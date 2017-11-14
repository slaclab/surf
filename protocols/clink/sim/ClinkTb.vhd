-------------------------------------------------------------------------------
-- File       : ClinkTb.vhd
-- Created    : 2017-11-13
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for Clink
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------

library ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
library unisim;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity ClinkTb is end ClinkTb;

-- Define architecture
architecture test of ClinkTb is

   constant CLK_PERIOD_C   : time    := 1.681 ns;
   constant TPD_G          : time    := 1 ns;

   signal fastClk       : sl;
   signal fastRst       : sl;
   signal din           : slv(3 downto 0);
   signal clk           : sl;
   signal clinkLocked   : sl;
   signal clinkParData  : slv(27 downto 0);
   signal cnt           : integer;

   constant clkShift   : slv(6 downto 0) := "1100011";
   constant dinShiftA  : slv(6 downto 0) := "0101010"; -- 1A
   constant dinShiftB  : slv(6 downto 0) := "1001011"; -- 2B
   constant dinShiftC  : slv(6 downto 0) := "1101100"; -- 3C
   constant dinShiftD  : slv(6 downto 0) := "0001101"; -- 0D

begin

   -----------------------------
   -- Generate a Clock and Reset
   -----------------------------
   U_ClkRst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => fastClk,
         clkN => open,
         rst  => fastRst,
         rstL => open);  

   -----------------------------
   -- Data Generation
   -----------------------------
   process (fastRst, fastClk)
   begin
      if rising_edge(fastClk) then
         if fastRst = '1' then
            din <= (others=>'0') after TPD_G;
            clk <= (others=>'0') after TPD_G;
            cnt <= 0             after TPD_G;
         else

            if cnt = 6 then
               cnt <= 0 after TPD_G;
            else
               cnt <= cnt + 1 after TPD_G;
            end if;

            clk    <= clkShift(cnt);
            din(0) <= dinShiftA(cnt);
            din(1) <= dinShiftB(cnt);
            din(2) <= dinShiftC(cnt);
            din(3) <= dinShiftD(cnt);

         end if;
      end if;
   end process;


   U_ClinkGroup: entity work.ClinkGroup 
      generic map ( TPD_G => TPD_G )
      port map (
         clinkClkIn      => fastClk,
         resetIn         => fastRst,
         clinkClk        => open,
         clinkRst        => open,
         clinkSerData    => din,
         clinkLocked     => clinkLocked,
         clinkParData    => clinkParData);

end test;

