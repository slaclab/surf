-------------------------------------------------------------------------------
-- Title      : Reliable SSI top module
-------------------------------------------------------------------------------
-- File       : RssiCoreWrapper.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2016-02-25
-- Last update: 2016-02-25
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Wrapper for RSSI + packetizer 
-------------------------------------------------------------------------------
-- Copyright (c) 2016 SLAC National Accelerator Laboratory
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
      TPD_G                   : time                := 1 ns;
      MAX_PACKET_BYTES_G      : positive            := 1440;
      CLK_FREQUENCY_G         : real                := 100.0E+6;               -- In units of Hz
      TIMEOUT_UNIT_G          : real                := 1.0E-6;  -- In units of seconds
      SERVER_G                : boolean             := true;  -- Module is server or client 
      RETRANSMIT_ENABLE_G     : boolean             := true;  -- Enable/Disable retransmissions in tx module
      WINDOW_ADDR_SIZE_G      : positive            := 3;  -- 2^WINDOW_ADDR_SIZE_G  = Max number of segments in buffer
      SEGMENT_ADDR_SIZE_G     : positive            := 7;  -- 2^SEGMENT_ADDR_SIZE_G = Number of 64 bit wide data words
      --
      PIPE_STAGES_G           : natural             := 0;
      -- Application AXIS fifos
      APP_INPUT_AXI_CONFIG_G  : AxiStreamConfigType := ssiAxiStreamConfig(4);  -- Application Input data width 
      APP_OUTPUT_AXI_CONFIG_G : AxiStreamConfigType := ssiAxiStreamConfig(4);  -- Application Output data width 
      -- Transport AXIS fifos
      TSP_INPUT_AXI_CONFIG_G  : AxiStreamConfigType := ssiAxiStreamConfig(16);  -- Transport Input data width
      TSP_OUTPUT_AXI_CONFIG_G : AxiStreamConfigType := ssiAxiStreamConfig(16);  -- Transport Output data width      
      -- Version and connection ID
      INIT_SEQ_N_G            : natural             := 16#80#;
      CONN_ID_G               : positive            := 16#12345678#;
      VERSION_G               : positive            := 1;
      HEADER_CHKSUM_EN_G      : boolean             := true;
      -- Window parameters of receiver module
      MAX_NUM_OUTS_SEG_G      : positive            := 8;  --   <=(2**WINDOW_ADDR_SIZE_G)
      MAX_SEG_SIZE_G          : positive            := (2**SEGMENT_ADDR_SIZE_C)*RSSI_WORD_WIDTH_C;  -- Number of bytes
      -- RSSI Timeouts
      RETRANS_TOUT_G          : positive            := 50;    -- unit depends on TIMEOUT_UNIT_G  
      ACK_TOUT_G              : positive            := 25;    -- unit depends on TIMEOUT_UNIT_G  
      NULL_TOUT_G             : positive            := 200;   -- unit depends on TIMEOUT_UNIT_G  
  
      -- Counters
      MAX_RETRANS_CNT_G       : positive            := 2;
      MAX_CUM_ACK_CNT_G       : positive            := 3;
      MAX_OUT_OF_SEQUENCE_G   : natural             := 3);
   port (
      -- Clock and Reset
      clk_i            : in  sl;
      rst_i            : in  sl;
      -- SSI Application side
      sAppAxisMaster_i : in  AxiStreamMasterType;
      sAppAxisSlave_o  : out AxiStreamSlaveType;
      mAppAxisMaster_o : out AxiStreamMasterType;
      mAppAxisSlave_i  : in  AxiStreamSlaveType;
      -- SSI Transport side
      sTspAxisMaster_i : in  AxiStreamMasterType;
      sTspAxisSlave_o  : out AxiStreamSlaveType;
      mTspAxisMaster_o : out AxiStreamMasterType;
      mTspAxisSlave_i  : in  AxiStreamSlaveType;
      -- High level  Application side interface
      openRq_i         : in  sl                     := '0';
      closeRq_i        : in  sl                     := '0';
      inject_i         : in  sl                     := '0';
      -- AXI-Lite Register Interface
      axiClk_i         : in  sl                     := '0';
      axiRst_i         : in  sl                     := '0';
      axilReadMaster   : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave    : out AxiLiteReadSlaveType;
      axilWriteMaster  : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave   : out AxiLiteWriteSlaveType;
      -- Internal statuses
      statusReg_o      : out slv(5 downto 0));
end entity RssiCoreWrapper;

architecture mapping of RssiCoreWrapper is

   signal depacketizerMasters : AxiStreamMasterArray(1 downto 0);
   signal depacketizerSlaves  : AxiStreamSlaveArray(1 downto 0);
   signal packetizerMasters   : AxiStreamMasterArray(1 downto 0);
   signal packetizerSlaves    : AxiStreamSlaveArray(1 downto 0);

