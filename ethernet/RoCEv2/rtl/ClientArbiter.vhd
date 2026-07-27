-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Dual of mkServerArbiter. Multiplexes PORT_COUNT_G upstream *client* request
--   streams onto ONE downstream client face, tagging each request with its
--   origin port index so the matching response is routed back to that port.
--   ClientArbiter is the MASTER of each clientVec[k]: it *gets* requests from
--   client k and *puts* responses to client k. The single returned Client
--   (toGPClient(reqQ, respQ)) is the shared downstream resource this arbiter
--   feeds.
--
--   BSV owns ONE register (shouldSaveGrantIdxReg), PORT_COUNT_G+2 rules
--   (extractReq[k] ×portSz, issueArbitratedReq, dispatchResponse), four FIFO
--   groups (inputReqWithIdxVec[k], reqQ, respQ, preGrantIdxQ) and the arbitration
--   tree (mkLeafBinaryPipeOutArbiterVec -> mkBinaryPipeOutArbiterTree). This is a
--   1-flag flow-control wrapper around the arbitration tree — no multi-state
--   enum; shouldSaveGrantIdxReg is a burst-boundary flag ('1' => next issued
--   request starts a new burst -> record its grant index in preGrantIdxQ).
--
--   OQ-FSM-CLTARB-01 (RESOLVED — inventory/partition mis-model this entity):
--     ClientArbiter.fsm.md (built from source) is AUTHORITATIVE: the child is
--     the arbitration tree = PipeOutArbiter (NOT ServerArbiter), and the owned
--     FSM/FIFOs are emitted here.
--
--   OQ-FSM-PERMARB-01 (RESOLVED — generic re-emit, supersedes the fixed-4 emit):
--     every concrete specialization (mkPermCheckCltArbiter, mkDmaReadCltArbiter,
--     mkDmaWriteCltArbiter, instantiated in TransportLayer.bsv over
--     qpPermCheckSrvVec / qpDmaReadCltVec / qpDmaWriteCltVec) uses
--     portSz = TMul#(2, MAX_QP) = 8 (one RQ-side + one SQ-side client per QP),
--     NOT MAX_QP = 4 as the inventory previously claimed. This entity is
--     therefore emitted GENERIC over PORT_COUNT_G (any power of 2, >= 2;
--     derived IDX_WIDTH_C = log2(PORT_COUNT_G)) with vectored/flattened
--     per-client ports built by generate statements, and the wrappers
--     instantiate it with PORT_COUNT_G => 2*MAX_QP_G = 8 (idxW = 3, full
--     8-input tree: 4 leaf + 2 mid + 1 top BinaryPipeOutArbiters, 3 levels).
--     The power-of-2 proviso and the FFT bit-reverse leaf permutation live in
--     the child tree (BinaryArbTree, via PipeOutArbiter); a matching local
--     assert below fails elaboration early with a ClientArbiter-specific
--     message.
--
--   OQ-FSM-17 (predicate handling) — cltReqFinished / outRespFinished input
--   ports: BSV isReqFinished / isRespFinished are elaboration-time function
--   arguments; VHDL has no function-type ports, so the parent (where the concrete
--   type is known) computes them and feeds them as 1-bit combinational inputs.
--   Concrete values are trivial (PermCheck req+resp both constant True -> tie '1';
--   DmaRead isRespFinished = resp.dataStream.isLast; DmaWrite isReqFinished =
--   req.dataStream.isLast). Because each predicate is a PURE function of its
--   payload, the bit is sampled at ENQUEUE and carried as a companion THROUGH the
--   relevant FIFO (same established resolution as ServerArbiter):
--     * REQUEST  predicate cltReqFinished(k) -> stored top bit of U_InReqQ(k)
--       element {finished, idx, req}; the arbiter's per-channel inFinished(k)
--       input reads that stored bit, and its outFinished companion ==
--       isReqFinished of the arbitrated request, which drives
--       shouldSaveGrantIdxReg.
--     * RESPONSE predicate outRespFinished -> stored top bit of U_RespQ element
--       {finished, resp}; dispatchResponse reads it as respFinished (release the
--       grant index only at response-burst end).
--
--   Payload layout (BSV pack(tuple2(reqIdx, inputReq)) = {reqIdx, inputReq},
--   reqIdx in the HIGH bits):
--       arbiter payload width = IDX_WIDTH_C + REQ_WIDTH_G   (= REQIDX_WIDTH_C)
--       inputReq = arbDout(REQ_WIDTH_G-1 downto 0)
--       reqIdx   = arbDout(REQIDX_WIDTH_C-1 downto REQ_WIDTH_G)
--   In extractReq[k], din = {cltReqFinished(k), idx=const k, req slice k}, idx
--   in the HIGH-of-payload bits (below the finished companion), req in the low
--   bits. Per-client flattened buses: client k's request payload is
--   cltReqData((k+1)*REQ_WIDTH_G-1 downto k*REQ_WIDTH_G), and likewise for
--   cltRespData with RESP_WIDTH_G.
--
--   Rules & scheduling (ClientArbiter.fsm.md):
--     * extractReq[k] (×PORT_COUNT_G) — mutually independent (disjoint ports);
--       each is pure combinational interface wiring: on cltReqValid(k) & room,
--       get client k's request and enqueue {finished,k,req} into U_InReqQ(k).
--       Emitted as a generate of continuous assignments.
--     * issueArbitratedReq vs dispatchResponse — disjoint registers, different
--       ports of preGrantIdxQ (issue -> enq, dispatch -> first/deq); conflict-free,
--       both may fire the same cycle. Emitted as two independent `if ...FiresEn`
--       blocks, no priority.
--       issueArbitratedReq guard : arbNotEmpty AND U_ReqQ.notFull
--                                  AND ((NOT shouldSave) OR preGrantNotFull)
--         -- preGrantIdxQ.enq is CONDITIONAL on shouldSaveGrantIdxReg, so the
--            rule may fire when the flag is '0' even if preGrantIdxQ is full
--            (BSV conditional-method implicit condition). MUST NOT gate issue
--            unconditionally on notFull.
--       dispatchResponse   guard : preGrantNotEmpty AND U_RespQ.notEmpty
--                                  AND cltRespReady(preGrantIdx)
--         -- the response put targets clientVec[preGrantIdx], so the readiness
--            term is the SELECTED client's cltRespReady bit (indexed by
--            preGrantIdx), NOT all-ports-ready.
--
--   Mealy: all strobes/data are combinational functions of FIFO/handshake status,
--   arbDout and r.shouldSaveGrantIdxReg. Only shouldSaveGrantIdxReg is registered.
--   Data persistence lives in the surf.Fifo instances, not FSM regs.
--
--   Child entity instantiated:
--     * U_ReqArb : work.PipeOutArbiter (generic vectored tree = BinaryArbTree,
--       PORT_COUNT_G forwarded; PORT_COUNT_G-1 BinaryPipeOutArbiters)
--       source: out/04-vhdl/PipeOutArbiter.vhd
--
--   SURF components instantiated (all BSV mkFIFOF -> surf.Fifo):
--     * GEN_PORT(k).U_InReqQ : surf.Fifo <- inputReqWithIdxVec[k] ({finished,idx,req})
--     * U_ReqQ      : surf.Fifo <- reqQ         (reqType, downstream)
--     * U_RespQ     : surf.Fifo <- respQ        ({finished,resp})
--     * U_PreGrantQ : surf.Fifo <- preGrantIdxQ (Bit#(idxW))
--       source: surf/base/fifo/rtl/Fifo.vhd
--     FWFT_EN_G => true so `valid` = head-present = BSV notEmpty. BSV mkFIFOF is
--     depth 2; surf.Fifo minimum ADDR_WIDTH is 4 (depth 16). Functionally a
--     buffering FIFO; depth differs and there is an inherent ~1-cycle write->valid
--     read latency vs BSV mkFIFOF — functionally equivalent, NOT cycle-accurate.
--
--   NOTE: emitting does not prove equivalence — simulate this entity against
--   the BSV behaviour before trusting it.
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

entity ClientArbiter is
   generic (
      TPD_G             : time                   := 1 ns;
      RST_POLARITY_G    : sl                     := '1';  -- '1' active HIGH reset, '0' active LOW
      RST_ASYNC_G       : boolean                := false;
      PORT_COUNT_G      : positive               := 8;  -- upstream client ports; any power of 2, >= 2 (OQ-FSM-PERMARB-01); concrete BSV use = 2*MAX_QP = 8
      REQ_WIDTH_G       : positive               := 8;  -- Bits#(reqType)
      RESP_WIDTH_G      : positive               := 8;  -- Bits#(respType)
      MEMORY_TYPE_G     : string                 := "distributed";  -- FIFO RAM style
      FIFO_ADDR_WIDTH_G : positive range 4 to 48 := 4);  -- FIFO depth = 2**ADDR (BSV mkFIFOF depth 2; SURF min 4)
   port (
      clk             : in  sl;
      rst             : in  sl := not RST_POLARITY_G;
      -- Per-port upstream client faces (clientVec[k], k = 0..PORT_COUNT_G-1;
      -- arbiter is master). Client k's payload slice is
      -- ((k+1)*WIDTH-1 downto k*WIDTH) of the flattened data buses.
      cltReqValid     : in  slv(PORT_COUNT_G-1 downto 0);  -- client k request available (request.get implicit cond)
      cltReqData      : in  slv(PORT_COUNT_G*REQ_WIDTH_G-1 downto 0);  -- client k request payload, flattened
      cltReqFinished  : in  slv(PORT_COUNT_G-1 downto 0);  -- isReqFinished(cltReqData slice k) (OQ-FSM-17), sampled at enqueue
      cltReqGet       : out slv(PORT_COUNT_G-1 downto 0);  -- ClientArbiter takes client k's request (request.get fired)
      cltRespValid    : out slv(PORT_COUNT_G-1 downto 0);  -- ClientArbiter drives a response to client k (response.put fired; one-hot on preGrantIdx)
      cltRespData     : out slv(PORT_COUNT_G*RESP_WIDTH_G-1 downto 0);  -- response payload (respQ.first broadcast to every slice; cltRespValid selects the port)
      cltRespReady    : in  slv(PORT_COUNT_G-1 downto 0);  -- client k can accept a response (response.put ready)
      -- Downstream shared Client face (toGPClient(reqQ, respQ))
      outReqValid     : out sl;  -- request.first valid (U_ReqQ notEmpty)
      outReqData      : out slv(REQ_WIDTH_G-1 downto 0);  -- request.first (U_ReqQ dout)
      outReqRd        : in  sl;         -- downstream request.get (U_ReqQ deq)
      outRespValid    : in  sl;         -- downstream response.put fired
      outRespData     : in  slv(RESP_WIDTH_G-1 downto 0);  -- response payload from downstream
      outRespFinished : in  sl;  -- isRespFinished(outRespData) (OQ-FSM-17), sampled at enqueue
      outRespReady    : out sl);  -- response can accept a put (U_RespQ notFull)
end entity ClientArbiter;

architecture rtl of ClientArbiter is

   -- idxW = TLog#(PORT_COUNT_G); for the concrete PORT_COUNT_G=8 -> 3
   -- (OQ-FSM-PERMARB-01).
   constant IDX_WIDTH_C    : positive := log2(PORT_COUNT_G);
   -- Arbiter payload = {reqIdx, inputReq} (reqIdx in the HIGH bits).
   constant REQIDX_WIDTH_C : positive := IDX_WIDTH_C + REQ_WIDTH_G;
   -- Per-port input FIFO element = {finished, idx, req}.
   constant INREQ_WIDTH_C  : positive := 1 + REQIDX_WIDTH_C;
   -- Downstream response FIFO element = {finished, resp}.
   constant RESPQ_WIDTH_C  : positive := 1 + RESP_WIDTH_G;

   -- Only registered state (BSV mkReg(True)). Burst-boundary flag, not a state
   -- selector: '1' => next issued request starts a new burst (record its grant
   -- index in preGrantIdxQ); '0' => mid-burst continuation (index already saved).
   type RegType is record
      shouldSaveGrantIdxReg : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      shouldSaveGrantIdxReg => '1');    -- BSV mkReg(True)

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- GEN_PORT(k).U_InReqQ (surf.Fifo, element {finished,idx,req}) status/handshake.
   type InReqDoutArrayType is array (natural range <>) of slv(INREQ_WIDTH_C-1 downto 0);
   signal inReqQNotFull : slv(PORT_COUNT_G-1 downto 0);
   signal inReqQValid   : slv(PORT_COUNT_G-1 downto 0);
   signal inReqQDout    : InReqDoutArrayType(PORT_COUNT_G-1 downto 0);
   signal inReqQWrEn    : slv(PORT_COUNT_G-1 downto 0);
   signal inReqQDin     : InReqDoutArrayType(PORT_COUNT_G-1 downto 0);
   signal inReqQRd      : slv(PORT_COUNT_G-1 downto 0);

   -- U_ReqArb (PipeOutArbiter) vectored inputs (flattened) + arbitrated PipeOut
   -- output.
   signal arbInDout     : slv(PORT_COUNT_G*REQIDX_WIDTH_C-1 downto 0);
   signal arbInFinished : slv(PORT_COUNT_G-1 downto 0);
   signal arbNotEmpty   : sl;
   signal arbDout       : slv(REQIDX_WIDTH_C-1 downto 0);  -- {reqIdx, inputReq}
   signal arbFinished   : sl;  -- isReqFinished(inputReq), buffered head bit
   signal arbDeq        : sl;

   -- U_ReqQ (surf.Fifo, element reqType) — downstream request queue.
   signal reqQNotFull  : sl;
   signal reqQNotEmpty : sl;
   signal reqQDout     : slv(REQ_WIDTH_G-1 downto 0);
   signal reqQWrEn     : sl;
   signal reqQDin      : slv(REQ_WIDTH_G-1 downto 0);
   signal reqQRd       : sl;

   -- U_RespQ (surf.Fifo, element {finished,resp}) — downstream response queue.
   signal respQNotFull  : sl;
   signal respQNotEmpty : sl;
   signal respQDout     : slv(RESPQ_WIDTH_C-1 downto 0);
   signal respQWrEn     : sl;
   signal respQDin      : slv(RESPQ_WIDTH_C-1 downto 0);
   signal respQRd       : sl;

   -- U_PreGrantQ (surf.Fifo, element Bit#(idxW)) status/handshake.
   signal preGrantNotFull  : sl;
   signal preGrantNotEmpty : sl;
   signal preGrantDout     : slv(IDX_WIDTH_C-1 downto 0);
   signal preGrantWrEn     : sl;
   signal preGrantDin      : slv(IDX_WIDTH_C-1 downto 0);
   signal preGrantRdEn     : sl;

begin

   -- BSV power-of-2 proviso (OQ-FSM-PERMARB-01). The child tree
   -- (PipeOutArbiter -> BinaryArbTree) carries the same guard; this local copy
   -- names the offending entity when a wrapper mis-parameterizes.
   assert isPowerOf2(PORT_COUNT_G) and (PORT_COUNT_G >= 2)
      report "ClientArbiter: PORT_COUNT_G must be a power of 2 and >= 2 " &
      "(BSV arbitration-tree proviso; OQ-FSM-PERMARB-01)"
      severity failure;

   --------------------------------------------------------------------------
   -- Per-port request input FIFOs (BSV inputReqWithIdxVec[k] = mkFIFOF) and
   --   rule extractReq[k] : pure interface wiring of clientVec[k].request.get.
   --   On cltReqValid(k) & not_full: get client k's request (cltReqGet(k)
   --   strobe) and enqueue {cltReqFinished(k), idx=const k, req slice k}. Read
   --   side feeds the arbiter's input channel k.
   --------------------------------------------------------------------------
   GEN_PORT : for k in 0 to PORT_COUNT_G-1 generate

      U_InReqQ : entity surf.Fifo
         generic map (
            TPD_G           => TPD_G,
            RST_POLARITY_G  => RST_POLARITY_G,
            RST_ASYNC_G     => RST_ASYNC_G,
            GEN_SYNC_FIFO_G => true,
            FWFT_EN_G       => true,
            MEMORY_TYPE_G   => MEMORY_TYPE_G,
            DATA_WIDTH_G    => INREQ_WIDTH_C,
            ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G)
         port map (
            rst      => rst,
            wr_clk   => clk,
            wr_en    => inReqQWrEn(k),
            din      => inReqQDin(k),
            not_full => inReqQNotFull(k),
            rd_clk   => clk,
            rd_en    => inReqQRd(k),
            dout     => inReqQDout(k),
            valid    => inReqQValid(k));

      -- rule extractReq[k]: independent, pure combinational interface wiring.
      -- Element = {finished, idx=const k, req}; idx in the HIGH-of-payload bits
      -- (below the finished companion), req in the low bits.
      cltReqGet(k)  <= cltReqValid(k) and inReqQNotFull(k);
      inReqQWrEn(k) <= cltReqValid(k) and inReqQNotFull(k);
      inReqQDin(k)  <= cltReqFinished(k) & toSlv(k, IDX_WIDTH_C) &
                      cltReqData((k+1)*REQ_WIDTH_G-1 downto k*REQ_WIDTH_G);

      -- Arbiter input channel k <- U_InReqQ(k) head; the stored finished
      -- companion (top element bit) is the per-channel finish predicate
      -- (OQ-FSM-17).
      arbInDout((k+1)*REQIDX_WIDTH_C-1 downto k*REQIDX_WIDTH_C) <=
         inReqQDout(k)(REQIDX_WIDTH_C-1 downto 0);
      arbInFinished(k) <= inReqQDout(k)(REQIDX_WIDTH_C);

      -- Response payload broadcast (cltRespValid selects the port).
      cltRespData((k+1)*RESP_WIDTH_G-1 downto k*RESP_WIDTH_G) <=
         respQDout(RESP_WIDTH_G-1 downto 0);

   end generate GEN_PORT;

   --------------------------------------------------------------------------
   -- U_ReqArb : generic arbitration tree (mkLeafBinaryPipeOutArbiterVec +
   --   mkBinaryPipeOutArbiterTree = PipeOutArbiter -> BinaryArbTree,
   --   PORT_COUNT_G-1 BinaryPipeOutArbiters, bit-reversed leaf pairing). Its
   --   PORT_COUNT_G PipeOut inputs are the input request FIFO heads; its
   --   outFinished companion = isReqFinished(inputReq) drives
   --   shouldSaveGrantIdxReg.
   --------------------------------------------------------------------------
   U_ReqArb : entity surf.PipeOutArbiter
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         PORT_COUNT_G      => PORT_COUNT_G,
         DATA_WIDTH_G      => REQIDX_WIDTH_C,  -- payload = {idx, req}
         MEMORY_TYPE_G     => MEMORY_TYPE_G,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G)
      port map (
         clk         => clk,
         rst         => rst,
         inValid     => inReqQValid,
         inDout      => arbInDout,
         inFinished  => arbInFinished,
         inRd        => inReqQRd,
         outNotEmpty => arbNotEmpty,
         outDout     => arbDout,
         outFinished => arbFinished,
         outDeq      => arbDeq);

   --------------------------------------------------------------------------
   -- U_ReqQ : BSV reqQ (mkFIFOF reqType). Written by issueArbitratedReq; read
   --   side = pure interface wiring of the downstream Client request (toGet).
   --------------------------------------------------------------------------
   U_ReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => MEMORY_TYPE_G,
         DATA_WIDTH_G    => REQ_WIDTH_G,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G)
      port map (
         rst      => rst,
         wr_clk   => clk,
         wr_en    => reqQWrEn,
         din      => reqQDin,
         not_full => reqQNotFull,
         rd_clk   => clk,
         rd_en    => reqQRd,
         dout     => reqQDout,
         valid    => reqQNotEmpty);

   -- Downstream request face (toGet(reqQ)): expose FIFO head; deq on request.get.
   outReqValid <= reqQNotEmpty;
   outReqData  <= reqQDout;
   reqQRd      <= outReqRd;

   --------------------------------------------------------------------------
   -- U_RespQ : BSV respQ (mkFIFOF respType). Write side = pure interface wiring
   --   of the downstream Client response (toPut): on outRespValid & not_full,
   --   enqueue {outRespFinished, outRespData}. Read side feeds dispatchResponse.
   --   The finished companion is sampled at enqueue (OQ-FSM-17).
   --------------------------------------------------------------------------
   U_RespQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => MEMORY_TYPE_G,
         DATA_WIDTH_G    => RESPQ_WIDTH_C,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G)
      port map (
         rst      => rst,
         wr_clk   => clk,
         wr_en    => respQWrEn,
         din      => respQDin,
         not_full => respQNotFull,
         rd_clk   => clk,
         rd_en    => respQRd,
         dout     => respQDout,
         valid    => respQNotEmpty);

   -- Downstream response face (toPut(respQ)): accept a put when not_full.
   outRespReady <= respQNotFull;
   respQWrEn    <= outRespValid and respQNotFull;
   respQDin     <= outRespFinished & outRespData;

   --------------------------------------------------------------------------
   -- U_PreGrantQ : BSV preGrantIdxQ (mkFIFOF Bit#(idxW)). Written by
   --   issueArbitratedReq (conditional on shouldSaveGrantIdxReg), read by
   --   dispatchResponse (first each cycle; deq only at response-burst end).
   --------------------------------------------------------------------------
   U_PreGrantQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => MEMORY_TYPE_G,
         DATA_WIDTH_G    => IDX_WIDTH_C,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G)
      port map (
         rst      => rst,
         wr_clk   => clk,
         wr_en    => preGrantWrEn,
         din      => preGrantDin,
         not_full => preGrantNotFull,
         rd_clk   => clk,
         rd_en    => preGrantRdEn,
         dout     => preGrantDout,
         valid    => preGrantNotEmpty);

   --------------------------------------------------------------------------
   -- Combinatorial : the always-enabled BSV rules issueArbitratedReq and
   --   dispatchResponse. Conflict-free -> two independent `if ...FiresEn` blocks.
   --   (extractReq[k] are emitted above inside GEN_PORT as continuous
   --   assignments.) See ClientArbiter.fsm.md transition table.
   --------------------------------------------------------------------------
   comb : process (r, rst, arbNotEmpty, arbDout, arbFinished, reqQNotFull,
                   preGrantNotEmpty, preGrantNotFull, preGrantDout,
                   respQNotEmpty, respQDout, cltRespReady) is
      variable v               : RegType;
      variable inputReq        : slv(REQ_WIDTH_G-1 downto 0);
      variable reqIdx          : slv(IDX_WIDTH_C-1 downto 0);
      variable issueFiresEn    : sl;
      variable respFinished    : sl;
      variable preGrantIdx     : natural range 0 to PORT_COUNT_G-1;
      variable selRespReady    : sl;
      variable dispatchFiresEn : sl;
   begin
      -- Latch current state
      v := r;

      -- Default Mealy outputs / strobes (no rule firing).
      arbDeq       <= '0';
      reqQWrEn     <= '0';
      reqQDin      <= (others => '0');
      preGrantWrEn <= '0';
      preGrantDin  <= (others => '0');
      preGrantRdEn <= '0';
      respQRd      <= '0';
      cltRespValid <= (others => '0');

      ----------------------------------------------------------------------
      -- rule issueArbitratedReq
      --   {reqIdx, inputReq} = arbDout; reqIdx in the HIGH bits.
      --   enq to preGrantIdxQ is CONDITIONAL on shouldSaveGrantIdxReg, so the
      --   rule may fire when the flag is '0' even if preGrantIdxQ is full.
      ----------------------------------------------------------------------
      inputReq := arbDout(REQ_WIDTH_G-1 downto 0);
      reqIdx   := arbDout(REQIDX_WIDTH_C-1 downto REQ_WIDTH_G);

      issueFiresEn := arbNotEmpty and reqQNotFull and
                      ((not r.shouldSaveGrantIdxReg) or preGrantNotFull);

      if (issueFiresEn = '1') then
         arbDeq                  <= '1';  -- dequeue arbitrated request
         reqQWrEn                <= '1';  -- reqQ.enq(inputReq) (downstream)
         reqQDin                 <= inputReq;
         preGrantWrEn            <= r.shouldSaveGrantIdxReg;  -- conditional preGrantIdxQ.enq
         preGrantDin             <= reqIdx;
         -- next burst-start = this request was the last of its burst
         v.shouldSaveGrantIdxReg := arbFinished;  -- = isReqFinished(inputReq)
      end if;

      ----------------------------------------------------------------------
      -- rule dispatchResponse
      --   route respQ.first to clientVec[preGrantIdx].response.put; release the
      --   grant index only at response-burst end (respFinished). Readiness term
      --   is the SELECTED client's cltRespReady bit (indexed by preGrantIdx).
      --   (Response DATA is broadcast to every port slice inside GEN_PORT;
      --   cltRespValid selects the port.)
      ----------------------------------------------------------------------
      respFinished := respQDout(RESP_WIDTH_G);    -- stored finished companion
      preGrantIdx  := to_integer(unsigned(preGrantDout));
      selRespReady := cltRespReady(preGrantIdx);  -- cltRespReady(preGrantIdx)

      dispatchFiresEn := preGrantNotEmpty and respQNotEmpty and selRespReady;

      if (dispatchFiresEn = '1') then
         respQRd                   <= '1';  -- deq respQ
         preGrantRdEn              <= respFinished;  -- deq preGrantIdxQ at burst end
         cltRespValid(preGrantIdx) <= '1';  -- response.put to selected client
      end if;

      -- Synchronous reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;
   end process comb;

   --------------------------------------------------------------------------
   -- Sequential
   --------------------------------------------------------------------------
   seq : process (clk, rst) is
   begin
      if (RST_ASYNC_G) and (rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
