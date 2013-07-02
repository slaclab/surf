-------------------------------------------------------------------------------
-- Title      : Standard RTL Package
-------------------------------------------------------------------------------
-- File       : StdRtlPkg.vhd
-- Author     : Benjamin Reese 
-- Standard   : VHDL'93/02, Math Packages
-------------------------------------------------------------------------------
-- Description: This package defines "sl" and "slv" shorthand subtypes for
--              std_logic and std_logic_vector repectively.  It also defines
--              many handy untility functions. Nearly every .vhd file should
--              use this package.
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use ieee.math_real.all;

package StdRtlPkg is

   -- Typing std_logic(_vector) is annoying
   subtype sl is std_logic;
   subtype slv is std_logic_vector;

   -- Declare arrays of built in types
   type IntegerArray is array (integer range <>) of integer;
   type NaturalArray is array (natural range <>) of natural;
   -- Add more slv array sizes here as they become needed
   type Slv128Array is array (natural range <>) of slv(127 downto 0);
   type Slv64Array is array (natural range <>) of slv(63 downto 0);
   type Slv32Array is array (natural range <>) of slv(31 downto 0);
   type Slv16Array is array (natural range <>) of slv(15 downto 0);
   type Slv14Array is array (natural range <>) of slv(13 downto 0);
   type Slv8Array is array (natural range <>) of slv(7 downto 0);
   type Slv7Array is array (natural range <>) of slv(6 downto 0);
   type Slv6Array is array (natural range <>) of slv(5 downto 0);
   type Slv5Array is array (natural range <>) of slv(4 downto 0);
   type Slv4Array is array (natural range <>) of slv(3 downto 0);
   type Slv3Array is array (natural range <>) of slv(2 downto 0);
   type Slv2Array is array (natural range <>) of slv(1 downto 0);
   type Slv1Array is array (natural range <>) of slv(0 downto 0);

   -- Create an arbitrary sized slv with all bits set high or low
   function slvAll (size  : positive; value : sl) return slv;
   function slvZero (size : positive) return slv;
   function slvOne (size  : positive) return slv;

   -- Very useful functions
   function log2 (constant number    : positive) return natural;
   function bitSize (constant number : positive) return positive;
   function bitReverse (a            : slv) return slv;

   -- Similar to python's range() function
   function list (constant start, size, step : integer) return IntegerArray;

   -- Simple decoder and mux functions
   function decode(v    : slv) return slv;
   function genmux(s, v : slv) return sl;

   -- This should be unnecessary in VHDL 2008
   function toBoolean (logic : sl) return boolean;
   function toSl (bool       : boolean) return sl;
   function toString (bool   : boolean) return string;
   function toBoolean (str   : string) return boolean;

   -- Unary reduction operators, also unnecessary in VHDL 2008
   function uOr (vec  : slv) return sl;
   function uAnd (vec : slv) return sl;
   function uXor (vec : slv) return sl;

   -- Test if all bits in a vector are set to a given logic value
   function allBits (vec : slv; test : sl) return boolean;
   function noBits (vec  : slv; test : sl) return boolean;

   -- These just use uXor to calulate parity
   -- Output is parity bit value needed to achieve that parity given vec.
   function evenParity (vec : slv) return sl;
   function oddParity (vec  : slv) return sl;

   -- Gray Code functions
   function grayEncode (vec : unsigned) return unsigned;
   function grayEncode (vec : slv) return slv;
   function grayDecode (vec : unsigned) return unsigned;
   function grayDecode (vec : slv) return slv;

   function max (left, right : integer) return integer;
   function min (left, right : integer) return integer;

   -- One line if-then-else functions. Usefull for assigning constants based on generics.
   function ite(i : boolean; t : sl; e : sl) return sl;
   function ite(i : boolean; t : slv; e : slv) return slv;
   function ite(i : boolean; t : string; e : string) return string;
   function ite(i : boolean; t : integer; e : integer) return integer;

   -- Some synthesis tools wont accept unit types
   -- pragma translate_off
   type frequency is range 0 to 2147483647
      units
         Hz;
         kHz = 1000 Hz;
         MHz = 1000 kHz;
         GHz = 1000 MHz;
      end units;

   function toTime(f : frequency) return time;
   -- pragma translate_on

end StdRtlPkg;

