-------------------------------------------------------------------------------
-- Title      : Gtx Low Latency Core
-------------------------------------------------------------------------------
-- File       : Gtx16LowLatCore.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-11-28
-- Last update: 2012-12-10
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2012 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.Pgp2GtxPackage.all;
use work.Pgp2CorePackage.all;
use work.Pgp2CoreTypesPkg.all;
library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity Gtx16LowLatCore is
  generic (
    TPD_G : time := 1 ns;

    -- GTX Parameters
    SIM_PLL_PERDIV2 : bit_vector := X"0C8";  --"011001000";
    CLK25_DIVIDER   : integer    := 5;
    PLL_DIVSEL_FB   : integer    := 2;
    PLL_DIVSEL_REF  : integer    := 1;

    -- Recovered clock parameters
    REC_CLK_PERIOD : real    := 8.000;
    REC_PLL_MULT   : integer := 4;
    REC_PLL_DIV    : integer := 1
    );
  port (

    -- GTX Signals
    gtxClkIn     : in  std_logic;       -- GTX Reference Clock In
    gtxRefClkOut : out std_logic;       -- GTX Reference Clock Output
    gtxRxN       : in  std_logic;       -- GTX Serial Receive Negative
    gtxRxP       : in  std_logic;       -- GTX Serial Receive Positive
    gtxTxN       : out std_logic;       -- GTX Serial Transmit Negative
    gtxTxP       : out std_logic;       -- GTX Serial Transmit Positive

    -- Shared
    gtxReset      : in  std_logic;
    gtxResetDone  : out std_logic;
    gtxPllLockDet : out std_logic;
    gtxLoopback   : in  std_logic;

    -- Rx Resets
    gtxRxReset    : in  std_logic;
    gtxRxCdrReset : in  std_logic;
    gtxRxElecIdle : out std_logic;

    -- Rx Clocks
    gtxRxUsrClk    : out std_logic;     -- 2 byte clock (recovered)
    gtxRxUsrClkRst : out std_logic;     -- Reset for gtxRxUsrClk

    -- Rx Data
    gtxRxData     : out std_logic_vector(15 downto 0);
    gtxRxDataK    : out std_logic_vector(1 downto 0);
    gtxRxDecErr   : out std_logic_vector(1 downto 0);
    gtxRxDispErr  : out std_logic_vector(1 downto 0);
    gtxRxPolarity : in  std_logic;
    gtxRxAligned  : out std_logic;

    -- Tx Resets
    gtxTxReset : in std_logic;

    -- Tx Clocks
    gtxTxUsrClk : in std_logic;

    gtxTxAligned : out std_logic;

    -- Tx Data
    gtxTxData  : in std_logic_vector(15 downto 0);
    gtxTxDataK : in std_logic_vector(1 downto 0)
    );

end Gtx16LowLatCore;

architecture rtl of Gtx16LowLatCore is

  signal gtxPllLockDetInt : std_logic;
  signal tmpRefClkOut     : std_logic;

  --------------------------------------------------------------------------------------------------
  -- Rx Signals
  --------------------------------------------------------------------------------------------------
  -- Clocking
  signal gtxResetDoneInt   : std_logic;
  signal gtxRxRecClk       : std_logic;  -- Raw rxrecclk from GTX, not square, needs DCM or PLL
  signal gtxRxRecClkBufG   : std_logic;
  signal rxRecClkPllOut0   : std_logic;  -- 2 byte clock
  signal rxRecClkPllFbIn   : std_logic;
  signal rxRecClkPllFbOut  : std_logic;
  signal rxRecClkPllLocked : std_logic;
  signal gtxRxUsrClkInt    : std_logic;
  signal gtxRxUsrClkRstInt : std_logic;

  -- Rx Data
  signal gtxRxDataRaw    : std_logic_vector(19 downto 0);
  signal gtxRxDecErrInt  : std_logic_vector(1 downto 0);
  signal gtxRxDispErrInt : std_logic_vector(1 downto 0);

  -- Rx Phase Alignment
  signal gtxRxSlide : std_logic;

  -- Tx Phase Alignment
  signal gtxTxEnPmaPhaseAlign : std_logic;
  signal gtxTxPmaSetPhase     : std_logic;

  -- Inputs to GTX must match expected sizes.
  signal gtxTxDataInt  : std_logic_vector(31 downto 0);
  signal gtxTxDataKInt : std_logic_vector(3 downto 0);

  -- Resets
  signal gtxRxCdrResetFinal : std_logic;
  signal rxCommaAlignReset  : std_logic;

  -- Modelsim needs this crap
  signal rxCharIsKExtra : std_logic_vector(1 downto 0);
  signal rxDispErrExtra : std_logic_vector(1 downto 0);
  signal rxDataExtra    : std_logic_vector(15 downto 0);

