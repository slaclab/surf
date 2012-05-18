-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, GTX Wrapper
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2Gtx16.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 08/18/2009
-------------------------------------------------------------------------------
-- Description:
-- VHDL source file containing the PGP, GTX and CRC blocks.
-- This module also contains the logic to control the reset of the GTX.
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
use work.Pgp2GtxPackage.all;
use work.Pgp2CorePackage.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;


entity Pgp2Gtx16 is 
   generic (
      EnShortCells : integer := 1;         -- Enable short non-EOF cells
      VcInterleave : integer := 1          -- Interleave Frames
   );
   port (

      -- System clock, reset & control
      pgpClk            : in  std_logic;                     -- Pgp master clock
      pgpReset          : in  std_logic;                     -- Synchronous reset input
      pgpFlush          : in  std_logic;                     -- Frame sync flush

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
      vc0LocBuffAFull   : in  std_logic;                     -- Local buffer almost full
      vc0LocBuffFull    : in  std_logic;                     -- Local buffer full

      -- Frame Transmit Interface, VC 1
      vc1FrameTxValid   : in  std_logic;                     -- User frame data is valid
      vc1FrameTxReady   : out std_logic;                     -- PGP is ready
      vc1FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
      vc1FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
      vc1FrameTxEOFE    : in  std_logic;                     -- User frame data error
      vc1FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
      vc1LocBuffAFull   : in  std_logic;                     -- Local buffer almost full
      vc1LocBuffFull    : in  std_logic;                     -- Local buffer full

      -- Frame Transmit Interface, VC 2
      vc2FrameTxValid   : in  std_logic;                     -- User frame data is valid
      vc2FrameTxReady   : out std_logic;                     -- PGP is ready
      vc2FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
      vc2FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
      vc2FrameTxEOFE    : in  std_logic;                     -- User frame data error
      vc2FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
      vc2LocBuffAFull   : in  std_logic;                     -- Local buffer almost full
      vc2LocBuffFull    : in  std_logic;                     -- Local buffer full

      -- Frame Transmit Interface, VC 3
      vc3FrameTxValid   : in  std_logic;                     -- User frame data is valid
      vc3FrameTxReady   : out std_logic;                     -- PGP is ready
      vc3FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
      vc3FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
      vc3FrameTxEOFE    : in  std_logic;                     -- User frame data error
      vc3FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
      vc3LocBuffAFull   : in  std_logic;                     -- Local buffer almost full
      vc3LocBuffFull    : in  std_logic;                     -- Local buffer full

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

      -- GTX Status & Control Signals
      gtxLoopback       : in  std_logic;                     -- GTX Serial Loopback Control

      -- MGT Signals Clock & IO Signals
      gtxClkIn          : in  std_logic;                     -- GTX Reference Clock In
      gtxRefClkOut      : out std_logic;                     -- GTX Reference Clock Output
      gtxRxRecClk       : out std_logic;                     -- GTX Rx Recovered Clock
      gtxRxN            : in  std_logic;                     -- GTX Serial Receive Negative
      gtxRxP            : in  std_logic;                     -- GTX Serial Receive Positive
      gtxTxN            : out std_logic;                     -- GTX Serial Transmit Negative
      gtxTxP            : out std_logic;                     -- GTX Serial Transmit Positive

      -- Debug
      debug             : out std_logic_vector(63 downto 0)
   );

end Pgp2Gtx16;


