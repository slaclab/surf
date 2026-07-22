-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   3-state control FSM (workCompGenState) wrapped around a 4-stage SURF Fifo
--   pipeline that turns SQ work-completion-generation requests into WorkComp
--   tokens exposed on workCompPipeOut.
--
--   Token flow (each FIFO is a surf.Fifo, FWFT, sync):
--     2 PipeIns --recvWorkCompGenReqSQ--> U_PendingWorkCompQ4SQ
--       --genPendingWorkCompSQ--> U_DmaWaitingQ
--       --waitDmaDoneSQ (NORMAL) / noDmaWaitSQ (ERR)--> U_GenWorkCompQ
--       --genWorkCompSQ (NORMAL) / errFlushSQ (ERR)--> U_WorkCompOutQ4SQ
--       --> workCompPipeOut
--
--   FSM states (BSV workCompGenStateReg, mkReg(WC_GEN_ST_STOP)):
--     WC_GEN_ST_STOP_S      — idle; no pipeline rule active
--     WC_GEN_ST_NORMAL_S    — normal completion generation
--     WC_GEN_ST_ERR_FLUSH_S — flushing pending WCs as IBV_WC_WR_FLUSH_ERR
--
--   Derived mode signals (combinational, recomputed every cycle):
--     inNormalState = isStableRTS AND state=NORMAL
--     inErrorState  = isERR       OR  state=ERR_FLUSH
--
--   State-register writers (guard-mutually-exclusive; emit priority
--   reset > start > genWorkCompSQ):
--     resetAndClear (isReset)            -> STOP_S, clear all 4 FIFOs
--     start         (isRTS && STOP)      -> NORMAL_S
--     genWorkCompSQ (NORMAL, !success)   -> ERR_FLUSH_S
--   The seven pipeline rules are conflict_free, operate on disjoint FIFOs and
--   are emitted as concurrent combinational datapaths (no priority among them).
--   NORMAL/ERROR stage pairs share a FIFO rd/wr enable but are mutually
--   exclusive by mode, so the shared enable is driven by exactly one path/cycle.
--
--   FIFO clear (OQ-FSM-01 carry-forward, RESOLVED in out/03-fsm/RESOLVED.md):
--     BSV FIFOF.clear under resetAndClear maps to asserting each Fifo's rst,
--     OR'd with the structural reset:  fifoClr = rst OR isReset.  surf.FifoSync
--     holds logically empty for the whole asserted window (level-safe); no pulse
--     generator needed.  Requires GEN_SYNC_FIFO_G=true, RST_ASYNC_G=false,
--     RST_POLARITY_G='1'.
--
--   Mapping note (OQ-FSM-WCGSQ-01, RESOLVED): mapping.json owns.state_registers
--     is empty and owns.rules carries fabricated aliases for this entity; the
--     FSM spec (and this file) are authoritative for state and rules.  The four
--     surf_instances FIFOs in mapping.json are correct.
--
--   Excluded by design (OQ-FSM-WCGSQ-02): the BSV source's commented-out
--     RQ-error propagation (recvWorkCompStatusRQ / rqHasErrReg) and CQ-full
--     back-pressure handling (isCompQueueFull) are NOT implemented — they are
--     stubbed/absent in the source.
--
--   mkRegU fields (OQ-FSM-WCGSQ-02): isFirstErrPartialAckWorkReq and
--     firstErrPartialAckWorkReqId are BSV mkRegU (no power-on reset).  They are
--     written by genWorkCompSQ on ERR entry strictly before errFlushSQ reads
--     them, so the undefined power-on value is never observed.  Emitted in
--     REG_INIT_C with zero init for determinism; the no-reset origin is noted.
--
--   Conditional implicit condition (OQ-FSM-WCGSQ-03): waitDmaDoneSQ deqs
--     payloadConRespPort only inside (isWorkCompSuccess && wcWaitDmaResp); the
--     port's readiness gates the dmaWaitingQ->genWorkCompQ move only then.
--
--   SURF components instantiated (source: surf/base/fifo/rtl/Fifo.vhd):
--     U_PendingWorkCompQ4SQ : surf.Fifo  DATA_WIDTH_G=633 ADDR_WIDTH_G=6 (depth 64)
--                             WorkCompGenReqSQ ; mkSizedFIFOF MAX_PENDING_WORK_COMP_NUM
--     U_DmaWaitingQ         : surf.Fifo  DATA_WIDTH_G=857 ADDR_WIDTH_G=4
--                             PendingWorkCompSQ ; mkFIFOF (default depth)
--     U_GenWorkCompQ        : surf.Fifo  DATA_WIDTH_G=857 ADDR_WIDTH_G=4
--                             PendingWorkCompSQ ; mkFIFOF (default depth)
--     U_WorkCompOutQ4SQ     : surf.Fifo  DATA_WIDTH_G=222 ADDR_WIDTH_G=5 (depth 32)
--                             WorkComp ; mkSizedFIFOF MAX_CQE.  rd side exported
--                             as workCompPipeOut (downstream drives rd_en).
--     Distributed-RAM FWFT cold latency is 1 cycle (block RAM was 2) — see tb-spec §8.
--
--   Type widths (BSV deriving(Bits), first-field-at-MSB; traced from
--   DataTypes.bsv/Headers.bsv/Settings.bsv):
--     WorkReq          = 601 b  (id 64 | opcode 4 | flags 5 | raddr 64 | rkey 32 |
--                                 len 32 | laddr 64 | lkey 32 | sqpn 24 | solicited 1 |
--                                 comp 65 | swap 65 | immDt 33 | rkey2Inv 33 |
--                                 srqn 25 | dqpn 25 | qkey 33)
--     WorkComp         = 222 b  (id 64 | opcode 8 | flags 7 | status 5 | len 32 |
--                                 pkey 16 | qpn 24 | immDt 33 | rkey2Inv 33)
--     WorkCompGenReqSQ = 633 b  (wr 601 | wcWaitDmaResp 1 | wcReqType 2 |
--                                 triggerPSN 24 | wcStatus 5)
--     PendingWorkCompSQ= 857 b  (wcGenReqSQ 633 | workComp 222 |
--                                 isWorkCompSuccess 1 | needWorkCompWhenNormal 1)
--     PayloadConResp   =  53 b  (= DmaWriteResp: initiator 4 | sqpn 24 | psn 24 |
--                                 isRespErr 1) ; dmaWriteResp.psn = [24:1]
--
--   WorkCompGenReqSQ field slices (in pendDout / wcGenReqSQ at +224 in dmaDout/genDout):
--     wr.id   = [632:569]   wr.opcode = [568:565]   wr.flags = [564:560]
--     wr.len  = [463:432]   wcWaitDmaResp = [31]    wcReqType = [30:29]
--     triggerPSN = [28:5]   wcStatus = [4:0]
--   WorkComp field slices (within the 222-bit token):
--     id=[221:158] opcode=[157:150] flags=[149:143] status=[142:138]
--     len=[137:106] pkey=[105:90] qpn=[89:66] immDt=[65:33] rkey2Inv=[32:0]
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

