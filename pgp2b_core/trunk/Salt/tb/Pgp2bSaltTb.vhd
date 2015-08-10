-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Pgp2bSaltTb.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-10
-- Last update: 2015-08-10
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the Pgp2bSalt module
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.Pgp2bPkg.all;

entity Pgp2bSaltTb is end Pgp2bSaltTb;

architecture testbed of Pgp2bSaltTb is

   -- General Configurations
   constant SLOW_PERIOD_C      : time             := 10 ns;
   constant FAST_PERIOD_C      : time             := (SLOW_PERIOD_C/2);
   constant TPD_C              : time             := 1 ns;
   constant STATUS_CNT_WIDTH_C : natural          := 32;
   constant AXI_ERROR_RESP_C   : slv(1 downto 0)  := AXI_RESP_SLVERR_C;
   constant TX_PACKET_LENGTH_C : slv(31 downto 0) := toSlv(256, 32);
   constant NUMBER_PACKET_C    : slv(31 downto 0) := x"00000FFF";

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
   constant AXI_STREAM_CONFIG_C : AxiStreamConfigType := SSI_PGP2B_CONFIG_C;
   constant AXI_PIPE_STAGES_C   : natural             := 1;

   signal clk      : sl := '0';
   signal rst      : sl := '0';
   signal clk2x    : sl := '0';
   signal clk2xRst : sl := '0';
   signal clk2xInv : sl := '0';

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

   signal errWordCnt : slv(31 downto 0) := (others => '0');
   signal errbitCnt  : slv(31 downto 0) := (others => '0');
   signal cnt        : slv(31 downto 0) := (others => '0');
   signal flowCnt    : slv(7 downto 0)  := (others => '0');

   signal pgpRxOut     : Pgp2bRxOutType;
   signal pgpTxOut     : Pgp2bTxOutType;
   signal pgpTxMasters : AxiStreamMasterArray(3 downto 0);
   signal pgpTxSlaves  : AxiStreamSlaveArray(3 downto 0);
   signal pgpRxMasters : AxiStreamMasterArray(3 downto 0);
   signal pgpRxCtrl    : AxiStreamCtrlArray(3 downto 0);
   signal sAxisCtrl    : AxiStreamCtrlType;
   
begin

   -----------------------------
   -- Generate clocks and resets
   -----------------------------
   ClkRst_Local_Slow : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => SLOW_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => clk,
         clkN => open,
         rst  => rst,
         rstL => open);          

   ClkRst_Local_Fast : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => FAST_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => clk2x,
         clkN => clk2xInv,
         rst  => clk2xRst,
         rstL => open);      

   SaltDelayCtrl_Inst : entity work.SaltDelayCtrl
      generic map (
         TPD_G => TPD_C)
      port map (
         ready  => open,
         refclk => clk2x,
         refRst => clk2xRst); 

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
         MASTER_AXI_STREAM_CONFIG_G => SSI_PGP2B_CONFIG_C,
         MASTER_AXI_PIPE_STAGES_G   => 1)        
      port map (
         -- Master Port (mAxisClk)
         mAxisClk     => clk,
         mAxisRst     => rst,
         mAxisMaster  => pgpTxMasters(0),
         mAxisSlave   => pgpTxSlaves(0),
         -- Trigger Signal (locClk domain)
         locClk       => clk,
         locRst       => rst,
         trig         => '1',
         packetLength => TX_PACKET_LENGTH_C,
         forceEofe    => FORCE_EOFE_C,
         busy         => open,
         tDest        => (others => '0'),
         tId          => (others => '0'));    

   ----------------------         
   -- Module to be tested
   ----------------------   
   Pgp2bSalt_Inst : entity work.Pgp2bSalt
      generic map (
         TPD_G             => TPD_C,
         ----------------
         -- SALT Settings
         ----------------
         XIL_DEVICE_G      => "ULTRASCALE",
         RXCLK2X_FREQ_G    => 200.0,
         IODELAY_GROUP_G   => "SALT_IODELAY_GRP",
         ---------------
         -- PGP Settings
         ---------------
         PGP_RX_ENABLE_G   => true,
         PGP_TX_ENABLE_G   => true,
         PAYLOAD_CNT_TOP_G => 7,
         VC_INTERLEAVE_G   => 1,
         NUM_VC_EN_G       => 4)
      port map (
         -- TX Serial Stream
         txP           => loopBackP,
         txN           => loopBackN,
         -- RX Serial Stream
         rxP           => loopBackP,
         rxN           => loopBackN,
         -- Tx Clocking
         pgpTxClk      => clk,
         pgpTxRst      => Rst,
         -- Rx clocking
         pgpRxClk      => clk,
         pgpRxClk2x    => clk2x,
         pgpRxClk2xInv => clk2xInv,
         pgpRxRst      => Rst,
         -- IODELAY Ref. Clock and Reset
         refClk        => clk2x,
         refRst        => clk2xRst,
         -- Non VC Rx Signals
         pgpRxIn       => PGP2B_RX_IN_INIT_C,
         pgpRxOut      => pgpRxOut,
         -- Non VC Tx Signals
         pgpTxIn       => PGP2B_TX_IN_INIT_C,
         pgpTxOut      => pgpTxOut,
         -- Frame Transmit Interface - Array of 4 VCs
         pgpTxMasters  => pgpTxMasters,
         pgpTxSlaves   => pgpTxSlaves,
         -- Frame Receive Interface - Array of 4 VCs
         pgpRxMasters  => pgpRxMasters,
         pgpRxCtrl     => pgpRxCtrl);         

   pgpTxMasters(3 downto 1) <= (others => AXI_STREAM_MASTER_INIT_C);
   pgpRxCtrl(3 downto 1)    <= (others => AXI_STREAM_CTRL_UNUSED_C);

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
         SLAVE_AXI_STREAM_CONFIG_G  => SSI_PGP2B_CONFIG_C,
         SLAVE_AXI_PIPE_STAGES_G    => 1,
         MASTER_AXI_STREAM_CONFIG_G => ssiAxiStreamConfig(4),  -- unused
         MASTER_AXI_PIPE_STAGES_G   => 0)                      -- unused
      port map (
         -- Streaming RX Data Interface (sAxisClk domain) 
         sAxisClk        => clk,
         sAxisRst        => rst,
         sAxisMaster     => pgpRxMasters(0),
         sAxisSlave      => open,
--         sAxisCtrl       => sAxisCtrl,
         sAxisCtrl       => pgpRxCtrl(0),
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
