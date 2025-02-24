-------------------------------------------------------------------------------
-- Title      : XVC Debug Bridge Support
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: VHDL Package for UDP Debug Bridge
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
use ieee.numeric_std.all;


library surf;
use surf.StdRtlPkg.all;
use surf.EthMacPkg.all;

-- Configuration constants (used for generics) for AxisJtagDebugBridge

-- Instantiating two variants (stub and real implementation) of the
-- module could be elegantly done with vhdl configurations but alas
-- there are is flaky (seems to work fine but subordinate IP dcp is
-- not used/linked into main dcp when I use configurations) support
-- (still in 2017.3) in vivado.
-- Therefore we define a package with relevant constants to reduce
-- redundant boilerplate at least a little bit...

package UdpDebugBridgePkg is

   constant XVC_MEM_SIZE_C    : natural  := 1450/2; -- non-jumbo MTU; mem must hold max. reply = max request/2
   constant XVC_TCLK_FREQ_C   : real     := 15.0E+6;
   constant XVC_AXIS_WIDTH_C  : positive range 4 to 16 := EMAC_AXIS_CONFIG_C.TDATA_BYTES_C;

   constant XVC_MEM_DEPTH_C   : natural range 0 to 65535 :=  XVC_MEM_SIZE_C/XVC_AXIS_WIDTH_C;
   constant XVC_MEM_STYLE_C   : string  := "auto";

end package UdpDebugBridgePkg;
