-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : IpV4EngineTx.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-12
-- Last update: 2016-08-17
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.IpV4EnginePkg.all;

entity IpV4EngineTx is
   generic (
      TPD_G            : time            := 1 ns;
      SIM_ERROR_HALT_G : boolean         := false;
      PROTOCOL_SIZE_G  : positive        := 1;
      PROTOCOL_G       : Slv8Array       := (0 => UDP_C);
      TTL_G            : slv(7 downto 0) := x"20";
      VLAN_G           : boolean         := false);       
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
      LENGTH_S,
      CHECKSUM_S,
      IPV4_HDR0_S,
      IPV4_HDR1_S,
      IPV4_HDR2_S,
      MOVE_S,
      LAST_S); 

   type RegType is record
      eofe             : sl;
      tKeep            : slv(15 downto 0);
      tData            : slv(127 downto 0);
      hdr              : Slv8Array(19 downto 0);
      sum0             : Slv32Array(3 downto 0);
      sum1             : Slv32Array(1 downto 0);
      sum2             : Slv32Array(1 downto 0);
      sum3             : slv(31 downto 0);
      sum4             : slv(31 downto 0);
      id               : slv(15 downto 0);
      obProtocolSlaves : AxiStreamSlaveArray(PROTOCOL_SIZE_G-1 downto 0);
      txMaster         : AxiStreamMasterType;
      cnt              : natural range 0 to 7;
      chCnt            : natural range 0 to PROTOCOL_SIZE_G-1;
      chCntDly         : natural range 0 to PROTOCOL_SIZE_G-1;
      state            : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      eofe             => '0',
      tKeep            => (others => '0'),
      tData            => (others => '0'),
      hdr              => (others => (others => '0')),
      sum0             => (others => (others => '0')),
      sum1             => (others => (others => '0')),
      sum2             => (others => (others => '0')),
      sum3             => (others => '0'),
      sum4             => (others => '0'),
      id               => (others => '0'),
      obProtocolSlaves => (others => AXI_STREAM_SLAVE_INIT_C),
      txMaster         => AXI_STREAM_MASTER_INIT_C,
      cnt              => 0,
      chCnt            => 0,
      chCntDly         => 0,
      state            => IDLE_S);      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal txMaster : AxiStreamMasterType;
   signal txSlave  : AxiStreamSlaveType;

   signal mAxisMaster : AxiStreamMasterType;
   signal mAxisSlave  : AxiStreamSlaveType;

   -- attribute dont_touch              : string;
   -- attribute dont_touch of r         : signal is "TRUE";   

