-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : TenGigEthGth7Clk.vhd
-- Author     : Larry Ruckman <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-03-30
-- Last update: 2015-04-06
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity TenGigEthGth7Clk is
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
      -- Quad PLL Ports
      qplllock      : out sl;
      qplloutclk    : out sl;
      qplloutrefclk : out sl;
      qpllRst       : in  sl);      
end TenGigEthGth7Clk;

architecture mapping of TenGigEthGth7Clk is

   constant QPLL_REFCLK_SEL_C : bit_vector := ite(USE_GTREFCLK_G,"111",QPLL_REFCLK_SEL_G);

   signal refClockDiv2 : sl;
   signal refClock     : sl;
   signal refClk       : sl;
   signal phyClock     : sl;
   signal phyReset     : sl;
   
begin

   phyClk <= phyClock;
   phyRst <= phyReset;

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

   Gth7QuadPll_Inst : entity work.Gth7QuadPll
      generic map (
         TPD_G               => TPD_G,
         SIM_RESET_SPEEDUP_G => "FALSE",       --Does not affect hardware
         SIM_VERSION_G       => "2.0",
         QPLL_CFG_G          => x"04801C7",
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
         qPllReset      => qpllRst);          
   ---------------------------------------------------------------------------------------------
   -- Note: GTXE2_COMMON pin gtxe2_common_0_i.QPLLLOCKDETCLK cannot be driven by a clock derived 
   --       from the same clock used as the reference clock for the QPLL, including TXOUTCLK*, 
   --       RXOUTCLK*, the output from the IBUFDS_GTE2 providing the reference clock, and any 
   --       buffered or multiplied/divided versions of these clock outputs. Please see UG476 for 
   --       more information. Source, through a clock buffer, is the same as the GT cell 
   --       reference clock.
   ---------------------------------------------------------------------------------------------
   
end mapping;
