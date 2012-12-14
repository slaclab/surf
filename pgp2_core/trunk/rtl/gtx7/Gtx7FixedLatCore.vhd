-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Gtx7FixedLatCore.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-12-12
-- Last update: 2012-12-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2012 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity Gtx7FixedLatCore is
  
  generic (
    TPD_G : time := 1 ns;

    -- Simulation attributes --
    SIM_GTRESET_SPEEDUP_G : string := "false";
    SIM_VERSION_G         : string := "4.0";

    -- CPLL Config --
    CPLLREFCLKSEL_G      : bit_vector            := "001";
    CPLL_FBDIV_G         : integer               := 4;
    CPLL_FBDIV_45_G      : integer               := 5;
    CPLL_REFCLK_DIV_G    : integer               := 1;
    RXOUT_DIV_G          : integer               := 2;
    TXOUT_DIV_G          : integer               := 2;

    -- QPLL Config
    TX_PLL_G : string := "QPLL";
    RX_PLL_G : string := "CPLL";
    TX_REFCLK_PERIOD_G : integer range 4 to 20 := 8;
    RX_REFCLK_PERIOD_G : integer range 4 to 20 := 8;
    );

  port (
    -- QPLL IO -- QPLL drives TX Side
    qPllClk    : in  sl;                -- Bit clock from QPLL
    qPllRefClk : in  sl;                -- QPLL Reference clock
    qPllLock   : in  sl;                -- QPLL has locked
    qPllReset  : out sl;                -- Reset the QPLL

    -- CPLL Reference Clock -- Drives Rx Side
    -- Fed to proper CPLL input clock via CPLLREFCLKSEL_G setting --
    cPllRefClk : in sl;

    -- Serial IO
    gtRxP : in  sl;
    gtRxN : in  sl;
    gtTxP : out sl;
    gtRxN : out sl;

    -- Rx Clocks/Resets
    gtRxUsrClk    : out sl;             -- Recovered clock from data stream
    gtRxUsrClkRst : out sl;             -- Asserted when gtRxUsrClk drops out
    gtRxUserReset : in  sl;             -- Allows external logic to reset the RX

    -- Rx Data
    gtRxData     : out slv(15 downto 0);
    gtRxCharIsK  : out slv(1 downto 0);
    gtRxDecErr   : out slv(1 downto 0);
    gtRxDispErr  : out slv(1 downto 0);
    gtRxPolarity : in  sl;

    -- Tx Clock/Resets
    gtTxOutClk    : out sl;             -- qpllRefClk, basically
    gtTxUsrClk    : in  sl;             -- feedback from gtTxOutClk through BUFG/BUFR/BUFH/MMCM
    gtTxUsrClkRst : out sl;             -- Not sure if this is needed
    gtTxUserReset : in  sl;             -- Allows external logic to reset TX

    -- Tx Data
    gtTxCharIsK : in slv(1 downto 0);
    gtTxData    : in slv(15 downto 0);

    -- Activates loopback in GT
    gtLoopback : in slv(2 downto 0);
    );

end entity Gtx7FixedLatCore;

architecture rtl of Gtx7FixedLatCore is


  -- Gtx CPLL Input Clocks
  signal gtGRefClk      : sl;
  signal gtNorthRefClk0 : sl;
  signal gtNorthRefClk1 : sl;
  signal gtRefClk0      : sl;
  signal gtRefClk1      : sl;
  signal gtSouthRefClk0 : sl;
  signal gtSouthRefClk1 : sl;

  -- CPll Reset
  signal cPllLock  : sl;
  signal cPllReset : sl;

  ----------------------------
  -- Rx Reset Signals
  signal gtRxReset        : sl;
  signal gtRxResetDone    : sl;
  signal gtRxUserRdy      : sl;
  signal rxFsmResetDone : sl;

  -- Rx Clocks
  signal gtRxOutClkInt : sl;
  signal gtRxUsrClkInt : sl;

  -- Rx Phase Align
  signal gtRxSlide : sl;
  signal rxAligned : sl;

  -- Rx Data
  signal gtRxDataFull    : slv(63 downto 0);
  signal gtRxCharIsKFull : slv(7 downto 0);
  signal gtRxDispErrFull : slv(7 downto 0);
  signal gtRxDataRaw     : slv(19 downto 0);  -- Built using selected *Full signals tied to gtx

  signal gtRxDecErrInt  : slv(1 downto 0);
  signal gtRxDispErrInt : slv(1 downto 0);

  ----------------------------
  -- Tx Reset Signals
  signal gtTxReset     : sl;
  signal gtTxResetDone : sl;
  signal gtTxUserRdy   : sl;

  -- Tx clocks (internal)
  signal gtTxOutClkInt : sl;

  -- Tx Data Signals
  signal gtTxDataInt    : slv(63 downto 0);
  signal gtTxCharIsKInt : slv(7 downto 0);

