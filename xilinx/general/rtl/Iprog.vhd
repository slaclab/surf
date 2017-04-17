-------------------------------------------------------------------------------
-- File       : Iprog.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-18
-- Last update: 2016-12-01
-------------------------------------------------------------------------------
-- Description: Wrapper for the ICAP Module to issue IPROG command
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
use work.TextUtilPkg.all;

entity Iprog is
   generic (
      TPD_G          : time     := 1 ns;
      XIL_DEVICE_G   : string   := "7SERIES";  -- Either "7SERIES" or "ULTRASCALE"
      USE_SLOWCLK_G  : boolean  := false;
      BUFR_CLK_DIV_G : positive := 8;
      RST_POLARITY_G : sl       := '1');
   port (
      clk         : in sl;
      rst         : in sl;
      slowClk     : in sl               := '0';
      start       : in sl;
      bootAddress : in slv(31 downto 0) := X"00000000");
end Iprog;

architecture rtl of Iprog is

   component Iprog7Series is
      generic (
         TPD_G          : time;
         USE_SLOWCLK_G  : boolean;
         BUFR_CLK_DIV_G : string);
      port (
         clk         : in sl;
         rst         : in sl;
         slowClk     : in sl               := '0';
         start       : in sl;
         bootAddress : in slv(31 downto 0) := X"00000000");
   end component Iprog7Series;

   component IprogUltraScale is
      generic (
         TPD_G          : time;
         USE_SLOWCLK_G  : boolean;
         BUFR_CLK_DIV_G : natural;
         RST_POLARITY_G : sl);
      port (
         clk         : in sl;
         rst         : in sl;
         slowClk     : in sl               := '0';
         start       : in sl;
         bootAddress : in slv(31 downto 0) := X"00000000");
   end component IprogUltraScale;


begin

   GEN_7SERIES : if (XIL_DEVICE_G = "7SERIES") generate
      Iprog7Series_Inst : Iprog7Series
         generic map (
            TPD_G          => TPD_G,
            USE_SLOWCLK_G  => USE_SLOWCLK_G,
            BUFR_CLK_DIV_G => str(BUFR_CLK_DIV_G, 10))
         port map (
            clk         => clk,
            rst         => rst,
            slowClk     => slowClk,
            start       => start,
            bootAddress => bootAddress);
   end generate;

   GEN_ULTRA_SCALE : if (XIL_DEVICE_G = "ULTRASCALE") generate
      IprogUltraScale_Inst : IprogUltraScale
         generic map (
            TPD_G          => TPD_G,
            USE_SLOWCLK_G  => USE_SLOWCLK_G,
            BUFR_CLK_DIV_G => BUFR_CLK_DIV_G,
            RST_POLARITY_G => RST_POLARITY_G)
         port map (
            clk         => clk,
            rst         => rst,
            slowClk     => slowClk,
            start       => start,
            bootAddress => bootAddress);
   end generate;

end rtl;
