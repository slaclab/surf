-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Stateless, purely combinational adapter around a single child entity
--   instance `U_MrTagVec : TagVecSrv#(MAX_MR_PER_PD, MemRegion)`.  This entity
--   has NO rules, NO registers, and NO SURF primitives of its own
--   (surf_instances: []); all sequential behaviour (the insert/remove FSM, the
--   tag/data register array, the req/resp FIFOs) lives inside the child
--   TagVecSrv (see out/04-vhdl/TagVecSrv.vhd).  Therefore there is no RegType /
--   REG_INIT_C / two-process FSM here, exactly as the Stage-3 FSM spec directs
--   ("a thin wrapping architecture ... no RegType, no two-process FSM").
--
--   MetaDataMRs only:
--     1. Request path : translate an MR key -> MR index
--        (key2IndexMR = top MR_INDEX_WIDTH bits of the 32-bit key), then forward
--        {allocOrNot, mr, mrIndex} to the child request port.
--     2. Response path: reconstruct local/remote keys from the child response
--        (genLocalAndRmtKey = {mrIndex, mr.lkeyPart} / {mrIndex, mr.rkeyPart}).
--     3. Lookup        : a combinational getItem read (getMemRegionByLKey /
--        getMemRegionByRKey) — see the shared-port note below.
--     4. Forward clear / notEmpty / notFull straight through to the child.
--
--   Struct widths (traced from MetaData.bsv / DataTypes.bsv / Headers.bsv,
--   first-field-at-MSB BSV pack convention — project convention OQ-FSM-H2DS-04):
--     MemRegion = 186 b : laddr[185:122] len[121:90] accFlags[89:82]
--                         pdHandler[81:50] lkeyPart[49:25] rkeyPart[24:0]
--     ReqMR     = 252 b : allocOrNot[251] mr[250:65] lkeyOrNot[64]
--                         lkey[63:32] rkey[31:0]
--     RespMR    = 251 b : successOrNot[250] mr[249:64] lkey[63:32] rkey[31:0]
--     MR_INDEX_WIDTH = TLog#(MAX_MR_PER_PD=128) = 7  (KEY_WIDTH = 32)
--   Child TagVecSrv interface words (V_SZ_G=128 -> log2=7, T_SZ_G=186):
--     reqData  = {allocOrNot[193], mr[192:7], mrIndex[6:0]}        (194 b)
--     respData = {successOrNot[193], mrIndex[192:186], mr[185:0]}  (194 b)
--     getItemOut = {valid[186], dataVec[185:0]}                    (187 b)
--
--   getItem SHARED-PORT NOTE (OQ-FSM-MR-03, RESOLVED at emit — shared+select):
--     The BSV module exposes TWO combinational lookup methods
--     (getMemRegionByLKey, getMemRegionByRKey), each calling the child's
--     getItem.  The emitted TagVecSrv has a SINGLE getItem port.  Per the emit
--     decision, the two lookups SHARE that one child port, multiplexed by
--     getMrSel_i ('0' = LKey, '1' = RKey).  This assumes the parent never needs
--     both lookups in the SAME cycle.  Truly-concurrent lkey+rkey lookups would
--     require a second getItem read port on TagVecSrv (not added here, to keep
--     TagVecSrv and its passing testbench untouched).  See OPEN_QUESTIONS.md.
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

entity MetaDataMRs is
   generic (
      TPD_G          : time     := 1 ns;
      MAX_MR_PER_PD_G : positive := 128);   -- TDiv#(MAX_MR=256, MAX_PD=2) (DataTypes.bsv)
   port (
      clk : in sl;
      rst : in sl;                          -- active-high synchronous reset

      -- srvPort.request : Put#(ReqMR)   (ReqMR = 252 b)
      reqValid_i : in  sl;                  -- request put enable
      reqData_i  : in  slv(251 downto 0);   -- ReqMR packed
      reqReady_o : out sl;                  -- child reqQ not_full (backpressure)

      -- srvPort.response : Get#(RespMR)  (RespMR = 251 b)
      respValid_o : out sl;                 -- child respQ has a response
      respData_o  : out slv(250 downto 0);  -- RespMR packed
      respReady_i : in  sl;                 -- response get enable (downstream)

      -- getMemRegionByLKey / getMemRegionByRKey : shared combinational lookup
      --   (single child getItem port, multiplexed by getMrSel_i; see header note)
      getMrLKey_i  : in  slv(31 downto 0);  -- getMemRegionByLKey arg
      getMrRKey_i  : in  slv(31 downto 0);  -- getMemRegionByRKey arg
      getMrSel_i   : in  sl;                -- '0' = LKey lookup, '1' = RKey lookup
      getMrValid_o : out sl;                -- Maybe#(MemRegion) tag
      getMrData_o  : out slv(185 downto 0); -- MemRegion (valid when getMrValid_o='1')

      -- clear() method
      clearEn_i : in sl;                    -- pulse child clear

      -- status methods
      notEmpty_o : out sl;                  -- child notEmpty
      notFull_o  : out sl);                 -- child notFull
end entity MetaDataMRs;

