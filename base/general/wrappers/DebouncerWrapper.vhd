-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.Debouncer with an integer
--              debounce cycle generic mapped onto the DUT's real period input.
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

entity DebouncerWrapper is
   generic (
      TPD_G              : time     := 1 ns;
      RST_POLARITY_G     : sl       := '1';
      RST_ASYNC_G        : boolean  := false;
      INPUT_POLARITY_G   : sl       := '0';
      OUTPUT_POLARITY_G  : sl       := '1';
      SYNCHRONIZE_G      : boolean  := true;
      SYNC_EDGE_TRIG_G   : boolean  := false;
      DEBOUNCE_CYCLES_G  : positive := 3);
   port (
      clk : in  sl;
      rst : in  sl := not RST_POLARITY_G;
      i   : in  sl;
      o   : out sl);
end entity DebouncerWrapper;

architecture rtl of DebouncerWrapper is

begin

   -- Convert the cocotb-facing integer debounce window into the real-valued
   -- period generic expected by the underlying SURF leaf.
   U_DUT : entity surf.Debouncer
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         INPUT_POLARITY_G  => INPUT_POLARITY_G,
         OUTPUT_POLARITY_G => OUTPUT_POLARITY_G,
         CLK_FREQ_G        => 1.0,
         DEBOUNCE_PERIOD_G => real(DEBOUNCE_CYCLES_G),
         SYNCHRONIZE_G     => SYNCHRONIZE_G,
         SYNC_EDGE_TRIG_G  => SYNC_EDGE_TRIG_G)
      port map (
         clk => clk,
         rst => rst,
         i   => i,
         o   => o);

end architecture rtl;
