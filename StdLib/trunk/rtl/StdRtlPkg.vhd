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
   type Slv144Array is array (natural range <>) of slv(143 downto 0);
   type Slv143Array is array (natural range <>) of slv(142 downto 0);
   type Slv142Array is array (natural range <>) of slv(141 downto 0);
   type Slv141Array is array (natural range <>) of slv(140 downto 0);
   type Slv140Array is array (natural range <>) of slv(139 downto 0);
   type Slv139Array is array (natural range <>) of slv(138 downto 0);
   type Slv138Array is array (natural range <>) of slv(137 downto 0);
   type Slv137Array is array (natural range <>) of slv(136 downto 0);
   type Slv136Array is array (natural range <>) of slv(135 downto 0);
   type Slv135Array is array (natural range <>) of slv(134 downto 0);
   type Slv134Array is array (natural range <>) of slv(133 downto 0);
   type Slv133Array is array (natural range <>) of slv(132 downto 0);
   type Slv132Array is array (natural range <>) of slv(131 downto 0);
   type Slv131Array is array (natural range <>) of slv(130 downto 0);
   type Slv130Array is array (natural range <>) of slv(129 downto 0);
   type Slv129Array is array (natural range <>) of slv(128 downto 0);
   type Slv128Array is array (natural range <>) of slv(127 downto 0);
   type Slv127Array is array (natural range <>) of slv(126 downto 0);
   type Slv126Array is array (natural range <>) of slv(125 downto 0);
   type Slv125Array is array (natural range <>) of slv(124 downto 0);
   type Slv124Array is array (natural range <>) of slv(123 downto 0);
   type Slv123Array is array (natural range <>) of slv(122 downto 0);
   type Slv122Array is array (natural range <>) of slv(121 downto 0);
   type Slv121Array is array (natural range <>) of slv(120 downto 0);
   type Slv120Array is array (natural range <>) of slv(119 downto 0);
   type Slv119Array is array (natural range <>) of slv(118 downto 0);
   type Slv118Array is array (natural range <>) of slv(117 downto 0);
   type Slv117Array is array (natural range <>) of slv(116 downto 0);
   type Slv116Array is array (natural range <>) of slv(115 downto 0);
   type Slv115Array is array (natural range <>) of slv(114 downto 0);
   type Slv114Array is array (natural range <>) of slv(113 downto 0);
   type Slv113Array is array (natural range <>) of slv(112 downto 0);
   type Slv112Array is array (natural range <>) of slv(111 downto 0);
   type Slv111Array is array (natural range <>) of slv(110 downto 0);
   type Slv110Array is array (natural range <>) of slv(109 downto 0);
   type Slv109Array is array (natural range <>) of slv(108 downto 0);
   type Slv108Array is array (natural range <>) of slv(107 downto 0);
   type Slv107Array is array (natural range <>) of slv(106 downto 0);
   type Slv106Array is array (natural range <>) of slv(105 downto 0);
   type Slv105Array is array (natural range <>) of slv(104 downto 0);
   type Slv104Array is array (natural range <>) of slv(103 downto 0);
   type Slv103Array is array (natural range <>) of slv(102 downto 0);
   type Slv102Array is array (natural range <>) of slv(101 downto 0);
   type Slv101Array is array (natural range <>) of slv(100 downto 0);
   type Slv100Array is array (natural range <>) of slv(99 downto 0);
   type Slv99Array is array (natural range <>) of slv(98 downto 0);
   type Slv98Array is array (natural range <>) of slv(97 downto 0);
   type Slv97Array is array (natural range <>) of slv(96 downto 0);
   type Slv96Array is array (natural range <>) of slv(95 downto 0);
   type Slv95Array is array (natural range <>) of slv(94 downto 0);
   type Slv94Array is array (natural range <>) of slv(93 downto 0);
   type Slv93Array is array (natural range <>) of slv(92 downto 0);
   type Slv92Array is array (natural range <>) of slv(91 downto 0);
   type Slv91Array is array (natural range <>) of slv(90 downto 0);
   type Slv90Array is array (natural range <>) of slv(89 downto 0);
   type Slv89Array is array (natural range <>) of slv(88 downto 0);
   type Slv88Array is array (natural range <>) of slv(87 downto 0);
   type Slv87Array is array (natural range <>) of slv(86 downto 0);
   type Slv86Array is array (natural range <>) of slv(85 downto 0);
   type Slv85Array is array (natural range <>) of slv(84 downto 0);
   type Slv84Array is array (natural range <>) of slv(83 downto 0);
   type Slv83Array is array (natural range <>) of slv(82 downto 0);
   type Slv82Array is array (natural range <>) of slv(81 downto 0);
   type Slv81Array is array (natural range <>) of slv(80 downto 0);
   type Slv80Array is array (natural range <>) of slv(79 downto 0);
   type Slv79Array is array (natural range <>) of slv(78 downto 0);
   type Slv78Array is array (natural range <>) of slv(77 downto 0);
   type Slv77Array is array (natural range <>) of slv(76 downto 0);
   type Slv76Array is array (natural range <>) of slv(75 downto 0);
   type Slv75Array is array (natural range <>) of slv(74 downto 0);
   type Slv74Array is array (natural range <>) of slv(73 downto 0);
   type Slv73Array is array (natural range <>) of slv(72 downto 0);
   type Slv72Array is array (natural range <>) of slv(71 downto 0);
   type Slv71Array is array (natural range <>) of slv(70 downto 0);
   type Slv70Array is array (natural range <>) of slv(69 downto 0);
   type Slv69Array is array (natural range <>) of slv(68 downto 0);
   type Slv68Array is array (natural range <>) of slv(67 downto 0);
   type Slv67Array is array (natural range <>) of slv(66 downto 0);
   type Slv66Array is array (natural range <>) of slv(65 downto 0);
   type Slv65Array is array (natural range <>) of slv(64 downto 0);
   type Slv64Array is array (natural range <>) of slv(63 downto 0);
   type Slv63Array is array (natural range <>) of slv(62 downto 0);
   type Slv62Array is array (natural range <>) of slv(61 downto 0);
   type Slv61Array is array (natural range <>) of slv(60 downto 0);
   type Slv60Array is array (natural range <>) of slv(59 downto 0);
   type Slv59Array is array (natural range <>) of slv(58 downto 0);
   type Slv58Array is array (natural range <>) of slv(57 downto 0);
   type Slv57Array is array (natural range <>) of slv(56 downto 0);
   type Slv56Array is array (natural range <>) of slv(55 downto 0);
   type Slv55Array is array (natural range <>) of slv(54 downto 0);
   type Slv54Array is array (natural range <>) of slv(53 downto 0);
   type Slv53Array is array (natural range <>) of slv(52 downto 0);
   type Slv52Array is array (natural range <>) of slv(51 downto 0);
   type Slv51Array is array (natural range <>) of slv(50 downto 0);
   type Slv50Array is array (natural range <>) of slv(49 downto 0);
   type Slv49Array is array (natural range <>) of slv(48 downto 0);
   type Slv48Array is array (natural range <>) of slv(47 downto 0);
   type Slv47Array is array (natural range <>) of slv(46 downto 0);
   type Slv46Array is array (natural range <>) of slv(45 downto 0);
   type Slv45Array is array (natural range <>) of slv(44 downto 0);
   type Slv44Array is array (natural range <>) of slv(43 downto 0);
   type Slv43Array is array (natural range <>) of slv(42 downto 0);
   type Slv42Array is array (natural range <>) of slv(41 downto 0);
   type Slv41Array is array (natural range <>) of slv(40 downto 0);
   type Slv40Array is array (natural range <>) of slv(39 downto 0);
   type Slv39Array is array (natural range <>) of slv(38 downto 0);
   type Slv38Array is array (natural range <>) of slv(37 downto 0);
   type Slv37Array is array (natural range <>) of slv(36 downto 0);
   type Slv36Array is array (natural range <>) of slv(35 downto 0);
   type Slv35Array is array (natural range <>) of slv(34 downto 0);
   type Slv34Array is array (natural range <>) of slv(33 downto 0);
   type Slv33Array is array (natural range <>) of slv(32 downto 0);
   type Slv32Array is array (natural range <>) of slv(31 downto 0);
   type Slv31Array is array (natural range <>) of slv(30 downto 0);
   type Slv30Array is array (natural range <>) of slv(29 downto 0);
   type Slv29Array is array (natural range <>) of slv(28 downto 0);
   type Slv28Array is array (natural range <>) of slv(27 downto 0);
   type Slv27Array is array (natural range <>) of slv(26 downto 0);
   type Slv26Array is array (natural range <>) of slv(25 downto 0);
   type Slv25Array is array (natural range <>) of slv(24 downto 0);
   type Slv24Array is array (natural range <>) of slv(23 downto 0);
   type Slv23Array is array (natural range <>) of slv(22 downto 0);
   type Slv22Array is array (natural range <>) of slv(21 downto 0);
   type Slv21Array is array (natural range <>) of slv(20 downto 0);
   type Slv20Array is array (natural range <>) of slv(19 downto 0);
   type Slv19Array is array (natural range <>) of slv(18 downto 0);
   type Slv18Array is array (natural range <>) of slv(17 downto 0);
   type Slv17Array is array (natural range <>) of slv(16 downto 0);
   type Slv16Array is array (natural range <>) of slv(15 downto 0);
   type Slv15Array is array (natural range <>) of slv(14 downto 0);
   type Slv14Array is array (natural range <>) of slv(13 downto 0);
   type Slv13Array is array (natural range <>) of slv(12 downto 0);
   type Slv12Array is array (natural range <>) of slv(11 downto 0);
   type Slv11Array is array (natural range <>) of slv(10 downto 0);
   type Slv10Array is array (natural range <>) of slv(9 downto 0);
   type Slv9Array is array (natural range <>) of slv(8 downto 0);
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
      return slvAll(size, '0');
   end function;

   function slvOne (size : positive) return slv is
   begin
      return slvAll(size, '1');
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
