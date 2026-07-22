-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Thin STRUCTURAL specialization of mkClientArbiter — owns 0 rules,
--   0 state registers, 0 SURF instances (matches the partition entry). Its
--   entire contribution over a bare ClientArbiter is:
--
--     1. Type specialization: reqType = DmaReadReq (176b), respType =
--        DmaReadResp (383b). These fix the child's REQ_WIDTH_G / RESP_WIDTH_G.
--
--     2. Resolution of the two BSV `function Bool` module parameters
--        (isReqFinished / isRespFinished — OQ-FSM-17). BSV realizes these as
--        elaboration-time functions; VHDL has no function-type ports, so this
--        wrapper (where the concrete DmaRead type is known) computes each
--        predicate and feeds it as a 1-bit combinational input to the child:
--          * isDmaReadReqLastFrag(req)  = True
--              -> child cltReqFinished tied to all-'1' (every request is a
--                 single-fragment burst; the child re-arms shouldSaveGrantIdxReg
--                 on every issued request).
--          * isDmaReadRespLastFrag(resp) = resp.dataStream.isLast
--              -> child outRespFinished = outRespData(0). BSV struct-pack places
--                 the first field in the MSBs, so `dataStream` (last field of
--                 DmaReadResp) sits in the low bits, and `isLast` (last field of
--                 DataStream) is bit 0 (LSB) of the packed DmaReadResp. Confirmed
--                 against DmaReadCntrlGen.vhd (dataStream.isLast = dmaRespIn(0)).
--
--   All other ports connect one-to-one between this entity boundary and the
--   child U_Arb. There is no owned RegType, no FSM, no sequential process —
--   the generated VHDL is a single child instantiation plus predicate wiring.
--   All arbitration state / FIFOs live in the child ClientArbiter; see
--   out/04-vhdl/ClientArbiter.vhd.
--
--   Sizing (DmaReadCltArbiter.fsm.md §Elaboration facts, OQ-FSM-PERMARB-01,
--   CLOSED 2026-07-04):
--     portSz = TMul#(2, MAX_QP) = 8. dmaReadCltVec is
--     Vector#(TMul#(2,MAX_QP), DmaReadClt) (each QP contributes one RQ-side and
--     one SQ-side DmaRead client). This wrapper carries a MAX_QP_G generic and
--     drives the child PORT_COUNT_G => 2*MAX_QP_G (= 8 at MAX_QP_G=4, idxW=3:
--     full 8-input arbitration tree). The child ClientArbiter is emitted generic
--     over PORT_COUNT_G and Stage-5 verified at PORT_COUNT_G=8.
--
--   Per-client flattened buses (inherited from ClientArbiter): client k's
--   request payload slice is cltReqData((k+1)*REQ_WIDTH_G-1 downto k*REQ_WIDTH_G)
--   and likewise cltRespData with RESP_WIDTH_G, k = 0 .. 2*MAX_QP_G-1.
--
--   Child entity instantiated:
--     * U_Arb : work.ClientArbiter (owns the arbitration FSM + all FIFOs)
--       source: out/04-vhdl/ClientArbiter.vhd
--   SURF components instantiated directly: NONE (all owned by the child).
--
--   NOTE: emitting does not prove equivalence — simulate this entity (cocotb)
--   against the BSV behaviour before trusting it.
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

