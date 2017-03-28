-------------------------------------------------------------------------------
-- File       : RssiCoreWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-02-25
-- Last update: 2016-09-09
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

use work.StdRtlPkg.all;
use work.RssiPkg.all;
use work.SsiPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;

entity RssiCoreWrapper is
   generic (
      TPD_G               : time                := 1 ns;
      CLK_FREQUENCY_G     : real                := 100.0E+6;  -- In units of Hz
      TIMEOUT_UNIT_G      : real                := 1.0E-6;    -- In units of seconds
      SERVER_G            : boolean             := true;  -- Module is server or client 
      RETRANSMIT_ENABLE_G : boolean             := true;  -- Enable/Disable retransmissions in tx module
      WINDOW_ADDR_SIZE_G  : positive            := 3;  -- 2^WINDOW_ADDR_SIZE_G  = Max number of segments in buffer
      SEGMENT_ADDR_SIZE_G : positive            := 7;  -- 2^SEGMENT_ADDR_SIZE_G = Number of 64 bit wide data words
      BYPASS_CHUNKER_G    : boolean             := false;     -- Bypass the AXIS chunker layer
      PIPE_STAGES_G       : natural             := 0;
      APP_STREAMS_G       : positive            := 1;
      APP_STREAM_ROUTES_G : Slv8Array           := (0 => "--------");
      AXI_ERROR_RESP_G    : slv(1 downto 0) := AXI_RESP_DECERR_C;
      -- AXIS Configurations
      APP_AXIS_CONFIG_G   : AxiStreamConfigArray;
      TSP_AXIS_CONFIG_G   : AxiStreamConfigType := ssiAxiStreamConfig(16, TKEEP_NORMAL_C);
      -- Version and connection ID
      INIT_SEQ_N_G        : natural             := 16#80#;
      CONN_ID_G           : positive            := 16#12345678#;
      VERSION_G           : positive            := 1;
      HEADER_CHKSUM_EN_G  : boolean             := true;
      -- Window parameters of receiver module
      MAX_NUM_OUTS_SEG_G  : positive            := 8;  --   <=(2**WINDOW_ADDR_SIZE_G)
      MAX_SEG_SIZE_G      : positive            := 1024;  -- <= (2**SEGMENT_ADDR_SIZE_G)*8 Number of bytes
      -- RSSI Timeouts
      ACK_TOUT_G          : positive            := 25;  -- unit depends on TIMEOUT_UNIT_G 
      RETRANS_TOUT_G      : positive            := 50;  -- unit depends on TIMEOUT_UNIT_G  (Recommended >= MAX_NUM_OUTS_SEG_G*Data segment transmission time)
      NULL_TOUT_G         : positive            := 200;  -- unit depends on TIMEOUT_UNIT_G  (Recommended >= 4*RETRANS_TOUT_G)
      -- Counters
      MAX_RETRANS_CNT_G   : positive            := 2;
      MAX_CUM_ACK_CNT_G   : positive            := 3);
   port (
      -- Clock and Reset
      clk_i             : in  sl;
      rst_i             : in  sl;
      -- SSI Application side
      sAppAxisMasters_i : in  AxiStreamMasterArray(APP_STREAMS_G-1 downto 0);
      sAppAxisSlaves_o  : out AxiStreamSlaveArray(APP_STREAMS_G-1 downto 0);
      mAppAxisMasters_o : out AxiStreamMasterArray(APP_STREAMS_G-1 downto 0);
      mAppAxisSlaves_i  : in  AxiStreamSlaveArray(APP_STREAMS_G-1 downto 0);
      -- SSI Transport side
      sTspAxisMaster_i  : in  AxiStreamMasterType;
      sTspAxisSlave_o   : out AxiStreamSlaveType;
      mTspAxisMaster_o  : out AxiStreamMasterType;
      mTspAxisSlave_i   : in  AxiStreamSlaveType;
      -- High level  Application side interface
      openRq_i          : in  sl                     := '0';
      closeRq_i         : in  sl                     := '0';
      inject_i          : in  sl                     := '0';
      -- AXI-Lite Register Interface
      axiClk_i          : in  sl                     := '0';
      axiRst_i          : in  sl                     := '0';
      axilReadMaster    : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave     : out AxiLiteReadSlaveType;
      axilWriteMaster   : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave    : out AxiLiteWriteSlaveType;
      -- Internal statuses
      statusReg_o       : out slv(6 downto 0));
end entity RssiCoreWrapper;

