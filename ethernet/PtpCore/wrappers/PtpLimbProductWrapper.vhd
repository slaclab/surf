-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Flat simulation boundary for the PtpLimbProduct record ports.
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

entity PtpLimbProductWrapper is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      A_G            : positive := 96;
      B_G            : positive := 95);
   port (
      clk : in  sl;
      rst : in  sl;
      -- Owner-local cancellation; discards pending and held work.
      cancel      : in  sl;
      inputValid  : in  sl;
      inputReady  : out sl;
      operandA    : in  slv(A_G-1 downto 0);
      operandB    : in  slv(B_G-1 downto 0);
      resultValid : out sl;
      resultReady : in  sl;
      resultValue : out slv(A_G+B_G-1 downto 0);
      -- Asserted when the full product does not fit signed 128 bits,
      -- independent of whether any later shifted result would be
      -- representable.
      overflow : out sl);
end entity PtpLimbProductWrapper;

architecture mapping of PtpLimbProductWrapper is

   signal request : PtpProductRequestType(operandA(A_G-1 downto 0), operandB(B_G-1 downto 0));
   signal result  : PtpProductResultType(value(A_G+B_G-1 downto 0));

begin

   request <=
   (
      valid    => inputValid,
      operandA => operandA,
      operandB => operandB
   );

   resultValid <= result.valid;
   resultValue <= result.value;
   overflow    <= result.overflow;

   U_DUT : entity surf.PtpLimbProduct
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         A_G            => A_G,
         B_G            => B_G)
      port map (
         clk         => clk,
         rst         => rst,
         cancel      => cancel,
         request     => request,
         inputReady  => inputReady,
         result      => result,
         resultReady => resultReady);

end architecture mapping;
