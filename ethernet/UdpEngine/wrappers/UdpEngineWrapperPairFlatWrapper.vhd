-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Legacy-parity cocotb wrapper for a client/server UdpEngine set
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
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.EthMacPkg.all;

entity UdpEngineWrapperPairFlatWrapper is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      CLK_FREQ_G     : real     := 4.0;
      COMM_TIMEOUT_G : positive := 6);
   port (
      clk              : in  sl;
      rst              : in  sl;
      clientLocalMac   : in  slv(47 downto 0);
      clientLocalIp    : in  slv(31 downto 0);
      clientRemotePort : in  slv(15 downto 0);
      clientRemoteIp   : in  slv(31 downto 0);
      selectedServer   : in  slv(1 downto 0);
      sClientTValid    : in  sl;
      sClientTData     : in  slv(127 downto 0);
      sClientTKeep     : in  slv(15 downto 0);
      sClientTLast     : in  sl;
      sClientTReady    : out sl;
      sClientTDest     : in  slv(7 downto 0);
      sClientSof       : in  sl;
      sClientEofe      : in  sl;
      mServer0TValid   : out sl;
      mServer0TData    : out slv(127 downto 0);
      mServer0TKeep    : out slv(15 downto 0);
      mServer0TLast    : out sl;
      mServer0TReady   : in  sl := '1';
      mServer0TDest    : out slv(7 downto 0);
      mServer0Sof      : out sl;
      mServer0Eofe     : out sl;
      mServer1TValid   : out sl;
      mServer1TData    : out slv(127 downto 0);
      mServer1TKeep    : out slv(15 downto 0);
      mServer1TLast    : out sl;
      mServer1TReady   : in  sl := '1';
      mServer1TDest    : out slv(7 downto 0);
      mServer1Sof      : out sl;
      mServer1Eofe     : out sl;
      mServer2TValid   : out sl;
      mServer2TData    : out slv(127 downto 0);
      mServer2TKeep    : out slv(15 downto 0);
      mServer2TLast    : out sl;
      mServer2TReady   : in  sl := '1';
      mServer2TDest    : out slv(7 downto 0);
      mServer2Sof      : out sl;
      mServer2Eofe     : out sl);
end entity UdpEngineWrapperPairFlatWrapper;

