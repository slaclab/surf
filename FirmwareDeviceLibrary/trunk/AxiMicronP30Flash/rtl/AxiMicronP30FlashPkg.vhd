library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

package AxiMicronP30FlashPkg is

   type AxiMicronP30FlashInOutType is record
      data : sl; 
   end record;
   type AxiMicronP30FlashInOutArray is array (natural range <>) of AxiMicronP30FlashInOutType;
   type AxiMicronP30FlashInOutVectorArray is array (integer range<>, integer range<>)of AxiMicronP30FlashInOutType;
   
   type AxiMicronP30FlashOutType is record
      addr  : slv(26 downto 0);-- up to 2 Gb support
      adv   : sl;
      ce    : sl;
      oe    : sl;
      we    : sl;      
   end record;
   type AxiMicronP30FlashOutArray is array (natural range <>) of AxiMicronP30FlashOutType;
   type AxiMicronP30FlashOutVectorArray is array (integer range<>, integer range<>)of AxiMicronP30FlashOutType;

end package;
