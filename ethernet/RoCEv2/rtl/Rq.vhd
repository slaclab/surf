-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Structural / wiring container — NOT a two-process FSM. mkRQ owns no
--   registered state and no datapath logic (RegType/comb/seq intentionally
--   absent, per Rq.fsm.md and OQ-FSM-RQTOP-01). It:
--     * instantiates four child entities:
--         U_DupReadAtomicCache, U_PayloadConsumer, U_ReqHandleRq, U_WorkCompGenRq
--     * wires them to each other and to this entity's module-argument ports
--       (contextRQ / payloadGenerator / dmaWriteCntrl / permCheckSrv /
--        recvReqBuf / reqPktPipeIn are BSV module arguments -> external
--        interface ports here, NOT sub-entities; same pattern as OQ-FSM-SQ-02)
--     * forwards three interface members outward
--         (rdmaRespDataStreamPipeOut, workCompRQ, respHeaderOutNotEmpty)
--     * carries the single reset-driven clear pulse
--         resetAndClear (BSV 304-309): isReset -> U_DupReadAtomicCache.clear
--
--   NOTE (mapping.json is stale for this entity — use Rq.fsm.md):
--     mapping.json lists {ReqHandleRq, PayloadConsumerConAndGen,
--     DupReadAtomicCache, AtomicSrvConAndGen} with rules=[]. Source shows NO
--     AtomicSrv instance and DOES instantiate WorkCompGenRq, plus the one
--     resetAndClear rule. Correct child set is
--     {DupReadAtomicCache, PayloadConsumerConAndGen, ReqHandleRq, WorkCompGenRq}.
--     (OQ-FSM-RQTOP-01, RESOLVED — use the fsm.md.)
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

