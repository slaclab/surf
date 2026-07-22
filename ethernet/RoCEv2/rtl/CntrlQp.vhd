-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Purpose: Per-QueuePair IB modify-state controller. The single control FSM is
--          the QP state machine (stateReg/StateQP). Seven mutually-exclusive
--          on* rules service one request from reqQ, emit a response into respQ,
--          latch QP attributes and propose a next state; rule canonicalize is
--          the single point that commits stateReg (with a setStateErr override).
--
-- SURF components instantiated (read from /home/fmarini/sink/surf/base/fifo/rtl/Fifo.vhd):
--   U_ReqQ     : surf.Fifo  (reqQ,     ReqQP   = 301 bits)
--   U_RespQ    : surf.Fifo  (respQ,    RespQP  = 274 bits)
--   U_RestoreQ : surf.Fifo  (restoreQ, {RdmaOpCode,PSN} = 29 bits)
--
-- Struct bit packing: BSV deriving(Bits) packs the FIRST field at the MSBs
--   (the project-wide convention confirmed in OQ-FSM-16 / RESOLVED.md, already
--   shipped in ConnectionWithAction.vhd). All field-position constants below
--   follow that rule. Widths are all traced from DataTypes.bsv/Headers.bsv/
--   Settings.bsv (CLAUDE.md: never invent widths).
--
-- Deferred-decision carry-forwards applied:
--   * OQ-FSM-CntrlQP-01 : RegType field list/widths taken from the FSM spec,
--                         NOT mapping.json owns.state (stale/abbreviated).
--   * OQ-FSM-CntrlQP-02 : immFail (DESTROY in non-ERR / default) is a sim-only
--                         fatal -> emitted as translate_off asserts; in synth
--                         the request is consumed and the rule's response is
--                         enqueued, no state transition.
--   * OQ-FSM-CntrlQP-03 : ~26 mkRegU/mkCRegU fields have no BSV reset; per the
--                         spec they are written-before-read, initialised to 0
--                         in REG_INIT_C (safe). errFlushDone init '0'.
--   * OQ-FSM-01/06      : BSV FIFOF.clear modelled by pulsing the (sync) Fifo
--                         rst; only restoreQ is cleared (RESET_S scrub, level).
--                         reqQ/respQ are never cleared (BSV clear was disabled).
--
-- Port modelling: ReqQP/RespQP cross the entity boundary as packed slv words
--   (the parent packs/unpacks); restorePort and the ~50 status/getter/setter
--   methods are exploded into explicit ports. All inited-guarded methods share
--   one inited_o ready output (their BSV implicit RDY == inited); setter writes
--   are gated internally by inited so an out-of-state assert is ignored.
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

