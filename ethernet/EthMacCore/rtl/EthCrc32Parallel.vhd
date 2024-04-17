-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Ethernet CRC32 Ethernet/AAL5 Module
-- Polynomial: x^32 + x^26 + x^23 + x^22 + x^16 + x^12 + x^11 + x^10 + x^8 + x^7 + x^5 + x^4 + x^2 + x^1 + 1
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
use surf.EthCrc32Pkg.all;

entity EthCrc32Parallel is
   generic (
      TPD_G        : time                   := 1 ns;
      USE_DSP_G    : boolean                := false;-- true is not tested yet
      CRC_INIT_G   : slv(31 downto 0)       := x"FFFFFFFF";
      BYTE_WIDTH_G : positive range 1 to 16 := 16);  -- Maximum byte width (1-16 supported)
   port (
      crcClk       : in  sl;
      crcReset     : in  sl;
      crcDataValid : in  sl;
      crcDataWidth : in  slv(3 downto 0);  -- # of bytes minus 1 (example: 0 - 1 byte, 1 - 2 bytes ... , 15 - 16 bytes)
      crcIn        : in  slv((BYTE_WIDTH_G*8-1) downto 0);
      crcOut       : out slv(31 downto 0));
end EthCrc32Parallel;

architecture rtl of EthCrc32Parallel is

   type RegType is record
      valid     : sl;
      byteWidth : slv(3 downto 0);
      data      : slv((BYTE_WIDTH_G*8-1) downto 0);
      crc       : slv(31 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      valid     => '0',
      byteWidth => (others => '0'),
      data      => (others => '0'),
      crc       => CRC_INIT_G);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dspInA : Slv96Array(31 downto 0);
   signal dspInB : Slv192Array(31 downto 0);
   signal dspOut : slv(31 downto 0);

   -- attribute dont_touch           : string;
   -- attribute dont_touch of r      : signal is "true";
   -- attribute dont_touch of dspInA : signal is "true";
   -- attribute dont_touch of dspInB : signal is "true";
   -- attribute dont_touch of dspOut : signal is "true";

