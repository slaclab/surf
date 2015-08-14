-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EthFrameDeMux.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-12
-- Last update: 2015-08-13
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.IpEngineDefPkg.all;

entity EthFrameDeMux is
   generic (
      TPD_G  : time    := 1 ns;
      VLAN_G : boolean := false);    
   port (
      -- Slave
      sEthMaster   : in  AxiStreamMasterType;
      sEthSlave    : out AxiStreamSlaveType;
      -- Masters
      ibArpMaster  : out AxiStreamMasterType;
      ibArpSlave   : in  AxiStreamSlaveType;
      ibIpv4Master : out AxiStreamMasterType;
      ibIpv4Slave  : in  AxiStreamSlaveType;
      -- Clock and Reset
      clk          : in  sl;
      rst          : in  sl);      
end EthFrameDeMux;

architecture rtl of EthFrameDeMux is

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
      sEthSlave    : AxiStreamSlaveType;
      state        : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      arpSel       => '0',
      ipv4Sel      => '0',
      dly          => AXI_STREAM_MASTER_INIT_C,
      ibArpMaster  => AXI_STREAM_MASTER_INIT_C,
      ibIpv4Master => AXI_STREAM_MASTER_INIT_C,
      sEthSlave    => AXI_STREAM_SLAVE_INIT_C,
      state        => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (ibArpSlave, ibIpv4Slave, r, rst, sEthMaster) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals   
      v.sEthSlave.tReady := '0';
      if ibArpSlave.tReady = '1' then
         v.ibArpMaster.tValid := '0';
      end if;
      if ibIpv4Slave.tReady = '1' then
         v.ibIpv4Master.tValid := '0';
      end if;

      -- Check if there is data to move
      if (sEthMaster.tValid = '1') and (v.ibArpMaster.tValid = '0') and (v.ibIpv4Master.tValid = '0') then
         ----------------------------------------------------------------------
         -- Checking for non-VLAN
         ----------------------------------------------------------------------         
         if (VLAN_G = false) then
            -- Accept for data
            v.sEthSlave.tReady := '1';
            -- Check for SOF and not EOF
            if (ssiGetUserSof(IP_ENGINE_CONFIG_C, sEthMaster) = '1') and (sEthMaster.tLast = '0') then
               -- Reset the flags
               v.arpSel  := '0';
               v.ipv4Sel := '0';
               -- Check for a valid ARP EtherType
               if (sEthMaster.tData(111 downto 96) = ARP_TYPE_C) then
                  v.arpSel      := '1';
                  v.ibArpMaster := sEthMaster;
               -- Check for a valid IPV4 EtherType
               elsif (sEthMaster.tData(111 downto 96) = IPV4_TYPE_C) and (sEthMaster.tData(47 downto 0) /= BROADCAST_MAC_C) then
                  v.ipv4Sel      := '1';
                  v.ibIpv4Master := sEthMaster;
               end if;
            elsif r.arpSel = '1' then
               v.ibArpMaster := sEthMaster;
            elsif r.ipv4Sel = '1' then
               v.ibIpv4Master := sEthMaster;
            end if;
            if sEthMaster.tLast = '1' then
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
                  v.sEthSlave.tReady := '1';
                  -- Check for SOF and not EOF
                  if (ssiGetUserSof(IP_ENGINE_CONFIG_C, sEthMaster) = '1') and (sEthMaster.tLast = '0') then
                     -- Check for a valid VLAN EtherType
                     if (sEthMaster.tData(111 downto 96) = VLAN_TYPE_C) then
                        -- Reset the flags
                        v.arpSel  := '0';
                        v.ipv4Sel := '0';
                        -- Latch the data bus
                        v.dly     := sEthMaster;
                        -- Next state
                        v.state   := CHECK_S;
                     end if;
                  end if;
               ----------------------------------------------------------------------
               when CHECK_S =>
                  -- Check for a valid ARP EtherType
                  if (sEthMaster.tData(15 downto 0) = ARP_TYPE_C) then
                     v.arpSel      := '1';
                     v.ibArpMaster := r.dly;
                  -- Check for a valid IPV4 EtherType
                  elsif (sEthMaster.tData(15 downto 0) = IPV4_TYPE_C) and (r.dly.tData(47 downto 0) /= BROADCAST_MAC_C) then
                     v.ipv4Sel      := '1';
                     v.ibIpv4Master := r.dly;
                  end if;
                  -- Next state
                  v.state := MOVE_S;
               ----------------------------------------------------------------------
               when MOVE_S =>
                  -- Accept for data
                  v.sEthSlave.tReady := '1';
                  if r.arpSel = '1' then
                     v.ibArpMaster := sEthMaster;
                  elsif r.ipv4Sel = '1' then
                     v.ibIpv4Master := sEthMaster;
                  end if;
                  if sEthMaster.tLast = '1' then
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
      sEthSlave    <= v.sEthSlave;
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
