-------------------------------------------------------------------------------
-- File       : GtpDualFixedLatCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-11-28
-- Last update: 2013-08-02
-------------------------------------------------------------------------------
-- Description: Pgp2 Gtp Low Latency Core
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
library UNISIM;
use UNISIM.VCOMPONENTS.all;
use work.StdRtlPkg.all;

entity GtpDualFixedLatCore is
   generic (
      TPD_G : time := 1 ns;

      -- GTP Parameters
      SIM_PLL_PERDIV2 : bit_vector := X"0C8";  -- "011001000";
      CLK25_DIVIDER   : integer    := 5;
      PLL_DIVSEL_FB   : integer    := 2;
      PLL_DIVSEL_REF  : integer    := 1;

      -- Recovered clock parameters
      REC_CLK_PERIOD : real    := 4.000;
      REC_PLL_MULT   : integer := 4;
      REC_PLL_DIV    : integer := 1
      );
   port (

      -- GTP Signals
      gtpClkIn     : in  std_logic;        -- GTP Reference Clock In
      gtpRefClkOut : out std_logic;        -- GTP Reference Clock Output
      gtpRxN       : in  slv(1 downto 0);  -- GTP Serial Receive Negative
      gtpRxP       : in  slv(1 downto 0);  -- GTP Serial Receive Positive
      gtpTxN       : out slv(1 downto 0);  -- GTP Serial Transmit Negative
      gtpTxP       : out slv(1 downto 0);  -- GTP Serial Transmit Positive

      -- Shared
      gtpReset      : in  std_logic;
      gtpResetDone  : out slv(1 downto 0);
      gtpPllLockDet : out std_logic;
      gtpLoopback   : in  slv(1 downto 0);

      -- Rx Resets
      gtpRxReset       : in  slv(1 downto 0);
      gtpRxCdrReset    : in  slv(1 downto 0);
      gtpRxElecIdle    : out slv(1 downto 0);
      gtpRxElecIdleRst : in  slv(1 downto 0);

      -- Rx Clocks
      gtpRxUsrClk    : out slv(1 downto 0);  -- 1 byte clock (recovered)
      gtpRxUsrClk2   : out slv(1 downto 0);  -- 2 byte clock (recovered)
      gtpRxUsrClkRst : out slv(1 downto 0);  -- Reset for 2 byte clock

      -- Rx Data
      gtpRxData     : out slv16Array(1 downto 0);
      gtpRxDataK    : out slv2Array(1 downto 0);
      gtpRxDecErr   : out slv2Array(1 downto 0);
      gtpRxDispErr  : out slv2Array(1 downto 0);
      gtpRxPolarity : in  slv(1 downto 0);
      gtpRxAligned  : out slv(1 downto 0);

      -- Tx Resets
      gtpTxReset : in slv(1 downto 0);

      -- Tx Clocks
      gtpTxUsrClk  : in std_logic;
      gtpTxUsrClk2 : in std_logic;

      gtpTxAligned : out std_logic;

      -- Tx Data
      gtpTxData  : in slv16Array(1 downto 0);
      gtpTxDataK : in slv2Array(1 downto 0)
      );

end GtpDualFixedLatCore;

architecture rtl of GtpDualFixedLatCore is

   signal gtpPllLockDetInt : std_logic;
   signal tmpRefClkOut     : std_logic;

   --------------------------------------------------------------------------------------------------
   -- Rx Signals
   --------------------------------------------------------------------------------------------------
   -- Clocking
   signal gtpRxRecClk       : slv(1 downto 0);  -- Raw rxrecclk from GTP, not square, needs DCM or PLL
   signal gtpRxRecClkBufG   : slv(1 downto 0);
   signal rxRecClkPllOut0   : slv(1 downto 0);  -- 1 byte clock
   signal rxRecClkPllOut1   : slv(1 downto 0);  -- 2 byte clock
   signal rxRecClkPllOut2   : slv(1 downto 0);  -- 2 byte clock (180 deg phase shift)
   signal rxRecClkPllFbIn   : slv(1 downto 0);
   signal rxRecClkPllFbOut  : slv(1 downto 0);
   signal rxRecClkPllLocked : slv(1 downto 0);
   signal rxUsrClk2Sel      : slv(1 downto 0);  -- Selects which 2 byte clock is used
   signal gtpRxUsrClkInt    : slv(1 downto 0);
   signal gtpRxUsrClk2Int   : slv(1 downto 0);
   signal gtpRxUsrClkRstInt : slv(1 downto 0);

   -- Rx Data
   signal gtpRxDataRaw    : slv20Array(1 downto 0);
   signal gtpRxDecErrInt  : slv2Array(1 downto 0);
   signal gtpRxDispErrInt : slv2Array(1 downto 0);

   -- Rx Phase Alignment
   signal gtpRxSlide : slv(1 downto 0);

   -- Tx Phase Alignment
   signal gtpTxEnPmaPhaseAlign : std_logic;
   signal gtpTxPmaSetPhase     : std_logic;

   -- Resets
   signal gtpRxCdrResetFinal : slv(1 downto 0);
   signal rxCommaAlignReset  : slv(1 downto 0);

