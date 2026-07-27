-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Three concurrent, FIFO-decoupled behaviours under ONE RegType (per the FSM
--   spec):
--     (1) Detection pipeline — 7 always-active rules gated only by isStableRTS +
--         FIFO occupancy (recvResetReq, recvRetryReq, checkTimeOut,
--         handleNotifiedRetryAndTimeOut, handleRetryAction, handleRetryCntUpdate,
--         sendRetryResp). No state register; pure feed-forward across FIFOs.
--     (2) Retry-control FSM — retryCntrlState (BSV mkCReg(2), 4 states). Rules
--         initRetry, waitRetryFinish, stopScanQ + port1 write from
--         handleRetryCntUpdate.
--     (3) Retry-handle FSM — retryHandleState (8 states). Rules startPreRetry,
--         rnrCheck, rnrWait, checkPartialRetry, modifyPartialRetryWR, startRetry,
--         waitRetryDone.
--   pauseRetryHandle partitions (2)/(3): handleRetryCntUpdate requires !pause;
--   initRetry requires pause; all handle-FSM rules require !pause.
--
--   CReg(2) ORDERING (FSM-spec item 1, carried forward): retryCntrlState has two
--   write ports. port0 writers = resetAndClear, initRetry, waitRetryFinish.
--   port1 writer = handleRetryCntUpdate. A port1 write OVERRIDES a same-cycle
--   port0 write. The only pair that can fire together is waitRetryFinish
--   (port0 -> NOT_RETRY) and handleRetryCntUpdate (port1 -> INIT_RETRY); when both
--   fire handleRetryCntUpdate must win. Two-process encoding: port0 writers
--   update v.retryCntrlState FIRST (Block 2 below), handleRetryCntUpdate applies
--   its update LAST (later assignment wins) and reads the already-updated v for
--   its hasRetryErr test.
--
--   FIFO clear: BSV FIFOF.clear under resetAndClear (isReset) -> fifoClr = rst or
--   isReset, asserted to every Fifo rst (level-safe sync clear; OQ-FSM-01
--   carry-forward). timeOutNotificationQ is additionally cleared by
--   initRetryCntAndTimeOutTimer (isRTR2RTS) -> tnClr = fifoClr or isRTR2RTS.
--   wr_en left ungated: FifoWrFsm sync reset dominates a concurrent write
--   (clear-after-enq ordering, per OQ-FSM-01).
--
--   SURF components instantiated (source: surf/base/fifo/rtl/Fifo.vhd), all 11
--   surf.Fifo FWFT/sync/block, ADDR_WIDTH_G=4:
--     U_ResetReqQ            1   U_TimeOutNotificationQ  1   U_RetryReqQ        97
--     U_RetryRespQ           1   U_ResetTimeOutQ         1   U_ResetRetryCntQ    1
--     U_TimeOutTriggerQ      1   U_RetryNotificationQ   98   U_RetryActionQ     98
--     U_UpdateRetryCntQ      4   U_PrepareRetryRespQ     4
--
--   Type widths (BSV deriving(Bits), first-field-at-MSB; traced from
--   DataTypes.bsv/Headers.bsv/Settings.bsv):
--     RetryReq=97 (wrID[96:33] | retryStartPSN[32:9] | retryReason[8:6] |
--       Maybe#RnrTimer[5:0] = tag[5]|value[4:0]); Maybe#(RetryReq)=98 (tag@97).
--     Maybe#(RetryReason)=4 (tag[3]|reason[2:0]).
--     Tuple2#(Bool,RetryReason)=4 (hasRetryErr[3]|reason[2:0]).
--     PendingWorkReq=679 (scanGetHead/modifyHead): wr[678:78] within which
--       wr.id[678:615], wr.raddr[605:542], wr.len[509:478], wr.laddr[477:414];
--       startPSN tag[77]/val[76:53]; endPSN tag[52]/val[51:28].
--     RetryReason(3): NOT_RETRY=000 RNR=001 SEQ_ERR=010 IMPLICIT=011 TIMEOUT=100.
--
--   Width corrections vs Stage-1 inventory (source-derived, not invented; same
--   class as OQ-FSM-DS2H-02 / OQ-FSM-CntrlQP-01):
--     rnrWaitCnt : RNR_WAIT_CYCLE_CNT_WIDTH = TLog#(MAX_RNR_WAIT_CYCLES) =
--                  TLog#(655360000/2 = 327680000) = 29 bits (inventory said 32).
--     timeOutCnt : TIMEOUT_CYCLE_CNT_WIDTH = 1+TLog#(MAX_TIMEOUT_CYCLES) =
--                  1+TLog#(2^43/2 = 2^42) = 43 bits (inventory said 64).
--     retryReason 3 bits (5 enum values), retryHandleState 3 bits (8 enum values).
--   isZero4LargeBits(timeOutCnt[42:0]) splits low=[20:0](21b), high=[42:21](22b).
--
--   Auxiliary datapath regs are BSV mkRegU (no reset) — zero-initialised here for
--   determinism; each is write-before-read within its retry episode so the chosen
--   init is not functionally observed (FSM-spec note).
--
--   Excluded/Deferred: all immAssert / immFail calls in the BSV source are
--   simulation-only and are NOT reproduced here (decRetryCntByReason default,
--   handleRetryCntUpdate !hasRetryErr, startPreRetry retryReason!=NOT_RETRY,
--   handleRetryAction pendingWorkReqNotEmpty / retryRnrTimer valid,
--   checkPartialRetry retryWorkReqId / PSN-in-range). See OQ-S3-RETRY-01/02.
--
--   REMINDER: emitting does not prove equivalence — simulate this entity (cocotb)
--   before trusting it (Stage 5, testbench-verify).
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

entity RetryHandleSq is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk                    : in  sl;
      rst                    : in  sl;                  -- active-high synchronous reset
      -- cntrlStatus.comm status methods (combinational inputs)
      isReset                : in  sl;                  -- comm.isReset   -> resetAndClear
      isERR                  : in  sl;                  -- comm.isERR     -> stopScanQ
      isStableRTS            : in  sl;                  -- comm.isStableRTS (gates all dataflow rules)
      isRTR2RTS              : in  sl;                  -- comm.isRTR2RTS -> initRetryCntAndTimeOutTimer
      getMaxRetryCnt         : in  slv(2 downto 0);     -- comm.getMaxRetryCnt (RetryCnt)
      getMaxRnrCnt           : in  slv(2 downto 0);     -- comm.getMaxRnrCnt   (RetryCnt)
      getMaxTimeOut          : in  slv(4 downto 0);     -- comm.getMaxTimeOut  (TimeOutTimer)
      getMinRnrTimer         : in  slv(4 downto 0);     -- comm.getMinRnrTimer (RnrTimer)
      getPMTU                : in  slv(2 downto 0);     -- comm.getPMTU (PMTU enum)
      -- pending-WR scan status (input)
      pendingWorkReqNotEmpty : in  sl;
      -- pendingWorkReqScanCntrl : ScanCntrl#(PendingWorkReq) — FSM consumes (in)
      scanGetHead            : in  slv(678 downto 0);   -- getHead (PendingWorkReq)
      scanIsScanDone         : in  sl;                  -- isScanDone
      -- pendingWorkReqScanCntrl drives (out, combinational pulses)
      scanClear              : out sl;                  -- clear
      scanStop               : out sl;                  -- scanStop
      scanStart              : out sl;                  -- scanStart
      scanPreScanStart       : out sl;                  -- preScanStart
      scanPreScanRestart     : out sl;                  -- preScanRestart
      scanModifyHeadValid    : out sl;                  -- modifyHead strobe
      scanModifyHeadData     : out slv(678 downto 0);   -- modifyHead(head)
      -- status methods (combinational Moore outputs)
      hasRetryErr            : out sl;
      isRetryDone            : out sl;
      isRetrying             : out sl;
      -- resetRetryCntAndTimeOutBySQ : Action(ResetRetryCntAndTimeOutReq) (1b)
      resetReqValid          : in  sl;                  -- caller enable
      resetReqData           : in  sl;                  -- 0=RESET_TIMEOUT, 1=RESET_CNT_AND_TIMEOUT
      resetReqReady          : out sl;                  -- isStableRTS and resetReqQ.notFull
      -- notifyTimeOut2SQ : Get#(TimeOutNotification) (1b)
      timeOutNotifValid      : out sl;                  -- notEmpty
      timeOutNotifData       : out sl;                  -- 0=TIMEOUT_RETRY, 1=TIMEOUT_ERR
      timeOutNotifGetEn      : in  sl;                  -- external deq
      -- srvPort.request : Put#(RetryReq) (97b)
      srvReqValid            : in  sl;
      srvReqData             : in  slv(96 downto 0);
      srvReqReady            : out sl;                  -- retryReqQ.notFull
      -- srvPort.response : Get#(RetryResp) (2b)
      srvRespValid           : out sl;                  -- notEmpty
      srvRespData            : out slv(1 downto 0);     -- bit0: 0=RECV_RETRY_REQ, 1=RETRY_LIMIT_EXC; bit1: reason was RNR
      srvRespGetEn           : in  sl);                 -- external deq
