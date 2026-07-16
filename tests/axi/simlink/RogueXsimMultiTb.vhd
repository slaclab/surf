-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Multi-instance Vivado xsim DPI-C test harness
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
-- - Instantiate four Stream and two each Memory and SideBand xsim/DPI models.
-- - Release reset with a unique endpoint pair per model, pulse reset again,
--   and run bounded clocks.
-- - A second top deliberately gives two Stream instances the same endpoint.
-- This proves per-leaf chandle creation, mixed-language DPI binding, distinct
-- socket ownership, normal final cleanup, and duplicate-port failure.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity RogueXsimMultiTb is
end entity RogueXsimMultiTb;

architecture test of RogueXsimMultiTb is

   signal clock : std_logic := '0';
   signal reset : std_logic := '1';

begin

   clock <= not clock after 5 ns;

   GEN_STREAM : for i in 0 to 3 generate
      U_STREAM : entity work.RogueTcpStream
         port map (
            clock      => clock,  -- [in]
            reset      => reset,  -- [in]
            portNum    => std_logic_vector(to_unsigned(19700+(2*i), 16)),  -- [in]
            ssi        => '0',  -- [in]
            obValid    => open,  -- [out]
            obReady    => '1',  -- [in]
            obDataLow  => open,  -- [out]
            obDataHigh => open,  -- [out]
            obUserLow  => open,  -- [out]
            obUserHigh => open,  -- [out]
            obKeep     => open,  -- [out]
            obLast     => open,  -- [out]
            ibValid    => '0',  -- [in]
            ibReady    => open,  -- [out]
            ibDataLow  => (others => '0'),  -- [in]
            ibDataHigh => (others => '0'),  -- [in]
            ibUserLow  => (others => '0'),  -- [in]
            ibUserHigh => (others => '0'),  -- [in]
            ibKeep     => (others => '0'),  -- [in]
            ibLast     => '0');  -- [in]
   end generate GEN_STREAM;

   GEN_MEMORY : for i in 0 to 1 generate
      U_MEMORY : entity work.RogueTcpMemory
         port map (
            clock   => clock,  -- [in]
            reset   => reset,  -- [in]
            portNum => std_logic_vector(to_unsigned(19708+(2*i), 16)),  -- [in]
            araddr  => open,  -- [out]
            arprot  => open,  -- [out]
            arvalid => open,  -- [out]
            rready  => open,  -- [out]
            arready => '0',  -- [in]
            rdata   => (others => '0'),  -- [in]
            rresp   => (others => '0'),  -- [in]
            rvalid  => '0',  -- [in]
            awaddr  => open,  -- [out]
            awprot  => open,  -- [out]
            awvalid => open,  -- [out]
            wdata   => open,  -- [out]
            wstrb   => open,  -- [out]
            wvalid  => open,  -- [out]
            bready  => open,  -- [out]
            awready => '0',  -- [in]
            wready  => '0',  -- [in]
            bresp   => (others => '0'),  -- [in]
            bvalid  => '0');  -- [in]
   end generate GEN_MEMORY;

   GEN_SIDEBAND : for i in 0 to 1 generate
      U_SIDEBAND : entity work.RogueSideBand
         port map (
            clock      => clock,  -- [in]
            reset      => reset,  -- [in]
            portNum    => std_logic_vector(to_unsigned(19712+(2*i), 16)),  -- [in]
            txOpCode   => (others => '0'),  -- [in]
            txOpCodeEn => '0',  -- [in]
            txRemData  => (others => '0'),  -- [in]
            rxOpCode   => open,  -- [out]
            rxOpCodeEn => open,  -- [out]
            rxRemData  => open);  -- [out]
   end generate GEN_SIDEBAND;

   test : process is
   begin
      for i in 0 to 2 loop
         wait until rising_edge(clock);
      end loop;
      reset <= '0';
      for i in 0 to 50 loop
         wait until rising_edge(clock);
      end loop;
      reset <= '1';
      for i in 0 to 2 loop
         wait until rising_edge(clock);
      end loop;
      reset <= '0';
      for i in 0 to 10 loop
         wait until rising_edge(clock);
      end loop;
      report "Rogue xsim multi-instance smoke test passed" severity note;
      stop;
      wait;
   end process test;

end architecture test;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

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
            obDataLow  => open,  -- [out]
            obDataHigh => open,  -- [out]
            obUserLow  => open,  -- [out]
            obUserHigh => open,  -- [out]
            obKeep     => open,  -- [out]
            obLast     => open,  -- [out]
            ibValid    => '0',  -- [in]
            ibReady    => open,  -- [out]
            ibDataLow  => (others => '0'),  -- [in]
            ibDataHigh => (others => '0'),  -- [in]
            ibUserLow  => (others => '0'),  -- [in]
            ibUserHigh => (others => '0'),  -- [in]
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
