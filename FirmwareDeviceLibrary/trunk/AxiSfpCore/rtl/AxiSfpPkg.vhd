library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

package AxiSfpPkg is
   
   type AxiSfpInType is record
      rxLoss     : sl;  -- Loss of Signal – High indicates loss of received optical signal 
      moduleDetL : sl;  -- Module Definition 0 (MOD-DEF0) – Grounded in module (module present indicator) 
      txFault    : sl;  -- Transmitter Fault Indication – High indicates a fault condition 
   end record;
   type AxiSfpInArray is array (natural range <>) of AxiSfpInType;
   type AxiSfpInVectorArray is array (integer range<>, integer range<>)of AxiSfpInType;
   constant AXI_SFP_IN_INIT_C : AxiSfpInType := (
      '0',
      '0',
      '0');   

   type AxiSfpInOutType is record
      rateSel : slv(1 downto 0);        -- Bit Rate Parametric Optimization 
      scl     : sl;  -- Module Definition 1 (MOD-DEF1) – Two wire serial ID interface clock line (SCL) 
      sda     : sl;  -- Module Definition 2 (MOD-DEF2) – Two wire serial ID interface data line (SDA) 
   end record;
   type AxiSfpInOutArray is array (natural range <>) of AxiSfpInOutType;
   type AxiSfpInOutVectorArray is array (integer range<>, integer range<>)of AxiSfpInOutType;
   constant AXI_SFP_IN_OUT_INIT_C : AxiSfpInOutType := (
      (others => 'Z'),
      'Z',
      'Z');       

   type AxiSfpOutType is record
      txDisable : sl;  -- Transmitter Disable – Module electrical input disables on high or open 
   end record;
   type AxiSfpOutArray is array (natural range <>) of AxiSfpOutType;
   type AxiSfpOutVectorArray is array (integer range<>, integer range<>)of AxiSfpOutType;
   constant AXI_SFP_OUT_INIT_C : AxiSfpOutType := (
      (others => '0'));  

   type AxiSfpStatusType is record
      rxLoss     : sl;
      moduleDetL : sl;
      txFault    : sl;
   end record;
   constant AXI_SFP_STATUS_INIT_C : AxiSfpStatusType := (
      '0',
      '0',
      '0');

   type AxiSfpConfigType is record
      rateSel   : slv(1 downto 0);
      txDisable : sl;
   end record;
   constant AXI_SFP_CONFIG_INIT_C : AxiSfpConfigType := (
      (others => '1'),
      '0');  

end package;
