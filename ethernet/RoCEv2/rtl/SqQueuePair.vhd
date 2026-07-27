-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Structural wiring container for the RDMA Send Queue.  `mkSQ` owns NO
--   registered state and NO control FSM: it instantiates the eight Send-Queue
--   sub-blocks, threads their interfaces together, forwards the module-argument
--   interfaces (contextSQ, payloadGenerator, dmaWriteCntrl, permCheckSrv,
--   workReqPipeIn, respPktPipeOut) down to the children, and re-exports a few
--   child interfaces/methods on the SQ interface.  The only rule in the BSV body
--   (resetAndClear, QueuePair.bsv:220-225, no_implicit_conditions +
--   fire_when_enabled) is a one-line combinational reset fan-out that asserts the
--   scan buffer's clear whenever contextSQ.statusSQ.comm.isReset is high.
--
--   Because there is no state to translate, this architecture is emitted as pure
--   structural VHDL (component instances + port map + a handful of concurrent
--   glue assignments) rather than the SURF two-process comb/seq template.  There
--   is no RegType / REG_INIT_C — there are zero mkReg/mkRegU/counter/CReg fields
--   in mkSQ.  (See FSM spec §"State register": NONE.)
--
--   Child entity instances (each separately emitted; wiring per FSM spec table):
--     U_ScanFifoF     : work.ScanFifoF               (mkScanFIFOF — register-array
--                          scan FIFO; NOT a surf.Fifo).  T_SZ_G=679 (PendingWorkReq),
--                          Q_SZ_G=32 (MAX_QP_WR, Settings.bsv:15).
--     U_RetryHandleSq : work.RetryHandleSq           (mkRetryHandleSQ)
--     U_NewPending    : work.NewPendingWorkReqPipeOut(mkNewPendingWorkReqPipeOut)
--     U_PipeOutMux    : work.PipeOutMux              (mkPipeOutMux; DATA_WIDTH_G=679)
--     U_PayloadCon    : work.PayloadConsumerConAndGen(mkPayloadConsumer)
--     U_ReqGenSq      : work.ReqGenSq                (mkReqGenSQ)
--     U_RespHandleSq  : work.RespHandleSq            (mkRespHandleSQ)
--     U_WorkCompGenSq : work.WorkCompGenSq           (mkWorkCompGenSQ)
--
--   SURF components instantiated DIRECTLY by this entity: NONE (mapping.json
--   surf_instances = []).  Every FIFO/RAM used by the Send Queue lives inside a
--   child entity; this container only wires children together.
--
--   mkConnection lowering — pendingWorkReq2Q (QueuePair.bsv:198-200):
--     toGet(reqGenSQ.pendingWorkReqPipeOut) -> toPut(pendingWorkReqBuf.fifof).
--     Lowered to a one-cycle handshake: enqueue fires when the producer PipeOut
--     is valid AND the scan-FIFO fifof side has room; the same strobe deqs the
--     producer.  All other links are direct interface-argument passing.
--
--   Composite word widths (traced from child port declarations / DataTypes.bsv):
--     PendingWorkReq  = 679  WorkReq       = 601  RdmaPktMetaData = 649
--     DataStream      = 290  WorkComp      = 222  WorkCompGenReqSQ= 633
--     PayloadConReq   = 203  PayloadConResp=  53  DmaWriteReq     = 419
--     DmaWriteResp    =  53  PayloadGenReq = 199  PayloadGenResp  =   2
--     PermCheckReq    = 267  RetryReq      =  97
--
--   Open questions (out/04-vhdl/OPEN_QUESTIONS.md): OQ-EMIT-SQQP-01 (structural,
--   no two-process template), OQ-EMIT-SQQP-02 (contextSQ flattened to a status
--   port bundle), OQ-EMIT-SQQP-03 (PipeOutMux dependency now emitted+verified),
--   OQ-EMIT-SQQP-04 (level vs pulse clear, inherited from ScanFifoF OQ-FSM-06).
--
--   DEVIATION-SQQP-01 (2026-07-08): SQ retry partial-replay fix (intentional
--   deviation from upstream blue-rdma; touches ScanFifoF.vhd, RespHandleSq.vhd
--   and this file — grep the tag).
--   Failure (claudeSurf tb, WRITE/CASES_NUM=50/DROP_REQ_PSN=3/MAX_QP_WR=32):
--   a NAK arrived while new WRs were still in flight between the PipeOutMux
--   and the pendingWorkReqBuf enqueue (inside PipeOutMux's output Fifo and
--   ReqGenSq's stage FIFOs — all 16-deep surf.Fifo vs BSV's 2-deep mkFIFOF,
--   which amplifies the upstream hole 8x). Those WRs are PSN-stamped and
--   their packets ARE emitted, but they miss the retry scan's itemCnt
--   snapshot, so the go-back-N replay covered only WR1-24 of 32; the mux then
--   served WR33+ ahead of the never-retried WR25-32 -> second NAK + response
--   timeout (naks=2, retransmits=350, ~105us stall). Root cause: go-back-N
--   correctness requires the replay window to cover every PSN-stamped WR, but
--   the snapshot only covers buffer occupancy. Upstream BSV has the same
--   latent hole; it is NOT closed by gating the enqueue alone (a deferred
--   enqueue misses the snapshot exactly like a mid-scan one).
--   Fix (three parts):
--     1. an in-flight counter (incr when the mux consumes a NEW WR from
--        NewPendingWorkReqPipeOut, decr on every buffer enqueue) plus a latch
--        that withholds RetryHandleSq's scanStart strobe from ScanFifoF until
--        the counter reaches zero — the buffer waits in PRE_SCAN, whose
--        snapshot re-samples every cycle, so the late WRs are replayed;
--     2. buffer enqueue admitted during PRE_SCAN as well as FIFO mode
--        (ScanFifoF DEVIATION note; snapshot takes the post-enq count), and
--        still blocked during SCAN (BUGFIX 2026-07-08 below, now relaxed);
--     3. RespHandleSq.pendingWrDeqAllowed = not inPreScan restores the BSV
--        deq implicit condition, keeping the head stable under
--        getHead/modifyHead across the (now longer) PRE_SCAN window.
--   No deadlock: the drain path (ReqGenSq pipeline -> packet emission ->
--   buffer enqueue) is independent of the stalled response path, and while
--   in-flight WRs exist the NewPending window arithmetic guarantees the
--   buffer is not full (in-flight + occupancy < MAX_QP_WR), so the drain
--   always completes and releases the scan.
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

