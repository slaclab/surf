-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : UdpEngineWrapper.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-20
-- Last update: 2015-09-08
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Ethernet Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Ethernet Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.IpV4EnginePkg.all;

entity UdpEngineWrapper is
   generic (
      -- Simulation Generics
      TPD_G              : time          := 1 ns;
      SIM_ERROR_HALT_G   : boolean       := false;
      -- UDP General Generic
      RX_MTU_G           : positive      := 1500;
      RX_FORWARD_EOFE_G  : boolean       := false;
      TX_FORWARD_EOFE_G  : boolean       := false;
      TX_CALC_CHECKSUM_G : boolean       := true;
      -- UDP Server Generics
      SERVER_EN_G        : boolean       := true;
      SERVER_SIZE_G      : positive      := 1;
      SERVER_PORTS_G     : PositiveArray := (0 => 8192);
      SERVER_MTU_G       : PositiveArray := (0 => 1500);
      -- UDP Client Generics
      CLIENT_EN_G        : boolean       := true;
      CLIENT_SIZE_G      : positive      := 1;
      CLIENT_PORTS_G     : PositiveArray := (0 => 8193);
      CLIENT_MTU_G       : PositiveArray := (0 => 1500);
      -- IPv4/ARP Generics
      CLK_FREQ_G         : real          := 156.25E+06;             -- In units of Hz
      COMM_TIMEOUT_EN_G  : boolean       := true;       -- Disable the timeout by setting to false
      COMM_TIMEOUT_G     : positive      := 30;  -- In units of seconds, Client's Communication timeout before re-ARPing
      ARP_TIMEOUT_G      : positive      := 156250000;  -- In units of clock cycles (Default: 156.25 MHz clock = 1 seconds)
      VLAN_G             : boolean       := false);     -- true = VLAN support       
   port (
      -- Local Configurations
      localMac         : in  slv(47 downto 0);   --  big-Endian configuration
      localIp          : in  slv(31 downto 0);   --  big-Endian configuration
      -- Interface to Ethernet Media Access Controller (MAC)
      obMacMaster      : in  AxiStreamMasterType;
      obMacSlave       : out AxiStreamSlaveType;
      ibMacMaster      : out AxiStreamMasterType;
      ibMacSlave       : in  AxiStreamSlaveType;
      -- Interface to UDP Server engine(s)
      obServerMasters  : out AxiStreamMasterArray(SERVER_SIZE_G-1 downto 0);  --  tData is big-Endian configuration
      obServerSlaves   : in  AxiStreamSlaveArray(SERVER_SIZE_G-1 downto 0);
      ibServerMasters  : in  AxiStreamMasterArray(SERVER_SIZE_G-1 downto 0);
      ibServerSlaves   : out AxiStreamSlaveArray(SERVER_SIZE_G-1 downto 0);  --  tData is big-Endian configuration
      serverRemoteIp   : out Slv32Array(SERVER_SIZE_G-1 downto 0);  --  big-Endian configuration
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
end UdpEngineWrapper;

architecture mapping of UdpEngineWrapper is

   signal arpReqMasters : AxiStreamMasterArray(CLIENT_SIZE_G-1 downto 0);
   signal arpReqSlaves  : AxiStreamSlaveArray(CLIENT_SIZE_G-1 downto 0);
   signal arpAckMasters : AxiStreamMasterArray(CLIENT_SIZE_G-1 downto 0);
   signal arpAckSlaves  : AxiStreamSlaveArray(CLIENT_SIZE_G-1 downto 0);

   signal ibUdpMaster : AxiStreamMasterType;
   signal ibUdpSlave  : AxiStreamSlaveType;
   signal obUdpMaster : AxiStreamMasterType;
   signal obUdpSlave  : AxiStreamSlaveType;

begin

   ------------------
   -- IPv4/ARP Engine
   ------------------
   IpV4Engine_Inst : entity work.IpV4Engine
      generic map (
         TPD_G            => TPD_G,
         SIM_ERROR_HALT_G => SIM_ERROR_HALT_G,
         PROTOCOL_SIZE_G  => 1,
         PROTOCOL_G       => (0 => UDP_C),
         CLIENT_SIZE_G    => CLIENT_SIZE_G,
         ARP_TIMEOUT_G    => ARP_TIMEOUT_G,
         VLAN_G           => VLAN_G)
      port map (
         -- Local Configurations
         localMac             => localMac,
         localIp              => localIp,
         -- Interface to Ethernet Media Access Controller (MAC)
         obMacMaster          => obMacMaster,
         obMacSlave           => obMacSlave,
         ibMacMaster          => ibMacMaster,
         ibMacSlave           => ibMacSlave,
         -- Interface to Protocol Engine(s)  
         obProtocolMasters(0) => obUdpMaster,
         obProtocolSlaves(0)  => obUdpSlave,
         ibProtocolMasters(0) => ibUdpMaster,
         ibProtocolSlaves(0)  => ibUdpSlave,
         -- Interface to Client Engine(s)
         arpReqMasters        => arpReqMasters,
         arpReqSlaves         => arpReqSlaves,
         arpAckMasters        => arpAckMasters,
         arpAckSlaves         => arpAckSlaves,
         -- Clock and Reset
         clk                  => clk,
         rst                  => rst);

   -------------
   -- UDP Engine
   -------------
   UdpEngine_Inst : entity work.UdpEngine
      generic map (
         -- Simulation Generics
         TPD_G              => TPD_G,
         SIM_ERROR_HALT_G   => SIM_ERROR_HALT_G,
         -- UDP General Generic
         RX_MTU_G           => RX_MTU_G,
         RX_FORWARD_EOFE_G  => RX_FORWARD_EOFE_G,
         TX_FORWARD_EOFE_G  => TX_FORWARD_EOFE_G,
         TX_CALC_CHECKSUM_G => TX_CALC_CHECKSUM_G,
         -- UDP Server Generics
         SERVER_EN_G        => SERVER_EN_G,
         SERVER_SIZE_G      => SERVER_SIZE_G,
         SERVER_PORTS_G     => SERVER_PORTS_G,
         SERVER_MTU_G       => SERVER_MTU_G,
         -- UDP Client Generics
         CLIENT_EN_G        => CLIENT_EN_G,
         CLIENT_SIZE_G      => CLIENT_SIZE_G,
         CLIENT_PORTS_G     => CLIENT_PORTS_G,
         CLIENT_MTU_G       => CLIENT_MTU_G,
         -- UDP ARP Generics
         CLK_FREQ_G         => CLK_FREQ_G,
         COMM_TIMEOUT_EN_G  => COMM_TIMEOUT_EN_G,
         COMM_TIMEOUT_G     => COMM_TIMEOUT_G)  
      port map (
         -- Local Configurations
         localIp          => localIp,
         -- Interface to IPV4 Engine  
         obUdpMaster      => obUdpMaster,
         obUdpSlave       => obUdpSlave,
         ibUdpMaster      => ibUdpMaster,
         ibUdpSlave       => ibUdpSlave,
         -- Interface to ARP Engine
         arpReqMasters    => arpReqMasters,
         arpReqSlaves     => arpReqSlaves,
         arpAckMasters    => arpAckMasters,
         arpAckSlaves     => arpAckSlaves,
         -- Interface to UDP Server engine(s)
         obServerMasters  => obServerMasters,
         obServerSlaves   => obServerSlaves,
         ibServerMasters  => ibServerMasters,
         ibServerSlaves   => ibServerSlaves,
         serverRemoteIp   => serverRemoteIp,
         -- Interface to UDP Client engine(s)
         clientRemotePort => clientRemotePort,
         clientRemoteIp   => clientRemoteIp,
         obClientMasters  => obClientMasters,
         obClientSlaves   => obClientSlaves,
         ibClientMasters  => ibClientMasters,
         ibClientSlaves   => ibClientSlaves,
         -- Clock and Reset
         clk              => clk,
         rst              => rst);  

end mapping;
