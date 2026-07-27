-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Thin DMA-write request/response shuttle with cancel / graceful-stop
--   support.  Almost pure dataflow (FIFO <-> external Server passthrough) plus
--   a 2-bit control sub-FSM over {cancel, gracefulStop}:
--     RUN_S        = {cancel=0}            — normal forwarding (issueReq/recvResp)
--     CANCELLING_S = {cancel=1,grStop=0}   — drain non-first frags, await resp
--     STOPPED_S    = {cancel=1,grStop=1}   — quiesced; isIdle() true
--   {cancel=0,gracefulStop=1} is unreachable.  The control bits are NOT an
--   explicit state enum in the live module — they are emitted as two boolean
--   RegType fields (per fsm.md §State register).
--
--   The entity is a Server to its caller (srvPort: request Put / response Get)
--   and a Client of an external Server dmaWriteSrv (request Put / response Get).
--
--   BSV rules implemented:
--     resetAndClear (R0) — guard clearAllI='1' (LEVEL); clears all three FIFOs
--                          via rst, forces cancel/gracefulStop to '0'.  Dominates
--                          every other rule (all guard !clearAllI).
--     issueReq      (R1) — RUN_S (!cancel); deq reqQ -> Put dmaWriteSrv request;
--                          on a first-fragment also enq a hasPendingReqQ token.
--                          Blocks if a first-fragment cannot enq its token.
--     recvResp      (R2) — cancel-INDEPENDENT; Get dmaWriteSrv response -> enq
--                          respQ and retire one hasPendingReqQ token.  This is
--                          how hasPendingReqQ empties so R4 can latch.
--     gracefulStopReq(R3)— CANCELLING_S (cancel && !gracefulStop); drains only
--                          NON-first fragments (deq reqQ -> Put request).  On a
--                          first-fragment it is a genuine no-op spin (reads
--                          reqQ.first only) — nothing emitted.
--     setGracefulStop(R4)— CANCELLING_S; latches gracefulStop:='1' once
--                          hasPendingReqQ is empty (no requests awaiting a resp).
--                          Conflict-free with R3 — both may fire the same cycle.
--     dmaCntrl.cancel() (M0) — Action pulse cancelEn -> cancel:='1' (CReg port0,
--                          same-cycle forwarded into the R1/R3/R4 guards).
--     dmaCntrl.isIdle() — Moore output = r.gracefulStop (CReg port0 read of the
--                          REGISTERED value).
--
--   CReg semantics (fsm.md §CReg semantics) — each mkCReg(2) is ONE RegType
--   field, writes applied in port order so reads see the forwarded value:
--     cancel       : v:=r; port0 (cancelEn) sets '1' BEFORE the rule guards read
--                    v.cancel (same-cycle cancel); port1 (clearAllI) clears '0'
--                    last (dominates).
--     gracefulStop : port0 read (isIdle) uses r.gracefulStop (pre-update, Moore);
--                    rule guards read v.gracefulStop (= r.gracefulStop, no port0
--                    writer); setGracefulStop sets '1', clearAllI clears '0'.
--
--   Request drive to dmaWriteSrv (dmaReqOut/dmaReqValid) is COMBINATIONAL
--   (Mealy): dmaReqOut is reqQ.dout (FIFO front) and dmaReqValid is the R1/R3
--   fire condition.  It is a deq->put passthrough in one rule and MUST NOT be
--   registered (fsm.md §Output style).
--
--   FIFO clear (OQ-FSM-01 carry-forward, RESOLVED in out/03-fsm/RESOLVED.md):
--     BSV reqQ.clear / respQ.clear / hasPendingReqQ.clear map to asserting each
--     Fifo's rst, OR'd with the structural reset:  fifoRst = rst OR clearAllI.
--     surf.FifoSync holds logically empty for the whole asserted window
--     (level-safe; no pulse generator).  Requires GEN_SYNC_FIFO_G=true,
--     RST_ASYNC_G=false, RST_POLARITY_G='1'.  All three FIFOs share fifoRst so
--     the BSV single-cycle simultaneous clear is preserved.
--
--   Open-question carry-forwards (see out/03-fsm/OPEN_QUESTIONS.md):
--     OQ-FSM-DWC-01 — Stage-1/2 records describe a stale DEAD variant
--                     (PayloadConAndGen.bsv:434-508, inside /* */); this file
--                     emits the LIVE body only.
--     OQ-FSM-DWC-02 — third FIFO hasPendingReqQ (omitted from mapping.json) IS
--                     emitted here as U_HasPendQ.
--     OQ-FSM-DWC-03 — dmaWriteSrv / cntrlStatus.comm.isReset are external ports
--                     (mapping.new_ports=[] is incomplete); enumerated below.
--
--   SURF components instantiated (source: surf/base/fifo/rtl/Fifo.vhd):
--     U_ReqQ     : surf.Fifo  DATA_WIDTH_G=419, FWFT, sync, distributed RAM
--                  (DmaWriteReq;  BSV mkFIFOF reqQ)
--     U_RespQ    : surf.Fifo  DATA_WIDTH_G=53,  FWFT, sync, distributed RAM
--                  (DmaWriteResp; BSV mkFIFOF respQ)
--     U_HasPendQ : surf.Fifo  DATA_WIDTH_G=1,   FWFT, sync, distributed RAM
--                  (Bool token;  BSV mkFIFOF hasPendingReqQ)
--     Distributed-RAM FWFT cold latency is 1 cycle (block RAM was 2); the 1-bit token queue
--     uses distributed RAM (1-cycle FWFT) so its notEmpty tracks the BSV
--     enq->notEmpty timing the R4 guard relies on — see tb-spec §8.
--
--   DmaWriteReq bit layout (419b; BSV deriving(Bits), first-field-at-MSB):
--     [418:290] metaData : DmaWriteMetaData (129b)
--       [418:415] initiator (DmaReqSrcType, 4b)
--       [414:391] sqpn      (QPN, 24b)
--       [390:327] startAddr (ADDR, 64b)
--       [326:314] len       (PktLen, 13b)
--       [313:290] psn       (PSN, 24b)
--     [289:0]   dataStream : DataStream (290b)
--       [289:34]  data    (DATA, 256b)
--       [33:2]    byteEn  (ByteEn, 32b)
--       [1]       isFirst   <-- reqFirst
--       [0]       isLast
--
--   DmaWriteResp bit layout (53b; first-field-at-MSB):
--     [52:49] initiator (4b)  [48:25] sqpn (24b)  [24:1] psn (24b)  [0] isRespErr
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