entity SqQueuePair is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';        -- '1' for active-HIGH reset
      RST_ASYNC_G    : boolean := false;
      -- false = no RDMA READ/atomic support on the requester: U_PayloadCon
      -- (read-response landing -> DMA write) is not generated and RespHandleSq
      -- treats read/atomic responses as unknown (contract: software never
      -- posts READ/atomic work requests).
      EN_READ_G      : boolean := true;
      -- Settings.bsv MAX_QP_WR (BSV default 32): pendingWorkReqBuf scan depth.
      -- Must match CntrlQp MAX_QP_WR_G and be a power of 2 (ScanFifoF Q_SZ_G).
      MAX_QP_WR_G    : positive := 4);
   port (
      clk : in sl;
      rst : in sl := not RST_POLARITY_G;      -- FPGA async/sync reset (active-high)

      -----------------------------------------------------------------------
      -- contextSQ.statusSQ status bundle (combinational inputs, fanned out to
      -- the children — see OQ-EMIT-SQQP-02).  contextSQ.comm.* + the shared
      -- next-PSN register read/write.
      -----------------------------------------------------------------------
      isReset               : in  sl;                    -- comm.isReset (soft clear)
      isNonErr              : in  sl;                    -- comm.isNonErr
      isStableRTS           : in  sl;                    -- comm.isStableRTS
      isRTS                 : in  sl;                    -- comm.isRTS
      isERR                 : in  sl;                    -- comm.isERR
      isSQD                 : in  sl;                    -- comm.isSQD
      isRTR2RTS             : in  sl;                    -- comm.isRTR2RTS
      qpType                : in  slv(3 downto 0);       -- getTypeQP
      sqpn                  : in  slv(23 downto 0);      -- getSQPN
      pmtu                  : in  slv(2 downto 0);       -- getPMTU
      pkey                  : in  slv(15 downto 0);      -- getPKEY
      dqpn                  : in  slv(23 downto 0);      -- getDQPN
      sigAll                : in  sl;                    -- getSigAll
      getMaxRetryCnt        : in  slv(2 downto 0);       -- comm.getMaxRetryCnt
      getMaxRnrCnt          : in  slv(2 downto 0);       -- comm.getMaxRnrCnt
      getMaxTimeOut         : in  slv(4 downto 0);       -- comm.getMaxTimeOut
      getMinRnrTimer        : in  slv(4 downto 0);       -- comm.getMinRnrTimer
      getPendingWorkReqNum  : in  slv(7 downto 0);       -- comm.getPendingWorkReqNum
      -- contextSQ shared next-PSN register (read + write-back, both in mkSQ)
      npsnIn                : in  slv(23 downto 0);      -- contextSQ.getNPSN
      npsnOut               : out slv(23 downto 0);      -- contextSQ.setNPSN value
      npsnWrEn              : out sl;                    -- contextSQ.setNPSN write-enable

      -----------------------------------------------------------------------
      -- payloadGenerator : external Server + payload DataStream (module arg,
      -- forwarded to U_ReqGenSq).  NOT instantiated here (it is payloadGenerator4SQ
      -- inside mkQP).
      -----------------------------------------------------------------------
      payloadGenReqValid    : out sl;                    -- srvPort.request (put)
      payloadGenReqData     : out slv(198 downto 0);     -- PayloadGenReq
      payloadGenReqReady    : in  sl;
      payloadGenRespValid   : in  sl;                    -- srvPort.response (get)
      payloadGenRespData    : in  slv(1 downto 0);       -- PayloadGenResp
      payloadGenRespReady   : out sl;
      payloadGenDataValid   : in  sl;                    -- payloadDataStreamPipeOut
      payloadGenDataData    : in  slv(289 downto 0);     -- DataStream
      payloadGenDataRdEn    : out sl;

      -----------------------------------------------------------------------
      -- dmaWriteCntrl : external Server client (module arg -> U_PayloadCon)
      -----------------------------------------------------------------------
      dmaWriteReqValid      : out sl;                    -- request (put)
      dmaWriteReqData       : out slv(418 downto 0);     -- DmaWriteReq
      dmaWriteReqReady      : in  sl;
      dmaWriteRespValid     : in  sl;                    -- response (get)
      dmaWriteRespData      : in  slv(52 downto 0);      -- DmaWriteResp
      dmaWriteRespReady     : out sl;

      -----------------------------------------------------------------------
      -- permCheckSrv : external Server client (module arg -> U_RespHandleSq)
      -----------------------------------------------------------------------
      permReqValid          : out sl;                    -- request (put)
      permReqData           : out slv(266 downto 0);     -- PermCheckReq
      permReqReady          : in  sl;
      permRespValid         : in  sl;                    -- response (get)
      permRespData          : in  sl;                    -- Bool (mrCheckResult)
      permRespGetEn         : out sl;

      -----------------------------------------------------------------------
      -- workReqPipeIn : PipeOut#(WorkReq) (module arg -> U_NewPending)
      -----------------------------------------------------------------------
      workReqInValid        : in  sl;                    -- notEmpty
      workReqInData         : in  slv(600 downto 0);     -- first (WorkReq)
      workReqInRdEn         : out sl;                    -- deq

      -----------------------------------------------------------------------
      -- respPktPipeOut : RdmaPktMetaDataAndPayloadPipeOut (module arg).
      --   .payload     -> U_PayloadCon (payloadPipeIn)
      --   .pktMetaData -> U_RespHandleSq (pktMetaDataPipeIn)
      -----------------------------------------------------------------------
      respPayloadValid      : in  sl;                    -- .payload notEmpty
      respPayloadData       : in  slv(289 downto 0);     -- DataStream
      respPayloadRdEn       : out sl;                    -- .payload deq
      respPktMetaValid      : in  sl;                    -- .pktMetaData notEmpty
      respPktMetaData       : in  slv(648 downto 0);     -- RdmaPktMetaData
      respPktMetaRdEn       : out sl;                    -- .pktMetaData deq

      -----------------------------------------------------------------------
      -- SQ interface (re-exported outputs)
      -----------------------------------------------------------------------
      -- rdmaReqDataStreamPipeOut = reqGenSQ.rdmaReqDataStreamPipeOut
      rdmaReqDataValid      : out sl;
      rdmaReqDataData       : out slv(289 downto 0);     -- DataStream
      rdmaReqDataRdEn       : in  sl;
      -- workCompSQ = workCompGenSQ (WorkCompGen interface)
      workCompValid         : out sl;
      workCompData          : out slv(221 downto 0);     -- WorkComp
      workCompRdEn          : in  sl;
      workCompHasErr        : out sl;                    -- workCompGenSQ.hasErr
      -- method Bool reqHeaderOutNotEmpty() = reqGenSQ.reqHeaderOutNotEmpty
      reqHeaderOutNotEmpty  : out sl;
      -- method Bool pendingWorkReqNotEmpty() = pendingWorkReqBuf.fifof.notEmpty
      pendingWorkReqNotEmpty : out sl);
