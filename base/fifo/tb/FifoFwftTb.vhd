-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the FifoFwft module
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


library surf;
use surf.StdRtlPkg.all;

entity FifoFwftTb is end FifoFwftTb;

architecture testbed of FifoFwftTb is

   -- Constants
   constant TPD_C              : time := 1 ns;
   constant WRITE_CLK_PERIOD_C : time := 5 ns;
   constant READ_CLK_PERIOD_C  : time := 4 ns;

   constant CONFIG_TEST_SIZE_C : natural := 15;

   type SimConfigType is record
      PIPE_STAGES_G   : natural;
      GEN_SYNC_FIFO_G : boolean;
      MEMORY_TYPE_G   : string;
   end record;
   type SimConfigArray is array (natural range <>) of SimConfigType;
   constant SIM_CONFIG_C : SimConfigArray(0 to 15) := (
      0                  => (
         PIPE_STAGES_G   => 0,
         GEN_SYNC_FIFO_G => false,
         MEMORY_TYPE_G   => "distributed"),
      1                  => (
         PIPE_STAGES_G   => 0,
         GEN_SYNC_FIFO_G => false,
         MEMORY_TYPE_G   => "distributed"),
      2                  => (
         PIPE_STAGES_G   => 0,
         GEN_SYNC_FIFO_G => false,
         MEMORY_TYPE_G   => "block"),
      3                  => (
         PIPE_STAGES_G   => 0,
         GEN_SYNC_FIFO_G => false,
         MEMORY_TYPE_G   => "block"),
      4                  => (
         PIPE_STAGES_G   => 0,
         GEN_SYNC_FIFO_G => true,
         MEMORY_TYPE_G   => "distributed"),
      5                  => (
         PIPE_STAGES_G   => 0,
         GEN_SYNC_FIFO_G => true,
         MEMORY_TYPE_G   => "distributed"),
      6                  => (
         PIPE_STAGES_G   => 0,
         GEN_SYNC_FIFO_G => true,
         MEMORY_TYPE_G   => "block"),
      7                  => (
         PIPE_STAGES_G   => 0,
         GEN_SYNC_FIFO_G => true,
         MEMORY_TYPE_G   => "block"),
      8                  => (
         PIPE_STAGES_G   => 1,
         GEN_SYNC_FIFO_G => false,
         MEMORY_TYPE_G   => "distributed"),
      9                  => (
         PIPE_STAGES_G   => 1,
         GEN_SYNC_FIFO_G => false,
         MEMORY_TYPE_G   => "distributed"),
      10                 => (
         PIPE_STAGES_G   => 1,
         GEN_SYNC_FIFO_G => false,
         MEMORY_TYPE_G   => "block"),
      11                 => (
         PIPE_STAGES_G   => 1,
         GEN_SYNC_FIFO_G => false,
         MEMORY_TYPE_G   => "block"),
      12                 => (
         PIPE_STAGES_G   => 1,
         GEN_SYNC_FIFO_G => true,
         MEMORY_TYPE_G   => "distributed"),
      13                 => (
         PIPE_STAGES_G   => 1,
         GEN_SYNC_FIFO_G => true,
         MEMORY_TYPE_G   => "distributed"),
      14                 => (
         PIPE_STAGES_G   => 1,
         GEN_SYNC_FIFO_G => true,
         MEMORY_TYPE_G   => "block"),
      15                 => (
         PIPE_STAGES_G   => 1,
         GEN_SYNC_FIFO_G => true,
         MEMORY_TYPE_G   => "block"));

   -- Signals
   signal wrClk,
      rst,
      rdClk : sl;

   signal failed,
      passed,
      subRdClk : slv(0 to CONFIG_TEST_SIZE_C) := (others => '0');

begin

   process(failed, passed)
   begin
      if uOr(passed) = '1' then
         assert false
            report "Simulation Passed!" severity failure;
      elsif uOr(failed) = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;
   end process;

   -- Generate clocks and resets
   ClkRst_Write : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => WRITE_CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => wrClk,
         clkN => open,
         rst  => rst,
         rstL => open);

   ClkRst_Read : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => READ_CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => rdClk,
         clkN => open,
         rst  => open,
         rstL => open);



   GEN_TEST_MODULES :
   for i in 0 to CONFIG_TEST_SIZE_C generate
      subRdClk(i) <= ite(SIM_CONFIG_C(i).GEN_SYNC_FIFO_G, wrClk, rdClk);
      FifoTbSubModule_Inst : entity surf.FifoTbSubModule
         generic map (
            TPD_G           => TPD_C,
            GEN_SYNC_FIFO_G => SIM_CONFIG_C(i).GEN_SYNC_FIFO_G,
            MEMORY_TYPE_G   => SIM_CONFIG_C(i).MEMORY_TYPE_G,
            PIPE_STAGES_G   => SIM_CONFIG_C(i).PIPE_STAGES_G)
         port map (
            rst    => rst,
            wrClk  => wrClk,
            rdClk  => subRdClk(i),
            passed => passed(i),
            failed => failed(i));

   end generate GEN_TEST_MODULES;

end testbed;
