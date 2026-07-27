-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Cross-SGE byte-shift merge.  The byte stream of each SGE (scatter/gather
--   element) within one SGL is generally not bus-width aligned at its last
--   fragment.  This module concatenates the partial last fragment of one SGE
--   with the first fragment(s) of the next SGE so the emitted DataStream is
--   densely packed across SGE boundaries, re-marking isFirst/isLast at SGL
--   granularity.  3-stage feed-forward pipeline:
--     Stage A  handleMetaDataEachSGE  — turns per-SGE MergedMetaDataSGE into a
--              TmpMergedMetaDataSGE, accumulating cross-SGE misalignment
--              (preInvalid*Reg).  State-independent producer for
--              U_MergedMetaDataQ4EachSGE.
--     Stage B  stateReg control FSM (mergePayloadInit / mergeFirstOrMidSGE /
--              mergeLastOrOnlySGE) — consumes payload fragments + Stage-A
--              metadata, computes the merged fragment and per-fragment left
--              shift amounts; producer for U_PayloadFragShiftQ.
--     Stage C  shiftPayloadFrag — applies the barrel left-shift+merge and emits
--              the final DataStream.  State-independent consumer of
--              U_PayloadFragShiftQ; producer for U_PktPayloadOutQ.
--   The two state-independent rules (A, C) may fire on the same cycle as
--   whichever Stage-B rule is active (disjoint registers / FIFO ports).
--
--   Two upstream PipeOut arguments are CONSUMED (NOT FIFOs instantiated here):
--     sgeMergedMetaDataPipeIn : PipeOut#(MergedMetaDataSGE) (8-bit meta word)
--     sgeMergedPayloadPipeIn  : PipeOut#(DataStream)        (290-bit payload).
--       This pipe is the OUTPUT of the SIBLING MergePayloadEachSge entity wired
--       by the parent (OQ-FSM-MPAS-01) — it is NOT a submodule of this entity.
--   One output PipeOut#(DataStream) is returned (read side of U_PktPayloadOutQ).
--
--   Mapping note (OQ-FSM-MPAS-01): mapping.json / modules.json are entirely
--     wrong for this entity (fabricated single rule `crossMerge`, nonexistent
--     `crossQ`/`carryReg`, a bogus MergePayloadEachSge child instance).  This
--     file follows MergePayloadAllSge.fsm.md, which is authoritative.
--
--   DEVIATION-MPAS-01 (deliberate fix of a latent upstream BSV bug):
--     preprocessNextSgl holds the payload flit (empty prePayloadFrag, no deq)
--     for ANY non-only single-flit first SGE, whereas BSV holds only when the
--     flit is partial (hasLessFrag=1).  The literal BSV dequeues a FULL-width
--     single-flit first SGE at INIT, desynchronising the SGE bookkeeping by one
--     SGE and deadlocking at end-of-SGL (terminal fragment held with isLast
--     stripped).  Upstream blue-rdma has the identical code and its tests never
--     cover this input.  Details in MergePayloadAllSge.result.md (TC-09/TC-10).
--
--   Width / packing resolutions applied:
--     - DataStream width = 290 bits            (OQ-FSM-H2DS-02 / MPAS-02 RESOLVED)
--     - all struct/tuple packing first-field-at-MSB
--                                              (OQ-FSM-H2DS-04 / MPAS-02 RESOLVED)
--
--   Atomicity / stall (OQ-FSM-MPAS-04):
--     - mergeLastOrOnlySGE's final payloadFragShiftQ.enq is UNCONDITIONAL in
--       BSV, so a full U_PayloadFragShiftQ stalls the WHOLE rule — including the
--       stateReg transition and prePayloadFragReg/deq.  Modelled by gating EVERY
--       register update of that rule on fragShiftQFull='0' (branch B also needs
--       sgeMergedPayloadPipeInValid='1').
--     - mergeFirstOrMidSGE's enq is nested under `if (shouldOutput)`.  Per the
--       RESOLVED OQ-FSM-MPAS-04(a) decision the overall rule enable is
--       `(shouldOutput='1') ? fragShiftQNotFull : '1'`; ALL effects (payload
--       deq, prePayloadFragReg, preprocessNextSge state/reg writes) key off this
--       single enable — gating only the enq would be a partial-fire bug.
--
--   FIFO clear (OQ-FSM-MPAS-03 RESOLVED): surf.Fifo has no clear port; BSV
--     FIFOF.clear is modelled by asserting the synchronous rst.  All three FIFOs
--     share fifoRst = rst OR clearAllI (level-safe with FifoSync).
--
--   Bit layouts (BSV deriving(Bits), first-field-at-MSB):
--     DataStream (290): [289:34] data[255:0] | [33:2] byteEn[31:0] |
--                       [1] isFirst | [0] isLast
--     MergedMetaDataSGE (8): [7:2] lastFragValidByteNum[5:0] |
--                       [1] isFirst | [0] isLast
--     TmpMergedMetaDataSGE (34):
--       [33:28] lastFragInvalidByteNum[5:0] | [27:19] lastFragInvalidBitNum[8:0] |
--       [18:13] curInvalidByteNum[5:0]      | [12:4]  curInvalidBitNum[8:0]      |
--       [3] isOnlySGE | [2] sgeIsFirst | [1] sgeIsLast | [0] hasLessFrag
--     payloadFragShiftQ Tuple4 (595):
--       [594:305] prePayloadFrag (DataStream) | [304:15] curPayloadFrag |
--       [14:9] leftShiftInvalidByteNum[5:0] | [8:0] leftShiftInvalidBitNum[8:0]
--
--   SURF components instantiated (source: surf/base/fifo/rtl/Fifo.vhd):
--     U_PktPayloadOutQ          : surf.Fifo DATA_WIDTH_G=290 (output queue, exposed)
--     U_MergedMetaDataQ4EachSGE : surf.Fifo DATA_WIDTH_G=34  (internal pipeline)
--     U_PayloadFragShiftQ       : surf.Fifo DATA_WIDTH_G=595 (internal pipeline)
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

