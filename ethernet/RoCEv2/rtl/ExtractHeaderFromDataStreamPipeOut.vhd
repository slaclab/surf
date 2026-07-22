-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Inverse of PrependHeader2PipeOut.  Splits one incoming left-aligned
--   DataStream (header bytes immediately followed by payload bytes, described
--   by a HeaderMetaData token) into two separate output streams:
--     * header  — the header fragments, last fragment trimmed to the header's
--                 valid byte count;
--     * payload — the payload bytes that followed the header, re-left-aligned
--                 by de-shifting the header's trailing partial fragment back
--                 out and concatenating across fragment boundaries, emitting an
--                 extra trailing fragment when the de-shift overflows a word.
--   If a header carries no payload (or the input ran out before any payload
--   byte), an empty DataStream {0,0,isFirst,isLast} is pushed to `payload` to
--   keep header and payload aligned 1:1.
--
--   4-stage FSM (BSV stageReg : ExtractOrPrependHeaderStage):
--     HEADER_META_DATA_POP_S    — latch HeaderMetaData + first data frag
--     HEADER_OUTPUT_S           — emit header frags to U_HeaderDataStreamOutQ
--     DATA_OUTPUT_S             — emit de-shifted payload frags
--     EXTRA_LAST_FRAG_OUTPUT_S  — emit trailing payload frag from leftover bits
--
--   BSV rules implemented (mutually exclusive on stageReg → single case):
--     popHeaderMetaData → HEADER_META_DATA_POP_S
--     outputHeader      → HEADER_OUTPUT_S
--     outputData        → DATA_OUTPUT_S
--     extraLastFrag     → EXTRA_LAST_FRAG_OUTPUT_S
--
--   Mapping note (OQ-FSM-EHDSPO-01):
--     mapping.json/modules.json are STALE for this entity (owns.rules=[],
--     surf_instances=[], and a bogus DataStream2Header child).  The BSV source
--     is authoritative: no child modules, two output FIFOs, 12 registers.
--     This file follows the BSV source + fsm.md, not mapping.json.
--
--   Width notes:
--     DataStream     = 290 b (data 256 + byteEn 32 + isFirst 1 + isLast 1)
--                      (OQ-FSM-EHDSPO-02 / OQ-FSM-H2DS-02 RESOLVED — NOT 321).
--     HeaderMetaData =  17 b (headerLen 7 + headerFragNum 2 +
--                      lastFragValidByteNum 6 + hasPayload 1 + isEmptyHeader 1).
--                      The fsm.md "42b" is an error; confirmed 17 b against
--                      DataTypes.bsv and the sibling Header2DataStream entity.
--     Only headerFragNum and lastFragValidByteNum are read functionally here.
--
--   Bit packing (BSV deriving(Bits), first-field-at-MSB; OQ-FSM-EHDSPO-03 /
--   OQ-FSM-H2DS-04 RESOLVED):
--     DataStream:
--       [289:34] data[255:0]   (256 b)
--       [33:2]   byteEn[31:0]  (32 b)   -- left-aligned mask (MSB = first byte)
--       [1]      isFirst
--       [0]      isLast
--     HeaderMetaData:
--       [16:10]  headerLen[6:0]          (sim-only assert; unused in RTL)
--       [9:8]    headerFragNum[1:0]
--       [7:2]    lastFragValidByteNum[5:0]
--       [1]      hasPayload              (unused here)
--       [0]      isEmptyHeader           (unused here)
--
--   Helper semantics (faithful to BSV — read the source, not the fsm.md prose):
--     genByteEn(n)    = reverseBits((1<<n)-1) = n left-aligned ('1') bits at the
--                       MSB end (bits 31 downto 32-n).            (Utils.bsv:161)
--     isZeroByteEn(b) = isZero({msb(b), lsb(b)}) = (b(31)='0' and b(0)='0').
--                       This is a 2-bit check, NOT a full OR-reduce; the fsm.md
--                       describes it as OR-reduce which is WRONG.  (PrimUtils.bsv:26)
--     calcFragBitNumAndByteNum(v):
--       validBit   = zeroExtend(v) << 3
--       invalidByte= 32 - v
--       invalidBit = zeroExtend(invalidByte) << 3                 (Utils.bsv:182)
--
--   SURF components instantiated:
--     U_HeaderDataStreamOutQ  : surf.Fifo  (DATA_WIDTH_G=290, FWFT, sync, block)
--       source: surf/base/fifo/rtl/Fifo.vhd  (BSV: mkFIFOF headerDataStreamOutQ;
--       read side exposed on the `header` PipeOut interface)
--     U_PayloadDataStreamOutQ : surf.Fifo  (DATA_WIDTH_G=290, FWFT, sync, block)
--       source: surf/base/fifo/rtl/Fifo.vhd  (BSV: mkFIFOF payloadDataStreamOutQ;
--       read side exposed on the `payload` PipeOut interface)
--   There is NO clearAll/reset rule in this module, so neither FIFO has a clr
--   driver; fifo rst is the entity rst only.
--
--   Atomicity (BSV rule = one comb evaluation): every reg READ is from r.*,
--   every WRITE to v.*.  In outputData the enqueued payload reads OLD
--   r.preDataStreamReg/r.curDataStreamReg/r.isFirstDataFragReg while v.* is
--   updated the same edge — emitted as read-before-write, never read-after-write.
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

