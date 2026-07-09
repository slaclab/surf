-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.Heartbeat with integer period
--              generics that map onto the DUT's real-valued timing interface.
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

entity HeartbeatWrapper is
   generic (
      TPD_G           : time     := 1 ns;
      RST_POLARITY_G  : sl       := '1';
      RST_ASYNC_G     : boolean  := false;
      TOGGLE_CYCLES_G : positive := 2);
   port (
      clk : in  sl;
      rst : in  sl := not RST_POLARITY_G;
      o   : out sl);
end entity HeartbeatWrapper;

architecture rtl of HeartbeatWrapper is

begin

   -- Map the integer cycle count used by cocotb onto the Heartbeat module's
   -- real-valued input/output period ratio.
   U_DUT : entity surf.Heartbeat
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         PERIOD_IN_G    => 1.0,
         PERIOD_OUT_G   => real(TOGGLE_CYCLES_G*2))
      port map (
         clk => clk,
         rst => rst,
         o   => o);

end architecture rtl;
