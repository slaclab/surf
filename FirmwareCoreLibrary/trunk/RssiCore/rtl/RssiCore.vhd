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
      
      -- First prototype will accept 16 bit word (2 - bytes)
      -- If you have a bus of different size you should insert AxiStreamFifo
      APP_SSI_WIDTH_G : positive := 2;
      
      WINDOW_ADDR_SIZE_G       : positive := 7;  -- 2^WINDOW_ADDR_SIZE_G  = Max number of segments in buffer
      
      -- Adjustible parameters
      
      -- Transmitter
      MAX_TX_NUM_OUTS_SEG_G  : positive := 32;
      MAX_TX_SEG_SIZE_G      : positive := (2**SEGMENT_ADDR_SIZE_C)*2; -- Number of bytes
      
      -- Receiver
      MAX_RX_NUM_OUTS_SEG_G  : positive := 32;
      MAX_RX_SEG_SIZE_G      : positive := (2**SEGMENT_ADDR_SIZE_C)*2; -- Number of bytes

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
      SYN_HEADER_SIZE_G   : natural := 28;
      ACK_HEADER_SIZE_G   : natural := 6;
      EACK_HEADER_SIZE_G  : natural := 6;      
      RST_HEADER_SIZE_G   : natural := 6;      
      NULL_HEADER_SIZE_G  : natural := 6;
      DATA_HEADER_SIZE_G  : natural := 6     
   );
   port (
      clk_i      : in  sl;
      rst_i      : in  sl;
      
      -- Temporarty inputs (Later this will be done by RX module, connectionFSM, and timers)
      txAck_i         : in sl;                   -- From receiver module when a segment with valid ACK is received
      txAckN_i        : in slv(7 downto 0);      -- Number being ACKed
      rxAckN_i        : in slv(7 downto 0);      -- SeqN received by onboard receiver (This value is sent in the header).
      
      connActive_i    : in sl; 
      sndSyn_i        : in  sl;
      sndAck_i        : in  sl;
      sndRst_i        : in  sl;
      sndResend_i     : in  sl;
      sndNull_i       : in  sl; 
      
      
      -- Temporaty outputs Errors (1 cc pulse)
      lenErr_o         : out sl;
      ackErr_o         : out sl;
      
      
      -- SSI input from the Application side
      appSsiMaster_i : in  SsiMasterType;
      appSsiSlave_o  : out SsiSlaveType;
      
      -- SSI Transport side interface
      tspSsiSlave_i  : in   SsiSlaveType;
      tspSsiMaster_o : out  SsiMasterType
      
   );
end entity RssiCore;

architecture rtl of RssiCore is
   
   -- Header decoder module
   signal s_headerValues : HeaderValuesType;

   signal s_synHeadSt    : sl;
   signal s_rstHeadSt    : sl;
   signal s_dataHeadSt   : sl;
   signal s_nullHeadSt   : sl;
   signal s_ackHeadSt    : sl;
   
   signal s_txSeqN    : slv(7  downto 0);
   
   -- Buffer
   signal s_nextRxSeqN : slv(7  downto 0);
   signal s_bufferWe   : sl;
   signal s_bufferSent : sl;
   signal s_txRdy      : sl;
   signal s_windowSize : integer range 0 to 2 ** (WINDOW_ADDR_SIZE_G-1);
   signal s_windowArray: WindowTypeArray(0 to 2 ** (WINDOW_ADDR_SIZE_G)-1);
   signal s_bufferFull : sl;
   signal s_ssiBusy    : sl;
   signal s_init       : sl;
   
   signal s_firstUnackAddr : slv(WINDOW_ADDR_SIZE_G-1 downto 0);
   signal s_lastSentAddr   : slv(WINDOW_ADDR_SIZE_G-1 downto 0);  
    
   -- TX Data sources
   signal s_headerAddr   : slv(7  downto 0);
   signal s_headerData   : slv(15  downto 0);
   signal s_bufferAddr   : slv( (SEGMENT_ADDR_SIZE_C+WINDOW_ADDR_SIZE_G)-1 downto 0);
   signal s_bufferData   : slv(15  downto 0);
   signal s_chksumData   : slv(15  downto 0);
   
   -- TX FSM
   signal s_sndData    : sl;
   signal s_initSeqN  : slv(7  downto 0);

   -- Checksum 
   signal s_enable : sl;
   
