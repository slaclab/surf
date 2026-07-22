-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Prepends a (right-aligned) header DataStream onto a payload DataStream and
--   emits one merged, left-aligned DataStream.  The header's last fragment is
--   only partially valid; payload fragments are shifted by the header's
--   valid-bit amount and concatenated across fragment boundaries, producing an
--   extra trailing fragment when the merge overflows the 256-bit bus.
--
--   Single SURF Fifo (U_DataStreamOutQ); its read side IS the module's
--   toPipeOut(dataStreamOutQ) — i.e. the entity's DataStream output port.  The
--   three upstream pipes (headerMetaDataPipeIn / headerPipeIn / dataPipeIn) are
--   PipeOut *arguments* (input handshake ports), NOT FIFOs instantiated here.
--
--   FIVE rules (fsm.md transition table):
--     resetAndClear (guard clearAllI, fire_when_enabled) — flush the FIFO and
--                    force stageReg = HEADER_META_DATA_POP_S.
--     popHeaderMetaData (POP)   — latch HeaderMetaData, branch to HOUT or DOUT.
--     outputHeader      (HOUT)  — stream header frags; on the last frag stash a
--                                 right-shifted residue into preDataStreamReg.
--     outputData        (DOUT)  — merge payload frags with the header residue.
--     extraLastFrag     (EXTRA) — emit the overflow tail fragment.
--   The four stage rules are guarded on distinct stageReg values (one-hot) and
--   are mutually exclusive; emitted as a single `case r.stageReg` under
--   `if clearAllI = '0'`.
--
--   Mapping note (OQ-FSM-PH2PO-01): mapping.json / modules.json are STALE for
--     this entity — they record a single bogus rule `merge`, a non-existent
--     `mergeQ` FIFO (321b), and a non-existent internal `hdr2DS =
--     mkHeader2DataStream` submodule.  None exist in the BSV source.  This file
--     follows PrependHeader2PipeOut.fsm.md, which is authoritative.
--
--   Width / packing resolutions applied:
--     - DataStream width = 290 bits           (OQ-FSM-H2DS-02 / PH2PO-02 RESOLVED)
--     - all struct packing first-field-at-MSB  (OQ-FSM-H2DS-04 / PH2PO-02 RESOLVED)
--
--   FIFO clear (OQ-FSM-01 / PH2PO-02 RESOLVED): surf.Fifo has no clear port; the
--     BSV FIFOF.clear (asserted as a LEVEL by resetAndClear while clearAll='1')
--     is modelled by asserting the synchronous FIFO reset:
--     fifoRst = rst OR clearAllI.
--
--   Atomicity (fsm.md "Atomicity caution"): in outputData, outDS.isFirst reads
--     OLD r.isFirstReg while v.isFirstReg := '0' is assigned the same cycle;
--     tmpData/tmpByteEn read OLD r.preDataStreamReg while v.preDataStreamReg :=
--     frag.  All reads are taken from r.*, all writes go to v.* — no
--     read-after-write within the comb evaluation.  A stage rule fires only when
--     its upstream notEmpty AND (for the enq'ing arms) downstream notFull hold;
--     stageReg, the deq strobes and wrEn are gated together (BSV rule atomicity).
--
--   Bit layouts (BSV deriving(Bits), first-field-at-MSB):
--     DataStream (290): [289:34] data[255:0] | [33:2] byteEn[31:0] |
--                       [1] isFirst | [0] isLast
--     HeaderMetaData (17):
--       [16:10] headerLen[6:0] (sim-assert only) | [9:8] headerFragNum[1:0] |
--       [7:2] lastFragValidByteNum[5:0] | [1] hasPayload | [0] isEmptyHeader
--
--   SURF components instantiated (source: surf/base/fifo/rtl/Fifo.vhd):
--     U_DataStreamOutQ : surf.Fifo  DATA_WIDTH_G=290 (output, read side exposed)
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

entity PrependHeader2PipeOut is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk : in sl;
      rst : in sl;                                          -- active-high synchronous reset
      -- Software clear (BSV constructor parameter clearAll : Bool)
      clearAllI                  : in  sl;
      -- Upstream: HeaderMetaData pipe (headerMetaDataPipeIn argument)
      headerMetaPipeInValid      : in  sl;                  -- .notEmpty
      headerMetaPipeInData       : in  slv(16 downto 0);    -- .first  (HeaderMetaData)
      headerMetaPipeInRdEn       : out sl;                  -- .deq
      -- Upstream: header DataStream pipe (headerPipeIn argument)
      headerPipeInValid          : in  sl;                  -- .notEmpty
      headerPipeInData           : in  slv(289 downto 0);   -- .first  (DataStream)
      headerPipeInRdEn           : out sl;                  -- .deq
      -- Upstream: payload DataStream pipe (dataPipeIn argument)
      dataPipeInValid            : in  sl;                  -- .notEmpty
      dataPipeInData             : in  slv(289 downto 0);   -- .first  (DataStream)
      dataPipeInRdEn             : out sl;                  -- .deq
      -- Downstream: returned PipeOut#(DataStream) (read side of U_DataStreamOutQ)
      dataStreamOutValid         : out sl;                  -- PipeOut.notEmpty
      dataStreamOutData          : out slv(289 downto 0);   -- PipeOut.first
      dataStreamOutRdEn          : in  sl);                 -- PipeOut.deq