end entity RetryHandleSq;

architecture rtl of RetryHandleSq is

   ---------------------------------------------------------------------------
   -- Width constants (source-derived; see header)
   ---------------------------------------------------------------------------
   constant RNR_WAIT_W_C : integer := 29;   -- RNR_WAIT_CYCLE_CNT_WIDTH
   constant TIMEOUT_W_C  : integer := 43;   -- TIMEOUT_CYCLE_CNT_WIDTH
   constant INFINITE_RETRY_C : slv(2 downto 0) := "111";  -- INFINITE_RETRY = 7

   ---------------------------------------------------------------------------
   -- Enum encodings
   ---------------------------------------------------------------------------
   -- RetryReason (3b)
   constant RR_NOT_RETRY_C : slv(2 downto 0) := "000";
   constant RR_RNR_C       : slv(2 downto 0) := "001";
   constant RR_SEQ_ERR_C   : slv(2 downto 0) := "010";
   constant RR_IMPLICIT_C  : slv(2 downto 0) := "011";
   constant RR_TIMEOUT_C   : slv(2 downto 0) := "100";
   -- ResetRetryCntAndTimeOutReq (1b)
   constant RESET_TIMEOUT_C     : sl := '0';
   constant RESET_CNT_TIMEOUT_C : sl := '1';
   -- TimeOutNotification (1b): TIMEOUT_RETRY=0, TIMEOUT_ERR=1
   constant TIMEOUT_RETRY_C : sl := '0';
   constant TIMEOUT_ERR_C   : sl := '1';
   -- RetryResp (2b): bit0 RECV_RETRY_REQ=0 / RETRY_LIMIT_EXC=1;
   --                 bit1 = reason was RNR (qualifier, meaningful when bit0='1')
   constant RECV_RETRY_REQ_C  : sl := '0';
   constant RETRY_LIMIT_EXC_C : sl := '1';

   ---------------------------------------------------------------------------
   -- FSM state types
   ---------------------------------------------------------------------------
   type RetryCntrlStateType is (
      RETRY_CNTRL_ST_NOT_RETRY_S,
      RETRY_CNTRL_ST_RETRY_LIMIT_EXC_S,
      RETRY_CNTRL_ST_INIT_RETRY_S,
      RETRY_CNTRL_ST_WAIT_RETRY_DONE_S);

   type RetryHandleStateType is (
      RETRY_HANDLE_ST_NOT_RETRY_S,
      RETRY_HANDLE_ST_START_PRE_RETRY_S,
      RETRY_HANDLE_ST_RNR_CHECK_S,
      RETRY_HANDLE_ST_RNR_WAIT_S,
      RETRY_HANDLE_ST_CHECK_PARTIAL_RETRY_WR_S,
      RETRY_HANDLE_ST_MODIFY_PARTIAL_RETRY_WR_S,
      RETRY_HANDLE_ST_START_RETRY_S,
      RETRY_HANDLE_ST_WAIT_RETRY_DONE_S);

   ---------------------------------------------------------------------------
   -- RegType : ONE record (three coupled FSMs + aux datapath)
   ---------------------------------------------------------------------------
   type RegType is record
      -- control + handle FSM state (real BSV mkReg/mkCReg inits)
      retryCntrlState          : RetryCntrlStateType;
      retryHandleState         : RetryHandleStateType;
      pauseRetryHandle         : sl;
      -- auxiliary datapath (BSV mkRegU — zero-init for determinism)
      rnrWaitCnt               : slv(RNR_WAIT_W_C-1 downto 0);
      isRnrWaitCntZero         : sl;
      timeOutCnt               : slv(TIMEOUT_W_C-1 downto 0);
      isTimeOutCntHighPartZero : sl;
      isTimeOutCntLowPartZero  : sl;
      disableTimeOut           : sl;
      disableRetryCnt          : sl;
      retryReason              : slv(2 downto 0);
      retryWorkReqId           : slv(63 downto 0);
      retryStartPsn            : slv(23 downto 0);
      psnDiff                  : slv(23 downto 0);
      retryRnrTimer            : slv(4 downto 0);
      retryCnt                 : slv(2 downto 0);
      rnrCnt                   : slv(2 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      retryCntrlState          => RETRY_CNTRL_ST_NOT_RETRY_S,
      retryHandleState         => RETRY_HANDLE_ST_NOT_RETRY_S,
      pauseRetryHandle         => '0',
      rnrWaitCnt               => (others => '0'),
      isRnrWaitCntZero         => '0',
      timeOutCnt               => (others => '0'),
      isTimeOutCntHighPartZero => '0',
      isTimeOutCntLowPartZero  => '0',
      disableTimeOut           => '0',
      disableRetryCnt          => '0',
      retryReason              => (others => '0'),
      retryWorkReqId           => (others => '0'),
      retryStartPsn            => (others => '0'),
      psnDiff                  => (others => '0'),
      retryRnrTimer            => (others => '0'),
      retryCnt                 => (others => '0'),
      rnrCnt                   => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   ---------------------------------------------------------------------------
   -- FIFO interface signals (one bundle per surf.Fifo)
   ---------------------------------------------------------------------------
   -- resetReqQ (1b)
   signal rrqWrEn : sl;
   signal rrqRdEn : sl;
   signal rrqValid : sl;
   signal rrqNotFull : sl;
   signal rrqDin, rrqDout                        : slv(0 downto 0);
   -- timeOutNotificationQ (1b)
   signal tnqWrEn : sl;
   signal tnqRdEn : sl;
   signal tnqValid : sl;
   signal tnqNotFull : sl;
   signal tnqDin, tnqDout                        : slv(0 downto 0);
   signal tnqClr                                 : sl;
   -- retryReqQ (97b)
   signal xrqWrEn : sl;
   signal xrqRdEn : sl;
   signal xrqValid : sl;
   signal xrqNotFull : sl;
   signal xrqDin, xrqDout                        : slv(96 downto 0);
   -- retryRespQ (1b)
   signal rsqWrEn : sl;
   signal rsqRdEn : sl;
   signal rsqValid : sl;
   signal rsqNotFull : sl;
   signal rsqDin, rsqDout                        : slv(1 downto 0);
   -- resetTimeOutQ (1b)
   signal rtqWrEn : sl;
   signal rtqRdEn : sl;
   signal rtqValid : sl;
   signal rtqNotFull : sl;
   signal rtqDin, rtqDout                        : slv(0 downto 0);
   -- resetRetryCntQ (1b)
   signal rcqWrEn : sl;
   signal rcqRdEn : sl;
   signal rcqValid : sl;
   signal rcqNotFull : sl;
   signal rcqDin, rcqDout                        : slv(0 downto 0);
   -- timeOutTriggerQ (1b)
   signal ttqWrEn : sl;
   signal ttqRdEn : sl;
   signal ttqValid : sl;
   signal ttqNotFull : sl;
   signal ttqDin, ttqDout                        : slv(0 downto 0);
   -- retryNotificationQ (98b)
   signal rnqWrEn : sl;
   signal rnqRdEn : sl;
   signal rnqValid : sl;
   signal rnqNotFull : sl;
   signal rnqDin, rnqDout                        : slv(97 downto 0);
   -- retryActionQ (98b)
   signal raqWrEn : sl;
   signal raqRdEn : sl;
   signal raqValid : sl;
   signal raqNotFull : sl;
   signal raqDin, raqDout                        : slv(97 downto 0);
   -- updateRetryCntQ (4b)
   signal urqWrEn : sl;
   signal urqRdEn : sl;
   signal urqValid : sl;
   signal urqNotFull : sl;
   signal urqDin, urqDout                        : slv(3 downto 0);
   -- prepareRetryRespQ (4b)
   signal prqWrEn : sl;
   signal prqRdEn : sl;
   signal prqValid : sl;
   signal prqNotFull : sl;
   signal prqDin, prqDout                        : slv(3 downto 0);

   signal fifoClr : sl;

   ---------------------------------------------------------------------------
   -- Helper functions (BSV Utils.bsv / PrimUtils.bsv equivalents)
   ---------------------------------------------------------------------------
   -- PMTU enum -> log2(PMTU bytes): 256->8, 512->9, 1024->10, 2048->11, 4096->12
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

   -- addrAddPsnMultiplyPMTU = addr + (psn << log2(PMTU))
   function addrAddPsn(addr : slv(63 downto 0); psn : slv(23 downto 0); pmtu : slv(2 downto 0)) return slv is
   begin
      return slv(unsigned(addr) + shift_left(resize(unsigned(psn), 64), pmtuLog(pmtu)));
   end function;

   -- lenSubtractPsnMultiplyPMTU = len - (psn << log2(PMTU))
   function lenSubPsn(len : slv(31 downto 0); psn : slv(23 downto 0); pmtu : slv(2 downto 0)) return slv is
   begin
      return slv(unsigned(len) - shift_left(resize(unsigned(psn), 32), pmtuLog(pmtu)));
   end function;

   -- calcPsnDiff(a,b) = truncate({1'b1,a} - {1'b0,b}) = (a - b) mod 2^24
   function calcPsnDiff(a : slv(23 downto 0); b : slv(23 downto 0)) return slv is
   begin
      return slv(unsigned(a) - unsigned(b));
   end function;

   -- getRnrTimeOutValue(rnrTimer) in cycles (TARGET_CYCLE_NS = 2). Max 327680000
   -- fits in 29 bits and in a 32-bit integer.
   function getRnrTimeOutValue(t : slv(4 downto 0)) return integer is
   begin
      case to_integer(unsigned(t)) is
         when 0      => return 327680000;
         when 1      => return 5000;
         when 2      => return 10000;
         when 3      => return 15000;
         when 4      => return 20000;
         when 5      => return 30000;
         when 6      => return 40000;
         when 7      => return 60000;
         when 8      => return 80000;
         when 9      => return 120000;
         when 10     => return 160000;
         when 11     => return 240000;
         when 12     => return 320000;
         when 13     => return 480000;
         when 14     => return 640000;
         when 15     => return 960000;
         when 16     => return 1280000;
         when 17     => return 1920000;
         when 18     => return 2560000;
         when 19     => return 3840000;
         when 20     => return 5120000;
         when 21     => return 7680000;
         when 22     => return 10240000;
         when 23     => return 15360000;
         when 24     => return 20480000;
         when 25     => return 30720000;
         when 26     => return 40960000;
         when 27     => return 61440000;
         when 28     => return 81920000;
         when 29     => return 122880000;
         when 30     => return 163840000;
         when others => return 245760000;  -- 31
      end case;
   end function;

   -- getTimeOutValue(t) in cycles (TARGET_CYCLE_NS = 2): t=0 -> 0 (infinite),
   -- else 8192 * 2^(t-1) / 2 = 2^(11+t). Max 2^42, needs 43-bit (exceeds integer).
   function getTimeOutValue(t : slv(4 downto 0)) return slv is
      variable ti : integer;
   begin
      ti := to_integer(unsigned(t));
      if ti = 0 then
         return slv(to_unsigned(0, TIMEOUT_W_C));
      else
         return slv(shift_left(to_unsigned(1, TIMEOUT_W_C), 11 + ti));
      end if;
   end function;

begin

   ---------------------------------------------------------------------------
   -- Clears (level-safe synchronous flush; OQ-FSM-01 carry-forward)
   ---------------------------------------------------------------------------
   fifoClr <= rst or isReset;
   tnqClr  <= rst or isReset or isRTR2RTS;   -- initRetryCntAndTimeOutTimer clears timeOutNotificationQ
   scanClear <= rst or isReset;              -- resetAndClear: pendingWorkReqScanCntrl.clear

   ---------------------------------------------------------------------------
   -- Status methods (combinational Moore outputs from registered state)
   ---------------------------------------------------------------------------
   hasRetryErr <= '1' when r.retryCntrlState = RETRY_CNTRL_ST_RETRY_LIMIT_EXC_S else '0';
   isRetryDone <= '1' when r.retryCntrlState = RETRY_CNTRL_ST_NOT_RETRY_S       else '0';
   isRetrying  <= '1' when r.retryHandleState = RETRY_HANDLE_ST_WAIT_RETRY_DONE_S else '0';

   ---------------------------------------------------------------------------
   -- Method handshakes (external put/get faces; constant w.r.t. r)
   ---------------------------------------------------------------------------
   -- resetRetryCntAndTimeOutBySQ : Action put, guard isStableRTS + notFull
   resetReqReady <= isStableRTS and rrqNotFull;
   rrqWrEn       <= resetReqValid and isStableRTS and rrqNotFull;
   rrqDin(0)     <= resetReqData;
   -- srvPort.request : Put#(RetryReq)
   srvReqReady   <= xrqNotFull;
   xrqWrEn       <= srvReqValid and xrqNotFull;
   xrqDin        <= srvReqData;
   -- notifyTimeOut2SQ : Get#(TimeOutNotification)
   timeOutNotifValid <= tnqValid;
   timeOutNotifData  <= tnqDout(0);
   tnqRdEn           <= timeOutNotifGetEn;
   -- srvPort.response : Get#(RetryResp)
   srvRespValid <= rsqValid;
   srvRespData  <= rsqDout;
   rsqRdEn      <= srvRespGetEn;

   ---------------------------------------------------------------------------
   -- 11 SURF Fifo instances (all FWFT/sync/block, ADDR_WIDTH_G=4)
   ---------------------------------------------------------------------------
   U_ResetReqQ : entity surf.Fifo
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
         rst => fifoClr,
         wr_clk => clk,
         wr_en => rrqWrEn,
         din => rrqDin,
         not_full => rrqNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk => clk,
         rd_en => rrqRdEn,
         dout => rrqDout,
         valid => rrqValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_TimeOutNotificationQ : entity surf.Fifo
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
         rst => tnqClr,
         wr_clk => clk,
         wr_en => tnqWrEn,
         din => tnqDin,
         not_full => tnqNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk => clk,
         rd_en => tnqRdEn,
         dout => tnqDout,
         valid => tnqValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_RetryReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 97,
         ADDR_WIDTH_G    => 4)
      port map (
         rst => fifoClr,
         wr_clk => clk,
         wr_en => xrqWrEn,
         din => xrqDin,
         not_full => xrqNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk => clk,
         rd_en => xrqRdEn,
         dout => xrqDout,
         valid => xrqValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_RetryRespQ : entity surf.Fifo
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
         rst => fifoClr,
         wr_clk => clk,
         wr_en => rsqWrEn,
         din => rsqDin,
         not_full => rsqNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk => clk,
         rd_en => rsqRdEn,
         dout => rsqDout,
         valid => rsqValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_ResetTimeOutQ : entity surf.Fifo
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
         rst => fifoClr,
         wr_clk => clk,
         wr_en => rtqWrEn,
         din => rtqDin,
         not_full => rtqNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk => clk,
         rd_en => rtqRdEn,
         dout => rtqDout,
         valid => rtqValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_ResetRetryCntQ : entity surf.Fifo
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
         rst => fifoClr,
         wr_clk => clk,
         wr_en => rcqWrEn,
         din => rcqDin,
         not_full => rcqNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk => clk,
         rd_en => rcqRdEn,
         dout => rcqDout,
         valid => rcqValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_TimeOutTriggerQ : entity surf.Fifo
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
         rst => fifoClr,
         wr_clk => clk,
         wr_en => ttqWrEn,
         din => ttqDin,
         not_full => ttqNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk => clk,
         rd_en => ttqRdEn,
         dout => ttqDout,
         valid => ttqValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_RetryNotificationQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 98,
         ADDR_WIDTH_G    => 4)
      port map (
         rst => fifoClr,
         wr_clk => clk,
         wr_en => rnqWrEn,
         din => rnqDin,
         not_full => rnqNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk => clk,
         rd_en => rnqRdEn,
         dout => rnqDout,
         valid => rnqValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_RetryActionQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 98,
         ADDR_WIDTH_G    => 4)
      port map (
         rst => fifoClr,
         wr_clk => clk,
         wr_en => raqWrEn,
         din => raqDin,
         not_full => raqNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk => clk,
         rd_en => raqRdEn,
         dout => raqDout,
         valid => raqValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_UpdateRetryCntQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 4,
         ADDR_WIDTH_G    => 4)
      port map (
         rst => fifoClr,
         wr_clk => clk,
         wr_en => urqWrEn,
         din => urqDin,
         not_full => urqNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk => clk,
         rd_en => urqRdEn,
         dout => urqDout,
         valid => urqValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_PrepareRetryRespQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 4,
         ADDR_WIDTH_G    => 4)
      port map (
         rst => fifoClr,
         wr_clk => clk,
         wr_en => prqWrEn,
         din => prqDin,
         not_full => prqNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk => clk,
         rd_en => prqRdEn,
         dout => prqDout,
         valid => prqValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- Combinatorial process
   ---------------------------------------------------------------------------
   comb : process (r, rst, isReset, isERR, isStableRTS, isRTR2RTS,
                   getMaxRetryCnt, getMaxRnrCnt, getMaxTimeOut, getMinRnrTimer,
                   getPMTU, pendingWorkReqNotEmpty, scanGetHead, scanIsScanDone,
                   rrqValid, rrqDout, rcqValid, rcqNotFull, rcqDout,
                   xrqValid, xrqDout, rtqValid, rtqNotFull,
                   ttqValid, ttqNotFull, ttqDout,
                   rnqValid, rnqDout, rnqNotFull, raqValid, raqDout, raqNotFull,
                   urqValid, urqDout, urqNotFull, prqValid, prqDout, prqNotFull,
                   tnqNotFull, rsqNotFull) is
      variable v : RegType;
      -- recvRetryReq
      variable enqNotif : boolean;
      -- handleNotified
      variable hasTimeOut   : boolean;
      variable hasRetry     : boolean;
      variable timeoutMaybe : slv(97 downto 0);
      -- handleRetryAction
      variable reason    : slv(2 downto 0);
      variable updCntDin : slv(3 downto 0);
      -- handleRetryCntUpdate
      variable hRetryErr : sl;
      variable exceed    : boolean;
      variable nextCtrl  : RetryCntrlStateType;
      -- handle FSM
      variable rnrTimerV   : slv(4 downto 0);
      variable startPsnV   : slv(23 downto 0);
      variable retryStartV : slv(23 downto 0);
      variable modHead     : slv(678 downto 0);
   begin
      v := r;

      -- default FIFO/scan drives (comb-driven only; method faces are concurrent)
      rrqRdEn <= '0';
      tnqWrEn <= '0'; tnqDin <= (others => '0');
      xrqRdEn <= '0';
      rsqWrEn <= '0'; rsqDin <= (others => '0');
      rtqWrEn <= '0'; rtqRdEn <= '0'; rtqDin <= (others => '0');
      rcqWrEn <= '0'; rcqRdEn <= '0'; rcqDin <= (others => '0');
      ttqWrEn <= '0'; ttqRdEn <= '0'; ttqDin <= (others => '0');
      rnqWrEn <= '0'; rnqRdEn <= '0'; rnqDin <= (others => '0');
      raqWrEn <= '0'; raqRdEn <= '0'; raqDin <= (others => '0');
      urqWrEn <= '0'; urqRdEn <= '0'; urqDin <= (others => '0');
      prqWrEn <= '0'; prqRdEn <= '0'; prqDin <= (others => '0');
      scanStop <= '0'; scanStart <= '0';
      scanPreScanStart <= '0'; scanPreScanRestart <= '0';
      scanModifyHeadValid <= '0'; scanModifyHeadData <= (others => '0');

      ----------------------------------------------------------------------
      -- BLOCK 1 — detection pipeline (gated isStableRTS); no state register.
      -- Each rule is independent and FIFO-decoupled.
      ----------------------------------------------------------------------
      if (isStableRTS = '1') then

         -- recvResetReq: deq resetReqQ; enq resetTimeOutQ (+ resetRetryCntQ on
         -- RESET_CNT). Atomicity: all enq targets must be notFull to fire.
         if (rrqValid = '1') and (rtqNotFull = '1') and
            ((rrqDout(0) = RESET_TIMEOUT_C) or (rcqNotFull = '1')) then
            rrqRdEn <= '1';
            rtqWrEn <= '1'; rtqDin <= "1";          -- resetTimeOut = True
            if (rrqDout(0) = RESET_CNT_TIMEOUT_C) then
               rcqWrEn <= '1'; rcqDin <= "1";        -- resetRetryCnt = True
            end if;
         end if;

         -- recvRetryReq: retry has priority over reset-retry-cnt.
         enqNotif := (rcqValid = '1') or (xrqValid = '1');
         if (not enqNotif) or (rnqNotFull = '1') then
            if (rcqValid = '1') then rcqRdEn <= '1'; end if;
            if (xrqValid = '1') then xrqRdEn <= '1'; end if;
            if enqNotif then
               rnqWrEn <= '1';
               if (xrqValid = '1') then
                  rnqDin <= '1' & xrqDout;            -- Valid(retryReqQ.first)
               else
                  rnqDin <= (others => '0');          -- Invalid
               end if;
            end if;
         end if;

         -- checkTimeOut: timeout down-counter / trigger.
         if (rtqValid = '1') or (r.retryCntrlState /= RETRY_CNTRL_ST_NOT_RETRY_S) then
            -- resetTimeOutCntInternal
            v.timeOutCnt               := getTimeOutValue(getMaxTimeOut);
            v.disableTimeOut           := '1' when (getMaxTimeOut = "00000") else '0';
            v.isTimeOutCntHighPartZero := '0';
            v.isTimeOutCntLowPartZero  := '0';
            if (rtqValid = '1') then rtqRdEn <= '1'; end if;
         elsif (r.disableTimeOut = '0') and (pendingWorkReqNotEmpty = '1') then
            if (r.isTimeOutCntHighPartZero = '1') and (r.isTimeOutCntLowPartZero = '1') then
               if (ttqNotFull = '1') then
                  ttqWrEn <= '1'; ttqDin <= "1";      -- triggerTimeOut = True
                  v.timeOutCnt               := getTimeOutValue(getMaxTimeOut);
                  v.disableTimeOut           := '1' when (getMaxTimeOut = "00000") else '0';
                  v.isTimeOutCntHighPartZero := '0';
                  v.isTimeOutCntLowPartZero  := '0';
               end if;
            else
               v.timeOutCnt := slv(unsigned(r.timeOutCnt) - 1);
               -- isZero4LargeBits(timeOutCntReg) on the CURRENT value (BSV)
               v.isTimeOutCntHighPartZero := '1' when (unsigned(r.timeOutCnt(TIMEOUT_W_C-1 downto 21)) = 0) else '0';
               v.isTimeOutCntLowPartZero  := '1' when (unsigned(r.timeOutCnt(20 downto 0)) = 0) else '0';
            end if;
         end if;

         -- handleNotifiedRetryAndTimeOut: retry req overrides synthesized timeout.
         hasTimeOut := (ttqValid = '1');
         hasRetry   := (rnqValid = '1');
         timeoutMaybe := (others => '0');
         timeoutMaybe(97)          := '1';            -- Valid
         timeoutMaybe(8 downto 6)  := RR_TIMEOUT_C;   -- retryReason = TIMEOUT
         if (not (hasTimeOut or hasRetry)) or (raqNotFull = '1') then
            if hasTimeOut then ttqRdEn <= '1'; end if;
            if hasRetry   then rnqRdEn <= '1'; end if;
            if (hasTimeOut or hasRetry) then
               raqWrEn <= '1';
               if hasRetry then
                  raqDin <= rnqDout;                  -- Valid(retryReq) passthrough
               else
                  raqDin <= timeoutMaybe;
               end if;
            end if;
         end if;

         -- handleRetryAction: latch retry context, push Maybe#(RetryReason).
         if (raqValid = '1') and (urqNotFull = '1') then
            raqRdEn <= '1';
            updCntDin := (others => '0');             -- Invalid
            if (raqDout(97) = '1') then               -- isValid(maybeReq)
               reason := raqDout(8 downto 6);
               if (reason /= RR_TIMEOUT_C) then
                  v.retryWorkReqId := raqDout(96 downto 33);
                  v.retryStartPsn  := raqDout(32 downto 9);
                  if (reason = RR_RNR_C) then
                     v.retryRnrTimer := raqDout(4 downto 0);  -- unwrap(retryRnrTimer)
                  end if;
               end if;
               v.retryReason := reason;
               updCntDin     := '1' & reason;         -- Valid(reason)
            end if;
            urqWrEn <= '1'; urqDin <= updCntDin;
         end if;

         -- sendRetryResp: emit response on timeOutNotificationQ or retryRespQ.
         if (prqValid = '1') then
            reason := prqDout(2 downto 0);
            if (reason = RR_TIMEOUT_C) then
               if (tnqNotFull = '1') then
                  prqRdEn <= '1';
                  tnqWrEn <= '1';
                  if (prqDout(3) = '1') then tnqDin <= (0 => TIMEOUT_ERR_C);
                  else                       tnqDin <= (0 => TIMEOUT_RETRY_C); end if;
               end if;
            else
               if (rsqNotFull = '1') then
                  prqRdEn <= '1';
                  rsqWrEn <= '1';
                  if (prqDout(3) = '1') then rsqDin(0) <= RETRY_LIMIT_EXC_C;
                  else                       rsqDin(0) <= RECV_RETRY_REQ_C; end if;
                  if (reason = RR_RNR_C) then rsqDin(1) <= '1'; end if;  -- RNR qualifier
               end if;
            end if;
         end if;

      end if;  -- isStableRTS (Block 1)

      ----------------------------------------------------------------------
      -- BLOCK 3 — retry-handle FSM (gated isStableRTS & !pause). Placed before
      -- the CReg port1 write; touches retryHandleState only.
      ----------------------------------------------------------------------
      if (isStableRTS = '1') and (r.pauseRetryHandle = '0') then
         case r.retryHandleState is
            when RETRY_HANDLE_ST_START_PRE_RETRY_S =>
               if (r.retryReason = RR_RNR_C) then
                  v.retryHandleState := RETRY_HANDLE_ST_RNR_CHECK_S;
               else
                  v.retryHandleState := RETRY_HANDLE_ST_CHECK_PARTIAL_RETRY_WR_S;
               end if;
               if (scanIsScanDone = '1') then scanPreScanStart   <= '1';
               else                           scanPreScanRestart <= '1'; end if;

            when RETRY_HANDLE_ST_RNR_CHECK_S =>
               if (unsigned(r.retryRnrTimer) > unsigned(getMinRnrTimer)) then
                  rnrTimerV := r.retryRnrTimer;
               else
                  rnrTimerV := getMinRnrTimer;
               end if;
               v.rnrWaitCnt       := slv(to_unsigned(getRnrTimeOutValue(rnrTimerV), RNR_WAIT_W_C));
               v.isRnrWaitCntZero := '0';
               v.retryHandleState := RETRY_HANDLE_ST_RNR_WAIT_S;

            when RETRY_HANDLE_ST_RNR_WAIT_S =>
               if (r.isRnrWaitCntZero = '1') then
                  v.retryHandleState := RETRY_HANDLE_ST_CHECK_PARTIAL_RETRY_WR_S;
               else
                  v.rnrWaitCnt       := slv(unsigned(r.rnrWaitCnt) - 1);
                  v.isRnrWaitCntZero := '1' when (unsigned(r.rnrWaitCnt) = 1) else '0';  -- isOne
               end if;

            when RETRY_HANDLE_ST_CHECK_PARTIAL_RETRY_WR_S =>
               startPsnV := scanGetHead(76 downto 53);          -- head.startPSN.val
               if (r.retryReason = RR_TIMEOUT_C) then
                  retryStartV := startPsnV;
               else
                  retryStartV := r.retryStartPsn;
               end if;
               v.psnDiff          := calcPsnDiff(retryStartV, startPsnV);
               v.retryHandleState := RETRY_HANDLE_ST_MODIFY_PARTIAL_RETRY_WR_S;

            when RETRY_HANDLE_ST_MODIFY_PARTIAL_RETRY_WR_S =>
               modHead := scanGetHead;
               modHead(509 downto 478) := lenSubPsn (scanGetHead(509 downto 478), r.psnDiff, getPMTU);  -- wr.len
               modHead(477 downto 414) := addrAddPsn(scanGetHead(477 downto 414), r.psnDiff, getPMTU);  -- wr.laddr
               modHead(605 downto 542) := addrAddPsn(scanGetHead(605 downto 542), r.psnDiff, getPMTU);  -- wr.raddr
               if (r.retryReason /= RR_TIMEOUT_C) then
                  modHead(77)            := '1';                  -- startPSN tag = Valid
                  modHead(76 downto 53)  := r.retryStartPsn;
               end if;
               scanModifyHeadValid <= '1';
               scanModifyHeadData  <= modHead;
               v.retryHandleState  := RETRY_HANDLE_ST_START_RETRY_S;

            when RETRY_HANDLE_ST_START_RETRY_S =>
               scanStart          <= '1';
               v.retryHandleState := RETRY_HANDLE_ST_WAIT_RETRY_DONE_S;

            when RETRY_HANDLE_ST_WAIT_RETRY_DONE_S =>
               if (scanIsScanDone = '1') then
                  v.retryHandleState := RETRY_HANDLE_ST_NOT_RETRY_S;
               end if;

            when others =>                                       -- NOT_RETRY_S idle
               null;
         end case;
      end if;

      ----------------------------------------------------------------------
      -- BLOCK 2 — retry-control FSM port0 writers (initRetry, waitRetryFinish)
      -- + stopScanQ. Applied BEFORE the CReg port1 write below.
      ----------------------------------------------------------------------
      -- initRetry (port0 -> WAIT_RETRY_DONE)
      if (isStableRTS = '1') and (r.pauseRetryHandle = '1') and
         (r.retryCntrlState = RETRY_CNTRL_ST_INIT_RETRY_S) then
         v.pauseRetryHandle := '0';
         v.retryHandleState := RETRY_HANDLE_ST_START_PRE_RETRY_S;
         v.retryCntrlState  := RETRY_CNTRL_ST_WAIT_RETRY_DONE_S;
      end if;

      -- waitRetryFinish (port0 -> NOT_RETRY)
      if (isStableRTS = '1') and
         (r.retryCntrlState = RETRY_CNTRL_ST_WAIT_RETRY_DONE_S) and
         (r.retryHandleState = RETRY_HANDLE_ST_WAIT_RETRY_DONE_S) and
         (scanIsScanDone = '1') then
         v.retryCntrlState := RETRY_CNTRL_ST_NOT_RETRY_S;
      end if;

      -- stopScanQ (no state change)
      if (isERR = '1') or
         ((r.pauseRetryHandle = '1') and (r.retryCntrlState = RETRY_CNTRL_ST_RETRY_LIMIT_EXC_S)) then
         scanStop <= '1';
      end if;

      ----------------------------------------------------------------------
      -- handleRetryCntUpdate — CReg(2) port1 write (applied LAST; overrides the
      -- port0 writers above). Gated isStableRTS & !pause & updateRetryCntQ.valid.
      ----------------------------------------------------------------------
      if (isStableRTS = '1') and (r.pauseRetryHandle = '0') and (urqValid = '1') then
         if (urqDout(3) = '1') then                -- Valid(reason)
            if (prqNotFull = '1') then             -- prepareRetryRespQ.enq atomicity
               reason := urqDout(2 downto 0);
               urqRdEn <= '1';
               v.pauseRetryHandle := '1';
               -- decRetryCntByReason (reads current r counts)
               if (r.disableRetryCnt = '0') then
                  if (reason = RR_RNR_C) then
                     if (r.rnrCnt /= "000") then v.rnrCnt := slv(unsigned(r.rnrCnt) - 1); end if;
                  elsif (reason = RR_SEQ_ERR_C) or (reason = RR_IMPLICIT_C) or (reason = RR_TIMEOUT_C) then
                     if (r.retryCnt /= "000") then v.retryCnt := slv(unsigned(r.retryCnt) - 1); end if;
                  end if;
               end if;
               -- retryCntExceedLimit
               exceed := false;
               if (reason = RR_RNR_C) then
                  exceed := (r.rnrCnt = "000");
               elsif (reason = RR_SEQ_ERR_C) or (reason = RR_IMPLICIT_C) or (reason = RR_TIMEOUT_C) then
                  exceed := (r.retryCnt = "000");
               end if;
               -- hasRetryErr: port1 read sees the same-cycle port0 update in v
               hRetryErr := '0';
               if (v.retryCntrlState = RETRY_CNTRL_ST_RETRY_LIMIT_EXC_S) then hRetryErr := '1'; end if;
               nextCtrl := RETRY_CNTRL_ST_INIT_RETRY_S;
               if exceed then
                  nextCtrl  := RETRY_CNTRL_ST_RETRY_LIMIT_EXC_S;
                  hRetryErr := '1';
               end if;
               v.retryCntrlState := nextCtrl;       -- port1 write (overrides port0)
               prqWrEn <= '1';
               prqDin  <= hRetryErr & reason;       -- tuple2(hasRetryErr, reason)
            end if;
         else                                      -- Invalid -> resetRetryCntInternal
            urqRdEn <= '1';
            v.retryCnt        := getMaxRetryCnt;
            v.rnrCnt          := getMaxRnrCnt;
            v.disableRetryCnt := '1' when (getMaxRetryCnt = INFINITE_RETRY_C) else '0';
         end if;
      end if;

      ----------------------------------------------------------------------
      -- initRetryCntAndTimeOutTimer (isRTR2RTS): reload counters/timers.
      -- timeOutNotificationQ cleared via tnqClr.
      ----------------------------------------------------------------------
      if (isRTR2RTS = '1') then
         v.retryCnt                 := getMaxRetryCnt;
         v.rnrCnt                   := getMaxRnrCnt;
         v.disableRetryCnt          := '1' when (getMaxRetryCnt = INFINITE_RETRY_C) else '0';
         v.timeOutCnt               := getTimeOutValue(getMaxTimeOut);
         v.disableTimeOut           := '1' when (getMaxTimeOut = "00000") else '0';
         v.isTimeOutCntHighPartZero := '0';
         v.isTimeOutCntLowPartZero  := '0';
      end if;

      ----------------------------------------------------------------------
      -- resetAndClear (isReset): state regs -> NOT_RETRY, pause -> 0
      -- (fire_when_enabled; FIFOs/scan cleared via fifoClr/scanClear).
      ----------------------------------------------------------------------
      if (isReset = '1') then
         v.retryCntrlState  := RETRY_CNTRL_ST_NOT_RETRY_S;
         v.retryHandleState := RETRY_HANDLE_ST_NOT_RETRY_S;
         v.pauseRetryHandle := '0';
      end if;

      -- synchronous (FPGA) reset
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