----------------------------------------------------------------------
begin

   -- Assign header values (later will connect to parameter negotiation module)
   s_headerValues.maxOutsSegments <= toSlv(MAX_TX_NUM_OUTS_SEG_G, 8);
   s_headerValues.maxSegSize      <= toSlv(MAX_TX_SEG_SIZE_G, 16);
   s_headerValues.retransTout     <= toSlv(RETRANS_TOUT_G, 16);
   s_headerValues.cumulAckTout    <= toSlv(ACK_TOUT_G, 16);
   s_headerValues.nullSegTout     <= toSlv(NULL_TOUT_G, 16);
   s_headerValues.transStateTout  <= toSlv(TRANS_STATE_TOUT_G, 16);
   s_headerValues.maxRetrans      <= toSlv(MAX_RETRANS_CNT_G, 8);
   s_headerValues.maxCumAck       <= toSlv(MAX_CUM_ACK_CNT_G, 8);
   s_headerValues.maxOutofseq     <= toSlv(MAX_OUT_OF_SEQUENCE_G, 8);
   s_headerValues.maxAutoRst      <= toSlv(MAX_AUTO_RST_CNT_G, 8);
   
   s_headerValues.connectionId    <= x"DEADBEEF";
   
   -- later will connect to parameter negotiation module   
   s_windowSize <= MAX_RX_NUM_OUTS_SEG_G;
   s_initSeqN   <= x"80";
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

      ack_i          => '1', -- Always send acknowledge with data packet
      txSeqN_i       => s_txSeqN,
      rxAckN_i       => rxAckN_i,
      headerValues_i => s_headerValues,
      addr_i         => s_headerAddr,
      headerData_o   => s_headerData);
   
   TxBuffer_INST: entity work.TxBuffer
   generic map (
      TPD_G             => TPD_G,
      AXI_CONFIG_G      => ssiAxiStreamConfig(APP_SSI_WIDTH_G),
      WINDOW_ADDR_SIZE_G=> WINDOW_ADDR_SIZE_G, 
      APP_SSI_WIDTH_G   => (APP_SSI_WIDTH_G * 8)
   )
   port map (
      clk_i            => clk_i,
      rst_i            => rst_i,
      init_i           => s_init,
      appSsiMaster_i   => appSsiMaster_i,
      appSsiSlave_o    => appSsiSlave_o,
      rdAddr_i         => s_bufferAddr,
      rdData_o         => s_bufferData,
      we_i             => s_bufferWe,
      sent_i           => s_bufferSent,
      txRdy_i          => s_txRdy,
      rstHeadSt_i      => s_rstHeadSt,
      dataHeadSt_i     => s_dataHeadSt,
      nullHeadSt_i     => s_nullHeadSt,
      windowSize_i     => s_windowSize,
      nextSeqN_i       => s_nextRxSeqN,
      ack_i            => txAck_i,
      ackN_i           => txAckN_i,
      txData_o         => s_sndData,
      windowArray_o    => s_windowArray,
      bufferFull_o     => s_bufferFull,
      firstUnackAddr_o => s_firstUnackAddr,
      lastSentAddr_o   => s_lastSentAddr,
      ssiBusy_o        => s_ssiBusy,
      lenErr_o         => lenErr_o,
      ackErr_o         => ackErr_o);

   TxFSM_INST: entity work.TxFSM
   generic map (
      TPD_G              => TPD_G,
      AXI_CONFIG_G       => ssiAxiStreamConfig(APP_SSI_WIDTH_G),
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
      initSeqN_i       => s_initSeqN,
      nextSeqN_o       => s_nextRxSeqN,
      windowArray_i    => s_windowArray,
      windowSize_i     => s_windowSize,
      bufferFull_i     => s_bufferFull,
      firstUnackAddr_i => s_firstUnackAddr,
      lastSentAddr_i   => s_lastSentAddr,
      ssiBusy_i        => s_ssiBusy,
      txSeqN_o         => s_txSeqN,
      synHeadSt_o      => s_synHeadSt,
      ackHeadSt_o      => s_ackHeadSt,
      dataHeadSt_o     => s_dataHeadSt,
      dataSt_o         => open, -- may be used in the future otherwise remove
      rstHeadSt_o      => s_rstHeadSt,
      nullHeadSt_o     => s_nullHeadSt,
      headerData_i     => s_headerData,
      chksumData_i     => s_chksumData,
      bufferData_i     => s_bufferData,
      tspSsiSlave_i    => tspSsiSlave_i,
      tspSsiMaster_o   => tspSsiMaster_o);
   
   
   -- 
   s_enable <= s_synHeadSt or s_rstHeadSt or s_dataHeadSt or s_nullHeadSt or s_ackHeadSt;
   
   Chksum_INST: entity work.Chksum
   generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => (APP_SSI_WIDTH_G * 8))
   port map (
      clk_i    => clk_i,
      rst_i    => rst_i,
      enable_i => s_enable,
      strobe_i => '1', -- Todo add strobe according to tspSsiSlave_i.ready signal 
      init_i   => x"0000",
      data_i   => s_headerData,
      chksum_o => s_chksumData,
      valid_o  => open,
      check_o  => open);
----------------------------------------
end architecture rtl;