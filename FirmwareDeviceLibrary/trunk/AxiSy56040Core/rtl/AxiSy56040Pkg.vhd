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
