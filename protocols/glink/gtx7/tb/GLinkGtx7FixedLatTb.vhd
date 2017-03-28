-------------------------------------------------------------------------------
-- File       : GLinkGtx7FixedLatTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-02-03
-- Last update: 2014-02-03
-------------------------------------------------------------------------------
-- Description: Simulation testbed for GLinkGtx7FixedLat
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

use work.StdRtlPkg.all;
use work.GlinkPkg.all;

entity GLinkGtx7FixedLatTb is end GLinkGtx7FixedLatTb;

architecture testbed of GLinkGtx7FixedLatTb is

   signal gtClk,
      stableClock,
      stableRst,
      txClock,
      txRst,
      rxClock,
      rxRecClk,
      pllRefClk,
      gtCPllRefClk,
      gtCPllLock,
      qPllOutClk,
      qPllOutRefClk,
      qPllLock,
      pllLockDetClk,
      qPllRefClkLost,
      qPllReset,
      gtQPllReset : sl := '0';
      
   signal gLinkTx    : GLinkTxType := GLINK_TX_INIT_C;
   signal gLinkRx    : GLinkRxType := GLINK_RX_INIT_C;
      
begin

   ClkRst_0 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 16 ns,
         RST_START_DELAY_G => 1 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 0.6 us)   -- Hold reset for this long)
      port map (
         clkP => stableClock,
         clkN => open,
         rst  => stableRst,
         rstL => open);
         
   ClkRst_1 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 6.25 ns,
         RST_START_DELAY_G => 1 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 0.6 us)   -- Hold reset for this long)
      port map (
         clkP => gtClk,
         clkN => open,
         rst  => open,
         rstL => open); 

   ClkRst_2 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 25 ns,
         RST_START_DELAY_G => 1 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 0.6 us)   -- Hold reset for this long)
      port map (
         clkP => txClock,
         clkN => open,
         rst  => open,
         rstL => open);          

   txRst <= stableRst;

   gtCPllRefClk  <= gtClk;
   pllRefClk     <= gtClk;
   pllLockDetClk <= stableClock;
   qPllReset     <= stableRst or gtQPllReset;
   --rxClock       <= rxRecClk;
   rxClock       <= txClock;

   QPllCore_1 : entity work.Gtx7QuadPll
      generic map (
         QPLL_REFCLK_SEL_G  => "111",
         QPLL_FBDIV_G       => "0100100000",-- N = 80
         QPLL_FBDIV_RATIO_G => '1',
         QPLL_REFCLK_DIV_G  => 1)
      port map (
         qPllRefClk     => pllRefClk,
         qPllOutClk     => qPllOutClk,
         qPllOutRefClk  => qPllOutRefClk,
         qPllLock       => qPllLock,
         qPllLockDetClk => pllLockDetClk,
         qPllRefClkLost => qPllRefClkLost,
         qPllReset      => qPllReset);                    

   GLinkGtx7FixedLat_Inst : entity work.GLinkGtx7FixedLat
      generic map (
         -- Simulation Settings
         SIM_GTRESET_SPEEDUP_G => "TRUE",
         SIMULATION_G          => true,         
         -- GLink Settings
         FLAGSEL_G         => false,
         -- CPLL Settings -
         CPLL_REFCLK_SEL_G => "111",
         CPLL_FBDIV_G         => 4,
         CPLL_FBDIV_45_G      => 5,
         CPLL_REFCLK_DIV_G    => 1,
         -- CDR Settings -
         RXOUT_DIV_G          => 8,
         TXOUT_DIV_G          => 16,
         RX_CLK25_DIV_G       => 7,    -- Set by wizard
         TX_CLK25_DIV_G       => 7,    -- Set by wizard
         RX_OS_CFG_G          => "0000010000000",  -- Set by wizard
         RXCDR_CFG_G          => x"03000023ff40080020",  -- Set by wizard
         RXDFEXYDEN_G         => '1',  -- Set by wizard
         RX_DFE_KL_CFG2_G     => x"301148AC",
         -- Configure PLL sources
         TX_PLL_G             => "QPLL",
         RX_PLL_G             => "CPLL")
      port map (
         -- TX Signals
         gLinkTx          => gLinkTx,
         txClk            => txClock,
         txRst            => txRst,
         txReady          => open,
         -- RX Signals
         gLinkRx          => gLinkRx,
         rxClk            => rxClock,
         rxRecClk         => rxRecClk,
         rxRst            => stableRst,
         rxMmcmRst        => open,
         rxMmcmLocked     => '1',
         rxReady          => open,
         -- MGT Clocking
         stableClk        => stableClock,
         gtCPllRefClk     => gtCPllRefClk,
         gtCPllLock       => gtCPllLock,
         gtQPllRefClk     => qPllOutRefClk,
         gtQPllClk        => qPllOutClk,
         gtQPllLock       => qPllLock,
         gtQPllRefClkLost => qPllRefClkLost,
         gtQPllReset      => gtQPllReset,
         -- MGT loopback control
         loopback         => "001",
         -- MGT Serial IO
         gtTxP            => open,
         gtTxN            => open,
         gtRxP            => '1',
         gtRxN            => '0');            

end testbed;
