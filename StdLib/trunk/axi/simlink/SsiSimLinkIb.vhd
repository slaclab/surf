
LIBRARY ieee;
USE work.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity SsiSimLinkIb is port (
      ibClk        : in    std_logic;
      ibReset      : in    std_logic;
      ibValid      : in    std_logic;
      ibDest       : in    std_logic_vector(3 downto 0);
      ibEof        : in    std_logic;
      ibEofe       : in    std_logic;
      ibData       : in    std_logic_vector(31 downto 0)
   );
end SsiSimLinkIb;

-- Define architecture
architecture SsiSimLinkIb of SsiSimLinkIb is
   Attribute FOREIGN of SsiSimLinkIb: architecture is 
      "vhpi:SimSw_lib:VhpiGenericElab:SsiSimLinkIbInit:SsiSimLinkIb";
begin
end SsiSimLinkIb;

