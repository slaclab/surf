-------------------------------------------------------------------------------
-- File       : SyncRegister.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-04-15
-- Last update: 2017-04-15
-------------------------------------------------------------------------------
-- Description: 1 c-c register delay 
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

entity SyncRegister is
   generic (
      TPD_G        : time       := 1 ns;
      WIDTH_G      : positive   := 1);
   port (
      clk      : in  sl;
      rst      : in  sl;
      
      -- Synchronisation inputs
      sig_i  : in  slv(WIDTH_G-1 downto 0);
      reg_o  : out slv(WIDTH_G-1 downto 0)
   );
end entity SyncRegister;

architecture rtl of SyncRegister is
   
   type RegType is record
      reg : slv(WIDTH_G-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      reg  => (others => '0')
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
begin

   comb : process (r, rst, sig_i) is
      variable v : RegType;
   begin
      v := r;
      
      -- Register/Delay for 1 clock cycle 
      v.reg := sig_i;
      
      if (rst = '1') then
         v := REG_INIT_C;
      end if;
      
      -- Output assignment
      rin   <= v;
      reg_o <= r.reg;
   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   

---------------------------------------   
end architecture rtl;
