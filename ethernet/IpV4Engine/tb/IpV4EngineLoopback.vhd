-------------------------------------------------------------------------------
-- File       : IpV4EngineLoopback.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-17
-- Last update: 2015-08-25
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the IpV4Engine in Loopback
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

entity IpV4EngineLoopback is
   generic (
      TPD_G      : time            := 1 ns;
      PROTOCOL_G : slv(7 downto 0) := UDP_C);
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
      start            : in  sl               := '0';
      remoteIp         : in  slv(31 downto 0) := (others => '0');
      done             : out sl;
      remoteMac        : out slv(47 downto 0);
      -- Clock and Reset
      clk              : in  sl;
      rst              : in  sl);
end IpV4EngineLoopback;

architecture rtl of IpV4EngineLoopback is

   type StateType is (
      IDLE_S,
      ARP_S,
      DONE_S); 

   type RegType is record
      ibProtocolSlave  : AxiStreamSlaveType;
      obProtocolMaster : AxiStreamMasterType;
      arpReqMaster     : AxiStreamMasterType;
      arpAckSlave      : AxiStreamSlaveType;
      done             : sl;
      remoteMac        : slv(47 downto 0);
      cnt              : slv(3 downto 0);
      state            : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      ibProtocolSlave  => AXI_STREAM_SLAVE_INIT_C,
      obProtocolMaster => AXI_STREAM_MASTER_INIT_C,
      arpReqMaster     => AXI_STREAM_MASTER_INIT_C,
      arpAckSlave      => AXI_STREAM_SLAVE_INIT_C,
      done             => '0',
      remoteMac        => (others => '0'),
      cnt              => (others => '0'),
      state            => IDLE_S);  

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";
   
begin

   comb : process (arpAckMaster, arpReqSlave, ibProtocolMaster, obProtocolSlave, r, remoteIp, rst,
                   start) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.ibProtocolSlave := AXI_STREAM_SLAVE_INIT_C;
      if obProtocolSlave.tReady = '1' then
         v.obProtocolMaster.tValid := '0';
      end if;
      v.arpAckSlave := AXI_STREAM_SLAVE_INIT_C;
      if arpReqSlave.tReady = '1' then
         v.arpReqMaster.tValid := '0';
      end if;

      -- Check for data
      if (ibProtocolMaster.tValid = '1') and (v.obProtocolMaster.tValid = '0') then
         -- Accept the data
         v.ibProtocolSlave.tReady := '1';
         -- Increment the counter
         if r.cnt /= x"F" then
            v.cnt := r.cnt + 1;
         end if;
         -- Move the data
         v.obProtocolMaster := ibProtocolMaster;
         -- Check if SOF
         if (ssiGetUserSof(EMAC_AXIS_CONFIG_C, ibProtocolMaster) = '1') then
            -- Swap the source and destination IP addresses in the IPv4 Pseudo Header 
            v.obProtocolMaster.tData(95 downto 64)  := ibProtocolMaster.tData(127 downto 96);
            v.obProtocolMaster.tData(127 downto 96) := ibProtocolMaster.tData(95 downto 64);
            -- Preset the counter
            v.cnt                                   := x"1";
         end if;
         -- Check if we need to swap the UDP ports
         if (PROTOCOL_G = UDP_C) and (r.cnt = 1) then
            -- Swap the source and destination UDP ports in the datagram 
            v.obProtocolMaster.tData(47 downto 32) := ibProtocolMaster.tData(63 downto 48);
            v.obProtocolMaster.tData(63 downto 48) := ibProtocolMaster.tData(47 downto 32);
         end if;
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            if start = '1' then
               -- Request the remote IpV4Engine's MAC address
               v.arpReqMaster.tValid             := '1';
               v.arpReqMaster.tData(31 downto 0) := remoteIp;
               -- Next state
               v.state                           := ARP_S;
            end if;
         ----------------------------------------------------------------------
         when ARP_S =>
            -- Wait for the ARP response
            if arpAckMaster.tValid = '1' then
               -- Accept the data
               v.arpAckSlave.tReady := '1';
               -- Save the remote MAC address
               v.remoteMac          := arpAckMaster.tData(47 downto 0);
               -- Next state
               v.state              := DONE_S;
            end if;
         ----------------------------------------------------------------------
         when DONE_S =>
            v.done := '1';
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs              
      ibProtocolSlave  <= v.ibProtocolSlave;
      obProtocolMaster <= r.obProtocolMaster;
      arpAckSlave      <= v.arpAckSlave;
      arpReqMaster     <= r.arpReqMaster;
      done             <= r.done;
      remoteMac        <= r.remoteMac;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
