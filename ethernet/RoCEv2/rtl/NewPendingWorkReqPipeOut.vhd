-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Accepts upstream WorkReq items and converts them to PendingWorkReq by
--   appending four Invalid-Maybe fields (78 bits of zeros), then enqueues them
--   into an output FIFO (U_OutQ).  Tracks the number of in-flight pending work
--   requests via a CountCF sub-entity (U_PendingCnt, 8 bits).
--
--   Three mutually-exclusive QP-state predicates drive three BSV rules:
--     resetAndClear           — continuous FIFO clear + counter reset
--                               while isReset_i='1'
--     flushWR                 — consume and forward WR when QP is in ERR state
--     genPendingWR            — consume, forward, and increment count in RTS
--   A fourth rule, decrPendingNewWorkReqCnt, decrements the count on an
--   external completion pulse and may fire simultaneously with genPendingWR.
--
--   No local registered state: all state lives in U_OutQ and U_PendingCnt.
--   The two-process skeleton is retained for uniformity; the RegType record
--   carries a single dummy field so the VHDL compiles without an empty record.
--   The comb process drives sub-instance control ports only.
--
--   SURF components instantiated:
--     U_OutQ : surf.Fifo  (DATA_WIDTH_G=679, FWFT, sync, distributed RAM)
--       source: surf/base/fifo/rtl/Fifo.vhd
--
--   Project entities instantiated:
--     U_PendingCnt : work.CountCF  (WIDTH_G=8; tick FIFOs depth CNT_ADDR_WIDTH_G)
--       source: out/04-vhdl/CountCF.vhd
--
--   FIFO clear (OQ-FSM-NPWRPO-02, resolved via OQ-FSM-06 in RESOLVED.md):
--     outQRst is held HIGH as a level for the duration that isReset_i='1'.
--     surf.FifoSync has no edge-detection on rst; holding it continuously
--     pins the FIFO logically empty.  No pulse-generator needed.
--
--   PendingWorkReq bit-packing (OQ-FSM-NPWRPO-03, resolved in RESOLVED.md):
--     BSV deriving(Bits) packs first-field-at-MSB.
--     Bits 678:78 = WorkReq (601 b), bits 77:0 = four Invalid-Maybe zeros:
--       isOnlyReqPkt [1:0], pktNum [27:2], endPSN [52:28], startPSN [77:53].
--     VHDL: outQDin = workReqData_i & (77 downto 0 => '0').
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

entity NewPendingWorkReqPipeOut is
   generic (
      TPD_G             : time                   := 1 ns;
      RST_POLARITY_G    : sl                     := '1';
      RST_ASYNC_G       : boolean                := false;
      FIFO_ADDR_WIDTH_G : positive range 4 to 48 := 4;  -- U_OutQ depth = 2**G entries
      CNT_ADDR_WIDTH_G  : positive range 4 to 48 := 4;  -- U_PendingCnt tick-FIFO depth
      MAX_QP_WR_G       : positive               := 32);  -- Settings.bsv MAX_QP_WR
   port (
      clk                      : in  sl;
      rst                      : in  sl := not RST_POLARITY_G;
      -- QP state predicates — mutually exclusive; guaranteed by CntrlQP semantics
      isReset_i                : in  sl;
      isERR_i                  : in  sl;
      isRTS_i                  : in  sl;
      -- QP attribute: configured maximum number of pending work requests
      getPendingWorkReqNum_i   : in  slv(7 downto 0);
      -- External completion pulse: a pending WR has been acknowledged/completed
      decrPendingReqCntPulse_i : in  sl;
      -- Upstream WorkReq PipeIn (workReqPipeIn)
      workReqValid_i           : in  sl;
      workReqData_i            : in  slv(600 downto 0);  -- WorkReq, 601 bits
      workReqRdy_o             : out sl;
      -- Output PipeOut (newPendingWorkReqOutQ exposed via U_OutQ)
      outQValid_o              : out sl;
      outQDout_o               : out slv(678 downto 0);  -- PendingWorkReq, 679 bits
      outQRdEn_i               : in  sl);
