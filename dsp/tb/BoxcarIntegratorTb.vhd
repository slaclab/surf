-------------------------------------------------------------------------------
-- File       : BoxcarIntegratorTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for the BoxcarIntegrator module
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

entity BoxcarIntegratorTb is end BoxcarIntegratorTb;

architecture testbed of BoxcarIntegratorTb is

   constant TPD_G : time := 2.5 ns;

   signal clk : sl := '0';
   signal rst : sl := '0';

   signal ibReady  : sl;
   signal intCount : slv(10 downto 0);
   signal obValid  : sl;
   signal obPeriod : sl;
   signal obData   : slv(15 downto 0);

begin

   U_ClkRst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 10 ns,
         RST_START_DELAY_G => 1 ns,
         RST_HOLD_TIME_G   => 1 us)
      port map (
         clkP => clk,
         clkN => open,
         rst  => rst,
         rstL => open);

   process begin
      intCount = "0000000000";
      wait for 100 us;
      intCount = "0000001000"; -- 8
      wait for 100 us;
      intCount = "0000000100"; -- 4
      wait for 100 us;
   end process;

   U_BoxcarIntegrator : entity work.BoxcarIntegrator
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 16,
         ADDR_WIDTH_G => 10)
      port map (
         clk      => clk,
         rst      => rst,
         intCount => intCount,
         ibValid  => '1',
         ibReady  => ibReady,
         ibData   => x"000A",
         obValid  => obValid,
         obData   => obData,
         obReady  => '1',
         obPeriod => obPeriod);

end testbed;