entity MergePayloadAllSge is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk                          : in  sl;
      rst                          : in  sl;  -- active-high synchronous reset
      -- Software clear (BSV constructor parameter clearAll : Bool)
      clearAllI                    : in  sl;
      -- Upstream: MergedMetaDataSGE pipe (sgeMergedMetaDataPipeIn argument)
      sgeMergedMetaDataPipeInValid : in  sl;  -- sgeMergedMetaDataPipeIn.notEmpty
      sgeMergedMetaDataPipeInData  : in  slv(7 downto 0);  -- sgeMergedMetaDataPipeIn.first
      sgeMergedMetaDataPipeInRdEn  : out sl;  -- sgeMergedMetaDataPipeIn.deq
      -- Upstream: DataStream payload pipe (sgeMergedPayloadPipeIn argument,
      --           driven by the sibling MergePayloadEachSge entity)
      sgeMergedPayloadPipeInValid  : in  sl;  -- sgeMergedPayloadPipeIn.notEmpty
      sgeMergedPayloadPipeInData   : in  slv(289 downto 0);  -- sgeMergedPayloadPipeIn.first
      sgeMergedPayloadPipeInRdEn   : out sl;  -- sgeMergedPayloadPipeIn.deq
      -- Downstream: returned PipeOut#(DataStream) (read side of U_PktPayloadOutQ)
      pktPayloadOutValid           : out sl;  -- PipeOut.notEmpty
      pktPayloadOutData            : out slv(289 downto 0);  -- PipeOut.first
      pktPayloadOutRdEn            : in  sl);              -- PipeOut.deq
end entity MergePayloadAllSge;

