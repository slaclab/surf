-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper on Xilinx IOBUF
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

library unisim;
use unisim.vcomponents.all;

entity IoBufWrapper is
   generic (
      TPD_G : time := 1 ns);
   port (
      O  : out   sl;                    -- Buffer output
      IO : inout sl;  -- Buffer inout port (connect directly to top-level port)
      I  : in    sl;                    -- Buffer input
      T  : in    sl);  -- 3-state enable input, high=input, low=output
end IoBufWrapper;

architecture rtl of IoBufWrapper is

begin

   U_IOBUF : IOBUF
      port map (
         O  => O,
         IO => IO,
         I  => I,
         T  => T);

end rtl;
