-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Merges the raw payload DataStream of one Scatter/Gather Element (SGE) across
--   packet boundaries: it drops the trailing invalid bytes of each packet's last
--   fragment and shifts the next packet's first fragment up to fill them, so the
--   SGE's payload becomes a single gap-free DataStream sequence.
--
--   Two upstream PipeOut arguments are consumed (NOT FIFOs instantiated here):
--     sgePktMetaDataPipeIn : PipeOut#(PktMetaDataSGE)  (54-bit meta word)
--     sgePayloadPipeIn     : PipeOut#(DataStream)      (290-bit payload flit)
--   One output PipeOut#(DataStream) is returned (read side of U_PktPayloadOutQ).
--
--   FOUR rule groups (fsm.md §transition table):
--     resetAndClear (guard clearAllI)  — flush all 3 FIFOs, force INIT_S.
--     handleEachPktMetaData4SGE        — state-independent producer for
--                                        U_SgeCurPktMetaDataQ.
--     mergePayloadInit / mergeFirstOrMidPktSGE / mergeLastOrOnlyPktSGE —
--                                        the 3-state stateReg FSM; producer for
--                                        U_PayloadFragShiftQ.
--     shiftPayloadFrag                 — state-independent consumer of
--                                        U_PayloadFragShiftQ, producer for
--                                        U_PktPayloadOutQ.
--   The two state-independent rules can fire on the same cycle as whichever
--   state-dependent rule is active (disjoint FIFOs / registers).
--
--   Mapping note (OQ-FSM-MPES-01): mapping.json / modules.json are entirely
--     wrong for this entity (fabricated single rule `merge`, nonexistent
--     `shiftReg`/`mergeQ`, missing 2 of 3 FIFOs and 5 of 6 rules).  This file
--     follows MergePayloadEachSge.fsm.md, which is authoritative.
--
--   Width / packing resolutions applied:
--     - DataStream width = 290 bits            (OQ-FSM-H2DS-02 / MPES-02 RESOLVED)
--     - all struct/tuple packing first-field-at-MSB
--                                              (OQ-FSM-H2DS-04 / MPES-04 RESOLVED)
--
--   Atomicity / stall (OQ-FSM-MPES-03): mergeLastOrOnlyPktSGE's final
--     payloadFragShiftQ.enq is unconditional in BSV, so the WHOLE rule —
--     including the stateReg transition decided by branches A/B — fails to fire
--     when payloadFragShiftQFull='1'.  Modelled here by gating EVERY register
--     update of that rule (state, prePayloadFrag, …) on fragShiftQFull='0', not
--     merely the FIFO write-enable.  Branch B additionally requires
--     sgePayloadPipeInValid='1' (it deqs the payload pipe unconditionally).
--
--   FIFO clear (OQ-FSM-01 RESOLVED): surf.Fifo has no clear port; BSV
--     FIFOF.clear is modelled by asserting the synchronous rst.  All three
--     FIFOs share fifoRst = rst OR clearAllI (level-safe with FifoSync).
--
--   Bit layouts (BSV deriving(Bits), first-field-at-MSB):
--     DataStream (290): [289:34] data[255:0] | [33:2] byteEn[31:0] |
--                       [1] isFirst | [0] isLast
--     PktMetaDataSGE (54): [53:41] firstPktLen[12:0] | [40:28] lastPktLen[12:0] |
--                          [27:3] sgePktNum[24:0] | [2:0] pmtu[2:0]
--     sgeCurPktMetaDataQ Tuple6 (43):
--       [42:37] firstPktLastFragInvalidByteNum[5:0] |
--       [36:28] firstPktLastFragInvalidBitNum[8:0]  |
--       [27:3]  sgePktNum[24:0] | [2] sgeHasJustTwoPkts |
--       [1] sgeHasOnlyPkt | [0] hasExtraFrag
--     payloadFragShiftQ Tuple4 (595):
--       [594:305] prePayloadFrag (DataStream) | [304:15] curPayloadFrag |
--       [14:9] leftShiftInvalidByteNum[5:0] | [8:0] leftShiftInvalidBitNum[8:0]
--
--   SURF components instantiated (source: surf/base/fifo/rtl/Fifo.vhd):
--     U_PktPayloadOutQ     : surf.Fifo  DATA_WIDTH_G=290 (output queue, exposed)
--     U_SgeCurPktMetaDataQ : surf.Fifo  DATA_WIDTH_G=43  (internal pipeline)
--     U_PayloadFragShiftQ  : surf.Fifo  DATA_WIDTH_G=595 (internal pipeline)
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