architecture rtl of MergePayloadAllSge is

   -- Maps BSV MergePayloadStateAllSGE:
   --   MERGE_SGL_PAYLOAD_INIT             -> INIT_S
   --   MERGE_SGL_PAYLOAD_FIRST_OR_MID_SGE -> FIRST_OR_MID_SGE_S
   --   MERGE_SGL_PAYLOAD_LAST_OR_ONLY_SGE -> LAST_OR_ONLY_SGE_S
   type StateType is (INIT_S, FIRST_OR_MID_SGE_S, LAST_OR_ONLY_SGE_S);

   type RegType is record
      state                  : StateType;  -- mkReg(MERGE_SGL_PAYLOAD_INIT)
      -- Stage-B context registers (all mkRegU)
      prePayloadFrag         : slv(289 downto 0);  -- mkRegU (DataStream)
      lastFragInvalidByteNum : slv(5 downto 0);    -- mkRegU (ByteEnBitNum)
      lastFragInvalidBitNum  : slv(8 downto 0);    -- mkRegU (BusBitNum)
      curInvalidByteNum      : slv(5 downto 0);    -- mkRegU (ByteEnBitNum)
      curInvalidBitNum       : slv(8 downto 0);    -- mkRegU (BusBitNum)
      isFirstFrag            : sl;      -- mkRegU
      sgeIsOnly              : sl;      -- mkRegU
      sgeIsLast              : sl;  -- mkRegU (DEAD: written, never read; kept for source fidelity, OQ-FSM-MPAS-04b)
      hasLessFrag            : sl;      -- mkRegU
      -- Stage-A cross-SGE accumulator (mkRegU)
      preInvalidByteNum      : slv(5 downto 0);    -- mkRegU (ByteEnBitNum)
      preInvalidBitNum       : slv(8 downto 0);    -- mkRegU (BusBitNum)
   end record RegType;

   -- All mkRegU fields set to '0' in REG_INIT_C: each is written by its
   -- preprocess*/Stage-A producer before any consumer reads it (pipeline
   -- ordering guarantees write-before-read; preInvalid* is read only on
   -- !sgeIsFirst, which follows a sgeIsFirst write).  Reset value is don't-care.
   constant REG_INIT_C : RegType := (
      state                  => INIT_S,
      prePayloadFrag         => (others => '0'),
      lastFragInvalidByteNum => (others => '0'),
      lastFragInvalidBitNum  => (others => '0'),
      curInvalidByteNum      => (others => '0'),
      curInvalidBitNum       => (others => '0'),
      isFirstFrag            => '0',
      sgeIsOnly              => '0',
      sgeIsLast              => '0',
      hasLessFrag            => '0',
      preInvalidByteNum      => (others => '0'),
      preInvalidBitNum       => (others => '0'));

   constant DATA_BUS_BYTE_WIDTH_C : natural := 32;   -- DATA_BUS_BYTE_WIDTH
   constant DATA_BUS_WIDTH_C      : natural := 256;  -- DATA_BUS_WIDTH

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Shared synchronous clear for all three FIFOs (rst OR clearAllI)
   signal fifoRst : sl;

   -- U_MergedMetaDataQ4EachSGE control / status (internal pipeline FIFO)
   signal metaQWrEn  : sl;
   signal metaQDin   : slv(33 downto 0);
   signal metaQRdEn  : sl;
   signal metaQDout  : slv(33 downto 0);
   signal metaQValid : sl;
   signal metaQFull  : sl;

   -- U_PayloadFragShiftQ control / status (internal pipeline FIFO)
   signal fragShiftQWrEn  : sl;
   signal fragShiftQDin   : slv(594 downto 0);
   signal fragShiftQRdEn  : sl;
   signal fragShiftQDout  : slv(594 downto 0);
   signal fragShiftQValid : sl;
   signal fragShiftQFull  : sl;

   -- U_PktPayloadOutQ control / status (output queue; read side exposed)
   signal pktPayloadOutQWrEn : sl;
   signal pktPayloadOutQDin  : slv(289 downto 0);
   signal pktPayloadOutQFull : sl;

   -- preprocessNextSgl (PayloadGen.bsv:1300): pops mergedMetaDataQ4EachSGE
   -- (deq asserted by caller) and conditionally the payload pipe, sets the
   -- per-SGE context registers + next stateReg, and returns the next
   -- prePayloadFrag value via retFrag (the caller writes prePayloadFragReg).
   -- deqPayload reports whether the payload pipe must be dequeued this cycle.
   procedure preprocessNextSgl (
      variable v          : inout RegType;
      signal mDout        : in    slv(33 downto 0);
      signal payloadData  : in    slv(289 downto 0);
      variable retFrag    : out   slv(289 downto 0);
      variable deqPayload : out   sl) is
      variable lastInvByte : slv(5 downto 0);
      variable lastInvBit  : slv(8 downto 0);
      variable isOnlySgeIn : sl;
      variable sgeIsLastIn : sl;
      variable curIsLast   : sl;
      variable nextHasLess : sl;
   begin
      lastInvByte := mDout(33 downto 28);
      lastInvBit  := mDout(27 downto 19);
      -- mDout(18:13) curInvalidByteNum / mDout(12:4) curInvalidBitNum unused
      -- here; mDout(0) hasLessFrag deliberately unused (DEVIATION-MPAS-01)
      isOnlySgeIn := mDout(3);
      sgeIsLastIn := mDout(1);
      curIsLast   := payloadData(0);

      v.sgeIsOnly   := isOnlySgeIn;
      v.sgeIsLast   := sgeIsLastIn;
      v.isFirstFrag := '1';

      -- If this SGE is a single fragment (and not the only SGE of the SGL),
      -- hold an empty prePayloadFrag and wait for the first fragment of the
      -- next SGE to merge.  BSV additionally requires hasLessFrag=1 here
      -- (partial last fragment); that is a latent upstream bug for a FULL-width
      -- single-flit first SGE (hasLessFrag=0): the flit would be dequeued now,
      -- making every later meta pop lag one SGE behind, so mergeFirstOrMidSGE
      -- eventually strips isLast off the SGL's true terminal fragment and
      -- mergeLastOrOnlySGE then waits forever for payload that never comes
      -- (deadlock; SqSendQ TC-03).  Holding for ANY non-only single-flit SGE
      -- keeps the invariant "the meta pop happens on the SGE's own last flit";
      -- the mergeFirstOrMidSGE shift by lastFragInvalid* (=0 when full-width)
      -- reconstructs the held flit exactly, so partial-SGE behaviour is
      -- unchanged.  See DEVIATION-MPAS-01 in MergePayloadAllSge.result.md.
      if (isOnlySgeIn = '0') and (curIsLast = '1') then
         retFrag     := (others => '0');  -- genEmptyDataStream
         deqPayload  := '0';              -- no payload deq
         nextHasLess := '1';
      else
         retFrag     := payloadData;      -- unmodified
         deqPayload  := '1';
         nextHasLess := '0';
      end if;

      v.hasLessFrag            := nextHasLess;
      v.lastFragInvalidByteNum := lastInvByte;
      v.lastFragInvalidBitNum  := lastInvBit;
      if nextHasLess = '1' then
         v.curInvalidByteNum := std_logic_vector(to_unsigned(DATA_BUS_BYTE_WIDTH_C, 6));  -- 32
         v.curInvalidBitNum  := std_logic_vector(to_unsigned(DATA_BUS_WIDTH_C, 9));  -- 256
      else
         v.curInvalidByteNum := (others => '0');
         v.curInvalidBitNum  := (others => '0');
      end if;

      -- nextState = {sgeIsFirst,sgeIsLast} in {11,01}->LAST ; {10,00}->FIRST
      -- (depends only on sgeIsLast)
      if sgeIsLastIn = '1' then
         v.state := LAST_OR_ONLY_SGE_S;
      else
         v.state := FIRST_OR_MID_SGE_S;
      end if;
   end procedure preprocessNextSgl;

   -- preprocessNextSge (PayloadGen.bsv:1373): pops mergedMetaDataQ4EachSGE (deq
   -- asserted by caller) and loads the next-SGE context registers + stateReg.
   -- No payload deq, no returned fragment.
   procedure preprocessNextSge (
      variable v   : inout RegType;
      signal mDout : in    slv(33 downto 0)) is
      variable lastInvByte : slv(5 downto 0);
      variable lastInvBit  : slv(8 downto 0);
      variable curInvByte  : slv(5 downto 0);
      variable curInvBit   : slv(8 downto 0);
      variable sgeIsLastIn : sl;
      variable hasLessIn   : sl;
   begin
      lastInvByte := mDout(33 downto 28);
      lastInvBit  := mDout(27 downto 19);
      curInvByte  := mDout(18 downto 13);
      curInvBit   := mDout(12 downto 4);
      sgeIsLastIn := mDout(1);
      hasLessIn   := mDout(0);

      v.sgeIsLast              := sgeIsLastIn;
      v.hasLessFrag            := hasLessIn;
      v.lastFragInvalidByteNum := lastInvByte;
      v.lastFragInvalidBitNum  := lastInvBit;
      v.curInvalidByteNum      := curInvByte;
      v.curInvalidBitNum       := curInvBit;

      if sgeIsLastIn = '1' then
         v.state := LAST_OR_ONLY_SGE_S;
      else
         v.state := FIRST_OR_MID_SGE_S;
      end if;
   end procedure preprocessNextSge;

