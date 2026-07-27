-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   A dataflow pipeline (NOT a classic state-enum FSM).  Accepts a PayloadConReq
--   (the server request), counts its fragments, pulls the matching number of
--   payload fragments out of a BRAM buffer (via child ConnectPipeOut2BramQConAndGen),
--   and per request either DISCARDs the payload, emits a dummy ATOMIC response, or
--   DMA-WRITEs the payload — issuing one DmaWriteReq to the external
--   dmaWriteCntrl.srvPort and, on the last fragment, generating a PayloadConResp
--   from the DMA write response.
--
--   Pipeline stages (each a BSV rule, gated by FIFO occupancy + mode):
--     R1 recvReq       — decode the request, classify tag, enq U_CountReqFragQ.
--     R2 countReqFrag  — the ONLY sequential control state: a per-request fragment
--                        down-counter (sub-FSM A); emits one U_PendingConReqQ entry
--                        per fragment (holds the U_CountReqFragQ head until the last
--                        fragment for non-discard requests).
--     R3 consumePayload— per tag: Discard (drain payload frags), Atomic (enq resp +
--                        dma token, no payload read), SendWrite (read payload frag,
--                        enq dma token, enq resp on last frag).
--     R4 issueDmaReq   — Put one DmaWriteReq to dmaWriteSrv (SendWrite: payload;
--                        Atomic: synthesised atomic dataStream; Discard: no put).
--     R5 genConResp    — get the DmaWriteResp, build the PayloadConResp, enq it.
--     R6 flushDmaWriteResp / R7 flushPipelineQ / R8 flushPayloadConResp — error-mode
--                        drains (see Clear / error-flush below).
--     R9 errDrainPayload — error-mode payload sink (BUGFIX 2026-07-16, no BSV
--                        counterpart): while isErr, deq payloadPipeIn every
--                        cycle it offers a fragment and drop it (the child is
--                        masked off).  Without it an erred QP stops sinking
--                        payload (bufRst holds U_PayloadBufQ in reset, so the
--                        child never deqs) and the SHARED InputRdmaPktBuf
--                        jams head-of-line, freezing ingress for every QP.
--
--   Mode inputs (cntrlStatus.comm; one-hot, NOT state):
--     isReset  guards R0 (clear all); isNonErr guards R1-R5; isErr guards R1-R3,R6-R8.
--     In isNonErr: R1-R5 active, flushes idle.  In isErr: R1-R3 + R6-R8 active,
--     R4/R5 idle.
--
--   The ONLY sequential state (sub-FSM A counter, rule countReqFrag):
--     isFirstOrOnlyFragReg      : sl  reset '1'  (FRAG_FIRST_S / FRAG_REST_S bit)
--     isRemainingFragNumZeroReg : sl  reset '0'  (countdown-reached-zero flag)
--     remainingFragNumReg       : slv(7:0)  mkRegU, NO RESET (only meaningful in
--                                 FRAG_REST_S; written before read).  REG_INIT_C
--                                 gives it 0 only to constrain the constant.
--   countReqFrag enqueues the CURRENT (pre-update) isFirstOrOnlyFragReg into
--   U_PendingConReqQ, then updates the regs — so the comb uses r.isFirstOrOnlyFragReg
--   for the din and writes v.* for the next value (standard two-process).
--
--   Clear / error-flush (fsm.md §Clear mapping, §Conflicts):
--     R0 resetAndClear (isReset): clear ALL 7 FIFOs + child skid (clearEnI); force
--       the two reset-valued counter regs.
--     R7 flushPipelineQ (isErr): clear U_PayloadBufQ, U_PendingConReqQ, U_PendingDmaReqQ.
--     R8 flushPayloadConResp (isErr): clear U_PayloadConRespQ.
--   These map to per-FIFO synchronous resets OR'd with the structural rst:
--     <fifo>Rst = rst OR isReset [OR isErr for the R7/R8 targets].
--   BSV mkFIFOF.clear is sequenced-BEFORE enq/deq, so in an error cycle the flush
--   DOMINATES any concurrent R3 enq (drain wins).  Asserting the FIFO rst (level)
--   nullifies the same-cycle wr_en, reproducing that ordering structurally — no
--   extra wr_en gating needed (the cleared queues read empty, so the dependent
--   rules see notEmpty='0' and take no effect).  Requires GEN_SYNC_FIFO_G=true,
--   RST_ASYNC_G=false, RST_POLARITY_G='1'.
--
--   Boundaries:
--     * Server to its caller (srvPort: request Put PayloadConReq via U_PayloadConReqQ;
--       response Get PayloadConResp via U_PayloadConRespQ).
--     * Client of the external Server dmaWriteSrv (= dmaWriteCntrl.srvPort): request
--       Put DmaWriteReq (R4); response Get DmaWriteResp (R5 / R6).
--     * payloadPipeIn (DataStreamPipeOut input) → child → U_PayloadBufQ (parent-owned
--       BRAM buffer) → child pipeOut → FSM (R3).
--
--   Output style (fsm.md §Moore vs Mealy): the counter regs are registered (Moore);
--   all inter-stage handoff is via registered SURF FIFOs; FIFO din/wrEn/rdEn and the
--   dmaWriteSrv request/response handshakes are combinational from v/r (Mealy w.r.t.
--   the FIFO write port — standard SURF two-process).  No combinational path exists
--   between server request and response (always >=1 FIFO of latency).  R4's
--   dmaWriteReqValid is asserted INDEPENDENT of dmaWriteReqReady (AXI-Stream master
--   rule); the dequeue is gated by valid AND ready (Stage-5 TC-06 fix, see R4).
--
--   Open-question carry-forwards (out/04-vhdl/OPEN_QUESTIONS.md, fsm.md §Open issues):
--     OQ-FSM-PCCAG-01 / OQ-RHSQ-03 — RESOLVED (DEVIATION-PCCAG-01, Rq Stage-5
--       integration TC-09).  PayloadConInfo tagged-union intra-member alignment:
--       BSV deriving(Bits) LSB-justifies (zero-extends) narrower members.  Only the
--       193b AtomicRespInfoAndPayload struct has its DmaWriteMetaData MSB-aligned at
--       consumeInfo[192:64] (atomicRespPayload at [63:0]); the 129b members
--       SendWriteReqReadRespInfo and DiscardPayloadInfo sit at consumeInfo[128:0].
--       The original emit assumed a uniform [192:64] slice (per the OQ-RHSQ-03
--       producer note) — WRONG for SendWrite/Discard, corrupting the DmaWriteReq
--       metadata and PayloadConResp.psn (caught by WorkCompGenRq's PSN assert).
--       R4/R5 now select the metaData slice by tag (tag="01" Atomic → [192:64],
--       else → [128:0]), matching the ReqHandleRq producer's LSB-aligned packing.
--     OQ-EMIT-PCCAG-02 (new) — the fsm.md R4-Atomic note "byteEn=genByteEn(8)=
--       byteEn[7:0]='1'" is INCORRECT.  genByteEn(n)=reverseBits((1<<n)-1) (Utils.bsv:
--       161-163), so genByteEn(8) over the 32b ByteEn = reverseBits(0x000000FF) =
--       0xFF000000 (TOP 8 bytes valid), which matches zeroExtendLSB placing the 64b
--       atomic payload at the data MSBs.  Emitted per the BSV source, not the note.
--
--   Bit layouts (BSV deriving(Bits), first field -> MSB; tagged-union tag at MSB;
--   fsm.md §Type widths / OQ-FSM-H2DS-04):
--
--   DataStream (290b):
--     [289:34] data(256)  [33:2] byteEn(32)  [1] isFirst  [0] isLast
--   DmaWriteMetaData (129b):
--     [128:125] initiator(4)  [124:101] sqpn(24)  [100:37] startAddr(64)
--     [36:24] len(13)  [23:0] psn(24)
--   DmaWriteReq (419b) — dmaWriteReqData:
--     [418:290] metaData(129)  [289:0] dataStream(290)
--   DmaWriteResp (53b) — dmaWriteRespData / PayloadConResp:
--     [52:49] initiator(4)  [48:25] sqpn(24)  [24:1] psn(24)  [0] isRespErr
--   PayloadConInfo (195b): [194:193] tag (Discard=0,Atomic=1,SendWrite=2),
--     [192:0] member data, LSB-justified per BSV deriving(Bits):
--       tag=01 (Atomic, 193b struct): DmaWriteMetaData at [192:64],
--                                     atomicRespPayload(64) at [63:0];
--       tag=00/10 (Discard/SendWrite, 129b): DmaWriteMetaData at [128:0].
--   PayloadConReq (203b): [202:195] fragNum(8)  [194:0] consumeInfo(195)
--   PayloadConResp (53b): DmaWriteResp(53)
--   Tuple3 countReqFragQ (205b): [204:2] consumeReq(203) [1] isFragNumLessOrEqOne [0] isDiscardReq
--   Tuple4 pendingConReqQ (206b): [205:3] consumeReq(203) [2] isFragNumLessOrEqOne
--     [1] isFirstOrOnlyFrag  [0] isLastReqFrag
--   Tuple2 pendingDmaReqQ (493b): [492:290] consumeReq(203)  [289:0] payload(DataStream)
--
--   Helpers (PrimUtils.bsv:30-55, Utils.bsv:161-163; ATOMIC_WORK_REQ_LEN=8):
--     isLessOrEqOne(b) = (b(7:1)=0);  isTwo(b)=(b(7:2)=0 and b(1) and not b(0));
--     isOne(b)=(b(7:1)=0 and b(0));   genByteEn(8)=0xFF000000;
--     zeroExtendLSB(p64)= p64 & 0(192) into the 256b data field.
--
--   SURF components instantiated (sources: surf/base/fifo/rtl/Fifo.vhd and
--   surf/base/fifo/rtl/inferred/FifoSync.vhd):
--     U_PayloadConReqQ  : surf.Fifo     DATA_WIDTH_G=203 (PayloadConReq)
--     U_PayloadConRespQ : surf.Fifo     DATA_WIDTH_G=53  (PayloadConResp)
--     U_CountReqFragQ   : surf.Fifo     DATA_WIDTH_G=205 (Tuple3)
--     U_PendingConReqQ  : surf.Fifo     DATA_WIDTH_G=206 (Tuple4)
--     U_GenConRespQ     : surf.Fifo     DATA_WIDTH_G=203 (PayloadConReq)
--     U_PendingDmaReqQ  : surf.Fifo     DATA_WIDTH_G=493 (Tuple2)
--     U_PayloadBufQ     : surf.FifoSync DATA_WIDTH_G=290, depth 256 (BRAM; bramQ
--                         wired between the child's pipeIn and pipeOut paths)
--   Child entity instantiated:
--     U_PipeOut2Bram : ConnectPipeOut2BramQConAndGen
--                      (out/04-vhdl/ConnectPipeOut2BramQConAndGen.vhd, DATA_W_G=290)
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
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;

entity PayloadConsumerConAndGen is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk                : in  sl;
      rst                : in  sl;      -- active-high synchronous reset
      -- cntrlStatus.comm mode inputs (one-hot; NOT state)
      isReset            : in  sl;      -- comm.isReset  (guards R0 clear)
      isNonErr           : in  sl;      -- comm.isNonErr (guards R1-R5)
      isErr              : in  sl;      -- comm.isERR    (guards R1-R3,R6-R8)
      -- srvPort.request : Put#(PayloadConReq)  (caller -> entity, enq payloadConReqQ)
      reqInValid         : in  sl;      -- caller offers a request (wr_en)
      reqInData          : in  slv(202 downto 0);  -- PayloadConReq packed
      reqInReady         : out sl;      -- entity can accept (notFull)
      -- srvPort.response : Get#(PayloadConResp) (entity -> caller, deq payloadConRespQ)
      respOutReady       : in  sl;      -- caller takes a response (rd_en)
      respOutValid       : out sl;      -- response available (notEmpty)
      respOutData        : out slv(52 downto 0);   -- PayloadConResp packed
      -- payloadPipeIn : DataStreamPipeOut (caller -> entity; consumed by child)
      payloadPipeInValid : in  sl;      -- pipeIn.notEmpty
      payloadPipeInData  : in  slv(289 downto 0);  -- pipeIn.first (DataStream)
      payloadPipeInReady : out sl;      -- pipeIn deq (back to caller)
      -- dmaWriteSrv.request : Put#(DmaWriteReq)  (entity -> external server, CLIENT)
      dmaWriteReqValid   : out sl;      -- entity offers a request (Mealy)
      dmaWriteReqData    : out slv(418 downto 0);  -- DmaWriteReq packed (Mealy)
      dmaWriteReqReady   : in  sl;      -- external server can accept
      -- dmaWriteSrv.response : Get#(DmaWriteResp) (external server -> entity, CLIENT)
      dmaWriteRespValid  : in  sl;      -- external server offers a response
      dmaWriteRespData   : in  slv(52 downto 0);   -- DmaWriteResp packed
      dmaWriteRespReady  : out sl);     -- entity takes the response (get)
