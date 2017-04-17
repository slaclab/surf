-------------------------------------------------------------------------------
-- File       : Salt7SeriesTb.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-03
-- Last update: 2015-09-04
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the Salt7Series
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

entity Salt7SeriesTb is end Salt7SeriesTb;

architecture testbed of Salt7SeriesTb is

   -- General Configurations
   constant CLK_PERIOD_C       : time             := 8 ns;
   constant CLK625_PERIOD_C    : time             := (CLK_PERIOD_C/5.0);
   constant CLK208_PERIOD_C    : time             := (CLK625_PERIOD_C*3.0);
   constant CLK104_PERIOD_C    : time             := (CLK208_PERIOD_C*2.0);
   constant TPD_C              : time             := 1 ns;
   constant STATUS_CNT_WIDTH_C : natural          := 32;
   constant AXI_ERROR_RESP_C   : slv(1 downto 0)  := AXI_RESP_SLVERR_C;
   constant TX_PACKET_LENGTH_C : slv(31 downto 0) := toSlv(32, 32);
   constant NUMBER_PACKET_C    : slv(31 downto 0) := x"0000001F";

   -- PRBS Configuration
   constant PRBS_SEED_SIZE_C : natural      := 32;
   constant PRBS_TAPS_C      : NaturalArray := (0 => 31, 1 => 6, 2 => 2, 3 => 1);
   constant FORCE_EOFE_C     : sl           := '0';  -- Forces an error (testing tUser field MUX-ing)   

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

   -- AXI Stream Configurations
   constant AXI_STREAM_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4);
   constant AXI_PIPE_STAGES_C   : natural             := 1;

   signal clk           : sl := '0';
   signal rst           : sl := '0';
   signal clk104MHz     : sl := '0';
   signal clk208MHz     : sl := '0';
   signal clk625MHz     : sl := '0';
   signal clk208MHzRst  : sl := '0';
   signal iDelayCtrlRdy : sl := '0';
   signal linkUp        : sl := '0';

   signal passed    : sl := '0';
   signal failed    : sl := '0';
   signal passedDly : sl := '0';
   signal failedDly : sl := '0';

   signal loopBackP       : sl := '0';
   signal loopBackN       : sl := '1';
   signal errMissedPacket : sl := '0';
   signal errLength       : sl := '0';
   signal errDataBus      : sl := '0';
   signal errEofe         : sl := '0';
   signal updated         : sl := '0';
   signal linkUpL         : sl := '0';

   signal errWordCnt : slv(31 downto 0) := (others => '0');
   signal errbitCnt  : slv(31 downto 0) := (others => '0');
   signal cnt        : slv(31 downto 0) := (others => '0');
   signal flowCnt    : slv(7 downto 0)  := (others => '0');

   signal ibSaltMaster : AxiStreamMasterType;
   signal ibSaltSlave  : AxiStreamSlaveType;
   signal obSaltMaster : AxiStreamMasterType;
   signal obSaltSlave  : AxiStreamSlaveType;
   