begin

   comb : process (localMac, obProtocolMasters, r, rst, txSlave) is
      variable v        : RegType;
      variable i        : natural;
      variable len      : slv(15 downto 0);
      variable ibValid  : sl;
      variable checksum : slv(15 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      if txSlave.tReady = '1' then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
         v.txMaster.tKeep  := (others => '1');
      end if;
      for i in PROTOCOL_SIZE_G-1 downto 0 loop
         v.obProtocolSlaves(i) := AXI_STREAM_SLAVE_INIT_C;
      end loop;

      -- Process the checksum
      GetIpV4Checksum(r.hdr,
                      r.sum0, v.sum0,
                      r.sum1, v.sum1,
                      r.sum2, v.sum2,
                      r.sum3, v.sum3,
                      r.sum4, v.sum4,
                      ibValid, checksum);

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Increment the counter
            if r.chCnt = PROTOCOL_SIZE_G-1 then
               v.chCnt := 0;
            else
               v.chCnt := r.chCnt + 1;
            end if;
            -- Keep a delayed copy
            v.chCntDly := r.chCnt;
            -- Check for data
            if (obProtocolMasters(r.chCnt).tValid = '1') and (v.txMaster.tValid = '0') then
               -- Accept the data
               v.obProtocolSlaves(r.chCnt).tReady := '1';
               -- Check for SOF with no EOF
               if (ssiGetUserSof(IP_ENGINE_CONFIG_C, obProtocolMasters(r.chCnt)) = '1') and (obProtocolMasters(r.chCnt).tLast = '0') then
                  -- Send the RAW Ethernet header
                  v.txMaster.tValid := '1';
                  -- Set the SOF bit
                  ssiSetUserSof(IP_ENGINE_CONFIG_C, v.txMaster, '1');
                  -- Setup the tDest routing
                  if localMac = obProtocolMasters(r.chCnt).tData(47 downto 0) then
                     -- Local Host Path
                     v.txMaster.tDest := x"01";
                  else
                     -- Remote Host Path
                     v.txMaster.tDest := x"00";
                  end if;
                  -- Set the DST MAC and SRC MAC
                  v.txMaster.tData(47 downto 0)  := obProtocolMasters(r.chCnt).tData(47 downto 0);
                  v.txMaster.tData(95 downto 48) := localMac;
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
                  -- Start to generate the IPV4 header
                  v.hdr(0)  := x"45";   -- IPVersion = 4,Header length = 5
                  v.hdr(1)  := x"00";   -- DSCP and ECN
                  v.hdr(2)  := x"00";   -- IPV4_Length(15 downto 8) Note: Filled in next state
                  v.hdr(3)  := x"00";   -- IPV4_Length(7 downto 0)  Note: Filled in next state
                  v.hdr(4)  := r.id(15 downto 8);       -- IPV4_ID(15 downto 8)
                  v.hdr(5)  := r.id(7 downto 0);        -- IPV4_ID(7 downto 0)
                  v.hdr(6)  := x"40";  -- Flags(2 downto 0) =  Don't Fragment (DF) and Fragment_Offsets(12 downto 8) = 0x0
                  v.hdr(7)  := x"00";   -- Fragment_Offsets(7 downto 0) = 0x0
                  v.hdr(8)  := TTL_G;   -- Time-To-Live (number of hops before packet is discarded)
                  v.hdr(9)  := PROTOCOL_G(r.chCnt);     -- Protocol
                  v.hdr(10) := x"00";   -- IPV4_Checksum(15 downto 8)  Note: Filled in next state
                  v.hdr(11) := x"00";   -- IPV4_Checksum(7 downto 0)   Note: Filled in next state
                  v.hdr(12) := obProtocolMasters(r.chCnt).tData(71 downto 64);  -- Source IP Address
                  v.hdr(13) := obProtocolMasters(r.chCnt).tData(79 downto 72);  -- Source IP Address
                  v.hdr(14) := obProtocolMasters(r.chCnt).tData(87 downto 80);  -- Source IP Address 
                  v.hdr(15) := obProtocolMasters(r.chCnt).tData(95 downto 88);  -- Source IP Address 
                  v.hdr(16) := obProtocolMasters(r.chCnt).tData(103 downto 96);  -- Destination IP Address
                  v.hdr(17) := obProtocolMasters(r.chCnt).tData(111 downto 104);  -- Destination IP Address
                  v.hdr(18) := obProtocolMasters(r.chCnt).tData(119 downto 112);  -- Destination IP Address 
                  v.hdr(19) := obProtocolMasters(r.chCnt).tData(127 downto 120);  -- Destination IP Address
                  -- Reset the tKeep bus
                  v.tKeep   := (others => '0');
                  -- Increment the counter
                  v.id      := r.id + 1;
                  -- Next state
                  v.state   := LENGTH_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when LENGTH_S =>
            -- Check for data
            if (obProtocolMasters(r.chCntDly).tValid = '1') and (v.txMaster.tValid = '0') then
               -- Check for wrong protocol type
               if obProtocolMasters(r.chCntDly).tData(15 downto 8) /= PROTOCOL_G(r.chCntDly) then
                  -- Terminated the frame
                  v.txMaster.tValid := '1';
                  v.txMaster.tLast  := '1';
                  ssiSetUserEofe(IP_ENGINE_CONFIG_C, v.txMaster, '1');
                  -- Next state
                  v.state           := IDLE_S;
               else
                  -- Calculate the IPV4 Header length (in little Endian)
                  len(15 downto 8) := obProtocolMasters(r.chCntDly).tData(23 downto 16);
                  len(7 downto 0)  := obProtocolMasters(r.chCntDly).tData(31 downto 24);
                  len              := len + 20;  -- IPV4 Header's length = protocol length + 20 Bytes
                  -- Update the IPV4 header
                  v.hdr(2)         := len(15 downto 8);          --- IPV4_Length(15 downto 8)
                  v.hdr(3)         := len(7 downto 0);  --- IPV4_Length(7 downto 0)                   
                  -- Next state
                  v.state          := CHECKSUM_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when CHECKSUM_S =>
            -- Check the counter
            if r.cnt = 7 then
               -- Reset the counter
               v.cnt     := 0;
               -- Load the calculated checksum into the IPV4 header
               v.hdr(10) := checksum(15 downto 8);
               v.hdr(11) := checksum(7 downto 0);
               -- Next state
               v.state   := IPV4_HDR0_S;
            else
               -- Increment the counter
               v.cnt := r.cnt + 1;
            end if;
         ----------------------------------------------------------------------
         when IPV4_HDR0_S =>
            -- Check for data
            if v.txMaster.tValid = '0' then
               -- Send the IPV4 header
               v.txMaster.tValid := '1';
               if (VLAN_G = false) then
                  v.txMaster.tData(7 downto 0)     := r.hdr(2);
                  v.txMaster.tData(15 downto 8)    := r.hdr(3);
                  v.txMaster.tData(23 downto 16)   := r.hdr(4);
                  v.txMaster.tData(31 downto 24)   := r.hdr(5);
                  v.txMaster.tData(39 downto 32)   := r.hdr(6);
                  v.txMaster.tData(47 downto 40)   := r.hdr(7);
                  v.txMaster.tData(55 downto 48)   := r.hdr(8);
                  v.txMaster.tData(63 downto 56)   := r.hdr(9);
                  v.txMaster.tData(71 downto 64)   := r.hdr(10);
                  v.txMaster.tData(79 downto 72)   := r.hdr(11);
                  v.txMaster.tData(87 downto 80)   := r.hdr(12);
                  v.txMaster.tData(95 downto 88)   := r.hdr(13);
                  v.txMaster.tData(103 downto 96)  := r.hdr(14);
                  v.txMaster.tData(111 downto 104) := r.hdr(15);
                  v.txMaster.tData(119 downto 112) := r.hdr(16);
                  v.txMaster.tData(127 downto 120) := r.hdr(17);
               else
                  v.txMaster.tData(15 downto 0)    := IPV4_TYPE_C;
                  v.txMaster.tData(23 downto 16)   := r.hdr(0);
                  v.txMaster.tData(31 downto 24)   := r.hdr(1);
                  v.txMaster.tData(39 downto 32)   := r.hdr(2);
                  v.txMaster.tData(47 downto 40)   := r.hdr(3);
                  v.txMaster.tData(55 downto 48)   := r.hdr(4);
                  v.txMaster.tData(63 downto 56)   := r.hdr(5);
                  v.txMaster.tData(71 downto 64)   := r.hdr(6);
                  v.txMaster.tData(79 downto 72)   := r.hdr(7);
                  v.txMaster.tData(87 downto 80)   := r.hdr(8);
                  v.txMaster.tData(95 downto 88)   := r.hdr(9);
                  v.txMaster.tData(103 downto 96)  := r.hdr(10);
                  v.txMaster.tData(111 downto 104) := r.hdr(11);
                  v.txMaster.tData(119 downto 112) := r.hdr(12);
                  v.txMaster.tData(127 downto 120) := r.hdr(13);
               end if;
               -- Next state
               v.state := IPV4_HDR1_S;
            end if;
         ----------------------------------------------------------------------
         when IPV4_HDR1_S =>
            -- Check for data
            if (obProtocolMasters(r.chCntDly).tValid = '1') and (v.txMaster.tValid = '0') then
               -- Accept the data
               v.obProtocolSlaves(r.chCntDly).tReady := '1';
               if (VLAN_G = false) then
                  -- Update the tData bus
                  v.txMaster.tData(7 downto 0)    := r.hdr(18);
                  v.txMaster.tData(15 downto 8)   := r.hdr(19);
                  v.txMaster.tData(111 downto 16) := obProtocolMasters(r.chCntDly).tData(127 downto 32);
                  -- Update the tKeep bus
                  v.txMaster.tKeep(1 downto 0)    := (others => '1');
                  v.txMaster.tKeep(13 downto 2)   := obProtocolMasters(r.chCntDly).tKeep(15 downto 4);
                  v.txMaster.tKeep(15 downto 14)  := (others => '0');
                  -- Check for tLast
                  if obProtocolMasters(r.chCntDly).tLast = '1' then
                     -- Move the data
                     v.txMaster.tValid := '1';
                     -- Set the tLast flag
                     v.txMaster.tLast  := '1';
                     -- Update the EOFE bit
                     v.eofe            := ssiGetUserEofe(IP_ENGINE_CONFIG_C, obProtocolMasters(r.chCntDly));
                     ssiSetUserEofe(IP_ENGINE_CONFIG_C, v.txMaster, v.eofe);
                     -- Next state
                     v.state           := IDLE_S;
                  else
                     -- Next state
                     v.state := IPV4_HDR2_S;
                  end if;
               else
                  -- Update the tData bus
                  v.txMaster.tValid               := '1';
                  v.txMaster.tData(7 downto 0)    := r.hdr(14);
                  v.txMaster.tData(15 downto 8)   := r.hdr(15);
                  v.txMaster.tData(23 downto 16)  := r.hdr(16);
                  v.txMaster.tData(31 downto 24)  := r.hdr(17);
                  v.txMaster.tData(39 downto 32)  := r.hdr(18);
                  v.txMaster.tData(47 downto 40)  := r.hdr(19);
                  v.txMaster.tData(127 downto 48) := obProtocolMasters(r.chCntDly).tData(111 downto 32);
                  -- Update the tKeep bus
                  v.txMaster.tKeep(5 downto 0)    := (others => '1');
                  v.txMaster.tKeep(15 downto 6)   := obProtocolMasters(r.chCntDly).tKeep(13 downto 4);
                  -- Track the leftovers
                  v.tData(15 downto 0)            := obProtocolMasters(r.chCntDly).tData(127 downto 112);
                  v.tKeep(1 downto 0)             := obProtocolMasters(r.chCntDly).tKeep(15 downto 14);
                  -- Check for tLast
                  if obProtocolMasters(r.chCntDly).tLast = '1' then
                     -- Zero out unused data field
                     v.tData(127 downto 16) := (others => '0');
                     -- Update the EOFE bit
                     v.eofe                 := ssiGetUserEofe(IP_ENGINE_CONFIG_C, obProtocolMasters(r.chCntDly));
                     -- Check the leftover tKeep is not empty
                     if v.tKeep /= 0 then
                        -- Next state
                        v.state := LAST_S;
                     else
                        -- Set the tLast flag
                        v.txMaster.tLast := '1';
                        -- Update the EOFE bit
                        ssiSetUserEofe(IP_ENGINE_CONFIG_C, v.txMaster, v.eofe);
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
            if (obProtocolMasters(r.chCntDly).tValid = '1') and (v.txMaster.tValid = '0') then
               -- Accept the data
               v.obProtocolSlaves(r.chCntDly).tReady := '1';
               -- Move the data
               v.txMaster.tValid                     := '1';
               v.txMaster.tData(127 downto 112)      := obProtocolMasters(r.chCntDly).tData(15 downto 0);
               v.txMaster.tKeep(13 downto 0)         := (others => '1');
               v.txMaster.tKeep(15 downto 14)        := obProtocolMasters(r.chCntDly).tKeep(1 downto 0);
               -- Track the leftovers
               v.tData(111 downto 0)                 := obProtocolMasters(r.chCntDly).tData(127 downto 16);
               v.tKeep(13 downto 0)                  := obProtocolMasters(r.chCntDly).tKeep(15 downto 2);
               -- Check for tLast
               if obProtocolMasters(r.chCntDly).tLast = '1' then
                  -- Zero out unused data field
                  v.tData(127 downto 112) := (others => '0');
                  -- Update the EOFE bit
                  v.eofe                  := ssiGetUserEofe(IP_ENGINE_CONFIG_C, obProtocolMasters(r.chCntDly));
                  -- Check the leftover tKeep is not empty
                  if v.tKeep /= 0 then
                     -- Next state
                     v.state := LAST_S;
                  else
                     v.txMaster.tLast := '1';
                     ssiSetUserEofe(IP_ENGINE_CONFIG_C, v.txMaster, v.eofe);
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
            if (obProtocolMasters(r.chCntDly).tValid = '1') and (v.txMaster.tValid = '0') then
               -- Accept the data
               v.obProtocolSlaves(r.chCntDly).tReady := '1';
               -- Move the data
               v.txMaster.tValid                     := '1';
               if (VLAN_G = false) then
                  -- Move the data
                  v.txMaster.tData(111 downto 0)   := r.tData(111 downto 0);
                  v.txMaster.tData(127 downto 112) := obProtocolMasters(r.chCntDly).tData(15 downto 0);
                  v.txMaster.tKeep(13 downto 0)    := r.tKeep(13 downto 0);
                  v.txMaster.tKeep(15 downto 14)   := obProtocolMasters(r.chCntDly).tKeep(1 downto 0);
                  -- Track the leftovers
                  v.tData(111 downto 0)            := obProtocolMasters(r.chCntDly).tData(127 downto 16);
                  v.tKeep(13 downto 0)             := obProtocolMasters(r.chCntDly).tKeep(15 downto 2);
                  -- Check for tLast
                  if obProtocolMasters(r.chCntDly).tLast = '1' then
                     -- Zero out unused data field
                     v.tData(127 downto 112) := (others => '0');
                     -- Update the EOFE bit
                     v.eofe                  := ssiGetUserEofe(IP_ENGINE_CONFIG_C, obProtocolMasters(r.chCntDly));
                     -- Check the leftover tKeep is not empty
                     if v.tKeep /= 0 then
                        -- Next state
                        v.state := LAST_S;
                     else
                        v.txMaster.tLast := '1';
                        ssiSetUserEofe(IP_ENGINE_CONFIG_C, v.txMaster, v.eofe);
                        -- Next state
                        v.state          := IDLE_S;
                     end if;
                  end if;
               else
                  -- Move the data
                  v.txMaster.tData(15 downto 0)   := r.tData(15 downto 0);
                  v.txMaster.tData(127 downto 16) := obProtocolMasters(r.chCntDly).tData(111 downto 0);
                  v.txMaster.tKeep(1 downto 0)    := r.tKeep(1 downto 0);
                  v.txMaster.tKeep(15 downto 2)   := obProtocolMasters(r.chCntDly).tKeep(13 downto 0);
                  -- Track the leftovers                  
                  v.tData(15 downto 0)            := obProtocolMasters(r.chCntDly).tData(127 downto 112);
                  v.tKeep(1 downto 0)             := obProtocolMasters(r.chCntDly).tKeep(15 downto 14);
                  -- Check for tLast
                  if obProtocolMasters(r.chCntDly).tLast = '1' then
                     -- Zero out unused data field
                     v.tData(127 downto 16) := (others => '0');
                     -- Update the EOFE bit
                     v.eofe                 := ssiGetUserEofe(IP_ENGINE_CONFIG_C, obProtocolMasters(r.chCntDly));
                     -- Check the leftover tKeep is not empty
                     if v.tKeep /= 0 then
                        -- Next state
                        v.state := LAST_S;
                     else
                        v.txMaster.tLast := '1';
                        ssiSetUserEofe(IP_ENGINE_CONFIG_C, v.txMaster, v.eofe);
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
               ssiSetUserEofe(IP_ENGINE_CONFIG_C, v.txMaster, r.eofe);
               -- Next state
               v.state           := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Check the simulation error printing
      if SIM_ERROR_HALT_G and (r.eofe = '1') then
         report "IpV4EngineTx: Error Detected" severity failure;
      end if;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      obProtocolSlaves <= v.obProtocolSlaves;
      txMaster         <= r.txMaster;

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
         sAxisMaster => txMaster,
         sAxisSlave  => txSlave,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);        

   U_DeMux : entity work.AxiStreamDeMux
      generic map (
         TPD_G         => TPD_G,
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
