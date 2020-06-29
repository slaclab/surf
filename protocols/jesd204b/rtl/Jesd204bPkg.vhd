-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: JESD204B Package File
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

library surf;
use surf.StdRtlPkg.all;

package Jesd204bPkg is

-- Constant definitions
--------------------------------------------------------------------------
   -- Number of bytes in MGT word (2 or 4).
   constant GT_WORD_SIZE_C : positive := 4;

   -- 8B10B characters (8-bit values)
   -- K.28.5
   constant K_CHAR_C : slv(7 downto 0) := x"BC";
   -- K.28.0
   constant R_CHAR_C : slv(7 downto 0) := x"1C";
   -- K.28.3
   constant A_CHAR_C : slv(7 downto 0) := x"7C";
   -- K.28.7
   constant F_CHAR_C : slv(7 downto 0) := x"FC";

   -- Register or counter widths
   constant SYSRF_DLY_WIDTH_C : positive := 8;
   constant RX_STAT_WIDTH_C   : positive := 19 + 2*GT_WORD_SIZE_C;
   constant TX_STAT_WIDTH_C   : positive := 6;

   -- AXI packet size at power up
   constant AXI_PACKET_SIZE_DEFAULT_C : slv(23 downto 0) := x"00_01_00";

   -- TX specific

   -- Ramp step or square wave period slv width (max 16)
   constant PER_STEP_WIDTH_C : positive := 16;

   -- Scrambler/Descrambler PBRS taps for 1 + x^14 + x^15
   constant JESD_PRBS_TAPS_C : NaturalArray := (0 => 14, 1 => 15);

-- Sub-types
--------------------------------------------------------------------------
   type jesdGtRxLaneType is record
      data      : slv((GT_WORD_SIZE_C*8)-1 downto 0);  -- PHY receive data
      dataK     : slv(GT_WORD_SIZE_C-1 downto 0);  -- PHY receive data is K character
      dispErr   : slv(GT_WORD_SIZE_C-1 downto 0);  -- PHY receive data has disparity error
      decErr    : slv(GT_WORD_SIZE_C-1 downto 0);  -- PHY receive data not in table
      rstDone   : sl;
      cdrStable : sl;
   end record jesdGtRxLaneType;

   constant JESD_GT_RX_LANE_INIT_C : jesdGtRxLaneType := (
      data      => (others => '0'),
      dataK     => (others => '0'),
      dispErr   => (others => '0'),
      decErr    => (others => '0'),
      rstDone   => '0',
      cdrStable => '0'
      );

   type jesdGtTxLaneType is record
      data  : slv((GT_WORD_SIZE_C*8)-1 downto 0);  -- PHY receive data
      dataK : slv(GT_WORD_SIZE_C-1 downto 0);  -- PHY receive data is K character
   end record jesdGtTxLaneType;
   constant JESD_GT_TX_LANE_INIT_C : jesdGtTxLaneType := (
      data  => (others => '0'),
      dataK => (others => '0'));

   -- Arrays
   type jesdGtRxLaneTypeArray is array (natural range <>) of jesdGtRxLaneType;
   type jesdGtTxLaneTypeArray is array (natural range <>) of jesdGtTxLaneType;
   type fixLatDataArray is array (natural range <>) of slv((GT_WORD_SIZE_C*8+GT_WORD_SIZE_C*2)-1 downto 0);
   type sampleDataArray is array (natural range <>) of slv((GT_WORD_SIZE_C*8)-1 downto 0);
   type sampleDataVectorArray is array (natural range<>, natural range<>) of slv((GT_WORD_SIZE_C*8)-1 downto 0);
   type rxStatuRegisterArray is array (natural range <>) of slv((RX_STAT_WIDTH_C)-1 downto 0);
   type txStatuRegisterArray is array (natural range <>) of slv((TX_STAT_WIDTH_C)-1 downto 0);
   type alignTxArray is array (natural range <>) of slv((GT_WORD_SIZE_C)-1 downto 0);

