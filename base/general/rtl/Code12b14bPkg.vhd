-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Code12b14bPkg.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-10-05
-- Last update: 2016-10-12
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of SURF. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of SURF, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.Code7b8bPkg.all;
use work.TextUtilPkg.all;


package Code12b14bPkg is

   subtype DisparityType is integer range -4 to 4;
   subtype DisparityOutType is integer range -2 to 4;
   constant DISP_N4_S : integer := -4;
   constant DISP_N2_S : integer := -2;
   constant DISP_Z_S  : integer := 0;
   constant DISP_P2_S : integer := 2;
   constant DISP_P4_S : integer := 4;

   function getDisparity (vec : slv) return DisparityType;

   function toSlv (      d : DisparityOutType)      return slv;
   function toDisparityOutType (      d : slv(1 downto 0))      return DisparityOutType;

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

   type KCodeEntryType is record
      k12  : slv(11 downto 0);
      k14  : slv(13 downto 0);
      disp : DisparityType;
   end record KCodeEntryType;

   type KCodeArray is array (natural range <>) of KCodeEntryType;

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

   -------------------------------------------------------------------------------------------------
   -- Use special type for disparity
   -- Allows specific encoding to be changed later if necessary
   -------------------------------------------------------------------------------------------------
--    type DisparityType is (DISP_N4_S, DISP_N2_S, DISP_Z_S, DISP_P2_S, DISP_P4_S);
--    subtype DisparityOutType is DisparityType range DISP_N2_S to DISP_P4_S;



   procedure encode12b14b (
      dataIn   : in  slv(11 downto 0);
      dataKIn  : in  sl;
      dispIn   : in  DisparityOutType;
      dataOut  : out slv(13 downto 0);
      dispOut  : out DisparityOutType;
      invalidK : out sl);

   -- These are for internal use
   -- 7b/8b K code constants
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

--    constant K_55_DISP_C  : DisparityType := getDisparity(K_55_CODE_C);
--    constant K_57_DISP_C  : DisparityType := getDisparity(K_57_CODE_C);
--    constant K_87_DISP_C  : DisparityType := getDisparity(K_87_CODE_C);
--    constant K_93_DISP_C  : DisparityType := getDisparity(K_93_CODE_C);
--    constant K_117_DISP_C : DisparityType := getDisparity(K_117_CODE_C);
   constant K_120_DISP_C : DisparityType := getDisparity(K_120_CODE_C);

   type K78EntryType is record
      b7   : slv(6 downto 0);
      b8   : slv(7 downto 0);
      disp : DisparityType;
   end record K78EntryType;

   type K78Array is array (natural range <>) of K78EntryType;

--    constant K_7B8B_TABLE_C : K78Array := (
--       (b7 => K_55_C, b8 => K_55_CODE_C, disp => K_55_DISP_C),
--       (b7 => K_57_C, b8 => K_57_CODE_C, disp => K_57_DISP_C),
--       (b7 => K_87_C, b8 => K_87_CODE_C, disp => K_87_DISP_C),
--       (b7 => K_93_C, b8 => K_93_CODE_C, disp => K_93_DISP_C),
--       (b7 => K_117_C, b8 => K_117_CODE_C, disp => K_117_DISP_C),
--       (b7 => K_120_C, b8 => K_120_CODE_C, disp => K_120_DISP_C));

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

   constant K_X_0_CODE_C  : slv(5 downto 0) := "000110";
   constant K_X_1_CODE_C  : slv(5 downto 0) := "010001";
   constant K_X_2_CODE_C  : slv(5 downto 0) := "010010";
   constant K_X_3_CODE_C  : slv(5 downto 0) := "100011";
   constant K_X_4_CODE_C  : slv(5 downto 0) := "010100";
   constant K_X_7_CODE_C  : slv(5 downto 0) := "111000";
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

   constant K_X_0_DISP_C  : DisparityType := getDisparity(K_X_0_CODE_C);
   constant K_X_1_DISP_C  : DisparityType := getDisparity(K_X_1_CODE_C);
   constant K_X_2_DISP_C  : DisparityType := getDisparity(K_X_2_CODE_C);
   constant K_X_3_DISP_C  : DisparityType := getDisparity(K_X_3_CODE_C);
   constant K_X_4_DISP_C  : DisparityType := getDisparity(K_X_4_CODE_C);
   constant K_X_7_DISP_C  : DisparityType := getDisparity(K_X_7_CODE_C);
   constant K_X_8_DISP_C  : DisparityType := getDisparity(K_X_8_CODE_C);
   constant K_X_11_DISP_C : DisparityType := getDisparity(K_X_11_CODE_C);
