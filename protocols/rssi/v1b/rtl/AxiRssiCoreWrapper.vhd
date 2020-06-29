-------------------------------------------------------------------------------
-- Title      : RSSI Protocol: https://confluence.slac.stanford.edu/x/1IyfD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for RSSI + AXIS packetizer
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
use surf.AxiPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiRssiPkg.all;
use surf.RssiPkg.all;
use surf.SsiPkg.all;

entity AxiRssiCoreWrapper is
   generic (
      TPD_G               : time                 := 1 ns;
      SERVER_G            : boolean              := true;  --! Module is server or client
      JUMBO_G             : boolean              := false;  --! true=8192 byte payload, false=1024 byte payload
      AXI_CONFIG_G        : AxiConfigType;  --! Defines the AXI configuration but ADDR_WIDTH_C should be defined as the space for RSSI and "maybe" not the entire memory address space available
      -- AXIS Configurations
      APP_STREAMS_G       : positive             := 1;
      APP_STREAM_ROUTES_G : Slv8Array            := (0 => "--------");
      APP_AXIS_CONFIG_G   : AxiStreamConfigArray;
      TSP_AXIS_CONFIG_G   : AxiStreamConfigType;
      -- RSSI Timeouts
      CLK_FREQUENCY_G     : real                 := 156.25E+6;  -- In units of Hz
      TIMEOUT_UNIT_G      : real                 := 1.0E-3;  -- In units of seconds
      ACK_TOUT_G          : positive             := 25;  -- unit depends on TIMEOUT_UNIT_G
      RETRANS_TOUT_G      : positive             := 50;  -- unit depends on TIMEOUT_UNIT_G  (Recommended >= MAX_NUM_OUTS_SEG_G*Data segment transmission time)
      NULL_TOUT_G         : positive             := 200;  -- unit depends on TIMEOUT_UNIT_G  (Recommended >= 4*RETRANS_TOUT_G)
      -- Counters
      MAX_RETRANS_CNT_G   : positive             := 8;
      MAX_CUM_ACK_CNT_G   : positive             := 3);
   port (
      -- Clock and Reset
      clk              : in  sl;
      rst              : in  sl;
      -- AXI TX Segment Buffer Interface
      txAxiOffset      : in  slv(63 downto 0);  --! Used to apply an address offset to the master AXI transactions
      txAxiWriteMaster : out AxiWriteMasterType;
      txAxiWriteSlave  : in  AxiWriteSlaveType;
      txAxiReadMaster  : out AxiReadMasterType;
      txAxiReadSlave   : in  AxiReadSlaveType;
      -- AXI RX Segment Buffer Interface
      rxAxiOffset      : in  slv(63 downto 0);  --! Used to apply an address offset to the master AXI transactions
      rxAxiWriteMaster : out AxiWriteMasterType;
      rxAxiWriteSlave  : in  AxiWriteSlaveType;
      rxAxiReadMaster  : out AxiReadMasterType;
      rxAxiReadSlave   : in  AxiReadSlaveType;
      -- SSI Application side
      sAppAxisMasters  : in  AxiStreamMasterArray(APP_STREAMS_G-1 downto 0);
      sAppAxisSlaves   : out AxiStreamSlaveArray(APP_STREAMS_G-1 downto 0);
      mAppAxisMasters  : out AxiStreamMasterArray(APP_STREAMS_G-1 downto 0);
      mAppAxisSlaves   : in  AxiStreamSlaveArray(APP_STREAMS_G-1 downto 0);
      -- SSI Transport side
      sTspAxisMaster   : in  AxiStreamMasterType;
      sTspAxisSlave    : out AxiStreamSlaveType;
      mTspAxisMaster   : out AxiStreamMasterType;
      mTspAxisSlave    : in  AxiStreamSlaveType;
      -- High level  Application side interface
      openRq           : in  sl                     := '0';
      closeRq          : in  sl                     := '0';
      inject           : in  sl                     := '0';
      linkUp           : out sl;
      -- Optional AXI-Lite Register Interface
      sAxilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      sAxilReadSlave   : out AxiLiteReadSlaveType;
      sAxilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      sAxilWriteSlave  : out AxiLiteWriteSlaveType);
end entity AxiRssiCoreWrapper;

