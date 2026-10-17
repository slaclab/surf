-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing loopback wrapper for EthMacTop that exposes the
-- TID sideband on both primary streams and the timing-port leaf events.
--
-- With TIMING_EN_G = false the MAC uses its default configuration (zero TID
-- bits) in an XGMII or GMII loopback. With TIMING_EN_G = true it uses
-- EMAC_TIMING_AXIS_CONFIG_C and the timing GMII leaves: the TX token is
-- visible in txFrameEvent after the TX FIFO, checksum cache and exporter, and
-- the RX token offered on rxNextToken is stamped by the importer and must
-- survive the RX FIFO to the primary output. Everything else matches
-- EthMacTopLoopbackWrapper.
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

entity EthMacTopTidLoopbackWrapper is
   generic (
      TPD_G             : time     := 1 ns;
      RST_POLARITY_G    : sl       := '1';
      PHY_TYPE_G        : string   := "XGMII";
      TIMING_EN_G       : boolean  := false;
      FIFO_ADDR_WIDTH_G : positive := 11);
   port (
      ethClk        : in  sl;
      ethRst        : in  sl;
      phyReady      : in  sl;
      sAxisTValid   : in  sl;
      sAxisTData    : in  slv(127 downto 0);
      sAxisTKeep    : in  slv(15 downto 0);
      sAxisTLast    : in  sl;
      sAxisTId      : in  slv(7 downto 0);
      sAxisTReady   : out sl;
      sAxisSof      : in  sl;
      sAxisEofe     : in  sl;
      mAxisTValid   : out sl;
      mAxisTData    : out slv(127 downto 0);
      mAxisTKeep    : out slv(15 downto 0);
      mAxisTLast    : out sl;
      mAxisTId      : out slv(7 downto 0);
      mAxisTReady   : in  sl := '1';
      mAxisSof      : out sl;
      mAxisEofe     : out sl;
      localMac      : in  slv(47 downto 0);
      rxCrcErrorCnt : out sl;
      rxFifoDropCnt : out sl;
      -- Timing port (TIMING_EN_G only)
      rxNextToken   : in  slv(7 downto 0) := (others => '0');
      rxStart       : out sl;
      rxStartToken  : out slv(7 downto 0);
      txStart       : out sl;
      txStartToken  : out slv(7 downto 0);
      txDone        : out sl;
      txDoneError   : out sl;
      txDoneToken   : out slv(7 downto 0));
end entity EthMacTopTidLoopbackWrapper;

architecture rtl of EthMacTopTidLoopbackWrapper is

   constant PRIM_CONFIG_C : AxiStreamConfigType := ite(TIMING_EN_G, EMAC_TIMING_AXIS_CONFIG_C, EMAC_AXIS_CONFIG_C);
   constant INT_CONFIG_C  : AxiStreamConfigType := ite(TIMING_EN_G, EMAC_TIMING_AXIS_CONFIG_C, INT_EMAC_AXIS_CONFIG_C);

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal ethConfig   : EthMacConfigType    := ETH_MAC_CONFIG_INIT_C;
   signal ethStatus   : EthMacStatusType    := ETH_MAC_STATUS_INIT_C;
   signal xgmiiTxd    : slv(63 downto 0)    := (others => '0');
   signal xgmiiTxc    : slv(7 downto 0)     := (others => '1');
   signal gmiiTxEn    : sl                  := '0';
   signal gmiiTxEr    : sl                  := '0';
   signal gmiiTxd     : slv(7 downto 0)     := (others => '0');

   signal rxFrameEvent : EthMacFrameEventType := ETH_MAC_FRAME_EVENT_INIT_C;
   signal txFrameEvent : EthMacFrameEventType := ETH_MAC_FRAME_EVENT_INIT_C;

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
      axiStreamSetUserBit(PRIM_CONFIG_C, v, EMAC_SOF_BIT_C, sAxisSof, 0);
      axiStreamSetUserBit(PRIM_CONFIG_C, v, EMAC_EOFE_BIT_C, sAxisEofe);
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
      mAxisSof    <= axiStreamGetUserBit(PRIM_CONFIG_C, mAxisMaster, EMAC_SOF_BIT_C, 0);
      mAxisEofe   <= axiStreamGetUserBit(PRIM_CONFIG_C, mAxisMaster, EMAC_EOFE_BIT_C);
   end process mAxisView;

   ethConfig.macAddress  <= localMac;
   ethConfig.filtEnable  <= '0';
   ethConfig.pauseEnable <= '1';
   ethConfig.pauseTime   <= x"0020";
   ethConfig.pauseThresh <= x"0008";
   ethConfig.ipCsumEn    <= '0';
   ethConfig.tcpCsumEn   <= '0';
   ethConfig.udpCsumEn   <= '0';
   ethConfig.dropOnPause <= '0';

   rxCrcErrorCnt <= ethStatus.rxCrcErrorCnt;
   rxFifoDropCnt <= ethStatus.rxFifoDropCnt;

   rxStart      <= rxFrameEvent.start;
   rxStartToken <= rxFrameEvent.startToken;
   txStart      <= txFrameEvent.start;
   txStartToken <= txFrameEvent.startToken;
   txDone       <= txFrameEvent.done;
   txDoneError  <= txFrameEvent.doneError;
   txDoneToken  <= txFrameEvent.doneToken;

   U_DUT : entity surf.EthMacTop
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         PAUSE_EN_G        => true,
         PAUSE_512BITS_G   => 8,
         PHY_TYPE_G        => PHY_TYPE_G,
         DROP_ERR_PKT_G    => true,
         JUMBO_G           => false,
         INT_PIPE_STAGES_G => 1,
         PIPE_STAGES_G     => 1,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         SYNTH_MODE_G      => "inferred",
         MEMORY_TYPE_G     => "block",
         ROCEV2_EN_G       => false,
         FILT_EN_G         => false,
         PRIM_COMMON_CLK_G => true,
         PRIM_CONFIG_G     => PRIM_CONFIG_C,
         INT_CONFIG_G      => INT_CONFIG_C,
         TIMING_EN_G       => TIMING_EN_G,
         BYP_EN_G          => false,
         BYP_COMMON_CLK_G  => false,
         BYP_CONFIG_G      => PRIM_CONFIG_C)
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
         xlgmiiRxd       => (others => '0'),
         xlgmiiRxc       => (others => '1'),
         xgmiiRxd        => xgmiiTxd,
         xgmiiRxc        => xgmiiTxc,
         xgmiiTxd        => xgmiiTxd,
         xgmiiTxc        => xgmiiTxc,
         gmiiRxDv        => gmiiTxEn,
         gmiiRxEr        => gmiiTxEr,
         gmiiRxd         => gmiiTxd,
         gmiiTxEn        => gmiiTxEn,
         gmiiTxEr        => gmiiTxEr,
         gmiiTxd         => gmiiTxd,
         phyReady        => phyReady,
         ethConfig       => ethConfig,
         ethStatus       => ethStatus,
         rxNextToken     => rxNextToken,
         rxFrameEvent    => rxFrameEvent,
         rxRetire        => open,
         txFrameEvent    => txFrameEvent,
         txRetire        => open);

end architecture rtl;
