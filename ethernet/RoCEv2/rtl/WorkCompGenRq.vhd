-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Receive-queue sibling of WorkCompGenSq.  A 3-state control FSM
--   (workCompGenState) wrapped around a 2-stage SURF Fifo pipeline (one stage
--   shorter than SQ — there is no pendingWorkCompQ4* input-buffer stage; the
--   input PipeOut feeds dmaWaitingQ directly).
--
--   Token flow (each FIFO is a surf.Fifo, FWFT, sync):
--     input PipeOut (wcGenReqPipeInFromRQ)
--       --recvWorkCompReqRQ--> U_DmaWaitingQ
--       --waitDmaDoneRQ (NORMAL) / noDmaWaitRQ (ERR)--> U_GenWorkCompQ
--       --genWorkCompRQ (NORMAL) / errFlushRQ (ERR)--> U_WorkCompOutQ4RQ
--         --> workCompPipeOut
--                       \--(waitDmaDoneRQ error path)--> U_WcStatusQ4SQ (DEAD)
--
--   FSM states (BSV workCompGenStateReg, mkReg(WC_GEN_ST_STOP)):
--     WC_GEN_ST_STOP_S      — idle; no pipeline rule active
--     WC_GEN_ST_NORMAL_S    — normal completion generation
--     WC_GEN_ST_ERR_FLUSH_S — flushing pending WCs as IBV_WC_WR_FLUSH_ERR
--
--   Derived mode signals (combinational, recomputed every cycle):
--     inNormalState = isNonErr AND state=NORMAL
--     inErrorState  = isERR    OR  state=ERR_FLUSH
--   (Note vs SQ: RQ's mode/start guards use cntrlStatus.comm.isNonErr, not
--    isStableRTS/isRTS.  start fires on isNonErr && state==STOP.)
--
--   State-register writers (guard-mutually-exclusive; emit priority
--   reset > start > genWorkCompRQ):
--     resetAndClear (isReset)            -> STOP_S, clear all 4 FIFOs
--     start         (isNonErr && STOP)   -> NORMAL_S
--     genWorkCompRQ (NORMAL, !success)   -> ERR_FLUSH_S
--   The six pipeline rules are conflict_free, operate on disjoint FIFOs and are
--   emitted as concurrent combinational datapaths (no priority among them).
--   NORMAL/ERROR stage pairs (waitDmaDoneRQ/noDmaWaitRQ on dmaWaitingQ;
--   genWorkCompRQ/errFlushRQ on genWorkCompQ) share a FIFO rd/wr enable but are
--   mutually exclusive by mode, so each shared enable is driven by exactly one
--   path per cycle.
--
--   FIFO clear (OQ-FSM-01 carry-forward, RESOLVED in out/03-fsm/RESOLVED.md):
--     BSV FIFOF.clear under resetAndClear maps to asserting each Fifo's rst,
--     OR'd with the structural reset:  fifoClr = rst OR isReset.  surf.FifoSync
--     holds logically empty for the whole asserted window (level-safe); no pulse
--     generator needed.  Requires GEN_SYNC_FIFO_G=true, RST_ASYNC_G=false,
--     RST_POLARITY_G='1'.
--
--   Mapping note (OQ-FSM-WCGRQ-01, RESOLVED): mapping.json owns.state_registers
--     is empty and owns.rules carries fabricated aliases for this entity; the
--     FSM spec (and this file) are authoritative for state and rules.  RQ has
--     exactly ONE registered field (workCompGenState); all per-token context
--     rides inside the PendingWorkCompRQ struct through the FIFOs (no mkRegU
--     context registers, unlike the SQ twin).  The four surf_instances FIFOs in
--     mapping.json are correct by name.
--
--   Dead output (OQ-FSM-WCGRQ-02, RESOLVED option (a) — keep for fidelity):
--     U_WcStatusQ4SQ is written by waitDmaDoneRQ's error (!success) path but is
--     NEVER dequeued and NEVER exported — the WorkCompGen interface exposes only
--     workCompPipeOut + hasErr, and the would-be workCompStatusPipeOutRQ line is
--     commented out in the BSV (WorkCompGen.bsv:700).  It is kept instantiated
--     here for source fidelity: it preserves BSV back-pressure (after MAX error
--     tokens, wcsNotFull='0' back-pressures the error path of waitDmaDoneRQ).
--     TODO: this RQ->SQ WC-status pipe has no consumer in the current source —
--     wire up workCompStatusPipeOutRQ or drop the FIFO once the consumer exists.
--
--   Excluded by design (OQ-FSM-WCGRQ-03): the BSV source's commented-out
--     err-flush helper functions (genErrFlushWorkComp4WorkCompGenReqRQ /
--     genErrFlushWorkComp4RecvReq), CQ-full back-pressure handling
--     (isCompQueueFull), and the workCompStatusPipeOutRQ interface are NOT
--     implemented — they are commented out in the source.  errFlushRQ instead
--     reuses the carried pendingWorkCompRQ.maybeWorkComp and overrides
--     flags/status (NO_FLAGS / WR_FLUSH_ERR).
--
--   SURF components instantiated (source: surf/base/fifo/rtl/Fifo.vhd):
--     U_DmaWaitingQ     : surf.Fifo  DATA_WIDTH_G=428 ADDR_WIDTH_G=4
--                         PendingWorkCompRQ ; mkFIFOF (default depth)
--     U_GenWorkCompQ    : surf.Fifo  DATA_WIDTH_G=428 ADDR_WIDTH_G=4
--                         PendingWorkCompRQ ; mkFIFOF (default depth)
--     U_WorkCompOutQ4RQ : surf.Fifo  DATA_WIDTH_G=222 ADDR_WIDTH_G=5 (depth 32)
--                         WorkComp ; mkSizedFIFOF MAX_CQE.  rd side exported as
--                         workCompPipeOut (downstream drives rd_en).
--     U_WcStatusQ4SQ    : surf.Fifo  DATA_WIDTH_G=5 ADDR_WIDTH_G=4
--                         WorkCompStatus ; mkFIFOF.  DEAD (no reader) — see above.
--     Distributed-RAM FWFT cold latency is 1 cycle (block RAM was 2) — see tb-spec §8.
--
--   Type widths (BSV deriving(Bits), first-field-at-MSB; traced from
--   DataTypes.bsv/Headers.bsv/Settings.bsv — see OQ-FSM-H2DS-04 packing rule):
--     WorkComp          = 222 b  (id 64 | opcode 8 | flags 7 | status 5 | len 32 |
--                                  pkey 16 | qpn 24 | immDt 33 | rkey2Inv 33)
--     WorkCompGenReqRQ  = 198 b  (rrID Maybe#(WorkReqID) 65 | len 32 | reqPSN 24 |
--                                  isZeroDmaLen 1 | wcStatus 5 | reqOpCode 5 |
--                                  immDt Maybe#(IMM) 33 | rkey2Inv Maybe#(RKEY) 33)
--     PendingWorkCompRQ = 428 b  (wcGenReqRQ 198 | maybeWorkComp Maybe#(WorkComp) 223 |
--                                  isSendReq 1 | isWriteReq 1 | isWriteImmReq 1 |
--                                  isFirstOrOnlyReq 1 | isLastOrOnlyReq 1 |
--                                  isWorkCompSuccess 1 | needWaitDmaWriteResp 1)
--     WorkCompStatus    =   5 b  (24 enum values)
--     RdmaOpCode        =   5 b  (24 enum values, encodings 0x00..0x17)
--     PayloadConResp    =  53 b  (= DmaWriteResp: initiator 4 | sqpn 24 | psn 24 |
--                                  isRespErr 1) ; dmaWriteResp.psn = [24:1]
--
--   WorkCompGenReqRQ field slices (in reqData_i, 198-bit input word):
--     rrID.tag=[197]  rrID.id=[196:133]  len=[132:101]  reqPSN=[100:77]
--     isZeroDmaLen=[76]  wcStatus=[75:71]  reqOpCode=[70:66]
--     immDt=[65:33] (tag [65], val [64:33])  rkey2Inv=[32:0] (tag [32], val [31:0])
--   PendingWorkCompRQ field slices (in dmaDout/genDout, 428-bit word):
--     wcGenReqRQ=[427:230] (wcStatus within = [305:301], reqPSN = [330:307])
--     maybeWorkComp.tag=[229]  maybeWorkComp.workComp=[228:7]
--       (id|opcode=[228:157] flags=[156:150] status=[149:145] rest=[144:7])
--     isSendReq=[6] isWriteReq=[5] isWriteImmReq=[4] isFirstOrOnlyReq=[3]
--     isLastOrOnlyReq=[2] isWorkCompSuccess=[1] needWaitDmaWriteResp=[0]
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

entity WorkCompGenRq is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk                   : in  sl;
      rst                   : in  sl;                  -- active-high synchronous reset
      -- cntrlStatus.comm status methods (combinational inputs)
      isReset_i             : in  sl;                  -- isReset  -> resetAndClear
      isNonErr_i            : in  sl;                  -- isNonErr -> start / inNormalState
      isERR_i               : in  sl;                  -- isERR       (inErrorState)
      getPKEY_i             : in  slv(15 downto 0);    -- getPKEY -> WorkComp.pkey
      getSQPN_i             : in  slv(23 downto 0);    -- getSQPN -> WorkComp.qpn
      -- payloadConRespPort : Get#(PayloadConResp)  (entity deqs)
      payloadConRespValid_i : in  sl;                  -- response available
      payloadConRespData_i  : in  slv(52 downto 0);    -- PayloadConResp packed (sim-only use)
      payloadConRespGetEn_o : out sl;                  -- .get handshake (deq)
      -- wcGenReqPipeInFromRQ : PipeOut#(WorkCompGenReqRQ)
      reqValid_i            : in  sl;                  -- notEmpty
      reqData_i             : in  slv(197 downto 0);   -- first (WorkCompGenReqRQ)
      reqDeq_o              : out sl;                  -- deq
      -- workCompPipeOut : PipeOut#(WorkComp)  (= U_WorkCompOutQ4RQ read face)
      workCompValid_o       : out sl;                  -- notEmpty
      workCompData_o        : out slv(221 downto 0);   -- first (WorkComp)
      workCompRdEn_i        : in  sl;                  -- deq (downstream drives)
      -- hasErr() method
      hasErr_o              : out sl);                 -- state = ERR_FLUSH_S
