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
