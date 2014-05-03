-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiStreamPipelineTb.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-05-02
-- Last update: 2014-05-02
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the VcPrbsTx and VcPrbsRx modules
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity AxiStreamPipelineTb is end AxiStreamPipelineTb;

architecture testbed of AxiStreamPipelineTb is

   constant CLK_PERIOD_C : time := 10 ns;
   constant TPD_C        : time := CLK_PERIOD_C/4;

   signal clk,
      rst,
      passed,
      failed,
      toggle,
      fifoWrEn,
      fifoAFull,
      fifoRdEn : sl := '0';
   signal mAxisMaster,
      sAxisMaster : AxiStreamMasterType;
   signal mAxisSlave,
      sAxisSlave : AxiStreamSlaveType;
   signal cnt,
      check : slv(127 downto 0);
      
   signal readDelay : slv(3 downto 0);

begin

   -- Generate clocks and resets
   ClkRst_Inst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 745 ns)   -- Hold reset for this long)
      port map (
         clkP => clk,
         clkN => open,
         rst  => rst,
         rstL => open); 

   process(clk)
   begin
      if rising_edge(clk) then
         fifoWrEn <= '0' after TPD_C;
         if rst = '1' then
            cnt <= (others => '1') after TPD_C;
         else
            if fifoAFull = '0' then
               fifoWrEn <= '1'     after TPD_C;
               cnt      <= cnt + 1 after TPD_C;
            end if;
         end if;
      end if;
   end process;

   FifoSync_Inst : entity work.FifoSync
      generic map (
         TPD_G        => TPD_C,
         BRAM_EN_G    => false,
         FWFT_EN_G    => true,
         DATA_WIDTH_G => 128,
         ADDR_WIDTH_G => 4)
      port map (
         rst         => rst,
         clk         => clk,
         wr_en       => fifoWrEn,
         rd_en       => fifoRdEn,
         din         => cnt,
         dout        => sAxisMaster.tData,
         valid       => sAxisMaster.tValid,
         almost_full => fifoAFull); 

   fifoRdEn <= sAxisMaster.tValid and sAxisSlave.tReady;

   -- VcPrbsTx (VHDL module to be tested)
   AxiStreamPipeline_Inst : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_C,
         PIPE_STAGES_G => 1)
      port map (
         -- Clock and Reset
         axisClk     => clk,
         axisRst     => rst,
         -- Slave Port
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         -- Master Port
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);   

   process(clk)
   begin
      if rising_edge(clk) then
         mAxisSlave.tReady <= '0' after TPD_C;
         if rst = '1' then
            check      <= (others => '0')         after TPD_C;
            readDelay  <= (others => '0')         after TPD_C;
            mAxisSlave <= AXI_STREAM_SLAVE_INIT_C after TPD_C;
         else
            readDelay <= readDelay + 1  after TPD_C;
            if readDelay < 3 then
               mAxisSlave.tReady <= '1' after TPD_C;
            end if;
            if mAxisSlave.tReady = '1' then
               if mAxisMaster.tValid = '1' then
                  check <= check + 1 after TPD_C;
                  if mAxisMaster.tData /= check then
                     failed <= '1' after TPD_C;
                  end if;
                  if check = 256 then
                     passed <= '1' after TPD_C;
                  end if;
               end if;
            end if;
         end if;
      end if;
   end process;

   process(failed, passed)
   begin
      if failed = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;
      if passed = '1' then
         assert false
            report "Simulation Passed!" severity failure;
      end if;
   end process;

end testbed;