entity Rq is
   generic (
      TPD_G     : time    := 1 ns;
      -- false = no RDMA READ/atomic serving: U_DupReadAtomicCache is not
      -- generated (its client faces are tied inert) and ReqHandleRq NAKs
      -- incoming READ/atomic requests as unsupported (INV_REQ).
      EN_READ_G : boolean := true;
      -- Settings.bsv MAX_QP_WR (BSV default 32); pass-through to ReqHandleRq
      MAX_QP_WR_G : positive := 4);
   port (
      clk : in sl;
      rst : in sl;                                        -- active-high synchronous reset
      -----------------------------------------------------------------------
      -- contextRQ.statusRQ.comm status methods (shared, fanned to children)
      -----------------------------------------------------------------------
      isReset                        : in  sl;            -- comm.isReset  (guards resetAndClear)
      isNonErr                       : in  sl;            -- comm.isNonErr
      isERR                          : in  sl;            -- comm.isERR
      getTypeQP                      : in  slv(3 downto 0);   -- TypeQP enum
      getPMTU                        : in  slv(2 downto 0);   -- PMTU enum (also -> DupReadAtomicCache.pmtu)
      getPKEY                        : in  slv(15 downto 0);
      getSQPN                        : in  slv(23 downto 0);
      getDQPN                        : in  slv(23 downto 0);
      getMinRnrTimer                 : in  slv(4 downto 0);
      getAccessFlags                 : in  slv(7 downto 0);
      getPendingWorkReqNum           : in  slv(7 downto 0);
      getPendingDestReadAtomicReqNum : in  slv(7 downto 0);
      -----------------------------------------------------------------------
      -- contextRQ shared registers (external RMW; -> U_ReqHandleRq only)
      -----------------------------------------------------------------------
      getEpoch           : in  sl;
      incEpoch           : out sl;
      getEPSN            : in  slv(23 downto 0);
      getRespPktNum      : in  slv(24 downto 0);
      setRespPktNumValid : out sl;
      setRespPktNumData  : out slv(24 downto 0);
      getIsRespPktNumZero : in sl;
      setEPSNValid       : out sl;
      setEPSNData        : out slv(23 downto 0);
      getPreReqOpCode      : in  slv(4 downto 0);
      setPreReqOpCodeValid : out sl;
      setPreReqOpCodeData  : out slv(4 downto 0);
      restoreValid         : out sl;
      restorePreOpCodeData : out slv(4 downto 0);
      restorePsnData       : out slv(23 downto 0);
      getPermCheckReq      : in  slv(266 downto 0);
      setPermCheckReqValid : out sl;
      setPermCheckReqData  : out slv(266 downto 0);
      getNextDmaWriteAddr        : in  slv(63 downto 0);
      setNextDmaWriteAddrValid   : out sl;
      setNextDmaWriteAddrData    : out slv(63 downto 0);
      getSendWriteReqPktNum      : in  slv(24 downto 0);
      setSendWriteReqPktNumValid : out sl;
      setSendWriteReqPktNumData  : out slv(24 downto 0);
      getRemainingDmaWriteLen      : in  slv(31 downto 0);
      setRemainingDmaWriteLenValid : out sl;
      setRemainingDmaWriteLenData  : out slv(31 downto 0);
      getTotalDmaWriteLen        : in  slv(31 downto 0);
      setTotalDmaWriteLenValid   : out sl;
      setTotalDmaWriteLenData    : out slv(31 downto 0);
      getCurRespPSN        : in  slv(23 downto 0);
      setCurRespPSNValid   : out sl;
      setCurRespPSNData    : out slv(23 downto 0);
      getMSN               : in  slv(23 downto 0);
      setMSNValid          : out sl;
      setMSNData           : out slv(23 downto 0);
      -----------------------------------------------------------------------
      -- payloadGenerator : Server + DataStream (module arg -> U_ReqHandleRq)
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
      -- permCheckSrv : Server#(PermCheckReq (267b), Bool) (module arg -> U_ReqHandleRq)
      -----------------------------------------------------------------------
      permReqValid  : out sl;
      permReqData   : out slv(266 downto 0);
      permReqReady  : in  sl;
      permRespValid : in  sl;
      permRespData  : in  sl;
      permRespGetEn : out sl;
      -----------------------------------------------------------------------
      -- recvReqBuf : RecvReqBuf (RecvReq 216b) (module arg -> U_ReqHandleRq)
      -----------------------------------------------------------------------
      recvReqValid : in  sl;
      recvReqData  : in  slv(215 downto 0);
      recvReqDeq   : out sl;
      -----------------------------------------------------------------------
      -- reqPktPipeIn.pktMetaData : PipeOut#(RdmaPktMetaData) (649b) (-> U_ReqHandleRq)
      -----------------------------------------------------------------------
      pktMetaValid : in  sl;
      pktMetaData  : in  slv(648 downto 0);
      pktMetaDeq   : out sl;
      -----------------------------------------------------------------------
      -- reqPktPipeIn.payload : DataStreamPipeOut (290b) (-> U_PayloadConsumer)
      -----------------------------------------------------------------------
      payloadPipeInValid : in  sl;
      payloadPipeInData  : in  slv(289 downto 0);
      payloadPipeInReady : out sl;
      -----------------------------------------------------------------------
      -- dmaWriteCntrl : DmaWriteSrv (module arg -> U_PayloadConsumer, CLIENT)
      -----------------------------------------------------------------------
      dmaWriteReqValid  : out sl;
      dmaWriteReqData   : out slv(418 downto 0);
      dmaWriteReqReady  : in  sl;
      dmaWriteRespValid : in  sl;
      dmaWriteRespData  : in  slv(52 downto 0);
      dmaWriteRespReady : out sl;
      -----------------------------------------------------------------------
      -- Forwarded outputs (interface members of RQ)
      -----------------------------------------------------------------------
      -- rdmaRespDataStreamPipeOut = U_ReqHandleRq.rdmaRespDataStreamPipeOut (290b)
      rdmaRespDataStreamValid : out sl;
      rdmaRespDataStreamData  : out slv(289 downto 0);
      rdmaRespDataStreamRdEn  : in  sl;
      -- respHeaderOutNotEmpty() = U_ReqHandleRq.respHeaderOutNotEmpty (Bool method)
      respHeaderOutNotEmpty : out sl;
      -- workCompRQ = U_WorkCompGenRq (WorkCompGen interface: WorkComp 222b + hasErr)
      workCompValid  : out sl;
      workCompData   : out slv(221 downto 0);
      workCompRdEn   : in  sl;
      workCompHasErr : out sl);
