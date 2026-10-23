-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: VHDL form of the Bluespec runtime depth-two queue primitive
-- FIFO2.v. WIDTH_G mirrors the Verilog "parameter width = 1". There is no
-- guard generic: FIFO2.v's "parameter guarded" is referenced only inside a
-- synthesis-off block that drives simulation warning messages
-- (FIFO2.v:130-151) and has no effect on any output port, so carrying it
-- here would imply a behavior it does not have.
--
-- Reset scope: reset touches only the two status signals (fullReg/emptyReg).
-- The data path (data0Reg/data1Reg) has no reset branch at all, because the
-- original's BSV_RESET_FIFO_HEAD macro is undefined and its data always
-- block therefore has no reset branch either (FIFO2.v:110-126). Both data
-- storage signals below are declared with no initial value, the same
-- uninitialized-storage decision RegUN.vhd records: GHDL leaves them
-- undefined until the first write that reaches them, and the harness's own
-- per-bit masking removes exactly that pre-first-write window from the
-- comparison, rather than giving them a simulation-only power-on value the
-- Verilog never synthesizes.
--
-- The status state machine's branch order is exactly the original's:
-- active-low reset, then clear, then enqueue-without-dequeue, then
-- dequeue-without-enqueue. A cycle with both an enqueue and a dequeue
-- asserted (and no clear) matches neither of the last two branches and
-- therefore leaves both status signals unchanged; this is the original's
-- documented behavior (FIFO2.v:95-104), not an oversight.
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

entity FIFO2 is
   generic (
      WIDTH_G : positive := 1);
   port (
      CLK     : in  sl;
      RST     : in  sl;
      D_IN    : in  slv(WIDTH_G-1 downto 0);
      ENQ     : in  sl;
      FULL_N  : out sl;
      D_OUT   : out slv(WIDTH_G-1 downto 0);
      DEQ     : in  sl;
      EMPTY_N : out sl;
      CLR     : in  sl);
end FIFO2;

architecture rtl of FIFO2 is

   signal fullReg  : sl;
   signal emptyReg : sl;
   signal data0Reg : slv(WIDTH_G-1 downto 0);
   signal data1Reg : slv(WIDTH_G-1 downto 0);

   -- Boolean load-select terms, transliterated term for term from the
   -- original's four continuous wire assignments (FIFO2.v:63-66). Each
   -- reads the current (pre-edge) values of fullReg/emptyReg, exactly like
   -- the Verilog wires read the current reg values before the clock edge.
   signal d0di : sl;
   signal d0d1 : sl;
   signal d0h  : sl;
   signal d1di : sl;

   -- Each select bit's replicated-bit mask, built with the shared
   -- all-bits-equal vector constructor, the direct equivalent of the
   -- original's {width{...}} replication.
   signal d0diMask : slv(WIDTH_G-1 downto 0);
   signal d0d1Mask : slv(WIDTH_G-1 downto 0);
   signal d0hMask  : slv(WIDTH_G-1 downto 0);

begin

   FULL_N  <= fullReg;
   EMPTY_N <= emptyReg;
   D_OUT   <= data0Reg;

   d0di <= (ENQ and (not emptyReg)) or (ENQ and DEQ and fullReg);
   d0d1 <= DEQ and (not fullReg);
   d0h  <= ((not DEQ) and (not ENQ)) or ((not DEQ) and emptyReg) or ((not ENQ) and fullReg);
   d1di <= ENQ and emptyReg;

   d0diMask <= slvAll(WIDTH_G, d0di);
   d0d1Mask <= slvAll(WIDTH_G, d0d1);
   d0hMask  <= slvAll(WIDTH_G, d0h);

   -- Status state machine (FIFO2.v:81-107): active-low reset first, then
   -- clear, then enqueue-without-dequeue, then dequeue-without-enqueue.
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
            -- documented behavior (FIFO2.v:95-104 has no combined-transfer
            -- branch), not an oversight, so no fifth branch should be added
            -- here to "handle" the simultaneous case.
         end if;
      end if;
   end process;

   -- Data path (FIFO2.v:110-126). No reset branch: the original's
   -- BSV_RESET_FIFO_HEAD macro is undefined, so its data always block has
   -- no reset branch at all, and both storage signals below are declared
   -- with no initial value for the same reason RegUN.vhd's storage signal
   -- is: GHDL leaves them undefined until the first write that reaches
   -- them, and the harness's own per-bit masking removes exactly that
   -- pre-first-write window from the comparison. Giving them a
   -- simulation-only power-on value would diverge from what the Verilog
   -- actually synthesizes.
   process (CLK) is
   begin
      if rising_edge(CLK) then
         data0Reg <= (d0diMask and D_IN) or (d0d1Mask and data1Reg) or (d0hMask and data0Reg);
         data1Reg <= D_IN when (d1di = '1') else data1Reg;
      end if;
   end process;

end rtl;
