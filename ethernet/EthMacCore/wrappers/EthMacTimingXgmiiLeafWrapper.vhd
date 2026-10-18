-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for the timing-capable XGMII leaves
-------------------------------------------------------------------------------
-- The RX half drives EthMacRxImport (TIMING_EN_G) from bench-controlled XGMII
-- pins; the TX half drives EthMacTxExport (TIMING_EN_G) from a flattened AXIS
-- source. A PtpRxTimestampAdapter observes each half's pins exactly as the
-- legacy endpoint does, so the bench can compare every leaf start with the
-- adapter's capture SOF on the same edge. PHC inputs are constant; only the
-- capture edge is compared here.
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.EthMacPkg.all;
use surf.PtpPkg.all;

entity EthMacTimingXgmiiLeafWrapper is
   generic (
      TPD_G          : time   := 1 ns;
      RST_POLARITY_G : sl     := '1';
      SYNTH_MODE_G   : string := "inferred");
   port (
      ethClk         : in  sl;
      ethRst         : in  sl;
      phyReady       : in  sl;
      -- RX pins and token offer
      xgmiiRxd       : in  slv(63 downto 0);
      xgmiiRxc       : in  slv(7 downto 0);
      rxNextToken    : in  slv(7 downto 0);
      -- RX stream
      mAxisTValid    : out sl;
      mAxisTData     : out slv(127 downto 0);
      mAxisTKeep     : out slv(15 downto 0);
      mAxisTLast     : out sl;
      mAxisTId       : out slv(7 downto 0);
      mAxisSof       : out sl;
      mAxisEofe      : out sl;
      -- RX events
      rxStart        : out sl;
      rxStartToken   : out slv(7 downto 0);
      rxStartLane    : out slv(2 downto 0);
      rxDone         : out sl;
      rxDoneError    : out sl;
      rxDoneLength   : out slv(15 downto 0);
      rxDoneToken    : out slv(7 downto 0);
      rxLost         : out sl;
      rxRetireValid  : out sl;
      rxRetireToken  : out slv(7 downto 0);
      rxCountEn      : out sl;
      rxCrcError     : out sl;
      rxOracleSof    : out sl;
      -- TX stream
      sAxisTValid    : in  sl;
      sAxisTData     : in  slv(127 downto 0);
      sAxisTKeep     : in  slv(15 downto 0);
      sAxisTLast     : in  sl;
      sAxisTId       : in  slv(7 downto 0);
      sAxisTReady    : out sl;
      sAxisSof       : in  sl;
      sAxisEofe      : in  sl;
      -- TX pins
      xgmiiTxd       : out slv(63 downto 0);
      xgmiiTxc       : out slv(7 downto 0);
      -- TX events
      txStart        : out sl;
      txStartToken   : out slv(7 downto 0);
      txDone         : out sl;
      txDoneError    : out sl;
      txDoneLength   : out slv(15 downto 0);
      txDoneToken    : out slv(7 downto 0);
      txRetireValid  : out sl;
      txRetireToken  : out slv(7 downto 0);
      txCountEn      : out sl;
      txUnderRun     : out sl;
      txLinkNotReady : out sl;
      txOracleSof    : out sl;
      -- Forced abort of the export leaf
      abortReq       : in  sl := '0';
      abortAck       : out sl);
end entity EthMacTimingXgmiiLeafWrapper;

architecture rtl of EthMacTimingXgmiiLeafWrapper is

   constant CONFIG_C : AxiStreamConfigType := EMAC_TIMING_AXIS_CONFIG_C;

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;

   signal rxEvent : EthMacFrameEventType  := ETH_MAC_FRAME_EVENT_INIT_C;
   signal rxRet   : EthMacTokenRetireType := ETH_MAC_TOKEN_RETIRE_INIT_C;
   signal txEvent : EthMacFrameEventType  := ETH_MAC_FRAME_EVENT_INIT_C;
   signal txRet   : EthMacTokenRetireType := ETH_MAC_TOKEN_RETIRE_INIT_C;

   signal txd : slv(63 downto 0) := x"0707070707070707";
   signal txc : slv(7 downto 0)  := x"FF";

   signal rxOracleMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal txOracleMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;

