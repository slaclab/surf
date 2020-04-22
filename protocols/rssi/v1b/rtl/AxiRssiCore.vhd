-------------------------------------------------------------------------------
-- Title      : RSSI Protocol: https://confluence.slac.stanford.edu/x/1IyfD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiRssiPkg.all;
use surf.RssiPkg.all;
use surf.SsiPkg.all;

entity AxiRssiCore is
   generic (
      TPD_G               : time                := 1 ns;
      SERVER_G            : boolean             := true;  --! Module is server or client
      -- AXI Configurations
      MAX_SEG_SIZE_G      : positive            := 1024;  --! max. payload size (units of bytes)
      AXI_CONFIG_G        : AxiConfigType;  --! Defines the AXI configuration but ADDR_WIDTH_C should be defined as the space for RSSI and maybe not the entire memory address space
      -- AXIS Configurations
      APP_AXIS_CONFIG_G   : AxiStreamConfigType;
      TSP_AXIS_CONFIG_G   : AxiStreamConfigType;
      -- RSSI Timeouts
      CLK_FREQUENCY_G     : real                := 156.25E+6;  --! In units of Hz
      TIMEOUT_UNIT_G      : real                := 1.0E-3;  --! In units of seconds
      ACK_TOUT_G          : positive            := 25;  --! unit depends on TIMEOUT_UNIT_G
      RETRANS_TOUT_G      : positive            := 50;  --! unit depends on TIMEOUT_UNIT_G  (Recommended >= MAX_NUM_OUTS_SEG_C*Data segment transmission time)
      NULL_TOUT_G         : positive            := 200;  --! unit depends on TIMEOUT_UNIT_G  (Recommended >= 4*RETRANS_TOUT_G)
      RETRANSMIT_ENABLE_G : boolean             := true;  --! Enable/Disable retransmissions in tx module
      -- Version and connection ID
      INIT_SEQ_N_G        : natural             := 16#80#;
      CONN_ID_G           : positive            := 16#12345678#;
      VERSION_G           : positive            := 1;
      HEADER_CHKSUM_EN_G  : boolean             := true;
      -- Counters
      MAX_RETRANS_CNT_G   : positive            := 8;
      MAX_CUM_ACK_CNT_G   : positive            := 3);
   port (
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
      -- High level  Application side interface
      openRq           : in  sl                     := '0';
      closeRq          : in  sl                     := '0';
      inject           : in  sl                     := '0';
      -- SSI Application side
      sAppAxisMaster   : in  AxiStreamMasterType;
      sAppAxisSlave    : out AxiStreamSlaveType;
      mAppAxisMaster   : out AxiStreamMasterType;
      mAppAxisSlave    : in  AxiStreamSlaveType;
      -- SSI Transport side
      sTspAxisMaster   : in  AxiStreamMasterType;
      sTspAxisSlave    : out AxiStreamSlaveType;
      mTspAxisMaster   : out AxiStreamMasterType;
      mTspAxisSlave    : in  AxiStreamSlaveType;
      -- AXI-Lite Register Interface
      sAxilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      sAxilReadSlave   : out AxiLiteReadSlaveType;
      sAxilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      sAxilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Internal statuses
      statusReg        : out slv(6 downto 0);
      maxSegSize       : out slv(15 downto 0));
end entity AxiRssiCore;

