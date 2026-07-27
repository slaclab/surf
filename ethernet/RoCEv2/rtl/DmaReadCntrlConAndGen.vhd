-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Read-side analogue of DmaWriteCntrl with an embedded address-chunker child
--   server.  It splits each incoming DmaReadCntrlReq into PMTU-sized chunks (via
--   U_AddrChunkSrv), issues one external DmaReadReq per chunk, and re-assembles
--   the streamed DmaReadResp fragments into DmaReadCntrlResps that carry the
--   *original* request's first/last flags.  Cancel / graceful-stop support
--   mirrors DmaWriteCntrl.
--
--   There is NO explicit state-enum register: control is two CReg booleans plus
--   the four FIFO occupancies.  The implied control sub-FSM over
--   {cancel, gracefulStop} (fsm.md §State register):
--     RUN_S        = {cancel=0}            — recvReq/issueDmaReq/recvDmaResp active
--     CANCELLING_S = {cancel=1,grStop=0}   — recvReq/issueDmaReq blocked; recvDmaResp
--                                            keeps draining; respQ autonomously
--                                            discarded (R5, DEVIATION-DRC-01);
--                                            await respQ + pendingRead empty
--     STOPPED_S    = {cancel=1,grStop=1}   — quiesced; isIdle() true
--   {cancel=0,gracefulStop=1} is unreachable.  Emitted as two boolean RegType
--   fields, not an enum.
--
--   The entity is a Server to its caller (srvPort: request Put / response Get,
--   wired through U_ReqQ/U_RespQ) and a Client of the external Server dmaReadSrv
--   (request Put dmaReqOut / response Get dmaRespIn).
--
--   BSV rules implemented (fsm.md §Transition table):
--     resetAndClear (R0) — guard clearAll='1' (LEVEL); clears all four FIFOs via
--                          rst, forces cancel/gracefulStop to '0'.  Dominates all
--                          other rules (every other guards !clearAll).
--     recvReq       (R1) — RUN_S (!cancel); deq U_ReqQ -> enq the whole 198-bit
--                          request into U_PendingDmaCntrlReqQ AND push an
--                          AddrChunkReq (startAddr,totalLen,pmtu) into the child.
--     issueDmaReq   (R2) — RUN_S (!cancel); get one AddrChunkResp from the child,
--                          Put one DmaReadReq to dmaReadSrv, enq a token (the
--                          DmaReadReq + chunk first/last) into U_PendingDmaReadReqQ.
--                          On addrChunkResp.isLast, retire (deq) the matching
--                          U_PendingDmaCntrlReqQ entry (per-original-request cadence).
--     recvDmaResp   (R3) — cancel-INDEPENDENT; get one DmaReadResp from dmaReadSrv,
--                          AND its stream first/last with the chunk's first/last
--                          (isOrigFirst/isOrigLast), enq the 385-bit
--                          DmaReadCntrlResp into U_RespQ.  On dataStream.isLast,
--                          retire (deq) one U_PendingDmaReadReqQ token
--                          (per-DMA-fragment cadence).  This is how the pending-read
--                          queue empties so R4 can latch even while cancelling.
--     setGracefulStop(R4)— CANCELLING_S (cancel && !gracefulStop); latches
--                          gracefulStop:='1' once BOTH U_RespQ and
--                          U_PendingDmaReadReqQ are empty (no in-flight responses).
--     drainRespQ    (R5) — CANCELLING_S/STOPPED_S; DEVIATION-DRC-01 (no BSV
--                          counterpart): discard one U_RespQ entry per cycle and
--                          suppress respOutValid so the stalled caller cannot
--                          race the pop.  Without it, an error landing
--                          mid-retransmission strands respQ (the caller's
--                          payload-gen path stops consuming outside stable RTS)
--                          and R4 never latches — QP DESTROY liveness hang
--                          (see qp-destroy-hang-issue.md).
--     dmaCntrl.cancel()(M0)— Action pulse cancelEn -> cancel:='1' (CReg port0,
--                          same-cycle forwarded into the R1/R2/R4 guards) and
--                          re-arms gracefulStop:='0' (port0).
--     dmaCntrl.isIdle()  — Moore output = r.gracefulStop (CReg port0 read of the
--                          REGISTERED value).
--
--   IMPORTANT — the two pending-FIFO deq conditions are DISTINCT (fsm.md §Notes):
--     U_PendingDmaCntrlReqQ : deq per ORIGINAL request  -> if addrChunkResp.isLast
--                             (childRespQDout(0))  in R2.
--     U_PendingDmaReadReqQ  : deq per DMA FRAGMENT      -> if dataStream.isLast
--                             (dmaRespIn(0))      in R3.
--
--   CReg semantics (fsm.md §CReg semantics) — each mkCReg(2,False) is ONE RegType
--   field, writes applied in port order so reads see the forwarded value:
--     cancel       : v:=r; port0 (cancelEn) sets '1' BEFORE R1/R2/R4 read v.cancel
--                    (same-cycle cancel); port1 (clearAll) clears '0' last (dominates).
--     gracefulStop : port0 read (isIdle) uses r.gracefulStop (pre-update, Moore);
--                    port0 write (cancelEn) re-arms '0'; R4 then sets '1';
--                    port1 (clearAll) clears '0' last (dominates).
--                    Net: clearAll->0; else setGracefulStop->1; else cancelEn->0; else hold.
--
--   Mealy (combinational) request paths (fsm.md §Output style) — MUST NOT be
--   registered (would insert a spurious cycle):
--     dmaReqOut       = composed DmaReadReq (initiator/sqpn/wrID from the pending-
--                       cntrl front + chunkAddr/chunkLen from the child front),
--                       gated by dmaReqValid (R2).
--     childReqPutData = AddrChunkReq (reqQ front startAddr/totalLen/pmtu), gated by
--                       childReqPutWrEn (R1).
--     U_RespQ.din     = DmaReadResp & isOrigFirst & isOrigLast, computed in R3 and
--                       then registered INSIDE the Fifo.
--
--   FIFO clear (OQ-FSM-01 carry-forward, RESOLVED in out/03-fsm/RESOLVED.md):
--     BSV reqQ/respQ/pendingDmaCntrlReqQ/pendingDmaReadReqQ .clear map to asserting
--     each Fifo's rst, OR'd with the structural reset:  fifoRst = rst OR clearAll.
--     surf.FifoSync holds logically empty for the whole asserted window (level-safe;
--     no pulse generator).  Requires GEN_SYNC_FIFO_G=true, RST_ASYNC_G=false,
--     RST_POLARITY_G='1'.  All four FIFOs share fifoRst so the BSV single-cycle
--     simultaneous clear is preserved.  The child clears via its own clearAllI.
--
--   Open-question carry-forwards (see out/04-vhdl/OPEN_QUESTIONS.md and
--   out/03-fsm/DmaReadCntrlConAndGen.fsm.md §Open issues):
--     OQ-FSM-DRCCAG-01 — Stage-1/2 records (mapping.json/modules.json) are wrong
--                        for this entity (fabricated issueReq/recvResp/cancelFlush/
--                        pendingCntReg; two FIFOs + the child missing).  This file
--                        follows the FSM spec / LIVE BSV source: FOUR surf.Fifo
--                        instances + one U_AddrChunkSrv child.
--     OQ-FSM-DRCCAG-02 — clearAll, isSQ and the dmaReadSrv Server-client handshake
--                        are real top-level ports (RESOLVED; enumerated below).
--                        isSQ is retained for interface fidelity only — the child
--                        AddrChunkSrvConAndGen dropped its isSQI port
--                        (OQ-FSM-ACSCAG-02), so isSQ has NO internal sink here.
--     OQ-EMIT-08       — R4 quiescence guard reads respQ-empty AND pendingRead-empty;
--                        FWFT cold latency caveat — verify in Stage 5.  See
--                        out/04-vhdl/OPEN_QUESTIONS.md.
--
--   Bit layouts (BSV deriving(Bits), first-field-at-MSB; fsm.md §Bit layouts,
--   OQ-FSM-H2DS-04 / OQ-FSM-DRCCAG-03):
--
--   DmaReadCntrlReq (198b) — U_ReqQ / U_PendingDmaCntrlReqQ element:
--     [197:194] initiator(4)  [193:170] sqpn(24)   [169:106] wrID(64)
--     [105:42]  startAddr(64) [41:10]   len(32)    [9:3]     mrIdx(7)
--     [2:0]     pmtu(3)
--   DmaReadReq (176b) — dmaReqOut / U_PendingDmaReadReqQ.dmaReadReq part:
--     [175:172] initiator(4)  [171:148] sqpn(24)   [147:84] wrID(64)
--     [83:20]   startAddr(64) [19:7]    len(13,PktLen) [6:0] mrIdx(7)
--   DmaReadResp (383b) — dmaRespIn:
--     [382:379] initiator(4)  [378:355] sqpn(24)   [354:291] wrID(64)
--     [290] isRespErr  [289:34] data(256)  [33:2] byteEn(32)  [1] isFirst  [0] isLast
--   DmaReadCntrlResp (385b) — U_RespQ element:
--     [384:2] dmaReadResp(383)  [1] isOrigFirst  [0] isOrigLast
--   Tuple3#(DmaReadReq,Bool,Bool) (178b) — U_PendingDmaReadReqQ element:
--     [177:2] dmaReadReq(176)  [1] isFirstDmaReqChunk  [0] isLastDmaReqChunk
--   AddrChunkReq (99b) — childReqPutData:
--     [98:35] startAddr(64)  [34:3] totalLen(32)  [2:0] pmtu(3)
--   AddrChunkResp (79b) — childRespQDout:
--     [78:15] chunkAddr(64)  [14:2] chunkLen(13)  [1] isFirst  [0] isLast
--
--   SURF components instantiated (source: surf/base/fifo/rtl/Fifo.vhd):
--     U_ReqQ                : surf.Fifo  DATA_WIDTH_G=198, FWFT, sync, distributed RAM
--                             (DmaReadCntrlReq;  BSV mkFIFOF reqQ)
--     U_RespQ               : surf.Fifo  DATA_WIDTH_G=385, FWFT, sync, distributed RAM
--                             (DmaReadCntrlResp; BSV mkFIFOF respQ)
--     U_PendingDmaCntrlReqQ : surf.Fifo  DATA_WIDTH_G=198, FWFT, sync, distributed RAM
--                             (DmaReadCntrlReq;  BSV mkFIFOF pendingDmaCntrlReqQ)
--     U_PendingDmaReadReqQ  : surf.Fifo  DATA_WIDTH_G=178, FWFT, sync, distributed RAM
--                             (Tuple3;  BSV mkFIFOF pendingDmaReadReqQ).  Distributed
--                             RAM chosen so its enq->notEmpty tracks the BSV timing
--                             that R4's quiescence guard relies on, mirroring the
--                             DmaWriteCntrl U_HasPendQ rationale.  See OQ-EMIT-08.
--   Child entity instantiated:
--     U_AddrChunkSrv : AddrChunkSrvConAndGen (out/04-vhdl/AddrChunkSrvConAndGen.vhd)
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

