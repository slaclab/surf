-------------------------------------------------------------------------------
-- File       : Pgp2bRx.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2009-05-27
-- Last update: 2017-03-28
-------------------------------------------------------------------------------
-- Description:
-- Cell Receive interface module for the Pretty Good Protocol core. 
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

LIBRARY ieee;
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
      pgpRxClkEn       : in  sl := '1'; -- Master clock enable
      pgpRxClk         : in  sl;        -- Master clock
      pgpRxClkRst      : in  sl;        -- Synchronous reset input

      -- Non-VC related IO
      pgpRxIn          : in  Pgp2bRxInType;
      pgpRxOut         : out Pgp2bRxOutType;

      -- VC Output
      pgpRxMaster      : out AxiStreamMasterType;
      remFifoStatus    : out AxiStreamCtrlArray(3 downto 0);

      -- PHY interface
      phyRxLanesOut    : out Pgp2bRxPhyLaneOutArray(0 to RX_LANE_CNT_G-1);
      phyRxLanesIn     : in  Pgp2bRxPhyLaneInArray(0 to RX_LANE_CNT_G-1);
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
   signal intPhyRxPolarity : slv(1 downto 0) := (others=>'0');    -- PHY receive signal polarity
   signal intPhyRxData     : slv(RX_LANE_CNT_G*16-1 downto 0); -- PHY receive data
   signal intPhyRxDataK    : slv(RX_LANE_CNT_G*2-1 downto 0);  -- PHY receive data is K character
   signal intPhyRxDispErr  : slv(RX_LANE_CNT_G*2-1 downto 0);  -- PHY receive data has disparity error
   signal intPhyRxDecErr   : slv(RX_LANE_CNT_G*2-1 downto 0);  -- PHY receive data not in table
   signal intRxVcValid     : slv(3 downto 0);
   signal intRxSof         : sl;
   signal intRxEof         : sl;
   signal intRxEofe        : sl;
   signal intRxData        : slv((RX_LANE_CNT_G*16)-1 downto 0);
   signal pause            : slv(3 downto 0);
   signal overflow         : slv(3 downto 0);

   attribute KEEP_HIERARCHY : string;
   attribute KEEP_HIERARCHY of 
      U_Pgp2bRxPhy,
      U_Pgp2bRxCell,
      Rx_CRC : label is "TRUE";
   
begin 

   -- Status
   pgpRxOut.linkReady    <= intRxLinkReady;
   pgpRxOut.linkPolarity <= intPhyRxPolarity;
   pgpRxOut.phyRxReady   <= phyRxReady;
   pgpRxOut.remOverflow  <= overflow;
   pgpRxOut.remPause     <= pause;

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
         pgpRxClkEn       => pgpRxClkEn,
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
         phyRxPolarity    => intPhyRxPolarity(RX_LANE_CNT_G-1 downto 0),
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
         pgpRxClkEn       => pgpRxClkEn,
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
         vcFrameRxSOF     => intRxSof,
         vcFrameRxEOF     => intRxEof,
         vcFrameRxEOFE    => intRxEofe,
         vcFrameRxData    => intRxData,
         vc0FrameRxValid  => intRxVcValid(0),
         vc0RemAlmostFull => pause(0),
         vc0RemOverflow   => overflow(0),
         vc1FrameRxValid  => intRxVcValid(1),
         vc1RemAlmostFull => pause(1),
         vc1RemOverflow   => overflow(1),
         vc2FrameRxValid  => intRxVcValid(2),
         vc2RemAlmostFull => pause(2),
         vc2RemOverflow   => overflow(2),
         vc3FrameRxValid  => intRxVcValid(3),
         vc3RemAlmostFull => pause(3),
         vc3RemOverflow   => overflow(3),
         crcRxIn          => crcRxIn,
         crcRxInit        => crcRxInit,
         crcRxValid       => crcRxValid,
         crcRxOut         => crcRxOutAdjust
      );


   -- Pass FIFO status
   process ( overflow, pause ) begin
      for i in 0 to 3 loop
         pgpRxOut.remOverFlow(i)   <= overflow(i);
         remFifoStatus(i).overflow <= overflow(i);
         remFifoStatus(i).pause    <= pause(i);
      end loop;
   end process;

   -- Generate valid/vc
   process ( pgpRxClk ) is
      variable intMaster : AxiStreamMasterType;
   begin
      if rising_edge (pgpRxClk ) then
         intMaster := AXI_STREAM_MASTER_INIT_C;

         if pgpRxClkEn = '1' then
            
            intMaster.tData((RX_LANE_CNT_G*16)-1 downto 0) := intRxData;
            intMaster.tStrb(RX_LANE_CNT_G-1 downto 0)      := (others=>'1');
            intMaster.tKeep(RX_LANE_CNT_G-1 downto 0)      := (others=>'1');

            intMaster.tLast := intRxEof;

            axiStreamSetUserBit(SSI_PGP2B_CONFIG_C,intMaster,SSI_EOFE_C,intRxEofe);
            axiStreamSetUserBit(SSI_PGP2B_CONFIG_C,intMaster,SSI_SOF_C,intRxSof,0);

            pgpRxOut.frameRx    <= uOr(intRxVcValid) and intRxEof and (not intRxEofe) after TPD_G;
            pgpRxOut.frameRxErr <= uOr(intRxVcValid) and intRxEof and intRxEofe       after TPD_G; 

            -- Generate valid and dest values
            case intRxVcValid is 
               when "0001" =>
                  intMaster.tValid            := '1';
                  intMaster.tDest(3 downto 0) := "0000";
               when "0010" =>
                  intMaster.tValid            := '1';
                  intMaster.tDest(3 downto 0) := "0001";
               when "0100" =>
                  intMaster.tValid            := '1';
                  intMaster.tDest(3 downto 0) := "0010";
               when "1000" =>
                  intMaster.tValid            := '1';
                  intMaster.tDest(3 downto 0) := "0011";
               when others =>
                  intMaster.tValid            := '0';
            end case;
         
         end if;

         if pgpRxClkRst = '1' then
            intMaster := AXI_STREAM_MASTER_INIT_C;
            pgpRxOut.frameRx    <= '0' after TPD_G;
            pgpRxOut.frameRxErr <= '0' after TPD_G;
         else

         pgpRxMaster <= intMaster after TPD_G;

         end if;
      end if;
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
         CRCCLKEN     => pgpRxClkEn,
         CRCDATAVALID => crcRxValid,
         CRCDATAWIDTH => crcRxWidthAdjust,
         CRCIN        => crcRxInAdjust,
         CRCRESET     => crcRxRst
      );

end Pgp2bRx;

