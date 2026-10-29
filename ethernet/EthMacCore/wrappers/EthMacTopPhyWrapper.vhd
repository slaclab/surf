-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing EthMacTop wrapper with separate PHY transmit and
--              receive pins, primary and bypass streams, independent clocks
--              and the full config/status records, for line-model benches.
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

entity EthMacTopPhyWrapper is
   generic (
      TPD_G             : time                     := 1 ns;
      PHY_TYPE_G        : string                   := "XGMII";
      PAUSE_EN_G        : boolean                  := true;
      PAUSE_512BITS_G   : positive range 1 to 1024 := 8;
      DROP_ERR_PKT_G    : boolean                  := true;
      JUMBO_G           : boolean                  := true;
      FIFO_ADDR_WIDTH_G : positive                 := 11;
      FILT_EN_G         : boolean                  := false;
      PRIM_COMMON_CLK_G : boolean                  := false;
      BYP_EN_G          : boolean                  := false;
      BYP_ETH_TYPE_G    : natural                  := 0;
      BYP_COMMON_CLK_G  : boolean                  := false);
   port (
      ethClk        : in  sl;
      ethRst        : in  sl;
      ethClkEn      : in  sl := '1';
      primClk       : in  sl;
      primRst       : in  sl;
      bypClk        : in  sl := '0';
      bypRst        : in  sl := '0';
      phyReady      : in  sl;
      -- Primary inbound (to TX)
      sAxisTValid   : in  sl;
      sAxisTData    : in  slv(127 downto 0);
      sAxisTKeep    : in  slv(15 downto 0);
      sAxisTLast    : in  sl;
      sAxisTReady   : out sl;
      sAxisSof      : in  sl;
      sAxisEofe     : in  sl;
      -- Primary outbound (from RX)
      mAxisTValid   : out sl;
      mAxisTData    : out slv(127 downto 0);
      mAxisTKeep    : out slv(15 downto 0);
      mAxisTLast    : out sl;
      mAxisTReady   : in  sl;
      mAxisSof      : out sl;
      mAxisFrag     : out sl;
      mAxisEofe     : out sl;
      mAxisIpErr    : out sl;
      mAxisTcpErr   : out sl;
      mAxisUdpErr   : out sl;
      -- Bypass inbound
      sBypTValid    : in  sl                := '0';
      sBypTData     : in  slv(127 downto 0) := (others => '0');
      sBypTKeep     : in  slv(15 downto 0)  := (others => '0');
      sBypTLast     : in  sl                := '0';
      sBypTReady    : out sl;
      sBypSof       : in  sl                := '0';
      sBypEofe      : in  sl                := '0';
      -- Bypass outbound
      mBypTValid    : out sl;
      mBypTData     : out slv(127 downto 0);
      mBypTKeep     : out slv(15 downto 0);
      mBypTLast     : out sl;
      mBypTReady    : in  sl               := '1';
      mBypSof       : out sl;
      mBypEofe      : out sl;
      -- XGMII PHY
      xgmiiTxd      : out slv(63 downto 0);
      xgmiiTxc      : out slv(7 downto 0);
      xgmiiRxd      : in  slv(63 downto 0) := x"0707070707070707";
      xgmiiRxc      : in  slv(7 downto 0)  := x"FF";
      -- GMII PHY
      gmiiTxEn      : out sl;
      gmiiTxEr      : out sl;
      gmiiTxd       : out slv(7 downto 0);
      gmiiRxDv      : in  sl               := '0';
      gmiiRxEr      : in  sl               := '0';
      gmiiRxd       : in  slv(7 downto 0)  := (others => '0');
      -- Config
      localMac      : in  slv(47 downto 0);
      filtEnable    : in  sl;
      pauseEnable   : in  sl;
      pauseTime     : in  slv(15 downto 0);
      pauseThresh   : in  slv(15 downto 0);
      ipCsumEn      : in  sl;
      tcpCsumEn     : in  sl;
      udpCsumEn     : in  sl;
      dropOnPause   : in  sl;
      -- Status
      rxFifoDropCnt : out sl;
      rxPauseCnt    : out sl;
      txPauseCnt    : out sl;
      rxCountEn     : out sl;
      rxOverFlow    : out sl;
      rxCrcErrorCnt : out sl;
      txCountEn     : out sl;
      txUnderRunCnt : out sl;
      txNotReadyCnt : out sl);
end entity EthMacTopPhyWrapper;

architecture rtl of EthMacTopPhyWrapper is

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal sBypMaster  : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sBypSlave   : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mBypMaster  : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mBypSlave   : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal ethConfig   : EthMacConfigType    := ETH_MAC_CONFIG_INIT_C;
   signal ethStatus   : EthMacStatusType    := ETH_MAC_STATUS_INIT_C;

