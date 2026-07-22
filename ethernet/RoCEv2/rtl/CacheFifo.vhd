-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- DESIGN NOTE - two specialised entities (OQ-FSM-CF-01, RESOLVED)
--   mkCacheFIFO is parameterised over THREE combinational stage functions and
--   the stored item type. It is instantiated twice (DupReadAtomicCache.bsv:719-
--   724) with structurally different functions/types. VHDL has no function
--   generics, so per the resolved OQ-FSM-CF-01 this file emits TWO concrete
--   entities, each inlining its own three stage functions:
--     * CacheFifoRead   <- readCacheQ   (ReadCacheItem,   item width 176)
--     * CacheFifoAtomic <- atomicCacheQ (AtomicCacheItem, item width 317)
--   The FSM/pipeline structure (CacheFifo.fsm.md) is identical for both.
--
-- WIDTHS (OQ-FSM-CF-02 / OQ-FSM-CF-03, RESOLVED):
--   readCacheQ   : item=176  searchData=359  cmpResult=235  searchResult=177
--   atomicCacheQ : item=317  searchData=638  cmpResult=325  searchResult=318
--   (searchData = 1 tag + searchType; cmpResult/searchResult = Maybe = 1 tag + value.)
--
-- CLEAR (OQ-FSM-CF-04 / OQ-FSM-01 / OQ-FSM-06 family, RESOLVED):
--   surf.Fifo has no clear port; FIFOF.clear is modelled by a level assertion of
--   the synchronous rst (sync FifoSync re-applies REG_INIT_C every held cycle).
--   fifosRst <= rst or clearActive drives every local FIFO; the BinaryTreeFork /
--   RecursiveSearch children receive clearActive on their own clearAll port.
--
-- CReg(2) clearReg: clear() writes port[0]; clearAll reads+clears port[1] the SAME
--   cycle (fire_when_enabled), so the registered value never persists -> the clear
--   is a pure 1-cycle level pulse == clear() this cycle. Hence clearActive = clearEn
--   and no clearReg register is carried (differs from TagVecSrv's OQ-FSM-03, where
--   method/rule use different CReg ports).
--
-- FIDELITY NOTE: BSV cmpHalfAddr (DupReadAtomicCache.bsv:192-202) has a source
--   bug - its low-half compare reads addrB twice, so addrLowPartMatch is always
--   True. Reproduced faithfully in CacheFifoAtomic.f_secondAtomic (constant '1').
--
-- DEPTH NOTE: BSV mkFIFOF default depth is 2; the intermediate FIFOs here are
--   over-provisioned to depth 2**FIFO_ADDR_WIDTH_G (default 16) to match the
--   sibling BinaryTreeFork/RecursiveSearch entities. Depth does not affect
--   functional correctness under ready/valid flow control.
--
-- dataVec is BSV mkRegU (no reset); REG_INIT_C clears it to 0 (safe - read only
--   when the matching tagVec bit is set; OQ-FSM-04 reasoning).
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CacheFifoRead : readCacheQ specialisation (ReadCacheItem, 176-bit items)
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;

entity CacheFifoRead is
   generic (
      TPD_G             : time                   := 1 ns;
      FIFO_ADDR_WIDTH_G : positive range 4 to 48 := 4;
      MEM_TYPE_G        : string                 := "distributed");
   port (
      clk             : in  sl;
      rst             : in  sl;                      -- active-high synchronous
      pmtu            : in  slv(2 downto 0);         -- PMTU enum (1..5); feeds firstStageFunc
      -- push (insert) method : enq ReadCacheItem
      pushEn          : in  sl;
      pushData        : in  slv(175 downto 0);
      pushReady       : out sl;                      -- = insertQ.not_full
      -- clear method
      clearEn         : in  sl;
      -- searchReq method : enq ReadCacheItem to search for
      searchReqEn     : in  sl;
      searchReqData   : in  slv(175 downto 0);
      searchReqReady  : out sl;                      -- = searchReqQ.not_full
      -- searchResp method : Maybe#(ReadCacheItem) result (valid tag = MSB)
      searchRespValid : out sl;
      searchRespData  : out slv(176 downto 0);
      searchRespRdEn  : in  sl);
end entity CacheFifoRead;

