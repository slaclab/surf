library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

package AxiSfpPkg is
   
   type AxiSfpInType is record
      sfpRs      : slv(1 downto 0);
      sfpRxLoss  : sl;
      sfpAbs     : sl;
      sfpTxFault : sl;
   end record;
   type AxiSfpInArray is array (natural range <>) of AxiSfpInType;
   type AxiSfpInVectorArray is array (integer range<>, integer range<>)of AxiSfpInType;
   constant AXI_SFP_IN_INIT_C : AxiSfpInType := (
      (others => '0'),
      '0',
      '0',
      '0');   

   type AxiSfpInOutType is record
      sfpScl : sl;
      sfpSda : sl;
   end record;
   type AxiSfpInOutArray is array (natural range <>) of AxiSfpInOutType;
   type AxiSfpInOutVectorArray is array (integer range<>, integer range<>)of AxiSfpInOutType;
   constant AXI_SFP_IN_OUT_INIT_C : AxiSfpInOutType := (
      'Z',
      'Z');       

   type AxiSfpOutType is record
      sfpTxDisable : sl;
   end record;
   type AxiSfpOutArray is array (natural range <>) of AxiSfpOutType;
   type AxiSfpOutVectorArray is array (integer range<>, integer range<>)of AxiSfpOutType;
   constant AXI_SFP_OUT_INIT_C : AxiSfpOutType := (
      (others => '0'));  

   type AxiSfpStatusType is record
      sfpRs      : slv(1 downto 0);
      sfpRxLoss  : sl;
      sfpAbs     : sl;
      sfpTxFault : sl;
   end record;
   constant AXI_SFP_STATUS_INIT_C : AxiSfpStatusType := (
      (others => '0'),
      '0',
      '0',
      '0');

   type AxiSfpConfigType is record
      sfpTxDisable : sl;
   end record;
   constant AXI_SFP_CONFIG_INIT_C : AxiSfpConfigType := (
      (others => '0'));  

end package;