end entity SqQueuePair;

architecture rtl of SqQueuePair is

   -----------------------------------------------------------------------------
   -- Word widths (traced from child ports / DataTypes.bsv)
   -----------------------------------------------------------------------------
   constant PENDING_WR_C : positive := 679;   -- PendingWorkReq
   constant MAX_QP_WR_C  : positive := MAX_QP_WR_G;   -- Settings.bsv MAX_QP_WR (scan depth)

   -----------------------------------------------------------------------------
   -- Inter-child signals
   -----------------------------------------------------------------------------
   -- U_ScanFifoF (pendingWorkReqBuf) --------------------------------------------
   signal scanEnqEn        : sl;
   signal scanEnqData      : slv(PENDING_WR_C-1 downto 0);
   signal scanDeqEn        : sl;
   signal scanFifoFirst    : slv(PENDING_WR_C-1 downto 0);
   signal scanFifoNotEmpty : sl;
   signal scanFifoNotFull  : sl;
   signal scanDeqPulse     : sl;
   signal scanClearEn      : sl;
   signal scanHead         : slv(PENDING_WR_C-1 downto 0);
   signal scanModifyHeadEn   : sl;
   signal scanModifyHeadData : slv(PENDING_WR_C-1 downto 0);
   signal scanPreScanStartEn   : sl;
   signal scanStartEn          : sl;
   signal scanStopEn           : sl;
   signal scanPreScanRestartEn : sl;
   signal scanHasScanOut   : sl;
   signal scanIsScanDone   : sl;
   signal scanInPreScan    : sl;
   signal scanOutValid     : sl;
   signal scanOutData      : slv(PENDING_WR_C-1 downto 0);
   signal scanOutReady     : sl;

   -- U_RetryHandleSq (retryHandler) ---------------------------------------------
   signal retryScanClearInt   : sl;    -- retryHandler scanCntrl.clear drive
   signal retryHasRetryErr   : sl;
   signal retryIsRetryDone    : sl;
   signal retryIsRetrying     : sl;
   signal retryResetReqValid  : sl;
   signal retryResetReqData   : sl;
   signal retryResetReqReady  : sl;
   signal retryTimeOutValid   : sl;
   signal retryTimeOutData    : sl;
   signal retryTimeOutGetEn   : sl;
   signal retrySrvReqValid    : sl;
   signal retrySrvReqData     : slv(96 downto 0);
   signal retrySrvReqReady    : sl;
   signal retrySrvRespValid   : sl;
   signal retrySrvRespData    : slv(1 downto 0);
   signal retrySrvRespGetEn   : sl;

   -- U_NewPending (newPendingWorkReqPiptOut) ------------------------------------
   signal newPendOutValid : sl;
   signal newPendOutData  : slv(PENDING_WR_C-1 downto 0);
   signal newPendOutRdEn  : sl;

   -- U_PipeOutMux (pendingWorkReqPipeOut, into reqGenSQ) ------------------------
   signal muxOutValid : sl;
   signal muxOutData  : slv(PENDING_WR_C-1 downto 0);
   signal muxOutRdEn  : sl;

   -- U_ReqGenSq (reqGenSQ) ------------------------------------------------------
   signal reqGenPendingOutValid : sl;
   signal reqGenPendingOutData  : slv(PENDING_WR_C-1 downto 0);
   signal reqGenPendingOutRdEn  : sl;
   signal reqGenWorkCompValid   : sl;
   signal reqGenWorkCompData    : slv(632 downto 0);
   signal reqGenWorkCompRdEn    : sl;

   -- U_RespHandleSq (respHandleSQ) ----------------------------------------------
   signal respPayloadConReqValid : sl;
   signal respPayloadConReqData  : slv(202 downto 0);
   signal respPayloadConReqReady : sl;
   signal respWorkCompValid      : sl;
   signal respWorkCompData       : slv(632 downto 0);
   signal respWorkCompRdEn       : sl;

   -- U_PayloadCon (payloadConsumer) ---------------------------------------------
   signal pcRespOutValid : sl;
   signal pcRespOutData  : slv(52 downto 0);
   signal pcRespOutReady : sl;

   -- pendingWorkReq2Q connection strobe -----------------------------------------
   signal pendingWr2QFire : sl;

   -----------------------------------------------------------------------------
   -- DEVIATION-SQQP-01: retry scan-start gate (see header).
   -- inFlightNewWr counts NEW WRs consumed from NewPendingWorkReqPipeOut by the
   -- mux but not yet enqueued into pendingWorkReqBuf (they sit in PipeOutMux's
   -- output Fifo and ReqGenSq's stage FIFOs). Bounded by the NewPending window
   -- (< MAX_QP_WR), hence log2(MAX_QP_WR_C)+1 bits.
   -----------------------------------------------------------------------------
   type RegType is record
      inFlightNewWr : slv(log2(MAX_QP_WR_C) downto 0);
      scanStartPend : sl;                 -- scanStart received, drain not done
   end record RegType;

   constant REG_INIT_C : RegType := (
      inFlightNewWr => (others => '0'),
      scanStartPend => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal retryScanStartReq   : sl;      -- RetryHandleSq's raw scanStart strobe
   signal pendingWrDeqAllowed : sl;      -- deq implicit condition to RespHandleSq

begin

   -----------------------------------------------------------------------------
   -- resetAndClear (QueuePair.bsv:220-225): forward the isReset LEVEL to the scan
   -- buffer's clear, OR-ed with any scan-clear the retry handler drives.
   -- fire_when_enabled + no_implicit_conditions -> unconditional, ungated.
   -- LEVEL-asserted clear, same class as ScanFifoF OQ-FSM-06 (see OQ-EMIT-SQQP-04).
   -----------------------------------------------------------------------------
   scanClearEn <= isReset or retryScanClearInt;

   -----------------------------------------------------------------------------
   -- pendingWorkReq2Q (mkConnection): reqGenSQ.pendingWorkReqPipeOut (Get) ->
   -- pendingWorkReqBuf.fifof (Put).  One-cycle handshake: enqueue when producer
   -- valid AND fifof has room; same strobe deqs the producer.
   -- BUGFIX 2026-07-08: enq is also gated on the buffer mode. mkScanFIFOF.enq's
   -- implicit condition is (!isFull && inFifoMode) (SpecialFIFOF.bsv:424): no
   -- enqueue may land while a retry scan is in progress (it would escape the
   -- scan snapshot and be excluded from the go-back-N replay). Gating on
   -- isScanDone alone did NOT cure the observed partial replay (the deferred
   -- enqueue missed the snapshot all the same); DEVIATION-SQQP-01 (see header)
   -- additionally admits enqueues during PRE_SCAN — the pre-scan snapshot
   -- re-samples every cycle, so those WRs are inside the replay window — and
   -- the scan-start gate below holds the buffer in PRE_SCAN until every
   -- in-flight new WR has landed.
   -----------------------------------------------------------------------------
   pendingWr2QFire       <= reqGenPendingOutValid and scanFifoNotFull and
                            (scanIsScanDone or scanInPreScan);
   scanEnqEn             <= pendingWr2QFire;
   scanEnqData           <= reqGenPendingOutData;
   reqGenPendingOutRdEn  <= pendingWr2QFire;

   -----------------------------------------------------------------------------
   -- DEVIATION-SQQP-01: retry scan-start gate (see header).
   --   comb/seq pair for {inFlightNewWr, scanStartPend}. RetryHandleSq's
   --   scanStart strobe (retryScanStartReq) is forwarded to ScanFifoF only once
   --   inFlightNewWr (counted through this cycle's enqueue) is zero; otherwise
   --   it is latched in scanStartPend and released when the drain completes.
   --   RetryHandleSq meanwhile sits in WAIT_RETRY_DONE polling isScanDone — the
   --   deferral is invisible to it. With no WRs in flight (the common case) the
   --   strobe passes through combinationally, i.e. zero added latency.
   -----------------------------------------------------------------------------
   comb : process (r, rst, isReset, newPendOutValid, newPendOutRdEn, scanEnqEn,
                   retryScanStartReq, scanStopEn, scanClearEn) is
      variable v        : RegType;
      variable incr     : sl;             -- mux consumed a NEW WR this cycle
      variable decr     : sl;             -- a new WR landed in the buffer
      variable releaseV : sl;             -- forward scanStart to ScanFifoF
   begin
      v := r;

      incr := newPendOutValid and newPendOutRdEn;
      decr := scanEnqEn;

      -- Saturating decrement: PipeOutMux's internal output Fifo survives a QP
      -- soft reset (faithful to BSV — mkSQ.resetAndClear clears only the scan
      -- buffer, not pipeMuxOutQ), so a WR consumed before an isReset (counter
      -- cleared) can drain into the buffer after it: a legitimate uncounted
      -- enqueue, absorbed here rather than wrapping the counter.
      if (incr = '1') and (decr = '0') then
         v.inFlightNewWr := slv(unsigned(r.inFlightNewWr) + 1);
      elsif (incr = '0') and (decr = '1') and (unsigned(r.inFlightNewWr) /= 0) then
         v.inFlightNewWr := slv(unsigned(r.inFlightNewWr) - 1);
      end if;

      -- latch the request; release when the drain (incl. this cycle's enq,
      -- which the PRE_SCAN snapshot also includes) is complete
      if (retryScanStartReq = '1') then
         v.scanStartPend := '1';
      end if;
      releaseV := '0';
      if ((retryScanStartReq = '1') or (r.scanStartPend = '1')) and
         (unsigned(v.inFlightNewWr) = 0) then
         releaseV        := '1';
         v.scanStartPend := '0';
      end if;

      -- a scan abort / soft clear cancels any pending start; the counter only
      -- clears with the QP soft reset (which also clears ReqGenSq's pipeline)
      if (isReset = '1') or (scanClearEn = '1') or (scanStopEn = '1') then
         v.scanStartPend := '0';
      end if;
      if (isReset = '1') then
         v.inFlightNewWr := (others => '0');
      end if;

      -- synchronous reset
      if (RST_ASYNC_G = false) and (rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin <= v;

      scanStartEn <= releaseV;
   end process comb;

   seq : process (clk, rst) is
   begin
      if (RST_ASYNC_G) and (rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -- DEVIATION-SQQP-01: BSV deq implicit condition (no pop while PRE_SCAN)
   pendingWrDeqAllowed <= not scanInPreScan;

   -----------------------------------------------------------------------------
   -- U_ScanFifoF : pendingWorkReqBuf (mkScanFIFOF; register-array scan FIFO).
   --   fifof side  : enq from reqGenSQ (above), deq by respHandleSQ (toPipeOut).
   --   scanCntrl   : driven by retryHandler + resetAndClear; head read by retry.
   --   scanPipeOut : feeds PipeOutMux.pipeIn1.
   -----------------------------------------------------------------------------
   U_ScanFifoF : entity surf.ScanFifoF
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         MEMORY_TYPE_G  => "distributed",          -- 679b scan-output queue -> distributed RAM
         Q_SZ_G         => MAX_QP_WR_C,       -- MAX_QP_WR
         T_SZ_G         => PENDING_WR_C)      -- PendingWorkReq = 679b
      port map (
         clk              => clk,
         rst              => rst,
         -- fifof enqueue side
         enqEn            => scanEnqEn,
         enqData          => scanEnqData,
         -- fifof dequeue / status side
         deqEn            => scanDeqEn,
         fifoFirst        => scanFifoFirst,
         fifoNotEmpty     => scanFifoNotEmpty,
         fifoNotFull      => scanFifoNotFull,
         deqPulse         => scanDeqPulse,
         fifoSize         => open,
         -- clear() method
         clearEn          => scanClearEn,
         -- scanCntrl
         scanHead         => scanHead,
         modifyHeadEn     => scanModifyHeadEn,
         modifyHeadData   => scanModifyHeadData,
         preScanStartEn   => scanPreScanStartEn,
         scanStartEn      => scanStartEn,
         scanStopEn       => scanStopEn,
         preScanRestartEn => scanPreScanRestartEn,
         hasScanOut       => scanHasScanOut,
         isScanDone       => scanIsScanDone,
         inPreScan        => scanInPreScan,
         -- scanPipeOut
         scanOutValid     => scanOutValid,
         scanOutData      => scanOutData,
         scanOutReady     => scanOutReady);

   -----------------------------------------------------------------------------
   -- U_RetryHandleSq : retryHandler
   --   mkRetryHandleSQ(contextSQ.statusSQ, pendingWorkReqBuf.fifof.notEmpty,
   --                   pendingWorkReqBuf.scanCntrl)
   -----------------------------------------------------------------------------
   U_RetryHandleSq : entity surf.RetryHandleSq
      generic map (
         TPD_G => TPD_G)
      port map (
         clk                    => clk,
         rst                    => rst,
         -- comm status
         isReset                => isReset,
         isERR                  => isERR,
         isStableRTS            => isStableRTS,
         isRTR2RTS              => isRTR2RTS,
         getMaxRetryCnt         => getMaxRetryCnt,
         getMaxRnrCnt           => getMaxRnrCnt,
         getMaxTimeOut          => getMaxTimeOut,
         getMinRnrTimer         => getMinRnrTimer,
         getPMTU                => pmtu,
         -- pending-WR scan status
         pendingWorkReqNotEmpty => scanFifoNotEmpty,
         scanGetHead            => scanHead,
         scanIsScanDone         => scanIsScanDone,
         -- scanCntrl drives
         scanClear              => retryScanClearInt,
         scanStop               => scanStopEn,
         -- DEVIATION-SQQP-01: raw strobe into the scan-start gate, which
         -- forwards it to ScanFifoF (scanStartEn) once in-flight WRs drained
         scanStart              => retryScanStartReq,
         scanPreScanStart       => scanPreScanStartEn,
         scanPreScanRestart     => scanPreScanRestartEn,
         scanModifyHeadValid    => scanModifyHeadEn,
         scanModifyHeadData     => scanModifyHeadData,
         -- status methods
         hasRetryErr            => retryHasRetryErr,
         isRetryDone            => retryIsRetryDone,
         isRetrying             => retryIsRetrying,
         -- resetRetryCntAndTimeOutBySQ (driven by respHandleSQ)
         resetReqValid          => retryResetReqValid,
         resetReqData           => retryResetReqData,
         resetReqReady          => retryResetReqReady,
         -- notifyTimeOut2SQ (consumed by respHandleSQ)
         timeOutNotifValid      => retryTimeOutValid,
         timeOutNotifData       => retryTimeOutData,
         timeOutNotifGetEn      => retryTimeOutGetEn,
         -- srvPort.request (from respHandleSQ)
         srvReqValid            => retrySrvReqValid,
         srvReqData             => retrySrvReqData,
         srvReqReady            => retrySrvReqReady,
         -- srvPort.response (to respHandleSQ)
         srvRespValid           => retrySrvRespValid,
         srvRespData            => retrySrvRespData,
         srvRespGetEn           => retrySrvRespGetEn);

   -----------------------------------------------------------------------------
   -- U_NewPending : newPendingWorkReqPiptOut
   --   mkNewPendingWorkReqPipeOut(contextSQ.statusSQ,
   --      pendingWorkReqBuf.scanCntrl.deqPulse, workReqPipeIn)
   -----------------------------------------------------------------------------
   U_NewPending : entity surf.NewPendingWorkReqPipeOut
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         MAX_QP_WR_G    => MAX_QP_WR_C)
      port map (
         clk                      => clk,
         rst                      => rst,
         isReset_i                => isReset,
         isERR_i                  => isERR,
         isRTS_i                  => isRTS,
         getPendingWorkReqNum_i   => getPendingWorkReqNum,
         decrPendingReqCntPulse_i => scanDeqPulse,
         workReqValid_i           => workReqInValid,
         workReqData_i            => workReqInData,
         workReqRdy_o             => workReqInRdEn,
         outQValid_o              => newPendOutValid,
         outQDout_o               => newPendOutData,
         outQRdEn_i               => newPendOutRdEn);

   -----------------------------------------------------------------------------
   -- U_PipeOutMux : pendingWorkReqPipeOut
   --   mkPipeOutMux(sel = scanCntrl.hasScanOut,
   --                pipeIn1 = scanPipeOut, pipeIn2 = newPendingWorkReqPiptOut)
   --   sel='1' -> pipeIn1 (scan output); sel='0' -> pipeIn2 (new pending WRs).
   -----------------------------------------------------------------------------
   U_PipeOutMux : entity surf.PipeOutMux
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         DATA_WIDTH_G   => PENDING_WR_C)
      port map (
         clk          => clk,
         rst          => rst,
         sel          => scanHasScanOut,
         -- pipeIn1 = scanPipeOut
         pipeIn1Valid => scanOutValid,
         pipeIn1Dout  => scanOutData,
         pipeIn1RdEn  => scanOutReady,
         -- pipeIn2 = newPendingWorkReqPiptOut
         pipeIn2Valid => newPendOutValid,
         pipeIn2Dout  => newPendOutData,
         pipeIn2RdEn  => newPendOutRdEn,
         -- output -> reqGenSQ.pendingWorkReqPipeIn
         pipeOutValid => muxOutValid,
         pipeOutDout  => muxOutData,
         pipeOutRdEn  => muxOutRdEn);

   -----------------------------------------------------------------------------
   -- U_ReqGenSq : reqGenSQ
   --   mkReqGenSQ(contextSQ, payloadGenerator, pendingWorkReqPipeOut,
   --             pendingWorkReqBuf.fifof.notEmpty)
   -----------------------------------------------------------------------------
   U_ReqGenSq : entity surf.ReqGenSq
      generic map (
         TPD_G => TPD_G)
      port map (
         clk                       => clk,
         rst                       => rst,
         -- contextSQ.statusSQ bundle
         isReset                   => isReset,
         isStableRTS               => isStableRTS,
         isRTS                     => isRTS,
         isERR                     => isERR,
         isSQD                     => isSQD,
         qpType                    => qpType,
         sqpn                      => sqpn,
         pmtu                      => pmtu,
         pkey                      => pkey,
         dqpn                      => dqpn,
         sigAll                    => sigAll,
         npsnIn                    => npsnIn,
         npsnOut                   => npsnOut,
         npsnWrEn                  => npsnWrEn,
         -- pendingWorkReqPipeIn = PipeOutMux output
         pendingWorkReqInValid     => muxOutValid,
         pendingWorkReqInData      => muxOutData,
         pendingWorkReqInRdEn      => muxOutRdEn,
         pendingWorkReqBufNotEmpty => scanFifoNotEmpty,
         -- payloadGenerator server + payload stream
         payloadGenReqValid        => payloadGenReqValid,
         payloadGenReqData         => payloadGenReqData,
         payloadGenReqReady        => payloadGenReqReady,
         payloadGenRespValid       => payloadGenRespValid,
         payloadGenRespData        => payloadGenRespData,
         payloadGenRespReady       => payloadGenRespReady,
         payloadDataStreamValid    => payloadGenDataValid,
         payloadDataStreamData     => payloadGenDataData,
         payloadDataStreamRdEn     => payloadGenDataRdEn,
         -- pendingWorkReqPipeOut -> back into scan buffer fifof (pendingWorkReq2Q)
         pendingWorkReqOutValid    => reqGenPendingOutValid,
         pendingWorkReqOutData     => reqGenPendingOutData,
         pendingWorkReqOutRdEn     => reqGenPendingOutRdEn,
         -- workCompGenReqPipeOut -> workCompGenSQ
         workCompGenReqValid       => reqGenWorkCompValid,
         workCompGenReqData        => reqGenWorkCompData,
         workCompGenReqRdEn        => reqGenWorkCompRdEn,
         -- rdmaReqDataStreamPipeOut -> SQ interface
         rdmaReqDataValid          => rdmaReqDataValid,
         rdmaReqDataData           => rdmaReqDataData,
         rdmaReqDataRdEn           => rdmaReqDataRdEn,
         -- method reqHeaderOutNotEmpty
         reqHeaderOutNotEmpty      => reqHeaderOutNotEmpty);

   -----------------------------------------------------------------------------
   -- U_PayloadCon : payloadConsumer
   --   mkPayloadConsumer(contextSQ.statusSQ, dmaWriteCntrl, respPktPipeOut.payload)
   --   .request  <- respHandleSQ  ;  .response -> workCompGenSQ
   -----------------------------------------------------------------------------
   -- Pruned when EN_READ_G=false: RespHandleSq's forced classifiers keep
   -- payloadConReq requests to the discard arm only (drained by the tied
   -- ready), the response face never produces (WorkCompGenSq never waits on
   -- it, wcWaitDma is constant '0'), and the resp-pipe payload leg is drained.
   GEN_NO_PAYLOAD_CON : if not EN_READ_G generate
      respPayloadRdEn       <= '1';
      respPayloadConReqReady <= '1';
      pcRespOutValid        <= '0';
      pcRespOutData         <= (others => '0');
      dmaWriteReqValid      <= '0';
      dmaWriteReqData       <= (others => '0');
      dmaWriteRespReady     <= '1';
   end generate GEN_NO_PAYLOAD_CON;

   GEN_PAYLOAD_CON : if EN_READ_G generate
      U_PayloadCon : entity surf.PayloadConsumerConAndGen
         generic map (
            TPD_G => TPD_G)
         port map (
            clk                => clk,
            rst                => rst,
            isReset            => isReset,
            isNonErr           => isNonErr,
            isErr              => isERR,
         -- srvPort.request (from respHandleSQ.payloadConReqPort)
            reqInValid         => respPayloadConReqValid,
            reqInData          => respPayloadConReqData,
            reqInReady         => respPayloadConReqReady,
         -- srvPort.response (to workCompGenSQ)
            respOutReady       => pcRespOutReady,
            respOutValid       => pcRespOutValid,
            respOutData        => pcRespOutData,
         -- payloadPipeIn = respPktPipeOut.payload
            payloadPipeInValid => respPayloadValid,
            payloadPipeInData  => respPayloadData,
            payloadPipeInReady => respPayloadRdEn,
         -- dmaWriteSrv client -> dmaWriteCntrl ports
            dmaWriteReqValid   => dmaWriteReqValid,
            dmaWriteReqData    => dmaWriteReqData,
            dmaWriteReqReady   => dmaWriteReqReady,
            dmaWriteRespValid  => dmaWriteRespValid,
            dmaWriteRespData   => dmaWriteRespData,
            dmaWriteRespReady  => dmaWriteRespReady);
   end generate GEN_PAYLOAD_CON;

   -----------------------------------------------------------------------------
   -- U_RespHandleSq : respHandleSQ
   --   mkRespHandleSQ(contextSQ, retryHandler, permCheckSrv,
   --      toPipeOut(pendingWorkReqBuf.fifof), respPktPipeOut.pktMetaData,
   --      payloadConsumer.request)
   -----------------------------------------------------------------------------
   U_RespHandleSq : entity surf.RespHandleSq
      generic map (
         TPD_G     => TPD_G,
         EN_READ_G => EN_READ_G)
      port map (
         clk                => clk,
         rst                => rst,
         -- comm status
         isReset            => isReset,
         isRTS              => isRTS,
         isERR              => isERR,
         isStableRTS        => isStableRTS,
         getPMTU            => pmtu,
         getSQPN            => sqpn,
         getNPSN            => npsnIn,
         -- pendingWorkReqPipeIn = toPipeOut(pendingWorkReqBuf.fifof)
         pendingWrValid      => scanFifoNotEmpty,
         pendingWrData       => scanFifoFirst,
         pendingWrDeq        => scanDeqEn,
         pendingWrDeqAllowed => pendingWrDeqAllowed,  -- DEVIATION-SQQP-01
         -- pktMetaDataPipeIn = respPktPipeOut.pktMetaData
         pktMetaValid       => respPktMetaValid,
         pktMetaData        => respPktMetaData,
         pktMetaDeq         => respPktMetaRdEn,
         -- payloadConReqPort -> payloadConsumer.request
         payloadConReqValid => respPayloadConReqValid,
         payloadConReqData  => respPayloadConReqData,
         payloadConReqReady => respPayloadConReqReady,
         -- retryHandler.resetRetryCntAndTimeOutBySQ
         retryResetValid    => retryResetReqValid,
         retryResetData     => retryResetReqData,
         retryResetReady    => retryResetReqReady,
         -- retryHandler.srvPort.request
         retryReqValid      => retrySrvReqValid,
         retryReqData       => retrySrvReqData,
         retryReqReady      => retrySrvReqReady,
         -- retryHandler.srvPort.response
         retryRespValid     => retrySrvRespValid,
         retryRespData      => retrySrvRespData,
         retryRespGetEn     => retrySrvRespGetEn,
         -- retryHandler.notifyTimeOut2SQ
         timeOutValid       => retryTimeOutValid,
         timeOutData        => retryTimeOutData,
         timeOutGetEn       => retryTimeOutGetEn,
         -- retryHandler.isRetrying
         isRetrying         => retryIsRetrying,
         -- permCheckSrv client
         permReqValid       => permReqValid,
         permReqData        => permReqData,
         permReqReady       => permReqReady,
         permRespValid      => permRespValid,
         permRespData       => permRespData,
         permRespGetEn      => permRespGetEn,
         -- workCompGenReqPipeOut -> workCompGenSQ
         wcGenReqValid      => respWorkCompValid,
         wcGenReqData       => respWorkCompData,
         wcGenReqRdEn       => respWorkCompRdEn);

   -----------------------------------------------------------------------------
   -- U_WorkCompGenSq : workCompGenSQ
   --   mkWorkCompGenSQ(contextSQ.statusSQ, payloadConsumer.response,
   --      reqGenSQ.workCompGenReqPipeOut, respHandleSQ.workCompGenReqPipeOut)
   -----------------------------------------------------------------------------
   U_WorkCompGenSq : entity surf.WorkCompGenSq
      generic map (
         TPD_G => TPD_G)
      port map (
         clk                   => clk,
         rst                   => rst,
         -- comm status
         isReset_i             => isReset,
         isRTS_i               => isRTS,
         isStableRTS_i         => isStableRTS,
         isERR_i               => isERR,
         getSigAll_i           => sigAll,
         getPKEY_i             => pkey,
         getSQPN_i             => sqpn,
         -- payloadConRespPort <- payloadConsumer.response
         payloadConRespValid_i => pcRespOutValid,
         payloadConRespData_i  => pcRespOutData,
         payloadConRespGetEn_o => pcRespOutReady,
         -- wcGenReqPipeInFromReqGenInSQ <- reqGenSQ.workCompGenReqPipeOut
         reqGenInValid_i       => reqGenWorkCompValid,
         reqGenInData_i        => reqGenWorkCompData,
         reqGenInDeq_o         => reqGenWorkCompRdEn,
         -- wcGenReqPipeInFromRespHandleInSQ <- respHandleSQ.workCompGenReqPipeOut
         respHandleInValid_i   => respWorkCompValid,
         respHandleInData_i    => respWorkCompData,
         respHandleInDeq_o     => respWorkCompRdEn,
         -- workCompPipeOut -> SQ interface (workCompSQ)
         workCompValid_o       => workCompValid,
         workCompData_o        => workCompData,
         workCompRdEn_i        => workCompRdEn,
         -- hasErr()
         hasErr_o              => workCompHasErr);

   -----------------------------------------------------------------------------
   -- pendingWorkReqNotEmpty method = pendingWorkReqBuf.fifof.notEmpty
   -----------------------------------------------------------------------------
   pendingWorkReqNotEmpty <= scanFifoNotEmpty;

end architecture rtl;
