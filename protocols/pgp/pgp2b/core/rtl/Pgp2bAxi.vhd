-------------------------------------------------------------------------------
-- File       : Pgp2bAxi.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2009-05-27
-- Last update: 2017-03-28
-------------------------------------------------------------------------------
-- Description:
-- AXI-Lite block to manage the PGP interface.
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
--       Bits 7:0 = Last OpCode Transmitted
--    0x74 = Read Only
--       Bits 7:0 = Last OpCode Received
--    0x78 = Read Only
--       Bits ?:0 = OpCode Transmit count
--    0x7C = Read Only
--       Bits ?:0 = OpCode Received count
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
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.Pgp2bPkg.all;

entity Pgp2bAxi is
   generic (
      TPD_G              : time                  := 1 ns;
      COMMON_TX_CLK_G    : boolean               := false;  -- Set to true if axiClk and pgpTxClk are the same clock
      COMMON_RX_CLK_G    : boolean               := false;  -- Set to true if axiClk and pgpRxClk are the same clock
      WRITE_EN_G         : boolean               := false;  -- Set to false when on remote end of a link
      AXI_CLK_FREQ_G     : real                  := 125.0E+6;
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 32;
      ERROR_CNT_WIDTH_G  : natural range 1 to 32 := 4;
      AXI_ERROR_RESP_G   : slv(1 downto 0)       := AXI_RESP_DECERR_C);  
   port (

      -- TX PGP Interface (pgpTxClk)
      pgpTxClk         : in  sl;
      pgpTxClkRst      : in  sl;
      pgpTxIn          : out Pgp2bTxInType;
      pgpTxOut         : in  Pgp2bTxOutType;
      locTxIn          : in  Pgp2bTxInType := PGP2B_TX_IN_INIT_C;

      -- RX PGP Interface (pgpRxClk)
      pgpRxClk         : in  sl;
      pgpRxClkRst      : in  sl;
      pgpRxIn          : out Pgp2bRxInType;
      pgpRxOut         : in  Pgp2bRxOutType;
      locRxIn          : in  Pgp2bRxInType := PGP2B_RX_IN_INIT_C;

      -- Status Bus (axilClk domain)
      statusWord       : out slv(63 downto 0);
      statusSend       : out sl;

      -- AXI-Lite Register Interface (axilClk domain)
      axilClk          : in  sl;
      axilRst          : in  sl;
      axilReadMaster   : in  AxiLiteReadMasterType;
      axilReadSlave    : out AxiLiteReadSlaveType;
      axilWriteMaster  : in  AxiLiteWriteMasterType;
      axilWriteSlave   : out AxiLiteWriteSlaveType
   );
end Pgp2bAxi;

architecture structure of Pgp2bAxi is

   constant STATUS_OUT_TOP_C : integer := ite(STATUS_CNT_WIDTH_G > 7, 7,STATUS_CNT_WIDTH_G-1);

   -- Local signals
   signal rxStatusSend : sl;

   signal rxErrorOut     : slv(17 downto 0);
   signal rxErrorCntOut  : SlVectorArray(17 downto 0, ERROR_CNT_WIDTH_G-1 downto 0);
   signal rxStatusCntOut : SlVectorArray(0 downto 0,  STATUS_CNT_WIDTH_G-1 downto 0);

   signal txErrorOut     : slv(11 downto 0);
   signal txErrorCntOut  : SlVectorArray(11 downto 0, ERROR_CNT_WIDTH_G-1 downto 0);
   signal txStatusCntOut : SlVectorArray(0 downto 0,  STATUS_CNT_WIDTH_G-1 downto 0);

   signal rxErrorIrqEn    : slv(17 downto 0);
   signal locTxDataEn     : sl;
   signal locTxData       : slv(7 downto 0);
   signal txFlush         : sl;
   signal rxFlush         : sl;
   signal rxReset         : sl;
   signal syncFlowCntlDis : sl;

   type RegType is record
      flush          : sl;
      resetRx        : sl;
      countReset     : sl;
      loopBack       : slv(2 downto 0);
      flowCntlDis    : sl;
      autoStatus     : sl;
      locData        : slv(7 downto 0);
      locDataEn      : sl;
      axilWriteSlave : AxiLiteWriteSlaveType;
      axilReadSlave  : AxiLiteReadSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      flush          => '0',
      resetRx        => '0',
      countReset     => '0',
      loopBack       => (others=>'0'),
      flowCntlDis    => '0',
      autoStatus     => '0',
      locData        => (others=>'0'),
      locDataEn      => '0',
      axilWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave   => AXI_LITE_READ_SLAVE_INIT_C
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   type RxStatusType is record
      phyRxReady       : sl;
      linkPolarity     : slv(1  downto 0);
      locLinkReady     : sl;
      remLinkReady     : sl;
      remLinkData      : slv(7 downto 0);
      cellErrorCount   : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      linkDownCount    : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      linkErrorCount   : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      remOverflow      : slv(3 downto 0);
      remOverflow0Cnt  : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      remOverflow1Cnt  : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      remOverflow2Cnt  : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      remOverflow3Cnt  : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      frameErrCount    : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      frameCount       : slv(STATUS_CNT_WIDTH_G-1 downto 0);
      remPause         : slv(3 downto 0);
      rxClkFreq        : slv(31 downto 0);
      rxOpCodeCount    : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      rxOpCodeLast     : slv(7 downto 0);
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
      txOpCodeCount   : slv(ERROR_CNT_WIDTH_G-1 downto 0);
      txOpCodeLast    : slv(7 downto 0);
   end record TxStatusType;

   signal txstatusSync : TxStatusType;

