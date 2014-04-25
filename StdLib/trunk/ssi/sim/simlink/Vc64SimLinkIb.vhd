
LIBRARY ieee;
USE work.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Vc64SimLinkIb is port (
      ibClk            : in    std_logic;
      ibReset          : in    std_logic;
      ibDataValid      : in    std_logic;
      ibDataSize       : in    std_logic;
      ibDataVc         : in    std_logic_vector(3 downto 0);
      ibDataSof        : in    std_logic;
      ibDataEof        : in    std_logic;
      ibDataEofe       : in    std_logic;
      ibDataDataHigh   : in    std_logic_vector(31 downto 0);
      ibDataDataLow    : in    std_logic_vector(31 downto 0);
      littleEndian     : in    std_logic;
      vcWidth          : in    std_logic_vector(6  downto 0)
   );
end Vc64SimLinkIb;

-- Define architecture
architecture Vc64SimLinkIb of Vc64SimLinkIb is
   Attribute FOREIGN of Vc64SimLinkIb: architecture is 
      "vhpi:SimSw_lib:VhpiGenericElab:Vc64SimLinkIbInit:Vc64SimLinkIb";
begin
end Vc64SimLinkIb;

