-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AD9252 serialized pin-interface types
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

package Ad9252Pkg is

   -- One AD9252 bank has a shared differential DCO/FCO pair and eight
   -- differential serialized data lanes. Array index zero corresponds to ADC channel zero.
   type Ad9252SerialType is record
      fClkP : sl;                         -- Frame clock, positive input
      fClkN : sl;
      dClkP : sl;                         -- Data clock, positive input
      dClkN : sl;
      chP   : slv(7 downto 0);            -- Serialized data, positive inputs
      chN   : slv(7 downto 0);
   end record Ad9252SerialType;

   type Ad9252SerialArray is array (natural range <>) of Ad9252SerialType;

end package Ad9252Pkg;
