-------------------------------------------------------------------------------
-- File       : UdpEngineRx.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-20
-- Last update: 2016-09-16
-------------------------------------------------------------------------------
-- Description: UDP RX Engine Module
-- Note: UDP checksum checked in EthMac core
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
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.EthMacPkg.all;

entity UdpEngineRx is
   generic (
      -- Simulation Generics
      TPD_G          : time          := 1 ns;
      -- UDP General Generic
      DHCP_G         : boolean       := false;
      -- UDP Server Generics
      SERVER_EN_G    : boolean       := true;
      SERVER_SIZE_G  : positive      := 1;
      SERVER_PORTS_G : PositiveArray := (0 => 8192);
      -- UDP Client Generics
      CLIENT_EN_G    : boolean       := true;
      CLIENT_SIZE_G  : positive      := 1;
      CLIENT_PORTS_G : PositiveArray := (0 => 8193));
   port (
      -- Local Configurations
      localIp          : in  slv(31 downto 0);  --  big-Endian configuration      
      -- Interface to IPV4 Engine  
      ibUdpMaster      : in  AxiStreamMasterType;
      ibUdpSlave       : out AxiStreamSlaveType;
      -- Interface to UDP Server engine(s)
      serverRemotePort : out Slv16Array(SERVER_SIZE_G-1 downto 0);
      serverRemoteIp   : out Slv32Array(SERVER_SIZE_G-1 downto 0);
      serverRemoteMac  : out Slv48Array(SERVER_SIZE_G-1 downto 0);
      obServerMasters  : out AxiStreamMasterArray(SERVER_SIZE_G-1 downto 0);
      obServerSlaves   : in  AxiStreamSlaveArray(SERVER_SIZE_G-1 downto 0);
      -- Interface to UDP Client engine(s)
      clientRemoteDet  : out slv(CLIENT_SIZE_G-1 downto 0);
      obClientMasters  : out AxiStreamMasterArray(CLIENT_SIZE_G-1 downto 0);
      obClientSlaves   : in  AxiStreamSlaveArray(CLIENT_SIZE_G-1 downto 0);
      -- Interface to DHCP Engine
      ibDhcpMaster     : out AxiStreamMasterType;
      ibDhcpSlave      : in  AxiStreamSlaveType;
      -- Clock and Reset
      clk              : in  sl;
      rst              : in  sl);
end UdpEngineRx;

architecture rtl of UdpEngineRx is

   constant SERVER_PORTS_C : Slv16Array(SERVER_SIZE_G-1 downto 0) := EthPortArrayBigEndian(SERVER_PORTS_G, SERVER_SIZE_G);
   constant CLIENT_PORTS_C : Slv16Array(CLIENT_SIZE_G-1 downto 0) := EthPortArrayBigEndian(CLIENT_PORTS_G, CLIENT_SIZE_G);
   
   type RouteType is (
      NULL_S,
      SERVER_S,
      CLIENT_S,
      DHCP_S);   

   type StateType is (
      IDLE_S,
      CHECK_PORT_S,
      MOVE_S,
      LAST_S);

   type RegType is record
      serverRemotePort : Slv16Array(SERVER_SIZE_G-1 downto 0);
      serverRemoteIp   : Slv32Array(SERVER_SIZE_G-1 downto 0);
      serverRemoteMac  : Slv48Array(SERVER_SIZE_G-1 downto 0);
      clientRemoteDet  : slv(CLIENT_SIZE_G-1 downto 0);
      byteCnt          : slv(15 downto 0);
      tData            : slv(127 downto 0);
      sof              : sl;
      route            : RouteType;
      rxSlave          : AxiStreamSlaveType;
      dhcpMaster       : AxiStreamMasterType;
      serverMaster     : AxiStreamMasterType;
      clientMaster     : AxiStreamMasterType;
      state            : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      serverRemotePort => (others => (others => '0')),
      serverRemoteIp   => (others => (others => '0')),
      serverRemoteMac  => (others => (others => '0')),
      clientRemoteDet  => (others => '0'),
      byteCnt          => (others => '0'),
      tData            => (others => '0'),
      sof              => '1',
      route            => NULL_S,
      rxSlave          => AXI_STREAM_SLAVE_INIT_C,
      dhcpMaster       => AXI_STREAM_MASTER_INIT_C,
      serverMaster     => AXI_STREAM_MASTER_INIT_C,
      clientMaster     => AXI_STREAM_MASTER_INIT_C,
      state            => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxMaster : AxiStreamMasterType;
   signal rxSlave  : AxiStreamSlaveType;

   signal serverSlave : AxiStreamSlaveType;
   signal clientSlave : AxiStreamSlaveType;
   signal dhcpSlave   : AxiStreamSlaveType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "TRUE";

