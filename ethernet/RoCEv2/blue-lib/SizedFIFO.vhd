-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: VHDL form of the Bluespec runtime depth-parameterized ring
-- queue primitive SizedFIFO.v. P1WIDTH_G/P2DEPTH_G/P3CNTR_WIDTH_G mirror the
-- Verilog "parameter p1width/p2depth/p3cntr_width". There is no guard
-- generic: SizedFIFO.v's "parameter guarded" is referenced only inside a
-- synthesis-off block that drives simulation warning messages
-- (SizedFIFO.v:211-232) and has no effect on any output port.
--
-- Implementation path: a hand-written direct translation, not the native
-- surf.Fifo wrapper originally attempted. That wrapper was built and
-- measured against the harness in full-scan mode at the larger real
-- production parameterization (633/32/5, 2048 cycles): 1324 of 2048
-- compared cycles differed (1377 mismatch events) across D_OUT, EMPTY_N,
-- and FULL_N, none of them maskable, since every mismatch was between two
-- fully defined values on both sides. Three distinct, unrelated causes: (1)
-- the power-on value -- the wrapper's native storage resets to a defined
-- zero while the original's simulation-only initial block sets an
-- alternating pattern, first diverging on D_OUT at cycle 0; (2) an
-- occupancy off-by-one -- the native FIFO reports full at whole-memory
-- occupancy while this primitive's ring holds one fewer entry than its
-- depth because the output register is an extra pipeline stage, first
-- diverging on FULL_N at cycle 209, one cycle before the golden's own first
-- full boundary; (3) an EMPTY_N read-latency mismatch that diverges
-- independently of any full-boundary event. Two further compromises the
-- wrapper needed and could not avoid: CLR had to be folded into the native
-- FIFO's only reset input, since it exposes no synchronous clear port at
-- all, and the native FIFO's address width had to be clamped to its own
-- hard minimum of 4, changing the entity's depth away from the Verilog's
-- own default. A hand-written direct translation is bit-exact by
-- construction, so it is the implementation landed here.
--
-- Reset scope: reset touches only the two pointers and the three status
-- bits (notFull/ringEmpty/hasOData). Neither the output register nor the
-- ring array is reset, because SizedFIFO.v tests BSV_RESET_FIFO_HEAD
-- (SizedFIFO.v:169) and BSV_RESET_FIFO_ARRAY (SizedFIFO.v:192), and neither
-- macro is defined anywhere in this repository, so both reset branches
-- compile out of the vendored Verilog and neither the output register nor
-- the ring array ever resets in hardware. This VHDL deliberately carries no
-- reset branch on either process for the same reason. The output register
-- and the ring array below are declared with no initial value, the same
-- uninitialized-storage decision RegUN.vhd and FIFO2.vhd record: GHDL
-- leaves them undefined until the first write that reaches them, and the
-- harness's own per-bit masking removes exactly that pre-first-write window
-- from the comparison, rather than giving them a simulation-only power-on
-- value the Verilog never synthesizes.
--
-- The pointer-and-status state machine's branch order is exactly the
-- original's ordered wildcard chain (SizedFIFO.v:120-162), first match
-- wins: active-low reset, then clear, then dequeue-and-enqueue with the
-- ring non-empty, then dequeue alone with the ring empty, then dequeue
-- alone with the ring non-empty, then enqueue alone with no output data,
-- then enqueue alone with output data present, with no final branch, so an
-- input combination matching none of the six leaves every pointer and
-- status bit unchanged. The output register's own chain reproduces the
-- original's four output-side patterns (SizedFIFO.v:177-185) in the same
-- order, also with no final branch so an unmatched combination holds. Both
-- are written as ordered elsif chains rather than an unordered case
-- statement, because the original resolves its wildcard patterns by first
-- match and an unordered selection statement is not an equivalent
-- construct.
--
-- There is no TPD_G here on purpose: this primitive is compared cycle by
-- cycle against its Verilog original, and any nonzero output delay would
-- shift the sampled value by a cycle and break bit-exactness by
-- construction.
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

entity SizedFIFO is
   generic (
      P1WIDTH_G      : positive := 1;
      P2DEPTH_G      : positive := 3;
      P3CNTR_WIDTH_G : positive := 1);
   port (
      CLK     : in  sl;
      RST     : in  sl;
      D_IN    : in  slv(P1WIDTH_G-1 downto 0);
      ENQ     : in  sl;
      FULL_N  : out sl;
      D_OUT   : out slv(P1WIDTH_G-1 downto 0);
      DEQ     : in  sl;
      EMPTY_N : out sl;
      CLR     : in  sl);
end SizedFIFO;

