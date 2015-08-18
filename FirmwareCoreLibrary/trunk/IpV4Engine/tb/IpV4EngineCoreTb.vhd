-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : IpV4EngineCoreTb.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-17
-- Last update: 2015-08-17
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
      failed           : sl;
      passedDly        : sl;
      failedDly        : sl;
      timer            : slv(15 downto 0);
      remoteMac        : slv(47 downto 0);
      len              : slv(15 downto 0);
      txCnt            : natural range 0 to MAX_CNT_G;
      rxCnt            : natural range 0 to MAX_CNT_G;
      obProtocolMaster : AxiStreamMasterType;
      ibProtocolSlave  : AxiStreamSlaveType;
      arpReqMaster     : AxiStreamMasterType;
      arpAckSlave      : AxiStreamSlaveType;
      state            : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      passed           => '0',
      failed           => '0',
      passedDly        => '0',
      failedDly        => '0',
      timer            => (others => '0'),
      remoteMac        => (others => '0'),
      len              => (others => '0'),
      txCnt            => 0,
      rxCnt            => 0,
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

      -- Increment the timer
      if r.timer /= x"FFFF" then
         v.timer := r.timer + 1;
      else
         -- Timed out
         v.failed := '1';
      end if;

      -- Create a delayed copy for easier viewing in simulation GUI
      v.passedDly := r.passed;
      v.failedDly := r.failed;

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
            -- TX generate
            if v.obProtocolMaster.tValid = '0' then
               -- Move data
               v.obProtocolMaster.tValid := '1';
               -- Increment the counter
               if r.txCnt /= MAX_CNT_G then
               end if;
               if r.txCnt = 0 then
                  v.txCnt                                 := r.txCnt + 1;
                  ssiSetUserSof(IP_ENGINE_CONFIG_C, v.obProtocolMaster, '1');
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
                  v.obProtocolMaster.tdata(127 downto 32) := toSlv(r.txCnt, 96);
               elsif r.txCnt /= MAX_CNT_G then
                  v.txCnt                  := r.txCnt + 1;
                  v.obProtocolMaster.tdata := toSlv(r.txCnt, 128);
                  if v.txCnt = MAX_CNT_G then
                     v.obProtocolMaster.tLast := '1';
                  end if;
               end if;
            end if;
            -- RX Comparator
            if ibProtocolMaster.tValid = '1' then
               -- Accept the data
               v.ibProtocolSlave.tReady := '1';
               if r.rxCnt = 0 then
                  -- Increment the counter
                  v.rxCnt := r.rxCnt + 1;
                  -- Check for errors
                  if (ssiGetUserSof(IP_ENGINE_CONFIG_C, ibProtocolMaster) = '0')
                     or (ibProtocolMaster.tdata(47 downto 0) /= r.remoteMac)   -- Remote IP address
                     or (ibProtocolMaster.tdata(95 downto 64) /= REMOTE_IP_G)  -- Source IPv4 Address
                     or (ibProtocolMaster.tdata(127 downto 96) /= LOCAL_IP_G) then  -- Destination IPv4 Address
                     v.failed := '1';
                  end if;
               elsif r.rxCnt = 1 then
                  -- Increment the counter
                  v.rxCnt := r.rxCnt + 1;
                  -- Check for errors
                  if (ibProtocolMaster.tdata(7 downto 0) /= x"00")         -- Zeros
                     or (ibProtocolMaster.tdata(15 downto 8) /= UDP_C)     -- Protocol
                     or (ibProtocolMaster.tdata(23 downto 16) /= r.len(15 downto 8))  -- Datagram Length
                     or (ibProtocolMaster.tdata(31 downto 24) /= r.len(7 downto 0))  -- Datagram Length
                     or (ibProtocolMaster.tdata(127 downto 32) /= toSlv(r.rxCnt, 96)) then
                     v.failed := '1';
                  end if;
               else
                  -- Increment the counter
                  v.rxCnt := r.rxCnt + 1;
                  -- Check for errors
                  if (ibProtocolMaster.tdata /= toSlv(r.rxCnt, 128)) then
                     v.failed := '1';
                  end if;
                  -- Check if done with simulation test
                  if (v.failed = '0') and ibProtocolMaster.tLast = '1' then
                     -- Reset the transaction timer
                     v.timer := x"0000";
                     -- Next state
                     v.state := DONE_S;
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
