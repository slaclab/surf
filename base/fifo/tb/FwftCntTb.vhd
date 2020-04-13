-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the FIFO FSM write/read counts
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

entity FwftCntTb is end FwftCntTb;

architecture testbed of FwftCntTb is

   constant CLK_PERIOD_G : time := 10 ns;
   constant TPD_G        : time := CLK_PERIOD_G/4;

   constant CONFIG_TEST_SIZE_C : natural := 2**3; -- 3 parameters, 2 possible value per parameter

   signal clk : sl := '0';
   signal rst : sl := '1';

   signal passedVec : slv(CONFIG_TEST_SIZE_C-1 downto 0) := (others => '0');
   signal failedVec : slv(CONFIG_TEST_SIZE_C-1 downto 0) := (others => '0');

   signal passed : sl := '0';
   signal failed : sl := '0';

begin

   -- Generate clocks and resets
   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_G,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => clk,
         rst  => rst);

   LOOP_I : for i in 0 to 1 generate
      LOOP_J : for j in 0 to 1 generate
         LOOP_K : for k in 0 to 1 generate
            U_SubModule : entity surf.FwftCntTbSubModule
               generic map (
                  TPD_G           => TPD_G,
                  GEN_SYNC_FIFO_G => ite(i = 0, true, false),
                  SYNTH_MODE_G    => ite(j = 0, "inferred", "xpm"),
                  MEMORY_TYPE_G   => ite(k = 0, "block", "distributed"))
               port map (
                  clk    => clk,
                  rst    => rst,
                  passed => passedVec(4*i+2*j+1*k),
                  failed => failedVec(4*i+2*j+1*k));
         end generate LOOP_K;
      end generate LOOP_J;
   end generate LOOP_I;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         passed <= uAnd(passedVec) after TPD_G;
         failed <= uOR(failedVec)  after TPD_G;
      end if;
   end process seq;

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
