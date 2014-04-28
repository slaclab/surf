-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, Receive Top Level
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2bRx.vhd
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
-- 04/04/2014: Changed to Pgp2b. Removed debug. Integrated CRC.
-- 04/25/2014: Changed interface to AxiStream/SSI
-------------------------------------------------------------------------------

LIBRARY ieee;
USE work.Pgp2bPkg.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.Pgp2bPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity Pgp2bRx is 
   generic (
      TPD_G             : time                 := 1 ns;
      RX_LANE_CNT_G     : integer range 1 to 2 := 1; -- Number of receive lanes, 1-2
      PAYLOAD_CNT_TOP_G : integer              := 7  -- Top bit for payload counter
   );
   port (

      -- System clock, reset & control
      pgpRxClk         : in  sl;        -- Master clock
      pgpRxClkRst      : in  sl;        -- Synchronous reset input

      -- Non-VC related IO
      pgpRxIn          : in  PgpRxInType;
      pgpRxOut         : out PgpRxOutType;

      -- VC Output
      pgpRxMaster      : out AxiStreamMasterType;
      remFifoStatus    : out AxiStreamFifoStatusArray(3 downto 0);

      -- PHY interface
      phyRxLanesOut    : out PgpRxPhyLaneOutArray(0 to RX_LANE_CNT_G-1);
      phyRxLanesIn     : in  PgpRxPhyLaneInArray(0 to RX_LANE_CNT_G-1);
      phyRxReady       : in  sl;
      phyRxInit        : out sl
   );
end Pgp2bRx;

-- Define architecture
architecture Pgp2bRx of Pgp2bRx is

   -- Local Signals
   signal cellRxPause      : sl;
   signal cellRxSOC        : sl;
   signal cellRxSOF        : sl;
   signal cellRxEOC        : sl;
   signal cellRxEOF        : sl;
   signal cellRxEOFE       : sl;
   signal cellRxData       : slv(RX_LANE_CNT_G*16-1 downto 0);
   signal intRxLinkReady   : sl;
   signal crcRxIn          : slv(RX_LANE_CNT_G*16-1 downto 0); -- Receive data for CRC
   signal crcRxInit        : sl;                                 -- Receive CRC value init
   signal crcRxValid       : sl;                                 -- Receive data for CRC is valid
   signal crcRxOut         : slv(31 downto 0);
   signal crcRxOutAdjust   : slv(31 downto 0);
   signal crcRxRst         : sl;
   signal crcRxInAdjust    : slv(31 downto 0);
   signal crcRxWidthAdjust : slv(2 downto 0);
   signal intPhyRxPolarity : slv(RX_LANE_CNT_G-1 downto 0);    -- PHY receive signal polarity
   signal intPhyRxData     : slv(RX_LANE_CNT_G*16-1 downto 0); -- PHY receive data
   signal intPhyRxDataK    : slv(RX_LANE_CNT_G*2-1 downto 0);  -- PHY receive data is K character
   signal intPhyRxDispErr  : slv(RX_LANE_CNT_G*2-1 downto 0);  -- PHY receive data has disparity error
   signal intPhyRxDecErr   : slv(RX_LANE_CNT_G*2-1 downto 0);  -- PHY receive data not in table
   signal intRxVcReady     : slv(3 downto 0);
   signal intRxEof         : sl;
   signal intRxEofe        : sl;
   signal intRxData        : slv((RX_LANE_CNT_G*16)-1 downto 0);
   signal pause            : slv(3 downto 0);
   signal overflow         : slv(3 downto 0);

   constant SSI_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig (2);

