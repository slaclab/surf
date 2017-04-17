-------------------------------------------------------------------------------
-- File       : TenGigEthGtx7Clk.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-03-30
-- Last update: 2016-05-19
-------------------------------------------------------------------------------
-- Description: 10GBASE-R Ethernet's Clock Module
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

library unisim;
use unisim.vcomponents.all;

entity TenGigEthGtx7Clk is
   generic (
      TPD_G             : time       := 1 ns;
      USE_GTREFCLK_G    : boolean    := false;  --  FALSE: gtClkP/N,  TRUE: gtRefClk
      REFCLK_DIV2_G     : boolean    := false;  --  FALSE: gtClkP/N = 156.25 MHz,  TRUE: gtClkP/N = 312.5 MHz
      QPLL_REFCLK_SEL_G : bit_vector := "001");
   port (
      -- Clocks and Resets
      extRst        : in  sl;           -- async reset
      phyClk        : out sl;
      phyRst        : out sl;
      -- MGT Clock Port (156.25 MHz or 312.5 MHz)
      gtRefClk      : in  sl := '0';    -- 156.25 MHz only
      gtClkP        : in  sl := '1';
      gtClkN        : in  sl := '0';
      gtClk         : out sl;
      -- Quad PLL Ports
      qplllock      : out sl;
      qplloutclk    : out sl;
      qplloutrefclk : out sl;
      qpllRst       : in  sl);      
end TenGigEthGtx7Clk;

architecture mapping of TenGigEthGtx7Clk is

   constant QPLL_REFCLK_SEL_C : bit_vector := ite(USE_GTREFCLK_G, "111", QPLL_REFCLK_SEL_G);

   signal refClockDiv2 : sl;
   signal refClock     : sl;
   signal refClk       : sl;
   signal phyClock     : sl;
   signal phyReset     : sl;
   signal pwrUpRst     : sl;
   signal qpllReset    : sl;
   
begin
   
   gtClk  <= refClk;
   phyClk <= phyClock;
   phyRst <= phyReset;

   qpllReset <= qpllRst or pwrUpRst;

   PwrUpRst_Inst : entity work.PwrUpRst
      generic map (
         TPD_G      => TPD_G,
         DURATION_G => 15625000)        -- 100 ms
      port map (
         arst   => extRst,
         clk    => phyClock,
         rstOut => pwrUpRst);      

   Synchronizer_0 : entity work.Synchronizer
      generic map(
         TPD_G          => TPD_G,
         RST_ASYNC_G    => true,
         RST_POLARITY_G => '1',
         STAGES_G       => 4,
         INIT_G         => "1111")
      port map (
         clk     => phyClock,
         rst     => extRst,
         dataIn  => '0',
         dataOut => phyReset);    

   IBUFDS_GTE2_Inst : IBUFDS_GTE2
      port map (
         I     => gtClkP,
         IB    => gtClkN,
         CEB   => '0',
         ODIV2 => refClockDiv2,
         O     => refClock);  

   refClk <= gtRefClk when (USE_GTREFCLK_G) else refClockDiv2 when(REFCLK_DIV2_G) else refClock;

   CLK156_BUFG : BUFG
      port map (
         I => refClk,
         O => phyClock);        

   Gtx7QuadPll_Inst : entity work.Gtx7QuadPll
      generic map (
         TPD_G               => TPD_G,
         SIM_RESET_SPEEDUP_G => "TRUE",        --Does not affect hardware
         SIM_VERSION_G       => "4.0",
         QPLL_CFG_G          => x"0680181",
         QPLL_REFCLK_SEL_G   => QPLL_REFCLK_SEL_C,
         QPLL_FBDIV_G        => "0101000000",  -- 64B/66B Encoding
         QPLL_FBDIV_RATIO_G  => '0',           -- 64B/66B Encoding
         QPLL_REFCLK_DIV_G   => 1)    
      port map (
         qPllRefClk     => refClk,             -- 156.25 MHz
         qPllOutClk     => qPllOutClk,
         qPllOutRefClk  => qPllOutRefClk,
         qPllLock       => qPllLock,
         qPllLockDetClk => '0',                -- IP Core ties this to GND (see note below) 
         qPllRefClkLost => open,
         qPllPowerDown  => '0',
         qPllReset      => qpllReset);          
   ---------------------------------------------------------------------------------------------
   -- Note: GTXE2_COMMON pin gtxe2_common_0_i.QPLLLOCKDETCLK cannot be driven by a clock derived 
   --       from the same clock used as the reference clock for the QPLL, including TXOUTCLK*, 
   --       RXOUTCLK*, the output from the IBUFDS_GTE2 providing the reference clock, and any 
   --       buffered or multiplied/divided versions of these clock outputs. Please see UG476 for 
   --       more information. Source, through a clock buffer, is the same as the GT cell 
   --       reference clock.
   ---------------------------------------------------------------------------------------------
   
end mapping;
