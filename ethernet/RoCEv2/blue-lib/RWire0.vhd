-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: VHDL form of the Bluespec runtime parameter-free single-bit
-- passthrough primitive RWire0.v. There is no generic clause, since the
-- Verilog original takes no parameter, and no TPD_G on purpose: this
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

entity RWire0 is
   port (
      WSET : in  sl;
      WHAS : out sl);
end RWire0;

architecture rtl of RWire0 is

begin

   WHAS <= WSET;

end rtl;
