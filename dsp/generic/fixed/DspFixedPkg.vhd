-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Fixed point math functions on two's complement (signed) and
--              unsigned vectors: range constants, magnitude, saturation,
--              rounding and saturating shifts, saturating add/subtract, real
--              to Q format conversion, clamp and complex magnitude
--              approximations. All are combinational and sized from their
--              arguments, so they drop into a pipeline stage or an
--              elaboration time constant.
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

   -- Rounding modes of shiftRightRound and rescale: how a value exactly half
   -- way between two results is resolved
   type RoundModeType is (
      ROUND_TRUNC_C,                    -- toward -infinity (floor), no rounding logic
      ROUND_HALF_UP_C,                  -- ties toward +infinity
      ROUND_HALF_DOWN_C,                -- ties toward -infinity
      ROUND_HALF_AWAY_C,                -- ties away from zero (symmetric)
      ROUND_HALF_ZERO_C,                -- ties toward zero (symmetric)
      ROUND_HALF_EVEN_C,                -- ties to the even result (convergent, no bias)
      ROUND_HALF_ODD_C);                -- ties to the odd result

   -- Range of a width bit vector
   function maxSigned (width : positive) return signed;
   function minSigned (width : positive) return signed;
   function maxUnsigned (width : positive) return unsigned;

   -- Magnitude and negation
   function absMag (x : signed) return unsigned;  -- |x|, one bit wider than x
   function absMag (x : slv) return slv;
   function absSat (x : signed) return signed;    -- |x| in the width of x, the most negative value clamps
   function negSat (x : signed) return signed;    -- -x in the width of x, the most negative value clamps

   -- Saturation
   function saturate (x : signed; width : positive) return signed;  -- narrow to width bits, clamped instead of wrapped
   function saturate (x : unsigned; width : positive) return unsigned;
   function inRange (x : signed; width : positive) return boolean;  -- true if x fits in width bits without clamping
   function inRange (x : unsigned; width : positive) return boolean;

   -- Shifts
   function shiftRightRound (x : signed; n : natural; mode : RoundModeType := ROUND_HALF_UP_C) return signed;  -- x/2^n rounded, width of x
   function shiftRightRound (x : unsigned; n : natural; mode : RoundModeType := ROUND_HALF_UP_C) return unsigned;
   function shiftLeftSat (x : signed; n : natural) return signed;  -- x*2^n in the width of x, clamped
   function shiftLeftSat (x : unsigned; n : natural) return unsigned;
   function rescale (x : signed; n : natural; width : positive; mode : RoundModeType := ROUND_HALF_UP_C) return signed;  -- x/2^n rounded then clamped to width bits
   function rescale (x : unsigned; n : natural; width : positive; mode : RoundModeType := ROUND_HALF_UP_C) return unsigned;

   -- Saturating add and subtract, clamped to the width of the wider operand
   function addSat (a, b : signed) return signed;
   function subSat (a, b : signed) return signed;
   function addSat (a, b : unsigned) return unsigned;
   function subSat (a, b : unsigned) return unsigned;  -- clamped at zero

   -- Real conversion for constants and coefficient tables, 32 bits at most
   function toFixed (x : real; width : positive; fracBits : natural) return slv;  -- real to Q format, rounded and clamped
   function toReal (x : signed; fracBits : natural) return real;
   function toReal (x : unsigned; fracBits : natural) return real;
   function toReal (x : slv; fracBits : natural) return real;  -- two's complement

   -- Bound x to lo..hi
   function clamp (x, lo, hi : integer) return integer;
   function clamp (x, lo, hi : signed) return signed;
   function clamp (x, lo, hi : unsigned) return unsigned;

   -- Complex magnitude approximations, one bit wider than the wider input
   function magL1 (i, q : signed) return unsigned;    -- |I|+|Q|
   function magLinf (i, q : signed) return unsigned;  -- max(|I|,|Q|)

end package DspFixedPkg;

