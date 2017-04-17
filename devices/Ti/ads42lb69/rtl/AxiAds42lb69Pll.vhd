-------------------------------------------------------------------------------
-- File       : AxiAds42lb69Pll.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-03-20
-- Last update: 2016-09-20
-------------------------------------------------------------------------------
-- Description: PLL Module
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

entity AxiAds42lb69Pll is
   generic (
      TPD_G          : time    := 1 ns;
      USE_PLL_G      : boolean := true;
      ADC_CLK_FREQ_G : real    := 250.0E+6);
   port (
      -- ADC Clocking ports
      adcClkP   : out sl;
      adcClkN   : out sl;
      adcSyncP  : out sl;
      adcSyncN  : out sl;
      adcClkFbP : in  sl;
      adcClkFbN : in  sl;
      -- ADC Reference Signals
      adcSync   : in  sl;
      adcClk    : in  sl;
      adcRst    : in  sl;              
      adcClock  : out  sl);                
end AxiAds42lb69Pll;

architecture mapping of AxiAds42lb69Pll is

   constant ADC_CLK_PERIOD_NS_C : real := 1.0E+9 / ADC_CLK_FREQ_G;

   signal clkFeedBack    : sl;
   signal clkFeedBackIn  : sl;
   signal clkFeedBackOut : sl;

   signal sync     : sl;
   signal syncOut  : sl;
   signal adcInClk : sl;

begin

   GEN_PLL : if (USE_PLL_G = true) generate

      IBUFGDS_0 : IBUFGDS
         port map (
            I  => adcClkFbP,
            IB => adcClkFbN,
            O  => clkFeedBackIn);

      MMCME2_ADV_0 : MMCME2_ADV
         generic map(
            BANDWIDTH            => "LOW",
            CLKOUT4_CASCADE      => false,
            COMPENSATION         => "ZHOLD",
            STARTUP_WAIT         => false,
            DIVCLK_DIVIDE        => 1,
            CLKFBOUT_MULT_F      => ADC_CLK_PERIOD_NS_C,
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
            LOCKED       => open,
            CLKINSTOPPED => open,
            CLKFBSTOPPED => open,
            PWRDWN       => '0',
            RST          => adcRst);

      BUFH_0 : BUFH
         port map (
            I => clkFeedBack,
            O => clkFeedBackOut);     

      ClkOutBufDiff_0 : entity work.ClkOutBufDiff
         port map (
            clkIn   => clkFeedBackOut,
            clkOutP => adcClkP,
            clkOutN => adcClkN);

      SynchronizerOneShot_0 : entity work.SynchronizerOneShot
         generic map (
            TPD_G         => TPD_G,
            BYPASS_SYNC_G => false)
         port map (
            clk     => clkFeedBackOut,
            dataIn  => adcSync,
            dataOut => sync);

      ODDR_0 : ODDR
         generic map(
            DDR_CLK_EDGE => "OPPOSITE_EDGE",  -- "OPPOSITE_EDGE" or "SAME_EDGE" 
            INIT         => '0',              -- Initial value for Q port ('1' or '0')
            SRTYPE       => "SYNC")           -- Reset Type ("ASYNC" or "SYNC")
         port map (
            D1 => sync,                       -- 1-bit data input (positive edge)
            D2 => sync,                       -- 1-bit data input (negative edge)
            Q  => syncOut,                    -- 1-bit DDR output
            C  => clkFeedBackOut,             -- 1-bit clock input
            CE => '1',                        -- 1-bit clock enable input
            R  => '0',                        -- 1-bit reset
            S  => '0');                       -- 1-bit set

      OBUFDS_0 : OBUFDS
         port map(
            I  => syncOut,
            O  => adcSyncP,
            OB => adcSyncN);  

      adcClock <= adcClk;

   end generate;

   GEN_NO_PLL : if (USE_PLL_G = false) generate
      
      ClkOutBufDiff_1 : entity work.ClkOutBufDiff
         port map (
            clkIn   => adcClk,
            rstIn   => adcRst,
            clkOutP => adcClkP,
            clkOutN => adcClkN);   

      SynchronizerOneShot_1 : entity work.SynchronizerOneShot
         generic map (
            TPD_G         => TPD_G,
            BYPASS_SYNC_G => true)
         port map (
            clk     => adcClk,
            dataIn  => adcSync,
            dataOut => sync);

      ODDR_1 : ODDR
         generic map(
            DDR_CLK_EDGE => "OPPOSITE_EDGE",  -- "OPPOSITE_EDGE" or "SAME_EDGE" 
            INIT         => '0',              -- Initial value for Q port ('1' or '0')
            SRTYPE       => "SYNC")           -- Reset Type ("ASYNC" or "SYNC")
         port map (
            D1 => sync,                       -- 1-bit data input (positive edge)
            D2 => sync,                       -- 1-bit data input (negative edge)
            Q  => syncOut,                    -- 1-bit DDR output
            C  => adcClk,                     -- 1-bit clock input
            CE => '1',                        -- 1-bit clock enable input
            R  => '0',                        -- 1-bit reset
            S  => '0');                       -- 1-bit set

      OBUFDS_1 : OBUFDS
         port map(
            I  => syncOut,
            O  => adcSyncP,
            OB => adcSyncN);         

      IBUFGDS_1 : IBUFGDS
         port map (
            I  => adcClkFbP,
            IB => adcClkFbN,
            O  => adcInClk);

      BUFG_1 : BUFG
         port map (
            I => adcInClk,
            O => adcClock); 

   end generate;
   
end mapping;
