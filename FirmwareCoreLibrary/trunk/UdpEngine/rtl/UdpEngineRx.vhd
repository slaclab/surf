-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : UdpEngineRx.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-20
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.IpV4EnginePkg.all;
use work.UdpEnginePkg.all;

entity UdpEngineRx is
   generic (
      -- Simulation Generics
      TPD_G               : time         := 1 ns;
      SIM_ERROR_HALT_G    : boolean      := false;
      -- UDP General Generic
      MAX_DATAGRAM_SIZE_G : positive     := 1472;
      RX_FORWARD_EOFE_G   : boolean      := false;
      -- UDP Server Generics
      SERVER_EN_G         : boolean      := true;
      SERVER_SIZE_G       : positive     := 1;
      SERVER_PORTS_G      : NaturalArray := (0 => 8192);
      -- UDP Client Generics
      CLIENT_EN_G         : boolean      := true;
      CLIENT_SIZE_G       : positive     := 1;
      CLIENT_PORTS_G      : NaturalArray := (0 => 8193));
   port (
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
      -- Clock and Reset
      clk              : in  sl;
      rst              : in  sl);
end UdpEngineRx;

architecture rtl of UdpEngineRx is

   -- Add a padding of 128 bytes to prevent buffer backpressuring
   -- Divide by 16 because 16 bytes per 128-bit word
   constant FIFO_ADDR_SIZE_C  : natural  := (MAX_DATAGRAM_SIZE_G+128)/16;
   constant FIFO_ADDR_WIDTH_C : positive := bitSize(FIFO_ADDR_SIZE_C-1);
   constant UDP_HDR_OFFSET_C  : positive := 8;

   type StateType is (
      IDLE_S,
      CHECK_PORT_S,
      BUFFER_S,
      ERROR_CHECKING_S,
      LAST_S,
      SERVER_MOVE_S,
      CLIENT_MOVE_S); 

   type RegType is record
      flushBuffer      : sl;
      udpPortDet       : sl;
      eofe             : sl;
      rxByteCnt        : natural range 0 to FIFO_ADDR_SIZE_C;
      serverRemotePort : Slv16Array(SERVER_SIZE_G-1 downto 0);
      serverRemoteIp   : Slv32Array(SERVER_SIZE_G-1 downto 0);
      serverRemoteMac  : Slv48Array(SERVER_SIZE_G-1 downto 0);
      clientRemoteDet  : slv(CLIENT_SIZE_G-1 downto 0);
      ipv4Length       : slv(15 downto 0);
      sPorts           : Slv16Array(SERVER_SIZE_G-1 downto 0);
      serverPorts      : Slv16Array(SERVER_SIZE_G-1 downto 0);
      cPorts           : Slv16Array(CLIENT_SIZE_G-1 downto 0);
      clientPorts      : Slv16Array(CLIENT_SIZE_G-1 downto 0);
      tKeepMask        : slv(15 downto 0);
      tKeep            : slv(15 downto 0);
      tData            : slv(127 downto 0);
      tLast            : sl;
      sum0             : Slv32Array(3 downto 0);
      sum1             : Slv32Array(1 downto 0);
      sum2             : slv(31 downto 0);
      accum            : slv(31 downto 0);
      cnt              : natural range 0 to 5;
      ibValid          : sl;
      ibChecksum       : slv(15 downto 0);
      checksum         : slv(15 downto 0);
      udpLength        : slv(15 downto 0);
      destSel          : sl;
      serverId         : natural range 0 to SERVER_SIZE_G-1;
      clientId         : natural range 0 to CLIENT_SIZE_G-1;
      rxSlave          : AxiStreamSlaveType;
      mSlave           : AxiStreamSlaveType;
      sMaster          : AxiStreamMasterType;
      obServerMasters  : AxiStreamMasterArray(SERVER_SIZE_G-1 downto 0);
      obClientMasters  : AxiStreamMasterArray(CLIENT_SIZE_G-1 downto 0);
      state            : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      flushBuffer      => '1',
      udpPortDet       => '0',
      eofe             => '0',
      rxByteCnt        => UDP_HDR_OFFSET_C,
      serverRemotePort => (others => (others => '0')),
      serverRemoteIp   => (others => (others => '0')),
      serverRemoteMac  => (others => (others => '0')),
      clientRemoteDet  => (others => '0'),
      ipv4Length       => (others => '0'),
      sPorts           => (others => (others => '0')),
      serverPorts      => (others => (others => '0')),
      cPorts           => (others => (others => '0')),
      clientPorts      => (others => (others => '0')),
      tKeepMask        => (others => '0'),
      tKeep            => (others => '0'),
      tData            => (others => '0'),
      tLast            => '0',
      sum0             => (others => (others => '0')),
      sum1             => (others => (others => '0')),
      sum2             => (others => '0'),
      accum            => (others => '0'),
      cnt              => 0,
      ibValid          => '0',
      ibChecksum       => (others => '0'),
      checksum         => (others => '0'),
      udpLength        => (others => '0'),
      destSel          => '0',
      serverId         => 0,
      clientId         => 0,
      rxSlave          => AXI_STREAM_SLAVE_INIT_C,
      mSlave           => AXI_STREAM_SLAVE_INIT_C,
      sMaster          => AXI_STREAM_MASTER_INIT_C,
      obServerMasters  => (others => AXI_STREAM_MASTER_INIT_C),
      obClientMasters  => (others => AXI_STREAM_MASTER_INIT_C),
      state            => IDLE_S);      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxMaster : AxiStreamMasterType;
   signal rxSlave  : AxiStreamSlaveType;
   signal sMaster  : AxiStreamMasterType;
   signal sSlave   : AxiStreamSlaveType;
   signal mMaster  : AxiStreamMasterType;
   signal mSlave   : AxiStreamSlaveType;

   -- attribute dont_touch             : string;
   -- attribute dont_touch of r        : signal is "TRUE";
   -- attribute dont_touch of rxMaster : signal is "TRUE";
   -- attribute dont_touch of rxSlave  : signal is "TRUE";   
   -- attribute dont_touch of sMaster  : signal is "TRUE";
   -- attribute dont_touch of sSlave   : signal is "TRUE";
   -- attribute dont_touch of mMaster  : signal is "TRUE";
   -- attribute dont_touch of mSlave   : signal is "TRUE";
   
