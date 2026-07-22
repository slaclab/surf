-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Two-input PipeOut arbiter. A single BSV rule (binaryArbitrate,
--   (* fire_when_enabled *)) every cycle:
--     * picks a granted input (curGrantIdx),
--     * dequeues that input (pipeIn<idx>Rd),
--     * enqueues its payload into the output FIFO (U_OutQ),
--     * decides whether to re-arbitrate next cycle from the finish predicate.
--
--   The rule fires whenever the selected input is valid AND the output FIFO has
--   room (ruleFiresEn = selectedValid AND outQNotFull). All register updates of
--   the rule are one atomic comb block — never split across cycles.
--
--   Two architectural states, encoded by needArbitrationReg:
--     ARB_S  (needArbitrationReg='1') : pick a NEW grant this cycle
--                                       (curGrantIdx = shouldGrantPipeIn2),
--                                       updating grantReg/priorityReg.
--     PASS_S (needArbitrationReg='0') : continue on the current grantReg
--                                       (curGrantIdx = grantReg); grant/priority
--                                       held.
--   needArbitrationReg is loaded from the (selected) finish predicate every
--   firing cycle: '1' -> ARB_S next, '0' -> PASS_S next. Per the FSM spec this
--   is one `if ruleFiresEn then ... end if` block with the next-state selection
--   done by `v.needArbitrationReg := selectedFinished` — NOT separate branches
--   per next state.
--
--   shouldGrantPipeIn2 = (priorityReg AND pipeIn2Valid)
--                        OR (NOT pipeIn1Valid AND pipeIn2Valid)
--                      = pipeIn2Valid AND (priorityReg OR NOT pipeIn1Valid)
--   priorityReg flips to the loser each ARB cycle, giving alternating fairness;
--   reset priority is pipeIn1 ("initial grant to LSB", Arbitration.bsv:243).
--
--   OQ-FSM-17 (RESOLVED here) — isPipePayloadFinished function parameter:
--     BSV `isPipePayloadFinished(inputPayload)` is an elaboration-time function
--     argument applied to the SELECTED payload; VHDL has no function-type ports.
--     This is a generic, reusable 2-input leaf (instantiated 3x in BinaryArbTree
--     with possibly different request/response predicates), so the payload type
--     and its finish bit are unknown here. Resolution: expose the predicate as
--     PER-CHANNEL 1-bit combinational input ports (pipeIn1Finished,
--     pipeIn2Finished) computed by the parent (where the type is known) and
--     selected internally by the same curGrantIdx mux. Muxing the per-channel
--     predicate results == applying the predicate to the muxed payload (pure
--     function), so this is exactly faithful to the BSV. See RESOLVED.md.
--
--   OQ-FSM-ARBTREE-01 (RESOLVED here) — outFinished companion output:
--     When leaves feed a ROOT arbiter (BinaryArbTree), the root needs the finish
--     predicate of EACH leaf's OUTPUT head (predicate(U_LeftLeaf.outDout) /
--     predicate(U_RightLeaf.outDout)). The generic tree cannot recompute the
--     predicate (type/logic unknown at that level), and the parent can only wire
--     it if the leaf exports it. Resolution: carry the 1-bit finish predicate as
--     a companion THROUGH U_OutQ — the FIFO element is widened to
--     {finishedBit, payload}, the selected pipeIn<idx>Finished is enqueued
--     alongside the selected payload, and the FIFO head's stored finished bit is
--     exposed as the new `outFinished` output. Because isPipePayloadFinished is a
--     pure function of the payload, the head's stored bit == predicate(outDout),
--     so leaf->root wiring becomes a pure port connection (no predicate logic in
--     the tree). Exactly faithful to BSV; extends the OQ-FSM-17 argument to the
--     buffered head. `outFinished` is only meaningful while outNotEmpty='1'.
--
--   SURF components instantiated:
--     * U_OutQ : surf.Fifo  <- BSV pipeOutQ (mkFIFOF FIFOF#(anytype))
--       source: surf/base/fifo/rtl/Fifo.vhd
--     The FIFO read side (dout/valid/rd_en) is the entity's PipeOut output
--     interface (first/notEmpty/deq) — driven by the downstream consumer, not
--     by this FSM. FWFT_EN_G => true so `valid` = head-present = BSV notEmpty.
--     The FIFO element width is DATA_WIDTH_G+1: bit DATA_WIDTH_G is the finished
--     companion (outFinished), bits DATA_WIDTH_G-1..0 are the payload (outDout).
--     BSV mkFIFOF is depth 2; surf.Fifo minimum ADDR_WIDTH is 4 (depth 16).
--     Functionally a buffering FIFO; depth differs and there is an inherent
--     ~1-cycle write->valid read latency vs BSV mkFIFOF (surf.Fifo sync
--     write-ptr -> read-FSM handshake) — functionally equivalent, NOT
--     cycle-accurate. MEMORY_TYPE_G defaults to "distributed" (1-cycle read
--     branch); set "block" for wide payloads at the cost of a DOB_REG stage.
--
--   NOTE: emitting does not prove equivalence — simulate this entity (cocotb)
--   against the BSV behaviour before trusting it.
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

entity BinaryPipeOutArbiter is
   generic (
      TPD_G             : time                     := 1 ns;
      RST_POLARITY_G    : sl                       := '1';  -- '1' active HIGH reset, '0' active LOW
      RST_ASYNC_G       : boolean                  := false;
      DATA_WIDTH_G      : positive                 := 8;    -- payload width = tSz of BSV anytype
      MEMORY_TYPE_G     : string                   := "distributed";  -- output FIFO RAM style
      FIFO_ADDR_WIDTH_G : positive range 4 to 48   := 4);  -- output FIFO depth = 2**ADDR (BSV mkFIFOF depth 2; SURF min 4)
   port (
      clk             : in  sl;
      rst             : in  sl := not RST_POLARITY_G;
      -- pipeIn1 (PipeOut#) input, preferred at reset ("initial grant to LSB")
      pipeIn1Valid    : in  sl;                              -- pipeIn1.notEmpty
      pipeIn1Dout     : in  slv(DATA_WIDTH_G-1 downto 0);    -- pipeIn1.first
      pipeIn1Finished : in  sl;                              -- isPipePayloadFinished(pipeIn1.first) (OQ-FSM-17)
      pipeIn1Rd       : out sl;                              -- pipeIn1.deq strobe
      -- pipeIn2 (PipeOut#) input
      pipeIn2Valid    : in  sl;                              -- pipeIn2.notEmpty
      pipeIn2Dout     : in  slv(DATA_WIDTH_G-1 downto 0);    -- pipeIn2.first
      pipeIn2Finished : in  sl;                              -- isPipePayloadFinished(pipeIn2.first) (OQ-FSM-17)
      pipeIn2Rd       : out sl;                              -- pipeIn2.deq strobe
      -- PipeOut output interface (read side of U_OutQ; driven by downstream)
      outNotEmpty     : out sl;                              -- PipeOut.notEmpty (U_OutQ.valid)
      outDout         : out slv(DATA_WIDTH_G-1 downto 0);    -- PipeOut.first    (U_OutQ.dout payload)
      outFinished     : out sl;                              -- isPipePayloadFinished(outDout), buffered head bit (OQ-FSM-ARBTREE-01)
      outDeq          : in  sl);                             -- PipeOut.deq      (U_OutQ.rd_en)
end BinaryPipeOutArbiter;

architecture rtl of BinaryPipeOutArbiter is

   -- All registered state (BSV: three mkReg). The two architectural states
   -- ARB_S/PASS_S are encoded by needArbitrationReg; grantReg/priorityReg are
   -- auxiliary registers persisting across arbitration decisions.
   type RegType is record
      needArbitrationReg : sl;            -- '1'=ARB_S (re-arbitrate), '0'=PASS_S
      priorityReg        : sl;            -- '0'=pipeIn1 preferred, '1'=pipeIn2
      grantReg           : sl;            -- last grant: '0'=pipeIn1, '1'=pipeIn2
   end record RegType;

   constant REG_INIT_C : RegType := (
      needArbitrationReg => '1',          -- BSV mkReg(True)  -> start in ARB_S
      priorityReg        => '0',          -- BSV mkReg(False) -> pipeIn1 preferred
      grantReg           => '0');         -- BSV mkReg(False) -> default to pipeIn1

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- U_OutQ element width = payload + 1-bit finished companion (OQ-FSM-ARBTREE-01).
   -- Layout: bit DATA_WIDTH_G = finished, bits DATA_WIDTH_G-1..0 = payload.
   constant FIFO_WIDTH_C : positive := DATA_WIDTH_G + 1;

   -- U_OutQ (surf.Fifo) handshake/status
   signal outQNotFull : sl;               -- not_full  : back-pressure (room to enqueue)
   signal outQValid   : sl;               -- valid     : head present  (= PipeOut.notEmpty)
   signal outQDout    : slv(FIFO_WIDTH_C-1 downto 0);  -- dout  {finished, payload}
   signal outQWrEn    : sl;               -- wr_en     : enqueue strobe (Mealy, comb)
   signal outQDin     : slv(FIFO_WIDTH_C-1 downto 0);  -- din   {selectedFinished, selectedData} (comb)

begin

   --------------------------------------------------------------------------
   -- BSV pipeOutQ (mkFIFOF FIFOF#(anytype)) -> surf.Fifo
   --   Write side driven by the FSM (outQWrEn/outQDin). Read side is the
   --   entity's PipeOut output interface, driven by the downstream consumer
   --   (outDeq). FWFT: valid = head-present = BSV notEmpty.
   --------------------------------------------------------------------------
   U_OutQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         GEN_SYNC_FIFO_G => true,         -- single clock (wr_clk = rd_clk)
         FWFT_EN_G       => true,         -- valid = head present = BSV notEmpty
         MEMORY_TYPE_G   => MEMORY_TYPE_G,
         DATA_WIDTH_G    => FIFO_WIDTH_C,     -- payload + finished companion bit
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G)
      port map (
         rst      => rst,
         wr_clk   => clk,
         wr_en    => outQWrEn,
         din      => outQDin,
         not_full => outQNotFull,
         rd_clk   => clk,
         rd_en    => outDeq,
         dout     => outQDout,
         valid    => outQValid);

   -- PipeOut output interface (downstream reads U_OutQ directly). The head word
   -- unpacks into {finished, payload} (OQ-FSM-ARBTREE-01).
   outNotEmpty <= outQValid;
   outDout     <= outQDout(DATA_WIDTH_G-1 downto 0);
   outFinished <= outQDout(DATA_WIDTH_G);

   --------------------------------------------------------------------------
   -- Combinatorial : single rule binaryArbitrate (one atomic action block).
   --   See BinaryPipeOutArbiter.fsm.md transition table.
   --------------------------------------------------------------------------
   comb : process (r, rst, pipeIn1Valid, pipeIn1Dout, pipeIn1Finished,
                   pipeIn2Valid, pipeIn2Dout, pipeIn2Finished, outQNotFull) is
      variable v                  : RegType;
      variable shouldGrantPipeIn2 : sl;
      variable curGrantIdx        : sl;
      variable selectedData       : slv(DATA_WIDTH_G-1 downto 0);
      variable selectedValid      : sl;
      variable selectedFinished   : sl;
      variable ruleFiresEn        : sl;
   begin
      -- Latch the current state
      v := r;

      -- Default Mealy strobes (no rule firing). These are signals/ports, so
      -- driven with <= ; the last assignment in this process wins.
      outQWrEn  <= '0';
      outQDin   <= (others => '0');
      pipeIn1Rd <= '0';
      pipeIn2Rd <= '0';

      -- shouldGrantPipeIn2 = pipeIn2Valid AND (priorityReg OR NOT pipeIn1Valid)
      shouldGrantPipeIn2 := (r.priorityReg and pipeIn2Valid) or
                            ((not pipeIn1Valid) and pipeIn2Valid);

      -- Current grant index: re-arbitrated in ARB_S, held in PASS_S.
      if (r.needArbitrationReg = '1') then    -- ARB_S
         curGrantIdx := shouldGrantPipeIn2;
      else                                    -- PASS_S
         curGrantIdx := r.grantReg;
      end if;

      -- Mux the selected input channel by curGrantIdx. Selecting the finish
      -- predicate per channel == isPipePayloadFinished(selectedData) (OQ-FSM-17).
      if (curGrantIdx = '0') then
         selectedData     := pipeIn1Dout;
         selectedValid    := pipeIn1Valid;
         selectedFinished := pipeIn1Finished;
      else
         selectedData     := pipeIn2Dout;
         selectedValid    := pipeIn2Valid;
         selectedFinished := pipeIn2Finished;
      end if;

      -- Implicit rule condition: selected input valid AND output FIFO has room.
      ruleFiresEn := selectedValid and outQNotFull;

      -- Atomic rule body (single block; next-state from selectedFinished).
      if (ruleFiresEn = '1') then
         -- ARB_S re-arbitration updates the auxiliary grant/priority registers;
         -- PASS_S holds them (BSV: grant/priority written only under needArbitration).
         if (r.needArbitrationReg = '1') then
            v.grantReg    := shouldGrantPipeIn2;
            v.priorityReg := not shouldGrantPipeIn2;
         end if;

         -- Next-state select: '1' -> ARB_S, '0' -> PASS_S
         v.needArbitrationReg := selectedFinished;

         -- Enqueue selected payload + its finished companion, and dequeue the
         -- granted input. Storing selectedFinished with the payload lets the
         -- FIFO head expose outFinished == predicate(outDout) (OQ-FSM-ARBTREE-01).
         outQWrEn  <= '1';
         outQDin   <= selectedFinished & selectedData;
         pipeIn1Rd <= not curGrantIdx;        -- '1' when curGrantIdx = '0'
         pipeIn2Rd <= curGrantIdx;            -- '1' when curGrantIdx = '1'
      end if;

      -- Synchronous Reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;
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
