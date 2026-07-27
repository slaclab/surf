-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Accepts a packed HeaderRDMA word from an upstream pipe (headerPipeIn)
--   and serialises it into at most two 256-bit DataStream flits, writing them
--   into U_HdrDataStreamQ.  Simultaneously pushes a 17-bit HeaderMetaData
--   word into U_HdrMetaDataQ.
--
--   FSM states (mapped from BSV headerValidReg):
--     IDLE_S ('0') — waiting for a new header
--     BUSY_S ('1') — emitting the second flit of a 2-fragment header
--
--   BSV rules implemented:
--     resetAndClear — no_implicit_conditions; fires every cycle while
--                     clearAllI='1'; clears both FIFOs via rst, sets IDLE_S.
--     outputHeader  — base guard: !clearAllI AND hdrPipeInValid='1';
--                     IDLE_S handles the three IDLE sub-cases; BUSY_S emits
--                     the second (last) flit.
--
--   Mapping note (OQ-FSM-H2DS-01, see fsm.md §mismatch):
--     mapping.json records one output FIFO and wrong port/state names; this
--     file is authoritative.  DataStream width = 290 bits (OQ-FSM-H2DS-02,
--     RESOLVED).  HeaderRDMA packing is first-field-at-MSB (OQ-FSM-H2DS-04,
--     RESOLVED).
--
--   SURF components instantiated:
--     U_HdrDataStreamQ : surf.Fifo
--       DATA_WIDTH_G=290, FWFT, sync, distributed RAM (1-cycle cold latency)
--       source: surf/base/fifo/rtl/Fifo.vhd
--     U_HdrMetaDataQ   : surf.Fifo
--       DATA_WIDTH_G=17,  FWFT, sync, distributed RAM (1-cycle cold latency)
--       source: surf/base/fifo/rtl/Fifo.vhd
--
--   FIFO clear (OQ-FSM-H2DS-03, resolved via OQ-FSM-06 in RESOLVED.md):
--     hdrDataStreamQRst / hdrMetaDataQRst are driven as levels:
--       fifoRst = rst OR clearAllI
--     surf.FifoSync holds logically empty for the entire asserted window;
--     no pulse generator is needed.
--
--   Scheduling note (fsm.md §scheduling):
--     hdrPipeInValid is required in BOTH IDLE_S and BUSY_S because the BSV
--     source reads headerPipeIn.first unconditionally in the BUSY branch
--     (peek-ahead).  The FSM stalls in BUSY_S until the next header arrives.
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
--     [9:8]    headerFragNum[1:0]
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

entity Header2DataStream is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk                : in  sl;
      rst                : in  sl;      -- active-high synchronous reset
      -- Software clear (synchronous; fires every cycle while asserted)
      clearAllI          : in  sl;
      -- Upstream: packed HeaderRDMA pipe (headerPipeIn)
      hdrPipeInValid     : in  sl;      -- headerPipeIn.notEmpty
      hdrPipeInData      : in  slv(592 downto 0);  -- headerPipeIn.first
      hdrPipeInRdEn      : out sl;  -- headerPipeIn.deq (asserted on isLast)
      -- Downstream: headerDataStream (DataStream, 290 b per beat)
      hdrDataStreamValid : out sl;      -- headerDataStream.notEmpty
      hdrDataStreamDout  : out slv(289 downto 0);  -- headerDataStream.first
      hdrDataStreamRdEn  : in  sl;      -- headerDataStream.deq
      -- Downstream: headerMetaData (HeaderMetaData, 17 b, one per header)
      hdrMetaDataValid   : out sl;      -- headerMetaData.notEmpty
      hdrMetaDataDout    : out slv(16 downto 0);   -- headerMetaData.first
      hdrMetaDataRdEn    : in  sl);     -- headerMetaData.deq
end entity Header2DataStream;