end entity PrependHeader2PipeOut;

architecture rtl of PrependHeader2PipeOut is

   -- Maps BSV ExtractOrPrependHeaderStage:
   --   HEADER_META_DATA_POP    -> HEADER_META_DATA_POP_S
   --   HEADER_OUTPUT           -> HEADER_OUTPUT_S
   --   DATA_OUTPUT             -> DATA_OUTPUT_S
   --   EXTRA_LAST_FRAG_OUTPUT  -> EXTRA_LAST_FRAG_OUTPUT_S
   type StateType is (
      HEADER_META_DATA_POP_S,
      HEADER_OUTPUT_S,
      DATA_OUTPUT_S,
      EXTRA_LAST_FRAG_OUTPUT_S);

   type RegType is record
      stageReg                       : StateType;        -- mkReg(HEADER_META_DATA_POP)
      preDataStreamReg               : slv(289 downto 0); -- mkRegU (DataStream, right-aligned)
      headerFragCntReg               : slv(1 downto 0);   -- mkRegU (HeaderFragNum)
      headerLastFragInvalidBitNumReg : slv(8 downto 0);   -- mkRegU (BusBitNum)
      headerLastFragInvalidByteNumReg: slv(5 downto 0);   -- mkRegU (ByteEnBitNum)
      headerLastFragValidBitNumReg   : slv(8 downto 0);   -- mkRegU (BusBitNum)
      headerLastFragValidByteNumReg  : slv(5 downto 0);   -- mkRegU (ByteEnBitNum)
      headerHasPayloadReg            : sl;                -- mkRegU
      isFirstReg                     : sl;                -- mkRegU
   end record RegType;

   -- mkRegU fields set to '0' in REG_INIT_C (OQ-FSM-04 precedent): every field
   -- is written before it is read on any live path (popHeaderMetaData sets the
   -- header context; preDataStreamReg/isFirstReg are written before the merge
   -- arms read them), so the reset value is don't-care (no correctness risk).
   constant REG_INIT_C : RegType := (
      stageReg                        => HEADER_META_DATA_POP_S,
      preDataStreamReg                => (others => '0'),
      headerFragCntReg                => (others => '0'),
      headerLastFragInvalidBitNumReg  => (others => '0'),
      headerLastFragInvalidByteNumReg => (others => '0'),
      headerLastFragValidBitNumReg    => (others => '0'),
      headerLastFragValidByteNumReg   => (others => '0'),
      headerHasPayloadReg             => '0',
      isFirstReg                      => '0');

   constant DATA_BUS_BYTE_WIDTH_C : natural := 32;     -- DATA_BUS_BYTE_WIDTH

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Shared synchronous clear for the output FIFO (rst OR clearAllI)
   signal fifoRst : sl;

   -- U_DataStreamOutQ control / status (output queue; read side exposed)
   signal dsOutQWrEn : sl;
   signal dsOutQDin  : slv(289 downto 0);
   signal dsOutQFull : sl;

