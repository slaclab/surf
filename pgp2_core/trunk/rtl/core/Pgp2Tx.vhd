-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, Top Level Transmit Interface
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2Tx.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/18/2009
-------------------------------------------------------------------------------
-- Description:
-- Top Level Transmit interface module for the Pretty Good Protocol core. 
-------------------------------------------------------------------------------
-- Copyright (c) 2006 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 05/18/2009: created.
-- 11/23/2009: Renamed package.
-- 01/13/2010: Added received init line to help linking.
-- 06/25/2010: Added payload size config as generic.
-- 05/18/2012: Added VC transmit timeout
-------------------------------------------------------------------------------

LIBRARY ieee;
--USE work.ALL;
USE work.Pgp2CorePackage.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Pgp2Tx is 
   generic (
      TxLaneCnt     : integer := 4; -- Number of receive lanes, 1-4
      VcInterleave  : integer := 1; -- Interleave Frames
      PayloadCntTop : integer := 7;  -- Top bit for payload counter
      NUM_VC_EN_G : integer range 1 to 4 := 4
   );
   port ( 

      -- System clock, reset & control
      pgpTxClk          : in  std_logic;                                 -- Master clock
      pgpTxReset        : in  std_logic;                                 -- Synchronous reset input

      -- Link flush
      pgpTxFlush        : in  std_logic;                                 -- Flush the link

      -- Link is ready
      pgpTxLinkReady    : out std_logic;                                 -- Local side has link

      -- Opcode Transmit Interface
      pgpTxOpCodeEn     : in  std_logic;                                 -- Opcode receive enable
      pgpTxOpCode       : in  std_logic_vector(7 downto 0);              -- Opcode receive value

      -- Sideband data
      pgpLocLinkReady   : in  std_logic;                                 -- Far end side has link
      pgpLocData        : in  std_logic_vector(7 downto 0);              -- Far end side User Data

      -- Frame Transmit Interface, VC 0
      vc0FrameTxValid   : in  std_logic;                                 -- User frame data is valid
      vc0FrameTxReady   : out std_logic;                                 -- PGP is ready
      vc0FrameTxSOF     : in  std_logic;                                 -- User frame data start of frame
      vc0FrameTxEOF     : in  std_logic;                                 -- User frame data end of frame
      vc0FrameTxEOFE    : in  std_logic;                                 -- User frame data error
      vc0FrameTxData    : in  std_logic_vector(TxLaneCnt*16-1 downto 0); -- User frame data
      vc0LocBuffAFull   : in  std_logic;                                 -- Remote buffer almost full
      vc0LocBuffFull    : in  std_logic;                                 -- Remote buffer full

      -- Frame Transmit Interface, VC 1
      vc1FrameTxValid   : in  std_logic;                                 -- User frame data is valid
      vc1FrameTxReady   : out std_logic;                                 -- PGP is ready
      vc1FrameTxSOF     : in  std_logic;                                 -- User frame data start of frame
      vc1FrameTxEOF     : in  std_logic;                                 -- User frame data end of frame
      vc1FrameTxEOFE    : in  std_logic;                                 -- User frame data error
      vc1FrameTxData    : in  std_logic_vector(TxLaneCnt*16-1 downto 0); -- User frame data
      vc1LocBuffAFull   : in  std_logic;                                 -- Remote buffer almost full
      vc1LocBuffFull    : in  std_logic;                                 -- Remote buffer full

      -- Frame Transmit Interface, VC 2
      vc2FrameTxValid   : in  std_logic;                                 -- User frame data is valid
      vc2FrameTxReady   : out std_logic;                                 -- PGP is ready
      vc2FrameTxSOF     : in  std_logic;                                 -- User frame data start of frame
      vc2FrameTxEOF     : in  std_logic;                                 -- User frame data end of frame
      vc2FrameTxEOFE    : in  std_logic;                                 -- User frame data error
      vc2FrameTxData    : in  std_logic_vector(TxLaneCnt*16-1 downto 0); -- User frame data
      vc2LocBuffAFull   : in  std_logic;                                 -- Remote buffer almost full
      vc2LocBuffFull    : in  std_logic;                                 -- Remote buffer full

      -- Frame Transmit Interface, VC 3
      vc3FrameTxValid   : in  std_logic;                                 -- User frame data is valid
      vc3FrameTxReady   : out std_logic;                                 -- PGP is ready
      vc3FrameTxSOF     : in  std_logic;                                 -- User frame data start of frame
      vc3FrameTxEOF     : in  std_logic;                                 -- User frame data end of frame
      vc3FrameTxEOFE    : in  std_logic;                                 -- User frame data error
      vc3FrameTxData    : in  std_logic_vector(TxLaneCnt*16-1 downto 0); -- User frame data
      vc3LocBuffAFull   : in  std_logic;                                 -- Remote buffer almost full
      vc3LocBuffFull    : in  std_logic;                                 -- Remote buffer full

      -- Physical Interface
      phyTxData         : out std_logic_vector(TxLaneCnt*16-1 downto 0); -- PHY receive data
      phyTxDataK        : out std_logic_vector(TxLaneCnt*2-1  downto 0); -- PHY receive data is K character
      phyTxReady        : in  std_logic;                                 -- PHY receive interface is ready

      -- Transmit CRC Interface
      crcTxIn           : out std_logic_vector(TxLaneCnt*16-1 downto 0); -- Transmit data for CRC
      crcTxInit         : out std_logic;                                 -- Transmit CRC value init
      crcTxValid        : out std_logic;                                 -- Transmit data for CRC is valid
      crcTxOut          : in  std_logic_vector(31 downto 0);             -- Transmit calculated CRC value

      -- Debug
      debug             : out std_logic_vector(63 downto 0)
   );

