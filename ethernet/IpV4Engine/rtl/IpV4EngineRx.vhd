-------------------------------------------------------------------------------
-- File       : IpV4EngineRx.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-12
-- Last update: 2016-09-16
-------------------------------------------------------------------------------
-- Description: IPv4 RX Engine Module
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

entity IpV4EngineRx is
   generic (
      TPD_G            : time      := 1 ns;
      SIM_ERROR_HALT_G : boolean   := false;
      PROTOCOL_SIZE_G  : positive  := 1;
      PROTOCOL_G       : Slv8Array := (0 => UDP_C);
      VLAN_G           : boolean   := false);       
   port (
      -- Interface to Ethernet Frame MUX/DEMUX 
      ibIpv4Master      : in  AxiStreamMasterType;
      ibIpv4Slave       : out AxiStreamSlaveType;
      localhostMaster   : in  AxiStreamMasterType;
      localhostSlave    : out AxiStreamSlaveType;
      -- Interface to Protocol Engine  
      ibProtocolMasters : out AxiStreamMasterArray(PROTOCOL_SIZE_G-1 downto 0);
      ibProtocolSlaves  : in  AxiStreamSlaveArray(PROTOCOL_SIZE_G-1 downto 0);
      -- Clock and Reset
      clk               : in  sl;
      rst               : in  sl);
end IpV4EngineRx;

architecture rtl of IpV4EngineRx is

   type StateType is (
      IDLE_S,
      IPV4_HDR0_S,
      IPV4_HDR1_S,
      IPV4_HDR2_S,
      MOVE_S,
      LAST_S); 

   type RegType is record
      tLast    : sl;
      eofe     : sl;
      len      : slv(15 downto 0);
      protocol : slv(7 downto 0);
      tKeep    : slv(15 downto 0);
      tData    : slv(127 downto 0);
      rxSlave  : AxiStreamSlaveType;
      txMaster : AxiStreamMasterType;
      state    : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      tLast    => '0',
      eofe     => '0',
      len      => (others => '0'),
      protocol => (others => '0'),
      tKeep    => (others => '0'),
      tData    => (others => '0'),
      rxSlave  => AXI_STREAM_SLAVE_INIT_C,
      txMaster => AXI_STREAM_MASTER_INIT_C,
      state    => IDLE_S);      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxMaster : AxiStreamMasterType;
   signal rxSlave  : AxiStreamSlaveType;
   signal txSlave  : AxiStreamSlaveType;

   -- attribute dont_touch              : string;
   -- attribute dont_touch of r         : signal is "TRUE";