begin

   -- Flatten the primary and bypass AXIS sources.
   sAxisComb : process (sAxisEofe, sAxisSof, sAxisTData, sAxisTKeep,
                        sAxisTLast, sAxisTValid, sBypEofe, sBypSof, sBypTData,
                        sBypTKeep, sBypTLast, sBypTValid) is
      variable v : AxiStreamMasterType;
      variable b : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := sAxisTValid;
      v.tData(127 downto 0) := sAxisTData;
      v.tKeep(15 downto 0)  := sAxisTKeep;
      v.tLast               := sAxisTLast;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sAxisSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sAxisEofe);
      sAxisMaster           <= v;

      b                     := AXI_STREAM_MASTER_INIT_C;
      b.tValid              := sBypTValid;
      b.tData(127 downto 0) := sBypTData;
      b.tKeep(15 downto 0)  := sBypTKeep;
      b.tLast               := sBypTLast;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, b, EMAC_SOF_BIT_C, sBypSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, b, EMAC_EOFE_BIT_C, sBypEofe);
      sBypMaster            <= b;
   end process sAxisComb;

   sAxisTReady       <= sAxisSlave.tReady;
   sBypTReady        <= sBypSlave.tReady;
   mAxisSlave.tReady <= mAxisTReady;
   mBypSlave.tReady  <= mBypTReady;

   -- Re-expand the outbound primary and bypass streams.
   mAxisView : process (mAxisMaster, mBypMaster) is
   begin
      mAxisTValid <= mAxisMaster.tValid;
      mAxisTData  <= mAxisMaster.tData(127 downto 0);
      mAxisTKeep  <= mAxisMaster.tKeep(15 downto 0);
      mAxisTLast  <= mAxisMaster.tLast;
      mAxisSof    <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_SOF_BIT_C, 0);
      mAxisFrag   <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_FRAG_BIT_C, 0);
      mAxisEofe   <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_EOFE_BIT_C);
      mAxisIpErr  <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_IPERR_BIT_C);
      mAxisTcpErr <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_TCPERR_BIT_C);
      mAxisUdpErr <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_UDPERR_BIT_C);

      mBypTValid <= mBypMaster.tValid;
      mBypTData  <= mBypMaster.tData(127 downto 0);
      mBypTKeep  <= mBypMaster.tKeep(15 downto 0);
      mBypTLast  <= mBypMaster.tLast;
      mBypSof    <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mBypMaster, EMAC_SOF_BIT_C, 0);
      mBypEofe   <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mBypMaster, EMAC_EOFE_BIT_C);
   end process mAxisView;

   ethConfig.macAddress  <= localMac;
   ethConfig.filtEnable  <= filtEnable;
   ethConfig.pauseEnable <= pauseEnable;
   ethConfig.pauseTime   <= pauseTime;
   ethConfig.pauseThresh <= pauseThresh;
   ethConfig.ipCsumEn    <= ipCsumEn;
   ethConfig.tcpCsumEn   <= tcpCsumEn;
   ethConfig.udpCsumEn   <= udpCsumEn;
   ethConfig.dropOnPause <= dropOnPause;

   rxFifoDropCnt <= ethStatus.rxFifoDropCnt;
   rxPauseCnt    <= ethStatus.rxPauseCnt;
   txPauseCnt    <= ethStatus.txPauseCnt;
   rxCountEn     <= ethStatus.rxCountEn;
   rxOverFlow    <= ethStatus.rxOverFlow;
   rxCrcErrorCnt <= ethStatus.rxCrcErrorCnt;
   txCountEn     <= ethStatus.txCountEn;
   txUnderRunCnt <= ethStatus.txUnderRunCnt;
   txNotReadyCnt <= ethStatus.txNotReadyCnt;

   U_DUT : entity surf.EthMacTop
      generic map (
         TPD_G             => TPD_G,
         PAUSE_EN_G        => PAUSE_EN_G,
         PAUSE_512BITS_G   => PAUSE_512BITS_G,
         PHY_TYPE_G        => PHY_TYPE_G,
         DROP_ERR_PKT_G    => DROP_ERR_PKT_G,
         JUMBO_G           => JUMBO_G,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         FILT_EN_G         => FILT_EN_G,
         PRIM_COMMON_CLK_G => PRIM_COMMON_CLK_G,
         PRIM_CONFIG_G     => EMAC_AXIS_CONFIG_C,
         BYP_EN_G          => BYP_EN_G,
         BYP_ETH_TYPE_G    => toSlv(BYP_ETH_TYPE_G, 16),
         BYP_COMMON_CLK_G  => BYP_COMMON_CLK_G,
         BYP_CONFIG_G      => EMAC_AXIS_CONFIG_C)
      port map (
         ethClkEn        => ethClkEn,
         ethClk          => ethClk,
         ethRst          => ethRst,
         primClk         => primClk,
         primRst         => primRst,
         ibMacPrimMaster => sAxisMaster,
         ibMacPrimSlave  => sAxisSlave,
         obMacPrimMaster => mAxisMaster,
         obMacPrimSlave  => mAxisSlave,
         bypClk          => bypClk,
         bypRst          => bypRst,
         ibMacBypMaster  => sBypMaster,
         ibMacBypSlave   => sBypSlave,
         obMacBypMaster  => mBypMaster,
         obMacBypSlave   => mBypSlave,
         xgmiiRxd        => xgmiiRxd,
         xgmiiRxc        => xgmiiRxc,
         xgmiiTxd        => xgmiiTxd,
         xgmiiTxc        => xgmiiTxc,
         gmiiRxDv        => gmiiRxDv,
         gmiiRxEr        => gmiiRxEr,
         gmiiRxd         => gmiiRxd,
         gmiiTxEn        => gmiiTxEn,
         gmiiTxEr        => gmiiTxEr,
         gmiiTxd         => gmiiTxd,
         phyReady        => phyReady,
         ethConfig       => ethConfig,
         ethStatus       => ethStatus);

end architecture rtl;
