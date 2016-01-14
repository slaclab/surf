-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : RssiCore.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-08-09
-- Last update: 2015-08-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
--                     
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.RssiPkg.all;
use work.SsiPkg.all;
use work.AxiStreamPkg.all;

entity RssiCore is
   generic (
      TPD_G            : time     := 1 ns;
      CLK_FREQUENCY_G  : real     := 100.0E6;
      TIMEOUT_UNIT_G   : real     := 1.0E-6; -- us (Applies to all the timeouts in the core)
   
      SERVER_G         : boolean  := true; -- Module is server or client 
      INTERNAL_PARAM_G : boolean  := true; -- Internal true (Rssi parameters from generics) 
                                           -- External true (Rssi parameters from input)
      RETRANSMIT_ENABLE_G : boolean := true; -- Enable/Disable retransmissions in tx module
      
      WINDOW_ADDR_SIZE_G : positive := 7;  -- 2^WINDOW_ADDR_SIZE_G  = Max number of segments in buffer
      
      -- Generic RSSI parameters
      
      -- Version and connection ID
      CONN_ID_G   : positive := 1385;
      VERSION_G   : positive := 1;
      HEADER_CHKSUM_EN_G : boolean  := true;
      
      -- Window parameters of receiver module
      MAX_NUM_OUTS_SEG_G  : positive := 8;
      MAX_SEG_SIZE_G      : positive := (2**SEGMENT_ADDR_SIZE_C)*8; -- Number of bytes

      -- RSSI Timeouts
      RETRANS_TOUT_G        : positive := 50;  -- unit depends on TIMEOUT_UNIT_G  
      ACK_TOUT_G            : positive := 25;  -- unit depends on TIMEOUT_UNIT_G  
      NULL_TOUT_G           : positive := 200; -- unit depends on TIMEOUT_UNIT_G  

      -- Internal Timeouts
      PEER_CONN_TIMEOUT_G   : positive := 1000; -- unit depends on TIMEOUT_UNIT_G  
      
      -- Counters
      MAX_RETRANS_CNT_G     : positive := 2;
      MAX_CUM_ACK_CNT_G     : positive := 3;
      MAX_OUT_OF_SEQUENCE_G : natural  := 3   
   );
   port (
      clk_i      : in  sl;
      rst_i      : in  sl;
     
      -- High level  Application side interface and RSSI parameters
      connRq_i   : in  sl;
      closeRq_i  : in  sl;
      initSeqN_i : in  slv(7 downto 0);
      appRssiParam_i : in RssiParamType:= (others => (others =>'0')); -- Can be disconnected if INTERNAL_PARAM_G=true
      
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
      
      -- Internal statuses
      statusReg_o : out slv(4 downto 0);
      dropCnt_o   : out slv(31 downto 0);
      validCnt_o  : out slv(31 downto 0) 
   );
end entity RssiCore;

