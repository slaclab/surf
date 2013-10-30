-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, Receive Top Level
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2Rx.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/18/2009
-------------------------------------------------------------------------------
-- Description:
-- Cell Receive interface module for the Pretty Good Protocol core. 
-------------------------------------------------------------------------------
-- Copyright (c) 2006 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 05/18/2009: created.
-- 11/23/2009: Renamed package.
-- 01/13/2010: Added received init line to help linking.
-- 06/25/2010: Added payload size config as generic.
-------------------------------------------------------------------------------

LIBRARY ieee;
--USE work.ALL;
USE work.Pgp2CorePackage.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Pgp2Rx is 
   generic (
      RxLaneCnt     : integer := 4; -- Number of receive lanes, 1-4
      EnShortCells  : integer := 1; -- Enable short non-EOF cells
      PayloadCntTop : integer := 7  -- Top bit for payload counter
   );
   port (

      -- System clock, reset & control
      pgpRxClk          : in  std_logic;                                 -- Master clock
      pgpRxReset        : in  std_logic;                                 -- Synchronous reset input

      -- Link flush
      pgpRxFlush        : in  std_logic;                                 -- Flush the link

      -- Link is ready
      pgpRxLinkReady    : out std_logic;                                 -- Local side has link

      -- Error Flags, one pulse per event
      pgpRxCellError    : out std_logic;                                 -- A cell error has occured
      pgpRxLinkDown     : out std_logic;                                 -- A link down event has occured
      pgpRxLinkError    : out std_logic;                                 -- A link error has occured

      -- Opcode Receive Interface
      pgpRxOpCodeEn     : out std_logic;                                 -- Opcode receive enable
      pgpRxOpCode       : out std_logic_vector(7 downto 0);              -- Opcode receive value

      -- Sideband data
      pgpRemLinkReady   : out std_logic;                                 -- Far end side has link
      pgpRemData        : out std_logic_vector(7 downto 0);              -- Far end side User Data

      -- Common Frame Receive Interface For All VCs
      vcFrameRxSOF      : out std_logic;                                 -- PGP frame data start of frame
      vcFrameRxEOF      : out std_logic;                                 -- PGP frame data end of frame
      vcFrameRxEOFE     : out std_logic;                                 -- PGP frame data error
      vcFrameRxData     : out std_logic_vector(RxLaneCnt*16-1 downto 0); -- PGP frame data

      -- Frame Receive Interface, VC 0
      vc0FrameRxValid   : out std_logic;                                 -- PGP frame data is valid
      vc0RemBuffAFull   : out std_logic;                                 -- Remote buffer almost full
      vc0RemBuffFull    : out std_logic;                                 -- Remote buffer full

      -- Frame Receive Interface, VC 1
      vc1FrameRxValid   : out std_logic;                                 -- PGP frame data is valid
      vc1RemBuffAFull   : out std_logic;                                 -- Remote buffer almost full
      vc1RemBuffFull    : out std_logic;                                 -- Remote buffer full

      -- Frame Receive Interface, VC 2
      vc2FrameRxValid   : out std_logic;                                 -- PGP frame data is valid
      vc2RemBuffAFull   : out std_logic;                                 -- Remote buffer almost full
      vc2RemBuffFull    : out std_logic;                                 -- Remote buffer full

      -- Frame Receive Interface, VC 3
      vc3FrameRxValid   : out std_logic;                                 -- PGP frame data is valid
      vc3RemBuffAFull   : out std_logic;                                 -- Remote buffer almost full
      vc3RemBuffFull    : out std_logic;                                 -- Remote buffer full

      -- Physical Interface Signals
      phyRxPolarity     : out std_logic_vector(RxLaneCnt-1    downto 0); -- PHY receive signal polarity
      phyRxData         : in  std_logic_vector(RxLaneCnt*16-1 downto 0); -- PHY receive data
      phyRxDataK        : in  std_logic_vector(RxLaneCnt*2-1  downto 0); -- PHY receive data is K character
      phyRxDispErr      : in  std_logic_vector(RxLaneCnt*2-1  downto 0); -- PHY receive data has disparity error
      phyRxDecErr       : in  std_logic_vector(RxLaneCnt*2-1  downto 0); -- PHY receive data not in table
      phyRxReady        : in  std_logic;                                 -- PHY receive interface is ready
      phyRxInit         : out std_logic;

      -- Receive CRC Interface
      crcRxIn           : out std_logic_vector(RxLaneCnt*16-1 downto 0); -- Receive data for CRC
      crcRxWidth        : out std_logic;                                 -- Receive CRC width, 1=full, 0=32-bit
      crcRxInit         : out std_logic;                                 -- Receive CRC value init
      crcRxValid        : out std_logic;                                 -- Receive data for CRC is valid
      crcRxOut          : in  std_logic_vector(31 downto 0);             -- Receive calculated CRC value

      -- Debug
      debug             : out std_logic_vector(63 downto 0)
   );

