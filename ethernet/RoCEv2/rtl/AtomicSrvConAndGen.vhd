-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Implements BSV interface Server#(AtomicOpReq, AtomicOpResp) as a pair of
--   surf.Fifo instances with a single combinational transform between them
--   (BSV rule genResp).  There is NO state register and NO RegType: mkAtomicSrv
--   declares no mkReg/mkRegU/mkCReg — its only state-holding elements are the two
--   FIFOs (atomicOpReqQ, atomicOpRespQ), which are SURF instances.  The single
--   rule genResp has no explicit guard; it fires purely on the FIFO implicit
--   conditions (reqQ.notEmpty AND respQ.notFull).  This entity is therefore a
--   structural wrapper + combinational glue (Mealy) — no two-process FSM, no
--   RegType (the only registered storage lives inside the two U_*Q FIFOs).
--
--   cntrlStatus (OQ-FSM-ASCAG-01, non-blocking): mkAtomicSrv takes a CntrlStatus
--   constructor argument but NEVER references it (no resetAndClear rule, no
--   guard) — unlike every sibling *ConAndGen module in this file.  It therefore
--   contributes NO port (mapping.json new_ports: [] is correct).  The FIFOs reset
--   only via their structural rst tied to the global synchronous reset.
--
-- !!! STUB — atomic operation is UNIMPLEMENTED (RQ-06 / OQ-FSM-ASCAG-02) !!!
-- ---------------------------------------------------------------------------
--   genResp does NOT compute a real compare-and-swap / fetch-and-add.  Per the
--   BSV source comment (PayloadConAndGen.bsv:1213, "// TODO: add atomic support")
--   the rule simply ECHOES the request's own compData back as `original`:
--
--       AtomicOpResp { initiator: req.initiator,
--                      original : req.compData,   -- <- STUB: should be the
--                                                 --    pre-CAS/FA value READ
--                                                 --    FROM MEMORY, not compData
--                      sqpn     : req.sqpn,
--                      psn      : req.psn }
--
--   The request fields casOrFetchAdd, swapData and startAddr are present in the
--   packed request word but are NEVER referenced — confirming a genuine no-op
--   stub (no memory access of any kind occurs here).  This is an INTENTIONAL,
--   RESOLVED decision (out/01-inventory/RESOLVED-round2.md RQ-06,
--   out/02-partition/RESOLVED-round4.md item 4): KEEP THE STUB IN VHDL.  Do NOT
--   implement a real atomic op.  This comment preserves the limitation for later
--   co-sim / hardware-correctness review.  See OQ-FSM-ASCAG-02.
--
-- Width / bit-layout trace (CLAUDE.md hard rule: trace widths, never invent)
-- --------------------------------------------------------------------------
--   BSV deriving(Bits) packs the first field at the MSB (confirmed RESOLVED at
--   OQ-FSM-H2DS-04; project-wide convention).  Field widths from DataTypes.bsv
--   349-364, Headers.bsv 22-26:
--     DmaReqSrcType=4, ADDR=64, Long=64, QPN=24, PSN=24, Bool=1.
--
--   AtomicOpReq  = 245 bits (DataTypes.bsv:349-357):
--     | 244:241 initiator | 240 casOrFetchAdd | 239:176 startAddr |
--     | 175:112 compData  | 111:48 swapData   |  47:24  sqpn      | 23:0 psn |
--   AtomicOpResp = 116 bits (DataTypes.bsv:359-364):
--     | 115:112 initiator | 111:48 original   |  47:24  sqpn      | 23:0 psn |
--
-- SURF components instantiated (source: surf/base/fifo/rtl/Fifo.vhd):
--   U_AtomicOpReqQ  : surf.Fifo  DATA_WIDTH_G=245  (BSV atomicOpReqQ  <- mkFIFOF)
--   U_AtomicOpRespQ : surf.Fifo  DATA_WIDTH_G=116  (BSV atomicOpRespQ <- mkFIFOF)
--   Both: sync, FWFT (matches BSV FIFOF.first fall-through), distributed RAM
--   (small control FIFOs), ADDR_WIDTH_G=4 (surf.Fifo minimum; BSV default depth
--   2 maps to depth-16 — extra buffering only, functionally equivalent).
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

entity AtomicSrvConAndGen is
   generic (
      TPD_G        : time     := 1 ns;
      -- Widths are fixed by the BSV struct layout (see header bit-layout trace);
      -- the field slicing below assumes these exact values.
      REQ_WIDTH_G  : positive := 245;   -- AtomicOpReq  packed width
      RESP_WIDTH_G : positive := 116);  -- AtomicOpResp packed width
   port (
      clk       : in  sl;
      rst       : in  sl;               -- active-high sync reset
      -- Server.request.put(AtomicOpReq) — caller enqueues a request.
      --   reqValid drives the request FIFO write enable; reqRdy = FIFO not-full.
      reqValid  : in  sl;
      reqData   : in  slv(REQ_WIDTH_G-1 downto 0);   -- AtomicOpReq packed
      reqRdy    : out sl;               -- = atomicOpReqQ.notFull
      -- Server.response.get(AtomicOpResp) — caller dequeues a response.
      --   respValid = FIFO not-empty; respRdy drives the response FIFO read enable.
      respValid : out sl;               -- = atomicOpRespQ.notEmpty
      respData  : out slv(RESP_WIDTH_G-1 downto 0);  -- AtomicOpResp packed
      respRdy   : in  sl);              -- caller get() enable
