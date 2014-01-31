-------------------------------------------------------------------------------
-- Title      : GLink Package
-------------------------------------------------------------------------------
-- File       : GlinkDecoder.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-03-12
-- Last update: 2014-01-30
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: A collection of common constants and functions intended for
-- use encoding/decoding the GLink Protocol.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;

package GLinkPkg is

   type GLinkTxType is record
      control : sl; 
      idle    : sl;   
      data    : slv(15 downto 0); 
   end record;
   type GLinkTxTypeArray is array (natural range <>) of GLinkTxType;
   type GLinkTxTypeVectorArray is array (natural range<>, natural range<>) of GLinkTxType;
   constant GLINK_TX_INIT_C : GLinkTxType := (
      '0',
      '0',
      (others => '0'));
      
   type GLinkRxType is record
      isControl : sl; 
      isIdle    : sl;   
      isData    : sl;   
      flag      : sl;   
      data      : slv(15 downto 0); 
   end record;
   type GLinkRxTypeArray is array (natural range <>) of GLinkRxType;
   type GLinkRxTypeVectorArray is array (natural range<>, natural range<>) of GLinkRxType;
   constant GLINK_RX_INIT_C : GLinkRxType := (
      '0',
      '0',
      '0',
      '0',
      (others => '0'));        

   -- Valid C Field values
   constant GLINK_CONTROL_WORD_C            : slv(3 downto 0) := "0011";
   constant GLINK_CONTROL_WORD_INV_C        : slv(3 downto 0) := "1100";
   constant GLINK_DATA_WORD_FLAG_LOW_C      : slv(3 downto 0) := "1101";
   constant GLINK_DATA_WORD_INV_FLAG_LOW_C  : slv(3 downto 0) := "0010";
   constant GLINK_DATA_WORD_FLAG_HIGH_C     : slv(3 downto 0) := "1011";
   constant GLINK_DATA_WORD_INV_FLAG_HIGH_C : slv(3 downto 0) := "0100";

   -- Array of valid C Fields
   type GLinkSlv4Array is array (natural range <>) of slv(3 downto 0);

   constant GLINK_VALID_C_FIELDS_C : GLinkSlv4Array(0 to 5) := (
      GLINK_CONTROL_WORD_C,
      GLINK_CONTROL_WORD_INV_C,
      GLINK_DATA_WORD_FLAG_LOW_C,
      GLINK_DATA_WORD_INV_FLAG_LOW_C,
      GLINK_DATA_WORD_FLAG_HIGH_C,
      GLINK_DATA_WORD_INV_FLAG_HIGH_C);

   -- Valid idle (fill) words
   constant GLINK_IDLE_WORD_FF0_C  : slv(0 to 15) := X"FF00";
   constant GLINK_IDLE_WORD_FF1L_C : slv(0 to 15) := X"FE00";
   constant GLINK_IDLE_WORD_FF1H_C : slv(0 to 15) := X"FF80";

   -- Array of valid idle words
   type GLinkSlv16Array is array (natural range <>) of slv(0 to 15);

   constant GLINK_VALID_IDLE_WORDS_C : GLinkSlv16Array(0 to 2) := (
      GLINK_IDLE_WORD_FF0_C,
      GLINK_IDLE_WORD_FF1L_C,
      GLINK_IDLE_WORD_FF1H_C);

   -- GLink Word structure
   -- Contains 16 bit W-Field (data) and 4 bit C-Field (control)
   type GLinkWordType is
   record
      w : slv(0 to 15);                 -- W-Field
      c : slv(3 downto 0);              -- C-Field
   end record;

   -- Array of GLink words (I really hate that VHDL makes you do this)
   type GLinkWordArray is array (natural range <>) of GLinkWordType;

   -- Functions for working with GLinkWordType
   function toGLinkWord(data        : slv(19 downto 0)) return GLinkWordType;
   function toSlv (word             : GLinkWordType) return slv;
   function isValidWord (word       : GLinkWordType) return boolean;
   function isControlWord (word     : GLinkWordType) return boolean;
   function isIdleWord (word        : GLinkWordType) return boolean;
   function isDataWord (word        : GLinkWordType) return boolean;
   function isInvertedWord (word    : GLinkWordType) return boolean;
   function getControlPayload (word : GLinkWordType) return slv;
   function getDataPayload(word     : GLinkWordType) return slv;
   function getFlag(word            : GLinkWordType) return sl;

