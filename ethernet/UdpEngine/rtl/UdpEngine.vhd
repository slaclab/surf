-------------------------------------------------------------------------------
-- File       : UdpEngine.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-20
-- Last update: 2016-09-30
-------------------------------------------------------------------------------
-- Description: Top-Level UDP/DHCP Module
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity UdpEngine is
   generic (
      -- Simulation Generics
      TPD_G          : time          := 1 ns;
      -- UDP Server Generics
      SERVER_EN_G    : boolean       := true;
      SERVER_SIZE_G  : positive      := 1;
      SERVER_PORTS_G : PositiveArray := (0 => 8192);
      -- UDP Client Generics
      CLIENT_EN_G    : boolean       := true;
      CLIENT_SIZE_G  : positive      := 1;
      CLIENT_PORTS_G : PositiveArray := (0 => 8193);
      -- General UDP/ARP/DHCP Generics
      DHCP_G         : boolean       := false;
      CLK_FREQ_G     : real          := 156.25E+06;                 -- In units of Hz
      COMM_TIMEOUT_G : positive      := 30);  -- In units of seconds, Client's Communication timeout before re-ARPing or DHCP discover/request
   port (
      -- Local Configurations
      localMac         : in  slv(47 downto 0);                      --  big-Endian configuration
      localIpIn        : in  slv(31 downto 0);                      --  big-Endian configuration 
      dhcpIpOut        : out slv(31 downto 0);                      --  big-Endian configuration 
      -- Interface to IPV4 Engine  
      obUdpMaster      : out AxiStreamMasterType;
      obUdpSlave       : in  AxiStreamSlaveType;
      ibUdpMaster      : in  AxiStreamMasterType;
      ibUdpSlave       : out AxiStreamSlaveType;
      -- Interface to ARP Engine
      arpReqMasters    : out AxiStreamMasterArray(CLIENT_SIZE_G-1 downto 0);
      arpReqSlaves     : in  AxiStreamSlaveArray(CLIENT_SIZE_G-1 downto 0);
      arpAckMasters    : in  AxiStreamMasterArray(CLIENT_SIZE_G-1 downto 0);
      arpAckSlaves     : out AxiStreamSlaveArray(CLIENT_SIZE_G-1 downto 0);
      -- Interface to UDP Server engine(s)
      serverRemotePort : out Slv16Array(SERVER_SIZE_G-1 downto 0);  --  big-Endian configuration
      serverRemoteIp   : out Slv32Array(SERVER_SIZE_G-1 downto 0);  --  big-Endian configuration
      obServerMasters  : out AxiStreamMasterArray(SERVER_SIZE_G-1 downto 0);  --  tData is big-Endian configuration
      obServerSlaves   : in  AxiStreamSlaveArray(SERVER_SIZE_G-1 downto 0);
      ibServerMasters  : in  AxiStreamMasterArray(SERVER_SIZE_G-1 downto 0);
      ibServerSlaves   : out AxiStreamSlaveArray(SERVER_SIZE_G-1 downto 0);  --  tData is big-Endian configuration
      -- Interface to UDP Client engine(s)
      clientRemotePort : in  Slv16Array(CLIENT_SIZE_G-1 downto 0);  --  big-Endian configuration
      clientRemoteIp   : in  Slv32Array(CLIENT_SIZE_G-1 downto 0);  --  big-Endian configuration
      obClientMasters  : out AxiStreamMasterArray(CLIENT_SIZE_G-1 downto 0);  --  tData is big-Endian configuration
      obClientSlaves   : in  AxiStreamSlaveArray(CLIENT_SIZE_G-1 downto 0);
      ibClientMasters  : in  AxiStreamMasterArray(CLIENT_SIZE_G-1 downto 0);
      ibClientSlaves   : out AxiStreamSlaveArray(CLIENT_SIZE_G-1 downto 0);  --  tData is big-Endian configuration    
      -- Clock and Reset
      clk              : in  sl;
      rst              : in  sl);
end UdpEngine;