architecture mapping of RssiCoreWrapper is

   signal rxMasters : AxiStreamMasterArray(APP_STREAMS_G-1 downto 0);
   signal rxSlaves  : AxiStreamSlaveArray(APP_STREAMS_G-1 downto 0);

   signal depacketizerMasters : AxiStreamMasterArray(1 downto 0);
   signal depacketizerSlaves  : AxiStreamSlaveArray(1 downto 0);

   signal packetizerMasters : AxiStreamMasterArray(1 downto 0);
   signal packetizerSlaves  : AxiStreamSlaveArray(1 downto 0);

   signal txMasters : AxiStreamMasterArray(APP_STREAMS_G-1 downto 0);
   signal txSlaves  : AxiStreamSlaveArray(APP_STREAMS_G-1 downto 0);

   signal statusReg        : slv(6 downto 0);
   signal rssiNotConnected : sl;

   -- This should really go in a AxiStreamPacketizerPkg
   constant PACKETIZER_AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 8,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   -- If bypassing chunker, convert directly to RSSI AXIS config
   -- else use Packetizer AXIS format. Packetizer will then convert to RSSI config.
   constant CONV_AXIS_CONFIG_C : AxiStreamConfigType := ite(BYPASS_CHUNKER_G, RSSI_AXIS_CONFIG_C, PACKETIZER_AXIS_CONFIG_C);

