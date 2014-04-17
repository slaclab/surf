-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, Top Level Transmit Interface
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2bTx.vhd
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
-- 04/04/2014: Changed to Pgp2b.
-------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.Pgp2bPkg.all;
use work.Vc64Pkg.all;

entity Pgp2bTx is 
   generic (
      TPD_G             : time                 := 1 ns;
      TX_LANE_CNT_G     : integer range 1 to 2 := 1; -- Number of receive lanes, 1-2
      VC_INTERLEAVE_G   : integer              := 1; -- Interleave Frames
      PAYLOAD_CNT_TOP_G : integer              := 7; -- Top bit for payload counter
      NUM_VC_EN_G       : integer range 1 to 4 := 4
   );
   port ( 

      -- System clock, reset & control
      pgpTxClk          : in  sl;    -- Master clock
      pgpTxClkRst       : in  sl;    -- Synchronous reset input

      -- Non-VC related IO
      pgpTxIn           : in  PgpTxInType;
      pgpTxOut          : out PgpTxOutType;

      -- VC Interface
      pgpTxVcData       : in  Vc64DataArray(3 downto 0);
      pgpTxVcCtrl       : out Vc64CtrlArray(3 downto 0);
      pgpTxLocVcCtrl    : in  Vc64CtrlArray(3 downto 0);

      -- Phy interface
      phyTxLanesOut     : out PgpTxPhyLaneOutArray(0 to TX_LANE_CNT_G-1);
      phyTxReady        : in  sl         
   );

end Pgp2bTx;


-- Define architecture
architecture Pgp2bTx of Pgp2bTx is

   -- Local Signals
   signal cellTxSOC         : sl;
   signal cellTxSOF         : sl;
   signal cellTxEOC         : sl;
   signal cellTxEOF         : sl;
   signal cellTxEOFE        : sl;
   signal cellTxData        : slv(TX_LANE_CNT_G*16-1 downto 0);
   signal schTxSOF          : sl;
   signal schTxEOF          : sl;
   signal schTxIdle         : sl;
   signal schTxReq          : sl;
   signal schTxAck          : sl;
   signal schTxDataVc       : slv(1 downto 0);
   signal intTxLinkReady    : sl;
   signal schTxTimeout      : sl;
   signal intPhyTxData      : slv(TX_LANE_CNT_G*16-1 downto 0);
   signal intPhyTxDataK     : slv(TX_LANE_CNT_G*2-1  downto 0);
   signal crcTxIn           : slv(TX_LANE_CNT_G*16-1 downto 0); -- Transmit data for CRC
   signal crcTxInit         : sl;                               -- Transmit CRC value init
   signal crcTxValid        : sl;                               -- Transmit data for CRC is valid
   signal crcTxOut          : slv(31 downto 0);                 -- Transmit calculated CRC value
   signal crcTxOutAdjust    : slv(31 downto 0);                 -- Transmit calculated CRC value
   signal crcTxRst          : sl;
   signal crcTxInAdjust     : slv(31 downto 0);
   signal crcTxWidthAdjust  : slv(2 downto 0);

