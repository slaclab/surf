-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for the Heartbeat module
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

entity HeartbeatTb is end HeartbeatTb;

architecture testbed of HeartbeatTb is
   signal clkIn  : slv(2 downto 0);
   signal clkOut : slv(2 downto 0);
begin
   CLK_0 : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => 4 ns,
         RST_START_DELAY_G => 1 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 0.25 us)  -- Hold reset for this long)
      port map (
         clkP => clkIn(0),
         clkN => open,
         rst  => open,
         rstL => open);

   CLK_1 : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => 20 ns,
         RST_START_DELAY_G => 1 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 0.25 us)  -- Hold reset for this long)
      port map (
         clkP => clkIn(1),
         clkN => open,
         rst  => open,
         rstL => open);

   CLK_2 : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => 6.4 ns,
         RST_START_DELAY_G => 1 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 0.25 us)  -- Hold reset for this long)
      port map (
         clkP => clkIn(2),
         clkN => open,
         rst  => open,
         rstL => open);       

   Heartbeat_0 : entity surf.Heartbeat
      generic map(
         PERIOD_IN_G  => 4.0E-9,
         PERIOD_OUT_G => 1.0E-3)
      port map (
         clk => clkIn(0),
         o   => clkOut(0));  

   Heartbeat_1 : entity surf.Heartbeat
      generic map(
         PERIOD_IN_G  => 20.0E-9,
         PERIOD_OUT_G => 1.0E-3)
      port map (
         clk => clkIn(1),
         o   => clkOut(1));  

   Heartbeat_2 : entity surf.Heartbeat
      generic map(
         PERIOD_IN_G  => 6.4E-9,
         PERIOD_OUT_G => 1.0E-3)
      port map (
         clk => clkIn(2),
         o   => clkOut(2));         

end testbed;
