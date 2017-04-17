-------------------------------------------------------------------------------
-- File       : RssiCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-09
-- Last update: 2016-05-13
-------------------------------------------------------------------------------
-- Description: The module is based upon RUDP (Cisco implementation) RFC-908, RFC-1151, draft-ietf-sigtran-reliable-udp-00.
--              The specifications in the drafts are modified by internal simplifications and improvements.
--              
--              Interfaces to transport and application side through AxiStream ports
--              The AxiStream IO port widths can be adjusted (AxiStream FIFOs added to IO)
--              Optional AxiLite Register interface. More info on registers is in RssiAxiLiteRegItf.vhd
--              The module can act as Server or Client:
--                 - Server: - Passively listens for connection request from client,
--                           - Monitors connection activity NULL segment timeouts
--                 - Client: - Actively requests connection
--                           - Sends NULL packages if there is no incoming data
--  Status register:
--    statusReg_o(0) : Connection Active          
--    statusReg_o(1) : Maximum retransmissions exceeded r.retransMax and
--    statusReg_o(2) : Null timeout reached (server) r.nullTout;
--    statusReg_o(3) : Error in acknowledgment mechanism   
--    statusReg_o(4) : SSI Frame length too long
--    statusReg_o(5) : Connection to peer timed out
--    statusReg_o(6) : Client rejected the connection (parameters out of range)
--                     Server proposed new parameters (parameters out of range)               
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
use ieee.math_real.all;

use work.StdRtlPkg.all;
use work.RssiPkg.all;
use work.SsiPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;

entity RssiCore is
   generic (
      TPD_G           : time := 1 ns;
      CLK_FREQUENCY_G : real := 100.0E6;
      TIMEOUT_UNIT_G  : real := 1.0E-6;  -- us (Applies to all the timeouts in the core)

      SERVER_G : boolean := true;       -- Module is server or client 

      RETRANSMIT_ENABLE_G : boolean := true;  -- Enable/Disable retransmissions in tx module

      WINDOW_ADDR_SIZE_G  : positive range 1 to 10 := 3;  -- 2^WINDOW_ADDR_SIZE_G  = Max number of segments in buffer
      SEGMENT_ADDR_SIZE_G : positive := 7;  -- 2^SEGMENT_ADDR_SIZE_G = Number of 64 bit wide data words
      
      AXI_ERROR_RESP_G    : slv(1 downto 0) := AXI_RESP_DECERR_C;
      
      -- AXIS Configurations
      APP_AXIS_CONFIG_G        : AxiStreamConfigType := ssiAxiStreamConfig(4, TKEEP_NORMAL_C);    
      TSP_AXIS_CONFIG_G        : AxiStreamConfigType := ssiAxiStreamConfig(16, TKEEP_NORMAL_C);       

      -- Generic RSSI parameters

      -- Version and connection ID
      INIT_SEQ_N_G       : natural  := 16#80#;
      CONN_ID_G          : positive := 16#12345678#;
      VERSION_G          : positive := 1;
      HEADER_CHKSUM_EN_G : boolean  := true;

      -- Window parameters of receiver module
      MAX_NUM_OUTS_SEG_G : positive range 2 to 1024 := 8; -- <=(2**WINDOW_ADDR_SIZE_G)
      MAX_SEG_SIZE_G     : positive := 1024;  -- <= (2**SEGMENT_ADDR_SIZE_G)*8 Number of bytes

      -- RSSI Timeouts
      ACK_TOUT_G     : positive := 25;   -- unit depends on TIMEOUT_UNIT_G   
      RETRANS_TOUT_G : positive := 50;   -- unit depends on TIMEOUT_UNIT_G  (Recommended >= MAX_NUM_OUTS_SEG_G*Data segment transmission time)
      NULL_TOUT_G    : positive := 200;  -- unit depends on TIMEOUT_UNIT_G  (Recommended >= 4*RETRANS_TOUT_G)

      -- Counters
      MAX_RETRANS_CNT_G     : positive := 2;
      MAX_CUM_ACK_CNT_G     : positive := 3
      );
   port (
      clk_i : in sl;
      rst_i : in sl;

      -- High level  Application side interface
      openRq_i  : in sl;
      closeRq_i : in sl;
      inject_i  : in sl := '0';

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

      -- AXI-Lite Register Interface
      axiClk_i        : in  sl                     := '0';
      axiRst_i        : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType;

      -- Internal statuses
      statusReg_o : out slv(6 downto 0));
