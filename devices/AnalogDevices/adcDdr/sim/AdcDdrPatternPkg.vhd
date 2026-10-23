-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Shared PN-sequence helpers for serialized DDR ADC models
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

library surf;
use surf.StdRtlPkg.all;

package AdcDdrPatternPkg is

   function adcDdrPn9Next (state : slv(8 downto 0)) return slv;
   function adcDdrPn23Next (state : slv(22 downto 0)) return slv;
   function adcDdrPn9Advance (state : slv(8 downto 0); count : positive) return slv;
   function adcDdrPn23Advance (state : slv(22 downto 0); count : positive) return slv;
   function adcDdrPn9Word (state : slv(8 downto 0); width : positive) return slv;
   function adcDdrPn23Word (state : slv(22 downto 0); width : positive) return slv;

end package AdcDdrPatternPkg;

package body AdcDdrPatternPkg is

   -- The PN helpers use an MSB-first Fibonacci representation throughout. A
   -- caller can therefore generate the word visible on serialized ADC pins and
   -- obtain the next state by advancing exactly the same number of bits.
   function adcDdrPn9Next (state : slv(8 downto 0)) return slv is
      variable result : slv(8 downto 0);
   begin
      -- Fibonacci realization of x^9 + x^5 + 1. The current MSB is the
      -- serialized output bit and the register shifts toward the MSB.
      result := state(7 downto 0) & (state(8) xor state(4));
      return result;
   end function adcDdrPn9Next;

   function adcDdrPn23Next (state : slv(22 downto 0)) return slv is
      variable result : slv(22 downto 0);
   begin
      -- Fibonacci realization of x^23 + x^18 + 1.
      result := state(21 downto 0) & (state(22) xor state(17));
      return result;
   end function adcDdrPn23Next;

   function adcDdrPn9Advance (state : slv(8 downto 0); count : positive) return slv is
      variable result : slv(8 downto 0) := state;
   begin
      for i in 1 to count loop
         result := adcDdrPn9Next(result);
      end loop;
      return result;
   end function adcDdrPn9Advance;

   function adcDdrPn23Advance (state : slv(22 downto 0); count : positive) return slv is
      variable result : slv(22 downto 0) := state;
   begin
      for i in 1 to count loop
         result := adcDdrPn23Next(result);
      end loop;
      return result;
   end function adcDdrPn23Advance;

   function adcDdrPn9Word (state : slv(8 downto 0); width : positive) return slv is
      variable current : slv(8 downto 0) := state;
      variable result  : slv(width-1 downto 0);
   begin
      -- Fill from the result MSB downward so bit width-1 is the first bit that
      -- would appear on an MSB-first serialized lane.
      for i in width-1 downto 0 loop
         result(i) := current(8);
         current   := adcDdrPn9Next(current);
      end loop;
      return result;
   end function adcDdrPn9Word;

   function adcDdrPn23Word (state : slv(22 downto 0); width : positive) return slv is
      variable current : slv(22 downto 0) := state;
      variable result  : slv(width-1 downto 0);
   begin
      -- Keep PN23 packing identical to PN9; only the polynomial/order differs.
      for i in width-1 downto 0 loop
         result(i) := current(22);
         current   := adcDdrPn23Next(current);
      end loop;
      return result;
   end function adcDdrPn23Word;

end package body AdcDdrPatternPkg;
