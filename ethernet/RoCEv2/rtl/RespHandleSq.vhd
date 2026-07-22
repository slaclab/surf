-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   The SQ response-handling datapath: an 11-stage linear pipeline of SURF FIFOs
--   (incomingRespQ -> pendingRespQ -> ... -> pendingWorkCompQ -> workCompGenReqOutQ)
--   wrapped around (a) a 3-state pre-stage control FSM (preStageState) that builds
--   incoming-response tokens from the pendingWorkReq + pktMetaData inputs, and
--   (b) a deferred error/retry/timeout sub-FSM expressed as mode flags
--   (recvErrResp/recvRetryResp/errOccurred/retryFlush + 2 CRegs).
--
--   ⚑S3 (OQ-PART-02) RESOLVED: KEEP FUSED — the err/retry control is threaded
--   through scalar/CReg registers written on both sides of the proposed cut, so a
--   split cannot preserve the same-cycle CReg ordering. ONE entity, one RegType;
--   the sub-FSM block is delimited in RegType below.
--
--   Mode signals (combinational from r):
--     inNormalState = (not retryFlush) and (not errOccurred) and (not recvErrResp)
--     inRetryState  = retryFlush and (not errOccurred) and (not recvErrResp)
--     inErrState    = errOccurred or isERR
--     inErrStateAlt = (isRTS and (recvErrResp or errOccurred)) or isERR
--
--   Cross-stage server handshakes (OQ-S3-RESP-01, in-order assumed): retryHandler
--   srvPort request issued in handleRespByType, response consumed in checkRetryErr;
--   permCheckSrv request in queryPerm4NormalReadAtomicResp, response in
--   checkPerm4NormalReadAtomicResp. Modelled as valid/ready (req) + valid/getEn
--   (resp) ports; the consuming stage's firing is gated on resp-valid only on the
--   branch that actually consumes the response (conditional implicit condition).
--
--   CReg(2) ordering (OQ-S3-RESP-02): hasInternalErr port0 written by issueDmaReq,
--   port1 read+cleared by canonicalize SAME cycle; hasTimeOutErr port0 written by
--   checkTimeOutErr / read+cleared by errFlushWorkReq, port1 read by canonicalize.
--   In comb: all port0 writers run BEFORE canonicalize (port1 read of v.*).
--
--   FIFO clear: BSV FIFOF.clear under resetAndClear -> fifoClr = rst or isReset
--   asserted to every Fifo rst (level-safe sync clear; OQ-FSM-01 carry-forward).
--
--   SURF components instantiated (source: surf/base/fifo/rtl/Fifo.vhd), all
--   surf.Fifo FWFT/sync/block, DATA_WIDTH_G = tuple width, ADDR_WIDTH_G=4:
--     U_IncomingRespQ      1470  U_PendingRespQ        1473  U_PendingPermQueryQ 1469
--     U_PendingRetryCheckQ 1470  U_PendingPermCheckQ   1476  U_PendingAddrCalcQ  1475
--     U_PendingLenCalcQ    1539  U_PendingSpaceCalcQ   1605  U_PendingLenCheckQ  1573
--     U_PendingDmaReqQ     1539  U_PendingWorkCompQ     768  U_WorkCompGenReqOutQ 633
--
--   Type widths (BSV deriving(Bits), first-field-at-MSB; traced from
--   DataTypes.bsv/Headers.bsv): PendingWorkReq=679 (wr[678:78]; startPSN.val
--   [76:53]; endPSN.val [51:28]; wr.id [678:615]; wr.opcode [614:611]; wr.flags
--   [610:606] (signaled=bit1=[607]); wr.len [509:478]; wr.laddr [477:414];
--   wr.lkey [413:382]). RdmaPktMetaData=649 (pktPayloadLen [648:636]; pktFragNum
--   [635:628]; isZeroPayloadLen [627]; pktHeader [626:34]; pdHandler [33:2];
--   pktValid [1]; pktStatus [0]; within header headerData=[626:115], extractBTH=
--   [626:531], extractAETH=[530:499], extractAtomicAckEth=[498:435]; bth.opcode=
--   [623:619], bth.psn=[554:531]; aeth.code=[529:528], aeth.value=[527:523]).
--   RespPktInfo=135 (bth[134:39]|aeth[38:7]|isFirstOrOnly[6]|isLastOrOnly[5]|
--   isReadResp[4]|isAtomicResp[3]|hasLocalErr[2]|shouldDiscard[1]|genWorkComp[0]).
--   WorkCompGenReqSQ=633 (wr[632:32]|wcWaitDmaResp[31]|wcReqType[30:29]|
--   triggerPSN[28:5]|wcStatus[4:0]). RespLenCheckResult=98 (enoughDmaSpace[97]|
--   isLastPayloadLenZero[96]|nextAddr[95:32]|remLen[31:0]). Maybe#WorkCompStatus=6
--   (tag[5]|status[4:0]). PermCheckReq=267, RetryReq=97, PayloadConReq=203.
--
--   Excluded/Deferred (see OPEN_QUESTIONS.md OQ-RHSQ-04..07): BSV immAsserts are
--   simulation-only and are NOT reproduced here; mkRegU latches zero-initialised;
--   permCheckReq.accFlags local-write encoding confirmed against PermCheckSrv;
--   the two server in-order/bounded-latency assumptions (OQ-S3-RESP-01).
--
--   DEVIATION-SQQP-01 (2026-07-08, SQ retry partial-replay fix; see
--   SqQueuePair.vhd header): new input pendingWrDeqAllowed (default '1')
--   restores mkScanFIFOF.deq's implicit condition — no pending-WR pop while
--   the scan buffer is in PRE_SCAN mode. Enforced at the two pop sites
--   (pre-stage DONE commit, errFlushWorkReq); the whole stage stalls, exactly
--   like the guarded BSV rule.
--
--   DEVIATION-RHSQ-02 (2026-07-21): enforce PSN continuity across multi-packet
--   READ responses. Opcode sequencing alone cannot detect a lost middle
--   response because READ_RESP_MIDDLE followed by READ_RESP_MIDDLE is legal.
--   On a PSN gap, discard the out-of-order packet and request an implicit
--   partial retry from the missing PSN, preventing its payload from being
--   DMA-written at the missing packet's destination address.
--   Keep a separate replay-pending barrier after retryFlush drops: response
--   packets already queued in this entity retain their original NORMAL action
--   and would otherwise complete a later WR.  Until the missing PSN returns as
--   the exact missing PSN, those stale responses are forced to DISCARD.  A
--   partial READ replay preserves the original response position/opcode (for
--   example, a missing MIDDLE returns as MIDDLE rather than FIRST).
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

entity RespHandleSq is
   generic (
      TPD_G     : time    := 1 ns;
      -- false = no RDMA READ/atomic support: read/atomic-response classifiers
      -- are forced false so all read-response landing logic constant-folds
      -- (software contract: never post READ/atomic work requests).
      EN_READ_G : boolean := true);
   port (
      clk                : in  sl;
      rst                : in  sl;                  -- active-high synchronous reset
      -- contextSQ.statusSQ.comm status methods (combinational inputs)
      isReset            : in  sl;                  -- isReset  -> resetAndClear
      isRTS              : in  sl;                  -- isRTS
      isERR              : in  sl;                  -- isERR
      isStableRTS        : in  sl;                  -- isStableRTS
      getPMTU            : in  slv(2 downto 0);     -- PMTU enum (256="001"..4096="101")
      getSQPN            : in  slv(23 downto 0);    -- getSQPN
      getNPSN            : in  slv(23 downto 0);    -- getNPSN
      -- pendingWorkReqPipeIn : PipeOut#(PendingWorkReq) (679b)
      pendingWrValid     : in  sl;                  -- notEmpty
      pendingWrData      : in  slv(678 downto 0);   -- first
      pendingWrDeq       : out sl;                  -- deq
      -- DEVIATION-SQQP-01: deq implicit condition. mkScanFIFOF.deq is guarded
      -- (!isEmpty && (inFifoMode || inScanMode)) (SpecialFIFOF.bsv:430): a pop
      -- must never land while the buffer is in PRE_SCAN, or it shifts the head
      -- under RetryHandleSq's getHead/modifyHead and shrinks the retry
      -- snapshot. Drive with (not ScanFifoF.inPreScan); default '1' keeps
      -- standalone TBs unchanged. A stage that wants to pop stalls whole
      -- (pktMetaDeq + incomingRespQ enq held together) until allowed.
      pendingWrDeqAllowed : in sl := '1';
      -- pktMetaDataPipeIn : PipeOut#(RdmaPktMetaData) (649b)
      pktMetaValid       : in  sl;                  -- notEmpty
      pktMetaData        : in  slv(648 downto 0);   -- first
      pktMetaDeq         : out sl;                  -- deq
      -- payloadConReqPort : Put#(PayloadConReq) (203b)
      payloadConReqValid : out sl;                  -- put valid
      payloadConReqData  : out slv(202 downto 0);   -- put data (PayloadConReq)
      payloadConReqReady : in  sl;                  -- put ready (consumer not full)
      -- retryHandler.resetRetryCntAndTimeOutBySQ : Action(ResetRetryCntAndTimeOutReq)
      retryResetValid    : out sl;
      retryResetData     : out sl;                  -- 1b enum
      retryResetReady    : in  sl;
      -- retryHandler.srvPort.request : Put#(RetryReq) (97b)
      retryReqValid      : out sl;
      retryReqData       : out slv(96 downto 0);
      retryReqReady      : in  sl;
      -- retryHandler.srvPort.response : Get#(RetryResp) (2b)
      retryRespValid     : in  sl;
      retryRespData      : in  slv(1 downto 0);     -- bit0: RETRY_LIMIT_EXC='1'; bit1: reason was RNR
      retryRespGetEn     : out sl;
      -- retryHandler.notifyTimeOut2SQ : Get#(TimeOutNotification) (1b)
      timeOutValid       : in  sl;
      timeOutData        : in  sl;                  -- TIMEOUT_ERR='1'
      timeOutGetEn       : out sl;
      -- retryHandler.isRetrying : Bool method
      isRetrying         : in  sl;
      -- permCheckSrv.request : Put#(PermCheckReq) (267b)
      permReqValid       : out sl;
      permReqData        : out slv(266 downto 0);
      permReqReady       : in  sl;
      -- permCheckSrv.response : Get#(Bool) (1b)
      permRespValid      : in  sl;
      permRespData       : in  sl;                  -- mrCheckResult
      permRespGetEn      : out sl;
      -- workCompGenReqPipeOut : PipeOut#(WorkCompGenReqSQ) (633b)
      wcGenReqValid      : out sl;                  -- notEmpty
      wcGenReqData       : out slv(632 downto 0);   -- first
      wcGenReqRdEn       : in  sl);                 -- deq (downstream drives)
end entity RespHandleSq;