begin

   -- FIFO reset: level-sensitive synchronous clear (OQ-FSM-01 RESOLVED).
   -- resetAndClear calls dataStreamOutQ.clear while clearAllI='1'.
   fifoRst <= rst or clearAllI;

   ---------------------------------------------------------------------------
   -- U_DataStreamOutQ : surf.Fifo
   --   Output queue; its read side IS the returned PipeOut#(DataStream).
   --   Written by outputHeader / outputData / extraLastFrag.
   --   DATA_WIDTH_G=290, FWFT, sync, distributed RAM.
   ---------------------------------------------------------------------------
   U_DataStreamOutQ : entity surf.Fifo
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
         wr_en         => dsOutQWrEn,
         din           => dsOutQDin,
         full          => dsOutQFull,
         not_full      => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => dataStreamOutRdEn,
         dout          => dataStreamOutData,
         valid         => dataStreamOutValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- Combinatorial process
   ---------------------------------------------------------------------------
   comb : process (r, rst, clearAllI,
                   headerMetaPipeInValid, headerMetaPipeInData,
                   headerPipeInValid, headerPipeInData,
                   dataPipeInValid, dataPipeInData,
                   dsOutQFull) is
      variable v : RegType;

      -- popHeaderMetaData locals
      variable hmdFragNum     : slv(1 downto 0);
      variable hmdValidByteN  : slv(5 downto 0);
      variable hmdValidBitN   : slv(8 downto 0);
      variable hmdInvalidByteN: slv(5 downto 0);
      variable hmdInvalidBitN : slv(8 downto 0);
      variable hmdHasPayload  : sl;
      variable hmdIsEmpty     : sl;

      -- outputHeader locals
      variable hFragIsLast : sl;
      variable hFragIsFirst: sl;
      variable hRsData     : slv(255 downto 0);
      variable hRsByteEn   : slv(31 downto 0);
      variable hFire       : sl;

      -- outputData locals
      variable dFragIsLast    : sl;
      variable dLastFragByteEn: slv(31 downto 0);
      variable dNoExtraLast   : sl;
      variable dDataCat       : slv(511 downto 0);
      variable dByteEnCat     : slv(63 downto 0);
      variable dTmpData       : slv(511 downto 0);
      variable dTmpByteEn     : slv(63 downto 0);
      variable dOutDS         : slv(289 downto 0);

      -- extraLastFrag locals
      variable eLeftData  : slv(255 downto 0);
      variable eLeftByteEn: slv(31 downto 0);
      variable eExtraDS   : slv(289 downto 0);
   begin
      v := r;

      -- default Mealy outputs (deasserted; overridden below per transition)
      headerMetaPipeInRdEn <= '0';
      headerPipeInRdEn     <= '0';
      dataPipeInRdEn       <= '0';
      dsOutQWrEn           <= '0';
      dsOutQDin            <= (others => '0');

      if clearAllI = '1' then
         -- resetAndClear: FIFO flushed via fifoRst; stageReg forced to POP.
         -- The mkRegU context registers are deliberately untouched (matches BSV;
         -- rewritten by the next popHeaderMetaData before any read).
         v.stageReg := HEADER_META_DATA_POP_S;

      else

         case r.stageReg is

            -- ============================================================
            -- HEADER_META_DATA_POP_S : popHeaderMetaData
            --   implicit cond: headerMetaPipeInValid='1' (no enq, no notFull)
            -- ============================================================
            when HEADER_META_DATA_POP_S =>
               if headerMetaPipeInValid = '1' then
                  -- HeaderMetaData slice (headerLen[16:10] used by sim assert only)
                  hmdFragNum    := headerMetaPipeInData(9 downto 8);
                  hmdValidByteN := headerMetaPipeInData(7 downto 2);
                  hmdHasPayload := headerMetaPipeInData(1);
                  hmdIsEmpty    := headerMetaPipeInData(0);

                  -- calcFragBitNumAndByteNum(validByteNum):
                  --   validBitNum   = zeroExtend(validByteNum) << 3
                  --   invalidByteNum= DATA_BUS_BYTE_WIDTH - validByteNum
                  --   invalidBitNum = zeroExtend(invalidByteNum) << 3
                  hmdValidBitN    := hmdValidByteN & "000";
                  hmdInvalidByteN := std_logic_vector(
                     to_unsigned(DATA_BUS_BYTE_WIDTH_C, 6) - unsigned(hmdValidByteN));
                  hmdInvalidBitN  := hmdInvalidByteN & "000";

                  headerMetaPipeInRdEn <= '1';

                  v.headerLastFragValidByteNumReg   := hmdValidByteN;
                  v.headerLastFragValidBitNumReg    := hmdValidBitN;
                  v.headerLastFragInvalidByteNumReg := hmdInvalidByteN;
                  v.headerLastFragInvalidBitNumReg  := hmdInvalidBitN;

                  if hmdIsEmpty = '1' then
                     v.headerFragCntReg := (others => '0');
                  else
                     v.headerFragCntReg := std_logic_vector(unsigned(hmdFragNum) - 1);
                  end if;

                  v.headerHasPayloadReg := hmdHasPayload;
                  v.isFirstReg          := '1';

                  if hmdIsEmpty = '1' then
                     v.stageReg := DATA_OUTPUT_S;
                  else
                     v.stageReg := HEADER_OUTPUT_S;
                  end if;
               end if;

            -- ============================================================
            -- HEADER_OUTPUT_S : outputHeader
            --   implicit cond: headerPipeInValid='1'; the two enq'ing arms
            --   (non-last frag, last-frag-no-payload) additionally need notFull.
            --   The last-frag-with-payload arm does NO enq -> no notFull needed.
            -- ============================================================
            when HEADER_OUTPUT_S =>
               hFragIsLast  := headerPipeInData(0);
               hFragIsFirst := headerPipeInData(1);

               hFire := '0';
               if headerPipeInValid = '1' then
                  if hFragIsLast = '1' and r.headerHasPayloadReg = '1' then
                     hFire := '1';                       -- row 4: no enq
                  elsif dsOutQFull = '0' then
                     hFire := '1';                       -- rows 3 / 5: enq
                  end if;
               end if;

               if hFire = '1' then
                  headerPipeInRdEn <= '1';

                  if hFragIsLast = '0' then
                     -- row 3: non-last header fragment -> stream it out as-is
                     v.isFirstReg       := '0';
                     v.headerFragCntReg := std_logic_vector(unsigned(r.headerFragCntReg) - 1);
                     dsOutQWrEn         <= '1';
                     dsOutQDin          <= headerPipeInData;   -- raw frag
                  else
                     -- rows 4 / 5: last header fragment.  Stash a right-shifted
                     -- residue into preDataStreamReg; isLast := !headerHasPayloadReg.
                     hRsData := std_logic_vector(shift_right(
                        unsigned(headerPipeInData(289 downto 34)),
                        to_integer(unsigned(r.headerLastFragInvalidBitNumReg))));
                     hRsByteEn := std_logic_vector(shift_right(
                        unsigned(headerPipeInData(33 downto 2)),
                        to_integer(unsigned(r.headerLastFragInvalidByteNumReg))));

                     v.preDataStreamReg := hRsData                       -- data
                                         & hRsByteEn                     -- byteEn
                                         & hFragIsFirst                  -- isFirst
                                         & (not r.headerHasPayloadReg);  -- isLast

                     if r.headerHasPayloadReg = '1' then
                        -- row 4: header has payload -> go merge it, no enq
                        v.stageReg := DATA_OUTPUT_S;
                     else
                        -- row 5: header has no payload -> emit raw last frag, done
                        v.stageReg := HEADER_META_DATA_POP_S;
                        dsOutQWrEn <= '1';
                        dsOutQDin  <= headerPipeInData;   -- raw frag (NOT shifted)
                     end if;
                  end if;
               end if;

            -- ============================================================
            -- DATA_OUTPUT_S : outputData
            --   implicit cond: dataPipeInValid='1' AND dsOutQFull='0' (always enqs)
            --   All register reads are OLD (r) values (BSV rule semantics).
            -- ============================================================
            when DATA_OUTPUT_S =>
               if dataPipeInValid = '1' and dsOutQFull = '0' then
                  dFragIsLast := dataPipeInData(0);

                  -- lastFragByteEn = truncate(frag.byteEn << invalidByteNum)
                  --   (Bit#(32) << keeps width 32; truncate is identity)
                  dLastFragByteEn := std_logic_vector(shift_left(
                     unsigned(dataPipeInData(33 downto 2)),
                     to_integer(unsigned(r.headerLastFragInvalidByteNumReg))));
                  -- noExtraLastFrag = isZeroByteEn(lastFragByteEn)
                  if unsigned(dLastFragByteEn) = 0 then
                     dNoExtraLast := '1';
                  else
                     dNoExtraLast := '0';
                  end if;

                  -- tmpData   = ({preDataStreamReg.data,  frag.data}  >> validBitNum)
                  -- tmpByteEn = ({preDataStreamReg.byteEn,frag.byteEn}>> validByteNum)
                  -- BSV {MSB-operand, LSB-operand}: pre = high half, frag = low half
                  dDataCat   := r.preDataStreamReg(289 downto 34) & dataPipeInData(289 downto 34);
                  dByteEnCat := r.preDataStreamReg(33 downto 2)    & dataPipeInData(33 downto 2);
                  dTmpData   := std_logic_vector(shift_right(unsigned(dDataCat),
                                   to_integer(unsigned(r.headerLastFragValidBitNumReg))));
                  dTmpByteEn := std_logic_vector(shift_right(unsigned(dByteEnCat),
                                   to_integer(unsigned(r.headerLastFragValidByteNumReg))));

                  -- outDS: data/byteEn = truncate (low bits); isFirst = OLD
                  -- r.isFirstReg; isLast = frag.isLast AND noExtraLastFrag
                  dOutDS := dTmpData(255 downto 0)          -- data   [289:34]
                          & dTmpByteEn(31 downto 0)         -- byteEn  [33:2]
                          & r.isFirstReg                    -- isFirst [1]
                          & (dFragIsLast and dNoExtraLast); -- isLast  [0]

                  dataPipeInRdEn <= '1';
                  dsOutQWrEn     <= '1';
                  dsOutQDin      <= dOutDS;

                  -- write-after-read: latch the raw frag and clear isFirst
                  v.preDataStreamReg := dataPipeInData;
                  v.isFirstReg       := '0';

                  if dFragIsLast = '1' then
                     if dNoExtraLast = '1' then
                        v.stageReg := HEADER_META_DATA_POP_S;
                     else
                        v.stageReg := EXTRA_LAST_FRAG_OUTPUT_S;
                     end if;
                  end if;
               end if;

            -- ============================================================
            -- EXTRA_LAST_FRAG_OUTPUT_S : extraLastFrag
            --   implicit cond: dsOutQFull='0' (always enqs; no upstream read)
            -- ============================================================
            when EXTRA_LAST_FRAG_OUTPUT_S =>
               if dsOutQFull = '0' then
                  -- leftShiftData  = truncate(preDataStreamReg.data  << invalidBitNum)
                  -- leftShiftByteEn= truncate(preDataStreamReg.byteEn<< invalidByteNum)
                  eLeftData := std_logic_vector(shift_left(
                     unsigned(r.preDataStreamReg(289 downto 34)),
                     to_integer(unsigned(r.headerLastFragInvalidBitNumReg))));
                  eLeftByteEn := std_logic_vector(shift_left(
                     unsigned(r.preDataStreamReg(33 downto 2)),
                     to_integer(unsigned(r.headerLastFragInvalidByteNumReg))));

                  eExtraDS := eLeftData     -- data   [289:34]
                            & eLeftByteEn   -- byteEn  [33:2]
                            & '0'           -- isFirst [1]
                            & '1';          -- isLast  [0]

                  dsOutQWrEn <= '1';
                  dsOutQDin  <= eExtraDS;
                  v.stageReg := HEADER_META_DATA_POP_S;
               end if;

         end case;

      end if;

      -- Synchronous reset (stageReg = mkReg(HEADER_META_DATA_POP))
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
   -- Simulation-only assertions (BSV immAssert calls; no synthesizable effect).
   --   popHeaderMetaData: when isEmptyHeader, validBitNum and validByteNum must
   --                      be zero; else headerLen must be non-zero.
   --   outputHeader     : on the last header fragment, headerFragCntReg must be 0.
   ---------------------------------------------------------------------------
   -- pragma translate_off
   check : process (clk) is
   begin
      if rising_edge(clk) then
         if rst = '0' and clearAllI = '0' then
            if (r.stageReg = HEADER_META_DATA_POP_S and headerMetaPipeInValid = '1') then
               if headerMetaPipeInData(0) = '1' then    -- isEmptyHeader
                  assert unsigned(headerMetaPipeInData(7 downto 2)) = 0
                     report "PrependHeader2PipeOut: lastFragValidByteNum must be 0 "
                          & "when isEmptyHeader"
                     severity error;
               else
                  assert unsigned(headerMetaPipeInData(16 downto 10)) /= 0
                     report "PrependHeader2PipeOut: headerLen must be non-zero "
                          & "when not isEmptyHeader"
                     severity error;
               end if;
            end if;
            if (r.stageReg = HEADER_OUTPUT_S and headerPipeInValid = '1'
                and headerPipeInData(0) = '1') then     -- last header fragment
               assert unsigned(r.headerFragCntReg) = 0
                  report "PrependHeader2PipeOut: headerFragCntReg must be 0 on the "
                       & "last header fragment"
                  severity error;
            end if;
         end if;
      end if;
   end process check;
   -- pragma translate_on

end architecture rtl;
