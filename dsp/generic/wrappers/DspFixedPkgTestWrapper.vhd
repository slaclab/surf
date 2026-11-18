-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: cocotb wrapper exposing the DspFixedPkg functions on ports.
--              Combinational: the outputs follow a, b and n. The toFixed and
--              toReal results are elaboration time constants.
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
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.DspFixedPkg.all;

entity DspFixedPkgTestWrapper is
   port (
      a             : in  slv(15 downto 0);
      b             : in  slv(15 downto 0);
      n             : in  slv(4 downto 0);
      -- absMag(a)
      absMagOut     : out slv(16 downto 0);
      -- saturate(a, 8)
      satS          : out slv(7 downto 0);
      satU          : out slv(7 downto 0);
      -- shiftRightRound(a, n), ties up then ties to even
      shrS          : out slv(15 downto 0);
      shrSEven      : out slv(15 downto 0);
      shrU          : out slv(15 downto 0);
      shrUEven      : out slv(15 downto 0);
      -- addSat/subSat(a, b), addSat(a, b(7 downto 0))
      addSatS       : out slv(15 downto 0);
      subSatS       : out slv(15 downto 0);
      addSatU       : out slv(15 downto 0);
      subSatU       : out slv(15 downto 0);
      addSatMix     : out slv(15 downto 0);
      -- clamp(a, -1000, 1000) and clamp(a, 100, 60000)
      clampS        : out slv(15 downto 0);
      clampU        : out slv(15 downto 0);
      -- magL1(a, b), magLinf(a, b)
      magL1Out      : out slv(16 downto 0);
      magLinfOut    : out slv(16 downto 0);
      -- toFixed constants
      fixedHalf     : out slv(15 downto 0);  -- toFixed(0.5, 16, 15)   = 0x4000
      fixedMinusOne : out slv(15 downto 0);  -- toFixed(-1.0, 16, 15)  = 0x8000
      fixedSatHi    : out slv(15 downto 0);  -- toFixed(1.0, 16, 15)   = 0x7FFF (clamped)
      fixedSatLo    : out slv(15 downto 0);  -- toFixed(-1.5, 16, 15)  = 0x8000 (clamped)
      fixedTenth    : out slv(15 downto 0);  -- toFixed(0.1, 16, 12)   = 410
      fixedNeg      : out slv(7 downto 0);   -- toFixed(-0.3, 8, 4)    = -5
      fixedTie      : out slv(7 downto 0);   -- toFixed(2.5, 8, 0)     = 3 (ties away from zero)
      fixedTieNeg   : out slv(7 downto 0);   -- toFixed(-2.5, 8, 0)    = -3
      fixedInt      : out slv(31 downto 0);  -- toFixed(-3.0, 32, 0)   = -3
      -- toReal round trips
      toRealOk      : out sl);
end entity DspFixedPkgTestWrapper;

architecture rtl of DspFixedPkgTestWrapper is

   constant TENTH_C : slv(15 downto 0) := toFixed(0.1, 16, 12);

   function toRealChecks return sl is
   begin
      if (abs(toReal(TENTH_C, 12) - 410.0/4096.0) < 1.0E-12) and
         (abs(toReal(to_signed(-5, 8), 4) + 0.3125) < 1.0E-12) and
         (abs(toReal(to_unsigned(400, 16), 8) - 1.5625) < 1.0E-12) and
         (abs(toReal(std_logic_vector'(x"8000"), 15) + 1.0) < 1.0E-12) then
         return '1';
      else
         return '0';
      end if;
   end function;

   signal shift : natural range 0 to 31;

begin

   shift <= to_integer(unsigned(n));

   absMagOut <= absMag(a);

   satS <= slv(saturate(signed(a), 8));
   satU <= slv(saturate(unsigned(a), 8));

   shrS     <= slv(shiftRightRound(signed(a), shift));
   shrSEven <= slv(shiftRightRound(signed(a), shift, true));
   shrU     <= slv(shiftRightRound(unsigned(a), shift));
   shrUEven <= slv(shiftRightRound(unsigned(a), shift, true));

   addSatS   <= slv(addSat(signed(a), signed(b)));
   subSatS   <= slv(subSat(signed(a), signed(b)));
   addSatU   <= slv(addSat(unsigned(a), unsigned(b)));
   subSatU   <= slv(subSat(unsigned(a), unsigned(b)));
   addSatMix <= slv(addSat(signed(a), signed(b(7 downto 0))));

   clampS <= slv(clamp(signed(a), to_signed(-1000, 16), to_signed(1000, 16)));
   clampU <= slv(clamp(unsigned(a), to_unsigned(100, 16), to_unsigned(60000, 16)));

   magL1Out   <= slv(magL1(signed(a), signed(b)));
   magLinfOut <= slv(magLinf(signed(a), signed(b)));

   fixedHalf     <= toFixed(0.5, 16, 15);
   fixedMinusOne <= toFixed(-1.0, 16, 15);
   fixedSatHi    <= toFixed(1.0, 16, 15);
   fixedSatLo    <= toFixed(-1.5, 16, 15);
   fixedTenth    <= TENTH_C;
   fixedNeg      <= toFixed(-0.3, 8, 4);
   fixedTie      <= toFixed(2.5, 8, 0);
   fixedTieNeg   <= toFixed(-2.5, 8, 0);
   fixedInt      <= toFixed(-3.0, 32, 0);

   toRealOk <= toRealChecks;

end architecture rtl;