entity ExtractHeaderFromDataStreamPipeOut is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk : in sl;
      rst : in sl;                                  -- active-high synchronous reset
      -- Upstream: data fragments (dataPipeIn : DataStreamPipeOut)
      dataPipeInValid       : in  sl;               -- dataPipeIn.notEmpty
      dataPipeInData        : in  slv(289 downto 0);-- dataPipeIn.first (DataStream)
      dataPipeInRdEn        : out sl;               -- dataPipeIn.deq
      -- Upstream: header metadata (headerMetaDataPipeIn : PipeOut#(HeaderMetaData))
      hdrMetaPipeInValid    : in  sl;               -- headerMetaDataPipeIn.notEmpty
      hdrMetaPipeInData     : in  slv(16 downto 0); -- headerMetaDataPipeIn.first
      hdrMetaPipeInRdEn     : out sl;               -- headerMetaDataPipeIn.deq
      -- Downstream: header stream (interface header = toPipeOut(headerDataStreamOutQ))
      headerValid           : out sl;               -- header.notEmpty
      headerData            : out slv(289 downto 0);-- header.first (DataStream)
      headerRdEn            : in  sl;               -- header.deq
      -- Downstream: payload stream (interface payload = toPipeOut(payloadDataStreamOutQ))
      payloadValid          : out sl;               -- payload.notEmpty
      payloadData           : out slv(289 downto 0);-- payload.first (DataStream)
      payloadRdEn           : in  sl);              -- payload.deq
end entity ExtractHeaderFromDataStreamPipeOut;

