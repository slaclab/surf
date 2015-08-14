-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : IpV4Engine.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-12
-- Last update: 2015-08-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.IpV4EnginePkg.all;

entity IpV4Engine is
   generic (
      TPD_G         : time                    := 1 ns;         -- Simulation parameter only
      PROTOCOL_G    : slv(7 downto 0)         := UDP_C;        -- UDP protocol by default
      ARP_TIMEOUT_G : slv(31 downto 0)        := x"09502F90";  -- In units of clock cycles (Default: 156.25 MHz clock = 1 seconds)
      MAC_TIMEOUT_G : slv(31 downto 0)        := x"FFFFFFFF";  -- In units of clock cycles (Default: 156.25 MHz clock = 27 seconds)
      CLIENT_SIZE_G : positive range 1 to 32  := 1;  -- Sets the number of attached client engines
      TABLE_SIZE_G  : positive range 1 to 256 := 16;           -- Sets the IP/MAC table depth
      VLAN_G        : boolean                 := false);       -- true = VLAN support 
   port (
      -- Local Configuration
      mac                   : in  slv(47 downto 0);  --  big-endian configuration
      ip                    : in  slv(31 downto 0);  --  big-endian configuration
      -- Interface to Ethernet Media Access Controller (MAC)
      obMacMaster           : in  AxiStreamMasterType;
      obMacSlave            : out AxiStreamSlaveType;
      ibMacMaster           : out AxiStreamMasterType;
      ibMacSlave            : in  AxiStreamSlaveType;
      -- Interface to Protocol Engine  
      obProtocolMaster      : in  AxiStreamMasterType;
      obProtocolSlave       : out AxiStreamSlaveType;
      ibProtocolMaster      : out AxiStreamMasterType;
      ibProtocolSlave       : in  AxiStreamSlaveType;
      obProtocolDestMasters : in  AxiStreamMasterArray(APP_SIZE_G-1 downto 0);  -- Request via IP only
      obProtocolDestSlaves  : out AxiStreamSlaveArray(APP_SIZE_G-1 downto 0);
      ibProtocolDestMasters : out AxiStreamMasterArray(APP_SIZE_G-1 downto 0);  -- Respond with DEST
      ibProtocolDestSlaves  : in  AxiStreamSlaveArray(APP_SIZE_G-1 downto 0);
      -- Clock and Reset
      clk                   : in  sl;
      rst                   : in  sl);
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

   signal ibArpMacMaster : AxiStreamMasterType;
   signal ibArpMacSlave  : AxiStreamSlaveType;
   signal obArpMacMaster : AxiStreamMasterType;
   signal obArpMacSlave  : AxiStreamSlaveType;

   signal obIpV4DestMaster : AxiStreamMasterType;
   signal obIpV4DestSlave  : AxiStreamSlaveType;
   signal ibIpV4DestMaster : AxiStreamMasterType;
   signal ibIpV4DestSlave  : AxiStreamSlaveType;

   signal obIpV4MacMaster : AxiStreamMasterType;
   signal obIpV4MacSlave  : AxiStreamSlaveType;
   signal ibIpV4MacMaster : AxiStreamMasterType;
   signal ibIpV4MacSlave  : AxiStreamSlaveType;
   
begin

   U_EthFrameDeMux : entity work.EthFrameDeMux
      generic map (
         TPD_G  => TPD_G,
         VLAN_G => VLAN_G) 
      port map (
         -- Slave
         sEthMaster   => obMacMaster,
         sEthSlave    => obMacSlave,
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
         TPD_G  => TPD_G,
         VLAN_G => VLAN_G)
      port map (
         -- Local Configuration
         mac            => mac,
         ip             => ip,
         -- Interface to IP/MAC Table 
         ibArpMacMaster => ibArpMacMaster,
         ibArpMacSlave  => ibArpMacSlave,
         obArpMacMaster => obArpMacMaster,
         obArpMacSlave  => obArpMacSlave,
         -- Interface to Etherenet Frame MUX/DEMUX 
         ibArpMaster    => ibArpMaster,
         ibArpSlave     => ibArpSlave,
         obArpMaster    => obArpMaster,
         obArpSlave     => obArpSlave,
         -- Clock and Reset
         clk            => clk,
         rst            => rst);

   U_IpMacTable : entity work.IpMacTable
      generic map (
         TPD_G         => TPD_G,
         CLIENT_SIZE_G => CLIENT_SIZE_G,
         TABLE_SIZE_G  => TABLE_SIZE_G)
      port map (
         -- Interface to ARP Engine
         ibArpMacMaster        => ibArpMacMaster,
         ibArpMacSlave         => ibArpMacSlave,
         obArpMacMaster        => obArpMacMaster,
         obArpMacSlave         => obArpMacSlave,
         -- Interface to IPV4 Engine
         obIpV4DestMaster      => obIpV4DestMaster,
         obIpV4DestSlave       => obIpV4DestSlave,
         ibIpV4DestMaster      => ibIpV4DestMaster,
         ibIpV4DestSlave       => ibIpV4DestSlave,
         obIpV4MacMaster       => obIpV4MacMaster,
         obIpV4MacSlave        => obIpV4MacSlave,
         ibIpV4MacMaster       => ibIpV4MacMaster,
         ibIpV4MacSlave        => ibIpV4MacSlave,
         -- Interface to Protocol Engine  
         obProtocolDestMasters => obProtocolDestMasters,
         obProtocolDestSlaves  => obProtocolDestSlaves,
         ibProtocolDestMasters => ibProtocolDestMasters,
         ibProtocolDestSlaves  => ibProtocolDestSlaves,
         -- Clock and Reset
         clk                   => clk,
         rst                   => rst);

   U_IpV4EngineRx : entity work.IpV4EngineRx
      generic map (
         TPD_G      => TPD_G,
         PROTOCOL_G => PROTOCOL_G,
         VLAN_G     => VLAN_G)    
      port map (
         -- Interface to IP/MAC Table 
         obIpV4DestMaster => obIpV4DestMaster,
         obIpV4DestSlave  => obIpV4DestSlave,
         ibIpV4DestMaster => ibIpV4DestMaster,
         ibIpV4DestSlave  => ibIpV4DestSlave,
         -- Interface to Etherenet Frame MUX/DEMUX 
         ibIpv4Master     => ibIpv4Master,
         ibIpv4Slave      => ibIpv4Slave,
         -- Interface to Protocol Engine  
         ibProtocolMaster => ibProtocolMaster,
         ibProtocolSlave  => ibProtocolSlave,
         -- Clock and Reset
         clk              => clk,
         rst              => rst); 

   U_IpV4EngineTx : entity work.IpV4EngineTx
      generic map (
         TPD_G      => TPD_G,
         PROTOCOL_G => PROTOCOL_G,
         VLAN_G     => VLAN_G)    
      port map (
         -- Interface to IP/MAC Table 
         obIpV4MacMaster  => obIpV4MacMaster,
         obIpV4MacSlave   => obIpV4MacSlave,
         ibIpV4MacMaster  => ibIpV4MacMaster,
         ibIpV4MacSlave   => ibIpV4MacSlave,
         -- Interface to Etherenet Frame MUX/DEMUX 
         obIpv4Master     => obIpv4Master,
         obIpv4Slave      => obIpv4Slave,
         -- Interface to Protocol Engine  
         obProtocolMaster => obProtocolMaster,
         obProtocolSlave  => obProtocolSlave,
         -- Clock and Reset
         clk              => clk,
         rst              => rst); 

end mapping;
