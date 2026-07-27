-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Multiplexes PORT_COUNT_G upstream client request/response streams onto one
--   downstream Server (srv), tagging each request with its origin port index so
--   the matching response is routed back to that port. Exposes PORT_COUNT_G
--   per-port Server faces (reqK/respK) to upstream clients.
--
--   BSV owns ONE register (shouldSaveGrantIdxReg) and TWO rules
--   (issueArbitratedReq, dispatchResponse), plus three FIFO groups
--   (inputReqWithIdxVec, respVec, preGrantIdxQ) and the arbitration tree
--   (mkLeafBinaryPipeOutArbiterVec -> mkBinaryPipeOutArbiterTree). This is a
--   1-flag flow-control wrapper around the arbitration tree — no multi-state
--   enum; shouldSaveGrantIdxReg is a burst-boundary flag.
--
--   PORT_COUNT_G = 2 (OQ-FSM-SRVARB-01, RESOLVED — option 2):
--     Every concrete mkServerArbiter instantiation (mkDmaArbiter4QP,
--     QueuePair.bsv:335/344) uses Vector#(2,...), so portSz = 2 and idxW = 1.
--     For portSz = 2 the BSV arbitration tree degenerates: the leaf-vec yields a
--     single mkBinaryPipeOutArbiter and mkBinaryPipeOutArbiterTree hits its
--     portSz==1 base case, returning that leaf unchanged. So the whole tree is a
--     single BinaryPipeOutArbiter (U_ReqArb) — NOT the fixed-4 PipeOutArbiter the
--     partition wired. A concurrent assertion below enforces PORT_COUNT_G = 2.
--
--   OQ-FSM-17 (predicate handling) — reqKFinished / srvRespFinished input ports:
--     BSV isReqFinished / isRespFinished are elaboration-time function arguments
--     (isReqFinished(req), isRespFinished(resp)); VHDL has no function-type ports.
--     Per the established resolution the parent (mkDmaArbiter4QP), where the
--     concrete type is known, computes them and feeds them as 1-bit combinational
--     inputs. Concrete values are trivial (isDmaReadReqLast=True, isDmaWriteRespLast
--     =True -> tie '1'; the others are single-field extracts).
--       * REQUEST predicate: computed by the parent on the request being put and
--         carried as a companion THROUGH the per-port input FIFO (element widened
--         to {finished, idx, req}). Because isReqFinished is a pure function of the
--         request, the stored bit at the FIFO head == isReqFinished(head.req), which
--         is exactly what the arbiter's per-channel pipeInKFinished input needs, and
--         (via BinaryPipeOutArbiter's outFinished companion) exactly what
--         issueArbitratedReq needs for shouldSaveGrantIdxReg. So reqKFinished is an
--         INPUT PORT sampled at enqueue — no predicate logic lives in this entity.
--       * RESPONSE predicate: srvRespData is already an entity input, so the parent
--         computes srvRespFinished = isRespFinished(srvRespData) and feeds it as a
--         combinational INPUT PORT.
--     These two ports are NOT in the FSM spec's Ports table verbatim (they are the
--     "predicate/port" inputs it defers to OQ-FSM-17); adding them is the faithful
--     realization. See "Judgment calls" in the emit report.
--
--   Payload layout (BSV pack(tuple2(reqIdx, inputReq)) = {reqIdx, inputReq},
--   reqIdx in the HIGH bits):
--       arbiter payload width = IDX_WIDTH_C + REQ_WIDTH_G
--       inputReq = arbDout(REQ_WIDTH_G-1 downto 0)
--       reqIdx   = arbDout(IDX_WIDTH_C+REQ_WIDTH_G-1 downto REQ_WIDTH_G)
--   Per-port input FIFO element = {finished(1), idx(IDX_WIDTH_C), req(REQ_WIDTH_G)}.
--
--   Two independent, conflict-free rules (disjoint registers; different ports of
--   preGrantIdxQ: issue -> enq, dispatch -> first/deq). Both may fire the same
--   cycle -> emitted as two independent `if ...FiresEn then` blocks, no priority.
--     issueArbitratedReq guard : arbNotEmpty AND srvReqReady
--                                AND ((NOT shouldSave) OR preGrantNotFull)
--       -- the preGrantIdxQ.enq is conditional on shouldSaveGrantIdxReg, so the
--          rule can still fire when the flag is '0' even if preGrantIdxQ is full
--          (BSV conditional-method implicit condition). MUST NOT gate issue
--          unconditionally on notFull.
--     dispatchResponse   guard : preGrantNotEmpty AND srvRespValid
--                                AND U_RespQ(preGrantIdx).notFull
--
--   Mealy: all strobes/data are combinational functions of FIFO/handshake status,
--   arbDout and r.shouldSaveGrantIdxReg. Only shouldSaveGrantIdxReg is registered.
--   Data persistence lives in the surf.Fifo instances, not FSM regs.
--
--   Child entity instantiated:
--     * U_ReqArb : work.BinaryPipeOutArbiter (degenerate PORT_COUNT_G=2 tree)
--       source: out/04-vhdl/BinaryPipeOutArbiter.vhd
--
--   SURF components instantiated (all BSV mkFIFOF -> surf.Fifo):
--     * U_InReqQ0/1 : surf.Fifo  <- inputReqWithIdxVec[k]  ({finished,idx,req})
--     * U_RespQ0/1  : surf.Fifo  <- respVec[k]             (respType)
--     * U_PreGrantQ : surf.Fifo  <- preGrantIdxQ           (Bit#(idxW))
--       source: surf/base/fifo/rtl/Fifo.vhd
--     FWFT_EN_G => true so `valid` = head-present = BSV notEmpty. BSV mkFIFOF is
--     depth 2; surf.Fifo minimum ADDR_WIDTH is 4 (depth 16). Functionally a
--     buffering FIFO; depth differs and there is an inherent ~1-cycle write->valid
--     read latency vs BSV mkFIFOF — functionally equivalent, NOT cycle-accurate.
--
--   NOTE: emitting does not prove equivalence — simulate this entity (cocotb)
--   against the BSV behaviour before trusting it.
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

entity ServerArbiter is
   generic (
      TPD_G             : time                   := 1 ns;
      RST_POLARITY_G    : sl                     := '1';  -- '1' active HIGH reset, '0' active LOW
      RST_ASYNC_G       : boolean                := false;
      PORT_COUNT_G      : positive               := 2;    -- number of upstream ports; MUST be 2 (OQ-FSM-SRVARB-01)
      REQ_WIDTH_G       : positive               := 8;    -- Bits#(reqType)
      RESP_WIDTH_G      : positive               := 8;    -- Bits#(respType)
      MEMORY_TYPE_G     : string                 := "distributed";  -- FIFO RAM style
      FIFO_ADDR_WIDTH_G : positive range 4 to 48 := 4);   -- FIFO depth = 2**ADDR (BSV mkFIFOF depth 2; SURF min 4)
   port (
      clk           : in  sl;
      rst           : in  sl := not RST_POLARITY_G;
      -- Per-port client-facing Server 0 (resultSrvVec[0])
      req0Valid     : in  sl;                              -- client 0 request.put valid
      req0Data      : in  slv(REQ_WIDTH_G-1 downto 0);     -- client 0 request payload
      req0Finished  : in  sl;                              -- isReqFinished(req0Data) (OQ-FSM-17), sampled at enqueue
      req0Ready     : out sl;                              -- port 0 ready = U_InReqQ0 not_full
      resp0Valid    : out sl;                              -- response 0 first valid (U_RespQ0 notEmpty)
      resp0Data     : out slv(RESP_WIDTH_G-1 downto 0);    -- response 0 first (U_RespQ0 dout)
      resp0Rd       : in  sl;                              -- client 0 response.get (U_RespQ0 deq)
      -- Per-port client-facing Server 1 (resultSrvVec[1])
      req1Valid     : in  sl;                              -- client 1 request.put valid
      req1Data      : in  slv(REQ_WIDTH_G-1 downto 0);     -- client 1 request payload
      req1Finished  : in  sl;                              -- isReqFinished(req1Data) (OQ-FSM-17), sampled at enqueue
      req1Ready     : out sl;                              -- port 1 ready = U_InReqQ1 not_full
      resp1Valid    : out sl;                              -- response 1 first valid (U_RespQ1 notEmpty)
      resp1Data     : out slv(RESP_WIDTH_G-1 downto 0);    -- response 1 first (U_RespQ1 dout)
      resp1Rd       : in  sl;                              -- client 1 response.get (U_RespQ1 deq)
      -- Downstream shared Server (srv, module argument)
      srvReqValid     : out sl;                              -- srv.request.put fired
      srvReqData      : out slv(REQ_WIDTH_G-1 downto 0);     -- request payload to srv (= inputReq)
      srvReqReady     : in  sl;                              -- srv.request can accept (CAN_PUT)
      srvRespValid    : in  sl;                              -- srv.response available (Get ready)
      srvRespData     : in  slv(RESP_WIDTH_G-1 downto 0);    -- srv.response payload
      srvRespFinished : in sl;                             -- isRespFinished(srvRespData) (OQ-FSM-17)
      srvRespRd       : out sl);                             -- srv.response.get fired
end entity ServerArbiter;

architecture rtl of ServerArbiter is

   -- idxW = TLog#(PORT_COUNT_G); for PORT_COUNT_G=2 -> 1 (OQ-FSM-SRVARB-01).
   constant IDX_WIDTH_C    : positive := log2(PORT_COUNT_G);
   -- Arbiter payload = {reqIdx, inputReq} (reqIdx in the HIGH bits).
   constant REQIDX_WIDTH_C : positive := IDX_WIDTH_C + REQ_WIDTH_G;
   -- Per-port input FIFO element = {finished, idx, req}.
   constant INREQ_WIDTH_C  : positive := 1 + REQIDX_WIDTH_C;

   -- Only registered state (BSV mkReg(True)). Burst-boundary flag, not a state
   -- selector: '1' => next issued request starts a new burst (record its grant
   -- index in preGrantIdxQ); '0' => mid-burst continuation (index already saved).
   type RegType is record
      shouldSaveGrantIdxReg : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      shouldSaveGrantIdxReg => '1');       -- BSV mkReg(True)

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- U_InReqQ(k) (surf.Fifo, element {finished,idx,req}) status/handshake.
   signal inReqQ0NotFull : sl;
   signal inReqQ0Valid   : sl;
   signal inReqQ0Dout    : slv(INREQ_WIDTH_C-1 downto 0);
   signal inReqQ0WrEn    : sl;
   signal inReqQ0Din     : slv(INREQ_WIDTH_C-1 downto 0);
   signal inReqQ0Rd      : sl;
   signal inReqQ1NotFull : sl;
   signal inReqQ1Valid   : sl;
   signal inReqQ1Dout    : slv(INREQ_WIDTH_C-1 downto 0);
   signal inReqQ1WrEn    : sl;
   signal inReqQ1Din     : slv(INREQ_WIDTH_C-1 downto 0);
   signal inReqQ1Rd      : sl;

   -- U_ReqArb (BinaryPipeOutArbiter) arbitrated PipeOut output.
   signal arbNotEmpty : sl;
   signal arbDout     : slv(REQIDX_WIDTH_C-1 downto 0);    -- {reqIdx, inputReq}
   signal arbFinished : sl;                                -- isReqFinished(inputReq), buffered head bit
   signal arbDeq      : sl;

   -- U_PreGrantQ (surf.Fifo, element Bit#(idxW)) status/handshake.
   signal preGrantNotFull  : sl;
   signal preGrantNotEmpty : sl;
   signal preGrantDout     : slv(IDX_WIDTH_C-1 downto 0);
   signal preGrantWrEn     : sl;
   signal preGrantDin      : slv(IDX_WIDTH_C-1 downto 0);
   signal preGrantRdEn     : sl;

   -- U_RespQ(k) (surf.Fifo, element respType) status/handshake.
   signal respQ0NotFull : sl;
   signal respQ0Valid   : sl;
   signal respQ0Dout    : slv(RESP_WIDTH_G-1 downto 0);
   signal respQ0WrEn    : sl;
   signal respQ1NotFull : sl;
   signal respQ1Valid   : sl;
   signal respQ1Dout    : slv(RESP_WIDTH_G-1 downto 0);
   signal respQ1WrEn    : sl;

begin

   -- Degenerate-tree emit is only valid for PORT_COUNT_G = 2 (OQ-FSM-SRVARB-01).
   assert (PORT_COUNT_G = 2)
      report "ServerArbiter: emitted for the degenerate PORT_COUNT_G=2 tree only " &
             "(single BinaryPipeOutArbiter child); wider portSz needs a real " &
             "PORT_COUNT_G-sized arbitration tree (see OQ-FSM-SRVARB-01)."
      severity failure;

   --------------------------------------------------------------------------
   -- Per-port request input FIFOs (BSV inputReqWithIdxVec[k] = mkFIFOF).
   --   Write side = pure interface wiring of resultSrvVec[k].request.put:
   --   on reqKValid & not_full enqueue {reqKFinished, idx=k, reqKData}.
   --   Read side feeds the arbiter's pipeInK channel.
   --------------------------------------------------------------------------
   U_InReqQ0 : entity surf.Fifo
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
         wr_en    => inReqQ0WrEn,
         din      => inReqQ0Din,
         not_full => inReqQ0NotFull,
         rd_clk   => clk,
         rd_en    => inReqQ0Rd,
         dout     => inReqQ0Dout,
         valid    => inReqQ0Valid);

   U_InReqQ1 : entity surf.Fifo
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
         wr_en    => inReqQ1WrEn,
         din      => inReqQ1Din,
         not_full => inReqQ1NotFull,
         rd_clk   => clk,
         rd_en    => inReqQ1Rd,
         dout     => inReqQ1Dout,
         valid    => inReqQ1Valid);

   -- Interface wiring (per-port request.put): enqueue on valid & room; port ready
   -- = FIFO not_full. Element = {finished, idx=const k, req}; idx in HIGH-of-payload
   -- bits (below the finished companion), req in the low bits.
   req0Ready   <= inReqQ0NotFull;
   inReqQ0WrEn <= req0Valid and inReqQ0NotFull;
   inReqQ0Din  <= req0Finished & toSlv(0, IDX_WIDTH_C) & req0Data;
   req1Ready   <= inReqQ1NotFull;
   inReqQ1WrEn <= req1Valid and inReqQ1NotFull;
   inReqQ1Din  <= req1Finished & toSlv(1, IDX_WIDTH_C) & req1Data;

   --------------------------------------------------------------------------
   -- U_ReqArb : degenerate PORT_COUNT_G=2 arbitration tree = single
   --   BinaryPipeOutArbiter (OQ-FSM-SRVARB-01). Its two PipeOut inputs are the
   --   two input request FIFO heads; the stored finished companion (top bit of
   --   the FIFO element) is the per-channel finish predicate (OQ-FSM-17). Its
   --   outFinished companion = isReqFinished(inputReq) drives shouldSaveGrantIdxReg.
   --------------------------------------------------------------------------
   U_ReqArb : entity surf.BinaryPipeOutArbiter
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         DATA_WIDTH_G      => REQIDX_WIDTH_C,   -- payload = {idx, req}
         MEMORY_TYPE_G     => MEMORY_TYPE_G,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G)
      port map (
         clk             => clk,
         rst             => rst,
         -- pipeIn1 <- U_InReqQ0
         pipeIn1Valid    => inReqQ0Valid,
         pipeIn1Dout     => inReqQ0Dout(REQIDX_WIDTH_C-1 downto 0),
         pipeIn1Finished => inReqQ0Dout(REQIDX_WIDTH_C),   -- stored finished companion
         pipeIn1Rd       => inReqQ0Rd,
         -- pipeIn2 <- U_InReqQ1
         pipeIn2Valid    => inReqQ1Valid,
         pipeIn2Dout     => inReqQ1Dout(REQIDX_WIDTH_C-1 downto 0),
         pipeIn2Finished => inReqQ1Dout(REQIDX_WIDTH_C),   -- stored finished companion
         pipeIn2Rd       => inReqQ1Rd,
         -- arbitrated PipeOut output
         outNotEmpty     => arbNotEmpty,
         outDout         => arbDout,
         outFinished     => arbFinished,
         outDeq          => arbDeq);

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
   -- Per-port response FIFOs (BSV respVec[k] = mkFIFOF). Written by
   --   dispatchResponse into queue preGrantIdx; read side = pure interface
   --   wiring of resultSrvVec[k].response (toGet).
   --------------------------------------------------------------------------
   U_RespQ0 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => MEMORY_TYPE_G,
         DATA_WIDTH_G    => RESP_WIDTH_G,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G)
      port map (
         rst      => rst,
         wr_clk   => clk,
         wr_en    => respQ0WrEn,
         din      => srvRespData,          -- broadcast; wr_en selects queue
         not_full => respQ0NotFull,
         rd_clk   => clk,
         rd_en    => resp0Rd,
         dout     => respQ0Dout,
         valid    => respQ0Valid);

   U_RespQ1 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => MEMORY_TYPE_G,
         DATA_WIDTH_G    => RESP_WIDTH_G,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G)
      port map (
         rst      => rst,
         wr_clk   => clk,
         wr_en    => respQ1WrEn,
         din      => srvRespData,          -- broadcast; wr_en selects queue
         not_full => respQ1NotFull,
         rd_clk   => clk,
         rd_en    => resp1Rd,
         dout     => respQ1Dout,
         valid    => respQ1Valid);

   -- Interface wiring (per-port response.get / toGet): expose FIFO head.
   resp0Valid <= respQ0Valid;
   resp0Data  <= respQ0Dout;
   resp1Valid <= respQ1Valid;
   resp1Data  <= respQ1Dout;

   --------------------------------------------------------------------------
   -- Combinatorial : the two always-enabled BSV rules (issueArbitratedReq,
   --   dispatchResponse). Conflict-free -> two independent `if ...FiresEn` blocks.
   --   See ServerArbiter.fsm.md transition table.
   --------------------------------------------------------------------------
   comb : process (r, rst, arbNotEmpty, arbDout, arbFinished, srvReqReady,
                   srvRespValid, srvRespFinished, preGrantNotEmpty,
                   preGrantNotFull, preGrantDout, respQ0NotFull, respQ1NotFull) is
      variable v               : RegType;
      variable inputReq        : slv(REQ_WIDTH_G-1 downto 0);
      variable reqIdx          : slv(IDX_WIDTH_C-1 downto 0);
      variable issueFiresEn    : sl;
      variable preGrantIdx     : natural range 0 to PORT_COUNT_G-1;
      variable selRespNotFull  : sl;
      variable dispatchFiresEn : sl;
   begin
      -- Latch current state
      v := r;

      -- Default Mealy outputs / strobes (no rule firing).
      srvReqValid  <= '0';
      srvReqData   <= (others => '0');
      arbDeq       <= '0';
      preGrantWrEn <= '0';
      preGrantDin  <= (others => '0');
      srvRespRd    <= '0';
      preGrantRdEn <= '0';
      respQ0WrEn   <= '0';
      respQ1WrEn   <= '0';

      ----------------------------------------------------------------------
      -- rule issueArbitratedReq
      --   {reqIdx, inputReq} = arbDout; reqIdx in the HIGH bits.
      --   enq to preGrantIdxQ is CONDITIONAL on shouldSaveGrantIdxReg, so the
      --   rule may fire when the flag is '0' even if preGrantIdxQ is full.
      ----------------------------------------------------------------------
      inputReq := arbDout(REQ_WIDTH_G-1 downto 0);
      reqIdx   := arbDout(REQIDX_WIDTH_C-1 downto REQ_WIDTH_G);

      issueFiresEn := arbNotEmpty and srvReqReady and
                      ((not r.shouldSaveGrantIdxReg) or preGrantNotFull);

      if (issueFiresEn = '1') then
         arbDeq       <= '1';                          -- dequeue arbitrated request
         srvReqValid  <= '1';                          -- srv.request.put(inputReq)
         srvReqData   <= inputReq;
         preGrantWrEn <= r.shouldSaveGrantIdxReg;      -- conditional preGrantIdxQ.enq
         preGrantDin  <= reqIdx;
         -- next burst-start = this request was the last of its burst
         v.shouldSaveGrantIdxReg := arbFinished;       -- = isReqFinished(inputReq)
      end if;

      ----------------------------------------------------------------------
      -- rule dispatchResponse
      --   route srv.response into respVec[preGrantIdx]; release preGrantIdx only
      --   at response-burst end (respFinished).
      ----------------------------------------------------------------------
      preGrantIdx := to_integer(unsigned(preGrantDout));

      if (preGrantIdx = 0) then
         selRespNotFull := respQ0NotFull;
      else
         selRespNotFull := respQ1NotFull;
      end if;

      dispatchFiresEn := preGrantNotEmpty and srvRespValid and selRespNotFull;

      if (dispatchFiresEn = '1') then
         srvRespRd    <= '1';                          -- srv.response.get
         if (preGrantIdx = 0) then                     -- respVec[preGrantIdx].enq(resp)
            respQ0WrEn <= '1';
         else
            respQ1WrEn <= '1';
         end if;
         preGrantRdEn <= srvRespFinished;              -- deq preGrantIdxQ at burst end
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
