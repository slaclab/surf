-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for UdpEngine
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

entity UdpEngineTopFlatWrapper is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      CLK_FREQ_G     : real     := 4.0;
      COMM_TIMEOUT_G : positive := 6);
   port (
      clk              : in  sl;
      rst              : in  sl;
      localMac         : in  slv(47 downto 0);
      localIp          : in  slv(31 downto 0);
      broadcastIp      : in  slv(31 downto 0);
      clientRemotePort : in  slv(15 downto 0);
      clientRemoteIp   : in  slv(31 downto 0);
      dhcpIpOut        : out slv(31 downto 0);
      sUdpTValid       : in  sl;
      sUdpTData        : in  slv(127 downto 0);
      sUdpTKeep        : in  slv(15 downto 0);
      sUdpTLast        : in  sl;
      sUdpTReady       : out sl;
      sUdpSof          : in  sl;
      sUdpEofe         : in  sl;
      mUdpTValid       : out sl;
      mUdpTData        : out slv(127 downto 0);
      mUdpTKeep        : out slv(15 downto 0);
      mUdpTLast        : out sl;
      mUdpTReady       : in  sl := '1';
      mUdpSof          : out sl;
      mUdpEofe         : out sl;
      arpReqTValid     : out sl;
      arpReqTData      : out slv(127 downto 0);
      arpReqTKeep      : out slv(15 downto 0);
      arpReqTLast      : out sl;
      arpReqTReady     : in  sl := '1';
      arpReqSof        : out sl;
      arpReqEofe       : out sl;
      arpAckTValid     : in  sl;
      arpAckTData      : in  slv(127 downto 0);
      arpAckTKeep      : in  slv(15 downto 0);
      arpAckTLast      : in  sl;
      arpAckTReady     : out sl;
      arpAckSof        : in  sl;
      arpAckEofe       : in  sl;
      sServerTValid    : in  sl;
      sServerTData     : in  slv(127 downto 0);
      sServerTKeep     : in  slv(15 downto 0);
      sServerTLast     : in  sl;
      sServerTReady    : out sl;
      sServerTDest     : in  slv(7 downto 0);
      sServerSof       : in  sl;
      sServerEofe      : in  sl;
      mServerTValid    : out sl;
      mServerTData     : out slv(127 downto 0);
      mServerTKeep     : out slv(15 downto 0);
      mServerTLast     : out sl;
      mServerTReady    : in  sl := '1';
      mServerTDest     : out slv(7 downto 0);
      mServerSof       : out sl;
      mServerEofe      : out sl;
      sClientTValid    : in  sl;
      sClientTData     : in  slv(127 downto 0);
      sClientTKeep     : in  slv(15 downto 0);
      sClientTLast     : in  sl;
      sClientTReady    : out sl;
      sClientTDest     : in  slv(7 downto 0);
      sClientSof       : in  sl;
      sClientEofe      : in  sl;
      mClientTValid    : out sl;
      mClientTData     : out slv(127 downto 0);
      mClientTKeep     : out slv(15 downto 0);
      mClientTLast     : out sl;
      mClientTReady    : in  sl := '1';
      mClientTDest     : out slv(7 downto 0);
      mClientSof       : out sl;
      mClientEofe      : out sl);
end entity UdpEngineTopFlatWrapper;

architecture rtl of UdpEngineTopFlatWrapper is

   signal igmpIp           : Slv32Array(0 downto 0) := (others => (others => '0'));
   signal clientRemotePortA : Slv16Array(0 downto 0);
   signal clientRemoteIpA   : Slv32Array(0 downto 0);
   signal sUdpMaster       : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sUdpSlave        : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mUdpMaster       : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mUdpSlave        : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal arpReqMasters    : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal arpReqSlaves     : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal arpAckMasters    : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal arpAckSlaves     : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal sServerMasters   : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal sServerSlaves    : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal mServerMasters   : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal mServerSlaves    : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal sClientMasters   : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal sClientSlaves    : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal mClientMasters   : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal mClientSlaves    : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);

