-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Combinational verification boundary for the production clock
-- carry-select adder and modulo-tick expiry predicate. No alternate arithmetic
-- implementation or protocol state is present in this simulation-only wrapper.
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
use surf.PtpPkg.all;

entity PtpTimingMathWrapper is
   generic (
      WIDTH_G : positive := 67);
   port (
      operandA : in  slv(WIDTH_G-1 downto 0);
      operandB : in  slv(WIDTH_G-1 downto 0);
      carry    : in  sl;
      timeout  : in  slv(63 downto 0);
      sumValue : out slv(WIDTH_G-1 downto 0);
      expired  : out sl);
end entity PtpTimingMathWrapper;

architecture mapping of PtpTimingMathWrapper is

begin

   sumValue <= slv(ptpAddFast(unsigned(operandA), unsigned(operandB), carry));
   expired <= toSl(ptpAgeExpired(operandA(63 downto 0), operandB(63 downto 0), timeout));

end architecture mapping;
