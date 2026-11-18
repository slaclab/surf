-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Fixed point math functions on two's complement (signed) and
--              unsigned vectors: magnitude, saturation, rounding shifts,
--              saturating add/subtract, real to Q format conversion, clamp
--              and complex magnitude approximations. All are combinational
--              and sized from their arguments, so they drop into a pipeline
--              stage or an elaboration time constant.
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
use ieee.math_real.all;

library surf;
use surf.StdRtlPkg.all;

package DspFixedPkg is

   function absMag (x : signed) return unsigned;  -- |x|, one bit wider than x
   function absMag (x : slv) return slv;
   function saturate (x : signed; width : positive) return signed;  -- narrow to width bits, clamped instead of wrapped
   function saturate (x : unsigned; width : positive) return unsigned;
   function shiftRightRound (x : signed; n : natural; convergent : boolean := false) return signed;  -- x/2^n rounded, ties up or to even
   function shiftRightRound (x : unsigned; n : natural; convergent : boolean := false) return unsigned;
   function addSat (a, b : signed) return signed;  -- clamped to the width of the wider operand
   function subSat (a, b : signed) return signed;
   function addSat (a, b : unsigned) return unsigned;
   function subSat (a, b : unsigned) return unsigned;  -- clamped at zero
   function toFixed (x : real; width : positive; fracBits : natural) return slv;  -- real to Q format, 32 bits at most
   function toReal (x : signed; fracBits : natural) return real;
   function toReal (x : unsigned; fracBits : natural) return real;
   function toReal (x : slv; fracBits : natural) return real;  -- two's complement
   function clamp (x, lo, hi : integer) return integer;  -- bound x to lo..hi
   function clamp (x, lo, hi : signed) return signed;
   function clamp (x, lo, hi : unsigned) return unsigned;
   function magL1 (i, q : signed) return unsigned;    -- |I|+|Q|, one bit wider
   function magLinf (i, q : signed) return unsigned;  -- max(|I|,|Q|), one bit wider

end package DspFixedPkg;

