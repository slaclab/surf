-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Complex Fixed Point VHDL Package File
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
use ieee.math_real.all;
use ieee.math_complex.all;
use ieee.fixed_pkg.all;
use ieee.fixed_float_types.all;

package ComplexFixedPkg is

   type cfixed is record
      re : sfixed;
      im : sfixed;
   end record cfixed;

   type sfixedArray is array(natural range <>) of sfixed;
   type cfixedArray is array(natural range<>)  of cfixed;

   type realArray is array(natural range<>) of real;
   type complexArray is array(natural range <>) of complex;

   function to_cfixed (R, I : REAL; CTYP : cfixed) return cfixed;
   function to_cfixed (CIN : COMPLEX; CTYP : cfixed) return cfixed;
   function to_cfixed (R, I : sfixed) return cfixed;

   function to_cfixedArray( CIN : complexArray; CTYP : cfixed ) return cfixedArray;
   function to_sfixedArray( SIN : realArray; STYP : sfixed) return sfixedArray;

   function resize(CIN  : cfixed;
                   CTYP : cfixed;
                   constant overflow_style : fixed_overflow_style_type;
                   constant round_style    : fixed_round_style_type)
                   return cfixed;

   function to_slv (ARG : cfixed) return std_logic_vector;
   function to_cfixed(VEC : std_logic_vector; CTYP : cfixed) return cfixed;

   function conj (ARG : cfixed) return cfixed;
   function swap (ARG : cfixed) return cfixed;

   function "="  (L, R : cfixed) return boolean;
   function "/=" (L, R : cfixed) return boolean;

   function "-" (ARG : cfixed) return cfixed;
   function "-" (L, R : cfixed) return cfixed;
   function "-" (L : cfixed; R : sfixed) return cfixed;
   function "-" (L : sfixed;  R : cfixed) return cfixed;

   function "+" (L, R : cfixed) return cfixed;
   function "+" (L : cfixed; R : sfixed) return cfixed;
   function "+" (L : sfixed;  R : cfixed) return cfixed;

   function "*" (L, R : cfixed) return cfixed;
   function "*" (L : cfixed; R : sfixed) return cfixed;
   function "*" (L : sfixed;  R : cfixed) return cfixed;

end package ComplexFixedPkg;

