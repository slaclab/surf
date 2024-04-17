-------------------------------------------------------------------------------
-- Title      : PGPv2fc: https://confluence.slac.stanford.edu/x/q86fD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- AXI-Lite block to manage the PGP (fc) interface.
--
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
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.Pgp2fcPkg.all;

entity Pgp2fcAxi is
   generic (
      TPD_G              : time                  := 1 ns;
      COMMON_TX_CLK_G    : boolean               := false;  -- Set to true if axiClk and pgpTxClk are the same clock
      COMMON_RX_CLK_G    : boolean               := false;  -- Set to true if axiClk and pgpRxClk are the same clock
      WRITE_EN_G         : boolean               := false;  -- Set to false when on remote end of a link
      AXI_CLK_FREQ_G     : real                  := 125.0E+6;
      FC_WORDS_G         : natural range 1 to 8  := 1;
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 32;
      ERROR_CNT_WIDTH_G  : natural range 1 to 32 := 4);
   port (

      -- TX PGP Interface (pgpTxClk domain)
      pgpTxClk     : in  sl;
      pgpTxClkRst  : in  sl;
      pgpTxIn      : out Pgp2fcTxInType;
      pgpTxOut     : in  Pgp2fcTxOutType;
      locTxIn      : in  Pgp2fcTxInType := PGP2FC_TX_IN_INIT_C;

      -- RX PGP Interface (pgpRxClk domain)
      pgpRxClk    : in  sl;
      pgpRxClkRst : in  sl;
      pgpRxIn     : out Pgp2fcRxInType;
      pgpRxOut    : in  Pgp2fcRxOutType;
      locRxIn     : in  Pgp2fcRxInType := PGP2FC_RX_IN_INIT_C;

      -- Status Bus (axilClk domain)
      statusWord : out slv(63 downto 0);
      statusSend : out sl;

      -- AXI-Lite Register Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType
      );
end Pgp2fcAxi;

architecture structure of Pgp2fcAxi is

   constant STATUS_OUT_TOP_C : integer := ite(STATUS_CNT_WIDTH_G > 7, 7, STATUS_CNT_WIDTH_G-1);

   -- Local signals
   signal rxStatusSend : sl;

   signal rxErrorOut     : slv(16 downto 0);
   signal rxErrorCntOut  : SlVectorArray(16 downto 0, ERROR_CNT_WIDTH_G-1 downto 0);
   signal rxStatusCntOut : SlVectorArray(0 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);

   signal txErrorOut     : slv(11 downto 0);
   signal txErrorCntOut  : SlVectorArray(11 downto 0, ERROR_CNT_WIDTH_G-1 downto 0);
   signal txStatusCntOut : SlVectorArray(0 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);

   signal rxErrorIrqEn    : slv(16 downto 0);
   signal locTxDataEn     : sl;
   signal locTxData       : slv(7 downto 0);
   signal txFlush         : sl;
   signal rxFlush         : sl;
   signal rxReset         : sl;
   signal txReset         : sl;
   signal syncFlowCntlDis : sl;

   type RegType is record
      flush          : sl;
      resetTx        : sl;
      resetRx        : sl;
      resetGt        : sl;
      countReset     : sl;
      loopBack       : slv(2 downto 0);
      flowCntlDis    : sl;
      autoStatus     : sl;
      locData        : slv(7 downto 0);
      locDataEn      : sl;
      alignRst       : sl;
      alignOverride  : sl;
      alignSlide     : sl;
      alignPhaseReq  : sl;
      axilWriteSlave : AxiLiteWriteSlaveType;
      axilReadSlave  : AxiLiteReadSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      flush          => '0',
      resetTx        => '0',
      resetRx        => '0',
      resetGt        => '0',
      countReset     => '0',
      loopBack       => (others => '0'),
      flowCntlDis    => '0',
      autoStatus     => '0',
      locData        => (others => '0'),
      locDataEn      => '0',
      alignRst       => '0',
      alignOverride  => '0',
      alignSlide     => '0',
      alignPhaseReq  => '0',
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C
      );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   type RxStatusType is record
      phyRxReady      : sl;
      locLinkReady    : sl;
      remLinkReady    : sl;
      remLinkReadyCnt : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      remLinkData     : slv(7 downto 0);
      cellErrorCount  : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      linkDownCount   : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      linkErrorCount  : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      remOverflow     : slv(3 downto 0);
      remOverflow0Cnt : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      remOverflow1Cnt : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      remOverflow2Cnt : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      remOverflow3Cnt : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      frameErrCount   : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      frameCount      : slv(STATUS_CNT_WIDTH_G-1 downto 0);
      remPause        : slv(3 downto 0);
      rxClkFreq       : slv(31 downto 0);
      rxFcWordLast    : slv(FC_WORDS_G*16-1 downto 0);
      rxFcRecvCount   : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      rxFcErrCount    : slv(ERROR_CNT_WIDTH_G-1 downto 0);
   end record RxStatusType;

   signal rxstatusSync : RxStatusType;

   type TxStatusType is record
      txLinkReady     : sl;
      phyTxReady      : sl;
      locOverflow     : slv(3 downto 0);
      locOverflow0Cnt : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      locOverflow1Cnt : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      locOverflow2Cnt : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      locOverflow3Cnt : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      locPause        : slv(3 downto 0);
      frameErrCount   : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      frameCount      : slv(STATUS_CNT_WIDTH_G-1 downto 0);
      txClkFreq       : slv(31 downto 0);
      txFcWordLast    : slv(FC_WORDS_G*16-1 downto 0);
      txFcSentCount   : slv(ERROR_CNT_WIDTH_G-1 downto 0);
   end record TxStatusType;

   signal txstatusSync : TxStatusType;

