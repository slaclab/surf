-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for the DspAddSub module
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

entity DspAddSubTb is end DspAddSubTb;

architecture testbed of DspAddSubTb is

   constant TPD_G : time := 2.5 ns;

   signal clk : sl              := '0';
   signal rst : sl              := '0';
   signal ain : slv(3 downto 0) := x"0";
   signal bin : slv(3 downto 0) := x"0";
   signal add : slv(3 downto 0) := x"0";
   signal sub : slv(3 downto 0) := x"0";

begin

   U_ClkRst : entity surf.ClkRst
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
            ain <= x"0" after TPD_G;
            bin <= x"0" after TPD_G;
         else
            if ain = x"F" then
               bin <= bin + 1 after TPD_G;
            end if;
            ain <= ain + 1 after TPD_G;
         end if;
      end if;
   end process;

   U_Add : entity surf.DspAddSub
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 4)
      port map (
         clk  => clk,
         ain  => ain,
         bin  => bin,
         add  => '1',
         pOut => add);

   U_Sub : entity surf.DspAddSub
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 4)
      port map (
         clk  => clk,
         ain  => ain,
         bin  => bin,
         add  => '0',
         pOut => sub);

end testbed;