begin

   FIFO_RX : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 0,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => true,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => (FIFO_ADDR_WIDTH_C+1),  -- 2x bigger than DATAGRAM_BUFFER
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => IP_ENGINE_CONFIG_C,
         MASTER_AXI_CONFIG_G => IP_ENGINE_CONFIG_C)            
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => ibUdpMaster,
         sAxisSlave  => ibUdpSlave,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => rxMaster,
         mAxisSlave  => rxSlave);

   DATAGRAM_BUFFER : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 0,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => true,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_C,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => IP_ENGINE_CONFIG_C,
         MASTER_AXI_CONFIG_G => IP_ENGINE_CONFIG_C)            
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => r.flushBuffer,
         sAxisMaster => sMaster,
         sAxisSlave  => sSlave,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => r.flushBuffer,
         mAxisMaster => mMaster,
         mAxisSlave  => mSlave);   

   comb : process (mMaster, obClientSlaves, obServerSlaves, r, rst, rxMaster, sSlave) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.flushBuffer     := '0';
      v.udpPortDet      := '0';
      v.clientRemoteDet := (others => '0');
      v.tKeepMask       := (others => '0');
      v.ipv4Length      := (others => '0');
      v.rxSlave         := AXI_STREAM_SLAVE_INIT_C;
      v.mSlave          := AXI_STREAM_SLAVE_INIT_C;
      if sSlave.tReady = '1' then
         v.sMaster.tValid := '0';
         v.sMaster.tLast  := '0';
         v.sMaster.tUser  := (others => '0');
         v.sMaster.tKeep  := (others => '1');
      end if;
      for i in SERVER_SIZE_G-1 downto 0 loop
         if obServerSlaves(i).tReady = '1' then
            v.obServerMasters(i).tValid := '0';
            v.obServerMasters(i).tLast  := '0';
            v.obServerMasters(i).tUser  := (others => '0');
            v.obServerMasters(i).tKeep  := (others => '1');
         end if;
      end loop;
      for i in CLIENT_SIZE_G-1 downto 0 loop
         if obClientSlaves(i).tReady = '1' then
            v.obClientMasters(i).tValid := '0';
            v.obClientMasters(i).tLast  := '0';
            v.obClientMasters(i).tUser  := (others => '0');
            v.obClientMasters(i).tKeep  := (others => '1');
         end if;
      end loop;

      -- Convert the NaturalArray into Slv48Array
      for i in SERVER_SIZE_G-1 downto 0 loop
         v.serverPorts(i)         := toSlv(SERVER_PORTS_G(i), 16);
         -- Convert to big endian
         v.sPorts(i)(15 downto 8) := v.serverPorts(i)(7 downto 0);
         v.sPorts(i)(7 downto 0)  := v.serverPorts(i)(15 downto 8);
      end loop;
      for i in CLIENT_SIZE_G-1 downto 0 loop
         v.clientPorts(i)         := toSlv(CLIENT_PORTS_G(i), 16);
         -- Convert to big endian
         v.cPorts(i)(15 downto 8) := v.clientPorts(i)(7 downto 0);
         v.cPorts(i)(7 downto 0)  := v.clientPorts(i)(15 downto 8);
      end loop;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset flags/accumulators
            v.flushBuffer := '1';
            v.eofe        := '0';
            v.rxByteCnt   := UDP_HDR_OFFSET_C;
            v.sum0        := (others => (others => '0'));
            v.sum1        := (others => (others => '0'));
            v.sum2        := (others => '0');
            v.accum       := (others => '0');
            -- Check for data and accumulator has reseted
            if (rxMaster.tValid = '1') and (r.accum = 0) and (r.flushBuffer = '1') then
               -- Accept the data
               v.rxSlave.tReady := '1';
               -- Check for SOF with no EOF
               if (ssiGetUserSof(IP_ENGINE_CONFIG_C, rxMaster) = '1') and (rxMaster.tLast = '0') then
                  -- Latch the first header
                  v.tData := rxMaster.tData;
                  -- Process checksum
                  GetUdpChecksum (
                     -- Inbound tKeep and tData
                     x"FF00",           -- Only use the source and destination IP address
                     rxMaster.tData,    -- tData
                     -- Summation Signals
                     r.sum0, v.sum0,
                     r.sum1, v.sum1,
                     r.sum2, v.sum2,
                     r.accum, v.accum,
                     -- Checksum generation and comparsion
                     v.ibValid,
                     r.ibChecksum,
                     v.checksum);                   
                  -- Next state
                  v.state := CHECK_PORT_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when CHECK_PORT_S =>
            -- Check for data
            if (rxMaster.tValid = '1') then
               -- Accept the data
               v.rxSlave.tReady          := '1';
               -- Latch the length value (in little endian)
               v.ipv4Length(15 downto 8) := rxMaster.tData(23 downto 16);
               v.ipv4Length(7 downto 0)  := rxMaster.tData(31 downto 24);
               v.udpLength(15 downto 8)  := rxMaster.tData(71 downto 64);
               v.udpLength(7 downto 0)   := rxMaster.tData(79 downto 72);
               -- Latch the checksum value (in little endian)
               v.ibChecksum(15 downto 8) := rxMaster.tData(87 downto 80);
               v.ibChecksum(7 downto 0)  := rxMaster.tData(95 downto 88);
               -- Track the leftovers
               v.tData(31 downto 0)      := rxMaster.tData(127 downto 96);
               v.tData(127 downto 32)    := (others => '0');
               v.tKeep(3 downto 0)       := rxMaster.tKeep(15 downto 12);
               v.tKeep(15 downto 4)      := (others => '0');
               v.tLast                   := rxMaster.tLast;
               v.eofe                    := ssiGetUserEofe(IP_ENGINE_CONFIG_C, rxMaster);
               -- Mask off the inbound checksum data field
               v.tKeepMask(15 downto 12) := rxMaster.tKeep(15 downto 12);
               v.tKeepMask(11 downto 10) := (others => '0');
               v.tKeepMask(9 downto 0)   := rxMaster.tKeep(9 downto 0);
               -- Process checksum
               GetUdpChecksum (
                  -- Inbound tKeep and tData
                  v.tKeepMask,
                  rxMaster.tData,
                  -- Summation Signals
                  r.sum0, v.sum0,
                  r.sum1, v.sum1,
                  r.sum2, v.sum2,
                  r.accum, v.accum,
                  -- Checksum generation and comparsion
                  v.ibValid,
                  r.ibChecksum,
                  v.checksum);                
               -- Check if server engine(s) is enabled
               if (SERVER_EN_G = true) then
                  for i in SERVER_SIZE_G-1 downto 0 loop
                     -- Check if port is defined
                     if (v.udpPortDet = '0') and (rxMaster.tData(63 downto 48) = v.sPorts(i)) then
                        v.udpPortDet          := '1';
                        v.destSel             := '0';
                        v.serverId            := i;
                        v.serverRemotePort(i) := rxMaster.tData(47 downto 32);
                        v.serverRemoteIp(i)   := r.tData(95 downto 64);
                        v.serverRemoteMac(i)  := r.tData(47 downto 0);
                     end if;
                  end loop;
               end if;
               -- Check if clients engine(s) is enabled
               if (CLIENT_EN_G = true) then
                  for i in CLIENT_SIZE_G-1 downto 0 loop
                     -- Check if port is defined
                     if (v.udpPortDet = '0') and (rxMaster.tData(63 downto 48) = v.cPorts(i)) then
                        v.udpPortDet         := '1';
                        v.destSel            := '1';
                        v.clientId           := i;
                        v.clientRemoteDet(i) := '1';
                     end if;
                  end loop;
               end if;
               -- Check for the following errors
               if (v.udpPortDet = '0')  -- UDP port was not detected 
                             or (v.udpLength /= v.ipv4Length)  -- the IPv4 Pseudo length and UDP length mismatch 
                             or (v.udpLength = 0)              -- zero length detected
                             or (rxMaster.tData(15 downto 8) /= UDP_C)  -- Correct protocol
                             or (rxMaster.tData(7 downto 0) /= 0) then  -- IPv4 Pseudo doesn't have zero padding
                  v.eofe  := '1';
                  -- Next state
                  v.state := IDLE_S;
               else
                  -- Check for tLast
                  if v.tLast = '1' then
                     -- Check the leftover tKeep is not empty
                     if v.tKeep /= 0 then
                        -- Next state
                        v.state := LAST_S;
                     else
                        -- Next state
                        v.state := IDLE_S;
                     end if;
                  else
                     -- Next state
                     v.state := BUFFER_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when BUFFER_S =>
            -- Check for data
            if (rxMaster.tValid = '1') and (v.sMaster.tValid = '0') then
               -- Accept the data
               v.rxSlave.tReady := '1';
               -- Process checksum
               GetUdpChecksum (
                  -- Inbound tKeep and tData
                  rxMaster.tKeep,
                  rxMaster.tData,
                  -- Summation Signals
                  r.sum0, v.sum0,
                  r.sum1, v.sum1,
                  r.sum2, v.sum2,
                  r.accum, v.accum,
                  -- Checksum generation and comparsion
                  v.ibValid,
                  r.ibChecksum,
                  v.checksum);                 
               -- Move the data
               v.sMaster.tValid               := '1';
               v.sMaster.tData(31 downto 0)   := r.tData(31 downto 0);
               v.sMaster.tData(127 downto 32) := rxMaster.tData(95 downto 0);
               v.sMaster.tKeep(3 downto 0)    := r.tKeep(3 downto 0);
               v.sMaster.tKeep(15 downto 4)   := rxMaster.tKeep(11 downto 0);
               -- Track the leftovers                                 
               v.tData(31 downto 0)           := rxMaster.tData(127 downto 96);
               v.tKeep(3 downto 0)            := rxMaster.tKeep(15 downto 12);
               -- Check for SOF
               if r.rxByteCnt = UDP_HDR_OFFSET_C then
                  ssiSetUserSof(IP_ENGINE_CONFIG_C, v.sMaster, '1');
               end if;
               -- Track the number of bytes receivced
               v.rxByteCnt := r.rxByteCnt + getTKeep(v.sMaster.tKeep);
               -- Check for tLast
               if (rxMaster.tLast = '1') or (v.rxByteCnt > MAX_DATAGRAM_SIZE_G) then
                  -- Zero out unused data field
                  v.tData(127 downto 32) := (others => '0');
                  -- Update the EOFE bit
                  v.eofe                 := ssiGetUserEofe(IP_ENGINE_CONFIG_C, rxMaster);
                  -- Check for overflow
                  if (v.rxByteCnt > MAX_DATAGRAM_SIZE_G) then
                     v.eofe := '1';
                  end if;
                  -- Check the leftover tKeep is not empty
                  if v.tKeep /= 0 then
                     -- Next state
                     v.state := LAST_S;
                  else
                     v.sMaster.tLast := '1';
                     -- Next state
                     v.state         := ERROR_CHECKING_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when LAST_S =>
            -- Check for data
            if (v.sMaster.tValid = '0') then
               -- Move the data
               v.sMaster.tValid := '1';
               v.sMaster.tData  := r.tData;
               v.sMaster.tKeep  := r.tKeep;
               v.sMaster.tLast  := '1';
               -- Check for SOF
               if r.rxByteCnt = UDP_HDR_OFFSET_C then
                  ssiSetUserSof(IP_ENGINE_CONFIG_C, v.sMaster, '1');
               end if;
               -- Track the number of bytes receivced
               v.rxByteCnt := r.rxByteCnt + getTKeep(v.tKeep);
               -- Check for overflow
               if (v.rxByteCnt > MAX_DATAGRAM_SIZE_G) then
                  v.eofe := '1';
               end if;
               -- Process checksum
               GetUdpChecksum (
                  -- Inbound tKeep and tData
                  (others => '0'),      -- tKeep
                  (others => '0'),      -- tData
                  -- Summation Signals
                  r.sum0, v.sum0,
                  r.sum1, v.sum1,
                  r.sum2, v.sum2,
                  r.accum, v.accum,
                  -- Checksum generation and comparsion
                  v.ibValid,
                  r.ibChecksum,
                  v.checksum);                
               -- Next state
               v.state := ERROR_CHECKING_S;
            end if;
         ----------------------------------------------------------------------
         when ERROR_CHECKING_S =>
            -- Process checksum
            GetUdpChecksum (
               -- Inbound tKeep and tData
               (others => '0'),         -- tKeep
               (others => '0'),         -- tData
               -- Summation Signals
               r.sum0, v.sum0,
               r.sum1, v.sum1,
               r.sum2, v.sum2,
               r.accum, v.accum,
               -- Checksum generation and comparsion
               v.ibValid,
               r.ibChecksum,
               v.checksum);       
            -- Increment the counter
            v.cnt := r.cnt + 1;
            -- Check the counter
            if r.cnt = 3 then           -- Simulation Optimized to 3 Minimum (25AUG2015)
               -- Reset the counter
               v.cnt := 0;
               -- Check for checksum 
               -- Note: UDP's checksum = 0x0 is allowed in UDP
               if (r.ibChecksum /= 0) and (r.ibValid = '0') then
                  v.eofe := '1';
               end if;
               -- Check for errors
               if (v.eofe = '1') and (RX_FORWARD_EOFE_G = false) then
                  -- Next state
                  v.state := IDLE_S;
               else
                  -- Remove the header IPv4 and UDP header offset
                  v.udpLength := r.udpLength - UDP_HDR_OFFSET_C;
                  -- Select the data destination
                  if r.destSel = '0' then
                     -- Next state
                     v.state := SERVER_MOVE_S;
                  else
                     -- Next state
                     v.state := CLIENT_MOVE_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when SERVER_MOVE_S =>
            -- Check for data
            if (mMaster.tValid = '1') and (v.obServerMasters(r.serverId).tValid = '0') then
               -- Accept the data
               v.mSlave.tReady                          := '1';
               -- Move data
               v.obServerMasters(r.serverId)            := mMaster;
               -- Decrement the counter
               v.udpLength                              := r.udpLength - 16;
               -- Check for EOF
               if (mMaster.tLast = '1') or (r.udpLength <= 16) then
                  -- Update the tKeep
                  if (r.udpLength <= 16) then
                     v.obServerMasters(r.serverId).tKeep := genTKeep(conv_integer(r.udpLength));
                  end if;
                  -- Force the tLast
                  v.obServerMasters(r.serverId).tLast := '1';
                  -- Set EOFE
                  if r.eofe = '1' then
                     ssiSetUserEofe(IP_ENGINE_CONFIG_C, v.obServerMasters(r.serverId), '1');
                  end if;
                  -- Next state
                  v.state := IDLE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when CLIENT_MOVE_S =>
            -- Check for data
            if (mMaster.tValid = '1') and (v.obClientMasters(r.clientId).tValid = '0') then
               -- Accept the data
               v.mSlave.tReady                          := '1';
               -- Move data
               v.obClientMasters(r.clientId)            := mMaster;
               -- Decrement the counter
               v.udpLength                              := r.udpLength - 16;
               -- Check for EOF
               if (mMaster.tLast = '1') or (r.udpLength <= 16) then
                  -- Update the tKeep
                  if (r.udpLength <= 16) then
                     v.obClientMasters(r.clientId).tKeep := genTKeep(conv_integer(r.udpLength));
                  end if;
                  -- Force the tLast
                  v.obClientMasters(r.clientId).tLast := '1';
                  -- Set EOFE
                  if r.eofe = '1' then
                     ssiSetUserEofe(IP_ENGINE_CONFIG_C, v.obClientMasters(r.clientId), '1');
                  end if;
                  -- Next state
                  v.state := IDLE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Check the simulation error printing
      if SIM_ERROR_HALT_G and (r.eofe = '1') then
         report "UdpEngineRx: Error Detected" severity failure;
      end if;

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
      mSlave           <= v.mSlave;
      sMaster          <= r.sMaster;
      rxSlave          <= v.rxSlave;
      obServerMasters  <= r.obServerMasters;
      obClientMasters  <= r.obClientMasters;
      
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
