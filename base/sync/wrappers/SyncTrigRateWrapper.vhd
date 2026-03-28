-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.SyncTrigRate with integer
--              frequency generics that map onto the DUT's real-valued inputs.
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

entity SyncTrigRateWrapper is
   generic (
      TPD_G              : time     := 1 ns;
      RST_ASYNC_G        : boolean  := false;
      COMMON_CLK_G       : boolean  := false;
      ONE_SHOT_G         : boolean  := false;
      IN_POLARITY_G      : sl       := '1';
      COUNT_EDGES_G      : boolean  := false;
      REF_CLK_FREQ_INT_G : positive := 8;
      REFRESH_RATE_INT_G : positive := 1;
      CNT_WIDTH_G        : positive := 32);
   port (
      trigIn          : in  sl;
      trigRateUpdated : out sl;
      trigRateOut     : out slv(CNT_WIDTH_G-1 downto 0);
      trigRateOutMax  : out slv(CNT_WIDTH_G-1 downto 0);
      trigRateOutMin  : out slv(CNT_WIDTH_G-1 downto 0);
      locClkEn        : in  sl := '1';
      locClk          : in  sl;
      locRst          : in  sl := '0';
      refClk          : in  sl;
      refRst          : in  sl := '0');
end entity SyncTrigRateWrapper;

architecture rtl of SyncTrigRateWrapper is
begin

   -- Expose the measurement-window configuration as integers so the cocotb
   -- bench can override them cleanly under GHDL.
   U_DUT : entity surf.SyncTrigRate
      generic map (
         TPD_G          => TPD_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         COMMON_CLK_G   => COMMON_CLK_G,
         ONE_SHOT_G     => ONE_SHOT_G,
         IN_POLARITY_G  => IN_POLARITY_G,
         COUNT_EDGES_G  => COUNT_EDGES_G,
         REF_CLK_FREQ_G => real(REF_CLK_FREQ_INT_G),
         REFRESH_RATE_G => real(REFRESH_RATE_INT_G),
         CNT_WIDTH_G    => CNT_WIDTH_G)
      port map (
         trigIn          => trigIn,
         trigRateUpdated => trigRateUpdated,
         trigRateOut     => trigRateOut,
         trigRateOutMax  => trigRateOutMax,
         trigRateOutMin  => trigRateOutMin,
         locClkEn        => locClkEn,
         locClk          => locClk,
         locRst          => locRst,
         refClk          => refClk,
         refRst          => refRst);

end architecture rtl;
