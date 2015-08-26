-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : ArpEngine.vhd
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.IpV4EnginePkg.all;

entity ArpEngine is
   generic (
      TPD_G         : time     := 1 ns;
      CLIENT_SIZE_G : positive := 1;
      ARP_TIMEOUT_G : positive := 156250000;
      VLAN_G        : boolean  := false);  
   port (
      -- Local Configuration
      localMac      : in  slv(47 downto 0);
      localIp       : in  slv(31 downto 0);
      -- Interface to Client Engine(s)
      arpReqMasters : in  AxiStreamMasterArray(CLIENT_SIZE_G-1 downto 0);  -- Request via IP address
      arpReqSlaves  : out AxiStreamSlaveArray(CLIENT_SIZE_G-1 downto 0);
      arpAckMasters : out AxiStreamMasterArray(CLIENT_SIZE_G-1 downto 0);  -- Respond with MAC address
      arpAckSlaves  : in  AxiStreamSlaveArray(CLIENT_SIZE_G-1 downto 0);
      -- Interface to Ethernet Frame MUX/DEMUX 
      ibArpMaster   : in  AxiStreamMasterType;
      ibArpSlave    : out AxiStreamSlaveType;
      obArpMaster   : out AxiStreamMasterType;
      obArpSlave    : in  AxiStreamSlaveType;
      -- Clock and Reset
      clk           : in  sl;
      rst           : in  sl);
end ArpEngine;

architecture rtl of ArpEngine is

   -- ARP Constants
   constant BROADCAST_MAC_C  : slv(47 downto 0) := (others => '1');
   constant HARDWWARE_TYPE_C : slv(15 downto 0) := x"0100";  -- HardwareType = ETH = 0x0001
   constant PROTOCOL_TYPE_C  : slv(15 downto 0) := x"0008";  -- ProtocolType = IP  = 0x0800
   constant HARDWWARE_LEN_C  : slv(7 downto 0)  := x"06";    -- HardwareLength = 6 (6 Bytes/MAC)
   constant PROTOCOL_LEN_C   : slv(7 downto 0)  := x"04";    -- ProtocolLength = 4 (6 Bytes/IP)
   constant ARP_REQ_C        : slv(15 downto 0) := x"0100";  -- OpCode = ARP Request  = 0x0001
   constant ARP_REPLY_C      : slv(15 downto 0) := x"0200";  -- OpCode = ARP Reply    = 0x0002

   type StateType is (
      IDLE_S,
      RX_S,
      CHECK_S,
      SCAN_S,
      TX_S); 

   type RegType is record
      cnt           : natural range 0 to 3;
      tData         : Slv128Array(2 downto 0);
      rxArpSlave    : AxiStreamSlaveType;
      txArpMaster   : AxiStreamMasterType;
      arpReqSlaves  : AxiStreamSlaveArray(CLIENT_SIZE_G-1 downto 0);
      arpAckMasters : AxiStreamMasterArray(CLIENT_SIZE_G-1 downto 0);
      arpTimers     : NaturalArray(CLIENT_SIZE_G-1 downto 0);
      reqCnt        : natural range 0 to CLIENT_SIZE_G-1;
      ackCnt        : natural range 0 to CLIENT_SIZE_G-1;
      state         : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      cnt           => 0,
      tData         => (others => (others => '0')),
      rxArpSlave    => AXI_STREAM_SLAVE_INIT_C,
      txArpMaster   => AXI_STREAM_MASTER_INIT_C,
      arpReqSlaves  => (others => AXI_STREAM_SLAVE_INIT_C),
      arpAckMasters => (others => AXI_STREAM_MASTER_INIT_C),
      arpTimers     => (others => 0),
      reqCnt        => 0,
      ackCnt        => 0,
      state         => IDLE_S);      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxArpMaster : AxiStreamMasterType;
   signal rxArpSlave  : AxiStreamSlaveType;
   signal txArpMaster : AxiStreamMasterType;
   signal txArpSlave  : AxiStreamSlaveType;
   
