-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing loopback wrapper for EthMacRx
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

entity EthMacRxLoopbackWrapper is
   generic (
      TPD_G          : time             := 1 ns;
      RST_POLARITY_G : sl               := '1';
      PAUSE_EN_G     : boolean          := true;
      PHY_TYPE_G     : string           := "XGMII";
      JUMBO_G        : boolean          := false;
      FILT_EN_G      : boolean          := true;
      BYP_EN_G       : boolean          := true;
      BYP_ETH_TYPE_G : slv(15 downto 0) := x"B588";
      SYNTH_MODE_G   : string           := "inferred");
   port (
      ethClk       : in  sl;
      ethRst       : in  sl;
      ethClkEn     : in  sl := '1';
      phyReady     : in  sl;
      sAxisTValid  : in  sl;
      sAxisTData   : in  slv(127 downto 0);
      sAxisTKeep   : in  slv(15 downto 0);
      sAxisTLast   : in  sl;
      sAxisTReady  : out sl;
      sAxisSof     : in  sl;
      sAxisFrag    : in  sl;
      sAxisEofe    : in  sl;
      mPrimTValid  : out sl;
      mPrimTData   : out slv(127 downto 0);
      mPrimTKeep   : out slv(15 downto 0);
      mPrimTLast   : out sl;
      mPrimSof     : out sl;
      mPrimFrag    : out sl;
      mPrimEofe    : out sl;
      mPrimIpErr   : out sl;
      mPrimTcpErr  : out sl;
      mPrimUdpErr  : out sl;
      mBypTValid   : out sl;
      mBypTData    : out slv(127 downto 0);
      mBypTKeep    : out slv(15 downto 0);
      mBypTLast    : out sl;
      mBypSof      : out sl;
      mBypFrag     : out sl;
      mBypEofe     : out sl;
      mBypIpErr    : out sl;
      mBypTcpErr   : out sl;
      mBypUdpErr   : out sl;
      mPrimPause   : in  sl := '0';
      dropOnPause  : in  sl;
      macAddress   : in  slv(47 downto 0);
      filtEnable   : in  sl;
      ipCsumEn     : in  sl;
      tcpCsumEn    : in  sl;
      udpCsumEn    : in  sl;
      rxPauseReq   : out sl;
      rxPauseValue : out slv(15 downto 0);
      rxCountEn    : out sl;
      rxCrcError   : out sl);
end entity EthMacRxLoopbackWrapper;

architecture rtl of EthMacRxLoopbackWrapper is

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mPrimMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mBypMaster  : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mPrimCtrl   : AxiStreamCtrlType   := AXI_STREAM_CTRL_INIT_C;
   signal xgmiiTxd    : slv(63 downto 0)    := (others => '0');
   signal xgmiiTxc    : slv(7 downto 0)     := (others => '1');
   signal gmiiTxEn    : sl                  := '0';
   signal gmiiTxEr    : sl                  := '0';
   signal gmiiTxd     : slv(7 downto 0)     := (others => '0');
   signal ethConfig   : EthMacConfigType    := ETH_MAC_CONFIG_INIT_C;

