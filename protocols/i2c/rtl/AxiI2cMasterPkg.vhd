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
