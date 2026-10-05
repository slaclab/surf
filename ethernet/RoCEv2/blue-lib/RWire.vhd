-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: VHDL form of the Bluespec runtime parameterized wire primitive
-- RWire.v. WIDTH_G mirrors the Verilog "parameter width = 1". This entity is
-- the literal union of BypassWire.vhd's data path (WVAL/WGET) and
-- RWire0.vhd's valid bit (WSET/WHAS): both outputs are continuous
-- assignments of their respective inputs, so the same-cycle data and valid
-- semantics are trivial by construction. There is no TPD_G here on purpose:
-- this primitive is compared cycle by cycle against its Verilog original,
-- and any nonzero output delay would shift the sampled value by a cycle and
-- break bit-exactness by construction.
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

entity RWire is
   generic (
      WIDTH_G : positive := 1);
   port (
      WGET : out slv(WIDTH_G-1 downto 0);
      WHAS : out sl;
      WVAL : in  slv(WIDTH_G-1 downto 0);
      WSET : in  sl);
end RWire;

architecture rtl of RWire is

begin

   WGET <= WVAL;
   WHAS <= WSET;

end rtl;
