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
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 04/21/2014: created.
-- 04/30/2014: modified to go back to original Crc32Rtl names, so this module
--             can be used as a drop-in replacement.  Updated to match group 
--             coding conventions.
-- 08/26/2014: Modified to accommodate a reset and valid simultaneously.  This
--             should match the behavior of the original CRC32Rtl.vhd.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.CrcPkg.all;

entity Crc32 is
   generic (
      BYTE_WIDTH_G  : integer := 4;
      CRC_INIT_G    : slv(31 downto 0) := x"FFFFFFFF";
      CRC_POLY_G    : slv(31 downto 0) := x"04C11DB7";
      TPD_G         : time := 0.5 ns);
   port (
      crcOut        :  out slv(31 downto 0);                  -- CRC output
      crcClk        : in   sl;                                -- system clock
      crcDataValid  : in   sl;                                -- indicate that new data arrived and CRC can be computed
      crcDataWidth  : in   slv(2 downto 0);                   -- indicate width in bytes minus 1, 0 - 1 byte, 1 - 2 bytes ... , 7 - 8 bytes
      crcIn         : in   slv((BYTE_WIDTH_G*8-1) downto 0);  -- input data for CRC calculation
      crcReset      : in   sl);                               -- initializes CRC logic to CRC_INIT_G
end Crc32;

architecture rtl of Crc32 is

   type RegType is record
      crc            : slv(31 downto 0);
      data           : slv((BYTE_WIDTH_G*8-1) downto 0);
      valid          : sl;
      byteWidth      : slv(2 downto 0);
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      crc           => CRC_INIT_G,
      data          => (others => '0'),
      valid         => '0',
      byteWidth     => (others => '0')
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process(crcIn,crcDataWidth,crcReset,crcDataValid,r)
      variable v       : RegType;
      variable byteXor : slv(7 downto 0);
   begin
      v := r;

      v.byteWidth := crcDataWidth;
      v.valid     := crcDataValid;
      byteXor     := (others => '0');
      
      -- Transpose the input data
      for byte in (BYTE_WIDTH_G-1) downto 0 loop
         for b in 0 to 7 loop
            if (crcDataWidth >= BYTE_WIDTH_G-byte-1) then
               v.data((byte+1)*8-1-b) := crcIn(byte*8+b);
            else 
               v.data((byte+1)*8-1-b) := '0';
            end if;            
         end loop;
      end loop;

      -- Reset handling
      if (crcReset = '0') then
         v.crc := r.crc;
      else
         v.crc := CRC_INIT_G;
      end if;
      
      -- Calculate CRC byte-by-byte 
      if (r.valid = '1') then
         for byte in BYTE_WIDTH_G-1 downto 0 loop
            if (r.byteWidth >= BYTE_WIDTH_G-byte-1) then
               byteXor := v.crc(31 downto 24) xor r.data( (byte+1)*8-1 downto byte*8); 
               v.crc   := (v.crc(23 downto 0) & x"00") xor crcByteLookup(byteXor,CRC_POLY_G);
            end if;
         end loop;
      end if;
      
      rin <= v;

      -- Transpose each byte in the data out and invert
      -- This inversion is equivalent to an XOR of the CRC register with xFFFFFFFF 
      for byte in 0 to 3 loop
         for b in 0 to 7 loop
            crcOut(byte*8+b) <= not(r.crc((byte+1)*8-1-b)); 
         end loop;
      end loop;
     
   end process;

   seq : process (crcClk) is
   begin
      if (rising_edge(crcClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;   