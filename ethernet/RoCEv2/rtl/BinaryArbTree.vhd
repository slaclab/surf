-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Purely structural netlist — this entity owns NO state, NO rules, and NO
--   SURF instances directly (mapping.json: rule_count=0, state_registers=[],
--   surf_instances=[]). No RegType/comb/seq two-process pair is emitted; per
--   the FSM spec this level is nothing but wiring between PORT_COUNT_G PipeOut
--   inputs, PORT_COUNT_G-1 BinaryPipeOutArbiter child instances, and 1 PipeOut
--   output. All arbitration behaviour lives in the child entity
--   (out/03-fsm/BinaryPipeOutArbiter.fsm.md / out/04-vhdl/BinaryPipeOutArbiter.vhd).
--
--   OQ-FSM-PERMARB-01 (supersedes the OQ-HIER-01 fixed unroll): emitted GENERIC
--   over PORT_COUNT_G (any power of 2, >= 2). The tree and the leaf permutation
--   are built in generate statements:
--     * level 0 (leaves, PORT_COUNT_G/2 arbiters) pairs the physical inputs in
--       FFT bit-reverse order, per mkLeafBinaryPipeOutArbiterVec: leaf j takes
--       inputs bitRev(2j) / bitRev(2j+1), reversal over log2(PORT_COUNT_G) bits.
--       This permutation is DIFFERENT at each PORT_COUNT_G (e.g. 8 -> leaves
--       (0,4)(2,6)(1,5)(3,7); 4 -> (0,2)(1,3); 2 -> (0,1)), which is why a
--       fixed unroll cannot serve the mixed portSz=8 (ClientArbiter
--       specializations, dataStreamArb) and portSz=4 (WorkComp arbiters) uses.
--     * levels 1..log2(PORT_COUNT_G)-1 pair the previous level's outputs in
--       LINEAR order (idx, idx+1), per mkBinaryPipeOutArbiterTree's recursion.
--   Total: PORT_COUNT_G-1 arbiters in log2(PORT_COUNT_G) levels; the single
--   level-(depth-1) node is the tree apex driving the output PipeOut.
--   PORT_COUNT_G=2 degenerates to a single arbiter (matches the BSV portSz==1
--   recursion base case returning the lone leaf unchanged).
--
--   Ports are vectored/flattened (interface CHANGED vs the pre-2026-07-03
--   fixed-4 emit): valid/finished/rd are slv(PORT_COUNT_G-1 downto 0); dout is
--   slv(PORT_COUNT_G*DATA_WIDTH_G-1 downto 0) with input k occupying bits
--   ((k+1)*DATA_WIDTH_G-1 downto k*DATA_WIDTH_G).
--
--   OQ-FSM-ARBTREE-01 (RESOLVED, 2026-07-01): the child BinaryPipeOutArbiter
--   exposes an `outFinished` output (buffered head's finish predicate,
--   companion-carried through its U_OutQ FIFO), so inter-level `Finished`
--   wiring is a pure port connection — no predicate logic in this entity.
--
--   SURF components instantiated: NONE directly. Each child arbiter
--   instantiates its own surf.Fifo (U_OutQ) internally — see
--   out/04-vhdl/BinaryPipeOutArbiter.vhd.
--
--   NOTE: emitting does not prove equivalence — simulate this entity against
--   the BSV behaviour before trusting it. The child BinaryPipeOutArbiter must
--   pass its own Stage-5 verification before this tree's result can be trusted.
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