end Pgp2Tx;


-- Define architecture
architecture Pgp2Tx of Pgp2Tx is

   -- Local Signals
   signal cellTxSOC         : std_logic;
   signal cellTxSOF         : std_logic;
   signal cellTxEOC         : std_logic;
   signal cellTxEOF         : std_logic;
   signal cellTxEOFE        : std_logic;
   signal cellTxData        : std_logic_vector(TxLaneCnt*16-1 downto 0);
   signal schTxSOF          : std_logic;
   signal schTxEOF          : std_logic;
   signal schTxIdle         : std_logic;
   signal schTxReq          : std_logic;
   signal schTxAck          : std_logic;
   signal schTxDataVc       : std_logic_vector(1 downto 0);
   signal intTxLinkReady    : std_logic;
   signal schTxTimeout      : std_logic;

begin

   -- Link Ready
   pgpTxLinkReady <= intTxLinkReady;

   -- Physical Interface
   U_Pgp2TxPhy: entity work.Pgp2TxPhy 
      generic map (
         TxLaneCnt         => TxLaneCnt
      ) port map ( 
         pgpTxClk          => pgpTxClk,
         pgpTxReset        => pgpTxReset,
         pgpTxLinkReady    => intTxLinkReady,
         pgpTxOpCodeEn     => pgpTxOpCodeEn,
         pgpTxOpCode       => pgpTxOpCode,
         pgpLocLinkReady   => pgpLocLinkReady,
         pgpLocData        => pgpLocData,
         cellTxSOC         => cellTxSOC,
         cellTxSOF         => cellTxSOF,
         cellTxEOC         => cellTxEOC,
         cellTxEOF         => cellTxEOF,
         cellTxEOFE        => cellTxEOFE,
         cellTxData        => cellTxData,
         phyTxData         => phyTxData,
         phyTxDataK        => phyTxDataK,
         phyTxReady        => phyTxReady,
         debug             => debug
      ); 


   -- Scheduler
   U_Pgp2TxSched: entity work.Pgp2TxSched 
      generic map (
         VcInterleave      => VcInterleave,
         NUM_VC_EN_G => NUM_VC_EN_G
      ) port map ( 
         pgpTxClk          => pgpTxClk,
         pgpTxReset        => pgpTxReset,
         pgpTxFlush        => pgpTxFlush,
         pgpTxLinkReady    => intTxLinkReady,
         schTxSOF          => schTxSOF,
         schTxEOF          => schTxEOF,
         schTxIdle         => schTxIdle,
         schTxReq          => schTxReq,
         schTxAck          => schTxAck,
         schTxDataVc       => schTxDataVc,
         schTxTimeout      => schTxTimeout,
         vc0FrameTxValid   => vc0FrameTxValid,
         vc1FrameTxValid   => vc1FrameTxValid,
         vc2FrameTxValid   => vc2FrameTxValid,
         vc3FrameTxValid   => vc3FrameTxValid
      );


   -- Cell Transmitter
   U_Pgp2TxCell: entity work.Pgp2TxCell 
      generic map (
         TxLaneCnt         => TxLaneCnt
      ) port map ( 
         pgpTxClk          => pgpTxClk,
         pgpTxReset        => pgpTxReset,
         pgpTxLinkReady    => intTxLinkReady,
         cellTxSOC         => cellTxSOC,
         cellTxSOF         => cellTxSOF,
         cellTxEOC         => cellTxEOC,
         cellTxEOF         => cellTxEOF,
         cellTxEOFE        => cellTxEOFE,
         cellTxData        => cellTxData,
         schTxSOF          => schTxSOF,
         schTxEOF          => schTxEOF,
         schTxIdle         => schTxIdle,
         schTxReq          => schTxReq,
         schTxAck          => schTxAck,
         schTxTimeout      => schTxTimeout,
         schTxDataVc       => schTxDataVc,
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
         crcTxIn           => crcTxIn,
         crcTxInit         => crcTxInit,
         crcTxValid        => crcTxValid,
         crcTxOut          => crcTxOut
      );

end Pgp2Tx;

