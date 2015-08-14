-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : ArpEngine.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-12
-- Last update: 2015-08-13
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.IpEngineDefPkg.all;

entity ArpEngine is
   generic (
      TPD_G  : time    := 1 ns;
      VLAN_G : boolean := false);  
   port (
      -- Local Configuration
      mac            : in  slv(47 downto 0);
      ip             : in  slv(31 downto 0);
      -- Interface to IP/MAC Table 
      ibArpMacMaster : in  AxiStreamMasterType;  -- Request via IP only
      ibArpMacSlave  : out AxiStreamSlaveType;
      obArpMacMaster : out AxiStreamMasterType;  -- Respond with IP + MAC
      obArpMacSlave  : in  AxiStreamSlaveType;
      -- Interface to Etherenet Frame MUX/DEMUX 
      ibArpMaster    : in  AxiStreamMasterType;
      ibArpSlave     : out AxiStreamSlaveType;
      obArpMaster    : out AxiStreamMasterType;
      obArpSlave     : in  AxiStreamSlaveType;
      -- Clock and Reset
      clk            : in  sl;
      rst            : in  sl);
end ArpEngine;

architecture rtl of ArpEngine is

   type StateType is (
      IDLE_S,
      RX_S,
      CHECK_S,
      TX_S); 

   type RegType is record
      cnt            : natural range 0 to 3;
      tData          : Slv128Array(2 downto 0);
      ibArpMacSlave  : AxiStreamSlaveType;
      obArpMacMaster : AxiStreamMasterType;
      rxArpSlave     : AxiStreamSlaveType;
      txArpMaster    : AxiStreamMasterType;
      state          : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      cnt            => 0,
      tData          => (others => (others => '0')),
      ibArpMacSlave  => AXI_STREAM_SLAVE_INIT_C,
      obArpMacMaster => IP_MAC_MASTER_INIT_C,
      rxArpSlave     => AXI_STREAM_SLAVE_INIT_C,
      txArpMaster    => AXI_STREAM_MASTER_INIT_C,
      state          => IDLE_S);      

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

   comb : process (ibArpMacMaster, rxArpMaster, ip, mac, obArpMacSlave, txArpSlave, r, rst) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.ibArpMacSlave := AXI_STREAM_SLAVE_INIT_C;
      if obArpMacSlave.tReady = '1' then
         v.obArpMacMaster := IP_MAC_MASTER_INIT_C;
      end if;
      v.rxArpSlave := AXI_STREAM_SLAVE_INIT_C;
      if txArpSlave.tReady = '1' then
         v.txArpMaster := AXI_STREAM_MASTER_INIT_C;
      end if;

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
            -- Check for an outstanding ARP request from IP/MAC table
            elsif ibArpMacMaster.tValid = '1' then
               -- Accept for data
               v.ibArpMacSlave.tReady := '1';
               ------------------------
               -- Checking for non-VLAN
               ------------------------
               if (VLAN_G = false) then
                  v.tData(0)(47 downto 0)    := BROADCAST_MAC_C;
                  v.tData(0)(95 downto 48)   := mac;
                  v.tData(0)(111 downto 96)  := ARP_TYPE_C;
                  v.tData(0)(127 downto 112) := HARDWWARE_TYPE_C;
                  v.tData(1)(15 downto 0)    := PROTOCOL_TYPE_C;
                  v.tData(1)(23 downto 16)   := HARDWWARE_LEN_C;
                  v.tData(1)(31 downto 24)   := PROTOCOL_LEN_C;
                  v.tData(1)(47 downto 32)   := ARP_REQ_C;
                  v.tData(1)(95 downto 48)   := mac;
                  v.tData(1)(127 downto 96)  := ip;
                  v.tData(2)(47 downto 0)    := (others => '0');    -- Sought-after MAC
                  v.tData(2)(79 downto 48)   := ibArpMacMaster.tData(79 downto 48);  -- Known IP address
                  v.tData(2)(127 downto 80)  := (others => '0');
               --------------------
               -- Checking for VLAN
               --------------------
               else
                  v.tData(0)(47 downto 0)    := BROADCAST_MAC_C;
                  v.tData(0)(95 downto 48)   := mac;
                  v.tData(0)(111 downto 96)  := VLAN_TYPE_C;
                  v.tData(0)(127 downto 122) := (others => '0');
                  v.tData(1)(15 downto 0)    := ARP_TYPE_C;
                  v.tData(1)(31 downto 16)   := HARDWWARE_TYPE_C;
                  v.tData(1)(47 downto 32)   := PROTOCOL_TYPE_C;
                  v.tData(1)(55 downto 48)   := HARDWWARE_LEN_C;
                  v.tData(1)(63 downto 56)   := PROTOCOL_LEN_C;
                  v.tData(1)(79 downto 64)   := ARP_REQ_C;
                  v.tData(1)(127 downto 80)  := mac;
                  v.tData(2)(31 downto 0)    := ip;
                  v.tData(2)(79 downto 32)   := (others => '0');    -- Sought-after MAC
                  v.tData(2)(111 downto 80)  := ibArpMacMaster.tData(79 downto 48);  -- Known IP address
                  v.tData(2)(127 downto 112) := (others => '0');
               end if;
               -- Next state
               v.state := TX_S;
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
            -- Check if ready to move data
            if v.obArpMacMaster.tValid = '0' then
               -- Default next state
               v.state := IDLE_S;
               ------------------------
               -- Checking for non-VLAN
               ------------------------
               if (VLAN_G = false) then
                  if (r.tData(0)(127 downto 112) = HARDWWARE_TYPE_C)  -- Check for valid Hardware type
                     and (r.tData(1)(15 downto 0) = PROTOCOL_TYPE_C)  -- Check for valid Protocol type
                     and (r.tData(1)(23 downto 16) = HARDWWARE_LEN_C)  -- Check for valid Hardware Length
                     and (r.tData(1)(31 downto 24) = PROTOCOL_LEN_C) then  -- Check for valid Protocol Length
                     -- Check OP-CODE = ARP Request
                     if (r.tData(1)(47 downto 32) = ARP_REQ_C) then
                        -- Check if the target IP address matches local address
                        if r.tData(2)(79 downto 48) = ip then
                           -- Modifed the local buffer to become a reply packet
                           v.tData(0)(47 downto 0)              := r.tData(0)(95 downto 48);
                           v.tData(0)(95 downto 48)             := mac;
                           v.tData(1)(47 downto 32)             := ARP_REPLY_C;
                           v.tData(1)(95 downto 48)             := mac;
                           v.tData(1)(127 downto 96)            := ip;
                           v.tData(2)(47 downto 0)              := r.tData(1)(95 downto 48);
                           v.tData(2)(79 downto 48)             := r.tData(1)(127 downto 96);
                           v.tData(2)(127 downto 80)            := (others => '0');
                           -- Update the IP/MAC Table
                           v.obArpMacMaster.tValid              := '1';
                           v.obArpMacMaster.tData(47 downto 0)  := r.tData(1)(95 downto 48);  -- Source's MAC address
                           v.obArpMacMaster.tData(79 downto 48) := r.tData(1)(127 downto 96);  -- Source's IP address
                           -- Next state
                           v.state                              := TX_S;
                        end if;
                     -- Check OP-CODE = ARP Reply
                     elsif (r.tData(1)(47 downto 32) = ARP_REPLY_C) then
                        -- Check if the target IP + MAC address matches local address
                        if (r.tData(2)(47 downto 0) = mac) and (r.tData(2)(79 downto 48) = ip) then
                           -- Update the IP/MAC Table
                           v.obArpMacMaster.tValid              := '1';
                           v.obArpMacMaster.tData(47 downto 0)  := r.tData(1)(95 downto 48);  -- Source's MAC address
                           v.obArpMacMaster.tData(79 downto 48) := r.tData(1)(127 downto 96);  -- Source's IP address
                        end if;
                     end if;
                  end if;
               --------------------
               -- Checking for VLAN
               --------------------
               else
                  if (r.tData(1)(31 downto 16) = HARDWWARE_TYPE_C)  -- Check for valid Hardware type
                     and (r.tData(1)(47 downto 32) = PROTOCOL_TYPE_C)  -- Check for valid Protocol type
                     and (r.tData(1)(55 downto 48) = HARDWWARE_LEN_C)  -- Check for valid Hardware Length
                     and (r.tData(1)(63 downto 56) = PROTOCOL_LEN_C) then  -- Check for valid Protocol Length
                     -- Check OP-CODE = ARP Request
                     if (r.tData(1)(79 downto 64) = ARP_REQ_C) then
                        -- Check if the target IP address matches local address
                        if r.tData(2)(111 downto 80) = ip then
                           -- Modifed the local buffer to become a reply packet
                           v.tData(0)(47 downto 0)              := r.tData(0)(95 downto 48);
                           v.tData(0)(95 downto 48)             := mac;
                           v.tData(1)(79 downto 64)             := ARP_REPLY_C;
                           v.tData(1)(127 downto 80)            := mac;
                           v.tData(2)(31 downto 0)              := ip;
                           v.tData(2)(79 downto 32)             := r.tData(1)(127 downto 80);
                           v.tData(2)(111 downto 80)            := r.tData(2)(31 downto 0);
                           v.tData(2)(127 downto 112)           := (others => '0');
                           -- Update the IP/MAC Table
                           v.obArpMacMaster.tValid              := '1';
                           v.obArpMacMaster.tData(47 downto 0)  := r.tData(1)(127 downto 80);  -- Source's MAC address
                           v.obArpMacMaster.tData(79 downto 48) := r.tData(2)(31 downto 0);  -- Source's IP address                              
                           -- Next state
                           v.state                              := TX_S;
                        end if;
                     -- Check OP-CODE = ARP Reply
                     elsif (r.tData(1)(79 downto 64) = ARP_REPLY_C) then
                        -- Check if the target IP + MAC address matches local address
                        if (r.tData(2)(79 downto 32) = mac) and (r.tData(2)(111 downto 80) = ip) then
                           -- Update the IP/MAC Table
                           v.obArpMacMaster.tValid              := '1';
                           v.obArpMacMaster.tData(47 downto 0)  := r.tData(1)(127 downto 80);  -- Source's MAC address
                           v.obArpMacMaster.tData(79 downto 48) := r.tData(2)(31 downto 0);  -- Source's IP address                        
                        end if;
                     end if;
                  end if;
               end if;
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
      ibArpMacSlave   <= v.ibArpMacSlave;
      obArpMacMaster  <= r.obArpMacMaster;
      rxArpSlave      <= v.rxArpSlave;
      txArpMaster     <= r.txArpMaster;
      
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
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
         sAxisMaster => txArpMaster,
         sAxisSlave  => txArpSlave,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => obArpMaster,
         mAxisSlave  => obArpSlave);  

end rtl;
