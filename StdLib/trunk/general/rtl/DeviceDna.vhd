-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DeviceDna.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-17
-- Last update: 2015-06-17
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Wrapper for the DNA_PORT
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

entity DeviceDna is
   generic (
      TPD_G           : time   := 1 ns;
      XIL_DEVICE_G    : string := "7SERIES";
      SIM_DNA_VALUE_G : slv    := X"000000000000000000000000";
      IN_POLARITY_G   : sl     := '1');
   port (
      clk      : in  sl;
      rst      : in  sl;
      dnaValue : out slv(63 downto 0);
      dnaValid : out sl);
end DeviceDna;

architecture rtl of DeviceDna is

begin

   GEN_7SERIES : if (XIL_DEVICE_G = "7SERIES") generate
      DeviceDna7Series_Inst : entity work.DeviceDna7Series
         generic map (
            TPD_G           => TPD_G,
            IN_POLARITY_G   => IN_POLARITY_G,
            SIM_DNA_VALUE_G => to_bitvector(SIM_DNA_VALUE_G))   
         port map (
            clk      => clk,
            rst      => rst,
            dnaValue => dnaValue,
            dnaValid => dnaValid);
   end generate;

   GEN_ULTRA_SCALE : if (XIL_DEVICE_G = "ULTRASCALE") generate
      DeviceDnaUltraScale_Inst : entity work.DeviceDnaUltraScale
         generic map (
            TPD_G           => TPD_G,
            IN_POLARITY_G   => IN_POLARITY_G,
            SIM_DNA_VALUE_G => SIM_DNA_VALUE_G)   
         port map (
            clk      => clk,
            rst      => rst,
            dnaValue => dnaValue,
            dnaValid => dnaValid);
   end generate;

end rtl;
