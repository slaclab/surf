-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   The RQ request-handling datapath: a 32-stage linear pipeline of SURF FIFOs
--   (supportedReqOpCodeCheckQ -> ... -> pendingRespQ -> {respHeaderOutQ,
--   psnRespOutQ, workCompReqQ} -> workCompGenReqOutQ) wrapped by five control
--   machines that thread registers across the pipeline (⚑S3 OQ-PART-01 RESOLVED:
--   KEEP FUSED — the error/retry control plane defeats the FIFO-boundary cut).
--
--   The five control sub-FSMs (RegType blocks A–E):
--     A  pre-stage FSM       : preStageState (build -> calc -> done) meters one
--                              packet at a time into the pipeline.
--     B  retry FSM           : retryState + retryStart CReg(2) + RNR-wait counter.
--     C  error/flush mode    : hasReqStatusErr/hasDmaReadRespErr/hasErrRespGen ->
--                              hasErrHappened/inErrorState; errFlush rules.
--     D  response-packet loop: isFirstOrOnlyRespPkt inside countPendingResp.
--     E  coalesce counter    : coalesceWorkReqCnt + isCoalesceWorkReqCntZero.
--
--   CReg(2) intra-cycle forward (OQ-FSM-RHR-02): retryStartReg port-0 write in
--   triggerRNR (stage 4) is visible to the port-1 read in retryStart (retry FSM)
--   the SAME cycle. Enforced by comb ordering: the pipeline block (incl. stage 4)
--   runs BEFORE the retry-rule block, so retryStart reads v.retryStart* (already
--   written by triggerRNR) not r.retryStart*.
--
--   contextRQ shared registers (OQ-FSM-RHR-01) are external port pairs, NOT local
--   state: getEpoch/incEpoch, getEPSN, getRespPktNum/setRespPktNum, getIsRespPktNumZero.
--
--   Child instances (NOT SURF, NOT state):
--     U_PendingDestReadAtomicReqCnt : CountCF   (RQ-02, full incrQ/decrQ/cntReg)
--     U_AtomicSrv                   : AtomicSrvConAndGen (RQ-06 STUB — genResp sets
--                                     original := compData; CAS/FetchAdd NOT implemented)
--     U_RdmaRespPipeOut             : CombineHeaderAndPayload (drives rdmaRespDataStreamPipeOut)
--
--   FIFO clear: BSV FIFOF.clear under resetAndClear -> fifoClr = rst or isReset,
--   asserted to every Fifo rst (level-safe sync clear; OQ-FSM-01 carry-forward).
--
--   *** STAGED EMIT — PHASE 2 DONE (front end + perm-check build/query stages 5-8) ***
--   Phase 0 emitted the full compilable STRUCTURE (entity, 35 surf.Fifo, 3 children,
--   RegType/REG_INIT_C, control-FSM scaffolding + per-stage handshake/back-pressure).
--   PHASE 1 fills the error-free request-classification front end:
--     pre-stage A (preBuildReqInfo/preCalcReqInfo/checkEPSN): BTH/RETH parse,
--       opcode classify, truncateLenByPMTU, access check, ePSN check + setEPSN;
--     stages 1-4 (checkSupportedReqOpCode/checkNormalReqOpCodeSeq/checkRNR/triggerRNR):
--       opcode-support, opcode-seq (setPreReqOpCode), RNR + recvReqBuf + restore,
--       retry trigger (retryStartReg CReg port-0 write + incEpoch + minRnrTimer);
--     retry FSM downstream rules (retryStart/RnrRetryFlush/RnrWait/retryDone) +
--       getRnrTimeOutValue LUT.  Added contextRQ ports: setEPSN, getPreReqOpCode,
--       setPreReqOpCode, restorePreReqOpCodeAndEPSN (OQ-FSM-RHR-01 external RMW).
--   PHASE 2 fills the permission-check build/query chain:
--     stage 5 checkQpAccPermAndReadAtomicReqNum (CountCF incrOne + read/atomic
--       over-limit -> InvReqStatus); stage 6a buildPermCheckReq4SendWrite and
--       6b buildPermCheckReq4ReadAtomic (PermCheckReq construction from RecvReq/
--       RETH/AtomicEth, ERR_FLUSH_RR override, multi-pkt setPermCheckReq/getPermCheckReq
--       carry); stage 7 queryPerm4NormalReq (conditional permCheckSrv.request.put +
--       expectPermCheckResp); stage 8 checkPerm4NormalReq (conditional response.get,
--       atomic-addr alignment, RMT_ACC on failure).  Added contextRQ ports:
--       getPermCheckReq/setPermCheckReq (OQ-FSM-RHR-01 external RMW).
--   Stages 9-31 datapath remains `-- TODO(phase N): <rule@line>` (phases 3-9); those
--   output FIFOs still carry-through/zero their din. Do NOT trust full functional
--   behaviour until phases 2-9 are complete and Stage-5 verified. See the plan file
--   and ReqHandleRq.tb-spec.md §9.
--
--   Type widths (BSV deriving(Bits), first-field-at-MSB; traced from DataTypes.bsv/
--   Headers.bsv/ReqHandleRQ.bsv): leaf PSN/QPN/MSN=24, ADDR/Long/WorkReqID=64,
--   Length/RKEY/LKEY/IMM=32, PKEY=16, PktLen=13, PktFragNum=8, PktNum=25, RnrTimer=5,
--   Epoch=1, RdmaOpCode/WorkCompStatus=5, HandlerPD=32, IndexMR=7, BTH=96, AETH=32,
--   RETH=128, AtomicEth=224, AtomicAckEth=64, HeaderRDMA=593, RdmaPktMetaData=649,
--   PermCheckReq=267, DataStream=290. Enums RdmaReqStatus=4, RetryStateRQ=3,
--   PreStageStateRQ=2, DupReadReqStartState=1, TypeQP=4, DmaReqSrcType=4.
--   Structs RdmaReqPktInfo=161, RespPktGenInfo=73, RespPktSeqInfo=2,
--   RespPktHeaderInfo=50, ReqLenCheckResult=130, EnoughDmaSpaceCheck=4,
--   WorkCompGenReqRQ=198, Maybe#RecvReq=217, Maybe#HeaderRDMA=594, RecvReq=216,
--   ReadCacheItem=176, AtomicCacheItem=317, PayloadGenReq=199, PayloadGenResp=2,
--   PayloadConReq=203, AtomicOpReq=245, AtomicOpResp=116,
--   Maybe#Tuple3(ReadCacheItem,ADDR,DupReadReqStartState)=242, Maybe#AtomicCacheItem=318.
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

entity ReqHandleRq is
   generic (
      TPD_G     : time    := 1 ns;
      -- false = no RDMA READ/atomic serving: read/atomic-request classifiers
      -- are forced false, so incoming READ/CMP_SWP/FETCH_ADD requests take the
      -- existing unsupported-opcode NAK-INV_REQ path and the read/atomic
      -- serving datapath (dup cache, payload gen, atomic srv) constant-folds.
      EN_READ_G : boolean := true;
      -- Settings.bsv MAX_QP_WR (BSV default 32); must match CntrlQp MAX_QP_WR_G
      MAX_QP_WR_G : positive := 4);
   port (
      clk : in sl;
      rst : in sl;                                        -- active-high synchronous reset
      -----------------------------------------------------------------------
      -- contextRQ.statusRQ.comm status methods (combinational inputs)
      -----------------------------------------------------------------------
      isReset                        : in  sl;            -- comm.isReset -> resetAndClear
      isNonErr                       : in  sl;            -- comm.isNonErr
      isERR                          : in  sl;            -- comm.isERR
      getTypeQP                      : in  slv(3 downto 0);   -- TypeQP enum
      getPMTU                        : in  slv(2 downto 0);   -- PMTU enum (256="001"..4096="101")
      getPKEY                        : in  slv(15 downto 0);
      getSQPN                        : in  slv(23 downto 0);
      getDQPN                        : in  slv(23 downto 0);
      getMinRnrTimer                 : in  slv(4 downto 0);   -- RnrTimer
      getAccessFlags                 : in  slv(7 downto 0);   -- FlagsType#(MemAccessTypeFlag)
      getPendingWorkReqNum           : in  slv(7 downto 0);   -- PendingReqCnt
      getPendingDestReadAtomicReqNum : in  slv(7 downto 0);   -- PendingReqCnt
      -----------------------------------------------------------------------
      -- contextRQ shared registers (OQ-FSM-RHR-01; external RMW, NOT local state)
      -----------------------------------------------------------------------
      getEpoch           : in  sl;                        -- Epoch (1b)
      incEpoch           : out sl;                        -- pulse: contextRQ.incEpoch
      getEPSN            : in  slv(23 downto 0);           -- expected PSN
      getRespPktNum      : in  slv(24 downto 0);           -- PktNum
      setRespPktNumValid : out sl;                         -- setRespPktNum write-enable
      setRespPktNumData  : out slv(24 downto 0);
      getIsRespPktNumZero : in sl;
      -- expected-PSN write-back (contextRQ.setEPSN; checkEPSN advances ePSN)
      setEPSNValid       : out sl;                         -- setEPSN write-enable
      setEPSNData        : out slv(23 downto 0);           -- PSN
      -- previous request opcode (contextRQ.getPreReqOpCode / setPreReqOpCode; RdmaOpCode 5b)
      getPreReqOpCode      : in  slv(4 downto 0);
      setPreReqOpCodeValid : out sl;                       -- setPreReqOpCode write-enable
      setPreReqOpCodeData  : out slv(4 downto 0);
      -- combined restore (contextRQ.restorePreReqOpCodeAndEPSN; checkRNR RNR path)
      restoreValid         : out sl;                       -- restorePreReqOpCodeAndEPSN write-enable
      restorePreOpCodeData : out slv(4 downto 0);          -- RdmaOpCode
      restorePsnData       : out slv(23 downto 0);         -- PSN
      -- multi-packet perm-check carry (contextRQ.getPermCheckReq / setPermCheckReq; PermCheckReq 267b)
      getPermCheckReq      : in  slv(266 downto 0);
      setPermCheckReqValid : out sl;                       -- setPermCheckReq write-enable
      setPermCheckReqData  : out slv(266 downto 0);
      -- DMA-write context registers (Phase 4; contextRQ get/set per multi-packet send/write)
      getNextDmaWriteAddr        : in  slv(63 downto 0);   -- ADDR
      setNextDmaWriteAddrValid   : out sl;                 -- setNextDmaWriteAddr write-enable
      setNextDmaWriteAddrData    : out slv(63 downto 0);
      getSendWriteReqPktNum      : in  slv(24 downto 0);   -- PktNum
      setSendWriteReqPktNumValid : out sl;                 -- setSendWriteReqPktNum write-enable
      setSendWriteReqPktNumData  : out slv(24 downto 0);
      getRemainingDmaWriteLen      : in  slv(31 downto 0); -- Length
      setRemainingDmaWriteLenValid : out sl;               -- setRemainingDmaWriteLen write-enable
      setRemainingDmaWriteLenData  : out slv(31 downto 0);
      getTotalDmaWriteLen        : in  slv(31 downto 0);   -- Length
      setTotalDmaWriteLenValid   : out sl;                 -- setTotalDmaWriteLen write-enable
      setTotalDmaWriteLenData    : out slv(31 downto 0);
      -- response PSN/MSN context registers (Phase 7; stage 23 updateRespPsnAndMsn)
      getCurRespPSN        : in  slv(23 downto 0);         -- PSN (current response PSN)
      setCurRespPSNValid   : out sl;                       -- setCurRespPSN write-enable
      setCurRespPSNData    : out slv(23 downto 0);
      getMSN               : in  slv(23 downto 0);         -- MSN
      setMSNValid          : out sl;                       -- setMSN write-enable
      setMSNData           : out slv(23 downto 0);
      -----------------------------------------------------------------------
      -- pktMetaDataPipeIn : PipeOut#(RdmaPktMetaData) (649b)
      -----------------------------------------------------------------------
      pktMetaValid : in  sl;                              -- .notEmpty
      pktMetaData  : in  slv(648 downto 0);               -- .first
      pktMetaDeq   : out sl;                              -- .deq
      -----------------------------------------------------------------------
      -- recvReqBuf : RecvReqBuf (RecvReq 216b) — .first/.deq/.notEmpty
      -----------------------------------------------------------------------
      recvReqValid : in  sl;
      recvReqData  : in  slv(215 downto 0);
      recvReqDeq   : out sl;
      -----------------------------------------------------------------------
      -- payloadConReqPort : Put#(PayloadConReq) (203b)
      -----------------------------------------------------------------------
      payloadConReqValid : out sl;
      payloadConReqData  : out slv(202 downto 0);
      payloadConReqReady : in  sl;
      -----------------------------------------------------------------------
      -- permCheckSrv : Server#(PermCheckReq (267b), Bool)
      -----------------------------------------------------------------------
      permReqValid  : out sl;
      permReqData   : out slv(266 downto 0);
      permReqReady  : in  sl;
      permRespValid : in  sl;
      permRespData  : in  sl;                             -- mrCheckResult
      permRespGetEn : out sl;
      -----------------------------------------------------------------------
      -- payloadGenerator : Server#(PayloadGenReq (199b), PayloadGenResp (2b))
      --                    + payloadDataStreamPipeOut : DataStream (290b)
      -----------------------------------------------------------------------
      payloadGenReqValid     : out sl;
      payloadGenReqData      : out slv(198 downto 0);
      payloadGenReqReady     : in  sl;
      payloadGenRespValid    : in  sl;
      payloadGenRespData     : in  slv(1 downto 0);
      payloadGenRespGetEn    : out sl;
      payloadDataStreamValid : in  sl;
      payloadDataStreamData  : in  slv(289 downto 0);
      payloadDataStreamRdEn  : out sl;
      -----------------------------------------------------------------------
      -- dupReadAtomicCache : DupReadAtomicCache
      -----------------------------------------------------------------------
      insertReadValid      : out sl;                      -- insertRead(ReadCacheItem 176b)
      insertReadData       : out slv(175 downto 0);
      insertReadReady      : in  sl;
      searchReadReqValid   : out sl;                      -- searchReadReq(ReadCacheItem 176b)
      searchReadReqData    : out slv(175 downto 0);
      searchReadReqReady   : in  sl;
      searchReadRespValid  : in  sl;                      -- searchReadResp Maybe#Tuple3 (242b)
      searchReadRespData   : in  slv(241 downto 0);
      searchReadRespGetEn  : out sl;
      insertAtomicValid    : out sl;                      -- insertAtomic(AtomicCacheItem 317b)
      insertAtomicData     : out slv(316 downto 0);
      insertAtomicReady    : in  sl;
      searchAtomicReqValid : out sl;                      -- searchAtomicReq(AtomicCacheItem 317b)
      searchAtomicReqData  : out slv(316 downto 0);
      searchAtomicReqReady : in  sl;
      searchAtomicRespValid : in sl;                      -- searchAtomicResp Maybe#AtomicCacheItem (318b)
      searchAtomicRespData  : in slv(317 downto 0);
      searchAtomicRespGetEn : out sl;
      dupCacheClear         : out sl;                     -- clear() pulse (from isReset)
      -----------------------------------------------------------------------
      -- Outputs
      -----------------------------------------------------------------------
      -- rdmaRespDataStreamPipeOut : DataStreamPipeOut (290b) — from U_RdmaRespPipeOut
      rdmaRespDataStreamValid : out sl;
      rdmaRespDataStreamData  : out slv(289 downto 0);
      rdmaRespDataStreamRdEn  : in  sl;
      -- workCompGenReqPipeOut : PipeOut#(WorkCompGenReqRQ) (198b)
      workCompGenReqValid : out sl;
      workCompGenReqData  : out slv(197 downto 0);
      workCompGenReqRdEn  : in  sl;                       -- downstream .deq
      -- respHeaderOutNotEmpty() = psnRespOutQ.notEmpty (combinational Mealy method)
      respHeaderOutNotEmpty : out sl);
end entity ReqHandleRq;