--   constant K_X_15_DISP_C : DisparityType := getDisparity(K_X_15_CODE_C);
   constant K_X_16_DISP_C : DisparityType := getDisparity(K_X_16_CODE_C);
   constant K_X_19_DISP_C : DisparityType := getDisparity(K_X_19_CODE_C);
   constant K_X_23_DISP_C : DisparityType := getDisparity(K_X_23_CODE_C);
   constant K_X_24_DISP_C : DisparityType := getDisparity(K_X_24_CODE_C);
   constant K_X_27_DISP_C : DisparityType := getDisparity(K_X_27_CODE_C);
   constant K_X_29_DISP_C : DisparityType := getDisparity(K_X_29_CODE_C);
   constant K_X_30_DISP_C : DisparityType := getDisparity(K_X_30_CODE_C);
   constant K_X_31_DISP_C : DisparityType := getDisparity(K_X_31_CODE_C);

   type K56EntryType is record
      b5   : slv(4 downto 0);
      b6   : slv(5 downto 0);
      disp : DisparityType;
   end record;

   type K56Array is array (natural range <>) of K56EntryType;

   constant K_5B6B_TABLE_C : K56Array := (
      (b5 => K_X_0_C, b6 => K_X_0_CODE_C, disp => K_X_0_DISP_C),
      (b5 => K_X_1_C, b6 => K_X_1_CODE_C, disp => K_X_1_DISP_C),
      (b5 => K_X_2_C, b6 => K_X_2_CODE_C, disp => K_X_2_DISP_C),
      (b5 => K_X_3_C, b6 => K_X_3_CODE_C, disp => K_X_3_DISP_C),
      (b5 => K_X_4_C, b6 => K_X_4_CODE_C, disp => K_X_4_DISP_C),
      (b5 => K_X_7_C, b6 => K_X_7_CODE_C, disp => K_X_7_DISP_C),
      (b5 => K_X_8_C, b6 => K_X_8_CODE_C, disp => K_X_8_DISP_C),
      (b5 => K_X_11_C, b6 => K_X_11_CODE_C, disp => K_X_11_DISP_C),
--      (b5 => K_X_15_C, b6 => K_X_15_CODE_C, disp => K_X_15_DISP_C),
      (b5 => K_X_16_C, b6 => K_X_16_CODE_C, disp => K_X_16_DISP_C),
      (b5 => K_X_19_C, b6 => K_X_19_CODE_C, disp => K_X_19_DISP_C),
      (b5 => K_X_23_C, b6 => K_X_23_CODE_C, disp => K_X_23_DISP_C),
      (b5 => K_X_24_C, b6 => K_X_24_CODE_C, disp => K_X_24_DISP_C),
      (b5 => K_X_27_C, b6 => K_X_27_CODE_C, disp => K_X_27_DISP_C),
      (b5 => K_X_29_C, b6 => K_X_29_CODE_C, disp => K_X_29_DISP_C),
      (b5 => K_X_30_C, b6 => K_X_30_CODE_C, disp => K_X_30_DISP_C),
      (b5 => K_X_31_C, b6 => K_X_31_CODE_C, disp => K_X_31_DISP_C));


   -------------------------------------------------------------------------------------------------
   -- 7B8B Code Constants
   -------------------------------------------------------------------------------------------------
--   type Code8bArray is array (0 to 127) of slv(7 downto 0);

   -- Array of codes for 7b/8b D codes
