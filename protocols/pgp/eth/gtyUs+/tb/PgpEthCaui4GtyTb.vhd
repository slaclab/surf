-------------------------------------------------------------------------------
-- File       : PgpEthCaui4GtyTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the PgpEthCaui4Gty
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
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.SsiPkg.all;
use work.PgpEthPkg.all;

entity PgpEthCaui4GtyTb is

end PgpEthCaui4GtyTb;

architecture testbed of PgpEthCaui4GtyTb is

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

   signal pgpTxIn  : PgpEthTxInType := PGP_ETH_TX_IN_INIT_C;
   signal pgpTxOut : PgpEthTxOutType;

   signal pgpRxIn  : PgpEthRxInType := PGP_ETH_RX_IN_INIT_C;
   signal pgpRxOut : PgpEthRxOutType;

   signal pgpTxMasters : AxiStreamMasterArray(NUM_VC_C-1 downto 0);
   signal pgpTxSlaves  : AxiStreamSlaveArray(NUM_VC_C-1 downto 0);
   signal pgpRxMasters : AxiStreamMasterArray(NUM_VC_C-1 downto 0);
   signal pgpRxCtrl    : AxiStreamCtrlArray(NUM_VC_C-1 downto 0);
   signal rxMasters    : AxiStreamMasterArray(NUM_VC_C-1 downto 0);
   signal rxSlaves     : AxiStreamSlaveArray(NUM_VC_C-1 downto 0);

   signal updateDet : slv(NUM_VC_C-1 downto 0);
   signal errorDet  : slv(NUM_VC_C-1 downto 0);

   signal loopbackP : slv(3 downto 0);
   signal loopbackN : slv(3 downto 0);

   signal stableClk : sl := '0';
   signal stableRst : sl := '1';

   signal gtRefClkP : sl := '0';
   signal gtRefClkN : sl := '1';

   signal pgpClk : sl := '0';
   signal pgpRst : sl := '1';

   signal passed : sl := '0';
   signal failed : sl := '0';

begin

   U_stableClk : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 6.4 ns,   -- 156.25 MHz
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1 us)     -- Hold reset for this long)
      port map (
         clkP => stableClk,
         rst  => stableRst);

   U_gtRefClk : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 6.206 ns,  -- 161.1328125 MHz
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1 us)     -- Hold reset for this long)
      port map (
         clkP => gtRefClkP,
         clkN => gtRefClkN);

   U_Core : entity work.PgpEthCaui4Gty
      generic map (
         TPD_G                 => TPD_G,
         NUM_VC_G              => NUM_VC_C,
         TX_MAX_PAYLOAD_SIZE_G => TX_MAX_PAYLOAD_SIZE_C)
      port map (
         -- Stable Clock and Reset
         stableClk    => stableClk,
         stableRst    => stableRst,
         -- PGP Clock and Reset
         pgpClk       => pgpClk,
         pgpRst       => pgpRst,
         -- Non VC Rx Signals
         pgpRxIn      => pgpRxIn,
         pgpRxOut     => pgpRxOut,
         -- Non VC Tx Signals
         pgpTxIn      => pgpTxIn,
         pgpTxOut     => pgpTxOut,
         -- Tx User interface
         pgpTxMasters => pgpTxMasters,
         pgpTxSlaves  => pgpTxSlaves,
         -- Rx User interface
         pgpRxMasters => pgpRxMasters,
         pgpRxCtrl    => pgpRxCtrl,
         -- GT Ports
         gtRefClkP    => gtRefClkP,
         gtRefClkN    => gtRefClkN,
         gtRxP        => loopbackP,
         gtRxN        => loopbackN,
         gtTxP        => loopbackP,
         gtTxN        => loopbackN);

   GEN_VEC :
   for i in 0 to NUM_VC_C-1 generate

      U_SsiPrbsTx : entity work.SsiPrbsTx
         generic map (
            TPD_G                      => TPD_G,
            VALID_THOLD_G              => (TX_MAX_PAYLOAD_SIZE_C/64),
            VALID_BURST_MODE_G         => true,
            AXI_EN_G                   => '0',
            GEN_SYNC_FIFO_G            => true,
            PRBS_SEED_SIZE_G           => PRBS_SEED_SIZE_C,
            MASTER_AXI_STREAM_CONFIG_G => PGP_ETH_AXIS_CONFIG_C)
         port map (
            mAxisClk     => pgpClk,
            mAxisRst     => pgpRst,
            mAxisMaster  => pgpTxMasters(i),
            mAxisSlave   => pgpTxSlaves(i),
            locClk       => pgpClk,
            locRst       => pgpRst,
            trig         => pgpRxOut.remRxLinkReady,
            packetLength => PKT_LEN_C);

      U_BottleNeck : entity work.AxiStreamFifoV2
         generic map (
            TPD_G               => TPD_G,
            SLAVE_READY_EN_G    => false,                -- Using pause
            GEN_SYNC_FIFO_G     => true,
            BRAM_EN_G           => true,
            FIFO_FIXED_THRESH_G => true,
            FIFO_ADDR_WIDTH_G   => 9,
            FIFO_PAUSE_THRESH_G => 2**7,
            SLAVE_AXI_CONFIG_G  => PGP_ETH_AXIS_CONFIG_C,
            MASTER_AXI_CONFIG_G => CHOKE_AXIS_CONFIG_C)  -- Bottleneck the bandwidth
         port map (
            -- Slave Interface
            sAxisClk    => pgpClk,
            sAxisRst    => pgpRst,
            sAxisMaster => pgpRxMasters(i),
            sAxisCtrl   => pgpRxCtrl(i),
            -- Master Interface
            mAxisClk    => pgpClk,
            mAxisRst    => pgpRst,
            mAxisMaster => rxMasters(i),
            mAxisSlave  => rxSlaves(i));

      U_SsiPrbsRx : entity work.SsiPrbsRx
         generic map (
            TPD_G                     => TPD_G,
            GEN_SYNC_FIFO_G           => true,
            SLAVE_READY_EN_G          => true,
            PRBS_SEED_SIZE_G          => PRBS_SEED_SIZE_C,
            SLAVE_AXI_STREAM_CONFIG_G => CHOKE_AXIS_CONFIG_C)  -- Matches U_BottleNeck outbound data stream
         port map (
            sAxisClk       => pgpClk,
            sAxisRst       => pgpRst,
            sAxisMaster    => rxMasters(i),
            sAxisSlave     => rxSlaves(i),
            updatedResults => updateDet(i),
            errorDet       => errorDet(i),
            axiClk         => pgpClk,
            axiRst         => pgpRst);

   end generate GEN_VEC;

   process(pgpClk)
   begin
      if rising_edge(pgpClk) then
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
