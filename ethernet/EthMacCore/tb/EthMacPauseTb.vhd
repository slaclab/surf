-------------------------------------------------------------------------------
-- Title      : SSI Protocol: https://confluence.slac.stanford.edu/x/0oyfD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the EthMacPause module
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

entity EthMacPauseTb is end EthMacPauseTb;

architecture testbed of EthMacPauseTb is

   constant CLK_PERIOD_C : time := 10 ns;
   constant TPD_C        : time := CLK_PERIOD_C/4;

   constant TX_PACKET_LENGTH_C : slv(31 downto 0) := toSlv((8800/16)-1, 32);  -- 8800B frames

   constant PRBS_SEED_SIZE_C : natural      := 128;
   constant PRBS_TAPS_C      : NaturalArray := (0 => 31, 1 => 6, 2 => 2, 3 => 1);
   constant PRBS_FLOW_CTRL_C : boolean      := true;

   constant CLT_MAC_C  : slv(47 downto 0) := x"000000560008";  -- 08:00:56:00:00:00
   constant CLT_IP_C   : slv(31 downto 0) := x"0A02A8C0";  -- 192.168.2.10
   constant CLT_PORT_C : positive         := 8193;

   constant SRV_MAC_C      : slv(47 downto 0) := x"010000560008";  -- 08:00:56:00:00:01
   constant SRV_IP_C       : slv(31 downto 0) := x"0B02A8C0";  -- 192.168.2.11
   constant SRV_PORT_C     : positive         := 8192;
   constant SRV_PORT_SLV_C : slv(15 downto 0) := x"0020";  -- 8192 in big-Endian configuration

   signal clk  : sl := '0';
   signal trig : sl := '0';
   signal rst  : sl := '1';

   signal txMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal txSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal obMacMasters : AxiStreamMasterArray(1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal obMacSlaves  : AxiStreamSlaveArray(1 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal ibMacMasters : AxiStreamMasterArray(1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal ibMacSlaves  : AxiStreamSlaveArray(1 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);

   signal xgmiiData : Slv64Array(1 downto 0) := (others => (others => '0'));
   signal xgmiiChar : Slv8Array(1 downto 0)  := (others => (others => '0'));

   signal rxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal rxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal prbsFlowCtrlMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal prbsFlowCtrlSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal updated      : sl               := '0';
   signal errorDet     : sl               := '0';
   signal errLength    : sl               := '0';
   signal errDataBus   : sl               := '0';
   signal errEofe      : sl               := '0';
   signal errWordCnt   : slv(31 downto 0) := (others => '0');
   signal packetLength : slv(31 downto 0) := (others => '0');
   signal cnt          : slv(31 downto 0) := (others => '0');

   signal ethConfig : EthMacConfigArray(1 downto 0) := (others => ETH_MAC_CONFIG_INIT_C);
   signal ethStatus : EthMacStatusArray(1 downto 0);

   signal failedVec : slv(15 downto 0) := (others => '0');

   signal passed : sl := '0';
   signal failed : sl := '0';

begin

   -----------------------------
   -- Generate clocks and resets
   -----------------------------
   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1 us)
      port map (
         clkP => clk,
         rst  => rst);

   ----------------------
   -- Client: Data Source
   ----------------------
   U_Tx : entity surf.SsiPrbsTx
      generic map (
         -- General Configurations
         TPD_G                      => TPD_C,
         AXI_EN_G                   => '0',
         -- FIFO Configurations
         GEN_SYNC_FIFO_G            => true,
         SYNTH_MODE_G               => "xpm",
         MEMORY_TYPE_G              => "block",
         -- PRBS Configurations
         PRBS_SEED_SIZE_G           => PRBS_SEED_SIZE_C,
         PRBS_TAPS_G                => PRBS_TAPS_C,
         -- AXI Stream Configurations
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
         trig         => trig,
         packetLength => TX_PACKET_LENGTH_C);

   trig <= not(rst);

   ------------------------------
   -- Client: IPv4/ARP/UDP Engine
   ------------------------------
   U_CltUdp : entity surf.UdpEngineWrapper
      generic map (
         -- Simulation Generics
         TPD_G               => TPD_C,
         -- UDP Server Generics
         SERVER_EN_G         => false,
         -- UDP Client Generics
         CLIENT_EN_G         => true,
         CLIENT_SIZE_G       => 1,
         CLIENT_PORTS_G      => (0 => CLT_PORT_C),
         -- General IPv4/ICMP/ARP/DHCP Generics
         TX_FLOW_CTRL_G      => false,  -- False: Backpressure until TX link is up
         CLIENT_EXT_CONFIG_G => true)
      port map (
         -- Local Configurations
         localMac            => CLT_MAC_C,
         localIp             => CLT_IP_C,
         -- Interface to Ethernet Media Access Controller (MAC)
         obMacMaster         => obMacMasters(0),
         obMacSlave          => obMacSlaves(0),
         ibMacMaster         => ibMacMasters(0),
         ibMacSlave          => ibMacSlaves(0),
         -- Remote Configurations
         clientRemotePort(0) => SRV_PORT_SLV_C,
         clientRemoteIp(0)   => SRV_IP_C,
         -- Interface to UDP Client engine(s)
         ibClientMasters(0)  => txMaster,
         ibClientSlaves(0)   => txSlave,
         -- Clock and Reset
         clk                 => clk,
         rst                 => rst);

   -----------------------
   -- Client: Ethernet MAC
   -----------------------
   U_CltMac : entity surf.EthMacTop
      generic map (
         TPD_G         => TPD_C,
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
         phyReady        => '1',
         ethConfig       => ethConfig(0),
         ethStatus       => ethStatus(0),
         -- XGMII PHY Interface
         xgmiiRxd        => xgmiiData(0),
         xgmiiRxc        => xgmiiChar(0),
         xgmiiTxd        => xgmiiData(1),
         xgmiiTxc        => xgmiiChar(1));

   ethConfig(0).macAddress <= CLT_MAC_C;

   -----------------------
   -- Server: Ethernet MAC
   -----------------------
   U_SrvMac : entity surf.EthMacTop
      generic map (
         TPD_G         => TPD_C,
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
         phyReady        => '1',
         ethConfig       => ethConfig(1),
         ethStatus       => ethStatus(1),
         -- XGMII PHY Interface
         xgmiiRxd        => xgmiiData(1),
         xgmiiRxc        => xgmiiChar(1),
         xgmiiTxd        => xgmiiData(0),
         xgmiiTxc        => xgmiiChar(0));

   ethConfig(1).macAddress <= SRV_MAC_C;

   ------------------------------
   -- Server: IPv4/ARP/UDP Engine
   ------------------------------
   U_SrvUdp : entity surf.UdpEngineWrapper
      generic map (
         -- Simulation Generics
         TPD_G          => TPD_C,
         -- UDP Server Generics
         SERVER_EN_G    => true,
         SERVER_SIZE_G  => 1,
         SERVER_PORTS_G => (0 => SRV_PORT_C),
         -- UDP Client Generics
         CLIENT_EN_G    => false)
      port map (
         -- Local Configurations
         localMac           => SRV_MAC_C,
         localIp            => SRV_IP_C,
         -- Interface to Ethernet Media Access Controller (MAC)
         obMacMaster        => obMacMasters(1),
         obMacSlave         => obMacSlaves(1),
         ibMacMaster        => ibMacMasters(1),
         ibMacSlave         => ibMacSlaves(1),
         -- Interface to UDP Client engine(s)
         obServerMasters(0) => rxMaster,
         obServerSlaves(0)  => rxSlave,
         -- Clock and Reset
         clk                => clk,
         rst                => rst);

   -------------------
   -- Server:Data Sink
   -------------------
   U_Rx : entity surf.SsiPrbsRx
      generic map (
         -- General Configurations
         TPD_G                      => TPD_C,
         -- FIFO Configurations
         GEN_SYNC_FIFO_G            => true,
         SYNTH_MODE_G               => "xpm",
         MEMORY_TYPE_G              => "block",
         -- PRBS Configurations
         PRBS_SEED_SIZE_G           => PRBS_SEED_SIZE_C,
         PRBS_TAPS_G                => PRBS_TAPS_C,
         -- AXI Stream Configurations
         SLAVE_AXI_STREAM_CONFIG_G  => EMAC_AXIS_CONFIG_C,
         MASTER_AXI_STREAM_CONFIG_G => ssiAxiStreamConfig(1))  -- Bottleneck the rate
      port map (
         -- Streaming RX Data Interface (sAxisClk domain)
         sAxisClk       => clk,
         sAxisRst       => rst,
         sAxisMaster    => rxMaster,
         sAxisSlave     => rxSlave,
         -- Optional: TX Data Interface with EOFE tagging (sAxisClk domain)
         mAxisMaster    => prbsFlowCtrlMaster,
         mAxisSlave     => prbsFlowCtrlSlave,
         -- Error Detection Signals (sAxisClk domain)
         updatedResults => updated,
         errorDet       => errorDet,
         packetLength   => packetLength,
         errLength      => errLength,
         errDataBus     => errDataBus,
         errEofe        => errEofe,
         errWordCnt     => errWordCnt);

   ------------------------------------
   -- Assert PseudoRandom back pressure
   ------------------------------------
   GEN_PRBS_FLOW_CTRL : if (PRBS_FLOW_CTRL_C) generate
      U_PrbsFlowCtrl : entity surf.AxiStreamPrbsFlowCtrl
         generic map (
            TPD_G => TPD_C)
         port map (
            clk         => clk,
            rst         => rst,
            threshold   => x"F000_0000",
            -- Slave Port
            sAxisMaster => prbsFlowCtrlMaster,
            sAxisSlave  => prbsFlowCtrlSlave,
            -- Master Port
            mAxisMaster => open,
            mAxisSlave  => AXI_STREAM_SLAVE_FORCE_C);
            -- mAxisSlave  => AXI_STREAM_SLAVE_INIT_C);
   end generate;

   -----------------
   -- Error Checking
   -----------------
   error_checking : process(clk)
   begin
      if rising_edge(clk) then
         -- Check that not in reset
         if (rst = '0') then

            -- Map the error flag to the failed test vector
            failedVec(0) <= ethStatus(0).rxFifoDropCnt after TPD_C;
            failedVec(1) <= ethStatus(0).rxOverFlow    after TPD_C;
            failedVec(2) <= ethStatus(0).rxCrcErrorCnt after TPD_C;
            failedVec(3) <= ethStatus(0).txUnderRunCnt after TPD_C;
            failedVec(4) <= ethStatus(0).txNotReadyCnt after TPD_C;

            failedVec(5) <= ethStatus(1).rxFifoDropCnt after TPD_C;
            failedVec(6) <= ethStatus(1).rxOverFlow    after TPD_C;
            failedVec(7) <= ethStatus(1).rxCrcErrorCnt after TPD_C;
            failedVec(8) <= ethStatus(1).txUnderRunCnt after TPD_C;
            failedVec(9) <= ethStatus(1).txNotReadyCnt after TPD_C;

            -- Check for RX PRBS update
            if updated = '1' then

               -- Map the error flag to the failed test vector
               failedVec(10) <= errorDet   after TPD_C;
               failedVec(11) <= errLength  after TPD_C;
               failedVec(12) <= errDataBus after TPD_C;
               failedVec(13) <= errEofe    after TPD_C;

               -- Check for non-zero error word counts
               if errWordCnt /= 0 then
                  failedVec(14) <= '1' after TPD_C;
               else
                  failedVec(14) <= '0' after TPD_C;
               end if;

               -- Check for mismatch in expect length
               if packetLength /= TX_PACKET_LENGTH_C then
                  failedVec(15) <= '1' after TPD_C;
               else
                  failedVec(15) <= '0' after TPD_C;
               end if;

               -- Increment the counter
               cnt <= cnt + 1 after TPD_C;

            end if;
         end if;
      end if;
   end process error_checking;

   results : process (clk) is
   begin
      if rising_edge(clk) then

         -- OR Failed bits together
         failed <= uOR(failedVec) after TPD_C;

         -- Check for counter
         if (cnt = x"0001_0000") then
            passed <= '1' after TPD_C;
         end if;

      end if;
   end process results;

   process(failed, passed)
   begin
      if passed = '1' then
         assert false
            report "Simulation Passed!" severity failure;
      elsif failed = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;
   end process;

end testbed;
