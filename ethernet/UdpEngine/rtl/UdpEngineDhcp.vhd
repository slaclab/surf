-------------------------------------------------------------------------------
-- File       : UdpEngineDhcp.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-08-12
-- Last update: 2016-09-16
-------------------------------------------------------------------------------
-- Description: DHCP Engine
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

entity UdpEngineDhcp is
   generic (
      -- Simulation Generics
      TPD_G          : time     := 1 ns;
      -- UDP ARP/DHCP Generics
      CLK_FREQ_G     : real     := 156.25E+06;  -- In units of Hz
      COMM_TIMEOUT_G : positive := 30);  
   port (
      -- Local Configurations
      localMac     : in  slv(47 downto 0);      --  big-Endian configuration
      localIp      : in  slv(31 downto 0);      --  big-Endian configuration 
      dhcpIp       : out slv(31 downto 0);      --  big-Endian configuration       
      -- Interface to DHCP Engine  
      ibDhcpMaster : in  AxiStreamMasterType;
      ibDhcpSlave  : out AxiStreamSlaveType;
      obDhcpMaster : out AxiStreamMasterType;
      obDhcpSlave  : in  AxiStreamSlaveType;
      -- Clock and Reset
      clk          : in  sl;
      rst          : in  sl);
end UdpEngineDhcp;

architecture rtl of UdpEngineDhcp is

   constant DHCP_CONFIG_C  : AxiStreamConfigType := ssiAxiStreamConfig(4);
   constant TIMER_1_SEC_C  : natural             := getTimeRatio(CLK_FREQ_G, 1.0);
   constant CLIENT_HDR_C   : slv(31 downto 0)    := x"00060101";  -- 0x01010600
   constant SERVER_HDR_C   : slv(31 downto 0)    := x"00060102";  -- 0x02010600
   constant MAGIC_COOKIE_C : slv(31 downto 0)    := x"63538263";  -- 0x63825363
   constant COMM_TIMEOUT_C : positive            := ite((COMM_TIMEOUT_G > 3), COMM_TIMEOUT_G, 3);

   type StateType is (
      IDLE_S,
      REQ_S,
      BOOTP_S,
      DHCP_S,
      VERIFY_S);

   type DecodeType is (
      CODE_S,
      LEN_S,
      DATA_S);      

   type RegType is record
      heartbeat  : sl;
      cnt        : natural range 0 to 127;
      timer      : natural range 0 to (TIMER_1_SEC_C-1);
      commCnt    : natural range 0 to COMM_TIMEOUT_C;
      renewCnt   : slv(30 downto 0);
      leaseCnt   : slv(31 downto 0);
      leaseTime  : slv(31 downto 0);
      remoteMac  : slv(47 downto 0);
      remoteIp   : slv(31 downto 0);
      dhcpIp     : slv(31 downto 0);
      dhcpReq    : sl;
      xid        : slv(31 downto 0);
      yiaddr     : slv(31 downto 0);
      siaddr     : slv(31 downto 0);
      yiaddrTemp : slv(31 downto 0);
      siaddrTemp : slv(31 downto 0);
      index      : natural range 0 to 3;
      valid      : slv(4 downto 0);
      opCode     : slv(7 downto 0);
      len        : slv(7 downto 0);
      msgType    : slv(7 downto 0);
      rxSlave    : AxiStreamSlaveType;
      txMaster   : AxiStreamMasterType;
      decode     : DecodeType;
      state      : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      heartbeat  => '0',
      cnt        => 0,
      timer      => 0,
      commCnt    => 3,                  -- Default to 3 seconds after bootup
      renewCnt   => (others => '0'),
      leaseCnt   => (others => '0'),
      leaseTime  => (others => '0'),
      remoteMac  => (others => '1'),    -- Broadcast MAC Address
      remoteIp   => (others => '1'),    -- Broadcast IP Address
      dhcpIP     => (others => '0'),
      dhcpReq    => '0',
      xid        => (others => '0'),
      yiaddr     => (others => '0'),
      siaddr     => (others => '0'),
      yiaddrTemp => (others => '0'),
      siaddrTemp => (others => '0'),
      index      => 0,
      valid      => (others => '0'),
      opCode     => (others => '0'),
      len        => (others => '0'),
      msgType    => (others => '0'),
      rxSlave    => AXI_STREAM_SLAVE_INIT_C,
      txMaster   => AXI_STREAM_MASTER_INIT_C,
      decode     => CODE_S,
      state      => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxMaster : AxiStreamMasterType;
   signal rxSlave  : AxiStreamSlaveType;
   signal txMaster : AxiStreamMasterType;
   signal txSlave  : AxiStreamSlaveType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "TRUE";