architecture rtl of ExtractHeaderFromDataStreamPipeOut is

   ---------------------------------------------------------------------------
   -- Constants / DataStream field slicing (290-bit packed layout)
   ---------------------------------------------------------------------------
   constant DATA_BUS_BYTE_WIDTH_C : natural := 32;   -- DATA_BUS_WIDTH/8
   constant DS_WIDTH_C            : natural := 290;

   -- DataStream sub-ranges within a 290-bit word
   subtype DsDataRange   is natural range 289 downto 34;  -- 256 b
   subtype DsByteEnRange is natural range 33 downto 2;    --  32 b
   constant DS_ISFIRST_C : natural := 1;
   constant DS_ISLAST_C  : natural := 0;

   ---------------------------------------------------------------------------
   -- BSV helper functions (faithful to Utils.bsv / PrimUtils.bsv)
   ---------------------------------------------------------------------------
   -- genByteEn(n) = reverseBits((1<<n)-1): n left-aligned '1' bits (bits 31..32-n)
   function genByteEn (validByteNum : slv) return slv is
      variable n   : integer;
      variable ret : slv(31 downto 0) := (others => '0');
   begin
      n := to_integer(unsigned(validByteNum));
      for i in 0 to 31 loop
         if i >= (32 - n) then
            ret(i) := '1';
         end if;
      end loop;
      return ret;
   end function genByteEn;

   -- isZeroByteEn(b) = isZero({msb(b), lsb(b)}): only the MSB and LSB are tested
   function isZeroByteEn (be : slv) return boolean is
   begin
      return (be(be'high) = '0') and (be(be'low) = '0');
   end function isZeroByteEn;

   ---------------------------------------------------------------------------
   -- FSM state (BSV stageReg : ExtractOrPrependHeaderStage)
   ---------------------------------------------------------------------------
   type StateType is (
      HEADER_META_DATA_POP_S,
      HEADER_OUTPUT_S,
      DATA_OUTPUT_S,
      EXTRA_LAST_FRAG_OUTPUT_S);

   type RegType is record
      stageReg                     : StateType;
      -- mkRegU context registers (no architectural reset; written before read)
      preDataStreamReg             : slv(289 downto 0);  -- previous frag (de-shift high half)
      curDataStreamReg             : slv(289 downto 0);  -- current frag (low half / header frag)
      headerFragNum                : slv(1 downto 0);    -- remaining header frags (decremented)
      headerLastFragByteEn         : slv(31 downto 0);   -- byteEn mask for header last frag
      headerLastFragInvalidBitNum  : slv(8 downto 0);    -- (32-validByteNum)<<3
      headerLastFragInvalidByteNum : slv(5 downto 0);    -- 32-validByteNum
      headerLastFragValidBitNum    : slv(8 downto 0);    -- validByteNum<<3
      headerLastFragValidByteNum   : slv(5 downto 0);    -- header last-frag valid byte count
      isFirstDataFrag              : sl;                 -- payload-out isFirst flag
      isHeaderLastFrag             : sl;                 -- current frag is the last header frag
      shiftedCurDataFragByteEn     : slv(31 downto 0);   -- curFrag.byteEn << validByteNum
   end record RegType;

   -- stageReg: mkReg(HEADER_META_DATA_POP) → reset value.
   -- All other fields: mkRegU → no real reset; set to '0' (written before read on
   -- every live path; OQ-FSM-04 / OQ-FSM-PH2PO precedent).
   constant REG_INIT_C : RegType := (
      stageReg                     => HEADER_META_DATA_POP_S,
      preDataStreamReg             => (others => '0'),
      curDataStreamReg             => (others => '0'),
      headerFragNum                => (others => '0'),
      headerLastFragByteEn         => (others => '0'),
      headerLastFragInvalidBitNum  => (others => '0'),
      headerLastFragInvalidByteNum => (others => '0'),
      headerLastFragValidBitNum    => (others => '0'),
      headerLastFragValidByteNum   => (others => '0'),
      isFirstDataFrag              => '0',
      isHeaderLastFrag             => '0',
      shiftedCurDataFragByteEn     => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Output-FIFO control signals (driven by comb process)
   signal headerOutQNotFull  : sl;
   signal headerOutQWrEn     : sl;
   signal headerOutQDin      : slv(289 downto 0);
   signal payloadOutQNotFull : sl;
   signal payloadOutQWrEn    : sl;
   signal payloadOutQDin     : slv(289 downto 0);

   -- Internal copies of the deq output ports (driven from the comb process)
   signal dataPipeInRdEn_i   : sl;
   signal hdrMetaPipeInRdEn_i : sl;

begin

   dataPipeInRdEn    <= dataPipeInRdEn_i;
   hdrMetaPipeInRdEn <= hdrMetaPipeInRdEn_i;

   ---------------------------------------------------------------------------
   -- U_HeaderDataStreamOutQ : surf.Fifo
   --   BSV: headerDataStreamOutQ <- mkFIFOF; read side = `header` PipeOut.
   --   DATA_WIDTH_G=290, FWFT (first = combinational dout/valid), sync, block.
   ---------------------------------------------------------------------------
   U_HeaderDataStreamOutQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => DS_WIDTH_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => rst,
         wr_clk        => clk,
         wr_en         => headerOutQWrEn,
         din           => headerOutQDin,
         not_full      => headerOutQNotFull,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         full          => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => headerRdEn,
         dout          => headerData,
         valid         => headerValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_PayloadDataStreamOutQ : surf.Fifo
   --   BSV: payloadDataStreamOutQ <- mkFIFOF; read side = `payload` PipeOut.
   --   DATA_WIDTH_G=290, FWFT, sync, block.
   ---------------------------------------------------------------------------
   U_PayloadDataStreamOutQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => DS_WIDTH_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => rst,
         wr_clk        => clk,
         wr_en         => payloadOutQWrEn,
         din           => payloadOutQDin,
         not_full      => payloadOutQNotFull,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         full          => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => payloadRdEn,
         dout          => payloadData,
         valid         => payloadValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- Combinatorial process (two-process FSM)
   ---------------------------------------------------------------------------
   comb : process (r, rst,
                   dataPipeInValid, dataPipeInData,
                   hdrMetaPipeInValid, hdrMetaPipeInData,
                   headerOutQNotFull, payloadOutQNotFull) is
      variable v : RegType;

      -- popHeaderMetaData scratch
      variable hmdFragNum   : slv(1 downto 0);
      variable vByte        : slv(5 downto 0);
      variable invByte      : slv(5 downto 0);
      variable validBit     : slv(8 downto 0);
      variable invalidBit   : slv(8 downto 0);
      variable firstByteEn  : slv(31 downto 0);

      -- outputHeader scratch
      variable cur          : slv(289 downto 0);
      variable curIsLast    : sl;
      variable hasDataAfter : boolean;
      variable nextByteEn   : slv(31 downto 0);

      -- outputData scratch
      variable noExtraLast  : boolean;
      variable concatData   : slv(511 downto 0);
      variable concatByteEn : slv(63 downto 0);
      variable shData       : slv(511 downto 0);
      variable shByteEn     : slv(63 downto 0);
      variable payIsLast    : sl;

      -- extraLastFrag scratch
      variable lsData       : slv(255 downto 0);
      variable lsByteEn     : slv(31 downto 0);

      -- shared fire gate
      variable canFire      : boolean;
   begin
      v := r;

      -- Default Mealy outputs (deasserted; overridden per fired transition)
      headerOutQWrEn      <= '0';
      headerOutQDin       <= (others => '0');
      payloadOutQWrEn     <= '0';
      payloadOutQDin      <= (others => '0');
      dataPipeInRdEn_i    <= '0';
      hdrMetaPipeInRdEn_i <= '0';

      case r.stageReg is

         -----------------------------------------------------------------
         -- popHeaderMetaData : POP -> HOUT
         --   Needs both upstream pipes ready (it deqs both); no enq → no
         --   notFull gate.
         -----------------------------------------------------------------
         when HEADER_META_DATA_POP_S =>
            canFire := (hdrMetaPipeInValid = '1') and (dataPipeInValid = '1');
            if canFire then
               hmdFragNum := hdrMetaPipeInData(9 downto 8);      -- headerFragNum
               vByte      := hdrMetaPipeInData(7 downto 2);      -- lastFragValidByteNum

               -- calcFragBitNumAndByteNum(vByte)
               validBit   := slv(shift_left(resize(unsigned(vByte), 9), 3));
               invByte    := slv(to_unsigned(DATA_BUS_BYTE_WIDTH_C, 6) - unsigned(vByte));
               invalidBit := slv(shift_left(resize(unsigned(invByte), 9), 3));

               v.headerLastFragValidByteNum   := vByte;
               v.headerLastFragValidBitNum    := validBit;
               v.headerLastFragInvalidByteNum := invByte;
               v.headerLastFragInvalidBitNum  := invalidBit;
               v.headerLastFragByteEn         := genByteEn(vByte);

               -- isHeaderLastFrag uses the ORIGINAL fragNum; store fragNum-1
               v.isHeaderLastFrag := toSl(hmdFragNum = "01");
               v.headerFragNum    := slv(unsigned(hmdFragNum) - 1);

               -- latch first data frag; precompute payload-after-header detector
               v.curDataStreamReg := dataPipeInData;
               firstByteEn        := dataPipeInData(DsByteEnRange);
               v.shiftedCurDataFragByteEn :=
                  slv(shift_left(unsigned(firstByteEn), to_integer(unsigned(vByte))));

               -- deq both upstream pipes
               hdrMetaPipeInRdEn_i <= '1';
               dataPipeInRdEn_i    <= '1';

               v.stageReg := HEADER_OUTPUT_S;
            end if;

         -----------------------------------------------------------------
         -- outputHeader : HOUT
         --   Always enq header. cur.isLast branch may enq payload (empty pad);
         --   !cur.isLast branch deqs dataPipeIn.
         -----------------------------------------------------------------
         when HEADER_OUTPUT_S =>
            cur          := r.curDataStreamReg;
            curIsLast    := cur(DS_ISLAST_C);
            -- hasDataFragAfterHeader = !isZeroByteEn(shifted) && isHeaderLastFrag
            hasDataAfter := (not isZeroByteEn(r.shiftedCurDataFragByteEn))
                            and (r.isHeaderLastFrag = '1');

            if curIsLast = '1' then
               -- gate: header enq always; payload enq only when !hasDataAfter
               if hasDataAfter then
                  canFire := (headerOutQNotFull = '1');
               else
                  canFire := (headerOutQNotFull = '1') and (payloadOutQNotFull = '1');
               end if;

               if canFire then
                  v.preDataStreamReg := cur;

                  -- header out frag: keep data/isFirst, trim byteEn, force isLast=1
                  if hasDataAfter then
                     nextByteEn := r.headerLastFragByteEn;
                  else
                     nextByteEn := cur(DsByteEnRange);
                  end if;
                  headerOutQWrEn <= '1';
                  headerOutQDin  <= cur(DsDataRange) & nextByteEn & cur(DS_ISFIRST_C) & '1';

                  v.isFirstDataFrag := toSl(hasDataAfter);

                  if hasDataAfter then
                     -- hasDataAfter implies isHeaderLastFrag, so this is EXTRA
                     if r.isHeaderLastFrag = '1' then
                        v.stageReg := EXTRA_LAST_FRAG_OUTPUT_S;
                     else
                        v.stageReg := DATA_OUTPUT_S;
                     end if;
                  else
                     -- no payload: push empty pad frag to keep header/payload 1:1
                     payloadOutQWrEn <= '1';
                     payloadOutQDin  <= (others => '0');    -- data=0, byteEn=0
                     payloadOutQDin(DS_ISFIRST_C) <= '1';
                     payloadOutQDin(DS_ISLAST_C)  <= '1';
                     v.stageReg := HEADER_META_DATA_POP_S;
                  end if;
               end if;

            else  -- not cur.isLast : more header/data frags follow
               canFire := (headerOutQNotFull = '1') and (dataPipeInValid = '1');
               if canFire then
                  v.preDataStreamReg := cur;

                  -- advance to next frag
                  v.curDataStreamReg := dataPipeInData;
                  nextByteEn := dataPipeInData(DsByteEnRange);
                  v.shiftedCurDataFragByteEn :=
                     slv(shift_left(unsigned(nextByteEn),
                                    to_integer(unsigned(r.headerLastFragValidByteNum))));
                  dataPipeInRdEn_i <= '1';

                  if r.isHeaderLastFrag = '1' then
                     -- finish header: trim byteEn, force isLast=1, go to DATA
                     headerOutQWrEn <= '1';
                     headerOutQDin  <= cur(DsDataRange) & r.headerLastFragByteEn
                                       & cur(DS_ISFIRST_C) & '1';
                     v.isFirstDataFrag := '1';
                     v.stageReg        := DATA_OUTPUT_S;
                  else
                     -- mid-header full frag (isLast stays 0); decrement fragNum
                     headerOutQWrEn   <= '1';
                     headerOutQDin    <= cur;          -- full frag unchanged
                     v.isHeaderLastFrag := toSl(r.headerFragNum = "01");
                     v.headerFragNum    := slv(unsigned(r.headerFragNum) - 1);
                     -- stageReg stays HEADER_OUTPUT_S
                  end if;
               end if;
            end if;

         -----------------------------------------------------------------
         -- outputData : DOUT
         --   Always enq payload (de-shifted). !cur.isLast also deqs dataPipeIn.
         -----------------------------------------------------------------
         when DATA_OUTPUT_S =>
            cur       := r.curDataStreamReg;
            curIsLast := cur(DS_ISLAST_C);
            if curIsLast = '1' then
               canFire := (payloadOutQNotFull = '1');
            else
               canFire := (payloadOutQNotFull = '1') and (dataPipeInValid = '1');
            end if;

            if canFire then
               noExtraLast := isZeroByteEn(r.shiftedCurDataFragByteEn);

               -- {pre, cur} with pre as MSB, then >> invalid count, truncate to low half
               concatData   := r.preDataStreamReg(DsDataRange)   & r.curDataStreamReg(DsDataRange);
               concatByteEn := r.preDataStreamReg(DsByteEnRange) & r.curDataStreamReg(DsByteEnRange);
               shData   := slv(shift_right(unsigned(concatData),
                                  to_integer(unsigned(r.headerLastFragInvalidBitNum))));
               shByteEn := slv(shift_right(unsigned(concatByteEn),
                                  to_integer(unsigned(r.headerLastFragInvalidByteNum))));

               -- isLast = cur.isLast && noExtraLast ; isFirst = OLD r.isFirstDataFrag
               if (curIsLast = '1') and noExtraLast then
                  payIsLast := '1';
               else
                  payIsLast := '0';
               end if;
               payloadOutQWrEn <= '1';
               payloadOutQDin  <= shData(255 downto 0) & shByteEn(31 downto 0)
                                  & r.isFirstDataFrag & payIsLast;

               v.preDataStreamReg := cur;
               v.isFirstDataFrag  := '0';

               if curIsLast = '1' then
                  if noExtraLast then
                     v.stageReg := HEADER_META_DATA_POP_S;
                  else
                     v.stageReg := EXTRA_LAST_FRAG_OUTPUT_S;
                  end if;
               else
                  v.curDataStreamReg := dataPipeInData;
                  nextByteEn := dataPipeInData(DsByteEnRange);
                  v.shiftedCurDataFragByteEn :=
                     slv(shift_left(unsigned(nextByteEn),
                                    to_integer(unsigned(r.headerLastFragValidByteNum))));
                  dataPipeInRdEn_i <= '1';
               end if;
            end if;

         -----------------------------------------------------------------
         -- extraLastFrag : EXTRA -> POP
         --   Emit the trailing payload frag from the leftover (left-shifted)
         --   bits of preDataStreamReg.  Enq payload only.
         -----------------------------------------------------------------
         when EXTRA_LAST_FRAG_OUTPUT_S =>
            canFire := (payloadOutQNotFull = '1');
            if canFire then
               lsData := slv(shift_left(unsigned(r.preDataStreamReg(DsDataRange)),
                                to_integer(unsigned(r.headerLastFragValidBitNum))));
               lsByteEn := slv(shift_left(unsigned(r.preDataStreamReg(DsByteEnRange)),
                                to_integer(unsigned(r.headerLastFragValidByteNum))));
               payloadOutQWrEn <= '1';
               payloadOutQDin  <= lsData & lsByteEn & r.isFirstDataFrag & '1';

               v.isFirstDataFrag := '0';
               v.stageReg        := HEADER_META_DATA_POP_S;
            end if;

      end case;

      -- Synchronous reset (matches BSV mkReg(HEADER_META_DATA_POP) for stageReg)
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