-- Define architecture
architecture Pgp2Gtx16 of Pgp2Gtx16 is

   -- Local Signals
   signal crcTxIn           : std_logic_vector(15 downto 0);
   signal crcTxInGtx        : std_logic_vector(31 downto 0);
   signal crcTxInit         : std_logic;
   signal crcTxRst          : std_logic;
   signal crcTxValid        : std_logic;
   signal crcTxWidth        : std_logic_vector(2  downto 0);
   signal crcTxOut          : std_logic_vector(31 downto 0);
   signal crcTxOutGtx       : std_logic_vector(31 downto 0);
   signal crcRxIn           : std_logic_vector(15 downto 0);
   signal crcRxInGtx        : std_logic_vector(31 downto 0);
   signal crcRxInit         : std_logic;
   signal crcRxRst          : std_logic;
   signal crcRxValid        : std_logic;
   signal crcRxWidth        : std_logic_vector(2  downto 0);
   signal crcRxOut          : std_logic_vector(31 downto 0);
   signal crcRxOutGtx       : std_logic_vector(31 downto 0);
   signal phyRxPolarity     : std_logic_vector(0  downto 0);
   signal phyRxData         : std_logic_vector(15 downto 0);
   signal phyRxDataK        : std_logic_vector(1  downto 0);
   signal phyTxData         : std_logic_vector(15 downto 0);
   signal phyTxDataK        : std_logic_vector(1  downto 0);
   signal phyRxDispErr      : std_logic_vector(1  downto 0);
   signal phyRxDecErr       : std_logic_vector(1  downto 0);
   signal phyRxReady        : std_logic;
   signal phyRxInit         : std_logic;
   signal phyTxReady        : std_logic;
   signal phyRxReset        : std_logic;
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


   -- Adapt CRC data width flag
   crcTxWidth <= "001";
   crcRxWidth <= "001";
   crcRxRst   <= intRxRst or crcRxInit;
   crcTxRst   <= intTxRst or crcTxInit;

   -- Pass CRC data in on proper bits
   crcTxInGtx(31 downto 24) <= crcTxIn(7  downto 0);
   crcTxInGtx(23 downto 16) <= crcTxIn(15 downto 8);
   crcTxInGtx(15 downto  0) <= (others=>'0');
   crcRxInGtx(31 downto 24) <= crcRxIn(7  downto 0);
   crcRxInGtx(23 downto 16) <= crcRxIn(15 downto 8);
   crcRxInGtx(15 downto  0) <= (others=>'0');

   -- Pll Resets
   intTxRst <= pllTxRst or pgpReset;
   intRxRst <= pllRxRst or pgpReset;

   -- PLL Lock
   pllRxReady <= phyRxReady;
   pllTxReady <= phyTxReady;

   -- Link Ready
   pgpLocLinkReady <= pgpRxLinkReady and pgpTxLinkReady;

   -- Invert Output CRC
   crcRxOut <= not crcRxOutGtx;
   crcTxOut <= not crcTxOutGtx;


   -- TX CRC BLock
   Tx_CRC: CRC32 
      generic map(
         CRC_INIT   => x"FFFFFFFF"
      ) port map(
         CRCOUT       => crcTxOutGtx,
         CRCCLK       => pgpClk,
         CRCDATAVALID => crcTxValid,
         CRCDATAWIDTH => crcTxWidth,
         CRCIN        => crcTxInGtx,
         CRCRESET     => crcTxRst
      );


   -- RX CRC BLock
   Rx_CRC: CRC32 
      generic map(
         CRC_INIT   => x"FFFFFFFF"
      ) port map(
         CRCOUT       => crcRxOutGtx,
         CRCCLK       => pgpClk,
         CRCDATAVALID => crcRxValid,
         CRCDATAWIDTH => crcRxWidth,
         CRCIN        => crcRxInGtx,
         CRCRESET     => crcRxRst 
      );


   -- RX Reset Control
   U_Pgp2GtxRxRst: Pgp2GtxRxRst
      port map (
         gtxRxClk          => pgpClk,
         gtxRxRst          => intRxRst,
         gtxRxReady        => phyRxReady,
         gtxRxInit         => phyRxInit,
         gtxLockDetect     => phyLockDetect,
         gtxRxElecIdle     => phyRxElecIdle,
         gtxRxBuffStatus   => phyRxBuffStatus,
         gtxRstDone        => phyRstDone,
         gtxRxReset        => phyRxReset,
         gtxRxCdrReset     => phyRxCdrReset
      );


   -- TX Reset Control
   U_Pgp2GtxTxRst: Pgp2GtxTxRst
      port map (
         gtxTxClk          => pgpClk,
         gtxTxRst          => intTxRst,
         gtxTxReady        => phyTxReady,
         gtxLockDetect     => phyLockDetect,
         gtxTxBuffStatus   => phyTxBuffStatus,
         gtxRstDone        => phyRstDone,
         gtxTxReset        => phyTxReset
      );


   ----------------------------- GTX_DUAL Instance  --------------------------   
   UGtxDual:GTX_DUAL
      generic map (

         --_______________________ Simulation-Only Attributes ___________________

         SIM_RECEIVER_DETECT_PASS_0  =>       TRUE,
         SIM_RECEIVER_DETECT_PASS_1  =>       TRUE,
         SIM_MODE                    =>       "FAST",
         SIM_GTXRESET_SPEEDUP        =>       1,
         SIM_PLL_PERDIV2             =>       x"140",

         --___________________________ Shared Attributes ________________________

         -------------------------- Tile and PLL Attributes ---------------------

         CLK25_DIVIDER               =>       10, 
         CLKINDC_B                   =>       TRUE,
         OOB_CLK_DIVIDER             =>       6,
         OVERSAMPLE_MODE             =>       FALSE,
         PLL_DIVSEL_FB               =>       2,
         PLL_DIVSEL_REF              =>       1,
         CLKRCV_TRST                 =>       TRUE,
         PLL_COM_CFG                 =>       x"21680a",
         PLL_CP_CFG                  =>       x"00",
         PLL_FB_DCCEN                =>       FALSE,
         PLL_LKDET_CFG               =>       "101",
         PLL_TDCC_CFG                =>       "000",
         PMA_COM_CFG                 =>       x"000000000000000000",

         --____________________ Transmit Interface Attributes ___________________

         ------------------- TX Buffering and Phase Alignment -------------------   

         TX_BUFFER_USE_0             =>       TRUE,
         TX_XCLK_SEL_0               =>       "TXOUT",
         TXRX_INVERT_0               =>       "011",        

         TX_BUFFER_USE_1             =>       TRUE,
         TX_XCLK_SEL_1               =>       "TXOUT",
         TXRX_INVERT_1               =>       "011",        

         --------------------- TX Gearbox Settings -----------------------------

         GEARBOX_ENDEC_0             =>       "000", 
         TXGEARBOX_USE_0             =>       FALSE,

         GEARBOX_ENDEC_1             =>       "000", 
         TXGEARBOX_USE_1             =>       FALSE,

         --------------------- TX Serial Line Rate settings ---------------------   
 
         PLL_TXDIVSEL_OUT_0          =>       1,
         PLL_TXDIVSEL_OUT_1          =>       1,

         --------------------- TX Driver and OOB signalling --------------------  

         CM_TRIM_0                   =>       "10",
         PMA_TX_CFG_0                =>       x"80082",
         TX_DETECT_RX_CFG_0          =>       x"1832",
         TX_IDLE_DELAY_0             =>       "010",
         CM_TRIM_1                   =>       "10",
         PMA_TX_CFG_1                =>       x"80082",
         TX_DETECT_RX_CFG_1          =>       x"1832",
         TX_IDLE_DELAY_1             =>       "010",

         ------------------ TX Pipe Control for PCI Express/SATA ---------------

         COM_BURST_VAL_0             =>       "1111",
         COM_BURST_VAL_1             =>       "1111",

         --_______________________ Receive Interface Attributes ________________
 
         ------------ RX Driver,OOB signalling,Coupling and Eq,CDR -------------  

         AC_CAP_DIS_0                =>       TRUE,
         OOBDETECT_THRESHOLD_0       =>       "111",
         PMA_CDR_SCAN_0              =>       x"640403a",
         PMA_RX_CFG_0                =>       x"0f44088",
         RCV_TERM_GND_0              =>       FALSE,
         RCV_TERM_VTTRX_0            =>       TRUE,
         TERMINATION_IMP_0           =>       50,
         AC_CAP_DIS_1                =>       TRUE,
         OOBDETECT_THRESHOLD_1       =>       "111",
         PMA_CDR_SCAN_1              =>       x"640403a",
         PMA_RX_CFG_1                =>       x"0f44088",  
         RCV_TERM_GND_1              =>       FALSE,
         RCV_TERM_VTTRX_1            =>       TRUE,
         TERMINATION_IMP_1           =>       50,
         TERMINATION_CTRL            =>       "10100",
         TERMINATION_OVRD            =>       FALSE,

         ---------------- RX Decision Feedback Equalizer(DFE)  ----------------  

         DFE_CFG_0                   =>       "1001111011",
         DFE_CFG_1                   =>       "1001111011",
         DFE_CAL_TIME                =>       "00110",

         --------------------- RX Serial Line Rate Attributes ------------------   
 
         PLL_RXDIVSEL_OUT_0          =>       1,
         PLL_SATA_0                  =>       FALSE,
         PLL_RXDIVSEL_OUT_1          =>       1,
         PLL_SATA_1                  =>       FALSE,
 
         ----------------------- PRBS Detection Attributes ---------------------  
 
         PRBS_ERR_THRESHOLD_0        =>       x"00000001",
         PRBS_ERR_THRESHOLD_1        =>       x"00000001",
 
         ---------------- Comma Detection and Alignment Attributes -------------  
 
         ALIGN_COMMA_WORD_0          =>       2,
         COMMA_10B_ENABLE_0          =>       "1111111111",
         COMMA_DOUBLE_0              =>       FALSE,
         DEC_MCOMMA_DETECT_0         =>       TRUE,
         DEC_PCOMMA_DETECT_0         =>       TRUE,
         DEC_VALID_COMMA_ONLY_0      =>       FALSE,
         MCOMMA_10B_VALUE_0          =>       "1010000011",
         MCOMMA_DETECT_0             =>       TRUE,
         PCOMMA_10B_VALUE_0          =>       "0101111100",
         PCOMMA_DETECT_0             =>       TRUE,
         RX_SLIDE_MODE_0             =>       "PCS",
 
         ALIGN_COMMA_WORD_1          =>       2,
         COMMA_10B_ENABLE_1          =>       "1111111111",
         COMMA_DOUBLE_1              =>       FALSE,
         DEC_MCOMMA_DETECT_1         =>       TRUE,
         DEC_PCOMMA_DETECT_1         =>       TRUE,
         DEC_VALID_COMMA_ONLY_1      =>       FALSE,
         MCOMMA_10B_VALUE_1          =>       "1010000011",
         MCOMMA_DETECT_1             =>       TRUE,
         PCOMMA_10B_VALUE_1          =>       "0101111100",
         PCOMMA_DETECT_1             =>       TRUE,
         RX_SLIDE_MODE_1             =>       "PCS",
 
         ------------------ RX Loss-of-sync State Machine Attributes -----------  
 
         RX_LOSS_OF_SYNC_FSM_0       =>       FALSE,
         RX_LOS_INVALID_INCR_0       =>       8,
         RX_LOS_THRESHOLD_0          =>       128,
         RX_LOSS_OF_SYNC_FSM_1       =>       FALSE,
         RX_LOS_INVALID_INCR_1       =>       8,
         RX_LOS_THRESHOLD_1          =>       128,

         --------------------- RX Gearbox Settings -----------------------------

         RXGEARBOX_USE_0             =>       FALSE,
         RXGEARBOX_USE_1             =>       FALSE,
 
         -------------- RX Elastic Buffer and Phase alignment Attributes -------   
 
         PMA_RXSYNC_CFG_0            =>       x"00",
         RX_BUFFER_USE_0             =>       TRUE,
         RX_XCLK_SEL_0               =>       "RXREC",
         PMA_RXSYNC_CFG_1            =>       x"00",
         RX_BUFFER_USE_1             =>       TRUE,
         RX_XCLK_SEL_1               =>       "RXREC",                   
 
         ------------------------ Clock Correction Attributes ------------------   
 
         CLK_CORRECT_USE_0           =>       TRUE,
         CLK_COR_ADJ_LEN_0           =>       4,
         CLK_COR_DET_LEN_0           =>       4,
         CLK_COR_INSERT_IDLE_FLAG_0  =>       FALSE,
         CLK_COR_KEEP_IDLE_0         =>       FALSE,
         CLK_COR_MAX_LAT_0           =>       48,
         CLK_COR_MIN_LAT_0           =>       36,
         CLK_COR_PRECEDENCE_0        =>       TRUE,
         CLK_COR_REPEAT_WAIT_0       =>       0,
         CLK_COR_SEQ_1_1_0           =>       "0110111100",
         CLK_COR_SEQ_1_2_0           =>       "0100011100",
         CLK_COR_SEQ_1_3_0           =>       "0100011100",
         CLK_COR_SEQ_1_4_0           =>       "0100011100",
         CLK_COR_SEQ_1_ENABLE_0      =>       "1111",
         CLK_COR_SEQ_2_1_0           =>       "0000000000",
         CLK_COR_SEQ_2_2_0           =>       "0000000000",
         CLK_COR_SEQ_2_3_0           =>       "0000000000",
         CLK_COR_SEQ_2_4_0           =>       "0000000000",
         CLK_COR_SEQ_2_ENABLE_0      =>       "0000",
         CLK_COR_SEQ_2_USE_0         =>       FALSE,
         RX_DECODE_SEQ_MATCH_0       =>       TRUE,
 
         CLK_CORRECT_USE_1           =>       TRUE,
         CLK_COR_ADJ_LEN_1           =>       4,
         CLK_COR_DET_LEN_1           =>       4,
         CLK_COR_INSERT_IDLE_FLAG_1  =>       FALSE,
         CLK_COR_KEEP_IDLE_1         =>       FALSE,
         CLK_COR_MAX_LAT_1           =>       48,
         CLK_COR_MIN_LAT_1           =>       36,
         CLK_COR_PRECEDENCE_1        =>       TRUE,
         CLK_COR_REPEAT_WAIT_1       =>       0,
         CLK_COR_SEQ_1_1_1           =>       "1101111100",
         CLK_COR_SEQ_1_2_1           =>       "1000111100",
         CLK_COR_SEQ_1_3_1           =>       "1000111100",
         CLK_COR_SEQ_1_4_1           =>       "1000111100",
         CLK_COR_SEQ_1_ENABLE_1      =>       "1111",
         CLK_COR_SEQ_2_1_1           =>       "0000000000",
         CLK_COR_SEQ_2_2_1           =>       "0000000000",
         CLK_COR_SEQ_2_3_1           =>       "0000000000",
         CLK_COR_SEQ_2_4_1           =>       "0000000000",
         CLK_COR_SEQ_2_ENABLE_1      =>       "0000",
         CLK_COR_SEQ_2_USE_1         =>       FALSE,
         RX_DECODE_SEQ_MATCH_1       =>       TRUE,
 
         ------------------------ Channel Bonding Attributes -------------------   
 
         CB2_INH_CC_PERIOD_0         =>       8,
         CHAN_BOND_KEEP_ALIGN_0      =>       FALSE,
         CHAN_BOND_1_MAX_SKEW_0      =>       1,
         CHAN_BOND_2_MAX_SKEW_0      =>       1,
         CHAN_BOND_LEVEL_0           =>       0,
         CHAN_BOND_MODE_0            =>       "OFF",
         CHAN_BOND_SEQ_1_1_0         =>       "0000000000",
         CHAN_BOND_SEQ_1_2_0         =>       "0000000000",
         CHAN_BOND_SEQ_1_3_0         =>       "0000000000",
         CHAN_BOND_SEQ_1_4_0         =>       "0000000000",
         CHAN_BOND_SEQ_1_ENABLE_0    =>       "0000",
         CHAN_BOND_SEQ_2_1_0         =>       "0000000000",
         CHAN_BOND_SEQ_2_2_0         =>       "0000000000",
         CHAN_BOND_SEQ_2_3_0         =>       "0000000000",
         CHAN_BOND_SEQ_2_4_0         =>       "0000000000",
         CHAN_BOND_SEQ_2_ENABLE_0    =>       "0000",
         CHAN_BOND_SEQ_2_USE_0       =>       FALSE,  
         CHAN_BOND_SEQ_LEN_0         =>       1,
         PCI_EXPRESS_MODE_0          =>       FALSE,   
      
         CB2_INH_CC_PERIOD_1         =>       8,
         CHAN_BOND_KEEP_ALIGN_1      =>       FALSE,
         CHAN_BOND_1_MAX_SKEW_1      =>       1,
         CHAN_BOND_2_MAX_SKEW_1      =>       1,
         CHAN_BOND_LEVEL_1           =>       0,
         CHAN_BOND_MODE_1            =>       "OFF",
         CHAN_BOND_SEQ_1_1_1         =>       "0000000000",
         CHAN_BOND_SEQ_1_2_1         =>       "0000000000",
         CHAN_BOND_SEQ_1_3_1         =>       "0000000000",
         CHAN_BOND_SEQ_1_4_1         =>       "0000000000",
         CHAN_BOND_SEQ_1_ENABLE_1    =>       "0000",
         CHAN_BOND_SEQ_2_1_1         =>       "0000000000",
         CHAN_BOND_SEQ_2_2_1         =>       "0000000000",
         CHAN_BOND_SEQ_2_3_1         =>       "0000000000",
         CHAN_BOND_SEQ_2_4_1         =>       "0000000000",
         CHAN_BOND_SEQ_2_ENABLE_1    =>       "0000",
         CHAN_BOND_SEQ_2_USE_1       =>       FALSE,  
         CHAN_BOND_SEQ_LEN_1         =>       1,
         PCI_EXPRESS_MODE_1          =>       FALSE,

         -------- RX Attributes to Control Reset after Electrical Idle  ------

         RX_EN_IDLE_HOLD_DFE_0       =>       TRUE,
         RX_EN_IDLE_RESET_BUF_0      =>       TRUE,
         RX_IDLE_HI_CNT_0            =>       "1000",
         RX_IDLE_LO_CNT_0            =>       "0000",
         RX_EN_IDLE_HOLD_DFE_1       =>       TRUE,
         RX_EN_IDLE_RESET_BUF_1      =>       TRUE,
         RX_IDLE_HI_CNT_1            =>       "1000",
         RX_IDLE_LO_CNT_1            =>       "0000",
         CDR_PH_ADJ_TIME             =>       "01010",
         RX_EN_IDLE_RESET_FR         =>       TRUE,
         RX_EN_IDLE_HOLD_CDR         =>       FALSE,
         RX_EN_IDLE_RESET_PH         =>       TRUE,

         ------------------ RX Attributes for PCI Express/SATA ---------------
 
         RX_STATUS_FMT_0             =>       "PCIE",
         SATA_BURST_VAL_0            =>       "100",
         SATA_IDLE_VAL_0             =>       "100",
         SATA_MAX_BURST_0            =>       7,
         SATA_MAX_INIT_0             =>       22,
         SATA_MAX_WAKE_0             =>       7,
         SATA_MIN_BURST_0            =>       4,
         SATA_MIN_INIT_0             =>       12,
         SATA_MIN_WAKE_0             =>       4,
         TRANS_TIME_FROM_P2_0        =>       x"003C",
         TRANS_TIME_NON_P2_0         =>       x"0019",
         TRANS_TIME_TO_P2_0          =>       x"0064",
 
         RX_STATUS_FMT_1             =>       "PCIE",
         SATA_BURST_VAL_1            =>       "100",
         SATA_IDLE_VAL_1             =>       "100",
         SATA_MAX_BURST_1            =>       7,
         SATA_MAX_INIT_1             =>       22,
         SATA_MAX_WAKE_1             =>       7,
         SATA_MIN_BURST_1            =>       4,
         SATA_MIN_INIT_1             =>       12,
         SATA_MIN_WAKE_1             =>       4,
         TRANS_TIME_FROM_P2_1        =>       x"003C",
         TRANS_TIME_NON_P2_1         =>       x"0019",
         TRANS_TIME_TO_P2_1          =>       x"0064"

      ) port map (

         ------------------------ Loopback and Powerdown Ports ----------------------
         LOOPBACK0(0)                    =>      '0',
         LOOPBACK0(1)                    =>      gtxLoopback,
         LOOPBACK0(2)                    =>      '0',
         LOOPBACK1                       =>      "000",
         RXPOWERDOWN0                    =>      (others=>'0'),
         RXPOWERDOWN1                    =>      (others=>'0'),
         TXPOWERDOWN0                    =>      (others=>'0'),
         TXPOWERDOWN1                    =>      (others=>'0'),
         -------------- Receive Ports - 64b66b and 64b67b Gearbox Ports -------------
         RXDATAVALID0                    =>      open,
         RXDATAVALID1                    =>      open,
         RXGEARBOXSLIP0                  =>      '0',
         RXGEARBOXSLIP1                  =>      '0',
         RXHEADER0                       =>      open,
         RXHEADER1                       =>      open,
         RXHEADERVALID0                  =>      open,
         RXHEADERVALID1                  =>      open,
         RXSTARTOFSEQ0                   =>      open,
         RXSTARTOFSEQ1                   =>      open,
         ----------------------- Receive Ports - 8b10b Decoder ----------------------
         RXCHARISCOMMA0                  =>      open,
         RXCHARISCOMMA1                  =>      open,
         RXCHARISK0(1 downto 0)          =>      phyRxDataK,
         RXCHARISK0(3 downto 2)          =>      open,
         RXCHARISK1                      =>      open,
         RXDEC8B10BUSE0                  =>      '1',
         RXDEC8B10BUSE1                  =>      '1',
         RXDISPERR0(1 downto 0)          =>      phyRxDispErr,
         RXDISPERR0(3 downto 2)          =>      open,
         RXDISPERR1                      =>      open,
         RXNOTINTABLE0(1 downto 0)       =>      phyRxDecErr,
         RXNOTINTABLE0(3 downto 2)       =>      open,
         RXNOTINTABLE1                   =>      open,
         RXRUNDISP0                      =>      open,
         RXRUNDISP1                      =>      open,
         ------------------- Receive Ports - Channel Bonding Ports ------------------
         RXCHANBONDSEQ0                  =>      open,
         RXCHANBONDSEQ1                  =>      open,
         RXCHBONDI0                      =>      (others=>'0'),
         RXCHBONDI1                      =>      (others=>'0'),
         RXCHBONDO0                      =>      open,
         RXCHBONDO1                      =>      open,
         RXENCHANSYNC0                   =>      '0',
         RXENCHANSYNC1                   =>      '0',
         ------------------- Receive Ports - Clock Correction Ports -----------------
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
         RXDATA0(15 downto 0)            =>      phyRxData,
         RXDATA0(31 downto 16)           =>      open,
         RXDATA1                         =>      open,
         RXDATAWIDTH0                    =>      "01",
         RXDATAWIDTH1                    =>      "01",
         RXRECCLK0                       =>      intRxRecClk,
         RXRECCLK1                       =>      open,
         RXRESET0                        =>      phyRxReset,
         RXRESET1                        =>      '0',
         RXUSRCLK0                       =>      pgpClk,
         RXUSRCLK1                       =>      pgpClk,
         RXUSRCLK20                      =>      pgpClk,
         RXUSRCLK21                      =>      pgpClk,
         ------------ Receive Ports - RX Decision Feedback Equalizer(DFE) -----------
         DFECLKDLYADJ0                   =>      (others=>'0'),
         DFECLKDLYADJ1                   =>      (others=>'0'),
         DFECLKDLYADJMONITOR0            =>      open,
         DFECLKDLYADJMONITOR1            =>      open,
         DFEEYEDACMONITOR0               =>      open,
         DFEEYEDACMONITOR1               =>      open,
         DFESENSCAL0                     =>      open,
         DFESENSCAL1                     =>      open,
         DFETAP10                        =>      (others=>'0'),
         DFETAP11                        =>      (others=>'0'),
         DFETAP1MONITOR0                 =>      open,
         DFETAP1MONITOR1                 =>      open,
         DFETAP20                        =>      (others=>'0'),
         DFETAP21                        =>      (others=>'0'),
         DFETAP2MONITOR0                 =>      open,
         DFETAP2MONITOR1                 =>      open,
         DFETAP30                        =>      (others=>'0'),
         DFETAP31                        =>      (others=>'0'),
         DFETAP3MONITOR0                 =>      open,
         DFETAP3MONITOR1                 =>      open,
         DFETAP40                        =>      (others=>'0'),
         DFETAP41                        =>      (others=>'0'),
         DFETAP4MONITOR0                 =>      open,
         DFETAP4MONITOR1                 =>      open,
         ------- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
         RXCDRRESET0                     =>      phyRxCdrReset,
         RXCDRRESET1                     =>      '0',
         RXELECIDLE0                     =>      phyRxElecIdle,
         RXELECIDLE1                     =>      open,
         RXENEQB0                        =>      '0',
         RXENEQB1                        =>      '0',
         RXEQMIX0                        =>      (others=>'0'),
         RXEQMIX1                        =>      (others=>'0'),
         RXEQPOLE0                       =>      (others=>'0'),
         RXEQPOLE1                       =>      (others=>'0'),
         RXN0                            =>      gtxRxN,
         RXN1                            =>      '1',
         RXP0                            =>      gtxRxP,
         RXP1                            =>      '0',
         -------- Receive Ports - RX Elastic Buffer and Phase Alignment Ports -------
         RXBUFRESET0                     =>      '0',
         RXBUFRESET1                     =>      '0',
         RXBUFSTATUS0                    =>      phyRxBuffStatus,
         RXBUFSTATUS1                    =>      open,
         RXCHANISALIGNED0                =>      open,
         RXCHANISALIGNED1                =>      open,
         RXCHANREALIGN0                  =>      open,
         RXCHANREALIGN1                  =>      open,
         RXENPMAPHASEALIGN0              =>      '0',
         RXENPMAPHASEALIGN1              =>      '0',
         RXPMASETPHASE0                  =>      '0',
         RXPMASETPHASE1                  =>      '0',
         RXSTATUS0                       =>      open,
         RXSTATUS1                       =>      open,
         --------------- Receive Ports - RX Loss-of-sync State Machine --------------
         RXLOSSOFSYNC0                   =>      open,
         RXLOSSOFSYNC1                   =>      open,
         ---------------------- Receive Ports - RX Oversampling ---------------------
         RXENSAMPLEALIGN0                =>      '0',
         RXENSAMPLEALIGN1                =>      '0',
         RXOVERSAMPLEERR0                =>      open,
         RXOVERSAMPLEERR1                =>      open,
         -------------- Receive Ports - RX Pipe Control for PCI Express -------------
         PHYSTATUS0                      =>      open,
         PHYSTATUS1                      =>      open,
         RXVALID0                        =>      open,
         RXVALID1                        =>      open,
         ----------------- Receive Ports - RX Polarity Control Ports ----------------
         RXPOLARITY0                     =>      phyRxPolarity(0),
         RXPOLARITY1                     =>      '0',
         ------------- Shared Ports - Dynamic Reconfiguration Port (DRP) ------------
         DADDR                           =>      (others=>'0'),
         DCLK                            =>      '0',
         DEN                             =>      '0',
         DI                              =>      (others=>'0'),
         DO                              =>      open,
         DRDY                            =>      open,
         DWE                             =>      '0',
         --------------------- Shared Ports - Tile and PLL Ports --------------------
         CLKIN                           =>      gtxClkIn,
         GTXRESET                        =>      pgpReset,
         GTXTEST                         =>      "10000000000000",
         INTDATAWIDTH                    =>      '1',
         PLLLKDET                        =>      phyLockDetect,
         PLLLKDETEN                      =>      '1',
         PLLPOWERDOWN                    =>      '0',
         REFCLKOUT                       =>      tmpRefClkOut,
         REFCLKPWRDNB                    =>      '1',
         RESETDONE0                      =>      phyRstDone,
         RESETDONE1                      =>      open,
         -------------- Transmit Ports - 64b66b and 64b67b Gearbox Ports ------------
         TXGEARBOXREADY0                 =>      open,
         TXGEARBOXREADY1                 =>      open,
         TXHEADER0                       =>      (others=>'0'),
         TXHEADER1                       =>      (others=>'0'),
         TXSEQUENCE0                     =>      (others=>'0'),
         TXSEQUENCE1                     =>      (others=>'0'),
         TXSTARTSEQ0                     =>      '0',
         TXSTARTSEQ1                     =>      '0',
         ---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
         TXBYPASS8B10B0                  =>      (others=>'0'),
         TXBYPASS8B10B1                  =>      (others=>'0'),
         TXCHARDISPMODE0                 =>      (others=>'0'),
         TXCHARDISPMODE1                 =>      (others=>'0'),
         TXCHARDISPVAL0                  =>      (others=>'0'),
         TXCHARDISPVAL1                  =>      (others=>'0'),
         TXCHARISK0(1 downto 0)          =>      phyTxDataK,
         TXCHARISK0(3 downto 2)          =>      (others=>'0'),
         TXCHARISK1                      =>      (others=>'0'),
         TXENC8B10BUSE0                  =>      '1',
         TXENC8B10BUSE1                  =>      '1',
         TXKERR0                         =>      open,
         TXKERR1                         =>      open,
         TXRUNDISP0                      =>      open,
         TXRUNDISP1                      =>      open,
         ------------- Transmit Ports - TX Buffering and Phase Alignment ------------
         TXBUFSTATUS0                    =>      phyTxBuffStatus,
         TXBUFSTATUS1                    =>      open,
         ------------------ Transmit Ports - TX Data Path interface -----------------
         TXDATA0(15 downto 0)            =>      phyTxData,
         TXDATA0(31 downto 16)           =>      (others=>'0'),
         TXDATA1                         =>      (others=>'0'),
         TXDATAWIDTH0                    =>      "01",
         TXDATAWIDTH1                    =>      "01",
         TXOUTCLK0                       =>      open,
         TXOUTCLK1                       =>      open,
         TXRESET0                        =>      phyTxReset,
         TXRESET1                        =>      '0',
         TXUSRCLK0                       =>      pgpClk,
         TXUSRCLK1                       =>      pgpClk,
         TXUSRCLK20                      =>      pgpClk,
         TXUSRCLK21                      =>      pgpClk,
         --------------- Transmit Ports - TX Driver and OOB signalling --------------
         TXBUFDIFFCTRL0                  =>      "100", -- 800mV
         TXBUFDIFFCTRL1                  =>      "100",
         TXDIFFCTRL0                     =>      "100",
         TXDIFFCTRL1                     =>      "100",
         TXINHIBIT0                      =>      '0',
         TXINHIBIT1                      =>      '0',
         TXN0                            =>      gtxTxN,
         TXN1                            =>      open,
         TXP0                            =>      gtxTxP,
         TXP1                            =>      open,
         TXPREEMPHASIS0                  =>      "0011", -- 4.5%
         TXPREEMPHASIS1                  =>      "0011",
         -------- Transmit Ports - TX Elastic Buffer and Phase Alignment Ports ------
         TXENPMAPHASEALIGN0              =>      '0',
         TXENPMAPHASEALIGN1              =>      '0',
         TXPMASETPHASE0                  =>      '0',
         TXPMASETPHASE1                  =>      '0',
         --------------------- Transmit Ports - TX PRBS Generator -------------------
         TXENPRBSTST0                    =>      (others=>'0'),
         TXENPRBSTST1                    =>      (others=>'0'),
         -------------------- Transmit Ports - TX Polarity Control ------------------
         TXPOLARITY0                     =>      '0',
         TXPOLARITY1                     =>      '0',
         ----------------- Transmit Ports - TX Ports for PCI Express ----------------
         TXDETECTRX0                     =>      '0',
         TXDETECTRX1                     =>      '0',
         TXELECIDLE0                     =>      '0',
         TXELECIDLE1                     =>      '0',
         --------------------- Transmit Ports - TX Ports for SATA -------------------
         TXCOMSTART0                     =>      '0',
         TXCOMSTART1                     =>      '0',
         TXCOMTYPE0                      =>      '0',
         TXCOMTYPE1                      =>      '0'
      );

   -- Global Buffer For Ref Clock Output
   U_RefClkBuff: BUFG port map (
      O => gtxRefClkOut,
      I => tmpRefClkOut
   );
   gtxRxRecClk <= intRxRecClk;

end Pgp2Gtx16;

