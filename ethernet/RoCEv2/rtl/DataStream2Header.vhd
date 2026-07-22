-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Structural inverse of Header2DataStream.  Re-accumulates a sequence of
--   256-bit DataStream flits back into a single packed 593-bit HeaderRDMA word
--   and enqueues it into U_HeaderOutQ, which is exposed as the returned
--   PipeOut#(HeaderRDMA) interface (headerOutQValid/Dout/RdEn).
--
--   Two input pipes are consumed (both opaque PipeOut arguments at the BSV call
--   site — NOT FIFOs instantiated here):
--     dataPipeIn            : DataStreamPipeOut   (290-bit DataStream flits)
--     headerMetaDataPipeIn  : PipeOut#(HeaderMetaData)  (17-bit meta word)
--
--   FSM states (mapped from BSV busyReg : Reg#(Bool) <- mkReg(False)):
--     IDLE_S ('0') — waiting to pop the HeaderMetaData for the next header
--     BUSY_S ('1') — accumulating DataStream flits until isLast
--
--   BSV rules implemented:
--     popHeaderMetaData (guard !busyReg) — IDLE_S row: latch HeaderMetaData,
--                        deq headerMetaDataPipeIn, go BUSY_S.
--     accumulate        (guard  busyReg) — BUSY_S rows: shift each DataStream
--                        fragment into the header accumulator; on isLast,
--                        left-align and enqueue the completed HeaderRDMA.
--
--   Mapping note (OQ-FSM-DS2H-01, see fsm.md §mismatch):
--     mapping.json / inventory describe an unrelated header/payload-split shape
--     (two outputs, payloadQ, rule `extract`).  They are WRONG for this entity;
--     this file follows DataStream2Header.fsm.md, which is authoritative.
--
--   Width / packing resolutions applied:
--     - DataStream width = 290 bits           (OQ-FSM-H2DS-02 RESOLVED)
--     - HeaderRDMA / HeaderMetaData packing is first-field-at-MSB
--                                              (OQ-FSM-H2DS-04 / DS2H-05 RESOLVED)
--     - hdrInvalidFragBitNumReg / hdrInvalidFragByteNumReg ELIMINATED
--       (OQ-FSM-DS2H-02 RESOLVED): the final isLast left-shift is specialized
--       into the FSM per the HEADER_MAX_FRAG_NUM=2 invariant, mirroring
--       Header2DataStream's prepend side — no runtime barrel shifter, no
--       HeaderBitNum-width register.  The shift amount (0 or 256 b) is fully
--       determined by which completing row fires:
--         row 3 (1-frag header, isFirst=isLast=1) → shift 256 → frag to high half
--         row 4 (2nd of 2-frag header, isLast=1)  → shift 0   → already aligned
--
--   Reset convention (judgment call, see report):
--     The fsm.md Inputs table notes "rst_n async active-low".  This file uses
--     active-high SYNCHRONOUS rst to stay consistent with the sibling
--     Header2DataStream and with the surf.Fifo config used project-wide
--     (RST_POLARITY_G='1', RST_ASYNC_G=false).  busyReg is mkReg(False) →
--     synchronous reset, matching this choice.  There is NO software clear in
--     this module (no resetAndClear rule), so no clearAllI port exists.
--
--   SURF components instantiated:
--     U_HeaderOutQ : surf.Fifo
--       DATA_WIDTH_G=593, FWFT, sync, distributed RAM (wide word; 1-cycle cold
--       latency, DOB reg) — source: surf/base/fifo/rtl/Fifo.vhd
--
--   Scheduling / atomicity (fsm.md §scheduling):
--     accumulate's headerOutQ.enq is conditional (isLast branch) but BSV
--     all-or-nothing rule firing means the WHOLE rule (incl. dataPipeIn.deq)
--     does not fire when isLast='1' AND headerOutQFull='1'.  Modelled here by
--     gating dataPipeInRdEn AND every register update of the completing rows on
--     headerOutQFull='0' — NOT merely gating headerOutQWrEn (would deq and lose
--     the fragment while the output FIFO is full).
--
--   DataStream bit layout (BSV deriving(Bits), first-field-at-MSB):
--     [289:34] data[255:0]   (256 bits)
--     [33:2]   byteEn[31:0]  (32 bits)
--     [1]      isFirst
--     [0]      isLast
--
--   HeaderRDMA bit layout (BSV deriving(Bits), first-field-at-MSB):
--     [592:81] headerData[511:0]   (512 bits)
--     [80:17]  headerByteEn[63:0]  (64 bits)
--     [16:10]  headerLen[6:0]
--     [9:8]    headerFragNum[1:0]   (OVERWRITTEN with running count on enqueue)
--     [7:2]    lastFragValidByteNum[5:0]
--     [1]      hasPayload
--     [0]      isEmptyHeader
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

entity DataStream2Header is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk : in sl;
      rst : in sl;                                 -- active-high synchronous reset
      -- Upstream: DataStream pipe (dataPipeIn, 290 b per beat)
      dataPipeInValid        : in  sl;             -- dataPipeIn.notEmpty
      dataPipeInData         : in  slv(289 downto 0);  -- dataPipeIn.first
      dataPipeInRdEn         : out sl;             -- dataPipeIn.deq
      -- Upstream: HeaderMetaData pipe (headerMetaDataPipeIn, 17 b)
      hdrMetaDataPipeInValid : in  sl;             -- headerMetaDataPipeIn.notEmpty
      hdrMetaDataPipeInData  : in  slv(16 downto 0);   -- headerMetaDataPipeIn.first
      hdrMetaDataPipeInRdEn  : out sl;             -- headerMetaDataPipeIn.deq
      -- Downstream: returned PipeOut#(HeaderRDMA) (read side of U_HeaderOutQ)
      headerOutQValid        : out sl;             -- PipeOut.notEmpty
      headerOutQDout         : out slv(592 downto 0);  -- PipeOut.first
      headerOutQRdEn         : in  sl);            -- PipeOut.deq
