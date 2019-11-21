-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for the DNA_PORT
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


library surf;
use surf.StdRtlPkg.all;
use surf.TextUtilPkg.all;

entity DeviceDna is
   generic (
      TPD_G           : time     := 1 ns;
      XIL_DEVICE_G   : string   := "7SERIES";  -- Either "7SERIES" or "ULTRASCALE" or "ULTRASCALE_PLUS"
      USE_SLOWCLK_G   : boolean  := false;
      BUFR_CLK_DIV_G  : positive := 8;
      RST_POLARITY_G  : sl       := '1';
      SIM_DNA_VALUE_G : slv      := X"000000000000000000000000");
   port (
      clk      : in  sl;
      rst      : in  sl;
      slowClk  : in  sl := '0';
      dnaValue : out slv(127 downto 0);
      dnaValid : out sl);
end DeviceDna;

architecture rtl of DeviceDna is

   component DeviceDna7Series is
      generic (
         TPD_G           : time;
         USE_SLOWCLK_G   : boolean;
         BUFR_CLK_DIV_G  : string;
         RST_POLARITY_G  : sl;
         SIM_DNA_VALUE_G : bit_vector);
      port (
         clk      : in  sl;
         rst      : in  sl;
         slowClk  : in  sl := '0';
         dnaValue : out slv(55 downto 0);
         dnaValid : out sl);
   end component DeviceDna7Series;
   
   component DeviceDnaUltraScale is
      generic (
         TPD_G           : time;
         USE_SLOWCLK_G   : boolean;
         BUFR_CLK_DIV_G  : natural;
         RST_POLARITY_G  : sl;
         SIM_DNA_VALUE_G : slv);
      port (
         clk      : in  sl;
         rst      : in  sl;
         slowClk  : in  sl := '0';
         dnaValue : out slv(95 downto 0);
         dnaValid : out sl);
   end component DeviceDnaUltraScale;
   
begin

   assert (XIL_DEVICE_G ="7SERIES" or XIL_DEVICE_G ="ULTRASCALE" or XIL_DEVICE_G ="ULTRASCALE_PLUS") 
      report "XIL_DEVICE_G must be either [7SERIES,ULTRASCALE,ULTRASCALE_PLUS]" severity failure;

   GEN_7SERIES : if (XIL_DEVICE_G = "7SERIES") generate
      DeviceDna7Series_Inst : DeviceDna7Series
         generic map (
            TPD_G           => TPD_G,
            USE_SLOWCLK_G   => USE_SLOWCLK_G,
            BUFR_CLK_DIV_G  => str(BUFR_CLK_DIV_G, 10),
            RST_POLARITY_G  => RST_POLARITY_G,
            SIM_DNA_VALUE_G => to_bitvector(SIM_DNA_VALUE_G))   
         port map (
            clk      => clk,
            rst      => rst,
            slowClk  => slowClk,
            dnaValue => dnaValue(55 downto 0),
            dnaValid => dnaValid);
      dnaValue(127 downto 56) <= (others=>'0');
   end generate;

   GEN_ULTRA_SCALE : if (XIL_DEVICE_G = "ULTRASCALE") or (XIL_DEVICE_G = "ULTRASCALE_PLUS") generate
      DeviceDnaUltraScale_Inst : DeviceDnaUltraScale
         generic map (
            TPD_G           => TPD_G,
            USE_SLOWCLK_G   => USE_SLOWCLK_G,
            BUFR_CLK_DIV_G  => BUFR_CLK_DIV_G,
            RST_POLARITY_G  => RST_POLARITY_G,
            SIM_DNA_VALUE_G => SIM_DNA_VALUE_G)   
         port map (
            clk      => clk,
            rst      => rst,
            slowClk  => slowClk,
            dnaValue => dnaValue(95 downto 0),
            dnaValid => dnaValid);
      dnaValue(127 downto 96) <= (others=>'0');
   end generate;

end rtl;
