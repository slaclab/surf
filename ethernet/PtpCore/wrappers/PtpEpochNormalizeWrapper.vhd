-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Flat simulation boundary for the PtpEpochNormalize record ports.
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

entity PtpEpochNormalizeWrapper is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';
      RST_ASYNC_G    : boolean := false);
   port (
      clk : in  sl;
      rst : in  sl;
      -- Owner-local cancellation; discards pending and held work.
      cancel       : in  sl;
      inputValid   : in  sl;
      inputReady   : out sl;
      seconds      : in  slv(47 downto 0);
      subsecondQ16 : in  slv(47 downto 0);
      resultValid  : out sl;
      resultReady  : in  sl;
      resultValue  : out slv(94 downto 0));
end entity PtpEpochNormalizeWrapper;

architecture mapping of PtpEpochNormalizeWrapper is

   signal request : PtpEpochRequestType;
   signal result  : PtpEpochResultType;

begin

   request <=
   (
      valid        => inputValid,
      seconds      => seconds,
      subsecondQ16 => subsecondQ16
   );

   resultValid <= result.valid;
   resultValue <= result.value;

   U_DUT : entity surf.PtpEpochNormalize
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk         => clk,
         rst         => rst,
         cancel      => cancel,
         request     => request,
         inputReady  => inputReady,
         result      => result,
         resultReady => resultReady);

end architecture mapping;