begin

   GEN_RX :
   for i in (APP_STREAMS_G-1) downto 0 generate
      U_RxFifo : entity work.AxiStreamFifo
         generic map (
            TPD_G               => TPD_G,
            SLAVE_READY_EN_G    => true,
            BRAM_EN_G           => false,
            GEN_SYNC_FIFO_G     => true,
            FIFO_ADDR_WIDTH_G   => 4,
            INT_PIPE_STAGES_G   => 0,
            PIPE_STAGES_G       => 1,
            SLAVE_AXI_CONFIG_G  => APP_AXIS_CONFIG_G(i),
            MASTER_AXI_CONFIG_G => CONV_AXIS_CONFIG_C)
         port map (
            sAxisClk    => clk_i,
            sAxisRst    => rst_i,
            sAxisMaster => sAppAxisMasters_i(i),
            sAxisSlave  => sAppAxisSlaves_o(i),
            mAxisClk    => clk_i,
            mAxisRst    => rst_i,
            mAxisMaster => rxMasters(i),
            mAxisSlave  => rxSlaves(i));
   end generate GEN_RX;

   U_AxiStreamMux : entity work.AxiStreamMux
      generic map (
         TPD_G          => TPD_G,
         NUM_SLAVES_G   => APP_STREAMS_G,
         MODE_G         => "ROUTED",
         TDEST_ROUTES_G => APP_STREAM_ROUTES_G,
         PIPE_STAGES_G  => 1)
      port map (
         -- Clock and reset
         axisClk      => clk_i,
         axisRst      => rst_i,
         -- Slaves
         sAxisMasters => rxMasters,
         sAxisSlaves  => rxSlaves,
         -- Master
         mAxisMaster  => packetizerMasters(0),
         mAxisSlave   => packetizerSlaves(0));

   GEN_PACKER : if (BYPASS_CHUNKER_G = false) generate
      U_Packetizer : entity work.AxiStreamPacketizer
         generic map (
            TPD_G                => TPD_G,
            MAX_PACKET_BYTES_G   => MAX_SEG_SIZE_G,
            INPUT_PIPE_STAGES_G  => 0,
            OUTPUT_PIPE_STAGES_G => 1)
         port map (
            axisClk     => clk_i,
            axisRst     => rst_i,
            sAxisMaster => packetizerMasters(0),
            sAxisSlave  => packetizerSlaves(0),
            mAxisMaster => packetizerMasters(1),
            mAxisSlave  => packetizerSlaves(1));
   end generate;

   BYPASS_PACKER : if (BYPASS_CHUNKER_G = true) generate
      packetizerMasters(1) <= packetizerMasters(0);
      packetizerSlaves(0)  <= packetizerSlaves(1);
   end generate;

   U_RssiCore : entity work.RssiCore
      generic map (
         TPD_G               => TPD_G,
         CLK_FREQUENCY_G     => CLK_FREQUENCY_G,
         TIMEOUT_UNIT_G      => TIMEOUT_UNIT_G,
         SERVER_G            => SERVER_G,
         RETRANSMIT_ENABLE_G => RETRANSMIT_ENABLE_G,
         WINDOW_ADDR_SIZE_G  => WINDOW_ADDR_SIZE_G,
         SEGMENT_ADDR_SIZE_G => SEGMENT_ADDR_SIZE_G,
         AXI_ERROR_RESP_G    => AXI_ERROR_RESP_G,
         -- AXIS Configurations
         APP_AXIS_CONFIG_G   => RSSI_AXIS_CONFIG_C,
         TSP_AXIS_CONFIG_G   => TSP_AXIS_CONFIG_G,
         -- Version and connection ID
         INIT_SEQ_N_G        => INIT_SEQ_N_G,
         CONN_ID_G           => CONN_ID_G,
         VERSION_G           => VERSION_G,
         HEADER_CHKSUM_EN_G  => HEADER_CHKSUM_EN_G,
         -- Window parameters of receiver module
         MAX_NUM_OUTS_SEG_G  => MAX_NUM_OUTS_SEG_G,
         MAX_SEG_SIZE_G      => MAX_SEG_SIZE_G,
         -- RSSI Timeouts
         RETRANS_TOUT_G      => RETRANS_TOUT_G,
         ACK_TOUT_G          => ACK_TOUT_G,
         NULL_TOUT_G         => NULL_TOUT_G,
         -- Counters
         MAX_RETRANS_CNT_G   => MAX_RETRANS_CNT_G,
         MAX_CUM_ACK_CNT_G   => MAX_CUM_ACK_CNT_G)
      port map (
         -- Clock and Reset
         clk_i            => clk_i,
         rst_i            => rst_i,
         -- SSI Application side
         sAppAxisMaster_i => packetizerMasters(1),
         sAppAxisSlave_o  => packetizerSlaves(1),
         mAppAxisMaster_o => depacketizerMasters(1),
         mAppAxisSlave_i  => depacketizerSlaves(1),
         -- SSI Transport side
         sTspAxisMaster_i => sTspAxisMaster_i,
         sTspAxisSlave_o  => sTspAxisSlave_o,
         mTspAxisMaster_o => mTspAxisMaster_o,
         mTspAxisSlave_i  => mTspAxisSlave_i,
         -- High level  Application side interface
         openRq_i         => openRq_i,
         closeRq_i        => closeRq_i,
         inject_i         => inject_i,
         -- AXI-Lite Register Interface
         axiClk_i         => axiClk_i,
         axiRst_i         => axiRst_i,
         axilReadMaster   => axilReadMaster,
         axilReadSlave    => axilReadSlave,
         axilWriteMaster  => axilWriteMaster,
         axilWriteSlave   => axilWriteSlave,
         -- Internal statuses
         statusReg_o      => statusReg);

   statusReg_o      <= statusReg;
   rssiNotConnected <= not statusReg(0);

   GEN_DEPACKER : if (BYPASS_CHUNKER_G = false) generate
      U_Depacketizer : entity work.AxiStreamDepacketizer
         generic map (
            TPD_G                => TPD_G,
            INPUT_PIPE_STAGES_G  => 0,  -- No need for input stage, RSSI output is already pipelined
            OUTPUT_PIPE_STAGES_G => 1)
         port map (
            axisClk     => clk_i,
            axisRst     => rst_i,
            restart     => rssiNotConnected,
            sAxisMaster => depacketizerMasters(1),
            sAxisSlave  => depacketizerSlaves(1),
            mAxisMaster => depacketizerMasters(0),
            mAxisSlave  => depacketizerSlaves(0));
   end generate;

   BYPASS_DEPACKER : if (BYPASS_CHUNKER_G = true) generate
      depacketizerMasters(0) <= depacketizerMasters(1);
      depacketizerSlaves(1)  <= depacketizerSlaves(0);
   end generate;

   U_AxiStreamDeMux : entity work.AxiStreamDeMux
      generic map (
         TPD_G          => TPD_G,
         NUM_MASTERS_G  => APP_STREAMS_G,
         MODE_G         => "ROUTED",
         TDEST_ROUTES_G => APP_STREAM_ROUTES_G)
      port map (
         -- Clock and reset
         axisClk      => clk_i,
         axisRst      => rst_i,
         -- Slaves
         sAxisMaster  => depacketizerMasters(0),
         sAxisSlave   => depacketizerSlaves(0),
         -- Master
         mAxisMasters => txMasters,
         mAxisSlaves  => txSlaves);

   GEN_TX :
   for i in (APP_STREAMS_G-1) downto 0 generate
      U_TxFifo : entity work.AxiStreamFifo
         generic map (
            TPD_G               => TPD_G,
            SLAVE_READY_EN_G    => true,
            BRAM_EN_G           => false,
            GEN_SYNC_FIFO_G     => true,
            FIFO_ADDR_WIDTH_G   => 4,
            INT_PIPE_STAGES_G   => 0,
            PIPE_STAGES_G       => PIPE_STAGES_G,
            SLAVE_AXI_CONFIG_G  => CONV_AXIS_CONFIG_C,
            MASTER_AXI_CONFIG_G => APP_AXIS_CONFIG_G(i))
         port map (
            sAxisClk    => clk_i,
            sAxisRst    => rst_i,
            sAxisMaster => txMasters(i),
            sAxisSlave  => txSlaves(i),
            mAxisClk    => clk_i,
            mAxisRst    => rst_i,
            mAxisMaster => mAppAxisMasters_o(i),
            mAxisSlave  => mAppAxisSlaves_i(i));
   end generate GEN_TX;

end architecture mapping;