entity WorkCompGenSq is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk                  : in  sl;
      rst                  : in  sl;                  -- active-high synchronous reset
      -- cntrlStatus.comm status methods (combinational inputs)
      isReset_i            : in  sl;                  -- isReset  -> resetAndClear
      isRTS_i              : in  sl;                  -- isRTS    -> start
      isStableRTS_i        : in  sl;                  -- isStableRTS (inNormalState)
      isERR_i              : in  sl;                  -- isERR       (inErrorState)
      getSigAll_i          : in  sl;                  -- getSigAll
      getPKEY_i            : in  slv(15 downto 0);    -- getPKEY -> WorkComp.pkey
      getSQPN_i            : in  slv(23 downto 0);    -- getSQPN -> WorkComp.qpn
      -- payloadConRespPort : Get#(PayloadConResp)  (entity deqs)
      payloadConRespValid_i : in  sl;                 -- response available
      payloadConRespData_i  : in  slv(52 downto 0);   -- PayloadConResp packed (sim-only use)
      payloadConRespGetEn_o : out sl;                 -- .get handshake (deq)
      -- wcGenReqPipeInFromReqGenInSQ : PipeOut#(WorkCompGenReqSQ)
      reqGenInValid_i      : in  sl;                  -- notEmpty
      reqGenInData_i       : in  slv(632 downto 0);   -- first (WorkCompGenReqSQ)
      reqGenInDeq_o        : out sl;                  -- deq
      -- wcGenReqPipeInFromRespHandleInSQ : PipeOut#(WorkCompGenReqSQ)
      respHandleInValid_i  : in  sl;                  -- notEmpty
      respHandleInData_i   : in  slv(632 downto 0);   -- first (WorkCompGenReqSQ)
      respHandleInDeq_o    : out sl;                  -- deq
      -- workCompPipeOut : PipeOut#(WorkComp)  (= U_WorkCompOutQ4SQ read face)
      workCompValid_o      : out sl;                  -- notEmpty
      workCompData_o       : out slv(221 downto 0);   -- first (WorkComp)
      workCompRdEn_i       : in  sl;                  -- deq (downstream drives)
      -- hasErr() method
      hasErr_o             : out sl);                 -- state = ERR_FLUSH_S
