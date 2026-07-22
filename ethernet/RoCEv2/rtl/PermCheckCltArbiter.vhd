-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Pure structural wrapper. `mkPermCheckCltArbiter` owns NO registered state,
--   NO rules and NO FIFOs of its own; its entire body defines two constant
--   predicate functions and instantiates ONE mkClientArbiter, returning that
--   interface unchanged:
--
--       function Bool isPermCheckReqFinished (PermCheckReq req) = True;
--       function Bool isPermCheckRespFinished(Bool resp)        = True;
--       let arbitratedClient <- mkClientArbiter(
--           permCheckCltVec, isPermCheckReqFinished, isPermCheckRespFinished);
--       return arbitratedClient;
--
--   It specializes the generic ClientArbiter to:
--     reqType  = PermCheckReq -> REQ_WIDTH_G  = 267 (DataTypes.bsv:244-254)
--     respType = Bool         -> RESP_WIDTH_G = 1   (PermCheckClt = Client#(PermCheckReq,Bool))
--     portSz   = 2*MAX_QP     -> PORT_COUNT_G = 2*MAX_QP_G (default 8; OQ-FSM-PERMARB-01)
--   Each QP exposes TWO perm-check clients (permCheckClt4RQ, permCheckClt4SQ;
--   TransportLayer.bsv:112,139-140), so the vector size is TMul#(2,MAX_QP), NOT
--   MAX_QP.  Even k = QP's RQ client, odd k = its SQ client (k = 2*qpIdx / 2*qpIdx+1).
--
--   OQ-FSM-17 (predicate handling): mkClientArbiter takes isReqFinished /
--   isRespFinished as elaboration-time FUNCTION arguments; VHDL has no
--   function-type ports, so the parent (where the concrete type is known) feeds
--   them to the child as 1-bit inputs.  For PermCheck BOTH predicates are the
--   constant function `= True`, so ALL child finished inputs are tied '1':
--     U_PermCheckArb.cltReqFinished(k) = isPermCheckReqFinished  = True -> '1' (k=0..PORT_COUNT-1)
--     U_PermCheckArb.outRespFinished   = isPermCheckRespFinished = True -> '1'
--   Consequence (for the TB writer): the child's shouldSaveGrantIdxReg stays '1'
--   forever, so every issued request records its grant index and every response
--   releases one — strict 1-request<->1-response, no multi-beat bursts. This is
--   the simplest arbiter case (contrast DmaWriteCltArbiter, whose req predicate
--   is req.dataStream.isLast).
--
--   Because there is no state to translate, this architecture is emitted as pure
--   structural VHDL (one child instance + 1:1 boundary wiring + two constant
--   tie-offs) rather than the SURF two-process comb/seq template.  There is no
--   RegType / REG_INIT_C — mkPermCheckCltArbiter has zero mkReg/mkRegU/mkCReg
--   fields (FSM spec §"State register": NONE).  Same convention as the sibling
--   structural containers DmaArbiter4Qp.vhd (OQ-EMIT-DMAARB-01) and
--   SqQueuePair.vhd (OQ-EMIT-SQQP-01).
--
--   Boundary is exposed VECTORED to mirror the child ClientArbiter's flattened
--   per-client buses (client k's REQ slice = ((k+1)*W-1 downto k*W)); the wrapper
--   forwards each bus straight through.  Upstream group `permSrv*` = the per-QP
--   perm-check client faces (arbiter is master: it *gets* requests, *puts*
--   responses); downstream group `permClt*` = the single aggregated client face
--   toward mkPermCheckSrv (TransportLayer.bsv:157).
--
--   Child entity instantiated (separately emitted):
--     U_PermCheckArb : work.ClientArbiter
--       (PORT_COUNT_G=2*MAX_QP_G, REQ_WIDTH_G=267, RESP_WIDTH_G=1)
--       source: out/04-vhdl/ClientArbiter.vhd
--
--   SURF components instantiated DIRECTLY by this entity: NONE.  Every surf.Fifo
--   (inputReqWithIdxVec, reqQ, respQ, preGrantIdxQ) and the arbitration tree live
--   inside the ClientArbiter child.
--
--   MAX_QP_G generic convention: MAX_QP-dependent entities expose a top-level
--   MAX_QP_G generic (power of 2, >= 2; default 4 = Settings.bsv:14) rather than a
--   hard-locked 4.  PORT_COUNT_G is derived as 2*MAX_QP_G (also a power of 2).
--
--   NOTE: emitting does not prove equivalence — simulate this entity (cocotb/GHDL)
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

library surf;
use surf.StdRtlPkg.all;

entity PermCheckCltArbiter is
   generic (
      TPD_G             : time                   := 1 ns;
      RST_POLARITY_G    : sl                     := '1';   -- '1' active HIGH reset, '0' active LOW
      RST_ASYNC_G       : boolean                := false;
      MAX_QP_G          : positive               := 4;     -- queue-pair count; power of 2, >= 2 (Settings.bsv:14)
      PERM_REQ_WIDTH_G  : positive               := 267;   -- Bits#(PermCheckReq)  (DataTypes.bsv:244-254)
      PERM_RESP_WIDTH_G : positive               := 1;     -- Bits#(Bool)          (PermCheckClt resp type)
      MEMORY_TYPE_G     : string                 := "distributed";  -- child FIFO RAM style
      FIFO_ADDR_WIDTH_G : positive range 4 to 48 := 4);    -- child FIFO depth = 2**ADDR
   port (
      clk : in sl;
      rst : in sl := not RST_POLARITY_G;

      -----------------------------------------------------------------------
      -- Upstream per-QP PermCheck client faces (permCheckCltVec[k],
      -- k = 0 .. 2*MAX_QP_G-1; arbiter is master). Client k's REQ payload slice
      -- is ((k+1)*PERM_REQ_WIDTH_G-1 downto k*PERM_REQ_WIDTH_G); RESP likewise.
      -- Even k = QP RQ perm-check client, odd k = QP SQ perm-check client.
      -----------------------------------------------------------------------
      permSrvReqValid  : in  slv(2*MAX_QP_G-1 downto 0);                    -- client k request available
      permSrvReqData   : in  slv(2*MAX_QP_G*PERM_REQ_WIDTH_G-1 downto 0);   -- client k request payload, flattened
      permSrvReqGet    : out slv(2*MAX_QP_G-1 downto 0);                    -- arbiter takes client k's request
      permSrvRespValid : out slv(2*MAX_QP_G-1 downto 0);                    -- arbiter drives a response to client k
      permSrvRespData  : out slv(2*MAX_QP_G*PERM_RESP_WIDTH_G-1 downto 0);  -- response payload, flattened (selected port valid)
      permSrvRespReady : in  slv(2*MAX_QP_G-1 downto 0);                    -- client k can accept a response

      -----------------------------------------------------------------------
      -- Downstream aggregated PermCheck client face (toward mkPermCheckSrv)
      -----------------------------------------------------------------------
      permCltReqValid  : out sl;                            -- aggregated request valid
      permCltReqData   : out slv(PERM_REQ_WIDTH_G-1 downto 0);  -- PermCheckReq
      permCltReqRd     : in  sl;                            -- downstream request.get
      permCltRespValid : in  sl;                            -- downstream response.put fired
      permCltRespData  : in  slv(PERM_RESP_WIDTH_G-1 downto 0); -- Bool response payload
      permCltRespReady : out sl);                           -- can accept a response put
end entity PermCheckCltArbiter;

architecture rtl of PermCheckCltArbiter is

   -- portSz = TMul#(2, MAX_QP) = 2*MAX_QP (OQ-FSM-PERMARB-01). Power-of-2 whenever
   -- MAX_QP_G is, satisfying the child arbitration-tree proviso.
   constant PORT_COUNT_C : positive := 2*MAX_QP_G;

   -- isPermCheckReqFinished = True for every port (OQ-FSM-17). Explicit constant
   -- so the vector tie-off has an unambiguous subtype in the port association.
   constant ALL_REQ_FINISHED_C : slv(PORT_COUNT_C-1 downto 0) := (others => '1');

begin

   -- MAX_QP proviso (MAX_QP_G generic convention). The child ClientArbiter carries
   -- the same power-of-2 guard on PORT_COUNT_G; this local copy names the offending
   -- entity if a parent mis-parameterizes MAX_QP_G.
   assert isPowerOf2(MAX_QP_G)
      report "PermCheckCltArbiter: MAX_QP_G must be a power of 2, >= 1 " &
             "(child gets PORT_COUNT_G = 2*MAX_QP_G >= 2; OQ-FSM-PERMARB-01)"
      severity failure;

   --------------------------------------------------------------------------
   -- U_PermCheckArb : the sole child (mkClientArbiter specialization).
   --   Boundary forwarded 1:1; both finished predicates constant True -> tie '1'.
   --------------------------------------------------------------------------
   U_PermCheckArb : entity surf.ClientArbiter
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         PORT_COUNT_G      => PORT_COUNT_C,        -- 2*MAX_QP (OQ-FSM-PERMARB-01)
         REQ_WIDTH_G       => PERM_REQ_WIDTH_G,    -- 267 (PermCheckReq)
         RESP_WIDTH_G      => PERM_RESP_WIDTH_G,   -- 1   (Bool)
         MEMORY_TYPE_G     => MEMORY_TYPE_G,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G)
      port map (
         clk             => clk,
         rst             => rst,
         -- Upstream per-QP client faces (1:1 forward)
         cltReqValid     => permSrvReqValid,
         cltReqData      => permSrvReqData,
         cltReqFinished  => ALL_REQ_FINISHED_C,    -- isPermCheckReqFinished = True (OQ-FSM-17)
         cltReqGet       => permSrvReqGet,
         cltRespValid    => permSrvRespValid,
         cltRespData     => permSrvRespData,
         cltRespReady    => permSrvRespReady,
         -- Downstream aggregated client face (1:1 forward)
         outReqValid     => permCltReqValid,
         outReqData      => permCltReqData,
         outReqRd        => permCltReqRd,
         outRespValid    => permCltRespValid,
         outRespData     => permCltRespData,
         outRespFinished => '1',                   -- isPermCheckRespFinished = True (OQ-FSM-17)
         outRespReady    => permCltRespReady);

end architecture rtl;
