-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Multi-instance Vivado xsim DPI-C live-traffic test harness
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
-- - Instantiate four Stream (and later two Memory, two SideBand) xsim/DPI
--   models, each on its own endpoint pair, and exchange a per-instance tagged
--   traffic family with a dedicated external peer.
-- - Hold off all outbound traffic for a fixed settle delay after reset so the
--   peers are connected and draining first (accepted transport contract; no
--   readiness handshake).
-- - Each Stream instance drives inbound beats tagged 0x80+i and checks the
--   outbound byte equals its peer's 0x10+i.
-- - Report the success banner only after all instances pass; $fatal on any
--   wrong/missing tag. $fatal exits 0 under xsim -R, so pytest judges success
--   by the banner plus per-peer exit codes/JSON, not the xsim return code.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity RogueXsimTrafficTb is
end entity RogueXsimTrafficTb;

architecture test of RogueXsimTrafficTb is

   constant CLK_HALF_C     : time    := 5 ns;
   constant SETTLE_EDGES_C : natural := 2000;   -- tuned later; generous margin
   constant WAIT_EDGES_C   : natural := 20000;  -- bounded per-item inbound wait

   signal clock : std_logic := '0';
   signal reset : std_logic := '1';

   type slv32_array is array (natural range <>) of std_logic_vector(31 downto 0);
   type slv8_array  is array (natural range <>) of std_logic_vector(7 downto 0);

   signal sObValid : std_logic_vector(3 downto 0);
   signal sObData  : slv32_array(3 downto 0);
   signal sIbValid : std_logic_vector(3 downto 0) := (others => '0');
   signal sIbData  : slv32_array(3 downto 0)      := (others => (others => '0'));
   signal sIbKeep  : slv8_array(3 downto 0)       := (others => (others => '0'));
   signal sIbLast  : std_logic_vector(3 downto 0) := (others => '0');

   signal streamDone : std_logic_vector(3 downto 0) := (others => '0');

begin

   clock <= not clock after CLK_HALF_C;

   GEN_STREAM : for i in 0 to 3 generate
      U_STREAM : entity work.RogueTcpStream
         port map (
            clock      => clock,
            reset      => reset,
            portNum    => std_logic_vector(to_unsigned(19740 + (2*i), 16)),
            ssi        => '0',
            obValid    => sObValid(i),
            obReady    => '1',
            obDataLow  => sObData(i),
            obDataHigh => open,
            obUserLow  => open,
            obUserHigh => open,
            obKeep     => open,
            obLast     => open,
            ibValid    => sIbValid(i),
            ibReady    => open,
            ibDataLow  => sIbData(i),
            ibDataHigh => (others => '0'),
            ibUserLow  => (others => '0'),
            ibUserHigh => (others => '0'),
            ibKeep     => sIbKeep(i),
            ibLast     => sIbLast(i));
   end generate GEN_STREAM;

   GEN_STREAM_DRV : for i in 0 to 3 generate
      -- One process per instance handles both directions concurrently: it
      -- counts outbound (ob) frames on EVERY edge from reset deassert, and
      -- after a fixed settle drives three inbound (ib) frames. Outbound must
      -- be watched continuously because obReady is hardwired '1', so the
      -- model presents each peer-pushed frame for a single edge as soon as it
      -- arrives (well before the inbound-drive phase); a counter that only
      -- looked after the settle would miss those early frames. streamDone is
      -- asserted only once BOTH the three inbound frames have been driven and
      -- three outbound frames have been counted, so the banner cannot stop
      -- the sim before every peer has exchanged its full tagged family.
      drv : process is
         variable expByte : std_logic_vector(7 downto 0);
         variable tagByte : std_logic_vector(7 downto 0);
         variable rxCount : natural := 0;
         variable waited  : natural := 0;
         variable phase   : natural := 0;  -- edges elapsed during settle
         variable frame   : natural := 0;  -- inbound frames driven so far
         variable step    : natural := 0;  -- sub-step within one inbound frame
      begin
         wait until reset = '0';
         tagByte := std_logic_vector(to_unsigned((16#80# + i), 8));
         expByte := std_logic_vector(to_unsigned((16#10# + i), 8));

         loop
            wait until rising_edge(clock);
            waited := waited + 1;

            -- Outbound: count each single-beat frame the model presents.
            if sObValid(i) = '1' then
               assert sObData(i)(7 downto 0) = expByte
                  report "Stream " & integer'image(i) & ": wrong outbound tag" severity failure;
               rxCount := rxCount + 1;
            end if;

            -- Inbound: after the settle, push three frames, one every few
            -- edges, deasserting valid the edge after each single beat.
            if phase < SETTLE_EDGES_C then
               phase := phase + 1;
            elsif frame < 3 then
               if step = 0 then
                  sIbData(i)  <= tagByte & tagByte & tagByte & tagByte;
                  sIbKeep(i)  <= x"0F";
                  sIbLast(i)  <= '1';
                  sIbValid(i) <= '1';
                  step        := 1;
               elsif step = 1 then
                  sIbValid(i) <= '0';
                  sIbLast(i)  <= '0';
                  step        := 2;
               elsif step < 5 then
                  step := step + 1;
               else
                  step  := 0;
                  frame := frame + 1;
               end if;
            end if;

            exit when (frame = 3) and (rxCount >= 3);

            assert waited < WAIT_EDGES_C
               report "Stream " & integer'image(i) & ": timed out exchanging traffic" severity failure;
         end loop;

         streamDone(i) <= '1';
         wait;
      end process drv;
   end generate GEN_STREAM_DRV;

   banner : process is
   begin
      for e in 0 to 2 loop
         wait until rising_edge(clock);
      end loop;
      reset <= '0';
      wait until streamDone = "1111";
      report "Rogue xsim traffic test passed" severity note;
      stop;
      wait;
   end process banner;

end architecture test;
