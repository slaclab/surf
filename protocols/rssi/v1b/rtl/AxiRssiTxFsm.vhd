-------------------------------------------------------------------------------
-- Title      : RSSI Protocol: https://confluence.slac.stanford.edu/x/1IyfD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Transmitter FSM
--              Transmitter has the following functionality:
--              Handle buffer addresses and buffer window (firstUnackAddr,nextSentAddr,lastSentAddr, bufferFull, bufferEmpty)
--              Application side FSM. Receive SSI frame and store into TX data buffer.
--                   - IDLE Waits until buffer window is free (not bufferFull),
--                   - Waits for Application side SOF,
--                   - Save the segment to Rx buffer at nextSentAddr. Disable sending of NULL segments with appBusy flag,
--                   - When EOF received save segment length and keep flags. Check length error,
--                   - Request data send at Transport side FSM and increment nextSentAddr
--                   - Wait until the data is processed and data segment sent by Transport side FSM
--                   - Release appBusy flag and go back to INIT.
--              Acknowledgment FSM.
--                   - IDLE Waits for ack_i (ack request) and ackN_i(ack number)(from RxFSM),
--                   - Increments firstUnackAddr until the ackN_i is found in Window buffer,
--                   - If it does not find the SEQ number it reports Ack Error,
--                   - Goes back to IDLE.
--              Transport side FSM. Send and resend various segments to Transport side.
--                   - INIT Initializes seqN to initSeqN. Waits until new connection requested. ConnFSM goin out od Closed state.
--                   - DISS_CONN allows sending SYN, ACK, or RST segments. Goes to CONN when connection becomes active.
--                   - CONN allows sending DATA, NULL, ACK, or RST segments.
--                     In Resend procedure the FSM resends all the unacknowledged (DATA, NULL, RST) segments in the buffer window.
--
--              Note:Sequence number is incremented with sending SYN, DATA, NULL, and RST segments.
--              Note:Only the following segments are saved into Tx buffer DATA, NULL, and RST.
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
use surf.AxiStreamPkg.all;
use surf.AxiPkg.all;
use surf.AxiDmaPkg.all;
use surf.AxiRssiPkg.all;
use surf.RssiPkg.all;
use surf.SsiPkg.all;

entity AxiRssiTxFsm is
   generic (
      TPD_G               : time          := 1 ns;
      AXI_CONFIG_G        : AxiConfigType;
      BURST_BYTES_G       : positive      := 1024;
      WINDOW_ADDR_SIZE_G  : positive      := 3;  -- 2^WINDOW_ADDR_SIZE_G  = Number of segments
      SEGMENT_ADDR_SIZE_G : positive      := 7;  -- 2^SEGMENT_ADDR_SIZE_G = Number of 64 bit wide data words
      HEADER_CHKSUM_EN_G  : boolean       := true);
   port (
      clk_i             : in  sl;
      rst_i             : in  sl;
      -- AXI Segment Buffer Interface
      axiOffset_i       : in  slv(63 downto 0);
      mAxiWriteMaster_o : out AxiWriteMasterType;
      mAxiWriteSlave_i  : in  AxiWriteSlaveType;
      mAxiReadMaster_o  : out AxiReadMasterType;
      mAxiReadSlave_i   : in  AxiReadSlaveType;
      -- Inbound Application Interface
      appMaster_i       : in  AxiStreamMasterType;
      appSlave_o        : out AxiStreamSlaveType;
      -- Outbound Transport Interface
      tspMaster_o       : out AxiStreamMasterType;
      tspSlave_i        : in  AxiStreamSlaveType;
      -- Connection FSM indicating active connection
      connActive_i      : in  sl;
      -- Closed state in connFSM (initialize seqN)
      closed_i          : in  sl;
      -- Fault injection corrupts header checksum
      injectFault_i     : in  sl;
      -- Various segment requests
      sndSyn_i          : in  sl;
      sndAck_i          : in  sl;
      sndRst_i          : in  sl;
      sndResend_i       : in  sl;
      sndNull_i         : in  sl;
      -- Window buff size (Depends on the number of outstanding segments)
      windowSize_i      : in  integer range 1 to 2 ** (WINDOW_ADDR_SIZE_G);
      bufferSize_i      : in  integer range 1 to 2 ** (SEGMENT_ADDR_SIZE_G);
      -- Header read
      rdHeaderAddr_o    : out slv(7 downto 0);
      rdHeaderData_i    : in  slv(RSSI_WORD_WIDTH_C*8-1 downto 0);
      -- Initial sequence number
      initSeqN_i        : in  slv(7 downto 0);
      -- Tx data (input to header decoder module)
      txSeqN_o          : out slv(7 downto 0);
      -- FSM outs for header and data flow control
      synHeadSt_o       : out sl;
      ackHeadSt_o       : out sl;
      dataHeadSt_o      : out sl;
      dataSt_o          : out sl;
      rstHeadSt_o       : out sl;
      nullHeadSt_o      : out sl;
      -- Last acked number (Used in Rx FSM to determine if AcnN is valid)
      lastAckN_o        : out slv(7 downto 0);
      -- Acknowledge mechanism
      ack_i             : in  sl;  -- From receiver module when a segment with valid ACK is received
      ackN_i            : in  slv(7 downto 0);   -- Number being ACKed
      --eack_i        : in sl;                 -- From receiver module when a segment with valid EACK is received
      --eackSeqnArr_i : in Slv8Array(0 to MAX_RX_NUM_OUTS_SEG_G-1); -- Array of sequence numbers received out of order
      -- Errors (1 cc pulse)
      lenErr_o          : out sl;
      ackErr_o          : out sl;
      -- Segment buffer indicator
      bufferEmpty_o     : out sl);
