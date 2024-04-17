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

-- complex multiply adder/accumulater
-- Uses 4 real multipliers (18x27 for DSP48)
--
-- p(n) = a(n-4)*b(n-4) + c(n-2)          (complex, CIN_REG_G = 0, ACCUMULATE_G = false)
-- p(n) = a(n-4)*b(n-4) + c(n-3)          (complex, CIN_REG_G = 1, ACCUMULATE_G = false)
-- p(n) = a(n-4)*b(n-4) + c(n-4)          (complex, CIN_REG_G = 2, ACCUMULATE_G = false)
--
-- p(n) = a(n-4)*b(n-4) + c(n-2) + p(n-1) (complex, CIN_REG_G = 0, ACCUMULATE_G = true)
-- p(n) = a(n-4)*b(n-4) + c(n-3) + p(n-1) (complex, CIN_REG_G = 1, ACCUMULATE_G = true)
-- p(n) = a(n-4)*b(n-4) + c(n-4) + p(n-1) (complex, CIN_REG_G = 2, ACCUMULATE_G = true)
--
-- optionally add one more delay register for output y
--    (move data out of preg into fabric)
--
-- y(n) = p(n)     ( REG_OUT_G = false )
-- y(n) = p(n-1)   ( REG_OUT_G = true )
--
-- Defaults to wrap and trucnated output for size(y)

entity cfixedMultAdd is
   generic (
      TPD_G                : time                      := 1 ns;
      REG_OUT_G            : boolean                   := false;
      CIN_REG_G            : integer range 0 to 2      := 2;
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
      c    : in  cfixed;
      cVld : in  sl := '0';
      -- outputs
      --acout : out cfixed;
      y    : out cfixed;
      yVld : out sl);
end entity cfixedMultAdd;

architecture rtl of cfixedMultAdd is

   constant DELAY_C  : natural := 4 + ite(REG_OUT_G, 1, 0);

   constant M_LOW_C  : integer := a.re'low + b.re'low;
   constant M_HIGH_C : integer := a.re'high + b.re'high + 1;

   constant P_W_C    : integer := 48;
   constant P_LOW_C  : integer := a.re'low + b.re'low;
   constant P_HIGH_C : integer := P_W_C + P_LOW_C - 1;

   -- For resizing into preg:
   constant INT_OVERFLOW_STYLE_C : fixed_overflow_style_type := fixed_wrap;
   constant INT_ROUNDING_STYLE_C : fixed_round_style_type    := fixed_truncate;

   type RegType is record
      areg : cfixedArray(1 downto 0)(re(a.re'range), im(a.im'range));
      breg : cfixedArray(1 downto 0)(re(b.re'range), im(b.im'range));
      creg : cfixedArray(2 downto 0)(re(c.re'range), im(c.im'range)); -- add one extra element so we can index with CIN_REG_G
      p_rr, p_ii, p_ri, p_ir : sfixed(P_HIGH_C downto P_LOW_C);
      m_rr, m_ii, m_ri, m_ir : sfixed(M_HIGH_C downto M_LOW_C);
      y         : cfixed(re(y.re'range), im(y.im'range));
      yVld     : slv(DELAY_C-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      areg  => (others => (others => (others => '0'))),
      breg  => (others => (others => (others => '0'))),
      creg  => (others => (others => (others => '0'))),
      m_rr  => (others => '0'),
      m_ii  => (others => '0'),
      m_ri  => (others => '0'),
      m_ir  => (others => '0'),
      p_rr  => (others => '0'),
      p_ii  => (others => '0'),
      p_ri  => (others => '0'),
      p_ir  => (others => '0'),
      y     => (others => (others => '0')),
      yVld => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   assert ((a.re'length < 28) and (b.re'length < 19)) or ((a.re'length < 19) and (b.re'length < 28))
       report "Input data should be less than 18x27 bits" severity failure;

   comb : process( a, b, c, aVld, bVld, cVld, r ) is
      variable v : RegType;
   begin

      v := r;

      v.yVld(0) := aVld and bVld;
      for i in r.yVld'left downto 1 loop
         v.yVld(i) := r.yVld(i-1);
      end loop;
      -- C PATH has configurable 2...4 c-c delay
      v.yVld(r.yVld'left-1-CIN_REG_G) := v.yVld(r.yVld'left-1-CIN_REG_G) and cVld;


      -- A B and C input registers 2 deep
      v.areg(0) := a;
      v.areg(1) := r.areg(0);
      v.breg(0) := b;
      v.breg(1) := r.breg(0);

      v.creg(0) := c;
      for i in r.creg'left downto 1 loop
         v.creg(i) := r.creg(i-1);
      end loop;


      -- Real part of cfixedMultAdd
      v.m_ii := r.areg(0).im * r.breg(0).im;
      v.p_ii := resize(r.m_ii - v.creg(CIN_REG_G).re, r.p_ii, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
      v.m_rr := r.areg(1).re * r.breg(1).re;
      if ACCUMULATE_G then
         v.p_rr := resize(r.m_rr - r.p_ii + r.p_rr, r.p_rr, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
      else
         v.p_rr := resize(r.m_rr - r.p_ii, r.p_rr, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
      end if;

      -- Imag part of cfixedMultAdd
      v.m_ir := r.areg(0).im * r.breg(0).re;
      v.p_ir := resize(r.m_ir + v.creg(CIN_REG_G).im, r.p_ir, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
      v.m_ri := r.areg(1).re * r.breg(1).im;
      if ACCUMULATE_G then
         v.p_ri := resize(r.m_ri + r.p_ir + r.p_ri, r.p_ri, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
      else
         v.p_ri := resize(r.m_ri + r.p_ir, r.p_ri, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
      end if;

      -- resize for output
      v.y := to_cfixed(
          resize(r.p_rr, y.re, OUT_OVERFLOW_STYLE_G, OUT_ROUNDING_STYLE_G),
          resize(r.p_ri, y.im, OUT_OVERFLOW_STYLE_G, OUT_ROUNDING_STYLE_G));
      rin <= v;

      -- Outputs
      if REG_OUT_G then
         y <= r.y;
      else
         y <= v.y;
      end if;
      --acout <= r.areg(0);

      yVld <= r.yVld(r.yVld'left);

   end process comb;

   seq : process(clk) is
   begin
      if rising_edge(clk) then
         if (rst = '1') then
            r <= REG_INIT_C after TPD_G;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process seq;

end architecture rtl;
