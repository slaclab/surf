library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

package AxiI2cSfpPkg is
   
   type AxiI2cSfpInType is record
      rxLoss     : sl;  -- Loss of Signal – High indicates loss of received optical signal 
      moduleDetL : sl;  -- Module Definition 0 (MOD-DEF0) – Grounded in module (module present indicator) 
      txFault    : sl;  -- Transmitter Fault Indication – High indicates a fault condition 
   end record;
   type AxiI2cSfpInArray is array (natural range <>) of AxiI2cSfpInType;
   type AxiI2cSfpInVectorArray is array (integer range<>, integer range<>)of AxiI2cSfpInType;
   constant AXI_SFP_IN_INIT_C : AxiI2cSfpInType := (
      '0',
      '0',
      '0');   

   type AxiI2cSfpInOutType is record
      rateSel : slv(1 downto 0);        -- Bit Rate Parametric Optimization 
      scl     : sl;  -- Module Definition 1 (MOD-DEF1) – Two wire serial ID interface clock line (SCL) 
      sda     : sl;  -- Module Definition 2 (MOD-DEF2) – Two wire serial ID interface data line (SDA) 
   end record;
   type AxiI2cSfpInOutArray is array (natural range <>) of AxiI2cSfpInOutType;
   type AxiI2cSfpInOutVectorArray is array (integer range<>, integer range<>)of AxiI2cSfpInOutType;
   constant AXI_SFP_IN_OUT_INIT_C : AxiI2cSfpInOutType := (
      (others => 'Z'),
      'Z',
      'Z');       

   type AxiI2cSfpOutType is record
      txDisable : sl;  -- Transmitter Disable – Module electrical input disables on high or open 
   end record;
   type AxiI2cSfpOutArray is array (natural range <>) of AxiI2cSfpOutType;
   type AxiI2cSfpOutVectorArray is array (integer range<>, integer range<>)of AxiI2cSfpOutType;
   constant AXI_SFP_OUT_INIT_C : AxiI2cSfpOutType := (
      (others => '0'));  

   type AxiI2cSfpStatusType is record
      rxLoss     : sl;
      moduleDetL : sl;
      txFault    : sl;
   end record;
   constant AXI_SFP_STATUS_INIT_C : AxiI2cSfpStatusType := (
      '0',
      '0',
      '0');

   type AxiI2cSfpConfigType is record
      rateSel   : slv(1 downto 0);
      txDisable : sl;
   end record;
   constant AXI_SFP_CONFIG_INIT_C : AxiI2cSfpConfigType := (
      (others => '1'),
      '0');  

end package;
