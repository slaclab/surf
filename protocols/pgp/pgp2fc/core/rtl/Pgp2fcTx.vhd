-------------------------------------------------------------------------------
-- Title      : PGPv2fc: https://confluence.slac.stanford.edu/x/q86fD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Top Level Transmit interface module for the Pretty Good Protocol core.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.Pgp2fcPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity Pgp2fcTx is
   generic (
      TPD_G             : time                 := 1 ns;
      FC_WORDS_G        : integer range 1 to 8 := 1;
      VC_INTERLEAVE_G   : integer              := 1;  -- Interleave Frames
      PAYLOAD_CNT_TOP_G : integer              := 7;  -- Top bit for payload counter
      NUM_VC_EN_G       : integer range 1 to 4 := 4
      );
   port (

      -- System clock, reset & control
      pgpTxClkEn  : in sl := '1';       -- Master clock enable
      pgpTxClk    : in sl;              -- Master clock
      pgpTxClkRst : in sl;              -- Synchronous reset input

      -- Non-VC related IO
      pgpTxIn      : in  Pgp2fcTxInType;
      pgpTxOut     : out Pgp2fcTxOutType;
      locLinkReady : in  sl;

      -- VC Interface
      pgpTxMasters  : in  AxiStreamMasterArray(3 downto 0);
      pgpTxSlaves   : out AxiStreamSlaveArray(3 downto 0);
      locFifoStatus : in  AxiStreamCtrlArray(3 downto 0);
      remFifoStatus : in  AxiStreamCtrlArray(3 downto 0);

      -- Phy interface
      phyTxLaneOut : out Pgp2fcTxPhyLaneOutType;
      phyTxReady   : in  sl
      );

end Pgp2fcTx;


-- Define architecture
architecture Pgp2fcTx of Pgp2fcTx is

   -- Local Signals
   signal cellTxSOC        : sl;
   signal cellTxSOF        : sl;
   signal cellTxEOC        : sl;
   signal cellTxEOF        : sl;
   signal cellTxEOFE       : sl;
   signal cellTxData       : slv(15 downto 0);
   signal schTxSOF         : sl;
   signal schTxEOF         : sl;
   signal schTxIdle        : sl;
   signal schTxReq         : sl;
   signal schTxAck         : sl;
   signal schTxDataVc      : slv(1 downto 0);
   signal intTxLinkReady   : sl;
   signal intTxBusy        : sl;
   signal schTxTimeout     : sl;
   signal intPhyTxData     : slv(15 downto 0);
   signal intPhyTxDataK    : slv(1 downto 0);
   signal crcTxIn          : slv(15 downto 0);  -- Transmit data for CRC
   signal crcTxInit        : sl;                -- Transmit CRC value init
   signal crcTxValid       : sl;                -- Transmit data for CRC is valid
   signal crcTxOut         : slv(31 downto 0);  -- Transmit calculated CRC value
   signal crcTxOutAdjust   : slv(31 downto 0);  -- Transmit calculated CRC value
   signal crcTxRst         : sl;
   signal crcTxInAdjust    : slv(31 downto 0);
   signal crcTxWidthAdjust : slv(2 downto 0);
   signal intTxSof         : slv(3 downto 0);
   signal intTxEofe        : slv(3 downto 0);
   signal intvalid         : slv(3 downto 0);
   signal rawReady         : slv(3 downto 0);
   signal syncLocPause     : slv(3 downto 0);
   signal syncLocOverFlow  : slv(3 downto 0);
   signal syncRemPause     : slv(3 downto 0);
   signal gateRemPause     : slv(3 downto 0);
   signal syncLocLinkReady : sl;
   signal intTxMasters     : AxiStreamMasterArray(3 downto 0);
   signal intTxSlaves      : AxiStreamSlaveArray(3 downto 0);
   signal intFcSent        : sl;

   attribute KEEP_HIERARCHY : string;
   attribute KEEP_HIERARCHY of
      U_Pgp2fcTxPhy,
      U_Pgp2fcTxSched,
      U_Pgp2fcTxCell,
      Tx_CRC : label is "TRUE";