end Pgp2Rx;


-- Define architecture
architecture Pgp2Rx of Pgp2Rx is

   -- Local Signals
   signal cellRxPause      : std_logic;
   signal cellRxSOC        : std_logic;
   signal cellRxSOF        : std_logic;
   signal cellRxEOC        : std_logic;
   signal cellRxEOF        : std_logic;
   signal cellRxEOFE       : std_logic;
   signal cellRxData       : std_logic_vector(RxLaneCnt*16-1 downto 0);
   signal intRxLinkReady   : std_logic;

begin

   -- Link Ready
   pgpRxLinkReady <= intRxLinkReady;

   -- PHY Logic
   U_Pgp2RxPhy: entity work.Pgp2RxPhy 
      generic map ( 
         RxLaneCnt        => RxLaneCnt
      ) port map (
         pgpRxClk         => pgpRxClk,
         pgpRxReset       => pgpRxReset,
         pgpRxLinkReady   => intRxLinkReady,
         pgpRxLinkDown    => pgpRxLinkDown,
         pgpRxLinkError   => pgpRxLinkError,
         pgpRxOpCodeEn    => pgpRxOpCodeEn,
         pgpRxOpCode      => pgpRxOpCode,
         pgpRemLinkReady  => pgpRemLinkReady,
         pgpRemData       => pgpRemData,
         cellRxPause      => cellRxPause,
         cellRxSOC        => cellRxSOC,
         cellRxSOF        => cellRxSOF,
         cellRxEOC        => cellRxEOC,
         cellRxEOF        => cellRxEOF,
         cellRxEOFE       => cellRxEOFE,
         cellRxData       => cellRxData,
         phyRxPolarity    => phyRxPolarity,
         phyRxData        => phyRxData,
         phyRxDataK       => phyRxDataK,
         phyRxDispErr     => phyRxDispErr,
         phyRxDecErr      => phyRxDecErr,
         phyRxReady       => phyRxReady,
         phyRxInit        => phyRxInit,
         debug            => debug
      ); 


   -- Cell Receiver
   U_Pgp2RxCell: entity work.Pgp2RxCell 
      generic map ( 
         RxLaneCnt        => RxLaneCnt, 
         EnShortCells     => EnShortCells,
         PayloadCntTop    => PayloadCntTop
      ) port map (
         pgpRxClk         => pgpRxClk,
         pgpRxReset       => pgpRxReset,
         pgpRxFlush       => pgpRxFlush,
         pgpRxLinkReady   => intRxLinkReady,
         pgpRxCellError   => pgpRxCellError,
         cellRxPause      => cellRxPause,
         cellRxSOC        => cellRxSOC,
         cellRxSOF        => cellRxSOF,
         cellRxEOC        => cellRxEOC,
         cellRxEOF        => cellRxEOF,
         cellRxEOFE       => cellRxEOFE,
         cellRxData       => cellRxData,
         vcFrameRxSOF     => vcFrameRxSOF,
         vcFrameRxEOF     => vcFrameRxEOF,
         vcFrameRxEOFE    => vcFrameRxEOFE,
         vcFrameRxData    => vcFrameRxData,
         vc0FrameRxValid  => vc0FrameRxValid,
         vc0RemBuffAFull  => vc0RemBuffAFull,
         vc0RemBuffFull   => vc0RemBuffFull,
         vc1FrameRxValid  => vc1FrameRxValid,
         vc1RemBuffAFull  => vc1RemBuffAFull,
         vc1RemBuffFull   => vc1RemBuffFull,
         vc2FrameRxValid  => vc2FrameRxValid,
         vc2RemBuffAFull  => vc2RemBuffAFull,
         vc2RemBuffFull   => vc2RemBuffFull,
         vc3FrameRxValid  => vc3FrameRxValid,
         vc3RemBuffAFull  => vc3RemBuffAFull,
         vc3RemBuffFull   => vc3RemBuffFull,
         crcRxIn          => crcRxIn,
         crcRxWidth       => crcRxWidth,
         crcRxInit        => crcRxInit,
         crcRxValid       => crcRxValid,
         crcRxOut         => crcRxOut
      );

end Pgp2Rx;

