-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SynchronizerOneShotTb.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-04
-- Last update: 2014-04-04
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the VcPrbsTx and VcPrbsRx modules
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

use work.StdRtlPkg.all;

entity SynchronizerOneShotTb is end SynchronizerOneShotTb;

architecture testbed of SynchronizerOneShotTb is

   -- Constants
   constant CLK_PERIOD_C : time := 10 ns;
   constant TPD_C        : time := CLK_PERIOD_C/4;

   -- Signals
   signal clk,
      rst,
      fastClk,
      fastRst,
      done,
      trigIn,
      trigOut : sl;

begin

   -- Generate clocks and resets
   ClkRst_Slow : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 250 ns)   -- Hold reset for this long)
      port map (
         clkP => clk,
         clkN => open,
         rst  => rst,
         rstL => open); 

   ClkRst_Fast : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 4 ns,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 500 ns)   -- Hold reset for this long)
      port map (
         clkP => fastClk,
         clkN => open,
         rst  => fastRst,
         rstL => open);          

   -- SynchronizerOneShot (VHDL module to be tested)
   SynchronizerOneShot_Inst : entity work.SynchronizerOneShot
      generic map (
         TPD_G => TPD_C)
      port map (
         clk     => clk,
         rst     => rst,
         dataIn  => trigIn,
         dataOut => trigOut);

   process(fastClk)
   begin
      if rising_edge(fastClk) then
         trigIn <= '0' after 1 ns;
         if fastRst = '1' then
            done <= '0' after 1 ns;
         elsif done = '0' then
            done   <= '1' after 1 ns;
            trigIn <= '1' after 1 ns;
         end if;
      end if;
   end process;
   
end testbed;
