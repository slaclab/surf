-------------------------------------------------------------------------------
-- File       : SaciMultiPixelPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 07/21/2016
-- Last update: 07/21/2016
-------------------------------------------------------------------------------
-- Description: SaciMultiPixel Package File
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;

package SaciMultiPixelPkg is

   constant FPGA_VERSION_C : slv(31 downto 0) := x"00000000";

   type MultiPixelWriteType is record
      asic       : slv(1 downto 0);
      row        : slv(9 downto 0);
      col        : slv(9 downto 0);
      data       : Slv16Array(3 downto 0);
      bankFlag   : slv(3 downto 0);
      calRowFlag : sl;
      calBotFlag : sl;
      req        : sl;
   end record;
   constant MULTI_PIXEL_WRITE_INIT_C : MultiPixelWriteType := (
      asic       => (others => '0'),
      row        => (others => '0'),
      col        => (others => '0'),
      data       => (others => (others => '0')),
      bankFlag   => (others => '0'),
      calRowFlag => '0',
      calBotFlag => '0',
      req        => '0'
   );

   function asicBaseAddr ( asic : natural ) return slv;

   --Functions to allow use of EPIX100 or 10k
   function getNumColumns ( version : slv ) return integer;
   function getWordsPerSuperRow ( version : slv ) return integer;

   constant NCOL_C : integer := getNumColumns(FPGA_VERSION_C);
   --Number of columns in ePix "super row"
   -- (columns / ch) * (channels / asic) * (asics / row) / (adc values / word)
   -- constant WORDS_PER_SUPER_ROW_C : integer := NCOL_C * 4 * 2 / 2; 
   constant WORDS_PER_SUPER_ROW_C  : integer := getWordsPerSuperRow(FPGA_VERSION_C);
   constant EPIX100_COLS_PER_ROW   : integer := 96;
   constant EPIX10K_COLS_PER_ROW   : integer := 48;
   constant EPIXS_COLS_PER_ROW     : integer := 10;
   constant EPIX100A_ROWS_PER_ASIC : integer := 352;
   
   procedure globalToLocalPixel( signal   globalRow  : in slv; 
                                 signal   globalCol  : in slv; 
                                 signal   calRowFlag : in sl; 
                                 signal   calBotFlag : in sl;
                                 signal   inputData  : in Slv16Array;
                                 variable localAsic  : inout slv; 
                                 variable localRow   : inout slv; 
                                 variable localCol   : inout slv;
                                 variable localData  : inout Slv16Array);
   procedure globalToLocalPixelEpix100A( signal   globalRow  : in slv; 
                                         signal   globalCol  : in slv; 
                                         signal   calRowFlag : in sl; 
                                         signal   calBotFlag : in sl;
                                         signal   inputData  : in Slv16Array;
                                         variable localAsic  : inout slv; 
                                         variable localRow   : inout slv; 
                                         variable localCol   : inout slv;
                                         variable localData  : inout Slv16Array) ;
   
end SaciMultiPixelPkg;

