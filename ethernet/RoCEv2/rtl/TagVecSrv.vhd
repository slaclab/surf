-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Tag-vector allocation server.
--   Maintains a register array of V_SZ_G tagged data entries. Clients issue
--   insert (find a free slot, write data) or remove (look up by index, clear
--   tag) requests through the request FIFO and receive results through the
--   response FIFO. One request is in flight at a time; each insert/remove takes
--   exactly two clock cycles (RECV_REQ -> RESP_*). A clear() pulse flushes both
--   FIFOs and resets all tags.
--
--   Generated from:
--     BSV source : src-bsv/MetaData.bsv  (module mkTagVecSrv, lines 35-151)
--     FSM spec   : out/03-fsm/TagVecSrv.fsm.md
--     Mapping    : out/02-partition/mapping.json (entity TagVecSrv)
--
--   SURF components instantiated:
--     surf.Fifo  (base/fifo/rtl/Fifo.vhd)  x2  -> U_ReqQ, U_RespQ
--
--   BSV FIFOF.clear is modelled per OQ-FSM-01 (out/03-fsm/RESOLVED.md): the
--   surf.Fifo has no flush port, so clear is a one-cycle synchronous rst pulse
--   asserted on both FIFOs simultaneously (sync config, active-high rst).
--
--   mkRegU fields (no BSV reset value): dataVec, maybeInsertIdxReg,
--   respSuccessReg. Initialised to all-'0' in REG_INIT_C; each is always written
--   before it is read (see OQ-FSM-04). Don't-care at reset.
--
--   REVISION (RESOLVED OQ-FSM-MDSRV-01 sec.4.2): added `tagValid` output — the
--   full tag-valid vector (= registered tagVec), so a parent with several
--   concurrent isValid-style readers (MetaDataPDs: PermCheckSrv's mrLkup vs
--   MetaDataSrv's isValidPD/getMRs4PD-valid) reads validity without contending
--   for the single muxed getItem port. Purely additive; existing users map it
--   to `open`.
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

entity TagVecSrv is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';     -- '1' for active HIGH reset
      RST_ASYNC_G    : boolean  := false;
      MEMORY_TYPE_G  : string   := "distributed";  -- small FIFOs
      V_SZ_G         : positive := 4;        -- number of tag entries (power of 2, >= 1)
      T_SZ_G         : positive := 32);      -- data width per entry
   port (
      clk        : in  sl;
      rst        : in  sl := not RST_POLARITY_G;
      -- Request input (srvPort.request -> reqQ write side)
      reqValid   : in  sl;                   -- parent enqueues a request
      reqData    : in  slv(T_SZ_G + log2(V_SZ_G) downto 0);  -- {insOrRem,insVal,remIdx}
      reqReady   : out sl;                   -- reqQ not_full (backpressure)
      -- Response output (respQ read side -> srvPort.response)
      respValid  : out sl;                   -- respQ has a response
      respData   : out slv(T_SZ_G + log2(V_SZ_G) downto 0);  -- {success,idx,value}
      respReady  : in  sl;                   -- parent dequeues a response
      -- getItem() combinational lookup
      getItemIdx : in  slv(log2(V_SZ_G)-1 downto 0);
      getItemOut : out slv(T_SZ_G downto 0);  -- {valid, dataVec(idx)}
      -- Full tag-valid vector export (combinational = r.tagVec). Added per
      -- RESOLVED OQ-FSM-MDSRV-01 sec.4.2 so parents with multiple concurrent
      -- isValid-style readers need not arbitrate the single getItem port.
      -- Leave open where unused.
      tagValid   : out slv(V_SZ_G-1 downto 0);
      -- Status methods
      notEmpty   : out sl;
      notFull    : out sl;
      -- clear() method
      clearEn    : in  sl);
end TagVecSrv;