begin

   U_RxFifo : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => true,
         BRAM_EN_G           => false,
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 4,
         PIPE_STAGES_G       => PIPE_STAGES_G,
         SLAVE_AXI_CONFIG_G  => APP_INPUT_AXI_CONFIG_G,
         MASTER_AXI_CONFIG_G => ssiAxiStreamConfig(8))
      port map (
         sAxisClk    => clk_i,
         sAxisRst    => rst_i,
         sAxisMaster => sAppAxisMaster_i,
         sAxisSlave  => sAppAxisSlave_o,
         mAxisClk    => clk_i,
         mAxisRst    => rst_i,
         mAxisMaster => depacketizerMasters(0),
         mAxisSlave  => depacketizerSlaves(0));

   U_Depacketizer : entity work.AxiStreamDepacketizer
      generic map (
         TPD_G                => TPD_G,
         INPUT_PIPE_STAGES_G  => 1,
         OUTPUT_PIPE_STAGES_G => 1)
      port map (
         axisClk     => clk_i,
         axisRst     => rst_i,
         sAxisMaster => depacketizerMasters(0),
         sAxisSlave  => depacketizerSlaves(0),
         mAxisMaster => depacketizerMasters(1),
         mAxisSlave  => depacketizerSlaves(1));

   U_RssiCore : entity work.RssiCore
      generic map (
         TPD_G                   => TPD_G,
         CLK_FREQUENCY_G         => CLK_FREQUENCY_G,
         TIMEOUT_UNIT_G          => TIMEOUT_UNIT_G,
         SERVER_G                => SERVER_G,
         RETRANSMIT_ENABLE_G     => RETRANSMIT_ENABLE_G,
         WINDOW_ADDR_SIZE_G      => WINDOW_ADDR_SIZE_G,
         SEGMENT_ADDR_SIZE_G     => SEGMENT_ADDR_SIZE_G,

         -- Application AXIS fifos
         APP_INPUT_AXI_CONFIG_G  => ssiAxiStreamConfig(8),
         APP_OUTPUT_AXI_CONFIG_G => ssiAxiStreamConfig(8),
         -- Transport AXIS fifos
         TSP_INPUT_AXI_CONFIG_G  => TSP_INPUT_AXI_CONFIG_G,
         TSP_OUTPUT_AXI_CONFIG_G => TSP_OUTPUT_AXI_CONFIG_G,
         -- Version and connection ID
         INIT_SEQ_N_G            => INIT_SEQ_N_G,
         CONN_ID_G               => CONN_ID_G,
         VERSION_G               => VERSION_G,
         HEADER_CHKSUM_EN_G      => HEADER_CHKSUM_EN_G,
         -- Window parameters of receiver module
         MAX_NUM_OUTS_SEG_G      => MAX_NUM_OUTS_SEG_G,
         MAX_SEG_SIZE_G          => MAX_SEG_SIZE_G,
         -- RSSI Timeouts
         RETRANS_TOUT_G          => RETRANS_TOUT_G,
         ACK_TOUT_G              => ACK_TOUT_G,
         NULL_TOUT_G             => NULL_TOUT_G,

         -- Counters
         MAX_RETRANS_CNT_G       => MAX_RETRANS_CNT_G,
         MAX_CUM_ACK_CNT_G       => MAX_CUM_ACK_CNT_G,
         MAX_OUT_OF_SEQUENCE_G   => MAX_OUT_OF_SEQUENCE_G)
      port map (
         -- Clock and Reset
         clk_i            => clk_i,
         rst_i            => rst_i,
         -- SSI Application side
         sAppAxisMaster_i => depacketizerMasters(1),
         sAppAxisSlave_o  => depacketizerSlaves(1),
         mAppAxisMaster_o => packetizerMasters(1),
         mAppAxisSlave_i  => packetizerSlaves(1),
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
         statusReg_o      => statusReg_o);         

   U_Packetizer : entity work.AxiStreamPacketizer
      generic map (
         TPD_G                => TPD_G,
         MAX_PACKET_BYTES_G   => MAX_PACKET_BYTES_G,
         INPUT_PIPE_STAGES_G  => 1,
         OUTPUT_PIPE_STAGES_G => 1)
      port map (
         axisClk     => clk_i,
         axisRst     => rst_i,
         sAxisMaster => packetizerMasters(1),
         sAxisSlave  => packetizerSlaves(1),
         mAxisMaster => packetizerMasters(0),
         mAxisSlave  => packetizerSlaves(0));

   U_TxFifo : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => true,
         BRAM_EN_G           => false,
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 4,
         PIPE_STAGES_G       => PIPE_STAGES_G,         
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(8),
         MASTER_AXI_CONFIG_G => APP_OUTPUT_AXI_CONFIG_G)
      port map (
         sAxisClk    => clk_i,
         sAxisRst    => rst_i,
         sAxisMaster => packetizerMasters(0),
         sAxisSlave  => packetizerSlaves(0),
         mAxisClk    => clk_i,
         mAxisRst    => rst_i,
         mAxisMaster => mAppAxisMaster_o,
         mAxisSlave  => mAppAxisSlave_i);

end architecture mapping;
