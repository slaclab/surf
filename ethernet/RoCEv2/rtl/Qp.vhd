-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Top-level Queue-Pair integration.  mkQP is 95% a wiring container: it
--   instantiates the controller, the SQ and RQ datapaths, their payload
--   generators, DMA read/write controllers, DMA/perm server proxies and the two
--   RDMA packet meta+payload pipes, threads the shared controller context down
--   to every child, and re-exports a handful of child interfaces on the
--   QueuePair interface.  The only genuine FSM state it owns is FOUR cancel
--   flags (mkReg(False)) driven by an error-flush / graceful-stop controller
--   (7 rules) that is inert in normal operation.
--
--   Because the sequential state is tiny (4 sl flags) but the wiring is large,
--   this file is emitted as: SURF two-process FSM (comb/seq over a RegType with
--   the 4 flags) for the flush controller + Mealy method-strobes, PLUS a large
--   structural instantiation/port-map body for the child netlist (same pattern
--   as the sibling container SqQueuePair.vhd, OQ-EMIT-SQQP-01).
--
--   Child entity instances (each separately emitted; module-variant resolution
--   below is from QueuePair.bsv's imports — it imports ONLY PayloadConAndGen, and
--   the module signatures take a CntrlStatus first arg, so mkDmaReadCntrl /
--   mkPayloadGenerator bind the ConAndGen variants, NOT the PayloadGen ones):
--     U_CntrlQp        : work.CntrlQp                 (mkCntrlQP)
--     U_Sq             : work.SqQueuePair             (mkSQ)
--     U_Rq             : work.Rq                      (mkRQ)
--     U_PayGenRq/Sq    : work.PayloadGeneratorConAndGen(mkPayloadGenerator ×2)
--     U_DmaRdCntrlRq/Sq: work.DmaReadCntrlConAndGen   (mkDmaReadCntrl ×2)
--     U_DmaWrCntrlRq/Sq: work.DmaWriteCntrl           (mkDmaWriteCntrl ×2)
--     U_DmaRdProxyRq/Sq: work.ServerProxy             (mkServerProxy, DmaRead)
--     U_DmaWrProxyRq/Sq: work.ServerProxy             (mkServerProxy, DmaWrite)
--     U_PermProxyRq/Sq : work.ServerProxy             (mkServerProxy, PermCheck)
--     U_ReqPktPipe     : work.RdmaPktMetaDataAndPayloadPipe (mkRdmaPkt…Pipe)
--     U_RespPktPipe    : work.RdmaPktMetaDataAndPayloadPipe (mkRdmaPkt…Pipe)
--
--   SURF components instantiated DIRECTLY by this entity:
--     U_RecvReqQ : surf.Fifo  (BSV recvReqQ <- mkSizedFIFOF(MAX_QP_WR), RecvReq)
--                  source: surf/base/fifo/rtl/Fifo.vhd
--     U_WorkReqQ : surf.Fifo  (BSV workReqQ <- mkFIFOF, WorkReq)
--                  source: surf/base/fifo/rtl/Fifo.vhd
--   Both are FWFT (valid == notEmpty, dout == first) so toPipeOut lowers to
--   valid/dout/rd_en.  clear() is lowered to a synchronous flush by OR-ing the
--   controller isReset LEVEL into the FIFO reset (OQ-FSM-QP-02 recommendation:
--   fifoRst <= rst or isReset).
--
--   statusSQ / statusRQ export (OQ-EMIT-QP-01): the QueuePair interface exports
--   two CntrlStatus interfaces (statusSQ, statusRQ).  In mkCntrlQP both share the
--   SAME comm sub-interface (Controller.bsv:954-975: interface comm =
--   getCntrlCommStatus for both), differing only in getTypeQP (sqTypeReg vs
--   rqTypeReg) and the constant isSQ (True vs False).  To avoid duplicating ~30
--   identical comm output ports, this entity exports ONE shared comm bundle
--   (comm*) plus statusGetTypeSq/statusGetTypeRq and the two constant isSQ flags.
--   A downstream consumer wires both statusSQ.comm and statusRQ.comm to the same
--   comm* ports.  This is faithful to the hardware (single shared status) and is
--   documented in OQ-EMIT-QP-01.
--
--   Composite word widths (traced from child port declarations already emitted):
--     RecvReq         = 216  WorkReq        = 601  ReqQP           = 301
--     RespQP          = 274  DataStream     = 290  WorkComp        = 222
--     RdmaPktMetaData = 649  DmaReadReq     = 176  DmaReadResp     = 383
--     DmaWriteReq     = 419  DmaWriteResp   =  53  DmaReadCntrlReq = 198
--     DmaReadCntrlResp= 385  PayloadGenReq  = 199  PayloadGenResp  =   2
--     PermCheckReq    = 267  MAX_QP_WR      =  32
--
--   Open questions (out/04-vhdl/OPEN_QUESTIONS.md): OQ-EMIT-QP-01 (shared comm
--   export), OQ-EMIT-QP-02 (FIFO clear lowered to reset OR, from OQ-FSM-QP-02),
--   OQ-EMIT-QP-03 (dmaReadCntrl isSQ tied to a constant per context; the child
--   has no internal sink anyway — OQ-FSM-DRCCAG-02).
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

library surf;
use surf.StdRtlPkg.all;

entity Qp is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';        -- '1' for active-HIGH reset
      RST_ASYNC_G    : boolean := false;
      -- Pruning generics (all true = full engine, identical to the verified
      -- netlist). EN_TX_G=false removes the requester (SQ) subtree; EN_RX_G=
      -- false removes the responder (RQ) subtree (ACK/NAK reception lives on
      -- the SQ side and is NOT affected); EN_READ_G=false removes RDMA READ /
      -- atomic support on both sides. Pruned-side ports are tied inert:
      -- user-facing inputs refuse (ready='0'), wire-side pipes drain
      -- (ready='1'), outputs quiesce (valid='0').
      EN_TX_G        : boolean := true;
      EN_RX_G        : boolean := true;
      EN_READ_G      : boolean := true;
      -- Settings.bsv MAX_QP_WR (BSV default 32): max pending work requests per
      -- QP (effective in-flight window is MAX_QP_WR_G-1, one slot reserved).
      -- Must be a power of 2 (sizes SqQueuePair's ScanFifoF).
      MAX_QP_WR_G    : positive := 4);
   port (
      clk : in sl;
      rst : in sl := not RST_POLARITY_G;      -- FPGA async/sync reset

      -----------------------------------------------------------------------
      -- srvPortQP = cntrl.srvPort : Server#(ReqQP(301b), RespQP(274b))
      -----------------------------------------------------------------------
      srvPortReqValid  : in  sl;
      srvPortReqData   : in  slv(300 downto 0);
      srvPortReqReady  : out sl;
      srvPortRespValid : out sl;
      srvPortRespData  : out slv(273 downto 0);
      srvPortRespReady : in  sl;

      -----------------------------------------------------------------------
      -- recvReqIn = toPut(recvReqQ) : Put#(RecvReq(216b))
      -- workReqIn = toPut(workReqQ) : Put#(WorkReq(601b))
      -----------------------------------------------------------------------
      recvReqInValid : in  sl;
      recvReqInData  : in  slv(215 downto 0);
      recvReqInReady : out sl;                -- = recvReqQ.not_full
      workReqInValid : in  sl;
      workReqInData  : in  slv(600 downto 0);
      workReqInReady : out sl;                -- = workReqQ.not_full

      -----------------------------------------------------------------------
      -- dmaReadClt4RQ / dmaReadClt4SQ  : Client#(DmaReadReq(176b), DmaReadResp(383b))
      -- dmaWriteClt4RQ / dmaWriteClt4SQ: Client#(DmaWriteReq(419b), DmaWriteResp(53b))
      -- (each = a mkServerProxy cltPort)
      -----------------------------------------------------------------------
      dmaReadClt4RqReqValid   : out sl;
      dmaReadClt4RqReqData    : out slv(175 downto 0);
      dmaReadClt4RqReqReady   : in  sl;
      dmaReadClt4RqRespValid  : in  sl;
      dmaReadClt4RqRespData   : in  slv(382 downto 0);
      dmaReadClt4RqRespReady  : out sl;
      dmaWriteClt4RqReqValid  : out sl;
      dmaWriteClt4RqReqData   : out slv(418 downto 0);
      dmaWriteClt4RqReqReady  : in  sl;
      dmaWriteClt4RqRespValid : in  sl;
      dmaWriteClt4RqRespData  : in  slv(52 downto 0);
      dmaWriteClt4RqRespReady : out sl;
      dmaReadClt4SqReqValid   : out sl;
      dmaReadClt4SqReqData    : out slv(175 downto 0);
      dmaReadClt4SqReqReady   : in  sl;
      dmaReadClt4SqRespValid  : in  sl;
      dmaReadClt4SqRespData   : in  slv(382 downto 0);
      dmaReadClt4SqRespReady  : out sl;
      dmaWriteClt4SqReqValid  : out sl;
      dmaWriteClt4SqReqData   : out slv(418 downto 0);
      dmaWriteClt4SqReqReady  : in  sl;
      dmaWriteClt4SqRespValid : in  sl;
      dmaWriteClt4SqRespData  : in  slv(52 downto 0);
      dmaWriteClt4SqRespReady : out sl;

      -----------------------------------------------------------------------
      -- permCheckClt4RQ / permCheckClt4SQ : Client#(PermCheckReq(267b), Bool)
      -----------------------------------------------------------------------
      permCheckClt4RqReqValid  : out sl;
      permCheckClt4RqReqData   : out slv(266 downto 0);
      permCheckClt4RqReqReady  : in  sl;
      permCheckClt4RqRespValid : in  sl;
      permCheckClt4RqRespData  : in  sl;
      permCheckClt4RqRespReady : out sl;
      permCheckClt4SqReqValid  : out sl;
      permCheckClt4SqReqData   : out slv(266 downto 0);
      permCheckClt4SqReqReady  : in  sl;
      permCheckClt4SqRespValid : in  sl;
      permCheckClt4SqRespData  : in  sl;
      permCheckClt4SqRespReady : out sl;

      -----------------------------------------------------------------------
      -- reqPktPipeIn / respPktPipeIn : RdmaPktMetaDataAndPayloadPipeIn
      --   .pktMetaData.put (RdmaPktMetaData 649b) + .payload.put (DataStream 290b)
      -----------------------------------------------------------------------
      reqPktMetaWrEn     : in  sl;
      reqPktMetaData     : in  slv(648 downto 0);
      reqPktMetaReady    : out sl;
      reqPktPayloadWrEn  : in  sl;
      reqPktPayloadData  : in  slv(289 downto 0);
      reqPktPayloadReady : out sl;
      respPktMetaWrEn     : in  sl;
      respPktMetaData     : in  slv(648 downto 0);
      respPktMetaReady    : out sl;
      respPktPayloadWrEn  : in  sl;
      respPktPayloadData  : in  slv(289 downto 0);
      respPktPayloadReady : out sl;

      -----------------------------------------------------------------------
      -- statusSQ / statusRQ export : shared CntrlCommStatus bundle (comm*) plus
      -- per-context getTypeQP and the constant isSQ (OQ-EMIT-QP-01).
      -----------------------------------------------------------------------
      commIsCreate                   : out sl;
      commIsErr                      : out sl;
      commIsInit                     : out sl;
      commIsNonErr                   : out sl;
      commIsReset                    : out sl;
      commIsRTR                      : out sl;
      commIsRTS                      : out sl;
      commIsSQD                      : out sl;
      commIsUnknown                  : out sl;
      commIsRTR2RTS                  : out sl;
      commIsStableRTS                : out sl;
      commGetAccessFlags             : out slv(7 downto 0);
      commGetMaxRnrCnt               : out slv(2 downto 0);
      commGetMaxRetryCnt             : out slv(2 downto 0);
      commGetMinRnrTimer             : out slv(4 downto 0);
      commGetMaxTimeOut              : out slv(4 downto 0);
      commGetPendingWorkReqNum       : out slv(7 downto 0);
      commGetPendingRecvReqNum       : out slv(7 downto 0);
      commGetPendingReadAtomicReqNum : out slv(7 downto 0);
      commGetPendingDestReadAtomicReqNum : out slv(7 downto 0);
      commGetSigAll                  : out sl;
      commGetSQPN                    : out slv(23 downto 0);
      commGetDQPN                    : out slv(23 downto 0);
      commGetPKEY                    : out slv(15 downto 0);
      commGetQKEY                    : out slv(31 downto 0);
      commGetPMTU                    : out slv(2 downto 0);
      statusGetTypeSq                : out slv(3 downto 0);
      statusGetTypeRq                : out slv(3 downto 0);
      statusSqIsSQ                   : out sl;
      statusRqIsSQ                   : out sl;

      -----------------------------------------------------------------------
      -- rdmaReqPipeOut  = sq.rdmaReqDataStreamPipeOut  (DataStream 290b)
      -- rdmaRespPipeOut = rq.rdmaRespDataStreamPipeOut (DataStream 290b)
      -- workCompPipeOutRQ = rq.workCompRQ.workCompPipeOut (WorkComp 222b)
      -- workCompPipeOutSQ = sq.workCompSQ.workCompPipeOut (WorkComp 222b)
      -----------------------------------------------------------------------
      rdmaReqValid   : out sl;
      rdmaReqData    : out slv(289 downto 0);
      rdmaReqRdEn    : in  sl;
      rdmaRespValid  : out sl;
      rdmaRespData   : out slv(289 downto 0);
      rdmaRespRdEn   : in  sl;
      workCompRqValid : out sl;
      workCompRqData  : out slv(221 downto 0);
      workCompRqRdEn  : in  sl;
      workCompSqValid : out sl;
      workCompSqData  : out slv(221 downto 0);
      workCompSqRdEn  : in  sl);
