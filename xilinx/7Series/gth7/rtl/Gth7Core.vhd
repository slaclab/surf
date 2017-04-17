-------------------------------------------------------------------------------
-- File       : Gth7Core.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-01
-- Last update: 2015-04-01
-------------------------------------------------------------------------------
-- Description: Wrapper for Xilinx 7-series GTH primitive
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

library unisim;
use unisim.vcomponents.all;

entity Gth7Core is
   generic (
      TPD_G                    : time            := 1 ns;
      -- Sim Generics --
      SIM_GTRESET_SPEEDUP_G    : string          := "FALSE";
      SIM_VERSION_G            : string          := "2.0";
      SIMULATION_G             : boolean         := false;
      STABLE_CLOCK_PERIOD_G    : real            := 4.0E-9;       --units of seconds
      -- CPLL Settings --
      CPLL_REFCLK_SEL_G        : bit_vector      := "001";
      CPLL_FBDIV_G             : integer         := 4;
      CPLL_FBDIV_45_G          : integer         := 5;
      CPLL_REFCLK_DIV_G        : integer         := 1;
      RXOUT_DIV_G              : integer         := 2;
      TXOUT_DIV_G              : integer         := 2;
      RX_CLK25_DIV_G           : integer         := 5;    -- Set by wizard
      TX_CLK25_DIV_G           : integer         := 5;    -- Set by wizard
      PMA_RSV_G                : bit_vector      := X"00000080";  -- For GTH Transceiver: The default value is 32'h0000080
      RX_OS_CFG_G              : bit_vector      := "0000010000000";   -- Set by wizard
      RXCDR_CFG_G              : bit_vector      := x"0002007FE1000C2200018";  -- Set by wizard
      -- Configure PLL sources
      TX_PLL_G                 : string          := "CPLL";
      RX_PLL_G                 : string          := "CPLL";
      -- Configure Data widths
      TX_EXT_DATA_WIDTH_G      : integer         := 16;
      TX_INT_DATA_WIDTH_G      : integer         := 20;
      TX_8B10B_EN_G            : boolean         := true;
      RX_EXT_DATA_WIDTH_G      : integer         := 16;
      RX_INT_DATA_WIDTH_G      : integer         := 20;
      RX_8B10B_EN_G            : boolean         := true;
      -- Configure Buffer usage
      TX_BUF_EN_G              : boolean         := true;
      TX_OUTCLK_SRC_G          : string          := "PLLREFCLK";  -- or "OUTCLKPMA" when bypassing buffer
      TX_DLY_BYPASS_G          : sl              := '1';  -- 1 for bypass, 0 for delay
      TX_PHASE_ALIGN_G         : string          := "AUTO";       -- Or "MANUAL" or "NONE"
      TX_BUF_ADDR_MODE_G       : string          := "FAST";       -- Or "FULL"
      RX_BUF_EN_G              : boolean         := true;
      RX_OUTCLK_SRC_G          : string          := "PLLREFCLK";  -- or "OUTCLKPMA" when bypassing buffer
      RX_USRCLK_SRC_G          : string          := "RXOUTCLK";   -- or "TXOUTCLK"
      RX_DLY_BYPASS_G          : sl              := '1';  -- 1 for bypass, 0 for delay
      RX_DDIEN_G               : sl              := '0';  -- Supposed to be '1' when bypassing rx buffer
      RX_BUF_ADDR_MODE_G       : string          := "FAST";
      -- Configure RX comma alignment
      RX_ALIGN_MODE_G          : string          := "GT";   -- Or "FIXED_LAT" or "NONE"
      ALIGN_COMMA_DOUBLE_G     : string          := "FALSE";
      ALIGN_COMMA_ENABLE_G     : bit_vector      := "1111111111";
      ALIGN_COMMA_WORD_G       : integer         := 2;
      ALIGN_MCOMMA_DET_G       : string          := "FALSE";
      ALIGN_MCOMMA_VALUE_G     : bit_vector      := "1010000011";
      ALIGN_MCOMMA_EN_G        : sl              := '0';
      ALIGN_PCOMMA_DET_G       : string          := "FALSE";
      ALIGN_PCOMMA_VALUE_G     : bit_vector      := "0101111100";
      ALIGN_PCOMMA_EN_G        : sl              := '0';
      SHOW_REALIGN_COMMA_G     : string          := "FALSE";
      RXSLIDE_MODE_G           : string          := "PCS";  -- Set to PMA for fixed latency operation
      -- Fixed Latency comma alignment (If RX_ALIGN_MODE_G = "FIXED_LAT")
      FIXED_COMMA_EN_G         : slv(3 downto 0) := "0011";
      FIXED_ALIGN_COMMA_0_G    : slv             := "----------0101111100";
      FIXED_ALIGN_COMMA_1_G    : slv             := "----------1010000011";
      FIXED_ALIGN_COMMA_2_G    : slv             := "XXXXXXXXXXXXXXXXXXXX";
      FIXED_ALIGN_COMMA_3_G    : slv             := "XXXXXXXXXXXXXXXXXXXX";
      -- Configure RX 8B10B decoding (If RX_8B10B_EN_G = true)
      RX_DISPERR_SEQ_MATCH_G   : string          := "TRUE";
      DEC_MCOMMA_DETECT_G      : string          := "TRUE";
      DEC_PCOMMA_DETECT_G      : string          := "TRUE";
      DEC_VALID_COMMA_ONLY_G   : string          := "FALSE";
      -- Configure Clock Correction
      CBCC_DATA_SOURCE_SEL_G   : string          := "DECODED";
      CLK_COR_SEQ_2_USE_G      : string          := "FALSE";
      CLK_COR_KEEP_IDLE_G      : string          := "FALSE";
      CLK_COR_MAX_LAT_G        : integer         := 9;
      CLK_COR_MIN_LAT_G        : integer         := 7;
      CLK_COR_PRECEDENCE_G     : string          := "TRUE";
      CLK_COR_REPEAT_WAIT_G    : integer         := 0;
      CLK_COR_SEQ_LEN_G        : integer         := 1;
      CLK_COR_SEQ_1_ENABLE_G   : bit_vector      := "1111";
      CLK_COR_SEQ_1_1_G        : bit_vector      := "0100000000";      -- UG476 pg 249
      CLK_COR_SEQ_1_2_G        : bit_vector      := "0000000000";
      CLK_COR_SEQ_1_3_G        : bit_vector      := "0000000000";
      CLK_COR_SEQ_1_4_G        : bit_vector      := "0000000000";
      CLK_CORRECT_USE_G        : string          := "FALSE";
      CLK_COR_SEQ_2_ENABLE_G   : bit_vector      := "0000";
      CLK_COR_SEQ_2_1_G        : bit_vector      := "0100000000";      -- UG476 pg 249
      CLK_COR_SEQ_2_2_G        : bit_vector      := "0000000000";
      CLK_COR_SEQ_2_3_G        : bit_vector      := "0000000000";
      CLK_COR_SEQ_2_4_G        : bit_vector      := "0000000000";
      -- Configure Channel Bonding
      RX_CHAN_BOND_EN_G        : boolean         := false;
      RX_CHAN_BOND_MASTER_G    : boolean         := false;  --True: Master, False: Slave
      CHAN_BOND_KEEP_ALIGN_G   : string          := "FALSE";
      CHAN_BOND_MAX_SKEW_G     : integer         := 1;
      CHAN_BOND_SEQ_LEN_G      : integer         := 1;
      CHAN_BOND_SEQ_1_1_G      : bit_vector      := "0000000000";
      CHAN_BOND_SEQ_1_2_G      : bit_vector      := "0000000000";
      CHAN_BOND_SEQ_1_3_G      : bit_vector      := "0000000000";
      CHAN_BOND_SEQ_1_4_G      : bit_vector      := "0000000000";
      CHAN_BOND_SEQ_1_ENABLE_G : bit_vector      := "1111";
      CHAN_BOND_SEQ_2_1_G      : bit_vector      := "0000000000";
      CHAN_BOND_SEQ_2_2_G      : bit_vector      := "0000000000";
      CHAN_BOND_SEQ_2_3_G      : bit_vector      := "0000000000";
      CHAN_BOND_SEQ_2_4_G      : bit_vector      := "0000000000";
      CHAN_BOND_SEQ_2_ENABLE_G : bit_vector      := "0000";
      CHAN_BOND_SEQ_2_USE_G    : string          := "FALSE";
      FTS_DESKEW_SEQ_ENABLE_G  : bit_vector      := "1111";
      FTS_LANE_DESKEW_CFG_G    : bit_vector      := "1111";
      FTS_LANE_DESKEW_EN_G     : string          := "FALSE";
      -- RX Equalizer Attributes--------------------------
      RX_EQUALIZER_G           : string          := "LPM";  -- "DFE" or "LPM"
      RX_CM_TRIM_G             : bit_vector      := "1000";
      RX_DFE_LPM_CFG_G         : bit_vector      := x"0080";
      RXDFELFOVRDEN_G          : sl              := '0';
      RXDFEXYDEN_G             : sl              := '1');   -- This should always be 1
   port (
      stableClkIn      : in  sl;        -- Free running clock needed to drive reset logic and DRP interface
      cPllRefClkIn     : in  sl              := '0';  -- Drives CPLL if used
      cPllLockOut      : out sl;
      qPllRefClkIn     : in  sl              := '0';  -- Signals from QPLL if used
      qPllClkIn        : in  sl              := '0';
      qPllLockIn       : in  sl              := '0';
      qPllRefClkLostIn : in  sl              := '0';
      qPllResetOut     : out sl;
      gtRxRefClkBufg   : in  sl              := '0';  -- In fixed latency mode, need BUF'd version of gt rx reference clock to check if recovered clock is stable
      -- Serial IO
      gtTxP            : out sl;
      gtTxN            : out sl;
      gtRxP            : in  sl;
      gtRxN            : in  sl;
      -- Rx Clock related signals
      rxOutClkOut      : out sl;
      rxUsrClkIn       : in  sl;
      rxUsrClk2In      : in  sl;
      rxUserRdyOut     : out sl;
      rxMmcmResetOut   : out sl;
      rxMmcmLockedIn   : in  sl              := '1';
      -- Rx User Reset Signals
      rxUserResetIn    : in  sl;
      rxResetDoneOut   : out sl;
      -- Manual Comma Align signals
      rxDataValidIn    : in  sl              := '1';
      rxSlideIn        : in  sl              := '0';
      -- Rx Data and decode signals
      rxDataOut        : out slv(RX_EXT_DATA_WIDTH_G-1 downto 0);
      rxCharIsKOut     : out slv((RX_EXT_DATA_WIDTH_G/8)-1 downto 0);  -- If WIDTH not mult of 8 then
      rxDecErrOut      : out slv((RX_EXT_DATA_WIDTH_G/8)-1 downto 0);  -- not using 8b10b and these dont matter
      rxDispErrOut     : out slv((RX_EXT_DATA_WIDTH_G/8)-1 downto 0);
      rxPolarityIn     : in  sl              := '0';
      rxBufStatusOut   : out slv(2 downto 0);
      -- Rx Channel Bonding
      rxChBondLevelIn  : in  slv(2 downto 0) := "000";
      rxChBondIn       : in  slv(4 downto 0) := "00000";
      rxChBondOut      : out slv(4 downto 0);
      -- Tx Clock Related Signals
      txOutClkOut      : out sl;
      txUsrClkIn       : in  sl;
      txUsrClk2In      : in  sl;
      txUserRdyOut     : out sl;        -- txOutClk is valid
      txMmcmResetOut   : out sl;
      txMmcmLockedIn   : in  sl              := '1';
      -- Tx User Reset signals
      txUserResetIn    : in  sl;
      txResetDoneOut   : out sl;
      -- Tx Data
      txDataIn         : in  slv(TX_EXT_DATA_WIDTH_G-1 downto 0);
      txCharIsKIn      : in  slv((TX_EXT_DATA_WIDTH_G/8)-1 downto 0);
      txBufStatusOut   : out slv(1 downto 0);
      txPolarityIn     : in  sl              := '0';
      -- Debug Interface      
      txPowerDown      : in  slv(1 downto 0) := "00";
      rxPowerDown      : in  slv(1 downto 0) := "00";
      loopbackIn       : in  slv(2 downto 0) := "000";
      txPreCursor      : in  slv(4 downto 0) := (others => '0');
      txPostCursor     : in  slv(4 downto 0) := (others => '0');
      txDiffCtrl       : in  slv(3 downto 0) := "1000";      
      -- DRP Interface (stableClkIn Domain)
      drpGnt         : out sl;
      drpRdy         : out sl;
      drpEn          : in  sl := '0';
      drpWe          : in  sl := '0';
      drpAddr        : in  slv(8 downto 0) := "000000000";
      drpDi          : in  slv(15 downto 0) := X"0000";
      drpDo          : out slv(15 downto 0));      