end entity WorkCompGenSq;

architecture rtl of WorkCompGenSq is

   -- FSM control state (BSV WorkCompGenState / workCompGenStateReg)
   type StateType is (WC_GEN_ST_STOP_S, WC_GEN_ST_NORMAL_S, WC_GEN_ST_ERR_FLUSH_S);

   type RegType is record
      state                       : StateType;        -- workCompGenStateReg (mkReg STOP)
      isFirstErrPartialAckWorkReq : sl;               -- mkRegU (no reset) — see header
      firstErrPartialAckWorkReqId : slv(63 downto 0); -- mkRegU (no reset) — WorkReqID
   end record RegType;

   constant REG_INIT_C : RegType := (
      state                       => WC_GEN_ST_STOP_S,
      isFirstErrPartialAckWorkReq => '0',             -- mkRegU: zero init for determinism
      firstErrPartialAckWorkReqId => (others => '0')); -- mkRegU: zero init for determinism

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- WorkComp enum constants (DataTypes.bsv)
   constant WC_NO_FLAGS_C     : slv(6 downto 0) := "0000000";          -- IBV_WC_NO_FLAGS = 0
   constant WC_WR_FLUSH_ERR_C : slv(4 downto 0) := "00101";            -- IBV_WC_WR_FLUSH_ERR = 5
   constant WC_SUCCESS_C      : slv(4 downto 0) := "00000";            -- IBV_WC_SUCCESS = 0
   constant WC_REQ_FULL_ACK_C : slv(1 downto 0) := "00";              -- WC_REQ_TYPE_FULL_ACK = 0
   constant WC_REQ_PART_ACK_C : slv(1 downto 0) := "01";              -- WC_REQ_TYPE_PARTIAL_ACK = 1
   -- immDt (Maybe#(IMM)=33) + rkey2Inv (Maybe#(RKEY)=33) = 66 Invalid bits
   constant WC_MAYBE_PAD_C    : slv(65 downto 0) := (others => '0');

   -- U_PendingWorkCompQ4SQ (WorkCompGenReqSQ, 633b)
   signal pendWrEn    : sl;
   signal pendDin     : slv(632 downto 0);
   signal pendRdEn    : sl;
   signal pendDout    : slv(632 downto 0);
   signal pendValid   : sl;
   signal pendNotFull : sl;

   -- U_DmaWaitingQ (PendingWorkCompSQ, 857b)
   signal dmaWrEn    : sl;
   signal dmaDin     : slv(856 downto 0);
   signal dmaRdEn    : sl;
   signal dmaDout    : slv(856 downto 0);
   signal dmaValid   : sl;
   signal dmaNotFull : sl;

   -- U_GenWorkCompQ (PendingWorkCompSQ, 857b)
   signal genWrEn    : sl;
   signal genDin     : slv(856 downto 0);
   signal genRdEn    : sl;
   signal genDout    : slv(856 downto 0);
   signal genValid   : sl;
   signal genNotFull : sl;

   -- U_WorkCompOutQ4SQ (WorkComp, 222b)
   signal outWrEn    : sl;
   signal outDin     : slv(221 downto 0);
   signal outDout    : slv(221 downto 0);
   signal outValid   : sl;
   signal outNotFull : sl;

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
   -- U_PendingWorkCompQ4SQ : surf.Fifo
   --   mkSizedFIFOF(MAX_PENDING_WORK_COMP_NUM=64) carrying WorkCompGenReqSQ.
   --   wr: recvWorkCompGenReqSQ ; rd: genPendingWorkCompSQ.
   ---------------------------------------------------------------------------
   U_PendingWorkCompQ4SQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "block",
         DATA_WIDTH_G    => 633,
         ADDR_WIDTH_G    => 6)
      port map (
         rst           => fifoClr,
         wr_clk        => clk,
         wr_en         => pendWrEn,
         din           => pendDin,
         not_full      => pendNotFull,
         full          => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => pendRdEn,
         dout          => pendDout,
         valid         => pendValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_DmaWaitingQ : surf.Fifo
   --   mkFIFOF carrying PendingWorkCompSQ.
   --   wr: genPendingWorkCompSQ ; rd: waitDmaDoneSQ (NORMAL) / noDmaWaitSQ (ERR).
   ---------------------------------------------------------------------------
   U_DmaWaitingQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 857,
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
   --   mkFIFOF carrying PendingWorkCompSQ.
   --   wr: waitDmaDoneSQ (NORMAL) / noDmaWaitSQ (ERR) ;
   --   rd: genWorkCompSQ (NORMAL) / errFlushSQ (ERR).
   ---------------------------------------------------------------------------
   U_GenWorkCompQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 857,
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
   -- U_WorkCompOutQ4SQ : surf.Fifo
   --   mkSizedFIFOF(MAX_CQE=32) carrying WorkComp.
   --   wr: genWorkCompSQ (NORMAL) / errFlushSQ (ERR) ;
   --   rd side = workCompPipeOut (downstream consumer drives rd_en).
   ---------------------------------------------------------------------------
   U_WorkCompOutQ4SQ : entity surf.Fifo
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
   -- Combinatorial process
   ---------------------------------------------------------------------------
   comb : process (r, rst, isReset_i, isRTS_i, isStableRTS_i, isERR_i,
                   getSigAll_i, getPKEY_i, getSQPN_i,
                   payloadConRespValid_i, reqGenInValid_i, reqGenInData_i,
                   respHandleInValid_i, respHandleInData_i,
                   pendValid, pendNotFull, pendDout,
                   dmaValid, dmaNotFull, dmaDout,
                   genValid, genNotFull, genDout, outNotFull) is
      variable v             : RegType;
      -- derived mode signals
      variable inNormalState : boolean;
      variable inErrorState  : boolean;
      -- genPendingWorkCompSQ datapath temporaries (from pendDout)
      variable wrOpcode      : slv(3 downto 0);
      variable wcOpcode      : slv(7 downto 0);
      variable wcOpcodeValid : sl;
      variable isReadOrAtom  : sl;
      variable wcStatus      : slv(4 downto 0);
      variable wcReqType     : slv(1 downto 0);
      variable isSuccess     : sl;
      variable needNormal    : sl;
      variable workCompBuilt : slv(221 downto 0);
      -- genWorkCompSQ / errFlushSQ datapath temporaries (from genDout)
      variable genIsSuccess  : sl;
      variable genNeedNormal : sl;
      variable genWorkComp   : slv(221 downto 0);
      variable errFlushWC    : slv(221 downto 0);
      variable genEnqWanted  : sl;
      -- waitDmaDoneSQ datapath temporaries (from dmaDout)
      variable dmaIsSuccess  : sl;
      variable dmaWaitResp   : sl;
      variable waitDmaCond   : sl;
   begin
      v := r;

      -- default (deasserted) outputs / FIFO controls
      pendWrEn              <= '0';
      pendDin               <= (others => '0');
      pendRdEn              <= '0';
      dmaWrEn               <= '0';
      dmaDin                <= (others => '0');
      dmaRdEn               <= '0';
      genWrEn               <= '0';
      genDin                <= (others => '0');
      genRdEn               <= '0';
      outWrEn               <= '0';
      outDin                <= (others => '0');
      payloadConRespGetEn_o <= '0';
      reqGenInDeq_o         <= '0';
      respHandleInDeq_o     <= '0';

      -- derived mode signals (combinational from registered state + inputs)
      inNormalState := (isStableRTS_i = '1') and (r.state = WC_GEN_ST_NORMAL_S);
      inErrorState  := (isERR_i = '1') or (r.state = WC_GEN_ST_ERR_FLUSH_S);

      ----------------------------------------------------------------------
      -- genPendingWorkCompSQ datapath (build PendingWorkCompSQ from pendDout)
      --   WorkCompGenReqSQ slices:  wr.opcode=[568:565] wr.flags=[564:560]
      --   wr.id=[632:569] wr.len=[463:432] wcReqType=[30:29] wcStatus=[4:0]
      ----------------------------------------------------------------------
      wrOpcode  := pendDout(568 downto 565);
      wcStatus  := pendDout(4 downto 0);
      wcReqType := pendDout(30 downto 29);

      -- workReqOpCode2WorkCompOpCode4SQ (Utils.bsv:1518)
      case wrOpcode is
         when "0000" => wcOpcode := x"01"; wcOpcodeValid := '1';  -- RDMA_WRITE          -> WC_RDMA_WRITE(1)
         when "0001" => wcOpcode := x"01"; wcOpcodeValid := '1';  -- RDMA_WRITE_WITH_IMM -> WC_RDMA_WRITE(1)
         when "0010" => wcOpcode := x"00"; wcOpcodeValid := '1';  -- SEND                -> WC_SEND(0)
         when "0011" => wcOpcode := x"00"; wcOpcodeValid := '1';  -- SEND_WITH_IMM       -> WC_SEND(0)
         when "0100" => wcOpcode := x"02"; wcOpcodeValid := '1';  -- RDMA_READ           -> WC_RDMA_READ(2)
         when "0101" => wcOpcode := x"03"; wcOpcodeValid := '1';  -- ATOMIC_CMP_AND_SWP  -> WC_COMP_SWAP(3)
         when "0110" => wcOpcode := x"04"; wcOpcodeValid := '1';  -- ATOMIC_FETCH_AND_ADD-> WC_FETCH_ADD(4)
         when "0111" => wcOpcode := x"06"; wcOpcodeValid := '1';  -- LOCAL_INV           -> WC_LOCAL_INV(6)
         when "1000" => wcOpcode := x"05"; wcOpcodeValid := '1';  -- BIND_MW             -> WC_BIND_MW(5)
         when "1001" => wcOpcode := x"00"; wcOpcodeValid := '1';  -- SEND_WITH_INV       -> WC_SEND(0)
         when "1010" => wcOpcode := x"07"; wcOpcodeValid := '1';  -- TSO                 -> WC_TSO(7)
         when others => wcOpcode := x"00"; wcOpcodeValid := '0';  -- tagged Invalid
      end case;

      -- isReadOrAtomicWorkReq (Utils.bsv:1443): RDMA_READ / CMP_AND_SWP / FETCH_AND_ADD
      if (wrOpcode = "0100" or wrOpcode = "0101" or wrOpcode = "0110") then
         isReadOrAtom := '1';
      else
         isReadOrAtom := '0';
      end if;

      -- isWorkCompSuccess = wcStatus == IBV_WC_SUCCESS
      if (wcStatus = WC_SUCCESS_C) then
         isSuccess := '1';
      else
         isSuccess := '0';
      end if;

      -- needWorkCompWhenNormal = wcReqType==FULL_ACK &&
      --   (workReqNeedWorkCompSQ(wr) || getSigAll)
      --   workReqNeedWorkCompSQ = containWorkReqFlag(flags, IBV_SEND_SIGNALED=2 => bit1)
      --                           || isReadOrAtomicWorkReq(opcode)
      if (wcReqType = WC_REQ_FULL_ACK_C) and
         ((pendDout(561) = '1') or (isReadOrAtom = '1') or (getSigAll_i = '1')) then
         needNormal := '1';
      else
         needNormal := '0';
      end if;

      -- genWorkComp4WorkReq(cntrlStatus, wcGenReqSQ): WorkComp token
      --   id=wr.id, opcode=wcOpcode, flags=NO_FLAGS, status=wcStatus, len=wr.len,
      --   pkey=getPKEY, qpn=getSQPN, immDt=Invalid, rkey2Inv=Invalid
      workCompBuilt := pendDout(632 downto 569)      -- id    (64)
                       & wcOpcode                     -- opcode (8)
                       & WC_NO_FLAGS_C                -- flags  (7)
                       & wcStatus                     -- status (5)
                       & pendDout(463 downto 432)     -- len   (32)
                       & getPKEY_i                    -- pkey  (16)
                       & getSQPN_i                    -- qpn   (24)
                       & WC_MAYBE_PAD_C;              -- immDt+rkey2Inv (66)

      -- PendingWorkCompSQ = wcGenReqSQ(633) & workComp(222) & isSuccess & needNormal
      dmaDin <= pendDout & workCompBuilt & isSuccess & needNormal;

      ----------------------------------------------------------------------
      -- waitDmaDoneSQ guard helpers (from dmaDout : PendingWorkCompSQ)
      --   isWorkCompSuccess=[1]  wcWaitDmaResp = wcGenReqSQ[31] = [255]
      ----------------------------------------------------------------------
      dmaIsSuccess := dmaDout(1);
      dmaWaitResp  := dmaDout(255);
      if (dmaIsSuccess = '1' and dmaWaitResp = '1') then
         waitDmaCond := '1';
      else
         waitDmaCond := '0';
      end if;

      ----------------------------------------------------------------------
      -- genWorkCompSQ / errFlushSQ datapath (from genDout : PendingWorkCompSQ)
      --   workComp=[223:2] isWorkCompSuccess=[1] needWorkCompWhenNormal=[0]
      ----------------------------------------------------------------------
      genWorkComp   := genDout(223 downto 2);
      genIsSuccess  := genDout(1);
      genNeedNormal := genDout(0);
      -- errFlushWC = workComp with flags->NO_FLAGS, status->WR_FLUSH_ERR
      --   workComp slice: [221:150]=id|opcode, [149:143]=flags, [142:138]=status,
      --   [137:0]=len|pkey|qpn|immDt|rkey2Inv
      errFlushWC := genWorkComp(221 downto 150)
                    & WC_NO_FLAGS_C
                    & WC_WR_FLUSH_ERR_C
                    & genWorkComp(137 downto 0);

      ----------------------------------------------------------------------
      -- Pipeline rules (conflict_free; concurrent datapaths).  All gated off
      -- while isReset (resetAndClear dominates, clearing the FIFOs).
      ----------------------------------------------------------------------
      if (isReset_i = '0') then

         -- recvWorkCompGenReqSQ (rows 3-4): input mux into U_PendingWorkCompQ4SQ
         if ((inNormalState or inErrorState) and pendNotFull = '1') then
            if (reqGenInValid_i = '1') then
               reqGenInDeq_o <= '1';
               pendWrEn      <= '1';
               pendDin       <= reqGenInData_i;
            elsif (respHandleInValid_i = '1') then
               respHandleInDeq_o <= '1';
               pendWrEn          <= '1';
               pendDin           <= respHandleInData_i;
            end if;
         end if;

         -- genPendingWorkCompSQ (row 5): U_PendingWorkCompQ4SQ -> U_DmaWaitingQ
         if ((inNormalState or inErrorState) and pendValid = '1' and dmaNotFull = '1') then
            pendRdEn <= '1';
            dmaWrEn  <= '1';
            -- dmaDin already built above
         end if;

         -- U_DmaWaitingQ -> U_GenWorkCompQ : waitDmaDoneSQ (NORMAL) / noDmaWaitSQ (ERR)
         -- (mutually exclusive by mode; share dmaRdEn / genWrEn / genDin)
         if (inNormalState and dmaValid = '1' and genNotFull = '1' and
             (waitDmaCond = '0' or payloadConRespValid_i = '1')) then
            -- waitDmaDoneSQ
            dmaRdEn <= '1';
            genWrEn <= '1';
            genDin  <= dmaDout;                       -- PendingWorkCompSQ pass-through
            if (waitDmaCond = '1') then
               payloadConRespGetEn_o <= '1';          -- conditional .get (deq DMA resp)
            end if;
         elsif (inErrorState and dmaValid = '1' and genNotFull = '1') then
            -- noDmaWaitSQ (no DMA wait in error)
            dmaRdEn <= '1';
            genWrEn <= '1';
            genDin  <= dmaDout;
         end if;

         -- U_GenWorkCompQ -> U_WorkCompOutQ4SQ : genWorkCompSQ (NORMAL) / errFlushSQ (ERR)
         if (inNormalState and genValid = '1') then
            -- genWorkCompSQ: enq wanted when (success && needNormal) || !success
            if (genIsSuccess = '1') then
               genEnqWanted := genNeedNormal;
            else
               genEnqWanted := '1';
            end if;

            if (genEnqWanted = '0' or outNotFull = '1') then
               genRdEn <= '1';                        -- deq genWorkCompQ
               if (genEnqWanted = '1') then
                  outWrEn <= '1';
                  outDin  <= genWorkComp;             -- WorkComp as-is
               end if;
               if (genIsSuccess = '0') then
                  -- enter ERR_FLUSH; latch first-partial-ACK context
                  v.state := WC_GEN_ST_ERR_FLUSH_S;
                  if (genDout(254 downto 253) = WC_REQ_PART_ACK_C) then
                     v.isFirstErrPartialAckWorkReq := '1';
                  else
                     v.isFirstErrPartialAckWorkReq := '0';
                  end if;
                  v.firstErrPartialAckWorkReqId := genDout(856 downto 793);  -- wr.id
               end if;
            end if;

         elsif (inErrorState and genValid = '1') then
            -- errFlushSQ: drop the first full-ACK after a partial-ACK error;
            -- otherwise emit errFlushWC.  enq wanted = NOT isFirstErrPartialAck.
            genEnqWanted := not r.isFirstErrPartialAckWorkReq;
            if (genEnqWanted = '0' or outNotFull = '1') then
               genRdEn <= '1';                        -- deq genWorkCompQ
               if (r.isFirstErrPartialAckWorkReq = '1') then
                  v.isFirstErrPartialAckWorkReq := '0';   -- skip enq, clear flag
               else
                  outWrEn <= '1';
                  outDin  <= errFlushWC;
               end if;
            end if;
         end if;

         -- discardPayloadConRespSQ (row 10, ERR): drain payloadConRespPort.
         -- Mutually exclusive with waitDmaDoneSQ's getEn by mode.
         if (inErrorState and payloadConRespValid_i = '1') then
            payloadConRespGetEn_o <= '1';
         end if;

         -- start (row 2): STOP -> NORMAL on isRTS
         if (isRTS_i = '1' and r.state = WC_GEN_ST_STOP_S) then
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
   --   1. genPendingWorkCompSQ: maybeWorkComp must be Valid (mapped opcode).
   --   2. waitDmaDoneSQ: when getting a DMA resp, its psn must match triggerPSN.
   --   3. errFlushSQ: wcReqType must be FULL_ACK; when dropping the first
   --      partial-ACK WC, wr.id must match firstErrPartialAckWorkReqId.
   -- (cf. OQ-FSM-WCGSQ-03 / OQ-FSM-APS-03 translate_off treatment.)
   ---------------------------------------------------------------------------
   -- pragma translate_off
   chk : process (clk) is
   begin
      if rising_edge(clk) then
         if (rst = '0' and isReset_i = '0') then
            -- (1) genPendingWorkCompSQ opcode mapping must be Valid
            if (((isStableRTS_i = '1' and r.state = WC_GEN_ST_NORMAL_S) or
                 (isERR_i = '1' or r.state = WC_GEN_ST_ERR_FLUSH_S)) and
                pendValid = '1' and dmaNotFull = '1') then
               assert (pendDout(568 downto 565) /= "1011" and    -- DRIVER1
                       pendDout(568 downto 565) /= "1100" and    -- RDMA_READ_RESP
                       pendDout(568 downto 565) /= "1101" and    -- (reserved 13)
                       pendDout(568 downto 565) /= "1110" and    -- FLUSH
                       pendDout(568 downto 565) /= "1111")       -- ATOMIC_WRITE
                  report "WorkCompGenSq: genPendingWorkCompSQ maybeWorkComp must be Valid"
                  severity warning;
            end if;
            -- (2) waitDmaDoneSQ DMA-response PSN match (NORMAL, conditional get)
            if (isStableRTS_i = '1' and r.state = WC_GEN_ST_NORMAL_S and
                dmaValid = '1' and genNotFull = '1' and
                dmaDout(1) = '1' and dmaDout(255) = '1' and
                payloadConRespValid_i = '1') then
               assert (payloadConRespData_i(24 downto 1) = dmaDout(252 downto 229))
                  report "WorkCompGenSq: waitDmaDoneSQ dmaWriteResp.psn /= wcGenReqSQ.triggerPSN"
                  severity error;
            end if;
            -- (3) errFlushSQ wcReqType must be FULL_ACK
            if ((isERR_i = '1' or r.state = WC_GEN_ST_ERR_FLUSH_S) and genValid = '1') then
               assert (genDout(254 downto 253) = "00")           -- WC_REQ_TYPE_FULL_ACK
                  report "WorkCompGenSq: errFlushSQ wcReqType must be FULL_ACK"
                  severity error;
               if (r.isFirstErrPartialAckWorkReq = '1') then
                  assert (genDout(856 downto 793) = r.firstErrPartialAckWorkReqId)
                     report "WorkCompGenSq: errFlushSQ wr.id /= firstErrPartialAckWorkReqId"
                     severity error;
               end if;
            end if;
         end if;
      end if;
   end process chk;
   -- pragma translate_on

end architecture rtl;
