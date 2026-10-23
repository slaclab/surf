-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.SyncTrigRateVector that flattens
--              the per-lane rate array into a plain slv for direct inspection.
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

entity SyncTrigRateVectorFlatWrapper is
   generic (
      TPD_G              : time     := 1 ns;
      RST_ASYNC_G        : boolean  := false;
      COMMON_CLK_G       : boolean  := false;
      ONE_SHOT_G         : boolean  := false;
      IN_POLARITY_G      : slv      := "1";
      REF_CLK_FREQ_INT_G : positive := 8;
      REFRESH_RATE_INT_G : positive := 1;
      CNT_WIDTH_G        : positive := 8;
      WIDTH_G            : positive := 3);
   port (
      trigIn          : in  slv(WIDTH_G-1 downto 0);
      trigRateUpdated : out sl;
      trigRateOutFlat : out slv(WIDTH_G*CNT_WIDTH_G-1 downto 0);
      locClkEn        : in  sl := '1';
      locClk          : in  sl;
      refClk          : in  sl);
end entity SyncTrigRateVectorFlatWrapper;

architecture rtl of SyncTrigRateVectorFlatWrapper is

   -- Flatten the vector rate outputs so cocotb can read each lane directly
   -- without custom array-type adapters.
   signal trigRateOutArr : SlVectorArray(WIDTH_G-1 downto 0, CNT_WIDTH_G-1 downto 0);

begin

   U_DUT : entity surf.SyncTrigRateVector
      generic map (
         TPD_G          => TPD_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         COMMON_CLK_G   => COMMON_CLK_G,
         ONE_SHOT_G     => ONE_SHOT_G,
         IN_POLARITY_G  => IN_POLARITY_G,
         REF_CLK_FREQ_G => real(REF_CLK_FREQ_INT_G),
         REFRESH_RATE_G => real(REFRESH_RATE_INT_G),
         CNT_WIDTH_G    => CNT_WIDTH_G,
         WIDTH_G        => WIDTH_G)
      port map (
         trigIn          => trigIn,
         trigRateUpdated => trigRateUpdated,
         trigRateOut     => trigRateOutArr,
         locClkEn        => locClkEn,
         locClk          => locClk,
         refClk          => refClk);

   GEN_FLAT :
   for i in 0 to WIDTH_G-1 generate
      GEN_BITS :
      for j in 0 to CNT_WIDTH_G-1 generate
         trigRateOutFlat(i*CNT_WIDTH_G + j) <= trigRateOutArr(i, j);
      end generate GEN_BITS;
   end generate GEN_FLAT;

end architecture rtl;
