-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: This module measures the trigger period between triggers
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

entity SyncTrigPeriod is
   generic (
      TPD_G         : time     := 1 ns;   -- Simulation FF output delay
      COMMON_CLK_G  : boolean  := false;  -- true if trigClk & locClk are the same clock
      IN_POLARITY_G : sl       := '1';  -- 0 for active LOW, 1 for active HIGH
      CNT_WIDTH_G   : positive := 32);  -- Counters' width
   port (
      -- Trigger Input (trigClk domain)
      trigClk   : in  sl;
      trigRst   : in  sl;
      trigIn    : in  sl;
      -- Trigger Period Output (locClk domain)
      locClk    : in  sl;
      locRst    : in  sl;
      resetStat : in  sl;
      period    : out slv(CNT_WIDTH_G-1 downto 0);   -- units of clock cycles
      periodMax : out slv(CNT_WIDTH_G-1 downto 0);   -- units of clock cycles
      periodMin : out slv(CNT_WIDTH_G-1 downto 0));  -- units of clock cycles
end SyncTrigPeriod;

architecture rtl of SyncTrigPeriod is

   constant MAX_CNT_C : slv(CNT_WIDTH_G-1 downto 0) := (others => '1');

   type RegType is record
      armed     : sl;
      cnt       : slv(CNT_WIDTH_G-1 downto 0);
      period    : slv(CNT_WIDTH_G-1 downto 0);
      periodMax : slv(CNT_WIDTH_G-1 downto 0);
      periodMin : slv(CNT_WIDTH_G-1 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      armed     => '0',
      cnt       => (others => '0'),
      period    => (others => '0'),
      periodMax => (others => '0'),
      periodMin => (others => '1'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal trig : sl := '0';

begin

   U_OneShot : entity surf.SynchronizerOneShot
      generic map (
         TPD_G          => TPD_G,
         BYPASS_SYNC_G  => COMMON_CLK_G,
         IN_POLARITY_G  => IN_POLARITY_G,
         OUT_POLARITY_G => '1')
      port map (
         clk     => locClk,
         dataIn  => trigIn,
         dataOut => trig);


   comb : process (locRst, r, resetStat, trig) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Increment the counter
      if (r.cnt /= MAX_CNT_C) then
         v.cnt := r.cnt + 1;
      end if;

      -- Check for a trigger
      if (trig = '1') then

         -- Check for first trigger strobe after reset
         if (r.armed = '0') then

            -- Set the flag
            v.armed := '1';

         else

            -- Save the current period value
            v.period := v.cnt;

            -- Check for max value
            if (v.cnt > r.periodMax) then
               v.periodMax := v.cnt;
            end if;

            -- Check for min value
            if (v.cnt < r.periodMin) then
               v.periodMin := v.cnt;
            end if;

            -- Reset the counter
            v.cnt := (others => '0');

         end if;

      end if;

      -- Outputs
      period    <= r.period;
      periodMax <= r.periodMax;
      periodMin <= r.periodMin;

      -- Reset
      if (locRst = '1') or (resetStat = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (locClk) is
   begin
      if rising_edge(locClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
