-------------------------------------------------------------------------------
-- File       : UdpEngineWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-20
-- Last update: 2016-11-02
-------------------------------------------------------------------------------
-- Description: Wrapper for UdpEngine
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.EthMacPkg.all;

entity UdpEngineWrapper is
   generic (
      -- Simulation Generics
      TPD_G               : time            := 1 ns;
      -- UDP Server Generics
      SERVER_EN_G         : boolean         := true;
      SERVER_SIZE_G       : positive        := 1;
      SERVER_PORTS_G      : PositiveArray   := (0 => 8192);
      -- UDP Client Generics
      CLIENT_EN_G         : boolean         := true;
      CLIENT_SIZE_G       : positive        := 1;
      CLIENT_PORTS_G      : PositiveArray   := (0 => 8193);
      CLIENT_EXT_CONFIG_G : boolean         := false;
      AXI_ERROR_RESP_G    : slv(1 downto 0) := AXI_RESP_DECERR_C;
      -- General IPv4/ARP/DHCP Generics
      DHCP_G              : boolean         := false;
      CLK_FREQ_G          : real            := 156.25E+06;                   -- In units of Hz
      COMM_TIMEOUT_G      : positive        := 30;  -- In units of seconds, Client's Communication timeout before re-ARPing or DHCP discover/request
      TTL_G               : slv(7 downto 0) := x"20";   -- IPv4's Time-To-Live (TTL)
      VLAN_G              : boolean         := false);  -- true = VLAN support       
   port (
      -- Local Configurations
      localMac         : in  slv(47 downto 0);      --  big-Endian configuration
      localIp          : in  slv(31 downto 0);      --  big-Endian configuration
      -- Remote Configurations
      clientRemotePort : in  Slv16Array(CLIENT_SIZE_G-1 downto 0)           := (others => x"0000");
      clientRemoteIp   : in  Slv32Array(CLIENT_SIZE_G-1 downto 0)           := (others => x"00000000");
      -- Interface to Ethernet Media Access Controller (MAC)
      obMacMaster      : in  AxiStreamMasterType;
      obMacSlave       : out AxiStreamSlaveType;
      ibMacMaster      : out AxiStreamMasterType;
      ibMacSlave       : in  AxiStreamSlaveType;
      -- Interface to UDP Server engine(s)
      obServerMasters  : out AxiStreamMasterArray(SERVER_SIZE_G-1 downto 0);  --  tData is big-Endian configuration
      obServerSlaves   : in  AxiStreamSlaveArray(SERVER_SIZE_G-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);
      ibServerMasters  : in  AxiStreamMasterArray(SERVER_SIZE_G-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
      ibServerSlaves   : out AxiStreamSlaveArray(SERVER_SIZE_G-1 downto 0);  --  tData is big-Endian configuration
      -- Interface to UDP Client engine(s)
      obClientMasters  : out AxiStreamMasterArray(CLIENT_SIZE_G-1 downto 0);  --  tData is big-Endian configuration
      obClientSlaves   : in  AxiStreamSlaveArray(CLIENT_SIZE_G-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);
      ibClientMasters  : in  AxiStreamMasterArray(CLIENT_SIZE_G-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
      ibClientSlaves   : out AxiStreamSlaveArray(CLIENT_SIZE_G-1 downto 0);  --  tData is big-Endian configuration
      -- AXI-Lite Interface
      axilReadMaster   : in  AxiLiteReadMasterType                          := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave    : out AxiLiteReadSlaveType;
      axilWriteMaster  : in  AxiLiteWriteMasterType                         := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave   : out AxiLiteWriteSlaveType;
      -- Clock and Reset
      clk              : in  sl;
      rst              : in  sl);
end UdpEngineWrapper;

architecture rtl of UdpEngineWrapper is

   type RegType is record
      clientRemotePort : Slv16Array(CLIENT_SIZE_G-1 downto 0);
      clientRemoteIp   : Slv32Array(CLIENT_SIZE_G-1 downto 0);
      axilReadSlave    : AxiLiteReadSlaveType;
      axilWriteSlave   : AxiLiteWriteSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      clientRemotePort => (others => (others => '0')),
      clientRemoteIp   => (others => (others => '0')),
      axilReadSlave    => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave   => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal arpReqMasters : AxiStreamMasterArray(CLIENT_SIZE_G-1 downto 0);
   signal arpReqSlaves  : AxiStreamSlaveArray(CLIENT_SIZE_G-1 downto 0);
   signal arpAckMasters : AxiStreamMasterArray(CLIENT_SIZE_G-1 downto 0);
   signal arpAckSlaves  : AxiStreamSlaveArray(CLIENT_SIZE_G-1 downto 0);

   signal ibUdpMaster : AxiStreamMasterType;
   signal ibUdpSlave  : AxiStreamSlaveType;
   signal obUdpMaster : AxiStreamMasterType;
   signal obUdpSlave  : AxiStreamSlaveType;

   signal serverRemotePort : Slv16Array(SERVER_SIZE_G-1 downto 0);
   signal serverRemoteIp   : Slv32Array(SERVER_SIZE_G-1 downto 0);
   signal dhcpIp           : slv(31 downto 0);

begin

   ------------------
   -- IPv4/ARP Engine
   ------------------
   IpV4Engine_Inst : entity work.IpV4Engine
      generic map (
         TPD_G           => TPD_G,
         PROTOCOL_SIZE_G => 1,
         PROTOCOL_G      => (0 => UDP_C),
         CLIENT_SIZE_G   => CLIENT_SIZE_G,
         CLK_FREQ_G      => CLK_FREQ_G,
         VLAN_G          => VLAN_G)
      port map (
         -- Local Configurations
         localMac             => localMac,
         localIp              => dhcpIp,
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
         TPD_G          => TPD_G,
         -- UDP Server Generics
         SERVER_EN_G    => SERVER_EN_G,
         SERVER_SIZE_G  => SERVER_SIZE_G,
         SERVER_PORTS_G => SERVER_PORTS_G,
         -- UDP Client Generics
         CLIENT_EN_G    => CLIENT_EN_G,
         CLIENT_SIZE_G  => CLIENT_SIZE_G,
         CLIENT_PORTS_G => CLIENT_PORTS_G,
         -- UDP ARP/DHCP Generics
         DHCP_G         => DHCP_G,
         CLK_FREQ_G     => CLK_FREQ_G,
         COMM_TIMEOUT_G => COMM_TIMEOUT_G)  
      port map (
         -- Local Configurations
         localMac         => localMac,
         localIpIn        => localIp,
         dhcpIpOut        => dhcpIp,
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
         serverRemotePort => serverRemotePort,
         serverRemoteIp   => serverRemoteIp,
         obServerMasters  => obServerMasters,
         obServerSlaves   => obServerSlaves,
         ibServerMasters  => ibServerMasters,
         ibServerSlaves   => ibServerSlaves,
         -- Interface to UDP Client engine(s)
         clientRemotePort => r.clientRemotePort,
         clientRemoteIp   => r.clientRemoteIp,
         obClientMasters  => obClientMasters,
         obClientSlaves   => obClientSlaves,
         ibClientMasters  => ibClientMasters,
         ibClientSlaves   => ibClientSlaves,
         -- Clock and Reset
         clk              => clk,
         rst              => rst);  

   comb : process (axilReadMaster, axilWriteMaster, clientRemoteIp, clientRemotePort, dhcpIp,
                   localMac, r, rst, serverRemoteIp, serverRemotePort) is
      variable v      : RegType;
      variable regCon : AxiLiteEndPointType;
      variable i      : natural;
   begin
      -- Latch the current value
      v := r;

      -- Determine the transaction type
      axiSlaveWaitTxn(regCon, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Map the read/write registers
      for i in CLIENT_SIZE_G-1 downto 0 loop
         axiSlaveRegister(regCon, toSlv((8*i)+0, 12), 0, v.clientRemotePort(i));  --  big-Endian configuration
         axiSlaveRegister(regCon, toSlv((8*i)+4, 12), 0, v.clientRemoteIp(i));  --  big-Endian configuration
      end loop;
      -- Map the read only registers
      for i in SERVER_SIZE_G-1 downto 0 loop
         axiSlaveRegisterR(regCon, toSlv((8*i)+0+2048, 12), 0, serverRemotePort(i));  --  big-Endian configuration
         axiSlaveRegisterR(regCon, toSlv((8*i)+4+2048, 12), 0, serverRemoteIp(i));  --  big-Endian configuration
      end loop;

      axiSlaveRegisterR(regCon, x"FF4", 0, dhcpIp);
      axiSlaveRegisterR(regCon, x"FF8", 0, localMac);

      -- Closeout the transaction
      axiSlaveDefault(regCon, v.axilWriteSlave, v.axilReadSlave, AXI_ERROR_RESP_G);

      -- Synchronous Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Check for external configuration
      if (CLIENT_EXT_CONFIG_G = true) then
         v.clientRemotePort := clientRemotePort;
         v.clientRemoteIp   := clientRemoteIp;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;
      
   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