begin

   sAxisComb : process (sAxisEofe, sAxisSof, sAxisTData, sAxisTId, sAxisTKeep,
                        sAxisTLast, sAxisTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := sAxisTValid;
      v.tData(127 downto 0) := sAxisTData;
      v.tKeep(15 downto 0)  := sAxisTKeep;
      v.tLast               := sAxisTLast;
      v.tId                 := sAxisTId;
      axiStreamSetUserBit(CONFIG_C, v, EMAC_SOF_BIT_C, sAxisSof, 0);
      axiStreamSetUserBit(CONFIG_C, v, EMAC_EOFE_BIT_C, sAxisEofe);
      sAxisMaster           <= v;
   end process sAxisComb;

   sAxisTReady <= sAxisSlave.tReady;

   mAxisView : process (mAxisMaster) is
   begin
      mAxisTValid <= mAxisMaster.tValid;
      mAxisTData  <= mAxisMaster.tData(127 downto 0);
      mAxisTKeep  <= mAxisMaster.tKeep(15 downto 0);
      mAxisTLast  <= mAxisMaster.tLast;
      mAxisTId    <= mAxisMaster.tId;
      mAxisSof    <= axiStreamGetUserBit(CONFIG_C, mAxisMaster, EMAC_SOF_BIT_C, 0);
      mAxisEofe   <= axiStreamGetUserBit(CONFIG_C, mAxisMaster, EMAC_EOFE_BIT_C);
   end process mAxisView;

   rxStart       <= rxEvent.start;
   rxStartToken  <= rxEvent.startToken;
   rxStartLane   <= rxEvent.startLane;
   rxDone        <= rxEvent.done;
   rxDoneError   <= rxEvent.doneError;
   rxDoneLength  <= rxEvent.doneLength;
   rxDoneToken   <= rxEvent.doneToken;
   rxLost        <= rxEvent.lost;
   rxRetireValid <= rxRet.valid;
   rxRetireToken <= rxRet.token;

   txStart       <= txEvent.start;
   txStartToken  <= txEvent.startToken;
   txDone        <= txEvent.done;
   txDoneError   <= txEvent.doneError;
   txDoneLength  <= txEvent.doneLength;
   txDoneToken   <= txEvent.doneToken;
   txRetireValid <= txRet.valid;
   txRetireToken <= txRet.token;

   xgmiiTxd <= txd;
   xgmiiTxc <= txc;

   rxOracleSof <= rxOracleMaster.tValid and ssiGetUserSof(PTP_RX_AXIS_CONFIG_C, rxOracleMaster);
   txOracleSof <= txOracleMaster.tValid and ssiGetUserSof(PTP_RX_AXIS_CONFIG_C, txOracleMaster);

   U_Import : entity surf.EthMacRxImport
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         PHY_TYPE_G     => "XGMII",
         INT_CONFIG_G   => CONFIG_C,
         TIMING_EN_G    => true,
         SYNTH_MODE_G   => SYNTH_MODE_G)
      port map (
         ethClkEn    => '1',
         ethClk      => ethClk,
         ethRst      => ethRst,
         macIbMaster => mAxisMaster,
         xlgmiiRxd   => (others => '0'),
         xlgmiiRxc   => (others => '0'),
         xgmiiRxd    => xgmiiRxd,
         xgmiiRxc    => xgmiiRxc,
         gmiiRxDv    => '0',
         gmiiRxEr    => '0',
         gmiiRxd     => (others => '0'),
         phyReady    => phyReady,
         rxCountEn   => rxCountEn,
         rxCrcError  => rxCrcError,
         nextToken   => rxNextToken,
         frameEvent  => rxEvent,
         retire      => rxRet);

   U_RxOracle : entity surf.PtpRxTimestampAdapter
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         TX_OBSERVE_G   => false,
         PHY_TYPE_G     => "XGMII")
      port map (
         clk          => ethClk,
         rst          => ethRst,
         rxFlush      => '0',
         phyReady     => phyReady,
         phcTime      => PTP_TIME_INIT_C,
         phcStatus    => PTP_PHC_STATUS_INIT_C,
         captureAbort => '0',
         xgmiiRxd     => xgmiiRxd,
         xgmiiRxc     => xgmiiRxc,
         rxMaster     => rxOracleMaster,
         rxCapture    => open);

   U_Export : entity surf.EthMacTxExport
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         PHY_TYPE_G     => "XGMII",
         INT_CONFIG_G   => CONFIG_C,
         TIMING_EN_G    => true,
         SYNTH_MODE_G   => SYNTH_MODE_G)
      port map (
         ethClkEn       => '1',
         ethClk         => ethClk,
         ethRst         => ethRst,
         macObMaster    => sAxisMaster,
         macObSlave     => sAxisSlave,
         xlgmiiTxd      => open,
         xlgmiiTxc      => open,
         xgmiiTxd       => txd,
         xgmiiTxc       => txc,
         gmiiTxEn       => open,
         gmiiTxEr       => open,
         gmiiTxd        => open,
         phyReady       => phyReady,
         txCountEn      => txCountEn,
         txUnderRun     => txUnderRun,
         txLinkNotReady => txLinkNotReady,
         frameEvent     => txEvent,
         retire         => txRet,
         abortReq       => abortReq,
         abortAck       => abortAck);

   -- PtpTxTimestampTap observes the TX pins through this adapter
   U_TxOracle : entity surf.PtpRxTimestampAdapter
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         TX_OBSERVE_G   => true,
         PHY_TYPE_G     => "XGMII")
      port map (
         clk          => ethClk,
         rst          => ethRst,
         rxFlush      => '0',
         phyReady     => phyReady,
         phcTime      => PTP_TIME_INIT_C,
         phcStatus    => PTP_PHC_STATUS_INIT_C,
         captureAbort => '0',
         xgmiiRxd     => txd,
         xgmiiRxc     => txc,
         rxMaster     => txOracleMaster,
         rxCapture    => open);

end architecture rtl;