entity CntrlQp is
   generic (
      TPD_G       : time     := 1 ns;
      MAX_QP_WR_G : positive := 4);     -- Settings.bsv MAX_QP_WR (BSV default 32)
   port (
      -- Clock and synchronous active-high reset
      clk                       : in  sl;
      rst                       : in  sl;

      -- srvPort = toGPServer(reqQ, respQ): request.put (in) / response.get (out)
      srvReqValid               : in  sl;                       -- request.put valid
      srvReqData                : in  slv(300 downto 0);        -- ReqQP packed
      srvReqReady               : out sl;                       -- = reqQ.not_full
      srvRespValid              : out sl;                       -- = respQ.valid
      srvRespData               : out slv(273 downto 0);        -- RespQP packed
      srvRespReady              : in  sl;                       -- response.get rdEn

      -- restorePort = restorePreReqOpCodeAndEPSN(preOpCode, psn) -> restoreQ.enq
      restoreValid              : in  sl;
      restorePreOpCode          : in  slv(4 downto 0);          -- RdmaOpCode
      restoreEpsn               : in  slv(23 downto 0);         -- PSN
      restoreReady              : out sl;                       -- = restoreQ.not_full

      -- Error-state control methods (guarded by inited)
      setStateErr               : in  sl;                       -- setStateErr()
      errFlushDoneIn            : in  sl;                       -- errFlushDone()

      -- Shared ready: every inited-guarded getter/setter is valid when '1'
      inited                    : out sl;

      ----------------------------------------------------------------------------
      -- CntrlCommStatus (comm) status decodes of stateReg (Moore)
      ----------------------------------------------------------------------------
      isCreate                  : out sl;
      isErr                     : out sl;
      isInit                    : out sl;
      isNonErr                  : out sl;
      isReset                   : out sl;
      isRTR                     : out sl;
      isRTS                     : out sl;
      isSQD                     : out sl;
      isUnknown                 : out sl;
      isRTR2RTS                 : out sl;
      isStableRTS               : out sl;

      -- CntrlCommStatus getters (valid when inited, except where noted)
      getAccessFlags            : out slv(7 downto 0);          -- FlagsType#(MemAccessTypeFlag)
      getMaxRnrCnt              : out slv(2 downto 0);          -- RetryCnt
      getMaxRetryCnt            : out slv(2 downto 0);          -- RetryCnt
      getMaxTimeOut             : out slv(4 downto 0);          -- TimeOutTimer
      getMinRnrTimer            : out slv(4 downto 0);          -- RnrTimer
      getPendingWorkReqNum      : out slv(7 downto 0);          -- PendingReqCnt
      getPendingRecvReqNum      : out slv(7 downto 0);
      getPendingReadAtomicReqNum     : out slv(7 downto 0);
      getPendingDestReadAtomicReqNum : out slv(7 downto 0);
      getSigAll                 : out sl;
      getSQPN                   : out slv(23 downto 0);         -- QPN
      getDQPN                   : out slv(23 downto 0);
      getPKEY                   : out slv(15 downto 0);         -- PKEY
      getQKEY                   : out slv(31 downto 0);         -- QKEY
      getPMTU                   : out slv(2 downto 0);          -- PMTU

      -- statusSQ / statusRQ: getTypeQP differs per context (sq vs rq)
      getTypeSq                 : out slv(3 downto 0);          -- TypeQP (statusSQ)
      getTypeRq                 : out slv(3 downto 0);          -- TypeQP (statusRQ)

      ----------------------------------------------------------------------------
      -- ContextSQ
      ----------------------------------------------------------------------------
      getNPSN                   : out slv(23 downto 0);         -- PSN
      setNPSNen                 : in  sl;
      setNPSN                   : in  slv(23 downto 0);

      ----------------------------------------------------------------------------
      -- ContextRQ getters/setters
      ----------------------------------------------------------------------------
      getPermCheckReq           : out slv(266 downto 0);        -- PermCheckReq (opaque)
      setPermCheckReqEn         : in  sl;
      setPermCheckReq           : in  slv(266 downto 0);
      getTotalDmaWriteLen       : out slv(31 downto 0);         -- Length
      setTotalDmaWriteLenEn     : in  sl;
      setTotalDmaWriteLen       : in  slv(31 downto 0);
      getRemainingDmaWriteLen   : out slv(31 downto 0);
      setRemainingDmaWriteLenEn : in  sl;
      setRemainingDmaWriteLen   : in  slv(31 downto 0);
      getNextDmaWriteAddr       : out slv(63 downto 0);         -- ADDR
      setNextDmaWriteAddrEn     : in  sl;
      setNextDmaWriteAddr       : in  slv(63 downto 0);
      getSendWriteReqPktNum     : out slv(24 downto 0);         -- PktNum
      setSendWriteReqPktNumEn   : in  sl;
      setSendWriteReqPktNum     : in  slv(24 downto 0);
      getPreReqOpCode           : out slv(4 downto 0);          -- RdmaOpCode
      setPreReqOpCodeEn         : in  sl;
      setPreReqOpCode           : in  slv(4 downto 0);
      getEpoch                  : out sl;                       -- Epoch (no inited guard)
      incEpochEn                : in  sl;
      getMSN                    : out slv(23 downto 0);         -- MSN
      setMSNen                  : in  sl;
      setMSN                    : in  slv(23 downto 0);
      getIsRespPktNumZero       : out sl;
      getRespPktNum             : out slv(24 downto 0);         -- PktNum
      setRespPktNumEn           : in  sl;
      setRespPktNum             : in  slv(24 downto 0);
      getCurRespPSN             : out slv(23 downto 0);         -- PSN
      setCurRespPSNen           : in  sl;
      setCurRespPSN             : in  slv(23 downto 0);
      getEPSN                   : out slv(23 downto 0);         -- PSN
      setEPSNen                 : in  sl;
      setEPSN                   : in  slv(23 downto 0));
end entity CntrlQp;

