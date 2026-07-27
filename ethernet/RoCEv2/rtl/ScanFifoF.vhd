-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Register-array FIFO with non-destructive sequential scan.
--   A bespoke FIFO (NOT a surf.Fifo instance: OQ-PART-05/OQ-02) built on a
--   register array dataVec[Q_SZ_G] indexed by three independent pointers
--   (enqPtr, deqPtr, scanPtr). Three top-level modes encoded in scanStateReg:
--     FIFO_S      - normal enqueue/dequeue FIFO operation
--     PRE_SCAN_S  - snapshot deqPtr->scanPtr and itemCnt->scanCnt; getHead /
--                   modifyHead available; array is write-frozen (enq blocked)
--     SCAN_S      - one entry per cycle is read from the array and pushed into
--                   U_ScanOutQ; external consumer drains it via a PipeOut
--                   handshake (scanOut{Valid,Data,Ready}).
--
--   All control requests (enq/deq/clear/preScanStart/scanStart/scanStop/
--   preScanRestart) are BSV CReg(2) pulse registers used as INTRA-CYCLE
--   forwarding: the method writes port-0 and the consuming rule reads port-1
--   IN THE SAME CYCLE (BSV CReg ordering: write[0] SB read[1]), then writes
--   port-1 False. The registered value is therefore always False across clock
--   edges, and the pulses collapse to pure combinational strobes here — the
--   same conclusion OQ-FSM-02 reached for CountCF's writeReg/incrReg/decrReg.
--
--   BUGFIX 2026-07-08 (SQ pendingCnt underflow under RoCE retry): a previous
--   revision registered these pulses and consumed them one cycle later, which
--   delayed every method effect (pop/push/clear/scan transitions) by one cycle
--   relative to BSV. fifoNotEmpty/fifoFirst then lagged a deq by one extra
--   cycle, letting RespHandleSq classify a back-to-back (duplicate) response
--   against an already-dequeued WorkReq and issue a second deq — an extra
--   deqPulse/decrement that underflowed NewPendingWorkReqPipeOut's pendingCnt.
--   With same-cycle semantics, deqPulse == deqEn (BSV: deqPulse() = popReg[1],
--   which sees the same-cycle deq() port-0 write) and all status outputs
--   update on the cycle AFTER the method strobe, exactly as in BSV.
--
--   DELIBERATE DEVIATION (same bugfix, OQ-FSM-03 class): BSV exits scan mode
--   on the same cycle scanNext emits the last snapshot entry (scanDoneReg CReg
--   forwarding), relying on mkFIFOF's 1-cycle enq->deq latency for the
--   consumer to grab the tail element before fifoMode's every-cycle
--   scanOutQ.clear destroys it. surf.Fifo (FWFT) has ~2-cycle enq->valid
--   latency, so a cycle-exact exit would ALWAYS lose the last scanned entry
--   (a lost retransmit WR). Instead the FSM holds SCAN_S until the scan
--   output queue has fully drained (tracked by the outQOcc occupancy counter,
--   since the Fifo's own empty/valid flags lag writes). isScanDone therefore
--   asserts only after every scanned element has been delivered — a strictly
--   stronger contract than BSV that the retry protocol relies on anyway.
--   scanStop/preScanRestart still abort immediately and flush the queue.
--
--   Generated from:
--     BSV source : src-bsv/SpecialFIFOF.bsv  (module mkScanFIFOF, lines 43-330)
--     FSM spec   : out/03-fsm/ScanFifoF.fsm.md
--     Mapping    : out/02-partition/mapping.json (entity ScanFifoF)
--
--   SURF components instantiated:
--     surf.Fifo  (base/fifo/rtl/Fifo.vhd)  x1  -> U_ScanOutQ (scan output queue)
--
--   BSV FIFOF.clear on the scan output queue is modelled per OQ-FSM-01 /
--   OQ-FSM-06 (out/03-fsm/RESOLVED.md): surf.Fifo has no flush port, so clear
--   is a synchronous rst assertion (sync config, active-high rst). OQ-FSM-06
--   confirms a HELD (level) assertion over FIFO_S is safe with the sync wrapper
--   (FifoSync wires rst straight through; release is next-cycle).
--
--   OQ-FSM-05 applied: scanNext is suppressed when scanCnt = 0, so the single-
--   entry-scan underflow (reading dataVec beyond the snapshot) cannot occur.
--
--   mkRegU fields (no BSV reset value): dataVec, scanPtrReg, headReg.
--   Initialised to all-'0' in REG_INIT_C; each is always written before it is
--   read. Don't-care at reset (mirrors OQ-FSM-04). BSV's scanAlmostDoneReg /
--   scanDoneReg pair is superseded by the drain-gated scanDone above.
--
--   DEVIATION-SQQP-01 (2026-07-08, SQ retry partial-replay fix; see
--   SqQueuePair.vhd header): enqueue is additionally legal during PRE_SCAN_S.
--   BSV forbids it (enq guard = inFifoMode) and instead relies on the NAK
--   round-trip being long enough that no sent WR is still in flight toward
--   this buffer when a retry snapshot is taken — a latent upstream hole (a
--   sent-but-not-yet-enqueued WR misses the scanCnt snapshot and is silently
--   excluded from the go-back-N replay). Here the parent holds the buffer in
--   PRE_SCAN until all in-flight new WRs have landed, so:
--     * the PRE_SCAN snapshot takes the POST-enq item count (v.itemCnt), so
--       an enqueue landing on any pre-scan cycle (including the scanStart
--       release cycle) is inside the replay window;
--     * the enq-mode simulation assert flags SCAN_S only;
--     * a new inPreScan status output lets the parent implement the enq gate
--       (FIFO_S or PRE_SCAN_S) and the deq gate (BSV deq guard forbids
--       PRE_SCAN) without duplicating this FSM's state.
--   deq during PRE_SCAN_S remains illegal (BSV guard: inFifoMode||inScanMode);
--   the parent now enforces it via RespHandleSq.pendingWrDeqAllowed.
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

entity ScanFifoF is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';            -- '1' for active HIGH reset
      RST_ASYNC_G    : boolean  := false;
      MEMORY_TYPE_G  : string   := "distributed";  -- scan output queue backend
      Q_SZ_G         : positive := 4;              -- FIFO depth (power of 2)
      T_SZ_G         : positive := 32);            -- data width per entry
   port (
      clk              : in  sl;
      rst              : in  sl := not RST_POLARITY_G;
      -- FIFOF enqueue side (fifof.enq)
      enqEn            : in  sl;                              -- enq strobe
      enqData          : in  slv(T_SZ_G-1 downto 0);          -- data to enqueue
      -- FIFOF dequeue / status side
      deqEn            : in  sl;                              -- deq strobe
      fifoFirst        : out slv(T_SZ_G-1 downto 0);          -- first() (comb read)
      fifoNotEmpty     : out sl;                              -- notEmpty()
      fifoNotFull      : out sl;                              -- notFull()
      deqPulse         : out sl;                              -- deqPulse()
      fifoSize         : out slv(log2(Q_SZ_G) downto 0);      -- size() (itemCnt)
      -- clear() method (either interface)
      clearEn          : in  sl;
      -- scan control (scanCntrl)
      scanHead         : out slv(T_SZ_G-1 downto 0);          -- getHead() (PRE_SCAN)
      modifyHeadEn     : in  sl;                              -- modifyHead strobe
      modifyHeadData   : in  slv(T_SZ_G-1 downto 0);          -- modifyHead value
      preScanStartEn   : in  sl;                              -- preScanStart()
      scanStartEn      : in  sl;                              -- scanStart()
      scanStopEn       : in  sl;                              -- scanStop()
      preScanRestartEn : in  sl;                              -- preScanRestart()
      hasScanOut       : out sl;                              -- hasScanOut()
      isScanDone       : out sl;                              -- isScanDone()
      inPreScan        : out sl;                              -- PRE_SCAN_S status (DEVIATION-SQQP-01)
      -- scan output PipeOut (read side of U_ScanOutQ)
      scanOutValid     : out sl;                              -- scanOutQ valid
      scanOutData      : out slv(T_SZ_G-1 downto 0);          -- scanOutQ dout
      scanOutReady     : in  sl);                             -- -> scanOutQ rd_en