entity DmaReadCntrlConAndGen is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk          : in  sl;
      rst          : in  sl;            -- active-high synchronous reset
      -- Software clear (cntrlStatus.comm.isReset; synchronous, LEVEL-asserted)
      clearAll     : in  sl;
      -- cntrlStatus.isSQ : forwarded to the child only in BSV, but the child
      -- (AddrChunkSrvConAndGen) dropped its isSQI port (OQ-FSM-ACSCAG-02), so this
      -- input has NO internal sink.  Retained for interface fidelity per
      -- OQ-FSM-DRCCAG-02.
      isSQ         : in  sl;
      -- dmaCntrl.cancel() method (Action pulse): request graceful cancel
      cancelEn     : in  sl;
      -- srvPort.request : Put#(DmaReadCntrlReq)  (caller -> entity, enq to reqQ)
      reqInValid   : in  sl;            -- caller offers a request (wr_en)
      reqInData    : in  slv(197 downto 0);  -- DmaReadCntrlReq packed
      reqInReady   : out sl;            -- entity can accept (reqQ.notFull)
      -- srvPort.response : Get#(DmaReadCntrlResp) (entity -> caller, deq from respQ)
      respOutReady : in  sl;            -- caller takes a response (rd_en)
      respOutValid : out sl;            -- response available (respQ.notEmpty)
      respOutData  : out slv(384 downto 0);  -- DmaReadCntrlResp packed
      -- dmaReadSrv.request : Put#(DmaReadReq)   (entity -> external server, CLIENT)
      dmaReqValid  : out sl;            -- entity offers a request (Mealy)
      dmaReqOut    : out slv(175 downto 0);  -- DmaReadReq packed (Mealy)
      dmaReqReady  : in  sl;            -- external server can accept
      -- dmaReadSrv.response : Get#(DmaReadResp) (external server -> entity, CLIENT)
      dmaRespValid : in  sl;            -- external server offers a response
      dmaRespIn    : in  slv(382 downto 0);  -- DmaReadResp packed
      dmaRespReady : out sl;            -- entity takes the response (get/pop)
      -- dmaCntrl.isIdle() method result (Moore, registered)
      isIdle       : out sl);