begin

  --------------------------------------------------------------------------------------------------
  -- CPLL clock select. Only ever use 1 clock to drive cpll.
  --------------------------------------------------------------------------------------------------
  gtRefClk0      <= cPllRefClk when CPLLREFCLKSEL_G = "001" else '0';
  gtRefClk1      <= cPllRefClk when CPLLREFCLKSEL_G = "010" else '0';
  gtNorthRefClk0 <= cPllRefClk when CPLLREFCLKSEL_G = "011" else '0';
  gtNorthRefClk1 <= cPllRefClk when CPLLREFCLKSEL_G = "100" else '0';
  gtSouthRefClk0 <= cPllRefClk when CPLLREFCLKSEL_G = "101" else '0';
  gtSouthRefClk1 <= cPllRefClk when CPLLREFCLKSEL_G = "110" else '0';
  gtGRefClk      <= cPllRefClk when CPLLREFCLKSEL_G = "111" else '0';




  --------------------------------------------------------------------------------------------------
  -- Rx Logic
  --------------------------------------------------------------------------------------------------
  -- Fit GTX port sizes to 16 bit interface
  gtRxDataRaw(7 downto 0)   <= gtRxDataFull(7 downto 0);
  gtRxDataRaw(8)            <= gtRxCharIsKFull(0);
  gtRxDataRaw(9)            <= gtRxDispErrFull(0);
  gtRxDataRaw(17 downto 10) <= gtRxDataFull(15 downto 8);
  gtRxDataRaw(18)           <= gtRxCharIsKFull(1);
  gtRxDataRaw(19)           <= gtRxDispErrFull(1);



  --------------------------------------------------------------------------------------------------
  -- Run RXOUTCLK (recoved clock) through an MMCM to reduce jitter
  --------------------------------------------------------------------------------------------------
  Gtx7RxUsrClkMmcm_1 : entity work.Gtx7RxUsrClkMmcm
    port map (
      CLK_IN1  => gtRxOutClk,
      CLK_OUT1 => gtRxUsrClkInt,
      RESET    => mmcmReset,
      LOCKED   => mmcmLocked);

  --------------------------------------------------------------------------------------------------
  -- Rx 8B10B Decoder
  --------------------------------------------------------------------------------------------------
  Decoder8b10b_1 : entity work.Decoder8b10b
    generic map (
      TPD_G       => TPD_G,
      NUM_BYTES_G => 2)
    port map (
      clk      => gtRxUsrClkInt,
      rstN     => gtRxUsrRdy,           -- Needs to be synchronized to usrClk
      dataIn   => gtRxDataRaw
      dataOut  => gtRxData,
      dataKOut => gtRxCharIsK,
      codeErr  => gtRxDecErrInt,
      dispErr  => gtRxDispErrInt);

  --------------------------------------------------------------------------------------------------
  -- Rx Comma Aligner
  --------------------------------------------------------------------------------------------------
  Gtx7RxCommaAligner_1 : entity work.Gtx7RxCommaAligner
    generic map (
      TPD_G        => TPD_G,
      COMMA_G      => "0101111100",
      SLIDE_WAIT_G => 32)
    port map (
      gtRxUsrClk     => gtRxUsrClkInt,
      gtRxUsrClkRstN => gtRxUsrRdy,     -- Needs to be synchronized to usrClk
      gtRxData       => gtRxData,
      codeErr        => gtRxDecErrInt
      dispErr        => gtRxDispErrInt,
      gtRxSlide      => gtRxSlide,
      gtRxReset      => alignReset,
      aligned        => rxAligned);

  --------------------------------------------------------------------------------------------------
  -- Rx Reset Module
  -- 1. Reset CPLL,
  -- 2. Wait CPLL Lock
  -- 3. Wait recclk_stable
  -- 4. Reset MMCM
  -- 5. Wait MMCM Lock
  -- 6. Assert gtRxUserRdy (gtRxUsrClk now usable)
  -- 7. Wait gtRxResetDone
  -- 8. Skip phase alignment
  -- 9. Wait DATA_VALID (aligned) - 100 us
  --10. Wait 1 us, Set rxFsmResetDone. 
  --------------------------------------------------------------------------------------------------
  gtRxUserResetInt <= gtRxUserReset or alignReset;
  Gtx7RxRst_1 : entity work.Gtx7RxRst
    generic map (
      EXAMPLE_SIMULATION     => 0,
      GT_TYPE                => "GTX",
      EQ_MODE                => "DFE",
      STABLE_CLOCK_PERIOD    => RX_REFCLK_PERIOD_G,
      RETRY_COUNTER_BITWIDTH => 8,
      TX_QPLL_USED           => (TX_PLL_G = "QPLL"),  -- true,
      RX_QPLL_USED           => (RX_PLL_G = "QPLL"), -- false,
      PHASE_ALIGNMENT_MANUAL => false)
    port map (
      STABLE_CLOCK           => cPllRefClk,
      RXUSERCLK              => gtRxUsrClkInt,
      SOFT_RESET             => gtRxUserReset,
      QPLLREFCLKLOST         => '0',
      CPLLREFCLKLOST         => '0',
      QPLLLOCK               => qPllLock,
      CPLLLOCK               => cPllLock,
      RXRESETDONE            => gtRxResetDone,
      MMCM_LOCK              => mmcmLocked,
      RECCLK_STABLE          => '1',    -- Asserted after 50,000 UI as per DS183
      RECCLK_MONITOR_RESTART => '0',
      DATA_VALID             => rxAligned,
      TXUSERRDY              => '1',    -- Don't care in this configuration
      GTRXRESET              => gtRxReset,
      MMCM_RESET             => mmcmReset,
      QPLL_RESET             => qPllReset,
      CPLL_RESET             => cPllReset,
      RX_FSM_RESET_DONE      => rxFsmResetDone,
      RXUSERRDY              => gtRxUserRdy,
      RUN_PHALIGNMENT        => open,
      PHALIGNMENT_DONE       => '1',    -- Not doing phase alignment
      RESET_PHALIGNMENT      => open,
      RXDFEAGCHOLD           => open,
      RXDFELFHOLD            => open,
      RXLPMLFHOLD            => open,
      RXLPMHFHOLD            => open,
      RETRY_COUNTER          => open);

  --------------------------------------------------------------------------------------------------
  -- Synchronize rxFsmResetDone to rxUsrClk to use as reset for external logic.
  --------------------------------------------------------------------------------------------------
  RstSync_1: entity work.RstSync
    generic map (
      DELAY_G        => TPD_G,
      IN_POLARITY_G  => '0',
      OUT_POLARITY_G => '1'
      HOLD_CYCLES_G  => 1)
    port map (
      clk      => gtRxUsrClkInt,
      asyncRst => rxFsmResetDone,
      syncRst  => gtRxUsrClkRst);       -- Output

  --------------------------------------------------------------------------------------------------
  -- Tx Logic
  --------------------------------------------------------------------------------------------------
  -- Internal signals that are output
  gtTxOutClk <= gtTxOutClkInt;

  -- Fit GTX port sizes to 16 bit interface
  gtTxDataInt(15 downto 0)   <= gtTxData;
  gtTxCharIsKInt(1 downto 0) <= gtTxCharIsK;

  --------------------------------------------------------------------------------------------------
  -- Tx Reset Module
  --------------------------------------------------------------------------------------------------
  Gtx7TxRst_1 : entity work.Gtx7TxRst
    generic map (
      GT_TYPE                => "GTX",
      STABLE_CLOCK_PERIOD    => TX_REFCLK_PERIOD_G,
      RETRY_COUNTER_BITWIDTH => 8,
      TX_QPLL_USED           => (TX_PLL_G = "QPLL"),  -- true,
      RX_QPLL_USED           => (RX_PLL_G = "QPLL"), -- false,
      PHASE_ALIGNMENT_MANUAL => false)
    port map (
      STABLE_CLOCK      => gtTxOutClkInt,     -- cpllrefclk
      TXUSERCLK         => gtTxUsrClk,
      SOFT_RESET        => gtTxUserReset,
      QPLLREFCLKLOST    => '0',               -- Don't worry about this happening
      CPLLREFCLKLOST    => '0',
      QPLLLOCK          => qPllLock,
      CPLLLOCK          => cPllLock,              -- Tx driven from QPLL
      TXRESETDONE       => gtTxResetDone,
      MMCM_LOCK         => open,              -- Not using an MMCM in TX clk path
      GTTXRESET         => gtTxReset,
      MMCM_RESET        => open,
      QPLL_RESET        => qPllReset,
      CPLL_RESET        => cPllReset,
      TX_FSM_RESET_DONE => gtTxFsmResetDone,  -- Use as reset for txUsrClk logic?
      TXUSERRDY         => gtTxUserRdy,
      RUN_PHALIGNMENT   => open,
      RESET_PHALIGNMENT => open,
      PHALIGNMENT_DONE  => '1',
      RETRY_COUNTER     => open);             -- Might be interesting to look at

  --------------------------------------------------------------------------------------------------
  -- GTX Instantiation
  --------------------------------------------------------------------------------------------------
  gtxe2_i : GTXE2_CHANNEL
    generic map
    (

      --_______________________ Simulation-Only Attributes ___________________

      SIM_RECEIVER_DETECT_PASS => ("TRUE"),
      SIM_RESET_SPEEDUP        => (SIM_GTRESET_SPEEDUP_G),
      SIM_TX_EIDLE_DRIVE_LEVEL => ("X"),
      SIM_CPLLREFCLK_SEL       => (CPLLREFCLKSEL_G),  --("001"),  -- GTPREFCLK0
      SIM_VERSION              => (SIM_VERSION_G),


      ------------------RX Byte and Word Alignment Attributes---------------
      ALIGN_COMMA_DOUBLE => ("FALSE"),
      ALIGN_COMMA_ENABLE => ("1111111111"),
      ALIGN_COMMA_WORD   => (2),
      ALIGN_MCOMMA_DET   => ("FALSE"),
      ALIGN_MCOMMA_VALUE => ("1010000011"),
      ALIGN_PCOMMA_DET   => ("FALSE"),
      ALIGN_PCOMMA_VALUE => ("0101111100"),
      SHOW_REALIGN_COMMA => ("FALSE"),
      RXSLIDE_AUTO_WAIT  => (7),
      RXSLIDE_MODE       => ("PMA"),    -- Low Lat
      RX_SIG_VALID_DLY   => (10),

      ------------------RX 8B/10B Decoder Attributes---------------
      -- These don't really matter since RX 8B10B is disabled
      RX_DISPERR_SEQ_MATCH => ("TRUE"),
      DEC_MCOMMA_DETECT    => ("TRUE"),
      DEC_PCOMMA_DETECT    => ("TRUE"),
      DEC_VALID_COMMA_ONLY => ("FALSE"),

      ------------------------RX Clock Correction Attributes----------------------
      CBCC_DATA_SOURCE_SEL => ("DECODED"),
      CLK_COR_SEQ_2_USE    => ("FALSE"),
      CLK_COR_KEEP_IDLE    => ("FALSE"),
      CLK_COR_MAX_LAT      => (9),
      CLK_COR_MIN_LAT      => (7),
      CLK_COR_PRECEDENCE   => ("TRUE"),
      CLK_COR_REPEAT_WAIT  => (0),
      CLK_COR_SEQ_LEN      => (1),
      CLK_COR_SEQ_1_ENABLE => ("1111"),
      CLK_COR_SEQ_1_1      => ("0100000000"),  -- UG476 pg 249
      CLK_COR_SEQ_1_2      => ("0000000000"),
      CLK_COR_SEQ_1_3      => ("0000000000"),
      CLK_COR_SEQ_1_4      => ("0000000000"),
      CLK_CORRECT_USE      => ("FALSE"),
      CLK_COR_SEQ_2_ENABLE => ("1111"),
      CLK_COR_SEQ_2_1      => ("0100000000"),  -- UG476 pg 249
      CLK_COR_SEQ_2_2      => ("0000000000"),
      CLK_COR_SEQ_2_3      => ("0000000000"),
      CLK_COR_SEQ_2_4      => ("0000000000"),

      ------------------------RX Channel Bonding Attributes----------------------
      CHAN_BOND_KEEP_ALIGN   => ("FALSE"),
      CHAN_BOND_MAX_SKEW     => (1),
      CHAN_BOND_SEQ_LEN      => (1),
      CHAN_BOND_SEQ_1_1      => ("0000000000"),
      CHAN_BOND_SEQ_1_2      => ("0000000000"),
      CHAN_BOND_SEQ_1_3      => ("0000000000"),
      CHAN_BOND_SEQ_1_4      => ("0000000000"),
      CHAN_BOND_SEQ_1_ENABLE => ("1111"),
      CHAN_BOND_SEQ_2_1      => ("0000000000"),
      CHAN_BOND_SEQ_2_2      => ("0000000000"),
      CHAN_BOND_SEQ_2_3      => ("0000000000"),
      CHAN_BOND_SEQ_2_4      => ("0000000000"),
      CHAN_BOND_SEQ_2_ENABLE => ("1111"),
      CHAN_BOND_SEQ_2_USE    => ("FALSE"),
      FTS_DESKEW_SEQ_ENABLE  => ("1111"),
      FTS_LANE_DESKEW_CFG    => ("1111"),
      FTS_LANE_DESKEW_EN     => ("FALSE"),

      ---------------------------RX Margin Analysis Attributes----------------------------
      ES_CONTROL     => ("000000"),
      ES_ERRDET_EN   => ("FALSE"),
      ES_EYE_SCAN_EN => ("TRUE"),
      ES_HORZ_OFFSET => (x"000"),
      ES_PMA_CFG     => ("0000000000"),
      ES_PRESCALE    => ("00000"),
      ES_QUALIFIER   => (x"00000000000000000000"),
      ES_QUAL_MASK   => (x"00000000000000000000"),
      ES_SDATA_MASK  => (x"00000000000000000000"),
      ES_VERT_OFFSET => ("000000000"),

      -------------------------FPGA RX Interface Attributes-------------------------
      RX_DATA_WIDTH => (20),

      ---------------------------PMA Attributes----------------------------
      OUTREFCLK_SEL_INV => ("11"),         -- ??
      PMA_RSV           => (x"001E7080"),  -- From wizard for 4.0Tx, 2.5Rx
      PMA_RSV2          => (x"2050"),
      PMA_RSV3          => ("00"),
      PMA_RSV4          => (x"00000000"),
      RX_BIAS_CFG       => ("000000000100"),
      DMONITOR_CFG      => (x"000A00"),
      RX_CM_SEL         => ("11"),
      RX_CM_TRIM        => ("010"),
      RX_DEBUG_CFG      => ("000000000000"),
      RX_OS_CFG         => ("0000010000000"),
      TERM_RCAL_CFG     => ("10000"),
      TERM_RCAL_OVRD    => ('0'),
      TST_RSV           => (x"00000000"),
      RX_CLK25_DIV      => (5),
      TX_CLK25_DIV      => (5),
      UCODEER_CLR       => ('0'),

      ---------------------------PCI Express Attributes----------------------------
      PCS_PCIE_EN => ("FALSE"),

      ---------------------------PCS Attributes----------------------------
      PCS_RSVD_ATTR => X"000000000000",  -- From wizard

      -------------RX Buffer Attributes------------
      RXBUF_ADDR_MODE            => ("FAST"),
      RXBUF_EIDLE_HI_CNT         => ("1000"),
      RXBUF_EIDLE_LO_CNT         => ("0000"),
      RXBUF_EN                   => ("FALSE"),
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
      RXPH_CFG                   => (x"000000"),
      RXPHDLY_CFG                => (x"084020"),
      RXPH_MONITOR_SEL           => ("00000"),
      RX_XCLK_SEL                => ("RXUSR"),
      RX_DDI_SEL                 => ("000000"),
      RX_DEFER_RESET_BUF_EN      => ("TRUE"),

      -----------------------CDR Attributes-------------------------
      RXCDR_CFG               => (x"03000023ff40200020"),
      RXCDR_FR_RESET_ON_EIDLE => ('0'),
      RXCDR_HOLD_DURING_EIDLE => ('0'),
      RXCDR_PH_RESET_ON_EIDLE => ('0'),
      RXCDR_LOCK_CFG          => ("010101"),

      -------------------RX Initialization and Reset Attributes-------------------
      RXCDRFREQRESET_TIME => ("00001"),
      RXCDRPHRESET_TIME   => ("00001"),
      RXISCANRESET_TIME   => ("00001"),
      RXPCSRESET_TIME     => ("00001"),
      RXPMARESET_TIME     => ("00011"), !

      -------------------RX OOB Signaling Attributes-------------------
      RXOOB_CFG => ("0000110"),

      -------------------------RX Gearbox Attributes---------------------------
      RXGEARBOX_EN => ("FALSE"),
      GEARBOX_MODE => ("000"),

      -------------------------PRBS Detection Attribute-----------------------
      RXPRBS_ERR_LOOPBACK => ('0'),

      -------------Power-Down Attributes----------
      PD_TRANS_TIME_FROM_P2 => (x"03c"),
      PD_TRANS_TIME_NONE_P2 => (x"3c"),
      PD_TRANS_TIME_TO_P2   => (x"64"),

      -------------RX OOB Signaling Attributes----------
      SAS_MAX_COM        => (64),
      SAS_MIN_COM        => (36),
      SATA_BURST_SEQ_LEN => ("1111"),
      SATA_BURST_VAL     => ("100"),
      SATA_EIDLE_VAL     => ("100"),
      SATA_MAX_BURST     => (8),
      SATA_MAX_INIT      => (21),
      SATA_MAX_WAKE      => (7),
      SATA_MIN_BURST     => (4),
      SATA_MIN_INIT      => (12),
      SATA_MIN_WAKE      => (4),

      -------------RX Fabric Clock Output Control Attributes----------
      TRANS_TIME_RATE => (x"0E"),

      --------------TX Buffer Attributes----------------
      TXBUF_EN                   => ("TRUE"),  -- Can't yet do fixed latency tx
      TXBUF_RESET_ON_RATE_CHANGE => ("TRUE"),
      TXDLY_CFG                  => (x"001F"),
      TXDLY_LCFG                 => (x"030"),
      TXDLY_TAP_CFG              => (x"0000"),
      TXPH_CFG                   => (x"0780"),
      TXPHDLY_CFG                => (x"084020"),
      TXPH_MONITOR_SEL           => ("00000"),
      TX_XCLK_SEL                => ("TXOUT"),

      -------------------------FPGA TX Interface Attributes-------------------------
      TX_DATA_WIDTH => (20),

      -------------------------TX Configurable Driver Attributes-------------------------
      TX_DEEMPH0              => ("00000"),
      TX_DEEMPH1              => ("00000"),
      TX_EIDLE_ASSERT_DELAY   => ("110"),
      TX_EIDLE_DEASSERT_DELAY => ("100"),
      TX_LOOPBACK_DRIVE_HIZ   => ("FALSE"),
      TX_MAINCURSOR_SEL       => ('0'),
      TX_DRIVE_MODE           => ("DIRECT"),
      TX_MARGIN_FULL_0        => ("1001110"),
      TX_MARGIN_FULL_1        => ("1001001"),
      TX_MARGIN_FULL_2        => ("1000101"),
      TX_MARGIN_FULL_3        => ("1000010"),
      TX_MARGIN_FULL_4        => ("1000000"),
      TX_MARGIN_LOW_0         => ("1000110"),
      TX_MARGIN_LOW_1         => ("1000100"),
      TX_MARGIN_LOW_2         => ("1000010"),
      TX_MARGIN_LOW_3         => ("1000000"),
      TX_MARGIN_LOW_4         => ("1000000"),

      -------------------------TX Gearbox Attributes--------------------------
      TXGEARBOX_EN => ("FALSE"),

      -------------------------TX Initialization and Reset Attributes--------------------------
      TXPCSRESET_TIME => ("00001"),
      TXPMARESET_TIME => ("00001"),

      -------------------------TX Receiver Detection Attributes--------------------------
      TX_RXDETECT_CFG => (x"1832"),
      TX_RXDETECT_REF => ("100"),

      ----------------------------CPLL Attributes----------------------------
      CPLL_CFG        => (x"BC07DC"),
      CPLL_FBDIV      => (CPLL_FBDIV_G),       -- 4
      CPLL_FBDIV_45   => (CPLL_FBDIV_45_G),    -- 5
      CPLL_INIT_CFG   => (x"00001E"),
      CPLL_LOCK_CFG   => (x"01E8"),
      CPLL_REFCLK_DIV => (CPLL_REFCLK_DIV_G),  -- 1
      RXOUT_DIV       => (RXOUT_DIV_G),        -- 2
      TXOUT_DIV       => (TXOUT_DIV_G),        -- 2
      SATA_CPLL_CFG   => ("VCO_3000MHZ"),

      --------------RX Initialization and Reset Attributes-------------
      RXDFELPMRESET_TIME => ("0001111"),

      --------------RX Equalizer Attributes-------------
      RXLPM_HF_CFG                 => ("00000011110000"),
      RXLPM_LF_CFG                 => ("00000011110000"),
      RX_DFE_GAIN_CFG              => (x"020FEA"),
      RX_DFE_H2_CFG                => ("000000000000"),
      RX_DFE_H3_CFG                => ("000001000000"),
      RX_DFE_H4_CFG                => ("00011110000"),
      RX_DFE_H5_CFG                => ("00011100000"),
      RX_DFE_KL_CFG                => ("0000011111110"),
      RX_DFE_LPM_CFG               => (x"0954"),
      RX_DFE_LPM_HOLD_DURING_EIDLE => ('0'),
      RX_DFE_UT_CFG                => ("10001111000000000"),
      RX_DFE_VP_CFG                => ("00011111100000011"),

      -------------------------Power-Down Attributes-------------------------
      RX_CLKMUX_PD => ('1'),
      TX_CLKMUX_PD => ('1'),

      -------------------------FPGA RX Interface Attribute-------------------------
      RX_INT_DATAWIDTH => (0),

      -------------------------FPGA TX Interface Attribute-------------------------
      TX_INT_DATAWIDTH => (0),

      ------------------TX Configurable Driver Attributes---------------
      TX_QPI_STATUS_EN => ('0'),

      -------------------------RX Equalizer Attributes--------------------------
      RX_DFE_KL_CFG2 => (X"3008E56A"),  -- Set by wizard
      RX_DFE_XYD_CFG => ("0000000000000"),

      -------------------------TX Configurable Driver Attributes--------------------------
      TX_PREDRIVER_MODE => ('0')


      )
    port map
    (
      ---------------------------------- Channel ---------------------------------
      CFGRESET         => '0',
      CLKRSVD          => "0000",
      DMONITOROUT      => open,
      GTRESETSEL       => '0',              -- Sequential Mode
      GTRSVD           => "0000000000000000",
      QPLLCLK          => qPllClk,
      QPLLREFCLK       => qPllRefClk,
      RESETOVRD        => '0',
      ---------------- Channel - Dynamic Reconfiguration Port (DRP) --------------
      DRPADDR          => X"00",
      DRPCLK           => '0',
      DRPDI            => X"0000",
      DRPDO            => open,
      DRPEN            => '0',
      DRPRDY           => open,
      DRPWE            => '0',
      ------------------------- Channel - Ref Clock Ports ------------------------
      GTGREFCLK        => gtGRefClk,
      GTNORTHREFCLK0   => gtNorthRefClk0,
      GTNORTHREFCLK1   => gtNorthRefClk1,
      GTREFCLK0        => gtRefClk0,
      GTREFCLK1        => gtRefClk1,
      GTREFCLKMONITOR  => open,
      GTSOUTHREFCLK0   => gtSouthRefClk0,
      GTSOUTHREFCLK1   => gtSouthRefClk1,
      -------------------------------- Channel PLL -------------------------------
      CPLLFBCLKLOST    => open,
      CPLLLOCK         => cPllLock,
      CPLLLOCKDETCLK   => '0',
      CPLLLOCKEN       => '1',
      CPLLPD           => '0',
      CPLLREFCLKLOST   => open,
      CPLLREFCLKSEL    => CPLLREFCLKSEL_G,  -- "001" for GTREFCLK0
      CPLLRESET        => cPllReset,
      ------------------------------- Eye Scan Ports -----------------------------
      EYESCANDATAERROR => open,
      EYESCANMODE      => '0',
      EYESCANRESET     => '0',
      EYESCANTRIGGER   => '0',
      ------------------------ Loopback and Powerdown Ports ----------------------
      LOOPBACK         => gtLoopback,
      RXPD             => "00",
      TXPD             => "00",
      ----------------------------- PCS Reserved Ports ---------------------------
      PCSRSVDIN        => "0000000000000000",
      PCSRSVDIN2       => "00000",
      PCSRSVDOUT       => open,
      ----------------------------- PMA Reserved Ports ---------------------------
      PMARSVDIN        => "00000",
      PMARSVDIN2       => "00000",
      ------------------------------- Receive Ports ------------------------------
      RXQPIEN          => '0',
      RXQPISENN        => open,
      RXQPISENP        => open,
      RXSYSCLKSEL      => "00",             -- Use CPLL clock for RX
      RXUSERRDY        => gtRxUserRdy,
      -------------- Receive Ports - 64b66b and 64b67b Gearbox Ports -------------
      RXDATAVALID      => open,
      RXGEARBOXSLIP    => '0',
      RXHEADER         => open,
      RXHEADERVALID    => open,
      RXSTARTOFSEQ     => open,
      ----------------------- Receive Ports - 8b10b Decoder ----------------------
      RX8B10BEN        => '0',
      RXCHARISCOMMA    => open,
      RXCHARISK        => gtRxCharIsKInt,
      RXDISPERR        => gtRxDispErrInt,
      RXNOTINTABLE     => open,
      ------------------- Receive Ports - Channel Bonding Ports ------------------
      RXCHANBONDSEQ    => open,
      RXCHBONDEN       => '0',
      RXCHBONDI        => "00000",
      RXCHBONDLEVEL    => "000",
      RXCHBONDMASTER   => '0',
      RXCHBONDO        => open,
      RXCHBONDSLAVE    => '0',
      ------------------- Receive Ports - Channel Bonding Ports  -----------------
      RXCHANISALIGNED  => open,
      RXCHANREALIGN    => open,
      ------------------- Receive Ports - Clock Correction Ports -----------------
      RXCLKCORCNT      => open,
      --------------- Receive Ports - Comma Detection and Alignment --------------
      RXBYTEISALIGNED  => open,
      RXBYTEREALIGN    => open,
      RXCOMMADET       => open,
      RXCOMMADETEN     => '1',              -- Enables RXSLIDE
      RXMCOMMAALIGNEN  => '0',
      RXPCOMMAALIGNEN  => '0',
      RXSLIDE          => gtRxSlide,
      ----------------------- Receive Ports - PRBS Detection ---------------------
      RXPRBSCNTRESET   => '0',
      RXPRBSERR        => open,
      RXPRBSSEL        => "000",
      ------------------- Receive Ports - RX Data Path interface -----------------
      GTRXRESET        => gtRxReset,
      RXDATA           => gtRxDataInt,
      RXOUTCLK         => gtRxOutClk
      RXOUTCLKFABRIC   => open,
      RXOUTCLKPCS      => open,
      RXOUTCLKSEL      => "010",            -- Selects rx recovered clk for rxoutclk
      RXPCSRESET       => '0',              -- Don't bother with component level resets
      RXPMARESET       => '0',
      RXUSRCLK         => gtRxUsrClk,
      RXUSRCLK2        => gtRxUsrClk,
      ------------ Receive Ports - RX Decision Feedback Equalizer(DFE) -----------
      RXDFEAGCHOLD     => '0',
      RXDFEAGCOVRDEN   => '0',
      RXDFECM1EN       => '0',
      RXDFELFHOLD      => '0',
      RXDFELFOVRDEN    => '1',
      RXDFELPMRESET    => '0',
      RXDFETAP2HOLD    => '0',
      RXDFETAP2OVRDEN  => '0',
      RXDFETAP3HOLD    => '0',
      RXDFETAP3OVRDEN  => '0',
      RXDFETAP4HOLD    => '0',
      RXDFETAP4OVRDEN  => '0',
      RXDFETAP5HOLD    => '0',
      RXDFETAP5OVRDEN  => '0',
      RXDFEUTHOLD      => '0',
      RXDFEUTOVRDEN    => '0',
      RXDFEVPHOLD      => '0',
      RXDFEVPOVRDEN    => '0',
      RXDFEVSEN        => '0',
      RXDFEXYDEN       => '0',
      RXDFEXYDHOLD     => '0',
      RXDFEXYDOVRDEN   => '0',
      RXMONITOROUT     => open,
      RXMONITORSEL     => "00",
      RXOSHOLD         => '0',
      RXOSOVRDEN       => '0',
      ------- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
      GTXRXN           => gtRxN,
      GTXRXP           => gtRxP,
      RXCDRFREQRESET   => '0',
      RXCDRHOLD        => '0',
      RXCDRLOCK        => gtRxCdrLock,      -- May not work
      RXCDROVRDEN      => '0',
      RXCDRRESET       => '0',
      RXCDRRESETRSV    => '0',
      RXELECIDLE       => open,
      RXELECIDLEMODE   => "11",
      RXLPMEN          => '0',
      RXLPMHFHOLD      => '0',
      RXLPMHFOVRDEN    => '0',
      RXLPMLFHOLD      => '0',
      RXLPMLFKLOVRDEN  => '0',
      RXOOBRESET       => '0',
      -------- Receive Ports - RX Elastic Buffer and Phase Alignment Ports -------
      RXBUFRESET       => '0',
      RXBUFSTATUS      => open,
      RXDDIEN          => '0',              -- Don't insert delay in deserializer. Might be wrong.
      RXDLYBYPASS      => '1',              -- Dont use delay aligner.
      RXDLYEN          => '0',
      RXDLYOVRDEN      => '0',
      RXDLYSRESET      => '0',
      RXDLYSRESETDONE  => open,
      RXPHALIGN        => '0',
      RXPHALIGNDONE    => open,
      RXPHALIGNEN      => '0',
      RXPHDLYPD        => '0',
      RXPHDLYRESET     => '0',
      RXPHMONITOR      => open,
      RXPHOVRDEN       => '0',
      RXPHSLIPMONITOR  => open,
      RXSTATUS         => open,
      ------------------------ Receive Ports - RX PLL Ports ----------------------
      RXRATE           => "000",
      RXRATEDONE       => open,
      RXRESETDONE      => gtRxResetDone,
      -------------- Receive Ports - RX Pipe Control for PCI Express -------------
      PHYSTATUS        => open,
      RXVALID          => open,
      ----------------- Receive Ports - RX Polarity Control Ports ----------------
      RXPOLARITY       => gtRxPolarity,
      --------------------- Receive Ports - RX Ports for SATA --------------------
      RXCOMINITDET     => open,
      RXCOMSASDET      => open,
      RXCOMWAKEDET     => open,
      ------------------------------- Transmit Ports -----------------------------
      SETERRSTATUS     => '0',
      TSTIN            => "11111111111111111111",
      TSTOUT           => open,
      TXPHDLYTSTCLK    => '0',
      TXPOSTCURSOR     => "00000",
      TXPOSTCURSORINV  => '0',
      TXPRECURSOR      => "00000",
      TXPRECURSORINV   => '0',
      TXQPIBIASEN      => '0',
      TXQPISENN        => open,
      TXQPISENP        => open,
      TXQPISTRONGPDOWN => '0',
      TXQPIWEAKPUP     => '0',
      TXSYSCLKSEL      => "11",             -- Drive TX from QPLL
      TXUSERRDY        => gtTxUserRdy,
      -------------- Transmit Ports - 64b66b and 64b67b Gearbox Ports ------------
      TXGEARBOXREADY   => open,
      TXHEADER         => "000",
      TXSEQUENCE       => "0000000",
      TXSTARTSEQ       => '0',
      ---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
      TX8B10BBYPASS    => X"00",
      TX8B10BEN        => '1',
      TXCHARDISPMODE   => X"00",
      TXCHARDISPVAL    => X"00",
      TXCHARISK        => gtTxCharIsKInt,
      ------------ Transmit Ports - TX Buffer and Phase Alignment Ports ----------
      TXBUFSTATUS      => open,
      TXDLYBYPASS      => '1',              -- Use the tx delay alignment circuit
      TXDLYEN          => '0',              -- Use auto alignment
      TXDLYHOLD        => '0',
      TXDLYOVRDEN      => '0',
      TXDLYSRESET      => '0',              -- gtTxDlySReset,
      TXDLYSRESETDONE  => open,             -- gtTxDlySResetDone,
      TXDLYUPDOWN      => '0',
      TXPHALIGN        => '0',              -- Use auto alignment
      TXPHALIGNDONE    => open,             -- gtTxPhAlignDone,
      TXPHALIGNEN      => '0',              -- Use auto alignment
      TXPHDLYPD        => '0',
      TXPHDLYRESET     => '0',              -- Use SReset instead
      TXPHINIT         => '0',              -- Use auto alignment
      TXPHINITDONE     => open,
      TXPHOVRDEN       => '0',
      ------------------ Transmit Ports - TX Data Path interface -----------------
      GTTXRESET        => gtTxReset,
      TXDATA           => gtTxDataInt,
      TXOUTCLK         => gtTxOutClk,
      TXOUTCLKFABRIC   => open,
      TXOUTCLKPCS      => open,
      TXOUTCLKSEL      => "011",            -- pll refclk 
      TXPCSRESET       => '0',              -- Don't bother with individual resets
      TXPMARESET       => '0',
      TXUSRCLK         => gtTxUsrClk,
      TXUSRCLK2        => gtTxUsrClk,
      ---------------- Transmit Ports - TX Driver and OOB signaling --------------
      GTXTXN           => gtTxN,
      GTXTXP           => gtTxP,
      TXBUFDIFFCTRL    => "100",
      TXDIFFCTRL       => "1000",
      TXDIFFPD         => '0',
      TXINHIBIT        => '0',
      TXMAINCURSOR     => "0000000",
      TXPDELECIDLEMODE => '0',
      TXPISOPD         => '0',
      ----------------------- Transmit Ports - TX PLL Ports ----------------------
      TXRATE           => "000",
      TXRATEDONE       => open,
      TXRESETDONE      => gtTxResetDone,
      --------------------- Transmit Ports - TX PRBS Generator -------------------
      TXPRBSFORCEERR   => '0',
      TXPRBSSEL        => "000",
      -------------------- Transmit Ports - TX Polarity Control ------------------
      TXPOLARITY       => '0',
      ----------------- Transmit Ports - TX Ports for PCI Express ----------------
      TXDEEMPH         => '0',
      TXDETECTRX       => '0',
      TXELECIDLE       => '0',
      TXMARGIN         => "000",
      TXSWING          => '0',
      --------------------- Transmit Ports - TX Ports for SATA -------------------
      TXCOMFINISH      => open,
      TXCOMINIT        => '0',
      TXCOMSAS         => '0',
      TXCOMWAKE        => '0'

      );


end architecture rtl;
