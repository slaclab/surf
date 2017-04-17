-------------------------------------------------------------------------------
-- File       : SsiPrbsTx.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-02
-- Last update: 2016-10-25
-------------------------------------------------------------------------------
-- Description:   This module generates 
--                PseudoRandom Binary Sequence (PRBS) on Virtual Channel Lane.
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

entity SsiPrbsTx is
   generic (
      -- General Configurations
      TPD_G                      : time                       := 1 ns;
      AXI_ERROR_RESP_G           : slv(1 downto 0)            := AXI_RESP_SLVERR_C;
      -- FIFO Configurations
      VALID_THOLD_G              : integer range 0 to (2**24) := 1;
      BRAM_EN_G                  : boolean                    := true;
      XIL_DEVICE_G               : string                     := "7SERIES";
      USE_BUILT_IN_G             : boolean                    := false;
      GEN_SYNC_FIFO_G            : boolean                    := false;
      ALTERA_SYN_G               : boolean                    := false;
      ALTERA_RAM_G               : string                     := "M9K";
      CASCADE_SIZE_G             : natural range 1 to (2**24) := 1;
      FIFO_ADDR_WIDTH_G          : natural range 4 to 48      := 9;
      FIFO_PAUSE_THRESH_G        : natural range 1 to (2**24) := 2**8;
      -- PRBS Configurations
      PRBS_SEED_SIZE_G           : natural range 8 to 128    := 32;
      PRBS_TAPS_G                : NaturalArray               := (0 => 31, 1 => 6, 2 => 2, 3 => 1);
      PRBS_INCREMENT_G           : boolean                    := false;  -- Increment mode by default instead of PRBS
      -- AXI Stream Configurations
      MASTER_AXI_STREAM_CONFIG_G : AxiStreamConfigType        := ssiAxiStreamConfig(16, TKEEP_COMP_C);
      MASTER_AXI_PIPE_STAGES_G   : natural range 0 to 16      := 0);
   port (
      -- Master Port (mAxisClk)
      mAxisClk        : in  sl;
      mAxisRst        : in  sl;
      mAxisMaster     : out AxiStreamMasterType;
      mAxisSlave      : in  AxiStreamSlaveType;
      -- Trigger Signal (locClk domain)
      locClk          : in  sl;
      locRst          : in  sl                     := '0';
      trig            : in  sl                     := '1';
      packetLength    : in  slv(31 downto 0)       := X"FFFFFFFF";
      forceEofe       : in  sl                     := '0';
      busy            : out sl;
      tDest           : in  slv(7 downto 0)        := X"00";
      tId             : in  slv(7 downto 0)        := X"00";
      -- Optional: Axi-Lite Register Interface (locClk domain)
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end SsiPrbsTx;

architecture rtl of SsiPrbsTx is

   constant PRBS_BYTES_C : natural := wordCount(PRBS_SEED_SIZE_G, 8);
   constant PRBS_SSI_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => PRBS_BYTES_C,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => MASTER_AXI_STREAM_CONFIG_G.TKEEP_MODE_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => MASTER_AXI_STREAM_CONFIG_G.TUSER_MODE_C);

   type StateType is (
      IDLE_S,
      SEED_RAND_S,
      LENGTH_S,
      DATA_S);

   type RegType is record
      busy           : sl;
      overflow       : sl;
      length         : slv(31 downto 0);
      packetLength   : slv(31 downto 0);
      dataCnt        : slv(31 downto 0);
      eventCnt       : slv(PRBS_SEED_SIZE_G-1 downto 0);
      randomData     : slv(PRBS_SEED_SIZE_G-1 downto 0);
      txAxisMaster   : AxiStreamMasterType;
      state          : StateType;
      axiEn          : sl;
      oneShot        : sl;
      trig           : sl;
      cntData        : sl;
      tDest          : slv(7 downto 0);
      tId            : slv(7 downto 0);
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      busy           => '1',
      overflow       => '0',
      length         => (others => '0'),
      packetLength   => (others => '0'),
      dataCnt        => (others => '0'),
      eventCnt       => (others => '0'),
      randomData     => (others => '0'),
      txAxisMaster   => AXI_STREAM_MASTER_INIT_C,
      state          => IDLE_S,
      axiEn          => '0',
      oneShot        => '0',
      trig           => '0',
      cntData        => toSl(PRBS_INCREMENT_G),
      tDest          => X"00",
      tId            => X"00",
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal txSlave : AxiStreamSlaveType;
   signal txCtrl  : AxiStreamCtrlType;

begin

