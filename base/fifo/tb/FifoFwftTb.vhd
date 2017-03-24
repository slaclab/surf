-------------------------------------------------------------------------------
-- File       : FifoFwftTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-05-05
-- Last update: 2014-05-14
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

use work.StdRtlPkg.all;

entity FifoFwftTb is end FifoFwftTb;

architecture testbed of FifoFwftTb is

   -- Constants
   constant TPD_C              : time := 1 ns;
   constant WRITE_CLK_PERIOD_C : time := 5 ns;
   constant READ_CLK_PERIOD_C  : time := 4 ns;

   constant CONFIG_TEST_SIZE_C : natural := 15;

   type SimConfigType is record
      GEN_SYNC_FIFO_G : boolean;
      BRAM_EN_G       : boolean;
      USE_BUILT_IN_G  : boolean;
      PIPE_STAGES_G   : natural;
   end record;
   type SimConfigArray is array (natural range <>) of SimConfigType;
   constant SIM_CONFIG_C : SimConfigArray(0 to 15) := (
      0                  => (
         PIPE_STAGES_G   => 0,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => false,
         USE_BUILT_IN_G  => false),
      1                  => (
         PIPE_STAGES_G   => 0,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => false,
         USE_BUILT_IN_G  => true),
      2                  => (
         PIPE_STAGES_G   => 0,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => true,
         USE_BUILT_IN_G  => false),
      3                  => (
         PIPE_STAGES_G   => 0,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => true,
         USE_BUILT_IN_G  => true),
      4                  => (
         PIPE_STAGES_G   => 0,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => false,
         USE_BUILT_IN_G  => false),
      5                  => (
         PIPE_STAGES_G   => 0,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => false,
         USE_BUILT_IN_G  => true),
      6                  => (
         PIPE_STAGES_G   => 0,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => true,
         USE_BUILT_IN_G  => false),
      7                  => (
         PIPE_STAGES_G   => 0,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => true,
         USE_BUILT_IN_G  => true),
      8                  => (
         PIPE_STAGES_G   => 1,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => false,
         USE_BUILT_IN_G  => false),
      9                  => (
         PIPE_STAGES_G   => 1,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => false,
         USE_BUILT_IN_G  => true),
      10                 => (
         PIPE_STAGES_G   => 1,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => true,
         USE_BUILT_IN_G  => false),
      11                 => (
         PIPE_STAGES_G   => 1,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => true,
         USE_BUILT_IN_G  => true),
      12                 => (
         PIPE_STAGES_G   => 1,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => false,
         USE_BUILT_IN_G  => false),
      13                 => (
         PIPE_STAGES_G   => 1,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => false,
         USE_BUILT_IN_G  => true),
      14                 => (
         PIPE_STAGES_G   => 1,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => true,
         USE_BUILT_IN_G  => false),
      15                 => (
         PIPE_STAGES_G   => 1,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => true,
         USE_BUILT_IN_G  => true));          

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
   ClkRst_Write : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => WRITE_CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => wrClk,
         clkN => open,
         rst  => rst,
         rstL => open); 

   ClkRst_Read : entity work.ClkRst
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
      FifoTbSubModule_Inst : entity work.FifoTbSubModule
         generic map (
            TPD_G           => TPD_C,
            GEN_SYNC_FIFO_G => SIM_CONFIG_C(i).GEN_SYNC_FIFO_G,
            BRAM_EN_G       => SIM_CONFIG_C(i).BRAM_EN_G,
            USE_BUILT_IN_G  => SIM_CONFIG_C(i).USE_BUILT_IN_G,
            PIPE_STAGES_G   => SIM_CONFIG_C(i).PIPE_STAGES_G)
         port map (
            rst    => rst,
            wrClk  => wrClk,
            rdClk  => subRdClk(i),
            passed => passed(i),
            failed => failed(i));               

   end generate GEN_TEST_MODULES;

end testbed;
