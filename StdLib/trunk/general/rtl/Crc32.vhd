-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, Crc32 Implementation
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Crc32.vhd
-- Author        : Kurtis Nishimura, kurtisn@slac.stanford.edu
-- Created       : 04/21/2014
-------------------------------------------------------------------------------
-- Description:
-- This is an implementation of a generic N-byte input CRC32 calculation.
-- The polynomial and CRC register initialization are generic configurable, but 
-- default to the commonly used 0x04C11DB7 and 0xFFFFFFFF, respectively.
-- This implementation is direct, so no bytes need to be appended to the data.
-- Bytes are reversed on input before being used for the CRC calculation, 
-- and the CRC register is reversed on output just before a final XOR with 
-- 0xFFFFFFFF. 
--
-- With a data input size of 4 bytes, this module is compatible with the
-- previous CRC32Rtl.vhdl module in the StdLib.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 04/21/2014: created.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.StdRtlPkg.all;
use work.CrcPkg.all;

entity Crc32 is
   generic (
      BYTE_WIDTH_G  : integer := 8;
      CRC_INIT_G    : std_logic_vector(31 downto 0) := x"FFFFFFFF";
      CRC_POLY_G    : std_logic_vector(31 downto 0) := x"04C11DB7");
   port (
      crcOut        :  out std_logic_vector(31 downto 0);                  -- CRC output
      clk           : in   std_logic;                                      -- system clock
      dataValid     : in   std_logic;                                      -- indicate that new data arrived and CRC can be computed
      dataByteWidth : in   std_logic_vector(2 downto 0);                   -- indicate width in bytes minus 1, 0 - 1 byte, 1 - 2 bytes ... , 7 - 8 bytes
      dataIn        : in   std_logic_vector((BYTE_WIDTH_G*8-1) downto 0);  -- input data for CRC calculation
      crcReset      : in   std_logic);                                     -- initializes CRC logic to CRC_INIT_G
end Crc32;

architecture rtl of Crc32 is

   -- Local Signals
   signal   data               : std_logic_vector((BYTE_WIDTH_G*8-1) downto 0); 
   signal   crcReg             : std_logic_vector(31 downto 0);
   signal   nextCrc            : std_logic_vector(31 downto 0); 
   signal   iDataByteWidth     : integer range 0 to 7;
   signal   iDataByteWidth_reg : integer range 0 to 7; 
   signal   dataValid_reg      : std_logic;

   -- Register delay for simulation
   constant tpd : time := 0.5 ns;

begin

   -- Convert byte width to integer, register this so it aligns with data
   iDataByteWidth <= to_integer(unsigned(DataByteWidth));
   process(clk) begin
      if rising_edge(clk) then
         iDataByteWidth_reg <= iDataByteWidth;
      end if;
   end process; 

   -- Clock the data in.  Transpose the bit order of each byte.
   -- For bits that are not enabled, clock in zeroes.
   process(Clk) begin
      if(rising_edge(Clk)) then
         for byte in (BYTE_WIDTH_G-1) downto 0 loop
            for b in 0 to 7 loop
               if (iDataByteWidth >= BYTE_WIDTH_G-byte-1) then
                  data((byte+1)*8-1-b) <= dataIn(byte*8+b);
               else 
                  data((byte+1)*8-1-b) <= '0';
               end if;            
            end loop;
         end loop;
         dataValid_reg <= dataValid;
      end if;
   end process;

   -- Combinatorial process to calculate next CRC value based on current one
   process(data,iDataByteWidth_reg,crcReg) 
      variable crcVar  : std_logic_vector(31 downto 0);
      variable byteXor : std_logic_vector(7 downto 0);
   begin
      crcVar := crcReg;

      for byte in BYTE_WIDTH_G-1 downto 0 loop  
         if (iDataByteWidth_reg >= BYTE_WIDTH_G-byte-1) then
            byteXor := crcVar(31 downto 24) xor data( (byte+1)*8-1 downto byte*8); 
            crcVar  := (crcVar(23 downto 0) & x"00") xor  crcByteLookup(byteXor,CRC_POLY_G);
         end if;
      end loop;
      
      nextCrc <= crcVar;         
   end process;

   -- Register the next CRC value from the combinatorial process above
   CRC_REG : process (Clk)
   begin
      if rising_edge(Clk) then
         if (crcReset = '1') then
            crcReg <= CRC_INIT_G;
         elsif (dataValid_reg = '1') then
            crcReg <= nextCrc;
         end if;
      end if;
   end process;

   -- Transpose each byte in the data out and invert
   -- This inversion is equivalent to an XOR of the CRC register with xFFFFFFFF 
   GEN_BYTEOUT : for byte in 0 to 3 generate
      GEN_BITOUT : for b in 0 to 7 generate
         crcOut(byte*8+b) <= not(crcReg((byte+1)*8-1-b)); 
      end generate;
   end generate;
   
end rtl;