entity BinaryArbTree is
   generic (
      TPD_G             : time                   := 1 ns;
      RST_POLARITY_G    : sl                     := '1';  -- '1' active HIGH reset, '0' active LOW
      RST_ASYNC_G       : boolean                := false;
      PORT_COUNT_G      : positive               := 8;    -- number of tree inputs; any power of 2, >= 2 (OQ-FSM-PERMARB-01)
      DATA_WIDTH_G      : positive               := 8;    -- payload width = tSz of BSV anytype
      MEMORY_TYPE_G     : string                 := "distributed";  -- child output FIFO RAM style
      FIFO_ADDR_WIDTH_G : positive range 4 to 48 := 4);    -- child output FIFO depth = 2**ADDR
   port (
      clk         : in  sl;
      rst         : in  sl := not RST_POLARITY_G;
      -- PORT_COUNT_G upstream PipeOut inputs (tree leaves, bit-reverse paired);
      -- input k's payload is inDout((k+1)*DATA_WIDTH_G-1 downto k*DATA_WIDTH_G)
      inValid     : in  slv(PORT_COUNT_G-1 downto 0);               -- in(k).notEmpty
      inDout      : in  slv(PORT_COUNT_G*DATA_WIDTH_G-1 downto 0);  -- in(k).first, flattened
      inFinished  : in  slv(PORT_COUNT_G-1 downto 0);               -- isPipePayloadFinished(in(k).first), OQ-FSM-17
      inRd        : out slv(PORT_COUNT_G-1 downto 0);               -- in(k).deq strobe
      -- tree PipeOut output
      outNotEmpty : out sl;                                         -- tree PipeOut.notEmpty (apex outNotEmpty)
      outDout     : out slv(DATA_WIDTH_G-1 downto 0);               -- tree PipeOut.first    (apex outDout)
      outFinished : out sl;                                         -- tree head finish predicate (apex outFinished)
      outDeq      : in  sl);                                        -- external dequeue of the tree output
end entity BinaryArbTree;

