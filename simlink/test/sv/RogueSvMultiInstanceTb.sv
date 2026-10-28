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
// Self-driving eight-instance isolation top shared by the Icarus and open-
// source SimLink runners. Instantiates four Stream, two Memory and two
// SideBand leaves concurrently on adjacent port pairs (the layout of
// multi_instance_peer_specs(): Stream tag t at BASE_PORT_G+2t, Memory tag t
// at BASE_PORT_G+8+2t, SideBand tag t at BASE_PORT_G+12+2t). Each instance
// drives and checks only its own tagged vector in HDL; any cross-instance
// value is a $fatal. Once every instance completes, the top clears every
// SideBand's remote-data register, re-pulses reset, and runs a guard window
// checking for spurious post-reset traffic before printing its pass banner.
//////////////////////////////////////////////////////////////////////////////

module RogueSvMultiInstanceTb #(
   parameter int BASE_PORT_G  = 20000,
   parameter int WAIT_EDGES_G = 1000000
);

   localparam int STREAM_COUNT_C   = 4;
   localparam int MEMORY_COUNT_C   = 2;
   localparam int SIDEBAND_COUNT_C = 2;
   localparam int RESET_EDGES_C    = 4;
   localparam int SETTLE_EDGES_C   = 10;
   localparam int GUARD_EDGES_C    = 2000;
   localparam int RERESET_EDGES_C  = 4;
   localparam int RUN_EDGES_C      = 50;
   localparam int MEM_WORDS_C      = 64;

   localparam int unsigned SEQ_INIT    = 0;
   localparam int unsigned SEQ_RUN     = 1;
   localparam int unsigned SEQ_GUARD   = 2;
   localparam int unsigned SEQ_CLEAR   = 3;
   localparam int unsigned SEQ_RERESET = 4;
   localparam int unsigned SEQ_POST    = 5;
   localparam int unsigned SEQ_DONE    = 6;

   // -------------------------------------------------------------------------
   // Clock and the sequencer that owns reset. edgeCount runs for the entire
   // simulation (watchdog and driver-trigger comparisons below); phaseEdge
   // counts edges since the sequencer entered its current state.
   // -------------------------------------------------------------------------
   logic        clk;
   logic        rst;
   int unsigned edgeCount;
   int unsigned phaseEdge;
   int unsigned seqState;
   logic        clearReq;

   initial begin
      clk       = 1'b0;
      rst       = 1'b1;
      edgeCount = 0;
      phaseEdge = 0;
      seqState  = SEQ_INIT;
      clearReq  = 1'b0;
   end

   always #5 clk = ~clk;

   // Per-instance completion vectors, populated by the generate blocks below.
   wire [STREAM_COUNT_C-1:0]   streamDone;
   wire [MEMORY_COUNT_C-1:0]   memoryDone;
   wire [SIDEBAND_COUNT_C-1:0] sideBandDone;

   // Per-instance post-reset activity, used only by the POST spurious-traffic
   // guard below.
   wire [STREAM_COUNT_C-1:0]   streamMAxisValid;
   wire [MEMORY_COUNT_C-1:0]   memoryAnyReqValid;
   wire [SIDEBAND_COUNT_C-1:0] sidebandRxEn;

   wire allDone = &streamDone && &memoryDone && &sideBandDone;

   // Fires on the edge-2 reset-phase check (initial reset) and again on the
   // last edge of the reset re-pulse, so every per-instance reset-phase
   // checker below can share one condition for both windows.
   wire resetCheckPulse = (edgeCount == 2) ||
                          (seqState == SEQ_RERESET && phaseEdge == RERESET_EDGES_C - 1);

   always @(posedge clk) begin
      int unsigned nextPhaseEdge;
      int unsigned nextSeqState;
      logic        nextRst;
      logic        nextClearReq;

      edgeCount <= edgeCount + 1;

      nextPhaseEdge = phaseEdge + 1;
      nextSeqState  = seqState;
      nextRst       = rst;
      nextClearReq  = 1'b0;

      case (seqState)
         SEQ_INIT: begin
            if (phaseEdge == RESET_EDGES_C - 1) begin
               nextRst       = 1'b0;
               nextSeqState  = SEQ_RUN;
               nextPhaseEdge = 0;
            end
         end

         SEQ_RUN: begin
            if (allDone) begin
               nextSeqState  = SEQ_GUARD;
               nextPhaseEdge = 0;
            end
         end

         SEQ_GUARD: begin
            if (phaseEdge == GUARD_EDGES_C - 1) begin
               nextSeqState  = SEQ_CLEAR;
               nextPhaseEdge = 0;
            end
         end

         SEQ_CLEAR: begin
            // Clear every SideBand's remote-data register before the reset
            // re-pulse: the leaf clears its own remembered value on reset,
            // so a nonzero txRemData still held after reset release would be
            // (re)transmitted as though it were a new change.
            nextClearReq  = 1'b1;
            nextSeqState  = SEQ_RERESET;
            nextPhaseEdge = 0;
         end

         SEQ_RERESET: begin
            nextRst = 1'b1;
            if (phaseEdge == RERESET_EDGES_C - 1) begin
               nextRst       = 1'b0;
               nextSeqState  = SEQ_POST;
               nextPhaseEdge = 0;
            end
         end

         SEQ_POST: begin
            if (phaseEdge == RUN_EDGES_C - 1) begin
               $display("%m: completion edge %0d, reset re-pulse clean", edgeCount);
               $display("RogueSvMultiInstanceTb passed");
               $finish;
            end
         end

         default: begin
            // SEQ_DONE: unreachable, $finish already called above.
         end
      endcase

      phaseEdge <= nextPhaseEdge;
      seqState  <= nextSeqState;
      rst       <= nextRst;
      clearReq  <= nextClearReq;
   end

   // -------------------------------------------------------------------------
   // gen_stream: four Stream leaves. Each drives its own tagged beat toward
   // the peer on sAxis (the wrapper's "HDL-to-software" port) and checks the
   // one tagged beat it receives from the peer on mAxis ("software-to-HDL").
   // -------------------------------------------------------------------------
   for (genvar t = 0; t < STREAM_COUNT_C; t++) begin : gen_stream

      logic        sAxisTReady;
      logic        mAxisTValid, mAxisTLast;
      logic [63:0] mAxisTData, mAxisTUser;
      logic [7:0]  mAxisTKeep;

      logic        txValid, txDone;
      wire  [63:0] txData = {32'h0, 8'(32'hB0 + t), 8'(32'hA0 + t), 8'(32'h90 + t), 8'(32'h80 + t)};
      wire  [7:0]  txKeep = 8'h0F;
      wire  [63:0] txUser = 64'h2;
      wire         txLast = 1'b1;

      wire mAxisTReadyLoc = 1'b1;
      wire [31:0] expectRxData = {8'(32'h40 + t), 8'(32'h30 + t), 8'(32'h20 + t), 8'(32'h10 + t)};

      RogueTcpStreamWrap #(
         .PORT_NUM_G    (BASE_PORT_G + 2*t),
         .SSI_EN_G      (1'b1),
         .TDATA_BYTES_G (8)
      ) U_Stream (
         .axisClk     (clk),
         .axisRst     (rst),
         .sAxisTValid (txValid),
         .sAxisTData  (txData),
         .sAxisTKeep  (txKeep),
         .sAxisTUser  (txUser),
         .sAxisTLast  (txLast),
         .sAxisTReady (sAxisTReady),
         .mAxisTValid (mAxisTValid),
         .mAxisTData  (mAxisTData),
         .mAxisTKeep  (mAxisTKeep),
         .mAxisTUser  (mAxisTUser),
         .mAxisTLast  (mAxisTLast),
         .mAxisTReady (mAxisTReadyLoc)
      );

      initial begin
         txValid = 1'b0;
         txDone  = 1'b0;
      end

      always @(posedge clk) begin
         if (!txValid && !txDone && edgeCount == (RESET_EDGES_C + SETTLE_EDGES_C)) begin
            txValid <= 1'b1;
         end else if (txValid && sAxisTReady) begin
            txValid <= 1'b0;
            txDone  <= 1'b1;
         end
      end

      logic rxDone;
      initial rxDone = 1'b0;

      always @(posedge clk) begin
         if (mAxisTValid && mAxisTReadyLoc) begin
            if (rxDone) begin
               $fatal(1, "%m: Stream tag %0d unexpected second beat at edge %0d", t, edgeCount);
            end
            if (mAxisTLast !== 1'b1 || mAxisTKeep !== 8'h0F || mAxisTUser[1] !== 1'b1 ||
                mAxisTData[31:0] !== expectRxData) begin
               $fatal(1, "%m: Stream tag %0d unexpected beat data=%016h keep=%02h user=%016h last=%0d expected=%08h at edge %0d",
                      t, mAxisTData, mAxisTKeep, mAxisTUser, mAxisTLast, expectRxData, edgeCount);
            end
            rxDone <= 1'b1;
         end
      end

      assign streamDone[t]       = txDone && rxDone;
      assign streamMAxisValid[t] = mAxisTValid;

      // Time-zero and reset-phase checks, in the RogueSvTrafficTb.sv form.
      initial begin
         #1;
         if (mAxisTValid !== 1'b0 || sAxisTReady !== 1'b0 ||
             mAxisTData !== 64'd0 || mAxisTKeep !== 8'd0 || mAxisTUser !== 64'd0 || mAxisTLast !== 1'b0) begin
            $fatal(1, "%m: Stream tag %0d nonzero wrapper output observed at time 1", t);
         end
      end

      always @(posedge clk) begin
         if (resetCheckPulse) begin
            if (!sAxisTReady || mAxisTValid) begin
               $fatal(1, "%m: Stream tag %0d reset-phase outputs incorrect at edge %0d (sAxisTReady=%0d mAxisTValid=%0d)",
                      t, edgeCount, sAxisTReady, mAxisTValid);
            end
         end
      end

   end

   // -------------------------------------------------------------------------
   // gen_memory: two Memory leaves. Each is a one-word-per-tag AXI-Lite RAM
   // slave with no throttling, checking the accepted address and write data
   // against its own tagged transaction before accepting a read-back.
   // -------------------------------------------------------------------------
   for (genvar t = 0; t < MEMORY_COUNT_C; t++) begin : gen_memory

      logic [31:0] axilArAddr;
      logic [2:0]  axilArProt;
      logic        axilArValid;
      logic        axilArReady;
      logic [31:0] axilRData;
      logic [1:0]  axilRResp;
      logic        axilRValid;
      logic        axilRReady;
      logic [31:0] axilAwAddr;
      logic [2:0]  axilAwProt;
      logic        axilAwValid;
      logic        axilAwReady;
      logic [31:0] axilWData;
      logic [3:0]  axilWStrb;
      logic        axilWValid;
      logic        axilWReady;
      logic [1:0]  axilBResp;
      logic        axilBValid;
      logic        axilBReady;

      RogueTcpMemoryWrap #(
         .PORT_NUM_G (BASE_PORT_G + 2*STREAM_COUNT_C + 2*t)
      ) U_Memory (
         .axilClk     (clk),
         .axilRst     (rst),
         .axilArAddr  (axilArAddr),
         .axilArProt  (axilArProt),
         .axilArValid (axilArValid),
         .axilArReady (axilArReady),
         .axilRData   (axilRData),
         .axilRResp   (axilRResp),
         .axilRValid  (axilRValid),
         .axilRReady  (axilRReady),
         .axilAwAddr  (axilAwAddr),
         .axilAwProt  (axilAwProt),
         .axilAwValid (axilAwValid),
         .axilAwReady (axilAwReady),
         .axilWData   (axilWData),
         .axilWStrb   (axilWStrb),
         .axilWValid  (axilWValid),
         .axilWReady  (axilWReady),
         .axilBResp   (axilBResp),
         .axilBValid  (axilBValid),
         .axilBReady  (axilBReady)
      );

      wire [31:0] expectAddr = 32'h100 + 32'h10 * t;
      wire [31:0] expectWord = {8'(32'h70 + t), 8'(32'h60 + t), 8'(32'h50 + t), 8'(32'h40 + t)};

      logic [31:0] ram [MEM_WORDS_C];

      logic        awHeld, wHeld, bPending, rPending;
      logic [31:0] heldAwAddr, heldWData, rDataReg;
      logic [3:0]  heldWStrb;
      logic        writeSeen, readSeen;

      assign axilAwReady = !awHeld && !bPending;
      assign axilWReady  = !wHeld  && !bPending;
      assign axilBValid  = bPending;
      assign axilBResp   = 2'b00;
      assign axilArReady = !rPending;
      assign axilRValid  = rPending;
      assign axilRResp   = 2'b00;
      assign axilRData   = rDataReg;

      initial begin
         for (int i = 0; i < MEM_WORDS_C; i++) ram[i] = 32'h0;
         awHeld     = 1'b0;
         wHeld      = 1'b0;
         bPending   = 1'b0;
         rPending   = 1'b0;
         heldAwAddr = 32'h0;
         heldWData  = 32'h0;
         heldWStrb  = 4'h0;
         rDataReg   = 32'h0;
         writeSeen  = 1'b0;
         readSeen   = 1'b0;
      end

      always @(posedge clk) begin
         logic        nextAwHeld, nextWHeld, nextBPending, nextRPending;
         logic [31:0] nextAwAddr, nextWData, nextRData;
         logic [3:0]  nextWStrb;
         logic        nextWriteSeen, nextReadSeen;
         logic        doWrite, doRead;

         nextAwHeld    = awHeld;
         nextWHeld     = wHeld;
         nextBPending  = bPending;
         nextRPending  = rPending;
         nextAwAddr    = heldAwAddr;
         nextWData     = heldWData;
         nextWStrb     = heldWStrb;
         nextRData     = rDataReg;
         nextWriteSeen = writeSeen;
         nextReadSeen  = readSeen;
         doWrite       = 1'b0;
         doRead        = 1'b0;

         if (axilAwValid && axilAwReady) begin
            nextAwHeld = 1'b1;
            nextAwAddr = axilAwAddr;
            if (axilAwAddr !== expectAddr) begin
               $fatal(1, "%m: Memory tag %0d unexpected AW address %08h expected %08h at edge %0d",
                      t, axilAwAddr, expectAddr, edgeCount);
            end
         end
         if (axilWValid && axilWReady) begin
            nextWHeld = 1'b1;
            nextWData = axilWData;
            nextWStrb = axilWStrb;
         end
         if (nextAwHeld && nextWHeld && !bPending) begin
            doWrite      = 1'b1;
            nextBPending = 1'b1;
            nextAwHeld   = 1'b0;
            nextWHeld    = 1'b0;
         end
         if (bPending && axilBValid && axilBReady) begin
            nextBPending = 1'b0;
         end

         if (axilArValid && axilArReady) begin
            nextRPending = 1'b1;
            nextRData    = ram[axilArAddr[7:2]];
            if (axilArAddr !== expectAddr) begin
               $fatal(1, "%m: Memory tag %0d unexpected AR address %08h expected %08h at edge %0d",
                      t, axilArAddr, expectAddr, edgeCount);
            end
         end
         if (rPending && axilRValid && axilRReady) begin
            doRead       = 1'b1;
            nextRPending = 1'b0;
         end

         if (doWrite) begin
            if (writeSeen) begin
               $fatal(1, "%m: Memory tag %0d second write observed at edge %0d", t, edgeCount);
            end
            if (nextWStrb !== 4'hF || nextWData !== expectWord) begin
               $fatal(1, "%m: Memory tag %0d write mismatch data=%08h strb=%01h expected=%08h at edge %0d",
                      t, nextWData, nextWStrb, expectWord, edgeCount);
            end
            ram[nextAwAddr[7:2]] <= nextWData;
            nextWriteSeen = 1'b1;
         end

         if (doRead) begin
            if (readSeen) begin
               $fatal(1, "%m: Memory tag %0d second read observed at edge %0d", t, edgeCount);
            end
            if (rDataReg !== expectWord) begin
               $fatal(1, "%m: Memory tag %0d read-back mismatch data=%08h expected=%08h at edge %0d",
                      t, rDataReg, expectWord, edgeCount);
            end
            nextReadSeen = 1'b1;
         end

         awHeld     <= nextAwHeld;
         wHeld      <= nextWHeld;
         bPending   <= nextBPending;
         rPending   <= nextRPending;
         heldAwAddr <= nextAwAddr;
         heldWData  <= nextWData;
         heldWStrb  <= nextWStrb;
         rDataReg   <= nextRData;
         writeSeen  <= nextWriteSeen;
         readSeen   <= nextReadSeen;
      end

      assign memoryDone[t]        = writeSeen && readSeen;
      assign memoryAnyReqValid[t] = axilArValid || axilAwValid || axilWValid;

      // Time-zero and reset-phase checks, in the RogueSvMemoryRelaunchTb.sv form.
      initial begin
         #1;
         if (axilArAddr !== 32'd0 || axilArProt !== 3'd0 || axilArValid !== 1'b0 ||
             axilRReady !== 1'b0 ||
             axilAwAddr !== 32'd0 || axilAwProt !== 3'd0 || axilAwValid !== 1'b0 ||
             axilWData !== 32'd0 || axilWStrb !== 4'd0 || axilWValid !== 1'b0 ||
             axilBReady !== 1'b0) begin
            $fatal(1, "%m: Memory tag %0d nonzero wrapper output observed at time 1", t);
         end
      end

      always @(posedge clk) begin
         if (resetCheckPulse) begin
            if (!axilRReady || !axilBReady ||
                axilArValid || axilAwValid || axilWValid) begin
               $fatal(1, "%m: Memory tag %0d reset-phase outputs incorrect at edge %0d (axilRReady=%0d axilBReady=%0d)",
                      t, edgeCount, axilRReady, axilBReady);
            end
         end
      end

   end

   // -------------------------------------------------------------------------
   // gen_sideband: two SideBand leaves. Each drives one tagged opcode pulse
   // then one tagged remote-data change toward the peer, and checks the one
   // tagged opcode pulse and remote-data value the leaf surfaces on rx*.
   // -------------------------------------------------------------------------
   for (genvar t = 0; t < SIDEBAND_COUNT_C; t++) begin : gen_sideband

      logic [7:0] txOpCode, txRemData;
      logic       txOpCodeEn;
      logic [7:0] rxOpCode, rxRemData;
      logic       rxOpCodeEn;

      wire [7:0] expectTxOpCode  = 8'(32'h60 + t);
      wire [7:0] expectTxRemData = 8'(32'h70 + t);
      wire [7:0] expectRxOpCode  = 8'(32'h20 + t);
      wire [7:0] expectRxRemData = 8'(32'h40 + t);

      RogueSideBandWrap #(
         .PORT_NUM_G (BASE_PORT_G + 2*(STREAM_COUNT_C + MEMORY_COUNT_C) + 2*t)
      ) U_SideBand (
         .sysClk     (clk),
         .sysRst     (rst),
         .txOpCode   (txOpCode),
         .txOpCodeEn (txOpCodeEn),
         .txRemData  (txRemData),
         .rxOpCode   (rxOpCode),
         .rxOpCodeEn (rxOpCodeEn),
         .rxRemData  (rxRemData)
      );

      logic txPulseDone, txSettleDone;

      initial begin
         txOpCode     = 8'h00;
         txOpCodeEn   = 1'b0;
         txRemData    = 8'h00;
         txPulseDone  = 1'b0;
         txSettleDone = 1'b0;
      end

      always @(posedge clk) begin
         if (!txPulseDone && edgeCount == (RESET_EDGES_C + SETTLE_EDGES_C)) begin
            txOpCode    <= expectTxOpCode;
            txOpCodeEn  <= 1'b1;
            txPulseDone <= 1'b1;
         end else if (txPulseDone && !txSettleDone) begin
            txOpCodeEn   <= 1'b0;
            txRemData    <= expectTxRemData;
            txSettleDone <= 1'b1;
         end else if (clearReq) begin
            txRemData <= 8'h00;
         end
      end

      logic prevRxOpCodeEn, rxPulseSeen, remDataSeen;

      initial begin
         prevRxOpCodeEn = 1'b0;
         rxPulseSeen    = 1'b0;
         remDataSeen    = 1'b0;
      end

      always @(posedge clk) begin
         if (prevRxOpCodeEn && rxOpCodeEn) begin
            $fatal(1, "%m: SideBand tag %0d rxOpCodeEn asserted on consecutive edges at edge %0d", t, edgeCount);
         end
         if (rxOpCodeEn) begin
            if (rxPulseSeen) begin
               $fatal(1, "%m: SideBand tag %0d second rxOpCodeEn pulse at edge %0d", t, edgeCount);
            end
            if (rxOpCode !== expectRxOpCode) begin
               $fatal(1, "%m: SideBand tag %0d unexpected rxOpCode %02h expected %02h at edge %0d",
                      t, rxOpCode, expectRxOpCode, edgeCount);
            end
            rxPulseSeen <= 1'b1;
         end
         if (rxRemData !== 8'h00 && rxRemData !== expectRxRemData) begin
            $fatal(1, "%m: SideBand tag %0d unexpected rxRemData %02h at edge %0d", t, rxRemData, edgeCount);
         end
         if (rxRemData === expectRxRemData) begin
            remDataSeen <= 1'b1;
         end
         prevRxOpCodeEn <= rxOpCodeEn;
      end

      assign sideBandDone[t]  = txSettleDone && rxPulseSeen && remDataSeen;
      assign sidebandRxEn[t]  = rxOpCodeEn;

      // Time-zero and reset-phase checks, in the RogueSvTrafficTb.sv form.
      initial begin
         #1;
         if (rxOpCode !== 8'd0 || rxOpCodeEn !== 1'b0 || rxRemData !== 8'd0) begin
            $fatal(1, "%m: SideBand tag %0d nonzero wrapper output observed at time 1", t);
         end
      end

      always @(posedge clk) begin
         if (resetCheckPulse) begin
            if (rxOpCodeEn) begin
               $fatal(1, "%m: SideBand tag %0d reset-phase outputs incorrect at edge %0d (rxOpCodeEn=%0d)",
                      t, edgeCount, rxOpCodeEn);
            end
         end
      end

   end

   // -------------------------------------------------------------------------
   // Watchdog and the POST-phase spurious-traffic guard. Neither message
   // uses the per-instance "Stream/Memory/SideBand tag" prefixes, so a
   // mutation that breaks isolation is distinguishable from a genuine hang
   // or a real post-reset traffic leak.
   // -------------------------------------------------------------------------
   always @(posedge clk) begin
      if (edgeCount > WAIT_EDGES_G) begin
         $fatal(1, "%m: watchdog expired at edge %0d (streamDone=%b memoryDone=%b sideBandDone=%b state=%0d)",
                edgeCount, streamDone, memoryDone, sideBandDone, seqState);
      end
   end

   always @(posedge clk) begin
      if (seqState == SEQ_POST) begin
         if (|streamMAxisValid || |memoryAnyReqValid || |sidebandRxEn) begin
            $fatal(1, "%m: spurious traffic after reset re-pulse at edge %0d (streamMAxisValid=%b memoryAnyReqValid=%b sidebandRxEn=%b)",
                   edgeCount, streamMAxisValid, memoryAnyReqValid, sidebandRxEn);
         end
      end
   end

endmodule