begin

   -- FIFO reset: level-sensitive synchronous clear (OQ-FSM-MPAS-03 RESOLVED).
   -- resetAndClear calls .clear on all three FIFOs while clearAllI='1'.
   fifoRst <= rst or clearAllI;

   ---------------------------------------------------------------------------
   -- U_MergedMetaDataQ4EachSGE : surf.Fifo
   --   Internal pipeline FIFO; produced by handleMetaDataEachSGE (Stage A),
   --   consumed by preprocessNextSgl/Sge (Stage B).  DATA_WIDTH_G=34, FWFT,
   --   sync, distributed RAM.
   ---------------------------------------------------------------------------
   U_MergedMetaDataQ4EachSGE : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 34,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoRst,
         wr_clk        => clk,
         wr_en         => metaQWrEn,
         din           => metaQDin,
         full          => metaQFull,
         not_full      => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => metaQRdEn,
         dout          => metaQDout,
         valid         => metaQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_PayloadFragShiftQ : surf.Fifo
   --   Internal pipeline FIFO; produced by mergeFirstOrMidSGE /
   --   mergeLastOrOnlySGE (Stage B), consumed by shiftPayloadFrag (Stage C).
   --   DATA_WIDTH_G=595, FWFT, sync, distributed RAM (wide word).
   ---------------------------------------------------------------------------
   U_PayloadFragShiftQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 595,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoRst,
         wr_clk        => clk,
         wr_en         => fragShiftQWrEn,
         din           => fragShiftQDin,
         full          => fragShiftQFull,
         not_full      => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => fragShiftQRdEn,
         dout          => fragShiftQDout,
         valid         => fragShiftQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_PktPayloadOutQ : surf.Fifo
   --   Output queue; its read side IS the returned PipeOut#(DataStream).
   --   Produced by shiftPayloadFrag (Stage C).  DATA_WIDTH_G=290, FWFT, sync,
   --   distributed RAM.
   ---------------------------------------------------------------------------
   U_PktPayloadOutQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 290,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoRst,
         wr_clk        => clk,
         wr_en         => pktPayloadOutQWrEn,
         din           => pktPayloadOutQDin,
         full          => pktPayloadOutQFull,
         not_full      => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => pktPayloadOutRdEn,
         dout          => pktPayloadOutData,
         valid         => pktPayloadOutValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- Combinatorial process
   ---------------------------------------------------------------------------
   comb : process (r, rst, clearAllI,
                   sgeMergedMetaDataPipeInValid, sgeMergedMetaDataPipeInData,
                   sgeMergedPayloadPipeInValid, sgeMergedPayloadPipeInData,
                   metaQValid, metaQDout, metaQFull,
                   fragShiftQValid, fragShiftQDout, fragShiftQFull,
                   pktPayloadOutQFull) is
      variable v : RegType;

      -- Stage A (handleMetaDataEachSGE) locals
      variable lastFragValidByteNum : slv(5 downto 0);
      variable aIsFirst             : sl;
      variable aIsLast              : sl;
      variable aIsOnly              : sl;
      variable aLastInvByte         : slv(5 downto 0);
      variable aLastInvBit          : slv(8 downto 0);
      variable aHasLessFrag         : sl;
      variable aCurInvByte          : slv(5 downto 0);
      variable aCurInvBit           : slv(8 downto 0);
      variable aPreInvByte          : slv(5 downto 0);
      variable aPreInvBit           : slv(8 downto 0);
      variable aSumInvByte          : slv(5 downto 0);
      variable aSumInvBit           : slv(8 downto 0);

      -- Stage B (control FSM) locals
      variable curIsLast    : sl;
      variable shouldOutput : sl;
      variable ruleFire     : sl;
      variable preIsLast    : sl;
      variable isLastFrag   : sl;
      variable nextPre      : slv(289 downto 0);
      variable nextFrag     : slv(289 downto 0);
      variable retFrag      : slv(289 downto 0);
      variable deqPayload   : sl;
      variable outPre       : slv(289 downto 0);
      variable bByteEnCat   : slv(63 downto 0);
      variable bDataCat     : slv(511 downto 0);
      variable bShByteEn    : slv(63 downto 0);
      variable bShData      : slv(511 downto 0);

      -- Stage C (shiftPayloadFrag / leftShiftAndMergeFragData) locals
      variable cPreData   : slv(255 downto 0);
      variable cCurData   : slv(255 downto 0);
      variable cPreByteEn : slv(31 downto 0);
      variable cCurByteEn : slv(31 downto 0);
      variable cShByteNum : slv(4 downto 0);  -- truncate(6->5) ShiftByteNum
      variable cShBitNum  : slv(7 downto 0);  -- truncate(9->8) ShiftBitNum
      variable cByteEnCat : slv(63 downto 0);
      variable cDataCat   : slv(511 downto 0);
      variable cShByteEn  : slv(63 downto 0);
      variable cShData    : slv(511 downto 0);
      variable cOutFrag   : slv(289 downto 0);
   begin
      v := r;

      -- default Mealy outputs (deasserted; overridden below per transition)
      sgeMergedMetaDataPipeInRdEn <= '0';
      sgeMergedPayloadPipeInRdEn  <= '0';
      metaQWrEn                   <= '0';
      metaQDin                    <= (others => '0');
      metaQRdEn                   <= '0';
      fragShiftQWrEn              <= '0';
      fragShiftQDin               <= (others => '0');
      fragShiftQRdEn              <= '0';
      pktPayloadOutQWrEn          <= '0';
      pktPayloadOutQDin           <= (others => '0');

      if clearAllI = '1' then
         -- resetAndClear: FIFOs flushed via fifoRst; stateReg forced to INIT_S.
         -- The mkRegU context registers are deliberately untouched (matches BSV;
         -- they are rewritten by the next preprocess* before any read).
         v.state := INIT_S;

      else

         -------------------------------------------------------------------
         -- Stage A : handleMetaDataEachSGE  (state-independent producer)
         --   guard: sgeMergedMetaDataPipeInValid='1' AND metaQFull='0'
         -------------------------------------------------------------------
         if sgeMergedMetaDataPipeInValid = '1' and metaQFull = '0' then
            lastFragValidByteNum := sgeMergedMetaDataPipeInData(7 downto 2);
            aIsFirst             := sgeMergedMetaDataPipeInData(1);
            aIsLast              := sgeMergedMetaDataPipeInData(0);
            aIsOnly              := aIsFirst and aIsLast;

            -- calcFragBitNumAndByteNum(lastFragValidByteNum):
            --   invalidByteNum = 32 - valid ; invalidBitNum = invalidByteNum<<3
            aLastInvByte := std_logic_vector(to_unsigned(DATA_BUS_BYTE_WIDTH_C, 6) - unsigned(lastFragValidByteNum));
            aLastInvBit  := aLastInvByte & "000";

            -- hasLessFrag / cur / pre defaults (sgeIsFirst path)
            aHasLessFrag := ite(unsigned(lastFragValidByteNum) < DATA_BUS_BYTE_WIDTH_C, '1', '0');
            aCurInvByte  := (others => '0');
            aCurInvBit   := (others => '0');
            aPreInvByte  := aLastInvByte;
            aPreInvBit   := aLastInvBit;

            if aIsFirst = '0' then
               -- accumulate cross-SGE misalignment from preInvalid*Reg (OLD)
               aHasLessFrag := ite(unsigned(r.preInvalidByteNum) >= unsigned(lastFragValidByteNum), '1', '0');
               aSumInvByte  := std_logic_vector(unsigned(r.preInvalidByteNum) + unsigned(aLastInvByte));
               aSumInvBit   := std_logic_vector(unsigned(r.preInvalidBitNum) + unsigned(aLastInvBit));
               aCurInvByte  := r.preInvalidByteNum;
               aCurInvBit   := r.preInvalidBitNum;
               aPreInvByte  := '0' & aSumInvByte(4 downto 0);  -- AND busByteNumMask (0x1F)
               aPreInvBit   := '0' & aSumInvBit(7 downto 0);  -- AND busBitNumMask  (0xFF)
            end if;

            v.preInvalidByteNum := aPreInvByte;
            v.preInvalidBitNum  := aPreInvBit;

            sgeMergedMetaDataPipeInRdEn <= '1';
            metaQWrEn                   <= '1';
            metaQDin                    <= aLastInvByte  -- [33:28]
                        & aLastInvBit                    -- [27:19]
                        & aCurInvByte                    -- [18:13]
                        & aCurInvBit                     -- [12:4]
                        & aIsOnly                        -- [3]
                        & aIsFirst                       -- [2]
                        & aIsLast                        -- [1]
                        & aHasLessFrag;                  -- [0]
         end if;

         -------------------------------------------------------------------
         -- Stage B : control FSM
         --           (mergePayloadInit / mergeFirstOrMidSGE / mergeLastOrOnlySGE)
         --   All register reads below use OLD (r) values (BSV semantics).
         -------------------------------------------------------------------
         case r.state is

            -- ============================================================
            -- INIT_S : mergePayloadInit (preprocessNextSgl)
            --   implicit cond: metaQValid='1' AND sgeMergedPayloadPipeInValid='1'
            -- ============================================================
            when INIT_S =>
               if metaQValid = '1' and sgeMergedPayloadPipeInValid = '1' then
                  metaQRdEn <= '1';
                  preprocessNextSgl(v, metaQDout, sgeMergedPayloadPipeInData, retFrag, deqPayload);
                  if deqPayload = '1' then
                     sgeMergedPayloadPipeInRdEn <= '1';
                  end if;
                  v.prePayloadFrag := retFrag;
               end if;

            -- ============================================================
            -- FIRST_OR_MID_SGE_S : mergeFirstOrMidSGE (+preprocessNextSge)
            --   Overall enable (OQ-FSM-MPAS-04a RESOLVED):
            --     sgePayloadValid AND (curIsLast='0' OR metaQValid)
            --                     AND (shouldOutput='0' OR fragShiftQNotFull)
            -- ============================================================
            when FIRST_OR_MID_SGE_S =>
               curIsLast := sgeMergedPayloadPipeInData(0);
               if curIsLast = '1' then
                  shouldOutput := not r.hasLessFrag;
               else
                  shouldOutput := '1';
               end if;

               ruleFire := '0';
               if sgeMergedPayloadPipeInValid = '1'
                  and (curIsLast = '0' or metaQValid = '1')
                  and (shouldOutput = '0' or fragShiftQFull = '0') then
                  ruleFire := '1';
               end if;

               if ruleFire = '1' then
                  sgeMergedPayloadPipeInRdEn <= '1';

                  if curIsLast = '1' then
                     -- preprocessNextSge advances state + loads next-SGE regs
                     metaQRdEn <= '1';
                     preprocessNextSge(v, metaQDout);

                     -- nextPrePayloadFrag = curPayloadFrag, isLast:=0, byteEn/data
                     --   = truncate({pre,cur} >> lastFragInvalid*Reg[OLD])  (low bits)
                     bByteEnCat := r.prePayloadFrag(33 downto 2) & sgeMergedPayloadPipeInData(33 downto 2);
                     bShByteEn  := std_logic_vector(shift_right(unsigned(bByteEnCat), to_integer(unsigned(r.lastFragInvalidByteNum))));
                     bDataCat   := r.prePayloadFrag(289 downto 34) & sgeMergedPayloadPipeInData(289 downto 34);
                     bShData    := std_logic_vector(shift_right(unsigned(bDataCat), to_integer(unsigned(r.lastFragInvalidBitNum))));

                     nextPre := bShData(255 downto 0)        -- data  [289:34]
                                & bShByteEn(31 downto 0)     -- byteEn [33:2]
                                & sgeMergedPayloadPipeInData(1)  -- isFirst (kept from cur)
           & '0';                       -- isLast := 0
                  else
                     nextPre := sgeMergedPayloadPipeInData;  -- unmodified, stay
                  end if;
                  v.prePayloadFrag := nextPre;

                  if shouldOutput = '1' then
                     v.isFirstFrag  := '0';
                     -- enq first elem = prePayloadFragReg[OLD] with
                     --   isFirst:=isFirstFragReg[OLD], isLast:=0
                     outPre         := r.prePayloadFrag(289 downto 2) & r.isFirstFrag & '0';
                     fragShiftQWrEn <= '1';
                     fragShiftQDin  <= outPre  -- [594:305]
                                      & sgeMergedPayloadPipeInData  -- [304:15] curPayloadFrag (raw)
                                      & r.curInvalidByteNum         -- [14:9]
                                      & r.curInvalidBitNum;         -- [8:0]
                  end if;
               end if;

            -- ============================================================
            -- LAST_OR_ONLY_SGE_S : mergeLastOrOnlySGE
            --   Whole-rule gate (enq unconditional, OQ-FSM-MPAS-04a):
            --     fragShiftQNotFull AND (preIsLast='1' OR sgePayloadValid)
            -- ============================================================
            when LAST_OR_ONLY_SGE_S =>
               preIsLast := r.prePayloadFrag(0);

               ruleFire := '0';
               if fragShiftQFull = '0'
                  and (preIsLast = '1' or sgeMergedPayloadPipeInValid = '1') then
                  ruleFire := '1';
               end if;

               if ruleFire = '1' then
                  isLastFrag := preIsLast;  -- isLastFrag = prePayloadFragReg.isLast
                  nextFrag   := (others => '0');  -- genEmptyDataStream default

                  if preIsLast = '1' then
                     -- Branch A
                     if metaQValid = '1' and sgeMergedPayloadPipeInValid = '1' then
                        -- A1: start the next SGE (also of next SGL)
                        metaQRdEn <= '1';
                        preprocessNextSgl(v, metaQDout, sgeMergedPayloadPipeInData, retFrag, deqPayload);
                        if deqPayload = '1' then
                           sgeMergedPayloadPipeInRdEn <= '1';
                        end if;
                        nextFrag := retFrag;
                     else
                        -- A2: no next SGE yet -> wait in INIT_S (empty frag)
                        v.state := INIT_S;
                     end if;
                  else
                     -- Branch B: needs sgePayloadPipeInValid (deqs it)
                     sgeMergedPayloadPipeInRdEn <= '1';
                     nextFrag                   := sgeMergedPayloadPipeInData(289 downto 2) & '0' & sgeMergedPayloadPipeInData(0);  -- isFirst:=0
                     if r.sgeIsOnly = '0' and r.hasLessFrag = '1' and nextFrag(0) = '1' then
                        -- B1: one less fragment -> finish this SGE
                        v.state    := INIT_S;
                        isLastFrag := '1';
                     end if;
                  -- B2: isLastFrag stays preIsLast (= 0 in branch B)
                  end if;

                  v.prePayloadFrag := nextFrag;
                  -- enq first elem = prePayloadFragReg[OLD] with isLast:=isLastFrag
                  outPre           := r.prePayloadFrag(289 downto 1) & isLastFrag;
                  fragShiftQWrEn   <= '1';
                  fragShiftQDin    <= outPre              -- [594:305]
                                   & nextFrag             -- [304:15]
                                   & r.curInvalidByteNum  -- [14:9]
                                   & r.curInvalidBitNum;  -- [8:0]
               end if;

         end case;

         -------------------------------------------------------------------
         -- Stage C : shiftPayloadFrag  (state-independent consumer)
         --   guard: fragShiftQValid='1' AND pktPayloadOutQFull='0'
         --   outPayloadFrag = leftShiftAndMergeFragData(pre, cur,
         --                       truncate(lsByteNum), truncate(lsBitNum))
         -------------------------------------------------------------------
         if fragShiftQValid = '1' and pktPayloadOutQFull = '0' then
            -- Slice the 595-bit element
            cPreData   := fragShiftQDout(594 downto 339);  -- prePayloadFrag.data
            cPreByteEn := fragShiftQDout(338 downto 307);  -- prePayloadFrag.byteEn
            cCurData   := fragShiftQDout(304 downto 49);  -- curPayloadFrag.data
            cCurByteEn := fragShiftQDout(48 downto 17);  -- curPayloadFrag.byteEn
            cShByteNum := fragShiftQDout(13 downto 9);  -- truncate(leftShiftInvByteNum 6->5)
            cShBitNum  := fragShiftQDout(7 downto 0);  -- truncate(leftShiftInvBitNum 9->8)

            -- byteEn: truncateLSB({pre,cur} << shByteNum) -> top 32 of 64
            cByteEnCat := cPreByteEn & cCurByteEn;
            cShByteEn  := std_logic_vector(shift_left(unsigned(cByteEnCat), to_integer(unsigned(cShByteNum))));
            -- data: truncateLSB({pre,cur} << shBitNum) -> top 256 of 512
            cDataCat   := cPreData & cCurData;
            cShData    := std_logic_vector(shift_left(unsigned(cDataCat), to_integer(unsigned(cShBitNum))));

            -- isFirst/isLast kept from preFrag
            cOutFrag := cShData(511 downto 256)    -- data  [289:34]
                        & cShByteEn(63 downto 32)  -- byteEn [33:2]
                        & fragShiftQDout(306)  -- isFirst (prePayloadFrag.isFirst)
                        & fragShiftQDout(305);  -- isLast  (prePayloadFrag.isLast)

            fragShiftQRdEn     <= '1';
            pktPayloadOutQWrEn <= '1';
            pktPayloadOutQDin  <= cOutFrag;
         end if;

      end if;

      -- Synchronous reset (stateReg = mkReg(MERGE_SGL_PAYLOAD_INIT))
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
