-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   STRUCTURAL packet-stream merger. Owns no datapath transformation. It chains
--   two child entities and drains their merged RDMA DataStream into one output
--   FIFO, popping one psnPipeIn entry per completed packet (per isLast):
--
--     headerPipeIn ──> U_Header2DataStream ──(headerDataStream + headerMetaData)──┐
--                                                                                  v
--     payloadPipeIn ───────────────────────────────> U_PrependHeader2PipeOut ──(rdmaDataStream)
--                                                                                  │
--                                                  connect handshake (this entity) │
--                                                                                  v
--                                                                            U_OutputQ : surf.Fifo
--                                                                                  │
--                                                                  toPipeOut(outputQ) = output
--
--   The single BSV `rule connect` comes from mkConnectionWithAction
--   (Utils.bsv:1782): get rdmaDataStreamPipeOut, put into outputQ, and run
--   deqActionFunc (ExtractAndPrependPipeOut.bsv:735), which pops psnPipeIn only
--   when the transferred fragment is isLast. Modeled here as a pure combinational
--   FIFO handshake — there is NO local RegType (single perpetual CONNECT state).
--
--   Partition / spec notes applied:
--     * OQ-FSM-CHP-01: mapping.json wrongly records rules=[]/surf_instances=[].
--       The BSV has `outputQ <- mkFIFOF` (-> U_OutputQ : surf.Fifo, 290 b) and the
--       implied connect rule. Both are emitted (FSM spec is authoritative).
--     * OQ-FSM-CHP-02: the commented-out `rule connect` (lines 700-733) with the
--       BTH-extract / PSN-compare assertion is DEAD CODE. `psnPipeIn` is drained
--       (notEmpty + deq) but its VALUE is never used; `bthReg` (mkRegU in
--       mkConnectionWithAction) is dead and NOT emitted. No PSN check is added —
--       that would be NEW behavior.
--
--   Width / packing (BSV deriving(Bits), first-field-at-MSB; OQ-FSM-H2DS-02/04):
--     DataStream (290): [289:34] data[255:0] | [33:2] byteEn[31:0] |
--                       [1] isFirst | [0] isLast
--     HeaderRDMA = 593 b ; HeaderMetaData = 17 b ; PSN = 24 b.
--
--   FIFO clear (OQ-FSM-01 family RESOLVED): surf.Fifo has no clear port; the
--   FSM spec's "U_OutputQ clears on cntrlStatus.comm.isReset" is realized by
--   asserting the synchronous FIFO reset: outputQRst = rst OR clearAllI. (Note:
--   the BSV mkFIFOF itself resets only on the module's implicit/global reset;
--   the OR with clearAllI follows the Stage-3 spec decision and the project-wide
--   soft-clear convention so the whole pipeline flushes coordinated.)
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

entity CombineHeaderAndPayload is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';      -- '1' for active HIGH reset
      RST_ASYNC_G    : boolean := false);
   port (
      clk : in sl;
      rst : in sl := not RST_POLARITY_G;

      -- Soft clear (cntrlStatus.comm.isReset); fanned to both children + outputQ
      clearAllI          : in  sl;

      -- headerPipeIn : PipeOut#(HeaderRDMA) (593 b) -> U_Header2DataStream
      headerPipeInValid  : in  sl;                   -- .notEmpty
      headerPipeInData   : in  slv(592 downto 0);    -- .first  (HeaderRDMA)
      headerPipeInRdEn   : out sl;                   -- .deq

      -- payloadPipeIn : DataStreamPipeOut (290 b) -> U_PrependHeader2PipeOut
      payloadPipeInValid : in  sl;                   -- .notEmpty
      payloadPipeInData  : in  slv(289 downto 0);    -- .first  (DataStream)
      payloadPipeInRdEn  : out sl;                   -- .deq

      -- psnPipeIn : PipeOut#(PSN) (24 b). VALUE UNUSED (OQ-FSM-CHP-02); only the
      -- notEmpty/deq handshake is used — one pop per completed (isLast) packet.
      psnPipeInValid     : in  sl;                   -- .notEmpty
      psnPipeInData      : in  slv(23 downto 0);     -- .first (PSN) — unused
      psnPipeInRdEn      : out sl;                   -- .deq (only on isLast)

      -- Output : toPipeOut(outputQ) : DataStreamPipeOut (290 b)
      dataStreamOutValid : out sl;                   -- PipeOut.notEmpty
      dataStreamOutData  : out slv(289 downto 0);    -- PipeOut.first
      dataStreamOutRdEn  : in  sl);                  -- PipeOut.deq
end entity CombineHeaderAndPayload;

architecture rtl of CombineHeaderAndPayload is

   -- DataStream layout
   constant DS_WIDTH_C  : integer := 290;
   constant DS_ISLAST_C : integer := 0;             -- DataStream.isLast bit index

   -- Reset / clear plumbing
   signal rstActiveHigh : sl;
   signal outputQRst    : sl;                       -- rst OR clearAllI (soft clear)

   -- U_Header2DataStream -> U_PrependHeader2PipeOut interconnect
   signal hdrDsValid    : sl;                        -- headerDataStream.notEmpty
   signal hdrDsData     : slv(DS_WIDTH_C-1 downto 0);-- headerDataStream.first
   signal hdrDsRdEn     : sl;                        -- headerDataStream.deq
   signal hdrMetaValid  : sl;                        -- headerMetaData.notEmpty
   signal hdrMetaData   : slv(16 downto 0);          -- headerMetaData.first
   signal hdrMetaRdEn   : sl;                        -- headerMetaData.deq

   -- U_PrependHeader2PipeOut output (rdmaDataStreamPipeOut)
   signal rdmaOutValid  : sl;                        -- .notEmpty
   signal rdmaOutData   : slv(DS_WIDTH_C-1 downto 0);-- .first
   signal rdmaOutRdEn   : sl;                        -- .deq (connect-rule pop)

   -- U_OutputQ (surf.Fifo) write side
   signal outputQFull   : sl;
   signal outputQWrEn   : sl;
   signal outputQDin    : slv(DS_WIDTH_C-1 downto 0);

   -- connect-rule combinational signals
   signal isLast        : sl;
   signal transferFire  : sl;