architecture rtl of ReqHandleRq is

   ---------------------------------------------------------------------------
   -- Control-FSM state enums
   ---------------------------------------------------------------------------
   -- Block A — PreStageStateRQ (BSV 4-member enum; RQ_PRE_RETRY_FLUSH unused in rules)
   type PreStageStateType is (
      RQ_PRE_BUILD_STAGE_S,
      RQ_PRE_CALC_STAGE_S,
      RQ_PRE_STAGE_DONE_S,
      RQ_PRE_RETRY_FLUSH_S);
   -- Block B — RetryStateRQ
   type RetryStateType is (
      RQ_SEQ_RETRY_FLUSH_S,
      RQ_RNR_RETRY_FLUSH_S,
      RQ_RNR_WAIT_S,
      RQ_RNR_WAIT_DONE_S,
      RQ_NOT_RETRY_S);

   ---------------------------------------------------------------------------
   -- RegType : ONE fused record; sub-FSM blocks A–E delimited below.
   ---------------------------------------------------------------------------
   type RegType is record
      -- (A) pre-stage control FSM + its mkRegU latch registers
      preStageState             : PreStageStateType;
      preStagePktMetaData       : slv(648 downto 0);   -- mkRegU
      preStageReqStatus         : slv(3 downto 0);     -- mkRegU (RdmaReqStatus)
      preStageReqPktInfo        : slv(160 downto 0);   -- mkRegU (RdmaReqPktInfo)
      preStageIsZeroPmtuResidue : sl;                  -- mkRegU
      -- (B) retry FSM
      retryState       : RetryStateType;
      retryStartValid  : sl;                           -- mkCReg(2) Maybe tag
      retryStartState  : RetryStateType;               -- mkCReg(2) Maybe value
      rnrWaitCnt       : slv(28 downto 0);             -- mkRegU (RNR_WAIT_CYCLE_CNT_WIDTH=29)
      minRnrTimer      : slv(4 downto 0);              -- mkRegU (RnrTimer)
      isRnrWaitCntZero : sl;                           -- mkRegU
      -- (C) error/flush mode flags (all mkReg False)
      hasReqStatusErr   : sl;
      hasDmaReadRespErr : sl;
      hasErrRespGen     : sl;
      -- (D) response-packet loop
      isFirstOrOnlyRespPkt : sl;                       -- mkReg True
      -- (E) coalesce counter
      coalesceWorkReqCnt     : slv(7 downto 0);        -- mkCount(MAX_QP_WR-1)
      isCoalesceWorkReqCntZero : sl;
   end record RegType;

   constant COALESCE_INIT_C : slv(7 downto 0) := std_logic_vector(to_unsigned(MAX_QP_WR_G-1, 8));  -- MAX_QP_WR-1

   constant REG_INIT_C : RegType := (
      preStageState             => RQ_PRE_BUILD_STAGE_S,
      preStagePktMetaData       => (others => '0'),
      preStageReqStatus         => (others => '0'),
      preStageReqPktInfo        => (others => '0'),
      preStageIsZeroPmtuResidue => '0',
      retryState                => RQ_NOT_RETRY_S,
      retryStartValid           => '0',
      retryStartState           => RQ_NOT_RETRY_S,
      rnrWaitCnt                => (others => '0'),
      minRnrTimer               => (others => '0'),
      isRnrWaitCntZero          => '0',
      hasReqStatusErr           => '0',
      hasDmaReadRespErr         => '0',
      hasErrRespGen             => '0',
      isFirstOrOnlyRespPkt      => '1',
      coalesceWorkReqCnt        => COALESCE_INIT_C,
      isCoalesceWorkReqCntZero  => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   ---------------------------------------------------------------------------
   -- Enum encodings (constants)
   ---------------------------------------------------------------------------
   -- RdmaReqStatus (4b)
   constant ST_NORMAL_C       : slv(3 downto 0) := x"0";
   constant ST_SEQ_ERR_C      : slv(3 downto 0) := x"1";
   constant ST_RNR_C          : slv(3 downto 0) := x"2";
   constant ST_INV_REQ_C      : slv(3 downto 0) := x"3";
   constant ST_INV_RD_C       : slv(3 downto 0) := x"4";
   constant ST_RMT_ACC_C      : slv(3 downto 0) := x"5";
   constant ST_RMT_OP_C       : slv(3 downto 0) := x"6";
   constant ST_DUP_C          : slv(3 downto 0) := x"7";
   constant ST_ERR_FLUSH_RR_C : slv(3 downto 0) := x"8";
   constant ST_DISCARD_C      : slv(3 downto 0) := x"9";
   constant ST_UNKNOWN_C      : slv(3 downto 0) := x"A";

   -- DmaReqSrcType (4b) — DataTypes.bsv (RQ initiators used by Phase 5)
   constant DMA_SRC_RQ_RD_C      : slv(3 downto 0) := x"0";
   constant DMA_SRC_RQ_WR_C      : slv(3 downto 0) := x"1";
   constant DMA_SRC_RQ_ATOMIC_C  : slv(3 downto 0) := x"3";
   constant DMA_SRC_RQ_DISCARD_C : slv(3 downto 0) := x"4";

   ---------------------------------------------------------------------------
   -- TransType (3b) / TypeQP (4b) encodings (Headers.bsv, DataTypes.bsv)
   ---------------------------------------------------------------------------
   constant TRANS_RC_C  : slv(2 downto 0) := "000";
   constant TRANS_UC_C  : slv(2 downto 0) := "001";
   constant TRANS_RD_C  : slv(2 downto 0) := "010";
   constant TRANS_UD_C  : slv(2 downto 0) := "011";
   constant TRANS_CNP_C : slv(2 downto 0) := "100";
   constant TRANS_XRC_C : slv(2 downto 0) := "101";
   -- TypeQP: RC=2, UC=3, UD=4, RAW=8, XRC_SEND=9, XRC_RECV=10
   constant QPT_RC_C       : slv(3 downto 0) := x"2";
   constant QPT_UC_C       : slv(3 downto 0) := x"3";
   constant QPT_UD_C       : slv(3 downto 0) := x"4";
   constant QPT_XRC_RECV_C : slv(3 downto 0) := x"A";

   ---------------------------------------------------------------------------
   -- Struct slice offsets (first-field-at-MSB deriving(Bits))
   ---------------------------------------------------------------------------
   -- RdmaPktMetaData (649b): pktPayloadLen[648:636] pktFragNum[635:628]
   --   isZeroPayloadLen[627] pktHeader(HeaderRDMA 593)[626:34] pdHandler[33:2]
   --   pktValid[1] pktStatus[0].  HeaderRDMA: headerData(512)[626:115]
   --   headerByteEn(64)[114:51] headerMetaData(17)[50:34].
   --   headerData[i] = pktMetaData[115+i].  BTH=headerData[511:416]=pmd[626:531];
   --   RETH(default,128)=headerData[415:288]=pmd[530:403]; RETH.dlen=RETH[31:0]=pmd[434:403].
   constant PMD_ISZEROPAYLOAD_C : integer := 627;
   constant PMD_PKTVALID_C      : integer := 1;
   constant PMD_PKTSTATUS_C     : integer := 0;    -- PktVeriStatus: 0=VALID, 1=LEN_ERR
   -- BTH (96b): trans[95:93] opcode[92:88] ... dqpn[55:32] ... psn[23:0]
   -- RdmaReqPktInfo (161b): bth[160:65] epoch[64] respPktNum(25)[63:39] endPSN(24)[38:15]
   --   isSendReq[14] isWriteReq[13] isWriteImmReq[12] isReadReq[11] isAtomicReq[10]
   --   isOnlyPkt[9] isFirstPkt[8] isMidPkt[7] isLastPkt[6] isFirstOrOnlyPkt[5]
   --   isLastOrOnlyPkt[4] isOnlyRespPkt[3] isExpected[2] isDuplicated[1] isAccCheckPass[0]
   -- RETH (128b): va[127:64] rkey[63:32] dlen[31:0]; RETH=pmd[530:403].
   -- AtomicEth (224b): va[223:160] rkey[159:128] swap[127:64] comp[63:0];
   --   AtomicEth=headerData[415:192]=pmd[530:307]; AtomicEth.va=pmd[530:467].
   -- PermCheckReq (267b): wrID(Maybe#64=65)[266:202] lkey[201:170] rkey[169:138]
   --   localOrRmtKey[137] reqAddr[136:73] totalLen[72:41] pdHandler[40:9]
   --   isZeroDmaLen[8] accFlags(8)[7:0].
   -- RecvReq (216b): id[215:152] len[151:120] laddr[119:56] lkey[55:24] sqpn[23:0].
   -- MemAccessTypeFlag (FlagsType 8b) = enum2Flag(pack(enum)); enum values are 1<<n.
   constant ACC_LOCAL_WRITE_C  : slv(7 downto 0) := x"01";   -- IBV_ACCESS_LOCAL_WRITE
   constant ACC_REMOTE_WRITE_C : slv(7 downto 0) := x"02";   -- IBV_ACCESS_REMOTE_WRITE
   constant ACC_REMOTE_READ_C  : slv(7 downto 0) := x"04";   -- IBV_ACCESS_REMOTE_READ
   constant ACC_REMOTE_ATOMIC_C : slv(7 downto 0) := x"08";  -- IBV_ACCESS_REMOTE_ATOMIC
   constant ATOMIC_WORK_REQ_LEN_C : slv(31 downto 0) := std_logic_vector(to_unsigned(8, 32));

   ---------------------------------------------------------------------------
   -- RdmaOpCode (5b) classifier helpers (Utils.bsv). Integer opcode values:
   --  SEND_FIRST0 MIDDLE1 LAST2 LAST_IMM3 ONLY4 ONLY_IMM5
   --  RDMA_WRITE_FIRST6 MIDDLE7 LAST8 LAST_IMM9 ONLY10 ONLY_IMM11
   --  RDMA_READ_REQUEST12 READ_RESP_FIRST13 MIDDLE14 LAST15 ONLY16
   --  ACK17 ATOMIC_ACK18 COMPARE_SWAP19 FETCH_ADD20 RESYNC21
   --  SEND_LAST_INV22 SEND_ONLY_INV23
   ---------------------------------------------------------------------------
   function opInt (op : slv(4 downto 0)) return integer is
   begin
      return to_integer(unsigned(op));
   end function;

   function isSendReqOp (op : slv(4 downto 0)) return boolean is
      variable u : integer := opInt(op);
   begin
      return (u=0) or (u=1) or (u=2) or (u=3) or (u=4) or (u=5) or (u=22) or (u=23);
   end function;
   function isWriteReqOp (op : slv(4 downto 0)) return boolean is
      variable u : integer := opInt(op);
   begin
      return (u=6) or (u=7) or (u=8) or (u=9) or (u=10) or (u=11);
   end function;
   function isWriteImmReqOp (op : slv(4 downto 0)) return boolean is
      variable u : integer := opInt(op);
   begin
      return (u=9) or (u=11);
   end function;
   -- EN_READ_G=false forces both classifiers false: isSupportedReqOp then
   -- rejects READ/atomics (stage 1 -> ST_INV_REQ_C -> NAK INV_REQ), and every
   -- downstream read/atomic arm (dup-read cache, atomicSrv, payloadGen issue)
   -- constant-folds away in synthesis.
   function isReadReqOp (op : slv(4 downto 0)) return boolean is
   begin
      return EN_READ_G and (opInt(op) = 12);
   end function;
   function isAtomicReqOp (op : slv(4 downto 0)) return boolean is
      variable u : integer := opInt(op);
   begin
      return EN_READ_G and ((u=19) or (u=20));
   end function;
   function isFirstOp (op : slv(4 downto 0)) return boolean is
      variable u : integer := opInt(op);
   begin
      return (u=0) or (u=6) or (u=13);
   end function;
   function isMiddleOp (op : slv(4 downto 0)) return boolean is
      variable u : integer := opInt(op);
   begin
      return (u=1) or (u=7) or (u=14);
   end function;
   function isLastOp (op : slv(4 downto 0)) return boolean is
      variable u : integer := opInt(op);
   begin
      return (u=2) or (u=3) or (u=22) or (u=8) or (u=9) or (u=15);
   end function;
   function isOnlyOp (op : slv(4 downto 0)) return boolean is
      variable u : integer := opInt(op);
   begin
      return (u=4) or (u=5) or (u=23) or (u=10) or (u=11) or (u=12) or
             (u=19) or (u=20) or (u=16) or (u=17) or (u=18);
   end function;
   function isFirstOrOnlyOp (op : slv(4 downto 0)) return boolean is
   begin
      return isFirstOp(op) or isOnlyOp(op);
   end function;
   function isLastOrOnlyOp (op : slv(4 downto 0)) return boolean is
   begin
      return isLastOp(op) or isOnlyOp(op);
   end function;

   -- isSupportedReqOpCodeRQ(qpt, opcode)
   function isSupportedReqOp (qpt : slv(3 downto 0); op : slv(4 downto 0)) return boolean is
   begin
      if (qpt = QPT_UC_C) then
         -- UC: SEND_{FIRST..ONLY_IMM}={0..5} (excludes *_WITH_INVALIDATE) or WRITE_*
         return (opInt(op) <= 5) or isWriteReqOp(op);
      end if;
      if (qpt = QPT_UD_C) then
         return (opInt(op) = 4) or (opInt(op) = 5);
      end if;
      if (qpt = QPT_RC_C) or (qpt = QPT_XRC_RECV_C) then
         return isSendReqOp(op) or isWriteReqOp(op) or isReadReqOp(op) or isAtomicReqOp(op);
      end if;
      return false;
   end function;

   -- checkNormalReqOpCodeSeqRQ(preOpCode, curOpCode)
   function checkNormalSeq (preOp : slv(4 downto 0); curOp : slv(4 downto 0)) return boolean is
      variable p : integer := opInt(preOp);
      variable c : integer := opInt(curOp);
   begin
      if (p=0) or (p=1) then                               -- SEND_FIRST / SEND_MIDDLE
         return (c=1) or (c=2) or (c=3) or (c=22);
      elsif (p=2) or (p=3) or (p=22) or (p=4) or (p=5) or (p=23) then
         return true;                                      -- SEND_LAST*/SEND_ONLY*
      elsif (p=6) or (p=7) then                            -- RDMA_WRITE_FIRST / MIDDLE
         return (c=7) or (c=8) or (c=9);
      elsif (p=8) or (p=9) or (p=10) or (p=11) or (p=12) or (p=19) or (p=20) then
         return true;                                      -- WRITE_LAST*/ONLY*/READ/ATOMIC
      else
         return false;
      end if;
   end function;

   -- getInvReqStatusByTransType(transType) -> RdmaReqStatus (4b)
   function invReqStatus (trans : slv(2 downto 0)) return slv is
   begin
      if    (trans = TRANS_RC_C)  then return ST_INV_REQ_C;
      elsif (trans = TRANS_UC_C)  then return ST_DISCARD_C;
      elsif (trans = TRANS_RD_C)  then return ST_INV_RD_C;
      elsif (trans = TRANS_UD_C)  then return ST_DISCARD_C;
      elsif (trans = TRANS_CNP_C) then return ST_DISCARD_C;
      elsif (trans = TRANS_XRC_C) then return ST_INV_RD_C;
      else                             return ST_UNKNOWN_C;
      end if;
   end function;

   -- calcOldestValidPsn4RQ(ePSN) = ePSN - 2^23 = { ~ePSN[23], ePSN[22:0] }
   function oldestValidPsn (epsn : slv(23 downto 0)) return slv is
   begin
      return (not epsn(23)) & epsn(22 downto 0);
   end function;

   -- psnInRangeExclusive(psn, psnStart, psnEnd) (24b PSN)
   function psnInRangeExcl (psn : slv(23 downto 0); psnStart : slv(23 downto 0);
                            psnEnd : slv(23 downto 0)) return boolean is
      variable psnGtStart : boolean := unsigned(psnStart) < unsigned(psn);
      variable psnLtEnd    : boolean := unsigned(psn) < unsigned(psnEnd);
   begin
      if (psnStart(23) = psnEnd(23)) then
         return psnGtStart and psnLtEnd;
      else
         return (psnGtStart and (psnStart(23) = psn(23))) or
                (psnLtEnd and (psn(23) = psnEnd(23)));
      end if;
   end function;

   -- truncateLenByPMTU: PktNum(25b) = len >> log2(pmtuBytes)
   function truncLenPktNum (len : slv(31 downto 0); pmtu : slv(2 downto 0)) return slv is
      variable sh : integer;
   begin
      case to_integer(unsigned(pmtu)) is
         when 1      => sh := 8;    -- 256
         when 2      => sh := 9;    -- 512
         when 3      => sh := 10;   -- 1024
         when 4      => sh := 11;   -- 2048
         when others => sh := 12;   -- 4096 (=5)
      end case;
      return slv(resize(shift_right(unsigned(len), sh), 25));
   end function;
   -- isZero(pmtuResidue): low log2(pmtuBytes) bits of len are all zero
   function pmtuResidueZero (len : slv(31 downto 0); pmtu : slv(2 downto 0)) return boolean is
      variable sh : integer;
   begin
      case to_integer(unsigned(pmtu)) is
         when 1      => sh := 8;
         when 2      => sh := 9;
         when 3      => sh := 10;
         when 4      => sh := 11;
         when others => sh := 12;
      end case;
      return unsigned(len(sh-1 downto 0)) = 0;
   end function;

   -- isLessOrEqOneR(x) : x <= 1
   function isLessOrEqOne (x : slv) return boolean is
   begin
      return unsigned(x) <= 1;
   end function;

   ---------------------------------------------------------------------------
   -- Phase 4 DMA addr/len PMTU arithmetic (Utils.bsv @422-665).  oneAsPSN=1
   -- everywhere in stages 12-16, so *PsnMultiplyPMTU reduce to +/- 2^log.
   ---------------------------------------------------------------------------
   -- getPmtuLogValue: 256->8, 512->9, 1024->10, 2048->11, 4096->12
   function pmtuLog (pmtu : slv(2 downto 0)) return integer is
   begin
      case to_integer(unsigned(pmtu)) is
         when 1      => return 8;    -- IBV_MTU_256
         when 2      => return 9;    -- IBV_MTU_512
         when 3      => return 10;   -- IBV_MTU_1024
         when 4      => return 11;   -- IBV_MTU_2048
         when others => return 12;   -- IBV_MTU_4096 (=5)
      end case;
   end function;
   -- addrAddPsnMultiplyPMTU(addr, 1, pmtu) = addr + 2^log
   function addrAddOnePmtu (addr : slv(63 downto 0); pmtu : slv(2 downto 0)) return slv is
   begin
      return slv(unsigned(addr) + to_unsigned(2**pmtuLog(pmtu), 64));
   end function;
   -- lenSubtractPsnMultiplyPMTU(len, 1, pmtu) = len - 2^log
   function lenSubOnePmtu (len : slv(31 downto 0); pmtu : slv(2 downto 0)) return slv is
   begin
      return slv(unsigned(len) - to_unsigned(2**pmtuLog(pmtu), 32));
   end function;
   -- lenAddPsnMultiplyPMTU(len, 1, pmtu) = len + 2^log
   function lenAddOnePmtu (len : slv(31 downto 0); pmtu : slv(2 downto 0)) return slv is
   begin
      return slv(unsigned(len) + to_unsigned(2**pmtuLog(pmtu), 32));
   end function;
   -- calcPmtuLen(pmtu) = 2^log (PktLen 13b)
   function calcPmtuLen (pmtu : slv(2 downto 0)) return slv is
   begin
      return slv(to_unsigned(2**pmtuLog(pmtu), 13));
   end function;
   -- pktLenEqPMTU(pktLen, pmtu): pktLen with bit[log] cleared is zero (i.e. == PMTU)
   function pktLenEqPmtu (pktLen : slv(12 downto 0); pmtu : slv(2 downto 0)) return boolean is
      variable t : slv(12 downto 0);
   begin
      t := pktLen;
      t(pmtuLog(pmtu)) := '0';
      return unsigned(t) = 0;
   end function;
   -- lenSubtractPktLen: low (log+1) bits subtract, no borrow into high part
   function lenSubPktLen (len : slv(31 downto 0); pktLen : slv(12 downto 0);
                          pmtu : slv(2 downto 0)) return slv is
   begin
      case to_integer(unsigned(pmtu)) is
         when 1      => return len(31 downto 9)  & slv(unsigned(len(8  downto 0)) - unsigned(pktLen(8  downto 0)));
         when 2      => return len(31 downto 10) & slv(unsigned(len(9  downto 0)) - unsigned(pktLen(9  downto 0)));
         when 3      => return len(31 downto 11) & slv(unsigned(len(10 downto 0)) - unsigned(pktLen(10 downto 0)));
         when 4      => return len(31 downto 12) & slv(unsigned(len(11 downto 0)) - unsigned(pktLen(11 downto 0)));
         when others => return len(31 downto 13) & slv(unsigned(len(12 downto 0)) - unsigned(pktLen(12 downto 0)));
      end case;
   end function;
   -- lenAddPktLen: if pktLen==PMTU add one PMTU, else replace low log bits with pktLen
   function lenAddPktLen (len : slv(31 downto 0); pktLen : slv(12 downto 0);
                          pmtu : slv(2 downto 0)) return slv is
   begin
      if (pktLenEqPmtu(pktLen, pmtu)) then
         return lenAddOnePmtu(len, pmtu);
      else
         case to_integer(unsigned(pmtu)) is
            when 1      => return len(31 downto 8)  & pktLen(7  downto 0);
            when 2      => return len(31 downto 9)  & pktLen(8  downto 0);
            when 3      => return len(31 downto 10) & pktLen(9  downto 0);
            when 4      => return len(31 downto 11) & pktLen(10 downto 0);
            when others => return len(31 downto 12) & pktLen(11 downto 0);
         end case;
      end if;
   end function;
   -- lenGtEqPktLen: high part (above log) nonzero, or low (log+1) bits >= pktLen
   function lenGtEqPktLen (len : slv(31 downto 0); pktLen : slv(12 downto 0);
                           pmtu : slv(2 downto 0)) return boolean is
   begin
      case to_integer(unsigned(pmtu)) is
         when 1      => return (unsigned(len(31 downto 9))  /= 0) or (unsigned(len(8  downto 0)) >= unsigned(pktLen(8  downto 0)));
         when 2      => return (unsigned(len(31 downto 10)) /= 0) or (unsigned(len(9  downto 0)) >= unsigned(pktLen(9  downto 0)));
         when 3      => return (unsigned(len(31 downto 11)) /= 0) or (unsigned(len(10 downto 0)) >= unsigned(pktLen(10 downto 0)));
         when 4      => return (unsigned(len(31 downto 12)) /= 0) or (unsigned(len(11 downto 0)) >= unsigned(pktLen(11 downto 0)));
         when others => return (unsigned(len(31 downto 13)) /= 0) or (unsigned(len(12 downto 0)) >= unsigned(pktLen(12 downto 0)));
      end case;
   end function;
   -- lenGtEqPMTU: bits above (log-1) nonzero, i.e. len >= 2^log
   function lenGtEqPmtu (len : slv(31 downto 0); pmtu : slv(2 downto 0)) return boolean is
   begin
      case to_integer(unsigned(pmtu)) is
         when 1      => return unsigned(len(31 downto 8))  /= 0;
         when 2      => return unsigned(len(31 downto 9))  /= 0;
         when 3      => return unsigned(len(31 downto 10)) /= 0;
         when 4      => return unsigned(len(31 downto 11)) /= 0;
         when others => return unsigned(len(31 downto 12)) /= 0;
      end case;
   end function;

   -- isErrReqStatus(reqStatus): INV_REQ(3) | INV_RD(4) | RMT_ACC(5) | RMT_OP(6)  (Phase 5)
   function isErrReqStatus (st : slv(3 downto 0)) return boolean is
   begin
      return (unsigned(st) >= 3) and (unsigned(st) <= 6);
   end function;

   -- qpNeedGenResp(trans): RC(000) | RD(010) | XRC(101) generate responses  (Phase 6)
   function qpNeedGenResp (trans : slv(2 downto 0)) return boolean is
   begin
      return (trans = "000") or (trans = "010") or (trans = "101");
   end function;

   ---------------------------------------------------------------------------
   -- Phase 8 : response RdmaOpCode + header generation (BSV Utils.bsv /
   --           ReqHandleRQ.bsv:77-319). RdmaOpCode encodings (Headers.bsv:100).
   ---------------------------------------------------------------------------
   constant OP_READ_REQUEST_C     : slv(4 downto 0) := "01100";  -- 0x0c
   constant OP_READ_RESP_FIRST_C  : slv(4 downto 0) := "01101";  -- 0x0d
   constant OP_READ_RESP_MIDDLE_C : slv(4 downto 0) := "01110";  -- 0x0e
   constant OP_READ_RESP_LAST_C   : slv(4 downto 0) := "01111";  -- 0x0f
   constant OP_READ_RESP_ONLY_C   : slv(4 downto 0) := "10000";  -- 0x10
   constant OP_ACKNOWLEDGE_C      : slv(4 downto 0) := "10001";  -- 0x11
   constant OP_ATOMIC_ACK_C       : slv(4 downto 0) := "10010";  -- 0x12

   -- isNormalOrErrorReqStatus (ReqHandleRQ.bsv:43): NORMAL|INV_REQ|INV_RD|RMT_ACC|RMT_OP
   function isNormalOrErrStatus (st : slv(3 downto 0)) return boolean is
   begin
      case st is
         when ST_NORMAL_C | ST_INV_REQ_C | ST_INV_RD_C | ST_RMT_ACC_C | ST_RMT_OP_C =>
            return true;
         when others => return false;
      end case;
   end function;

   -- calcPadCnt (Utils.bsv:830), PAD_WIDTH=2: padCnt = (4 - len[1:0]) mod 4
   function calcPadCnt (len : slv(31 downto 0)) return slv is
   begin
      return slv(to_unsigned((4 - to_integer(unsigned(len(1 downto 0)))) mod 4, 2));
   end function;

   -- AETH validity + build (ReqHandleRQ.bsv:125 genAethByReqStatus).
   -- AETH(32) = rsvd[31] code[30:29] value[28:24] msn[23:0].
   function aethValid (st : slv(3 downto 0)) return boolean is
   begin
      case st is
         when ST_NORMAL_C | ST_DUP_C | ST_RNR_C | ST_SEQ_ERR_C
            | ST_INV_REQ_C | ST_INV_RD_C | ST_RMT_ACC_C | ST_RMT_OP_C => return true;
         when others => return false;
      end case;
   end function;

   function genAeth (st : slv(3 downto 0); minRnrTimer : slv(4 downto 0);
                     msn : slv(23 downto 0)) return slv is
      variable code : slv(1 downto 0);
      variable val  : slv(4 downto 0);
   begin
      case st is
         when ST_NORMAL_C | ST_DUP_C => code := "00"; val := "11111";  -- ACK, INVALID_CREDIT_CNT
         when ST_RNR_C               => code := "01"; val := minRnrTimer;
         when ST_SEQ_ERR_C           => code := "11"; val := "00000";  -- NAK SEQ_ERR
         when ST_INV_REQ_C           => code := "11"; val := "00001";  -- NAK INV_REQ
         when ST_RMT_ACC_C           => code := "11"; val := "00010";  -- NAK RMT_ACC
         when ST_RMT_OP_C            => code := "11"; val := "00011";  -- NAK RMT_OP
         when ST_INV_RD_C            => code := "11"; val := "00100";  -- NAK INV_RD
         when others                 => code := "00"; val := "00000";  -- unused (Invalid path)
      end case;
      return '0' & code & val & msn;
   end function;

   -- genFirstOrOnlyRespRdmaOpCode (ReqHandleRQ.bsv:77): [5]=valid, [4:0]=opcode.
   function genFirstOnlyRespOp (reqOp : slv(4 downto 0); st : slv(3 downto 0);
                                isOnlyReadResp : boolean) return slv is
      variable op : integer := to_integer(unsigned(reqOp));
   begin
      case st is
         when ST_NORMAL_C | ST_DUP_C =>
            if ((op >= 0 and op <= 11) or op = 22 or op = 23) then   -- SEND*/WRITE*/*INVALIDATE
               return '1' & OP_ACKNOWLEDGE_C;
            elsif (op = 12) then                                     -- RDMA_READ_REQUEST
               if isOnlyReadResp then return '1' & OP_READ_RESP_ONLY_C;
               else return '1' & OP_READ_RESP_FIRST_C; end if;
            elsif (op = 19 or op = 20) then                          -- COMPARE_SWAP/FETCH_ADD
               return '1' & OP_ATOMIC_ACK_C;
            else return "000000"; end if;
         when ST_SEQ_ERR_C | ST_RNR_C | ST_INV_REQ_C | ST_INV_RD_C | ST_RMT_ACC_C | ST_RMT_OP_C =>
            return '1' & OP_ACKNOWLEDGE_C;
         when others => return "000000";
      end case;
   end function;

   -- genMiddleOrLastRespRdmaOpCode (ReqHandleRQ.bsv:116): [5]=valid, [4:0]=opcode.
   function genMidLastRespOp (st : slv(3 downto 0); isLastResp : boolean) return slv is
   begin
      case st is
         when ST_NORMAL_C | ST_DUP_C =>
            if isLastResp then return '1' & OP_READ_RESP_LAST_C;
            else return '1' & OP_READ_RESP_MIDDLE_C; end if;
         when ST_RMT_OP_C => return '1' & OP_ACKNOWLEDGE_C;
         when others => return "000000";
      end case;
   end function;

   -- qpType2TransType (Utils.bsv:741): [3]=valid, [2:0]=trans
   function qpType2Trans (qpt : slv(3 downto 0)) return slv is
   begin
      case qpt is
         when QPT_RC_C       => return '1' & TRANS_RC_C;
         when QPT_UC_C       => return '1' & TRANS_UC_C;
         when QPT_UD_C       => return '1' & TRANS_UD_C;
         when QPT_XRC_RECV_C => return '1' & TRANS_XRC_C;
         when others         => return "0000";
      end case;
   end function;

   -- getMaybeDestQpnRQ (ReqHandleRQ.bsv:54): valid for RC/UC/XRC_RECV
   function destQpnValid (qpt : slv(3 downto 0)) return boolean is
   begin
      case qpt is
         when QPT_RC_C | QPT_UC_C | QPT_XRC_RECV_C => return true;
         when others => return false;
      end case;
   end function;

   -- genHeaderRDMA (Utils.bsv:319). HeaderRDMA(593) = headerData[592:81]
   -- byteEn[80:17] metaData[16:0]; meta = headerLen[16:10] fragNum[9:8]
   -- lastFragValidByteNum[7:2] hasPayload[1] isEmptyHeader[0]. All response
   -- headers are <=24 bytes -> single fragment, byteEn is MSB-aligned ones.
   function genHeaderRDMA (hdrData : slv(511 downto 0); lenBytes : integer;
                           hasPayloadV : sl) return slv is
      variable byteEn : slv(63 downto 0) := (others => '0');
      variable meta   : slv(16 downto 0);
   begin
      byteEn(63 downto 64 - lenBytes) := (others => '1');
      meta := slv(to_unsigned(lenBytes, 7)) & "01"
            & slv(to_unsigned(lenBytes, 6)) & hasPayloadV & '0';
      return hdrData & byteEn & meta;
   end function;

   -- BTH(96) builder — reserved/solicited/migReq/tver/fecn/becn/ackReq all 0.
   function mkRespBth (trans : slv(2 downto 0); opcode : slv(4 downto 0);
                       padCnt : slv(1 downto 0); pkey : slv(15 downto 0);
                       dqpn : slv(23 downto 0); psn : slv(23 downto 0)) return slv is
   begin
      return trans & opcode & '0' & '0' & padCnt & "0000" & pkey
           & '0' & '0' & "000000" & dqpn & '0' & "0000000" & psn;
   end function;

   -- genFirstOrOnlyRespHeader (ReqHandleRQ.bsv:188) -> Maybe#HeaderRDMA(594):
   -- [593]=valid, [592:0]=HeaderRDMA.
   function genFirstOrOnlyRespHeader (
      reqOp : slv(4 downto 0); st : slv(3 downto 0); payloadLen : slv(31 downto 0);
      atomicOrig : slv(64 downto 0); qpType : slv(3 downto 0); pkey : slv(15 downto 0);
      dqpn : slv(23 downto 0); minRnrTimer : slv(4 downto 0); psn : slv(23 downto 0);
      msn : slv(23 downto 0); isOnlyReadResp : boolean) return slv is
      variable transM  : slv(3 downto 0) := qpType2Trans(qpType);
      variable opM     : slv(5 downto 0) := genFirstOnlyRespOp(reqOp, st, isOnlyReadResp);
      variable opcode  : slv(4 downto 0);
      variable padV    : slv(1 downto 0);
      variable bth     : slv(95 downto 0);
      variable aeth    : slv(31 downto 0);
      variable hdrData : slv(511 downto 0) := (others => '0');
   begin
      if (transM(3) = '1' and opM(5) = '1' and destQpnValid(qpType) and aethValid(st)) then
         opcode := opM(4 downto 0);
         if isOnlyReadResp then padV := calcPadCnt(payloadLen); else padV := "00"; end if;
         bth  := mkRespBth(transM(2 downto 0), opcode, padV, pkey, dqpn, psn);
         aeth := genAeth(st, minRnrTimer, msn);
         case opcode is
            when OP_ACKNOWLEDGE_C =>
               hdrData(511 downto 384) := bth & aeth;
               return '1' & genHeaderRDMA(hdrData, 16, '0');
            when OP_ATOMIC_ACK_C =>
               hdrData(511 downto 320) := bth & aeth & atomicOrig(63 downto 0);
               return '1' & genHeaderRDMA(hdrData, 24, '0');
            when OP_READ_RESP_FIRST_C | OP_READ_RESP_ONLY_C =>
               hdrData(511 downto 384) := bth & aeth;
               if (unsigned(payloadLen) = 0) then
                  return '1' & genHeaderRDMA(hdrData, 16, '0');
               else
                  return '1' & genHeaderRDMA(hdrData, 16, '1');
               end if;
            when others => return (593 downto 0 => '0');
         end case;
      else
         return (593 downto 0 => '0');
      end if;
   end function;

   -- genMiddleOrLastRespHeader (ReqHandleRQ.bsv:258) -> Maybe#HeaderRDMA(594).
   function genMidLastRespHeader (
      st : slv(3 downto 0); payloadLen : slv(31 downto 0); qpType : slv(3 downto 0);
      pkey : slv(15 downto 0); dqpn : slv(23 downto 0); minRnrTimer : slv(4 downto 0);
      psn : slv(23 downto 0); msn : slv(23 downto 0); isLastResp : boolean) return slv is
      variable transM  : slv(3 downto 0) := qpType2Trans(qpType);
      variable opM     : slv(5 downto 0) := genMidLastRespOp(st, isLastResp);
      variable opcode  : slv(4 downto 0);
      variable padV    : slv(1 downto 0);
      variable bth     : slv(95 downto 0);
      variable aeth    : slv(31 downto 0);
      variable hdrData : slv(511 downto 0) := (others => '0');
   begin
      if (transM(3) = '1' and opM(5) = '1' and destQpnValid(qpType) and aethValid(st)) then
         opcode := opM(4 downto 0);
         if isLastResp then padV := calcPadCnt(payloadLen); else padV := "00"; end if;
         bth  := mkRespBth(transM(2 downto 0), opcode, padV, pkey, dqpn, psn);
         aeth := genAeth(st, minRnrTimer, msn);
         case opcode is
            when OP_ACKNOWLEDGE_C =>
               hdrData(511 downto 384) := bth & aeth;
               return '1' & genHeaderRDMA(hdrData, 16, '0');
            when OP_READ_RESP_LAST_C =>
               hdrData(511 downto 384) := bth & aeth;
               return '1' & genHeaderRDMA(hdrData, 16, '1');
            when OP_READ_RESP_MIDDLE_C =>
               hdrData(511 downto 416) := bth;
               return '1' & genHeaderRDMA(hdrData, 12, '1');
            when others => return (593 downto 0 => '0');
         end case;
      else
         return (593 downto 0 => '0');
      end if;
   end function;

   ---------------------------------------------------------------------------
   -- getRnrTimeOutValue(minRnrTimer) LUT — cycles = usValue*1000/TARGET_CYCLE_NS
   -- with TARGET_CYCLE_NS=2 (Settings.bsv) -> value*500. RNR_WAIT_CYCLE_CNT_WIDTH=29.
   ---------------------------------------------------------------------------
   type Slv29Array is array (0 to 31) of slv(28 downto 0);
   function rnrTo (n : integer) return slv is
   begin
      return slv(to_unsigned(n, 29));
   end function;
   constant RNR_TIMEOUT_C : Slv29Array := (
      0  => rnrTo(327680000),  1  => rnrTo(5000),      2  => rnrTo(10000),
      3  => rnrTo(15000),      4  => rnrTo(20000),     5  => rnrTo(30000),
      6  => rnrTo(40000),      7  => rnrTo(60000),     8  => rnrTo(80000),
      9  => rnrTo(120000),     10 => rnrTo(160000),    11 => rnrTo(240000),
      12 => rnrTo(320000),     13 => rnrTo(480000),    14 => rnrTo(640000),
      15 => rnrTo(960000),     16 => rnrTo(1280000),   17 => rnrTo(1920000),
      18 => rnrTo(2560000),    19 => rnrTo(3840000),   20 => rnrTo(5120000),
      21 => rnrTo(7680000),    22 => rnrTo(10240000),  23 => rnrTo(15360000),
      24 => rnrTo(20480000),   25 => rnrTo(30720000),  26 => rnrTo(40960000),
      27 => rnrTo(61440000),   28 => rnrTo(81920000),  29 => rnrTo(122880000),
      30 => rnrTo(163840000),  31 => rnrTo(245760000));

   ---------------------------------------------------------------------------
   -- Phase 9 : genWorkCompRQ helpers (BSV ReqHandleRQ.bsv:65,3385; Utils.bsv:942/
   --           971/1182/1192). RdmaOpCode (low-5) encodings from Headers.bsv:36.
   --   WorkCompStatus (DataTypes.bsv:613) encodings (5b): SUCCESS=0, WR_FLUSH=5,
   --   REM_INV_REQ=9, REM_ACCESS=10, REM_OP=11, REM_INV_RD=15.
   ---------------------------------------------------------------------------
   -- rdmaReqHasImmDt (Utils.bsv:1182): SEND/WRITE _LAST/_ONLY_WITH_IMMEDIATE
   function opHasImmDt (op : slv(4 downto 0)) return boolean is
   begin
      case op is
         when "00011" | "00101" | "01001" | "01011" => return true;  -- 0x03,0x05,0x09,0x0b
         when others => return false;
      end case;
   end function;

   -- rdmaReqHasIETH (Utils.bsv:1192): SEND_LAST/_ONLY_WITH_INVALIDATE (0x16,0x17)
   function opHasIETH (op : slv(4 downto 0)) return boolean is
   begin
      case op is
         when "10110" | "10111" => return true;
         when others => return false;
      end case;
   end function;

   -- genWorkCompStatusFromReqStatusRQ (ReqHandleRQ.bsv:65). Returns slv(5:0):
   -- [5]=Valid tag; [4:0]=WorkCompStatus (only meaningful when tag='1').
   function genWcStatus (st : slv(3 downto 0)) return slv is
   begin
      case st is
         when ST_NORMAL_C       => return "1" & "00000";  -- IBV_WC_SUCCESS=0
         when ST_INV_REQ_C      => return "1" & "01001";  -- REM_INV_REQ_ERR=9
         when ST_INV_RD_C       => return "1" & "01111";  -- REM_INV_RD_REQ_ERR=15
         when ST_RMT_ACC_C      => return "1" & "01010";  -- REM_ACCESS_ERR=10
         when ST_RMT_OP_C       => return "1" & "01011";  -- REM_OP_ERR=11
         when ST_ERR_FLUSH_RR_C => return "1" & "00101";  -- WR_FLUSH_ERR=5
         when others            => return "0" & "00000";  -- tagged Invalid
      end case;
   end function;

   ---------------------------------------------------------------------------
   -- SURF Fifo interface signals — one bundle per instance.
   -- Naming: fNN follows the pipeline dataflow order (== BSV declaration order):
   --   f01 supportedReqOpCodeCheckQ    f17 reqLenCheckQ
   --   f02 reqOpCodeSeqCheckQ          f18 issuePayloadConReqQ
   --   f03 rnrCheckQ                   f19 issuePayloadGenReqQ
   --   f04 rnrTriggerQ                 f20 issueAtomicReqQ
   --   f05 qpAccPermCheckQ             f21 respGenCheck4NormalCaseQ
   --   f06 reqPermInfoBuildQ           f22 respGenCheck4OtherCasesQ
   --   f07 reqPermQueryTmpQ            f23 respCountQ
   --   f08 reqPermQueryQ               f24 respPsnAndMsnQ
   --   f09 reqPermCheckQ               f25 waitAtomicRespQ
   --   f10 readCacheInsertQ            f26 atomicCacheInsertQ
   --   f11 dupReadReqPermQueryQ        f27 respCheckQ
   --   f12 dupReadReqPermCheckQ        f28 dupAtomicReqPermQueryQ
   --   f13 reqAddrCalcQ                f29 dupAtomicReqPermCheckQ
   --   f14 reqRemainingLenCalcQ        f30 respHeaderGenQ
   --   f15 reqEnoughDmaSpaceQ          f31 pendingRespQ
   --   f16 reqTotalLenCalcQ            f32 workCompReqQ
   -- Output FIFOs: wcOut workCompGenReqOutQ, rhOut respHeaderOutQ, psnOut psnRespOutQ
   ---------------------------------------------------------------------------
   -- widths, in fNN order
   constant W01_C : integer := 838;   constant W17_C : integer := 1212;
   constant W02_C : integer := 814;   constant W18_C : integer := 1146;
   constant W03_C : integer := 819;   constant W19_C : integer := 1083;
   constant W04_C : integer := 1036;  constant W20_C : integer := 1154;
   constant W05_C : integer := 1031;  constant W21_C : integer := 1154;
   constant W06_C : integer := 1031;  constant W22_C : integer := 1154;
   constant W07_C : integer := 1426;  constant W23_C : integer := 1154;
   constant W08_C : integer := 1209;  constant W24_C : integer := 1156;
   constant W09_C : integer := 1210;  constant W25_C : integer := 1204;
   constant W10_C : integer := 1209;  constant W26_C : integer := 1204;
   constant W11_C : integer := 1209;  constant W27_C : integer := 1428;
   constant W12_C : integer := 1210;  constant W28_C : integer := 1428;
   constant W13_C : integer := 1082;  constant W29_C : integer := 1204;
   constant W14_C : integer := 1146;  constant W30_C : integer := 1204;
   constant W15_C : integer := 1210;  constant W31_C : integer := 1798;
   constant W16_C : integer := 1182;  constant W32_C : integer := 1204;
   constant WCW_C : integer := 198;   -- workCompGenReqOutQ
   constant RHW_C : integer := 593;   -- respHeaderOutQ
   constant PSW_C : integer := 24;    -- psnRespOutQ

   -- per-FIFO handshake bundles
   signal f01WrEn, f01RdEn, f01Valid, f01NotFull : sl; signal f01Din, f01Dout : slv(W01_C-1 downto 0);
   signal f02WrEn, f02RdEn, f02Valid, f02NotFull : sl; signal f02Din, f02Dout : slv(W02_C-1 downto 0);
   signal f03WrEn, f03RdEn, f03Valid, f03NotFull : sl; signal f03Din, f03Dout : slv(W03_C-1 downto 0);
   signal f04WrEn, f04RdEn, f04Valid, f04NotFull : sl; signal f04Din, f04Dout : slv(W04_C-1 downto 0);
   signal f05WrEn, f05RdEn, f05Valid, f05NotFull : sl; signal f05Din, f05Dout : slv(W05_C-1 downto 0);
   signal f06WrEn, f06RdEn, f06Valid, f06NotFull : sl; signal f06Din, f06Dout : slv(W06_C-1 downto 0);
   signal f07WrEn, f07RdEn, f07Valid, f07NotFull : sl; signal f07Din, f07Dout : slv(W07_C-1 downto 0);
   signal f08WrEn, f08RdEn, f08Valid, f08NotFull : sl; signal f08Din, f08Dout : slv(W08_C-1 downto 0);
   signal f09WrEn, f09RdEn, f09Valid, f09NotFull : sl; signal f09Din, f09Dout : slv(W09_C-1 downto 0);
   signal f10WrEn, f10RdEn, f10Valid, f10NotFull : sl; signal f10Din, f10Dout : slv(W10_C-1 downto 0);
   signal f11WrEn, f11RdEn, f11Valid, f11NotFull : sl; signal f11Din, f11Dout : slv(W11_C-1 downto 0);
   signal f12WrEn, f12RdEn, f12Valid, f12NotFull : sl; signal f12Din, f12Dout : slv(W12_C-1 downto 0);
   signal f13WrEn, f13RdEn, f13Valid, f13NotFull : sl; signal f13Din, f13Dout : slv(W13_C-1 downto 0);
   signal f14WrEn, f14RdEn, f14Valid, f14NotFull : sl; signal f14Din, f14Dout : slv(W14_C-1 downto 0);
   signal f15WrEn, f15RdEn, f15Valid, f15NotFull : sl; signal f15Din, f15Dout : slv(W15_C-1 downto 0);
   signal f16WrEn, f16RdEn, f16Valid, f16NotFull : sl; signal f16Din, f16Dout : slv(W16_C-1 downto 0);
   signal f17WrEn, f17RdEn, f17Valid, f17NotFull : sl; signal f17Din, f17Dout : slv(W17_C-1 downto 0);
   signal f18WrEn, f18RdEn, f18Valid, f18NotFull : sl; signal f18Din, f18Dout : slv(W18_C-1 downto 0);
   signal f19WrEn, f19RdEn, f19Valid, f19NotFull : sl; signal f19Din, f19Dout : slv(W19_C-1 downto 0);
   signal f20WrEn, f20RdEn, f20Valid, f20NotFull : sl; signal f20Din, f20Dout : slv(W20_C-1 downto 0);
   signal f21WrEn, f21RdEn, f21Valid, f21NotFull : sl; signal f21Din, f21Dout : slv(W21_C-1 downto 0);
   signal f22WrEn, f22RdEn, f22Valid, f22NotFull : sl; signal f22Din, f22Dout : slv(W22_C-1 downto 0);
   signal f23WrEn, f23RdEn, f23Valid, f23NotFull : sl; signal f23Din, f23Dout : slv(W23_C-1 downto 0);
   signal f24WrEn, f24RdEn, f24Valid, f24NotFull : sl; signal f24Din, f24Dout : slv(W24_C-1 downto 0);
   signal f25WrEn, f25RdEn, f25Valid, f25NotFull : sl; signal f25Din, f25Dout : slv(W25_C-1 downto 0);
   signal f26WrEn, f26RdEn, f26Valid, f26NotFull : sl; signal f26Din, f26Dout : slv(W26_C-1 downto 0);
   signal f27WrEn, f27RdEn, f27Valid, f27NotFull : sl; signal f27Din, f27Dout : slv(W27_C-1 downto 0);
   signal f28WrEn, f28RdEn, f28Valid, f28NotFull : sl; signal f28Din, f28Dout : slv(W28_C-1 downto 0);
   signal f29WrEn, f29RdEn, f29Valid, f29NotFull : sl; signal f29Din, f29Dout : slv(W29_C-1 downto 0);
   signal f30WrEn, f30RdEn, f30Valid, f30NotFull : sl; signal f30Din, f30Dout : slv(W30_C-1 downto 0);
   signal f31WrEn, f31RdEn, f31Valid, f31NotFull : sl; signal f31Din, f31Dout : slv(W31_C-1 downto 0);
   signal f32WrEn, f32RdEn, f32Valid, f32NotFull : sl; signal f32Din, f32Dout : slv(W32_C-1 downto 0);
   -- output FIFOs
   signal wcOutWrEn, wcOutRdEn, wcOutValid, wcOutNotFull : sl; signal wcOutDin, wcOutDout : slv(WCW_C-1 downto 0);
   signal rhOutWrEn, rhOutRdEn, rhOutValid, rhOutNotFull : sl; signal rhOutDin, rhOutDout : slv(RHW_C-1 downto 0);
   signal psnOutWrEn, psnOutRdEn, psnOutValid, psnOutNotFull : sl; signal psnOutDin, psnOutDout : slv(PSW_C-1 downto 0);

   signal fifoClr : sl;

   ---------------------------------------------------------------------------
   -- Child-instance interconnect signals
   ---------------------------------------------------------------------------
   -- U_AtomicSrv (internal): request 245b / response 116b
   signal atomicReqValid  : sl;
   signal atomicReqData   : slv(244 downto 0);
   signal atomicReqRdy    : sl;
   signal atomicRespValid : sl;
   signal atomicRespData  : slv(115 downto 0);
   signal atomicRespRdEn  : sl;
   -- U_PendingDestReadAtomicReqCnt (CountCF, WIDTH_G=8)
   signal ccIncrEn  : sl;
   signal ccIncrRdy : sl;
   signal ccDecrEn  : sl;
   signal ccDecrRdy : sl;
   signal ccWriteEn : sl;
   signal ccWriteVal : slv(7 downto 0);
   signal ccCnt     : slv(7 downto 0);

begin

   fifoClr <= rst or isReset;

   -- Combinational Mealy method: respHeaderOutNotEmpty() = psnRespOutQ.notEmpty
   respHeaderOutNotEmpty <= psnOutValid;

   -- workCompGenReqPipeOut read face (downstream drives rd_en)
   workCompGenReqValid <= wcOutValid;
   workCompGenReqData  <= wcOutDout;
   wcOutRdEn           <= workCompGenReqRdEn;

   ---------------------------------------------------------------------------
   -- 35 SURF Fifo instances (all FWFT / sync / block; cleared by fifoClr).
   -- Minimal port map (surf.Fifo unmapped ports carry their entity defaults —
   -- same instantiation style as the emitted CountCF/RespHandleSq children).
   ---------------------------------------------------------------------------
   U_SupportedReqOpCodeCheckQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W01_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f01WrEn, din => f01Din,
                not_full => f01NotFull, rd_clk => clk, rd_en => f01RdEn,
                dout => f01Dout, valid => f01Valid);
   U_ReqOpCodeSeqCheckQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W02_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f02WrEn, din => f02Din,
                not_full => f02NotFull, rd_clk => clk, rd_en => f02RdEn,
                dout => f02Dout, valid => f02Valid);
   U_RnrCheckQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W03_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f03WrEn, din => f03Din,
                not_full => f03NotFull, rd_clk => clk, rd_en => f03RdEn,
                dout => f03Dout, valid => f03Valid);
   U_RnrTriggerQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W04_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f04WrEn, din => f04Din,
                not_full => f04NotFull, rd_clk => clk, rd_en => f04RdEn,
                dout => f04Dout, valid => f04Valid);
   U_QpAccPermCheckQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W05_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f05WrEn, din => f05Din,
                not_full => f05NotFull, rd_clk => clk, rd_en => f05RdEn,
                dout => f05Dout, valid => f05Valid);
   U_ReqPermInfoBuildQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W06_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f06WrEn, din => f06Din,
                not_full => f06NotFull, rd_clk => clk, rd_en => f06RdEn,
                dout => f06Dout, valid => f06Valid);
   U_ReqPermQueryTmpQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W07_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f07WrEn, din => f07Din,
                not_full => f07NotFull, rd_clk => clk, rd_en => f07RdEn,
                dout => f07Dout, valid => f07Valid);
   U_ReqPermQueryQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W08_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f08WrEn, din => f08Din,
                not_full => f08NotFull, rd_clk => clk, rd_en => f08RdEn,
                dout => f08Dout, valid => f08Valid);
   U_ReqPermCheckQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W09_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f09WrEn, din => f09Din,
                not_full => f09NotFull, rd_clk => clk, rd_en => f09RdEn,
                dout => f09Dout, valid => f09Valid);
   U_ReadCacheInsertQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W10_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f10WrEn, din => f10Din,
                not_full => f10NotFull, rd_clk => clk, rd_en => f10RdEn,
                dout => f10Dout, valid => f10Valid);
   U_DupReadReqPermQueryQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W11_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f11WrEn, din => f11Din,
                not_full => f11NotFull, rd_clk => clk, rd_en => f11RdEn,
                dout => f11Dout, valid => f11Valid);
   U_DupReadReqPermCheckQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W12_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f12WrEn, din => f12Din,
                not_full => f12NotFull, rd_clk => clk, rd_en => f12RdEn,
                dout => f12Dout, valid => f12Valid);
   U_ReqAddrCalcQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W13_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f13WrEn, din => f13Din,
                not_full => f13NotFull, rd_clk => clk, rd_en => f13RdEn,
                dout => f13Dout, valid => f13Valid);
   U_ReqRemainingLenCalcQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W14_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f14WrEn, din => f14Din,
                not_full => f14NotFull, rd_clk => clk, rd_en => f14RdEn,
                dout => f14Dout, valid => f14Valid);
   U_ReqEnoughDmaSpaceQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W15_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f15WrEn, din => f15Din,
                not_full => f15NotFull, rd_clk => clk, rd_en => f15RdEn,
                dout => f15Dout, valid => f15Valid);
   U_ReqTotalLenCalcQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W16_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f16WrEn, din => f16Din,
                not_full => f16NotFull, rd_clk => clk, rd_en => f16RdEn,
                dout => f16Dout, valid => f16Valid);
   U_ReqLenCheckQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W17_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f17WrEn, din => f17Din,
                not_full => f17NotFull, rd_clk => clk, rd_en => f17RdEn,
                dout => f17Dout, valid => f17Valid);
   U_IssuePayloadConReqQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W18_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f18WrEn, din => f18Din,
                not_full => f18NotFull, rd_clk => clk, rd_en => f18RdEn,
                dout => f18Dout, valid => f18Valid);
   U_IssuePayloadGenReqQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W19_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f19WrEn, din => f19Din,
                not_full => f19NotFull, rd_clk => clk, rd_en => f19RdEn,
                dout => f19Dout, valid => f19Valid);
   U_IssueAtomicReqQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W20_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f20WrEn, din => f20Din,
                not_full => f20NotFull, rd_clk => clk, rd_en => f20RdEn,
                dout => f20Dout, valid => f20Valid);
   U_RespGenCheck4NormalCaseQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W21_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f21WrEn, din => f21Din,
                not_full => f21NotFull, rd_clk => clk, rd_en => f21RdEn,
                dout => f21Dout, valid => f21Valid);
   U_RespGenCheck4OtherCasesQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W22_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f22WrEn, din => f22Din,
                not_full => f22NotFull, rd_clk => clk, rd_en => f22RdEn,
                dout => f22Dout, valid => f22Valid);
   U_RespCountQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W23_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f23WrEn, din => f23Din,
                not_full => f23NotFull, rd_clk => clk, rd_en => f23RdEn,
                dout => f23Dout, valid => f23Valid);
   U_RespPsnAndMsnQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W24_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f24WrEn, din => f24Din,
                not_full => f24NotFull, rd_clk => clk, rd_en => f24RdEn,
                dout => f24Dout, valid => f24Valid);
   U_WaitAtomicRespQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W25_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f25WrEn, din => f25Din,
                not_full => f25NotFull, rd_clk => clk, rd_en => f25RdEn,
                dout => f25Dout, valid => f25Valid);
   U_AtomicCacheInsertQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W26_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f26WrEn, din => f26Din,
                not_full => f26NotFull, rd_clk => clk, rd_en => f26RdEn,
                dout => f26Dout, valid => f26Valid);
   U_RespCheckQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W27_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f27WrEn, din => f27Din,
                not_full => f27NotFull, rd_clk => clk, rd_en => f27RdEn,
                dout => f27Dout, valid => f27Valid);
   U_DupAtomicReqPermQueryQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W28_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f28WrEn, din => f28Din,
                not_full => f28NotFull, rd_clk => clk, rd_en => f28RdEn,
                dout => f28Dout, valid => f28Valid);
   U_DupAtomicReqPermCheckQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W29_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f29WrEn, din => f29Din,
                not_full => f29NotFull, rd_clk => clk, rd_en => f29RdEn,
                dout => f29Dout, valid => f29Valid);
   U_RespHeaderGenQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W30_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f30WrEn, din => f30Din,
                not_full => f30NotFull, rd_clk => clk, rd_en => f30RdEn,
                dout => f30Dout, valid => f30Valid);
   U_PendingRespQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W31_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f31WrEn, din => f31Din,
                not_full => f31NotFull, rd_clk => clk, rd_en => f31RdEn,
                dout => f31Dout, valid => f31Valid);
   U_WorkCompReqQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => W32_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => f32WrEn, din => f32Din,
                not_full => f32NotFull, rd_clk => clk, rd_en => f32RdEn,
                dout => f32Dout, valid => f32Valid);
   -- output FIFOs
   U_WorkCompGenReqOutQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => WCW_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => wcOutWrEn, din => wcOutDin,
                not_full => wcOutNotFull, rd_clk => clk, rd_en => wcOutRdEn,
                dout => wcOutDout, valid => wcOutValid);
   U_RespHeaderOutQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => RHW_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => rhOutWrEn, din => rhOutDin,
                not_full => rhOutNotFull, rd_clk => clk, rd_en => rhOutRdEn,
                dout => rhOutDout, valid => rhOutValid);
   U_PsnRespOutQ : entity surf.Fifo
      generic map (TPD_G => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
                   GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
                   DATA_WIDTH_G => PSW_C, ADDR_WIDTH_G => 4)
      port map (rst => fifoClr, wr_clk => clk, wr_en => psnOutWrEn, din => psnOutDin,
                not_full => psnOutNotFull, rd_clk => clk, rd_en => psnOutRdEn,
                dout => psnOutDout, valid => psnOutValid);

   ---------------------------------------------------------------------------
   -- Child entity instances
   ---------------------------------------------------------------------------
   -- CountCF child (RQ-02): pendingDestReadAtomicReqCnt <- mkCountCF(0)
   U_PendingDestReadAtomicReqCnt : entity surf.CountCF
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => '1',
         RST_ASYNC_G       => false,
         WIDTH_G           => 8,               -- PendingReqCnt
         RESET_VAL_G       => "00000000",      -- mkCountCF(0)
         FIFO_ADDR_WIDTH_G => 4)
      port map (
         clk        => clk,
         rst        => fifoClr,                -- rst OR isReset (write/clear path handled inside)
         incrOneEn  => ccIncrEn,
         incrOneRdy => ccIncrRdy,
         decrOneEn  => ccDecrEn,
         decrOneRdy => ccDecrRdy,
         writeEn    => ccWriteEn,
         writeVal   => ccWriteVal,
         cntOut     => ccCnt);

   -- AtomicSrv child (RQ-06 STUB): mkAtomicSrv(cntrlStatus) — CAS/FetchAdd NOT implemented
   U_AtomicSrv : entity surf.AtomicSrvConAndGen
      generic map (
         TPD_G        => TPD_G,
         REQ_WIDTH_G  => 245,                  -- AtomicOpReq
         RESP_WIDTH_G => 116)                  -- AtomicOpResp
      port map (
         clk       => clk,
         rst       => fifoClr,
         reqValid  => atomicReqValid,
         reqData   => atomicReqData,
         reqRdy    => atomicReqRdy,
         respValid => atomicRespValid,
         respData  => atomicRespData,
         respRdy   => atomicRespRdEn);

   -- CombineHeaderAndPayload child: drives rdmaRespDataStreamPipeOut.
   -- header  <- respHeaderOutQ read side; psn <- psnRespOutQ read side;
   -- payload <- payloadGenerator.payloadDataStreamPipeOut (external).
   U_RdmaRespPipeOut : entity surf.CombineHeaderAndPayload
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         RST_ASYNC_G    => false)
      port map (
         clk                => clk,
         rst                => rst,
         clearAllI          => isReset,
         headerPipeInValid  => rhOutValid,
         headerPipeInData   => rhOutDout,
         headerPipeInRdEn   => rhOutRdEn,
         payloadPipeInValid => payloadDataStreamValid,
         payloadPipeInData  => payloadDataStreamData,
         payloadPipeInRdEn  => payloadDataStreamRdEn,
         psnPipeInValid     => psnOutValid,
         psnPipeInData      => psnOutDout,
         psnPipeInRdEn      => psnOutRdEn,
         dataStreamOutValid => rdmaRespDataStreamValid,
         dataStreamOutData  => rdmaRespDataStreamData,
         dataStreamOutRdEn  => rdmaRespDataStreamRdEn);

   ---------------------------------------------------------------------------
   -- Combinatorial process
   --   NOTE: VHDL-2008 process(all) is used deliberately — this entity reads
   --   ~150 signals across 9 datapath fill-in phases; an explicit list would be
   --   a recurring source of simulation/synthesis mismatch as stages are filled.
   ---------------------------------------------------------------------------
   comb : process (all) is
      variable v : RegType;
      -- Block-C combinational error state (BSV: hasErrHappened / inErrorState)
      variable hasErrHappened : sl;
      variable inErrorState   : sl;
      -- convenience: pipeline worker enable (BSV workers fire on isNonErr||isERR)
      variable workerEnable   : boolean;
      -- Pre-stage / pipeline datapath temporaries (Phase 1)
      variable bthV        : slv(95 downto 0);
      variable opcodeV     : slv(4 downto 0);
      variable transV      : slv(2 downto 0);
      variable psnV        : slv(23 downto 0);
      variable dlenV       : slv(31 downto 0);
      variable reqPktInfoV : slv(160 downto 0);
      variable reqStatusV  : slv(3 downto 0);
      variable isReadReqV  : boolean;
      variable isAccPassV  : boolean;
      variable respPktNumV : slv(24 downto 0);   -- PktNum
      variable totRespPktNumV : slv(24 downto 0);
      variable isOnlyRespPktV : boolean;
      variable curEPSNv    : slv(23 downto 0);
      variable nextEPSNv   : slv(23 downto 0);
      variable nextPsnV    : slv(23 downto 0);
      variable endPsnV     : slv(23 downto 0);
      variable epochV      : sl;
      variable preOpCodeV  : slv(4 downto 0);
      variable maybeRecvReqV : slv(216 downto 0);   -- Maybe#RecvReq (tag @216)
      -- Phase 2 (perm-check build/query)
      variable permCheckReqV : slv(266 downto 0);   -- PermCheckReq
      variable rethV         : slv(127 downto 0);    -- RETH
      variable pdHandlerV     : slv(31 downto 0);    -- HandlerPD
      variable recvReqV      : slv(215 downto 0);    -- RecvReq
      variable atomicVaV     : slv(63 downto 0);      -- AtomicEth.va
      variable isZeroPayloadV : sl;
      variable doPermReqV    : boolean;
      variable expectPermV   : sl;
      variable doDupCacheV   : boolean;   -- Phase 3: gate insertRead / searchReadReq
      variable expectDupV    : sl;        -- Phase 3: expectDupReadCheckResp carry
      variable dupStartV     : sl;        -- Phase 3: DupReadReqStartState (0=FROM_FIRST)
      -- Phase 4: DMA addr/len arithmetic (stages 12-16)
      variable isSendWrV     : boolean;   -- isSendReq or isWriteReq
      variable curDmaAddrV   : slv(63 downto 0);
      variable nextDmaAddrV  : slv(63 downto 0);
      variable sendPktNumV   : slv(24 downto 0);
      variable remLenV       : slv(31 downto 0);
      variable totLenV       : slv(31 downto 0);
      variable pktPayLenV    : slv(12 downto 0);   -- PktLen
      variable enoughChkV    : slv(3 downto 0);    -- EnoughDmaSpaceCheck (only/first/mid/last)
      variable lastOnlyEnV   : sl;                 -- lastOrOnlyPktHasEnoughDmaSpace
      variable firstMidEnV   : sl;                 -- firstOrMidPktHasEnoughDmaSpace
      variable enoughSpaceV  : sl;
      variable isLastZeroV   : sl;                 -- isLastPayloadLenZero
      variable reqLenResV    : slv(129 downto 0);  -- ReqLenCheckResult
      variable writeMatchV   : boolean;
      -- Phase 5: PayloadConReq / PayloadGenReq / AtomicOpReq build (stages 17-19)
      variable dmaWrMetaV    : slv(128 downto 0);   -- DmaWriteMetaData
      variable dmaRdMetaV    : slv(194 downto 0);   -- DmaReadMetaData
      variable respGenV      : slv(72 downto 0);    -- RespPktGenInfo
      variable hasReqStErrV  : sl;
      variable doConPutV     : boolean;             -- stage 17 payloadConReqPort.put fired
      variable doGenReqV     : boolean;             -- stage 18 payloadGenerator.request.put fired
      variable doAtomicReqV  : boolean;             -- stage 19 atomicSrv.request.put fired
      variable expRdPayV     : sl;                  -- expectReadRespPayload
      variable expAtomicV    : sl;                  -- expectAtomicRespOrig
      -- Phase 6: response-gen decision + response-packet loop (stages 20-22)
      variable qpHasRespV    : boolean;             -- qpNeedGenResp(bth.trans)
      variable shouldGenRespV : sl;
      variable reloadCntV    : boolean;             -- reloadPendingWorkReqCnt
      variable decrCntV      : boolean;             -- decrPendingWorkReqCnt
      variable genEvenNoAckV : boolean;             -- shouldGenRespEvenNoAckReq
      variable isFirstRespV  : boolean;             -- isFirstOrOnlyRespPkt (this cycle)
      variable isLastRespV   : boolean;             -- isLastOrOnlyRespPkt (this cycle)
      variable remRespPktV   : slv(24 downto 0);    -- remainingRespPktNum
      variable deqRespV      : boolean;             -- respCountQ.deq this cycle
      -- Phase 7: resp PSN/MSN update + atomic resp / atomic-cache insert / read-resp err (stages 23-26)
      variable respPSNv           : slv(23 downto 0);   -- respPSN (stage 23)
      variable msnV               : slv(23 downto 0);   -- MSN (stage 23)
      variable isFirstOrOnlyRespV : sl;                 -- isFirstOrOnlyRespPkt (stage 23, may clear)
      variable respPktHdrV        : slv(49 downto 0);   -- RespPktHeaderInfo
      variable doAtomicRespV      : boolean;            -- stage 24 atomicSrv.response.get fired
      variable atomicAckOrigV     : slv(64 downto 0);   -- Maybe#Long (stage 24)
      variable doInsertAtomicV    : boolean;            -- stage 25 insertAtomic fired
      variable atomicEthV         : slv(223 downto 0);  -- AtomicEth (stage 25)
      variable atomicCacheItemV   : slv(316 downto 0);  -- AtomicCacheItem (stage 25)
      variable doPayloadRespV     : boolean;            -- stage 26 payloadGen.response.get fired
      variable hasDmaRdErrV       : sl;                 -- hasDmaReadRespErr (stage 26)
      variable expectReadV        : sl;                 -- expectReadRespPayload (stage 26)
      -- Phase 8: dup-atomic query/check + response-header gen + resp-pkt emit (stages 27-30)
      variable doSearchAtomicV    : boolean;            -- stage 27 searchAtomicReq fired
      variable reqStatus28V       : slv(3 downto 0);    -- stage 28 reqStatus (may -> DISCARD)
      variable shouldGen28V       : sl;                 -- stage 28 shouldGenResp
      variable atomicAck28V       : slv(64 downto 0);   -- stage 28 atomicAckOrig (Maybe#Long)
      variable reqStatus29V       : slv(3 downto 0);    -- stage 29 reqStatus (may -> RMT_OP/DISCARD)
      variable shouldGen29V       : sl;                 -- stage 29 shouldGenResp
      variable hasErrRespGenV     : sl;                 -- stage 29 hasErrRespGen (Block C sticky)
      variable maybeHeaderV       : slv(593 downto 0);  -- stage 29 Maybe#HeaderRDMA
      variable isOnlyReadResp29V  : boolean;            -- stage 29 isOnlyRespPkt & isReadReq
      variable doHeaderEnqV       : boolean;            -- stage 30 header/psn enq
      -- Phase 9 (stage 31 genWorkCompRQ)
      variable reqStatus31V       : slv(3 downto 0);    -- workCompReqQ reqStatus
      variable reqOp31V           : slv(4 downto 0);    -- bth.opcode
      variable trans31V           : slv(2 downto 0);    -- bth.trans
      variable wcStatus31V        : slv(5 downto 0);    -- [5]=valid,[4:0]=WorkCompStatus
      variable immDt31V           : slv(31 downto 0);   -- extractImmDt
      variable ieth31V            : slv(31 downto 0);   -- extractIETH (rkey)
      variable immM31V            : slv(32 downto 0);   -- Maybe#IMM
      variable rkeyM31V           : slv(32 downto 0);   -- Maybe#RKEY
      variable doDecr31V          : boolean;            -- pendingDestReadAtomicReqCnt.decrOne
      variable doWcEnq31V         : boolean;            -- workCompGenReqOutQ.enq
      -- Phase err (SUB-FSM C errFlushRecvReq): synthetic flush-RR token fields
      variable flushPmdV          : slv(648 downto 0);  -- synthetic RdmaPktMetaData
      variable flushPktInfoV      : slv(160 downto 0);  -- synthetic RdmaReqPktInfo
   begin
      v := r;

      ---------------------------------------------------------------------
      -- Default drives (Moore: everything computed into v / driven low)
      ---------------------------------------------------------------------
      f01WrEn <= '0'; f01RdEn <= '0'; f01Din <= (others => '0');
      f02WrEn <= '0'; f02RdEn <= '0'; f02Din <= (others => '0');
      f03WrEn <= '0'; f03RdEn <= '0'; f03Din <= (others => '0');
      f04WrEn <= '0'; f04RdEn <= '0'; f04Din <= (others => '0');
      f05WrEn <= '0'; f05RdEn <= '0'; f05Din <= (others => '0');
      f06WrEn <= '0'; f06RdEn <= '0'; f06Din <= (others => '0');
      f07WrEn <= '0'; f07RdEn <= '0'; f07Din <= (others => '0');
      f08WrEn <= '0'; f08RdEn <= '0'; f08Din <= (others => '0');
      f09WrEn <= '0'; f09RdEn <= '0'; f09Din <= (others => '0');
      f10WrEn <= '0'; f10RdEn <= '0'; f10Din <= (others => '0');
      f11WrEn <= '0'; f11RdEn <= '0'; f11Din <= (others => '0');
      f12WrEn <= '0'; f12RdEn <= '0'; f12Din <= (others => '0');
      f13WrEn <= '0'; f13RdEn <= '0'; f13Din <= (others => '0');
      f14WrEn <= '0'; f14RdEn <= '0'; f14Din <= (others => '0');
      f15WrEn <= '0'; f15RdEn <= '0'; f15Din <= (others => '0');
      f16WrEn <= '0'; f16RdEn <= '0'; f16Din <= (others => '0');
      f17WrEn <= '0'; f17RdEn <= '0'; f17Din <= (others => '0');
      f18WrEn <= '0'; f18RdEn <= '0'; f18Din <= (others => '0');
      f19WrEn <= '0'; f19RdEn <= '0'; f19Din <= (others => '0');
      f20WrEn <= '0'; f20RdEn <= '0'; f20Din <= (others => '0');
      f21WrEn <= '0'; f21RdEn <= '0'; f21Din <= (others => '0');
      f22WrEn <= '0'; f22RdEn <= '0'; f22Din <= (others => '0');
      f23WrEn <= '0'; f23RdEn <= '0'; f23Din <= (others => '0');
      f24WrEn <= '0'; f24RdEn <= '0'; f24Din <= (others => '0');
      f25WrEn <= '0'; f25RdEn <= '0'; f25Din <= (others => '0');
      f26WrEn <= '0'; f26RdEn <= '0'; f26Din <= (others => '0');
      f27WrEn <= '0'; f27RdEn <= '0'; f27Din <= (others => '0');
      f28WrEn <= '0'; f28RdEn <= '0'; f28Din <= (others => '0');
      f29WrEn <= '0'; f29RdEn <= '0'; f29Din <= (others => '0');
      f30WrEn <= '0'; f30RdEn <= '0'; f30Din <= (others => '0');
      f31WrEn <= '0'; f31RdEn <= '0'; f31Din <= (others => '0');
      f32WrEn <= '0'; f32RdEn <= '0'; f32Din <= (others => '0');
      wcOutWrEn  <= '0'; wcOutDin  <= (others => '0');
      rhOutWrEn  <= '0'; rhOutDin  <= (others => '0');
      psnOutWrEn <= '0'; psnOutDin <= (others => '0');

      pktMetaDeq <= '0';
      recvReqDeq <= '0';
      incEpoch   <= '0';
      setRespPktNumValid <= '0'; setRespPktNumData <= (others => '0');
      setEPSNValid <= '0'; setEPSNData <= (others => '0');
      setPreReqOpCodeValid <= '0'; setPreReqOpCodeData <= (others => '0');
      restoreValid <= '0'; restorePreOpCodeData <= (others => '0'); restorePsnData <= (others => '0');
      setPermCheckReqValid <= '0'; setPermCheckReqData <= (others => '0');
      setNextDmaWriteAddrValid   <= '0'; setNextDmaWriteAddrData   <= (others => '0');
      setSendWriteReqPktNumValid <= '0'; setSendWriteReqPktNumData <= (others => '0');
      setRemainingDmaWriteLenValid <= '0'; setRemainingDmaWriteLenData <= (others => '0');
      setTotalDmaWriteLenValid   <= '0'; setTotalDmaWriteLenData   <= (others => '0');
      setCurRespPSNValid <= '0'; setCurRespPSNData <= (others => '0');
      setMSNValid <= '0'; setMSNData <= (others => '0');
      payloadConReqValid <= '0'; payloadConReqData <= (others => '0');
      permReqValid  <= '0'; permReqData  <= (others => '0'); permRespGetEn <= '0';
      payloadGenReqValid <= '0'; payloadGenReqData <= (others => '0'); payloadGenRespGetEn <= '0';
      insertReadValid <= '0'; insertReadData <= (others => '0');
      searchReadReqValid <= '0'; searchReadReqData <= (others => '0'); searchReadRespGetEn <= '0';
      insertAtomicValid <= '0'; insertAtomicData <= (others => '0');
      searchAtomicReqValid <= '0'; searchAtomicReqData <= (others => '0'); searchAtomicRespGetEn <= '0';
      dupCacheClear <= isReset;
      atomicReqValid <= '0'; atomicReqData <= (others => '0'); atomicRespRdEn <= '0';
      ccIncrEn <= '0'; ccDecrEn <= '0'; ccWriteEn <= '0'; ccWriteVal <= (others => '0');

      -- Block C combinational error state (BSV lines 523-524)
      hasErrHappened := r.hasReqStatusErr or r.hasDmaReadRespErr;
      inErrorState   := (isNonErr and hasErrHappened) or isERR;
      workerEnable   := (isNonErr = '1') or (isERR = '1');

      --------------------------------------------------------------------
      -- 32-STAGE PIPELINE (conflict-free workers; fire on isNonErr||isERR
      -- with input notEmpty + output notFull). Datapath transforms are
      -- filled per phase; Phase-0 wires handshake/back-pressure only and
      -- leaves each output FIFO din at zero (see file header).
      -- The triggerRNR retry-start write (stage 4) is placed here, BEFORE
      -- the retry-rule block, to honour the CReg(2) same-cycle forward
      -- (OQ-FSM-RHR-02).
      --------------------------------------------------------------------
      -- Stage 1 : checkSupportedReqOpCode (f01 -> f02)   ReqHandleRQ.bsv:899
      -- f01 = tuple4(pmd[837:189], reqStatus[188:185], reqPktInfo[184:24], curEPSN[23:0]).
      -- reqPktInfo[b]=f01[24+b]: bth.opcode=[157:153] bth.trans=[160:158] bth.psn=[88:65] epoch=[64].
      if (workerEnable and f01Valid = '1' and f02NotFull = '1') then
         f01RdEn <= '1'; f02WrEn <= '1';
         reqPktInfoV := f01Dout(184 downto 24);
         reqStatusV  := f01Dout(188 downto 185);
         opcodeV     := reqPktInfoV(157 downto 153);
         transV      := reqPktInfoV(160 downto 158);
         epochV      := reqPktInfoV(64);
         curEPSNv    := f01Dout(23 downto 0);
         if (epochV = getEpoch) then
            if (hasErrHappened = '0') then
               if (reqStatusV = ST_SEQ_ERR_C) then
                  reqPktInfoV(88 downto 65) := curEPSNv;                 -- bth.psn = curEPSN
               elsif (not isSupportedReqOp(getTypeQP, opcodeV)) then
                  if (reqStatusV = ST_NORMAL_C) then
                     reqStatusV := invReqStatus(transV);
                  elsif (reqStatusV = ST_DUP_C) then
                     reqStatusV := ST_DISCARD_C;
                  end if;
               end if;
            end if;
         else
            reqStatusV := ST_DISCARD_C;
         end if;
         f02Din <= f01Dout(837 downto 189) & reqStatusV & reqPktInfoV;   -- tuple3
      end if;
      -- Stage 2 : checkNormalReqOpCodeSeq (f02 -> f03)   ReqHandleRQ.bsv:952
      -- f02 = tuple3(pmd[813:165], reqStatus[164:161], reqPktInfo[160:0]).
      if (workerEnable and f02Valid = '1' and f03NotFull = '1') then
         f02RdEn <= '1'; f03WrEn <= '1';
         reqPktInfoV := f02Dout(160 downto 0);
         reqStatusV  := f02Dout(164 downto 161);
         opcodeV     := reqPktInfoV(157 downto 153);
         transV      := reqPktInfoV(160 downto 158);
         epochV      := reqPktInfoV(64);
         preOpCodeV  := getPreReqOpCode;                                 -- enqueued as-read
         if (epochV = getEpoch) then
            if (reqStatusV = ST_NORMAL_C and hasErrHappened = '0') then
               if (checkNormalSeq(preOpCodeV, opcodeV)) then
                  setPreReqOpCodeValid <= '1';
                  setPreReqOpCodeData  <= opcodeV;
               else
                  reqStatusV := invReqStatus(transV);
               end if;
            end if;
         else
            reqStatusV := ST_DISCARD_C;
         end if;
         f03Din <= f02Dout(813 downto 165) & reqStatusV & reqPktInfoV & preOpCodeV;   -- tuple4
      end if;
      -- Stage 3 : checkRNR (f03 -> f04)                  ReqHandleRQ.bsv:999
      -- f03 = tuple4(pmd[818:170], reqStatus[169:166], reqPktInfo[165:5], preOpCode[4:0]).
      -- pmd[i]=f03[170+i]: isZeroPayloadLen=pmd[627]=f03[797].
      if (workerEnable and f03Valid = '1' and f04NotFull = '1') then
         f03RdEn <= '1'; f04WrEn <= '1';
         reqPktInfoV := f03Dout(165 downto 5);
         reqStatusV  := f03Dout(169 downto 166);
         preOpCodeV  := f03Dout(4 downto 0);
         epochV      := reqPktInfoV(64);
         psnV        := reqPktInfoV(88 downto 65);                       -- bth.psn
         maybeRecvReqV := (others => '0');                               -- tagged Invalid
         if (epochV = getEpoch) then
            -- Duplicate requests do not use RecvReq
            if (reqStatusV = ST_NORMAL_C and hasErrHappened = '0' and
                ((reqPktInfoV(5) = '1' and reqPktInfoV(14) = '1')        -- isFirstOrOnlyPkt & isSendReq
                 or reqPktInfoV(12) = '1')) then                         -- isWriteImmReq
               if (recvReqValid = '1') then
                  maybeRecvReqV := '1' & recvReqData;                    -- tagged Valid recvReq
                  recvReqDeq <= '1';
               else
                  reqStatusV := ST_RNR_C;
                  restoreValid         <= '1';                           -- restorePreReqOpCodeAndEPSN
                  restorePreOpCodeData <= preOpCodeV;
                  restorePsnData       <= psnV;
               end if;
            elsif (reqStatusV = ST_ERR_FLUSH_RR_C) then
               if (recvReqValid = '1') then
                  maybeRecvReqV := '1' & recvReqData;
                  recvReqDeq <= '1';
               end if;
            end if;
         else
            reqStatusV := ST_DISCARD_C;
         end if;
         f04Din <= f03Dout(818 downto 170) & reqStatusV & reqPktInfoV & preOpCodeV & maybeRecvReqV;  -- tuple5
      end if;
      -- Stage 4 : triggerRNR (f04 -> f05)   ReqHandleRQ.bsv:1094
      -- f04 = tuple5(pmd[1035:387], reqStatus[386:383], reqPktInfo[382:222],
      --   preOpCode[221:217], maybeRecvReq[216:0]). f05 = tuple4 drops preOpCode.
      -- retryStartReg[0] write (v.retryStart*) is placed here, BEFORE the retry-rule
      -- block, so retryStart's port-1 read sees it this cycle (CReg(2), OQ-FSM-RHR-02).
      if (workerEnable and f04Valid = '1' and f05NotFull = '1') then
         f04RdEn <= '1'; f05WrEn <= '1';
         reqPktInfoV := f04Dout(382 downto 222);
         reqStatusV  := f04Dout(386 downto 383);
         epochV      := reqPktInfoV(64);
         v.retryStartValid := '0';                          -- retryStartReg[0] <= Invalid (default)
         if (epochV = getEpoch) then
            if (hasErrHappened = '0') then
               if (reqStatusV = ST_RNR_C) then
                  incEpoch          <= '1';
                  v.retryStartValid := '1';
                  v.retryStartState := RQ_RNR_RETRY_FLUSH_S;
               elsif (reqStatusV = ST_SEQ_ERR_C) then
                  incEpoch          <= '1';
                  v.retryStartValid := '1';
                  v.retryStartState := RQ_SEQ_RETRY_FLUSH_S;
               end if;
            end if;
         else
            reqStatusV := ST_DISCARD_C;
         end if;
         v.minRnrTimer := getMinRnrTimer;
         f05Din <= f04Dout(1035 downto 387) & reqStatusV & reqPktInfoV & f04Dout(216 downto 0);  -- tuple4
      end if;
      -- Stage 5 : checkQpAccPermAndReadAtomicReqNum (f05 -> f06) + CountCF incrOne
      --           (BSV checkQpAccPermAndReadAtomicReqNum @1144)
      -- f05/f06 tuple4: pmd[1030:382] reqStatus[381:378] reqPktInfo[377:217] maybeRecvReq[216:0]
      if (workerEnable and f05Valid = '1' and f06NotFull = '1') then
         f05RdEn <= '1'; f06WrEn <= '1';
         reqPktInfoV := f05Dout(377 downto 217);
         reqStatusV  := f05Dout(381 downto 378);
         transV      := reqPktInfoV(160 downto 158);
         if (reqStatusV = ST_NORMAL_C and hasErrHappened = '0') then
            if (reqPktInfoV(11) = '1' or reqPktInfoV(10) = '1') then   -- isReadReq or isAtomicReq
               ccIncrEn <= '1';                                        -- pendingDestReadAtomicReqCnt.incrOne
               if (unsigned(ccCnt) >= unsigned(getPendingDestReadAtomicReqNum)) then
                  reqStatusV := invReqStatus(transV);                  -- getInvReqStatusByTransType
               end if;
            end if;
         end if;
         f06Din <= f05Dout(1030 downto 382) & reqStatusV & reqPktInfoV & f05Dout(216 downto 0);
      end if;
      -- Stage 6a : buildPermCheckReq4SendWrite (f06 -> f07)  (BSV @1197)
      -- The commented-out "buildPermCheckReq" (BSV @1404) is NOT in the design; the
      -- perm-build flow is the linear 6a -> 6b chain (send/write here, read/atomic in 6b).
      -- f07 tuple6: pmd[1425:777] reqStatus[776:773] permCheckReq[772:506]
      --   reqPktInfo[505:345] reth[344:217] maybeRecvReq[216:0]
      if (workerEnable and f06Valid = '1' and f07NotFull = '1') then
         f06RdEn <= '1'; f07WrEn <= '1';
         reqPktInfoV    := f06Dout(377 downto 217);
         reqStatusV     := f06Dout(381 downto 378);
         maybeRecvReqV  := f06Dout(216 downto 0);
         recvReqV       := f06Dout(215 downto 0);
         pdHandlerV     := f06Dout(415 downto 384);          -- pmd.pdHandler = pmd[33:2]
         isZeroPayloadV := f06Dout(1009);                    -- pmd.isZeroPayloadLen = pmd[627]
         rethV          := f06Dout(912 downto 785);          -- RETH = pmd[530:403]
         -- default PermCheckReq (BSV @1216): wrID Invalid, keys/addr/len 0,
         --   localOrRmtKey=True, pdHandler, isZeroDmaLen=True, accFlags=LOCAL_WRITE
         permCheckReqV := (others => '0');
         permCheckReqV(137)          := '1';                 -- localOrRmtKey = True
         permCheckReqV(40 downto 9)  := pdHandlerV;          -- pdHandler
         permCheckReqV(8)            := '1';                 -- isZeroDmaLen = True
         permCheckReqV(7 downto 0)   := ACC_LOCAL_WRITE_C;   -- accFlags
         if (hasErrHappened = '0') then
            if (reqPktInfoV(14) = '1' and reqStatusV = ST_NORMAL_C) then       -- send && normal
               if (reqPktInfoV(5) = '1') then                                   -- isFirstOrOnlyPkt
                  permCheckReqV := (others => '0');
                  permCheckReqV(266)          := '1';                           -- wrID Valid
                  permCheckReqV(265 downto 202) := recvReqV(215 downto 152);    -- wrID = recvReq.id
                  permCheckReqV(201 downto 170) := recvReqV(55 downto 24);      -- lkey = recvReq.lkey
                  permCheckReqV(137)          := '1';                           -- localOrRmtKey = True
                  permCheckReqV(136 downto 73)  := recvReqV(119 downto 56);     -- reqAddr = recvReq.laddr
                  if (isZeroPayloadV = '0') then
                     permCheckReqV(72 downto 41) := recvReqV(151 downto 120);   -- totalLen = recvReq.len
                  end if;
                  permCheckReqV(40 downto 9)  := pdHandlerV;
                  permCheckReqV(8)            := isZeroPayloadV;                 -- isZeroDmaLen
                  permCheckReqV(7 downto 0)   := ACC_LOCAL_WRITE_C;
                  setPermCheckReqValid <= '1';
                  setPermCheckReqData  <= permCheckReqV;
               else
                  permCheckReqV := getPermCheckReq;                             -- continuation packet
               end if;
            elsif (reqPktInfoV(13) = '1' and reqStatusV = ST_NORMAL_C) then     -- write && normal
               if (reqPktInfoV(5) = '1') then                                   -- isFirstOrOnlyPkt
                  permCheckReqV := (others => '0');                             -- wrID Invalid
                  permCheckReqV(169 downto 138) := rethV(63 downto 32);         -- rkey = reth.rkey
                  permCheckReqV(137)          := '0';                           -- localOrRmtKey = False
                  permCheckReqV(136 downto 73)  := rethV(127 downto 64);        -- reqAddr = reth.va
                  permCheckReqV(72 downto 41)  := rethV(31 downto 0);           -- totalLen = reth.dlen
                  permCheckReqV(40 downto 9)  := pdHandlerV;
                  permCheckReqV(8)            := toSl(unsigned(rethV(31 downto 0)) = 0);  -- isZeroRethLen
                  permCheckReqV(7 downto 0)   := ACC_REMOTE_WRITE_C;
                  setPermCheckReqValid <= '1';
                  setPermCheckReqData  <= permCheckReqV;
               else
                  permCheckReqV := getPermCheckReq;                             -- continuation packet
               end if;
               if (reqPktInfoV(12) = '1') then                                  -- isWriteImmReq
                  permCheckReqV(266)          := '1';                           -- wrID Valid
                  permCheckReqV(265 downto 202) := recvReqV(215 downto 152);    -- wrID = recvReq.id
               end if;
            end if;
         end if;
         f07Din <= f06Dout(1030 downto 382) & reqStatusV & permCheckReqV
                   & reqPktInfoV & rethV & maybeRecvReqV;
      end if;
      -- Stage 6b : buildPermCheckReq4ReadAtomic (f07 -> f08)  (BSV @1326)
      -- f08 tuple5: pmd[1208:560] reqStatus[559:556] permCheckReq[555:289]
      --   reqPktInfo[288:128] reth[127:0]
      if (workerEnable and f07Valid = '1' and f08NotFull = '1') then
         f07RdEn <= '1'; f08WrEn <= '1';
         reqPktInfoV   := f07Dout(505 downto 345);
         reqStatusV    := f07Dout(776 downto 773);
         permCheckReqV := f07Dout(772 downto 506);
         rethV         := f07Dout(344 downto 217);
         maybeRecvReqV := f07Dout(216 downto 0);
         recvReqV      := f07Dout(215 downto 0);
         pdHandlerV    := f07Dout(810 downto 779);           -- pmd.pdHandler
         atomicVaV     := f07Dout(1307 downto 1244);         -- AtomicEth.va = pmd[530:467]
         if (hasErrHappened = '0') then
            if (reqPktInfoV(11) = '1' and (reqStatusV = ST_NORMAL_C or reqStatusV = ST_DUP_C)) then  -- read
               permCheckReqV(266)          := '0';                              -- wrID Invalid
               permCheckReqV(169 downto 138) := rethV(63 downto 32);            -- rkey = reth.rkey
               permCheckReqV(137)          := '0';                              -- localOrRmtKey = False
               permCheckReqV(136 downto 73)  := rethV(127 downto 64);           -- reqAddr = reth.va
               permCheckReqV(72 downto 41)  := rethV(31 downto 0);              -- totalLen = reth.dlen
               permCheckReqV(40 downto 9)  := pdHandlerV;
               permCheckReqV(8)            := toSl(unsigned(rethV(31 downto 0)) = 0);
               permCheckReqV(7 downto 0)   := ACC_REMOTE_READ_C;
            elsif (reqPktInfoV(10) = '1' and reqStatusV = ST_NORMAL_C) then     -- atomic
               permCheckReqV(266)          := '0';                              -- wrID Invalid
               permCheckReqV(169 downto 138) := f07Dout(1243 downto 1212);      -- rkey = AtomicEth.rkey = pmd[466:435]
               permCheckReqV(137)          := '0';                              -- localOrRmtKey = False
               permCheckReqV(136 downto 73)  := atomicVaV;                      -- reqAddr = atomicEth.va
               permCheckReqV(72 downto 41)  := ATOMIC_WORK_REQ_LEN_C;           -- totalLen = ATOMIC_WORK_REQ_LEN
               permCheckReqV(40 downto 9)  := pdHandlerV;
               permCheckReqV(8)            := '0';                              -- isZeroDmaLen = False
               permCheckReqV(7 downto 0)   := ACC_REMOTE_ATOMIC_C;
            end if;
         end if;
         if (reqStatusV = ST_ERR_FLUSH_RR_C) then
            if (maybeRecvReqV(216) = '1') then                                  -- Valid recvReq
               permCheckReqV(266)          := '1';                              -- wrID Valid
               permCheckReqV(265 downto 202) := recvReqV(215 downto 152);       -- wrID = recvReq.id
               permCheckReqV(201 downto 170) := recvReqV(55 downto 24);         -- lkey = recvReq.lkey
               permCheckReqV(136 downto 73)  := recvReqV(119 downto 56);        -- reqAddr = recvReq.laddr
               permCheckReqV(72 downto 41)  := recvReqV(151 downto 120);        -- totalLen = recvReq.len
            end if;
         end if;
         f08Din <= f07Dout(1425 downto 777) & reqStatusV & permCheckReqV
                   & reqPktInfoV & rethV;
      end if;
      -- Stage 7 : queryPerm4NormalReq (f08 -> f09) + permCheckSrv.request.put (BSV @1646)
      -- f09 tuple6: pmd[1209:561] reqStatus[560:557] permCheckReq[556:290]
      --   reqPktInfo[289:129] reth[128:1] expectPermCheckResp[0]
      -- The permCheckSrv.request.put is conditional (inside the if); the rule fires
      -- (deq/enq) even when not putting, so gate on permReqReady only when doPermReq.
      reqPktInfoV   := f08Dout(288 downto 128);
      permCheckReqV := f08Dout(555 downto 289);
      reqStatusV    := f08Dout(559 downto 556);
      doPermReqV := (reqPktInfoV(5) = '1') and (hasErrHappened = '0')
                    and (reqStatusV = ST_NORMAL_C) and (permCheckReqV(8) = '0');  -- !isZeroDmaLen
      if (workerEnable and f08Valid = '1' and f09NotFull = '1'
          and (not doPermReqV or permReqReady = '1')) then
         f08RdEn <= '1'; f09WrEn <= '1';
         expectPermV := '0';
         if (doPermReqV) then
            permReqValid <= '1';
            permReqData  <= permCheckReqV;
            expectPermV  := '1';
         end if;
         f09Din <= f08Dout(1208 downto 560) & reqStatusV & permCheckReqV
                   & reqPktInfoV & f08Dout(127 downto 0) & expectPermV;
      end if;
      -- Stage 8 : checkPerm4NormalReq (f09 -> f10) + permCheckSrv.response.get (BSV @1675)
      -- f10 tuple5 (same layout as f08): pmd[1208:560] reqStatus[559:556]
      --   permCheckReq[555:289] reqPktInfo[288:128] reth[127:0]
      -- response.get is conditional on expectPermCheckResp; gate on permRespValid only then.
      expectPermV := f09Dout(0);
      if (workerEnable and f09Valid = '1' and f10NotFull = '1'
          and (expectPermV = '0' or permRespValid = '1')) then
         f09RdEn <= '1'; f10WrEn <= '1';
         reqPktInfoV   := f09Dout(289 downto 129);
         permCheckReqV := f09Dout(556 downto 290);
         reqStatusV    := f09Dout(560 downto 557);
         transV        := reqPktInfoV(160 downto 158);
         atomicVaV     := f09Dout(1091 downto 1028);         -- AtomicEth.va = pmd[530:467]
         if (expectPermV = '1') then
            permRespGetEn <= '1';
            if (permRespData = '1') then                     -- mrCheckResult granted
               if (reqPktInfoV(10) = '1') then               -- isAtomicReq
                  if (atomicVaV(2 downto 0) /= "000") then    -- !isAlignedAtomicAddr
                     reqStatusV := invReqStatus(transV);
                  end if;
               end if;
            else
               reqStatusV := ST_RMT_ACC_C;                   -- RDMA_REQ_ST_RMT_ACC
            end if;
         end if;
         f10Din <= f09Dout(1209 downto 561) & reqStatusV & permCheckReqV
                   & reqPktInfoV & f09Dout(128 downto 1);
      end if;
      -- Stage 9 : insertIntoReadCache (f10 -> f11) + dupReadAtomicCache.insertRead (BSV @1751)
      -- f10/f11 tuple5: pmd[1208:560] reqStatus[559:556] permCheckReq[555:289]
      --   reqPktInfo[288:128] reth[127:0]. ReadCacheItem(176): startPSN=bth.psn[175:152]
      --   endPSN=reqPktInfo.endPSN[151:128] reth[127:0].
      -- insertRead is CONDITIONAL (NORMAL first/only read, no error): fire deq/enq
      -- unconditionally, gate on insertReadReady only when inserting; payload is unchanged.
      reqStatusV  := f10Dout(559 downto 556);
      reqPktInfoV := f10Dout(288 downto 128);
      doDupCacheV := (reqStatusV = ST_NORMAL_C) and (reqPktInfoV(11) = '1')       -- isReadReq
                     and (reqPktInfoV(5) = '1') and (hasErrHappened = '0');       -- isFirstOrOnlyPkt
      if (workerEnable and f10Valid = '1' and f11NotFull = '1'
          and (not doDupCacheV or insertReadReady = '1')) then
         f10RdEn <= '1'; f11WrEn <= '1';
         if (doDupCacheV) then
            insertReadValid <= '1';
            insertReadData  <= f10Dout(216 downto 193)      -- startPSN = bth.psn = reqPktInfo[88:65]
                               & f10Dout(166 downto 143)    -- endPSN   = reqPktInfo[38:15]
                               & f10Dout(127 downto 0);     -- reth
         end if;
         f11Din <= f10Dout;                                 -- tuple5 threaded unchanged
      end if;
      -- Stage 10 : queryPerm4DupReadReq (f11 -> f12) + dupReadAtomicCache.searchReadReq (BSV @1785)
      -- f12 tuple6: f11 payload + expectDupReadCheckResp[0].
      -- searchReadReq is CONDITIONAL (DUP first/only read, no error); expectDup mirrors it.
      reqStatusV  := f11Dout(559 downto 556);
      reqPktInfoV := f11Dout(288 downto 128);
      doDupCacheV := (reqStatusV = ST_DUP_C) and (reqPktInfoV(11) = '1')          -- isReadReq
                     and (reqPktInfoV(5) = '1') and (hasErrHappened = '0');       -- isFirstOrOnlyPkt
      if (workerEnable and f11Valid = '1' and f12NotFull = '1'
          and (not doDupCacheV or searchReadReqReady = '1')) then
         f11RdEn <= '1'; f12WrEn <= '1';
         expectDupV := '0';
         if (doDupCacheV) then
            searchReadReqValid <= '1';
            searchReadReqData  <= f11Dout(216 downto 193)   -- startPSN = bth.psn
                                  & f11Dout(166 downto 143) -- endPSN
                                  & f11Dout(127 downto 0);  -- reth
            expectDupV := '1';
         end if;
         f12Din <= f11Dout & expectDupV;
      end if;
      -- Stage 11 : checkPerm4DupReadReq (f12 -> f13) + dupReadAtomicCache.searchReadResp (BSV @1821)
      -- f12 tuple6: pmd[1209:561] reqStatus[560:557] permCheckReq[556:290]
      --   reqPktInfo[289:129] reth[128:1] expectDup[0].
      -- f13 tuple5: pmd[1081:433] reqStatus[432:429] permCheckReq[428:162]
      --   reqPktInfo[161:1] dupReadReqStartState[0].
      -- searchReadResp Maybe#Tuple3 (242b): valid[241] origReadCacheItem[240:65]
      --   verifiedDupReadAddr(ADDR)[64:1] dupReadReqStart(DupReadReqStartState)[0].
      -- response.get is CONDITIONAL on expectDup; on Valid patch permCheckReq.reqAddr and
      -- carry dupReadReqStart; on Invalid mark DISCARD (drop erroneous duplicate).
      expectDupV := f12Dout(0);
      if (workerEnable and f12Valid = '1' and f13NotFull = '1'
          and (expectDupV = '0' or searchReadRespValid = '1')) then
         f12RdEn <= '1'; f13WrEn <= '1';
         reqStatusV    := f12Dout(560 downto 557);
         permCheckReqV := f12Dout(556 downto 290);
         dupStartV     := '0';                              -- DUP_READ_REQ_START_FROM_FIRST
         if (expectDupV = '1') then
            searchReadRespGetEn <= '1';
            if (searchReadRespData(241) = '1') then          -- tagged Valid
               permCheckReqV(136 downto 73) := searchReadRespData(64 downto 1);  -- reqAddr = verifiedDupReadAddr
               dupStartV                    := searchReadRespData(0);            -- dupReadReqStart
            else
               reqStatusV := ST_DISCARD_C;                   -- discard duplicate w/ error
            end if;
         end if;
         f13Din <= f12Dout(1209 downto 561) & reqStatusV & permCheckReqV
                   & f12Dout(289 downto 129) & dupStartV;
      end if;
      -- Stage 12 : calcNormalSendWriteReqDmaAddr (f13 -> f14 = f13 & curDmaWriteAddr[63:0]) (BSV @1888)
      -- f13 tuple5: pmd[1081:433] reqStatus[432:429] permCheckReq[428:162] reqPktInfo[161:1]
      --   dupReadReqStartState[0].  reqPktInfo.isSendReq=[15] isWriteReq=[14] isOnlyPkt=[10]
      --   isFirstPkt=[9] isMidPkt=[8] isLastPkt=[7]; permCheckReq.reqAddr=f13[298:235].  oneAsPSN=1.
      if (workerEnable and f13Valid = '1' and f14NotFull = '1') then
         f13RdEn <= '1'; f14WrEn <= '1';
         reqStatusV   := f13Dout(432 downto 429);
         isSendWrV    := (f13Dout(15) = '1') or (f13Dout(14) = '1');
         curDmaAddrV  := f13Dout(298 downto 235);       -- default: permCheckReq.reqAddr
         nextDmaAddrV := getNextDmaWriteAddr;            -- default: keep context reg
         sendPktNumV  := getSendWriteReqPktNum;          -- default: keep context reg
         if (isSendWrV) then
            if    (f13Dout(10) = '1') then               -- isOnlyPkt
               nextDmaAddrV := f13Dout(298 downto 235);
               sendPktNumV  := slv(to_unsigned(1, 25));
            elsif (f13Dout(9) = '1') then                -- isFirstPkt
               nextDmaAddrV := addrAddOnePmtu(f13Dout(298 downto 235), getPMTU);
               sendPktNumV  := slv(to_unsigned(1, 25));
            elsif (f13Dout(8) = '1') then                -- isMidPkt
               curDmaAddrV  := getNextDmaWriteAddr;
               nextDmaAddrV := addrAddOnePmtu(getNextDmaWriteAddr, getPMTU);
               sendPktNumV  := slv(unsigned(getSendWriteReqPktNum) + 1);
            elsif (f13Dout(7) = '1') then                -- isLastPkt
               curDmaAddrV  := getNextDmaWriteAddr;
               nextDmaAddrV := f13Dout(298 downto 235);
               sendPktNumV  := slv(unsigned(getSendWriteReqPktNum) + 1);
            end if;
            if (reqStatusV = ST_NORMAL_C and hasErrHappened = '0') then
               setNextDmaWriteAddrValid   <= '1'; setNextDmaWriteAddrData   <= nextDmaAddrV;
               setSendWriteReqPktNumValid <= '1'; setSendWriteReqPktNumData <= sendPktNumV;
            end if;
         end if;
         f14Din <= f13Dout & curDmaAddrV;
      end if;
      -- Stage 13 : calcNormalSendWriteReqDmaRemainingLen (f14 -> f15) (BSV @1966)
      -- f14 tuple6: pmd[1145:497] reqStatus[496:493] permCheckReq[492:226] reqPktInfo[225:65]
      --   dupReadReqStartState[64] curDmaWriteAddr[63:0].  isSendReq=[79] isWriteReq=[78]
      --   isOnlyPkt=[74] isFirstPkt=[73] isMidPkt=[72] isLastPkt=[71]; permCheckReq.totalLen=f14[298:267];
      --   pmd.pktPayloadLen=f14[1145:1133].  f15 = f14 & remainingDmaWriteLen[63:32] & preRemaining[31:0].
      if (workerEnable and f14Valid = '1' and f15NotFull = '1') then
         f14RdEn <= '1'; f15WrEn <= '1';
         reqStatusV := f14Dout(496 downto 493);
         isSendWrV  := (f14Dout(79) = '1') or (f14Dout(78) = '1');
         pktPayLenV := f14Dout(1145 downto 1133);
         remLenV    := getRemainingDmaWriteLen;          -- default: keep context reg
         if (isSendWrV) then
            if    (f14Dout(74) = '1') then               -- isOnlyPkt
               remLenV := lenSubPktLen(f14Dout(298 downto 267), pktPayLenV, getPMTU);
            elsif (f14Dout(73) = '1') then               -- isFirstPkt
               remLenV := lenSubOnePmtu(f14Dout(298 downto 267), getPMTU);
            elsif (f14Dout(72) = '1') then               -- isMidPkt
               remLenV := lenSubOnePmtu(getRemainingDmaWriteLen, getPMTU);
            elsif (f14Dout(71) = '1') then               -- isLastPkt
               remLenV := lenSubPktLen(getRemainingDmaWriteLen, pktPayLenV, getPMTU);
            end if;
            if (reqStatusV = ST_NORMAL_C and hasErrHappened = '0') then
               setRemainingDmaWriteLenValid <= '1'; setRemainingDmaWriteLenData <= remLenV;
            end if;
         end if;
         -- preRemainingDmaWriteLen = contextRQ.getRemainingDmaWriteLen (pre-update value)
         f15Din <= f14Dout & remLenV & getRemainingDmaWriteLen;
      end if;
      -- Stage 14 : calcNormalSendWriteReqEnoughDmaSpace (f15 -> f16) (BSV @2039)
      -- f15 tuple8: pmd[1209:561] reqStatus[560:557] permCheckReq[556:290] reqPktInfo[289:129]
      --   dupReadReqStartState[128] curDmaWriteAddr[127:64] remainingDmaWriteLen[63:32]
      --   preRemainingDmaWriteLen[31:0].  isSendReq=[143] isWriteReq=[142] isOnlyPkt=[138]
      --   isFirstPkt=[137]; permCheckReq.totalLen=f15[362:331]; pmd.pktPayloadLen=f15[1209:1197].
      --   EnoughDmaSpaceCheck(4): onlyPktCase[3] firstPktCase[2] midPktCase[1] lastPktCase[0].
      if (workerEnable and f15Valid = '1' and f16NotFull = '1') then
         f15RdEn <= '1'; f16WrEn <= '1';
         isSendWrV  := (f15Dout(143) = '1') or (f15Dout(142) = '1');
         pktPayLenV := f15Dout(1209 downto 1197);
         if (f15Dout(138) = '1') then                    -- isOnlyPkt ? totalLen : preRemaining
            lastOnlyEnV := toSl(lenGtEqPktLen(f15Dout(362 downto 331), pktPayLenV, getPMTU));
         else
            lastOnlyEnV := toSl(lenGtEqPktLen(f15Dout(31 downto 0), pktPayLenV, getPMTU));
         end if;
         if (f15Dout(137) = '1') then                    -- isFirstPkt ? totalLen : preRemaining
            firstMidEnV := toSl(lenGtEqPmtu(f15Dout(362 downto 331), getPMTU));
         else
            firstMidEnV := toSl(lenGtEqPmtu(f15Dout(31 downto 0), getPMTU));
         end if;
         enoughChkV := (others => '0');
         if (isSendWrV) then
            enoughChkV := lastOnlyEnV & firstMidEnV & firstMidEnV & lastOnlyEnV;  -- only/first/mid/last
         end if;
         f16Din <= f15Dout(1209 downto 32) & enoughChkV;  -- drop preRemaining[31:0], append check
      end if;
      -- Stage 15 : calcNormalSendWriteReqDmaTotalLen (f16 -> f17) (BSV @2095)
      -- f16 tuple8: pmd[1181:533] reqStatus[532:529] permCheckReq[528:262] reqPktInfo[261:101]
      --   dupReadReqStartState[100] curDmaWriteAddr[99:36] remainingDmaWriteLen[35:4]
      --   enoughDmaSpaceCheck[3:0].  isSendReq=[115] isWriteReq=[114] isOnlyPkt=[110] isFirstPkt=[109]
      --   isMidPkt=[108] isLastPkt=[107]; pmd.pktPayloadLen=f16[1181:1169]; pmd.isZeroPayloadLen=f16[1160];
      --   enoughDmaSpaceCheck onlyPktCase=[3] firstPktCase=[2] midPktCase=[1] lastPktCase=[0].
      -- f17 tuple6: pmd reqStatus permCheckReq reqPktInfo reqLenCheckResult[130:1] dupReadReqStartState[0].
      --   ReqLenCheckResult(130): enoughDmaSpace[129] isLastPayloadLenZero[128] curDmaWriteAddr[127:64]
      --     remainingDmaWriteLen[63:32] totalDmaWriteLen[31:0].
      if (workerEnable and f16Valid = '1' and f17NotFull = '1') then
         f16RdEn <= '1'; f17WrEn <= '1';
         reqStatusV   := f16Dout(532 downto 529);
         isSendWrV    := (f16Dout(115) = '1') or (f16Dout(114) = '1');
         pktPayLenV   := f16Dout(1181 downto 1169);
         totLenV      := getTotalDmaWriteLen;            -- default: keep context reg
         enoughSpaceV := '0';
         isLastZeroV  := '0';
         if (isSendWrV) then
            if    (f16Dout(110) = '1') then              -- isOnlyPkt
               totLenV      := slv(resize(unsigned(pktPayLenV), 32));
               enoughSpaceV := f16Dout(0);               -- lastPktCase
            elsif (f16Dout(109) = '1') then              -- isFirstPkt
               totLenV      := slv(resize(unsigned(calcPmtuLen(getPMTU)), 32));
               enoughSpaceV := f16Dout(1);               -- midPktCase
            elsif (f16Dout(108) = '1') then              -- isMidPkt
               totLenV      := lenAddOnePmtu(getTotalDmaWriteLen, getPMTU);
               enoughSpaceV := f16Dout(2);               -- firstPktCase
            elsif (f16Dout(107) = '1') then              -- isLastPkt
               totLenV      := lenAddPktLen(getTotalDmaWriteLen, pktPayLenV, getPMTU);
               enoughSpaceV := f16Dout(3);               -- onlyPktCase
               isLastZeroV  := f16Dout(1160);            -- isZeroPayloadLen
            end if;
            if (reqStatusV = ST_NORMAL_C and hasErrHappened = '0') then
               setTotalDmaWriteLenValid <= '1'; setTotalDmaWriteLenData <= totLenV;
            end if;
         end if;
         reqLenResV := enoughSpaceV & isLastZeroV & f16Dout(99 downto 36)   -- curDmaWriteAddr
                       & f16Dout(35 downto 4) & totLenV;                    -- remainingDmaWriteLen, totalDmaWriteLen
         f17Din <= f16Dout(1181 downto 101) & reqLenResV & f16Dout(100);
      end if;
      -- Stage 16 : checkReqLen (f17 -> f18) (BSV @2179)
      -- f17 tuple6: pmd[1211:563] reqStatus[562:559] permCheckReq[558:292] reqPktInfo[291:131]
      --   reqLenCheckResult[130:1] dupReadReqStartState[0].  reqLenCheckResult: enoughDmaSpace=[130]
      --   isLastPayloadLenZero=[129] curDmaWriteAddr=[128:65] remainingDmaWriteLen=[64:33]
      --   totalDmaWriteLen=[32:1].  reqPktInfo.isSendReq=[145] isWriteReq=[144] isOnlyPkt=[140]
      --   isLastPkt=[137]; bth.trans=f17[291:289]; permCheckReq.totalLen field=permCheckReqV[72:41].
      -- f18 tuple6: pmd reqStatus permCheckReq reqPktInfo curDmaWriteAddr[64:1] dupReadReqStartState[0].
      if (workerEnable and f17Valid = '1' and f18NotFull = '1') then
         f17RdEn <= '1'; f18WrEn <= '1';
         reqStatusV    := f17Dout(562 downto 559);
         permCheckReqV := f17Dout(558 downto 292);
         enoughSpaceV  := f17Dout(130);
         isLastZeroV   := f17Dout(129);
         remLenV       := f17Dout(64 downto 33);
         totLenV       := f17Dout(32 downto 1);
         isSendWrV     := (f17Dout(145) = '1') or (f17Dout(144) = '1');
         if (isSendWrV and reqStatusV = ST_NORMAL_C and hasErrHappened = '0') then
            -- writeReqLenMatch = (isWrite && (last||only)) ? isZero(remaining) : True
            if ((f17Dout(144) = '1') and ((f17Dout(137) = '1') or (f17Dout(140) = '1'))) then
               writeMatchV := (unsigned(remLenV) = 0);
            else
               writeMatchV := true;
            end if;
            if (enoughSpaceV = '0' or (not writeMatchV) or isLastZeroV = '1') then
               reqStatusV := invReqStatus(f17Dout(291 downto 289));   -- getInvReqStatusByTransType(bth.trans)
            elsif ((f17Dout(145) = '1') and ((f17Dout(137) = '1') or (f17Dout(140) = '1'))) then
               permCheckReqV(72 downto 41) := totLenV;                -- send req: update totalLen
            end if;
         end if;
         f18Din <= f17Dout(1211 downto 563) & reqStatusV & permCheckReqV
                   & f17Dout(291 downto 131) & f17Dout(128 downto 65) & f17Dout(0);
      end if;
      -- Stage 17 : issuePayloadConReqOrDiscard (f18 -> f19) + payloadConReqPort.put (BSV @2248)
      -- f18 tuple6: pmd[1145:497] reqStatus[496:493] permCheckReq[492:226] reqPktInfo[225:65]
      --   curDmaWriteAddr[64:1] dupReadReqStartState[0].  isSendReq=[79] isWriteReq=[78];
      --   permCheckReq.isZeroDmaLen=f18[234]; pmd.isZeroPayloadLen=f18[1124];
      --   pmd.pktFragNum=f18[1132:1125]; pmd.pktPayloadLen=f18[1145:1133]; bth.psn=f18[153:130].
      -- PayloadConReq(203): fragNum[202:195] consumeInfo[194:0]; consumeInfo = tag[194:193] &
      --   pad[192:129] & DmaWriteMetaData[128:0]. DmaWriteMetaData: initiator[128:125] sqpn[124:101]
      --   startAddr[100:37] len(PktLen)[36:24] psn[23:0].  tag: DiscardPayloadInfo="00",
      --   SendWriteReqReadRespInfo="10".  put is CONDITIONAL (gate ready only when putting).
      -- f19 tuple6: pmd reqStatus permCheckReq reqPktInfo hasReqStatusErr[1] dupReadReqStartState[0].
      reqStatusV := f18Dout(496 downto 493);
      -- normalPut = NORMAL & !err & (send|write) & !isZeroDmaLen ; discardPut = !(NORMAL&!err) & !isZeroPayloadLen
      doConPutV := ((reqStatusV = ST_NORMAL_C) and (hasErrHappened = '0')
                    and ((f18Dout(79) = '1') or (f18Dout(78) = '1')) and (f18Dout(234) = '0'))
                   or ((not ((reqStatusV = ST_NORMAL_C) and (hasErrHappened = '0'))) and (f18Dout(1124) = '0'));
      if (workerEnable and f18Valid = '1' and f19NotFull = '1'
          and (not doConPutV or payloadConReqReady = '1')) then
         f18RdEn <= '1'; f19WrEn <= '1';
         if (doConPutV) then
            payloadConReqValid <= '1';
            -- DmaWriteMetaData: initiator (WR normal / DISCARD else), sqpn, startAddr=curDmaWriteAddr,
            --   len=pktPayloadLen, psn=bth.psn
            if ((reqStatusV = ST_NORMAL_C) and (hasErrHappened = '0')) then
               dmaWrMetaV := DMA_SRC_RQ_WR_C & getSQPN & f18Dout(64 downto 1)
                             & f18Dout(1145 downto 1133) & f18Dout(153 downto 130);
               payloadConReqData <= f18Dout(1132 downto 1125)           -- fragNum
                                    & "10" & slv(to_unsigned(0, 64)) & dmaWrMetaV;  -- SendWrite tag
            else
               dmaWrMetaV := DMA_SRC_RQ_DISCARD_C & getSQPN & f18Dout(64 downto 1)
                             & f18Dout(1145 downto 1133) & f18Dout(153 downto 130);
               payloadConReqData <= f18Dout(1132 downto 1125)           -- fragNum
                                    & "00" & slv(to_unsigned(0, 64)) & dmaWrMetaV;  -- Discard tag
            end if;
         end if;
         -- Block C error latch: sticky hasReqStatusErr, set on any error request status
         hasReqStErrV := r.hasReqStatusErr;
         if (isErrReqStatus(reqStatusV)) then
            hasReqStErrV := '1';
         end if;
         v.hasReqStatusErr := hasReqStErrV;
         f19Din <= f18Dout(1145 downto 65) & hasReqStErrV & f18Dout(0);
      end if;
      -- Stage 18 : issuePayloadGenReq (f19 -> f20) + payloadGenerator.request.put (BSV @2331)
      -- f19 tuple6: pmd[1082:434] reqStatus[433:430] permCheckReq[429:163] reqPktInfo[162:2]
      --   hasReqStatusErr[1] dupReadReqStartState[0].  isReadReq=f19[13];
      --   permCheckReq.isZeroDmaLen=f19[171] reqAddr=f19[299:236] totalLen=f19[235:204] rkey=f19[332:301].
      -- PayloadGenReq(199): dmaReadMetaData[198:4] addPadding[3] pmtu[2:0].  DmaReadMetaData(195):
      --   initiator[194:191] sqpn[190:167] wrID[166:103] startAddr[102:39] len[38:7] mrIdx[6:0].
      --   mrIdx=key2IndexMR(rkey)=rkey[31:25].  request.put is CONDITIONAL.
      -- f20 tuple5: pmd reqStatus permCheckReq reqPktInfo respPktGenInfo[72:0].
      -- RespPktGenInfo(73): hasReqStatusErr[72] hasDmaReadRespErr[71] hasErrRespGen[70] shouldGenResp[69]
      --   expectReadRespPayload[68] expectAtomicRespOrig[67] expectDupAtomicCheckResp[66]
      --   atomicAckOrig(Maybe#Long)[65:1] dupReadReqStartState[0].
      reqStatusV   := f19Dout(433 downto 430);
      doGenReqV := (f19Dout(1) = '0') and (r.hasDmaReadRespErr = '0')     -- !hasReqStatusErr & !hasDmaReadRespErr
                   and (f19Dout(171) = '0') and (f19Dout(13) = '1')       -- !isZeroDmaLen & isReadReq
                   and ((reqStatusV = ST_NORMAL_C) or (reqStatusV = ST_DUP_C));
      if (workerEnable and f19Valid = '1' and f20NotFull = '1'
          and (not doGenReqV or payloadGenReqReady = '1')) then
         f19RdEn <= '1'; f20WrEn <= '1';
         expRdPayV := '0';
         if (doGenReqV) then
            payloadGenReqValid <= '1';
            -- DmaReadMetaData: initiator=RD, sqpn, wrID=dontCare(0), startAddr=reqAddr, len=totalLen,
            --   mrIdx=key2IndexMR(rkey)=rkey[31:25]
            dmaRdMetaV := DMA_SRC_RQ_RD_C & getSQPN & slv(to_unsigned(0, 64))
                          & f19Dout(299 downto 236) & f19Dout(235 downto 204) & f19Dout(332 downto 326);
            payloadGenReqData <= dmaRdMetaV & '1' & getPMTU;   -- addPadding=True
            expRdPayV := '1';
         end if;
         -- RespPktGenInfo: only hasReqStatusErr / hasDmaReadRespErr / expectReadRespPayload /
         --   dupReadReqStartState set here; the rest False / Invalid.
         respGenV := (others => '0');
         respGenV(72) := f19Dout(1);            -- hasReqStatusErr
         respGenV(71) := r.hasDmaReadRespErr;   -- hasDmaReadRespErr
         respGenV(68) := expRdPayV;             -- expectReadRespPayload
         respGenV(0)  := f19Dout(0);            -- dupReadReqStartState
         f20Din <= f19Dout(1082 downto 2) & respGenV;
      end if;
      -- Stage 19 : issueAtomicReq (f20 -> f21) + U_AtomicSrv request (RQ-06 STUB) (BSV @2399)
      -- f20 tuple5: pmd[1153:505] reqStatus[504:501] permCheckReq[500:234] reqPktInfo[233:73]
      --   respPktGenInfo[72:0].  isAtomicReq=f20[83]; bth.opcode=f20[230:226]; bth.psn=f20[161:138];
      --   respPktGenInfo.hasReqStatusErr=f20[72].  AtomicEth from pmd: va=f20[1035:972]
      --   swap=f20[939:876] comp=f20[875:812].
      -- AtomicOpReq(245): initiator[244:241] casOrFetchAdd[240] startAddr[239:176] compData[175:112]
      --   swapData[111:48] sqpn[47:24] psn[23:0].  casOrFetchAdd = (opcode==COMPARE_SWAP=5'h13).
      --   request.put is CONDITIONAL.  f21 = f20 with respPktGenInfo.{hasDmaReadRespErr,expectAtomicRespOrig}.
      reqStatusV := f20Dout(504 downto 501);
      doAtomicReqV := (f20Dout(72) = '0') and (r.hasDmaReadRespErr = '0')    -- !hasReqStatusErr & !hasDmaReadRespErr
                      and (reqStatusV = ST_NORMAL_C) and (f20Dout(83) = '1'); -- NORMAL & isAtomicReq
      if (workerEnable and f20Valid = '1' and f21NotFull = '1'
          and (not doAtomicReqV or atomicReqRdy = '1')) then
         f20RdEn <= '1'; f21WrEn <= '1';
         expAtomicV := '0';
         if (doAtomicReqV) then
            atomicReqValid <= '1';
            atomicReqData  <= DMA_SRC_RQ_ATOMIC_C & toSl(f20Dout(230 downto 226) = "10011")  -- casOrFetchAdd
                              & f20Dout(1035 downto 972)     -- startAddr = atomicEth.va
                              & f20Dout(875 downto 812)      -- compData  = atomicEth.comp
                              & f20Dout(939 downto 876)      -- swapData  = atomicEth.swap
                              & getSQPN & f20Dout(161 downto 138);  -- sqpn, psn
            expAtomicV := '1';
         end if;
         respGenV      := f20Dout(72 downto 0);
         respGenV(71)  := r.hasDmaReadRespErr;   -- hasDmaReadRespErr
         respGenV(67)  := expAtomicV;            -- expectAtomicRespOrig
         f21Din <= f20Dout(1153 downto 73) & respGenV;
      end if;
      -- Stage 20 : shouldGenResp4NormalCase (f21 -> f22) + coalesce counter (Block E) (BSV @2447)
      -- f21 tuple5: pmd[1153:505] reqStatus[504:501] permCheckReq[500:234] reqPktInfo[233:73]
      --   respPktGenInfo[72:0].  isSendReq=[87] isWriteReq=[86] isReadReq=[84] isAtomicReq=[83]
      --   isLastOrOnlyPkt=[77]; bth.ackReq=[169] bth.trans=[233:231]; respPktGenInfo.hasReqStatusErr=[72]
      --   expectAtomicRespOrig=[67] shouldGenResp=[69].
      reqStatusV     := f21Dout(504 downto 501);
      qpHasRespV     := qpNeedGenResp(f21Dout(233 downto 231));
      shouldGenRespV := '0';
      reloadCntV     := false;
      decrCntV       := false;
      genEvenNoAckV  := (f21Dout(77) = '1') and (r.isCoalesceWorkReqCntZero = '1');
      if (workerEnable and f21Valid = '1' and f22NotFull = '1') then
         f21RdEn <= '1'; f22WrEn <= '1';
         if (reqStatusV = ST_NORMAL_C) then
            if ((f21Dout(87) = '1') or (f21Dout(86) = '1')) then       -- send or write
               if ((f21Dout(169) = '1') or genEvenNoAckV) then          -- ackReq or coalesce-forced
                  shouldGenRespV := toSl(qpHasRespV);
                  reloadCntV     := true;
               else
                  decrCntV := (f21Dout(77) = '1');                      -- decr on isLastOrOnlyPkt
               end if;
            elsif (f21Dout(84) = '1') then                             -- read
               shouldGenRespV := toSl(qpHasRespV);
               reloadCntV     := true;
            elsif (f21Dout(83) = '1') then                             -- atomic
               if (f21Dout(67) = '1') then                             -- expectAtomicRespOrig
                  shouldGenRespV := toSl(qpHasRespV);
                  reloadCntV     := true;
               end if;
            end if;
            if (qpHasRespV and (f21Dout(72) = '0')) then                -- qpHasResp and !hasReqStatusErr
               if (reloadCntV) then
                  v.coalesceWorkReqCnt       := slv(unsigned(getPendingWorkReqNum) - 1);
                  v.isCoalesceWorkReqCntZero := toSl(unsigned(getPendingWorkReqNum) = 1);
               elsif (decrCntV) then
                  v.coalesceWorkReqCnt       := slv(unsigned(r.coalesceWorkReqCnt) - 1);
                  v.isCoalesceWorkReqCntZero := toSl(unsigned(r.coalesceWorkReqCnt) = 1);
               end if;
            end if;
         end if;
         respGenV      := f21Dout(72 downto 0);
         respGenV(69)  := shouldGenRespV;         -- respPktGenInfo.shouldGenResp
         f22Din <= f21Dout(1153 downto 73) & respGenV;
      end if;
      -- Stage 21 : shouldGenResp4OtherCases (f22 -> f23) (BSV @2546)
      --   Recompute shouldGenResp per reqStatus (NORMAL keeps stage-20 value; DUP send/write
      --   needs ackReq|last; DUP read always; SEQ_ERR/RNR/INV_*/RMT_* always; DISCARD/FLUSH none).
      reqStatusV     := f22Dout(504 downto 501);
      qpHasRespV     := qpNeedGenResp(f22Dout(233 downto 231));
      shouldGenRespV := '0';
      if (workerEnable and f22Valid = '1' and f23NotFull = '1') then
         f22RdEn <= '1'; f23WrEn <= '1';
         if (reqStatusV = ST_NORMAL_C) then
            shouldGenRespV := f22Dout(69);                             -- keep stage-20 shouldGenResp
         elsif (reqStatusV = ST_DUP_C) then
            if ((f22Dout(87) = '1') or (f22Dout(86) = '1')) then       -- dup send/write
               if ((f22Dout(169) = '1') or (f22Dout(77) = '1')) then   -- ackReq or isLastOrOnlyPkt
                  shouldGenRespV := toSl(qpHasRespV);
               end if;
            elsif (f22Dout(84) = '1') then                            -- dup read
               shouldGenRespV := toSl(qpHasRespV);
            end if;                                                    -- dup atomic: none
         elsif (reqStatusV = ST_SEQ_ERR_C or reqStatusV = ST_RNR_C or reqStatusV = ST_INV_REQ_C
                or reqStatusV = ST_INV_RD_C or reqStatusV = ST_RMT_ACC_C or reqStatusV = ST_RMT_OP_C) then
            shouldGenRespV := toSl(qpHasRespV);
         end if;                                                       -- DISCARD/ERR_FLUSH_RR: no resp
         respGenV      := f22Dout(72 downto 0);
         respGenV(69)  := shouldGenRespV;
         f23Din <= f22Dout(1153 downto 73) & respGenV;
      end if;
      -- Stage 22 : countPendingResp (f23 -> f24) — Sub-FSM D response-packet LOOP (BSV @2636)
      -- Multi-cycle: emits one respPsnAndMsnQ entry per response packet, deqs respCountQ only on
      -- the last/only response packet.  f24 tuple6 = f23 tuple5 + respPktSeqInfo[1:0]
      --   (isFirstOrOnlyRespPkt[1] isLastOrOnlyRespPkt[0]).  reqPktInfo.isOnlyRespPkt=f23[76]
      --   respPktNum=f23[136:112].  contextRQ.getRespPktNum/getIsRespPktNumZero/setRespPktNum (RMW).
      reqStatusV   := f23Dout(504 downto 501);
      remRespPktV  := getRespPktNum;
      isFirstRespV := (r.isFirstOrOnlyRespPkt = '1');
      isLastRespV  := (f23Dout(76) = '1')
                      or ((r.isFirstOrOnlyRespPkt = '0') and (getIsRespPktNumZero = '1'));
      deqRespV     := false;
      if (workerEnable and f23Valid = '1' and f24NotFull = '1') then
         f24WrEn <= '1';
         if ((not (reqStatusV = ST_NORMAL_C or reqStatusV = ST_DUP_C)) or (r.hasErrRespGen = '1')) then
            -- No response counting after an error response (single-packet error responses)
            isFirstRespV := true;
            isLastRespV  := true;
            deqRespV     := true;
         else
            if (isLastRespV) then
               deqRespV := true;
            end if;
            if (isFirstRespV) then
               if (f23Dout(76) = '1') then                             -- isOnlyRespPkt
                  remRespPktV := (others => '0');
               else
                  remRespPktV := slv(unsigned(f23Dout(136 downto 112)) - 2);  -- respPktNum - 2
               end if;
               setRespPktNumValid <= '1';
               setRespPktNumData  <= remRespPktV;
            elsif (not isLastRespV) then                               -- middle response packet
               setRespPktNumValid <= '1';
               setRespPktNumData  <= slv(unsigned(remRespPktV) - 1);
            end if;
         end if;
         v.isFirstOrOnlyRespPkt := toSl(isLastRespV or (r.hasErrRespGen = '1'));
         if (deqRespV) then
            f23RdEn <= '1';
         end if;
         f24Din <= f23Dout & toSl(isFirstRespV) & toSl(isLastRespV);
      end if;
      -- Stage 23 : updateRespPsnAndMsn (f24 -> f25) (BSV @2708)
      --   f24 (1156, tuple6) = pmd[1155:507] reqStatus[506:503] permCheckReq[502:236]
      --     reqPktInfo[235:75] respPktGenInfo[74:2] respPktSeqInfo[1:0].
      --   reqPktInfo base 75 (bth = reqPktInfo[160:65]): bth.psn[163:140] isReadReq[86] isLastOrOnlyPkt[79].
      --   respPktSeqInfo: isFirstOrOnlyRespPkt[1] isLastOrOnlyRespPkt[0].
      --   respPktGenInfo base 2: dupReadReqStartState[2] (FROM_MIDDLE=1).
      --   respPSN = isFirstOrOnlyRespPkt ? bth.psn : getCurRespPSN; msn = getMSN.
      --   f25 (1204, tuple6) = f24[1155:2] (tuple5) & respPktHeaderInfo[49:0]
      --     (psn[49:26] msn[25:2] isFirstOrOnlyRespPkt[1] isLastOrOnlyRespPkt[0]).
      if (workerEnable and f24Valid = '1' and f25NotFull = '1') then
         f24RdEn <= '1'; f25WrEn <= '1';
         isFirstOrOnlyRespV := f24Dout(1);
         if (isFirstOrOnlyRespV = '1') then
            respPSNv := f24Dout(163 downto 140);    -- bth.psn
         else
            respPSNv := getCurRespPSN;
         end if;
         msnV := getMSN;
         if (r.hasErrRespGen = '0') then
            setCurRespPSNValid <= '1';
            setCurRespPSNData  <= slv(unsigned(respPSNv) + 1);
            if ((f24Dout(506 downto 503) = ST_NORMAL_C) and (f24Dout(79) = '1') and (f24Dout(0) = '1')) then
               msnV := slv(unsigned(msnV) + 1);     -- isLastOrOnlyReqPkt & isLastOrOnlyRespPkt
               setMSNValid <= '1';
               setMSNData  <= msnV;
            end if;
            -- DUP read starting from middle: this resp pkt is no longer the first
            if ((f24Dout(506 downto 503) = ST_DUP_C) and (f24Dout(2) = '1')) then
               isFirstOrOnlyRespV := '0';
            end if;
         end if;
         respPktHdrV := respPSNv & msnV & isFirstOrOnlyRespV & f24Dout(0);
         f25Din <= f24Dout(1155 downto 2) & respPktHdrV;
      end if;
      -- Stage 24 : waitAtomicResp (f25 -> f26) + atomicSrv.response.get (BSV @2780)
      --   f25/f26 (1204, tuple6): respPktGenInfo[122:50] (expectAtomicRespOrig[117],
      --     atomicAckOrig Maybe#Long[115:51]).  AtomicOpResp: original[111:48].
      --   response.get is CONDITIONAL on expectAtomicRespOrig; atomicAckOrig := Valid original
      --   (else Invalid).  f26 = f25 with respPktGenInfo.atomicAckOrig patched.
      doAtomicRespV := (f25Dout(117) = '1');
      if (workerEnable and f25Valid = '1' and f26NotFull = '1'
          and (not doAtomicRespV or atomicRespValid = '1')) then
         f25RdEn <= '1'; f26WrEn <= '1';
         if (doAtomicRespV) then
            atomicRespRdEn <= '1';
            atomicAckOrigV := '1' & atomicRespData(111 downto 48);   -- tagged Valid original
         else
            atomicAckOrigV := (others => '0');                       -- tagged Invalid
         end if;
         f26Din <= f25Dout(1203 downto 116) & atomicAckOrigV & f25Dout(50 downto 0);
      end if;
      -- Stage 25 : insertIntoAtomicCache (f26 -> f27) + dupReadAtomicCache.insertAtomic (BSV @2834)
      --   atomicEth = pmd[530:307] (pmd-rel: va[530:467] rkey[466:435] swap[434:371] comp[370:307]);
      --   in f26 pmd base 555 -> atomicEth = f26[1085:862].
      --   reqPktInfo base 123 (bth = reqPktInfo[160:65]): bth.psn[211:188] bth.opcode[280:276].
      --   atomicAckOrig[115:51] (value[114:51]).
      --   insertAtomic is CONDITIONAL on expectAtomicRespOrig (f26[117]).
      --   AtomicCacheItem(317): atomicPSN[316:293] atomicOpCode[292:288] atomicEth[287:64] atomicAckEth[63:0].
      --   f27 (1428, tuple7) = f26 & atomicEth[223:0].
      atomicEthV      := f26Dout(1085 downto 862);
      doInsertAtomicV := (f26Dout(117) = '1');
      atomicCacheItemV := f26Dout(211 downto 188) & f26Dout(280 downto 276)
                          & atomicEthV & f26Dout(114 downto 51);
      if (workerEnable and f26Valid = '1' and f27NotFull = '1'
          and (not doInsertAtomicV or insertAtomicReady = '1')) then
         f26RdEn <= '1'; f27WrEn <= '1';
         if (doInsertAtomicV) then
            insertAtomicValid <= '1';
            insertAtomicData  <= atomicCacheItemV;
         end if;
         f27Din <= f26Dout & atomicEthV;
      end if;
      -- Stage 26 : checkReadResp (f27 -> f28) + payloadGen.response.get; sets hasDmaReadRespErr (Block C) (BSV @2903)
      --   f27/f28 (1428, tuple7): respPktGenInfo base 274 -> hasDmaReadRespErr[345]
      --     hasErrRespGen[344] shouldGenResp[343] expectReadRespPayload[342].
      --   PayloadGenResp(2): addPadding[1] isRespErr[0].
      --   response.get CONDITIONAL on (!hasDmaReadRespErrReg & expectReadRespPayload); on isRespErr:
      --     latch sticky v.hasDmaReadRespErr, clear expectReadRespPayload.
      doPayloadRespV := (r.hasDmaReadRespErr = '0') and (f27Dout(342) = '1');
      if (workerEnable and f27Valid = '1' and f28NotFull = '1'
          and (not doPayloadRespV or payloadGenRespValid = '1')) then
         f27RdEn <= '1'; f28WrEn <= '1';
         hasDmaRdErrV := f27Dout(345);   -- incoming respPktGenInfo.hasDmaReadRespErr
         expectReadV  := f27Dout(342);
         if (doPayloadRespV) then
            payloadGenRespGetEn <= '1';
            if (payloadGenRespData(0) = '1') then   -- isRespErr
               hasDmaRdErrV       := '1';
               v.hasDmaReadRespErr := '1';          -- sticky Block-C flag
               expectReadV        := '0';
            end if;
         end if;
         f28Din <= f27Dout(1427 downto 346) & hasDmaRdErrV & f27Dout(344 downto 343)
                   & expectReadV & f27Dout(341 downto 0);
      end if;
      -- Stage 27 : queryPerm4DupAtomicReq (f28 -> f29) + searchAtomicReq (BSV @3003)
      -- On DUP atomic w/o error, issue dupReadAtomicCache.searchAtomicReq; set
      -- respPktGenInfo.expectDupAtomicCheckResp. searchAtomicReq is CONDITIONAL
      -- (gate its ready only when performed); atomicEth field (f28[223:0]) is dropped.
      doSearchAtomicV := (f28Dout(778 downto 775) = ST_DUP_C) and (f28Dout(357) = '1')
                         and (f28Dout(346) = '0') and (f28Dout(345) = '0');  -- DUP & isAtomic & !reqErr & !dmaErr
      if (workerEnable and f28Valid = '1' and f29NotFull = '1'
          and (not doSearchAtomicV or searchAtomicReqReady = '1')) then
         f28RdEn <= '1'; f29WrEn <= '1';
         if (doSearchAtomicV) then
            searchAtomicReqValid <= '1';
            -- AtomicCacheItem(317): atomicPSN bth.psn | atomicOpCode bth.opcode | atomicEth | atomicAckEth(dontCare)
            searchAtomicReqData <= f28Dout(435 downto 412) & f28Dout(504 downto 500)
                                   & f28Dout(223 downto 0) & slv(to_unsigned(0, 64));
         end if;
         -- f29 = f28 minus atomicEth, with expectDupAtomicCheckResp (respPktGenInfo[66]=f28[340]) updated
         f29Din <= f28Dout(1427 downto 341) & toSl(doSearchAtomicV) & f28Dout(339 downto 224);
      end if;
      -- Stage 28 : checkPerm4DupAtomicReq (f29 -> f30) + searchAtomicResp (BSV @3042)
      -- If a dup-atomic search was issued, get its result: Valid -> patch
      -- atomicAckOrig + shouldGenResp(qpNeedGenResp); Invalid -> reqStatus DISCARD.
      -- searchAtomicResp.get is CONDITIONAL (gate its valid only when expected).
      reqStatus28V := f29Dout(554 downto 551);
      shouldGen28V := f29Dout(119);            -- respPktGenInfo.shouldGenResp
      atomicAck28V := f29Dout(115 downto 51);  -- respPktGenInfo.atomicAckOrig (Maybe#Long)
      if (workerEnable and f29Valid = '1' and f30NotFull = '1'
          and (f29Dout(116) = '0' or searchAtomicRespValid = '1')) then   -- expectDupAtomicCheckResp
         f29RdEn <= '1'; f30WrEn <= '1';
         if (f29Dout(116) = '1') then
            searchAtomicRespGetEn <= '1';
            if (searchAtomicRespData(317) = '1') then           -- Valid atomicCache
               atomicAck28V := '1' & searchAtomicRespData(63 downto 0);  -- Valid atomicAckEth.orig
               shouldGen28V := toSl(qpNeedGenResp(f29Dout(283 downto 281)));  -- bth.trans
            else
               reqStatus28V := ST_DISCARD_C;
            end if;
         end if;
         f30Din <= f29Dout(1203 downto 555) & reqStatus28V & f29Dout(550 downto 120)
                   & shouldGen28V & f29Dout(118 downto 116) & atomicAck28V & f29Dout(50 downto 0);
      end if;
      -- Stage 29 : genRespHeader (f30 -> f31) + sets hasErrRespGen (Block C) (BSV @3097)
      -- Build the response HeaderRDMA (first/only vs middle/last), promote
      -- hasDmaReadRespErr to RMT_OP/DISCARD, and latch the sticky hasErrRespGen
      -- flag on any error request status. maybeHeader is appended (tuple7 -> f31).
      reqStatus29V   := f30Dout(554 downto 551);
      shouldGen29V   := f30Dout(119);
      hasErrRespGenV := r.hasErrRespGen;
      maybeHeaderV   := (others => '0');
      if (workerEnable and f30Valid = '1' and f31NotFull = '1') then
         f30RdEn <= '1'; f31WrEn <= '1';
         if (r.hasErrRespGen = '1') then
            shouldGen29V := '0';
         else
            if (f30Dout(121) = '1') then      -- hasDmaReadRespErr
               if (isNormalOrErrStatus(reqStatus29V)) then
                  reqStatus29V := ST_RMT_OP_C; shouldGen29V := '1';
               elsif (reqStatus29V = ST_DUP_C) then
                  reqStatus29V := ST_DISCARD_C; shouldGen29V := '0';
               end if;
            end if;
            isOnlyReadResp29V := (f30Dout(126) = '1') and (f30Dout(134) = '1');  -- isOnlyRespPkt & isReadReq
            if (f30Dout(1) = '1') then        -- isFirstOrOnlyRespPkt
               maybeHeaderV := genFirstOrOnlyRespHeader(
                  f30Dout(280 downto 276), reqStatus29V, f30Dout(356 downto 325),
                  f30Dout(115 downto 51), getTypeQP, getPKEY, getDQPN, getMinRnrTimer,
                  f30Dout(49 downto 26), f30Dout(25 downto 2), isOnlyReadResp29V);
            else
               maybeHeaderV := genMidLastRespHeader(
                  reqStatus29V, f30Dout(356 downto 325), getTypeQP, getPKEY, getDQPN,
                  getMinRnrTimer, f30Dout(49 downto 26), f30Dout(25 downto 2), f30Dout(0) = '1');
            end if;
         end if;
         if (isErrReqStatus(reqStatus29V)) then
            hasErrRespGenV := '1';
         end if;
         v.hasErrRespGen := hasErrRespGenV;
         -- f31 (tuple7): patch reqStatus, respPktGenInfo.{hasErrRespGen,shouldGenResp}, append maybeHeader
         f31Din <= f30Dout(1203 downto 555) & reqStatus29V & f30Dout(550 downto 123)
                   & f30Dout(122 downto 121) & hasErrRespGenV & shouldGen29V
                   & f30Dout(118 downto 50) & f30Dout(49 downto 0) & maybeHeaderV;
      end if;
      -- Stage 30 : genRespPkt (f31 -> respHeaderOutQ + psnRespOutQ + workCompReqQ) (BSV @3214)
      -- Emit the header + respPSN to the output FIFOs iff shouldGenResp and the
      -- header is Valid (same rule for first/only and middle/last). Always enq
      -- the tuple6 into workCompReqQ (drop maybeHeader). Header enq is CONDITIONAL.
      doHeaderEnqV := (f31Dout(713) = '1') and (f31Dout(593) = '1');  -- shouldGenResp & maybeHeader.valid
      if (workerEnable and f31Valid = '1' and f32NotFull = '1'
          and (not doHeaderEnqV or (rhOutNotFull = '1' and psnOutNotFull = '1'))) then
         f31RdEn <= '1'; f32WrEn <= '1';
         if (doHeaderEnqV) then
            rhOutWrEn  <= '1'; rhOutDin  <= f31Dout(592 downto 0);        -- HeaderRDMA
            psnOutWrEn <= '1'; psnOutDin <= f31Dout(643 downto 620);      -- respPSN
         end if;
         f32Din <= f31Dout(1797 downto 594);   -- workCompReqQ tuple6 (drop maybeHeader)
      end if;
      -- Stage 31 : genWorkCompRQ (f32 -> workCompGenReqOutQ) + CountCF decrOne
      --            (BSV genWorkCompRQ @3385). Runs at normal, retry AND error state.
      -- f32 workCompReqQ tuple6 (=1204): pmd[1203:555] reqStatus[554:551]
      --   permCheckReq[550:284] reqPktInfo[283:123] respPktGenInfo[122:50]
      --   respPktHeaderInfo[49:0]. permCheckReq.wrID[550:486] totalLen[356:325]
      --   isZeroDmaLen[292]; reqPktInfo bth.psn[211:188] isAtomicReq[133]
      --   isReadReq[134] bth.opcode[280:276] bth.trans[283:281]; hasErrRespGen[120];
      --   respPktHeaderInfo.isFirstOrOnlyRespPkt[1]. headerData bit h -> f32[670+h].
      reqStatus31V := f32Dout(554 downto 551);
      reqOp31V     := f32Dout(280 downto 276);
      trans31V     := f32Dout(283 downto 281);
      -- (a) pendingDestReadAtomicReqCnt.decrOne when this WC closes a read/atomic req
      --     (BSV: reqStatus==NORMAL && !hasErrRespGen && ((isReadReq &&
      --      isFirstOrOnlyRespPkt) || isAtomicReq) && cnt > 0).
      doDecr31V := (reqStatus31V = ST_NORMAL_C) and (f32Dout(120) = '0')
                   and (((f32Dout(134) = '1') and (f32Dout(1) = '1'))   -- isReadReq & isFirstOrOnlyResp
                        or (f32Dout(133) = '1'))                          -- isAtomicReq
                   and (unsigned(ccCnt) > 0);
      -- (b) extractImmDt/extractIETH (Utils.bsv:942,971) — 32b slices of headerData.
      if (reqOp31V = "01011") then                 -- RDMA_WRITE_ONLY_WITH_IMMEDIATE
         if (trans31V = "101") then immDt31V := f32Dout(925 downto 894);   -- XRC: hdr[255:224]
         else                       immDt31V := f32Dout(957 downto 926);   -- hdr[287:256] (after RETH)
         end if;
      else
         if (trans31V = "101") then immDt31V := f32Dout(1053 downto 1022); -- XRC: hdr[383:352]
         else                       immDt31V := f32Dout(1085 downto 1054); -- hdr[415:384] (after BTH)
         end if;
      end if;
      if (trans31V = "101") then ieth31V := f32Dout(1053 downto 1022);     -- XRC: hdr[383:352]
      else                       ieth31V := f32Dout(1085 downto 1054);     -- hdr[415:384]
      end if;
      -- (c) Maybe#IMM / Maybe#RKEY : tag[32] & data[31:0]
      if (opHasImmDt(reqOp31V)) then immM31V := '1' & immDt31V; else immM31V := (32 downto 0 => '0'); end if;
      if (opHasIETH(reqOp31V))  then rkeyM31V := '1' & ieth31V; else rkeyM31V := (32 downto 0 => '0'); end if;
      -- (d) WorkComp is generated only when genWorkCompStatusFromReqStatusRQ Valid.
      wcStatus31V := genWcStatus(reqStatus31V);
      doWcEnq31V  := (wcStatus31V(5) = '1');
      if (workerEnable and f32Valid = '1'
          and (not doWcEnq31V or wcOutNotFull = '1')) then
         f32RdEn <= '1';
         if (doDecr31V) then
            ccDecrEn <= '1';                        -- pendingDestReadAtomicReqCnt.decrOne
         end if;
         if (doWcEnq31V) then
            wcOutWrEn <= '1';
            -- WorkCompGenReqRQ(198): rrID[197:133] len[132:101] reqPSN[100:77]
            --   isZeroDmaLen[76] wcStatus[75:71] reqOpCode[70:66] immDt[65:33]
            --   rkey2Inv[32:0]
            wcOutDin <= f32Dout(550 downto 486)     -- rrID  = permCheckReq.wrID
                      & f32Dout(356 downto 325)     -- len   = permCheckReq.totalLen
                      & f32Dout(211 downto 188)     -- reqPSN = bth.psn
                      & f32Dout(292)                -- isZeroDmaLen
                      & wcStatus31V(4 downto 0)     -- wcStatus
                      & reqOp31V                    -- reqOpCode = bth.opcode
                      & immM31V                     -- immDt (Maybe#IMM)
                      & rkeyM31V;                   -- rkey2Inv (Maybe#RKEY)
         end if;
      end if;

      --------------------------------------------------------------------
      -- SUB-FSM A : pre-stage (preBuildReqInfo / preCalcReqInfo / checkEPSN)
      -- Meters one packet at a time from pktMetaDataPipeIn into f01. Normal
      -- mode only (isNonErr && !hasErrHappened). Field extraction is datapath
      -- (Phase 1); Phase 0 wires the 3-state control + deq/enq handshake.
      --------------------------------------------------------------------
      if (isNonErr = '1' and hasErrHappened = '0') then
         case r.preStageState is
            when RQ_PRE_BUILD_STAGE_S =>
               -- preBuildReqInfo (594): read pktMetaDataPipeIn.first (no deq), parse
               -- BTH/RETH, classify opcode, compute isExpected/isDuplicated, latch.
               if (pktMetaValid = '1') then
                  bthV     := pktMetaData(626 downto 531);   -- extractBTH
                  opcodeV  := bthV(92 downto 88);
                  psnV     := bthV(23 downto 0);
                  dlenV    := pktMetaData(434 downto 403);   -- extractRETH.dlen (default trans)
                  epochV   := getEpoch;
                  isReadReqV := isReadReqOp(opcodeV);
                  -- respPktNum = isReadReq ? truncateLenByPMTU(dlen) : 1
                  respPktNumV := ite(isReadReqV, truncLenPktNum(dlenV, getPMTU),
                                     slv(to_unsigned(1, 25)));
                  -- RdmaReqPktInfo (161b): endPSN/isOnlyRespPkt/isAccCheckPass dontCare here
                  reqPktInfoV := bthV                                                       -- [160:65]
                               & epochV                                                     -- [64]
                               & respPktNumV                                                -- [63:39]
                               & slv(to_unsigned(0, 24))                                    -- [38:15] endPSN
                               & toSl(isSendReqOp(opcodeV))                                 -- [14]
                               & toSl(isWriteReqOp(opcodeV))                                -- [13]
                               & toSl(isWriteImmReqOp(opcodeV))                             -- [12]
                               & toSl(isReadReqV)                                           -- [11]
                               & toSl(isAtomicReqOp(opcodeV))                               -- [10]
                               & toSl(isOnlyOp(opcodeV))                                    -- [9]
                               & toSl(isFirstOp(opcodeV))                                   -- [8]
                               & toSl(isMiddleOp(opcodeV))                                  -- [7]
                               & toSl(isLastOp(opcodeV))                                    -- [6]
                               & toSl(isFirstOrOnlyOp(opcodeV))                             -- [5]
                               & toSl(isLastOrOnlyOp(opcodeV))                              -- [4]
                               & '0'                                                        -- [3] isOnlyRespPkt
                               & toSl(psnV = getEPSN)                                       -- [2] isExpected
                               & toSl(psnInRangeExcl(psnV, oldestValidPsn(getEPSN), getEPSN)) -- [1] isDuplicated
                               & '0';                                                       -- [0] isAccCheckPass
                  v.preStageIsZeroPmtuResidue := toSl(pmtuResidueZero(dlenV, getPMTU));
                  v.preStagePktMetaData := pktMetaData;
                  v.preStageReqPktInfo  := reqPktInfoV;
                  v.preStageState       := RQ_PRE_CALC_STAGE_S;
               end if;
            when RQ_PRE_CALC_STAGE_S =>
               -- preCalcReqInfo (692): totalRespPktNum, isOnlyRespPkt, access check,
               -- reqStatus = pktStatus2ReqStatusRQ (+ getInvReqStatusByTransType on !acc).
               reqPktInfoV := r.preStageReqPktInfo;
               respPktNumV := reqPktInfoV(63 downto 39);
               isReadReqV  := reqPktInfoV(11) = '1';
               transV      := reqPktInfoV(160 downto 158);   -- bth.trans
               totRespPktNumV := ite(r.preStageIsZeroPmtuResidue = '1', respPktNumV,
                                     slv(unsigned(respPktNumV) + 1));
               isOnlyRespPktV := isLessOrEqOne(totRespPktNumV);
               reqPktInfoV(3) := toSl(ite(isReadReqV, isOnlyRespPktV, true));       -- isOnlyRespPkt
               reqPktInfoV(63 downto 39) := ite(isReadReqV, totRespPktNumV, slv(to_unsigned(1, 25)));
               -- access check: send/write->REMOTE_WRITE(bit1); read->REMOTE_READ(bit2); atomic->REMOTE_ATOMIC(bit3)
               if (reqPktInfoV(14) = '1' or reqPktInfoV(13) = '1') then
                  isAccPassV := getAccessFlags(1) = '1';
               elsif (reqPktInfoV(11) = '1') then
                  isAccPassV := getAccessFlags(2) = '1';
               else
                  isAccPassV := getAccessFlags(3) = '1';
               end if;
               if (r.preStagePktMetaData(PMD_PKTSTATUS_C) = '0') then   -- PKT_ST_VALID
                  reqStatusV := ST_NORMAL_C;
               else                                                     -- PKT_ST_LEN_ERR
                  reqStatusV := invReqStatus(transV);
               end if;
               if (reqStatusV = ST_NORMAL_C and not isAccPassV) then
                  reqStatusV := invReqStatus(transV);
               end if;
               reqPktInfoV(0) := toSl(isAccPassV);                      -- isAccCheckPass
               v.preStageReqStatus  := reqStatusV;
               v.preStageReqPktInfo := reqPktInfoV;
               v.preStageState      := RQ_PRE_STAGE_DONE_S;
            when RQ_PRE_STAGE_DONE_S =>
               -- checkEPSN (821): only when retryState == NOT_RETRY. calcNextAndEndPSN,
               -- ePSN check, setEPSN, deq + enq f01 = tuple4(pmd, reqStatus, reqPktInfo, curEPSN).
               if (r.retryState = RQ_NOT_RETRY_S and f01NotFull = '1') then
                  reqStatusV  := r.preStageReqStatus;
                  reqPktInfoV := r.preStageReqPktInfo;
                  bthV        := reqPktInfoV(160 downto 65);
                  psnV        := bthV(23 downto 0);
                  transV      := bthV(95 downto 93);
                  epochV      := reqPktInfoV(64);
                  isReadReqV  := reqPktInfoV(11) = '1';
                  respPktNumV := reqPktInfoV(63 downto 39);
                  isOnlyRespPktV := reqPktInfoV(3) = '1';
                  curEPSNv    := getEPSN;
                  -- calcNextAndEndPSN(psn, respPktNum, isOnlyPkt=isOnlyRespPkt, pmtu[unused])
                  nextPsnV := ite(isOnlyRespPktV, slv(unsigned(psnV) + 1),
                                  slv(resize(unsigned(psnV) + unsigned(respPktNumV), 24)));
                  endPsnV  := ite(isOnlyRespPktV, psnV, slv(unsigned(nextPsnV) - 1));
                  nextEPSNv := curEPSNv;
                  if (epochV = getEpoch) then
                     if (reqStatusV = ST_NORMAL_C and transV /= TRANS_UD_C) then
                        case slv'(reqPktInfoV(2) & reqPktInfoV(1)) is   -- {isExpected, isDuplicated}
                           when "10" =>
                              nextEPSNv  := ite(isReadReqV, nextPsnV, slv(unsigned(psnV) + 1));
                              reqStatusV := ST_NORMAL_C;
                           when "01" =>
                              reqStatusV := ST_DUP_C;
                           when others =>
                              reqStatusV := ST_SEQ_ERR_C;
                        end case;
                     end if;
                  else
                     reqStatusV := ST_DISCARD_C;
                  end if;
                  reqPktInfoV(38 downto 15) := endPsnV;                 -- reqPktInfo.endPSN
                  setEPSNValid <= '1';
                  setEPSNData  <= nextEPSNv;
                  pktMetaDeq   <= '1';
                  f01WrEn      <= '1';
                  f01Din <= r.preStagePktMetaData & reqStatusV & reqPktInfoV & curEPSNv;
                  v.preStageState := RQ_PRE_BUILD_STAGE_S;
               end if;
            when others =>
               v.preStageState := RQ_PRE_BUILD_STAGE_S;
         end case;

         -- retryFlush (3655): DONE stage while a retry is in progress -> discard-enq f01
         if (r.preStageState = RQ_PRE_STAGE_DONE_S and r.retryState /= RQ_NOT_RETRY_S
             and f01NotFull = '1') then
            curEPSNv := getEPSN;
            pktMetaDeq <= '1';
            f01WrEn    <= '1';
            f01Din <= r.preStagePktMetaData & ST_DISCARD_C & r.preStageReqPktInfo & curEPSNv;
            v.preStageState := RQ_PRE_BUILD_STAGE_S;
         end if;
      end if;

      --------------------------------------------------------------------
      -- SUB-FSM B : retry rules (all fire on isNonErr && !hasErrHappened).
      -- retryStart reads v.retryStart* (already written by triggerRNR above)
      -- for the CReg(2) same-cycle forward (OQ-FSM-RHR-02).
      --------------------------------------------------------------------
      if (isNonErr = '1' and hasErrHappened = '0') then
         -- retryStart (3623): consume a pending retry-start request (CReg port 1)
         if (v.retryStartValid = '1' and r.retryState = RQ_NOT_RETRY_S) then
            v.retryState      := v.retryStartState;
            v.retryStartValid := '0';
         end if;
         -- retryStageRnrRetryFlush (3601)
         if (r.retryState = RQ_RNR_RETRY_FLUSH_S) then
            v.retryState := RQ_RNR_WAIT_S;
            v.rnrWaitCnt := RNR_TIMEOUT_C(to_integer(unsigned(r.minRnrTimer)));
            v.isRnrWaitCntZero := '0';
         end if;
         -- retryStageRnrWait (3610)
         if (r.retryState = RQ_RNR_WAIT_S) then
            if (r.isRnrWaitCntZero = '1') then
               v.retryState := RQ_RNR_WAIT_DONE_S;
            else
               v.rnrWaitCnt := slv(unsigned(r.rnrWaitCnt) - 1);
               if (unsigned(r.rnrWaitCnt) = 1) then
                  v.isRnrWaitCntZero := '1';
               end if;
            end if;
         end if;
         -- retryDone (3632): needs preStage in CALC and WAIT_DONE/SEQ_RETRY_FLUSH
         if (r.preStageState = RQ_PRE_CALC_STAGE_S and
             (r.retryState = RQ_RNR_WAIT_DONE_S or r.retryState = RQ_SEQ_RETRY_FLUSH_S)) then
            -- retryFlushDone = reqPktInfo.isExpected && reqPktInfo.epoch == getEpoch
            if (r.preStageReqPktInfo(2) = '1' and r.preStageReqPktInfo(64) = getEpoch) then
               v.retryState := RQ_NOT_RETRY_S;
            end if;
         end if;
      end if;

      --------------------------------------------------------------------
      -- SUB-FSM C : error-flush rules (inErrorState). Exactly one of the
      -- normal pre-stage / errFlush consumers touches pktMetaDataPipeIn per
      -- cycle — inErrorState is mutually exclusive with the normal guard.
      --
      -- Synthetic flush-RR token (errFlushRecvReq), values forced by the
      -- stage-1..31 trace:
      --   pmd: zeros except isZeroPayloadLen='1' (pmd[627]) — keeps stage 17
      --        from issuing a PayloadConReq for the synthetic token.
      --   reqPktInfo: bth=0 (opcode "00000"=SEND_FIRST -> WorkCompGenRq maps
      --        it to a Valid IBV_WC_RECV with isSendReq & isFirstOrOnly, the
      --        errFlushRQ emit condition); epoch := getEpoch (stages 1-4
      --        demote epoch-mismatched tokens to DISCARD); all classifier
      --        flags '0' (every reader is NORMAL/DUP-gated, so an
      --        ERR_FLUSH_RR token skips them).
      --------------------------------------------------------------------
      flushPmdV                      := (others => '0');
      flushPmdV(PMD_ISZEROPAYLOAD_C) := '1';
      flushPktInfoV                  := (others => '0');
      flushPktInfoV(64)              := getEpoch;

      if (inErrorState = '1' and f01NotFull = '1') then
         if (pktMetaValid = '1') then
            -- errFlushIncomingReq (ReqHandleRQ.bsv errFlushIncomingReq):
            -- deq + discard-enq the incoming packet.  reqPktInfo keeps the
            -- real BTH so stage 17 issues the Discard PayloadConReq with the
            -- packet's fragNum/psn (the payload must be sunk; the
            -- PayloadConsumer rules stay active under isErr).
            pktMetaDeq <= '1';
            f01WrEn    <= '1';
            f01Din     <= pktMetaData & ST_DISCARD_C
                          & pktMetaData(626 downto 531)   -- reqPktInfo.bth
                          & flushPktInfoV(64 downto 0)    -- epoch & zeros
                          & getEPSN;
         elsif (recvReqValid = '1') then
            -- errFlushRecvReq (ReqHandleRQ.bsv errFlushRecvReq): synthesize
            -- one flush-RR token; stage 3's ERR_FLUSH_RR branch deqs one recv
            -- WR per token and stage 31 + WorkCompGenRq.errFlushRQ complete
            -- it as IBV_WC_WR_FLUSH_ERR, letting recvReqValid fall so QP
            -- DESTROY can complete (qp-destroy-hang-issue.md).
            -- DEVIATION-RHR-01 (2026-07-13): gated on recvReqValid — upstream
            -- blue-rdma fires unconditionally, pushing a token down the
            -- 32-stage pipe every cycle for as long as the QP sits in ERR.
            -- Stages advance on workerEnable without needing head input, so
            -- gating loses no flush coverage; surplus in-flight tokens that
            -- miss the recvReq still terminate safely (Invalid rrID ->
            -- genMaybeTag=0 in WorkCompGenRq.errFlushRQ -> dropped).
            f01WrEn <= '1';
            f01Din  <= flushPmdV & ST_ERR_FLUSH_RR_C & flushPktInfoV & getEPSN;
         end if;
      end if;

      --------------------------------------------------------------------
      -- resetAndClear (isReset): synchronous clear of control state. FIFOs are
      -- cleared via fifoClr; CountCF via its own write/clear. (BSV line 530)
      --------------------------------------------------------------------
      if (isReset = '1') then
         v.retryState               := RQ_NOT_RETRY_S;
         v.retryStartValid          := '0';
         v.preStageState            := RQ_PRE_BUILD_STAGE_S;
         v.hasReqStatusErr          := '0';
         v.hasDmaReadRespErr        := '0';
         v.hasErrRespGen            := '0';
         v.isFirstOrOnlyRespPkt     := '1';
         v.coalesceWorkReqCnt       := COALESCE_INIT_C;
         v.isCoalesceWorkReqCntZero := '0';
         -- pendingDestReadAtomicReqCnt <= 0 : drive CountCF write port
         ccWriteEn  <= '1';
         ccWriteVal <= (others => '0');
      end if;

      -- Synchronous reset (SURF rst port) dominates
      if (rst = '1') then
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