end entity AtomicSrvConAndGen;

architecture rtl of AtomicSrvConAndGen is

   -- AtomicOpReq field slices (first-field-at-MSB, OQ-FSM-H2DS-04 RESOLVED).
   subtype INITIATOR_REQ_F is natural range 244 downto 241;
   --   240            casOrFetchAdd  -- read but UNUSED (stub)
   --   239 downto 176 startAddr      -- read but UNUSED (stub)
   subtype COMPDATA_F is natural range 175 downto 112;
   --   111 downto  48 swapData       -- read but UNUSED (stub)
   subtype SQPN_REQ_F is natural range 47 downto 24;
   subtype PSN_REQ_F is natural range 23 downto 0;

   -- U_AtomicOpReqQ interface signals (request FIFO, REQ_WIDTH_G bits)
   signal reqQNotFull : sl;
   signal reqQValid   : sl;             -- = atomicOpReqQ.notEmpty
   signal reqQDout    : slv(REQ_WIDTH_G-1 downto 0);
   signal reqQRdEn    : sl;             -- atomicOpReqQ.deq

   -- U_AtomicOpRespQ interface signals (response FIFO, RESP_WIDTH_G bits)
   signal respQNotFull : sl;
   signal respQValid   : sl;            -- = atomicOpRespQ.notEmpty
   signal respQDout    : slv(RESP_WIDTH_G-1 downto 0);
   signal respQWrEn    : sl;            -- atomicOpRespQ.enq
   signal respQDin     : slv(RESP_WIDTH_G-1 downto 0);

   -- genResp fire condition (Mealy): reqQ has a request AND respQ can accept.
   signal genFire : sl;

begin

   -- generic sanity: the field slicing is hardwired to these struct widths.
   assert (REQ_WIDTH_G = 245 and RESP_WIDTH_G = 116)
      report "AtomicSrvConAndGen: field slicing assumes REQ_WIDTH_G=245, " &
      "RESP_WIDTH_G=116 (BSV AtomicOpReq/AtomicOpResp layout)."
      severity failure;

   ---------------------------------------------------------------------------
   -- request.put pass-through (NOT FSM-gated): the caller drives the request
   -- FIFO write side directly; reqRdy reports the FIFO's not-full state.
   ---------------------------------------------------------------------------
   reqRdy <= reqQNotFull after TPD_G;

   ---------------------------------------------------------------------------
   -- rule genResp (single rule; no explicit guard).  Implicit conditions:
   --   fire = atomicOpReqQ.notEmpty AND atomicOpRespQ.notFull
   -- On firing it dequeues the request, enqueues the response, and (STUB)
   -- echoes compData back as `original` — see header for the unimplemented
   -- atomic-op warning (RQ-06 / OQ-FSM-ASCAG-02).
   ---------------------------------------------------------------------------
   genFire <= reqQValid and respQNotFull;

   reqQRdEn  <= genFire after TPD_G;    -- atomicOpReqQ.deq
   respQWrEn <= genFire after TPD_G;    -- atomicOpRespQ.enq

   -- AtomicOpResp packing (first-field-at-MSB):
   --   { initiator(4) | original(64) | sqpn(24) | psn(24) }
   -- STUB: original := compData (NOT a real CAS/FA result — see header).
   respQDin <= reqQDout(INITIATOR_REQ_F) &
reqQDout(COMPDATA_F) & -- original <= compData (stub)
               reqQDout(SQPN_REQ_F) &
               reqQDout(PSN_REQ_F) after TPD_G;

   ---------------------------------------------------------------------------
   -- response.get pass-through (NOT FSM-gated): the caller reads the response
   -- FIFO front directly; respRdy drives the read enable.
   ---------------------------------------------------------------------------
   respValid <= respQValid after TPD_G;
   respData  <= respQDout  after TPD_G;

   ---------------------------------------------------------------------------
   -- U_AtomicOpReqQ : surf.Fifo
   --   BSV: FIFOF#(AtomicOpReq) atomicOpReqQ <- mkFIFOF.  Write side = caller's
   --   request.put; read side = rule genResp.
   ---------------------------------------------------------------------------
   U_AtomicOpReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => REQ_WIDTH_G,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => rst,
         wr_clk        => clk,
         wr_en         => reqValid,     -- request.put enable (pass-through)
         din           => reqData,      -- AtomicOpReq packed (pass-through)
         full          => open,
         not_full      => reqQNotFull,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => reqQRdEn,     -- genResp deq
         dout          => reqQDout,
         valid         => reqQValid,    -- atomicOpReqQ.notEmpty
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_AtomicOpRespQ : surf.Fifo
   --   BSV: FIFOF#(AtomicOpResp) atomicOpRespQ <- mkFIFOF.  Write side = rule
   --   genResp; read side = caller's response.get.
   ---------------------------------------------------------------------------
   U_AtomicOpRespQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => RESP_WIDTH_G,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => rst,
         wr_clk        => clk,
         wr_en         => respQWrEn,     -- genResp enq
         din           => respQDin,      -- AtomicOpResp packed (stub)
         full          => open,
         not_full      => respQNotFull,  -- genResp implicit condition
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => respRdy,       -- response.get enable (pass-through)
         dout          => respQDout,
         valid         => respQValid,    -- atomicOpRespQ.notEmpty
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

end architecture rtl;
