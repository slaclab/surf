-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing timing-mode GMII EthMacTop wrapper
-------------------------------------------------------------------------------
-- Exposes the primary streams with tId, the RX token offer, both frame-event
-- records and every retire owner as flattened signals. RX pins come from the
-- MAC's own TX pins (rxInject = '0') or from the bench (rxInject = '1'), so
-- loopback traffic and malformed or overflowing wire traffic share one bench.
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
use surf.EthMacPkg.all;

entity EthMacTopTimingWrapper is
   generic (
      TPD_G             : time     := 1 ns;
      RST_POLARITY_G    : sl       := '1';
      FILT_EN_G         : boolean  := true;
      FIFO_ADDR_WIDTH_G : positive := 11);
   port (
      ethClk        : in  sl;
      ethRst        : in  sl;
      phyReady      : in  sl;
      -- TX stream
      sAxisTValid   : in  sl;
      sAxisTData    : in  slv(127 downto 0);
      sAxisTKeep    : in  slv(15 downto 0);
      sAxisTLast    : in  sl;
      sAxisTId      : in  slv(7 downto 0);
      sAxisTReady   : out sl;
      sAxisSof      : in  sl;
      sAxisEofe     : in  sl;
      -- RX stream
      mAxisTValid   : out sl;
      mAxisTData    : out slv(127 downto 0);
      mAxisTKeep    : out slv(15 downto 0);
      mAxisTLast    : out sl;
      mAxisTId      : out slv(7 downto 0);
      mAxisTReady   : in  sl               := '1';
      mAxisSof      : out sl;
      mAxisEofe     : out sl;
      -- Wire
      rxInject      : in  sl               := '0';
      injRxDv       : in  sl               := '0';
      injRxEr       : in  sl               := '0';
      injRxd        : in  slv(7 downto 0)  := (others => '0');
      gmiiTxEn      : out sl;
      gmiiTxd       : out slv(7 downto 0);
      -- Configuration
      localMac      : in  slv(47 downto 0);
      filtEnable    : in  sl               := '0';
      dropOnPause   : in  sl               := '0';
      pauseEnable   : in  sl               := '1';
      pauseThresh   : in  slv(15 downto 0) := x"FFFF";
      -- Status
      rxCrcErrorCnt : out sl;
      rxFifoDropCnt : out sl;
      rxPauseCnt    : out sl;
      txPauseCnt    : out sl;
      -- Timing port
      rxNextToken   : in  slv(7 downto 0)  := (others => '0');
      rxStart       : out sl;
      rxStartToken  : out slv(7 downto 0);
      rxDone        : out sl;
      rxDoneError   : out sl;
      rxDoneLength  : out slv(15 downto 0);
      rxDoneToken   : out slv(7 downto 0);
      rxLost        : out sl;
      txStart       : out sl;
      txStartToken  : out slv(7 downto 0);
      txDone        : out sl;
      txDoneError   : out sl;
      txDoneToken   : out slv(7 downto 0);
      -- Retires, one valid bit and token per EthMacPkg owner index
      rxRetireValid : out slv(EMAC_RX_RETIRE_SOURCES_C-1 downto 0);
      rxRetireToken : out slv(8*EMAC_RX_RETIRE_SOURCES_C-1 downto 0);
      txRetireValid : out slv(EMAC_TX_RETIRE_SOURCES_C-1 downto 0);
      txRetireToken : out slv(8*EMAC_TX_RETIRE_SOURCES_C-1 downto 0);
      -- Forced abort
      abortReq      : in  sl               := '0';
      abortAck      : out sl);
end entity EthMacTopTimingWrapper;

