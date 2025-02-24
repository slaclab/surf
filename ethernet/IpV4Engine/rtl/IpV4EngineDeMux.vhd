-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.EthMacPkg.all;

entity IpV4EngineDeMux is
   generic (
      TPD_G : time := 1 ns);
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

   type RegType is record
      arpSel       : sl;
      ipv4Sel      : sl;
      dly          : AxiStreamMasterType;
      ibArpMaster  : AxiStreamMasterType;
      ibIpv4Master : AxiStreamMasterType;
      obMacSlave   : AxiStreamSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      arpSel       => '0',
      ipv4Sel      => '0',
      dly          => AXI_STREAM_MASTER_INIT_C,
      ibArpMaster  => AXI_STREAM_MASTER_INIT_C,
      ibIpv4Master => AXI_STREAM_MASTER_INIT_C,
      obMacSlave   => AXI_STREAM_SLAVE_INIT_C);

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
      end if;

      -- Combinatorial outputs before the reset
      obMacSlave <= v.obMacSlave;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Registered Outputs
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
