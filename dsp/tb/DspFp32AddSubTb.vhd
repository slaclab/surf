-------------------------------------------------------------------------------
-- File       : DspFp32AddSubTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-09-07
-- Last update: 2017-09-30
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

library ieee_proposed;
use ieee_proposed.fixed_float_types.all;
use ieee_proposed.float_pkg.all;

use work.StdRtlPkg.all;
use work.DspPkg.all;

entity DspFp32AddSubTb is end DspFp32AddSubTb;

architecture testbed of DspFp32AddSubTb is

   constant TPD_G : time := 2.5 ns;

   signal clk : sl := '0';
   signal rst : sl := '0';

   signal cnt : float32          := FP32_ZERO_C;
   signal add : slv(31 downto 0) := (others => '0');
   signal sub : slv(31 downto 0) := (others => '0');

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
            cnt <= FP32_ZERO_C after TPD_G;
         else
            cnt <= cnt + 0.5 after TPD_G;
         end if;
      end if;
   end process;

   U_Add : entity work.DspFp32AddSub
      generic map (
         TPD_G => TPD_G)
      port map (
         clk  => clk,
         ain  => (others => '0'),
         bin  => std_logic_vector(cnt),
         add  => '1',
         pOut => add);

   U_Sub : entity work.DspFp32AddSub
      generic map (
         TPD_G => TPD_G)
      port map (
         clk  => clk,
         ain  => (others => '0'),
         bin  => std_logic_vector(cnt),
         add  => '0',
         pOut => sub);

end testbed;
