-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: UDP Client's ARP Messaging Module
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity UdpEngineArp is
   generic (
      TPD_G          : time     := 1 ns;
      CLIENT_SIZE_G  : positive := 1;
      CLK_FREQ_G     : real     := 156.25E+06;
      COMM_TIMEOUT_G : positive := 30;
      RESP_TIMEOUT_G : positive := 5);
   port (
      -- Local Configurations
      localIp              : in  slv(31 downto 0);  --  big-Endian configuration
      -- Interface to ARP Engine
      arpReqMasters        : out AxiStreamMasterArray(CLIENT_SIZE_G-1 downto 0);  -- Request via IP address
      arpReqSlaves         : in  AxiStreamSlaveArray(CLIENT_SIZE_G-1 downto 0);
      arpAckMasters        : in  AxiStreamMasterArray(CLIENT_SIZE_G-1 downto 0);  -- Respond with MAC address
      arpAckSlaves         : out AxiStreamSlaveArray(CLIENT_SIZE_G-1 downto 0);
      -- Interface to ARP Table
      arpTabFound          : in  slv(CLIENT_SIZE_G-1 downto 0);
      arpTabMacAddr        : in  Slv48Array(CLIENT_SIZE_G-1 downto 0);
      arpTabIpWe           : out slv(CLIENT_SIZE_G-1 downto 0);
      arpTabMacWe          : out slv(CLIENT_SIZE_G-1 downto 0);
      arpTabMacAddrW       : out Slv48Array(CLIENT_SIZE_G-1 downto 0);
      -- Interface to UDP Client engine(s)
      clientRemoteDetValid : in  slv(CLIENT_SIZE_G-1 downto 0);
      clientRemoteDetIp    : in  Slv32Array(CLIENT_SIZE_G-1 downto 0);
      clientRemoteIp       : in  Slv32Array(CLIENT_SIZE_G-1 downto 0);
      clientRemoteMac      : out Slv48Array(CLIENT_SIZE_G-1 downto 0);
      -- Clock and Reset
      clk                  : in  sl;
      rst                  : in  sl);
end UdpEngineArp;