end ScanFifoF;

architecture rtl of ScanFifoF is

   -----------------------------------------------------------------------------
   -- Constants (widths traced from BSV provisos)
   --   ptrSz = TLog(qSz)            ; cntSz = TLog(qSz+1) = ptrSz + 1 (qSz pow2)
   --   headReg / pushReg width = 1 + tSz  (Maybe#(a): MSB = valid bit)
   -----------------------------------------------------------------------------
   constant PTR_SZ_C        : integer := log2(Q_SZ_G);   -- pointer width
   constant CNT_SZ_C        : integer := PTR_SZ_C + 1;   -- item/scan count width
   constant MAYBE_SZ_C      : integer := T_SZ_G + 1;     -- {valid, data}

   -- almostFull = all itemCnt bits except the MSB are '1' (itemCnt = Q_SZ_G-1)
   constant ALMOST_FULL_C   : slv(CNT_SZ_C-2 downto 0) := (others => '1');

   constant FIFO_ADDR_WIDTH_C : integer := 4;            -- surf.Fifo minimum

   -----------------------------------------------------------------------------
   -- Types
   -----------------------------------------------------------------------------
   type ScanStateType is (
      FIFO_S,                                  -- SCAN_Q_FIFOF_MODE   = 0
      PRE_SCAN_S,                              -- SCAN_Q_PRE_SCAN_MODE = 1
      SCAN_S);                                 -- SCAN_Q_SCAN_MODE     = 2

   type DataVecType is array (0 to Q_SZ_G-1) of slv(T_SZ_G-1 downto 0);

   type RegType is record
      scanStateReg      : ScanStateType;                 -- mkReg(FIFO mode)
      dataVec           : DataVecType;                   -- mkRegU (no reset)
      enqPtrReg         : slv(PTR_SZ_C-1 downto 0);       -- mkReg(0)
      deqPtrReg         : slv(PTR_SZ_C-1 downto 0);       -- mkReg(0)
      scanPtrReg        : slv(PTR_SZ_C-1 downto 0);       -- mkRegU
      fullReg           : sl;                             -- mkReg(False)
      emptyReg          : sl;                             -- mkReg(True)
      headReg           : slv(MAYBE_SZ_C-1 downto 0);     -- mkRegU {valid,data}
      itemCnt           : slv(CNT_SZ_C-1 downto 0);       -- mkCount(0)
      scanCnt           : slv(CNT_SZ_C-1 downto 0);       -- mkCount(0)
      -- U_ScanOutQ occupancy (writes minus completed reads); gates the
      -- drain-based scanDone exit (see header DEVIATION note). No BSV
      -- counterpart — the Fifo's own empty/valid flags lag a write by 1-2
      -- cycles and cannot signal "truly drained" safely.
      outQOcc           : slv(FIFO_ADDR_WIDTH_C downto 0);
      -- NOTE: the BSV CReg(2) control pulses (pushReg/popReg/clearReg/
      -- preScanStartReg/scanStartReg/scanStopReg/preScanRestartReg/
      -- scanDoneReg) are intra-cycle forwarding only (registered value is
      -- always False) and are therefore NOT registered state — the input
      -- strobes are consumed combinationally in the same cycle.
   end record RegType;

   constant REG_INIT_C : RegType := (
      scanStateReg      => FIFO_S,
      dataVec           => (others => (others => '0')),   -- mkRegU: don't-care
      enqPtrReg         => (others => '0'),
      deqPtrReg         => (others => '0'),
      scanPtrReg        => (others => '0'),               -- mkRegU: don't-care
      fullReg           => '0',
      emptyReg          => '1',
      headReg           => (others => '0'),               -- mkRegU: Invalid
      itemCnt           => (others => '0'),
      scanCnt           => (others => '0'),
      outQOcc           => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- U_ScanOutQ (surf.Fifo) interface signals
   signal scanOutQValid   : sl;                           -- valid
   signal scanOutQDout    : slv(T_SZ_G-1 downto 0);       -- dout
   signal scanOutQNotFull : sl;                           -- not_full (enq guard)
   signal scanOutQWrEn    : sl;                           -- wr_en (scanNext enq)
   signal scanOutQDin     : slv(T_SZ_G-1 downto 0);       -- din
   signal scanOutQRdEn    : sl;                           -- rd_en (consumer)
   signal scanOutQClr     : sl;                           -- clear strobe/level

   -- Clear / reset plumbing (OQ-FSM-01 / OQ-FSM-06)
   signal scanOutQRst   : sl;                             -- rst OR scanOutQClr
   signal rstActiveHigh : sl;

begin

   -----------------------------------------------------------------------------
   -- Scan output queue (BSV scanOutQ : FIFOF#(a))
   --   FSM (scanNext) drives the write side; external consumer drains the read
   --   side via the PipeOut handshake. FWFT so dout/valid present without an
   --   rd_en pulse (BSV first/deq peek semantics).
   -----------------------------------------------------------------------------
   U_ScanOutQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',             -- active-high (clear-via-rst, OQ-FSM-01)
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,            -- single clock; next-cycle release
         FWFT_EN_G       => true,            -- first/deq peek semantics
         MEMORY_TYPE_G   => MEMORY_TYPE_G,
         DATA_WIDTH_G    => T_SZ_G,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_C)
      port map (
         rst      => scanOutQRst,
         wr_clk   => clk,
         wr_en    => scanOutQWrEn,           -- scanNext enq
         din      => scanOutQDin,
         not_full => scanOutQNotFull,        -- scanNext implicit guard
         rd_clk   => clk,
         rd_en    => scanOutQRdEn,           -- external consumer
         dout     => scanOutQDout,
         valid    => scanOutQValid);

   -- Active-high reset for the FIFO clear mechanism (OQ-FSM-01 / OQ-FSM-06):
   -- scanOutQClr is asserted as a LEVEL over FIFO_S and as a pulse on
   -- scanStop / preScanRestart / clearAll; OR-ed with the global reset.
   rstActiveHigh <= rst when RST_POLARITY_G = '1' else not rst;
   scanOutQRst   <= rstActiveHigh or scanOutQClr;

   -----------------------------------------------------------------------------
   -- Combinatorial process (two-process FSM): next state + outputs into v.
   -----------------------------------------------------------------------------
   comb : process (r, rst, enqEn, enqData, deqEn, clearEn, preScanStartEn,
                   scanStartEn, scanStopEn, preScanRestartEn, modifyHeadEn,
                   modifyHeadData, scanOutQValid, scanOutQNotFull,
                   scanOutReady) is
      variable v : RegType;
      -- canonicalize helpers (decoded from the registered CReg pulses)
      variable hasPush       : sl;
      variable hasPop        : sl;
      variable pushData      : slv(T_SZ_G-1 downto 0);
      variable isAlmostFull  : sl;
      variable isAlmostEmpty : sl;
      -- scanNext datapath
      variable scanOutElem : slv(T_SZ_G-1 downto 0);
      -- Mealy outputs to U_ScanOutQ
      variable vScanOutQWrEn : sl;
      variable vScanOutQDin  : slv(T_SZ_G-1 downto 0);
      variable vScanOutQClr  : sl;
   begin
      v := r;

      -- Defaults for Mealy outputs (deasserted unless a branch drives them)
      vScanOutQWrEn := '0';
      vScanOutQDin  := (others => '0');
      vScanOutQClr  := '0';
      scanOutElem   := (others => '0');

      -- CReg intra-cycle forwarding: the method (port-0) strobes of THIS cycle
      -- are what the rules (port-1 reads) consume — no registration (see the
      -- header BUGFIX note; matches BSV write[0] SB read[1] ordering).
      hasPush  := enqEn;
      hasPop   := deqEn;
      pushData := enqData;

      -- Saturating-count status helpers over the current item count
      if (r.itemCnt(CNT_SZ_C-2 downto 0) = ALMOST_FULL_C) then
         isAlmostFull := '1';                -- itemCnt = Q_SZ_G-1 (full after push)
      else
         isAlmostFull := '0';
      end if;
      if (unsigned(r.itemCnt) = 1) then
         isAlmostEmpty := '1';               -- itemCnt = 1 (empty after pop)
      else
         isAlmostEmpty := '0';
      end if;

      -----------------------------------------------------------------------
      -- Rule priority (FSM spec lines 364-371):
      --   1. clearAll          (overrides everything)
      --   2. scanModeStateChange (SCAN; suppresses scanNext on stop/restart)
      --   3. canonicalize      (always, disjoint write set)
      --   4. scanNext          (SCAN, not suppressed, scanOutQ not full)
      --   5. fifoMode / preScanMode (per state)
      -- clearAll / canonicalize / the state rules consume the SAME-CYCLE input
      -- strobes (BSV CReg port-1 reads see the port-0 method writes of the
      -- current cycle); a same-cycle clear discards any concurrent push/pop
      -- (BSV: clearAll's port-1 False writes are the last writes committed).
      -----------------------------------------------------------------------
      if (clearEn = '1') then
         -- rule clearAll : reset pointers/counts/flags/state and flush scanOutQ
         v.enqPtrReg         := (others => '0');
         v.deqPtrReg         := (others => '0');
         v.itemCnt           := (others => '0');
         v.fullReg           := '0';
         v.emptyReg          := '1';
         v.scanStateReg      := FIFO_S;
         vScanOutQClr        := '1';               -- U_ScanOutQ.clear

      else
         ---------------------------------------------------------------------
         -- canonicalize : commit the pending push/pop every cycle (all states)
         ---------------------------------------------------------------------
         if (hasPush = '1') then
            v.dataVec(to_integer(unsigned(r.enqPtrReg))) := pushData;
            v.enqPtrReg                                  := slv(unsigned(r.enqPtrReg) + 1);
         end if;
         if (hasPop = '1') then
            v.deqPtrReg := slv(unsigned(r.deqPtrReg) + 1);
         end if;
         if (hasPush = '0') and (hasPop = '1') then
            v.itemCnt  := slv(unsigned(r.itemCnt) - 1);
            v.emptyReg := isAlmostEmpty;           -- empty iff itemCnt was 1
            v.fullReg  := '0';
         elsif (hasPush = '1') and (hasPop = '0') then
            v.itemCnt  := slv(unsigned(r.itemCnt) + 1);
            v.fullReg  := isAlmostFull;            -- full iff itemCnt was Q_SZ_G-1
            v.emptyReg := '0';
         end if;
         -- both / neither: itemCnt and flags unchanged

         ---------------------------------------------------------------------
         -- State rules (mutually exclusive by scanStateReg)
         ---------------------------------------------------------------------
         case r.scanStateReg is

            when FIFO_S =>
               -- rule fifoMode : optional transition into PRE_SCAN; hold
               -- scanOutQ cleared (level) and head invalidated while idle.
               vScanOutQClr := '1';
               v.headReg    := (others => '0');    -- Invalid
               if (preScanStartEn = '1') and (r.emptyReg = '0') then
                  v.scanStateReg := PRE_SCAN_S;
               end if;

            when PRE_SCAN_S =>
               -- rule preScanMode : snapshot deqPtr->scanPtr, itemCnt->scanCnt;
               -- optional transition into SCAN. (deq blocked here by guards.)
               -- DEVIATION: scanStop is honoured here too (BSV guards scanStop
               -- to inScanMode and relies on the caller's implicit conditions
               -- to defer the whole ERR flush; the port-level VHDL cannot, so
               -- an abort while pre-scanning must not strand the FSM here —
               -- otherwise RespHandleSq's ERR flush deqs against PRE_SCAN).
               -- DEVIATION-SQQP-01: enq IS legal during PRE_SCAN (see header),
               -- so the snapshot takes the post-enq count v.itemCnt — an
               -- enqueue landing on the same cycle as scanStart is still
               -- inside the replay window. deq stays gated off by the parent,
               -- so v.deqPtrReg = r.deqPtrReg here.
               v.scanPtrReg := r.deqPtrReg;
               v.scanCnt    := v.itemCnt;
               if (scanStopEn = '1') then
                  v.scanStateReg := FIFO_S;
               elsif (scanStartEn = '1') then
                  v.scanStateReg := SCAN_S;
               end if;

            when SCAN_S =>
               -- rule scanModeStateChange (stop > restart > done) + scanNext.
               if (scanStopEn = '1') then
                  -- abort scan; scanNext SUPPRESSED (no emit, no advance)
                  v.scanStateReg := FIFO_S;
                  vScanOutQClr   := '1';           -- U_ScanOutQ.clear

               elsif (preScanRestartEn = '1') then
                  -- restart snapshot; scanNext SUPPRESSED
                  v.scanStateReg := PRE_SCAN_S;
                  vScanOutQClr   := '1';           -- U_ScanOutQ.clear

               else
                  -- rule scanNext : emit one entry per cycle.
                  --   implicit guard : scanOutQ not full
                  --   OQ-FSM-05      : suppress when scanCnt = 0 (nothing left)
                  if (scanOutQNotFull = '1') and (unsigned(r.scanCnt) /= 0) then
                     -- first scan output may use the modified head
                     if (r.headReg(MAYBE_SZ_C-1) = '1') then
                        scanOutElem := r.headReg(T_SZ_G-1 downto 0);
                     else
                        scanOutElem := r.dataVec(to_integer(unsigned(r.scanPtrReg)));
                     end if;
                     v.scanCnt     := slv(unsigned(r.scanCnt) - 1);
                     v.scanPtrReg  := slv(unsigned(r.scanPtrReg) + 1);
                     v.headReg     := (others => '0');      -- consume modified head
                     vScanOutQWrEn := '1';
                     vScanOutQDin  := scanOutElem;
                  end if;

                  -- scanDone: all snapshot entries emitted AND the scan output
                  -- queue fully drained (drain-gated exit; header DEVIATION
                  -- note). Mutually exclusive with scanNext (scanCnt = 0).
                  if (unsigned(r.scanCnt) = 0) and (unsigned(r.outQOcc) = 0) then
                     v.scanStateReg := FIFO_S;
                  end if;
               end if;

         end case;
      end if;

      -----------------------------------------------------------------------
      -- modifyHead (BSV: plain mkRegU headReg, method write lands next cycle).
      -- Method guards are enforced by the caller; most immAssert checks in the
      -- BSV source are runtime-only and are not re-encoded here (OQ-FSM-07).
      -----------------------------------------------------------------------
      if (modifyHeadEn = '1') then
         v.headReg := '1' & modifyHeadData;   -- Valid modified head
      end if;

      -----------------------------------------------------------------------
      -- U_ScanOutQ occupancy bookkeeping: any clear (level or pulse) empties
      -- the queue; otherwise count writes minus completed reads (a read
      -- completes only when rd_en meets a presented word, i.e. valid = '1').
      -----------------------------------------------------------------------
      if (vScanOutQClr = '1') then
         v.outQOcc := (others => '0');
      elsif (vScanOutQWrEn = '1') and
            not ((scanOutReady = '1') and (scanOutQValid = '1')) then
         v.outQOcc := slv(unsigned(r.outQOcc) + 1);
      elsif (vScanOutQWrEn = '0') and
            (scanOutReady = '1') and (scanOutQValid = '1') then
         v.outQOcc := slv(unsigned(r.outQOcc) - 1);
      end if;

      -- Synchronous reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin <= v;

      -- Mealy outputs to U_ScanOutQ (combinational from this cycle's firing).
      -- Left ungated under reset: scanOutQRst forces the FIFO's synchronous
      -- reset, which dominates a concurrent wr_en (OQ-FSM-01 RESOLVED).
      scanOutQWrEn <= vScanOutQWrEn;
      scanOutQDin  <= vScanOutQDin;
      scanOutQClr  <= vScanOutQClr;

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
   -- Simulation-only protocol checks (BSV mkScanFIFOF immAsserts).
   -- CLOCKED on purpose: enqEn/deqEn and the scan strobes are Mealy inputs
   -- combinationally derived (in the parent) from this entity's own outputs
   -- (isScanDone/inPreScan), so for a few delta cycles after a state edge
   -- they hold stale values against the freshly updated r.scanStateReg. An
   -- immediate assert in the comb process false-fires on those transients
   -- (seen in Questa at the PRE_SCAN->SCAN release edge with a same-cycle
   -- legal PRE_SCAN enq). Sampling at rising_edge(clk) checks exactly the
   -- settled values the DUT commits.
   -----------------------------------------------------------------------------
   -- pragma translate_off
   chk : process (clk) is
   begin
      if rising_edge(clk) and (rst /= RST_POLARITY_G) then
         -- a deq strobe must never coincide with a scan(-re)start or land in
         -- PRE_SCAN. Any violation here means the PARENT is producing the
         -- spurious pop that unbalances the SQ pending-request counter.
         assert not (deqEn = '1' and preScanStartEn = '1')
            report "deq coincides with preScanStart @ ScanFifoF" severity error;
         assert not (deqEn = '1' and scanStartEn = '1')
            report "deq coincides with scanStart @ ScanFifoF" severity error;
         assert not (deqEn = '1' and preScanRestartEn = '1')
            report "deq coincides with preScanRestart @ ScanFifoF" severity error;
         assert not (deqEn = '1' and r.scanStateReg = PRE_SCAN_S)
            report "deq while in PRE_SCAN mode @ ScanFifoF" severity error;
         -- BSV enq implicit condition is (!isFull && inFifoMode)
         -- (SpecialFIFOF.bsv:424). DEVIATION-SQQP-01 additionally admits enq
         -- during PRE_SCAN (included in the continuous snapshot); an enq
         -- landing mid-SCAN still escapes the scan snapshot and is silently
         -- excluded from the retry replay (partial go-back-N retransmit) —
         -- the caller must gate enq on (isScanDone or inPreScan).
         assert not (enqEn = '1' and r.scanStateReg = SCAN_S)
            report "enq while in SCAN mode @ ScanFifoF" severity error;
         -- while scanning: dequeue must not overtake the scan pointer, and
         -- occupancy must never drop below the remaining scan count.
         if (r.scanStateReg = SCAN_S) then
            assert (deqEn = '0') or
                   (unsigned(r.deqPtrReg) /= unsigned(r.scanPtrReg) + 1)
               report "deq overtakes scanPtr @ ScanFifoF" severity error;
            assert (unsigned(r.itemCnt) >= unsigned(r.scanCnt))
               report "itemCnt < scanCnt @ ScanFifoF" severity error;
         end if;
      end if;
   end process chk;
   -- pragma translate_on

   -----------------------------------------------------------------------------
   -- Outputs
   -----------------------------------------------------------------------------
   -- Moore (registered state reads)
   fifoNotEmpty <= not r.emptyReg;
   fifoNotFull  <= not r.fullReg;
   -- deqPulse: BSV deqPulse() = popReg[1], i.e. the SAME-CYCLE deq() strobe
   -- (registered popReg is always False). Mealy passthrough, NOT delayed.
   deqPulse     <= deqEn;
   fifoSize     <= r.itemCnt;
   isScanDone   <= '1' when (r.scanStateReg = FIFO_S) else '0';
   inPreScan    <= '1' when (r.scanStateReg = PRE_SCAN_S) else '0';

   -- Mealy (combinational array reads; BSV first()/getHead() peek semantics)
   fifoFirst <= r.dataVec(to_integer(unsigned(r.deqPtrReg)));
   scanHead  <= r.dataVec(to_integer(unsigned(r.deqPtrReg)));

   -- hasScanOut = !inFifoMode || scanOutQ.notEmpty  (FSM spec line 128/470)
   hasScanOut <= '1' when (r.scanStateReg /= FIFO_S) or (scanOutQValid = '1') else '0';

   -- Scan output PipeOut (read side of U_ScanOutQ)
   scanOutValid <= scanOutQValid;
   scanOutData  <= scanOutQDout;
   scanOutQRdEn <= scanOutReady;

end architecture rtl;
