-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: VHDL form of the Bluespec runtime combinational passthrough
-- primitive BypassWire.v. WIDTH_G mirrors the Verilog "parameter width = 1".
-- There is no TPD_G here on purpose: this primitive is compared cycle by
-- cycle against its Verilog original, and any nonzero output delay would
-- shift the sampled value by a cycle and break bit-exactness by construction.
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

entity BypassWire is
   generic (
      WIDTH_G : positive := 1);
   port (
      WVAL : in  slv(WIDTH_G-1 downto 0);
      WGET : out slv(WIDTH_G-1 downto 0));
end BypassWire;

architecture rtl of BypassWire is

begin

   WGET <= WVAL;

end rtl;
