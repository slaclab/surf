-------------------------------------------------------------------------------
-- Title      : HTSP: https://confluence.slac.stanford.edu/x/pQmODw
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI-Lite block to manage the HTSP Ethernet interface.
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
use surf.AxiLitePkg.all;
use surf.HtspPkg.all;

entity HtspAxiL is
   generic (
      TPD_G              : time                  := 1 ns;
      WRITE_EN_G         : boolean               := false;  -- Set to false when on remote end of a link
      NUM_VC_G           : integer range 1 to 16 := 1;
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 12;
      ERROR_CNT_WIDTH_G  : natural range 1 to 32 := 8;
      AXIL_CLK_FREQ_G    : real                  := 156.25E+6;
      LOOPBACK_G         : slv(2 downto 0)       := (others => '0');
      RX_POLARITY_G      : slv(3 downto 0)       := (others => '0');
      TX_POLARITY_G      : slv(3 downto 0)       := (others => '0');
      TX_DIFF_CTRL_G     : Slv5Array(3 downto 0) := (others => "11000");
      TX_PRE_CURSOR_G    : Slv5Array(3 downto 0) := (others => "00011");
      TX_POST_CURSOR_G   : Slv5Array(3 downto 0) := (others => "00011"));
   port (
      -- Clock and Reset
      htspClk         : in  sl;
      htspRst         : in  sl;
      -- Tx User interface (htspClk domain)
      htspTxIn        : out HtspTxInType;
      htspTxOut       : in  HtspTxOutType;
      locTxIn         : in  HtspTxInType := HTSP_TX_IN_INIT_C;
      -- RX HTSP Interface (htspClk domain)
      htspRxIn        : out HtspRxInType;
      htspRxOut       : in  HtspRxOutType;
      locRxIn         : in  HtspRxInType := HTSP_RX_IN_INIT_C;
      -- Ethernet Configuration (htspClk domain)
      remoteMacIn     : in  slv(47 downto 0);
      localMacIn      : in  slv(47 downto 0);
      localMacOut     : out slv(47 downto 0);
      broadcastMac    : out slv(47 downto 0);
      etherType       : out slv(15 downto 0);
      -- Misc Debug Interfaces
      loopback        : out slv(2 downto 0);
      rxPolarity      : out slv(3 downto 0);
      txPolarity      : out slv(3 downto 0);
      txDiffCtrl      : out Slv5Array(3 downto 0);
      txPreCursor     : out Slv5Array(3 downto 0);
      txPostCursor    : out Slv5Array(3 downto 0);
      -- AXI-Lite Register Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end HtspAxiL;

architecture rtl of HtspAxiL is

   constant RX_STATUS_CNT_SIZE_C : integer := 2;
   constant RX_ERROR_CNT_SIZE_C  : integer := 5;

   constant TX_STATUS_CNT_SIZE_C : integer := 2;
   constant TX_ERROR_CNT_SIZE_C  : integer := 3;

   type RegType is record
      countReset     : sl;
      broadcastMac   : slv(47 downto 0);
      localMac       : slv(47 downto 0);
      etherType      : slv(15 downto 0);
      loopback       : slv(2 downto 0);
      rxPolarity     : slv(3 downto 0);
      txPolarity     : slv(3 downto 0);
      txDiffCtrl     : Slv5Array(3 downto 0);
      txPreCursor    : Slv5Array(3 downto 0);
      txPostCursor   : Slv5Array(3 downto 0);
      htspTxIn       : HtspTxInType;
      htspRxIn       : HtspRxInType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      axilReadSlave  : AxiLiteReadSlaveType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      countReset     => '0',
      broadcastMac   => x"FF_FF_FF_FF_FF_FF",
      localMac       => x"01_02_03_56_44_00",
      etherType      => x"11_01",       -- EtherType = 0x0111 ("Experimental")
      loopBack       => LOOPBACK_G,
      rxPolarity     => RX_POLARITY_G,
      txPolarity     => TX_POLARITY_G,
      txDiffCtrl     => TX_DIFF_CTRL_G,
      txPreCursor    => TX_PRE_CURSOR_G,
      txPostCursor   => TX_POST_CURSOR_G,
      htspTxIn       => HTSP_TX_IN_INIT_C,
      htspRxIn       => HTSP_RX_IN_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Ethernet/Common Configuration
   signal localMac  : slv(47 downto 0);
   signal remoteMac : slv(47 downto 0);

   signal freqMeasured : slv(31 downto 0);

   -- RX
   signal frameRxMinSize : slv(15 downto 0);
   signal frameRxMaxSize : slv(15 downto 0);

   signal resetRx      : sl;
   signal remLinkData  : slv(127 downto 0);
   signal rxOpCodeData : slv(127 downto 0);

   signal remRxPause    : slv(NUM_VC_G-1 downto 0);
   signal remRxPauseCnt : SlVectorArray(NUM_VC_G-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);

   signal rxStatus    : slv(RX_STATUS_CNT_SIZE_C-1 downto 0);
   signal rxStatusCnt : SlVectorArray(RX_STATUS_CNT_SIZE_C-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);

   signal rxError    : slv(RX_ERROR_CNT_SIZE_C-1 downto 0);
   signal rxErrorCnt : SlVectorArray(RX_ERROR_CNT_SIZE_C-1 downto 0, ERROR_CNT_WIDTH_G-1 downto 0);

   -- TX
   signal frameTxMinSize : slv(15 downto 0);
   signal frameTxMaxSize : slv(15 downto 0);

   signal syncTxIn : HtspTxInType := HTSP_TX_IN_INIT_C;

   signal opCodeEvent  : sl;
   signal flowCntlDis  : sl;
   signal locData      : slv(127 downto 0);
   signal txOpCodeData : slv(127 downto 0);

   signal locPause    : slv(NUM_VC_G-1 downto 0);
   signal locPauseCnt : SlVectorArray(NUM_VC_G-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);

   signal locOverflow    : slv(NUM_VC_G-1 downto 0);
   signal locOverflowCnt : SlVectorArray(NUM_VC_G-1 downto 0, ERROR_CNT_WIDTH_G-1 downto 0);

   signal txStatus    : slv(TX_STATUS_CNT_SIZE_C-1 downto 0);
   signal txStatusCnt : SlVectorArray(TX_STATUS_CNT_SIZE_C-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);

   signal txError    : slv(TX_ERROR_CNT_SIZE_C-1 downto 0);
   signal txErrorCnt : SlVectorArray(TX_ERROR_CNT_SIZE_C-1 downto 0, ERROR_CNT_WIDTH_G-1 downto 0);

begin

   U_ClockFreq : entity surf.SyncClockFreq
      generic map (
         TPD_G          => TPD_G,
         REF_CLK_FREQ_G => AXIL_CLK_FREQ_G,
         CNT_WIDTH_G    => 32)
      port map (
         freqOut => freqMeasured,
         -- Clocks
         clkIn   => htspClk,
         locClk  => axilClk,
         refClk  => axilClk);

   ---------------
   -- Set TX input
   ---------------
   htspTxIn.disable      <= locTxIn.disable or syncTxIn.disable;
   htspTxIn.flowCntlDis  <= locTxIn.flowCntlDis or syncTxIn.flowCntlDis;
   htspTxIn.nullInterval <= syncTxIn.nullInterval;
   htspTxIn.opCodeEn     <= locTxIn.opCodeEn;
   htspTxIn.opCode       <= locTxIn.opCode;
   htspTxIn.locData      <= locTxIn.locData;

   U_nullInterval : entity surf.SynchronizerVector
      generic map(
         TPD_G   => TPD_G,
         WIDTH_G => 32)
      port map (
         clk     => htspClk,
         dataIn  => r.htspTxIn.nullInterval,  -- From AXIL regs
         dataOut => syncTxIn.nullInterval);

   U_SyncBits : entity surf.SynchronizerVector
      generic map(
         TPD_G   => TPD_G,
         WIDTH_G => 2)
      port map (
         clk        => htspClk,
         -- Inputs
         dataIn(0)  => r.htspTxIn.disable,      -- From AXIL regs
         dataIn(1)  => r.htspTxIn.flowCntlDis,  -- From AXIL regs
         -- Outputs
         dataOut(0) => syncTxIn.disable,
         dataOut(1) => syncTxIn.flowCntlDis);

   ---------------
   -- Set RX input
   ---------------
   htspRxIn.resetRx <= locRxIn.resetRx or r.htspRxIn.resetRx;

   -------------------------
   -- Ethernet Configuration
   -------------------------
   U_remoteMacIn : entity surf.SynchronizerVector
      generic map(
         TPD_G   => TPD_G,
         WIDTH_G => 48)
      port map (
         clk     => axilClk,
         dataIn  => remoteMacIn,
         dataOut => remoteMac);         -- To AXIL regs

   U_localMacIn : entity surf.SynchronizerVector
      generic map(
         TPD_G   => TPD_G,
         WIDTH_G => 48)
      port map (
         clk     => axilClk,
         dataIn  => localMacIn,
         dataOut => localMac);          -- To AXIL regs

   U_localMacOut : entity surf.SynchronizerVector
      generic map(
         TPD_G   => TPD_G,
         WIDTH_G => 48)
      port map (
         clk     => htspClk,
         dataIn  => r.localMac,         -- From AXIL regs
         dataOut => localMacOut);

   U_broadcastMac : entity surf.SynchronizerVector
      generic map(
         TPD_G   => TPD_G,
         WIDTH_G => 48)
      port map (
         clk     => htspClk,
         dataIn  => r.broadcastMac,     -- From AXIL regs
         dataOut => broadcastMac);

   U_etherType : entity surf.SynchronizerVector
      generic map(
         TPD_G   => TPD_G,
         WIDTH_G => 16)
      port map (
         clk     => htspClk,
         dataIn  => r.etherType,        -- From AXIL regs
         dataOut => etherType);

   process (axilReadMaster, axilRst, axilWriteMaster, frameRxMaxSize,
            frameRxMinSize, frameTxMaxSize, frameTxMinSize, freqMeasured,
            locData, locOverflowCnt, locPause, locPauseCnt, localMac, r,
            remLinkData, remRxPause, remRxPauseCnt, remoteMac, rxError,
            rxErrorCnt, rxOpCodeData, rxStatusCnt, txError, txErrorCnt,
            txOpCodeData, txStatusCnt) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      -- Latch the current value
      v := r;

      ---------------------------------
      -- Determine the transaction type
      ---------------------------------
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      ----------------------------------------------------------------------------------------------
      -- Control = 0x000 in SW
      ----------------------------------------------------------------------------------------------

      axiSlaveRegister (axilEp, x"000", 0, v.countReset);
      axiSlaveRegisterR(axilEp, x"004", 0, ite(WRITE_EN_G, '1', '0'));
      axiSlaveRegisterR(axilEp, x"004", 8, toSlv(NUM_VC_G, 8));
      axiSlaveRegisterR(axilEp, x"004", 16, toSlv(STATUS_CNT_WIDTH_G, 8));
      axiSlaveRegisterR(axilEp, x"004", 24, toSlv(ERROR_CNT_WIDTH_G, 8));

      axiSlaveRegisterR(axilEp, x"010", 0, freqMeasured);

      if (WRITE_EN_G) then

         axiSlaveRegister(axilEp, x"030", 0, v.loopback);
         axiSlaveRegister(axilEp, x"030", 8, v.htspTxIn.disable);
         axiSlaveRegister(axilEp, x"030", 9, v.htspTxIn.flowCntlDis);
         axiSlaveRegister(axilEp, x"030", 10, v.htspRxIn.resetRx);

         axiSlaveRegister(axilEp, x"038", 0, v.rxPolarity);
         axiSlaveRegister(axilEp, x"038", 16, v.txPolarity);
         axiSlaveRegister(axilEp, x"03C", 0, v.htspTxIn.nullInterval);

         for i in 3 downto 0 loop
            axiSlaveRegister(axilEp, toSlv(64+(4*i), 12), 0, v.txDiffCtrl(i));
            axiSlaveRegister(axilEp, toSlv(64+(4*i), 12), 8, v.txPreCursor(i));
            axiSlaveRegister(axilEp, toSlv(64+(4*i), 12), 16, v.txPostCursor(i));
         end loop;

         axiSlaveRegister (axilEp, x"0C0", 0, v.localMac);
         axiSlaveRegisterR(axilEp, x"0C8", 0, remoteMac);
         axiSlaveRegister (axilEp, x"0D0", 0, v.broadcastMac);
         axiSlaveRegister (axilEp, x"0D8", 0, v.etherType);

      else

         -- Update the register from external value
         v.localMac := localMac;

         axiSlaveRegisterR(axilEp, x"030", 0, r.loopback);
         axiSlaveRegisterR(axilEp, x"030", 8, r.htspTxIn.disable);
         axiSlaveRegisterR(axilEp, x"030", 9, r.htspTxIn.flowCntlDis);
         axiSlaveRegisterR(axilEp, x"030", 10, r.htspRxIn.resetRx);

         axiSlaveRegisterR(axilEp, x"038", 0, r.rxPolarity);
         axiSlaveRegisterR(axilEp, x"038", 16, r.txPolarity);
         axiSlaveRegisterR(axilEp, x"03C", 0, r.htspTxIn.nullInterval);

         for i in 3 downto 0 loop
            axiSlaveRegisterR(axilEp, toSlv(64+(4*i), 12), 0, r.txDiffCtrl(i));
            axiSlaveRegisterR(axilEp, toSlv(64+(4*i), 12), 8, r.txPreCursor(i));
            axiSlaveRegisterR(axilEp, toSlv(64+(4*i), 12), 16, r.txPostCursor(i));
         end loop;

         axiSlaveRegisterR(axilEp, x"0C0", 0, r.localMac);
         axiSlaveRegisterR(axilEp, x"0C8", 0, remoteMac);
         axiSlaveRegisterR(axilEp, x"0D0", 0, r.broadcastMac);
         axiSlaveRegisterR(axilEp, x"0D8", 0, r.etherType);

      end if;

      ----------------------------------------------------------------------------------------------
      -- RX Status: Offset = 0x400 in SW
      ----------------------------------------------------------------------------------------------

      for i in 0 to NUM_VC_G-1 loop
         axiSlaveRegisterR(axilEp, x"400"+toSlv(i*4, 12), 0, muxSlVectorArray(remRxPauseCnt, i));  -- 0x400:0x43F
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
      axiSlaveRegisterR(axilEp, x"750", 0, frameRxMinSize);
      axiSlaveRegisterR(axilEp, x"750", 16, frameRxMaxSize);



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
      axiSlaveRegisterR(axilEp, x"B50", 0, frameTxMinSize);
      axiSlaveRegisterR(axilEp, x"B50", 16, frameTxMaxSize);

      ----------------------------------------------------------------------------------------------

      -------------------------------------
      -- Close out the AXI-Lite transaction
      -------------------------------------
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      -- Reset
      if (axilRst = '1') then
         v          := REG_INIT_C;
         v.localMac := localMac;
      end if;

      -- Next register assignment
      rin <= v;

      -- Outputs
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;
      loopback       <= r.loopback;
      rxPolarity     <= r.rxPolarity;
      txPolarity     <= r.txPolarity;
      txDiffCtrl     <= r.txDiffCtrl;
      txPreCursor    <= r.txPreCursor;
      txPostCursor   <= r.txPostCursor;

   end process;

   process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process;

   ----------------------------------------------------------------------------------------------
   -- RX SYNC
   ----------------------------------------------------------------------------------------------

   U_remLinkData : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 128)
      port map (
         clk     => axilClk,
         dataIn  => htspRxOut.remLinkData,
         dataOut => remLinkData);

   U_RxOpCode : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 128)
      port map (
         rst    => r.countReset,
         wr_clk => htspClk,
         wr_en  => htspRxOut.opCodeEn,
         din    => htspRxOut.opCode,
         rd_clk => axilClk,
         dout   => rxOpCodeData);

   U_remRxPause : entity surf.SyncStatusVector
      generic map (
         TPD_G       => TPD_G,
         CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         WIDTH_G     => NUM_VC_G)
      port map (
         statusIn     => htspRxOut.remRxPause(NUM_VC_G-1 downto 0),
         statusOut    => remRxPause,
         cntOut       => remRxPauseCnt,
         cntRstIn     => r.countReset,
         rollOverEnIn => (others => '1'),
         wrClk        => htspClk,
         wrRst        => htspRst,
         rdClk        => axilClk,
         rdRst        => axilRst);

   U_rxStatusCnt : entity surf.SyncStatusVector
      generic map (
         TPD_G       => TPD_G,
         CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         WIDTH_G     => RX_STATUS_CNT_SIZE_C)
      port map (
         statusIn(0)  => htspRxOut.frameRx,
         statusIn(1)  => htspRxOut.opCodeEn,
         statusOut    => rxStatus,
         cntOut       => rxStatusCnt,
         cntRstIn     => r.countReset,
         rollOverEnIn => (others => '1'),
         wrClk        => htspClk,
         wrRst        => htspRst,
         rdClk        => axilClk,
         rdRst        => axilRst);

   U_rxErrorCnt : entity surf.SyncStatusVector
      generic map (
         TPD_G       => TPD_G,
         CNT_WIDTH_G => ERROR_CNT_WIDTH_G,
         WIDTH_G     => RX_ERROR_CNT_SIZE_C)
      port map (
         statusIn(0)  => htspRxOut.phyRxActive,
         statusIn(1)  => htspRxOut.linkReady,
         statusIn(2)  => htspRxOut.remRxLinkReady,
         statusIn(3)  => htspRxOut.frameRxErr,
         statusIn(4)  => htspRxOut.linkDown,
         statusOut    => rxError,
         cntOut       => rxErrorCnt,
         cntRstIn     => r.countReset,
         rollOverEnIn => (others => '0'),
         wrClk        => htspClk,
         wrRst        => htspRst,
         rdClk        => axilClk,
         rdRst        => axilRst);

   U_frameRxSize : entity surf.SyncMinMax
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 16)
      port map (
         -- Write Interface (wrClk domain)
         wrClk   => htspClk,
         wrRst   => htspRst,
         wrEn    => htspRxOut.frameRx,
         dataIn  => htspRxOut.frameRxSize,
         -- Read Interface (rdClk domain)
         rdClk   => axilClk,
         rstStat => r.countReset,
         dataMin => frameRxMinSize,
         dataMax => frameRxMaxSize);

   ----------------------------------------------------------------------------------------------
   -- TX SYNC
   ----------------------------------------------------------------------------------------------
   U_locData : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 128)
      port map (
         clk     => axilClk,
         dataIn  => locTxIn.locData,
         dataOut => locData);

   U_TxOpCode : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 128)
      port map (
         rst    => r.countReset,
         wr_clk => htspClk,
         wr_en  => opCodeEvent,
         din    => locTxIn.opCode,
         rd_clk => axilClk,
         dout   => txOpCodeData);
   opCodeEvent <= locTxIn.opCodeEn and htspTxOut.opCodeReady;

   U_locPause : entity surf.SyncStatusVector
      generic map (
         TPD_G       => TPD_G,
         CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         WIDTH_G     => NUM_VC_G)
      port map (
         statusIn     => htspTxOut.locPause(NUM_VC_G-1 downto 0),
         statusOut    => locPause,
         cntOut       => locPauseCnt,
         cntRstIn     => r.countReset,
         rollOverEnIn => (others => '1'),
         wrClk        => htspClk,
         wrRst        => htspRst,
         rdClk        => axilClk,
         rdRst        => axilRst);

   U_locOverflow : entity surf.SyncStatusVector
      generic map (
         TPD_G       => TPD_G,
         CNT_WIDTH_G => ERROR_CNT_WIDTH_G,
         WIDTH_G     => NUM_VC_G)
      port map (
         statusIn     => htspTxOut.locOverflow(NUM_VC_G-1 downto 0),
         statusOut    => locOverflow,
         cntOut       => locOverflowCnt,
         cntRstIn     => r.countReset,
         rollOverEnIn => (others => '0'),
         wrClk        => htspClk,
         wrRst        => htspRst,
         rdClk        => axilClk,
         rdRst        => axilRst);

   U_txStatusCnt : entity surf.SyncStatusVector
      generic map (
         TPD_G       => TPD_G,
         CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         WIDTH_G     => TX_STATUS_CNT_SIZE_C)
      port map (
         statusIn(0)  => htspTxOut.frameTx,
         statusIn(1)  => locTxIn.opCodeEn,
         statusOut    => txStatus,
         cntOut       => txStatusCnt,
         cntRstIn     => r.countReset,
         rollOverEnIn => (others => '1'),
         wrClk        => htspClk,
         wrRst        => htspRst,
         rdClk        => axilClk,
         rdRst        => axilRst);

   U_txErrorCnt : entity surf.SyncStatusVector
      generic map (
         TPD_G       => TPD_G,
         CNT_WIDTH_G => ERROR_CNT_WIDTH_G,
         WIDTH_G     => TX_ERROR_CNT_SIZE_C)
      port map (
         statusIn(0)  => htspTxOut.phyTxActive,
         statusIn(1)  => htspTxOut.linkReady,
         statusIn(2)  => htspTxOut.frameTxErr,
         statusOut    => txError,
         cntOut       => txErrorCnt,
         cntRstIn     => r.countReset,
         rollOverEnIn => (others => '0'),
         wrClk        => htspClk,
         wrRst        => htspRst,
         rdClk        => axilClk,
         rdRst        => axilRst);

   U_frameTxSize : entity surf.SyncMinMax
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 16)
      port map (
         -- Write Interface (wrClk domain)
         wrClk   => htspClk,
         wrRst   => htspRst,
         wrEn    => htspTxOut.frameTx,
         dataIn  => htspTxOut.frameTxSize,
         -- Read Interface (rdClk domain)
         rdClk   => axilClk,
         rstStat => r.countReset,
         dataMin => frameTxMinSize,
         dataMax => frameTxMaxSize);

end rtl;