architecture rtl of CacheFifoRead is

   constant QSZ_C      : positive := 16;            -- MAX_QP_RD_ATOM
   constant CNT_W_C    : positive := 4;             -- TLog(QSZ)
   constant ITEM_W_C   : positive := 176;           -- ReadCacheItem
   constant SEARCH_W_C : positive := 358;           -- Tuple6 searchType
   constant CMP_W_C    : positive := 234;           -- Tuple4 cmpResultType
   constant SD_W_C     : positive := 1 + SEARCH_W_C;  -- 359 : Tuple2(Bool, searchType)
   constant CR_W_C     : positive := 1 + CMP_W_C;     -- 235 : Maybe(cmpResultType)
   constant SR_W_C     : positive := 1 + ITEM_W_C;    -- 177 : Maybe(anytype)

   -- Array signal types (one element per lane)
   type SlVecType is array (0 to QSZ_C-1) of sl;
   type ItemArray is array (0 to QSZ_C-1) of slv(ITEM_W_C-1 downto 0);
   type SdArray   is array (0 to QSZ_C-1) of slv(SD_W_C-1 downto 0);
   type CrArray   is array (0 to QSZ_C-1) of slv(CR_W_C-1 downto 0);
   type SrArray   is array (0 to QSZ_C-1) of slv(SR_W_C-1 downto 0);

   -- psnInRangeExclusive (Utils.bsv:386) ; PSN width 24, msb = bit 23
   function f_psnInRange (psn, psnStart, psnEnd : slv(23 downto 0)) return sl is
      variable psnGtStart, psnLtEnd, result : sl;
   begin
      psnGtStart := toSl(unsigned(psnStart) < unsigned(psn));
      psnLtEnd   := toSl(unsigned(psn) < unsigned(psnEnd));
      if (psnStart(23) = psnEnd(23)) then
         result := psnGtStart and psnLtEnd;                       -- no wrap
      else
         result := (psnGtStart and toSl(psnStart(23) = psn(23))) or
                   (psnLtEnd   and toSl(psn(23) = psnEnd(23)));   -- wrapped
      end if;
      return result;
   end function;

   -- firstStageFunc = buildDupReadSearchData(pmtu)  (DupReadAtomicCache.bsv:552)
   --   item4Search = dup (incoming),  itemInQ = orig (stored)
   --   ReadCacheItem layout: startPSN[175:152] endPSN[151:128] reth[127:0]
   --                         reth: va[127:64] rkey[63:32] dlen[31:0]
   function f_firstRead (item4Search, itemInQ : slv(ITEM_W_C-1 downto 0);
                         pmtuI : slv(2 downto 0)) return slv is
      variable psnStartExact, psnEndExact, keyMatch : sl;
   begin
      psnStartExact := toSl(item4Search(175 downto 152) = itemInQ(175 downto 152));
      psnEndExact   := toSl(item4Search(151 downto 128) = itemInQ(151 downto 128));
      keyMatch      := toSl(item4Search(63 downto 32) = itemInQ(63 downto 32));
      -- Tuple6(pmtu, psnStartExact, psnEndExact, keyMatch, dup, orig)
      return pmtuI & psnStartExact & psnEndExact & keyMatch & item4Search & itemInQ;
   end function;

   -- secondStageFunc = compareReadCacheItem  (DupReadAtomicCache.bsv:576)
   --   incl. computeReadEndAddrAndCompare (bsv:17-122) specialised by pmtu shift
   function f_secondRead (searchData : slv(SEARCH_W_C-1 downto 0)) return slv is
      variable pmtuV                                   : slv(2 downto 0);
      variable psnStartExact, psnEndExact, keyMatch    : sl;
      variable dup, orig                               : slv(ITEM_W_C-1 downto 0);
      variable dupStartPSN, dupEndPSN                  : slv(23 downto 0);
      variable origStartPSN, origEndPSN                : slv(23 downto 0);
      variable dupVaHigh, oVaHigh, dupVaLow, oVaLow    : slv(31 downto 0);
      variable dupDlen, origDlen                       : slv(31 downto 0);
      variable addrHighHalfMatch, addrLowHalfMatch     : sl;
      variable readLenMatch, psnStartRange, psnEndRange: sl;
      variable dupLastPkt, origLastPkt                 : slv(24 downto 0);
      variable s                                       : integer range 8 to 12;
      variable cmpParts                                : slv(7 downto 0);
   begin
      pmtuV         := searchData(357 downto 355);
      psnStartExact := searchData(354);
      psnEndExact   := searchData(353);
      keyMatch      := searchData(352);
      dup           := searchData(351 downto 176);
      orig          := searchData(175 downto 0);

      dupStartPSN  := dup(175 downto 152);  dupEndPSN  := dup(151 downto 128);
      origStartPSN := orig(175 downto 152); origEndPSN := orig(151 downto 128);
      dupVaHigh := dup(127 downto 96);  dupVaLow := dup(95 downto 64);  dupDlen  := dup(31 downto 0);
      oVaHigh   := orig(127 downto 96); oVaLow   := orig(95 downto 64); origDlen := orig(31 downto 0);

      addrHighHalfMatch := toSl(dupVaHigh = oVaHigh);

      -- shift = log2(pmtu payload size) : 256->8 512->9 1024->10 2048->11 4096->12
      case pmtuV is
         when "001"  => s := 8;
         when "010"  => s := 9;
         when "011"  => s := 10;
         when "100"  => s := 11;
         when "101"  => s := 12;
         when others => s := 8;
      end case;

      addrLowHalfMatch := toSl(dupVaLow(s-1 downto 0) = oVaLow(s-1 downto 0)) and
                          toSl(dupDlen(s-1 downto 0)  = origDlen(s-1 downto 0));
      readLenMatch     := toSl(unsigned(origDlen(31 downto s)) >= unsigned(dupDlen(31 downto s)));
      dupLastPkt  := slv(resize(unsigned(dupVaLow(31 downto s)) + unsigned(dupDlen(31 downto s)), 25));
      origLastPkt := slv(resize(unsigned(oVaLow(31 downto s)) + unsigned(origDlen(31 downto s)), 25));

      psnStartRange := f_psnInRange(dupStartPSN, origStartPSN, origEndPSN);
      psnEndRange   := f_psnInRange(dupEndPSN,   origStartPSN, origEndPSN);

      -- DupReadCmpParts (8 Bools, first-field-at-MSB)
      cmpParts := addrHighHalfMatch & addrLowHalfMatch & keyMatch &
                  psnStartExact & psnStartRange & psnEndExact & psnEndRange & readLenMatch;
      -- Tuple4(DupReadCmpParts, dupLastPkt, origLastPkt, origReadCacheItem)
      return cmpParts & dupLastPkt & origLastPkt & orig;
   end function;

   -- thirdStageFunc = checkReadCacheItemCmpResult  (DupReadAtomicCache.bsv:617)
   function f_thirdRead (cmpResult : slv(CMP_W_C-1 downto 0)) return slv is
      variable cmpParts             : slv(7 downto 0);
      variable dupLastPkt, origLast : slv(24 downto 0);
      variable orig                 : slv(ITEM_W_C-1 downto 0);
      variable addrLenMatch, psnMatch, matchAll : sl;
   begin
      cmpParts   := cmpResult(233 downto 226);
      dupLastPkt := cmpResult(225 downto 201);
      origLast   := cmpResult(200 downto 176);
      orig       := cmpResult(175 downto 0);
      addrLenMatch := cmpParts(7) and cmpParts(6) and cmpParts(0) and toSl(dupLastPkt = origLast);
      psnMatch     := (cmpParts(4) or cmpParts(3)) and (cmpParts(2) or cmpParts(1));
      matchAll     := addrLenMatch and cmpParts(5) and psnMatch;   -- cmpParts(5)=keyMatch
      -- Maybe(ReadCacheItem): valid tag = MSB
      return matchAll & orig;
   end function;

   type RegType is record
      dataVec   : ItemArray;
      tagVec    : SlVecType;
      enqPtrReg : slv(CNT_W_C-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      dataVec   => (others => (others => '0')),   -- mkRegU; init 0 (don't-care, gated by tagVec)
      tagVec    => (others => '0'),
      enqPtrReg => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal clearActive : sl;
   signal fifosRst    : sl;

   -- insertQ
   signal insertNotFull, insertValid, insertRdEn : sl;
   signal insertDout                             : slv(ITEM_W_C-1 downto 0);
   -- searchReqQ
   signal searchReqNotFull, searchReqValid, forkPipeInRdEn : sl;
   signal searchReqDout                                    : slv(ITEM_W_C-1 downto 0);
   -- BinaryTreeFork outputs (per lane)
   signal forkValid : SlVecType;
   signal forkDout  : ItemArray;
   signal forkRdEn  : SlVecType;
   -- searchDataVec FIFOs
   signal sdWrEn, sdNotFull, sdRdEn, sdValid : SlVecType;
   signal sdDin, sdDout                      : SdArray;
   -- cmpResultVec FIFOs
   signal crWrEn, crNotFull, crRdEn, crValid : SlVecType;
   signal crDin, crDout                      : CrArray;
   -- searchResultVec FIFOs
   signal srWrEn, srNotFull, srRdEn, srValid : SlVecType;
   signal srDin, srDout                      : SrArray;

begin

   clearActive    <= clearEn;                 -- CReg pulse reduces to combinational clear
   fifosRst       <= rst or clearActive;      -- BSV FIFOF.clear modelled as level rst
   pushReady      <= insertNotFull;
   searchReqReady <= searchReqNotFull;

   ----------------------------------------------------------------------------
   -- Source FIFOs
   ----------------------------------------------------------------------------
   U_InsertQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         DATA_WIDTH_G    => ITEM_W_C,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => fifosRst,
         wr_clk   => clk,
         wr_en    => pushEn,
         din      => pushData,
         not_full => insertNotFull,
         rd_clk   => clk,
         rd_en    => insertRdEn,
         dout     => insertDout,
         valid    => insertValid);

   U_SearchReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         DATA_WIDTH_G    => ITEM_W_C,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => fifosRst,
         wr_clk   => clk,
         wr_en    => searchReqEn,
         din      => searchReqData,
         not_full => searchReqNotFull,
         rd_clk   => clk,
         rd_en    => forkPipeInRdEn,
         dout     => searchReqDout,
         valid    => searchReqValid);

   ----------------------------------------------------------------------------
   -- BinaryTreeFork : broadcast searchReq stream to QSZ lanes
   ----------------------------------------------------------------------------
   U_SearchReqFork : entity surf.BinaryTreeFork
      generic map (
         TPD_G             => TPD_G,
         DATA_W_G          => ITEM_W_C,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEM_TYPE_G        => MEM_TYPE_G)
      port map (
         clk            => clk,
         rst            => rst,
         clearAll       => clearActive,
         pipeInValid    => searchReqValid,
         pipeInDout     => searchReqDout,
         pipeInRdEn     => forkPipeInRdEn,
         pipeOut0Valid  => forkValid(0),  pipeOut0Dout  => forkDout(0),  pipeOut0RdEn  => forkRdEn(0),
         pipeOut1Valid  => forkValid(1),  pipeOut1Dout  => forkDout(1),  pipeOut1RdEn  => forkRdEn(1),
         pipeOut2Valid  => forkValid(2),  pipeOut2Dout  => forkDout(2),  pipeOut2RdEn  => forkRdEn(2),
         pipeOut3Valid  => forkValid(3),  pipeOut3Dout  => forkDout(3),  pipeOut3RdEn  => forkRdEn(3),
         pipeOut4Valid  => forkValid(4),  pipeOut4Dout  => forkDout(4),  pipeOut4RdEn  => forkRdEn(4),
         pipeOut5Valid  => forkValid(5),  pipeOut5Dout  => forkDout(5),  pipeOut5RdEn  => forkRdEn(5),
         pipeOut6Valid  => forkValid(6),  pipeOut6Dout  => forkDout(6),  pipeOut6RdEn  => forkRdEn(6),
         pipeOut7Valid  => forkValid(7),  pipeOut7Dout  => forkDout(7),  pipeOut7RdEn  => forkRdEn(7),
         pipeOut8Valid  => forkValid(8),  pipeOut8Dout  => forkDout(8),  pipeOut8RdEn  => forkRdEn(8),
         pipeOut9Valid  => forkValid(9),  pipeOut9Dout  => forkDout(9),  pipeOut9RdEn  => forkRdEn(9),
         pipeOut10Valid => forkValid(10), pipeOut10Dout => forkDout(10), pipeOut10RdEn => forkRdEn(10),
         pipeOut11Valid => forkValid(11), pipeOut11Dout => forkDout(11), pipeOut11RdEn => forkRdEn(11),
         pipeOut12Valid => forkValid(12), pipeOut12Dout => forkDout(12), pipeOut12RdEn => forkRdEn(12),
         pipeOut13Valid => forkValid(13), pipeOut13Dout => forkDout(13), pipeOut13RdEn => forkRdEn(13),
         pipeOut14Valid => forkValid(14), pipeOut14Dout => forkDout(14), pipeOut14RdEn => forkRdEn(14),
         pipeOut15Valid => forkValid(15), pipeOut15Dout => forkDout(15), pipeOut15RdEn => forkRdEn(15));

   ----------------------------------------------------------------------------
   -- Per-lane pipeline FIFOs (searchData / cmpResult / searchResult)
   ----------------------------------------------------------------------------
   GEN_LANE : for i in 0 to QSZ_C-1 generate

      U_SearchDataQ : entity surf.Fifo
         generic map (
            TPD_G           => TPD_G,
            RST_POLARITY_G  => '1',
            RST_ASYNC_G     => false,
            GEN_SYNC_FIFO_G => true,
            FWFT_EN_G       => true,
            DATA_WIDTH_G    => SD_W_C,
            ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G,
            MEMORY_TYPE_G   => MEM_TYPE_G)
         port map (
            rst      => fifosRst,
            wr_clk   => clk,
            wr_en    => sdWrEn(i),
            din      => sdDin(i),
            not_full => sdNotFull(i),
            rd_clk   => clk,
            rd_en    => sdRdEn(i),
            dout     => sdDout(i),
            valid    => sdValid(i));

      U_CmpResultQ : entity surf.Fifo
         generic map (
            TPD_G           => TPD_G,
            RST_POLARITY_G  => '1',
            RST_ASYNC_G     => false,
            GEN_SYNC_FIFO_G => true,
            FWFT_EN_G       => true,
            DATA_WIDTH_G    => CR_W_C,
            ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G,
            MEMORY_TYPE_G   => MEM_TYPE_G)
         port map (
            rst      => fifosRst,
            wr_clk   => clk,
            wr_en    => crWrEn(i),
            din      => crDin(i),
            not_full => crNotFull(i),
            rd_clk   => clk,
            rd_en    => crRdEn(i),
            dout     => crDout(i),
            valid    => crValid(i));

      U_SearchResultQ : entity surf.Fifo
         generic map (
            TPD_G           => TPD_G,
            RST_POLARITY_G  => '1',
            RST_ASYNC_G     => false,
            GEN_SYNC_FIFO_G => true,
            FWFT_EN_G       => true,
            DATA_WIDTH_G    => SR_W_C,
            ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G,
            MEMORY_TYPE_G   => MEM_TYPE_G)
         port map (
            rst      => fifosRst,
            wr_clk   => clk,
            wr_en    => srWrEn(i),
            din      => srDin(i),
            not_full => srNotFull(i),
            rd_clk   => clk,
            rd_en    => srRdEn(i),
            dout     => srDout(i),
            valid    => srValid(i));

   end generate GEN_LANE;

   ----------------------------------------------------------------------------
   -- RecursiveSearch : reduce QSZ Maybe lanes to one left-priority winner
   ----------------------------------------------------------------------------
   U_SearchResult : entity surf.RecursiveSearch
      generic map (
         TPD_G             => TPD_G,
         ITEM_W_G          => ITEM_W_C,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEM_TYPE_G        => MEM_TYPE_G)
      port map (
         clk               => clk,
         rst               => rst,
         clearAll          => clearActive,
         inputVec_0_valid  => srValid(0),  inputVec_0_dout  => srDout(0),  inputVec_0_rdEn  => srRdEn(0),
         inputVec_1_valid  => srValid(1),  inputVec_1_dout  => srDout(1),  inputVec_1_rdEn  => srRdEn(1),
         inputVec_2_valid  => srValid(2),  inputVec_2_dout  => srDout(2),  inputVec_2_rdEn  => srRdEn(2),
         inputVec_3_valid  => srValid(3),  inputVec_3_dout  => srDout(3),  inputVec_3_rdEn  => srRdEn(3),
         inputVec_4_valid  => srValid(4),  inputVec_4_dout  => srDout(4),  inputVec_4_rdEn  => srRdEn(4),
         inputVec_5_valid  => srValid(5),  inputVec_5_dout  => srDout(5),  inputVec_5_rdEn  => srRdEn(5),
         inputVec_6_valid  => srValid(6),  inputVec_6_dout  => srDout(6),  inputVec_6_rdEn  => srRdEn(6),
         inputVec_7_valid  => srValid(7),  inputVec_7_dout  => srDout(7),  inputVec_7_rdEn  => srRdEn(7),
         inputVec_8_valid  => srValid(8),  inputVec_8_dout  => srDout(8),  inputVec_8_rdEn  => srRdEn(8),
         inputVec_9_valid  => srValid(9),  inputVec_9_dout  => srDout(9),  inputVec_9_rdEn  => srRdEn(9),
         inputVec_10_valid => srValid(10), inputVec_10_dout => srDout(10), inputVec_10_rdEn => srRdEn(10),
         inputVec_11_valid => srValid(11), inputVec_11_dout => srDout(11), inputVec_11_rdEn => srRdEn(11),
         inputVec_12_valid => srValid(12), inputVec_12_dout => srDout(12), inputVec_12_rdEn => srRdEn(12),
         inputVec_13_valid => srValid(13), inputVec_13_dout => srDout(13), inputVec_13_rdEn => srRdEn(13),
         inputVec_14_valid => srValid(14), inputVec_14_dout => srDout(14), inputVec_14_rdEn => srRdEn(14),
         inputVec_15_valid => srValid(15), inputVec_15_dout => srDout(15), inputVec_15_rdEn => srRdEn(15),
         resultValid       => searchRespValid,
         resultDout        => searchRespData,
         resultRdEn        => searchRespRdEn);

   ----------------------------------------------------------------------------
   -- Two-process FSM
   ----------------------------------------------------------------------------
   comb : process (r, rst, clearEn, pmtu, insertValid, insertDout,
                   forkValid, forkDout, sdValid, sdDout, sdNotFull,
                   crValid, crDout, crNotFull, srNotFull) is
      variable v        : RegType;
      variable enqIdx   : integer range 0 to QSZ_C-1;
      variable tagV     : sl;
      variable sDataV   : slv(SEARCH_W_C-1 downto 0);
      variable validBit : sl;
   begin
      v := r;

      -- default FIFO drives
      insertRdEn <= '0';
      forkRdEn   <= (others => '0');
      sdWrEn     <= (others => '0'); sdRdEn <= (others => '0');
      crWrEn     <= (others => '0'); crRdEn <= (others => '0');
      srWrEn     <= (others => '0');   -- srRdEn is driven by U_SearchResult (RecursiveSearch);
                                       -- the comb must NOT also drive it (would be a 2nd driver -> 'X').
      sdDin      <= (others => (others => '0'));
      crDin      <= (others => (others => '0'));
      srDin      <= (others => (others => '0'));

      if (clearEn = '0') then
         -- search pipeline : QSZ independent lanes (conflict-free)
         for i in 0 to QSZ_C-1 loop
            -- firstSearchStage[i]
            if (forkValid(i) = '1') and (sdNotFull(i) = '1') then
               sdDin(i)  <= r.tagVec(i) & f_firstRead(forkDout(i), r.dataVec(i), pmtu);
               sdWrEn(i) <= '1';
               forkRdEn(i) <= '1';
            end if;
            -- secondSearchStage[i]
            if (sdValid(i) = '1') and (crNotFull(i) = '1') then
               tagV   := sdDout(i)(SD_W_C-1);
               sDataV := sdDout(i)(SD_W_C-2 downto 0);
               crDin(i)  <= tagV & f_secondRead(sDataV);    -- Maybe: valid = tag
               crWrEn(i) <= '1';
               sdRdEn(i) <= '1';
            end if;
            -- thirdSearchStage[i]
            if (crValid(i) = '1') and (srNotFull(i) = '1') then
               validBit := crDout(i)(CR_W_C-1);
               if (validBit = '1') then
                  srDin(i) <= f_thirdRead(crDout(i)(CR_W_C-2 downto 0));
               else
                  srDin(i) <= (others => '0');             -- Invalid
               end if;
               srWrEn(i) <= '1';
               crRdEn(i) <= '1';
            end if;
         end loop;

         -- insert : circular overwrite ring (no full check)
         if (insertValid = '1') then
            enqIdx := to_integer(unsigned(r.enqPtrReg));
            v.dataVec(enqIdx) := insertDout;
            v.tagVec(enqIdx)  := '1';
            v.enqPtrReg       := slv(unsigned(r.enqPtrReg) + 1);
            insertRdEn        <= '1';
         end if;

      else
         -- clearAll : clear tags + ptr ; all FIFOs cleared via fifosRst (level)
         v.tagVec    := (others => '0');
         v.enqPtrReg := (others => '0');
         -- dataVec left unchanged (only tags cleared)
      end if;

      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin;
      end if;
   end process seq;

