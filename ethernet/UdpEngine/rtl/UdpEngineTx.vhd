-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: UDP TX Engine Module
-- Note: UDP checksum checked in EthMac core
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
use surf.SsiPkg.all;
use surf.EthMacPkg.all;

entity UdpEngineTx is
   generic (
      -- Simulation Generics
      TPD_G          : time          := 1 ns;
      -- UDP General Generic
      SIZE_G         : positive      := 1;
      TX_FLOW_CTRL_G : boolean       := true;  -- True: Blow off the UDP TX data if link down, False: Backpressure until TX link is up
      IS_CLIENT_G    : boolean       := false;
      PORT_G         : PositiveArray := (0 => 8192));
   port (
      -- Interface to IPV4 Engine
      obUdpMaster   : out AxiStreamMasterType;
      obUdpSlave    : in  AxiStreamSlaveType;
      -- Interface to User Application
      linkUp        : out slv(SIZE_G-1 downto 0);
      localMac      : in  slv(47 downto 0);
      localIp       : in  slv(31 downto 0);
      remotePort    : in  Slv16Array(SIZE_G-1 downto 0);
      remoteIp      : in  Slv32Array(SIZE_G-1 downto 0);
      remoteMac     : in  Slv48Array(SIZE_G-1 downto 0);
      ibMasters     : in  AxiStreamMasterArray(SIZE_G-1 downto 0);
      ibSlaves      : out AxiStreamSlaveArray(SIZE_G-1 downto 0);
      arpTabPos     : out Slv8Array(SIZE_G-1 downto 0);
      arpTabFound   : in  slv(SIZE_G-1 downto 0)        := (others => '0');
      arpTabIpAddr  : in  Slv32Array(SIZE_G-1 downto 0) := (others => (others => '0'));
      arpTabMacAddr : in  Slv48Array(SIZE_G-1 downto 0) := (others => (others => '0'));
      -- Interface to DHCP Engine
      obDhcpMaster  : in  AxiStreamMasterType           := AXI_STREAM_MASTER_INIT_C;
      obDhcpSlave   : out AxiStreamSlaveType;
      -- Clock and Reset
      clk           : in  sl;
      rst           : in  sl);
end UdpEngineTx;

architecture rtl of UdpEngineTx is

   constant PORT_C : Slv16Array(SIZE_G-1 downto 0) := EthPortArrayBigEndian(PORT_G, SIZE_G);

   type StateType is (
      IDLE_S,
      ACC_ARP_TAB_S,
      DHCP_HDR_S,
      HDR_S,
      DHCP_BUFFER_S,
      BUFFER_S,
      LAST_S);

   type RegType is record
      linkUp      : slv(SIZE_G-1 downto 0);
      tKeep       : slv(15 downto 0);
      tData       : slv(127 downto 0);
      tLast       : sl;
      eofe        : sl;
      chPntr      : natural range 0 to SIZE_G-1;
      index       : natural range 0 to SIZE_G-1;
      arpPos      : Slv8Array(SIZE_G-1 downto 0);
      obDhcpSlave : AxiStreamSlaveType;
      ibSlaves    : AxiStreamSlaveArray(SIZE_G-1 downto 0);
      txMaster    : AxiStreamMasterType;
      state       : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      linkUp      => (others => '0'),
      tKeep       => (others => '0'),
      tData       => (others => '0'),
      tLast       => '0',
      eofe        => '0',
      chPntr      => 0,
      index       => 0,
      arpPos      => (others => (others => '0')),
      obDhcpSlave => AXI_STREAM_SLAVE_INIT_C,
      ibSlaves    => (others => AXI_STREAM_SLAVE_INIT_C),
      txMaster    => AXI_STREAM_MASTER_INIT_C,
      state       => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal txMaster : AxiStreamMasterType;
   signal txSlave  : AxiStreamSlaveType;

   -- attribute dont_touch             : string;
   -- attribute dont_touch of r        : signal is "TRUE";