architecture rtl of RespHandleSq is

   ---------------------------------------------------------------------------
   -- Pre-stage control FSM state
   ---------------------------------------------------------------------------
   type StateType is (SQ_PRE_BUILD_STAGE_S, SQ_PRE_PROC_STAGE_S, SQ_PRE_STAGE_DONE_S);

   ---------------------------------------------------------------------------
   -- RegType : ONE record (fused). Sub-FSM block delimited below.
   ---------------------------------------------------------------------------
   type RegType is record
      -- (a) pre-stage control FSM
      preStageState                  : StateType;
      -- (b) pre-stage latch registers (mkRegU — no reset; zero-init for determinism)
      preStageRespAndWorkReqRelation : slv(4 downto 0);
      preStagePktMetaData            : slv(648 downto 0);
      preStageReqPktInfo             : slv(134 downto 0);
      preStageRespType               : slv(1 downto 0);
      preStageDeqPktMetaData         : sl;
      preStageDeqPendingWorkReq      : sl;
      preStageWorkReqAckType         : slv(3 downto 0);
      preStageWorkCompReqType        : slv(1 downto 0);
      retryResetReq                  : sl;                 -- ResetRetryCntAndTimeOutReq (1b)
      -- (c) pipeline accumulators
      preRdmaOpCode                  : slv(4 downto 0);    -- reset ACKNOWLEDGE
      preNextReadRespPsn             : slv(23 downto 0);   -- earliest/pre-stage continuity tracker
      preReadRespPsnValid            : sl;
      nextReadRespPsn                : slv(23 downto 0);   -- next in-order READ response PSN
      nextReadRespPsnValid           : sl;
      readGapInFlight                : sl;                 -- gap packet is moving to retry handler
      readReplayPending              : sl;                 -- discard stale responses until missing PSN
      remainingReadRespLen           : slv(31 downto 0);   -- mkRegU
      nextReadRespWriteAddr          : slv(63 downto 0);   -- mkRegU
      readRespPktNum                 : slv(24 downto 0);   -- mkRegU
      -- (d) ⚑ DEFERRED-SUB-FSM block — error/retry/timeout mode flags
      recvErrResp                    : sl;
      recvRetryResp                  : sl;
      errOccurred                    : sl;
      retryFlush                     : sl;
      hasInternalErr                 : sl;                 -- mkCReg(2)
      hasTimeOutErr                  : sl;                 -- mkCReg(2)
   end record RegType;

   constant ACKNOWLEDGE_C : slv(4 downto 0) := "10001";   -- RdmaOpCode ACKNOWLEDGE = 0x11

   constant REG_INIT_C : RegType := (
      preStageState                  => SQ_PRE_BUILD_STAGE_S,
      preStageRespAndWorkReqRelation => (others => '0'),
      preStagePktMetaData            => (others => '0'),
      preStageReqPktInfo             => (others => '0'),
      preStageRespType               => (others => '0'),
      preStageDeqPktMetaData         => '0',
      preStageDeqPendingWorkReq      => '0',
      preStageWorkReqAckType         => (others => '0'),
      preStageWorkCompReqType        => (others => '0'),
      retryResetReq                  => '0',
      preRdmaOpCode                  => ACKNOWLEDGE_C,
      preNextReadRespPsn             => (others => '0'),
      preReadRespPsnValid            => '0',
      nextReadRespPsn                => (others => '0'),
      nextReadRespPsnValid           => '0',
      readGapInFlight                => '0',
      readReplayPending              => '0',
      remainingReadRespLen           => (others => '0'),
      nextReadRespWriteAddr          => (others => '0'),
      readRespPktNum                 => (others => '0'),
      recvErrResp                    => '0',
      recvRetryResp                  => '0',
      errOccurred                    => '0',
      retryFlush                     => '0',
      hasInternalErr                 => '0',
      hasTimeOutErr                  => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   ---------------------------------------------------------------------------
   -- Enum encodings
   ---------------------------------------------------------------------------
   -- RdmaRespType (2b)
   constant RESP_NORMAL_C : slv(1 downto 0) := "00";
   constant RESP_RETRY_C  : slv(1 downto 0) := "01";
   constant RESP_ERROR_C  : slv(1 downto 0) := "10";
   constant RESP_UNK_C    : slv(1 downto 0) := "11";
   -- WorkReqAckType (4b)
   constant WRA_EWN_C   : slv(3 downto 0) := x"0";  -- EXPLICIT_WHOLE_NORMAL
   constant WRA_EWR_C   : slv(3 downto 0) := x"1";  -- EXPLICIT_WHOLE_RETRY
   constant WRA_EWE_C   : slv(3 downto 0) := x"2";  -- EXPLICIT_WHOLE_ERROR
   constant WRA_EPN_C   : slv(3 downto 0) := x"3";  -- EXPLICIT_PARTIAL_NORMAL
   constant WRA_EPR_C   : slv(3 downto 0) := x"4";  -- EXPLICIT_PARTIAL_RETRY
   constant WRA_EPE_C   : slv(3 downto 0) := x"5";  -- EXPLICIT_PARTIAL_ERROR
   constant WRA_CN_C    : slv(3 downto 0) := x"6";  -- COALESCE_NORMAL
   constant WRA_CR_C    : slv(3 downto 0) := x"7";  -- COALESCE_RETRY
   constant WRA_DUP_C   : slv(3 downto 0) := x"8";  -- DUPLICATE
   constant WRA_GHOST_C : slv(3 downto 0) := x"9";  -- GHOST
   constant WRA_ILL_C   : slv(3 downto 0) := x"A";  -- ILLEGAL
   constant WRA_DISC_C  : slv(3 downto 0) := x"B";  -- DISCARD
   constant WRA_FLUSH_C : slv(3 downto 0) := x"C";  -- ERR_FLUSH_WR
   constant WRA_TMOUT_C : slv(3 downto 0) := x"D";  -- TIMOUT_ERR
   constant WRA_UNK_C   : slv(3 downto 0) := x"E";  -- UNKNOWN
   -- RespActionSQ (4b)
   constant ACT_BAD_C       : slv(3 downto 0) := x"0";
   constant ACT_COALESCE_C  : slv(3 downto 0) := x"1";
   constant ACT_ERROR_C     : slv(3 downto 0) := x"2";
   constant ACT_EXP_NORM_C  : slv(3 downto 0) := x"3";
   constant ACT_DISCARD_C   : slv(3 downto 0) := x"4";
   constant ACT_DUP_C       : slv(3 downto 0) := x"5";
   constant ACT_ILLEGAL_C   : slv(3 downto 0) := x"6";
   constant ACT_FLUSH_WR_C  : slv(3 downto 0) := x"7";
   constant ACT_TIMEOUT_C   : slv(3 downto 0) := x"8";
   constant ACT_EXP_RETRY_C : slv(3 downto 0) := x"9";
   constant ACT_IMP_RETRY_C : slv(3 downto 0) := x"A";
   constant ACT_LOC_ACC_C   : slv(3 downto 0) := x"B";
   constant ACT_LOC_LEN_C   : slv(3 downto 0) := x"C";
   constant ACT_UNK_C       : slv(3 downto 0) := x"D";
   -- WorkCompReqType (2b)
   constant WC_FULL_C : slv(1 downto 0) := "00";
   constant WC_PART_C : slv(1 downto 0) := "01";
   constant WC_NO_C   : slv(1 downto 0) := "10";
   constant WC_UNK_C  : slv(1 downto 0) := "11";
   -- ResetRetryCntAndTimeOutReq (1b)
   constant RESET_TIMEOUT_C   : sl := '0';
   constant RESET_CNT_TMO_C   : sl := '1';
   -- WorkCompStatus (5b)
   constant WCS_SUCCESS_C      : slv(4 downto 0) := "00000";  -- 0
   constant WCS_LOC_LEN_C      : slv(4 downto 0) := "00001";  -- 1
   constant WCS_WR_FLUSH_C     : slv(4 downto 0) := "00101";  -- 5
   constant WCS_BAD_RESP_C     : slv(4 downto 0) := "00111";  -- 7
   constant WCS_LOC_ACC_C      : slv(4 downto 0) := "01000";  -- 8
   constant WCS_REM_INV_REQ_C  : slv(4 downto 0) := "01001";  -- 9
   constant WCS_REM_ACC_C      : slv(4 downto 0) := "01010";  -- 10
   constant WCS_REM_OP_C       : slv(4 downto 0) := "01011";  -- 11
   constant WCS_RETRY_EXC_C    : slv(4 downto 0) := "01100";  -- 12
   constant WCS_RNR_RETRY_EXC_C : slv(4 downto 0) := "01101"; -- 13
   constant WCS_REM_INV_RD_C   : slv(4 downto 0) := "01111";  -- 15
   constant WCS_RESP_TMOUT_C   : slv(4 downto 0) := "10100";  -- 20
   -- RdmaOpCode (5b) — relevant codes
   constant OP_WRITE_ONLY_C     : slv(4 downto 0) := "01010"; -- 10 (unused here)
   -- AethCode (2b)
   constant AETH_ACK_C : slv(1 downto 0) := "00";
   constant AETH_RNR_C : slv(1 downto 0) := "01";
   constant AETH_NAK_C : slv(1 downto 0) := "11";
   -- AETH NAK values (5b)
   constant NAK_SEQ_C     : slv(4 downto 0) := "00000"; -- 0
   constant NAK_INV_REQ_C : slv(4 downto 0) := "00001"; -- 1
   constant NAK_RMT_ACC_C : slv(4 downto 0) := "00010"; -- 2
   constant NAK_RMT_OP_C  : slv(4 downto 0) := "00011"; -- 3
   constant NAK_INV_RD_C  : slv(4 downto 0) := "00100"; -- 4
   -- DmaReqSrcType (4b)
   constant DMA_SQ_WR_C   : slv(3 downto 0) := x"6";
   constant DMA_SQ_ATOM_C : slv(3 downto 0) := x"7";
   constant DMA_SQ_DISC_C : slv(3 downto 0) := x"8";
   -- PermCheck access flags (FlagsType#(MemAccessTypeFlag), 8b): IBV_ACCESS_LOCAL_WRITE
   constant ACC_LOCAL_WRITE_C : slv(7 downto 0) := x"01";  -- see OQ-RHSQ-07
   -- zero-fill constants for dontCare / union padding
   constant ZERO_PWR_C : slv(678 downto 0) := (others => '0');
   constant ZERO64_C   : slv(63 downto 0)  := (others => '0');
   constant ZERO32_C   : slv(31 downto 0)  := (others => '0');

   ---------------------------------------------------------------------------
   -- FIFO interface signals (one bundle per surf.Fifo)
   ---------------------------------------------------------------------------
   signal incWrEn, incRdEn, incValid, incNotFull : sl;
   signal incDin, incDout                        : slv(1469 downto 0);
   signal prsWrEn, prsRdEn, prsValid, prsNotFull : sl;
   signal prsDin, prsDout                        : slv(1472 downto 0);
   signal pqWrEn, pqRdEn, pqValid, pqNotFull     : sl;
   signal pqDin, pqDout                          : slv(1468 downto 0);
   signal prcWrEn, prcRdEn, prcValid, prcNotFull : sl;
   signal prcDin, prcDout                        : slv(1469 downto 0);
   signal ppcWrEn, ppcRdEn, ppcValid, ppcNotFull : sl;
   signal ppcDin, ppcDout                        : slv(1475 downto 0);
   signal pacWrEn, pacRdEn, pacValid, pacNotFull : sl;
   signal pacDin, pacDout                        : slv(1474 downto 0);
   signal plcWrEn, plcRdEn, plcValid, plcNotFull : sl;
   signal plcDin, plcDout                        : slv(1538 downto 0);
   signal pscWrEn, pscRdEn, pscValid, pscNotFull : sl;
   signal pscDin, pscDout                        : slv(1604 downto 0);
   signal plkWrEn, plkRdEn, plkValid, plkNotFull : sl;
   signal plkDin, plkDout                        : slv(1572 downto 0);
   signal pdrWrEn, pdrRdEn, pdrValid, pdrNotFull : sl;
   signal pdrDin, pdrDout                        : slv(1538 downto 0);
   signal pwcWrEn, pwcRdEn, pwcValid, pwcNotFull : sl;
   signal pwcDin, pwcDout                        : slv(767 downto 0);
   signal outWrEn, outValid, outNotFull          : sl;
   signal outDin, outDout                        : slv(632 downto 0);

   signal fifoClr : sl;

   ---------------------------------------------------------------------------
   -- Helper functions (BSV Utils.bsv equivalents)
   ---------------------------------------------------------------------------
   -- RdmaOpCode classifiers (5b opcode)
   function isFirstOp(op : slv(4 downto 0)) return boolean is
   begin
      return op = "00000" or op = "00110" or op = "01101";  -- SEND_FIRST/WRITE_FIRST/READ_RESP_FIRST
   end function;
   function isMidOp(op : slv(4 downto 0)) return boolean is
   begin
      return op = "00001" or op = "00111" or op = "01110";  -- SEND_MIDDLE/WRITE_MIDDLE/READ_RESP_MIDDLE
   end function;
   function isLastOp(op : slv(4 downto 0)) return boolean is
   begin
      return op = "00010" or op = "00011" or op = "10110" or  -- SEND_LAST/_IMM/_INV
             op = "01000" or op = "01001" or                  -- WRITE_LAST/_IMM
             op = "01111";                                    -- READ_RESP_LAST
   end function;
   function isOnlyOp(op : slv(4 downto 0)) return boolean is
   begin
      return op = "00100" or op = "00101" or op = "10111" or  -- SEND_ONLY/_IMM/_INV
             op = "01010" or op = "01011" or                  -- WRITE_ONLY/_IMM
             op = "01100" or op = "10011" or op = "10100" or  -- READ_REQUEST/COMPARE_SWAP/FETCH_ADD
             op = "10000" or op = "10001" or op = "10010";    -- READ_RESP_ONLY/ACK/ATOMIC_ACK
   end function;
   -- EN_READ_G=false forces both classifiers false: rpi isReadResp/isAtomicResp
   -- bits become constant '0' and synthesis prunes the read-response datapath
   -- (calcReadRespAddr/calcReadRespLen/checkReadRespLen, DMA-write issue, perm
   -- queries); a real read response then falls into the RESP_UNK_C branch.
   function isReadRespOp(op : slv(4 downto 0)) return boolean is
   begin
      return EN_READ_G and
             (op = "01101" or op = "01110" or op = "01111" or op = "10000");
   end function;
   function isAtomicRespOp(op : slv(4 downto 0)) return boolean is
   begin
      return EN_READ_G and (op = "10010");  -- ATOMIC_ACKNOWLEDGE
   end function;
   function isFirstOrOnlyOp(op : slv(4 downto 0)) return boolean is
   begin
      return isFirstOp(op) or isOnlyOp(op);
   end function;
   function isLastOrOnlyOp(op : slv(4 downto 0)) return boolean is
   begin
      return isLastOp(op) or isOnlyOp(op);
   end function;
   -- WorkReqOpCode classifiers (4b)
   function isReadOrAtomicWR(op : slv(3 downto 0)) return boolean is
   begin
      return op = x"4" or op = x"5" or op = x"6";  -- RDMA_READ/CMP_SWP/FETCH_ADD
   end function;
   function rdmaRespMatchWR(rop : slv(4 downto 0); wop : slv(3 downto 0)) return boolean is
   begin
      if rop = "01101" or rop = "01110" or rop = "01111" or rop = "10000" then  -- READ_RESP_*
         return wop = x"4";                                                     -- RDMA_READ
      elsif rop = "10010" then                                                  -- ATOMIC_ACK
         return wop = x"5" or wop = x"6";
      elsif rop = "10001" then                                                  -- ACKNOWLEDGE
         return true;
      else
         return false;
      end if;
   end function;
   function checkRespOpSeq(preOp, curOp : slv(4 downto 0)) return boolean is
   begin
      if preOp = "01101" or preOp = "01110" then          -- READ_RESP_FIRST/MIDDLE
         return curOp = "01110" or curOp = "01111";       -- MIDDLE/LAST
      elsif preOp = "01111" or preOp = "10000" or preOp = "10001" or preOp = "10010" then
         return true;                                     -- READ_RESP_LAST/ONLY/ACK/ATOMIC_ACK
      else
         return false;
      end if;
   end function;
   -- calcPmtuLen -> PktLen(13)
   function calcPmtuLen(pmtu : slv(2 downto 0)) return unsigned is
      variable v : unsigned(12 downto 0);
   begin
      case pmtu is
         when "001"  => v := to_unsigned(256, 13);
         when "010"  => v := to_unsigned(512, 13);
         when "011"  => v := to_unsigned(1024, 13);
         when "100"  => v := to_unsigned(2048, 13);
         when others => v := to_unsigned(4096, 13);  -- IBV_MTU_4096 (and default)
      end case;
      return v;
   end function;
   -- pmtu log2 (shift split point): 256->8 .. 4096->12
   function pmtuLog(pmtu : slv(2 downto 0)) return integer is
   begin
      case pmtu is
         when "001"  => return 8;
         when "010"  => return 9;
         when "011"  => return 10;
         when "100"  => return 11;
         when others => return 12;
      end case;
   end function;
   -- addrAddPsnMultiplyPMTU = addr + (psn << log2(PMTU))  (high-part add; BSV form)
   function addrAddPsn(addr : slv(63 downto 0); psn : slv(23 downto 0); pmtu : slv(2 downto 0)) return slv is
   begin
      return slv(unsigned(addr) + shift_left(resize(unsigned(psn), 64), pmtuLog(pmtu)));
   end function;
   -- lenSubtractPsnMultiplyPMTU = len - (psn << log2(PMTU))
   function lenSubPsn(len : slv(31 downto 0); psn : slv(23 downto 0); pmtu : slv(2 downto 0)) return slv is
   begin
      return slv(unsigned(len) - shift_left(resize(unsigned(psn), 32), pmtuLog(pmtu)));
   end function;
   -- lenSubtractPktLen: { len[31:k+1], len[k:0]-pktLen } (low-part subtract, no borrow up)
   function lenSubPktLen(len : slv(31 downto 0); pktLen : slv(12 downto 0); pmtu : slv(2 downto 0)) return slv is
   begin
      case pmtu is
         when "001"  => return len(31 downto 9)  & slv(unsigned(len(8 downto 0))  - resize(unsigned(pktLen), 9));
         when "010"  => return len(31 downto 10) & slv(unsigned(len(9 downto 0))  - resize(unsigned(pktLen), 10));
         when "011"  => return len(31 downto 11) & slv(unsigned(len(10 downto 0)) - resize(unsigned(pktLen), 11));
         when "100"  => return len(31 downto 12) & slv(unsigned(len(11 downto 0)) - resize(unsigned(pktLen), 12));
         when others => return len(31 downto 13) & slv(unsigned(len(12 downto 0)) - unsigned(pktLen));
      end case;
   end function;
   -- lenGtEqPktLen: (len >= 2^(k+1)) or (len[k:0] >= pktLen[k:0])
   function lenGtEqPktLen(len : slv(31 downto 0); pktLen : slv(12 downto 0); pmtu : slv(2 downto 0)) return boolean is
   begin
      case pmtu is
         when "001"  => return (unsigned(len(31 downto 9))  /= 0) or (unsigned(len(8 downto 0))  >= unsigned(pktLen(8 downto 0)));
         when "010"  => return (unsigned(len(31 downto 10)) /= 0) or (unsigned(len(9 downto 0))  >= unsigned(pktLen(9 downto 0)));
         when "011"  => return (unsigned(len(31 downto 11)) /= 0) or (unsigned(len(10 downto 0)) >= unsigned(pktLen(10 downto 0)));
         when "100"  => return (unsigned(len(31 downto 12)) /= 0) or (unsigned(len(11 downto 0)) >= unsigned(pktLen(11 downto 0)));
         when others => return (unsigned(len(31 downto 13)) /= 0) or (unsigned(len(12 downto 0)) >= unsigned(pktLen));
      end case;
   end function;
   -- lenGtEqPMTU: len >= 2^log2(PMTU)
   function lenGtEqPMTU(len : slv(31 downto 0); pmtu : slv(2 downto 0)) return boolean is
   begin
      return unsigned(len) >= shift_left(to_unsigned(1, 40), pmtuLog(pmtu));
   end function;
   -- getRetryReasonFromAETH / IMPLICIT -> RetryReason(3b)
   function getRetryReason(respAct, aCode, aVal : slv) return slv is
   begin
      if respAct = "1010" then          -- SQ_ACT_IMPLICIT_RETRY
         return "011";                  -- RETRY_REASON_IMPLICIT
      elsif aCode = "01" then           -- AETH_CODE_RNR
         return "001";                  -- RETRY_REASON_RNR
      elsif (aCode = "11") and (aVal = "00000") then  -- NAK SEQ_ERR
         return "010";                  -- RETRY_REASON_SEQ_ERR
      else
         return "000";                  -- RETRY_REASON_NOT_RETRY
      end if;
   end function;
   -- Maybe#(RnrTimer) (tag|5b): Valid aeth.value iff reason==RNR (explicit retry, RNR code)
   function getRnrTimer(respAct, aCode, aVal : slv) return slv is
   begin
      if (respAct = "1001") and (aCode = "01") then  -- EXPLICIT_RETRY & RNR
         return '1' & aVal;
      else
         return "000000";
      end if;
   end function;
   -- genErrWorkCompStatusFromAethSQ -> Maybe#(WorkCompStatus) (tag|5b)
   function genErrWcStatusFromAeth(aCode : slv(1 downto 0); aVal : slv(4 downto 0)) return slv is
   begin
      if aCode = "11" then              -- AETH_CODE_NAK
         case aVal is
            when "00001" => return '1' & "01001";  -- INV_REQ -> REM_INV_REQ_ERR(9)
            when "00010" => return '1' & "01010";  -- RMT_ACC -> REM_ACCESS_ERR(10)
            when "00011" => return '1' & "01011";  -- RMT_OP  -> REM_OP_ERR(11)
            when "00100" => return '1' & "01111";  -- INV_RD  -> REM_INV_RD_REQ_ERR(15)
            when others  => return "000000";
         end case;
      else
         return "000000";
      end if;
   end function;
   -- psnInRangeExclusive(psn, start, end) — 24b PSN wrap-aware
   function psnInRange(psn, ps, pe : slv(23 downto 0)) return boolean is
      variable gtStart, ltEnd : boolean;
   begin
      gtStart := unsigned(ps) < unsigned(psn);
      ltEnd   := unsigned(psn) < unsigned(pe);
      if ps(23) = pe(23) then
         return gtStart and ltEnd;
      else
         return (gtStart and (ps(23) = psn(23))) or (ltEnd and (psn(23) = pe(23)));
      end if;
   end function;

begin

   fifoClr <= rst or isReset;

   -- workCompGenReqPipeOut read face (downstream drives rd_en)
   wcGenReqValid <= outValid;
   wcGenReqData  <= outDout;

   ---------------------------------------------------------------------------
   -- 12 SURF Fifo instances (all FWFT/sync/block; cleared by fifoClr)
   ---------------------------------------------------------------------------
   U_IncomingRespQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 1470,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoClr,
         wr_clk        => clk,
         wr_en         => incWrEn,
         din           => incDin,
         not_full      => incNotFull,
         full          => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => incRdEn,
         dout          => incDout,
         valid         => incValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   U_PendingRespQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 1473,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoClr,
         wr_clk        => clk,
         wr_en         => prsWrEn,
         din           => prsDin,
         not_full      => prsNotFull,
         full          => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => prsRdEn,
         dout          => prsDout,
         valid         => prsValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   U_PendingPermQueryQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 1469,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoClr,
         wr_clk        => clk,
         wr_en         => pqWrEn,
         din           => pqDin,
         not_full      => pqNotFull,
         full          => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => pqRdEn,
         dout          => pqDout,
         valid         => pqValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   U_PendingRetryCheckQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 1470,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoClr,
         wr_clk        => clk,
         wr_en         => prcWrEn,
         din           => prcDin,
         not_full      => prcNotFull,
         full          => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => prcRdEn,
         dout          => prcDout,
         valid         => prcValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   U_PendingPermCheckQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 1476,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoClr,
         wr_clk        => clk,
         wr_en         => ppcWrEn,
         din           => ppcDin,
         not_full      => ppcNotFull,
         full          => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => ppcRdEn,
         dout          => ppcDout,
         valid         => ppcValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   U_PendingAddrCalcQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 1475,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoClr,
         wr_clk        => clk,
         wr_en         => pacWrEn,
         din           => pacDin,
         not_full      => pacNotFull,
         full          => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => pacRdEn,
         dout          => pacDout,
         valid         => pacValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   U_PendingLenCalcQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 1539,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoClr,
         wr_clk        => clk,
         wr_en         => plcWrEn,
         din           => plcDin,
         not_full      => plcNotFull,
         full          => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => plcRdEn,
         dout          => plcDout,
         valid         => plcValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   U_PendingSpaceCalcQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 1605,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoClr,
         wr_clk        => clk,
         wr_en         => pscWrEn,
         din           => pscDin,
         not_full      => pscNotFull,
         full          => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => pscRdEn,
         dout          => pscDout,
         valid         => pscValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   U_PendingLenCheckQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 1573,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoClr,
         wr_clk        => clk,
         wr_en         => plkWrEn,
         din           => plkDin,
         not_full      => plkNotFull,
         full          => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => plkRdEn,
         dout          => plkDout,
         valid         => plkValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   U_PendingDmaReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 1539,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoClr,
         wr_clk        => clk,
         wr_en         => pdrWrEn,
         din           => pdrDin,
         not_full      => pdrNotFull,
         full          => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => pdrRdEn,
         dout          => pdrDout,
         valid         => pdrValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   U_PendingWorkCompQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 768,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoClr,
         wr_clk        => clk,
         wr_en         => pwcWrEn,
         din           => pwcDin,
         not_full      => pwcNotFull,
         full          => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => pwcRdEn,
         dout          => pwcDout,
         valid         => pwcValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   U_WorkCompGenReqOutQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 633,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoClr,
         wr_clk        => clk,
         wr_en         => outWrEn,
         din           => outDin,
         not_full      => outNotFull,
         full          => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => wcGenReqRdEn,
         dout          => outDout,
         valid         => outValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- Combinatorial process
   ---------------------------------------------------------------------------
   comb : process (r, rst, isReset, isRTS, isERR, isStableRTS, getPMTU,
                   getSQPN, getNPSN, pendingWrValid, pendingWrData,
                   pendingWrDeqAllowed,
                   pktMetaValid, pktMetaData, payloadConReqReady,
                   retryResetReady, retryReqReady, retryRespValid, retryRespData,
                   timeOutValid, timeOutData, isRetrying, permReqReady,
                   permRespValid, permRespData,
                   incValid, incDout, incNotFull, prsValid, prsDout, prsNotFull,
                   pqValid, pqDout, pqNotFull, prcValid, prcDout, prcNotFull,
                   ppcValid, ppcDout, ppcNotFull, pacValid, pacDout, pacNotFull,
                   plcValid, plcDout, plcNotFull, pscValid, pscDout, pscNotFull,
                   plkValid, plkDout, plkNotFull, pdrValid, pdrDout, pdrNotFull,
                   pwcValid, pwcDout, pwcNotFull, outNotFull) is
      variable v : RegType;
      -- mode signals (from r)
      variable inNormalState, inRetryState, inErrState, inErrStateAlt : boolean;
      -- generic working vars
      variable pwr   : slv(678 downto 0);
      variable pmd   : slv(648 downto 0);
      variable rpi   : slv(134 downto 0);
      variable opc   : slv(4 downto 0);
      variable wop   : slv(3 downto 0);
      variable aCode : slv(1 downto 0);
      variable aVal  : slv(4 downto 0);
      variable bpsn  : slv(23 downto 0);
      variable respAct  : slv(3 downto 0);
      variable wcReq    : slv(1 downto 0);
      variable wcStat   : slv(5 downto 0);   -- Maybe#WorkCompStatus (tag|5)
      variable mWcStat  : slv(5 downto 0);
      variable rlcr     : slv(97 downto 0);
      variable nAddr    : slv(63 downto 0);
      variable remLen   : slv(31 downto 0);
      variable preRem   : slv(31 downto 0);
      variable expectPerm : sl;
      variable wcWaitDma  : sl;
      variable doPut      : sl;
      variable enqOut     : sl;
      variable fire       : boolean;
      variable wcGenReq   : slv(632 downto 0);
      variable rdmaRespType : slv(1 downto 0);
      variable rel        : slv(4 downto 0);
      variable wrAck      : slv(3 downto 0);
      variable deqPmd, deqPwr : sl;
      variable needPerm   : boolean;
      variable pcInfo     : slv(194 downto 0);  -- PayloadConInfo
      variable retryStartPsn : slv(23 downto 0);
      variable readExpectedPsn : slv(23 downto 0);
      variable readPsnGap    : boolean;
      variable preReadPsnGap : boolean;
      variable readReplayStart : boolean;
      variable replayHeadStart : boolean;
      variable staleReplayResp : boolean;
   begin
      v := r;

      -- default outputs
      incWrEn <= '0'; incRdEn <= '0'; incDin <= (others => '0');
      prsWrEn <= '0'; prsRdEn <= '0'; prsDin <= (others => '0');
      pqWrEn  <= '0'; pqRdEn  <= '0'; pqDin  <= (others => '0');
      prcWrEn <= '0'; prcRdEn <= '0'; prcDin <= (others => '0');
      ppcWrEn <= '0'; ppcRdEn <= '0'; ppcDin <= (others => '0');
      pacWrEn <= '0'; pacRdEn <= '0'; pacDin <= (others => '0');
      plcWrEn <= '0'; plcRdEn <= '0'; plcDin <= (others => '0');
      pscWrEn <= '0'; pscRdEn <= '0'; pscDin <= (others => '0');
      plkWrEn <= '0'; plkRdEn <= '0'; plkDin <= (others => '0');
      pdrWrEn <= '0'; pdrRdEn <= '0'; pdrDin <= (others => '0');
      pwcWrEn <= '0'; pwcRdEn <= '0'; pwcDin <= (others => '0');
      outWrEn <= '0'; outDin <= (others => '0');
      pendingWrDeq <= '0'; pktMetaDeq <= '0';
      payloadConReqValid <= '0'; payloadConReqData <= (others => '0');
      retryResetValid <= '0'; retryResetData <= '0';
      retryReqValid <= '0'; retryReqData <= (others => '0');
      retryRespGetEn <= '0'; timeOutGetEn <= '0';
      permReqValid <= '0'; permReqData <= (others => '0'); permRespGetEn <= '0';

      -- mode signals (combinational from r)
      inNormalState := (r.retryFlush = '0') and (r.errOccurred = '0') and (r.recvErrResp = '0');
      inRetryState  := (r.retryFlush = '1') and (r.errOccurred = '0') and (r.recvErrResp = '0');
      inErrState    := (r.errOccurred = '1') or (isERR = '1');
      inErrStateAlt := ((isRTS = '1') and ((r.recvErrResp = '1') or (r.errOccurred = '1'))) or (isERR = '1');

      -- Source-side replay barrier.  Unlike readReplayStart below (which
      -- protects responses already in the internal FIFOs), this prevents a
      -- stale LAST response at pktMetaDataPipeIn from popping the pending WR.
      -- When no response has yet established continuity, the WR start PSN is
      -- the expected first response PSN.
      if r.nextReadRespPsnValid = '1' then
         readExpectedPsn := r.nextReadRespPsn;
      else
         readExpectedPsn := pendingWrData(76 downto 53);
      end if;
      replayHeadStart := false;
      staleReplayResp := false;
      if pktMetaValid = '1' then
         opc  := pktMetaData(623 downto 619);
         bpsn := pktMetaData(554 downto 531);
         replayHeadStart := (r.readReplayPending = '1') and
                            isReadRespOp(opc) and
                            (bpsn = readExpectedPsn);
         staleReplayResp := (r.readReplayPending = '1') and
                            isReadRespOp(opc) and
                            (not replayHeadStart);
      end if;

      --------------------------------------------------------------------
      -- (a) Pre-stage control FSM (normal mode only): preBuild/preProc/deq
      -- BUGFIX 2026-07-08: gate on pktMetaValid as well. In BSV,
      -- preBuildRespInfo reads pktMetaDataPipeIn.first (RespHandleSQ.bsv:211),
      -- so pktMetaDataPipeIn.notEmpty is an IMPLICIT rule condition. Without
      -- it the FSM classifies the empty FIFO's stale FWFT dout: at cold start
      -- (zeros, pktValid=0) it raises an illegal-resp error flush; after a
      -- NAK retry it re-classifies the stale NAK, firing a new retry request
      -- every ~15 cycles until the retry budget is exhausted (observed as
      -- IBV_WC_RETRY_EXC_ERR under DROP_REQ_PSN fault injection). The pktMeta
      -- stays in the FIFO until the DONE stage deqs it, so pktMetaValid holds
      -- through all three stages of one classification.
      --------------------------------------------------------------------
      if (isRTS = '1' and pendingWrValid = '1' and pktMetaValid = '1' and
          inNormalState and (not staleReplayResp) and
          not ((r.preStageState = SQ_PRE_BUILD_STAGE_S) and
               (r.readGapInFlight = '1'))) then
         case r.preStageState is
            ----------------------------------------------------------------
            when SQ_PRE_BUILD_STAGE_S =>
               -- read pktMetaDataPipeIn.first header
               opc  := pktMetaData(623 downto 619);          -- bth.opcode
               bpsn := pktMetaData(554 downto 531);          -- bth.psn
               aCode:= pktMetaData(529 downto 528);
               aVal := pktMetaData(527 downto 523);
               wop  := pendingWrData(614 downto 611);        -- wr.opcode
               -- relation (5 Bools): isReadAtomicWR[4] isMatchEndPSN[3] isCoalesce[2]
               --                     isMatchStartPSN[1] isPartialResp[0]
               rel := (others => '0');
               if isReadOrAtomicWR(wop) then rel(4) := '1'; end if;
               if bpsn = pendingWrData(51 downto 28) then rel(3) := '1'; end if;  -- endPSN.val
               if psnInRange(bpsn, pendingWrData(51 downto 28), getNPSN) then rel(2) := '1'; end if;
               if bpsn = pendingWrData(76 downto 53) then rel(1) := '1'; end if;  -- startPSN.val
               if psnInRange(bpsn, pendingWrData(76 downto 53), pendingWrData(51 downto 28)) then rel(0) := '1'; end if;
               -- rdmaRespType from opcode + aeth
               rdmaRespType := RESP_UNK_C;
               if isReadRespOp(opc) or isAtomicRespOp(opc) then
                  rdmaRespType := RESP_NORMAL_C;
               elsif opc = "10001" then  -- ACKNOWLEDGE
                  if aCode = AETH_ACK_C then rdmaRespType := RESP_NORMAL_C;
                  elsif aCode = AETH_RNR_C then rdmaRespType := RESP_RETRY_C;
                  elsif aCode = AETH_NAK_C then
                     if aVal = NAK_SEQ_C then rdmaRespType := RESP_RETRY_C;
                     elsif aVal = NAK_INV_REQ_C or aVal = NAK_RMT_ACC_C or aVal = NAK_RMT_OP_C or aVal = NAK_INV_RD_C then
                        rdmaRespType := RESP_ERROR_C;
                     else rdmaRespType := RESP_UNK_C; end if;
                  else rdmaRespType := RESP_UNK_C; end if;
               end if;

               -- Observe READ PSNs at the earliest point in the response
               -- path.  The later handler is intentionally FIFO-decoupled;
               -- without this guard, packets following a gap can reach DONE
               -- and dequeue the WR before the retry state is registered.
               if r.preReadRespPsnValid = '1' then
                  retryStartPsn := r.preNextReadRespPsn;
               else
                  retryStartPsn := pendingWrData(76 downto 53);
               end if;
               preReadPsnGap := (pktMetaData(1) = '1') and
                                (rdmaRespType = RESP_NORMAL_C) and
                                isReadRespOp(opc) and
                                (isMidOp(opc) or isLastOp(opc)) and
                                (bpsn /= retryStartPsn);
               if (pktMetaData(1) = '1') and
                  (rdmaRespType = RESP_NORMAL_C) and isReadRespOp(opc) then
                  if isFirstOp(opc) or isOnlyOp(opc) or
                     ((isMidOp(opc) or isLastOp(opc)) and
                      (not preReadPsnGap)) then
                     v.preNextReadRespPsn  := slv(unsigned(bpsn) + 1);
                     v.preReadRespPsnValid := '1';
                  end if;
                  if preReadPsnGap then
                     v.readGapInFlight := '1';
                  end if;
               end if;
               -- respPktInfo (135): bth | aeth | flags
               rpi := (others => '0');
               rpi(134 downto 39) := pktMetaData(626 downto 531);  -- bth (96)
               rpi(38 downto 7)   := pktMetaData(530 downto 499);  -- aeth (32)
               if isFirstOrOnlyOp(opc) then rpi(6) := '1'; end if;
               if isLastOrOnlyOp(opc)  then rpi(5) := '1'; end if;
               if isReadRespOp(opc)    then rpi(4) := '1'; end if;
               if isAtomicRespOp(opc)  then rpi(3) := '1'; end if;
               -- latch
               v.preStageRespAndWorkReqRelation := rel;
               v.preStageReqPktInfo  := rpi;
               v.preStageRespType    := rdmaRespType;
               v.preStagePktMetaData := pktMetaData;
               v.preStageState       := SQ_PRE_PROC_STAGE_S;
            ----------------------------------------------------------------
            when SQ_PRE_PROC_STAGE_S =>
               rel := r.preStageRespAndWorkReqRelation;
               rdmaRespType := r.preStageRespType;
               deqPmd := '1'; deqPwr := '0';
               wrAck := WRA_UNK_C; wcReq := WC_UNK_C;
               if r.preStagePktMetaData(1) = '0' then  -- isIllegalResp = !pktValid
                  wrAck := WRA_ILL_C; wcReq := WC_FULL_C;
               else
                  -- case {isMatchEndPSN, isCoalesce, isMatchStartPSN, isPartialResp}
                  if (rel(3) = '1' and rel(2) = '0' and rel(1) = '0' and rel(0) = '0') or
                     (rel(3) = '1' and rel(2) = '0' and rel(1) = '1' and rel(0) = '0') then  -- 1000 / 1010 whole WR
                     if rdmaRespType = RESP_RETRY_C then
                        wrAck := WRA_EWR_C; wcReq := WC_NO_C;
                     elsif rdmaRespType = RESP_ERROR_C then
                        wrAck := WRA_EWE_C; wcReq := WC_FULL_C; deqPwr := '1';
                     else  -- NORMAL
                        wrAck := WRA_EWN_C; wcReq := WC_FULL_C; deqPwr := '1';
                     end if;
                  elsif (rel(3) = '0' and rel(2) = '1' and rel(1) = '0' and rel(0) = '0') then  -- 0100 coalesce
                     deqPmd := '0';
                     if rel(4) = '1' then  -- isReadAtomicWR -> implicit retry
                        wrAck := WRA_CR_C; wcReq := WC_NO_C;
                     else
                        wrAck := WRA_CN_C; wcReq := WC_FULL_C; deqPwr := '1';
                     end if;
                  elsif (rel(3) = '0' and rel(2) = '0' and rel(1) = '1' and rel(0) = '0') or
                        (rel(3) = '0' and rel(2) = '0' and rel(1) = '0' and rel(0) = '1') then  -- 0010/0001 partial
                     if rdmaRespType = RESP_RETRY_C then
                        wrAck := WRA_EPR_C; wcReq := WC_NO_C;
                     elsif rdmaRespType = RESP_ERROR_C then
                        wrAck := WRA_EPE_C; wcReq := WC_FULL_C; deqPwr := '1';
                     else  -- NORMAL
                        wrAck := WRA_EPN_C; wcReq := WC_PART_C;
                     end if;
                  else  -- duplicate
                     wrAck := WRA_DUP_C; wcReq := WC_NO_C;
                  end if;
               end if;
               if deqPwr = '1' then
                  v.retryResetReq := RESET_CNT_TMO_C;
               else
                  v.retryResetReq := RESET_TIMEOUT_C;
               end if;
               v.preStageDeqPktMetaData    := deqPmd;
               v.preStageDeqPendingWorkReq := deqPwr;
               v.preStageWorkReqAckType    := wrAck;
               v.preStageWorkCompReqType   := wcReq;
               v.preStageState             := SQ_PRE_STAGE_DONE_S;
            ----------------------------------------------------------------
            when SQ_PRE_STAGE_DONE_S =>
               -- deqPktMetaDataOrWorkReq: gated on incomingRespQ room.
               -- DEVIATION-SQQP-01: a stage that pops the pending WR also
               -- requires pendingWrDeqAllowed (BSV deq implicit condition —
               -- no pop while the scan buffer is in PRE_SCAN). Non-popping
               -- stages (partials, duplicates, retries) proceed unchanged.
               if (incNotFull = '1' and
                   (r.preStageDeqPendingWorkReq = '0' or pendingWrDeqAllowed = '1')) then
                  if r.preStageDeqPktMetaData = '1' then pktMetaDeq <= '1'; end if;
                  if r.preStageDeqPendingWorkReq = '1' then pendingWrDeq <= '1'; end if;
                  incWrEn <= '1';
                  incDin  <= pendingWrData & r.preStagePktMetaData & r.preStageReqPktInfo &
                             r.retryResetReq & r.preStageWorkCompReqType & r.preStageWorkReqAckType;
                  v.preStageState := SQ_PRE_BUILD_STAGE_S;
               end if;
         end case;
      end if;

      --------------------------------------------------------------------
      -- (c) incomingRespQ source rules (mode-disjoint with deq-stage above)
      --------------------------------------------------------------------
      -- discardStaleReadReplayResp: retryFlush may finish before every old READ
      -- response reaches this source.  Keep those packets away from pre-stage
      -- so an old LAST cannot dequeue the retried pending WR.
      if (isRTS = '1' and inNormalState and pktMetaValid = '1' and
          staleReplayResp and incNotFull = '1') then
         pktMetaDeq <= '1';
         rpi := (others => '0');
         rpi(134 downto 39) := pktMetaData(626 downto 531);
         rpi(38 downto 7)   := pktMetaData(530 downto 499);
         opc := pktMetaData(623 downto 619);
         if isFirstOrOnlyOp(opc) then rpi(6) := '1'; end if;
         if isLastOrOnlyOp(opc)  then rpi(5) := '1'; end if;
         if isReadRespOp(opc)    then rpi(4) := '1'; end if;
         rpi(1) := '1';
         incWrEn <= '1';
         incDin  <= ZERO_PWR_C & pktMetaData & rpi &
                    RESET_TIMEOUT_C & WC_NO_C & WRA_DISC_C;
      -- discardGhostResp: normal, pktMeta present, no pending WR
      elsif (isRTS = '1' and inNormalState and pktMetaValid = '1' and
          pendingWrValid = '0' and incNotFull = '1') then
         pktMetaDeq <= '1';
         rpi := (others => '0');
         rpi(134 downto 39) := pktMetaData(626 downto 531);  -- bth
         rpi(6) := '1'; rpi(5) := '1';                          -- isFirstOrOnly/isLastOrOnly = True
         rpi(1) := '1';                                         -- shouldDiscard
         incWrEn <= '1';
         incDin  <= ZERO_PWR_C & pktMetaData & rpi &
                    RESET_TIMEOUT_C & WC_NO_C & WRA_GHOST_C;
      -- retryFlushPktMetaDataAndPayload: retry mode (also forces preStage=BUILD)
      elsif (isRTS = '1' and inRetryState) then
         v.preStageState := SQ_PRE_BUILD_STAGE_S;
         if (pktMetaValid = '1' and incNotFull = '1') then
            pktMetaDeq <= '1';
            rpi := (others => '0');
            rpi(134 downto 39) := pktMetaData(626 downto 531);
            rpi(38 downto 7)   := pktMetaData(530 downto 499);
            opc := pktMetaData(623 downto 619);
            if isFirstOrOnlyOp(opc) then rpi(6) := '1'; end if;
            if isLastOrOnlyOp(opc)  then rpi(5) := '1'; end if;
            if isReadRespOp(opc)    then rpi(4) := '1'; end if;
            if isAtomicRespOp(opc)  then rpi(3) := '1'; end if;
            rpi(1) := '1';                                       -- shouldDiscard
            incWrEn <= '1';
            incDin  <= ZERO_PWR_C & pktMetaData & rpi &
                       RESET_TIMEOUT_C & WC_NO_C & WRA_DISC_C;
         end if;
      -- errFlushWorkReq: err mode, pending WR present
      -- (DEVIATION-SQQP-01: same deq implicit condition as the DONE stage;
      -- while blocked the errFlushIncomingResp branch below cannot fire
      -- either — pendingWrValid='1' — so the flush just stalls, as the
      -- blocked BSV rule would.)
      elsif (inErrStateAlt and pendingWrValid = '1' and incNotFull = '1' and
             pendingWrDeqAllowed = '1') then
         pendingWrDeq <= '1';
         rpi := (others => '0');
         rpi(6) := '1'; rpi(5) := '1';     -- isFirstOrOnly/isLastOrOnly
         rpi(2) := '1';                     -- hasLocalErr
         rpi(1) := '1';                     -- shouldDiscard
         rpi(0) := '1';                     -- genWorkComp
         pmd := (others => '0');
         pmd(627) := '1';                   -- isZeroPayloadLen = True; pktValid=0
         if r.hasTimeOutErr = '1' then
            wrAck := WRA_TMOUT_C;
            v.hasTimeOutErr := '0';         -- CReg port[0] clear
         else
            wrAck := WRA_FLUSH_C;
         end if;
         incWrEn <= '1';
         incDin  <= pendingWrData & pmd & rpi & RESET_TIMEOUT_C & WC_FULL_C & wrAck;
      -- errFlushIncomingResp: err mode, no pending WR
      elsif (inErrStateAlt and pendingWrValid = '0' and pktMetaValid = '1' and incNotFull = '1') then
         pktMetaDeq <= '1';
         rpi := (others => '0');
         rpi(134 downto 39) := pktMetaData(626 downto 531);
         rpi(38 downto 7)   := pktMetaData(530 downto 499);
         opc := pktMetaData(623 downto 619);
         if isFirstOrOnlyOp(opc) then rpi(6) := '1'; end if;
         if isLastOrOnlyOp(opc)  then rpi(5) := '1'; end if;
         if isReadRespOp(opc)    then rpi(4) := '1'; end if;
         if isAtomicRespOp(opc)  then rpi(3) := '1'; end if;
         rpi(1) := '1';                     -- shouldDiscard
         incWrEn <= '1';
         incDin  <= ZERO_PWR_C & pktMetaData & rpi &
                    RESET_TIMEOUT_C & WC_NO_C & WRA_DISC_C;
      end if;

      --------------------------------------------------------------------
      -- (b) Linear pipeline stages (fire when isRTS or isERR)
      --------------------------------------------------------------------
      if (isRTS = '1' or isERR = '1') then

         ---------------- recvRespHeader : incomingRespQ -> pendingRespQ ----------------
         if (incValid = '1') then
            wrAck := incDout(3 downto 0);
            -- resetRetry put only when isStableRTS (conditional implicit cond)
            fire := (prsNotFull = '1') and ((isStableRTS = '0') or (retryResetReady = '1'));
            if fire then
               incRdEn <= '1';
               if isStableRTS = '1' then
                  retryResetValid <= '1';
                  retryResetData  <= incDout(6);   -- retryResetReq
               end if;
               -- map wrAckType -> respAction; set mode flags
               respAct := ACT_UNK_C;
               case wrAck is
                  when WRA_EWN_C | WRA_EPN_C => respAct := ACT_EXP_NORM_C;
                  when WRA_EWR_C | WRA_EPR_C =>
                     respAct := ACT_EXP_RETRY_C; v.recvRetryResp := '1'; v.retryFlush := '1';
                  when WRA_EWE_C | WRA_EPE_C =>
                     respAct := ACT_ERROR_C; v.recvErrResp := '1';
                  when WRA_CN_C  => respAct := ACT_COALESCE_C;
                  when WRA_CR_C  =>
                     respAct := ACT_IMP_RETRY_C; v.recvRetryResp := '1'; v.retryFlush := '1';
                  when WRA_DUP_C => respAct := ACT_DUP_C;
                  when WRA_DISC_C | WRA_GHOST_C => respAct := ACT_DISCARD_C;
                  when WRA_ILL_C =>
                     -- pktStatus2RespActionSQ(pktStatus = pmd bit0 = incDout(142)):
                     --   PKT_ST_VALID(0)->EXPLICIT_NORMAL, PKT_ST_LEN_ERR(1)->ILLEGAL
                     if incDout(142) = '0' then respAct := ACT_EXP_NORM_C; else respAct := ACT_ILLEGAL_C; end if;
                     v.recvErrResp := '1';
                  when WRA_FLUSH_C => respAct := ACT_FLUSH_WR_C;
                  when WRA_TMOUT_C => respAct := ACT_TIMEOUT_C;
                  when others      => respAct := ACT_UNK_C;
               end case;
               -- pendingResp din: pwr | pmd | rpi | respAct | wcReqType | wrAck
               prsWrEn <= '1';
               prsDin  <= incDout(1469 downto 791) & incDout(790 downto 142) & incDout(141 downto 7) &
                          respAct & incDout(5 downto 4) & wrAck;
            end if;
         end if;

         ---------------- handleRespByType : pendingRespQ -> pendingPermQueryQ ----------------
         if (prsValid = '1') then
            pwr := prsDout(1472 downto 794);
            rpi := prsDout(144 downto 10);
            respAct := prsDout(9 downto 6);
            wcReq := prsDout(5 downto 4);
            opc := rpi(131 downto 127);            -- bth.opcode within rpi
            bpsn:= rpi(62 downto 39);              -- bth.psn
            aCode := rpi(37 downto 36);
            aVal  := rpi(35 downto 31);
            wop := pwr(614 downto 611);
            doPut := '0';                          -- retry request put wanted?
            if (respAct = ACT_EXP_RETRY_C or respAct = ACT_IMP_RETRY_C) then doPut := '1'; end if;
            retryStartPsn := bpsn;
            if r.nextReadRespPsnValid = '1' then
               readExpectedPsn := r.nextReadRespPsn;
            else
               readExpectedPsn := pwr(76 downto 53);
            end if;

            -- retryFlush only protects packet metadata which has not entered
            -- this pipeline yet.  NORMAL responses already resident in
            -- incomingRespQ/pendingRespQ keep that action after retryFlush is
            -- released and can otherwise generate a completion for a later
            -- READ WR.  While a partial replay is pending, discard everything
            -- until the responder restarts exactly at the missing PSN.  A
            -- partial READ request does not necessarily produce FIRST: the
            -- response opcode retains its position in the original transfer.
            -- The triggering gap packet itself is dealt with by readPsnGap.
            readReplayStart := (r.readReplayPending = '1') and
                               (respAct = ACT_EXP_NORM_C) and
                               (rpi(4) = '1') and
                               (bpsn = readExpectedPsn);
            if (r.readReplayPending = '1') and
               (respAct = ACT_EXP_NORM_C) and (rpi(4) = '1') and
               (not readReplayStart) then
               respAct := ACT_DISCARD_C;
               rpi(1) := '1';
            end if;

            -- Opcode sequencing cannot reveal a lost READ_RESP_MIDDLE because
            -- MIDDLE->MIDDLE is legal.  Track the next accepted response PSN
            -- and convert a forward gap into an implicit partial READ retry
            -- from the missing PSN.  This packet is then discarded downstream
            -- and cannot be DMA-written at the missing packet's address.
            readPsnGap := (respAct = ACT_EXP_NORM_C) and (rpi(4) = '1') and
                          (isMidOp(opc) or isLastOp(opc)) and
                          (bpsn /= readExpectedPsn);
            if readPsnGap then
               respAct := ACT_IMP_RETRY_C;
               retryStartPsn := readExpectedPsn;
               doPut := '1';
            end if;
            fire := (pqNotFull = '1') and ((doPut = '0') or (retryReqReady = '1'));
            if fire then
               prsRdEn <= '1';
               if respAct = ACT_EXP_NORM_C then
                  if (not rdmaRespMatchWR(opc, wop)) or (not checkRespOpSeq(r.preRdmaOpCode, opc)) then
                     respAct := ACT_BAD_C; v.recvErrResp := '1';
                     rpi(2) := '1';                -- hasLocalErr
                     if prsDout(3 downto 0) = WRA_EPN_C then wcReq := WC_PART_C; else wcReq := WC_FULL_C; end if;
                  elsif inErrState = false then
                     v.preRdmaOpCode := opc;
                     if rpi(4) = '1' then
                        v.nextReadRespPsn := slv(unsigned(bpsn) + 1);
                        v.nextReadRespPsnValid := '1';
                        if readReplayStart then
                           v.readReplayPending := '0';
                        end if;
                     end if;
                  end if;
               elsif doPut = '1' then
                  -- Gap retries originate in this stage, after the earlier
                  -- wrAck mapper, so arm retry mode here too.  Preserve opcode
                  -- history: a partial replay of a missing MIDDLE response
                  -- restarts with MIDDLE and must follow the last accepted
                  -- MIDDLE response normally.
                  v.recvRetryResp := '1';
                  v.retryFlush    := '1';
                  if readPsnGap then
                     -- Arm only on the same successful handshake which puts
                     -- the retry request.  If retryReqReady is low, leave the
                     -- gap packet at the FIFO head and retry next cycle.
                     v.readReplayPending := '1';
                     v.readGapInFlight   := '0';
                  end if;
                  -- build RetryReq(97): wrID(64) | retryStartPSN(24) | retryReason(3) | Maybe#RnrTimer(6)
                  -- retryStartPSN (upstream fix f2e0789, RespHandleSQ.bsv:711-712):
                  -- bth.psn only for Read/Atomic WRs (ACK PSN = exact resume point);
                  -- Send/Write must restart from the whole WR's first PSN =
                  -- unwrapMaybe(pendingWR.startPSN) (value slice [76:53], valid
                  -- tag [77] deliberately ignored) or a fragmented WR restarts
                  -- mid-WR after an RNR NAK.
                  retryReqValid <= '1';
                  retryReqData  <= pwr(678 downto 615) &           -- wr.id
                                     ite(isReadOrAtomicWR(wop), retryStartPsn, pwr(76 downto 53)) &
                                     getRetryReason(respAct, aCode, aVal) &
                                     getRnrTimer(respAct, aCode, aVal);
               end if;
               pqWrEn <= '1';
               pqDin  <= pwr & prsDout(793 downto 145) & rpi & respAct & wcReq;
            end if;
         end if;

         ---------------- queryPerm4NormalReadAtomicResp : pendingPermQueryQ -> pendingRetryCheckQ -------
         if (pqValid = '1') then
            pwr := pqDout(1468 downto 790);
            pmd := pqDout(789 downto 141);
            rpi := pqDout(140 downto 6);
            respAct := pqDout(5 downto 2);
            wcReq := pqDout(1 downto 0);
            expectPerm := '0';
            needPerm := (respAct = ACT_EXP_NORM_C) and (rpi(6) = '1') and (inErrState = false) and
                        (((rpi(4) = '1') and (pmd(627) = '0')) or (rpi(3) = '1'));  -- (read&!zeroPayload)|atomic
            fire := (prcNotFull = '1') and ((not needPerm) or (permReqReady = '1'));
            if fire then
               pqRdEn <= '1';
               if needPerm then
                  expectPerm := '1';
                  -- PermCheckReq(267): wrID Maybe(65) | lkey(32) | rkey(32) | localOrRmtKey(1) |
                  --   reqAddr ADDR(64) | totalLen Length(32) | pdHandler(32) | isZeroDmaLen(1) | accFlags(8)
                  permReqValid <= '1';
                  permReqData  <= '1' & pwr(678 downto 615) &         -- wrID = Valid wr.id
                                    pwr(413 downto 382) &               -- lkey
                                    ZERO32_C &              -- rkey = dontCare
                                    '1' &                               -- localOrRmtKey = True
                                    pwr(477 downto 414) &               -- reqAddr = wr.laddr
                                    pwr(509 downto 478) &               -- totalLen = wr.len
                                    pmd(33 downto 2) &                  -- pdHandler
                                    (pmd(627) and not rpi(3)) &         -- isZeroDmaLen = atomic?False:isZeroPayloadLen
                                    ACC_LOCAL_WRITE_C;                  -- accFlags
               end if;
               -- pendingRetryCheck din: pwr | pmd | rpi | respAct | wcReq | expectPerm
               prcWrEn <= '1';
               prcDin  <= pwr & pmd & rpi & respAct & wcReq & expectPerm;
            end if;
         end if;

         ---------------- checkRetryErr : pendingRetryCheckQ -> pendingPermCheckQ ----------------
         if (prcValid = '1') then
            pwr := prcDout(1469 downto 791);
            pmd := prcDout(790 downto 142);
            rpi := prcDout(141 downto 7);
            respAct := prcDout(6 downto 3);
            wcReq := prcDout(2 downto 1);
            expectPerm := prcDout(0);
            opc := rpi(131 downto 127);
            aCode := rpi(37 downto 36);
            aVal  := rpi(35 downto 31);
            wop := pwr(614 downto 611);
            mWcStat := (others => '0');           -- Invalid
            doPut := '0';                          -- consumes retry response?
            if (respAct = ACT_EXP_RETRY_C or respAct = ACT_IMP_RETRY_C) then doPut := '1'; end if;
            fire := (ppcNotFull = '1') and ((doPut = '0') or (retryRespValid = '1'));
            if fire then
               prcRdEn <= '1';
               case respAct is
                  when ACT_BAD_C =>
                     rpi(0) := '1'; rpi(1) := '1';                 -- genWorkComp, shouldDiscard
                     mWcStat := '1' & WCS_BAD_RESP_C;
                  when ACT_ERROR_C =>
                     rpi(0) := '1';
                     mWcStat := genErrWcStatusFromAeth(aCode, aVal);
                  when ACT_EXP_NORM_C =>
                     -- needWorkComp = signaled flag (wr.flags bit1) or isReadOrAtomicWR
                     if ((pwr(607) = '1') or isReadOrAtomicWR(wop)) and (rpi(5) = '1') then  -- needWC & isLastOrOnly
                        rpi(0) := '1';
                        mWcStat := '1' & WCS_SUCCESS_C;
                     end if;
                  when ACT_COALESCE_C =>
                     if (pwr(607) = '1') or isReadOrAtomicWR(wop) then
                        rpi(0) := '1';
                        mWcStat := '1' & WCS_SUCCESS_C;
                     end if;
                  when ACT_DUP_C =>
                     rpi(1) := '1';
                  when ACT_ILLEGAL_C =>
                     rpi(0) := '1'; rpi(1) := '1';
                     -- pktStatus2WorkCompStatusSQ(pmd.pktStatus bit0): VALID->SUCCESS, LEN_ERR->LOC_LEN
                     if pmd(0) = '0' then mWcStat := '1' & WCS_SUCCESS_C; else mWcStat := '1' & WCS_LOC_LEN_C; end if;
                  when ACT_DISCARD_C =>
                     rpi(1) := '1';
                  when ACT_FLUSH_WR_C =>
                     rpi(0) := '1';
                     mWcStat := '1' & WCS_WR_FLUSH_C;
                  when ACT_EXP_RETRY_C | ACT_IMP_RETRY_C =>
                     retryRespGetEn <= '1';
                     if retryRespData(0) = '1' then       -- RETRY_LIMIT_EXC
                        if retryRespData(1) = '1' then    -- RNR exhaustion
                           mWcStat := '1' & WCS_RNR_RETRY_EXC_C;
                        else
                           mWcStat := '1' & WCS_RETRY_EXC_C;
                        end if;
                        wcReq := WC_PART_C;
                        rpi(0) := '1';
                     end if;
                     rpi(1) := '1';
                  when ACT_TIMEOUT_C =>
                     rpi(0) := '1';
                     mWcStat := '1' & WCS_RESP_TMOUT_C;
                  when others => null;
               end case;
               -- pendingPermCheck din: pwr|pmd|rpi|respAct|mWcStat|wcReq|expectPerm
               ppcWrEn <= '1';
               ppcDin  <= pwr & pmd & rpi & respAct & mWcStat & wcReq & expectPerm;
            end if;
         end if;

         ---------------- checkPerm4NormalReadAtomicResp : pendingPermCheckQ -> pendingAddrCalcQ -------
         if (ppcValid = '1') then
            pwr := ppcDout(1475 downto 797);
            pmd := ppcDout(796 downto 148);
            rpi := ppcDout(147 downto 13);
            respAct := ppcDout(12 downto 9);
            mWcStat := ppcDout(8 downto 3);
            wcReq := ppcDout(2 downto 1);
            expectPerm := ppcDout(0);
            doPut := '0';                          -- consumes perm response?
            if (respAct = ACT_EXP_NORM_C and expectPerm = '1') then doPut := '1'; end if;
            fire := (pacNotFull = '1') and ((doPut = '0') or (permRespValid = '1'));
            if fire then
               ppcRdEn <= '1';
               if doPut = '1' then
                  permRespGetEn <= '1';
                  if permRespData = '0' then       -- mrCheckResult = False
                     mWcStat := '1' & WCS_LOC_ACC_C;
                     respAct := ACT_LOC_ACC_C;
                     rpi(0) := '1'; rpi(2) := '1'; rpi(1) := '1';
                  end if;
               end if;
               pacWrEn <= '1';
               pacDin  <= pwr & pmd & rpi & respAct & mWcStat & wcReq;
            end if;
         end if;

         ---------------- calcReadRespAddr : pendingAddrCalcQ -> pendingLenCalcQ ----------------
         if (pacValid = '1' and plcNotFull = '1') then
            pacRdEn <= '1';
            pwr := pacDout(1474 downto 796);
            pmd := pacDout(795 downto 147);
            rpi := pacDout(146 downto 12);
            respAct := pacDout(11 downto 8);
            mWcStat := pacDout(7 downto 2);
            wcReq := pacDout(1 downto 0);
            opc := rpi(131 downto 127);
            -- nAddr = THIS packet's DMA-write start address (it feeds the
            -- SendWriteReqReadRespInfo DmaWriteMetaData in issueDmaReq):
            -- ONLY/FIRST land at wr.laddr, every subsequent packet advances
            -- one PMTU from the previous packet's address (register).
            -- R12 readRespWriteAddrOffByOne: FIRST used laddr+PMTU and LAST
            -- reused the previous address, shifting every multi-packet READ
            -- response payload up by one PMTU (last packet overwrote the
            -- previous one; bytes [0, PMTU) never written).  Invisible to the
            -- legacy (addr mod 256) payload check because PMTU = 0 mod 256 —
            -- caught by the address-seeded PRBS stream (prbs-payload-plan.md).
            nAddr := r.nextReadRespWriteAddr;
            if rpi(4) = '1' then                   -- isReadResp
               if isOnlyOp(opc) or isFirstOp(opc) then
                  nAddr := pwr(477 downto 414);     -- wr.laddr
               else                                 -- mid / last
                  nAddr := addrAddPsn(r.nextReadRespWriteAddr, x"000001", getPMTU);
               end if;
               if (respAct = ACT_EXP_NORM_C) and (inErrState = false) then
                  v.nextReadRespWriteAddr := nAddr;
               end if;
            end if;
            plcWrEn <= '1';
            plcDin  <= pwr & pmd & rpi & respAct & mWcStat & wcReq & nAddr;
         end if;

         ---------------- calcReadRespLen : pendingLenCalcQ -> pendingSpaceCalcQ ----------------
         if (plcValid = '1' and pscNotFull = '1') then
            plcRdEn <= '1';
            pwr := plcDout(1538 downto 860);
            pmd := plcDout(859 downto 211);
            rpi := plcDout(210 downto 76);
            respAct := plcDout(75 downto 72);
            mWcStat := plcDout(71 downto 66);
            wcReq := plcDout(65 downto 64);
            nAddr := plcDout(63 downto 0);
            opc := rpi(131 downto 127);
            remLen := r.remainingReadRespLen;
            if rpi(4) = '1' then
               if isOnlyOp(opc) then
                  remLen := slv(unsigned(pwr(509 downto 478)) - resize(unsigned(pmd(648 downto 636)), 32));
               elsif isFirstOp(opc) then
                  remLen := lenSubPsn(pwr(509 downto 478), x"000001", getPMTU);
               elsif isMidOp(opc) then
                  remLen := lenSubPsn(r.remainingReadRespLen, x"000001", getPMTU);
               else  -- last
                  remLen := lenSubPktLen(r.remainingReadRespLen, pmd(648 downto 636), getPMTU);
               end if;
               if (respAct = ACT_EXP_NORM_C) and (inErrState = false) then
                  v.remainingReadRespLen := remLen;
               end if;
            end if;
            -- RespLenCheckResult(98): enoughDmaSpace(F)|isLastPayloadLenZero(T)|nextAddr|remLen
            rlcr := '0' & '1' & nAddr & remLen;
            pscWrEn <= '1';
            pscDin  <= pwr & pmd & rpi & respAct & mWcStat & wcReq & rlcr & r.remainingReadRespLen;
         end if;

         ---------------- calcEnoughDmaSpace : pendingSpaceCalcQ -> pendingLenCheckQ ----------------
         if (pscValid = '1' and plkNotFull = '1') then
            pscRdEn <= '1';
            pwr := pscDout(1604 downto 926);
            pmd := pscDout(925 downto 277);
            rpi := pscDout(276 downto 142);
            respAct := pscDout(141 downto 138);
            mWcStat := pscDout(137 downto 132);
            wcReq := pscDout(131 downto 130);
            rlcr := pscDout(129 downto 32);
            preRem := pscDout(31 downto 0);
            opc := rpi(131 downto 127);
            -- enoughDmaSpace default True; isLastPayloadLenZero default False
            rlcr(97) := '1'; rlcr(96) := '0';
            if rpi(4) = '1' then
               if isOnlyOp(opc) then
                  if lenGtEqPktLen(pwr(509 downto 478), pmd(648 downto 636), getPMTU) then rlcr(97) := '1'; else rlcr(97) := '0'; end if;
               elsif isFirstOp(opc) then
                  if lenGtEqPMTU(pwr(509 downto 478), getPMTU) then rlcr(97) := '1'; else rlcr(97) := '0'; end if;
               elsif isMidOp(opc) then
                  if lenGtEqPMTU(preRem, getPMTU) then rlcr(97) := '1'; else rlcr(97) := '0'; end if;
               else  -- last
                  if lenGtEqPktLen(preRem, pmd(648 downto 636), getPMTU) then rlcr(97) := '1'; else rlcr(97) := '0'; end if;
                  rlcr(96) := pmd(627);           -- isLastPayloadLenZero = isZeroPayloadLen
               end if;
            end if;
            plkWrEn <= '1';
            plkDin  <= pwr & pmd & rpi & respAct & mWcStat & wcReq & rlcr;
         end if;

         ---------------- checkReadRespLen : pendingLenCheckQ -> pendingDmaReqQ ----------------
         if (plkValid = '1' and pdrNotFull = '1') then
            plkRdEn <= '1';
            pwr := plkDout(1572 downto 894);
            pmd := plkDout(893 downto 245);
            rpi := plkDout(244 downto 110);
            respAct := plkDout(109 downto 106);
            mWcStat := plkDout(105 downto 100);
            wcReq := plkDout(99 downto 98);
            rlcr := plkDout(97 downto 0);
            nAddr := rlcr(95 downto 32);
            remLen := rlcr(31 downto 0);
            if (rpi(4) = '1') and (respAct = ACT_EXP_NORM_C) and (inErrState = false) then
               -- readRespLenMatch = isLastOrOnly ? isZero(remLen) : True
               fire := true;
               if rpi(5) = '1' then
                  fire := (unsigned(remLen) = 0);
               end if;
               if (rlcr(97) = '0') or (not fire) or (rlcr(96) = '1') then
                  respAct := ACT_LOC_LEN_C;
                  mWcStat := '1' & WCS_LOC_LEN_C;
                  if rpi(5) = '1' then wcReq := WC_FULL_C; else wcReq := WC_PART_C; end if;
                  rpi(0) := '1'; rpi(2) := '1'; rpi(1) := '1';
               end if;
            end if;
            pdrWrEn <= '1';
            pdrDin  <= pwr & pmd & rpi & respAct & mWcStat & wcReq & nAddr;
         end if;

         ---------------- issueDmaReq : pendingDmaReqQ -> pendingWorkCompQ ----------------
         if (pdrValid = '1') then
            pwr := pdrDout(1538 downto 860);
            pmd := pdrDout(859 downto 211);
            rpi := pdrDout(210 downto 76);
            respAct := pdrDout(75 downto 72);
            mWcStat := pdrDout(71 downto 66);
            wcReq := pdrDout(65 downto 64);
            nAddr := pdrDout(63 downto 0);
            opc := rpi(131 downto 127);
            bpsn := rpi(62 downto 39);
            wcWaitDma := '0';
            doPut := '0';
            pcInfo := (others => '0');
            if respAct = ACT_EXP_NORM_C then
               if inErrState = false then
                  if (rpi(4) = '1') and (pmd(627) = '0') then       -- read & !zeroPayload
                     -- PayloadConInfo : BSV deriving(Bits) LSB-justifies the 129b
                     -- union members, so SendWriteReqReadRespInfo/DiscardPayloadInfo
                     -- carry DmaWriteMetaData at [128:0] with zero-pad at [192:129]
                     -- (only the 193b Atomic member is metadata-MSB-aligned).
                     -- OQ-RHSQ-03 RESOLVED — was MSB-aligned, same emit bug as
                     -- DEVIATION-PCCAG-01's consumer side.
                     pcInfo := "10" & ZERO64_C &                     -- tag=2, pad [192:129]
                               DMA_SQ_WR_C & getSQPN & nAddr & pmd(648 downto 636) & bpsn;
                     doPut := '1'; wcWaitDma := '1';
                  elsif rpi(3) = '1' then                            -- atomic
                     pcInfo := "01" &                                -- tag=1 (AtomicRespInfoAndPayload)
                               DMA_SQ_ATOM_C & getSQPN & pwr(477 downto 414) &
                               pwr(490 downto 478) & bpsn &          -- len = truncate(wr.len) to 13b
                               pmd(498 downto 435);                  -- atomicRespPayload = atomicAckEth.orig(64)
                     doPut := '1'; wcWaitDma := '1';
                  end if;
               end if;
            elsif ((rpi(1) = '1') or inErrState) and (pmd(627) = '0') then  -- discard & !zeroPayload
               pcInfo := "00" & ZERO64_C &                           -- tag=0, LSB-justified (OQ-RHSQ-03)
                         DMA_SQ_DISC_C & getSQPN & nAddr & pmd(648 downto 636) & bpsn;
               doPut := '1';
            end if;
            fire := (pwcNotFull = '1') and ((doPut = '0') or (payloadConReqReady = '1'));
            if fire then
               pdrRdEn <= '1';
               if doPut = '1' then
                  payloadConReqValid <= '1';
                  payloadConReqData  <= pmd(635 downto 628) & pcInfo;   -- fragNum | consumeInfo
               end if;
               -- hasInternalErr port[0] <= True if wcStatus Valid and != SUCCESS
               if (mWcStat(5) = '1') and (mWcStat(4 downto 0) /= WCS_SUCCESS_C) then
                  v.hasInternalErr := '1';
               end if;
               -- WorkCompGenReqSQ(633): wr(601)|wcWaitDma(1)|wcReqType(2)|triggerPSN(24)|wcStatus(5)
               if mWcStat(5) = '1' then wcStat := mWcStat; else wcStat := '1' & WCS_SUCCESS_C; end if;
               wcGenReq := pwr(678 downto 78) & wcWaitDma & wcReq & bpsn & wcStat(4 downto 0);
               pwcWrEn <= '1';
               pwcDin  <= rpi & wcGenReq;
            end if;
         end if;

         ---------------- genWorkCompSQ : pendingWorkCompQ -> workCompGenReqOutQ ----------------
         if (pwcValid = '1') then
            rpi := pwcDout(767 downto 633);
            wcGenReq := pwcDout(632 downto 0);
            -- enq when genWorkComp or wcWaitDmaResp
            enqOut := rpi(0) or wcGenReq(31);
            if (enqOut = '0') or (outNotFull = '1') then
               pwcRdEn <= '1';
               if enqOut = '1' then
                  outWrEn <= '1';
                  outDin  <= wcGenReq;
               end if;
            end if;
         end if;

         ---------------- checkTimeOutErr (normal): notifyTimeOut2SQ ----------------
         if (inNormalState and timeOutValid = '1') then
            timeOutGetEn <= '1';
            if timeOutData = '1' then            -- TIMEOUT_ERR
               v.hasTimeOutErr := '1';             -- CReg port[0]
            end if;
         end if;

         ---------------- canonicalize : reads CReg port[1] (after port[0] writes above) ----------------
         if (v.hasInternalErr = '1') or (v.hasTimeOutErr = '1') then
            v.errOccurred    := '1';
            v.hasInternalErr := '0';               -- port[1] clear
         end if;

         ---------------- retryFlushDone (retry) ----------------
         if (inRetryState and isRetrying = '1') then
            v.retryFlush    := '0';
            v.recvRetryResp := '0';
         end if;

      end if;

      -- resetAndClear (isReset): force pre-stage to BUILD, clear mode flags; FIFOs cleared via fifoClr
      if (isReset = '1') then
         v.preStageState  := SQ_PRE_BUILD_STAGE_S;
         v.preRdmaOpCode  := ACKNOWLEDGE_C;
         v.preNextReadRespPsn := (others => '0');
         v.preReadRespPsnValid := '0';
         v.nextReadRespPsn := (others => '0');
         v.nextReadRespPsnValid := '0';
         v.readGapInFlight := '0';
         v.readReplayPending := '0';
         v.recvErrResp    := '0';
         v.recvRetryResp  := '0';
         v.errOccurred    := '0';
         v.retryFlush     := '0';
         v.hasInternalErr := '0';
         v.hasTimeOutErr  := '0';
      end if;

      -- structural synchronous reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin;
      end if;
   end process seq;

end architecture rtl;
