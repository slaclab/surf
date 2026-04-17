-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for UdpEngineRx
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

entity UdpEngineRxFlatWrapper is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';
      RST_ASYNC_G    : boolean := false);
   port (
      clk                  : in  sl;
      rst                  : in  sl;
      localIp              : in  slv(31 downto 0);
      broadcastIp          : in  slv(31 downto 0);
      igmpIp               : in  slv(31 downto 0);
      serverRemotePort     : out slv(15 downto 0);
      serverRemoteIp       : out slv(31 downto 0);
      serverRemoteMac      : out slv(47 downto 0);
      clientRemoteDetValid : out sl;
      clientRemoteDetIp    : out slv(31 downto 0);
      sUdpTValid           : in  sl;
      sUdpTData            : in  slv(127 downto 0);
      sUdpTKeep            : in  slv(15 downto 0);
      sUdpTLast            : in  sl;
      sUdpTReady           : out sl;
      sUdpSof              : in  sl;
      sUdpEofe             : in  sl;
      mServerTValid        : out sl;
      mServerTData         : out slv(127 downto 0);
      mServerTKeep         : out slv(15 downto 0);
      mServerTLast         : out sl;
      mServerTReady        : in  sl := '1';
      mServerTDest         : out slv(7 downto 0);
      mServerSof           : out sl;
      mServerEofe          : out sl;
      mClientTValid        : out sl;
      mClientTData         : out slv(127 downto 0);
      mClientTKeep         : out slv(15 downto 0);
      mClientTLast         : out sl;
      mClientTReady        : in  sl := '1';
      mClientTDest         : out slv(7 downto 0);
      mClientSof           : out sl;
      mClientEofe          : out sl;
      mDhcpTValid          : out sl;
      mDhcpTData           : out slv(127 downto 0);
      mDhcpTKeep           : out slv(15 downto 0);
      mDhcpTLast           : out sl;
      mDhcpTReady          : in  sl := '1';
      mDhcpSof             : out sl;
      mDhcpEofe            : out sl);
end entity UdpEngineRxFlatWrapper;

architecture rtl of UdpEngineRxFlatWrapper is

   signal igmpIpArray       : Slv32Array(0 downto 0);
   signal sUdpMaster        : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sUdpSlave         : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal serverRemotePortA : Slv16Array(0 downto 0);
   signal serverRemoteIpA   : Slv32Array(0 downto 0);
   signal serverRemoteMacA  : Slv48Array(0 downto 0);
   signal clientRemoteDetVA : slv(0 downto 0);
   signal clientRemoteDetIA : Slv32Array(0 downto 0);
   signal mServerMasters    : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal mServerSlaves     : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal mClientMasters    : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal mClientSlaves     : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal mDhcpMaster       : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mDhcpSlave        : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

begin

   sUdpComb : process (sUdpEofe, sUdpSof, sUdpTData, sUdpTKeep, sUdpTLast, sUdpTValid) is
      variable v : AxiStreamMasterType;
   begin
      v := AXI_STREAM_MASTER_INIT_C;
      v.tValid := sUdpTValid;
      v.tData(127 downto 0) := sUdpTData;
      v.tKeep(15 downto 0) := sUdpTKeep;
      v.tLast := sUdpTLast;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sUdpSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sUdpEofe);
      sUdpMaster <= v;
   end process sUdpComb;

   mServerView : process (mServerMasters(0)) is
   begin
      mServerTValid <= mServerMasters(0).tValid;
      mServerTData <= mServerMasters(0).tData(127 downto 0);
      mServerTKeep <= mServerMasters(0).tKeep(15 downto 0);
      mServerTLast <= mServerMasters(0).tLast;
      mServerTDest <= mServerMasters(0).tDest(7 downto 0);
      mServerSof <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mServerMasters(0), EMAC_SOF_BIT_C, 0);
      mServerEofe <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mServerMasters(0), EMAC_EOFE_BIT_C);
   end process mServerView;

   mClientView : process (mClientMasters(0)) is
   begin
      mClientTValid <= mClientMasters(0).tValid;
      mClientTData <= mClientMasters(0).tData(127 downto 0);
      mClientTKeep <= mClientMasters(0).tKeep(15 downto 0);
      mClientTLast <= mClientMasters(0).tLast;
      mClientTDest <= mClientMasters(0).tDest(7 downto 0);
      mClientSof <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mClientMasters(0), EMAC_SOF_BIT_C, 0);
      mClientEofe <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mClientMasters(0), EMAC_EOFE_BIT_C);
   end process mClientView;

   mDhcpView : process (mDhcpMaster) is
   begin
      mDhcpTValid <= mDhcpMaster.tValid;
      mDhcpTData <= mDhcpMaster.tData(127 downto 0);
      mDhcpTKeep <= mDhcpMaster.tKeep(15 downto 0);
      mDhcpTLast <= mDhcpMaster.tLast;
      mDhcpSof <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mDhcpMaster, EMAC_SOF_BIT_C, 0);
      mDhcpEofe <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mDhcpMaster, EMAC_EOFE_BIT_C);
   end process mDhcpView;

   sUdpTReady <= sUdpSlave.tReady;
   mServerSlaves(0).tReady <= mServerTReady;
   mClientSlaves(0).tReady <= mClientTReady;
   mDhcpSlave.tReady <= mDhcpTReady;

   igmpIpArray(0) <= igmpIp;
   serverRemotePort <= serverRemotePortA(0);
   serverRemoteIp <= serverRemoteIpA(0);
   serverRemoteMac <= serverRemoteMacA(0);
   clientRemoteDetValid <= clientRemoteDetVA(0);
   clientRemoteDetIp <= clientRemoteDetIA(0);

   U_DUT : entity surf.UdpEngineRx
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         DHCP_G         => true,
         IGMP_G         => false,
         IGMP_GRP_SIZE  => 1,
         SERVER_EN_G    => true,
         SERVER_SIZE_G  => 1,
         SERVER_PORTS_G => (0 => 8192),
         CLIENT_EN_G    => true,
         CLIENT_SIZE_G  => 1,
         CLIENT_PORTS_G => (0 => 8193))
      port map (
         localIp              => localIp,
         broadcastIp          => broadcastIp,
         igmpIp               => igmpIpArray,
         ibUdpMaster          => sUdpMaster,
         ibUdpSlave           => sUdpSlave,
         serverRemotePort     => serverRemotePortA,
         serverRemoteIp       => serverRemoteIpA,
         serverRemoteMac      => serverRemoteMacA,
         obServerMasters      => mServerMasters,
         obServerSlaves       => mServerSlaves,
         clientRemoteDetValid => clientRemoteDetVA,
         clientRemoteDetIp    => clientRemoteDetIA,
         obClientMasters      => mClientMasters,
         obClientSlaves       => mClientSlaves,
         ibDhcpMaster         => mDhcpMaster,
         ibDhcpSlave          => mDhcpSlave,
         clk                  => clk,
         rst                  => rst);

end architecture rtl;
