-------------------------------------------------------------------------------
-- File       : IpV4EngineDeMux.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-12
-- Last update: 2016-09-16
-------------------------------------------------------------------------------
-- Description: IPv4 AXIS DEMUX module
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

entity IpV4EngineDeMux is
   generic (
      TPD_G  : time    := 1 ns;
      VLAN_G : boolean := false);    
   port (
      -- Local Configurations
      localMac     : in  slv(47 downto 0);  --  big-Endian configuration   
      -- Slave
      obMacMaster  : in  AxiStreamMasterType;
      obMacSlave   : out AxiStreamSlaveType;
      -- Masters
      ibArpMaster  : out AxiStreamMasterType;
      ibArpSlave   : in  AxiStreamSlaveType;
      ibIpv4Master : out AxiStreamMasterType;
      ibIpv4Slave  : in  AxiStreamSlaveType;
      -- Clock and Reset
      clk          : in  sl;
      rst          : in  sl);      
end IpV4EngineDeMux;

architecture rtl of IpV4EngineDeMux is

   constant BROADCAST_MAC_C : slv(47 downto 0) := (others => '1');

   type StateType is (
      IDLE_S,
      CHECK_S,
      MOVE_S); 

   type RegType is record
      arpSel       : sl;
      ipv4Sel      : sl;
      dly          : AxiStreamMasterType;
      ibArpMaster  : AxiStreamMasterType;
      ibIpv4Master : AxiStreamMasterType;
      obMacSlave   : AxiStreamSlaveType;
      state        : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      arpSel       => '0',
      ipv4Sel      => '0',
      dly          => AXI_STREAM_MASTER_INIT_C,
      ibArpMaster  => AXI_STREAM_MASTER_INIT_C,
      ibIpv4Master => AXI_STREAM_MASTER_INIT_C,
      obMacSlave   => AXI_STREAM_SLAVE_INIT_C,
      state        => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (ibArpSlave, ibIpv4Slave, localMac, obMacMaster, r, rst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals   
      v.obMacSlave.tReady := '0';
      if ibArpSlave.tReady = '1' then
         v.ibArpMaster.tValid := '0';
      end if;
      if ibIpv4Slave.tReady = '1' then
         v.ibIpv4Master.tValid := '0';
      end if;

      -- Check if there is data to move
      if (obMacMaster.tValid = '1') and (v.ibArpMaster.tValid = '0') and (v.ibIpv4Master.tValid = '0') then
         ----------------------------------------------------------------------
         -- Checking for non-VLAN
         ----------------------------------------------------------------------         
         if (VLAN_G = false) then
            -- Accept for data
            v.obMacSlave.tReady := '1';
            -- Check for SOF and not EOF
            if (ssiGetUserSof(EMAC_AXIS_CONFIG_C, obMacMaster) = '1') and (obMacMaster.tLast = '0') then
               -- Reset the flags
               v.arpSel  := '0';
               v.ipv4Sel := '0';
               -- Check for a valid ARP EtherType
               if (obMacMaster.tData(111 downto 96) = ARP_TYPE_C) then
                  -- Check the destination MAC address
                  if(obMacMaster.tData(47 downto 0) = BROADCAST_MAC_C) or (obMacMaster.tData(47 downto 0) = localMac) then
                     v.arpSel      := '1';
                     v.ibArpMaster := obMacMaster;
                  end if;
               -- Check for a valid IPV4 EtherType and (IPVersion + Header length)
               elsif (obMacMaster.tData(111 downto 96) = IPV4_TYPE_C) and (obMacMaster.tData(119 downto 112) = x"45") then
                  -- Check the destination MAC address
                  if(obMacMaster.tData(47 downto 0) = BROADCAST_MAC_C) or (obMacMaster.tData(47 downto 0) = localMac) then
                     v.ipv4Sel      := '1';
                     v.ibIpv4Master := obMacMaster;
                  end if;
               end if;
            elsif r.arpSel = '1' then
               v.ibArpMaster := obMacMaster;
            elsif r.ipv4Sel = '1' then
               v.ibIpv4Master := obMacMaster;
            end if;
            if obMacMaster.tLast = '1' then
               -- Reset the flags
               v.arpSel  := '0';
               v.ipv4Sel := '0';
            end if;
         ----------------------------------------------------------------------
         -- Checking for VLAN
         ----------------------------------------------------------------------         
         else
            -- State Machine
            case r.state is
               ----------------------------------------------------------------------
               when IDLE_S =>
                  -- Accept for data
                  v.obMacSlave.tReady := '1';
                  -- Check for SOF and not EOF
                  if (ssiGetUserSof(EMAC_AXIS_CONFIG_C, obMacMaster) = '1') and (obMacMaster.tLast = '0') then
                     -- Check for a valid VLAN EtherType
                     if (obMacMaster.tData(111 downto 96) = VLAN_TYPE_C) then
                        -- Reset the flags
                        v.arpSel  := '0';
                        v.ipv4Sel := '0';
                        -- Latch the data bus
                        v.dly     := obMacMaster;
                        -- Next state
                        v.state   := CHECK_S;
                     end if;
                  end if;
               ----------------------------------------------------------------------
               when CHECK_S =>
                  -- Check for a valid ARP EtherType
                  if (obMacMaster.tData(15 downto 0) = ARP_TYPE_C) then
                     -- Check the destination MAC address
                     if(r.dly.tData(47 downto 0) = BROADCAST_MAC_C) or (r.dly.tData(47 downto 0) = localMac) then
                        v.arpSel      := '1';
                        v.ibArpMaster := r.dly;
                     end if;
                  -- Check for a valid IPV4 EtherType and (IPVersion + Header length)
                  elsif (obMacMaster.tData(15 downto 0) = IPV4_TYPE_C) and (obMacMaster.tData(23 downto 16) = x"45") then
                     -- Check the destination MAC address
                     if(r.dly.tData(47 downto 0) = BROADCAST_MAC_C) or (r.dly.tData(47 downto 0) = localMac) then
                        v.ipv4Sel      := '1';
                        v.ibIpv4Master := r.dly;
                     end if;
                  end if;
                  -- Next state
                  v.state := MOVE_S;
               ----------------------------------------------------------------------
               when MOVE_S =>
                  -- Accept for data
                  v.obMacSlave.tReady := '1';
                  if r.arpSel = '1' then
                     v.ibArpMaster := obMacMaster;
                  elsif r.ipv4Sel = '1' then
                     v.ibIpv4Master := obMacMaster;
                  end if;
                  if obMacMaster.tLast = '1' then
                     -- Next state
                     v.state := IDLE_S;
                  end if;
            ----------------------------------------------------------------------
            end case;
         end if;
      end if;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      obMacSlave   <= v.obMacSlave;
      ibArpMaster  <= r.ibArpMaster;
      ibIpv4Master <= r.ibIpv4Master;
      
   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
