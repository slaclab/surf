-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Classic 7-state Moore dispatcher (the only sibling in MetaData.bsv with a
--   real stateReg). Demultiplexes an incoming MetaDataReq (tagged union
--   PD/MR/QP) to the matching metadata sub-server, waits one state for the
--   response, and enqueues a MetaDataResp. Strictly one request in flight
--   ("Do not use pipeline to avoid conflict requests", MetaData.bsv:692):
--   RECV_REQ -> {MR,PD,QP}_REQ -> {MR,PD,QP}_RESP -> RECV_REQ.
--
--   pdMetaData / qpMetaData are BSV module ARGUMENTS (interfaces passed in by
--   mkTransportLayer), NOT children of this module. Per the OQ-FSM-MDSRV-01
--   resolution they surface here as external CLIENT port groups, wired by the
--   parent TransportLayer to the sibling MetaDataPDs / MetaDataQPs entities:
--     * pdReq*/pdResp*        <-> MetaDataPDs.srvReq*/srvResp*
--     * isValidPdHandler/isValidPd <-> MetaDataPDs.isValidPdHandler/isValidPd
--     * mrSrv*                <-> MetaDataPDs.mrSrv*  (getMRs4PD interface-
--       return flattened; group added to MetaDataPDs per RESOLVED section 4.1)
--     * qpReq*/qpResp*        <-> MetaDataQPs.srvReq*/srvResp*  (parent nets
--       should be named mdSrvQp* to avoid MetaDataQPs' own qpReq* bundle)
--
--   Invalid-PD behaviour (faithful to BSV `if` predication — do NOT over-gate):
--     * MR path: when mrSrvPdValid='0' no MR sub-server is touched; a default
--       RespMR{successOrNot=False, mr/lkey/rkey echoed from the request} is
--       enqueued immediately (MetaData.bsv:740-745).
--     * QP path: when isValidPd='0' no QP request is issued; a default
--       RespQP{successOrNot=False, qpn/pdHandler/qpAttr/qpInitAttr echoed}
--       is enqueued immediately (MetaData.bsv:767-773).
--   isValidPd / mrSrvPdValid are combinational lookups in MetaDataPDs, driven
--   from held registers here, and cannot change between the REQ and RESP
--   states of one op (PD dealloc only flows through this same serialized FSM).
--
--   Bit packing (BSV deriving(Bits), first-field-at-MSB; unions tag-at-MSB
--   with LSB-justified payload — project convention):
--     MetaDataReq [302:0] : tag[302:301] (Req4PD=00, Req4MR=01, Req4QP=10),
--       payload LSB-justified in [300:0] (ReqPD [63:0], ReqMR [251:0],
--       ReqQP [300:0]); unused high payload bits ignored.
--     MetaDataResp [275:0]: tag[275:274] (Resp4PD=00, Resp4MR=01, Resp4QP=10),
--       payload LSB-justified in [273:0], zero-filled above.
--     ReqMR  [251:0] : allocOrNot[251] mr[250:65] lkeyOrNot[64] lkey[63:32]
--                      rkey[31:0]
--     RespMR [250:0] : successOrNot[250] mr[249:64] lkey[63:32] rkey[31:0]
--     MemRegion [185:0] (within mr): laddr[185:122] len[121:90] accFlags[89:82]
--                      pdHandler[81:50] lkeyPart[49:25] rkeyPart[24:0]
--       => mrReq.mr.pdHandler = ReqMR[146:115]
--     ReqPD  [63:0]  : allocOrNot[63] pdKey[62:32] pdHandler[31:0]
--       (NOTE: fsm.md's REQ_PD_W=65 was an off-by-one; 64 b is correct,
--        reconciled against MetaDataPDs.srvReqData(63:0) — RESOLVED section 3)
--     RespPD [63:0]  : successOrNot[63] pdHandler[62:31] pdKey[30:0]
--     ReqQP  [300:0] : qpReqType[300:299] pdHandler[298:267] qpn[266:243]
--                      qpAttrMask[242:217] qpAttr[216:5] qpInitAttr[4:0]
--     RespQP [273:0] : successOrNot[273] qpn[272:249] pdHandler[248:217]
--                      qpAttr[216:5] qpInitAttr[4:0]
--
--   SURF instances (BSV mkFIFOF -> surf.Fifo, sync FWFT, 16-deep at the
--   ADDR_WIDTH_G=4 minimum; extra depth over BSV's 2-deep is behaviour-
--   preserving for the notFull/notEmpty handshake, same call as OQ-EMIT-PCS-02):
--     U_MetaDataReqQ  : surf.Fifo  DATA_WIDTH_G=303, FWFT, sync, block
--     U_MetaDataRespQ : surf.Fifo  DATA_WIDTH_G=276, FWFT, sync, block
--
--   mkRegU note: mrReqReg/pdReqReg/qpReqReg have NO reset in BSV (mkRegU);
--   write-before-read is guaranteed by the REQ->RESP state ordering. Their
--   REG_INIT_C zeros are don't-care initials, not functional resets.
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

entity MetaDataSrv is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk              : in  sl;
      rst              : in  sl;        -- active-high synchronous reset
      -----------------------------------------------------------------------
      -- srvPort : Server#(MetaDataReq(303b), MetaDataResp(276b))
      -- (request face: caller enq; ready = U_MetaDataReqQ not full)
      -----------------------------------------------------------------------
      srvReqValid      : in  sl;
      srvReqData       : in  slv(302 downto 0);  -- MetaDataReq
      srvReqReady      : out sl;
      -- (response face; FWFT: srvRespReady = caller deq strobe)
      srvRespValid     : out sl;
      srvRespData      : out slv(275 downto 0);  -- MetaDataResp
      srvRespReady     : in  sl;
      -----------------------------------------------------------------------
      -- pdMetaData.srvPort client (-> MetaDataPDs.srvReq*/srvResp*)
      -----------------------------------------------------------------------
      pdReqValid       : out sl;
      pdReqData        : out slv(63 downto 0);   -- ReqPD
      pdReqReady       : in  sl;
      pdRespValid      : in  sl;
      pdRespData       : in  slv(63 downto 0);   -- RespPD
      pdRespReady      : out sl;
      -----------------------------------------------------------------------
      -- pdMetaData.isValidPD lookup (-> MetaDataPDs.isValidPdHandler/isValidPd)
      -- combinational; sampled in QP_REQ_S and QP_RESP_S
      -----------------------------------------------------------------------
      isValidPdHandler : out slv(31 downto 0);   -- = qpReqReg.pdHandler
      isValidPd        : in  sl;
      -----------------------------------------------------------------------
      -- pdMetaData.getMRs4PD interface-return, flattened MR sub-server client
      -- (-> MetaDataPDs.mrSrv* group, RESOLVED OQ-FSM-MDSRV-01 section 2.3/4.1)
      -----------------------------------------------------------------------
      mrSrvPdHandler   : out slv(31 downto 0);   -- = mrReqReg.mr.pdHandler
      mrSrvPdValid     : in  sl;        -- isValid(getMRs4PD(handler))
      mrSrvReqValid    : out sl;
      mrSrvReqData     : out slv(251 downto 0);  -- ReqMR
      mrSrvReqReady    : in  sl;
      mrSrvRespValid   : in  sl;
      mrSrvRespData    : in  slv(250 downto 0);  -- RespMR
      mrSrvRespReady   : out sl;
      -----------------------------------------------------------------------
      -- qpMetaData.srvPort client (-> MetaDataQPs.srvReq*/srvResp*)
      -----------------------------------------------------------------------
      qpReqValid       : out sl;
      qpReqData        : out slv(300 downto 0);  -- ReqQP
      qpReqReady       : in  sl;
      qpRespValid      : in  sl;
      qpRespData       : in  slv(273 downto 0);  -- RespQP
      qpRespReady      : out sl);