entity DmaReadCltArbiter is
   generic (
      TPD_G             : time                   := 1 ns;
      RST_POLARITY_G    : sl                     := '1';  -- '1' active HIGH reset, '0' active LOW
      RST_ASYNC_G       : boolean                := false;
      MAX_QP_G          : positive               := 4;    -- BSV MAX_QP; child PORT_COUNT = 2*MAX_QP
      REQ_WIDTH_G       : positive               := 176;  -- Bits#(DmaReadReq)  (fixed by type; do not change)
      RESP_WIDTH_G      : positive               := 383;  -- Bits#(DmaReadResp) (fixed by type; do not change)
      MEMORY_TYPE_G     : string                 := "distributed";  -- child FIFO RAM style
      FIFO_ADDR_WIDTH_G : positive range 4 to 48 := 4);   -- child FIFO depth = 2**ADDR
   port (
      clk          : in  sl;
      rst          : in  sl := not RST_POLARITY_G;
      -- Per-port upstream DmaRead client faces (dmaReadCltVec[k],
      -- k = 0 .. 2*MAX_QP_G-1; arbiter is master). Client k's payload slice is
      -- ((k+1)*WIDTH-1 downto k*WIDTH) of the flattened data buses.
      cltReqValid  : in  slv(2*MAX_QP_G-1 downto 0);                 -- client k DmaReadReq available (request.get implicit cond)
      cltReqData   : in  slv(2*MAX_QP_G*REQ_WIDTH_G-1 downto 0);     -- client k DmaReadReq payload, flattened
      cltReqGet    : out slv(2*MAX_QP_G-1 downto 0);                 -- arbiter takes client k's request (request.get fired)
      cltRespValid : out slv(2*MAX_QP_G-1 downto 0);                 -- arbiter drives a DmaReadResp to client k (one-hot on grant)
      cltRespData  : out slv(2*MAX_QP_G*RESP_WIDTH_G-1 downto 0);    -- DmaReadResp payload (broadcast; cltRespValid selects the port)
      cltRespReady : in  slv(2*MAX_QP_G-1 downto 0);                 -- client k can accept a response (response.put ready)
      -- Downstream shared DmaRead Client face (returned arbitratedClient)
      outReqValid  : out sl;                             -- arbitrated DmaReadReq valid to DMA
      outReqData   : out slv(REQ_WIDTH_G-1 downto 0);    -- arbitrated DmaReadReq
      outReqRd     : in  sl;                             -- DMA dequeues the request (request.get)
      outRespValid : in  sl;                             -- DMA presents a DmaReadResp (response.put fired)
      outRespData  : in  slv(RESP_WIDTH_G-1 downto 0);   -- DmaReadResp payload from DMA
      outRespReady : out sl);                            -- arbiter can accept a response (response.put ready)
end entity DmaReadCltArbiter;

architecture rtl of DmaReadCltArbiter is

   -- Resolved OQ-FSM-17 request predicate: isDmaReadReqLastFrag = True for every
   -- port, so the child's per-channel finish input is a constant all-'1' bus.
   signal reqFinishedAll : slv(2*MAX_QP_G-1 downto 0);

begin

   -- isDmaReadReqLastFrag(req) = True  ->  every request is single-fragment.
   reqFinishedAll <= (others => '1');

   --------------------------------------------------------------------------
   -- U_Arb : the actual DmaRead client arbiter (ClientArbiter) — owns the FSM
   --   register (shouldSaveGrantIdxReg), the arbitration tree, and all FIFOs.
   --   PORT_COUNT_G => 2*MAX_QP_G (= 8 at MAX_QP_G=4). Predicate inputs resolved
   --   by this wrapper; all other ports pass straight through.
   --------------------------------------------------------------------------
   U_Arb : entity surf.ClientArbiter
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         PORT_COUNT_G      => 2*MAX_QP_G,
         REQ_WIDTH_G       => REQ_WIDTH_G,
         RESP_WIDTH_G      => RESP_WIDTH_G,
         MEMORY_TYPE_G     => MEMORY_TYPE_G,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G)
      port map (
         clk             => clk,
         rst             => rst,
         -- Per-port upstream client faces (pass-through)
         cltReqValid     => cltReqValid,
         cltReqData      => cltReqData,
         cltReqFinished  => reqFinishedAll,       -- OQ-FSM-17: isDmaReadReqLastFrag = True
         cltReqGet       => cltReqGet,
         cltRespValid    => cltRespValid,
         cltRespData     => cltRespData,
         cltRespReady    => cltRespReady,
         -- Downstream shared client face (pass-through)
         outReqValid     => outReqValid,
         outReqData      => outReqData,
         outReqRd        => outReqRd,
         outRespValid    => outRespValid,
         outRespData     => outRespData,
         outRespFinished => outRespData(0),       -- OQ-FSM-17: resp.dataStream.isLast = RESP LSB
         outRespReady    => outRespReady);

end architecture rtl;