entity MergePayloadEachSge is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk : in sl;
      rst : in sl;                                       -- active-high synchronous reset
      -- Software clear (BSV constructor parameter clearAll : Bool)
      clearAllI                  : in  sl;
      -- Upstream: PktMetaDataSGE pipe (sgePktMetaDataPipeIn argument)
      sgePktMetaDataPipeInValid  : in  sl;              -- sgePktMetaDataPipeIn.notEmpty
      sgePktMetaDataPipeInData   : in  slv(53 downto 0);-- sgePktMetaDataPipeIn.first
      sgePktMetaDataPipeInRdEn   : out sl;              -- sgePktMetaDataPipeIn.deq
      -- Upstream: DataStream payload pipe (sgePayloadPipeIn argument)
      sgePayloadPipeInValid      : in  sl;              -- sgePayloadPipeIn.notEmpty
      sgePayloadPipeInData       : in  slv(289 downto 0);-- sgePayloadPipeIn.first
      sgePayloadPipeInRdEn       : out sl;              -- sgePayloadPipeIn.deq
      -- Downstream: returned PipeOut#(DataStream) (read side of U_PktPayloadOutQ)
      pktPayloadOutValid         : out sl;              -- PipeOut.notEmpty
      pktPayloadOutData          : out slv(289 downto 0);-- PipeOut.first
      pktPayloadOutRdEn          : in  sl);             -- PipeOut.deq
end entity MergePayloadEachSge;

