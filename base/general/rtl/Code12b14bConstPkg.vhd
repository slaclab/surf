-------------------------------------------------------------------------------
-- File       : Code12b14bPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-10-05
-- Last update: 2016-10-17
-------------------------------------------------------------------------------
-- Description: 12B14B Constant Package File
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

use work.StdRtlPkg.all;
use work.Code12b14bPkg.all;
use work.Code7b8bPkg.all;

package Code12b14bConstPkg is

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


   -- 7b/8b K code constants
   constant K_55_C  : slv(6 downto 0) := "0110111";
   constant K_57_C  : slv(6 downto 0) := "0111001";
   constant K_87_C  : slv(6 downto 0) := "1010111";
   constant K_93_C  : slv(6 downto 0) := "1011101";
   constant K_117_C : slv(6 downto 0) := "1110101";
   constant K_120_C : slv(6 downto 0) := "1111000";

   constant K_55_CODE_C  : slv(7 downto 0) := "10110111";
   constant K_57_CODE_C  : slv(7 downto 0) := "10111001";
   constant K_87_CODE_C  : slv(7 downto 0) := "11010111";
   constant K_93_CODE_C  : slv(7 downto 0) := "11011101";
   constant K_117_CODE_C : slv(7 downto 0) := "11110101";
   constant K_120_CODE_C : slv(7 downto 0) := "11111000";

   constant K_55_DISP_C  : BlockDisparityType := getDisparity(K_55_CODE_C);
   constant K_57_DISP_C  : BlockDisparityType := getDisparity(K_57_CODE_C);
   constant K_87_DISP_C  : BlockDisparityType := getDisparity(K_87_CODE_C);
   constant K_93_DISP_C  : BlockDisparityType := getDisparity(K_93_CODE_C);
   constant K_117_DISP_C : BlockDisparityType := getDisparity(K_117_CODE_C);
   constant K_120_DISP_C : BlockDisparityType := getDisparity(K_120_CODE_C);

   constant K78_TABLE_C : Encode7b8bArray(0 to 0) := (
      0          => (
         in7b    => K_120_C,
         out8b   => K_120_CODE_C,
         outDisp => K_120_DISP_C,
         alt8b   => not K_120_CODE_C,
         altDisp => getDisparity(not K_120_CODE_C)));


   -- 5b/6b K Codes
   constant K_X_0_C  : slv(4 downto 0) := "00000";
   constant K_X_1_C  : slv(4 downto 0) := "00001";
   constant K_X_2_C  : slv(4 downto 0) := "00010";
   constant K_X_3_C  : slv(4 downto 0) := "00011";
   constant K_X_4_C  : slv(4 downto 0) := "00100";
   constant K_X_7_C  : slv(4 downto 0) := "00111";
   constant K_X_8_C  : slv(4 downto 0) := "01000";
   constant K_X_11_C : slv(4 downto 0) := "01011";
   constant K_X_15_C : slv(4 downto 0) := "01111";
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
   constant K_X_15_CODE_C : slv(5 downto 0) := "000011";
   constant K_X_16_CODE_C : slv(5 downto 0) := "001001";
   constant K_X_19_CODE_C : slv(5 downto 0) := "010011";
   constant K_X_23_CODE_C : slv(5 downto 0) := "101000";
   constant K_X_24_CODE_C : slv(5 downto 0) := "001100";
   constant K_X_27_CODE_C : slv(5 downto 0) := "100100";
   constant K_X_29_CODE_C : slv(5 downto 0) := "100010";
   constant K_X_30_CODE_C : slv(5 downto 0) := "100001";
   constant K_X_31_CODE_C : slv(5 downto 0) := "001010";

   constant K_X_0_DISP_C  : BlockDisparityType := getDisparity(K_X_0_CODE_C);
   constant K_X_1_DISP_C  : BlockDisparityType := getDisparity(K_X_1_CODE_C);
   constant K_X_2_DISP_C  : BlockDisparityType := getDisparity(K_X_2_CODE_C);
   constant K_X_3_DISP_C  : BlockDisparityType := getDisparity(K_X_3_CODE_C);
   constant K_X_4_DISP_C  : BlockDisparityType := getDisparity(K_X_4_CODE_C);
   constant K_X_7_DISP_C  : BlockDisparityType := getDisparity(K_X_7_CODE_C);
   constant K_X_8_DISP_C  : BlockDisparityType := getDisparity(K_X_8_CODE_C);
   constant K_X_11_DISP_C : BlockDisparityType := getDisparity(K_X_11_CODE_C);
   constant K_X_15_DISP_C : BlockDisparityType := getDisparity(K_X_15_CODE_C);
   constant K_X_16_DISP_C : BlockDisparityType := getDisparity(K_X_16_CODE_C);
   constant K_X_19_DISP_C : BlockDisparityType := getDisparity(K_X_19_CODE_C);
   constant K_X_23_DISP_C : BlockDisparityType := getDisparity(K_X_23_CODE_C);
   constant K_X_24_DISP_C : BlockDisparityType := getDisparity(K_X_24_CODE_C);
   constant K_X_27_DISP_C : BlockDisparityType := getDisparity(K_X_27_CODE_C);
   constant K_X_29_DISP_C : BlockDisparityType := getDisparity(K_X_29_CODE_C);
   constant K_X_30_DISP_C : BlockDisparityType := getDisparity(K_X_30_CODE_C);
   constant K_X_31_DISP_C : BlockDisparityType := getDisparity(K_X_31_CODE_C);

   constant K56_TABLE_C : Encode5b6bArray(0 to 16) := (
      (in5b => K_X_0_C, out6b => K_X_0_CODE_C, outDisp => K_X_0_DISP_C, alt6b => not K_X_0_CODE_C, altDisp => getDisparity(not K_X_0_CODE_C)),
      (in5b => K_X_1_C, out6b => K_X_1_CODE_C, outDisp => K_X_1_DISP_C, alt6b => not K_X_1_CODE_C, altDisp => getDisparity(not K_X_1_CODE_C)),
      (in5b => K_X_2_C, out6b => K_X_2_CODE_C, outDisp => K_X_2_DISP_C, alt6b => not K_X_2_CODE_C, altDisp => getDisparity(not K_X_2_CODE_C)),
      (in5b => K_X_3_C, out6b => K_X_3_CODE_C, outDisp => K_X_3_DISP_C, alt6b => not K_X_3_CODE_C, altDisp => getDisparity(not K_X_3_CODE_C)),
      (in5b => K_X_4_C, out6b => K_X_4_CODE_C, outDisp => K_X_4_DISP_C, alt6b => not K_X_4_CODE_C, altDisp => getDisparity(not K_X_4_CODE_C)),
      (in5b => K_X_7_C, out6b => K_X_7_CODE_C, outDisp => K_X_7_DISP_C, alt6b => not K_X_7_CODE_C, altDisp => getDisparity(not K_X_7_CODE_C)),
      (in5b => K_X_8_C, out6b => K_X_8_CODE_C, outDisp => K_X_8_DISP_C, alt6b => not K_X_8_CODE_C, altDisp => getDisparity(not K_X_8_CODE_C)),
      (in5b => K_X_11_C, out6b => K_X_11_CODE_C, outDisp => K_X_11_DISP_C, alt6b => not K_X_11_CODE_C, altDisp => getDisparity(not K_X_11_CODE_C)),
      (in5b => K_X_15_C, out6b => K_X_15_CODE_C, outDisp => K_X_15_DISP_C, alt6b => not K_X_15_CODE_C, altDisp => getDisparity(not K_X_15_CODE_C)),
      (in5b => K_X_16_C, out6b => K_X_16_CODE_C, outDisp => K_X_16_DISP_C, alt6b => not K_X_16_CODE_C, altDisp => getDisparity(not K_X_16_CODE_C)),
      (in5b => K_X_19_C, out6b => K_X_19_CODE_C, outDisp => K_X_19_DISP_C, alt6b => not K_X_19_CODE_C, altDisp => getDisparity(not K_X_19_CODE_C)),
      (in5b => K_X_23_C, out6b => K_X_23_CODE_C, outDisp => K_X_23_DISP_C, alt6b => not K_X_23_CODE_C, altDisp => getDisparity(not K_X_23_CODE_C)),
      (in5b => K_X_24_C, out6b => K_X_24_CODE_C, outDisp => K_X_24_DISP_C, alt6b => not K_X_24_CODE_C, altDisp => getDisparity(not K_X_24_CODE_C)),
      (in5b => K_X_27_C, out6b => K_X_27_CODE_C, outDisp => K_X_27_DISP_C, alt6b => not K_X_27_CODE_C, altDisp => getDisparity(not K_X_27_CODE_C)),
      (in5b => K_X_29_C, out6b => K_X_29_CODE_C, outDisp => K_X_29_DISP_C, alt6b => not K_X_29_CODE_C, altDisp => getDisparity(not K_X_29_CODE_C)),
      (in5b => K_X_30_C, out6b => K_X_30_CODE_C, outDisp => K_X_30_DISP_C, alt6b => not K_X_30_CODE_C, altDisp => getDisparity(not K_X_30_CODE_C)),
      (in5b => K_X_31_C, out6b => K_X_31_CODE_C, outDisp => K_X_31_DISP_C, alt6b => not K_X_31_CODE_C, altDisp => getDisparity(not K_X_31_CODE_C)));

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

   constant ENCODE_7B8B_TABLE_C : Encode7b8bArray := makeEncode7b8bTable(CODE_8B_C);


   constant CODE_6B_C : slv6Array(0 to 31) := (
      "000110", "010001", "010010", "100011", "010100", "100101", "100110", "000111",
      "011000", "101001", "101010", "001011", "101100", "001101", "001110", "111010",
      "110110", "110001", "110010", "010011", "110100", "010101", "010110", "010111",
      "001100", "011001", "011010", "011011", "011100", "011101", "011110", "110101");

   constant ENCODE_5B6B_TABLE_C : Encode5b6bArray := makeEncode5b6bTable(CODE_6B_C);
--    constant DECODE_5B6B_TABLE_C : Decode5b6bArray := makeDecode5b6bArray;

   constant ENCODE_TABLE_C : EncodeTableType := (
      data78 => ENCODE_7B8B_TABLE_C,
      data56 => ENCODE_5B6B_TABLE_C,
      k78    => K78_TABLE_C,
      k56    => K56_TABLE_C);


end package;

