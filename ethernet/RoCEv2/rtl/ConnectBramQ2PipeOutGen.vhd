-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Byte-for-byte twin of ConnectBramQ2PipeOutConAndGen (the two copies exist
--   only because mkConnectBramQ2PipeOut is defined once per BSV file; the bodies
--   are identical).  This entity mirrors that one; only the source/instantiation
--   line references and OQ ids differ (OQ-FSM-CBG-1/-2/-3 vs CB-1/-2/-3).
--
--   Skid / output-register stage.  Pulls fragments out of an upstream FIFO
--   (bramQ, a module argument — exposed here as a Get/dequeue handshake on
--   ports, NOT instantiated) into a small internal skid FIFO (postBramQ), and
--   re-exposes that internal FIFO as a PipeOut.
--
--   There is NO explicit state register and NO data-dependent control flow:
--   per the FSM spec (§State register / §Output style) the only "machine" is the
--   implicit mkConnection transfer rule, gated solely by the two FIFOs'
--   full/empty flags.  This entity is therefore emitted as a *pure structural
--   wrapper* — one surf.Fifo plus combinational glue — with NO two-process FSM
--   and NO RegType (the only registered storage lives inside U_PostBramQ).
--
--   BramPipe interface (3 live methods restored per OQ-FSM-CBG-2; mapping.json
--   listed only pipeOutPort):
--     pipeOut  : PipeOut#(DataStream)  -> first/deq/notEmpty handshake ports
--     clear()  : Action                -> clearEnI (synchronous flush of postBramQ)
--     notEmpty : Bool                  -> notEmpty output
--   (pipeOut->lines 2128/2631, clear->line 2148, notEmpty->line 2632.)
--
--   Two independent, conflict-free handshakes through the one FIFO:
--     * Upstream enqueue (mkConnection rl_connect, line 1971):
--         fire = bramQNotEmpty AND postBramQNotFull
--         -> bramQDeq, postBramQWrEn, postBramQDin = bramQDout
--     * Downstream dequeue (toPipeOut, line 1973):
--         postBramQRdEn = pipeOutDeq
--     They may both occur in the same cycle (opposite ends of a FIFO).
--
--   clear() mapping (OQ-FSM-CBG-3, resolved via OQ-FSM-01 in
--   out/03-fsm/RESOLVED.md):
--     surf.Fifo has no dedicated clear port; BSV postBramQ.clear is modelled by
--     asserting the Fifo rst, OR'd with the structural reset:
--         fifoRst <= rst or clearEnI
--     surf.FifoSync (GEN_SYNC_FIFO_G=true, RST_ASYNC_G=false, RST_POLARITY_G='1')
--     holds the FIFO logically empty for the whole asserted window (level-safe;
--     no pulse generator).  The upstream enqueue (bramQDeq / postBramQWrEn) is
--     SUPPRESSED while clearEnI='1' (fsm.md §Conflicts/scheduling) so a fragment
--     is not dequeued from the upstream bramQ only to be discarded by the flush.
--
--   Width (OQ-FSM-CBG-1 + project-wide OQ-FSM-H2DS-02, RESOLVED):
--     DataStream = data(256)+byteEn(32)+isFirst(1)+isLast(1) = 290 bits.
--     The FSM spec / mapping.json carry the stale inventory value 321; per the
--     OQ-FSM-H2DS-02 resolution ("apply consistently at emit") and OQ-FSM-CPG-1
--     ("backfill the siblings"), this entity uses DATA_W_G=290.
--
--   SURF components instantiated (source: surf/base/fifo/rtl/Fifo.vhd):
--     U_PostBramQ : surf.Fifo  DATA_WIDTH_G=290, FWFT, sync, distributed RAM
--                   (BSV postBramQ <- mkFIFOF).  ADDR_WIDTH_G=4 (surf.Fifo min;
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

entity ConnectBramQ2PipeOutGen is
   generic (
      TPD_G    : time     := 1 ns;
      DATA_W_G : positive := 290);      -- DataStream width (OQ-FSM-H2DS-02)
   port (
      clk             : in  sl;
      rst             : in  sl;         -- active-high sync reset
      -- clear() method (Action): synchronous flush of the internal skid FIFO
      clearEnI        : in  sl;
      -- Upstream bramQ : Get#(DataStream) handshake (bramQ is a module argument)
      bramQNotEmpty   : in  sl;         -- bramQ.notEmpty (first valid)
      bramQDout       : in  slv(DATA_W_G-1 downto 0);  -- bramQ.first
      bramQDeq        : out sl;         -- dequeue upstream bramQ
      -- pipeOut : PipeOut#(DataStream) (downstream consumer)
      pipeOutDeq      : in  sl;         -- consumer dequeues pipeOut
      pipeOutFirst    : out slv(DATA_W_G-1 downto 0);  -- pipeOut.first
      pipeOutNotEmpty : out sl;         -- pipeOut.notEmpty
      -- notEmpty() method result (parent payloadNotEmpty)
      notEmpty        : out sl);
end entity ConnectBramQ2PipeOutGen;

architecture rtl of ConnectBramQ2PipeOutGen is

   -- U_PostBramQ interface signals (DataStream, DATA_W_G bits)
   signal postBramQNotFull : sl;
   signal postBramQValid   : sl;        -- = postBramQ.notEmpty (FWFT)
   signal postBramQDout    : slv(DATA_W_G-1 downto 0);
   signal postBramQWrEn    : sl;
   signal postBramQRdEn    : sl;

   -- Upstream->skid enqueue fire condition (Mealy, gated against flush)
   signal enqFire : sl;

   -- FIFO reset line: level = rst OR clearEnI (BSV postBramQ.clear)
   signal fifoRst : sl;

begin

   -- FIFO clear (OQ-FSM-CBG-3 / OQ-FSM-01, RESOLVED): level-sensitive flush.
   fifoRst <= rst or clearEnI;

   -- Upstream enqueue handshake (mkConnection rl_connect): fire when the
   -- upstream has a fragment and the skid FIFO can accept it.  Suppressed during
   -- a clear flush so we do not dequeue bramQ into a FIFO being emptied.
   enqFire <= bramQNotEmpty and postBramQNotFull and (not clearEnI);

   bramQDeq      <= enqFire;            -- dequeue upstream bramQ (Get side)
   postBramQWrEn <= enqFire;            -- enqueue into skid FIFO

   -- Downstream dequeue handshake (toPipeOut): decoupled, every-cycle strobe.
   postBramQRdEn <= pipeOutDeq;

   -- pipeOut method wiring (pure combinational re-export of the skid FIFO front)
   pipeOutFirst    <= postBramQDout;
   pipeOutNotEmpty <= postBramQValid;

   -- notEmpty() method: upstream has data AND skid FIFO has data
   notEmpty <= bramQNotEmpty and postBramQValid;

   ---------------------------------------------------------------------------
   -- U_PostBramQ : surf.Fifo
   --   Internal skid FIFO (BSV postBramQ <- mkFIFOF).  Write side = upstream
   --   enqueue (enqFire / bramQDout); read side = downstream pipeOut dequeue.
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
         din           => bramQDout,    -- pass-through of upstream head
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
