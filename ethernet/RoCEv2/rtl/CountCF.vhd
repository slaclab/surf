-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Conflict-free up/down counter. incrOne()/decrOne() each set a one-cycle
--   registered "tick"; every cycle the counter applies the net delta
--   (+1 / -1 / 0) of the ticks captured on the previous cycle, and _write()
--   overrides the count and discards any pending ticks.
--
--   Cycle accuracy vs BSV mkCountCF (PrimUtils.bsv:276-332): an incrOne()
--   issued in cycle n is visible on _read() in cycle n+2, exactly as in BSV
--   (enq cycle n -> increment rule deqs and CReg-forwards cycle n+1 -> cntReg
--   updated edge n+1 -> readable n+2). _write() lands on the same edge it is
--   issued (BSV writeReg CReg port-0 -> write rule same cycle) and discards
--   both in-flight and same-cycle ticks (BSV: increment/decrement rules are
--   guarded off and both queues cleared).
--
--   BUGFIX 2026-07-08 (OQ-FSM-03 class): the previous implementation queued
--   ticks through surf.Fifo instances, whose FWFT read path adds several
--   cycles of latency before a tick reaches cntReg. Guards written against
--   the BSV one-tick-in-flight margin (e.g. NewPendingWorkReqPipeOut's
--   "pendingCnt < getPendingWorkReqNum - 1", QueuePair.bsv:105) then act on a
--   stale count: a back-to-back 50-WR burst overshot MAX_QP_WR by ~5 and
--   flooded the "pendingCnt > MAX_QP_WR" assertion. BSV mkFIFOF ticks never
--   buffer more than one entry (the apply rules drain every cycle), so the
--   FIFOs are pure scheduling artifacts and collapse to single registered
--   tick flags — restoring the exact BSV visibility latency.
--
--   The BSV CReg(2) scratch registers (writeReg/incrReg/decrReg) are pure
--   intra-cycle forwarding signals and collapse to combinational logic here —
--   see OQ-FSM-02.
--
--   No SURF components instantiated (tick FIFOs removed, see BUGFIX above).
--   FIFO_ADDR_WIDTH_G is retained for port/generic compatibility with
--   existing instantiations but is no longer used.
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

entity CountCF is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      RST_ASYNC_G    : boolean  := false;
      WIDTH_G        : positive := 8;    -- count width = tSz of BSV anytype
      RESET_VAL_G    : slv      := "00000000";  -- BSV mkCountCF 'resetVal' parameter (length must = WIDTH_G)
      FIFO_ADDR_WIDTH_G : positive range 4 to 48 := 4);  -- UNUSED (legacy, kept for instantiation compatibility)
   port (
      clk        : in  sl;
      rst        : in  sl := not RST_POLARITY_G;
      -- incrOne() method : register a +1 tick (always ready, see header)
      incrOneEn  : in  sl;
      incrOneRdy : out sl;
      -- decrOne() method : register a -1 tick (always ready, see header)
      decrOneEn  : in  sl;
      decrOneRdy : out sl;
      -- _write() method : override count and discard pending ticks
      writeEn    : in  sl;
      writeVal   : in  slv(WIDTH_G-1 downto 0);
      -- _read() method : current count (Moore, registered)
      cntOut     : out slv(WIDTH_G-1 downto 0));
end CountCF;

architecture rtl of CountCF is

   -- Registered state: the count (BSV cntReg <- mkReg(resetVal)) plus one
   -- pending-tick flag per direction (BSV incrQ/decrQ head, never deeper
   -- than one entry — see header).
   type RegType is record
      cntReg   : slv(WIDTH_G-1 downto 0);
      incrPend : sl;
      decrPend : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      cntReg   => RESET_VAL_G,
      incrPend => '0',
      decrPend => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   -- Elaboration sanity check: the reset value must be WIDTH_G bits wide.
   assert (RESET_VAL_G'length = WIDTH_G)
      report "CountCF: RESET_VAL_G length must equal WIDTH_G" severity failure;

   -- Method-readiness: the tick flags are consumed every cycle, so the BSV
   -- implicit conditions (incrQ/decrQ notFull) can never block.
   incrOneRdy <= '1';
   decrOneRdy <= '1';

   --------------------------------------------------------------------------
   -- Combinatorial : per-cycle priority action table (single state OPER_S).
   --   priority: write > (net delta of previous-cycle ticks).
   --------------------------------------------------------------------------
   comb : process (r, rst, incrOneEn, decrOneEn, writeEn, writeVal) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Capture this cycle's method ticks (applied to cntReg next cycle,
      -- matching the BSV enq -> deq-and-apply pipeline).
      v.incrPend := incrOneEn;
      v.decrPend := decrOneEn;

      -- cntReg update: write wins and discards ticks (BSV write rule clears
      -- both queues and gates off the apply rules); otherwise apply the net
      -- +1/-1/0 delta of the ticks captured on the previous cycle.
      if (writeEn = '1') then
         v.cntReg   := writeVal;
         v.incrPend := '0';             -- same-cycle enq discarded (clear after enq)
         v.decrPend := '0';
      elsif (r.incrPend = '1') and (r.decrPend = '0') then
         v.cntReg := slv(unsigned(r.cntReg) + 1);
      elsif (r.incrPend = '0') and (r.decrPend = '1') then
         v.cntReg := slv(unsigned(r.cntReg) - 1);
      end if;                           -- both ticks (net 0) or neither: hold

      -- Synchronous Reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Moore output
      cntOut <= r.cntReg;
   end process comb;

   --------------------------------------------------------------------------
   -- Sequential
   --------------------------------------------------------------------------
   seq : process (clk, rst) is
   begin
      if (RST_ASYNC_G) and (rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