begin

   GEN_DSP : if (USE_DSP_G) generate
      GEN_VEC :
      for i in 31 downto 0 generate

         GEN_A : if (BYTE_WIDTH_G < 9) generate

            U_Xor : entity surf.DspXor
               generic map (
                  TPD_G   => TPD_G,
                  INIT_G  => CRC_INIT_G(i),
                  WIDTH_G => 96)
               port map (
                  clk  => crcClk,
                  rst  => crcReset,     -- ASYNC RST
                  ain  => dspInA(i),
                  pOut => dspOut(i));

         end generate;

         GEN_B : if (BYTE_WIDTH_G >= 9) generate

            U_Xor : entity surf.DspXor
               generic map (
                  TPD_G   => TPD_G,
                  INIT_G  => CRC_INIT_G(i),
                  WIDTH_G => 192)
               port map (
                  clk  => crcClk,
                  rst  => crcReset,     -- ASYNC RST
                  ain  => dspInB(i),
                  pOut => dspOut(i));

         end generate;

      end generate GEN_VEC;
   end generate;

   comb : process(crcDataValid, crcDataWidth, crcIn, crcReset, dspOut, r)
      variable v          : RegType;
      variable dspOut     : slv(31 downto 0);
      variable xorBitMapA : Slv96Array(31 downto 0);
      variable xorBitMapB : Slv192Array(31 downto 0);
      variable prevCrc    : slv(31 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Reset the variables
      xorBitMapA := (others => (others => '0'));
      xorBitMapB := (others => (others => '0'));

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

      if (USE_DSP_G = false) then
         if (crcReset = '0') then
            prevCrc := r.crc;
         else
            prevCrc := CRC_INIT_G;
         end if;
      end if;

      -- Calculate CRC in parallel - implementation used depends on the byte width in use.
      if (r.valid = '1') then
         case(r.byteWidth) is
            ---------------------------------------------------------------------------------------------------------------
            when x"0" =>                -- 1 Byte (8-bits)
               if (USE_DSP_G) then
                  if (BYTE_WIDTH_G < 9) then
                     xorBitMap1Byte(xorBitMapA, dspOut, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-1)*8));
                  else
                     xorBitMap1Byte(xorBitMapB, dspOut, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-1)*8));
                  end if;
               else
                  v.crc := crc32Parallel1Byte(prevCrc, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-1)*8));
               end if;
            ---------------------------------------------------------------------------------------------------------------
            when x"1" =>                -- 2 Byte (16-bits)
               if (BYTE_WIDTH_G >= 2) then
                  if (USE_DSP_G) then
                     if (BYTE_WIDTH_G < 9) then
                        xorBitMap2Byte(xorBitMapA, dspOut, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-2)*8));
                     else
                        xorBitMap2Byte(xorBitMapB, dspOut, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-2)*8));
                     end if;
                  else
                     v.crc := crc32Parallel2Byte(prevCrc, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-2)*8));
                  end if;
               end if;
            ---------------------------------------------------------------------------------------------------------------
            when x"2" =>                -- 3 Byte (24-bits)
               if (BYTE_WIDTH_G >= 3) then
                  if (USE_DSP_G) then
                     if (BYTE_WIDTH_G < 9) then
                        xorBitMap3Byte(xorBitMapA, dspOut, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-3)*8));
                     else
                        xorBitMap3Byte(xorBitMapB, dspOut, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-3)*8));
                     end if;
                  else
                     v.crc := crc32Parallel3Byte(prevCrc, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-3)*8));
                  end if;
               end if;
            ---------------------------------------------------------------------------------------------------------------
            when x"3" =>                -- 4 Byte (32-bits)
               if (BYTE_WIDTH_G >= 4) then
                  if (USE_DSP_G) then
                     if (BYTE_WIDTH_G < 9) then
                        xorBitMap4Byte(xorBitMapA, dspOut, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-4)*8));
                     else
                        xorBitMap4Byte(xorBitMapB, dspOut, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-4)*8));
                     end if;
                  else
                     v.crc := crc32Parallel4Byte(prevCrc, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-4)*8));
                  end if;
               end if;
            ---------------------------------------------------------------------------------------------------------------
            when x"4" =>                -- 5 Byte (40-bits)
               if (BYTE_WIDTH_G >= 5) then
                  if (USE_DSP_G) then
                     if (BYTE_WIDTH_G < 9) then
                        xorBitMap5Byte(xorBitMapA, dspOut, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-5)*8));
                     else
                        xorBitMap5Byte(xorBitMapB, dspOut, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-5)*8));
                     end if;
                  else
                     v.crc := crc32Parallel5Byte(prevCrc, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-5)*8));
                  end if;
               end if;
            ---------------------------------------------------------------------------------------------------------------
            when x"5" =>                -- 6 Byte (48-bits)
               if (BYTE_WIDTH_G >= 6) then
                  if (USE_DSP_G) then
                     if (BYTE_WIDTH_G < 9) then
                        xorBitMap6Byte(xorBitMapA, dspOut, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-6)*8));
                     else
                        xorBitMap6Byte(xorBitMapB, dspOut, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-6)*8));
                     end if;
                  else
                     v.crc := crc32Parallel6Byte(prevCrc, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-6)*8));
                  end if;
               end if;
            ---------------------------------------------------------------------------------------------------------------
            when x"6" =>                -- 7 Byte (56-bits)
               if (BYTE_WIDTH_G >= 7) then
                  if (USE_DSP_G) then
                     if (BYTE_WIDTH_G < 9) then
                        xorBitMap7Byte(xorBitMapA, dspOut, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-7)*8));
                     else
                        xorBitMap7Byte(xorBitMapB, dspOut, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-7)*8));
                     end if;
                  else
                     v.crc := crc32Parallel7Byte(prevCrc, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-7)*8));
                  end if;
               end if;
            ---------------------------------------------------------------------------------------------------------------
            when x"7" =>                -- 8 Byte (64-bits)
               if (BYTE_WIDTH_G >= 8) then
                  if (USE_DSP_G) then
                     if (BYTE_WIDTH_G < 9) then
                        xorBitMap8Byte(xorBitMapA, dspOut, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-8)*8));
                     else
                        xorBitMap8Byte(xorBitMapB, dspOut, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-8)*8));
                     end if;
                  else
                     v.crc := crc32Parallel8Byte(prevCrc, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-8)*8));

                  end if;
               end if;
            ---------------------------------------------------------------------------------------------------------------
            when x"8" =>                -- 9 Byte (72-bits)
               if (BYTE_WIDTH_G >= 9) then
                  if (USE_DSP_G) then
                     xorBitMap9Byte(xorBitMapB, dspOut, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-9)*8));
                  else
                     v.crc := crc32Parallel9Byte(prevCrc, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-9)*8));
                  end if;
               end if;
            ---------------------------------------------------------------------------------------------------------------
            when x"9" =>                -- 10 Byte (80-bits)
               if (BYTE_WIDTH_G >= 10) then
                  if (USE_DSP_G) then
                     xorBitMap10Byte(xorBitMapB, dspOut, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-10)*8));
                  else
                     v.crc := crc32Parallel10Byte(prevCrc, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-10)*8));
                  end if;
               end if;
            ---------------------------------------------------------------------------------------------------------------
            when x"A" =>                -- 11 Byte (88-bits)
               if (BYTE_WIDTH_G >= 11) then
                  if (USE_DSP_G) then
                     xorBitMap11Byte(xorBitMapB, dspOut, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-11)*8));
                  else
                     v.crc := crc32Parallel11Byte(prevCrc, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-11)*8));
                  end if;
               end if;
            ---------------------------------------------------------------------------------------------------------------
            when x"B" =>                -- 12 Byte (96-bits)
               if (BYTE_WIDTH_G >= 12) then
                  if (USE_DSP_G) then
                     xorBitMap12Byte(xorBitMapB, dspOut, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-12)*8));
                  else
                     v.crc := crc32Parallel12Byte(prevCrc, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-12)*8));
                  end if;
               end if;
            ---------------------------------------------------------------------------------------------------------------
            when x"C" =>                -- 13 Byte (104-bits)
               if (BYTE_WIDTH_G >= 13) then
                  if (USE_DSP_G) then
                     xorBitMap13Byte(xorBitMapB, dspOut, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-13)*8));
                  else
                     v.crc := crc32Parallel13Byte(prevCrc, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-13)*8));
                  end if;
               end if;
            ---------------------------------------------------------------------------------------------------------------
            when x"D" =>                -- 14 Byte (112-bits)
               if (BYTE_WIDTH_G >= 14) then
                  if (USE_DSP_G) then
                     xorBitMap14Byte(xorBitMapB, dspOut, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-14)*8));
                  else
                     v.crc := crc32Parallel14Byte(prevCrc, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-14)*8));
                  end if;
               end if;
            ---------------------------------------------------------------------------------------------------------------
            when x"E" =>                -- 15 Byte (120-bits)
               if (BYTE_WIDTH_G >= 15) then
                  if (USE_DSP_G) then
                     xorBitMap15Byte(xorBitMapB, dspOut, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-15)*8));
                  else
                     v.crc := crc32Parallel15Byte(prevCrc, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-15)*8));
                  end if;
               end if;
            ---------------------------------------------------------------------------------------------------------------
            when x"F" =>                -- 16 Byte (128-bits)
               if (BYTE_WIDTH_G = 16) then
                  if (USE_DSP_G) then
                     xorBitMap16Byte(xorBitMapB, dspOut, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-16)*8));
                  else
                     v.crc := crc32Parallel16Byte(prevCrc, r.data(BYTE_WIDTH_G*8-1 downto (BYTE_WIDTH_G-16)*8));
                  end if;
               end if;
         ---------------------------------------------------------------------------------------------------------------
         end case;
      elsif (USE_DSP_G = false) then
         v.crc := prevCrc;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Transpose each byte in the data out and invert
      -- This inversion is equivalent to an XOR of the CRC register with xFFFFFFFF
      for byte in 0 to 3 loop
         for b in 0 to 7 loop
            if (USE_DSP_G) then
               crcOut(byte*8+b) <= not(dspOut((byte+1)*8-1-b));
            else
               crcOut(byte*8+b) <= not(r.crc((byte+1)*8-1-b));
            end if;
         end loop;
      end loop;

      -- Outputs
      dspInA <= xorBitMapA;
      dspInB <= xorBitMapB;

   end process;

   seq : process (crcClk) is
   begin
      if (rising_edge(crcClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
