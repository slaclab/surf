-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Thin front-end splitter / fan-out wrapper around the child
--   ExtractHeaderFromDataStreamPipeOut.  Takes ONE incoming RDMA-packet
--   DataStream pipe (rdmaPktPipeIn, header bytes left-aligned at the front of
--   the first fragment) and:
--     1. forwards every fragment verbatim into U_DataInQ;
--     2. on the FIRST fragment only, decodes the BTH {transType, rdmaOpCode}
--        field, looks up the header byte length + has-payload flag, builds a
--        17-bit HeaderMetaData token and pushes it into U_HeaderMetaDataInQ;
--     3. fans the metadata token out 2 ways (U_Fork, replicate-with-join):
--          copy[0] → child U_ExtractDS.headerMetaDataPipeIn (unbuffered)
--          copy[1] → U_HeaderMetaDataBuf → exposed headerMetaData PipeOut
--     4. instantiates the child extractor U_ExtractDS, fed by U_DataInQ and
--        fork copy[0]; its header/payload outputs pass straight through to this
--        module's interface.
--
--   ALL header/payload byte-splitting is done by the CHILD entity. This module
--   does NOT touch payload data; it only routes fragments + emits the metadata
--   token (it is mkForkAndBufferRight on the metadata stream + the opcode decode).
--
--   Mapping note (OQ-FSM-EHRPPO-01): mapping.json/modules.json are STALE for this
--   entity (owns.rules=["extract"]→actual "extractHeader"; a bogus single "outQ"
--   Fifo; interface PipeOut#(RdmaHeader)→actual
--   HeaderAndMetaDataAndPayloadSeperateDataStreamPipeOut). The BSV source +
--   fsm.md are authoritative; this file follows them, not mapping.json.
--
--   Width notes (traced from DataTypes.bsv / Headers.bsv / Settings.bsv):
--     DataStream     = 290 b  (data 256 + byteEn 32 + isFirst 1 + isLast 1)
--     HeaderMetaData =  17 b  (headerLen 7 + headerFragNum 2 +
--                       lastFragValidByteNum 6 + hasPayload 1 + isEmptyHeader 1)
--     DATA_BUS_WIDTH = 256, DATA_BUS_BYTE_WIDTH = 32 (5-bit byte index)
--     TransType  = 3 b  (data[255:253] of first frag)
--     RdmaOpCode = 5 b  (data[252:248] of first frag)
--
--   Bit packing (BSV deriving(Bits), first-field-at-MSB; project-wide
--   OQ-FSM-H2DS-04):
--     DataStream:      [289:34]=data  [33:2]=byteEn  [1]=isFirst  [0]=isLast
--     HeaderMetaData:  [16:10]=headerLen  [9:8]=headerFragNum
--                      [7:2]=lastFragValidByteNum  [1]=hasPayload  [0]=isEmptyHeader
--
--   Decode datapath (faithful to Utils.bsv / Headers.bsv, isFirst path only):
--     extractTranTypeAndRdmaOpCode : transType = data[255:253],
--                                    rdmaOpCode = data[252:248]   (Utils.bsv:840)
--     rdmaOpCodeHasPayload(opcode) : LUT on the 5-bit opcode      (Headers.bsv:407)
--     calcHeaderLenByTransTypeAndRdmaOpCode(transType, opcode) :
--          ROM keyed on the 8-bit {transType, opcode}             (Headers.bsv:286)
--          (BTH=12 + optional XRCETH=4/RETH=16/AETH=4/IMM_DT=4/IETH=4/DETH=8/
--           ATOMIC_ETH=28/ATOMIC_ACK_ETH=8/CNP_PAYLOAD=16; default 0)
--     genHeaderMetaData(headerLen, hasPayload)                    (Utils.bsv:303)
--          headerFragNum        = headerLen[6:5] + (headerLen[4:0]/=0 ? 1 : 0)
--          lastFragValidByteNum = (residue==0 && headerLen[6:5]/=0) ? 32
--                                                                  : zeroExt(residue)
--          isEmptyHeader        = '0' (constant)
--     The BSV immAssert(!isZero(headerLen)) is simulation-only and is NOT
--     emitted (synthesis drops it); an unknown opcode yields headerLen=0.
--
--   SURF components instantiated (read at emit from the .vhd source):
--     U_DataInQ            : surf.Fifo  (DATA_WIDTH_G=290, FWFT, sync, block)
--       source: surf/base/fifo/rtl/Fifo.vhd  (BSV: dataInQ <- mkFIFOF;
--       read side owned by the child U_ExtractDS.dataPipeIn)
--     U_HeaderMetaDataInQ  : surf.Fifo  (DATA_WIDTH_G=17, FWFT, sync, dist)
--       source: surf/base/fifo/rtl/Fifo.vhd  (BSV: headerMetaDataInQ <- mkFIFOF;
--       read side owned by U_Fork)
--     U_HeaderMetaDataBuf  : surf.Fifo  (DATA_WIDTH_G=17, FWFT, sync, dist)
--       source: surf/base/fifo/rtl/Fifo.vhd  (BSV: mkBuffer = mkPipelineFIFOF,
--       1-deep; emitted as a depth-16 Fifo — SURF ADDR_WIDTH_G min is 4. Extra
--       buffering is behaviour-preserving for the notFull/notEmpty handshake;
--       OQ-EMIT-EHRPPO-02.)
--   Hand-rolled (no stock SURF entity — OQ-FSM-EHRPPO-02 / OQ-EMIT-EHRPPO-01):
--     U_Fork : the 2-way mkForkVector replicate-with-join is NOT a catalog
--       component (the SURF replicate entity AxiStreamSplitter is AXI-Stream-only;
--       this metadata path uses plain valid/data/rdEn PipeOut ports). It is the
--       ONLY state in this module: a 2-bit "taken" register (r.forkTaken) so the
--       source HeaderMetaDataInQ is dequeued only once BOTH consumers (child +
--       buffer) have accepted the token.
--   Child entity:
--     U_ExtractDS : work.ExtractHeaderFromDataStreamPipeOut
--       spec: out/03-fsm/ExtractHeaderFromDataStreamPipeOut.fsm.md
--
--   Scheduling fidelity (fsm.md §Conflicts): the metadata-FIFO readiness gates the
--   single extractHeader rule ONLY on the isFirst path (the enq sits inside
--   `if (isFirst)`). The data path must NOT stall on U_HeaderMetaDataInQ fullness
--   for non-first fragments:
--     deqEn = inValid && dataInQ.notFull && (isFirst -> hdrMetaInQ.notFull)
--   All rule actions are one atomic BSV firing → one block of combinational enables.
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

