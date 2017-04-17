-------------------------------------------------------------------------------
-- File       : EthMacTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-09-20
-- Last update: 2016-09-21
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the EthMac module
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.EthMacPkg.all;

entity EthMacTb is
end EthMacTb;

architecture testbed of EthMacTb is

   constant CLK_PERIOD_C : time := 6.4 ns;
   constant TPD_G        : time := (CLK_PERIOD_C/4);

   constant MAC_ADDR_C : Slv48Array(1 downto 0) := (0 => x"010300564400", 1 => x"020300564400");
   constant IP_ADDR_C  : Slv32Array(1 downto 0) := (0 => x"0A02A8C0", 1 => x"0B02A8C0");

   signal clk          : sl                            := '0';
   signal rst          : sl                            := '0';
   signal txMaster     : AxiStreamMasterType;
   signal txSlave      : AxiStreamSlaveType;
   signal obMacMasters : AxiStreamMasterArray(1 downto 0);
   signal obMacSlaves  : AxiStreamSlaveArray(1 downto 0);
   signal ibMacMasters : AxiStreamMasterArray(1 downto 0);
   signal ibMacSlaves  : AxiStreamSlaveArray(1 downto 0);
   signal ethConfig    : EthMacConfigArray(1 downto 0) := (others => ETH_MAC_CONFIG_INIT_C);
   signal phyD         : Slv64Array(1 downto 0);
   signal phyC         : Slv8Array(1 downto 0);
   signal rxMaster     : AxiStreamMasterType;
   signal rxSlave      : AxiStreamSlaveType;
   signal phyReady     : sl;
   signal errorDet     : sl;

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
         rstL => phyReady);     

   ----------
   -- PRBS TX
   ----------
   U_TX : entity work.SsiPrbsTx
      generic map (
         TPD_G                      => TPD_G,
         CASCADE_SIZE_G             => 1,
         FIFO_ADDR_WIDTH_G          => 9,
         FIFO_PAUSE_THRESH_G        => 2**8,
         PRBS_SEED_SIZE_G           => 32,
         PRBS_TAPS_G                => (0 => 31, 1 => 6, 2 => 2, 3 => 1),
         MASTER_AXI_STREAM_CONFIG_G => EMAC_AXIS_CONFIG_C,
         MASTER_AXI_PIPE_STAGES_G   => 1)
      port map (
         mAxisClk     => clk,
         mAxisRst     => rst,
         mAxisMaster  => txMaster,
         mAxisSlave   => txSlave,
         locClk       => clk,
         locRst       => rst,
         trig         => '1',
         packetLength => X"000000ff");    

   ----------------------
   -- IPv4/ARP/UDP Engine
   ----------------------
   U_UDP_Client : entity work.UdpEngineWrapper
      generic map (
         TPD_G               => TPD_G,
         SERVER_EN_G         => false,
         CLIENT_EN_G         => true,
         CLIENT_EXT_CONFIG_G => true)
      port map (
         -- Local Configurations
         localMac            => MAC_ADDR_C(0),
         localIp             => IP_ADDR_C(0),
         -- Remote Configurations
         clientRemotePort(0) => x"0020",  -- 0x2000
         clientRemoteIp(0)   => IP_ADDR_C(1),
         -- Interface to Ethernet Media Access Controller (MAC)
         obMacMaster         => obMacMasters(0),
         obMacSlave          => obMacSlaves(0),
         ibMacMaster         => ibMacMasters(0),
         ibMacSlave          => ibMacSlaves(0),
         -- Interface to UDP Server engine(s)
         obClientMasters     => open,
         obClientSlaves(0)   => AXI_STREAM_SLAVE_FORCE_C,
         ibClientMasters(0)  => txMaster,
         ibClientSlaves(0)   => txSlave,
         -- Clock and Reset
         clk                 => clk,
         rst                 => rst);     

   --------------------
   -- Ethernet MAC core
   --------------------
   U_MAC0 : entity work.EthMacTop
      generic map (
         TPD_G         => TPD_G,
         PHY_TYPE_G    => "XGMII",
         PRIM_CONFIG_G => EMAC_AXIS_CONFIG_C)
      port map (
         -- DMA Interface 
         primClk         => clk,
         primRst         => rst,
         ibMacPrimMaster => obMacMasters(0),
         ibMacPrimSlave  => obMacSlaves(0),
         obMacPrimMaster => ibMacMasters(0),
         obMacPrimSlave  => ibMacSlaves(0),
         -- Ethernet Interface
         ethClk          => clk,
         ethRst          => rst,
         ethConfig       => ethConfig(0),
         phyReady        => phyReady,
         -- XGMII PHY Interface
         xgmiiRxd        => phyD(0),
         xgmiiRxc        => phyC(0),
         xgmiiTxd        => phyD(1),
         xgmiiTxc        => phyC(1));  
   ethConfig(0).macAddress <= MAC_ADDR_C(0);

   U_MAC1 : entity work.EthMacTop
      generic map (
         TPD_G         => TPD_G,
         PHY_TYPE_G    => "XGMII",
         PRIM_CONFIG_G => EMAC_AXIS_CONFIG_C)
      port map (
         -- DMA Interface 
         primClk         => clk,
         primRst         => rst,
         ibMacPrimMaster => obMacMasters(1),
         ibMacPrimSlave  => obMacSlaves(1),
         obMacPrimMaster => ibMacMasters(1),
         obMacPrimSlave  => ibMacSlaves(1),
         -- Ethernet Interface
         ethClk          => clk,
         ethRst          => rst,
         ethConfig       => ethConfig(1),
         phyReady        => phyReady,
         -- XGMII PHY Interface
         xgmiiRxd        => phyD(1),
         xgmiiRxc        => phyC(1),
         xgmiiTxd        => phyD(0),
         xgmiiTxc        => phyC(0));  
   ethConfig(1).macAddress <= MAC_ADDR_C(1);

   ----------------------
   -- IPv4/ARP/UDP Engine
   ----------------------
   U_UDP_Server : entity work.UdpEngineWrapper
      generic map (
         TPD_G       => TPD_G,
         SERVER_EN_G => true,
         CLIENT_EN_G => false)
      port map (
         -- Local Configurations
         localMac           => MAC_ADDR_C(1),
         localIp            => IP_ADDR_C(1),
         -- Interface to Ethernet Media Access Controller (MAC)
         obMacMaster        => obMacMasters(1),
         obMacSlave         => obMacSlaves(1),
         ibMacMaster        => ibMacMasters(1),
         ibMacSlave         => ibMacSlaves(1),
         -- Interface to UDP Server engine(s)
         obServerMasters(0) => rxMaster,
         obServerSlaves(0)  => rxSlave,
         ibServerMasters(0) => AXI_STREAM_MASTER_INIT_C,
         ibServerSlaves     => open,
         -- Clock and Reset
         clk                => clk,
         rst                => rst);  

   ----------
   -- PRBS RX
   ----------
   U_RX : entity work.SsiPrbsRx
      generic map (
         TPD_G                     => TPD_G,
         CASCADE_SIZE_G            => 1,
         FIFO_ADDR_WIDTH_G         => 9,
         FIFO_PAUSE_THRESH_G       => 2**8,
         PRBS_SEED_SIZE_G          => 32,
         PRBS_TAPS_G               => (0 => 31, 1 => 6, 2 => 2, 3 => 1),
         SLAVE_AXI_STREAM_CONFIG_G => EMAC_AXIS_CONFIG_C,
         SLAVE_AXI_PIPE_STAGES_G   => 0)
      port map (
         errorDet    => errorDet,
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => rxMaster,
         sAxisSlave  => rxSlave,
         mAxisClk    => clk,
         mAxisRst    => rst,
         axiClk      => clk,
         axiRst      => rst);           

end testbed;
