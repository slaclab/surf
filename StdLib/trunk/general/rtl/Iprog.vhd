-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Iprog.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-18
-- Last update: 2015-09-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Wrapper for the IPROG Module
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

entity Iprog is
   generic (
      TPD_G          : time    := 1 ns;
      XIL_DEVICE_G   : string  := "7SERIES";  -- Either "7SERIES" or "ULTRASCALE"
      USE_SLOWCLK_G  : boolean := false;
      RST_POLARITY_G : sl      := '1');      
   port (
      clk         : in sl;
      rst         : in sl;
      slowClk     : in sl               := '0';
      start       : in sl;
      bootAddress : in slv(31 downto 0) := X"00000000");
end Iprog;

architecture rtl of Iprog is

begin

   GEN_7SERIES : if (XIL_DEVICE_G = "7SERIES") generate
      Iprog7Series_Inst : entity work.Iprog7Series
         generic map (
            TPD_G          => TPD_G,
            USE_SLOWCLK_G  => USE_SLOWCLK_G)
         port map (
            clk         => clk,
            rst         => rst,
            slowClk     => slowClk,
            start       => start,
            bootAddress => bootAddress);
   end generate;

   GEN_ULTRA_SCALE : if (XIL_DEVICE_G = "ULTRASCALE") generate
      IprogUltraScale_Inst : entity work.IprogUltraScale
         generic map (
            TPD_G          => TPD_G,
            USE_SLOWCLK_G  => USE_SLOWCLK_G,
            RST_POLARITY_G => RST_POLARITY_G)   
         port map (
            clk         => clk,
            rst         => rst,
            slowClk     => slowClk,
            start       => start,
            bootAddress => bootAddress);
   end generate;

end rtl;
