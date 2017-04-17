-------------------------------------------------------------------------------
-- File       : UdpEngineTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-17
-- Last update: 2015-08-28
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the UdpEngine module
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

entity UdpEngineTb is end UdpEngineTb;

architecture testbed of UdpEngineTb is

   constant CLK_PERIOD_C : time             := 6.4 ns;
   constant TPD_C        : time             := (CLK_PERIOD_C/4);
   constant LOCAL_MAC_C  : slv(47 downto 0) := x"123456789ABC";
   constant LOCAL_IP_C   : slv(31 downto 0) := x"12345678";
   constant REMOTE_MAC_C : slv(47 downto 0) := x"DEADBEEFCAFE";
   constant REMOTE_IP_C  : slv(31 downto 0) := x"ABCDEFFF";

   constant VLAN_C : boolean          := false;
   constant VID_C  : slv(15 downto 0) := x"0000";

   constant PROTOCOL_C         : Slv8Array(0 downto 0) := (0 => UDP_C);
   constant SERVER_PORTS_C     : PositiveArray         := (0 => 8192);
   constant CLIENT_PORTS_C     : PositiveArray         := (0 => 8193);
   constant SIM_ERROR_HALT_C   : boolean               := true;
   constant TX_CALC_CHECKSUM_C : boolean               := true;

   signal clk    : sl := '0';
   signal rst    : sl := '0';
   signal passed : sl := '0';
   signal failed : sl := '0';

   signal obServerMasters : AxiStreamMasterArray(1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal obServerSlaves  : AxiStreamSlaveArray(1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);
   signal ibServerMasters : AxiStreamMasterArray(1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal ibServerSlaves  : AxiStreamSlaveArray(1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);

   signal obClientMasters : AxiStreamMasterArray(1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal obClientSlaves  : AxiStreamSlaveArray(1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);
   signal ibClientMasters : AxiStreamMasterArray(1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal ibClientSlaves  : AxiStreamSlaveArray(1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);

   signal obProtocolMasters : AxiStreamMasterArray(1 downto 0);
   signal obProtocolSlaves  : AxiStreamSlaveArray(1 downto 0);
   signal ibProtocolMasters : AxiStreamMasterArray(1 downto 0);
   signal ibProtocolSlaves  : AxiStreamSlaveArray(1 downto 0);

   signal arpReqMasters : AxiStreamMasterArray(1 downto 0);
   signal arpReqSlaves  : AxiStreamSlaveArray(1 downto 0);
   signal arpAckMasters : AxiStreamMasterArray(1 downto 0);
   signal arpAckSlaves  : AxiStreamSlaveArray(1 downto 0);

   signal ibMacMasters : AxiStreamMasterArray(1 downto 0);
   signal ibMacSlaves  : AxiStreamSlaveArray(1 downto 0);
   signal obMacMasters : AxiStreamMasterArray(1 downto 0);
   signal obMacSlaves  : AxiStreamSlaveArray(1 downto 0);
   
begin

   ClkRst_Inst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => clk,
         clkN => open,
         rst  => rst,
         rstL => open);       

   -- Loopback the UDP datagram
   ibServerMasters(1) <= obServerMasters(1);
   obServerSlaves(1)  <= ibServerSlaves(1);

   UdpEngine_Remote : entity work.UdpEngine
      generic map (
         -- Simulation Generics
         TPD_G              => TPD_C,
         SIM_ERROR_HALT_G   => SIM_ERROR_HALT_C,
         -- UDP General Generic
         RX_FORWARD_EOFE_G  => false,
         TX_FORWARD_EOFE_G  => false,
         TX_CALC_CHECKSUM_G => TX_CALC_CHECKSUM_C,
         -- UDP Server Generics
         SERVER_EN_G        => true,
         SERVER_SIZE_G      => 1,
         SERVER_PORTS_G     => SERVER_PORTS_C,
         -- UDP Client Generics
         CLIENT_EN_G        => true,
         CLIENT_SIZE_G      => 1,
         CLIENT_PORTS_G     => CLIENT_PORTS_C,
         -- UDP ARP Generics
         CLK_FREQ_G         => 156.25E+06,  -- In units of Hz
         COMM_TIMEOUT_EN_G  => true,    -- Disable the timeout by setting to false
         COMM_TIMEOUT_G     => 30)  -- In units of seconds, Client's Communication timeout before re-ARPing
      port map (
         -- Local Configurations
         localIp            => REMOTE_IP_C,
         -- Interface to IPV4 Engine  
         obUdpMaster        => obProtocolMasters(1),
         obUdpSlave         => obProtocolSlaves(1),
         ibUdpMaster        => ibProtocolMasters(1),
         ibUdpSlave         => ibProtocolSlaves(1),
         -- Interface to ARP Engine
         arpReqMasters(0)   => arpReqMasters(1),
         arpReqSlaves(0)    => arpReqSlaves(1),
         arpAckMasters(0)   => arpAckMasters(1),
         arpAckSlaves(0)    => arpAckSlaves(1),
         -- Interface to UDP Server engine(s)
         obServerMasters(0) => obServerMasters(1),
         obServerSlaves(0)  => obServerSlaves(1),
         ibServerMasters(0) => ibServerMasters(1),
         ibServerSlaves(0)  => ibServerSlaves(1),
         -- Interface to UDP Client engine(s)
         clientRemotePort   => (others => x"0120"),
         clientRemoteIp     => (others => LOCAL_IP_C),
         obClientMasters(0) => obClientMasters(1),
         obClientSlaves(0)  => obClientSlaves(1),
         ibClientMasters(0) => ibClientMasters(1),
         ibClientSlaves(0)  => ibClientSlaves(1),
         -- Clock and Reset
         clk                => clk,
         rst                => rst);       

   IpV4Engine_Remote : entity work.IpV4Engine
      generic map (
         TPD_G            => TPD_C,
         SIM_ERROR_HALT_G => SIM_ERROR_HALT_C,
         PROTOCOL_SIZE_G  => 1,
         PROTOCOL_G       => PROTOCOL_C,
         CLIENT_SIZE_G    => 1,
         ARP_TIMEOUT_G    => 156250000,
         VLAN_G           => VLAN_C)
      port map (
         -- Local Configurations
         localMac             => REMOTE_MAC_C,
         localIp              => REMOTE_IP_C,
         -- Interface to Ethernet Media Access Controller (MAC)
         obMacMaster          => obMacMasters(1),
         obMacSlave           => obMacSlaves(1),
         ibMacMaster          => ibMacMasters(1),
         ibMacSlave           => ibMacSlaves(1),
         -- Interface to Protocol Engine(s)  
         obProtocolMasters(0) => obProtocolMasters(1),
         obProtocolSlaves(0)  => obProtocolSlaves(1),
         ibProtocolMasters(0) => ibProtocolMasters(1),
         ibProtocolSlaves(0)  => ibProtocolSlaves(1),
         -- Interface to Client Engine(s)
         arpReqMasters(0)     => arpReqMasters(1),
         arpReqSlaves(0)      => arpReqSlaves(1),
         arpAckMasters(0)     => arpAckMasters(1),
         arpAckSlaves(0)      => arpAckSlaves(1),
         -- Clock and Reset
         clk                  => clk,
         rst                  => rst);  

   MAC_FIFO_0 : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_C,
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
         MASTER_AXI_CONFIG_G => EMAC_AXIS_CONFIG_C)            
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => ibMacMasters(0),
         sAxisSlave  => ibMacSlaves(0),
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => obMacMasters(1),
         mAxisSlave  => obMacSlaves(1));    

   MAC_FIFO_1 : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_C,
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
         MASTER_AXI_CONFIG_G => EMAC_AXIS_CONFIG_C)            
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => ibMacMasters(1),
         sAxisSlave  => ibMacSlaves(1),
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => obMacMasters(0),
         mAxisSlave  => obMacSlaves(0));   

   IpV4Engine_Local : entity work.IpV4Engine
      generic map (
         TPD_G            => TPD_C,
         SIM_ERROR_HALT_G => SIM_ERROR_HALT_C,
         PROTOCOL_SIZE_G  => 1,
         PROTOCOL_G       => PROTOCOL_C,
         CLIENT_SIZE_G    => 1,
         ARP_TIMEOUT_G    => 156250000,
         VLAN_G           => VLAN_C)
      port map (
         -- Local Configurations
         localMac             => LOCAL_MAC_C,
         localIp              => LOCAL_IP_C,
         -- Interface to Ethernet Media Access Controller (MAC)
         obMacMaster          => obMacMasters(0),
         obMacSlave           => obMacSlaves(0),
         ibMacMaster          => ibMacMasters(0),
         ibMacSlave           => ibMacSlaves(0),
         -- Interface to Protocol Engine(s)  
         obProtocolMasters(0) => obProtocolMasters(0),
         obProtocolSlaves(0)  => obProtocolSlaves(0),
         ibProtocolMasters(0) => ibProtocolMasters(0),
         ibProtocolSlaves(0)  => ibProtocolSlaves(0),
         -- Interface to Client Engine(s)
         arpReqMasters(0)     => arpReqMasters(0),
         arpReqSlaves(0)      => arpReqSlaves(0),
         arpAckMasters(0)     => arpAckMasters(0),
         arpAckSlaves(0)      => arpAckSlaves(0),
         -- Clock and Reset
         clk                  => clk,
         rst                  => rst); 

   UdpEngine_Local : entity work.UdpEngine
      generic map (
         -- Simulation Generics
         TPD_G              => TPD_C,
         SIM_ERROR_HALT_G   => SIM_ERROR_HALT_C,
         -- UDP General Generic
         RX_FORWARD_EOFE_G  => false,
         TX_FORWARD_EOFE_G  => false,
         TX_CALC_CHECKSUM_G => TX_CALC_CHECKSUM_C,
         -- UDP Server Generics
         SERVER_EN_G        => true,
         SERVER_SIZE_G      => 1,
         SERVER_PORTS_G     => SERVER_PORTS_C,
         -- UDP Client Generics
         CLIENT_EN_G        => true,
         CLIENT_SIZE_G      => 1,
         CLIENT_PORTS_G     => CLIENT_PORTS_C,
         -- UDP ARP Generics
         CLK_FREQ_G         => 156.25E+06,  -- In units of Hz
         COMM_TIMEOUT_EN_G  => true,    -- Disable the timeout by setting to false
         COMM_TIMEOUT_G     => 30)  -- In units of seconds, Client's Communication timeout before re-ARPing
      port map (
         -- Local Configurations
         localIp            => LOCAL_IP_C,
         -- Interface to IPV4 Engine  
         obUdpMaster        => obProtocolMasters(0),
         obUdpSlave         => obProtocolSlaves(0),
         ibUdpMaster        => ibProtocolMasters(0),
         ibUdpSlave         => ibProtocolSlaves(0),
         -- Interface to ARP Engine
         arpReqMasters(0)   => arpReqMasters(0),
         arpReqSlaves(0)    => arpReqSlaves(0),
         arpAckMasters(0)   => arpAckMasters(0),
         arpAckSlaves(0)    => arpAckSlaves(0),
         -- Interface to UDP Server engine(s)
         obServerMasters(0) => obServerMasters(0),
         obServerSlaves(0)  => obServerSlaves(0),
         ibServerMasters(0) => ibServerMasters(0),
         ibServerSlaves(0)  => ibServerSlaves(0),
         -- Interface to UDP Client engine(s)
         clientRemotePort   => (others => x"0020"),
         clientRemoteIp     => (others => REMOTE_IP_C),
         obClientMasters(0) => obClientMasters(0),
         obClientSlaves(0)  => obClientSlaves(0),
         ibClientMasters(0) => ibClientMasters(0),
         ibClientSlaves(0)  => ibClientSlaves(0),
         -- Clock and Reset
         clk                => clk,
         rst                => rst);    

   UdpEngineCoreTb_Inst : entity work.UdpEngineCoreTb
      generic map (
         TPD_G => TPD_C)
      port map (
         -- Interface to UDP Engine
         obClientMaster => obClientMasters(0),
         obClientSlave  => obClientSlaves(0),
         ibClientMaster => ibClientMasters(0),
         ibClientSlave  => ibClientSlaves(0),
         -- Simulation Result
         passed         => passed,
         failed         => failed,
         -- Clock and Reset
         clk            => clk,
         rst            => rst);  

   process(failed, passed)
   begin
      if failed = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;
      if passed = '1' then
         assert false
            report "Simulation Passed!" severity failure;
      end if;
   end process;

end testbed;