end entity MetaDataSrv;

architecture rtl of MetaDataSrv is

   ---------------------------------------------------------------------------
   -- Widths (traced, see header packing table)
   ---------------------------------------------------------------------------
   constant MD_REQ_W_C  : integer := 303;  -- MetaDataReq  = 2 + 301
   constant MD_RESP_W_C : integer := 276;  -- MetaDataResp = 2 + 274

   -- MetaDataReq / MetaDataResp union tags (declaration order = encoding)
   constant TAG_PD_C : slv(1 downto 0) := "00";
   constant TAG_MR_C : slv(1 downto 0) := "01";
   constant TAG_QP_C : slv(1 downto 0) := "10";

   ---------------------------------------------------------------------------
   -- Types and records
   ---------------------------------------------------------------------------
   type StateType is (
      RECV_REQ_S,                       -- META_DATA_RECV_REQ (000)
      MR_REQ_S,                         -- META_DATA_MR_REQ   (001)
      PD_REQ_S,                         -- META_DATA_PD_REQ   (010)
      QP_REQ_S,                         -- META_DATA_QP_REQ   (011)
      MR_RESP_S,                        -- META_DATA_MR_RESP  (100)
      PD_RESP_S,                        -- META_DATA_PD_RESP  (101)
      QP_RESP_S);                       -- META_DATA_QP_RESP  (110)

   type RegType is record
      state : StateType;
      mrReq : slv(251 downto 0);  -- mrReqReg (BSV mkRegU — init is don't-care)
      pdReq : slv(63 downto 0);   -- pdReqReg (BSV mkRegU — init is don't-care)
      qpReq : slv(300 downto 0);  -- qpReqReg (BSV mkRegU — init is don't-care)
   end record RegType;

   constant REG_INIT_C : RegType := (
      state => RECV_REQ_S,              -- mkReg(META_DATA_RECV_REQ)
      mrReq => (others => '0'),
      pdReq => (others => '0'),
      qpReq => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   ---------------------------------------------------------------------------
   -- U_MetaDataReqQ (303 b) : srvPort.request write side / recvMetaDataReq read
   ---------------------------------------------------------------------------
   signal reqQWrEn    : sl;
   signal reqQNotFull : sl;
   signal reqQRdEn    : sl;
   signal reqQValid   : sl;
   signal reqQDout    : slv(MD_REQ_W_C-1 downto 0);

   ---------------------------------------------------------------------------
   -- U_MetaDataRespQ (276 b) : genResp4* write side / srvPort.response read
   ---------------------------------------------------------------------------
   signal respQWrEn    : sl;
   signal respQDin     : slv(MD_RESP_W_C-1 downto 0);
   signal respQNotFull : sl;
   signal respQRdEn    : sl;
   signal respQValid   : sl;
   signal respQDout    : slv(MD_RESP_W_C-1 downto 0);

begin

   ---------------------------------------------------------------------------
   -- U_MetaDataReqQ : BSV metaDataReqQ (mkFIFOF), server request face
   -- source: surf/base/fifo/rtl/Fifo.vhd
   ---------------------------------------------------------------------------
   U_MetaDataReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => MD_REQ_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => rst,
         wr_clk        => clk,
         wr_en         => reqQWrEn,
         din           => srvReqData,
         not_full      => reqQNotFull,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         full          => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => reqQRdEn,
         dout          => reqQDout,
         valid         => reqQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_MetaDataRespQ : BSV metaDataRespQ (mkFIFOF), server response face
   -- source: surf/base/fifo/rtl/Fifo.vhd
   ---------------------------------------------------------------------------
   U_MetaDataRespQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => MD_RESP_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => rst,
         wr_clk        => clk,
         wr_en         => respQWrEn,
         din           => respQDin,
         not_full      => respQNotFull,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         full          => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => respQRdEn,
         dout          => respQDout,
         valid         => respQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- Server face glue (toGPServer(metaDataReqQ, metaDataRespQ), MetaData.bsv:784)
   ---------------------------------------------------------------------------
   reqQWrEn    <= srvReqValid and reqQNotFull;
   srvReqReady <= reqQNotFull;

   srvRespValid <= respQValid;
   srvRespData  <= respQDout;
   respQRdEn    <= srvRespReady and respQValid;

   ---------------------------------------------------------------------------
   -- Combinational process — one BSV rule per state branch, atomic v-blocks
   ---------------------------------------------------------------------------
   comb : process (isValidPd, mrSrvPdValid, mrSrvReqReady, mrSrvRespData,
                   mrSrvRespValid, pdReqReady, pdRespData, pdRespValid,
                   qpReqReady, qpRespData, qpRespValid, r, reqQDout, reqQValid,
                   respQNotFull, rst) is
      variable v           : RegType;
      variable vReqQRdEn   : sl;
      variable vRespQWrEn  : sl;
      variable vRespQDin   : slv(MD_RESP_W_C-1 downto 0);
      variable vPdReqValid : sl;
      variable vPdRespRdy  : sl;
      variable vMrReqValid : sl;
      variable vMrRespRdy  : sl;
      variable vQpReqValid : sl;
      variable vQpRespRdy  : sl;
      variable vMrResp     : slv(250 downto 0);
      variable vQpResp     : slv(273 downto 0);
   begin
      v := r;

      -- strobe defaults
      vReqQRdEn   := '0';
      vRespQWrEn  := '0';
      vRespQDin   := (others => '0');
      vPdReqValid := '0';
      vPdRespRdy  := '0';
      vMrReqValid := '0';
      vMrRespRdy  := '0';
      vQpReqValid := '0';
      vQpRespRdy  := '0';

      case r.state is
         ------------------------------------------------------------------
         -- rule recvMetaDataReq (MetaData.bsv:693-711)
         ------------------------------------------------------------------
         when RECV_REQ_S =>
            if (reqQValid = '1') then
               vReqQRdEn := '1';        -- metaDataReqQ.deq
               case reqQDout(302 downto 301) is
                  when TAG_MR_C =>
                     v.mrReq := reqQDout(251 downto 0);
                     v.state := MR_REQ_S;
                  when TAG_PD_C =>
                     v.pdReq := reqQDout(63 downto 0);
                     v.state := PD_REQ_S;
                  when TAG_QP_C =>
                     v.qpReq := reqQDout(300 downto 0);
                     v.state := QP_REQ_S;
                  when others =>
                     null;        -- tag "11" unreachable; request dropped
               end case;
            end if;

         ------------------------------------------------------------------
         -- rule issueReq4MR (MetaData.bsv:713-721)
         -- put only when getMRs4PD hit; advance unconditionally
         ------------------------------------------------------------------
         when MR_REQ_S =>
            if (mrSrvPdValid = '0') then
               v.state := MR_RESP_S;    -- no MR server touched
            else
               vMrReqValid := '1';      -- srvPort.request.put
               if (mrSrvReqReady = '1') then
                  v.state := MR_RESP_S;
               end if;
            end if;

         ------------------------------------------------------------------
         -- rule issueReq4PD (MetaData.bsv:723-727) — unconditional put
         ------------------------------------------------------------------
         when PD_REQ_S =>
            vPdReqValid := '1';         -- srvPort.request.put
            if (pdReqReady = '1') then
               v.state := PD_RESP_S;
            end if;

         ------------------------------------------------------------------
         -- rule issueReq4QP (MetaData.bsv:729-736)
         -- put only when isValidPD; advance unconditionally
         ------------------------------------------------------------------
         when QP_REQ_S =>
            if (isValidPd = '0') then
               v.state := QP_RESP_S;    -- no QP request issued
            else
               vQpReqValid := '1';      -- srvPort.request.put
               if (qpReqReady = '1') then
                  v.state := QP_RESP_S;
               end if;
            end if;

         ------------------------------------------------------------------
         -- rule genResp4MR (MetaData.bsv:738-755)
         -- default RespMR{successOrNot=False, mr, lkey, rkey} unless PD hit
         ------------------------------------------------------------------
         when MR_RESP_S =>
            vMrResp := '0' & r.mrReq(250 downto 65) & r.mrReq(63 downto 0);
            if (mrSrvPdValid = '1') then
               vMrResp := mrSrvRespData;          -- srvPort.response.get
            end if;
            if (respQNotFull = '1') and
               ((mrSrvPdValid = '0') or (mrSrvRespValid = '1')) then
               if (mrSrvPdValid = '1') then
                  vMrRespRdy := '1';              -- deq MR server response
               end if;
               vRespQWrEn                := '1';  -- metaDataRespQ.enq
               vRespQDin(275 downto 274) := TAG_MR_C;
               vRespQDin(250 downto 0)   := vMrResp;
               v.state                   := RECV_REQ_S;
            end if;

         ------------------------------------------------------------------
         -- rule genResp4PD (MetaData.bsv:757-763) — unconditional get
         ------------------------------------------------------------------
         when PD_RESP_S =>
            if (pdRespValid = '1') and (respQNotFull = '1') then
               vPdRespRdy                := '1';  -- srvPort.response.get
               vRespQWrEn                := '1';  -- metaDataRespQ.enq
               vRespQDin(275 downto 274) := TAG_PD_C;
               vRespQDin(63 downto 0)    := pdRespData;
               v.state                   := RECV_REQ_S;
            end if;

         ------------------------------------------------------------------
         -- rule genResp4QP (MetaData.bsv:765-782)
         -- default RespQP{successOrNot=False, qpn, pdHandler, qpAttr,
         -- qpInitAttr} unless PD valid
         ------------------------------------------------------------------
         when QP_RESP_S =>
            vQpResp := '0' & r.qpReq(266 downto 243)  -- qpn
                       & r.qpReq(298 downto 267)      -- pdHandler
                       & r.qpReq(216 downto 5)        -- qpAttr
                       & r.qpReq(4 downto 0);         -- qpInitAttr
            if (isValidPd = '1') then
               vQpResp := qpRespData;                 -- srvPort.response.get
            end if;
            if (respQNotFull = '1') and
               ((isValidPd = '0') or (qpRespValid = '1')) then
               if (isValidPd = '1') then
                  vQpRespRdy := '1';                  -- deq QP server response
               end if;
               vRespQWrEn                := '1';      -- metaDataRespQ.enq
               vRespQDin(275 downto 274) := TAG_QP_C;
               vRespQDin(273 downto 0)   := vQpResp;
               v.state                   := RECV_REQ_S;
            end if;

      end case;

      -- synchronous reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      -- FIFO strobes and handshake outputs (Mealy strobes, single-cycle)
      reqQRdEn       <= vReqQRdEn;
      respQWrEn      <= vRespQWrEn;
      respQDin       <= vRespQDin;
      pdReqValid     <= vPdReqValid;
      pdRespReady    <= vPdRespRdy;
      mrSrvReqValid  <= vMrReqValid;
      mrSrvRespReady <= vMrRespRdy;
      qpReqValid     <= vQpReqValid;
      qpRespReady    <= vQpRespRdy;

      -- Moore data outputs from held registers (stable across REQ->RESP pairs)
      pdReqData        <= r.pdReq;
      mrSrvReqData     <= r.mrReq;
      mrSrvPdHandler   <= r.mrReq(146 downto 115);  -- mrReqReg.mr.pdHandler
      qpReqData        <= r.qpReq;
      isValidPdHandler <= r.qpReq(298 downto 267);  -- qpReqReg.pdHandler
   end process comb;

   ---------------------------------------------------------------------------
   -- Sequential process
   ---------------------------------------------------------------------------
   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