end architecture rtl;

-------------------------------------------------------------------------------
-- CacheFifoAtomic : atomicCacheQ specialisation (AtomicCacheItem, 317-bit items)
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;

entity CacheFifoAtomic is
   generic (
      TPD_G             : time                   := 1 ns;
      FIFO_ADDR_WIDTH_G : positive range 4 to 48 := 4;
      MEM_TYPE_G        : string                 := "distributed");
   port (
      clk             : in  sl;
      rst             : in  sl;                      -- active-high synchronous
      -- push (insert) method : enq AtomicCacheItem
      pushEn          : in  sl;
      pushData        : in  slv(316 downto 0);
      pushReady       : out sl;
      -- clear method
      clearEn         : in  sl;
      -- searchReq method
      searchReqEn     : in  sl;
      searchReqData   : in  slv(316 downto 0);
      searchReqReady  : out sl;
      -- searchResp method : Maybe#(AtomicCacheItem) (valid tag = MSB)
      searchRespValid : out sl;
      searchRespData  : out slv(317 downto 0);
      searchRespRdEn  : in  sl);
end entity CacheFifoAtomic;

architecture rtl of CacheFifoAtomic is

   constant QSZ_C      : positive := 16;
   constant CNT_W_C    : positive := 4;
   constant ITEM_W_C   : positive := 317;           -- AtomicCacheItem
   constant SEARCH_W_C : positive := 637;           -- Tuple5 searchType
   constant CMP_W_C    : positive := 324;           -- Tuple2 cmpResultType
   constant SD_W_C     : positive := 1 + SEARCH_W_C;  -- 638
   constant CR_W_C     : positive := 1 + CMP_W_C;     -- 325
   constant SR_W_C     : positive := 1 + ITEM_W_C;    -- 318

   constant COMPARE_SWAP_C : slv(4 downto 0) := "10011";  -- RdmaOpCode 5'h13

   type SlVecType is array (0 to QSZ_C-1) of sl;
   type ItemArray is array (0 to QSZ_C-1) of slv(ITEM_W_C-1 downto 0);
   type SdArray   is array (0 to QSZ_C-1) of slv(SD_W_C-1 downto 0);
   type CrArray   is array (0 to QSZ_C-1) of slv(CR_W_C-1 downto 0);
   type SrArray   is array (0 to QSZ_C-1) of slv(SR_W_C-1 downto 0);

   -- AtomicCacheItem layout: atomicPSN[316:293] atomicOpCode[292:288]
   --   atomicEth[287:64] (va[287:224] rkey[223:192] swap[191:128] comp[127:64])
   --   atomicAckEth[63:0]

   -- firstStageFunc = buildAtomicSearchData  (DupReadAtomicCache.bsv:646)
   function f_firstAtomic (item4Search, itemInQ : slv(ITEM_W_C-1 downto 0)) return slv is
      variable keyMatch, opCodeMatch, psnMatch : sl;
   begin
      keyMatch    := toSl(item4Search(223 downto 192) = itemInQ(223 downto 192));  -- atomicEth.rkey
      opCodeMatch := toSl(item4Search(292 downto 288) = itemInQ(292 downto 288));  -- atomicOpCode
      psnMatch    := toSl(item4Search(316 downto 293) = itemInQ(316 downto 293));  -- atomicPSN
      -- Tuple5(keyMatch, opCodeMatch, psnMatch, dup, orig)
      return keyMatch & opCodeMatch & psnMatch & item4Search & itemInQ;
   end function;

   -- secondStageFunc = compareAtomicCacheItem  (DupReadAtomicCache.bsv:662)
   function f_secondAtomic (searchData : slv(SEARCH_W_C-1 downto 0)) return slv is
      variable keyMatch, opCodeMatch, psnMatch         : sl;
      variable dup, orig                               : slv(ITEM_W_C-1 downto 0);
      variable dupVa, origVa                           : slv(63 downto 0);
      variable addrHighPartMatch, addrLowPartMatch     : sl;
      variable swapMatch, compMatch                    : sl;
      variable cmpParts                                : slv(6 downto 0);
   begin
      keyMatch    := searchData(636);
      opCodeMatch := searchData(635);
      psnMatch    := searchData(634);
      dup         := searchData(633 downto 317);
      orig        := searchData(316 downto 0);

      dupVa  := dup(287 downto 224);     -- atomicEth.va
      origVa := orig(287 downto 224);

      -- cmpHalfAddr(dupVa, origVa) : HALF_ADDR_WIDTH=32
      addrHighPartMatch := toSl(dupVa(63 downto 32) = origVa(63 downto 32));
      -- FIDELITY: BSV cmpHalfAddr reads addrB for both low halves -> always True
      addrLowPartMatch  := '1';

      swapMatch := toSl(dup(191 downto 128) = orig(191 downto 128));   -- atomicEth.swap
      compMatch := toSl(dup(127 downto 64)  = orig(127 downto 64));    -- atomicEth.comp

      -- DupAtomicCmpParts (7 Bools, first-field-at-MSB)
      cmpParts := addrHighPartMatch & addrLowPartMatch & compMatch &
                  keyMatch & opCodeMatch & psnMatch & swapMatch;
      -- Tuple2(DupAtomicCmpParts, origAtomicCacheItem)
      return cmpParts & orig;
   end function;

   -- thirdStageFunc = checkAtomicCacheItemCmpResult  (DupReadAtomicCache.bsv:697)
   function f_thirdAtomic (cmpResult : slv(CMP_W_C-1 downto 0)) return slv is
      variable cmpParts     : slv(6 downto 0);
      variable orig         : slv(ITEM_W_C-1 downto 0);
      variable origOpCode   : slv(4 downto 0);
      variable payloadMatch, allMatch : sl;
   begin
      cmpParts   := cmpResult(323 downto 317);
      orig       := cmpResult(316 downto 0);
      origOpCode := orig(292 downto 288);
      -- cmpParts: addrHighPartMatch(6) addrLowPartMatch(5) compMatch(4)
      --           keyMatch(3) opCodeMatch(2) psnMatch(1) swapMatch(0)
      payloadMatch := ite(origOpCode = COMPARE_SWAP_C,
                          cmpParts(0) and cmpParts(4),   -- swap && comp
                          cmpParts(0));                  -- swap
      allMatch := cmpParts(6) and cmpParts(5) and cmpParts(3) and
                  payloadMatch and cmpParts(2) and cmpParts(1);
      -- Maybe(AtomicCacheItem): valid tag = MSB
      return allMatch & orig;
   end function;

   type RegType is record
      dataVec   : ItemArray;
      tagVec    : SlVecType;
      enqPtrReg : slv(CNT_W_C-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      dataVec   => (others => (others => '0')),   -- mkRegU; init 0 (don't-care, gated by tagVec)
      tagVec    => (others => '0'),
      enqPtrReg => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal clearActive : sl;
   signal fifosRst    : sl;

   signal insertNotFull, insertValid, insertRdEn : sl;
   signal insertDout                             : slv(ITEM_W_C-1 downto 0);
   signal searchReqNotFull, searchReqValid, forkPipeInRdEn : sl;
   signal searchReqDout                                    : slv(ITEM_W_C-1 downto 0);
   signal forkValid : SlVecType;
   signal forkDout  : ItemArray;
   signal forkRdEn  : SlVecType;
   signal sdWrEn, sdNotFull, sdRdEn, sdValid : SlVecType;
   signal sdDin, sdDout                      : SdArray;
   signal crWrEn, crNotFull, crRdEn, crValid : SlVecType;
   signal crDin, crDout                      : CrArray;
   signal srWrEn, srNotFull, srRdEn, srValid : SlVecType;
   signal srDin, srDout                      : SrArray;

begin

   clearActive    <= clearEn;
   fifosRst       <= rst or clearActive;
   pushReady      <= insertNotFull;
   searchReqReady <= searchReqNotFull;

   U_InsertQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         DATA_WIDTH_G    => ITEM_W_C,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => fifosRst,
         wr_clk   => clk,
         wr_en    => pushEn,
         din      => pushData,
         not_full => insertNotFull,
         rd_clk   => clk,
         rd_en    => insertRdEn,
         dout     => insertDout,
         valid    => insertValid);

   U_SearchReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         DATA_WIDTH_G    => ITEM_W_C,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => fifosRst,
         wr_clk   => clk,
         wr_en    => searchReqEn,
         din      => searchReqData,
         not_full => searchReqNotFull,
         rd_clk   => clk,
         rd_en    => forkPipeInRdEn,
         dout     => searchReqDout,
         valid    => searchReqValid);

   U_SearchReqFork : entity surf.BinaryTreeFork
      generic map (
         TPD_G             => TPD_G,
         DATA_W_G          => ITEM_W_C,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEM_TYPE_G        => MEM_TYPE_G)
      port map (
         clk            => clk,
         rst            => rst,
         clearAll       => clearActive,
         pipeInValid    => searchReqValid,
         pipeInDout     => searchReqDout,
         pipeInRdEn     => forkPipeInRdEn,
         pipeOut0Valid  => forkValid(0),  pipeOut0Dout  => forkDout(0),  pipeOut0RdEn  => forkRdEn(0),
         pipeOut1Valid  => forkValid(1),  pipeOut1Dout  => forkDout(1),  pipeOut1RdEn  => forkRdEn(1),
         pipeOut2Valid  => forkValid(2),  pipeOut2Dout  => forkDout(2),  pipeOut2RdEn  => forkRdEn(2),
         pipeOut3Valid  => forkValid(3),  pipeOut3Dout  => forkDout(3),  pipeOut3RdEn  => forkRdEn(3),
         pipeOut4Valid  => forkValid(4),  pipeOut4Dout  => forkDout(4),  pipeOut4RdEn  => forkRdEn(4),
         pipeOut5Valid  => forkValid(5),  pipeOut5Dout  => forkDout(5),  pipeOut5RdEn  => forkRdEn(5),
         pipeOut6Valid  => forkValid(6),  pipeOut6Dout  => forkDout(6),  pipeOut6RdEn  => forkRdEn(6),
         pipeOut7Valid  => forkValid(7),  pipeOut7Dout  => forkDout(7),  pipeOut7RdEn  => forkRdEn(7),
         pipeOut8Valid  => forkValid(8),  pipeOut8Dout  => forkDout(8),  pipeOut8RdEn  => forkRdEn(8),
         pipeOut9Valid  => forkValid(9),  pipeOut9Dout  => forkDout(9),  pipeOut9RdEn  => forkRdEn(9),
         pipeOut10Valid => forkValid(10), pipeOut10Dout => forkDout(10), pipeOut10RdEn => forkRdEn(10),
         pipeOut11Valid => forkValid(11), pipeOut11Dout => forkDout(11), pipeOut11RdEn => forkRdEn(11),
         pipeOut12Valid => forkValid(12), pipeOut12Dout => forkDout(12), pipeOut12RdEn => forkRdEn(12),
         pipeOut13Valid => forkValid(13), pipeOut13Dout => forkDout(13), pipeOut13RdEn => forkRdEn(13),
         pipeOut14Valid => forkValid(14), pipeOut14Dout => forkDout(14), pipeOut14RdEn => forkRdEn(14),
         pipeOut15Valid => forkValid(15), pipeOut15Dout => forkDout(15), pipeOut15RdEn => forkRdEn(15));

   GEN_LANE : for i in 0 to QSZ_C-1 generate

      U_SearchDataQ : entity surf.Fifo
         generic map (
            TPD_G           => TPD_G,
            RST_POLARITY_G  => '1',
            RST_ASYNC_G     => false,
            GEN_SYNC_FIFO_G => true,
            FWFT_EN_G       => true,
            DATA_WIDTH_G    => SD_W_C,
            ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G,
            MEMORY_TYPE_G   => MEM_TYPE_G)
         port map (
            rst      => fifosRst,
            wr_clk   => clk,
            wr_en    => sdWrEn(i),
            din      => sdDin(i),
            not_full => sdNotFull(i),
            rd_clk   => clk,
            rd_en    => sdRdEn(i),
            dout     => sdDout(i),
            valid    => sdValid(i));

      U_CmpResultQ : entity surf.Fifo
         generic map (
            TPD_G           => TPD_G,
            RST_POLARITY_G  => '1',
            RST_ASYNC_G     => false,
            GEN_SYNC_FIFO_G => true,
            FWFT_EN_G       => true,
            DATA_WIDTH_G    => CR_W_C,
            ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G,
            MEMORY_TYPE_G   => MEM_TYPE_G)
         port map (
            rst      => fifosRst,
            wr_clk   => clk,
            wr_en    => crWrEn(i),
            din      => crDin(i),
            not_full => crNotFull(i),
            rd_clk   => clk,
            rd_en    => crRdEn(i),
            dout     => crDout(i),
            valid    => crValid(i));

      U_SearchResultQ : entity surf.Fifo
         generic map (
            TPD_G           => TPD_G,
            RST_POLARITY_G  => '1',
            RST_ASYNC_G     => false,
            GEN_SYNC_FIFO_G => true,
            FWFT_EN_G       => true,
            DATA_WIDTH_G    => SR_W_C,
            ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G,
            MEMORY_TYPE_G   => MEM_TYPE_G)
         port map (
            rst      => fifosRst,
            wr_clk   => clk,
            wr_en    => srWrEn(i),
            din      => srDin(i),
            not_full => srNotFull(i),
            rd_clk   => clk,
            rd_en    => srRdEn(i),
            dout     => srDout(i),
            valid    => srValid(i));

   end generate GEN_LANE;

   U_SearchResult : entity surf.RecursiveSearch
      generic map (
         TPD_G             => TPD_G,
         ITEM_W_G          => ITEM_W_C,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEM_TYPE_G        => MEM_TYPE_G)
      port map (
         clk               => clk,
         rst               => rst,
         clearAll          => clearActive,
         inputVec_0_valid  => srValid(0),  inputVec_0_dout  => srDout(0),  inputVec_0_rdEn  => srRdEn(0),
         inputVec_1_valid  => srValid(1),  inputVec_1_dout  => srDout(1),  inputVec_1_rdEn  => srRdEn(1),
         inputVec_2_valid  => srValid(2),  inputVec_2_dout  => srDout(2),  inputVec_2_rdEn  => srRdEn(2),
         inputVec_3_valid  => srValid(3),  inputVec_3_dout  => srDout(3),  inputVec_3_rdEn  => srRdEn(3),
         inputVec_4_valid  => srValid(4),  inputVec_4_dout  => srDout(4),  inputVec_4_rdEn  => srRdEn(4),
         inputVec_5_valid  => srValid(5),  inputVec_5_dout  => srDout(5),  inputVec_5_rdEn  => srRdEn(5),
         inputVec_6_valid  => srValid(6),  inputVec_6_dout  => srDout(6),  inputVec_6_rdEn  => srRdEn(6),
         inputVec_7_valid  => srValid(7),  inputVec_7_dout  => srDout(7),  inputVec_7_rdEn  => srRdEn(7),
         inputVec_8_valid  => srValid(8),  inputVec_8_dout  => srDout(8),  inputVec_8_rdEn  => srRdEn(8),
         inputVec_9_valid  => srValid(9),  inputVec_9_dout  => srDout(9),  inputVec_9_rdEn  => srRdEn(9),
         inputVec_10_valid => srValid(10), inputVec_10_dout => srDout(10), inputVec_10_rdEn => srRdEn(10),
         inputVec_11_valid => srValid(11), inputVec_11_dout => srDout(11), inputVec_11_rdEn => srRdEn(11),
         inputVec_12_valid => srValid(12), inputVec_12_dout => srDout(12), inputVec_12_rdEn => srRdEn(12),
         inputVec_13_valid => srValid(13), inputVec_13_dout => srDout(13), inputVec_13_rdEn => srRdEn(13),
         inputVec_14_valid => srValid(14), inputVec_14_dout => srDout(14), inputVec_14_rdEn => srRdEn(14),
         inputVec_15_valid => srValid(15), inputVec_15_dout => srDout(15), inputVec_15_rdEn => srRdEn(15),
         resultValid       => searchRespValid,
         resultDout        => searchRespData,
         resultRdEn        => searchRespRdEn);

   comb : process (r, rst, clearEn, insertValid, insertDout,
                   forkValid, forkDout, sdValid, sdDout, sdNotFull,
                   crValid, crDout, crNotFull, srNotFull) is
      variable v        : RegType;
      variable enqIdx   : integer range 0 to QSZ_C-1;
      variable tagV     : sl;
      variable sDataV   : slv(SEARCH_W_C-1 downto 0);
      variable validBit : sl;
   begin
      v := r;

      insertRdEn <= '0';
      forkRdEn   <= (others => '0');
      sdWrEn     <= (others => '0'); sdRdEn <= (others => '0');
      crWrEn     <= (others => '0'); crRdEn <= (others => '0');
      srWrEn     <= (others => '0');   -- srRdEn is driven by U_SearchResult (RecursiveSearch);
                                       -- the comb must NOT also drive it (would be a 2nd driver -> 'X').
      sdDin      <= (others => (others => '0'));
      crDin      <= (others => (others => '0'));
      srDin      <= (others => (others => '0'));

      if (clearEn = '0') then
         for i in 0 to QSZ_C-1 loop
            if (forkValid(i) = '1') and (sdNotFull(i) = '1') then
               sdDin(i)    <= r.tagVec(i) & f_firstAtomic(forkDout(i), r.dataVec(i));
               sdWrEn(i)   <= '1';
               forkRdEn(i) <= '1';
            end if;
            if (sdValid(i) = '1') and (crNotFull(i) = '1') then
               tagV      := sdDout(i)(SD_W_C-1);
               sDataV    := sdDout(i)(SD_W_C-2 downto 0);
               crDin(i)  <= tagV & f_secondAtomic(sDataV);
               crWrEn(i) <= '1';
               sdRdEn(i) <= '1';
            end if;
            if (crValid(i) = '1') and (srNotFull(i) = '1') then
               validBit := crDout(i)(CR_W_C-1);
               if (validBit = '1') then
                  srDin(i) <= f_thirdAtomic(crDout(i)(CR_W_C-2 downto 0));
               else
                  srDin(i) <= (others => '0');
               end if;
               srWrEn(i) <= '1';
               crRdEn(i) <= '1';
            end if;
         end loop;

         if (insertValid = '1') then
            enqIdx := to_integer(unsigned(r.enqPtrReg));
            v.dataVec(enqIdx) := insertDout;
            v.tagVec(enqIdx)  := '1';
            v.enqPtrReg       := slv(unsigned(r.enqPtrReg) + 1);
            insertRdEn        <= '1';
         end if;

      else
         v.tagVec    := (others => '0');
         v.enqPtrReg := (others => '0');
      end if;

      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin;
      end if;
   end process seq;

end architecture rtl;
