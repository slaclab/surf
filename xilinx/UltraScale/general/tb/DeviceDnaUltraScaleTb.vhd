-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the DeviceDnaUltraScale
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
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.SsiPkg.all;
use surf.RssiPkg.all;

entity DeviceDnaUltraScaleTb is

end DeviceDnaUltraScaleTb;

architecture testbed of DeviceDnaUltraScaleTb is

   constant CLK_PERIOD_C    : time             := 10 ns;  -- 1 us makes it easy to count clock cycles in sim GUI
   constant TPD_G           : time             := CLK_PERIOD_C/4;
   constant SIM_DNA_VALUE_C : slv(95 downto 0) := x"400200000139CA294D9041C5";

   signal dnaValue : slv(95 downto 0);
   signal dnaValid : sl;

   signal clk : sl := '0';
   signal rst : sl := '1';

   signal passed : sl := '0';
   signal failed : sl := '0';

begin

   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1 us)     -- Hold reset for this long)
      port map (
         clkP => clk,
         rst  => rst);

   U_DeviceDnaUltraScale : entity surf.DeviceDnaUltraScale
      generic map (
         TPD_G           => TPD_G,
         SIM_DNA_VALUE_G => SIM_DNA_VALUE_C)
      port map (
         clk      => clk,
         rst      => rst,
         dnaValue => dnaValue,
         dnaValid => dnaValid);

   process(clk)
   begin
      if rising_edge(clk) then
         if (dnaValid = '1') then
            if (dnaValue = SIM_DNA_VALUE_C) then
               passed <= '1' after TPD_G;
            else
               failed <= '1' after TPD_G;
            end if;
         end if;
      end if;
   end process;

   process(failed, passed)
   begin
      if passed = '1' then
         assert false
            report "Simulation Passed!" severity failure;
      elsif failed = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;
   end process;

end testbed;