-- Functions
--------------------------------------------------------------------------
   -- Detect K character
   function detKcharFunc(data_slv : slv; charisk_slv : slv; bytes_int : positive) return std_logic;

   -- Output variable index from SLV (use in variable length shift register)
   function varIndexOutFunc(shft_slv : slv; index_slv : slv) return std_logic;

   -- Detect position of first non K character (Swapped)
   function detectPosFuncSwap(data_slv : slv; charisk_slv : slv; bytes_int : positive) return std_logic_vector;

   -- Detect position of first non K character
   function detectPosFunc(data_slv : slv; charisk_slv : slv; bytes_int : positive) return std_logic_vector;

   -- Byte swap slv (bytes int 2 or 4)
   function byteSwapSlv(data_slv : slv; bytes_int : positive) return std_logic_vector;

   -- Swap little and big endians (bytes int 2 or 4)
   function endianSwapSlv(data_slv : slv; bytes_int : positive) return std_logic_vector;

   -- Align the data within the data buffer according to the position of the byte alignment word
   function JesdDataAlign(data_slv : slv; position_slv : slv; bytes_int : positive) return std_logic_vector;

   -- Align the character within the buffer according to the position of the byte alignment word
   function JesdCharAlign(char_slv : slv; position_slv : slv; bytes_int : positive) return std_logic_vector;

   -- Convert standard logic vector to integer
   function slvToInt(data_slv : slv) return integer;

   -- Convert integer to standard logic vector
   function intToSlv(data_int : integer; bytes_int : positive) return std_logic_vector;

   -- Output offset binary zero
   function outSampleZero(F_int : positive; bytes_int : positive) return std_logic_vector;

   -- Invert functions

   -- Invert signed
   function invSigned(input : slv) return std_logic_vector;
   function invData(data    : slv; F_int : positive; bytes_int : positive) return std_logic_vector;

   procedure jesdScrambler (
      dataIn  : in    slv(15 downto 0);
      lfsrIn  : in    slv(14 downto 0);
      dataOut : inout slv(15 downto 0);
      lfsrOut : inout slv(14 downto 0));

end Jesd204bPkg;

package body Jesd204bPkg is