begin

   -- Flatten the packet source that is exported onto the chosen PHY loopback.
   sAxisComb : process (sAxisEofe, sAxisFrag, sAxisSof, sAxisTData, sAxisTKeep,
                        sAxisTLast, sAxisTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := sAxisTValid;
      v.tData(127 downto 0) := sAxisTData;
      v.tKeep(15 downto 0)  := sAxisTKeep;
      v.tLast               := sAxisTLast;
      axiStreamSetUserBit(INT_EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sAxisSof, 0);
      axiStreamSetUserBit(INT_EMAC_AXIS_CONFIG_C, v, EMAC_FRAG_BIT_C, sAxisFrag, 0);
      axiStreamSetUserBit(INT_EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sAxisEofe);
      sAxisMaster           <= v;
   end process sAxisComb;

   sAxisTReady <= sAxisSlave.tReady;

   -- Expose the primary-path AXIS payload and user bits directly to cocotb.
   mPrimView : process (mPrimMaster) is
   begin
      mPrimTValid <= mPrimMaster.tValid;
      mPrimTData  <= mPrimMaster.tData(127 downto 0);
      mPrimTKeep  <= mPrimMaster.tKeep(15 downto 0);
      mPrimTLast  <= mPrimMaster.tLast;
      mPrimSof    <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mPrimMaster, EMAC_SOF_BIT_C, 0);
      mPrimFrag   <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mPrimMaster, EMAC_FRAG_BIT_C, 0);
      mPrimEofe   <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mPrimMaster, EMAC_EOFE_BIT_C);
      mPrimIpErr  <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mPrimMaster, EMAC_IPERR_BIT_C);
      mPrimTcpErr <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mPrimMaster, EMAC_TCPERR_BIT_C);
      mPrimUdpErr <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mPrimMaster, EMAC_UDPERR_BIT_C);
   end process mPrimView;

   -- Expose the bypass stream separately so tests can prove EtherType routing.
   mBypView : process (mBypMaster) is
   begin
      mBypTValid <= mBypMaster.tValid;
      mBypTData  <= mBypMaster.tData(127 downto 0);
      mBypTKeep  <= mBypMaster.tKeep(15 downto 0);
      mBypTLast  <= mBypMaster.tLast;
      mBypSof    <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mBypMaster, EMAC_SOF_BIT_C, 0);
      mBypFrag   <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mBypMaster, EMAC_FRAG_BIT_C, 0);
      mBypEofe   <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mBypMaster, EMAC_EOFE_BIT_C);
      mBypIpErr  <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mBypMaster, EMAC_IPERR_BIT_C);
      mBypTcpErr <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mBypMaster, EMAC_TCPERR_BIT_C);
      mBypUdpErr <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mBypMaster, EMAC_UDPERR_BIT_C);
   end process mBypView;

   -- Only the pause bit of the primary control record matters for these tests.
   mPrimCtrl.pause    <= mPrimPause;
   mPrimCtrl.overflow <= '0';
   mPrimCtrl.idle     <= '0';

   -- Flatten the small EthMac config record into simple scalar inputs.
   ethConfig.macAddress  <= macAddress;
   ethConfig.filtEnable  <= filtEnable;
   ethConfig.pauseEnable <= '0';
   ethConfig.pauseTime   <= (others => '0');
   ethConfig.pauseThresh <= (others => '0');
   ethConfig.ipCsumEn    <= ipCsumEn;
   ethConfig.tcpCsumEn   <= tcpCsumEn;
   ethConfig.udpCsumEn   <= udpCsumEn;
   ethConfig.dropOnPause <= dropOnPause;

   -- Use the real export path to generate protocol-correct PHY symbols.
   U_Tx : entity surf.EthMacTxExport
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         PHY_TYPE_G     => PHY_TYPE_G,
         SYNTH_MODE_G   => SYNTH_MODE_G)
      port map (
         ethClkEn       => ethClkEn,
         ethClk         => ethClk,
         ethRst         => ethRst,
         macObMaster    => sAxisMaster,
         macObSlave     => sAxisSlave,
         xlgmiiTxd      => open,
         xlgmiiTxc      => open,
         xgmiiTxd       => xgmiiTxd,
         xgmiiTxc       => xgmiiTxc,
         gmiiTxEn       => gmiiTxEn,
         gmiiTxEr       => gmiiTxEr,
         gmiiTxd        => gmiiTxd,
         phyReady       => phyReady,
         txCountEn      => open,
         txUnderRun     => open,
         txLinkNotReady => open);

   -- Feed the generated PHY traffic into the full RX assembly under test.
   U_DUT : entity surf.EthMacRx
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         PAUSE_EN_G     => PAUSE_EN_G,
         PHY_TYPE_G     => PHY_TYPE_G,
         JUMBO_G        => JUMBO_G,
         ROCEV2_EN_G    => false,
         FILT_EN_G      => FILT_EN_G,
         BYP_EN_G       => BYP_EN_G,
         BYP_ETH_TYPE_G => BYP_ETH_TYPE_G,
         SYNTH_MODE_G   => SYNTH_MODE_G)
      port map (
         ethClkEn     => ethClkEn,
         ethClk       => ethClk,
         ethRst       => ethRst,
         mPrimMaster  => mPrimMaster,
         mPrimCtrl    => mPrimCtrl,
         mBypMaster   => mBypMaster,
         mBypCtrl     => AXI_STREAM_CTRL_UNUSED_C,
         xlgmiiRxd    => (others => '0'),
         xlgmiiRxc    => (others => '1'),
         xgmiiRxd     => xgmiiTxd,
         xgmiiRxc     => xgmiiTxc,
         gmiiRxDv     => gmiiTxEn,
         gmiiRxEr     => gmiiTxEr,
         gmiiRxd      => gmiiTxd,
         rxPauseReq   => rxPauseReq,
         rxPauseValue => rxPauseValue,
         phyReady     => phyReady,
         ethConfig    => ethConfig,
         rxCountEn    => rxCountEn,
         rxCrcError   => rxCrcError);

end architecture rtl;
