-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, Virtex 6 GTX Wrapper
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2GtxV616.vhd
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

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.Pgp2GtxV6Package.all;
use work.Pgp2CorePackage.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;


entity Pgp2GtxV616 is
   generic (
      EnShortCells : integer := 1;         -- Enable short non-EOF cells
      VcInterleave : integer := 1          -- Interleave Frames
   );
   port (
	
      -- System clock, reset & control
      pgpClk            : in  std_logic;                     -- 156.25Mhz master clock
      pgpClk2x          : in  std_logic;                     -- 2x master clock
      pgpReset          : in  std_logic;                     -- Synchronous reset input
      pgpFlush          : in  std_logic;                     -- Frame state flash

      -- PLL Reset Control
      pllTxRst          : in  std_logic;                     -- Reset transmit PLL logic
      pllRxRst          : in  std_logic;                     -- Reset receive  PLL logic

      -- PLL Lock Status
      pllRxReady        : out std_logic;                     -- MGT Receive logic is ready
      pllTxReady        : out std_logic;                     -- MGT Transmit logic is ready

      -- Sideband data
      pgpRemData        : out std_logic_vector(7 downto 0);  -- Far end side User Data
      pgpLocData        : in  std_logic_vector(7 downto 0);  -- Far end side User Data

      -- Opcode Transmit Interface
      pgpTxOpCodeEn     : in  std_logic;                     -- Opcode receive enable
      pgpTxOpCode       : in  std_logic_vector(7 downto 0);  -- Opcode receive value

      -- Opcode Receive Interface
      pgpRxOpCodeEn     : out std_logic;                     -- Opcode receive enable
      pgpRxOpCode       : out std_logic_vector(7 downto 0);  -- Opcode receive value

      -- Link status
      pgpLocLinkReady   : out std_logic;                     -- Local Link is ready
      pgpRemLinkReady   : out std_logic;                     -- Far end side has link

      -- Error Flags, one pulse per event
      pgpRxCellError    : out std_logic;                     -- A cell error has occured
      pgpRxLinkDown     : out std_logic;                     -- A link down event has occured
      pgpRxLinkError    : out std_logic;                     -- A link error has occured

      -- Frame Transmit Interface, VC 0
      vc0FrameTxValid   : in  std_logic;                     -- User frame data is valid
      vc0FrameTxReady   : out std_logic;                     -- PGP is ready
      vc0FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
      vc0FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
      vc0FrameTxEOFE    : in  std_logic;                     -- User frame data error
      vc0FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
      vc0LocBuffAFull   : in  std_logic;                     -- Remote buffer almost full
      vc0LocBuffFull    : in  std_logic;                     -- Remote buffer full

      -- Frame Transmit Interface, VC 1
      vc1FrameTxValid   : in  std_logic;                     -- User frame data is valid
      vc1FrameTxReady   : out std_logic;                     -- PGP is ready
      vc1FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
      vc1FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
      vc1FrameTxEOFE    : in  std_logic;                     -- User frame data error
      vc1FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
      vc1LocBuffAFull   : in  std_logic;                     -- Remote buffer almost full
      vc1LocBuffFull    : in  std_logic;                     -- Remote buffer full

      -- Frame Transmit Interface, VC 2
      vc2FrameTxValid   : in  std_logic;                     -- User frame data is valid
      vc2FrameTxReady   : out std_logic;                     -- PGP is ready
      vc2FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
      vc2FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
      vc2FrameTxEOFE    : in  std_logic;                     -- User frame data error
      vc2FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
      vc2LocBuffAFull   : in  std_logic;                     -- Remote buffer almost full
      vc2LocBuffFull    : in  std_logic;                     -- Remote buffer full

      -- Frame Transmit Interface, VC 3
      vc3FrameTxValid   : in  std_logic;                     -- User frame data is valid
      vc3FrameTxReady   : out std_logic;                     -- PGP is ready
      vc3FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
      vc3FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
      vc3FrameTxEOFE    : in  std_logic;                     -- User frame data error
      vc3FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
      vc3LocBuffAFull   : in  std_logic;                     -- Remote buffer almost full
      vc3LocBuffFull    : in  std_logic;                     -- Remote buffer full

      -- Common Frame Receive Interface For All VCs
      vcFrameRxSOF      : out std_logic;                     -- PGP frame data start of frame
      vcFrameRxEOF      : out std_logic;                     -- PGP frame data end of frame
      vcFrameRxEOFE     : out std_logic;                     -- PGP frame data error
      vcFrameRxData     : out std_logic_vector(15 downto 0); -- PGP frame data

      -- Frame Receive Interface, VC 0
      vc0FrameRxValid   : out std_logic;                     -- PGP frame data is valid
      vc0RemBuffAFull   : out std_logic;                     -- Remote buffer almost full
      vc0RemBuffFull    : out std_logic;                     -- Remote buffer full

      -- Frame Receive Interface, VC 1
      vc1FrameRxValid   : out std_logic;                     -- PGP frame data is valid
      vc1RemBuffAFull   : out std_logic;                     -- Remote buffer almost full
      vc1RemBuffFull    : out std_logic;                     -- Remote buffer full

      -- Frame Receive Interface, VC 2
      vc2FrameRxValid   : out std_logic;                     -- PGP frame data is valid
      vc2RemBuffAFull   : out std_logic;                     -- Remote buffer almost full
      vc2RemBuffFull    : out std_logic;                     -- Remote buffer full

      -- Frame Receive Interface, VC 3
      vc3FrameRxValid   : out std_logic;                     -- PGP frame data is valid
      vc3RemBuffAFull   : out std_logic;                     -- Remote buffer almost full
      vc3RemBuffFull    : out std_logic;                     -- Remote buffer full

      -- GTP loopback control
      gtpLoopback       : in  std_logic;                     -- GTP Serial Loopback Control

      -- GTP Signals
      gtpClkIn          : in  std_logic;                     -- GTP Reference Clock In
      gtpRefClkOut      : out std_logic;                     -- GTP Reference Clock Output
      gtpRxRecClk       : out std_logic;                     -- GTP Rx Recovered Clock
      gtpRxN            : in  std_logic;                     -- GTP Serial Receive Negative
      gtpRxP            : in  std_logic;                     -- GTP Serial Receive Positive
      gtpTxN            : out std_logic;                     -- GTP Serial Transmit Negative
      gtpTxP            : out std_logic;                     -- GTP Serial Transmit Positive

      -- Debug
      debug             : out std_logic_vector(63 downto 0)
   );

