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
      TPD_G        : time     := 1 ns;
      SERVER_G     : boolean  := true;
 
      WINDOW_ADDR_SIZE_G       : positive := 7;  -- 2^WINDOW_ADDR_SIZE_G  = Max number of segments in buffer
      
      -- Adjustible parameters
      
      -- Transmitter
      MAX_TX_NUM_OUTS_SEG_G  : positive := 8;
      MAX_TX_SEG_SIZE_G      : positive := (2**SEGMENT_ADDR_SIZE_C)*8; -- Number of bytes
      
      -- Receiver
      MAX_RX_NUM_OUTS_SEG_G  : positive := 8;
      MAX_RX_SEG_SIZE_G      : positive := (2**SEGMENT_ADDR_SIZE_C)*8; -- Number of bytes

      -- Timeouts
      RETRANS_TOUT_G         : positive := 60;  -- ms
      ACK_TOUT_G             : positive := 30;  -- ms
      NULL_TOUT_G            : positive := 200; -- ms
      TRANS_STATE_TOUT_G     : positive := 500; -- ms
      
      -- Counters
      MAX_RETRANS_CNT_G      : positive := 2;
      MAX_CUM_ACK_CNT_G      : positive := 3;
      MAX_OUT_OF_SEQUENCE_G  : natural  := 3;
      MAX_AUTO_RST_CNT_G     : positive := 1;
      
      -- Standard parameters
      SYN_HEADER_SIZE_G  : natural := 24;
      ACK_HEADER_SIZE_G  : natural := 8;
      EACK_HEADER_SIZE_G : natural := 8;
      RST_HEADER_SIZE_G  : natural := 8;
      NULL_HEADER_SIZE_G : natural := 8;
      DATA_HEADER_SIZE_G : natural := 8
   );
   port (
      clk_i      : in  sl;
      rst_i      : in  sl;
      
      connActive_i    : in  sl; 
      sndSyn_i        : in  sl;
      sndAck_i        : in  sl;
      sndRst_i        : in  sl;
      sndResend_i     : in  sl;
      sndNull_i       : in  sl;
      initSeqN_i      : in  slv(7 downto 0);

      -- SSI Application side
      sAppSsiMaster_i : in  SsiMasterType;
      sAppSsiSlave_o  : out SsiSlaveType;
      mAppSsiMaster_o : out SsiMasterType;
      mAppSsiSlave_i  : in  SsiSlaveType;

      -- SSI Teansport side
      sTspSsiMaster_i : in  SsiMasterType;
      sTspSsiSlave_o  : out SsiSlaveType;
      mTspSsiMaster_o : out SsiMasterType;
      mTspSsiSlave_i  : in  SsiSlaveType
   );
end entity RssiCore;

architecture rtl of RssiCore is
   
   -- Header decoder module
   signal s_headerValues : RssiParamType;

   signal s_synHeadSt    : sl;
   signal s_rstHeadSt    : sl;
   signal s_dataHeadSt   : sl;
   signal s_nullHeadSt   : sl;
   signal s_ackHeadSt    : sl;
   
   -- Current transmitted or received SeqN and AckN   
   signal s_txSeqN    : slv(7  downto 0);
   signal s_txAckN    : slv(7  downto 0);   

   signal s_rxSeqN    : slv(7  downto 0);
   signal s_rxAckN    : slv(7  downto 0);
   
   -- Buffer
   signal s_nextSeqN   : slv(7  downto 0);
   signal s_nextAckN   : slv(7  downto 0);
   signal s_bufferWe   : sl;
   signal s_bufferSent : sl;
   signal s_txRdy      : sl;
   signal s_windowSize : integer range 0 to 2 ** (WINDOW_ADDR_SIZE_G-1);
   signal s_windowArray: TxWindowTypeArray(0 to 2 ** (WINDOW_ADDR_SIZE_G)-1);
   signal s_bufferFull : sl;
   signal s_ssiBusy    : sl;
   signal s_init       : sl;
   
   signal s_firstUnackAddr : slv(WINDOW_ADDR_SIZE_G-1 downto 0);
   signal s_lastSentAddr   : slv(WINDOW_ADDR_SIZE_G-1 downto 0);  
   signal s_nextSentAddr   : slv(WINDOW_ADDR_SIZE_G-1 downto 0); 
    
    
   -- TX Data sources
   signal s_headerAddr   : slv(7  downto 0);
   signal s_headerData   : slv(RSSI_WORD_WIDTH_C*8-1  downto 0);
   signal s_headerRdy    : sl;
   signal s_bufferAddr   : slv( (SEGMENT_ADDR_SIZE_C+WINDOW_ADDR_SIZE_G)-1 downto 0);
   signal s_bufferData   : slv(RSSI_WORD_WIDTH_C*8-1  downto 0);
   signal s_chksumData   : slv(15  downto 0);
   
   -- TX FSM
   signal s_sndData    : sl;
   signal s_initSeqN   : slv(7  downto 0);

   -- Tx Checksum 
   signal s_txChkEnable : sl;
   signal s_txChkValid  : sl;
   signal s_txChkStrobe : sl;
   signal s_txChkLength : positive;
   
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
   signal s_rxParam    : RssiParamType;
   
   -- Rx segment buffer
   signal s_rxWrBuffAddr : slv( (SEGMENT_ADDR_SIZE_C+WINDOW_ADDR_SIZE_G)-1 downto 0);
   signal s_rxWrBuffData : slv(RSSI_WORD_WIDTH_C*8-1 downto 0);      
   signal s_rxRdBuffAddr : slv( (SEGMENT_ADDR_SIZE_C+WINDOW_ADDR_SIZE_G)-1 downto 0);
   signal s_rxRdBuffData : slv(RSSI_WORD_WIDTH_C*8-1 downto 0);
                       
   -- Internal signals 
   
   -- Acknowledge pulse when valid segment 
   -- with acknowledge flag received
   signal s_rxAck : sl;
   
   --
   signal s_lenErr : sl;
   signal s_ackErr : sl;
   
