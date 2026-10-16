-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Flat simulation boundary for the PtpMath record interface.
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

entity PtpMathWrapper is
   generic (
      TPD_G           : time                          := 1 ns;
      RST_POLARITY_G  : sl                            := '1';
      RST_ASYNC_G     : boolean                       := false;
      DIVISOR_WIDTH_G : positive range 1 to 128       := 128);
   port (
      clk          : in  sl;
      rst          : in  sl;
      cancel       : in  sl := '0';
      inputValid   : in  sl;
      inputReady   : out sl;
      divide       : in  sl;
      roundNearest : in  sl := '1';
      operandA     : in  slv(127 downto 0);
      operandB     : in  slv(127 downto 0);
      -- Registered valid; transfer requires valid/ready high and cancel/reset inactive.
      resultValid     : out sl;
      resultReady     : in  sl := '1';  -- Default consumer accepts every result.
      resultValue     : out slv(127 downto 0);
      resultRemainder : out slv(127 downto 0);
      resultError     : out sl);
end entity PtpMathWrapper;

architecture mapping of PtpMathWrapper is

   signal request : PtpMathRequestType;
   signal result  : PtpMathResultType;

begin

   request <=
   (
      valid        => inputValid,
      divide       => divide,
      roundNearest => roundNearest,
      operandA     => operandA,
      operandB     => operandB
   );
   resultValid     <= result.valid;
   resultValue     <= result.value;
   resultRemainder <= result.remainder;
   resultError     <= result.error;
   U_DUT : entity surf.PtpMath
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         DIVISOR_WIDTH_G => DIVISOR_WIDTH_G)
      port map (
         clk         => clk,           -- [in]
         rst         => rst,           -- [in]
         cancel      => cancel,        -- [in]
         request     => request,       -- [in]
         inputReady  => inputReady,    -- [out]
         result      => result,        -- [out]
         resultReady => resultReady);  -- [in]

end architecture mapping;
