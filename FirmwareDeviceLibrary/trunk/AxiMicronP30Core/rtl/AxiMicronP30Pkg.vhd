library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

package AxiMicronP30Pkg is

   type AxiMicronP30InType is record
      flashWait : sl; 
   end record;
   type AxiMicronP30InArray is array (natural range <>) of AxiMicronP30InType;
   type AxiMicronP30InVectorArray is array (integer range<>, integer range<>)of AxiMicronP30InType;
   
   type AxiMicronP30InOutType is record
      dq : slv(15 downto 0); 
   end record;
   type AxiMicronP30InOutArray is array (natural range <>) of AxiMicronP30InOutType;
   type AxiMicronP30InOutVectorArray is array (integer range<>, integer range<>)of AxiMicronP30InOutType;
   
   type AxiMicronP30OutType is record
      ceL    : sl;
      oeL    : sl;
      weL    : sl;      
      addr  : slv(30 downto 0);
      adv   : sl;
      clk   : sl;
      rstL   : sl;
   end record;
   type AxiMicronP30OutArray is array (natural range <>) of AxiMicronP30OutType;
   type AxiMicronP30OutVectorArray is array (integer range<>, integer range<>)of AxiMicronP30OutType;

end package;
