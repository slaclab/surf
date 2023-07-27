-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IPv4 Top-level Module for IPv4/ARP/ICMP
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

entity IpV4Engine is
   generic (
      TPD_G           : time            := 1 ns;  -- Simulation parameter only
      PROTOCOL_SIZE_G : positive        := 1;  -- Default to 1x protocol
      PROTOCOL_G      : Slv8Array       := (0 => UDP_C);  -- Default to UDP protocol
      CLIENT_SIZE_G   : positive        := 1;  -- Sets the number of attached client engines
      CLK_FREQ_G      : real            := 156.25E+06;    -- In units of Hz
      TTL_G           : slv(7 downto 0) := x"20";
      IGMP_G          : boolean         := false;
      IGMP_GRP_SIZE   : positive        := 1;
      VLAN_G          : boolean         := false);  -- true = VLAN support
   port (
      -- Local Configurations
      localMac          : in  slv(47 downto 0);   --  big-Endian configuration
      localIp           : in  slv(31 downto 0);   --  big-Endian configuration
      igmpIp            : in  Slv32Array(IGMP_GRP_SIZE-1 downto 0);  --  big-Endian configuration
      -- Interface to Ethernet Media Access Controller (MAC)
      obMacMaster       : in  AxiStreamMasterType;
      obMacSlave        : out AxiStreamSlaveType;
      ibMacMaster       : out AxiStreamMasterType;
      ibMacSlave        : in  AxiStreamSlaveType;
      -- Interface to Protocol Engine(s)
      obProtocolMasters : in  AxiStreamMasterArray(PROTOCOL_SIZE_G-1 downto 0);
      obProtocolSlaves  : out AxiStreamSlaveArray(PROTOCOL_SIZE_G-1 downto 0);
      ibProtocolMasters : out AxiStreamMasterArray(PROTOCOL_SIZE_G-1 downto 0);
      ibProtocolSlaves  : in  AxiStreamSlaveArray(PROTOCOL_SIZE_G-1 downto 0);
      -- Interface to Client Engine(s)
      arpReqMasters     : in  AxiStreamMasterArray(CLIENT_SIZE_G-1 downto 0);  -- Request via IP address
      arpReqSlaves      : out AxiStreamSlaveArray(CLIENT_SIZE_G-1 downto 0);
      arpAckMasters     : out AxiStreamMasterArray(CLIENT_SIZE_G-1 downto 0);  -- Respond with MAC address
      arpAckSlaves      : in  AxiStreamSlaveArray(CLIENT_SIZE_G-1 downto 0);
      -- Clock and Reset
      clk               : in  sl;
      rst               : in  sl);
end IpV4Engine;

