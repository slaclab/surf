-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Vivado xsim DPI-C duplicate-port rejection testbench
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Test methodology:
-- - Instantiate two Stream xsim/DPI models with the same endpoint pair.
-- - Release reset and require the process-wide port-pair guard to reject the
--   second instance before the bounded testbench fallback fires.
-- This proves duplicate-port detection across independently created leaves.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity RogueXsimDuplicatePortTb is
end entity RogueXsimDuplicatePortTb;

architecture test of RogueXsimDuplicatePortTb is

   signal clock : std_logic := '0';
   signal reset : std_logic := '1';

begin

   clock <= not clock after 5 ns;

   GEN_STREAM : for i in 0 to 1 generate
      U_STREAM : entity work.RogueTcpStream
         port map (
            clock      => clock,  -- [in]
            reset      => reset,  -- [in]
            portNum    => std_logic_vector(to_unsigned(19720, 16)),  -- [in]
            ssi        => '0',  -- [in]
            obValid    => open,  -- [out]
            obReady    => '1',  -- [in]
            obData     => open,  -- [out]
            obUser     => open,  -- [out]
            obKeep     => open,  -- [out]
            obLast     => open,  -- [out]
            ibValid    => '0',  -- [in]
            ibReady    => open,  -- [out]
            ibData     => (others => '0'),  -- [in]
            ibUser     => (others => '0'),  -- [in]
            ibKeep     => (others => '0'),  -- [in]
            ibLast     => '0');  -- [in]
   end generate GEN_STREAM;

   test : process is
   begin
      for i in 0 to 2 loop
         wait until rising_edge(clock);
      end loop;
      reset <= '0';
      for i in 0 to 10 loop
         wait until rising_edge(clock);
      end loop;
      assert false report "Duplicate xsim port pair was not rejected" severity failure;
      wait;
   end process test;

end architecture test;
