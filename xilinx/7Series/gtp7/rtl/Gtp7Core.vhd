-------------------------------------------------------------------------------
-- File       : Gtp7Core.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-06-29
-- Last update: 2016-12-15
-------------------------------------------------------------------------------
-- Description: Wrapper for Xilinx 7-series GTP primitive
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

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity Gtp7Core is

   generic (
      TPD_G : time := 1 ns;

      -- Sim Generics --
      SIM_GTRESET_SPEEDUP_G : string := "FALSE";
      SIM_VERSION_G         : string := "1.0";

      SIMULATION_G : boolean := false;

      STABLE_CLOCK_PERIOD_G : real := 4.0E-9;   --units of seconds
      REF_CLK_FREQ_G        : real := 125.0E6;  -- Only needed if Fixed Latency used

      -- TX/RX Settings --
      RXOUT_DIV_G      : integer    := 2;
      TXOUT_DIV_G      : integer    := 2;
      RX_CLK25_DIV_G   : integer    := 5;                         -- Set by wizard
      TX_CLK25_DIV_G   : integer    := 5;                         -- Set by wizard
      PMA_RSV_G        : bit_vector := x"00000333";               -- Set by wizard 
      RX_OS_CFG_G      : bit_vector := "0001111110000";           -- Set by wizard
      RXCDR_CFG_G      : bit_vector := x"0000107FE206001041010";  -- Set by wizard
      RXLPM_INCM_CFG_G : bit        := '1';                       -- Set by wizard
      RXLPM_IPCM_CFG_G : bit        := '0';                       -- Set by wizard

      -- Configure PLL sources
      TX_PLL_G : string := "PLL0";
      RX_PLL_G : string := "PLL1";

      -- Configure Data widths
      TX_EXT_DATA_WIDTH_G : integer := 16;
      TX_INT_DATA_WIDTH_G : integer := 20;
      TX_8B10B_EN_G       : boolean := true;

      RX_EXT_DATA_WIDTH_G : integer := 16;
      RX_INT_DATA_WIDTH_G : integer := 20;
      RX_8B10B_EN_G       : boolean := true;

      -- Configure Buffer usage
      TX_BUF_EN_G        : boolean := true;
      TX_OUTCLK_SRC_G    : string  := "PLLREFCLK";  -- or "OUTCLKPMA" when bypassing buffer
      TX_DLY_BYPASS_G    : sl      := '1';          -- 1 for bypass, 0 for delay
      TX_PHASE_ALIGN_G   : string  := "AUTO";       -- Or "MANUAL" or "NONE"
      TX_BUF_ADDR_MODE_G : string  := "FAST";       -- Or "FULL"

      RX_BUF_EN_G        : boolean := true;
      RX_OUTCLK_SRC_G    : string  := "PLLREFCLK";  -- or "OUTCLKPMA" when bypassing buffer
      RX_USRCLK_SRC_G    : string  := "RXOUTCLK";   -- or "TXOUTCLK"
      RX_DLY_BYPASS_G    : sl      := '1';          -- 1 for bypass, 0 for delay
      RX_DDIEN_G         : sl      := '0';          -- Supposed to be '1' when bypassing rx buffer
      RX_BUF_ADDR_MODE_G : string  := "FAST";

      -- Configure RX comma alignment
      RX_ALIGN_MODE_G      : string     := "GT";   -- Or "FIXED_LAT" or "NONE"
      ALIGN_COMMA_DOUBLE_G : string     := "FALSE";
      ALIGN_COMMA_ENABLE_G : bit_vector := "1111111111";
      ALIGN_COMMA_WORD_G   : integer    := 2;
      ALIGN_MCOMMA_DET_G   : string     := "FALSE";
      ALIGN_MCOMMA_VALUE_G : bit_vector := "1010000011";
      ALIGN_MCOMMA_EN_G    : sl         := '0';
      ALIGN_PCOMMA_DET_G   : string     := "FALSE";
      ALIGN_PCOMMA_VALUE_G : bit_vector := "0101111100";
      ALIGN_PCOMMA_EN_G    : sl         := '0';
      SHOW_REALIGN_COMMA_G : string     := "FALSE";
      RXSLIDE_MODE_G       : string     := "PCS";  -- Set to PMA for fixed latency operation

      -- Fixed Latency comma alignment (If RX_ALIGN_MODE_G = "FIXED_LAT")
      FIXED_COMMA_EN_G      : slv(3 downto 0) := "0011";
      FIXED_ALIGN_COMMA_0_G : slv             := "----------0101111100";
      FIXED_ALIGN_COMMA_1_G : slv             := "----------1010000011";
      FIXED_ALIGN_COMMA_2_G : slv             := "XXXXXXXXXXXXXXXXXXXX";
      FIXED_ALIGN_COMMA_3_G : slv             := "XXXXXXXXXXXXXXXXXXXX";

      -- Configure RX 8B10B decoding (If RX_8B10B_EN_G = true)
      RX_DISPERR_SEQ_MATCH_G : string := "TRUE";
      DEC_MCOMMA_DETECT_G    : string := "TRUE";
      DEC_PCOMMA_DETECT_G    : string := "TRUE";
      DEC_VALID_COMMA_ONLY_G : string := "FALSE";

      -- Configure Clock Correction
      CBCC_DATA_SOURCE_SEL_G : string     := "DECODED";
      CLK_COR_SEQ_2_USE_G    : string     := "FALSE";
      CLK_COR_KEEP_IDLE_G    : string     := "FALSE";
      CLK_COR_MAX_LAT_G      : integer    := 9;
      CLK_COR_MIN_LAT_G      : integer    := 7;
      CLK_COR_PRECEDENCE_G   : string     := "TRUE";
      CLK_COR_REPEAT_WAIT_G  : integer    := 0;
      CLK_COR_SEQ_LEN_G      : integer    := 1;
      CLK_COR_SEQ_1_ENABLE_G : bit_vector := "1111";
      CLK_COR_SEQ_1_1_G      : bit_vector := "0100000000";  -- UG476 pg 249
      CLK_COR_SEQ_1_2_G      : bit_vector := "0000000000";
      CLK_COR_SEQ_1_3_G      : bit_vector := "0000000000";
      CLK_COR_SEQ_1_4_G      : bit_vector := "0000000000";
      CLK_CORRECT_USE_G      : string     := "FALSE";
      CLK_COR_SEQ_2_ENABLE_G : bit_vector := "0000";
      CLK_COR_SEQ_2_1_G      : bit_vector := "0100000000";  -- UG476 pg 249
      CLK_COR_SEQ_2_2_G      : bit_vector := "0000000000";
      CLK_COR_SEQ_2_3_G      : bit_vector := "0000000000";
      CLK_COR_SEQ_2_4_G      : bit_vector := "0000000000";

      -- Configure Channel Bonding
      RX_CHAN_BOND_EN_G        : boolean    := false;
      RX_CHAN_BOND_MASTER_G    : boolean    := false;  --True: Master, False: Slave
      CHAN_BOND_KEEP_ALIGN_G   : string     := "FALSE";
      CHAN_BOND_MAX_SKEW_G     : integer    := 1;
      CHAN_BOND_SEQ_LEN_G      : integer    := 1;
      CHAN_BOND_SEQ_1_1_G      : bit_vector := "0000000000";
      CHAN_BOND_SEQ_1_2_G      : bit_vector := "0000000000";
      CHAN_BOND_SEQ_1_3_G      : bit_vector := "0000000000";
      CHAN_BOND_SEQ_1_4_G      : bit_vector := "0000000000";
      CHAN_BOND_SEQ_1_ENABLE_G : bit_vector := "1111";
      CHAN_BOND_SEQ_2_1_G      : bit_vector := "0000000000";
      CHAN_BOND_SEQ_2_2_G      : bit_vector := "0000000000";
      CHAN_BOND_SEQ_2_3_G      : bit_vector := "0000000000";
      CHAN_BOND_SEQ_2_4_G      : bit_vector := "0000000000";
      CHAN_BOND_SEQ_2_ENABLE_G : bit_vector := "0000";
      CHAN_BOND_SEQ_2_USE_G    : string     := "FALSE";
      FTS_DESKEW_SEQ_ENABLE_G  : bit_vector := "1111";
      FTS_LANE_DESKEW_CFG_G    : bit_vector := "1111";
      FTS_LANE_DESKEW_EN_G     : string     := "FALSE");
   port (
      stableClkIn : in sl;              -- Freerunning clock needed to drive reset logic

      qPllRefClkIn     : in  slv(1 downto 0);
      qPllClkIn        : in  slv(1 downto 0);
      qPllLockIn       : in  slv(1 downto 0);
      qPllRefClkLostIn : in  slv(1 downto 0);
      qPllResetOut     : out slv(1 downto 0);
      gtRxRefClkBufg   : in  sl := '0';  -- In fixed latency mode, need BUF'd version of gt rx
                                         -- reference clock to check if recovered clock is stable

      -- Serial IO
      gtTxP : out sl;
      gtTxN : out sl;
      gtRxP : in  sl;
      gtRxN : in  sl;

      -- Rx Clock related signals
      rxOutClkOut    : out sl;
      rxUsrClkIn     : in  sl;
      rxUsrClk2In    : in  sl;
      rxUserRdyOut   : out sl;
      rxMmcmResetOut : out sl;
      rxMmcmLockedIn : in  sl := '1';

      -- Rx User Reset Signals
      rxUserResetIn  : in  sl;
      rxResetDoneOut : out sl;

      -- Manual Comma Align signals
      rxDataValidIn : in sl := '1';
      rxSlideIn     : in sl := '0';

      -- Rx Data and decode signals
      rxDataOut      : out slv(RX_EXT_DATA_WIDTH_G-1 downto 0);
      rxCharIsKOut   : out slv((RX_EXT_DATA_WIDTH_G/8)-1 downto 0);  -- If WIDTH not mult of 8 then
      rxDecErrOut    : out slv((RX_EXT_DATA_WIDTH_G/8)-1 downto 0);  -- not using 8b10b and these dont matter
      rxDispErrOut   : out slv((RX_EXT_DATA_WIDTH_G/8)-1 downto 0);
      rxPolarityIn   : in  sl := '0';
      rxBufStatusOut : out slv(2 downto 0);

      -- Rx Channel Bonding
      rxChBondLevelIn : in  slv(2 downto 0) := "000";
      rxChBondIn      : in  slv(3 downto 0) := "0000";
      rxChBondOut     : out slv(3 downto 0);

      -- Tx Clock Related Signals
      txOutClkOut    : out sl;
      txUsrClkIn     : in  sl;
      txUsrClk2In    : in  sl;
      txUserRdyOut   : out sl;          -- txOutClk is valid
      txMmcmResetOut : out sl;
      txMmcmLockedIn : in  sl := '1';

      -- Tx User Reset signals
      txUserResetIn  : in  sl;
      txResetDoneOut : out sl;

      -- Tx Data
      txDataIn       : in  slv(TX_EXT_DATA_WIDTH_G-1 downto 0);
      txCharIsKIn    : in  slv((TX_EXT_DATA_WIDTH_G/8)-1 downto 0);
      txBufStatusOut : out slv(1 downto 0);
      txPolarityIn   : in  sl               := '0';
      -- Debug Interface      
      txPowerDown    : in  slv(1 downto 0)  := "00";
      rxPowerDown    : in  slv(1 downto 0)  := "00";
      loopbackIn     : in  slv(2 downto 0)  := "000";
      txPreCursor    : in  slv(4 downto 0)  := (others => '0');
      txPostCursor   : in  slv(4 downto 0)  := (others => '0');
      txDiffCtrl     : in  slv(3 downto 0)  := "1000";
      -- DRP Interface (stableClkIn Domain)
      drpGnt         : out sl;
      drpRdy         : out sl;
      drpEn          : in  sl               := '0';
      drpWe          : in  sl               := '0';
      drpAddr        : in  slv(8 downto 0)  := "000000000";
      drpDi          : in  slv(15 downto 0) := X"0000";
      drpDo          : out slv(15 downto 0));
