
LIBRARY ieee;
USE work.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity AxiStreamSimLinkOb is port (
      obClk        : in    std_logic;
      obReset      : in    std_logic;
      obValid      : out   std_logic;
      obDest       : out   std_logic_vector(3 downto 0);
      obEof        : out   std_logic;
      obData       : out   std_logic_vector(31 downto 0);
      obReady      : in    std_logic
   );
end AxiStreamSimLinkOb;

-- Define architecture
architecture AxiStreamSimLinkOb of AxiStreamSimLinkOb is
   Attribute FOREIGN of AxiStreamSimLinkOb: architecture is 
      "vhpi:SimSw_lib:VhpiGenericElab:AxiStreamSimLinkObInit:AxiStreamSimLinkOb";
begin
end AxiStreamSimLinkOb;

