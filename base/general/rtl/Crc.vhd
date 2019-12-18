-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- This is an implementation of a generic N-byte input CRC32 calculation.
-- The polynomial and CRC register initialization are generic configurable, but 
-- default to the commonly used 0x04C11DB7 and 0xFFFFFFFF, respectively.
-- This implementation is direct, so no bytes need to be appended to the data.
-- 
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

entity Crc is
   generic (
      TPD_G            : time    := 0.5 ns;
      INPUT_REGISTER_G : boolean := false;
      CRC_INIT_G       : slv     := x"FFFF";
      CRC_POLY_G       : slv     := X"011B"; ----x"04C11DB7";  -- In "Normal" form with highest term implicitly 1
      DATA_WIDTH_G     : integer := 40;
      BYTE_WIDTH_G     : integer := 40;
      REVERSE_INPUT_G  : boolean := false;
      REVERSE_OUTPUT_G : boolean := false;
      INVERT_OUTPUT_G  : boolean := true);
   port (
      clk       : in  sl;
      rst       : in  sl;
      crcInit   : in  slv(CRC_POLY_G'length-1 downto 0);
      dataIn    : in  slv(DATA_WIDTH_G-1 downto 0);
      dataValid : in  sl;
      dataBytes : in  slv(log2(DATA_WIDTH_G/BYTE_WIDTH_G)-1 downto 0) := (others => '1');
      crcOut    : out slv(CRC_POLY_G'length-1 downto 0);   -- CRC output
      crcRem    : out slv(CRC_POLY_G'length-1 downto 0));  -- CRC interim remainder


end Crc;

architecture rtl of Crc is

   constant CRC_LENGTH_C : integer                           := CRC_POLY_G'length;
   constant CRC_POLY_C   : slv(CRC_POLY_G'length-1 downto 0) := CRC_POLY_G;
   constant CRC_INIT_C   : slv(CRC_INIT_G'length-1 downto 0) := CRC_INIT_G;



   type RegType is record
      crc : slv(CRC_LENGTH_C-1 downto 0);
--       data      : slv(DATA_WIDTH_G-1 downto 0);
--       valid     : sl;
--       dataBytes : slv(log2(DATA_WIDTH_G/BYTE_WIDTH_G)-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      crc => CRC_INIT_G);
--       data      => (others => '0'),
--       valid     => '0',
--       dataBytes => (others => '1'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process(crcInit, dataBytes, dataIn, dataValid, r, rst)
      variable v       : RegType;
      variable data    : slv(DATA_WIDTH_G-1 downto 0) := (others => '0');
      variable valid   : sl;
      variable fb      : slv(CRC_LENGTH_C-1 downto 0);
      variable tmpOut  : slv(CRC_LENGTH_C-1 downto 0);
      variable numBits : integer;
   begin
      -- Latch the current value
      v := r;

      numBits := (conv_integer(dataBytes)+1)*BYTE_WIDTH_G;

      -- Register inputs
      valid := dataValid;

      -- Select the correct input rante
      data(numBits-1 downto 0) := dataIn(numBits-1 downto 0);

      -- Optionally transpose the input data
      --v.data := (others => '0');
      if (REVERSE_INPUT_G) then
         for i in 0 to DATA_WIDTH_G-1 loop
            if (i < numBits) then
               data(i) := dataIn(numBits-1-i);
            end if;
         end loop;
      end if;

--       v.dataBytes := dataBytes;

--       -- Select where to register the inputs
--       if (INPUT_REGISTER_G) then
--          valid   := r.valid;
--          data    := r.data;
--          numBits := (conv_integer(r.dataBytes)+1)*BYTE_WIDTH_G;
--       else
--          valid   := v.valid;
--          data    := v.data;
--          numBits := (conv_integer(v.dataBytes)+1)*BYTE_WIDTH_G;
--       end if;


      -- Reset handling
      if (rst = '1') then
         -- Pre-load the remainder
         v.crc := crcInit;
      end if;

      if (valid = '1') then
         for d in 0 to DATA_WIDTH_G-1 loop
            if (d < numBits) then
               fb    := (others => (v.crc(CRC_LENGTH_C-1) xor data(d)));
               v.crc := v.crc(CRC_LENGTH_C-2 downto 0) & fb(0);
               v.crc := (fb and CRC_POLY_G) xor v.crc;
            end if;
         end loop;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      crcRem <= r.crc;

      -- Optionally transpose and/or invert the output
      tmpOut := ite(REVERSE_OUTPUT_G, bitReverse(r.crc), r.crc);
      tmpOut := ite(INVERT_OUTPUT_G, not(tmpOut), tmpOut);
      crcOut <= tmpOut;

   end process;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
