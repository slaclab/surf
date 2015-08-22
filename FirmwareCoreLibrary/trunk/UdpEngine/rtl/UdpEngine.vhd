-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : UdpEngine.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-20
-- Last update: 2015-08-21
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

entity UdpEngine is
   generic (
      -- Simulation Generics
      TPD_G               : time         := 1 ns;
      -- UDP General Generic
      MAX_DATAGRAM_SIZE_G : positive     := 1440;  -- In units of bytes
      RX_FORWARD_EOFE_G   : boolean      := false;
      TX_FORWARD_EOFE_G   : boolean      := false;
      -- UDP Server Generics
      SERVER_EN_G         : boolean      := true;
      SERVER_SIZE_G       : positive     := 1;
      SERVER_PORTS_G      : NaturalArray := (0 => 8192);
      -- UDP Client Generics
      CLIENT_EN_G         : boolean      := true;
      CLIENT_SIZE_G       : positive     := 1;
      CLIENT_PORTS_G      : NaturalArray := (0 => 8193);
      -- UDP ARP Generics
      CLK_FREQ_G          : real         := 156.25E+06;             -- In units of Hz
      COMM_TIMEOUT_EN_G   : boolean      := true;  -- Disable the timeout by setting to false
      COMM_TIMEOUT_G      : positive     := 30);  -- In units of seconds, Client's Commmunication timeout before re-ARPing
   port (
      -- Local Configurations
      localIp          : in  slv(31 downto 0);    --  big-endian configuration
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
      obServerMasters  : out AxiStreamMasterArray(SERVER_SIZE_G-1 downto 0);  --  tData is big-endian configuration
      obServerSlaves   : in  AxiStreamSlaveArray(SERVER_SIZE_G-1 downto 0);
      ibServerMasters  : in  AxiStreamMasterArray(SERVER_SIZE_G-1 downto 0);
      ibServerSlaves   : out AxiStreamSlaveArray(SERVER_SIZE_G-1 downto 0);  --  tData is big-endian configuration
      -- Interface to UDP Client engine(s)
      clientRemotePort : in  Slv16Array(CLIENT_SIZE_G-1 downto 0);  --  big-endian configuration
      clientRemoteIp   : in  Slv32Array(CLIENT_SIZE_G-1 downto 0);  --  big-endian configuration
      obClientMasters  : out AxiStreamMasterArray(CLIENT_SIZE_G-1 downto 0);  --  tData is big-endian configuration
      obClientSlaves   : in  AxiStreamSlaveArray(CLIENT_SIZE_G-1 downto 0);
      ibClientMasters  : in  AxiStreamMasterArray(CLIENT_SIZE_G-1 downto 0);
      ibClientSlaves   : out AxiStreamSlaveArray(CLIENT_SIZE_G-1 downto 0);  --  tData is big-endian configuration
      -- Clock and Reset
      clk              : in  sl;
      rst              : in  sl);
end UdpEngine;

architecture mapping of UdpEngine is

   signal clientRemoteDet : slv(CLIENT_SIZE_G-1 downto 0);
   signal clientRemoteMac : Slv48Array(CLIENT_SIZE_G-1 downto 0);

   signal serverRemotePort : Slv16Array(SERVER_SIZE_G-1 downto 0);
   signal serverRemoteIp   : Slv32Array(SERVER_SIZE_G-1 downto 0);
   signal serverRemoteMac  : Slv48Array(SERVER_SIZE_G-1 downto 0);

   signal serverMasters : AxiStreamMasterArray(SERVER_SIZE_G-1 downto 0);
   signal serverSlaves  : AxiStreamSlaveArray(SERVER_SIZE_G-1 downto 0);

   signal clientMasters : AxiStreamMasterArray(CLIENT_SIZE_G-1 downto 0);
   signal clientSlaves  : AxiStreamSlaveArray(CLIENT_SIZE_G-1 downto 0);

   signal obUdpMasters : AxiStreamMasterArray(1 downto 0);
   signal obUdpSlaves  : AxiStreamSlaveArray(1 downto 0);