end entity DmaReadCntrlConAndGen;

architecture rtl of DmaReadCntrlConAndGen is

   -- Control sub-FSM state lives in two boolean fields (mkCReg(2,False) each).
   -- Documented implied states: RUN_S/CANCELLING_S/STOPPED_S (fsm.md §State).
   type RegType is record
      cancel       : sl;                -- cancelReg[2] <- mkCReg(2,False)
      gracefulStop : sl;  -- gracefulStopReg[2] <- mkCReg(2,False)
   end record RegType;

   constant REG_INIT_C : RegType := (
      cancel       => '0',
      gracefulStop => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- U_ReqQ interface signals (DmaReadCntrlReq, 198b)
   signal reqQNotFull : sl;
   signal reqQValid   : sl;             -- = reqQ.notEmpty (FWFT data valid)
   signal reqQDout    : slv(197 downto 0);
   signal reqQRdEn    : sl;

   -- U_RespQ interface signals (DmaReadCntrlResp, 385b)
   signal respQNotFull : sl;
   signal respQValid   : sl;            -- = respQ.notEmpty
   signal respQWrEn    : sl;
   signal respQDin     : slv(384 downto 0);
   signal respQRdEn    : sl;  -- caller pop OR cancel drain (DEVIATION-DRC-01)

   -- U_PendingDmaCntrlReqQ interface signals (DmaReadCntrlReq, 198b)
   signal pendCntrlNotFull : sl;
   signal pendCntrlValid   : sl;        -- = notEmpty
   signal pendCntrlWrEn    : sl;
   signal pendCntrlDin     : slv(197 downto 0);
   signal pendCntrlRdEn    : sl;
   signal pendCntrlDout    : slv(197 downto 0);

   -- U_PendingDmaReadReqQ interface signals (Tuple3, 178b)
   signal pendReadNotFull : sl;
   signal pendReadValid   : sl;         -- = notEmpty (R4 quiescence guard)
   signal pendReadWrEn    : sl;
   signal pendReadDin     : slv(177 downto 0);
   signal pendReadRdEn    : sl;
   signal pendReadDout    : slv(177 downto 0);

   -- U_AddrChunkSrv child interface signals
   signal childReqPutWrEn  : sl;        -- FSM (recvReq) -> child request.put
   signal childReqPutDin   : slv(98 downto 0);
   signal childReqPutReady : sl;  -- child reqQ.notFull (R1 implicit cond)
   signal childRespGetRdEn : sl;  -- FSM (issueDmaReq) -> child response.get
   signal childRespQValid  : sl;  -- child respQ.notEmpty (R2 implicit cond)
   signal childRespQDout   : slv(78 downto 0);

   -- FIFO reset line: level = rst OR clearAll (atomic 4-FIFO clear)
   signal fifoRst : sl;

begin

   -- FIFO reset: level-sensitive clear (OQ-FSM-01 carry-forward, RESOLVED)
   fifoRst <= rst or clearAll;

   -- srvPort boundary wiring (pass-through; not FSM-gated)
   reqInReady   <= reqQNotFull;         -- reqQ.notFull readiness to caller
   -- DEVIATION-DRC-01: responses are withheld from the caller while cancelling
   -- (registered cancel, Moore) — the R5 drain owns the respQ read side from
   -- the cycle after cancelEn; the caller only asserts respOutReady when it
   -- sees respOutValid, so there is no double-pop window.
   respOutValid <= respQValid and not r.cancel;

   -- isIdle() method (Moore): registered gracefulStop (CReg port0 read of the
   -- REGISTERED value).  Drive from r, NOT v.
   isIdle <= r.gracefulStop;

   ---------------------------------------------------------------------------
   -- U_ReqQ : surf.Fifo
   --   Inbound DmaReadCntrlReq queue (BSV mkFIFOF reqQ).  wr side = caller's
   --   srvPort.request.put (pass-through); rd side = FSM (recvReq deq).
   ---------------------------------------------------------------------------
   U_ReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 198,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoRst,
         wr_clk        => clk,
         wr_en         => reqInValid,   -- pass-through (caller drives)
         din           => reqInData,    -- pass-through (caller drives)
         full          => open,
         not_full      => reqQNotFull,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => reqQRdEn,     -- FSM (recvReq)
         dout          => reqQDout,
         valid         => reqQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_RespQ : surf.Fifo
   --   Outbound DmaReadCntrlResp queue (BSV mkFIFOF respQ).  wr side = FSM
   --   (recvDmaResp enq); rd side = caller's srvPort.response.get (pass-through).
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
         rst           => fifoRst,
         wr_clk        => clk,
         wr_en         => respQWrEn,    -- FSM (recvDmaResp)
         din           => respQDin,     -- FSM (recvDmaResp)
         full          => open,
         not_full      => respQNotFull,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => respQRdEn,  -- FSM: caller pop / cancel drain (DEVIATION-DRC-01)
         dout          => respOutData,
         valid         => respQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_PendingDmaCntrlReqQ : surf.Fifo
   --   Holds the whole 198-bit original request while its chunks are issued.
   --   wr = FSM (recvReq); rd = FSM (issueDmaReq, deq per ORIGINAL request, i.e.
   --   on the LAST addr chunk).  Only notFull/notEmpty + dout consumed.
   ---------------------------------------------------------------------------
   U_PendingDmaCntrlReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 198,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoRst,
         wr_clk        => clk,
         wr_en         => pendCntrlWrEn,  -- FSM (recvReq)
         din           => pendCntrlDin,   -- FSM (recvReq) = reqQDout
         full          => open,
         not_full      => pendCntrlNotFull,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => pendCntrlRdEn,  -- FSM (issueDmaReq, per original req)
         dout          => pendCntrlDout,
         valid         => pendCntrlValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_PendingDmaReadReqQ : surf.Fifo
   --   One token per issued DMA-read chunk (DmaReadReq + chunk first/last).
   --   wr = FSM (issueDmaReq); rd = FSM (recvDmaResp, deq per DMA FRAGMENT, i.e.
   --   on dataStream.isLast).  R4's graceful-stop guard reads its notEmpty, so
   --   distributed RAM is used (enq->notEmpty timing fidelity; see OQ-EMIT-08,
   --   mirrors DmaWriteCntrl U_HasPendQ).
   ---------------------------------------------------------------------------
   U_PendingDmaReadReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 178,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoRst,
         wr_clk        => clk,
         wr_en         => pendReadWrEn,  -- FSM (issueDmaReq)
         din           => pendReadDin,   -- FSM (issueDmaReq)
         full          => open,
         not_full      => pendReadNotFull,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => pendReadRdEn,  -- FSM (recvDmaResp, per DMA fragment)
         dout          => pendReadDout,
         valid         => pendReadValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_AddrChunkSrv : AddrChunkSrvConAndGen (child entity, not SURF)
   --   BSV: addrChunkSrv <- mkAddrChunkSrv(clearAll, cntrlStatus.isSQ).
   --   The child has its own clearAllI (internal clear) and does NOT expose an
   --   isSQI port (OQ-FSM-ACSCAG-02), so the parent's isSQ is not wired here.
   --   Treated as a Server pair: parent drives request.put / response.get.
   ---------------------------------------------------------------------------
   U_AddrChunkSrv : entity surf.AddrChunkSrvConAndGen
      generic map (
         TPD_G => TPD_G)
      port map (
         clk          => clk,
         rst          => rst,
         clearAllI    => clearAll,
         reqPutValid  => childReqPutWrEn,
         reqPutData   => childReqPutDin,
         reqPutReady  => childReqPutReady,
         respGetReady => childRespGetRdEn,
         respGetValid => childRespQValid,
         respGetData  => childRespQDout,
         isIdle       => open);         -- parent does not read child isIdle

   ---------------------------------------------------------------------------
   -- Combinatorial process
   --   Emit order (fsm.md §Conflicts/scheduling §Suggested comb order):
   --     1) cancel() port0 (cancelEn) forwarded into v.cancel / v.gracefulStop
   --     2) recvDmaResp (R3) — cancel-independent
   --     3) R1/R2/R4 evaluated off v.cancel and v.gracefulStop + FIFO/child flags
   --     4) setGracefulStop is part of (3); resetAndClear (R0) port1 writes last
   ---------------------------------------------------------------------------
   comb : process (r, rst, clearAll, cancelEn,
                   reqQValid, reqQDout,
                   respQNotFull, respQValid, respOutReady,
                   pendCntrlNotFull, pendCntrlValid, pendCntrlDout,
                   pendReadNotFull, pendReadValid, pendReadDout,
                   childReqPutReady, childRespQValid, childRespQDout,
                   dmaReqReady, dmaRespValid, dmaRespIn) is
      variable v : RegType;
      -- recvReq (R1) datapath off U_ReqQ front (DmaReadCntrlReq layout)
      variable startAddr    : slv(63 downto 0);
      variable totalLen     : slv(31 downto 0);
      variable pmtu         : slv(2 downto 0);
      variable chunkReqData : slv(98 downto 0);   -- AddrChunkReq to child
      -- issueDmaReq (R2) datapath off pending-cntrl front + child resp front
      variable initiator    : slv(3 downto 0);
      variable sqpn         : slv(23 downto 0);
      variable wrID         : slv(63 downto 0);
      variable mrIdx        : slv(6 downto 0);
      variable chunkAddr    : slv(63 downto 0);
      variable chunkLen     : slv(12 downto 0);
      variable chunkIsFirst : sl;
      variable chunkIsLast  : sl;
      variable dmaReadReq   : slv(175 downto 0);  -- DmaReadReq to dmaReadSrv
      -- recvDmaResp (R3) datapath
      variable isOrigFirst : sl;
      variable isOrigLast  : sl;
   begin
      v := r;

      ----------------------------------------------------------------------
      -- Combinational datapath extraction (harmless to compute every cycle;
      -- only committed under the corresponding rule guard below).
      ----------------------------------------------------------------------
      -- recvReq (R1): AddrChunkReq = startAddr(64) & totalLen(32) & pmtu(3)
      startAddr    := reqQDout(105 downto 42);
      totalLen     := reqQDout(41 downto 10);
      pmtu         := reqQDout(2 downto 0);
      chunkReqData := startAddr & totalLen & pmtu;

      -- issueDmaReq (R2): compose DmaReadReq from the pending-cntrl front and
      -- the child's AddrChunkResp front.
      initiator    := pendCntrlDout(197 downto 194);
      sqpn         := pendCntrlDout(193 downto 170);
      wrID         := pendCntrlDout(169 downto 106);
      mrIdx        := pendCntrlDout(9 downto 3);
      chunkAddr    := childRespQDout(78 downto 15);
      chunkLen     := childRespQDout(14 downto 2);
      chunkIsFirst := childRespQDout(1);
      chunkIsLast  := childRespQDout(0);
      -- DmaReadReq = initiator & sqpn & wrID & startAddr(=chunkAddr) & len(=chunkLen) & mrIdx
      dmaReadReq   := initiator & sqpn & wrID & chunkAddr & chunkLen & mrIdx;

      -- recvDmaResp (R3): AND the response stream first/last with the chunk's
      -- first/last so the re-assembled stream reports the ORIGINAL boundaries.
      isOrigFirst := dmaRespIn(1) and pendReadDout(1);
      isOrigLast  := dmaRespIn(0) and pendReadDout(0);

      ----------------------------------------------------------------------
      -- Default Mealy outputs / SURF & child drives (deasserted / front data).
      -- The "din"/"out" defaults carry the combinational front so the Mealy
      -- paths are correct whenever their enable is asserted below.
      ----------------------------------------------------------------------
      reqQRdEn         <= '0';
      respQWrEn        <= '0';
      respQDin         <= dmaRespIn & isOrigFirst & isOrigLast;  -- 383+1+1=385
      respQRdEn        <= respOutReady;  -- srvPort.response.get pass-through (RUN_S)
      pendCntrlWrEn    <= '0';
      pendCntrlDin     <= reqQDout;     -- enq whole 198-bit request (R1)
      pendCntrlRdEn    <= '0';
      pendReadWrEn     <= '0';
      pendReadDin      <= dmaReadReq & chunkIsFirst & chunkIsLast;  -- 176+1+1=178
      pendReadRdEn     <= '0';
      dmaReqValid      <= '0';
      dmaReqOut        <= dmaReadReq;   -- Mealy front; gated by dmaReqValid
      dmaRespReady     <= '0';
      childReqPutWrEn  <= '0';
      childReqPutDin   <= chunkReqData;  -- Mealy front; gated by childReqPutWrEn
      childRespGetRdEn <= '0';

      ----------------------------------------------------------------------
      -- (1) CReg cancel() port0: dmaCntrl.cancel() method (cancelEn).
      --     Forwarded into the R1/R2/R4 guards this same cycle (same-cycle
      --     cancel); also re-arms gracefulStop to '0' (port0 write).
      ----------------------------------------------------------------------
      if cancelEn = '1' then
         v.cancel       := '1';
         v.gracefulStop := '0';
      end if;

      ----------------------------------------------------------------------
      -- (2) recvDmaResp (R3): cancel-INDEPENDENT.  Get one DmaReadResp ->
      --     enq the 385-bit DmaReadCntrlResp into U_RespQ; on the LAST DMA
      --     fragment retire (deq) one pending-read token.  This drains
      --     U_PendingDmaReadReqQ so R4 can eventually latch while cancelling.
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
      -- (3) Forwarding path on {cancel, gracefulStop} (all guard !clearAll).
      --     R1/R2 (RUN_S, !cancel) are mutually exclusive with R4
      --     (CANCELLING_S, cancel) on v.cancel.
      ----------------------------------------------------------------------
      if clearAll = '0' then
         if v.cancel = '0' then
            -- R1 recvReq: deq U_ReqQ; enq the whole request into the pending-
            --   cntrl queue; push an AddrChunkReq into the child.  Implicit
            --   conds: reqQ has data, pending-cntrl has room, child can accept.
            if (reqQValid = '1' and pendCntrlNotFull = '1' and
                childReqPutReady = '1') then
               reqQRdEn        <= '1';  -- deq U_ReqQ
               pendCntrlWrEn   <= '1';  -- enq U_PendingDmaCntrlReqQ (din=reqQDout)
               childReqPutWrEn <= '1';  -- child request.put (din=chunkReqData)
            end if;

            -- R2 issueDmaReq: get one AddrChunkResp from the child, Put one
            --   DmaReadReq to dmaReadSrv, enq a pending-read token.  On the LAST
            --   chunk of the request, retire the pending-cntrl entry.  Implicit
            --   conds: child has a resp, pending-cntrl has a head, server ready,
            --   pending-read has room.
            if (childRespQValid = '1' and pendCntrlValid = '1' and
                dmaReqReady = '1' and pendReadNotFull = '1') then
               childRespGetRdEn <= '1';  -- get child response
               dmaReqValid      <= '1';  -- Put external request (dmaReqOut set above)
               pendReadWrEn     <= '1';  -- enq U_PendingDmaReadReqQ (din set above)
               if chunkIsLast = '1' then  -- addrChunkResp.isLast -> request done
                  pendCntrlRdEn <= '1';  -- deq U_PendingDmaCntrlReqQ (per original req)
               end if;
            end if;

         else
            -- cancel = '1' (CANCELLING_S / STOPPED_S).  R1/R2 blocked.
            -- R5 drainRespQ (DEVIATION-DRC-01, 2026-07-13): autonomously discard
            --   stranded DmaReadCntrlResps while cancelling.  Upstream blue-rdma
            --   waits for the caller to drain respQ, but the caller (payload
            --   generator -> header generation) stops consuming once the QP
            --   leaves stable RTS; an error landing mid-retransmission (e.g.
            --   RNR-retry exhaustion) strands respQ and R4 never latches — QP
            --   DESTROY liveness hang (see qp-destroy-hang-issue.md).  Gated on
            --   the REGISTERED cancel so the cancelEn transition cycle keeps a
            --   single respQ reader (respOutValid is suppressed off r.cancel
            --   the same cycle this rule arms).  R3 keeps running so remaining
            --   external DMA responses still retire pendingRead tokens.
            if (r.cancel = '1' and respQValid = '1') then
               respQRdEn <= '1';
            end if;
            -- R4 setGracefulStop: latch once both the response queue and the
            --   pending-read queue have drained (no in-flight responses).  Reads
            --   v.gracefulStop (post-port0; cancel() may have re-armed it to '0').
            if (v.gracefulStop = '0' and respQValid = '0' and
                pendReadValid = '0') then
               v.gracefulStop := '1';
            end if;
         end if;
      end if;

      ----------------------------------------------------------------------
      -- (4) resetAndClear (R0) port1 writes: clearAll dominates all rules and
      --     forces both control bits to '0' (FIFOs cleared via fifoRst pins;
      --     the child clears via its own clearAllI).
      ----------------------------------------------------------------------
      if clearAll = '1' then
         v.cancel       := '0';
         v.gracefulStop := '0';
      end if;

      -- Synchronous reset (matches BSV mkCReg(_,False) reset)
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