entity DmaWriteCntrl is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk          : in  sl;
      rst          : in  sl;            -- active-high synchronous reset
      -- Software clear (cntrlStatus.comm.isReset; synchronous, LEVEL-asserted)
      clearAllI    : in  sl;
      -- dmaCntrl.cancel() method (Action pulse): request graceful cancel
      cancelEn     : in  sl;
      -- srvPort.request : Put#(DmaWriteReq)  (caller -> entity, enq to reqQ)
      reqInValid   : in  sl;            -- caller offers a request (wr_en)
      reqInData    : in  slv(418 downto 0);  -- DmaWriteReq packed
      reqInReady   : out sl;            -- entity can accept (reqQ.notFull)
      -- srvPort.response : Get#(DmaWriteResp) (entity -> caller, deq from respQ)
      respOutReady : in  sl;            -- caller takes a response (rd_en)
      respOutValid : out sl;            -- response available (respQ.notEmpty)
      respOutData  : out slv(52 downto 0);   -- DmaWriteResp packed
      -- dmaWriteSrv.request : Put#(DmaWriteReq)   (entity -> external server)
      dmaReqValid  : out sl;            -- entity offers a request (Mealy)
      dmaReqOut    : out slv(418 downto 0);  -- DmaWriteReq packed = reqQ.dout
      dmaReqReady  : in  sl;            -- external server can accept
      -- dmaWriteSrv.response : Get#(DmaWriteResp) (external server -> entity)
      dmaRespValid : in  sl;            -- external server offers a response
      dmaRespIn    : in  slv(52 downto 0);   -- DmaWriteResp packed
      dmaRespReady : out sl;            -- entity takes the response (get/pop)
      -- dmaCntrl.isIdle() method result (Moore, registered)
      isIdle       : out sl);
