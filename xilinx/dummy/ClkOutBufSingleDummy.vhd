-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Special buffer for outputting a clock on Xilinx FPGA pins.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

library surf;
use surf.StdRtlPkg.all;

entity ClkOutBufSingle is
   generic (
      TPD_G          : time    := 1 ns;
      XIL_DEVICE_G   : string  := "7SERIES";  -- Either "7SERIES" or "ULTRASCALE" or "ULTRASCALE_PLUS"
      RST_POLARITY_G : sl      := '1';
      INVERT_G       : boolean := false);
   port (
      rstIn  : in  sl := not RST_POLARITY_G;  -- Optional reset
      outEnL : in  sl := '0';  -- optional tristate (0 = enabled, 1 = high z output)
      clkIn  : in  sl := '0';
      clkOut : out sl := '0');          -- Single ended output buffer
end ClkOutBufSingle;

architecture mapping of ClkOutBufSingle is

begin

   assert (false)
      report "surf.xilinx: ClkOutBufSingle not supported" severity failure;

end mapping;
