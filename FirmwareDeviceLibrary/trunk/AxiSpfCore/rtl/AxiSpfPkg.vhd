library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

package AxiSpfPkg is
   
   type AxiSpfInType is record
      spfRs      : slv(1 downto 0);
      spfRxLoss  : sl;
      spfAbs     : sl;
      spfTxFault : sl;
   end record;
   type AxiSpfInArray is array (natural range <>) of AxiSpfInType;
   type AxiSpfInVectorArray is array (integer range<>, integer range<>)of AxiSpfInType;
   constant AXI_SFP_IN_INIT_C : AxiSpfInType := (
      (others => '0'),
      '0',
      '0',
      '0');   

   type AxiSpfInOutType is record
      spfScl : sl;
      spfSda : sl;
   end record;
   type AxiSpfInOutArray is array (natural range <>) of AxiSpfInOutType;
   type AxiSpfInOutVectorArray is array (integer range<>, integer range<>)of AxiSpfInOutType;
   constant AXI_SFP_IN_OUT_INIT_C : AxiSpfInOutType := (
      'Z',
      'Z');       

   type AxiSpfOutType is record
      spfTxDisable : sl;
   end record;
   type AxiSpfOutArray is array (natural range <>) of AxiSpfOutType;
   type AxiSpfOutVectorArray is array (integer range<>, integer range<>)of AxiSpfOutType;
   constant AXI_SFP_OUT_INIT_C : AxiSpfOutType := (
      (others => '0'));  

   type AxiSpfStatusType is record
      spfRs      : slv(1 downto 0);
      spfRxLoss  : sl;
      spfAbs     : sl;
      spfTxFault : sl;
   end record;
   constant AXI_SFP_STATUS_INIT_C : AxiSpfStatusType := (
      (others => '0'),
      '0',
      '0',
      '0');

   type AxiSpfConfigType is record
      spfTxDisable : sl;
   end record;
   constant AXI_SFP_CONFIG_INIT_C : AxiSpfConfigType := (
      (others => '0'));  

end package;
