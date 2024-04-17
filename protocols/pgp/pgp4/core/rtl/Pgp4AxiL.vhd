-------------------------------------------------------------------------------
-- Title      : PGPv4: https://confluence.slac.stanford.edu/x/1dzgEQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI-Lite block to manage the PGPv4 interface
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
use surf.Pgp4Pkg.all;

entity Pgp4AxiL is
   generic (
      TPD_G              : time                  := 1 ns;
      RST_ASYNC_G        : boolean               := false;
      COMMON_TX_CLK_G    : boolean               := false;  -- Set to true if axiClk and pgpTxClk are the same clock
      COMMON_RX_CLK_G    : boolean               := false;  -- Set to true if axiClk and pgpRxClk are the same clock
      WRITE_EN_G         : boolean               := true;  -- Set to false when on remote end of a link
      NUM_VC_G           : integer range 1 to 16 := 4;
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 16;
      ERROR_CNT_WIDTH_G  : natural range 1 to 32 := 8;
      AXIL_CLK_FREQ_G    : real                  := 125.0E+6);
   port (
      -- TX PGP Interface (pgpTxClk)
      pgpTxClk        : in  sl;
      pgpTxRst        : in  sl;
      pgpTxIn         : out Pgp4TxInType;
      pgpTxOut        : in  Pgp4TxOutType;
      locTxIn         : in  Pgp4TxInType := PGP4_TX_IN_INIT_C;
      -- RX PGP Interface (pgpRxClk)
      pgpRxClk        : in  sl;
      pgpRxRst        : in  sl;
      pgpRxIn         : out Pgp4RxInType;
      pgpRxOut        : in  Pgp4RxOutType;
      locRxIn         : in  Pgp4RxInType := PGP4_RX_IN_INIT_C;
      -- Debug Interface (axilClk domain)
      txDiffCtrl      : out slv(4 downto 0);
      txPreCursor     : out slv(4 downto 0);
      txPostCursor    : out slv(4 downto 0);
      -- AXI-Lite Register Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end Pgp4AxiL;

architecture mapping of Pgp4AxiL is

   constant RX_STATUS_CNT_SIZE_C : integer := 2;
   constant RX_ERROR_CNT_SIZE_C  : integer := 16;

   constant TX_STATUS_CNT_SIZE_C : integer := 2;
   constant TX_ERROR_CNT_SIZE_C  : integer := 3;

   type RegType is record
      countReset     : sl;
      skpInterval    : slv(31 downto 0);
      loopBack       : slv(2 downto 0);
      flowCntlDis    : sl;
      txDisable      : sl;
      resetTx        : sl;
      resetRx        : sl;
      txDiffCtrl     : slv(4 downto 0);
      txPreCursor    : slv(4 downto 0);
      txPostCursor   : slv(4 downto 0);
      axilWriteSlave : AxiLiteWriteSlaveType;
      axilReadSlave  : AxiLiteReadSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      countReset     => '0',
      skpInterval    => PGP4_TX_IN_INIT_C.skpInterval,
      loopBack       => (others => '0'),
      flowCntlDis    => PGP4_TX_IN_INIT_C.flowCntlDis,
      txDisable      => PGP4_TX_IN_INIT_C.disable,
      resetTx        => PGP4_TX_IN_INIT_C.resetTx,
      resetRx        => PGP4_RX_IN_INIT_C.resetRx,
      txDiffCtrl     => (others => '1'),
      txPreCursor    => "00111",
      txPostCursor   => "00111",
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- RX
   signal rxClkFreq    : slv(31 downto 0);
   signal resetRx      : sl;
   signal remLinkData  : slv(47 downto 0);
   signal rxOpCodeData : slv(47 downto 0);

   signal remRxPause    : slv(NUM_VC_G-1 downto 0);
   signal remRxPauseCnt : SlVectorArray(NUM_VC_G-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);

   signal remRxOverflow    : slv(NUM_VC_G-1 downto 0);
   signal remRxOverflowCnt : SlVectorArray(NUM_VC_G-1 downto 0, ERROR_CNT_WIDTH_G-1 downto 0);

   signal rxStatus    : slv(RX_STATUS_CNT_SIZE_C-1 downto 0);
   signal rxStatusCnt : SlVectorArray(RX_STATUS_CNT_SIZE_C-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);

   signal rxError    : slv(RX_ERROR_CNT_SIZE_C-1 downto 0);
   signal rxErrorCnt : SlVectorArray(RX_ERROR_CNT_SIZE_C-1 downto 0, ERROR_CNT_WIDTH_G-1 downto 0);

   -- TX
   signal txClkFreq    : slv(31 downto 0);
   signal skpInterval  : slv(31 downto 0);
   signal flowCntlDis  : sl;
   signal txDisable    : sl;
   signal resetTx      : sl;
   signal locData      : slv(47 downto 0);
   signal txOpCodeData : slv(47 downto 0);

   signal locPause    : slv(NUM_VC_G-1 downto 0);
   signal locPauseCnt : SlVectorArray(NUM_VC_G-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);

   signal locOverflow    : slv(NUM_VC_G-1 downto 0);
   signal locOverflowCnt : SlVectorArray(NUM_VC_G-1 downto 0, ERROR_CNT_WIDTH_G-1 downto 0);

   signal txStatus    : slv(TX_STATUS_CNT_SIZE_C-1 downto 0);
   signal txStatusCnt : SlVectorArray(TX_STATUS_CNT_SIZE_C-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);

   signal txError    : slv(TX_ERROR_CNT_SIZE_C-1 downto 0);
   signal txErrorCnt : SlVectorArray(TX_ERROR_CNT_SIZE_C-1 downto 0, ERROR_CNT_WIDTH_G-1 downto 0);

begin

   ---------------
   -- Set TX input
   ---------------
   pgpTxIn.disable     <= locTxIn.disable or txDisable;
   pgpTxIn.flowCntlDis <= locTxIn.flowCntlDis or flowCntlDis;
   pgpTxIn.resetTx     <= locTxIn.resetTx or resetTx;
   pgpTxIn.skpInterval <= skpInterval when(WRITE_EN_G) else locTxIn.skpInterval;
   pgpTxIn.opCodeEn    <= locTxIn.opCodeEn;
   pgpTxIn.opCodeData  <= locTxIn.opCodeData;
   pgpTxIn.locData     <= locTxIn.locData;

   ---------------
   -- Set RX input
   ---------------
   pgpRxIn.loopback <= locRxIn.loopback or r.loopBack;
   pgpRxIn.resetRx  <= locRxIn.resetRx or resetRx;

   ---------------------
   -- AXI-Lite Registers
   ---------------------
   process (axilReadMaster, axilRst, axilWriteMaster, locData, locOverflowCnt,
            locPause, locPauseCnt, r, remLinkData, remRxOverflowCnt,
            remRxPause, remRxPauseCnt, rxClkFreq, rxError, rxErrorCnt,
            rxOpCodeData, rxStatus, rxStatusCnt, txClkFreq, txError,
            txErrorCnt, txOpCodeData, txStatus, txStatusCnt) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      -- Latch the current value
      v := r;

      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      ----------------------------------------------------------------------------------------------
      -- Control = 0x000 in SW
      ----------------------------------------------------------------------------------------------

      axiSlaveRegister (axilEp, x"000", 0, v.countReset);
      axiSlaveRegisterR(axilEp, x"004", 0, ite(WRITE_EN_G, '1', '0'));
      axiSlaveRegisterR(axilEp, x"004", 8, toSlv(NUM_VC_G, 8));
      axiSlaveRegisterR(axilEp, x"004", 16, toSlv(STATUS_CNT_WIDTH_G, 8));
      axiSlaveRegisterR(axilEp, x"004", 24, toSlv(ERROR_CNT_WIDTH_G, 8));

      if (WRITE_EN_G) then
         axiSlaveRegister (axilEp, x"008", 0, v.skpInterval);
         axiSlaveRegister (axilEp, x"00C", 0, v.loopback);
         axiSlaveRegister (axilEp, x"00C", 3, v.flowCntlDis);
         axiSlaveRegister (axilEp, x"00C", 4, v.txDisable);
         axiSlaveRegister (axilEp, x"00C", 5, v.resetTx);
         axiSlaveRegister (axilEp, x"00C", 6, v.resetTx);
         axiSlaveRegister (axilEp, x"00C", 8, v.txDiffCtrl);
         axiSlaveRegister (axilEp, x"00C", 16, v.txPreCursor);
         axiSlaveRegister (axilEp, x"00C", 24, v.txPostCursor);
      else
         axiSlaveRegisterR(axilEp, x"008", 0, r.skpInterval);
         axiSlaveRegisterR(axilEp, x"00C", 0, r.loopback);
         axiSlaveRegisterR(axilEp, x"00C", 3, r.flowCntlDis);
         axiSlaveRegisterR(axilEp, x"00C", 4, r.txDisable);
         axiSlaveRegisterR(axilEp, x"00C", 5, r.resetTx);
         axiSlaveRegisterR(axilEp, x"00C", 6, r.resetTx);
         axiSlaveRegisterR(axilEp, x"00C", 8, r.txDiffCtrl);
         axiSlaveRegisterR(axilEp, x"00C", 16, r.txPreCursor);
         axiSlaveRegisterR(axilEp, x"00C", 24, r.txPostCursor);
      end if;

      ----------------------------------------------------------------------------------------------
      -- RX Status: Offset = 0x400 in SW
      ----------------------------------------------------------------------------------------------

      for i in 0 to NUM_VC_G-1 loop
         axiSlaveRegisterR(axilEp, x"400"+toSlv(i*4, 12), 0, muxSlVectorArray(remRxPauseCnt, i));  -- 0x400:0x43F
         axiSlaveRegisterR(axilEp, x"440"+toSlv(i*4, 12), 0, muxSlVectorArray(remRxOverflowCnt, i));  -- 0x440:0x47F
      end loop;

      for i in 0 to RX_STATUS_CNT_SIZE_C-1 loop
         axiSlaveRegisterR(axilEp, x"500"+toSlv(i*4, 12), 0, muxSlVectorArray(rxStatusCnt, i));
      end loop;

      for i in 0 to RX_ERROR_CNT_SIZE_C-1 loop
         axiSlaveRegisterR(axilEp, x"600"+toSlv(i*4, 12), 0, muxSlVectorArray(rxErrorCnt, i));
      end loop;

      axiSlaveRegisterR(axilEp, x"710", 0, rxError);
      axiSlaveRegisterR(axilEp, x"720", 0, remLinkData);
      axiSlaveRegisterR(axilEp, x"730", 0, rxOpCodeData);
      axiSlaveRegisterR(axilEp, x"740", 0, remRxPause);
      axiSlaveRegisterR(axilEp, x"750", 0, rxClkFreq);

      ----------------------------------------------------------------------------------------------
      -- TX Status: Offset = 0x800 in SW
      ----------------------------------------------------------------------------------------------

      for i in 0 to NUM_VC_G-1 loop
         axiSlaveRegisterR(axilEp, x"800"+toSlv(i*4, 12), 0, muxSlVectorArray(locPauseCnt, i));  -- 0x800:0x83F
         axiSlaveRegisterR(axilEp, x"840"+toSlv(i*4, 12), 0, muxSlVectorArray(locOverflowCnt, i));  -- 0x840:0x87F
      end loop;

      for i in 0 to TX_STATUS_CNT_SIZE_C-1 loop
         axiSlaveRegisterR(axilEp, x"900"+toSlv(i*4, 12), 0, muxSlVectorArray(txStatusCnt, i));
      end loop;

      for i in 0 to TX_ERROR_CNT_SIZE_C-1 loop
         axiSlaveRegisterR(axilEp, x"A00"+toSlv(i*4, 12), 0, muxSlVectorArray(txErrorCnt, i));
      end loop;

      axiSlaveRegisterR(axilEp, x"B10", 0, txError);
      axiSlaveRegisterR(axilEp, x"B20", 0, locData);
      axiSlaveRegisterR(axilEp, x"B30", 0, txOpCodeData);
      axiSlaveRegisterR(axilEp, x"B40", 0, locPause);
      axiSlaveRegisterR(axilEp, x"B50", 0, txClkFreq);

      ----------------------------------------------------------------------------------------------

      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      -- Outputs
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;
      txDiffCtrl     <= r.txDiffCtrl;
      txPreCursor    <= r.txPreCursor;
      txPostCursor   <= r.txPostCursor;

      -- Reset
      if (RST_ASYNC_G = false and axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Next register assignment
      rin <= v;

   end process;

   seqAxil : process (axilClk, axilRst) is
   begin
      if (RST_ASYNC_G) and (axilRst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(axilClk) then
         r <= rin after TPD_G;
      end if;
   end process seqAxil;

   ----------------------------------------------------------------------------------------------
   -- RX SYNC
   ----------------------------------------------------------------------------------------------
   U_RxClkFreq : entity surf.SyncClockFreq
      generic map (
         TPD_G          => TPD_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         REF_CLK_FREQ_G => AXIL_CLK_FREQ_G,
         COMMON_CLK_G   => true,        -- locClk = refClk
         CNT_WIDTH_G    => 32)
      port map (
         freqOut => rxClkFreq,
         clkIn   => pgpRxClk,
         locClk  => axilClk,
         refClk  => axilClk);

   U_RxSyncVec : entity surf.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         RST_ASYNC_G   => RST_ASYNC_G,
         BYPASS_SYNC_G => COMMON_RX_CLK_G,
         WIDTH_G       => 1)
      port map (
         clk        => pgpRxClk,
         dataIn(0)  => r.resetRx,
         dataOut(0) => resetRx);

   U_remLinkData : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         RST_ASYNC_G  => RST_ASYNC_G,
         COMMON_CLK_G => COMMON_RX_CLK_G,
         DATA_WIDTH_G => 48)
      port map (
         wr_clk => pgpRxClk,
         din    => pgpRxOut.remLinkData,
         rd_clk => axilClk,
         dout   => remLinkData);

   U_RxOpCode : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         RST_ASYNC_G  => RST_ASYNC_G,
         COMMON_CLK_G => COMMON_RX_CLK_G,
         DATA_WIDTH_G => 48)
      port map (
         rst    => r.countReset,
         wr_clk => pgpRxClk,
         wr_en  => pgpRxOut.opCodeEn,
         din    => pgpRxOut.opCodeData,
         rd_clk => axilClk,
         dout   => rxOpCodeData);

   U_remRxPause : entity surf.SyncStatusVector
      generic map (
         TPD_G        => TPD_G,
         RST_ASYNC_G  => RST_ASYNC_G,
         COMMON_CLK_G => COMMON_RX_CLK_G,
         CNT_WIDTH_G  => STATUS_CNT_WIDTH_G,
         WIDTH_G      => NUM_VC_G)
      port map (
         statusIn     => pgpRxOut.remRxPause(NUM_VC_G-1 downto 0),
         statusOut    => remRxPause,
         cntOut       => remRxPauseCnt,
         cntRstIn     => r.countReset,
         rollOverEnIn => (others => '1'),
         wrClk        => pgpRxClk,
         wrRst        => pgpRxRst,
         rdClk        => axilClk,
         rdRst        => axilRst);

   U_remRxOverflow : entity surf.SyncStatusVector
      generic map (
         TPD_G        => TPD_G,
         RST_ASYNC_G  => RST_ASYNC_G,
         COMMON_CLK_G => COMMON_RX_CLK_G,
         CNT_WIDTH_G  => ERROR_CNT_WIDTH_G,
         WIDTH_G      => NUM_VC_G)
      port map (
         statusIn     => pgpRxOut.remRxOverflow(NUM_VC_G-1 downto 0),
         statusOut    => remRxOverflow,
         cntOut       => remRxOverflowCnt,
         cntRstIn     => r.countReset,
         rollOverEnIn => (others => '0'),
         wrClk        => pgpRxClk,
         wrRst        => pgpRxRst,
         rdClk        => axilClk,
         rdRst        => axilRst);

   U_rxStatusCnt : entity surf.SyncStatusVector
      generic map (
         TPD_G        => TPD_G,
         RST_ASYNC_G  => RST_ASYNC_G,
         COMMON_CLK_G => COMMON_RX_CLK_G,
         CNT_WIDTH_G  => STATUS_CNT_WIDTH_G,
         WIDTH_G      => RX_STATUS_CNT_SIZE_C)
      port map (
         statusIn(0)  => pgpRxOut.frameRx,
         statusIn(1)  => pgpRxOut.opCodeEn,
         statusOut    => rxStatus,
         cntOut       => rxStatusCnt,
         cntRstIn     => r.countReset,
         rollOverEnIn => (others => '1'),
         wrClk        => pgpRxClk,
         wrRst        => pgpRxRst,
         rdClk        => axilClk,
         rdRst        => axilRst);

   U_rxErrorCnt : entity surf.SyncStatusVector
      generic map (
         TPD_G        => TPD_G,
         RST_ASYNC_G  => RST_ASYNC_G,
         COMMON_CLK_G => COMMON_RX_CLK_G,
         CNT_WIDTH_G  => ERROR_CNT_WIDTH_G,
         WIDTH_G      => RX_ERROR_CNT_SIZE_C)
      port map (
         statusIn(0)  => pgpRxOut.phyRxActive,
         statusIn(1)  => pgpRxOut.phyRxInit,
         statusIn(2)  => pgpRxOut.gearboxAligned,
         statusIn(3)  => pgpRxOut.linkReady,
         statusIn(4)  => pgpRxOut.remRxLinkReady,
         statusIn(5)  => pgpRxOut.frameRxErr,
         statusIn(6)  => pgpRxOut.linkDown,
         statusIn(7)  => pgpRxOut.linkError,
         statusIn(8)  => pgpRxOut.ebOverflow,
         statusIn(9)  => pgpRxOut.cellError,
         statusIn(10)  => pgpRxOut.cellSofError,
         statusIn(11)  => pgpRxOut.cellSeqError,
         statusIn(12)  => pgpRxOut.cellVersionError,
         statusIn(13)  => pgpRxOut.cellCrcModeError,
         statusIn(14)  => pgpRxOut.cellCrcError,
         statusIn(15)  => pgpRxOut.cellEofeError,
         statusOut    => rxError,
         cntOut       => rxErrorCnt,
         cntRstIn     => r.countReset,
         rollOverEnIn => (others => '0'),
         wrClk        => pgpRxClk,
         wrRst        => pgpRxRst,
         rdClk        => axilClk,
         rdRst        => axilRst);

   ----------------------------------------------------------------------------------------------
   -- TX SYNC
   ----------------------------------------------------------------------------------------------
   U_TxClkFreq : entity surf.SyncClockFreq
      generic map (
         TPD_G          => TPD_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         REF_CLK_FREQ_G => AXIL_CLK_FREQ_G,
         COMMON_CLK_G   => true,        -- locClk = refClk
         CNT_WIDTH_G    => 32)
      port map (
         freqOut => txClkFreq,
         clkIn   => pgpTxClk,
         locClk  => axilClk,
         refClk  => axilClk);

   U_SKP_SYNC : entity surf.SynchronizerVector  -- Using Synchronizer (instead of Fifo) to save on LUTs and because rarely changed and Pgp4TxProtocol.vhd includes a register changed detection logic
      generic map (
         TPD_G         => TPD_G,
         RST_ASYNC_G   => RST_ASYNC_G,
         BYPASS_SYNC_G => COMMON_TX_CLK_G,
         WIDTH_G       => 32)
      port map (
         clk     => pgpTxClk,
         dataIn  => r.skpInterval,
         dataOut => pgpTxIn.skpInterval);

   U_TxSyncVec : entity surf.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         RST_ASYNC_G   => RST_ASYNC_G,
         BYPASS_SYNC_G => COMMON_TX_CLK_G,
         WIDTH_G       => 3)
      port map (
         clk        => pgpTxClk,
         dataIn(0)  => r.flowCntlDis,
         dataIn(1)  => r.txDisable,
         dataIn(2)  => r.resetTx,
         dataOut(0) => flowCntlDis,
         dataOut(1) => txDisable,
         dataOut(2) => resetTx);

   U_locData : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         RST_ASYNC_G  => RST_ASYNC_G,
         COMMON_CLK_G => COMMON_TX_CLK_G,
         DATA_WIDTH_G => 48)
      port map (
         wr_clk => pgpTxClk,
         din    => locTxIn.locData,
         rd_clk => axilClk,
         dout   => locData);

   U_TxOpCode : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         RST_ASYNC_G  => RST_ASYNC_G,
         COMMON_CLK_G => COMMON_TX_CLK_G,
         DATA_WIDTH_G => 48)
      port map (
         rst    => r.countReset,
         wr_clk => pgpTxClk,
         wr_en  => locTxIn.opCodeEn,
         din    => locTxIn.opCodeData,
         rd_clk => axilClk,
         dout   => txOpCodeData);

   U_locPause : entity surf.SyncStatusVector
      generic map (
         TPD_G        => TPD_G,
         RST_ASYNC_G  => RST_ASYNC_G,
         COMMON_CLK_G => COMMON_TX_CLK_G,
         CNT_WIDTH_G  => STATUS_CNT_WIDTH_G,
         WIDTH_G      => NUM_VC_G)
      port map (
         statusIn     => pgpTxOut.locPause(NUM_VC_G-1 downto 0),
         statusOut    => locPause,
         cntOut       => locPauseCnt,
         cntRstIn     => r.countReset,
         rollOverEnIn => (others => '1'),
         wrClk        => pgpTxClk,
         wrRst        => pgpTxRst,
         rdClk        => axilClk,
         rdRst        => axilRst);

   U_locOverflow : entity surf.SyncStatusVector
      generic map (
         TPD_G        => TPD_G,
         RST_ASYNC_G  => RST_ASYNC_G,
         COMMON_CLK_G => COMMON_TX_CLK_G,
         CNT_WIDTH_G  => ERROR_CNT_WIDTH_G,
         WIDTH_G      => NUM_VC_G)
      port map (
         statusIn     => pgpTxOut.locOverflow(NUM_VC_G-1 downto 0),
         statusOut    => locOverflow,
         cntOut       => locOverflowCnt,
         cntRstIn     => r.countReset,
         rollOverEnIn => (others => '0'),
         wrClk        => pgpTxClk,
         wrRst        => pgpTxRst,
         rdClk        => axilClk,
         rdRst        => axilRst);

   U_txStatusCnt : entity surf.SyncStatusVector
      generic map (
         TPD_G        => TPD_G,
         RST_ASYNC_G  => RST_ASYNC_G,
         COMMON_CLK_G => COMMON_TX_CLK_G,
         CNT_WIDTH_G  => STATUS_CNT_WIDTH_G,
         WIDTH_G      => TX_STATUS_CNT_SIZE_C)
      port map (
         statusIn(0)  => pgpTxOut.frameTx,
         statusIn(1)  => locTxIn.opCodeEn,
         statusOut    => txStatus,
         cntOut       => txStatusCnt,
         cntRstIn     => r.countReset,
         rollOverEnIn => (others => '1'),
         wrClk        => pgpTxClk,
         wrRst        => pgpTxRst,
         rdClk        => axilClk,
         rdRst        => axilRst);

   U_txErrorCnt : entity surf.SyncStatusVector
      generic map (
         TPD_G        => TPD_G,
         RST_ASYNC_G  => RST_ASYNC_G,
         COMMON_CLK_G => COMMON_TX_CLK_G,
         CNT_WIDTH_G  => ERROR_CNT_WIDTH_G,
         WIDTH_G      => TX_ERROR_CNT_SIZE_C)
      port map (
         statusIn(0)  => pgpTxOut.phyTxActive,
         statusIn(1)  => pgpTxOut.linkReady,
         statusIn(2)  => pgpTxOut.frameTxErr,
         statusOut    => txError,
         cntOut       => txErrorCnt,
         cntRstIn     => r.countReset,
         rollOverEnIn => (others => '0'),
         wrClk        => pgpTxClk,
         wrRst        => pgpTxRst,
         rdClk        => axilClk,
         rdRst        => axilRst);

end mapping;
