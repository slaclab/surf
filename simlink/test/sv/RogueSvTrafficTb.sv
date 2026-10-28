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
// Self-driving SV traffic top shared by the Icarus and Verilator SimLink
// runners. Instantiates one flat wrapper per model family, drives it against
// a deterministic pyzmq peer, and self-checks the wrapper's timing and beat
// counts entirely in HDL so the Python side only has to look for one banner.
//
// Port map, fixed offsets from BASE_PORT_G (Task 2 adds the last three):
//   Stream0   BASE_PORT_G + 0  (throttled loopback)
//   Stream1   BASE_PORT_G + 2  (direct/sustained loopback)
//   Stream2   BASE_PORT_G + 4  (128-byte direct loopback)
//   Memory0   BASE_PORT_G + 6
//   SideBand0 BASE_PORT_G + 8
//////////////////////////////////////////////////////////////////////////////

module RogueSvTrafficTb #(
   parameter int BASE_PORT_G  = 19760,
   parameter int WAIT_EDGES_G = 1000000
);

   localparam int RESET_EDGES_C     = 4;
   localparam int GUARD_EDGES_C     = 2000;
   localparam int FIFO_DEPTH_C      = 4;
   localparam int STREAM_FRAMES_C   = 3;
   localparam int STREAM8_BEATS_C   = 15;
   localparam int STREAM8_MAX_RUN_C = 12;
   localparam int SETTLE_EDGES_C    = 2000;
   localparam int STREAM128_BEATS_C = 3;
   localparam int MEM_WORDS_C       = 16;

   typedef struct packed {
      logic [63:0] tData;
      logic [7:0]  tKeep;
      logic [63:0] tUser;
      logic        tLast;
   } Stream8BeatType;

   // -------------------------------------------------------------------------
   // Clock, reset, and the two independent throttle LFSRs
   // -------------------------------------------------------------------------
   logic clk;
   logic rst;
   int unsigned edgeCount;

   // 16-bit maximal-length taps (16,15,13,4), used one bit at a time as
   // pseudo-random throttle decisions.
   logic [15:0] lfsrReady;
   logic [15:0] lfsrSource;

   initial begin
      clk        = 1'b0;
      rst        = 1'b1;
      edgeCount  = 0;
      lfsrReady  = 16'hACE1;
      lfsrSource = 16'h1234;
   end

   always #5 clk = ~clk;

   always @(posedge clk) begin
      if (edgeCount == RESET_EDGES_C - 1) begin
         rst <= 1'b0;
      end
      edgeCount  <= edgeCount + 1;
      lfsrReady  <= {lfsrReady[14:0],  lfsrReady[15]  ^ lfsrReady[14]  ^ lfsrReady[12]  ^ lfsrReady[3]};
      lfsrSource <= {lfsrSource[14:0], lfsrSource[15] ^ lfsrSource[14] ^ lfsrSource[12] ^ lfsrSource[3]};
   end

   // -------------------------------------------------------------------------
   // Stream0: throttled loopback through a 4-entry TB FIFO. mAxisTReady is
   // throttled by lfsrReady; the sAxis source only loads a new beat on edges
   // where lfsrSource permits it, so both directions see random gaps.
   // -------------------------------------------------------------------------
   logic        sAxisTReady0, mAxisTValid0, mAxisTLast0;
   logic [63:0] mAxisTData0, mAxisTUser0;
   logic [7:0]  mAxisTKeep0;
   logic        mAxisTReady0;

   Stream8BeatType fifo0Mem [FIFO_DEPTH_C];
   logic [1:0]     fifo0Head, fifo0Tail;
   int unsigned    fifo0Count;
   logic           fifo0Empty;
   assign fifo0Empty = (fifo0Count == 0);
   assign mAxisTReady0 = (fifo0Count < FIFO_DEPTH_C) && lfsrReady[0];

   logic           stream0SrcValid;
   Stream8BeatType stream0SrcBeat;
   logic           stream0Accepted;
   assign stream0Accepted = stream0SrcValid && sAxisTReady0;

   logic stream0Push, stream0Pop;
   assign stream0Push = mAxisTValid0 && mAxisTReady0;
   assign stream0Pop  = (!stream0SrcValid || stream0Accepted) && !fifo0Empty && lfsrSource[0];

   initial begin
      fifo0Head       = 2'd0;
      fifo0Tail       = 2'd0;
      fifo0Count      = 0;
      stream0SrcValid = 1'b0;
   end

   always @(posedge clk) begin
      if (stream0Push) begin
         fifo0Mem[fifo0Tail] <= {mAxisTData0, mAxisTKeep0, mAxisTUser0, mAxisTLast0};
         fifo0Tail           <= fifo0Tail + 2'd1;
      end
      if (stream0Pop) begin
         stream0SrcBeat  <= fifo0Mem[fifo0Head];
         stream0SrcValid <= 1'b1;
         fifo0Head       <= fifo0Head + 2'd1;
      end else if (!stream0SrcValid || stream0Accepted) begin
         stream0SrcValid <= 1'b0;
      end
      case ({stream0Push, stream0Pop})
         2'b10:   fifo0Count <= fifo0Count + 1;
         2'b01:   fifo0Count <= fifo0Count - 1;
         default: fifo0Count <= fifo0Count;
      endcase
   end

   RogueTcpStreamWrap #(
      .PORT_NUM_G    (BASE_PORT_G + 0),
      .SSI_EN_G      (1'b1),
      .TDATA_BYTES_G (8)
   ) U_Stream0 (
      .axisClk     (clk),
      .axisRst     (rst),
      .sAxisTValid (stream0SrcValid),
      .sAxisTData  (stream0SrcBeat.tData),
      .sAxisTKeep  (stream0SrcBeat.tKeep),
      .sAxisTUser  (stream0SrcBeat.tUser),
      .sAxisTLast  (stream0SrcBeat.tLast),
      .sAxisTReady (sAxisTReady0),
      .mAxisTValid (mAxisTValid0),
      .mAxisTData  (mAxisTData0),
      .mAxisTKeep  (mAxisTKeep0),
      .mAxisTUser  (mAxisTUser0),
      .mAxisTLast  (mAxisTLast0),
      .mAxisTReady (mAxisTReady0)
   );

   // Stalled-beat stability check: a beat presented while not ready must be
   // held byte-identical on the very next edge.
   logic           stream0PrevValid, stream0PrevReady;
   Stream8BeatType stream0PrevBeat;

   initial begin
      stream0PrevValid = 1'b0;
      stream0PrevReady = 1'b0;
   end

   always @(posedge clk) begin
      if (stream0PrevValid && !stream0PrevReady) begin
         if (!mAxisTValid0 ||
             mAxisTData0 !== stream0PrevBeat.tData ||
             mAxisTKeep0 !== stream0PrevBeat.tKeep ||
             mAxisTUser0 !== stream0PrevBeat.tUser ||
             mAxisTLast0 !== stream0PrevBeat.tLast) begin
            $fatal(1, "%m: Stream0 stalled mAxis beat changed while not ready at edge %0d", edgeCount);
         end
      end
      stream0PrevValid <= mAxisTValid0;
      stream0PrevReady <= mAxisTReady0;
      stream0PrevBeat  <= {mAxisTData0, mAxisTKeep0, mAxisTUser0, mAxisTLast0};
   end

   // Beat/frame counters plus the completion assertion (beat counts equal
   // STREAM8_BEATS_C and both throttle counters are non-zero).
   int unsigned stream0MAxisBeats, stream0MAxisLastBeats;
   int unsigned stream0SAxisBeats, stream0SAxisLastBeats;
   int unsigned stream0StallCount, stream0GapCount;
   logic        stream0Done;

   initial begin
      stream0MAxisBeats     = 0;
      stream0MAxisLastBeats = 0;
      stream0SAxisBeats     = 0;
      stream0SAxisLastBeats = 0;
      stream0StallCount     = 0;
      stream0GapCount       = 0;
      stream0Done           = 1'b0;
   end

   always @(posedge clk) begin
      int unsigned nextMAxisBeats, nextMAxisLastBeats;
      int unsigned nextSAxisBeats, nextSAxisLastBeats;
      int unsigned nextStallCount, nextGapCount;

      nextMAxisBeats     = stream0MAxisBeats;
      nextMAxisLastBeats = stream0MAxisLastBeats;
      nextSAxisBeats     = stream0SAxisBeats;
      nextSAxisLastBeats = stream0SAxisLastBeats;
      nextStallCount     = stream0StallCount;
      nextGapCount       = stream0GapCount;

      if (mAxisTValid0 && mAxisTReady0) begin
         nextMAxisBeats = nextMAxisBeats + 1;
         if (mAxisTLast0) nextMAxisLastBeats = nextMAxisLastBeats + 1;
      end
      if (stream0SrcValid && sAxisTReady0) begin
         nextSAxisBeats = nextSAxisBeats + 1;
         if (stream0SrcBeat.tLast) nextSAxisLastBeats = nextSAxisLastBeats + 1;
      end
      if (mAxisTValid0 && !mAxisTReady0) begin
         nextStallCount = nextStallCount + 1;
      end
      if (!fifo0Empty && !stream0SrcValid) begin
         nextGapCount = nextGapCount + 1;
      end

      stream0MAxisBeats     <= nextMAxisBeats;
      stream0MAxisLastBeats <= nextMAxisLastBeats;
      stream0SAxisBeats     <= nextSAxisBeats;
      stream0SAxisLastBeats <= nextSAxisLastBeats;
      stream0StallCount     <= nextStallCount;
      stream0GapCount       <= nextGapCount;

      if (!stream0Done && nextMAxisLastBeats >= STREAM_FRAMES_C && nextSAxisLastBeats >= STREAM_FRAMES_C) begin
         if (nextMAxisBeats != STREAM8_BEATS_C || nextSAxisBeats != STREAM8_BEATS_C) begin
            $fatal(1, "%m: Stream0 beat count mismatch at completion (mAxis=%0d sAxis=%0d expected=%0d)",
                   nextMAxisBeats, nextSAxisBeats, STREAM8_BEATS_C);
         end
         if (nextStallCount == 0 || nextGapCount == 0) begin
            $fatal(1, "%m: Stream0 stall/gap counters unexercised (stall=%0d gap=%0d)",
                   nextStallCount, nextGapCount);
         end
         stream0Done <= 1'b1;
      end
   end

   // -------------------------------------------------------------------------
   // Stream1: direct/sustained loopback (no FIFO, no throttling).
   // -------------------------------------------------------------------------
   logic        sAxisTValid1, sAxisTLast1, sAxisTReady1;
   logic [63:0] sAxisTData1, sAxisTUser1;
   logic [7:0]  sAxisTKeep1;
   logic        mAxisTValid1, mAxisTLast1, mAxisTReady1;
   logic [63:0] mAxisTData1, mAxisTUser1;
   logic [7:0]  mAxisTKeep1;

   assign sAxisTValid1 = mAxisTValid1;
   assign sAxisTData1  = mAxisTData1;
   assign sAxisTKeep1  = mAxisTKeep1;
   assign sAxisTUser1  = mAxisTUser1;
   assign sAxisTLast1  = mAxisTLast1;
   assign mAxisTReady1 = sAxisTReady1;

   RogueTcpStreamWrap #(
      .PORT_NUM_G    (BASE_PORT_G + 2),
      .SSI_EN_G      (1'b1),
      .TDATA_BYTES_G (8)
   ) U_Stream1 (
      .axisClk     (clk),
      .axisRst     (rst),
      .sAxisTValid (sAxisTValid1),
      .sAxisTData  (sAxisTData1),
      .sAxisTKeep  (sAxisTKeep1),
      .sAxisTUser  (sAxisTUser1),
      .sAxisTLast  (sAxisTLast1),
      .sAxisTReady (sAxisTReady1),
      .mAxisTValid (mAxisTValid1),
      .mAxisTData  (mAxisTData1),
      .mAxisTKeep  (mAxisTKeep1),
      .mAxisTUser  (mAxisTUser1),
      .mAxisTLast  (mAxisTLast1),
      .mAxisTReady (mAxisTReady1)
   );

   always @(posedge clk) begin
      if (edgeCount > (RESET_EDGES_C + 1) && !sAxisTReady1) begin
         $fatal(1, "%m: Stream1 sAxisTReady dropped after reset at edge %0d", edgeCount);
      end
   end

   logic        stream1InFrame, stream1ExpectFirst;
   int unsigned stream1RunLen, stream1MaxRun;
   int unsigned stream1MAxisBeats, stream1MAxisLastBeats;
   logic        stream1Done;

   initial begin
      stream1InFrame        = 1'b0;
      stream1ExpectFirst    = 1'b1;
      stream1RunLen         = 0;
      stream1MaxRun         = 0;
      stream1MAxisBeats     = 0;
      stream1MAxisLastBeats = 0;
      stream1Done           = 1'b0;
   end

   always @(posedge clk) begin
      logic        nextInFrame, nextExpectFirst;
      int unsigned nextRunLen, nextMaxRun;
      int unsigned nextBeats, nextLastBeats;
      logic        accepted;

      accepted = mAxisTValid1 && mAxisTReady1;

      nextInFrame     = stream1InFrame;
      nextExpectFirst = stream1ExpectFirst;
      nextRunLen      = stream1RunLen;
      nextMaxRun      = stream1MaxRun;
      nextBeats       = stream1MAxisBeats;
      nextLastBeats   = stream1MAxisLastBeats;

      if (stream1InFrame && !mAxisTValid1) begin
         $fatal(1, "%m: Stream1 bubble mid-frame at edge %0d", edgeCount);
      end

      if (accepted) begin
         if (stream1ExpectFirst) begin
            if (!mAxisTUser1[1]) $fatal(1, "%m: Stream1 missing SOF on first beat at edge %0d", edgeCount);
         end else begin
            if (mAxisTUser1[1]) $fatal(1, "%m: Stream1 unexpected SOF on non-first beat at edge %0d", edgeCount);
         end
         nextExpectFirst = mAxisTLast1;
         nextInFrame      = !mAxisTLast1;

         nextRunLen = stream1RunLen + 1;
         if (nextRunLen > stream1MaxRun) nextMaxRun = nextRunLen;

         nextBeats = stream1MAxisBeats + 1;
         if (mAxisTLast1) nextLastBeats = stream1MAxisLastBeats + 1;
      end else begin
         nextRunLen = 0;
      end

      stream1InFrame        <= nextInFrame;
      stream1ExpectFirst    <= nextExpectFirst;
      stream1RunLen         <= nextRunLen;
      stream1MaxRun         <= nextMaxRun;
      stream1MAxisBeats     <= nextBeats;
      stream1MAxisLastBeats <= nextLastBeats;

      if (!stream1Done && nextLastBeats >= STREAM_FRAMES_C) begin
         if (nextBeats != STREAM8_BEATS_C) begin
            $fatal(1, "%m: Stream1 beat count mismatch at completion (beats=%0d expected=%0d)",
                   nextBeats, STREAM8_BEATS_C);
         end
         if (nextMaxRun < STREAM8_MAX_RUN_C) begin
            $fatal(1, "%m: Stream1 longest run %0d below required %0d", nextMaxRun, STREAM8_MAX_RUN_C);
         end
         stream1Done <= 1'b1;
      end
   end

   // -------------------------------------------------------------------------
   // Stream2: 128-byte direct/sustained loopback (no FIFO, no throttling).
   // -------------------------------------------------------------------------
   logic          sAxisTValid2, sAxisTLast2, sAxisTReady2;
   logic [1023:0] sAxisTData2, sAxisTUser2;
   logic [127:0]  sAxisTKeep2;
   logic          mAxisTValid2, mAxisTLast2, mAxisTReady2;
   logic [1023:0] mAxisTData2, mAxisTUser2;
   logic [127:0]  mAxisTKeep2;

   assign sAxisTValid2 = mAxisTValid2;
   assign sAxisTData2  = mAxisTData2;
   assign sAxisTKeep2  = mAxisTKeep2;
   assign sAxisTUser2  = mAxisTUser2;
   assign sAxisTLast2  = mAxisTLast2;
   assign mAxisTReady2 = sAxisTReady2;

   RogueTcpStreamWrap #(
      .PORT_NUM_G    (BASE_PORT_G + 4),
      .SSI_EN_G      (1'b1),
      .TDATA_BYTES_G (128)
   ) U_Stream2 (
      .axisClk     (clk),
      .axisRst     (rst),
      .sAxisTValid (sAxisTValid2),
      .sAxisTData  (sAxisTData2),
      .sAxisTKeep  (sAxisTKeep2),
      .sAxisTUser  (sAxisTUser2),
      .sAxisTLast  (sAxisTLast2),
      .sAxisTReady (sAxisTReady2),
      .mAxisTValid (mAxisTValid2),
      .mAxisTData  (mAxisTData2),
      .mAxisTKeep  (mAxisTKeep2),
      .mAxisTUser  (mAxisTUser2),
      .mAxisTLast  (mAxisTLast2),
      .mAxisTReady (mAxisTReady2)
   );

   int unsigned stream2MAxisBeats, stream2MAxisLastBeats;
   logic        stream2Done;

   initial begin
      stream2MAxisBeats     = 0;
      stream2MAxisLastBeats = 0;
      stream2Done           = 1'b0;
   end

   always @(posedge clk) begin
      int unsigned nextBeats, nextLastBeats;

      nextBeats     = stream2MAxisBeats;
      nextLastBeats = stream2MAxisLastBeats;

      if (mAxisTValid2 && mAxisTReady2) begin
         nextBeats = nextBeats + 1;
         if (mAxisTLast2) nextLastBeats = nextLastBeats + 1;
      end

      stream2MAxisBeats     <= nextBeats;
      stream2MAxisLastBeats <= nextLastBeats;

      if (!stream2Done && nextLastBeats >= STREAM_FRAMES_C) begin
         if (nextBeats != STREAM128_BEATS_C) begin
            $fatal(1, "%m: Stream2 beat count mismatch at completion (beats=%0d expected=%0d)",
                   nextBeats, STREAM128_BEATS_C);
         end
         stream2Done <= 1'b1;
      end
   end

   // -------------------------------------------------------------------------
   // Memory0: AXI-Lite RAM slave (16 32-bit words) with random ready
   // throttling on AR/AW/W and held B/R responses.
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
      .PORT_NUM_G (BASE_PORT_G + 6)
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

   assign axilAwReadyMem0 = !mem0AwHeld && !mem0BPending && lfsrReady[1];
   assign axilWReadyMem0  = !mem0WHeld  && !mem0BPending && lfsrSource[1];
   assign axilBValidMem0  = mem0BPending;
   assign axilBRespMem0   = 2'b00;
   assign axilArReadyMem0 = !mem0RPending && lfsrReady[2];
   assign axilRValidMem0  = mem0RPending;
   assign axilRRespMem0   = 2'b00;
   assign axilRDataMem0   = mem0RData;

   int unsigned mem0BCount, mem0RCount, mem0StallCount;
   logic        mem0Done;

   // Stalled-request stability checks (AR/AW/W).
   logic        mem0ArPrevValid, mem0ArPrevReady;
   logic [31:0] mem0ArPrevAddr;
   logic        mem0AwPrevValid, mem0AwPrevReady;
   logic [31:0] mem0AwPrevAddr;
   logic        mem0WPrevValid, mem0WPrevReady;
   logic [31:0] mem0WPrevData;
   logic [3:0]  mem0WPrevStrb;

   initial begin
      for (int i = 0; i < MEM_WORDS_C; i++) mem0Ram[i] = 32'h0;
      mem0AwHeld      = 1'b0;
      mem0WHeld       = 1'b0;
      mem0BPending    = 1'b0;
      mem0RPending    = 1'b0;
      mem0BCount      = 0;
      mem0RCount      = 0;
      mem0StallCount  = 0;
      mem0Done        = 1'b0;
      mem0ArPrevValid = 1'b0;
      mem0ArPrevReady = 1'b0;
      mem0AwPrevValid = 1'b0;
      mem0AwPrevReady = 1'b0;
      mem0WPrevValid  = 1'b0;
      mem0WPrevReady  = 1'b0;
   end

   always @(posedge clk) begin
      logic        nextAwHeld, nextWHeld, nextBPending, nextRPending;
      logic [31:0] nextAwAddr, nextWData, nextRData;
      logic [3:0]  nextWStrb;
      int unsigned nextBCount, nextRCount, nextStallCount;
      logic        doWrite;

      nextAwHeld     = mem0AwHeld;
      nextWHeld      = mem0WHeld;
      nextBPending   = mem0BPending;
      nextRPending   = mem0RPending;
      nextAwAddr     = mem0AwAddr;
      nextWData      = mem0WData;
      nextWStrb      = mem0WStrb;
      nextRData      = mem0RData;
      nextBCount     = mem0BCount;
      nextRCount     = mem0RCount;
      nextStallCount = mem0StallCount;
      doWrite        = 1'b0;

      if (mem0ArPrevValid && !mem0ArPrevReady &&
          (!axilArValidMem0 || axilArAddrMem0 !== mem0ArPrevAddr)) begin
         $fatal(1, "%m: Memory0 AR changed while stalled at edge %0d", edgeCount);
      end
      if (mem0AwPrevValid && !mem0AwPrevReady &&
          (!axilAwValidMem0 || axilAwAddrMem0 !== mem0AwPrevAddr)) begin
         $fatal(1, "%m: Memory0 AW changed while stalled at edge %0d", edgeCount);
      end
      if (mem0WPrevValid && !mem0WPrevReady &&
          (!axilWValidMem0 || axilWDataMem0 !== mem0WPrevData || axilWStrbMem0 !== mem0WPrevStrb)) begin
         $fatal(1, "%m: Memory0 W changed while stalled at edge %0d", edgeCount);
      end
      if ((axilArValidMem0 && !axilArReadyMem0) ||
          (axilAwValidMem0 && !axilAwReadyMem0) ||
          (axilWValidMem0  && !axilWReadyMem0)) begin
         nextStallCount = nextStallCount + 1;
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
         nextBCount   = nextBCount + 1;
      end

      if (axilArValidMem0 && axilArReadyMem0) begin
         nextRPending = 1'b1;
         nextRData    = mem0Ram[axilArAddrMem0[5:2]];
      end
      if (mem0RPending && axilRValidMem0 && axilRReadyMem0) begin
         nextRPending = 1'b0;
         nextRCount   = nextRCount + 1;
      end

      if (doWrite) begin
         if (nextWStrb[0]) mem0Ram[nextAwAddr[5:2]][7:0]   <= nextWData[7:0];
         if (nextWStrb[1]) mem0Ram[nextAwAddr[5:2]][15:8]  <= nextWData[15:8];
         if (nextWStrb[2]) mem0Ram[nextAwAddr[5:2]][23:16] <= nextWData[23:16];
         if (nextWStrb[3]) mem0Ram[nextAwAddr[5:2]][31:24] <= nextWData[31:24];
      end

      mem0AwHeld     <= nextAwHeld;
      mem0WHeld      <= nextWHeld;
      mem0BPending   <= nextBPending;
      mem0RPending   <= nextRPending;
      mem0AwAddr     <= nextAwAddr;
      mem0WData      <= nextWData;
      mem0WStrb      <= nextWStrb;
      mem0RData      <= nextRData;
      mem0BCount     <= nextBCount;
      mem0RCount     <= nextRCount;
      mem0StallCount <= nextStallCount;

      mem0ArPrevValid <= axilArValidMem0;
      mem0ArPrevReady <= axilArReadyMem0;
      mem0ArPrevAddr  <= axilArAddrMem0;
      mem0AwPrevValid <= axilAwValidMem0;
      mem0AwPrevReady <= axilAwReadyMem0;
      mem0AwPrevAddr  <= axilAwAddrMem0;
      mem0WPrevValid  <= axilWValidMem0;
      mem0WPrevReady  <= axilWReadyMem0;
      mem0WPrevData   <= axilWDataMem0;
      mem0WPrevStrb   <= axilWStrbMem0;

      if (!mem0Done && nextBCount >= 2 && nextRCount >= 2) begin
         if (nextStallCount == 0) begin
            $fatal(1, "%m: Memory0 stall counter unexercised");
         end
         mem0Done <= 1'b1;
      end
   end

   // -------------------------------------------------------------------------
   // SideBand0: drives a one-cycle opcode pulse plus a remote-data change
   // toward the peer, and checks the peer-originated opcode pulse/remote-data
   // value the leaf surfaces on rx*.
   // -------------------------------------------------------------------------
   logic [7:0] txOpCodeSb0, txRemDataSb0;
   logic       txOpCodeEnSb0;
   logic [7:0] rxOpCodeSb0, rxRemDataSb0;
   logic       rxOpCodeEnSb0;

   RogueSideBandWrap #(
      .PORT_NUM_G (BASE_PORT_G + 8)
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

   logic sb0TxPulseDone, sb0TxSettleDone;
   int unsigned sb0RxPulseCount;
   logic        sb0RemDataSeen, sb0PrevRxOpCodeEn, sb0Done;

   initial begin
      txOpCodeSb0       = 8'h00;
      txOpCodeEnSb0     = 1'b0;
      txRemDataSb0      = 8'h00;
      sb0TxPulseDone    = 1'b0;
      sb0TxSettleDone   = 1'b0;
      sb0RxPulseCount   = 0;
      sb0RemDataSeen    = 1'b0;
      sb0PrevRxOpCodeEn = 1'b0;
      sb0Done           = 1'b0;
   end

   // Drive the tx pulse plus the remote-data change SETTLE_EDGES_C edges
   // after reset release.
   always @(posedge clk) begin
      if (!sb0TxPulseDone && edgeCount == (RESET_EDGES_C + SETTLE_EDGES_C)) begin
         txOpCodeSb0    <= 8'h5A;
         txOpCodeEnSb0  <= 1'b1;
         sb0TxPulseDone <= 1'b1;
      end else if (sb0TxPulseDone && !sb0TxSettleDone) begin
         txOpCodeEnSb0   <= 1'b0;
         txRemDataSb0    <= 8'hC3;
         sb0TxSettleDone <= 1'b1;
      end
   end

   always @(posedge clk) begin
      if (sb0PrevRxOpCodeEn && rxOpCodeEnSb0) begin
         $fatal(1, "%m: SideBand0 rxOpCodeEn asserted on consecutive edges at edge %0d", edgeCount);
      end
      if (rxOpCodeEnSb0) begin
         if (rxOpCodeSb0 != 8'hA5) begin
            $fatal(1, "%m: SideBand0 unexpected rxOpCode 0x%0h at edge %0d", rxOpCodeSb0, edgeCount);
         end
         sb0RxPulseCount <= sb0RxPulseCount + 1;
      end
      if (rxRemDataSb0 == 8'h3C) begin
         sb0RemDataSeen <= 1'b1;
      end
      sb0PrevRxOpCodeEn <= rxOpCodeEnSb0;

      if (!sb0Done && sb0TxSettleDone && sb0RxPulseCount == 1 && sb0RemDataSeen) begin
         sb0Done <= 1'b1;
      end
   end

   // -------------------------------------------------------------------------
   // Time-zero and reset-phase checks: every wrapper output is 0
   // before the first rising edge, and the model's reset outputs
   // (sAxisTReady=1, mAxisTValid=0, axilRReady=1, axilBReady=1, rxOpCodeEn=0)
   // are visible while reset is still asserted.
   // -------------------------------------------------------------------------
   initial begin
      #1;
      if (mAxisTValid0 !== 1'b0 || sAxisTReady0 !== 1'b0 ||
          mAxisTData0 !== 64'd0  || mAxisTKeep0 !== 8'd0 || mAxisTUser0 !== 64'd0 || mAxisTLast0 !== 1'b0 ||
          mAxisTValid1 !== 1'b0 || sAxisTReady1 !== 1'b0 ||
          mAxisTData1 !== 64'd0  || mAxisTKeep1 !== 8'd0 || mAxisTUser1 !== 64'd0 || mAxisTLast1 !== 1'b0 ||
          mAxisTValid2 !== 1'b0 || sAxisTReady2 !== 1'b0 ||
          mAxisTData2 !== 1024'd0 || mAxisTKeep2 !== 128'd0 || mAxisTUser2 !== 1024'd0 || mAxisTLast2 !== 1'b0 ||
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
         if (!sAxisTReady0 || !sAxisTReady1 || mAxisTValid0 || mAxisTValid1 ||
             !sAxisTReady2 || mAxisTValid2 ||
             !axilRReadyMem0 || !axilBReadyMem0 ||
             axilArValidMem0 || axilAwValidMem0 || axilWValidMem0 ||
             rxOpCodeEnSb0) begin
            $fatal(1, "%m: reset-phase outputs incorrect at edge %0d (sAxisTReady0=%0d sAxisTReady1=%0d sAxisTReady2=%0d mAxisTValid0=%0d mAxisTValid1=%0d mAxisTValid2=%0d axilRReadyMem0=%0d axilBReadyMem0=%0d)",
                   edgeCount, sAxisTReady0, sAxisTReady1, sAxisTReady2, mAxisTValid0, mAxisTValid1, mAxisTValid2,
                   axilRReadyMem0, axilBReadyMem0);
         end
      end
   end

   // -------------------------------------------------------------------------
   // Watchdog, completion, and banner.
   // -------------------------------------------------------------------------
   always @(posedge clk) begin
      if (edgeCount > WAIT_EDGES_G) begin
         $fatal(1, "%m: watchdog expired at edge %0d (stream0Done=%0d stream1Done=%0d stream2Done=%0d mem0Done=%0d sb0Done=%0d)",
                edgeCount, stream0Done, stream1Done, stream2Done, mem0Done, sb0Done);
      end
   end

   logic        allDone, guardArmed;
   int unsigned doneEdge;
   assign allDone = stream0Done && stream1Done && stream2Done && mem0Done && sb0Done;

   initial begin
      guardArmed = 1'b0;
      doneEdge   = 0;
   end

   always @(posedge clk) begin
      if (allDone && !guardArmed) begin
         guardArmed <= 1'b1;
         doneEdge   <= edgeCount;
      end
      if (guardArmed && (edgeCount >= (doneEdge + GUARD_EDGES_C))) begin
         $display("%m: completion edge %0d, Stream0 stall=%0d gap=%0d, Stream1 longest run=%0d",
                   edgeCount, stream0StallCount, stream0GapCount, stream1MaxRun);
         $display("RogueSvTrafficTb passed");
         $finish;
      end
   end

endmodule