----------------------------------------------------------------------
begin

   -- Assign header values (later will connect to parameter negotiation module)
   s_headerValues.maxOutsSeg      <= toSlv(MAX_TX_NUM_OUTS_SEG_G, 8);
   s_headerValues.maxSegSize      <= toSlv(MAX_TX_SEG_SIZE_G, 16);
   s_headerValues.retransTout     <= toSlv(RETRANS_TOUT_G, 16);
   s_headerValues.cumulAckTout    <= toSlv(ACK_TOUT_G, 16);
   s_headerValues.nullSegTout     <= toSlv(NULL_TOUT_G, 16);
   s_headerValues.transStateTout  <= toSlv(TRANS_STATE_TOUT_G, 16);
   s_headerValues.maxRetrans      <= toSlv(MAX_RETRANS_CNT_G, 8);
   s_headerValues.maxCumAck       <= toSlv(MAX_CUM_ACK_CNT_G, 8);
   s_headerValues.maxOutofseq     <= toSlv(MAX_OUT_OF_SEQUENCE_G, 8);
   s_headerValues.maxAutoRst      <= toSlv(MAX_AUTO_RST_CNT_G, 8);
   
   s_headerValues.connectionId    <= x"BEEF"; -- TODO bring from connection negotiation Debug
   
   -- later will connect to parameter negotiation module   
   s_windowSize <= MAX_RX_NUM_OUTS_SEG_G;
   s_init       <= not connActive_i;
   
   -- Header decoder module
   HeaderReg_INST: entity work.HeaderReg
   generic map (
      TPD_G                 => TPD_G,

      SYN_HEADER_SIZE_G     => SYN_HEADER_SIZE_G,
      ACK_HEADER_SIZE_G     => ACK_HEADER_SIZE_G,
      EACK_HEADER_SIZE_G    => EACK_HEADER_SIZE_G,
      RST_HEADER_SIZE_G     => RST_HEADER_SIZE_G,
      NULL_HEADER_SIZE_G    => NULL_HEADER_SIZE_G,
      DATA_HEADER_SIZE_G    => DATA_HEADER_SIZE_G)
   port map (
      clk_i          => clk_i,
      rst_i          => rst_i,
      synHeadSt_i    => s_synHeadSt,
      rstHeadSt_i    => s_rstHeadSt,
      dataHeadSt_i   => s_dataHeadSt,
      nullHeadSt_i   => s_nullHeadSt,
      ackHeadSt_i    => s_ackHeadSt,
      
      ack_i          => s_rxFlags.ack,
      txSeqN_i       => s_txSeqN,
      rxAckN_i       => s_rxSeqN,
      headerValues_i => s_headerValues,
      addr_i         => s_headerAddr,
      headerData_o   => s_headerData,
      ready_o        => s_headerRdy,
      headerLength_o => s_txChkLength);

   TxBuffer_INST: entity work.TxBuffer
   generic map (
      TPD_G             => TPD_G,
      WINDOW_ADDR_SIZE_G=> WINDOW_ADDR_SIZE_G)
   port map (
      clk_i            => clk_i,
      rst_i            => rst_i,
      init_i           => s_init,
      appSsiMaster_i   => sAppSsiMaster_i,
      appSsiSlave_o    => sAppSsiSlave_o,
      rdAddr_i         => s_bufferAddr,
      rdData_o         => s_bufferData,
      we_i             => s_bufferWe,
      sent_i           => s_bufferSent,
      txRdy_i          => s_txRdy,
      rstHeadSt_i      => s_rstHeadSt,
      dataHeadSt_i     => s_dataHeadSt,
      nullHeadSt_i     => s_nullHeadSt,
      windowSize_i     => s_windowSize,
      nextSeqN_i       => s_nextSeqN,
      nextAckN_o       => s_nextAckN,
      ack_i            => s_rxAck,
      ackN_i           => s_rxAckN,
      txData_o         => s_sndData,
      windowArray_o    => s_windowArray,
      bufferFull_o     => s_bufferFull,
      firstUnackAddr_o => s_firstUnackAddr,
      lastSentAddr_o   => s_lastSentAddr,
      nextSentAddr_o   => s_nextSentAddr,
      ssiBusy_o        => s_ssiBusy,
      lenErr_o         => s_lenErr,
      ackErr_o         => s_ackErr);

   TxFSM_INST: entity work.TxFSM
   generic map (
      TPD_G              => TPD_G,
      WINDOW_ADDR_SIZE_G => WINDOW_ADDR_SIZE_G,
      SYN_HEADER_SIZE_G  => SYN_HEADER_SIZE_G,
      ACK_HEADER_SIZE_G  => ACK_HEADER_SIZE_G,
      EACK_HEADER_SIZE_G => EACK_HEADER_SIZE_G,
      RST_HEADER_SIZE_G  => RST_HEADER_SIZE_G,
      NULL_HEADER_SIZE_G => NULL_HEADER_SIZE_G,
      DATA_HEADER_SIZE_G => DATA_HEADER_SIZE_G)
   port map (
      clk_i            => clk_i,
      rst_i            => rst_i,
      connActive_i     => connActive_i,
      txSyn_i          => sndSyn_i,
      txAck_i          => sndAck_i,
      txRst_i          => sndRst_i,
      txData_i         => s_sndData,
      txResend_i       => sndResend_i,
      txNull_i         => sndNull_i,
      rdDataAddr_o     => s_bufferAddr,
      rdHeaderAddr_o   => s_headerAddr,
      we_o             => s_bufferWe,
      sent_o           => s_bufferSent,
      txRdy_o          => s_txRdy,
      initSeqN_i       => initSeqN_i,
      nextSeqN_o       => s_nextSeqN,
      windowArray_i    => s_windowArray,
      windowSize_i     => s_windowSize,
      bufferFull_i     => s_bufferFull,
      firstUnackAddr_i => s_firstUnackAddr,
      lastSentAddr_i   => s_lastSentAddr,
      nextSentAddr_i   => s_nextSentAddr,
      ssiBusy_i        => s_ssiBusy,
      txSeqN_o         => s_txSeqN,
      synHeadSt_o      => s_synHeadSt,
      ackHeadSt_o      => s_ackHeadSt,
      dataHeadSt_o     => s_dataHeadSt,
      dataSt_o         => open, -- may be used in the future otherwise remove
      rstHeadSt_o      => s_rstHeadSt,
      nullHeadSt_o     => s_nullHeadSt,
      headerData_i     => s_headerData,
      headerRdy_i      => s_headerRdy,
      bufferData_i     => s_bufferData,
      chksumData_i     => s_chksumData,
      chksumValid_i    => s_txChkValid,
      chksumEnable_o   => s_txChkEnable,
      chksumStrobe_o   => s_txChkStrobe,
      tspSsiSlave_i    => mTspSsiSlave_i,
      tspSsiMaster_o   => mTspSsiMaster_o,
      headerLength_i   => s_txChkLength);
   
   RxFSM_INST: entity work.RxFSM
   generic map (
      TPD_G              => TPD_G,
      WINDOW_ADDR_SIZE_G => WINDOW_ADDR_SIZE_G)
   port map (
      clk_i          => clk_i,
      rst_i          => rst_i,
      connActive_i   => connActive_i,
      rxWindowSize_i => s_windowSize,
      txWindowSize_i => s_windowSize,
      nextAckN_i     => s_nextAckN,--
      rxSeqN_o       => s_rxSeqN,
      rxAckN_o       => s_rxAckN,
      rxValidSeg_o   => s_rxValidSeg,
      rxDropSeg_o    => s_rxDropSeg,
      rxFlags_o      => s_rxFlags,
      rxParam_o      => s_rxParam,
      chksumValid_i  => s_rxChkValid,
      chksumOk_i     => s_rxChkCheck,
      chksumEnable_o => s_rxChkEnable,
      chksumStrobe_o => s_rxChkStrobe,
      chksumLength_o => s_rxChkLength,
      wrBuffAddr_o   => s_rxWrBuffAddr,
      wrBuffData_o   => s_rxWrBuffData,
      rdBuffAddr_o   => s_rxRdBuffAddr,
      rdBuffData_i   => s_rxRdBuffData,
      tspSsiMaster_i => sTspSsiMaster_i,
      tspSsiSlave_o  => sTspSsiSlave_o,
      appSsiMaster_o => mAppSsiMaster_o,
      appSsiSlave_i  => mAppSsiSlave_i);
   
   -- Acknowledge valid
   s_rxAck <= s_rxValidSeg and s_rxFlags.ack;
   
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
      data_i   => s_headerData,
      chksum_o => s_chksumData,
      valid_o  => s_txChkValid,
      check_o  => open);
   
   
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
      data_i   => sTspSsiMaster_i.data(RSSI_WORD_WIDTH_C*8-1 downto 0),
      chksum_o => open,
      valid_o  => s_rxChkValid,
      check_o  => s_rxChkCheck);
----------------------------------------
end architecture rtl;