end entity DataStream2Header;

architecture rtl of DataStream2Header is

   -- FSM state type (maps BSV busyReg: False→IDLE_S, True→BUSY_S)
   type StateType is (IDLE_S, BUSY_S);

   type RegType is record
      state          : StateType;
      rdmaHdrData    : slv(511 downto 0);  -- mkRegU — accumulating headerData
      rdmaHdrByteEn  : slv(63 downto 0);   -- mkRegU — accumulating headerByteEn
      rdmaHdrFragNum : slv(1 downto 0);    -- mkRegU — running accumulated frag count
      hdrMetaDataReg : slv(16 downto 0);   -- mkRegU — latched HeaderMetaData
   end record RegType;

   -- mkRegU fields set to '0' in REG_INIT_C: every one is written in IDLE_S /
   -- the first BUSY_S fire before being read on completion (no correctness risk).
   constant REG_INIT_C : RegType := (
      state          => IDLE_S,
      rdmaHdrData    => (others => '0'),
      rdmaHdrByteEn  => (others => '0'),
      rdmaHdrFragNum => (others => '0'),
      hdrMetaDataReg => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- U_HeaderOutQ control signals (internal; driven by comb process)
   signal headerOutQFull : sl;
   signal headerOutQWrEn : sl;
   signal headerOutQDin  : slv(592 downto 0);

   -- Zero-padding constants for the left-align (isLast) shift specialization
   constant ZERO_256_C : slv(255 downto 0) := (others => '0');
   constant ZERO_32_C  : slv(31 downto 0)  := (others => '0');

begin

   ---------------------------------------------------------------------------
   -- U_HeaderOutQ : surf.Fifo
   --   Holds completed HeaderRDMA words; its read side IS the returned
   --   PipeOut#(HeaderRDMA) interface.  DATA_WIDTH_G=593, FWFT, sync, distributed RAM.
   --   rst wired directly (no software clear in this module).
   ---------------------------------------------------------------------------
   U_HeaderOutQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 593,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => rst,
         wr_clk        => clk,
         wr_en         => headerOutQWrEn,
         din           => headerOutQDin,
         full          => headerOutQFull,
         not_full      => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => headerOutQRdEn,
         dout          => headerOutQDout,
         valid         => headerOutQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- Combinatorial process
   ---------------------------------------------------------------------------
   comb : process (r, rst,
                   dataPipeInValid, dataPipeInData,
                   hdrMetaDataPipeInValid, hdrMetaDataPipeInData,
                   headerOutQFull) is
      variable v           : RegType;
      variable fragData    : slv(255 downto 0);
      variable fragByteEn  : slv(31 downto 0);
      variable fragIsFirst : sl;
      variable fragIsLast  : sl;
   begin
      v := r;

      -- default Mealy outputs (deasserted; overridden below per transition)
      dataPipeInRdEn        <= '0';
      hdrMetaDataPipeInRdEn <= '0';
      headerOutQWrEn        <= '0';
      headerOutQDin         <= (others => '0');

      -- DataStream field aliases (see bit layout in header)
      fragData    := dataPipeInData(289 downto 34);
      fragByteEn  := dataPipeInData(33 downto 2);
      fragIsFirst := dataPipeInData(1);
      fragIsLast  := dataPipeInData(0);

      case r.state is

         -- ---------------------------------------------------------------
         -- IDLE_S: popHeaderMetaData (guard !busyReg)
         --   Latch the HeaderMetaData for the header about to arrive, deq the
         --   meta pipe, advance to BUSY_S.  Touches neither dataPipeIn nor
         --   headerOutQ.  hdrInvalidFrag* precompute is eliminated (DS2H-02).
         -- ---------------------------------------------------------------
         when IDLE_S =>
            if hdrMetaDataPipeInValid = '1' then
               hdrMetaDataPipeInRdEn <= '1';
               v.hdrMetaDataReg      := hdrMetaDataPipeInData;
               v.state               := BUSY_S;
            end if;

         -- ---------------------------------------------------------------
         -- BUSY_S: accumulate (guard busyReg)
         --   Base guard for all rows: dataPipeInValid='1'.
         -- ---------------------------------------------------------------
         when BUSY_S =>
            if dataPipeInValid = '1' then

               -- Row 1: isFirst='1', isLast='0' — first of a 2-fragment header.
               --   zeroExtend: fragment lands in the LOW half; stay BUSY_S.
               if fragIsFirst = '1' and fragIsLast = '0' then
                  v.rdmaHdrData    := ZERO_256_C & fragData;
                  v.rdmaHdrByteEn  := ZERO_32_C & fragByteEn;
                  v.rdmaHdrFragNum := "01";
                  dataPipeInRdEn   <= '1';

               -- Row 3: isFirst='1', isLast='1' — 1-fragment header, completes.
               --   isLast shift = 256 b (1 invalid frag) specialized as slice +
               --   zero-pad: frag moves to the HIGH (left-aligned) half.
               --   Gated on !headerOutQFull (all-or-nothing, see header).
               elsif fragIsFirst = '1' and fragIsLast = '1' then
                  if headerOutQFull = '0' then
                     headerOutQWrEn <= '1';
                     headerOutQDin  <= (fragData & ZERO_256_C)          -- headerData [592:81]
                                     & (fragByteEn & ZERO_32_C)         -- headerByteEn [80:17]
                                     & r.hdrMetaDataReg(16 downto 10)   -- headerLen [16:10]
                                     & "01"                             -- headerFragNum [9:8] = running count
                                     & r.hdrMetaDataReg(7 downto 0);    -- lastFragValidByteNum/hasPayload/isEmptyHeader [7:0]
                     dataPipeInRdEn <= '1';
                     v.state        := IDLE_S;
                  end if;

               -- Row 4: isFirst='0', isLast='1' — 2nd of a 2-fragment header,
               --   completes.  isLast shift = 0 (no invalid frag): the
               --   shift-in accumulator already left-aligns it.
               --   Gated on !headerOutQFull.
               elsif fragIsFirst = '0' and fragIsLast = '1' then
                  if headerOutQFull = '0' then
                     headerOutQWrEn <= '1';
                     headerOutQDin  <= (r.rdmaHdrData(255 downto 0) & fragData)      -- headerData [592:81]
                                     & (r.rdmaHdrByteEn(31 downto 0) & fragByteEn)   -- headerByteEn [80:17]
                                     & r.hdrMetaDataReg(16 downto 10)                -- headerLen [16:10]
                                     & slv(unsigned(r.rdmaHdrFragNum) + 1)           -- headerFragNum [9:8] = "10"
                                     & r.hdrMetaDataReg(7 downto 0);                 -- [7:0]
                     dataPipeInRdEn <= '1';
                     v.state        := IDLE_S;
                  end if;

               -- Row 5: isFirst='0', isLast='0' — STRUCTURALLY UNREACHABLE under
               --   HEADER_MAX_FRAG_NUM=2 / DATA_BUS_WIDTH=256 (OQ-FSM-DS2H-03).
               --   Implemented for source fidelity (the BSV else arm): shift-in
               --   accumulate, stay BUSY_S.  Dead in the current build.
               else
                  v.rdmaHdrData    := r.rdmaHdrData(255 downto 0) & fragData;
                  v.rdmaHdrByteEn  := r.rdmaHdrByteEn(31 downto 0) & fragByteEn;
                  v.rdmaHdrFragNum := slv(unsigned(r.rdmaHdrFragNum) + 1);
                  dataPipeInRdEn   <= '1';
               end if;

            end if;

      end case;

      -- Synchronous reset (matches BSV mkReg(False) for busyReg)
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
   -- Simulation-only assertions (OQ-FSM-DS2H-04): BSV immAssert calls have no
   -- synthesizable effect.  Emitted under translate_off for Stage 5 value.
   ---------------------------------------------------------------------------
   -- pragma translate_off
   check : process (clk) is
   begin
      if rising_edge(clk) then
         if rst = '0' then
            -- popHeaderMetaData immAssert: headerLen (meta[16:10]) must be /= 0
            if (r.state = IDLE_S and hdrMetaDataPipeInValid = '1') then
               assert hdrMetaDataPipeInData(16 downto 10) /= "0000000"
                  report "DataStream2Header: headerLen must be non-zero"
                  severity error;
            end if;
            -- accumulate immAsserts (completing fire): running headerFragNum must
            -- equal the expected value latched in hdrMetaDataReg(9:8), and
            -- genByteEn(headerLastFragValidByteNum) must equal fragByteEn.
            -- TODO(OQ-FSM-DS2H-04): the genByteEn(...) == fragByteEn check needs
            -- the BSV genByteEn helper; left as a TODO rather than an incorrect
            -- assertion.  The fragNum-match check is asserted below.
            if (r.state = BUSY_S and dataPipeInValid = '1'
                and dataPipeInData(0) = '1' and headerOutQFull = '0') then
               if dataPipeInData(1) = '1' then          -- 1-frag header (row 3)
                  assert r.hdrMetaDataReg(9 downto 8) = "01"
                     report "DataStream2Header: 1-frag header fragNum mismatch"
                     severity error;
               else                                     -- 2-frag header (row 4)
                  assert r.hdrMetaDataReg(9 downto 8) = slv(unsigned(r.rdmaHdrFragNum) + 1)
                     report "DataStream2Header: 2-frag header fragNum mismatch"
                     severity error;
               end if;
            end if;
         end if;
      end if;
   end process check;
   -- pragma translate_on

end architecture rtl;