begin

   FIFO_RX : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 0,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => false,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 4,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => IP_ENGINE_CONFIG_C,
         MASTER_AXI_CONFIG_G => IP_ENGINE_CONFIG_C)            
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => ibArpMaster,
         sAxisSlave  => ibArpSlave,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => rxArpMaster,
         mAxisSlave  => rxArpSlave);

   comb : process (arpAckSlaves, arpReqMasters, localIp, localMac, r, rst, rxArpMaster, txArpSlave) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.rxArpSlave := AXI_STREAM_SLAVE_INIT_C;
      if txArpSlave.tReady = '1' then
         v.txArpMaster := AXI_STREAM_MASTER_INIT_C;
      end if;
      for i in CLIENT_SIZE_G-1 downto 0 loop
         v.arpReqSlaves(i) := AXI_STREAM_SLAVE_INIT_C;
         if arpAckSlaves(i).tReady = '1' then
            v.arpAckMasters(i) := AXI_STREAM_MASTER_INIT_C;
         end if;
      end loop;

      -- Update the timers
      for i in CLIENT_SIZE_G-1 downto 0 loop
         if r.arpTimers(i) /= 0 then
            -- Decrement the timers
            v.arpTimers(i) := r.arpTimers(i) - 1;
         end if;
      end loop;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the counter
            v.cnt := 0;
            -- Check for inbound data
            if (rxArpMaster.tValid = '1') then
               -- Next state
               v.state := RX_S;
            else
               -- Increment the counter
               if r.reqCnt = (CLIENT_SIZE_G-1) then
                  v.reqCnt := 0;
               else
                  v.reqCnt := r.reqCnt + 1;
               end if;
               -- Check the tValid and timer
               if (arpReqMasters(r.reqCnt).tValid = '1') and (r.arpTimers(r.reqCnt) = 0) then
                  -- Set the timer
                  v.arpTimers(r.reqCnt) := ARP_TIMEOUT_G;
                  ------------------------
                  -- Checking for non-VLAN
                  ------------------------
                  if (VLAN_G = false) then
                     v.tData(0)(47 downto 0)    := BROADCAST_MAC_C;
                     v.tData(0)(95 downto 48)   := localMac;
                     v.tData(0)(111 downto 96)  := ARP_TYPE_C;
                     v.tData(0)(127 downto 112) := HARDWWARE_TYPE_C;
                     v.tData(1)(15 downto 0)    := PROTOCOL_TYPE_C;
                     v.tData(1)(23 downto 16)   := HARDWWARE_LEN_C;
                     v.tData(1)(31 downto 24)   := PROTOCOL_LEN_C;
                     v.tData(1)(47 downto 32)   := ARP_REQ_C;
                     v.tData(1)(95 downto 48)   := localMac;
                     v.tData(1)(127 downto 96)  := localIp;
                     v.tData(2)(47 downto 0)    := (others => '0');     -- Sought-after MAC
                     v.tData(2)(79 downto 48)   := arpReqMasters(r.reqCnt).tData(31 downto 0);  -- Known IP address
                     v.tData(2)(127 downto 80)  := (others => '0');
                  --------------------
                  -- Checking for VLAN
                  --------------------
                  else
                     v.tData(0)(47 downto 0)    := BROADCAST_MAC_C;
                     v.tData(0)(95 downto 48)   := localMac;
                     v.tData(0)(111 downto 96)  := VLAN_TYPE_C;
                     v.tData(0)(127 downto 122) := (others => '0');
                     v.tData(1)(15 downto 0)    := ARP_TYPE_C;
                     v.tData(1)(31 downto 16)   := HARDWWARE_TYPE_C;
                     v.tData(1)(47 downto 32)   := PROTOCOL_TYPE_C;
                     v.tData(1)(55 downto 48)   := HARDWWARE_LEN_C;
                     v.tData(1)(63 downto 56)   := PROTOCOL_LEN_C;
                     v.tData(1)(79 downto 64)   := ARP_REQ_C;
                     v.tData(1)(127 downto 80)  := localMac;
                     v.tData(2)(31 downto 0)    := localIp;
                     v.tData(2)(79 downto 32)   := (others => '0');     -- Sought-after MAC
                     v.tData(2)(111 downto 80)  := arpReqMasters(r.reqCnt).tData(31 downto 0);  -- Known IP address
                     v.tData(2)(127 downto 112) := (others => '0');
                  end if;
                  -- Next state
                  v.state := TX_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when RX_S =>
            -- Accept for data
            v.rxArpSlave.tReady := '1';
            -- Check for SOF and not EOF
            if (rxArpMaster.tValid = '1') then
               if r.cnt = 0 then
                  v.tData(0) := rxArpMaster.tData;
                  if (ssiGetUserSof(IP_ENGINE_CONFIG_C, rxArpMaster) = '1') then
                     -- Increment the counter
                     v.cnt := r.cnt + 1;
                  else
                     -- Next state
                     v.state := IDLE_S;
                  end if;
               elsif r.cnt = 1 then
                  v.tData(1) := rxArpMaster.tData;
                  if (rxArpMaster.tLast = '0') then
                     -- Increment the counter
                     v.cnt := r.cnt + 1;
                  else
                     -- Next state
                     v.state := IDLE_S;
                  end if;
               elsif r.cnt = 2 then
                  v.tData(2) := rxArpMaster.tData;
                  if (rxArpMaster.tLast = '0') then
                     -- Increment the counter
                     v.cnt := r.cnt + 1;
                  else
                     -- Check for EOFE error
                     if (ssiGetUserEofe(IP_ENGINE_CONFIG_C, rxArpMaster) = '1') then
                        -- Next state
                        v.state := IDLE_S;
                     else
                        -- Next state
                        v.state := CHECK_S;
                     end if;
                  end if;
               else
                  if rxArpMaster.tLast = '1' then
                     -- Check for EOFE error
                     if (ssiGetUserEofe(IP_ENGINE_CONFIG_C, rxArpMaster) = '1') then
                        -- Next state
                        v.state := IDLE_S;
                     else
                        -- Next state
                        v.state := CHECK_S;
                     end if;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when CHECK_S =>
            -- Default next state
            v.state := IDLE_S;
            -- Reset the counter
            v.cnt   := 0;
            ------------------------
            -- Checking for non-VLAN
            ------------------------
            if (VLAN_G = false) then
               if (r.tData(0)(127 downto 112) = HARDWWARE_TYPE_C)   -- Check for valid Hardware type
                  and (r.tData(1)(15 downto 0) = PROTOCOL_TYPE_C)   -- Check for valid Protocol type
                  and (r.tData(1)(23 downto 16) = HARDWWARE_LEN_C)  -- Check for valid Hardware Length
                  and (r.tData(1)(31 downto 24) = PROTOCOL_LEN_C) then  -- Check for valid Protocol Length
                  -- Check OP-CODE = ARP Request
                  if (r.tData(1)(47 downto 32) = ARP_REQ_C) then
                     -- Check if the target IP address matches local address
                     if r.tData(2)(79 downto 48) = localIp then
                        -- Modified the local buffer to become a reply packet
                        v.tData(0)(47 downto 0)   := r.tData(0)(95 downto 48);
                        v.tData(0)(95 downto 48)  := localMac;
                        v.tData(1)(47 downto 32)  := ARP_REPLY_C;
                        v.tData(1)(95 downto 48)  := localMac;
                        v.tData(1)(127 downto 96) := localIp;
                        v.tData(2)(47 downto 0)   := r.tData(1)(95 downto 48);
                        v.tData(2)(79 downto 48)  := r.tData(1)(127 downto 96);
                        v.tData(2)(127 downto 80) := (others => '0');
                        -- Next state
                        v.state                   := TX_S;
                     end if;
                  -- Check OP-CODE = ARP Reply
                  elsif (r.tData(1)(47 downto 32) = ARP_REPLY_C) then
                     -- Check if the target IP + MAC address matches local address
                     if (r.tData(2)(47 downto 0) = localMac) and (r.tData(2)(79 downto 48) = localIp) then
                        -- Next state
                        v.state := SCAN_S;
                     end if;
                  end if;
               end if;
            --------------------
            -- Checking for VLAN
            --------------------
            else
               if (r.tData(1)(31 downto 16) = HARDWWARE_TYPE_C)     -- Check for valid Hardware type
                  and (r.tData(1)(47 downto 32) = PROTOCOL_TYPE_C)  -- Check for valid Protocol type
                  and (r.tData(1)(55 downto 48) = HARDWWARE_LEN_C)  -- Check for valid Hardware Length
                  and (r.tData(1)(63 downto 56) = PROTOCOL_LEN_C) then  -- Check for valid Protocol Length
                  -- Check OP-CODE = ARP Request
                  if (r.tData(1)(79 downto 64) = ARP_REQ_C) then
                     -- Check if the target IP address matches local address
                     if r.tData(2)(111 downto 80) = localIp then
                        -- Modified the local buffer to become a reply packet
                        v.tData(0)(47 downto 0)    := r.tData(0)(95 downto 48);
                        v.tData(0)(95 downto 48)   := localMac;
                        v.tData(1)(79 downto 64)   := ARP_REPLY_C;
                        v.tData(1)(127 downto 80)  := localMac;
                        v.tData(2)(31 downto 0)    := localIp;
                        v.tData(2)(79 downto 32)   := r.tData(1)(127 downto 80);
                        v.tData(2)(111 downto 80)  := r.tData(2)(31 downto 0);
                        v.tData(2)(127 downto 112) := (others => '0');
                        -- Next state
                        v.state                    := TX_S;
                     end if;
                  -- Check OP-CODE = ARP Reply
                  elsif (r.tData(1)(79 downto 64) = ARP_REPLY_C) then
                     -- Check if the target IP + MAC address matches local address
                     if (r.tData(2)(79 downto 32) = localMac) and (r.tData(2)(111 downto 80) = localIp) then
                        -- Next state
                        v.state := SCAN_S;
                     end if;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when SCAN_S =>
            -- Check the tValid 
            if (arpReqMasters(r.ackCnt).tValid = '1') and (v.arpAckMasters(r.ackCnt).tValid = '0') then
               ------------------------
               -- Checking for non-VLAN
               ------------------------
               if (VLAN_G = false) then
                  -- Check if Source's IP address match request IP address
                  if arpReqMasters(r.ackCnt).tData(31 downto 0) = r.tData(1)(127 downto 96) then
                     -- ACK the request
                     v.arpReqSlaves(r.ackCnt).tReady              := '1';
                     v.arpAckMasters(r.ackCnt).tValid             := '1';
                     v.arpAckMasters(r.ackCnt).tData(47 downto 0) := r.tData(1)(95 downto 48);  -- Source's MAC address
                     -- Reset the timer
                     v.arpTimers(r.ackCnt)                        := 0;
                  end if;
               else
                  -- Check if Source's IP address match request IP address
                  if arpReqMasters(r.ackCnt).tData(31 downto 0) = r.tData(2)(31 downto 0) then
                     -- ACK the request
                     v.arpReqSlaves(r.ackCnt).tReady              := '1';
                     v.arpAckMasters(r.ackCnt).tValid             := '1';
                     v.arpAckMasters(r.ackCnt).tData(47 downto 0) := r.tData(1)(127 downto 80);  -- Source's MAC address
                     -- Reset the timer
                     v.arpTimers(r.ackCnt)                        := 0;
                  end if;
               end if;
            end if;
            -- Check the counter
            if r.ackCnt = (CLIENT_SIZE_G-1) then
               -- Reset the counter
               v.ackCnt := 0;
               -- Next state
               v.state  := IDLE_S;
            else
               v.reqCnt := r.reqCnt + 1;
            end if;
         ----------------------------------------------------------------------
         when TX_S =>
            -- Check if ready to move data
            if v.txArpMaster.tValid = '0' then
               -- Move data
               v.txArpMaster.tValid := '1';
               v.txArpMaster.tData  := r.tData(r.cnt);
               -- Increment the counter
               v.cnt                := r.cnt + 1;
               if r.cnt = 0 then
                  ssiSetUserSof(IP_ENGINE_CONFIG_C, v.txArpMaster, '1');
               elsif r.cnt = 2 then
                  -- Set the EOF flag
                  v.txArpMaster.tLast := '1';
                  -- Set the tKeep
                  if (VLAN_G = false) then
                     v.txArpMaster.tKeep := x"03FF";
                  else
                     v.txArpMaster.tKeep := x"3FFF";
                  end if;
                  -- Next state
                  v.state := IDLE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      arpReqSlaves  <= v.arpReqSlaves;
      arpAckMasters <= r.arpAckMasters;
      rxArpSlave    <= v.rxArpSlave;
      txArpMaster   <= r.txArpMaster;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   FIFO_TX : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 0,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => false,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 4,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => IP_ENGINE_CONFIG_C,
         MASTER_AXI_CONFIG_G => IP_ENGINE_CONFIG_C)            
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => txArpMaster,
         sAxisSlave  => txArpSlave,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => obArpMaster,
         mAxisSlave  => obArpSlave);  

end rtl;