end NewPendingWorkReqPipeOut;

architecture rtl of NewPendingWorkReqPipeOut is

   -- No local FSM state: all state in U_OutQ and U_PendingCnt.
   -- One dummy bit keeps the RegType record syntactically non-empty.
   type RegType is record
      dummy : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (dummy => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- genNewPendingWorkReq packing constant (OQ-FSM-NPWRPO-03 resolved):
   -- Four Invalid-Maybe fields occupy bits 77:0 of PendingWorkReq — all zeros.
   constant MAYBE_PAD_C : slv(77 downto 0) := (others => '0');

   -- U_OutQ signals
   signal outQRst     : sl;
   signal outQWrEn    : sl;
   signal outQDin     : slv(678 downto 0);
   signal outQNotFull : sl;

   -- U_PendingCnt (CountCF) control signals
   signal pendingCntOut      : slv(7 downto 0);
   signal pendingCntIncrEn   : sl;
   signal pendingCntDecrEn   : sl;
   signal pendingCntWriteEn  : sl;
   signal pendingCntWriteVal : slv(7 downto 0);

   -- Global reset normalised to active-high (for FIFO rst port)
   signal rstActiveHigh : sl;

begin

   -- Normalise global rst to active-high
   rstActiveHigh <= rst when (RST_POLARITY_G = '1') else not rst;

   -- FIFO clear level: held '1' for the full duration of isReset_i='1'.
   -- surf.FifoSync re-applies REG_INIT_C every cycle rst is asserted;
   -- releasing rst makes the FIFO usable on the very next cycle.  (OQ-FSM-06)
   outQRst <= rstActiveHigh or isReset_i;

   -- genNewPendingWorkReq(wr): WorkReq in MSBs, Invalid-Maybe zeros in LSBs.
   -- Packing is identical for both flushWR and genPendingWR paths.
   outQDin <= workReqData_i & MAYBE_PAD_C;

   --------------------------------------------------------------------------
   -- U_OutQ : newPendingWorkReqOutQ
   --   BSV: FIFOF#(PendingWorkReq), instantiated as mkFIFO (depth 2, FWFT)
   --   SURF: surf.Fifo, GEN_SYNC_FIFO_G=true, FWFT_EN_G=true
   --   Width: 679 bits (WorkReq 601b + four Invalid-Maybe fields 78b)
   --------------------------------------------------------------------------
   U_OutQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 679,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G)
      port map (
         rst      => outQRst,
         wr_clk   => clk,
         wr_en    => outQWrEn,
         din      => outQDin,
         not_full => outQNotFull,
         rd_clk   => clk,
         rd_en    => outQRdEn_i,
         dout     => outQDout_o,
         valid    => outQValid_o);

   --------------------------------------------------------------------------
   -- U_PendingCnt : pendingNewWorkReqCnt
   --   BSV: mkCountCF(0), PendingReqCnt = Bit#(QP_CAP_CNT_WIDTH) = Bit#(8)
   --   Project entity: surf.CountCF, WIDTH_G=8, reset value = 0
   --------------------------------------------------------------------------
   U_PendingCnt : entity surf.CountCF
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         WIDTH_G           => 8,
         FIFO_ADDR_WIDTH_G => CNT_ADDR_WIDTH_G)
      port map (
         clk        => clk,
         rst        => rst,
         incrOneEn  => pendingCntIncrEn,
         incrOneRdy => open,
         decrOneEn  => pendingCntDecrEn,
         decrOneRdy => open,
         writeEn    => pendingCntWriteEn,
         writeVal   => pendingCntWriteVal,
         cntOut     => pendingCntOut);

   --------------------------------------------------------------------------
   -- Combinatorial: per-cycle rule evaluation
   --   All outputs are Mealy (from current inputs, not from registered state).
   --   Rules are mutually exclusive per QP-state predicate:
   --     isReset_i / isERR_i / isRTS_i are guaranteed disjoint by CntrlQP.
   --   decrPendingNewWorkReqCnt may fire simultaneously with genPendingWR;
   --     CountCF handles simultaneous incr+decr as a net-zero operation.
   --------------------------------------------------------------------------
   comb : process (r, rst, isReset_i, isERR_i, isRTS_i, getPendingWorkReqNum_i,
                   decrPendingReqCntPulse_i, workReqValid_i,
                   outQNotFull, pendingCntOut) is
      variable v         : RegType;
      variable wrRdyV    : sl;
      variable outQWrV   : sl;
      variable incrEnV   : sl;
      variable decrEnV   : sl;
      variable cntWrEnV  : sl;
      variable cntWrValV : slv(7 downto 0);
   begin
      v := r;

      -- Default all Mealy outputs to inactive
      wrRdyV    := '0';
      outQWrV   := '0';
      incrEnV   := '0';
      decrEnV   := '0';
      cntWrEnV  := '0';
      cntWrValV := (others => '0');

      -- Rule: resetAndClear  (no_implicit_conditions, fire_when_enabled)
      --   Fires every cycle isReset='1'.
      --   U_OutQ is cleared via the outQRst level signal (concurrent above).
      --   U_PendingCnt is reset to 0 via write().
      if (isReset_i = '1') then
         cntWrEnV  := '1';
         cntWrValV := (others => '0');
      end if;

      -- Rule: flushWR  (ERR_S implied state)
      --   Consume upstream WR and enqueue PendingWorkReq; no count increment.
      if (isERR_i = '1') and (workReqValid_i = '1') and (outQNotFull = '1') then
         wrRdyV  := '1';
         outQWrV := '1';
      end if;

      -- Rule: genPendingWR  (RTS_S implied state)
      --   Guard: pendingCnt + 1 < getPendingWorkReqNum (one slot reserved).
      --   Equivalent to BSV: pendingCntRd < getPendingWorkReqNum - 1.
      --   Using (count+1 < max) avoids unsigned-subtraction underflow when max=0
      --   (safe: in valid operation max >= 1).
      if (isRTS_i = '1') and
         (unsigned(pendingCntOut) + 1 < unsigned(getPendingWorkReqNum_i)) and
         (workReqValid_i = '1') and (outQNotFull = '1') then
         wrRdyV  := '1';
         outQWrV := '1';
         incrEnV := '1';
      end if;

      -- Rule: decrPendingNewWorkReqCnt  (RTS_S; may fire same cycle as genPendingWR)
      if (isRTS_i = '1') and (decrPendingReqCntPulse_i = '1') then
         decrEnV := '1';
      end if;

      -- Synchronous reset (dummy field only; no live state to restore)
      if (RST_ASYNC_G = false) and (rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin <= v;

      -- Drive outputs
      workReqRdy_o       <= wrRdyV;
      outQWrEn           <= outQWrV;
      pendingCntIncrEn   <= incrEnV;
      pendingCntDecrEn   <= decrEnV;
      pendingCntWriteEn  <= cntWrEnV;
      pendingCntWriteVal <= cntWrValV;

   end process comb;

   --------------------------------------------------------------------------
   -- Sequential: register update (skeleton only; no live registered fields)
   --------------------------------------------------------------------------
   seq : process (clk, rst) is
   begin
      if (RST_ASYNC_G) and (rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -- pragma translate_off
   --------------------------------------------------------------------------
   -- Simulation assertions
   --   checkPendingNewWorkReqCnt (QueuePair.bsv:133-143): MAX_QP_WR >= count
   --   decrPendingNewWorkReqCnt immAssert (QueuePair.bsv:121-128): count > 0
   --------------------------------------------------------------------------
   check : process (clk) is
   begin
      if rising_edge(clk) then
         assert unsigned(pendingCntOut) <= to_unsigned(MAX_QP_WR_G, 8)
            report "NewPendingWorkReqPipeOut: pendingCnt > MAX_QP_WR" severity error;
         if (pendingCntDecrEn = '1') then
            assert unsigned(pendingCntOut) > 0
               report "NewPendingWorkReqPipeOut: pendingCnt underflow on decrement" severity error;
         end if;
      end if;
   end process check;
   -- pragma translate_on

end architecture rtl;
