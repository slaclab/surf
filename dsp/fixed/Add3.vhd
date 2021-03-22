-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 3 input add/sub module y = +/- a +/- b + c
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

entity add3 is
  generic (
      TPD_G        : time    := 1 ns;
      REG_IN_G     : boolean := false;
      REG_OUT_G    : boolean := true;
      NEGATIVE_A_G : boolean := false;
      NEGATIVE_B_G : boolean := false;
      EXTRA_MSB_G  : integer := 2);
  port (
      clk : in  sl;
      rst : in  sl := '0';
      a   : in  sfixed;
      b   : in  sfixed;
      c   : in  sfixed;
      y   : out sfixed);   -- y = +/- a +/- a + C
end add3;

architecture rtl of add3 is

   constant INT_OVERFLOW_STYLE_C : fixed_overflow_style_type := fixed_wrap;
   constant INT_ROUNDING_STYLE_C : fixed_round_style_type    := fixed_truncate;

   constant HIGH_ARRAY_C : IntegerArray(2 downto 0) := (
      0 => a'high,
      1 => b'high,
      2 => c'high);

   constant LOW_ARRAY_C  : IntegerArray(2 downto 0) := (
      0 => a'low,
      1 => b'low,
      2 => c'low);

   constant HIGH_BIT_C : integer := maximum(HIGH_ARRAY_C) + EXTRA_MSB_G;
   constant MED_BIT_C  : integer := median(LOW_ARRAY_C);
   constant LOW_BIT_C  : integer := minimum(LOW_ARRAY_C);

   type RegType is record
      a   : sfixed(a'range);
      b   : sfixed(b'range);
      c   : sfixed(c'range);
      sum : sfixed(y'range);
   end record RegType;

   constant REG_INIT_C : RegType := (
      a   => (others => '0'),
      b   => (others => '0'),
      c   => (others => '0'),
      sum => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

  comb : process( a, b, c, r ) is
      variable v   : RegType;
      variable sum : sfixed(HIGH_BIT_C downto LOW_BIT_C);
  begin

      v     := r;

      v.a   := a;
      v.b   := b;
      v.c   := c;

      if REG_IN_G then
         sum := resize(r.c, sum, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
         IF NEGATIVE_A_G then
            sum := resize(sum - r.a, sum, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
         else
            sum := resize(sum + r.a, sum, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
         end if;
         IF NEGATIVE_B_G then
            sum := resize(sum - r.b, sum, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
         else
            sum := resize(sum + r.b, sum, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
         end if;
      else
         sum := resize(v.c, sum, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
         IF NEGATIVE_A_G then
            sum := resize(sum - v.a, sum, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
         else
            sum := resize(sum + v.a, sum, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
         end if;
         IF NEGATIVE_B_G then
            sum := resize(sum - v.b, sum, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
         else
            sum := resize(sum + v.b, sum, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
         end if;
      end if;

      v.sum := resize(sum, v.sum, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);

      rin <= v;

      if REG_OUT_G then
          y <= r.sum;
      else
          y <= v.sum;
      end if;

  end process comb;

  seq : process ( clk ) is
  begin

      if rising_edge(clk) then
         if rst = '1' then
            r <= REG_INIT_C after TPD_G;
         else
            r <= rin after TPD_G;
         end if;
      end if;
  end process seq;

end rtl;