architecture rtl of TagVecSrv is

   -----------------------------------------------------------------------------
   -- Constants (widths traced from BSV provisos)
   --   vLogSz  = TLog(vSz)        ; cntSz = TAdd(1, vLogSz)
   --   reqQ/respQ width = 1 + tSz + vLogSz (Tuple3 packing)
   -----------------------------------------------------------------------------
   constant V_LOG_SZ_C  : integer := log2(V_SZ_G);          -- index bit width
   constant CNT_SZ_C    : integer := V_LOG_SZ_C + 1;        -- item-count width
   constant FIFO_WIDTH_C : integer := 1 + T_SZ_G + V_LOG_SZ_C;
   constant FIFO_ADDR_WIDTH_C : integer := 4;               -- surf.Fifo minimum


   -----------------------------------------------------------------------------
   -- Types
   -----------------------------------------------------------------------------
   type TagVecStateType is (
      RECV_REQ_S,                            -- TAG_VEC_RECV_REQ = 0
      RESP_INSERT_S,                         -- TAG_VEC_RESP_INSERT = 1
      RESP_REMOVE_S);                        -- TAG_VEC_RESP_REMOVE = 2

   type DataVecType is array (0 to V_SZ_G-1) of slv(T_SZ_G-1 downto 0);

   type RegType is record
      tagVecStateReg    : TagVecStateType;
      dataVec           : DataVecType;                   -- mkRegU (no reset)
      tagVec            : slv(V_SZ_G-1 downto 0);        -- mkReg(False)
      maybeInsertIdxReg : slv(V_LOG_SZ_C downto 0);      -- {valid, index}, mkRegU
      respSuccessReg    : sl;                            -- mkRegU
      emptyReg          : sl;                            -- mkReg(True)
      fullReg           : sl;                            -- mkReg(False)
      clearReg          : sl;                            -- mkCReg(2,False) collapsed
      itemCnt           : slv(CNT_SZ_C-1 downto 0);      -- mkCount(0)
   end record RegType;

   constant REG_INIT_C : RegType := (
      tagVecStateReg    => RECV_REQ_S,
      dataVec           => (others => (others => '0')),  -- mkRegU: don't-care
      tagVec            => (others => '0'),
      maybeInsertIdxReg => (others => '0'),              -- mkRegU: don't-care
      respSuccessReg    => '0',                          -- mkRegU: don't-care
      emptyReg          => '1',
      fullReg           => '0',
      clearReg          => '0',
      itemCnt           => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- SURF Fifo interface signals
   signal reqQValid    : sl;                              -- U_ReqQ.valid
   signal reqQDout     : slv(FIFO_WIDTH_C-1 downto 0);    -- U_ReqQ.dout
   signal reqQRdEn     : sl;                              -- U_ReqQ.rd_en (deq)
   signal respQNotFull : sl;                              -- U_RespQ.not_full
   signal respQWrEn    : sl;                              -- U_RespQ.wr_en (enq)
   signal respQDin     : slv(FIFO_WIDTH_C-1 downto 0);    -- U_RespQ.din

   -- Clear / reset plumbing
   signal clrFifos      : sl;                             -- clearAll flush strobe
   signal fifoRst       : sl;                             -- rst (active high) OR clrFifos
   signal rstActiveHigh : sl;

begin

   -----------------------------------------------------------------------------
   -- Request FIFO (BSV reqQ : FIFOF#(Tuple3#(Bool, a, UInt#(vLogSz))))
   --   wr side driven by parent; rd side (deq) driven by the FSM.
   -----------------------------------------------------------------------------
   U_ReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',             -- active-high (clear-via-rst, OQ-FSM-01)
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,            -- BSV first/deq peek semantics
         MEMORY_TYPE_G   => MEMORY_TYPE_G,
         DATA_WIDTH_G    => FIFO_WIDTH_C,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_C)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => reqValid,               -- parent enqueue
         din      => reqData,
         not_full => reqReady,               -- backpressure to parent
         rd_clk   => clk,
         rd_en    => reqQRdEn,               -- FSM dequeue
         dout     => reqQDout,
         valid    => reqQValid);

   -----------------------------------------------------------------------------
   -- Response FIFO (BSV respQ : FIFOF#(Tuple3#(Bool, UInt#(vLogSz), a)))
   --   wr side (enq) driven by the FSM; rd side driven by parent.
   -----------------------------------------------------------------------------
   U_RespQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => MEMORY_TYPE_G,
         DATA_WIDTH_G    => FIFO_WIDTH_C,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_C)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => respQWrEn,              -- FSM enqueue
         din      => respQDin,
         not_full => respQNotFull,           -- FSM reads (enqueue guard)
         rd_clk   => clk,
         rd_en    => respReady,              -- parent dequeue
         dout     => respData,
         valid    => respValid);

   -- Active-high reset for the FIFO clear mechanism (OQ-FSM-01 RESOLVED):
   -- a one-cycle clrFifos pulse is OR-ed with the global reset into both FIFOs.
   rstActiveHigh <= rst when RST_POLARITY_G = '1' else not rst;
   fifoRst       <= rstActiveHigh or clrFifos;

   -----------------------------------------------------------------------------
   -- Combinatorial process (two-process FSM): next state + outputs into v.
   -----------------------------------------------------------------------------
   comb : process (r, rst, clearEn, reqQValid, reqQDout, respQNotFull) is
      variable v          : RegType;
      -- Request tuple fields (peeked from reqQ head)
      variable insertOrRemove : sl;
      variable insertVal      : slv(T_SZ_G-1 downto 0);
      variable removeIdx      : slv(V_LOG_SZ_C-1 downto 0);
      variable removeIdxInt   : natural;
      -- Combinational helpers
      variable almostFull     : sl;
      variable almostEmpty     : sl;
      variable freeIdx        : slv(V_LOG_SZ_C-1 downto 0);
      variable freeValid      : sl;
      variable removeTag      : sl;
      variable insertIdx      : slv(V_LOG_SZ_C-1 downto 0);
      variable removeVal      : slv(T_SZ_G-1 downto 0);
      -- Mealy strobes / datapath to the FIFOs
      variable vReqDeq        : sl;
      variable vRespEnq       : sl;
      variable vClrFifos      : sl;
      variable vRespDin       : slv(FIFO_WIDTH_C-1 downto 0);
   begin
      v := r;

      -- Defaults for Mealy outputs (deasserted unless a branch fires)
      vReqDeq   := '0';
      vRespEnq  := '0';
      vClrFifos := '0';
      vRespDin  := (others => '0');

      -- Decode the peeked request tuple (Tuple3 packs first element in the MSBs)
      insertOrRemove := reqQDout(FIFO_WIDTH_C-1);
      insertVal      := reqQDout(FIFO_WIDTH_C-2 downto V_LOG_SZ_C);
      removeIdx      := reqQDout(V_LOG_SZ_C-1 downto 0);
      removeIdxInt   := to_integer(unsigned(removeIdx));

      -- Status helpers over the current item count.
      -- Explicit integer compare (itemCnt = V_SZ_G-1): equivalent to the BSV
      -- all-low-bits-set trick for V_SZ_G >= 2 (itemCnt <= V_SZ_G), and still
      -- correct at V_SZ_G=1 where SURF log2(1)=1 pads itemCnt to 2 bits and
      -- desynchronizes the bit trick (it would detect 1 instead of 0).
      almostFull := toSl(to_integer(unsigned(r.itemCnt)) = V_SZ_G-1);
      if (unsigned(r.itemCnt) = 1) then
         almostEmpty := '1';
      else
         almostEmpty := '0';
      end if;

      -- Priority encoder: lowest-index free slot (tagVec(i) = '0'), LSB priority
      freeIdx   := (others => '0');
      freeValid := '0';
      for i in V_SZ_G-1 downto 0 loop
         if (r.tagVec(i) = '0') then
            freeIdx   := toSlv(i, V_LOG_SZ_C);
            freeValid := '1';
         end if;
      end loop;

      -- clear() method: set the clear pulse (may be overridden by clearAll below,
      -- matching the CReg port-ordering where the rule's deassert wins, OQ-FSM-03)
      if (clearEn = '1') then
         v.clearReg := '1';
      end if;

      -----------------------------------------------------------------------
      -- Rule priority (clearAll wins; the three normal rules are mutually
      -- exclusive by tagVecStateReg). clearAll reads the registered clearReg
      -- (previous-cycle pulse, OQ-FSM-03).
      -----------------------------------------------------------------------
      if (r.clearReg = '1') then
         -- rule clearAll
         v.tagVec         := (others => '0');
         vClrFifos        := '1';
         v.tagVecStateReg := RECV_REQ_S;
         v.emptyReg       := '1';
         v.fullReg        := '0';
         v.clearReg       := '0';
         v.itemCnt        := (others => '0');

      elsif (r.tagVecStateReg = RECV_REQ_S) then
         -- rule recvReq (peek only; reqQ is dequeued in the response state)
         if (reqQValid = '1') then
            if (insertOrRemove = '1') then
               -- Insert: record the free slot found this cycle
               v.maybeInsertIdxReg := freeValid & freeIdx;
               if (r.fullReg = '0') then
                  v.itemCnt  := slv(unsigned(r.itemCnt) + 1);
                  v.emptyReg := '0';
                  v.fullReg  := almostFull;
               end if;
               v.respSuccessReg := not r.fullReg;
               v.tagVecStateReg := RESP_INSERT_S;
            else
               -- Remove: success iff the addressed slot is currently tagged
               removeTag := r.tagVec(removeIdxInt);
               if (removeTag = '1') then
                  v.itemCnt  := slv(unsigned(r.itemCnt) - 1);
                  v.emptyReg := almostEmpty;
                  v.fullReg  := '0';
               end if;
               v.respSuccessReg := removeTag;
               v.tagVecStateReg := RESP_REMOVE_S;
            end if;
         end if;

      elsif (r.tagVecStateReg = RESP_INSERT_S) then
         -- rule genInsertResp
         if (reqQValid = '1') and (respQNotFull = '1') then
            vReqDeq    := '1';
            insertIdx  := r.maybeInsertIdxReg(V_LOG_SZ_C-1 downto 0);
            if (r.respSuccessReg = '1') then
               -- pragma translate_off
               assert (r.maybeInsertIdxReg(V_LOG_SZ_C) = '1')
                  report "maybeInsertIdxReg should be valid @ TagVecSrv"
                  severity error;
               -- pragma translate_on
               v.tagVec(to_integer(unsigned(insertIdx)))  := '1';
               v.dataVec(to_integer(unsigned(insertIdx))) := insertVal;
            end if;
            vRespEnq         := '1';
            vRespDin         := r.respSuccessReg & insertIdx & insertVal;
            v.tagVecStateReg := RECV_REQ_S;
         end if;

      else
         -- rule genRemoveResp (RESP_REMOVE_S)
         if (reqQValid = '1') and (respQNotFull = '1') then
            vReqDeq                  := '1';
            removeVal                := r.dataVec(removeIdxInt);
            v.tagVec(removeIdxInt)   := '0';
            vRespEnq                 := '1';
            vRespDin                 := r.respSuccessReg & removeIdx & removeVal;
            v.tagVecStateReg         := RECV_REQ_S;
         end if;
      end if;

      -- Synchronous reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin <= v;

      -- Mealy outputs to the FIFOs (combinational from this cycle's firing).
      -- Left ungated under reset: fifoRst forces both FIFOs' synchronous reset,
      -- which dominates any concurrent wr_en/rd_en (OQ-FSM-01 RESOLVED).
      reqQRdEn  <= vReqDeq;
      respQWrEn <= vRespEnq;
      respQDin  <= vRespDin;
      clrFifos  <= vClrFifos;

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
   -- Moore outputs (combinational reads of the registered state).
   -----------------------------------------------------------------------------
   notEmpty   <= not r.emptyReg;
   notFull    <= not r.fullReg;
   getItemOut <= r.tagVec(to_integer(unsigned(getItemIdx))) &
                 r.dataVec(to_integer(unsigned(getItemIdx)));
   tagValid   <= r.tagVec;

end architecture rtl;
