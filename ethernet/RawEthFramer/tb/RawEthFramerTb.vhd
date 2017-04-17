-------------------------------------------------------------------------------
-- File       : RawEthFramerTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-05-24
-- Last update: 2016-05-26
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the RawEthFramer module
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

entity RawEthFramerTb is end RawEthFramerTb;

architecture testbed of RawEthFramerTb is

   constant CLK_PERIOD_C : time := 6.4 ns;
   constant TPD_G        : time := (CLK_PERIOD_C/4);

   constant BYPASS_UDP_C              : boolean          := true;
   constant BYPASS_RSSI_C             : boolean          := false;
   constant BYPASS_CHUNKER_C          : boolean          := false;
   constant PKT_LEN_C                 : slv(31 downto 0) := X"000000AB";
   constant PRBS_SEED_SIZE_C          : positive         := 128;
   constant CLIENT_WINDOW_ADDR_SIZE_C : positive         := 1;
   constant CLIENT_MAX_NUM_OUTS_SEG_C : positive         := (2**CLIENT_WINDOW_ADDR_SIZE_C);

   constant SERVER_WINDOW_ADDR_SIZE_C : positive := CLIENT_WINDOW_ADDR_SIZE_C;
   constant SERVER_MAX_NUM_OUTS_SEG_C : positive := (2**CLIENT_WINDOW_ADDR_SIZE_C);

   constant MAC_ADDR_C : Slv48Array(2 downto 0) := (0 => x"010300564400", 1 => x"020300564400", 2 => x"030300564400");
   constant IP_ADDR_C  : Slv32Array(2 downto 0) := (0 => x"0A02A8C0", 1 => x"0B02A8C0", 2 => x"0C02A8C0");
   
   constant AXIS_CONFIG_C : AxiStreamConfigArray(3 downto 0) := ( others => EMAC_AXIS_CONFIG_C); 

   signal clk : sl;
   signal rst : sl;

   signal rxMasters : AxiStreamMasterArray(1 downto 0);
   signal rxSlaves  : AxiStreamSlaveArray(1 downto 0);
   signal txMasters : AxiStreamMasterArray(1 downto 0);
   signal txSlaves  : AxiStreamSlaveArray(1 downto 0);

   signal ibServerMaster : AxiStreamMasterType;
   signal ibServerSlave  : AxiStreamSlaveType;
   signal obServerMaster : AxiStreamMasterType;
   signal obServerSlave  : AxiStreamSlaveType;

   signal ibClientMaster : AxiStreamMasterType;
   signal ibClientSlave  : AxiStreamSlaveType;
   signal obClientMaster : AxiStreamMasterType;
   signal obClientSlave  : AxiStreamSlaveType;

   signal ibServerMasters : AxiStreamMasterArray(1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal ibServerSlaves  : AxiStreamSlaveArray(1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);
   signal obServerMasters : AxiStreamMasterArray(1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal obServerSlaves  : AxiStreamSlaveArray(1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);

   signal ibClientMasters : AxiStreamMasterArray(1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal ibClientSlaves  : AxiStreamSlaveArray(1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);
   signal obClientMasters : AxiStreamMasterArray(1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal obClientSlaves  : AxiStreamSlaveArray(1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);

   signal errorDet    : slv(0 downto 0);
   signal start       : sl;
   signal stop        : sl;
   signal cnt         : Slv(31 downto 0);
   signal tdc         : Slv(31 downto 0);
   signal trig        : slv(1 downto 0);
   signal frameRate   : Slv32Array(1 downto 0);
   signal errorDetCnt : SlVectorArray(0 downto 0, 31 downto 0);
   
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

   -- Loopback the PHY streams
   rxMasters(0) <= txMasters(1);
   txSlaves(1)  <= rxSlaves(0);
   rxMasters(1) <= txMasters(0);
   txSlaves(0)  <= rxSlaves(1);

   GEN_UDP : if (BYPASS_UDP_C = false) generate

      -------------------------
      -- IPv4/ARP/UDP Engine[0]
      -------------------------
      U_Server : entity work.UdpEngineWrapper
         generic map (
            -- Simulation Generics
            TPD_G              => TPD_G,
            SIM_ERROR_HALT_G   => false,
            -- UDP General Generic
            RX_MTU_G           => 1500,
            RX_FORWARD_EOFE_G  => false,
            TX_FORWARD_EOFE_G  => false,
            TX_CALC_CHECKSUM_G => true,
            -- UDP Server Generics
            SERVER_EN_G        => true,
            SERVER_SIZE_G      => 1,
            SERVER_PORTS_G     => (0 => 4369),
            SERVER_MTU_G       => 1500,
            -- UDP Client Generics
            CLIENT_EN_G        => false)
         port map (
            -- Local Configurations
            localMac           => MAC_ADDR_C(0),
            localIp            => IP_ADDR_C(0),
            -- Interface to Ethernet Media Access Controller (MAC)
            obMacMaster        => rxMasters(0),
            obMacSlave         => rxSlaves(0),
            ibMacMaster        => txMasters(0),
            ibMacSlave         => txSlaves(0),
            -- Interface to UDP Server engine(s)
            obServerMasters(0) => obServerMaster,
            obServerSlaves(0)  => obServerSlave,
            ibServerMasters(0) => ibServerMaster,
            ibServerSlaves(0)  => ibServerSlave,
            -- Clock and Reset
            clk                => clk,
            rst                => rst);

      -------------------------
      -- IPv4/ARP/UDP Engine[1]
      -------------------------
      U_Client : entity work.UdpEngineWrapper
         generic map (
            -- Simulation Generics
            TPD_G               => TPD_G,
            SIM_ERROR_HALT_G    => false,
            -- UDP General Generic
            RX_MTU_G            => 1500,
            RX_FORWARD_EOFE_G   => false,
            TX_FORWARD_EOFE_G   => false,
            TX_CALC_CHECKSUM_G  => true,
            -- UDP Server Generics
            SERVER_EN_G         => false,
            -- UDP Client Generics
            CLIENT_EN_G         => true,
            CLIENT_SIZE_G       => 1,
            CLIENT_PORTS_G      => (0 => 8738),
            CLIENT_MTU_G        => 1500,
            CLIENT_EXT_CONFIG_G => true)
         port map (
            -- Local Configurations
            localMac            => MAC_ADDR_C(1),
            localIp             => IP_ADDR_C(1),
            -- Remote Configurations
            clientRemotePort(0) => x"1111",
            clientRemoteIp(0)   => IP_ADDR_C(0),
            -- Interface to Ethernet Media Access Controller (MAC)
            obMacMaster         => rxMasters(1),
            obMacSlave          => rxSlaves(1),
            ibMacMaster         => txMasters(1),
            ibMacSlave          => txSlaves(1),
            -- Interface to UDP Server engine(s)
            obClientMasters(0)  => obClientMaster,
            obClientSlaves(0)   => obClientSlave,
            ibClientMasters(0)  => ibClientMaster,
            ibClientSlaves(0)   => ibClientSlave,
            -- Clock and Reset
            clk                 => clk,
            rst                 => rst);         

   end generate;


   BYPASS_UDP : if (BYPASS_UDP_C = true) generate

      --------------------
      -- RAW ETH Engine[0]
      --------------------
      U_Server : entity work.RawEthFramer
         generic map (
            TPD_G => TPD_G)
         port map (
            -- Local Configurations
            localMac    => MAC_ADDR_C(0),
            remoteMac   => MAC_ADDR_C(1),
            -- Interface to Ethernet Media Access Controller (MAC)
            obMacMaster => rxMasters(0),
            obMacSlave  => rxSlaves(0),
            ibMacMaster => txMasters(0),
            ibMacSlave  => txSlaves(0),
            -- Interface to Application engine(s)
            ibAppMaster => obServerMaster,
            ibAppSlave  => obServerSlave,
            obAppMaster => ibServerMaster,
            obAppSlave  => ibServerSlave,
            -- Clock and Reset
            clk         => clk,
            rst         => rst);

      --------------------
      -- RAW ETH Engine[1]
      --------------------
      U_Client : entity work.RawEthFramer
         generic map (
            TPD_G => TPD_G)
         port map (
            -- Local Configurations
            localMac    => MAC_ADDR_C(1),
            remoteMac   => MAC_ADDR_C(0),
            -- Interface to Ethernet Media Access Controller (MAC)
            obMacMaster => rxMasters(1),
            obMacSlave  => rxSlaves(1),
            ibMacMaster => txMasters(1),
            ibMacSlave  => txSlaves(1),
            -- Interface to Application engine(s)
            ibAppMaster => obClientMaster,
            ibAppSlave  => obClientSlave,
            obAppMaster => ibClientMaster,
            obAppSlave  => ibClientSlave,
            -- Clock and Reset
            clk         => clk,
            rst         => rst);      

   end generate;

   GEN_RSSI : if (BYPASS_RSSI_C = false) generate

      -------------------------------
      -- RSSI Server Interface @ 4369
      -------------------------------
      U_RssiServer : entity work.RssiCoreWrapper
         generic map (
            TPD_G                    => TPD_G,
            APP_STREAMS_G            => 2,
            APP_STREAM_ROUTES_G      => (
               0                     => X"00",
               1                     => X"01"),
            CLK_FREQUENCY_G          => 156.25E+6,
            TIMEOUT_UNIT_G           => 1.0E-6,
            SERVER_G                 => true,
            RETRANSMIT_ENABLE_G      => true,
            BYPASS_CHUNKER_G         => BYPASS_CHUNKER_C,
            WINDOW_ADDR_SIZE_G       => SERVER_WINDOW_ADDR_SIZE_C,
            MAX_NUM_OUTS_SEG_G       => SERVER_MAX_NUM_OUTS_SEG_C,
            PIPE_STAGES_G            => 1,
            APP_INPUT_AXIS_CONFIG_G  => EMAC_AXIS_CONFIG_C,
            APP_OUTPUT_AXIS_CONFIG_G => EMAC_AXIS_CONFIG_C,
            TSP_INPUT_AXIS_CONFIG_G  => EMAC_AXIS_CONFIG_C,
            TSP_OUTPUT_AXIS_CONFIG_G => EMAC_AXIS_CONFIG_C,
            MAX_RETRANS_CNT_G        => 1,
            MAX_CUM_ACK_CNT_G        => 1)
         port map (
            clk_i             => clk,
            rst_i             => rst,
            openRq_i          => '1',
            -- Application Layer Interface
            sAppAxisMasters_i => obServerMasters,
            sAppAxisSlaves_o  => obServerSlaves,
            mAppAxisMasters_o => ibServerMasters,
            mAppAxisSlaves_i  => ibServerSlaves,
            -- Transport Layer Interface
            sTspAxisMaster_i  => obServerMaster,
            sTspAxisSlave_o   => obServerSlave,
            mTspAxisMaster_o  => ibServerMaster,
            mTspAxisSlave_i   => ibServerSlave,
            -- AXI-Lite Interface
            axiClk_i          => clk,
            axiRst_i          => rst);

      -------------------------------
      -- RSSI Client Interface @ 8738
      -------------------------------
      U_RssiClient : entity work.RssiCoreWrapper
         generic map (
            TPD_G                    => TPD_G,
            APP_STREAMS_G            => 2,
            APP_STREAM_ROUTES_G      => (
               0                     => X"00",
               1                     => X"01"),
            CLK_FREQUENCY_G          => 156.25E+6,
            TIMEOUT_UNIT_G           => 1.0E-6,
            SERVER_G                 => false,
            RETRANSMIT_ENABLE_G      => true,
            BYPASS_CHUNKER_G         => BYPASS_CHUNKER_C,
            WINDOW_ADDR_SIZE_G       => CLIENT_WINDOW_ADDR_SIZE_C,
            MAX_NUM_OUTS_SEG_G       => CLIENT_MAX_NUM_OUTS_SEG_C,
            PIPE_STAGES_G            => 1,
            APP_INPUT_AXIS_CONFIG_G  => EMAC_AXIS_CONFIG_C,
            APP_OUTPUT_AXIS_CONFIG_G => EMAC_AXIS_CONFIG_C,
            TSP_INPUT_AXIS_CONFIG_G  => EMAC_AXIS_CONFIG_C,
            TSP_OUTPUT_AXIS_CONFIG_G => EMAC_AXIS_CONFIG_C,
            MAX_RETRANS_CNT_G        => 1,
            MAX_CUM_ACK_CNT_G        => 1)        
         port map (
            clk_i             => clk,
            rst_i             => rst,
            openRq_i          => '1',
            -- Application Layer Interface
            sAppAxisMasters_i => obClientMasters,
            sAppAxisSlaves_o  => obClientSlaves,
            mAppAxisMasters_o => ibClientMasters,
            mAppAxisSlaves_i  => ibClientSlaves,
            -- Transport Layer Interface
            sTspAxisMaster_i  => obClientMaster,
            sTspAxisSlave_o   => obClientSlave,
            mTspAxisMaster_o  => ibClientMaster,
            mTspAxisSlave_i   => ibClientSlave,
            -- AXI-Lite Interface
            axiClk_i          => clk,
            axiRst_i          => rst);         

   end generate;


   BYPASS_RSSI : if (BYPASS_RSSI_C = true) generate
      
      ibServerMaster     <= obServerMasters(0);
      obServerSlaves(0)  <= ibServerSlave;
      ibServerMasters(0) <= obServerMaster;
      obServerSlave      <= ibServerSlaves(0);

      ibClientMaster     <= obClientMasters(0);
      obClientSlaves(0)  <= ibClientSlave;
      ibClientMasters(0) <= obClientMaster;
      obClientSlave      <= ibClientSlaves(0);
      
   end generate;

   ----------------------------------------
   -- 192.168.2.10@4369@TDEST[0] = PRBS TX
   ----------------------------------------   
   U_TX_4369_tdest0 : entity work.SsiPrbsTx
      generic map (
         TPD_G                      => TPD_G,
         CASCADE_SIZE_G             => 1,
         FIFO_ADDR_WIDTH_G          => 9,
         FIFO_PAUSE_THRESH_G        => 2**8,
         PRBS_SEED_SIZE_G           => PRBS_SEED_SIZE_C,
         PRBS_TAPS_G                => (0 => 31, 1 => 6, 2 => 2, 3 => 1),
         MASTER_AXI_STREAM_CONFIG_G => EMAC_AXIS_CONFIG_C,
         MASTER_AXI_PIPE_STAGES_G   => 1)
      port map (
         mAxisClk     => clk,
         mAxisRst     => rst,
         mAxisMaster  => obServerMasters(0),
         mAxisSlave   => obServerSlaves(0),
         locClk       => clk,
         locRst       => rst,
         trig         => '1',
         packetLength => PKT_LEN_C,
         tDest        => X"00",
         tId          => X"00");    

   ----------------------------------------
   -- 192.168.2.10@8738@TDEST[0] = PRBS RX
   ----------------------------------------   
   U_RX_8738_tdest0 : entity work.SsiPrbsRx
      generic map (
         TPD_G                     => TPD_G,
         CASCADE_SIZE_G            => 1,
         FIFO_ADDR_WIDTH_G         => 9,
         FIFO_PAUSE_THRESH_G       => 2**8,
         PRBS_SEED_SIZE_G          => PRBS_SEED_SIZE_C,
         PRBS_TAPS_G               => (0 => 31, 1 => 6, 2 => 2, 3 => 1),
         SLAVE_AXI_STREAM_CONFIG_G => EMAC_AXIS_CONFIG_C,
         SLAVE_AXI_PIPE_STAGES_G   => 0)
      port map (
         errorDet    => errorDet(0),
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => ibClientMasters(0),
         sAxisSlave  => ibClientSlaves(0),
         mAxisClk    => clk,
         mAxisRst    => rst,
         axiClk      => clk,
         axiRst      => rst);    

   start <= obServerMasters(0).tValid and obServerMasters(0).tUser(SSI_SOF_C) and obServerSlaves(0).tReady;
   stop  <= ibClientMasters(0).tValid and ibClientMasters(0).tUser(SSI_SOF_C) and ibClientSlaves(0).tReady;

   process(clk)
   begin
      if rising_edge(clk) then
         if rst = '1' then
            cnt <= toSlv(0, 32) after TPD_G;
            tdc <= toSlv(0, 32) after TPD_G;
         else
            if cnt /= 0 then
               cnt <= cnt + 1 after TPD_G;
            end if;
            if stop = '1' then
               tdc <= cnt          after TPD_G;
               cnt <= toSlv(0, 32) after TPD_G;
            end if;
            if start = '1' then
               cnt <= toSlv(1, 32) after TPD_G;
            end if;
         end if;
      end if;
   end process;

   GEN_VEC :
   for i in 1 downto 0 generate
      trig(i) <= ibClientMasters(i).tValid and ibClientMasters(i).tLast and ibClientSlaves(i).tReady;
      U_TrigRate : entity work.SyncTrigRate
         generic map (
            TPD_G          => TPD_G,
            COMMON_CLK_G   => true,
            ONE_SHOT_G     => false,
            IN_POLARITY_G  => '1',
            REF_CLK_FREQ_G => 156.25E+6,
            REFRESH_RATE_G => 1.0E+0,
            CNT_WIDTH_G    => 32)
         port map (
            -- Trigger Input (locClk domain)
            trigIn      => trig(i),
            -- Trigger Rate Output (locClk domain)
            trigRateOut => frameRate(i),
            -- Clocks
            locClk      => clk,
            refClk      => clk);     
   end generate GEN_VEC;

   U_SyncStatusVector : entity work.SyncStatusVector
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => true,
         CNT_WIDTH_G  => 32,
         WIDTH_G      => 1)
      port map (
         statusIn => errorDet,
         cntRstIn => '0',
         cntOut   => errorDetCnt,
         wrClk    => clk,
         wrRst    => rst,
         rdClk    => clk,
         rdRst    => rst);         

end testbed;