--    constant CODE_8B_C : Code8bArray := (
--       "00011010", "11110001", "10101110", "00100011", "00001101", "00010101",
--       "00100110", "10000111", "00010011", "00100101", "00101001", "10001011",
--       "00101100", "10001101", "10001110", "00001111", "00101010", "00110001",
--       "00110010", "10010011", "00110100", "10010101", "10010110", "00010111",
--       "01000101", "10011001", "10011010", "10011011", "10011100", "00011101",
--       "00011110", "00011001", "01000111", "01100001", "01001001", "10100011",
--       "01001010", "10100101", "10100110", "00100111", "01011000", "10101001",
--       "10101010", "10101011", "10101100", "10101101", "00101110", "00101111",
--       "01001100", "10110001", "10110010", "00110011", "10110100", "00110101",
--       "00110110", "00110111", "10111000", "00111001", "00111010", "00111011",
--       "00111100", "00111101", "00111110", "00011011", "01000100", "00011100",
--       "01100010", "11000011", "00100100", "11000101", "11000110", "11000111",
--       "01101000", "11001001", "11001010", "01001011", "11001100", "01001101",
--       "01001110", "01001111", "01110000", "11010001", "11010010", "01010011",
--       "11010100", "01010101", "01010110", "01010111", "11011000", "01011001",
--       "01011010", "01011011", "01011100", "01011101", "01011110", "00101011",
--       "00101101", "11100001", "11100010", "01100011", "11100100", "01100101",
--       "01100110", "01100111", "11101000", "01101001", "01101010", "01101011",
--       "01101100", "01101101", "01101110", "01000011", "11110000", "01110001",
--       "01110010", "01110011", "01110100", "01110101", "01110110", "01110111",
--       "01111000", "01111001", "01111010", "01111011", "01111100", "10111101",
--       "11110100", "11101001");

   type Encode7b8bType is record
      disp  : DisparityType;
      out8b : slv(7 downto 0);
      alt8b : slv(7 downto 0);
   end record Encode7b8bType;

   type Encode7b8bArray is array (0 to 127) of Encode7b8bType;

   function makeEncode7b8bTable return Encode7b8bArray;

   constant ENCODE_7B8B_TABLE_C : Encode7b8bArray := makeEncode7b8bTable;



--    type Decode7b8bType is record
--       valid : sl;
--       out7b : slv(6 downto 0);
--       k     : sl;
--       din   : DisparityType;
--       dout  : DisparityType;
--    end record Decode7b8bType;

--    type Decode7b8bArray is array (0 to 255) of Decode7b8bType;

--    function makeDecode7b8bTable return Decode7b8bArray;

--    constant DECODE_7B8B_TABLE_C : Decode7b8bArray := makeDecode7b8bTable;

   -------------------------------------------------------------------------------------------------
   -- 5B6B Code Constants
   -------------------------------------------------------------------------------------------------
   type Code5b6bArray is array (0 to 31) of slv(5 downto 0);

   constant CODE_6B_C : Code5b6bArray := (
      "000110", "010001", "010010", "100011", "010100", "100101",
      "100110", "000111", "011000", "101001", "101010", "001011",
      "101100", "001101", "001110", "111010", "110110", "110001",
      "110010", "010011", "110100", "010101", "010110", "010111",
      "001100", "011001", "011010", "011011", "011100", "011101",
      "011110", "110101");

   constant CODE_5B6B_A15_C : slv(5 downto 0) := "111100";

   type Encode5b6bType is record
      disp  : DisparityType;
      out6b : slv(5 downto 0);
      alt6b : slv(5 downto 0);
   end record Encode5b6bType;

   type Encode5b6bArray is array (0 to 31) of Encode5b6bType;

   function makeEncode5b6bTable return Encode5b6bArray;

   constant ENCODE_5B6B_TABLE_C : Encode5b6bArray := makeEncode5b6bTable;

--    type Decode5b6bType is record
--       valid : sl;
--       out5b : slv(4 downto 0);
--       k     : sl;
--       din   : DisparityType;
--       dout  : DisparityType;
--    end record Decode5b6bType;

--   type Decode5b6bArray is array (0 to 255) of Decode5b6bType;

--    function makeDecode5b6bArray return Decode5b6bArray;

--    constant DECODE_5B6B_TABLE_C : Decode5b6bArray := makeDecode5b6bArray;

   -------------------------------------------------------------------------------------------------
   -- Control Code constants
   -------------------------------------------------------------------------------------------------

end package Code12b14bPkg;

package body Code12b14bPkg is

   -- Determine the disparity of a vector
   function getDisparity (vec : slv) return DisparityType is
      variable ones      : integer;
      variable zeros     : integer;
      variable disparity : DisparityType;
   begin
      zeros := 0;
      ones  := 0;
      for i in vec'range loop
         if (vec(i) = '0') then
            zeros := zeros + 1;
         end if;
      end loop;

      ones      := vec'length-zeros;
      disparity := ones-zeros;

      return disparity;