begin

   clientRemotePortA(0) <= clientRemotePort;
   clientRemoteIpA(0) <= clientRemoteIp;

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

   sServerComb : process (sServerEofe, sServerSof, sServerTData, sServerTDest, sServerTKeep, sServerTLast, sServerTValid) is
      variable v : AxiStreamMasterType;
   begin
      v := AXI_STREAM_MASTER_INIT_C;
      v.tValid := sServerTValid;
      v.tData(127 downto 0) := sServerTData;
      v.tKeep(15 downto 0) := sServerTKeep;
      v.tLast := sServerTLast;
      v.tDest(7 downto 0) := sServerTDest;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sServerSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sServerEofe);
      sServerMasters(0) <= v;
   end process sServerComb;

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

   arpAckComb : process (arpAckEofe, arpAckSof, arpAckTData, arpAckTKeep, arpAckTLast, arpAckTValid) is
      variable v : AxiStreamMasterType;
   begin
      v := AXI_STREAM_MASTER_INIT_C;
      v.tValid := arpAckTValid;
      v.tData(127 downto 0) := arpAckTData;
      v.tKeep(15 downto 0) := arpAckTKeep;
      v.tLast := arpAckTLast;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, arpAckSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, arpAckEofe);
      arpAckMasters(0) <= v;
   end process arpAckComb;

   mUdpView : process (mUdpMaster) is
   begin
      mUdpTValid <= mUdpMaster.tValid;
      mUdpTData <= mUdpMaster.tData(127 downto 0);
      mUdpTKeep <= mUdpMaster.tKeep(15 downto 0);
      mUdpTLast <= mUdpMaster.tLast;
      mUdpSof <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mUdpMaster, EMAC_SOF_BIT_C, 0);
      mUdpEofe <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mUdpMaster, EMAC_EOFE_BIT_C);
   end process mUdpView;

   arpReqView : process (arpReqMasters(0)) is
   begin
      arpReqTValid <= arpReqMasters(0).tValid;
      arpReqTData <= arpReqMasters(0).tData(127 downto 0);
      arpReqTKeep <= arpReqMasters(0).tKeep(15 downto 0);
      arpReqTLast <= arpReqMasters(0).tLast;
      arpReqSof <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, arpReqMasters(0), EMAC_SOF_BIT_C, 0);
      arpReqEofe <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, arpReqMasters(0), EMAC_EOFE_BIT_C);
   end process arpReqView;

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

   sUdpTReady <= sUdpSlave.tReady;
   mUdpSlave.tReady <= mUdpTReady;
   arpReqSlaves(0).tReady <= arpReqTReady;
   arpAckTReady <= arpAckSlaves(0).tReady;
   sServerTReady <= sServerSlaves(0).tReady;
   mServerSlaves(0).tReady <= mServerTReady;
   sClientTReady <= sClientSlaves(0).tReady;
   mClientSlaves(0).tReady <= mClientTReady;

   U_DUT : entity surf.UdpEngine
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         SERVER_EN_G       => true,
         SERVER_SIZE_G     => 1,
         SERVER_PORTS_G    => (0 => 8192),
         CLIENT_EN_G       => true,
         CLIENT_SIZE_G     => 1,
         CLIENT_PORTS_G    => (0 => 8193),
         ARP_TAB_ENTRIES_G => 4,
         TX_FLOW_CTRL_G    => true,
         DHCP_G            => false,
         IGMP_G            => false,
         IGMP_GRP_SIZE     => 1,
         CLK_FREQ_G        => CLK_FREQ_G,
         COMM_TIMEOUT_G    => COMM_TIMEOUT_G)
      port map (
         localMac         => localMac,
         broadcastIp      => broadcastIp,
         igmpIp           => igmpIp,
         localIpIn        => localIp,
         dhcpIpOut        => dhcpIpOut,
         obUdpMaster      => mUdpMaster,
         obUdpSlave       => mUdpSlave,
         ibUdpMaster      => sUdpMaster,
         ibUdpSlave       => sUdpSlave,
         arpReqMasters    => arpReqMasters,
         arpReqSlaves     => arpReqSlaves,
         arpAckMasters    => arpAckMasters,
         arpAckSlaves     => arpAckSlaves,
         serverRemotePort => open,
         serverRemoteIp   => open,
         obServerMasters  => mServerMasters,
         obServerSlaves   => mServerSlaves,
         ibServerMasters  => sServerMasters,
         ibServerSlaves   => sServerSlaves,
         clientRemotePort => clientRemotePortA,
         clientRemoteIp   => clientRemoteIpA,
         obClientMasters  => mClientMasters,
         obClientSlaves   => mClientSlaves,
         ibClientMasters  => sClientMasters,
         ibClientSlaves   => sClientSlaves,
         clk              => clk,
         rst              => rst);

end architecture rtl;