architecture rtl of MergePayloadEachSge is

   -- Maps BSV MergePayloadStateEachSGE:
   --   MERGE_SGE_PAYLOAD_INIT             -> INIT_S
   --   MERGE_SGE_PAYLOAD_FIRST_OR_MID_PKT -> FIRST_OR_MID_PKT_S
   --   MERGE_SGE_PAYLOAD_LAST_OR_ONLY_PKT -> LAST_OR_ONLY_PKT_S
   type StateType is (INIT_S, FIRST_OR_MID_PKT_S, LAST_OR_ONLY_PKT_S);

   type RegType is record
      state                         : StateType;        -- mkReg(MERGE_SGE_PAYLOAD_INIT)
      sgeFirstPktLastFragInvByteNum : slv(5 downto 0);  -- mkRegU (ByteEnBitNum)
      sgeFirstPktLastFragInvBitNum  : slv(8 downto 0);  -- mkRegU (BusBitNum)
      sgeHasOnlyPkt                 : sl;               -- mkRegU
      hasExtraFrag                  : sl;               -- mkRegU
      isFirstFrag                   : sl;               -- mkRegU
      isFirstPkt                    : sl;               -- mkRegU
      remainingPktNum               : slv(24 downto 0); -- mkRegU (PktNum)
      prePayloadFrag                : slv(289 downto 0);-- mkRegU (DataStream)
   end record RegType;

   -- All mkRegU fields set to '0' in REG_INIT_C: each is written by
   -- prepareNextSGE (the only path out of INIT_S) before any state-dependent
   -- read, so the reset value is don't-care (no correctness risk).
   constant REG_INIT_C : RegType := (
      state                         => INIT_S,
      sgeFirstPktLastFragInvByteNum => (others => '0'),
      sgeFirstPktLastFragInvBitNum  => (others => '0'),
      sgeHasOnlyPkt                 => '0',
      hasExtraFrag                  => '0',
      isFirstFrag                   => '0',
      isFirstPkt                    => '0',
      remainingPktNum               => (others => '0'),
      prePayloadFrag                => (others => '0'));

   constant DATA_BUS_BYTE_WIDTH_C : natural := 32;      -- DATA_BUS_BYTE_WIDTH

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Shared synchronous clear for all three FIFOs (rst OR clearAllI)
   signal fifoRst : sl;

   -- U_SgeCurPktMetaDataQ control / status (internal pipeline FIFO)
   signal sgeCurMetaQWrEn  : sl;
   signal sgeCurMetaQDin   : slv(42 downto 0);
   signal sgeCurMetaQRdEn  : sl;
   signal sgeCurMetaQDout  : slv(42 downto 0);
   signal sgeCurMetaQValid : sl;
   signal sgeCurMetaQFull  : sl;

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

   -- calcLastFragValidByteNum(len) (Utils.bsv:165): residue = len(4:0); if the
   -- residue is zero but len is a non-zero multiple of 32, the last fragment is
   -- "full" (32 valid bytes), else the residue is the valid byte count.
   function calcLastFragValidByteNum (len : slv(12 downto 0)) return slv is
      variable residue : slv(4 downto 0);
      variable result  : slv(5 downto 0);
   begin
      residue := len(4 downto 0);
      if (residue = "00000") and (len /= "0000000000000") then
         result := std_logic_vector(to_unsigned(DATA_BUS_BYTE_WIDTH_C, 6));  -- 32
      else
         result := '0' & residue;                                            -- zero-extend 5->6
      end if;
      return result;
   end function calcLastFragValidByteNum;

   -- prepareNextSGE (PayloadGen.bsv:994): pops sgeCurPktMetaDataQ + the payload
   -- pipe and sets up the per-SGE context registers + next stateReg.  Returns
   -- the next prePayloadFrag value through retFrag (the BSV function's
   -- ActionValue result); the caller writes prePayloadFragReg, mirroring the BSV
   -- (it does NOT write the register itself).  The pops (deq) are asserted by the
   -- caller, not here.
   procedure prepareNextSGE (
      variable v           : inout RegType;
      signal   metaQDout   : in    slv(42 downto 0);
      signal   payloadData : in    slv(289 downto 0);
      variable retFrag     : out   slv(289 downto 0)) is
      variable invByteNumIn : slv(5 downto 0);
      variable invBitNumIn  : slv(8 downto 0);
      variable pktNumIn     : slv(24 downto 0);
      variable hasJustTwoIn : sl;
      variable hasOnlyIn    : sl;
      variable curIsLast    : sl;
      variable shiftedFrag  : slv(289 downto 0);
   begin
      invByteNumIn := metaQDout(42 downto 37);
      invBitNumIn  := metaQDout(36 downto 28);
      pktNumIn     := metaQDout(27 downto 3);
      hasJustTwoIn := metaQDout(2);
      hasOnlyIn    := metaQDout(1);
      curIsLast    := payloadData(0);

      -- Single-fragment first-packet shift: drop the invalid trailing bytes of
      -- the first packet's last fragment.  isLast forced to 0, isFirst kept.
      shiftedFrag :=
           std_logic_vector(shift_right(unsigned(payloadData(289 downto 34)), to_integer(unsigned(invBitNumIn))))  -- data >> invBitNum
         & std_logic_vector(shift_right(unsigned(payloadData(33 downto 2)),  to_integer(unsigned(invByteNumIn)))) -- byteEn >> invByteNum
         & payloadData(1)                                                                                          -- isFirst (unchanged)
         & '0';                                                                                                    -- isLast := 0

      -- Common register updates for every branch
      v.sgeHasOnlyPkt                 := hasOnlyIn;
      v.hasExtraFrag                  := metaQDout(0);
      v.sgeFirstPktLastFragInvByteNum := invByteNumIn;
      v.sgeFirstPktLastFragInvBitNum  := invBitNumIn;
      v.isFirstFrag                   := '1';

      if hasOnlyIn = '1' then                                  -- P1: only one packet in SGE
         v.state           := LAST_OR_ONLY_PKT_S;
         v.remainingPktNum := (others => '0');
         v.isFirstPkt      := '1';
         retFrag           := payloadData;                     -- unmodified
      elsif curIsLast = '1' then                               -- single-fragment first packet
         retFrag      := shiftedFrag;
         v.isFirstPkt := '0';
         if hasJustTwoIn = '1' then                            -- P2: exactly two packets
            v.state           := LAST_OR_ONLY_PKT_S;
            v.remainingPktNum := (others => '0');
         else                                                  -- P3: more than two packets
            v.state           := FIRST_OR_MID_PKT_S;
            v.remainingPktNum := std_logic_vector(unsigned(pktNumIn) - 2);
         end if;
      else                                                     -- P4: multi-fragment first packet
         v.state           := FIRST_OR_MID_PKT_S;
         v.remainingPktNum := std_logic_vector(unsigned(pktNumIn) - 1);
         v.isFirstPkt      := '1';
         retFrag           := payloadData;                     -- unmodified
      end if;
   end procedure prepareNextSGE;

