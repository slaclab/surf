-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   QP metadata manager. A QP-control Server#(ReqQP, RespQP) face routes
--   CREATE/DESTROY requests through the tag-vector allocator (index+pdHandler
--   alloc/free) and forwards every accepted request to the addressed per-QP
--   controller via the per-QP client bundle. The module owns NO registers
--   (inventory state=[]): it is a 3-locus Mealy handshake router around two
--   surf.Fifo instances and the TagVecSrv child. The RegType record carries a
--   single dummy field so the two-process skeleton is retained for uniformity
--   (same pattern as PipeOutMux.vhd).
--
--   The three atomic loci (may all fire in the same cycle — disjoint FIFO
--   ports, no priority):
--     A. srvPort.request.put : enq U_QpReqQ4Cntrl; CREATE/DESTROY also puts
--        {create, pdHandler, qpIndex} to the tag vector.
--     B. rule handleReqQP    : deq U_QpReqQ4Cntrl; CREATE/DESTROY consumes the
--        tag-vector response (on success rewrites qpn := genQPN(idx, pd) and
--        pdHandler, then puts the request to QP[idx]); MODIFY/QUERY puts the
--        unmodified request to QP[getIndexQP(qpn)]; enq
--        {tagVecRespSuccess, qpReq'} to U_QpReqQ4Resp.
--     C. srvPort.response.get: deq U_QpReqQ4Resp; on success fetches the
--        addressed QP's RespQP, otherwise returns the default failure RespQP
--        (successOrNot='0', fields echoed from the stored request).
--
--   ReqQP packing (301 b, traced via CntrlQp.vhd):
--     qpReqType[300:299]  pdHandler[298:267]  qpn[266:243]
--     qpAttrMask[242:217] qpAttr[216:5]       qpInitAttr[4:0]
--   RespQP packing (274 b):
--     successOrNot[273]   qpn[272:249]        pdHandler[248:217]
--     qpAttr[216:5]       qpInitAttr[4:0]
--   getIndexQP(qpn) = truncateLSB(qpn) = qpn's top log2(MAX_QP_G) bits.
--   genQPN(idx, pd) = { idx , truncate(pd) } (idx in the QPN MSBs).
--
--   Per-QP srvPortQP client bundle (OQ-FSM-MDQPS-01 resolution §2.2): one
--   shared request payload + one-hot qpReqValid / per-QP qpReqReady; per-QP
--   response payloads (flattened, QP k at slice
--   qpRespData((k+1)*274-1 downto k*274)) + valid vector / one-hot ready.
--   In TransportLayer each bundle index wires 1:1 to U_Qp(k)'s srvPort* face
--   (Qp.vhd srvPortReq*/srvPortResp* ports); nothing else may drive it.
--
--   Interface methods lowered to ports:
--     getPD(qpn)   -> getPdQpn/getPdMaybeValid/getPdHandler (matches the
--                     consumer-side names in InputRdmaPktBufAndHeaderValidation)
--     isValidQP(qpn) = isValid(getPD(qpn)) -> same lookup; use getPdMaybeValid.
--                     (No live BSV consumer besides getPD @ InputPktHandle:490.)
--     getQueuePairByQPN / getQueuePairByIndexQP -> DELETED per OQ-FSM-MDQPS-01
--                     (static wiring + status mux move to TransportLayer /
--                     InputRdmaPktBufAndHeaderValidation).
--     notEmpty/notFull -> forwarded TagVecSrv status.
--     clear() is commented out in the BSV source -> U_QpTagVec.clearEn tied '0'.
--
--   SURF components instantiated (surf/base/fifo/rtl/Fifo.vhd):
--     U_QpReqQ4Cntrl : surf.Fifo  (BSV qpReqQ4Cntrl <- mkFIFOF, ReqQP, 301 b)
--     U_QpReqQ4Resp  : surf.Fifo  (BSV qpReqQ4Resp  <- mkFIFOF,
--                                  Tuple2#(Bool,ReqQP), 302 b, flag in MSB)
--   Both sync + FWFT (valid = notEmpty, dout = first, rd_en = deq).
--   Child entity: U_QpTagVec : surf.TagVecSrv (V_SZ_G=MAX_QP_G, T_SZ_G=32).
-------------------------------------------------------------------------------
-- This file is part of the BSV->VHDL transpilation output. It targets the SURF
-- VHDL library and follows the SURF coding standard (style/vhdl-style-rules.md).
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

entity MetaDataQPs is
   generic (
      TPD_G             : time     := 1 ns;
      RST_POLARITY_G    : sl       := '1';  -- '1' for active HIGH reset
      RST_ASYNC_G       : boolean  := false;
      MEMORY_TYPE_G     : string   := "distributed";   -- small FIFOs
      MAX_QP_G          : positive := 4;  -- MAX_QP (Settings.bsv), power of 2
      PD_HANDLE_WIDTH_G : positive := 32);  -- PD_HANDLE_WIDTH (DataTypes.bsv)
   port (
      clk             : in  sl;
      rst             : in  sl := not RST_POLARITY_G;
      -- srvPort : Server#(ReqQP(301b), RespQP(274b)) (request face)
      srvReqValid     : in  sl;
      srvReqData      : in  slv(300 downto 0);
      srvReqReady     : out sl;         -- CAN_PUT (type-dependent, see A)
      -- srvPort (response face; FWFT: srvRespReady = deq strobe)
      srvRespValid    : out sl;
      srvRespData     : out slv(273 downto 0);
      srvRespReady    : in  sl;
      -- Per-QP srvPortQP client bundle (index k <-> U_Qp(k).srvPort* in parent)
      qpReqValid      : out slv(MAX_QP_G-1 downto 0);  -- one-hot request put
      qpReqData       : out slv(300 downto 0);         -- shared ReqQP payload
      qpReqReady      : in  slv(MAX_QP_G-1 downto 0);  -- per-QP CAN_PUT
      qpRespValid     : in  slv(MAX_QP_G-1 downto 0);  -- per-QP response valid
      qpRespData      : in  slv(MAX_QP_G*274-1 downto 0);  -- per-QP RespQP slices
      qpRespReady     : out slv(MAX_QP_G-1 downto 0);  -- one-hot response deq
      -- getPD(qpn) / isValidQP(qpn) combinational lookup
      getPdQpn        : in  slv(23 downto 0);
      getPdMaybeValid : out sl;         -- Maybe tag (= isValidQP result)
      getPdHandler    : out slv(PD_HANDLE_WIDTH_G-1 downto 0);
      -- Status methods (forwarded TagVecSrv status)
      notEmpty        : out sl;
      notFull         : out sl);
end entity MetaDataQPs;

architecture rtl of MetaDataQPs is

   -----------------------------------------------------------------------------
   -- Constants (widths traced from BSV types via CntrlQp.vhd / Qp.vhd)
   -----------------------------------------------------------------------------
   constant QPN_W_C           : integer := 24;              -- QPN (IB spec)
   constant PD_W_C            : integer := PD_HANDLE_WIDTH_G;  -- HandlerPD = 32
   constant QP_IDX_W_C        : integer := log2(MAX_QP_G);  -- IndexQP = 2
   constant REQ_QP_W_C        : integer := 301;             -- ReqQP packed
   constant RESP_QP_W_C       : integer := 274;             -- RespQP packed
   constant RESP_FIFO_W_C     : integer := 1 + REQ_QP_W_C;  -- {flag, ReqQP} = 302
   constant TAG_MSG_W_C       : integer := 1 + PD_W_C + QP_IDX_W_C;  -- TagVecSrv 35
   constant FIFO_ADDR_WIDTH_C : integer := 4;  -- surf.Fifo minimum

   -- ReqQP field offsets (LSB index of each field)
   constant REQ_TYPE_LSB_C : integer := 299;  -- qpReqType[300:299]
   constant REQ_PD_LSB_C   : integer := 267;  -- pdHandler[298:267]
   constant REQ_QPN_LSB_C  : integer := 243;  -- qpn[266:243]
   constant REQ_ATTR_LSB_C : integer := 5;    -- qpAttr[216:5]
   -- RespQP field offsets
   constant RESP_QPN_LSB_C : integer := 249;  -- qpn[272:249]
   constant RESP_PD_LSB_C  : integer := 217;  -- pdHandler[248:217]

   -- qpReqType enum encoding (DataTypes.bsv, confirmed in CntrlQp.vhd)
   constant REQ_QP_CREATE_C  : slv(1 downto 0) := "00";
   constant REQ_QP_DESTROY_C : slv(1 downto 0) := "01";

   -----------------------------------------------------------------------------
   -- Types / records: no owned BSV state (inventory state=[]) — one dummy bit
   -- keeps the RegType record syntactically non-empty (PipeOutMux precedent).
   -----------------------------------------------------------------------------
   type RegType is record
      dummy : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (dummy => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- U_QpReqQ4Cntrl (ReqQP) interface signals
   signal cntrlWrEn    : sl;            -- enq (locus A)
   signal cntrlNotFull : sl;
   signal cntrlRdEn    : sl;            -- deq (locus B)
   signal cntrlDout    : slv(REQ_QP_W_C-1 downto 0);
   signal cntrlValid   : sl;            -- notEmpty (FWFT)

   -- U_QpReqQ4Resp ({flag, ReqQP}) interface signals
   signal respWrEn    : sl;             -- enq (locus B)
   signal respDin     : slv(RESP_FIFO_W_C-1 downto 0);
   signal respNotFull : sl;
   signal respRdEn    : sl;             -- deq (locus C)
   signal respDout    : slv(RESP_FIFO_W_C-1 downto 0);
   signal respValid   : sl;             -- notEmpty (FWFT)

   -- U_QpTagVec interface signals
   signal tagReqValid  : sl;                           -- put (locus A)
   signal tagReqData   : slv(TAG_MSG_W_C-1 downto 0);  -- {create, pd, idx}
   signal tagReqReady  : sl;
   signal tagRespValid : sl;
   signal tagRespData  : slv(TAG_MSG_W_C-1 downto 0);  -- {success, idx, pd}
   signal tagRespReady : sl;                           -- get (locus B)
   signal tagGetOut    : slv(PD_W_C downto 0);         -- {valid, pdHandler}
   -- getIndexQP(getPdQpn): forced to 0 at MAX_QP_G=1 (0-bit BSV index,
   -- MetaData.bsv:349); intermediate signal because the ite sits in a port map
   signal tagGetIdx    : slv(QP_IDX_W_C-1 downto 0);

begin

   -- pragma translate_off
   assert isPowerOf2(MAX_QP_G)
      report "MAX_QP_G must be a power of 2 @ MetaDataQPs"
      severity failure;
   -- pragma translate_on

   -----------------------------------------------------------------------------
   -- Control-request FIFO (BSV qpReqQ4Cntrl : FIFOF#(ReqQP))
   --   wr side = srvPort.request.put (locus A); rd side = rule handleReqQP (B).
   -----------------------------------------------------------------------------
   U_QpReqQ4Cntrl : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,       -- BSV first/deq peek semantics
         MEMORY_TYPE_G   => MEMORY_TYPE_G,
         DATA_WIDTH_G    => REQ_QP_W_C,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_C)
      port map (
         rst      => rst,
         wr_clk   => clk,
         wr_en    => cntrlWrEn,
         din      => srvReqData,
         not_full => cntrlNotFull,
         rd_clk   => clk,
         rd_en    => cntrlRdEn,
         dout     => cntrlDout,
         valid    => cntrlValid);

   -----------------------------------------------------------------------------
   -- Response-descriptor FIFO (BSV qpReqQ4Resp : FIFOF#(Tuple2#(Bool, ReqQP)))
   --   Tuple2 packs the Bool flag in the MSB: flag = dout(301), ReqQP = dout(300:0).
   --   wr side = rule handleReqQP (B); rd side = srvPort.response.get (C).
   -----------------------------------------------------------------------------
   U_QpReqQ4Resp : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => MEMORY_TYPE_G,
         DATA_WIDTH_G    => RESP_FIFO_W_C,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_C)
      port map (
         rst      => rst,
         wr_clk   => clk,
         wr_en    => respWrEn,
         din      => respDin,
         not_full => respNotFull,
         rd_clk   => clk,
         rd_en    => respRdEn,
         dout     => respDout,
         valid    => respValid);

   -----------------------------------------------------------------------------
   -- Tag-vector allocation server (BSV qpTagVec <- mkTagVecSrv,
   -- TagVecSrv#(MAX_QP, HandlerPD)). reqData = {insOrRem, insVal(pd), remIdx};
   -- respData = {success, idx, value(pd)}; getItemOut = {valid, dataVec(idx)}.
   -- BSV clear() is commented out (MetaData.bsv:497) -> clearEn tied '0'.
   -----------------------------------------------------------------------------
   tagGetIdx <= ite(MAX_QP_G > 1,
                    getPdQpn(QPN_W_C-1 downto QPN_W_C-QP_IDX_W_C),
                    "0");

   U_QpTagVec : entity surf.TagVecSrv
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         MEMORY_TYPE_G  => MEMORY_TYPE_G,
         V_SZ_G         => MAX_QP_G,
         T_SZ_G         => PD_W_C)
      port map (
         clk        => clk,
         rst        => rst,
         reqValid   => tagReqValid,
         reqData    => tagReqData,
         reqReady   => tagReqReady,
         respValid  => tagRespValid,
         respData   => tagRespData,
         respReady  => tagRespReady,
         getItemIdx => tagGetIdx,
         getItemOut => tagGetOut,
         tagValid   => open,            -- not needed here (single reader)
         notEmpty   => notEmpty,
         notFull    => notFull,
         clearEn    => '0');

   -----------------------------------------------------------------------------
   -- Combinatorial process: the three Mealy loci (A, B, C). All strobes are
   -- combinational; they may all fire in the same cycle (disjoint FIFO ports).
   -- Left ungated under reset: rst forces the FIFOs'/children's own synchronous
   -- reset, which dominates any concurrent wr_en/rd_en (TagVecSrv precedent).
   -----------------------------------------------------------------------------
   comb : process (r, rst, srvReqValid, srvReqData, srvRespReady, cntrlValid,
                   cntrlDout, cntrlNotFull, respValid, respDout, respNotFull,
                   tagReqReady, tagRespValid, tagRespData, qpReqReady,
                   qpRespValid, qpRespData) is
      variable v : RegType;
      -- Locus A (srvPort.request.put)
      variable aType  : slv(1 downto 0);
      variable aIsCd  : sl;       -- CREATE or DESTROY
      variable aReady : sl;
      variable aFire  : sl;
      -- Locus B (rule handleReqQP)
      variable bType   : slv(1 downto 0);
      variable bIsCd   : sl;
      variable bTagOk  : sl;       -- tag-vec success
      variable bTagIdx : slv(QP_IDX_W_C-1 downto 0);
      variable bTagPd  : slv(PD_W_C-1 downto 0);
      variable bFlag   : sl;       -- tagVecRespSuccess
      variable bIdx    : slv(QP_IDX_W_C-1 downto 0);  -- target QP index
      variable bIdxInt : natural;
      variable bDoPut  : sl;       -- put to QP[bIdx]?
      variable bReq    : slv(REQ_QP_W_C-1 downto 0);  -- qpReq' (maybe rewritten)
      variable bChild  : sl;       -- type-dependent guard
      variable bFire   : sl;
      -- Locus C (srvPort.response.get)
      variable cFlag   : sl;
      variable cReq    : slv(REQ_QP_W_C-1 downto 0);
      variable cIdx    : slv(QP_IDX_W_C-1 downto 0);
      variable cIdxInt : natural;
      variable cResp   : slv(RESP_QP_W_C-1 downto 0);
      variable cValid  : sl;
      variable cFire   : sl;
      -- Mealy strobe/data outputs
      variable vQpReqValid  : slv(MAX_QP_G-1 downto 0);
      variable vQpRespReady : slv(MAX_QP_G-1 downto 0);
   begin
      v := r;

      -- Defaults for Mealy outputs (deasserted unless a locus fires)
      vQpReqValid  := (others => '0');
      vQpRespReady := (others => '0');

      -----------------------------------------------------------------------
      -- Locus A — srvPort.request.put (MetaData.bsv:398-420)
      --   Guard: cntrl notFull AND (MODIFY/QUERY OR tag-vec CAN_PUT). The
      --   tag-vec term applies ONLY to CREATE/DESTROY (do not over-gate).
      -----------------------------------------------------------------------
      aType := srvReqData(300 downto REQ_TYPE_LSB_C);
      aIsCd := ite((aType = REQ_QP_CREATE_C) or (aType = REQ_QP_DESTROY_C),
                   '1', '0');
      aReady := cntrlNotFull and (not aIsCd or tagReqReady);
      aFire  := srvReqValid and aReady;

      -- tuple3(create, pdHandler, getIndexQP(qpn)) to the tag vector
      -- (index term forced to 0 at MAX_QP_G=1: 0-bit BSV index, MetaData.bsv:349)
      tagReqValid <= aFire and aIsCd;
      tagReqData  <= ite(aType = REQ_QP_CREATE_C, '1', '0') &
                    srvReqData(REQ_PD_LSB_C+PD_W_C-1 downto REQ_PD_LSB_C) &
                    ite(MAX_QP_G > 1,
                        srvReqData(REQ_QPN_LSB_C+QPN_W_C-1 downto
                                   REQ_QPN_LSB_C+QPN_W_C-QP_IDX_W_C),
                        "0");
      cntrlWrEn   <= aFire;
      srvReqReady <= aReady;

      -----------------------------------------------------------------------
      -- Locus B — rule handleReqQP (MetaData.bsv:361-395)
      -----------------------------------------------------------------------
      bType := cntrlDout(REQ_QP_W_C-1 downto REQ_TYPE_LSB_C);
      bIsCd := ite((bType = REQ_QP_CREATE_C) or (bType = REQ_QP_DESTROY_C),
                   '1', '0');
      bTagOk  := tagRespData(TAG_MSG_W_C-1);
      bTagIdx := tagRespData(PD_W_C+QP_IDX_W_C-1 downto PD_W_C);
      bTagPd  := tagRespData(PD_W_C-1 downto 0);

      bReq := cntrlDout;
      if (bIsCd = '1') then
         -- consume the tag-vec response (alloc/free result)
         bFlag  := bTagOk;
         bIdx   := bTagIdx;
         bDoPut := bTagOk;
         if (bTagOk = '1') then
            -- qpReq.qpn := genQPN(idx, pd); qpReq.pdHandler := pd
            bReq(REQ_QPN_LSB_C+QPN_W_C-1 downto REQ_QPN_LSB_C) :=
               bTagIdx & bTagPd(QPN_W_C-QP_IDX_W_C-1 downto 0);
            bReq(REQ_PD_LSB_C+PD_W_C-1 downto REQ_PD_LSB_C) := bTagPd;
         end if;
         bChild := tagRespValid and (not bTagOk or qpReqReady(to_integer(unsigned(bTagIdx))));
      else
         -- MODIFY / QUERY: no tag-vec touch, initial True flag
         -- (host-facing qpn index: forced 0 at MAX_QP_G=1, MetaData.bsv:349)
         bFlag := '1';
         bIdx := ite(MAX_QP_G > 1,
                     cntrlDout(REQ_QPN_LSB_C+QPN_W_C-1 downto
                               REQ_QPN_LSB_C+QPN_W_C-QP_IDX_W_C),
                     "0");
         bDoPut := '1';
         bChild := qpReqReady(to_integer(unsigned(bIdx)));
      end if;
      bIdxInt := to_integer(unsigned(bIdx));

      bFire := cntrlValid and respNotFull and bChild;

      cntrlRdEn    <= bFire;
      tagRespReady <= bFire and bIsCd;
      if (bFire = '1' and bDoPut = '1') then
         vQpReqValid(bIdxInt) := '1';
      end if;
      qpReqData <= bReq;
      respWrEn  <= bFire;
      respDin   <= bFlag & bReq;

      -----------------------------------------------------------------------
      -- Locus C — srvPort.response.get (MetaData.bsv:423-475)
      --   FWFT face: srvRespValid = CAN_GET; srvRespReady = caller deq strobe.
      -----------------------------------------------------------------------
      cFlag := respDout(RESP_FIFO_W_C-1);
      cReq  := respDout(REQ_QP_W_C-1 downto 0);
      -- response-demux qpn index: forced 0 at MAX_QP_G=1 (MetaData.bsv:349)
      cIdx := ite(MAX_QP_G > 1,
                  cReq(REQ_QPN_LSB_C+QPN_W_C-1 downto
                       REQ_QPN_LSB_C+QPN_W_C-QP_IDX_W_C),
                  "0");
      cIdxInt := to_integer(unsigned(cIdx));

      -- Default failure RespQP: successOrNot='0', fields echoed from qpReq'
      cResp := (others => '0');
      cResp(RESP_QPN_LSB_C+QPN_W_C-1 downto RESP_QPN_LSB_C) :=
         cReq(REQ_QPN_LSB_C+QPN_W_C-1 downto REQ_QPN_LSB_C);
      cResp(RESP_PD_LSB_C+PD_W_C-1 downto RESP_PD_LSB_C) :=
         cReq(REQ_PD_LSB_C+PD_W_C-1 downto REQ_PD_LSB_C);
      cResp(RESP_PD_LSB_C-1 downto 0) :=
         cReq(RESP_PD_LSB_C-1 downto 0);  -- qpAttr[216:5] + qpInitAttr[4:0]
      if (cFlag = '1') then
         -- successful descriptor: pass the addressed QP's RespQP through
         cResp := qpRespData(cIdxInt*RESP_QP_W_C+RESP_QP_W_C-1 downto
                             cIdxInt*RESP_QP_W_C);
      end if;

      cValid := respValid and (not cFlag or qpRespValid(cIdxInt));
      cFire  := srvRespReady and cValid;

      respRdEn <= cFire;
      if (cFire = '1' and cFlag = '1') then
         vQpRespReady(cIdxInt) := '1';
      end if;
      srvRespValid <= cValid;
      srvRespData  <= cResp;

      -- Synchronous reset (dummy register only)
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin <= v;

      qpReqValid  <= vQpReqValid;
      qpRespReady <= vQpRespReady;

   end process comb;

   -----------------------------------------------------------------------------
   -- Sequential process: register update + async reset option.
   -----------------------------------------------------------------------------
   seq : process (clk, rst) is
   begin
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -----------------------------------------------------------------------------
   -- Combinational status methods (Moore-style reads of the tag vector).
   -- getPD = getItem(getIndexQP(qpn)); isValidQP = the Maybe tag of the same
   -- lookup (getPdMaybeValid). notEmpty/notFull are wired at U_QpTagVec.
   -----------------------------------------------------------------------------
   getPdMaybeValid <= tagGetOut(PD_W_C);
   getPdHandler    <= tagGetOut(PD_W_C-1 downto 0);

end architecture rtl;
