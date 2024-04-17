-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: complex multiplier add/accumulator.  Will use 4 real multipliers
--              (27x18 DSP48).  Supports inputs up to 27x18.
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
use ieee.fixed_pkg.all;
use ieee.fixed_float_types.all;

library surf;
use surf.StdRtlPkg.all;
use surf.ComplexFixedPkg.all;

-- complex multiply (accumulater)
-- Uses 4 real multipliers (18x27 for DSP48)
--
-- p(n) = a(n-4)*b(n-4)                         (ACCUMULATE_G = false, RND_SIMPLE_G = false)
-- p(n) = a(n-4)*b(n-4) + RND_SIMPLE_C          (ACCUMULATE_G = false, RND_SIMPLE_G = true)
--
-- p(n) = a(n-4)*b(n-4) + p(n-1)                (ACCUMULATE_G = true, RND_SIMPLE_G = false)
-- p(n) = a(n-4)*b(n-4) + RND_SIMPLE_C + p(n-1) (ACCUMULATE_G = true, RND_SIMPLE_G = true)
--
-- optionally add one more delay register for output y
--    (move data out of preg into fabric)
--
-- y(n) = p(n)     ( REG_OUT_G = false )
-- y(n) = p(n-1)   ( REG_OUT_G = true )
--
-- Defaults to wrap and trucnated output for size(y)

entity cfixedMult is
   generic (
      TPD_G                : time                      := 1 ns;
      SWAP_INP_A_G         : boolean                   := false;
      SWAP_INP_B_G         : boolean                   := false;
      REG_OUT_G            : boolean                   := false;
      RND_SIMPLE_G         : boolean                   := false;
      ACCUMULATE_G         : boolean                   := false;
      OUT_OVERFLOW_STYLE_G : fixed_overflow_style_type := fixed_wrap;
      OUT_ROUNDING_STYLE_G : fixed_round_style_type    := fixed_truncate);
   port (
      clk  : in  sl;
      rst  : in  sl := '0';
      a    : in  cfixed;
      aVld : in  sl := '0';
      b    : in  cfixed;
      bVld : in  sl := '0';
      y    : out cfixed;
      yVld : out sl);
end entity cfixedMult;

architecture rtl of cfixedMult is

   constant C_HIGH_BIT_C : integer := a.re'high + b.re'high + 1;
   constant C_LOW_BIT_C  : integer := a.re'low  + b.re'low;

   signal c    : cfixed( re(C_HIGH_BIT_C downto C_LOW_BIT_C), im(C_HIGH_BIT_C downto C_LOW_BIT_C)) := (
         re => (others => '0'),
         im => (others => '0'));

   signal cVld : sl := '1';

   signal aInt : cfixed(re(a.re'range), im(a.im'range));
   signal bInt : cfixed(re(b.re'range), im(b.im'range));

begin

   aInt <= swap(a) when SWAP_INP_A_G else a;
   bInt <= swap(b) when SWAP_INP_B_G else b;

   GEN_RND_SIMPLE : if RND_SIMPLE_G generate
      c.re(y.re'low - 1) <= '1';
      c.im(y.im'low - 1) <= '1';
   end generate GEN_RND_SIMPLE;

   U_MULT_ADD : entity surf.CfixedMultAdd
      generic map (
         TPD_G                => TPD_G,
         REG_OUT_G            => REG_OUT_G,
         CIN_REG_G            => 1,
         ACCUMULATE_G         => ACCUMULATE_G,
         OUT_OVERFLOW_STYLE_G => OUT_OVERFLOW_STYLE_G,
         OUT_ROUNDING_STYLE_G => OUT_ROUNDING_STYLE_G)
      port map (
         clk  => clk,
         rst  => rst,
         a    => aInt,
         aVld => aVld,
         b    => bInt,
         bVld => bVld,
         c    => c,
         cVld => cVld,
         y    => y,
         yVld => yVld);

end architecture rtl;