end entity Rq;

architecture rtl of Rq is

   -- No RegType / REG_INIT_C / comb / seq: mkRQ is a pure structural container
   -- (Rq.fsm.md: "no registered state, no datapath logic"). Below are only the
   -- internal child-to-child interconnect signals and one clear-merge.

   ------------------------------------------------------------------------------
   -- U_ReqHandleRq.payloadConReqPort <-> U_PayloadConsumer.request (PayloadConReq 203b)
   ------------------------------------------------------------------------------
   signal payloadConReqValid : sl;
   signal payloadConReqData  : slv(202 downto 0);
   signal payloadConReqReady : sl;

   ------------------------------------------------------------------------------
   -- U_PayloadConsumer.response <-> U_WorkCompGenRq.payloadConRespPort (PayloadConResp 53b)
   ------------------------------------------------------------------------------
   signal payloadConRespValid : sl;
   signal payloadConRespData  : slv(52 downto 0);
   signal payloadConRespGetEn : sl;

   ------------------------------------------------------------------------------
   -- U_ReqHandleRq.workCompGenReqPipeOut <-> U_WorkCompGenRq.wcGenReqPipeInFromRQ (198b)
   ------------------------------------------------------------------------------
   signal workCompGenReqValid : sl;
   signal workCompGenReqData  : slv(197 downto 0);
   signal workCompGenReqDeq   : sl;

   ------------------------------------------------------------------------------
   -- U_ReqHandleRq <-> U_DupReadAtomicCache (dupReadAtomicCache methods)
   ------------------------------------------------------------------------------
   signal insertReadValid      : sl;
   signal insertReadData       : slv(175 downto 0);
   signal insertReadReady      : sl;
   signal searchReadReqValid   : sl;
   signal searchReadReqData    : slv(175 downto 0);
   signal searchReadReqReady   : sl;
   signal searchReadRespValid  : sl;
   signal searchReadRespData   : slv(241 downto 0);
   signal searchReadRespGetEn  : sl;
   signal insertAtomicValid    : sl;
   signal insertAtomicData     : slv(316 downto 0);
   signal insertAtomicReady    : sl;
   signal searchAtomicReqValid : sl;
   signal searchAtomicReqData  : slv(316 downto 0);
   signal searchAtomicReqReady : sl;
   signal searchAtomicRespValid : sl;
   signal searchAtomicRespData  : slv(317 downto 0);
   signal searchAtomicRespGetEn : sl;

   -- clear() has two BSV callers that both reduce to isReset:
   --   * mkRQ.resetAndClear rule (isReset)                       [Rq.fsm.md]
   --   * U_ReqHandleRq.dupCacheClear output (= isReset internally)
   -- The faithful merge of multiple Action-method callers is an OR.
   signal dupCacheClear    : sl;   -- from U_ReqHandleRq
   signal dupCacheClearAll : sl;   -- isReset OR dupCacheClear -> U_DupReadAtomicCache.clearEn