begin

   DUAL_INST_LOOP : for i in 1 downto 0 generate


      --------------------------------------------------------------------------------------------------
      -- Rx Data Path
      --------------------------------------------------------------------------------------------------
      RX_REC_CLK_BUFG : BUFG
         port map (
            O => gtpRxRecClkBufG(i),    -- Feeds pll clkin
            I => gtpRxRecClk(i));       -- From GTP RXRECCLK

      RX_REC_CLK_PLL : PLL_BASE
         generic map(
            BANDWIDTH          => "OPTIMIZED",
            CLKIN_PERIOD       => REC_CLK_PERIOD,
            CLKOUT0_DIVIDE     => REC_PLL_MULT,
            CLKOUT1_DIVIDE     => REC_PLL_MULT * 2,
            CLKOUT2_DIVIDE     => REC_PLL_MULT * 2,
            CLKOUT0_PHASE      => 0.000,
            CLKOUT1_PHASE      => 0.000,
            CLKOUT2_PHASE      => 180.000,
            CLKOUT0_DUTY_CYCLE => 0.500,
            CLKOUT1_DUTY_CYCLE => 0.500,
            CLKOUT2_DUTY_CYCLE => 0.500,
            COMPENSATION       => "SYSTEM_SYNCHRONOUS",
            DIVCLK_DIVIDE      => REC_PLL_DIV,
            CLKFBOUT_MULT      => REC_PLL_MULT,
            CLKFBOUT_PHASE     => 0.0,
            REF_JITTER         => 0.005000)
         port map (
            CLKFBIN  => rxRecClkPllFbIn(i),
            CLKIN    => gtpRxRecClkBufG(i),
            RST      => '0',
            CLKFBOUT => rxRecClkPllFbOut(i),
            CLKOUT0  => rxRecClkPllOut0(i),
            CLKOUT1  => rxRecClkPllOut1(i),
            CLKOUT2  => rxRecClkPllOut2(i),
            CLKOUT3  => open,
            CLKOUT4  => open,
            CLKOUT5  => open,
            LOCKED   => rxRecClkPllLocked(i));

      -- Feedback for PLL
      RX_REC_CLK_PLL_FB_BUFG : BUFG
         port map (
            O => rxRecClkPllFbIn(i),
            I => rxRecClkPllFbOut(i));

      -- Buffer pll outputs
      RX_USR_CLK_BUFG : BUFG
         port map (
            I => rxRecClkPllOut0(i),
            O => gtpRxUsrClkInt(i));

      RX_USR_CLK2_BUFMUX : BUFGMUX_CTRL
         port map (
            I1 => rxRecClkPllOut1(i),
            I0 => rxRecClkPllOut2(i),
            S  => rxUsrClk2Sel(i),
            O  => gtpRxUsrClk2Int(i));

      RstSync_1 : entity work.RstSync
         generic map (
            TPD_G           => TPD_G,
            IN_POLARITY_G   => '0',
            OUT_POLARITY_G  => '1',
            RELEASE_DELAY_G => 3)
         port map (
            clk      => gtpRxUsrClk2Int(i),
            asyncRst => rxRecClkPllLocked(i),
            syncRst  => gtpRxUsrClkRstInt(i));

      -- Output recovered clocks for external use
      gtpRxUsrClk2(i)   <= gtpRxUsrClk2Int(i);
      gtpRxUsrClk(i)    <= gtpRxUsrClkInt(i);
      gtpRxUsrClkRst(i) <= gtpRxUsrClkRstInt(i);

      -- Comma aligner and RxRst modules both drive CDR Reset
      gtpRxCdrResetFinal(i) <= gtpRxCdrReset(i) or rxCommaAlignReset(i);

      -- Manual comma aligner
      GtpRxCommaAligner_1 : entity work.GtpRxCommaAligner
         generic map (
            TPD_G => TPD_G)
         port map (
            gtpRxUsrClk2    => gtpRxUsrClk2Int(i),
            gtpRxUsrClk2Rst => gtpRxUsrClkRstInt(i),
            gtpRxData       => gtpRxDataRaw(i),
            codeErr         => gtpRxDecErrInt(i),
            dispErr         => gtpRxDispErrInt(i),
            gtpRxUsrClk2Sel => rxUsrClk2Sel(i),
            gtpRxSlide      => gtpRxSlide(i),
            gtpRxCdrReset   => rxCommaAlignReset(i),
            aligned         => gtpRxAligned(i));

      Decoder8b10b_1 : entity work.Decoder8b10b
         generic map (
            TPD_G          => TPD_G,
            NUM_BYTES_G    => 2,
            RST_POLARITY_G => '1',
            RST_ASYNC_G    => true)        
         port map (
            clk      => gtpRxUsrClk2Int(i),
            rst      => gtpRxUsrClkRstInt(i),
            dataIn   => gtpRxDataRaw(i),
            dataOut  => gtpRxData(i),
            dataKOut => gtpRxDataK(i),
            codeErr  => gtpRxDecErrInt(i),
            dispErr  => gtpRxDispErrInt(i));

      -- Assign internal signals to outputs
      gtpRxDecErr(i)  <= gtpRxDecErrInt(i);
      gtpRxDispErr(i) <= gtpRxDispErrInt(i);

   end generate DUAL_INST_LOOP;

   --------------------------------------------------------------------------------------------------
   -- Tx Data Path
   --------------------------------------------------------------------------------------------------
   GtpTxPhaseAligner_1 : entity work.GtpTxPhaseAligner
      generic map (
         TPD_G => TPD_G)
      port map (
         gtpTxUsrClk2         => gtpTxUsrClk2,
         gtpReset             => gtpReset,
         gtpPllLockDetect     => gtpPllLockDetInt,
         gtpTxEnPmaPhaseAlign => gtpTxEnPmaPhaseAlign,
         gtpTxPmaSetPhase     => gtpTxPmaSetPhase,
         gtpTxAligned         => gtpTxAligned);

   REFCLK_BUFG : BUFG
      port map (
         I => tmpRefClkOut,
         O => gtpRefClkOut);

   gtpPllLockDet <= gtpPllLockDetInt;

   --------------------------------------------------------------------------------------------------
   -- GTP Instance
   --------------------------------------------------------------------------------------------------


   ----------------------------- GTP_DUAL Instance  --------------------------   
   UGtpDual : GTP_DUAL
      generic map (

         --_______________________ Simulation-Only Attributes ___________________

         SIM_GTPRESET_SPEEDUP => 0,
         SIM_PLL_PERDIV2      => SIM_PLL_PERDIV2,  -- x"0C8",

         --___________________________ Shared Attributes ________________________

         -------------------------- Tile and PLL Attributes ---------------------

         CLK25_DIVIDER         => CLK25_DIVIDER,   -- For 125 MHz clkin
         CLKINDC_B             => true,
         OOB_CLK_DIVIDER       => 6,
         OVERSAMPLE_MODE       => false,
         PLL_DIVSEL_FB         => PLL_DIVSEL_FB,
         PLL_DIVSEL_REF        => PLL_DIVSEL_REF,  -- creates pll clock = 2.5 GHz w/ 125 Mhz clkin
         PLL_TXDIVSEL_COMM_OUT => 1,
         TX_SYNC_FILTERB       => 1,

         --____________________ Transmit Interface Attributes ___________________

         ------------------- TX Buffering and Phase Alignment -------------------   

         TX_BUFFER_USE_0 => false,
         TX_XCLK_SEL_0   => "TXUSR",
         TXRX_INVERT_0   => "00100",

         TX_BUFFER_USE_1 => false,
         TX_XCLK_SEL_1   => "TXUSR",
         TXRX_INVERT_1   => "00100",

         --------------------- TX Serial Line Rate settings ---------------------   

         PLL_TXDIVSEL_OUT_0 => 1,       -- Must be 1 when TX_BUFFER_USE = false

         PLL_TXDIVSEL_OUT_1 => 1,

         --------------------- TX Driver and OOB signalling --------------------  

         TX_DIFF_BOOST_0 => true,

         TX_DIFF_BOOST_1 => true,

         ------------------ TX Pipe Control for PCI Express/SATA ---------------

         COM_BURST_VAL_0 => "1111",

         COM_BURST_VAL_1 => "1111",
         --_______________________ Receive Interface Attributes ________________

         ------------ RX Driver,OOB signalling,Coupling and Eq,CDR -------------  

         AC_CAP_DIS_0          => true,
         OOBDETECT_THRESHOLD_0 => "001",
         PMA_CDR_SCAN_0        => x"6c07640",
         PMA_RX_CFG_0          => x"09f0089",
         RCV_TERM_GND_0        => false,
         RCV_TERM_MID_0        => false,
         RCV_TERM_VTTRX_0      => false,
         TERMINATION_IMP_0     => 50,

         AC_CAP_DIS_1          => true,
         OOBDETECT_THRESHOLD_1 => "001",
         PMA_CDR_SCAN_1        => x"6c07640",
         PMA_RX_CFG_1          => x"09f0089",
         RCV_TERM_GND_1        => false,
         RCV_TERM_MID_1        => false,
         RCV_TERM_VTTRX_1      => false,
         TERMINATION_IMP_1     => 50,
         TERMINATION_CTRL      => "10100",
         TERMINATION_OVRD      => false,

         --------------------- RX Serial Line Rate Attributes ------------------   

         PLL_RXDIVSEL_OUT_0 => 1,
         PLL_SATA_0         => true,

         PLL_RXDIVSEL_OUT_1 => 1,
         PLL_SATA_1         => true,

         ----------------------- PRBS Detection Attributes ---------------------  

         PRBS_ERR_THRESHOLD_0 => x"00000001",

         PRBS_ERR_THRESHOLD_1 => x"00000001",

         ---------------- Comma Detection and Alignment Attributes -------------  

         ALIGN_COMMA_WORD_0     => 2,
         COMMA_10B_ENABLE_0     => "1111111111",
         COMMA_DOUBLE_0         => false,
         DEC_MCOMMA_DETECT_0    => false,
         DEC_PCOMMA_DETECT_0    => false,
         DEC_VALID_COMMA_ONLY_0 => false,
         MCOMMA_10B_VALUE_0     => "1010000011",
         MCOMMA_DETECT_0        => false,
         PCOMMA_10B_VALUE_0     => "0101111100",
         PCOMMA_DETECT_0        => false,
         RX_SLIDE_MODE_0        => "PMA",

         ALIGN_COMMA_WORD_1     => 2,
         COMMA_10B_ENABLE_1     => "1111111111",
         COMMA_DOUBLE_1         => false,
         DEC_MCOMMA_DETECT_1    => false,
         DEC_PCOMMA_DETECT_1    => false,
         DEC_VALID_COMMA_ONLY_1 => false,
         MCOMMA_10B_VALUE_1     => "1010000011",
         MCOMMA_DETECT_1        => false,
         PCOMMA_10B_VALUE_1     => "0101111100",
         PCOMMA_DETECT_1        => false,
         RX_SLIDE_MODE_1        => "PMA",

         ------------------ RX Loss-of-sync State Machine Attributes -----------  

         RX_LOSS_OF_SYNC_FSM_0 => false,
         RX_LOS_INVALID_INCR_0 => 8,
         RX_LOS_THRESHOLD_0    => 128,

         RX_LOSS_OF_SYNC_FSM_1 => false,
         RX_LOS_INVALID_INCR_1 => 8,
         RX_LOS_THRESHOLD_1    => 128,

         -------------- RX Elastic Buffer and Phase alignment Attributes -------   

         RX_BUFFER_USE_0 => false,
         RX_XCLK_SEL_0   => "RXUSR",

         RX_BUFFER_USE_1 => false,
         RX_XCLK_SEL_1   => "RXUSR",

         ------------------------ Clock Correction Attributes ------------------   

         CLK_CORRECT_USE_0          => false,
         CLK_COR_ADJ_LEN_0          => 4,
         CLK_COR_DET_LEN_0          => 4,
         CLK_COR_INSERT_IDLE_FLAG_0 => false,
         CLK_COR_KEEP_IDLE_0        => false,
         CLK_COR_MAX_LAT_0          => 48,
         CLK_COR_MIN_LAT_0          => 36,
         CLK_COR_PRECEDENCE_0       => true,
         CLK_COR_REPEAT_WAIT_0      => 0,
         CLK_COR_SEQ_1_1_0          => "0110111100",
         CLK_COR_SEQ_1_2_0          => "0100011100",
         CLK_COR_SEQ_1_3_0          => "0100011100",
         CLK_COR_SEQ_1_4_0          => "0100011100",
         CLK_COR_SEQ_1_ENABLE_0     => "1111",
         CLK_COR_SEQ_2_1_0          => "0000000000",
         CLK_COR_SEQ_2_2_0          => "0000000000",
         CLK_COR_SEQ_2_3_0          => "0000000000",
         CLK_COR_SEQ_2_4_0          => "0000000000",
         CLK_COR_SEQ_2_ENABLE_0     => "0000",
         CLK_COR_SEQ_2_USE_0        => false,
         RX_DECODE_SEQ_MATCH_0      => true,

         CLK_CORRECT_USE_1          => false,
         CLK_COR_ADJ_LEN_1          => 4,
         CLK_COR_DET_LEN_1          => 4,
         CLK_COR_INSERT_IDLE_FLAG_1 => false,
         CLK_COR_KEEP_IDLE_1        => false,
         CLK_COR_MAX_LAT_1          => 48,
         CLK_COR_MIN_LAT_1          => 36,
         CLK_COR_PRECEDENCE_1       => true,
         CLK_COR_REPEAT_WAIT_1      => 0,
         CLK_COR_SEQ_1_1_1          => "1101111100",
         CLK_COR_SEQ_1_2_1          => "1000111100",
         CLK_COR_SEQ_1_3_1          => "1000111100",
         CLK_COR_SEQ_1_4_1          => "1000111100",
         CLK_COR_SEQ_1_ENABLE_1     => "1111",
         CLK_COR_SEQ_2_1_1          => "0000000000",
         CLK_COR_SEQ_2_2_1          => "0000000000",
         CLK_COR_SEQ_2_3_1          => "0000000000",
         CLK_COR_SEQ_2_4_1          => "0000000000",
         CLK_COR_SEQ_2_ENABLE_1     => "0000",
         CLK_COR_SEQ_2_USE_1        => false,
         RX_DECODE_SEQ_MATCH_1      => true,

         ------------------------ Channel Bonding Attributes -------------------   

         CHAN_BOND_1_MAX_SKEW_0   => 1,
         CHAN_BOND_2_MAX_SKEW_0   => 1,
         CHAN_BOND_LEVEL_0        => 0,
         CHAN_BOND_MODE_0         => "OFF",
         CHAN_BOND_SEQ_1_1_0      => "0000000000",
         CHAN_BOND_SEQ_1_2_0      => "0000000000",
         CHAN_BOND_SEQ_1_3_0      => "0000000000",
         CHAN_BOND_SEQ_1_4_0      => "0000000000",
         CHAN_BOND_SEQ_1_ENABLE_0 => "0000",
         CHAN_BOND_SEQ_2_1_0      => "0000000000",
         CHAN_BOND_SEQ_2_2_0      => "0000000000",
         CHAN_BOND_SEQ_2_3_0      => "0000000000",
         CHAN_BOND_SEQ_2_4_0      => "0000000000",
         CHAN_BOND_SEQ_2_ENABLE_0 => "0000",
         CHAN_BOND_SEQ_2_USE_0    => false,
         CHAN_BOND_SEQ_LEN_0      => 1,
         PCI_EXPRESS_MODE_0       => false,

         CHAN_BOND_1_MAX_SKEW_1   => 1,
         CHAN_BOND_2_MAX_SKEW_1   => 1,
         CHAN_BOND_LEVEL_1        => 0,
         CHAN_BOND_MODE_1         => "OFF",
         CHAN_BOND_SEQ_1_1_1      => "0000000000",
         CHAN_BOND_SEQ_1_2_1      => "0000000000",
         CHAN_BOND_SEQ_1_3_1      => "0000000000",
         CHAN_BOND_SEQ_1_4_1      => "0000000000",
         CHAN_BOND_SEQ_1_ENABLE_1 => "0000",
         CHAN_BOND_SEQ_2_1_1      => "0000000000",
         CHAN_BOND_SEQ_2_2_1      => "0000000000",
         CHAN_BOND_SEQ_2_3_1      => "0000000000",
         CHAN_BOND_SEQ_2_4_1      => "0000000000",
         CHAN_BOND_SEQ_2_ENABLE_1 => "0000",
         CHAN_BOND_SEQ_2_USE_1    => false,
         CHAN_BOND_SEQ_LEN_1      => 1,
         PCI_EXPRESS_MODE_1       => false,

         ------------------ RX Attributes for PCI Express/SATA ---------------

         RX_STATUS_FMT_0      => "PCIE",
         SATA_BURST_VAL_0     => "100",
         SATA_IDLE_VAL_0      => "100",
         SATA_MAX_BURST_0     => 7,
         SATA_MAX_INIT_0      => 22,
         SATA_MAX_WAKE_0      => 7,
         SATA_MIN_BURST_0     => 4,
         SATA_MIN_INIT_0      => 12,
         SATA_MIN_WAKE_0      => 4,
         TRANS_TIME_FROM_P2_0 => x"0060",
         TRANS_TIME_NON_P2_0  => x"0025",
         TRANS_TIME_TO_P2_0   => x"0100",

         RX_STATUS_FMT_1      => "PCIE",
         SATA_BURST_VAL_1     => "100",
         SATA_IDLE_VAL_1      => "100",
         SATA_MAX_BURST_1     => 7,
         SATA_MAX_INIT_1      => 22,
         SATA_MAX_WAKE_1      => 7,
         SATA_MIN_BURST_1     => 4,
         SATA_MIN_INIT_1      => 12,
         SATA_MIN_WAKE_1      => 4,
         TRANS_TIME_FROM_P2_1 => x"0060",
         TRANS_TIME_NON_P2_1  => x"0025",
         TRANS_TIME_TO_P2_1   => x"0100"

         )
      port map (

         ------------------------ Loopback and Powerdown Ports ----------------------
         LOOPBACK0(0)         => '0',
         LOOPBACK0(1)         => gtpLoopback(0),
         LOOPBACK0(2)         => '0',
         LOOPBACK1(0)         => '0',
         LOOPBACK1(1)         => gtpLoopback(1),
         LOOPBACK1(2)         => '0',
         RXPOWERDOWN0         => (others => '0'),
         RXPOWERDOWN1         => (others => '0'),
         TXPOWERDOWN0         => (others => '0'),
         TXPOWERDOWN1         => (others => '0'),
         ----------------------- Receive Ports - 8b10b Decoder ----------------------
         RXCHARISCOMMA0       => open,
         RXCHARISCOMMA1       => open,
         RXCHARISK0(0)        => gtpRxDataRaw(0)(8),
         RXCHARISK0(1)        => gtpRxDataRaw(0)(18),
         RXCHARISK1(0)        => gtpRxDataRaw(1)(8),
         RXCHARISK1(1)        => gtpRxDataRaw(1)(18),
         RXDEC8B10BUSE0       => '0',
         RXDEC8B10BUSE1       => '0',
         RXDISPERR0(0)        => gtpRxDataRaw(0)(9),
         RXDISPERR0(1)        => gtpRxDataRaw(0)(19),
         RXDISPERR1(0)        => gtpRxDataRaw(1)(9),
         RXDISPERR1(1)        => gtpRxDataRaw(1)(19),
         RXNOTINTABLE0        => open,
         RXNOTINTABLE1        => open,
         RXRUNDISP0           => open,
         RXRUNDISP1           => open,
         ------------------- Receive Ports - Channel Bonding Ports ------------------
         RXCHANBONDSEQ0       => open,
         RXCHANBONDSEQ1       => open,
         RXCHBONDI0           => (others => '0'),
         RXCHBONDI1           => (others => '0'),
         RXCHBONDO0           => open,
         RXCHBONDO1           => open,
         RXENCHANSYNC0        => '0',
         RXENCHANSYNC1        => '0',
         ------------------- Receive Ports - Clock Correction Ports -----------------
         RXCLKCORCNT0         => open,
         RXCLKCORCNT1         => open,
         --------------- Receive Ports - Comma Detection and Alignment --------------
         RXBYTEISALIGNED0     => open,
         RXBYTEISALIGNED1     => open,
         RXBYTEREALIGN0       => open,
         RXBYTEREALIGN1       => open,
         RXCOMMADET0          => open,
         RXCOMMADET1          => open,
         RXCOMMADETUSE0       => '0',
         RXCOMMADETUSE1       => '0',
         RXENMCOMMAALIGN0     => '0',
         RXENMCOMMAALIGN1     => '0',
         RXENPCOMMAALIGN0     => '0',
         RXENPCOMMAALIGN1     => '0',
         RXSLIDE0             => gtpRxSlide(0),
         RXSLIDE1             => gtpRxSlide(1),
         ----------------------- Receive Ports - PRBS Detection ---------------------
         PRBSCNTRESET0        => '0',
         PRBSCNTRESET1        => '0',
         RXENPRBSTST0         => (others => '0'),
         RXENPRBSTST1         => (others => '0'),
         RXPRBSERR0           => open,
         RXPRBSERR1           => open,
         ------------------- Receive Ports - RX Data Path interface -----------------
         RXDATA0(7 downto 0)  => gtpRxDataRaw(0)(7 downto 0),
         RXDATA0(15 downto 8) => gtpRxDataRaw(0)(17 downto 10),
         RXDATA1(7 downto 0)  => gtpRxDataRaw(1)(7 downto 0),
         RXDATA1(15 downto 8) => gtpRxDataRaw(1)(17 downto 10),
         RXDATAWIDTH0         => '1',
         RXDATAWIDTH1         => '1',
         RXRECCLK0            => gtpRxRecClk(0),
         RXRECCLK1            => gtpRxRecClk(1),
         RXRESET0             => gtpRxReset(0),
         RXRESET1             => gtpRxReset(1),
         RXUSRCLK0            => gtpRxUsrClkInt(0),
         RXUSRCLK1            => gtpRxUsrClkInt(1),
         RXUSRCLK20           => gtpRxUsrClk2Int(0),
         RXUSRCLK21           => gtpRxUsrClk2Int(1),
         ------- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
         RXCDRRESET0          => gtpRxCdrResetFinal(0),
         RXCDRRESET1          => gtpRxCdrResetFinal(1),
         RXELECIDLE0          => gtpRxElecIdle(0),
         RXELECIDLE1          => gtpRxElecIdle(1),
         RXELECIDLERESET0     => gtpRxElecIdleRst(0),
         RXELECIDLERESET1     => gtpRxElecIdleRst(1),
         RXENEQB0             => '0',
         RXENEQB1             => '0',
         RXEQMIX0             => (others => '0'),
         RXEQMIX1             => (others => '0'),
         RXEQPOLE0            => (others => '0'),
         RXEQPOLE1            => (others => '0'),
         RXN0                 => gtpRxN(0),
         RXN1                 => gtpRxN(1),
         RXP0                 => gtpRxP(0),
         RXP1                 => gtpRxP(1),
         -------- Receive Ports - RX Elastic Buffer and Phase Alignment Ports -------
         RXBUFRESET0          => '0',
         RXBUFRESET1          => '0',
         RXBUFSTATUS0         => open,
         RXBUFSTATUS1         => open,
         RXCHANISALIGNED0     => open,
         RXCHANISALIGNED1     => open,
         RXCHANREALIGN0       => open,
         RXCHANREALIGN1       => open,
         RXPMASETPHASE0       => '0',
         RXPMASETPHASE1       => '0',
         RXSTATUS0            => open,
         RXSTATUS1            => open,
         --------------- Receive Ports - RX Loss-of-sync State Machine --------------
         RXLOSSOFSYNC0        => open,
         RXLOSSOFSYNC1        => open,
         ---------------------- Receive Ports - RX Oversampling ---------------------
         RXENSAMPLEALIGN0     => '0',
         RXENSAMPLEALIGN1     => '0',
         RXOVERSAMPLEERR0     => open,
         RXOVERSAMPLEERR1     => open,
         -------------- Receive Ports - RX Pipe Control for PCI Express -------------
         PHYSTATUS0           => open,
         PHYSTATUS1           => open,
         RXVALID0             => open,
         RXVALID1             => open,
         ----------------- Receive Ports - RX Polarity Control Ports ----------------
         RXPOLARITY0          => gtpRxPolarity(0),
         RXPOLARITY1          => gtpRxPolarity(1),
         ------------- Shared Ports - Dynamic Reconfiguration Port (DRP) ------------
         DADDR                => (others => '0'),
         DCLK                 => '0',
         DEN                  => '0',
         DI                   => (others => '0'),
         DO                   => open,
         DRDY                 => open,
         DWE                  => '0',
         --------------------- Shared Ports - Tile and PLL Ports --------------------
         CLKIN                => gtpClkIn,
         GTPRESET             => gtpReset,
         GTPTEST              => (others => '0'),
         INTDATAWIDTH         => '1',
         PLLLKDET             => gtpPllLockDetInt,
         PLLLKDETEN           => '1',
         PLLPOWERDOWN         => '0',
         REFCLKOUT            => tmpRefClkOut,
         REFCLKPWRDNB         => '1',
         RESETDONE0           => gtpResetDone(0),
         RESETDONE1           => gtpResetDone(1),
         RXENELECIDLERESETB   => '1',
         TXENPMAPHASEALIGN    => gtpTxEnPmaPhaseAlign,
         TXPMASETPHASE        => gtpTxPmaSetPhase,
         ---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
         TXBYPASS8B10B0       => (others => '0'),
         TXBYPASS8B10B1       => (others => '0'),
         TXCHARDISPMODE0      => (others => '0'),
         TXCHARDISPMODE1      => (others => '0'),
         TXCHARDISPVAL0       => (others => '0'),
         TXCHARDISPVAL1       => (others => '0'),
         TXCHARISK0           => gtpTxDataK(0),
         TXCHARISK1           => gtpTxDataK(1),
         TXENC8B10BUSE0       => '1',
         TXENC8B10BUSE1       => '1',
         TXKERR0              => open,   --txKerr,
         TXKERR1              => open,
         TXRUNDISP0           => open,
         TXRUNDISP1           => open,
         ------------- Transmit Ports - TX Buffering and Phase Alignment ------------
         TXBUFSTATUS0         => open,
         TXBUFSTATUS1         => open,
         ------------------ Transmit Ports - TX Data Path interface -----------------
         TXDATA0              => gtpTxData(0),
         TXDATA1              => gtpTxData(1),
         TXDATAWIDTH0         => '1',
         TXDATAWIDTH1         => '1',
         TXOUTCLK0            => open,
         TXOUTCLK1            => open,
         TXRESET0             => gtpTxReset(0),
         TXRESET1             => gtpTxReset(1),
         TXUSRCLK0            => gtpTxUsrClk,
         TXUSRCLK1            => gtpTxUsrClk,
         TXUSRCLK20           => gtpTxUsrClk2,
         TXUSRCLK21           => gtpTxUsrClk2,
         --------------- Transmit Ports - TX Driver and OOB signalling --------------
         TXBUFDIFFCTRL0       => "100",  -- 800mV
         TXBUFDIFFCTRL1       => "100",
         TXDIFFCTRL0          => "100",
         TXDIFFCTRL1          => "100",
         TXINHIBIT0           => '0',
         TXINHIBIT1           => '0',
         TXN0                 => gtpTxN(0),
         TXN1                 => gtpTxN(1),
         TXP0                 => gtpTxP(0),
         TXP1                 => gtpTxP(1),
         TXPREEMPHASIS0       => "011",  -- 4.5%
         TXPREEMPHASIS1       => "011",
         --------------------- Transmit Ports - TX PRBS Generator -------------------
         TXENPRBSTST0         => (others => '0'),
         TXENPRBSTST1         => (others => '0'),
         -------------------- Transmit Ports - TX Polarity Control ------------------
         TXPOLARITY0          => '0',
         TXPOLARITY1          => '0',
         ----------------- Transmit Ports - TX Ports for PCI Express ----------------
         TXDETECTRX0          => '0',
         TXDETECTRX1          => '0',
         TXELECIDLE0          => '0',
         TXELECIDLE1          => '0',
         --------------------- Transmit Ports - TX Ports for SATA -------------------
         TXCOMSTART0          => '0',
         TXCOMSTART1          => '0',
         TXCOMTYPE0           => '0',
         TXCOMTYPE1           => '0'
         );


end rtl;
