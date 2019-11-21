-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Programmable One-Shot Module
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

entity OneShot is
   generic (
      TPD_G             : time     := 1 ns;  -- Simulation FF output delay
      RST_POLARITY_G    : sl       := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      IN_POLARITY_G     : sl       := '1';  -- 0 for active LOW, 1 for active HIGH
      OUT_POLARITY_G    : sl       := '1';  -- 0 for active LOW, 1 for active HIGH
      PULSE_BIT_WIDTH_G : positive := 4);  -- maximum one-shot pulse width duration = 2**PULSE_BIT_WIDTH_G (units of clk cycles)
   port (
      clk        : in  sl;              -- Clock
      rst        : in  sl := not RST_POLARITY_G;           -- Optional reset
      pulseWidth : in  slv(PULSE_BIT_WIDTH_G-1 downto 0);  -- Pulse width configuration (zero inclusive)
      trigIn     : in  sl;              -- Trigger Input
      pulseOut   : out sl);             -- One-shot pulse Output
end OneShot;

architecture rtl of OneShot is

   type StateType is (
      IDLE_S,
      CNT_S,
      WAIT_S);

   type RegType is record
      cnt      : slv(PULSE_BIT_WIDTH_G-1 downto 0);
      pulseOut : sl;
      state    : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      cnt      => (others => '0'),
      pulseOut => not(OUT_POLARITY_G),
      state    => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";      

begin

   comb : process (pulseWidth, r, rst, trigIn) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flag
      v.pulseOut := not(OUT_POLARITY_G);

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------   
         when IDLE_S =>
            -- Check for trigger
            if (trigIn = IN_POLARITY_G) then
               -- Next state
               v.state := CNT_S;
            end if;
         ----------------------------------------------------------------------   
         when CNT_S =>
            -- Set the flag
            v.pulseOut := OUT_POLARITY_G;

            -- Increment the counter
            v.cnt := r.cnt + 1;

            -- Check the counter
            if (r.cnt = pulseWidth) then

               -- Reset the counter
               v.cnt := (others => '0');

               -- Check for trigger still active
               if (trigIn = IN_POLARITY_G) then
                  -- Next state
                  v.state := WAIT_S;

               -- Else trigger not active
               else
                  -- Next state
                  v.state := IDLE_S;
               end if;

            end if;
         ----------------------------------------------------------------------   
         when WAIT_S =>
            -- Check for trigger
            if (trigIn /= IN_POLARITY_G) then
               -- Next state
               v.state := IDLE_S;
            end if;
      ----------------------------------------------------------------------   
      end case;

      -- Outputs
      pulseOut <= r.pulseOut;

      -- Reset
      if (rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