architecture rtl of Header2DataStream is

   -- FSM state type (maps BSV headerValidReg: False→IDLE_S, True→BUSY_S)
   type StateType is (IDLE_S, BUSY_S);

   type RegType is record
      state       : StateType;
      rdmaHdrData : slv(511 downto 0);  -- mkRegU — left-aligned remaining header data
      rdmaHdrByEn : slv(63 downto 0);  -- mkRegU — left-aligned remaining byte enables
      fragCnt     : slv(1 downto 0);    -- mkRegU — remaining fragment count
   end record RegType;

   -- mkRegU fields set to '0' in REG_INIT_C (written before read; no correctness risk)
   constant REG_INIT_C : RegType := (
      state       => IDLE_S,
      rdmaHdrData => (others => '0'),
      rdmaHdrByEn => (others => '0'),
      fragCnt     => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- FIFO control signals (internal; driven by comb process)
   signal hdrDataStreamQFull : sl;
   signal hdrDataStreamQWrEn : sl;
   signal hdrDataStreamQDin  : slv(289 downto 0);
   signal hdrMetaDataQFull   : sl;
   signal hdrMetaDataQWrEn   : sl;
   signal hdrMetaDataQDin    : slv(16 downto 0);

   -- FIFO reset lines: level = rst OR clearAllI (see FIFO clear note above)
   signal hdrDataStreamQRst : sl;
   signal hdrMetaDataQRst   : sl;

   -- Internal copy of hdrPipeInRdEn (avoids driving output port from process)
   signal hdrPipeInRdEn_i : sl;

   -- Zero-padding constants for the left-shift operation
   constant ZERO_256_C : slv(255 downto 0) := (others => '0');
   constant ZERO_32_C  : slv(31 downto 0)  := (others => '0');

begin

   -- FIFO reset: level-sensitive clear (OQ-FSM-H2DS-03 / OQ-FSM-06 RESOLVED)
   hdrDataStreamQRst <= rst or clearAllI;
   hdrMetaDataQRst   <= rst or clearAllI;
   hdrPipeInRdEn     <= hdrPipeInRdEn_i;

   ---------------------------------------------------------------------------
   -- U_HdrDataStreamQ : surf.Fifo
   --   Carries DataStream flits to the headerDataStream output interface.
   --   DATA_WIDTH_G=290 (256+32+1+1), FWFT, sync, distributed RAM.
   ---------------------------------------------------------------------------
   U_HdrDataStreamQ : entity surf.Fifo
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
         rst           => hdrDataStreamQRst,
         wr_clk        => clk,
         wr_en         => hdrDataStreamQWrEn,
         din           => hdrDataStreamQDin,
         full          => hdrDataStreamQFull,
         not_full      => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => hdrDataStreamRdEn,
         dout          => hdrDataStreamDout,
         valid         => hdrDataStreamValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_HdrMetaDataQ : surf.Fifo
   --   Carries HeaderMetaData words to the headerMetaData output interface.
   --   DATA_WIDTH_G=17 (7+2+6+1+1), FWFT, sync, distributed RAM.
   ---------------------------------------------------------------------------
   U_HdrMetaDataQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 17,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => hdrMetaDataQRst,
         wr_clk        => clk,
         wr_en         => hdrMetaDataQWrEn,
         din           => hdrMetaDataQDin,
         full          => hdrMetaDataQFull,
         not_full      => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => hdrMetaDataRdEn,
         dout          => hdrMetaDataDout,
         valid         => hdrMetaDataValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- Combinatorial process
   ---------------------------------------------------------------------------
   comb : process (r, rst, clearAllI,
                   hdrPipeInValid, hdrPipeInData,
                   hdrDataStreamQFull, hdrMetaDataQFull) is
      variable v : RegType;
   begin
      v := r;

      -- default Mealy outputs (deasserted; overridden below per transition)
      hdrPipeInRdEn_i    <= '0';
      hdrDataStreamQWrEn <= '0';
      hdrDataStreamQDin  <= (others => '0');
      hdrMetaDataQWrEn   <= '0';
      hdrMetaDataQDin    <= (others => '0');

      -- resetAndClear (no_implicit_conditions, fire_when_enabled):
      --   fires every cycle while clearAllI='1'; FIFOs cleared via rst pins;
      --   stateReg forced to IDLE_S.  Mutually exclusive with outputHeader.
      if clearAllI = '1' then
         v.state := IDLE_S;

      -- outputHeader (conflict_free):
      --   base guard = !clearAllI AND hdrPipeInValid='1'
      --   hdrPipeInValid required in BOTH states (BSV peek-ahead scheduling;
      --   see fsm.md §scheduling note).
      elsif hdrPipeInValid = '1' then

         case r.state is

            -- ---------------------------------------------------------------
            -- IDLE_S: examine incoming HeaderRDMA word; three sub-cases
            -- ---------------------------------------------------------------
            when IDLE_S =>

               -- Sub-case A: 2-fragment header (fragNum=2), not empty
               --   → emit first DataStream flit (isFirst='1', isLast='0'),
               --     store second fragment in RegType, advance to BUSY_S.
               --   No deq of headerPipeIn yet (more flits to come).
               if hdrMetaDataQFull = '0' and hdrDataStreamQFull = '0'
                  and hdrPipeInData(0) = '0'            -- isEmptyHeader=false
                  and hdrPipeInData(9 downto 8) = "10"  -- headerFragNum=2
               then
                  hdrMetaDataQWrEn   <= '1';
                  hdrMetaDataQDin    <= hdrPipeInData(16 downto 0);
                  hdrDataStreamQWrEn <= '1';
                  -- data[289:34]=hdrData_msb, byteEn[33:2]=hdrByEn_msb,
                  -- isFirst[1]='1', isLast[0]='0'
                  hdrDataStreamQDin  <= hdrPipeInData(592 downto 337)  -- 256 b
                                       & hdrPipeInData(80 downto 49)   --  32 b
                                       & '1' & '0';     --   2 b
                  -- Shift headerData/headerByteEn left by DATA_BUS_WIDTH (256 b)
                  -- using truncate: keep lower half, zero-pad the vacated upper half
                  v.rdmaHdrData := hdrPipeInData(336 downto 81) & ZERO_256_C;
                  v.rdmaHdrByEn := hdrPipeInData(48 downto 17) & ZERO_32_C;
                  v.fragCnt     := "01";                -- fragNum(2) - 1 = 1
                  v.state       := BUSY_S;
                  -- hdrPipeInRdEn stays '0'

               -- Sub-case B: 1-fragment header (fragNum=1), not empty
               --   → emit single DataStream flit (isFirst='1', isLast='1'),
               --     deq headerPipeIn, stay in IDLE_S.
               elsif hdrMetaDataQFull = '0' and hdrDataStreamQFull = '0'
                  and hdrPipeInData(0) = '0'            -- isEmptyHeader=false
                  and hdrPipeInData(9 downto 8) = "01"  -- headerFragNum=1
               then
                  hdrMetaDataQWrEn   <= '1';
                  hdrMetaDataQDin    <= hdrPipeInData(16 downto 0);
                  hdrDataStreamQWrEn <= '1';
                  hdrDataStreamQDin  <= hdrPipeInData(592 downto 337)
                                       & hdrPipeInData(80 downto 49)
                                       & '1' & '1';
                  hdrPipeInRdEn_i <= '1';

               -- Sub-case C: empty header (isEmptyHeader=1)
               --   → push HeaderMetaData only; no DataStream flit;
               --     deq headerPipeIn, stay in IDLE_S.
               elsif hdrMetaDataQFull = '0'
                  and hdrPipeInData(0) = '1'  -- isEmptyHeader=true
               then
                  hdrMetaDataQWrEn <= '1';
                  hdrMetaDataQDin  <= hdrPipeInData(16 downto 0);
                  hdrPipeInRdEn_i  <= '1';
               end if;

            -- ---------------------------------------------------------------
            -- BUSY_S: emit second (last) DataStream flit from RegType
            -- Structural invariant: HEADER_MAX_FRAG_NUM=2 → fragCnt always 1
            -- here, so isLast='1' unconditionally; BUSY_S exits in one cycle.
            -- ---------------------------------------------------------------
            when BUSY_S =>
               if hdrDataStreamQFull = '0' then
                  hdrDataStreamQWrEn <= '1';
                  -- data[289:34]=MSB 256b of saved data,
                  -- byteEn[33:2]=MSB 32b of saved byteEn,
                  -- isFirst[1]='0', isLast[0]='1'
                  hdrDataStreamQDin  <= r.rdmaHdrData(511 downto 256)
                                       & r.rdmaHdrByEn(63 downto 32)
                                       & '0' & '1';
                  hdrPipeInRdEn_i <= '1';
                  v.state         := IDLE_S;
               end if;

         end case;
      end if;

      -- Synchronous reset (overrides FSM; matches BSV mkReg(False) for stateReg)
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