begin

  gtxResetDone <= gtxResetDoneInt;

  --------------------------------------------------------------------------------------------------
  -- Rx Data Path
  --------------------------------------------------------------------------------------------------
  RX_REC_CLK_BUFG : BUFG
    port map (
      O => gtxRxRecClkBufG,             -- Feeds pll clkin
      I => gtxRxRecClk);                -- From GTX RXRECCLK

  RX_REC_CLK_PLL : PLL_BASE
    generic map(
      BANDWIDTH          => "OPTIMIZED",
      CLKIN_PERIOD       => REC_CLK_PERIOD,
      CLKOUT0_DIVIDE     => REC_PLL_MULT,
      CLKOUT0_PHASE      => 0.000,
      CLKOUT0_DUTY_CYCLE => 0.500,
      COMPENSATION       => "SYSTEM_SYNCHRONOUS",
      DIVCLK_DIVIDE      => REC_PLL_DIV,
      CLKFBOUT_MULT      => REC_PLL_MULT,
      CLKFBOUT_PHASE     => 0.0,
      REF_JITTER         => 0.005000)
    port map (
      CLKFBIN  => rxRecClkPllFbIn,
      CLKIN    => gtxRxRecClkBufG,
      RST      => '0',
      CLKFBOUT => rxRecClkPllFbOut,
      CLKOUT0  => rxRecClkPllOut0,
      CLKOUT3  => open,
      CLKOUT4  => open,
      CLKOUT5  => open,
      LOCKED   => rxRecClkPllLocked);

  -- Feedback for PLL
  RX_REC_CLK_PLL_FB_BUFG : BUFG
    port map (
      O => rxRecClkPllFbIn,
      I => rxRecClkPllFbOut);

  -- Buffer pll outputs
  RX_USR_CLK_BUFG : BUFG
    port map (
      I => rxRecClkPllOut0,
      O => gtxRxUsrClkInt);

  RX_USR_CLK_RST : entity work.RstSync
    generic map (
      DELAY_G        => TPD_G,
      IN_POLARITY_G  => '0',
      OUT_POLARITY_G => '1')
    port map (
      clk      => gtxRxUsrClkInt,
      asyncRst => gtxResetDoneInt,
      syncRst  => gtxRxUsrClkRstInt);

  -- Output recovered clocks for external use
  gtxRxUsrClk    <= gtxRxUsrClkInt;
  gtxRxUsrClkRst <= gtxRxUsrClkRstInt;


  -- Comma aligner and RxRst modules both drive CDR Reset
  gtxRxCdrResetFinal <= gtxRxCdrReset or rxCommaAlignReset;

  -- Manual comma aligner
  GtxRxCommaAligner_1 : entity work.GtxRxCommaAligner
    generic map (
      TPD_G => TPD_G)
    port map (
      gtxRxUsrClk    => gtxRxUsrClkInt,
      gtxRxUsrClkRst => gtxRxUsrClkRstInt,
      gtxRxData      => gtxRxDataRaw,
      codeErr        => gtxRxDecErrInt,
      dispErr        => gtxRxDispErrInt,
      gtxRxSlide     => gtxRxSlide,
      gtxRxCdrReset  => rxCommaAlignReset,
      aligned        => gtxRxAligned);

  Decoder8b10b_1 : entity work.Decoder8b10b
    generic map (
      TPD_G       => TPD_G,
      NUM_BYTES_G => 2)
    port map (
      clk      => gtxRxUsrClkInt,
      rstN     => rxRecClkPllLocked,
      dataIn   => gtxRxDataRaw,
      dataOut  => gtxRxData,
      dataKOut => gtxRxDataK,
      codeErr  => gtxRxDecErrInt,
      dispErr  => gtxRxDispErrInt);

  -- Assign internal signals to outputs
  gtxRxDecErr  <= gtxRxDecErrInt;
  gtxRxDispErr <= gtxRxDispErrInt;


  --------------------------------------------------------------------------------------------------
  -- Tx Data Path
  --------------------------------------------------------------------------------------------------
  GtxTxPhaseAligner_1 : entity work.GtxTxPhaseAligner
    generic map (
      TPD_G => TPD_G)
    port map (
      gtxTxUsrClk          => gtxTxUsrClk,
      gtxReset             => gtxReset,
      gtxPllLockDetect     => gtxPllLockDetInt,
      gtxTxEnPmaPhaseAlign => gtxTxEnPmaPhaseAlign,
      gtxTxPmaSetPhase     => gtxTxPmaSetPhase,
      gtxTxAligned         => gtxTxAligned);

  REFCLK_BUFG : BUFG
    port map (
      I => tmpRefClkOut,
      O => gtxRefClkOut);

  gtxPllLockDet <= gtxPllLockDetInt;

  --------------------------------------------------------------------------------------------------
  -- GTX Instance
  --------------------------------------------------------------------------------------------------
  gtxTxDataInt  <= X"0000" & gtxTxData;
  gtxTxDataKInt <= "00" & gtxTxDataK;
  ----------------------------- GTX_DUAL Instance  --------------------------   
  UGtxDual : GTX_DUAL
    generic map (

      --_______________________ Simulation-Only Attributes ___________________

      SIM_RECEIVER_DETECT_PASS_0 => true,
      SIM_RECEIVER_DETECT_PASS_1 => true,
      SIM_MODE                   => "FAST",
      SIM_GTXRESET_SPEEDUP       => 0,
      SIM_PLL_PERDIV2            => SIM_PLL_PERDIV2,

      --___________________________ Shared Attributes ________________________

      -------------------------- Tile and PLL Attributes ---------------------

      CLK25_DIVIDER   => CLK25_DIVIDER,
      CLKINDC_B       => true,
      OOB_CLK_DIVIDER => 6,
      OVERSAMPLE_MODE => false,
      PLL_DIVSEL_FB   => PLL_DIVSEL_FB,
      PLL_DIVSEL_REF  => PLL_DIVSEL_REF,
      CLKRCV_TRST     => true,
      PLL_COM_CFG     => x"21680a",
      PLL_CP_CFG      => x"00",
      PLL_FB_DCCEN    => false,
      PLL_LKDET_CFG   => "101",
      PLL_TDCC_CFG    => "000",
      PMA_COM_CFG     => x"000000000000000000",

      --____________________ Transmit Interface Attributes ___________________

      ------------------- TX Buffering and Phase Alignment -------------------   

      TX_BUFFER_USE_0 => false,
      TX_XCLK_SEL_0   => "TXUSR",
      TXRX_INVERT_0   => "111",

      TX_BUFFER_USE_1 => false,
      TX_XCLK_SEL_1   => "TXUSR",
      TXRX_INVERT_1   => "111",

      --------------------- TX Gearbox Settings -----------------------------

      GEARBOX_ENDEC_0 => "000",
      TXGEARBOX_USE_0 => false,

      GEARBOX_ENDEC_1 => "000",
      TXGEARBOX_USE_1 => false,

      --------------------- TX Serial Line Rate settings ---------------------   

      PLL_TXDIVSEL_OUT_0 => 1,
      PLL_TXDIVSEL_OUT_1 => 1,

      --------------------- TX Driver and OOB signalling --------------------  

      CM_TRIM_0          => "10",
      PMA_TX_CFG_0       => x"80082",
      TX_DETECT_RX_CFG_0 => x"1832",
      TX_IDLE_DELAY_0    => "010",
      CM_TRIM_1          => "10",
      PMA_TX_CFG_1       => x"80082",
      TX_DETECT_RX_CFG_1 => x"1832",
      TX_IDLE_DELAY_1    => "010",

      ------------------ TX Pipe Control for PCI Express/SATA ---------------

      COM_BURST_VAL_0 => "1111",
      COM_BURST_VAL_1 => "1111",

      --_______________________ Receive Interface Attributes ________________

      ------------ RX Driver,OOB signalling,Coupling and Eq,CDR -------------  

      AC_CAP_DIS_0          => true,
      OOBDETECT_THRESHOLD_0 => "111",
      PMA_CDR_SCAN_0        => x"640403c",  -- For 2.5 Gbps
      PMA_RX_CFG_0          => x"0f44089",
      RCV_TERM_GND_0        => false,
      RCV_TERM_VTTRX_0      => true,
      TERMINATION_IMP_0     => 50,
      AC_CAP_DIS_1          => true,
      OOBDETECT_THRESHOLD_1 => "111",
      PMA_CDR_SCAN_1        => x"640403c",
      PMA_RX_CFG_1          => x"0f44089",
      RCV_TERM_GND_1        => false,
      RCV_TERM_VTTRX_1      => true,
      TERMINATION_IMP_1     => 50,
      TERMINATION_CTRL      => "10100",
      TERMINATION_OVRD      => false,

      ---------------- RX Decision Feedback Equalizer(DFE)  ----------------  

      DFE_CFG_0    => "1001111011",
      DFE_CFG_1    => "1001111011",
      DFE_CAL_TIME => "00110",

      --------------------- RX Serial Line Rate Attributes ------------------   

      PLL_RXDIVSEL_OUT_0 => 1,
      PLL_SATA_0         => false,
      PLL_RXDIVSEL_OUT_1 => 1,
      PLL_SATA_1         => false,

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
      RX_SLIDE_MODE_1        => "PCS",

      ------------------ RX Loss-of-sync State Machine Attributes -----------  

      RX_LOSS_OF_SYNC_FSM_0 => false,
      RX_LOS_INVALID_INCR_0 => 8,
      RX_LOS_THRESHOLD_0    => 128,
      RX_LOSS_OF_SYNC_FSM_1 => false,
      RX_LOS_INVALID_INCR_1 => 8,
      RX_LOS_THRESHOLD_1    => 128,

      --------------------- RX Gearbox Settings -----------------------------

      RXGEARBOX_USE_0 => false,
      RXGEARBOX_USE_1 => false,

      -------------- RX Elastic Buffer and Phase alignment Attributes -------   

      PMA_RXSYNC_CFG_0 => x"00",
      RX_BUFFER_USE_0  => false,
      RX_XCLK_SEL_0    => "RXUSR",
      PMA_RXSYNC_CFG_1 => x"00",
      RX_BUFFER_USE_1  => false,
      RX_XCLK_SEL_1    => "RXUSR",

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

      CB2_INH_CC_PERIOD_0      => 8,
      CHAN_BOND_KEEP_ALIGN_0   => false,
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

      CB2_INH_CC_PERIOD_1      => 8,
      CHAN_BOND_KEEP_ALIGN_1   => false,
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

      -------- RX Attributes to Control Reset after Electrical Idle  ------

      RX_EN_IDLE_HOLD_DFE_0  => true,
      RX_EN_IDLE_RESET_BUF_0 => true,
      RX_IDLE_HI_CNT_0       => "1000",
      RX_IDLE_LO_CNT_0       => "0000",
      RX_EN_IDLE_HOLD_DFE_1  => true,
      RX_EN_IDLE_RESET_BUF_1 => true,
      RX_IDLE_HI_CNT_1       => "1000",
      RX_IDLE_LO_CNT_1       => "0000",
      CDR_PH_ADJ_TIME        => "01010",
      RX_EN_IDLE_RESET_FR    => true,
      RX_EN_IDLE_HOLD_CDR    => false,
      RX_EN_IDLE_RESET_PH    => true,

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
      TRANS_TIME_FROM_P2_0 => x"003C",
      TRANS_TIME_NON_P2_0  => x"0019",
      TRANS_TIME_TO_P2_0   => x"0064",

      RX_STATUS_FMT_1      => "PCIE",
      SATA_BURST_VAL_1     => "100",
      SATA_IDLE_VAL_1      => "100",
      SATA_MAX_BURST_1     => 7,
      SATA_MAX_INIT_1      => 22,
      SATA_MAX_WAKE_1      => 7,
      SATA_MIN_BURST_1     => 4,
      SATA_MIN_INIT_1      => 12,
      SATA_MIN_WAKE_1      => 4,
      TRANS_TIME_FROM_P2_1 => x"003C",
      TRANS_TIME_NON_P2_1  => x"0019",
      TRANS_TIME_TO_P2_1   => x"0064"

      ) port map (

        ------------------------ Loopback and Powerdown Ports ----------------------
        LOOPBACK0(0)           => '0',
        LOOPBACK0(1)           => gtxLoopback,
        LOOPBACK0(2)           => '0',
        LOOPBACK1              => "000",
        RXPOWERDOWN0           => (others => '0'),
        RXPOWERDOWN1           => (others => '0'),
        TXPOWERDOWN0           => (others => '0'),
        TXPOWERDOWN1           => (others => '0'),
        -------------- Receive Ports - 64b66b and 64b67b Gearbox Ports -------------
        RXDATAVALID0           => open,
        RXDATAVALID1           => open,
        RXGEARBOXSLIP0         => '0',
        RXGEARBOXSLIP1         => '0',
        RXHEADER0              => open,
        RXHEADER1              => open,
        RXHEADERVALID0         => open,
        RXHEADERVALID1         => open,
        RXSTARTOFSEQ0          => open,
        RXSTARTOFSEQ1          => open,
        ----------------------- Receive Ports - 8b10b Decoder ----------------------
        RXCHARISCOMMA0         => open,
        RXCHARISCOMMA1         => open,
        RXCHARISK0(0)          => gtxRxDataRaw(8),
        RXCHARISK0(1)          => gtxRxDataRaw(18),
        RXCHARISK0(3 downto 2) => rxCharIsKExtra,
        RXCHARISK1             => open,
        RXDEC8B10BUSE0         => '0',
        RXDEC8B10BUSE1         => '0',
        RXDISPERR0(0)          => gtxRxDataRaw(9),
        RXDISPERR0(1)          => gtxRxDataRaw(19),
        RXDISPERR0(3 downto 2) => rxDispErrExtra,
        RXDISPERR1             => open,
        RXNOTINTABLE0          => open,    -- phyRxDecErr,
        RXNOTINTABLE1          => open,
        RXRUNDISP0             => open,
        RXRUNDISP1             => open,
        ------------------- Receive Ports - Channel Bonding Ports ------------------
        RXCHANBONDSEQ0         => open,
        RXCHANBONDSEQ1         => open,
        RXCHBONDI0             => (others => '0'),
        RXCHBONDI1             => (others => '0'),
        RXCHBONDO0             => open,
        RXCHBONDO1             => open,
        RXENCHANSYNC0          => '0',
        RXENCHANSYNC1          => '0',
        ------------------- Receive Ports - Clock Correction Ports -----------------
        RXCLKCORCNT0           => open,
        RXCLKCORCNT1           => open,
        --------------- Receive Ports - Comma Detection and Alignment --------------
        RXBYTEISALIGNED0       => open,
        RXBYTEISALIGNED1       => open,
        RXBYTEREALIGN0         => open,
        RXBYTEREALIGN1         => open,
        RXCOMMADET0            => open,
        RXCOMMADET1            => open,
        RXCOMMADETUSE0         => '0',
        RXCOMMADETUSE1         => '0',
        RXENMCOMMAALIGN0       => '0',
        RXENMCOMMAALIGN1       => '0',
        RXENPCOMMAALIGN0       => '0',
        RXENPCOMMAALIGN1       => '0',
        RXSLIDE0               => gtxRxSlide,
        RXSLIDE1               => '0',
        ----------------------- Receive Ports - PRBS Detection ---------------------
        PRBSCNTRESET0          => '0',
        PRBSCNTRESET1          => '0',
        RXENPRBSTST0           => (others => '0'),
        RXENPRBSTST1           => (others => '0'),
        RXPRBSERR0             => open,
        RXPRBSERR1             => open,
        ------------------- Receive Ports - RX Data Path interface -----------------
        RXDATA0(7 downto 0)    => gtxRxDataRaw(7 downto 0),
        RXDATA0(15 downto 8)   => gtxRxDataRaw(17 downto 10),
        RXDATA0(31 downto 16)  => rxDataExtra,
        RXDATA1                => open,
        RXDATAWIDTH0           => "01",
        RXDATAWIDTH1           => "01",
        RXRECCLK0              => gtxRxRecClk,
        RXRECCLK1              => open,
        RXRESET0               => gtxRxReset,
        RXRESET1               => '0',
        RXUSRCLK0              => gtxRxUsrClkInt,
        RXUSRCLK1              => gtxRxUsrClkInt,
        RXUSRCLK20             => gtxRxUsrClkInt,
        RXUSRCLK21             => gtxRxUsrClkInt,
        ------------ Receive Ports - RX Decision Feedback Equalizer(DFE) -----------
        DFECLKDLYADJ0          => (others => '0'),
        DFECLKDLYADJ1          => (others => '0'),
        DFECLKDLYADJMONITOR0   => open,
        DFECLKDLYADJMONITOR1   => open,
        DFEEYEDACMONITOR0      => open,
        DFEEYEDACMONITOR1      => open,
        DFESENSCAL0            => open,
        DFESENSCAL1            => open,
        DFETAP10               => (others => '0'),
        DFETAP11               => (others => '0'),
        DFETAP1MONITOR0        => open,
        DFETAP1MONITOR1        => open,
        DFETAP20               => (others => '0'),
        DFETAP21               => (others => '0'),
        DFETAP2MONITOR0        => open,
        DFETAP2MONITOR1        => open,
        DFETAP30               => (others => '0'),
        DFETAP31               => (others => '0'),
        DFETAP3MONITOR0        => open,
        DFETAP3MONITOR1        => open,
        DFETAP40               => (others => '0'),
        DFETAP41               => (others => '0'),
        DFETAP4MONITOR0        => open,
        DFETAP4MONITOR1        => open,
        ------- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
        RXCDRRESET0            => gtxRxCdrResetFinal,
        RXCDRRESET1            => '0',
        RXELECIDLE0            => gtxRxElecIdle,
        RXELECIDLE1            => open,
        RXENEQB0               => '0',
        RXENEQB1               => '0',
        RXEQMIX0               => (others => '0'),
        RXEQMIX1               => (others => '0'),
        RXEQPOLE0              => (others => '0'),
        RXEQPOLE1              => (others => '0'),
        RXN0                   => gtxRxN,
        RXN1                   => '1',
        RXP0                   => gtxRxP,
        RXP1                   => '0',
        -------- Receive Ports - RX Elastic Buffer and Phase Alignment Ports -------
        RXBUFRESET0            => '0',
        RXBUFRESET1            => '0',
        RXBUFSTATUS0           => open,
        RXBUFSTATUS1           => open,
        RXCHANISALIGNED0       => open,
        RXCHANISALIGNED1       => open,
        RXCHANREALIGN0         => open,
        RXCHANREALIGN1         => open,
        RXENPMAPHASEALIGN0     => '0',
        RXENPMAPHASEALIGN1     => '0',
        RXPMASETPHASE0         => '0',
        RXPMASETPHASE1         => '0',
        RXSTATUS0              => open,
        RXSTATUS1              => open,
        --------------- Receive Ports - RX Loss-of-sync State Machine --------------
        RXLOSSOFSYNC0          => open,
        RXLOSSOFSYNC1          => open,
        ---------------------- Receive Ports - RX Oversampling ---------------------
        RXENSAMPLEALIGN0       => '0',
        RXENSAMPLEALIGN1       => '0',
        RXOVERSAMPLEERR0       => open,
        RXOVERSAMPLEERR1       => open,
        -------------- Receive Ports - RX Pipe Control for PCI Express -------------
        PHYSTATUS0             => open,
        PHYSTATUS1             => open,
        RXVALID0               => open,
        RXVALID1               => open,
        ----------------- Receive Ports - RX Polarity Control Ports ----------------
        RXPOLARITY0            => gtxRxPolarity,
        RXPOLARITY1            => '0',
        ------------- Shared Ports - Dynamic Reconfiguration Port (DRP) ------------
        DADDR                  => (others => '0'),
        DCLK                   => '0',
        DEN                    => '0',
        DI                     => (others => '0'),
        DO                     => open,
        DRDY                   => open,
        DWE                    => '0',
        --------------------- Shared Ports - Tile and PLL Ports --------------------
        CLKIN                  => gtxClkIn,
        GTXRESET               => gtxReset,
        GTXTEST                => "10000000000000",
        INTDATAWIDTH           => '1',
        PLLLKDET               => gtxPllLockDetInt,
        PLLLKDETEN             => '1',
        PLLPOWERDOWN           => '0',
        REFCLKOUT              => tmpRefClkOut,
        REFCLKPWRDNB           => '1',
        RESETDONE0             => gtxResetDoneInt,
        RESETDONE1             => open,
        -------------- Transmit Ports - 64b66b and 64b67b Gearbox Ports ------------
        TXGEARBOXREADY0        => open,
        TXGEARBOXREADY1        => open,
        TXHEADER0              => (others => '0'),
        TXHEADER1              => (others => '0'),
        TXSEQUENCE0            => (others => '0'),
        TXSEQUENCE1            => (others => '0'),
        TXSTARTSEQ0            => '0',
        TXSTARTSEQ1            => '0',
        ---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
        TXBYPASS8B10B0         => (others => '0'),
        TXBYPASS8B10B1         => (others => '0'),
        TXCHARDISPMODE0        => (others => '0'),
        TXCHARDISPMODE1        => (others => '0'),
        TXCHARDISPVAL0         => (others => '0'),
        TXCHARDISPVAL1         => (others => '0'),
        TXCHARISK0             => gtxTxDataKInt,
        TXCHARISK1             => (others => '0'),
        TXENC8B10BUSE0         => '1',
        TXENC8B10BUSE1         => '1',
        TXKERR0                => open,
        TXKERR1                => open,
        TXRUNDISP0             => open,
        TXRUNDISP1             => open,
        ------------- Transmit Ports - TX Buffering and Phase Alignment ------------
        TXBUFSTATUS0           => open,
        TXBUFSTATUS1           => open,
        ------------------ Transmit Ports - TX Data Path interface -----------------
        TXDATA0                => gtxTxDataInt,
        TXDATA1                => (others => '0'),
        TXDATAWIDTH0           => "01",
        TXDATAWIDTH1           => "01",
        TXOUTCLK0              => open,
        TXOUTCLK1              => open,
        TXRESET0               => gtxTxReset,
        TXRESET1               => '0',
        TXUSRCLK0              => gtxTxUsrClk,
        TXUSRCLK1              => gtxTxUsrClk,
        TXUSRCLK20             => gtxTxUsrClk,
        TXUSRCLK21             => gtxTxUsrClk,
        --------------- Transmit Ports - TX Driver and OOB signalling --------------
        TXBUFDIFFCTRL0         => "100",   -- 800mV
        TXBUFDIFFCTRL1         => "100",
        TXDIFFCTRL0            => "100",
        TXDIFFCTRL1            => "100",
        TXINHIBIT0             => '0',
        TXINHIBIT1             => '0',
        TXN0                   => gtxTxN,
        TXN1                   => open,
        TXP0                   => gtxTxP,
        TXP1                   => open,
        TXPREEMPHASIS0         => "0011",  -- 4.5%
        TXPREEMPHASIS1         => "0011",
        -------- Transmit Ports - TX Elastic Buffer and Phase Alignment Ports ------
        TXENPMAPHASEALIGN0     => gtxTxEnPmaPhaseAlign,
        TXENPMAPHASEALIGN1     => '0',
        TXPMASETPHASE0         => gtxTxPmaSetPhase,
        TXPMASETPHASE1         => '0',
        --------------------- Transmit Ports - TX PRBS Generator -------------------
        TXENPRBSTST0           => (others => '0'),
        TXENPRBSTST1           => (others => '0'),
        -------------------- Transmit Ports - TX Polarity Control ------------------
        TXPOLARITY0            => '0',
        TXPOLARITY1            => '0',
        ----------------- Transmit Ports - TX Ports for PCI Express ----------------
        TXDETECTRX0            => '0',
        TXDETECTRX1            => '0',
        TXELECIDLE0            => '0',
        TXELECIDLE1            => '0',
        --------------------- Transmit Ports - TX Ports for SATA -------------------
        TXCOMSTART0            => '0',
        TXCOMSTART1            => '0',
        TXCOMTYPE0             => '0',
        TXCOMTYPE1             => '0'
        );

end rtl;
