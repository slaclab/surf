-------------------------------------------------------------------------------
-- File       : Crc32.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-05-01
-- Last update: 2017-10-31
-------------------------------------------------------------------------------
-- Description:
-- This is an implementation of an 1-to-8-byte input CRC32 calculation.
-- The polynomial is fixed to 0x04C11DB7, the "standard CRC32 polynomial."
-- The initialization value is configurable, but defaults to 0xFFFFFFFF.
--
-- This implementation is direct, so no bytes need to be appended to the data.
--
-- Bytes are reversed on input before being used for the CRC calculation, 
-- and the CRC register is reversed on output just before a final XOR with 
-- 0xFFFFFFFF.
--
-- This version utilizes parallel CRC calculations, and as a result generally
-- should meet much tighter timing constraints and run at higher frequencies.
-- (relative to Crc32.vhd and CRC32Rtl.vhd).
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.CrcPkg.all;

entity Crc32Parallel is
   generic (
      TPD_G            : time             := 0.5 ns;
      BYTE_WIDTH_G     : integer          := 4;
      INPUT_REGISTER_G : boolean          := true;
      CRC_INIT_G       : slv(31 downto 0) := x"FFFFFFFF");
   port (
      crcOut       : out slv(31 downto 0);                  -- CRC output
      crcClk       : in  sl;            -- system clock
      crcDataValid : in  sl;  -- indicate that new data arrived and CRC can be computed
      crcDataWidth : in  slv(2 downto 0);  -- indicate width in bytes minus 1, 0 - 1 byte, 1 - 2 bytes ... , 7 - 8 bytes
      crcIn        : in  slv((BYTE_WIDTH_G*8-1) downto 0);  -- input data for CRC calculation
      crcReset     : in  sl);  -- initializes CRC logic to CRC_INIT_G     
end Crc32Parallel;

architecture rtl of Crc32Parallel is

   type RegType is record
      crc       : slv(31 downto 0);
      data      : slv((BYTE_WIDTH_G*8-1) downto 0);
      valid     : sl;
      byteWidth : slv(2 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      crc       => CRC_INIT_G,
      data      => (others => '0'),
      valid     => '0',
      byteWidth => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   assert (BYTE_WIDTH_G > 0 and BYTE_WIDTH_G <= 8) report "BYTE_WIDTH_G must be in the range [1,8]" severity failure;

   comb : process(crcDataValid, crcDataWidth, crcIn, crcReset, r)
      variable v         : RegType;
      variable prevCrc   : slv(31 downto 0);
      variable byteWidth : slv(2 downto 0);
      variable valid     : sl;
      variable data      : slv((BYTE_WIDTH_G*8-1) downto 0);
   begin
      v := r;

      v.byteWidth := crcDataWidth;
      v.valid     := crcDataValid;

      -- Transpose the input data
      for byte in (BYTE_WIDTH_G-1) downto 0 loop
         if (crcDataWidth >= BYTE_WIDTH_G-byte-1) then
            for b in 0 to 7 loop
               v.data((byte+1)*8-1-b) := crcIn(byte*8+b);
            end loop;
         else
            v.data((byte+1)*8-1 downto byte*8) := (others => '0');
         end if;
      end loop;

      if (INPUT_REGISTER_G) then
         byteWidth := r.byteWidth;
         valid     := r.valid;
         data      := r.data;
      else
         byteWidth := v.byteWidth;
         valid     := v.valid;
         data      := v.data;
      end if;

      if (crcReset = '0') then
         prevCrc := r.crc;
      else
         prevCrc := CRC_INIT_G;
      end if;

      -- Calculate CRC in parallel - implementation used depends on the 
      -- byte width in use.      
      if (valid = '1') then
         case(byteWidth) is
            when "000" =>
               v.crc := crc32Parallel1Byte(prevCrc, data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-1)*8));
            when "001" =>
               if (BYTE_WIDTH_G >= 2) then
                  v.crc := crc32Parallel2Byte(prevCrc, data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-2)*8));
               end if;
            when "010" =>
               if (BYTE_WIDTH_G >= 3) then
                  v.crc := crc32Parallel3Byte(prevCrc, data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-3)*8));
               end if;
            when "011" =>
               if (BYTE_WIDTH_G >= 4) then
                  v.crc := crc32Parallel4Byte(prevCrc, data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-4)*8));
               end if;
            when "100" =>
               if (BYTE_WIDTH_G >= 5) then
                  v.crc := crc32Parallel5Byte(prevCrc, data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-5)*8));
               end if;
            when "101" =>
               if (BYTE_WIDTH_G >= 6) then
                  v.crc := crc32Parallel6Byte(prevCrc, data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-6)*8));
               end if;
            when "110" =>
               if (BYTE_WIDTH_G >= 7) then
                  v.crc := crc32Parallel7Byte(prevCrc, data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-7)*8));
               end if;
            when "111" =>
               if (BYTE_WIDTH_G = 8) then
                  v.crc := crc32Parallel8Byte(prevCrc, data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-8)*8));
               end if;
            when others => v.crc := (others => '0');
         end case;
      else
         v.crc := prevCrc;
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
