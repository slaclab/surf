-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for the Debouncer module
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;

entity DebouncerTb is end DebouncerTb;

architecture testbed of DebouncerTb is

   constant CLK_PERIOD_C : time := 10 ns;
   constant TPD_C        : time := (CLK_PERIOD_C/4);

   signal clk : sl;
   signal rst : sl;
   signal i   : sl;
   signal o   : sl;

begin

   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => clk,
         rst  => rst);

   U_DUT : entity surf.Debouncer
      generic map(
         TPD_G             => TPD_C,
         INPUT_POLARITY_G  => '1',
         OUTPUT_POLARITY_G => '1',
         CLK_FREQ_G        => 100.0E+6,  -- units of Hz
         DEBOUNCE_PERIOD_G => 100.0E-9,  -- units of seconds
         SYNCHRONIZE_G     => true,  -- Run input through 2 FFs before filtering
         SYNC_EDGE_TRIG_G  => true)  -- TRUE: debouncer fire on the leading edge detected
      port map (
         clk => clk,
         rst => rst,
         i   => i,
         o   => o);

   -- Drive input 'i' with chatter before and after pulse
   p_stim : process
   begin
      i <= '0';

      -- 1.002 us after reset deasserts, start chatter
      wait until rst = '1';
      wait until rst = '0';
      wait for 1.002 us;

      -- 7 ns chatter before the main pulse
      for j in 0 to 6 loop
         i <= not i;
         wait for 1 ns;
      end loop;

      -- Main pulse: keep high for 25 ns
      i <= '1';
      wait for 25 ns;

      -- 7 ns chatter after pulse
      for j in 0 to 6 loop
         i <= not i;
         wait for 1 ns;
      end loop;

      -- Finish low
      i <= '0';
      wait;
   end process;

end testbed;
