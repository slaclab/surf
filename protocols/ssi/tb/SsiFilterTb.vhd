-------------------------------------------------------------------------------
-- File       : SsiFilterTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-03-24
-- Last update: 2016-10-11
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the SsiFifo module
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
use work.SsiPkg.all;

entity SsiFilterTb is end SsiFilterTb;

architecture testbed of SsiFilterTb is

   constant SLOW_CLK_PERIOD_C : time := 6.4 ns;
   constant FAST_CLK_PERIOD_C : time := 5 ns;
   constant TPD_C             : time := (FAST_CLK_PERIOD_C/4);

   constant SLAVE_AXI_CONFIG_C  : AxiStreamConfigType := ssiAxiStreamConfig(16);
   constant MASTER_AXI_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(8);

   type RegType is record
      passed      : sl;
      toggle      : sl;
      flood       : sl;
      floodCnt    : slv(15 downto 0);
      movCnt      : natural range 0 to 500;
      sAxisMaster : AxiStreamMasterType;
   end record;

   constant REG_INIT_C : RegType := (
      passed      => '0',
      toggle      => '0',
      flood       => '1',
      floodCnt    => x"0000",
      movCnt      => 0,
      sAxisMaster => AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal slowClk   : sl := '0';
   signal slowRst   : sl := '1';
   signal fastClk   : sl := '0';
   signal fastRst   : sl := '1';
   signal failed    : sl := '0';
   signal failedDly : sl := '0';
   signal passedDly : sl := '0';

   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;

begin

   ---------------------------------------
   -- Generate fast clocks and fast resets
   ---------------------------------------
   ClkRst_Fast : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => FAST_CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 750 ns)   -- Hold reset for this long)
      port map (
         clkP => fastClk,
         clkN => open,
         rst  => fastRst,
         rstL => open); 

   ClkRst_Slow : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => SLOW_CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => slowClk,
         clkN => open,
         rst  => slowRst,
         rstL => open);          

   comb : process (r, slowRst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Toggle the flag
      v.toggle := not(r.toggle);

      --  Move the data
      v.sAxisMaster.tValid := (r.flood or r.toggle);
      v.sAxisMaster.tLast  := '0';
      v.sAxisMaster.tUser  := (others => '0');

      -- Check if moving data
      if (v.sAxisMaster.tValid = '1') then
         -- Increment the counter
         v.movCnt := r.movCnt + 1;
         -- Check for SOF
         if r.movCnt = 0 then
            -- Set the SOF bit
            ssiSetUserSof(SLAVE_AXI_CONFIG_C, v.sAxisMaster, '1');
         elsif r.movCnt = 63 then
            -- Reset the counter
            v.movCnt            := 0;
            -- Set the EOF bit
            v.sAxisMaster.tLast := '1';
            if r.floodCnt = x"00FF" then
               -- Reset the flag
               v.flood := '0';
            else
               -- Increment the counter
               v.floodCnt := r.floodCnt + 1;
            end if;
         end if;
      end if;

      -- Reset
      if (slowRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (slowClk) is
   begin
      if rising_edge(slowClk) then
         r         <= rin      after TPD_C;
         passedDly <= r.passed after TPD_C;
      end if;
   end process seq;

   U_Fifo : entity work.SsiFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_C,
         INT_PIPE_STAGES_G   => 1,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => false,
         EN_FRAME_FILTER_G   => true,
         VALID_THOLD_G       => 0,
         -- FIFO configurations
         BRAM_EN_G           => true,
         GEN_SYNC_FIFO_G     => false,
         CASCADE_SIZE_G      => 4,
         CASCADE_PAUSE_SEL_G => 1,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_PAUSE_THRESH_G => 500,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_C,
         MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_C)        
      port map (
         sAxisClk    => slowClk,
         sAxisRst    => slowRst,
         sAxisMaster => r.sAxisMaster,
         mAxisClk    => fastClk,
         mAxisRst    => fastRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => AXI_STREAM_SLAVE_FORCE_C);           

   process (fastClk) is
   begin
      if rising_edge(fastClk) then
         if (fastRst = '1') then
            failed    <= '0' after TPD_C;
            failedDly <= '0' after TPD_C;
         else
            failedDly <= failed after TPD_C;
            failed    <= '0' after TPD_C;
            if (mAxisMaster.tValid = '1') and (mAxisMaster.tLast = '1') then
               failed <= ssiGetUserEofe(MASTER_AXI_CONFIG_C, mAxisMaster) after TPD_C;
            end if;
         end if;
      end if;
   end process;

   process(failedDly, passedDly)
   begin
      if (failedDly = '1') then
      -- assert false
      -- report "Simulation Failed!" severity failure;
      end if;
      if (passedDly = '1') then
         assert false
            report "Simulation Passed!" severity failure;
      end if;
   end process;
   
end testbed;
