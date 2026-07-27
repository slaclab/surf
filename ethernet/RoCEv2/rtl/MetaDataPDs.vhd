-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Pure STRUCTURAL / combinational wrapper. mkMetaDataPDs declares ZERO rules
--   and ZERO own state (no mkReg/mkRegU, no FIFO, no counter). All PD-tag state
--   lives in the child TagVecSrv; per-PD memory-region tables live in the two
--   MetaDataMRs children. This entity is therefore emitted with NO two-process
--   RegType FSM (OQ-FSM-MDPD-03): child instances + combinational glue only.
--
--   Children (OQ-FSM-MDPD-02 — counts come from the BSV source, not mapping.json
--   which records count=null):
--     * U_PdTagVec : TagVecSrv  (1 instance, V_SZ_G=MAX_PD=2, T_SZ_G=KeyPD=31)
--     * U_PdMrVec  : MetaDataMRs (MAX_PD = 2 instances, for..generate)
--
--   Interface mapping (BSV method -> VHDL ports):
--     * srvPort (Server#(ReqPD,RespPD)) -> request/response handshake, repacked
--       to/from the child TagVecSrv tuple3 request/response.
--         ReqPD  = {allocOrNot(1), pdKey(31), pdHandler(32)}  = 64 b (first->MSB)
--         RespPD = {successOrNot(1), pdHandler(32), pdKey(31)} = 64 b
--         getIndexPD(h) = truncateLSB(h) = the TOP PD_INDEX_WIDTH(=1) bit(s) of
--         the 32-bit handler => index = pdHandler(31).
--     * getMRs4PD(pdHandler) returns a *MetaDataMRs interface handle*
--       (OQ-FSM-MDPD-01). TWO consumers exist, each flattened to its own group:
--         1. mrLkup* : the getMemRegionByLKey/getMemRegionByRKey combinational
--            lookup of the selected child, qualified by tag-valid(idx). Consumer:
--            PermCheckSrv (names per OQ-FSM-PCS-01).
--         2. mrSrv*  : the selected child's REGISTRATION srvPort (request demux /
--            response mux by getIndexPD(mrSrvPdHandler)) + mrSrvPdValid =
--            tag-valid(idx). Consumer: MetaDataSrv (issueReq4MR/genResp4MR via
--            the getMRs4PD interface-return, MetaData.bsv:713-755). Single
--            client, one outstanding MR op (serialized by MetaDataSrv's FSM).
--     * isValidPD(pdHandler) = isValid(getItem(idx)) = tag-valid(idx). LIVE —
--       called from mkMetaDataSrv (MetaData.bsv:731, 775). Consumer: MetaDataSrv.
--     * clear() -> pulse TagVecSrv.clear AND every MetaDataMRs.clear.
--     * notEmpty/notFull -> passthrough from U_PdTagVec.
--
--   REVISION HISTORY (supersedes two original judgment calls):
--     * OQ-FSM-MDPD-04 (was: "MR registration srvPorts tied off") INVALIDATED —
--       the original emit missed the interface-return path: mkMetaDataSrv
--       connects to the children's srvPort THROUGH getMRs4PD. Tie-off made MR
--       registration unreachable (every PermCheckSrv lookup would miss forever).
--       Fixed per RESOLVED OQ-FSM-MDSRV-01 sec.4.1: mrSrv* group + index
--       demux/mux added.
--     * OQ-FSM-MDPD-05 (was: "isValidPD dead; share getItem port, mrLkup
--       priority") premise INVALIDATED — isValidPD is live (see above), and the
--       shared-port arbitration could corrupt it exactly when sampled (mrLkup*
--       is driven concurrently by the PermCheckSrv datapath). Fixed per RESOLVED
--       OQ-FSM-MDSRV-01 sec.4.2 (preferred option): TagVecSrv now exports its
--       tag-valid vector (`tagValid`); isValidPd and mrSrvPdValid read it
--       directly, and the single getItem data port is DEDICATED to mrLkup*.
--       mrLkupReqValid is thereby unused here (retained for port stability;
--       the lookup is served every cycle).
--
--   Bit-packing follows BSV deriving(Bits) first-field-at-MSB (project
--   convention, OQ-FSM-H2DS-04 / OQ-FSM-16).
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

entity MetaDataPDs is
   generic (
      TPD_G             : time     := 1 ns;
      RST_POLARITY_G    : sl       := '1';   -- '1' for active HIGH reset
      RST_ASYNC_G       : boolean  := false;
      MAX_PD_G          : positive := 2;   -- MAX_PD (Settings.bsv:20)
      PD_HANDLE_WIDTH_G : positive := 32;  -- PD_HANDLE_WIDTH (DataTypes.bsv:28)
      MR_REGION_WIDTH_G : positive := 186);  -- SizeOf#(MemRegion)
   port (
      clk : in sl;
      rst : in sl := not RST_POLARITY_G;

      -- srvPort.request : Put#(ReqPD)  (ReqPD = 1 + PD_KEY + PD_HANDLE = 64 b)
      --   high index = 2*PD_HANDLE_WIDTH_G - PD_INDEX_WIDTH = 2*32 - 1 = 63
      srvReqValid : in  sl;
      srvReqData  : in  slv(2*PD_HANDLE_WIDTH_G - log2(MAX_PD_G) downto 0);  -- 64 b
      srvReqReady : out sl;

      -- srvPort.response : Get#(RespPD)  (RespPD = 1 + PD_HANDLE + PD_KEY = 64 b)
      srvRespValid : out sl;
      srvRespData  : out slv(2*PD_HANDLE_WIDTH_G - log2(MAX_PD_G) downto 0);  -- 64 b
      srvRespReady : in  sl;

      -- isValidPD(pdHandler) : Bool  (LIVE — called by MetaDataSrv,
      -- MetaData.bsv:731/775; served from the TagVecSrv tag-valid vector)
      isValidPdHandler : in  slv(PD_HANDLE_WIDTH_G-1 downto 0);
      isValidPd        : out sl;

      -- getMRs4PD(pdHandler), consumer 1: MR-lookup group (-> PermCheckSrv,
      -- OQ-FSM-MDPD-01 / PCS-01)
      mrLkupPdHandler : in  slv(PD_HANDLE_WIDTH_G-1 downto 0);
      mrLkupKey       : in  slv(31 downto 0);  -- LKEY/RKEY (KEY_WIDTH = 32)
      mrLkupByLocal   : in  sl;         -- '1' = LKey lookup, '0' = RKey
      mrLkupReqValid  : in  sl;         -- unused since sec.4.2 fix (kept)
      mrLkupValid     : out sl;         -- Maybe#(MemRegion) tag
      mrLkupData      : out slv(MR_REGION_WIDTH_G-1 downto 0);

      -- getMRs4PD(pdHandler), consumer 2: selected child's registration srvPort
      -- (-> MetaDataSrv.mrSrv*, RESOLVED OQ-FSM-MDSRV-01 sec.2.3/4.1).
      -- Widths fixed by MetaDataMRs.vhd: ReqMR = 252 b, RespMR = 251 b.
      mrSrvPdHandler : in  slv(PD_HANDLE_WIDTH_G-1 downto 0);
      mrSrvPdValid   : out sl;          -- tag-valid(getIndexPD(handler))
      mrSrvReqValid  : in  sl;
      mrSrvReqData   : in  slv(251 downto 0);  -- ReqMR
      mrSrvReqReady  : out sl;
      mrSrvRespValid : out sl;
      mrSrvRespData  : out slv(250 downto 0);  -- RespMR
      mrSrvRespReady : in  sl;

      -- clear() method
      clearEn : in sl;

      -- status methods (passthrough from U_PdTagVec)
      notEmpty : out sl;
      notFull  : out sl);
end entity MetaDataPDs;

architecture rtl of MetaDataPDs is

   -----------------------------------------------------------------------------
   -- Derived widths (traced from BSV provisos, MetaData.bsv:247-263)
   --   PD_INDEX_WIDTH = TLog#(MAX_PD)
   --   PD_KEY_WIDTH   = PD_HANDLE_WIDTH - PD_INDEX_WIDTH
   --   ReqPD  = 1 + PD_KEY_WIDTH + PD_HANDLE_WIDTH
   --   RespPD = 1 + PD_HANDLE_WIDTH + PD_KEY_WIDTH
   --   TagVecSrv tuple3 word = 1 + T_SZ + vLogSz  (T_SZ = KeyPD = PD_KEY_WIDTH)
   -----------------------------------------------------------------------------
   constant PD_IDX_W_C  : integer := log2(MAX_PD_G);                    -- = 1
   constant PD_KEY_W_C  : integer := PD_HANDLE_WIDTH_G - PD_IDX_W_C;    -- = 31
   constant TAG_W_C     : integer := 1 + PD_KEY_W_C + PD_IDX_W_C;       -- = 33
   -- MSB index of the packed ReqPD/RespPD ports (width-1)
   constant REQ_MSB_C   : integer := 2*PD_HANDLE_WIDTH_G - PD_IDX_W_C;  -- = 63
   -- MetaDataMRs srvPort word widths (fixed by that entity's port list)
   constant REQ_MR_W_C  : integer := 252;
   constant RESP_MR_W_C : integer := 251;

   -- Per-child lookup / response arrays
   type MrDataArray is array (0 to MAX_PD_G-1) of slv(MR_REGION_WIDTH_G-1 downto 0);
   type MrRespArray is array (0 to MAX_PD_G-1) of slv(RESP_MR_W_C-1 downto 0);

   -- TagVecSrv interface signals
   signal tagReqData   : slv(TAG_W_C-1 downto 0);
   signal tagRespData  : slv(TAG_W_C-1 downto 0);
   signal tagGetIdx    : slv(PD_IDX_W_C-1 downto 0);
   signal tagGetItem   : slv(PD_KEY_W_C downto 0);  -- {valid, dataVec(idx)} = 32 b
   signal tagValidVec  : slv(MAX_PD_G-1 downto 0);  -- full tag-valid vector
   signal getItemValid : sl;

   -- MetaDataMRs combinational lookup interface (per instance)
   signal mrGetSel   : sl;
   signal mrValidVec : slv(MAX_PD_G-1 downto 0);
   signal mrDataVec  : MrDataArray;

   -- MetaDataMRs registration srvPort demux/mux (per instance)
   signal mrReqValidVec  : slv(MAX_PD_G-1 downto 0);
   signal mrReqReadyVec  : slv(MAX_PD_G-1 downto 0);
   signal mrRespValidVec : slv(MAX_PD_G-1 downto 0);
   signal mrRespReadyVec : slv(MAX_PD_G-1 downto 0);
   signal mrRespDataVec  : MrRespArray;
   signal mrSrvIdx       : slv(PD_IDX_W_C-1 downto 0);

   -- Selected (idx-routed) MR lookup result
   signal selMrIdx   : slv(PD_IDX_W_C-1 downto 0);
   signal selMrValid : sl;
   signal selMrData  : slv(MR_REGION_WIDTH_G-1 downto 0);

begin

   -----------------------------------------------------------------------------
   -- U_PdTagVec : TagVecSrv  (BSV: pdTagVec <- mkTagVecSrv, MetaData.bsv:279)
   --   vSz = MAX_PD = 2 ; anytype = KeyPD = Bit#(31).
   --   Holds all PD-tag state. clear() is routed via clearEn.
   -----------------------------------------------------------------------------
   U_PdTagVec : entity surf.TagVecSrv
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         V_SZ_G         => MAX_PD_G,
         T_SZ_G         => PD_KEY_W_C)
      port map (
         clk        => clk,
         rst        => rst,
         -- request (srvPort.request, repacked from ReqPD)
         reqValid   => srvReqValid,
         reqData    => tagReqData,
         reqReady   => srvReqReady,
         -- response (srvPort.response, repacked into RespPD)
         respValid  => srvRespValid,
         respData   => tagRespData,
         respReady  => srvRespReady,
         -- getItem() combinational lookup (DEDICATED to mrLkup*, sec.4.2)
         getItemIdx => tagGetIdx,
         getItemOut => tagGetItem,
         -- tag-valid vector (serves isValidPd + mrSrvPdValid, sec.4.2)
         tagValid   => tagValidVec,
         -- status
         notEmpty   => notEmpty,
         notFull    => notFull,
         -- clear()
         clearEn    => clearEn);

   -----------------------------------------------------------------------------
   -- U_PdMrVec[0..MAX_PD-1] : MetaDataMRs
   --   (BSV: pdMrVec <- replicateM(mkMetaDataMRs), MetaData.bsv:280, MAX_PD = 2)
   --   Registration srvPort demux/mux: MetaDataSrv drives the child selected by
   --   getIndexPD(mrSrvPdHandler) through the getMRs4PD interface-return
   --   (RESOLVED OQ-FSM-MDSRV-01 sec.4.1; single client, one outstanding op).
   --   The combinational getMemRegionBy{L,R}Key lookup fans out to all children;
   --   the selected result is routed upward via mrLkup*.
   -----------------------------------------------------------------------------
   mrGetSel <= not mrLkupByLocal;  -- MetaDataMRs getMrSel_i: '0'=LKey, '1'=RKey
   -- getIndexPD: at MAX_PD_G=1 the BSV index is 0 bits, i.e. the constant 0 -
   -- force 0 instead of reading a live handle bit (same idiom as getIndexQP)
   mrSrvIdx <= ite(MAX_PD_G > 1,
                   mrSrvPdHandler(PD_HANDLE_WIDTH_G-1 downto PD_HANDLE_WIDTH_G - PD_IDX_W_C),
                   "0");

   GEN_MR : for i in 0 to MAX_PD_G-1 generate

      -- getIndexPD demux: only the addressed child sees the put/get strobes
      mrReqValidVec(i)  <= mrSrvReqValid and toSl(to_integer(unsigned(mrSrvIdx)) = i);
      mrRespReadyVec(i) <= mrSrvRespReady and toSl(to_integer(unsigned(mrSrvIdx)) = i);

      U_PdMr : entity surf.MetaDataMRs
         generic map (
            TPD_G => TPD_G)
         port map (
            clk          => clk,
            rst          => rst,
            -- srvPort.request : from MetaDataSrv via getMRs4PD (demuxed)
            reqValid_i   => mrReqValidVec(i),
            reqData_i    => mrSrvReqData,
            reqReady_o   => mrReqReadyVec(i),
            -- srvPort.response : to MetaDataSrv via getMRs4PD (muxed)
            respValid_o  => mrRespValidVec(i),
            respData_o   => mrRespDataVec(i),
            respReady_i  => mrRespReadyVec(i),
            -- getMemRegionByLKey / getMemRegionByRKey (combinational lookup)
            getMrLKey_i  => mrLkupKey,
            getMrRKey_i  => mrLkupKey,
            getMrSel_i   => mrGetSel,
            getMrValid_o => mrValidVec(i),
            getMrData_o  => mrDataVec(i),
            -- clear() : fanned out to all MetaDataMRs (mapM_ clearAllMRs)
            clearEn_i    => clearEn,
            -- status : not exported by MetaDataPDs (only TagVecSrv's are)
            notEmpty_o   => open,
            notFull_o    => open);
   end generate GEN_MR;

   -----------------------------------------------------------------------------
   -- Combinational glue (no registers — structural wrapper, OQ-FSM-MDPD-03)
   -----------------------------------------------------------------------------

   -- srvPort.request : ReqPD -> TagVecSrv tuple3(allocOrNot, pdKey, pdIndex)
   --   ReqPD layout (first-field-MSB, 64 b):
   --     allocOrNot = srvReqData(63)
   --     pdKey      = srvReqData(62 downto 32)
   --     pdHandler  = srvReqData(31 downto 0) ; index = pdHandler(31) = MSB
   --   tuple3 word = {allocOrNot(1), pdKey(31), pdIndex(1)} (TagVecSrv reqData)
   tagReqData <= srvReqData(REQ_MSB_C) & -- allocOrNot (MSB)
                 srvReqData(REQ_MSB_C - 1 downto PD_HANDLE_WIDTH_G) & -- pdKey (PD_KEY_W_C b)
                 ite(MAX_PD_G > 1,
                     srvReqData(PD_HANDLE_WIDTH_G-1 downto PD_HANDLE_WIDTH_G - PD_IDX_W_C),
                     "0");  -- pdIndex = top of handler; constant 0 at MAX_PD_G=1

   -- srvPort.response : TagVecSrv tuple3(success, idx, value) -> RespPD
   --   TagVecSrv respData = {success(1), pdIndex(1), pdKey(31)}
   --   pdHandler = {pack(pdIndex), pdKey} = respData(31 downto 0)
   --   RespPD layout (first-field-MSB, 64 b):
   --     successOrNot = respData(32)
   --     pdHandler    = respData(31 downto 0)        (62 downto 31)
   --     pdKey        = respData(30 downto 0)        (30 downto 0)
   srvRespData <= tagRespData(TAG_W_C-1) & -- successOrNot
                  tagRespData(TAG_W_C-2 downto 0) & -- pdHandler = {idx, key}
                  tagRespData(PD_KEY_W_C-1 downto 0);  -- pdKey

   -- getItem() data port: DEDICATED to the mrLkup* consumer (sec.4.2 fix — no
   -- arbitration; mrLkupReqValid no longer gates anything).
   tagGetIdx <= ite(MAX_PD_G > 1,
                    mrLkupPdHandler(PD_HANDLE_WIDTH_G-1 downto PD_HANDLE_WIDTH_G - PD_IDX_W_C),
                    "0");

   getItemValid <= tagGetItem(PD_KEY_W_C);  -- {valid, data} : valid is the MSB

   -- isValidPD(pdHandler) = tag-valid(getIndexPD(handler)) — conflict-free read
   -- of the exported vector (LIVE consumer: MetaDataSrv QP states).
   isValidPd <= tagValidVec(ite(MAX_PD_G > 1,
                                to_integer(unsigned(
                                   isValidPdHandler(PD_HANDLE_WIDTH_G-1 downto PD_HANDLE_WIDTH_G - PD_IDX_W_C))),
                                0));

   -- getMRs4PD validity for the registration client (MetaDataSrv MR states)
   mrSrvPdValid <= tagValidVec(to_integer(unsigned(mrSrvIdx)));

   -- getMRs4PD registration srvPort response mux (selected child -> MetaDataSrv)
   mrSrvReqReady  <= mrReqReadyVec(to_integer(unsigned(mrSrvIdx)));
   mrSrvRespValid <= mrRespValidVec(to_integer(unsigned(mrSrvIdx)));
   mrSrvRespData  <= mrRespDataVec(to_integer(unsigned(mrSrvIdx)));

   -- getMRs4PD lookup consumer: route the selected MetaDataMRs instance's
   -- result, qualified by tag-valid(idx) (= isValid(getItem(idx)) in BSV).
   selMrIdx <= ite(MAX_PD_G > 1,
                   mrLkupPdHandler(PD_HANDLE_WIDTH_G-1 downto PD_HANDLE_WIDTH_G - PD_IDX_W_C),
                   "0");
   selMrValid <= mrValidVec(to_integer(unsigned(selMrIdx)));
   selMrData  <= mrDataVec(to_integer(unsigned(selMrIdx)));

   mrLkupValid <= getItemValid and selMrValid;
   mrLkupData  <= selMrData;

end architecture rtl;
