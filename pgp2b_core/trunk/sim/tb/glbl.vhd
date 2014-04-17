library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity glbl is 
end glbl;

architecture glbl of glbl is
   signal GR   : std_logic;
   signal GSR  : std_logic;
   signal GTS  : std_logic;
   signal PRLD : std_logic;
begin
   process begin
      GTS <= '0';
      GSR <= '1';
      wait for 100 ns;
      GTS <= '0';
      GSR <= '0';
      wait;
   end process;
end glbl;