begin

   FIFO_RX : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => 0,
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
         SLAVE_AXI_CONFIG_G  => EMAC_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => DHCP_CONFIG_C)          
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => ibDhcpMaster,
         sAxisSlave  => ibDhcpSlave,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => rxMaster,
         mAxisSlave  => rxSlave);  

   comb : process (localIp, localMac, r, rst, rxMaster, txSlave) is
      variable v     : RegType;
      variable tData : slv(7 downto 0);
      variable tKeep : slv(15 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.heartbeat := '0';
      v.rxSlave   := AXI_STREAM_SLAVE_INIT_C;
      if txSlave.tReady = '1' then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
      end if;

      -- Check 1 second heartbeat timeout
      if r.timer = (TIMER_1_SEC_C-1) then
         -- Reset the counter
         v.timer     := 0;
         -- Set the timeout flag
         v.heartbeat := '1';
      else
         -- Increment the counter
         v.timer := r.timer + 1;
      end if;

      -- Check for heart beat
      if (r.heartbeat = '1') then
         -- Check Communication timer
         if (r.commCnt /= 0) then
            -- Decrement the counter
            v.commCnt := r.commCnt - 1;
         end if;
         -- Check DHCP renewal timer
         if (r.renewCnt /= 0) then
            -- Decrement the counter
            v.renewCnt := r.renewCnt - 1;
         end if;
         -- Check DHCP lease timer
         if (r.leaseCnt /= 0) then
            -- Decrement the counter
            v.leaseCnt := r.leaseCnt - 1;
            -- Check for DHCP lease expire event
            if (r.leaseCnt = 1) then
               -- Set the flag
               v.dhcpReq   := '0';
               -- Reset the renewal counter
               v.renewCnt  := (others => '0');
               -- Broadcast the MAC/IP addresses
               v.remoteMac := (others => '1');
               v.remoteIp  := (others => '1');
            end if;
         else
            -- Set DHCP IP address to local value
            v.dhcpIP := localIp;
         end if;
      end if;

      -- Update the variables
      tData := rxMaster.tData((8*r.index)+7 downto (8*r.index));
      tKeep := x"000" & rxMaster.tKeep(3 downto 0);

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for inbound data
            if (rxMaster.tValid = '1') then
               -- Accept the data
               v.rxSlave.tReady := '1';
               -- Check for SOF with no EOF
               if (ssiGetUserSof(DHCP_CONFIG_C, rxMaster) = '1') and (rxMaster.tLast = '0') then
                  -- Check for valid DHCP server OP/HTYPE/HLEN/HOPS
                  if rxMaster.tData(31 downto 0) = SERVER_HDR_C then
                     -- Preset the counter
                     v.cnt   := 1;
                     -- Next state
                     v.state := BOOTP_S;
                  end if;
               end if;
            else
               -- Check DHCP renewal timer
               if (r.renewCnt = 0) then
                  -- Check for communication timeout
                  if r.commCnt = 0 then
                     -- Reset the counter
                     v.cnt   := 0;
                     -- Increment the counter
                     v.xid   := r.xid + 1;
                     -- Next state
                     v.state := REQ_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when REQ_S =>
            -- Check if ready to move data
            if v.txMaster.tValid = '0' then
               -- Set the default value
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := (others => '0');
               -- Increment the counter
               v.cnt                         := r.cnt + 1;
               -- Check the counter
               case r.cnt is
                  -- OP/HTYPE/HLEN/HOPS
                  when 0 =>
                     v.txMaster.tData(31 downto 0) := CLIENT_HDR_C;
                     ssiSetUserSof(DHCP_CONFIG_C, v.txMaster, '1');
                  -- XID
                  when 1 =>
                     -- Save the XID as big Endian
                     v.txMaster.tData(31 downto 24) := r.xid(7 downto 0);
                     v.txMaster.tData(23 downto 16) := r.xid(15 downto 8);
                     v.txMaster.tData(15 downto 8)  := r.xid(23 downto 16);
                     v.txMaster.tData(7 downto 0)   := r.xid(31 downto 24);
                  -- SECS/FLAGS
                  when 2 =>
                     v.txMaster.tData(31 downto 0) := x"00080000";
                  -- SIADDR
                  when 5 =>
                     -- Check for DHCP request
                     if r.dhcpReq = '1' then
                        v.txMaster.tData(31 downto 0) := r.siaddr;
                     end if;
                  -- CHADDR[31:0]
                  when 7 =>
                     v.txMaster.tData(31 downto 0) := localMac(31 downto 0);
                  -- CHADDR[47:32]
                  when 8 =>
                     v.txMaster.tData(15 downto 0) := localMac(47 downto 32);
                  -- Magic cookie
                  when 59 =>
                     v.txMaster.tData(31 downto 0) := MAGIC_COOKIE_C;
                  -- DHCP Discover
                  when 60 =>
                     -- Check for DHCP Discover
                     if r.dhcpReq = '0' then
                        v.txMaster.tData(7 downto 0)   := toSlv(53, 8);  -- code = DHCP Message Type
                        v.txMaster.tData(15 downto 8)  := x"01";  -- len = 1 byte
                        v.txMaster.tData(23 downto 16) := x"01";  -- DHCP Discover = 0x1
                        v.txMaster.tLast               := '1';
                        -- Start the communication timer
                        v.commCnt                      := COMM_TIMEOUT_C;
                        -- Reset the counter
                        v.cnt                          := 0;
                        -- Next state
                        v.state                        := IDLE_S;
                     else
                        v.txMaster.tData(7 downto 0)   := toSlv(53, 8);  -- code = DHCP Message Type
                        v.txMaster.tData(15 downto 8)  := x"01";  -- len = 1 byte
                        v.txMaster.tData(23 downto 16) := x"03";  -- DHCP request = 0x3                    
                     end if;
                  -- Requested IP address[15:0]
                  when 61 =>
                     v.txMaster.tData(7 downto 0)   := toSlv(50, 8);  -- code = Requested IP address
                     v.txMaster.tData(15 downto 8)  := x"04";     -- len = 4 byte
                     v.txMaster.tData(31 downto 16) := r.yiaddr(15 downto 0);  -- YIADDR[15:0]
                  -- Requested IP address[32:16]
                  when 62 =>
                     v.txMaster.tData(15 downto 0) := r.yiaddr(31 downto 16);  -- YIADDR[31:16] 
                  -- Server Identifier[15:0]
                  when 63 =>
                     v.txMaster.tData(7 downto 0)   := toSlv(54, 8);  -- code = Server Identifier
                     v.txMaster.tData(15 downto 8)  := x"04";     -- len = 4 byte
                     v.txMaster.tData(31 downto 16) := r.siaddr(15 downto 0);  -- SIADDR[15:0]
                  -- Server Identifier[32:16]
                  when 64 =>
                     v.txMaster.tData(15 downto 0) := r.siaddr(31 downto 16);  -- SIADDR[31:16] 
                     v.txMaster.tLast              := '1';
                     -- Start the communication timer
                     v.commCnt                     := COMM_TIMEOUT_C;
                     -- Reset the counter
                     v.cnt                         := 0;
                     -- Next state
                     v.state                       := IDLE_S;
                  when others=>
                     null;
               end case;
            end if;
         ----------------------------------------------------------------------
         when BOOTP_S =>
            -- Check for request data
            if (rxMaster.tValid = '1') then
               -- Accept the data
               v.rxSlave.tReady := '1';
               -- Increment the counter
               v.cnt            := r.cnt + 1;
               -- Check the counter
               case r.cnt is
                  -- XID
                  when 1 =>
                     -- Check if XID doesn't match
                     if (rxMaster.tData(31 downto 24) /= r.xid(7 downto 0))
                        or (rxMaster.tData(23 downto 16) /= r.xid(15 downto 8))
                        or (rxMaster.tData(15 downto 8) /= r.xid(23 downto 16))
                        or (rxMaster.tData(7 downto 0) /= r.xid(31 downto 24)) then
                        -- Next state
                        v.state := IDLE_S;
                     end if;
                  -- YIADDR
                  when 4 =>
                     v.yiaddrTemp := rxMaster.tData(31 downto 0);
                  -- SIADDR
                  when 5 =>
                     v.siaddrTemp := rxMaster.tData(31 downto 0);
                  -- CHADDR[31:0]
                  when 7 =>
                     -- Check if CHADDR[31:0] doesn't match
                     if rxMaster.tData(31 downto 0) /= localMac(31 downto 0) then
                        -- Next state
                        v.state := IDLE_S;
                     end if;
                  -- CHADDR[47:32]
                  when 8 =>
                     -- Check if CHADDR[47:32] doesn't match
                     if rxMaster.tData(15 downto 0) /= localMac(47 downto 32) then
                        -- Next state
                        v.state := IDLE_S;
                     end if;
                  -- Magic cookie
                  when 59 =>
                     -- Check if Magic cookie doesn't match                  
                     if rxMaster.tData(31 downto 0) /= MAGIC_COOKIE_C then
                        -- Next state
                        v.state := IDLE_S;
                     else
                        -- Reset data fields
                        v.valid  := (others => '0');
                        v.index  := 0;
                        v.decode := CODE_S;
                        -- Next state
                        v.state  := DHCP_S;
                     end if;
                  when others=>
                     null;
               end case;
               -- Check for early packet termination
               if (rxMaster.tLast = '1') then
                  -- Next state
                  v.state := IDLE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when DHCP_S =>
            -- Check for request data
            if (rxMaster.tValid = '1') then
               -- Decode State Machine
               case r.decode is
                  ----------------------------------------------------------------
                  when CODE_S =>
                     -- Save the OP-code value
                     v.opCode := tData;
                     -- Check for not "PAD" and not "End" OP-code
                     if (tData /= 0) and (tData /= 255) then
                        -- Next state
                        v.decode := LEN_S;
                     end if;
                  ----------------------------------------------------------------
                  when LEN_S =>
                     -- Save the length
                     v.len := tData;
                     -- Check for non-zero length
                     if tData /= 0 then
                        -- Next state
                        v.decode := DATA_S;
                     else               -- Error detected
                        -- Next state
                        v.state := IDLE_S;
                     end if;
                  ----------------------------------------------------------------
                  when DATA_S =>
                     -- Decrement the counter
                     v.len := r.len - 1;
                     -- Check for last byte
                     if (r.len = 1) then
                        -- Next state
                        v.decode := CODE_S;
                     end if;
                     -- Check the Code
                     case r.opCode is   -- Note: Assuming zero padding
                        -- Check for DHCP Message Type
                        when toSlv(53, 8) =>
                           if (r.len = 1) then
                              -- Set the flag
                              v.valid(0) := '1';
                              -- Save the message
                              v.msgType  := tData;
                           end if;
                        -- Check for IP address Lease Time
                        when toSlv(51, 8) =>
                           if r.len = 4 then
                              -- Set the flag
                              v.valid(1)                := '1';
                              v.leaseTime(31 downto 24) := tData;
                           elsif r.len = 3 then
                              -- Set the flag
                              v.valid(2)                := '1';
                              v.leaseTime(23 downto 16) := tData;
                           elsif r.len = 2 then
                              -- Set the flag
                              v.valid(3)               := '1';
                              v.leaseTime(15 downto 8) := tData;
                           elsif r.len = 1 then
                              -- Set the flag
                              v.valid(4)              := '1';
                              v.leaseTime(7 downto 0) := tData;
                           end if;
                        when others =>
                           null;
                     end case;
               ----------------------------------------------------------------
               end case;
               -- Check the counter
               if r.index = 3 then
                  -- Reset the counter
                  v.index          := 0;
                  -- Accept the data
                  v.rxSlave.tReady := '1';
               else
                  v.index := r.index + 1;
               end if;
               -- Check for last transfer
               if (rxMaster.tLast = '1') and (getTKeep(tKeep) = (r.index+1)) then
                  -- Check for no EOFE
                  if ssiGetUserEofe(DHCP_CONFIG_C, rxMaster) = '0' then
                     -- Next state
                     v.state := VERIFY_S;
                  else
                     -- Next state
                     v.state := IDLE_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when VERIFY_S =>
            -- Check if armed
            if uAnd(r.valid) = '1' then
               -- Save the values
               v.yiaddr := r.yiaddrTemp;
               v.siaddr := r.siaddrTemp;
               -- Check for "DHCP Discover" request and "DHCP Offer" reply
               if (r.dhcpReq = '0') and (r.msgType = 2) then
                  -- Set the flag
                  v.dhcpReq := '1';
                  -- Reset counter to immediately start the "DHCP request"  
                  v.commCnt := 0;
               -- Check for "DHCP request" request and "DHCP ACK" reply
               elsif (r.dhcpReq = '1') and (r.msgType = 5) then
                  -- Set the DHCP address 
                  v.dhcpIp   := r.yiaddrTemp;
                  -- Clients begin to attempt to renew their leases 
                  -- once half the lease interval has expired.
                  v.renewCnt := r.leaseTime(31 downto 1);
                  v.leaseCnt := r.leaseTime;
               end if;
            end if;
            -- Next state
            v.state := IDLE_S;
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
      dhcpIp   <= r.dhcpIp;
      
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
         INT_PIPE_STAGES_G   => 0,
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
         SLAVE_AXI_CONFIG_G  => DHCP_CONFIG_C,
         MASTER_AXI_CONFIG_G => EMAC_AXIS_CONFIG_C)        
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => txMaster,
         sAxisSlave  => txSlave,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => obDhcpMaster,
         mAxisSlave  => obDhcpSlave);       

end rtl;