end entity AxiRssiTxFsm;

architecture rtl of AxiRssiTxFsm is

   type TspStateType is (
      --
      INIT_S,
      DISS_CONN_S,
      CONN_S,
      --
      SYN_H_S,
      SYN_XSUM_S,
      NSYN_H_S,
      NSYN_XSUM_S,
      DATA_H_S,
      DATA_XSUM_S,
      DATA_S,
      --
      RESEND_INIT_S,
      RESEND_H_S,
      RESEND_XSUM_S,
      RESEND_PP_S);

   type AppStateType is (
      IDLE_S,
      WAIT_SOF_S,
      DATA_S,
      SEG_RDY_S);

   type AckStateType is (
      IDLE_S,
      ERR_S,
      -- EACK_S,
      ACK_S);

   type RegType is record
      ----------------------------------------------------
      -- Buffer window handling and acknowledgment control
      ----------------------------------------------------
      windowArray    : WindowTypeArray(0 to 2 ** WINDOW_ADDR_SIZE_G-1);
      firstUnackAddr : slv(WINDOW_ADDR_SIZE_G-1 downto 0);
      nextSentAddr   : slv(WINDOW_ADDR_SIZE_G-1 downto 0);
      lastSentAddr   : slv(WINDOW_ADDR_SIZE_G-1 downto 0);
      lastAckSeqN    : slv(7 downto 0);
      --eackAddr       : slv(WINDOW_ADDR_SIZE_G-1 downto 0);
      --eackIndex      : integer;
      bufferFull     : sl;
      bufferEmpty    : sl;
      ackErr         : sl;
      -- State Machine
      ackState       : AckStateType;
      -----------------------
      -- Application side FSM
      -----------------------
      wrReq          : AxiWriteDmaReqType;
      rxBufferAddr   : slv(WINDOW_ADDR_SIZE_G-1 downto 0);
      rxSegmentWe    : sl;
      sndData        : sl;
      lenErr         : sl;
      appBusy        : sl;
      appSlave       : AxiStreamSlaveType;
      appState       : AppStateType;
      ---------------------
      -- Transport side FSM
      ---------------------
      rdReq          : AxiReadDmaReqType;
      -- Checksum Calculation
      csumAccum      : slv(20 downto 0);
      chksumOk       : sl;
      checksum       : slv(15 downto 0);
      -- Counters
      nextSeqN       : slv(7 downto 0);
      seqN           : slv(7 downto 0);
      txHeaderAddr   : slv(7 downto 0);
      txBufferAddr   : slv(WINDOW_ADDR_SIZE_G-1 downto 0);
      -- Data mux flags
      synH           : sl;
      ackH           : sl;
      rstH           : sl;
      nullH          : sl;
      dataH          : sl;
      dataD          : sl;
      resend         : sl;
      ackSndData     : sl;
      hdrAmrmed      : sl;
      simErrorDet    : sl;
      -- Various controls
      buffWe         : sl;
      buffSent       : sl;
      -- Fault injection
      injectFaultD1  : sl;
      injectFaultReg : sl;
      -- Transport Interface
      rdDmaSlave     : AxiStreamSlaveType;
      tspMaster      : AxiStreamMasterType;
      -- State Machine
      tspState       : tspStateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      ----------------------------------------------------
      -- Buffer window handling and acknowledgment control
      ----------------------------------------------------
      -- Window control
      firstUnackAddr => (others => '0'),
      lastSentAddr   => (others => '0'),
      nextSentAddr   => (others => '0'),
      lastAckSeqN    => (others => '0'),
      --eackAddr       => (others => '0'),
      --eackIndex      => 0,
      bufferFull     => '0',
      bufferEmpty    => '1',
      windowArray    => (0 to 2 ** WINDOW_ADDR_SIZE_G-1 => WINDOW_INIT_C),
      ackErr         => '0',
      ackState       => IDLE_S,
      -----------------------
      -- Application side FSM
      -----------------------
      wrReq          => AXI_WRITE_DMA_REQ_INIT_C,
      rxSegmentWe    => '0',
      rxBufferAddr   => (others => '0'),
      sndData        => '0',
      lenErr         => '0',
      appBusy        => '0',
      appSlave       => AXI_STREAM_SLAVE_INIT_C,
      appState       => IDLE_S,
      ----------------------
      -- Transport side FSM
      ----------------------
      rdReq          => AXI_READ_DMA_REQ_INIT_C,
      --
      csumAccum      => (others => '0'),
      chksumOk       => '0',
      checksum       => (others => '0'),
      --
      nextSeqN       => (others => '0'),
      seqN           => (others => '0'),
      txHeaderAddr   => (others => '0'),
      txBufferAddr   => (others => '0'),
      --
      synH           => '0',
      ackH           => '0',
      rstH           => '0',
      nullH          => '0',
      dataH          => '0',
      dataD          => '0',
      resend         => '0',
      ackSndData     => '0',
      hdrAmrmed      => '0',
      simErrorDet    => '0',
      --
      buffWe         => '0',
      buffSent       => '0',
      -- Fault injection
      injectFaultD1  => '0',
      injectFaultReg => '0',
      -- Transport Interface
      rdDmaSlave     => AXI_STREAM_SLAVE_INIT_C,
      tspMaster      => AXI_STREAM_MASTER_INIT_C,
      -- State Machine
      tspState       => INIT_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal wrAck : AxiWriteDmaAckType;
   signal rdAck : AxiReadDmaAckType;

   signal wrDmaMaster : AxiStreamMasterType;
   signal wrDmaSlave  : AxiStreamSlaveType;

   signal rdDmaMaster : AxiStreamMasterType;
   signal rdDmaSlave  : AxiStreamSlaveType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "TRUE";