end Pgp2GtxV616;


-- Define architecture
architecture Pgp2GtxV616 of Pgp2GtxV616 is

   -- Local Signals
   signal crcTxIn           : std_logic_vector(15 downto 0);
   signal crcTxInGtp        : std_logic_vector(31 downto 0);
   signal crcTxInit         : std_logic;
   signal crcTxRst          : std_logic;
   signal crcTxValid        : std_logic;
   signal crcTxWidth        : std_logic_vector(2  downto 0);
   signal crcTxOut          : std_logic_vector(31 downto 0);
   signal crcTxOutGtp       : std_logic_vector(31 downto 0);
   signal crcRxIn           : std_logic_vector(15 downto 0);
   signal crcRxInGtp        : std_logic_vector(31 downto 0);
   signal crcRxInit         : std_logic;
   signal crcRxRst          : std_logic;
   signal crcRxValid        : std_logic;
   signal crcRxWidth        : std_logic_vector(2  downto 0);
   signal crcRxOut          : std_logic_vector(31 downto 0);
   signal crcRxOutGtp       : std_logic_vector(31 downto 0);
   signal phyRxPolarity     : std_logic_vector(0  downto 0);
   signal phyRxData         : std_logic_vector(31 downto 0);
   signal phyRxDataK        : std_logic_vector(1  downto 0);
   signal phyTxData         : std_logic_vector(31 downto 0);
   signal phyTxDataK        : std_logic_vector(1  downto 0);
   signal phyRxDispErr      : std_logic_vector(1  downto 0);
   signal phyRxDecErr       : std_logic_vector(1  downto 0);
   signal phyRxReady        : std_logic;
   signal phyRxInit         : std_logic;
   signal phyTxReady        : std_logic;
   signal phyRxReset        : std_logic;
   signal phyRxElecIdleRst  : std_logic;
   signal phyRxElecIdle     : std_logic;
   signal phyRxCdrReset     : std_logic;
   signal phyRstDone        : std_logic;
   signal phyRxBuffStatus   : std_logic_vector(2  downto 0);
   signal phyTxReset        : std_logic;
   signal phyTxBuffStatus   : std_logic_vector(1  downto 0);
   signal phyLockDetect     : std_logic;
   signal intTxRst          : std_logic;
   signal intRxRst          : std_logic;
   signal pgpRxLinkReady    : std_logic;
   signal pgpTxLinkReady    : std_logic;
   signal intRxRecClk       : std_logic;
   signal tmpRefClkOut      : std_logic;
   signal txKerr            : std_logic_vector(1 downto 0);
   signal testclk           : std_logic;
   signal test_out          : std_logic;


   signal RXphyLockDetect   : std_logic;
   signal TXphyLockDetect   : std_logic;
   signal RXphyRstDone      : std_logic;
   signal TXphyRstDone      : std_logic;
   signal gtpClkIn_v        : std_logic_vector(1 downto 0);
	
	

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin


   -- PGP RX Block
   U_Pgp2Rx: Pgp2Rx
      generic map (
         RxLaneCnt    => 1,
         EnShortCells => EnShortCells
      ) port map (
         pgpRxClk          => pgpClk,
         pgpRxReset        => pgpReset,
         pgpRxFlush        => pgpFlush,
         pgpRxLinkReady    => pgpRxLinkReady,
         pgpRxCellError    => pgpRxCellError,
         pgpRxLinkDown     => pgpRxLinkDown,
         pgpRxLinkError    => pgpRxLinkError,
         pgpRxOpCodeEn     => pgpRxOpCodeEn,
         pgpRxOpCode       => pgpRxOpCode,
         pgpRemLinkReady   => pgpRemLinkReady,
         pgpRemData        => pgpRemData,
         vcFrameRxSOF      => vcFrameRxSOF,
         vcFrameRxEOF      => vcFrameRxEOF,
         vcFrameRxEOFE     => vcFrameRxEOFE,
         vcFrameRxData     => vcFrameRxData,
         vc0FrameRxValid   => vc0FrameRxValid,
         vc0RemBuffAFull   => vc0RemBuffAFull,
         vc0RemBuffFull    => vc0RemBuffFull,
         vc1FrameRxValid   => vc1FrameRxValid,
         vc1RemBuffAFull   => vc1RemBuffAFull,
         vc1RemBuffFull    => vc1RemBuffFull,
         vc2FrameRxValid   => vc2FrameRxValid,
         vc2RemBuffAFull   => vc2RemBuffAFull,
         vc2RemBuffFull    => vc2RemBuffFull,
         vc3FrameRxValid   => vc3FrameRxValid,
         vc3RemBuffAFull   => vc3RemBuffAFull,
         vc3RemBuffFull    => vc3RemBuffFull,
         phyRxPolarity     => phyRxPolarity,
         phyRxData         => phyRxData,
         phyRxDataK        => phyRxDataK,
         phyRxDispErr      => phyRxDispErr,
         phyRxDecErr       => phyRxDecErr,
         phyRxReady        => phyRxReady,
         phyRxInit         => phyRxInit,
         crcRxIn           => crcRxIn,
         crcRxWidth        => open,
         crcRxInit         => crcRxInit,
         crcRxValid        => crcRxValid,
         crcRxOut          => crcRxOut,
         debug             => debug
      );


   -- PGP TX Block
   U_Pgp2Tx: Pgp2Tx
      generic map (
         TxLaneCnt    => 1,
         VcInterleave => VcInterleave
      ) port map (
         pgpTxClk          => pgpClk,
         pgpTxReset        => pgpReset,
         pgpTxFlush        => pgpFlush,
         pgpTxLinkReady    => pgpTxLinkReady,
         pgpTxOpCodeEn     => pgpTxOpCodeEn,
         pgpTxOpCode       => pgpTxOpCode,
         pgpLocLinkReady   => pgpRxLinkReady,
         pgpLocData        => pgpLocData,
         vc0FrameTxValid   => vc0FrameTxValid,
         vc0FrameTxReady   => vc0FrameTxReady,
         vc0FrameTxSOF     => vc0FrameTxSOF,
         vc0FrameTxEOF     => vc0FrameTxEOF,
         vc0FrameTxEOFE    => vc0FrameTxEOFE,
         vc0FrameTxData    => vc0FrameTxData,
         vc0LocBuffAFull   => vc0LocBuffAFull,
         vc0LocBuffFull    => vc0LocBuffFull,
         vc1FrameTxValid   => vc1FrameTxValid,
         vc1FrameTxReady   => vc1FrameTxReady,
         vc1FrameTxSOF     => vc1FrameTxSOF,
         vc1FrameTxEOF     => vc1FrameTxEOF,
         vc1FrameTxEOFE    => vc1FrameTxEOFE,
         vc1FrameTxData    => vc1FrameTxData,
         vc1LocBuffAFull   => vc1LocBuffAFull,
         vc1LocBuffFull    => vc1LocBuffFull,
         vc2FrameTxValid   => vc2FrameTxValid,
         vc2FrameTxReady   => vc2FrameTxReady,
         vc2FrameTxSOF     => vc2FrameTxSOF,
         vc2FrameTxEOF     => vc2FrameTxEOF,
         vc2FrameTxEOFE    => vc2FrameTxEOFE,
         vc2FrameTxData    => vc2FrameTxData,
         vc2LocBuffAFull   => vc2LocBuffAFull,
         vc2LocBuffFull    => vc2LocBuffFull,
         vc3FrameTxValid   => vc3FrameTxValid,
         vc3FrameTxReady   => vc3FrameTxReady,
         vc3FrameTxSOF     => vc3FrameTxSOF,
         vc3FrameTxEOF     => vc3FrameTxEOF,
         vc3FrameTxEOFE    => vc3FrameTxEOFE,
         vc3FrameTxData    => vc3FrameTxData,
         vc3LocBuffAFull   => vc3LocBuffAFull,
         vc3LocBuffFull    => vc3LocBuffFull,
         phyTxData         => phyTxData,
         phyTxDataK        => phyTxDataK,
         phyTxReady        => phyTxReady,
         crcTxIn           => crcTxIn,
         crcTxInit         => crcTxInit,
         crcTxValid        => crcTxValid,
         crcTxOut          => crcTxOut,
         debug             => open
      );