package body StdRtlPkg is

   function slvAll (size : positive; value : sl) return slv is
      variable retVar : slv(size-1 downto 0) := (others => value);
   begin
      return retVar;
   end function slvAll;

   function slvZero (size : positive) return slv is
   begin
      return slvAll(size, '1');
   end function;

   function slvOne (size : positive) return slv is
   begin
      return slvAll(size, '0');
   end function;

   ---------------------------------------------------------------------------------------------------------------------
   -- Function: log2
   -- Purpose: Finds the log base 2 of an integer
   -- Input is rounded up to nearest power of two.
   -- Therefore log2(5) = log2(8) = 3.
   -- Arg: number - integer to find log2 of
   -- Returns: Integer containing log base two of input.
   ---------------------------------------------------------------------------------------------------------------------
   function log2(constant number : positive) return natural is
   begin
      return integer(ceil(ieee.math_real.log2(real(number))));
   end function;

   -- Find number of bits needed to store a number
   function bitSize (constant number : positive) return positive is
   begin
      if (number = 1) then
         return 1;
      else
         return log2(number);
      end if;
   end function;

   -- NOTE: XST will crap its pants if you try to pass a constant to this function
   function bitReverse (a : slv) return slv is
      variable resultVar : slv(a'range);
      alias aa           : slv(a'reverse_range) is a;
   begin
      for i in aa'range loop
         resultVar(i) := aa(i);
      end loop;
      return resultVar;
   end;

   function list (constant start, size, step : integer) return IntegerArray is
      variable retVar : IntegerArray(0 to size-1);
   begin
      for i in retVar'range loop
         retVar(i) := start + (i * step);
      end loop;
      return retVar;
   end function list;

   function toBoolean (logic : sl) return boolean is
   begin  -- function toBoolean
      return logic = '1';
   end function toBoolean;

   function toSl (bool : boolean) return sl is
   begin
      if (bool) then
         return '1';
      else
         return '0';
      end if;
   end function toSl;

   function toString (bool : boolean) return string is
   begin
      if (bool) then
         return "TRUE";
      else
         return "FALSE";
      end if;
   end function toString;

   function toBoolean (str : string) return boolean is
   begin
      if (str = "TRUE" or str = "true") then
         return true;
      else
         return false;
      end if;
   end function toBoolean;

   --------------------------------------------------------------------------------------------------
   -- Decode and genmux
   --------------------------------------------------------------------------------------------------
   -- generic decoder
   function decode(v : slv) return slv is
      variable res : slv((2**v'length)-1 downto 0);
      variable i   : integer range res'range;
   begin
      res    := (others => '0');
      i      := 0;
      i      := to_integer(unsigned(v));
      res(i) := '1';
      return res;
   end;

   -- generic multiplexer
   function genmux(s, v : slv) return sl is
      variable res : slv(v'length-1 downto 0);
      variable i   : integer range res'range;
   begin
      res := v;
      i   := 0;
      i   := to_integer(unsigned(s));
      return res(i);
   end;

   ---------------------------------------------------------------------------------------------------------------------
   -- Unary reduction operators
   ---------------------------------------------------------------------------------------------------------------------
   function uOr (vec : slv) return sl is
   begin
      for i in vec'range loop
         if (vec(i) = '1') then
            return '1';
         end if;
      end loop;
      return '0';
   end function uOr;

   function uAnd (vec : slv) return sl is
   begin
      for i in vec'range loop
         if (vec(i) = '0') then
            return '0';
         end if;
      end loop;
      return '1';
   end function uAnd;

   function uXor (vec : slv) return sl is
      variable intVar : sl;
   begin
      for i in vec'range loop
         if (i = vec'left) then
            intVar := vec(i);
         else
            intVar := intVar xor vec(i);
         end if;
      end loop;
      return intVar;
   end function uXor;

   function allBits (vec : slv; test : sl) return boolean is
   begin
      for i in vec'range loop
         if (vec(i) /= test) then
            return false;
         end if;
      end loop;
      return true;
   end function;

   function noBits (vec : slv; test : sl) return boolean is
   begin
      for i in vec'range loop
         if (vec(i) = test) then
            return false;
         end if;
      end loop;
      return true;
   end function;

   -----------------------------------------------------------------------------
   -- Functions to determine parity of arbitrary sized slv
   -----------------------------------------------------------------------------
   -- returns '1' if vec has even parity
   function evenParity (vec : slv)
      return sl is
   begin
      return not uXor(vec);
   end function;

   -- return '1' if vec has odd parity
   function oddParity (vec : slv)
      return sl is
   begin
      return uXor(vec);
   end function;

   -----------------------------------------------------------------------------
   -- Functions for encoding and decoding grey codes
   -----------------------------------------------------------------------------
   -- Get next gray code given binary vector
   function grayEncode (vec : unsigned)
      return unsigned is
   begin
      return vec xor shift_right(vec, 1);
   end function;

   -- SLV variant
   function grayEncode (vec : slv)
      return slv is
   begin
      return slv(grayEncode(unsigned(vec)));
   end function;

   -- Get the binary equivalent of a gray code created with gray_encode.
   function grayDecode (vec : unsigned)
      return unsigned is
      variable retVar : unsigned(vec'range) := (others => '0');
   begin
      for i in vec'range loop
         if (i = vec'left) then
            retVar(i) := vec(i);
         else
            if (vec'ascending) then
               retVar(i) := retVar(i-1) xor vec(i);
            else
               retVar(i) := retVar(i+1) xor vec(i);
            end if;
         end if;
      end loop;
      return retVar;
   end function;

   -- SLV variant
   function grayDecode (vec : slv)
      return slv is
      variable retVar : slv(vec'range) := (others => '0');
   begin
      return slv(grayDecode(unsigned(vec)));
   end function;

   -------------------------------------------------------------------------------------------------
   -- One line if-then-else functions.
   -------------------------------------------------------------------------------------------------
   function ite (i : boolean; t : sl; e : sl) return sl is
   begin
      if (i) then return t; else return e; end if;
   end function ite;

   function ite (i : boolean; t : slv; e : slv) return slv is
   begin
      if (i) then return t; else return e; end if;
   end function ite;

   function ite (i : boolean; t : string; e : string) return string is
   begin
      if (i) then return t; else return e; end if;
   end function ite;
   
   function ite (i : boolean; t : integer; e : integer) return integer is
   begin
      if (i) then return t; else return e; end if;
   end function ite;
   
   -----------------------------
   -- Min and Max
   -----------------------------
   function max (left, right : integer) return integer is
   begin
      if left > right then return left;
      else return right;
      end if;
   end max;

   function min (left, right : integer) return integer is
   begin
      if left < right then return left;
      else return right;
      end if;
   end min;
   
   ---------------------------------------------------------------------------------------------------------------------
   -- Convert a frequency to a period (time).
   ---------------------------------------------------------------------------------------------------------------------
   -- pragma translate_off
   function toTime(f : frequency) return time is
   begin
      return(1.0 sec / (f/Hz));
   end function;
   --pragma translate_on


   
end package body StdRtlPkg;
