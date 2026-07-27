-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Purely structural wrapper — this entity owns NO state, NO rules, and NO
--   SURF instances directly (mapping.json: rule_count=0, state_registers=[],
--   surf_instances=[]). Per the FSM spec, mkPipeOutArbiter is a 1:1 passthrough:
--   it instantiates mkLeafBinaryPipeOutArbiterVec + mkBinaryPipeOutArbiterTree,
--   which are exactly the pair collapsed into the BinaryArbTree entity
--   (out/03-fsm/BinaryArbTree.fsm.md / out/04-vhdl/BinaryArbTree.vhd). This
--   entity therefore instantiates a single BinaryArbTree (U_Tree) and re-exposes
--   its ports unchanged. The sole rule in the BSV source (`rule debug`,
--   lines 379-395) is commented out and carries no behavior, so nothing is
--   dropped by omitting it.
--
--   OQ-FSM-PERMARB-01 (supersedes the OQ-HIER-01 fixed unroll): generic
--   PORT_COUNT_G (any power of 2, >= 1; 1 = passthrough per the BSV base case
--   Arbitration.bsv:317-319, GEN_BYPASS) forwarded to U_Tree unchanged; the
--   power-of-2 assert and the bit-reverse leaf permutation live inside
--   BinaryArbTree. Concrete BSV uses span PORT_COUNT_G = 8 (dataStreamArb over
--   qpDataStreamPipeOutVec, and the three ClientArbiter specializations at
--   2*MAX_QP) and PORT_COUNT_G = 4 (rqWcArb/sqWcArb WorkComp arbiters at
--   MAX_QP). Ports are vectored/flattened to match BinaryArbTree: input k's
--   payload is inDout((k+1)*DATA_WIDTH_G-1 downto k*DATA_WIDTH_G).
--
--   outFinished: forwarded 1:1 from U_Tree (OQ-FSM-ARBTREE-01 companion) so
--   downstream consumers (ServerArbiter, DmaArbiter4Qp, TransportLayer) that
--   need the finish predicate can wire it directly.
--
--   SURF components instantiated: NONE directly. All arbitration and the
--   surf.Fifo (U_OutQ) instances live inside U_Tree's BinaryPipeOutArbiter
--   children — see out/04-vhdl/BinaryArbTree.vhd / BinaryPipeOutArbiter.vhd.
--
--   NOTE: emitting does not prove equivalence — simulate this entity against
--   the BSV behaviour before trusting it, even though it is pure wiring:
--   a testbench still needs to confirm no port got swapped/mis-mapped.
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

entity PipeOutArbiter is
   generic (
      TPD_G             : time                   := 1 ns;
      RST_POLARITY_G    : sl                     := '1';  -- '1' active HIGH reset, '0' active LOW
      RST_ASYNC_G       : boolean                := false;
      PORT_COUNT_G      : positive               := 8;  -- number of PipeOut inputs; any power of 2, >= 1 (1 = passthrough, Arbitration.bsv:317) (OQ-FSM-PERMARB-01)
      DATA_WIDTH_G      : positive               := 8;  -- payload width = tSz of BSV anytype
      MEMORY_TYPE_G     : string                 := "distributed";  -- child output FIFO RAM style
      FIFO_ADDR_WIDTH_G : positive range 4 to 48 := 4);  -- child output FIFO depth = 2**ADDR
   port (
      clk         : in  sl;
      rst         : in  sl := not RST_POLARITY_G;
      -- PORT_COUNT_G upstream PipeOut inputs, forwarded 1:1 to U_Tree;
      -- input k's payload is inDout((k+1)*DATA_WIDTH_G-1 downto k*DATA_WIDTH_G)
      inValid     : in  slv(PORT_COUNT_G-1 downto 0);  -- in(k).notEmpty
      inDout      : in  slv(PORT_COUNT_G*DATA_WIDTH_G-1 downto 0);  -- in(k).first, flattened
      inFinished  : in  slv(PORT_COUNT_G-1 downto 0);  -- isPipePayloadFinished(in(k).first)
      inRd        : out slv(PORT_COUNT_G-1 downto 0);  -- in(k).deq strobe
      -- tree PipeOut output, forwarded 1:1 from U_Tree
      outNotEmpty : out sl;             -- tree PipeOut.notEmpty
      outDout     : out slv(DATA_WIDTH_G-1 downto 0);  -- tree PipeOut.first
      outFinished : out sl;   -- tree head finish predicate (see note above)
      outDeq      : in  sl);            -- external dequeue of the tree output
end entity PipeOutArbiter;

architecture struct of PipeOutArbiter is

begin

   --------------------------------------------------------------------------
   -- GEN_BYPASS : PORT_COUNT_G = 1 — BSV base case (Arbitration.bsv:317-319,
   --              mkBinaryPipeOutArbiterTree returns inputPipeOutVec[0]):
   --              a 1-port arbiter is a pure passthrough, zero logic.
   --------------------------------------------------------------------------
   GEN_BYPASS : if PORT_COUNT_G = 1 generate
      outNotEmpty <= inValid(0);
      outDout     <= inDout;            -- widths identical at PORT_COUNT_G=1
      outFinished <= inFinished(0);
      inRd(0)     <= outDeq;
   end generate GEN_BYPASS;

   --------------------------------------------------------------------------
   -- GEN_TREE : PORT_COUNT_G > 1 —
   -- U_Tree : mkLeafBinaryPipeOutArbiterVec + mkBinaryPipeOutArbiterTree,
   --          collapsed into BinaryArbTree — every port forwarded unchanged.
   --------------------------------------------------------------------------
   GEN_TREE : if PORT_COUNT_G > 1 generate
      U_Tree : entity surf.BinaryArbTree
         generic map (
            TPD_G             => TPD_G,
            RST_POLARITY_G    => RST_POLARITY_G,
            RST_ASYNC_G       => RST_ASYNC_G,
            PORT_COUNT_G      => PORT_COUNT_G,
            DATA_WIDTH_G      => DATA_WIDTH_G,
            MEMORY_TYPE_G     => MEMORY_TYPE_G,
            FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G)
         port map (
            clk         => clk,
            rst         => rst,
            inValid     => inValid,
            inDout      => inDout,
            inFinished  => inFinished,
            inRd        => inRd,
            outNotEmpty => outNotEmpty,
            outDout     => outDout,
            outFinished => outFinished,
            outDeq      => outDeq);
   end generate GEN_TREE;

end architecture struct;
