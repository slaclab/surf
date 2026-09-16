-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: VHDL form of the Bluespec runtime single-register primitive
-- RegN.v. WIDTH_G mirrors the Verilog "parameter width = 1" and INIT_G
-- mirrors "parameter init". Reset is synchronous and active low: the
-- Verilog's BSV_POSITIVE_RESET and BSV_ASYNC_RESET macros are both
-- undefined, so BSV_RESET_VALUE resolves to 1'b0 and BSV_ARESET_EDGE_META
-- expands to nothing, leaving a single rising_edge(CLK) branch with no
-- separate asynchronous reset edge. There is no TPD_G here on purpose: this
-- primitive is compared cycle by cycle against its Verilog original, and any
-- nonzero output delay would shift the sampled value by a cycle and break
-- bit-exactness by construction.
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

entity RegN is
   generic (
      WIDTH_G : positive := 1;
      INIT_G  : natural  := 0);
   port (
      CLK   : in  sl;
      RST   : in  sl;
      EN    : in  sl;
      D_IN  : in  slv(WIDTH_G-1 downto 0);
      Q_OUT : out slv(WIDTH_G-1 downto 0));
end RegN;

architecture rtl of RegN is

   signal qOut : slv(WIDTH_G-1 downto 0);

begin

   process (CLK) is
   begin
      if rising_edge(CLK) then
         if (RST = '0') then
            qOut <= toSlv(INIT_G, WIDTH_G);
         elsif (EN = '1') then
            qOut <= D_IN;
         end if;
      end if;
   end process;

   Q_OUT <= qOut;

end rtl;
