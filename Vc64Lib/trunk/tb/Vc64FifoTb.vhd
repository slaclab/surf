-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Vc64FifoTb.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-07
-- Last update: 2014-04-08
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the Vc64FifoTb module
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.Vc64Pkg.all;

entity Vc64FifoTb is end Vc64FifoTb;

architecture testbed of Vc64FifoTb is

   -- Constants
   constant WR_CLK_PERIOD_C : time := 10 ns;
   constant RD_CLK_PERIOD_C : time := 3.14 ns;  -- Test parameter
   constant TPD_C           : time := 1 ns;

   constant CONFIG_TEST_C      : natural := 0;
   constant CONFIG_TEST_SIZE_C : natural := (6-1);
   
   constant GEN_SYNC_FIFO_C : BooleanArray(0 to CONFIG_TEST_SIZE_C) := (
      -- PIPE_STAGES_C = 0
      false,
      true,
      -- PIPE_STAGES_C = 1
      false,
      true,
      -- PIPE_STAGES_C = 2
      false,
      true);      

   constant PIPE_STAGES_C : IntegerArray(0 to CONFIG_TEST_SIZE_C) := (
      -- PIPE_STAGES_C = 0
      0,
      0,
      -- PIPE_STAGES_C = 1
      1,
      1,
      -- PIPE_STAGES_C = 2
      2,
      2);     

   constant LAST_DATA_C       : slv(63 downto 0) := toSlv(4096, 64);
   constant READ_BUSY_THRES_C : slv(3 downto 0)  := toSlv(7, 4);

   -- Signals
   signal clk,
      rst,
      vcRxClk,
      vcRxRst : sl;
   signal wrDone,
      rdDone,
      rdError : slv(0 to CONFIG_TEST_SIZE_C);

   signal simulationPassed,
      simulationFailed : sl := '0';

begin

   simulationPassed <= uAnd(wrDone) and uAnd(rdDone) and not uOr(rdError);
   simulationFailed <= uAnd(wrDone) and uAnd(rdDone) and uOr(rdError);

   process(simulationFailed, simulationPassed)
   begin
      if simulationPassed = '1' then
         assert false
            report "Simulation Passed!" severity failure;
      elsif simulationFailed = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;
   end process;

   -- Generate clocks and resets
   ClkRst_Write : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => WR_CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 500 ns)   -- Hold reset for this long)
      port map (
         clkP => vcRxClk,
         clkN => open,
         rst  => vcRxRst,
         rstL => open); 

   ClkRst_Read : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => RD_CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 500 ns)   -- Hold reset for this long)
      port map (
         clkP => clk,
         clkN => open,
         rst  => rst,
         rstL => open); 

   GEN_TEST_MODULES :
   for i in 0 to CONFIG_TEST_SIZE_C generate

      Vc64FifoTbSubModule_Inst : entity work.Vc64FifoTbSubModule
         generic map (
            TPD_G             => TPD_C,
            GEN_SYNC_FIFO_G   => GEN_SYNC_FIFO_C(i),
            PIPE_STAGES_G     => PIPE_STAGES_C(i),
            LAST_DATA_G       => LAST_DATA_C,
            READ_BUSY_THRES_G => READ_BUSY_THRES_C)
         port map (
            -- Status
            wrDone  => wrDone(i),
            rdDone  => rdDone(i),
            rdError => rdError(i),
            -- Clocks and Resets
            vcRxClk => vcRxClk,
            vcRxRst => vcRxRst,
            clk     => clk,
            rst     => rst);  
   end generate GEN_TEST_MODULES;

end testbed;
