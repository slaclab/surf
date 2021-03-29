-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: sfixed accumultaor, supports interleaved channels
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
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;
use ieee.fixed_float_types.all;

library surf;
use surf.StdRtlPkg.all;

entity ComplexAccumulator is
   generic (
      TPD_G         : time    := 1 ns;
      XIL_DEVICE_G  : string  := "ULTRASCALE_PLUS";
      ILEAVE_CHAN_G : integer := 1;
      REG_IN_G      : boolean := true;
      REG_OUT_G     : boolean := true);
   port (
      clk       : in  sl;
      rst       : in  sl := '0';
      -- inputs
      validIn   : in  sl;
      userIn    : in  slv;
      din       : in  cfixed;
      -- outputs
      validOut  : out sl;
      userOut   : out slv;
      dout      : out cfixed);
end entity ComplexAccumulator;

architecture rtl of ComplexAccumulator is

begin

   U_REAL_ACCUM : entity surf.Accumulator
      generic map (
         TPD_G         => TPD_G,
         XIL_DEVICE_G  => XIL_DEVICE_G,
         ILEAVE_CHAN_G => ILEAVE_CHAN_G,
         REG_IN_G      => REG_IN_G,
         REG_OUT_G     => REG_OUT_G)
      port map (
         clk           => clk,
         rst           => rst,
         -- inputs
         validIn       => validIn,
         userIn        => userIn,
         din           => din.re,
         -- outputs
         validOut      => validOut,
         userOut       => userOut,
         dout          => dout.re);

   U_REAL_ACCUM : entity surf.Accumulator
      generic map (
         TPD_G         => TPD_G,
         XIL_DEVICE_G  => XIL_DEVICE_G,
         ILEAVE_CHAN_G => ILEAVE_CHAN_G,
         REG_IN_G      => REG_IN_G,
         REG_OUT_G     => REG_OUT_G)
      port map (
         clk           => clk,
         rst           => rst,
         -- inputs
         validIn       => validIn,
         userIn        => userIn,
         din           => din.im,
         -- outputs
         validOut      => open,
         userOut       => open,
         dout          => dout.im);

end architecture rtl;