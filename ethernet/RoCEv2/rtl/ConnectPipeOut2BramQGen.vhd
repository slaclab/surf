-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Two-stage forwarding / skid wrapper around an externally-owned BRAM FIFO.
--   It (1) pushes fragments from the upstream pipeIn into the external bramQ, and
--   (2) pulls them out of bramQ into a small internal skid FIFO (postBramQ) which
--   it re-exposes as a PipeOut.
--
--   Identical in structure to ConnectPipeOut2BramQConAndGen: that adapter has
--   the same two mkConnection rules (pipeIn -> bramQ enqueue, bramQ ->
--   postBramQ skid), driving both the put and the get ports of the external
--   bramQ. Only the (absent) instantiation context and the data width differ
--   (see below).
--
--   There is NO explicit state register and NO data-dependent control flow: per
--   the FSM spec (§State register / §Output style) the only "machines" are the two
--   implicit mkConnection transfer rules, each gated solely by the relevant FIFOs'
--   full/empty flags. This entity is therefore emitted as a *pure structural
--   wrapper* — one surf.Fifo plus combinational glue — with NO two-process FSM and
--   NO RegType (the only registered storage local to this entity lives inside
--   U_PostBramQ; bramQ is registered storage outside this entity's scope).
--
--   BramPipe interface (3 live methods + the pipeIn input arg, restored per
--   OQ-FSM-CPG-1 / OQ-FSM-CPG-2; mapping.json listed only "pipeInPort"):
--     pipeIn   : PipeOut#(anytype)     -> input handshake (notEmpty/first in, deq out)
--     pipeOut  : PipeOut#(anytype)     -> first/deq/notEmpty handshake ports
--     clear()  : Action                -> clearEnI (synchronous flush of postBramQ)
--     notEmpty : Bool                  -> notEmpty output
--   bramQ (module argument, no in-scope owner) is exposed as a put+get handshake
--   (wrEn/din/notFull and deq/first/notEmpty).
--
--   Three independent, conflict-free handshakes (fsm.md §Transition table):
--     * Stage 1 — pipeIn -> bramQ enqueue (mkConnection rl_in2bram, line 1985):
--         fire1 = pipeInNotEmpty AND bramQNotFull
--         -> pipeInDeq, bramQWrEn, bramQDin = pipeInFirst
--     * Stage 2 — bramQ -> postBramQ skid (mkConnection rl_bram2skid, line 1986):
--         fire2 = bramQNotEmpty AND postBramQNotFull   (suppressed during flush)
--         -> bramQDeq, postBramQWrEn, postBramQDin = bramQFirst
--     * Downstream — pipeOut dequeue (toPipeOut, line 1988):
--         postBramQRdEn = pipeOutDeq
--     They touch distinct FIFO ports and may all occur in the same cycle.
--
--   clear() mapping (OQ-FSM-CPG-3, resolved via OQ-FSM-01 in
--   out/03-fsm/RESOLVED.md):
--     surf.Fifo has no dedicated clear port; BSV postBramQ.clear is modelled by
--     asserting the Fifo rst, OR'd with the structural reset:
--         fifoRst <= rst or clearEnI
--     surf.FifoSync (GEN_SYNC_FIFO_G=true, RST_ASYNC_G=false, RST_POLARITY_G='1')
--     holds the FIFO logically empty for the whole asserted window (level-safe; no
--     pulse generator). clear() flushes ONLY postBramQ (BSV clear method, lines
--     1989-1991); the external bramQ has no in-scope owner to clear it (it would
--     be cleared by whatever owns it). The stage-2 skid enqueue
--     (bramQDeq / postBramQWrEn) is SUPPRESSED while clearEnI='1' so a fragment is
--     not dequeued from bramQ only to be discarded by the flush. The stage-1
--     pipeIn -> bramQ enqueue is NOT suppressed (it does not touch postBramQ).
--
--   Width (OQ-FSM-CPG-1, per the project-wide OQ-FSM-H2DS-02 resolution):
--     DataStream = data(256)+byteEn(32)+isFirst(1)+isLast(1) = 290 bits.
--     This entity has no concrete instantiation site to trace a width from (see
--     dead-code note above); per construction parity with its three siblings,
--     which all carry DataStream through this exact adapter shape, DATA_W_G
--     defaults to 290 — the RESOLVED DataStream width, not the stale 321 the
--     three sibling .vhd/specs still carry (pre-dates the OQ-FSM-H2DS-02 fix).
--
--   SURF components instantiated (source:
--   surf-catalogue-prj/surf/base/fifo/rtl/Fifo.vhd):
--     U_PostBramQ : surf.Fifo  DATA_WIDTH_G=290, FWFT, sync, distributed RAM
--                   (BSV postBramQ <- mkFIFOF). ADDR_WIDTH_G=4 (surf.Fifo min;
--                   the BSV 2-deep skid maps to depth-16 — extra buffering only,
--                   functionally equivalent for a skid stage).
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

entity ConnectPipeOut2BramQGen is
   generic (
      TPD_G    : time     := 1 ns;
      DATA_W_G : positive := 290);  -- DataStream width (OQ-FSM-CPG-1 / OQ-FSM-H2DS-02)
   port (
      clk             : in  sl;
      rst             : in  sl;         -- active-high sync reset
      -- clear() method (Action): synchronous flush of the internal skid FIFO only
      clearEnI        : in  sl;
      -- pipeIn : PipeOut#(anytype) input arg (upstream PipeOut, no in-scope owner)
      pipeInNotEmpty  : in  sl;         -- pipeIn.notEmpty (first valid)
      pipeInFirst     : in  slv(DATA_W_G-1 downto 0);  -- pipeIn.first
      pipeInDeq       : out sl;         -- dequeue upstream pipeIn
      -- bramQ : external BRAM buffer (put + get handshake; NOT instantiated, no in-scope owner)
      bramQNotFull    : in  sl;         -- bramQ.notFull (can enqueue)
      bramQWrEn       : out sl;         -- enqueue into bramQ
      bramQDin        : out slv(DATA_W_G-1 downto 0);  -- bramQ enqueue data
      bramQNotEmpty   : in  sl;         -- bramQ.notEmpty (first valid)
      bramQFirst      : in  slv(DATA_W_G-1 downto 0);  -- bramQ.first
      bramQDeq        : out sl;         -- dequeue bramQ
      -- pipeOut : PipeOut#(anytype) (downstream consumer)
      pipeOutDeq      : in  sl;         -- consumer dequeues pipeOut
      pipeOutFirst    : out slv(DATA_W_G-1 downto 0);  -- pipeOut.first
      pipeOutNotEmpty : out sl;         -- pipeOut.notEmpty
      -- notEmpty() method result (BramPipe)
      notEmpty        : out sl);
end entity ConnectPipeOut2BramQGen;

architecture rtl of ConnectPipeOut2BramQGen is

   -- U_PostBramQ interface signals (DataStream, DATA_W_G bits)
   signal postBramQNotFull : sl;
   signal postBramQValid   : sl;        -- = postBramQ.notEmpty (FWFT)
   signal postBramQDout    : slv(DATA_W_G-1 downto 0);
   signal postBramQWrEn    : sl;
   signal postBramQRdEn    : sl;

   -- Stage-1 (pipeIn -> bramQ) and stage-2 (bramQ -> postBramQ) fire conditions
   signal fire1 : sl;                   -- upstream enqueue (Mealy)
   signal fire2 : sl;                   -- skid enqueue (Mealy, gated)

   -- FIFO reset line: level = rst OR clearEnI (BSV postBramQ.clear)
   signal fifoRst : sl;

begin

   -- FIFO clear (OQ-FSM-CPG-3 / OQ-FSM-01, RESOLVED): level-sensitive flush of the
   -- internal skid FIFO only.
   fifoRst <= rst or clearEnI;

   -- Stage 1: pipeIn -> bramQ enqueue (mkConnection rl_in2bram). Fire when the
   -- upstream has a fragment and the external bramQ can accept it. NOT suppressed
   -- by clear (clear flushes postBramQ, not bramQ).
   fire1     <= pipeInNotEmpty and bramQNotFull;
   pipeInDeq <= fire1;                  -- dequeue upstream pipeIn (Get side)
   bramQWrEn <= fire1;        -- enqueue into external bramQ (Put side)
   bramQDin  <= pipeInFirst;            -- pass-through of upstream head

   -- Stage 2: bramQ -> postBramQ skid enqueue (mkConnection rl_bram2skid). Fire
   -- when bramQ has a fragment and the skid FIFO can accept it. Suppressed during
   -- a clear flush so we do not dequeue bramQ into a FIFO being emptied.
   fire2         <= bramQNotEmpty and postBramQNotFull and (not clearEnI);
   bramQDeq      <= fire2;              -- dequeue external bramQ (Get side)
   postBramQWrEn <= fire2;              -- enqueue into skid FIFO

   -- Downstream dequeue handshake (toPipeOut): decoupled, every-cycle strobe.
   postBramQRdEn <= pipeOutDeq;

   -- pipeOut method wiring (pure combinational re-export of the skid FIFO front)
   pipeOutFirst    <= postBramQDout;
   pipeOutNotEmpty <= postBramQValid;

   -- notEmpty() method: external bramQ has data AND skid FIFO has data
   notEmpty <= bramQNotEmpty and postBramQValid;

   ---------------------------------------------------------------------------
   -- U_PostBramQ : surf.Fifo
   --   Internal skid FIFO (BSV postBramQ <- mkFIFOF). Write side = stage-2 skid
   --   enqueue (fire2 / bramQFirst); read side = downstream pipeOut dequeue.
   ---------------------------------------------------------------------------
   U_PostBramQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => DATA_W_G,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoRst,
         wr_clk        => clk,
         wr_en         => postBramQWrEn,
         din           => bramQFirst,   -- pass-through of bramQ head
         full          => open,
         not_full      => postBramQNotFull,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => postBramQRdEn,
         dout          => postBramQDout,
         valid         => postBramQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

end architecture rtl;