architecture rtl of AxiRssiCore is

   constant MAX_SEGS_BITS_C     : positive := bitSize(MAX_SEG_SIZE_G-1);
   constant SEGMENT_ADDR_SIZE_C : positive := (MAX_SEGS_BITS_C-3);  --! 2^SEGMENT_ADDR_SIZE_C = Number of 64 bit wide data words
   constant WINDOW_ADDR_SIZE_C  : positive := (AXI_CONFIG_G.ADDR_WIDTH_C-MAX_SEGS_BITS_C);  --! 2^WINDOW_ADDR_SIZE_C  = Max number of segments in buffer
   constant MAX_NUM_OUTS_SEG_C  : positive := (2**WINDOW_ADDR_SIZE_C);  --! MAX_NUM_OUTS_SEG_C=(2**WINDOW_ADDR_SIZE_C)
   constant AXI_BURST_BYTES_C   : positive := ite((MAX_SEG_SIZE_G > 4096), 4096, 2**MAX_SEGS_BITS_C);  -- Enforce power of 2 and up to 4kB AXI burst

   -- RSSI Parameters
   signal s_appRssiParam : RssiParamType;
   signal s_rxRssiParam  : RssiParamType;
   signal s_rssiParam    : RssiParamType;

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

   -- Header states
   signal s_synHeadSt  : sl;
   signal s_rstHeadSt  : sl;
   signal s_dataHeadSt : sl;
   signal s_nullHeadSt : sl;
   signal s_ackHeadSt  : sl;

   -- Tx Segment requests
   signal s_sndResend : sl;
   signal s_sndSyn    : sl;
   signal s_sndAck    : sl;
   signal s_sndAckMon : sl;
   signal s_sndAckCon : sl;
   signal s_sndRst    : sl;
   signal s_sndNull   : sl;

   -- Current transmitted or received SeqN and AckN
   signal s_txSeqN     : slv(7 downto 0);
   signal s_txAckN     : slv(7 downto 0);
   signal s_rxSeqN     : slv(7 downto 0);
   signal s_rxLastSeqN : slv(7 downto 0);
   signal s_rxAckN     : slv(7 downto 0);
   signal s_rxLastAckN : slv(7 downto 0);

   -- Tx Header Interface
   signal s_headerAddr   : slv(7 downto 0);
   signal s_headerData   : slv(RSSI_WORD_WIDTH_C*8-1 downto 0);
   signal s_headerRdy    : sl;
   signal s_headerLength : positive;

   -- Rx Statuses
   signal s_rxValidSeg : sl;
   signal s_rxDropSeg  : sl;
   signal s_rxFlags    : flagsType;
   signal s_rxAck      : sl;  -- Acknowledge pulse when valid segment with acknowledge flag received
   signal s_rxBuffBusy : sl;

   -- Rx segment buffer
   signal s_rxBufferSize : integer range 1 to 2 ** (SEGMENT_ADDR_SIZE_C);
   signal s_rxWindowSize : integer range 1 to 2 ** (WINDOW_ADDR_SIZE_C);

   -- Tx segment buffer
   signal s_txBufferSize : integer range 1 to 2 ** (SEGMENT_ADDR_SIZE_C);
   signal s_txWindowSize : integer range 1 to 2 ** (WINDOW_ADDR_SIZE_C);

   -- AXIS Application Interface
   signal s_sAppAxisMaster : AxiStreamMasterType;
   signal s_sAppAxisSlave  : AxiStreamSlaveType;
   signal s_mAppAxisMaster : AxiStreamMasterType;
   signal s_mAppAxisSlave  : AxiStreamSlaveType;

   -- AXIS Transport Interface
   signal s_sTspAxisMaster : AxiStreamMasterType;
   signal s_sTspAxisSlave  : AxiStreamSlaveType;
   signal s_mTspAxisMaster : AxiStreamMasterType;
   signal s_mTspAxisSlave  : AxiStreamSlaveType;

   -- AXI-Lite Control/Config Interface
   signal s_openRqReg       : sl;
   signal s_closeRqReg      : sl;
   signal s_modeReg         : sl;  -- '0': Use internal parameters from generics, '1': Use parameters from Axil
   signal s_initSeqNReg     : slv(7 downto 0);
   signal s_appRssiParamReg : RssiParamType;

   -- AXI-Lite Status/Monitoring Interface
   signal s_statusReg    : slv(statusReg'range);
   signal s_dropCntReg   : slv(31 downto 0);
   signal s_validCntReg  : slv(31 downto 0);
   signal s_reconCntReg  : slv(31 downto 0);
   signal s_resendCntReg : slv(31 downto 0);
   signal s_monMasters   : AxiStreamMasterArray(1 downto 0);
   signal s_monSlaves    : AxiStreamSlaveArray(1 downto 0);
   signal s_frameRate    : Slv32Array(1 downto 0);
   signal s_bandwidth    : Slv64Array(1 downto 0);

begin

   assert (MAX_NUM_OUTS_SEG_C <= 256)
      report "AxiRssiCore: MAX_NUM_OUTS_SEG_C must be <= 256" severity failure;

   statusReg  <= s_statusReg;
   maxSegSize <= s_rxRssiParam.maxSegSize;

   ---------------------
   -- Register interface
   ---------------------
   U_Reg : entity surf.RssiAxiLiteRegItf
      generic map (
         TPD_G                 => TPD_G,
         COMMON_CLK_G          => true,
         TIMEOUT_UNIT_G        => TIMEOUT_UNIT_G,
         SEGMENT_ADDR_SIZE_G   => SEGMENT_ADDR_SIZE_C,
         INIT_SEQ_N_G          => INIT_SEQ_N_G,
         CONN_ID_G             => CONN_ID_G,
         VERSION_G             => VERSION_G,
         HEADER_CHKSUM_EN_G    => HEADER_CHKSUM_EN_G,
         MAX_NUM_OUTS_SEG_G    => MAX_NUM_OUTS_SEG_C,
         MAX_SEG_SIZE_G        => MAX_SEG_SIZE_G,
         RETRANS_TOUT_G        => RETRANS_TOUT_G,
         ACK_TOUT_G            => ACK_TOUT_G,
         NULL_TOUT_G           => NULL_TOUT_G,
         MAX_RETRANS_CNT_G     => MAX_RETRANS_CNT_G,
         MAX_CUM_ACK_CNT_G     => MAX_CUM_ACK_CNT_G,
         MAX_OUT_OF_SEQUENCE_G => 0)
      port map (
         axiClk_i        => clk,
         axiRst_i        => rst,
         axilReadMaster  => sAxilReadMaster,
         axilReadSlave   => sAxilReadSlave,
         axilWriteMaster => sAxilWriteMaster,
         axilWriteSlave  => sAxilWriteSlave,
         -- DevClk domain
         devClk_i        => clk,
         devRst_i        => rst,
         -- Control
         openRq_o        => s_openRqReg,
         closeRq_o       => s_closeRqReg,
         mode_o          => s_modeReg,
         initSeqN_o      => s_initSeqNReg,
         appRssiParam_o  => s_appRssiParamReg,
         negRssiParam_i  => s_rssiParam,
         injectFault_o   => s_injectFaultReg,
         -- Status (RO)
         frameRate_i     => s_frameRate,
         bandwidth_i     => s_bandwidth,
         status_i        => s_statusReg,
         dropCnt_i       => s_dropCntReg,
         validCnt_i      => s_validCntReg,
         resendCnt_i     => s_resendCntReg,
         reconCnt_i      => s_reconCntReg);

   s_injectFault <= s_injectFaultReg or inject;

   PACKET_RATE :
   for i in 1 downto 0 generate
      U_AxiStreamMon : entity surf.AxiStreamMon
         generic map (
            TPD_G           => TPD_G,
            COMMON_CLK_G    => true,
            AXIS_CLK_FREQ_G => CLK_FREQUENCY_G,
            AXIS_CONFIG_G   => APP_AXIS_CONFIG_G)
         port map (
            -- AXIS Stream Interface
            axisClk    => clk,
            axisRst    => rst,
            axisMaster => s_monMasters(i),
            axisSlave  => s_monSlaves(i),
            -- Status Interface
            statusClk  => clk,
            statusRst  => rst,
            frameRate  => s_frameRate(i),
            bandwidth  => s_bandwidth(i));
   end generate PACKET_RATE;

   ----------------------------------------------------------------------------
   --             Connection, Auto Negotiation and Monitoring                --
   ----------------------------------------------------------------------------

   -----------------------
   -- Parameter assignment
   -----------------------
   process (closeRq, openRq, s_appRssiParamReg, s_closeRqReg, s_initSeqNReg,
            s_intCloseRq, s_modeReg, s_openRqReg) is
   begin
      if (s_modeReg = '0') then

         -- Use external requests
         s_closeRq <= s_closeRqReg or closeRq or s_intCloseRq;
         s_openRq  <= s_openRqReg or openRq;

         -- Assign application side RSSI parameters from generics
         s_appRssiParam.maxOutsSeg   <= toSlv(MAX_NUM_OUTS_SEG_C, 8);
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
         s_initSeqN                  <= toSlv(INIT_SEQ_N_G, 8);

      else

         -- Use AXI-Lite register requests
         s_closeRq <= s_closeRqReg or s_intCloseRq;
         s_openRq  <= s_openRqReg;

         -- Assign application side RSSI parameters from AXI-Lite registers
         s_appRssiParam <= s_appRssiParamReg;
         s_initSeqN     <= s_initSeqNReg;

      end if;
   end process;

   ----------------------------------
   -- Connection Finite State Machine
   ----------------------------------
   U_ConnFSM : entity surf.RssiConnFsm
      generic map (
         TPD_G               => TPD_G,
         SERVER_G            => SERVER_G,
         TIMEOUT_UNIT_G      => TIMEOUT_UNIT_G,
         CLK_FREQUENCY_G     => CLK_FREQUENCY_G,
         RETRANS_TOUT_G      => RETRANS_TOUT_G,
         MAX_RETRANS_CNT_G   => MAX_RETRANS_CNT_G,
         WINDOW_ADDR_SIZE_G  => WINDOW_ADDR_SIZE_C,
         SEGMENT_ADDR_SIZE_G => SEGMENT_ADDR_SIZE_C)
      port map (
         clk_i          => clk,
         rst_i          => rst,
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

   -------------------------------
   -- Connection Monitoring Module
   -------------------------------
   U_Monitor : entity surf.RssiMonitor
      generic map (
         TPD_G               => TPD_G,
         CLK_FREQUENCY_G     => CLK_FREQUENCY_G,
         TIMEOUT_UNIT_G      => TIMEOUT_UNIT_G,
         SERVER_G            => SERVER_G,
         WINDOW_ADDR_SIZE_G  => WINDOW_ADDR_SIZE_C,
         RETRANSMIT_ENABLE_G => RETRANSMIT_ENABLE_G)
      port map (
         clk_i           => clk,
         rst_i           => rst,
         connActive_i    => s_connActive,
         rxBuffBusy_i    => s_rxBuffBusy,
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
         reconCnt_o      => s_reconCntReg);

   ------------------------------------
   -- Outbound Header Generation Module
   ------------------------------------
   U_HeaderReg : entity surf.RssiHeaderReg
      generic map (
         TPD_G              => TPD_G,
         SYN_HEADER_SIZE_G  => SYN_HEADER_SIZE_C,
         ACK_HEADER_SIZE_G  => ACK_HEADER_SIZE_C,
         EACK_HEADER_SIZE_G => EACK_HEADER_SIZE_C,
         RST_HEADER_SIZE_G  => RST_HEADER_SIZE_C,
         NULL_HEADER_SIZE_G => NULL_HEADER_SIZE_C,
         DATA_HEADER_SIZE_G => DATA_HEADER_SIZE_C)
      port map (
         clk_i          => clk,
         rst_i          => rst,
         synHeadSt_i    => s_synHeadSt,
         rstHeadSt_i    => s_rstHeadSt,
         dataHeadSt_i   => s_dataHeadSt,
         nullHeadSt_i   => s_nullHeadSt,
         ackHeadSt_i    => s_ackHeadSt,
         busyHeadSt_i   => s_rxBuffBusy,
         ack_i          => s_txAckF,    -- Connected to ConnectFSM
         txSeqN_i       => s_txSeqN,
         rxAckN_i       => s_rxLastSeqN,
         headerValues_i => s_rssiParam,
         addr_i         => s_headerAddr,
         headerData_o   => s_headerData,
         ready_o        => s_headerRdy,
         headerLength_o => s_headerLength);

   s_sndAck <= s_sndAckCon or s_sndAckMon;

   ----------------------------------------------------------------------------
   --                From Application layer to Transport Layer               --
   ----------------------------------------------------------------------------

   --------------------
   -- Application Layer
   --------------------
   U_AppIn : entity surf.AxiStreamResize
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         READY_EN_G          => true,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => APP_AXIS_CONFIG_G,
         MASTER_AXI_CONFIG_G => RSSI_AXIS_CONFIG_C)
      port map (
         -- Clock and reset
         axisClk     => clk,
         axisRst     => rst,
         -- Slave Port
         sAxisMaster => s_monMasters(0),
         sAxisSlave  => s_monSlaves(0),
         -- Master Port
         mAxisMaster => s_mAppAxisMaster,
         mAxisSlave  => s_mAppAxisSlave);

   s_monMasters(0) <= sAppAxisMaster;
   sAppAxisSlave   <= s_monSlaves(0);

   -----------------------------------
   -- Transmitter Finite State Machine
   -----------------------------------
   U_TxFSM : entity surf.AxiRssiTxFsm
      generic map (
         TPD_G               => TPD_G,
         AXI_CONFIG_G        => AXI_CONFIG_G,
         BURST_BYTES_G       => AXI_BURST_BYTES_C,
         WINDOW_ADDR_SIZE_G  => WINDOW_ADDR_SIZE_C,
         SEGMENT_ADDR_SIZE_G => SEGMENT_ADDR_SIZE_C,
         HEADER_CHKSUM_EN_G  => HEADER_CHKSUM_EN_G)
      port map (
         clk_i             => clk,
         rst_i             => rst,
         -- AXI Segment Buffer Interface
         axiOffset_i       => txAxiOffset,
         mAxiWriteMaster_o => txAxiWriteMaster,
         mAxiWriteSlave_i  => txAxiWriteSlave,
         mAxiReadMaster_o  => txAxiReadMaster,
         mAxiReadSlave_i   => txAxiReadSlave,
         -- Inbound Application Interface
         appMaster_i       => s_mAppAxisMaster,
         appSlave_o        => s_mAppAxisSlave,
         -- Outbound Transport Interface
         tspMaster_o       => s_sTspAxisMaster,
         tspSlave_i        => s_sTspAxisSlave,
         -- Connection FSM indicating active connection
         connActive_i      => s_connActive,
         -- Closed state in connFSM (initialize seqN)
         closed_i          => s_closed,
         -- Fault injection corrupts header checksum
         injectFault_i     => s_injectFault,
         -- Various segment requests
         sndSyn_i          => s_sndSyn,
         sndAck_i          => s_sndAck,
         sndRst_i          => s_sndRst,
         sndResend_i       => s_sndResend,
         sndNull_i         => s_sndNull,
         -- Window buff size (Depends on the number of outstanding segments)
         windowSize_i      => s_txWindowSize,
         bufferSize_i      => s_txBufferSize,
         -- Header read
         rdHeaderAddr_o    => s_headerAddr,
         rdHeaderData_i    => s_headerData,
         -- Initial sequence number
         initSeqN_i        => s_initSeqN,
         -- Tx data (input to header decoder module)
         txSeqN_o          => s_txSeqN,
         -- FSM outs for header and data flow control
         synHeadSt_o       => s_synHeadSt,
         ackHeadSt_o       => s_ackHeadSt,
         dataHeadSt_o      => s_dataHeadSt,
         dataSt_o          => open,  -- may be used in the future otherwise remove
         rstHeadSt_o       => s_rstHeadSt,
         nullHeadSt_o      => s_nullHeadSt,
         -- Last acked number (Used in Rx FSM to determine if AcnN is valid)
         lastAckN_o        => s_rxLastAckN,
         -- Acknowledge mechanism
         ack_i             => s_rxAck,
         ackN_i            => s_rxAckN,
         ----------------------------------
         --eack_i          => s_rxEack_i, -- From receiver module when a segment with valid EACK is received
         --eackSeqnArr_i   => s_rxEackSeqnArr, -- Array of sequence numbers received out of order
         ----------------------------------
         -- Errors (1 cc pulse)
         lenErr_o          => s_lenErr,
         ackErr_o          => s_ackErr,
         -- Segment buffer indicator
         bufferEmpty_o     => s_txBufferEmpty);

   ------------------
   -- Transport Layer
   ------------------
   U_TspOut : entity surf.AxiStreamResize
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         READY_EN_G          => true,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => RSSI_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => TSP_AXIS_CONFIG_G)
      port map (
         -- Clock and reset
         axisClk     => clk,
         axisRst     => rst,
         -- Slave Port
         sAxisMaster => s_sTspAxisMaster,
         sAxisSlave  => s_sTspAxisSlave,
         -- Master Port
         mAxisMaster => mTspAxisMaster,
         mAxisSlave  => mTspAxisSlave);

   ----------------------------------------------------------------------------
   --                From Transport layer to Application Layer               --
   ----------------------------------------------------------------------------

   ------------------
   -- Transport Layer
   ------------------
   U_TspIn : entity surf.AxiStreamResize
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         READY_EN_G          => true,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => TSP_AXIS_CONFIG_G,
         MASTER_AXI_CONFIG_G => RSSI_AXIS_CONFIG_C)
      port map (
         -- Clock and reset
         axisClk     => clk,
         axisRst     => rst,
         -- Slave Port
         sAxisMaster => sTspAxisMaster,
         sAxisSlave  => sTspAxisSlave,
         -- Master Port
         mAxisMaster => s_mTspAxisMaster,
         mAxisSlave  => s_mTspAxisSlave);

   --------------------------------
   -- Receiver Finite State Machine
   --------------------------------
   U_RxFSM : entity surf.AxiRssiRxFsm
      generic map (
         TPD_G               => TPD_G,
         AXI_CONFIG_G        => AXI_CONFIG_G,
         BURST_BYTES_G       => AXI_BURST_BYTES_C,
         WINDOW_ADDR_SIZE_G  => WINDOW_ADDR_SIZE_C,
         HEADER_CHKSUM_EN_G  => HEADER_CHKSUM_EN_G,
         SEGMENT_ADDR_SIZE_G => SEGMENT_ADDR_SIZE_C)
      port map (
         clk_i             => clk,
         rst_i             => rst,
         -- AXI Segment Buffer Interface
         axiOffset_i       => rxAxiOffset,
         mAxiWriteMaster_o => rxAxiWriteMaster,
         mAxiWriteSlave_i  => rxAxiWriteSlave,
         mAxiReadMaster_o  => rxAxiReadMaster,
         mAxiReadSlave_i   => rxAxiReadSlave,
         -- Inbound Transport Interface
         tspMaster_i       => s_mTspAxisMaster,
         tspSlave_o        => s_mTspAxisSlave,
         -- Outbound Application Interface
         appMaster_o       => s_sAppAxisMaster,
         appSlave_i        => s_sAppAxisSlave,
         -- RX Buffer Full
         rxBuffBusy_o      => s_rxBuffBusy,
         -- Connection FSM indicating active connection
         connActive_i      => s_connActive,
         -- Window size different for Rx and Tx
         rxWindowSize_i    => s_rxWindowSize,
         rxBufferSize_i    => s_rxBufferSize,
         txWindowSize_i    => s_txWindowSize,
         -- Last acknowledged Sequence number connected to TX module
         lastAckN_i        => s_rxLastAckN,
         -- Current received seqN
         rxSeqN_o          => s_rxSeqN,
         -- Current received ackN
         rxLastSeqN_o      => s_rxLastSeqN,
         -- Last seqN received and sent to application (this is the ackN transmitted)
         rxAckN_o          => s_rxAckN,
         -- Valid Segment received (1 c-c)
         rxValidSeg_o      => s_rxValidSeg,
         -- Segment dropped (1 c-c)
         rxDropSeg_o       => s_rxDropSeg,
         -- Last segment received flags (active until next segment is received)
         rxFlags_o         => s_rxFlags,
         -- Parameters received from peer SYN packet
         rxParam_o         => s_rxRssiParam);

   s_rxAck <= s_rxValidSeg and s_rxFlags.ack and s_connActive;  -- Acknowledge valid packet

   --------------------
   -- Application Layer
   --------------------
   U_AppOut : entity surf.AxiStreamResize
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         READY_EN_G          => true,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => RSSI_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => APP_AXIS_CONFIG_G)
      port map (
         -- Clock and reset
         axisClk     => clk,
         axisRst     => rst,
         -- Slave Port
         sAxisMaster => s_sAppAxisMaster,
         sAxisSlave  => s_sAppAxisSlave,
         -- Master Port
         mAxisMaster => s_monMasters(1),
         mAxisSlave  => s_monSlaves(1));

   mAppAxisMaster <= s_monMasters(1);
   s_monSlaves(1) <= mAppAxisSlave;

end architecture rtl;
