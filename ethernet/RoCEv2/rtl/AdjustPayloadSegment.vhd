-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Re-segments an SGL's merged payload DataStream into PMTU-sized packets: it
--   left-shifts each packet's fragments to absorb the trailing invalid bytes of
--   the first packet's last fragment, and re-flags isFirst/isLast on packet
--   boundaries so every adjusted packet is a contiguous DataStream run.
--
--   Structural twin of MergePayloadEachSge (same file): a 3-state stateReg
--   control FSM between a stateless input-side producer (handleMetaDataEachSGL,
--   fills U_SglAdjustedPktMetaDataQ) and a stateless output-side consumer
--   (shiftPayloadFrag, drains U_PayloadFragShiftQ -> U_PktPayloadOutQ).  All
--   conventions resolved there are reused here.
--
--   Two upstream PipeOut arguments are consumed (NOT FIFOs instantiated here):
--     adjustedTotalPayloadMetaDataPipeIn : PipeOut#(AdjustedTotalPayloadMetaData)
--                                          (61-bit meta word)
--     sglAllPayloadPipeIn                : PipeOut#(DataStream) (290-bit flit)
--   One output PipeOut#(DataStream) is returned (read side of U_PktPayloadOutQ).
--
--   SIX rules (fsm.md §transition table):
--     resetAndClear (guard clearAllI) — flush all 3 FIFOs, force INIT_S.
--     handleMetaDataEachSGL           — state-independent producer for
--                                       U_SglAdjustedPktMetaDataQ.
--     adjustPayloadInit / adjustFirstOrMidPkt / adjustLastOrOnlyPkt —
--                                       the 3-state stateReg FSM; producer for
--                                       U_PayloadFragShiftQ.
--     shiftPayloadFrag                — state-independent consumer of
--                                       U_PayloadFragShiftQ, producer for
--                                       U_PktPayloadOutQ.
--   The two state-independent rules can fire on the same cycle as whichever
--   state-dependent rule is active (disjoint FIFOs / registers, opposite ends).
--
--   Mapping note (OQ-FSM-APS-01): mapping.json / modules.json `owns.state` lists
--     non-existent regs (shiftAmtReg/firstFragLenReg/lastFragLenReg) and omits
--     the 11 real mkRegU context regs; `new_ports:[]` omits the used clearAll
--     constructor parameter; SURF widths use the stale DataStream=321.  This file
--     follows AdjustPayloadSegment.fsm.md, which is authoritative.
--
--   Width / packing resolutions applied:
--     - DataStream width = 290 bits           (OQ-FSM-H2DS-02 / APS-02 RESOLVED)
--     - all struct/tuple packing first-field-at-MSB
--                                             (OQ-FSM-H2DS-04 / APS-02 RESOLVED)
--
--   Atomicity / stall: every adjust* rule's payloadFragShiftQ.enq is
--     unconditional in BSV, so the WHOLE rule — including the stateReg transition
--     — fails to fire when fragShiftQFull='1'.  Modelled by gating EVERY register
--     update of those rules on fragShiftQFull='0' (the `fire` variable), not just
--     the FIFO write-enable.  The non-prePayloadFragReg.isLast branches
--     additionally require sglAllPayloadPipeInValid='1' (they deq the payload
--     pipe).  Same shape as MergePayloadEachSge (OQ-FSM-MPES-03).
--
--   FIFO clear (OQ-FSM-01 RESOLVED): surf.Fifo has no clear port; BSV
--     FIFOF.clear is modelled by asserting the synchronous rst.  All three FIFOs
--     share fifoRst = rst OR clearAllI.
--
--   Bit layouts (BSV deriving(Bits), first-field-at-MSB):
--     DataStream (290): [289:34] data[255:0] | [33:2] byteEn[31:0] |
--                       [1] isFirst | [0] isLast
--     AdjustedTotalPayloadMetaData (61):
--       [60:48] firstPktLen[12:0] | [47:40] firstPktFragNum[7:0] |
--       [39:34] firstPktLastFragValidByteNum[5:0] |
--       [33:28] origLastFragValidByteNum[5:0] | [27:3] adjustedPktNum[24:0] |
--       [2:0] pmtu[2:0]
--     sglAdjustedPktMetaDataQ Tuple8 (54):
--       [53:51] pmtu[2:0] | [50:43] firstPktFragNum[7:0] |
--       [42:18] adjustedPktNum[24:0] |
--       [17:12] firstPktLastFragValidByteNum[5:0] |
--       [11:3] firstPktLastFragValidBitNum[8:0] | [2] sglHasOnlyPkt |
--       [1] hasExtraFrag | [0] noShiftFrag
--     payloadFragShiftQ Tuple6 (628):
--       [627:338] prePayloadFrag (DataStream) | [337:48] curPayloadFrag |
--       [47:42] leftShiftValidByteNum[5:0] | [41:33] leftShiftValidBitNum[8:0] |
--       [32] shouldChangeByteEn | [31:0] firstPktLastFragByteEn[31:0]
--
--   SURF components instantiated (source: surf/base/fifo/rtl/Fifo.vhd):
--     U_PktPayloadOutQ          : surf.Fifo  DATA_WIDTH_G=290 (output, exposed)
--     U_SglAdjustedPktMetaDataQ : surf.Fifo  DATA_WIDTH_G=54  (internal pipeline)
--     U_PayloadFragShiftQ       : surf.Fifo  DATA_WIDTH_G=628 (internal pipeline)
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