end entity Gtp7Core;

architecture rtl of Gtp7Core is

   function getOutClkSelVal (OUT_CLK_SRC : string) return bit_vector is
   begin
      if (OUT_CLK_SRC = "PLLREFCLK") then
         return "011";
      elsif (OUT_CLK_SRC = "OUTCLKPMA") then
         return "010";
      elsif (OUT_CLK_SRC = "PLLREFDV2") then
         return "100";
      else
         return "000";
      end if;
   end function getOutClkSelVal;

   function getDataWidth (USE_8B10B : boolean; EXT_DATA_WIDTH : integer) return integer is
   begin
      if (USE_8B10B = false) then
         return EXT_DATA_WIDTH;
      else
         return (EXT_DATA_WIDTH / 8) * 10;
      end if;
   end function;

   --------------------------------------------------------------------------------------------------
   -- Constants
   --------------------------------------------------------------------------------------------------
   constant RX_SYSCLK_SEL_C : slv := ite(RX_PLL_G = "PLL0", "00", "11");
   constant TX_SYSCLK_SEL_C : slv := ite(TX_PLL_G = "PLL0", "00", "11");

   constant RX_PLL0_USED_C : boolean := (RX_PLL_G = "PLL0");
   constant TX_PLL0_USED_C : boolean := (TX_PLL_G = "PLL0");

   constant RX_XCLK_SEL_C : string := ite(RX_BUF_EN_G, "RXREC", "RXUSR");
   constant TX_XCLK_SEL_C : string := ite(TX_BUF_EN_G, "TXOUT", "TXUSR");

   constant RX_OUTCLK_SEL_C : bit_vector := getOutClkSelVal(RX_OUTCLK_SRC_G);
   constant TX_OUTCLK_SEL_C : bit_vector := getOutClkSelVal(TX_OUTCLK_SRC_G);

   constant RX_DATA_WIDTH_C : integer := getDataWidth(RX_8B10B_EN_G, RX_EXT_DATA_WIDTH_G);
   constant TX_DATA_WIDTH_C : integer := getDataWidth(TX_8B10B_EN_G, TX_EXT_DATA_WIDTH_G);

   constant GT_TYPE_C : string := "GTP";

   constant WAIT_TIME_CDRLOCK_C : integer := ite(SIM_GTRESET_SPEEDUP_G = "TRUE", 16, 165520);

   --------------------------------------------------------------------------------------------------
   -- Signals
   --------------------------------------------------------------------------------------------------

   ----------------------------
   -- Rx Signals
   signal rxOutClk     : sl;
   signal rxOutClkBufg : sl;

   signal rxPllResets     : slv(1 downto 0);
   signal rxPllLock       : sl;

   signal gtRxReset    : sl;            -- GT GTRXRESET
   signal rxResetDone  : sl;            -- GT RXRESETDONE
   signal rxUserRdyInt : sl;            -- GT RXUSERRDY

   signal rxUserResetInt : sl;
   signal rxFsmResetDone : sl;
   signal rxRstTxUserRdy : sl;
   signal rxPmaResetDone : sl;

   signal rxRecClkStable         : sl;
   signal rxRecClkMonitorRestart : sl;
   signal rxCdrLockCnt           : integer range 0 to WAIT_TIME_CDRLOCK_C := 0;

   signal rxRunPhaseAlignment  : sl;
   signal rxPhaseAlignmentDone : sl;
   signal rxAlignReset         : sl;
   signal rxDlySReset          : sl;    -- GT RXDLYSRESET
   signal rxDlySResetDone      : sl;    -- GT RXDLYSRESETDONE
   signal rxPhAlignDone        : sl;    -- GT RXPHALIGNDONE
   signal rxSlide              : sl;    -- GT RXSLIDE
   signal rxCdrLock            : sl;    -- GT RXCDRLOCK

   signal rxDfeAgcHold : sl := '0';
   signal rxDfeLfHold  : sl := '0';
   signal rxLpmLfHold  : sl := '0';
   signal rxLpmHfHold  : sl := '0';

   -- Rx Data
   signal rxDataInt     : slv(RX_EXT_DATA_WIDTH_G-1 downto 0);
   signal rxDataFull    : slv(31 downto 0);  -- GT RXDATA
   signal rxCharIsKFull : slv(3 downto 0);   -- GT RXCHARISK
   signal rxDispErrFull : slv(3 downto 0);   -- GT RXDISPERR
   signal rxDecErrFull  : slv(3 downto 0);

   ----------------------------
   -- Tx Signals
   signal txOutClk : sl;

   signal txPllResets     : slv(1 downto 0);

   signal gtTxReset    : sl;            -- GT GTTXRESET
   signal txResetDone  : sl;            -- GT TXRESETDONE
   signal txUserRdyInt : sl;            -- GT TXUSERRDY

   signal txFsmResetDone : sl;
   signal txPmaResetDone : sl;


   signal txResetPhaseAlignment : sl;
   signal txRunPhaseAlignment   : sl;
   signal txPhaseAlignmentDone  : sl;
   signal txPhAlignEn           : sl;   -- GT TXPHALIGNEN
   signal txDlySReset           : sl;   -- GT TXDLYSRESET
   signal txDlySResetDone       : sl;   -- GT TXDLYSRESETDONE
   signal txPhInit              : sl;   -- GT TXPHINIT
   signal txPhInitDone          : sl;   -- GT TXPHINITDONE
   signal txPhAlign             : sl;   -- GT TXPHALIGN
   signal txPhAlignDone         : sl;   -- GT TXPHALIGNDONE
   signal txDlyEn               : sl;   -- GT TXDLYEN

   -- Tx Data Signals
   signal txDataFull     : slv(31 downto 0) := (others => '0');
   signal txCharIsKFull  : slv(3 downto 0)  := (others => '0');
   signal txCharDispMode : slv(3 downto 0)  := (others => '0');
   signal txCharDispVal  : slv(3 downto 0)  := (others => '0');

   -- DRP Signals
   signal drpMuxAddr : slv(8 downto 0);
   signal drpMuxDo   : slv(15 downto 0);
   signal drpMuxDi   : slv(15 downto 0);
   signal drpMuxRdy  : sl;
   signal drpMuxEn   : sl;
   signal drpMuxWe   : sl;
   signal drpRstAddr : slv(8 downto 0);
   signal drpRstDo   : slv(15 downto 0);
   signal drpRstDi   : slv(15 downto 0);
   signal drpRstRdy  : sl;
   signal drpRstEn   : sl;
   signal drpRstWe   : sl;
   signal drpRstDone : sl;
   signal gtRxRst    : sl;

