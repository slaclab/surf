-------------------------------------------------------------------------------
-- File       : SsiPrbsTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-29
-- Last update: 2014-11-07
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the VcPrbsTx and VcPrbsRx modules
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
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity SsiPrbsTb is end SsiPrbsTb;

architecture testbed of SsiPrbsTb is

   function PrbsAxiStreamConfig (
      dataBytes : natural;
      tKeepMode : TKeepModeType := TKEEP_COMP_C) 
      return AxiStreamConfigType is
      variable ret : AxiStreamConfigType;
   begin
      ret.TDATA_BYTES_C := dataBytes;           -- Configurable data size
      ret.TUSER_BITS_C  := 4;
      ret.TDEST_BITS_C  := SSI_TDEST_BITS_C;    -- 4 TDEST bits for VC
      ret.TID_BITS_C    := SSI_TID_BITS_C;      -- TID not used
      ret.TKEEP_MODE_C  := tKeepMode;           -- 
      ret.TSTRB_EN_C    := SSI_TSTRB_EN_C;      -- No TSTRB support in SSI
      ret.TUSER_MODE_C  := TUSER_FIRST_LAST_C;  -- User field valid on last only
      return ret;
   end function;

   -- Constants
   constant SLOW_CLK_PERIOD_C  : time             := 10 ns;
   constant FAST_CLK_PERIOD_C  : time             := SLOW_CLK_PERIOD_C/3;
   constant TPD_C              : time             := FAST_CLK_PERIOD_C/4;
   constant STATUS_CNT_WIDTH_C : natural          := 32;
   constant AXI_ERROR_RESP_C   : slv(1 downto 0)  := AXI_RESP_SLVERR_C;
   constant TX_PACKET_LENGTH_C : slv(31 downto 0) := toSlv(256, 32);
   constant NUMBER_PACKET_C    : slv(31 downto 0) := x"00000FFF";

   -- FIFO configurations
   constant BRAM_EN_C           : boolean := true;
   constant XIL_DEVICE_C        : string  := "7SERIES";
   constant USE_BUILT_IN_C      : boolean := false;
   constant GEN_SYNC_FIFO_C     : boolean := false;
   constant ALTERA_SYN_C        : boolean := false;
   constant ALTERA_RAM_C        : string  := "M9K";
   constant CASCADE_SIZE_C      : natural := 1;
   constant FIFO_ADDR_WIDTH_C   : natural := 9;
   constant FIFO_PAUSE_THRESH_C : natural := 2**8;

   -- PRBS Configuration
   constant PRBS_SEED_SIZE_C : natural      := 32;
   constant PRBS_TAPS_C      : NaturalArray := (0 => 31, 1 => 6, 2 => 2, 3 => 1);
   constant FORCE_EOFE_C     : sl           := '0';  -- Forces an error (testing tUser field MUX-ing)

   -- AXI Stream Configurations
   constant AXI_STREAM_CONFIG_C : AxiStreamConfigType := PrbsAxiStreamConfig(16, TKEEP_COMP_C);
   constant AXI_PIPE_STAGES_C   : natural             := 1;

   -- Signals
   signal fastClk,
      slowClk,
      errMissedPacket,
      errLength,
      errDataBus,
      errEofe,
      passed,
      failed,
      updated : sl := '0';
   signal fastRst,
      slowRst : sl := '1';
   signal errWordCnt,
      errbitCnt,
      cnt : slv(31 downto 0);
   
   signal axisMaster : AxiStreamMasterType;
   signal axisSlave  : AxiStreamSlaveType;

