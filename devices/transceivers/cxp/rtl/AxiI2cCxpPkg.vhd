library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

package AxiI2cCxpPkg is
   
   type AxiI2cCxpInType is record
      moduleDetL : sl;                  -- Module Present = PRSNT_L
   end record;
   type AxiI2cCxpInArray is array (natural range <>) of AxiI2cCxpInType;
   type AxiI2cCxpInVectorArray is array (integer range<>, integer range<>)of AxiI2cCxpInType;
   constant AXI_SFP_IN_INIT_C : AxiI2cCxpInType := (
      moduleDetL => '1');   

   type AxiI2cCxpInOutType is record
      irqRstL : sl;                     -- Interrupt / Reset = Int_L/Reset_L
      scl     : sl;                     -- Two-wire serial interface clock
      sda     : sl;                     -- Two-wire serial interface data
   end record;
   type AxiI2cCxpInOutArray is array (natural range <>) of AxiI2cCxpInOutType;
   type AxiI2cCxpInOutVectorArray is array (integer range<>, integer range<>)of AxiI2cCxpInOutType;
   constant AXI_SFP_IN_OUT_INIT_C : AxiI2cCxpInOutType := (
      irqRstL => 'Z',
      scl     => 'Z',
      sda     => 'Z');        

   type AxiI2cCxpStatusType is record
      irq       : sl;
      moduleDet : sl;
   end record;
   constant AXI_SFP_STATUS_INIT_C : AxiI2cCxpStatusType := (
      irq       => '0',
      moduleDet => '0');

   type AxiI2cCxpConfigType is record
      rst : sl;
   end record;
   constant AXI_SFP_CONFIG_INIT_C : AxiI2cCxpConfigType := (
      rst => '0');  

end package;