entity AdjustPayloadSegment is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk                      : in  sl;
      rst                      : in  sl;  -- active-high synchronous reset
      -- Software clear (BSV constructor parameter clearAll : Bool)
      clearAllI                : in  sl;
      -- Upstream: AdjustedTotalPayloadMetaData pipe (adjustedTotalPayloadMetaDataPipeIn)
      adjustedMetaPipeInValid  : in  sl;  -- .notEmpty
      adjustedMetaPipeInData   : in  slv(60 downto 0);   -- .first
      adjustedMetaPipeInRdEn   : out sl;  -- .deq
      -- Upstream: DataStream payload pipe (sglAllPayloadPipeIn argument)
      sglAllPayloadPipeInValid : in  sl;  -- .notEmpty
      sglAllPayloadPipeInData  : in  slv(289 downto 0);  -- .first
      sglAllPayloadPipeInRdEn  : out sl;  -- .deq
      -- Downstream: returned PipeOut#(DataStream) (read side of U_PktPayloadOutQ)
      pktPayloadOutValid       : out sl;  -- PipeOut.notEmpty
      pktPayloadOutData        : out slv(289 downto 0);  -- PipeOut.first
      pktPayloadOutRdEn        : in  sl);                -- PipeOut.deq
end entity AdjustPayloadSegment;

