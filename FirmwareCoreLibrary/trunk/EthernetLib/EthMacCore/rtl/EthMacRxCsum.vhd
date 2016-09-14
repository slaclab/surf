-------------------------------------------------------------------------------
-- Title      : 1GbE/10GbE/40GbE Ethernet MAC
-------------------------------------------------------------------------------
-- File       : EthMacRxCsum.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-09-08
-- Last update: 2016-09-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: RX Checksum Hardware Offloading Engine
-- https://docs.google.com/spreadsheets/d/1_1M1keasfq8RLmRYHkO0IlRhMq5YZTgJ7OGrWvkib8I/edit?usp=sharing
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.AxiStreamPkg.all;
use work.StdRtlPkg.all;
use work.EthMacPkg.all;

entity EthMacRxCsum is
   generic (
      TPD_G   : time    := 1 ns;
      JUMBO_G : boolean := true;
      VLAN_G  : boolean := false);
   port (
      -- Clock and Reset
      ethClk      : in  sl;
      ethRst      : in  sl;
      -- Configurations
      ipCsumEn    : in  sl;
      tcpCsumEn   : in  sl;
      udpCsumEn   : in  sl;
      -- Inbound data from MAC
      sAxisMaster : in  AxiStreamMasterType;
      mAxisMaster : out AxiStreamMasterType);
end EthMacRxCsum;

architecture rtl of EthMacRxCsum is

   constant MAX_FRAME_SIZE_C : natural := ite(JUMBO_G, 9000, 1500);
   
   type StateType is (
      IDLE_S,
      IPV4_HDR0_S,
      IPV4_HDR1_S,
      MOVE_S,
      LAST_S,
      BLOWOFF_S); 

   type RegType is record
      eofeDet   : sl;
      ipv4Det   : sl;
      udpDet    : sl;
      tcpDet    : sl;
      tcpFlag   : sl;
      byteCnt   : natural range 0 to (MAX_FRAME_SIZE_C + 32);  -- MTU size + padding
      ipv4Len   : slv(15 downto 0);
      ipv4Csum  : slv(15 downto 0);
      protLen   : slv(15 downto 0);
      protCsum  : slv(15 downto 0);
      ipv4Hdr   : Slv8Array(19 downto 0);
      ipv4Sum   : Slv32Array(1 downto 0);
      protAccum : slv(31 downto 0);

      mAxisMaster : AxiStreamMasterType;
      state       : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      eofeDet     => '0',
      ipv4Det     => '0',
      udpDet      => '0',
      tcpDet      => '0',
      tcpFlag     => '0',
      byteCnt     => 0,
      ipv4Len     => (others => '0'),
      ipv4Csum    => (others => '0'),
      protLen     => (others => '0'),
      protCsum    => (others => '0'),
      ipv4Hdr     => (others => (others => '0')),
      ipv4Sum     => (others => (others => '0')),
      protAccum   => (others => '0'),
      mAxisMaster => AXI_STREAM_MASTER_INIT_C,
      state       => IDLE_S);      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch              : string;
   -- attribute dont_touch of r         : signal is "TRUE";

