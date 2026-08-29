-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: VHDL form of the Bluespec runtime N-bit counter primitive
-- Counter.v. WIDTH_G mirrors the Verilog "parameter width = 1" and INIT_G
-- mirrors "parameter init". Reset is synchronous and active low, the same
-- convention as RegN.vhd: the Verilog's BSV_POSITIVE_RESET and
-- BSV_ASYNC_RESET macros are both undefined, so BSV_RESET_VALUE resolves to
-- 1'b0 and BSV_ARESET_EDGE_META expands to nothing, leaving a single
-- rising_edge(CLK) branch with no separate asynchronous reset edge.
--
-- Precedence, matching the Verilog always block exactly: the active-low
-- reset test comes first and loads INIT_G regardless of every other input.
-- In its else branch, the force-set test (SETF) comes first and loads
-- DATA_F unconditionally, with both adders ignored. Only in SETF's own else
-- branch is the sum computed: DATA_C when SETC is high, otherwise the
-- state's own previous value, plus DATA_A when ADDA is high (otherwise
-- zero), plus DATA_B when ADDB is high (otherwise zero).
--
-- Arithmetic: each of the three addends is an explicit ieee.numeric_std.all
-- unsigned conversion of a vector of exactly WIDTH_G bits, so the sum
-- returns exactly WIDTH_G bits and wraps by construction rather than
-- widening and truncating. This is deliberate rather than relying on an
-- implicit operator on a plain std_logic_vector: the GHDL flag set makes the
-- synopsys arithmetic packages visible alongside numeric_std, and an
-- implicit operator could resolve against the wrong package.
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

entity Counter is
   generic (
      WIDTH_G : positive := 1;
      INIT_G  : natural  := 0);
   port (
      CLK    : in  sl;
      RST    : in  sl;
      Q_OUT  : out slv(WIDTH_G-1 downto 0);
      DATA_A : in  slv(WIDTH_G-1 downto 0);
      ADDA   : in  sl;
      DATA_B : in  slv(WIDTH_G-1 downto 0);
      ADDB   : in  sl;
      DATA_C : in  slv(WIDTH_G-1 downto 0);
      SETC   : in  sl;
      DATA_F : in  slv(WIDTH_G-1 downto 0);
      SETF   : in  sl);
end Counter;

architecture rtl of Counter is

   signal qState : slv(WIDTH_G-1 downto 0);

begin

   Q_OUT <= qState;

   process (CLK) is
   begin
      if rising_edge(CLK) then
         if (RST = '0') then
            qState <= toSlv(INIT_G, WIDTH_G);
         elsif (SETF = '1') then
            qState <= DATA_F;
         else
            qState <= slv(
               unsigned(ite(SETC = '1', DATA_C, qState)) +
               unsigned(ite(ADDA = '1', DATA_A, slvZero(WIDTH_G))) +
               unsigned(ite(ADDB = '1', DATA_B, slvZero(WIDTH_G))));
         end if;
      end if;
   end process;

end rtl;