end entity Qp;

architecture rtl of Qp is

   -----------------------------------------------------------------------------
   -- Word widths (traced from already-emitted child ports)
   -----------------------------------------------------------------------------
   constant RECV_REQ_C          : positive := 216;
   constant WORK_REQ_C          : positive := 601;
   constant DATA_STREAM_C       : positive := 290;
   constant RDMA_META_C         : positive := 649;
   constant DMA_READ_REQ_C      : positive := 176;
   constant DMA_READ_RESP_C     : positive := 383;
   constant DMA_WRITE_REQ_C     : positive := 419;
   constant DMA_WRITE_RESP_C    : positive := 53;
   constant PERM_CHECK_REQ_C    : positive := 267;
   -- recvReqQ = mkSizedFIFOF(MAX_QP_WR); workReqQ = mkFIFOF -> min depth
   -- surf.Fifo needs ADDR_WIDTH_G >= 4, so depth is at least 16 (>= MAX_QP_WR ok)
   constant RECV_REQ_AW_C : positive := maximum(log2(MAX_QP_WR_G), 4);
   constant WORK_REQ_AW_C : positive := 4;   -- min surf.Fifo depth (BSV mkFIFOF)

   -----------------------------------------------------------------------------
   -- FSM state : the four DMA-cancel flags (mkReg(False))
   -----------------------------------------------------------------------------
   type RegType is record
      rqDmaReadCancelReg  : sl;
      sqDmaReadCancelReg  : sl;
      rqDmaWriteCancelReg : sl;
      sqDmaWriteCancelReg : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      rqDmaReadCancelReg  => '0',
      sqDmaReadCancelReg  => '0',
      rqDmaWriteCancelReg => '0',
      sqDmaWriteCancelReg => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Mealy method-strobes (combinational, driven by the comb process)
   signal setStateErrStrobe  : sl;   -- errTrigger        -> cntrl.setStateErr
   signal errFlushDoneStrobe : sl;   -- waitGracefulStop  -> cntrl.errFlushDone
   signal cancelReadRq       : sl;   -- cancelDmaReadRQ   -> dmaReadCntrl4RQ.cancel
   signal cancelReadSq       : sl;   -- cancelDmaReadSQ   -> dmaReadCntrl4SQ.cancel
   signal cancelWriteRq      : sl;   -- cancelDmaWriteRQ  -> dmaWriteCntrl4RQ.cancel
   signal cancelWriteSq      : sl;   -- cancelDmaWriteSQ  -> dmaWriteCntrl4SQ.cancel
   signal reqPipeClr         : sl;   -- resetAndClear     -> reqPktPipe.clear
   signal respPipeClr        : sl;   -- resetAndClear     -> respPktPipe.clear
   signal fifoClr            : sl;   -- resetAndClear     -> recvReqQ/workReqQ clear

   -----------------------------------------------------------------------------
   -- Controller (U_CntrlQp) status/context outputs (shared, fanned to children
   -- and re-exported on statusSQ/statusRQ).
   -----------------------------------------------------------------------------
   signal cIsCreate    : sl;
   signal cIsErr       : sl;
   signal cIsInit      : sl;
   signal cIsNonErr    : sl;
   signal cIsReset     : sl;
   signal cIsRtr       : sl;
   signal cIsRts       : sl;
   signal cIsSqd       : sl;
   signal cIsUnknown   : sl;
   signal cIsRtr2Rts   : sl;
   signal cIsStableRts : sl;
   signal cAccessFlags : slv(7 downto 0);
   signal cMaxRnrCnt   : slv(2 downto 0);
   signal cMaxRetryCnt : slv(2 downto 0);
   signal cMaxTimeOut  : slv(4 downto 0);
   signal cMinRnrTimer : slv(4 downto 0);
   signal cPendingWorkReqNum           : slv(7 downto 0);
   signal cPendingRecvReqNum           : slv(7 downto 0);
   signal cPendingReadAtomicReqNum     : slv(7 downto 0);
   signal cPendingDestReadAtomicReqNum : slv(7 downto 0);
   signal cSigAll      : sl;
   signal cSqpn        : slv(23 downto 0);
   signal cDqpn        : slv(23 downto 0);
   signal cPkey        : slv(15 downto 0);
   signal cQkey        : slv(31 downto 0);
   signal cPmtu        : slv(2 downto 0);
   signal cTypeSq      : slv(3 downto 0);
   signal cTypeRq      : slv(3 downto 0);
   -- contextSQ shared next-PSN register
   signal cGetNpsn     : slv(23 downto 0);
   signal sqSetNpsnEn  : sl;
   signal sqSetNpsn    : slv(23 downto 0);
   -- contextRQ RMW registers (cntrl get* out; rq set*/restore in)
   signal cPermCheckReq        : slv(266 downto 0);
   signal cTotalDmaWriteLen    : slv(31 downto 0);
   signal cRemainingDmaWriteLen: slv(31 downto 0);
   signal cNextDmaWriteAddr    : slv(63 downto 0);
   signal cSendWriteReqPktNum  : slv(24 downto 0);
   signal cPreReqOpCode        : slv(4 downto 0);
   signal cEpoch               : sl;
   signal cMsn                 : slv(23 downto 0);
   signal cIsRespPktNumZero    : sl;
   signal cRespPktNum          : slv(24 downto 0);
   signal cCurRespPSN          : slv(23 downto 0);
   signal cEpsn                : slv(23 downto 0);

   -----------------------------------------------------------------------------
   -- U_Rq -> U_CntrlQp contextRQ write-backs / restore
   -----------------------------------------------------------------------------
   signal rqIncEpoch                  : sl;
   signal rqSetRespPktNumValid        : sl;
   signal rqSetRespPktNumData         : slv(24 downto 0);
   signal rqSetEPSNValid              : sl;
   signal rqSetEPSNData               : slv(23 downto 0);
   signal rqSetPreReqOpCodeValid      : sl;
   signal rqSetPreReqOpCodeData       : slv(4 downto 0);
   signal rqRestoreValid              : sl;
   signal rqRestorePreOpCodeData      : slv(4 downto 0);
   signal rqRestorePsnData            : slv(23 downto 0);
   signal rqSetPermCheckReqValid      : sl;
   signal rqSetPermCheckReqData       : slv(266 downto 0);
   signal rqSetNextDmaWriteAddrValid  : sl;
   signal rqSetNextDmaWriteAddrData   : slv(63 downto 0);
   signal rqSetSendWriteReqPktNumValid: sl;
   signal rqSetSendWriteReqPktNumData : slv(24 downto 0);
   signal rqSetRemainingDmaWriteLenValid : sl;
   signal rqSetRemainingDmaWriteLenData  : slv(31 downto 0);
   signal rqSetTotalDmaWriteLenValid  : sl;
   signal rqSetTotalDmaWriteLenData   : slv(31 downto 0);
   signal rqSetCurRespPSNValid        : sl;
   signal rqSetCurRespPSNData         : slv(23 downto 0);
   signal rqSetMSNValid               : sl;
   signal rqSetMSNData                : slv(23 downto 0);

   -----------------------------------------------------------------------------
   -- Payload generators (PayloadGeneratorConAndGen) <-> Rq / Sq / DmaReadCntrl
   -----------------------------------------------------------------------------
   -- payloadGenerator4RQ
   signal pgRqReqValid    : sl;                        -- rq -> pg srvPort.request
   signal pgRqReqData     : slv(198 downto 0);
   signal pgRqReqReady    : sl;
   signal pgRqRespValid   : sl;                        -- pg -> rq srvPort.response
   signal pgRqRespData    : slv(1 downto 0);
   signal pgRqRespReady   : sl;
   signal pgRqDataValid   : sl;                        -- pg payloadDataStreamPipeOut -> rq
   signal pgRqDataData    : slv(289 downto 0);
   signal pgRqDataDeq     : sl;
   signal pgRqNotEmpty    : sl;                        -- pg.payloadNotEmpty (-> FSM)
   signal pgRqDmaReqValid : sl;                        -- pg -> dmaReadCntrl4RQ.request
   signal pgRqDmaReqData  : slv(197 downto 0);
   signal pgRqDmaReqReady : sl;
   signal pgRqDmaRespValid: sl;                        -- dmaReadCntrl4RQ.response -> pg
   signal pgRqDmaRespData : slv(384 downto 0);
   signal pgRqDmaRespReady: sl;
   -- payloadGenerator4SQ
   signal pgSqReqValid    : sl;
   signal pgSqReqData     : slv(198 downto 0);
   signal pgSqReqReady    : sl;
   signal pgSqRespValid   : sl;
   signal pgSqRespData    : slv(1 downto 0);
   signal pgSqRespReady   : sl;
   signal pgSqDataValid   : sl;
   signal pgSqDataData    : slv(289 downto 0);
   signal pgSqDataDeq     : sl;
   signal pgSqNotEmpty    : sl;
   signal pgSqDmaReqValid : sl;
   signal pgSqDmaReqData  : slv(197 downto 0);
   signal pgSqDmaReqReady : sl;
   signal pgSqDmaRespValid: sl;
   signal pgSqDmaRespData : slv(384 downto 0);
   signal pgSqDmaRespReady: sl;

   -----------------------------------------------------------------------------
   -- DMA read/write controllers <-> server proxies (dmaReadSrv/dmaWriteSrv client)
   -----------------------------------------------------------------------------
   -- dmaReadCntrl4RQ dmaReadSrv client -> dmaReadProxy4RQ.srvPort
   signal drRqDmaReqValid : sl;
   signal drRqDmaReqData  : slv(DMA_READ_REQ_C-1 downto 0);
   signal drRqDmaReqReady : sl;
   signal drRqDmaRespValid: sl;
   signal drRqDmaRespData : slv(DMA_READ_RESP_C-1 downto 0);
   signal drRqDmaRespReady: sl;
   signal drRqIsIdle      : sl;
   -- dmaReadCntrl4SQ
   signal drSqDmaReqValid : sl;
   signal drSqDmaReqData  : slv(DMA_READ_REQ_C-1 downto 0);
   signal drSqDmaReqReady : sl;
   signal drSqDmaRespValid: sl;
   signal drSqDmaRespData : slv(DMA_READ_RESP_C-1 downto 0);
   signal drSqDmaRespReady: sl;
   signal drSqIsIdle      : sl;
   -- dmaWriteCntrl4RQ srvPort.request (from rq) + dmaWriteSrv client -> proxy
   signal dwRqReqValid    : sl;                        -- rq -> dmaWriteCntrl4RQ.request
   signal dwRqReqData     : slv(DMA_WRITE_REQ_C-1 downto 0);
   signal dwRqReqReady    : sl;
   signal dwRqRespValid   : sl;                        -- dmaWriteCntrl4RQ.response -> rq
   signal dwRqRespData    : slv(DMA_WRITE_RESP_C-1 downto 0);
   signal dwRqRespReady   : sl;
   signal dwRqDmaReqValid : sl;                        -- dmaWriteCntrl4RQ -> proxy
   signal dwRqDmaReqData  : slv(DMA_WRITE_REQ_C-1 downto 0);
   signal dwRqDmaReqReady : sl;
   signal dwRqDmaRespValid: sl;                        -- proxy -> dmaWriteCntrl4RQ
   signal dwRqDmaRespData : slv(DMA_WRITE_RESP_C-1 downto 0);
   signal dwRqDmaRespReady: sl;
   signal dwRqIsIdle      : sl;
   -- dmaWriteCntrl4SQ srvPort.request (from sq) + dmaWriteSrv client -> proxy
   signal dwSqReqValid    : sl;                        -- sq -> dmaWriteCntrl4SQ.request
   signal dwSqReqData     : slv(DMA_WRITE_REQ_C-1 downto 0);
   signal dwSqReqReady    : sl;
   signal dwSqRespValid   : sl;                        -- dmaWriteCntrl4SQ.response -> sq
   signal dwSqRespData    : slv(DMA_WRITE_RESP_C-1 downto 0);
   signal dwSqRespReady   : sl;
   signal dwSqDmaReqValid : sl;
   signal dwSqDmaReqData  : slv(DMA_WRITE_REQ_C-1 downto 0);
   signal dwSqDmaReqReady : sl;
   signal dwSqDmaRespValid: sl;
   signal dwSqDmaRespData : slv(DMA_WRITE_RESP_C-1 downto 0);
   signal dwSqDmaRespReady: sl;
   signal dwSqIsIdle      : sl;

   -----------------------------------------------------------------------------
   -- Perm-check server clients (rq / sq) -> perm proxies
   -----------------------------------------------------------------------------
   signal rqPermReqValid  : sl;
   signal rqPermReqData   : slv(PERM_CHECK_REQ_C-1 downto 0);
   signal rqPermReqReady  : sl;
   signal rqPermRespValid : sl;
   signal rqPermRespData  : sl;
   signal rqPermRespReady : sl;
   signal sqPermReqValid  : sl;
   signal sqPermReqData   : slv(PERM_CHECK_REQ_C-1 downto 0);
   signal sqPermReqReady  : sl;
   signal sqPermRespValid : sl;
   signal sqPermRespData  : sl;
   signal sqPermRespReady : sl;

   -----------------------------------------------------------------------------
   -- Packet pipes (reqPktPipe -> rq, respPktPipe -> sq) read side
   -----------------------------------------------------------------------------
   signal reqPipeMetaValid    : sl;
   signal reqPipeMetaData     : slv(RDMA_META_C-1 downto 0);
   signal reqPipeMetaRdEn     : sl;
   signal reqPipePayloadValid : sl;
   signal reqPipePayloadData  : slv(DATA_STREAM_C-1 downto 0);
   signal reqPipePayloadRdEn  : sl;
   signal respPipeMetaValid    : sl;
   signal respPipeMetaData     : slv(RDMA_META_C-1 downto 0);
   signal respPipeMetaRdEn     : sl;
   signal respPipePayloadValid : sl;
   signal respPipePayloadData  : slv(DATA_STREAM_C-1 downto 0);
   signal respPipePayloadRdEn  : sl;

   -----------------------------------------------------------------------------
   -- Input FIFOs (surf.Fifo) read side + reset
   -----------------------------------------------------------------------------
   signal recvReqRst      : sl;
   signal recvReqValid    : sl;                    -- = not empty (FWFT)
   signal recvReqDout     : slv(RECV_REQ_C-1 downto 0);
   signal recvReqRdEn     : sl;
   signal workReqRst      : sl;
   signal workReqValid    : sl;
   signal workReqDout     : slv(WORK_REQ_C-1 downto 0);
   signal workReqRdEn     : sl;

   -----------------------------------------------------------------------------
   -- Sq / Rq status/method outputs consumed by the flush FSM
   -----------------------------------------------------------------------------
   signal rqWorkCompHasErr    : sl;
   signal sqWorkCompHasErr    : sl;
   signal rqRespHeaderNotEmpty: sl;   -- rq.respHeaderOutNotEmpty
   signal sqReqHeaderNotEmpty : sl;   -- sq.reqHeaderOutNotEmpty
   signal sqPendingNotEmpty   : sl;   -- sq.pendingWorkReqNotEmpty