begin

   U_DmaWrite : entity surf.AxiStreamDmaWrite
      generic map (
         TPD_G             => TPD_G,
         AXI_READY_EN_G    => true,
         AXIS_CONFIG_G     => RSSI_AXIS_CONFIG_C,
         AXI_CONFIG_G      => AXI_CONFIG_G,
         BURST_BYTES_G     => BURST_BYTES_G,
         AXI_BURST_G       => "01",     -- INCR
         AXI_CACHE_G       => "0011",   -- Cacheable
         SW_CACHE_EN_G     => false,
         ACK_WAIT_BVALID_G => true,
         PIPE_STAGES_G     => 0,
         BYP_SHIFT_G       => true,
         BYP_CACHE_G       => true)
      port map (
         -- Clock/Reset
         axiClk         => clk_i,
         axiRst         => rst_i,
         -- DMA Control Interface
         dmaReq         => r.wrReq,
         dmaAck         => wrAck,
         -- Streaming Interface
         axisMaster     => wrDmaMaster,
         axisSlave      => wrDmaSlave,
         -- AXI Interface
         axiWriteMaster => mAxiWriteMaster_o,
         axiWriteSlave  => mAxiWriteSlave_i);

   U_DmaRead : entity surf.AxiStreamDmaRead
      generic map (
         TPD_G           => TPD_G,
         AXIS_READY_EN_G => true,
         AXIS_CONFIG_G   => RSSI_AXIS_CONFIG_C,
         AXI_CONFIG_G    => AXI_CONFIG_G,
         AXI_BURST_G     => "01",       -- INCR
         AXI_CACHE_G     => "0011",     -- Cacheable
         SW_CACHE_EN_G   => false,
         PIPE_STAGES_G   => 0,
         PEND_THRESH_G   => 0,          -- In units of bytes
         BYP_SHIFT_G     => true)
      port map (
         -- Clock/Reset
         axiClk        => clk_i,
         axiRst        => rst_i,
         -- DMA Control Interface
         dmaReq        => r.rdReq,
         dmaAck        => rdAck,
         -- Streaming Interface
         axisMaster    => rdDmaMaster,
         axisSlave     => rdDmaSlave,
         axisCtrl      => AXI_STREAM_CTRL_UNUSED_C,
         -- AXI Interface
         axiReadMaster => mAxiReadMaster_o,
         axiReadSlave  => mAxiReadSlave_i);


   -----------------------------------------------------------------------------------------------
   comb : process (ackN_i, ack_i, appMaster_i, axiOffset_i, bufferSize_i,
                   closed_i, connActive_i, initSeqN_i, injectFault_i, r, rdAck,
                   rdDmaMaster, rdHeaderData_i, rst_i, sndAck_i, sndNull_i,
                   sndResend_i, sndRst_i, sndSyn_i, tspSlave_i, windowSize_i,
                   wrAck, wrDmaSlave) is

      variable v          : RegType;
      variable maxSegSize : natural;
      variable rxBufIdx   : natural;
      variable txBufIdx   : natural;
   begin
      -- Latch the current value
      v := r;

      -- Convert to bytes
      maxSegSize := 8*bufferSize_i;

      -- Reset strobes
      v.appSlave   := AXI_STREAM_SLAVE_INIT_C;
      v.ackSndData := '0';
      v.sndData    := '0';
      v.lenErr     := '0';

      -- /////////////////////////////////////////////////////////
      ------------------------------------------------------------
      -- Buffer window handling
      ------------------------------------------------------------
      -- /////////////////////////////////////////////////////////

      ------------------------------------------------------------
      -- Buffer full if next slot is occupied
      if (r.windowArray(conv_integer(v.rxBufferAddr)).occupied = '1') then
         v.bufferFull := '1';
      else
         v.bufferFull := '0';
      end if;

      ------------------------------------------------------------
      -- Buffer empty if next unacknowledged slot is unoccupied
      if (r.windowArray(conv_integer(r.firstUnackAddr)).occupied = '0') then
         v.bufferEmpty := '1';
      else
         v.bufferEmpty := '0';
      end if;

      ------------------------------------------------------------
      -- Write seqN and segment type to window array
      ------------------------------------------------------------
      if (r.buffWe = '1') then
         v.windowArray(conv_integer(r.nextSentAddr)).seqN     := r.nextSeqN;
         v.windowArray(conv_integer(r.nextSentAddr)).segType  := r.rstH & r.nullH & r.dataH;
         v.windowArray(conv_integer(r.nextSentAddr)).occupied := '1';

         -- Update last sent address when new segment is being sent
         v.lastSentAddr := r.nextSentAddr;
      else
         v.windowArray := r.windowArray;
      end if;

      ------------------------------------------------------------
      -- When buffer is sent increase nextSentAddr
      ------------------------------------------------------------
      if (r.buffSent = '1') then

         if r.nextSentAddr < (windowSize_i-1) then
            v.nextSentAddr := r.nextSentAddr +1;
         else
            v.nextSentAddr := (others => '0');
         end if;

      else
         v.nextSentAddr := r.nextSentAddr;
      end if;

      -- /////////////////////////////////////////////////////////
      ------------------------------------------------------------
      -- ACK FSM
      -- Acknowledgment mechanism to increment firstUnackAddr
      -- Place out of order flags from EACK table (Not in Version 1)
      ------------------------------------------------------------
      -- /////////////////////////////////////////////////////////

      case r.ackState is
         ----------------------------------------------------------------------
         when IDLE_S =>

            -- Hold ACK address
            v.firstUnackAddr := r.firstUnackAddr;
            v.lastAckSeqN    := r.lastAckSeqN;
            --v.eackAddr       := r.firstUnackAddr;
            --v.eackIndex      := 0;
            v.ackErr         := '0';

            -- Next state condition
            if (ack_i = '1') then
               v.ackState := ACK_S;
            end if;
         ----------------------------------------------------------------------
         when ACK_S =>

            -- If the same ackN received do nothing
            if (r.lastAckSeqN = ackN_i) then
               v.firstUnackAddr := r.firstUnackAddr;
            -- Increment ACK address until seqN is found next received
            elsif r.firstUnackAddr < (windowSize_i-1) then
               v.windowArray(conv_integer(r.firstUnackAddr)).occupied := '0';
               v.firstUnackAddr                                       := r.firstUnackAddr+1;
            else
               v.windowArray(conv_integer(r.firstUnackAddr)).occupied := '0';
               v.firstUnackAddr                                       := (others => '0');
            end if;

            --v.eackAddr       := r.firstUnackAddr;
            -- v.eackIndex      := 0;
            v.ackErr := '0';

            -- Next state condition

            -- If the same ackN received
            if (r.lastAckSeqN = ackN_i) then

               -- Go back to IDLE
               v.ackState := IDLE_S;

            elsif (r.firstUnackAddr = r.lastSentAddr and r.windowArray(conv_integer(r.firstUnackAddr)).seqN /= ackN_i) then
               -- If the acked seqN is not found go to error state
               v.ackState := ERR_S;
            elsif (r.windowArray(conv_integer(r.firstUnackAddr)).seqN = ackN_i) then
               v.lastAckSeqN := ackN_i;  -- Save the last Acked seqN
               --if eack_i = '1' then
               -- Go back to init when the acked seqN is found
               --   v.ackState   := EACK_S;
               --else
               -- Go back to init when the acked seqN is found
               v.ackState    := IDLE_S;
            --end if;
            end if;
            ----------------------------------------------------------------------
            -- when EACK_S =>

            -- -- Increment EACK address from firstUnackAddr to nextSentAddr
            -- if r.eackAddr < (windowSize_i-1) then
            -- v.eackAddr  := r.eackAddr+1;
            -- else
            -- v.eackAddr  := (others => '0');
            -- end if;

            -- -- For every address check if the sequence number equals value from eackSeqnArr_i array.
            -- -- If it matches mark the eack field at the address and compare the next value from the table.
            -- if  r.windowArray(conv_integer(r.eackAddr)).seqN = eackSeqnArr_i(r.eackIndex)  then
            -- v.windowArray(conv_integer(r.eackAddr)).eacked := '1';
            -- v.eackIndex := r.eackIndex + 1;
            -- end if;

            -- v.firstUnackAddr  := r.firstUnackAddr;
            -- v.ackErr          := '0';

         -- -- Next state condition
         -- if (r.eackAddr = r.nextSentAddr) then
         -- -- If the acked seqN is not found go to error state
         -- v.ackState   := IDLE_S;
         -- end if;
         ----------------------------------------------------------------------
         when ERR_S =>
            -- Outputs
            v.firstUnackAddr := r.firstUnackAddr;
            --v.eackAddr       := r.firstUnackAddr;
            --v.eackIndex      := 0;
            v.ackErr         := '1';

            -- Next state condition
            v.ackState := IDLE_S;
      ----------------------------------------------------------------------
      end case;

      -- /////////////////////////////////////////////////////////
      ------------------------------------------------------------
      -- Application side FSM
      ------------------------------------------------------------
      -- /////////////////////////////////////////////////////////

      -- Calculate the next DMA write transaction
      rxBufIdx        := conv_integer(r.rxBufferAddr);
      v.wrReq.address := axiOffset_i + toSlv((rxBufIdx*maxSegSize), 64);
      v.wrReq.maxSize := toSlv(maxSegSize, 32);

      ------------------------------------------------------------
      case r.appState is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Set the flag
            v.appBusy := '1';
            -- Check if buffer if not full
            if (v.bufferFull = '0') then
               -- Next state
               v.appState := WAIT_SOF_S;
            end if;
         ----------------------------------------------------------------------
         when WAIT_SOF_S =>
            -- Set the flag
            v.appBusy := '0';
            -- If other segment (NULL, or RST) is requested return to IDLE_S to
            -- check if buffer is still available (not full)
            if (r.buffWe = '1') then
               -- Increment the buffer window address because a NULL segment has filled the current spot
               if r.rxBufferAddr < (windowSize_i-1) then
                  v.rxBufferAddr := r.rxBufferAddr+1;
               else
                  v.rxBufferAddr := (others => '0');
               end if;
               -- Set the flag
               v.appBusy  := '1';
               -- Next state
               v.appState := IDLE_S;
            -- Check for data
            elsif (appMaster_i.tValid = '1') then
               -- Check if SOF
               if (ssiGetUserSof(RSSI_AXIS_CONFIG_C, appMaster_i) = '1') then
                  -- Set the flag
                  v.appBusy       := '1';
                  -- Start the DMA write transaction
                  v.wrReq.request := '1';
                  -- Next State
                  v.appState      := DATA_S;
               else
                  -- Blow off the data
                  v.appSlave.tReady := '1';
               end if;
            end if;
         ----------------------------------------------------------------------
         when DATA_S =>
            -- Latch the segment size
            v.windowArray(rxBufIdx).segSize := conv_integer(wrAck.size);
            -- Check if DMA write completed
            if (wrAck.done = '1') then
               -- Reset the flag
               v.wrReq.request := '0';
               -- Check for error
               if (wrAck.writeError = '1') or (wrAck.overflow = '1') then
                  -- Set the flag
                  v.lenErr   := '1';
                  -- Next state
                  v.appState := IDLE_S;
               else
                  -- Next state
                  v.appState := SEG_RDY_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when SEG_RDY_S =>
            -- Request data transfer
            v.sndData := '1';
            -- Hold request until accepted and not in resend process
            if (r.ackSndData = '1') and (v.resend = '0') then
               -- Increment the rxBuffer
               if r.rxBufferAddr < (windowSize_i-1) then
                  v.rxBufferAddr := r.rxBufferAddr+1;
               else
                  v.rxBufferAddr := (others => '0');
               end if;
               -- Next state
               v.appState := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;


      -- /////////////////////////////////////////////////////////
      ------------------------------------------------------------
      -- Initialization of the parameters when the connection is broken
      if (connActive_i = '0') then
         v.firstUnackAddr := REG_INIT_C.firstUnackAddr;
         v.lastSentAddr   := REG_INIT_C.lastSentAddr;
         v.nextSentAddr   := REG_INIT_C.nextSentAddr;
         v.rxBufferAddr   := REG_INIT_C.rxBufferAddr;
         v.bufferFull     := REG_INIT_C.bufferFull;
         v.bufferEmpty    := REG_INIT_C.bufferEmpty;
         v.windowArray    := REG_INIT_C.windowArray;
         v.lastAckSeqN    := initSeqN_i;
         v.ackState       := REG_INIT_C.ackState;
         v.appState       := REG_INIT_C.appState;
      end if;
      ------------------------------------------------------------
      -- /////////////////////////////////////////////////////////

      -- /////////////////////////////////////////////////////////
      ------------------------------------------------------------
      -- Arm fault injection on rising edge of injectFault_i
      ------------------------------------------------------------
      -- /// //////////////////////////////////////////////////////
      v.injectFaultD1 := injectFault_i;

      if (injectFault_i = '1' and r.injectFaultD1 = '0') then
         v.injectFaultReg := '1';
      else
         v.injectFaultReg := r.injectFaultReg;
      end if;


      -- /////////////////////////////////////////////////////////
      ------------------------------------------------------------
      -- Transport side FSM
      ------------------------------------------------------------
      -- /////////////////////////////////////////////////////////

      -- Reset strobes
      v.buffWe     := '0';
      v.buffSent   := '0';
      v.rdDmaSlave := AXI_STREAM_SLAVE_INIT_C;
      if (tspSlave_i.tReady = '1') then
         v.tspMaster.tValid := '0';
         v.tspMaster.tLast  := '0';
         v.tspMaster.tUser  := (others => '0');
         v.tspMaster.tKeep  := (others => '1');
      end if;

      -- Calculate the next DMA read transaction
      txBufIdx        := conv_integer(r.txBufferAddr);
      v.rdReq.address := axiOffset_i + toSlv((txBufIdx*maxSegSize), 64);
      v.rdReq.size    := toSlv(r.windowArray(txBufIdx).segSize, 32);

      -- Update the pipeline
      GetRssiCsum(
         -- Input
         '0',                           -- init
         (others => '0'),               -- header
         r.csumAccum,                   -- accumReg
         -- Results
         v.csumAccum,                   -- accumVar
         v.chksumOk,                    -- chksumOk
         v.checksum);                   -- checksum


      case r.tspState is
         ----------------------------------------------------------------------
         when INIT_S =>
            -- Initialize all
            v          := REG_INIT_C;
            -- Register initial sequence number
            v.nextSeqN := initSeqN_i;
            v.seqN     := r.nextSeqN;
            -- Next state condition
            if (closed_i = '0') then
               -- Next state
               v.tspState := DISS_CONN_S;
            end if;
         ----------------------------------------------------------------------
         when DISS_CONN_S =>
            -- Update the sequence indexes
            v.nextSeqN     := r.nextSeqN;
            v.seqN         := r.nextSeqN;
            -- Update TX buffer address
            v.txBufferAddr := r.nextSentAddr;
            -- Reset RSSI flags
            v.synH         := '0';
            v.ackH         := '0';
            v.rstH         := '0';
            v.nullH        := '0';
            v.dataH        := '0';
            v.dataD        := '0';
            v.resend       := '0';
            v.hdrAmrmed    := '0';
            -- Check for SYN
            if (sndSyn_i = '1') then
               -- Set the flag
               v.synH     := '1';
               -- Next state
               v.tspState := SYN_H_S;
            -- Check for ACK
            elsif (sndAck_i = '1') then
               -- Set the flag
               v.ackH     := '1';
               -- Next state
               v.tspState := NSYN_H_S;
            -- Check for RST
            elsif (sndRst_i = '1') then
               -- Set the flag
               v.rstH     := '1';
               -- Next state
               v.tspState := NSYN_H_S;
            -- Check for link up
            elsif (connActive_i = '1') then
               -- Next state
               v.tspState := CONN_S;
            -- Check for link down
            elsif (closed_i = '1') then
               -- Next state
               v.tspState := INIT_S;
            end if;
         ----------------------------------------------------------------------
         when CONN_S =>
            -- Update TX buffer address
            v.txBufferAddr := r.nextSentAddr;
            -- Reset RSSI flags
            v.synH         := '0';
            v.ackH         := '0';
            v.rstH         := '0';
            v.nullH        := '0';
            v.dataH        := '0';
            v.dataD        := '0';
            v.resend       := '0';
            v.hdrAmrmed    := '0';
            -- Check for RST
            if (sndRst_i = '1') then
               -- Set the flags
               v.rstH     := '1';
               -- Next state
               v.tspState := NSYN_H_S;
            -- Check for DATA
            elsif (r.sndData = '1') and (r.bufferFull = '0') then
               -- Set the flags
               v.ackSndData    := '1';
               v.dataH         := '1';
               v.buffWe        := '1';  -- Update buffer seqN and Type
               -- Start the DMA read transaction
               v.rdReq.request := '1';
               -- Next state
               v.tspState      := DATA_H_S;
            -- Check for RESEND
            elsif (sndResend_i = '1') and (r.bufferEmpty = '0') then
               -- Next state
               v.tspState := RESEND_INIT_S;
            -- Check for ACK
            elsif (sndAck_i = '1') then
               -- Set the flag
               v.ackH     := '1';
               -- Next state
               v.tspState := NSYN_H_S;
            -- Check for NULL
            elsif (sndNull_i = '1') and (r.bufferFull = '0') and (r.appBusy = '0') then
               -- Set flags
               v.nullH    := '1';
               v.buffWe   := '1';       -- Update buffer seqN and Type
               -- Next state
               v.tspState := NSYN_H_S;
            -- Check for link down
            elsif (connActive_i = '0') then
               -- Next state
               v.tspState := INIT_S;
            end if;
         ----------------------------------------------------------------------
         when SYN_H_S =>
            -- Set the flag
            v.hdrAmrmed := '1';
            -- Check if ready to move data
            if (r.tspMaster.tValid = '0') and (r.hdrAmrmed = '1') then  -- Using registered value to help relax timing
               -- Move the data
               v.tspMaster.tValid             := '1';
               v.tspMaster.tData(63 downto 0) := endianSwap64(rdHeaderData_i);
               -- Increment the counter
               v.txHeaderAddr                 := r.txHeaderAddr + 1;
               -- Check for SOF
               if (r.txHeaderAddr = 0) then
                  -- Set the SOF flag
                  ssiSetUserSof(RSSI_AXIS_CONFIG_C, v.tspMaster, '1');
                  -- Calculate the checksum
                  GetRssiCsum(
                     -- Input
                     '1',               -- init
                     rdHeaderData_i,    -- header
                     r.csumAccum,       -- accumReg
                     -- Results
                     v.csumAccum,       -- accumVar
                     v.chksumOk,        -- chksumOk
                     v.checksum);       -- checksum
               elsif (r.txHeaderAddr = 1) or (r.txHeaderAddr = 2) then
                  -- Calculate the checksum
                  GetRssiCsum(
                     -- Input
                     '0',               -- init
                     rdHeaderData_i,    -- header
                     r.csumAccum,       -- accumReg
                     -- Results
                     v.csumAccum,       -- accumVar
                     v.chksumOk,        -- chksumOk
                     v.checksum);       -- checksum
                  if (r.txHeaderAddr = 2) then
                     -- Keep counter value
                     v.txHeaderAddr     := r.txHeaderAddr;
                     -- Hold off write
                     v.tspMaster.tValid := '0';
                     -- Reset the flag
                     v.hdrAmrmed        := '0';
                     -- Next state
                     v.tspState         := SYN_XSUM_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when SYN_XSUM_S =>
            -- Set the flag
            v.hdrAmrmed := '1';
            -- Check if ready to move data (r.tspMaster.tValid already '0' from previous state)
            if (r.hdrAmrmed = '1') then  -- Using registered value to help relax timing
               -- Reset counter
               v.txHeaderAddr     := (others => '0');
               -- Move the data
               v.tspMaster.tValid := '1';
               -- Set EOF flag
               v.tspMaster.tLast  := '1';
               -- Check if header checksum enable generic set
               if (HEADER_CHKSUM_EN_G) then
                  -- Insert the checksum
                  v.tspMaster.tData(63 downto 56) := r.checksum(7 downto 0);
                  v.tspMaster.tData(55 downto 48) := r.checksum(15 downto 8);
               end if;
               -- Increment SEQ number at the end of segment transmission
               v.nextSeqN := r.nextSeqN+1;
               v.seqN     := r.nextSeqN+1;
               -- Next state
               v.tspState := DISS_CONN_S;
            end if;
         ----------------------------------------------------------------------
         when NSYN_H_S =>               -- RST/ACK/NULL messages
            -- Set the flag
            v.hdrAmrmed := '1';
            -- Check if ready to move data
            if (r.tspMaster.tValid = '0') and (r.hdrAmrmed = '1') then  -- Using registered value to help relax timing
               -- Set the data
               v.tspMaster.tData(63 downto 0) := endianSwap64(rdHeaderData_i);
               -- Calculate the checksum
               GetRssiCsum(
                  -- Input
                  '1',                  -- init
                  rdHeaderData_i,       -- header
                  r.csumAccum,          -- accumReg
                  -- Results
                  v.csumAccum,          -- accumVar
                  v.chksumOk,           -- chksumOk
                  v.checksum);          -- checksum
               -- Reset the flag
               v.hdrAmrmed := '0';
               -- Next state
               v.tspState  := NSYN_XSUM_S;
            end if;
         ----------------------------------------------------------------------
         when NSYN_XSUM_S =>
            -- Set the flag
            v.hdrAmrmed := '1';
            -- Check if ready to move data (r.tspMaster.tValid already '0' from previous state)
            if (r.hdrAmrmed = '1') then  -- Using registered value to help relax timing
               -- Move the data
               v.tspMaster.tValid := '1';
               -- Set the SOF flag
               ssiSetUserSof(RSSI_AXIS_CONFIG_C, v.tspMaster, '1');
               -- Set EOF flag
               v.tspMaster.tLast  := '1';
               -- Check if header checksum enable generic set
               if (HEADER_CHKSUM_EN_G) then
                  -- Insert the checksum
                  v.tspMaster.tData(63 downto 56) := r.checksum(7 downto 0);
                  v.tspMaster.tData(55 downto 48) := r.checksum(15 downto 8);
               end if;
               -- Check for RST or NULL
               if (r.rstH = '1') or (r.nullH = '1') then
                  -- Increment seqN
                  v.nextSeqN := r.nextSeqN+1;  -- Increment SEQ number at the end of segment transmission
                  v.seqN     := r.nextSeqN+1;
               end if;
               -- Increment the sent buffer
               v.buffSent := r.nullH;
               -- Check if link up
               if connActive_i = '0' then
                  -- Next state
                  v.tspState := DISS_CONN_S;
               else
                  -- Next state
                  v.tspState := CONN_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when DATA_H_S =>
            -- Set the flag
            v.hdrAmrmed := '1';
            -- Check if ready to move data
            if (r.tspMaster.tValid = '0') and (r.hdrAmrmed = '1') then  -- Using registered value to help relax timing
               -- Set the data
               v.tspMaster.tData(63 downto 0) := endianSwap64(rdHeaderData_i);
               -- Calculate the checksum
               GetRssiCsum(
                  -- Input
                  '1',                  -- init
                  rdHeaderData_i,       -- header
                  r.csumAccum,          -- accumReg
                  -- Results
                  v.csumAccum,          -- accumVar
                  v.chksumOk,           -- chksumOk
                  v.checksum);          -- checksum
               -- Reset the flag
               v.hdrAmrmed := '0';
               -- Next state
               v.tspState  := DATA_XSUM_S;
            end if;
         ----------------------------------------------------------------------
         when DATA_XSUM_S =>
            -- Set the flag
            v.hdrAmrmed := '1';
            -- Check if ready to move data (r.tspMaster.tValid already '0' from previous state)
            if (r.hdrAmrmed = '1') then  -- Using registered value to help relax timing
               -- Move the data
               v.tspMaster.tValid := '1';
               -- Set the SOF flag
               ssiSetUserSof(RSSI_AXIS_CONFIG_C, v.tspMaster, '1');
               -- Check if header checksum enable generic set
               if (HEADER_CHKSUM_EN_G) then
                  -- Inject fault into checksum
                  if (r.injectFaultReg = '1') then
                     -- Flip bits in checksum! Point of fault injection!
                     v.tspMaster.tData(63 downto 56) := not(r.checksum(7 downto 0));
                     v.tspMaster.tData(55 downto 48) := not(r.checksum(15 downto 8));
                  else
                     -- Insert the checksum
                     v.tspMaster.tData(63 downto 56) := r.checksum(7 downto 0);
                     v.tspMaster.tData(55 downto 48) := r.checksum(15 downto 8);
                  end if;
               end if;
               -- Set the fault reg to 0
               v.injectFaultReg := '0';
               -- Update the flags
               v.dataH          := '0';
               v.dataD          := '1';  -- Send data
               -- Next state
               v.tspState       := DATA_S;
            end if;
         ----------------------------------------------------------------------
         when DATA_S =>
            -- Check if ready to move data
            if (v.tspMaster.tValid = '0') and (rdDmaMaster.tValid = '1') then
               -- Accept the data
               v.rdDmaSlave.tReady := '1';
               -- Move the data
               v.tspMaster         := rdDmaMaster;
               -- Check for last transfer
               if (rdDmaMaster.tLast = '1') then
                  -- Reset the flag
                  v.rdReq.request := '0';
                  -- Check if not resending
                  if (r.resend = '0') then
                     -- Increment SEQ number at the end of segment transmission
                     v.nextSeqN := r.nextSeqN+1;
                     v.seqN     := r.nextSeqN+1;
                     -- Increment buffer last sent address(txBuffer)
                     v.buffSent := '1';
                     -- Next state
                     v.tspState := CONN_S;
                  else
                     -- Next state
                     v.tspState := RESEND_PP_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         -- Resend all packets from the buffer
         -- Packets between r.firstUnackAddr and r.lastSentAddr
         ----------------------------------------------------------------------
         when RESEND_INIT_S =>
            -- Check if first segment iteration of resending
            if (r.resend = '0') then
               -- Start from first unack address
               v.txBufferAddr := r.firstUnackAddr;
               -- Update the sequence indexes
               v.nextSeqN     := r.nextSeqN;  -- Never increment seqN while resending
               v.seqN         := r.windowArray(conv_integer(r.firstUnackAddr)).seqN;
            end if;
            -- Update the RSSI flags
            v.synH      := '0';
            v.ackH      := '0';
            v.rstH      := r.windowArray(conv_integer(r.firstUnackAddr)).segType(2);
            v.nullH     := r.windowArray(conv_integer(r.firstUnackAddr)).segType(1);
            v.dataH     := r.windowArray(conv_integer(r.firstUnackAddr)).segType(0);
            v.dataD     := '0';
            v.resend    := '1';
            -- Reset the flag
            v.hdrAmrmed := '0';
            -- Next state condition
            v.tspState  := RESEND_H_S;
         ----------------------------------------------------------------------
         when RESEND_H_S =>
            -- Set the flag
            v.hdrAmrmed := '1';
            -- Check if ready to move data
            if (r.tspMaster.tValid = '0') and (r.hdrAmrmed = '1') then  -- Using registered value to help relax timing
               -- Set the data
               v.tspMaster.tData(63 downto 0) := endianSwap64(rdHeaderData_i);
               -- Calculate the checksum
               GetRssiCsum(
                  -- Input
                  '1',                  -- init
                  rdHeaderData_i,       -- header
                  r.csumAccum,          -- accumReg
                  -- Results
                  v.csumAccum,          -- accumVar
                  v.chksumOk,           -- chksumOk
                  v.checksum);          -- checksum
               -- Reset the flag
               v.hdrAmrmed := '0';
               -- Next state
               v.tspState  := RESEND_XSUM_S;
            end if;
         ----------------------------------------------------------------------
         when RESEND_XSUM_S =>
            -- Set the flag
            v.hdrAmrmed := '1';
            -- Check if ready to move data (r.tspMaster.tValid already '0' from previous state)
            if (r.hdrAmrmed = '1') then  -- Using registered value to help relax timing
               -- Move the data
               v.tspMaster.tValid := '1';
               -- Set the SOF flag
               ssiSetUserSof(RSSI_AXIS_CONFIG_C, v.tspMaster, '1');
               -- Check if header checksum enable generic set
               if (HEADER_CHKSUM_EN_G) then
                  -- Insert the checksum
                  v.tspMaster.tData(63 downto 56) := r.checksum(7 downto 0);
                  v.tspMaster.tData(55 downto 48) := r.checksum(15 downto 8);
               end if;
               -- Check for a Null or Rst packet
               if (r.windowArray(txBufIdx).segType(2) = '1') or (r.windowArray(txBufIdx).segType(1) = '1') then
                  -- Set EOF flag
                  v.tspMaster.tLast := '1';
                  -- Next state
                  v.tspState        := RESEND_PP_S;
               -- else resend the DATA packet start sending data
               else
                  -- Start the DMA read transaction
                  v.rdReq.request := '1';
                  -- Next state
                  v.tspState      := DATA_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when RESEND_PP_S =>
            -- Increment buffer address (circular)
            if r.txBufferAddr < (windowSize_i-1) then
               v.txBufferAddr := r.txBufferAddr+1;
            else
               v.txBufferAddr := (others => '0');
            end if;
            -- Go back to CONN_S when the last sent address reached
            if (r.txBufferAddr = r.lastSentAddr) then
               -- Next state
               v.tspState := CONN_S;
            else
               -- Next state
               v.tspState := RESEND_INIT_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      v.simErrorDet := (wrAck.overflow or wrAck.writeError or rdAck.readError);
     -- if r.simErrorDet = '1' then
        -- assert false
           -- report "Simulation Failed!" severity failure;
     -- end if;

      ----------------------------------------------------------------------
      --                            Outputs                               --
      ----------------------------------------------------------------------

      -- Inbound Application Interface
      wrDmaMaster        <= appMaster_i;
      wrDmaMaster.tValid <= appMaster_i.tValid and r.wrReq.request;
      appSlave_o.tReady  <= v.appSlave.tReady or wrDmaSlave.tReady;

      -- Outbound Transport Interface
      tspMaster_o <= r.tspMaster;

      -- DMA Read Interface
      rdDmaSlave <= v.rdDmaSlave;

      -- Tx data (input to header decoder module)
      txSeqN_o <= r.seqN;

      -- FSM outs for header and data flow control
      rdHeaderAddr_o <= v.txHeaderAddr;
      synHeadSt_o    <= r.synH;
      ackHeadSt_o    <= r.ackH;
      dataHeadSt_o   <= r.dataH;
      dataSt_o       <= r.dataD;
      rstHeadSt_o    <= r.rstH;
      nullHeadSt_o   <= r.nullH;

      -- Last acked number (Used in Rx FSM to determine if AcnN is valid)
      lastAckN_o <= r.lastAckSeqN;

      -- Errors (1 cc pulse)
      ackErr_o <= r.ackErr;
      lenErr_o <= r.lenErr;

      -- Segment buffer indicator
      bufferEmpty_o <= r.bufferEmpty;

      -- Reset
      if (rst_i = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk_i) is
   begin
      if (rising_edge(clk_i)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