begin

   ------------------------------------------------------------------------------
   -- resetAndClear (BSV 304-309): isReset -> DupReadAtomicCache.clear.
   -- Level-driven combinational pulse (no_implicit_conditions, fire_when_enabled).
   ------------------------------------------------------------------------------
   dupCacheClearAll <= isReset or dupCacheClear;

   ------------------------------------------------------------------------------
   -- U_DupReadAtomicCache : constructed with contextRQ.statusRQ.comm.getPMTU
   ------------------------------------------------------------------------------
   -- Pruned when EN_READ_G=false: ReqHandleRq's forced classifiers guarantee
   -- the insert/search request valids below never assert, so the tied readies
   -- are never observed and the responses are never consumed.
   GEN_NO_DUP_CACHE : if not EN_READ_G generate
      insertReadReady       <= '1';
      searchReadReqReady    <= '1';
      searchReadRespValid   <= '0';
      searchReadRespData    <= (others => '0');
      insertAtomicReady     <= '1';
      searchAtomicReqReady  <= '1';
      searchAtomicRespValid <= '0';
      searchAtomicRespData  <= (others => '0');
   end generate GEN_NO_DUP_CACHE;

   GEN_DUP_CACHE : if EN_READ_G generate
   U_DupReadAtomicCache : entity surf.DupReadAtomicCache
      generic map (
         TPD_G => TPD_G)
      port map (
         clk                   => clk,
         rst                   => rst,
         pmtu                  => getPMTU,               -- construct arg getPMTU
         insertReadEn          => insertReadValid,
         insertReadData        => insertReadData,
         insertReadReady       => insertReadReady,
         searchReadReqEn       => searchReadReqValid,
         searchReadReqData     => searchReadReqData,
         searchReadReqReady    => searchReadReqReady,
         searchReadRespValid   => searchReadRespValid,
         searchReadRespData    => searchReadRespData,
         searchReadRespRdEn    => searchReadRespGetEn,
         insertAtomicEn        => insertAtomicValid,
         insertAtomicData      => insertAtomicData,
         insertAtomicReady     => insertAtomicReady,
         searchAtomicReqEn     => searchAtomicReqValid,
         searchAtomicReqData   => searchAtomicReqData,
         searchAtomicReqReady  => searchAtomicReqReady,
         searchAtomicRespValid => searchAtomicRespValid,
         searchAtomicRespData  => searchAtomicRespData,
         searchAtomicRespRdEn  => searchAtomicRespGetEn,
         clearEn               => dupCacheClearAll);
   end generate GEN_DUP_CACHE;

   ------------------------------------------------------------------------------
   -- U_PayloadConsumer : mkPayloadConsumer(statusRQ, dmaWriteCntrl, reqPktPipeIn.payload)
   ------------------------------------------------------------------------------
   U_PayloadConsumer : entity surf.PayloadConsumerConAndGen
      generic map (
         TPD_G => TPD_G)
      port map (
         clk                => clk,
         rst                => rst,
         isReset            => isReset,
         isNonErr           => isNonErr,
         isErr              => isERR,
         -- request : from U_ReqHandleRq
         reqInValid         => payloadConReqValid,
         reqInData          => payloadConReqData,
         reqInReady         => payloadConReqReady,
         -- response : to U_WorkCompGenRq
         respOutReady       => payloadConRespGetEn,
         respOutValid       => payloadConRespValid,
         respOutData        => payloadConRespData,
         -- payloadPipeIn : reqPktPipeIn.payload (external)
         payloadPipeInValid => payloadPipeInValid,
         payloadPipeInData  => payloadPipeInData,
         payloadPipeInReady => payloadPipeInReady,
         -- dmaWriteSrv : dmaWriteCntrl (external CLIENT)
         dmaWriteReqValid   => dmaWriteReqValid,
         dmaWriteReqData    => dmaWriteReqData,
         dmaWriteReqReady   => dmaWriteReqReady,
         dmaWriteRespValid  => dmaWriteRespValid,
         dmaWriteRespData   => dmaWriteRespData,
         dmaWriteRespReady  => dmaWriteRespReady);

   ------------------------------------------------------------------------------
   -- U_ReqHandleRq : mkReqHandleRQ(contextRQ, payloadGenerator, permCheckSrv,
   --   dupReadAtomicCache, recvReqBuf, reqPktPipeIn.pktMetaData, payloadConsumer.request)
   ------------------------------------------------------------------------------
   U_ReqHandleRq : entity surf.ReqHandleRq
      generic map (
         TPD_G       => TPD_G,
         EN_READ_G   => EN_READ_G,
         MAX_QP_WR_G => MAX_QP_WR_G)
      port map (
         clk                            => clk,
         rst                            => rst,
         -- contextRQ.statusRQ.comm status
         isReset                        => isReset,
         isNonErr                       => isNonErr,
         isERR                          => isERR,
         getTypeQP                      => getTypeQP,
         getPMTU                        => getPMTU,
         getPKEY                        => getPKEY,
         getSQPN                        => getSQPN,
         getDQPN                        => getDQPN,
         getMinRnrTimer                 => getMinRnrTimer,
         getAccessFlags                 => getAccessFlags,
         getPendingWorkReqNum           => getPendingWorkReqNum,
         getPendingDestReadAtomicReqNum => getPendingDestReadAtomicReqNum,
         -- contextRQ shared registers
         getEpoch                       => getEpoch,
         incEpoch                       => incEpoch,
         getEPSN                        => getEPSN,
         getRespPktNum                  => getRespPktNum,
         setRespPktNumValid             => setRespPktNumValid,
         setRespPktNumData              => setRespPktNumData,
         getIsRespPktNumZero            => getIsRespPktNumZero,
         setEPSNValid                   => setEPSNValid,
         setEPSNData                    => setEPSNData,
         getPreReqOpCode                => getPreReqOpCode,
         setPreReqOpCodeValid           => setPreReqOpCodeValid,
         setPreReqOpCodeData            => setPreReqOpCodeData,
         restoreValid                   => restoreValid,
         restorePreOpCodeData           => restorePreOpCodeData,
         restorePsnData                 => restorePsnData,
         getPermCheckReq                => getPermCheckReq,
         setPermCheckReqValid           => setPermCheckReqValid,
         setPermCheckReqData            => setPermCheckReqData,
         getNextDmaWriteAddr            => getNextDmaWriteAddr,
         setNextDmaWriteAddrValid       => setNextDmaWriteAddrValid,
         setNextDmaWriteAddrData        => setNextDmaWriteAddrData,
         getSendWriteReqPktNum          => getSendWriteReqPktNum,
         setSendWriteReqPktNumValid     => setSendWriteReqPktNumValid,
         setSendWriteReqPktNumData      => setSendWriteReqPktNumData,
         getRemainingDmaWriteLen        => getRemainingDmaWriteLen,
         setRemainingDmaWriteLenValid   => setRemainingDmaWriteLenValid,
         setRemainingDmaWriteLenData    => setRemainingDmaWriteLenData,
         getTotalDmaWriteLen            => getTotalDmaWriteLen,
         setTotalDmaWriteLenValid       => setTotalDmaWriteLenValid,
         setTotalDmaWriteLenData        => setTotalDmaWriteLenData,
         getCurRespPSN                  => getCurRespPSN,
         setCurRespPSNValid             => setCurRespPSNValid,
         setCurRespPSNData              => setCurRespPSNData,
         getMSN                         => getMSN,
         setMSNValid                    => setMSNValid,
         setMSNData                     => setMSNData,
         -- pktMetaDataPipeIn : reqPktPipeIn.pktMetaData (external)
         pktMetaValid                   => pktMetaValid,
         pktMetaData                    => pktMetaData,
         pktMetaDeq                     => pktMetaDeq,
         -- recvReqBuf (external)
         recvReqValid                   => recvReqValid,
         recvReqData                    => recvReqData,
         recvReqDeq                     => recvReqDeq,
         -- payloadConReqPort : to U_PayloadConsumer.request
         payloadConReqValid             => payloadConReqValid,
         payloadConReqData              => payloadConReqData,
         payloadConReqReady             => payloadConReqReady,
         -- permCheckSrv (external)
         permReqValid                   => permReqValid,
         permReqData                    => permReqData,
         permReqReady                   => permReqReady,
         permRespValid                  => permRespValid,
         permRespData                   => permRespData,
         permRespGetEn                  => permRespGetEn,
         -- payloadGenerator (external)
         payloadGenReqValid             => payloadGenReqValid,
         payloadGenReqData              => payloadGenReqData,
         payloadGenReqReady             => payloadGenReqReady,
         payloadGenRespValid            => payloadGenRespValid,
         payloadGenRespData             => payloadGenRespData,
         payloadGenRespGetEn            => payloadGenRespGetEn,
         payloadDataStreamValid         => payloadDataStreamValid,
         payloadDataStreamData          => payloadDataStreamData,
         payloadDataStreamRdEn          => payloadDataStreamRdEn,
         -- dupReadAtomicCache : to U_DupReadAtomicCache
         insertReadValid                => insertReadValid,
         insertReadData                 => insertReadData,
         insertReadReady                => insertReadReady,
         searchReadReqValid             => searchReadReqValid,
         searchReadReqData              => searchReadReqData,
         searchReadReqReady             => searchReadReqReady,
         searchReadRespValid            => searchReadRespValid,
         searchReadRespData             => searchReadRespData,
         searchReadRespGetEn            => searchReadRespGetEn,
         insertAtomicValid              => insertAtomicValid,
         insertAtomicData               => insertAtomicData,
         insertAtomicReady              => insertAtomicReady,
         searchAtomicReqValid           => searchAtomicReqValid,
         searchAtomicReqData            => searchAtomicReqData,
         searchAtomicReqReady           => searchAtomicReqReady,
         searchAtomicRespValid          => searchAtomicRespValid,
         searchAtomicRespData           => searchAtomicRespData,
         searchAtomicRespGetEn          => searchAtomicRespGetEn,
         dupCacheClear                  => dupCacheClear,
         -- outputs
         rdmaRespDataStreamValid        => rdmaRespDataStreamValid,
         rdmaRespDataStreamData         => rdmaRespDataStreamData,
         rdmaRespDataStreamRdEn         => rdmaRespDataStreamRdEn,
         workCompGenReqValid            => workCompGenReqValid,
         workCompGenReqData             => workCompGenReqData,
         workCompGenReqRdEn             => workCompGenReqDeq,
         respHeaderOutNotEmpty          => respHeaderOutNotEmpty);

   ------------------------------------------------------------------------------
   -- U_WorkCompGenRq : mkWorkCompGenRQ(statusRQ, payloadConsumer.response,
   --                                   reqHandlerRQ.workCompGenReqPipeOut)
   ------------------------------------------------------------------------------
   U_WorkCompGenRq : entity surf.WorkCompGenRq
      generic map (
         TPD_G => TPD_G)
      port map (
         clk                   => clk,
         rst                   => rst,
         -- statusRQ.comm status
         isReset_i             => isReset,
         isNonErr_i            => isNonErr,
         isERR_i               => isERR,
         getPKEY_i             => getPKEY,
         getSQPN_i             => getSQPN,
         -- payloadConRespPort : from U_PayloadConsumer.response
         payloadConRespValid_i => payloadConRespValid,
         payloadConRespData_i  => payloadConRespData,
         payloadConRespGetEn_o => payloadConRespGetEn,
         -- wcGenReqPipeInFromRQ : from U_ReqHandleRq.workCompGenReqPipeOut
         reqValid_i            => workCompGenReqValid,
         reqData_i             => workCompGenReqData,
         reqDeq_o              => workCompGenReqDeq,
         -- workCompPipeOut : forwarded to RQ.workCompRQ
         workCompValid_o       => workCompValid,
         workCompData_o        => workCompData,
         workCompRdEn_i        => workCompRdEn,
         hasErr_o              => workCompHasErr);

end architecture rtl;