package body SaciMultiPixelPkg is

   function asicBaseAddr(asic : natural) return slv is
   begin
      return toSlv(asic*(2**22), 32);
   end function;

   function getNumColumns (version : slv ) return integer is
   begin
      assert (version(31 downto 24) = x"E0" or 
              version(31 downto 24) = x"EA" or
              version(31 downto 24) = x"E2" or
              version(31 downto 24) = x"E3") report "Unable to determine ASIC type from version string!" severity failure;
      --Epix 100p and Epix100a
      if (version(31 downto 24) = x"E0" or version(31 downto 24) = x"EA") then
         return EPIX100_COLS_PER_ROW;
      --Epix 10k
      elsif (version(31 downto 24) = x"E2") then
         return EPIX10K_COLS_PER_ROW;
      --Epix S
      elsif (version(31 downto 24) = x"E3") then
         return EPIXS_COLS_PER_ROW;
      --Other (default to Epix 100)
      else
         return EPIX100_COLS_PER_ROW;
      end if; 
   end function;

   function getWordsPerSuperRow (version : slv ) return integer is
   begin
      --EpixS reads only the active ASICs
      if (version(31 downto 24) = x"E3") then
         return EPIXS_COLS_PER_ROW * 2 / 2;
      --Other
      else
         return NCOL_C * 4 * 2 / 2;
      end if; 
   end function;

   procedure globalToLocalPixel (
       signal   globalRow  : in slv;
       signal   globalCol  : in slv;
       signal   calRowFlag : in sl;
       signal   calBotFlag : in sl;
       signal   inputData  : in Slv16Array;
       variable localAsic  : inout slv;
       variable localRow   : inout slv;
       variable localCol   : inout slv;
       variable localData  : inout Slv16Array)
   is
   begin 
      assert (FPGA_VERSION_C(31 downto 24) = x"EA") report "Multi-pixel writes not supported for this ASIC!" severity warning;   
      if FPGA_VERSION_C(31 downto 24) = x"EA" then
         globalToLocalPixelEpix100A(globalRow,globalCol,calRowFlag,calBotFlag,inputData,localAsic,localRow,localCol,localData);
      end if;
   end procedure globalToLocalPixel;
   
   procedure globalToLocalPixelEpix100A (
       signal   globalRow  : in slv;
       signal   globalCol  : in slv;
       signal   calRowFlag : in sl;
       signal   calBotFlag : in sl;
       signal   inputData  : in Slv16Array;
       variable localAsic  : inout slv;
       variable localRow   : inout slv;
       variable localCol   : inout slv;
       variable localData  : inout Slv16Array)
   is
      variable asicCol  : slv(9 downto 0);
   begin 
      -- Top 2 ASICs
      if (globalRow < EPIX100A_ROWS_PER_ASIC and calRowFlag = '0') or (calRowFlag = '1' and calBotFlag = '0') then
         -- ASIC 2 (upper left)
         if globalCol < NCOL_C * 4 then
            localAsic := "10";
            asicCol   := NCOL_C * 4 - globalCol - 1;
         -- ASIC 1 (upper right)
         else
            localAsic := "01";
            asicCol   := NCOL_C * 4 * 2 - 1 - globalCol;
         end if;
         -- For both top ASICs, translate row to local space
         if calRowFlag = '1' then
            localRow := conv_std_logic_vector(EPIX100A_ROWS_PER_ASIC,localRow'length);
         else
            localRow := EPIX100A_ROWS_PER_ASIC - 1 - globalRow;
         end if;
         -- Readout order for top ASICs is 3->0
         for i in 0 to 3 loop
            localData(3-i) := inputData(i);
         end loop;
      -- Bottom two ASICs
      else
         -- ASIC 3 (lower left)
         if (globalCol < NCOL_C * 4) then
            localAsic := "11";
            asicCol   := globalCol;
         -- ASIC 0 (lower right)
         else
            localAsic := "00";
            asicCol   := globalCol - NCOL_C * 4;
         end if;
         -- For both bottom ASICs, translate row to local space
         if calRowFlag = '1' then
            localRow := conv_std_logic_vector(EPIX100A_ROWS_PER_ASIC,localRow'length);
         else
            localRow := globalRow - EPIX100A_ROWS_PER_ASIC;
         end if;
         -- Readout order for bottom ASICs is 0->3
         for i in 0 to 3 loop
            localData(i) := inputData(i);
         end loop;
      end if;
      -- Decode column to column within a bank   
      if asicCol  < NCOL_C then
         localCol := asicCol;
      elsif asicCol < NCOL_C * 2 then
         localCol := asicCol - NCOL_C;
      elsif asicCol < NCOL_C * 3 then
         localCol := asicCol - NCOL_C * 2;
      else
         localCol := asicCol - NCOL_C * 3;
      end if;
   end procedure globalToLocalPixelEpix100A;  
   
end package body SaciMultiPixelPkg;
