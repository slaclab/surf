-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, MGT Package
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2TbPackage.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 11/23/2009
-------------------------------------------------------------------------------
-- Description:
-- MGT Components package.
-------------------------------------------------------------------------------
-- Copyright (c) 2006 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 11/23/2009: created.
-- 01/13/2010: Added received init line to help linking.
-------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package Pgp2TbPackage is

   -- 16-bit wrapper
   component Pgp2Mgt16Model 
      generic (
         EnShortCells : integer := 1;         -- Enable short non-EOF cells
         VcInterleave : integer := 1;         -- Interleave Frames
         MgtMode      : string  := "A";       -- Default Location
         RefClkSel    : string  := "REFCLK1"  -- Reference Clock To Use "REFCLK1" or "REFCLK2"
      );
      port (
         pgpClk            : in  std_logic;                     -- 156.25Mhz master clock
         pgpReset          : in  std_logic;                     -- Synchronous reset input
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
         mgtLoopback       : in  std_logic;                     -- MGT Serial Loopback Control
         mgtRefClk1        : in  std_logic;                     -- MGT Reference Clock In 1
         mgtRefClk2        : in  std_logic;                     -- MGT Reference Clock In 2
         mgtRxRecClk       : out std_logic;                     -- MGT Rx Recovered Clock
         mgtRxN            : in  std_logic;                     -- MGT Serial Receive Negative
         mgtRxP            : in  std_logic;                     -- MGT Serial Receive Positive
         mgtTxN            : out std_logic;                     -- MGT Serial Transmit Negative
         mgtTxP            : out std_logic;                     -- MGT Serial Transmit Positive
         mgtCombusIn       : in  std_logic_vector(15 downto 0);
         mgtCombusOut      : out std_logic_vector(15 downto 0)
      );
   end component;

end Pgp2TbPackage;