begin

   U_RxPipeline : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 0)
      port map (
         axisClk     => clk,
         axisRst     => rst,
         sAxisMaster => ibUdpMaster,
         sAxisSlave  => ibUdpSlave,
         mAxisMaster => rxMaster,
         mAxisSlave  => rxSlave);

   comb : process (clientSlave, dhcpSlave, localIp, r, rst, rxMaster, serverSlave) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.clientRemoteDet := (others => '0');
      v.rxSlave         := AXI_STREAM_SLAVE_INIT_C;
      if serverSlave.tReady = '1' then
         v.serverMaster.tValid := '0';
         v.serverMaster.tLast  := '0';
         v.serverMaster.tUser  := (others => '0');
         v.serverMaster.tKeep  := (others => '1');
      end if;
      if clientSlave.tReady = '1' then
         v.clientMaster.tValid := '0';
         v.clientMaster.tLast  := '0';
         v.clientMaster.tUser  := (others => '0');
         v.clientMaster.tKeep  := (others => '1');
      end if;
      if (dhcpSlave.tReady) = '1' then
         v.dhcpMaster.tValid := '0';
         v.dhcpMaster.tLast  := '0';
         v.dhcpMaster.tUser  := (others => '0');
         v.dhcpMaster.tKeep  := (others => '1');
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for data
            if (rxMaster.tValid = '1') then
               -- Accept the data
               v.rxSlave.tReady := '1';
               -- Check for SOF with no EOF
               if (ssiGetUserSof(EMAC_AXIS_CONFIG_C, rxMaster) = '1') and (rxMaster.tLast = '0') then
                  -- Latch the first header
                  v.tData := rxMaster.tData;
                  -- Next state
                  v.state := CHECK_PORT_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when CHECK_PORT_S =>
            -- Check for data
            if (rxMaster.tValid = '1') then
               -- Accept the data
               v.rxSlave.tReady := '1';
               -- Set default route type
               v.route          := NULL_S;
               ------------------------------------------------
               -- Notes: Non-Standard IPv4 Pseudo Header Format
               ------------------------------------------------
               -- tData[0][47:0]   = Remote MAC Address
               -- tData[0][63:48]  = zeros
               -- tData[0][95:64]  = Remote IP Address 
               -- tData[0][127:96] = Local IP address
               -- tData[1][7:0]    = zeros
               -- tData[1][15:8]   = Protocol Type = UDP
               -- tData[1][31:16]  = IPv4 Pseudo header length
               -- tData[1][47:32]  = Remote Port
               -- tData[1][63:48]  = Local Port
               -- tData[1][79:64]  = UDP Length
               -- tData[1][95:80]  = UDP Checksum 
               -- tData[1][127:96] = UDP Datagram 
               ------------------------------------------------               
               -- Check the IP port 
               if (r.tData(127 downto 96) = localIp) then
                  -- Check if server engine(s) is enabled
                  if (SERVER_EN_G = true) then
                     for i in (SERVER_SIZE_G-1) downto 0 loop
                        -- Check if port is defined
                        if (v.route = NULL_S) and (rxMaster.tData(63 downto 48) = SERVER_PORTS_C(i)) then
                           v.route               := SERVER_S;
                           v.serverMaster.tDest  := toSlv(i, 8);
                           v.serverRemotePort(i) := rxMaster.tData(47 downto 32);
                           v.serverRemoteIp(i)   := r.tData(95 downto 64);
                           v.serverRemoteMac(i)  := r.tData(47 downto 0);
                        end if;
                     end loop;
                  end if;
                  -- Check if clients engine(s) is enabled
                  if (CLIENT_EN_G = true) then
                     for i in (CLIENT_SIZE_G-1) downto 0 loop
                        -- Check if port is defined
                        if (v.route = NULL_S) and (rxMaster.tData(63 downto 48) = CLIENT_PORTS_C(i)) then
                           v.route              := CLIENT_S;
                           v.clientMaster.tDest := toSlv(i, 8);
                           v.clientRemoteDet(i) := '1';
                        end if;
                     end loop;
                  end if;
               end if;
               -- Check if DHCP engine is enabled and DHCP packet
               if (DHCP_G = true) and (rxMaster.tData(47 downto 32) = DHCP_SPORT) and (rxMaster.tData(63 downto 48) = DHCP_CPORT) then
                  v.route := DHCP_S;
               end if;
               -- Get the UDP length = UDP HDR + UDP data
               v.byteCnt(15 downto 8) := rxMaster.tData(71 downto 64);
               v.byteCnt(7 downto 0)  := rxMaster.tData(79 downto 72);
               -- Remove the 8 byte UDP header
               v.byteCnt              := v.byteCnt - 8;
               -- Track the leftovers
               v.tData(31 downto 0)   := rxMaster.tData(127 downto 96);
               -- Set the flag
               v.sof                  := '1';
               -- Check for non-NULL route type
               if (v.route /= NULL_S) then
                  -- Check for leftovers
                  if (rxMaster.tLast = '1') or (v.byteCnt <= 4) then
                     -- Next state
                     v.state := LAST_S;
                  else
                     -- Next state
                     v.state := MOVE_S;
                  end if;
               else
                  -- Next state
                  v.state := IDLE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check the route type
            case r.route is
               ----------------------------------------------------------------------
               when SERVER_S =>
                  -- Check if ready to move data
                  if (rxMaster.tValid = '1') and (v.serverMaster.tValid = '0') then
                     -- Accept the data
                     v.rxSlave.tReady                        := '1';
                     -- Move the data
                     v.serverMaster.tValid                   := '1';
                     v.serverMaster.tData(31 downto 0)       := r.tData(31 downto 0);
                     v.serverMaster.tData(127 downto 32)     := rxMaster.tData(95 downto 0);
                     ssiSetUserSof(EMAC_AXIS_CONFIG_C, v.serverMaster, r.sof);
                     -- Track the leftovers                                 
                     v.tData(31 downto 0)                    := rxMaster.tData(127 downto 96);
                     -- Reset the flag
                     v.sof                                   := '0';
                     -- Decrement the counter
                     v.byteCnt                               := r.byteCnt - 16;
                     -- Check for tLast or the byte counter
                     if (rxMaster.tLast = '1') or (r.byteCnt <= 16) or (v.byteCnt <= 4) then
                        -- Check for leftovers
                        if (v.byteCnt <= 4) and (r.byteCnt /= 16) then
                           -- Next state
                           v.state := LAST_S;
                        else
                           -- Terminate the packet
                           v.serverMaster.tKeep := genTKeep(conv_integer(r.byteCnt));
                           v.serverMaster.tLast := '1';
                           -- Next state
                           v.state              := IDLE_S;
                        end if;
                     end if;
                  end if;
               ----------------------------------------------------------------------
               when CLIENT_S =>
                  -- Check if ready to move data
                  if (rxMaster.tValid = '1') and (v.clientMaster.tValid = '0') then
                     -- Accept the data
                     v.rxSlave.tReady                        := '1';
                     -- Move the data
                     v.clientMaster.tValid                   := '1';
                     v.clientMaster.tData(31 downto 0)       := r.tData(31 downto 0);
                     v.clientMaster.tData(127 downto 32)     := rxMaster.tData(95 downto 0);
                     ssiSetUserSof(EMAC_AXIS_CONFIG_C, v.clientMaster, r.sof);
                     -- Track the leftovers                                 
                     v.tData(31 downto 0)                    := rxMaster.tData(127 downto 96);
                     -- Reset the flag
                     v.sof                                   := '0';
                     -- Decrement the counter
                     v.byteCnt                               := r.byteCnt - 16;
                     -- Check for tLast or the byte counter
                     if (rxMaster.tLast = '1') or (r.byteCnt <= 16) or (v.byteCnt <= 4) then
                        -- Check for leftovers
                        if (v.byteCnt <= 4) and (r.byteCnt /= 16) then
                           -- Next state
                           v.state := LAST_S;
                        else
                           -- Terminate the packet
                           v.clientMaster.tKeep := genTKeep(conv_integer(r.byteCnt));
                           v.clientMaster.tLast := '1';
                           -- Next state
                           v.state              := IDLE_S;
                        end if;
                     end if;
                  end if;
               ----------------------------------------------------------------------
               when DHCP_S =>
                  -- Check if ready to move data
                  if (rxMaster.tValid = '1') and (v.dhcpMaster.tValid = '0') then
                     -- Accept the data
                     v.rxSlave.tReady                        := '1';
                     -- Move the data
                     v.dhcpMaster.tValid                     := '1';
                     v.dhcpMaster.tData(31 downto 0)         := r.tData(31 downto 0);
                     v.dhcpMaster.tData(127 downto 32)       := rxMaster.tData(95 downto 0);
                     ssiSetUserSof(EMAC_AXIS_CONFIG_C, v.dhcpMaster, r.sof);
                     -- Track the leftovers                                 
                     v.tData(31 downto 0)                    := rxMaster.tData(127 downto 96);
                     -- Reset the flag
                     v.sof                                   := '0';
                     -- Decrement the counter
                     v.byteCnt                               := r.byteCnt - 16;
                     -- Check for tLast or the byte counter
                     if (rxMaster.tLast = '1') or (r.byteCnt <= 16) or (v.byteCnt <= 4) then
                        -- Check for leftovers
                        if (v.byteCnt <= 4) and (r.byteCnt /= 16) then
                           -- Next state
                           v.state := LAST_S;
                        else
                           -- Terminate the packet
                           v.dhcpMaster.tKeep := genTKeep(conv_integer(r.byteCnt));
                           v.dhcpMaster.tLast := '1';
                           -- Next state
                           v.state            := IDLE_S;
                        end if;
                     end if;
                  end if;
               ----------------------------------------------------------------------
               when NULL_S =>
                  -- Next state
                  v.state := IDLE_S;
            ----------------------------------------------------------------------
            end case;
         ----------------------------------------------------------------------
         when LAST_S =>
            -- Check the route type
            case r.route is
               ----------------------------------------------------------------------
               when SERVER_S =>
                  -- Check if ready to move data
                  if (v.serverMaster.tValid = '0') then
                     -- Move the data
                     v.serverMaster.tValid := '1';
                     v.serverMaster.tData  := r.tData;
                     v.serverMaster.tKeep  := genTKeep(conv_integer(r.byteCnt));
                     v.serverMaster.tLast  := '1';
                     ssiSetUserSof(EMAC_AXIS_CONFIG_C, v.serverMaster, r.sof);
                     -- Next state
                     v.state               := IDLE_S;
                  end if;
               ----------------------------------------------------------------------
               when CLIENT_S =>
                  -- Check if ready to move data
                  if (v.clientMaster.tValid = '0') then
                     -- Move the data
                     v.clientMaster.tValid := '1';
                     v.clientMaster.tData  := r.tData;
                     v.clientMaster.tKeep  := genTKeep(conv_integer(r.byteCnt));
                     v.clientMaster.tLast  := '1';
                     ssiSetUserSof(EMAC_AXIS_CONFIG_C, v.clientMaster, r.sof);
                     -- Next state
                     v.state               := IDLE_S;
                  end if;
               ----------------------------------------------------------------------
               when DHCP_S =>
                  -- Check if ready to move data
                  if (v.dhcpMaster.tValid = '0') then
                     -- Move the data
                     v.dhcpMaster.tValid := '1';
                     v.dhcpMaster.tData  := r.tData;
                     v.dhcpMaster.tKeep  := genTKeep(conv_integer(r.byteCnt));
                     v.dhcpMaster.tLast  := '1';
                     ssiSetUserSof(EMAC_AXIS_CONFIG_C, v.dhcpMaster, r.sof);
                     -- Next state
                     v.state             := IDLE_S;
                  end if;
               ----------------------------------------------------------------------
               when NULL_S =>
                  -- Next state
                  v.state := IDLE_S;
            ----------------------------------------------------------------------
            end case;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      serverRemotePort <= r.serverRemotePort;
      serverRemoteIp   <= r.serverRemoteIp;
      serverRemoteMac  <= r.serverRemoteMac;
      clientRemoteDet  <= r.clientRemoteDet;
      rxSlave          <= v.rxSlave;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_Servers : entity work.AxiStreamDeMux
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 1,
         NUM_MASTERS_G => SERVER_SIZE_G)
      port map (
         -- Clock and reset
         axisClk      => clk,
         axisRst      => rst,
         -- Slave         
         sAxisMaster  => r.serverMaster,
         sAxisSlave   => serverSlave,
         -- Masters
         mAxisMasters => obServerMasters,
         mAxisSlaves  => obServerSlaves);  

   U_Clients : entity work.AxiStreamDeMux
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 1,
         NUM_MASTERS_G => CLIENT_SIZE_G)
      port map (
         -- Clock and reset
         axisClk      => clk,
         axisRst      => rst,
         -- Slave         
         sAxisMaster  => r.clientMaster,
         sAxisSlave   => clientSlave,
         -- Masters
         mAxisMasters => obClientMasters,
         mAxisSlaves  => obClientSlaves);           

   U_Dhcp : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 0)
      port map (
         axisClk     => clk,
         axisRst     => rst,
         sAxisMaster => r.dhcpMaster,
         sAxisSlave  => dhcpSlave,
         mAxisMaster => ibDhcpMaster,
         mAxisSlave  => ibDhcpSlave);      

end rtl;