--       case disparity is
--          when -4 => return DISP_N4_S;
--          when -2 => return DISP_N2_S;
--          when 0  => return DISP_Z_S;
--          when 2  => return DISP_P2_S;
--          when 4  => return DISP_P4_S;
--          when others =>
--             return DISP_Z_S;
--             report "getDisparity(): Disparity of vector: " &
--                str(vec) & " - " & str(disparity) & " excedes +/- 4"
--                severity error;
--       end case;
   end function getDisparity;

   function toSlv (      d : DisparityOutType)      return slv is
      variable ret : slv(1 downto 0) := "01";
   begin
      if (d = -2) then
         ret := "00";
      elsif (d = 0) then
         ret := "01";
      elsif (d = 2) then
         ret := "10";
      elsif (d = 4) then
         ret := "11";
      end if;
      return ret;
   end function;
      
   function toDisparityOutType (      d : slv(1 downto 0))      return DisparityOutType is
      variable ret : DisparityOutType := 2;
   begin
      if (d = "00") then
         return -2;
      elsif (d = "01") then
         return 0;
      elsif (d = "10") then
         return 2;
      elsif (d = "11") then
         return 4;
      end if;
      return 0;
   end function;


   -- Given an running disparity and a selected code disparity,
   -- determine whether the selected code needs to be complimented, and what the out disparity is
   -- Should maybe implement DisparityType as a constrained integer and just use math here
   -- instead of this state machine. Not sure which is better.
--    procedure disparityControl (
--       prevDisp   : in    DisparityOutType;
--       blockDisp  : in    DisparityType;
--       compliment : inout sl;
--       nextDisp   : inout DisparityOutType) is
--    begin
--       compliment := '0';
--       case prevDisp is
--          when DISP_N2_S =>
--             if (blockDisp = DISP_N2_S) then
--                compliment := '1';
--                nextDisp   := DISP_Z_S;
--             elsif (blockDisp = DISP_N4_S) then
--                compliment := '1';
--                nextDisp   := DISP_P2_S;
--             else
--                nextDisp := DisparityOutType'leftof(blockDisp);
--             end if;

--          when DISP_Z_S =>
--             if (blockDisp = DISP_N4_S) then
--                compliment := '1';
--                nextDisp   := DISP_P4_S;
--             else
--                nextDisp := blockDisp;
--             end if;

--          when DISP_P2_S =>
--             if (blockDisp = DISP_P4_S) then
--                compliment := '1';
--                nextDisp   := DISP_N2_S;
--             elsif (blockDisp = DISP_P2_S) then
--                compliment := '1';
--                nextDisp   := DISP_Z_S;
--             else
--                nextDisp := DisparityType'rightof(blockDisp);
--             end if;

--          when DISP_P4_S =>
--             if (blockDisp = DISP_P4_S) then
--                compliment := '1';
--                nextDisp   := DISP_Z_S;
--             elsif (blockDisp = DISP_P2_S) then
--                compliment := '1';
--                nextDisp   := DISP_P2_S;
--             else
--                nextDisp := DisparityType'rightof(blockDisp);
--                nextDisp := DisparityType'rightof(nextDisp);
--             end if;

--       end case;
--    end procedure disparityControl;

   procedure disparityControl (
      prevDisp   : in    DisparityOutType;
      blockDisp  : in    DisparityType;
      compliment : inout sl;
      nextDisp   : inout DisparityOutType)
   is
      variable tmp : integer;
   begin
      compliment         := '0';
      tmp                := prevDisp + blockDisp;
      if (tmp > 4 or tmp <= -4) then
         compliment := '1';
         tmp        := prevDisp - blockDisp;
      end if;
      nextDisp := tmp;
   end procedure;

   -------------------------------------------------------------------------------------------------
   -- Make the encode table
   function makeEncode7b8bTable return Encode7b8bArray is
      variable ret : Encode7b8bArray;
   begin
      for i in ret'range loop
         ret(i).out8b := CODE_8B_C(i);
         ret(i).disp  := getDisparity(ret(i).out8b);
         if (ret(i).disp /= DISP_Z_S) then
            ret(i).alt8b := not (ret(i).out8b);
         else
            ret(i).alt8b := ret(i).out8b;
         end if;
      end loop;
      return ret;
   end function makeEncode7b8bTable;

   -- Make the decode table