end entity DmaWriteCntrl;

architecture rtl of DmaWriteCntrl is

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

   -- U_ReqQ interface signals (DmaWriteReq, 419b)
   signal reqQNotFull : sl;
   signal reqQValid   : sl;             -- = reqQ.notEmpty (FWFT data valid)
   signal reqQDout    : slv(418 downto 0);
   signal reqQRdEn    : sl;

   -- U_RespQ interface signals (DmaWriteResp, 53b)
   signal respQNotFull : sl;
   signal respQValid   : sl;
   signal respQWrEn    : sl;
   signal respQDin     : slv(52 downto 0);

   -- U_HasPendQ interface signals (Bool token, 1b)
   signal hasPendNotFull : sl;
   signal hasPendValid   : sl;          -- = hasPendingReqQ.notEmpty
   signal hasPendWrEn    : sl;
   signal hasPendDin     : slv(0 downto 0);
   signal hasPendRdEn    : sl;

   -- FIFO reset line: level = rst OR clearAllI (atomic 3-FIFO clear)
   signal fifoRst : sl;

begin

   -- FIFO reset: level-sensitive clear (OQ-FSM-01 carry-forward, RESOLVED)
   fifoRst <= rst or clearAllI;

   -- srvPort boundary wiring (pass-through; not FSM-gated)
   reqInReady   <= reqQNotFull;         -- reqQ.notFull readiness to caller
   respOutValid <= respQValid;          -- respQ.notEmpty to caller

   -- isIdle() method (Moore): registered gracefulStop (CReg port0 read, no port0
   -- writer => the pre-update value).  Drive from r, NOT v.
   isIdle <= r.gracefulStop;

   ---------------------------------------------------------------------------
   -- U_ReqQ : surf.Fifo
   --   Inbound DmaWriteReq queue (BSV mkFIFOF reqQ).  wr side = caller's
   --   srvPort.request.put (pass-through); rd side = FSM (issueReq /
   --   gracefulStopReq deq).
   ---------------------------------------------------------------------------
   U_ReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 419,
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
         rd_en         => reqQRdEn,     -- FSM (issueReq / gracefulStopReq)
         dout          => reqQDout,
         valid         => reqQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_RespQ : surf.Fifo
   --   Outbound DmaWriteResp queue (BSV mkFIFOF respQ).  wr side = FSM
   --   (recvResp enq); rd side = caller's srvPort.response.get (pass-through).
   ---------------------------------------------------------------------------
   U_RespQ : entity surf.Fifo
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
         rst           => fifoRst,
         wr_clk        => clk,
         wr_en         => respQWrEn,     -- FSM (recvResp)
         din           => respQDin,      -- FSM (recvResp)
         full          => open,
         not_full      => respQNotFull,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => respOutReady,  -- pass-through (caller drives)
         dout          => respOutData,
         valid         => respQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_HasPendQ : surf.Fifo
   --   1-bit token queue (BSV mkFIFOF hasPendingReqQ).  Enqueued by issueReq on
   --   each first-fragment request, dequeued by recvResp per DMA-write response.
   --   Only its notEmpty flag is consumed (setGracefulStop guard); dout unused.
   --   Distributed RAM => 1-cycle FWFT, matching BSV enq->notEmpty timing.
   ---------------------------------------------------------------------------
   U_HasPendQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 1,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoRst,
         wr_clk        => clk,
         wr_en         => hasPendWrEn,  -- FSM (issueReq, first-fragment)
         din           => hasPendDin,   -- FSM (constant "1")
         full          => open,
         not_full      => hasPendNotFull,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => hasPendRdEn,  -- FSM (recvResp)
         dout          => open,         -- value never read (only notEmpty)
         valid         => hasPendValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- Combinatorial process
   --   Emit order (fsm.md §Conflicts/scheduling):
   --     1) cancel() port0 (cancelEn) forwarded into v.cancel
   --     2) recvResp (R2) — cancel-independent
   --     3) R1/R3/R4 evaluated off v.cancel and r.gracefulStop + SURF flags
   --     4) setGracefulStop / resetAndClear port1 writes
   ---------------------------------------------------------------------------
   comb : process (r, rst, clearAllI, cancelEn, reqQValid, reqQDout, dmaReqReady,
                   dmaRespValid, dmaRespIn, respQNotFull, hasPendValid,
                   hasPendNotFull) is
      variable v        : RegType;
      variable reqFirst : sl;
   begin
      v := r;

      -- default Mealy outputs / SURF drives (deasserted)
      reqQRdEn     <= '0';
      respQWrEn    <= '0';
      respQDin     <= (others => '0');
      hasPendWrEn  <= '0';
      hasPendDin   <= (others => '0');
      hasPendRdEn  <= '0';
      dmaReqValid  <= '0';
      dmaReqOut    <= reqQDout;  -- Mealy front: reqQ.dout, gated by dmaReqValid
      dmaRespReady <= '0';

      -- reqQ.first.dataStream.isFirst (DmaWriteReq bit 1)
      reqFirst := reqQDout(1);

      ----------------------------------------------------------------------
      -- (1) CReg cancel port0: dmaCntrl.cancel() method.  Forwarded into the
      --     R1/R3/R4 guards this same cycle (same-cycle cancel).
      ----------------------------------------------------------------------
      if cancelEn = '1' then
         v.cancel := '1';
      end if;

      ----------------------------------------------------------------------
      -- (2) recvResp (R2): cancel-INDEPENDENT.  Get dmaWriteSrv response ->
      --     enq respQ and retire one hasPendingReqQ token.
      ----------------------------------------------------------------------
      if (clearAllI = '0' and dmaRespValid = '1' and respQNotFull = '1' and
          hasPendValid = '1') then
         dmaRespReady <= '1';           -- get/pop external server response
         respQWrEn    <= '1';           -- enq respQ
         respQDin     <= dmaRespIn;
         hasPendRdEn  <= '1';           -- deq hasPendingReqQ token
      end if;

      ----------------------------------------------------------------------
      -- (3) Forwarding path on {cancel, gracefulStop} (all guard !clearAllI).
      --     R1 (RUN_S, !cancel) vs R3/R4 (CANCELLING_S, cancel) are mutually
      --     exclusive on v.cancel.
      ----------------------------------------------------------------------
      if clearAllI = '0' then
         if v.cancel = '0' then
            -- R1 issueReq: deq reqQ -> Put request; first-fragment also enqs a
            --   hasPendingReqQ token (rule blocks if that token cannot enq).
            if (reqQValid = '1' and dmaReqReady = '1' and
                (reqFirst = '0' or hasPendNotFull = '1')) then
               reqQRdEn    <= '1';      -- deq reqQ
               dmaReqValid <= '1';      -- Put (dmaReqOut already = reqQDout)
               if reqFirst = '1' then
                  hasPendWrEn <= '1';
                  hasPendDin  <= "1";   -- enq token
               end if;
            end if;

         else
            -- cancel = '1'
            if r.gracefulStop = '0' then
               -- R3 gracefulStopReq: drain only NON-first fragments.  A first
               --   fragment is a no-op spin (reads reqQ.first only) -> emit
               --   nothing; hold until R4 latches gracefulStop.
               if (reqQValid = '1' and reqFirst = '0' and dmaReqReady = '1') then
                  reqQRdEn    <= '1';   -- deq reqQ
                  dmaReqValid <= '1';   -- Put (dmaReqOut already = reqQDout)
               end if;

               -- R4 setGracefulStop: latch once hasPendingReqQ is empty.
               --   Conflict-free with R3 (may fire the same cycle).
               if hasPendValid = '0' then
                  v.gracefulStop := '1';
               end if;
            end if;
         end if;
      end if;

      ----------------------------------------------------------------------
      -- (4) resetAndClear (R0) port1 writes: clearAllI dominates all rules and
      --     forces both control bits to '0' (FIFOs cleared via fifoRst pins).
      ----------------------------------------------------------------------
      if clearAllI = '1' then
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
