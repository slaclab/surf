-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Heartbeat LED output
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

entity Heartbeat is
   generic (
      TPD_G        : time   := 1 ns;
      USE_DSP_G    : string := "no";
      PERIOD_IN_G  : real   := 6.4E-9;   --units of seconds
      PERIOD_OUT_G : real   := 1.0E-0);  --units of seconds
   port (
      clk : in  sl;
      rst : in  sl := '0';
      o   : out sl);
end entity Heartbeat;

architecture rtl of Heartbeat is
   
   constant CNT_MAX_C  : natural := getTimeRatio(PERIOD_OUT_G, (2.0 * PERIOD_IN_G));
   constant CNT_SIZE_C : natural := bitSize(CNT_MAX_C);

   type RegType is record
      cnt : slv(CNT_SIZE_C-1 downto 0);
      o   : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      cnt => (others => '0'),
      o   => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Attribute for XST
   attribute use_dsp      : string;
   attribute use_dsp of r : signal is USE_DSP_G;
   
begin

   comb : process (r, rst) is
      variable v : RegType;
   begin
      v := r;

      v.cnt := r.cnt + 1;
      if (r.cnt = CNT_MAX_C) then
         v.cnt := (others => '0');
         if (r.o = '1') then
            v.o := '0';
         else
            v.o := '1';
         end if;
      end if;

      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;
      o   <= r.o;
      
   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
