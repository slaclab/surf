-------------------------------------------------------------------------------
-- Title      : Line Code 12B14B: https://confluence.slac.stanford.edu/x/6AJODQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 12B14B Package File
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


library surf;
use surf.StdRtlPkg.all;
--use surf.TextUtilPkg.all;


package Code12b14bPkg is

   -------------------------------------------------------------------------------------------------
   -- Constants for K codes
   -- These are intended for public use
   -------------------------------------------------------------------------------------------------
   constant K_120_0_C  : slv(11 downto 0) := "000001111000";
   constant K_120_1_C  : slv(11 downto 0) := "000011111000";
   constant K_120_2_C  : slv(11 downto 0) := "000101111000";
   constant K_120_3_C  : slv(11 downto 0) := "000111111000";
   constant K_120_4_C  : slv(11 downto 0) := "001001111000";
   constant K_120_7_C  : slv(11 downto 0) := "001111111000";
   constant K_120_8_C  : slv(11 downto 0) := "010001111000";
   constant K_120_11_C : slv(11 downto 0) := "010111111000";
--   constant K_120_15_C : slv(11 downto 0) := "011111111000";
   constant K_120_16_C : slv(11 downto 0) := "100001111000";
   constant K_120_19_C : slv(11 downto 0) := "100111111000";
   constant K_120_23_C : slv(11 downto 0) := "101111111000";
   constant K_120_24_C : slv(11 downto 0) := "110001111000";
   constant K_120_27_C : slv(11 downto 0) := "110111111000";
   constant K_120_29_C : slv(11 downto 0) := "111011111000";
   constant K_120_30_C : slv(11 downto 0) := "111101111000";
   constant K_120_31_C : slv(11 downto 0) := "111111111000";
--    constant K_55_15_C  : slv(11 downto 0) := "011110110111";
--    constant K_57_15_C  : slv(11 downto 0) := "011110111001";
--    constant K_87_15_C  : slv(11 downto 0) := "011111010111";
--    constant K_93_15_C  : slv(11 downto 0) := "011111011101";
--    constant K_117_15_C : slv(11 downto 0) := "011111110101";

   constant K_120_0_CODE_C  : slv(13 downto 0) := "00011011111000";
   constant K_120_1_CODE_C  : slv(13 downto 0) := "01000111111000";
   constant K_120_2_CODE_C  : slv(13 downto 0) := "01001011111000";
   constant K_120_3_CODE_C  : slv(13 downto 0) := "10001111111000";
   constant K_120_4_CODE_C  : slv(13 downto 0) := "01010011111000";
   constant K_120_7_CODE_C  : slv(13 downto 0) := "11100011111000";
   constant K_120_8_CODE_C  : slv(13 downto 0) := "01100011111000";
   constant K_120_11_CODE_C : slv(13 downto 0) := "00101111111000";
--   constant K_120_15_CODE_C : slv(13 downto 0) := "00001111111000";
   constant K_120_16_CODE_C : slv(13 downto 0) := "00100111111000";
   constant K_120_19_CODE_C : slv(13 downto 0) := "01001111111000";
   constant K_120_23_CODE_C : slv(13 downto 0) := "10100011111000";
   constant K_120_24_CODE_C : slv(13 downto 0) := "00110011111000";
   constant K_120_27_CODE_C : slv(13 downto 0) := "10010011111000";
   constant K_120_29_CODE_C : slv(13 downto 0) := "10001011111000";
   constant K_120_30_CODE_C : slv(13 downto 0) := "10000111111000";
   constant K_120_31_CODE_C : slv(13 downto 0) := "00101011111000";