architecture rtl of MetaDataMRs is

   -- Widths (traced; see header)
   constant MEM_REGION_WIDTH_C : integer := 186;
   constant MR_INDEX_WIDTH_C   : integer := log2(MAX_MR_PER_PD_G);   -- 7 for 128
   constant CHILD_WORD_WIDTH_C : integer := MEM_REGION_WIDTH_C + MR_INDEX_WIDTH_C;  -- 193 (=> slv 193:0, 194 b)

   -- MemRegion sub-field LSB positions within the 186-bit MemRegion word
   constant MR_LKEY_PART_LOW_C : integer := 25;   -- lkeyPart = [49:25]
   constant MR_RKEY_PART_LOW_C : integer := 0;    -- rkeyPart = [24:0]

   -- Request-path glue
   signal reqMrKey   : slv(31 downto 0);                       -- lkeyOrNot ? lkey : rkey
   signal reqMrIndex : slv(MR_INDEX_WIDTH_C-1 downto 0);       -- key2IndexMR = key[31:25]

   -- Child TagVecSrv handshake nets
   signal childReqData    : slv(CHILD_WORD_WIDTH_C downto 0);  -- {allocOrNot, mr, mrIndex} (194 b)
   signal childReqReady   : sl;
   signal childRespData   : slv(CHILD_WORD_WIDTH_C downto 0);  -- {success, mrIndex, mr}   (194 b)
   signal childRespValid  : sl;
   signal childGetItemIdx : slv(MR_INDEX_WIDTH_C-1 downto 0);
   signal childGetItemOut : slv(MEM_REGION_WIDTH_C downto 0);  -- {valid, dataVec} (187 b)
   signal childNotEmpty   : sl;
   signal childNotFull    : sl;

   -- Response-path glue
   signal respSuccess : sl;
   signal respMrIndex : slv(MR_INDEX_WIDTH_C-1 downto 0);
   signal respMr      : slv(MEM_REGION_WIDTH_C-1 downto 0);
   signal lkeyOut     : slv(31 downto 0);
   signal rkeyOut     : slv(31 downto 0);

   -- Lookup-path glue
   signal lkupKey : slv(31 downto 0);

begin

   ---------------------------------------------------------------------------
   -- Request path: key -> index, forward {allocOrNot, mr, mrIndex} to child
   --   mrReqKey = lkeyOrNot ? lkey : rkey ; mrIndex = key2IndexMR(mrReqKey)
   ---------------------------------------------------------------------------
   reqMrKey   <= reqData_i(63 downto 32) when (reqData_i(64) = '1') else reqData_i(31 downto 0);
   reqMrIndex <= reqMrKey(31 downto 31 - MR_INDEX_WIDTH_C + 1);   -- key[31:25] (truncateLSB)

   childReqData <= reqData_i(251) & reqData_i(250 downto 65) & reqMrIndex;  -- allocOrNot & mr & mrIndex
   reqReady_o   <= childReqReady;

   ---------------------------------------------------------------------------
   -- Response path: rebuild local/remote keys from child response
   --   resp_dout = {success, mrIndex(7), mr(186)}
   --   lkey = {mrIndex, mr.lkeyPart} ; rkey = {mrIndex, mr.rkeyPart}
   --   RespMR = {success, mr, lkey, rkey}
   ---------------------------------------------------------------------------
   respSuccess <= childRespData(CHILD_WORD_WIDTH_C);                                   -- bit 193
   respMrIndex <= childRespData(CHILD_WORD_WIDTH_C-1 downto MEM_REGION_WIDTH_C);        -- bits 192:186
   respMr      <= childRespData(MEM_REGION_WIDTH_C-1 downto 0);                         -- bits 185:0

   lkeyOut <= respMrIndex & respMr(MR_LKEY_PART_LOW_C + 24 downto MR_LKEY_PART_LOW_C);  -- {idx, lkeyPart}
   rkeyOut <= respMrIndex & respMr(MR_RKEY_PART_LOW_C + 24 downto MR_RKEY_PART_LOW_C);  -- {idx, rkeyPart}

   respData_o  <= respSuccess & respMr & lkeyOut & rkeyOut;   -- {success, mr, lkey, rkey} (251 b)
   respValid_o <= childRespValid;

   ---------------------------------------------------------------------------
   -- Lookup path (shared single child getItem port, see header OQ-FSM-MR-03)
   --   idx = key2IndexMR(selected key) ; result = child.getItem(idx)
   ---------------------------------------------------------------------------
   lkupKey         <= getMrLKey_i when (getMrSel_i = '0') else getMrRKey_i;
   childGetItemIdx <= lkupKey(31 downto 31 - MR_INDEX_WIDTH_C + 1);   -- key[31:25]

   getMrValid_o <= childGetItemOut(MEM_REGION_WIDTH_C);              -- valid tag (MSB)
   getMrData_o  <= childGetItemOut(MEM_REGION_WIDTH_C-1 downto 0);   -- MemRegion data

   ---------------------------------------------------------------------------
   -- Status / clear pass-through
   ---------------------------------------------------------------------------
   notEmpty_o <= childNotEmpty;
   notFull_o  <= childNotFull;

   ---------------------------------------------------------------------------
   -- U_MrTagVec : child entity TagVecSrv#(MAX_MR_PER_PD, MemRegion)
   --   src : out/04-vhdl/TagVecSrv.vhd  (BSV mkTagVecSrv, MetaData.bsv:193)
   --   NOT a SURF primitive — a project child entity (mapping child_entity_instances).
   ---------------------------------------------------------------------------
   U_MrTagVec : entity surf.TagVecSrv
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         RST_ASYNC_G    => false,
         MEMORY_TYPE_G  => "distributed",
         V_SZ_G         => MAX_MR_PER_PD_G,         -- 128 tag entries
         T_SZ_G         => MEM_REGION_WIDTH_C)      -- 186-bit MemRegion per entry
      port map (
         clk        => clk,
         rst        => rst,
         reqValid   => reqValid_i,
         reqData    => childReqData,
         reqReady   => childReqReady,
         respValid  => childRespValid,
         respData   => childRespData,
         respReady  => respReady_i,
         getItemIdx => childGetItemIdx,
         getItemOut => childGetItemOut,
         tagValid   => open,                        -- not needed here (single reader)
         notEmpty   => childNotEmpty,
         notFull    => childNotFull,
         clearEn    => clearEn_i);

end architecture rtl;