entity ExtractHeaderFromRdmaPktPipeOut is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk                   : in  sl;
      rst                   : in  sl;   -- active-high synchronous reset
      -- Upstream: one RDMA packet DataStream pipe (module arg rdmaPktPipeIn)
      rdmaPktPipeInValid    : in  sl;   -- rdmaPktPipeIn.notEmpty
      rdmaPktPipeInData     : in  slv(289 downto 0);  -- rdmaPktPipeIn.first (DataStream)
      rdmaPktPipeInRdEn     : out sl;   -- rdmaPktPipeIn.deq
      -- Downstream: header DataStream (headerAndMetaData.headerDataStream = child.header)
      headerDataStreamValid : out sl;   -- header.notEmpty
      headerDataStreamData  : out slv(289 downto 0);  -- header.first (DataStream)
      headerDataStreamRdEn  : in  sl;   -- header.deq
      -- Downstream: header metadata token (headerAndMetaData.headerMetaData = buffer)
      headerMetaDataValid   : out sl;   -- headerMetaData.notEmpty
      headerMetaDataData    : out slv(16 downto 0);  -- headerMetaData.first (HeaderMetaData)
      headerMetaDataRdEn    : in  sl;   -- headerMetaData.deq
      -- Downstream: payload DataStream (payload = child.payload)
      payloadValid          : out sl;   -- payload.notEmpty
      payloadData           : out slv(289 downto 0);  -- payload.first (DataStream)
      payloadRdEn           : in  sl);  -- payload.deq
