-------------------------------------------------------------------------------
-- File       : IpV4EngineCoreTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-17
-- Last update: 2015-08-18
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the IpV4EngineCore
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

entity IpV4EngineCoreTb is
   generic (
      TPD_G        : time := 1 ns;
      LOCAL_MAC_G  : slv(47 downto 0);
      LOCAL_IP_G   : slv(31 downto 0);
      REMOTE_MAC_G : slv(47 downto 0);
      REMOTE_IP_G  : slv(31 downto 0);
      VLAN_G       : boolean;
      VID_G        : slv(15 downto 0);
      MAX_CNT_G    : natural;
      UDP_LEN_G    : natural);
   port (
      -- Interface to IPV4 Engine
      obProtocolMaster : out AxiStreamMasterType;
      obProtocolSlave  : in  AxiStreamSlaveType;
      ibProtocolMaster : in  AxiStreamMasterType;
      ibProtocolSlave  : out AxiStreamSlaveType;
      -- Interface to ARP Engine
      arpReqMaster     : out AxiStreamMasterType;
      arpReqSlave      : in  AxiStreamSlaveType;
      arpAckMaster     : in  AxiStreamMasterType;
      arpAckSlave      : out AxiStreamSlaveType;
      -- Simulation Result
      passed           : out sl;
      failed           : out sl;
      -- Clock and Reset
      clk              : in  sl;
      rst              : in  sl);
end IpV4EngineCoreTb;

