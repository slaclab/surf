-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.CrcPkg.all;

entity Crc32 is
   generic (
      TPD_G            : time             := 1 ns;
      RST_POLARITY_G   : sl               := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      RST_ASYNC_G      : boolean          := false;
      BYTE_WIDTH_G     : positive         := 4;
      INPUT_REGISTER_G : boolean          := true;
      CRC_INIT_G       : slv(31 downto 0) := x"FFFFFFFF";
      CRC_POLY_G       : slv(31 downto 0) := x"04C11DB7");
   port (
      crcPwrOnRst  : in  sl               := not RST_POLARITY_G;
      crcOut       : out slv(31 downto 0);         -- CRC output
      crcRem       : out slv(31 downto 0);         -- CRC interim remainder
      crcClk       : in  sl;            -- system clock
      crcDataValid : in  sl;  -- indicate that new data arrived and CRC can be computed
      crcDataWidth : in  slv(2 downto 0);  -- indicate width in bytes minus 1, 0 - 1 byte, 1 - 2 bytes ... , 7 - 8 bytes
      crcIn        : in  slv((BYTE_WIDTH_G*8-1) downto 0);  -- input data for CRC calculation
      crcInit      : in  slv(31 downto 0) := CRC_INIT_G;  -- optional override of CRC_INIT_G
      crcReset     : in  sl);           -- initializes CRC logic to crcInit
end Crc32;

architecture rtl of Crc32 is

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

   comb : process(crcDataValid, crcDataWidth, crcIn, crcInit, crcReset, r)
      variable v         : RegType;
      variable byteXor   : slv(7 downto 0);
      variable byteWidth : slv(2 downto 0);
      variable valid     : sl;
      variable data      : slv((BYTE_WIDTH_G*8-1) downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Reset the bit mask
      byteXor := (others => '0');

      -- Register inputs
      v.byteWidth := crcDataWidth;
      v.valid     := crcDataValid;

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

      -- Select where to register the inputs
      if (INPUT_REGISTER_G) then
         byteWidth := r.byteWidth;
         valid     := r.valid;
         data      := r.data;
      else
         byteWidth := v.byteWidth;
         valid     := v.valid;
         data      := v.data;
      end if;

      -- Reset handling
      if (crcReset = '0') then
         -- Use remainder from previous cycle
         v.crc := r.crc;
      else
         -- Pre-load the remainder
         v.crc := crcInit;
      end if;

      -- Calculate CRC byte-by-byte
      if (valid = '1') then
         for byte in BYTE_WIDTH_G-1 downto 0 loop
            if (byteWidth >= BYTE_WIDTH_G-byte-1) then
               byteXor := v.crc(31 downto 24) xor data((byte+1)*8-1 downto byte*8);
               v.crc   := (v.crc(23 downto 0) & x"00") xor crcByteLookup(byteXor, CRC_POLY_G);
            end if;
         end loop;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      crcRem <= r.crc;
      -- Transpose each byte in the data out and invert
      -- This inversion is equivalent to an XOR of the CRC register with xFFFFFFFF
      for byte in 0 to 3 loop
         for b in 0 to 7 loop
            crcOut(byte*8+b) <= not(r.crc((byte+1)*8-1-b));
         end loop;
      end loop;

   end process;

   seq : process (crcClk, crcPwrOnRst) is
   begin
      if (RST_ASYNC_G and crcPwrOnRst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif (rising_edge(crcClk)) then
         if (RST_ASYNC_G = false and crcPwrOnRst = RST_POLARITY_G) then
            r <= REG_INIT_C after TPD_G;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process seq;

end rtl;
