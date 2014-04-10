-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Vc64FifoTb.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-07
-- Last update: 2014-04-09
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
   constant TPD_C             : time := 1 ns;
   constant SLOW_CLK_PERIOD_C : time := 10 ns;
   constant FAST_CLK_PERIOD_C : time := 10 ns;

   constant CONFIG_TEST_C      : natural := 0;
   constant CONFIG_TEST_SIZE_C : natural := (48-1);

   type SimConfigType is record
      PIPE_STAGES_G   : integer;
      BRAM_EN_G       : boolean;
      GEN_SYNC_FIFO_G : boolean;
      USE_BUILT_IN_G  : boolean;
      FAST_WCLK_G     : boolean;
   end record;
   type SimConfigArray is array (natural range <>) of SimConfigType;
   constant SIM_CONFIG_C : SimConfigArray(0 to 47) := (
      0                  => (
         PIPE_STAGES_G   => 0,
         USE_BUILT_IN_G  => false,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => false,
         FAST_WCLK_G     => false),
      1                  => (
         PIPE_STAGES_G   => 0,
         USE_BUILT_IN_G  => false,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => false,
         FAST_WCLK_G     => true),
      2                  => (
         PIPE_STAGES_G   => 0,
         USE_BUILT_IN_G  => false,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => true,
         FAST_WCLK_G     => false),
      3                  => (
         PIPE_STAGES_G   => 0,
         USE_BUILT_IN_G  => false,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => true,
         FAST_WCLK_G     => true),
      4                  => (
         PIPE_STAGES_G   => 0,
         USE_BUILT_IN_G  => false,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => false,
         FAST_WCLK_G     => false),
      5                  => (
         PIPE_STAGES_G   => 0,
         USE_BUILT_IN_G  => false,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => false,
         FAST_WCLK_G     => true),
      6                  => (
         PIPE_STAGES_G   => 0,
         USE_BUILT_IN_G  => false,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => true,
         FAST_WCLK_G     => false),
      7                  => (
         PIPE_STAGES_G   => 0,
         USE_BUILT_IN_G  => false,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => true,
         FAST_WCLK_G     => true),
      8                  => (
         PIPE_STAGES_G   => 0,
         USE_BUILT_IN_G  => true,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => false,
         FAST_WCLK_G     => false),
      9                  => (
         PIPE_STAGES_G   => 0,
         USE_BUILT_IN_G  => true,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => false,
         FAST_WCLK_G     => true),
      10                 => (
         PIPE_STAGES_G   => 0,
         USE_BUILT_IN_G  => true,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => true,
         FAST_WCLK_G     => false),
      11                 => (
         PIPE_STAGES_G   => 0,
         USE_BUILT_IN_G  => true,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => true,
         FAST_WCLK_G     => true),
      12                 => (
         PIPE_STAGES_G   => 0,
         USE_BUILT_IN_G  => true,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => false,
         FAST_WCLK_G     => false),
      13                 => (
         PIPE_STAGES_G   => 0,
         USE_BUILT_IN_G  => true,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => false,
         FAST_WCLK_G     => true),
      14                 => (
         PIPE_STAGES_G   => 0,
         USE_BUILT_IN_G  => true,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => true,
         FAST_WCLK_G     => false),
      15                 => (
         PIPE_STAGES_G   => 0,
         USE_BUILT_IN_G  => true,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => true,
         FAST_WCLK_G     => true),
      16                 => (
         PIPE_STAGES_G   => 1,
         USE_BUILT_IN_G  => false,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => false,
         FAST_WCLK_G     => false),
      17                 => (
         PIPE_STAGES_G   => 1,
         USE_BUILT_IN_G  => false,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => false,
         FAST_WCLK_G     => true),
      18                 => (
         PIPE_STAGES_G   => 1,
         USE_BUILT_IN_G  => false,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => true,
         FAST_WCLK_G     => false),
      19                 => (
         PIPE_STAGES_G   => 1,
         USE_BUILT_IN_G  => false,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => true,
         FAST_WCLK_G     => true),
      20                 => (
         PIPE_STAGES_G   => 1,
         USE_BUILT_IN_G  => false,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => false,
         FAST_WCLK_G     => false),
      21                 => (
         PIPE_STAGES_G   => 1,
         USE_BUILT_IN_G  => false,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => false,
         FAST_WCLK_G     => true),
      22                 => (
         PIPE_STAGES_G   => 1,
         USE_BUILT_IN_G  => false,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => true,
         FAST_WCLK_G     => false),
      23                 => (
         PIPE_STAGES_G   => 1,
         USE_BUILT_IN_G  => false,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => true,
         FAST_WCLK_G     => true),
      24                 => (
         PIPE_STAGES_G   => 1,
         USE_BUILT_IN_G  => true,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => false,
         FAST_WCLK_G     => false),
      25                 => (
         PIPE_STAGES_G   => 1,
         USE_BUILT_IN_G  => true,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => false,
         FAST_WCLK_G     => true),
      26                 => (
         PIPE_STAGES_G   => 1,
         USE_BUILT_IN_G  => true,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => true,
         FAST_WCLK_G     => false),
      27                 => (
         PIPE_STAGES_G   => 1,
         USE_BUILT_IN_G  => true,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => true,
         FAST_WCLK_G     => true),
      28                 => (
         PIPE_STAGES_G   => 1,
         USE_BUILT_IN_G  => true,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => false,
         FAST_WCLK_G     => false),
      29                 => (
         PIPE_STAGES_G   => 1,
         USE_BUILT_IN_G  => true,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => false,
         FAST_WCLK_G     => true),
      30                 => (
         PIPE_STAGES_G   => 1,
         USE_BUILT_IN_G  => true,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => true,
         FAST_WCLK_G     => false),
      31                 => (
         PIPE_STAGES_G   => 1,
         USE_BUILT_IN_G  => true,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => true,
         FAST_WCLK_G     => true),
      32                 => (
         PIPE_STAGES_G   => 2,
         USE_BUILT_IN_G  => false,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => false,
         FAST_WCLK_G     => false),
      33                 => (
         PIPE_STAGES_G   => 2,
         USE_BUILT_IN_G  => false,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => false,
         FAST_WCLK_G     => true),
      34                 => (
         PIPE_STAGES_G   => 2,
         USE_BUILT_IN_G  => false,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => true,
         FAST_WCLK_G     => false),
      35                 => (
         PIPE_STAGES_G   => 2,
         USE_BUILT_IN_G  => false,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => true,
         FAST_WCLK_G     => true),
      36                 => (
         PIPE_STAGES_G   => 2,
         USE_BUILT_IN_G  => false,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => false,
         FAST_WCLK_G     => false),
      37                 => (
         PIPE_STAGES_G   => 2,
         USE_BUILT_IN_G  => false,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => false,
         FAST_WCLK_G     => true),
      38                 => (
         PIPE_STAGES_G   => 2,
         USE_BUILT_IN_G  => false,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => true,
         FAST_WCLK_G     => false),
      39                 => (
         PIPE_STAGES_G   => 2,
         USE_BUILT_IN_G  => false,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => true,
         FAST_WCLK_G     => true),
      40                 => (
         PIPE_STAGES_G   => 2,
         USE_BUILT_IN_G  => true,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => false,
         FAST_WCLK_G     => false),
      41                 => (
         PIPE_STAGES_G   => 2,
         USE_BUILT_IN_G  => true,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => false,
         FAST_WCLK_G     => true),
      42                 => (
         PIPE_STAGES_G   => 2,
         USE_BUILT_IN_G  => true,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => true,
         FAST_WCLK_G     => false),
      43                 => (
         PIPE_STAGES_G   => 2,
         USE_BUILT_IN_G  => true,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => true,
         FAST_WCLK_G     => true),
      44                 => (
         PIPE_STAGES_G   => 2,
         USE_BUILT_IN_G  => true,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => false,
         FAST_WCLK_G     => false),
      45                 => (
         PIPE_STAGES_G   => 2,
         USE_BUILT_IN_G  => true,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => false,
         FAST_WCLK_G     => true),
      46                 => (
         PIPE_STAGES_G   => 2,
         USE_BUILT_IN_G  => true,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => true,
         FAST_WCLK_G     => false),
      47                 => (
         PIPE_STAGES_G   => 2,
         USE_BUILT_IN_G  => true,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => true,
         FAST_WCLK_G     => true));          

   constant LAST_DATA_C       : slv(63 downto 0) := toSlv(4096, 64);
   constant READ_BUSY_THRES_C : slv(3 downto 0)  := toSlv(7, 4);

   -- Signals
   signal clk,
      rst,
      vcRxClk,
      vcRxRst : sl;
   signal dropWrite,
      termFrame,
      wrDone,
      wrDoneDly,
      rdDone,
      rdDoneDly,
      rdError,
      rdErrorDly : slv(0 to CONFIG_TEST_SIZE_C) := (others=>'0');

   signal simulationPassed,
      simulationFailed : sl := '0';