--    function makeDecode7b8bArray return Decode7b8bArray is
--       variable ret : Decode7b8bArray := (others => DECODE_7B8B_INIT_C);
--       variable tmp : integer;
--    begin
--       for i in ENCODE_7B8B_TABLE_C'range loop
--          tmp            := conv_integer(ENCODE_7B8B_TABLE_C(i).out8b);
--          ret(tmp).valid := '1'
--          ret(tmp).out7b := conv_std_logic_vector(i, 7);

--          tmp            := conv_integer(ENCODE_7B8B_TABLE_C(i).alt8b);
--          ret(tmp).valid := '1';
--          ret(tmp).out7b := conv_std_logic_vector(i, 7);
--       end loop;
--       return ret;
--    end function makeDecode7b8bArray;

   -------------------------------------------------------------------------------------------------
   -- Make the encode table
   function makeEncode5b6bTable
      return Encode5b6bArray
   is
      variable ret : Encode5b6bArray;
   begin
      for i in ret'range loop
         ret(i).out6b := CODE_6B_C(i);
         ret(i).disp  := getDisparity(ret(i).out6b);
         if (ret(i).disp /= DISP_Z_S) then
            ret(i).alt6b := not (ret(i).out6b);
         else
            ret(i).alt6b := ret(i).out6b;
         end if;
      end loop;
      return ret;
   end function makeEncode5b6bTable;

   -- Make the decode table
--    function makeDecode5b6bArray return Decode5b6bArray is
--       variable ret : Decode5b6bArray := (others => DECODE_5B6B_INIT_C);
--       variable tmp : integer;
--    begin
--       for i in ENCODE_5B6B_TABLE_C'range loop
--          tmp            := conv_integer(ENCODE_5B6B_TABLE_C(i).out6b);
--          ret(tmp).valid := '1'
--          ret(tmp).out5b := conv_std_logic_vector(i, 7);

--          tmp            := conv_integer(ENCODE_5B6B_TABLE_C(i).alt6b);
--          ret(tmp).valid := '1';
--          ret(tmp).out5b := conv_std_logic_vector(i, 7);
--       end loop;
--       return ret;
--    end function makeDecode5b6bArray;



   procedure encode12b14b (
      dataIn   : in  slv(11 downto 0);
      dataKIn  : in  sl;
      dispIn   : in  DisparityOutType;
      dataOut  : out slv(13 downto 0);
      dispOut  : out DisparityOutType;
      invalidK : out sl)
   is
      variable dataIn7   : slv(6 downto 0);
      variable data8     : slv(7 downto 0);
      variable disp78    : DisparityType;
      variable dataIn5   : slv(4 downto 0);
      variable data6     : slv(5 downto 0);
      variable disp56    : DisparityType;
      variable blockDisp : DisparityType;

      variable tmp78      : Encode7b8bType;
      variable tmp56      : Encode5b6bType;
      variable compliment : sl;
      variable dispK      : DisparityType;

      variable debug : boolean := false;
   begin



      -- First, split in input word in two
      dataIn5 := dataIn(11 downto 7);
      dataIn7 := dataIn(6 downto 0);

      -- Now do the 7b8b part
      -- Default lookup first
      tmp78     := ENCODE_7B8B_TABLE_C(conv_integer(dataIn7));
      data8     := tmp78.out8b;
      blockDisp := tmp78.disp;

      -- pragma translate_off
      print(debug, "--------------");
      print(debug, "data7: " & str(dataIn7));
      print(debug, "data8: " & str(data8));
      print(debug, "blockDisp: " & str(blockDisp));
      print(debug, "dispIn: " & str(dispIn));
      -- pragma translate_on

      -- Override normal table lookup for control codes
--       if (dataKIn = '1') then
--          invalidK := '1';
--          -- Search the table for valid K.x
--          for i in K_7B8B_TABLE_C'range loop
--             if (dataIn7 = K_7B8B_TABLE_C(i).b7) then
--                data8     := K_7B8B_TABLE_C(i).b8;
--                blockDisp := K_7B8B_TABLE_C(i).disp;
--                invalidK  := '0';
--             end if;
--          end loop;
--       end if;

      -- Decide whether to invert the output
      disparityControl(dispIn, blockDisp, compliment, disp78);
      -- pragma translate_off
      print(debug, "compliment: " & str(compliment));
      -- pragma translate_on

      -- Special case for D15
