-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: VHDL form of the Bluespec runtime zero-data-width depth-two
-- queue primitive FIFO20.v. This is the zero-data-width variant of FIFO2:
-- it carries no data path, no data ports, and no generic clause at all.
-- FIFO20.v's only parameter, "parameter guarded", is never read outside a
-- synthesis-off block (FIFO20.v:87-108), the same reason FIFO2 carries no
-- guard generic either, so declaring no generic clause here is the correct
-- translation of a module with no functional parameter.
--
-- Ports are declared in the original module header's own order (CLK, RST,
-- ENQ, FULL_N, DEQ, EMPTY_N, CLR), which differs from the order the
-- original's body declares them in; the header order is the one the
-- harness's port table follows.
--
-- The status state machine is identical to FIFO2.vhd's sibling machine,
-- minus the data path: active-low reset first, then clear, then
-- enqueue-without-dequeue, then dequeue-without-enqueue, in that order. A
-- cycle with both an enqueue and a dequeue asserted (and no clear) matches
-- neither of the last two branches and therefore leaves both status
-- signals unchanged; this is the original's documented behavior
-- (FIFO20.v:74-83), not an oversight.
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

library surf;
use surf.StdRtlPkg.all;

entity FIFO20 is
   port (
      CLK     : in  sl;
      RST     : in  sl;
      ENQ     : in  sl;
      FULL_N  : out sl;
      DEQ     : in  sl;
      EMPTY_N : out sl;
      CLR     : in  sl);
end FIFO20;

architecture rtl of FIFO20 is

   signal fullReg  : sl;
   signal emptyReg : sl;

begin

   FULL_N  <= fullReg;
   EMPTY_N <= emptyReg;

   -- Status state machine (FIFO20.v:60-85): active-low reset first, then
   -- clear, then enqueue-without-dequeue, then dequeue-without-enqueue.
   -- There is no data process and no select term here, because there is no
   -- data.
   process (CLK) is
   begin
      if rising_edge(CLK) then
         if (RST = '0') then
            emptyReg <= '0';
            fullReg  <= '1';
         else
            if (CLR = '1') then
               emptyReg <= '0';
               fullReg  <= '1';
            elsif (ENQ = '1' and DEQ = '0') then
               emptyReg <= '1';
               fullReg  <= not emptyReg;
            elsif (DEQ = '1' and ENQ = '0') then
               fullReg  <= '1';
               emptyReg <= not fullReg;
            end if;
            -- A cycle with both ENQ and DEQ high (and no CLR) matches
            -- neither of the two branches above and therefore leaves
            -- fullReg and emptyReg unchanged; this is the original's
            -- documented behavior, not an oversight, so no fifth branch
            -- should be added here to "handle" the simultaneous case.
         end if;
      end if;
   end process;

end rtl;
