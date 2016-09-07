------------------------------------------------------------------------------
-- This file is part of 'AXI-Lite I2C Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'AXI-Lite I2C Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

package AxiI2cMasterPkg is

   type AxiI2cMasterInOutType is record
      scl : sl;                         -- Two wire serial ID interface clock line (SCL) 
      sda : sl;                         -- Two wire serial ID interface data line (SDA) 
   end record;
   type AxiI2cMasterInOutArray is array (natural range <>) of AxiI2cMasterInOutType;
   type AxiI2cMasterInOutVectorArray is array (integer range<>, integer range<>)of AxiI2cMasterInOutType;
   constant AXI_SFP_IN_OUT_INIT_C : AxiI2cMasterInOutType := (
      'Z',
      'Z');       

end package;