begin

   -- Sync flow control & buffer status
   U_VcFlowGen : for i in 0 to 3 generate
      U_Sync : entity surf.SynchronizerVector
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => '1',
            OUT_POLARITY_G => '1',
            RST_ASYNC_G    => false,
            STAGES_G       => 2,
            WIDTH_G        => 3,
            INIT_G         => "0")
         port map (
            clk        => pgpTxClk,
            rst        => pgpTxClkRst,
            dataIn(0)  => locFifoStatus(i).pause,
            dataIn(1)  => locFifoStatus(i).overflow,
            dataIn(2)  => remFifoStatus(i).pause,
            dataOut(0) => syncLocPause(i),
            dataOut(1) => syncLocOverFlow(i),
            dataOut(2) => syncRemPause(i));
   end generate;


   U_LinkReady : entity surf.Synchronizer
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         OUT_POLARITY_G => '1',
         RST_ASYNC_G    => false,
         STAGES_G       => 2,
         INIT_G         => "0")
      port map (
         clk     => pgpTxClk,
         rst     => pgpTxClkRst,
         dataIn  => locLinkReady,
         dataOut => syncLocLinkReady);

   -- Set phy lanes
   phyTxLaneOut.data  <= intPhyTxData;
   phyTxLaneOut.dataK <= intPhyTxDataK;

   -- Link Ready
   pgpTxOut.linkReady   <= intTxLinkReady;
   pgpTxOut.phyTxReady  <= phyTxReady;
   pgpTxOut.fcSent      <= intFcSent;
   pgpTxOut.locOverflow <= syncLocOverFlow;
   pgpTxOut.locPause    <= syncLocPause;

   process (pgpTxClk)
   begin
      if rising_edge(pgpTxClk) then
         if pgpTxClkRst = '1' then
            pgpTxOut.frameTx    <= '0'             after TPD_G;
            pgpTxOut.frameTxErr <= '0'             after TPD_G;
            gateRemPause        <= (others => '0') after TPD_G;
         else
            pgpTxOut.frameTx    <= cellTxEOF  after TPD_G;
            pgpTxOut.frameTxErr <= cellTxEOFE after TPD_G;

            if pgpTxIn.flowCntlDis = '1' then
               gateRemPause <= (others => '0') after TPD_G;
            else
               gateRemPause <= syncRemPause after TPD_G;
            end if;
         end if;
      end if;
   end process;

   -- Physical Interface
   U_Pgp2fcTxPhy : entity surf.Pgp2fcTxPhy
      generic map (
         TPD_G      => TPD_G,
         FC_WORDS_G => FC_WORDS_G)
      port map (
         pgpTxClkEn      => pgpTxClkEn,
         pgpTxClk        => pgpTxClk,
         pgpTxClkRst     => pgpTxClkRst,
         pgpTxLinkReady  => intTxLinkReady,
         pgpBusy         => intTxBusy,
         fcValid         => pgpTxIn.fcValid,
         fcWord          => pgpTxIn.fcWord(FC_WORDS_G*16-1 downto 0),
         fcSent          => intFcSent,
         pgpLocLinkReady => syncLocLinkReady,
         pgpLocData      => pgpTxIn.locData,
         cellTxSOC       => cellTxSOC,
         cellTxSOF       => cellTxSOF,
         cellTxEOC       => cellTxEOC,
         cellTxEOF       => cellTxEOF,
         cellTxEOFE      => cellTxEOFE,
         cellTxData      => cellTxData,
         phyTxData       => intPhyTxData,
         phyTxDataK      => intPhyTxDataK,
         phyTxReady      => phyTxReady);


   -- Scheduler
   U_Pgp2fcTxSched : entity surf.Pgp2fcTxSched
      generic map (
         TPD_G           => TPD_G,
         VC_INTERLEAVE_G => VC_INTERLEAVE_G,
         NUM_VC_EN_G     => NUM_VC_EN_G)
      port map (
         pgpTxClkEn       => pgpTxClkEn,
         pgpTxClk         => pgpTxClk,
         pgpTxClkRst      => pgpTxClkRst,
         pgpTxFlush       => pgpTxIn.flush,
         pgpTxLinkReady   => intTxLinkReady,
         pgpTxBusy        => intTxBusy,
         schTxSOF         => schTxSOF,
         schTxEOF         => schTxEOF,
         schTxIdle        => schTxIdle,
         schTxReq         => schTxReq,
         schTxAck         => schTxAck,
         schTxDataVc      => schTxDataVc,
         schTxTimeout     => schTxTimeout,
         vc0FrameTxValid  => intValid(0),
         vc1FrameTxValid  => intValid(1),
         vc2FrameTxValid  => intValid(2),
         vc3FrameTxValid  => intValid(3),
         vc0RemAlmostFull => gateRemPause(0),
         vc1RemAlmostFull => gateRemPause(1),
         vc2RemAlmostFull => gateRemPause(2),
         vc3RemAlmostFull => gateRemPause(3));


   -- Cell Transmitter
   U_Pgp2fcTxCell : entity surf.Pgp2fcTxCell
      generic map (
         TPD_G => TPD_G)
      port map (
         pgpTxClkEn       => pgpTxClkEn,
         pgpTxClk         => pgpTxClk,
         pgpTxClkRst      => pgpTxClkRst,
         pgpTxLinkReady   => intTxLinkReady,
         pgpTxBusy        => intTxBusy,
         cellTxSOC        => cellTxSOC,
         cellTxSOF        => cellTxSOF,
         cellTxEOC        => cellTxEOC,
         cellTxEOF        => cellTxEOF,
         cellTxEOFE       => cellTxEOFE,
         cellTxData       => cellTxData,
         schTxSOF         => schTxSOF,
         schTxEOF         => schTxEOF,
         schTxIdle        => schTxIdle,
         schTxReq         => schTxReq,
         schTxAck         => schTxAck,
         schTxTimeout     => schTxTimeout,
         schTxDataVc      => schTxDataVc,
         vc0FrameTxValid  => intValid(0),
         vc0FrameTxReady  => rawReady(0),
         vc0FrameTxSOF    => intTxSof(0),
         vc0FrameTxEOF    => intTxMasters(0).tLast,
         vc0FrameTxEOFE   => intTxEofe(0),
         vc0FrameTxData   => intTxMasters(0).tData(15 downto 0),
         vc0LocAlmostFull => syncLocPause(0),
         vc0LocOverflow   => syncLocOverFlow(0),
         vc0RemAlmostFull => gateRemPause(0),
         vc1FrameTxValid  => intValid(1),
         vc1FrameTxReady  => rawReady(1),
         vc1FrameTxSOF    => intTxSof(1),
         vc1FrameTxEOF    => intTxMasters(1).tLast,
         vc1FrameTxEOFE   => intTxEofe(1),
         vc1FrameTxData   => intTxMasters(1).tData(15 downto 0),
         vc1LocAlmostFull => syncLocPause(1),
         vc1LocOverflow   => syncLocOverFlow(1),
         vc1RemAlmostFull => gateRemPause(1),
         vc2FrameTxValid  => intValid(2),
         vc2FrameTxReady  => rawReady(2),
         vc2FrameTxSOF    => intTxSof(2),
         vc2FrameTxEOF    => intTxMasters(2).tLast,
         vc2FrameTxEOFE   => intTxEofe(2),
         vc2FrameTxData   => intTxMasters(2).tData(15 downto 0),
         vc2LocAlmostFull => syncLocPause(2),
         vc2LocOverflow   => syncLocOverFlow(2),
         vc2RemAlmostFull => gateRemPause(2),
         vc3FrameTxValid  => intValid(3),
         vc3FrameTxReady  => rawReady(3),
         vc3FrameTxSOF    => intTxSof(3),
         vc3FrameTxEOF    => intTxMasters(3).tLast,
         vc3FrameTxEOFE   => intTxEofe(3),
         vc3FrameTxData   => intTxMasters(3).tData(15 downto 0),
         vc3LocAlmostFull => syncLocPause(3),
         vc3LocOverflow   => syncLocOverFlow(3),
         vc3RemAlmostFull => gateRemPause(3),
         crcTxIn          => crcTxIn,
         crcTxInit        => crcTxInit,
         crcTxValid       => crcTxValid,
         crcTxOut         => crcTxOutAdjust);


   -- EOFE/Ready/Valid
   U_Vc_Gen : for i in 0 to 3 generate

      -- Add pipeline stages to ensure ready stays asserted
      U_InputPipe : entity surf.AxiStreamPipeline
         generic map (
            TPD_G         => TPD_G,
            PIPE_STAGES_G => 0)
         port map (
            axisClk     => pgpTxClk,
            axisRst     => pgpTxClkRst,
            sAxisMaster => pgpTxMasters(i),
            sAxisSlave  => pgpTxSlaves(i),
            mAxisMaster => intTxMasters(i),
            mAxisSlave  => intTxSlaves(i)
            );

      intValid(i)           <= intTxMasters(i).tValid;
      intTxEofe(i)          <= axiStreamGetUserBit(PGP2FC_AXIS_CONFIG_C, intTxMasters(i), SSI_EOFE_C);
      intTxSof(i)           <= axiStreamGetUserBit(PGP2FC_AXIS_CONFIG_C, intTxMasters(i), SSI_SOF_C, 0);
      intTxSlaves(i).tReady <= rawReady(i);

   end generate;

   -- TX CRC Block
   crcTxRst                    <= pgpTxClkRst or crcTxInit;
   crcTxInAdjust(31 downto 24) <= crcTxIn(7 downto 0);
   crcTxInAdjust(23 downto 16) <= crcTxIn(15 downto 8);
   crcTxOutAdjust              <= not crcTxOut;
   crcTxWidthAdjust            <= "001";
   crcTxInAdjust(15 downto 0)  <= (others => '0');

   Tx_CRC : entity surf.CRC32Rtl
      generic map(
         CRC_INIT => x"FFFFFFFF")
      port map(
         CRCOUT       => crcTxOut,
         CRCCLK       => pgpTxClk,
         CRCCLKEN     => pgpTxClkEn,
         CRCDATAVALID => crcTxValid,
         CRCDATAWIDTH => crcTxWidthAdjust,
         CRCIN        => crcTxInAdjust,
         CRCRESET     => crcTxRst
         );

end Pgp2fcTx;