architecture rtl of UdpEngineArp is

   constant TIMER_1_SEC_C : natural := getTimeRatio(CLK_FREQ_G, 1.0);
   type TimerArray is array (natural range <>) of natural range 0 to COMM_TIMEOUT_G;

   type StateType is (
      CHECK_S,
      IDLE_S,
      WAIT_S,
      COMM_MONITOR_S);
   type StateArray is array (natural range <>) of StateType;

   type RegType is record
      clientRemoteMac     : Slv48Array(CLIENT_SIZE_G-1 downto 0);
      clientRemoteMacWrEn : slv(CLIENT_SIZE_G-1 downto 0);
      clientRemoteIpWrEn  : slv(CLIENT_SIZE_G-1 downto 0);
      arpAckSlaves        : AxiStreamSlaveArray(CLIENT_SIZE_G-1 downto 0);
      arpReqMasters       : AxiStreamMasterArray(CLIENT_SIZE_G-1 downto 0);
      timerEn             : sl;
      timer               : natural range 0 to (TIMER_1_SEC_C-1);
      arpTimers           : TimerArray(CLIENT_SIZE_G-1 downto 0);
      respTimers          : TimerArray(CLIENT_SIZE_G-1 downto 0);
      state               : StateArray(CLIENT_SIZE_G-1 downto 0);
   end record RegType;
   constant REG_INIT_C : RegType := (
      clientRemoteMac     => (others => (others => '0')),
      clientRemoteMacWrEn => (others => '0'),
      clientRemoteIpWrEn  => (others => '0'),
      arpAckSlaves        => (others => AXI_STREAM_SLAVE_INIT_C),
      arpReqMasters       => (others => AXI_STREAM_MASTER_INIT_C),
      timerEn             => '0',
      timer               => 0,
      arpTimers           => (others => 0),
      respTimers          => (others => 0),
      state               => (others => IDLE_S));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (arpAckMasters, arpReqSlaves, arpTabFound, arpTabMacAddr,
                   clientRemoteDetIp, clientRemoteDetValid, clientRemoteIp, r,
                   rst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.timerEn             := '0';
      v.clientRemoteMacWrEn := (others => '0');
      v.clientRemoteIpWrEn  := (others => '0');
      for i in CLIENT_SIZE_G-1 downto 0 loop
         v.arpAckSlaves(i) := AXI_STREAM_SLAVE_INIT_C;
         if arpReqSlaves(i).tReady = '1' then
            v.arpReqMasters(i).tValid := '0';
         end if;
      end loop;


      -- Increment the timer
      if r.timer = (TIMER_1_SEC_C-1) then
         v.timer   := 0;
         v.timerEn := '1';
      else
         v.timer := r.timer + 1;
      end if;

      -- Loop through the clients
      for i in CLIENT_SIZE_G-1 downto 0 loop

         -- Update the timers
         if (r.timerEn = '1') and (r.arpTimers(i) /= 0) then
            -- Decrement the timers
            v.arpTimers(i) := r.arpTimers(i) - 1;
         end if;
         if (r.timerEn = '1') and (r.respTimers(i) /= 0) then
            -- Decrement the timers
            v.respTimers(i) := r.respTimers(i) - 1;
         end if;

         -- Check for dynamic change in IP address
         if (clientRemoteIp(i) = 0) then
            -- Stop any outstanding requests
            v.arpReqMasters(i).tValid := '0';
            -- Reset the remote MAC address
            v.clientRemoteMac(i)      := (others => '0');
            -- Next state
            v.state(i)                := IDLE_S;
         elsif (r.arpReqMasters(i).tData(31 downto 0) /= clientRemoteIp(i)) then
            -- Update the IP address
            v.arpReqMasters(i).tData(31 downto 0) := clientRemoteIp(i);
            -- Stop any outstanding requests
            v.arpReqMasters(i).tValid             := '0';
            -- Reset the remote MAC address
            v.clientRemoteMac(i)                  := (others => '0');
            -- Next state
            v.state(i)                            := CHECK_S;
         else
            -- State Machine
            case r.state(i) is
               ----------------------------------------------------------------------
               when CHECK_S =>
                  if arpTabFound(i) = '1' then
                     -- Set found MAC addr
                     v.clientRemoteMac(i) := arpTabMacAddr(i);
                     -- Preset the timer
                     v.arpTimers(i)       := COMM_TIMEOUT_G;
                     -- Next state
                     v.state(i)           := COMM_MONITOR_S;
                  else
                     -- Write IP to ARP table
                     v.clientRemoteIpWrEn(i) := '1';
                     -- Next state
                     v.state(i)              := IDLE_S;
                  end if;
               ----------------------------------------------------------------------
               when IDLE_S =>
                  -- Reset the counter
                  v.arpTimers(i) := 0;
                  -- Check if we have a non-zero IP address to request
                  if clientRemoteIp(i) /= 0 then
                     -- Make an ARP request
                     v.arpReqMasters(i).tValid := '1';
                     -- Set the response timer
                     v.respTimers(i)           := RESP_TIMEOUT_G;
                     -- Next state
                     v.state(i)                := WAIT_S;
                  end if;
               ----------------------------------------------------------------------
               when WAIT_S =>
                  -- Reset the remote MAC address if ARP response times out
                  if r.respTimers(i) = 0 then
                     v.clientRemoteMac(i) := (others => '0');
                  end if;
                  -- Wait for the ARP response
                  if arpAckMasters(i).tValid = '1' then
                     -- Accept the data
                     v.arpAckSlaves(i).tReady := '1';
                     -- Latch the MAC address value
                     v.clientRemoteMac(i)     := arpAckMasters(i).tData(47 downto 0);
                     -- Write to ARP table
                     v.clientRemoteMacWrEn(i) := '1';
                     -- Preset the timer
                     v.arpTimers(i)           := COMM_TIMEOUT_G;
                     -- Next state
                     v.state(i)               := COMM_MONITOR_S;
                  end if;
               ----------------------------------------------------------------------
               when COMM_MONITOR_S =>
                  -- Check for inbound client communication
                  if clientRemoteDetValid(i) = '1' and clientRemoteDetIp(i) = clientRemoteIp(i) then
                     -- Preset the timer
                     v.arpTimers(i) := COMM_TIMEOUT_G;
                  elsif r.arpTimers(i) = 0 then
                     -- Next state
                     v.state(i) := IDLE_S;
                  end if;
            ----------------------------------------------------------------------
            end case;
         end if;
      end loop;

      -- Combinatorial outputs before the reset
      arpAckSlaves <= v.arpAckSlaves;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Registered Outputs
      arpReqMasters   <= r.arpReqMasters;
      clientRemoteMac <= r.clientRemoteMac;
      arpTabIpWe      <= r.clientRemoteIpWrEn;
      arpTabMacWe     <= r.clientRemoteMacWrEn;
      arpTabMacAddrW  <= r.clientRemoteMac;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