begin

   simulationPassed <= uAnd(wrDoneDly) and uAnd(rdDoneDly);
   simulationFailed <= uOr(rdErrorDly);

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
   
   process(clk)
   begin
      if rising_edge(clk) then
         wrDoneDly  <= wrDone after TPD_C;
         rdDoneDly  <= rdDone after TPD_C;
         rdErrorDly <= rdError after TPD_C;
      end if;
   end process;   

   -- Generate clocks and resets
   ClkRst_Write : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => SLOW_CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 500 ns)   -- Hold reset for this long)
      port map (
         clkP => vcRxClk,
         clkN => open,
         rst  => vcRxRst,
         rstL => open); 

   ClkRst_Read : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => FAST_CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 500 ns)   -- Hold reset for this long)
      port map (
         clkP => clk,
         clkN => open,
         rst  => rst,
         rstL => open); 

   GEN_TEST_MODULES :
   for i in 0 to CONFIG_TEST_SIZE_C generate
      
      GEN_FAST_CLK : if (SIM_CONFIG_C(i).FAST_WCLK_G = true) generate
         
         Vc64FifoTbSubModule_Fast : entity work.Vc64FifoTbSubModule
            generic map (
               TPD_G             => TPD_C,
               PIPE_STAGES_G     => SIM_CONFIG_C(i).PIPE_STAGES_G,
               BRAM_EN_G         => SIM_CONFIG_C(i).BRAM_EN_G,
               GEN_SYNC_FIFO_G   => SIM_CONFIG_C(i).GEN_SYNC_FIFO_G,
               USE_BUILT_IN_G    => SIM_CONFIG_C(i).USE_BUILT_IN_G,
               LAST_DATA_G       => LAST_DATA_C,
               READ_BUSY_THRES_G => READ_BUSY_THRES_C)
            port map (
               -- Status
               dropWrite => dropWrite(i),
               termFrame => termFrame(i),
               wrDone    => wrDone(i),
               rdDone    => rdDone(i),
               rdError   => rdError(i),
               -- Clocks and Resets
               vcRxClk   => clk,
               vcRxRst   => rst,
               clk       => vcRxClk,
               rst       => vcRxRst);

      end generate GEN_FAST_CLK;

      GEN_SLOW_CLK : if (SIM_CONFIG_C(i).FAST_WCLK_G = false) generate
         
         Vc64FifoTbSubModule_Slow : entity work.Vc64FifoTbSubModule
            generic map (
               TPD_G             => TPD_C,
               PIPE_STAGES_G     => SIM_CONFIG_C(i).PIPE_STAGES_G,
               BRAM_EN_G         => SIM_CONFIG_C(i).BRAM_EN_G,
               GEN_SYNC_FIFO_G   => SIM_CONFIG_C(i).GEN_SYNC_FIFO_G,
               USE_BUILT_IN_G    => SIM_CONFIG_C(i).USE_BUILT_IN_G,
               LAST_DATA_G       => LAST_DATA_C,
               READ_BUSY_THRES_G => READ_BUSY_THRES_C)
            port map (
               -- Status
               dropWrite => dropWrite(i),
               termFrame => termFrame(i),
               wrDone    => wrDone(i),
               rdDone    => rdDone(i),
               rdError   => rdError(i),
               -- Clocks and Resets
               vcRxClk   => vcRxClk,
               vcRxRst   => vcRxRst,
               clk       => clk,
               rst       => rst); 

      end generate GEN_SLOW_CLK;
      
   end generate GEN_TEST_MODULES;

end testbed;