--    constant K_55_15_CODE_C  : slv(13 downto 0) := "00001110110111";
--    constant K_57_15_CODE_C  : slv(13 downto 0) := "00001110111001";
--    constant K_87_15_CODE_C  : slv(13 downto 0) := "00001111010111";
--    constant K_93_15_CODE_C  : slv(13 downto 0) := "00001111011101";
--    constant K_117_15_CODE_C : slv(13 downto 0) := "00001111110101";



   -------------------------------------------------------------------------------------------------
   -- Disparity types and helper functions
   -------------------------------------------------------------------------------------------------
   subtype BlockDisparityType is integer range -4 to 4;
   function toSlv (d                : BlockDisparityType) return slv;
   function toBlockDisparityType (d : slv(1 downto 0)) return BlockDisparityType;
   function getDisparity (vec       : slv) return BlockDisparityType;

   -- Convert a 12 bit code into "D/K.x.y" form
   function toString (code : slv(11 downto 0); k : sl) return string;

   -------------------------------------------------------------------------------------------------
   -- K-Code table
   -------------------------------------------------------------------------------------------------
   type KCodeEntryType is record
      k12  : slv(11 downto 0);
      k14  : slv(13 downto 0);
      disp : BlockDisparityType;
   end record KCodeEntryType;

   type KCodeArray is array (natural range <>) of KCodeEntryType;

   constant K_CODE_TABLE_C : KCodeArray;

   -------------------------------------------------------------------------------------------------
   -- Structures for holding 7/8 code table
   -------------------------------------------------------------------------------------------------
   type Encode7b8bType is record
      in7b    : slv(6 downto 0);
      out8b   : slv(7 downto 0);
      outDisp : BlockDisparityType;
      alt8b   : slv(7 downto 0);
      altDisp : BlockDisparityType;
   end record Encode7b8bType;

   type Encode7b8bArray is array (natural range <>) of Encode7b8bType;

   function makeEncode7b8bTable(a : slv8Array(0 to 127)) return Encode7b8bArray;

   -- Array of codes for 7b/8b D codes
--    constant CODE_8B_C : slv8Array(0 to 127) := (
--       "00011010", "11110001", "10101110", "00100011", "00001101", "00010101", "00100110", "10000111",
--       "00010011", "00100101", "00101001", "10001011", "00101100", "10001101", "10001110", "00001111",
--       "00101010", "00110001", "00110010", "10010011", "00110100", "10010101", "10010110", "00010111",
--       "01000101", "10011001", "10011010", "10011011", "10011100", "00011101", "00011110", "00011001",
--       "01000111", "01100001", "01001001", "10100011", "01001010", "10100101", "10100110", "00100111",
--       "01011000", "10101001", "10101010", "10101011", "10101100", "10101101", "00101110", "00101111",
--       "01001100", "10110001", "10110010", "00110011", "10110100", "00110101", "00110110", "00110111",
--       "10111000", "00111001", "00111010", "00111011", "00111100", "00111101", "00111110", "00011011",
--       "01000100", "00011100", "01100010", "11000011", "00100100", "11000101", "11000110", "11000111",
--       "01101000", "11001001", "11001010", "01001011", "11001100", "01001101", "01001110", "01001111",
--       "01110000", "11010001", "11010010", "01010011", "11010100", "01010101", "01010110", "01010111",
--       "11011000", "01011001", "01011010", "01011011", "01011100", "01011101", "01011110", "00101011",
--       "00101101", "11100001", "11100010", "01100011", "11100100", "01100101", "01100110", "01100111",
--       "11101000", "01101001", "01101010", "01101011", "01101100", "01101101", "01101110", "01000011",
--       "11110000", "01110001", "01110010", "01110011", "01110100", "01110101", "01110110", "01110111",
--       "01111000", "01111001", "01111010", "01111011", "01111100", "10111101", "11110100", "11101001");

   constant CODE_8B_C : slv8Array(0 to 127) := (
      "01011000", "00011001", "00011010", "00100011", "01100100", "10000101", "10000110", "10000111",  -- 7
      "01101000", "10001001", "01001010", "10001011", "01001100", "10001101", "10001110", "11000111",  -- 15
      "00010011", "10010001", "10010010", "10010011", "10010100", "10010101", "10010110", "00010111",  -- 23
      "10011000", "10011001", "10011010", "00011011", "10011100", "00011101", "00011110", "00011100",  -- 31
      "00100101", "10100001", "00100110", "10100011", "10100100", "10100101", "10100110", "00100111",  -- 39
      "00101001", "10101001", "10101010", "00101011", "10101100", "00101101", "00101110", "00101010",  -- 47
      "00110010", "10110001", "10110010", "00110011", "10110100", "00110101", "00110110", "00110111",  -- 55
      "10111000", "00111001", "00111010", "00111011", "00111100", "10111101", "00110100", "10111011",  -- 63
      "01010100", "11000001", "11000010", "11000011", "01000001", "11000101", "11000110", "01000111",  -- 71
      "01001001", "11001001", "11001010", "01001011", "11001100", "01001101", "01001110", "01000101",  -- 79
      "01000011", "11010001", "11010010", "01010011", "11010100", "01010101", "01010110", "01010111",  -- 87
      "11011000", "01011001", "01011010", "11010011", "01011100", "01011101", "11001110", "11011110",  -- 95
      "01100010", "11100001", "11100010", "01100011", "11100100", "01100101", "01100110", "11100111",  -- 103
      "11101000", "01101001", "01101010", "11101011", "01101100", "11101001", "11101010", "11101101",  -- 111
      "00100100", "01110001", "01110010", "01010001", "01110100", "01110101", "01010010", "01110111",  -- 119
      "01111000", "01100001", "01111011", "01110011", "01111100", "01111101", "01111110", "11101110");  -- 127


   constant ENCODE_7B8B_TABLE_C : Encode7b8bArray;

   -- 7/8 K-code constants
