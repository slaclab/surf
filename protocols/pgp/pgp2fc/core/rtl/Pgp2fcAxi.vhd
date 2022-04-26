-------------------------------------------------------------------------------
-- Title      : PGPv2fc: https://confluence.slac.stanford.edu/x/q86fD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- AXI-Lite block to manage the PGP (fc) interface.
--
-- Address map (offset from base):
--    0x00 = Read/Write
--       Bits 0 = Count Reset
--    0x04 = Read/Write
--       Bits 0 = Reset Rx
--    0x08 = Read/Write
--       Bits 0 = Flush
--    0x0C = Read/Write
--       Bits 1:0 = Loop Back
--    0x10 = Read/Write
--       Bits 7:0 = Sideband data to transmit
--       Bits 8   = Sideband data enable
--    0x14 = Read/Write
--       Bits 0 = Auto Status Send Enable (PPI)
--    0x18 = Read/Write
--       Bits 0 = Disable Flow Control
--    0x20 = Read Only
--       Bits 0     = Rx Phy Ready
--       Bits 1     = Tx Phy Ready
--       Bits 2     = Local Link Ready
--       Bits 3     = Remote Link Ready
--       Bits 4     = Transmit Ready
--       Bits 9:8   = Receive Link Polarity
--       Bits 15:12 = Remote Pause Status
--       Bits 19:16 = Local Pause Status
--       Bits 23:20 = Remote Overflow Status
--       Bits 27:24 = Local Overflow Status
--    0x24 = Read Only
--       Bits 7:0 = Remote Link Data
--    0x28 = Read Only
--       Bits ?:0 = Cell Error Count
--    0x2C = Read Only
--       Bits ?:0 = Link Down Count
--    0x30 = Read Only
--       Bits ?:0 = Link Error Count
--    0x34 = Read Only
--       Bits ?:0 = Remote Overflow VC 0 Count
--    0x38 = Read Only
--       Bits ?:0 = Remote Overflow VC 1 Count
--    0x3C = Read Only
--       Bits ?:0 = Remote Overflow VC 2 Count
--    0x40 = Read Only
--       Bits ?:0 = Remote Overflow VC 3 Count
--    0x44 = Read Only
--       Bits ?:0 = Receive Frame Error Count
--    0x48 = Read Only
--       Bits ?:0 = Receive Frame Count
--    0x4C = Read Only
--       Bits ?:0 = Local Overflow VC 0 Count
--    0x50 = Read Only
--       Bits ?:0 = Local Overflow VC 1 Count
--    0x54 = Read Only
--       Bits ?:0 = Local Overflow VC 2 Count
--    0x58 = Read Only
--       Bits ?:0 = Local Overflow VC 3 Count
--    0x5C = Read Only
--       Bits ?:0 = Transmit Frame Error Count
--    0x60 = Read Only
--       Bits ?:0 = Transmit Frame Count
--    0x64 = Read Only
--       Bits 31:0 = Receive Clock Frequency
--    0x68 = Read Only
--       Bits 31:0 = Transmit Clock Frequency
--    0x70 = Read Only
--       Bits ?:0 = Fast Control Sent Count
--    0x74 = Read Only
--       Bits ?:0 = Fast Control Received Count
--    0x78 = Read Only
--       Bits ?:0 = Fast Control Received Error Count
--    0xA0 = Read/Write
--       Bits 0     = Reset link alignment block
--       Bits 1     = Place link alignment block in manual mode
--    0xA4 = Write Only
--       Bits ?     = Issue an RXSLIDE, automatically cleared
--    0xA8 = Read Only
--       Bits 0     = Alignment status
--       Bits 1     = Asserted when RXSLIDE is done
--       Bits 2     = Alignment Latency (0 or 1)
--       Bits 3     = Alignment Latency Valid
--    0xAC = Write Only
--       Bits ?     = Issue a request to get the phase latency
--
-- Status vector:
--       Bits 31:24 = Rx Link Down Count
--       Bits 23:16 = Rx Frame Error Count
--       Bits 15:8  = Rx Cell Error Count
--       Bits  7:6  = Zeros
--       Bits    5  = Remote Link Ready
--       Bits    4  = Local Link Ready
--       Bits  3:0  = Remote Overflow Status
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
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 32;
      ERROR_CNT_WIDTH_G  : natural range 1 to 32 := 4);
   port (

      -- TX PGP Interface (pgpTxClk domain)
      pgpTxClk    : in  sl;
      pgpTxClkRst : in  sl;
      pgpTxIn     : out Pgp2fcTxCtrlInType;
      pgpTxOut    : in  Pgp2fcTxStatusOutType;
      locTxIn     : in  Pgp2fcTxCtrlInType := PGP2FC_TX_CTRL_IN_INIT_C;

      -- RX PGP Interface (pgpRxClk domain)
      pgpRxClk    : in  sl;
      pgpRxClkRst : in  sl;
      pgpRxIn     : out Pgp2fcRxCtrlInType;
      pgpRxOut    : in  Pgp2fcRxStatusOutType;
      locRxIn     : in  Pgp2fcRxCtrlInType := PGP2FC_RX_CTRL_IN_INIT_C;

      -- RX PGP Link Alignment Control (axilClk domain)
      linkAlignRst        : out sl;
      linkAligned         : in sl := '0';
      linkAlignOverride   : out sl;
      linkAlignSlide      : out sl;
      linkAlignSlideDone  : in sl := '0';
      linkAlignPhaseReq   : out sl;
      linkAlignPhase      : in sl := '0';
      linkAlignPhaseValid : in sl := '0';

      -- Protocol error for error tracking (pgpRxClk domain)
      protocolError       : in sl := '0';

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

   signal rxErrorOut     : slv(17 downto 0);
   signal rxErrorCntOut  : SlVectorArray(17 downto 0, ERROR_CNT_WIDTH_G-1 downto 0);
   signal rxStatusCntOut : SlVectorArray(0 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);

   signal txErrorOut     : slv(11 downto 0);
   signal txErrorCntOut  : SlVectorArray(11 downto 0, ERROR_CNT_WIDTH_G-1 downto 0);
   signal txStatusCntOut : SlVectorArray(0 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);

   signal rxErrorIrqEn    : slv(17 downto 0);
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

      aligned         : sl;
      alignSlideDone  : sl;
      alignPhase      : sl;
      alignPhaseValid : sl;
      protocolErrorCount : slv(ERROR_CNT_WIDTH_G-1 downto 0);

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

      txFcSentCount   : slv(ERROR_CNT_WIDTH_G-1 downto 0);
   end record TxStatusType;

   signal txstatusSync : TxStatusType;

begin


   ---------------------------------------
   -- Receive Status
   ---------------------------------------

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
         SYNTH_CNT_G    => "111111100001111100",
         CNT_RST_EDGE_G => false,
         CNT_WIDTH_G    => ERROR_CNT_WIDTH_G,
         WIDTH_G        => 18)
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
         statusIn(15)          => pgpRxOut.fcRecv,
         statusIn(16)          => pgpRxOut.fcRecvErr,
         statusIn(17)          => protocolError,
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
      rxErrorIrqEn(17) <= r.autoStatus;
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
   rxStatusSync.protocolErrorCount <= muxSlVectorArray(rxErrorCntOut, 17);

   rxStatusSync.aligned         <= linkAligned;
   rxStatusSync.alignSlideDone  <= linkAlignSlideDone;
   rxStatusSync.alignPhase      <= linkAlignPhase;
   rxStatusSync.alignPhaseValid <= linkAlignPhaseValid;

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

   linkAlignRst      <= r.alignRst;
   linkAlignOverride <= r.alignOverride;
   linkAlignSlide    <= r.alignSlide;
   linkAlignPhaseReq <= r.alignPhaseReq;



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
      variable v         : RegType;
      variable axiStatus : AxiLiteStatusType;
   begin
      v := r;

      -- Automatic clear
      v.alignSlide := '0';
      v.alignPhaseReq := '0';

      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axiStatus);

      -- Write
      if (axiStatus.writeEnable = '1') then

         -- Decode address and perform write
         case (axilWriteMaster.awaddr(7 downto 0)) is
            when X"00" =>
               v.countReset := axilWriteMaster.wdata(0);
            when X"04" =>
               v.resetRx := ite(WRITE_EN_G, axilWriteMaster.wdata(0), '0');
               v.resetTx := ite(WRITE_EN_G, axilWriteMaster.wdata(1), '0');
               v.resetGt := ite(WRITE_EN_G, axilWriteMaster.wdata(2), '0');
            when X"08" =>
               v.flush := ite(WRITE_EN_G, axilWriteMaster.wdata(0), '0');
            when X"0C" =>
               v.loopBack := ite(WRITE_EN_G, axilWriteMaster.wdata(2 downto 0), "000");
            when X"10" =>
               v.locDataEn := axilWriteMaster.wdata(8);
               v.locData   := axilWriteMaster.wdata(7 downto 0);
            when X"14" =>
               v.autoStatus := axilWriteMaster.wdata(0);
            when X"18" =>
               v.flowCntlDis := ite(WRITE_EN_G, axilWriteMaster.wdata(0), '0');
            when X"A0" =>
               v.alignRst := ite(WRITE_EN_G, axilWriteMaster.wdata(0), '0');
               v.alignOverride  := ite(WRITE_EN_G, axilWriteMaster.wdata(1), '0');
            when X"A4" =>
               v.alignSlide := ite(WRITE_EN_G, '1', '0');
            when X"AC" =>
               v.alignPhaseReq := ite(WRITE_EN_G, '1', '0');
            when others => null;
         end case;

         -- Send Axi response
         axiSlaveWriteResponse(v.axilWriteSlave);
      end if;

      -- Read
      if (axiStatus.readEnable = '1') then

         -- Decode address and assign read data
         case axilReadMaster.araddr(7 downto 0) is
            when X"00" =>
               v.axilReadSlave.rdata(0) := r.countReset;
            when X"04" =>
               v.axilReadSlave.rdata(0) := r.resetRx;
               v.axilReadSlave.rdata(1) := r.resetTx;
               v.axilReadSlave.rdata(2) := r.resetGt;
            when X"08" =>
               v.axilReadSlave.rdata(0) := r.flush;
            when X"0C" =>
               v.axilReadSlave.rdata(2 downto 0) := r.loopBack;
            when X"10" =>
               v.axilReadSlave.rdata(8)          := r.locDataEn;
               v.axilReadSlave.rdata(7 downto 0) := r.locData;
            when X"14" =>
               v.axilReadSlave.rdata(0) := r.autoStatus;
            when X"18" =>
               v.axilReadSlave.rdata(0) := r.flowCntlDis;
            when X"20" =>
               v.axilReadSlave.rdata(0)            := rxStatusSync.phyRxReady;
               v.axilReadSlave.rdata(1)            := txStatusSync.phyTxReady;
               v.axilReadSlave.rdata(2)            := rxStatusSync.locLinkReady;
               v.axilReadSlave.rdata(3)            := rxStatusSync.remLinkReady;
               v.axilReadSlave.rdata(4)            := txStatusSync.txLinkReady;
               v.axilReadSlave.rdata(9 downto 8)   := "00";
               v.axilReadSlave.rdata(15 downto 12) := rxStatusSync.remPause;
               v.axilReadSlave.rdata(19 downto 16) := txStatusSync.locPause;
               v.axilReadSlave.rdata(23 downto 20) := rxStatusSync.remOverflow;
               v.axilReadSlave.rdata(27 downto 24) := txStatusSync.locOverflow;
            when X"24" =>
               v.axilReadSlave.rdata(7 downto 0) := rxStatusSync.remLinkData;
            when X"28" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0) := rxStatusSync.cellErrorCount;
            when X"2C" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0) := rxStatusSync.linkDownCount;
            when X"30" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0) := rxStatusSync.linkErrorCount;
            when X"34" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0) := rxStatusSync.remOverflow0Cnt;
            when X"38" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0) := rxStatusSync.remOverflow1Cnt;
            when X"3C" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0) := rxStatusSync.remOverflow2Cnt;
            when X"40" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0) := rxStatusSync.remOverflow3Cnt;
            when X"44" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0) := rxStatusSync.frameErrCount;
            when X"48" =>
               v.axilReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := rxStatusSync.frameCount;
            when X"4C" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0) := txStatusSync.locOverflow0Cnt;
            when X"50" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0) := txStatusSync.locOverflow1Cnt;
            when X"54" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0) := txStatusSync.locOverflow2Cnt;
            when X"58" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0) := txStatusSync.locOverflow3Cnt;
            when X"5C" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0) := txStatusSync.frameErrCount;
            when X"60" =>
               v.axilReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := txStatusSync.frameCount;
            when X"64" =>
               v.axilReadSlave.rdata := rxStatusSync.rxClkFreq;
            when X"68" =>
               v.axilReadSlave.rdata := txStatusSync.txClkFreq;
            when X"70" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0) := txStatusSync.txFcSentCount;
            when X"74" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0) := rxStatusSync.rxFcRecvCount;
            when X"78" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0) := rxStatusSync.rxFcErrCount;
            when X"7C" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0) := rxStatusSync.remLinkReadyCnt;
            when X"A0" =>
               v.axilReadSlave.rdata(0) := r.alignRst;
               v.axilReadSlave.rdata(1) := r.alignOverride;
            when X"A8" =>
               v.axilReadSlave.rdata(0) := rxStatusSync.aligned;
               v.axilReadSlave.rdata(1) := rxStatusSync.alignSlideDone;
               v.axilReadSlave.rdata(2) := rxStatusSync.alignPhase;
               v.axilReadSlave.rdata(3) := rxStatusSync.alignPhaseValid;
            when X"B0" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0) := rxStatusSync.protocolErrorCount;

            when others => null;
         end case;

         -- Send Axi Response
         axiSlaveReadResponse(v.axilReadSlave);
      end if;

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

