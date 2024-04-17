-------------------------------------------------------------------------------
-- Title      : Hamming-ECC: https://en.wikipedia.org/wiki/Hamming_code
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Hamming-ECC Package File
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;

package HammingEccPkg is

   function hammingEccPartiyWidth (k : positive) return positive;
   function hammingEccDataWidth (k   : positive) return positive;

   function hammingEccEncode (data : slv) return slv;
   procedure hammingEccDecode (
      encWord : in    slv;
      data    : inout slv;
      errSbit : inout sl;
      errDbit : inout sl);

end package HammingEccPkg;

package body HammingEccPkg is

   function hammingEccPartiyWidth (k : positive) return positive is
      variable m : positive;
   begin
      -- Init
      m := 1;

      -----------------------------------
      -- Calculate number of parity bits:
      -----------------------------------
      -- k = 2^m - m  - 1
      --    where k is data bits
      --    where m is parity bits
      -----------------------------------
      while (2**m < k+m+1) loop
         m := m + 1;
      end loop;

      -- Return the results
      return m;
   end function;

   function hammingEccDataWidth (k : positive) return positive is
      variable m : positive;
      variable n : positive;
   begin
      m := hammingEccPartiyWidth(k);
      n := m+k;
      return n;
   end function;

   function hammingEccEncode (data : slv) return slv is
      constant k         : positive := data'length;
      constant m         : positive := hammingEccPartiyWidth(k);
      constant n         : positive := hammingEccDataWidth(k);
      variable bitPtr    : natural;
      variable codeWord  : slv(n downto 1);
      variable pVector   : slv(m downto 1);
      variable pExtended : sl;
      variable encWord   : slv(n downto 0);
   begin
      -- Init
      bitPtr   := 0;
      codeWord := (others => '0');
      pVector  := (others => '0');

      -- Put the data bits in the correct location
      for i in 1 to n loop
         if (isPowerOf2(i) = false) then
            codeWord(i) := data(bitPtr);
            bitPtr      := bitPtr + 1;
         end if;
      end loop;

      -- Calculate the parity vector
      for i in 1 to m loop
         for j in 1 to n loop
            if uOr(toSlv(2**(i-1), n) and toSlv(j, n)) = '1' then
               pVector(i) := pVector(i) xor codeWord(j);
            end if;
         end loop;
      end loop;

      -- Put the parity bits in the correct location
      for i in 1 to m loop
         codeWord(2**(i-1)) := pVector(i);
      end loop;

      -- Calculate extended parity bit
      pExtended := uXor(codeWord);

      -- Set the output encoded data bus
      encWord := codeWord & pExtended;

      -- Return the results
      return encWord;
   end function;

   procedure hammingEccDecode (
      encWord : in    slv;
      data    : inout slv;
      errSbit : inout sl;
      errDbit : inout sl) is
      constant k        : positive := data'length;
      constant m        : positive := hammingEccPartiyWidth(k);
      constant n        : positive := hammingEccDataWidth(k);
      variable bitPtr   : natural;
      variable parity   : sl;
      variable syndrome : slv(m downto 1);
      variable codeWord : slv(n downto 0);
   begin
      -- Init
      bitPtr   := 0;
      data     := toSlv(0, data'length);
      errSbit  := '0';
      errDbit  := '0';
      syndrome := (others => '0');
      codeWord := encWord;

      -- Calculate parity
      parity := uXor(encWord);

      -- Calculate syndrome
      for i in 1 to m loop
         for j in 1 to n loop
            if uOr(toSlv(2**(i-1), n) and toSlv(j, n)) = '1' then
               syndrome(i) := syndrome(i) xor encWord(j);
            end if;
         end loop;
      end loop;

      -- Correct the code word
      if (conv_integer(syndrome) <= n) then
         codeWord(conv_integer(syndrome)) := not(codeWord(conv_integer(syndrome)));
      end if;

      -- Get the data bits in the correct location
      for i in 1 to n loop
         if (isPowerOf2(i) = false) then
            data(bitPtr) := codeWord(i);
            bitPtr       := bitPtr + 1;
         end if;
      end loop;

      -- Set the status flags
      errSbit := parity or uOr(syndrome);
      errDbit := not(parity) and uOr(syndrome);

   end procedure;

end package body HammingEccPkg;