--    constant K_55_C  : slv(6 downto 0) := "0110111";
--    constant K_57_C  : slv(6 downto 0) := "0111001";
--    constant K_87_C  : slv(6 downto 0) := "1010111";
--    constant K_93_C  : slv(6 downto 0) := "1011101";
--    constant K_117_C : slv(6 downto 0) := "1110101";
   constant K_120_C : slv(6 downto 0) := "1111000";

--    constant K_55_CODE_C  : slv(7 downto 0) := "10110111";
--    constant K_57_CODE_C  : slv(7 downto 0) := "10111001";
--    constant K_87_CODE_C  : slv(7 downto 0) := "11010111";
--    constant K_93_CODE_C  : slv(7 downto 0) := "11011101";
--    constant K_117_CODE_C : slv(7 downto 0) := "11110101";
   constant K_120_CODE_C : slv(7 downto 0) := "11111000";

--   constant K78_TABLE_C : Encode7b8bArray(0 to 0);

   -------------------------------------------------------------------------------------------------
   -- Structure for holding 5/6 code table
   -------------------------------------------------------------------------------------------------
   type Encode5b6bType is record
      in5b    : slv(4 downto 0);
      out6b   : slv(5 downto 0);
      outDisp : BlockDisparityType;
      alt6b   : slv(5 downto 0);
      altDisp : BlockDisparityType;
   end record Encode5b6bType;

   type Encode5b6bArray is array (natural range <>) of Encode5b6bType;

   function makeEncode5b6bTable(a : slv6Array(0 to 31)) return Encode5b6bArray;

   constant CODE_6B_C : slv6Array(0 to 31) := (
      "000110", "010001", "010010", "100011", "010100", "100101", "100110", "000111",
      "011000", "101001", "101010", "001011", "101100", "001101", "001110", "111010",
      "110110", "110001", "110010", "010011", "110100", "010101", "010110", "010111",
      "001100", "011001", "011010", "011011", "011100", "011101", "011110", "110101");

   constant ENCODE_5B6B_TABLE_C : Encode5b6bArray;

   -- 5b/6b K Codes
   constant K_X_0_C  : slv(4 downto 0) := "00000";
   constant K_X_1_C  : slv(4 downto 0) := "00001";
   constant K_X_2_C  : slv(4 downto 0) := "00010";
   constant K_X_3_C  : slv(4 downto 0) := "00011";
   constant K_X_4_C  : slv(4 downto 0) := "00100";
   constant K_X_7_C  : slv(4 downto 0) := "00111";
   constant K_X_8_C  : slv(4 downto 0) := "01000";
   constant K_X_11_C : slv(4 downto 0) := "01011";