architecture rtl of AdjustPayloadSegment is

   -- Maps BSV AdjustPayloadSegmentState:
   --   ADJUST_PAYLOAD_SEGMENT_INIT             -> INIT_S
   --   ADJUST_PAYLOAD_SEGMENT_FIRST_OR_MID_PKT -> FIRST_OR_MID_PKT_S
   --   ADJUST_PAYLOAD_SEGMENT_LAST_OR_ONLY_PKT -> LAST_OR_ONLY_PKT_S
   type StateType is (INIT_S, FIRST_OR_MID_PKT_S, LAST_OR_ONLY_PKT_S);

   type RegType is record
      state                        : StateType;  -- mkReg(ADJUST_PAYLOAD_SEGMENT_INIT)
      prePayloadFrag               : slv(289 downto 0);  -- mkRegU (DataStream)
      firstPktLastFragByteEn       : slv(31 downto 0);   -- mkRegU (ByteEn)
      firstPktLastFragValidByteNum : slv(5 downto 0);  -- mkRegU (ByteEnBitNum)
      firstPktLastFragValidBitNum  : slv(8 downto 0);  -- mkRegU (BusBitNum)
      isFirstPkt                   : sl;         -- mkRegU
      hasExtraFrag                 : sl;         -- mkRegU
      sglHasOnlyPkt                : sl;         -- mkRegU
      noShiftFrag                  : sl;         -- mkRegU
      pmtuFragNum                  : slv(7 downto 0);  -- mkRegU (PktFragNum)
      pktRemainingFragNum          : slv(7 downto 0);  -- mkRegU (PktFragNum)
      sglRemainingPktNum           : slv(24 downto 0);   -- mkRegU (PktNum)
   end record RegType;

   -- All mkRegU fields set to '0' in REG_INIT_C: each is written by prepareNextSgl
   -- (the only path out of INIT_S) before any state-dependent read, so the reset
   -- value is don't-care (no correctness risk).
   constant REG_INIT_C : RegType := (
      state                        => INIT_S,
      prePayloadFrag               => (others => '0'),
      firstPktLastFragByteEn       => (others => '0'),
      firstPktLastFragValidByteNum => (others => '0'),
      firstPktLastFragValidBitNum  => (others => '0'),
      isFirstPkt                   => '0',
      hasExtraFrag                 => '0',
      sglHasOnlyPkt                => '0',
      noShiftFrag                  => '0',
      pmtuFragNum                  => (others => '0'),
      pktRemainingFragNum          => (others => '0'),
      sglRemainingPktNum           => (others => '0'));

   constant DATA_BUS_BYTE_WIDTH_C : natural := 32;  -- DATA_BUS_BYTE_WIDTH

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Shared synchronous clear for all three FIFOs (rst OR clearAllI)
   signal fifoRst : sl;

   -- U_SglAdjustedPktMetaDataQ control / status (internal pipeline FIFO)
   signal sglMetaQWrEn  : sl;
   signal sglMetaQDin   : slv(53 downto 0);
   signal sglMetaQRdEn  : sl;
   signal sglMetaQDout  : slv(53 downto 0);
   signal sglMetaQValid : sl;
   signal sglMetaQFull  : sl;

   -- U_PayloadFragShiftQ control / status (internal pipeline FIFO)
   signal fragShiftQWrEn  : sl;
   signal fragShiftQDin   : slv(627 downto 0);
   signal fragShiftQRdEn  : sl;
   signal fragShiftQDout  : slv(627 downto 0);
   signal fragShiftQValid : sl;
   signal fragShiftQFull  : sl;

   -- U_PktPayloadOutQ control / status (output queue; read side exposed)
   signal pktPayloadOutQWrEn : sl;
   signal pktPayloadOutQDin  : slv(289 downto 0);
   signal pktPayloadOutQFull : sl;

   -- genByteEn(n) (Utils.bsv:161): reverseBits((1<<n)-1) => left-aligned mask with
   -- the top n byteEn bits set.  Identical to shifting an all-ones word left by
   -- (32-n) (top n bits survive; n=0 -> 0, n=32 -> all ones).
   function genByteEn (n : slv(5 downto 0)) return slv is
      variable ones     : slv(31 downto 0);
      variable shiftAmt : natural;
   begin
      ones     := (others => '1');
      shiftAmt := DATA_BUS_BYTE_WIDTH_C - to_integer(unsigned(n));
      return std_logic_vector(shift_left(unsigned(ones), shiftAmt));
   end function genByteEn;

   -- calcFragNumByPMTU(pmtu) (Utils.bsv:268): 1 << (getPmtuLogValue(pmtu) -
   -- log2(DATA_BUS_BYTE_WIDTH=32)=5).  PMTU enum 256/512/1024/2048/4096 ->
   -- fragments/packet 8/16/32/64/128.
   function calcFragNumByPMTU (pmtu : slv(2 downto 0)) return slv is
      variable res : slv(7 downto 0);
   begin
      case pmtu is
         when "001"  => res := std_logic_vector(to_unsigned(8, 8));  -- IBV_MTU_256
         when "010"  => res := std_logic_vector(to_unsigned(16, 8));  -- IBV_MTU_512
         when "011"  => res := std_logic_vector(to_unsigned(32, 8));  -- IBV_MTU_1024
         when "100"  => res := std_logic_vector(to_unsigned(64, 8));  -- IBV_MTU_2048
         when others => res := std_logic_vector(to_unsigned(128, 8));  -- IBV_MTU_4096 ("101")
      end case;
      return res;
   end function calcFragNumByPMTU;

   -- prepareNextSgl (PayloadGen.bsv:1668): pops sglAdjustedPktMetaDataQ + the
   -- payload pipe and sets up the per-SGL context registers + next stateReg.
   -- Returns the next prePayloadFrag value through retFrag (the BSV function's
   -- ActionValue result); the caller writes prePayloadFragReg, mirroring the BSV
   -- (it does NOT write that register itself).  The pops (deq) are asserted by the
   -- caller, not here.
   procedure prepareNextSgl (
      variable v         : inout RegType;
      signal metaQDout   : in    slv(53 downto 0);
      signal payloadData : in    slv(289 downto 0);
      variable retFrag   : out   slv(289 downto 0)) is
      variable pmtuV      : slv(2 downto 0);
      variable firstFragN : slv(7 downto 0);
      variable pktNumV    : slv(24 downto 0);
      variable validByteN : slv(5 downto 0);
      variable validBitN  : slv(8 downto 0);
      variable hasOnlyV   : sl;
      variable hasExtraV  : sl;
      variable noShiftV   : sl;
   begin
      pmtuV      := metaQDout(53 downto 51);
      firstFragN := metaQDout(50 downto 43);
      pktNumV    := metaQDout(42 downto 18);
      validByteN := metaQDout(17 downto 12);
      validBitN  := metaQDout(11 downto 3);
      hasOnlyV   := metaQDout(2);
      hasExtraV  := metaQDout(1);
      noShiftV   := metaQDout(0);

      v.pmtuFragNum                  := calcFragNumByPMTU(pmtuV);
      v.pktRemainingFragNum          := firstFragN;
      v.sglRemainingPktNum           := pktNumV;
      v.firstPktLastFragValidByteNum := validByteN;
      v.firstPktLastFragValidBitNum  := validBitN;
      v.firstPktLastFragByteEn       := genByteEn(validByteN);
      v.isFirstPkt                   := '1';
      v.hasExtraFrag                 := hasExtraV;
      v.sglHasOnlyPkt                := hasOnlyV;
      v.noShiftFrag                  := noShiftV;

      if hasOnlyV = '1' then
         v.state := LAST_OR_ONLY_PKT_S;
      else
         v.state := FIRST_OR_MID_PKT_S;
      end if;

      retFrag := payloadData;           -- curPayloadFrag (unmodified)
   end procedure prepareNextSgl;