begin




   ---------------------------------------
   -- Receive Status
   ---------------------------------------

   -- OpCode Capture
   U_RxFcWordSync : entity surf.SynchronizerFifo
      generic map (
         TPD_G         => TPD_G,
         MEMORY_TYPE_G => "distributed",
         SYNC_STAGES_G => 3,
         DATA_WIDTH_G  => FC_WORDS_G*16,
         ADDR_WIDTH_G  => 2,
         INIT_G        => "0")
      port map (
         rst    => r.countReset,
         wr_clk => pgpRxClk,
         wr_en  => pgpRxOut.fcValid,
         din    => pgpRxOut.fcWord(FC_WORDS_G*16-1 downto 0),
         rd_clk => axilClk,
         rd_en  => '1',
         valid  => open,
         dout   => rxStatusSync.rxFcWordLast);


   -- Sync remote data
   U_RxDataSyncEn : if COMMON_RX_CLK_G = false generate
      U_RxDataSync : entity surf.SynchronizerFifo
         generic map (
            TPD_G         => TPD_G,
            MEMORY_TYPE_G => "distributed",
            SYNC_STAGES_G => 3,
            DATA_WIDTH_G  => 8,
            ADDR_WIDTH_G  => 2,
            INIT_G        => "0")
         port map (
            rst    => axilRst,
            wr_clk => pgpRxClk,
            wr_en  => '1',
            din    => pgpRxOut.remLinkData,
            rd_clk => axilClk,
            rd_en  => '1',
            valid  => open,
            dout   => rxStatusSync.remLinkData);
   end generate;

   U_RxDataSyncDis : if COMMON_RX_CLK_G generate
      rxStatusSync.remLinkData <= pgpRxOut.remLinkData;
   end generate;

   -- Errror counters and non counted values
   U_RxError : entity surf.SyncStatusVector
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         COMMON_CLK_G   => COMMON_RX_CLK_G,
         SYNC_STAGES_G  => 3,
         IN_POLARITY_G  => "1",
         OUT_POLARITY_G => '1',
         SYNTH_CNT_G    => "11111100001111100",
         CNT_RST_EDGE_G => false,
         CNT_WIDTH_G    => ERROR_CNT_WIDTH_G,
         WIDTH_G        => 17)
      port map (
         statusIn(0)           => pgpRxOut.phyRxReady,
         statusIn(1)           => pgpRxOut.linkReady,
         statusIn(2)           => pgpRxOut.remLinkReady,
         statusIn(6 downto 3)  => pgpRxOut.remOverflow,
         statusIn(10 downto 7) => pgpRxOut.remPause,
         statusIn(11)          => pgpRxOut.cellError,
         statusIn(12)          => pgpRxOut.linkDown,
         statusIn(13)          => pgpRxOut.linkError,
         statusIn(14)          => pgpRxOut.frameRxErr,
         statusIn(15)          => pgpRxOut.fcValid,
         statusIn(16)          => pgpRxOut.fcError,
         statusOut             => rxErrorOut,
         cntRstIn              => r.countReset,
         rollOverEnIn          => (others => '0'),
         cntOut                => rxErrorCntOut,
         irqEnIn               => rxErrorIrqEn,
         irqOut                => rxStatusSend,
         wrClk                 => pgpRxClk,
         wrRst                 => pgpRxClkRst,
         rdClk                 => axilClk,
         rdRst                 => axilRst);

   U_RxErrorIrqEn : process (r.autoStatus)
   begin
      rxErrorIrqEn     <= (others => '0');
      rxErrorIrqEn(1)  <= r.autoStatus;
      rxErrorIrqEn(4)  <= r.autoStatus;
      rxErrorIrqEn(5)  <= r.autoStatus;
      rxErrorIrqEn(6)  <= r.autoStatus;
      rxErrorIrqEn(7)  <= r.autoStatus;
      rxErrorIrqEn(8)  <= r.autoStatus;
      rxErrorIrqEn(13) <= r.autoStatus;
      rxErrorIrqEn(14) <= r.autoStatus;
      rxErrorIrqEn(16) <= r.autoStatus;
   end process;

   -- map status
   rxStatusSync.phyRxReady   <= rxErrorOut(0);
   rxStatusSync.locLinkReady <= rxErrorOut(1);
   rxStatusSync.remLinkReady <= rxErrorOut(2);
   rxStatusSync.remOverflow  <= rxErrorOut(6 downto 3);
   rxStatusSync.remPause     <= rxErrorOut(10 downto 7);

   -- Map counters
   rxStatusSync.remLinkReadyCnt <= muxSlVectorArray(rxErrorCntOut, 2);
   rxStatusSync.remOverflow0Cnt <= muxSlVectorArray(rxErrorCntOut, 3);
   rxStatusSync.remOverflow1Cnt <= muxSlVectorArray(rxErrorCntOut, 4);
   rxStatusSync.remOverflow2Cnt <= muxSlVectorArray(rxErrorCntOut, 5);
   rxStatusSync.remOverflow3Cnt <= muxSlVectorArray(rxErrorCntOut, 6);
   rxStatusSync.cellErrorCount  <= muxSlVectorArray(rxErrorCntOut, 11);
   rxStatusSync.linkDownCount   <= muxSlVectorArray(rxErrorCntOut, 12);
   rxStatusSync.linkErrorCount  <= muxSlVectorArray(rxErrorCntOut, 13);
   rxStatusSync.frameErrCount   <= muxSlVectorArray(rxErrorCntOut, 14);
   rxStatusSync.rxFcRecvCount   <= muxSlVectorArray(rxErrorCntOut, 15);
   rxStatusSync.rxFcErrCount    <= muxSlVectorArray(rxErrorCntOut, 16);

   -- Status counters
   U_RxStatus : entity surf.SyncStatusVector
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         COMMON_CLK_G   => COMMON_RX_CLK_G,
         SYNC_STAGES_G  => 3,
         IN_POLARITY_G  => "1",
         OUT_POLARITY_G => '1',
         SYNTH_CNT_G    => "1",
         CNT_RST_EDGE_G => false,
         CNT_WIDTH_G    => STATUS_CNT_WIDTH_G,
         WIDTH_G        => 1)
      port map (
         statusIn(0)  => pgpRxOut.frameRx,
         statusOut    => open,
         cntRstIn     => r.countReset,
         rollOverEnIn => (others => '1'),
         cntOut       => rxStatusCntOut,
         irqEnIn      => (others => '0'),
         irqOut       => open,
         wrClk        => pgpRxClk,
         wrRst        => pgpRxClkRst,
         rdClk        => axilClk,
         rdRst        => axilRst);

   rxStatusSync.frameCount <= muxSlVectorArray(rxStatusCntOut, 0);

   U_RxClkFreq : entity surf.SyncClockFreq
      generic map (
         TPD_G             => TPD_G,
         REF_CLK_FREQ_G    => AXI_CLK_FREQ_G,
         REFRESH_RATE_G    => 100.0,
         CLK_LOWER_LIMIT_G => 155.0E+6,
         CLK_UPPER_LIMIT_G => 158.0E+6,
         CNT_WIDTH_G       => 32)
      port map (
         freqOut     => rxStatusSync.rxClkFreq,
         freqUpdated => open,
         locked      => open,
         tooFast     => open,
         tooSlow     => open,
         clkIn       => pgpRxClk,
         locClk      => axilClk,
         refClk      => axilClk);


   ---------------------------------------
   -- Transmit Status
   ---------------------------------------
   -- FC Word Capture
   U_TxFcWordSync : entity surf.SynchronizerFifo
      generic map (
         TPD_G         => TPD_G,
         MEMORY_TYPE_G => "distributed",
         SYNC_STAGES_G => 3,
         DATA_WIDTH_G  => FC_WORDS_G*16,
         ADDR_WIDTH_G  => 2,
         INIT_G        => "0")
      port map (
         rst    => r.countReset,
         wr_clk => pgpTxClk,
         wr_en  => locTxIn.fcValid,
         din    => locTxIn.fcWord(FC_WORDS_G*16-1 downto 0),
         rd_clk => axilClk,
         rd_en  => '1',
         valid  => open,
         dout   => txStatusSync.txFcWordLast);


   -- Errror counters and non counted values
   U_TxError : entity surf.SyncStatusVector
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         COMMON_CLK_G   => COMMON_TX_CLK_G,
         SYNC_STAGES_G  => 3,
         IN_POLARITY_G  => "1",
         OUT_POLARITY_G => '1',
         SYNTH_CNT_G    => "110000111100",
         CNT_RST_EDGE_G => false,
         CNT_WIDTH_G    => ERROR_CNT_WIDTH_G,
         WIDTH_G        => 12)
      port map (
         statusIn(0)          => pgpTxOut.phyTxReady,
         statusIn(1)          => pgpTxOut.linkReady,
         statusIn(5 downto 2) => pgpTxOut.locOverflow,
         statusIn(9 downto 6) => pgpTxOut.locPause,
         statusIn(10)         => pgpTxOut.frameTxErr,
         statusIn(11)         => pgpTxOut.fcSent,
         statusOut            => txErrorOut,
         cntRstIn             => r.countReset,
         rollOverEnIn         => (others => '0'),
         cntOut               => txErrorCntOut,
         irqEnIn              => (others => '0'),
         irqOut               => open,
         wrClk                => pgpTxClk,
         wrRst                => pgpTxClkRst,
         rdClk                => axilClk,
         rdRst                => axilRst);

   -- Map Status
   txStatusSync.phyTxReady  <= txErrorOut(0);
   txStatusSync.txLinkReady <= txErrorOut(1);
   txStatusSync.locOverFlow <= txErrorOut(5 downto 2);
   txStatusSync.locPause    <= txErrorOut(9 downto 6);

   -- Map counters
   txStatusSync.locOverflow0Cnt <= muxSlVectorArray(txErrorCntOut, 2);
   txStatusSync.locOverflow1Cnt <= muxSlVectorArray(txErrorCntOut, 3);
   txStatusSync.locOverflow2Cnt <= muxSlVectorArray(txErrorCntOut, 4);
   txStatusSync.locOverflow3Cnt <= muxSlVectorArray(txErrorCntOut, 5);
   txStatusSync.frameErrCount   <= muxSlVectorArray(txErrorCntOut, 10);
   txStatusSync.txFcSentCount   <= muxSlVectorArray(txErrorCntOut, 11);

   -- Status counters
   U_TxStatus : entity surf.SyncStatusVector
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         COMMON_CLK_G   => COMMON_TX_CLK_G,
         SYNC_STAGES_G  => 3,
         IN_POLARITY_G  => "1",
         OUT_POLARITY_G => '1',
         SYNTH_CNT_G    => "1",
         CNT_RST_EDGE_G => false,
         CNT_WIDTH_G    => STATUS_CNT_WIDTH_G,
         WIDTH_G        => 1)
      port map (
         statusIn(0)  => pgpTxOut.frameTx,
         statusOut    => open,
         cntRstIn     => r.countReset,
         rollOverEnIn => (others => '1'),
         cntOut       => txStatusCntOut,
         irqEnIn      => (others => '0'),
         irqOut       => open,
         wrClk        => pgpTxClk,
         wrRst        => pgpTxClkRst,
         rdClk        => axilClk,
         rdRst        => axilRst);

   txStatusSync.frameCount <= muxSlVectorArray(txStatusCntOut, 0);

   U_TxClkFreq : entity surf.SyncClockFreq
      generic map (
         TPD_G             => TPD_G,
         REF_CLK_FREQ_G    => AXI_CLK_FREQ_G,
         REFRESH_RATE_G    => 100.0,
         CLK_LOWER_LIMIT_G => 155.0E+6,
         CLK_UPPER_LIMIT_G => 158.0E+6,
         CNT_WIDTH_G       => 32)
      port map (
         freqOut     => txStatusSync.txClkFreq,
         freqUpdated => open,
         locked      => open,
         tooFast     => open,
         tooSlow     => open,
         clkIn       => pgpTxClk,
         locClk      => axilClk,
         refClk      => axilClk);

   -------------------------------------
   -- Tx Control Sync
   -------------------------------------

   -- Sync Tx Control
   U_TxDataSyncEn : if COMMON_RX_CLK_G = false generate
      U_TxDataSync : entity surf.SynchronizerFifo
         generic map (
            TPD_G         => TPD_G,
            MEMORY_TYPE_G => "distributed",
            SYNC_STAGES_G => 3,
            DATA_WIDTH_G  => 9,
            ADDR_WIDTH_G  => 2,
            INIT_G        => "0")
         port map (
            rst              => axilRst,
            wr_clk           => axilClk,
            wr_en            => '1',
            din(8)           => r.locDataEn,
            din(7 downto 0)  => r.locData,
            rd_clk           => pgpTxClk,
            rd_en            => '1',
            valid            => open,
            dout(8)          => locTxDataEn,
            dout(7 downto 0) => locTxData);
   end generate;

   -- Sync flow cntl disable
   U_FlowCntlDis : entity surf.Synchronizer
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
         dataIn  => r.flowCntlDis,
         dataOut => syncFlowCntlDis);


   U_TxDataSyncDis : if COMMON_RX_CLK_G generate
      locTxDataEn <= r.locDataEn;
      locTxData   <= r.locData;
   end generate;

   txFlush <= r.flush;
   txReset <= r.resetTx;


   -- Set tx input
   pgpTxIn.flush       <= locTxIn.flush or txFlush;
   pgpTxIn.locData     <= locTxData when locTxDataEn = '1' else locTxIn.locData;
   pgpTxIn.flowCntlDis <= locTxIn.flowCntlDis or syncFlowCntlDis;
   pgpTxIn.resetTx     <= locTxIn.resetTx or txReset;
   pgpTxIn.resetGt     <= r.resetGt;


   -------------------------------------
   -- Rx Control Sync
   -------------------------------------
   rxFlush <= r.flush;
   rxReset <= r.resetRx;

   -- Set rx input
   pgpRxIn.flush    <= locRxIn.flush or rxFlush;
   pgpRxIn.resetRx  <= locRxIn.resetRx or rxReset;
   pgpRxIn.loopback <= locRxIn.loopback or r.loopBack;