package body ComplexFixedPkg is

   function to_cfixed (R, I : sfixed) return cfixed is
      variable ret : cfixed(re(R'range), im(I'range)) := (re => R, im => I);
   begin
      assert (R'left = I'left) and (R'right = I'right);
      return ret;
   end function to_cfixed;

   function resize(CIN  : cfixed;
                   CTYP : cfixed;
                   constant overflow_style : fixed_overflow_style_type;
                   constant round_style    : fixed_round_style_type)
                   return cfixed is
       variable ret : cfixed(re(CTYP.re'range), im(CTYP.im'range));
   begin
       ret.RE := resize(CIN.re, CTYP.re, overflow_style, round_style);
       ret.IM := resize(CIN.im, CTYP.im, overflow_style, round_style);
       return ret;
   end function resize;

   function to_slv(ARG : cfixed) return std_logic_vector is
      variable vec : std_logic_vector(ARG.re'length + ARG.im'length - 1 downto 0);
   begin
       vec(ARG.im'length - 1 downto 0) := to_slv(ARG.im);
       vec(ARG.re'length + ARG.im'length - 1 downto ARG.im'length) :=
           to_slv(ARG.re);
       return vec;
   end function to_slv;

   function to_cfixed(vec : std_logic_vector; CTYP : cfixed) return cfixed is
       variable ret : cfixed(re(CTYP.RE'range), im(CTYP.IM'range));
       --variable ret : CTYP'subtype;
   begin
       ret.IM := to_sfixed(vec(CTYP.IM'length - 1 downto 0), CTYP.IM);
       ret.RE := to_sfixed(vec(CTYP.IM'length + CTYP.RE'length - 1 downto CTYP.IM'length), CTYP.RE);
       return ret;
   end function to_cfixed;

   function "=" (L, R : cfixed) return boolean is
   begin
       return ( (L.RE = R.RE) and (L.IM = R.IM) );
   end function "=";

   function "/=" (L, R : cfixed) return boolean is
   begin
       return not( L = R );
   end function "/=";

   function conj (ARG : cfixed) return cfixed is
       variable RE : sfixed(ARG.RE'left + 1 downto ARG.RE'low);
       variable IM : sfixed(ARG.IM'left + 1 downto ARG.IM'low);
   begin
      RE := resize(ARG.RE, RE);
      IM := -ARG.IM;
      return to_cfixed(RE, IM);
   end function conj;

   function swap (ARG : cfixed) return cfixed is
   begin
       return to_cfixed(ARG.IM, ARG.RE);
   end function swap;

   function "-" (ARG : cfixed) return cfixed is
   begin
      return to_cfixed(-ARG.RE, -ARG.IM);
   end function "-";

   function "-" (L, R : cfixed) return cfixed is
   begin
      return to_cfixed(L.re - R.re, L.im - R.im);
   end function "-";

   function "-" (L : cfixed; R : sfixed) return cfixed is
      variable RIM : sfixed(R'range) := (others => '0');
   begin
      return L - to_cfixed(R, RIM);
   end function "-";

   function "-" (L : sfixed; R : cfixed) return cfixed is
      variable LIM : sfixed(L'range) := (others => '0');
   begin
      return to_cfixed(L, LIM) - R;
   end function "-";

   function "+" (L, R : cfixed) return cfixed is
   begin
      return to_cfixed(L.re + R.re, L.im + R.im);
   end function "+";

   function "+" (L : cfixed; R : sfixed) return cfixed is
      variable re : sfixed(R'range);
      variable im : sfixed(R'range);
   begin
      re := R;
      im := (others => '0');
      return (L + to_cfixed(re, im));
   end function "+";

   function "+" (L : sfixed; R : cfixed) return cfixed is
   begin
      return R + L;
   end function "+";

  function "*" (L, R : cfixed) return cfixed is
   begin
      return to_cfixed( L.RE * R.RE - L.IM * R.IM, L.RE * R.IM + L.IM * R.RE );
   end function "*";

   function "*" (L : cfixed; R : sfixed) return cfixed is
      variable RIM : sfixed(R'range) := (others => '0');
   begin
      return L * to_cfixed(R, RIM);
   end function "*";

   function "*" (L : sfixed; R : cfixed) return cfixed is
   begin
      return R*L;
   end function "*";

   function to_cfixed (R, I : REAL; CTYP : cfixed) return cfixed is
   begin
      return to_cfixed(to_sfixed(R, CTYP.RE), to_sfixed(I, CTYP.IM));
   end to_cfixed;

   function to_cfixed (CIN : COMPLEX; CTYP : cfixed) return cfixed is
   begin
      return to_cfixed(to_sfixed(CIN.RE, CTYP.RE), to_sfixed(CIN.IM, CTYP.IM));
   end to_cfixed;

   function to_cfixedArray ( CIN : complexArray; CTYP : cfixed ) return cfixedArray is
       variable ret : cfixedArray(CIN'range)(re(CTYP.re'range), im(CTYP.im'range));
   begin
       for i in CIN'range loop
           ret(i) := to_cfixed(CIN(i), CTYP);
       end loop;
       return ret;
   end function to_cfixedArray;

   function to_sfixedArray( SIN : realArray; STYP : sfixed) return sfixedArray is
      variable ret : sfixedArray(SIN'range)(STYP'range);
   begin
      for i in SIN'range loop
          ret(i) := to_sfixed(SIN(i), STYP);
      end loop;
      return ret;
   end function to_sfixedArray;

end package body ComplexFixedPkg;
