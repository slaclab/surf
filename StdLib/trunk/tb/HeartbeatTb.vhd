-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : HeartbeatTb.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-09-26
-- Last update: 2013-10-02
-- Platform   : ISE 14.5
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

entity HeartbeatTb is end HeartbeatTb;

architecture testbed of HeartbeatTb is
   signal clkIn  : slv(2 downto 0);
   signal clkOut : slv(2 downto 0);
begin
   CLK_0 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 4 ns,
         RST_START_DELAY_G => 1 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 0.25 us)  -- Hold reset for this long)
      port map (
         clkP => clkIn(0),
         clkN => open,
         rst  => open,
         rstL => open);

   CLK_1 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 20 ns,
         RST_START_DELAY_G => 1 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 0.25 us)  -- Hold reset for this long)
      port map (
         clkP => clkIn(1),
         clkN => open,
         rst  => open,
         rstL => open);

   CLK_2 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 6.4 ns,
         RST_START_DELAY_G => 1 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 0.25 us)  -- Hold reset for this long)
      port map (
         clkP => clkIn(2),
         clkN => open,
         rst  => open,
         rstL => open);       

   Heartbeat_0 : entity work.Heartbeat
      generic map(
         PERIOD_IN_G  => 4 ns,
         PERIOD_OUT_G => 1000 ms)
      port map (
         clk => clkIn(0),
         o   => clkOut(0));  

   Heartbeat_1 : entity work.Heartbeat
      generic map(
         PERIOD_IN_G  => 20 ns,
         PERIOD_OUT_G => 1000 ms)
      port map (
         clk => clkIn(1),
         o   => clkOut(1));  

   Heartbeat_2 : entity work.Heartbeat
      generic map(
         PERIOD_IN_G  => 6.4 ns,
         PERIOD_OUT_G => 1000 ms)
      port map (
         clk => clkIn(2),
         o   => clkOut(2));         

end testbed;