-- Functions
--------------------------------------------------------------------------
   -- Detect K character
   function detKcharFunc(data_slv : slv; charisk_slv : slv; bytes_int : positive) return std_logic is
   begin
      if(bytes_int = 2) then
         if(data_slv (7 downto 0) = K_CHAR_C and
            data_slv (15 downto 8) = K_CHAR_C and
            charisk_slv = (charisk_slv'range => '1')
            ) then
            return '1';
         else
            return '0';
         end if;
      elsif(bytes_int = 4) then
         if(data_slv (7 downto 0) = K_CHAR_C and
            data_slv (15 downto 8) = K_CHAR_C and
            data_slv (23 downto 16) = K_CHAR_C and
            data_slv (31 downto 24) = K_CHAR_C and
            charisk_slv = (charisk_slv'range => '1')
            ) then
            return '1';
         else
            return '0';
         end if;
      else
         return '0';
      end if;
   end detKcharFunc;

   -- Output variable index from SLV (use in variable length shift register)
   function varIndexOutFunc(shft_slv : slv; index_slv : slv) return std_logic is
      variable i : integer;
   begin
      -- Return the index
      i := to_integer(unsigned(index_slv));
      return shft_slv(i);

   end varIndexOutFunc;

   -- Detect position of first non K character
   function detectPosFunc(data_slv : slv; charisk_slv : slv; bytes_int : positive) return std_logic_vector is
   begin
      -- GT word is 2 bytes
      if(bytes_int = 2) then
         if(data_slv (7 downto 0) /= K_CHAR_C and
            data_slv (15 downto 8) /= K_CHAR_C
            ) then
            return "01";
         elsif(data_slv (7 downto 0) /= K_CHAR_C and
               data_slv (15 downto 8) = K_CHAR_C and
               charisk_slv(1) = '1'
               ) then
            return "10";
         else
            return "11";
         end if;
      -- GT word is 4 bytes wide
      elsif(bytes_int = 4) then
         if(data_slv (7 downto 0) /= K_CHAR_C and
            data_slv (15 downto 8) /= K_CHAR_C and
            data_slv (23 downto 16) /= K_CHAR_C and
            data_slv (31 downto 24) /= K_CHAR_C
            ) then
            return "0001";
         elsif(data_slv (7 downto 0) /= K_CHAR_C and
               data_slv (15 downto 8) /= K_CHAR_C and
               data_slv (23 downto 16) /= K_CHAR_C and
               data_slv (31 downto 24) = K_CHAR_C and
               charisk_slv(3) = '1'
               ) then
            return "0010";
         elsif(data_slv (7 downto 0) /= K_CHAR_C and
               data_slv (15 downto 8) /= K_CHAR_C and
               data_slv (23 downto 16) = K_CHAR_C and
               data_slv (31 downto 24) = K_CHAR_C and
               charisk_slv(3 downto 2) = "11"
               ) then
            return "0100";
         elsif(data_slv (7 downto 0) /= K_CHAR_C and
               data_slv (15 downto 8) = K_CHAR_C and
               data_slv (23 downto 16) = K_CHAR_C and
               data_slv (31 downto 24) = K_CHAR_C and
               charisk_slv(3 downto 1) = "111"
               ) then
            return "1000";
         else
            return "1111";
         end if;
      else
         return (bytes_int-1 downto 0 => '1');
      end if;
   end detectPosFunc;


   -- Detect position of first non K character (Swapped bits/bytes)
   function detectPosFuncSwap(data_slv : slv; charisk_slv : slv; bytes_int : positive) return std_logic_vector is
   begin
      -- GT word is 2 bytes
      if(bytes_int = 2) then
         if(data_slv (7 downto 0) /= K_CHAR_C and
            data_slv (15 downto 8) /= K_CHAR_C
            ) then
            return "01";
         elsif(data_slv (7 downto 0) = K_CHAR_C and
               data_slv (15 downto 8) /= K_CHAR_C and
               charisk_slv(0) = '1'
               ) then
            return "10";
         else
            return "11";
         end if;
      -- GT word is 4 bytes wide
      elsif(bytes_int = 4) then
         if(data_slv (7 downto 0) /= K_CHAR_C and
            data_slv (15 downto 8) /= K_CHAR_C and
            data_slv (23 downto 16) /= K_CHAR_C and
            data_slv (31 downto 24) /= K_CHAR_C
            ) then
            return "0001";
         elsif(data_slv (7 downto 0) = K_CHAR_C and
               data_slv (15 downto 8) /= K_CHAR_C and
               data_slv (23 downto 16) /= K_CHAR_C and
               data_slv (31 downto 24) /= K_CHAR_C and
               charisk_slv(0) = '1'
               ) then
            return "0010";
         elsif(data_slv (7 downto 0) = K_CHAR_C and
               data_slv (15 downto 8) = K_CHAR_C and
               data_slv (23 downto 16) /= K_CHAR_C and
               data_slv (31 downto 24) /= K_CHAR_C and
               charisk_slv(1 downto 0) = "11"
               ) then
            return "0100";
         elsif(data_slv (7 downto 0) = K_CHAR_C and
               data_slv (15 downto 8) = K_CHAR_C and
               data_slv (23 downto 16) = K_CHAR_C and
               data_slv (31 downto 24) /= K_CHAR_C and
               charisk_slv(2 downto 0) = "111"
               ) then
            return "1000";
         else
            return "1111";
         end if;
      else
         return (bytes_int-1 downto 0 => '1');
      end if;
   end detectPosFuncSwap;

   -- Byte swap slv (bytes int 2 or 4)
   function byteSwapSlv(data_slv : slv; bytes_int : positive) return std_logic_vector is
   begin

      if(bytes_int = 2) then
         return data_slv(7 downto 0) & data_slv(15 downto 8);
      elsif(bytes_int = 4) then
         return data_slv(7 downto 0) & data_slv(15 downto 8) & data_slv(23 downto 16) & data_slv(31 downto 24);
      else
         return data_slv;
      end if;
   end byteSwapSlv;

   -- Swap little or big endian (bytes int 2 or 4)
   function endianSwapSlv(data_slv : slv; bytes_int : positive) return std_logic_vector is
   begin

      if(bytes_int = 2) then
         return data_slv;
      elsif(bytes_int = 4) then
         return data_slv(15 downto 0) & data_slv(31 downto 16);
      else
         return data_slv;
      end if;
   end endianSwapSlv;

   -- Align the data within the data buffer according to the position of the byte alignment word
   function JesdDataAlign(data_slv : slv; position_slv : slv; bytes_int : positive) return std_logic_vector is
   begin
      if(bytes_int = 2) then
         if (position_slv(1 downto 0) = "01") then
            return data_slv (31 downto 16);
         elsif (position_slv(1 downto 0) = "10") then
            return data_slv (31-8 downto 16-8);
         else
            return data_slv (31 downto 16);
         end if;
      elsif(bytes_int = 4) then
         if (position_slv(3 downto 0) = "0001") then
            return data_slv(63 downto 32);
         elsif (position_slv(3 downto 0) = "0010") then
            return data_slv(63-1*8 downto 32-1*8);
         elsif (position_slv(3 downto 0) = "0100") then
            return data_slv(63-2*8 downto 32-2*8);
         elsif (position_slv(3 downto 0) = "1000") then
            return data_slv(63-3*8 downto 32-3*8);
         else
            return data_slv(63 downto 32);
         end if;
      else
         return data_slv;
      end if;
   end JesdDataAlign;

   -- Align the char within the buffer according to the position of the byte alignment word
   function JesdCharAlign(char_slv : slv; position_slv : slv; bytes_int : positive) return std_logic_vector is
   begin
      if(bytes_int = 2) then
         if (position_slv(1 downto 0) = "01") then
            return char_slv (3 downto 2);
         elsif (position_slv(1 downto 0) = "10") then
            return char_slv (3-1 downto 2-1);
         else
            return char_slv (3 downto 2);
         end if;
      elsif(bytes_int = 4) then
         if (position_slv(3 downto 0) = "0001") then
            return char_slv(7 downto 4);
         elsif (position_slv(3 downto 0) = "0010") then
            return char_slv(7-1 downto 4-1);
         elsif (position_slv(3 downto 0) = "0100") then
            return char_slv(7-2 downto 4-2);
         elsif (position_slv(3 downto 0) = "1000") then
            return char_slv(7-3 downto 4-3);
         else
            return char_slv(7 downto 4);
         end if;
      else
         return char_slv;
      end if;
   end JesdCharAlign;

   -- Convert standard logic vector to integer
   function slvToInt(data_slv : slv) return integer is
   begin
      return to_integer(unsigned(data_slv));
   end slvToInt;

   -- Convert integer to standard logic vector
   function intToSlv(data_int : integer; bytes_int : positive) return std_logic_vector is
   begin
      return std_logic_vector(to_unsigned(data_int, bytes_int));
   end IntToSlv;

   -- Output zero sample data depending on word size and Frame size
   function outSampleZero(F_int : positive; bytes_int : positive) return std_logic_vector is
      constant SAMPLES_IN_WORD_C : positive := (bytes_int/F_int);
      variable vSlv              : slv((bytes_int*8)-1 downto 0);
   begin

      vSlv := (others => '0');

      for i in (SAMPLES_IN_WORD_C-1) downto 0 loop
         vSlv(i*8*F_int+8*F_int-1) := '1';
      end loop;

      return vSlv;

   end outSampleZero;

   -- Invert Signed
   function invSigned(input : slv) return std_logic_vector is
      variable vOutput : signed(input'range);
   begin
      vOutput := - signed(input);
      return std_logic_vector(vOutput);
   end invSigned;

   -- Output zero sample data depending on word size and Frame size
   function invData(data : slv; F_int : positive; bytes_int : positive) return std_logic_vector is
      constant SAMPLES_IN_WORD_C : positive := (bytes_int/F_int);
      variable vSlv              : slv((bytes_int*8)-1 downto 0);
   begin

      vSlv := data;

      for i in (SAMPLES_IN_WORD_C-1) downto 0 loop
         vSlv(i*8*F_int+8*F_int-1 downto i*8*F_int) := invSigned(vSlv(i*8*F_int+8*F_int-1 downto i*8*F_int));
      end loop;

      return vSlv;

   end invData;

   -- lfsr(14:0)=1+x^14+x^15
   procedure jesdScrambler (
      dataIn  : in    slv(15 downto 0);
      lfsrIn  : in    slv(14 downto 0);
      dataOut : inout slv(15 downto 0);
      lfsrOut : inout slv(14 downto 0)) is
   begin
      lfsrOut(0)  := lfsrIn(0) xor lfsrIn(1) xor lfsrIn(2) xor lfsrIn(3) xor lfsrIn(4) xor lfsrIn(5) xor lfsrIn(6) xor lfsrIn(7) xor lfsrIn(8) xor lfsrIn(9) xor lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13);
      lfsrOut(1)  := lfsrIn(0) xor lfsrIn(1) xor lfsrIn(2) xor lfsrIn(3) xor lfsrIn(4) xor lfsrIn(5) xor lfsrIn(6) xor lfsrIn(7) xor lfsrIn(8) xor lfsrIn(9) xor lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      lfsrOut(2)  := lfsrIn(1) xor lfsrIn(2) xor lfsrIn(3) xor lfsrIn(4) xor lfsrIn(5) xor lfsrIn(6) xor lfsrIn(7) xor lfsrIn(8) xor lfsrIn(9) xor lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      lfsrOut(3)  := lfsrIn(2) xor lfsrIn(3) xor lfsrIn(4) xor lfsrIn(5) xor lfsrIn(6) xor lfsrIn(7) xor lfsrIn(8) xor lfsrIn(9) xor lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      lfsrOut(4)  := lfsrIn(3) xor lfsrIn(4) xor lfsrIn(5) xor lfsrIn(6) xor lfsrIn(7) xor lfsrIn(8) xor lfsrIn(9) xor lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      lfsrOut(5)  := lfsrIn(4) xor lfsrIn(5) xor lfsrIn(6) xor lfsrIn(7) xor lfsrIn(8) xor lfsrIn(9) xor lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      lfsrOut(6)  := lfsrIn(5) xor lfsrIn(6) xor lfsrIn(7) xor lfsrIn(8) xor lfsrIn(9) xor lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      lfsrOut(7)  := lfsrIn(6) xor lfsrIn(7) xor lfsrIn(8) xor lfsrIn(9) xor lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      lfsrOut(8)  := lfsrIn(7) xor lfsrIn(8) xor lfsrIn(9) xor lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      lfsrOut(9)  := lfsrIn(8) xor lfsrIn(9) xor lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      lfsrOut(10) := lfsrIn(9) xor lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      lfsrOut(11) := lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      lfsrOut(12) := lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      lfsrOut(13) := lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      lfsrOut(14) := lfsrIn(0) xor lfsrIn(1) xor lfsrIn(2) xor lfsrIn(3) xor lfsrIn(4) xor lfsrIn(5) xor lfsrIn(6) xor lfsrIn(7) xor lfsrIn(8) xor lfsrIn(9) xor lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(14);

      dataOut(0)  := dataIn(0) xor lfsrIn(14);
      dataOut(1)  := dataIn(1) xor lfsrIn(13) xor lfsrIn(14);
      dataOut(2)  := dataIn(2) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      dataOut(3)  := dataIn(3) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      dataOut(4)  := dataIn(4) xor lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      dataOut(5)  := dataIn(5) xor lfsrIn(9) xor lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      dataOut(6)  := dataIn(6) xor lfsrIn(8) xor lfsrIn(9) xor lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      dataOut(7)  := dataIn(7) xor lfsrIn(7) xor lfsrIn(8) xor lfsrIn(9) xor lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      dataOut(8)  := dataIn(8) xor lfsrIn(6) xor lfsrIn(7) xor lfsrIn(8) xor lfsrIn(9) xor lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      dataOut(9)  := dataIn(9) xor lfsrIn(5) xor lfsrIn(6) xor lfsrIn(7) xor lfsrIn(8) xor lfsrIn(9) xor lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      dataOut(10) := dataIn(10) xor lfsrIn(4) xor lfsrIn(5) xor lfsrIn(6) xor lfsrIn(7) xor lfsrIn(8) xor lfsrIn(9) xor lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      dataOut(11) := dataIn(11) xor lfsrIn(3) xor lfsrIn(4) xor lfsrIn(5) xor lfsrIn(6) xor lfsrIn(7) xor lfsrIn(8) xor lfsrIn(9) xor lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      dataOut(12) := dataIn(12) xor lfsrIn(2) xor lfsrIn(3) xor lfsrIn(4) xor lfsrIn(5) xor lfsrIn(6) xor lfsrIn(7) xor lfsrIn(8) xor lfsrIn(9) xor lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      dataOut(13) := dataIn(13) xor lfsrIn(1) xor lfsrIn(2) xor lfsrIn(3) xor lfsrIn(4) xor lfsrIn(5) xor lfsrIn(6) xor lfsrIn(7) xor lfsrIn(8) xor lfsrIn(9) xor lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      dataOut(14) := dataIn(14) xor lfsrIn(0) xor lfsrIn(1) xor lfsrIn(2) xor lfsrIn(3) xor lfsrIn(4) xor lfsrIn(5) xor lfsrIn(6) xor lfsrIn(7) xor lfsrIn(8) xor lfsrIn(9) xor lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13) xor lfsrIn(14);
      dataOut(15) := dataIn(15) xor lfsrIn(0) xor lfsrIn(1) xor lfsrIn(2) xor lfsrIn(3) xor lfsrIn(4) xor lfsrIn(5) xor lfsrIn(6) xor lfsrIn(7) xor lfsrIn(8) xor lfsrIn(9) xor lfsrIn(10) xor lfsrIn(11) xor lfsrIn(12) xor lfsrIn(13);

   end procedure;

end package body Jesd204bPkg;
