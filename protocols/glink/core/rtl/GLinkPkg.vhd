-------------------------------------------------------------------------------
-- File       : GlinkDecoder.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-03-12
-- Last update: 2014-10-24
-------------------------------------------------------------------------------
-- Description: A collection of common constants and functions intended for
-- use encoding/decoding the GLink Protocol.
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

use work.StdRtlPkg.all;

package GLinkPkg is

   type GLinkTxType is record
      idle    : sl;
      control : sl;
      flag    : sl;
      data    : slv(15 downto 0);
      linkRst : sl;
   end record;
   type GLinkTxArray is array (natural range <>) of GLinkTxType;
   type GLinkTxVectorArray is array (natural range<>, natural range<>) of GLinkTxType;
   constant GLINK_TX_INIT_C : GLinkTxType := (
      idle    => '1',
      control => '0',
      flag    => '0',
      data    => (others => '0'),
      linkRst => '1');
   constant GLINK_TX_UNUSED_C : GLinkTxType := (
      idle    => '1',
      control => '0',
      flag    => '0',
      data    => (others => '0'),
      linkRst => '0');
   function toSlv (vec     : GLinkTxType) return slv;
   function toGLinkTx (vec : slv(19 downto 0)) return GLinkTxType;

   type GLinkRxType is record
      isIdle    : sl;
      isData    : sl;
      isControl : sl;
      flag      : sl;
      data      : slv(15 downto 0);
      -- Link Status Signals
      error     : sl;
      rxReady   : sl;
      txReady   : sl;
      linkUp    : sl;
   end record;
   type GLinkRxArray is array (natural range <>) of GLinkRxType;
   type GLinkRxVectorArray is array (natural range<>, natural range<>) of GLinkRxType;
   constant GLINK_RX_INIT_C : GLinkRxType := (
      isIdle    => '1',
      isData    => '0',
      isControl => '0',
      flag      => '0',
      data      => (others => '0'),
      -- Link Status Signals
      error     => '0',
      rxReady   => '0',
      txReady   => '0',
      linkUp    => '0');
   function toSlv (vec     : GLinkRxType) return slv;
   function toGLinkRx (vec : slv(23 downto 0)) return GLinkRxType;

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

   function toSlv (vec : GLinkTxType) return slv is
      variable retVar : slv(19 downto 0) := (others => '0');
   begin
      retVar(19)          := vec.idle;
      retVar(18)          := vec.control;
      retVar(17)          := vec.flag;
      retVar(16)          := vec.linkRst;
      retVar(15 downto 0) := vec.data(15 downto 0);
      return retVar;
   end function;

   function toGLinkTx (vec : slv(19 downto 0)) return GLinkTxType is
      variable retVar : GLinkTxType;
   begin
      retVar.idle              := vec(19);
      retVar.control           := vec(18);
      retVar.flag              := vec(17);
      retVar.linkRst           := vec(16);
      retVar.data(15 downto 0) := vec(15 downto 0);
      return retVar;
   end function;

   function toSlv (vec : GLinkRxType) return slv is
      variable retVar : slv(23 downto 0) := (others => '0');
   begin
      retVar(23)          := vec.isIdle;
      retVar(22)          := vec.isData;
      retVar(21)          := vec.isControl;
      retVar(20)          := vec.flag;
      retVar(19)          := vec.error;
      retVar(18)          := vec.rxReady;
      retVar(17)          := vec.txReady;
      retVar(16)          := vec.linkUp;
      retVar(15 downto 0) := vec.data(15 downto 0);
      return retVar;
   end function;

   function toGLinkRx (vec : slv(23 downto 0)) return GLinkRxType is
      variable retVar : GLinkRxType;
   begin
      retVar.isIdle            := vec(23);
      retVar.isData            := vec(22);
      retVar.isControl         := vec(21);
      retVar.flag              := vec(20);
      retVar.error             := vec(19);
      retVar.rxReady           := vec(18);
      retVar.txReady           := vec(17);
      retVar.linkUp            := vec(16);
      retVar.data(15 downto 0) := vec(15 downto 0);
      return retVar;
   end function;

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
      if (std_match(word.c, "-00-") or
          std_match(word.c, "-11-") or
          std_match(word.c, "0101") or
          std_match(word.c, "1010")) then  
         validVar := false;
      elsif word.c = "1100" then        --check for invalid Filled frames
         if (std_match(word.w, "-------0--------") or
             std_match(word.w, "-------11-------")) then  
            validVar := false;
         end if;
      end if;
      return validVar;
   end function isValidWord;

   function isControlWord (
      -- we might want to add a 01/10 check in the isControlWord function, 
      -- instead on relying on the isValidWord function (LLR - 26FEB2014)
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
