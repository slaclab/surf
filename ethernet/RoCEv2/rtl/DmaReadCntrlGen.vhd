-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   SGL-aware read controller for the SQ payload generator.  Each incoming
--   DmaReadCntrlReq (1163b) carries a full scatter-gather list (MAX_SGE=8 SGEs).
--     * recvReq      (R1) walks the SGL one SGE per cycle (sglIdxReg), emitting a
--                         per-SGE MergedMetaDataSGE side stream
--                         (U_SgeMergedMetaDataOutQ) and pushing each SGE+PMTU
--                         into the chunker pipeline (U_PendingScatterGatherElemQ).
--                         It deqs U_ReqQ ONLY on the SGL's last SGE (sge.isLast),
--                         and enqs the per-SGL {sqpn,wrID} into
--                         U_PendingDmaCntrlReqQ ONLY on the first SGE
--                         (sge.isFirst).
--     * issueChunkReq(R2) pops one SGE, pushes an AddrChunkReq into the child
--                         U_AddrChunkSrv, and stashes the SGE's lkey in
--                         U_PendingLKeyQ.
--     * issueDmaReq  (R3) pops one AddrChunkResp from the child, composes one
--                         external DmaReadReq (one per PMTU chunk), and tokenises
--                         the SGL-level first/last flags into U_PendingDmaReadReqQ.
--     * recvDmaResp  (R4) re-assembles the streamed DmaReadResp fragments into
--                         DmaReadCntrlResps that carry the *SGL-level* first/last
--                         flags, into U_RespQ.
--   Cancel / graceful-stop mirrors DmaReadCntrlConAndGen and DmaWriteCntrl.
--
--   There is NO explicit state-enum register.  Two control axes coexist:
--     (1) the {cancel, gracefulStop} CReg sub-FSM (two boolean RegType fields):
--           RUN_S        = {cancel=0}            — R1/R2/R3/R4 active
--           CANCELLING_S = {cancel=1,grStop=0}   — R1/R2/R3 blocked; R4 keeps
--                                                  draining; await respQ +
--                                                  pendingDmaReadReqQ empty
--           STOPPED_S    = {cancel=1,grStop=1}   — quiesced; isIdle() true
--           {cancel=0,gracefulStop=1} is unreachable.
--     (2) sglIdxReg (3b) — the SGL-walk index inside recvReq (counter-as-state).
--
--   The four pipeline rules carry (* conflict_free *) (PayloadGen.bsv:730-733)
--   and touch DISJOINT FIFO enq/deq pairs, so all four may fire the SAME cycle
--   (a 4-stage pipeline).  Each is emitted as an independent if-block in comb.
--
--   Boundaries:
--     * Server to its caller (srvPort: request Put / response Get, wired through
--       U_ReqQ / U_RespQ).
--     * Client of the external Server dmaReadSrv (request Put dmaReqOut /
--       response Get dmaRespIn).
--     * Two PipeOut outputs: sgeMergedMetaDataPipeOut (8b, from the parent
--       U_SgeMergedMetaDataOutQ) and sgePktMetaDataPipeOut (54b, re-exported
--       DIRECTLY from the child U_AddrChunkSrv — no parent FIFO, no FSM logic).
--
--   THREE distinct "last" conditions (fsm.md §Notes; do NOT conflate):
--     addrChunkResp.isLast (last CHUNK of an SGE)            -> deq U_PendingLKeyQ
--     isLastDmaReqChunk (= isLast AND isOrigLast SGE)        -> deq U_PendingDmaCntrlReqQ
--     dmaResp.dataStream.isLast (last FRAGMENT of a DMA resp)-> deq U_PendingDmaReadReqQ
--
--   CReg semantics (fsm.md §CReg semantics) — each mkCReg(2,False) is ONE RegType
--   field, writes applied in port order so reads see the forwarded value:
--     cancel       : v:=r; port0 (cancelEn) sets '1' BEFORE R1/R2/R3/R5 read
--                    v.cancel (same-cycle cancel); port1 (clearAll) clears '0'
--                    last (dominates).
--     gracefulStop : port0 read (isIdle) uses r.gracefulStop (pre-update, Moore);
--                    port0 write (cancelEn) re-arms '0'; R5 then sets '1';
--                    port1 (clearAll) clears '0' last (dominates).
--                    Net: clearAll->0; else setGracefulStop->1; else cancelEn->0;
--                    else hold.
--
--   Mealy (combinational) request paths (fsm.md §Output style) — MUST NOT be
--   registered:
--     dmaReqOut       = composed DmaReadReq (sqpn/wrID from the pending-cntrl
--                       front, chunkAddr/chunkLen from the child resp front,
--                       mrIdx from the pending-lkey front), gated by dmaReqValid
--                       (R3).
--     childReqPutDin  = AddrChunkReq off the pending-SGE front, gated by
--                       childReqPutWrEn (R2).
--     U_RespQ.din     = DmaReadResp & isFirstFragInSGL & isLastFragInSGL,
--                       computed in R4 and then registered INSIDE the Fifo.
--
--   sglIdxReg / totalLenReg / sgeNumReg (fsm.md §State register):
--     sglIdxReg  is genuine state (selects the SGE, paces the U_ReqQ deq).
--     totalLenReg/sgeNumReg are DEAD for synthesis (totalLenReg feeds only a
--       sim-only immAssert / commented-out enq; sgeNumReg is never read).  Kept
--       in RegType for source fidelity per OQ-FSM-DRCG-04; a synth tool may prune
--       them.
--
--   FIFO clear (OQ-FSM-01 carry-forward, RESOLVED in out/03-fsm/RESOLVED.md):
--     BSV resetAndClear .clear of all seven FIFOs maps to asserting each Fifo's
--     rst, OR'd with the structural reset:  fifoRst = rst OR clearAll.  Requires
--     GEN_SYNC_FIFO_G=true, RST_ASYNC_G=false, RST_POLARITY_G='1'.  All seven
--     share fifoRst so the BSV single-cycle simultaneous clear is preserved.  The
--     child clears via its own clearAllI (= clearAll).
--
--   Open-question carry-forwards (out/04-vhdl/OPEN_QUESTIONS.md and
--   out/03-fsm/DmaReadCntrlGen.fsm.md §Open issues):
--     OQ-FSM-DRCG-01 — mapping.json/modules.json are WRONG for this entity
--                      (fabricated issueReq/recvResp/cancelFlush rules; five FIFOs
--                      and three registers + the child + two PipeOut outputs
--                      missing).  This file follows the FSM spec / LIVE BSV: SEVEN
--                      surf.Fifo + one U_AddrChunkSrv child.
--     OQ-FSM-DRCG-02 — new_ports=[] is incomplete: clearAll, the dmaReadSrv
--                      Server-client handshake, and BOTH PipeOut output groups are
--                      real top-level ports (enumerated below).
--     OQ-FSM-DRCG-03 — Vector packing direction for sgl[sglIdx]: element 0 at the
--                      MSB of the 1040b sgl region (project-wide first-element-at-
--                      MSB convention, shared with OQ-FSM-H2DS-04).  Correctness
--                      needs only producer/consumer agreement; both sides are this
--                      pipeline.
--     OQ-FSM-DRCG-04 — totalLenReg/sgeNumReg dead for synthesis (kept for
--                      fidelity).
--
--   Bit layouts (BSV deriving(Bits), first-field-at-MSB; fsm.md §Bit layouts):
--
--   DmaReadCntrlReq (1163b) — U_ReqQ element:
--     [1162:123] sgl (Vector#(8,SGE), element 0 at MSB; SGE i at
--                (1162-130*i) downto (1033-130*i))
--     [122:91] totalLen(32)  [90:67] sqpn(24)  [66:3] wrID(64)  [2:0] pmtu(3)
--   ScatterGatherElem (130b) — selected sgl[sglIdx] slice, bits within the SGE:
--     [129:66] laddr(64)  [65:34] len(32)  [33:2] lkey(32)  [1] isFirst [0] isLast
--   MergedMetaDataSGE (8b) — U_SgeMergedMetaDataOutQ element:
--     [7:2] lastFragValidByteNum(6)  [1] isFirst  [0] isLast
--   Tuple2#(SGE,PMTU) (133b) — U_PendingScatterGatherElemQ element:
--     [132:3] sge(130)  [2:0] pmtu(3)
--   Tuple2#(QPN,WorkReqID) (88b) — U_PendingDmaCntrlReqQ element:
--     [87:64] sqpn(24)  [63:0] wrID(64)
--   AddrChunkReq (101b, Gen) — childReqPutDin:
--     [100:37] startAddr(64)  [36:5] len(32)  [4:2] pmtu(3)  [1] isFirst [0] isLast
--   AddrChunkResp (81b, Gen) — childRespQDout:
--     [80:17] chunkAddr(64)  [16:4] chunkLen(13)  [3] isFirst  [2] isLast
--     [1] isOrigFirst  [0] isOrigLast
--   DmaReadReq (176b) — dmaReqOut:
--     [175:172] initiator(4)  [171:148] sqpn(24)  [147:84] wrID(64)
--     [83:20] startAddr(64)  [19:7] len(13,PktLen)  [6:0] mrIdx(7)
--   DmaReadResp (383b) — dmaRespIn:
--     [382:379] initiator(4)  [378:355] sqpn(24)  [354:291] wrID(64)
--     [290] isRespErr  [289:34] data(256)  [33:2] byteEn(32)  [1] isFirst [0] isLast
--   DmaReadCntrlResp (385b) — U_RespQ element:
--     [384:2] dmaReadResp(383)  [1] isFirstFragInSGL  [0] isLastFragInSGL
--   Tuple2#(Bool,Bool) (2b) — U_PendingDmaReadReqQ element:
--     [1] isFirstDmaReqChunk  [0] isLastDmaReqChunk
--
--   calcLastFragValidByteNum(len) (Utils.bsv:165-180) -> 6b:
--     residue := len(4:0);
--     (residue=0 AND len(31:5)/=0) ? 32 : ('0' & residue)
--   key2IndexMR(lkey) (Utils.bsv:416, truncateLSB) -> 7b:  mrIdx := lkey(31:25)
--   DMA_SRC_SQ_RD = enum index 5 of DmaReqSrcType (DataTypes.bsv:302-314,
--     commented members excluded) => 4-bit "0101".
--
--   SURF components instantiated (source: surf/base/fifo/rtl/Fifo.vhd):
--     U_ReqQ                      : surf.Fifo DATA_WIDTH_G=1163 (DmaReadCntrlReq)
--     U_RespQ                     : surf.Fifo DATA_WIDTH_G=385  (DmaReadCntrlResp)
--     U_SgeMergedMetaDataOutQ     : surf.Fifo DATA_WIDTH_G=8    (MergedMetaDataSGE)
--     U_PendingScatterGatherElemQ : surf.Fifo DATA_WIDTH_G=133  (Tuple2#(SGE,PMTU))
--     U_PendingLKeyQ              : surf.Fifo DATA_WIDTH_G=32    (LKEY)
--     U_PendingDmaCntrlReqQ       : surf.Fifo DATA_WIDTH_G=88    (Tuple2#(QPN,WRID))
--     U_PendingDmaReadReqQ        : surf.Fifo DATA_WIDTH_G=2     (Tuple2#(Bool,Bool))
--   Child entity instantiated:
--     U_AddrChunkSrv : AddrChunkSrvGen (out/04-vhdl/AddrChunkSrvGen.vhd)
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

entity DmaReadCntrlGen is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk             : in  sl;
      rst             : in  sl;         -- active-high synchronous reset
      -- Software clear (module parameter clearAll; synchronous, LEVEL-asserted)
      clearAll        : in  sl;
      -- dmaCntrl.cancel() method (Action pulse): request graceful cancel
      cancelEn        : in  sl;
      -- srvPort.request : Put#(DmaReadCntrlReq)  (caller -> entity, enq to reqQ)
      reqInValid      : in  sl;         -- caller offers a request (wr_en)
      reqInData       : in  slv(1162 downto 0);  -- DmaReadCntrlReq packed
      reqInReady      : out sl;         -- entity can accept (reqQ.notFull)
      -- srvPort.response : Get#(DmaReadCntrlResp) (entity -> caller, deq from respQ)
      respOutReady    : in  sl;         -- caller takes a response (rd_en)
      respOutValid    : out sl;         -- response available (respQ.notEmpty)
      respOutData     : out slv(384 downto 0);   -- DmaReadCntrlResp packed
      -- sgeMergedMetaDataPipeOut : PipeOut#(MergedMetaDataSGE) (entity -> caller)
      sgeMergedRdEn   : in  sl;         -- caller deq
      sgeMergedValid  : out sl;         -- data available (notEmpty)
      sgeMergedData   : out slv(7 downto 0);   -- MergedMetaDataSGE packed
      -- sgePktMetaDataPipeOut : PipeOut#(PktMetaDataSGE) (re-exported from child)
      sgePktMetaRdEn  : in  sl;         -- caller deq -> child
      sgePktMetaValid : out sl;         -- child respQ.notEmpty
      sgePktMetaData  : out slv(53 downto 0);  -- PktMetaDataSGE packed (child)
      -- dmaReadSrv.request : Put#(DmaReadReq)   (entity -> external server, CLIENT)
      dmaReqValid     : out sl;         -- entity offers a request (Mealy)
      dmaReqOut       : out slv(175 downto 0);   -- DmaReadReq packed (Mealy)
      dmaReqReady     : in  sl;         -- external server can accept
      -- dmaReadSrv.response : Get#(DmaReadResp) (external server -> entity, CLIENT)
      dmaRespValid    : in  sl;         -- external server offers a response
      dmaRespIn       : in  slv(382 downto 0);   -- DmaReadResp packed
      dmaRespReady    : out sl;         -- entity takes the response (get/pop)
      -- dmaCntrl.isIdle() method result (Moore, registered)
      isIdle          : out sl);
end entity DmaReadCntrlGen;

architecture rtl of DmaReadCntrlGen is

   -- DmaReqSrcType enum index 5 (DataTypes.bsv:302-314, commented members excluded)
   constant DMA_SRC_SQ_RD_C : slv(3 downto 0) := "0101";

   -- Control sub-FSM state: two CReg booleans + the SGL-walk index.  The two
   -- accumulators are dead for synthesis (OQ-FSM-DRCG-04) but kept for fidelity.
   type RegType is record
      cancel       : sl;                -- cancelReg[2] <- mkCReg(2,False)
      gracefulStop : sl;  -- gracefulStopReg[2] <- mkCReg(2,False)
      sglIdxReg    : slv(2 downto 0);   -- mkReg(0) : IdxSGL, SGL-walk index
      totalLenReg  : slv(31 downto 0);  -- mkRegU : Length accumulator (dead)
      sgeNumReg    : slv(3 downto 0);   -- mkRegU : NumSGE accumulator (dead)
   end record RegType;

   constant REG_INIT_C : RegType := (
      cancel       => '0',
      gracefulStop => '0',
      sglIdxReg    => (others => '0'),
      totalLenReg  => (others => '0'),
      sgeNumReg    => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- U_ReqQ (DmaReadCntrlReq, 1163b)
   signal reqQValid : sl;               -- = reqQ.notEmpty (FWFT data valid)
   signal reqQDout  : slv(1162 downto 0);
   signal reqQRdEn  : sl;

   -- U_RespQ (DmaReadCntrlResp, 385b)
   signal respQNotFull : sl;
   signal respQValid   : sl;  -- = respQ.notEmpty (R5 quiescence guard)
   signal respQWrEn    : sl;
   signal respQDin     : slv(384 downto 0);

   -- U_SgeMergedMetaDataOutQ (MergedMetaDataSGE, 8b)
   signal sgeMergedNotFull : sl;
   signal sgeMergedWrEn    : sl;
   signal sgeMergedDin     : slv(7 downto 0);

   -- U_PendingScatterGatherElemQ (Tuple2#(SGE,PMTU), 133b)
   signal pscElemNotFull : sl;
   signal pscElemValid   : sl;          -- = notEmpty
   signal pscElemWrEn    : sl;
   signal pscElemDin     : slv(132 downto 0);
   signal pscElemRdEn    : sl;
   signal pscElemDout    : slv(132 downto 0);

   -- U_PendingLKeyQ (LKEY, 32b)
   signal lkeyNotFull : sl;
   signal lkeyValid   : sl;             -- = notEmpty
   signal lkeyWrEn    : sl;
   signal lkeyDin     : slv(31 downto 0);
   signal lkeyRdEn    : sl;
   signal lkeyDout    : slv(31 downto 0);

   -- U_PendingDmaCntrlReqQ (Tuple2#(QPN,WorkReqID), 88b)
   signal pendCntrlNotFull : sl;
   signal pendCntrlValid   : sl;        -- = notEmpty
   signal pendCntrlWrEn    : sl;
   signal pendCntrlDin     : slv(87 downto 0);
   signal pendCntrlRdEn    : sl;
   signal pendCntrlDout    : slv(87 downto 0);

   -- U_PendingDmaReadReqQ (Tuple2#(Bool,Bool), 2b)
   signal pendReadNotFull : sl;
   signal pendReadValid   : sl;         -- = notEmpty (R5 quiescence guard)
   signal pendReadWrEn    : sl;
   signal pendReadDin     : slv(1 downto 0);
   signal pendReadRdEn    : sl;
   signal pendReadDout    : slv(1 downto 0);

   -- U_AddrChunkSrv child interface
   signal childReqPutWrEn  : sl;  -- FSM (issueChunkReq) -> child request.put
   signal childReqPutDin   : slv(100 downto 0);
   signal childReqPutReady : sl;  -- child reqQ.notFull (R2 implicit cond)
   signal childRespGetRdEn : sl;  -- FSM (issueDmaReq) -> child response.get
   signal childRespQValid  : sl;  -- child respQ.notEmpty (R3 implicit cond)
   signal childRespQDout   : slv(80 downto 0);

   -- FIFO reset line: level = rst OR clearAll (atomic 7-FIFO clear)
   signal fifoRst : sl;

begin

   -- FIFO reset: level-sensitive clear (OQ-FSM-01 carry-forward, RESOLVED)
   fifoRst <= rst or clearAll;

   -- srvPort response valid pass-through (also used by R5 quiescence guard)
   respOutValid <= respQValid;

   -- isIdle() method (Moore): registered gracefulStop (CReg port0 read of the
   -- REGISTERED value).  Drive from r, NOT v.
   isIdle <= r.gracefulStop;

   ---------------------------------------------------------------------------
   -- U_ReqQ : surf.Fifo
   --   Inbound DmaReadCntrlReq queue (BSV mkFIFOF reqQ).  wr side = caller's
   --   srvPort.request.put (pass-through); rd side = FSM (recvReq deq on the
   --   SGL's last SGE only).
   ---------------------------------------------------------------------------
   U_ReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 1163,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => reqInValid,        -- pass-through (caller drives)
         din      => reqInData,         -- pass-through (caller drives)
         not_full => reqInReady,        -- pass-through to caller
         rd_clk   => clk,
         rd_en    => reqQRdEn,          -- FSM (recvReq, on sge.isLast)
         dout     => reqQDout,
         valid    => reqQValid);

   ---------------------------------------------------------------------------
   -- U_RespQ : surf.Fifo
   --   Outbound DmaReadCntrlResp queue (BSV mkFIFOF respQ).  wr = FSM
   --   (recvDmaResp enq); rd = caller's srvPort.response.get (pass-through).
   ---------------------------------------------------------------------------
   U_RespQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 385,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => respQWrEn,         -- FSM (recvDmaResp)
         din      => respQDin,          -- FSM (recvDmaResp)
         not_full => respQNotFull,
         rd_clk   => clk,
         rd_en    => respOutReady,      -- pass-through (caller drives)
         dout     => respOutData,
         valid    => respQValid);

   ---------------------------------------------------------------------------
   -- U_SgeMergedMetaDataOutQ : surf.Fifo
   --   Per-SGE MergedMetaDataSGE side stream (BSV mkSizedFIFOF(MAX_SGE)).
   --   wr = FSM (recvReq, every SGE); rd = caller (sgeMergedMetaDataPipeOut).
   --   ADDR_WIDTH_G=4 (capacity 15 >= MAX_SGE=8).
   ---------------------------------------------------------------------------
   U_SgeMergedMetaDataOutQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 8,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => sgeMergedWrEn,     -- FSM (recvReq)
         din      => sgeMergedDin,      -- FSM (recvReq)
         not_full => sgeMergedNotFull,
         rd_clk   => clk,
         rd_en    => sgeMergedRdEn,     -- pass-through (caller drives)
         dout     => sgeMergedData,
         valid    => sgeMergedValid);

   ---------------------------------------------------------------------------
   -- U_PendingScatterGatherElemQ : surf.Fifo
   --   SGE+PMTU staged for the chunker (BSV mkSizedFIFOF(MAX_SGE)).
   --   wr = FSM (recvReq, every SGE); rd = FSM (issueChunkReq).
   --   ADDR_WIDTH_G=4 (capacity 15 >= MAX_SGE=8).
   ---------------------------------------------------------------------------
   U_PendingScatterGatherElemQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 133,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => pscElemWrEn,       -- FSM (recvReq)
         din      => pscElemDin,        -- FSM (recvReq)
         not_full => pscElemNotFull,
         rd_clk   => clk,
         rd_en    => pscElemRdEn,       -- FSM (issueChunkReq)
         dout     => pscElemDout,
         valid    => pscElemValid);

   ---------------------------------------------------------------------------
   -- U_PendingLKeyQ : surf.Fifo
   --   Per-SGE lkey held until its chunks are issued (BSV mkFIFOF).
   --   wr = FSM (issueChunkReq); rd = FSM (issueDmaReq, on addrChunkResp.isLast).
   ---------------------------------------------------------------------------
   U_PendingLKeyQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 32,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => lkeyWrEn,          -- FSM (issueChunkReq)
         din      => lkeyDin,           -- FSM (issueChunkReq)
         not_full => lkeyNotFull,
         rd_clk   => clk,
         rd_en    => lkeyRdEn,          -- FSM (issueDmaReq, on chunk.isLast)
         dout     => lkeyDout,
         valid    => lkeyValid);

   ---------------------------------------------------------------------------
   -- U_PendingDmaCntrlReqQ : surf.Fifo
   --   Per-SGL {sqpn,wrID} (BSV mkFIFOF).  wr = FSM (recvReq, only on
   --   sge.isFirst); rd = FSM (issueDmaReq, only on isLastDmaReqChunk).
   ---------------------------------------------------------------------------
   U_PendingDmaCntrlReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 88,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => pendCntrlWrEn,     -- FSM (recvReq, on sge.isFirst)
         din      => pendCntrlDin,      -- FSM (recvReq)
         not_full => pendCntrlNotFull,
         rd_clk   => clk,
         rd_en    => pendCntrlRdEn,  -- FSM (issueDmaReq, on isLastDmaReqChunk)
         dout     => pendCntrlDout,
         valid    => pendCntrlValid);

   ---------------------------------------------------------------------------
   -- U_PendingDmaReadReqQ : surf.Fifo
   --   One token per issued DMA-read chunk: {isFirstDmaReqChunk,
   --   isLastDmaReqChunk} (BSV mkFIFOF).  wr = FSM (issueDmaReq); rd = FSM
   --   (recvDmaResp, on dataStream.isLast).  R5's graceful-stop guard reads its
   --   notEmpty, so distributed RAM is used for enq->notEmpty timing fidelity
   --   (mirrors the DmaReadCntrlConAndGen/DmaWriteCntrl rationale; OQ-EMIT-08).
   ---------------------------------------------------------------------------
   U_PendingDmaReadReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 2,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => pendReadWrEn,      -- FSM (issueDmaReq)
         din      => pendReadDin,       -- FSM (issueDmaReq)
         not_full => pendReadNotFull,
         rd_clk   => clk,
         rd_en    => pendReadRdEn,  -- FSM (recvDmaResp, on dataStream.isLast)
         dout     => pendReadDout,
         valid    => pendReadValid);

   ---------------------------------------------------------------------------
   -- U_AddrChunkSrv : AddrChunkSrvGen (child entity, not SURF)
   --   BSV: addrChunkSrv <- mkAddrChunkSrv(clearAll).  Server pair: parent drives
   --   request.put / response.get.  Its sgePktMetaDataPipeOut is RE-EXPORTED
   --   directly as the parent's sgePktMetaDataPipeOut (no parent FIFO/logic).
   --   The child's isIdle is not read by this parent (left open).
   ---------------------------------------------------------------------------
   U_AddrChunkSrv : entity surf.AddrChunkSrvGen
      generic map (
         TPD_G => TPD_G)
      port map (
         clk             => clk,
         rst             => rst,
         clearAllI       => clearAll,
         reqPutValid     => childReqPutWrEn,
         reqPutData      => childReqPutDin,
         reqPutReady     => childReqPutReady,
         respGetReady    => childRespGetRdEn,
         respGetValid    => childRespQValid,
         respGetData     => childRespQDout,
         sgePktMetaRdEn  => sgePktMetaRdEn,   -- re-export: caller deq -> child
         sgePktMetaValid => sgePktMetaValid,  -- re-export: child -> caller
         sgePktMetaData  => sgePktMetaData,   -- re-export: child -> caller
         isIdle          => open);      -- parent does not read child isIdle

   ---------------------------------------------------------------------------
   -- Combinatorial process
   --   Emit order (fsm.md §Conflicts/scheduling §Suggested comb order):
   --     1) cancel() port0 (cancelEn) forwarded into v.cancel / v.gracefulStop
   --     2) recvDmaResp (R4) — cancel-independent
   --     3) if !cancel: R1/R2/R3 (independent CF blocks); else: R5 setGracefulStop
   --     4) resetAndClear (R0) port1 writes last (clearAll dominates)
   ---------------------------------------------------------------------------
   comb : process (r, rst, clearAll, cancelEn,
                   reqQValid, reqQDout,
                   respQNotFull, respQValid,
                   sgeMergedNotFull,
                   pscElemNotFull, pscElemValid, pscElemDout,
                   lkeyNotFull, lkeyValid, lkeyDout,
                   pendCntrlNotFull, pendCntrlValid, pendCntrlDout,
                   pendReadNotFull, pendReadValid, pendReadDout,
                   childReqPutReady, childRespQValid, childRespQDout,
                   dmaReqReady, dmaRespValid, dmaRespIn) is
      variable v : RegType;
      -- recvReq (R1) datapath off U_ReqQ front (DmaReadCntrlReq layout)
      variable sglIdxInt  : integer range 0 to 7;
      variable sgeHi      : integer range 252 to 1162;
      variable sge        : slv(129 downto 0);  -- selected sgl[sglIdx]
      variable sgeLen     : slv(31 downto 0);
      variable mergedByte : slv(5 downto 0);    -- calcLastFragValidByteNum
      variable sqpnR1     : slv(23 downto 0);
      variable wrIdR1     : slv(63 downto 0);
      -- issueChunkReq (R2) datapath off U_PendingScatterGatherElemQ front
      variable sge2  : slv(129 downto 0);
      variable pmtu2 : slv(2 downto 0);
      -- issueDmaReq (R3) datapath off child resp / lkey / pending-cntrl fronts
      variable chunkAddr    : slv(63 downto 0);
      variable chunkLen     : slv(12 downto 0);
      variable mrIdx        : slv(6 downto 0);
      variable curSqpn      : slv(23 downto 0);
      variable curWrID      : slv(63 downto 0);
      variable dmaReadReqV  : slv(175 downto 0);
      variable isFirstChunk : sl;                 -- isFirstDmaReqChunk
      variable isLastChunk  : sl;                 -- isLastDmaReqChunk
      -- recvDmaResp (R4) datapath
      variable isFirstFrag : sl;                 -- isFirstFragInSGL
      variable isLastFrag  : sl;                 -- isLastFragInSGL
   begin
      v := r;

      ----------------------------------------------------------------------
      -- Combinational datapath extraction (harmless every cycle; committed
      -- only under the corresponding rule guard below).
      ----------------------------------------------------------------------
      -- R1: select sgl[sglIdx] (element 0 at MSB; OQ-FSM-DRCG-03).  sgl occupies
      --     reqQDout(1162:123); SGE i at (1162-130*i) downto (1033-130*i).
      sglIdxInt := to_integer(unsigned(r.sglIdxReg));
      sgeHi     := 1162 - 130 * sglIdxInt;
      sge       := reqQDout(sgeHi downto sgeHi - 129);
      sgeLen    := sge(65 downto 34);
      -- calcLastFragValidByteNum(sge.len): residue=len(4:0);
      --   (residue=0 AND len(31:5)/=0) ? 32 : ('0' & residue)
      if (sgeLen(4 downto 0) = "00000") and (unsigned(sgeLen(31 downto 5)) /= 0) then
         mergedByte := "100000";        -- 32
      else
         mergedByte := '0' & sgeLen(4 downto 0);
      end if;
      sqpnR1 := reqQDout(90 downto 67);
      wrIdR1 := reqQDout(66 downto 3);

      -- R2: {sge,pmtu} off the pending-SGE front (133b = sge(132:3) & pmtu(2:0))
      sge2  := pscElemDout(132 downto 3);
      pmtu2 := pscElemDout(2 downto 0);

      -- R3: compose DmaReadReq from child resp / lkey / pending-cntrl fronts.
      chunkAddr    := childRespQDout(80 downto 17);
      chunkLen     := childRespQDout(16 downto 4);
      mrIdx        := lkeyDout(31 downto 25);  -- key2IndexMR (truncateLSB)
      curSqpn      := pendCntrlDout(87 downto 64);
      curWrID      := pendCntrlDout(63 downto 0);
      -- DmaReadReq = initiator & sqpn & wrID & startAddr(=chunkAddr) & len(=chunkLen) & mrIdx
      dmaReadReqV  := DMA_SRC_SQ_RD_C & curSqpn & curWrID & chunkAddr & chunkLen & mrIdx;
      -- isFirstDmaReqChunk = chunk.isFirst AND chunk.isOrigFirst
      -- isLastDmaReqChunk  = chunk.isLast  AND chunk.isOrigLast
      isFirstChunk := childRespQDout(3) and childRespQDout(1);
      isLastChunk  := childRespQDout(2) and childRespQDout(0);

      -- R4: AND the response stream first/last with the chunk SGL-level first/last
      isFirstFrag := dmaRespIn(1) and pendReadDout(1);
      isLastFrag  := dmaRespIn(0) and pendReadDout(0);

      ----------------------------------------------------------------------
      -- Default Mealy outputs / SURF & child drives (deasserted; din/out carry
      -- the combinational front so the Mealy paths are correct when enabled).
      ----------------------------------------------------------------------
      reqQRdEn        <= '0';
      respQWrEn       <= '0';
      respQDin        <= dmaRespIn & isFirstFrag & isLastFrag;  -- 383+1+1=385
      sgeMergedWrEn   <= '0';
      sgeMergedDin    <= mergedByte & sge(1) & sge(0);          -- 6+1+1=8
      pscElemWrEn     <= '0';
      pscElemDin      <= sge & reqQDout(2 downto 0);  -- sge(130) & pmtu(3) (R1 front)
      pscElemRdEn     <= '0';
      lkeyWrEn        <= '0';
      lkeyDin         <= sge2(33 downto 2);           -- sge.lkey (R2 front)
      lkeyRdEn        <= '0';
      pendCntrlWrEn   <= '0';
      pendCntrlDin    <= sqpnR1 & wrIdR1;             -- {sqpn,wrID} (R1 front)
      pendCntrlRdEn   <= '0';
      pendReadWrEn    <= '0';
      pendReadDin     <= isFirstChunk & isLastChunk;  -- 2b (R3 front)
      pendReadRdEn    <= '0';
      dmaReqValid     <= '0';
      dmaReqOut       <= dmaReadReqV;   -- Mealy front; gated by dmaReqValid
      dmaRespReady    <= '0';
      childReqPutWrEn <= '0';
      -- AddrChunkReq = laddr(64) & len(32) & pmtu(3) & isFirst(1) & isLast(1) (R2 front)
      childReqPutDin  <= sge2(129 downto 66) & sge2(65 downto 34) & pmtu2 &
                        sge2(1) & sge2(0);
      childRespGetRdEn <= '0';

      ----------------------------------------------------------------------
      -- (1) CReg cancel() port0: dmaCntrl.cancel() method (cancelEn).
      --     Forwarded into the R1/R2/R3/R5 guards this same cycle; also re-arms
      --     gracefulStop to '0' (port0 write).
      ----------------------------------------------------------------------
      if cancelEn = '1' then
         v.cancel       := '1';
         v.gracefulStop := '0';
      end if;

      ----------------------------------------------------------------------
      -- (2) recvDmaResp (R4): cancel-INDEPENDENT.  Get one DmaReadResp -> enq the
      --     385-bit DmaReadCntrlResp into U_RespQ; on the LAST DMA fragment
      --     retire (deq) one pending-read token.  This drains
      --     U_PendingDmaReadReqQ so R5 can eventually latch while cancelling.
      ----------------------------------------------------------------------
      if (clearAll = '0' and dmaRespValid = '1' and pendReadValid = '1' and
          respQNotFull = '1') then
         dmaRespReady <= '1';           -- get external server response
         respQWrEn    <= '1';           -- enq U_RespQ (respQDin set above)
         if dmaRespIn(0) = '1' then     -- dataStream.isLast -> retire token
            pendReadRdEn <= '1';     -- deq U_PendingDmaReadReqQ (per fragment)
         end if;
      end if;

      ----------------------------------------------------------------------
      -- (3) Pipeline rules on {cancel}.  R1/R2/R3 (RUN_S, !cancel) are mutually
      --     exclusive with R5 (CANCELLING_S, cancel) on v.cancel.  All guard
      --     !clearAll.  R1/R2/R3 are conflict_free over disjoint FIFO pairs.
      ----------------------------------------------------------------------
      if clearAll = '0' then
         if v.cancel = '0' then

            -- R1 recvReq: walk the SGL.  Always emit one MergedMetaDataSGE and
            --   one pending-SGE entry; deq U_ReqQ only on the SGL's last SGE;
            --   enq {sqpn,wrID} only on the first SGE.  Implicit conds: reqQ has
            --   data, both always-written queues have room, and (only when
            --   sge.isFirst) the pending-cntrl queue has room.
            if (reqQValid = '1' and sgeMergedNotFull = '1' and pscElemNotFull = '1' and
                (sge(1) = '0' or pendCntrlNotFull = '1')) then
               sgeMergedWrEn <= '1';  -- enq MergedMetaDataSGE (din set above)
               pscElemWrEn   <= '1';    -- enq {sge,pmtu} (din set below)
               if sge(1) = '1' then     -- sge.isFirst
                  v.totalLenReg := sgeLen;
                  v.sgeNumReg   := "0001";
                  pendCntrlWrEn <= '1';  -- enq {sqpn,wrID} (din set above)
               else
                  v.totalLenReg := slv(unsigned(r.totalLenReg) + unsigned(sgeLen));
                  v.sgeNumReg   := slv(unsigned(r.sgeNumReg) + 1);
               end if;
               if sge(0) = '1' then     -- sge.isLast -> SGL complete
                  reqQRdEn    <= '1';   -- deq U_ReqQ
                  v.sglIdxReg := "000";
               else
                  v.sglIdxReg := slv(unsigned(r.sglIdxReg) + 1);
               end if;
            end if;

            -- R2 issueChunkReq: pop one SGE, push an AddrChunkReq into the child,
            --   stash its lkey.  Implicit conds: pending-SGE has data, child can
            --   accept, lkey queue has room.
            if (pscElemValid = '1' and childReqPutReady = '1' and lkeyNotFull = '1') then
               pscElemRdEn     <= '1';  -- deq U_PendingScatterGatherElemQ
               childReqPutWrEn <= '1';  -- child request.put (din set above)
               lkeyWrEn        <= '1';  -- enq U_PendingLKeyQ (din set above)
            end if;

            -- R3 issueDmaReq: pop one AddrChunkResp, Put one DmaReadReq to
            --   dmaReadSrv, tokenise SGL-level first/last.  On the last CHUNK of
            --   an SGE retire the lkey; on the original-last chunk retire the
            --   pending-cntrl entry.  Implicit conds: child has a resp, lkey and
            --   pending-cntrl have heads, server ready, pending-read has room.
            if (childRespQValid = '1' and lkeyValid = '1' and pendCntrlValid = '1' and
                dmaReqReady = '1' and pendReadNotFull = '1') then
               childRespGetRdEn <= '1';  -- get child response
               dmaReqValid      <= '1';  -- Put external request (dmaReqOut set above)
               pendReadWrEn     <= '1';  -- enq U_PendingDmaReadReqQ (din set above)
               if childRespQDout(2) = '1' then  -- addrChunkResp.isLast (chunk-last)
                  lkeyRdEn <= '1';      -- deq U_PendingLKeyQ
               end if;
               if isLastChunk = '1' then  -- isLastDmaReqChunk (original-last)
                  pendCntrlRdEn <= '1';  -- deq U_PendingDmaCntrlReqQ
               end if;
            end if;

         else
            -- cancel = '1' (CANCELLING_S / STOPPED_S).  R1/R2/R3 blocked.
            -- R5 setGracefulStop: latch once BOTH the response queue and the
            --   pending-read queue have drained.  Reads v.gracefulStop (post-port0;
            --   cancel() may have re-armed it to '0').
            if (v.gracefulStop = '0' and respQValid = '0' and pendReadValid = '0') then
               v.gracefulStop := '1';
            end if;
         end if;
      end if;

      ----------------------------------------------------------------------
      -- (4) resetAndClear (R0) port1 writes: clearAll dominates all rules and
      --     forces the control bits + SGL index to their power-on values (FIFOs
      --     cleared via fifoRst pins; the child clears via its own clearAllI).
      ----------------------------------------------------------------------
      if clearAll = '1' then
         v.cancel       := '0';
         v.gracefulStop := '0';
         v.sglIdxReg    := "000";
      end if;

      -- Synchronous reset (matches BSV mkReg/mkCReg reset values)
      if rst = '1' then
         v := REG_INIT_C;
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