end entity RssiCore;

architecture rtl of RssiCore is
   --
   constant FIFO_ADDR_WIDTH_C   : positive := ite((SEGMENT_ADDR_SIZE_G < 7), 9, SEGMENT_ADDR_SIZE_G+2);
   constant FIFO_PAUSE_THRESH_C : positive := ((2**FIFO_ADDR_WIDTH_C)-1) - 16;  -- FIFO_FULL - padding (128 bytes)

   -- RSSI Parameters
   signal s_appRssiParam : RssiParamType;
   signal s_rxRssiParam  : RssiParamType;
   signal s_rssiParam    : RssiParamType;

   -- Tx Segment requests 
   signal s_sndResend : sl;
   signal s_sndSyn    : sl;
   signal s_sndAck    : sl;
   signal s_sndAckMon : sl;
   signal s_sndAckCon : sl;

   signal s_sndRst  : sl;
   signal s_sndNull : sl;

   -- Header states
   signal s_synHeadSt  : sl;
   signal s_rstHeadSt  : sl;
   signal s_dataHeadSt : sl;
   signal s_nullHeadSt : sl;
   signal s_ackHeadSt  : sl;

   -- Current transmitted or received SeqN and AckN   
   signal s_txSeqN : slv(7 downto 0);
   signal s_txAckN : slv(7 downto 0);

   signal s_rxSeqN     : slv(7 downto 0);
   signal s_rxLastSeqN : slv(7 downto 0);
   signal s_rxAckN     : slv(7 downto 0);
   signal s_rxLastAckN : slv(7 downto 0);

   -- Tx Header
   signal s_headerAddr : slv(7 downto 0);
   signal s_headerData : slv(RSSI_WORD_WIDTH_C*8-1 downto 0);
   signal s_headerRdy  : sl;

   -- Tx Checksum 
   signal s_txChkEnable : sl;
   signal s_txChkValid  : sl;
   signal s_txChkStrobe : sl;
   signal s_txChkLength : positive;
   signal s_txChksum    : slv(15 downto 0);

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
   signal s_rxBufferSize : integer range 1 to 2 ** (SEGMENT_ADDR_SIZE_G);
   signal s_rxWindowSize : integer range 1 to 2 ** (WINDOW_ADDR_SIZE_G);
   signal s_rxWrBuffAddr : slv((SEGMENT_ADDR_SIZE_G+WINDOW_ADDR_SIZE_G)-1 downto 0);
   signal s_rxWrBuffData : slv(RSSI_WORD_WIDTH_C*8-1 downto 0);
   signal s_rxWrBuffWe   : sl;
   signal s_rxRdBuffRe   : sl;
   signal s_rxRdBuffAddr : slv((SEGMENT_ADDR_SIZE_G+WINDOW_ADDR_SIZE_G)-1 downto 0);
   signal s_rxRdBuffData : slv(RSSI_WORD_WIDTH_C*8-1 downto 0);

   -- Tx segment buffer
   signal s_txBufferSize : integer range 1 to 2 ** (SEGMENT_ADDR_SIZE_G);
   signal s_txWindowSize : integer range 1 to 2 ** (WINDOW_ADDR_SIZE_G);
   signal s_txWrBuffAddr : slv((SEGMENT_ADDR_SIZE_G+WINDOW_ADDR_SIZE_G)-1 downto 0);
   signal s_txWrBuffData : slv(RSSI_WORD_WIDTH_C*8-1 downto 0);
   signal s_txWrBuffWe   : sl;
   signal s_txRdBuffRe   : sl;
   signal s_txRdBuffAddr : slv((SEGMENT_ADDR_SIZE_G+WINDOW_ADDR_SIZE_G)-1 downto 0);
   signal s_txRdBuffData : slv(RSSI_WORD_WIDTH_C*8-1 downto 0);

   -- Acknowledge pulse when valid segment 
   -- with acknowledge flag received
   signal s_rxAck : sl;

   -- Application Fifo reset when connection is closed
   signal s_rstFifo : sl;

   -- AXIS Application side
   signal s_sAppAxisMaster : AxiStreamMasterType;
   signal s_sAppAxisSlave  : AxiStreamSlaveType;
   signal s_mAppAxisMaster : AxiStreamMasterType;
   signal s_mAppAxisSlave  : AxiStreamSlaveType;
   signal s_mAppAxisCtrl   : AxiStreamCtrlType;

   -- SSI Application side
   signal s_sAppSsiMaster : SsiMasterType;
   signal s_sAppSsiSlave  : SsiSlaveType;
   signal s_mAppSsiMaster : SsiMasterType;
   signal s_mAppSsiSlave  : SsiSlaveType;

   -- AXIS Transport side
   signal s_sTspAxisMaster : AxiStreamMasterType;
   signal s_sTspAxisSlave  : AxiStreamSlaveType;
   signal s_mTspAxisMaster : AxiStreamMasterType;
   signal s_mTspAxisSlave  : AxiStreamSlaveType;
   signal s_mTspAxisCtrl   : AxiStreamCtrlType;

   -- SSI Transport side      
   signal s_sTspSsiMaster : SsiMasterType;
   signal s_sTspSsiSlave  : SsiSlaveType;
   signal s_mTspSsiMaster : SsiMasterType;
   signal s_mTspSsiSlave  : SsiSlaveType;

   -- Monitor input signals
   signal s_txBufferEmpty : sl;
   signal s_lenErr        : sl;
   signal s_ackErr        : sl;
   signal s_peerConnTout  : sl;
   signal s_paramReject   : sl;

   -- Connection control and parameters
   signal s_initSeqN   : slv(7 downto 0);
   signal s_connActive : sl;
   signal s_closeRq    : sl;
   signal s_closed     : sl;
   signal s_openRq     : sl;
   signal s_intCloseRq : sl;
   signal s_txAckF     : sl;

   -- Fault injection
   signal s_injectFaultReg : sl;
   signal s_injectFault    : sl;

   -- Axi Lite registers
   signal s_openRqReg       : sl;
   signal s_closeRqReg      : sl;
   signal s_modeReg         : sl;       -- '0': Use internal parameters from generics 
   -- '1': Use parameters from Axil   
   signal s_initSeqNReg     : slv(7 downto 0);
   signal s_appRssiParamReg : RssiParamType;

   signal s_statusReg   : slv(statusReg_o'range);
   signal s_dropCntReg  : slv(31 downto 0);
   signal s_validCntReg : slv(31 downto 0);
   signal s_reconCntReg  : slv(31 downto 0);
   signal s_resendCntReg : slv(31 downto 0);

   signal monMasters : AxiStreamMasterArray(1 downto 0);   
   signal monSlaves  : AxiStreamSlaveArray(1 downto 0);      
   signal frameRate  : Slv32Array(1 downto 0);   
   signal bandwidth  : Slv64Array(1 downto 0);   
   
   -- attribute dont_touch                   : string;
   -- attribute dont_touch of bandwidth      : signal is "TRUE";     
   -- attribute dont_touch of s_mAppAxisCtrl : signal is "TRUE";     
   -- attribute dont_touch of s_mTspAxisCtrl : signal is "TRUE";   

----------------------------------------------------------------------
begin
   -- Assertions to check generics
   assert (1 <= MAX_NUM_OUTS_SEG_G and MAX_NUM_OUTS_SEG_G <=(2**WINDOW_ADDR_SIZE_G)) report "MAX_NUM_OUTS_SEG_G should be less or equal to 2**WINDOW_ADDR_SIZE_G" severity failure;   
   assert (8 <= MAX_SEG_SIZE_G and  MAX_SEG_SIZE_G <=(2**SEGMENT_ADDR_SIZE_G)*8) report "MAX_SEG_SIZE_G should be less or equal to (2**SEGMENT_ADDR_SIZE_G)*8" severity failure;


   -- /////////////////////////////////////////////////////////
   ------------------------------------------------------------
   -- Register interface
   ------------------------------------------------------------
   -- /////////////////////////////////////////////////////////
   AxiLiteRegItf_INST : entity work.RssiAxiLiteRegItf
      generic map (
         TPD_G                 => TPD_G,
         AXI_ERROR_RESP_G      => AXI_ERROR_RESP_G,
         TIMEOUT_UNIT_G        => TIMEOUT_UNIT_G,
         SEGMENT_ADDR_SIZE_G   => SEGMENT_ADDR_SIZE_G,
         INIT_SEQ_N_G          => INIT_SEQ_N_G,
         CONN_ID_G             => CONN_ID_G,
         VERSION_G             => VERSION_G,
         HEADER_CHKSUM_EN_G    => HEADER_CHKSUM_EN_G,
         MAX_NUM_OUTS_SEG_G    => MAX_NUM_OUTS_SEG_G,
         MAX_SEG_SIZE_G        => MAX_SEG_SIZE_G,
         RETRANS_TOUT_G        => RETRANS_TOUT_G,
         ACK_TOUT_G            => ACK_TOUT_G,
         NULL_TOUT_G           => NULL_TOUT_G,
         MAX_RETRANS_CNT_G     => MAX_RETRANS_CNT_G,
         MAX_CUM_ACK_CNT_G     => MAX_CUM_ACK_CNT_G,
         MAX_OUT_OF_SEQUENCE_G => 0)
      port map (
         axiClk_i        => axiClk_i,
         axiRst_i        => axiRst_i,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,

         -- DevClk domain
         devClk_i => clk_i,
         devRst_i => rst_i,

         -- Control
         openRq_o       => s_openRqReg,
         closeRq_o      => s_closeRqReg,
         mode_o         => s_modeReg,
         initSeqN_o     => s_initSeqNReg,
         appRssiParam_o => s_appRssiParamReg,
         injectFault_o  => s_injectFaultReg,

         -- Status (RO)
         frameRate_i => frameRate,
         bandwidth_i => bandwidth, 
         status_i    => s_statusReg,
         dropCnt_i   => s_dropCntReg,
         validCnt_i  => s_validCntReg,
         resendCnt_i => s_resendCntReg,
         reconCnt_i  => s_reconCntReg 
      );

   s_injectFault <= s_injectFaultReg or inject_i;

   -- /////////////////////////////////////////////////////////
   ------------------------------------------------------------
   -- Parameter assignment
   ------------------------------------------------------------
   -- /////////////////////////////////////////////////////////
   combParamAssign : process (closeRq_i, openRq_i, s_appRssiParamReg, s_closeRqReg, s_initSeqNReg,
                              s_intCloseRq, s_modeReg, s_openRqReg) is
   begin
      if (s_modeReg = '0') then
         -- Use external requests
         s_closeRq <= s_closeRqReg or closeRq_i or s_intCloseRq;
         s_openRq  <= s_openRqReg or openRq_i;

         -- Assign application side Rssi parameters from generics
         s_appRssiParam.maxOutsSeg   <= toSlv(MAX_NUM_OUTS_SEG_G, 8);
         s_appRssiParam.maxSegSize   <= toSlv(MAX_SEG_SIZE_G, 16);
         s_appRssiParam.retransTout  <= toSlv(RETRANS_TOUT_G, 16);
         s_appRssiParam.cumulAckTout <= toSlv(ACK_TOUT_G, 16);
         s_appRssiParam.nullSegTout  <= toSlv(NULL_TOUT_G, 16);
         s_appRssiParam.maxRetrans   <= toSlv(MAX_RETRANS_CNT_G, 8);
         s_appRssiParam.maxCumAck    <= toSlv(MAX_CUM_ACK_CNT_G, 8);
         s_appRssiParam.maxOutofseq  <= toSlv(0, 8);
         s_appRssiParam.version      <= toSlv(VERSION_G, 4);
         s_appRssiParam.connectionId <= toSlv(CONN_ID_G, 32);
         s_appRssiParam.chksumEn     <= ite(HEADER_CHKSUM_EN_G, "1", "0");
         s_appRssiParam.timeoutUnit  <= toSlv(integer(0.0 - (ieee.math_real.log(TIMEOUT_UNIT_G)/ieee.math_real.log(10.0))), 8);
         -- 
         s_initSeqN                  <= toSlv(INIT_SEQ_N_G, 8);
      else
         -- Use axil register requests
         s_closeRq <= s_closeRqReg or s_intCloseRq;
         s_openRq  <= s_openRqReg;

         -- Assign application side Rssi parameters from Axilite registers
         s_appRssiParam <= s_appRssiParamReg;
         --
         s_initSeqN     <= s_initSeqNReg;
      end if;
   end process combParamAssign;

   -- /////////////////////////////////////////////////////////
   ------------------------------------------------------------
   -- Input AXIS fifos
   ------------------------------------------------------------
   -- /////////////////////////////////////////////////////////

   -- Application Fifo reset when connection is closed
   s_rstFifo <= rst_i or not s_connActive;

   -- Application side   
   AppFifoIn_INST : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         GEN_SYNC_FIFO_G     => true,
         BRAM_EN_G           => true,
         INT_PIPE_STAGES_G   => 0,
         PIPE_STAGES_G       => 1,
         FIFO_ADDR_WIDTH_G   => 9,
         SLAVE_AXI_CONFIG_G  => APP_AXIS_CONFIG_G,
         MASTER_AXI_CONFIG_G => RSSI_AXIS_CONFIG_C)
      port map (
         sAxisClk    => clk_i,
         sAxisRst    => s_rstFifo,
         sAxisMaster => monMasters(0),
         sAxisSlave  => monSlaves(0),
         sAxisCtrl   => open,
         --
         mAxisClk    => clk_i,
         mAxisRst    => s_rstFifo,
         mAxisMaster => s_sAppAxisMaster,
         mAxisSlave  => s_sAppAxisSlave,
         mTLastTUser => open);
           
   monMasters(0)   <= sAppAxisMaster_i;      
   sAppAxisSlave_o <= monSlaves(0);      
   
   -- Transport side
   TspFifoIn_INST : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         GEN_SYNC_FIFO_G     => true,
         BRAM_EN_G           => true,
         INT_PIPE_STAGES_G   => 0,
         PIPE_STAGES_G       => 1,
         FIFO_ADDR_WIDTH_G   => 9,
         SLAVE_AXI_CONFIG_G  => TSP_AXIS_CONFIG_G,
         MASTER_AXI_CONFIG_G => RSSI_AXIS_CONFIG_C)
      port map (
         sAxisClk    => clk_i,
         sAxisRst    => rst_i,
         sAxisMaster => sTspAxisMaster_i,
         sAxisSlave  => sTspAxisSlave_o,
         sAxisCtrl   => open,
         --
         mAxisClk    => clk_i,
         mAxisRst    => rst_i,
         mAxisMaster => s_sTspAxisMaster,
         mAxisSlave  => s_sTspAxisSlave,
         mTLastTUser => open);

   -- /////////////////////////////////////////////////////////
   ------------------------------------------------------------
   -- Input AXIS conversion to SSI 
   ------------------------------------------------------------
   -- /////////////////////////////////////////////////////////

   -- Application side
   s_sAppSsiMaster <= axis2SsiMaster(RSSI_AXIS_CONFIG_C, s_sAppAxisMaster);
   s_sAppAxisSlave <= ssi2AxisSlave(s_sAppSsiSlave);

   -- Transport side   
   s_sTspSsiMaster <= axis2SsiMaster(RSSI_AXIS_CONFIG_C, s_sTspAxisMaster);
   s_sTspAxisSlave <= ssi2AxisSlave(s_sTspSsiSlave);

   -- /////////////////////////////////////////////////////////
   ------------------------------------------------------------
   -- Connection and monitoring part
   ------------------------------------------------------------ 
   ConnFSM_INST : entity work.ConnFSM
      generic map (
         TPD_G               => TPD_G,
         SERVER_G            => SERVER_G,
         TIMEOUT_UNIT_G      => TIMEOUT_UNIT_G,
         CLK_FREQUENCY_G     => CLK_FREQUENCY_G,
         RETRANS_TOUT_G      => RETRANS_TOUT_G,
         MAX_RETRANS_CNT_G   => MAX_RETRANS_CNT_G,
         WINDOW_ADDR_SIZE_G  => WINDOW_ADDR_SIZE_G,
         SEGMENT_ADDR_SIZE_G => SEGMENT_ADDR_SIZE_G)
      port map (
         clk_i          => clk_i,
         rst_i          => rst_i,
         connRq_i       => s_openRq,
         closeRq_i      => s_closeRq,
         closed_o       => s_closed,
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
         peerTout_o     => s_peerConnTout,
         paramReject_o  => s_paramReject);

   Monitor_INST : entity work.Monitor
      generic map (
         TPD_G               => TPD_G,
         CLK_FREQUENCY_G     => CLK_FREQUENCY_G,
         TIMEOUT_UNIT_G      => TIMEOUT_UNIT_G,
         SERVER_G            => SERVER_G,
         WINDOW_ADDR_SIZE_G  => WINDOW_ADDR_SIZE_G,
         RETRANSMIT_ENABLE_G => RETRANSMIT_ENABLE_G)
      port map (
         clk_i        => clk_i,
         rst_i        => rst_i,
         connActive_i => s_connActive,

         rssiParam_i     => s_rssiParam,
         rxFlags_i       => s_rxFlags,
         rxValid_i       => s_rxValidSeg,
         rxDrop_i        => s_rxDropSeg,
         ackHeadSt_i     => s_ackHeadSt,
         rstHeadSt_i     => s_rstHeadSt,
         dataHeadSt_i    => s_dataHeadSt,
         nullHeadSt_i    => s_nullHeadSt,
         rxLastSeqN_i    => s_rxLastSeqN,
         rxWindowSize_i  => s_rxWindowSize,
         lenErr_i        => s_lenErr,
         ackErr_i        => s_ackErr,
         peerConnTout_i  => s_peerConnTout,
         paramReject_i   => s_paramReject,
         txBufferEmpty_i => s_txBufferEmpty,
         sndResend_o     => s_sndResend,
         sndAck_o        => s_sndAckMon,
         sndNull_o       => s_sndNull,
         closeRq_o       => s_intCloseRq,
         statusReg_o     => s_statusReg,
         dropCnt_o       => s_dropCntReg,
         validCnt_o      => s_validCntReg,
         resendCnt_o     => s_resendCntReg,
         reconCnt_o      => s_reconCntReg         
      );

   -- /////////////////////////////////////////////////////////
   ------------------------------------------------------------
   -- TX part
   ------------------------------------------------------------
   -- /////////////////////////////////////////////////////////       

   -- Header decoder module
   HeaderReg_INST : entity work.HeaderReg
      generic map (
         TPD_G => TPD_G,

         SYN_HEADER_SIZE_G  => SYN_HEADER_SIZE_C,
         ACK_HEADER_SIZE_G  => ACK_HEADER_SIZE_C,
         EACK_HEADER_SIZE_G => EACK_HEADER_SIZE_C,
         RST_HEADER_SIZE_G  => RST_HEADER_SIZE_C,
         NULL_HEADER_SIZE_G => NULL_HEADER_SIZE_C,
         DATA_HEADER_SIZE_G => DATA_HEADER_SIZE_C)
      port map (
         clk_i        => clk_i,
         rst_i        => rst_i,
         synHeadSt_i  => s_synHeadSt,
         rstHeadSt_i  => s_rstHeadSt,
         dataHeadSt_i => s_dataHeadSt,
         nullHeadSt_i => s_nullHeadSt,
         ackHeadSt_i  => s_ackHeadSt,

         ack_i          => s_txAckF,    -- Connected to ConnectFSM
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
   TxFSM_INST : entity work.TxFSM
      generic map (
         TPD_G               => TPD_G,
         WINDOW_ADDR_SIZE_G  => WINDOW_ADDR_SIZE_G,
         SEGMENT_ADDR_SIZE_G => SEGMENT_ADDR_SIZE_G,
         SYN_HEADER_SIZE_G   => SYN_HEADER_SIZE_C,
         ACK_HEADER_SIZE_G   => ACK_HEADER_SIZE_C,
         EACK_HEADER_SIZE_G  => EACK_HEADER_SIZE_C,
         RST_HEADER_SIZE_G   => RST_HEADER_SIZE_C,
         NULL_HEADER_SIZE_G  => NULL_HEADER_SIZE_C,
         DATA_HEADER_SIZE_G  => DATA_HEADER_SIZE_C,
         HEADER_CHKSUM_EN_G  => HEADER_CHKSUM_EN_G)
      port map (
         clk_i         => clk_i,
         rst_i         => rst_i,
         connActive_i  => s_connActive,
         closed_i      => s_closed,
         injectFault_i => s_injectFault,

         sndSyn_i    => s_sndSyn,
         sndAck_i    => s_sndAck,
         sndRst_i    => s_sndRst,
         sndResend_i => s_sndResend,
         sndNull_i   => s_sndNull,

         windowSize_i => s_txWindowSize,
         bufferSize_i => s_txBufferSize,


         wrBuffWe_o   => s_txWrBuffWe,
         wrBuffAddr_o => s_txWrBuffAddr,
         wrBuffData_o => s_txWrBuffData,
         rdBuffAddr_o => s_txRdBuffAddr,
         rdBuffData_i => s_txRdBuffData,

         rdHeaderAddr_o => s_headerAddr,
         rdHeaderData_i => s_headerData,
         headerRdy_i    => s_headerRdy,
         headerLength_i => s_txChkLength,

         chksumValid_i  => s_txChkValid,
         chksumEnable_o => s_txChkEnable,
         chksumStrobe_o => s_txChkStrobe,
         chksum_i       => s_txChksum,

         initSeqN_i => s_initSeqN,

         txSeqN_o     => s_txSeqN,
         synHeadSt_o  => s_synHeadSt,
         ackHeadSt_o  => s_ackHeadSt,
         dataHeadSt_o => s_dataHeadSt,
         dataSt_o     => open,          -- may be used in the future otherwise remove
         rstHeadSt_o  => s_rstHeadSt,
         nullHeadSt_o => s_nullHeadSt,

         lastAckN_o => s_rxLastAckN,
         ack_i      => s_rxAck,
         ackN_i     => s_rxAckN,

         appSsiMaster_i => s_sAppSsiMaster,
         appSsiSlave_o  => s_sAppSsiSlave,

         tspSsiSlave_i  => s_mTspSsiSlave,
         tspSsiMaster_o => s_mTspSsiMaster,

         bufferEmpty_o => s_txBufferEmpty,
         lenErr_o      => s_lenErr,
         ackErr_o      => s_ackErr);

   -----------------------------------------------   
   -- Tx buffer RAM 
   TxBuffer_INST : entity work.SimpleDualPortRam
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => RSSI_WORD_WIDTH_C*8,
         ADDR_WIDTH_G => (SEGMENT_ADDR_SIZE_G+WINDOW_ADDR_SIZE_G)
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

   tx_Chksum_INST : entity work.Chksum
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
         data_i   => endianSwap64(s_mTspSsiMaster.data(RSSI_WORD_WIDTH_C*8-1 downto 0)),
         chksum_o => s_txChksum,
         valid_o  => s_txChkValid,
         check_o  => open);

   -- /////////////////////////////////////////////////////////
   ------------------------------------------------------------
   -- RX part
   ------------------------------------------------------------   
   -- /////////////////////////////////////////////////////////  
   RxFSM_INST : entity work.RxFSM
      generic map (
         TPD_G               => TPD_G,
         WINDOW_ADDR_SIZE_G  => WINDOW_ADDR_SIZE_G,
         HEADER_CHKSUM_EN_G  => HEADER_CHKSUM_EN_G,
         SEGMENT_ADDR_SIZE_G => SEGMENT_ADDR_SIZE_G)
      port map (
         clk_i          => clk_i,
         rst_i          => rst_i,
         connActive_i   => s_connActive,
         rxWindowSize_i => s_rxWindowSize,
         rxBufferSize_i => s_rxBufferSize,
         txWindowSize_i => s_txWindowSize,
         lastAckN_i     => s_rxLastAckN,  --
         rxSeqN_o       => s_rxSeqN,
         rxLastSeqN_o   => s_rxLastSeqN,
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
   RxBuffer_INST : entity work.SimpleDualPortRam
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => RSSI_WORD_WIDTH_C*8,
         ADDR_WIDTH_G => (SEGMENT_ADDR_SIZE_G+WINDOW_ADDR_SIZE_G)
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

   rx_Chksum_INST : entity work.Chksum
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

   -- /////////////////////////////////////////////////////////
   ------------------------------------------------------------
   -- Output SSI conversion to AXIS
   ------------------------------------------------------------
   -- /////////////////////////////////////////////////////////

   -- SSI Application side   
   s_mAppAxisMaster <= ssi2AxisMaster(RSSI_AXIS_CONFIG_C, s_mAppSsiMaster);
   s_mAppSsiSlave   <= axis2SsiSlave(RSSI_AXIS_CONFIG_C, s_mAppAxisSlave, s_mAppAxisCtrl);
   -- SSI Transport side
   s_mTspAxisMaster <= ssi2AxisMaster(RSSI_AXIS_CONFIG_C, s_mTspSsiMaster);
   s_mTspSsiSlave   <= axis2SsiSlave(RSSI_AXIS_CONFIG_C, s_mTspAxisSlave, s_mTspAxisCtrl);

   -- /////////////////////////////////////////////////////////
   ------------------------------------------------------------
   -- Output AXIS fifos
   ------------------------------------------------------------
   -- /////////////////////////////////////////////////////////

   -- Application side   
   AppFifoOut_INST : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => false,
         VALID_THOLD_G       => 1,
         GEN_SYNC_FIFO_G     => true,
         BRAM_EN_G           => true,
         INT_PIPE_STAGES_G   => 0,
         PIPE_STAGES_G       => 1,
         CASCADE_SIZE_G      => 1,
         CASCADE_PAUSE_SEL_G => 0,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_C,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_C,
         SLAVE_AXI_CONFIG_G  => RSSI_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => APP_AXIS_CONFIG_G)
      port map (
         sAxisClk    => clk_i,
         sAxisRst    => s_rstFifo,
         sAxisMaster => s_mAppAxisMaster,
         sAxisSlave  => s_mAppAxisSlave,
         sAxisCtrl   => s_mAppAxisCtrl,
         --
         mAxisClk    => clk_i,
         mAxisRst    => s_rstFifo,
         mAxisMaster => monMasters(1),
         mAxisSlave  => monSlaves(1),
         mTLastTUser => open);
         
   mAppAxisMaster_o <= monMasters(1);
   monSlaves(1)     <= mAppAxisSlave_i;

   -- Transport side
   TspFifoOut_INST : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => false,
         VALID_THOLD_G       => 1,
         GEN_SYNC_FIFO_G     => true,
         BRAM_EN_G           => true,
         INT_PIPE_STAGES_G   => 0,
         PIPE_STAGES_G       => 1,
         CASCADE_SIZE_G      => 1,
         CASCADE_PAUSE_SEL_G => 0,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_C,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_C,
         SLAVE_AXI_CONFIG_G  => RSSI_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => TSP_AXIS_CONFIG_G)
      port map (
         sAxisClk    => clk_i,
         sAxisRst    => rst_i,
         sAxisMaster => s_mTspAxisMaster,
         sAxisSlave  => s_mTspAxisSlave,
         sAxisCtrl   => s_mTspAxisCtrl,
         --
         mAxisClk    => clk_i,
         mAxisRst    => rst_i,
         mAxisMaster => mTspAxisMaster_o,
         mAxisSlave  => mTspAxisSlave_i,
         mTLastTUser => open);
----------------------------------------
-- Output assignment
   statusReg_o <= s_statusReg;
   
   PACKET_RATE :
   for i in 1 downto 0 generate
      U_AxiStreamMon : entity work.AxiStreamMon
         generic map (
            TPD_G            => TPD_G,   
            AXIS_CLK_FREQ_G => CLK_FREQUENCY_G,
            AXIS_CONFIG_G   => APP_AXIS_CONFIG_G)
         port map (
            -- AXIS Stream Interface
            axisClk    => clk_i,
            axisRst    => rst_i,
            axisMaster => monMasters(i),
            axisSlave  => monSlaves(i),
            -- Status Interface
            statusClk  => axiClk_i,
            statusRst  => axiRst_i,
            frameRate  => frameRate(i),
            bandwidth  => bandwidth(i));  
   end generate PACKET_RATE;         
   
end architecture rtl;
