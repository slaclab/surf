-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : UdpEngineDhcp.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-08-12
-- Last update: 2016-08-12
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
use work.UdpEnginePkg.all;

entity UdpEngineDhcp is
   generic (
      -- Simulation Generics
      TPD_G            : time    := 1 ns;
      SIM_ERROR_HALT_G : boolean := false);
   port (
      -- Interface to DHCP Engine  
      dhcpEn       : out sl;
      dhcpIp       : out slv(31 downto 0);  --  big-Endian configuration 
      ibDhcpMaster : in  AxiStreamMasterType;
      ibDhcpSlave  : out AxiStreamSlaveType;
      obDhcpMaster : out AxiStreamMasterType;
      obDhcpSlave  : in  AxiStreamSlaveType;
      -- Clock and Reset
      clk          : in  sl;
      rst          : in  sl);
end UdpEngineDhcp;

architecture rtl of UdpEngineDhcp is

   type StateType is (
      IDLE_S);

   type RegType is record
      eofe         : sl;
      dhcpEn       : sl;
      dhcpIp       : slv(31 downto 0);
      ibDhcpSlave  : AxiStreamSlaveType;
      obDhcpMaster : AxiStreamMasterType;
      state        : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      eofe         => '0',
      dhcpEn       => '0',
      dhcpIp       => (others => '0'),
      ibDhcpSlave  => AXI_STREAM_SLAVE_INIT_C,
      obDhcpMaster => AXI_STREAM_MASTER_INIT_C,
      state        => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal obDhcpMasterPipe : AxiStreamMasterType;
   signal obDhcpSlavePipe  : AxiStreamSlaveType;

   -- attribute dont_touch             : string;
   -- attribute dont_touch of r        : signal is "TRUE";

begin

   comb : process (obDhcpSlavePipe, r, rst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.ibDhcpSlave := AXI_STREAM_SLAVE_INIT_C;
      if obDhcpSlavePipe.tReady = '1' then
         v.obDhcpMaster.tValid := '0';
         v.obDhcpMaster.tLast  := '0';
         v.obDhcpMaster.tUser  := (others => '0');
         v.obDhcpMaster.tKeep  := (others => '1');
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Place holder for future code
            v.ibDhcpSlave := AXI_STREAM_SLAVE_FORCE_C;
      ----------------------------------------------------------------------
      end case;

      -- Check the simulation error printing
      if SIM_ERROR_HALT_G and (r.eofe = '1') then
         report "UdpEngineDhcp: Error Detected" severity failure;
      end if;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      ibDhcpSlave      <= v.ibDhcpSlave;
      obDhcpMasterPipe <= r.obDhcpMaster;
      dhcpEn           <= r.dhcpEn;
      dhcpIp           <= r.dhcpIp;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_AxiStreamPipeline_Dhcp : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 1)
      port map (
         axisClk     => clk,
         axisRst     => rst,
         sAxisMaster => obDhcpMasterPipe,
         sAxisSlave  => obDhcpSlavePipe,
         mAxisMaster => obDhcpMaster,
         mAxisSlave  => obDhcpSlave);         

end rtl;