begin

   Lane_Gen: for i in 0 to TX_LANE_CNT_G-1 generate
      phyTxLanesOut(i).data   <= intPhyTxData(16*i+15 downto 16*i);
      phyTxLanesOut(i).dataK  <= intPhyTxDataK(2*i+1 downto 2*i);
   end generate;

   Flow_Gen: for i in 0 to 3 generate
      pgpTxVcCtrl(i).almostFull <= '0';
      pgpTxVcCtrl(i).overflow   <= '0';
   end generate;

   -- Link Ready
   pgpTxOut.linkReady <= intTxLinkReady;

   -- Physical Interface
   U_Pgp2bTxPhy: entity work.Pgp2bTxPhy 
      generic map (
         TPD_G             => TPD_G,
         TX_LANE_CNT_G     => TX_LANE_CNT_G
      ) port map ( 
         pgpTxClk          => pgpTxClk,
         pgpTxClkRst       => pgpTxClkRst,
         pgpTxLinkReady    => intTxLinkReady,
         pgpTxOpCodeEn     => pgpTxIn.opCodeEn,
         pgpTxOpCode       => pgpTxIn.opCode,
         pgpLocLinkReady   => pgpTxIn.locLinkReady,
         pgpLocData        => pgpTxIn.locData,
         cellTxSOC         => cellTxSOC,
         cellTxSOF         => cellTxSOF,
         cellTxEOC         => cellTxEOC,
         cellTxEOF         => cellTxEOF,
         cellTxEOFE        => cellTxEOFE,
         cellTxData        => cellTxData,
         phyTxData         => intPhyTxData,
         phyTxDataK        => intPhyTxDataK,
         phyTxReady        => phyTxReady
      ); 


   -- Scheduler
   U_Pgp2bTxSched: entity work.Pgp2bTxSched 
      generic map (
         TPD_G             => TPD_G,
         VC_INTERLEAVE_G   => VC_INTERLEAVE_G,
         NUM_VC_EN_G       => NUM_VC_EN_G
      ) port map ( 
         pgpTxClk          => pgpTxClk,
         pgpTxClkRst       => pgpTxClkRst,
         pgpTxFlush        => pgpTxIn.flush,
         pgpTxLinkReady    => intTxLinkReady,
         schTxSOF          => schTxSOF,
         schTxEOF          => schTxEOF,
         schTxIdle         => schTxIdle,
         schTxReq          => schTxReq,
         schTxAck          => schTxAck,
         schTxDataVc       => schTxDataVc,
         schTxTimeout      => schTxTimeout,
         vc0FrameTxValid   => pgpTxVcData(0).valid,
         vc1FrameTxValid   => pgpTxVcData(1).valid,
         vc2FrameTxValid   => pgpTxVcData(2).valid,
         vc3FrameTxValid   => pgpTxVcData(3).valid
      );


   -- Cell Transmitter
   U_Pgp2bTxCell: entity work.Pgp2bTxCell 
      generic map (
         TPD_G             => TPD_G,
         TX_LANE_CNT_G     => TX_LANE_CNT_G
      ) port map ( 
         pgpTxClk          => pgpTxClk,
         pgpTxClkRst       => pgpTxClkRst,
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
         vc0FrameTxValid   => pgpTxVcData(0).valid,
         vc0FrameTxReady   => pgpTxVcCtrl(0).ready,
         vc0FrameTxSOF     => pgpTxVcData(0).sof,
         vc0FrameTxEOF     => pgpTxVcData(0).eof,
         vc0FrameTxEOFE    => pgpTxVcData(0).eofe,
         vc0FrameTxData    => pgpTxVcData(0).data(TX_LANE_CNT_G*16-1 downto 0),
         vc0LocAlmostFull  => pgpTxLocVcCtrl(0).almostFull,
         vc0LocOverflow    => pgpTxLocVcCtrl(0).overflow,
         vc1FrameTxValid   => pgpTxVcData(1).valid,
         vc1FrameTxReady   => pgpTxVcCtrl(1).ready,
         vc1FrameTxSOF     => pgpTxVcData(1).sof,
         vc1FrameTxEOF     => pgpTxVcData(1).eof,
         vc1FrameTxEOFE    => pgpTxVcData(1).eofe,
         vc1FrameTxData    => pgpTxVcData(1).data(TX_LANE_CNT_G*16-1 downto 0),
         vc1LocAlmostFull  => pgpTxLocVcCtrl(1).almostFull,
         vc1LocOverflow    => pgpTxLocVcCtrl(1).overflow,
         vc2FrameTxValid   => pgpTxVcData(2).valid,
         vc2FrameTxReady   => pgpTxVcCtrl(2).ready,
         vc2FrameTxSOF     => pgpTxVcData(2).sof,
         vc2FrameTxEOF     => pgpTxVcData(2).eof,
         vc2FrameTxEOFE    => pgpTxVcData(2).eofe,
         vc2FrameTxData    => pgpTxVcData(2).data(TX_LANE_CNT_G*16-1 downto 0),
         vc2LocAlmostFull  => pgpTxLocVcCtrl(2).almostFull,
         vc2LocOverflow    => pgpTxLocVcCtrl(2).overflow,
         vc3FrameTxValid   => pgpTxVcData(3).valid,
         vc3FrameTxReady   => pgpTxVcCtrl(3).ready,
         vc3FrameTxSOF     => pgpTxVcData(3).sof,
         vc3FrameTxEOF     => pgpTxVcData(3).eof,
         vc3FrameTxEOFE    => pgpTxVcData(3).eofe,
         vc3FrameTxData    => pgpTxVcData(3).data(TX_LANE_CNT_G*16-1 downto 0),
         vc3LocAlmostFull  => pgpTxLocVcCtrl(3).almostFull,
         vc3LocOverflow    => pgpTxLocVcCtrl(3).overflow,
         crcTxIn           => crcTxIn,
         crcTxInit         => crcTxInit,
         crcTxValid        => crcTxValid,
         crcTxOut          => crcTxOutAdjust
      );


   -- TX CRC BLock
   crcTxRst                    <= pgpTxClkRst or crcTxInit;
   crcTxInAdjust(31 downto 24) <= crcTxIn(7 downto 0);
   crcTxInAdjust(23 downto 16) <= crcTxIn(15 downto 8);
   crcTxOutAdjust              <= not crcTxOut;

   CRC_TX_1xLANE : if TX_LANE_CNT_G = 1 generate
      crcTxWidthAdjust           <= "001";
      crcTxInAdjust(15 downto 0) <= (others => '0');
   end generate CRC_TX_1xLANE;

   CRC_TX_2xLANE : if TX_LANE_CNT_G = 2 generate
      crcTxWidthAdjust           <= "011";
      crcTxInAdjust(15 downto 8) <= crcTxIn(23 downto 16);
      crcTxInAdjust(7 downto 0)  <= crcTxIn(31 downto 24);
   end generate CRC_TX_2xLANE;

   Tx_CRC : entity work.CRC32Rtl
      generic map(
         CRC_INIT => x"FFFFFFFF")
      port map(
         CRCOUT       => crcTxOut,
         CRCCLK       => pgpTxClk,
         CRCDATAVALID => crcTxValid,
         CRCDATAWIDTH => crcTxWidthAdjust,
         CRCIN        => crcTxInAdjust,
         CRCRESET     => crcTxRst
      );

end Pgp2bTx;

