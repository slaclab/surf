-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.SyncStatusVector that flattens
--              the counter array output into a plain slv for direct inspection.
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

entity SyncStatusVectorFlatWrapper is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      COMMON_CLK_G   : boolean  := false;
      SYNC_STAGES_G  : positive := 3;
      IN_POLARITY_G  : slv      := "1";
      OUT_POLARITY_G : sl       := '1';
      USE_DSP_G      : string   := "no";
      SYNTH_CNT_G    : slv      := "1";
      CNT_RST_EDGE_G : boolean  := true;
      CNT_WIDTH_G    : positive := 32;
      WIDTH_G        : positive := 16);
   port (
      statusIn     : in  slv(WIDTH_G-1 downto 0);
      statusOut    : out slv(WIDTH_G-1 downto 0);
      cntRstIn     : in  sl;
      rollOverEnIn : in  slv(WIDTH_G-1 downto 0) := (others => '0');
      cntOutFlat   : out slv(WIDTH_G*CNT_WIDTH_G-1 downto 0);
      irqEnIn      : in  slv(WIDTH_G-1 downto 0) := (others => '0');
      irqOut       : out sl;
      wrClk        : in  sl;
      wrRst        : in  sl := '0';
      rdClk        : in  sl;
      rdRst        : in  sl := '0');
end entity SyncStatusVectorFlatWrapper;

architecture rtl of SyncStatusVectorFlatWrapper is

   -- Flatten the SlVectorArray counter bank so cocotb can inspect the per-lane
   -- counts without requiring custom type handling.
   signal cntOutArr : SlVectorArray(WIDTH_G-1 downto 0, CNT_WIDTH_G-1 downto 0);

begin

   U_DUT : entity surf.SyncStatusVector
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         COMMON_CLK_G   => COMMON_CLK_G,
         SYNC_STAGES_G  => SYNC_STAGES_G,
         IN_POLARITY_G  => IN_POLARITY_G,
         OUT_POLARITY_G => OUT_POLARITY_G,
         USE_DSP_G      => USE_DSP_G,
         SYNTH_CNT_G    => SYNTH_CNT_G,
         CNT_RST_EDGE_G => CNT_RST_EDGE_G,
         CNT_WIDTH_G    => CNT_WIDTH_G,
         WIDTH_G        => WIDTH_G)
      port map (
         statusIn     => statusIn,
         statusOut    => statusOut,
         cntRstIn     => cntRstIn,
         rollOverEnIn => rollOverEnIn,
         cntOut       => cntOutArr,
         irqEnIn      => irqEnIn,
         irqOut       => irqOut,
         wrClk        => wrClk,
         wrRst        => wrRst,
         rdClk        => rdClk,
         rdRst        => rdRst);

   GEN_FLAT :
   for i in 0 to WIDTH_G-1 generate
      GEN_BITS :
      for j in 0 to CNT_WIDTH_G-1 generate
         cntOutFlat(i*CNT_WIDTH_G + j) <= cntOutArr(i, j);
      end generate GEN_BITS;
   end generate GEN_FLAT;

end architecture rtl;