begin

   txOutClkOut <= txOutClk;

   rxOutClkOut     <= rxOutClkBufg;
   qPllResetOut(0) <= rxPllResets(0) or txPllResets(0);
   qPllResetOut(1) <= rxPllResets(1) or txPllResets(1);

   rxPllLock <= qPllLockIn(0) when RX_PLL0_USED_C else qPllLockIn(1);

   --------------------------------------------------------------------------------------------------
   -- Rx Logic
   --------------------------------------------------------------------------------------------------
   -- Fit GTP port sizes to selected rx external interface size
   rxDataOut <= rxDataInt;
   RX_DATA_8B10B_GLUE : process (rxCharIsKFull, rxDataFull, rxDecErrFull,
                                 rxDispErrFull) is
   begin
      if (RX_8B10B_EN_G) then
         rxDataInt    <= rxDataFull(RX_EXT_DATA_WIDTH_G-1 downto 0);
         rxCharIsKOut <= rxCharIsKFull((RX_EXT_DATA_WIDTH_G/8)-1 downto 0);
         rxDispErrOut <= rxDispErrFull((RX_EXT_DATA_WIDTH_G/8)-1 downto 0);
         rxDecErrOut  <= rxDecErrFull((RX_EXT_DATA_WIDTH_G/8)-1 downto 0);
      else
         for i in RX_EXT_DATA_WIDTH_G-1 downto 0 loop
            if ((i-9) mod 10 = 0) then
               rxDataInt(i) <= rxDispErrFull((i-9)/10);
            elsif ((i-8) mod 10 = 0) then
               rxDataInt(i) <= rxCharIsKFull((i-8)/10);
            else
               rxDataInt(i) <= rxDataFull(i-2*(i/10));
            end if;
         end loop;
         rxCharIsKOut <= (others => '0');
         rxDispErrOut <= (others => '0');
         rxDecErrOut  <= (others => '0');
      end if;
   end process RX_DATA_8B10B_GLUE;

   rxUserResetInt <= rxUserResetIn or rxAlignReset;
   rxRstTxUserRdy <= txUserRdyInt when RX_USRCLK_SRC_G = "TXOUTCLK" else '1';

   -- Drive outputs that have internal use
   rxUserRdyOut <= rxUserRdyInt;

   --------------------------------------------------------------------------------------------------
   -- Rx Reset Module
   -- 1. Reset RX PLL,
   -- 2. Wait PLL Lock
   -- 3. Wait recclk_stable
   -- 4. Reset MMCM
   -- 5. Wait MMCM Lock
   -- 6. Assert gtRxUserRdy (gtRxUsrClk now usable)
   -- 7. Wait gtRxResetDone
   -- 8. Do phase alignment if necessary
   -- 9. Wait DATA_VALID (aligned) - 100 us
   --10. Wait 1 us, Set rxFsmResetDone. 
   --------------------------------------------------------------------------------------------------
   Gtp7RxRst_Inst : entity work.Gtp7RxRst
      generic map (
         TPD_G                  => TPD_G,
         SIMULATION_G => SIMULATION_G,
         STABLE_CLOCK_PERIOD    => getTimeRatio(STABLE_CLOCK_PERIOD_G, 1.0E-9),
         RETRY_COUNTER_BITWIDTH => 8,
         TX_PLL0_USED           => TX_PLL0_USED_C,
         RX_PLL0_USED           => RX_PLL0_USED_C)
      port map (
         STABLE_CLOCK           => stableClkIn,
         RXUSERCLK              => rxUsrClkIn,
         SOFT_RESET             => rxUserResetInt,
         RXPMARESETDONE         => rxPmaResetDone,
         RXOUTCLK               => rxOutClkBufg,
         PLL0REFCLKLOST         => qPllRefClkLostIn(0),
         PLL1REFCLKLOST         => qPllRefClkLostIn(1),
         PLL0LOCK               => qPllLockIn(0),
         PLL1LOCK               => qPllLockIn(1),
         RXRESETDONE            => rxResetDone,           -- From GT
         MMCM_LOCK              => rxMmcmLockedIn,
         RECCLK_STABLE          => rxRecClkStable,        -- Asserted after 50,000 UI as per DS183
         RECCLK_MONITOR_RESTART => rxRecClkMonitorRestart,
         DATA_VALID             => rxDataValidIn,         -- From external decoder if used
         TXUSERRDY              => rxRstTxUserRdy,        -- Need to know when txUserRdy
         GTRXRESET              => gtRxReset,             -- To GT
         MMCM_RESET             => rxMmcmResetOut,
         PLL0_RESET             => rxPllResets(0),
         PLL1_RESET             => rxPllResets(1),
         RX_FSM_RESET_DONE      => rxFsmResetDone,
         RXUSERRDY              => rxUserRdyInt,          -- To GT
         RUN_PHALIGNMENT        => rxRunPhaseAlignment,   -- To Phase Alignment module
         PHALIGNMENT_DONE       => rxPhaseAlignmentDone,  -- From Phase Alignment module
         RESET_PHALIGNMENT      => open,                  -- For manual phase align
         RXDFEAGCHOLD           => rxDfeAgcHold,          -- Explore using these later
         RXDFELFHOLD            => rxDfeLfHold,
         RXLPMLFHOLD            => rxLpmLfHold,
         RXLPMHFHOLD            => rxLpmHfHold,
         RETRY_COUNTER          => open);

   --------------------------------------------------------------------------------------------------
   -- Synchronize rxFsmResetDone to rxUsrClk to use as reset for external logic.
   --------------------------------------------------------------------------------------------------
   RstSync_RxResetDone : entity work.RstSync
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '0',
         OUT_POLARITY_G => '0')
      port map (
         clk      => rxUsrClkIn,
         asyncRst => rxFsmResetDone,
         syncRst  => rxResetDoneOut);   -- Output

   -------------------------------------------------------------------------------------------------
   -- Recovered clock monitor
   -------------------------------------------------------------------------------------------------
   BUFG_RX_OUT_CLK : BUFG
      port map (
         I => rxOutClk,
         O => rxOutClkBufg);

--   GTX7_RX_REC_CLK_MONITOR_GEN : if (RX_BUF_EN_G = false) generate
--      SyncClockFreq_1 : entity work.SyncClockFreq
--         generic map (
--            TPD_G             => TPD_G,
--            REF_CLK_FREQ_G    => REF_CLK_FREQ_G,
--            REFRESH_RATE_G    => 1.0E3,
--            CLK_LOWER_LIMIT_G => REF_CLK_FREQ_G * (1.010),
--            CLK_UPPER_LIMIT_G => REF_CLK_FREQ_G * (0.990),
--            CNT_WIDTH_G       => 32)
--         port map (
--            freqOut     => open,
--            freqUpdated => rxRecClkMonitorRestart,
--            locked      => rxRecClkStable,
--            tooFast     => open,
--            tooSlow     => open,
--            clkIn       => rxOutClkBufg,
--            locClk      => stableClkIn,
--            refClk      => gtRxRefClkBufg);

--   end generate;

--   RX_NO_RECCLK_MON_GEN : if (RX_BUF_EN_G) generate
   rxRecClkMonitorRestart <= '0';
   process(stableClkIn)
   begin
      if rising_edge(stableClkIn) then
         if gtRxReset = '1' then
            rxRecClkStable <= '0' after TPD_G;
            rxCdrLockCnt   <= 0   after TPD_G;
         elsif rxRecClkStable = '0' then
            if rxCdrLockCnt = WAIT_TIME_CDRLOCK_C then
               rxRecClkStable <= '1'          after TPD_G;
               rxCdrLockCnt   <= rxCdrLockCnt after TPD_G;
            else
               rxCdrLockCnt <= rxCdrLockCnt + 1 after TPD_G;
            end if;
         end if;
      end if;
   end process;