begin

   U_Mux : entity work.AxiStreamMux
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 0,
         NUM_SLAVES_G  => 2)
      port map (
         -- Clock and reset
         axisClk         => clk,
         axisRst         => rst,
         -- Slaves
         sAxisMasters(0) => ibIpv4Master,
         sAxisMasters(1) => localhostMaster,
         sAxisSlaves(0)  => ibIpv4Slave,
         sAxisSlaves(1)  => localhostSlave,
         -- Master
         mAxisMaster     => rxMaster,
         mAxisSlave      => rxSlave);

   comb : process (r, rst, rxMaster, txSlave) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.rxSlave := AXI_STREAM_SLAVE_INIT_C;
      if (txSlave.tReady = '1') then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
         v.txMaster.tKeep  := (others => '1');
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for data
            if (rxMaster.tValid = '1') and (v.txMaster.tValid = '0') then
               -- Accept the data
               v.rxSlave.tReady := '1';
               -- Check for SOF with no EOF
               if (ssiGetUserSof(EMAC_AXIS_CONFIG_C, rxMaster) = '1') and (rxMaster.tLast = '0') then
                  -- Latch the remote MAC address
                  v.txMaster.tData(47 downto 0)  := rxMaster.tData(95 downto 48);
                  -- Unused data field 
                  v.txMaster.tData(63 downto 48) := (others => '0');
                  -- Next state
                  v.state                        := IPV4_HDR0_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when IPV4_HDR0_S =>
            -- Check for data
            if (rxMaster.tValid = '1') and (v.txMaster.tValid = '0') then
               -- Accept the data
               v.rxSlave.tReady := '1';
               -- Check for non-VLAN               
               if (VLAN_G = false) then
                  -- Calculate the IPV4 Pseudo Header length (in little Endian)
                  v.len(15 downto 8)              := rxMaster.tData(7 downto 0);  -- IPV4_Length(15 downto 8)
                  v.len(7 downto 0)               := rxMaster.tData(15 downto 8);  -- IPV4_Length(7 downto 0)
                  v.len                           := v.len - 20;  -- IPV4 Pseudo Header's length = protocol length - 20 Bytes               
                  -- Latch the protocol value
                  v.protocol                      := rxMaster.tData(63 downto 56);
                  -- Source IP Address(31 downto 0)
                  v.txMaster.tData(95 downto 64)  := rxMaster.tData(111 downto 80);
                  -- Destination IP Address(31 downto 16)
                  v.txMaster.tData(111 downto 96) := rxMaster.tData(127 downto 112);
               else
                  -- Calculate the IPV4 Pseudo Header length (in little Endian)
                  v.len(15 downto 8)             := rxMaster.tData(39 downto 32);  -- IPV4_Length(15 downto 8)
                  v.len(7 downto 0)              := rxMaster.tData(47 downto 40);  -- IPV4_Length(7 downto 0)
                  v.len                          := v.len - 20;  -- IPV4 Pseudo Header's length = protocol length - 20 Bytes               
                  -- Latch the protocol value
                  v.protocol                     := rxMaster.tData(95 downto 88);
                  -- Source IP Address(31 downto 16)
                  v.txMaster.tData(79 downto 64) := rxMaster.tData(127 downto 112);
               end if;
               -- Next state if protocol not detected during the "for loop"
               v.state := IDLE_S;
               -- Loop through the protocol buses
               for i in (PROTOCOL_SIZE_G-1) downto 0 loop
                  if (v.protocol = PROTOCOL_G(i)) then
                     -- Latch the protocol bus pointer
                     v.txMaster.tDest := toSlv(i, 8);
                     -- Next state if protocol not detected
                     v.state          := IPV4_HDR1_S;
                  end if;
               end loop;
            end if;
         ----------------------------------------------------------------------
         when IPV4_HDR1_S =>
            -- Check for data
            if (rxMaster.tValid = '1') and (v.txMaster.tValid = '0') then
               -- Move the data
               v.txMaster.tValid := '1';
               -- Set the SOF
               ssiSetUserSof(EMAC_AXIS_CONFIG_C, v.txMaster, '1');
               -- Check for non-VLAN                     
               if (VLAN_G = false) then
                  -- Destination IP Address(15 downto 0)
                  v.txMaster.tData(127 downto 112) := rxMaster.tData(15 downto 0);
                  -- Track the leftovers
                  v.tData(7 downto 0)              := x"00";
                  v.tData(15 downto 8)             := r.protocol;
                  v.tData(23 downto 16)            := r.len(15 downto 8);
                  v.tData(31 downto 24)            := r.len(7 downto 0);
                  v.tData(127 downto 32)           := rxMaster.tData(111 downto 16);
                  v.tKeep(3 downto 0)              := "1111";
                  v.tKeep(15 downto 4)             := rxMaster.tKeep(13 downto 2);
                  v.tLast                          := rxMaster.tLast;
                  v.eofe                           := ssiGetUserEofe(EMAC_AXIS_CONFIG_C, rxMaster);
                  -- Check for no remainder 
                  if (rxMaster.tKeep(15 downto 14) = 0) then
                     -- Accept the data
                     v.rxSlave.tReady := '1';
                     -- Next state
                     v.state          := LAST_S;
                  else
                     -- Next state
                     v.state := IPV4_HDR2_S;
                  end if;
               else
                  -- Accept the data
                  v.rxSlave.tReady                := '1';
                  -- Source IP Address(15 downto 0)
                  v.txMaster.tData(95 downto 80)  := rxMaster.tData(15 downto 0);
                  -- Destination IP Address(31 downto 0)
                  v.txMaster.tData(127 downto 96) := rxMaster.tData(47 downto 16);
                  -- Track the leftovers
                  v.tData(7 downto 0)             := x"00";
                  v.tData(15 downto 8)            := r.protocol;
                  v.tData(23 downto 16)           := r.len(15 downto 8);
                  v.tData(31 downto 24)           := r.len(7 downto 0);
                  v.tData(111 downto 32)          := rxMaster.tData(127 downto 48);
                  v.tKeep(3 downto 0)             := "1111";
                  v.tKeep(13 downto 4)            := rxMaster.tKeep(15 downto 6);
                  v.tKeep(15 downto 14)           := "00";
                  v.tLast                         := rxMaster.tLast;
                  v.eofe                          := ssiGetUserEofe(EMAC_AXIS_CONFIG_C, rxMaster);
                  -- Check for EOF
                  if (rxMaster.tLast = '1') then
                     -- Check the leftovers
                     if (v.tKeep /= 0) then
                        -- Next state
                        v.state := LAST_S;
                     else
                        -- Set EOF and EOFE
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
               v.rxSlave.tReady     := '1';
               -- Move the data
               v.txMaster.tValid    := '1';
               v.txMaster.tData     := r.tData;
               v.txMaster.tKeep     := r.tKeep;
               -- Track the leftovers
               v.tData(15 downto 0) := rxMaster.tData(127 downto 112);
               v.tKeep(1 downto 0)  := rxMaster.tKeep(15 downto 14);
               v.tKeep(15 downto 2) := (others => '0');
               v.tLast              := rxMaster.tLast;
               v.eofe               := ssiGetUserEofe(EMAC_AXIS_CONFIG_C, rxMaster);
               -- Check for EOF
               if (rxMaster.tLast = '1') then
                  -- Check the leftovers
                  if (v.tKeep /= 0) then
                     -- Next state
                     v.state := LAST_S;
                  else
                     -- Set EOF and EOFE
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
                  v.txMaster.tData(15 downto 0)   := r.tData(15 downto 0);
                  v.txMaster.tData(127 downto 16) := rxMaster.tData(111 downto 0);
                  v.txMaster.tKeep(1 downto 0)    := r.tKeep(1 downto 0);
                  v.txMaster.tKeep(15 downto 2)   := rxMaster.tKeep(13 downto 0);
                  -- Track the leftovers                  
                  v.tData(15 downto 0)            := rxMaster.tData(127 downto 112);
                  v.tKeep(1 downto 0)             := rxMaster.tKeep(15 downto 14);
                  v.tLast                         := rxMaster.tLast;
                  v.eofe                          := ssiGetUserEofe(EMAC_AXIS_CONFIG_C, rxMaster);
               else
                  -- Move the data
                  v.txMaster.tData(111 downto 0)   := r.tData(111 downto 0);
                  v.txMaster.tData(127 downto 112) := rxMaster.tData(15 downto 0);
                  v.txMaster.tKeep(13 downto 0)    := r.tKeep(13 downto 0);
                  v.txMaster.tKeep(15 downto 14)   := rxMaster.tKeep(1 downto 0);
                  -- Track the leftovers                  
                  v.tData(111 downto 0)            := rxMaster.tData(127 downto 16);
                  v.tKeep(13 downto 0)             := rxMaster.tKeep(15 downto 2);
                  v.tLast                          := rxMaster.tLast;
                  v.eofe                           := ssiGetUserEofe(EMAC_AXIS_CONFIG_C, rxMaster);
               end if;
               -- Check for tLast
               if (v.tLast = '1') then
                  -- Check the leftover tKeep is not empty
                  if (v.tKeep /= 0) then
                     -- Next state
                     v.state := LAST_S;
                  else
                     -- Set EOF and EOFE
                     v.txMaster.tLast := '1';
                     ssiSetUserEofe(EMAC_AXIS_CONFIG_C, v.txMaster, v.eofe);
                     -- Next state
                     v.state          := IDLE_S;
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
      rxSlave <= v.rxSlave;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_AxisMux : entity work.AxiStreamDeMux
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 1,
         NUM_MASTERS_G => PROTOCOL_SIZE_G)
      port map (
         -- Clock and reset
         axisClk      => clk,
         axisRst      => rst,
         -- Slave         
         sAxisMaster  => r.txMaster,
         sAxisSlave   => txSlave,
         -- Masters
         mAxisMasters => ibProtocolMasters,
         mAxisSlaves  => ibProtocolSlaves);     

end rtl;
