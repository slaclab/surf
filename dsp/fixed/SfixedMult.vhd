-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: signed fixed point multiplier using VHDL2008 fixed_pkg and
--              unconstrained input/output ports.  Can infer 27x18 mult
--              (1 DSP48) with latency >= 3 or 35x27 mult (2 DSP48) with
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

-- sfixed multiplier use LATENCY_G >= 3 for 27x18 (1 DSP48E2 slice)
-- sfixed multiplier use LATENCY_G >= 4 for 35x27 (2 DSP48E2 slices)

-- Using the reset may cause issues inferring correct DSP48 structure

entity sfixedMult is
   generic (
      TPD_G                : time                      := 1 ns;
      LATENCY_G            : natural range 3 to 100    := 3;
      RND_SIMPLE_G         : boolean                   := false; -- may interfere with large mult inference (35x27)
      OUT_OVERFLOW_STYLE_G : fixed_overflow_style_type := fixed_wrap;
      OUT_ROUNDING_STYLE_G : fixed_round_style_type    := fixed_truncate);
   port (
      clk     : in  sl;
      -- rst may cause issues inferring DSP48
      rst     : in  sl := '0';
      a       : in  sfixed;
      aVld    : in  sl := '0';
      b       : in  sfixed;
      bVld    : in  sl := '0';
      -- outputs
      y       : out sfixed;
      yVld    : out sl);
end entity sfixedMult;

architecture rtl of sfixedMult is

   type sfixedArray is array(natural range<>) of sfixed;

   constant C_HIGH_BIT_C : integer := a'high + b'high + 1;
   constant C_LOW_BIT_C  : integer := a'low  + b'low;

   signal c    : sfixed(C_HIGH_BIT_C downto C_LOW_BIT_C) := (others => '0');

   type RegType is record
      areg : sfixed(a'range);
      breg : sfixed(b'range);
      mreg : sfixed(a'high + b'high + 1 downto a'low + b'low);
      preg : sfixedArray(LATENCY_G-1 downto 2)(y'range);
      vld  : slv(LATENCY_G-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      areg  => (others => '0'),
      breg  => (others => '0'),
      mreg  => (others => '0'),
      preg  => (others => (others => '0')),
      vld   => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   -- RND_SIMPLE_G
   c(y'low - 1) <= '1';

   comb : process( a, b, c, aVld, bVld, r ) is
      variable v : RegType;
   begin
      -- latch current value
      v := r;

      v.areg   := a;
      v.breg   := b;

      v.vld(0) := aVld and bVld;
      v.vld(LATENCY_G-1 downto 1)  := r.vld(LATENCY_G-2 downto 0);

      v.mreg    := r.areg * r.breg;
      if RND_SIMPLE_G then
         v.preg(2) := resize(r.mreg + c, v.preg(2), OUT_OVERFLOW_STYLE_G, OUT_ROUNDING_STYLE_G);
      else
         v.preg(2) := resize(r.mreg, v.preg(2), OUT_OVERFLOW_STYLE_G, OUT_ROUNDING_STYLE_G);
      end if;
      v.preg(LATENCY_G-1 downto 3) := r.preg(LATENCY_G-2 downto 2);

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