begin
   
   comb : process (ethRst, ipCsumEn, r, sAxisMaster, tcpCsumEn, udpCsumEn) is
      variable v         : RegType;
      variable ipValid   : sl;
      variable protValid : sl;
      variable dummy     : Slv16Array(1 downto 0);
      variable tKeep     : slv(15 downto 0);
      variable tData     : slv(127 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.mAxisMaster.tValid := '0';
      tKeep                := (others => '0');
      tData                := (others => '0');

      -- Process the IPv4 checksum
      GetIpV4Checksum(
         r.ipv4Hdr,
         r.ipv4Sum,
         ipValid,
         dummy(0));                     -- Unused in RX CSUM

      -- Process the TCP/UDP checksum
      GetTcpUdpChecksum(
         r.protAccum,
         r.protLen,
         r.protCsum,
         protValid,
         dummy(1));                     -- Unused in RX CSUM          

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the flags and counter
            v.ipv4Det := '0';
            v.udpDet  := '0';
            v.tcpDet  := '0';
            v.tcpFlag := '0';
            -- Check for valid data
            if (sAxisMaster.tValid = '1') then
               -- Move the data
               v.mAxisMaster := sAxisMaster;
               -- Check for no EOF
               if (sAxisMaster.tLast = '0') then
                  -- Check if NON-VLAN
                  if (VLAN_G = false) then
                     -- Check for EtherType = IPV4 = 0x0800
                     if (sAxisMaster.tData(111 downto 96) = IPV4_TYPE_C) then
                        -- Set the flag
                        v.ipv4Det := '1';
                     end if;
                     -- Fill in the IPv4 header checksum
                     v.ipv4Hdr(0) := sAxisMaster.tData(119 downto 112);  -- IPVersion + Header length
                     v.ipv4Hdr(1) := sAxisMaster.tData(127 downto 120);  -- DSCP and ECN                          
                  end if;
                  -- Next state
                  v.state := IPV4_HDR0_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when IPV4_HDR0_S =>
            -- Check for valid data
            if (sAxisMaster.tValid = '1') then
               -- Move the data
               v.mAxisMaster := sAxisMaster;
               -- Check for EOF
               if (sAxisMaster.tLast = '1') then
                  -- Set the error flag if IPv4 is detected and being checked
                  axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v.mAxisMaster, EMAC_IPERR_BIT_C, r.ipv4Det);
                  -- Next state
                  v.state := IDLE_S;
               else
                  -- Check if NON-VLAN
                  if (VLAN_G = false) then
                     -- Fill in the IPv4 header checksum
                     v.ipv4Hdr(2)       := sAxisMaster.tData(7 downto 0);  -- IPV4_Length(15 downto 8)
                     v.ipv4Hdr(3)       := sAxisMaster.tData(15 downto 8);  -- IPV4_Length(7 downto 0)                     
                     v.ipv4Hdr(4)       := sAxisMaster.tData(23 downto 16);  -- IPV4_ID(15 downto 8)
                     v.ipv4Hdr(5)       := sAxisMaster.tData(31 downto 24);  -- IPV4_ID(7 downto 0)
                     v.ipv4Hdr(6)       := sAxisMaster.tData(39 downto 32);  -- Flags and Fragment Offsets
                     v.ipv4Hdr(7)       := sAxisMaster.tData(47 downto 40);  -- Flags and Fragment Offsets
                     v.ipv4Hdr(8)       := sAxisMaster.tData(55 downto 48);  -- Time-To-Live
                     v.ipv4Hdr(9)       := sAxisMaster.tData(63 downto 56);  -- Protocol
                     v.ipv4Hdr(10)      := sAxisMaster.tData(71 downto 64);  -- IPV4_Checksum(15 downto 8)
                     v.ipv4Hdr(11)      := sAxisMaster.tData(79 downto 72);  -- IPV4_Checksum(7 downto 0)                     
                     v.ipv4Hdr(12)      := sAxisMaster.tData(87 downto 80);  -- Source IP Address
                     v.ipv4Hdr(13)      := sAxisMaster.tData(95 downto 88);  -- Source IP Address
                     v.ipv4Hdr(14)      := sAxisMaster.tData(103 downto 96);  -- Source IP Address
                     v.ipv4Hdr(15)      := sAxisMaster.tData(111 downto 104);  -- Source IP Address
                     v.ipv4Hdr(16)      := sAxisMaster.tData(119 downto 112);  -- Destination IP Address
                     v.ipv4Hdr(17)      := sAxisMaster.tData(127 downto 120);  -- Destination IP Address    
                     -- Fill in the TCP/UDP checksum
                     tData(63 downto 0) := sAxisMaster.tData(127 downto 80) & sAxisMaster.tData(63 downto 56) & x"00";
                     tKeep(7 downto 0)  := (others => '1');
                  else
                     -- Check for EtherType = IPV4 = 0x0800
                     if (sAxisMaster.tData(15 downto 0) = IPV4_TYPE_C) then
                        -- Set the flag
                        v.ipv4Det := '1';
                     end if;
                     -- Fill in the IPv4 header checksum
                     v.ipv4Hdr(0)       := sAxisMaster.tData(23 downto 16);  -- IPVersion + Header length
                     v.ipv4Hdr(1)       := sAxisMaster.tData(31 downto 24);  -- DSCP and ECN
                     v.ipv4Hdr(2)       := sAxisMaster.tData(39 downto 32);  -- IPV4_Length(15 downto 8)
                     v.ipv4Hdr(3)       := sAxisMaster.tData(47 downto 40);  -- IPV4_Length(7 downto 0)                     
                     v.ipv4Hdr(4)       := sAxisMaster.tData(55 downto 48);  -- IPV4_ID(15 downto 8)
                     v.ipv4Hdr(5)       := sAxisMaster.tData(63 downto 56);  -- IPV4_ID(7 downto 0)
                     v.ipv4Hdr(6)       := sAxisMaster.tData(71 downto 64);  -- Flags and Fragment Offsets
                     v.ipv4Hdr(7)       := sAxisMaster.tData(79 downto 72);  -- Flags and Fragment Offsets
                     v.ipv4Hdr(8)       := sAxisMaster.tData(87 downto 80);  -- Time-To-Live
                     v.ipv4Hdr(9)       := sAxisMaster.tData(95 downto 88);  -- Protocol
                     v.ipv4Hdr(10)      := sAxisMaster.tData(103 downto 96);  -- IPV4_Checksum(15 downto 8)
                     v.ipv4Hdr(11)      := sAxisMaster.tData(111 downto 104);  -- IPV4_Checksum(7 downto 0)                     
                     v.ipv4Hdr(12)      := sAxisMaster.tData(119 downto 112);  -- Source IP Address
                     v.ipv4Hdr(13)      := sAxisMaster.tData(127 downto 120);  -- Source IP Address      
                     -- Fill in the TCP/UDP checksum
                     tData(31 downto 0) := sAxisMaster.tData(127 downto 119) & sAxisMaster.tData(95 downto 88) & x"00";
                     tKeep(3 downto 0)  := (others => '1');
                  end if;
                  -- Latch the IPv4 length value
                  v.ipv4Len(15 downto 8) := v.ipv4Hdr(2);
                  v.ipv4Len(7 downto 0)  := v.ipv4Hdr(3);
                  -- Check for UDP protocol
                  if (v.ipv4Hdr(9) = UDP_C) then
                     v.udpDet := '1';
                  end if;
                  -- Check for TCP protocol
                  if (v.ipv4Hdr(9) = TCP_C) then
                     v.tcpDet := '1';
                  end if;
                  -- Next state
                  v.state := IPV4_HDR1_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when IPV4_HDR1_S =>
            -- Check for valid data
            if (sAxisMaster.tValid = '1') then
               -- Move the data
               v.mAxisMaster := sAxisMaster;
               -- Fill in the TCP/UDP checksum
               tKeep         := sAxisMaster.tKeep;
               tData         := sAxisMaster.tData;
               -- Check if NON-VLAN
               if (VLAN_G = false) then
                  -- Fill in the IPv4 header checksum
                  v.ipv4Hdr(18) := sAxisMaster.tData(7 downto 0);    -- Destination IP Address
                  v.ipv4Hdr(19) := sAxisMaster.tData(15 downto 8);   -- Destination IP Address    
                  -- Check for UDP data with inbound checksum
                  if (r.ipv4Det = '1') and (r.udpDet = '1') then
                     -- Mask off inbound UDP checksum
                     tData                   := sAxisMaster.tData(127 downto 80) & x"0000" & sAxisMaster.tData(63 downto 0);
                     -- Latch the inbound UDP checksum
                     v.protCsum(15 downto 8) := sAxisMaster.tData(71 downto 64);
                     v.protCsum(7 downto 0)  := sAxisMaster.tData(79 downto 72);
                     -- Latch the inbound UDP length
                     v.protLen(15 downto 8)  := sAxisMaster.tData(55 downto 48);
                     v.protLen(7 downto 0)   := sAxisMaster.tData(63 downto 56);
                  end if;
                  -- Track the number of bytes (include IPv4 header offset from previous state)
                  v.byteCnt := getTKeep(sAxisMaster.tKeep) + 18;
               else
                  -- Fill in the IPv4 header checksum
                  v.ipv4Hdr(14) := sAxisMaster.tData(7 downto 0);    -- Source IP Address
                  v.ipv4Hdr(15) := sAxisMaster.tData(15 downto 8);   -- Source IP Address
                  v.ipv4Hdr(16) := sAxisMaster.tData(23 downto 16);  -- Destination IP Address
                  v.ipv4Hdr(17) := sAxisMaster.tData(31 downto 24);  -- Destination IP Address               
                  v.ipv4Hdr(18) := sAxisMaster.tData(39 downto 32);  -- Destination IP Address
                  v.ipv4Hdr(19) := sAxisMaster.tData(47 downto 40);  -- Destination IP Address       
                  -- Check for UDP data with inbound checksum
                  if (r.ipv4Det = '1') and (r.udpDet = '1') then
                     -- Mask off inbound UDP checksum
                     tData                   := sAxisMaster.tData(127 downto 112) & x"0000" & sAxisMaster.tData(95 downto 0);
                     -- Latch the inbound UDP checksum
                     v.protCsum(15 downto 8) := sAxisMaster.tData(103 downto 96);
                     v.protCsum(7 downto 0)  := sAxisMaster.tData(111 downto 104);
                     -- Latch the inbound UDP length
                     v.protLen(15 downto 8)  := sAxisMaster.tData(87 downto 80);
                     v.protLen(7 downto 0)   := sAxisMaster.tData(95 downto 88);
                  end if;
                  -- Track the number of bytes (include IPv4 header offset from previous state)
                  v.byteCnt := getTKeep(sAxisMaster.tKeep) + 14;
               end if;
               -- Check for EOF
               if (sAxisMaster.tLast = '1') then
                  -- Check the detection flags
                  if (r.ipv4Det = '1') or (r.udpDet = '1') or (r.tcpDet = '1') then
                     -- Hold moving tLast until after checksum calculation
                     v.mAxisMaster.tValid := '0';
                     -- Next state
                     v.state              := LAST_S;
                  else
                     -- Next state
                     v.state := IDLE_S;
                  end if;
               else
                  -- Next state
                  v.state := MOVE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check for valid data
            if (sAxisMaster.tValid = '1') then
               -- Move the data
               v.mAxisMaster := sAxisMaster;
               -- Fill in the TCP/UDP checksum
               tData         := sAxisMaster.tData;
               tKeep         := sAxisMaster.tKeep;
               -- Check for TCP data with inbound checksum
               if (r.ipv4Det = '1') and (r.tcpDet = '1') and (r.tcpFlag = '0') then
                  -- Set the flag
                  v.tcpFlag := '1';
                  -- Calculate TCP length from IPv4 length
                  v.protLen := r.ipv4Len - 20;
                  -- Check if NON-VLAN
                  if (VLAN_G = false) then
                     -- Mask off inbound TCP checksum
                     tData                   := sAxisMaster.tData(127 downto 32) & x"0000" & sAxisMaster.tData(15 downto 0);
                     -- Latch the inbound TCP checksum
                     v.protCsum(15 downto 8) := sAxisMaster.tData(23 downto 16);
                     v.protCsum(7 downto 0)  := sAxisMaster.tData(31 downto 24);
                  else
                     -- Mask off inbound TCP checksum
                     tData                   := sAxisMaster.tData(127 downto 64) & x"0000" & sAxisMaster.tData(47 downto 0);
                     -- Latch the inbound TCP checksum
                     v.protCsum(15 downto 8) := sAxisMaster.tData(55 downto 48);
                     v.protCsum(7 downto 0)  := sAxisMaster.tData(63 downto 56);
                  end if;
               end if;
               -- Track the number of bytes 
               v.byteCnt := r.byteCnt + getTKeep(sAxisMaster.tKeep);
               -- Check for EOF
               if (sAxisMaster.tLast = '1') or (v.byteCnt > MAX_FRAME_SIZE_C) then
                  -- Check for overflow condition
                  if (sAxisMaster.tLast = '0') then
                     -- Force EOF
                     v.mAxisMaster.tLast := '1';
                     -- Set the error flag
                     axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v.mAxisMaster, EMAC_EOFE_BIT_C, '1');
                     -- Next state
                     v.state             := BLOWOFF_S;
                  -- Check the detection flags
                  elsif (r.ipv4Det = '1') or (r.udpDet = '1') or (r.tcpDet = '1') then
                     -- Hold moving tLast until after checksum calculation
                     v.mAxisMaster.tValid := '0';
                     -- Next state
                     v.state              := LAST_S;
                  else
                     -- Next state
                     v.state := IDLE_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when LAST_S =>
            -- Move the data from previous state
            v.mAxisMaster.tValid := '1';
            -- Check if IPv4 is detected and being checked
            if (r.ipv4Det = '1') and (ipCsumEn = '1') then
               -- Forward the result of checksum calculation
               axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v.mAxisMaster, EMAC_IPERR_BIT_C, not(ipValid));
               axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v.mAxisMaster, EMAC_EOFE_BIT_C, not(ipValid));
            end if;
            -- Check if UDP is detected and being checked
            if (r.ipv4Det = '1') and (r.udpDet = '1') and (udpCsumEn = '1') then
               -- Forward the result of checksum calculation
               axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v.mAxisMaster, EMAC_UDPERR_BIT_C, not(protValid));
               axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v.mAxisMaster, EMAC_EOFE_BIT_C, not(protValid));
               -- Check for mismatch in IPv4 length with UDP length
               if (r.ipv4Len /= (r.protLen + 20)) then
                  -- Set the error flags
                  axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v.mAxisMaster, EMAC_UDPERR_BIT_C, '1');
                  axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v.mAxisMaster, EMAC_EOFE_BIT_C, '1');
               end if;
            end if;
            -- Check if TCP is detected and being checked
            if (r.ipv4Det = '1') and (r.tcpDet = '1') and (tcpCsumEn = '1') then
               -- Forward the result of checksum calculation
               axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v.mAxisMaster, EMAC_TCPERR_BIT_C, not(protValid));
               axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v.mAxisMaster, EMAC_EOFE_BIT_C, not(protValid));
            end if;
            -- Next state
            v.state := IDLE_S;
         ----------------------------------------------------------------------
         when BLOWOFF_S =>
            -- Check for a valid EOF
            if (sAxisMaster.tValid = '1') and (sAxisMaster.tLast = '1') then
               -- Next State
               v.state := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Process the IPv4 checksum      
      GetIpV4Summation(
         v.ipv4Hdr,
         v.ipv4Sum);        

      -- Process the TCP/UDP checksum         
      GetTcpUdpAccumulator (
         tKeep,
         tData,
         r.protAccum,
         v.protAccum);            

      -- Check if next state will be IDLE
      if (v.state = IDLE_S) then
         -- Reset accumulators
         v.protAccum := (others => '0');
      end if;

      -- Reset
      if (ethRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      mAxisMaster <= r.mAxisMaster;
      
   end process comb;

   seq : process (ethClk) is
   begin
      if rising_edge(ethClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