--    linkAlignRst      <= r.alignRst;
--    linkAlignOverride <= r.alignOverride;
--    linkAlignSlide    <= r.alignSlide;
--    linkAlignPhaseReq <= r.alignPhaseReq;



   ------------------------------------
   -- AXI Registers
   ------------------------------------

   -- Sync
   process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process;

   -- Async
   process (axilRst, axilReadMaster, axilWriteMaster, r, rxStatusSync, txStatusSync) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      v := r;

      -- Automatic clear
      v.alignSlide    := '0';
      v.alignPhaseReq := '0';

      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      axiSlaveRegister(axilEp, X"00", 0, v.countReset);
      if (WRITE_EN_G) then
         axiSlaveRegister(axilEp, X"04", 0, v.resetRx);
         axiSlaveRegister(axilEp, X"04", 1, v.resetTx);
         axiSlaveRegister(axilEp, X"04", 2, v.resetGt);
         axiSlaveRegister(axilEp, X"08", 0, v.flush);
         axiSlaveRegister(axilEp, X"0C", 0, v.loopback);
         axiSlaveRegister(axilEp, X"18", 0, v.flowCntlDis);
      end if;
      axiSlaveRegister(axilEp, X"10", 0, v.locData);
      axiSlaveRegister(axilEp, X"10", 8, v.locDataEn);
      axiSlaveRegister(axilEp, X"14", 0, v.autoStatus);

      axiSlaveRegisterR(axilEp, X"20", 0, rxStatusSync.phyRxReady);
      axiSlaveRegisterR(axilEp, X"20", 1, txStatusSync.phyTxReady);
      axiSlaveRegisterR(axilEp, X"20", 2, rxStatusSync.locLinkReady);
      axiSlaveRegisterR(axilEp, X"20", 3, rxStatusSync.remLinkReady);
      axiSlaveRegisterR(axilEp, X"20", 4, txStatusSync.txLinkReady);
      axiSlaveRegisterR(axilEp, X"20", 12, rxStatusSync.remPause);
      axiSlaveRegisterR(axilEp, X"20", 16, txStatusSync.locPause);
      axiSlaveRegisterR(axilEp, X"20", 20, rxStatusSync.remOverflow);
      axiSlaveRegisterR(axilEp, X"20", 24, txStatusSync.locOverflow);
      axiSlaveRegisterR(axilEp, X"24", 0, rxStatusSync.remLinkData);
      axiSlaveRegisterR(axilEp, X"28", 0, rxStatusSync.cellErrorCount);
      axiSlaveRegisterR(axilEp, X"2C", 0, rxStatusSync.linkDownCount);
      axiSlaveRegisterR(axilEp, X"30", 0, rxStatusSync.linkErrorCount);
      axiSlaveRegisterR(axilEp, X"34", 0, rxStatusSync.remOverflow0Cnt);
      axiSlaveRegisterR(axilEp, X"38", 0, rxStatusSync.remOverflow1Cnt);
      axiSlaveRegisterR(axilEp, X"3C", 0, rxStatusSync.remOverflow2Cnt);
      axiSlaveRegisterR(axilEp, X"40", 0, rxStatusSync.remOverflow3Cnt);
      axiSlaveRegisterR(axilEp, X"44", 0, rxStatusSync.frameErrCount);
      axiSlaveRegisterR(axilEp, X"48", 0, rxStatusSync.frameCount);
      axiSlaveRegisterR(axilEp, X"4C", 0, txStatusSync.locOverflow0Cnt);
      axiSlaveRegisterR(axilEp, X"50", 0, txStatusSync.locOverflow1Cnt);
      axiSlaveRegisterR(axilEp, X"54", 0, txStatusSync.locOverflow2Cnt);
      axiSlaveRegisterR(axilEp, X"58", 0, txStatusSync.locOverflow3Cnt);
      axiSlaveRegisterR(axilEp, X"5C", 0, txStatusSync.frameErrCount);
      axiSlaveRegisterR(axilEp, X"60", 0, txStatusSync.frameCount);
      axiSlaveRegisterR(axilEp, X"64", 0, rxStatusSync.rxClkFreq);
      axiSlaveRegisterR(axilEp, X"68", 0, txStatusSync.txClkFreq);
      axiSlaveRegisterR(axilEp, X"70", 0, txStatusSync.txFcSentCount);
      axiSlaveRegisterR(axilEp, X"74", 0, rxStatusSync.rxFcRecvCount);
      axiSlaveRegisterR(axilEp, X"78", 0, rxStatusSync.rxFcErrCount);
      axiSlaveRegisterR(axilEp, X"7C", 0, rxStatusSync.remLinkReadyCnt);
      axiSlaveRegisterR(axilEp, X"80", 0, txStatusSync.txFcWordLast);  -- up to 128 bit word
      axiSlaveRegisterR(axilEp, X"90", 0, rxStatusSync.rxFcWordLast);  -- up to 128 bit word

      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      -- Reset
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Next register assignment
      rin <= v;

      -- Outputs
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;

   end process;


   ---------------------------------------
   -- Status Vector
   ---------------------------------------
   statusSend <= rxStatusSend;

   U_StatusWord : process (rxStatusSync)
   begin
      statusWord <= (others => '0');

      statusWord(ERROR_CNT_WIDTH_G-1+24 downto 24) <= rxStatusSync.linkDownCount;
      statusWord(ERROR_CNT_WIDTH_G-1+16 downto 16) <= rxStatusSync.frameErrCount;
      statusWord(ERROR_CNT_WIDTH_G-1+8 downto 8)   <= rxStatusSync.cellErrorCount;

      statusWord(7 downto 6) <= (others => '0');
      statusWord(5)          <= rxStatusSync.remLinkReady;
      statusWord(4)          <= rxStatusSync.locLinkReady;
      statusWord(3 downto 0) <= rxStatusSync.remOverflow;
   end process;

end architecture structure;