begin

   -----------------------------------------------------------------------------
   -- Reset normalisation + soft clear
   -----------------------------------------------------------------------------
   rstActiveHigh <= rst when RST_POLARITY_G = '1' else not rst;
   outputQRst    <= rstActiveHigh or clearAllI;

   -----------------------------------------------------------------------------
   -- U_Header2DataStream : HeaderRDMA pipe -> (headerDataStream + headerMetaData)
   --   (BSV: mkHeader2DataStream(cntrlStatus.comm.isReset, headerPipeIn))
   -----------------------------------------------------------------------------
   U_Header2DataStream : entity surf.Header2DataStream
      generic map (
         TPD_G => TPD_G)
      port map (
         clk                => clk,
         rst                => rstActiveHigh,
         clearAllI          => clearAllI,
         -- headerPipeIn (top-level)
         hdrPipeInValid     => headerPipeInValid,
         hdrPipeInData      => headerPipeInData,
         hdrPipeInRdEn      => headerPipeInRdEn,
         -- headerDataStream -> U_PrependHeader2PipeOut.headerPipeIn
         hdrDataStreamValid => hdrDsValid,
         hdrDataStreamDout  => hdrDsData,
         hdrDataStreamRdEn  => hdrDsRdEn,
         -- headerMetaData -> U_PrependHeader2PipeOut.headerMetaPipeIn
         hdrMetaDataValid   => hdrMetaValid,
         hdrMetaDataDout    => hdrMetaData,
         hdrMetaDataRdEn    => hdrMetaRdEn);

   -----------------------------------------------------------------------------
   -- U_PrependHeader2PipeOut : merge header DataStream + payload -> RDMA stream
   --   (BSV: mkPrependHeader2PipeOut(isReset, headerDataStream, headerMetaData,
   --    payloadPipeIn))
   -----------------------------------------------------------------------------
   U_PrependHeader2PipeOut : entity surf.PrependHeader2PipeOut
      generic map (
         TPD_G => TPD_G)
      port map (
         clk                   => clk,
         rst                   => rstActiveHigh,
         clearAllI             => clearAllI,
         -- headerMetaPipeIn <- U_Header2DataStream.headerMetaData
         headerMetaPipeInValid => hdrMetaValid,
         headerMetaPipeInData  => hdrMetaData,
         headerMetaPipeInRdEn  => hdrMetaRdEn,
         -- headerPipeIn <- U_Header2DataStream.headerDataStream
         headerPipeInValid     => hdrDsValid,
         headerPipeInData      => hdrDsData,
         headerPipeInRdEn      => hdrDsRdEn,
         -- dataPipeIn <- payloadPipeIn (top-level)
         dataPipeInValid       => payloadPipeInValid,
         dataPipeInData        => payloadPipeInData,
         dataPipeInRdEn        => payloadPipeInRdEn,
         -- dataStreamOut = rdmaDataStreamPipeOut (drained by connect handshake)
         dataStreamOutValid    => rdmaOutValid,
         dataStreamOutData     => rdmaOutData,
         dataStreamOutRdEn     => rdmaOutRdEn);

   -----------------------------------------------------------------------------
   -- U_OutputQ : surf.Fifo  (BSV: outputQ <- mkFIFOF, element DataStream = 290 b)
   --   FWFT first/deq PipeOut semantics; sync; soft-cleared via outputQRst.
   --   Read side IS the module's toPipeOut(outputQ) output interface.
   -----------------------------------------------------------------------------
   U_OutputQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',                -- outputQRst is active-high
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => DS_WIDTH_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => outputQRst,
         wr_clk        => clk,
         wr_en         => outputQWrEn,
         din           => outputQDin,
         full          => outputQFull,
         not_full      => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => dataStreamOutRdEn,    -- downstream deq (output port)
         dout          => dataStreamOutData,    -- output port
         valid         => dataStreamOutValid,   -- output port
         underflow     => open,
         rd_data_count => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open);

   -----------------------------------------------------------------------------
   -- connect rule (combinational FIFO handshake; no RegType — CONNECT_S only)
   --   fire = rdmaOut.notEmpty AND outputQ.notFull AND (!isLast OR psn.notEmpty)
   --   on fire: outputQ.enq(rdmaOut.first); rdmaOut.deq; if isLast: psn.deq
   -- BSV mkConnectionWithAction: the connectAction (psnPipeIn.deq, gated by
   -- isLast) contributes its implicit notEmpty condition to the rule only when
   -- isLast — hence the (!isLast OR psnPipeInValid) term (FSM spec guard note).
   -----------------------------------------------------------------------------
   isLast       <= rdmaOutData(DS_ISLAST_C);
   transferFire <= rdmaOutValid and (not outputQFull) and
                   ((not isLast) or psnPipeInValid);

   outputQWrEn  <= transferFire;
   outputQDin   <= rdmaOutData;
   rdmaOutRdEn  <= transferFire;                 -- pop the merged RDMA stream
   psnPipeInRdEn <= transferFire and isLast;     -- one pop per completed packet

end architecture rtl;
