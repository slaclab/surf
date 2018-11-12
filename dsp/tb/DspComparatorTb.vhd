-------------------------------------------------------------------------------
-- File       : DspComparatorTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for the DspComparator module
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

entity DspComparatorTb is end DspComparatorTb;

architecture testbed of DspComparatorTb is

   constant TPD_G : time := 2.5 ns;

   signal clk  : sl              := '0';
   signal rst  : sl              := '0';
   signal ain  : slv(7 downto 0) := x"00";
   signal bin  : slv(7 downto 0) := x"00";
   signal eq   : sl              := '0';
   signal gt   : sl              := '0';
   signal gtEq : sl              := '0';
   signal ls   : sl              := '0';
   signal lsEq : sl              := '0';

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

   process(clk)
   begin
      if rising_edge(clk) then
         if rst = '1' then
            ain <= x"00" after TPD_G;
            bin <= x"80" after TPD_G;
         else
            ain <= ain + 1 after TPD_G;
         end if;
      end if;
   end process;

   U_DspComparator : entity work.DspComparator
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 8)
      port map (
         clk  => clk,
         ain  => ain,
         bin  => bin,
         eq   => eq,
         gt   => gt,
         gtEq => gtEq,
         ls   => ls,
         lsEq => lsEq);

end testbed;