-- To mutch GTP width for S6 and V5

	phyTxData(31 downto 16) <= (Others => '0');
	
   -- Adapt CRC data width flag
   crcTxWidth <= "001";
   crcRxWidth <= "001";
   crcRxRst   <= intRxRst or crcRxInit;
   crcTxRst   <= intTxRst or crcTxInit;

   -- Pass CRC data in on proper bits
   crcTxInGtp(31 downto 24) <= crcTxIn(7  downto 0);
   crcTxInGtp(23 downto 16) <= crcTxIn(15 downto 8);
   crcTxInGtp(15 downto  0) <= (others=>'0');
   crcRxInGtp(31 downto 24) <= crcRxIn(7  downto 0);
   crcRxInGtp(23 downto 16) <= crcRxIn(15 downto 8);
   crcRxInGtp(15 downto  0) <= (others=>'0');

   -- Pll Resets
   intTxRst <= pllTxRst or pgpReset;
   intRxRst <= pllRxRst or pgpReset;

   -- PLL Lock
   pllRxReady <= phyRxReady;
   pllTxReady <= phyTxReady;

   -- Link Ready
   pgpLocLinkReady <= pgpRxLinkReady and pgpTxLinkReady;

   -- Invert Output CRC
   crcRxOut <= not crcRxOutGtp;
   crcTxOut <= not crcTxOutGtp;

 
   -- TX CRC BLock
   Tx_CRC: CRC32_V6
      generic map(
         CRC_INIT   => x"FFFFFFFF"
      ) port map(
         CRCOUT       => crcTxOutGtp,
         CRCCLK       => pgpClk,
         CRCDATAVALID => crcTxValid,
         CRCDATAWIDTH => crcTxWidth,
         CRCIN        => crcTxInGtp,
         CRCRESET     => crcTxRst
      );

   -- RX CRC BLock
   Rx_CRC: CRC32_V6
      generic map(
         CRC_INIT   => x"FFFFFFFF"
      ) port map(
         CRCOUT       => crcRxOutGtp,
         CRCCLK       => pgpClk,
         CRCDATAVALID => crcRxValid,
         CRCDATAWIDTH => crcRxWidth,
         CRCIN        => crcRxInGtp,
         CRCRESET     => crcRxRst
      );

   -- RX Reset Control
   U_Pgp2GtxV6RxRst: Pgp2GtxV6RxRst
      port map (
         gtpRxClk          => pgpClk,
         gtpRxRst          => intRxRst,
         gtpRxReady        => phyRxReady,
         gtpRxInit         => phyRxInit,
         gtpLockDetect     => phyLockDetect,
         gtpRxElecIdle     => phyRxElecIdle,
         gtpRxBuffStatus   => phyRxBuffStatus,
         gtpRstDone        => phyRstDone,
         gtpRxElecIdleRst  => phyRxElecIdleRst,
         gtpRxReset        => phyRxReset,
         gtpRxCdrReset     => phyRxCdrReset
      );


   -- TX Reset Control
   U_Pgp2GtxV6TxRst: Pgp2GtxV6TxRst
      port map (
         gtpTxClk          => pgpClk,
         gtpTxRst          => intTxRst,
         gtpTxReady        => phyTxReady,
         gtpLockDetect     => phyLockDetect,
         gtpTxBuffStatus   => phyTxBuffStatus,
         gtpRstDone        => phyRstDone,
         gtpTxReset        => phyTxReset
      );

   phyLockDetect <= RXphyLockDetect AND TXphyLockDetect;
   phyRstDone  <= RXphyRstDone AND TXphyRstDone;
	gtpClkIn_v <= '0' & gtpClkIn;
    gtxe1_i :GTXE1
    generic map
    (

        --_______________________ Simulation-Only Attributes ___________________

        SIM_RECEIVER_DETECT_PASS   =>      (TRUE),

        SIM_GTXRESET_SPEEDUP       =>      1,

        SIM_TX_ELEC_IDLE_LEVEL     =>      ("X"),

        SIM_VERSION                =>      ("2.0"),
        SIM_TXREFCLK_SOURCE        =>      ("000"),
        SIM_RXREFCLK_SOURCE        =>      ("000"),


       ----------------------------TX PLL----------------------------
        TX_CLK_SOURCE                           =>     ("RXPLL"),
        TX_OVERSAMPLE_MODE                      =>     (FALSE),
        TXPLL_COM_CFG                           =>     (x"21680a"),
        TXPLL_CP_CFG                            =>     (x"07"),
        TXPLL_DIVSEL_FB                         =>     (5),
        TXPLL_DIVSEL_OUT                        =>     (1),
        TXPLL_DIVSEL_REF                        =>     (2),
        TXPLL_DIVSEL45_FB                       =>     (5),
        TXPLL_LKDET_CFG                         =>     ("111"),
        TX_CLK25_DIVIDER                        =>     (5),
        TXPLL_SATA                              =>     ("00"),
        TX_TDCC_CFG                             =>     ("11"),
        PMA_CAS_CLK_EN                          =>     (FALSE),
        POWER_SAVE                              =>     ("0000110100"),

       -------------------------TX Interface-------------------------
        GEN_TXUSRCLK                            =>     (TRUE),
        TX_DATA_WIDTH                           =>     (20),
        TX_USRCLK_CFG                           =>     (x"00"),
        TXOUTCLK_CTRL                           =>     ("TXOUTCLKPMA_DIV2"),
        TXOUTCLK_DLY                            =>     ("0000000000"),

       --------------TX Buffering and Phase Alignment----------------
        TX_PMADATA_OPT                          =>     ('0'),
        PMA_TX_CFG                              =>     (x"80082"),
        TX_BUFFER_USE                           =>     (TRUE),
        TX_BYTECLK_CFG                          =>     (x"00"),
        TX_EN_RATE_RESET_BUF                    =>     (TRUE),
        TX_XCLK_SEL                             =>     ("TXOUT"),
        TX_DLYALIGN_CTRINC                      =>     ("0100"),
        TX_DLYALIGN_LPFINC                      =>     ("0110"),
        TX_DLYALIGN_MONSEL                      =>     ("000"),
        TX_DLYALIGN_OVRDSETTING                 =>     ("10000000"),

       -------------------------TX Gearbox---------------------------
        GEARBOX_ENDEC                           =>     ("000"),
        TXGEARBOX_USE                           =>     (FALSE),

       ----------------TX Driver and OOB Signalling------------------
        TX_DRIVE_MODE                           =>     ("DIRECT"),
        TX_IDLE_ASSERT_DELAY                    =>     ("100"),
        TX_IDLE_DEASSERT_DELAY                  =>     ("010"),
        TXDRIVE_LOOPBACK_HIZ                    =>     (FALSE),
        TXDRIVE_LOOPBACK_PD                     =>     (FALSE),

       --------------TX Pipe Control for PCI Express/SATA------------
        COM_BURST_VAL                           =>     ("1111"),

       ------------------TX Attributes for PCI Express---------------
        TX_DEEMPH_0                             =>     ("11010"),
        TX_DEEMPH_1                             =>     ("10000"),
        TX_MARGIN_FULL_0                        =>     ("1001110"),
        TX_MARGIN_FULL_1                        =>     ("1001001"),
        TX_MARGIN_FULL_2                        =>     ("1000101"),
        TX_MARGIN_FULL_3                        =>     ("1000010"),
        TX_MARGIN_FULL_4                        =>     ("1000000"),
        TX_MARGIN_LOW_0                         =>     ("1000110"),
        TX_MARGIN_LOW_1                         =>     ("1000100"),
        TX_MARGIN_LOW_2                         =>     ("1000010"),
        TX_MARGIN_LOW_3                         =>     ("1000000"),
        TX_MARGIN_LOW_4                         =>     ("1000000"),

       ----------------------------RX PLL----------------------------
        RX_OVERSAMPLE_MODE                      =>     (FALSE),
        RXPLL_COM_CFG                           =>     (x"21680a"),
        RXPLL_CP_CFG                            =>     (x"07"),
        RXPLL_DIVSEL_FB                         =>     (5),
        RXPLL_DIVSEL_OUT                        =>     (1),
        RXPLL_DIVSEL_REF                        =>     (2),
        RXPLL_DIVSEL45_FB                       =>     (5),
        RXPLL_LKDET_CFG                         =>     ("111"),
        RX_CLK25_DIVIDER                        =>     (5),

       -------------------------RX Interface-------------------------
        GEN_RXUSRCLK                            =>     (TRUE),
        RX_DATA_WIDTH                           =>     (20),
        RXRECCLK_CTRL                           =>     ("RXRECCLKPMA_DIV2"),
        RXRECCLK_DLY                            =>     ("0000000000"),
        RXUSRCLK_DLY                            =>     (x"0000"),

       ----------RX Driver,OOB signalling,Coupling and Eq.,CDR-------
        AC_CAP_DIS                              =>     (TRUE),
        CDR_PH_ADJ_TIME                         =>     ("10100"),
        OOBDETECT_THRESHOLD                     =>     ("011"),
        PMA_CDR_SCAN                            =>     (x"640404C"),
        PMA_RX_CFG                              =>     (x"05ce008"),
        RCV_TERM_GND                            =>     (FALSE),
        RCV_TERM_VTTRX                          =>     (FALSE),
        RX_EN_IDLE_HOLD_CDR                     =>     (FALSE),
        RX_EN_IDLE_RESET_FR                     =>     (TRUE),
        RX_EN_IDLE_RESET_PH                     =>     (TRUE),
        TX_DETECT_RX_CFG                        =>     (x"1832"),
        TERMINATION_CTRL                        =>     ("00000"),
        TERMINATION_OVRD                        =>     (FALSE),
        CM_TRIM                                 =>     ("01"),
        PMA_RXSYNC_CFG                          =>     (x"00"),
        PMA_CFG                                 =>     (x"0040000040000000003"),
        BGTEST_CFG                              =>     ("00"),
        BIAS_CFG                                =>     (x"00000"),

       --------------RX Decision Feedback Equalizer(DFE)-------------
        DFE_CAL_TIME                            =>     ("01100"),
        DFE_CFG                                 =>     ("00011011"),
        RX_EN_IDLE_HOLD_DFE                     =>     (TRUE),
        RX_EYE_OFFSET                           =>     (x"4C"),
        RX_EYE_SCANMODE                         =>     ("00"),

       -------------------------PRBS Detection-----------------------
        RXPRBSERR_LOOPBACK                      =>     ('0'),

       ------------------Comma Detection and Alignment---------------
        ALIGN_COMMA_WORD                        =>     (2),
        COMMA_10B_ENABLE                        =>     ("1111111111"),
        COMMA_DOUBLE                            =>     (FALSE),
        DEC_MCOMMA_DETECT                       =>     (TRUE),
        DEC_PCOMMA_DETECT                       =>     (TRUE),
        DEC_VALID_COMMA_ONLY                    =>     (FALSE),
        MCOMMA_10B_VALUE                        =>     ("1010000011"),
        MCOMMA_DETECT                           =>     (TRUE),
        PCOMMA_10B_VALUE                        =>     ("0101111100"),
        PCOMMA_DETECT                           =>     (TRUE),
        RX_DECODE_SEQ_MATCH                     =>     (TRUE),
        RX_SLIDE_AUTO_WAIT                      =>     (5),
        RX_SLIDE_MODE                           =>     ("OFF"),
        SHOW_REALIGN_COMMA                      =>     (FALSE),

       -----------------RX Loss-of-sync State Machine----------------
        RX_LOS_INVALID_INCR                     =>     (8),
        RX_LOS_THRESHOLD                        =>     (128),
        RX_LOSS_OF_SYNC_FSM                     =>     (FALSE),

       -------------------------RX Gearbox---------------------------
        RXGEARBOX_USE                           =>     (FALSE),

       -------------RX Elastic Buffer and Phase alignment------------
        RX_BUFFER_USE                           =>     (TRUE),
        RX_EN_IDLE_RESET_BUF                    =>     (TRUE),
        RX_EN_MODE_RESET_BUF                    =>     (TRUE),
        RX_EN_RATE_RESET_BUF                    =>     (TRUE),
        RX_EN_REALIGN_RESET_BUF                 =>     (FALSE),
        RX_EN_REALIGN_RESET_BUF2                =>     (FALSE),
        RX_FIFO_ADDR_MODE                       =>     ("FULL"),
        RX_IDLE_HI_CNT                          =>     ("1000"),
        RX_IDLE_LO_CNT                          =>     ("0000"),
        RX_XCLK_SEL                             =>     ("RXREC"),
        RX_DLYALIGN_CTRINC                      =>     ("1110"),
        RX_DLYALIGN_EDGESET                     =>     ("00010"),
        RX_DLYALIGN_LPFINC                      =>     ("1110"),
        RX_DLYALIGN_MONSEL                      =>     ("000"),
        RX_DLYALIGN_OVRDSETTING                 =>     ("10000000"),

       ------------------------Clock Correction----------------------
        CLK_COR_ADJ_LEN                         =>     (4),
        CLK_COR_DET_LEN                         =>     (4),
        CLK_COR_INSERT_IDLE_FLAG                =>     (FALSE),
        CLK_COR_KEEP_IDLE                       =>     (FALSE),
        CLK_COR_MAX_LAT                         =>     (48),
        CLK_COR_MIN_LAT                         =>     (36),
        CLK_COR_PRECEDENCE                      =>     (TRUE),
        CLK_COR_REPEAT_WAIT                     =>     (0),
        CLK_COR_SEQ_1_1                         =>     ("1101111100"),
        CLK_COR_SEQ_1_2                         =>     ("1000111100"),
        CLK_COR_SEQ_1_3                         =>     ("1000111100"),
        CLK_COR_SEQ_1_4                         =>     ("1000111100"),
        CLK_COR_SEQ_1_ENABLE                    =>     ("1111"),
        CLK_COR_SEQ_2_1                         =>     ("0100000000"),
        CLK_COR_SEQ_2_2                         =>     ("0100000000"),
        CLK_COR_SEQ_2_3                         =>     ("0100000000"),
        CLK_COR_SEQ_2_4                         =>     ("0100000000"),
        CLK_COR_SEQ_2_ENABLE                    =>     ("1111"),
        CLK_COR_SEQ_2_USE                       =>     (FALSE),
        CLK_CORRECT_USE                         =>     (TRUE),

       ------------------------Channel Bonding----------------------
        CHAN_BOND_1_MAX_SKEW                    =>     (1),
        CHAN_BOND_2_MAX_SKEW                    =>     (1),
        CHAN_BOND_KEEP_ALIGN                    =>     (FALSE),
        CHAN_BOND_SEQ_1_1                       =>     ("0000000000"),
        CHAN_BOND_SEQ_1_2                       =>     ("0000000000"),
        CHAN_BOND_SEQ_1_3                       =>     ("0000000000"),
        CHAN_BOND_SEQ_1_4                       =>     ("0000000000"),
        CHAN_BOND_SEQ_1_ENABLE                  =>     ("1111"),
        CHAN_BOND_SEQ_2_1                       =>     ("0000000000"),
        CHAN_BOND_SEQ_2_2                       =>     ("0000000000"),
        CHAN_BOND_SEQ_2_3                       =>     ("0000000000"),
        CHAN_BOND_SEQ_2_4                       =>     ("0000000000"),
        CHAN_BOND_SEQ_2_CFG                     =>     ("00000"),
        CHAN_BOND_SEQ_2_ENABLE                  =>     ("1111"),
        CHAN_BOND_SEQ_2_USE                     =>     (FALSE),
        CHAN_BOND_SEQ_LEN                       =>     (1),
        PCI_EXPRESS_MODE                        =>     (FALSE),

       -------------RX Attributes for PCI Express/SATA/SAS----------
        SAS_MAX_COMSAS                          =>     (52),
        SAS_MIN_COMSAS                          =>     (40),
        SATA_BURST_VAL                          =>     ("100"),
        SATA_IDLE_VAL                           =>     ("100"),
        SATA_MAX_BURST                          =>     (7),
        SATA_MAX_INIT                           =>     (22),
        SATA_MAX_WAKE                           =>     (7),
        SATA_MIN_BURST                          =>     (4),
        SATA_MIN_INIT                           =>     (12),
        SATA_MIN_WAKE                           =>     (4),
        TRANS_TIME_FROM_P2                      =>     (x"03c"),
        TRANS_TIME_NON_P2                       =>     (x"19"),
        TRANS_TIME_RATE                         =>     (x"ff"),
        TRANS_TIME_TO_P2                        =>     (x"064")


     )
     port map
     (
                      ------------------------ Loopback and Powerdown Ports ----------------------

        LOOPBACK(0)                    =>      '0',
        LOOPBACK(1)                    =>      gtpLoopback,
        LOOPBACK(2)                    =>      '0',
        RXPOWERDOWN                     =>      (others=>'0'),
        TXPOWERDOWN                     =>      (others=>'0'),
        -------------- Receive Ports - 64b66b and 64b67b Gearbox Ports -------------
        RXDATAVALID                     =>      open,
        RXGEARBOXSLIP                   =>      '0',
        RXHEADER                        =>      open,
        RXHEADERVALID                   =>      open,
        RXSTARTOFSEQ                    =>      open,
        ----------------------- Receive Ports - 8b10b Decoder ----------------------
        RXCHARISCOMMA(3 downto 2)       =>      open,
        RXCHARISCOMMA(1 downto 0)       =>      open,
        RXCHARISK(3 downto 2)           =>      open,
        RXCHARISK(1 downto 0)           =>      phyRxDataK,
        RXDEC8B10BUSE                   =>      '1',
        RXDISPERR(3 downto 2)           =>      open,
        RXDISPERR(1 downto 0)           =>      phyRxDispErr,
        RXNOTINTABLE(3 downto 2)        =>      open,
        RXNOTINTABLE(1 downto 0)        =>      phyRxDecErr,
        RXRUNDISP                       =>      open,
        USRCODEERR                      =>      '0',
        ------------------- Receive Ports - Channel Bonding Ports ------------------
        RXCHANBONDSEQ                   =>      open,
        RXCHBONDI                       =>      (Others => '0'),
        RXCHBONDLEVEL                   =>      (Others => '0'),
        RXCHBONDMASTER                  =>      '0',
        RXCHBONDO                       =>      open,
        RXCHBONDSLAVE                   =>      '0',
        RXENCHANSYNC                    =>      '0',
        ------------------- Receive Ports - Clock Correction Ports -----------------
        RXCLKCORCNT                     =>      open,
        --------------- Receive Ports - Comma Detection and Alignment --------------
        RXBYTEISALIGNED                 =>      open,
        RXBYTEREALIGN                   =>      open,
        RXCOMMADET                      =>      open,
        RXCOMMADETUSE                   =>      '1',
        RXENMCOMMAALIGN                 =>      '1',
        RXENPCOMMAALIGN                 =>      '1',
        RXSLIDE                         =>      '0',
        ----------------------- Receive Ports - PRBS Detection ---------------------
        PRBSCNTRESET                    =>      '0',
        RXENPRBSTST                     =>      (Others => '0'),
        RXPRBSERR                       =>      open,
        ------------------- Receive Ports - RX Data Path interface -----------------
        RXDATA                          =>      phyRxData,
        RXRECCLK                        =>      gtpRxRecClk,
        RXRECCLKPCS                     =>      open,
        RXRESET                         =>      phyRxReset,
        RXUSRCLK                        =>      '0',
        RXUSRCLK2                       =>      pgpClk,
        ------------ Receive Ports - RX Decision Feedback Equalizer(DFE) -----------
        DFECLKDLYADJ                    =>      (Others => '0'),
        DFECLKDLYADJMON                 =>      open,
        DFEDLYOVRD                      =>      '0',
        DFEEYEDACMON                    =>      open,
        DFESENSCAL                      =>      open,
        DFETAP1                         =>      (Others => '0'),
        DFETAP1MONITOR                  =>      open,
        DFETAP2                         =>      (Others => '0'),
        DFETAP2MONITOR                  =>      open,
        DFETAP3                         =>      (Others => '0'),
        DFETAP3MONITOR                  =>      open,
        DFETAP4                         =>      (Others => '0'),
        DFETAP4MONITOR                  =>      open,
        DFETAPOVRD                      =>      '1',
        ------- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
        GATERXELECIDLE                  =>      '1',
        IGNORESIGDET                    =>      '1',
        RXCDRRESET                      =>      phyRxCdrReset,
        RXELECIDLE                      =>      phyRxElecIdle,
        RXEQMIX                         =>      "0000000111",
        RXN                             =>      gtpRxN,
        RXP                             =>      gtpRxP,
        -------- Receive Ports - RX Elastic Buffer and Phase Alignment Ports -------
        RXBUFRESET                      =>      '0',
        RXBUFSTATUS                     =>      phyRxBuffStatus,
        RXCHANISALIGNED                 =>      open,
        RXCHANREALIGN                   =>      open,
        RXDLYALIGNDISABLE               =>      '0',
        RXDLYALIGNMONENB                =>      '0',
        RXDLYALIGNMONITOR               =>      open,
        RXDLYALIGNOVERRIDE              =>      '1',
        RXDLYALIGNRESET                 =>      '0',
        RXDLYALIGNSWPPRECURB            =>      '1',
        RXDLYALIGNUPDSW                 =>      '0',
        RXENPMAPHASEALIGN               =>      '0',
        RXPMASETPHASE                   =>      '0',
        RXSTATUS                        =>      open,
        --------------- Receive Ports - RX Loss-of-sync State Machine --------------
        RXLOSSOFSYNC                    =>      open,
        ---------------------- Receive Ports - RX Oversampling ---------------------
        RXENSAMPLEALIGN                 =>      '0',
        RXOVERSAMPLEERR                 =>      open,
        ------------------------ Receive Ports - RX PLL Ports ----------------------
        GREFCLKRX                       =>      '0',
        GTXRXRESET                      =>      pgpReset,
        MGTREFCLKRX                     =>      gtpClkIn_v,
        NORTHREFCLKRX                   =>      (Others => '0'),
        PERFCLKRX                       =>      '0',
        PLLRXRESET                      =>      '0',
        RXPLLLKDET                      =>      RXphyLockDetect,
        RXPLLLKDETEN                    =>      '1',
        RXPLLPOWERDOWN                  =>      '0',
        RXPLLREFSELDY                   =>      (Others => '0'),
        RXRATE                          =>      (Others => '0'),
        RXRATEDONE                      =>      open,
        RXRESETDONE                     =>      RXphyRstDone,
        SOUTHREFCLKRX                   =>      (Others => '0'),
        -------------- Receive Ports - RX Pipe Control for PCI Express -------------
        PHYSTATUS                       =>      open,
        RXVALID                         =>      open,
        ----------------- Receive Ports - RX Polarity Control Ports ----------------
        RXPOLARITY                      =>      phyRxPolarity(0),
        --------------------- Receive Ports - RX Ports for SATA --------------------
        COMINITDET                      =>      open,
        COMSASDET                       =>      open,
        COMWAKEDET                      =>      open,
        ------------- Shared Ports - Dynamic Reconfiguration Port (DRP) ------------
        DADDR                           =>      (Others => '0'),
        DCLK                            =>      '0',
        DEN                             =>      '0',
        DI                              =>      (Others => '0'),
        DRDY                            =>      open,
        DRPDO                           =>      open,
        DWE                             =>      '0',
        -------------- Transmit Ports - 64b66b and 64b67b Gearbox Ports ------------
        TXGEARBOXREADY                  =>      open,
        TXHEADER                        =>      (Others => '0'),
        TXSEQUENCE                      =>      (Others => '0'),
        TXSTARTSEQ                      =>      '0',
        ---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
        TXBYPASS8B10B                   =>      (Others => '0'),
        TXCHARDISPMODE                  =>      (Others => '0'),
        TXCHARDISPVAL                   =>      (Others => '0'),
        TXCHARISK(3 downto 2)           =>      (Others => '0'),
        TXCHARISK(1 downto 0)           =>      phyTxDataK,
        TXENC8B10BUSE                   =>      '1',
        TXKERR                          =>      open,
        TXRUNDISP                       =>      open,
        ------------------------- Transmit Ports - GTX Ports -----------------------
        GTXTEST                         =>      "1000000000000",
        MGTREFCLKFAB                    =>      open,
        TSTCLK0                         =>      '0',
        TSTCLK1                         =>      '0',
        TSTIN                           =>      "11111111111111111111",
        TSTOUT                          =>      open,
        ------------------ Transmit Ports - TX Data Path interface -----------------
        TXDATA                          =>      phyTxData,
        TXOUTCLK                        =>      gtpRefClkOut,
        TXOUTCLKPCS                     =>      open,
        TXRESET                         =>      phyTxReset,
        TXUSRCLK                        =>      '0',
        TXUSRCLK2                       =>      pgpClk,
        ---------------- Transmit Ports - TX Driver and OOB signaling --------------
        TXBUFDIFFCTRL                   =>      "100",
        TXDIFFCTRL                      =>      "0000",
        TXINHIBIT                       =>      '0',
        TXN                             =>      gtpTxN,
        TXP                             =>      gtpTxP,
        TXPOSTEMPHASIS                  =>      "00000",
        --------------- Transmit Ports - TX Driver and OOB signalling --------------
        TXPREEMPHASIS                   =>      "0000",
        ----------- Transmit Ports - TX Elastic Buffer and Phase Alignment ---------
        TXBUFSTATUS                     =>      phyTxBuffStatus,
        -------- Transmit Ports - TX Elastic Buffer and Phase Alignment Ports ------
        TXDLYALIGNDISABLE               =>      '1',
        TXDLYALIGNMONENB                =>      '0',
        TXDLYALIGNMONITOR               =>      open,
        TXDLYALIGNOVERRIDE              =>      '0',
        TXDLYALIGNRESET                 =>      '0',
        TXDLYALIGNUPDSW                 =>      '1',
        TXENPMAPHASEALIGN               =>      '0',
        TXPMASETPHASE                   =>      '0',
        ----------------------- Transmit Ports - TX PLL Ports ----------------------
        GREFCLKTX                       =>      '0',
        GTXTXRESET                      =>      pgpReset,
        MGTREFCLKTX                     =>      gtpClkIn_v,
        NORTHREFCLKTX                   =>      (Others => '0'),
        PERFCLKTX                       =>      '0',
        PLLTXRESET                      =>      '0',
        SOUTHREFCLKTX                   =>      (Others => '0'),
        TXPLLLKDET                      =>      TXphyLockDetect,
        TXPLLLKDETEN                    =>      '1',
        TXPLLPOWERDOWN                  =>      '0',
        TXPLLREFSELDY                   =>      (Others => '0'),
        TXRATE                          =>      (Others => '0'),
        TXRATEDONE                      =>      open,
        TXRESETDONE                     =>      TXphyRstDone,
        --------------------- Transmit Ports - TX PRBS Generator -------------------
        TXENPRBSTST                     =>      (Others => '0'),
        TXPRBSFORCEERR                  =>      '0',
        -------------------- Transmit Ports - TX Polarity Control ------------------
        TXPOLARITY                      =>      '0',
        ----------------- Transmit Ports - TX Ports for PCI Express ----------------
        TXDEEMPH                        =>      '0',
        TXDETECTRX                      =>      '0',
        TXELECIDLE                      =>      '0',
        TXMARGIN                        =>      (Others => '0'),
        TXPDOWNASYNCH                   =>      '0',
        TXSWING                         =>      '0',
        --------------------- Transmit Ports - TX Ports for SATA -------------------
        COMFINISH                       =>      open,
        TXCOMINIT                       =>      '0',
        TXCOMSAS                        =>      '0',
        TXCOMWAKE                       =>      '0'

     );
end Pgp2GtxV616;

