-------------------------------------------------------------------------------
-- Title      : RSSI Protocol: https://confluence.slac.stanford.edu/x/1IyfD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the RssiCore
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
use surf.AxiLitePkg.all;
use surf.SsiPkg.all;
use surf.RssiPkg.all;

entity RssiInterleaveTb is

end RssiInterleaveTb;

architecture testbed of RssiInterleaveTb is

   constant CLK_PERIOD_C     : time     := 10 ns;  -- 1 us makes it easy to count clock cycles in sim GUI
   constant TPD_G            : time     := CLK_PERIOD_C/4;
   constant PRBS_SEED_SIZE_C : positive := 128;

   constant SRV_PKT_LEN_C          : slv(31 downto 0) := x"00000007";  -- PRBS TX packet length
   constant SRV_WINDOW_ADDR_SIZE_C : positive         := 4;     -- RSSI config
   constant SRV_MAX_SEG_SIZE_C     : positive         := 8192;  -- RSSI config

   constant CLT_PKT_LEN_C          : slv(31 downto 0) := x"00000003";  -- PRBS TX packet length
   constant CLT_WINDOW_ADDR_SIZE_C : positive         := 3;     -- RSSI config
   constant CLT_MAX_SEG_SIZE_C     : positive         := 1024;  -- RSSI config

   constant APP_STREAMS_C : positive := 5;

   constant SRV_AXIS_CONFIG_C : AxiStreamConfigArray(APP_STREAMS_C-1 downto 0) := (
      0 => ssiAxiStreamConfig(1),
      1 => ssiAxiStreamConfig(2),
      2 => ssiAxiStreamConfig(4),
      3 => ssiAxiStreamConfig(8),
      4 => ssiAxiStreamConfig(16));

   constant CLT_AXIS_CONFIG_C : AxiStreamConfigArray(APP_STREAMS_C-1 downto 0) := (
      0 => ssiAxiStreamConfig(16),
      1 => ssiAxiStreamConfig(8),
      2 => ssiAxiStreamConfig(4),
      3 => ssiAxiStreamConfig(2),
      4 => ssiAxiStreamConfig(1));

   signal clk        : sl              := '0';
   signal rst        : sl              := '1';
   signal linkUp     : slv(1 downto 0) := "00";
   signal tspMasters : AxiStreamMasterArray(1 downto 0);
   signal tspSlaves  : AxiStreamSlaveArray(1 downto 0);

   signal srvIbMasters : AxiStreamMasterArray(APP_STREAMS_C-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal srvIbSlaves  : AxiStreamSlaveArray(APP_STREAMS_C-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);
   signal srvObMasters : AxiStreamMasterArray(APP_STREAMS_C-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal srvObSlaves  : AxiStreamSlaveArray(APP_STREAMS_C-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);
   signal srvUpdateDet : slv(APP_STREAMS_C-1 downto 0);
   signal srvErrorDet  : slv(APP_STREAMS_C-1 downto 0);

   signal cltIbMasters : AxiStreamMasterArray(APP_STREAMS_C-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal cltIbSlaves  : AxiStreamSlaveArray(APP_STREAMS_C-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);
   signal cltObMasters : AxiStreamMasterArray(APP_STREAMS_C-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal cltObSlaves  : AxiStreamSlaveArray(APP_STREAMS_C-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);
   signal cltUpdateDet : slv(APP_STREAMS_C-1 downto 0);
   signal cltErrorDet  : slv(APP_STREAMS_C-1 downto 0);

   signal passed : sl := '0';
   signal failed : sl := '0';

begin

   ---------------------------
   -- Generate clock and reset
   ---------------------------
   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1 us)     -- Hold reset for this long)
      port map (
         clkP => clk,
         rst  => rst);

   GEN_SRV_DEV :
   for i in 0 to APP_STREAMS_C-1 generate

      U_SsiPrbsTx : entity surf.SsiPrbsTx
         generic map (
            TPD_G                      => TPD_G,
            AXI_EN_G                   => '0',
            GEN_SYNC_FIFO_G            => true,
            PRBS_SEED_SIZE_G           => PRBS_SEED_SIZE_C,
            MASTER_AXI_STREAM_CONFIG_G => SRV_AXIS_CONFIG_C(i))
         port map (
            mAxisClk     => clk,
            mAxisRst     => rst,
            mAxisMaster  => srvIbMasters(i),
            mAxisSlave   => srvIbSlaves(i),
            locClk       => clk,
            locRst       => rst,
            trig         => linkUp(0),
            -- trig         => '0',
            packetLength => SRV_PKT_LEN_C);

      U_SsiPrbsRx : entity surf.SsiPrbsRx
         generic map (
            TPD_G                     => TPD_G,
            GEN_SYNC_FIFO_G           => true,
            PRBS_SEED_SIZE_G          => PRBS_SEED_SIZE_C,
            SLAVE_AXI_STREAM_CONFIG_G => SRV_AXIS_CONFIG_C(i))
         port map (
            sAxisClk       => clk,
            sAxisRst       => rst,
            sAxisMaster    => srvObMasters(i),
            sAxisSlave     => srvObSlaves(i),
            updatedResults => srvUpdateDet(i),
            errorDet       => srvErrorDet(i),
            axiClk         => clk,
            axiRst         => rst);

   end generate GEN_SRV_DEV;

   --------------
   -- RSSI Server
   --------------
   U_RssiServer : entity surf.RssiCoreWrapper
      generic map (
         TPD_G               => TPD_G,
         SERVER_G            => true,                -- Server
         APP_ILEAVE_EN_G     => true,
         APP_STREAMS_G       => APP_STREAMS_C,
         APP_STREAM_ROUTES_G => (
            0                => X"00",
            1                => X"01",
            2                => X"02",
            3                => X"03",
            4                => X"04"),
         TIMEOUT_UNIT_G      => 1.0E-6,
         CLK_FREQUENCY_G     => 100.0E+6,
         MAX_SEG_SIZE_G      => SRV_MAX_SEG_SIZE_C,  -- Using Jumbo frames
         WINDOW_ADDR_SIZE_G  => SRV_WINDOW_ADDR_SIZE_C,
         ACK_TOUT_G          => 25,
         RETRANS_TOUT_G      => 50,
         NULL_TOUT_G         => 200,
         MAX_RETRANS_CNT_G   => 8,
         MAX_CUM_ACK_CNT_G   => 3,
         APP_AXIS_CONFIG_G   => SRV_AXIS_CONFIG_C,
         TSP_AXIS_CONFIG_G   => RSSI_AXIS_CONFIG_C)
      port map (
         clk_i             => clk,
         rst_i             => rst,
         openRq_i          => '1',
         rssiConnected_o   => linkUp(0),
         -- Application Layer Interface
         sAppAxisMasters_i => srvIbMasters,
         sAppAxisSlaves_o  => srvIbSlaves,
         mAppAxisMasters_o => srvObMasters,
         mAppAxisSlaves_i  => srvObSlaves,
         -- Transport Layer Interface
         sTspAxisMaster_i  => tspMasters(0),
         sTspAxisSlave_o   => tspSlaves(0),
         mTspAxisMaster_o  => tspMasters(1),
         mTspAxisSlave_i   => tspSlaves(1));

   --------------
   -- RSSI Client
   --------------
   U_RssiClient : entity surf.RssiCoreWrapper
      generic map (
         TPD_G               => TPD_G,
         SERVER_G            => false,               -- Client
         APP_ILEAVE_EN_G     => true,
         APP_STREAMS_G       => APP_STREAMS_C,
         APP_STREAM_ROUTES_G => (
            0                => X"00",
            1                => X"01",
            2                => X"02",
            3                => X"03",
            4                => X"04"),
         TIMEOUT_UNIT_G      => 1.0E-6,
         CLK_FREQUENCY_G     => 100.0E+6,
         MAX_SEG_SIZE_G      => CLT_MAX_SEG_SIZE_C,  -- Using Jumbo frames
         WINDOW_ADDR_SIZE_G  => CLT_WINDOW_ADDR_SIZE_C,
         ACK_TOUT_G          => 5,
         RETRANS_TOUT_G      => 100,
         NULL_TOUT_G         => 1000,
         MAX_RETRANS_CNT_G   => 16,
         MAX_CUM_ACK_CNT_G   => 2,
         APP_AXIS_CONFIG_G   => CLT_AXIS_CONFIG_C,
         TSP_AXIS_CONFIG_G   => RSSI_AXIS_CONFIG_C)
      port map (
         clk_i             => clk,
         rst_i             => rst,
         openRq_i          => '1',
         rssiConnected_o   => linkUp(1),
         -- Application Layer Interface
         sAppAxisMasters_i => cltIbMasters,
         sAppAxisSlaves_o  => cltIbSlaves,
         mAppAxisMasters_o => cltObMasters,
         mAppAxisSlaves_i  => cltObSlaves,
         -- Transport Layer Interface
         sTspAxisMaster_i  => tspMasters(1),
         sTspAxisSlave_o   => tspSlaves(1),
         mTspAxisMaster_o  => tspMasters(0),
         mTspAxisSlave_i   => tspSlaves(0));

   GEN_CLT_DEV :
   for i in 0 to APP_STREAMS_C-1 generate

      U_SsiPrbsTx : entity surf.SsiPrbsTx
         generic map (
            TPD_G                      => TPD_G,
            AXI_EN_G                   => '0',
            GEN_SYNC_FIFO_G            => true,
            PRBS_SEED_SIZE_G           => PRBS_SEED_SIZE_C,
            MASTER_AXI_STREAM_CONFIG_G => CLT_AXIS_CONFIG_C(i))
         port map (
            mAxisClk     => clk,
            mAxisRst     => rst,
            mAxisMaster  => cltIbMasters(i),
            mAxisSlave   => cltIbSlaves(i),
            locClk       => clk,
            locRst       => rst,
            trig         => linkUp(1),
            -- trig         => '0',
            packetLength => CLT_PKT_LEN_C);

      U_SsiPrbsRx : entity surf.SsiPrbsRx
         generic map (
            TPD_G                     => TPD_G,
            GEN_SYNC_FIFO_G           => true,
            PRBS_SEED_SIZE_G          => PRBS_SEED_SIZE_C,
            SLAVE_AXI_STREAM_CONFIG_G => CLT_AXIS_CONFIG_C(i))
         port map (
            sAxisClk       => clk,
            sAxisRst       => rst,
            sAxisMaster    => cltObMasters(i),
            sAxisSlave     => cltObSlaves(i),
            updatedResults => cltUpdateDet(i),
            errorDet       => cltErrorDet(i),
            axiClk         => clk,
            axiRst         => rst);

   end generate GEN_CLT_DEV;

   process(clk)
   begin
      if rising_edge(clk) then
         failed <= uOr(srvErrorDet) or uOr(cltErrorDet) after TPD_G;
      end if;
   end process;

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