begin

   comb : process (ibMasters, localIp, localMac, obDhcpMaster, r, remoteIp,
                   remoteMac, remotePort, rst, txSlave) is
      variable v       : RegType;
      variable arpPosV : Slv8Array(SIZE_G-1 downto 0);
      variable i       : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.obDhcpSlave := AXI_STREAM_SLAVE_INIT_C;
      v.ibSlaves    := (others => AXI_STREAM_SLAVE_INIT_C);
      if (txSlave.tReady = '1') then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
         v.txMaster.tKeep  := (others => '1');
      end if;

      for i in SIZE_G-1 downto 0 loop
         -- Check if link is up
         if (localMac /= 0) and         -- Non-zero local MAC address
                       (localIp /= 0) and       -- Non-zero local IP address
                       (PORT_G(i) /= 0) and     -- Non-zero local UDP port
                       (remoteMac(i) /= 0) and  -- Non-zero remote MAC address
                       (remoteIp(i) /= 0) and   -- Non-zero remote IP address
                       (remotePort(i) /= 0) then  -- Non-zero remote UDP port
            -- Link Up
            v.linkUp(i) := '1';
         else
            -- Link down
            v.linkUp(i) := '0';
         end if;
      end loop;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for roll over
            if (r.index = (SIZE_G-1)) then
               -- Reset the counter
               v.index := 0;
            else
               -- Increment the counter
               v.index := r.index + 1;
            end if;
            -- Check for DHCP data and remote MAC is non-zero
            if (obDhcpMaster.tValid = '1') and (v.txMaster.tValid = '0') then
               -- Check for SOF
               if (ssiGetUserSof(EMAC_AXIS_CONFIG_C, obDhcpMaster) = '1') then
                  -- Write the first header
                  v.txMaster.tValid               := '1';
                  v.txMaster.tData(47 downto 0)   := (others => '1');  -- Destination MAC address
                  v.txMaster.tData(63 downto 48)  := x"0000";     -- All 0s
                  v.txMaster.tData(95 downto 64)  := (others => '0');  -- Source IP address
                  v.txMaster.tData(127 downto 96) := (others => '1');  -- Destination IP address
                  ssiSetUserSof(EMAC_AXIS_CONFIG_C, v.txMaster, '1');
                  -- Next state
                  v.state                         := DHCP_HDR_S;
               else
                  -- Blow off the data
                  v.obDhcpSlave.tReady := '1';
               end if;
            -- Check for data and remote MAC is non-zero
            elsif (ibMasters(r.index).tValid = '1') and (v.txMaster.tValid = '0') then
               -- Check if need to access ARP Table
               if ibMasters(r.index).tDest = x"00" or IS_CLIENT_G = false then
                  -- Check if link down and blowing off the data
                  if (r.linkUp(r.index) = '0') and TX_FLOW_CTRL_G then
                     -- Blow off the data
                     v.ibSlaves(r.index).tReady := '1';
                  -- Check for SOF
                  elsif (ssiGetUserSof(EMAC_AXIS_CONFIG_C, ibMasters(r.index)) = '1') then
                     -- Check if link up
                     if (r.linkUp(r.index) = '1') then
                        -- Latch the index
                        v.chPntr                        := r.index;
                        -- Write the first header
                        v.txMaster.tValid               := '1';
                        v.txMaster.tData(47 downto 0)   := remoteMac(r.index);  -- Destination MAC address
                        v.txMaster.tData(63 downto 48)  := x"0000";  -- All 0s
                        v.txMaster.tData(95 downto 64)  := localIp;  -- Source IP address
                        v.txMaster.tData(127 downto 96) := remoteIp(r.index);  -- Destination IP address
                        ssiSetUserSof(EMAC_AXIS_CONFIG_C, v.txMaster, '1');
                        -- Next state
                        v.state                         := HDR_S;
                     end if;
                  else
                     -- Blow off the data
                     v.ibSlaves(r.index).tReady := '1';
                  end if;
               else
                  v.chPntr         := r.index;
                  arpPosV(r.index) := ibMasters(r.index).tDest;
                  v.state          := ACC_ARP_TAB_S;
               end if;
            end if;
         -----------------------------------------------------------------------
         when ACC_ARP_TAB_S =>
            arpPosV(r.chPntr) := ibMasters(r.chPntr).tDest;
            if arpTabFound(r.chPntr) = '0' then
               v.linkUp(r.chPntr)          := '0';
               -- Blow off the data..
               v.ibSlaves(r.chPntr).tReady := '1';
               -- ..until the last frame
               if (ssiGetUserEofe(EMAC_AXIS_CONFIG_C, ibMasters(r.chPntr)) = '1' or ibMasters(r.chPntr).tLast = '1') then
                  v.state := IDLE_S;
               end if;
            else
               -- Check if link down and blowing off the data
               if (r.linkUp(r.chPntr) = '0') and TX_FLOW_CTRL_G then
                  -- Blow off the data..
                  v.ibSlaves(r.chPntr).tReady := '1';
                  -- ..until the last frame
                  if (ssiGetUserEofe(EMAC_AXIS_CONFIG_C, ibMasters(r.chPntr)) = '1' or ibMasters(r.chPntr).tLast = '1') then
                     v.state := IDLE_S;
                  end if;
               -- Check for SOF
               elsif (ssiGetUserSof(EMAC_AXIS_CONFIG_C, ibMasters(r.chPntr)) = '1') then
                  -- Check if link up
                  if (r.linkUp(r.chPntr) = '1') then
                     -- Latch the index
                     v.chPntr                        := r.chPntr;
                     -- Write the first header
                     v.txMaster.tValid               := '1';
                     v.txMaster.tData(47 downto 0)   := arpTabMacAddr(r.chPntr);  -- Destination MAC address
                     v.txMaster.tData(63 downto 48)  := x"0000";  -- All 0s
                     v.txMaster.tData(95 downto 64)  := localIp;  -- Source IP address
                     v.txMaster.tData(127 downto 96) := arpTabIpAddr(r.chPntr);  -- Destination IP address
                     ssiSetUserSof(EMAC_AXIS_CONFIG_C, v.txMaster, '1');
                     -- Next state
                     v.state                         := HDR_S;
                  end if;
               else
                  -- Blow off the data..
                  v.ibSlaves(r.chPntr).tReady := '1';
                  -- ..until the last frame
                  if (ssiGetUserEofe(EMAC_AXIS_CONFIG_C, ibMasters(r.chPntr)) = '1' or ibMasters(r.chPntr).tLast = '1') then
                     v.state := IDLE_S;
                  end if;
               end if;
            end if;

         ------------------------------------------------
         -- Notes: Non-Standard IPv4 Pseudo Header Format
         ------------------------------------------------
         -- tData[0][47:0]   = DST MAC Address
         -- tData[0][63:48]  = zeros
         -- tData[0][95:64]  = SRC IP Address
         -- tData[0][127:96] = DST IP address
         -- tData[1][7:0]    = zeros
         -- tData[1][15:8]   = Protocol Type = UDP
         -- tData[1][31:16]  = IPv4 Pseudo header length
         -- tData[1][47:32]  = SRC Port
         -- tData[1][63:48]  = DST Port
         -- tData[1][79:64]  = UDP Length
         -- tData[1][95:80]  = UDP Checksum
         -- tData[1][127:96] = UDP Datagram
         ------------------------------------------------
         ----------------------------------------------------------------------
         when DHCP_HDR_S =>
            -- Check if ready to move data
            if (obDhcpMaster.tValid = '1') and (v.txMaster.tValid = '0') then
               -- Accept the data
               v.obDhcpSlave.tReady            := '1';
               -- Write the Second header
               v.txMaster.tValid               := '1';
               v.txMaster.tData(7 downto 0)    := x"00";  -- All 0s
               v.txMaster.tData(15 downto 8)   := UDP_C;  -- Protocol Type = UDP
               v.txMaster.tData(31 downto 16)  := x"0000";  -- IPv4 Pseudo header length = Calculated in EthMac core
               v.txMaster.tData(47 downto 32)  := DHCP_CPORT;  -- Source port
               v.txMaster.tData(63 downto 48)  := DHCP_SPORT;  -- Destination port
               v.txMaster.tData(79 downto 64)  := x"0000";  -- UDP length = Calculated in EthMac core
               v.txMaster.tData(95 downto 80)  := x"0000";  -- UDP checksum  = Calculated in EthMac core
               v.txMaster.tData(127 downto 96) := obDhcpMaster.tData(31 downto 0);  -- UDP Datagram
               v.txMaster.tKeep(11 downto 0)   := x"FFF";
               v.txMaster.tKeep(15 downto 12)  := obDhcpMaster.tKeep(3 downto 0);  -- UDP Datagram
               -- Track the leftovers
               v.tData(95 downto 0)            := obDhcpMaster.tData(127 downto 32);
               v.tData(127 downto 96)          := (others => '0');
               v.tKeep(11 downto 0)            := obDhcpMaster.tKeep(15 downto 4);
               v.tKeep(15 downto 12)           := (others => '0');
               v.tLast                         := obDhcpMaster.tLast;
               v.eofe                          := ssiGetUserEofe(EMAC_AXIS_CONFIG_C, obDhcpMaster);
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
               else
                  -- Next state
                  v.state := DHCP_BUFFER_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when HDR_S =>
            -- Check if ready to move data
            if (ibMasters(r.chPntr).tValid = '1') and (v.txMaster.tValid = '0') then
               -- Accept the data
               v.ibSlaves(r.chPntr).tReady     := '1';
               -- Write the Second header
               v.txMaster.tValid               := '1';
               v.txMaster.tData(7 downto 0)    := x"00";  -- All 0s
               v.txMaster.tData(15 downto 8)   := UDP_C;  -- Protocol Type = UDP
               v.txMaster.tData(31 downto 16)  := x"0000";  -- IPv4 Pseudo header length = Calculated in EthMac core
               v.txMaster.tData(47 downto 32)  := PORT_C(r.chPntr);  -- Source port
               v.txMaster.tData(63 downto 48)  := remotePort(r.chPntr);  -- Destination port
               v.txMaster.tData(79 downto 64)  := x"0000";  -- UDP length = Calculated in EthMac core
               v.txMaster.tData(95 downto 80)  := x"0000";  -- UDP checksum  = Calculated in EthMac core
               v.txMaster.tData(127 downto 96) := ibMasters(r.chPntr).tData(31 downto 0);  -- UDP Datagram
               v.txMaster.tKeep(11 downto 0)   := x"FFF";
               v.txMaster.tKeep(15 downto 12)  := ibMasters(r.chPntr).tKeep(3 downto 0);  -- UDP Datagram
               -- Track the leftovers
               v.tData(95 downto 0)            := ibMasters(r.chPntr).tData(127 downto 32);
               v.tData(127 downto 96)          := (others => '0');
               v.tKeep(11 downto 0)            := ibMasters(r.chPntr).tKeep(15 downto 4);
               v.tKeep(15 downto 12)           := (others => '0');
               v.tLast                         := ibMasters(r.chPntr).tLast;
               v.eofe                          := ssiGetUserEofe(EMAC_AXIS_CONFIG_C, ibMasters(r.chPntr));
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
               else
                  -- Next state
                  v.state := BUFFER_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when DHCP_BUFFER_S =>
            -- Check if ready to move data
            if (obDhcpMaster.tValid = '1') and (v.txMaster.tValid = '0') then
               -- Accept the data
               v.obDhcpSlave.tReady            := '1';
               -- Write the Second header
               v.txMaster.tValid               := '1';
               -- Move the data
               v.txMaster.tData(95 downto 0)   := r.tData(95 downto 0);
               v.txMaster.tData(127 downto 96) := obDhcpMaster.tData(31 downto 0);
               v.txMaster.tKeep(11 downto 0)   := r.tKeep(11 downto 0);
               v.txMaster.tKeep(15 downto 12)  := obDhcpMaster.tKeep(3 downto 0);
               -- Track the leftovers
               v.tData(95 downto 0)            := obDhcpMaster.tData(127 downto 32);
               v.tKeep(11 downto 0)            := obDhcpMaster.tKeep(15 downto 4);
               v.tLast                         := obDhcpMaster.tLast;
               v.eofe                          := ssiGetUserEofe(EMAC_AXIS_CONFIG_C, obDhcpMaster);
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
         when BUFFER_S =>
            -- Check if ready to move data
            if (ibMasters(r.chPntr).tValid = '1') and (v.txMaster.tValid = '0') then
               -- Accept the data
               v.ibSlaves(r.chPntr).tReady     := '1';
               -- Write the Second header
               v.txMaster.tValid               := '1';
               -- Move the data
               v.txMaster.tData(95 downto 0)   := r.tData(95 downto 0);
               v.txMaster.tData(127 downto 96) := ibMasters(r.chPntr).tData(31 downto 0);
               v.txMaster.tKeep(11 downto 0)   := r.tKeep(11 downto 0);
               v.txMaster.tKeep(15 downto 12)  := ibMasters(r.chPntr).tKeep(3 downto 0);
               -- Track the leftovers
               v.tData(95 downto 0)            := ibMasters(r.chPntr).tData(127 downto 32);
               v.tKeep(11 downto 0)            := ibMasters(r.chPntr).tKeep(15 downto 4);
               v.tLast                         := ibMasters(r.chPntr).tLast;
               v.eofe                          := ssiGetUserEofe(EMAC_AXIS_CONFIG_C, ibMasters(r.chPntr));
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
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Move the data
               v.txMaster.tValid              := '1';
               v.txMaster.tData(127 downto 0) := r.tData;
               v.txMaster.tKeep(15 downto 0)  := r.tKeep;
               v.txMaster.tLast               := '1';
               ssiSetUserEofe(EMAC_AXIS_CONFIG_C, v.txMaster, r.eofe);
               -- Next state
               v.state                        := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      ibSlaves    <= v.ibSlaves;
      obDhcpSlave <= v.obDhcpSlave;
      txMaster    <= r.txMaster;
      linkUp      <= r.linkUp;
      arpTabPos   <= arpPosV;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_TxPipeline : entity surf.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 1)
      port map (
         axisClk     => clk,
         axisRst     => rst,
         sAxisMaster => txMaster,
         sAxisSlave  => txSlave,
         mAxisMaster => obUdpMaster,
         mAxisSlave  => obUdpSlave);

end rtl;