architecture rtl of UdpEngineWrapperPairFlatWrapper is

   constant SERVER_MACS_C : Slv48Array(2 downto 0) := (
      0 => x"020300564400",
      1 => x"030300564400",
      2 => x"040300564400");
   constant SERVER_IPS_C : Slv32Array(2 downto 0) := (
      0 => x"0B02A8C0",
      1 => x"0C02A8C0",
      2 => x"0D02A8C0");
   constant PHY_D_IDLE_C    : slv(63 downto 0) := x"0707070707070707";
   constant PHY_C_IDLE_C    : slv(7 downto 0)  := x"FF";

   signal obMacMasters : AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal obMacSlaves  : AxiStreamSlaveArray(3 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal ibMacMasters : AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal ibMacSlaves  : AxiStreamSlaveArray(3 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal sClientMasters  : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal sClientSlaves   : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal mServerMasters  : AxiStreamMasterArray(2 downto 0);
   signal mServerSlaves   : AxiStreamSlaveArray(2 downto 0) := (others => AXI_STREAM_SLAVE_INIT_C);
   signal ethConfig       : EthMacConfigArray(3 downto 0)  := (others => ETH_MAC_CONFIG_INIT_C);
   signal phyD            : Slv64Array(3 downto 0)         := (others => (others => '0'));
   signal phyC            : Slv8Array(3 downto 0)          := (others => (others => '0'));
   signal phyDSelected    : slv(63 downto 0)               := PHY_D_IDLE_C;
   signal phyCSelected    : slv(7 downto 0)                := PHY_C_IDLE_C;
   signal phyReady        : sl;

begin

   sClientComb : process (sClientEofe, sClientSof, sClientTData, sClientTDest, sClientTKeep, sClientTLast, sClientTValid) is
      variable v : AxiStreamMasterType;
   begin
      v := AXI_STREAM_MASTER_INIT_C;
      v.tValid := sClientTValid;
      v.tData(127 downto 0) := sClientTData;
      v.tKeep(15 downto 0) := sClientTKeep;
      v.tLast := sClientTLast;
      v.tDest(7 downto 0) := sClientTDest;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sClientSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sClientEofe);
      sClientMasters(0) <= v;
   end process sClientComb;

   mServer0View : process (mServerMasters(0)) is
   begin
      mServer0TValid <= mServerMasters(0).tValid;
      mServer0TData <= mServerMasters(0).tData(127 downto 0);
      mServer0TKeep <= mServerMasters(0).tKeep(15 downto 0);
      mServer0TLast <= mServerMasters(0).tLast;
      mServer0TDest <= mServerMasters(0).tDest(7 downto 0);
      mServer0Sof <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mServerMasters(0), EMAC_SOF_BIT_C, 0);
      mServer0Eofe <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mServerMasters(0), EMAC_EOFE_BIT_C);
   end process mServer0View;

   mServer1View : process (mServerMasters(1)) is
   begin
      mServer1TValid <= mServerMasters(1).tValid;
      mServer1TData <= mServerMasters(1).tData(127 downto 0);
      mServer1TKeep <= mServerMasters(1).tKeep(15 downto 0);
      mServer1TLast <= mServerMasters(1).tLast;
      mServer1TDest <= mServerMasters(1).tDest(7 downto 0);
      mServer1Sof <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mServerMasters(1), EMAC_SOF_BIT_C, 0);
      mServer1Eofe <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mServerMasters(1), EMAC_EOFE_BIT_C);
   end process mServer1View;

   mServer2View : process (mServerMasters(2)) is
   begin
      mServer2TValid <= mServerMasters(2).tValid;
      mServer2TData <= mServerMasters(2).tData(127 downto 0);
      mServer2TKeep <= mServerMasters(2).tKeep(15 downto 0);
      mServer2TLast <= mServerMasters(2).tLast;
      mServer2TDest <= mServerMasters(2).tDest(7 downto 0);
      mServer2Sof <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mServerMasters(2), EMAC_SOF_BIT_C, 0);
      mServer2Eofe <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mServerMasters(2), EMAC_EOFE_BIT_C);
   end process mServer2View;

   sClientTReady <= sClientSlaves(0).tReady;
   mServerSlaves(0).tReady <= mServer0TReady;
   mServerSlaves(1).tReady <= mServer1TReady;
   mServerSlaves(2).tReady <= mServer2TReady;
   phyReady <= not rst;

   ---------------------------------------------------------------------------
   -- Match the legacy XGMII PHY multiplexer from UdpEngineTb.
   ---------------------------------------------------------------------------
   process (phyC, phyD, selectedServer) is
      variable index : natural range 0 to 3;
   begin
      phyDSelected <= PHY_D_IDLE_C;
      phyCSelected <= PHY_C_IDLE_C;
      index := to_integer(unsigned(selectedServer));
      if (index >= 1) and (index <= 3) then
         phyDSelected <= phyD(index);
         phyCSelected <= phyC(index);
      end if;
   end process;
   ethConfig(0).macAddress <= clientLocalMac;
   ethConfig(1).macAddress <= SERVER_MACS_C(0);
   ethConfig(2).macAddress <= SERVER_MACS_C(1);
   ethConfig(3).macAddress <= SERVER_MACS_C(2);

   U_Client : entity surf.UdpEngineWrapper
      generic map (
         TPD_G               => TPD_G,
         RST_POLARITY_G      => RST_POLARITY_G,
         RST_ASYNC_G         => RST_ASYNC_G,
         SERVER_EN_G         => false,
         CLIENT_EN_G         => true,
         CLIENT_SIZE_G       => 1,
         CLIENT_PORTS_G      => (0 => 8193),
         CLIENT_EXT_CONFIG_G => true,
         TX_FLOW_CTRL_G      => true,
         DHCP_G              => false,
         IGMP_G              => false,
         IGMP_GRP_SIZE       => 1,
         CLK_FREQ_G          => CLK_FREQ_G,
         COMM_TIMEOUT_G      => COMM_TIMEOUT_G)
      port map (
         localMac            => clientLocalMac,
         localIp             => clientLocalIp,
         softMac             => open,
         softIp              => open,
         clientRemotePort(0) => clientRemotePort,
         clientRemoteIp(0)   => clientRemoteIp,
         obMacMaster         => obMacMasters(0),
         obMacSlave          => obMacSlaves(0),
         ibMacMaster         => ibMacMasters(0),
         ibMacSlave          => ibMacSlaves(0),
         obServerMasters     => open,
         obServerSlaves      => (others => AXI_STREAM_SLAVE_FORCE_C),
         ibServerMasters     => (others => AXI_STREAM_MASTER_INIT_C),
         ibServerSlaves      => open,
         obClientMasters     => open,
         obClientSlaves      => (others => AXI_STREAM_SLAVE_FORCE_C),
         ibClientMasters     => sClientMasters,
         ibClientSlaves      => sClientSlaves,
         clk                 => clk,
         rst                 => rst);

   U_ClientMac : entity surf.EthMacTop
      generic map (
         TPD_G         => TPD_G,
         PHY_TYPE_G    => "XGMII",
         PRIM_CONFIG_G => EMAC_AXIS_CONFIG_C)
      port map (
         primClk         => clk,
         primRst         => rst,
         ibMacPrimMaster => ibMacMasters(0),
         ibMacPrimSlave  => ibMacSlaves(0),
         obMacPrimMaster => obMacMasters(0),
         obMacPrimSlave  => obMacSlaves(0),
         ethClk          => clk,
         ethRst          => rst,
         ethConfig       => ethConfig(0),
         phyReady        => phyReady,
         xgmiiTxd        => phyD(0),
         xgmiiTxc        => phyC(0),
         xgmiiRxd        => phyDSelected,
         xgmiiRxc        => phyCSelected);

   GEN_SERVERS : for i in 0 to 2 generate
      signal obServerMasters : AxiStreamMasterArray(0 downto 0);
      signal obServerSlaves  : AxiStreamSlaveArray(0 downto 0);
   begin
      obServerSlaves(0) <= mServerSlaves(i);
      mServerMasters(i) <= obServerMasters(0);

      U_Server : entity surf.UdpEngineWrapper
         generic map (
            TPD_G               => TPD_G,
            RST_POLARITY_G      => RST_POLARITY_G,
            RST_ASYNC_G         => RST_ASYNC_G,
            SERVER_EN_G         => true,
            SERVER_SIZE_G       => 1,
            SERVER_PORTS_G      => (0 => 8192),
            CLIENT_EN_G         => false,
            CLIENT_EXT_CONFIG_G => false,
            TX_FLOW_CTRL_G      => true,
            DHCP_G              => false,
            IGMP_G              => false,
            IGMP_GRP_SIZE       => 1,
            CLK_FREQ_G          => CLK_FREQ_G,
            COMM_TIMEOUT_G      => COMM_TIMEOUT_G)
         port map (
            localMac         => SERVER_MACS_C(i),
            localIp          => SERVER_IPS_C(i),
            softMac          => open,
            softIp           => open,
            obMacMaster      => obMacMasters(i+1),
            obMacSlave       => obMacSlaves(i+1),
            ibMacMaster      => ibMacMasters(i+1),
            ibMacSlave       => ibMacSlaves(i+1),
            obServerMasters  => obServerMasters,
            obServerSlaves   => obServerSlaves,
            ibServerMasters  => (others => AXI_STREAM_MASTER_INIT_C),
            ibServerSlaves   => open,
            obClientMasters  => open,
            obClientSlaves   => (others => AXI_STREAM_SLAVE_FORCE_C),
            ibClientMasters  => (others => AXI_STREAM_MASTER_INIT_C),
            ibClientSlaves   => open,
            clk              => clk,
            rst              => rst);

      U_ServerMac : entity surf.EthMacTop
         generic map (
            TPD_G         => TPD_G,
            PHY_TYPE_G    => "XGMII",
            PRIM_CONFIG_G => EMAC_AXIS_CONFIG_C)
         port map (
            primClk         => clk,
            primRst         => rst,
            ibMacPrimMaster => ibMacMasters(i+1),
            ibMacPrimSlave  => ibMacSlaves(i+1),
            obMacPrimMaster => obMacMasters(i+1),
            obMacPrimSlave  => obMacSlaves(i+1),
            ethClk          => clk,
            ethRst          => rst,
            ethConfig       => ethConfig(i+1),
            phyReady        => phyReady,
            xgmiiTxd        => phyD(i+1),
            xgmiiTxc        => phyC(i+1),
            xgmiiRxd        => phyD(0),
            xgmiiRxc        => phyC(0));
   end generate GEN_SERVERS;

end architecture rtl;