architecture mapping of UdpEngine is

   signal clientRemoteDet : slv(CLIENT_SIZE_G-1 downto 0);
   signal clientRemoteMac : Slv48Array(CLIENT_SIZE_G-1 downto 0);

   signal remotePort      : Slv16Array(SERVER_SIZE_G-1 downto 0);
   signal remoteIp        : Slv32Array(SERVER_SIZE_G-1 downto 0);
   signal serverRemoteMac : Slv48Array(SERVER_SIZE_G-1 downto 0);

   signal obUdpMasters : AxiStreamMasterArray(1 downto 0);
   signal obUdpSlaves  : AxiStreamSlaveArray(1 downto 0);

   signal ibDhcpMaster : AxiStreamMasterType;
   signal ibDhcpSlave  : AxiStreamSlaveType;

   signal obDhcpMaster : AxiStreamMasterType;
   signal obDhcpSlave  : AxiStreamSlaveType;

   signal localIp : slv(31 downto 0);
   
begin

   assert ((SERVER_EN_G = true) or (CLIENT_EN_G = true)) report
      "UdpEngine: Either SERVER_EN_G or CLIENT_EN_G must be true" severity failure;
   
   serverRemotePort <= remotePort;      -- Debug Only
   serverRemoteIp   <= remoteIp;        -- Debug Only
   dhcpIpOut        <= localIp;

   U_UdpEngineRx : entity work.UdpEngineRx
      generic map (
         TPD_G          => TPD_G,
         DHCP_G         => DHCP_G,
         SERVER_EN_G    => SERVER_EN_G,
         SERVER_SIZE_G  => SERVER_SIZE_G,
         SERVER_PORTS_G => SERVER_PORTS_G,
         CLIENT_EN_G    => CLIENT_EN_G,
         CLIENT_SIZE_G  => CLIENT_SIZE_G,
         CLIENT_PORTS_G => CLIENT_PORTS_G) 
      port map (
         -- Local Configurations
         localIp          => localIp,
         -- Interface to IPV4 Engine  
         ibUdpMaster      => ibUdpMaster,
         ibUdpSlave       => ibUdpSlave,
         -- Interface to UDP Server engine(s)
         serverRemotePort => remotePort,
         serverRemoteIp   => remoteIp,
         serverRemoteMac  => serverRemoteMac,
         obServerMasters  => obServerMasters,
         obServerSlaves   => obServerSlaves,
         -- Interface to UDP Client engine(s)
         clientRemoteDet  => clientRemoteDet,
         obClientMasters  => obClientMasters,
         obClientSlaves   => obClientSlaves,
         -- Interface to DHCP Engine  
         ibDhcpMaster     => ibDhcpMaster,
         ibDhcpSlave      => ibDhcpSlave,
         -- Clock and Reset
         clk              => clk,
         rst              => rst); 

   GEN_DHCP : if (DHCP_G = true) generate
      
      U_UdpEngineDhcp : entity work.UdpEngineDhcp
         generic map (
            -- Simulation Generics
            TPD_G          => TPD_G,
            -- UDP ARP/DHCP Generics
            CLK_FREQ_G     => CLK_FREQ_G,
            COMM_TIMEOUT_G => COMM_TIMEOUT_G)             
         port map (
            -- Local Configurations
            localMac     => localMac,
            localIp      => localIpIn,
            dhcpIp       => localIp,
            -- Interface to DHCP Engine  
            ibDhcpMaster => ibDhcpMaster,
            ibDhcpSlave  => ibDhcpSlave,
            obDhcpMaster => obDhcpMaster,
            obDhcpSlave  => obDhcpSlave,
            -- Clock and Reset
            clk          => clk,
            rst          => rst);

   end generate;

   BYPASS_DHCP : if (DHCP_G = false) generate

      localIp      <= localIpIn;
      ibDhcpSlave  <= AXI_STREAM_SLAVE_FORCE_C;
      obDhcpMaster <= AXI_STREAM_MASTER_INIT_C;
      
   end generate;

   GEN_SERVER : if (SERVER_EN_G = true) generate
      
      U_UdpEngineTx : entity work.UdpEngineTx
         generic map (
            TPD_G  => TPD_G,
            SIZE_G => SERVER_SIZE_G,
            PORT_G => SERVER_PORTS_G)    
         port map (
            -- Interface to IPV4 Engine  
            obUdpMaster  => obUdpMasters(0),
            obUdpSlave   => obUdpSlaves(0),
            -- Interface to User Application
            localIp      => localIp,
            remotePort   => remotePort,
            remoteIp     => remoteIp,
            remoteMac    => serverRemoteMac,
            ibMasters    => ibServerMasters,
            ibSlaves     => ibServerSlaves,
            -- Interface to DHCP Engine  
            obDhcpMaster => obDhcpMaster,
            obDhcpSlave  => obDhcpSlave,
            -- Clock and Reset
            clk          => clk,
            rst          => rst);

   end generate;

   GEN_CLIENT : if (CLIENT_EN_G = true) generate
      
      U_UdpEngineArp : entity work.UdpEngineArp
         generic map (
            TPD_G          => TPD_G,
            CLIENT_SIZE_G  => CLIENT_SIZE_G,
            CLK_FREQ_G     => CLK_FREQ_G,
            COMM_TIMEOUT_G => COMM_TIMEOUT_G) 
         port map (
            -- Local Configurations
            localIp         => localIp,
            -- Interface to ARP Engine
            arpReqMasters   => arpReqMasters,
            arpReqSlaves    => arpReqSlaves,
            arpAckMasters   => arpAckMasters,
            arpAckSlaves    => arpAckSlaves,
            -- Interface to UDP Client engine(s)
            clientRemoteDet => clientRemoteDet,
            clientRemoteIp  => clientRemoteIp,
            clientRemoteMac => clientRemoteMac,
            -- Clock and Reset
            clk             => clk,
            rst             => rst);

      U_UdpEngineTx : entity work.UdpEngineTx
         generic map (
            TPD_G  => TPD_G,
            SIZE_G => CLIENT_SIZE_G,
            PORT_G => CLIENT_PORTS_G)    
         port map (
            -- Interface to IPV4 Engine  
            obUdpMaster => obUdpMasters(1),
            obUdpSlave  => obUdpSlaves(1),
            -- Interface to User Application
            localIp     => localIp,
            remotePort  => clientRemotePort,
            remoteIp    => clientRemoteIp,
            remoteMac   => clientRemoteMac,
            ibMasters   => ibClientMasters,
            ibSlaves    => ibClientSlaves,
            -- Clock and Reset
            clk         => clk,
            rst         => rst);

   end generate;

   GEN_MUX : if ((SERVER_EN_G = true) and (CLIENT_EN_G = true)) generate
      
      U_AxiStreamMux : entity work.AxiStreamMux
         generic map (
            TPD_G        => TPD_G,
            NUM_SLAVES_G => 2)
         port map (
            -- Clock and reset
            axisClk      => clk,
            axisRst      => rst,
            -- Slaves
            sAxisMasters => obUdpMasters,
            sAxisSlaves  => obUdpSlaves,
            -- Master
            mAxisMaster  => obUdpMaster,
            mAxisSlave   => obUdpSlave); 

   end generate;

   NO_CLIENT : if ((SERVER_EN_G = true) and (CLIENT_EN_G = false)) generate

      -- Pass the server buses
      obUdpMaster    <= obUdpMasters(0);
      obUdpSlaves(0) <= obUdpSlave;

      -- Terminated the client buses
      ibClientSlaves  <= (others => AXI_STREAM_SLAVE_FORCE_C);
      obUdpMasters(1) <= AXI_STREAM_MASTER_INIT_C;
      arpReqMasters   <= (others => AXI_STREAM_MASTER_INIT_C);
      arpAckSlaves    <= (others => AXI_STREAM_SLAVE_FORCE_C);
      clientRemoteMac <= (others => (others => '0'));
      
   end generate;

   NO_SERVER : if ((SERVER_EN_G = false) and (CLIENT_EN_G = true)) generate

      -- Pass the client buses
      obUdpMaster    <= obUdpMasters(1);
      obUdpSlaves(1) <= obUdpSlave;

      -- Terminated the server buses
      ibServerSlaves  <= (others => AXI_STREAM_SLAVE_FORCE_C);
      obUdpMasters(0) <= AXI_STREAM_MASTER_INIT_C;
      
   end generate;
   
end mapping;
