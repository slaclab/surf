-------------------------------------------------------------------------------
-- Title      : SSI Protocol: https://confluence.slac.stanford.edu/x/0oyfD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: SsiPrbsTx + AxiStreamMon Wrapper
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity SsiPrbsRateGen is
   generic (
      -- General Configurations
      TPD_G                   : time                       := 1 ns;
      RST_ASYNC_G             : boolean                    := false;
      -- PRBS TX FIFO Configurations
      VALID_THOLD_G           : integer range 0 to (2**24) := 1;
      VALID_BURST_MODE_G      : boolean                    := false;
      MEMORY_TYPE_G           : string                     := "block";
      CASCADE_SIZE_G          : natural range 1 to (2**24) := 1;
      FIFO_ADDR_WIDTH_G       : natural range 4 to 48      := 9;
      FIFO_INT_WIDTH_SELECT_G : string                     := "WIDE";
      -- PRBS Configuration
      PRBS_SEED_SIZE_G        : natural range 32 to 512    := 32;
      PRBS_FIFO_PIPE_STAGES_G : integer range 0 to 16      := 0;
      -- AXI Stream Configurations
      AXIS_CLK_FREQ_G         : real                       := 156.25E+6;  -- units of Hz
      AXIS_CONFIG_G           : AxiStreamConfigType;
      -- Clock Configuration
      USE_AXIL_CLK_G          : boolean                    := false);
   port (
      -- Master Port (mAxisClk)
      mAxisClk        : in  sl;
      mAxisRst        : in  sl;
      mAxisMaster     : out AxiStreamMasterType;
      mAxisSlave      : in  AxiStreamSlaveType;
      axilClk         : in  sl := '0';
      axilRst         : in  sl := '0';
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
      packetLength   => (others => '0'),
      genPeriod      => (others => '0'),
      genEnable      => '0',
      genOne         => '0',
      genMissed      => (others => '0'),
      genCount       => (others => '0'),
      frameCount     => (others => '0'),
      statReset      => '0');

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

   signal localClk : sl;
   signal localRst : sl;

begin

   mAxisMaster <= iAxisMaster;
   iAxisSlave  <= mAxisSlave;

   localClk <= axilClk when USE_AXIL_CLK_G else mAxisClk;
   localRst <= axilRst when USE_AXIL_CLK_G else mAxisRst;

   U_PrbsTx : entity surf.SsiPrbsTx
      generic map (
         TPD_G                      => TPD_G,
         RST_ASYNC_G                => RST_ASYNC_G,
         AXI_EN_G                   => '0',
         VALID_THOLD_G              => VALID_THOLD_G,
         VALID_BURST_MODE_G         => VALID_BURST_MODE_G,
         MEMORY_TYPE_G              => MEMORY_TYPE_G,
         GEN_SYNC_FIFO_G            => not USE_AXIL_CLK_G,
         CASCADE_SIZE_G             => CASCADE_SIZE_G,
         FIFO_ADDR_WIDTH_G          => FIFO_ADDR_WIDTH_G,
         FIFO_INT_WIDTH_SELECT_G    => FIFO_INT_WIDTH_SELECT_G,
         PRBS_SEED_SIZE_G           => PRBS_SEED_SIZE_G,
         MASTER_AXI_STREAM_CONFIG_G => AXIS_CONFIG_G,
         MASTER_AXI_PIPE_STAGES_G   => PRBS_FIFO_PIPE_STAGES_G)
      port map (
         mAxisClk     => mAxisClk,
         mAxisRst     => mAxisRst,
         mAxisMaster  => iAxisMaster,
         mAxisSlave   => iAxisSlave,
         locClk       => localClk,
         locRst       => localRst,
         trig         => r.trig,
         busy         => busy,
         packetLength => r.packetLength);

   U_Monitor : entity surf.AxiStreamMon
      generic map (
         TPD_G           => TPD_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         COMMON_CLK_G    => true,
         AXIS_CLK_FREQ_G => AXIS_CLK_FREQ_G,
         AXIS_CONFIG_G   => AXIS_CONFIG_G)
      port map (
         axisClk      => mAxisClk,
         axisRst      => mAxisRst,
         axisMaster   => iAxisMaster,
         axisSlave    => iAxisSlave,
         statusClk    => localClk,
         statusRst    => r.statReset,
         frameRate    => frameRate,
         frameRateMax => frameRateMax,
         frameRateMin => frameRateMin,
         bandwidth    => bandwidth,
         bandwidthMax => bandwidthMax,
         bandwidthMin => bandwidthMin);


   comb : process (axilReadMaster, axilWriteMaster, bandwidth, bandwidthMax,
                   bandwidthMin, busy, frameRate, frameRateMax, frameRateMin,
                   localRst, r) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndPointType;
   begin

      -- Latch the current value
      v := r;

      -- Clear
      --v.statReset := '0';
      v.trig   := '0';
      v.genOne := '0';

      -- Start transaction block
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Map the registers
      axiSlaveRegister(axilEp, x"00", 0, v.statReset);
      axiSlaveRegister(axilEp, x"04", 0, v.packetLength);
      axiSlaveRegister(axilEp, x"08", 0, v.genPeriod);
      axiSlaveRegister(axilEp, x"0C", 0, v.genEnable);
      axiSlaveRegister(axilEp, x"0C", 1, v.genOne);

      axiSlaveRegisterR(axilEp, x"10", 0, r.genMissed);
      axiSlaveRegisterR(axilEp, x"14", 0, frameRate);
      axiSlaveRegisterR(axilEp, x"18", 0, frameRateMax);
      axiSlaveRegisterR(axilEp, x"1C", 0, frameRateMin);
      axiSlaveRegisterR(axilEp, x"20", 0, bandwidth);
      axiSlaveRegisterR(axilEp, x"28", 0, bandwidthMax);
      axiSlaveRegisterR(axilEp, x"30", 0, bandwidthMin);

      axiSlaveRegisterR(axilEp, x"40", 0, r.frameCount);

      -- End transaction block
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_OK_C);

      -- Frame generation
      if r.genEnable = '0' then
         v.genCount := (others => '0');
         v.trig     := '0';
      else
         v.genCount := r.genCount + 1;

         if r.genOne = '1' then
            v.trig := '1';

         elsif r.genCount = r.genPeriod then
            v.genCount := (others => '0');
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
         v.genMissed := (others => '0');
      end if;

      -- Reset
      if (RST_ASYNC_G = false and localRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;

   end process comb;

   seq : process (localClk, localRst) is
   begin
      if (RST_ASYNC_G) and (localRst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(localClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
