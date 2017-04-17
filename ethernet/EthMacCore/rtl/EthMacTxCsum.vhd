-------------------------------------------------------------------------------
-- File       : EthMacTxCsum.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-09-08
-- Last update: 2017-02-22
-------------------------------------------------------------------------------
-- Description: TX Checksum Hardware Offloading Engine
-- https://docs.google.com/spreadsheets/d/1_1M1keasfq8RLmRYHkO0IlRhMq5YZTgJ7OGrWvkib8I/edit?usp=sharing
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.EthMacPkg.all;

entity EthMacTxCsum is
   generic (
      TPD_G          : time             := 1 ns;
      DROP_ERR_PKT_G : boolean          := true;
      JUMBO_G        : boolean          := true;
      VLAN_G         : boolean          := false;
      VID_G          : slv(11 downto 0) := x"001");
   port (
      -- Clock and Reset
      ethClk      : in  sl;
      ethRst      : in  sl;
      -- Configurations
      ipCsumEn    : in  sl;
      tcpCsumEn   : in  sl;
      udpCsumEn   : in  sl;
      -- Outbound data to MAC
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);
end EthMacTxCsum;

architecture rtl of EthMacTxCsum is

   constant MAX_FRAME_SIZE_C : natural := ite(JUMBO_G, 9000, 1500);

   type StateType is (
      IDLE_S,
      IPV4_HDR0_S,
      IPV4_HDR1_S,
      MOVE_S,
      BLOWOFF_S);

   type RegType is record
      tranWr   : sl;
      fragDet  : slv(EMAC_CSUM_PIPELINE_C+1 downto 0);
      eofeDet  : slv(EMAC_CSUM_PIPELINE_C+1 downto 0);
      ipv4Det  : slv(EMAC_CSUM_PIPELINE_C+1 downto 0);
      udpDet   : slv(EMAC_CSUM_PIPELINE_C+1 downto 0);
      tcpDet   : slv(EMAC_CSUM_PIPELINE_C+1 downto 0);
      tcpFlag  : sl;
      ipv4Len  : Slv16Array(EMAC_CSUM_PIPELINE_C+1 downto 0);
      ipv4Csum : slv(15 downto 0);
      protLen  : Slv16Array(EMAC_CSUM_PIPELINE_C+1 downto 0);
      protCsum : slv(15 downto 0);
      ipv4Hdr  : Slv8Array(19 downto 0);
      calc     : EthMacCsumAccumArray(1 downto 0);
      len      : slv(15 downto 0);
      tKeep    : slv(15 downto 0);
      tData    : slv(127 downto 0);
      tranRd   : sl;
      mvCnt    : natural range 0 to 4;
      dbg      : slv(5 downto 0);
      rxSlave  : AxiStreamSlaveType;
      txMaster : AxiStreamMasterType;
      mSlave   : AxiStreamSlaveType;
      sMaster  : AxiStreamMasterType;
      state    : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      tranWr   => '0',
      fragDet  => (others => '0'),
      eofeDet  => (others => '0'),
      ipv4Det  => (others => '0'),
      udpDet   => (others => '0'),
      tcpDet   => (others => '0'),
      tcpFlag  => '0',
      ipv4Len  => (others => (others => '0')),
      ipv4Csum => (others => '0'),
      protLen  => (others => (others => '0')),
      protCsum => (others => '0'),
      ipv4Hdr  => (others => (others => '0')),
      calc     => (others => ETH_MAC_CSUM_ACCUM_INIT_C),
      len      => (others => '0'),
      tKeep    => (others => '0'),
      tData    => (others => '0'),
      tranRd   => '0',
      mvCnt    => 0,
      dbg      => (others => '0'),
      rxSlave  => AXI_STREAM_SLAVE_INIT_C,
      txMaster => AXI_STREAM_MASTER_INIT_C,
      mSlave   => AXI_STREAM_SLAVE_INIT_C,
      sMaster  => AXI_STREAM_MASTER_INIT_C,
      state    => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxMaster : AxiStreamMasterType;
   signal rxSlave  : AxiStreamSlaveType;
   signal sMaster  : AxiStreamMasterType;
   signal sSlave   : AxiStreamSlaveType;
   signal mMaster  : AxiStreamMasterType;
   signal mSlave   : AxiStreamSlaveType;
   signal txMaster : AxiStreamMasterType;
   signal txSlave  : AxiStreamSlaveType;

   signal tranPause : sl;
   signal fragDet   : sl;
   signal eofeDet   : sl;
   signal ipv4Det   : sl;
   signal udpDet    : sl;
   signal tcpDet    : sl;
   signal ipv4Len   : slv(15 downto 0);
   signal ipv4Csum  : slv(15 downto 0);
   signal protLen   : slv(15 downto 0);
   signal protCsum  : slv(15 downto 0);
   signal tranValid : sl;

   -- attribute dont_touch              : string;
   -- attribute dont_touch of r         : signal is "TRUE";
   -- attribute dont_touch of fragDet   : signal is "TRUE";
   -- attribute dont_touch of eofeDet   : signal is "TRUE";
   -- attribute dont_touch of ipv4Det   : signal is "TRUE";
   -- attribute dont_touch of udpDet    : signal is "TRUE";
   -- attribute dont_touch of tcpDet    : signal is "TRUE";
   -- attribute dont_touch of ipv4Len   : signal is "TRUE";
   -- attribute dont_touch of ipv4Csum  : signal is "TRUE";
   -- attribute dont_touch of protLen   : signal is "TRUE";
   -- attribute dont_touch of protCsum  : signal is "TRUE";
   -- attribute dont_touch of tranValid : signal is "TRUE";
   -- attribute dont_touch of mMaster   : signal is "TRUE";
   -- attribute dont_touch of mSlave    : signal is "TRUE";

