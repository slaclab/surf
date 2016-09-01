-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiAd9467Pll.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-10-02
-- Last update: 2014-09-24
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
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

   constant ADC_CLK_PERIOD_C    : real := getRealDiv(1, ADC_CLK_FREQ_G);
   constant ADC_CLK_PERIOD_NS_C : real := getRealMult(1.0E+9, ADC_CLK_PERIOD_C);
   constant CLKFBOUT_MULT_F_C   : real := getRealDiv(1.0E+9, ADC_CLK_FREQ_G);

   signal clkFeedBackIn,
      clkFeedBack,
      clkFeedBackOut : sl;
   
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
