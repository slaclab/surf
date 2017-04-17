-------------------------------------------------------------------------------
-- File       : AxiSy56040Pkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-12
-- Last update: 2015-06-12
-------------------------------------------------------------------------------
-- Description: AxiSy56040 Package File
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

package AxiSy56040Pkg is

   type AxiSy56040OutType is record
      sin    : slv(1 downto 0);
      sout   : slv(1 downto 0);
      config : sl;
      load   : sl;
   end record;
   type AxiSy56040OutArray is array (natural range <>) of AxiSy56040OutType;
   type AxiSy56040OutVectorArray is array (integer range<>, integer range<>)of AxiSy56040OutType;

end package;
