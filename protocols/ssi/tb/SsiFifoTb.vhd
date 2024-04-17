-------------------------------------------------------------------------------
-- Title      : SSI Protocol: https://confluence.slac.stanford.edu/x/0oyfD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the SsiFifo module
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
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity SsiFifoTb is end SsiFifoTb;

architecture testbed of SsiFifoTb is

   constant CLK_PERIOD_C : time := 10 ns;
   constant TPD_C        : time := CLK_PERIOD_C/4;

   constant TX_PACKET_LENGTH_C : slv(31 downto 0) := x"0000_000F";

   constant PRBS_SEED_SIZE_C : natural      := 32;
   constant PRBS_TAPS_C      : NaturalArray := (0 => 31, 1 => 6, 2 => 2, 3 => 1);
   constant PRBS_FLOW_CTRL_C : boolean      := true;

   constant NOT_PAUSE_FLOW_CONTROL_C : boolean := false;  -- false for pause flow control

   constant AXI_STREAM_CONFIG_C : AxiStreamConfigType := (
      -- TDEST_INTERLEAVE_C => true,
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 4,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 4,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   signal txClk  : sl := '0';
   signal txRst  : sl := '1';
   signal txRstL : sl := '0';

   signal txTrig      : sl := '0';
   signal txForceEofe : sl := '0';
   signal txBusy      : sl := '0';

   signal txMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal txSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal txCtrl   : AxiStreamCtrlType   := AXI_STREAM_CTRL_INIT_C;

   signal rxClk : sl := '0';
   signal rxRst : sl := '1';

   signal rxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal rxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal prbsFlowCtrlMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal prbsFlowCtrlSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal updated      : sl               := '0';
   signal errorDet     : sl               := '0';
   signal errLength    : sl               := '0';
   signal errDataBus   : sl               := '0';
   signal errEofe      : sl               := '0';
   signal errWordCnt   : slv(31 downto 0) := (others => '0');
   signal packetLength : slv(31 downto 0) := (others => '0');
   signal cnt          : slv(31 downto 0) := (others => '0');
   signal trigCnt      : slv(31 downto 0) := (others => '0');
   signal failedVec    : slv(6 downto 0)  := (others => '0');

   signal passed : sl := '0';
   signal failed : sl := '0';

begin

   -----------------------------
   -- Generate clocks and resets
   -----------------------------
   U_Fast : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1 us)
      port map (
         clkP => txClk,
         rst  => txRst,
         rstL => txRstL);

   U_Slow : entity surf.ClkRst
      generic map (
         -- CLK_PERIOD_G      => (2*CLK_PERIOD_C),
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1 us)
      port map (
         clkP => rxClk,
         rst  => rxRst);

   --------------
   -- Data Source
   --------------
   U_Tx : entity surf.SsiPrbsTx
      generic map (
         -- General Configurations
         TPD_G                      => TPD_C,
         AXI_EN_G                   => '0',
         -- FIFO configurations
         GEN_SYNC_FIFO_G            => true,
         -- PRBS Configurations
         PRBS_SEED_SIZE_G           => PRBS_SEED_SIZE_C,
         PRBS_TAPS_G                => PRBS_TAPS_C,
         -- AXI Stream Configurations
         MASTER_AXI_STREAM_CONFIG_G => AXI_STREAM_CONFIG_C)
      port map (
         -- Master Port (mAxisClk)
         mAxisClk     => txClk,
         mAxisRst     => txRst,
         mAxisMaster  => txMaster,
         mAxisSlave   => txSlave,
         -- Trigger Signal (locClk domain)
         locClk       => txClk,
         locRst       => txRst,
         -- trig         => txTrig,
         trig         => txRstL,
         packetLength => TX_PACKET_LENGTH_C,
         forceEofe    => txForceEofe,
         busy         => txBusy);

   trig : process (txClk) is
   begin
      if rising_edge(txClk) then
         -- Select the trigger pre-scaler
         txTrig  <= trigCnt(8)  after TPD_C;
         -- Increment the counter
         trigCnt <= trigCnt + 1 after TPD_C;
      end if;
   end process trig;

   ----------------------
   -- Module to be tested
   ----------------------
   U_SsiFifo : entity surf.SsiFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_C,
         INT_PIPE_STAGES_G   => 1,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => NOT_PAUSE_FLOW_CONTROL_C,
         VALID_THOLD_G       => 0,
         -- FIFO configurations
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 8,
         FIFO_FIXED_THRESH_G => false,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => AXI_STREAM_CONFIG_C,
         MASTER_AXI_CONFIG_G => AXI_STREAM_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk        => txClk,
         sAxisRst        => txRst,
         sAxisMaster     => txMaster,
         sAxisSlave      => txSlave,
         sAxisCtrl       => txCtrl,
         fifoPauseThresh => x"80",
         -- Master Port
         mAxisClk        => rxClk,
         mAxisRst        => rxRst,
         mAxisMaster     => rxMaster,
         mAxisSlave      => rxSlave);

   ------------
   -- Data Sink
   ------------
   U_Rx : entity surf.SsiPrbsRx
      generic map (
         -- General Configurations
         TPD_G                      => TPD_C,
         -- FIFO Configurations
         GEN_SYNC_FIFO_G            => true,
         -- PRBS Configurations
         PRBS_SEED_SIZE_G           => PRBS_SEED_SIZE_C,
         PRBS_TAPS_G                => PRBS_TAPS_C,
         -- AXI Stream Configurations
         SLAVE_AXI_STREAM_CONFIG_G  => AXI_STREAM_CONFIG_C,
         MASTER_AXI_STREAM_CONFIG_G => AXI_STREAM_CONFIG_C)
      port map (
         -- Streaming RX Data Interface (sAxisClk domain)
         sAxisClk       => rxClk,
         sAxisRst       => rxRst,
         sAxisMaster    => rxMaster,
         sAxisSlave     => rxSlave,
         -- Optional: TX Data Interface with EOFE tagging (sAxisClk domain)
         mAxisMaster    => prbsFlowCtrlMaster,
         mAxisSlave     => prbsFlowCtrlSlave,
         -- Error Detection Signals (sAxisClk domain)
         updatedResults => updated,
         errorDet       => errorDet,
         packetLength   => packetLength,
         errLength      => errLength,
         errDataBus     => errDataBus,
         errEofe        => errEofe,
         errWordCnt     => errWordCnt);

   ------------------------------------
   -- Assert PseudoRandom back pressure
   ------------------------------------
   GEN_PRBS_FLOW_CTRL : if (PRBS_FLOW_CTRL_C) generate
      U_PrbsFlowCtrl : entity surf.AxiStreamPrbsFlowCtrl
         generic map (
            TPD_G => TPD_C)
         port map (
            clk         => rxClk,
            rst         => rxRst,
            threshold   => x"8000_0000",
            -- Slave Port
            sAxisMaster => prbsFlowCtrlMaster,
            sAxisSlave  => prbsFlowCtrlSlave,
            -- Master Port
            mAxisMaster => open,
            mAxisSlave  => AXI_STREAM_SLAVE_FORCE_C);
   end generate;

   -----------------
   -- Error Checking
   -----------------
   error_checking : process(rxClk)
   begin
      if rising_edge(rxClk) then
         -- Check for RX PRBS update
         if updated = '1' then

            -- Map the error flag to the failed test vector
            failedVec(0) <= errLength  after TPD_C;
            failedVec(1) <= errDataBus after TPD_C;
            failedVec(2) <= errEofe    after TPD_C;

            -- Check for non-zero error word counts
            if errWordCnt /= 0 then
               failedVec(3) <= '1' after TPD_C;
            else
               failedVec(3) <= '0' after TPD_C;
            end if;

            -- Check for mismatch in expect length
            if packetLength /= TX_PACKET_LENGTH_C then
               failedVec(4) <= '1' after TPD_C;
            else
               failedVec(4) <= '0' after TPD_C;
            end if;

            -- Check for non-pause flow control and error detected
            if (NOT_PAUSE_FLOW_CONTROL_C) then
               failedVec(5) <= errorDet        after TPD_C;
               failedVec(6) <= txCtrl.overflow after TPD_C;
            end if;

            -- Increment the counter
            cnt <= cnt + 1 after TPD_C;

         end if;
      end if;
   end process error_checking;

   results : process (rxClk) is
   begin
      if rising_edge(rxClk) then

         -- OR Failed bits together
         failed <= uOR(failedVec) after TPD_C;

         -- Check for counter
         if (cnt = x"0001_0000") then
            passed <= '1' after TPD_C;
         end if;

      end if;
   end process results;

   process(failed, passed)
   begin
      if passed = '1' then
         assert false
            report "Simulation Passed!" severity failure;
      elsif failed = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;
   end process;

end testbed;