architecture mapping of AxiRssiCoreWrapper is

   constant PACKETIZER_AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 8,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant MAX_SEG_SIZE_C  : positive := ite(JUMBO_G, 8192, 1024);
   constant MAX_SEGS_BITS_C : positive := bitSize(MAX_SEG_SIZE_C);

   signal maxSegs      : slv(MAX_SEGS_BITS_C-1 downto 0) := toSlv(MAX_SEG_SIZE_C, MAX_SEGS_BITS_C);
   signal maxObSegSize : slv(15 downto 0)                := toSlv(MAX_SEG_SIZE_C, 16);
   signal ileaveRearb  : slv(11 downto 0);

   signal status           : slv(6 downto 0) := (others => '0');
   signal rssiNotConnected : sl              := '1';
   signal rssiConnected    : sl              := '1';

   signal rxMasters : AxiStreamMasterArray(APP_STREAMS_G-1 downto 0);
   signal rxSlaves  : AxiStreamSlaveArray(APP_STREAMS_G-1 downto 0);

   signal depacketizerMasters : AxiStreamMasterArray(1 downto 0);
   signal depacketizerSlaves  : AxiStreamSlaveArray(1 downto 0);

   signal packetizerMasters : AxiStreamMasterArray(1 downto 0);
   signal packetizerSlaves  : AxiStreamSlaveArray(1 downto 0);

   signal txMasters : AxiStreamMasterArray(APP_STREAMS_G-1 downto 0);
   signal txSlaves  : AxiStreamSlaveArray(APP_STREAMS_G-1 downto 0);