begin

   assert ((SERVER_EN_G = true) or (CLIENT_EN_G = true)) report
      "UdpEngine: Either SERVER_EN_G or CLIENT_EN_G must be true" severity failure;

   U_UdpEngineRx : entity work.UdpEngineRx
      generic map (
         TPD_G               => TPD_G,
         MAX_DATAGRAM_SIZE_G => MAX_DATAGRAM_SIZE_G,
         RX_FORWARD_EOFE_G   => RX_FORWARD_EOFE_G,
         SERVER_EN_G         => SERVER_EN_G,
         SERVER_SIZE_G       => SERVER_SIZE_G,
         SERVER_PORTS_G      => SERVER_PORTS_G,
         CLIENT_EN_G         => CLIENT_EN_G,
         CLIENT_SIZE_G       => CLIENT_SIZE_G,
         CLIENT_PORTS_G      => CLIENT_PORTS_G) 
      port map (
         -- Interface to IPV4 Engine  
         ibUdpMaster      => ibUdpMaster,
         ibUdpSlave       => ibUdpSlave,
         -- Interface to UDP Server engine(s)
         serverRemotePort => serverRemotePort,
         serverRemoteIp   => serverRemoteIp,
         serverRemoteMac  => serverRemoteMac,
         obServerMasters  => obServerMasters,
         obServerSlaves   => obServerSlaves,
         -- Interface to UDP Client engine(s)
         clientRemoteDet  => clientRemoteDet,
         obClientMasters  => obClientMasters,
         obClientSlaves   => obClientSlaves,
         -- Clock and Reset
         clk              => clk,
         rst              => rst); 

   GEN_SERVER : if (SERVER_EN_G = true) generate
      
      GEN_VEC :
      for i in (SERVER_SIZE_G-1) downto 0 generate
         U_UdpEngineTx : entity work.UdpEngineTx
            generic map (
               TPD_G               => TPD_G,
               MAX_DATAGRAM_SIZE_G => MAX_DATAGRAM_SIZE_G,
               TX_FORWARD_EOFE_G   => TX_FORWARD_EOFE_G,
               PORT_G              => SERVER_PORTS_G(i))    
            port map (
               -- Interface to IPV4 Engine  
               obUdpMaster => serverMasters(i),
               obUdpSlave  => serverSlaves(i),
               -- Interface to User Application
               localIp     => localIp,
               remotePort  => serverRemotePort(i),
               remoteIp    => serverRemoteIp(i),
               remoteMac   => serverRemoteMac(i),
               ibMaster    => ibServerMasters(i),
               ibSlave     => ibServerSlaves(i),
               -- Clock and Reset
               clk         => clk,
               rst         => rst);
      end generate GEN_VEC;

      SINGLE_SERVER : if (SERVER_SIZE_G = 1) generate
         obUdpMasters(0) <= serverMasters(0);
         serverSlaves(0) <= obUdpSlaves(0);
      end generate;

      MULTI_SERVER : if (SERVER_SIZE_G > 1) generate
         U_AxiStreamMux : entity work.AxiStreamMux
            generic map (
               TPD_G         => TPD_G,
               NUM_SLAVES_G  => SERVER_SIZE_G,
               PIPE_STAGES_G => 2)      -- mux be > 1 if cascading muxes
            port map (
               -- Clock and reset
               axisClk      => clk,
               axisRst      => rst,
               -- Slaves
               sAxisMasters => serverMasters,
               sAxisSlaves  => serverSlaves,
               -- Master
               mAxisMaster  => obUdpMasters(0),
               mAxisSlave   => obUdpSlaves(0)); 
      end generate;
      
   end generate;

   GEN_CLIENT : if (CLIENT_EN_G = true) generate
      
      U_UdpEngineArp : entity work.UdpEngineArp
         generic map (
            TPD_G             => TPD_G,
            CLIENT_SIZE_G     => CLIENT_SIZE_G,
            CLK_FREQ_G        => CLK_FREQ_G,
            COMM_TIMEOUT_EN_G => COMM_TIMEOUT_EN_G,
            COMM_TIMEOUT_G    => COMM_TIMEOUT_G) 
         port map (
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

      GEN_VEC :
      for i in (CLIENT_SIZE_G-1) downto 0 generate
         U_UdpEngineTx : entity work.UdpEngineTx
            generic map (
               TPD_G               => TPD_G,
               MAX_DATAGRAM_SIZE_G => MAX_DATAGRAM_SIZE_G,
               TX_FORWARD_EOFE_G   => TX_FORWARD_EOFE_G,
               PORT_G              => CLIENT_PORTS_G(i))    
            port map (
               -- Interface to IPV4 Engine  
               obUdpMaster => clientMasters(i),
               obUdpSlave  => clientSlaves(i),
               -- Interface to User Application
               localIp     => localIp,
               remotePort  => clientRemotePort(i),
               remoteIp    => clientRemoteIp(i),
               remoteMac   => clientRemoteMac(i),
               ibMaster    => ibClientMasters(i),
               ibSlave     => ibClientSlaves(i),
               -- Clock and Reset
               clk         => clk,
               rst         => rst);
      end generate GEN_VEC;

      SINGLE_CLIENT : if (CLIENT_SIZE_G = 1) generate
         obUdpMasters(1) <= clientMasters(0);
         clientSlaves(0) <= obUdpSlaves(1);
      end generate;

      MULTI_CLIENT : if (CLIENT_SIZE_G > 1) generate
         U_AxiStreamMux : entity work.AxiStreamMux
            generic map (
               TPD_G         => TPD_G,
               NUM_SLAVES_G  => CLIENT_SIZE_G,
               PIPE_STAGES_G => 2)      -- mux be > 1 if cascading muxes
            port map (
               -- Clock and reset
               axisClk      => clk,
               axisRst      => rst,
               -- Slaves
               sAxisMasters => clientMasters,
               sAxisSlaves  => clientSlaves,
               -- Master
               mAxisMaster  => obUdpMasters(1),
               mAxisSlave   => obUdpSlaves(1)); 
      end generate;
      
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
      obUdpMaster     <= obUdpMasters(0);
      obUdpSlaves(0)  <= obUdpSlave;
      -- Terminated the client buses
      ibClientSlaves  <= (others => AXI_STREAM_SLAVE_FORCE_C);
      obUdpMasters(1) <= AXI_STREAM_MASTER_INIT_C;
      arpReqMasters   <= (others => AXI_STREAM_MASTER_INIT_C);
      arpAckSlaves    <= (others => AXI_STREAM_SLAVE_FORCE_C);
      clientRemoteMac <= (others => (others => '0'));
   end generate;

   NO_SERVER : if ((SERVER_EN_G = false) and (CLIENT_EN_G = true)) generate
      -- Pass the client buses
      obUdpMaster     <= obUdpMasters(1);
      obUdpSlaves(1)  <= obUdpSlave;
      -- Terminated the server buses
      ibServerSlaves  <= (others => AXI_STREAM_SLAVE_FORCE_C);
      obUdpMasters(0) <= AXI_STREAM_MASTER_INIT_C;
   end generate;
   
end mapping;
