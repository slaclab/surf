//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////
//
// Self-driving real-Rogue contract top shared by the Icarus and open-source
// DPI-C SimLink runners. The production Rogue clients (rogue_memory_client.py,
// rogue_stream_client.py, rogue_sideband_client.py, unchanged) drive the
// software side; this top stands in for the cocotb harness of the GHDL
// real-Rogue contracts, drives the HDL-first Stream frame and SideBand event,
// self-checks what those harnesses check, and finishes only once every
// client's result file exists (the transport discards anything still queued
// when this leaf's final block runs).
//
// Port map, fixed offsets from BASE_PORT_G:
//   Memory0   BASE_PORT_G + 0
//   Stream0   BASE_PORT_G + 2
//   SideBand0 BASE_PORT_G + 4
//////////////////////////////////////////////////////////////////////////////

module RogueSvRogueTb #(
   parameter int BASE_PORT_G  = 20050,
   parameter int WAIT_EDGES_G = 1000000
);

   localparam int RESET_EDGES_C  = 4;
   localparam int SETTLE_EDGES_C = 10;
   localparam int GAP_EDGES_C    = 5;
   localparam int POLL_EDGES_C   = 1000;
   localparam int MEM_WORDS_C    = 16;

   // Real-Rogue contract constants. These equal the GHDL real-Rogue contract
   // constants (rogue_memory_client.py TEST_VALUE/POST_VALUE, the Stream
   // HDL_TO_CLIENT/CLIENT_TO_HDL payloads, and the SideBand opcode/remData
   // pairs). Bytes "de ad be ef" in lane order are 32'hEFBEADDE; bytes
   // "12 34 56 78" are 32'h78563412.
   localparam logic [31:0] MEM_POST_VALUE_C = 32'hEBADEBAF;
   localparam logic [31:0] STREAM_TX_DATA_C = 32'hEFBEADDE;
   localparam logic [31:0] STREAM_RX_DATA_C = 32'h78563412;
   localparam logic [7:0]  SB_TX_OPCODE_C   = 8'h2A;
   localparam logic [7:0]  SB_TX_REMDATA_C  = 8'h3B;
   localparam logic [7:0]  SB_RX_OPCODE_C   = 8'h5C;
   localparam logic [7:0]  SB_RX_REMDATA_C  = 8'h6D;

   // -------------------------------------------------------------------------
   // Clock and reset.
   // -------------------------------------------------------------------------
   logic clk;
   logic rst;
   int unsigned edgeCount;

   initial begin
      clk       = 1'b0;
      rst       = 1'b1;
      edgeCount = 0;
   end

   always #5 clk = ~clk;

   always @(posedge clk) begin
      if (edgeCount == RESET_EDGES_C - 1) begin
         rst <= 1'b0;
      end
      edgeCount <= edgeCount + 1;
   end

   // -------------------------------------------------------------------------
   // Runtime plusargs: the three per-client result-file paths.
   // -------------------------------------------------------------------------
   string memoryResultPath;
   string streamResultPath;
   string sidebandResultPath;

   initial begin
      if (!$value$plusargs("ROGUE_MEMORY_RESULT=%s", memoryResultPath)) begin
         $fatal(1, "%m: missing +ROGUE_MEMORY_RESULT=<path>");
      end
      if (!$value$plusargs("ROGUE_STREAM_RESULT=%s", streamResultPath)) begin
         $fatal(1, "%m: missing +ROGUE_STREAM_RESULT=<path>");
      end
      if (!$value$plusargs("ROGUE_SIDEBAND_RESULT=%s", sidebandResultPath)) begin
         $fatal(1, "%m: missing +ROGUE_SIDEBAND_RESULT=<path>");
      end
   end

   // -------------------------------------------------------------------------
   // Memory0: AXI-Lite RAM slave (MEM_WORDS_C 32-bit words), no throttling,
   // OKAY responses. Any accepted AW/AR address at or above 0x40 is fatal.
   // -------------------------------------------------------------------------
   logic [31:0] axilArAddrMem0;
   logic [2:0]  axilArProtMem0;
   logic        axilArValidMem0;
   logic        axilArReadyMem0;
   logic [31:0] axilRDataMem0;
   logic [1:0]  axilRRespMem0;
   logic        axilRValidMem0;
   logic        axilRReadyMem0;
   logic [31:0] axilAwAddrMem0;
   logic [2:0]  axilAwProtMem0;
   logic        axilAwValidMem0;
   logic        axilAwReadyMem0;
   logic [31:0] axilWDataMem0;
   logic [3:0]  axilWStrbMem0;
   logic        axilWValidMem0;
   logic        axilWReadyMem0;
   logic [1:0]  axilBRespMem0;
   logic        axilBValidMem0;
   logic        axilBReadyMem0;

   RogueTcpMemoryWrap #(
      .PORT_NUM_G (BASE_PORT_G + 0)
   ) U_Memory0 (
      .axilClk     (clk),
      .axilRst     (rst),
      .axilArAddr  (axilArAddrMem0),
      .axilArProt  (axilArProtMem0),
      .axilArValid (axilArValidMem0),
      .axilArReady (axilArReadyMem0),
      .axilRData   (axilRDataMem0),
      .axilRResp   (axilRRespMem0),
      .axilRValid  (axilRValidMem0),
      .axilRReady  (axilRReadyMem0),
      .axilAwAddr  (axilAwAddrMem0),
      .axilAwProt  (axilAwProtMem0),
      .axilAwValid (axilAwValidMem0),
      .axilAwReady (axilAwReadyMem0),
      .axilWData   (axilWDataMem0),
      .axilWStrb   (axilWStrbMem0),
      .axilWValid  (axilWValidMem0),
      .axilWReady  (axilWReadyMem0),
      .axilBResp   (axilBRespMem0),
      .axilBValid  (axilBValidMem0),
      .axilBReady  (axilBReadyMem0)
   );

   logic [31:0] mem0Ram [MEM_WORDS_C];

   logic        mem0AwHeld, mem0WHeld, mem0BPending, mem0RPending;
   logic [31:0] mem0AwAddr, mem0WData, mem0RData;
   logic [3:0]  mem0WStrb;

   assign axilAwReadyMem0 = !mem0AwHeld && !mem0BPending;
   assign axilWReadyMem0  = !mem0WHeld  && !mem0BPending;
   assign axilBValidMem0  = mem0BPending;
   assign axilBRespMem0   = 2'b00;
   assign axilArReadyMem0 = !mem0RPending;
   assign axilRValidMem0  = mem0RPending;
   assign axilRRespMem0   = 2'b00;
   assign axilRDataMem0   = mem0RData;

   initial begin
      for (int i = 0; i < MEM_WORDS_C; i++) mem0Ram[i] = 32'h0;
      mem0AwHeld   = 1'b0;
      mem0WHeld    = 1'b0;
      mem0BPending = 1'b0;
      mem0RPending = 1'b0;
   end

   always @(posedge clk) begin
      logic        nextAwHeld, nextWHeld, nextBPending, nextRPending;
      logic [31:0] nextAwAddr, nextWData, nextRData;
      logic [3:0]  nextWStrb;
      logic        doWrite;

      nextAwHeld   = mem0AwHeld;
      nextWHeld    = mem0WHeld;
      nextBPending = mem0BPending;
      nextRPending = mem0RPending;
      nextAwAddr   = mem0AwAddr;
      nextWData    = mem0WData;
      nextWStrb    = mem0WStrb;
      nextRData    = mem0RData;
      doWrite      = 1'b0;

      if (axilAwValidMem0 && axilAwReadyMem0 && axilAwAddrMem0 >= 32'h40) begin
         $fatal(1, "%m: Memory address 0x%08h out of range (AW) at edge %0d", axilAwAddrMem0, edgeCount);
      end
      if (axilArValidMem0 && axilArReadyMem0 && axilArAddrMem0 >= 32'h40) begin
         $fatal(1, "%m: Memory address 0x%08h out of range (AR) at edge %0d", axilArAddrMem0, edgeCount);
      end

      if (axilAwValidMem0 && axilAwReadyMem0) begin
         nextAwHeld = 1'b1;
         nextAwAddr = axilAwAddrMem0;
      end
      if (axilWValidMem0 && axilWReadyMem0) begin
         nextWHeld = 1'b1;
         nextWData = axilWDataMem0;
         nextWStrb = axilWStrbMem0;
      end
      if (nextAwHeld && nextWHeld && !mem0BPending) begin
         doWrite      = 1'b1;
         nextBPending = 1'b1;
         nextAwHeld   = 1'b0;
         nextWHeld    = 1'b0;
      end
      if (mem0BPending && axilBValidMem0 && axilBReadyMem0) begin
         nextBPending = 1'b0;
      end

      if (axilArValidMem0 && axilArReadyMem0) begin
         nextRPending = 1'b1;
         nextRData    = mem0Ram[axilArAddrMem0[5:2]];
      end
      if (mem0RPending && axilRValidMem0 && axilRReadyMem0) begin
         nextRPending = 1'b0;
      end

      if (doWrite) begin
         if (nextWStrb[0]) mem0Ram[nextAwAddr[5:2]][7:0]   <= nextWData[7:0];
         if (nextWStrb[1]) mem0Ram[nextAwAddr[5:2]][15:8]  <= nextWData[15:8];
         if (nextWStrb[2]) mem0Ram[nextAwAddr[5:2]][23:16] <= nextWData[23:16];
         if (nextWStrb[3]) mem0Ram[nextAwAddr[5:2]][31:24] <= nextWData[31:24];
      end

      mem0AwHeld   <= nextAwHeld;
      mem0WHeld    <= nextWHeld;
      mem0BPending <= nextBPending;
      mem0RPending <= nextRPending;
      mem0AwAddr   <= nextAwAddr;
      mem0WData    <= nextWData;
      mem0WStrb    <= nextWStrb;
      mem0RData    <= nextRData;
   end

   // Poll the memory result path every POLL_EDGES_C edges; once it exists,
   // RAM word 0 must equal the posted value.
   logic        memResultSeen;
   int unsigned memPollCounter;
   integer      memResultFile;
   logic        memDone;

   initial begin
      memResultSeen  = 1'b0;
      memPollCounter = 0;
      memDone        = 1'b0;
   end

   always @(posedge clk) begin
      if (!memResultSeen) begin
         if (memPollCounter == 0) begin
            memResultFile = $fopen(memoryResultPath, "r");
            if (memResultFile != 0) begin
               $fclose(memResultFile);
               memResultSeen <= 1'b1;
               if (mem0Ram[0] !== MEM_POST_VALUE_C) begin
                  $fatal(1, "%m: Memory word0=%08h expected %08h", mem0Ram[0], MEM_POST_VALUE_C);
               end
               memDone <= 1'b1;
            end
         end
         memPollCounter <= (memPollCounter + 1) % POLL_EDGES_C;
      end
   end

   // -------------------------------------------------------------------------
   // Stream0: drives one HDL-first frame toward the client, then checks the
   // first client-originated frame.
   // -------------------------------------------------------------------------
   logic        sAxisTValid0, sAxisTLast0, sAxisTReady0;
   logic [63:0] sAxisTData0, sAxisTUser0;
   logic [7:0]  sAxisTKeep0;
   logic        mAxisTValid0, mAxisTLast0, mAxisTReady0;
   logic [63:0] mAxisTData0, mAxisTUser0;
   logic [7:0]  mAxisTKeep0;

   assign mAxisTReady0 = 1'b1;

   RogueTcpStreamWrap #(
      .PORT_NUM_G    (BASE_PORT_G + 2),
      .SSI_EN_G      (1'b1),
      .TDATA_BYTES_G (8)
   ) U_Stream0 (
      .axisClk     (clk),
      .axisRst     (rst),
      .sAxisTValid (sAxisTValid0),
      .sAxisTData  (sAxisTData0),
      .sAxisTKeep  (sAxisTKeep0),
      .sAxisTUser  (sAxisTUser0),
      .sAxisTLast  (sAxisTLast0),
      .sAxisTReady (sAxisTReady0),
      .mAxisTValid (mAxisTValid0),
      .mAxisTData  (mAxisTData0),
      .mAxisTKeep  (mAxisTKeep0),
      .mAxisTUser  (mAxisTUser0),
      .mAxisTLast  (mAxisTLast0),
      .mAxisTReady (mAxisTReady0)
   );

   logic streamTxSent, streamRxSeen, streamDone;

   initial begin
      sAxisTValid0 = 1'b0;
      sAxisTData0  = 64'h0;
      sAxisTKeep0  = 8'h0;
      sAxisTUser0  = 64'h0;
      sAxisTLast0  = 1'b0;
      streamTxSent = 1'b0;
      streamRxSeen = 1'b0;
      streamDone   = 1'b0;
   end

   // Present the HDL-to-client frame at SETTLE_EDGES_C after reset, held
   // steady until the wrap accepts it.
   always @(posedge clk) begin
      if (!streamTxSent && !sAxisTValid0 && edgeCount == (RESET_EDGES_C + SETTLE_EDGES_C)) begin
         sAxisTValid0 <= 1'b1;
         sAxisTData0  <= {32'h0, STREAM_TX_DATA_C};
         sAxisTKeep0  <= 8'h0F;
         sAxisTUser0  <= 64'h2;
         sAxisTLast0  <= 1'b1;
      end else if (sAxisTValid0 && sAxisTReady0) begin
         sAxisTValid0 <= 1'b0;
         streamTxSent <= 1'b1;
      end
   end

   // Check the client-to-HDL frame: the first accepted beat must carry the
   // expected payload; any beat after that is unexpected (single-frame
   // contract).
   always @(posedge clk) begin
      if (mAxisTValid0 && mAxisTReady0) begin
         if (!streamRxSeen) begin
            if (!mAxisTLast0 || mAxisTKeep0 !== 8'h0F || mAxisTData0[31:0] !== STREAM_RX_DATA_C) begin
               $fatal(1, "%m: Stream rx unexpected beat tLast=%0d tKeep=%02h tData=%08h at edge %0d",
                      mAxisTLast0, mAxisTKeep0, mAxisTData0[31:0], edgeCount);
            end
            streamRxSeen <= 1'b1;
         end else begin
            $fatal(1, "%m: Stream rx unexpected beat after completion at edge %0d", edgeCount);
         end
      end
   end

   // Poll the stream result path; done once the frame was sent, the client
   // frame was received, and the result file exists.
   logic        streamResultSeen;
   int unsigned streamPollCounter;
   integer      streamResultFile;

   initial begin
      streamResultSeen  = 1'b0;
      streamPollCounter = 0;
   end

   always @(posedge clk) begin
      if (!streamResultSeen) begin
         if (streamPollCounter == 0) begin
            streamResultFile = $fopen(streamResultPath, "r");
            if (streamResultFile != 0) begin
               $fclose(streamResultFile);
               streamResultSeen <= 1'b1;
            end
         end
         streamPollCounter <= (streamPollCounter + 1) % POLL_EDGES_C;
      end
      if (!streamDone && streamTxSent && streamRxSeen && streamResultSeen) begin
         streamDone <= 1'b1;
      end
   end

   // -------------------------------------------------------------------------
   // SideBand0: strobes an opcode pulse and, GAP_EDGES_C edges later, a
   // remote-data change toward the client (the GHDL sequence), and checks the
   // client-originated opcode pulse/remote-data value on rx*.
   // -------------------------------------------------------------------------
   logic [7:0] txOpCodeSb0, txRemDataSb0;
   logic       txOpCodeEnSb0;
   logic [7:0] rxOpCodeSb0, rxRemDataSb0;
   logic       rxOpCodeEnSb0;

   RogueSideBandWrap #(
      .PORT_NUM_G (BASE_PORT_G + 4)
   ) U_SideBand0 (
      .sysClk     (clk),
      .sysRst     (rst),
      .txOpCode   (txOpCodeSb0),
      .txOpCodeEn (txOpCodeEnSb0),
      .txRemData  (txRemDataSb0),
      .rxOpCode   (rxOpCodeSb0),
      .rxOpCodeEn (rxOpCodeEnSb0),
      .rxRemData  (rxRemDataSb0)
   );

   logic        sbTxPulseDone, sbTxSettleDone;
   int unsigned sbGapCounter;
   int unsigned sbRxPulseCount;
   logic        sbRemDataSeen, sbDone;

   initial begin
      txOpCodeSb0    = 8'h00;
      txOpCodeEnSb0  = 1'b0;
      txRemDataSb0   = 8'h00;
      sbTxPulseDone  = 1'b0;
      sbTxSettleDone = 1'b0;
      sbGapCounter   = 0;
      sbRxPulseCount = 0;
      sbRemDataSeen  = 1'b0;
      sbDone         = 1'b0;
   end

   // The opcode pulse is deliberately sequenced after Memory0 and Stream0
   // both finish their own client exchanges, not off a fixed edge count:
   // the production SideBand client sends its reply and then immediately
   // closes its sockets with a zero linger, discarding anything the ZMQ
   // I/O thread has not yet flushed. Letting the other two leaves' traffic
   // quiesce first keeps this process from contending with that thread for
   // a CPU slot during the narrow send-then-close window.
   always @(posedge clk) begin
      if (!sbTxPulseDone && memDone && streamDone) begin
         txOpCodeSb0   <= SB_TX_OPCODE_C;
         txOpCodeEnSb0 <= 1'b1;
         sbTxPulseDone <= 1'b1;
      end else if (sbTxPulseDone && txOpCodeEnSb0) begin
         txOpCodeEnSb0 <= 1'b0;
         txOpCodeSb0   <= 8'h00;
         sbGapCounter  <= sbGapCounter + 1;
      end else if (sbTxPulseDone && !sbTxSettleDone) begin
         if (sbGapCounter < GAP_EDGES_C) begin
            sbGapCounter <= sbGapCounter + 1;
         end else begin
            txRemDataSb0   <= SB_TX_REMDATA_C;
            sbTxSettleDone <= 1'b1;
         end
      end
   end

   always @(posedge clk) begin
      if (rxOpCodeEnSb0) begin
         if (rxOpCodeSb0 != SB_RX_OPCODE_C) begin
            $fatal(1, "%m: SideBand rx unexpected opcode 0x%0h at edge %0d", rxOpCodeSb0, edgeCount);
         end
         sbRxPulseCount <= sbRxPulseCount + 1;
      end
      if (rxRemDataSb0 != 8'h00 && rxRemDataSb0 != SB_RX_REMDATA_C) begin
         $fatal(1, "%m: SideBand rx unexpected remData 0x%0h at edge %0d", rxRemDataSb0, edgeCount);
      end
      if (rxRemDataSb0 == SB_RX_REMDATA_C) begin
         sbRemDataSeen <= 1'b1;
      end
   end

   // Poll the sideband result path; done once a pulse was seen, remData
   // settled at the expected value, and the result file exists.
   logic        sbResultSeen;
   int unsigned sbPollCounter;
   integer      sbResultFile;

   initial begin
      sbResultSeen  = 1'b0;
      sbPollCounter = 0;
   end

   always @(posedge clk) begin
      if (!sbResultSeen) begin
         if (sbPollCounter == 0) begin
            sbResultFile = $fopen(sidebandResultPath, "r");
            if (sbResultFile != 0) begin
               $fclose(sbResultFile);
               sbResultSeen <= 1'b1;
            end
         end
         sbPollCounter <= (sbPollCounter + 1) % POLL_EDGES_C;
      end
      if (!sbDone && sbRxPulseCount >= 1 && sbRemDataSeen && sbResultSeen) begin
         sbDone <= 1'b1;
      end
   end

   // -------------------------------------------------------------------------
   // Time-zero and reset-phase checks: every wrapper output is 0 before the
   // first rising edge, and the model's reset outputs (sAxisTReady=1,
   // mAxisTValid=0, axilRReady=1, axilBReady=1, rxOpCodeEn=0) are visible
   // while reset is still asserted.
   // -------------------------------------------------------------------------
   initial begin
      #1;
      if (mAxisTValid0 !== 1'b0 || sAxisTReady0 !== 1'b0 ||
          mAxisTData0 !== 64'd0  || mAxisTKeep0 !== 8'd0 || mAxisTUser0 !== 64'd0 || mAxisTLast0 !== 1'b0 ||
          axilArAddrMem0 !== 32'd0 || axilArProtMem0 !== 3'd0 || axilArValidMem0 !== 1'b0 ||
          axilRReadyMem0 !== 1'b0 ||
          axilAwAddrMem0 !== 32'd0 || axilAwProtMem0 !== 3'd0 || axilAwValidMem0 !== 1'b0 ||
          axilWDataMem0 !== 32'd0 || axilWStrbMem0 !== 4'd0 || axilWValidMem0 !== 1'b0 ||
          axilBReadyMem0 !== 1'b0 ||
          rxOpCodeSb0 !== 8'd0 || rxOpCodeEnSb0 !== 1'b0 || rxRemDataSb0 !== 8'd0) begin
         $fatal(1, "%m: nonzero wrapper output observed at time 1");
      end
   end

   always @(posedge clk) begin
      if (edgeCount == 2) begin
         if (!sAxisTReady0 || mAxisTValid0 ||
             !axilRReadyMem0 || !axilBReadyMem0 ||
             axilArValidMem0 || axilAwValidMem0 || axilWValidMem0 ||
             rxOpCodeEnSb0) begin
            $fatal(1, "%m: reset-phase outputs incorrect at edge %0d (sAxisTReady0=%0d mAxisTValid0=%0d axilRReadyMem0=%0d axilBReadyMem0=%0d)",
                   edgeCount, sAxisTReady0, mAxisTValid0, axilRReadyMem0, axilBReadyMem0);
         end
      end
   end

   // -------------------------------------------------------------------------
   // Watchdog, completion, and banner.
   // -------------------------------------------------------------------------
   logic allDone;
   assign allDone = memDone && streamDone && sbDone;

   always @(posedge clk) begin
      if (edgeCount > WAIT_EDGES_G) begin
         $fatal(1, "%m: watchdog expired at edge %0d (memDone=%0d streamDone=%0d sbDone=%0d)",
                edgeCount, memDone, streamDone, sbDone);
      end
      if (allDone) begin
         $display("RogueSvRogueTb memory word0=%08h stream rx=%02h%02h%02h%02h sideband opcode=%02h remdata=%02h",
                   mem0Ram[0],
                   mAxisTData0[7:0], mAxisTData0[15:8], mAxisTData0[23:16], mAxisTData0[31:24],
                   rxOpCodeSb0, rxRemDataSb0);
         $display("RogueSvRogueTb passed");
         $finish;
      end
   end

endmodule