end package GLinkPkg;

package body GLinkPkg is

   function toGLinkWord (
      data : slv(19 downto 0))
      return GLinkWordType
   is
      variable retVar : GLinkWordType;
   begin
      retVar.w := data(19 downto 4);
      retVar.c := data(3 downto 0);
      return retVar;
   end function;

   function toSlv (
      word : GLinkWordType)
      return slv
   is
      variable retVar : slv(19 downto 0);
   begin
      retVar(19 downto 4) := word.w;
      retVar(3 downto 0)  := word.c;
      return retVar;
   end function;

   -----------------------------------------------------------------------------
   -- Test if a word is valid.
   -- Detectable error states listed on page 23 of HDMP-1032A/1034A Data Sheet
   -----------------------------------------------------------------------------
   function isValidWord (
      word : GLinkWordType)
      return boolean
   is
      variable validVar : boolean := true;
   begin
      if (word.c = "-00-" or            -- Invalid C-field
          word.c = "-11-" or            -- Invalid C-field
          (word.c = "1100" and word.w(7) = '0') or  -- Control with invalid data
          (word.c = "1100" and word.w(7 to 8) = "11") or  -- Control with invalid data
          word.c = "1010" or            -- Invalid C-field
          word.c = "0101") then         -- Invalid C-field
         validVar := false;
      end if;
      return validVar;
   end function isValidWord;

   function isControlWord (
      word : GLinkWordType)
      return boolean
   is
      variable retVar : boolean := false;
   begin
      if (word.c = GLINK_CONTROL_WORD_C or word.c = GLINK_CONTROL_WORD_INV_C) then
         retVar := true;
      end if;
      return retVar;
   end function isControlWord;

   function isIdleWord (
      word : GLinkWordType)
      return boolean
   is
      variable retVar : boolean := false;
   begin
      if (word.c = GLINK_CONTROL_WORD_C) then
         for i in GLINK_VALID_IDLE_WORDS_C'range loop
            if (word.w = GLINK_VALID_IDLE_WORDS_C(i)) then
               retVar := true;
            end if;
         end loop;  -- i
      end if;
      return retVar;
   end function;

   function isDataWord (
      word : GLinkWordType)
      return boolean
   is
      variable retVar : boolean := false;
   begin
      if (word.c = GLINK_DATA_WORD_FLAG_LOW_C or
          word.c = GLINK_DATA_WORD_INV_FLAG_LOW_C or
          word.c = GLINK_DATA_WORD_FLAG_HIGH_C or
          word.c = GLINK_DATA_WORD_INV_FLAG_HIGH_C) then
         retVar := true;
      end if;
      return retVar;
   end function isDataWord;

   function isInvertedWord (
      word : GLinkWordType)
      return boolean
   is
      variable retVar : boolean := false;
   begin
      if (word.c = GLINK_DATA_WORD_INV_FLAG_LOW_C or
          word.c = GLINK_DATA_WORD_INV_FLAG_HIGH_C or
          word.c = GLINK_CONTROL_WORD_INV_C) then
         retVar := true;
      end if;
      return retVar;
   end function isInvertedWord;

   function getControlPayload (
      word : GLinkWordType)
      return slv
   is
      variable retVar : slv(15 downto 0);
   begin
      retVar(6 downto 0)   := bitReverse(word.w(0 to 6));
      retVar(13 downto 7)  := bitReverse(word.w(9 to 15));
      retVar(15 downto 14) := word.w(7 to 8);  -- actually don't care
      return retVar;
   end function;

   function getDataPayload(
      word : GLinkWordType)
      return slv
   is
   begin
      return bitReverse(word.w);
   end function;

   function getFlag(
      word : GLinkWordType)
      return sl
   is
   begin
      if (word.c = GLINK_DATA_WORD_FLAG_HIGH_C or
          word.c = GLINK_DATA_WORD_INV_FLAG_HIGH_C) then
         return '1';
      else
         return '0';
      end if;
   end function;

end package body GLinkPkg;
