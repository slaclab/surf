-------------------------------------------------------------------------------
-- File       : IpV4EngineTx.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-12
-- Last update: 2016-09-16
-------------------------------------------------------------------------------
-- Description: IPv4 TX Engine Module
-- Note: IPv4 checksum checked in EthMac core
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

entity IpV4EngineTx is
   generic (
      TPD_G           : time            := 1 ns;
      PROTOCOL_SIZE_G : positive        := 1;
      PROTOCOL_G      : Slv8Array       := (0 => UDP_C);
      TTL_G           : slv(7 downto 0) := x"20";
      VLAN_G          : boolean         := false);       
   port (
      -- Local Configurations
      localMac          : in  slv(47 downto 0);  --  big-Endian configuration 
      -- Interface to Ethernet Frame MUX/DEMUX 
      obIpv4Master      : out AxiStreamMasterType;
      obIpv4Slave       : in  AxiStreamSlaveType;
      localhostMaster   : out AxiStreamMasterType;
      localhostSlave    : in  AxiStreamSlaveType;
      -- Interface to Protocol Engine  
      obProtocolMasters : in  AxiStreamMasterArray(PROTOCOL_SIZE_G-1 downto 0);
      obProtocolSlaves  : out AxiStreamSlaveArray(PROTOCOL_SIZE_G-1 downto 0);
      -- Clock and Reset
      clk               : in  sl;
      rst               : in  sl);
end IpV4EngineTx;

architecture rtl of IpV4EngineTx is

   type StateType is (
      IDLE_S,
      IPV4_HDR0_S,
      IPV4_HDR1_S,
      IPV4_HDR2_S,
      MOVE_S,
      LAST_S); 

   type RegType is record
      eofe     : sl;
      tKeep    : slv(15 downto 0);
      tData    : slv(127 downto 0);
      tDest    : slv(7 downto 0);
      id       : slv(15 downto 0);
      rxSlave  : AxiStreamSlaveType;
      txMaster : AxiStreamMasterType;
      state    : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      eofe     => '0',
      tKeep    => (others => '0'),
      tData    => (others => '0'),
      tDest    => (others => '0'),
      id       => (others => '0'),
      rxSlave  => AXI_STREAM_SLAVE_INIT_C,
      txMaster => AXI_STREAM_MASTER_INIT_C,
      state    => IDLE_S);      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxMaster : AxiStreamMasterType;
   signal rxSlave  : AxiStreamSlaveType;

   signal txMaster : AxiStreamMasterType;
   signal txSlave  : AxiStreamSlaveType;

   signal mAxisMaster : AxiStreamMasterType;
   signal mAxisSlave  : AxiStreamSlaveType;

   -- attribute dont_touch              : string;
   -- attribute dont_touch of r         : signal is "TRUE";   