architecture rtl of IpV4EngineCoreTb is

   type StateType is (
      IDLE_S,
      ARP_S,
      UDP_S,
      DONE_S); 

   type RegType is record
      passed           : sl;
      failed           : slv(5 downto 0);
      passedDly        : sl;
      failedDly        : sl;
      txDone           : sl;
      tKeep            : slv(15 downto 0);
      timer            : slv(15 downto 0);
      remoteMac        : slv(47 downto 0);
      len              : slv(15 downto 0);
      txCnt            : natural range 0 to 256;
      txWordCnt        : natural range 0 to 256;
      txWordSize       : natural range 0 to 256;
      txByteCnt        : natural range 0 to 16;
      rxCnt            : natural range 0 to 256;
      rxWordCnt        : natural range 0 to 256;
      rxWordSize       : natural range 0 to 256;
      rxByteCnt        : natural range 0 to 16;
      obProtocolMaster : AxiStreamMasterType;
      ibProtocolSlave  : AxiStreamSlaveType;
      arpReqMaster     : AxiStreamMasterType;
      arpAckSlave      : AxiStreamSlaveType;
      state            : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      passed           => '0',
      failed           => (others => '0'),
      passedDly        => '0',
      failedDly        => '0',
      txDone           => '0',
      tKeep            => (others => '1'),
      timer            => (others => '0'),
      remoteMac        => (others => '0'),
      len              => (others => '0'),
      txCnt            => 0,
      txWordCnt        => 0,
      txWordSize       => 0,
      txByteCnt        => 0,
      rxCnt            => 0,
      rxWordCnt        => 0,
      rxWordSize       => 0,
      rxByteCnt        => 0,
      obProtocolMaster => AXI_STREAM_MASTER_INIT_C,
      ibProtocolSlave  => AXI_STREAM_SLAVE_INIT_C,
      arpReqMaster     => AXI_STREAM_MASTER_INIT_C,
      arpAckSlave      => AXI_STREAM_SLAVE_INIT_C,
      state            => IDLE_S);      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (arpAckMaster, arpReqSlave, ibProtocolMaster, obProtocolSlave, r, rst) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.ibProtocolSlave := AXI_STREAM_SLAVE_INIT_C;
      if obProtocolSlave.tReady = '1' then
         v.obProtocolMaster.tValid := '0';
         v.obProtocolMaster.tLast  := '0';
         v.obProtocolMaster.tUser  := (others => '0');
         v.obProtocolMaster.tKeep  := (others => '1');
      end if;
      v.arpAckSlave := AXI_STREAM_SLAVE_INIT_C;
      if arpReqSlave.tReady = '1' then
         v.arpReqMaster.tValid := '0';
      end if;
      v.tKeep := (others => '1');

      -- Increment the timer
      if r.timer /= x"FFFF" then
         v.timer := r.timer + 1;
      else
         -- Timed out
         v.failed(0) := '1';
      end if;

      -- Create a delayed copy for easier viewing in simulation GUI
      v.passedDly := r.passed;
      v.failedDly := uOr(r.failed);

      -- Convert UDP_LEN_C to SLV
      v.len := toSlv(UDP_LEN_G, 16);

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Request the remote IpV4Engine's MAC address
            v.arpReqMaster.tValid             := '1';
            v.arpReqMaster.tData(31 downto 0) := REMOTE_IP_G;
            -- Reset the transaction timer
            v.timer                           := x"0000";
            -- Next state
            v.state                           := ARP_S;
         ----------------------------------------------------------------------
         when ARP_S =>
            -- Wait for the ARP response
            if arpAckMaster.tValid = '1' then
               -- Accept the data
               v.arpAckSlave.tReady := '1';
               -- Save the remote MAC address
               v.remoteMac          := arpAckMaster.tData(47 downto 0);
               -- Reset the transaction timer
               v.timer              := x"0000";
               -- Next state
               v.state              := UDP_S;
            end if;
         ----------------------------------------------------------------------
         when UDP_S =>
            ----------------------------------------------------------------------
            ----------------------------------------------------------------------
            ----------------------------------------------------------------------
            -- TX generate
            if (v.obProtocolMaster.tValid = '0') and (r.txDone = '0') then
               -- Move data
               v.obProtocolMaster.tValid := '1';
               if r.txCnt = 0 then
                  v.txCnt                                 := r.txCnt + 1;
                  ssiSetUserSof(EMAC_AXIS_CONFIG_C, v.obProtocolMaster, '1');
                  v.obProtocolMaster.tdata(47 downto 0)   := r.remoteMac;  -- Remote IP address
                  v.obProtocolMaster.tdata(63 downto 48)  := VID_G;        -- VLAN's ID
                  v.obProtocolMaster.tdata(95 downto 64)  := LOCAL_IP_G;   -- Source IPv4 Address
                  v.obProtocolMaster.tdata(127 downto 96) := REMOTE_IP_G;  -- Destination IPv4 Address
               elsif r.txCnt = 1 then
                  v.txCnt                                 := r.txCnt + 1;
                  v.obProtocolMaster.tdata(7 downto 0)    := x"00";        -- Zeros
                  v.obProtocolMaster.tdata(15 downto 8)   := UDP_C;        -- Protocol
                  v.obProtocolMaster.tdata(23 downto 16)  := r.len(15 downto 8);  -- Datagram Length
                  v.obProtocolMaster.tdata(31 downto 24)  := r.len(7 downto 0);   -- Datagram Length
                  v.obProtocolMaster.tdata(127 downto 32) := (others => '0');
               else
                  -- Send data
                  v.obProtocolMaster.tdata := toSlv(r.txWordCnt, 128);
                  -- Increment the counter
                  v.txWordCnt              := r.txWordCnt + 1;
                  -- Check for tLast
                  if r.txWordCnt = r.txWordSize then
                     -- Reset the counters
                     v.txCnt                  := 0;
                     v.txWordCnt              := 0;
                     -- Set EOF
                     v.obProtocolMaster.tLast := '1';
                     -- Increment the counter
                     v.txByteCnt              := r.txByteCnt + 1;
                     -- Loop through the tKeep byte field
                     for i in 15 downto 0 loop
                        if (i > r.txByteCnt) then
                           v.obProtocolMaster.tKeep(i) := '0';
                        end if;
                     end loop;
                     -- Check the counter
                     if r.txByteCnt = 15 then
                        -- Reset the counter
                        v.txByteCnt  := 0;
                        -- Increment the counter
                        v.txWordSize := r.txWordSize + 1;
                        -- Check if we are done
                        if r.txWordSize = 255 then
                           v.txDone := '1';
                        end if;
                     end if;
                  end if;
               end if;
            end if;
            ----------------------------------------------------------------------
            ----------------------------------------------------------------------
            ----------------------------------------------------------------------
            -- RX Comparator
            if ibProtocolMaster.tValid = '1' then
               -- Accept the data
               v.ibProtocolSlave.tReady := '1';
               if r.rxCnt = 0 then
                  -- Increment the counter
                  v.rxCnt := r.rxCnt + 1;
                  -- Check for errors
                  if (ssiGetUserSof(EMAC_AXIS_CONFIG_C, ibProtocolMaster) = '0')
                     or (ibProtocolMaster.tdata(47 downto 0) /= r.remoteMac)   -- Remote IP address
                     or (ibProtocolMaster.tdata(95 downto 64) /= REMOTE_IP_G)  -- Source IPv4 Address
                     or (ibProtocolMaster.tdata(127 downto 96) /= LOCAL_IP_G) then  -- Destination IPv4 Address
                     v.failed(1) := '1';
                  end if;
               elsif r.rxCnt = 1 then
                  -- Increment the counter
                  v.rxCnt := r.rxCnt + 1;
                  -- Check for errors
                  if (ibProtocolMaster.tdata(7 downto 0) /= x"00")         -- Zeros
                                    or (ibProtocolMaster.tdata(15 downto 8) /= UDP_C)  -- Protocol
                                    or (ibProtocolMaster.tdata(23 downto 16) /= r.len(15 downto 8))  -- Datagram Length
                                    or (ibProtocolMaster.tdata(31 downto 24) /= r.len(7 downto 0)) then  -- Datagram Length
                     v.failed(2) := '1';
                  end if;
               else
                  -- Increment the counter
                  v.rxWordCnt := r.rxWordCnt + 1;
                  -- Check for errors
                  if (ibProtocolMaster.tdata /= toSlv(r.rxWordCnt, 128)) then
                     v.failed(3) := '1';
                  end if;
                  -- Check if done with simulation test
                  if (uOr(v.failed) = '0') and ibProtocolMaster.tLast = '1' then
                     -- Reset the transaction timer
                     v.timer     := x"0000";
                     -- Reset the counters
                     v.rxCnt     := 0;
                     v.rxWordCnt := 0;
                     -- Increment the counter
                     v.rxByteCnt := r.rxByteCnt + 1;
                     -- Loop through the tKeep byte field
                     for i in 15 downto 0 loop
                        if (i > r.rxByteCnt) then
                           v.tKeep(i) := '0';
                        end if;
                     end loop;
                     -- Check for errors
                     if (v.tKeep /= ibProtocolMaster.tKeep) then
                        v.failed(4) := '1';
                     end if;
                     -- Check the counter
                     if r.rxByteCnt = 15 then
                        -- Reset the counter
                        v.rxByteCnt  := 0;
                        -- Increment the counter
                        v.rxWordSize := r.rxWordSize + 1;
                     end if;
                     -- Check for errors
                     if (r.rxWordSize /= r.rxWordCnt) then
                        v.failed(5) := '1';
                     end if;
                     -- Check for full word transfer and full size
                     if (ibProtocolMaster.tKeep = x"FFFF") and (r.rxWordCnt = 255) then
                        -- Next state
                        v.state := DONE_S;
                     end if;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when DONE_S =>
            v.passed := '1';
            v.timer  := x"0000";
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      arpAckSlave      <= v.arpAckSlave;
      arpReqMaster     <= r.arpReqMaster;
      ibProtocolSlave  <= v.ibProtocolSlave;
      obProtocolMaster <= r.obProtocolMaster;
      passed           <= r.passedDly;
      failed           <= r.failedDly;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
