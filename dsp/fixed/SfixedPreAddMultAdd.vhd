-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: signed fixed point preAdd mult add module using VHDL2008 fixed_pkg.
--              (D + A)*B + C (ADD_A_G = true)
--              (D - A)*B + C (ADD_A_G = false)
--              latency >= 4
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

entity sfixedPreAddMultAdd is
   generic (
      TPD_G                : time                      := 1 ns;
      ADD_A_G              : boolean                   := true; -- (D+A)*B+C
      LATENCY_G            : natural range 4 to 100    := 4;
      OUT_OVERFLOW_STYLE_G : fixed_overflow_style_type := fixed_wrap;
      OUT_ROUNDING_STYLE_G : fixed_round_style_type    := fixed_truncate);
   port (
      clk     : in  sl;
      -- rst may cause issues inferring DSP48
      rst     : in  sl := '0';
      a       : in  sfixed;
      aVld    : in  sl := '0';
      d       : in  sfixed;
      dVld    : in  sl := '0';
      b       : in  sfixed;
      bVld    : in  sl := '0';
      c       : in  sfixed;
      cVld    : in  sl := '0';
      -- outputs
      y       : out sfixed;
      yVld    : out sl);
end entity sfixedPreAddMultAdd;

architecture rtl of sfixedPreAddMultAdd is

   -- 1 bit growth for pre adder
   constant PRE_ADD_HIGH_C : integer := maximum(a'high, d'high) + 1;
   constant PRE_ADD_LOW_C  : integer := minimum(a'low, d'low);

   type sfixedArray is array(natural range<>) of sfixed;

   type RegType is record
      areg   : sfixed(a'range);
      dreg   : sfixed(d'range);
      breg   : sfixed(b'range);
      brreg  : sfixed(b'range);
      creg   : sfixed(c'range);
      crreg  : sfixed(c'range);
      crrreg : sfixed(c'range);
      preAdd : sfixed(PRE_ADD_HIGH_C downto PRE_ADD_LOW_C); -- 1 bit growth here
      mreg   : sfixed(PRE_ADD_HIGH_C + b'high + 1 downto PRE_ADD_LOW_C + b'low);
      preg   : sfixedArray(LATENCY_G-1 downto 3)(y'range);
      vld    : slv(LATENCY_G-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      areg   => (others => '0'),
      dreg   => (others => '0'),
      breg   => (others => '0'),
      brreg  => (others => '0'),
      creg   => (others => '0'),
      crreg  => (others => '0'),
      crrreg => (others => '0'),
      preAdd => (others => '0'),
      mreg   => (others => '0'),
      preg   => (others => (others => '0')),
      vld    => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process( a, d, b, c, aVld, dVld, bVld, cVld, r ) is
      variable v : RegType;
   begin
      -- latch current value
      v := r;

      v.areg   := a;
      v.dreg   := d;
      v.breg   := b;
      v.brreg  := r.breg;
      v.creg   := c;
      v.crreg  := r.creg;
      v.crrreg := r.crreg;

      v.vld(0) := aVld and dVld and bVld and cVld;
      v.vld(LATENCY_G-1 downto 1)  := r.vld(LATENCY_G-2 downto 0);


      if ADD_A_G then
         v.preAdd := r.dreg + r.areg;
      else
         v.preAdd := r.dreg - r.areg;
      end if;

      v.mreg    := r.preAdd * r.brreg;
      v.preg(3) := resize(r.mreg + r.crrreg, v.preg(3), OUT_OVERFLOW_STYLE_G, OUT_ROUNDING_STYLE_G);

      v.preg(LATENCY_G-1 downto 4) := r.preg(LATENCY_G-2 downto 3);

      -- register for next cycle
      rin  <= v;

      -- registered outputs
      yVld    <= r.vld(LATENCY_G-1);
      --y       <= resize(r.preg(LATENCY_G-1), y, OUT_OVERFLOW_STYLE_G, OUT_ROUNDING_STYLE_G);
      y       <= r.preg(LATENCY_G-1);

   end process comb;

   seq : process(clk) is
   begin
      if rising_edge(clk) then
         if rst = '1' then
            r <= REG_INIT_C after TPD_G;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process seq;

end architecture rtl;