end entity WorkCompGenRq;

architecture rtl of WorkCompGenRq is

   -- FSM control state (BSV WorkCompGenState / workCompGenStateReg)
   type StateType is (WC_GEN_ST_STOP_S, WC_GEN_ST_NORMAL_S, WC_GEN_ST_ERR_FLUSH_S);

   type RegType is record
      state : StateType;                               -- workCompGenStateReg (mkReg STOP)
   end record RegType;

   constant REG_INIT_C : RegType := (
      state => WC_GEN_ST_STOP_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- WorkComp enum constants (DataTypes.bsv)
   constant WC_RECV_C               : slv(7 downto 0) := x"80";   -- IBV_WC_RECV = 128
   constant WC_RECV_RDMA_W_IMM_C    : slv(7 downto 0) := x"81";   -- IBV_WC_RECV_RDMA_WITH_IMM = 129
   constant WC_NO_FLAGS_C           : slv(6 downto 0) := "0000000"; -- IBV_WC_NO_FLAGS = 0
   constant WC_WITH_IMM_C           : slv(6 downto 0) := "0000010"; -- IBV_WC_WITH_IMM = 2
   constant WC_WITH_INV_C           : slv(6 downto 0) := "0001000"; -- IBV_WC_WITH_INV = 8
   constant WC_SUCCESS_C            : slv(4 downto 0) := "00000";   -- IBV_WC_SUCCESS = 0
   constant WC_WR_FLUSH_ERR_C       : slv(4 downto 0) := "00101";   -- IBV_WC_WR_FLUSH_ERR = 5

   -- U_DmaWaitingQ (PendingWorkCompRQ, 428b)
   signal dmaWrEn    : sl;
   signal dmaDin     : slv(427 downto 0);
   signal dmaRdEn    : sl;
   signal dmaDout    : slv(427 downto 0);
   signal dmaValid   : sl;
   signal dmaNotFull : sl;

   -- U_GenWorkCompQ (PendingWorkCompRQ, 428b)
   signal genWrEn    : sl;
   signal genDin     : slv(427 downto 0);
   signal genRdEn    : sl;
   signal genDout    : slv(427 downto 0);
   signal genValid   : sl;
   signal genNotFull : sl;

   -- U_WorkCompOutQ4RQ (WorkComp, 222b)
   signal outWrEn    : sl;
   signal outDin     : slv(221 downto 0);
   signal outDout    : slv(221 downto 0);
   signal outValid   : sl;
   signal outNotFull : sl;

   -- U_WcStatusQ4SQ (WorkCompStatus, 5b) — DEAD output (written, never read)
   signal wcsWrEn    : sl;
   signal wcsDin     : slv(4 downto 0);
   signal wcsNotFull : sl;

   -- FIFO clear line: level = rst OR isReset (see FIFO clear note above)
   signal fifoClr : sl;

begin

   -- FIFO clear: level-sensitive (OQ-FSM-01 carry-forward, RESOLVED)
   fifoClr <= rst or isReset_i;

   -- hasErr() : Moore decode of registered state
   hasErr_o <= '1' when (r.state = WC_GEN_ST_ERR_FLUSH_S) else '0';

   -- workCompPipeOut read face (pass-through; downstream drives rd_en)
   workCompValid_o <= outValid;
   workCompData_o  <= outDout;

   ---------------------------------------------------------------------------
   -- U_DmaWaitingQ : surf.Fifo
   --   mkFIFOF carrying PendingWorkCompRQ.
   --   wr: recvWorkCompReqRQ ; rd: waitDmaDoneRQ (NORMAL) / noDmaWaitRQ (ERR).
   ---------------------------------------------------------------------------
   U_DmaWaitingQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 428,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoClr,
         wr_clk        => clk,
         wr_en         => dmaWrEn,
         din           => dmaDin,
         not_full      => dmaNotFull,
         full          => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => dmaRdEn,
         dout          => dmaDout,
         valid         => dmaValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_GenWorkCompQ : surf.Fifo
   --   mkFIFOF carrying PendingWorkCompRQ.
   --   wr: waitDmaDoneRQ (NORMAL) / noDmaWaitRQ (ERR) ;
   --   rd: genWorkCompRQ (NORMAL) / errFlushRQ (ERR).
   ---------------------------------------------------------------------------
   U_GenWorkCompQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 428,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoClr,
         wr_clk        => clk,
         wr_en         => genWrEn,
         din           => genDin,
         not_full      => genNotFull,
         full          => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => genRdEn,
         dout          => genDout,
         valid         => genValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_WorkCompOutQ4RQ : surf.Fifo
   --   mkSizedFIFOF(MAX_CQE=32) carrying WorkComp.
   --   wr: genWorkCompRQ (NORMAL) / errFlushRQ (ERR) ;
   --   rd side = workCompPipeOut (downstream consumer drives rd_en).
   ---------------------------------------------------------------------------
   U_WorkCompOutQ4RQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 222,
         ADDR_WIDTH_G    => 5)
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
         rd_en         => workCompRdEn_i,    -- downstream drives (PipeOut deq)
         dout          => outDout,
         valid         => outValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_WcStatusQ4SQ : surf.Fifo  (DEAD OUTPUT — kept for source fidelity)
   --   mkFIFOF carrying WorkCompStatus (5b).
   --   wr: waitDmaDoneRQ error (!success) path ;
   --   rd: NONE — there is no reader/consumer in this source (see header /
   --       OQ-FSM-WCGRQ-02).  rd_en is tied off and dout/valid left open; the
   --       FIFO can saturate and back-pressure the error path via wcsNotFull,
   --       exactly as the BSV mkFIFOF does.
   --   TODO: wire up workCompStatusPipeOutRQ consumer or drop this instance.
   ---------------------------------------------------------------------------
   U_WcStatusQ4SQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 5,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoClr,
         wr_clk        => clk,
         wr_en         => wcsWrEn,
         din           => wcsDin,
         not_full      => wcsNotFull,
         full          => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => '0',               -- DEAD: no reader
         dout          => open,
         valid         => open,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- Combinatorial process
   ---------------------------------------------------------------------------
   comb : process (r, rst, isReset_i, isNonErr_i, isERR_i, getPKEY_i, getSQPN_i,
                   payloadConRespValid_i, reqValid_i, reqData_i,
                   dmaValid, dmaNotFull, dmaDout,
                   genValid, genNotFull, genDout, outNotFull, wcsNotFull) is
      variable v             : RegType;
      -- derived mode signals
      variable inNormalState : boolean;
      variable inErrorState  : boolean;
      -- recvWorkCompReqRQ datapath temporaries (from reqData_i : WorkCompGenReqRQ)
      variable reqOpCode     : slv(4 downto 0);
      variable wcStatus      : slv(4 downto 0);
      variable wcOpcode      : slv(7 downto 0);
      variable wcOpcodeValid : sl;
      variable wcFlags       : slv(6 downto 0);
      variable isSendReq     : sl;
      variable isWriteReq    : sl;
      variable isWriteImmReq : sl;
      variable isFirstReq    : sl;
      variable isLastReq     : sl;
      variable isOnlyReq     : sl;
      variable isFirstOrOnly : sl;
      variable isLastOrOnly  : sl;
      variable isSuccess     : sl;
      variable needWaitDma   : sl;
      variable maybeWcTag    : sl;
      variable workCompBuilt : slv(221 downto 0);
      variable pendToken     : slv(427 downto 0);
      -- waitDmaDoneRQ guard helpers (from dmaDout : PendingWorkCompRQ)
      variable dmaIsSuccess  : sl;
      variable dmaNeedWaitDma : sl;
      variable dmaIsLastOnly : sl;
      variable dmaIsSend     : sl;
      variable dmaIsWriteImm : sl;
      variable waitGenEnq    : sl;   -- success path enqueues genWorkCompQ?
      variable waitStatEnq   : sl;   -- error path enqueues wcStatusQ4SQ?
      variable waitGetWanted : sl;   -- success path deqs payloadConResp?
      variable waitFire      : sl;
      -- genWorkCompRQ / errFlushRQ helpers (from genDout : PendingWorkCompRQ)
      variable genIsSuccess  : sl;
      variable genMaybeTag   : sl;
      variable genWorkComp   : slv(221 downto 0);
      variable genEnqWanted  : sl;
      variable errFlushWC    : slv(221 downto 0);
      variable errEnqWanted  : sl;
   begin
      v := r;

      -- default (deasserted) outputs / FIFO controls
      dmaWrEn               <= '0';
      dmaDin                <= (others => '0');
      dmaRdEn               <= '0';
      genWrEn               <= '0';
      genDin                <= (others => '0');
      genRdEn               <= '0';
      outWrEn               <= '0';
      outDin                <= (others => '0');
      wcsWrEn               <= '0';
      wcsDin                <= (others => '0');
      payloadConRespGetEn_o <= '0';
      reqDeq_o              <= '0';

      -- derived mode signals (combinational from registered state + inputs)
      inNormalState := (isNonErr_i = '1') and (r.state = WC_GEN_ST_NORMAL_S);
      inErrorState  := (isERR_i = '1') or (r.state = WC_GEN_ST_ERR_FLUSH_S);

      ----------------------------------------------------------------------
      -- recvWorkCompReqRQ datapath: decode reqOpCode and build the
      -- PendingWorkCompRQ token from the input WorkCompGenReqRQ word.
      ----------------------------------------------------------------------
      reqOpCode := reqData_i(70 downto 66);
      wcStatus  := reqData_i(75 downto 71);

      -- RdmaOpCode classification + WorkComp opcode/flags mapping
      --   (Utils.bsv isSendReqRdmaOpCode/isWriteReqRdmaOpCode/isWriteImmReq*,
      --    isFirst/isLast/isOnlyRdmaOpCode, rdmaOpCode2WorkCompOpCode4RQ,
      --    rdmaOpCode2WorkCompFlagsRQ).  reqOpCode encodings 0x00..0x17.
      isSendReq     := '0';
      isWriteReq    := '0';
      isWriteImmReq := '0';
      isFirstReq    := '0';
      isLastReq     := '0';
      isOnlyReq     := '0';
      wcOpcode      := WC_RECV_C;
      wcOpcodeValid := '0';
      wcFlags       := WC_NO_FLAGS_C;
      case reqOpCode is
         when "00000" =>                                   -- SEND_FIRST
            isSendReq := '1'; isFirstReq := '1';
            wcOpcode := WC_RECV_C; wcOpcodeValid := '1'; wcFlags := WC_NO_FLAGS_C;
         when "00001" =>                                   -- SEND_MIDDLE
            isSendReq := '1';
            wcOpcode := WC_RECV_C; wcOpcodeValid := '1'; wcFlags := WC_NO_FLAGS_C;
         when "00010" =>                                   -- SEND_LAST
            isSendReq := '1'; isLastReq := '1';
            wcOpcode := WC_RECV_C; wcOpcodeValid := '1'; wcFlags := WC_NO_FLAGS_C;
         when "00011" =>                                   -- SEND_LAST_WITH_IMMEDIATE
            isSendReq := '1'; isLastReq := '1';
            wcOpcode := WC_RECV_C; wcOpcodeValid := '1'; wcFlags := WC_WITH_IMM_C;
         when "00100" =>                                   -- SEND_ONLY
            isSendReq := '1'; isOnlyReq := '1';
            wcOpcode := WC_RECV_C; wcOpcodeValid := '1'; wcFlags := WC_NO_FLAGS_C;
         when "00101" =>                                   -- SEND_ONLY_WITH_IMMEDIATE
            isSendReq := '1'; isOnlyReq := '1';
            wcOpcode := WC_RECV_C; wcOpcodeValid := '1'; wcFlags := WC_WITH_IMM_C;
         when "00110" =>                                   -- RDMA_WRITE_FIRST
            isWriteReq := '1'; isFirstReq := '1';
            wcOpcodeValid := '0';
         when "00111" =>                                   -- RDMA_WRITE_MIDDLE
            isWriteReq := '1';
            wcOpcodeValid := '0';
         when "01000" =>                                   -- RDMA_WRITE_LAST
            isWriteReq := '1'; isLastReq := '1';
            wcOpcodeValid := '0';
         when "01001" =>                                   -- RDMA_WRITE_LAST_WITH_IMMEDIATE
            isWriteReq := '1'; isWriteImmReq := '1'; isLastReq := '1';
            wcOpcode := WC_RECV_RDMA_W_IMM_C; wcOpcodeValid := '1'; wcFlags := WC_WITH_IMM_C;
         when "01010" =>                                   -- RDMA_WRITE_ONLY
            isWriteReq := '1'; isOnlyReq := '1';
            wcOpcodeValid := '0';
         when "01011" =>                                   -- RDMA_WRITE_ONLY_WITH_IMMEDIATE
            isWriteReq := '1'; isWriteImmReq := '1'; isOnlyReq := '1';
            wcOpcode := WC_RECV_RDMA_W_IMM_C; wcOpcodeValid := '1'; wcFlags := WC_WITH_IMM_C;
         when "01100" =>                                   -- RDMA_READ_REQUEST
            isOnlyReq := '1'; wcOpcodeValid := '0';
         when "01101" =>                                   -- RDMA_READ_RESPONSE_FIRST
            isFirstReq := '1'; wcOpcodeValid := '0';
         when "01110" =>                                   -- RDMA_READ_RESPONSE_MIDDLE
            wcOpcodeValid := '0';
         when "01111" =>                                   -- RDMA_READ_RESPONSE_LAST
            isLastReq := '1'; wcOpcodeValid := '0';
         when "10000" =>                                   -- RDMA_READ_RESPONSE_ONLY
            isOnlyReq := '1'; wcOpcodeValid := '0';
         when "10001" =>                                   -- ACKNOWLEDGE
            isOnlyReq := '1'; wcOpcodeValid := '0';
         when "10010" =>                                   -- ATOMIC_ACKNOWLEDGE
            isOnlyReq := '1'; wcOpcodeValid := '0';
         when "10011" =>                                   -- COMPARE_SWAP
            isOnlyReq := '1'; wcOpcodeValid := '0';
         when "10100" =>                                   -- FETCH_ADD
            isOnlyReq := '1'; wcOpcodeValid := '0';
         when "10101" =>                                   -- RESYNC
            wcOpcodeValid := '0';
         when "10110" =>                                   -- SEND_LAST_WITH_INVALIDATE
            isSendReq := '1'; isLastReq := '1';
            wcOpcode := WC_RECV_C; wcOpcodeValid := '1'; wcFlags := WC_WITH_INV_C;
         when "10111" =>                                   -- SEND_ONLY_WITH_INVALIDATE
            isSendReq := '1'; isOnlyReq := '1';
            wcOpcode := WC_RECV_C; wcOpcodeValid := '1'; wcFlags := WC_WITH_INV_C;
         when others =>                                    -- 0x18..0x1f unused
            wcOpcodeValid := '0';
      end case;

      isFirstOrOnly := isFirstReq or isOnlyReq;
      isLastOrOnly  := isLastReq or isOnlyReq;

      -- isWorkCompSuccess = wcStatus == IBV_WC_SUCCESS
      if (wcStatus = WC_SUCCESS_C) then
         isSuccess := '1';
      else
         isSuccess := '0';
      end if;

      -- needWaitDmaWriteResp = !isZeroDmaLen && (isSendReq || isWriteReq)
      if (reqData_i(76) = '0') and ((isSendReq = '1') or (isWriteReq = '1')) then
         needWaitDma := '1';
      else
         needWaitDma := '0';
      end if;

      -- maybeWorkComp = genWorkComp4RecvReq(cntrlStatus, first):
      --   Valid iff (mapped WC opcode Valid) && (rrID Valid).
      maybeWcTag := wcOpcodeValid and reqData_i(197);    -- rrID.tag = reqData_i(197)
      --   WorkComp { id=rrID.id, opcode=wcOpcode, flags=wcFlags, status=wcStatus,
      --              len=wr.len, pkey=getPKEY, qpn=getSQPN, immDt, rkey2Inv }
      workCompBuilt := reqData_i(196 downto 133)         -- id    (64) = rrID.id
                       & wcOpcode                        -- opcode (8)
                       & wcFlags                         -- flags  (7)
                       & wcStatus                        -- status (5)
                       & reqData_i(132 downto 101)       -- len   (32)
                       & getPKEY_i                       -- pkey  (16)
                       & getSQPN_i                       -- qpn   (24)
                       & reqData_i(65 downto 33)         -- immDt   (33, Maybe passthrough)
                       & reqData_i(32 downto 0);         -- rkey2Inv(33, Maybe passthrough)

      -- PendingWorkCompRQ = wcGenReqRQ(198) & maybeWcTag & workComp(222) & 7 bools
      pendToken := reqData_i                             -- wcGenReqRQ (198)
                   & maybeWcTag                          -- maybeWorkComp.tag (1)
                   & workCompBuilt                       -- maybeWorkComp.workComp (222)
                   & isSendReq & isWriteReq & isWriteImmReq
                   & isFirstOrOnly & isLastOrOnly
                   & isSuccess & needWaitDma;
      dmaDin <= pendToken;

      ----------------------------------------------------------------------
      -- waitDmaDoneRQ guard helpers (from dmaDout : PendingWorkCompRQ)
      ----------------------------------------------------------------------
      dmaIsSuccess   := dmaDout(1);
      dmaNeedWaitDma := dmaDout(0);
      dmaIsLastOnly  := dmaDout(2);
      dmaIsSend      := dmaDout(6);
      dmaIsWriteImm  := dmaDout(4);
      -- success path enqueues genWorkCompQ only if isLastOrOnly && (isSend||isWriteImm)
      if (dmaIsSuccess = '1') then
         if (dmaIsLastOnly = '1') and ((dmaIsSend = '1') or (dmaIsWriteImm = '1')) then
            waitGenEnq := '1';
         else
            waitGenEnq := '0';
         end if;
         waitStatEnq   := '0';
         waitGetWanted := dmaNeedWaitDma;               -- conditional .get
      else
         -- error path: enqueue genWorkCompQ AND wcStatusQ4SQ unconditionally
         waitGenEnq    := '1';
         waitStatEnq   := '1';
         waitGetWanted := '0';
      end if;

      ----------------------------------------------------------------------
      -- genWorkCompRQ / errFlushRQ helpers (from genDout : PendingWorkCompRQ)
      ----------------------------------------------------------------------
      genIsSuccess := genDout(1);
      genMaybeTag  := genDout(229);
      genWorkComp  := genDout(228 downto 7);            -- maybeWorkComp.workComp
      -- genWorkCompRQ enq: success -> always enq unwrapped WC; error -> enq only if Valid
      if (genIsSuccess = '1') then
         genEnqWanted := '1';
      else
         genEnqWanted := genMaybeTag;
      end if;
      -- errFlushRQ: override flags->NO_FLAGS, status->WR_FLUSH_ERR; enq only on Valid
      -- and ((isSend && isFirstOrOnly) || isWriteImm)
      errFlushWC := genDout(228 downto 157)             -- id|opcode (72)
                    & WC_NO_FLAGS_C                      -- flags  (7)
                    & WC_WR_FLUSH_ERR_C                  -- status (5)
                    & genDout(144 downto 7);            -- len..rkey2Inv (138)
      if (genMaybeTag = '1') and
         (((genDout(6) = '1') and (genDout(3) = '1')) or (genDout(4) = '1')) then
         errEnqWanted := '1';
      else
         errEnqWanted := '0';
      end if;

      ----------------------------------------------------------------------
      -- Pipeline rules (conflict_free; concurrent datapaths).  All gated off
      -- while isReset (resetAndClear dominates, clearing the FIFOs).
      ----------------------------------------------------------------------
      if (isReset_i = '0') then

         -- recvWorkCompReqRQ (row 3): input PipeOut -> U_DmaWaitingQ
         if ((inNormalState or inErrorState) and reqValid_i = '1' and dmaNotFull = '1') then
            reqDeq_o <= '1';
            dmaWrEn  <= '1';
            -- dmaDin already built above (pendToken)
         end if;

         -- U_DmaWaitingQ -> U_GenWorkCompQ : waitDmaDoneRQ (NORMAL) / noDmaWaitRQ (ERR)
         -- (mutually exclusive by mode; share dmaRdEn / genWrEn / genDin)
         if (inNormalState and dmaValid = '1') then
            -- waitDmaDoneRQ: conditional implicit conditions —
            --   genNotFull gates only when waitGenEnq; wcsNotFull only when waitStatEnq;
            --   payloadConRespValid only when waitGetWanted.
            waitFire := '1';
            if (waitGenEnq = '1' and genNotFull = '0') then
               waitFire := '0';
            end if;
            if (waitStatEnq = '1' and wcsNotFull = '0') then
               waitFire := '0';
            end if;
            if (waitGetWanted = '1' and payloadConRespValid_i = '0') then
               waitFire := '0';
            end if;
            if (waitFire = '1') then
               dmaRdEn <= '1';                           -- deq dmaWaitingQ
               if (waitGenEnq = '1') then
                  genWrEn <= '1';
                  genDin  <= dmaDout;                    -- PendingWorkCompRQ pass-through
               end if;
               if (waitStatEnq = '1') then
                  wcsWrEn <= '1';
                  wcsDin  <= dmaDout(305 downto 301);    -- wcGenReqRQ.wcStatus
               end if;
               if (waitGetWanted = '1') then
                  payloadConRespGetEn_o <= '1';          -- conditional .get (deq DMA resp)
               end if;
            end if;
         elsif (inErrorState and dmaValid = '1' and genNotFull = '1') then
            -- noDmaWaitRQ (no DMA wait / no status enq in error)
            dmaRdEn <= '1';
            genWrEn <= '1';
            genDin  <= dmaDout;
         end if;

         -- U_GenWorkCompQ -> U_WorkCompOutQ4RQ : genWorkCompRQ (NORMAL) / errFlushRQ (ERR)
         if (inNormalState and genValid = '1') then
            -- genWorkCompRQ: outNotFull gates firing only on the enqueuing branch.
            if (genEnqWanted = '0' or outNotFull = '1') then
               genRdEn <= '1';                           -- deq genWorkCompQ
               if (genIsSuccess = '1') then
                  -- success: emit the unwrapped WorkComp (sim-assert Valid below)
                  outWrEn <= '1';
                  outDin  <= genWorkComp;
               else
                  -- error: enter ERR_FLUSH; emit the carried WC if Valid
                  v.state := WC_GEN_ST_ERR_FLUSH_S;
                  if (genMaybeTag = '1') then
                     outWrEn <= '1';
                     outDin  <= genWorkComp;
                  end if;
               end if;
            end if;

         elsif (inErrorState and genValid = '1') then
            -- errFlushRQ: deq always; emit flush-overridden WC when enq wanted.
            if (errEnqWanted = '0' or outNotFull = '1') then
               genRdEn <= '1';                           -- deq genWorkCompQ
               if (errEnqWanted = '1') then
                  outWrEn <= '1';
                  outDin  <= errFlushWC;
               end if;
            end if;
         end if;

         -- discardPayloadConRespRQ (row 8, ERR): drain payloadConRespPort.
         -- Mutually exclusive with waitDmaDoneRQ's getEn by mode.
         if (inErrorState and payloadConRespValid_i = '1') then
            payloadConRespGetEn_o <= '1';
         end if;

         -- start (row 2): STOP -> NORMAL on isNonErr
         if (isNonErr_i = '1' and r.state = WC_GEN_ST_STOP_S) then
            v.state := WC_GEN_ST_NORMAL_S;
         end if;

      end if;

      -- resetAndClear (row 1, highest priority): force STOP; FIFOs cleared via fifoClr
      if (isReset_i = '1') then
         v.state := WC_GEN_ST_STOP_S;
      end if;

      -- structural synchronous reset (dominates; matches mkReg STOP power-on)
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

   ---------------------------------------------------------------------------
   -- Simulation-only assertions (no synthesizable effect; BSV immAssert):
   --   1. genWorkCompRQ success: maybeWorkComp must be Valid (genDout(229)='1').
   --   2. waitDmaDoneRQ: when getting a DMA resp, its psn must match reqPSN.
   --   3. errFlushRQ: token must be a SEND or WRITE_IMM request when emitting.
   ---------------------------------------------------------------------------
   -- pragma translate_off
   chk : process (clk) is
   begin
      if rising_edge(clk) then
         if (rst = '0' and isReset_i = '0') then
            -- (1) genWorkCompRQ success path: carried WC must be Valid
            if (isNonErr_i = '1' and r.state = WC_GEN_ST_NORMAL_S and
                genValid = '1' and genDout(1) = '1') then
               assert (genDout(229) = '1')
                  report "WorkCompGenRq: genWorkCompRQ maybeWorkComp must be Valid on success"
                  severity warning;
            end if;
            -- (2) waitDmaDoneRQ DMA-response PSN match (NORMAL, conditional get)
            if (isNonErr_i = '1' and r.state = WC_GEN_ST_NORMAL_S and
                dmaValid = '1' and dmaDout(1) = '1' and dmaDout(0) = '1' and
                payloadConRespValid_i = '1') then
               assert (payloadConRespData_i(24 downto 1) = dmaDout(330 downto 307))
                  report "WorkCompGenRq: waitDmaDoneRQ dmaWriteResp.psn /= wcGenReqRQ.reqPSN"
                  severity error;
            end if;
            -- (3) errFlushRQ: emitted WC must be SEND or WRITE_IMM
            if ((isERR_i = '1' or r.state = WC_GEN_ST_ERR_FLUSH_S) and genValid = '1' and
                genDout(229) = '1') then
               assert (genDout(6) = '1' or genDout(4) = '1')
                  report "WorkCompGenRq: errFlushRQ token must be SEND or WRITE_IMM"
                  severity error;
            end if;
         end if;
      end if;
   end process chk;
   -- pragma translate_on

end architecture rtl;