end entity Gth7Core;

architecture rtl of Gth7Core is

   function getOutClkSelVal (OUT_CLK_SRC : string) return bit_vector is
   begin
      if (OUT_CLK_SRC = "PLLREFCLK") then
         return "011";
      elsif (OUT_CLK_SRC = "OUTCLKPMA") then
         return "010";
      elsif (OUT_CLK_SRC = "PLLDV2CLK") then
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
   constant RX_SYSCLK_SEL_C : slv := ite(RX_PLL_G = "CPLL", "00", "11");
   constant TX_SYSCLK_SEL_C : slv := ite(TX_PLL_G = "CPLL", "00", "11");

   constant RX_XCLK_SEL_C : string := ite(RX_BUF_EN_G, "RXREC", "RXUSR");
   constant TX_XCLK_SEL_C : string := ite(TX_BUF_EN_G, "TXOUT", "TXUSR");

   constant RX_OUTCLK_SEL_C : bit_vector := getOutClkSelVal(RX_OUTCLK_SRC_G);
   constant TX_OUTCLK_SEL_C : bit_vector := getOutClkSelVal(TX_OUTCLK_SRC_G);

   constant RX_DATA_WIDTH_C : integer := getDataWidth(RX_8B10B_EN_G, RX_EXT_DATA_WIDTH_G);
   constant TX_DATA_WIDTH_C : integer := getDataWidth(TX_8B10B_EN_G, TX_EXT_DATA_WIDTH_G);

   constant WAIT_TIME_CDRLOCK_C : integer := ite(SIM_GTRESET_SPEEDUP_G = "TRUE", 16, 65520);

   constant RX_INT_DATAWIDTH_C : integer := (RX_INT_DATA_WIDTH_G/32);
   constant TX_INT_DATAWIDTH_C : integer := (TX_INT_DATA_WIDTH_G/32);

   --------------------------------------------------------------------------------------------------
   -- Signals
   --------------------------------------------------------------------------------------------------

   -- CPll Reset
   signal cPllLock       : sl;
   signal cPllReset      : sl;
   signal cPllRefClkLost : sl;

   -- Gtx CPLL Input Clocks
   signal gtGRefClk      : sl;
   signal gtNorthRefClk0 : sl;
   signal gtNorthRefClk1 : sl;
   signal gtRefClk0      : sl;
   signal gtRefClk1      : sl;
   signal gtSouthRefClk0 : sl;
   signal gtSouthRefClk1 : sl;

   ----------------------------
   -- Rx Signals
   signal rxOutClk     : sl;
   signal rxOutClkBufg : sl;

   signal rxPllLock       : sl;
   signal rxPllReset      : sl;
   signal rxPllRefClkLost : sl;

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

   signal rxRunPhAlignment     : sl;
   signal rxPhaseAlignmentDone : sl;
   signal rxAlignReset         : sl;
   signal rxDlySReset          : sl;    -- GT RXDLYSRESET
   signal rxDlySResetDone      : sl;    -- GT RXDLYSRESETDONE
   signal rxPhAlignDone        : sl;    -- GT RXPHALIGNDONE
   signal rxSlide              : sl;    -- GT RXSLIDE
   signal rxCdrLock            : sl;    -- GT RXCDRLOCK

   signal rxDfeAgcHold : sl;
   signal rxDfeLfHold  : sl;
   signal rxLpmLfHold  : sl;
   signal rxLpmHfHold  : sl;

   -- Rx Data
   signal rxDataInt     : slv(RX_EXT_DATA_WIDTH_G-1 downto 0);
   signal rxDataFull    : slv(63 downto 0);  -- GT RXDATA
   signal rxCharIsKFull : slv(7 downto 0);   -- GT RXCHARISK
   signal rxDispErrFull : slv(7 downto 0);   -- GT RXDISPERR
   signal rxDecErrFull  : slv(7 downto 0);


   ----------------------------
   -- Tx Signals
   signal txPllLock       : sl;
   signal txPllReset      : sl;
   signal txPllRefClkLost : sl;

   signal gtTxReset    : sl;            -- GT GTTXRESET
   signal txResetDone  : sl;            -- GT TXRESETDONE
   signal txUserRdyInt : sl;            -- GT TXUSERRDY

   signal txFsmResetDone : sl;

   signal txResetPhAlignment   : sl;
   signal txRunPhAlignment     : sl;
   signal txPhaseAlignmentDone : sl;
   signal txPhAlignEn          : sl;    -- GT TXPHALIGNEN
   signal txDlySReset          : sl;    -- GT TXDLYSRESET
   signal txDlySResetDone      : sl;    -- GT TXDLYSRESETDONE
   signal txPhInit             : sl;    -- GT TXPHINIT
   signal txPhInitDone         : sl;    -- GT TXPHINITDONE
   signal txPhAlign            : sl;    -- GT TXPHALIGN
   signal txPhAlignDone        : sl;    -- GT TXPHALIGNDONE
   signal txDlyEn              : sl;    -- GT TXDLYEN

   -- Tx Data Signals
   signal txDataFull : slv(63 downto 0) := (others => '0');
   signal txCharIsKFull,
      txCharDispMode,
      txCharDispVal : slv(7 downto 0) := (others => '0');

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

   rxOutClkOut <= rxOutClkBufg;

   cPllLockOut <= cPllLock;

   --------------------------------------------------------------------------------------------------
   -- PLL Resets. Driven from TX Rst if both use same PLL
   --------------------------------------------------------------------------------------------------
   cPllReset    <= txPllReset when (TX_PLL_G = "CPLL") else rxPllReset when (RX_PLL_G = "CPLL") else '0';
   qPllResetOut <= txPllReset when (TX_PLL_G = "QPLL") else rxPllReset when (RX_PLL_G = "QPLL") else '0';

   --------------------------------------------------------------------------------------------------
   -- CPLL clock select. Only ever use 1 clock to drive cpll. Never switch clocks.
   -- This may be unnecessary. Vivado does this for you now.
   --------------------------------------------------------------------------------------------------
   gtRefClk0      <= cPllRefClkIn when CPLL_REFCLK_SEL_G = "001" else '0';
   gtRefClk1      <= cPllRefClkIn when CPLL_REFCLK_SEL_G = "010" else '0';
   gtNorthRefClk0 <= cPllRefClkIn when CPLL_REFCLK_SEL_G = "011" else '0';
   gtNorthRefClk1 <= cPllRefClkIn when CPLL_REFCLK_SEL_G = "100" else '0';
   gtSouthRefClk0 <= cPllRefClkIn when CPLL_REFCLK_SEL_G = "101" else '0';
   gtSouthRefClk1 <= cPllRefClkIn when CPLL_REFCLK_SEL_G = "110" else '0';
   gtGRefClk      <= cPllRefClkIn when CPLL_REFCLK_SEL_G = "111" else '0';

   --------------------------------------------------------------------------------------------------
   -- Rx Logic
   --------------------------------------------------------------------------------------------------
   -- Fit GTX port sizes to selected rx external interface size
   rxDataOut <= rxDataInt;
   RX_DATA_8B10B_GLUE : process (rxCharIsKFull, rxDataFull, rxDecErrFull, rxDispErrFull) is
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

   -- Mux proper PLL Lock signal onto rxPllLock
   rxPllLock <= cPllLock when (RX_PLL_G = "CPLL") else qPllLockIn when (RX_PLL_G = "QPLL") else '0';

   -- Mux proper PLL RefClkLost signal on rxPllRefClkLost
   rxPllRefClkLost <= cPllRefClkLost when (RX_PLL_G = "CPLL") else qPllRefClkLostIn when (RX_PLL_G = "QPLL") else '0';

   rxAlignReset   <= '0';               -- Unused?!?
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
   Gth7RxRst_Inst : entity work.Gth7RxRst
      generic map (
         TPD_G                  => TPD_G,
         EXAMPLE_SIMULATION     => 0,
         GT_TYPE                => "GTX",
         EQ_MODE                => RX_EQUALIZER_G,
         STABLE_CLOCK_PERIOD    => getTimeRatio(STABLE_CLOCK_PERIOD_G, 1.0E-9),
         RETRY_COUNTER_BITWIDTH => 8)
      port map (
         STABLE_CLOCK           => stableClkIn,
         RXUSERCLK              => rxUsrClkIn,
         SOFT_RESET             => rxUserResetInt,
         PLLREFCLKLOST          => rxPllRefClkLost,
         PLLLOCK                => rxPllLock,
         RXRESETDONE            => rxResetDone,           -- From GT
         MMCM_LOCK              => rxMmcmLockedIn,
         RECCLK_STABLE          => rxRecClkStable,        -- Asserted after 50,000 UI as per DS183
         RECCLK_MONITOR_RESTART => rxRecClkMonitorRestart,
         DATA_VALID             => rxDataValidIn,         -- From external decoder if used
         TXUSERRDY              => rxRstTxUserRdy,        -- Need to know when txUserRdy
         GTRXRESET              => gtRxReset,             -- To GT
         MMCM_RESET             => rxMmcmResetOut,
         PLL_RESET              => rxPllReset,
         RX_FSM_RESET_DONE      => rxFsmResetDone,
         RXUSERRDY              => rxUserRdyInt,          -- To GT
         RUN_PHALIGNMENT        => rxRunPhAlignment,      -- To Phase Alignment module
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

   GTX7_RX_REC_CLK_MONITOR_GEN : if (RX_BUF_EN_G = false) generate
      Gth7RecClkMonitor_Inst : entity work.Gth7RecClkMonitor
         generic map (
            COUNTER_UPPER_VALUE      => 15,
            GCLK_COUNTER_UPPER_VALUE => 15,
            CLOCK_PULSES             => 164,
            EXAMPLE_SIMULATION       => ite(SIMULATION_G, 1, 0))
         port map (
            GT_RST        => gtRxReset,
            REF_CLK       => gtRxRefClkBufg,
            RX_REC_CLK0   => rxOutClkBufg,  -- Only works if rxOutClkOut fed back on rxUsrClkIn through bufg
            SYSTEM_CLK    => stableClkIn,
            PLL_LK_DET    => rxPllLock,
            RECCLK_STABLE => rxRecClkStable,
            EXEC_RESTART  => rxRecClkMonitorRestart);
   end generate;

   RX_NO_RECCLK_MON_GEN : if (RX_BUF_EN_G) generate
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
   end generate RX_NO_RECCLK_MON_GEN;

   -------------------------------------------------------------------------------------------------
   -- Phase alignment needed when rx buffer is disabled
   -- Use normal Auto Phase Align module when RX_BUF_EN_G=false and RX_ALIGN_FIXED_LAT_G=false
   -- Use special fixed latency aligner when RX_BUF_EN_G=false and RX_ALIGN_FIXED_LAT_G=true
   -------------------------------------------------------------------------------------------------
   RX_AUTO_ALIGN_GEN : if (RX_BUF_EN_G = false and RX_ALIGN_MODE_G = "GT") generate
      Gth7AutoPhaseAligner_Rx : entity work.Gth7AutoPhaseAligner
         generic map (
            GT_TYPE => "GTX")
         port map (
            STABLE_CLOCK         => stableClkIn,
            RUN_PHALIGNMENT      => rxRunPhAlignment,      -- From RxRst
            PHASE_ALIGNMENT_DONE => rxPhaseAlignmentDone,  -- To RxRst
            PHALIGNDONE          => rxPhAlignDone,         -- From gt
            DLYSRESET            => rxDlySReset,           -- To gt
            DLYSRESETDONE        => rxDlySResetDone,       -- From gt
            RECCLKSTABLE         => rxRecClkStable);
      rxSlide <= rxSlideIn;                                -- User controlled rxSlide
   end generate;

   RX_FIX_LAT_ALIGN_GEN : if (RX_BUF_EN_G = false and RX_ALIGN_MODE_G = "FIXED_LAT") generate
      Gth7RxFixedLatPhaseAligner_Inst : entity work.Gth7RxFixedLatPhaseAligner
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
            rxRunPhAlignment     => rxRunPhAlignment,
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

   -- Mux proper PLL Lock signal onto txPllLock
   txPllLock <= cPllLock when (TX_PLL_G = "CPLL") else qPllLockIn when (TX_PLL_G = "QPLL") else '0';

   -- Mux proper PLL RefClkLost signal on txPllRefClkLost
   txPllRefClkLost <= cPllRefClkLost when (TX_PLL_G = "CPLL") else qPllRefClkLostIn when (TX_PLL_G = "QPLL") else '0';

   -- Drive outputs that have internal use
   txUserRdyOut <= txUserRdyInt;

   --------------------------------------------------------------------------------------------------
   -- Tx Reset Module
   --------------------------------------------------------------------------------------------------
   Gth7TxRst_Inst : entity work.Gth7TxRst
      generic map (
         TPD_G                  => TPD_G,
         GT_TYPE                => "GTX",
         STABLE_CLOCK_PERIOD    => getTimeRatio(STABLE_CLOCK_PERIOD_G, 1.0E-9),
         RETRY_COUNTER_BITWIDTH => 8)
      port map (
         STABLE_CLOCK      => stableClkIn,
         TXUSERCLK         => txUsrClkIn,
         SOFT_RESET        => txUserResetIn,
         PLLREFCLKLOST     => txPllRefClkLost,
         PLLLOCK           => txPllLock,
         TXRESETDONE       => txResetDone,         -- From GT
         MMCM_LOCK         => txMmcmLockedIn,
         GTTXRESET         => gtTxReset,
         MMCM_RESET        => txMmcmResetOut,
         PLL_RESET         => txPllReset,
         TX_FSM_RESET_DONE => txFsmResetDone,
         TXUSERRDY         => txUserRdyInt,
         RUN_PHALIGNMENT   => txRunPhAlignment,
         RESET_PHALIGNMENT => txResetPhAlignment,  -- Used for manual alignment
         PHALIGNMENT_DONE  => txPhaseAlignmentDone,
         RETRY_COUNTER     => open);               -- Might be interesting to look at

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
      
      PhaseAlign_Tx : entity work.Gth7AutoPhaseAligner
         generic map (
            GT_TYPE => "GTX")
         port map (
            STABLE_CLOCK         => stableClkIn,
            RUN_PHALIGNMENT      => txRunPhAlignment,
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
      Gth7TxManualPhaseAligner_1 : entity work.Gth7TxManualPhaseAligner
         generic map (
            TPD_G => TPD_G)
         port map (
            stableClk          => stableClkIn,
            resetPhAlignment   => txResetPhAlignment,
            runPhAlignment     => txRunPhAlignment,
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
      txPhaseAlignmentDone <= '1';
      txDlySReset          <= '0';
      txPhInit             <= '0';
      txPhAlign            <= '0';
      txDlyEn              <= '0';
      txPhAlignEn          <= '0';
   end generate NoTxPhaseAlignGen;

   --------------------------------------------------------------------------------------------------
   -- GTX Instantiation
   --------------------------------------------------------------------------------------------------
   gthe2_i : GTHE2_CHANNEL
      generic map(
         --_______________________ Simulation-Only Attributes ___________________
         SIM_RECEIVER_DETECT_PASS     => ("TRUE"),
         SIM_RESET_SPEEDUP            => (SIM_GTRESET_SPEEDUP_G),
         SIM_TX_EIDLE_DRIVE_LEVEL     => ("X"),
         SIM_CPLLREFCLK_SEL           => (CPLL_REFCLK_SEL_G),  --("001"),  -- GTPREFCLK0
         SIM_VERSION                  => (SIM_VERSION_G),
         ------------------RX Byte and Word Alignment Attributes---------------
         ALIGN_COMMA_DOUBLE           => ALIGN_COMMA_DOUBLE_G,
         ALIGN_COMMA_ENABLE           => ALIGN_COMMA_ENABLE_G,
         ALIGN_COMMA_WORD             => ALIGN_COMMA_WORD_G,
         ALIGN_MCOMMA_DET             => ALIGN_MCOMMA_DET_G,
         ALIGN_MCOMMA_VALUE           => ALIGN_MCOMMA_VALUE_G,
         ALIGN_PCOMMA_DET             => ALIGN_PCOMMA_DET_G,
         ALIGN_PCOMMA_VALUE           => ALIGN_PCOMMA_VALUE_G,
         SHOW_REALIGN_COMMA           => SHOW_REALIGN_COMMA_G,
         RXSLIDE_AUTO_WAIT            => 7,
         RXSLIDE_MODE                 => RXSLIDE_MODE_G,
         RX_SIG_VALID_DLY             => 10,
         ------------------RX 8B/10B Decoder Attributes---------------
         -- These don't really matter since RX 8B10B is disabled
         RX_DISPERR_SEQ_MATCH         => RX_DISPERR_SEQ_MATCH_G,
         DEC_MCOMMA_DETECT            => DEC_MCOMMA_DETECT_G,
         DEC_PCOMMA_DETECT            => DEC_PCOMMA_DETECT_G,
         DEC_VALID_COMMA_ONLY         => DEC_VALID_COMMA_ONLY_G,
         ------------------------RX Clock Correction Attributes----------------------
         CBCC_DATA_SOURCE_SEL         => CBCC_DATA_SOURCE_SEL_G,
         CLK_COR_SEQ_2_USE            => CLK_COR_SEQ_2_USE_G,
         CLK_COR_KEEP_IDLE            => CLK_COR_KEEP_IDLE_G,
         CLK_COR_MAX_LAT              => CLK_COR_MAX_LAT_G,
         CLK_COR_MIN_LAT              => CLK_COR_MIN_LAT_G,
         CLK_COR_PRECEDENCE           => CLK_COR_PRECEDENCE_G,
         CLK_COR_REPEAT_WAIT          => CLK_COR_REPEAT_WAIT_G,
         CLK_COR_SEQ_LEN              => CLK_COR_SEQ_LEN_G,
         CLK_COR_SEQ_1_ENABLE         => CLK_COR_SEQ_1_ENABLE_G,
         CLK_COR_SEQ_1_1              => CLK_COR_SEQ_1_1_G,                 -- UG476 pg 249
         CLK_COR_SEQ_1_2              => CLK_COR_SEQ_1_2_G,
         CLK_COR_SEQ_1_3              => CLK_COR_SEQ_1_3_G,
         CLK_COR_SEQ_1_4              => CLK_COR_SEQ_1_4_G,
         CLK_CORRECT_USE              => CLK_CORRECT_USE_G,
         CLK_COR_SEQ_2_ENABLE         => CLK_COR_SEQ_2_ENABLE_G,
         CLK_COR_SEQ_2_1              => CLK_COR_SEQ_2_1_G,                 -- UG476 pg 249
         CLK_COR_SEQ_2_2              => CLK_COR_SEQ_2_2_G,
         CLK_COR_SEQ_2_3              => CLK_COR_SEQ_2_3_G,
         CLK_COR_SEQ_2_4              => CLK_COR_SEQ_2_4_G,
         ------------------------RX Channel Bonding Attributes----------------------
         CHAN_BOND_KEEP_ALIGN         => CHAN_BOND_KEEP_ALIGN_G,
         CHAN_BOND_MAX_SKEW           => CHAN_BOND_MAX_SKEW_G,
         CHAN_BOND_SEQ_LEN            => CHAN_BOND_SEQ_LEN_G,
         CHAN_BOND_SEQ_1_1            => CHAN_BOND_SEQ_1_1_G,
         CHAN_BOND_SEQ_1_2            => CHAN_BOND_SEQ_1_2_G,
         CHAN_BOND_SEQ_1_3            => CHAN_BOND_SEQ_1_3_G,
         CHAN_BOND_SEQ_1_4            => CHAN_BOND_SEQ_1_4_G,
         CHAN_BOND_SEQ_1_ENABLE       => CHAN_BOND_SEQ_1_ENABLE_G,
         CHAN_BOND_SEQ_2_1            => CHAN_BOND_SEQ_2_1_G,
         CHAN_BOND_SEQ_2_2            => CHAN_BOND_SEQ_2_2_G,
         CHAN_BOND_SEQ_2_3            => CHAN_BOND_SEQ_2_3_G,
         CHAN_BOND_SEQ_2_4            => CHAN_BOND_SEQ_2_4_G,
         CHAN_BOND_SEQ_2_ENABLE       => CHAN_BOND_SEQ_2_ENABLE_G,
         CHAN_BOND_SEQ_2_USE          => CHAN_BOND_SEQ_2_USE_G,
         FTS_DESKEW_SEQ_ENABLE        => FTS_DESKEW_SEQ_ENABLE_G,
         FTS_LANE_DESKEW_CFG          => FTS_LANE_DESKEW_CFG_G,
         FTS_LANE_DESKEW_EN           => FTS_LANE_DESKEW_EN_G,
         ---------------------------RX Margin Analysis Attributes----------------------------
         ES_CONTROL                   => ("000000"),
         ES_ERRDET_EN                 => ("FALSE"),
         ES_EYE_SCAN_EN               => ("TRUE"),
         ES_HORZ_OFFSET               => (x"000"),
         ES_PMA_CFG                   => ("0000000000"),
         ES_PRESCALE                  => ("00000"),
         ES_QUALIFIER                 => (x"00000000000000000000"),
         ES_QUAL_MASK                 => (x"00000000000000000000"),
         ES_SDATA_MASK                => (x"00000000000000000000"),
         ES_VERT_OFFSET               => ("000000000"),
         -------------------------FPGA RX Interface Attributes-------------------------
         RX_DATA_WIDTH                => (RX_DATA_WIDTH_C),
         ---------------------------PMA Attributes----------------------------
         OUTREFCLK_SEL_INV            => ("11"),    -- ??
         PMA_RSV                      => PMA_RSV_G,      -- 
         PMA_RSV2                     => (x"1C00000A"),
         PMA_RSV3                     => ("00"),
         PMA_RSV4                     => (x"0008"),
         RX_BIAS_CFG                  => ("000011000000000000010000"),
         DMONITOR_CFG                 => (x"000A00"),
         RX_CM_SEL                    => ("11"),
         RX_CM_TRIM                   => RX_CM_TRIM_G,
         RX_DEBUG_CFG                 => ("00000000000000"),
         RX_OS_CFG                    => RX_OS_CFG_G,
         TERM_RCAL_CFG                => ("100001000010000"),
         TERM_RCAL_OVRD               => ("000"),
         TST_RSV                      => (x"00000000"),
         RX_CLK25_DIV                 => RX_CLK25_DIV_G,                    --(5),
         TX_CLK25_DIV                 => TX_CLK25_DIV_G,                    --(5),
         UCODEER_CLR                  => ('0'),
         ---------------------------PCI Express Attributes----------------------------
         PCS_PCIE_EN                  => ("FALSE"),
         ---------------------------PCS Attributes----------------------------
         PCS_RSVD_ATTR                => ite(RX_ALIGN_MODE_G = "FIXED_LAT", X"000000000002", X"000000000000"),  --UG476 pg 241
         -------------RX Buffer Attributes------------
         RXBUF_ADDR_MODE              => RX_BUF_ADDR_MODE_G,
         RXBUF_EIDLE_HI_CNT           => ("1000"),
         RXBUF_EIDLE_LO_CNT           => ("0000"),
         RXBUF_EN                     => toString(RX_BUF_EN_G),
         RX_BUFFER_CFG                => ("000000"),
         RXBUF_RESET_ON_CB_CHANGE     => ("TRUE"),
         RXBUF_RESET_ON_COMMAALIGN    => ("FALSE"),
         RXBUF_RESET_ON_EIDLE         => ("FALSE"),
         RXBUF_RESET_ON_RATE_CHANGE   => ("TRUE"),
         RXBUFRESET_TIME              => ("00001"),
         RXBUF_THRESH_OVFLW           => (61),
         RXBUF_THRESH_OVRD            => ("FALSE"),
         RXBUF_THRESH_UNDFLW          => (4),
         RXDLY_CFG                    => (x"001F"),
         RXDLY_LCFG                   => (x"030"),
         RXDLY_TAP_CFG                => (x"0000"),
         RXPH_CFG                     => (x"000000"),
         RXPHDLY_CFG                  => (x"084020"),
         RXPH_MONITOR_SEL             => ("00000"),
         RX_XCLK_SEL                  => RX_XCLK_SEL_C,
         RX_DDI_SEL                   => ("000000"),
         RX_DEFER_RESET_BUF_EN        => ("TRUE"),
         -----------------------CDR Attributes-------------------------
         RXCDR_CFG                    => RXCDR_CFG_G,
         RXCDR_FR_RESET_ON_EIDLE      => ('0'),
         RXCDR_HOLD_DURING_EIDLE      => ('0'),
         RXCDR_PH_RESET_ON_EIDLE      => ('0'),
         RXCDR_LOCK_CFG               => ("010101"),
         -------------------RX Initialization and Reset Attributes-------------------
         RXCDRFREQRESET_TIME          => ("00001"),
         RXCDRPHRESET_TIME            => ("00001"),
         RXISCANRESET_TIME            => ("00001"),
         RXPCSRESET_TIME              => ("00001"),
         RXPMARESET_TIME              => ("00011"),      -- ! Check this         
         -------------------RX OOB Signaling Attributes-------------------
         RXOOB_CFG                    => ("0000110"),
         -------------------------RX Gearbox Attributes---------------------------
         RXGEARBOX_EN                 => ("FALSE"),
         GEARBOX_MODE                 => ("000"),
         -------------------------PRBS Detection Attribute-----------------------
         RXPRBS_ERR_LOOPBACK          => ('0'),
         -------------Power-Down Attributes----------
         PD_TRANS_TIME_FROM_P2        => (x"03c"),
         PD_TRANS_TIME_NONE_P2        => (x"3c"),
         PD_TRANS_TIME_TO_P2          => (x"64"),
         -------------RX OOB Signaling Attributes----------
         SAS_MAX_COM                  => (64),
         SAS_MIN_COM                  => (36),
         SATA_BURST_SEQ_LEN           => ("1111"),
         SATA_BURST_VAL               => ("100"),
         SATA_EIDLE_VAL               => ("100"),
         SATA_MAX_BURST               => (8),
         SATA_MAX_INIT                => (21),
         SATA_MAX_WAKE                => (7),
         SATA_MIN_BURST               => (4),
         SATA_MIN_INIT                => (12),
         SATA_MIN_WAKE                => (4),
         -------------RX Fabric Clock Output Control Attributes----------
         TRANS_TIME_RATE              => (x"0E"),
         --------------TX Buffer Attributes----------------
         TXBUF_EN                     => toString(TX_BUF_EN_G),
         TXBUF_RESET_ON_RATE_CHANGE   => ("TRUE"),
         TXDLY_CFG                    => (x"001F"),
         TXDLY_LCFG                   => (x"030"),
         TXDLY_TAP_CFG                => (x"0000"),
         TXPH_CFG                     => (x"0780"),
         TXPHDLY_CFG                  => (x"084020"),
         TXPH_MONITOR_SEL             => ("00000"),
         TX_XCLK_SEL                  => TX_XCLK_SEL_C,
         -------------------------FPGA TX Interface Attributes-------------------------
         TX_DATA_WIDTH                => (TX_DATA_WIDTH_C),
         -------------------------TX Configurable Driver Attributes-------------------------
         TX_DEEMPH0                   => ("00000"),
         TX_DEEMPH1                   => ("00000"),
         TX_EIDLE_ASSERT_DELAY        => ("110"),
         TX_EIDLE_DEASSERT_DELAY      => ("100"),
         TX_LOOPBACK_DRIVE_HIZ        => ("FALSE"),
         TX_MAINCURSOR_SEL            => ('0'),
         TX_DRIVE_MODE                => ("DIRECT"),
         TX_MARGIN_FULL_0             => ("1001110"),
         TX_MARGIN_FULL_1             => ("1001001"),
         TX_MARGIN_FULL_2             => ("1000101"),
         TX_MARGIN_FULL_3             => ("1000010"),
         TX_MARGIN_FULL_4             => ("1000000"),
         TX_MARGIN_LOW_0              => ("1000110"),
         TX_MARGIN_LOW_1              => ("1000100"),
         TX_MARGIN_LOW_2              => ("1000010"),
         TX_MARGIN_LOW_3              => ("1000000"),
         TX_MARGIN_LOW_4              => ("1000000"),
         -------------------------TX Gearbox Attributes--------------------------
         TXGEARBOX_EN                 => ("FALSE"),
         -------------------------TX Initialization and Reset Attributes--------------------------
         TXPCSRESET_TIME              => ("00001"),
         TXPMARESET_TIME              => ("00001"),
         -------------------------TX Receiver Detection Attributes--------------------------
         TX_RXDETECT_CFG              => (x"1832"),
         TX_RXDETECT_REF              => ("100"),
         ----------------------------CPLL Attributes----------------------------
         CPLL_CFG                     => (x"00BC07DC"),
         CPLL_FBDIV                   => (CPLL_FBDIV_G),                    -- 4
         CPLL_FBDIV_45                => (CPLL_FBDIV_45_G),                 -- 5
         CPLL_INIT_CFG                => (x"00001E"),
         CPLL_LOCK_CFG                => (x"01E8"),
         CPLL_REFCLK_DIV              => (CPLL_REFCLK_DIV_G),               -- 1
         RXOUT_DIV                    => (RXOUT_DIV_G),  -- 2
         TXOUT_DIV                    => (TXOUT_DIV_G),  -- 2
         SATA_CPLL_CFG                => ("VCO_3000MHZ"),
         --------------RX Initialization and Reset Attributes-------------
         RXDFELPMRESET_TIME           => ("0001111"),
         --------------RX Equalizer Attributes-------------
         RXLPM_HF_CFG                 => ("00001000000000"),
         RXLPM_LF_CFG                 => ("001001000000000000"),
         RX_DFE_GAIN_CFG              => (x"0020C0"),
         RX_DFE_H2_CFG                => ("000000000000"),
         RX_DFE_H3_CFG                => ("000001000000"),
         RX_DFE_H4_CFG                => ("00011100000"),
         RX_DFE_H5_CFG                => ("00011100000"),
         RX_DFE_KL_CFG                => ("001000001000000000000001100010000"),
         RX_DFE_LPM_CFG               => RX_DFE_LPM_CFG_G,
         RX_DFE_LPM_HOLD_DURING_EIDLE => ('0'),
         RX_DFE_UT_CFG                => ("00011100000000000"),
         RX_DFE_VP_CFG                => ("00011101010100011"),
         -------------------------Power-Down Attributes-------------------------
         RX_CLKMUX_PD                 => ('1'),
         TX_CLKMUX_PD                 => ('1'),
         -------------------------FPGA RX Interface Attribute-------------------------
         RX_INT_DATAWIDTH             => RX_INT_DATAWIDTH_C,
         -------------------------FPGA TX Interface Attribute-------------------------
         TX_INT_DATAWIDTH             => TX_INT_DATAWIDTH_C,
         ------------------TX Configurable Driver Attributes---------------
         TX_QPI_STATUS_EN             => ('0'),
         ------------------ JTAG Attributes ---------------
         ACJTAG_DEBUG_MODE            => ('0'),
         ACJTAG_MODE                  => ('0'),
         ACJTAG_RESET                 => ('0'),
         ADAPT_CFG0                   => (x"00C10"),
         CFOK_CFG                     => (x"24800040E80"),
         CFOK_CFG2                    => (x"20"),
         CFOK_CFG3                    => (x"20"),
         ES_CLK_PHASE_SEL             => ('0'),
         PMA_RSV5                     => (x"0"),
         RESET_POWERSAVE_DISABLE      => ('0'),
         USE_PCS_CLK_PHASE_SEL        => ('0'),
         A_RXOSCALRESET               => ('0'),
         ------------------ RX Phase Interpolator Attributes---------------
         RXPI_CFG0                    => ("00"),
         RXPI_CFG1                    => ("00"),
         RXPI_CFG2                    => ("00"),
         RXPI_CFG3                    => ("11"),
         RXPI_CFG4                    => ('1'),
         RXPI_CFG5                    => ('1'),
         RXPI_CFG6                    => ("001"),
         --------------RX Decision Feedback Equalizer(DFE)-------------
         RX_DFELPM_CFG0               => ("0110"),
         RX_DFELPM_CFG1               => ('0'),
         RX_DFELPM_KLKH_AGC_STUP_EN   => ('1'),
         RX_DFE_AGC_CFG0              => ("00"),
         RX_DFE_AGC_CFG1              => ("100"),
         RX_DFE_AGC_CFG2              => ("0000"),
         RX_DFE_AGC_OVRDEN            => ('1'),
         RX_DFE_H6_CFG                => (x"020"),
         RX_DFE_H7_CFG                => (x"020"),
         RX_DFE_KL_LPM_KH_CFG0        => ("01"),
         RX_DFE_KL_LPM_KH_CFG1        => ("010"),
         RX_DFE_KL_LPM_KH_CFG2        => ("0010"),
         RX_DFE_KL_LPM_KH_OVRDEN      => ('1'),
         RX_DFE_KL_LPM_KL_CFG0        => ("10"),
         RX_DFE_KL_LPM_KL_CFG1        => ("010"),
         RX_DFE_KL_LPM_KL_CFG2        => ("0010"),
         RX_DFE_KL_LPM_KL_OVRDEN      => ('1'),
         RX_DFE_ST_CFG                => (x"00E100000C003F"),
         ------------------ TX Phase Interpolator Attributes---------------
         TXPI_CFG0                    => ("00"),
         TXPI_CFG1                    => ("00"),
         TXPI_CFG2                    => ("00"),
         TXPI_CFG3                    => ('0'),
         TXPI_CFG4                    => ('0'),
         TXPI_CFG5                    => ("100"),
         TXPI_GREY_SEL                => ('0'),
         TXPI_INVSTROBE_SEL           => ('0'),
         TXPI_PPMCLK_SEL              => ("TXUSRCLK2"),
         TXPI_PPM_CFG                 => (x"00"),
         TXPI_SYNFREQ_PPM             => ("000"),
         TX_RXDETECT_PRECHARGE_TIME   => (x"155CC"),
         ------------------ LOOPBACK Attributes---------------
         LOOPBACK_CFG                 => ('0'),
         ------------------RX OOB Signalling Attributes---------------
         RXOOB_CLK_CFG                => ("PMA"),
         ------------------ CDR Attributes ---------------
         RXOSCALRESET_TIME            => ("00011"),
         RXOSCALRESET_TIMEOUT         => ("00000"),
         ------------------TX OOB Signalling Attributes---------------
         TXOOB_CFG                    => '0',
         ------------------RX Buffer Attributes---------------
         RXSYNC_MULTILANE             => '0',
         RXSYNC_OVRD                  => '0',
         RXSYNC_SKIP_DA               => '0',
         ------------------TX Buffer Attributes---------------
         TXSYNC_MULTILANE             => '0',
         TXSYNC_OVRD                  => '0',
         TXSYNC_SKIP_DA               => '0')
      port map(
         ---------------------------------- Channel ---------------------------------
         CFGRESET                   => '0',
         DMONITOROUT                => open,
         GTRESETSEL                 => '0',         -- Sequential Mode
         GTRSVD                     => "0000000000000000",
         QPLLCLK                    => qPllClkIn,
         QPLLREFCLK                 => qPllRefClkIn,
         RESETOVRD                  => '0',
         ---------------- Channel - Dynamic Reconfiguration Port (DRP) --------------
         DRPADDR                    => drpMuxAddr,
         DRPCLK                     => stableClkIn,
         DRPDI                      => drpMuxDi,
         DRPDO                      => drpMuxDo,
         DRPEN                      => drpMuxEn,
         DRPRDY                     => drpMuxRdy,
         DRPWE                      => drpMuxWe,
         ------------------------- Channel - Ref Clock Ports ------------------------
         GTGREFCLK                  => gtGRefClk,
         GTNORTHREFCLK0             => gtNorthRefClk0,
         GTNORTHREFCLK1             => gtNorthRefClk1,
         GTREFCLK0                  => gtRefClk0,
         GTREFCLK1                  => gtRefClk1,
         GTREFCLKMONITOR            => open,
         GTSOUTHREFCLK0             => gtSouthRefClk0,
         GTSOUTHREFCLK1             => gtSouthRefClk1,
         -------------------------------- Channel PLL -------------------------------
         CPLLFBCLKLOST              => open,
         CPLLLOCK                   => cPllLock,
         CPLLLOCKDETCLK             => stableClkIn,
         CPLLLOCKEN                 => '1',
         CPLLPD                     => '0',
         CPLLREFCLKLOST             => cPllRefClkLost,
         CPLLREFCLKSEL              => to_stdlogicvector(CPLL_REFCLK_SEL_G),
         CPLLRESET                  => cPllReset,
         ------------------------------- Eye Scan Ports -----------------------------
         EYESCANDATAERROR           => open,
         EYESCANMODE                => '0',
         EYESCANRESET               => '0',
         EYESCANTRIGGER             => '0',
         ------------------------ Loopback and Powerdown Ports ----------------------
         LOOPBACK                   => loopbackIn,
         RXPD                       => rxPowerDown,
         TXPD                       => txPowerDown,
         ----------------------------- PCS Reserved Ports ---------------------------
         PCSRSVDIN                  => "0000000000000000",
         PCSRSVDIN2                 => "00000",
         PCSRSVDOUT                 => open,
         ----------------------------- PMA Reserved Ports ---------------------------
         PMARSVDIN                  => "00000",
         ------------------------------- Receive Ports ------------------------------
         RXQPIEN                    => '0',
         RXQPISENN                  => open,
         RXQPISENP                  => open,
         RXSYSCLKSEL                => RX_SYSCLK_SEL_C,
         RXUSERRDY                  => rxUserRdyInt,
         CLKRSVD0                   => '0',
         CLKRSVD1                   => '0',
         DMONFIFORESET              => '0',
         DMONITORCLK                => '0',
         RXPMARESETDONE             => rxPmaResetDone,
         RXRATEMODE                 => '0',
         SIGVALIDCLK                => '0',
         -------------- Receive Ports - 64b66b and 64b67b Gearbox Ports -------------
         RXDATAVALID                => open,
         RXGEARBOXSLIP              => '0',
         RXHEADER                   => open,
         RXHEADERVALID              => open,
         RXSTARTOFSEQ               => open,
         ----------------------- Receive Ports - 8b10b Decoder ----------------------
         RX8B10BEN                  => toSl(RX_8B10B_EN_G),
         RXCHARISCOMMA              => open,
         RXCHARISK                  => rxCharIsKFull,
         RXDISPERR                  => rxDispErrFull,
         RXNOTINTABLE               => rxDecErrFull,
         ------------------- Receive Ports - Channel Bonding Ports ------------------
         RXCHANBONDSEQ              => open,
         RXCHBONDEN                 => toSl(RX_CHAN_BOND_EN_G),
         RXCHBONDI                  => rxChBondIn,  --"00000",
         RXCHBONDLEVEL              => rxChBondLevelIn,  --"000",
         RXCHBONDMASTER             => toSl(RX_CHAN_BOND_MASTER_G),
         RXCHBONDO                  => rxChBondOut,
         RXCHBONDSLAVE              => toSl(RX_CHAN_BOND_MASTER_G = false),
         ------------------- Receive Ports - Channel Bonding Ports  -----------------
         RXCHANISALIGNED            => open,
         RXCHANREALIGN              => open,
         ------------------- Receive Ports - Clock Correction Ports -----------------
         RXCLKCORCNT                => open,
         --------------- Receive Ports - Comma Detection and Alignment --------------
         RXBYTEISALIGNED            => open,
         RXBYTEREALIGN              => open,
         RXCOMMADET                 => open,
         RXCOMMADETEN               => toSl(RX_ALIGN_MODE_G /= "NONE"),     -- Enables RXSLIDE
         RXMCOMMAALIGNEN            => toSl(ALIGN_MCOMMA_EN_G = '1' and (RX_ALIGN_MODE_G = "GT")),
         RXPCOMMAALIGNEN            => toSl(ALIGN_PCOMMA_EN_G = '1' and (RX_ALIGN_MODE_G = "GT")),
         RXSLIDE                    => rxSlide,
         ----------------------- Receive Ports - PRBS Detection ---------------------
         RXPRBSCNTRESET             => '0',
         RXPRBSERR                  => open,
         RXPRBSSEL                  => "000",
         ------------------- Receive Ports - RX Data Path interface -----------------
         GTRXRESET                  => gtRxReset,
         RXDATA                     => rxDataFull,
         RXOUTCLK                   => rxOutClk,
         RXOUTCLKFABRIC             => open,
         RXOUTCLKPCS                => open,
         RXOUTCLKSEL                => to_stdlogicvector(RX_OUTCLK_SEL_C),  -- Selects rx recovered clk for rxoutclk
         RXPCSRESET                 => '0',         -- Don't bother with component level resets
         RXPMARESET                 => '0',
         RXUSRCLK                   => rxUsrClkIn,
         RXUSRCLK2                  => rxUsrClk2In,
         --------------------- Receive Ports - RX Equalizer Ports -------------------
         RXDFESLIDETAPSTARTED       => open,
         RXDFESLIDETAPSTROBEDONE    => open,
         RXDFESLIDETAPSTROBESTARTED => open,
         ------------ Receive Ports - RX Decision Feedback Equalizer(DFE) -----------
         RXADAPTSELTEST             => (others => '0'),
         RXDFEAGCHOLD               => rxDfeAgcHold,
         RXDFEAGCOVRDEN             => '0',
         RXDFEAGCTRL                => "01000",
         RXDFECM1EN                 => '0',
         RXDFELFHOLD                => rxDfeLfHold,
         RXDFELFOVRDEN              => RXDFELFOVRDEN_G,
         RXDFELPMRESET              => '0',
         RXDFESLIDETAP              => "00000",
         RXDFESLIDETAPADAPTEN       => '0',
         RXDFESLIDETAPHOLD          => '0',
         RXDFESLIDETAPID            => "000000",
         RXDFESLIDETAPINITOVRDEN    => '0',
         RXDFESLIDETAPONLYADAPTEN   => '0',
         RXDFESLIDETAPSTROBE        => '0',
         RXDFESTADAPTDONE           => open,
         RXDFETAP2HOLD              => '0',
         RXDFETAP2OVRDEN            => '0',
         RXDFETAP3HOLD              => '0',
         RXDFETAP3OVRDEN            => '0',
         RXDFETAP4HOLD              => '0',
         RXDFETAP4OVRDEN            => '0',
         RXDFETAP5HOLD              => '0',
         RXDFETAP5OVRDEN            => '0',
         RXDFETAP6HOLD              => '0',
         RXDFETAP6OVRDEN            => '0',
         RXDFETAP7HOLD              => '0',
         RXDFETAP7OVRDEN            => '0',
         RXDFEUTHOLD                => '0',
         RXDFEUTOVRDEN              => '0',
         RXDFEVPHOLD                => '0',
         RXDFEVPOVRDEN              => '0',
         RXDFEVSEN                  => '0',
         RXDFEXYDEN                 => RXDFEXYDEN_G,
         RXMONITOROUT               => open,
         RXMONITORSEL               => "00",
         RXOSHOLD                   => '0',
         RXOSINTCFG                 => "0110",
         RXOSINTEN                  => '1',
         RXOSINTHOLD                => '0',
         RXOSINTID0                 => "0000",
         RXOSINTNTRLEN              => '0',
         RXOSINTOVRDEN              => '0',
         RXOSINTSTARTED             => open,
         RXOSINTSTROBE              => '0',
         RXOSINTSTROBEDONE          => open,
         RXOSINTSTROBESTARTED       => open,
         RXOSINTTESTOVRDEN          => '0',
         RXOSOVRDEN                 => '0',
         ------- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
         GTHRXN                     => gtRxN,
         GTHRXP                     => gtRxP,
         RXCDRFREQRESET             => '0',
         RXCDRHOLD                  => '0',
         RXCDRLOCK                  => rxCdrLock,
         RXCDROVRDEN                => '0',
         RXCDRRESET                 => '0',
         RXCDRRESETRSV              => '0',
         RXELECIDLE                 => open,
         RXELECIDLEMODE             => "11",
         RXLPMEN                    => ite(RX_EQUALIZER_G = "LPM", '1', '0'),
         RXLPMHFHOLD                => rxLpmHfHold,
         RXLPMHFOVRDEN              => '0',
         RXLPMLFHOLD                => rxLpmLfHold,
         RXLPMLFKLOVRDEN            => '0',
         RXOOBRESET                 => '0',
         ------------ Receive Ports - RX Decision Feedback Equalizer(DFE) -----------
         RSOSINTDONE                => open,
         RXDFESLIDETAPOVRDEN        => '0',
         RXOSCALRESET               => '0',
         -------- Receive Ports - RX Elastic Buffer and Phase Alignment Ports -------
         RXBUFRESET                 => '0',
         RXBUFSTATUS                => rxBufStatusOut,
         RXDDIEN                    => RX_DDIEN_G,  -- Don't insert delay in deserializer. Might be wrong.
         RXDLYBYPASS                => RX_DLY_BYPASS_G,
         RXDLYEN                    => '0',         -- Used for manual phase align
         RXDLYOVRDEN                => '0',
         RXDLYSRESET                => rxDlySReset,
         RXDLYSRESETDONE            => rxDlySResetDone,
         RXPHALIGN                  => '0',
         RXPHALIGNDONE              => rxPhAlignDone,
         RXPHALIGNEN                => '0',
         RXPHDLYPD                  => '0',
         RXPHDLYRESET               => '0',
         RXPHMONITOR                => open,
         RXPHOVRDEN                 => '0',
         RXPHSLIPMONITOR            => open,
         RXSTATUS                   => open,
         RXSYNCALLIN                => '0',
         RXSYNCDONE                 => open,
         RXSYNCIN                   => '0',
         RXSYNCMODE                 => '0',
         RXSYNCOUT                  => open,
         ------------------------ Receive Ports - RX PLL Ports ----------------------
         RXRATE                     => "000",
         RXRATEDONE                 => open,
         RXRESETDONE                => rxResetDone,
         -------------- Receive Ports - RX Pipe Control for PCI Express -------------
         PHYSTATUS                  => open,
         RXVALID                    => open,
         ----------------- Receive Ports - RX Polarity Control Ports ----------------
         RXPOLARITY                 => rxPolarityIn,
         --------------------- Receive Ports - RX Ports for SATA --------------------
         RXCOMINITDET               => open,
         RXCOMSASDET                => open,
         RXCOMWAKEDET               => open,
         ------------------------------- Transmit Ports -----------------------------
         SETERRSTATUS               => '0',
         TSTIN                      => "11111111111111111111",
         TXPHDLYTSTCLK              => '0',
         TXPOSTCURSOR               => txPostCursor,
         TXPOSTCURSORINV            => '0',
         TXPRECURSOR                => txPreCursor,
         TXPRECURSORINV             => '0',
         TXQPIBIASEN                => '0',
         TXQPISENN                  => open,
         TXQPISENP                  => open,
         TXQPISTRONGPDOWN           => '0',
         TXQPIWEAKPUP               => '0',
         TXSYSCLKSEL                => TX_SYSCLK_SEL_C,
         TXUSERRDY                  => txUserRdyInt,
         TXRATEMODE                 => '0',
         TXPMARESETDONE             => open,
         ----------------- TX Phase Interpolator PPM Controller Ports ---------------
         TXPIPPMEN                  => '0',
         TXPIPPMOVRDEN              => '0',
         TXPIPPMPD                  => '0',
         TXPIPPMSEL                 => '1',
         TXPIPPMSTEPSIZE            => "00000",
         -------------- Transmit Ports - 64b66b and 64b67b Gearbox Ports ------------
         TXGEARBOXREADY             => open,
         TXHEADER                   => "000",
         TXSEQUENCE                 => "0000000",
         TXSTARTSEQ                 => '0',
         ---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
         TX8B10BBYPASS              => X"00",
         TX8B10BEN                  => toSl(TX_8B10B_EN_G),
         TXCHARDISPMODE             => txCharDispMode,
         TXCHARDISPVAL              => txCharDispVal,
         TXCHARISK                  => txCharIsKFull,
         ------------ Transmit Ports - TX Buffer and Phase Alignment Ports ----------
         TXBUFSTATUS                => txBufStatusOut,
         TXDLYBYPASS                => TX_DLY_BYPASS_G,  -- Use the tx delay alignment circuit
         TXDLYEN                    => txDlyEn,     -- Manual Align
         TXDLYHOLD                  => '0',
         TXDLYOVRDEN                => '0',
         TXDLYSRESET                => txDlySReset,
         TXDLYSRESETDONE            => txDlySResetDone,
         TXDLYUPDOWN                => '0',
         TXPHALIGN                  => txPhAlign,   -- Manual Align
         TXPHALIGNDONE              => txPhAlignDone,
         TXPHALIGNEN                => txPhAlignEn,      -- Enables manual align
         TXPHDLYPD                  => '0',
         TXPHDLYRESET               => '0',         -- Use SReset instead
         TXPHINIT                   => txPhInit,    -- Manual Align
         TXPHINITDONE               => txPhInitDone,
         TXPHOVRDEN                 => '0',
         TXSYNCALLIN                => '0',
         TXSYNCDONE                 => open,
         TXSYNCIN                   => '0',
         TXSYNCMODE                 => '0',
         TXSYNCOUT                  => open,
         ------------------ Transmit Ports - TX Data Path interface -----------------
         GTTXRESET                  => gtTxReset,
         TXDATA                     => txDataFull,
         TXOUTCLK                   => txOutClkOut,
         TXOUTCLKFABRIC             => open,        --txGtRefClk,
         TXOUTCLKPCS                => open,        --txOutClkPcsOut,
         TXOUTCLKSEL                => to_stdlogicvector(TX_OUTCLK_SEL_C),
         TXPCSRESET                 => '0',         -- Don't bother with individual resets
         TXPMARESET                 => '0',
         TXUSRCLK                   => txUsrClkIn,
         TXUSRCLK2                  => txUsrClk2In,
         ---------------- Transmit Ports - TX Driver and OOB signaling --------------
         GTHTXN                     => gtTxN,
         GTHTXP                     => gtTxP,
         TXBUFDIFFCTRL              => "100",
         TXDIFFCTRL                 => txDiffCtrl,
         TXDIFFPD                   => '0',
         TXINHIBIT                  => '0',
         TXMAINCURSOR               => "0000000",
         TXPDELECIDLEMODE           => '0',
         TXPISOPD                   => '0',
         ----------------------- Transmit Ports - TX PLL Ports ----------------------
         TXRATE                     => "000",
         TXRATEDONE                 => open,
         TXRESETDONE                => txResetDone,
         --------------------- Transmit Ports - TX PRBS Generator -------------------
         TXPRBSFORCEERR             => '0',
         TXPRBSSEL                  => "000",
         -------------------- Transmit Ports - TX Polarity Control ------------------
         TXPOLARITY                 => txPolarityIn,
         ----------------- Transmit Ports - TX Ports for PCI Express ----------------
         TXDEEMPH                   => '0',
         TXDETECTRX                 => '0',
         TXELECIDLE                 => '0',
         TXMARGIN                   => "000",
         TXSWING                    => '0',
         --------------------- Transmit Ports - TX Ports for SATA -------------------
         TXCOMFINISH                => open,
         TXCOMINIT                  => '0',
         TXCOMSAS                   => '0',
         TXCOMWAKE                  => '0');

   ------------------------- Soft Fix for Production Silicon----------------------
   Gth7RxRstSeq_Inst : entity work.Gth7RxRstSeq
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
