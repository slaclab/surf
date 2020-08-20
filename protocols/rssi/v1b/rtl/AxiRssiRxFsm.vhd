-------------------------------------------------------------------------------
-- Title      : RSSI Protocol: https://confluence.slac.stanford.edu/x/1IyfD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Receiver FSM
--              Receiver has the following functionality:
--              Transport side FSM. Receive check and save segments to RX buffer.
--               - WAIT_SOF Waits for Transport side SOF,
--               - CHECK Determines the segment type and checks:
--                    ACK, NULL, DATA, or RST segment
--                    1. Validates checksum (when valid),
--                    2. Header length (number of bytes),
--                    3. Sequence number (Only current seqN or lastSeqN+1 allowed)
--                    4. Acknowledgment number (Valid range is lastAckN to lastAckN + txWindowSize)
--               - CHECK_SYN Toggles through SYN header addresses and saves the RSSI parameters
--                    Checks the following:
--                    1. Validates checksum (when valid),
--                    2. Validates Ack number if the ack is sent with the SYN segment
--               - DATA Receives the payload part of the DATA segment
--               - VALID Checks if next valid SEQn is received. If yes:
--                      1. increment the in order SEQn
--                      2. save seqN, type, and occupied to the window buffer at current rxBufferAddr
--                      3. increment rxBufferAddr
--               - DROP Just report dropped packet and got back to WAIT_SOF
--              Receiver side FSM. Send data to App side.
--                - CHECK_BUFFER and DATA Send the data frame to the Application
--                  when the data at the next txSegmentAddr is ready.
--                - SENT Release the windowbuffer at txBufferAddr.
--                       Increment txBufferAddr.
--                       Register the received SeqN for acknowledgment.
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

entity AxiRssiRxFsm is
   generic (
      TPD_G               : time          := 1 ns;
      AXI_CONFIG_G        : AxiConfigType;
      BURST_BYTES_G       : positive      := 1024;
      WINDOW_ADDR_SIZE_G  : positive      := 7;  -- 2^WINDOW_ADDR_SIZE_G  = Number of segments
      HEADER_CHKSUM_EN_G  : boolean       := true;
      SEGMENT_ADDR_SIZE_G : positive      := 3);  -- 2^SEGMENT_ADDR_SIZE_G = Number of 64 bit wide data words
   port (
      clk_i             : in  sl;
      rst_i             : in  sl;
      -- AXI Segment Buffer Interface
      axiOffset_i       : in  slv(63 downto 0);
      mAxiWriteMaster_o : out AxiWriteMasterType;
      mAxiWriteSlave_i  : in  AxiWriteSlaveType;
      mAxiReadMaster_o  : out AxiReadMasterType;
      mAxiReadSlave_i   : in  AxiReadSlaveType;
      -- Inbound Transport Interface
      tspMaster_i       : in  AxiStreamMasterType;
      tspSlave_o        : out AxiStreamSlaveType;
      -- Outbound Application Interface
      appMaster_o       : out AxiStreamMasterType;
      appSlave_i        : in  AxiStreamSlaveType;
      -- RX Buffer Full
      rxBuffBusy_o      : out sl;
      -- Connection FSM indicating active connection
      connActive_i      : in  sl;
      -- Window size different for Rx and Tx
      rxWindowSize_i    : in  integer range 1 to 2 ** (WINDOW_ADDR_SIZE_G);
      rxBufferSize_i    : in  integer range 1 to 2 ** (SEGMENT_ADDR_SIZE_G);  -- Units of 64-bit words
      txWindowSize_i    : in  integer range 1 to 2 ** (WINDOW_ADDR_SIZE_G);
      -- Last acknowledged Sequence number connected to TX module
      lastAckN_i        : in  slv(7 downto 0);
      -- Current received seqN
      rxSeqN_o          : out slv(7 downto 0);
      -- Current received ackN
      rxAckN_o          : out slv(7 downto 0);
      -- Last seqN received and sent to application (this is the ackN transmitted)
      rxLastSeqN_o      : out slv(7 downto 0);
      -- Valid Segment received (1 c-c)
      rxValidSeg_o      : out sl;
      -- Segment dropped (1 c-c)
      rxDropSeg_o       : out sl;
      -- Last segment received flags (active until next segment is received)
      rxFlags_o         : out flagsType;
      -- Parameters received from peer SYN packet
      rxParam_o         : out RssiParamType);
