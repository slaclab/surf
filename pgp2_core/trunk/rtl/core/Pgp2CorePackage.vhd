-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, Core Package
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2CorePackage.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/27/2009
-------------------------------------------------------------------------------
-- Description:
-- PGP ID and other global constants.
-------------------------------------------------------------------------------
-- Copyright (c) 2006 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 05/27/2009: created.
-- 11/23/2009: Renamed package.
-- 12/13/2010: Added received init line to help linking.
-- 06/25/2010: Added payload size config as generic.
-- 05/18/2012: Added VC transmit timeout
-------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package Pgp2CorePackage is

   -- 8B10B Characters
   constant K_COM  : std_logic_vector(7 downto 0) := "10111100"; -- K28.5, 0xBC
   constant K_LTS  : std_logic_vector(7 downto 0) := "00111100"; -- K28.1, 0x3C
   constant D_102  : std_logic_vector(7 downto 0) := "01001010"; -- D10.2, 0x4A
   constant D_215  : std_logic_vector(7 downto 0) := "10110101"; -- D21.5, 0xB5
   constant K_SKP  : std_logic_vector(7 downto 0) := "00011100"; -- K28.0, 0x1C
   constant K_OTS  : std_logic_vector(7 downto 0) := "01111100"; -- K28.3, 0x7C
   constant K_ALN  : std_logic_vector(7 downto 0) := "11011100"; -- K28.6, 0xDC
   constant K_SOC  : std_logic_vector(7 downto 0) := "11111011"; -- K27.7, 0xFB
   constant K_SOF  : std_logic_vector(7 downto 0) := "11110111"; -- K23.7, 0xF7
   constant K_EOF  : std_logic_vector(7 downto 0) := "11111101"; -- K29.7, 0xFD
   constant K_EOFE : std_logic_vector(7 downto 0) := "11111110"; -- K30.7, 0xFE
   constant K_EOC  : std_logic_vector(7 downto 0) := "01011100"; -- K28.2, 0x5C

   -- ID Constant
   constant Pgp2Id : std_logic_vector(3 downto 0) := "0101";

   -- PGP Receive Core
   component Pgp2Rx
      generic (
         RxLaneCnt     : integer := 4;
         EnShortCells  : integer := 1;
         PayloadCntTop : integer := 7
      );
      port (
         pgpRxClk          : in  std_logic;
         pgpRxReset        : in  std_logic;
         pgpRxFlush        : in  std_logic;
         pgpRxLinkReady    : out std_logic;
         pgpRxCellError    : out std_logic;
         pgpRxLinkDown     : out std_logic;
         pgpRxLinkError    : out std_logic;
         pgpRxOpCodeEn     : out std_logic;
         pgpRxOpCode       : out std_logic_vector(7 downto 0);
         pgpRemLinkReady   : out std_logic;
         pgpRemData        : out std_logic_vector(7 downto 0);
         vcFrameRxSOF      : out std_logic;
         vcFrameRxEOF      : out std_logic;
         vcFrameRxEOFE     : out std_logic;
         vcFrameRxData     : out std_logic_vector(RxLaneCnt*16-1 downto 0);
         vc0FrameRxValid   : out std_logic;
         vc0RemBuffAFull   : out std_logic;
         vc0RemBuffFull    : out std_logic;
         vc1FrameRxValid   : out std_logic;
         vc1RemBuffAFull   : out std_logic;
         vc1RemBuffFull    : out std_logic;
         vc2FrameRxValid   : out std_logic;
         vc2RemBuffAFull   : out std_logic;
         vc2RemBuffFull    : out std_logic;
         vc3FrameRxValid   : out std_logic;
         vc3RemBuffAFull   : out std_logic;
         vc3RemBuffFull    : out std_logic;
         phyRxPolarity     : out std_logic_vector(RxLaneCnt-1    downto 0);
         phyRxData         : in  std_logic_vector(RxLaneCnt*16-1 downto 0);
         phyRxDataK        : in  std_logic_vector(RxLaneCnt*2-1  downto 0);
         phyRxDispErr      : in  std_logic_vector(RxLaneCnt*2-1  downto 0);
         phyRxDecErr       : in  std_logic_vector(RxLaneCnt*2-1  downto 0);
         phyRxReady        : in  std_logic;
         phyRxInit         : out std_logic;
         crcRxIn           : out std_logic_vector(RxLaneCnt*16-1 downto 0);
         crcRxWidth        : out std_logic;
         crcRxInit         : out std_logic;
         crcRxValid        : out std_logic;
         crcRxOut          : in  std_logic_vector(31 downto 0);
         debug             : out std_logic_vector(63 downto 0)
      );
   end component;

   -- PGP Transmit Core
   component Pgp2Tx
      generic (
         TxLaneCnt     : integer := 4;
         VcInterleave  : integer := 1;
         PayloadCntTop : integer := 7
      );
      port (
         pgpTxClk          : in  std_logic;
         pgpTxReset        : in  std_logic;
         pgpTxFlush        : in  std_logic;
         pgpTxLinkReady    : out std_logic;
         pgpTxOpCodeEn     : in  std_logic;
         pgpTxOpCode       : in  std_logic_vector(7 downto 0);
         pgpLocLinkReady   : in  std_logic;
         pgpLocData        : in  std_logic_vector(7 downto 0);
         vc0FrameTxValid   : in  std_logic;
         vc0FrameTxReady   : out std_logic;
         vc0FrameTxSOF     : in  std_logic;
         vc0FrameTxEOF     : in  std_logic;
         vc0FrameTxEOFE    : in  std_logic;
         vc0FrameTxData    : in  std_logic_vector(TxLaneCnt*16-1 downto 0);
         vc0LocBuffAFull   : in  std_logic;
         vc0LocBuffFull    : in  std_logic;
         vc1FrameTxValid   : in  std_logic;
         vc1FrameTxReady   : out std_logic;
         vc1FrameTxSOF     : in  std_logic;
         vc1FrameTxEOF     : in  std_logic;
         vc1FrameTxEOFE    : in  std_logic;
         vc1FrameTxData    : in  std_logic_vector(TxLaneCnt*16-1 downto 0);
         vc1LocBuffAFull   : in  std_logic;
         vc1LocBuffFull    : in  std_logic;
         vc2FrameTxValid   : in  std_logic;
         vc2FrameTxReady   : out std_logic;
         vc2FrameTxSOF     : in  std_logic;
         vc2FrameTxEOF     : in  std_logic;
         vc2FrameTxEOFE    : in  std_logic;
         vc2FrameTxData    : in  std_logic_vector(TxLaneCnt*16-1 downto 0);
         vc2LocBuffAFull   : in  std_logic;
         vc2LocBuffFull    : in  std_logic;
         vc3FrameTxValid   : in  std_logic;
         vc3FrameTxReady   : out std_logic;
         vc3FrameTxSOF     : in  std_logic;
         vc3FrameTxEOF     : in  std_logic;
         vc3FrameTxEOFE    : in  std_logic;
         vc3FrameTxData    : in  std_logic_vector(TxLaneCnt*16-1 downto 0);
         vc3LocBuffAFull   : in  std_logic;
         vc3LocBuffFull    : in  std_logic;
         phyTxData         : out std_logic_vector(TxLaneCnt*16-1 downto 0);
         phyTxDataK        : out std_logic_vector(TxLaneCnt*2-1  downto 0);
         phyTxReady        : in  std_logic;
         crcTxIn           : out std_logic_vector(TxLaneCnt*16-1 downto 0);
         crcTxInit         : out std_logic;
         crcTxValid        : out std_logic;
         crcTxOut          : in  std_logic_vector(31 downto 0);
         debug             : out std_logic_vector(63 downto 0)
      );
   end component;

   -- Phy Interface
   component Pgp2RxPhy
      generic (
         RxLaneCnt : integer  := 4  -- Number of receive lanes, 1-4
      );
      port (
         pgpRxClk          : in  std_logic;                                 -- Master clock
         pgpRxReset        : in  std_logic;                                 -- Synchronous reset input
         pgpRxLinkReady    : out std_logic;                                 -- Local side has link
         pgpRxLinkDown     : out std_logic;                                 -- A link down event has occured
         pgpRxLinkError    : out std_logic;                                 -- A link error has occured
         pgpRxOpCodeEn     : out std_logic;                                 -- Opcode receive enable
         pgpRxOpCode       : out std_logic_vector(7 downto 0);              -- Opcode receive value
         pgpRemLinkReady   : out std_logic;                                 -- Far end side has link
         pgpRemData        : out std_logic_vector(7 downto 0);              -- Far end side User Data
         cellRxPause       : out std_logic;                                 -- Cell data pause
         cellRxSOC         : out std_logic;                                 -- Cell data start of cell
         cellRxSOF         : out std_logic;                                 -- Cell data start of frame
         cellRxEOC         : out std_logic;                                 -- Cell data end of cell
         cellRxEOF         : out std_logic;                                 -- Cell data end of frame
         cellRxEOFE        : out std_logic;                                 -- Cell data end of frame error
         cellRxData        : out std_logic_vector(RxLaneCnt*16-1 downto 0); -- Cell data data
         phyRxPolarity     : out std_logic_vector(RxLaneCnt-1    downto 0); -- PHY receive signal polarity
         phyRxData         : in  std_logic_vector(RxLaneCnt*16-1 downto 0); -- PHY receive data
         phyRxDataK        : in  std_logic_vector(RxLaneCnt*2-1  downto 0); -- PHY receive data is K character
         phyRxDispErr      : in  std_logic_vector(RxLaneCnt*2-1  downto 0); -- PHY receive data has disparity error
         phyRxDecErr       : in  std_logic_vector(RxLaneCnt*2-1  downto 0); -- PHY receive data not in table
         phyRxReady        : in  std_logic;                                 -- PHY receive interface is ready
         phyRxInit         : out std_logic;
         debug             : out std_logic_vector(63 downto 0)
      );
   end component;

   -- Cell Receiver
   component Pgp2RxCell
      generic (
         RxLaneCnt     : integer := 4;
         EnShortCells  : integer := 1;
         PayloadCntTop : integer := 7
      );
      port (
         pgpRxClk          : in  std_logic;                                 -- Master clock
         pgpRxReset        : in  std_logic;                                 -- Synchronous reset input
         pgpRxFlush        : in  std_logic;                                 -- Flush the link
         pgpRxLinkReady    : in  std_logic;                                 -- Local side has link
         pgpRxCellError    : out std_logic;                                 -- A cell error has occured
         cellRxPause       : in  std_logic;                                 -- Cell data pause
         cellRxSOC         : in  std_logic;                                 -- Cell data start of cell
         cellRxSOF         : in  std_logic;                                 -- Cell data start of frame
         cellRxEOC         : in  std_logic;                                 -- Cell data end of cell
         cellRxEOF         : in  std_logic;                                 -- Cell data end of frame
         cellRxEOFE        : in  std_logic;                                 -- Cell data end of frame error
         cellRxData        : in  std_logic_vector(RxLaneCnt*16-1 downto 0); -- Cell data data
         vcFrameRxSOF      : out std_logic;                                 -- PGP frame data start of frame
         vcFrameRxEOF      : out std_logic;                                 -- PGP frame data end of frame
         vcFrameRxEOFE     : out std_logic;                                 -- PGP frame data error
         vcFrameRxData     : out std_logic_vector(RxLaneCnt*16-1 downto 0); -- PGP frame data
         vc0FrameRxValid   : out std_logic;                                 -- PGP frame data is valid
         vc0RemBuffAFull   : out std_logic;                                 -- Remote buffer almost full
         vc0RemBuffFull    : out std_logic;                                 -- Remote buffer full
         vc1FrameRxValid   : out std_logic;                                 -- PGP frame data is valid
         vc1RemBuffAFull   : out std_logic;                                 -- Remote buffer almost full
         vc1RemBuffFull    : out std_logic;                                 -- Remote buffer full
         vc2FrameRxValid   : out std_logic;                                 -- PGP frame data is valid
         vc2RemBuffAFull   : out std_logic;                                 -- Remote buffer almost full
         vc2RemBuffFull    : out std_logic;                                 -- Remote buffer full
         vc3FrameRxValid   : out std_logic;                                 -- PGP frame data is valid
         vc3RemBuffAFull   : out std_logic;                                 -- Remote buffer almost full
         vc3RemBuffFull    : out std_logic;                                 -- Remote buffer full
         crcRxIn           : out std_logic_vector(RxLaneCnt*16-1 downto 0); -- Receive data for CRC
         crcRxWidth        : out std_logic;                                 -- Receive CRC width, 1=full, 0=32-bit
         crcRxInit         : out std_logic;                                 -- Receive CRC value init
         crcRxValid        : out std_logic;                                 -- Receive data for CRC is valid
         crcRxOut          : in  std_logic_vector(31 downto 0)              -- Receive calculated CRC value
      );
   end component;

   -- Phy Interface
   component Pgp2TxPhy
      generic (
         TxLaneCnt : integer  := 4  -- Number of receive lanes, 1-4
      );
      port (
         pgpTxClk          : in  std_logic;                                 -- Master clock
         pgpTxReset        : in  std_logic;                                 -- Synchronous reset input
         pgpTxLinkReady    : out std_logic;                                 -- Local side has link
         pgpTxOpCodeEn     : in  std_logic;                                 -- Opcode receive enable
         pgpTxOpCode       : in  std_logic_vector(7 downto 0);              -- Opcode receive value
         pgpLocLinkReady   : in  std_logic;                                 -- Far end side has link
         pgpLocData        : in  std_logic_vector(7 downto 0);              -- Far end side User Data
         cellTxSOC         : in  std_logic;                                 -- Cell data start of cell
         cellTxSOF         : in  std_logic;                                 -- Cell data start of frame
         cellTxEOC         : in  std_logic;                                 -- Cell data end of cell
         cellTxEOF         : in  std_logic;                                 -- Cell data end of frame
         cellTxEOFE        : in  std_logic;                                 -- Cell data end of frame error
         cellTxData        : in  std_logic_vector(TxLaneCnt*16-1 downto 0); -- Cell data data
         phyTxData         : out std_logic_vector(TxLaneCnt*16-1 downto 0); -- PHY receive data
         phyTxDataK        : out std_logic_vector(TxLaneCnt*2-1  downto 0); -- PHY receive data is K character
         phyTxReady        : in  std_logic;                                 -- PHY receive interface is ready
         debug             : out std_logic_vector(63 downto 0)
      );
   end component;

   -- Cell Transmit Block
   component Pgp2TxCell
      generic (
         TxLaneCnt     : integer := 4;
         PayloadCntTop : integer := 7
      );
      port (
         pgpTxClk          : in  std_logic;                                 -- Master clock
         pgpTxReset        : in  std_logic;                                 -- Synchronous reset input
         pgpTxLinkReady    : in  std_logic;                                 -- Local side has link
         cellTxSOC         : out std_logic;                                 -- Cell data start of cell
         cellTxSOF         : out std_logic;                                 -- Cell data start of frame
         cellTxEOC         : out std_logic;                                 -- Cell data end of cell
         cellTxEOF         : out std_logic;                                 -- Cell data end of frame
         cellTxEOFE        : out std_logic;                                 -- Cell data end of frame error
         cellTxData        : out std_logic_vector(TxLaneCnt*16-1 downto 0); -- Cell data data
         schTxSOF          : out std_logic;                                 -- Cell contained SOF
         schTxEOF          : out std_logic;                                 -- Cell contained EOF
         schTxIdle         : in  std_logic;                                 -- Force IDLE transmit
         schTxReq          : in  std_logic;                                 -- Cell transmit request
         schTxAck          : out std_logic;                                 -- Cell transmit acknowledge
         schTxTimeout      : in  std_logic;                                 -- Cell transmit timeout
         schTxDataVc       : in  std_logic_vector(1 downto 0);              -- Cell transmit virtual channel
         vc0FrameTxValid   : in  std_logic;                                 -- User frame data is valid
         vc0FrameTxReady   : out std_logic;                                 -- PGP is ready
         vc0FrameTxSOF     : in  std_logic;                                 -- User frame data start of frame
         vc0FrameTxEOF     : in  std_logic;                                 -- User frame data end of frame
         vc0FrameTxEOFE    : in  std_logic;                                 -- User frame data error
         vc0FrameTxData    : in  std_logic_vector(TxLaneCnt*16-1 downto 0); -- User frame data
         vc0LocBuffAFull   : in  std_logic;                                 -- Remote buffer almost full
         vc0LocBuffFull    : in  std_logic;                                 -- Remote buffer full
         vc1FrameTxValid   : in  std_logic;                                 -- User frame data is valid
         vc1FrameTxReady   : out std_logic;                                 -- PGP is ready
         vc1FrameTxSOF     : in  std_logic;                                 -- User frame data start of frame
         vc1FrameTxEOF     : in  std_logic;                                 -- User frame data end of frame
         vc1FrameTxEOFE    : in  std_logic;                                 -- User frame data error
         vc1FrameTxData    : in  std_logic_vector(TxLaneCnt*16-1 downto 0); -- User frame data
         vc1LocBuffAFull   : in  std_logic;                                 -- Remote buffer almost full
         vc1LocBuffFull    : in  std_logic;                                 -- Remote buffer full
         vc2FrameTxValid   : in  std_logic;                                 -- User frame data is valid
         vc2FrameTxReady   : out std_logic;                                 -- PGP is ready
         vc2FrameTxSOF     : in  std_logic;                                 -- User frame data start of frame
         vc2FrameTxEOF     : in  std_logic;                                 -- User frame data end of frame
         vc2FrameTxEOFE    : in  std_logic;                                 -- User frame data error
         vc2FrameTxData    : in  std_logic_vector(TxLaneCnt*16-1 downto 0); -- User frame data
         vc2LocBuffAFull   : in  std_logic;                                 -- Remote buffer almost full
         vc2LocBuffFull    : in  std_logic;                                 -- Remote buffer full
         vc3FrameTxValid   : in  std_logic;                                 -- User frame data is valid
         vc3FrameTxReady   : out std_logic;                                 -- PGP is ready
         vc3FrameTxSOF     : in  std_logic;                                 -- User frame data start of frame
         vc3FrameTxEOF     : in  std_logic;                                 -- User frame data end of frame
         vc3FrameTxEOFE    : in  std_logic;                                 -- User frame data error
         vc3FrameTxData    : in  std_logic_vector(TxLaneCnt*16-1 downto 0); -- User frame data
         vc3LocBuffAFull   : in  std_logic;                                 -- Remote buffer almost full
         vc3LocBuffFull    : in  std_logic;                                 -- Remote buffer full
         crcTxIn           : out std_logic_vector(TxLaneCnt*16-1 downto 0); -- Transmit data for CRC
         crcTxInit         : out std_logic;                                 -- Transmit CRC value init
         crcTxValid        : out std_logic;                                 -- Transmit data for CRC is valid
         crcTxOut          : in  std_logic_vector(31 downto 0)              -- Transmit calculated CRC value
      );
   end component;

   -- Scheduler
   component Pgp2TxSched
      generic (
         VcInterleave : integer := 1  -- Interleave Frames
      );
      port (
         pgpTxClk          : in  std_logic;                     -- Master clock
         pgpTxReset        : in  std_logic;                     -- Synchronous reset input
         pgpTxFlush        : in  std_logic;                     -- Transmit state flush
         pgpTxLinkReady    : in  std_logic;                     -- Local side has link
         schTxSOF          : in  std_logic;                     -- Cell contained SOF
         schTxEOF          : in  std_logic;                     -- Cell contained EOF
         schTxIdle         : out std_logic;                     -- Force IDLE transmit
         schTxReq          : out std_logic;                     -- Cell transmit request
         schTxAck          : in  std_logic;                     -- Cell transmit acknowledge
         schTxTimeout      : out std_logic;                     -- Cell transmit timeout
         schTxDataVc       : out std_logic_vector(1 downto 0);  -- Cell transmit virtual channel
         vc0FrameTxValid   : in  std_logic;                     -- User frame data is valid
         vc1FrameTxValid   : in  std_logic;                     -- User frame data is valid
         vc2FrameTxValid   : in  std_logic;                     -- User frame data is valid
         vc3FrameTxValid   : in  std_logic                      -- User frame data is valid
      );
   end component;

end Pgp2CorePackage;

