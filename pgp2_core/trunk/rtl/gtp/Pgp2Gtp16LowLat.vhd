-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, GTP Wrapper
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2Gtp16.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 08/18/2009
-------------------------------------------------------------------------------
-- Description:
-- VHDL source file containing the PGP, GTP and CRC blocks.
-- This module also contains the logic to control the reset of the GTP.
-------------------------------------------------------------------------------
-- Copyright (c) 2006 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 08/18/2009: created.
-- 01/13/2010: Added received init line to help linking.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.Pgp2GtpPackage.all;
use work.Pgp2CorePackage.all;
use work.Pgp2CoreTypesPkg.all;
library UNISIM;
use UNISIM.VCOMPONENTS.all;


entity Pgp2Gtp16LowLat is
  generic (
    TPD_G        : time    := 1 ns;
    EnShortCells : integer := 1;        -- Enable short non-EOF cells
    VcInterleave : integer := 1         -- Interleave Frames
    );
  port (

    -- System clock, reset & control
    pgpReset   : in std_logic;          -- Synchronous reset input
    pgpTxClk   : in std_logic;          -- 125 MHz Tx clock (PgpTx)
    pgpTxClk2x : in std_logic;          -- 250 MHz Tx clock (GTP)

    pgpRxRecClk    : out std_logic;     -- rxrecclk basically
    pgpRxRecClk2x  : out std_logic;     -- double byte clock
    pgpRxRecClkRst : out std_logic;     -- Reset for recovered clock

    -- Non VC Rx Signals
    pgpRxIn  : in  PgpRxInType;
    pgpRxOut : out PgpRxOutType;

    -- Non VC Tx Signals
    pgpTxIn  : in  PgpTxInType;
    pgpTxOut : out PgpTxOutType;

    -- Frame Transmit Interface - 1 Lane, Array of 4 VCs
    pgpTxVcQuadIn  : in  PgpTxVcQuadInType;
    pgpTxVcQuadOut : out PgpTxVcQuadOutType;

    -- Frame Receive Interface - 1 Lane, Array of 4 VCs
    pgpRxVcCommonOut : out PgpRxVcCommonOutType;
    pgpRxVcQuadOut   : out PgpRxVcQuadOutType;

    -- GTP loopback control
    gtpLoopback : in std_logic;         -- GTP Serial Loopback Control

    -- GTP Signals
    gtpClkIn     : in  std_logic;       -- GTP Reference Clock In
    gtpRefClkOut : out std_logic;       -- GTP Reference Clock Output
    gtpRxN       : in  std_logic;       -- GTP Serial Receive Negative
    gtpRxP       : in  std_logic;       -- GTP Serial Receive Positive
    gtpTxN       : out std_logic;       -- GTP Serial Transmit Negative
    gtpTxP       : out std_logic;       -- GTP Serial Transmit Positive

    -- Debug
    debug : out std_logic_vector(63 downto 0)
    );

end Pgp2Gtp16LowLat;


