-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : IpV4EngineRx.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-12
-- Last update: 2016-05-12
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

entity IpV4EngineRx is
   generic (
      TPD_G            : time      := 1 ns;
      SIM_ERROR_HALT_G : boolean   := false;
      PROTOCOL_SIZE_G  : positive  := 1;
      PROTOCOL_G       : Slv8Array := (0 => UDP_C);
      VLAN_G           : boolean   := false);       
   port (
      -- Local Configurations
      localIp           : in  slv(31 downto 0);  --  big-Endian configuration   
      -- Interface to Ethernet Frame MUX/DEMUX 
      ibIpv4Master      : in  AxiStreamMasterType;
      ibIpv4Slave       : out AxiStreamSlaveType;
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
      CHECKSUM_S,
      IPV4_HDR2_S,
      MOVE_S,
      LAST_S); 

   type RegType is record
      tLast       : sl;
      eofe        : sl;
      length      : slv(15 downto 0);
      tKeep       : slv(15 downto 0);
      tData       : slv(127 downto 0);
      hdr         : Slv8Array(19 downto 0);
      sum0        : Slv32Array(3 downto 0);
      sum1        : Slv32Array(1 downto 0);
      sum2        : Slv32Array(1 downto 0);
      sum3        : slv(31 downto 0);
      sum4        : slv(31 downto 0);
      ibIpv4Slave : AxiStreamSlaveType;
      txMasters   : AxiStreamMasterArray(PROTOCOL_SIZE_G-1 downto 0);
      cnt         : natural range 0 to 7;
      index       : natural range 0 to PROTOCOL_SIZE_G-1;
      state       : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      tLast       => '0',
      eofe        => '0',
      length      => (others => '0'),
      tKeep       => (others => '0'),
      tData       => (others => '0'),
      hdr         => (others => (others => '0')),
      sum0        => (others => (others => '0')),
      sum1        => (others => (others => '0')),
      sum2        => (others => (others => '0')),
      sum3        => (others => '0'),
      sum4        => (others => '0'),
      ibIpv4Slave => AXI_STREAM_SLAVE_INIT_C,
      txMasters   => (others => AXI_STREAM_MASTER_INIT_C),
      cnt         => 0,
      index       => 0,
      state       => IDLE_S);      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal txMasters : AxiStreamMasterArray(PROTOCOL_SIZE_G-1 downto 0);
   signal txSlaves  : AxiStreamSlaveArray(PROTOCOL_SIZE_G-1 downto 0);

   -- attribute dont_touch              : string;
   -- attribute dont_touch of r         : signal is "TRUE";
   -- attribute dont_touch of txMasters : signal is "TRUE";
   -- attribute dont_touch of txSlaves  : signal is "TRUE";