begin


   ---------------------------------------
   -- Receive Status
   ---------------------------------------

   -- OpCode Capture
   U_RxOpCodeSync : entity work.SynchronizerFifo
      generic map (
         TPD_G         => TPD_G,
         BRAM_EN_G     => false,
         ALTERA_SYN_G  => false,
         ALTERA_RAM_G  => "M9K",
         SYNC_STAGES_G => 3,
         DATA_WIDTH_G  => 8,
         ADDR_WIDTH_G  => 2,
         INIT_G        => "0"
      ) port map (
         rst           => r.countReset,
         wr_clk        => pgpRxClk,
         wr_en         => pgpRxOut.opCodeEn,
         din           => pgpRxOut.opCode,
         rd_clk        => axilClk,
         rd_en         => '1',
         valid         => open,
         dout          => rxStatusSync.rxOpCodeLast
      );

   -- Sync remote data
   U_RxDataSyncEn : if COMMON_RX_CLK_G = false generate
      U_RxDataSync : entity work.SynchronizerFifo
         generic map (
            TPD_G         => TPD_G,
            BRAM_EN_G     => false,
            ALTERA_SYN_G  => false,
            ALTERA_RAM_G  => "M9K",
            SYNC_STAGES_G => 3,
            DATA_WIDTH_G  => 8,
            ADDR_WIDTH_G  => 2,
            INIT_G        => "0"
         ) port map (
            rst           => axilRst,
            wr_clk        => pgpRxClk,
            wr_en         => '1',
            din           => pgpRxOut.remLinkData,
            rd_clk        => axilClk,
            rd_en         => '1',
            valid         => open,
            dout          => rxStatusSync.remLinkData
         );
   end generate;

   U_RxDataSyncDis : if COMMON_RX_CLK_G generate
      rxStatusSync.remLinkData <= pgpRxOut.remLinkData;
   end generate;

   -- Errror counters and non counted values
   U_RxError : entity work.SyncStatusVector 
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         COMMON_CLK_G    => COMMON_RX_CLK_G,
         RELEASE_DELAY_G => 3,
         IN_POLARITY_G   => "1",
         OUT_POLARITY_G  => '1',
         USE_DSP48_G     => "no",
         SYNTH_CNT_G     => "111110000111100000",
         CNT_RST_EDGE_G  => false,
         CNT_WIDTH_G     => ERROR_CNT_WIDTH_G,
         WIDTH_G         => 18
      ) port map (
         statusIn(0)             => pgpRxOut.phyRxReady,
         statusIn(1)             => pgpRxOut.linkReady,
         statusIn(3  downto 2)   => pgpRxOut.linkPolarity,
         statusIn(4)             => pgpRxOut.remLinkReady,
         statusIn(8  downto 5)   => pgpRxOut.remOverflow,
         statusIn(12 downto 9)   => pgpRxOut.remPause,
         statusIn(13)            => pgpRxOut.cellError,
         statusIn(14)            => pgpRxOut.linkDown,
         statusIn(15)            => pgpRxOut.linkError,
         statusIn(16)            => pgpRxOut.frameRxErr,
         statusIn(17)            => pgpRxOut.opCodeEn,
         statusOut               => rxErrorOut,
         cntRstIn                => r.countReset,
         rollOverEnIn            => (others=>'0'),
         cntOut                  => rxErrorCntOut,
         irqEnIn                 => rxErrorIrqEn,
         irqOut                  => rxStatusSend,
         wrClk                   => pgpRxClk,
         wrRst                   => pgpRxClkRst,
         rdClk                   => axilClk,
         rdRst                   => axilRst
      );

   U_RxErrorIrqEn : process (r.autoStatus) begin
      rxErrorIrqEn     <= (others=>'0');
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
   rxStatusSync.phyRxReady    <= rxErrorOut(0);
   rxStatusSync.locLinkReady  <= rxErrorOut(1);
   rxStatusSync.linkPolarity  <= rxErrorOut(3 downto 2);
   rxStatusSync.remLinkReady  <= rxErrorOut(4);
   rxStatusSync.remOverflow   <= rxErrorOut(8 downto 5);
   rxStatusSync.remPause      <= rxErrorOut(12 downto 9);

   -- Map counters
   rxStatusSync.remOverflow0Cnt <= muxSlVectorArray(rxErrorCntOut,5);
   rxStatusSync.remOverflow1Cnt <= muxSlVectorArray(rxErrorCntOut,6);
   rxStatusSync.remOverflow2Cnt <= muxSlVectorArray(rxErrorCntOut,7);
   rxStatusSync.remOverflow3Cnt <= muxSlVectorArray(rxErrorCntOut,8);
   rxStatusSync.cellErrorCount  <= muxSlVectorArray(rxErrorCntOut,13);
   rxStatusSync.linkDownCount   <= muxSlVectorArray(rxErrorCntOut,14);
   rxStatusSync.linkErrorCount  <= muxSlVectorArray(rxErrorCntOut,15);
   rxStatusSync.frameErrCount   <= muxSlVectorArray(rxErrorCntOut,16);
   rxStatusSync.rxOpCodeCount   <= muxSlVectorArray(rxErrorCntOut,17);

   -- Status counters
   U_RxStatus : entity work.SyncStatusVector 
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         COMMON_CLK_G    => COMMON_RX_CLK_G,
         RELEASE_DELAY_G => 3,
         IN_POLARITY_G   => "1",
         OUT_POLARITY_G  => '1',
         USE_DSP48_G     => "no",
         SYNTH_CNT_G     => "1",
         CNT_RST_EDGE_G  => false,
         CNT_WIDTH_G     => STATUS_CNT_WIDTH_G,
         WIDTH_G         => 1
      ) port map (
         statusIn(0)     => pgpRxOut.frameRx,
         statusOut       => open,
         cntRstIn        => r.countReset,
         rollOverEnIn    => (others=>'1'),
         cntOut          => rxStatusCntOut,
         irqEnIn         => (others=>'0'),
         irqOut          => open,
         wrClk           => pgpRxClk,
         wrRst           => pgpRxClkRst,
         rdClk           => axilClk,
         rdRst           => axilRst
      );

   rxStatusSync.frameCount <= muxSlVectorArray(rxStatusCntOut,0);

   U_RxClkFreq: entity work.SyncClockFreq 
      generic map (
         TPD_G             => TPD_G,
         USE_DSP48_G       => "no",
         REF_CLK_FREQ_G    => AXI_CLK_FREQ_G,
         REFRESH_RATE_G    => 100.0,
         CLK_LOWER_LIMIT_G => 159.0E+6,
         CLK_UPPER_LIMIT_G => 161.0E+6,
         CNT_WIDTH_G       => 32
      ) port map (
         freqOut     => rxStatusSync.rxClkFreq,
         freqUpdated => open,
         locked      => open,
         tooFast     => open,
         tooSlow     => open,
         clkIn       => pgpRxClk,
         locClk      => axilClk,
         refClk      => axilClk
      );


   ---------------------------------------
   -- Transmit Status
   ---------------------------------------

   -- OpCode Capture
   U_TxOpCodeSync : entity work.SynchronizerFifo
      generic map (
         TPD_G         => TPD_G,
         BRAM_EN_G     => false,
         ALTERA_SYN_G  => false,
         ALTERA_RAM_G  => "M9K",
         SYNC_STAGES_G => 3,
         DATA_WIDTH_G  => 8,
         ADDR_WIDTH_G  => 2,
         INIT_G        => "0"
      ) port map (
         rst           => r.countReset,
         wr_clk        => pgpTxClk,
         wr_en         => locTxIn.opCodeEn,
         din           => locTxIn.opCode,
         rd_clk        => axilClk,
         rd_en         => '1',
         valid         => open,
         dout          => txStatusSync.txOpCodeLast
      );

   -- Errror counters and non counted values
   U_TxError : entity work.SyncStatusVector 
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         COMMON_CLK_G    => COMMON_TX_CLK_G,
         RELEASE_DELAY_G => 3,
         IN_POLARITY_G   => "1",
         OUT_POLARITY_G  => '1',
         USE_DSP48_G     => "no",
         SYNTH_CNT_G     => "110000111100",
         CNT_RST_EDGE_G  => false,
         CNT_WIDTH_G     => ERROR_CNT_WIDTH_G,
         WIDTH_G         => 12
      ) port map (
         statusIn(0)            => pgpTxOut.phyTxReady,
         statusIn(1)            => pgpTxOut.linkReady,
         statusIn(5 downto 2)   => pgpTxOut.locOverflow,
         statusIn(9 downto 6)   => pgpTxOut.locPause,
         statusIn(10)           => pgpTxOut.frameTxErr,
         statusIn(11)           => locTxIn.opCodeEn,
         statusOut              => txErrorOut,
         cntRstIn               => r.countReset,
         rollOverEnIn           => (others=>'0'),
         cntOut                 => txErrorCntOut,
         irqEnIn                => (others=>'0'),
         irqOut                 => open,
         wrClk                  => pgpTxClk,
         wrRst                  => pgpTxClkRst,
         rdClk                  => axilClk,
         rdRst                  => axilRst
      );

   -- Map Status
   txStatusSync.phyTxReady  <= txErrorOut(0);
   txStatusSync.txLinkReady <= txErrorOut(1);
   txStatusSync.locOverFlow <= txErrorOut(5 downto 2);
   txStatusSync.locPause    <= txErrorOut(9 downto 6);

   -- Map counters
   txStatusSync.locOverflow0Cnt <= muxSlVectorArray(txErrorCntOut,2);
   txStatusSync.locOverflow1Cnt <= muxSlVectorArray(txErrorCntOut,3);
   txStatusSync.locOverflow2Cnt <= muxSlVectorArray(txErrorCntOut,4);
   txStatusSync.locOverflow3Cnt <= muxSlVectorArray(txErrorCntOut,5);
   txStatusSync.frameErrCount   <= muxSlVectorArray(txErrorCntOut,10);
   txStatusSync.txOpCodeCount   <= muxSlVectorArray(txErrorCntOut,11);

   -- Status counters
   U_TxStatus : entity work.SyncStatusVector 
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         COMMON_CLK_G    => COMMON_TX_CLK_G,
         RELEASE_DELAY_G => 3,
         IN_POLARITY_G   => "1",
         OUT_POLARITY_G  => '1',
         USE_DSP48_G     => "no",
         SYNTH_CNT_G     => "1",
         CNT_RST_EDGE_G  => false,
         CNT_WIDTH_G     => STATUS_CNT_WIDTH_G,
         WIDTH_G         => 1
      ) port map (
         statusIn(0)     => pgpTxOut.frameTx,
         statusOut       => open,
         cntRstIn        => r.countReset,
         rollOverEnIn    => (others=>'1'),
         cntOut          => txStatusCntOut,
         irqEnIn         => (others=>'0'),
         irqOut          => open,
         wrClk           => pgpTxClk,
         wrRst           => pgpTxClkRst,
         rdClk           => axilClk,
         rdRst           => axilRst
      );

   txStatusSync.frameCount <= muxSlVectorArray(txStatusCntOut,0);

   U_TxClkFreq: entity work.SyncClockFreq 
      generic map (
         TPD_G             => TPD_G,
         USE_DSP48_G       => "no",
         REF_CLK_FREQ_G    => AXI_CLK_FREQ_G,
         REFRESH_RATE_G    => 100.0,
         CLK_LOWER_LIMIT_G => 159.0E+6,
         CLK_UPPER_LIMIT_G => 161.0E+6,
         CNT_WIDTH_G       => 32
      ) port map (
         freqOut     => txStatusSync.txClkFreq,
         freqUpdated => open,
         locked      => open,
         tooFast     => open,
         tooSlow     => open,
         clkIn       => pgpTxClk,
         locClk      => axilClk,
         refClk      => axilClk
      );

   -------------------------------------
   -- Tx Control Sync
   -------------------------------------

   -- Sync Tx Control
   U_TxDataSyncEn : if COMMON_RX_CLK_G = false generate
      U_TxDataSync : entity work.SynchronizerFifo 
         generic map (
            TPD_G         => TPD_G,
            BRAM_EN_G     => false,
            ALTERA_SYN_G  => false,
            ALTERA_RAM_G  => "M9K",
            SYNC_STAGES_G => 3,
            DATA_WIDTH_G  => 9,
            ADDR_WIDTH_G  => 2,
            INIT_G        => "0"
         ) port map (
            rst              => axilRst,
            wr_clk           => axilClk,
            wr_en            => '1',
            din(8)           => r.locDataEn,
            din(7 downto 0)  => r.locData,
            rd_clk           => pgpTxClk,
            rd_en            => '1',
            valid            => open,
            dout(8)          => locTxDataEn,
            dout(7 downto 0) => locTxData
         );
   end generate;

   -- Sync flow cntl disable
   U_FlowCntlDis: entity work.Synchronizer
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         OUT_POLARITY_G => '1',
         RST_ASYNC_G    => false,
         STAGES_G       => 2,
         INIT_G         => "0"
      ) port map (
         clk        => pgpTxClk,
         rst        => pgpTxClkRst,
         dataIn     => r.flowCntlDis,
         dataOut    => syncFlowCntlDis
      );


   U_TxDataSyncDis : if COMMON_RX_CLK_G generate
      locTxDataEn <= r.locDataEn;
      locTxData   <= r.locData;
   end generate;

   -- Flush Sync
   U_TxFlushSync: entity work.RstSync 
      generic map (
         TPD_G           => TPD_G,
         IN_POLARITY_G   => '1',
         OUT_POLARITY_G  => '1',
         RELEASE_DELAY_G => 3
      ) port map (
         clk      => pgpTxClk,
         asyncRst => r.flush,
         syncRst  => txFlush
      );

   -- Set tx input
   pgpTxIn.flush       <= locTxIn.flush or txFlush;
   pgpTxIn.opCodeEn    <= locTxIn.opCodeEn;
   pgpTxIn.opCode      <= locTxIn.opCode;
   pgpTxIn.locData     <= locTxData when locTxDataEn = '1' else locTxIn.locData;
   pgpTxIn.flowCntlDis <= locTxIn.flowCntlDis or syncFlowCntlDis;


   -------------------------------------
   -- Rx Control Sync
   -------------------------------------

   -- Flush Sync
   U_RxFlushSync: entity work.RstSync 
      generic map (
         TPD_G           => TPD_G,
         IN_POLARITY_G   => '1',
         OUT_POLARITY_G  => '1',
         RELEASE_DELAY_G => 3
      ) port map (
         clk      => pgpRxClk,
         asyncRst => r.flush,
         syncRst  => rxFlush
      );

   -- Reset Rx Sync
   U_ResetRxSync: entity work.RstSync 
      generic map (
         TPD_G           => TPD_G,
         IN_POLARITY_G   => '1',
         OUT_POLARITY_G  => '1',
         RELEASE_DELAY_G => 16
      ) port map (
         clk      => pgpRxClk,
         asyncRst => r.resetRx,
         syncRst  => rxReset
      );

   -- Set rx input
   pgpRxIn.flush       <= locRxIn.flush       or rxFlush;
   pgpRxIn.resetRx     <= locRxIn.resetRx     or rxReset;
   pgpRxIn.loopback    <= locRxIn.loopback    or r.loopBack;


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

      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axiStatus);

      -- Write
      if (axiStatus.writeEnable = '1') then

         -- Decode address and perform write
         case (axilWriteMaster.awaddr(7 downto 0)) is
            when X"00" =>
               v.countReset := axilWriteMaster.wdata(0);
            when X"04" =>
               v.resetRx    := ite(WRITE_EN_G,axilWriteMaster.wdata(0),'0');
            when X"08" =>
               v.flush      := ite(WRITE_EN_G,axilWriteMaster.wdata(0),'0');
            when X"0C" =>
               v.loopBack   := ite(WRITE_EN_G,axilWriteMaster.wdata(2 downto 0),"000");
            when X"10" =>
               v.locDataEn  := axilWriteMaster.wdata(8);
               v.locData    := axilWriteMaster.wdata(7 downto 0);
            when X"14" =>
               v.autoStatus := axilWriteMaster.wdata(0);
            when X"18" =>
               v.flowCntlDis := ite(WRITE_EN_G,axilWriteMaster.wdata(0),'0');
            when others => null;
         end case;

         -- Send Axi response
         axiSlaveWriteResponse(v.axilWriteSlave);
      end if;

      -- Read
      if (axiStatus.readEnable = '1') then
         v.axilReadSlave.rdata := (others => '0');

         -- Decode address and assign read data
         case axilReadMaster.araddr(7 downto 0) is
            when X"00" =>
               v.axilReadSlave.rdata(0) := r.countReset;
            when X"04" =>
               v.axilReadSlave.rdata(0) := r.resetRx;
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
               v.axilReadSlave.rdata(9  downto  8) := rxStatusSync.linkPolarity;
               v.axilReadSlave.rdata(15 downto 12) := rxStatusSync.remPause;
               v.axilReadSlave.rdata(19 downto 16) := txStatusSync.locPause;
               v.axilReadSlave.rdata(23 downto 20) := rxStatusSync.remOverflow;
               v.axilReadSlave.rdata(27 downto 24) := txStatusSync.locOverflow;
            when X"24" =>
               v.axilReadSlave.rdata(7 downto 0) := rxStatusSync.remLinkData;
            when X"28" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0)  := rxStatusSync.cellErrorCount;
            when X"2C" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0)  := rxStatusSync.linkDownCount;
            when X"30" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0)  := rxStatusSync.linkErrorCount;
            when X"34" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0)  := rxStatusSync.remOverflow0Cnt;
            when X"38" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0)  := rxStatusSync.remOverflow1Cnt;
            when X"3C" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0)  := rxStatusSync.remOverflow2Cnt;
            when X"40" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0)  := rxStatusSync.remOverflow3Cnt;
            when X"44" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0)  := rxStatusSync.frameErrCount;
            when X"48" =>
               v.axilReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := rxStatusSync.frameCount;
            when X"4C" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0)  := txStatusSync.locOverflow0Cnt;
            when X"50" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0)  := txStatusSync.locOverflow1Cnt;
            when X"54" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0)  := txStatusSync.locOverflow2Cnt;
            when X"58" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0)  := txStatusSync.locOverflow3Cnt;
            when X"5C" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0)  := txStatusSync.frameErrCount;
            when X"60" =>
               v.axilReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := txStatusSync.frameCount;
            when X"64" =>
               v.axilReadSlave.rdata := rxStatusSync.rxClkFreq;
            when X"68" =>
               v.axilReadSlave.rdata := txStatusSync.txClkFreq;
            when X"70" =>
               v.axilReadSlave.rdata(7 downto 0) := txStatusSync.txOpCodeLast;
            when X"74" =>
               v.axilReadSlave.rdata(7 downto 0) := rxStatusSync.rxOpCodeLast;
            when X"78" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0) := txStatusSync.txOpCodeCount;
            when X"7C" =>
               v.axilReadSlave.rdata(ERROR_CNT_WIDTH_G-1 downto 0) := rxStatusSync.rxOpCodeCount;               

            when others => null;
         end case;

         -- Send Axi Response
         axiSlaveReadResponse(v.axilReadSlave);
      end if;

      -- Reset
      if (axilRst = '1' ) then
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

   U_StatusWord : process ( rxStatusSync ) begin
      statusWord <= (others=>'0');

      statusWord(ERROR_CNT_WIDTH_G-1+24 downto 24) <= rxStatusSync.linkDownCount;
      statusWord(ERROR_CNT_WIDTH_G-1+16 downto 16) <= rxStatusSync.frameErrCount;
      statusWord(ERROR_CNT_WIDTH_G-1+8  downto  8) <= rxStatusSync.cellErrorCount;

      statusWord(7 downto 6) <= (others=>'0');
      statusWord(5)          <= rxStatusSync.remLinkReady;
      statusWord(4)          <= rxStatusSync.locLinkReady;
      statusWord(3 downto 0) <= rxStatusSync.remOverflow;
   end process;

end architecture structure;

