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
      CLK_FREQUENCY_G         : real                := 100.0E+6;               -- In units of Hz
      TIMEOUT_UNIT_G          : real                := 1.0E-6;  -- In units of seconds
      SERVER_G                : boolean             := true;  -- Module is server or client 
      RETRANSMIT_ENABLE_G     : boolean             := true;  -- Enable/Disable retransmissions in tx module
      WINDOW_ADDR_SIZE_G      : positive            := 3;  -- 2^WINDOW_ADDR_SIZE_G  = Max number of segments in buffer
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
      -- Internal Timeouts
      PEER_CONN_TIMEOUT_G     : positive            := 1000;  -- unit depends on TIMEOUT_UNIT_G  
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

begin

   U_RssiCore : entity work.RssiCore
      generic map (
         TPD_G                   => TPD_G,
         CLK_FREQUENCY_G         => CLK_FREQUENCY_G,
         TIMEOUT_UNIT_G          => TIMEOUT_UNIT_G,
         SERVER_G                => SERVER_G,
         RETRANSMIT_ENABLE_G     => RETRANSMIT_ENABLE_G,
         WINDOW_ADDR_SIZE_G      => WINDOW_ADDR_SIZE_G,
         -- Application AXIS fifos
         APP_INPUT_AXI_CONFIG_G  => APP_INPUT_AXI_CONFIG_G,
         APP_OUTPUT_AXI_CONFIG_G => APP_OUTPUT_AXI_CONFIG_G,
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
         -- Internal Timeouts
         PEER_CONN_TIMEOUT_G     => PEER_CONN_TIMEOUT_G,
         -- Counters
         MAX_RETRANS_CNT_G       => MAX_RETRANS_CNT_G,
         MAX_CUM_ACK_CNT_G       => MAX_CUM_ACK_CNT_G,
         MAX_OUT_OF_SEQUENCE_G   => MAX_OUT_OF_SEQUENCE_G)
      port map (
         -- Clock and Reset
         clk_i            => rst_i,
         rst_i            => rst_i,
         -- SSI Application side
         sAppAxisMaster_i => sAppAxisMaster_i,
         sAppAxisSlave_o  => sAppAxisSlave_o,
         mAppAxisMaster_o => mAppAxisMaster_o,
         mAppAxisSlave_i  => mAppAxisSlave_i,
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

end architecture mapping;
