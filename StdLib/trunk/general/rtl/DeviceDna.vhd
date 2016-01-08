-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DeviceDna.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-17
-- Last update: 2015-06-18
-- Platform   : 
-- Standard   : VHDL'93/02
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

use work.StdRtlPkg.all;

entity DeviceDna is
   generic (
      TPD_G           : time    := 1 ns;
      XIL_DEVICE_G    : string  := "7SERIES";  -- Either "7SERIES" or "ULTRASCALE"
      USE_SLOWCLK_G   : boolean := false;
      RST_POLARITY_G  : sl      := '1';
      SIM_DNA_VALUE_G : slv     := X"000000000000000000000000");
   port (
      clk      : in  sl;
      rst      : in  sl;
      slowClk  : in  sl := '0';
      dnaValue : out slv(63 downto 0);
      dnaValid : out sl);
end DeviceDna;

architecture rtl of DeviceDna is

begin

   GEN_7SERIES : if (XIL_DEVICE_G = "7SERIES") generate
      DeviceDna7Series_Inst : entity work.DeviceDna7Series
         generic map (
            TPD_G           => TPD_G,
            USE_SLOWCLK_G   => USE_SLOWCLK_G,
            RST_POLARITY_G  => RST_POLARITY_G,
            SIM_DNA_VALUE_G => to_bitvector(SIM_DNA_VALUE_G))   
         port map (
            clk      => clk,
            rst      => rst,
            slowClk  => slowClk,
            dnaValue => dnaValue,
            dnaValid => dnaValid);
   end generate;

   GEN_ULTRA_SCALE : if (XIL_DEVICE_G = "ULTRASCALE") generate
      DeviceDnaUltraScale_Inst : entity work.DeviceDnaUltraScale
         generic map (
            TPD_G           => TPD_G,
            USE_SLOWCLK_G   => USE_SLOWCLK_G,
            RST_POLARITY_G  => RST_POLARITY_G,
            SIM_DNA_VALUE_G => SIM_DNA_VALUE_G)   
         port map (
            clk      => clk,
            rst      => rst,
            slowClk  => slowClk,
            dnaValue => dnaValue,
            dnaValid => dnaValid);
   end generate;

end rtl;
