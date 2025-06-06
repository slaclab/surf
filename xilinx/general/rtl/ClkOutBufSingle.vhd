-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Special buffer for outputting a clock on Xilinx FPGA pins.
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

library unisim;
use unisim.vcomponents.all;

entity ClkOutBufSingle is
   generic (
      TPD_G          : time    := 1 ns;
      XIL_DEVICE_G   : string  := "7SERIES";  -- Either "7SERIES" or "ULTRASCALE" or "ULTRASCALE_PLUS"
      RST_POLARITY_G : sl      := '1';
      INVERT_G       : boolean := false);
   port (
      rstIn  : in  sl := not RST_POLARITY_G;  -- Optional reset
      outEnL : in  sl := '0';  -- optional tristate (0 = enabled, 1 = high z output)
      clkIn  : in  sl;
      clkOut : out sl);                 -- Single ended output buffer
end ClkOutBufSingle;

architecture rtl of ClkOutBufSingle is

   signal clkDdr : sl;
   signal rst    : sl;

begin

   assert (XIL_DEVICE_G = "7SERIES" or XIL_DEVICE_G = "ULTRASCALE" or XIL_DEVICE_G = "ULTRASCALE_PLUS")
      report "XIL_DEVICE_G must be either [7SERIES,ULTRASCALE,ULTRASCALE_PLUS]" severity failure;

   rst <= rstIn when(RST_POLARITY_G = '1') else not(rstIn);

   GEN_7SERIES : if (XIL_DEVICE_G = "7SERIES") generate
      ODDR_I : ODDR
         port map (
            C  => clkIn,
            Q  => clkDdr,
            CE => '1',
            D1 => toSl(not INVERT_G),
            D2 => toSl(INVERT_G),
            R  => rst,
            S  => '0');
   end generate;

   GEN_ULTRA_SCALE : if (XIL_DEVICE_G = "ULTRASCALE") or (XIL_DEVICE_G = "ULTRASCALE_PLUS") generate
      ODDR_I : ODDRE1
         port map (
            C  => clkIn,
            Q  => clkDdr,
            D1 => toSl(not INVERT_G),
            D2 => toSl(INVERT_G),
            SR => rst);
   end generate;

   -- Single ended output buffer
   OBUFT_I : OBUFT
      port map (
         I => clkDdr,
         T => outEnL,
         O => clkOut);

end rtl;
