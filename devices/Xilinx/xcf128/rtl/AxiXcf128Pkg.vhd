-------------------------------------------------------------------------------
-- File       : AxiXcf128Pkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-18
-- Last update: 2015-01-13
-------------------------------------------------------------------------------
-- Description: AxiXcf128 Package File
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

package AxiXcf128Pkg is

   type AxiXcf128InOutType is record
      data : slv(15 downto 0);
   end record;
   type AxiXcf128InOutArray is array (natural range <>) of AxiXcf128InOutType;
   type AxiXcf128InOutVectorArray is array (integer range<>, integer range<>)of AxiXcf128InOutType;
   constant AXI_XCF128_IN_OUT_INIT_C : AxiXcf128InOutType := (
      data => (others => 'Z'));     

   type AxiXcf128OutType is record
      ceL   : sl;
      oeL   : sl;
      weL   : sl;
      latch : sl;
      addr  : slv(22 downto 0);
   end record;
   type AxiXcf128OutArray is array (natural range <>) of AxiXcf128OutType;
   type AxiXcf128OutVectorArray is array (integer range<>, integer range<>)of AxiXcf128OutType;
   constant AXI_XCF128_OUT_INIT_C : AxiXcf128OutType := (
      '1',
      '1',
      '1',
      '1',
      (others => '1'));  

   type AxiXcf128StatusType is record
      data : slv(15 downto 0);
   end record;
   constant AXI_XCF128_STATUS_INIT_C : AxiXcf128StatusType := (
      data => (others => '1'));    

   type AxiXcf128ConfigType is record
      ceL      : sl;
      oeL      : sl;
      weL      : sl;
      latch    : sl;
      addr     : slv(22 downto 0);
      tristate : sl;
      data     : slv(15 downto 0);
   end record;
   constant AXI_XCF128_CONFIG_INIT_C : AxiXcf128ConfigType := (
      '1',
      '1',
      '1',
      '0',
      (others => '1'),
      '1',
      (others => '1'));  

end package;
