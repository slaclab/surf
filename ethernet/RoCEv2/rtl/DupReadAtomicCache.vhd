-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- DESIGN NOTE - STATELESS WRAPPER (OQ-FSM-DRAC-02)
--   mkDupReadAtomicCache owns NO mkReg/mkRegU/mkCReg and no counter; its only
--   sequential control is the single rule postProcessDupReadResp, which is a
--   one-stage combinational stream-join registered only through the dupReadRespQ
--   FIFO. There is therefore no RegType / REG_INIT_C / r-rin pair and no seq
--   process for this entity: all state lives inside the two surf.Fifo instances
--   and the two CacheFifo children. The two-process FSM template does not apply
--   to a stateless join. (mapping.json wrongly records rules=[], surf_instances=[];
--   the .fsm.md is authoritative - OQ-FSM-DRAC-02.)
--
-- STRUCTURE
--   * U_ReadCacheQ   : CacheFifoRead   (readCacheQ,   ReadCacheItem   176 b) - takes pmtu
--   * U_AtomicCacheQ : CacheFifoAtomic (atomicCacheQ, AtomicCacheItem 317 b)
--   * U_DupReadReqQ  : surf.Fifo       (dupReadReqQ,  ReadCacheItem   176 b, FWFT)
--   * U_DupReadRespQ : surf.Fifo       (dupReadRespQ, Maybe#(Tuple3)  242 b, FWFT)
--
-- WIDTHS (traced; see CacheFifo.vhd header / RESOLVED.md OQ-FSM-CF-02/03)
--   ReadCacheItem   = startPSN(24)+endPSN(24)+RETH(128)                 = 176
--     RETH          = va(64)+rkey(32)+dlen(32) ; va = reth[127:64]
--   AtomicCacheItem                                                     = 317
--   readCacheQ searchResp = Maybe#(ReadCacheItem)   = 1+176            = 177 (tag = bit 176)
--   atomicCacheQ searchResp = Maybe#(AtomicCacheItem) = 1+317          = 318 (tag = bit 317)
--   Tuple3(ReadCacheItem, ADDR, DupReadReqStartState) = 176+64+1       = 241
--   dupReadRespQ word = Maybe#(Tuple3) = 1+241                          = 242 (tag = bit 241)
--   DupReadReqStartState : FROM_FIRST=0, FROM_MIDDLE=1 (1 bit)
--   PMTU enum (3 b) encoding: 256="001" 512="010" 1024="011" 2048="100" 4096="101"
--   (matches CacheFifoRead.f_secondRead / DataTypes.bsv:407-413)
--
-- ATOMICITY (OQ-FSM-DRAC-04)
--   searchReadReq fires TWO enqueues atomically: U_ReadCacheQ.searchReq AND
--   U_DupReadReqQ.enq. Both are gated on the AND of (searchReq-ready AND
--   dupReadReqQ.not_full) so neither commits without the other; otherwise the
--   rule's 1:1 join (child searchResp <-> dupReadReqQ.first) would desync.
--
-- CLEAR (OQ-FSM-DRAC-03)
--   clear() asserts cacheIfc.clear on BOTH children only; it does NOT flush
--   dupReadReqQ / dupReadRespQ. Faithfully reproduced: clearEn is wired ONLY to
--   the children's clearEn; the two own FIFOs see the global rst alone.
--
-- MEALY NOTE
--   readResp is computed combinationally (compareDupReadAddr / getVerifiedDupReadAddr
--   are pure) and registered only by the U_DupReadRespQ enqueue. searchAtomicResp
--   is a pure combinational passthrough of U_AtomicCacheQ's search response.
--
-- VERIFY: this entity has not been simulated. Run Stage 5 (cocotb/VHDL TB) before
--   trusting it.
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

entity DupReadAtomicCache is
   generic (
      TPD_G             : time                   := 1 ns;
      FIFO_ADDR_WIDTH_G : positive range 4 to 48 := 4;  -- children + own FIFO depth = 2**N
      MEM_TYPE_G        : string                 := "distributed");
   port (
      clk                   : in  sl;
      rst                   : in  sl;   -- active-high synchronous
      pmtu                  : in  slv(2 downto 0);  -- PMTU enum (feeds read-cache compare)
      -- insertRead method : push ReadCacheItem into readCacheQ
      insertReadEn          : in  sl;
      insertReadData        : in  slv(175 downto 0);
      insertReadReady       : out sl;   -- = U_ReadCacheQ.pushReady
      -- searchReadReq method : enq into readCacheQ.searchReq AND dupReadReqQ (atomic)
      searchReadReqEn       : in  sl;
      searchReadReqData     : in  slv(175 downto 0);
      searchReadReqReady    : out sl;  -- = readCacheQ.searchReqReady AND dupReadReqQ.not_full
      -- searchReadResp method : Maybe#(Tuple3(ReadCacheItem, ADDR, StartState))
      searchReadRespValid   : out sl;
      searchReadRespData    : out slv(241 downto 0);
      searchReadRespRdEn    : in  sl;
      -- insertAtomic method : push AtomicCacheItem into atomicCacheQ
      insertAtomicEn        : in  sl;
      insertAtomicData      : in  slv(316 downto 0);
      insertAtomicReady     : out sl;   -- = U_AtomicCacheQ.pushReady
      -- searchAtomicReq method : enq into atomicCacheQ.searchReq
      searchAtomicReqEn     : in  sl;
      searchAtomicReqData   : in  slv(316 downto 0);
      searchAtomicReqReady  : out sl;   -- = U_AtomicCacheQ.searchReqReady
      -- searchAtomicResp method : Maybe#(AtomicCacheItem) (direct passthrough)
      searchAtomicRespValid : out sl;
      searchAtomicRespData  : out slv(317 downto 0);
      searchAtomicRespRdEn  : in  sl;
      -- clear method : clears the two children's caches only (NOT dup*Q)
      clearEn               : in  sl);
end entity DupReadAtomicCache;

architecture rtl of DupReadAtomicCache is

   constant READ_ITEM_W_C        : positive := 176;  -- ReadCacheItem
   constant ATOMIC_ITEM_W_C      : positive := 317;  -- AtomicCacheItem
   constant READ_SEARCH_RESP_W_C : positive := 177;  -- Maybe#(ReadCacheItem)   (tag = bit 176)
   constant READ_RESP_W_C        : positive := 242;  -- Maybe#(Tuple3)          (tag = bit 241)
   constant SR_TAG_C             : natural  := 176;  -- Maybe-valid tag index in readCacheQ searchResp

   -- compareDupReadAddr (DupReadAtomicCache.bsv:134-188) : compares the upper bits
   -- (above the PMTU shift) of the LOW 32-bit half of va. dupVaLow/origVaLow are
   -- reth.va[31:0]. Returns True when dAddrLowHalf[31:s] = oAddrLowHalf[31:s].
   function f_cmpDupReadAddr (dupVaLow, origVaLow : slv(31 downto 0);
                              pmtuI               : slv(2 downto 0)) return sl is
      variable s : integer range 8 to 12;
   begin
      case pmtuI is
         when "001"  => s := 8;         -- IBV_MTU_256  : 8  = log2(256)
         when "010"  => s := 9;         -- IBV_MTU_512  : 9  = log2(512)
         when "011"  => s := 10;        -- IBV_MTU_1024 : 10 = log2(1024)
         when "100"  => s := 11;        -- IBV_MTU_2048 : 11 = log2(2048)
         when "101"  => s := 12;        -- IBV_MTU_4096 : 12 = log2(4096)
         when others => s := 8;
      end case;
      return toSl(dupVaLow(31 downto s) = origVaLow(31 downto s));
   end function;

   -- read-cache child (readCacheQ)
   signal readPushReady       : sl;
   signal readSearchReqEn     : sl;
   signal readSearchReqReady  : sl;
   signal readSearchRespValid : sl;
   signal readSearchRespData  : slv(READ_SEARCH_RESP_W_C-1 downto 0);
   signal readSearchRespRdEn  : sl;

   -- atomic-cache child (atomicCacheQ)
   signal atomicPushReady       : sl;
   signal atomicSearchReqReady  : sl;
   signal atomicSearchRespValid : sl;
   signal atomicSearchRespData  : slv(ATOMIC_ITEM_W_C downto 0);  -- 318 b Maybe

   -- dupReadReqQ (own FIFO)
   signal dupReqWrEn    : sl;
   signal dupReqNotFull : sl;
   signal dupReqRdEn    : sl;
   signal dupReqDout    : slv(READ_ITEM_W_C-1 downto 0);
   signal dupReqValid   : sl;

   -- dupReadRespQ (own FIFO)
   signal dupRespWrEn    : sl;
   signal dupRespDin     : slv(READ_RESP_W_C-1 downto 0);
   signal dupRespNotFull : sl;
   signal dupRespDout    : slv(READ_RESP_W_C-1 downto 0);
   signal dupRespValid   : sl;

   -- atomic dual-enqueue gate for searchReadReq
   signal searchReqCombReady : sl;
   signal searchReqDoEnq     : sl;

begin

   ----------------------------------------------------------------------------
   -- Method-level wiring (combinational handshakes, no state)
   ----------------------------------------------------------------------------
   -- insertRead : straight push (readiness exposed; wr_en ungated like CacheFifo)
   insertReadReady <= readPushReady;

   -- searchReadReq : TWO atomic enqueues, gated on the AND of both readinesses
   searchReqCombReady <= readSearchReqReady and dupReqNotFull;
   searchReqDoEnq     <= searchReadReqEn and searchReqCombReady;
   searchReadReqReady <= searchReqCombReady;
   readSearchReqEn    <= searchReqDoEnq;  -- to U_ReadCacheQ.searchReq
   dupReqWrEn         <= searchReqDoEnq;  -- to U_DupReadReqQ.enq

   -- searchReadResp : FWFT output of dupReadRespQ
   searchReadRespValid <= dupRespValid;
   searchReadRespData  <= dupRespDout;
   -- (dupReadRespQ rd_en driven directly from searchReadRespRdEn in the port map)

   -- insertAtomic : straight push
   insertAtomicReady <= atomicPushReady;

   -- searchAtomicReq : single enqueue
   searchAtomicReqReady <= atomicSearchReqReady;

   -- searchAtomicResp : pure passthrough of atomicCacheQ search response
   searchAtomicRespValid <= atomicSearchRespValid;
   searchAtomicRespData  <= atomicSearchRespData;
   -- (U_AtomicCacheQ.searchRespRdEn driven directly from searchAtomicRespRdEn)

   ----------------------------------------------------------------------------
   -- Child entities (CacheFifo specialisations, NOT SURF, NOT state)
   ----------------------------------------------------------------------------
   U_ReadCacheQ : entity surf.CacheFifoRead
      generic map (
         TPD_G             => TPD_G,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEM_TYPE_G        => MEM_TYPE_G)
      port map (
         clk             => clk,
         rst             => rst,
         pmtu            => pmtu,
         pushEn          => insertReadEn,
         pushData        => insertReadData,
         pushReady       => readPushReady,
         clearEn         => clearEn,    -- DRAC-03: only children are cleared
         searchReqEn     => readSearchReqEn,
         searchReqData   => searchReadReqData,
         searchReqReady  => readSearchReqReady,
         searchRespValid => readSearchRespValid,
         searchRespData  => readSearchRespData,
         searchRespRdEn  => readSearchRespRdEn);

   U_AtomicCacheQ : entity surf.CacheFifoAtomic
      generic map (
         TPD_G             => TPD_G,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEM_TYPE_G        => MEM_TYPE_G)
      port map (
         clk             => clk,
         rst             => rst,
         pushEn          => insertAtomicEn,
         pushData        => insertAtomicData,
         pushReady       => atomicPushReady,
         clearEn         => clearEn,    -- DRAC-03: only children are cleared
         searchReqEn     => searchAtomicReqEn,
         searchReqData   => searchAtomicReqData,
         searchReqReady  => atomicSearchReqReady,
         searchRespValid => atomicSearchRespValid,
         searchRespData  => atomicSearchRespData,
         searchRespRdEn  => searchAtomicRespRdEn);  -- passthrough get

   ----------------------------------------------------------------------------
   -- Own FIFOs  (surf.Fifo ; FWFT sync ; NOT flushed by clear() - DRAC-03)
   ----------------------------------------------------------------------------
   U_DupReadReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         DATA_WIDTH_G    => READ_ITEM_W_C,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => rst,               -- global rst only (not clearEn)
         wr_clk   => clk,
         wr_en    => dupReqWrEn,
         din      => searchReadReqData,  -- same item enqueued to readCacheQ.searchReq
         not_full => dupReqNotFull,
         rd_clk   => clk,
         rd_en    => dupReqRdEn,
         dout     => dupReqDout,
         valid    => dupReqValid);

   U_DupReadRespQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         DATA_WIDTH_G    => READ_RESP_W_C,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => rst,                 -- global rst only (not clearEn)
         wr_clk   => clk,
         wr_en    => dupRespWrEn,
         din      => dupRespDin,
         not_full => dupRespNotFull,
         rd_clk   => clk,
         rd_en    => searchReadRespRdEn,  -- searchReadResp deq
         dout     => dupRespDout,
         valid    => dupRespValid);

   ----------------------------------------------------------------------------
   -- rule postProcessDupReadResp : combinational 1:1 stream-join
   --   guard : dupReadReqQ.notEmpty AND readCacheQ.searchResp valid AND
   --           dupReadRespQ.not_full
   --   on fire (atomic) : deq dupReadReqQ ; get readCacheQ.searchResp ;
   --                       enq readResp into dupReadRespQ
   ----------------------------------------------------------------------------
   join_comb : process (dupReqValid, dupReqDout, readSearchRespValid,
                        readSearchRespData, dupRespNotFull, pmtu) is
      variable fire        : sl;
      variable searchValid : sl;
      variable orig        : slv(READ_ITEM_W_C-1 downto 0);
      variable matchV      : sl;
      variable vaddr       : slv(63 downto 0);
      variable startState  : sl;
      variable readResp    : slv(READ_RESP_W_C-1 downto 0);
   begin
      -- defaults : no enqueue / dequeue
      dupReqRdEn         <= '0';
      readSearchRespRdEn <= '0';
      dupRespWrEn        <= '0';
      dupRespDin         <= (others => '0');

      fire := dupReqValid and readSearchRespValid and dupRespNotFull;

      -- compute readResp (Mealy combinational; registered only by the enq below)
      searchValid := readSearchRespData(SR_TAG_C);  -- Maybe tag (MSB)
      orig        := readSearchRespData(READ_ITEM_W_C-1 downto 0);

      -- compareDupReadAddr(pmtu, dupReth, origReth) : low-half va, bits [95:64]
      matchV := f_cmpDupReadAddr(dupReqDout(95 downto 64), orig(95 downto 64), pmtu);

      -- getVerifiedDupReadAddr = { origReth.va[63:32] , dupReth.va[31:0] }
      --   origReth.va[63:32] = orig[127:96] ; dupReth.va[31:0] = dupReqDout[95:64]
      vaddr := orig(127 downto 96) & dupReqDout(95 downto 64);

      -- match -> FROM_FIRST(0) ; mismatch -> FROM_MIDDLE(1)
      startState := not matchV;

      if (searchValid = '1') then
         -- Maybe Valid : tag=1, Tuple3(origReadCacheItem, vaddr, startState)
         readResp := '1' & orig & vaddr & startState;
      else
         readResp := (others => '0');   -- tagged Invalid
      end if;

      if (fire = '1') then
         dupReqRdEn         <= '1';     -- deq dupReadReqQ
         readSearchRespRdEn <= '1';     -- get readCacheQ.searchResp
         dupRespWrEn        <= '1';     -- enq dupReadRespQ
         dupRespDin         <= readResp;
      end if;
   end process join_comb;

end architecture rtl;