begin

   -----------------------------------------------------------------------------
   -- statusSQ / statusRQ export (shared comm; per-context type + isSQ)
   -----------------------------------------------------------------------------
   commIsCreate                       <= cIsCreate;
   commIsErr                          <= cIsErr;
   commIsInit                         <= cIsInit;
   commIsNonErr                       <= cIsNonErr;
   commIsReset                        <= cIsReset;
   commIsRTR                          <= cIsRtr;
   commIsRTS                          <= cIsRts;
   commIsSQD                          <= cIsSqd;
   commIsUnknown                      <= cIsUnknown;
   commIsRTR2RTS                      <= cIsRtr2Rts;
   commIsStableRTS                    <= cIsStableRts;
   commGetAccessFlags                 <= cAccessFlags;
   commGetMaxRnrCnt                   <= cMaxRnrCnt;
   commGetMaxRetryCnt                 <= cMaxRetryCnt;
   commGetMinRnrTimer                 <= cMinRnrTimer;
   commGetMaxTimeOut                  <= cMaxTimeOut;
   commGetPendingWorkReqNum           <= cPendingWorkReqNum;
   commGetPendingRecvReqNum           <= cPendingRecvReqNum;
   commGetPendingReadAtomicReqNum     <= cPendingReadAtomicReqNum;
   commGetPendingDestReadAtomicReqNum <= cPendingDestReadAtomicReqNum;
   commGetSigAll                      <= cSigAll;
   commGetSQPN                        <= cSqpn;
   commGetDQPN                        <= cDqpn;
   commGetPKEY                        <= cPkey;
   commGetQKEY                        <= cQkey;
   commGetPMTU                        <= cPmtu;
   statusGetTypeSq                    <= cTypeSq;
   statusGetTypeRq                    <= cTypeRq;
   statusSqIsSQ                       <= '1';       -- CntrlStatus.isSQ (statusSQ)
   statusRqIsSQ                       <= '0';       -- CntrlStatus.isSQ (statusRQ)

   -----------------------------------------------------------------------------
   -- Input-FIFO clear() lowered to a synchronous flush (OQ-EMIT-QP-02): OR the
   -- controller isReset LEVEL into the surf.Fifo reset while a QP soft-reset is
   -- held (resetAndClear -> recvReqQ.clear / workReqQ.clear).
   -----------------------------------------------------------------------------
   recvReqRst <= rst or fifoClr;
   workReqRst <= rst or fifoClr;

   -----------------------------------------------------------------------------
   -- Error-flush / graceful-stop FSM (mkQP rules resetAndClear, errTrigger,
   -- cancelDmaRead/Write RQ/SQ, waitGracefulStop).  Two-process comb/seq over
   -- the four cancel flags; every method call is a Mealy strobe.  The three
   -- controller phases (isReset / isNonErr / isERR) are mutually exclusive, so
   -- they lower to an if/elsif on the shared comm status.
   -----------------------------------------------------------------------------
   comb : process (r, cIsReset, cIsNonErr, cIsErr, rqWorkCompHasErr,
                   sqWorkCompHasErr, rqRespHeaderNotEmpty, pgRqNotEmpty,
                   sqReqHeaderNotEmpty, pgSqNotEmpty, recvReqValid, workReqValid,
                   sqPendingNotEmpty, drRqIsIdle, dwRqIsIdle, drSqIsIdle,
                   dwSqIsIdle) is
      variable v : RegType;
   begin
      v := r;

      -- default: all Mealy strobes deasserted
      setStateErrStrobe  <= '0';
      errFlushDoneStrobe <= '0';
      cancelReadRq       <= '0';
      cancelReadSq       <= '0';
      cancelWriteRq      <= '0';
      cancelWriteSq      <= '0';
      reqPipeClr         <= '0';
      respPipeClr        <= '0';
      fifoClr            <= '0';

      if (cIsReset = '1') then
         -- rule resetAndClear: flush both input FIFOs + both packet pipes and
         -- clear all four cancel flags every cycle isReset is held.
         fifoClr             <= '1';
         reqPipeClr          <= '1';
         respPipeClr         <= '1';
         v.rqDmaReadCancelReg  := '0';
         v.sqDmaReadCancelReg  := '0';
         v.rqDmaWriteCancelReg := '0';
         v.sqDmaWriteCancelReg := '0';

      elsif (cIsErr = '1') then
         -- rule cancelDmaReadRQ: gated on !flag AND the RQ read/response path
         -- being drained; fires once then latches.
         if (r.rqDmaReadCancelReg = '0') and
            not (rqRespHeaderNotEmpty = '1' and pgRqNotEmpty = '1') then
            cancelReadRq         <= '1';
            v.rqDmaReadCancelReg := '1';
         end if;
         -- rule cancelDmaReadSQ
         if (r.sqDmaReadCancelReg = '0') and
            not (sqReqHeaderNotEmpty = '1' and pgSqNotEmpty = '1') then
            cancelReadSq         <= '1';
            v.sqDmaReadCancelReg := '1';
         end if;
         -- rule cancelDmaWriteRQ: no flag guard -> re-asserts every isERR cycle.
         cancelWriteRq         <= '1';
         v.rqDmaWriteCancelReg := '1';
         -- rule cancelDmaWriteSQ
         cancelWriteSq         <= '1';
         v.sqDmaWriteCancelReg := '1';
         -- rule waitGracefulStop: reads the OLD (registered) flag values, so
         -- write flags only satisfy this from the cycle AFTER they latch.
         if (recvReqValid = '0') and (workReqValid = '0') and
            (sqPendingNotEmpty = '0') and
            (r.rqDmaReadCancelReg = '1') and (r.rqDmaWriteCancelReg = '1') and
            (r.sqDmaReadCancelReg = '1') and (r.sqDmaWriteCancelReg = '1') and
            (drRqIsIdle = '1') and (dwRqIsIdle = '1') and
            (drSqIsIdle = '1') and (dwSqIsIdle = '1') then
            errFlushDoneStrobe <= '1';
         end if;

      elsif (cIsNonErr = '1') then
         -- rule errTrigger: request controller -> ERR on any child WorkComp error
         if (rqWorkCompHasErr = '1') or (sqWorkCompHasErr = '1') then
            setStateErrStrobe <= '1';
         end if;
      end if;

      rin <= v;
   end process comb;

   seq : process (clk, rst) is
   begin
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
            r <= REG_INIT_C after TPD_G;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process seq;

   -----------------------------------------------------------------------------
   -- Pruning tie-offs. Each block drives ONLY signals that a kept process,
   -- kept instance, or entity output still reads; signals whose producer AND
   -- consumer are both pruned are left undriven (no reader). The flush FSM
   -- inputs are tied to their "permanently drained/idle" values so the
   -- graceful-stop condition is unaffected.
   -----------------------------------------------------------------------------
   GEN_NO_TX : if not EN_TX_G generate
      -- top ports
      workReqInReady      <= '0';           -- refuse work requests
      respPktMetaReady    <= '1';           -- drain resp pkt pipe write side
      respPktPayloadReady <= '1';
      rdmaReqValid        <= '0';           -- DataStreamArb slot 2i+1 idle
      rdmaReqData         <= (others => '0');
      workCompSqValid     <= '0';
      workCompSqData      <= (others => '0');
      dmaReadClt4SqReqValid  <= '0';
      dmaReadClt4SqReqData   <= (others => '0');
      dmaReadClt4SqRespReady <= '1';
      -- into U_CntrlQp (only Sq-driven context write)
      sqSetNpsnEn <= '0';
      sqSetNpsn   <= (others => '0');
      -- into flush FSM: SQ permanently drained/idle
      sqWorkCompHasErr    <= '0';
      sqReqHeaderNotEmpty <= '0';
      sqPendingNotEmpty   <= '0';
      pgSqNotEmpty        <= '0';
      drSqIsIdle          <= '1';
      workReqValid        <= '0';
   end generate GEN_NO_TX;

   GEN_NO_RX : if not EN_RX_G generate
      -- top ports
      recvReqInReady     <= '0';            -- refuse recv requests
      reqPktMetaReady    <= '1';            -- drain req pkt pipe write side
      reqPktPayloadReady <= '1';
      rdmaRespValid      <= '0';            -- DataStreamArb slot 2i idle
      rdmaRespData       <= (others => '0');
      workCompRqValid    <= '0';
      workCompRqData     <= (others => '0');
      dmaWriteClt4RqReqValid  <= '0';
      dmaWriteClt4RqReqData   <= (others => '0');
      dmaWriteClt4RqRespReady <= '1';
      permCheckClt4RqReqValid  <= '0';
      permCheckClt4RqReqData   <= (others => '0');
      permCheckClt4RqRespReady <= '1';
      -- into U_CntrlQp (all Rq-driven contextRQ RMW writes)
      rqRestoreValid         <= '0';
      rqRestorePreOpCodeData <= (others => '0');
      rqRestorePsnData       <= (others => '0');
      rqIncEpoch             <= '0';
      rqSetPermCheckReqValid       <= '0';
      rqSetPermCheckReqData        <= (others => '0');
      rqSetTotalDmaWriteLenValid   <= '0';
      rqSetTotalDmaWriteLenData    <= (others => '0');
      rqSetRemainingDmaWriteLenValid <= '0';
      rqSetRemainingDmaWriteLenData  <= (others => '0');
      rqSetNextDmaWriteAddrValid   <= '0';
      rqSetNextDmaWriteAddrData    <= (others => '0');
      rqSetSendWriteReqPktNumValid <= '0';
      rqSetSendWriteReqPktNumData  <= (others => '0');
      rqSetPreReqOpCodeValid       <= '0';
      rqSetPreReqOpCodeData        <= (others => '0');
      rqSetMSNValid                <= '0';
      rqSetMSNData                 <= (others => '0');
      rqSetRespPktNumValid         <= '0';
      rqSetRespPktNumData          <= (others => '0');
      rqSetCurRespPSNValid         <= '0';
      rqSetCurRespPSNData          <= (others => '0');
      rqSetEPSNValid               <= '0';
      rqSetEPSNData                <= (others => '0');
      -- into flush FSM: RQ permanently drained/idle
      rqWorkCompHasErr     <= '0';
      rqRespHeaderNotEmpty <= '0';
      dwRqIsIdle           <= '1';
      recvReqValid         <= '0';
   end generate GEN_NO_RX;

   -- READ-responder payload-fetch chain (U_DmaRdCntrlRq/U_PayGenRq/proxy)
   GEN_NO_RQ_READ : if not (EN_RX_G and EN_READ_G) generate
      dmaReadClt4RqReqValid  <= '0';
      dmaReadClt4RqReqData   <= (others => '0');
      dmaReadClt4RqRespReady <= '1';
      -- toward U_Rq (present when EN_RX_G; its forced classifiers guarantee
      -- pgRqReqValid never asserts)
      pgRqReqReady  <= '1';
      pgRqRespValid <= '0';
      pgRqRespData  <= (others => '0');
      pgRqDataValid <= '0';
      pgRqDataData  <= (others => '0');
      -- into flush FSM
      pgRqNotEmpty <= '0';
      drRqIsIdle   <= '1';
   end generate GEN_NO_RQ_READ;

   -- Requester read-response landing chain (U_DmaWrCntrlSq/U_DmaWrProxySq)
   -- plus the SQ perm check (only queried for read/atomic responses).
   GEN_NO_SQ_READ : if not (EN_TX_G and EN_READ_G) generate
      dmaWriteClt4SqReqValid  <= '0';
      dmaWriteClt4SqReqData   <= (others => '0');
      dmaWriteClt4SqRespReady <= '1';
      permCheckClt4SqReqValid  <= '0';
      permCheckClt4SqReqData   <= (others => '0');
      permCheckClt4SqRespReady <= '1';
      -- toward U_Sq (present when EN_TX_G)
      dwSqReqReady   <= '1';
      dwSqRespValid  <= '0';
      dwSqRespData   <= (others => '0');
      sqPermReqReady  <= '1';
      sqPermRespValid <= '0';
      sqPermRespData  <= '0';
      -- into flush FSM
      dwSqIsIdle <= '1';
   end generate GEN_NO_SQ_READ;

   -----------------------------------------------------------------------------
   -- U_CntrlQp : cntrl (mkCntrlQP) — owns the shared context; srvPort = srvPortQP.
   -----------------------------------------------------------------------------
   U_CntrlQp : entity surf.CntrlQp
      generic map (
         TPD_G       => TPD_G,
         MAX_QP_WR_G => MAX_QP_WR_G)
      port map (
         clk                       => clk,
         rst                       => rst,
         -- srvPort = srvPortQP
         srvReqValid               => srvPortReqValid,
         srvReqData                => srvPortReqData,
         srvReqReady               => srvPortReqReady,
         srvRespValid              => srvPortRespValid,
         srvRespData               => srvPortRespData,
         srvRespReady              => srvPortRespReady,
         -- restorePort <- rq.restore
         restoreValid              => rqRestoreValid,
         restorePreOpCode          => rqRestorePreOpCodeData,
         restoreEpsn               => rqRestorePsnData,
         restoreReady              => open,          -- rq does not consume ready
         -- error control <- flush FSM
         setStateErr               => setStateErrStrobe,
         errFlushDoneIn            => errFlushDoneStrobe,
         inited                    => open,
         -- comm status decodes
         isCreate                  => cIsCreate,
         isErr                     => cIsErr,
         isInit                    => cIsInit,
         isNonErr                  => cIsNonErr,
         isReset                   => cIsReset,
         isRTR                     => cIsRtr,
         isRTS                     => cIsRts,
         isSQD                     => cIsSqd,
         isUnknown                 => cIsUnknown,
         isRTR2RTS                 => cIsRtr2Rts,
         isStableRTS               => cIsStableRts,
         -- comm getters
         getAccessFlags            => cAccessFlags,
         getMaxRnrCnt              => cMaxRnrCnt,
         getMaxRetryCnt            => cMaxRetryCnt,
         getMaxTimeOut             => cMaxTimeOut,
         getMinRnrTimer            => cMinRnrTimer,
         getPendingWorkReqNum      => cPendingWorkReqNum,
         getPendingRecvReqNum      => cPendingRecvReqNum,
         getPendingReadAtomicReqNum     => cPendingReadAtomicReqNum,
         getPendingDestReadAtomicReqNum => cPendingDestReadAtomicReqNum,
         getSigAll                 => cSigAll,
         getSQPN                   => cSqpn,
         getDQPN                   => cDqpn,
         getPKEY                   => cPkey,
         getQKEY                   => cQkey,
         getPMTU                   => cPmtu,
         getTypeSq                 => cTypeSq,
         getTypeRq                 => cTypeRq,
         -- contextSQ next-PSN (rq/sq: only sq uses it)
         getNPSN                   => cGetNpsn,
         setNPSNen                 => sqSetNpsnEn,
         setNPSN                   => sqSetNpsn,
         -- contextRQ RMW registers (<-> rq)
         getPermCheckReq           => cPermCheckReq,
         setPermCheckReqEn         => rqSetPermCheckReqValid,
         setPermCheckReq           => rqSetPermCheckReqData,
         getTotalDmaWriteLen       => cTotalDmaWriteLen,
         setTotalDmaWriteLenEn     => rqSetTotalDmaWriteLenValid,
         setTotalDmaWriteLen       => rqSetTotalDmaWriteLenData,
         getRemainingDmaWriteLen   => cRemainingDmaWriteLen,
         setRemainingDmaWriteLenEn => rqSetRemainingDmaWriteLenValid,
         setRemainingDmaWriteLen   => rqSetRemainingDmaWriteLenData,
         getNextDmaWriteAddr       => cNextDmaWriteAddr,
         setNextDmaWriteAddrEn     => rqSetNextDmaWriteAddrValid,
         setNextDmaWriteAddr       => rqSetNextDmaWriteAddrData,
         getSendWriteReqPktNum     => cSendWriteReqPktNum,
         setSendWriteReqPktNumEn   => rqSetSendWriteReqPktNumValid,
         setSendWriteReqPktNum     => rqSetSendWriteReqPktNumData,
         getPreReqOpCode           => cPreReqOpCode,
         setPreReqOpCodeEn         => rqSetPreReqOpCodeValid,
         setPreReqOpCode           => rqSetPreReqOpCodeData,
         getEpoch                  => cEpoch,
         incEpochEn                => rqIncEpoch,
         getMSN                    => cMsn,
         setMSNen                  => rqSetMSNValid,
         setMSN                    => rqSetMSNData,
         getIsRespPktNumZero       => cIsRespPktNumZero,
         getRespPktNum             => cRespPktNum,
         setRespPktNumEn           => rqSetRespPktNumValid,
         setRespPktNum             => rqSetRespPktNumData,
         getCurRespPSN             => cCurRespPSN,
         setCurRespPSNen           => rqSetCurRespPSNValid,
         setCurRespPSN             => rqSetCurRespPSNData,
         getEPSN                   => cEpsn,
         setEPSNen                 => rqSetEPSNValid,
         setEPSN                   => rqSetEPSNData);

   -----------------------------------------------------------------------------
   -- U_RecvReqQ : recvReqQ (surf.Fifo, FWFT) — mkSizedFIFOF(MAX_QP_WR), RecvReq.
   -- Write side = recvReqIn (toPut); read side = recvReqBufPipeOut -> rq.
   -----------------------------------------------------------------------------
   GEN_RECVREQ_Q : if EN_RX_G generate
   U_RecvReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "block",
         DATA_WIDTH_G    => RECV_REQ_C,
         ADDR_WIDTH_G    => RECV_REQ_AW_C)
      port map (
         rst           => recvReqRst,
         wr_clk        => clk,
         wr_en         => recvReqInValid,
         din           => recvReqInData,
         not_full      => recvReqInReady,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         full          => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => recvReqRdEn,
         dout          => recvReqDout,
         valid         => recvReqValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);
   end generate GEN_RECVREQ_Q;

   -----------------------------------------------------------------------------
   -- U_WorkReqQ : workReqQ (surf.Fifo, FWFT) — mkFIFOF, WorkReq.
   -- Write side = workReqIn (toPut); read side = workReqBufPipeOut -> sq.
   -----------------------------------------------------------------------------
   GEN_WORKREQ_Q : if EN_TX_G generate
   U_WorkReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => WORK_REQ_C,
         ADDR_WIDTH_G    => WORK_REQ_AW_C)
      port map (
         rst           => workReqRst,
         wr_clk        => clk,
         wr_en         => workReqInValid,
         din           => workReqInData,
         not_full      => workReqInReady,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         full          => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => workReqRdEn,
         dout          => workReqDout,
         valid         => workReqValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);
   end generate GEN_WORKREQ_Q;

   -----------------------------------------------------------------------------
   -- U_ReqPktPipe : reqPktPipe (mkRdmaPktMetaDataAndPayloadPipe)
   --   write side = reqPktPipeIn (top);  read side (pktPipeOut) -> rq.
   --   clear() = resetAndClear reqPktPipe.clear (level, isReset).
   -----------------------------------------------------------------------------
   GEN_REQPKT_PIPE : if EN_RX_G generate
   U_ReqPktPipe : entity surf.RdmaPktMetaDataAndPayloadPipe
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk            => clk,
         rst            => rst,
         clrEn_i        => reqPipeClr,
         -- write side <- reqPktPipeIn
         metaWrEn_i     => reqPktMetaWrEn,
         metaDin_i      => reqPktMetaData,
         metaRdy_o      => reqPktMetaReady,
         payloadWrEn_i  => reqPktPayloadWrEn,
         payloadDin_i   => reqPktPayloadData,
         payloadRdy_o   => reqPktPayloadReady,
         -- read side -> rq
         metaValid_o    => reqPipeMetaValid,
         metaDout_o     => reqPipeMetaData,
         metaRdEn_i     => reqPipeMetaRdEn,
         payloadValid_o => reqPipePayloadValid,
         payloadDout_o  => reqPipePayloadData,
         payloadRdEn_i  => reqPipePayloadRdEn);
   end generate GEN_REQPKT_PIPE;

   -----------------------------------------------------------------------------
   -- U_RespPktPipe : respPktPipe (mkRdmaPktMetaDataAndPayloadPipe)
   --   write side = respPktPipeIn (top);  read side (pktPipeOut) -> sq.
   -----------------------------------------------------------------------------
   GEN_RESPPKT_PIPE : if EN_TX_G generate
   U_RespPktPipe : entity surf.RdmaPktMetaDataAndPayloadPipe
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk            => clk,
         rst            => rst,
         clrEn_i        => respPipeClr,
         metaWrEn_i     => respPktMetaWrEn,
         metaDin_i      => respPktMetaData,
         metaRdy_o      => respPktMetaReady,
         payloadWrEn_i  => respPktPayloadWrEn,
         payloadDin_i   => respPktPayloadData,
         payloadRdy_o   => respPktPayloadReady,
         metaValid_o    => respPipeMetaValid,
         metaDout_o     => respPipeMetaData,
         metaRdEn_i     => respPipeMetaRdEn,
         payloadValid_o => respPipePayloadValid,
         payloadDout_o  => respPipePayloadData,
         payloadRdEn_i  => respPipePayloadRdEn);
   end generate GEN_RESPPKT_PIPE;

   -----------------------------------------------------------------------------
   -- U_DmaRdCntrlRq : dmaReadCntrl4RQ  (mkDmaReadCntrl(statusRQ, dmaReadProxy4RQ))
   --   srvPort  <- payloadGenerator4RQ ; dmaReadSrv client -> dmaReadProxy4RQ.
   -----------------------------------------------------------------------------
   GEN_DMARD_CNTRL_RQ : if EN_RX_G and EN_READ_G generate
   U_DmaRdCntrlRq : entity surf.DmaReadCntrlConAndGen
      generic map (
         TPD_G => TPD_G)
      port map (
         clk          => clk,
         rst          => rst,
         clearAll     => cIsReset,
         isSQ         => '0',               -- statusRQ.isSQ = False (no internal sink)
         cancelEn     => cancelReadRq,
         -- srvPort.request <- payloadGenerator4RQ.dmaReadCntrl.request
         reqInValid   => pgRqDmaReqValid,
         reqInData    => pgRqDmaReqData,
         reqInReady   => pgRqDmaReqReady,
         -- srvPort.response -> payloadGenerator4RQ.dmaReadCntrl.response
         respOutReady => pgRqDmaRespReady,
         respOutValid => pgRqDmaRespValid,
         respOutData  => pgRqDmaRespData,
         -- dmaReadSrv client -> dmaReadProxy4RQ.srvPort
         dmaReqValid  => drRqDmaReqValid,
         dmaReqOut    => drRqDmaReqData,
         dmaReqReady  => drRqDmaReqReady,
         dmaRespValid => drRqDmaRespValid,
         dmaRespIn    => drRqDmaRespData,
         dmaRespReady => drRqDmaRespReady,
         isIdle       => drRqIsIdle);
   end generate GEN_DMARD_CNTRL_RQ;

   -----------------------------------------------------------------------------
   -- U_DmaRdCntrlSq : dmaReadCntrl4SQ  (mkDmaReadCntrl(statusSQ, dmaReadProxy4SQ))
   -----------------------------------------------------------------------------
   GEN_DMARD_CNTRL_SQ : if EN_TX_G generate
   U_DmaRdCntrlSq : entity surf.DmaReadCntrlConAndGen
      generic map (
         TPD_G => TPD_G)
      port map (
         clk          => clk,
         rst          => rst,
         clearAll     => cIsReset,
         isSQ         => '1',               -- statusSQ.isSQ = True (no internal sink)
         cancelEn     => cancelReadSq,
         reqInValid   => pgSqDmaReqValid,
         reqInData    => pgSqDmaReqData,
         reqInReady   => pgSqDmaReqReady,
         respOutReady => pgSqDmaRespReady,
         respOutValid => pgSqDmaRespValid,
         respOutData  => pgSqDmaRespData,
         dmaReqValid  => drSqDmaReqValid,
         dmaReqOut    => drSqDmaReqData,
         dmaReqReady  => drSqDmaReqReady,
         dmaRespValid => drSqDmaRespValid,
         dmaRespIn    => drSqDmaRespData,
         dmaRespReady => drSqDmaRespReady,
         isIdle       => drSqIsIdle);
   end generate GEN_DMARD_CNTRL_SQ;

   -----------------------------------------------------------------------------
   -- U_DmaWrCntrlRq : dmaWriteCntrl4RQ (mkDmaWriteCntrl(statusRQ, dmaWriteProxy4RQ))
   --   srvPort <- rq (payloadConsumer) ; dmaWriteSrv client -> dmaWriteProxy4RQ.
   -----------------------------------------------------------------------------
   GEN_DMAWR_CNTRL_RQ : if EN_RX_G generate
   U_DmaWrCntrlRq : entity surf.DmaWriteCntrl
      generic map (
         TPD_G => TPD_G)
      port map (
         clk          => clk,
         rst          => rst,
         clearAllI    => cIsReset,
         cancelEn     => cancelWriteRq,
         reqInValid   => dwRqReqValid,
         reqInData    => dwRqReqData,
         reqInReady   => dwRqReqReady,
         respOutReady => dwRqRespReady,
         respOutValid => dwRqRespValid,
         respOutData  => dwRqRespData,
         dmaReqValid  => dwRqDmaReqValid,
         dmaReqOut    => dwRqDmaReqData,
         dmaReqReady  => dwRqDmaReqReady,
         dmaRespValid => dwRqDmaRespValid,
         dmaRespIn    => dwRqDmaRespData,
         dmaRespReady => dwRqDmaRespReady,
         isIdle       => dwRqIsIdle);
   end generate GEN_DMAWR_CNTRL_RQ;

   -----------------------------------------------------------------------------
   -- U_DmaWrCntrlSq : dmaWriteCntrl4SQ (mkDmaWriteCntrl(statusSQ, dmaWriteProxy4SQ))
   --   srvPort <- sq ; dmaWriteSrv client -> dmaWriteProxy4SQ.
   -----------------------------------------------------------------------------
   GEN_DMAWR_CNTRL_SQ : if EN_TX_G and EN_READ_G generate
   U_DmaWrCntrlSq : entity surf.DmaWriteCntrl
      generic map (
         TPD_G => TPD_G)
      port map (
         clk          => clk,
         rst          => rst,
         clearAllI    => cIsReset,
         cancelEn     => cancelWriteSq,
         reqInValid   => dwSqReqValid,
         reqInData    => dwSqReqData,
         reqInReady   => dwSqReqReady,
         respOutReady => dwSqRespReady,
         respOutValid => dwSqRespValid,
         respOutData  => dwSqRespData,
         dmaReqValid  => dwSqDmaReqValid,
         dmaReqOut    => dwSqDmaReqData,
         dmaReqReady  => dwSqDmaReqReady,
         dmaRespValid => dwSqDmaRespValid,
         dmaRespIn    => dwSqDmaRespData,
         dmaRespReady => dwSqDmaRespReady,
         isIdle       => dwSqIsIdle);
   end generate GEN_DMAWR_CNTRL_SQ;

   -----------------------------------------------------------------------------
   -- U_PayGenRq : payloadGenerator4RQ (mkPayloadGenerator(statusRQ, dmaReadCntrl4RQ))
   --   srvPort <-> rq ; dmaReadCntrl client -> U_DmaRdCntrlRq ; dataStream -> rq.
   -----------------------------------------------------------------------------
   GEN_PAYGEN_RQ : if EN_RX_G and EN_READ_G generate
   U_PayGenRq : entity surf.PayloadGeneratorConAndGen
      generic map (
         TPD_G => TPD_G)
      port map (
         clk                   => clk,
         rst                   => rst,
         isReset               => cIsReset,
         isNonErr              => cIsNonErr,
         isERR                 => cIsErr,
         -- srvPort <-> rq
         reqInValid            => pgRqReqValid,
         reqInData             => pgRqReqData,
         reqInReady            => pgRqReqReady,
         respOutReady          => pgRqRespReady,
         respOutValid          => pgRqRespValid,
         respOutData           => pgRqRespData,
         -- dmaReadCntrl client -> U_DmaRdCntrlRq.srvPort
         dmaReadCntrlReqValid  => pgRqDmaReqValid,
         dmaReadCntrlReqData   => pgRqDmaReqData,
         dmaReadCntrlReqReady  => pgRqDmaReqReady,
         dmaReadCntrlRespValid => pgRqDmaRespValid,
         dmaReadCntrlRespData  => pgRqDmaRespData,
         dmaReadCntrlRespReady => pgRqDmaRespReady,
         -- payloadDataStreamPipeOut -> rq
         payloadDataStreamDeq      => pgRqDataDeq,
         payloadDataStreamFirst    => pgRqDataData,
         payloadDataStreamNotEmpty => pgRqDataValid,
         payloadNotEmpty           => pgRqNotEmpty);
   end generate GEN_PAYGEN_RQ;

   -----------------------------------------------------------------------------
   -- U_PayGenSq : payloadGenerator4SQ (mkPayloadGenerator(statusSQ, dmaReadCntrl4SQ))
   -----------------------------------------------------------------------------
   GEN_PAYGEN_SQ : if EN_TX_G generate
   U_PayGenSq : entity surf.PayloadGeneratorConAndGen
      generic map (
         TPD_G => TPD_G)
      port map (
         clk                   => clk,
         rst                   => rst,
         isReset               => cIsReset,
         isNonErr              => cIsNonErr,
         isERR                 => cIsErr,
         reqInValid            => pgSqReqValid,
         reqInData             => pgSqReqData,
         reqInReady            => pgSqReqReady,
         respOutReady          => pgSqRespReady,
         respOutValid          => pgSqRespValid,
         respOutData           => pgSqRespData,
         dmaReadCntrlReqValid  => pgSqDmaReqValid,
         dmaReadCntrlReqData   => pgSqDmaReqData,
         dmaReadCntrlReqReady  => pgSqDmaReqReady,
         dmaReadCntrlRespValid => pgSqDmaRespValid,
         dmaReadCntrlRespData  => pgSqDmaRespData,
         dmaReadCntrlRespReady => pgSqDmaRespReady,
         payloadDataStreamDeq      => pgSqDataDeq,
         payloadDataStreamFirst    => pgSqDataData,
         payloadDataStreamNotEmpty => pgSqDataValid,
         payloadNotEmpty           => pgSqNotEmpty);
   end generate GEN_PAYGEN_SQ;

   -----------------------------------------------------------------------------
   -- U_DmaRdProxyRq : dmaReadProxy4RQ (mkServerProxy) — srvPort <- U_DmaRdCntrlRq,
   --   cltPort -> dmaReadClt4RQ (top).
   -----------------------------------------------------------------------------
   GEN_DMARD_PROXY_RQ : if EN_RX_G and EN_READ_G generate
   U_DmaRdProxyRq : entity surf.ServerProxy
      generic map (
         TPD_G        => TPD_G,
         REQ_WIDTH_G  => DMA_READ_REQ_C,
         RESP_WIDTH_G => DMA_READ_RESP_C)
      port map (
         clk          => clk,
         rst          => rst,
         -- srvPort <- dmaReadCntrl4RQ client
         srvReqValid  => drRqDmaReqValid,
         srvReqData   => drRqDmaReqData,
         srvReqReady  => drRqDmaReqReady,
         srvRespValid => drRqDmaRespValid,
         srvRespData  => drRqDmaRespData,
         srvRespReady => drRqDmaRespReady,
         -- cltPort -> top dmaReadClt4RQ
         cltReqValid  => dmaReadClt4RqReqValid,
         cltReqData   => dmaReadClt4RqReqData,
         cltReqReady  => dmaReadClt4RqReqReady,
         cltRespValid => dmaReadClt4RqRespValid,
         cltRespData  => dmaReadClt4RqRespData,
         cltRespReady => dmaReadClt4RqRespReady);
   end generate GEN_DMARD_PROXY_RQ;

   -----------------------------------------------------------------------------
   -- U_DmaRdProxySq : dmaReadProxy4SQ
   -----------------------------------------------------------------------------
   GEN_DMARD_PROXY_SQ : if EN_TX_G generate
   U_DmaRdProxySq : entity surf.ServerProxy
      generic map (
         TPD_G        => TPD_G,
         REQ_WIDTH_G  => DMA_READ_REQ_C,
         RESP_WIDTH_G => DMA_READ_RESP_C)
      port map (
         clk          => clk,
         rst          => rst,
         srvReqValid  => drSqDmaReqValid,
         srvReqData   => drSqDmaReqData,
         srvReqReady  => drSqDmaReqReady,
         srvRespValid => drSqDmaRespValid,
         srvRespData  => drSqDmaRespData,
         srvRespReady => drSqDmaRespReady,
         cltReqValid  => dmaReadClt4SqReqValid,
         cltReqData   => dmaReadClt4SqReqData,
         cltReqReady  => dmaReadClt4SqReqReady,
         cltRespValid => dmaReadClt4SqRespValid,
         cltRespData  => dmaReadClt4SqRespData,
         cltRespReady => dmaReadClt4SqRespReady);
   end generate GEN_DMARD_PROXY_SQ;

   -----------------------------------------------------------------------------
   -- U_DmaWrProxyRq : dmaWriteProxy4RQ
   -----------------------------------------------------------------------------
   GEN_DMAWR_PROXY_RQ : if EN_RX_G generate
   U_DmaWrProxyRq : entity surf.ServerProxy
      generic map (
         TPD_G        => TPD_G,
         REQ_WIDTH_G  => DMA_WRITE_REQ_C,
         RESP_WIDTH_G => DMA_WRITE_RESP_C)
      port map (
         clk          => clk,
         rst          => rst,
         srvReqValid  => dwRqDmaReqValid,
         srvReqData   => dwRqDmaReqData,
         srvReqReady  => dwRqDmaReqReady,
         srvRespValid => dwRqDmaRespValid,
         srvRespData  => dwRqDmaRespData,
         srvRespReady => dwRqDmaRespReady,
         cltReqValid  => dmaWriteClt4RqReqValid,
         cltReqData   => dmaWriteClt4RqReqData,
         cltReqReady  => dmaWriteClt4RqReqReady,
         cltRespValid => dmaWriteClt4RqRespValid,
         cltRespData  => dmaWriteClt4RqRespData,
         cltRespReady => dmaWriteClt4RqRespReady);
   end generate GEN_DMAWR_PROXY_RQ;

   -----------------------------------------------------------------------------
   -- U_DmaWrProxySq : dmaWriteProxy4SQ
   -----------------------------------------------------------------------------
   GEN_DMAWR_PROXY_SQ : if EN_TX_G and EN_READ_G generate
   U_DmaWrProxySq : entity surf.ServerProxy
      generic map (
         TPD_G        => TPD_G,
         REQ_WIDTH_G  => DMA_WRITE_REQ_C,
         RESP_WIDTH_G => DMA_WRITE_RESP_C)
      port map (
         clk          => clk,
         rst          => rst,
         srvReqValid  => dwSqDmaReqValid,
         srvReqData   => dwSqDmaReqData,
         srvReqReady  => dwSqDmaReqReady,
         srvRespValid => dwSqDmaRespValid,
         srvRespData  => dwSqDmaRespData,
         srvRespReady => dwSqDmaRespReady,
         cltReqValid  => dmaWriteClt4SqReqValid,
         cltReqData   => dmaWriteClt4SqReqData,
         cltReqReady  => dmaWriteClt4SqReqReady,
         cltRespValid => dmaWriteClt4SqRespValid,
         cltRespData  => dmaWriteClt4SqRespData,
         cltRespReady => dmaWriteClt4SqRespReady);
   end generate GEN_DMAWR_PROXY_SQ;

   -----------------------------------------------------------------------------
   -- U_PermProxyRq : permCheckProxy4RQ (mkServerProxy) — srvPort <- rq,
   --   cltPort -> permCheckClt4RQ (top).
   -----------------------------------------------------------------------------
   GEN_PERM_PROXY_RQ : if EN_RX_G generate
   U_PermProxyRq : entity surf.ServerProxy
      generic map (
         TPD_G        => TPD_G,
         REQ_WIDTH_G  => PERM_CHECK_REQ_C,
         RESP_WIDTH_G => 1)
      port map (
         clk             => clk,
         rst             => rst,
         srvReqValid     => rqPermReqValid,
         srvReqData      => rqPermReqData,
         srvReqReady     => rqPermReqReady,
         srvRespValid    => rqPermRespValid,
         srvRespData(0)  => rqPermRespData,
         srvRespReady    => rqPermRespReady,
         cltReqValid     => permCheckClt4RqReqValid,
         cltReqData      => permCheckClt4RqReqData,
         cltReqReady     => permCheckClt4RqReqReady,
         cltRespValid    => permCheckClt4RqRespValid,
         cltRespData(0)  => permCheckClt4RqRespData,
         cltRespReady    => permCheckClt4RqRespReady);
   end generate GEN_PERM_PROXY_RQ;

   -----------------------------------------------------------------------------
   -- U_PermProxySq : permCheckProxy4SQ — srvPort <- sq, cltPort -> permCheckClt4SQ.
   -----------------------------------------------------------------------------
   GEN_PERM_PROXY_SQ : if EN_TX_G and EN_READ_G generate
   U_PermProxySq : entity surf.ServerProxy
      generic map (
         TPD_G        => TPD_G,
         REQ_WIDTH_G  => PERM_CHECK_REQ_C,
         RESP_WIDTH_G => 1)
      port map (
         clk             => clk,
         rst             => rst,
         srvReqValid     => sqPermReqValid,
         srvReqData      => sqPermReqData,
         srvReqReady     => sqPermReqReady,
         srvRespValid    => sqPermRespValid,
         srvRespData(0)  => sqPermRespData,
         srvRespReady    => sqPermRespReady,
         cltReqValid     => permCheckClt4SqReqValid,
         cltReqData      => permCheckClt4SqReqData,
         cltReqReady     => permCheckClt4SqReqReady,
         cltRespValid    => permCheckClt4SqRespValid,
         cltRespData(0)  => permCheckClt4SqRespData,
         cltRespReady    => permCheckClt4SqRespReady);
   end generate GEN_PERM_PROXY_SQ;

   -----------------------------------------------------------------------------
   -- U_Rq : rq (mkRQ(contextRQ, payloadGenerator4RQ, dmaWriteCntrl4RQ,
   --   permCheckProxy4RQ.srvPort, recvReqBufPipeOut, reqPktPipe.pktPipeOut))
   -----------------------------------------------------------------------------
   GEN_RQ : if EN_RX_G generate
   U_Rq : entity surf.Rq
      generic map (
         TPD_G       => TPD_G,
         EN_READ_G   => EN_READ_G,
         MAX_QP_WR_G => MAX_QP_WR_G)
      port map (
         clk => clk,
         rst => rst,
         -- contextRQ.statusRQ.comm status
         isReset                        => cIsReset,
         isNonErr                       => cIsNonErr,
         isERR                          => cIsErr,
         getTypeQP                      => cTypeRq,
         getPMTU                        => cPmtu,
         getPKEY                        => cPkey,
         getSQPN                        => cSqpn,
         getDQPN                        => cDqpn,
         getMinRnrTimer                 => cMinRnrTimer,
         getAccessFlags                 => cAccessFlags,
         getPendingWorkReqNum           => cPendingWorkReqNum,
         getPendingDestReadAtomicReqNum => cPendingDestReadAtomicReqNum,
         -- contextRQ shared registers (external RMW)
         getEpoch             => cEpoch,
         incEpoch             => rqIncEpoch,
         getEPSN              => cEpsn,
         getRespPktNum        => cRespPktNum,
         setRespPktNumValid   => rqSetRespPktNumValid,
         setRespPktNumData    => rqSetRespPktNumData,
         getIsRespPktNumZero  => cIsRespPktNumZero,
         setEPSNValid         => rqSetEPSNValid,
         setEPSNData          => rqSetEPSNData,
         getPreReqOpCode      => cPreReqOpCode,
         setPreReqOpCodeValid => rqSetPreReqOpCodeValid,
         setPreReqOpCodeData  => rqSetPreReqOpCodeData,
         restoreValid         => rqRestoreValid,
         restorePreOpCodeData => rqRestorePreOpCodeData,
         restorePsnData       => rqRestorePsnData,
         getPermCheckReq      => cPermCheckReq,
         setPermCheckReqValid => rqSetPermCheckReqValid,
         setPermCheckReqData  => rqSetPermCheckReqData,
         getNextDmaWriteAddr        => cNextDmaWriteAddr,
         setNextDmaWriteAddrValid   => rqSetNextDmaWriteAddrValid,
         setNextDmaWriteAddrData    => rqSetNextDmaWriteAddrData,
         getSendWriteReqPktNum      => cSendWriteReqPktNum,
         setSendWriteReqPktNumValid => rqSetSendWriteReqPktNumValid,
         setSendWriteReqPktNumData  => rqSetSendWriteReqPktNumData,
         getRemainingDmaWriteLen      => cRemainingDmaWriteLen,
         setRemainingDmaWriteLenValid => rqSetRemainingDmaWriteLenValid,
         setRemainingDmaWriteLenData  => rqSetRemainingDmaWriteLenData,
         getTotalDmaWriteLen        => cTotalDmaWriteLen,
         setTotalDmaWriteLenValid   => rqSetTotalDmaWriteLenValid,
         setTotalDmaWriteLenData    => rqSetTotalDmaWriteLenData,
         getCurRespPSN        => cCurRespPSN,
         setCurRespPSNValid   => rqSetCurRespPSNValid,
         setCurRespPSNData    => rqSetCurRespPSNData,
         getMSN               => cMsn,
         setMSNValid          => rqSetMSNValid,
         setMSNData           => rqSetMSNData,
         -- payloadGenerator (payloadGenerator4RQ) server + data stream
         payloadGenReqValid     => pgRqReqValid,
         payloadGenReqData      => pgRqReqData,
         payloadGenReqReady     => pgRqReqReady,
         payloadGenRespValid    => pgRqRespValid,
         payloadGenRespData     => pgRqRespData,
         payloadGenRespGetEn    => pgRqRespReady,
         payloadDataStreamValid => pgRqDataValid,
         payloadDataStreamData  => pgRqDataData,
         payloadDataStreamRdEn  => pgRqDataDeq,
         -- permCheckSrv (permCheckProxy4RQ.srvPort)
         permReqValid  => rqPermReqValid,
         permReqData   => rqPermReqData,
         permReqReady  => rqPermReqReady,
         permRespValid => rqPermRespValid,
         permRespData  => rqPermRespData,
         permRespGetEn => rqPermRespReady,
         -- recvReqBuf (recvReqQ pipe out)
         recvReqValid => recvReqValid,
         recvReqData  => recvReqDout,
         recvReqDeq   => recvReqRdEn,
         -- reqPktPipeIn.pktMetaData
         pktMetaValid => reqPipeMetaValid,
         pktMetaData  => reqPipeMetaData,
         pktMetaDeq   => reqPipeMetaRdEn,
         -- reqPktPipeIn.payload
         payloadPipeInValid => reqPipePayloadValid,
         payloadPipeInData  => reqPipePayloadData,
         payloadPipeInReady => reqPipePayloadRdEn,
         -- dmaWriteCntrl (dmaWriteCntrl4RQ) client
         dmaWriteReqValid  => dwRqReqValid,
         dmaWriteReqData   => dwRqReqData,
         dmaWriteReqReady  => dwRqReqReady,
         dmaWriteRespValid => dwRqRespValid,
         dmaWriteRespData  => dwRqRespData,
         dmaWriteRespReady => dwRqRespReady,
         -- forwarded outputs
         rdmaRespDataStreamValid => rdmaRespValid,
         rdmaRespDataStreamData  => rdmaRespData,
         rdmaRespDataStreamRdEn  => rdmaRespRdEn,
         respHeaderOutNotEmpty   => rqRespHeaderNotEmpty,
         workCompValid  => workCompRqValid,
         workCompData   => workCompRqData,
         workCompRdEn   => workCompRqRdEn,
         workCompHasErr => rqWorkCompHasErr);
   end generate GEN_RQ;

   -----------------------------------------------------------------------------
   -- U_Sq : sq (mkSQ(contextSQ, payloadGenerator4SQ, dmaWriteCntrl4SQ,
   --   permCheckProxy4SQ.srvPort, workReqBufPipeOut, respPktPipe.pktPipeOut))
   -----------------------------------------------------------------------------
   GEN_SQ : if EN_TX_G generate
   U_Sq : entity surf.SqQueuePair
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         EN_READ_G      => EN_READ_G,
         MAX_QP_WR_G    => MAX_QP_WR_G)
      port map (
         clk => clk,
         rst => rst,
         -- contextSQ.statusSQ status bundle
         isReset              => cIsReset,
         isNonErr             => cIsNonErr,
         isStableRTS          => cIsStableRts,
         isRTS                => cIsRts,
         isERR                => cIsErr,
         isSQD                => cIsSqd,
         isRTR2RTS            => cIsRtr2Rts,
         qpType               => cTypeSq,
         sqpn                 => cSqpn,
         pmtu                 => cPmtu,
         pkey                 => cPkey,
         dqpn                 => cDqpn,
         sigAll               => cSigAll,
         getMaxRetryCnt       => cMaxRetryCnt,
         getMaxRnrCnt         => cMaxRnrCnt,
         getMaxTimeOut        => cMaxTimeOut,
         getMinRnrTimer       => cMinRnrTimer,
         getPendingWorkReqNum => cPendingWorkReqNum,
         -- contextSQ next-PSN register (RMW -> cntrl)
         npsnIn   => cGetNpsn,
         npsnOut  => sqSetNpsn,
         npsnWrEn => sqSetNpsnEn,
         -- payloadGenerator (payloadGenerator4SQ) server + data stream
         payloadGenReqValid  => pgSqReqValid,
         payloadGenReqData   => pgSqReqData,
         payloadGenReqReady  => pgSqReqReady,
         payloadGenRespValid => pgSqRespValid,
         payloadGenRespData  => pgSqRespData,
         payloadGenRespReady => pgSqRespReady,
         payloadGenDataValid => pgSqDataValid,
         payloadGenDataData  => pgSqDataData,
         payloadGenDataRdEn  => pgSqDataDeq,
         -- dmaWriteCntrl (dmaWriteCntrl4SQ) client
         dmaWriteReqValid  => dwSqReqValid,
         dmaWriteReqData   => dwSqReqData,
         dmaWriteReqReady  => dwSqReqReady,
         dmaWriteRespValid => dwSqRespValid,
         dmaWriteRespData  => dwSqRespData,
         dmaWriteRespReady => dwSqRespReady,
         -- permCheckSrv (permCheckProxy4SQ.srvPort)
         permReqValid  => sqPermReqValid,
         permReqData   => sqPermReqData,
         permReqReady  => sqPermReqReady,
         permRespValid => sqPermRespValid,
         permRespData  => sqPermRespData,
         permRespGetEn => sqPermRespReady,
         -- workReqPipeIn (workReqQ pipe out)
         workReqInValid => workReqValid,
         workReqInData  => workReqDout,
         workReqInRdEn  => workReqRdEn,
         -- respPktPipeOut (respPktPipe.pktPipeOut)
         respPayloadValid => respPipePayloadValid,
         respPayloadData  => respPipePayloadData,
         respPayloadRdEn  => respPipePayloadRdEn,
         respPktMetaValid => respPipeMetaValid,
         respPktMetaData  => respPipeMetaData,
         respPktMetaRdEn  => respPipeMetaRdEn,
         -- SQ interface outputs
         rdmaReqDataValid       => rdmaReqValid,
         rdmaReqDataData        => rdmaReqData,
         rdmaReqDataRdEn        => rdmaReqRdEn,
         workCompValid          => workCompSqValid,
         workCompData           => workCompSqData,
         workCompRdEn           => workCompSqRdEn,
         workCompHasErr         => sqWorkCompHasErr,
         reqHeaderOutNotEmpty   => sqReqHeaderNotEmpty,
         pendingWorkReqNotEmpty => sqPendingNotEmpty);
   end generate GEN_SQ;

end architecture rtl;