begin

   -- Link Ready
   pgpRxOut.linkReady <= intRxLinkReady;

   -- Interface connection
   wrap : process ( intPhyRxPolarity, phyRxLanesIn) is
   begin
      for i in 0 to RX_LANE_CNT_G-1 loop
         phyRxLanesOut(i).polarity         <= intPhyRxPolarity(i);
         intPhyRxData(16*i+15 downto 16*i) <= phyRxLanesIn(i).data;
         intPhyRxDataK(2*i+1 downto 2*i)   <= phyRxLanesIn(i).dataK;
         intPhyRxDispErr(2*i+1 downto 2*i) <= phyRxLanesIn(i).dispErr;
         intPhyRxDecErr(2*i+1 downto 2*i)  <= phyRxLanesIn(i).decErr;
      end loop;
   end process;


   -- PHY Logic
   U_Pgp2bRxPhy: entity work.Pgp2bRxPhy 
      generic map ( 
         TPD_G            => TPD_G,
         RX_LANE_CNT_G    => RX_LANE_CNT_G
      ) port map (
         pgpRxClk         => pgpRxClk,
         pgpRxClkRst      => pgpRxClkRst,
         pgpRxLinkReady   => intRxLinkReady,
         pgpRxLinkDown    => pgpRxOut.linkDown,
         pgpRxLinkError   => pgpRxOut.linkError,
         pgpRxOpCodeEn    => pgpRxOut.opCodeEn,
         pgpRxOpCode      => pgpRxOut.opCode,
         pgpRemLinkReady  => pgpRxOut.remLinkReady,
         pgpRemData       => pgpRxOut.remLinkData,
         cellRxPause      => cellRxPause,
         cellRxSOC        => cellRxSOC,
         cellRxSOF        => cellRxSOF,
         cellRxEOC        => cellRxEOC,
         cellRxEOF        => cellRxEOF,
         cellRxEOFE       => cellRxEOFE,
         cellRxData       => cellRxData,
         phyRxPolarity    => intPhyRxPolarity,
         phyRxData        => intPhyRxData,
         phyRxDataK       => intPhyRxDataK,
         phyRxDispErr     => intPhyRxDispErr,
         phyRxDecErr      => intPhyRxDecErr,
         phyRxReady       => phyRxReady,
         phyRxInit        => phyRxInit
      ); 


   -- Cell Receiver
   U_Pgp2bRxCell: entity work.Pgp2bRxCell 
      generic map ( 
         TPD_G                => TPD_G,
         RX_LANE_CNT_G        => RX_LANE_CNT_G, 
         EN_SHORT_CELLS_G     => 1,
         PAYLOAD_CNT_TOP_G    => PAYLOAD_CNT_TOP_G
      ) port map (
         pgpRxClk         => pgpRxClk,
         pgpRxClkRst      => pgpRxClkRst,
         pgpRxFlush       => pgpRxIn.flush,
         pgpRxLinkReady   => intRxLinkReady,
         pgpRxCellError   => pgpRxOut.cellError,
         cellRxPause      => cellRxPause,
         cellRxSOC        => cellRxSOC,
         cellRxSOF        => cellRxSOF,
         cellRxEOC        => cellRxEOC,
         cellRxEOF        => cellRxEOF,
         cellRxEOFE       => cellRxEOFE,
         cellRxData       => cellRxData,
         vcFrameRxSOF     => open,
         vcFrameRxEOF     => intRxEof,
         vcFrameRxEOFE    => intRxEofe,
         vcFrameRxData    => intRxData,
         vc0FrameRxValid  => intRxVcReady(0),
         vc0RemAlmostFull => pause(0),
         vc0RemOverflow   => overflow(0),
         vc1FrameRxValid  => intRxVcReady(1),
         vc1RemAlmostFull => pause(1),
         vc1RemOverflow   => overflow(1),
         vc2FrameRxValid  => intRxVcReady(2),
         vc2RemAlmostFull => pause(2),
         vc2RemOverflow   => overflow(2),
         vc3FrameRxValid  => intRxVcReady(3),
         vc3RemAlmostFull => pause(3),
         vc3RemOverflow   => overflow(3),
         crcRxIn          => crcRxIn,
         crcRxInit        => crcRxInit,
         crcRxValid       => crcRxValid,
         crcRxOut         => crcRxOutAdjust
      );


   -- Generate valid/vc
   ValidRx: process (intRxVcReady, intRxEof, intRxEofe, intRxData, pause, overflow ) is
   begin

      for i in 0 to 3 loop
         pgpRxOut.remOverFlow(i)   <= overflow(i);
         remFifoStatus(i).overflow <= overflow(i);
         remFifoStatus(i).pause    <= pause(i);
      end loop;

      pgpRxMaster <= AXI_STREAM_MASTER_INIT_C;

      pgpRxMaster.tData((RX_LANE_CNT_G*16)-1 downto 0) <= intRxData;
      pgpRxMaster.tStrb(RX_LANE_CNT_G-1 downto 0)      <= (others=>'1');
      pgpRxMaster.tKeep(RX_LANE_CNT_G-1 downto 0)      <= (others=>'1');

      pgpRxMaster.tLast <= intRxEof;
      pgpRxMaster.tUser <= ssiSetUserBits(SSI_CONFIG_C,intRxEofe);

      -- Generate valid and dest values
      case intRxVcReady is 
         when "0001" =>
            pgpRxMaster.tValid            <= '1';
            pgpRxMaster.tDest(3 downto 0) <= "0000";
         when "0010" =>
            pgpRxMaster.tValid            <= '1';
            pgpRxMaster.tDest(3 downto 0) <= "0001";
         when "0100" =>
            pgpRxMaster.tValid            <= '1';
            pgpRxMaster.tDest(3 downto 0) <= "0010";
         when "1000" =>
            pgpRxMaster.tValid            <= '1';
            pgpRxMaster.tDest(3 downto 0) <= "0011";
         when others =>
            pgpRxMaster.tValid            <= '0';
            pgpRxMaster.tDest(3 downto 0) <= "0000";
      end case;
   end process;


   -- RX CRC BLock
   crcRxRst                    <= pgpRxClkRst or crcRxInit or not phyRxReady;
   crcRxInAdjust(31 downto 24) <= crcRxIn(7 downto 0);
   crcRxInAdjust(23 downto 16) <= crcRxIn(15 downto 8);
   crcRxOutAdjust              <= not crcRxOut;

   CRC_RX_1xLANE : if RX_LANE_CNT_G = 1 generate
      crcRxWidthAdjust           <= "001";
      crcRxInAdjust(15 downto 0) <= (others => '0');
   end generate CRC_RX_1xLANE;

   CRC_RX_2xLANE : if RX_LANE_CNT_G = 2 generate
      crcRxWidthAdjust           <= "011";
      crcRxInAdjust(15 downto 8) <= crcRxIn(23 downto 16);
      crcRxInAdjust(7 downto 0)  <= crcRxIn(31 downto 24);
   end generate CRC_RX_2xLANE;

   Rx_CRC : entity work.CRC32Rtl
      generic map(
         CRC_INIT => x"FFFFFFFF")
      port map(
         CRCOUT       => crcRxOut,
         CRCCLK       => pgpRxClk,
         CRCDATAVALID => crcRxValid,
         CRCDATAWIDTH => crcRxWidthAdjust,
         CRCIN        => crcRxInAdjust,
         CRCRESET     => crcRxRst
      );

end Pgp2bRx;