package body DspFixedPkg is

   -----------------------------------------------------------------------------
   -- Range of a width bit vector
   -----------------------------------------------------------------------------
   function maxSigned (width : positive)
      return signed is
      variable ret : signed(width-1 downto 0) := (others => '1');
   begin
      ret(width-1) := '0';
      return ret;
   end function;

   function minSigned (width : positive)
      return signed is
      variable ret : signed(width-1 downto 0) := (others => '0');
   begin
      ret(width-1) := '1';
      return ret;
   end function;

   function maxUnsigned (width : positive)
      return unsigned is
      constant RET_C : unsigned(width-1 downto 0) := (others => '1');
   begin
      return RET_C;
   end function;

   -----------------------------------------------------------------------------
   -- Magnitude and negation
   -----------------------------------------------------------------------------
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

   -- |x| kept in the width of x: the most negative value clamps to the most
   -- positive one instead of wrapping back onto itself
   function absSat (x : signed)
      return signed is
   begin
      return saturate(signed(absMag(x)), x'length);
   end function;

   -- -x kept in the width of x, the most negative value clamps
   function negSat (x : signed)
      return signed is
   begin
      return saturate(-resize(x, x'length+1), x'length);
   end function;

   -----------------------------------------------------------------------------
   -- Saturation
   -----------------------------------------------------------------------------
   -- Narrow a two's complement vector to width bits, clamping to the
   -- representable range instead of wrapping
   function saturate (x : signed; width : positive)
      return signed is
   begin
      if (x'length <= width) then
         return resize(x, width);
      end if;
      if (x > resize(maxSigned(width), x'length)) then
         return maxSigned(width);
      elsif (x < resize(minSigned(width), x'length)) then
         return minSigned(width);
      else
         return resize(x, width);
      end if;
   end function;

   -- Unsigned variant
   function saturate (x : unsigned; width : positive)
      return unsigned is
   begin
      if (x'length <= width) then
         return resize(x, width);
      end if;
      if (x > resize(maxUnsigned(width), x'length)) then
         return maxUnsigned(width);
      else
         return resize(x, width);
      end if;
   end function;

   -- True when saturate(x, width) would return x unchanged: the test for an
   -- overflow flag next to a saturating datapath
   function inRange (x : signed; width : positive)
      return boolean is
   begin
      if (x'length <= width) then
         return true;
      end if;
      return (x <= resize(maxSigned(width), x'length)) and (x >= resize(minSigned(width), x'length));
   end function;

   function inRange (x : unsigned; width : positive)
      return boolean is
   begin
      if (x'length <= width) then
         return true;
      end if;
      return (x <= resize(maxUnsigned(width), x'length));
   end function;

   -----------------------------------------------------------------------------
   -- Shifts
   -----------------------------------------------------------------------------
   -- Divide a two's complement vector by 2^n, rounded to the nearest integer
   -- with the tie rule of mode (ROUND_TRUNC_C floors instead). The result has
   -- the width of x: no rounded result can exceed it once n is at least 1.
   function shiftRightRound (x : signed; n : natural; mode : RoundModeType := ROUND_HALF_UP_C)
      return signed is
      constant NEGATIVE_C : boolean := (x(x'left) = '1');
      variable ext        : signed(x'length downto 0);
      variable ret        : signed(x'length downto 0) := (others => '0');
      variable dropped    : unsigned(x'length downto 0);
      variable half       : unsigned(x'length downto 0) := (others => '0');
      variable above      : boolean;
      variable tie        : boolean;
      variable inc        : boolean;
   begin
      if (n = 0) then
         return resize(x, x'length);
      end if;
      -- |x|/2^n is below one half: zero, or minus one when flooring a negative value
      if (n > x'length) then
         if (mode = ROUND_TRUNC_C) and NEGATIVE_C then
            ret := (others => '1');
         end if;
         return resize(ret, x'length);
      end if;
      -- Floor, with one bit of headroom for the rounding carry
      ext := resize(x, x'length+1);
      ret := shift_right(ext, n);
      -- The discarded bits against one half
      dropped := unsigned(ext);
      for k in dropped'range loop
         if (k >= n) then
            dropped(k) := '0';
         end if;
      end loop;
      half(n-1) := '1';
      above     := (dropped > half);
      tie       := (dropped = half);
      case mode is
         when ROUND_TRUNC_C     => inc := false;
         when ROUND_HALF_UP_C   => inc := above or tie;
         when ROUND_HALF_DOWN_C => inc := above;
         when ROUND_HALF_AWAY_C => inc := above or (tie and not NEGATIVE_C);
         when ROUND_HALF_ZERO_C => inc := above or (tie and NEGATIVE_C);
         when ROUND_HALF_EVEN_C => inc := above or (tie and (ret(0) = '1'));
         when ROUND_HALF_ODD_C  => inc := above or (tie and (ret(0) = '0'));
      end case;
      if (inc) then
         ret := ret + 1;
      end if;
      return resize(ret, x'length);
   end function;

   -- Unsigned variant: the symmetric modes behave like their positive half
   function shiftRightRound (x : unsigned; n : natural; mode : RoundModeType := ROUND_HALF_UP_C)
      return unsigned is
      variable ext     : unsigned(x'length downto 0);
      variable ret     : unsigned(x'length downto 0) := (others => '0');
      variable dropped : unsigned(x'length downto 0);
      variable half    : unsigned(x'length downto 0) := (others => '0');
      variable above   : boolean;
      variable tie     : boolean;
      variable inc     : boolean;
   begin
      if (n = 0) then
         return resize(x, x'length);
      end if;
      -- x/2^n is below one half
      if (n > x'length) then
         return resize(ret, x'length);
      end if;
      -- Floor, with one bit of headroom for the rounding carry
      ext := resize(x, x'length+1);
      ret := shift_right(ext, n);
      -- The discarded bits against one half
      dropped := ext;
      for k in dropped'range loop
         if (k >= n) then
            dropped(k) := '0';
         end if;
      end loop;
      half(n-1) := '1';
      above     := (dropped > half);
      tie       := (dropped = half);
      case mode is
         when ROUND_TRUNC_C     => inc := false;
         when ROUND_HALF_UP_C   => inc := above or tie;
         when ROUND_HALF_DOWN_C => inc := above;
         when ROUND_HALF_AWAY_C => inc := above or tie;
         when ROUND_HALF_ZERO_C => inc := above;
         when ROUND_HALF_EVEN_C => inc := above or (tie and (ret(0) = '1'));
         when ROUND_HALF_ODD_C  => inc := above or (tie and (ret(0) = '0'));
      end case;
      if (inc) then
         ret := ret + 1;
      end if;
      return resize(ret, x'length);
   end function;

   -- Multiply by 2^n in the width of x, clamped instead of losing the top bits
   function shiftLeftSat (x : signed; n : natural)
      return signed is
      variable ext : signed(x'length+n-1 downto 0);
   begin
      ext := shift_left(resize(x, x'length+n), n);
      return saturate(ext, x'length);
   end function;

   function shiftLeftSat (x : unsigned; n : natural)
      return unsigned is
      variable ext : unsigned(x'length+n-1 downto 0);
   begin
      ext := shift_left(resize(x, x'length+n), n);
      return saturate(ext, x'length);
   end function;

   -- Drop n fractional bits with rounding, then clamp to width bits: the
   -- usual step from an accumulator or product back to the bus width
   function rescale (x : signed; n : natural; width : positive; mode : RoundModeType := ROUND_HALF_UP_C)
      return signed is
   begin
      return saturate(shiftRightRound(x, n, mode), width);
   end function;

   function rescale (x : unsigned; n : natural; width : positive; mode : RoundModeType := ROUND_HALF_UP_C)
      return unsigned is
   begin
      return saturate(shiftRightRound(x, n, mode), width);
   end function;

   -----------------------------------------------------------------------------
   -- Saturating add and subtract
   -----------------------------------------------------------------------------
   -- Clamped to the representable range of the wider operand instead of wrapping
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

   -----------------------------------------------------------------------------
   -- Real conversion
   -----------------------------------------------------------------------------
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

   -----------------------------------------------------------------------------
   -- Clamp
   -----------------------------------------------------------------------------
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

   -----------------------------------------------------------------------------
   -- Complex magnitude approximations
   -----------------------------------------------------------------------------
   -- One bit wider than the wider of i and q: |I|+|Q| overestimates |I+jQ| by
   -- up to sqrt(2)
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
