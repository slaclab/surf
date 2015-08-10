-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, CRC32 implementation for Xilinx 7 FPGA
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : CRC32Rtl.vhd
-- Author        : Leonid Sapozhnikov, leosap@slac.stanford.edu
-- Created       : 08/18/2009
-------------------------------------------------------------------------------
-- Description:
-- VHDL source file for CRC32 calculation to replace macro of Virtex5 in Virtex6 and Spartan6.
-- assuming clock positive edge, reset positive edge, LSB first, data width is 32,
-- polynomial CRC32 IEEE802.3 type X32+X26+X23+x22+x16+X12+X11+X10+X8+X7+X5+X4+X2+X1+1
-- with CRCRESETial value of 0xffffffff
-- similar equation can be derived from
-- http://www.xilinx.com/support/documentation/application_notes/xapp209.pdf
-- and related app notes
-- http://www.xilinx.com/support/documentation/application_notes/xapp562.pdf
-------------------------------------------------------------------------------
-- Copyright (c) 2012 by Leonid Sapozhnikov. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 02/08/2012: created.
-- 04/21/2014: Kurtis Nishimura - modified to register the data valid signal.
--             Using the raw version would have caused errors for dynamically
--             changing data widths.
-- 08/10/2015: Added clock enable support
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity CRC32Rtl is
   generic (
      CRC_INIT : bit_vector := x"FFFFFFFF");
   port (
      CRCOUT       : out std_logic_vector(31 downto 0);  -- CRC output
      CRCCLK       : in  std_logic;     -- system clock
      CRCCLKEN     : in  std_logic := '1';-- system clock enable
      CRCDATAVALID : in  std_logic;  -- indicate that new data arrived and CRC can be computed
      CRCDATAWIDTH : in  std_logic_vector(2 downto 0);  -- indicate width in bytes minus 1, 0 - 1 byte, 1 - 2 bytes
      CRCIN        : in  std_logic_vector(31 downto 0);  -- input data for CRC calculation
      CRCRESET     : in  std_logic);  -- to set CRC logic to value in crc_cNIT
end CRC32Rtl;

architecture rtl of CRC32Rtl is

   -- Local Signals
   signal   data             : std_logic_vector(31 downto 0); 
   signal   crc              : std_logic_vector(31 downto 0); 
   signal   CRCDATAVALID_d   : std_logic;
   signal   CRCDATAWIDTH_d   : std_logic_vector(2 downto 0);
   constant Polyval          : std_logic_vector(31 downto 0) := X"04C11DB7";
   type     fb_array is array (32 downto 0) of std_logic_vector(31 downto 0); 
   signal   MSBVect, TempXOR : fb_array;

   -- Register delay for simulation
   constant tpd : time := 0.5 ns;

begin
   TempXOR(0) <= crc xor data;

   MS0 : for i in 0 to 31 generate
      MS1 : for j in 0 to 31 generate
         MSBVect(i)(j) <= TempXOR(i)(31);
      end generate MS1;
   end generate MS0;

   MS2 : for i in 0 to 31 generate
      TempXOR(i+1) <= ((TempXOR(i)(30 downto 0) & '0') xor (Polyval and MSBVect(i)));
   end generate MS2;

   process(CRCCLK,CRCCLKEN)
   begin
      if rising_edge(CRCCLK) and (CRCCLKEN = '1') then
         for i in 24 to 31 loop
            data(31 - (i - 24)) <= (CRCIN(i));
         end loop;
         if (CRCDATAWIDTH = "001" or CRCDATAWIDTH = "010" or CRCDATAWIDTH = "011") then
            for i in 16 to 23 loop
               data(23 - (i - 16)) <= (CRCIN(i));
            end loop;
         end if;
         if (CRCDATAWIDTH = "010" or CRCDATAWIDTH = "011") then
            for i in 8 to 15 loop
               data(15 - (i - 8)) <= (CRCIN(i));
            end loop;
         end if;
         if (CRCDATAWIDTH = "011") then
            for i in 0 to 7 loop
               data(7 - (i)) <= (CRCIN(i));
            end loop;
         end if;

         if (CRCDATAWIDTH = "000") then
            data(23 downto 0) <= (others => '0');
         elsif (CRCDATAWIDTH = "001") then
            data(15 downto 0) <= (others => '0');
         elsif (CRCDATAWIDTH = "010") then
            data(7 downto 0) <= (others => '0');
         end if;
         CRCDATAVALID_d <= CRCDATAVALID;
         CRCDATAWIDTH_d <= CRCDATAWIDTH;
      end if;
   end process;

   CRCP : process (CRCCLK)
   begin
      if rising_edge(CRCCLK) then
         if (CRCRESET = '1') then
            crc <= To_StdLogicVector(CRC_INIT);
         elsif (CRCDATAVALID_d = '1') and (CRCCLKEN = '1') then
            if (CRCDATAWIDTH_d = "000") then
               crc <= TempXOR(8);
            elsif (CRCDATAWIDTH_d = "001") then
               crc <= TempXOR(16);
            elsif (CRCDATAWIDTH_d = "010") then
               crc <= TempXOR(24);
            elsif (CRCDATAWIDTH_d = "011") then
               crc <= TempXOR(32);
            end if;
         end if;
      end if;
   end process;

   -- Trasposing CRC bytes
   CRCOUT <= not(crc(24) & crc(25) & crc(26) & crc(27) & crc(28) & crc(29) & crc(30) & crc(31)
                 & crc(16) & crc(17) & crc(18) & crc(19) & crc(20) & crc(21) & crc(22) & crc(23)
                 & crc(8) & crc(9) & crc(10) & crc(11) & crc(12) & crc(13) & crc(14) & crc(15)
                 & crc(0) & crc(1) & crc(2) & crc(3) & crc(4) & crc(5) & crc(6) & crc(7));
end rtl;