architecture rtl of CntrlQp is

   ---------------------------------------------------------------------------
   -- Width constants (traced from BSV types)
   ---------------------------------------------------------------------------
   constant REQ_WIDTH_C  : positive := 301;  -- ReqQP
   constant RESP_WIDTH_C : positive := 274;  -- RespQP
   constant PERM_WIDTH_C : positive := 267;  -- PermCheckReq (opaque scratch)

   ---------------------------------------------------------------------------
   -- StateQP encoding (4 bits, BSV enum declaration order)
   ---------------------------------------------------------------------------
   subtype StateType is slv(3 downto 0);
   constant RESET_S   : StateType := x"0";   -- IBV_QPS_RESET
   constant INIT_S    : StateType := x"1";   -- IBV_QPS_INIT
   constant RTR_S     : StateType := x"2";   -- IBV_QPS_RTR
   constant RTS_S     : StateType := x"3";   -- IBV_QPS_RTS
   constant SQD_S     : StateType := x"4";   -- IBV_QPS_SQD
   constant SQE_S     : StateType := x"5";   -- IBV_QPS_SQE     (dead/decode-only)
   constant ERR_S     : StateType := x"6";   -- IBV_QPS_ERR
   constant UNKNOWN_S : StateType := x"7";   -- IBV_QPS_UNKNOWN
   constant CREATE_S  : StateType := x"8";   -- IBV_QPS_CREATE

   -- QpReqType encoding (2 bits, BSV enum declaration order)
   constant REQ_QP_CREATE_C  : slv(1 downto 0) := "00";
   constant REQ_QP_DESTROY_C : slv(1 downto 0) := "01";
   constant REQ_QP_MODIFY_C  : slv(1 downto 0) := "10";
   constant REQ_QP_QUERY_C   : slv(1 downto 0) := "11";

   -- TypeQP encoding (4 bits, explicit BSV values) -- only XRC values used here
   constant IBV_QPT_XRC_SEND_C : slv(3 downto 0) := x"9";   -- 9
   constant IBV_QPT_XRC_RECV_C : slv(3 downto 0) := x"A";   -- 10

   -- RdmaOpCode SEND_ONLY = 5'h04 (preReqOpCode reset)
   constant SEND_ONLY_C : slv(4 downto 0) := "00100";

   -- MAX_QP_WR (pendingWorkReqNum/pendingRecvReqNum reset)
   constant MAX_QP_WR_C : slv(7 downto 0) := toSlv(MAX_QP_WR_G, 8);

   ---------------------------------------------------------------------------
   -- containFlags(mask, required) == (mask and required) = required
   -- QpAttrMaskFlag is FlagsType#(...) = 26 bits; enum values are bit weights.
   --   IBV_QP_STATE=bit0  ACCESS_FLAGS=bit3  PKEY_INDEX=bit4  PATH_MTU=bit8
   --   TIMEOUT=bit9  RETRY_CNT=bit10  RNR_RETRY=bit11  RQ_PSN=bit12
   --   MAX_QP_RD_ATOMIC=bit13  MIN_RNR_TIMER=bit15  SQ_PSN=bit16
   --   MAX_DEST_RD_ATOMIC=bit17  DEST_QPN=bit20
   ---------------------------------------------------------------------------
   constant MASK_RESET2INIT_C : slv(25 downto 0) := toSlv(25,      26);  -- bits 0,3,4
   constant MASK_INIT2RTR_C   : slv(25 downto 0) := toSlv(1216769, 26);  -- bits 0,8,12,15,17,20
   constant MASK_RTR2RTS_C    : slv(25 downto 0) := toSlv(77313,   26);  -- bits 0,9,10,11,13,16
   constant MASK_ONLYSTATE_C  : slv(25 downto 0) := toSlv(1,       26);  -- bit 0

   ---------------------------------------------------------------------------
   -- ReqQP packed-field absolute ranges (301-bit word, first field at MSB)
   -- qpReqType[300:299] pdHandler[298:267] qpn[266:243] qpAttrMask[242:217]
   -- qpAttr[216:5]      qpInitAttr[4:0]
   -- AttrQP (base offset 5) fields used by the FSM (absolute bit ranges):
   --   qpState[216:213] pmtu[208:206] qkey[205:174] rqPSN[173:150]
   --   sqPSN[149:126] dqpn[125:102] qpAccessFlags[101:94] pkeyIndex[53:38]
   --   maxReadAtomic[36:29] maxDestReadAtomic[28:21] minRnrTimer[20:16]
   --   timeout[15:11] retryCnt[10:8] rnrRetry[7:5]
   -- QpInitAttr (base offset 0): qpType[4:1] sqSigAll[0]
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- RegType : all FSM state + QP attribute latches + ContextRQ scratch.
   -- Per OQ-FSM-CntrlQP-01/02: nextState and setStateErr are CReg intra-cycle
   -- forwarding signals (cleared every cycle by canonicalize) -> modelled as
   -- comb variables, NOT registered fields.
   ---------------------------------------------------------------------------
   type RegType is record
      -- control state
      state          : StateType;
      preState       : StateType;
      errFlushDone   : sl;
      -- QP attribute latches
      sqpn           : slv(23 downto 0);
      dqpn           : slv(23 downto 0);
      sqType         : slv(3 downto 0);
      rqType         : slv(3 downto 0);
      sqSigAll       : sl;
      qpAccessFlags  : slv(7 downto 0);
      pkey           : slv(15 downto 0);
      qkey           : slv(31 downto 0);
      pmtu           : slv(2 downto 0);
      epsn           : slv(23 downto 0);   -- epsnReg (CReg: port0 onINIT/setEPSN, port1 restore)
      npsn           : slv(23 downto 0);
      maxTimeOut     : slv(4 downto 0);
      maxRetryCnt    : slv(2 downto 0);
      maxRnrCnt      : slv(2 downto 0);
      minRnrTimer    : slv(4 downto 0);
      pendingReadAtomicReqNum     : slv(7 downto 0);
      pendingDestReadAtomicReqNum : slv(7 downto 0);
      pendingWorkReqNum : slv(7 downto 0);
      pendingRecvReqNum : slv(7 downto 0);
      preReqOpCode   : slv(4 downto 0);    -- CReg: port0 scrub/set, port1 restore
      epoch          : sl;
      msn            : slv(23 downto 0);
      -- ContextRQ scratch (method-only)
      permCheckReq        : slv(266 downto 0);
      totalDmaWriteLen    : slv(31 downto 0);
      remainingDmaWriteLen: slv(31 downto 0);
      nextDmaWriteAddr    : slv(63 downto 0);
      sendWriteReqPktNum  : slv(24 downto 0);
      respPktNum          : slv(24 downto 0);
      isRespPktNumZero    : sl;
      curRespPsn          : slv(23 downto 0);
   end record RegType;

   -- mkRegU/mkCRegU fields initialised to 0 per OQ-FSM-CntrlQP-03 (safe: all
   -- written-before-read). Reset values from BSV mkReg(...) where present.
   constant REG_INIT_C : RegType := (
      state          => RESET_S,         -- mkReg(IBV_QPS_RESET)
      preState       => UNKNOWN_S,       -- mkReg(IBV_QPS_UNKNOWN)
      errFlushDone   => '0',             -- mkRegU
      sqpn           => (others => '0'),
      dqpn           => (others => '0'),
      sqType         => (others => '0'),
      rqType         => (others => '0'),
      sqSigAll       => '0',
      qpAccessFlags  => (others => '0'),
      pkey           => (others => '0'),
      qkey           => (others => '0'),
      pmtu           => (others => '0'),
      epsn           => (others => '0'),
      npsn           => (others => '0'),
      maxTimeOut     => (others => '0'),
      maxRetryCnt    => (others => '0'),
      maxRnrCnt      => (others => '0'),
      minRnrTimer    => (others => '0'),
      pendingReadAtomicReqNum     => (others => '0'),
      pendingDestReadAtomicReqNum => (others => '0'),
      pendingWorkReqNum => MAX_QP_WR_C,  -- mkReg(MAX_QP_WR)
      pendingRecvReqNum => MAX_QP_WR_C,  -- mkReg(MAX_QP_WR)
      preReqOpCode   => SEND_ONLY_C,     -- mkCReg(2, SEND_ONLY)
      epoch          => '0',             -- mkReg(0)
      msn            => (others => '0'), -- mkReg(0)
      permCheckReq        => (others => '0'),
      totalDmaWriteLen    => (others => '0'),
      remainingDmaWriteLen=> (others => '0'),
      nextDmaWriteAddr    => (others => '0'),
      sendWriteReqPktNum  => (others => '0'),
      respPktNum          => (others => '0'),
      isRespPktNumZero    => '0',
      curRespPsn          => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- inited (combinational decode of r.state), used as method RDY and guard
   signal initedInt : sl;

   -- U_ReqQ
   signal reqQNotFull : sl;
   signal reqQValid   : sl;
   signal reqQDout    : slv(300 downto 0);
   signal reqQRdEn    : sl;
   -- U_RespQ
   signal respQNotFull : sl;
   signal respQValid   : sl;
   signal respQDin     : slv(273 downto 0);
   signal respQWrEn    : sl;
   -- U_RestoreQ
   signal restoreQNotFull : sl;
   signal restoreQValid   : sl;
   signal restoreQDout    : slv(28 downto 0);
   signal restoreQRdEn    : sl;
   signal restoreQRst     : sl;   -- global rst OR RESET_S clear (level)

   signal rstActiveHigh : sl;

begin

   ---------------------------------------------------------------------------
   -- inited = (state /= RESET) and (state /= UNKNOWN)
   ---------------------------------------------------------------------------
   initedInt     <= '1' when (r.state /= RESET_S and r.state /= UNKNOWN_S) else '0';
   rstActiveHigh <= rst;   -- RST_POLARITY_G = '1' (active-high)

   -- restoreQ.clear (resetAndClear, fire_when_enabled while state=RESET) is
   -- modelled as a level rst pulse (OQ-FSM-01/06). reqQ/respQ never cleared.
   restoreQRst <= rstActiveHigh or ite(r.state = RESET_S, '1', '0');

   ---------------------------------------------------------------------------
   -- U_ReqQ : reqQ (ReqQP, 301 bits). FWFT so valid/dout == BSV !empty/first.
   ---------------------------------------------------------------------------
   U_ReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         SYNTH_MODE_G    => "inferred",
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => REQ_WIDTH_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => rstActiveHigh,
         wr_clk   => clk,
         wr_en    => srvReqValid,        -- parent gates externally on srvReqReady
         din      => srvReqData,
         not_full => reqQNotFull,
         rd_clk   => clk,
         rd_en    => reqQRdEn,
         dout     => reqQDout,
         valid    => reqQValid);

   ---------------------------------------------------------------------------
   -- U_RespQ : respQ (RespQP, 274 bits)
   ---------------------------------------------------------------------------
   U_RespQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         SYNTH_MODE_G    => "inferred",
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => RESP_WIDTH_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => rstActiveHigh,
         wr_clk   => clk,
         wr_en    => respQWrEn,
         din      => respQDin,
         not_full => respQNotFull,
         rd_clk   => clk,
         rd_en    => srvRespReady,       -- parent gates externally on srvRespValid
         dout     => srvRespData,
         valid    => respQValid);

   ---------------------------------------------------------------------------
   -- U_RestoreQ : restoreQ (Tuple2#(RdmaOpCode,PSN) = 29 bits)
   --   din = preOpCode(5) & psn(24); dout(28:24)=preOpCode, dout(23:0)=psn.
   --   rst carries the RESET_S clear pulse (OQ-FSM-01).
   ---------------------------------------------------------------------------
   U_RestoreQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         SYNTH_MODE_G    => "inferred",
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 29,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => restoreQRst,
         wr_clk   => clk,
         wr_en    => restoreValid,       -- parent gates externally on restoreReady
         din      => restorePreOpCode & restoreEpsn,
         not_full => restoreQNotFull,
         rd_clk   => clk,
         rd_en    => restoreQRdEn,
         dout     => restoreQDout,
         valid    => restoreQValid);

   ---------------------------------------------------------------------------
   -- Combinatorial process: all on*/canonicalize/restore/updatePreState/
   -- resetAndClear logic + method writes. One atomic BSV rule = one v-block.
   ---------------------------------------------------------------------------
   comb : process (r, rst, initedInt,
                   reqQValid, reqQDout, reqQNotFull,
                   respQNotFull, respQValid,
                   restoreQValid, restoreQDout, restoreQNotFull,
                   srvReqValid, srvRespReady,
                   setStateErr, errFlushDoneIn,
                   setNPSNen, setNPSN, setPermCheckReqEn, setPermCheckReq,
                   setTotalDmaWriteLenEn, setTotalDmaWriteLen,
                   setRemainingDmaWriteLenEn, setRemainingDmaWriteLen,
                   setNextDmaWriteAddrEn, setNextDmaWriteAddr,
                   setSendWriteReqPktNumEn, setSendWriteReqPktNum,
                   setPreReqOpCodeEn, setPreReqOpCode, incEpochEn,
                   setMSNen, setMSN, setRespPktNumEn, setRespPktNum,
                   setCurRespPSNen, setCurRespPSN, setEPSNen, setEPSN) is
      variable v             : RegType;
      variable nextStateVld  : sl;
      variable nextStateData : StateType;
      variable setStateErrV  : sl;
      variable fireV         : sl;
      variable successV      : sl;
      variable reqType       : slv(1 downto 0);
      variable reqQpState    : StateType;
      variable reqQpType     : slv(3 downto 0);
      variable reqMask       : slv(25 downto 0);
      variable vResp         : slv(273 downto 0);
   begin
      v := r;

      -- CReg intra-cycle forwarding signals (default: no proposal / no error)
      nextStateVld  := '0';
      nextStateData := r.state;
      setStateErrV  := '0';

      -- FIFO drive defaults
      reqQRdEn     <= '0';
      respQWrEn    <= '0';
      restoreQRdEn <= '0';

      -- No rule fires in states without an active on* rule (SQE/UNKNOWN)
      fireV := '0';

      -- Request field views (ReqQP packed)
      reqType    := reqQDout(300 downto 299);
      reqQpState := reqQDout(216 downto 213);   -- qpAttr.qpState (target state)
      reqQpType  := reqQDout(4 downto 1);        -- qpInitAttr.qpType
      reqMask    := reqQDout(242 downto 217);   -- qpAttrMask

      -- Response default = echo request (qpn / pdHandler / qpAttr / qpInitAttr)
      vResp                  := (others => '0');
      vResp(272 downto 249)  := reqQDout(266 downto 243);   -- qpn
      vResp(248 downto 217)  := reqQDout(298 downto 267);   -- pdHandler
      vResp(216 downto 5)    := reqQDout(216 downto 5);     -- qpAttr (echo)
      vResp(4 downto 0)      := reqQDout(4 downto 0);        -- qpInitAttr
      successV               := '1';

      ------------------------------------------------------------------------
      -- ContextSQ/ContextRQ setter methods (CReg/Reg port0 writes), gated by
      -- inited (BSV implicit RDY). Applied before the state case so that the
      -- on* rule latches and restore (port1) take precedence in their states.
      ------------------------------------------------------------------------
      if (initedInt = '1') then
         if (setNPSNen = '1')                 then v.npsn                 := setNPSN; end if;
         if (setPermCheckReqEn = '1')         then v.permCheckReq         := setPermCheckReq; end if;
         if (setTotalDmaWriteLenEn = '1')     then v.totalDmaWriteLen     := setTotalDmaWriteLen; end if;
         if (setRemainingDmaWriteLenEn = '1') then v.remainingDmaWriteLen := setRemainingDmaWriteLen; end if;
         if (setNextDmaWriteAddrEn = '1')     then v.nextDmaWriteAddr     := setNextDmaWriteAddr; end if;
         if (setSendWriteReqPktNumEn = '1')   then v.sendWriteReqPktNum   := setSendWriteReqPktNum; end if;
         if (setPreReqOpCodeEn = '1')         then v.preReqOpCode         := setPreReqOpCode; end if;  -- port0
         if (incEpochEn = '1')                then v.epoch                := not r.epoch; end if;
         if (setMSNen = '1')                  then v.msn                  := setMSN; end if;
         if (setCurRespPSNen = '1')           then v.curRespPsn           := setCurRespPSN; end if;
         if (setEPSNen = '1')                 then v.epsn                 := setEPSN; end if;          -- port0
         if (setRespPktNumEn = '1') then
            v.respPktNum       := setRespPktNum;
            v.isRespPktNumZero := ite(unsigned(setRespPktNum) = 0, '1', '0');
         end if;
      end if;

      ------------------------------------------------------------------------
      -- setStateErr() / errFlushDone() methods (both guarded by inited).
      -- They share errFlushDoneReg, so they cannot both apply same cycle:
      -- setStateErr takes priority (it forces the error transition).
      ------------------------------------------------------------------------
      if (initedInt = '1' and setStateErr = '1') then
         setStateErrV   := '1';     -- setStateErrReg[0] <= True (consumed by canonicalize)
         v.errFlushDone := '0';     -- errFlushDoneReg <= False
      elsif (initedInt = '1' and errFlushDoneIn = '1'
             and r.state = ERR_S and r.errFlushDone = '0') then
         v.errFlushDone := '1';
      end if;

      ------------------------------------------------------------------------
      -- rule updatePreState (fire_when_enabled, unconditional)
      ------------------------------------------------------------------------
      v.preState := r.state;

      ------------------------------------------------------------------------
      -- on* rules (mutually exclusive by state) + resetAndClear scrub.
      -- A rule fires iff reqQ has data and respQ can accept (implicit conds);
      -- onERR additionally requires errFlushDone.  fireV => deq req + enq resp.
      ------------------------------------------------------------------------
      case r.state is
         ----------------------------------------------------------------------
         when RESET_S =>
            -- rule resetAndClear (every cycle in RESET): re-apply defaults +
            -- pulse restoreQ clear (restoreQRst level, driven concurrently).
            v.pendingWorkReqNum := MAX_QP_WR_C;
            v.pendingRecvReqNum := MAX_QP_WR_C;
            v.preReqOpCode      := SEND_ONLY_C;
            v.epoch             := '0';
            v.msn               := (others => '0');

            -- rule onReset
            fireV    := reqQValid and respQNotFull;
            successV := ite(reqType = REQ_QP_CREATE_C, '1', '0');
            if (fireV = '1') then
               v.sqpn     := reqQDout(266 downto 243);   -- qpn
               v.sqType   := ite(reqQpType = IBV_QPT_XRC_RECV_C, IBV_QPT_XRC_SEND_C, reqQpType);
               v.rqType   := ite(reqQpType = IBV_QPT_XRC_SEND_C, IBV_QPT_XRC_RECV_C, reqQpType);
               v.sqSigAll := reqQDout(0);                -- qpInitAttr.sqSigAll
               if (successV = '1') then
                  nextStateVld  := '1';
                  nextStateData := CREATE_S;             -- tagged Valid IBV_QPS_CREATE
               end if;
               vResp(273) := successV;
            end if;

         ----------------------------------------------------------------------
         when CREATE_S =>
            fireV := reqQValid and respQNotFull;
            if (fireV = '1') then
               case reqType is
                  when REQ_QP_MODIFY_C =>
                     successV := ite((reqQpState = INIT_S) and
                                     ((reqMask and MASK_RESET2INIT_C) = MASK_RESET2INIT_C),
                                     '1', '0');
                     if (successV = '1') then
                        nextStateVld  := '1';
                        nextStateData := reqQpState;
                     end if;
                     v.qpAccessFlags := reqQDout(101 downto 94);  -- always (success or not)
                     v.pkey          := reqQDout(53 downto 38);
                  when REQ_QP_QUERY_C =>
                     vResp(212 downto 209) := r.state;            -- curQpState
                  when others =>                                  -- DESTROY / default: immFail (sim-only)
                     null;
               end case;
               vResp(273) := successV;
            end if;

         ----------------------------------------------------------------------
         when INIT_S =>
            fireV := reqQValid and respQNotFull;
            if (fireV = '1') then
               case reqType is
                  when REQ_QP_MODIFY_C =>
                     successV := ite((reqQpState = RTR_S) and
                                     ((reqMask and MASK_INIT2RTR_C) = MASK_INIT2RTR_C),
                                     '1', '0');
                     if (successV = '1') then
                        nextStateVld  := '1';
                        nextStateData := reqQpState;
                     end if;
                     v.pmtu                        := reqQDout(208 downto 206);
                     v.dqpn                        := reqQDout(125 downto 102);
                     v.epsn                        := reqQDout(173 downto 150);  -- epsn[0] <= rqPSN
                     v.pendingDestReadAtomicReqNum := reqQDout(28 downto 21);
                     v.minRnrTimer                 := reqQDout(20 downto 16);
                  when REQ_QP_QUERY_C =>
                     vResp(212 downto 209) := r.state;             -- curQpState
                     vResp(101 downto 94)  := r.qpAccessFlags;
                     vResp(53 downto 38)   := r.pkey;              -- pkeyIndex
                  when others =>
                     null;
               end case;
               vResp(273) := successV;
            end if;

         ----------------------------------------------------------------------
         when RTR_S =>
            fireV := reqQValid and respQNotFull;
            if (fireV = '1') then
               case reqType is
                  when REQ_QP_MODIFY_C =>
                     successV := ite(
                        ((reqQpState = ERR_S) and ((reqMask and MASK_ONLYSTATE_C) = MASK_ONLYSTATE_C)) or
                        ((reqQpState = RTS_S) and ((reqMask and MASK_RTR2RTS_C)   = MASK_RTR2RTS_C)),
                        '1', '0');
                     if (successV = '1') then
                        nextStateVld  := '1';
                        nextStateData := reqQpState;
                     end if;
                     v.npsn                    := reqQDout(149 downto 126);  -- sqPSN
                     v.maxTimeOut              := reqQDout(15 downto 11);    -- timeout
                     v.maxRetryCnt             := reqQDout(10 downto 8);     -- retryCnt
                     v.maxRnrCnt               := reqQDout(7 downto 5);      -- rnrRetry
                     v.pendingReadAtomicReqNum := reqQDout(36 downto 29);    -- maxReadAtomic
                  when REQ_QP_QUERY_C =>
                     vResp(212 downto 209) := r.state;
                     vResp(101 downto 94)  := r.qpAccessFlags;
                     vResp(53 downto 38)   := r.pkey;
                  when others =>
                     null;
               end case;
               vResp(273) := successV;
            end if;

         ----------------------------------------------------------------------
         when RTS_S =>
            fireV := reqQValid and respQNotFull;
            if (fireV = '1') then
               case reqType is
                  when REQ_QP_MODIFY_C =>
                     successV := ite(
                        ((reqQpState = SQD_S) or (reqQpState = ERR_S)) and
                        ((reqMask and MASK_ONLYSTATE_C) = MASK_ONLYSTATE_C),
                        '1', '0');
                     if (successV = '1') then
                        nextStateVld  := '1';
                        nextStateData := reqQpState;
                     end if;
                  when REQ_QP_QUERY_C =>
                     vResp(212 downto 209) := r.state;             -- curQpState
                     vResp(101 downto 94)  := r.qpAccessFlags;
                     vResp(53 downto 38)   := r.pkey;
                     vResp(149 downto 126) := r.npsn;              -- sqPSN
                     vResp(15 downto 11)   := r.maxTimeOut;        -- timeout
                     vResp(10 downto 8)    := r.maxRetryCnt;       -- retryCnt
                     vResp(7 downto 5)     := r.maxRnrCnt;         -- rnrRetry
                     vResp(36 downto 29)   := r.pendingReadAtomicReqNum;  -- maxReadAtomic
                  when others =>
                     null;
               end case;
               vResp(273) := successV;
            end if;

         ----------------------------------------------------------------------
         when SQD_S =>
            fireV := reqQValid and respQNotFull;
            if (fireV = '1') then
               case reqType is
                  when REQ_QP_MODIFY_C =>
                     successV := ite(
                        ((reqQpState = ERR_S) or (reqQpState = RTS_S)) and
                        ((reqMask and MASK_ONLYSTATE_C) = MASK_ONLYSTATE_C),
                        '1', '0');
                     if (successV = '1') then
                        nextStateVld  := '1';
                        nextStateData := reqQpState;
                     end if;
                  when REQ_QP_QUERY_C =>
                     vResp(212 downto 209) := r.state;
                     vResp(101 downto 94)  := r.qpAccessFlags;
                     vResp(53 downto 38)   := r.pkey;
                     vResp(149 downto 126) := r.npsn;
                     vResp(15 downto 11)   := r.maxTimeOut;
                     vResp(10 downto 8)    := r.maxRetryCnt;
                     vResp(7 downto 5)     := r.maxRnrCnt;
                     vResp(36 downto 29)   := r.pendingReadAtomicReqNum;
                  when others =>
                     null;
               end case;
               vResp(273) := successV;
            end if;

         ----------------------------------------------------------------------
         when ERR_S =>
            -- onERR also requires errFlushDone
            fireV := reqQValid and respQNotFull and r.errFlushDone;
            if (fireV = '1') then
               case reqType is
                  when REQ_QP_DESTROY_C =>
                     nextStateVld  := '1';
                     nextStateData := RESET_S;            -- DESTROY legal only from ERR
                  when REQ_QP_MODIFY_C =>
                     successV := ite((reqQpState = RESET_S) and
                                     ((reqMask and MASK_ONLYSTATE_C) = MASK_ONLYSTATE_C),
                                     '1', '0');
                     if (successV = '1') then
                        nextStateVld  := '1';
                        nextStateData := reqQpState;      -- RESET
                     end if;
                  when REQ_QP_QUERY_C =>
                     vResp(212 downto 209) := r.state;    -- curQpState
                  when others =>
                     null;
               end case;
               vResp(273) := successV;
            end if;

         when others =>                                  -- SQE/UNKNOWN: no active rule
            null;
      end case;

      -- Drive FIFO enables from the firing rule
      reqQRdEn  <= fireV;
      respQWrEn <= fireV;
      respQDin  <= vResp;

      ------------------------------------------------------------------------
      -- rule restore (RTR/RTS/SQD, when restoreQ has data) — independent of
      -- reqQ. Writes preReqOpCode[1]/epsn[1] (port1) -> OVERRIDES same-cycle
      -- port0 (setPreReqOpCode/setEPSN) writes applied above.
      ------------------------------------------------------------------------
      if ((r.state = RTR_S or r.state = RTS_S or r.state = SQD_S)
          and restoreQValid = '1') then
         restoreQRdEn   <= '1';
         v.preReqOpCode := restoreQDout(28 downto 24);   -- preOpCode
         v.epsn         := restoreQDout(23 downto 0);    -- psn
      end if;

      ------------------------------------------------------------------------
      -- rule canonicalize (fire_when_enabled): single state commit.
      -- priority: setStateErr (force ERR) > nextState proposal > hold.
      ------------------------------------------------------------------------
      if (nextStateVld = '1') then
         v.state := nextStateData;
      end if;
      if (setStateErrV = '1') then
         v.state := ERR_S;
      end if;

      ------------------------------------------------------------------------
      -- Synchronous reset
      ------------------------------------------------------------------------
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      ------------------------------------------------------------------------
      -- Outputs
      ------------------------------------------------------------------------
      srvReqReady  <= reqQNotFull;
      srvRespValid <= respQValid;
      restoreReady <= restoreQNotFull;
      inited       <= initedInt;

      -- CntrlCommStatus decodes (Moore, from r.state / r.preState)
      isCreate    <= ite(r.state = CREATE_S, '1', '0');
      isErr       <= ite(r.state = ERR_S, '1', '0');
      isInit      <= ite(r.state = INIT_S, '1', '0');
      isNonErr    <= ite(r.state = RTR_S or r.state = RTS_S or r.state = SQD_S, '1', '0');
      isReset     <= ite(r.state = RESET_S, '1', '0');
      isRTR       <= ite(r.state = RTR_S, '1', '0');
      isRTS       <= ite(r.state = RTS_S, '1', '0');
      isSQD       <= ite(r.state = SQD_S, '1', '0');
      isUnknown   <= ite(r.state = UNKNOWN_S, '1', '0');
      isRTR2RTS   <= ite(r.preState = RTR_S and r.state = RTS_S, '1', '0');
      isStableRTS <= ite(r.preState = RTS_S and r.state = RTS_S, '1', '0');

      -- Attribute getters (Moore)
      getAccessFlags                 <= r.qpAccessFlags;
      getMaxRnrCnt                   <= r.maxRnrCnt;
      getMaxRetryCnt                 <= r.maxRetryCnt;
      getMaxTimeOut                  <= r.maxTimeOut;
      getMinRnrTimer                 <= r.minRnrTimer;
      getPendingWorkReqNum           <= r.pendingWorkReqNum;
      getPendingRecvReqNum           <= r.pendingRecvReqNum;
      getPendingReadAtomicReqNum     <= r.pendingReadAtomicReqNum;
      getPendingDestReadAtomicReqNum <= r.pendingDestReadAtomicReqNum;
      getSigAll                      <= r.sqSigAll;
      getSQPN                        <= r.sqpn;
      getDQPN                        <= r.dqpn;
      getPKEY                        <= r.pkey;
      getQKEY                        <= r.qkey;
      getPMTU                        <= r.pmtu;
      getTypeSq                      <= r.sqType;
      getTypeRq                      <= r.rqType;

      -- ContextSQ / ContextRQ getters (Moore)
      getNPSN                 <= r.npsn;
      getPermCheckReq         <= r.permCheckReq;
      getTotalDmaWriteLen     <= r.totalDmaWriteLen;
      getRemainingDmaWriteLen <= r.remainingDmaWriteLen;
      getNextDmaWriteAddr     <= r.nextDmaWriteAddr;
      getSendWriteReqPktNum   <= r.sendWriteReqPktNum;
      getPreReqOpCode         <= r.preReqOpCode;       -- preReqOpCodeReg[0]
      getEpoch                <= r.epoch;
      getMSN                  <= r.msn;
      getIsRespPktNumZero     <= r.isRespPktNumZero;
      getRespPktNum           <= r.respPktNum;
      getCurRespPSN           <= r.curRespPsn;
      getEPSN                 <= r.epsn;                -- epsnReg[0]

   end process comb;

   ---------------------------------------------------------------------------
   -- Sequential process: r <= rin on rising edge.
   ---------------------------------------------------------------------------
   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin;
      end if;
   end process seq;

   ---------------------------------------------------------------------------
   -- Simulation-only invariant checks (OQ-FSM-CntrlQP-02): immFail asserts.
   -- DESTROY is legal only from ERR_S; any other reqType decodes to default.
   ---------------------------------------------------------------------------
   -- pragma translate_off
   check : process (clk) is
   begin
      if rising_edge(clk) then
         if (rst = '0' and reqQValid = '1' and respQNotFull = '1') then
            if ((r.state = CREATE_S or r.state = INIT_S or r.state = RTR_S or
                 r.state = RTS_S or r.state = SQD_S)
                and reqQDout(300 downto 299) = REQ_QP_DESTROY_C) then
               assert false
                  report "CntrlQp: REQ_QP_DESTROY illegal outside ERR_S (immFail @ mkCntrlQP)"
                  severity failure;
            end if;
         end if;
         if (rst = '0' and setStateErr = '1' and initedInt = '1') then
            assert (r.state /= UNKNOWN_S and r.state /= RESET_S)
               report "CntrlQp: setStateErr while state is UNKNOWN/RESET (immAssert @ canonicalize)"
               severity failure;
         end if;
      end if;
   end process check;
   -- pragma translate_on

end architecture rtl;
