-------------------------------------------------------------------------------
-- Title      : HTSP: https://confluence.slac.stanford.edu/x/pQmODw
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the HtspCaui4Gty
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
use surf.AxiLitePkg.all;
use surf.SsiPkg.all;
use surf.HtspPkg.all;

entity HtspCaui4GtyTb is

end HtspCaui4GtyTb;

architecture testbed of HtspCaui4GtyTb is

   -- Note: The IP core's tx_axis-to-rx_axis loopback latency is 287.579ns (93 clock cycles of 322.58 MHz txusrclk2 clock)

   constant TPD_G : time := 1 ns;

   constant PRBS_SEED_SIZE_C : positive := 512;
   -- constant PRBS_SEED_SIZE_C      : positive := 32;

   -- constant NUM_VC_C              : positive := 1;
   constant NUM_VC_C : positive := 4;

   constant TX_MAX_PAYLOAD_SIZE_C : positive := 1024;

   constant CHOKE_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(8);
   -- constant CHOKE_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(64);

   -- constant PKT_LEN_C : slv(31 downto 0) := x"0000000F";
   constant PKT_LEN_C : slv(31 downto 0) := x"000000FF";

   signal htspTxIn  : HtspTxInType := HTSP_TX_IN_INIT_C;
   signal htspTxOut : HtspTxOutType;

   signal htspRxIn  : HtspRxInType := HTSP_RX_IN_INIT_C;
   signal htspRxOut : HtspRxOutType;

   signal htspTxMasters : AxiStreamMasterArray(NUM_VC_C-1 downto 0);
   signal htspTxSlaves  : AxiStreamSlaveArray(NUM_VC_C-1 downto 0);
   signal htspRxMasters : AxiStreamMasterArray(NUM_VC_C-1 downto 0);
   signal htspRxCtrl    : AxiStreamCtrlArray(NUM_VC_C-1 downto 0);
   signal rxMasters     : AxiStreamMasterArray(NUM_VC_C-1 downto 0);
   signal rxSlaves      : AxiStreamSlaveArray(NUM_VC_C-1 downto 0);

   signal updateDet : slv(NUM_VC_C-1 downto 0);
   signal errorDet  : slv(NUM_VC_C-1 downto 0);

   signal loopbackP : slv(3 downto 0);
   signal loopbackN : slv(3 downto 0);

   signal stableClk : sl := '0';
   signal stableRst : sl := '1';

   signal gtRefClkP : sl := '0';
   signal gtRefClkN : sl := '1';

   signal htspClk : sl := '0';
   signal htspRst : sl := '1';

   signal passed : sl := '0';
   signal failed : sl := '0';

begin

   U_stableClk : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => 6.4 ns,   -- 156.25 MHz
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1 us)     -- Hold reset for this long)
      port map (
         clkP => stableClk,
         rst  => stableRst);

   U_gtRefClk : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => 6.206 ns,  -- 161.1328125 MHz
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1 us)     -- Hold reset for this long)
      port map (
         clkP => gtRefClkP,
         clkN => gtRefClkN);

   U_Core : entity surf.HtspCaui4Gty
      generic map (
         TPD_G                 => TPD_G,
         SIM_SPEEDUP_G         => true,
         NUM_VC_G              => NUM_VC_C,
         TX_MAX_PAYLOAD_SIZE_G => TX_MAX_PAYLOAD_SIZE_C)
      port map (
         -- Stable Clock and Reset
         stableClk     => stableClk,
         stableRst     => stableRst,
         -- HTSP Clock and Reset
         htspClk       => htspClk,
         htspRst       => htspRst,
         -- Non VC Rx Signals
         htspRxIn      => htspRxIn,
         htspRxOut     => htspRxOut,
         -- Non VC Tx Signals
         htspTxIn      => htspTxIn,
         htspTxOut     => htspTxOut,
         -- Tx User interface
         htspTxMasters => htspTxMasters,
         htspTxSlaves  => htspTxSlaves,
         -- Rx User interface
         htspRxMasters => htspRxMasters,
         htspRxCtrl    => htspRxCtrl,
         -- GT Ports
         gtRefClkP     => gtRefClkP,
         gtRefClkN     => gtRefClkN,
         gtRxP         => loopbackP,
         gtRxN         => loopbackN,
         gtTxP         => loopbackP,
         gtTxN         => loopbackN);

   GEN_VEC :
   for i in 0 to NUM_VC_C-1 generate

      U_SsiPrbsTx : entity surf.SsiPrbsTx
         generic map (
            TPD_G                      => TPD_G,
            VALID_THOLD_G              => (TX_MAX_PAYLOAD_SIZE_C/64),
            VALID_BURST_MODE_G         => true,
            AXI_EN_G                   => '0',
            GEN_SYNC_FIFO_G            => true,
            PRBS_SEED_SIZE_G           => PRBS_SEED_SIZE_C,
            MASTER_AXI_STREAM_CONFIG_G => HTSP_AXIS_CONFIG_C)
         port map (
            mAxisClk     => htspClk,
            mAxisRst     => htspRst,
            mAxisMaster  => htspTxMasters(i),
            mAxisSlave   => htspTxSlaves(i),
            locClk       => htspClk,
            locRst       => htspRst,
            trig         => htspRxOut.remRxLinkReady,
            packetLength => PKT_LEN_C);

      U_BottleNeck : entity surf.AxiStreamFifoV2
         generic map (
            TPD_G               => TPD_G,
            SLAVE_READY_EN_G    => false,                -- Using pause
            GEN_SYNC_FIFO_G     => true,
            SYNTH_MODE_G        => "xpm",
            MEMORY_TYPE_G       => "ultra",
            FIFO_ADDR_WIDTH_G   => 12,  -- 4k URAM,
            FIFO_FIXED_THRESH_G => true,
            FIFO_PAUSE_THRESH_G => 1024,                 -- 1/4 of buffer
            SLAVE_AXI_CONFIG_G  => HTSP_AXIS_CONFIG_C,
            MASTER_AXI_CONFIG_G => CHOKE_AXIS_CONFIG_C)  -- Bottleneck the bandwidth
         port map (
            -- Slave Interface
            sAxisClk    => htspClk,
            sAxisRst    => htspRst,
            sAxisMaster => htspRxMasters(i),
            sAxisCtrl   => htspRxCtrl(i),
            -- Master Interface
            mAxisClk    => htspClk,
            mAxisRst    => htspRst,
            mAxisMaster => rxMasters(i),
            mAxisSlave  => rxSlaves(i));

      U_SsiPrbsRx : entity surf.SsiPrbsRx
         generic map (
            TPD_G                     => TPD_G,
            GEN_SYNC_FIFO_G           => true,
            SLAVE_READY_EN_G          => true,
            PRBS_SEED_SIZE_G          => PRBS_SEED_SIZE_C,
            SLAVE_AXI_STREAM_CONFIG_G => CHOKE_AXIS_CONFIG_C)  -- Matches U_BottleNeck outbound data stream
         port map (
            sAxisClk       => htspClk,
            sAxisRst       => htspRst,
            sAxisMaster    => rxMasters(i),
            sAxisSlave     => rxSlaves(i),
            updatedResults => updateDet(i),
            errorDet       => errorDet(i),
            axiClk         => htspClk,
            axiRst         => htspRst);

   end generate GEN_VEC;

   process(htspClk)
   begin
      if rising_edge(htspClk) then
         failed <= uOr(errorDet) after TPD_G;
      end if;
   end process;

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