architecture rtl of SizedFIFO is

   -- Derived ring depth, the Verilog's own p2depth2 (SizedFIFO.v:41): the
   -- ring array and pointer wraparound cover depth-2 entries, since the
   -- output register supplies the extra stage ("model has output register
   -- which improves timing", SizedFIFO.v:34).
   constant P2DEPTH2_C   : natural := ite((P2DEPTH_G >= 2), P2DEPTH_G - 2, 0);
   -- The Verilog's own depthLess2 (SizedFIFO.v:71): p2depth2 truncated to
   -- the counter width, exactly the Verilog's own bit-slice
   -- p2depth2[p3cntr_width-1:0].
   constant DEPTH_LESS2_C : unsigned(P3CNTR_WIDTH_G-1 downto 0) := to_unsigned(P2DEPTH2_C, P3CNTR_WIDTH_G);

   type RingArrayType is array (0 to P2DEPTH2_C) of slv(P1WIDTH_G-1 downto 0);

   signal headPtr   : unsigned(P3CNTR_WIDTH_G-1 downto 0);
   signal tailPtr   : unsigned(P3CNTR_WIDTH_G-1 downto 0);
   signal nextHead  : unsigned(P3CNTR_WIDTH_G-1 downto 0);
   signal nextTail  : unsigned(P3CNTR_WIDTH_G-1 downto 0);

   signal notFull   : sl;
   signal ringEmpty : sl;
   signal hasOData  : sl;

   -- Uninitialized on purpose: see the header's reset-scope note. Neither
   -- signal below is ever reset, matching the vendored Verilog exactly.
   signal outReg  : slv(P1WIDTH_G-1 downto 0);
   signal ringArr : RingArrayType;

begin

   nextHead <= (others => '0') when (headPtr = DEPTH_LESS2_C) else headPtr + 1;
   nextTail <= (others => '0') when (tailPtr = DEPTH_LESS2_C) else tailPtr + 1;

   FULL_N  <= notFull;
   EMPTY_N <= hasOData;
   D_OUT   <= outReg;

   -- Pointer-and-status state machine (SizedFIFO.v:107-164): active-low
   -- reset first, then the ordered wildcard chain described in the header.
   process (CLK) is
   begin
      if rising_edge(CLK) then
         if (RST = '0') then
            headPtr   <= (others => '0');
            tailPtr   <= (others => '0');
            ringEmpty <= '1';
            notFull   <= '1';
            hasOData  <= '0';
         else
            if (CLR = '1') then
               -- Clear operation.
               headPtr   <= (others => '0');
               tailPtr   <= (others => '0');
               ringEmpty <= '1';
               notFull   <= '1';
               hasOData  <= '0';
            elsif (DEQ = '1' and ENQ = '1' and ringEmpty = '0') then
               -- DEQ && ENQ -- change head and tail if added to ring.
               tailPtr <= nextTail;
               headPtr <= nextHead;
            elsif (DEQ = '1' and ENQ = '0' and ringEmpty = '1') then
               -- DEQ only and no data is in ring.
               hasOData <= '0';
            elsif (DEQ = '1' and ENQ = '0' and ringEmpty = '0') then
               -- DEQ only and data is in ring (move the head pointer).
               headPtr   <= nextHead;
               notFull   <= '1';
               ringEmpty <= '1' when (nextHead = tailPtr) else '0';
            elsif (DEQ = '0' and ENQ = '1' and hasOData = '0') then
               -- ENQ only when empty.
               hasOData <= '1';
            elsif (DEQ = '0' and ENQ = '1' and hasOData = '1') then
               -- ENQ only when not empty.
               if (notFull = '1') then
                  tailPtr   <= nextTail;
                  ringEmpty <= '0';
                  notFull   <= '0' when (nextTail = headPtr) else '1';
               end if;
            end if;
            -- An input combination matching none of the six branches above
            -- (for example ENQ and DEQ both low, or DEQ and ENQ both high
            -- with the ring already empty) leaves every pointer and status
            -- bit unchanged, exactly as the original's casez with no
            -- default case.
         end if;
      end if;
   end process;

   -- Output register (SizedFIFO.v:167-187). No reset branch: see the
   -- header's reset-scope note.
   process (CLK) is
   begin
      if rising_edge(CLK) then
         if (CLR = '0' and DEQ = '1' and ENQ = '1' and ringEmpty = '0') then
            outReg <= ringArr(to_integer(headPtr));
         elsif (CLR = '0' and DEQ = '1' and ENQ = '1' and ringEmpty = '1') then
            outReg <= D_IN;
         elsif (CLR = '0' and DEQ = '1' and ENQ = '0' and ringEmpty = '0') then
            outReg <= ringArr(to_integer(headPtr));
         elsif (CLR = '0' and DEQ = '0' and ENQ = '1' and hasOData = '0') then
            outReg <= D_IN;
         end if;
         -- An unmatched combination, including CLR high, holds outReg.
      end if;
   end process;

   -- Ring array write (SizedFIFO.v:190-209). No reset branch: see the
   -- header's reset-scope note. A single condition, not a chain, exactly
   -- the original's.
   process (CLK) is
   begin
      if rising_edge(CLK) then
         if (CLR = '0' and ENQ = '1' and
             ((DEQ = '1' and ringEmpty = '0') or (DEQ = '0' and hasOData = '1' and notFull = '1'))) then
            ringArr(to_integer(tailPtr)) <= D_IN;
         end if;
      end if;
   end process;

end rtl;
