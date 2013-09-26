-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : HeartbeatTb.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-09-26
-- Last update: 2013-09-26
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
   constant PERIOD_IN_C  : time := 6.4 ns;
   constant PERIOD_OUT_C : time := 1000 ms;

   signal clk,
      o : sl;
begin
   CLK_Inst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => PERIOD_IN_C,
         RST_START_DELAY_G => 1 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 0.25 us)  -- Hold reset for this long)
      port map (
         clkP => clk,
         clkN => open,
         rst  => open,
         rstL => open);

   Heartbeat_Inst : entity work.Heartbeat
      generic map(
         PERIOD_IN_G  => PERIOD_IN_C,
         PERIOD_OUT_G => PERIOD_OUT_C)
      port map (
         clk => clk,
         o   => o);      

end testbed;
