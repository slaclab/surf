-------------------------------------------------------------------------------
-- File       : SsiPrbsRateGen.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:   
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity SsiPrbsRateGen is
   generic (
      -- General Configurations
      TPD_G                      : time                       := 1 ns;
      -- PRBS TX FIFO Configurations
      VALID_THOLD_G              : integer range 0 to (2**24) := 1;
      VALID_BURST_MODE_G         : boolean                    := false;
      BRAM_EN_G                  : boolean                    := true;
      XIL_DEVICE_G               : string                     := "7SERIES";
      USE_BUILT_IN_G             : boolean                    := false;
      CASCADE_SIZE_G             : natural range 1 to (2**24) := 1;
      FIFO_ADDR_WIDTH_G          : natural range 4 to 48      := 9;
      -- AXI Stream Configurations
      AXIS_CLK_FREQ_G            : real                       := 156.25E+6;  -- units of Hz
      AXIS_CONFIG_G              : AxiStreamConfigType        := AXI_STREAM_CONFIG_INIT_C);
   port (
      -- Master Port (mAxisClk)
      mAxisClk        : in  sl;
      mAxisRst        : in  sl;
      mAxisMaster     : out AxiStreamMasterType;
      mAxisSlave      : in  AxiStreamSlaveType;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end SsiPrbsRateGen;

architecture rtl of SsiPrbsRateGen is

   type RegType is record
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      trig           : sl;
      packetLength   : slv(31 downto 0);
      genPeriod      : slv(31 downto 0);
      genEnable      : sl;
      genOne         : sl;
      genMissed      : slv(31 downto 0);
      genCount       : slv(31 downto 0);
      frameCount     : slv(31 downto 0);
      statReset      : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      trig           => '0',
      packetLength   => (others=>'0'),
      genPeriod      => (others=>'0'),
      genEnable      => '0',
      genOne         => '0',
      genMissed      => (others=>'0'),
      genCount       => (others=>'0'),
      frameCount     => (others=>'0'),
      statReset      => '1');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal iAxisMaster  : AxiStreamMasterType;
   signal iAxisSlave   : AxiStreamSlaveType;
   signal frameRate    : slv(31 downto 0);
   signal frameRateMax : slv(31 downto 0);
   signal frameRateMin : slv(31 downto 0);
   signal bandwidth    : slv(63 downto 0);
   signal bandwidthMax : slv(63 downto 0);
   signal bandwidthMin : slv(63 downto 0);
   signal busy         : sl;

begin

   mAxisMaster <= iAxisMaster;
   iAxisSlave  <= mAxisSlave;

   U_PrbsTx: entity work.SsiPrbsTx 
      generic map (
         TPD_G                      => TPD_G,
         VALID_THOLD_G              => VALID_THOLD_G,
         VALID_BURST_MODE_G         => VALID_BURST_MODE_G,
         BRAM_EN_G                  => BRAM_EN_G,
         XIL_DEVICE_G               => XIL_DEVICE_G,
         USE_BUILT_IN_G             => USE_BUILT_IN_G,
         GEN_SYNC_FIFO_G            => true,
         CASCADE_SIZE_G             => CASCADE_SIZE_G,
         FIFO_ADDR_WIDTH_G          => FIFO_ADDR_WIDTH_G,
         MASTER_AXI_STREAM_CONFIG_G => AXIS_CONFIG_G)
      port map (
         mAxisClk        => mAxisClk,
         mAxisRst        => mAxisRst,
         mAxisMaster     => iAxisMaster,
         mAxisSlave      => iAxisSlave,
         locClk          => mAxisClk,
         locRst          => mAxisRst,
         trig            => r.trig,
         busy            => busy,
         packetLength    => r.packetLength);

   U_Monitor: entity work.AxiStreamMon
      generic map (
         TPD_G           => TPD_G,
         COMMON_CLK_G    => true,
         AXIS_CLK_FREQ_G => AXIS_CLK_FREQ_G,
         AXIS_CONFIG_G   => AXIS_CONFIG_G)
      port map (
         axisClk       => mAxisClk,
         axisRst       => mAxisRst,
         axisMaster    => iAxisMaster,
         axisSlave     => iAxisSlave,
         statusClk     => mAxisClk,
         statusRst     => r.statReset,
         frameRate     => frameRate,
         frameRateMax  => frameRateMax,
         frameRateMin  => frameRateMin,
         bandwidth     => bandwidth,
         bandwidthMax  => bandwidthMax,
         bandwidthMin  => bandwidthMin);


   comb : process (axilReadMaster, axilWriteMaster, r, mAxisRst, busy,
                   frameRate, frameRateMax, frameRateMin,
                   bandwidth, bandwidthMax, bandwidthMin,
                   iAxisMaster, iAxisSlave ) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndPointType;
   begin

      -- Latch the current value
      v := r;

      -- Clear
      --v.statReset := '0';
      v.trig      := '0';
      v.genOne    := '0';

      -- Start transaction block
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Map the registers
      axiSlaveRegister(axilEp, x"000", 0, v.statReset);
      axiSlaveRegister(axilEp, x"004", 0, v.packetLength);
      axiSlaveRegister(axilEp, x"008", 0, v.genPeriod);
      axiSlaveRegister(axilEp, x"00C", 0, v.genEnable);
      axiSlaveRegister(axilEp, x"00C", 1, v.genOne);

      axiSlaveRegisterR(axilEp, x"010", 0, r.genMissed);
      axiSlaveRegisterR(axilEp, x"014", 0, frameRate);
      axiSlaveRegisterR(axilEp, x"018", 0, frameRateMax);
      axiSlaveRegisterR(axilEp, x"01C", 0, frameRateMin);
      axiSlaveRegisterR(axilEp, x"020", 0, bandwidth);
      axiSlaveRegisterR(axilEp, x"028", 0, bandwidthMax);
      axiSlaveRegisterR(axilEp, x"030", 0, bandwidthMin);

      axiSlaveRegisterR(axilEp, x"040", 0, r.frameCount);

      -- End transaction block
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_OK_C);

      -- Frame generation
      if r.genEnable = '0' then
         v.genCount := (others=>'0'); 
         v.trig     := '0';
      else
         v.genCount := r.genCount + 1;

         if r.genOne = '1' then
            v.trig := '1';

         elsif r.genCount = r.genPeriod then
            v.genCount := (others=>'0');
            v.trig     := '1';

            if busy = '1' then
               v.trig      := '0';
               v.genMissed := r.genMissed + 1;
            else
               v.frameCount := r.frameCount + 1;
            end if;
         end if;
      end if;

      if r.statReset = '1' then
         v.genMissed := (others=>'0');
      end if;

      -- Reset      
      if (mAxisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle      
      rin <= v;

      -- Outputs   
      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;

   end process comb;

   seq : process (mAxisClk) is
   begin
      if (rising_edge(mAxisClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