begin

   -- Generate fast clocks and fast resets
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
         RST_HOLD_TIME_G   => 750 ns)   -- Hold reset for this long)
      port map (
         clkP => slowClk,
         clkN => open,
         rst  => slowRst,
         rstL => open);          

   -- VcPrbsTx (VHDL module to be tested)
   SsiPrbsTx_Inst : entity work.SsiPrbsTx
      generic map (
         -- General Configurations
         TPD_G                      => TPD_C,
         -- FIFO configurations
         BRAM_EN_G                  => BRAM_EN_C,
         XIL_DEVICE_G               => XIL_DEVICE_C,
         USE_BUILT_IN_G             => USE_BUILT_IN_C,
         GEN_SYNC_FIFO_G            => GEN_SYNC_FIFO_C,
         ALTERA_SYN_G               => ALTERA_SYN_C,
         ALTERA_RAM_G               => ALTERA_RAM_C,
         CASCADE_SIZE_G             => CASCADE_SIZE_C,
         FIFO_ADDR_WIDTH_G          => FIFO_ADDR_WIDTH_C,
         FIFO_PAUSE_THRESH_G        => FIFO_PAUSE_THRESH_C,
         -- PRBS Configurations
         PRBS_SEED_SIZE_G           => PRBS_SEED_SIZE_C,
         PRBS_TAPS_G                => PRBS_TAPS_C,
         -- AXI Stream Configurations
         MASTER_AXI_STREAM_CONFIG_G => AXI_STREAM_CONFIG_C,
         MASTER_AXI_PIPE_STAGES_G   => AXI_PIPE_STAGES_C)        
      port map (
         -- Master Port (mAxisClk)
         mAxisClk     => slowClk,
         mAxisRst     => slowRst,
         mAxisMaster  => axisMaster,
         mAxisSlave   => axisSlave,
         -- Trigger Signal (locClk domain)
         locClk       => fastClk,
         locRst       => fastRst,
         trig         => '1',
         packetLength => TX_PACKET_LENGTH_C,
         forceEofe    => FORCE_EOFE_C,
         busy         => open,
         tDest        => (others => '0'),
         tId          => (others => '0'));     

   -- VcPrbsRx (VHDL module to be tested)
   SsiPrbsRx_Inst : entity work.SsiPrbsRx
      generic map (
         -- General Configurations
         TPD_G                      => TPD_C,
         STATUS_CNT_WIDTH_G         => STATUS_CNT_WIDTH_C,
         AXI_ERROR_RESP_G           => AXI_ERROR_RESP_C,
         -- FIFO Configurations
         BRAM_EN_G                  => BRAM_EN_C,
         XIL_DEVICE_G               => XIL_DEVICE_C,
         USE_BUILT_IN_G             => USE_BUILT_IN_C,
         GEN_SYNC_FIFO_G            => GEN_SYNC_FIFO_C,
         ALTERA_SYN_G               => ALTERA_SYN_C,
         ALTERA_RAM_G               => ALTERA_RAM_C,
         CASCADE_SIZE_G             => CASCADE_SIZE_C,
         FIFO_ADDR_WIDTH_G          => FIFO_ADDR_WIDTH_C,
         FIFO_PAUSE_THRESH_G        => FIFO_PAUSE_THRESH_C,
         -- PRBS Configurations
         PRBS_SEED_SIZE_G           => PRBS_SEED_SIZE_C,
         PRBS_TAPS_G                => PRBS_TAPS_C,
         -- AXI Stream Configurations
         SLAVE_AXI_STREAM_CONFIG_G  => AXI_STREAM_CONFIG_C,
         SLAVE_AXI_PIPE_STAGES_G    => AXI_PIPE_STAGES_C,
         MASTER_AXI_STREAM_CONFIG_G => ssiAxiStreamConfig(4),  -- unused
         MASTER_AXI_PIPE_STAGES_G   => 0)                      -- unused
      port map (
         -- Streaming RX Data Interface (sAxisClk domain) 
         sAxisClk        => slowClk,
         sAxisRst        => slowRst,
         sAxisMaster     => axisMaster,
         sAxisSlave      => axisSlave,
         sAxisCtrl       => open,
         -- Optional: Streaming TX Data Interface (mAxisClk domain)
         mAxisClk        => slowClk,
         mAxisRst        => slowRst,
         mAxisMaster     => open,
         mAxisSlave      => AXI_STREAM_SLAVE_FORCE_C,
         -- Optional: AXI-Lite Register Interface (axiClk domain)
         axiClk          => slowClk,
         axiRst          => slowRst,
         axiReadMaster   => AXI_LITE_READ_MASTER_INIT_C,
         axiReadSlave    => open,
         axiWriteMaster  => AXI_LITE_WRITE_MASTER_INIT_C,
         -- Error Detection Signals (sAxisClk domain)
         updatedResults  => updated,
         busy            => open,
         errMissedPacket => errMissedPacket,
         errLength       => errLength,
         errDataBus      => errDataBus,
         errEofe         => errEofe,
         errWordCnt      => errWordCnt,
         errbitCnt       => errbitCnt,
         packetRate      => open,
         packetLength    => open);     

   process(slowClk)
   begin
      if rising_edge(slowClk) then
         if slowRst = '1' then
            cnt    <= (others => '0') after TPD_C;
            passed <= '0'             after TPD_C;
            failed <= '0'             after TPD_C;
         elsif updated = '1' then
            -- Check for missed packet error
            if errMissedPacket = '1' then
               failed <= '1' after TPD_C;
            end if;
            -- Check for packet length error
            if errLength = '1' then
               failed <= '1' after TPD_C;
            end if;
            -- Check for packet data bus error
            if errDataBus = '1' then
               failed <= '1' after TPD_C;
            end if;
            -- Check for EOFE error
            if errEofe = '1' then
               failed <= '1' after TPD_C;
            end if;
            -- Check for word error
            if errWordCnt /= 0 then
               failed <= '1' after TPD_C;
            end if;
            -- Check for bit error
            if errbitCnt /= 0 then
               failed <= '1' after TPD_C;
            end if;
            -- Check the counter
            if cnt = NUMBER_PACKET_C then
               passed <= '1' after TPD_C;
            else
               -- Increment the counter
               cnt <= cnt + 1 after TPD_C;
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