end entity AxiRssiRxFsm;

architecture rtl of AxiRssiRxFsm is

   type tspStateType is (
      IDLE_S,
      SYN_WAIT0_S,
      SYN_WAIT1_S,
      SYN_CHECK_S,
      NSYN_CHECK_S,
      DATA_S,
      VALID_S);

   type AppStateType is (
      IDLE_S,
      DATA_S,
      SENT_S);

   type RegType is record
      -- Reception buffer window
      windowArray  : WindowTypeArray(0 to 2 ** WINDOW_ADDR_SIZE_G-1);
      pending      : slv(WINDOW_ADDR_SIZE_G downto 0);
      --------------------------------------------------
      -- Transport side FSM (Receive and check segments)
      --------------------------------------------------
      wrReq        : AxiWriteDmaReqType;
      -- Counters
      inorderSeqN  : slv(7 downto 0);   -- Next expected seqN
      rxBufferAddr : slv(WINDOW_ADDR_SIZE_G-1 downto 0);
      -- Packet flags
      rxF          : flagsType;
      -- Received RSSI parameters
      rxParam      : RssiParamType;
      rxHeadLen    : slv(7 downto 0);
      rxSeqN       : slv(7 downto 0);   -- Received seqN
      rxAckN       : slv(7 downto 0);   -- Received ackN
      -- Checksum Calculation
      csumAccum    : slv(20 downto 0);
      chksumOk     : sl;
      chksumRdy    : sl;
      checksum     : slv(15 downto 0);
      -- Strobing status flags
      segValid     : sl;
      segDrop      : sl;
      simErrorDet  : sl;
      -- Inbound Transport Interface
      tspSlave     : AxiStreamSlaveType;
      -- State Machine
      tspState     : TspStateType;
      -- Application side FSM (Send segments when next in order received)
      -----------------------------------------------------------
      rdReq        : AxiReadDmaReqType;
      txBufferAddr : slv(WINDOW_ADDR_SIZE_G-1 downto 0);
      rxLastSeqN   : slv(7 downto 0);
      -- State Machine
      appState     : AppStateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      -- Rx buffer window
      windowArray  => (0 to 2 ** WINDOW_ADDR_SIZE_G-1 => WINDOW_INIT_C),
      pending      => (others => '0'),
      --------------------------------------------------
      -- Transport side FSM (Receive and check segments)
      --------------------------------------------------
      wrReq        => AXI_WRITE_DMA_REQ_INIT_C,
      -- Counters
      inorderSeqN  => (others => '0'),  -- Next expected seqN
      rxBufferAddr => (others => '0'),
      -- Packet flags
      rxF          => (others => ('0')),
      -- Received RSSI parameters
      rxParam      => RSSI_PARAM_INIT_C,
      rxHeadLen    => (others => '0'),  -- Received seqN
      rxSeqN       => (others => '0'),  -- Received seqN
      rxAckN       => (others => '0'),  -- Received ackN
      -- Checksum Calculation
      csumAccum    => (others => '0'),
      chksumOk     => '0',
      chksumRdy    => '0',
      checksum     => (others => '0'),
      -- Strobing status flags
      segValid     => '0',
      segDrop      => '0',
      simErrorDet  => '0',
      -- Inbound Transport Interface
      tspSlave     => AXI_STREAM_SLAVE_INIT_C,
      -- Transport side state
      tspState     => IDLE_S,
      ----------------------------------------------------------------------------
      -- Application side FSM (Send segments when received next in order received)
      ----------------------------------------------------------------------------
      rdReq        => AXI_READ_DMA_REQ_INIT_C,
      txBufferAddr => (others => '0'),
      rxLastSeqN   => (others => '0'),
      -- Application side state
      appState     => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal wrAck : AxiWriteDmaAckType;
   signal rdAck : AxiReadDmaAckType;

   signal wrDmaMaster : AxiStreamMasterType;
   signal wrDmaSlave  : AxiStreamSlaveType;

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
         axisMaster    => appMaster_o,
         axisSlave     => appSlave_i,
         axisCtrl      => AXI_STREAM_CTRL_UNUSED_C,
         -- AXI Interface
         axiReadMaster => mAxiReadMaster_o,
         axiReadSlave  => mAxiReadSlave_i);

   -----------------------------------------------------------------------------------------------
   comb : process (axiOffset_i, connActive_i, lastAckN_i, r, rdAck, rst_i,
                   rxBufferSize_i, rxWindowSize_i, tspMaster_i, txWindowSize_i,
                   wrAck, wrDmaSlave) is

      variable v          : RegType;
      variable headerData : slv(63 downto 0);
      variable maxSegSize : natural;
      variable rxBufIdx   : natural;
      variable txBufIdx   : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.tspSlave  := AXI_STREAM_SLAVE_INIT_C;
      v.segValid  := '0';
      v.segDrop   := '0';
      v.chksumRdy := '0';

      -- Endian swap the header
      headerData := endianSwap64(tspMaster_i.tData(63 downto 0));

      -- Convert to bytes
      maxSegSize := 8*rxBufferSize_i;

      -- Calculate the next DMA write transaction
      rxBufIdx        := conv_integer(r.rxBufferAddr);
      v.wrReq.address := axiOffset_i + toSlv((rxBufIdx*maxSegSize), 64);
      v.wrReq.maxSize := toSlv(maxSegSize, 32);

      ------------------------------------------------------------
      -- RX Transport side FSM:
      -- Receive the segment from the peer
      -- Check the segment:
      --       register the parameters from SYN header
      --       seqN, ackN
      --       check header checksum
      --       increment in order received SeqN
      ------------------------------------------------------------
      case r.tspState is
         ----------------------------------------------------------------------
         when IDLE_S =>

            -- Calculate the checksum
            GetRssiCsum(
               -- Input
               '1',                     -- init
               headerData,              -- header
               r.csumAccum,             -- accumReg
               -- Results
               v.csumAccum,             -- accumVar
               v.chksumOk,              -- chksumOk
               v.checksum);             -- checksum

            -- Check for data
            if (tspMaster_i.tValid = '1') then

               -- Accept the data
               v.tspSlave.tReady := '1';

               -- Check if SOF
               if (ssiGetUserSof(RSSI_AXIS_CONFIG_C, tspMaster_i) = '1') then

                  -- Register flags, header length and SEQn
                  v.rxF.syn   := headerData(63);
                  v.rxF.ack   := headerData(62);
                  v.rxF.eack  := headerData(61);
                  v.rxF.rst   := headerData(60);
                  v.rxF.nul   := headerData(59);
                  v.rxF.busy  := headerData(56);
                  v.rxHeadLen := headerData(55 downto 48);
                  v.rxSeqN    := headerData(47 downto 40);
                  v.rxAckN    := headerData(39 downto 32);

                  -- Syn header received (header is 3 c-c long)
                  if (v.rxF.syn = '1') then

                     -- Register SYN header word 0 parameters
                     v.rxParam.version    := headerData(31 downto 28);
                     v.rxParam.chksumEn   := headerData(26 downto 26);
                     v.rxParam.maxOutsSeg := headerData(23 downto 16);
                     v.rxParam.maxSegSize := headerData(15 downto 0);

                     -- Check for early EOF
                     if (tspMaster_i.tLast = '1') then
                        -- Set the flag
                        v.segDrop := '1';
                     else
                        -- Next State
                        v.tspState := SYN_WAIT0_S;
                     end if;

                  else
                     -- Set the flag
                     v.rxF.data := not(tspMaster_i.tLast);
                     -- Next State
                     v.tspState := NSYN_CHECK_S;
                  end if;

               end if;

            end if;
         ----------------------------------------------------------------------
         when SYN_WAIT0_S =>
            -- Check for data
            if (tspMaster_i.tValid = '1') then

               -- Accept the data
               v.tspSlave.tReady := '1';

               -- Calculate the checksum
               GetRssiCsum(
                  -- Input
                  '0',                  -- init
                  headerData,           -- header
                  r.csumAccum,          -- accumReg
                  -- Results
                  v.csumAccum,          -- accumVar
                  v.chksumOk,           -- chksumOk
                  v.checksum);          -- checksum

               -- Syn parameters
               v.rxParam.retransTout  := headerData(63 downto 48);
               v.rxParam.cumulAckTout := headerData(47 downto 32);
               v.rxParam.nullSegTout  := headerData(31 downto 16);
               v.rxParam.maxRetrans   := headerData(15 downto 8);
               v.rxParam.maxCumAck    := headerData(7 downto 0);

               -- Check for early EOF
               if (tspMaster_i.tLast = '1') then
                  -- Set the flag
                  v.segDrop  := '1';
                  -- Next State
                  v.tspState := IDLE_S;
               else
                  -- Next State
                  v.tspState := SYN_WAIT1_S;
               end if;

            end if;

         ----------------------------------------------------------------------
         when SYN_WAIT1_S =>
            -- Check for data
            if (tspMaster_i.tValid = '1') then

               -- Accept the data
               v.tspSlave.tReady := '1';

               -- Calculate the checksum
               GetRssiCsum(
                  -- Input
                  '0',                  -- init
                  headerData,           -- header
                  r.csumAccum,          -- accumReg
                  -- Results
                  v.csumAccum,          -- accumVar
                  v.chksumOk,           -- chksumOk
                  v.checksum);          -- checksum

               -- Syn parameters
               v.rxParam.maxOutofseq               := headerData(63 downto 56);
               v.rxParam.timeoutUnit               := headerData(55 downto 48);
               v.rxParam.connectionId(31 downto 0) := headerData(47 downto 16);

               -- Check for no EOF
               if (tspMaster_i.tLast = '0') then
                  -- Set the flag
                  v.segDrop  := '1';
                  -- Next State
                  v.tspState := IDLE_S;
               else
                  -- Next State
                  v.tspState := SYN_CHECK_S;
               end if;

            end if;
         ----------------------------------------------------------------------
         when SYN_CHECK_S =>

            -- Last cycle of pipeline
            v.chksumRdy := '1';
            GetRssiCsum(
               -- Input
               '0',                     -- init
               (others => '0'),         -- header
               r.csumAccum,             -- accumReg
               -- Results
               v.csumAccum,             -- accumVar
               v.chksumOk,              -- chksumOk
               v.checksum);             -- checksum

            if (r.chksumRdy = '1') then

               -- Check the header
               if ((HEADER_CHKSUM_EN_G = false) or (r.chksumOk = '1')) and (r.rxHeadLen = toSlv(24, 8)) then
                  -- Next State
                  v.tspState := VALID_S;
               else

                  -- Set the flag
                  v.segDrop := '1';

                  -- Next State
                  v.tspState := IDLE_S;

               end if;

            end if;
         ----------------------------------------------------------------------
         when NSYN_CHECK_S =>
            -- Last cycle of pipeline
            v.chksumRdy := '1';
            GetRssiCsum(
               -- Input
               '0',                     -- init
               (others => '0'),         -- header
               r.csumAccum,             -- accumReg
               -- Results
               v.csumAccum,             -- accumVar
               v.chksumOk,              -- chksumOk
               v.checksum);             -- checksum

            if (r.chksumRdy = '1') then

               -- Check the header
               if (
                  ((HEADER_CHKSUM_EN_G = false) or (r.chksumOk = '1')) and
                  -- Check length
                  r.rxHeadLen = toSlv(8, 8) and
                  -- Check SeqN range
                  (r.rxSeqN - r.inOrderSeqN) <= 1 and
                  -- Check AckN range
                  (r.rxAckN - lastAckN_i)    <= txWindowSize_i
                  ) then

                  -- Valid data segment
                  if (r.rxF.data = '1' and v.rxF.nul = '0' and v.rxF.rst = '0') then

                     -- Wait if the buffer full
                     -- Note: Deadlock possibility! If the peer is not accepting data!
                     if (r.windowArray(rxBufIdx).occupied = '0') then
                        -- Start the DMA write transaction
                        v.wrReq.request := '1';
                        -- Next State
                        v.tspState      := DATA_S;

                     -- Buffer is full -> drop segment
                     else
                        -- Set the flag
                        v.segDrop  := '1';
                        -- Next State
                        v.tspState := IDLE_S;
                     end if;

                  -- Valid non data segment
                  elsif (r.rxF.data = '0') then
                     -- Next State
                     v.tspState := VALID_S;

                  -- Undefined condition
                  else
                     -- Set the flag
                     v.segDrop  := '1';
                     -- Next State
                     v.tspState := IDLE_S;
                  end if;

               -- Else failed header checking
               else
                  -- Set the flag
                  v.segDrop  := '1';
                  -- Next State
                  v.tspState := IDLE_S;
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
                  v.segDrop  := '1';
                  -- Next State
                  v.tspState := IDLE_S;
               else
                  -- Next State
                  v.tspState := VALID_S;
               end if;

            end if;
         ----------------------------------------------------------------------
         when VALID_S =>
            -- Set the flag
            v.segValid := '1';

            -- Initialize when valid SYN segment received
            -- 1. Set the initial SeqN
            -- 2. Initialize the buffer address
            -- 3. Initialize window
            if (connActive_i = '0') and (r.rxF.syn = '1') then

               -- Initialize for FSM internal signals
               v.rxF.ack      := r.rxF.ack;
               v.inOrderSeqN  := r.rxSeqN;
               v.rxBufferAddr := (others => '0');
               v.windowArray  := REG_INIT_C.windowArray;
               v.pending      := (others => '0');

            -- Check if next valid SEQn is received. If yes:
            -- 1. increment the in order SEQn
            -- 2. save seqN, type, and occupied to the current buffer address
            -- 3. increase buffer
            elsif ((r.rxF.data = '1' or r.rxF.nul = '1' or r.rxF.rst = '1') and
                   -- Next seqN absolute difference is one
                   r.rxSeqN - r.inOrderSeqN = 1
                   ) then

               -- Fill in the window array buffer
               v.windowArray(rxBufIdx).seqN       := r.rxSeqN;
               v.windowArray(rxBufIdx).segType(0) := r.rxF.data;
               v.windowArray(rxBufIdx).segType(1) := r.rxF.nul;
               v.windowArray(rxBufIdx).segType(2) := r.rxF.rst;
               v.windowArray(rxBufIdx).occupied   := '1';

               -- Update the in-order sequence index
               v.inOrderSeqN := r.rxSeqN;

               -- Increment the RX buffer index
               if r.rxBufferAddr < (rxWindowSize_i-1) then
                  v.rxBufferAddr := r.rxBufferAddr +1;
               else
                  v.rxBufferAddr := (others => '0');
               end if;

               -- Increment the pending counter
               if v.pending < rxWindowSize_i then
                  v.pending := v.pending + 1;
               end if;

            end if;

            -- Next State
            v.tspState := IDLE_S;
      ----------------------------------------------------------------------
      end case;

      -- Calculate the next DMA read transaction
      txBufIdx                     := conv_integer(r.txBufferAddr);
      v.rdReq.address              := axiOffset_i + toSlv((txBufIdx*maxSegSize), 64);
      v.rdReq.size                 := toSlv(r.windowArray(txBufIdx).segSize, 32);
      v.rdReq.firstUser(SSI_SOF_C) := '1';  -- SOF

      ----------------------------------------------------------------------------
      -- TX Application side FSM:
      -- Transmit the segments in correct order
      -- Check the buffer if the next slot is available and send the buffer to APP
      ----------------------------------------------------------------------------
      case r.appState is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check if not connected
            if (connActive_i = '0') then
               -- Reset the index pointers
               v.txBufferAddr := (others => '0');
               v.rxLastSeqN   := r.inOrderSeqN;

            -- Check for occupied buffer
            elsif (r.windowArray(txBufIdx).occupied = '1') then

               -- Check for a data segment
               if (r.windowArray(txBufIdx).segType(0) = '1') then

                  -- Check if ready to move data
                  if (rdAck.idle = '1') then
                     -- Start the DMA read transaction
                     v.rdReq.request := '1';

                     -- Next State
                     v.appState := DATA_S;
                  end if;

               else
                  -- Next State
                  v.appState := SENT_S;
               end if;

            end if;
         ----------------------------------------------------------------------
         when DATA_S =>
            -- Check if DMA write completed
            if (rdAck.done = '1') then

               -- Reset the flag
               v.rdReq.request := '0';

               -- Next State
               v.appState := SENT_S;

            end if;
         ----------------------------------------------------------------------
         when SENT_S =>
            -- Register the sent SeqN (this means that the place has been freed and the SeqN can be Acked)
            v.rxLastSeqN := r.windowArray(txBufIdx).seqN;

            -- Release buffer
            v.windowArray(txBufIdx).occupied := '0';

            -- Increment the TX buffer index
            if r.txBufferAddr < (rxWindowSize_i-1) then
               v.txBufferAddr := r.txBufferAddr+1;  -- Increment once
            else
               v.txBufferAddr := (others => '0');
            end if;

            -- Decrement the pending counter
            if v.pending /= 0 then
               v.pending := v.pending - 1;
            end if;

            -- Next State
            v.appState := IDLE_S;
      ----------------------------------------------------------------------
      end case;

      v.simErrorDet := (r.segDrop or wrAck.overflow or wrAck.writeError or rdAck.readError);
     -- if r.simErrorDet = '1' then
        -- assert false
           -- report "Simulation Failed!" severity failure;
     -- end if;

      ----------------------------------------------------------------------
      --                            Outputs                               --
      ----------------------------------------------------------------------

      -- Inbound Transport Interface
      wrDmaMaster        <= tspMaster_i;
      wrDmaMaster.tValid <= tspMaster_i.tValid and r.wrReq.request;
      tspSlave_o.tReady  <= v.tspSlave.tReady or wrDmaSlave.tReady;

      -- RX Buffer Full
      if (r.pending > 1) then
         rxBuffBusy_o <= '1';
      else
         rxBuffBusy_o <= '0';
      end if;

      -- Current received seqN
      rxSeqN_o <= r.rxSeqN;

      -- Current received ackN
      rxAckN_o <= r.rxAckN;

      -- Last seqN received and sent to application (this is the ackN transmitted)
      rxLastSeqN_o <= r.rxLastSeqN;

      -- Valid Segment received (1 c-c)
      rxValidSeg_o <= r.segValid;

      -- Segment dropped (1 c-c)
      rxDropSeg_o <= r.segDrop;

      -- Last segment received flags (active until next segment is received)
      rxFlags_o <= r.rxF;

      -- Parameters received from peer SYN packet
      rxParam_o <= r.rxParam;

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