begin

   -- FIFO reset: level-sensitive synchronous clear (OQ-FSM-01 RESOLVED).
   -- resetAndClear calls .clear on all three FIFOs while clearAllI='1'.
   fifoRst <= rst or clearAllI;

   ---------------------------------------------------------------------------
   -- U_SglAdjustedPktMetaDataQ : surf.Fifo
   --   Internal pipeline FIFO; produced by handleMetaDataEachSGL, consumed by
   --   prepareNextSgl.  DATA_WIDTH_G=54, FWFT, sync, distributed RAM.
   ---------------------------------------------------------------------------
   U_SglAdjustedPktMetaDataQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 54,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoRst,
         wr_clk        => clk,
         wr_en         => sglMetaQWrEn,
         din           => sglMetaQDin,
         full          => sglMetaQFull,
         not_full      => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => sglMetaQRdEn,
         dout          => sglMetaQDout,
         valid         => sglMetaQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_PayloadFragShiftQ : surf.Fifo
   --   Internal pipeline FIFO; produced by adjustFirstOrMidPkt /
   --   adjustLastOrOnlyPkt, consumed by shiftPayloadFrag.
   --   DATA_WIDTH_G=628, FWFT, sync, distributed RAM (wide word).
   ---------------------------------------------------------------------------
   U_PayloadFragShiftQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 628,
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
                   adjustedMetaPipeInValid, adjustedMetaPipeInData,
                   sglAllPayloadPipeInValid, sglAllPayloadPipeInData,
                   sglMetaQValid, sglMetaQDout, sglMetaQFull,
                   fragShiftQValid, fragShiftQDout, fragShiftQFull,
                   pktPayloadOutQFull) is
      variable v : RegType;

      -- handleMetaDataEachSGL locals
      variable mFirstPktFragNum  : slv(7 downto 0);
      variable mValidByteNum     : slv(5 downto 0);
      variable mOrigValidByteNum : slv(5 downto 0);
      variable mPktNum           : slv(24 downto 0);
      variable mPmtu             : slv(2 downto 0);
      variable mValidBitNum      : slv(8 downto 0);
      variable mHasOnly          : sl;
      variable mHasExtra         : sl;
      variable mNoShift          : sl;

      -- main-FSM locals
      variable preIsLast         : sl;
      variable isAdjLastFrag     : sl;
      variable isFirstPktAdjLast : sl;
      variable shouldShift       : sl;
      variable shouldChgByteEn   : sl;
      variable isLastFrag        : sl;
      variable fire              : sl;
      variable curFrag           : slv(289 downto 0);
      variable nextFrag          : slv(289 downto 0);
      variable preFragWLast      : slv(289 downto 0);
      variable retFrag           : slv(289 downto 0);
      variable lsByteNum         : slv(5 downto 0);
      variable lsBitNum          : slv(8 downto 0);

      -- shiftPayloadFrag (leftShiftAndMergeFragData) locals
      variable sPreData   : slv(255 downto 0);
      variable sCurData   : slv(255 downto 0);
      variable sPreByteEn : slv(31 downto 0);
      variable sCurByteEn : slv(31 downto 0);
      variable sShByteNum : slv(4 downto 0);  -- truncate(6->5) ShiftByteNum
      variable sShBitNum  : slv(7 downto 0);  -- truncate(9->8) ShiftBitNum
      variable byteEnCat  : slv(63 downto 0);
      variable dataCat    : slv(511 downto 0);
      variable shByteEn   : slv(63 downto 0);
      variable shData     : slv(511 downto 0);
      variable outFrag    : slv(289 downto 0);
   begin
      v := r;

      -- default Mealy outputs (deasserted; overridden below per transition)
      adjustedMetaPipeInRdEn  <= '0';
      sglAllPayloadPipeInRdEn <= '0';
      sglMetaQWrEn            <= '0';
      sglMetaQDin             <= (others => '0');
      sglMetaQRdEn            <= '0';
      fragShiftQWrEn          <= '0';
      fragShiftQDin           <= (others => '0');
      fragShiftQRdEn          <= '0';
      pktPayloadOutQWrEn      <= '0';
      pktPayloadOutQDin       <= (others => '0');

      if clearAllI = '1' then
         -- resetAndClear: FIFOs flushed via fifoRst; stateReg forced to INIT_S.
         -- The 11 mkRegU context registers are deliberately untouched (matches
         -- BSV; rewritten by the next prepareNextSgl before any read).
         v.state := INIT_S;

      else

         -------------------------------------------------------------------
         -- handleMetaDataEachSGL (state-independent producer)
         --   guard: adjustedMetaPipeInValid='1' AND sglMetaQFull='0'
         -------------------------------------------------------------------
         if adjustedMetaPipeInValid = '1' and sglMetaQFull = '0' then
            -- AdjustedTotalPayloadMetaData slice (firstPktLen[60:48] unused)
            mFirstPktFragNum  := adjustedMetaPipeInData(47 downto 40);
            mValidByteNum     := adjustedMetaPipeInData(39 downto 34);
            mOrigValidByteNum := adjustedMetaPipeInData(33 downto 28);
            mPktNum           := adjustedMetaPipeInData(27 downto 3);
            mPmtu             := adjustedMetaPipeInData(2 downto 0);

            -- calcFragBitNumAndByteNum: validBitNum = zeroExtend(validByteNum)<<3
            mValidBitNum := mValidByteNum & "000";

            mHasOnly  := ite(unsigned(mPktNum) = 1, '1', '0');  -- isOneR(adjustedPktNum)
            mHasExtra := ite(unsigned(mValidByteNum) < unsigned(mOrigValidByteNum), '1', '0');
            mNoShift  := ite(unsigned(mValidByteNum) = DATA_BUS_BYTE_WIDTH_C, '1', '0');

            adjustedMetaPipeInRdEn <= '1';
            sglMetaQWrEn           <= '1';
            sglMetaQDin            <= mPmtu    -- [53:51]
                           & mFirstPktFragNum  -- [50:43]
                           & mPktNum           -- [42:18]
                           & mValidByteNum     -- [17:12]
                           & mValidBitNum      -- [11:3]
                           & mHasOnly          -- [2]
                           & mHasExtra         -- [1]
                           & mNoShift;         -- [0]
         end if;

         -------------------------------------------------------------------
         -- Main 3-state FSM (adjustPayloadInit / adjustFirstOrMidPkt /
         --                   adjustLastOrOnlyPkt).  All register reads below
         --                   are OLD (r) values (BSV rule semantics).
         -------------------------------------------------------------------
         case r.state is

            -- ============================================================
            -- INIT_S: adjustPayloadInit
            --   implicit cond: sglMetaQValid='1' AND sglAllPayloadPipeInValid='1'
            -- ============================================================
            when INIT_S =>
               if sglMetaQValid = '1' and sglAllPayloadPipeInValid = '1' then
                  sglMetaQRdEn            <= '1';
                  sglAllPayloadPipeInRdEn <= '1';
                  prepareNextSgl(v, sglMetaQDout, sglAllPayloadPipeInData, retFrag);
                  v.prePayloadFrag        := retFrag;
               end if;

            -- ============================================================
            -- FIRST_OR_MID_PKT_S: adjustFirstOrMidPkt
            --   Whole rule gated on fragShiftQFull='0'; when prePayloadFrag.isLast
            --   ='0' the payload pipe is also read/deq'd (needs Valid='1').
            -- ============================================================
            when FIRST_OR_MID_PKT_S =>
               preIsLast       := r.prePayloadFrag(0);
               isAdjLastFrag   := ite(unsigned(r.pktRemainingFragNum) = 1, '1', '0');  -- isOneR
               shouldShift     := not (r.isFirstPkt or r.noShiftFrag);
               curFrag         := (others => '0');  -- genEmptyDataStream
               shouldChgByteEn := '0';

               fire := '0';
               if fragShiftQFull = '0' then
                  if preIsLast = '1' then
                     fire := '1';
                  elsif sglAllPayloadPipeInValid = '1' then
                     fire := '1';
                  end if;
               end if;

               if fire = '1' then
                  if preIsLast = '0' then
                     curFrag           := sglAllPayloadPipeInData;
                     isFirstPktAdjLast := r.isFirstPkt and isAdjLastFrag;
                     if (r.noShiftFrag = '1') or (isFirstPktAdjLast = '0') then
                        sglAllPayloadPipeInRdEn <= '1';
                        nextFrag                := curFrag;
                     else
                        -- last frag of first packet: keep it in prePayloadFragReg,
                        -- do NOT deq (queue head is next packet's first fragment)
                        nextFrag := r.prePayloadFrag;
                     end if;
                     -- nextPayloadFrag.isFirst := isAdjustedLastFrag (bit 1)
                     nextFrag         := nextFrag(289 downto 2) & isAdjLastFrag & nextFrag(0);
                     v.prePayloadFrag := nextFrag;
                  end if;

                  if isAdjLastFrag = '1' then
                     if r.isFirstPkt = '1' then
                        shouldChgByteEn := '1';
                        v.isFirstPkt    := '0';
                     end if;
                     v.sglRemainingPktNum := std_logic_vector(unsigned(r.sglRemainingPktNum) - 1);
                     if unsigned(r.sglRemainingPktNum) = 2 then  -- isTwoR
                        v.state := LAST_OR_ONLY_PKT_S;
                     else
                        v.pktRemainingFragNum := r.pmtuFragNum;
                        v.state               := FIRST_OR_MID_PKT_S;
                     end if;
                  else
                     v.pktRemainingFragNum := std_logic_vector(unsigned(r.pktRemainingFragNum) - 1);
                  end if;

                  -- payloadFragShiftQ.enq (first elem = OLD prePayloadFrag with
                  --   isLast := isAdjustedLastFrag; leftShift gated by shouldShift)
                  preFragWLast := r.prePayloadFrag(289 downto 1) & isAdjLastFrag;
                  if shouldShift = '1' then
                     lsByteNum := r.firstPktLastFragValidByteNum;
                     lsBitNum  := r.firstPktLastFragValidBitNum;
                  else
                     lsByteNum := (others => '0');
                     lsBitNum  := (others => '0');
                  end if;
                  fragShiftQWrEn <= '1';
                  fragShiftQDin  <= preFragWLast                -- [627:338]
                                   & curFrag                    -- [337:48]
                                   & lsByteNum                  -- [47:42]
                                   & lsBitNum                   -- [41:33]
                                   & shouldChgByteEn            -- [32]
                                   & r.firstPktLastFragByteEn;  -- [31:0]
               end if;

            -- ============================================================
            -- LAST_OR_ONLY_PKT_S: adjustLastOrOnlyPkt
            --   Whole rule gated on fragShiftQFull='0'.  Branch on OLD
            --   prePayloadFrag.isLast; the not-last branch deqs the payload pipe.
            -- ============================================================
            when LAST_OR_ONLY_PKT_S =>
               preIsLast       := r.prePayloadFrag(0);
               shouldShift     := not (r.sglHasOnlyPkt or r.noShiftFrag);
               isLastFrag      := preIsLast;  -- = prePayloadFragReg.isLast
               nextFrag        := (others => '0');  -- genEmptyDataStream
               shouldChgByteEn := '0';

               fire := '0';
               if fragShiftQFull = '0' then
                  if preIsLast = '1' then
                     fire := '1';
                  elsif sglAllPayloadPipeInValid = '1' then
                     fire := '1';
                  end if;
               end if;

               if fire = '1' then
                  if preIsLast = '1' then
                     if sglMetaQValid = '1' and sglAllPayloadPipeInValid = '1' then
                        -- start the next SGL
                        sglMetaQRdEn            <= '1';
                        sglAllPayloadPipeInRdEn <= '1';
                        prepareNextSgl(v, sglMetaQDout, sglAllPayloadPipeInData, retFrag);
                        nextFrag                := retFrag;
                     else
                        -- no next SGL yet -> wait in INIT_S (empty frag)
                        v.state := INIT_S;
                     end if;
                  else
                     sglAllPayloadPipeInRdEn <= '1';
                     -- nextPayloadFrag = payload, isFirst forced 0 (bit 1)
                     nextFrag                := sglAllPayloadPipeInData(289 downto 2) & '0' & sglAllPayloadPipeInData(0);
                     if (shouldShift = '1') and (r.hasExtraFrag = '0') and (nextFrag(0) = '1') then
                        -- no extra fragment -> finish this SGL
                        v.state    := INIT_S;
                        isLastFrag := '1';
                     end if;
                  end if;

                  v.prePayloadFrag := nextFrag;

                  -- payloadFragShiftQ.enq (first elem = OLD prePayloadFrag with
                  --   isLast := isLastFrag; shouldChangeByteEn=0, byteEn override
                  --   = dontCare (0) since shouldChangeByteEn is False)
                  preFragWLast := r.prePayloadFrag(289 downto 1) & isLastFrag;
                  if shouldShift = '1' then
                     lsByteNum := r.firstPktLastFragValidByteNum;
                     lsBitNum  := r.firstPktLastFragValidBitNum;
                  else
                     lsByteNum := (others => '0');
                     lsBitNum  := (others => '0');
                  end if;
                  fragShiftQWrEn <= '1';
                  fragShiftQDin  <= preFragWLast   -- [627:338]
                                   & nextFrag      -- [337:48]
                                   & lsByteNum     -- [47:42]
                                   & lsBitNum      -- [41:33]
                                   & '0'           -- [32] shouldChangeByteEn
                                   & x"00000000";  -- [31:0] invalidByteEn (dontCare)
               end if;

         end case;

         -------------------------------------------------------------------
         -- shiftPayloadFrag (state-independent consumer)
         --   guard: fragShiftQValid='1' AND pktPayloadOutQFull='0'
         --   outPayloadFrag = leftShiftAndMergeFragData(pre, cur,
         --                       truncate(lsByteNum 6->5), truncate(lsBitNum 9->8))
         -------------------------------------------------------------------
         if fragShiftQValid = '1' and pktPayloadOutQFull = '0' then
            -- Slice the 628-bit element
            sPreData   := fragShiftQDout(627 downto 372);  -- prePayloadFrag.data
            sPreByteEn := fragShiftQDout(371 downto 340);  -- prePayloadFrag.byteEn
            sCurData   := fragShiftQDout(337 downto 82);  -- curPayloadFrag.data
            sCurByteEn := fragShiftQDout(81 downto 50);  -- curPayloadFrag.byteEn
            sShByteNum := fragShiftQDout(46 downto 42);  -- truncate(leftShiftValidByteNum 6->5)
            sShBitNum  := fragShiftQDout(40 downto 33);  -- truncate(leftShiftValidBitNum 9->8)

            -- byteEn: truncateLSB({pre,cur} << shByteNum) -> top 32 of 64
            byteEnCat := sPreByteEn & sCurByteEn;
            shByteEn  := std_logic_vector(shift_left(unsigned(byteEnCat), to_integer(unsigned(sShByteNum))));
            -- data: truncateLSB({pre,cur} << shBitNum) -> top 256 of 512
            dataCat   := sPreData & sCurData;
            shData    := std_logic_vector(shift_left(unsigned(dataCat), to_integer(unsigned(sShBitNum))));

            -- isFirst/isLast kept from preFrag
            outFrag := shData(511 downto 256)  -- data   [289:34]
                       & shByteEn(63 downto 32)  -- byteEn  [33:2]
                       & fragShiftQDout(339)  -- isFirst (prePayloadFrag.isFirst)
                       & fragShiftQDout(338);  -- isLast  (prePayloadFrag.isLast)

            -- if shouldChangeByteEn: override byteEn with firstPktLastFragByteEn
            if fragShiftQDout(32) = '1' then
               outFrag := outFrag(289 downto 34)  -- keep data
& fragShiftQDout(31 downto 0)           -- byteEn := firstPktLastFragByteEn
                          & outFrag(1 downto 0);  -- keep isFirst/isLast
            end if;

            fragShiftQRdEn     <= '1';
            pktPayloadOutQWrEn <= '1';
            pktPayloadOutQDin  <= outFrag;
         end if;

      end if;

      -- Synchronous reset (stateReg = mkReg(ADJUST_PAYLOAD_SEGMENT_INIT))
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
   --   adjustFirstOrMidPkt: when prePayloadFragReg.isLast, pktRemainingFragNum=1
   --                        and sglRemainingPktNum=2.
   --   adjustLastOrOnlyPkt: sglRemainingPktNum=1 whenever the rule fires.
   --   shiftPayloadFrag   : NOT(MSB(leftShiftValidByteNum) AND MSB(leftShiftValidBitNum)).
   ---------------------------------------------------------------------------
   -- pragma translate_off
   check : process (clk) is
   begin
      if rising_edge(clk) then
         if rst = '0' and clearAllI = '0' then
            if (r.state = FIRST_OR_MID_PKT_S and r.prePayloadFrag(0) = '1'
                and fragShiftQFull = '0') then
               assert (unsigned(r.pktRemainingFragNum) = 1)
                  and (unsigned(r.sglRemainingPktNum) = 2)
                  report "AdjustPayloadSegment: pktRemainingFragNum must be 1 and "
                  & "sglRemainingPktNum must be 2 when prePayloadFrag.isLast in "
                  & "FIRST_OR_MID_PKT_S"
                  severity error;
            end if;
            if (r.state = LAST_OR_ONLY_PKT_S and fragShiftQFull = '0'
                and (r.prePayloadFrag(0) = '1' or sglAllPayloadPipeInValid = '1')) then
               assert unsigned(r.sglRemainingPktNum) = 1
                  report "AdjustPayloadSegment: sglRemainingPktNum must be 1 in "
                  & "LAST_OR_ONLY_PKT_S"
                  severity error;
            end if;
            if (fragShiftQValid = '1' and pktPayloadOutQFull = '0') then
               assert not (fragShiftQDout(47) = '1' and fragShiftQDout(41) = '1')
                  report "AdjustPayloadSegment: leftShiftValidByteNum/BitNum MSBs "
                  & "must not both be 1 (truncate 6->5 / 9->8 would lose a bit)"
                  severity error;
            end if;
         end if;
      end if;
   end process check;
   -- pragma translate_on

end architecture rtl;
