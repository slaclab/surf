-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Flat simulation boundary for the PtpConstDivide record ports.
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
use surf.PtpMathPkg.all;
use surf.PtpPkg.all;

entity PtpConstDivideWrapper is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      -- Signed dividend width. Every supported divisor exceeds one, so a
      -- signed WIDTH_G-bit quotient cannot overflow; narrower consumers apply
      -- their own fit checks.
      WIDTH_G : positive         := 96;
      -- Positive constant divisor, as a 64-bit value because SECOND_Q16
      -- exceeds the range of a VHDL integer. Callers pass the named constant
      -- that carries the units for their conversion.
      DIVISOR_G : slv(63 downto 0) := (others => '1'));
   port (
      clk : in  sl;
      rst : in  sl;
      -- Owner-local cancellation; discards pending and held work.
      cancel          : in  sl;
      inputValid      : in  sl;
      inputReady      : out sl;
      roundNearest    : in  sl;
      operand         : in  slv(WIDTH_G-1 downto 0);
      resultValid     : out sl;
      resultReady     : in  sl;
      resultValue     : out slv(WIDTH_G-1 downto 0);
      resultRemainder : out slv(WIDTH_G-1 downto 0));
end entity PtpConstDivideWrapper;

architecture mapping of PtpConstDivideWrapper is

   signal request : PtpConstDivideRequestType(operand(WIDTH_G-1 downto 0));
   signal result  : PtpConstDivideResultType(value(WIDTH_G-1 downto 0), remainder(WIDTH_G-1 downto 0));

begin

   request <=
   (
      valid        => inputValid,
      roundNearest => roundNearest,
      operand      => operand
   );

   resultValid     <= result.valid;
   resultValue     <= result.value;
   resultRemainder <= result.remainder;

   U_DUT : entity surf.PtpConstDivide
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         WIDTH_G        => WIDTH_G,
         DIVISOR_G      => DIVISOR_G)
      port map (
         clk         => clk,
         rst         => rst,
         cancel      => cancel,
         request     => request,
         inputReady  => inputReady,
         result      => result,
         resultReady => resultReady);

end architecture mapping;
