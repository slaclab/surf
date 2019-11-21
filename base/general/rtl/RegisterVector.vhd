-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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


library surf;
use surf.StdRtlPkg.all;

entity RegisterVector is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      WIDTH_G        : positive := 1;
      INIT_G         : slv      := "0");
   port (
      clk   : in  sl;
      rst   : in  sl := not RST_POLARITY_G;  -- Optional reset
      en    : in  sl := '1';            -- Optional clock enable
      sig_i : in  slv(WIDTH_G-1 downto 0);
      reg_o : out slv(WIDTH_G-1 downto 0));
end entity RegisterVector;

architecture rtl of RegisterVector is

   constant INIT_C : slv(WIDTH_G-1 downto 0) := ite(INIT_G = "0", slvZero(WIDTH_G), INIT_G);

   type RegType is record
      reg : slv(WIDTH_G-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      reg => INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (en, r, rst, sig_i) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Check the clock enable
      if en = '1' then
         -- Register/Delay for 1 clock cycle 
         v.reg := sig_i;
      end if;

      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs  
      reg_o <= r.reg;
   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
