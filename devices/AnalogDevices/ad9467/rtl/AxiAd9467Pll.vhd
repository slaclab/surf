-------------------------------------------------------------------------------
-- File       : AxiAd9467Core.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-09-23
-- Last update: 2014-09-24
-------------------------------------------------------------------------------
-- Description: AD9467 PLL Module
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

entity AxiAd9467Pll is
   generic (
      TPD_G          : time := 1 ns;
      ADC_CLK_FREQ_G : real := 250.0E+6);
   port (
      -- ADC Clocking ports
      adcClkOutP : out sl;
      adcClkOutN : out sl;
      adcClkInP  : in  sl;
      adcClkInN  : in  sl;
      -- PLL Status
      pllLocked  : out sl;
      -- ADC Reference Signals
      adcClk     : in  sl;
      adcRst     : in  sl);
end AxiAd9467Pll;

architecture mapping of AxiAd9467Pll is

   constant ADC_CLK_PERIOD_C    : real := 1.0 / ADC_CLK_FREQ_G;
   constant ADC_CLK_PERIOD_NS_C : real := 1.0E+9 * ADC_CLK_PERIOD_C;
   constant CLKFBOUT_MULT_F_C   : real := 1.0E+9 / ADC_CLK_FREQ_G;

   signal clkFeedBackIn  : sl;
   signal clkFeedBack    : sl;
   signal clkFeedBackOut : sl;

begin

   IBUFGDS_Inst : IBUFGDS
      port map (
         I  => adcClkInP,
         IB => adcClkInN,
         O  => clkFeedBackIn);

   MMCME2_ADV_Inst : MMCME2_ADV
      generic map(
         BANDWIDTH            => "LOW",
         CLKOUT4_CASCADE      => false,
         COMPENSATION         => "ZHOLD",
         STARTUP_WAIT         => false,
         DIVCLK_DIVIDE        => 1,
         CLKFBOUT_MULT_F      => CLKFBOUT_MULT_F_C,
         CLKFBOUT_PHASE       => 0.000,
         CLKFBOUT_USE_FINE_PS => false,
         CLKIN1_PERIOD        => ADC_CLK_PERIOD_NS_C,
         REF_JITTER1          => 0.100)
      port map (
         -- Output clocks
         CLKFBOUT     => clkFeedBack,
         CLKFBOUTB    => open,
         CLKOUT0      => open,
         CLKOUT0B     => open,
         CLKOUT1      => open,
         CLKOUT1B     => open,
         CLKOUT2      => open,
         CLKOUT2B     => open,
         CLKOUT3      => open,
         CLKOUT3B     => open,
         CLKOUT4      => open,
         CLKOUT5      => open,
         CLKOUT6      => open,
         -- Input clock control
         CLKFBIN      => clkFeedBackIn,
         CLKIN1       => adcClk,
         CLKIN2       => '0',
         -- Tied to always select the primary input clock
         CLKINSEL     => '1',
         -- Ports for dynamic reconfiguration
         DADDR        => (others => '0'),
         DCLK         => '0',
         DEN          => '0',
         DI           => (others => '0'),
         DO           => open,
         DRDY         => open,
         DWE          => '0',
         -- Ports for dynamic phase shift
         PSCLK        => '0',
         PSEN         => '0',
         PSINCDEC     => '0',
         PSDONE       => open,
         -- Other control and status signals
         LOCKED       => pllLocked,
         CLKINSTOPPED => open,
         CLKFBSTOPPED => open,
         PWRDWN       => '0',
         RST          => adcRst);

   BUFH_West : BUFH
      port map (
         I => clkFeedBack,
         O => clkFeedBackOut);

   ClkOutBufDiff_Inst : entity work.ClkOutBufDiff
      port map (
         clkIn   => clkFeedBackOut,
         clkOutP => adcClkOutP,
         clkOutN => adcClkOutN);

end mapping;
