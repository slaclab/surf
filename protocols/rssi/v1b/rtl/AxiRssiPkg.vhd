-------------------------------------------------------------------------------
-- File       : AxiRssiPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: RSSI Package File
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

use work.StdRtlPkg.all;
use work.AxiPkg.all;

package AxiRssiPkg is

   --! Default RSSI AXI configuration
   constant RSSI_AXI_CONFIG_C : AxiConfigType := (
      ADDR_WIDTH_C => 14,               -- 2^14 = 16kB buffer
      DATA_BYTES_C => 8,                -- 8 bytes = 64-bits
      ID_BITS_C    => 0,
      LEN_BITS_C   => 8);               -- Up to 4kB bursting

end AxiRssiPkg;