-- Define architecture
architecture rtl of Pgp2Gtp16LowLat is

  component decode is
    port (
      clk      : in  std_logic;
      rst      : in  std_logic;
      datain   : in  std_logic_vector(9 downto 0);
      dataout  : out std_logic_vector(8 downto 0);
      code_err : out std_logic;
      disp_err : out std_logic);
  end component decode;


  --------------------------------------------------------------------------------------------------
  -- Shared GTP Signals
  --------------------------------------------------------------------------------------------------
  signal tmpRefClkOut  : std_logic;     -- Raw REFCLKOUT from GTP before BUFG
  signal gtpLockDetect : std_logic;     -- GTP PLLLKDET
  signal gtpReset      : std_logic;     -- GTPRESET
  signal gtpRstDone    : std_logic;     -- RESETDONE0


  --------------------------------------------------------------------------------------------------
  -- Rx Signals
  --------------------------------------------------------------------------------------------------
  -- Rx Clocks
  signal gtpRxRecClk       : std_logic;  -- Raw rxrecclk from GTP
  signal gtpRxRecClkBufG   : std_logic;  -- BUFG'd rxrecclk - fed into DCM
  signal rxRecClkPllOut0   : std_logic;  -- 250 MHz clk
  signal rxRecClkPllOut1   : std_logic;  -- 125 MHz clk
  signal rxRecClkPllOut2   : std_logic;  -- 125 MHz clk (180 deg phase shift)
  signal rxRecClkPllFbIn   : std_logic;
  signal rxRecClkPllFbOut  : std_logic;
  signal rxRecClkPllLocked : std_logic;
  signal gtpRxUsrClk       : std_logic;  -- Recovered 1 byte clock
  signal gtpRxUsrClk2      : std_logic;  -- Recovered 2 byte clock
  signal gtpRxUsrClk2Sel   : std_logic;

  -- Rx Resets
  signal gtpRxElecIdle    : std_logic;
  signal gtpRxElecIdleRst : std_logic;
  signal gtpRxReset       : std_logic;
  signal gtpRxCdrReset    : std_logic;

  signal rxCommaAlignReset : std_logic;
--  signal gtpRxCdrReset1   : std_logic;
--  signal gtpRxCdrReset2   : std_logic;
--  signal gtpRxCdrReset3   : std_logic;
--  signal rxResetDone      : std_logic;
--  signal gtpResetBla      : std_logic;

  -- GTP Data
  signal gtpRxData  : std_logic_vector(19 downto 0);  -- Raw rx data from GTP (8b10b encoded)
  signal gtpRxSlide : std_logic;

  -- PgpRx Signals
  signal phyRxLanesIn  : PgpRxPhyLaneInArray(0 to 0);   -- Output from RxByter
  signal phyRxLanesOut : PgpRxPhyLaneOutArray(0 to 0);  -- Polarity to GTP
  signal phyRxReady    : std_logic;                     -- To RxRst
  signal phyRxInit     : std_logic;                     -- To RxRst
  signal crcRxIn       : PgpCrcInType;
  signal crcRxOut      : std_logic_vector(31 downto 0);

  -- CRC Rx IO (PgpRxPhy CRC IO must be adapted to V5 GTP CRCs)
  signal crcRxWidthGtp : std_logic_vector(2 downto 0);
  signal crcRxRstGtp   : std_logic;
  signal crcRxInGtp    : std_logic_vector(31 downto 0);
  signal crcRxOutGtp   : std_logic_vector(31 downto 0);


  --------------------------------------------------------------------------------------------------
  -- Tx Signals
  --------------------------------------------------------------------------------------------------
  -- PgpTx Signals
  signal phyTxLanesOut : PgpTxPhyLaneOutArray(0 to 0);
  signal phyTxReady    : std_logic;
  signal crcTxIn       : PgpCrcInType;
  signal crcTxOut      : std_logic_vector(31 downto 0);

  -- CRC Tx IO (PgpTxPhy CRC IO must be adapted to V5 GTP CRCs)
  signal crcTxWidthGtp : std_logic_vector(2 downto 0);
  signal crcTxRstGtp   : std_logic;
  signal crcTxInGtp    : std_logic_vector(31 downto 0);
  signal crcTxOutGtp   : std_logic_vector(31 downto 0);

  -- Tx Phase Alignment
  signal gtpTxEnPmaPhaseAlign : std_logic;
  signal gtpTxPmaSetPhase     : std_logic;

  -- Reset signals
  signal gtpTxReset : std_logic;

  signal gtpRxInit : std_logic;
begin

  --------------------------------------------------------------------------------------------------
  -- Misc
  --------------------------------------------------------------------------------------------------
  -- Link Ready