begin

   AxiStreamMux_Inst : entity work.AxiStreamMux
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 0,
         NUM_SLAVES_G  => PROTOCOL_SIZE_G)
      port map (
         -- Clock and reset
         axisClk      => clk,
         axisRst      => rst,
         -- Slave
         sAxisMasters => obProtocolMasters,
         sAxisSlaves  => obProtocolSlaves,
         -- Masters
         mAxisMaster  => rxMaster,
         mAxisSlave   => rxSlave);   

   comb : process (localMac, r, rst, rxMaster, txSlave) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.rxSlave := AXI_STREAM_SLAVE_INIT_C;
      if txSlave.tReady = '1' then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
         v.txMaster.tKeep  := (others => '1');
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check if ready to move data
            if (rxMaster.tValid = '1') and (v.txMaster.tValid = '0') then
               -- Accept the data
               v.rxSlave.tReady := '1';
               -- Latch the TDEST
               v.tDest          := rxMaster.tDest;
               -- Check for SOF with no EOF
               if (ssiGetUserSof(EMAC_AXIS_CONFIG_C, rxMaster) = '1') and (rxMaster.tLast = '0') then
                  -- Send the RAW Ethernet header
                  v.txMaster.tValid := '1';
                  -- Set the SOF bit
                  ssiSetUserSof(EMAC_AXIS_CONFIG_C, v.txMaster, '1');
                  -- Setup the tDest routing
                  if (localMac = rxMaster.tData(47 downto 0)) then
                     -- Local Host Path
                     v.txMaster.tDest := x"01";
                  else
                     -- Remote Host Path
                     v.txMaster.tDest := x"00";
                  end if;
                  -- Set the DST MAC and SRC MAC
                  v.txMaster.tData(47 downto 0)  := rxMaster.tData(47 downto 0);
                  v.txMaster.tData(95 downto 48) := localMac;
                  -- Check for non-VLAN
                  if (VLAN_G = false) then
                     v.txMaster.tData(111 downto 96)  := IPV4_TYPE_C;
                     v.txMaster.tData(119 downto 112) := x"45";  -- IPVersion = 4,Header length = 5
                     v.txMaster.tData(127 downto 120) := x"00";  --- DSCP and ECN
                  else
                     -- Set the EtherType = VLAN Type
                     v.txMaster.tData(111 downto 96)  := VLAN_TYPE_C;
                     -- VID = 0x0 here because it gets overwritten in the MAC               
                     v.txMaster.tData(127 downto 112) := (others => '0');
                  end if;
                  -- Track the leftovers
                  v.tData(63 downto 0) := rxMaster.tData(127 downto 64);
                  -- Next state
                  v.state              := IPV4_HDR0_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when IPV4_HDR0_S =>
            -- Check for data
            if (v.txMaster.tValid = '0') then
               -- Send the IPV4 header
               v.txMaster.tValid := '1';
               -- Check for non-VLAN
               if (VLAN_G = false) then
                  v.txMaster.tData(7 downto 0)     := x"00";  -- IPV4_Length(15 downto 8) Note: Calculated in EthMac core 
                  v.txMaster.tData(15 downto 8)    := x"00";  -- IPV4_Length(7 downto 0)  Note: Calculated in EthMac core 
                  v.txMaster.tData(23 downto 16)   := r.id(15 downto 8);     -- IPV4_ID(15 downto 8)
                  v.txMaster.tData(31 downto 24)   := r.id(7 downto 0);      -- IPV4_ID(7 downto 0)
                  v.txMaster.tData(39 downto 32)   := x"40";  -- Flags(2 downto 0) =  Don't Fragment (DF) and Fragment_Offsets(12 downto 8) = 0x0
                  v.txMaster.tData(47 downto 40)   := x"00";  -- Fragment_Offsets(7 downto 0) = 0x0
                  v.txMaster.tData(55 downto 48)   := TTL_G;  -- Time-To-Live (number of hops before packet is discarded)
                  v.txMaster.tData(63 downto 56)   := PROTOCOL_G(conv_integer(r.tDest));  -- Protocol
                  v.txMaster.tData(71 downto 64)   := x"00";  -- IPV4_Checksum(15 downto 8)  Note: Filled in next state
                  v.txMaster.tData(79 downto 72)   := x"00";  -- IPV4_Checksum(7 downto 0)   Note: Filled in next state
                  v.txMaster.tData(111 downto 80)  := r.tData(31 downto 0);  -- Source IP Address(31 downto 0)
                  v.txMaster.tData(127 downto 112) := r.tData(47 downto 32);  -- Destination IP Address(31 downto 16)
               else
                  v.txMaster.tData(15 downto 0)    := IPV4_TYPE_C;
                  v.txMaster.tData(23 downto 16)   := x"45";  -- IPVersion = 4,Header length = 5
                  v.txMaster.tData(31 downto 24)   := x"00";  -- DSCP and ECN
                  v.txMaster.tData(39 downto 32)   := x"00";  -- IPV4_Length(15 downto 8) Note: Calculated in EthMac core 
                  v.txMaster.tData(47 downto 40)   := x"00";  -- IPV4_Length(7 downto 0)  Note: Calculated in EthMac core 
                  v.txMaster.tData(55 downto 48)   := r.id(15 downto 8);     -- IPV4_ID(15 downto 8)
                  v.txMaster.tData(63 downto 56)   := r.id(7 downto 0);      -- IPV4_ID(7 downto 0)
                  v.txMaster.tData(71 downto 64)   := x"40";  -- Flags(2 downto 0) =  Don't Fragment (DF) and Fragment_Offsets(12 downto 8) = 0x0
                  v.txMaster.tData(79 downto 72)   := x"00";  -- Fragment_Offsets(7 downto 0) = 0x0
                  v.txMaster.tData(87 downto 80)   := TTL_G;  -- Time-To-Live (number of hops before packet is discarded)
                  v.txMaster.tData(95 downto 88)   := PROTOCOL_G(conv_integer(r.tDest));  -- Protocol
                  v.txMaster.tData(103 downto 96)  := x"00";  -- IPV4_Checksum(15 downto 8)  Note: Calculated in EthMac core 
                  v.txMaster.tData(111 downto 104) := x"00";  -- IPV4_Checksum(7 downto 0)   Note: Calculated in EthMac core 
                  v.txMaster.tData(127 downto 112) := r.tData(15 downto 0);  -- Source IP Address(31 downto 16)
               end if;
               -- Increment the counter
               v.id    := r.id + 1;
               -- Next state
               v.state := IPV4_HDR1_S;
            end if;
         ----------------------------------------------------------------------
         when IPV4_HDR1_S =>
            -- Check if ready to move data
            if (rxMaster.tValid = '1') and (v.txMaster.tValid = '0') then
               -- Accept the data
               v.rxSlave.tReady := '1';
               -- Check for non-VLAN
               if (VLAN_G = false) then
                  -- Update the tData bus
                  v.txMaster.tData(15 downto 0)   := r.tData(63 downto 48);  -- Destination IP Address(15 downto 0)
                  v.txMaster.tData(111 downto 16) := rxMaster.tData(127 downto 32);
                  -- Update the tKeep bus
                  v.txMaster.tKeep(1 downto 0)    := (others => '1');
                  v.txMaster.tKeep(13 downto 2)   := rxMaster.tKeep(15 downto 4);
                  v.txMaster.tKeep(15 downto 14)  := (others => '0');
                  -- Get the EOFE 
                  v.eofe                          := ssiGetUserEofe(EMAC_AXIS_CONFIG_C, rxMaster);
                  -- Check for tLast
                  if (rxMaster.tLast = '1') then
                     -- Move the data
                     v.txMaster.tValid := '1';
                     -- Set the tLast flag
                     v.txMaster.tLast  := '1';
                     -- Set the EOFE 
                     ssiSetUserEofe(EMAC_AXIS_CONFIG_C, v.txMaster, v.eofe);
                     -- Next state
                     v.state           := IDLE_S;
                  else
                     -- Next state
                     v.state := IPV4_HDR2_S;
                  end if;
               else
                  -- Move the data
                  v.txMaster.tValid               := '1';
                  -- Update the tData bus
                  v.txMaster.tData(15 downto 0)   := r.tData(31 downto 16);  -- Source IP Address(15 downto 0)
                  v.txMaster.tData(47 downto 16)  := r.tData(63 downto 32);  -- Destination IP Address(31 downto 0)
                  v.txMaster.tData(127 downto 48) := rxMaster.tData(111 downto 32);
                  -- Update the tKeep bus
                  v.txMaster.tKeep(5 downto 0)    := (others => '1');
                  v.txMaster.tKeep(15 downto 6)   := rxMaster.tKeep(13 downto 4);
                  -- Track the leftovers
                  v.tData(15 downto 0)            := rxMaster.tData(127 downto 112);
                  v.tKeep(1 downto 0)             := rxMaster.tKeep(15 downto 14);
                  -- Get the EOFE 
                  v.eofe                          := ssiGetUserEofe(EMAC_AXIS_CONFIG_C, rxMaster);
                  -- Check for tLast
                  if (rxMaster.tLast = '1') then
                     -- Check the leftover tKeep is not empty
                     if (v.tKeep /= 0) then
                        -- Next state
                        v.state := LAST_S;
                     else
                        -- Set the EOF/EOFE
                        v.txMaster.tLast := '1';
                        ssiSetUserEofe(EMAC_AXIS_CONFIG_C, v.txMaster, v.eofe);
                        -- Next state
                        v.state          := IDLE_S;
                     end if;
                  else
                     -- Next state
                     v.state := MOVE_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when IPV4_HDR2_S =>
            -- Check for data
            if (rxMaster.tValid = '1') and (v.txMaster.tValid = '0') then
               -- Accept the data
               v.rxSlave.tReady                 := '1';
               -- Move the data
               v.txMaster.tValid                := '1';
               v.txMaster.tData(127 downto 112) := rxMaster.tData(15 downto 0);
               v.txMaster.tKeep(13 downto 0)    := (others => '1');
               v.txMaster.tKeep(15 downto 14)   := rxMaster.tKeep(1 downto 0);
               -- Track the leftovers
               v.tData(111 downto 0)            := rxMaster.tData(127 downto 16);
               v.tKeep(13 downto 0)             := rxMaster.tKeep(15 downto 2);
               -- Get the EOFE 
               v.eofe                           := ssiGetUserEofe(EMAC_AXIS_CONFIG_C, rxMaster);
               -- Check for tLast
               if (rxMaster.tLast = '1') then
                  -- Check the leftover tKeep is not empty
                  if (v.tKeep /= 0) then
                     -- Next state
                     v.state := LAST_S;
                  else
                     -- Set the EOF/EOFE
                     v.txMaster.tLast := '1';
                     ssiSetUserEofe(EMAC_AXIS_CONFIG_C, v.txMaster, v.eofe);
                     -- Next state
                     v.state          := IDLE_S;
                  end if;
               else
                  -- Next state
                  v.state := MOVE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check for data
            if (rxMaster.tValid = '1') and (v.txMaster.tValid = '0') then
               -- Accept the data
               v.rxSlave.tReady  := '1';
               -- Move the data
               v.txMaster.tValid := '1';
               -- Check for non-VLAN
               if (VLAN_G = false) then
                  -- Move the data
                  v.txMaster.tData(111 downto 0)   := r.tData(111 downto 0);
                  v.txMaster.tData(127 downto 112) := rxMaster.tData(15 downto 0);
                  v.txMaster.tKeep(13 downto 0)    := r.tKeep(13 downto 0);
                  v.txMaster.tKeep(15 downto 14)   := rxMaster.tKeep(1 downto 0);
                  -- Track the leftovers
                  v.tData(111 downto 0)            := rxMaster.tData(127 downto 16);
                  v.tKeep(13 downto 0)             := rxMaster.tKeep(15 downto 2);
                  -- Get the EOFE 
                  v.eofe                           := ssiGetUserEofe(EMAC_AXIS_CONFIG_C, rxMaster);
                  -- Check for tLast
                  if (rxMaster.tLast = '1') then
                     -- Check the leftover tKeep is not empty
                     if (v.tKeep /= 0) then
                        -- Next state
                        v.state := LAST_S;
                     else
                        -- Set the EOF/EOFE
                        v.txMaster.tLast := '1';
                        ssiSetUserEofe(EMAC_AXIS_CONFIG_C, v.txMaster, v.eofe);
                        -- Next state
                        v.state          := IDLE_S;
                     end if;
                  end if;
               else
                  -- Move the data
                  v.txMaster.tData(15 downto 0)   := r.tData(15 downto 0);
                  v.txMaster.tData(127 downto 16) := rxMaster.tData(111 downto 0);
                  v.txMaster.tKeep(1 downto 0)    := r.tKeep(1 downto 0);
                  v.txMaster.tKeep(15 downto 2)   := rxMaster.tKeep(13 downto 0);
                  -- Track the leftovers                  
                  v.tData(15 downto 0)            := rxMaster.tData(127 downto 112);
                  v.tKeep(1 downto 0)             := rxMaster.tKeep(15 downto 14);
                  -- Get the EOFE 
                  v.eofe                          := ssiGetUserEofe(EMAC_AXIS_CONFIG_C, rxMaster);
                  -- Check for tLast
                  if (rxMaster.tLast = '1') then
                     -- Check the leftover tKeep is not empty
                     if (v.tKeep /= 0) then
                        -- Next state
                        v.state := LAST_S;
                     else
                        -- Set the EOF/EOFE
                        v.txMaster.tLast := '1';
                        ssiSetUserEofe(EMAC_AXIS_CONFIG_C, v.txMaster, v.eofe);
                        -- Next state
                        v.state          := IDLE_S;
                     end if;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when LAST_S =>
            -- Check for data
            if (v.txMaster.tValid = '0') then
               -- Move the data
               v.txMaster.tValid := '1';
               v.txMaster.tData  := r.tData;
               v.txMaster.tKeep  := r.tKeep;
               v.txMaster.tLast  := '1';
               ssiSetUserEofe(EMAC_AXIS_CONFIG_C, v.txMaster, r.eofe);
               -- Next state
               v.state           := IDLE_S;
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
      rxSlave  <= v.rxSlave;
      txMaster <= r.txMaster;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_TxPipeline : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 0)
      port map (
         axisClk     => clk,
         axisRst     => rst,
         sAxisMaster => txMaster,
         sAxisSlave  => txSlave,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);      

   U_DeMux : entity work.AxiStreamDeMux
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 1,
         NUM_MASTERS_G => 2)
      port map (
         -- Clock and reset
         axisClk         => clk,
         axisRst         => rst,
         -- Slave         
         sAxisMaster     => mAxisMaster,
         sAxisSlave      => mAxisSlave,
         -- Masters
         mAxisMasters(0) => obIpv4Master,
         mAxisMasters(1) => localhostMaster,
         mAxisSlaves(0)  => obIpv4Slave,
         mAxisSlaves(1)  => localhostSlave);            

end rtl;