end entity ExtractHeaderFromRdmaPktPipeOut;

architecture rtl of ExtractHeaderFromRdmaPktPipeOut is

   ---------------------------------------------------------------------------
   -- Widths / DataStream field slicing (290-bit packed layout)
   ---------------------------------------------------------------------------
   constant DS_WIDTH_C            : natural := 290;
   constant HMD_WIDTH_C           : natural := 17;
   constant DATA_BUS_BYTE_WIDTH_C : natural := 32;  -- DATA_BUS_WIDTH/8

   subtype DsDataRange is natural range 289 downto 34;  -- 256 b
   constant DS_ISFIRST_C : natural := 1;

   ---------------------------------------------------------------------------
   -- Header-component byte widths (Headers.bsv SizeOf comments, verified)
   ---------------------------------------------------------------------------
   constant BTH_BYTE_C            : natural := 12;
   constant AETH_BYTE_C           : natural := 4;
   constant RETH_BYTE_C           : natural := 16;
   constant ATOMIC_ETH_BYTE_C     : natural := 28;
   constant ATOMIC_ACK_ETH_BYTE_C : natural := 8;
   constant IMM_DT_BYTE_C         : natural := 4;
   constant IETH_BYTE_C           : natural := 4;
   constant DETH_BYTE_C           : natural := 8;
   constant XRCETH_BYTE_C         : natural := 4;
   constant CNP_PAYLOAD_BYTE_C    : natural := 16;

   ---------------------------------------------------------------------------
   -- BSV decode helpers (faithful to Headers.bsv / Utils.bsv)
   ---------------------------------------------------------------------------
   -- rdmaOpCodeHasPayload : LUT on the 5-bit RdmaOpCode (Headers.bsv:407)
   function rdmaOpCodeHasPayload (opcode : slv(4 downto 0)) return sl is
   begin
      case opcode is
         when "00000" | "00001" | "00010" | "00011" | "00100" | "00101" |  -- SEND_FIRST..ONLY_WITH_IMMEDIATE
              "00110" | "00111" | "01000" | "01001" | "01010" | "01011" |  -- RDMA_WRITE_FIRST..ONLY_WITH_IMMEDIATE
              "01101" | "01110" | "01111" | "10000" |  -- RDMA_READ_RESPONSE_FIRST..ONLY
              "10110" | "10111" =>        -- SEND_{LAST,ONLY}_WITH_INVALIDATE
            return '1';
         when others =>
            return '0';
      end case;
   end function rdmaOpCodeHasPayload;

   -- calcHeaderLenByTransTypeAndRdmaOpCode : ROM keyed on {transType(3),opcode(5)}
   -- (Headers.bsv:286-344; the active, non-commented variant). Returns 7-bit
   -- header byte length; unknown keys → 0 (BSV default).
   function calcHeaderLen (key : slv(7 downto 0)) return slv is
      variable n : natural := 0;
   begin
      case key is
         -- RC requests / responses
         when x"00" | x"01" | x"02" | x"04" | x"07" | x"08" | x"0e" =>
            n := BTH_BYTE_C;            -- 12
         when x"03" | x"05" | x"09" | x"0d" | x"0f" | x"10" | x"11" | x"16" | x"17" =>
            n := BTH_BYTE_C + AETH_BYTE_C;  -- 16 (also =BTH+IMM_DT/IETH)
         when x"06" | x"0a" | x"0c" =>
            n := BTH_BYTE_C + RETH_BYTE_C;  -- 28
         when x"0b" =>
            n := BTH_BYTE_C + RETH_BYTE_C + IMM_DT_BYTE_C;    -- 32
         when x"12" =>
            n := BTH_BYTE_C + AETH_BYTE_C + ATOMIC_ACK_ETH_BYTE_C;  -- 24
         when x"13" | x"14" =>
            n := BTH_BYTE_C + ATOMIC_ETH_BYTE_C;              -- 40
         -- RC/XRC responses sharing AETH-based lengths
         when x"ad" | x"af" | x"b0" | x"b1" =>
            n := BTH_BYTE_C + AETH_BYTE_C;  -- 16
         when x"ae" =>
            n := BTH_BYTE_C;            -- 12
         when x"b2" =>
            n := BTH_BYTE_C + AETH_BYTE_C + ATOMIC_ACK_ETH_BYTE_C;  -- 24
         -- XRC requests (BTH + XRCETH + ...)
         when x"a0" | x"a1" | x"a2" | x"a4" | x"a7" | x"a8" =>
            n := BTH_BYTE_C + XRCETH_BYTE_C;                  -- 16
         when x"a3" | x"a5" | x"a9" | x"b6" | x"b7" =>
            n := BTH_BYTE_C + XRCETH_BYTE_C + IMM_DT_BYTE_C;  -- 20 (IMM_DT/IETH both 4)
         when x"a6" | x"aa" | x"ac" =>
            n := BTH_BYTE_C + XRCETH_BYTE_C + RETH_BYTE_C;    -- 32
         when x"ab" =>
            n := BTH_BYTE_C + XRCETH_BYTE_C + RETH_BYTE_C + IMM_DT_BYTE_C;  -- 36
         when x"b3" | x"b4" =>
            n := BTH_BYTE_C + XRCETH_BYTE_C + ATOMIC_ETH_BYTE_C;    -- 44
         -- UD requests (BTH + DETH + ...)
         when x"64" =>
            n := BTH_BYTE_C + DETH_BYTE_C;  -- 20
         when x"65" =>
            n := BTH_BYTE_C + DETH_BYTE_C + IMM_DT_BYTE_C;    -- 24
         -- CNP notification
         when x"81" =>
            n := BTH_BYTE_C + CNP_PAYLOAD_BYTE_C;             -- 28
         when others =>
            n := 0;
      end case;
      return slv(to_unsigned(n, 7));
   end function calcHeaderLen;

   -- genHeaderMetaData(headerLen, hasPayload) → packed 17-bit HeaderMetaData
   -- (Utils.bsv:303 + calcHeaderFragNumAndLastFragValidByeNum, Utils.bsv:284)
   function genHeaderMetaData (headerLen : slv(6 downto 0); hasPayload : sl) return slv is
      variable residue  : unsigned(4 downto 0);
      variable truncLen : unsigned(1 downto 0);
      variable fragNum  : unsigned(1 downto 0);
      variable lastVbn  : unsigned(5 downto 0);
   begin
      residue  := unsigned(headerLen(4 downto 0));
      truncLen := unsigned(headerLen(6 downto 5));
      if residue /= 0 then
         fragNum := truncLen + 1;
      else
         fragNum := truncLen;
      end if;
      if (residue = 0) and (truncLen /= 0) then
         lastVbn := to_unsigned(DATA_BUS_BYTE_WIDTH_C, 6);  -- 32
      else
         lastVbn := resize(residue, 6);
      end if;
      -- [16:10]headerLen [9:8]headerFragNum [7:2]lastFragValidByteNum [1]hasPayload [0]isEmptyHeader
      return headerLen & slv(fragNum) & slv(lastVbn) & hasPayload & '0';
   end function genHeaderMetaData;

   ---------------------------------------------------------------------------
   -- FSM state : ONLY the U_Fork replicate-with-join "taken" flags.
   --   forkTaken(0) = child copy already consumed ; forkTaken(1) = buffer copy.
   ---------------------------------------------------------------------------
   type RegType is record
      forkTaken : slv(1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      forkTaken => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- rdmaPktPipeIn deq (driven by comb; out port cannot be read back)
   signal rdmaPktPipeInRdEn_i : sl;

   -- U_DataInQ (290 b)
   signal dataInQWrEn    : sl;
   signal dataInQDin     : slv(DS_WIDTH_C-1 downto 0);
   signal dataInQNotFull : sl;
   signal dataInQValid   : sl;
   signal dataInQDout    : slv(DS_WIDTH_C-1 downto 0);
   signal dataInQRdEn    : sl;          -- owned by child U_ExtractDS

   -- U_HeaderMetaDataInQ (17 b) — fork source
   signal hmdInQWrEn    : sl;
   signal hmdInQDin     : slv(HMD_WIDTH_C-1 downto 0);
   signal hmdInQNotFull : sl;
   signal hmdInQValid   : sl;
   signal hmdInQDout    : slv(HMD_WIDTH_C-1 downto 0);
   signal hmdInQRdEn    : sl;           -- driven by comb (fork join deq)

   -- U_Fork outputs
   signal fork0Valid       : sl;        -- comb → child.hdrMetaPipeInValid
   signal childHdrMetaRdEn : sl;        -- child.hdrMetaPipeInRdEn → comb

   -- U_HeaderMetaDataBuf (17 b) — copy[1] buffer
   signal bufWrEn    : sl;
   signal bufNotFull : sl;

begin

   rdmaPktPipeInRdEn <= rdmaPktPipeInRdEn_i;
   -- U_DataInQ din is the input fragment verbatim (gated by dataInQWrEn)
   dataInQDin        <= rdmaPktPipeInData;

   ---------------------------------------------------------------------------
   -- U_DataInQ : surf.Fifo  (BSV: dataInQ <- mkFIFOF)
   --   Write side driven by extractHeader; read side feeds child U_ExtractDS.
   ---------------------------------------------------------------------------
   U_DataInQ : entity surf.Fifo
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
         wr_en         => dataInQWrEn,
         din           => dataInQDin,
         not_full      => dataInQNotFull,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         full          => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => dataInQRdEn,
         dout          => dataInQDout,
         valid         => dataInQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_HeaderMetaDataInQ : surf.Fifo  (BSV: headerMetaDataInQ <- mkFIFOF)
   --   Write side driven by extractHeader (isFirst path); read side = U_Fork.
   ---------------------------------------------------------------------------
   U_HeaderMetaDataInQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => HMD_WIDTH_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => rst,
         wr_clk        => clk,
         wr_en         => hmdInQWrEn,
         din           => hmdInQDin,
         not_full      => hmdInQNotFull,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         full          => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => hmdInQRdEn,
         dout          => hmdInQDout,
         valid         => hmdInQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_HeaderMetaDataBuf : surf.Fifo  (BSV: mkBuffer = mkPipelineFIFOF, 1-deep)
   --   Consumes fork copy[1]; read side = exposed headerMetaData PipeOut.
   --   Emitted depth 16 (SURF ADDR_WIDTH_G min 4); see OQ-EMIT-EHRPPO-02.
   ---------------------------------------------------------------------------
   U_HeaderMetaDataBuf : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => HMD_WIDTH_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => rst,
         wr_clk        => clk,
         wr_en         => bufWrEn,
         din           => hmdInQDout,   -- fork copy[1] payload = source token
         not_full      => bufNotFull,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         full          => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => headerMetaDataRdEn,
         dout          => headerMetaDataData,
         valid         => headerMetaDataValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_ExtractDS : child entity ExtractHeaderFromDataStreamPipeOut
   --   dataPipeIn        ← U_DataInQ          (read side owned here)
   --   headerMetaDataPipeIn ← U_Fork copy[0]  (unbuffered)
   --   header / payload  → this module's interface (pass-through)
   ---------------------------------------------------------------------------
   U_ExtractDS : entity surf.ExtractHeaderFromDataStreamPipeOut
      generic map (
         TPD_G => TPD_G)
      port map (
         clk                => clk,
         rst                => rst,
         dataPipeInValid    => dataInQValid,
         dataPipeInData     => dataInQDout,
         dataPipeInRdEn     => dataInQRdEn,
         hdrMetaPipeInValid => fork0Valid,
         hdrMetaPipeInData  => hmdInQDout,  -- fork copy[0] payload = source token
         hdrMetaPipeInRdEn  => childHdrMetaRdEn,
         headerValid        => headerDataStreamValid,
         headerData         => headerDataStreamData,
         headerRdEn         => headerDataStreamRdEn,
         payloadValid       => payloadValid,
         payloadData        => payloadData,
         payloadRdEn        => payloadRdEn);

   ---------------------------------------------------------------------------
   -- Combinatorial process (two-process FSM)
   --   * extractHeader rule (Mealy routing + first-frag decode)
   --   * U_Fork 2-way replicate-with-join (the only registered state)
   ---------------------------------------------------------------------------
   comb : process (r, rst,
                   rdmaPktPipeInValid, rdmaPktPipeInData,
                   dataInQNotFull, hmdInQNotFull, hmdInQValid, hmdInQDout,
                   childHdrMetaRdEn, bufNotFull) is
      variable v          : RegType;
      variable isFirst    : sl;
      variable ruleFires  : boolean;
      variable data       : slv(255 downto 0);
      variable transType  : slv(2 downto 0);
      variable rdmaOpCode : slv(4 downto 0);
      variable hasPayload : sl;
      variable headerLen  : slv(6 downto 0);
      -- fork join
      variable take0     : sl;
      variable take1     : sl;
      variable newTaken0 : sl;
      variable newTaken1 : sl;
   begin
      v := r;

      -- Default Mealy outputs (deasserted)
      rdmaPktPipeInRdEn_i <= '0';
      dataInQWrEn         <= '0';
      hmdInQWrEn          <= '0';
      hmdInQDin           <= (others => '0');
      hmdInQRdEn          <= '0';
      fork0Valid          <= '0';
      bufWrEn             <= '0';

      ----------------------------------------------------------------------
      -- extractHeader rule (single implied PASS_S state)
      --   ruleFires = inValid && dataInQ.notFull && (isFirst -> hdrMetaInQ.notFull)
      ----------------------------------------------------------------------
      isFirst   := rdmaPktPipeInData(DS_ISFIRST_C);
      ruleFires := (rdmaPktPipeInValid = '1') and (dataInQNotFull = '1')
                   and ((isFirst = '0') or (hmdInQNotFull = '1'));

      if ruleFires then
         rdmaPktPipeInRdEn_i <= '1';    -- rdmaPktPipeIn.deq
         dataInQWrEn         <= '1';    -- dataInQ.enq(frag)  (din wired above)

         if isFirst = '1' then
            data       := rdmaPktPipeInData(DsDataRange);
            transType  := data(255 downto 253);
            rdmaOpCode := data(252 downto 248);
            hasPayload := rdmaOpCodeHasPayload(rdmaOpCode);
            headerLen  := calcHeaderLen(transType & rdmaOpCode);
            hmdInQWrEn <= '1';          -- headerMetaDataInQ.enq(token)
            hmdInQDin  <= genHeaderMetaData(headerLen, hasPayload);
         end if;
      end if;

      ----------------------------------------------------------------------
      -- U_Fork : replicate U_HeaderMetaDataInQ head to two consumers, joined.
      --   copy[0] → child U_ExtractDS ; copy[1] → U_HeaderMetaDataBuf.
      --   Source is dequeued only once BOTH copies have been accepted.
      ----------------------------------------------------------------------
      fork0Valid <= hmdInQValid and (not r.forkTaken(0));
      bufWrEn    <= (hmdInQValid and (not r.forkTaken(1))) and bufNotFull;

      take0 := (hmdInQValid and (not r.forkTaken(0))) and childHdrMetaRdEn;
      take1 := (hmdInQValid and (not r.forkTaken(1))) and bufNotFull;

      newTaken0 := r.forkTaken(0) or take0;
      newTaken1 := r.forkTaken(1) or take1;

      if (newTaken0 = '1') and (newTaken1 = '1') then
         hmdInQRdEn  <= '1';            -- both consumed → deq source
         v.forkTaken := (others => '0');
      else
         v.forkTaken(0) := newTaken0;
         v.forkTaken(1) := newTaken1;
      end if;

      -- Synchronous reset (fork join state only)
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