architecture rtl of EthMacTopTimingWrapper is

   constant CONFIG_C : AxiStreamConfigType := EMAC_TIMING_AXIS_CONFIG_C;

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal ethConfig   : EthMacConfigType    := ETH_MAC_CONFIG_INIT_C;
   signal ethStatus   : EthMacStatusType    := ETH_MAC_STATUS_INIT_C;

   signal txEn : sl              := '0';
   signal txEr : sl              := '0';
   signal txd  : slv(7 downto 0) := (others => '0');
   signal rxDv : sl              := '0';
   signal rxEr : sl              := '0';
   signal rxd  : slv(7 downto 0) := (others => '0');

   signal rxEvent : EthMacFrameEventType := ETH_MAC_FRAME_EVENT_INIT_C;
   signal txEvent : EthMacFrameEventType := ETH_MAC_FRAME_EVENT_INIT_C;
   signal rxRet   : EthMacTokenRetireArray(EMAC_RX_RETIRE_SOURCES_C-1 downto 0);
   signal txRet   : EthMacTokenRetireArray(EMAC_TX_RETIRE_SOURCES_C-1 downto 0);
   signal abortR  : EthMacAbortRequestType := ETH_MAC_ABORT_REQUEST_INIT_C;
   signal abortA  : EthMacAbortAckType     := ETH_MAC_ABORT_ACK_INIT_C;

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

   sAxisTReady       <= sAxisSlave.tReady;
   mAxisSlave.tReady <= mAxisTReady;

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

   retireView : process (rxRet, txRet) is
   begin
      for i in 0 to EMAC_RX_RETIRE_SOURCES_C-1 loop
         rxRetireValid(i)                <= rxRet(i).valid;
         rxRetireToken(8*i+7 downto 8*i) <= rxRet(i).token;
      end loop;
      for i in 0 to EMAC_TX_RETIRE_SOURCES_C-1 loop
         txRetireValid(i)                <= txRet(i).valid;
         txRetireToken(8*i+7 downto 8*i) <= txRet(i).token;
      end loop;
   end process retireView;

   rxDv <= injRxDv when rxInject = '1' else txEn;
   rxEr <= injRxEr when rxInject = '1' else txEr;
   rxd  <= injRxd  when rxInject = '1' else txd;

   abortR.request <= abortReq;
   abortAck       <= abortA.acknowledge;

   gmiiTxEn <= txEn;
   gmiiTxd  <= txd;

   ethConfig.macAddress  <= localMac;
   ethConfig.filtEnable  <= filtEnable;
   ethConfig.pauseEnable <= pauseEnable;
   ethConfig.pauseTime   <= x"FFFF";
   ethConfig.pauseThresh <= pauseThresh;
   ethConfig.ipCsumEn    <= '0';
   ethConfig.tcpCsumEn   <= '0';
   ethConfig.udpCsumEn   <= '0';
   ethConfig.dropOnPause <= dropOnPause;

   rxCrcErrorCnt <= ethStatus.rxCrcErrorCnt;
   rxFifoDropCnt <= ethStatus.rxFifoDropCnt;
   rxPauseCnt    <= ethStatus.rxPauseCnt;
   txPauseCnt    <= ethStatus.txPauseCnt;

   rxStart      <= rxEvent.start;
   rxStartToken <= rxEvent.startToken;
   rxDone       <= rxEvent.done;
   rxDoneError  <= rxEvent.doneError;
   rxDoneLength <= rxEvent.doneLength;
   rxDoneToken  <= rxEvent.doneToken;
   rxLost       <= rxEvent.lost;
   txStart      <= txEvent.start;
   txStartToken <= txEvent.startToken;
   txDone       <= txEvent.done;
   txDoneError  <= txEvent.doneError;
   txDoneToken  <= txEvent.doneToken;

   U_DUT : entity surf.EthMacTop
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         PAUSE_EN_G        => true,
         PAUSE_512BITS_G   => 64,
         PHY_TYPE_G        => "GMII",
         DROP_ERR_PKT_G    => true,
         JUMBO_G           => false,
         INT_PIPE_STAGES_G => 1,
         PIPE_STAGES_G     => 1,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         SYNTH_MODE_G      => "inferred",
         MEMORY_TYPE_G     => "block",
         ROCEV2_EN_G       => false,
         FILT_EN_G         => FILT_EN_G,
         PRIM_COMMON_CLK_G => true,
         PRIM_CONFIG_G     => CONFIG_C,
         INT_CONFIG_G      => CONFIG_C,
         TIMING_EN_G       => true,
         BYP_EN_G          => false,
         BYP_COMMON_CLK_G  => false,
         BYP_CONFIG_G      => CONFIG_C)
      port map (
         ethClkEn        => '1',
         ethClk          => ethClk,
         ethRst          => ethRst,
         primClk         => ethClk,
         primRst         => ethRst,
         ibMacPrimMaster => sAxisMaster,
         ibMacPrimSlave  => sAxisSlave,
         obMacPrimMaster => mAxisMaster,
         obMacPrimSlave  => mAxisSlave,
         bypClk          => '0',
         bypRst          => '0',
         ibMacBypMaster  => AXI_STREAM_MASTER_INIT_C,
         ibMacBypSlave   => open,
         obMacBypMaster  => open,
         obMacBypSlave   => AXI_STREAM_SLAVE_FORCE_C,
         gmiiRxDv        => rxDv,
         gmiiRxEr        => rxEr,
         gmiiRxd         => rxd,
         gmiiTxEn        => txEn,
         gmiiTxEr        => txEr,
         gmiiTxd         => txd,
         phyReady        => phyReady,
         ethConfig       => ethConfig,
         ethStatus       => ethStatus,
         rxNextToken     => rxNextToken,
         rxFrameEvent    => rxEvent,
         rxRetire        => rxRet,
         txFrameEvent    => txEvent,
         txRetire        => txRet,
         abortReq        => abortR,
         abortAck        => abortA);

end architecture rtl;