begin

   U_RxPipeline : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 0)
      port map (
         axisClk     => ethClk,
         axisRst     => ethRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         mAxisMaster => rxMaster,
         mAxisSlave  => rxSlave);

   comb : process (eofeDet, ethRst, fragDet, ipCsumEn, ipv4Csum, ipv4Det,
                   ipv4Len, mMaster, protCsum, protLen, r, rxMaster, sSlave,
                   tcpCsumEn, tcpDet, tranPause, tranValid, txSlave, udpCsumEn,
                   udpDet) is
      variable v     : RegType;
      variable dummy : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.tranWr  := '0';
      v.tranRd  := '0';
      v.dbg     := (others => '0');
      v.tKeep   := (others => '0');
      v.rxSlave := AXI_STREAM_SLAVE_INIT_C;
      if sSlave.tReady = '1' then
         v.sMaster.tValid := '0';
      end if;
      v.mSlave := AXI_STREAM_SLAVE_INIT_C;
      if txSlave.tReady = '1' then
         v.txMaster.tValid := '0';
      end if;

      GetEthMacCsum (
         r.udpDet(EMAC_CSUM_PIPELINE_C),
         r.tranWr,
         r.ipv4Hdr,
         r.tKeep,
         r.tData,
         r.len,
         x"0000",                       -- Unused in TX CSUM
         r.calc,
         v.calc,
         dummy(0),                      -- Unused in TX CSUM
         v.ipv4Csum,
         dummy(1),                      -- Unused in TX CSUM
         v.protCsum);

      -- Pipeline alignment to GetEthMacCsum()
      v.fragDet := r.fragDet(EMAC_CSUM_PIPELINE_C downto 0) & r.fragDet(0);
      v.eofeDet := r.eofeDet(EMAC_CSUM_PIPELINE_C downto 0) & r.eofeDet(0);
      v.ipv4Det := r.ipv4Det(EMAC_CSUM_PIPELINE_C downto 0) & r.ipv4Det(0);
      v.udpDet  := r.udpDet(EMAC_CSUM_PIPELINE_C downto 0) & r.udpDet(0);
      v.tcpDet  := r.tcpDet(EMAC_CSUM_PIPELINE_C downto 0) & r.tcpDet(0);
      v.ipv4Len := r.ipv4Len(EMAC_CSUM_PIPELINE_C downto 0) & r.ipv4Len(0);
      v.protLen := r.protLen(EMAC_CSUM_PIPELINE_C downto 0) & r.protLen(0);

      -- Check for UDP frame
      if (r.udpDet(EMAC_CSUM_PIPELINE_C-1) = '1') then
         -- Multiple length by 2 to combine UDP length and IPV4 Pseudo Header's length together
         v.len := r.protLen(EMAC_CSUM_PIPELINE_C-2)(14 downto 0) & '0';
      else
         -- TCP only has IPV4 Pseudo Header's length together
         v.len := r.protLen(EMAC_CSUM_PIPELINE_C-2);
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the flags
            v.fragDet(0) := '0';
            v.eofeDet(0) := '0';
            v.ipv4Det(0) := '0';
            v.udpDet(0)  := '0';
            v.tcpDet(0)  := '0';
            v.tcpFlag    := '0';
            -- Reset accumulators
            v.ipv4Len(0) := toSlv(20, 16);
            v.protLen(0) := (others => '0');
            -- Check if ready to move data
            if (rxMaster.tValid = '1') and (v.sMaster.tValid = '0') and (tranPause = '0') then
               -- Accept the data
               v.rxSlave.tReady := '1';
               -- Move data
               v.sMaster        := rxMaster;
               -- Set the flag
               v.fragDet(0) := axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, rxMaster, EMAC_FRAG_BIT_C, 0);
               -- Check for EOF
               if (rxMaster.tLast = '1') then
                  -- Save the EOFE value
                  v.eofeDet(0) := axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, rxMaster, EMAC_EOFE_BIT_C);
                  -- Write the transaction data
                  v.tranWr     := '1';
               else
                  -- Check if NON-VLAN
                  if (VLAN_G = false) then
                     -- Check for EtherType = IPV4 = 0x0800
                     if (rxMaster.tData(111 downto 96) = IPV4_TYPE_C) then
                        -- Set the flag
                        v.ipv4Det(0) := '1';
                     end if;
                     -- Fill in the IPv4 header checksum
                     v.ipv4Hdr(0) := rxMaster.tData(119 downto 112);  -- IPVersion + Header length
                     v.ipv4Hdr(1) := rxMaster.tData(127 downto 120);  -- DSCP and ECN     
                  else
                     -- Add the IEEE 802.1Q header
                     v.sMaster.tData(111 downto 96)  := VLAN_TYPE_C;
                     v.sMaster.tData(119 downto 112) := x"0" & VID_G(11 downto 8);
                     v.sMaster.tData(127 downto 120) := VID_G(7 downto 0);
                  end if;
                  -- Next state
                  v.state := IPV4_HDR0_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when IPV4_HDR0_S =>
            -- Check if ready to move data
            if (rxMaster.tValid = '1') and (v.sMaster.tValid = '0') and (tranPause = '0') then
               -- Accept the data
               v.rxSlave.tReady := '1';
               -- Move data
               v.sMaster        := rxMaster;
               -- Check for EOF
               if (rxMaster.tLast = '1') then
                  -- if IPv4 detected, ETH frame too short 
                  if (r.ipv4Det(0) = '1') then
                     -- Set the error flag
                     v.eofeDet(0) := '1';
                  else
                     -- Save the EOFE value
                     v.eofeDet(0) := axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, rxMaster, EMAC_EOFE_BIT_C);
                  end if;
                  -- Write the transaction data
                  v.tranWr := '1';
                  -- Next state
                  v.state  := IDLE_S;
               else
                  -- Check if NON-VLAN
                  if (VLAN_G = false) then
                     -- Fill in the IPv4 header checksum
                     v.ipv4Hdr(4)         := rxMaster.tData(23 downto 16);  -- IPV4_ID(15 downto 8)
                     v.ipv4Hdr(5)         := rxMaster.tData(31 downto 24);  -- IPV4_ID(7 downto 0)
                     v.ipv4Hdr(6)         := rxMaster.tData(39 downto 32);  -- Flags(2 downto 0) and Fragment Offsets(12 downto 8)
                     v.ipv4Hdr(7)         := rxMaster.tData(47 downto 40);  -- Fragment Offsets(7 downto 0)
                     v.ipv4Hdr(8)         := rxMaster.tData(55 downto 48);  -- Time-To-Live
                     v.ipv4Hdr(9)         := rxMaster.tData(63 downto 56);  -- Protocol
                     v.ipv4Hdr(12)        := rxMaster.tData(87 downto 80);  -- Source IP Address
                     v.ipv4Hdr(13)        := rxMaster.tData(95 downto 88);  -- Source IP Address
                     v.ipv4Hdr(14)        := rxMaster.tData(103 downto 96);  -- Source IP Address
                     v.ipv4Hdr(15)        := rxMaster.tData(111 downto 104);  -- Source IP Address
                     v.ipv4Hdr(16)        := rxMaster.tData(119 downto 112);  -- Destination IP Address
                     v.ipv4Hdr(17)        := rxMaster.tData(127 downto 120);  -- Destination IP Address    
                     -- Fill in the TCP/UDP checksum
                     v.tData(63 downto 0) := rxMaster.tData(127 downto 80) & rxMaster.tData(63 downto 56) & x"00";
                     v.tKeep(7 downto 0)  := (others => '1');
                  else
                     -- Check for EtherType = IPV4 = 0x0800
                     if (rxMaster.tData(15 downto 0) = IPV4_TYPE_C) then
                        -- Set the flag
                        v.ipv4Det(0) := '1';
                     end if;
                     -- Fill in the IPv4 header checksum
                     v.ipv4Hdr(0)         := rxMaster.tData(23 downto 16);  -- IPVersion + Header length
                     v.ipv4Hdr(1)         := rxMaster.tData(31 downto 24);  -- DSCP and ECN
                     v.ipv4Hdr(4)         := rxMaster.tData(55 downto 48);  -- IPV4_ID(15 downto 8)
                     v.ipv4Hdr(5)         := rxMaster.tData(63 downto 56);  -- IPV4_ID(7 downto 0)
                     v.ipv4Hdr(6)         := rxMaster.tData(71 downto 64);  -- Flags(2 downto 0) and Fragment Offsets(12 downto 8)
                     v.ipv4Hdr(7)         := rxMaster.tData(79 downto 72);  -- Fragment Offsets(7 downto 0)
                     v.ipv4Hdr(8)         := rxMaster.tData(87 downto 80);  -- Time-To-Live
                     v.ipv4Hdr(9)         := rxMaster.tData(95 downto 88);  -- Protocol
                     v.ipv4Hdr(12)        := rxMaster.tData(119 downto 112);  -- Source IP Address
                     v.ipv4Hdr(13)        := rxMaster.tData(127 downto 120);  -- Source IP Address      
                     -- Fill in the TCP/UDP checksum
                     v.tData(31 downto 0) := rxMaster.tData(127 downto 119) & rxMaster.tData(95 downto 88) & x"00";
                     v.tKeep(3 downto 0)  := (others => '1');
                  end if;
                  -- Check for UDP protocol
                  if (v.ipv4Hdr(9) = UDP_C) then
                     v.udpDet(0) := '1';
                  end if;
                  -- Check for TCP protocol
                  if (v.ipv4Hdr(9) = TCP_C) then
                     v.tcpDet(0) := '1';
                  end if;
                  -- Next state
                  v.state := IPV4_HDR1_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when IPV4_HDR1_S =>
            -- Check if ready to move data
            if (rxMaster.tValid = '1') and (v.sMaster.tValid = '0') and (tranPause = '0') then
               -- Accept the data
               v.rxSlave.tReady := '1';
               -- Move data
               v.sMaster        := rxMaster;
               -- Fill in the TCP/UDP checksum
               v.tKeep          := rxMaster.tKeep;
               v.tData          := rxMaster.tData;
               -- Check if NON-VLAN
               if (VLAN_G = false) then
                  -- Fill in the IPv4 header checksum
                  v.ipv4Hdr(18) := rxMaster.tData(7 downto 0);  -- Destination IP Address
                  v.ipv4Hdr(19) := rxMaster.tData(15 downto 8);  -- Destination IP Address   
                  -- Check for UDP data with inbound length/checksum
                  if (r.ipv4Det(0) = '1') and (r.udpDet(0) = '1') then
                     -- Mask off inbound UDP length/checksum
                     v.tData := rxMaster.tData(127 downto 80) & x"00000000" & rxMaster.tData(47 downto 0);
                  end if;
                  -- Track the number of bytes 
                  v.ipv4Len(0) := r.ipv4Len(0) + getTKeep(rxMaster.tKeep) - 2;
                  v.protLen(0) := r.protLen(0) + getTKeep(rxMaster.tKeep) - 2;
               else
                  -- Fill in the IPv4 header checksum
                  v.ipv4Hdr(14) := rxMaster.tData(7 downto 0);  -- Source IP Address
                  v.ipv4Hdr(15) := rxMaster.tData(15 downto 8);  -- Source IP Address
                  v.ipv4Hdr(16) := rxMaster.tData(23 downto 16);  -- Destination IP Address
                  v.ipv4Hdr(17) := rxMaster.tData(31 downto 24);  -- Destination IP Address               
                  v.ipv4Hdr(18) := rxMaster.tData(39 downto 32);  -- Destination IP Address
                  v.ipv4Hdr(19) := rxMaster.tData(47 downto 40);  -- Destination IP Address   
                  -- Check for UDP data with inbound length/checksum
                  if (r.ipv4Det(0) = '1') and (r.udpDet(0) = '1') then
                     -- Mask off inbound UDP length/checksum
                     v.tData := rxMaster.tData(127 downto 112) & x"00000000" & rxMaster.tData(79 downto 0);
                  end if;
                  -- Track the number of bytes 
                  v.ipv4Len(0) := r.ipv4Len(0) + getTKeep(rxMaster.tKeep) - 6;
                  v.protLen(0) := r.protLen(0) + getTKeep(rxMaster.tKeep) - 6;
               end if;
               -- Check for EOF
               if (rxMaster.tLast = '1') then
                  -- Save the EOFE value
                  v.eofeDet(0) := axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, rxMaster, EMAC_EOFE_BIT_C);
                  -- Write the transaction data
                  v.tranWr     := '1';
                  -- Next state
                  v.state      := IDLE_S;
               else
                  -- Next state
                  v.state := MOVE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check if ready to move data
            if (rxMaster.tValid = '1') and (v.sMaster.tValid = '0') and (tranPause = '0') then
               -- Accept the data
               v.rxSlave.tReady := '1';
               -- Move data
               v.sMaster        := rxMaster;
               -- Fill in the TCP/UDP checksum
               v.tData          := rxMaster.tData;
               v.tKeep          := rxMaster.tKeep;
               -- Check for TCP data with inbound checksum
               if (r.ipv4Det(0) = '1') and (r.tcpDet(0) = '1') and (r.tcpFlag = '0') then
                  -- Set the flag
                  v.tcpFlag := '1';
                  -- Check if NON-VLAN
                  if (VLAN_G = false) then
                     -- Mask off inbound TCP checksum
                     v.tData := rxMaster.tData(127 downto 32) & x"0000" & rxMaster.tData(15 downto 0);
                  else
                     -- Mask off inbound TCP checksum
                     v.tData := rxMaster.tData(127 downto 64) & x"0000" & rxMaster.tData(47 downto 0);
                  end if;
               end if;
               -- Track the number of bytes 
               v.ipv4Len(0) := r.ipv4Len(0) + getTKeep(rxMaster.tKeep);
               v.protLen(0) := r.protLen(0) + getTKeep(rxMaster.tKeep);
               -- Check for EOF
               if (rxMaster.tLast = '1') or (v.ipv4Len(0) > MAX_FRAME_SIZE_C) then
                  -- Save the EOFE value
                  v.eofeDet(0) := axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, rxMaster, EMAC_EOFE_BIT_C);
                  -- Check for overflow
                  if (rxMaster.tLast = '0') then
                     -- Error detect
                     v.eofeDet(0) := '1';
                     -- Write the transaction data
                     v.tranWr     := '1';
                     -- Next state
                     v.state      := BLOWOFF_S;
                  else
                     -- Write the transaction data
                     v.tranWr := '1';
                     -- Next state
                     v.state  := IDLE_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when BLOWOFF_S =>
            -- Check if ready to move data
            if (rxMaster.tValid = '1') and (v.sMaster.tValid = '0') then
               -- Accept the data
               v.rxSlave.tReady := '1';
               -- Check for EOF
               if (rxMaster.tLast = '1') then
                  -- Next state
                  v.state := IDLE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Fill in the IPv4 header
      v.ipv4Hdr(2) := v.ipv4Len(0)(15 downto 8);  -- IPV4_Length(15 downto 8)
      v.ipv4Hdr(3) := v.ipv4Len(0)(7 downto 0);  -- IPV4_Length(7 downto 0)        

      -- Wait for the transaction data 
      if (tranValid = '1') and (r.tranRd = '0') then
         -- Check for data
         if (mMaster.tValid = '1') and (v.txMaster.tValid = '0') then
            -- Accept the data
            v.mSlave.tReady := '1';
            -- Move data
            v.txMaster      := mMaster;
            -- Check if not forwarding EOFE frames
            if (DROP_ERR_PKT_G = true) and (eofeDet = '1') then
               -- Do NOT move data
               v.txMaster.tValid := '0';
            end if;
            -- Check the counter size
            if (r.mvCnt /= 4) then
               -- Increment the counter
               v.mvCnt := r.mvCnt + 1;
            end if;
            -- Check for IPv4 checksum/length insertion 
            if (ipv4Det = '1') and (r.mvCnt = 1) then
               -- Check if NON-VLAN
               if (VLAN_G = false) then
                  -- Check if firmware checksum enabled
                  if (ipCsumEn = '1') then
                     -- Overwrite the data field
                     v.txMaster.tData(7 downto 0)   := ipv4Len(15 downto 8);
                     v.txMaster.tData(15 downto 8)  := ipv4Len(7 downto 0);
                     v.txMaster.tData(71 downto 64) := ipv4Csum(15 downto 8);
                     v.txMaster.tData(79 downto 72) := ipv4Csum(7 downto 0);
                  end if;
                  -- Check for mismatch between firmware/software IPv4 length
                  if (ipv4Len(15 downto 8) /= mMaster.tData(7 downto 0)) or (ipv4Len(7 downto 0) /= mMaster.tData(15 downto 8)) then
                     -- Set the flag
                     v.dbg(0) := '1';
                  end if;
                  -- Check for mismatch between firmware/software IPv4 checksum
                  if (ipv4Csum(15 downto 8) /= mMaster.tData(71 downto 64)) or (ipv4Csum(7 downto 0) /= mMaster.tData(79 downto 72)) then
                     -- Set the flag
                     v.dbg(1) := '1';
                  end if;
               else
                  -- Check if firmware checksum enabled
                  if (ipCsumEn = '1') then
                     -- Overwrite the data field
                     v.txMaster.tData(39 downto 32)   := ipv4Len(15 downto 8);
                     v.txMaster.tData(47 downto 40)   := ipv4Len(7 downto 0);
                     v.txMaster.tData(103 downto 96)  := ipv4Csum(15 downto 8);
                     v.txMaster.tData(111 downto 104) := ipv4Csum(7 downto 0);
                  end if;
                  -- Check for mismatch between firmware/software IPv4 length
                  if (ipv4Len(15 downto 8) /= mMaster.tData(39 downto 32)) or (ipv4Len(7 downto 0) /= mMaster.tData(47 downto 40)) then
                     -- Set the flag
                     v.dbg(0) := '1';
                  end if;
                  -- Check for mismatch between firmware/software IPv4 checksum
                  if (ipv4Csum(15 downto 8) /= mMaster.tData(103 downto 96)) or (ipv4Csum(7 downto 0) /= mMaster.tData(111 downto 104)) then
                     -- Set the flag
                     v.dbg(1) := '1';
                  end if;
               end if;
            end if;
            -- Check for UDP checksum/length insertion and no fragmentation
            if (ipv4Det = '1') and (udpDet = '1') and (fragDet = '0') and (r.mvCnt = 2) then
               -- Check if NON-VLAN
               if (VLAN_G = false) then
                  -- Check if firmware checksum enabled
                  if (udpCsumEn = '1') then
                     -- Overwrite the data field
                     v.txMaster.tData(55 downto 48) := protLen(15 downto 8);
                     v.txMaster.tData(63 downto 56) := protLen(7 downto 0);
                     v.txMaster.tData(71 downto 64) := protCsum(15 downto 8);
                     v.txMaster.tData(79 downto 72) := protCsum(7 downto 0);
                  end if;
                  -- Check for mismatch between firmware/software UDP length
                  if (protLen(15 downto 8) /= mMaster.tData(55 downto 48)) or (protLen(7 downto 0) /= mMaster.tData(63 downto 56)) then
                     -- Set the flag
                     v.dbg(2) := '1';
                  end if;
                  -- Check for mismatch between firmware/software UDP checksum
                  if (protCsum(15 downto 8) /= mMaster.tData(71 downto 64)) or (protCsum(7 downto 0) /= mMaster.tData(79 downto 72)) then
                     -- Set the flag
                     v.dbg(3) := '1';
                  end if;
               else
                  -- Check if firmware checksum enabled
                  if (udpCsumEn = '1') then
                     -- Overwrite the data field
                     v.txMaster.tData(87 downto 80)   := protLen(15 downto 8);
                     v.txMaster.tData(95 downto 88)   := protLen(7 downto 0);
                     v.txMaster.tData(103 downto 96)  := protCsum(15 downto 8);
                     v.txMaster.tData(111 downto 104) := protCsum(7 downto 0);
                  end if;
                  -- Check for mismatch between firmware/software UDP length
                  if (protLen(15 downto 8) /= mMaster.tData(87 downto 80)) or (protLen(7 downto 0) /= mMaster.tData(95 downto 88)) then
                     -- Set the flag
                     v.dbg(2) := '1';
                  end if;
                  -- Check for mismatch between firmware/software UDP checksum
                  if (protCsum(15 downto 8) /= mMaster.tData(103 downto 96)) or (protCsum(7 downto 0) /= mMaster.tData(111 downto 104)) then
                     -- Set the flag
                     v.dbg(3) := '1';
                  end if;
               end if;
            end if;
            -- Check for TCP checksum insertion and no fragmentation
            if (ipv4Det = '1') and (tcpDet = '1') and (fragDet = '0') and (r.mvCnt = 3) then
               -- Check if NON-VLAN
               if (VLAN_G = false) then
                  -- Check if firmware checksum enabled
                  if (tcpCsumEn = '1') then
                     -- Overwrite the data field
                     v.txMaster.tData(23 downto 16) := protCsum(15 downto 8);
                     v.txMaster.tData(31 downto 24) := protCsum(7 downto 0);
                  end if;
                  -- Check for mismatch between firmware/software TCP checksum
                  if (protCsum(15 downto 8) /= mMaster.tData(23 downto 16)) or (protCsum(7 downto 0) /= mMaster.tData(31 downto 24)) then
                     -- Set the flag
                     v.dbg(4) := '1';
                  end if;
               else
                  -- Check if firmware checksum enabled
                  if (tcpCsumEn = '1') then
                     -- Overwrite the data field
                     v.txMaster.tData(55 downto 48) := protCsum(15 downto 8);
                     v.txMaster.tData(63 downto 56) := protCsum(7 downto 0);
                  end if;
                  -- Check for mismatch between firmware/software TCP checksum
                  if (protCsum(15 downto 8) /= mMaster.tData(55 downto 48)) or (protCsum(7 downto 0) /= mMaster.tData(63 downto 56)) then
                     -- Set the flag
                     v.dbg(4) := '1';
                  end if;
               end if;
            end if;
            -- Check for tLast
            if (mMaster.tLast = '1') then
               -- Reset the counter
               v.mvCnt  := 0;
               -- Forward the EOFE               
               axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v.txMaster, EMAC_EOFE_BIT_C, eofeDet);
               v.dbg(5) := eofeDet;
               -- Accept the data
               v.tranRd := '1';
            end if;
         end if;
      end if;

      -- Reset
      if (ethRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      rxSlave  <= v.rxSlave;
      sMaster  <= r.sMaster;
      mSlave   <= v.mSlave;
      txMaster <= r.txMaster;

   end process comb;

   seq : process (ethClk) is
   begin
      if rising_edge(ethClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   Fifo_Cache : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => 0,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => true,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         CASCADE_SIZE_G      => ite(JUMBO_G, 2, 1),
         FIFO_ADDR_WIDTH_G   => 9,      -- 8kB per FIFO
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => EMAC_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => EMAC_AXIS_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => ethClk,
         sAxisRst    => ethRst,
         sAxisMaster => sMaster,
         sAxisSlave  => sSlave,
         -- Master Port
         mAxisClk    => ethClk,
         mAxisRst    => ethRst,
         mAxisMaster => mMaster,
         mAxisSlave  => mSlave);

   Fifo_Trans : entity work.FifoSync
      generic map (
         TPD_G        => TPD_G,
         BRAM_EN_G    => false,
         FWFT_EN_G    => true,
         DATA_WIDTH_G => 69,
         ADDR_WIDTH_G => 4,
         FULL_THRES_G => 8)
      port map (
         clk                => ethClk,
         rst                => ethRst,
         --Write Ports (wr_clk domain)
         wr_en              => r.calc(0).step(EMAC_CSUM_PIPELINE_C),
         din(68)            => r.fragDet(EMAC_CSUM_PIPELINE_C+1),
         din(67)            => r.eofeDet(EMAC_CSUM_PIPELINE_C+1),
         din(66)            => r.ipv4Det(EMAC_CSUM_PIPELINE_C+1),
         din(65)            => r.udpDet(EMAC_CSUM_PIPELINE_C+1),
         din(64)            => r.tcpDet(EMAC_CSUM_PIPELINE_C+1),
         din(63 downto 48)  => r.ipv4Len(EMAC_CSUM_PIPELINE_C+1),
         din(47 downto 32)  => r.ipv4Csum,
         din(31 downto 16)  => r.protLen(EMAC_CSUM_PIPELINE_C+1),
         din(15 downto 0)   => r.protCsum,
         prog_full          => tranPause,
         --Read Ports (rd_clk domain)
         rd_en              => r.tranRd,
         dout(68)           => fragDet,
         dout(67)           => eofeDet,
         dout(66)           => ipv4Det,
         dout(65)           => udpDet,
         dout(64)           => tcpDet,
         dout(63 downto 48) => ipv4Len,
         dout(47 downto 32) => ipv4Csum,
         dout(31 downto 16) => protLen,
         dout(15 downto 0)  => protCsum,
         valid              => tranValid);

   U_TxPipeline : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 1)
      port map (
         axisClk     => ethClk,
         axisRst     => ethRst,
         sAxisMaster => txMaster,
         sAxisSlave  => txSlave,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end rtl;