--  pgpLocLinkReady <= pgpRxLinkReady and pgpTxLinkReady;

  --------------------------------------------------------------------------------------------------
  -- Rx Data Path
  --------------------------------------------------------------------------------------------------

  -- RX Reset Control
  -- Uses pgpTxClk! Needs free-running clock to work
  -- All outputs used asynchronously so this is ok
  U_Pgp2GtpRxRst : Pgp2GtpRxRst
    port map (
      gtpRxClk         => pgpTxClk,     -- Need free-running clock here so use TxClk
      gtpRxRst         => pgpReset,
      gtpRxReady       => open,         -- rxResetDone,
      gtpRxInit        => '0',
      gtpLockDetect    => gtpLockDetect,
      gtpRxElecIdle    => gtpRxElecIdle,
      gtpRxBuffStatus  => "000",
      gtpRstDone       => gtpRstDone,
      gtpRxElecIdleRst => gtpRxElecIdleRst,
      gtpRxReset       => gtpRxReset,
      gtpRxCdrReset    => gtpRxCdrReset
      );

  -- Recovered clock buffering and DCM
--  RxRecClkBufR : BUFR
--    port map (
--      O   => gtpRxUsrClk,               -- Goes straight to GTP RXUSRCLK
--      CE  => '1',                       -- Clock enable input
--      CLR => '0',                       -- Clock buffer reset input
--      I   => gtpRxRecClk);              -- From GTP RXRECCLK

  RX_REC_CLK_BUFG : BUFG
    port map (
      O => gtpRxRecClkBufG,             -- Feeds pll clkin
      I => gtpRxRecClk);                -- From GTP RXRECCLK

  RX_REC_CLK_PLL : PLL_BASE
    generic map(
      BANDWIDTH          => "OPTIMIZED",
      CLKIN_PERIOD       => 4.000,
      CLKOUT0_DIVIDE     => 4,
      CLKOUT1_DIVIDE     => 8,
      CLKOUT2_DIVIDE     => 8,
      CLKOUT0_PHASE      => 0.000,
      CLKOUT1_PHASE      => 0.000,
      CLKOUT2_PHASE      => 180.000,
      CLKOUT0_DUTY_CYCLE => 0.500,
      CLKOUT1_DUTY_CYCLE => 0.500,
      CLKOUT2_DUTY_CYCLE => 0.500,
      COMPENSATION       => "SYSTEM_SYNCHRONOUS",
      DIVCLK_DIVIDE      => 1,
      CLKFBOUT_MULT      => 4,
      CLKFBOUT_PHASE     => 0.0,
      REF_JITTER         => 0.005000)
    port map (
      CLKFBIN  => rxRecClkPllFbIn,
      CLKIN    => gtpRxRecClkBufG,
      RST      => '0',
      CLKFBOUT => rxRecClkPllFbOut,
      CLKOUT0  => rxRecClkPllOut0,
      CLKOUT1  => rxRecClkPllOut1,
      CLKOUT2  => rxRecClkPllOut2,
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
      O => gtpRxUsrClk);

  RX_USR_CLK2_BUFMUX : BUFGMUX_CTRL
    port map (
      I1 => rxRecClkPllOut1,
      I0 => rxRecClkPllOut2,
      S  => gtpRxUsrClk2Sel,
      O  => gtpRxUsrClk2);

  -- Output recovered clocks for external use
  pgpRxRecClk    <= gtpRxUsrClk2;
  pgpRxRecClk2x  <= gtpRxUsrClk;
  pgpRxRecClkRst <= not rxRecClkPllLocked;  -- EHH?

  gtpReset <= rxCommaAlignReset or pgpReset;


  -- Manual comma aligner
  GtpRxCommaAligner_1 : entity work.GtpRxCommaAligner
    generic map (
      TPD_G => TPD_G)
    port map (
      gtpRxUsrClk2     => gtpRxUsrClk2,
      gtpRxUsrClk2RstL => rxRecClkPllLocked,
      gtpRxData        => gtpRxData,
      codeErr          => phyRxLanesIn(0).decErr,
      dispErr          => phyRxLanesIn(0).dispErr,
      gtpRxUsrClk2Sel  => gtpRxUsrClk2Sel,
      gtpRxSlide       => gtpRxSlide,
      gtpRxCdrReset    => rxCommaAlignReset,
      aligned          => phyRxReady);

  Decoder8b10b_1 : entity work.Decoder8b10b
    generic map (
      TPD_G       => TPD_G,
      NUM_BYTES_G => 2)
    port map (
      clk      => gtpRxUsrClk2,
      rstN     => rxRecClkPllLocked,
      dataIn   => gtpRxData,
      dataOut  => phyRxLanesIn(0).data,
      dataKOut => phyRxLanesIn(0).dataK,
      codeErr  => phyRxLanesIn(0).decErr,
      dispErr  => phyRxLanesIn(0).dispErr);


  -- PGP RX Block
  Pgp2RxWrapper_1 : entity work.Pgp2RxWrapper
    generic map (
      RxLaneCnt    => 1,
      EnShortCells => EnShortCells)
    port map (
      pgpRxClk         => gtpRxUsrClk2,
      pgpRxReset       => pgpReset,
      pgpRxIn          => pgpRxIn,
      pgpRxOut         => pgpRxOut,
      pgpRxVcCommonOut => pgpRxVcCommonOut,
      pgpRxVcQuadOut   => pgpRxVcQuadOut,
      phyRxLanesOut    => phyRxLanesOut,
      phyRxLanesIn     => phyRxLanesIn,
      phyRxReady       => phyRxReady,
      phyRxInit        => phyRxInit,
      crcRxIn          => crcRxIn,
      crcRxOut         => crcRxOut,
      debug            => open);

  -- RX CRC BLock
  -- Must adapt generic CRC type to GTP CRC block
  crcRxWidthGtp            <= "001";
  crcRxRstGtp              <= pgpReset or crcRxIn.init or not rxRecClkPllLocked;
  crcRxInGtp(31 downto 24) <= crcRxIn.crcIn(7 downto 0);
  crcRxInGtp(23 downto 16) <= crcRxIn.crcIn(15 downto 8);
  crcRxInGtp(15 downto 0)  <= (others => '0');
  crcRxOut                 <= not crcRxOutGtp;  -- Invert Output CRC

  Rx_CRC : CRC32
    generic map(
      CRC_INIT => x"FFFFFFFF"
      ) port map(
        CRCOUT       => crcRxOutGtp,
        CRCCLK       => gtpRxUsrClk2,
        CRCDATAVALID => crcRxIn.valid,
        CRCDATAWIDTH => crcRxWidthGtp,
        CRCIN        => crcRxInGtp,
        CRCRESET     => crcRxRstGtp
        );


  --------------------------------------------------------------------------------------------------
  -- Tx Data Path
  --------------------------------------------------------------------------------------------------

  Pgp2TxWrapper_1 : entity work.Pgp2TxWrapper
    generic map (
      TxLaneCnt    => 1,
      VcInterleave => VcInterleave)
    port map (
      pgpTxClk       => pgpTxClk,
      pgpTxReset     => pgpReset,
      pgpTxIn        => pgpTxIn,
      pgpTxOut       => pgpTxOut,
      pgpTxVcQuadIn  => pgpTxVcQuadIn,
      pgpTxVcQuadOut => pgpTxVcQuadOut,
      phyTxLanesOut  => phyTxLanesOut,
      phyTxReady     => phyTxReady,
      crcTxIn        => crcTxIn,
      crcTxOut       => crcTxOut,
      debug          => open);


  -- Adapt CRC data width flag
  crcTxWidthGtp            <= "001";
  crcTxRstGtp              <= pgpReset or crcTxIn.init;
  -- Pass CRC data in on proper bits
  crcTxInGtp(31 downto 24) <= crcTxIn.crcIn(7 downto 0);
  crcTxInGtp(23 downto 16) <= crcTxIn.crcIn(15 downto 8);
  crcTxInGtp(15 downto 0)  <= (others => '0');
  crcTxOut                 <= not crcTxOutGtp;


  -- TX CRC BLock
  Tx_CRC : CRC32
    generic map(
      CRC_INIT => x"FFFFFFFF"
      )
    port map(
      CRCOUT       => crcTxOutGtp,
      CRCCLK       => pgpTxClk,
      CRCDATAVALID => crcTxIn.valid,
      CRCDATAWIDTH => crcTxWidthGtp,
      CRCIN        => crcTxInGtp,
      CRCRESET     => crcTxRstGtp
      );

  -- TX Reset Control
  U_Pgp2GtpTxRst : Pgp2GtpTxRst
    port map (
      gtpTxClk        => pgpTxClk,
      gtpTxRst        => pgpReset,
      gtpTxReady      => phyTxReady,
      gtpLockDetect   => gtpLockDetect,
      gtpTxBuffStatus => "00",
      gtpRstDone      => gtpRstDone,
      gtpTxReset      => gtpTxReset
      );

  GtpTxPhaseAligner_1 : entity work.GtpTxPhaseAligner
    generic map (
      TPD_G => TPD_G)
    port map (
      pgpTxClk             => pgpTxClk,
      gtpReset             => pgpReset,
      gtpPllLockDetect     => gtpLockDetect,
      gtpTxClkLocked       => '1',
      gtpTxEnPmaPhaseAlign => gtpTxEnPmaPhaseAlign,
      gtpTxPmaSetPhase     => gtpTxPmaSetPhase);

  --------------------------------------------------------------------------------------------------
  -- GTP Instance
  --------------------------------------------------------------------------------------------------


  ----------------------------- GTP_DUAL Instance  --------------------------   
  UGtpDual : GTP_DUAL
    generic map (

      --_______________________ Simulation-Only Attributes ___________________

      SIM_GTPRESET_SPEEDUP => 0,
      SIM_PLL_PERDIV2      => x"0C8",

      --___________________________ Shared Attributes ________________________

      -------------------------- Tile and PLL Attributes ---------------------

      CLK25_DIVIDER         => 5,       -- For 125 MHz clkin
      CLKINDC_B             => true,
      OOB_CLK_DIVIDER       => 6,
      OVERSAMPLE_MODE       => false,
      PLL_DIVSEL_FB         => 2,
      PLL_DIVSEL_REF        => 1,       -- creates pll clock = 2.5 GHz w/ 125 Mhz clkin
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

      PLL_TXDIVSEL_OUT_0 => 1,          -- Must be 1 when TX_BUFFER_USE = false

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
      LOOPBACK0(1)         => gtpLoopback,
      LOOPBACK0(2)         => '0',
      LOOPBACK1            => "000",
      RXPOWERDOWN0         => (others => '0'),
      RXPOWERDOWN1         => (others => '0'),
      TXPOWERDOWN0         => (others => '0'),
      TXPOWERDOWN1         => (others => '0'),
      ----------------------- Receive Ports - 8b10b Decoder ----------------------
      RXCHARISCOMMA0       => open,
      RXCHARISCOMMA1       => open,
      RXCHARISK0(0)        => gtpRxData(8),
      RXCHARISK0(1)        => gtpRxData(18),
      RXCHARISK1           => open,
      RXDEC8B10BUSE0       => '0',
      RXDEC8B10BUSE1       => '0',
      RXDISPERR0(0)        => gtpRxData(9),
      RXDISPERR0(1)        => gtpRxData(19),
      RXDISPERR1           => open,
      RXNOTINTABLE0        => open,                       -- phyRxDecErr,
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
      RXSLIDE0             => gtpRxSlide,
      RXSLIDE1             => '0',
      ----------------------- Receive Ports - PRBS Detection ---------------------
      PRBSCNTRESET0        => '0',
      PRBSCNTRESET1        => '0',
      RXENPRBSTST0         => (others => '0'),
      RXENPRBSTST1         => (others => '0'),
      RXPRBSERR0           => open,
      RXPRBSERR1           => open,
      ------------------- Receive Ports - RX Data Path interface -----------------
      RXDATA0(7 downto 0)  => gtpRxData(7 downto 0),
      RXDATA0(15 downto 8) => gtpRxData(17 downto 10),
      RXDATA1              => open,
      RXDATAWIDTH0         => '1',
      RXDATAWIDTH1         => '1',
      RXRECCLK0            => gtpRxRecClk,
      RXRECCLK1            => open,
      RXRESET0             => gtpRxReset,
      RXRESET1             => '0',
      RXUSRCLK0            => gtpRxUsrClk,
      RXUSRCLK1            => gtpRxUsrClk,
      RXUSRCLK20           => gtpRxUsrClk2,
      RXUSRCLK21           => gtpRxUsrClk2,
      ------- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
      RXCDRRESET0          => gtpRxCdrReset,
      RXCDRRESET1          => '0',
      RXELECIDLE0          => gtpRxElecIdle,
      RXELECIDLE1          => open,
      RXELECIDLERESET0     => gtpRxElecIdleRst,
      RXELECIDLERESET1     => '0',
      RXENEQB0             => '0',
      RXENEQB1             => '0',
      RXEQMIX0             => (others => '0'),
      RXEQMIX1             => (others => '0'),
      RXEQPOLE0            => (others => '0'),
      RXEQPOLE1            => (others => '0'),
      RXN0                 => gtpRxN,
      RXN1                 => '1',
      RXP0                 => gtpRxP,
      RXP1                 => '0',
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
      RXPOLARITY0          => phyRxLanesOut(0).polarity,  --  phyRxPolarity(0),
      RXPOLARITY1          => '0',
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
      PLLLKDET             => gtpLockDetect,
      PLLLKDETEN           => '1',
      PLLPOWERDOWN         => '0',
      REFCLKOUT            => tmpRefClkOut,
      REFCLKPWRDNB         => '1',
      RESETDONE0           => gtpRstDone,
      RESETDONE1           => open,
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
      TXCHARISK0           => phyTxLanesOut(0).dataK,     -- gtpTxDataK,       
      TXCHARISK1           => "00",
      TXENC8B10BUSE0       => '1',
      TXENC8B10BUSE1       => '1',
      TXKERR0              => open,                       --txKerr,
      TXKERR1              => open,
      TXRUNDISP0           => open,
      TXRUNDISP1           => open,
      ------------- Transmit Ports - TX Buffering and Phase Alignment ------------
      TXBUFSTATUS0         => open,                       --phyTxBuffStatus,
      TXBUFSTATUS1         => open,
      ------------------ Transmit Ports - TX Data Path interface -----------------
      TXDATA0              => phyTxLanesOut(0).data,      -- gtpTxData, ,
      TXDATA1              => (others => '0'),
      TXDATAWIDTH0         => '1',
      TXDATAWIDTH1         => '1',
      TXOUTCLK0            => open,
      TXOUTCLK1            => open,
      TXRESET0             => gtpTxReset,
      TXRESET1             => '0',
      TXUSRCLK0            => pgpTxClk2x,
      TXUSRCLK1            => pgpTxClk2x,
      TXUSRCLK20           => pgpTxClk,
      TXUSRCLK21           => pgpTxClk,
      --------------- Transmit Ports - TX Driver and OOB signalling --------------
      TXBUFDIFFCTRL0       => "100",                      -- 800mV
      TXBUFDIFFCTRL1       => "100",
      TXDIFFCTRL0          => "100",
      TXDIFFCTRL1          => "100",
      TXINHIBIT0           => '0',
      TXINHIBIT1           => '0',
      TXN0                 => gtpTxN,
      TXN1                 => open,
      TXP0                 => gtpTxP,
      TXP1                 => open,
      TXPREEMPHASIS0       => "011",                      -- 4.5%
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

  REFCLK_BUFG : BUFG
    port map (
      I => tmpRefClkOut,
      O => gtpRefClkOut);


end rtl;