--   constant K_X_15_C : slv(4 downto 0) := "01111";
   constant K_X_16_C : slv(4 downto 0) := "10000";
   constant K_X_19_C : slv(4 downto 0) := "10011";
   constant K_X_23_C : slv(4 downto 0) := "10111";
   constant K_X_24_C : slv(4 downto 0) := "11000";
   constant K_X_27_C : slv(4 downto 0) := "11011";
   constant K_X_29_C : slv(4 downto 0) := "11101";
   constant K_X_30_C : slv(4 downto 0) := "11110";
   constant K_X_31_C : slv(4 downto 0) := "11111";

   -- Some of these are inverted from normal code.
   -- This doesn't matter as the encoder/decoder are currently written
   -- These aren't used for encoder and both normal and inverted are checked for in decoder
   constant K_X_0_CODE_C  : slv(5 downto 0) := "000110";
   constant K_X_1_CODE_C  : slv(5 downto 0) := "010001";
   constant K_X_2_CODE_C  : slv(5 downto 0) := "010010";
   constant K_X_3_CODE_C  : slv(5 downto 0) := "100011";
   constant K_X_4_CODE_C  : slv(5 downto 0) := "010100";
   constant K_X_7_CODE_C  : slv(5 downto 0) := "111000";  -- Double check this, should invert?
   constant K_X_8_CODE_C  : slv(5 downto 0) := "011000";
   constant K_X_11_CODE_C : slv(5 downto 0) := "001011";
--   constant K_X_15_CODE_C : slv(5 downto 0) := "000011";
   constant K_X_16_CODE_C : slv(5 downto 0) := "001001";
   constant K_X_19_CODE_C : slv(5 downto 0) := "010011";
   constant K_X_23_CODE_C : slv(5 downto 0) := "101000";
   constant K_X_24_CODE_C : slv(5 downto 0) := "001100";
   constant K_X_27_CODE_C : slv(5 downto 0) := "100100";
   constant K_X_29_CODE_C : slv(5 downto 0) := "100010";
   constant K_X_30_CODE_C : slv(5 downto 0) := "100001";
   constant K_X_31_CODE_C : slv(5 downto 0) := "001010";

--   constant K56_TABLE_C : Encode5b6bArray(0 to 15);

   -------------------------------------------------------------------------------------------------
   -- Structure for full encode table
   -------------------------------------------------------------------------------------------------
   type EncodeTableType is record
      data78 : Encode7b8bArray(0 to 127);
      data56 : Encode5b6bArray(0 to 31);
      kTable : KCodeArray(0 to 15);
   end record;

   constant ENCODE_TABLE_C : EncodeTableType;

   -------------------------------------------------------------------------------------------------
   -- Procedures for encoding and decoding
   -------------------------------------------------------------------------------------------------
   procedure encode12b14b (
      constant CODES_C : in    EncodeTableType;
      dataIn           : in    slv(11 downto 0);
      dataKIn          : in    sl;
      dispIn           : in    slv(1 downto 0);
      dataOut          : inout slv(13 downto 0);
      dispOut          : inout slv(1 downto 0);
      invalidK         : out   sl);

   procedure decode12b14b (
      constant CODES_C : in    EncodeTableType;
      dataIn           : in    slv(13 downto 0);
      dispIn           : in    slv(1 downto 0);
      dataOut          : inout slv(11 downto 0);
      dataKOut         : inout sl;
      dispOut          : inout slv(1 downto 0);
      codeError        : out   sl;
      dispError        : inout sl);

