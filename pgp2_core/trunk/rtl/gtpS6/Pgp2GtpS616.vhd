-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, Spartan 6 GTP Wrapper
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2GtpS616.vhd
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
use work.Pgp2GtpS6Package.all;
use work.Pgp2CorePackage.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;


entity Pgp2GtpS616 is
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

end Pgp2GtpS616;


-- Define architecture
architecture Pgp2GtpS616 of Pgp2GtpS616 is

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
         phyRxData         => phyRxData(15 downto 0),
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
         phyTxData         => phyTxData(15 downto 0),
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
   Tx_CRC: CRC32_S6
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
   Rx_CRC: CRC32_S6
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
   U_Pgp2GtpS6RxRst: Pgp2GtpS6RxRst
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
   U_Pgp2GtpS6TxRst: Pgp2GtpS6TxRst
      port map (
         gtpTxClk          => pgpClk,
         gtpTxRst          => intTxRst,
         gtpTxReady        => phyTxReady,
         gtpLockDetect     => phyLockDetect,
         gtpTxBuffStatus   => phyTxBuffStatus,
         gtpRstDone        => phyRstDone,
         gtpTxReset        => phyTxReset
      );

    ----------------------------- GTPA1_DUAL Instance  S6 --------------------------
    gtpa1_dual_s6_156:GTPA1_DUAL
    generic map
    (

        --_______________________ Simulation-Only Attributes ___________________

        SIM_RECEIVER_DETECT_PASS    =>      (TRUE),
        SIM_TX_ELEC_IDLE_LEVEL      =>      ("Z"),
        SIM_VERSION                 =>      ("2.0"),

        SIM_REFCLK0_SOURCE          =>      ("000"),
        SIM_REFCLK1_SOURCE          =>      ("000"),

        SIM_GTPRESET_SPEEDUP        =>      1,
        CLK25_DIVIDER_0             =>      10,
        CLK25_DIVIDER_1             =>      10,
        PLL_DIVSEL_FB_0             =>      2,
        PLL_DIVSEL_FB_1             =>      2,
        PLL_DIVSEL_REF_0            =>      1,
        PLL_DIVSEL_REF_1            =>      1,



       --PLL Attributes
        CLKINDC_B_0                             =>     (TRUE),
        CLKRCV_TRST_0                           =>     (TRUE),
        OOB_CLK_DIVIDER_0                       =>     (6),
        PLL_COM_CFG_0                           =>     (x"21680a"),
        PLL_CP_CFG_0                            =>     (x"00"),
        PLL_RXDIVSEL_OUT_0                      =>     (1),
        PLL_SATA_0                              =>     (FALSE),
        PLL_SOURCE_0                            =>     ("PLL0"),
        PLL_TXDIVSEL_OUT_0                      =>     (1),
        PLLLKDET_CFG_0                          =>     ("111"),

       --
        CLKINDC_B_1                             =>     (TRUE),
        CLKRCV_TRST_1                           =>     (TRUE),
        OOB_CLK_DIVIDER_1                       =>     (6),
        PLL_COM_CFG_1                           =>     (x"21680a"),
        PLL_CP_CFG_1                            =>     (x"00"),
        PLL_RXDIVSEL_OUT_1                      =>     (1),
        PLL_SATA_1                              =>     (FALSE),
        PLL_SOURCE_1                            =>     ("PLL1"),
        PLL_TXDIVSEL_OUT_1                      =>     (1),
        PLLLKDET_CFG_1                          =>     ("111"),
        PMA_COM_CFG_EAST                        =>     (x"000008000"),
        PMA_COM_CFG_WEST                        =>     (x"00000a000"),
        TST_ATTR_0                              =>     (x"00000000"),
        TST_ATTR_1                              =>     (x"00000000"),

       --TX Interface Attributes
        CLK_OUT_GTP_SEL_0                       =>     ("REFCLKPLL0"),
        TX_TDCC_CFG_0                           =>     ("11"),
        CLK_OUT_GTP_SEL_1                       =>     ("REFCLKPLL1"),
        TX_TDCC_CFG_1                           =>     ("11"),

       --TX Buffer and Phase Alignment Attributes
        PMA_TX_CFG_0                            =>     (x"00082"), -- wizard
        TX_BUFFER_USE_0                         =>     (TRUE),
        TX_XCLK_SEL_0                           =>     ("TXOUT"),
        TXRX_INVERT_0                           =>     ("011"),   -- from wizard
        PMA_TX_CFG_1                            =>     (x"00082"),
        TX_BUFFER_USE_1                         =>     (TRUE),
        TX_XCLK_SEL_1                           =>     ("TXOUT"),
        TXRX_INVERT_1                           =>     ("011"),

       --TX Driver and OOB signalling Attributes
        CM_TRIM_0                               =>     ("00"),
        TX_IDLE_DELAY_0                         =>     ("011"),
        CM_TRIM_1                               =>     ("00"),
        TX_IDLE_DELAY_1                         =>     ("011"),

       --TX PIPE/SATA Attributes
        COM_BURST_VAL_0                         =>     ("1111"),
        COM_BURST_VAL_1                         =>     ("1111"),

       --RX Driver,OOB signalling,Coupling and Eq,CDR Attributes
        AC_CAP_DIS_0                            =>     (TRUE),
        OOBDETECT_THRESHOLD_0                   =>     ("110"),
        PMA_CDR_SCAN_0                          =>     (x"6404040"),
        PMA_RX_CFG_0                            =>     (x"05ce089"),
        PMA_RXSYNC_CFG_0                        =>     (x"00"),
        RCV_TERM_GND_0                          =>     (FALSE),
        RCV_TERM_VTTRX_0                        =>     (FALSE),
        RXEQ_CFG_0                              =>     ("01111011"),
        TERMINATION_CTRL_0                      =>     ("10100"),
        TERMINATION_OVRD_0                      =>     (FALSE),
        TX_DETECT_RX_CFG_0                      =>     (x"1832"),

        AC_CAP_DIS_1                            =>     (TRUE),
        OOBDETECT_THRESHOLD_1                   =>     ("110"),
        PMA_CDR_SCAN_1                          =>     (x"6404040"),
        PMA_RX_CFG_1                            =>     (x"05ce089"),
        PMA_RXSYNC_CFG_1                        =>     (x"00"),
        RCV_TERM_GND_1                          =>     (FALSE),
        RCV_TERM_VTTRX_1                        =>     (FALSE),
        RXEQ_CFG_1                              =>     ("01111011"),
        TERMINATION_CTRL_1                      =>     ("10100"),
        TERMINATION_OVRD_1                      =>     (FALSE),
        TX_DETECT_RX_CFG_1                      =>     (x"1832"),

       --PRBS Detection Attributes
        RXPRBSERR_LOOPBACK_0                    =>     ('0'),
        RXPRBSERR_LOOPBACK_1                    =>     ('0'),

       --Comma Detection and Alignment Attributes
        ALIGN_COMMA_WORD_0                      =>     (2),
        COMMA_10B_ENABLE_0                      =>     ("1111111111"),
        DEC_MCOMMA_DETECT_0                     =>     (FALSE),
        DEC_PCOMMA_DETECT_0                     =>     (FALSE),
        DEC_VALID_COMMA_ONLY_0                  =>     (FALSE),
        MCOMMA_10B_VALUE_0                      =>     ("1010000011"),
        MCOMMA_DETECT_0                         =>     (TRUE),
        PCOMMA_10B_VALUE_0                      =>     ("0101111100"),
        PCOMMA_DETECT_0                         =>     (TRUE),
        RX_SLIDE_MODE_0                         =>     ("PCS"),
        ALIGN_COMMA_WORD_1                      =>     (2),
        COMMA_10B_ENABLE_1                      =>     ("1111111111"),
        DEC_MCOMMA_DETECT_1                     =>     (FALSE),
        DEC_PCOMMA_DETECT_1                     =>     (FALSE),
        DEC_VALID_COMMA_ONLY_1                  =>     (FALSE),
        MCOMMA_10B_VALUE_1                      =>     ("1010000011"),
        MCOMMA_DETECT_1                         =>     (TRUE),
        PCOMMA_10B_VALUE_1                      =>     ("0101111100"),
        PCOMMA_DETECT_1                         =>     (TRUE),
        RX_SLIDE_MODE_1                         =>     ("PCS"),

       --RX Loss-of-sync State Machine Attributes
        RX_LOS_INVALID_INCR_0                   =>     (8),
        RX_LOS_THRESHOLD_0                      =>     (128),
        RX_LOSS_OF_SYNC_FSM_0                   =>     (FALSE),
        RX_LOS_INVALID_INCR_1                   =>     (8),
        RX_LOS_THRESHOLD_1                      =>     (128),
        RX_LOSS_OF_SYNC_FSM_1                   =>     (FALSE),

       --RX Elastic Buffer and Phase alignment Attributes
        RX_BUFFER_USE_0                         =>     (TRUE),
        RX_EN_IDLE_RESET_BUF_0                  =>     (TRUE),
        RX_IDLE_HI_CNT_0                        =>     ("1000"),
        RX_IDLE_LO_CNT_0                        =>     ("0000"),
        RX_XCLK_SEL_0                           =>     ("RXREC"),
        RX_BUFFER_USE_1                         =>     (TRUE),
        RX_EN_IDLE_RESET_BUF_1                  =>     (TRUE),
        RX_IDLE_HI_CNT_1                        =>     ("1000"),
        RX_IDLE_LO_CNT_1                        =>     ("0000"),
        RX_XCLK_SEL_1                           =>     ("RXREC"),

       --Clock Correction Attributes
        CLK_COR_ADJ_LEN_0                       =>     (4),
        CLK_COR_DET_LEN_0                       =>     (4),
        CLK_COR_INSERT_IDLE_FLAG_0              =>     (FALSE),
        CLK_COR_KEEP_IDLE_0                     =>     (FALSE),
        CLK_COR_MAX_LAT_0                       =>     (48),
        CLK_COR_MIN_LAT_0                       =>     (36),
        CLK_COR_PRECEDENCE_0                    =>     (TRUE),
        CLK_COR_REPEAT_WAIT_0                   =>     (0),
        CLK_COR_SEQ_1_1_0                       =>     ("0110111100"),
        CLK_COR_SEQ_1_2_0                       =>     ("0100011100"),
        CLK_COR_SEQ_1_3_0                       =>     ("0100011100"),
        CLK_COR_SEQ_1_4_0                       =>     ("0100011100"),
        CLK_COR_SEQ_1_ENABLE_0                  =>     ("1111"),
        CLK_COR_SEQ_2_1_0                       =>     ("0100000000"),
        CLK_COR_SEQ_2_2_0                       =>     ("0000000000"),
        CLK_COR_SEQ_2_3_0                       =>     ("0000000000"),
        CLK_COR_SEQ_2_4_0                       =>     ("0000000000"),
        CLK_COR_SEQ_2_ENABLE_0                  =>     ("0000"),
        CLK_COR_SEQ_2_USE_0                     =>     (FALSE),
        CLK_CORRECT_USE_0                       =>     (TRUE),
        RX_DECODE_SEQ_MATCH_0                   =>     (TRUE),
        CLK_COR_ADJ_LEN_1                       =>     (4),
        CLK_COR_DET_LEN_1                       =>     (4),
        CLK_COR_INSERT_IDLE_FLAG_1              =>     (FALSE),
        CLK_COR_KEEP_IDLE_1                     =>     (FALSE),
        CLK_COR_MAX_LAT_1                       =>     (48),
        CLK_COR_MIN_LAT_1                       =>     (36),
        CLK_COR_PRECEDENCE_1                    =>     (TRUE),
        CLK_COR_REPEAT_WAIT_1                   =>     (0),
        CLK_COR_SEQ_1_1_1                       =>     ("0110111100"),
        CLK_COR_SEQ_1_2_1                       =>     ("0100011100"),
        CLK_COR_SEQ_1_3_1                       =>     ("0100011100"),
        CLK_COR_SEQ_1_4_1                       =>     ("0100000000"),
        CLK_COR_SEQ_1_ENABLE_1                  =>     ("1111"),
        CLK_COR_SEQ_2_1_1                       =>     ("0100000000"),
        CLK_COR_SEQ_2_2_1                       =>     ("0000000000"),
        CLK_COR_SEQ_2_3_1                       =>     ("0000000000"),
        CLK_COR_SEQ_2_4_1                       =>     ("0000000000"),
        CLK_COR_SEQ_2_ENABLE_1                  =>     ("0000"),
        CLK_COR_SEQ_2_USE_1                     =>     (FALSE),
        CLK_CORRECT_USE_1                       =>     (TRUE),
        RX_DECODE_SEQ_MATCH_1                   =>     (TRUE),

       --Channel Bonding Attributes
        CHAN_BOND_1_MAX_SKEW_0                  =>     (1),
        CHAN_BOND_2_MAX_SKEW_0                  =>     (1),
        CHAN_BOND_KEEP_ALIGN_0                  =>     (FALSE),
        CHAN_BOND_SEQ_1_1_0                     =>     ("0000000000"),
        CHAN_BOND_SEQ_1_2_0                     =>     ("0000000000"),
        CHAN_BOND_SEQ_1_3_0                     =>     ("0000000000"),
        CHAN_BOND_SEQ_1_4_0                     =>     ("0000000000"),
        CHAN_BOND_SEQ_1_ENABLE_0                =>     ("0000"),
        CHAN_BOND_SEQ_2_1_0                     =>     ("0000000000"),
        CHAN_BOND_SEQ_2_2_0                     =>     ("0000000000"),
        CHAN_BOND_SEQ_2_3_0                     =>     ("0000000000"),
        CHAN_BOND_SEQ_2_4_0                     =>     ("0000000000"),
        CHAN_BOND_SEQ_2_ENABLE_0                =>     ("0000"),
        CHAN_BOND_SEQ_2_USE_0                   =>     (FALSE),
        CHAN_BOND_SEQ_LEN_0                     =>     (1),
        RX_EN_MODE_RESET_BUF_0                  =>     (TRUE),
        CHAN_BOND_1_MAX_SKEW_1                  =>     (1),
        CHAN_BOND_2_MAX_SKEW_1                  =>     (1),
        CHAN_BOND_KEEP_ALIGN_1                  =>     (FALSE),
        CHAN_BOND_SEQ_1_1_1                     =>     ("0000000000"),
        CHAN_BOND_SEQ_1_2_1                     =>     ("0000000000"),
        CHAN_BOND_SEQ_1_3_1                     =>     ("0000000000"),
        CHAN_BOND_SEQ_1_4_1                     =>     ("0000000000"),
        CHAN_BOND_SEQ_1_ENABLE_1                =>     ("0000"),
        CHAN_BOND_SEQ_2_1_1                     =>     ("0000000000"),
        CHAN_BOND_SEQ_2_2_1                     =>     ("0000000000"),
        CHAN_BOND_SEQ_2_3_1                     =>     ("0000000000"),
        CHAN_BOND_SEQ_2_4_1                     =>     ("0000000000"),
        CHAN_BOND_SEQ_2_ENABLE_1                =>     ("0000"),
        CHAN_BOND_SEQ_2_USE_1                   =>     (FALSE),
        CHAN_BOND_SEQ_LEN_1                     =>     (1),
        RX_EN_MODE_RESET_BUF_1                  =>     (TRUE),

       --RX PCI Express Attributes
        CB2_INH_CC_PERIOD_0                     =>     (8),
        CDR_PH_ADJ_TIME_0                       =>     ("01010"),
        PCI_EXPRESS_MODE_0                      =>     (FALSE),
        RX_EN_IDLE_HOLD_CDR_0                   =>     (FALSE),
        RX_EN_IDLE_RESET_FR_0                   =>     (TRUE),
        RX_EN_IDLE_RESET_PH_0                   =>     (TRUE),
        RX_STATUS_FMT_0                         =>     ("PCIE"),
        TRANS_TIME_FROM_P2_0                    =>     (x"03c"),
        TRANS_TIME_NON_P2_0                     =>     (x"19"),
        TRANS_TIME_TO_P2_0                      =>     (x"064"),
        CB2_INH_CC_PERIOD_1                     =>     (8),
        CDR_PH_ADJ_TIME_1                       =>     ("01010"),
        PCI_EXPRESS_MODE_1                      =>     (FALSE),
        RX_EN_IDLE_HOLD_CDR_1                   =>     (FALSE),
        RX_EN_IDLE_RESET_FR_1                   =>     (TRUE),
        RX_EN_IDLE_RESET_PH_1                   =>     (TRUE),
        RX_STATUS_FMT_1                         =>     ("PCIE"),
        TRANS_TIME_FROM_P2_1                    =>     (x"03c"),
        TRANS_TIME_NON_P2_1                     =>     (x"19"),
        TRANS_TIME_TO_P2_1                      =>     (x"064"),

       --RX SATA Attributes
        SATA_BURST_VAL_0                        =>     ("100"),
        SATA_IDLE_VAL_0                         =>     ("100"),
        SATA_MAX_BURST_0                        =>     (7),
        SATA_MAX_INIT_0                         =>     (22),
        SATA_MAX_WAKE_0                         =>     (7),
        SATA_MIN_BURST_0                        =>     (4),
        SATA_MIN_INIT_0                         =>     (12),
        SATA_MIN_WAKE_0                         =>     (4),
        SATA_BURST_VAL_1                        =>     ("100"),
        SATA_IDLE_VAL_1                         =>     ("100"),
        SATA_MAX_BURST_1                        =>     (7),
        SATA_MAX_INIT_1                         =>     (22),
        SATA_MAX_WAKE_1                         =>     (7),
        SATA_MIN_BURST_1                        =>     (4),
        SATA_MIN_INIT_1                         =>     (12),
        SATA_MIN_WAKE_1                         =>     (4)


    )
    port map
    (
        ------------------------ Loopback and Powerdown Ports ----------------------
        LOOPBACK0(0)                    =>      '0',
        LOOPBACK0(1)                    =>      gtpLoopback,
        LOOPBACK0(2)                    =>      '0',
        LOOPBACK1                       =>      (others=>'0'),
        RXPOWERDOWN0                    =>      (others=>'0'),
        RXPOWERDOWN1                    =>      (others=>'0'),
        TXPOWERDOWN0                    =>      (others=>'0'),
        TXPOWERDOWN1                    =>      (others=>'0'),
        --------------------------------- PLL Ports --------------------------------
        CLK00                           =>      gtpClkIn,
        CLK01                           =>      '0',
        CLK10                           =>      '0',
        CLK11                           =>      '0',
        CLKINEAST0                      =>      '0',
        CLKINEAST1                      =>      '0',
        CLKINWEST0                      =>      '0',
        CLKINWEST1                      =>      '0',
        GCLK00                          =>      '0',
        GCLK01                          =>      '0',
        GCLK10                          =>      '0',
        GCLK11                          =>      '0',
        GTPRESET0                       =>      pgpReset,
        GTPRESET1                       =>      pgpReset,
        GTPTEST0                        =>      "00010000",  -- Reserved
        GTPTEST1                        =>      "00010000",  -- Reserved
        INTDATAWIDTH0                   =>      '1',
        INTDATAWIDTH1                   =>      '1',
        PLLCLK00                        =>      '0',
        PLLCLK01                        =>      '0',
        PLLCLK10                        =>      '0',
        PLLCLK11                        =>      '0',
        PLLLKDET0                       =>      phyLockDetect,
        PLLLKDET1                       =>      open,
        PLLLKDETEN0                     =>      '1',
        PLLLKDETEN1                     =>      '1',
        PLLPOWERDOWN0                   =>      '0',
        PLLPOWERDOWN1                   =>      '0',
        REFCLKOUT0                      =>      open,   -- Must be open
        REFCLKOUT1                      =>      open,   -- Must be open
        REFCLKPLL0                      =>      open,   -- Must be open
        REFCLKPLL1                      =>      open,   -- Must be open
        REFCLKPWRDNB0                   =>      '1',
        REFCLKPWRDNB1                   =>      '1',
        REFSELDYPLL0                    =>      (others=>'0'),
        REFSELDYPLL1                    =>      (others=>'0'),
        RESETDONE0                      =>      phyRstDone,
        RESETDONE1                      =>      open,
        TSTCLK0                         =>      '0',
        TSTCLK1                         =>      '0',
        TSTIN0                          =>      (others=>'0'),
        TSTIN1                          =>      (others=>'0'),
        TSTOUT0                         =>      open,
        TSTOUT1                         =>      open,
        ----------------------- Receive Ports - 8b10b Decoder ----------------------
        RXCHARISCOMMA0                  =>      open,
        RXCHARISCOMMA1                  =>      open,
        RXCHARISK0(3 downto 2)          =>      open,
        RXCHARISK0(1 downto 0)          =>      phyRxDataK,
        RXCHARISK1(3 downto 2)          =>      open,
        RXCHARISK1(1 downto 0)          =>      open,
        RXDEC8B10BUSE0                  =>      '1',
        RXDEC8B10BUSE1                  =>      '1',
        RXDISPERR0(3 downto 2)          =>      open,
        RXDISPERR0(1 downto 0)          =>      phyRxDispErr,
        RXDISPERR1(3 downto 2)          =>      open,
        RXDISPERR1(1 downto 0)          =>      open,
        RXNOTINTABLE0(3 downto 2)       =>      open,
        RXNOTINTABLE0(1 downto 0)       =>      phyRxDecErr,
        RXNOTINTABLE1(3 downto 2)       =>      open,
        RXNOTINTABLE1(1 downto 0)       =>      open,
        RXRUNDISP0                      =>      open,
        RXRUNDISP1                      =>      open,
        USRCODEERR0                     =>      '0',
        USRCODEERR1                     =>      '0',
        ---------------------- Receive Ports - Channel Bonding ---------------------
        RXCHANBONDSEQ0                  =>      open,
        RXCHANBONDSEQ1                  =>      open,
        RXCHANISALIGNED0                =>      open,
        RXCHANISALIGNED1                =>      open,
        RXCHANREALIGN0                  =>      open,
        RXCHANREALIGN1                  =>      open,
        RXCHBONDI                       =>      (others=>'0'),
        RXCHBONDMASTER0                 =>      '0',
        RXCHBONDMASTER1                 =>      '0',
        RXCHBONDO                       =>      open,
        RXCHBONDSLAVE0                  =>      '0',
        RXCHBONDSLAVE1                  =>      '0',
        RXENCHANSYNC0                   =>      '0',
        RXENCHANSYNC1                   =>      '0',
        ---------------------- Receive Ports - Clock Correction --------------------
        RXCLKCORCNT0                    =>      open,
        RXCLKCORCNT1                    =>      open,
        --------------- Receive Ports - Comma Detection and Alignment --------------
        RXBYTEISALIGNED0                =>      open,
        RXBYTEISALIGNED1                =>      open,
        RXBYTEREALIGN0                  =>      open,
        RXBYTEREALIGN1                  =>      open,
        RXCOMMADET0                     =>      open,
        RXCOMMADET1                     =>      open,
        RXCOMMADETUSE0                  =>      '1',
        RXCOMMADETUSE1                  =>      '1',
        RXENMCOMMAALIGN0                =>      '1',
        RXENMCOMMAALIGN1                =>      '1',
        RXENPCOMMAALIGN0                =>      '1',
        RXENPCOMMAALIGN1                =>      '1',
        RXSLIDE0                        =>      '0',
        RXSLIDE1                        =>      '0',
        ----------------------- Receive Ports - PRBS Detection ---------------------
        PRBSCNTRESET0                   =>      '0',
        PRBSCNTRESET1                   =>      '0',
        RXENPRBSTST0                    =>      (others=>'0'),
        RXENPRBSTST1                    =>      (others=>'0'),
        RXPRBSERR0                      =>      open,
        RXPRBSERR1                      =>      open,
        ------------------- Receive Ports - RX Data Path interface -----------------
        RXDATA0                         =>      phyRxData,
        RXDATA1                         =>      open,
        RXDATAWIDTH0                    =>      "01",
        RXDATAWIDTH1                    =>      "01",
        RXRECCLK0                       =>      open,  -- keep open, use instead GTPCLKOUT0(1)
        RXRECCLK1                       =>      open,
        RXRESET0                        =>      phyRxReset,
        RXRESET1                        =>      '0',
        RXUSRCLK0                       =>      pgpClk2x,
        RXUSRCLK1                       =>      pgpClk2x,
        RXUSRCLK20                      =>      pgpClk,
        RXUSRCLK21                      =>      pgpClk,
        ------- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
        GATERXELECIDLE0                 =>      '0',
        GATERXELECIDLE1                 =>      '0',
        IGNORESIGDET0                   =>      '0',
        IGNORESIGDET1                   =>      '0',
        RCALINEAST                      =>      (others=>'0'),
        RCALINWEST                      =>      (others=>'0'),
        RCALOUTEAST                     =>      open,
        RCALOUTWEST                     =>      open,
        RXCDRRESET0                     =>      phyRxCdrReset,
        RXCDRRESET1                     =>      '0',
        RXELECIDLE0                     =>      phyRxElecIdle,
        RXELECIDLE1                     =>      open,
        RXEQMIX0                        =>      (others=>'0'),
        RXEQMIX1                        =>      (others=>'0'),
        RXN0                            =>      gtpRxN,
        RXN1                            =>      '0',
        RXP0                            =>      gtpRxP,
        RXP1                            =>      '0',
        ----------- Receive Ports - RX Elastic Buffer and Phase Alignment ----------
        RXBUFRESET0                     =>      '0',
        RXBUFRESET1                     =>      '0',
        RXBUFSTATUS0                    =>      phyRxBuffStatus,
        RXBUFSTATUS1                    =>      open,
        RXENPMAPHASEALIGN0              =>      '0',
        RXENPMAPHASEALIGN1              =>      '0',
        RXPMASETPHASE0                  =>      '0',
        RXPMASETPHASE1                  =>      '0',
        RXSTATUS0                       =>      open,
        RXSTATUS1                       =>      open,
        --------------- Receive Ports - RX Loss-of-sync State Machine --------------
        RXLOSSOFSYNC0                   =>      open,
        RXLOSSOFSYNC1                   =>      open,
        -------------- Receive Ports - RX Pipe Control for PCI Express -------------
        PHYSTATUS0                      =>      open,
        PHYSTATUS1                      =>      open,
        RXVALID0                        =>      open,
        RXVALID1                        =>      open,
        -------------------- Receive Ports - RX Polarity Control -------------------
        RXPOLARITY0                     =>      phyRxPolarity(0),
        RXPOLARITY1                     =>      '0',
        ------------- Shared Ports - Dynamic Reconfiguration Port (DRP) ------------
        DADDR                           =>      (others=>'0'),
        DCLK                            =>      '0',
        DEN                             =>      '0',
        DI                              =>      (others=>'0'),
        DRDY                            =>      open,
        DRPDO                           =>      open,
        DWE                             =>      '0',
        ---------------------------- TX/RX Datapath Ports --------------------------
        GTPCLKFBEAST                    =>      open,
        GTPCLKFBSEL0EAST                =>      "10",
        GTPCLKFBSEL0WEST                =>      "00",
        GTPCLKFBSEL1EAST                =>      "11",
        GTPCLKFBSEL1WEST                =>      "01",
        GTPCLKFBWEST                    =>      open,
        GTPCLKOUT0(0)                   =>      tmpRefClkOut,
        GTPCLKOUT0(1)                   =>      intRxRecClk,
        GTPCLKOUT1                      =>      open,
        ------------------- Transmit Ports - 8b10b Encoder Control -----------------
        TXBYPASS8B10B0                  =>      (others=>'0'),
        TXBYPASS8B10B1                  =>      (others=>'0'),
        TXCHARDISPMODE0                 =>      (others=>'0'),
        TXCHARDISPMODE1                 =>      (others=>'0'),
        TXCHARDISPVAL0                  =>      (others=>'0'),
        TXCHARDISPVAL1                  =>      (others=>'0'),
        TXCHARISK0(3 downto 2)          =>      (others=>'0'),
        TXCHARISK0(1 downto 0)          =>      phyTxDataK,
        TXCHARISK1(3 downto 2)          =>      (others=>'0'),
        TXCHARISK1(1 downto 0)          =>      (others=>'0'),
        TXENC8B10BUSE0                  =>      '1',
        TXENC8B10BUSE1                  =>      '1',
        TXKERR0(3 downto 2)             =>      open,
        TXKERR0(1 downto 0)             =>      txKerr,
        TXKERR1(3 downto 2)             =>      open,
        TXKERR1(1 downto 0)             =>      open,
        TXRUNDISP0                      =>      open,
        TXRUNDISP1                      =>      open,
        --------------- Transmit Ports - TX Buffer and Phase Alignment -------------
        TXBUFSTATUS0                    =>      phyTxBuffStatus,
        TXBUFSTATUS1                    =>      open,
        TXENPMAPHASEALIGN0              =>      '0',
        TXENPMAPHASEALIGN1              =>      '0',
        TXPMASETPHASE0                  =>      '0',
        TXPMASETPHASE1                  =>      '0',
        ------------------ Transmit Ports - TX Data Path interface -----------------
        TXDATA0                         =>      phyTxData,
        TXDATA1                         =>      (others=>'0'),
        TXDATAWIDTH0                    =>      "01",
        TXDATAWIDTH1                    =>      "01",
        TXOUTCLK0                       =>      open,
        TXOUTCLK1                       =>      open,
        TXRESET0                        =>      phyTxReset,
        TXRESET1                        =>      '0',
        TXUSRCLK0                       =>      pgpClk2x,
        TXUSRCLK1                       =>      pgpClk2x,
        TXUSRCLK20                      =>      pgpClk,
        TXUSRCLK21                      =>      pgpClk,
        --------------- Transmit Ports - TX Driver and OOB signalling --------------
        TXBUFDIFFCTRL0                  =>      "101",  -- do not change
        TXBUFDIFFCTRL1                  =>      "101",
        TXDIFFCTRL0                     =>      "0110",  -- 762mV
        TXDIFFCTRL1                     =>      "0110",
        TXINHIBIT0                      =>      '0',
        TXINHIBIT1                      =>      '0',
        TXN0                            =>      gtpTxN,
        TXN1                            =>      open,
        TXP0                            =>      gtpTxP,
        TXP1                            =>      open,
        TXPREEMPHASIS0                  =>      "011",  -- 4.5%
        TXPREEMPHASIS1                  =>      "011",
        --------------------- Transmit Ports - TX PRBS Generator -------------------
        TXENPRBSTST0                    =>      (others=>'0'),
        TXENPRBSTST1                    =>      (others=>'0'),
        TXPRBSFORCEERR0                 =>      '0',
        TXPRBSFORCEERR1                 =>      '0',
        -------------------- Transmit Ports - TX Polarity Control ------------------
        TXPOLARITY0                     =>      '0',
        TXPOLARITY1                     =>      '0',
        ----------------- Transmit Ports - TX Ports for PCI Express ----------------
        TXDETECTRX0                     =>      '0',
        TXDETECTRX1                     =>      '0',
        TXELECIDLE0                     =>      '0',
        TXELECIDLE1                     =>      '0',
        TXPDOWNASYNCH0                  =>      '0',
        TXPDOWNASYNCH1                  =>      '0',
        --------------------- Transmit Ports - TX Ports for SATA -------------------
        TXCOMSTART0                     =>      '0',
        TXCOMSTART1                     =>      '0',
        TXCOMTYPE0                      =>      '0',
        TXCOMTYPE1                      =>      '0'

    );
	
	    U_RefClkBuff_s6 : BUFIO2
    generic map
    (
        DIVIDE                          =>      1,
        DIVIDE_BYPASS                   =>      TRUE
    )
    port map
    (
        I                               =>      tmpRefClkOut,
        DIVCLK                          =>      gtpRefClkOut,
        IOCLK                           =>      open,
        SERDESSTROBE                    =>      open
    );
	 
    U_RecClkBuff_s6 : BUFIO2
    generic map
    (
        DIVIDE                          =>      1,
        DIVIDE_BYPASS                   =>      TRUE
    )
    port map
    (
        I                               =>      intRxRecClk,
        DIVCLK                          =>      gtpRxRecClk,
        IOCLK                           =>      open,
        SERDESSTROBE                    =>      open
    );
 
end Pgp2GtpS616;

