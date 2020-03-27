-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: GLBL module for mixed Verilog/VHDL simulation support
------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------

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
