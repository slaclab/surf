-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for the BoxcarFilter module
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

entity BoxcarFilterTb is end BoxcarFilterTb;

architecture testbed of BoxcarFilterTb is

   constant TPD_G : time := 2.5 ns;

   type RegType is record
      ibValid : sl;
      ibData  : slv(15 downto 0);
   end record RegType;
   constant REG_INIT_C : RegType := (
      ibValid => '0',
      ibData  => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal clk : sl := '0';
   signal rst : sl := '0';

   signal obValid : sl               := '0';
   signal obData  : slv(15 downto 0) := x"0000";

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

   comb : process (r, rst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      v.ibValid := '1';

      v.ibData := r.ibData + 1;

      -- Uncomment to test ramping value
      if (v.ibData = 1025) then
         v.ibData := toSlv(1, 16);
      end if;

      -- -- Uncomment to test min accumulator value
      -- v.ibData := (others => '0');

      -- -- Uncomment to test midpoint accumulator value
      -- v.ibData := x"8000";

      -- -- Uncomment to test max accumulator value
      -- v.ibData := (others => '1');

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_BoxcarFilter : entity surf.BoxcarFilter
      generic map (
         TPD_G        => TPD_G,
         SIGNED_G     => false,
         DATA_WIDTH_G => 16,
         ADDR_WIDTH_G => 10)
      port map (
         clk     => clk,
         rst     => rst,
         -- Inbound Interface
         ibValid => r.ibValid,
         ibData  => r.ibData,
         -- Outbound Interface
         obValid => obValid,
         obData  => obData);

end testbed;
