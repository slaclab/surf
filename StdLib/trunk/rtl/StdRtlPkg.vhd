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

package StdRtlPkg is

  -- Typing std_logic(_vector) is annoying
  subtype sl is std_logic;
  subtype slv is std_logic_vector;

  -- Declare arrays of built in types
  type IntegerArray is array (integer range <>) of integer;
  type NaturalArray is array (natural range <>) of natural;
  type Slv64Array is array (natural range <>) of slv(63 downto 0);
  type Slv32Array is array (natural range <>) of slv(31 downto 0);
  type Slv16Array is array (natural range <>) of slv(15 downto 0);
  type Slv8Array is array (natural range <>) of slv(7 downto 0);

  -- Very useful functions
  function log2 (constant number : integer) return integer;
  function bitSize (constant number : positive) return positive;
  function bitReverse (a         : slv) return slv;

  function list (constant start : integer;
                 constant size  : integer;
                 constant step  : integer := 1)
    return IntegerArray;

  -- This should be unnecessary in VHDL 2008
  function toBoolean (logic : sl) return boolean;
  function toSl (bool       : boolean) return sl;
  function toString (bool   : boolean) return string;
  function toBoolean (str   : string) return boolean;

  -- Unary reduction operators, also unnecessary in VHDL 2008
  function uOr (vec      : slv) return sl;
  function uAnd (vec     : slv) return sl;
  function uXor (vec     : slv) return sl;
  function uOrBool (vec  : slv) return boolean;
  function uAndBool (vec : slv) return boolean;
  function uXorBool (vec : slv) return boolean;

  -- Avoid bla = "00000" literal comarisons that don't scale naturally with bla'length
  function slvAll (value   : sl; length : natural) return slv;
  function slvZero (length : integer) return slv;
--  function unsignedZero (length : integer) return unsigned;
  function isAll (vec      : slv; value : sl) return boolean;
  function isAll (vec      : unsigned; value : sl) return boolean;
  function isZero (vec     : slv) return boolean;


  -- Create an slv of given size with every bit set to value

  -- These just use uXor to calulate parity
  -- Output is parity bit value needed to achieve that parity given vec.
  function evenParity (vec : slv) return sl;
  function oddParity (vec  : slv) return sl;

  -- Gray Code functions
  function grayEncode (vec : unsigned) return unsigned;
  function grayEncode (vec : slv) return slv;
  function grayDecode (vec : unsigned) return unsigned;
  function grayDecode (vec : slv) return slv;



  -- Some synthesis tools wont accept unit types
  --type frequency is range 0 to 2147483647
  --  units
  --    Hz;
  --    kHz = 1000 Hz;
  --    MHz = 1000 kHz;
  --    GHz = 1000 MHz;
  --  end units;

  --function toTime(f : frequency) return time;

end StdRtlPkg;

package body StdRtlPkg is


  ---------------------------------------------------------------------------------------------------------------------
  -- Function: log2
  -- Purpose: Finds the log base 2 of an integer
  -- Input is rounded up to nearest power of two.
  -- Therefore log2(5) = log2(8) = 3.
  -- Arg: number - integer to find log2 of
  -- Returns: Integer containing log base two of input.
  ---------------------------------------------------------------------------------------------------------------------
  function log2(
    constant number : integer)
    return integer
  is
    variable divVar : real    := real(number);
    variable retVar : integer := 0;
  begin
    while (divVar > 1.0) loop
      divVar := divVar/2.0;
      retVar := retVar + 1;
    end loop;
    return retVar;
  end function;

  -- Find number of bits needed to store a number
  function bitSize (
    constant number : positive)
    return positive is
  begin
    if (number = 1) then
      return 1;
    else
      return log2(number);
    end if;
  end function;

  -- NOTE: XST will crap its pants if you try to pass a constant to this function
  function bitReverse (a : slv)
    return slv
  is
    variable resultVar : slv(a'range);
    alias aa           : slv(a'reverse_range) is a;
  begin
    for i in aa'range loop
      resultVar(i) := aa(i);
    end loop;
    return resultVar;
  end;

  function list (
    constant start : integer;
    constant size  : integer;
    constant step  : integer := 1)
    return IntegerArray is
    variable retVar : IntegerArray(0 to size-1);
  begin
    for i in retVar'range loop
      retVar(i) := start + (i * step);
    end loop;
    return retVar;
  end function list;

  function toBoolean (
    logic : sl)
    return boolean is
  begin  -- function toBoolean
    return logic = '1';
  end function toBoolean;

  function toSl (
    bool : boolean)
    return sl is
  begin  -- function toSl
    if (bool) then
      return '1';
    else
      return '0';
    end if;
  end function toSl;

  function toString (
    bool : boolean)
    return string is
  begin
    if (bool) then
      return "TRUE";
    else
      return "FALSE";
    end if;
  end function toString;

  function toBoolean (
    str : string)
    return boolean is
  begin
    if (str = "TRUE" or str = "true") then
      return true;
    else
      return false;
    end if;
  end function toBoolean;

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

  function uOrBool (vec : slv) return boolean is
  begin
    return toBoolean(uOr(vec));
  end function;

  function uAndBool (vec : slv) return boolean is
  begin
    return toBoolean(uAnd(vec));
  end function;

  function uXorBool (vec : slv) return boolean is
    variable intVar : sl;
  begin
    return toBoolean(uXor(vec));
  end function;

  ---------------------------------------------------------------------------------------------------------------------
  -- Functions to get a vector of all same value
  ---------------------------------------------------------------------------------------------------------------------
  function slvAll (value : sl; length : natural) return slv is
    variable retVar : slv(length-1 downto 0) := (others => value);
  begin
    return retVar;
  end function;

  function slvZero (length : integer) return slv is
  begin
    return slvAll('0', length);
  end function;

  function unsignedZero (length : integer) return unsigned is
  begin
    return unsigned(slvZero(length));
  end function;

  function isAll (vec : slv; value : sl)
    return boolean is
  begin
    return vec = slvAll(value, vec'length);
  end function;

  function isAll (vec : unsigned; value : sl)
    return boolean is
  begin
    return slv(vec) = slvAll(value, vec'length);
  end function;

  function isZero (vec : slv)
    return boolean is
  begin
    return vec = slvZero(vec'length);
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

  ---------------------------------------------------------------------------------------------------------------------
  -- Convert a frequency to a period (time).
  ---------------------------------------------------------------------------------------------------------------------
  --function toTime(f : frequency) return time is
  --begin
  --  return(1.0 sec / (f/Hz));
  --end function;
  
end package body StdRtlPkg;
