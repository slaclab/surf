-------------------------------------------------------------------------------
-- File       : GigEthLvdsClockEnable.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: SGMII/LVDS Ethernet's clock enabling for 10/100 speeds
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;

entity GigEthLvdsClockEnable is
   generic (
      TPD_G : time := 1 ns);
   port (
      sysClk125       : in  sl;
      sysRst125       : in  sl;
      speed_is_10_100 : in  sl;
      speed_is_100    : in  sl;
      ethClkEn        : out sl);
end entity GigEthLvdsClockEnable;

architecture rtl of GigEthLvdsClockEnable is

   type RegType is record
      ethClkEn : sl;
      en100    : sl;
      cnt100   : natural range 0 to 9;
      en10     : sl;
      cnt10    : natural range 0 to 99;
   end record RegType;

   constant REG_INIT_C : RegType := (
      ethClkEn => '1',
      en100    => '0',
      cnt100   => 0,
      en10     => '0',
      cnt10    => 0);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (r, speed_is_100, speed_is_10_100, sysRst125) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.en100 := '0';
      v.en10  := '0';

      -- Check for max count
      if r.cnt100 = 9 then
         -- Reset the counter
         v.cnt100 := 0;
         -- Set the flag
         v.en100  := '1';
      else
         -- Increment the counter
         v.cnt100 := r.cnt100 + 1;
      end if;

      -- Check for max count
      if r.cnt10 = 99 then
         -- Reset the counter
         v.cnt10 := 0;
         -- Set the flag
         v.en10  := '1';
      else
         -- Increment the counter
         v.cnt10 := r.cnt10 + 1;
      end if;

      -- Check if 10 or 100 speed
      if speed_is_10_100 = '1' then

         -- Check if 100 speed
         if speed_is_100 = '1' then
            v.ethClkEn := r.en100;

         -- Else this is 10 speed
         else
            v.ethClkEn := r.en10;
         end if;

      else
         -- 1000 speed (100% duty cycle for clock enable)
         v.ethClkEn := '1';
      end if;

      -- Outputs 
      ethClkEn <= r.ethClkEn;

      -- Reset
      if (sysRst125 = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (sysClk125) is
   begin
      if (rising_edge(sysClk125)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