begin

   -----------------------------
   -- Generate clocks and resets
   -----------------------------
   ClkRst_625MHz : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK625_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => clk625MHz,
         clkN => open,
         rst  => open,
         rstL => open);   

   ClkRst_204MHz : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK208_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => clk208MHz,
         clkN => open,
         rst  => clk208MHzRst,
         rstL => open);   

   ClkRst_104MHz : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK104_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => clk104MHz,
         clkN => open,
         rst  => open,
         rstL => open);            

   ClkRst_125MHz : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => clk,
         clkN => open,
         rst  => rst,
         rstL => open);          

   SaltDelayCtrl_Inst : entity work.SaltDelayCtrl
      generic map (
         TPD_G           => TPD_C,
         IODELAY_GROUP_G => "SALT_IODELAY_GRP")
      port map (
         iDelayCtrlRdy => iDelayCtrlRdy,
         refClk        => clk208MHz,
         refRst        => clk208MHzRst);         

   -----------------
   -- Data Generator
   -----------------
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
         MASTER_AXI_STREAM_CONFIG_G => ssiAxiStreamConfig(4),
         MASTER_AXI_PIPE_STAGES_G   => 1)        
      port map (
         -- Master Port (mAxisClk)
         mAxisClk     => clk,
         mAxisRst     => linkUpL,
         mAxisMaster  => ibSaltMaster,
         mAxisSlave   => ibSaltSlave,
         -- Trigger Signal (locClk domain)
         locClk       => clk,
         locRst       => linkUpL,
         trig         => iDelayCtrlRdy,
         packetLength => TX_PACKET_LENGTH_C,
         forceEofe    => FORCE_EOFE_C,
         busy         => open,
         tDest        => (others => '0'),
         tId          => (others => '0'));    

   linkUpL <= not(linkUp);

   ----------------------         
   -- Module to be tested
   ----------------------   
   Salt7Series_Inst : entity work.Salt7Series
      generic map (
         TPD_G               => TPD_C,
         TX_ENABLE_G         => true,
         RX_ENABLE_G         => true,
         COMMON_TX_CLK_G     => true,   -- Set to true if sAxisClk and clk are the same clock
         COMMON_RX_CLK_G     => true,   -- Set to true if mAxisClk and clk are the same clock      
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(4),
         MASTER_AXI_CONFIG_G => ssiAxiStreamConfig(4))
      port map (
         -- TX Serial Stream
         txP         => loopBackP,
         txN         => loopBackN,
         -- RX Serial Stream
         rxP         => loopBackP,
         rxN         => loopBackN,
         -- Reference Signals
         clk125MHz   => clk,
         rst125MHz   => rst,
         clk104MHz   => clk104MHz,
         clk208MHz   => clk208MHz,
         clk625MHz   => clk625MHz,
         linkUp      => linkUp,
         mmcmLocked  => iDelayCtrlRdy,
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => ibSaltMaster,
         sAxisSlave  => ibSaltSlave,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => obSaltMaster,
         mAxisSlave  => obSaltSlave);    

   ---------------
   -- Data Checker
   ---------------
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
         SLAVE_AXI_STREAM_CONFIG_G  => ssiAxiStreamConfig(4),
         SLAVE_AXI_PIPE_STAGES_G    => 1,
         MASTER_AXI_STREAM_CONFIG_G => ssiAxiStreamConfig(4),  -- unused
         MASTER_AXI_PIPE_STAGES_G   => 0)                      -- unused
      port map (
         -- Streaming RX Data Interface (sAxisClk domain) 
         sAxisClk        => clk,
         sAxisRst        => rst,
         sAxisMaster     => obSaltMaster,
         sAxisSlave      => obSaltSlave,
         -- Optional: Streaming TX Data Interface (mAxisClk domain)
         mAxisClk        => clk,
         mAxisRst        => rst,
         mAxisMaster     => open,
         mAxisSlave      => AXI_STREAM_SLAVE_FORCE_C,
         -- Optional: AXI-Lite Register Interface (axiClk domain)
         axiClk          => clk,
         axiRst          => rst,
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

   process(clk)
   begin
      if rising_edge(clk) then
         passedDly <= passed after TPD_C;
         failedDly <= failed after TPD_C;
         -- if flowCnt(7) = '1' then
         -- pgpRxCtrl(0) <= sAxisCtrl;
         -- else
         -- pgpRxCtrl(0) <= AXI_STREAM_CTRL_INIT_C;
         -- end if;
         -- flowCnt <= flowCnt + 1 after TPD_C;
         if rst = '1' then
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

   process(failedDly, passedDly)
   begin
      if failedDly = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;
      if passedDly = '1' then
         assert false
            report "Simulation Passed!" severity failure;
      end if;
   end process;

end testbed;
