-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: VHDL form of the Bluespec runtime enable-only register
-- primitive RegUN.v. WIDTH_G mirrors the Verilog "parameter width = 1".
-- RegUN.v declares no reset port at all, so this entity carries no reset
-- generic, no reset port, and no reset branch.
--
-- Uninitialized-storage decision: the internal storage signal below is
-- declared with no initial value, so GHDL leaves it undefined until the
-- first enabled write. RegUN.v's own simulation-only initial block (guarded
-- by a synthesis-off directive) sets Q_OUT to an alternating bit pattern
-- that exists only under Icarus, not something the Verilog synthesizes into
-- a bitstream. Because this primitive has no reset, that pattern is what
-- the recorded golden holds for every bit that has not yet been written.
-- Leaving this VHDL signal undefined makes the harness's own per-bit
-- masking remove exactly those pre-first-write bits from the comparison,
-- the mechanism built for precisely this case. The rejected alternative is
-- giving this signal the same alternating initial value: that would remove
-- the masked bits, but it would also put a power-on value into the
-- bitstream that the Verilog never synthesizes, so the translation would
-- diverge in hardware in order to make a simulation number look tidier.
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

entity RegUN is
   generic (
      WIDTH_G : positive := 1);
   port (
      CLK   : in  sl;
      EN    : in  sl;
      D_IN  : in  slv(WIDTH_G-1 downto 0);
      Q_OUT : out slv(WIDTH_G-1 downto 0));
end RegUN;

architecture rtl of RegUN is

   signal qOut : slv(WIDTH_G-1 downto 0);

begin

   process (CLK) is
   begin
      if rising_edge(CLK) then
         if (EN = '1') then
            qOut <= D_IN;
         end if;
      end if;
   end process;

   Q_OUT <= qOut;

end rtl;
