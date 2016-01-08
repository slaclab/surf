-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiStreamPipelineTb.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-05-02
-- Last update: 2015-04-03
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the AxiStreamPipelineTb module
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity AxiStreamPipelineTb is end AxiStreamPipelineTb;

architecture testbed of AxiStreamPipelineTb is

   constant CLK_PERIOD_C  : time              := 1 ns;
   constant TPD_C         : time              := CLK_PERIOD_C/4;
   constant FIFO_WIDTH_C  : natural           := 4;
   constant DATA_WIDTH_C  : natural           := 128;
   constant PIPE_STAGES_C : natural           := 4;
   constant MAX_CNT_C     : slv(127 downto 0) := toSlv(65535, 128);

   type StateType is (
      FILLUP_S,
      DRAIN_S,
      HOLD_S);       

   signal state     : StateType := FILLUP_S;
   signal clk       : sl        := '0';
   signal rst       : sl        := '0';
   signal passed    : sl        := '0';
   signal failed    : sl        := '0';
   signal toggle    : sl        := '0';
   signal fifoWrEn  : sl        := '0';
   signal fifoAFull : sl        := '0';
   signal fifoRdEn  : sl        := '0';

   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal writeDelay : slv(3 downto 0)              := (others => '0');
   signal readDelay  : slv(3 downto 0)              := (others => '0');
   signal fillCount  : slv(FIFO_WIDTH_C-1 downto 0) := (others => '0');
   signal cnt        : slv(DATA_WIDTH_C-1 downto 0) := (others => '1');
   signal check      : slv(DATA_WIDTH_C-1 downto 0) := (others => '0');
   
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

   -- Data generator
   process(clk)
   begin
      if rising_edge(clk) then
         -- Reset the flag
         fifoWrEn <= '0' after TPD_C;
         -- Check for a reset
         if rst = '1' then
            -- Reset the registers
            cnt        <= (others => '1') after TPD_C;
            writeDelay <= (others => '0') after TPD_C;
            state      <= FILLUP_S        after TPD_C;
         else
            case state is
               ----------------------------------------------------------------------
               when FILLUP_S =>
                  -- Check the FIFO status
                  if fifoAFull = '0' then
                     -- Increment the counter
                     writeDelay <= writeDelay + 1 after TPD_C;
                     -- Check the counter
                     if writeDelay < 3 then
                        fifoWrEn <= '1'     after TPD_C;
                        cnt      <= cnt + 1 after TPD_C;
                     end if;
                  else
                     -- Next state
                     state <= DRAIN_S after TPD_C;
                  end if;
               ----------------------------------------------------------------------
               when DRAIN_S =>
                  -- Check the FIFO status
                  if fillCount = 0 then
                     -- Next state
                     state <= HOLD_S after TPD_C;
                  end if;
               ----------------------------------------------------------------------
               when HOLD_S =>
                  -- Check for polling
                  if (mAxisSlave.tReady = '1') and (mAxisMaster.tValid = '1') then
                     -- Reset the counter
                     writeDelay <= (others => '0') after TPD_C;
                  elsif writeDelay /= x"F" then
                     -- Increment the counter
                     writeDelay <= writeDelay + 1;
                  else
                     -- Reset the counter
                     writeDelay <= (others => '0') after TPD_C;
                     -- Next state
                     state      <= FILLUP_S        after TPD_C;
                  end if;
            ----------------------------------------------------------------------
            end case;
         end if;
      end if;
   end process;

   -- Buffer the data
   FifoSync_Inst : entity work.FifoSync
      generic map (
         TPD_G        => TPD_C,
         BRAM_EN_G    => false,
         FWFT_EN_G    => true,
         DATA_WIDTH_G => DATA_WIDTH_C,
         ADDR_WIDTH_G => FIFO_WIDTH_C)
      port map (
         rst         => rst,
         clk         => clk,
         wr_en       => fifoWrEn,
         rd_en       => fifoRdEn,
         din         => cnt,
         dout        => sAxisMaster.tData,
         valid       => sAxisMaster.tValid,
         data_count  => fillCount,
         almost_full => fifoAFull); 

   fifoRdEn <= sAxisMaster.tValid and sAxisSlave.tReady;

   -- AxiStreamPipeline (VHDL module to be tested)
   AxiStreamPipeline_Inst : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_C,
         PIPE_STAGES_G => PIPE_STAGES_C)
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
         -- Reset the flag
         mAxisSlave.tReady <= '0' after TPD_C;
         -- Check for reset
         if rst = '1' then
            -- Reset the registers
            check      <= (others => '0')         after TPD_C;
            readDelay  <= (others => '0')         after TPD_C;
            mAxisSlave <= AXI_STREAM_SLAVE_INIT_C after TPD_C;
         else
            -- Increment the counter
            readDelay <= readDelay + 1 after TPD_C;
            -- Check the counter to create a tReady duty cycle
            if state /= FILLUP_S then
               -- Set the flag
               mAxisSlave.tReady <= '1' after TPD_C;
            elsif readDelay < 2 then
               -- Set the flag
               mAxisSlave.tReady <= '1' after TPD_C;
            end if;
            -- Check the flag
            if mAxisSlave.tReady = '1' then
               -- Check for FIFO data
               if mAxisMaster.tValid = '1' then
                  -- Increment the counter
                  check <= check + 1 after TPD_C;
                  -- Check for data error
                  if mAxisMaster.tData /= check then
                     -- Assert the flag and not the simulation
                     failed <= '1' after TPD_C;
                  end if;
                  -- Check if simulation is completed
                  if check = MAX_CNT_C then
                     -- Assert the flag and not the simulation
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
