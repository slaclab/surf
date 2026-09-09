-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Combinational adapter for StdRtlPkg ADC conversion functions.
--
-- Exposes coding in both directions with nonzero ascending/descending bounds.
-- analogQuarterLsb is a signed voltage in quarter-LSB units relative to zero;
-- real conversion uses a nominal -1 V to +1 V window. No clocks or state.
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

entity StdRtlPkgAdcWrapper is
   generic (
      BITS_G : positive range 1 to 30 := 14);
   port (
      code             : in  slv(BITS_G-1 downto 0);
      analogQuarterLsb : in  slv(31 downto 0);
      twosDescending   : out slv(BITS_G-1 downto 0);
      twosAscending    : out slv(BITS_G-1 downto 0);
      offsetDescending : out slv(BITS_G-1 downto 0);
      offsetAscending  : out slv(BITS_G-1 downto 0);
      analogOffset     : out slv(BITS_G-1 downto 0);
      analogTwos       : out slv(BITS_G-1 downto 0));
end entity StdRtlPkgAdcWrapper;

architecture mapping of StdRtlPkgAdcWrapper is

begin

   adapt : process (code, analogQuarterLsb) is
      variable ascendingCode  : slv(5 to BITS_G+4);
      variable descendingCode : slv(BITS_G+4 downto 5);
      variable volts          : real;
   begin
      ascendingCode := code;
      descendingCode := code;
      volts := real(to_integer(signed(analogQuarterLsb)))/(4.0*2.0**(BITS_G-1));
      twosDescending <= offsetBinaryToTwosComplement(descendingCode);
      twosAscending <= offsetBinaryToTwosComplement(ascendingCode);
      offsetDescending <= twosComplementToOffsetBinary(descendingCode);
      offsetAscending <= twosComplementToOffsetBinary(ascendingCode);
      analogOffset <= adcConversion(volts, -1.0, 1.0, BITS_G, false);
      analogTwos <= adcConversion(volts, -1.0, 1.0, BITS_G, true);
   end process adapt;

end architecture mapping;