--   assert (PRBS_SEED_SIZE_G mod 8 = 0) report "PRBS_SEED_SIZE_G must be a multiple of 8" severity failure;

   comb : process (axilReadMaster, axilWriteMaster, forceEofe, locRst, packetLength, r, tDest, tId,
                   trig, txCtrl, txSlave) is
      variable v             : RegType;
      variable axilStatus    : AxiLiteStatusType;
      variable axilWriteResp : slv(1 downto 0);
      variable axilReadResp  : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Reset the one shot
      v.oneShot := '0';

      ----------------------------------------------------------------------------------------------
      -- Axi-Lite interface
      ----------------------------------------------------------------------------------------------
      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

      if (axilStatus.writeEnable = '1') then
         axilWriteResp := ite(axilWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         case (axilWriteMaster.awaddr(7 downto 0)) is
            when X"00" =>
               v.axiEn   := axilWriteMaster.wdata(0);
               v.trig    := axilWriteMaster.wdata(1);
               -- BIT2 reserved for busy
               -- BIT3 reserved for overflow
               v.oneShot := axilWriteMaster.wdata(4);
               v.cntData := axilWriteMaster.wdata(5);
            when X"04" =>
               v.packetLength := axilWriteMaster.wdata(31 downto 0);
            when X"08" =>
               v.tDest := axilWriteMaster.wdata(7 downto 0);
               v.tId   := axilWriteMaster.wdata(15 downto 8);
            when others =>
               axilWriteResp := AXI_ERROR_RESP_G;
         end case;
         axiSlaveWriteResponse(v.axilWriteSlave);
      end if;

      if (axilStatus.readEnable = '1') then
         axilReadResp          := ite(axilReadMaster.araddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         v.axilReadSlave.rdata := (others => '0');
         case (axilReadMaster.araddr(7 downto 0)) is
            when X"00" =>
               v.axilReadSlave.rdata(0) := r.axiEn;
               v.axilReadSlave.rdata(1) := r.trig;
               v.axilReadSlave.rdata(2) := r.busy;
               v.axilReadSlave.rdata(3) := r.overflow;
               -- BIT4 reserved for oneShot
               v.axilReadSlave.rdata(5) := r.cntData;
            when X"04" =>
               v.axilReadSlave.rdata(31 downto 0) := r.packetLength;
            when X"08" =>
               v.axilReadSlave.rdata(7 downto 0)  := r.tDest;
               v.axilReadSlave.rdata(15 downto 8) := r.tId;
            when X"0C" =>
               v.axilReadSlave.rdata(31 downto 0) := r.dataCnt;
            when X"10" =>
               if (PRBS_SEED_SIZE_G < 32) then
                  v.axilReadSlave.rdata(PRBS_SEED_SIZE_G-1 downto 0) := r.eventCnt;
               else
                  v.axilReadSlave.rdata(31 downto 0) := r.eventCnt(31 downto 0);
               end if;
            when X"14" =>
               if (PRBS_SEED_SIZE_G < 32) then
                  v.axilReadSlave.rdata(PRBS_SEED_SIZE_G-1 downto 0) := r.randomData;
               else
                  v.axilReadSlave.rdata(31 downto 0) := r.randomData(31 downto 0);
               end if;
            when others =>
               axilReadResp := AXI_ERROR_RESP_G;
         end case;
         axiSlaveReadResponse(v.axilReadSlave);
      end if;

      -- Override axi settings if axi not enabled
      if (v.axiEn = '0') then
         v.trig         := trig;
         v.packetLength := packetLength;
         v.tDest        := tDest;
         v.tId          := tId;
      end if;

      -- Check for overflow condition or forced EOFE
      if (txCtrl.overflow = '1') or (forceEofe = '1') then
         -- Latch the overflow error bit for the data packet
         v.overflow := '1';
      end if;

      -- Check the AXIS flow control
      if txSlave.tReady = '1' then
         v.txAxisMaster.tValid := '0';
         v.txAxisMaster.tLast  := '0';
         v.txAxisMaster.tUser  := (others => '0');
         v.txAxisMaster.tKeep  := (others => '1');
      end if;

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the busy flag
            v.busy := '0';
            -- Check for a trigger
            if (r.trig = '1') or (r.oneShot = '1') then
               -- Latch the generator seed
               v.randomData         := r.eventCnt;
               -- Set the busy flag
               v.busy               := '1';
               -- Reset the overflow flag
               v.overflow           := '0';
               -- Latch the configuration
               v.txAxisMaster.tDest := r.tDest;
               v.txAxisMaster.tId   := r.tId;
               -- Check the packet length request value
               if r.packetLength = 0 then
                  -- Force minimum packet length of 2 (+1)
                  v.length := toSlv(2, 32);
               elsif r.packetLength = 1 then
                  -- Force minimum packet length of 2 (+1)
                  v.length := toSlv(2, 32);
               else
                  v.length := r.packetLength;
               end if;
               -- Next State
               v.state := SEED_RAND_S;
            end if;
         ----------------------------------------------------------------------
         when SEED_RAND_S =>
            -- Check if the FIFO is ready
            if v.txAxisMaster.tvalid = '0' then
               -- Send the random seed word
               v.txAxisMaster.tvalid                             := '1';
               v.txAxisMaster.tData(PRBS_SEED_SIZE_G-1 downto 0) := r.eventCnt;
               -- Generate the next random data word
--               for i in 0 to PRBS_SEED_SIZE_G-1 loop
                  v.randomData := lfsrShift(v.randomData, PRBS_TAPS_G, '0');
--               end loop;
               -- Increment the counter
               v.eventCnt := r.eventCnt + 1;
               -- Increment the counter
               v.dataCnt  := r.dataCnt + 1;
               -- Set the SOF bit
               ssiSetUserSof(PRBS_SSI_CONFIG_C, v.txAxisMaster, '1');
               -- Next State
               v.state    := LENGTH_S;
            end if;
         ----------------------------------------------------------------------
         when LENGTH_S =>
            -- Check if the FIFO is ready
            if v.txAxisMaster.tvalid = '0' then
               -- Send the upper packetLength value
               v.txAxisMaster.tvalid             := '1';
               v.txAxisMaster.tData(31 downto 0) := r.length;
               -- Increment the counter
               v.dataCnt                         := r.dataCnt + 1;
               -- Next State
               v.state                           := DATA_S;
            end if;
         ----------------------------------------------------------------------
         when DATA_S =>
            -- Check if the FIFO is ready
            if v.txAxisMaster.tvalid = '0' then
               -- Send the random data word
               v.txAxisMaster.tValid := '1';
               -- Check if we are sending PRBS or counter data
               if r.cntData = '0' then
                  -- PRBS data
                  v.txAxisMaster.tData(PRBS_SEED_SIZE_G-1 downto 0) := r.randomData;
               else
                  -- Counter data
                  v.txAxisMaster.tData(PRBS_SEED_SIZE_G-1 downto 0) := (others => '0');
                  v.txAxisMaster.tData(31 downto 0)                 := r.dataCnt;
               end if;
               -- Generate the next random data word
--               for i in 0 to PRBS_SEED_SIZE_G-1 loop
                  v.randomData := lfsrShift(v.randomData, PRBS_TAPS_G, '0');
--               end loop;
               -- Increment the counter
               v.dataCnt    := r.dataCnt + 1;
               -- Check the counter
               if r.dataCnt = r.length then
                  -- Reset the counter
                  v.dataCnt            := (others => '0');
                  -- Set the EOF bit                
                  v.txAxisMaster.tLast := '1';
                  -- Set the EOFE bit
                  ssiSetUserEofe(PRBS_SSI_CONFIG_C, v.txAxisMaster, r.overflow);
                  -- Reset the busy flag
                  v.busy  := '0';
                  -- Next State
                  v.state := IDLE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (locRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      busy           <= r.busy;
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;

   end process comb;

   seq : process (locClk) is
   begin
      if rising_edge(locClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   AxiStreamFifo_Inst : entity work.AxiStreamFifo
      generic map(
         -- General Configurations
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => MASTER_AXI_PIPE_STAGES_G,
         PIPE_STAGES_G       => MASTER_AXI_PIPE_STAGES_G,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => VALID_THOLD_G,
         -- FIFO configurations
         BRAM_EN_G           => BRAM_EN_G,
         XIL_DEVICE_G        => XIL_DEVICE_G,
         USE_BUILT_IN_G      => USE_BUILT_IN_G,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         ALTERA_SYN_G        => ALTERA_SYN_G,
         ALTERA_RAM_G        => ALTERA_RAM_G,
         CASCADE_SIZE_G      => CASCADE_SIZE_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         CASCADE_PAUSE_SEL_G => (CASCADE_SIZE_G-1),
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => PRBS_SSI_CONFIG_C,
         MASTER_AXI_CONFIG_G => MASTER_AXI_STREAM_CONFIG_G)
      port map (
         -- Slave Port
         sAxisClk    => locClk,
         sAxisRst    => locRst,
         sAxisMaster => r.txAxisMaster,
         sAxisSlave  => txSlave,
         sAxisCtrl   => txCtrl,
         -- Master Port
         mAxisClk    => mAxisClk,
         mAxisRst    => mAxisRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end rtl;