end package Code12b14bPkg;

package body Code12b14bPkg is

   function toString (
      code : slv(11 downto 0);
      k    : sl)
      return string is
      variable s : string(1 to 8);
   begin
      s := resize(ite(k = '1', "K.", "D.") &
                  integer'image(conv_integer(code(6 downto 0))) &
                  "." &
                  integer'image(conv_integer(code(11 downto 7))), 8);
      return s;
   end function toString;

   -- Determine the disparity of a vector
   function getDisparity (vec : slv) return BlockDisparityType is
      variable ones      : integer;
      variable zeros     : integer;
      variable difference: integer;
      variable disparity : BlockDisparityType;
   begin
      zeros := 0;
      ones  := 0;
      for i in vec'range loop
         if (vec(i) = '0') then
            zeros := zeros + 1;
         end if;
      end loop;

      ones      := vec'length-zeros;
      difference:= ones-zeros;
      if (difference > 4) then
        disparity := 4;
      elsif (difference < -4) then
        disparity := -4;
      else
        disparity :=  difference;
      end if;

      return disparity;

   end function getDisparity;

   function toSlv (d : BlockDisparityType) return slv is
      variable ret : slv(1 downto 0) := "01";
   begin
      case d is
         when -2 =>
            ret := "10";
         when 0 =>
            ret := "11";
         when 2 =>
            ret := "00";
         when 4 =>
            ret := "01";
         when others =>
            ret := "11";
      end case;
      return ret;
   end function;

   function toBlockDisparityType (d : slv(1 downto 0)) return BlockDisparityType is
   begin
      if (d = "10") then
         return -2;
      elsif (d = "11") then
         return 0;
      elsif (d = "00") then
         return 2;
      elsif (d = "01") then
         return 4;
      end if;
      return 0;
   end function;


   -- Given an running disparity and a selected code disparity,
   -- determine whether the selected code needs to be complimented, and what the out disparity is
   -- Should maybe implement DisparityType as a constrained integer and just use math here
   -- instead of this state machine. Not sure which is better.
   procedure disparityControl (
      prevDisp   : in    slv(1 downto 0);
      blockDisp  : in    BlockDisparityType;
      compliment : inout sl) is
      variable dispInt : BlockDisparityType;
   begin
      compliment := '0';
      dispInt := toBlockDisparityType(prevDisp);

      case prevDisp is
         when "10" =>                   -- -2
            if (blockDisp = -2 or blockDisp = -4) then
               compliment := '1';
            end if;
         when "11" =>                   -- 0
            if (blockDisp = -4) then
               compliment := '1';
            end if;
         when "00" =>                   -- 2
            if (blockDisp = 2 or blockDisp = 4) then
               compliment := '1';
            end if;
         when "01" =>                   -- 4
            if (blockDisp = 2 or blockDisp = 4) then
               compliment := '1';
            end if;
         when others =>
            null;
      end case;

   end procedure;

   -------------------------------------------------------------------------------------------------
   -- Make the encode table
   function makeEncode7b8bTable(a : slv8Array(0 to 127)) return Encode7b8bArray is
      variable ret : Encode7b8bArray(0 to 127);
   begin
      for i in ret'range loop
         ret(i).in7b    := conv_std_logic_vector(i, 7);
         ret(i).out8b   := a(i);
         ret(i).outDisp := getDisparity(ret(i).out8b);
         ret(i).altDisp := getDisparity(not ret(i).out8b);
         if (ret(i).outDisp /= 0) then
            ret(i).alt8b := not (ret(i).out8b);
         else
            ret(i).alt8b := ret(i).out8b;
         end if;
      end loop;
      return ret;
   end function makeEncode7b8bTable;

   -------------------------------------------------------------------------------------------------
   -- Make the encode table
   function makeEncode5b6bTable (a : slv6Array(0 to 31)) return Encode5b6bArray is
      variable ret : Encode5b6bArray(0 to 31);
   begin
      for i in ret'range loop
         ret(i).in5b    := conv_std_logic_vector(i, 5);
         ret(i).out6b   := a(i);
         ret(i).outDisp := getDisparity(ret(i).out6b);
         ret(i).altDisp := getDisparity(not ret(i).out6b);
         if (ret(i).outDisp /= 0) then
            ret(i).alt6b := not (ret(i).out6b);
         else
            ret(i).alt6b := ret(i).out6b;
         end if;
         if (ret(i).out6b = "000111") then
            ret(i).alt6b := "111000";
         end if;
      end loop;
      return ret;
   end function makeEncode5b6bTable;

   procedure encode12b14b (
      constant CODES_C : in    EncodeTableType;
      dataIn           : in    slv(11 downto 0);
      dataKIn          : in    sl;
      dispIn           : in    slv(1 downto 0);
      dataOut          : inout slv(13 downto 0);
      dispOut          : inout slv(1 downto 0);
      invalidK         : out   sl)
   is
      variable blockDispIn : BlockDisparityType;

      variable dataIn7     : slv(6 downto 0);
      variable tmp78       : Encode7b8bType;
      variable data8       : slv(7 downto 0);
      variable blockDisp78 : BlockDisparityType;

      variable dataIn5     : slv(4 downto 0);
      variable tmp56       : Encode5b6bType;
      variable data6       : slv(5 downto 0);
      variable blockDisp56 : BlockDisparityType;

      variable debug   : boolean := false;
      variable tmpDisp : integer range -8 to 8;
      variable compliment : sl;
   begin

      -- First, split in input word in two
      dataIn5 := dataIn(11 downto 7);
      dataIn7 := dataIn(6 downto 0);

      -- Now do the 7b8b part
      -- Default lookup first
      tmp78       := CODES_C.data78(conv_integer(dataIn7));
      data8       := tmp78.out8b;
      blockDisp78 := tmp78.outDisp;


      -- Decide whether to invert
      blockDispIn := toBlockDisparityType(dispIn);

      disparityControl(dispIn, blockDisp78, compliment);

      if (compliment = '1') then
         blockDisp78 := tmp78.altDisp;
         data8       := tmp78.alt8b;
      end if;

--       tmpDisp     := blockDispIn + tmp78.outDisp;

--       if ((dispIn = "10" and tmpDisp = 4) or tmpDisp > 4 or tmpDisp <= -4) then
--          blockDisp78 := tmp78.altDisp;
--          data8       := tmp78.alt8b;
--       end if;

--       tmpDisp := blockDispIn + blockDisp78;

      -- Now repeat for the 5b6b
      tmp56       := CODES_C.data56(conv_integer(dataIn5));
      data6       := tmp56.out6b;
      blockDisp56 := tmp56.outDisp;

      -- Decide whether to invert the output
      if ((blockDisp78 > 0 and blockDisp56 > 0) or
          (blockDisp78 < 0 and blockDisp56 < 0) or
          (blockDisp78 = 0 and blockDispIn > 0 and blockDisp56 > 0) or
          (blockDisp78 = 0 and blockDispIn < 0 and blockDisp56 < 0)) then
         blockDisp56 := tmp56.altDisp;
         data6       := tmp56.alt6b;
      end if;

      -- Special case for D/K.x.7
      -- Code is balanced but need to invert to avoid run length limits
      if (dataIn5 = "00111" and (blockDisp78 > 0)) then
         blockDisp56 := tmp56.altDisp;
         data6       := tmp56.alt6b;
      end if;


      dataOut(7 downto 0)  := data8;
      dataOut(13 downto 8) := data6;
      dispOut              := toSlv(blockDispIn + blockDisp56 + blockDisp78);

      -- Control table overrides everything
      if (dataKIn = '1') then
         invalidK := '1';
         -- Search the table for valid K.x
         for i in CODES_C.kTable'range loop
            if (dataIn = CODES_C.kTable(i).k12) then
               dataOut  := CODES_C.kTable(i).k14;
               tmpDisp  := CODES_C.kTable(i).disp;
               invalidK := '0';
            end if;
         end loop;

         if (blockDispIn = 0 or blockDispIn = 2 or blockDispIn = 4) then
            dataOut := not dataOut;
            tmpDisp := getDisparity(dataOut);
         end if;

         dispOut := toSlv(blockDispIn + tmpDisp);
      end if;

   end;

   procedure decode12b14b (
      constant CODES_C : in    EncodeTableType;
      dataIn           : in    slv(13 downto 0);
      dispIn           : in    slv(1 downto 0);
      dataOut          : inout slv(11 downto 0);
      dataKOut         : inout sl;
      dispOut          : inout slv(1 downto 0);
      codeError        : out   sl;
      dispError        : inout sl)
   is
      variable valid78   : sl;
      variable valid56   : sl;
      variable dataIn8   : slv(7 downto 0);
      variable dataIn6   : slv(5 downto 0);
      variable dataOut5  : slv(4 downto 0);
      variable dataOut7  : slv(6 downto 0);
      variable inputDisp : integer;
      variable runDisp   : integer;
   begin

      -- Set default values
      codeError := '1';
      dispError := '0';
      dataKOut  := '0';
      valid78   := '0';
      valid56   := '0';
      dataOut5  := (others => '0');
      dataOut7  := (others => '0');


      -- Check the disparity of the input
      inputDisp := getDisparity(dataIn);
      if (inputDisp > 4 or inputDisp < -4) then
--          print("Input Disp Error");
--          print("dataIn: " & str(dataIn));
--          print("inputDisp: " & str(inputDisp));
         dispError := '1';
      end if;

      -- Check the running disparity
      runDisp := inputDisp + toBlockDisparityType(dispIn);
      if (runDisp > 4 or runDisp < -4) then
         runDisp   := minimum(4, maximum(-4, runDisp));
--          print("Run Disp Error");
--          print("dataIn: " & str(dataIn) & " " & hstr(dataIn));
--          print("dispIn: " & str(toBlockDisparityType(dispIn)));
--          print("inputDisp: " & str(inputDisp));
--          print("runDisp: " & str(runDisp));
         dispError := '1';
      end if;

      -- This probably isn't correct
      -- Need to figure out what to do when running disparity is out of range
      dispOut := toSlv(runDisp);
--       if (dispError = '1') then
--          dispOut := toSlv(0);
--       end if;



      dataIn8 := dataIn(7 downto 0);
      dataIn6 := dataIn(13 downto 8);

--       dataOut7 := dataIn8(6 downto 0);
--       dataOut5 := dataIn6(4 downto 0);

      dataOut(6 downto 0)  := dataIn(6 downto 0);
      dataOut(11 downto 7) := dataIn(12 downto 8);

      -- Check for a k-code
      for i in CODES_C.kTable'range loop
         if (dataIn = CODES_C.kTable(i).k14 or
             dataIn = not CODES_C.kTable(i).k14) then
            dataOut  := CODES_C.kTable(i).k12;
            dataKOut := '1';
            valid56  := '1';
            valid78  := '1';
            exit;
         end if;
      end loop;

      if (dataKOut = '0') then
         -- Decode 7/8
         for i in CODES_C.data78'range loop
            if (dataIn8 = CODES_C.data78(i).out8b or
                dataIn8 = CODES_C.data78(i).alt8b) then
               dataOut7            := CODES_C.data78(i).in7b;
               dataOut(6 downto 0) := CODES_C.data78(i).in7b;
               valid78             := '1';
               exit;
            end if;
         end loop;

         for i in CODES_C.data56'range loop
            if (dataIn6 = CODES_C.data56(i).out6b or
                dataIn6 = CODES_C.data56(i).alt6b) then
               dataOut5             := CODES_C.data56(i).in5b;
               dataOut(11 downto 7) := CODES_C.data56(i).in5b;
               valid56              := '1';
               exit;
            end if;
         end loop;

      end if;

      if (valid56 = '1' and valid78 = '1') then
         codeError := '0';
      end if;


   end procedure decode12b14b;

   -------------------------------------------------------------------------------------------------
   -- Differed constants from above
   -------------------------------------------------------------------------------------------------
   constant K_CODE_TABLE_C : KCodeArray := (
      (k12 => K_120_0_C, k14 => K_120_0_CODE_C, disp => getDisparity(K_120_0_CODE_C)),
      (k12 => K_120_1_C, k14 => K_120_1_CODE_C, disp => getDisparity(K_120_1_CODE_C)),
      (k12 => K_120_2_C, k14 => K_120_2_CODE_C, disp => getDisparity(K_120_2_CODE_C)),
      (k12 => K_120_3_C, k14 => K_120_3_CODE_C, disp => getDisparity(K_120_3_CODE_C)),
      (k12 => K_120_4_C, k14 => K_120_4_CODE_C, disp => getDisparity(K_120_4_CODE_C)),
      (k12 => K_120_7_C, k14 => K_120_7_CODE_C, disp => getDisparity(K_120_7_CODE_C)),
      (k12 => K_120_8_C, k14 => K_120_8_CODE_C, disp => getDisparity(K_120_8_CODE_C)),
      (k12 => K_120_11_C, k14 => K_120_11_CODE_C, disp => getDisparity(K_120_11_CODE_C)),
--      (k12 => K_120_15_C, k14 => K_120_15_CODE_C, disp => getDisparity(K_120_15_CODE_C)),
      (k12 => K_120_16_C, k14 => K_120_16_CODE_C, disp => getDisparity(K_120_16_CODE_C)),
      (k12 => K_120_19_C, k14 => K_120_19_CODE_C, disp => getDisparity(K_120_19_CODE_C)),
      (k12 => K_120_23_C, k14 => K_120_23_CODE_C, disp => getDisparity(K_120_23_CODE_C)),
      (k12 => K_120_24_C, k14 => K_120_24_CODE_C, disp => getDisparity(K_120_24_CODE_C)),
      (k12 => K_120_27_C, k14 => K_120_27_CODE_C, disp => getDisparity(K_120_27_CODE_C)),
      (k12 => K_120_29_C, k14 => K_120_29_CODE_C, disp => getDisparity(K_120_29_CODE_C)),
      (k12 => K_120_30_C, k14 => K_120_30_CODE_C, disp => getDisparity(K_120_30_CODE_C)),
      (k12 => K_120_31_C, k14 => K_120_31_CODE_C, disp => getDisparity(K_120_31_CODE_C)));
--       (k12 => K_55_15_C, k14 => K_55_15_CODE_C, disp => getDisparity(K_55_15_CODE_C)),
--       (k12 => K_57_15_C, k14 => K_57_15_CODE_C, disp => getDisparity(K_57_15_CODE_C)),
--       (k12 => K_87_15_C, k14 => K_87_15_CODE_C, disp => getDisparity(K_87_15_CODE_C)),
--       (k12 => K_93_15_C, k14 => K_93_15_CODE_C, disp => getDisparity(K_93_15_CODE_C)),
--       (k12 => K_117_15_C, k14 => K_117_15_CODE_C, disp => getDisparity(K_117_15_CODE_C)));


   constant ENCODE_7B8B_TABLE_C : Encode7b8bArray := makeEncode7b8bTable(CODE_8B_C);
   constant ENCODE_5B6B_TABLE_C : Encode5b6bArray := makeEncode5b6bTable(CODE_6B_C);

   constant ENCODE_TABLE_C : EncodeTableType := (
      data78 => ENCODE_7B8B_TABLE_C,
      data56 => ENCODE_5B6B_TABLE_C,
      kTable => K_CODE_TABLE_C);

end package body Code12b14bPkg;
