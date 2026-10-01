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
// Self-driving one-leaf Memory top for the persistent-peer relaunch
// regression shared by the Icarus and Verilator runners. One run accepts
// exactly one AXI-Lite write, checks it against the +RELAUNCH_ADDR and
// +RELAUNCH_VALUE plusargs, and finishes only after the external peer's
// result file for this run exists at +RELAUNCH_RESULT, because the SimLink
// transport closes with ZMQ_LINGER 0 when this leaf's final block runs, so
// anything still queued at simulator exit would otherwise be discarded.
//////////////////////////////////////////////////////////////////////////////

module RogueSvMemoryRelaunchTb #(
   parameter int PORT_NUM_G   = 20040,
   parameter int WAIT_EDGES_G = 1000000
);

   localparam int RESET_EDGES_C = 4;
   localparam int POLL_EDGES_C  = 1000;

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
   // Runtime plusargs. Every missing plusarg is fatal before any port binds,
   // since this initial block is declared, and therefore runs, ahead of the
   // U_Memory0 instantiation below.
   // -------------------------------------------------------------------------
   string       resultPath;
   logic [31:0] expectAddr;
   logic [31:0] expectValue;

   initial begin
      if (!$value$plusargs("RELAUNCH_RESULT=%s", resultPath)) begin
         $fatal(1, "%m: missing +RELAUNCH_RESULT=<path>");
      end
      if (!$value$plusargs("RELAUNCH_ADDR=%h", expectAddr)) begin
         $fatal(1, "%m: missing +RELAUNCH_ADDR=<hex>");
      end
      if (!$value$plusargs("RELAUNCH_VALUE=%h", expectValue)) begin
         $fatal(1, "%m: missing +RELAUNCH_VALUE=<hex>");
      end
   end

   // -------------------------------------------------------------------------
   // One Memory leaf. RogueTcpMemoryWrap is the AXI-Lite master driven by the
   // peer over the wire; this top implements the AXI-Lite slave side as a
   // one-write RAM model with no throttling.
   // -------------------------------------------------------------------------
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
      .PORT_NUM_G (PORT_NUM_G)
   ) U_Memory0 (
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

   // Read address/data channel: never accepted, never valid. Any ArValid is
   // caught below as a fatal, since the peer never reads in this scenario.
   assign axilArReady = 1'b0;
   assign axilRValid  = 1'b0;
   assign axilRResp   = 2'b00;
   assign axilRData   = 32'h0;

   logic        awHeld, wHeld, bPending, writeCompleted, bDone;
   logic [31:0] capturedAwAddr, capturedWData;
   logic [3:0]  capturedWStrb;

   assign axilAwReady = !awHeld && !bPending;
   assign axilWReady  = !wHeld  && !bPending;
   assign axilBValid  = bPending;
   assign axilBResp   = 2'b00;

   initial begin
      awHeld         = 1'b0;
      wHeld          = 1'b0;
      bPending       = 1'b0;
      writeCompleted = 1'b0;
      bDone          = 1'b0;
      capturedAwAddr = 32'h0;
      capturedWData  = 32'h0;
      capturedWStrb  = 4'h0;
   end

   always @(posedge clk) begin
      logic        nextAwHeld, nextWHeld, nextBPending, nextBDone, nextWriteCompleted;
      logic [31:0] nextAwAddr, nextWData;
      logic [3:0]  nextWStrb;
      logic        doWrite;

      nextAwHeld         = awHeld;
      nextWHeld          = wHeld;
      nextBPending       = bPending;
      nextBDone          = bDone;
      nextWriteCompleted = writeCompleted;
      nextAwAddr         = capturedAwAddr;
      nextWData          = capturedWData;
      nextWStrb          = capturedWStrb;
      doWrite            = 1'b0;

      if (axilArValid) begin
         $fatal(1, "%m: unexpected AR request at edge %0d (this leaf never reads)", edgeCount);
      end

      if (axilAwValid && axilAwReady) begin
         nextAwHeld = 1'b1;
         nextAwAddr = axilAwAddr;
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
         nextBDone    = 1'b1;
      end

      if (doWrite) begin
         if (writeCompleted) begin
            $fatal(1, "%m: second write observed at edge %0d (addr=%08h value=%08h)",
                   edgeCount, nextAwAddr, nextWData);
         end
         if (nextAwAddr !== expectAddr) begin
            $fatal(1, "%m: AW address mismatch observed=%08h expected=%08h at edge %0d",
                   nextAwAddr, expectAddr, edgeCount);
         end
         if (nextWStrb !== 4'hF) begin
            $fatal(1, "%m: W strobe mismatch observed=%01h expected=f at edge %0d",
                   nextWStrb, edgeCount);
         end
         if (nextWData !== expectValue) begin
            $fatal(1, "%m: W data mismatch observed=%08h expected=%08h at edge %0d",
                   nextWData, expectValue, edgeCount);
         end
         nextWriteCompleted = 1'b1;
      end

      awHeld         <= nextAwHeld;
      wHeld          <= nextWHeld;
      bPending       <= nextBPending;
      bDone          <= nextBDone;
      writeCompleted <= nextWriteCompleted;
      capturedAwAddr <= nextAwAddr;
      capturedWData  <= nextWData;
      capturedWStrb  <= nextWStrb;
   end

   // -------------------------------------------------------------------------
   // Poll for the peer's per-run result file once the B handshake completes.
   // The transport discards anything still queued when this leaf's final
   // block runs, so this top must not exit before the peer confirms delivery.
   // -------------------------------------------------------------------------
   logic        resultSeen;
   int unsigned pollCounter;
   integer      resultFile;

   initial begin
      resultSeen  = 1'b0;
      pollCounter = 0;
   end

   always @(posedge clk) begin
      if (bDone && !resultSeen) begin
         if (pollCounter == 0) begin
            resultFile = $fopen(resultPath, "r");
            if (resultFile != 0) begin
               $fclose(resultFile);
               resultSeen <= 1'b1;
               $display("RogueSvMemoryRelaunchTb addr=%08h value=%08h edge=%0d",
                        capturedAwAddr, capturedWData, edgeCount);
               $display("RogueSvMemoryRelaunchTb passed");
               $finish;
            end
         end
         pollCounter <= (pollCounter + 1) % POLL_EDGES_C;
      end
   end

   // -------------------------------------------------------------------------
   // Time-zero and reset-phase checks, in the RogueSvTrafficTb.sv form: every
   // wrapper output reads 0 at time 1, and while reset is still asserted the
   // wrapper's own reset behavior drives axilRReady/axilBReady high with no
   // AR/AW/W valid.
   // -------------------------------------------------------------------------
   initial begin
      #1;
      if (axilArAddr !== 32'd0 || axilArProt !== 3'd0 || axilArValid !== 1'b0 ||
          axilRReady !== 1'b0 ||
          axilAwAddr !== 32'd0 || axilAwProt !== 3'd0 || axilAwValid !== 1'b0 ||
          axilWData !== 32'd0 || axilWStrb !== 4'd0 || axilWValid !== 1'b0 ||
          axilBReady !== 1'b0) begin
         $fatal(1, "%m: nonzero wrapper output observed at time 1");
      end
   end

   always @(posedge clk) begin
      if (edgeCount == 2) begin
         if (!axilRReady || !axilBReady ||
             axilArValid || axilAwValid || axilWValid) begin
            $fatal(1, "%m: reset-phase outputs incorrect at edge %0d (axilRReady=%0d axilBReady=%0d)",
                   edgeCount, axilRReady, axilBReady);
         end
      end
   end

   // -------------------------------------------------------------------------
   // Watchdog.
   // -------------------------------------------------------------------------
   always @(posedge clk) begin
      if (edgeCount > WAIT_EDGES_G) begin
         $fatal(1, "%m: watchdog expired at edge %0d (bDone=%0d resultSeen=%0d)",
                edgeCount, bDone, resultSeen);
      end
   end

endmodule