--       if (dataIn7 = "0001111" and (dispIn = DISP_P2_S or dispIn = DISP_P4_S)) then
--          compliment := '1';
--       end if;

      if (compliment = '1') then
         data8 := not data8;
      end if;
      -- pragma translate_off
      print(debug, "final data8: " & str(data8));
      print(debug, "disp78: " & str(disp78));
      print(debug, "--------------");
      -- pragma translate_on

      -- Now repeat for the 5b6b
      tmp56     := ENCODE_5B6B_TABLE_C(conv_integer(dataIn5));
      data6     := tmp56.out6b;
      blockDisp := tmp56.disp;
      -- pragma translate_off
      print(debug, "data5: " & str(dataIn5));
      print(debug, "data6: " & str(data6));
      print(debug, "blockDisp: " & str(blockDisp));
      -- pragma translate_on

      -- Hard code the K codes
--       if (dataKIn = '1' and invalidK = '0') then
--          invalidk := '1';

--          -- If on a K.120.y, check for valid y
--          if (dataIn7 = K_120_C) then      -- K.120
--             -- Search for a valid K.120.y
--             for i in K_5B6B_TABLE_C'range loop
--                if (dataIn5 = K_5B6B_TABLE_C(i).b6) then
--                   data6     := K_5B6B_TABLE_C(i).b6;
--                   blockDisp := K_5B6B_TABLE_C(i).disp;
--                   invalidK  := '0';
--                end if;
--             end loop;
--          end if;

--          -- If on a K.x.15, check for valid x
--          if (dataIn5 = K_X_15_C) then     -- K.x.15
--             data6     := K_X_15_CODE_C;
--             blockDisp := K_X_15_DISP_C;
--             for i in K_7B8B_TABLE_C'range loop
--                if (dataIn7 = K_7B8B_TABLE_C(i).b7) then
--                   invalidK := '0';
--                end if;
--             end loop;
--          end if;
--       end if;

      -- Decide whether to invert the output
      disparityControl(disp78, blockDisp, compliment, disp56);


      -- Special case for D/K.x.7
      -- Code is balanced but need to invert to avoid run length limits
      if (dataIn5 = "00111" and (disp78 = 2 or disp78 = 4)) then
         -- pragma translate_off
         print(debug, "D.x.7 special case. Complement = 1");
         -- pragma translate_on
         compliment := '1';
      end if;

      -- pragma translate_off
      print(debug, "compliment: " & str(compliment));
      -- pragma translate_on

      if (compliment = '1') then
         data6 := not data6;
      end if;

      -- pragma translate_off
      print(debug, "data6: " & str(data6));
      -- pragma translate_on

--       if (data8(7 downto 5) = "111" and data6 = "001111") then
--          -- pragma translate_off
--          print(debug, "D.x.15 special case");
--          -- pragma translate_on
--          data6 := CODE_5B6B_A15_C;
--          disparityControl(disp78, 2, compliment, disp56);
--          print(debug, "data6: " & str(data6));
--       elsif (data8(7 downto 5) = "000" and data6 = "110000") then
--          -- pragma translate_off
--          print(debug, "D.x.15 special case");
--          -- pragma translate_on
--          data6 := not CODE_5B6B_A15_C;
--          disparityControl(disp78, -2, compliment, disp56);
--          -- pragma translate_off
--          print(debug, "data6: " & str(data6));
--       -- pragma translate_on
--       end if;
      -- pragma translate_off
      print(debug, "disp56: " & str(disp56));

      print(debug, "--------------------------");
      -- pragma translate_on

      dataOut(7 downto 0)  := data8;
      dataOut(13 downto 8) := data6;
      dispOut              := disp56;

      -- If k-code being sent, override everything above and select the proper code
      -- from the K_CODE_TABLE_C.
      if (dataKIn = '1') then
         invalidK := '1';
         -- Search table of KCODES
         for i in K_CODE_TABLE_C'range loop
            if (dataIn = K_CODE_TABLE_C(i).k12) then
               dataOut   := K_CODE_TABLE_C(i).k14;
               blockDisp := K_CODE_TABLE_C(i).disp;
               disparityControl(dispIn, blockDisp, compliment, dispK);
               if (compliment = '1') then
                  dataOut := not K_CODE_TABLE_C(i).k14;
               end if;
               dispOut  := dispK;
               invalidK := '0';
            end if;
         end loop;
      end if;


   end;


end package body Code12b14bPkg;