begin

   -- FIFO reset: level-sensitive synchronous clear (OQ-FSM-01 RESOLVED).
   -- resetAndClear calls .clear on all three FIFOs while clearAllI='1'.
   fifoRst <= rst or clearAllI;

   ---------------------------------------------------------------------------
   -- U_SgeCurPktMetaDataQ : surf.Fifo
   --   Internal pipeline FIFO; produced by handleEachPktMetaData4SGE, consumed
   --   by prepareNextSGE.  DATA_WIDTH_G=43, FWFT, sync, distributed RAM.
   ---------------------------------------------------------------------------
   U_SgeCurPktMetaDataQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 43,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoRst,
         wr_clk        => clk,
         wr_en         => sgeCurMetaQWrEn,
         din           => sgeCurMetaQDin,
         full          => sgeCurMetaQFull,
         not_full      => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => sgeCurMetaQRdEn,
         dout          => sgeCurMetaQDout,
         valid         => sgeCurMetaQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_PayloadFragShiftQ : surf.Fifo
   --   Internal pipeline FIFO; produced by mergeFirstOrMidPktSGE /
   --   mergeLastOrOnlyPktSGE, consumed by shiftPayloadFrag.
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
   --   Produced by shiftPayloadFrag.  DATA_WIDTH_G=290, FWFT, sync, distributed RAM.
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
                   sgePktMetaDataPipeInValid, sgePktMetaDataPipeInData,
                   sgePayloadPipeInValid, sgePayloadPipeInData,
                   sgeCurMetaQValid, sgeCurMetaQDout, sgeCurMetaQFull,
                   fragShiftQValid, fragShiftQDout, fragShiftQFull,
                   pktPayloadOutQFull) is
      variable v : RegType;

      -- handleEachPktMetaData4SGE locals
      variable firstPktLen   : slv(12 downto 0);
      variable lastPktLen    : slv(12 downto 0);
      variable metaPktNum    : slv(24 downto 0);
      variable firstValid    : slv(5 downto 0);
      variable lastValid     : slv(5 downto 0);
      variable firstInvByte  : slv(5 downto 0);
      variable firstInvBit   : slv(8 downto 0);
      variable hasJustTwoPkts : sl;
      variable metaHasOnlyPkt : sl;
      variable metaHasExtra   : sl;

      -- main-FSM locals
      variable retFrag        : slv(289 downto 0);
      variable nextFrag       : slv(289 downto 0);
      variable nextPre        : slv(289 downto 0);
      variable preFragWIsFirst : slv(289 downto 0);
      variable preFragWIsLast  : slv(289 downto 0);
      variable curIsLast      : sl;
      variable preIsLast      : sl;
      variable isLastFrag     : sl;
      variable fire           : sl;
      variable lsByteNum      : slv(5 downto 0);
      variable lsBitNum       : slv(8 downto 0);

      -- shiftPayloadFrag (leftShiftAndMergeFragData) locals
      variable sPreData    : slv(255 downto 0);
      variable sCurData    : slv(255 downto 0);
      variable sPreByteEn  : slv(31 downto 0);
      variable sCurByteEn  : slv(31 downto 0);
      variable sShByteNum  : slv(4 downto 0);   -- truncate(6->5) ShiftByteNum
      variable sShBitNum   : slv(7 downto 0);   -- truncate(9->8) ShiftBitNum
      variable byteEnCat   : slv(63 downto 0);
      variable dataCat     : slv(511 downto 0);
      variable shByteEn    : slv(63 downto 0);
      variable shData      : slv(511 downto 0);
      variable outFrag     : slv(289 downto 0);
   begin
      v := r;

      -- default Mealy outputs (deasserted; overridden below per transition)
      sgePktMetaDataPipeInRdEn <= '0';
      sgePayloadPipeInRdEn     <= '0';
      sgeCurMetaQWrEn          <= '0';
      sgeCurMetaQDin           <= (others => '0');
      sgeCurMetaQRdEn          <= '0';
      fragShiftQWrEn           <= '0';
      fragShiftQDin            <= (others => '0');
      fragShiftQRdEn           <= '0';
      pktPayloadOutQWrEn       <= '0';
      pktPayloadOutQDin        <= (others => '0');

      if clearAllI = '1' then
         -- resetAndClear: FIFOs flushed via fifoRst; stateReg forced to INIT_S.
         -- The 8 mkRegU context registers are deliberately untouched (matches
         -- BSV; they are rewritten by the next prepareNextSGE before any read).
         v.state := INIT_S;

      else

         -------------------------------------------------------------------
         -- handleEachPktMetaData4SGE (state-independent producer)
         --   guard: sgePktMetaDataPipeInValid='1' AND sgeCurMetaQFull='0'
         -------------------------------------------------------------------
         if sgePktMetaDataPipeInValid = '1' and sgeCurMetaQFull = '0' then
            firstPktLen := sgePktMetaDataPipeInData(53 downto 41);
            lastPktLen  := sgePktMetaDataPipeInData(40 downto 28);
            metaPktNum  := sgePktMetaDataPipeInData(27 downto 3);

            firstValid := calcLastFragValidByteNum(firstPktLen);
            lastValid  := calcLastFragValidByteNum(lastPktLen);

            -- calcFragBitNumAndByteNum(firstValid): invalidByteNum = 32 - valid,
            --   invalidBitNum = invalidByteNum << 3.
            firstInvByte := std_logic_vector(to_unsigned(DATA_BUS_BYTE_WIDTH_C, 6) - unsigned(firstValid));
            firstInvBit  := firstInvByte & "000";

            hasJustTwoPkts := ite(unsigned(metaPktNum) = 2, '1', '0');
            metaHasOnlyPkt := ite(unsigned(metaPktNum) <= 1, '1', '0');
            metaHasExtra   := ite(unsigned(lastValid) > unsigned(firstInvByte), '1', '0');

            sgePktMetaDataPipeInRdEn <= '1';
            sgeCurMetaQWrEn          <= '1';
            sgeCurMetaQDin           <= firstInvByte      -- [42:37]
                                      & firstInvBit       -- [36:28]
                                      & metaPktNum        -- [27:3]
                                      & hasJustTwoPkts    -- [2]
                                      & metaHasOnlyPkt    -- [1]
                                      & metaHasExtra;     -- [0]
         end if;

         -------------------------------------------------------------------
         -- Main 3-state FSM (mergePayloadInit / mergeFirstOrMidPktSGE /
         --                   mergeLastOrOnlyPktSGE)
         -------------------------------------------------------------------
         case r.state is

            -- ============================================================
            -- INIT_S: mergePayloadInit
            --   implicit cond: sgeCurMetaQValid='1' AND sgePayloadPipeInValid='1'
            -- ============================================================
            when INIT_S =>
               if sgeCurMetaQValid = '1' and sgePayloadPipeInValid = '1' then
                  sgeCurMetaQRdEn      <= '1';
                  sgePayloadPipeInRdEn <= '1';
                  prepareNextSGE(v, sgeCurMetaQDout, sgePayloadPipeInData, retFrag);
                  v.prePayloadFrag := retFrag;
               end if;

            -- ============================================================
            -- FIRST_OR_MID_PKT_S: mergeFirstOrMidPktSGE
            --   implicit cond: sgePayloadPipeInValid='1' AND fragShiftQFull='0'
            --   All register reads below are OLD (r) values (BSV semantics).
            -- ============================================================
            when FIRST_OR_MID_PKT_S =>
               if sgePayloadPipeInValid = '1' and fragShiftQFull = '0' then
                  sgePayloadPipeInRdEn <= '1';
                  curIsLast := sgePayloadPipeInData(0);

                  -- nextPrePayloadFrag computation (BSV lines 1109-1126)
                  if curIsLast = '0' then
                     nextPre := sgePayloadPipeInData;            -- unmodified, stay
                  else
                     if r.isFirstPkt = '1' then
                        -- first packet's last fragment: drop invalid trailing
                        -- bytes (right shift), force isLast=0; isFirstPkt -> 0
                        v.isFirstPkt := '0';
                        nextPre :=
                             std_logic_vector(shift_right(unsigned(sgePayloadPipeInData(289 downto 34)), to_integer(unsigned(r.sgeFirstPktLastFragInvBitNum))))
                           & std_logic_vector(shift_right(unsigned(sgePayloadPipeInData(33 downto 2)),  to_integer(unsigned(r.sgeFirstPktLastFragInvByteNum))))
                           & sgePayloadPipeInData(1)
                           & '0';
                     else
                        nextPre := sgePayloadPipeInData(289 downto 1) & '0';  -- isLast := 0 only
                     end if;
                     if unsigned(r.remainingPktNum) <= 1 then
                        v.state := LAST_OR_ONLY_PKT_S;
                     end if;
                     v.remainingPktNum := std_logic_vector(unsigned(r.remainingPktNum) - 1);
                  end if;
                  v.prePayloadFrag := nextPre;

                  -- payloadFragShiftQ.enq (BSV lines 1137-1151)
                  --   first elem = prePayloadFragReg[old] with isFirst:=isFirstFragReg[old]
                  --   second elem = curPayloadFrag (raw, unmodified)
                  --   leftShift = (!isFirstPktReg[old]) ? invByteNum/BitNum[old] : 0
                  preFragWIsFirst := r.prePayloadFrag(289 downto 2) & r.isFirstFrag & r.prePayloadFrag(0);
                  v.isFirstFrag   := '0';
                  if r.isFirstPkt = '0' then
                     lsByteNum := r.sgeFirstPktLastFragInvByteNum;
                     lsBitNum  := r.sgeFirstPktLastFragInvBitNum;
                  else
                     lsByteNum := (others => '0');
                     lsBitNum  := (others => '0');
                  end if;
                  fragShiftQWrEn <= '1';
                  fragShiftQDin  <= preFragWIsFirst        -- [594:305]
                                  & sgePayloadPipeInData    -- [304:15]
                                  & lsByteNum               -- [14:9]
                                  & lsBitNum;               -- [8:0]
               end if;

            -- ============================================================
            -- LAST_OR_ONLY_PKT_S: mergeLastOrOnlyPktSGE
            --   Branch selector = prePayloadFragReg.isLast (OLD).  The WHOLE
            --   rule (incl. stateReg) is gated on fragShiftQFull='0'
            --   (OQ-FSM-MPES-03); Branch B additionally needs the payload pipe.
            -- ============================================================
            when LAST_OR_ONLY_PKT_S =>
               preIsLast  := r.prePayloadFrag(0);
               isLastFrag := preIsLast;                 -- BSV: isLastFrag = prePayloadFragReg.isLast
               nextFrag   := (others => '0');           -- BSV: nextPayloadFrag = genEmptyDataStream
               fire       := '0';

               if preIsLast = '1' then
                  -- Branch A: fires whenever fragShiftQFull='0' (A1 or A2)
                  if fragShiftQFull = '0' then
                     fire := '1';
                     if sgeCurMetaQValid = '1' and sgePayloadPipeInValid = '1' then
                        -- A1: start the next SGE
                        sgeCurMetaQRdEn      <= '1';
                        sgePayloadPipeInRdEn <= '1';
                        prepareNextSGE(v, sgeCurMetaQDout, sgePayloadPipeInData, retFrag);
                        nextFrag := retFrag;
                     else
                        -- A2: no next SGE yet -> wait in INIT_S (empty frag)
                        v.state := INIT_S;
                     end if;
                  end if;
               else
                  -- Branch B: needs sgePayloadPipeInValid (deqs it) AND room
                  if sgePayloadPipeInValid = '1' and fragShiftQFull = '0' then
                     fire := '1';
                     sgePayloadPipeInRdEn <= '1';
                     -- nextPayloadFrag = sgePayloadPipeIn.first, isFirst forced 0
                     nextFrag := sgePayloadPipeInData(289 downto 2) & '0' & sgePayloadPipeInData(0);
                     if r.sgeHasOnlyPkt = '0' and r.hasExtraFrag = '0' and nextFrag(0) = '1' then
                        -- B1: no extra fragment -> finish this SGE
                        v.state    := INIT_S;
                        isLastFrag := '1';
                     else
                        -- B2: more fragments to come
                        isLastFrag := '0';
                     end if;
                  end if;
               end if;

               -- Common tail (BSV lines 1189-1215): only when the rule fires.
               if fire = '1' then
                  v.prePayloadFrag := nextFrag;
                  -- enq first elem = prePayloadFragReg[old] with isLast:=isLastFrag
                  preFragWIsLast := r.prePayloadFrag(289 downto 1) & isLastFrag;
                  -- leftShift = (!sgeHasOnlyPktReg[old]) ? invByteNum/BitNum[old] : 0
                  if r.sgeHasOnlyPkt = '0' then
                     lsByteNum := r.sgeFirstPktLastFragInvByteNum;
                     lsBitNum  := r.sgeFirstPktLastFragInvBitNum;
                  else
                     lsByteNum := (others => '0');
                     lsBitNum  := (others => '0');
                  end if;
                  fragShiftQWrEn <= '1';
                  fragShiftQDin  <= preFragWIsLast    -- [594:305]
                                  & nextFrag          -- [304:15]
                                  & lsByteNum         -- [14:9]
                                  & lsBitNum;         -- [8:0]
               end if;

         end case;

         -------------------------------------------------------------------
         -- shiftPayloadFrag (state-independent consumer)
         --   guard: fragShiftQValid='1' AND pktPayloadOutQFull='0'
         --   outPayloadFrag = leftShiftAndMergeFragData(pre, cur,
         --                       truncate(lsByteNum), truncate(lsBitNum))
         -------------------------------------------------------------------
         if fragShiftQValid = '1' and pktPayloadOutQFull = '0' then
            -- Slice the 595-bit element
            sPreData   := fragShiftQDout(594 downto 339);  -- prePayloadFrag.data
            sPreByteEn := fragShiftQDout(338 downto 307);  -- prePayloadFrag.byteEn
            sCurData   := fragShiftQDout(304 downto  49);  -- curPayloadFrag.data
            sCurByteEn := fragShiftQDout( 48 downto  17);  -- curPayloadFrag.byteEn
            sShByteNum := fragShiftQDout(13 downto 9);      -- truncate(leftShiftInvByteNum 6->5)
            sShBitNum  := fragShiftQDout( 7 downto 0);      -- truncate(leftShiftInvBitNum 9->8)

            -- byteEn: truncateLSB({pre,cur} << shByteNum) -> top 32 of 64
            byteEnCat := sPreByteEn & sCurByteEn;
            shByteEn  := std_logic_vector(shift_left(unsigned(byteEnCat), to_integer(unsigned(sShByteNum))));
            -- data: truncateLSB({pre,cur} << shBitNum) -> top 256 of 512
            dataCat := sPreData & sCurData;
            shData  := std_logic_vector(shift_left(unsigned(dataCat), to_integer(unsigned(sShBitNum))));

            -- isFirst/isLast kept from preFrag
            outFrag := shData(511 downto 256)              -- data  [289:34]
                     & shByteEn(63 downto 32)              -- byteEn [33:2]
                     & fragShiftQDout(306)                 -- isFirst (prePayloadFrag.isFirst)
                     & fragShiftQDout(305);                -- isLast  (prePayloadFrag.isLast)

            fragShiftQRdEn     <= '1';
            pktPayloadOutQWrEn <= '1';
            pktPayloadOutQDin  <= outFrag;
         end if;

      end if;

      -- Synchronous reset (stateReg = mkReg(MERGE_SGE_PAYLOAD_INIT))
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

   ---------------------------------------------------------------------------
   -- Simulation-only assertions (sim-only immAssert calls, no synth effect):
   --   mergeFirstOrMidPktSGE: remainingPktNumReg /= 0 when the rule fires.
   --   mergeLastOrOnlyPktSGE: remainingPktNumReg  = 0 when the rule fires.
   ---------------------------------------------------------------------------
   -- pragma translate_off
   check : process (clk) is
   begin
      if rising_edge(clk) then
         if rst = '0' and clearAllI = '0' then
            if (r.state = FIRST_OR_MID_PKT_S
                and sgePayloadPipeInValid = '1' and fragShiftQFull = '0') then
               assert unsigned(r.remainingPktNum) /= 0
                  report "MergePayloadEachSge: remainingPktNum must be > 0 in FIRST_OR_MID_PKT_S"
                  severity error;
            end if;
            if (r.state = LAST_OR_ONLY_PKT_S) then
               assert unsigned(r.remainingPktNum) = 0
                  report "MergePayloadEachSge: remainingPktNum must be 0 in LAST_OR_ONLY_PKT_S"
                  severity error;
            end if;
         end if;
      end if;
   end process check;
   -- pragma translate_on

end architecture rtl;