--   end generate RX_NO_RECCLK_MON_GEN;

   -------------------------------------------------------------------------------------------------
   -- Phase alignment needed when rx buffer is disabled
   -- Use normal Auto Phase Align module when RX_BUF_EN_G=false and RX_ALIGN_FIXED_LAT_G=false
   -- Use special fixed latency aligner when RX_BUF_EN_G=false and RX_ALIGN_FIXED_LAT_G=true
   -------------------------------------------------------------------------------------------------
   RX_AUTO_ALIGN_GEN : if (RX_BUF_EN_G = false and RX_ALIGN_MODE_G = "GT") generate
      Gtp7AutoPhaseAligner_Rx : entity work.Gtp7AutoPhaseAligner
         generic map (
            GT_TYPE => GT_TYPE_C)
         port map (
            STABLE_CLOCK         => stableClkIn,
            RUN_PHALIGNMENT      => rxRunPhaseAlignment,   -- From RxRst
            PHASE_ALIGNMENT_DONE => rxPhaseAlignmentDone,  -- To RxRst
            PHALIGNDONE          => rxPhAlignDone,         -- From gt
            DLYSRESET            => rxDlySReset,           -- To gt
            DLYSRESETDONE        => rxDlySResetDone,       -- From gt
            RECCLKSTABLE         => rxRecClkStable);
      rxSlide      <= rxSlideIn;                           -- User controlled rxSlide
      rxAlignReset <= '0';
   end generate;

   RX_FIX_LAT_ALIGN_GEN : if (RX_BUF_EN_G = false and RX_ALIGN_MODE_G = "FIXED_LAT") generate
      Gtp7RxFixedLatPhaseAligner_Inst : entity work.Gtp7RxFixedLatPhaseAligner
         generic map (
            TPD_G       => TPD_G,
            WORD_SIZE_G => RX_EXT_DATA_WIDTH_G,
            COMMA_EN_G  => FIXED_COMMA_EN_G,
            COMMA_0_G   => FIXED_ALIGN_COMMA_0_G,
            COMMA_1_G   => FIXED_ALIGN_COMMA_1_G,
            COMMA_2_G   => FIXED_ALIGN_COMMA_2_G,
            COMMA_3_G   => FIXED_ALIGN_COMMA_3_G)
         port map (
            rxUsrClk             => rxUsrClkIn,
            rxRunPhAlignment     => rxRunPhaseAlignment,
            rxData               => rxDataInt,
            rxReset              => rxAlignReset,
            rxSlide              => rxSlide,
            rxPhaseAlignmentDone => rxPhaseAlignmentDone);
      rxDlySReset <= '0';
   end generate;

   RX_NO_ALIGN_GEN : if (RX_BUF_EN_G = true or RX_ALIGN_MODE_G = "NONE") generate
      rxPhaseAlignmentDone <= '1';
      rxSlide              <= rxSlideIn;
      rxDlySReset          <= '0';
      rxAlignReset         <= '0';
   end generate;

   --------------------------------------------------------------------------------------------------
   -- Tx Logic
   --------------------------------------------------------------------------------------------------

   TX_DATA_8B10B_GLUE : process (txCharIsKIn, txDataIn) is
   begin
      if (TX_8B10B_EN_G) then
         txDataFull                                        <= (others => '0');
         txDataFull(TX_EXT_DATA_WIDTH_G-1 downto 0)        <= txDataIn;
         txCharIsKFull                                     <= (others => '0');
         txCharIsKFull((TX_EXT_DATA_WIDTH_G/8)-1 downto 0) <= txCharIsKIn;
         txCharDispMode                                    <= (others => '0');
         txCharDispVal                                     <= (others => '0');
      else
         for i in TX_EXT_DATA_WIDTH_G-1 downto 0 loop
            if ((i-9) mod 10 = 0) then
               txCharDispMode((i-9)/10) <= txDataIn(i);
            elsif ((i-8) mod 10 = 0) then
               txCharDispVal((i-8)/10) <= txDataIn(i);
            else
               txDataFull(i-2*(i/10)) <= txDataIn(i);
            end if;
         end loop;
         txCharIsKFull <= (others => '0');
      end if;
   end process TX_DATA_8B10B_GLUE;

   -- Drive outputs that have internal use
   txUserRdyOut <= txUserRdyInt;

   --------------------------------------------------------------------------------------------------
   -- Tx Reset Module
   --------------------------------------------------------------------------------------------------
   Gtp7TxRst_Inst : entity work.Gtp7TxRst
      generic map (
         TPD_G                  => TPD_G,
         STABLE_CLOCK_PERIOD    => getTimeRatio(STABLE_CLOCK_PERIOD_G, 1.0E-9),
         RETRY_COUNTER_BITWIDTH => 8,
         TX_PLL0_USED           => TX_PLL0_USED_C)
      port map (
         STABLE_CLOCK      => stableClkIn,
         TXUSERCLK         => txUsrClkIn,
         SOFT_RESET        => txUserResetIn,
         TXPMARESETDONE    => txPmaResetDone,
         TXOUTCLK          => txOutClk,
         PLL0REFCLKLOST    => qPllRefClkLostIn(0),
         PLL1REFCLKLOST    => qPllRefClkLostIn(1),
         PLL0LOCK          => qPllLockIn(0),
         PLL1LOCK          => qPllLockIn(1),
         TXRESETDONE       => txResetDone,            -- From GT
         MMCM_LOCK         => txMmcmLockedIn,
         GTTXRESET         => gtTxReset,
         MMCM_RESET        => txMmcmResetOut,
         PLL0_RESET        => txPllResets(0),
         PLL1_RESET        => txPllResets(1),
         TX_FSM_RESET_DONE => txFsmResetDone,
         TXUSERRDY         => txUserRdyInt,
         RUN_PHALIGNMENT   => txRunPhaseAlignment,
         RESET_PHALIGNMENT => txResetPhaseAlignment,  -- Used for manual alignment
         PHALIGNMENT_DONE  => txPhaseAlignmentDone,
         RETRY_COUNTER     => open);                  -- Might be interesting to look at

   --------------------------------------------------------------------------------------------------
   -- Synchronize rxFsmResetDone to rxUsrClk to use as reset for external logic.
   --------------------------------------------------------------------------------------------------
   RstSync_Tx : entity work.RstSync
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '0',
         OUT_POLARITY_G => '0')
      port map (
         clk      => txUsrClkIn,
         asyncRst => txFsmResetDone,
         syncRst  => txResetDoneOut);   -- Output

   -------------------------------------------------------------------------------------------------
   -- Tx Phase aligner
   -- Only used when bypassing buffer
   -------------------------------------------------------------------------------------------------
   TxAutoPhaseAlignGen : if (TX_BUF_EN_G = false and TX_PHASE_ALIGN_G = "AUTO") generate

      PhaseAlign_Tx : entity work.Gtp7AutoPhaseAligner
         generic map (
            GT_TYPE => GT_TYPE_C)
         port map (
            STABLE_CLOCK         => stableClkIn,
            RUN_PHALIGNMENT      => txRunPhaseAlignment,
            PHASE_ALIGNMENT_DONE => txPhaseAlignmentDone,
            PHALIGNDONE          => txPhAlignDone,
            DLYSRESET            => txDlySReset,
            DLYSRESETDONE        => txDlySResetDone,
            RECCLKSTABLE         => '1');
      txPhAlignEn <= '0';               -- Auto Mode
      txPhInit    <= '0';
      txPhAlign   <= '0';
      txDlyEn     <= '0';
   end generate TxAutoPhaseAlignGen;

   TxManualPhaseAlignGen : if (TX_BUF_EN_G = false and TX_PHASE_ALIGN_G = "MANUAL") generate
      Gtx7TxManualPhaseAligner_1 : entity work.Gtp7TxManualPhaseAligner
         generic map (
            TPD_G => TPD_G)
         port map (
            stableClk          => stableClkIn,
            resetPhAlignment   => txResetPhaseAlignment,
            runPhAlignment     => txRunPhaseAlignment,
            phaseAlignmentDone => txPhaseAlignmentDone,
            gtTxDlySReset      => txDlySReset,
            gtTxDlySResetDone  => txDlySResetDone,
            gtTxPhInit         => txPhInit,
            gtTxPhInitDone     => txPhInitDone,
            gtTxPhAlign        => txPhAlign,
            gtTxPhAlignDone    => txPhAlignDone,
            gtTxDlyEn          => txDlyEn);
      txPhAlignEn <= '1';
   end generate TxManualPhaseAlignGen;

   NoTxPhaseAlignGen : if (TX_BUF_EN_G = true or TX_PHASE_ALIGN_G = "NONE") generate
      txDlyEn              <= '0';
      txDlySReset          <= '0';
      txPhAlign            <= '0';
      txPhAlignEn          <= '0';
      txPhInit             <= '0';
      txPhaseAlignmentDone <= '1';
   end generate NoTxPhaseAlignGen;

   --------------------------------------------------------------------------------------------------
   -- GTX Instantiation
   --------------------------------------------------------------------------------------------------
   gtpe2_i : GTPE2_CHANNEL
      generic map(
         ------------------Simulation-Only Attributes---------------
         SIM_RECEIVER_DETECT_PASS   => ("TRUE"),
         SIM_RESET_SPEEDUP          => SIM_GTRESET_SPEEDUP_G,
         SIM_TX_EIDLE_DRIVE_LEVEL   => ("X"),
         SIM_VERSION                => SIM_VERSION_G,
         ------------------RX Byte and Word Alignment Attributes---------------
         ALIGN_COMMA_DOUBLE         => ALIGN_COMMA_DOUBLE_G,
         ALIGN_COMMA_ENABLE         => ALIGN_COMMA_ENABLE_G,
         ALIGN_COMMA_WORD           => ALIGN_COMMA_WORD_G,
         ALIGN_MCOMMA_DET           => ALIGN_MCOMMA_DET_G,
         ALIGN_MCOMMA_VALUE         => ALIGN_MCOMMA_VALUE_G,
         ALIGN_PCOMMA_DET           => ALIGN_PCOMMA_DET_G,
         ALIGN_PCOMMA_VALUE         => ALIGN_PCOMMA_VALUE_G,
         SHOW_REALIGN_COMMA         => SHOW_REALIGN_COMMA_G,
         RXSLIDE_AUTO_WAIT          => 7,
         RXSLIDE_MODE               => RXSLIDE_MODE_G,
         RX_SIG_VALID_DLY           => 10,
         ------------------RX 8B/10B Decoder Attributes---------------
         -- These don't really matter since RX 8B10B is disabled
         RX_DISPERR_SEQ_MATCH       => RX_DISPERR_SEQ_MATCH_G,
         DEC_MCOMMA_DETECT          => DEC_MCOMMA_DETECT_G,
         DEC_PCOMMA_DETECT          => DEC_PCOMMA_DETECT_G,
         DEC_VALID_COMMA_ONLY       => DEC_VALID_COMMA_ONLY_G,
         ------------------------RX Clock Correction Attributes----------------------
         CBCC_DATA_SOURCE_SEL       => CBCC_DATA_SOURCE_SEL_G,
         CLK_COR_SEQ_2_USE          => CLK_COR_SEQ_2_USE_G,
         CLK_COR_KEEP_IDLE          => CLK_COR_KEEP_IDLE_G,
         CLK_COR_MAX_LAT            => CLK_COR_MAX_LAT_G,
         CLK_COR_MIN_LAT            => CLK_COR_MIN_LAT_G,
         CLK_COR_PRECEDENCE         => CLK_COR_PRECEDENCE_G,
         CLK_COR_REPEAT_WAIT        => CLK_COR_REPEAT_WAIT_G,
         CLK_COR_SEQ_LEN            => CLK_COR_SEQ_LEN_G,
         CLK_COR_SEQ_1_ENABLE       => CLK_COR_SEQ_1_ENABLE_G,
         CLK_COR_SEQ_1_1            => CLK_COR_SEQ_1_1_G,
         CLK_COR_SEQ_1_2            => CLK_COR_SEQ_1_2_G,
         CLK_COR_SEQ_1_3            => CLK_COR_SEQ_1_3_G,
         CLK_COR_SEQ_1_4            => CLK_COR_SEQ_1_4_G,
         CLK_CORRECT_USE            => CLK_CORRECT_USE_G,
         CLK_COR_SEQ_2_ENABLE       => CLK_COR_SEQ_2_ENABLE_G,
         CLK_COR_SEQ_2_1            => CLK_COR_SEQ_2_1_G,
         CLK_COR_SEQ_2_2            => CLK_COR_SEQ_2_2_G,
         CLK_COR_SEQ_2_3            => CLK_COR_SEQ_2_3_G,
         CLK_COR_SEQ_2_4            => CLK_COR_SEQ_2_4_G,
         ------------------------RX Channel Bonding Attributes----------------------
         CHAN_BOND_KEEP_ALIGN       => CHAN_BOND_KEEP_ALIGN_G,
         CHAN_BOND_MAX_SKEW         => CHAN_BOND_MAX_SKEW_G,
         CHAN_BOND_SEQ_LEN          => CHAN_BOND_SEQ_LEN_G,
         CHAN_BOND_SEQ_1_1          => CHAN_BOND_SEQ_1_1_G,
         CHAN_BOND_SEQ_1_2          => CHAN_BOND_SEQ_1_2_G,
         CHAN_BOND_SEQ_1_3          => CHAN_BOND_SEQ_1_3_G,
         CHAN_BOND_SEQ_1_4          => CHAN_BOND_SEQ_1_4_G,
         CHAN_BOND_SEQ_1_ENABLE     => CHAN_BOND_SEQ_1_ENABLE_G,
         CHAN_BOND_SEQ_2_1          => CHAN_BOND_SEQ_2_1_G,
         CHAN_BOND_SEQ_2_2          => CHAN_BOND_SEQ_2_2_G,
         CHAN_BOND_SEQ_2_3          => CHAN_BOND_SEQ_2_3_G,
         CHAN_BOND_SEQ_2_4          => CHAN_BOND_SEQ_2_4_G,
         CHAN_BOND_SEQ_2_ENABLE     => CHAN_BOND_SEQ_2_ENABLE_G,
         CHAN_BOND_SEQ_2_USE        => CHAN_BOND_SEQ_2_USE_G,
         FTS_DESKEW_SEQ_ENABLE      => FTS_DESKEW_SEQ_ENABLE_G,
         FTS_LANE_DESKEW_CFG        => FTS_LANE_DESKEW_CFG_G,
         FTS_LANE_DESKEW_EN         => FTS_LANE_DESKEW_EN_G,
         ---------------------------RX Margin Analysis Attributes----------------------------
         ES_CONTROL                 => ("000000"),
         ES_ERRDET_EN               => ("FALSE"),
         ES_EYE_SCAN_EN             => ("FALSE"),
         ES_HORZ_OFFSET             => (x"010"),
         ES_PMA_CFG                 => ("0000000000"),
         ES_PRESCALE                => ("00000"),
         ES_QUALIFIER               => (x"00000000000000000000"),
         ES_QUAL_MASK               => (x"00000000000000000000"),
         ES_SDATA_MASK              => (x"00000000000000000000"),
         ES_VERT_OFFSET             => ("000000000"),
         -------------------------FPGA RX Interface Attributes-------------------------
         RX_DATA_WIDTH              => (RX_DATA_WIDTH_C),
         ---------------------------PMA Attributes----------------------------
         OUTREFCLK_SEL_INV          => ("11"),     -- ??
         PMA_RSV                    => PMA_RSV_G,  -- 
         PMA_RSV2                   => (x"00002040"),
         PMA_RSV3                   => ("00"),
         PMA_RSV4                   => ("0000"),
         RX_BIAS_CFG                => ("0000111100110011"),
         DMONITOR_CFG               => (x"000A00"),
         RX_CM_SEL                  => ("11"),
         RX_CM_TRIM                 => ("1010"),
         RX_DEBUG_CFG               => ("00000000000000"),
         RX_OS_CFG                  => RX_OS_CFG_G,                   -- From wizard
         TERM_RCAL_CFG              => ("100001000010000"),
         TERM_RCAL_OVRD             => ("000"),
         TST_RSV                    => (x"00000000"),
         RX_CLK25_DIV               => RX_CLK25_DIV_G,
         TX_CLK25_DIV               => TX_CLK25_DIV_G,
         UCODEER_CLR                => ('0'),
         ---------------------------PCI Express Attributes----------------------------
         PCS_PCIE_EN                => ("FALSE"),
         ---------------------------PCS Attributes----------------------------
         PCS_RSVD_ATTR              => (x"000000000000"),             -- From wizard
         -------------RX Buffer Attributes------------
         RXBUF_ADDR_MODE            => RX_BUF_ADDR_MODE_G,
         RXBUF_EIDLE_HI_CNT         => ("1000"),
         RXBUF_EIDLE_LO_CNT         => ("0000"),
         RXBUF_EN                   => toString(RX_BUF_EN_G),
         RX_BUFFER_CFG              => ("000000"),
         RXBUF_RESET_ON_CB_CHANGE   => ("TRUE"),
         RXBUF_RESET_ON_COMMAALIGN  => ("FALSE"),
         RXBUF_RESET_ON_EIDLE       => ("FALSE"),
         RXBUF_RESET_ON_RATE_CHANGE => ("TRUE"),
         RXBUFRESET_TIME            => ("00001"),
         RXBUF_THRESH_OVFLW         => (61),
         RXBUF_THRESH_OVRD          => ("FALSE"),
         RXBUF_THRESH_UNDFLW        => (4),
         RXDLY_CFG                  => (x"001F"),
         RXDLY_LCFG                 => (x"030"),
         RXDLY_TAP_CFG              => (x"0000"),
         RXPH_CFG                   => (x"C00002"),
         RXPHDLY_CFG                => (x"084020"),
         RXPH_MONITOR_SEL           => ("00000"),
         RX_XCLK_SEL                => RX_XCLK_SEL_C,
         RX_DDI_SEL                 => ("000000"),
         RX_DEFER_RESET_BUF_EN      => ("TRUE"),
         -----------------------CDR Attributes-------------------------
         RXCDR_CFG                  => RXCDR_CFG_G,                   -- From wizard
         RXCDR_FR_RESET_ON_EIDLE    => ('0'),
         RXCDR_HOLD_DURING_EIDLE    => ('0'),
         RXCDR_PH_RESET_ON_EIDLE    => ('0'),
         RXCDR_LOCK_CFG             => ("001001"),
         -------------------RX Initialization and Reset Attributes-------------------
         RXCDRFREQRESET_TIME        => ("00001"),
         RXCDRPHRESET_TIME          => ("00001"),
         RXISCANRESET_TIME          => ("00001"),
         RXPCSRESET_TIME            => ("00001"),
         RXPMARESET_TIME            => ("00011"),  -- ! Check this
         -------------------RX OOB Signaling Attributes-------------------
         RXOOB_CFG                  => ("0000110"),
         -------------------------RX Gearbox Attributes---------------------------
         RXGEARBOX_EN               => ("FALSE"),
         GEARBOX_MODE               => ("000"),
         -------------------------PRBS Detection Attribute-----------------------
         RXPRBS_ERR_LOOPBACK        => ('0'),
         -------------Power-Down Attributes----------
         PD_TRANS_TIME_FROM_P2      => (x"03c"),
         PD_TRANS_TIME_NONE_P2      => (x"3c"),
         PD_TRANS_TIME_TO_P2        => (x"64"),
         -------------RX OOB Signaling Attributes----------
         SAS_MAX_COM                => (64),
         SAS_MIN_COM                => (36),
         SATA_BURST_SEQ_LEN         => ("1111"),
         SATA_BURST_VAL             => ("100"),
         SATA_EIDLE_VAL             => ("100"),
         SATA_MAX_BURST             => (8),
         SATA_MAX_INIT              => (21),
         SATA_MAX_WAKE              => (7),
         SATA_MIN_BURST             => (4),
         SATA_MIN_INIT              => (12),
         SATA_MIN_WAKE              => (4),
         -------------RX Fabric Clock Output Control Attributes----------
         TRANS_TIME_RATE            => (x"0E"),
         --------------TX Buffer Attributes----------------
         TXBUF_EN                   => toString(TX_BUF_EN_G),
         TXBUF_RESET_ON_RATE_CHANGE => ("TRUE"),
         TXDLY_CFG                  => (x"001F"),
         TXDLY_LCFG                 => (x"030"),
         TXDLY_TAP_CFG              => (x"0000"),
         TXPH_CFG                   => (x"0780"),
         TXPHDLY_CFG                => (x"084020"),
         TXPH_MONITOR_SEL           => ("00000"),
         TX_XCLK_SEL                => TX_XCLK_SEL_C,
         -------------------------FPGA TX Interface Attributes-------------------------
         TX_DATA_WIDTH              => TX_DATA_WIDTH_C,
         -------------------------TX Configurable Driver Attributes-------------------------
         TX_DEEMPH0                 => ("000000"),
         TX_DEEMPH1                 => ("000000"),
         TX_EIDLE_ASSERT_DELAY      => ("110"),
         TX_EIDLE_DEASSERT_DELAY    => ("100"),
         TX_LOOPBACK_DRIVE_HIZ      => ("FALSE"),
         TX_MAINCURSOR_SEL          => ('0'),
         TX_DRIVE_MODE              => ("DIRECT"),
         TX_MARGIN_FULL_0           => ("1001110"),
         TX_MARGIN_FULL_1           => ("1001001"),
         TX_MARGIN_FULL_2           => ("1000101"),
         TX_MARGIN_FULL_3           => ("1000010"),
         TX_MARGIN_FULL_4           => ("1000000"),
         TX_MARGIN_LOW_0            => ("1000110"),
         TX_MARGIN_LOW_1            => ("1000100"),
         TX_MARGIN_LOW_2            => ("1000010"),
         TX_MARGIN_LOW_3            => ("1000000"),
         TX_MARGIN_LOW_4            => ("1000000"),
         -------------------------TX Gearbox Attributes--------------------------
         TXGEARBOX_EN               => ("FALSE"),
         -------------------------TX Initialization and Reset Attributes--------------------------
         TXPCSRESET_TIME            => ("00001"),
         TXPMARESET_TIME            => ("00001"),
         -------------------------TX Receiver Detection Attributes--------------------------
         TX_RXDETECT_CFG            => (x"1832"),
         TX_RXDETECT_REF            => ("100"),
         ------------------ JTAG Attributes ---------------
         ACJTAG_DEBUG_MODE          => ('0'),
         ACJTAG_MODE                => ('0'),
         ACJTAG_RESET               => ('0'),
         ------------------ CDR Attributes ---------------
         CFOK_CFG                   => (x"49000040E80"),
         CFOK_CFG2                  => ("0100000"),
         CFOK_CFG3                  => ("0100000"),
         CFOK_CFG4                  => ('0'),
         CFOK_CFG5                  => (x"0"),
         CFOK_CFG6                  => ("0000"),
         RXOSCALRESET_TIME          => ("00011"),
         RXOSCALRESET_TIMEOUT       => ("00000"),
         ------------------ PMA Attributes ---------------
         CLK_COMMON_SWING           => ('0'),
         RX_CLKMUX_EN               => ('1'),
         TX_CLKMUX_EN               => ('1'),
         ES_CLK_PHASE_SEL           => ('0'),
         USE_PCS_CLK_PHASE_SEL      => ('0'),
         PMA_RSV6                   => ('0'),
         PMA_RSV7                   => ('0'),
         ------------------ TX Configuration Driver Attributes ---------------
         TX_PREDRIVER_MODE          => ('0'),
         PMA_RSV5                   => ('0'),
         SATA_PLL_CFG               => ("VCO_3000MHZ"),
         ------------------ RX Fabric Clock Output Control Attributes ---------------
         RXOUT_DIV                  => RXOUT_DIV_G,
         ------------------ TX Fabric Clock Output Control Attributes ---------------
         TXOUT_DIV                  => TXOUT_DIV_G,
         ------------------ RX Phase Interpolator Attributes---------------
         RXPI_CFG0                  => ("000"),
         RXPI_CFG1                  => ('1'),
         RXPI_CFG2                  => ('1'),
         --------------RX Equalizer Attributes-------------
         ADAPT_CFG0                 => (x"00000"),
         RXLPMRESET_TIME            => ("0001111"),
         RXLPM_BIAS_STARTUP_DISABLE => ('0'),
         RXLPM_CFG                  => ("0110"),
         RXLPM_CFG1                 => ('0'),
         RXLPM_CM_CFG               => ('0'),
         RXLPM_GC_CFG               => ("111100010"),
         RXLPM_GC_CFG2              => ("001"),
         RXLPM_HF_CFG               => ("00001111110000"),
         RXLPM_HF_CFG2              => ("01010"),
         RXLPM_HF_CFG3              => ("0000"),
         RXLPM_HOLD_DURING_EIDLE    => ('0'),
         RXLPM_INCM_CFG             => RXLPM_INCM_CFG_G,              -- From wizard
         RXLPM_IPCM_CFG             => RXLPM_IPCM_CFG_G,              -- From wizard
         RXLPM_LF_CFG               => ("000000001111110000"),
         RXLPM_LF_CFG2              => ("01010"),
         RXLPM_OSINT_CFG            => ("000"),
         ------------------ TX Phase Interpolator PPM Controller Attributes---------------
         TXPI_CFG0                  => ("00"),
         TXPI_CFG1                  => ("00"),
         TXPI_CFG2                  => ("00"),
         TXPI_CFG3                  => ('0'),
         TXPI_CFG4                  => ('0'),
         TXPI_CFG5                  => ("000"),
         TXPI_GREY_SEL              => ('0'),
         TXPI_INVSTROBE_SEL         => ('0'),
         TXPI_PPMCLK_SEL            => ("TXUSRCLK2"),
         TXPI_PPM_CFG               => (x"00"),
         TXPI_SYNFREQ_PPM           => ("000"),
         ------------------ LOOPBACK Attributes---------------
         LOOPBACK_CFG               => ('0'),
         PMA_LOOPBACK_CFG           => ('0'),
         ------------------RX OOB Signalling Attributes---------------
         RXOOB_CLK_CFG              => ("PMA"),
         ------------------TX OOB Signalling Attributes---------------
         TXOOB_CFG                  => ('0'),
         ------------------RX Buffer Attributes---------------
         RXSYNC_MULTILANE           => ('0'),
         RXSYNC_OVRD                => ('0'),
         RXSYNC_SKIP_DA             => ('0'),
         ------------------TX Buffer Attributes---------------
         TXSYNC_MULTILANE           => ('0'),
         TXSYNC_OVRD                => ('1'),
         TXSYNC_SKIP_DA             => ('0'))
      port map
      (
         --------------------------------- CPLL Ports -------------------------------
         GTRSVD               => "0000000000000000",
         PCSRSVDIN            => "0000000000000000",
         TSTIN                => "11111111111111111111",
         ---------------------------- Channel - DRP Ports  --------------------------
         DRPADDR              => drpMuxAddr,
         DRPCLK               => stableClkIn,
         DRPDI                => drpMuxDi,
         DRPDO                => drpMuxDo,
         DRPEN                => drpMuxEn,
         DRPRDY               => drpMuxRdy,
         DRPWE                => drpMuxWe,
         ----------------- FPGA TX Interface Datapath Configuration  ----------------
         TX8B10BEN            => toSl(TX_8B10B_EN_G),
         ------------------------ GTPE2_CHANNEL Clocking Ports ----------------------
         PLL0CLK              => qPllClkIn(0),
         PLL0REFCLK           => qPllRefClkIn(0),
         PLL1CLK              => qPllClkIn(1),
         PLL1REFCLK           => qPllRefClkIn(1),
         RXSYSCLKSEL          => RX_SYSCLK_SEL_C,
         TXSYSCLKSEL          => TX_SYSCLK_SEL_C,
         ------------------------------- Loopback Ports -----------------------------
         LOOPBACK             => loopbackIn,
         ----------------------------- PCI Express Ports ----------------------------
         PHYSTATUS            => open,
         RXRATE               => "000",
         RXVALID              => open,
         ----------------------------- PMA Reserved Ports ---------------------------
         PMARSVDIN3           => '0',
         PMARSVDIN4           => '0',
         ------------------------------ Power-Down Ports ----------------------------
         RXPD                 => rxPowerDown,
         TXPD                 => txPowerDown,
         -------------------------- RX 8B/10B Decoder Ports -------------------------
         SETERRSTATUS         => '0',
         --------------------- RX Initialization and Reset Ports --------------------
         EYESCANRESET         => '0',
         RXUSERRDY            => rxUserRdyInt,
         -------------------------- RX Margin Analysis Ports ------------------------
         EYESCANDATAERROR     => open,
         EYESCANMODE          => '0',
         EYESCANTRIGGER       => '0',
         ------------------------------- Receive Ports ------------------------------
         CLKRSVD0             => '0',
         CLKRSVD1             => '0',
         DMONFIFORESET        => '0',
         DMONITORCLK          => '0',
         RXPMARESETDONE       => rxPmaResetDone,
         SIGVALIDCLK          => '0',
         ------------------------- Receive Ports - CDR Ports ------------------------
         RXCDRFREQRESET       => '0',
         RXCDRHOLD            => '0',
         RXCDRLOCK            => rxCdrLock,
         RXCDROVRDEN          => '0',
         RXCDRRESET           => '0',
         RXCDRRESETRSV        => '0',
         RXOSCALRESET         => '0',
         RXOSINTCFG           => "0010",
         RXOSINTDONE          => open,
         RXOSINTHOLD          => '0',
         RXOSINTOVRDEN        => '0',
         RXOSINTPD            => '0',
         RXOSINTSTARTED       => open,
         RXOSINTSTROBE        => '0',
         RXOSINTSTROBESTARTED => open,
         RXOSINTTESTOVRDEN    => '0',
         ------------------- Receive Ports - Clock Correction Ports -----------------
         RXCLKCORCNT          => open,
         ---------- Receive Ports - FPGA RX Interface Datapath Configuration --------
         RX8B10BEN            => toSl(RX_8B10B_EN_G),
         ------------------ Receive Ports - FPGA RX Interface Ports -----------------
         RXDATA               => rxDataFull,
         RXUSRCLK             => rxUsrClkIn,
         RXUSRCLK2            => rxUsrClk2In,
         ------------------- Receive Ports - Pattern Checker Ports ------------------
         RXPRBSERR            => open,
         RXPRBSSEL            => "000",
         ------------------- Receive Ports - Pattern Checker ports ------------------
         RXPRBSCNTRESET       => '0',
         ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
         RXCHARISCOMMA        => open,
         RXCHARISK            => rxCharIsKFull,
         RXDISPERR            => rxDispErrFull,
         RXNOTINTABLE         => rxDecErrFull,
         ------------------------ Receive Ports - RX AFE Ports ----------------------
         GTPRXN               => gtRxN,
         GTPRXP               => gtRxP,
         PMARSVDIN2           => '0',
         PMARSVDOUT0          => open,
         PMARSVDOUT1          => open,
         ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
         RXBUFRESET           => '0',
         RXBUFSTATUS          => rxBufStatusOut,
         RXDDIEN              => RX_DDIEN_G,  -- Don't insert delay in deserializer. Might be wrong.
         RXDLYBYPASS          => RX_DLY_BYPASS_G,
         RXDLYEN              => '0',   -- Used for manual phase align
         RXDLYOVRDEN          => '0',
         RXDLYSRESET          => rxDlySReset,
         RXDLYSRESETDONE      => rxDlySResetDone,
         RXPHALIGN            => '0',
         RXPHALIGNDONE        => rxPhAlignDone,
         RXPHALIGNEN          => '0',
         RXPHDLYPD            => '0',
         RXPHDLYRESET         => '0',
         RXPHMONITOR          => open,
         RXPHOVRDEN           => '0',
         RXPHSLIPMONITOR      => open,
         RXSTATUS             => open,
         RXSYNCALLIN          => '0',
         RXSYNCDONE           => open,
         RXSYNCIN             => '0',
         RXSYNCMODE           => '0',
         RXSYNCOUT            => open,
         -------------- Receive Ports - RX Byte and Word Alignment Ports ------------
         RXBYTEISALIGNED      => open,
         RXBYTEREALIGN        => open,
         RXCOMMADET           => open,
         RXCOMMADETEN         => toSl(RX_ALIGN_MODE_G /= "NONE"),     -- Enables RXSLIDE
         RXMCOMMAALIGNEN      => toSl(ALIGN_MCOMMA_EN_G = '1' and (RX_ALIGN_MODE_G = "GT")),
         RXPCOMMAALIGNEN      => toSl(ALIGN_PCOMMA_EN_G = '1' and (RX_ALIGN_MODE_G = "GT")),
         RXSLIDE              => rxSlide,
         ------------------ Receive Ports - RX Channel Bonding Ports ----------------
         RXCHANBONDSEQ        => open,
         RXCHBONDEN           => toSl(RX_CHAN_BOND_EN_G),
         RXCHBONDI            => rxChBondIn,
         RXCHBONDLEVEL        => rxChBondLevelIn,
         RXCHBONDMASTER       => toSl(RX_CHAN_BOND_MASTER_G),
         RXCHBONDO            => rxChBondOut,
         RXCHBONDSLAVE        => toSl(RX_CHAN_BOND_MASTER_G = false),
         ----------------- Receive Ports - RX Channel Bonding Ports  ----------------
         RXCHANISALIGNED      => open,
         RXCHANREALIGN        => open,
         ------------ Receive Ports - RX Decision Feedback Equalizer(DFE) -----------
         DMONITOROUT          => open,
         RXADAPTSELTEST       => "00000000000000",
         RXDFEXYDEN           => '0',
         RXOSINTEN            => '1',
         RXOSINTID0           => x"0",
         RXOSINTNTRLEN        => '0',
         RXOSINTSTROBEDONE    => open,
         ------- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
         RXLPMLFOVRDEN        => '0',
         RXLPMOSINTNTRLEN     => '0',
         --------------------- Receive Ports - RX Equalizer Ports -------------------
         RXOSHOLD             => '0',
         RXOSOVRDEN           => '0',
         --------------------- Receive Ports - RX Equilizer Ports -------------------
         RXLPMHFHOLD          => rxLpmHfHold,
         RXLPMHFOVRDEN        => '0',
         RXLPMLFHOLD          => rxLpmLfHold,
         ------------ Receive Ports - RX Fabric ClocK Output Control Ports ----------
         RXRATEDONE           => open,
         ----------- Receive Ports - RX Fabric Clock Output Control Ports  ----------
         RXRATEMODE           => '0',
         --------------- Receive Ports - RX Fabric Output Control Ports -------------
         RXOUTCLK             => rxOutClk,
         RXOUTCLKFABRIC       => open,  --rxGtRefClk,
         RXOUTCLKPCS          => open,
         RXOUTCLKSEL          => to_stdlogicvector(RX_OUTCLK_SEL_C),  -- Selects rx recovered clk for rxoutclk
         ---------------------- Receive Ports - RX Gearbox Ports --------------------
         RXDATAVALID          => open,
         RXHEADER             => open,
         RXHEADERVALID        => open,
         RXSTARTOFSEQ         => open,
         --------------------- Receive Ports - RX Gearbox Ports  --------------------
         RXGEARBOXSLIP        => '0',
         ------------- Receive Ports - RX Initialization and Reset Ports ------------
         GTRXRESET            => gtRxRst,
         RXLPMRESET           => '0',
         RXOOBRESET           => '0',
         RXPCSRESET           => '0',
         RXPMARESET           => '0',
         ------------------- Receive Ports - RX OOB Signaling ports -----------------
         RXCOMSASDET          => open,
         RXCOMWAKEDET         => open,
         ------------------ Receive Ports - RX OOB Signaling ports  -----------------
         RXCOMINITDET         => open,
         ------------------ Receive Ports - RX OOB signalling Ports -----------------
         RXELECIDLE           => open,
         RXELECIDLEMODE       => "11",
         ----------------- Receive Ports - RX Polarity Control Ports ----------------
         RXPOLARITY           => rxPolarityIn,
         -------------- Receive Ports -RX Initialization and Reset Ports ------------
         RXRESETDONE          => rxResetDone,
         --------------------------- TX Buffer Bypass Ports -------------------------
         TXPHDLYTSTCLK        => '0',
         ------------------------ TX Configurable Driver Ports ----------------------
         TXPOSTCURSOR         => txPostCursor,
         TXPOSTCURSORINV      => '0',
         TXPRECURSOR          => txPreCursor,
         TXPRECURSORINV       => '0',
         -------------------- TX Fabric Clock Output Control Ports ------------------
         TXRATEMODE           => '0',
         --------------------- TX Initialization and Reset Ports --------------------
         CFGRESET             => '0',
         GTTXRESET            => gtTxReset,
         PCSRSVDOUT           => open,
         TXUSERRDY            => txUserRdyInt,
         ----------------- TX Phase Interpolator PPM Controller Ports ---------------
         TXPIPPMEN            => '0',
         TXPIPPMOVRDEN        => '0',
         TXPIPPMPD            => '0',
         TXPIPPMSEL           => '0',
         TXPIPPMSTEPSIZE      => "00000",
         ---------------------- Transceiver Reset Mode Operation --------------------
         GTRESETSEL           => '0',   -- Sequential Mode
         RESETOVRD            => '0',
         ------------------------------- Transmit Ports -----------------------------
         TXPMARESETDONE       => txPmaResetDone,
         ----------------- Transmit Ports - Configurable Driver Ports ---------------
         PMARSVDIN0           => '0',
         PMARSVDIN1           => '0',
         ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
         TXDATA               => txDataFull,
         TXUSRCLK             => txUsrClkIn,
         TXUSRCLK2            => txUsrClk2In,
         --------------------- Transmit Ports - PCI Express Ports -------------------
         TXELECIDLE           => '0',
         TXMARGIN             => "000",
         TXRATE               => "000",
         TXSWING              => '0',
         ------------------ Transmit Ports - Pattern Generator Ports ----------------
         TXPRBSFORCEERR       => '0',
         ------------------ Transmit Ports - TX 8B/10B Encoder Ports ----------------
         TX8B10BBYPASS        => x"0",
         TXCHARDISPMODE       => txCharDispMode,
         TXCHARDISPVAL        => txCharDispVal,
         TXCHARISK            => txCharIsKFull,
         ------------------ Transmit Ports - TX Buffer Bypass Ports -----------------
         TXDLYBYPASS          => TX_DLY_BYPASS_G,  -- Use the tx delay alignment circuit
         TXDLYEN              => txDlyEn,     -- Manual Align
         TXDLYHOLD            => '0',
         TXDLYOVRDEN          => '0',
         TXDLYSRESET          => txDlySReset,
         TXDLYSRESETDONE      => txDlySResetDone,
         TXDLYUPDOWN          => '0',
         TXPHALIGN            => txPhAlign,   -- Manual Align
         TXPHALIGNDONE        => txPhAlignDone,
         TXPHALIGNEN          => txPhAlignEn,      -- Enables manual align
         TXPHDLYPD            => '0',
         TXPHDLYRESET         => '0',   -- Use SReset instead
         TXPHINIT             => txPhInit,    -- Manual Align
         TXPHINITDONE         => txPhInitDone,
         TXPHOVRDEN           => '0',
         ---------------------- Transmit Ports - TX Buffer Ports --------------------
         TXBUFSTATUS          => txBufStatusOut,
         ------------ Transmit Ports - TX Buffer and Phase Alignment Ports ----------
         TXSYNCALLIN          => '0',
         TXSYNCDONE           => open,
         TXSYNCIN             => '0',
         TXSYNCMODE           => '0',
         TXSYNCOUT            => open,
         --------------- Transmit Ports - TX Configurable Driver Ports --------------
         GTPTXN               => gtTxN,
         GTPTXP               => gtTxP,
         TXBUFDIFFCTRL        => "100",
         TXDEEMPH             => '0',
         TXDIFFCTRL           => txDiffCtrl,
         TXDIFFPD             => '0',
         TXINHIBIT            => '0',
         TXMAINCURSOR         => "0000000",
         TXPISOPD             => '0',
         ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
         TXOUTCLK             => txOutClk,
         TXOUTCLKFABRIC       => open,  --txGtRefClk,
         TXOUTCLKPCS          => open,  --txOutClkPcsOut,
         TXOUTCLKSEL          => to_stdlogicvector(TX_OUTCLK_SEL_C),
         TXRATEDONE           => open,
         --------------------- Transmit Ports - TX Gearbox Ports --------------------
         TXGEARBOXREADY       => open,
         TXHEADER             => "000",
         TXSEQUENCE           => "0000000",
         TXSTARTSEQ           => '0',
         ------------- Transmit Ports - TX Initialization and Reset Ports -----------
         TXPCSRESET           => '0',
         TXPMARESET           => '0',
         TXRESETDONE          => txResetDone,
         ------------------ Transmit Ports - TX OOB signalling Ports ----------------
         TXCOMFINISH          => open,
         TXCOMINIT            => '0',
         TXCOMSAS             => '0',
         TXCOMWAKE            => '0',
         TXPDELECIDLEMODE     => '0',
         ----------------- Transmit Ports - TX Polarity Control Ports ---------------
         TXPOLARITY           => '0',
         --------------- Transmit Ports - TX Receiver Detection Ports  --------------
         TXDETECTRX           => '0',
         ------------------ Transmit Ports - pattern Generator Ports ----------------
         TXPRBSSEL            => "000");


   ------------------------- Soft Fix for Production Silicon----------------------

   GEN_RST_SEQ : if (SIMULATION_G = false) generate
      Gtp7RxRstSeq_Inst : entity work.Gtp7RxRstSeq
         port map(
            RST_IN         => rxUserResetIn,
            GTRXRESET_IN   => gtRxReset,
            RXPMARESETDONE => rxPmaResetDone,
            GTRXRESET_OUT  => gtRxRst,
            DRP_OP_DONE    => drpRstDone,
            DRPCLK         => stableClkIn,
            DRPEN          => drpRstEn,
            DRPADDR        => drpRstAddr,
            DRPWE          => drpRstWe,
            DRPDO          => drpRstDo,
            DRPDI          => drpRstDi,
            DRPRDY         => drpRstRdy);
   end generate GEN_RST_SEQ;

   NO_RST_SEQ : if (SIMULATION_G) generate
      gtRxRst    <= gtRxReset;
      drpRstDone <= '1';
      drpRstEn   <= '0';
      drpRstAddr <= (others => '0');
      drpRstWe   <= '0';
      drpRstDi   <= (others => '0');
   end generate NO_RST_SEQ;

   drpGnt     <= drpRstDone;
   drpRstRdy  <= drpMuxRdy when(drpRstDone = '0') else '0';
   drpRdy     <= drpMuxRdy when(drpRstDone = '1') else '0';
   drpMuxEn   <= drpEn     when(drpRstDone = '1') else drpRstEn;
   drpMuxWe   <= drpWe     when(drpRstDone = '1') else drpRstWe;
   drpMuxAddr <= drpAddr   when(drpRstDone = '1') else drpRstAddr;
   drpMuxDi   <= drpDi     when(drpRstDone = '1') else drpRstDi;
   drpRstDo   <= drpMuxDo;
   drpDo      <= drpMuxDo;

end architecture rtl;