architecture struct of BinaryArbTree is

   constant DEPTH_C      : natural := log2(PORT_COUNT_G);  -- tree levels
   constant NODE_COUNT_C : natural := PORT_COUNT_G-1;      -- total arbiters
   constant APEX_C       : natural := NODE_COUNT_C-1;      -- global index of the root node

   -- Global node numbering, level-major: level 0 (leaves) has PORT_COUNT_G/2
   -- nodes at indices 0..PORT_COUNT_G/2-1, level L has PORT_COUNT_G/2**(L+1)
   -- nodes starting at nodeBaseIdx(L); the single level-(DEPTH_C-1) node is
   -- the apex (index APEX_C).
   function nodeBaseIdx (lvl : natural) return natural is
   begin
      return PORT_COUNT_G - (PORT_COUNT_G/(2**lvl));
   end function nodeBaseIdx;

   -- FFT bit-reverse of a leaf input index over DEPTH_C bits
   -- (mkLeafBinaryPipeOutArbiterVec: reverseBits on Bit#(TLog#(portSz))).
   function bitRevIdx (idx : natural) return natural is
      variable ret : natural := 0;
      variable tmp : natural := idx;
   begin
      for i in 0 to DEPTH_C-1 loop
         ret := (ret*2) + (tmp mod 2);
         tmp := tmp/2;
      end loop;
      return ret;
   end function bitRevIdx;

   type DoutArrayType is array (natural range <>) of slv(DATA_WIDTH_G-1 downto 0);

   -- Per-node output PipeOut nets (node index = global numbering above).
   -- Forward: notEmpty/dout/finished driven by the node's arbiter instance.
   -- Backward: deq driven by the parent node (or by outDeq for the apex).
   signal nodeNotEmpty : slv(NODE_COUNT_C-1 downto 0);
   signal nodeDout     : DoutArrayType(NODE_COUNT_C-1 downto 0);
   signal nodeFinished : slv(NODE_COUNT_C-1 downto 0);
   signal nodeDeq      : slv(NODE_COUNT_C-1 downto 0);

begin

   -- Generic generate-tree is only defined for power-of-2 port counts
   -- (BSV proviso Add#(TLog#(portSz), 1, TLog#(TAdd#(1, portSz)))).
   assert isPowerOf2(PORT_COUNT_G) and (PORT_COUNT_G >= 2)
      report "BinaryArbTree: PORT_COUNT_G must be a power of 2 and >= 2 " &
             "(BSV power-of-2 proviso; OQ-FSM-PERMARB-01)"
      severity failure;

   --------------------------------------------------------------------------
   -- Level 0 — leaves: PORT_COUNT_G/2 arbiters, FFT bit-reverse input pairing
   -- (leaf j = arb(in(bitRev(2j)), in(bitRev(2j+1))), per
   -- mkLeafBinaryPipeOutArbiterVec).
   --------------------------------------------------------------------------
   GEN_LEAF : for node in 0 to (PORT_COUNT_G/2)-1 generate
      constant LEFT_C  : natural := bitRevIdx(2*node);
      constant RIGHT_C : natural := bitRevIdx((2*node)+1);
   begin
      U_Arb : entity surf.BinaryPipeOutArbiter
         generic map (
            TPD_G             => TPD_G,
            RST_POLARITY_G    => RST_POLARITY_G,
            RST_ASYNC_G       => RST_ASYNC_G,
            DATA_WIDTH_G      => DATA_WIDTH_G,
            MEMORY_TYPE_G     => MEMORY_TYPE_G,
            FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G)
         port map (
            clk             => clk,
            rst             => rst,
            pipeIn1Valid    => inValid(LEFT_C),
            pipeIn1Dout     => inDout((LEFT_C+1)*DATA_WIDTH_G-1 downto LEFT_C*DATA_WIDTH_G),
            pipeIn1Finished => inFinished(LEFT_C),
            pipeIn1Rd       => inRd(LEFT_C),
            pipeIn2Valid    => inValid(RIGHT_C),
            pipeIn2Dout     => inDout((RIGHT_C+1)*DATA_WIDTH_G-1 downto RIGHT_C*DATA_WIDTH_G),
            pipeIn2Finished => inFinished(RIGHT_C),
            pipeIn2Rd       => inRd(RIGHT_C),
            outNotEmpty     => nodeNotEmpty(node),
            outDout         => nodeDout(node),
            outFinished     => nodeFinished(node),
            outDeq          => nodeDeq(node));
   end generate GEN_LEAF;

   --------------------------------------------------------------------------
   -- Levels 1..DEPTH_C-1 — linear pairing of the previous level's outputs
   -- (mkBinaryPipeOutArbiterTree recursion: arb(prev(2j), prev(2j+1))).
   -- Inter-level Finished wiring is a pure port connection to the children's
   -- outFinished (OQ-FSM-ARBTREE-01 resolved).
   --------------------------------------------------------------------------
   GEN_LVL : for lvl in 1 to DEPTH_C-1 generate
   begin
      GEN_NODE : for node in 0 to (PORT_COUNT_G/(2**(lvl+1)))-1 generate
         constant NODE_C : natural := nodeBaseIdx(lvl) + node;
         constant CH1_C  : natural := nodeBaseIdx(lvl-1) + (2*node);
         constant CH2_C  : natural := nodeBaseIdx(lvl-1) + (2*node) + 1;
      begin
         U_Arb : entity surf.BinaryPipeOutArbiter
            generic map (
               TPD_G             => TPD_G,
               RST_POLARITY_G    => RST_POLARITY_G,
               RST_ASYNC_G       => RST_ASYNC_G,
               DATA_WIDTH_G      => DATA_WIDTH_G,
               MEMORY_TYPE_G     => MEMORY_TYPE_G,
               FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G)
            port map (
               clk             => clk,
               rst             => rst,
               pipeIn1Valid    => nodeNotEmpty(CH1_C),
               pipeIn1Dout     => nodeDout(CH1_C),
               pipeIn1Finished => nodeFinished(CH1_C),
               pipeIn1Rd       => nodeDeq(CH1_C),
               pipeIn2Valid    => nodeNotEmpty(CH2_C),
               pipeIn2Dout     => nodeDout(CH2_C),
               pipeIn2Finished => nodeFinished(CH2_C),
               pipeIn2Rd       => nodeDeq(CH2_C),
               outNotEmpty     => nodeNotEmpty(NODE_C),
               outDout         => nodeDout(NODE_C),
               outFinished     => nodeFinished(NODE_C),
               outDeq          => nodeDeq(NODE_C));
      end generate GEN_NODE;
   end generate GEN_LVL;

   --------------------------------------------------------------------------
   -- Tree apex — the last node's PipeOut is the tree output.
   --------------------------------------------------------------------------
   outNotEmpty       <= nodeNotEmpty(APEX_C);
   outDout           <= nodeDout(APEX_C);
   outFinished       <= nodeFinished(APEX_C);
   nodeDeq(APEX_C)   <= outDeq;

end architecture struct;