begin

   -- Register to help with timing
   process(clk)
   begin
      if rising_edge(clk) then
         linkUp           <= status(0)          after TPD_G;
         rssiConnected    <= status(0)          after TPD_G;
         rssiNotConnected <= not(rssiConnected) after TPD_G;
         if (maxObSegSize >= MAX_SEG_SIZE_C) then
            maxSegs <= toSlv(MAX_SEG_SIZE_C, MAX_SEGS_BITS_C) after TPD_G;
         else
            maxSegs <= maxObSegSize(maxSegs'range) after TPD_G;
         end if;
         ileaveRearb <= resize(maxSegs(MAX_SEGS_BITS_C-1 downto 3), 12) - 3 after TPD_G;  -- # of tValid minus AxiStreamPacketizer2.PROTO_WORDS_C=3
      end if;
   end process;

   GEN_RX :
   for i in (APP_STREAMS_G-1) downto 0 generate
      U_Rx : entity surf.AxiStreamResize
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            READY_EN_G          => true,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => APP_AXIS_CONFIG_G(i),
            MASTER_AXI_CONFIG_G => PACKETIZER_AXIS_CONFIG_C)
         port map (
            -- Clock and reset
            axisClk     => clk,
            axisRst     => rst,
            -- Slave Port
            sAxisMaster => sAppAxisMasters(i),
            sAxisSlave  => sAppAxisSlaves(i),
            -- Master Port
            mAxisMaster => rxMasters(i),
            mAxisSlave  => rxSlaves(i));
   end generate GEN_RX;

   U_AxiStreamMux : entity surf.AxiStreamMux
      generic map (
         TPD_G                => TPD_G,
         NUM_SLAVES_G         => APP_STREAMS_G,
         MODE_G               => "ROUTED",
         TDEST_ROUTES_G       => APP_STREAM_ROUTES_G,
         ILEAVE_EN_G          => true,
         ILEAVE_ON_NOTVALID_G => true,  -- Because of ILEAVE_REARB_G value != power of 2, forcing rearb on not(tValid)
         ILEAVE_REARB_G       => (MAX_SEG_SIZE_C/PACKETIZER_AXIS_CONFIG_C.TDATA_BYTES_C) - 3,  -- AxiStreamPacketizer2.PROTO_WORDS_C=3
         PIPE_STAGES_G        => 1)
      port map (
         -- Clock and reset
         axisClk      => clk,
         axisRst      => rst,
         -- Slaves
         sAxisMasters => rxMasters,
         sAxisSlaves  => rxSlaves,
         ileaveRearb  => ileaveRearb,
         -- Master
         mAxisMaster  => packetizerMasters(0),
         mAxisSlave   => packetizerSlaves(0));

   U_Packetizer : entity surf.AxiStreamPacketizer2
      generic map (
         TPD_G                => TPD_G,
         MEMORY_TYPE_G        => "block",
         REG_EN_G             => true,
         CRC_MODE_G           => "FULL",
         CRC_POLY_G           => x"04C11DB7",
         TDEST_BITS_G         => 8,
         MAX_PACKET_BYTES_G   => MAX_SEG_SIZE_C,
         INPUT_PIPE_STAGES_G  => 0,
         OUTPUT_PIPE_STAGES_G => 1)
      port map (
         axisClk     => clk,
         axisRst     => rst,
         maxPktBytes => maxSegs,
         sAxisMaster => packetizerMasters(0),
         sAxisSlave  => packetizerSlaves(0),
         mAxisMaster => packetizerMasters(1),
         mAxisSlave  => packetizerSlaves(1));

   U_RssiCore : entity surf.AxiRssiCore
      generic map (
         TPD_G             => TPD_G,
         SERVER_G          => SERVER_G,
         -- AXI Configurations
         MAX_SEG_SIZE_G    => MAX_SEG_SIZE_C,
         AXI_CONFIG_G      => AXI_CONFIG_G,
         -- AXIS Configurations
         APP_AXIS_CONFIG_G => PACKETIZER_AXIS_CONFIG_C,
         TSP_AXIS_CONFIG_G => TSP_AXIS_CONFIG_G,
         -- RSSI Timeouts
         CLK_FREQUENCY_G   => CLK_FREQUENCY_G,
         TIMEOUT_UNIT_G    => TIMEOUT_UNIT_G,
         ACK_TOUT_G        => ACK_TOUT_G,
         RETRANS_TOUT_G    => RETRANS_TOUT_G,
         NULL_TOUT_G       => NULL_TOUT_G,
         -- Counters
         MAX_RETRANS_CNT_G => MAX_RETRANS_CNT_G,
         MAX_CUM_ACK_CNT_G => MAX_CUM_ACK_CNT_G)
      port map (
         -- Clock and Reset
         clk              => clk,
         rst              => rst,
         -- AXI TX Segment Buffer Interface
         txAxiOffset      => txAxiOffset,
         txAxiWriteMaster => txAxiWriteMaster,
         txAxiWriteSlave  => txAxiWriteSlave,
         txAxiReadMaster  => txAxiReadMaster,
         txAxiReadSlave   => txAxiReadSlave,
         -- AXI RX Segment Buffer Interface
         rxAxiOffset      => rxAxiOffset,
         rxAxiWriteMaster => rxAxiWriteMaster,
         rxAxiWriteSlave  => rxAxiWriteSlave,
         rxAxiReadMaster  => rxAxiReadMaster,
         rxAxiReadSlave   => rxAxiReadSlave,
         -- SSI Application side
         sAppAxisMaster   => packetizerMasters(1),
         sAppAxisSlave    => packetizerSlaves(1),
         mAppAxisMaster   => depacketizerMasters(1),
         mAppAxisSlave    => depacketizerSlaves(1),
         -- SSI Transport side
         sTspAxisMaster   => sTspAxisMaster,
         sTspAxisSlave    => sTspAxisSlave,
         mTspAxisMaster   => mTspAxisMaster,
         mTspAxisSlave    => mTspAxisSlave,
         -- High level  Application side interface
         openRq           => openRq,
         closeRq          => closeRq,
         inject           => inject,
         -- AXI-Lite Register Interface
         sAxilReadMaster  => sAxilReadMaster,
         sAxilReadSlave   => sAxilReadSlave,
         sAxilWriteMaster => sAxilWriteMaster,
         sAxilWriteSlave  => sAxilWriteSlave,
         -- Internal statuses
         statusReg        => status,
         maxSegSize       => maxObSegSize);

   U_Depacketizer : entity surf.AxiStreamDepacketizer2
      generic map (
         TPD_G                => TPD_G,
         MEMORY_TYPE_G        => "block",
         REG_EN_G             => true,
         CRC_MODE_G           => "FULL",
         CRC_POLY_G           => x"04C11DB7",
         TDEST_BITS_G         => 8,
         INPUT_PIPE_STAGES_G  => 0,  -- No need for input stage, RSSI output is already pipelined
         OUTPUT_PIPE_STAGES_G => 1)
      port map (
         axisClk     => clk,
         axisRst     => rst,
         linkGood    => rssiConnected,
         sAxisMaster => depacketizerMasters(1),
         sAxisSlave  => depacketizerSlaves(1),
         mAxisMaster => depacketizerMasters(0),
         mAxisSlave  => depacketizerSlaves(0));

   U_AxiStreamDeMux : entity surf.AxiStreamDeMux
      generic map (
         TPD_G          => TPD_G,
         PIPE_STAGES_G  => 1,
         NUM_MASTERS_G  => APP_STREAMS_G,
         MODE_G         => "ROUTED",
         TDEST_ROUTES_G => APP_STREAM_ROUTES_G)
      port map (
         -- Clock and reset
         axisClk      => clk,
         axisRst      => rst,
         -- Slaves
         sAxisMaster  => depacketizerMasters(0),
         sAxisSlave   => depacketizerSlaves(0),
         -- Master
         mAxisMasters => txMasters,
         mAxisSlaves  => txSlaves);

   GEN_TX :
   for i in (APP_STREAMS_G-1) downto 0 generate
      U_Tx : entity surf.AxiStreamResize
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            READY_EN_G          => true,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => PACKETIZER_AXIS_CONFIG_C,
            MASTER_AXI_CONFIG_G => APP_AXIS_CONFIG_G(i))
         port map (
            -- Clock and reset
            axisClk     => clk,
            axisRst     => rst,
            -- Slave Port
            sAxisMaster => txMasters(i),
            sAxisSlave  => txSlaves(i),
            -- Master Port
            mAxisMaster => mAppAxisMasters(i),
            mAxisSlave  => mAppAxisSlaves(i));
   end generate GEN_TX;

end architecture mapping;