end entity PayloadConsumerConAndGen;

architecture rtl of PayloadConsumerConAndGen is

   -- Atomic-path constants (R4): zeroExtendLSB fill + genByteEn(ATOMIC_WORK_REQ_LEN=8)
   constant ZERO_192_C       : slv(191 downto 0) := (others => '0');
   constant ATOMIC_BYTE_EN_C : slv(31 downto 0)  := x"FF000000";  -- top 8 bytes valid

   -- Sub-FSM A counter state (the only sequential control state).
   type RegType is record
      isFirstOrOnlyFragReg      : sl;   -- mkReg(True)  -> '1'
      isRemainingFragNumZeroReg : sl;   -- mkReg(False) -> '0'
      remainingFragNumReg       : slv(7 downto 0);  -- mkRegU (NO RESET; written-before-read)
   end record RegType;

   constant REG_INIT_C : RegType := (
      isFirstOrOnlyFragReg      => '1',
      isRemainingFragNumZeroReg => '0',
      remainingFragNumReg       => (others => '0'));  -- don't-care init (mkRegU)

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- U_PayloadConReqQ (PayloadConReq, 203b)
   signal payReqValid : sl;
   signal payReqDout  : slv(202 downto 0);
   signal payReqRdEn  : sl;
   signal payReqRst   : sl;

   -- U_PayloadConRespQ (PayloadConResp, 53b)
   signal payRespNotFull : sl;
   signal payRespWrEn    : sl;
   signal payRespDin     : slv(52 downto 0);
   signal payRespRst     : sl;

   -- U_CountReqFragQ (Tuple3, 205b)
   signal countNotFull : sl;
   signal countValid   : sl;
   signal countWrEn    : sl;
   signal countDin     : slv(204 downto 0);
   signal countRdEn    : sl;
   signal countDout    : slv(204 downto 0);
   signal countRst     : sl;

   -- U_PendingConReqQ (Tuple4, 206b)
   signal pendConNotFull : sl;
   signal pendConValid   : sl;
   signal pendConWrEn    : sl;
   signal pendConDin     : slv(205 downto 0);
   signal pendConRdEn    : sl;
   signal pendConDout    : slv(205 downto 0);
   signal pendConRst     : sl;

   -- U_GenConRespQ (PayloadConReq, 203b)
   signal genRespNotFull : sl;
   signal genRespValid   : sl;
   signal genRespWrEn    : sl;
   signal genRespDin     : slv(202 downto 0);
   signal genRespRdEn    : sl;
   signal genRespDout    : slv(202 downto 0);
   signal genRespRst     : sl;

   -- U_PendingDmaReqQ (Tuple2, 493b)
   signal pendDmaNotFull : sl;
   signal pendDmaValid   : sl;
   signal pendDmaWrEn    : sl;
   signal pendDmaDin     : slv(492 downto 0);
   signal pendDmaRdEn    : sl;
   signal pendDmaDout    : slv(492 downto 0);
   signal pendDmaRst     : sl;

   -- U_PayloadBufQ (DataStream, 290b; FifoSync BRAM) <-> child bramQ ports
   signal bufNotFull : sl;
   signal bufValid   : sl;
   signal bufWrEn    : sl;
   signal bufDin     : slv(289 downto 0);
   signal bufRdEn    : sl;
   signal bufDout    : slv(289 downto 0);
   signal bufRst     : sl;

   -- Child pipeOut (DataStream, 290b) consumed by FSM (R3)
   signal bufPipeNotEmpty : sl;
   signal bufPipeFirst    : slv(289 downto 0);
   signal bufPipeDeq      : sl;

   -- R9 errDrainPayload (see error-flush note below): child-facing view of the
   -- payloadPipeIn face; in isErr the child is masked off and the fragments
   -- are sunk directly.
   signal childPipeInNotEmpty : sl;
   signal childPipeInDeq      : sl;