package body DspFixedPkg is

   -- |x| of a two's complement vector, one bit wider than x so the most
   -- negative value (for example -32768 of 16 bits) does not overflow
   function absMag (x : signed)
      return unsigned is
      variable ext : signed(x'length downto 0);
   begin
      ext := resize(x, x'length+1);
      return unsigned(abs(ext));
   end function;

   -- SLV variant
   function absMag (x : slv)
      return slv is
   begin
      return slv(absMag(signed(x)));
   end function;

   -- Narrow a two's complement vector to width bits, clamping to the
   -- representable range instead of wrapping
   function saturate (x : signed; width : positive)
      return signed is
      variable minVal : signed(width-1 downto 0) := (others => '0');
      variable maxVal : signed(width-1 downto 0) := (others => '0');
   begin
      if (x'length <= width) then
         return resize(x, width);
      end if;
      minVal(width-1) := '1';
      maxVal          := not minVal;
      if (x > resize(maxVal, x'length)) then
         return maxVal;
      elsif (x < resize(minVal, x'length)) then
         return minVal;
      else
         return resize(x, width);
      end if;
   end function;

   -- Unsigned variant
   function saturate (x : unsigned; width : positive)
      return unsigned is
      constant MAX_C : unsigned(width-1 downto 0) := (others => '1');
   begin
      if (x'length <= width) then
         return resize(x, width);
      end if;
      if (x > resize(MAX_C, x'length)) then
         return MAX_C;
      else
         return resize(x, width);
      end if;
   end function;

   -- Divide a two's complement vector by 2^n, rounded to the nearest integer.
   -- Ties round up (toward +infinity), or to the even result when convergent
   -- (the DSP48 pattern, no bias). The result has the width of x.
   function shiftRightRound (x : signed; n : natural; convergent : boolean := false)
      return signed is
      variable ext  : signed(x'length downto 0);
      variable half : signed(x'length downto 0) := (others => '0');
      variable ret  : signed(x'length downto 0) := (others => '0');
   begin
      if (n = 0) then
         return resize(x, x'length);
      end if;
      -- |x|/2^n is below one half
      if (n > x'length) then
         return resize(ret, x'length);
      end if;
      -- One bit of headroom for the rounding carry
      ext       := resize(x, x'length+1);
      half(n-1) := '1';
      ret       := shift_right(ext + half, n);
      -- Half way exactly: the discarded bits of x are a one followed by zeros
      if (convergent) and (ext(n-1 downto 0) = half(n-1 downto 0)) then
         ret(0) := '0';
      end if;
      return resize(ret, x'length);
   end function;

   -- Unsigned variant
   function shiftRightRound (x : unsigned; n : natural; convergent : boolean := false)
      return unsigned is
      variable ext  : unsigned(x'length downto 0);
      variable half : unsigned(x'length downto 0) := (others => '0');
      variable ret  : unsigned(x'length downto 0) := (others => '0');
   begin
      if (n = 0) then
         return resize(x, x'length);
      end if;
      -- x/2^n is below one half
      if (n > x'length) then
         return resize(ret, x'length);
      end if;
      -- One bit of headroom for the rounding carry
      ext       := resize(x, x'length+1);
      half(n-1) := '1';
      ret       := shift_right(ext + half, n);
      -- Half way exactly: the discarded bits of x are a one followed by zeros
      if (convergent) and (ext(n-1 downto 0) = half(n-1 downto 0)) then
         ret(0) := '0';
      end if;
      return resize(ret, x'length);
   end function;

   -- Add or subtract, clamped to the representable range of the wider operand
   -- instead of wrapping
   function addSat (a, b : signed)
      return signed is
      constant WIDTH_C : positive := ite(a'length > b'length, a'length, b'length);
      variable sum     : signed(WIDTH_C downto 0);
   begin
      sum := resize(a, WIDTH_C+1) + resize(b, WIDTH_C+1);
      return saturate(sum, WIDTH_C);
   end function;

   function subSat (a, b : signed)
      return signed is
      constant WIDTH_C : positive := ite(a'length > b'length, a'length, b'length);
      variable diff    : signed(WIDTH_C downto 0);
   begin
      diff := resize(a, WIDTH_C+1) - resize(b, WIDTH_C+1);
      return saturate(diff, WIDTH_C);
   end function;

   -- Unsigned variants
   function addSat (a, b : unsigned)
      return unsigned is
      constant WIDTH_C : positive := ite(a'length > b'length, a'length, b'length);
      variable sum     : unsigned(WIDTH_C downto 0);
   begin
      sum := resize(a, WIDTH_C+1) + resize(b, WIDTH_C+1);
      return saturate(sum, WIDTH_C);
   end function;

   -- Clamped at zero
   function subSat (a, b : unsigned)
      return unsigned is
      constant WIDTH_C : positive := ite(a'length > b'length, a'length, b'length);
      variable diff    : unsigned(WIDTH_C-1 downto 0) := (others => '0');
   begin
      if (a > b) then
         diff := resize(a, WIDTH_C) - resize(b, WIDTH_C);
      end if;
      return diff;
   end function;

   -- Real to two's complement Q format: width bits with fracBits of them
   -- fractional, rounded to the nearest code (ties away from zero) and clamped
   -- to the representable range. Meant for constants and coefficient tables.
   -- The integer arithmetic limits width to 32 bits.
   function toFixed (x : real; width : positive; fracBits : natural)
      return slv is
      constant MAX_C : real := 2.0**(width-1) - 1.0;
      constant MIN_C : real := -(2.0**(width-1));
      variable code  : real;
   begin
      assert (width <= 32) report "toFixed() - width must be 32 bits or less" severity failure;
      code := round(x * 2.0**fracBits);
      if (code > MAX_C) then
         code := MAX_C;
      elsif (code < MIN_C) then
         code := MIN_C;
      end if;
      return slv(to_signed(integer(code), width));
   end function;

   -- Q format to real, the inverse of toFixed. 32 bits at most (31 unsigned)
   function toReal (x : signed; fracBits : natural)
      return real is
   begin
      assert (x'length <= 32) report "toReal() - x must be 32 bits or less" severity failure;
      return real(to_integer(x)) / 2.0**fracBits;
   end function;

   function toReal (x : unsigned; fracBits : natural)
      return real is
   begin
      assert (x'length <= 31) report "toReal() - x must be 31 bits or less" severity failure;
      return real(to_integer(x)) / 2.0**fracBits;
   end function;

   -- SLV variant, two's complement
   function toReal (x : slv; fracBits : natural)
      return real is
   begin
      return toReal(signed(x), fracBits);
   end function;

   -- Bound x to the range lo to hi
   function clamp (x, lo, hi : integer)
      return integer is
   begin
      if (x < lo) then
         return lo;
      elsif (x > hi) then
         return hi;
      else
         return x;
      end if;
   end function;

   -- Vector variants, with the width of x
   function clamp (x, lo, hi : signed)
      return signed is
   begin
      if (x < lo) then
         return resize(lo, x'length);
      elsif (x > hi) then
         return resize(hi, x'length);
      else
         return resize(x, x'length);
      end if;
   end function;

   function clamp (x, lo, hi : unsigned)
      return unsigned is
   begin
      if (x < lo) then
         return resize(lo, x'length);
      elsif (x > hi) then
         return resize(hi, x'length);
      else
         return resize(x, x'length);
      end if;
   end function;

   -- Magnitude approximations of a complex sample, one bit wider than the
   -- wider of i and q: |I|+|Q| overestimates |I+jQ| by up to sqrt(2)
   function magL1 (i, q : signed)
      return unsigned is
      constant WIDTH_C : positive := ite(i'length > q'length, i'length, q'length) + 1;
   begin
      return resize(absMag(i), WIDTH_C) + resize(absMag(q), WIDTH_C);
   end function;

   -- max(|I|,|Q|) underestimates |I+jQ| by up to sqrt(2)
   function magLinf (i, q : signed)
      return unsigned is
      constant WIDTH_C : positive := ite(i'length > q'length, i'length, q'length) + 1;
      variable absI    : unsigned(WIDTH_C-1 downto 0);
      variable absQ    : unsigned(WIDTH_C-1 downto 0);
   begin
      absI := resize(absMag(i), WIDTH_C);
      absQ := resize(absMag(q), WIDTH_C);
      if (absI > absQ) then
         return absI;
      else
         return absQ;
      end if;
   end function;

end package body DspFixedPkg;
