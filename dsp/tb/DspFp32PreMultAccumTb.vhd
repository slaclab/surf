-------------------------------------------------------------------------------
-- File       : DspFp32PreMultAccumTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-09-30
-- Last update: 2017-09-30
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for the DspFp32PreMultAccum module
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

entity DspFp32PreMultAccumTb is end DspFp32PreMultAccumTb;

architecture testbed of DspFp32PreMultAccumTb is

   constant TPD_G : time := 2.5 ns;

   signal clk : sl := '0';
   signal rst : sl := '0';

   signal ain : float32;
   signal bin : float32;

   signal cntValid : natural range 0 to 3  := 0;
   signal cntLoad  : natural range 0 to 63 := 0;
   signal load     : sl                    := '0';
   signal ibValid  : sl                    := '0';
   signal obValid  : sl                    := '0';
   signal result   : slv(31 downto 0)      := (others => '0');

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
         ibValid <= '0' after TPD_G;
         load    <= '0' after TPD_G;
         if rst = '1' then
            cntValid <= 0 after TPD_G;
            cntLoad  <= 0 after TPD_G;
         else
            if cntValid = 3 then
               cntValid <= 0   after TPD_G;
               ibValid  <= '1' after TPD_G;
               if cntLoad = 63 then
                  cntLoad <= 0   after TPD_G;
                  load    <= '1' after TPD_G;
               else
                  cntLoad <= cntLoad + 1;
               end if;
            else
               cntValid <= cntValid + 1;
            end if;
         end if;
      end if;
   end process;

   -------------------------------------------
   -- Equation: p = sum(+/-(a x b)[i])
   -------------------------------------------
   U_DspCore : entity work.DspFp32PreMultAccum
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => clk,
         -- Inbound Interface
         ibValid => ibValid,
         ain     => std_logic_vector(ain),
         bin     => std_logic_vector(bin),
         load    => load,
         -- Outbound Interface
         obValid => obValid,
         pOut    => result);

   ain <= to_float(1.0);
   bin <= to_float(1.0);

end testbed;