begin

   comb : process (ibIpv4Master, localIp, r, rst, txSlaves) is
      variable v        : RegType;
      variable i        : natural;
      variable len      : slv(15 downto 0);
      variable ibValid  : sl;
      variable checksum : slv(15 downto 0);
      variable tReady   : sl;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      tReady        := '1';
      v.ibIpv4Slave := AXI_STREAM_SLAVE_INIT_C;
      for i in PROTOCOL_SIZE_G-1 downto 0 loop
         if txSlaves(i).tReady = '1' then
            v.txMasters(i).tValid := '0';
            v.txMasters(i).tLast  := '0';
            v.txMasters(i).tUser  := (others => '0');
            v.txMasters(i).tKeep  := (others => '1');
         end if;
         if v.txMasters(i).tValid = '1' then
            tReady := '0';
         end if;
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
            -- Check for data
            if (ibIpv4Master.tValid = '1') and (tReady = '1') then
               -- Accept the data
               v.ibIpv4Slave.tReady := '1';
               -- Check for SOF with no EOF
               if (ssiGetUserSof(IP_ENGINE_CONFIG_C, ibIpv4Master) = '1') and (ibIpv4Master.tLast = '0') then
                  -- Loop through the protocol buses
                  for i in PROTOCOL_SIZE_G-1 downto 0 loop
                     -- Latch the remote MAC address
                     v.txMasters(i).tData(47 downto 0) := ibIpv4Master.tData(95 downto 48);
                     if (VLAN_G = false) then
                        -- Unused data field 
                        v.txMasters(i).tData(63 downto 48) := (others => '0');
                        -- Fill in the header
                        v.hdr(0)                           := ibIpv4Master.tData(119 downto 112);  -- IPVersion + Header length
                        v.hdr(1)                           := ibIpv4Master.tData(127 downto 120);  -- DSCP and ECN                     
                     else
                        -- Mask off VLAN's ID
                        v.txMasters(i).tData(63 downto 48) := (others => '0');
                     end if;
                  end loop;
                  -- Reset the tKeep bus
                  v.tKeep := (others => '0');
                  -- Next state
                  v.state := IPV4_HDR0_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when IPV4_HDR0_S =>
            -- Check for data
            if (ibIpv4Master.tValid = '1') then
               -- Accept the data
               v.ibIpv4Slave.tReady := '1';
               if (VLAN_G = false) then
                  v.hdr(2)  := ibIpv4Master.tData(7 downto 0);      -- IPV4_Length(15 downto 8)
                  v.hdr(3)  := ibIpv4Master.tData(15 downto 8);     -- IPV4_Length(7 downto 0)
                  v.hdr(4)  := ibIpv4Master.tData(23 downto 16);    -- IPV4_ID(15 downto 8)
                  v.hdr(5)  := ibIpv4Master.tData(31 downto 24);    -- IPV4_ID(7 downto 0)
                  v.hdr(6)  := ibIpv4Master.tData(39 downto 32);    -- Flags and Fragment Offsets
                  v.hdr(7)  := ibIpv4Master.tData(47 downto 40);    -- Flags and Fragment Offsets
                  v.hdr(8)  := ibIpv4Master.tData(55 downto 48);    -- Time of Live
                  v.hdr(9)  := ibIpv4Master.tData(63 downto 56);    -- Protocol
                  v.hdr(10) := ibIpv4Master.tData(71 downto 64);    -- IPV4_Checksum(15 downto 8)
                  v.hdr(11) := ibIpv4Master.tData(79 downto 72);    -- IPV4_Checksum(7 downto 0)
                  v.hdr(12) := ibIpv4Master.tData(87 downto 80);    -- Source IP Address
                  v.hdr(13) := ibIpv4Master.tData(95 downto 88);    -- Source IP Address
                  v.hdr(14) := ibIpv4Master.tData(103 downto 96);   -- Source IP Address
                  v.hdr(15) := ibIpv4Master.tData(111 downto 104);  -- Source IP Address
                  v.hdr(16) := ibIpv4Master.tData(119 downto 112);  -- Destination IP Address
                  v.hdr(17) := ibIpv4Master.tData(127 downto 120);  -- Destination IP Address
               else
                  v.hdr(0)  := ibIpv4Master.tData(23 downto 16);    -- IPVersion + Header length
                  v.hdr(1)  := ibIpv4Master.tData(31 downto 24);    -- DSCP and ECN
                  v.hdr(2)  := ibIpv4Master.tData(39 downto 32);    -- IPV4_Length(15 downto 8)
                  v.hdr(3)  := ibIpv4Master.tData(47 downto 40);    -- IPV4_Length(7 downto 0)
                  v.hdr(4)  := ibIpv4Master.tData(55 downto 48);    -- IPV4_ID(15 downto 8)
                  v.hdr(5)  := ibIpv4Master.tData(63 downto 56);    -- IPV4_ID(7 downto 0)
                  v.hdr(6)  := ibIpv4Master.tData(71 downto 64);    -- Flags and Fragment Offsets
                  v.hdr(7)  := ibIpv4Master.tData(79 downto 72);    -- Flags and Fragment Offsets
                  v.hdr(8)  := ibIpv4Master.tData(87 downto 80);    -- Time of Live
                  v.hdr(9)  := ibIpv4Master.tData(95 downto 88);    -- Protocol
                  v.hdr(10) := ibIpv4Master.tData(103 downto 96);   -- IPV4_Checksum(15 downto 8)
                  v.hdr(11) := ibIpv4Master.tData(111 downto 104);  -- IPV4_Checksum(7 downto 0)
                  v.hdr(12) := ibIpv4Master.tData(119 downto 112);  -- Source IP Address
                  v.hdr(13) := ibIpv4Master.tData(127 downto 120);  -- Source IP Address               
               end if;
               -- Calculate the IPV4 Pseudo Header length (in little Endian)
               len(15 downto 8)      := v.hdr(2);
               len(7 downto 0)       := v.hdr(3);
               len                   := len - 20;  -- IPV4 Pseudo Header's length = protocol length - 20 Bytes
               -- Save the result in big Endian
               v.length(7 downto 0)  := len(15 downto 8);
               v.length(15 downto 8) := len(7 downto 0);
               -- Next state if protocol not detected during the "for loop"
               v.state               := IDLE_S;
               -- Loop through the protocol buses
               for i in PROTOCOL_SIZE_G-1 downto 0 loop
                  if v.hdr(9) = PROTOCOL_G(i) then
                     -- Latch the protocol bus pointer
                     v.index := i;
                     -- Next state if protocol not detected
                     v.state := IPV4_HDR1_S;
                  end if;
               end loop;
               -- Check the simulation error printing
               if (v.state = IDLE_S) then
                  v.eofe := '1';
               end if;
            end if;
         ----------------------------------------------------------------------
         when IPV4_HDR1_S =>
            -- Check for data
            if (ibIpv4Master.tValid = '1') then
               -- Accept the data
               v.ibIpv4Slave.tReady := '1';
               if (VLAN_G = false) then
                  v.hdr(18)             := ibIpv4Master.tData(7 downto 0);  -- Destination IP Address
                  v.hdr(19)             := ibIpv4Master.tData(15 downto 8);  -- Destination IP Address               
                  -- Track the leftovers
                  v.tData(111 downto 0) := ibIpv4Master.tData(127 downto 16);
                  v.tKeep(13 downto 0)  := ibIpv4Master.tKeep(15 downto 2);
                  v.tLast               := ibIpv4Master.tLast;
                  v.eofe                := ssiGetUserEofe(IP_ENGINE_CONFIG_C, ibIpv4Master);
               else
                  v.hdr(14)              := ibIpv4Master.tData(7 downto 0);  -- Source IP Address
                  v.hdr(15)              := ibIpv4Master.tData(15 downto 8);   -- Source IP Address
                  v.hdr(16)              := ibIpv4Master.tData(23 downto 16);  -- Destination IP Address
                  v.hdr(17)              := ibIpv4Master.tData(31 downto 24);  -- Destination IP Address               
                  v.hdr(18)              := ibIpv4Master.tData(39 downto 32);  -- Destination IP Address
                  v.hdr(19)              := ibIpv4Master.tData(47 downto 40);  -- Destination IP Address                
                  -- Track the leftovers                  
                  v.tData(79 downto 0)   := ibIpv4Master.tData(127 downto 48);
                  v.tData(127 downto 80) := (others => '0');
                  v.tKeep(9 downto 0)    := ibIpv4Master.tKeep(15 downto 6);
                  v.tKeep(15 downto 10)  := (others => '0');
                  v.tLast                := ibIpv4Master.tLast;
                  v.eofe                 := ssiGetUserEofe(IP_ENGINE_CONFIG_C, ibIpv4Master);
               end if;
               -- Check the Destination IP Address and (IPVersion + Header length)
               if (v.hdr(16) = localIp(7 downto 0))
                  and (v.hdr(17) = localIp(15 downto 8))
                  and (v.hdr(18) = localIp(23 downto 16))
                  and (v.hdr(19) = localIp(31 downto 24))
                  and (r.hdr(0) = x"45") then
                  -- Fill in the reset of the 1st word of IPV4 Pseudo Header
                  v.txMasters(r.index).tData(71 downto 64)  := v.hdr(12);
                  v.txMasters(r.index).tData(79 downto 72)  := v.hdr(13);
                  v.txMasters(r.index).tData(87 downto 80)  := v.hdr(14);
                  v.txMasters(r.index).tData(95 downto 88)  := v.hdr(15);
                  v.txMasters(r.index).tData(127 downto 96) := localIp;
                  -- Next state
                  v.state                                   := CHECKSUM_S;
               else
                  v.eofe  := '1';
                  -- Next state
                  v.state := IDLE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when CHECKSUM_S =>
            -- Check if ready to move data
            if (v.txMasters(r.index).tValid = '0') then
               -- Check the counter
               if r.cnt = 7 then
                  -- Reset the counter
                  v.cnt := 0;
                  -- Check if received valid checksum value
                  if ibValid = '1' then
                     -- Send the RAW Ethernet header
                     v.txMasters(r.index).tValid := '1';
                     ssiSetUserSof(IP_ENGINE_CONFIG_C, v.txMasters(r.index), '1');
                     -- Next state
                     v.state                     := IPV4_HDR2_S;
                  else
                     v.eofe  := '1';
                     -- Next state
                     v.state := IDLE_S;
                  end if;
               else
                  -- Increment the counter
                  v.cnt := r.cnt + 1;
               end if;
            end if;
         ----------------------------------------------------------------------
         when IPV4_HDR2_S =>
            -- Check for data
            if ((ibIpv4Master.tValid = '1') or (r.tLast = '1')) and (v.txMasters(r.index).tValid = '0') then
               -- Complete the IPV4 Pseudo Header 
               v.txMasters(r.index).tValid              := '1';
               v.txMasters(r.index).tData(7 downto 0)   := (others => '0');
               v.txMasters(r.index).tData(15 downto 8)  := PROTOCOL_G(r.index);
               v.txMasters(r.index).tData(31 downto 16) := r.length;
               -- Start to move the datagram
               if (VLAN_G = false) then
                  v.txMasters(r.index).tData(127 downto 32) := r.tData(95 downto 0);
                  v.txMasters(r.index).tKeep(15 downto 0)   := r.tKeep(11 downto 0) & "1111";
                  -- Track the leftovers
                  v.tData(15 downto 0)                      := r.tData(111 downto 96);
                  v.tData(127 downto 16)                    := (others => '0');
                  v.tKeep(1 downto 0)                       := r.tKeep(13 downto 12);
                  v.tKeep(15 downto 2)                      := (others => '0');
                  -- Check for tLast
                  if r.tLast = '1' then
                     -- Check the leftover tKeep is not empty
                     if v.tKeep /= 0 then
                        -- Next state
                        v.state := LAST_S;
                     else
                        v.txMasters(r.index).tLast := '1';
                        ssiSetUserEofe(IP_ENGINE_CONFIG_C, v.txMasters(r.index), r.eofe);
                        -- Next state
                        v.state                    := IDLE_S;
                     end if;
                  else
                     -- Next state
                     v.state := MOVE_S;
                  end if;
               else
                  -- Check for tLast during IPV4_HDR1_S
                  if (r.tLast = '1') then
                     -- Move the data
                     v.txMasters(r.index).tData(111 downto 32)  := r.tData(79 downto 0);
                     v.txMasters(r.index).tData(127 downto 112) := (others => '0');
                     v.txMasters(r.index).tKeep(13 downto 0)    := r.tKeep(9 downto 0) & "1111";
                     v.txMasters(r.index).tKeep(15 downto 14)   := (others => '0');
                     -- Set tLast and EOFE
                     v.txMasters(r.index).tLast                 := '1';
                     ssiSetUserEofe(IP_ENGINE_CONFIG_C, v.txMasters(r.index), r.eofe);
                     -- Next state
                     v.state                                    := IDLE_S;
                  else
                     -- Accept the data
                     v.ibIpv4Slave.tReady                       := '1';
                     -- Move the data
                     v.txMasters(r.index).tData(111 downto 32)  := r.tData(79 downto 0);
                     v.txMasters(r.index).tData(127 downto 112) := ibIpv4Master.tData(15 downto 0);
                     v.txMasters(r.index).tKeep(13 downto 0)    := r.tKeep(9 downto 0) & "1111";
                     v.txMasters(r.index).tKeep(15 downto 14)   := ibIpv4Master.tKeep(1 downto 0);
                     -- Track the leftovers
                     v.tData(111 downto 0)                      := ibIpv4Master.tData(127 downto 16);
                     v.tKeep(13 downto 0)                       := ibIpv4Master.tKeep(15 downto 2);
                     -- Check for tLast
                     if ibIpv4Master.tLast = '1' then
                        -- Zero out unused data field
                        v.tData(127 downto 112) := (others => '0');
                        -- Update the EOFE bit
                        v.eofe                  := ssiGetUserEofe(IP_ENGINE_CONFIG_C, ibIpv4Master);
                        -- Check the leftover tKeep is not empty
                        if v.tKeep /= 0 then
                           -- Next state
                           v.state := LAST_S;
                        else
                           v.txMasters(r.index).tLast := '1';
                           ssiSetUserEofe(IP_ENGINE_CONFIG_C, v.txMasters(r.index), v.eofe);
                           -- Next state
                           v.state                    := IDLE_S;
                        end if;
                     else
                        -- Next state
                        v.state := MOVE_S;
                     end if;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check for data
            if (ibIpv4Master.tValid = '1') and (v.txMasters(r.index).tValid = '0') then
               -- Accept the data
               v.ibIpv4Slave.tReady        := '1';
               -- Move the data
               v.txMasters(r.index).tValid := '1';
               if (VLAN_G = false) then
                  -- Move the data
                  v.txMasters(r.index).tData(15 downto 0)   := r.tData(15 downto 0);
                  v.txMasters(r.index).tData(127 downto 16) := ibIpv4Master.tData(111 downto 0);
                  v.txMasters(r.index).tKeep(1 downto 0)    := r.tKeep(1 downto 0);
                  v.txMasters(r.index).tKeep(15 downto 2)   := ibIpv4Master.tKeep(13 downto 0);
                  -- Track the leftovers                  
                  v.tData(15 downto 0)                      := ibIpv4Master.tData(127 downto 112);
                  v.tKeep(1 downto 0)                       := ibIpv4Master.tKeep(15 downto 14);
                  -- Check for tLast
                  if ibIpv4Master.tLast = '1' then
                     -- Zero out unused data field
                     v.tData(127 downto 16) := (others => '0');
                     -- Update the EOFE bit
                     v.eofe                 := ssiGetUserEofe(IP_ENGINE_CONFIG_C, ibIpv4Master);
                     -- Check the leftover tKeep is not empty
                     if v.tKeep /= 0 then
                        -- Next state
                        v.state := LAST_S;
                     else
                        v.txMasters(r.index).tLast := '1';
                        ssiSetUserEofe(IP_ENGINE_CONFIG_C, v.txMasters(r.index), v.eofe);
                        -- Next state
                        v.state                    := IDLE_S;
                     end if;
                  end if;
               else
                  -- Move the data
                  v.txMasters(r.index).tData(111 downto 0)   := r.tData(111 downto 0);
                  v.txMasters(r.index).tData(127 downto 112) := ibIpv4Master.tData(15 downto 0);
                  v.txMasters(r.index).tKeep(13 downto 0)    := r.tKeep(13 downto 0);
                  v.txMasters(r.index).tKeep(15 downto 14)   := ibIpv4Master.tKeep(1 downto 0);
                  -- Track the leftovers
                  v.tData(111 downto 0)                      := ibIpv4Master.tData(127 downto 16);
                  v.tKeep(13 downto 0)                       := ibIpv4Master.tKeep(15 downto 2);
                  -- Check for tLast
                  if ibIpv4Master.tLast = '1' then
                     -- Zero out unused data field
                     v.tData(127 downto 112) := (others => '0');
                     -- Update the EOFE bit
                     v.eofe                  := ssiGetUserEofe(IP_ENGINE_CONFIG_C, ibIpv4Master);
                     -- Check the leftover tKeep is not empty
                     if v.tKeep /= 0 then
                        -- Next state
                        v.state := LAST_S;
                     else
                        v.txMasters(r.index).tLast := '1';
                        ssiSetUserEofe(IP_ENGINE_CONFIG_C, v.txMasters(r.index), v.eofe);
                        -- Next state
                        v.state                    := IDLE_S;
                     end if;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when LAST_S =>
            -- Check for data
            if (v.txMasters(r.index).tValid = '0') then
               -- Move the data
               v.txMasters(r.index).tValid := '1';
               v.txMasters(r.index).tData  := r.tData;
               v.txMasters(r.index).tKeep  := r.tKeep;
               v.txMasters(r.index).tLast  := '1';
               ssiSetUserEofe(IP_ENGINE_CONFIG_C, v.txMasters(r.index), r.eofe);
               -- Next state
               v.state                     := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Check the simulation error printing
      if SIM_ERROR_HALT_G and (r.eofe = '1') then
         report "IpV4EngineRx: Error Detected" severity failure;
      end if;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      ibIpv4Slave <= v.ibIpv4Slave;
      txMasters   <= r.txMasters;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   GEN_VEC :
   for i in (PROTOCOL_SIZE_G-1) downto 0 generate
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
            sAxisMaster => txMasters(i),
            sAxisSlave  => txSlaves(i),
            -- Master Port
            mAxisClk    => clk,
            mAxisRst    => rst,
            mAxisMaster => ibProtocolMasters(i),
            mAxisSlave  => ibProtocolSlaves(i));  
   end generate GEN_VEC;

end rtl;
