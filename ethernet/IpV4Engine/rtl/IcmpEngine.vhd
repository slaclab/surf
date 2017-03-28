-------------------------------------------------------------------------------
-- File       : IcmpEngine.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-08-16
-- Last update: 2016-09-16
-------------------------------------------------------------------------------
-- Description: ICMP Engine (A.K.A. "ping" protocol)
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

entity IcmpEngine is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Local Configurations
      localIp      : in  slv(31 downto 0);  --  big-Endian configuration   
      -- Interface to ICMP Engine
      ibIcmpMaster : in  AxiStreamMasterType;
      ibIcmpSlave  : out AxiStreamSlaveType;
      obIcmpMaster : out AxiStreamMasterType;
      obIcmpSlave  : in  AxiStreamSlaveType;
      -- Clock and Reset
      clk          : in  sl;
      rst          : in  sl);
end IcmpEngine;

architecture rtl of IcmpEngine is

   type StateType is (
      IDLE_S,
      RX_HDR_S,
      TX_HDR_S,
      MOVE_S); 

   type RegType is record
      tData        : slv(127 downto 0);
      checksum     : slv(15 downto 0);
      ibIcmpSlave  : AxiStreamSlaveType;
      obIcmpMaster : AxiStreamMasterType;
      state        : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      tData        => (others => '0'),
      checksum     => (others => '0'),
      ibIcmpSlave  => AXI_STREAM_SLAVE_INIT_C,
      obIcmpMaster => AXI_STREAM_MASTER_INIT_C,
      state        => IDLE_S);      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "TRUE";   

begin

   comb : process (ibIcmpMaster, localIp, obIcmpSlave, r, rst) is
      variable v    : RegType;
      variable eofe : sl;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.ibIcmpSlave := AXI_STREAM_SLAVE_INIT_C;
      if obIcmpSlave.tReady = '1' then
         v.obIcmpMaster.tValid := '0';
         v.obIcmpMaster.tLast  := '0';
         v.obIcmpMaster.tUser  := (others => '0');
         v.obIcmpMaster.tKeep  := (others => '1');
      end if;

      -- Update the variable
      eofe := ssiGetUserEofe(EMAC_AXIS_CONFIG_C, ibIcmpMaster);

      ------------------------------------------------
      -- Notes: Non-Standard IPv4 Pseudo Header Format
      ------------------------------------------------
      -- tData[0][47:0]   = Remote MAC Address
      -- tData[0][63:48]  = zeros
      -- tData[0][95:64]  = Remote IP Address 
      -- tData[0][127:96] = Local IP address
      -- tData[1][7:0]    = zeros
      -- tData[1][15:8]   = Protocol Type = ICMP
      -- tData[1][31:16]  = IPv4 Pseudo header length
      -- tData[1][39:32]  = Type of message
      -- tData[1][47:40]  = Code
      -- tData[1][63:48]  = Checksum
      -- tData[1][95:64]  = ICMP Header 
      -- tData[1][127:96] = ICMP Datagram 
      ------------------------------------------------         

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for data
            if (ibIcmpMaster.tValid = '1') then
               -- Accept the data
               v.ibIcmpSlave.tReady := '1';
               -- Check for SOF with no EOF
               if (ssiGetUserSof(EMAC_AXIS_CONFIG_C, ibIcmpMaster) = '1') and (ibIcmpMaster.tLast = '0') then
                  -- Copy IPv4 base header
                  v.tData(63 downto 0)   := ibIcmpMaster.tData(63 downto 0);
                  -- Swap the IP addresses
                  v.tData(95 downto 64)  := ibIcmpMaster.tData(127 downto 96);  -- SRC IP
                  v.tData(127 downto 96) := ibIcmpMaster.tData(95 downto 64);   -- DST IP
                  if ibIcmpMaster.tData(127 downto 96) = localIp then
                     -- Next state
                     v.state := RX_HDR_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when RX_HDR_S =>
            -- Check for data
            if (ibIcmpMaster.tValid = '1') and (v.obIcmpMaster.tValid = '0') then
               -- Check for Echo request
               if (ibIcmpMaster.tData(47 downto 32) = x"0008") then
                  -- Map the inbound checksum to little Endian
                  v.checksum(15 downto 8) := ibIcmpMaster.tData(55 downto 48);
                  v.checksum(7 downto 0)  := ibIcmpMaster.tData(63 downto 56);
                  -- Update the checksum for outbound data packet
                  v.checksum              := v.checksum + x"0800";
                  ---------------------------------------------------------
                  -- Note: To save FPGA resources, we do NOT cache the data 
                  --       for properly calculating the checksum.  Instead, 
                  --       we calculate the outbound checksum with respect 
                  --       to the inbound checksum and assume that the 
                  --       computer interface will probably check our 
                  --       outbound packet.
                  ---------------------------------------------------------
                  -- Send the IPv4 base header
                  v.obIcmpMaster.tValid   := '1';
                  v.obIcmpMaster.tData    := r.tData;
                  ssiSetUserSof(EMAC_AXIS_CONFIG_C, v.obIcmpMaster, '1');
                  -- Next state
                  v.state                 := TX_HDR_S;
               else
                  -- Next state
                  v.state := IDLE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when TX_HDR_S =>
            -- Check for data
            if (ibIcmpMaster.tValid = '1') and (v.obIcmpMaster.tValid = '0') then
               -- Accept the data
               v.ibIcmpSlave.tReady                := '1';
               -- Send the IPv4 base header
               v.obIcmpMaster.tValid               := '1';
               v.obIcmpMaster.tData(31 downto 0)   := ibIcmpMaster.tData(31 downto 0);
               v.obIcmpMaster.tData(47 downto 32)  := x"0000";                  -- Echo reply
               v.obIcmpMaster.tData(55 downto 48)  := r.checksum(15 downto 8);
               v.obIcmpMaster.tData(63 downto 56)  := r.checksum(7 downto 0);
               v.obIcmpMaster.tData(127 downto 64) := ibIcmpMaster.tData(127 downto 64);
               v.obIcmpMaster.tKeep                := ibIcmpMaster.tKeep;
               v.obIcmpMaster.tLast                := ibIcmpMaster.tLast;
               if ibIcmpMaster.tLast = '1' then
                  -- Echo back EOFE 
                  ssiSetUserEofe(EMAC_AXIS_CONFIG_C, v.obIcmpMaster, eofe);
                  -- Next state
                  v.state := IDLE_S;
               else
                  -- Next state
                  v.state := MOVE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check for data
            if (ibIcmpMaster.tValid = '1') and (v.obIcmpMaster.tValid = '0') then
               -- Accept the data
               v.ibIcmpSlave.tReady  := '1';
               -- Send the IPv4 base header
               v.obIcmpMaster.tValid := '1';
               v.obIcmpMaster.tData  := ibIcmpMaster.tData;
               v.obIcmpMaster.tKeep  := ibIcmpMaster.tKeep;
               v.obIcmpMaster.tLast  := ibIcmpMaster.tLast;
               if ibIcmpMaster.tLast = '1' then
                  -- Echo back EOFE 
                  ssiSetUserEofe(EMAC_AXIS_CONFIG_C, v.obIcmpMaster, eofe);
                  -- Next state
                  v.state := IDLE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      ibIcmpSlave  <= v.ibIcmpSlave;
      obIcmpMaster <= r.obIcmpMaster;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
