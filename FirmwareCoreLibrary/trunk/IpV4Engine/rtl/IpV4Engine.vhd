-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : IpV4Engine.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-12
-- Last update: 2015-08-25
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.IpV4EnginePkg.all;

entity IpV4Engine is
   generic (
      TPD_G            : time      := 1 ns;       -- Simulation parameter only
      SIM_ERROR_HALT_G : boolean   := false;      -- Simulation parameter only
      PROTOCOL_SIZE_G  : positive  := 1;          -- Default to 1x protocol
      PROTOCOL_G       : Slv8Array := (0 => UDP_C);  -- Default to UDP protocol
      CLIENT_SIZE_G    : positive  := 1;          -- Sets the number of attached client engines
      ARP_TIMEOUT_G    : positive  := 156250000;  -- In units of clock cycles (Default: 156.25 MHz clock = 1 seconds)
      VLAN_G           : boolean   := false);     -- true = VLAN support 
   port (
      -- Local Configurations
      localMac          : in  slv(47 downto 0);   --  big-Endian configuration
      localIp           : in  slv(31 downto 0);   --  big-Endian configuration
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

   signal ibArpMaster : AxiStreamMasterType;
   signal ibArpSlave  : AxiStreamSlaveType;
   signal obArpMaster : AxiStreamMasterType;
   signal obArpSlave  : AxiStreamSlaveType;

   signal ibIpv4Master : AxiStreamMasterType;
   signal ibIpv4Slave  : AxiStreamSlaveType;
   signal obIpv4Master : AxiStreamMasterType;
   signal obIpv4Slave  : AxiStreamSlaveType;
   
begin

   U_EthFrameDeMux : entity work.EthFrameDeMux
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

   U_EthFrameMux : entity work.AxiStreamMux
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

   U_ArpEngine : entity work.ArpEngine
      generic map (
         TPD_G         => TPD_G,
         CLIENT_SIZE_G => CLIENT_SIZE_G,
         ARP_TIMEOUT_G => ARP_TIMEOUT_G,
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

   U_IpV4EngineRx : entity work.IpV4EngineRx
      generic map (
         TPD_G            => TPD_G,
         SIM_ERROR_HALT_G => SIM_ERROR_HALT_G,
         PROTOCOL_SIZE_G  => PROTOCOL_SIZE_G,
         PROTOCOL_G       => PROTOCOL_G,
         VLAN_G           => VLAN_G)    
      port map (
         -- Local Configurations
         localIp           => localIp,
         -- Interface to Ethernet Frame MUX/DEMUX 
         ibIpv4Master      => ibIpv4Master,
         ibIpv4Slave       => ibIpv4Slave,
         -- Interface to Protocol Engine  
         ibProtocolMasters => ibProtocolMasters,
         ibProtocolSlaves  => ibProtocolSlaves,
         -- Clock and Reset
         clk               => clk,
         rst               => rst); 

   U_IpV4EngineTx : entity work.IpV4EngineTx
      generic map (
         TPD_G            => TPD_G,
         SIM_ERROR_HALT_G => SIM_ERROR_HALT_G,
         PROTOCOL_SIZE_G  => PROTOCOL_SIZE_G,
         PROTOCOL_G       => PROTOCOL_G,
         VLAN_G           => VLAN_G)    
      port map (
         -- Local Configurations
         localMac          => localMac,
         localIp           => localIp,
         -- Interface to Ethernet Frame MUX/DEMUX 
         obIpv4Master      => obIpv4Master,
         obIpv4Slave       => obIpv4Slave,
         -- Interface to Protocol Engine  
         obProtocolMasters => obProtocolMasters,
         obProtocolSlaves  => obProtocolSlaves,
         -- Clock and Reset
         clk               => clk,
         rst               => rst); 

end mapping;
