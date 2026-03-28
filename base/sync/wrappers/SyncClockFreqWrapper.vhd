-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.SyncClockFreq that exposes the
--              frequency and threshold generics as integers for stable test
--              parameterization under GHDL.
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

entity SyncClockFreqWrapper is
   generic (
      TPD_G               : time     := 1 ns;
      RST_ASYNC_G         : boolean  := false;
      USE_DSP_G           : string   := "no";
      REF_CLK_FREQ_INT_G  : positive := 8;
      REFRESH_RATE_INT_G  : positive := 1;
      CLK_LOWER_LIMIT_G   : natural  := 0;
      CLK_UPPER_LIMIT_G   : natural  := 16;
      COMMON_CLK_G        : boolean  := false;
      CNT_WIDTH_G         : positive := 32);
   port (
      freqOut     : out slv(CNT_WIDTH_G-1 downto 0);
      freqUpdated : out sl;
      locked      : out sl;
      tooFast     : out sl;
      tooSlow     : out sl;
      clkIn       : in  sl;
      locClk      : in  sl;
      refClk      : in  sl);
end entity SyncClockFreqWrapper;

architecture rtl of SyncClockFreqWrapper is
begin

   -- Translate cocotb-friendly integer generics into the real-valued frequency
   -- and threshold generics used by the underlying monitor.
   U_DUT : entity surf.SyncClockFreq
      generic map (
         TPD_G             => TPD_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         USE_DSP_G         => USE_DSP_G,
         REF_CLK_FREQ_G    => real(REF_CLK_FREQ_INT_G),
         REFRESH_RATE_G    => real(REFRESH_RATE_INT_G),
         CLK_LOWER_LIMIT_G => real(CLK_LOWER_LIMIT_G),
         CLK_UPPER_LIMIT_G => real(CLK_UPPER_LIMIT_G),
         COMMON_CLK_G      => COMMON_CLK_G,
         CNT_WIDTH_G       => CNT_WIDTH_G)
      port map (
         freqOut     => freqOut,
         freqUpdated => freqUpdated,
         locked      => locked,
         tooFast     => tooFast,
         tooSlow     => tooSlow,
         clkIn       => clkIn,
         locClk      => locClk,
         refClk      => refClk);

end architecture rtl;
