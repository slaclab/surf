-------------------------------------------------------------------------------
-- File       : AxiStreamPipelineTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-05-02
-- Last update: 2016-09-06
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

   constant CLK_PERIOD_C  : time              := 4 ns;
   constant TPD_C         : time              := CLK_PERIOD_C/4;
   constant PIPE_STAGES_C : natural           := 1;
   constant MAX_CNT_C     : slv(127 downto 0) := x"000000000000000019999997E241C000";
   -- constant MAX_CNT_C     : slv(127 downto 0) := x"000000000000000000000000000000FF";
   constant PRBS_TAPS_C   : NaturalArray      := (0 => 31, 1 => 6, 2 => 2, 3 => 1);

   type RegType is record
      passed      : sl;
      failed      : sl;
      wrPbrs      : slv(31 downto 0);
      wrSof       : sl;
      wrPkt       : slv(127 downto 0);
      wrCnt       : slv(127 downto 0);
      wrSize      : slv(127 downto 0);
      rdPbrs      : slv(31 downto 0);
      rdSof       : sl;
      rdPkt       : slv(127 downto 0);
      rdCnt       : slv(127 downto 0);
      rdSize      : slv(127 downto 0);
      sAxisMaster : AxiStreamMasterType;
      mAxisSlave  : AxiStreamSlaveType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      passed      => '0',
      failed      => '0',
      wrPbrs      => x"AE64B770",
      wrSof       => '1',
      wrPkt       => (others => '0'),
      wrCnt       => (others => '0'),
      wrSize      => (others => '0'),
      rdPbrs      => x"5E68B7E2",
      rdSof       => '1',
      rdPkt       => (others => '0'),
      rdCnt       => (others => '0'),
      rdSize      => (others => '0'),
      sAxisMaster => AXI_STREAM_MASTER_INIT_C,
      mAxisSlave  => AXI_STREAM_SLAVE_INIT_C);      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal clk    : sl := '0';
   signal rst    : sl := '0';
   signal passed : sl := '0';
   signal failed : sl := '0';
   
begin

   -- Generate clocks and resets
   ClkRst_Inst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => clk,
         clkN => open,
         rst  => rst,
         rstL => open); 

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

   comb : process (mAxisMaster, r, rst, sAxisSlave) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags      
      v.mAxisSlave := AXI_STREAM_SLAVE_INIT_C;
      if sAxisSlave.tReady = '1' then
         v.sAxisMaster.tValid := '0';
         v.sAxisMaster.tLast  := '0';
         v.sAxisMaster.tUser  := (others => '0');
         v.sAxisMaster.tKeep  := (others => '1');
      end if;

      -- Generate the next random data words
      for i in 31 downto 0 loop
         v.wrPbrs := lfsrShift(v.wrPbrs, PRBS_TAPS_C);
         v.rdPbrs := lfsrShift(v.rdPbrs, PRBS_TAPS_C);
      end loop;

      -- Write Process with time domain randomization
      if (v.sAxisMaster.tValid = '0') and (r.wrPbrs(0) = '0') then
         -- Move the data
         v.sAxisMaster.tValid := '1';
         -- Check for SOF
         if r.wrSof = '1' then
            -- Reset the flag
            v.wrSof             := '0';
            -- Forward packet index
            v.sAxisMaster.tData := r.wrPkt;
            -- Increment the counter
            v.wrPkt             := r.wrPkt + 1;
         else
            -- Forward counter
            v.sAxisMaster.tData := r.wrCnt;
            -- Increment the counter
            v.wrCnt             := r.wrCnt + 1;
            -- Check the counter size
            if r.wrCnt = r.wrSize then
               -- Reset the counter
               v.wrCnt             := (others => '0');
               -- Increment the counter
               v.wrSize            := r.wrSize + 1;
               -- Set EOF
               v.sAxisMaster.tLast := '1';
               -- Reset the flag
               v.wrSof             := '1';
            end if;
         end if;
      end if;

      -- Read Process with time domain randomization      
      if (mAxisMaster.tValid = '1') and (r.rdPbrs(0) = '0') then
         -- Accept the data
         v.mAxisSlave.tReady := '1';
         -- Check for SOF
         if r.rdSof = '1' then
            -- Reset the flag
            v.rdSof := '0';
            -- Increment the counter
            v.rdPkt := r.rdPkt + 1;
            -- Check for incorrect packet number
            if (mAxisMaster.tData /= r.rdPkt) then
               v.failed := '1';
            end if;
         else
            -- Increment the counter
            v.rdCnt := r.rdCnt + 1;
            -- Check for incorrect data
            if (mAxisMaster.tData /= r.rdCnt) then
               v.failed := '1';
            end if;
            -- Check for EOF
            if (mAxisMaster.tLast = '1') then
               -- Reset the counter
               v.rdCnt  := (others => '0');
               -- Increment the counter
               v.rdSize := r.rdSize + 1;
               -- Check for incorrect size
               if (r.rdCnt /= r.rdSize) then
                  v.failed := '1';
               end if;
               -- Reset the flag
               v.rdSof := '1';
               -- Check if test passed 
               if r.rdSize = MAX_CNT_C then
                  v.passed := '1';
               end if;
            end if;
         end if;
      end if;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      mAxisSlave  <= v.mAxisSlave;
      sAxisMaster <= r.sAxisMaster;
      failed      <= r.failed;
      passed      <= r.passed;
      
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_C;
      end if;
   end process seq;

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