architecture mapping of IpV4Engine is

   constant PROTOCOL_SIZE_C : positive := ite(IGMP_G, PROTOCOL_SIZE_G+2, PROTOCOL_SIZE_G+1);

   function GenIPv4List (foo : Slv8Array(PROTOCOL_SIZE_G-1 downto 0)) return Slv8Array is
      variable retVar : Slv8Array(PROTOCOL_SIZE_C-1 downto 0);
      variable i      : natural;
   begin
      for i in PROTOCOL_SIZE_G-1 downto 0 loop
         retVar(i) := foo(i);
      end loop;
      retVar(PROTOCOL_SIZE_G) := ICMP_C;
      if IGMP_G then
         retVar(PROTOCOL_SIZE_G+1) := IGMP_C;
      end if;
      return retVar;
   end function;
   constant PROTOCOL_C : Slv8Array(PROTOCOL_SIZE_C-1 downto 0) := GenIPv4List(PROTOCOL_G);

   signal ibArpMaster : AxiStreamMasterType;
   signal ibArpSlave  : AxiStreamSlaveType;
   signal obArpMaster : AxiStreamMasterType;
   signal obArpSlave  : AxiStreamSlaveType;

   signal ibIpv4Master : AxiStreamMasterType;
   signal ibIpv4Slave  : AxiStreamSlaveType;
   signal obIpv4Master : AxiStreamMasterType;
   signal obIpv4Slave  : AxiStreamSlaveType;

   signal localhostMaster : AxiStreamMasterType;
   signal localhostSlave  : AxiStreamSlaveType;

   signal ibMasters : AxiStreamMasterArray(PROTOCOL_SIZE_C-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal ibSlaves  : AxiStreamSlaveArray(PROTOCOL_SIZE_C-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);
   signal obMasters : AxiStreamMasterArray(PROTOCOL_SIZE_C-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal obSlaves  : AxiStreamSlaveArray(PROTOCOL_SIZE_C-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);

begin

   U_EthFrameDeMux : entity surf.IpV4EngineDeMux
      generic map (
         TPD_G  => TPD_G,
         VLAN_G => VLAN_G)
      port map (
         -- Local Configurations
         localMac     => localMac,
         -- Slave
         obMacMaster  => obMacMaster,
         obMacSlave   => obMacSlave,
         -- Masters
         ibArpMaster  => ibArpMaster,
         ibArpSlave   => ibArpSlave,
         ibIpv4Master => ibIpv4Master,
         ibIpv4Slave  => ibIpv4Slave,
         -- Clock and Reset
         clk          => clk,
         rst          => rst);

   U_EthFrameMux : entity surf.AxiStreamMux
      generic map (
         TPD_G        => TPD_G,
         NUM_SLAVES_G => 2)
      port map (
         -- Clock and reset
         axisClk         => clk,
         axisRst         => rst,
         -- Slaves
         sAxisMasters(0) => obArpMaster,
         sAxisMasters(1) => obIpv4Master,
         sAxisSlaves(0)  => obArpSlave,
         sAxisSlaves(1)  => obIpv4Slave,
         -- Master
         mAxisMaster     => ibMacMaster,
         mAxisSlave      => ibMacSlave);

   U_ArpEngine : entity surf.ArpEngine
      generic map (
         TPD_G         => TPD_G,
         CLIENT_SIZE_G => CLIENT_SIZE_G,
         CLK_FREQ_G    => CLK_FREQ_G,
         VLAN_G        => VLAN_G)
      port map (
         -- Local Configurations
         localMac      => localMac,
         localIp       => localIp,
         -- Interface to Client Engine(s)
         arpReqMasters => arpReqMasters,
         arpReqSlaves  => arpReqSlaves,
         arpAckMasters => arpAckMasters,
         arpAckSlaves  => arpAckSlaves,
         -- Interface to Ethernet Frame MUX/DEMUX
         ibArpMaster   => ibArpMaster,
         ibArpSlave    => ibArpSlave,
         obArpMaster   => obArpMaster,
         obArpSlave    => obArpSlave,
         -- Clock and Reset
         clk           => clk,
         rst           => rst);

   U_IpV4EngineRx : entity surf.IpV4EngineRx
      generic map (
         TPD_G           => TPD_G,
         PROTOCOL_SIZE_G => PROTOCOL_SIZE_C,
         PROTOCOL_G      => PROTOCOL_C,
         VLAN_G          => VLAN_G)
      port map (
         -- Interface to Ethernet Frame MUX/DEMUX
         ibIpv4Master      => ibIpv4Master,
         ibIpv4Slave       => ibIpv4Slave,
         localhostMaster   => localhostMaster,
         localhostSlave    => localhostSlave,
         -- Interface to Protocol Engine
         ibProtocolMasters => ibMasters,
         ibProtocolSlaves  => ibSlaves,
         -- Clock and Reset
         clk               => clk,
         rst               => rst);

   U_IpV4EngineTx : entity surf.IpV4EngineTx
      generic map (
         TPD_G           => TPD_G,
         PROTOCOL_SIZE_G => PROTOCOL_SIZE_C,
         PROTOCOL_G      => PROTOCOL_C,
         TTL_G           => TTL_G,
         VLAN_G          => VLAN_G)
      port map (
         -- Local Configurations
         localMac          => localMac,
         -- Interface to Ethernet Frame MUX/DEMUX
         obIpv4Master      => obIpv4Master,
         obIpv4Slave       => obIpv4Slave,
         localhostMaster   => localhostMaster,
         localhostSlave    => localhostSlave,
         -- Interface to Protocol Engine
         obProtocolMasters => obMasters,
         obProtocolSlaves  => obSlaves,
         -- Clock and Reset
         clk               => clk,
         rst               => rst);

   U_IcmpEngine : entity surf.IcmpEngine
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Local Configurations
         localIp      => localIp,
         -- Interface to ICMP Engine
         ibIcmpMaster => ibMasters(PROTOCOL_SIZE_G+0),
         ibIcmpSlave  => ibSlaves(PROTOCOL_SIZE_G+0),
         obIcmpMaster => obMasters(PROTOCOL_SIZE_G+0),
         obIcmpSlave  => obSlaves(PROTOCOL_SIZE_G+0),
         -- Clock and Reset
         clk          => clk,
         rst          => rst);

   GEN_IGMP : if (IGMP_G = true) generate
      U_IgmpV2Engine : entity surf.IgmpV2Engine
         generic map (
            TPD_G         => TPD_G,
            IGMP_GRP_SIZE => IGMP_GRP_SIZE,
            CLK_FREQ_G    => CLK_FREQ_G)
         port map (
            -- Local Configurations
            localIp      => localIp,
            igmpIp       => igmpIp,
            -- Interface to ICMP Engine
            ibIgmpMaster => ibMasters(PROTOCOL_SIZE_G+1),
            ibIgmpSlave  => ibSlaves(PROTOCOL_SIZE_G+1),
            obIgmpMaster => obMasters(PROTOCOL_SIZE_G+1),
            obIgmpSlave  => obSlaves(PROTOCOL_SIZE_G+1),
            -- Clock and Reset
            clk          => clk,
            rst          => rst);
   end generate;

   GEN_VEC :
   for i in (PROTOCOL_SIZE_G-1) downto 0 generate
      obMasters(i)         <= obProtocolMasters(i);
      obProtocolSlaves(i)  <= obSlaves(i);
      ibProtocolMasters(i) <= ibMasters(i);
      ibSlaves(i)          <= ibProtocolSlaves(i);
   end generate GEN_VEC;

end mapping;
