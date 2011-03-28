-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, GTX Package
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2GtxPackage.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 11/23/2009
-------------------------------------------------------------------------------
-- Description:
-- GTX Components package.
-------------------------------------------------------------------------------
-- Copyright (c) 2006 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 11/23/2009: created.
-- 01/13/2010: Added received init line to help linking.
-------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package Pgp2GtxPackage is

   -- 16-bit wrapper
   component Pgp2Gtx16 
      generic (
         EnShortCells : integer := 1;         -- Enable short non-EOF cells
         VcInterleave : integer := 1          -- Interleave Frames
      );
      port (
         pgpClk            : in  std_logic;                     -- 156.25Mhz master clock
         pgpReset          : in  std_logic;                     -- Synchronous reset input
         pgpFlush          : in  std_logic;                     -- Frame state flush
         pllTxRst          : in  std_logic;                     -- Reset transmit PLL logic
         pllRxRst          : in  std_logic;                     -- Reset receive  PLL logic
         pllRxReady        : out std_logic;                     -- MGT Receive logic is ready
         pllTxReady        : out std_logic;                     -- MGT Transmit logic is ready
         pgpRemData        : out std_logic_vector(7 downto 0);  -- Far end side User Data
         pgpLocData        : in  std_logic_vector(7 downto 0);  -- Far end side User Data
         pgpTxOpCodeEn     : in  std_logic;                     -- Opcode receive enable
         pgpTxOpCode       : in  std_logic_vector(7 downto 0);  -- Opcode receive value
         pgpRxOpCodeEn     : out std_logic;                     -- Opcode receive enable
         pgpRxOpCode       : out std_logic_vector(7 downto 0);  -- Opcode receive value
         pgpLocLinkReady   : out std_logic;                     -- Local Link is ready
         pgpRemLinkReady   : out std_logic;                     -- Far end side has link
         pgpRxCellError    : out std_logic;                     -- A cell error has occured
         pgpRxLinkDown     : out std_logic;                     -- A link down event has occured
         pgpRxLinkError    : out std_logic;                     -- A link error has occured
         vc0FrameTxValid   : in  std_logic;                     -- User frame data is valid
         vc0FrameTxReady   : out std_logic;                     -- PGP is ready
         vc0FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
         vc0FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
         vc0FrameTxEOFE    : in  std_logic;                     -- User frame data error
         vc0FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
         vc0LocBuffAFull   : in  std_logic;                     -- Remote buffer almost full
         vc0LocBuffFull    : in  std_logic;                     -- Remote buffer full
         vc1FrameTxValid   : in  std_logic;                     -- User frame data is valid
         vc1FrameTxReady   : out std_logic;                     -- PGP is ready
         vc1FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
         vc1FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
         vc1FrameTxEOFE    : in  std_logic;                     -- User frame data error
         vc1FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
         vc1LocBuffAFull   : in  std_logic;                     -- Remote buffer almost full
         vc1LocBuffFull    : in  std_logic;                     -- Remote buffer full
         vc2FrameTxValid   : in  std_logic;                     -- User frame data is valid
         vc2FrameTxReady   : out std_logic;                     -- PGP is ready
         vc2FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
         vc2FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
         vc2FrameTxEOFE    : in  std_logic;                     -- User frame data error
         vc2FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
         vc2LocBuffAFull   : in  std_logic;                     -- Remote buffer almost full
         vc2LocBuffFull    : in  std_logic;                     -- Remote buffer full
         vc3FrameTxValid   : in  std_logic;                     -- User frame data is valid
         vc3FrameTxReady   : out std_logic;                     -- PGP is ready
         vc3FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
         vc3FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
         vc3FrameTxEOFE    : in  std_logic;                     -- User frame data error
         vc3FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
         vc3LocBuffAFull   : in  std_logic;                     -- Remote buffer almost full
         vc3LocBuffFull    : in  std_logic;                     -- Remote buffer full
         vcFrameRxSOF      : out std_logic;                     -- PGP frame data start of frame
         vcFrameRxEOF      : out std_logic;                     -- PGP frame data end of frame
         vcFrameRxEOFE     : out std_logic;                     -- PGP frame data error
         vcFrameRxData     : out std_logic_vector(15 downto 0); -- PGP frame data
         vc0FrameRxValid   : out std_logic;                     -- PGP frame data is valid
         vc0RemBuffAFull   : out std_logic;                     -- Remote buffer almost full
         vc0RemBuffFull    : out std_logic;                     -- Remote buffer full
         vc1FrameRxValid   : out std_logic;                     -- PGP frame data is valid
         vc1RemBuffAFull   : out std_logic;                     -- Remote buffer almost full
         vc1RemBuffFull    : out std_logic;                     -- Remote buffer full
         vc2FrameRxValid   : out std_logic;                     -- PGP frame data is valid
         vc2RemBuffAFull   : out std_logic;                     -- Remote buffer almost full
         vc2RemBuffFull    : out std_logic;                     -- Remote buffer full
         vc3FrameRxValid   : out std_logic;                     -- PGP frame data is valid
         vc3RemBuffAFull   : out std_logic;                     -- Remote buffer almost full
         vc3RemBuffFull    : out std_logic;                     -- Remote buffer full
         gtxLoopback       : in  std_logic;                     -- GTX Serial Loopback Control
         gtxClkIn          : in  std_logic;                     -- GTX Reference Clock In
         gtxRefClkOut      : out std_logic;                     -- GTX Reference Clock Output
         gtxRxRecClk       : out std_logic;                     -- GTX Rx Recovered Clock
         gtxRxN            : in  std_logic;                     -- GTX Serial Receive Negative
         gtxRxP            : in  std_logic;                     -- GTX Serial Receive Positive
         gtxTxN            : out std_logic;                     -- GTX Serial Transmit Negative
         gtxTxP            : out std_logic;                     -- GTX Serial Transmit Positive
         debug             : out std_logic_vector(63 downto 0)
      );
   end component;

   -- 16-bit wrapper, port b
   component Pgp2Gtx16B
      generic (
         EnShortCells : integer := 1;         -- Enable short non-EOF cells
         VcInterleave : integer := 1          -- Interleave Frames
      );
      port (
         pgpClk            : in  std_logic;                     -- 156.25Mhz master clock
         pgpReset          : in  std_logic;                     -- Synchronous reset input
         pgpFlush          : in  std_logic;                     -- Frame state flush
         pllTxRst          : in  std_logic;                     -- Reset transmit PLL logic
         pllRxRst          : in  std_logic;                     -- Reset receive  PLL logic
         pllRxReady        : out std_logic;                     -- MGT Receive logic is ready
         pllTxReady        : out std_logic;                     -- MGT Transmit logic is ready
         pgpRemData        : out std_logic_vector(7 downto 0);  -- Far end side User Data
         pgpLocData        : in  std_logic_vector(7 downto 0);  -- Far end side User Data
         pgpTxOpCodeEn     : in  std_logic;                     -- Opcode receive enable
         pgpTxOpCode       : in  std_logic_vector(7 downto 0);  -- Opcode receive value
         pgpRxOpCodeEn     : out std_logic;                     -- Opcode receive enable
         pgpRxOpCode       : out std_logic_vector(7 downto 0);  -- Opcode receive value
         pgpLocLinkReady   : out std_logic;                     -- Local Link is ready
         pgpRemLinkReady   : out std_logic;                     -- Far end side has link
         pgpRxCellError    : out std_logic;                     -- A cell error has occured
         pgpRxLinkDown     : out std_logic;                     -- A link down event has occured
         pgpRxLinkError    : out std_logic;                     -- A link error has occured
         vc0FrameTxValid   : in  std_logic;                     -- User frame data is valid
         vc0FrameTxReady   : out std_logic;                     -- PGP is ready
         vc0FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
         vc0FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
         vc0FrameTxEOFE    : in  std_logic;                     -- User frame data error
         vc0FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
         vc0LocBuffAFull   : in  std_logic;                     -- Remote buffer almost full
         vc0LocBuffFull    : in  std_logic;                     -- Remote buffer full
         vc1FrameTxValid   : in  std_logic;                     -- User frame data is valid
         vc1FrameTxReady   : out std_logic;                     -- PGP is ready
         vc1FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
         vc1FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
         vc1FrameTxEOFE    : in  std_logic;                     -- User frame data error
         vc1FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
         vc1LocBuffAFull   : in  std_logic;                     -- Remote buffer almost full
         vc1LocBuffFull    : in  std_logic;                     -- Remote buffer full
         vc2FrameTxValid   : in  std_logic;                     -- User frame data is valid
         vc2FrameTxReady   : out std_logic;                     -- PGP is ready
         vc2FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
         vc2FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
         vc2FrameTxEOFE    : in  std_logic;                     -- User frame data error
         vc2FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
         vc2LocBuffAFull   : in  std_logic;                     -- Remote buffer almost full
         vc2LocBuffFull    : in  std_logic;                     -- Remote buffer full
         vc3FrameTxValid   : in  std_logic;                     -- User frame data is valid
         vc3FrameTxReady   : out std_logic;                     -- PGP is ready
         vc3FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
         vc3FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
         vc3FrameTxEOFE    : in  std_logic;                     -- User frame data error
         vc3FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
         vc3LocBuffAFull   : in  std_logic;                     -- Remote buffer almost full
         vc3LocBuffFull    : in  std_logic;                     -- Remote buffer full
         vcFrameRxSOF      : out std_logic;                     -- PGP frame data start of frame
         vcFrameRxEOF      : out std_logic;                     -- PGP frame data end of frame
         vcFrameRxEOFE     : out std_logic;                     -- PGP frame data error
         vcFrameRxData     : out std_logic_vector(15 downto 0); -- PGP frame data
         vc0FrameRxValid   : out std_logic;                     -- PGP frame data is valid
         vc0RemBuffAFull   : out std_logic;                     -- Remote buffer almost full
         vc0RemBuffFull    : out std_logic;                     -- Remote buffer full
         vc1FrameRxValid   : out std_logic;                     -- PGP frame data is valid
         vc1RemBuffAFull   : out std_logic;                     -- Remote buffer almost full
         vc1RemBuffFull    : out std_logic;                     -- Remote buffer full
         vc2FrameRxValid   : out std_logic;                     -- PGP frame data is valid
         vc2RemBuffAFull   : out std_logic;                     -- Remote buffer almost full
         vc2RemBuffFull    : out std_logic;                     -- Remote buffer full
         vc3FrameRxValid   : out std_logic;                     -- PGP frame data is valid
         vc3RemBuffAFull   : out std_logic;                     -- Remote buffer almost full
         vc3RemBuffFull    : out std_logic;                     -- Remote buffer full
         gtxLoopback       : in  std_logic;                     -- GTX Serial Loopback Control
         gtxClkIn          : in  std_logic;                     -- GTX Reference Clock In
         gtxRefClkOut      : out std_logic;                     -- GTX Reference Clock Output
         gtxRxRecClk       : out std_logic;                     -- GTX Rx Recovered Clock
         gtxRxN            : in  std_logic;                     -- GTX Serial Receive Negative
         gtxRxP            : in  std_logic;                     -- GTX Serial Receive Positive
         gtxTxN            : out std_logic;                     -- GTX Serial Transmit Negative
         gtxTxP            : out std_logic;                     -- GTX Serial Transmit Positive
         debug             : out std_logic_vector(63 downto 0)
      );
   end component;

   -- Dual Channel Wrapper
   component Pgp2GtxDual
      generic (
         EnShortCells : integer := 1;         -- Enable short non-EOF cells
         VcInterleave : integer := 1          -- Interleave Frames
      );
      port (
         pgpClk             : in  std_logic;                     -- Pgp master clock
         pgpReset           : in  std_logic;                     -- Synchronous reset input
         pgpFlush           : in  std_logic;                     -- Frame state flush
         pll0TxRst          : in  std_logic;                     -- Reset transmit PLL logic
         pll0RxRst          : in  std_logic;                     -- Reset receive  PLL logic
         pll0RxReady        : out std_logic;                     -- MGT Receive logic is ready
         pll0TxReady        : out std_logic;                     -- MGT Transmit logic is ready
         pgp0RemData        : out std_logic_vector(7 downto 0);  -- Far end side User Data
         pgp0LocData        : in  std_logic_vector(7 downto 0);  -- Far end side User Data
         pgp0TxOpCodeEn     : in  std_logic;                     -- Opcode receive enable
         pgp0TxOpCode       : in  std_logic_vector(7 downto 0);  -- Opcode receive value
         pgp0RxOpCodeEn     : out std_logic;                     -- Opcode receive enable
         pgp0RxOpCode       : out std_logic_vector(7 downto 0);  -- Opcode receive value
         pgp0LocLinkReady   : out std_logic;                     -- Local Link is ready
         pgp0RemLinkReady   : out std_logic;                     -- Far end side has link
         pgp0RxCellError    : out std_logic;                     -- A cell error has occured
         pgp0RxLinkDown     : out std_logic;                     -- A link down event has occured
         pgp0RxLinkError    : out std_logic;                     -- A link error has occured
         vc00FrameTxValid   : in  std_logic;                     -- User frame data is valid
         vc00FrameTxReady   : out std_logic;                     -- PGP is ready
         vc00FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
         vc00FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
         vc00FrameTxEOFE    : in  std_logic;                     -- User frame data error
         vc00FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
         vc00LocBuffAFull   : in  std_logic;                     -- Local buffer almost full
         vc00LocBuffFull    : in  std_logic;                     -- Local buffer full
         vc01FrameTxValid   : in  std_logic;                     -- User frame data is valid
         vc01FrameTxReady   : out std_logic;                     -- PGP is ready
         vc01FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
         vc01FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
         vc01FrameTxEOFE    : in  std_logic;                     -- User frame data error
         vc01FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
         vc01LocBuffAFull   : in  std_logic;                     -- Local buffer almost full
         vc01LocBuffFull    : in  std_logic;                     -- Local buffer full
         vc02FrameTxValid   : in  std_logic;                     -- User frame data is valid
         vc02FrameTxReady   : out std_logic;                     -- PGP is ready
         vc02FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
         vc02FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
         vc02FrameTxEOFE    : in  std_logic;                     -- User frame data error
         vc02FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
         vc02LocBuffAFull   : in  std_logic;                     -- Local buffer almost full
         vc02LocBuffFull    : in  std_logic;                     -- Local buffer full
         vc03FrameTxValid   : in  std_logic;                     -- User frame data is valid
         vc03FrameTxReady   : out std_logic;                     -- PGP is ready
         vc03FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
         vc03FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
         vc03FrameTxEOFE    : in  std_logic;                     -- User frame data error
         vc03FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
         vc03LocBuffAFull   : in  std_logic;                     -- Local buffer almost full
         vc03LocBuffFull    : in  std_logic;                     -- Local buffer full
         vc0FrameRxSOF      : out std_logic;                     -- PGP frame data start of frame
         vc0FrameRxEOF      : out std_logic;                     -- PGP frame data end of frame
         vc0FrameRxEOFE     : out std_logic;                     -- PGP frame data error
         vc0FrameRxData     : out std_logic_vector(15 downto 0); -- PGP frame data
         vc00FrameRxValid   : out std_logic;                     -- PGP frame data is valid
         vc00RemBuffAFull   : out std_logic;                     -- Remote buffer almost full
         vc00RemBuffFull    : out std_logic;                     -- Remote buffer full
         vc01FrameRxValid   : out std_logic;                     -- PGP frame data is valid
         vc01RemBuffAFull   : out std_logic;                     -- Remote buffer almost full
         vc01RemBuffFull    : out std_logic;                     -- Remote buffer full
         vc02FrameRxValid   : out std_logic;                     -- PGP frame data is valid
         vc02RemBuffAFull   : out std_logic;                     -- Remote buffer almost full
         vc02RemBuffFull    : out std_logic;                     -- Remote buffer full
         vc03FrameRxValid   : out std_logic;                     -- PGP frame data is valid
         vc03RemBuffAFull   : out std_logic;                     -- Remote buffer almost full
         vc03RemBuffFull    : out std_logic;                     -- Remote buffer full
         pll1TxRst          : in  std_logic;                     -- Reset transmit PLL logic
         pll1RxRst          : in  std_logic;                     -- Reset receive  PLL logic
         pll1RxReady        : out std_logic;                     -- MGT Receive logic is ready
         pll1TxReady        : out std_logic;                     -- MGT Transmit logic is ready
         pgp1RemData        : out std_logic_vector(7 downto 0);  -- Far end side User Data
         pgp1LocData        : in  std_logic_vector(7 downto 0);  -- Far end side User Data
         pgp1TxOpCodeEn     : in  std_logic;                     -- Opcode receive enable
         pgp1TxOpCode       : in  std_logic_vector(7 downto 0);  -- Opcode receive value
         pgp1RxOpCodeEn     : out std_logic;                     -- Opcode receive enable
         pgp1RxOpCode       : out std_logic_vector(7 downto 0);  -- Opcode receive value
         pgp1LocLinkReady   : out std_logic;                     -- Local Link is ready
         pgp1RemLinkReady   : out std_logic;                     -- Far end side has link
         pgp1RxCellError    : out std_logic;                     -- A cell error has occured
         pgp1RxLinkDown     : out std_logic;                     -- A link down event has occured
         pgp1RxLinkError    : out std_logic;                     -- A link error has occured
         vc10FrameTxValid   : in  std_logic;                     -- User frame data is valid
         vc10FrameTxReady   : out std_logic;                     -- PGP is ready
         vc10FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
         vc10FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
         vc10FrameTxEOFE    : in  std_logic;                     -- User frame data error
         vc10FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
         vc10LocBuffAFull   : in  std_logic;                     -- Local buffer almost full
         vc10LocBuffFull    : in  std_logic;                     -- Local buffer full
         vc11FrameTxValid   : in  std_logic;                     -- User frame data is valid
         vc11FrameTxReady   : out std_logic;                     -- PGP is ready
         vc11FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
         vc11FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
         vc11FrameTxEOFE    : in  std_logic;                     -- User frame data error
         vc11FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
         vc11LocBuffAFull   : in  std_logic;                     -- Local buffer almost full
         vc11LocBuffFull    : in  std_logic;                     -- Local buffer full
         vc12FrameTxValid   : in  std_logic;                     -- User frame data is valid
         vc12FrameTxReady   : out std_logic;                     -- PGP is ready
         vc12FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
         vc12FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
         vc12FrameTxEOFE    : in  std_logic;                     -- User frame data error
         vc12FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
         vc12LocBuffAFull   : in  std_logic;                     -- Local buffer almost full
         vc12LocBuffFull    : in  std_logic;                     -- Local buffer full
         vc13FrameTxValid   : in  std_logic;                     -- User frame data is valid
         vc13FrameTxReady   : out std_logic;                     -- PGP is ready
         vc13FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
         vc13FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
         vc13FrameTxEOFE    : in  std_logic;                     -- User frame data error
         vc13FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
         vc13LocBuffAFull   : in  std_logic;                     -- Local buffer almost full
         vc13LocBuffFull    : in  std_logic;                     -- Local buffer full
         vc1FrameRxSOF      : out std_logic;                     -- PGP frame data start of frame
         vc1FrameRxEOF      : out std_logic;                     -- PGP frame data end of frame
         vc1FrameRxEOFE     : out std_logic;                     -- PGP frame data error
         vc1FrameRxData     : out std_logic_vector(15 downto 0); -- PGP frame data
         vc10FrameRxValid   : out std_logic;                     -- PGP frame data is valid
         vc10RemBuffAFull   : out std_logic;                     -- Remote buffer almost full
         vc10RemBuffFull    : out std_logic;                     -- Remote buffer full
         vc11FrameRxValid   : out std_logic;                     -- PGP frame data is valid
         vc11RemBuffAFull   : out std_logic;                     -- Remote buffer almost full
         vc11RemBuffFull    : out std_logic;                     -- Remote buffer full
         vc12FrameRxValid   : out std_logic;                     -- PGP frame data is valid
         vc12RemBuffAFull   : out std_logic;                     -- Remote buffer almost full
         vc12RemBuffFull    : out std_logic;                     -- Remote buffer full
         vc13FrameRxValid   : out std_logic;                     -- PGP frame data is valid
         vc13RemBuffAFull   : out std_logic;                     -- Remote buffer almost full
         vc13RemBuffFull    : out std_logic;                     -- Remote buffer full
         gtxLoopback        : in  std_logic_vector(1 downto 0);  -- GTX Serial Loopback Control
         gtxClkIn           : in  std_logic;                     -- GTX Reference Clock In
         gtxRefClkOut       : out std_logic;                     -- GTX Reference Clock Output
         gtxRxRecClk        : out std_logic_vector(1 downto 0);  -- GTX Rx Recovered Clock
         gtxRxN             : in  std_logic_vector(1 downto 0);  -- GTX Serial Receive Negative
         gtxRxP             : in  std_logic_vector(1 downto 0);  -- GTX Serial Receive Positive
         gtxTxN             : out std_logic_vector(1 downto 0);  -- GTX Serial Transmit Negative
         gtxTxP             : out std_logic_vector(1 downto 0);  -- GTX Serial Transmit Positive
         debug              : out std_logic_vector(127 downto 0)
      );
   end component;

   -- PGP Clock Generator
   component Pgp2GtxClk 
      generic (
         UserFxDiv  : integer := 5; -- DCM FX Output Divide
         UserFxMult : integer := 4  -- DCM FX Output Divide, 4/5 * 156.25 = 125Mhz
      );
      port (
         pgpRefClk     : in  std_logic;
         ponResetL     : in  std_logic;
         locReset      : in  std_logic;
         pgpClk        : out std_logic;
         pgpReset      : out std_logic;
         userClk       : out std_logic;
         userReset     : out std_logic;
         pgpClkIn      : in  std_logic;
         userClkIn     : in  std_logic
      );
   end component;

   -- RX Reset Control
   component Pgp2GtxRxRst
      port (
         gtxRxClk          : in  std_logic;
         gtxRxRst          : in  std_logic;
         gtxRxReady        : out std_logic;
         gtxRxInit         : in  std_logic;
         gtxLockDetect     : in  std_logic;
         gtxRxBuffStatus   : in  std_logic_vector(2  downto 0);
         gtxRxElecIdle     : in  std_logic;
         gtxRstDone        : in  std_logic;
         gtxRxReset        : out std_logic;
         gtxRxCdrReset     : out std_logic
      );
   end component;

   -- TX Reset Control
   component Pgp2GtxTxRst
      port (
         gtxTxClk          : in  std_logic;
         gtxTxRst          : in  std_logic;
         gtxTxReady        : out std_logic;
         gtxLockDetect     : in  std_logic;
         gtxTxBuffStatus   : in  std_logic_vector(1  downto 0);
         gtxRstDone        : in  std_logic;
         gtxTxReset        : out std_logic
      );
   end component;

end Pgp2GtxPackage;

