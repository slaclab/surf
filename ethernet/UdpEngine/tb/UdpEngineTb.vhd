-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.EthMacPkg.all;

entity UdpEngineTb is
end UdpEngineTb;

architecture testbed of UdpEngineTb is

   constant CLK_PERIOD_C : time := 6.4 ns;
   constant TPD_G        : time := (CLK_PERIOD_C/4);

   constant MAC_ADDR_C : Slv48Array(1 downto 0) := (
      0 => x"010300564400",             --00:44:56:00:03:01
      1 => x"020300564400");            --00:44:56:00:03:02

   constant IP_ADDR_C : Slv32Array(1 downto 0) := (
      0 => x"0A02A8C0",                 -- 192.168.2.10
      1 => x"0B02A8C0");                -- 192.168.2.11

   type RegType is record
      packetLength : slv(31 downto 0);
      trig         : sl;
      txBusy       : sl;
      errorDet     : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      packetLength => toSlv(0, 32),
      trig         => '0',
      txBusy       => '0',
      errorDet     => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal clk : sl := '0';
   signal rst : sl := '0';

   signal txMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal txSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal obMacMasters : AxiStreamMasterArray(1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal obMacSlaves  : AxiStreamSlaveArray(1 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);

   signal ibMacMasters : AxiStreamMasterArray(1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal ibMacSlaves  : AxiStreamSlaveArray(1 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);

   signal ethConfig : EthMacConfigArray(1 downto 0) := (others => ETH_MAC_CONFIG_INIT_C);
   signal phyD      : Slv64Array(1 downto 0)        := (others => (others => '0'));
   signal phyC      : Slv8Array(1 downto 0)         := (others => (others => '0'));

   signal rxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal rxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal phyReady       : sl;
   signal updatedResults : sl;
   signal errorDet       : sl;
   signal rxBusy         : sl;
   signal txBusy         : sl;

begin

   ClkRst_Inst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1000 ns)
      port map (
         clkP => clk,
         clkN => open,
         rst  => rst,
         rstL => phyReady);

   ----------
   -- PRBS TX
   ----------
   U_TX : entity surf.SsiPrbsTx
      generic map (
         TPD_G                      => TPD_G,
         AXI_EN_G                   => '0',
         MASTER_AXI_STREAM_CONFIG_G => EMAC_AXIS_CONFIG_C)
      port map (
         -- Master Port (mAxisClk)
         mAxisClk     => clk,
         mAxisRst     => rst,
         mAxisMaster  => txMaster,
         mAxisSlave   => txSlave,
         -- Trigger Signal (locClk domain)
         locClk       => clk,
         locRst       => rst,
         packetLength => r.packetLength,
         trig         => r.trig,
         busy         => txBusy);

   ----------------------
   -- IPv4/ARP/UDP Engine
   ----------------------
   U_UDP_Client : entity surf.UdpEngineWrapper
      generic map (
         -- Simulation Generics
         TPD_G               => TPD_G,
         -- UDP Server Generics
         SERVER_EN_G         => false,
         -- UDP Client Generics
         CLIENT_EN_G         => true,
         CLIENT_SIZE_G       => 1,
         CLIENT_PORTS_G      => (0 => 8193),
         CLIENT_EXT_CONFIG_G => true)
      port map (
         -- Local Configurations
         localMac            => MAC_ADDR_C(0),
         localIp             => IP_ADDR_C(0),
         -- Remote Configurations
         clientRemotePort(0) => x"0020",  -- PORT = 8192 = 0x2000 (0x0020 in big endianness)
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
   U_MAC0 : entity surf.EthMacTop
      generic map (
         TPD_G         => TPD_G,
         PHY_TYPE_G    => "XGMII",
         PRIM_CONFIG_G => EMAC_AXIS_CONFIG_C)
      port map (
         -- DMA Interface
         primClk         => clk,
         primRst         => rst,
         ibMacPrimMaster => ibMacMasters(0),
         ibMacPrimSlave  => ibMacSlaves(0),
         obMacPrimMaster => obMacMasters(0),
         obMacPrimSlave  => obMacSlaves(0),
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

   U_MAC1 : entity surf.EthMacTop
      generic map (
         TPD_G         => TPD_G,
         PHY_TYPE_G    => "XGMII",
         PRIM_CONFIG_G => EMAC_AXIS_CONFIG_C)
      port map (
         -- DMA Interface
         primClk         => clk,
         primRst         => rst,
         ibMacPrimMaster => ibMacMasters(1),
         ibMacPrimSlave  => ibMacSlaves(1),
         obMacPrimMaster => obMacMasters(1),
         obMacPrimSlave  => obMacSlaves(1),
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
   U_UDP_Server : entity surf.UdpEngineWrapper
      generic map (
         -- Simulation Generics
         TPD_G          => TPD_G,
         -- UDP Server Generics
         SERVER_EN_G    => true,
         SERVER_SIZE_G  => 1,
         SERVER_PORTS_G => (0 => 8192),
         -- UDP Client Generics
         CLIENT_EN_G    => false)
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
   U_RX : entity surf.SsiPrbsRx
      generic map (
         TPD_G                     => TPD_G,
         SLAVE_AXI_STREAM_CONFIG_G => EMAC_AXIS_CONFIG_C)
      port map (
         -- Slave Port (sAxisClk)
         sAxisClk       => clk,
         sAxisRst       => rst,
         sAxisMaster    => rxMaster,
         sAxisSlave     => rxSlave,
         -- Error Detection Signals (sAxisClk domain)
         updatedResults => updatedResults,
         errorDet       => errorDet,
         busy           => rxBusy);

   comb : process (errorDet, r, rst, txBusy) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Keep delay copies
      v.errorDet := errorDet;
      v.txBusy   := txBusy;
      v.trig     := not(r.txBusy);

      -- Check for the packet completion
      if (txBusy = '1') and (r.txBusy = '0') then
         -- Sweeping the packet size size
         v.packetLength := r.packetLength + 1;
         -- Check for Jumbo frame roll over
         if (r.packetLength = (8192/4)-1) then
            -- Reset the counter
            v.packetLength := (others => '0');
         end if;
      end if;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      ---------------------------------
      -- Simulation Error Self-checking
      ---------------------------------
      if r.errorDet = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end testbed;