begin

   ---------------------------------------------------------------------------
   -- Per-FIFO synchronous clear lines (resetAndClear R0 + error flush R7/R8).
   ---------------------------------------------------------------------------
   payReqRst  <= rst or isReset;
   payRespRst <= rst or isReset or isErr;  -- + R8
   countRst   <= rst or isReset;
   pendConRst <= rst or isReset or isErr;  -- + R7
   genRespRst <= rst or isReset;
   pendDmaRst <= rst or isReset or isErr;  -- + R7
   bufRst     <= rst or isReset or isErr;  -- + R7

   ---------------------------------------------------------------------------
   -- R9 errDrainPayload (BUGFIX 2026-07-16, no BSV counterpart): while isErr,
   -- sink payloadPipeIn unconditionally and mask it off the child.
   --
   -- Packets addressed to an ERR QP pass header validation BY DESIGN
   -- (InputRdmaPktBufAndHeaderValidation validateHeader: statusIsERR ->
   -- qpStateMatch true) so the erred QP's flush rules can consume them.  But
   -- with U_PayloadBufQ held in reset by R7 (bufRst above), the child's
   -- bramQNotFull is low for as long as the QP sits in ERR, so the child
   -- never deqs payloadPipeIn: an erred QP stopped sinking payload, its
   -- RdmaPktMetaDataAndPayloadPipe backed up mid-packet (so no further meta
   -- -> no further Discard tokens either), and the SHARED input packet buffer
   -- jammed head-of-line — freezing ingress for EVERY QP of the
   -- TransportLayer.  Token/fragment pairing is irrelevant during ERR (R7
   -- discards the tokens); everything is cleared by R0 on the ERR->RESET
   -- transition before the QP can be reused.
   ---------------------------------------------------------------------------
   childPipeInNotEmpty <= payloadPipeInValid and (not isErr);
   payloadPipeInReady  <= (payloadPipeInValid and isErr) or
                         (childPipeInDeq and (not isErr));

   -- srvPort response valid/data are driven directly by U_PayloadConRespQ
   -- (valid => respOutValid, dout => respOutData below); request ready by
   -- U_PayloadConReqQ (not_full => reqInReady).

   ---------------------------------------------------------------------------
   -- U_PayloadConReqQ : surf.Fifo
   --   Inbound PayloadConReq (BSV mkFIFOF payloadConReqQ).  wr = caller's
   --   srvPort.request.put (pass-through); rd = FSM (recvReq R1).
   ---------------------------------------------------------------------------
   U_PayloadConReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 203,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => payReqRst,
         wr_clk   => clk,
         wr_en    => reqInValid,        -- pass-through (caller drives)
         din      => reqInData,         -- pass-through (caller drives)
         not_full => reqInReady,        -- pass-through to caller
         rd_clk   => clk,
         rd_en    => payReqRdEn,        -- FSM (recvReq)
         dout     => payReqDout,
         valid    => payReqValid);

   ---------------------------------------------------------------------------
   -- U_PayloadConRespQ : surf.Fifo
   --   Outbound PayloadConResp (BSV mkFIFOF payloadConRespQ).  wr = FSM
   --   (genConResp R5); rd = caller's srvPort.response.get (pass-through).
   ---------------------------------------------------------------------------
   U_PayloadConRespQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 53,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => payRespRst,
         wr_clk   => clk,
         wr_en    => payRespWrEn,       -- FSM (genConResp)
         din      => payRespDin,        -- FSM (genConResp)
         not_full => payRespNotFull,
         rd_clk   => clk,
         rd_en    => respOutReady,      -- pass-through (caller drives)
         dout     => respOutData,
         valid    => respOutValid);

   ---------------------------------------------------------------------------
   -- U_CountReqFragQ : surf.Fifo
   --   Tuple3(PayloadConReq,isFragNumLessOrEqOne,isDiscardReq).
   --   wr = FSM (recvReq R1); rd = FSM (countReqFrag R2, held until last frag).
   ---------------------------------------------------------------------------
   U_CountReqFragQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 205,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => countRst,
         wr_clk   => clk,
         wr_en    => countWrEn,         -- FSM (recvReq)
         din      => countDin,          -- FSM (recvReq)
         not_full => countNotFull,
         rd_clk   => clk,
         rd_en    => countRdEn,         -- FSM (countReqFrag)
         dout     => countDout,
         valid    => countValid);

   ---------------------------------------------------------------------------
   -- U_PendingConReqQ : surf.Fifo
   --   Tuple4(PayloadConReq,isFragNumLessOrEqOne,isFirstOrOnlyFrag,isLastReqFrag).
   --   wr = FSM (countReqFrag R2); rd = FSM (consumePayload R3).  Error-flushed (R7).
   ---------------------------------------------------------------------------
   U_PendingConReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 206,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => pendConRst,
         wr_clk   => clk,
         wr_en    => pendConWrEn,       -- FSM (countReqFrag)
         din      => pendConDin,        -- FSM (countReqFrag)
         not_full => pendConNotFull,
         rd_clk   => clk,
         rd_en    => pendConRdEn,       -- FSM (consumePayload)
         dout     => pendConDout,
         valid    => pendConValid);

   ---------------------------------------------------------------------------
   -- U_GenConRespQ : surf.Fifo
   --   PayloadConReq pending a DMA-write response (BSV mkFIFOF genConRespQ).
   --   wr = FSM (consumePayload R3, Atomic + SendWrite-last); rd = FSM (genConResp R5).
   ---------------------------------------------------------------------------
   U_GenConRespQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 203,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => genRespRst,
         wr_clk   => clk,
         wr_en    => genRespWrEn,       -- FSM (consumePayload)
         din      => genRespDin,        -- FSM (consumePayload)
         not_full => genRespNotFull,
         rd_clk   => clk,
         rd_en    => genRespRdEn,       -- FSM (genConResp)
         dout     => genRespDout,
         valid    => genRespValid);

   ---------------------------------------------------------------------------
   -- U_PendingDmaReqQ : surf.Fifo
   --   Tuple2(PayloadConReq,DataStream) awaiting issue to dmaWriteSrv.
   --   wr = FSM (consumePayload R3); rd = FSM (issueDmaReq R4).  Error-flushed (R7).
   ---------------------------------------------------------------------------
   U_PendingDmaReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 493,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => pendDmaRst,
         wr_clk   => clk,
         wr_en    => pendDmaWrEn,       -- FSM (consumePayload)
         din      => pendDmaDin,        -- FSM (consumePayload)
         not_full => pendDmaNotFull,
         rd_clk   => clk,
         rd_en    => pendDmaRdEn,       -- FSM (issueDmaReq)
         dout     => pendDmaDout,
         valid    => pendDmaValid);

   ---------------------------------------------------------------------------
   -- U_PayloadBufQ : surf.FifoSync  (BSV mkSizedBRAMFIFOF, depth 256)
   --   Parent-owned BRAM buffer wired between the child's pipeIn and pipeOut
   --   paths.  The FSM never reads it directly (it reads the child's pipeOut);
   --   it only clears it (R0/R7) via bufRst.  Driven entirely by the child's
   --   bramQ port group.  ADDR_WIDTH_G=8 (depth 256).
   ---------------------------------------------------------------------------
   U_PayloadBufQ : entity surf.FifoSync
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         RST_ASYNC_G    => false,
         MEMORY_TYPE_G  => "block",
         FWFT_EN_G      => true,
         DATA_WIDTH_G   => 290,
         ADDR_WIDTH_G   => 8)
      port map (
         rst      => bufRst,
         clk      => clk,
         wr_en    => bufWrEn,           -- child bramQ.enq
         rd_en    => bufRdEn,           -- child bramQ.deq
         din      => bufDin,            -- child bramQ data
         dout     => bufDout,           -- -> child bramQFirst
         valid    => bufValid,          -- -> child bramQNotEmpty
         not_full => bufNotFull);       -- -> child bramQNotFull

   ---------------------------------------------------------------------------
   -- U_PipeOut2Bram : ConnectPipeOut2BramQConAndGen (child entity, not SURF)
   --   BSV: mkConnectPipeOut2BramQ(payloadPipeIn, payloadBufQ).  Moves DataStream
   --   from the entity input pipe through U_PayloadBufQ and presents pipeOut to
   --   the FSM.  Its internal skid is cleared on R0 only (clearEnI <= isReset).
   ---------------------------------------------------------------------------
   U_PipeOut2Bram : entity surf.ConnectPipeOut2BramQConAndGen
      generic map (
         TPD_G    => TPD_G,
         DATA_W_G => 290)
      port map (
         clk             => clk,
         rst             => rst,
         clearEnI        => isReset,    -- R0 child clear
         -- pipeIn (entity input pipe; masked off + free-drained during isErr,
         -- see R9 errDrainPayload above)
         pipeInNotEmpty  => childPipeInNotEmpty,
         pipeInFirst     => payloadPipeInData,
         pipeInDeq       => childPipeInDeq,
         -- bramQ (parent-owned U_PayloadBufQ)
         bramQNotFull    => bufNotFull,
         bramQWrEn       => bufWrEn,
         bramQDin        => bufDin,
         bramQNotEmpty   => bufValid,
         bramQFirst      => bufDout,
         bramQDeq        => bufRdEn,
         -- pipeOut (to FSM, R3)
         pipeOutDeq      => bufPipeDeq,
         pipeOutFirst    => bufPipeFirst,
         pipeOutNotEmpty => bufPipeNotEmpty,
         notEmpty        => open);  -- parent does not use the aggregate method

   ---------------------------------------------------------------------------
   -- Combinatorial process (fsm.md §Conflicts §Suggested comb order)
   ---------------------------------------------------------------------------
   comb : process (r, rst, isReset, isNonErr, isErr,
                   payReqValid, payReqDout,
                   payRespNotFull,
                   countNotFull, countValid, countDout,
                   pendConNotFull, pendConValid, pendConDout,
                   genRespNotFull, genRespValid, genRespDout,
                   pendDmaNotFull, pendDmaValid, pendDmaDout,
                   bufPipeNotEmpty, bufPipeFirst,
                   dmaWriteReqReady, dmaWriteRespValid, dmaWriteRespData) is
      variable v : RegType;
      -- R1 recvReq datapath (off U_PayloadConReqQ front)
      variable tagR1       : slv(1 downto 0);
      variable fragNumR1   : slv(7 downto 0);
      variable isDiscardR1 : sl;
      variable isLeqOneR1  : sl;
      -- R2 countReqFrag datapath (off U_CountReqFragQ front)
      variable consumeR2    : slv(202 downto 0);
      variable fragNumR2    : slv(7 downto 0);
      variable isLeqOneR2   : sl;
      variable isDiscardR2  : sl;
      variable isLastFragR2 : sl;
      -- R3 consumePayload datapath (off U_PendingConReqQ front + child pipeOut)
      variable consumeR3     : slv(202 downto 0);
      variable tagR3         : slv(1 downto 0);
      variable isLastFragR3  : sl;
      variable payloadLastR3 : sl;
      -- R4 issueDmaReq datapath (off U_PendingDmaReqQ front)
      variable consumeR4   : slv(202 downto 0);
      variable payloadR4   : slv(289 downto 0);
      variable tagR4       : slv(1 downto 0);
      variable metaR4      : slv(128 downto 0);
      variable atomicPayR4 : slv(63 downto 0);
      variable atomicDsR4  : slv(289 downto 0);
      variable dmaReqDataV : slv(418 downto 0);
      -- R5 genConResp datapath (off U_GenConRespQ front + dmaWriteResp)
      variable tagR5  : slv(1 downto 0);
      variable metaR5 : slv(128 downto 0);
   begin
      v := r;

      ----------------------------------------------------------------------
      -- Combinational datapath extraction (harmless every cycle).
      ----------------------------------------------------------------------
      -- R1
      tagR1                                                := payReqDout(194 downto 193);
      fragNumR1                                            := payReqDout(202 downto 195);
      if tagR1 = "00" then isDiscardR1                     := '1'; else isDiscardR1 := '0'; end if;
      if fragNumR1(7 downto 1) = "0000000" then isLeqOneR1 := '1'; else isLeqOneR1 := '0'; end if;

      -- R2
      consumeR2   := countDout(204 downto 2);
      isLeqOneR2  := countDout(1);
      isDiscardR2 := countDout(0);
      fragNumR2   := consumeR2(202 downto 195);
      if isLeqOneR2 = '1' then
         isLastFragR2 := '1';
      else
         isLastFragR2 := r.isRemainingFragNumZeroReg;
      end if;

      -- R3
      consumeR3     := pendConDout(205 downto 3);
      isLastFragR3  := pendConDout(0);
      tagR3         := consumeR3(194 downto 193);
      payloadLastR3 := bufPipeFirst(0);

      -- R4
      consumeR4 := pendDmaDout(492 downto 290);
      payloadR4 := pendDmaDout(289 downto 0);
      tagR4     := consumeR4(194 downto 193);
      -- DmaWriteMetaData slice is TAG-DEPENDENT (DEVIATION-PCCAG-01): only the
      -- 193b Atomic struct member is metadata-MSB-aligned; the 129b members
      -- (SendWrite/Discard) are LSB-justified per BSV deriving(Bits).
      if tagR4 = "01" then              -- Atomic struct member
         metaR4 := consumeR4(192 downto 64);
      else                              -- SendWrite/Discard 129b member
         metaR4 := consumeR4(128 downto 0);
      end if;
      atomicPayR4 := consumeR4(63 downto 0);
      -- atomic DataStream: data = zeroExtendLSB(payload64) -> payload at MSB;
      -- byteEn = genByteEn(8) = 0xFF000000; isFirst='1'; isLast='1'
      atomicDsR4  := atomicPayR4 & ZERO_192_C & ATOMIC_BYTE_EN_C & '1' & '1';
      if tagR4 = "01" then              -- Atomic
         dmaReqDataV := metaR4 & atomicDsR4;
      else                              -- SendWrite (Discard: unused)
         dmaReqDataV := metaR4 & payloadR4;
      end if;

      -- R5 (same tag-dependent metaData slice as R4; genRespDout carries the
      -- 203b PayloadConReq layout, tag at [194:193])
      tagR5 := genRespDout(194 downto 193);
      if tagR5 = "01" then              -- Atomic struct member
         metaR5 := genRespDout(192 downto 64);
      else                              -- SendWrite/Discard 129b member
         metaR5 := genRespDout(128 downto 0);
      end if;

      ----------------------------------------------------------------------
      -- Default outputs / SURF & child drives (deasserted; din/data = fronts).
      ----------------------------------------------------------------------
      payReqRdEn  <= '0';
      countWrEn   <= '0';
      countDin    <= payReqDout & isLeqOneR1 & isDiscardR1;     -- 203+1+1=205
      countRdEn   <= '0';
      pendConWrEn <= '0';
      pendConDin  <= consumeR2 & isLeqOneR2 & r.isFirstOrOnlyFragReg & isLastFragR2;  -- 203+1+1+1=206
      pendConRdEn <= '0';
      genRespWrEn <= '0';
      genRespDin  <= consumeR3;         -- PayloadConReq (203)
      genRespRdEn <= '0';
      pendDmaWrEn <= '0';
      pendDmaDin  <= consumeR3 & bufPipeFirst;  -- 203+290=493 (SendWrite)
      pendDmaRdEn <= '0';
      payRespWrEn <= '0';
      -- PayloadConResp = DmaWriteResp{initiator,sqpn,psn from meta; isRespErr from resp}
      payRespDin  <= metaR5(128 downto 125) & metaR5(124 downto 101) &
                    metaR5(23 downto 0) & dmaWriteRespData(0);  -- 4+24+24+1=53
      bufPipeDeq        <= '0';
      dmaWriteReqValid  <= '0';
      dmaWriteReqData   <= dmaReqDataV;         -- Mealy front (R4)
      dmaWriteRespReady <= '0';

      ----------------------------------------------------------------------
      -- R1 recvReq : (isNonErr||isErr) && payReqQ.notEmpty && countReqFragQ.notFull
      ----------------------------------------------------------------------
      if ((isNonErr = '1' or isErr = '1') and payReqValid = '1' and countNotFull = '1') then
         payReqRdEn <= '1';             -- deq U_PayloadConReqQ
         countWrEn  <= '1';             -- enq U_CountReqFragQ (din set above)
      end if;

      ----------------------------------------------------------------------
      -- R2 countReqFrag : sub-FSM A.  Always enq U_PendingConReqQ with the CURRENT
      --   isFirstOrOnlyFragReg; deq U_CountReqFragQ only on discard or last frag.
      ----------------------------------------------------------------------
      if ((isNonErr = '1' or isErr = '1') and countValid = '1' and pendConNotFull = '1') then
         pendConWrEn <= '1';            -- enq U_PendingConReqQ (din set above)
         if isDiscardR2 = '1' then
            countRdEn <= '1';           -- deq (no counter update)
         elsif isLastFragR2 = '1' then
            countRdEn                   <= '1';
            v.isFirstOrOnlyFragReg      := '1';
            v.isRemainingFragNumZeroReg := '0';
         else
            -- hold the U_CountReqFragQ head (no deq); advance the down-counter
            if r.isFirstOrOnlyFragReg = '1' then
               v.remainingFragNumReg  := slv(unsigned(fragNumR2) - 2);
               v.isFirstOrOnlyFragReg := '0';
               -- isRemainingFragNumZeroReg := isTwo(fragNum)
               if (fragNumR2(7 downto 2) = "000000" and fragNumR2(1) = '1' and
                   fragNumR2(0) = '0') then
                  v.isRemainingFragNumZeroReg := '1';
               else
                  v.isRemainingFragNumZeroReg := '0';
               end if;
            else
               v.remainingFragNumReg := slv(unsigned(r.remainingFragNumReg) - 1);
               -- isRemainingFragNumZeroReg := isOne(remainingFragNumReg)
               if (r.remainingFragNumReg(7 downto 1) = "0000000" and
                   r.remainingFragNumReg(0) = '1') then
                  v.isRemainingFragNumZeroReg := '1';
               else
                  v.isRemainingFragNumZeroReg := '0';
               end if;
            end if;
         end if;
      end if;

      ----------------------------------------------------------------------
      -- R3 consumePayload : per-tag.  Whole-branch atomic — if the branch's
      --   implicit conditions fail, none of its actions (incl. the pendConReq deq)
      --   take effect.
      ----------------------------------------------------------------------
      if ((isNonErr = '1' or isErr = '1') and pendConValid = '1') then
         case tagR3 is
            when "00" =>                -- Discard: drain one payload fragment
               if bufPipeNotEmpty = '1' then
                  bufPipeDeq <= '1';
                  if payloadLastR3 = '1' then  -- shouldDeqConReq = payload.isLast
                     pendConRdEn <= '1';
                  end if;
               end if;
            when "01" =>  -- Atomic: dummy resp + dma token, no payload
               if (genRespNotFull = '1' and pendDmaNotFull = '1') then
                  genRespWrEn <= '1';
                  pendDmaWrEn <= '1';
                  pendDmaDin  <= consumeR3 & (289 downto 0 => '0');  -- payload dontCare
                  pendConRdEn <= '1';
               end if;
            when "10" =>  -- SendWrite: payload + dma token (+resp on last)
               if (bufPipeNotEmpty = '1' and pendDmaNotFull = '1' and
                   (isLastFragR3 = '0' or genRespNotFull = '1')) then
                  bufPipeDeq <= '1';
                  if isLastFragR3 = '1' then
                     genRespWrEn <= '1';
                  end if;
                  pendDmaWrEn <= '1';  -- pendDmaDin default = consumeR3 & payload
                  pendConRdEn <= '1';
               end if;
            when others =>
               null;
         end case;
      end if;

      ----------------------------------------------------------------------
      -- R4 issueDmaReq : isNonErr only.  Discard deqs without a Put; SendWrite/
      --   Atomic Put one DmaWriteReq.
      --   AXI-Stream / SURF master rule: dmaWriteReqValid is asserted whenever a
      --   non-Discard token is available (Mealy from pendDmaValid), INDEPENDENT of
      --   dmaWriteReqReady; the transfer (FIFO dequeue) is gated by valid AND ready.
      --   dmaWriteReqData is already driven combinationally (dmaReqDataV) and is held
      --   stable while the token sits at the FIFO front, so valid+data hold across a
      --   ready-low stall with no extra logic.  (Stage-5 TC-06 fix: previously valid
      --   was asserted only inside `if dmaWriteReqReady='1'`, making valid depend on
      --   ready — a handshake violation / potential combinational deadlock.)
      ----------------------------------------------------------------------
      if (isNonErr = '1' and pendDmaValid = '1') then
         case tagR4 is
            when "00" =>                -- Discard: deq, no DMA put
               pendDmaRdEn <= '1';
            when others =>              -- SendWrite / Atomic: Put
               dmaWriteReqValid <= '1';  -- valid independent of ready (data = dmaReqDataV)
               if dmaWriteReqReady = '1' then
                  pendDmaRdEn <= '1';  -- dequeue only on accept (valid AND ready)
               end if;
         end case;
      end if;

      ----------------------------------------------------------------------
      -- R5 genConResp : isNonErr.  Get DmaWriteResp, build PayloadConResp, enq.
      ----------------------------------------------------------------------
      if (isNonErr = '1' and dmaWriteRespValid = '1' and genRespValid = '1' and
          payRespNotFull = '1') then
         dmaWriteRespReady <= '1';      -- get external response
         genRespRdEn       <= '1';      -- deq U_GenConRespQ
         payRespWrEn       <= '1';  -- enq U_PayloadConRespQ (din set above)
      end if;

      ----------------------------------------------------------------------
      -- R6 flushDmaWriteResp : isErr.  Drop the DMA write response.
      ----------------------------------------------------------------------
      if (isErr = '1' and dmaWriteRespValid = '1') then
         dmaWriteRespReady <= '1';      -- get and discard
      end if;

      ----------------------------------------------------------------------
      -- R0 resetAndClear (isReset) / hardware reset : force the two reset-valued
      --   counter regs (remainingFragNumReg is mkRegU -> untouched).  Dominates R2.
      ----------------------------------------------------------------------
      if (rst = '1' or isReset = '1') then
         v.isFirstOrOnlyFragReg      := '1';
         v.isRemainingFragNumZeroReg := '0';
      end if;

      rin <= v;
   end process comb;

   ---------------------------------------------------------------------------
   -- Sequential process
   ---------------------------------------------------------------------------
   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin;
      end if;
   end process seq;

end architecture rtl;