architecture rtl of RssiCore is
   
   -- RSSI Parameters
   signal s_appRssiParam  : RssiParamType;
   signal s_rxRssiParam   : RssiParamType;
   signal s_rssiParam     : RssiParamType;
   
   -- Tx Segment requests 
   signal s_sndResend : sl;
   signal s_sndSyn    : sl;
   signal s_sndAck    : sl;
   signal s_sndAckMon : sl;
   signal s_sndAckCon : sl;
   
   signal s_sndRst    : sl;
   signal s_sndNull   : sl;

   -- Header states
   signal s_synHeadSt    : sl;
   signal s_rstHeadSt    : sl;
   signal s_dataHeadSt   : sl;
   signal s_nullHeadSt   : sl;
   signal s_ackHeadSt    : sl;
  
   -- Current transmitted or received SeqN and AckN   
   signal s_txSeqN    : slv(7  downto 0);
   signal s_txAckN    : slv(7  downto 0);   

   signal s_rxSeqN    : slv(7  downto 0);
   signal s_rxLastSeqN: slv(7  downto 0);   
   signal s_rxAckN    : slv(7  downto 0);
   signal s_rxLastAckN: slv(7  downto 0);

   -- Tx Header
   signal s_headerAddr   : slv(7  downto 0);
   signal s_headerData   : slv(RSSI_WORD_WIDTH_C*8-1  downto 0);
   signal s_headerRdy    : sl;

   -- Tx Checksum 
   signal s_txChkEnable : sl;
   signal s_txChkValid  : sl;
   signal s_txChkStrobe : sl;
   signal s_txChkLength : positive;
   signal s_txChksum   : slv(15  downto 0);
   
   -- Rx Checksum 
   signal s_rxChkEnable : sl;
   signal s_rxChkValid  : sl;
   signal s_rxChkCheck  : sl;
   signal s_rxChkStrobe : sl;
   signal s_rxChkLength : positive;
   
   -- Rx Statuses
   signal s_rxValidSeg : sl;
   signal s_rxDropSeg  : sl;
   signal s_rxFlags    : flagsType;
   
   -- Rx segment buffer
   signal s_rxBufferSize : integer range 1 to 2 ** (SEGMENT_ADDR_SIZE_C);
   signal s_rxWindowSize : integer range 1 to 2 ** (WINDOW_ADDR_SIZE_G);
   signal s_rxWrBuffAddr : slv( (SEGMENT_ADDR_SIZE_C+WINDOW_ADDR_SIZE_G)-1 downto 0);
   signal s_rxWrBuffData : slv(RSSI_WORD_WIDTH_C*8-1 downto 0);
   signal s_rxWrBuffWe   : sl;
   signal s_rxRdBuffRe   : sl;
   signal s_rxRdBuffAddr : slv( (SEGMENT_ADDR_SIZE_C+WINDOW_ADDR_SIZE_G)-1 downto 0);
   signal s_rxRdBuffData : slv(RSSI_WORD_WIDTH_C*8-1 downto 0);
   
   -- Tx segment buffer
   signal s_txBufferSize : integer range 1 to 2 ** (SEGMENT_ADDR_SIZE_C);
   signal s_txWindowSize : integer range 1 to 2 ** (WINDOW_ADDR_SIZE_G);
   signal s_txWrBuffAddr : slv( (SEGMENT_ADDR_SIZE_C+WINDOW_ADDR_SIZE_G)-1 downto 0);
   signal s_txWrBuffData : slv(RSSI_WORD_WIDTH_C*8-1 downto 0);
   signal s_txWrBuffWe   : sl;
   signal s_txRdBuffRe   : sl;
   signal s_txRdBuffAddr : slv( (SEGMENT_ADDR_SIZE_C+WINDOW_ADDR_SIZE_G)-1 downto 0);
   signal s_txRdBuffData : slv(RSSI_WORD_WIDTH_C*8-1 downto 0);

   -- Internal signals 
   
   -- Acknowledge pulse when valid segment 
   -- with acknowledge flag received
   signal s_rxAck : sl;
   
   -- SSI Application side
   signal s_sAppSsiMaster : SsiMasterType;
   signal s_sAppSsiSlave  : SsiSlaveType;
   signal s_mAppSsiMaster : SsiMasterType;
   signal s_mAppSsiSlave  : SsiSlaveType;
  
   -- SSI Teansport side      
   signal s_sTspSsiMaster : SsiMasterType;
   signal s_sTspSsiSlave  : SsiSlaveType;
   signal s_mTspSsiMaster : SsiMasterType;
   signal s_mTspSsiSlave  : SsiSlaveType;

   -- Monitor input signals
   signal s_txBufferEmpty : sl;
   signal s_lenErr : sl;
   signal s_ackErr : sl;
   signal s_peerConnTout : sl;
   
   -- Connection indicator
   signal s_connActive : sl;
   signal s_closeRq : sl;
   signal s_intCloseRq : sl;
   signal s_txAckF : sl;
----------------------------------------------------------------------
begin
   -- /////////////////////////////////////////////////////////
   ------------------------------------------------------------
   -- SSI to AXIS conversion
   ------------------------------------------------------------
   -- /////////////////////////////////////////////////////////   



   -- /////////////////////////////////////////////////////////
   ------------------------------------------------------------
   -- SSI to AXIS conversion
   ------------------------------------------------------------
   -- /////////////////////////////////////////////////////////
   
   -- SSI Application side
   s_sAppSsiMaster  <= axis2SsiMaster(RSSI_AXI_CONFIG_C, sAppAxisMaster_i); 
   sAppAxisSlave_o  <= ssi2AxisSlave(s_sAppSsiSlave); 
   mAppAxisMaster_o <= ssi2AxisMaster(RSSI_AXI_CONFIG_C, s_mAppSsiMaster); 
   s_mAppSsiSlave   <= axis2SsiSlave(RSSI_AXI_CONFIG_C, mAppAxisSlave_i, AXI_STREAM_CTRL_UNUSED_C);

   -- SSI Transport side
   s_sTspSsiMaster  <= axis2SsiMaster(RSSI_AXI_CONFIG_C, sTspAxisMaster_i); 
   sTspAxisSlave_o  <= ssi2AxisSlave(s_sTspSsiSlave); 
   mTspAxisMaster_o <= ssi2AxisMaster(RSSI_AXI_CONFIG_C, s_mTspSsiMaster); 
   s_mTspSsiSlave   <= axis2SsiSlave(RSSI_AXI_CONFIG_C, mTspAxisSlave_i, AXI_STREAM_CTRL_UNUSED_C);

   -- /////////////////////////////////////////////////////////
   ------------------------------------------------------------
   -- Parameter assignment
   ------------------------------------------------------------
   -- /////////////////////////////////////////////////////////
   GEN_INTERNAL : if INTERNAL_PARAM_G = true generate
      -- assign application side Rssi parameters from generics
      s_appRssiParam.maxOutsSeg      <= toSlv(MAX_NUM_OUTS_SEG_G, 8);
      s_appRssiParam.maxSegSize      <= toSlv(MAX_SEG_SIZE_G, 16);
      s_appRssiParam.retransTout     <= toSlv(RETRANS_TOUT_G, 16);
      s_appRssiParam.cumulAckTout    <= toSlv(ACK_TOUT_G, 16);
      s_appRssiParam.nullSegTout     <= toSlv(NULL_TOUT_G, 16);
      s_appRssiParam.maxRetrans      <= toSlv(MAX_RETRANS_CNT_G, 8);
      s_appRssiParam.maxCumAck       <= toSlv(MAX_CUM_ACK_CNT_G, 8);
      s_appRssiParam.maxOutofseq     <= toSlv(MAX_OUT_OF_SEQUENCE_G, 8);
      s_appRssiParam.version         <= toSlv(VERSION_G, 4);
      s_appRssiParam.connectionId    <= toSlv(CONN_ID_G, 32);
      s_appRssiParam.chksumEn        <= ite(HEADER_CHKSUM_EN_G, "1", "0");
   end generate GEN_INTERNAL;
   
   GEN_EXTERNAL : if INTERNAL_PARAM_G = false generate
      -- assign application side Rssi parameters from generics
      s_appRssiParam  <= appRssiParam_i;
   end generate GEN_EXTERNAL;
   
   -- /////////////////////////////////////////////////////////
   ------------------------------------------------------------
   -- Connection and monitoring part
   ------------------------------------------------------------
   -- /////////////////////////////////////////////////////////
   -- Connection close request 
   -- Either requested by high level App or Internal error
   s_closeRq <= s_intCloseRq or closeRq_i;
   
   ConnFSM_INST: entity work.ConnFSM
   generic map (
      TPD_G              => TPD_G,
      SERVER_G           => SERVER_G,
      TIMEOUT_UNIT_G     => TIMEOUT_UNIT_G,
      CLK_FREQUENCY_G    => CLK_FREQUENCY_G,
      PEER_TIMEOUT_G     => PEER_CONN_TIMEOUT_G,
      
      WINDOW_ADDR_SIZE_G => WINDOW_ADDR_SIZE_G)
   port map (
      clk_i          => clk_i,
      rst_i          => rst_i,
      connRq_i       => connRq_i,
      closeRq_i      => s_closeRq,
      rxRssiParam_i  => s_rxRssiParam,
      appRssiParam_i => s_appRssiParam,
      rssiParam_o    => s_rssiParam,
      rxFlags_i      => s_rxFlags,
      rxValid_i      => s_rxValidSeg,
      synHeadSt_i    => s_synHeadSt,
      ackHeadSt_i    => s_ackHeadSt,
      rstHeadSt_i    => s_rstHeadSt,
      connActive_o   => s_connActive,
      sndSyn_o       => s_sndSyn,
      sndAck_o       => s_sndAckCon,
      sndRst_o       => s_sndRst,
      txAckF_o       => s_txAckF,
      rxBufferSize_o => s_rxBufferSize,
      rxWindowSize_o => s_rxWindowSize,
      txBufferSize_o => s_txBufferSize,
      txWindowSize_o => s_txWindowSize,
      peerTout_o     => s_peerConnTout);

   Monitor_INST: entity work.Monitor
   generic map (
      TPD_G => TPD_G,
      CLK_FREQUENCY_G => CLK_FREQUENCY_G,
      TIMEOUT_UNIT_G => TIMEOUT_UNIT_G,
      SERVER_G => SERVER_G,
      WINDOW_ADDR_SIZE_G => WINDOW_ADDR_SIZE_G,
      RETRANSMIT_ENABLE_G => RETRANSMIT_ENABLE_G)
   port map (
      clk_i          => clk_i,
      rst_i          => rst_i,
      connRq_i       => connRq_i,     
      connActive_i   => s_connActive,
      
      rssiParam_i    => s_rssiParam,
      rxFlags_i      => s_rxFlags,
      rxValid_i      => s_rxValidSeg,
      rxDrop_i       => s_rxDropSeg,
      ackHeadSt_i    => s_ackHeadSt,
      rstHeadSt_i    => s_rstHeadSt,
      dataHeadSt_i   => s_dataHeadSt,
      nullHeadSt_i   => s_nullHeadSt,
      rxLastSeqN_i   => s_rxLastSeqN, 
      rxWindowSize_i => s_rxWindowSize,
      lenErr_i       => s_lenErr,
      ackErr_i       => s_ackErr,
      peerConnTout_i => s_peerConnTout,
      txBufferEmpty_i=> s_txBufferEmpty,
      sndResend_o    => s_sndResend,
      sndAck_o       => s_sndAckMon,
      sndNull_o      => s_sndNull,
      closeRq_o      => s_intCloseRq,
      statusReg_o    => statusReg_o,
      dropCnt_o      => dropCnt_o,
      validCnt_o     => validCnt_o);
   
   -- /////////////////////////////////////////////////////////
   ------------------------------------------------------------
   -- TX part
   ------------------------------------------------------------
   -- /////////////////////////////////////////////////////////       
   
   -- Header decoder module
   HeaderReg_INST: entity work.HeaderReg
   generic map (
      TPD_G                 => TPD_G,

      SYN_HEADER_SIZE_G     => SYN_HEADER_SIZE_C,
      ACK_HEADER_SIZE_G     => ACK_HEADER_SIZE_C,
      EACK_HEADER_SIZE_G    => EACK_HEADER_SIZE_C,
      RST_HEADER_SIZE_G     => RST_HEADER_SIZE_C,
      NULL_HEADER_SIZE_G    => NULL_HEADER_SIZE_C,
      DATA_HEADER_SIZE_G    => DATA_HEADER_SIZE_C)
   port map (
      clk_i          => clk_i,
      rst_i          => rst_i,
      synHeadSt_i    => s_synHeadSt,
      rstHeadSt_i    => s_rstHeadSt,
      dataHeadSt_i   => s_dataHeadSt,
      nullHeadSt_i   => s_nullHeadSt,
      ackHeadSt_i    => s_ackHeadSt,
      
      ack_i          => s_txAckF, -- Connected to ConnectFSM
      txSeqN_i       => s_txSeqN,
      rxAckN_i       => s_rxLastSeqN,
      headerValues_i => s_rssiParam,
      addr_i         => s_headerAddr,
      headerData_o   => s_headerData,
      ready_o        => s_headerRdy,
      headerLength_o => s_txChkLength);
   
   -- TX FSM
   -----------------------------------------
   -- Group all ack requests
   s_sndAck <= s_sndAckCon or s_sndAckMon;
   
   --
   TxFSM_INST: entity work.TxFSM
   generic map (
      TPD_G              => TPD_G,
      WINDOW_ADDR_SIZE_G => WINDOW_ADDR_SIZE_G,
      SYN_HEADER_SIZE_G  => SYN_HEADER_SIZE_C,
      ACK_HEADER_SIZE_G  => ACK_HEADER_SIZE_C,
      EACK_HEADER_SIZE_G => EACK_HEADER_SIZE_C,
      RST_HEADER_SIZE_G  => RST_HEADER_SIZE_C,
      NULL_HEADER_SIZE_G => NULL_HEADER_SIZE_C,
      DATA_HEADER_SIZE_G => DATA_HEADER_SIZE_C,
      HEADER_CHKSUM_EN_G => HEADER_CHKSUM_EN_G)
   port map (
      clk_i          => clk_i,
      rst_i          => rst_i,
      connActive_i   => s_connActive,
      connRq_i       => connRq_i,
      
      sndSyn_i       => s_sndSyn,
      sndAck_i       => s_sndAck,
      sndRst_i       => s_sndRst,
      sndResend_i    => s_sndResend,
      sndNull_i      => s_sndNull,

      windowSize_i   => s_txWindowSize,
      bufferSize_i   => s_txBufferSize,
      
      
      wrBuffWe_o     => s_txWrBuffWe,
      wrBuffAddr_o   => s_txWrBuffAddr,
      wrBuffData_o   => s_txWrBuffData,
      rdBuffAddr_o   => s_txRdBuffAddr,
      rdBuffData_i   => s_txRdBuffData,

      rdHeaderAddr_o => s_headerAddr,
      rdHeaderData_i => s_headerData,
      headerRdy_i    => s_headerRdy,
      headerLength_i => s_txChkLength,
                 
      chksumValid_i  => s_txChkValid,
      chksumEnable_o => s_txChkEnable,
      chksumStrobe_o => s_txChkStrobe,
      chksum_i       => s_txChksum,
      
      initSeqN_i     => initSeqN_i,

      txSeqN_o       => s_txSeqN,
      synHeadSt_o    => s_synHeadSt,
      ackHeadSt_o    => s_ackHeadSt,
      dataHeadSt_o   => s_dataHeadSt,
      dataSt_o       => open, -- may be used in the future otherwise remove
      rstHeadSt_o    => s_rstHeadSt,
      nullHeadSt_o   => s_nullHeadSt,

      lastAckN_o     => s_rxLastAckN,
      ack_i          => s_rxAck,
      ackN_i         => s_rxAckN,

      appSsiMaster_i => s_sAppSsiMaster,
      appSsiSlave_o  => s_sAppSsiSlave,
      
      tspSsiSlave_i  => s_mTspSsiSlave,
      tspSsiMaster_o => s_mTspSsiMaster,
      
      bufferEmpty_o=> s_txBufferEmpty,
      lenErr_o       => s_lenErr,
      ackErr_o       => s_ackErr);
   
   -----------------------------------------------   
   -- Tx buffer RAM 
   TxBuffer_INST: entity work.SimpleDualPortRam
   generic map (
      TPD_G          => TPD_G,
      DATA_WIDTH_G   => RSSI_WORD_WIDTH_C*8,
      ADDR_WIDTH_G   => (SEGMENT_ADDR_SIZE_C+WINDOW_ADDR_SIZE_G)
   )
   port map (
      -- Port A - Write only
      clka  => clk_i,
      wea   => s_txWrBuffWe,
      addra => s_txWrBuffAddr,
      dina  => s_txWrBuffData,
      
      -- Port B - Read only
      clkb  => clk_i,
      rstb  => rst_i,
      addrb => s_txRdBuffAddr,
      doutb => s_txRdBuffData);
      
   tx_Chksum_INST: entity work.Chksum
   generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => 64,
      CSUM_WIDTH_G => 16
   ) 
   port map (
      clk_i    => clk_i,
      rst_i    => rst_i,
      enable_i => s_txChkEnable,
      strobe_i => s_txChkStrobe,
      init_i   => x"0000",
      length_i => s_txChkLength,
      data_i   => s_mTspSsiMaster.data(RSSI_WORD_WIDTH_C*8-1 downto 0),
      chksum_o => s_txChksum,
      valid_o  => s_txChkValid,
      check_o  => open);   

   -- /////////////////////////////////////////////////////////
   ------------------------------------------------------------
   -- RX part
   ------------------------------------------------------------   
   -- /////////////////////////////////////////////////////////  
   RxFSM_INST: entity work.RxFSM
   generic map (
      TPD_G              => TPD_G,
      WINDOW_ADDR_SIZE_G => WINDOW_ADDR_SIZE_G,
      HEADER_CHKSUM_EN_G => HEADER_CHKSUM_EN_G
   )      
   port map (
      clk_i          => clk_i,
      rst_i          => rst_i,
      connActive_i   => s_connActive,
      rxWindowSize_i => s_rxWindowSize,
      rxBufferSize_i => s_rxBufferSize,
      txWindowSize_i => s_txWindowSize,
      lastAckN_i     => s_rxLastAckN,--
      initAckN_i     => initSeqN_i,
      rxSeqN_o       => s_rxSeqN,
      inOrderSeqN_o  => s_rxLastSeqN,
      rxAckN_o       => s_rxAckN,
      rxValidSeg_o   => s_rxValidSeg,
      rxDropSeg_o    => s_rxDropSeg,
      rxFlags_o      => s_rxFlags,
      rxParam_o      => s_rxRssiParam,
      chksumValid_i  => s_rxChkValid,
      chksumOk_i     => s_rxChkCheck,
      chksumEnable_o => s_rxChkEnable,
      chksumStrobe_o => s_rxChkStrobe,
      chksumLength_o => s_rxChkLength,
      wrBuffWe_o     => s_rxWrBuffWe,
      wrBuffAddr_o   => s_rxWrBuffAddr,
      wrBuffData_o   => s_rxWrBuffData,
      rdBuffAddr_o   => s_rxRdBuffAddr,
      rdBuffData_i   => s_rxRdBuffData,
      tspSsiMaster_i => s_sTspSsiMaster,
      tspSsiSlave_o  => s_sTspSsiSlave,
      appSsiMaster_o => s_mAppSsiMaster,
      appSsiSlave_i  => s_mAppSsiSlave);
      
   -- Rx buffer RAM 
   RxBuffer_INST: entity work.SimpleDualPortRam
   generic map (
      TPD_G          => TPD_G,
      DATA_WIDTH_G   => RSSI_WORD_WIDTH_C*8,
      ADDR_WIDTH_G   => (SEGMENT_ADDR_SIZE_C+WINDOW_ADDR_SIZE_G)
   )
   port map (
      -- Port A - Write only
      clka  => clk_i,
      wea   => s_rxWrBuffWe,
      addra => s_rxWrBuffAddr,
      dina  => s_rxWrBuffData,
      
      -- Port B - Read only
      clkb  => clk_i,
      rstb  => rst_i,
      addrb => s_rxRdBuffAddr,
      doutb => s_rxRdBuffData);

   -- Acknowledge valid packet
   s_rxAck <= s_rxValidSeg and s_rxFlags.ack and s_connActive;

   rx_Chksum_INST: entity work.Chksum
   generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => 64,
      CSUM_WIDTH_G => 16
   ) 
   port map (
      clk_i    => clk_i,
      rst_i    => rst_i,
      enable_i => s_rxChkEnable,
      strobe_i => s_rxChkStrobe,
      init_i   => x"0000",
      length_i => s_rxChkLength,
      data_i   => s_rxWrBuffData,
      chksum_o => open,
      valid_o  => s_rxChkValid,
      check_o  => s_rxChkCheck);
----------------------------------------
end architecture rtl;