-------------------------------------------------------------------------------
-- File       : SynchronizerOneShot.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-02-06
-- Last update: 2016-11-04
-------------------------------------------------------------------------------
-- Description: One-Shot Pulser that has to cross clock domains
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

use work.StdRtlPkg.all;

entity SynchronizerOneShot is
   generic (
      TPD_G           : time     := 1 ns;   -- Simulation FF output delay
      RST_POLARITY_G  : sl       := '1';    -- '1' for active HIGH reset, '0' for active LOW reset
      RST_ASYNC_G     : boolean  := false;  -- Reset is asynchronous
      BYPASS_SYNC_G   : boolean  := false;  -- Bypass RstSync module for synchronous data configuration
      RELEASE_DELAY_G : positive := 3;  -- Delay between deassertion of async and sync resets
      IN_POLARITY_G   : sl       := '1';    -- 0 for active LOW, 1 for active HIGH
      OUT_POLARITY_G  : sl       := '1';    -- 0 for active LOW, 1 for active HIGH
      PULSE_WIDTH_G   : positive := 1);     -- one-shot pulse width duration (units of clk cycles)
   port (
      clk     : in  sl;                 -- Clock to be SYNC'd to
      rst     : in  sl := not RST_POLARITY_G;  -- Optional reset
      dataIn  : in  sl;                 -- Trigger to be sync'd
      dataOut : out sl);                -- synced one-shot pulse
end SynchronizerOneShot;

architecture rtl of SynchronizerOneShot is

   type StateType is (
      IDLE_S,
      CNT_S);

   type RegType is record
      cnt     : natural range 0 to (PULSE_WIDTH_G-1);
      dataOut : sl;
      state   : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      cnt     => 0,
      dataOut => not(OUT_POLARITY_G),
      state   => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal pulseRst : sl;
   signal edgeDet  : sl;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";      

begin

   RstSync_Inst : entity work.RstSync
      generic map (
         TPD_G           => TPD_G,
         RELEASE_DELAY_G => RELEASE_DELAY_G,
         BYPASS_SYNC_G   => BYPASS_SYNC_G,
         IN_POLARITY_G   => IN_POLARITY_G,
         OUT_POLARITY_G  => '1')
      port map (
         clk      => clk,
         asyncRst => dataIn,
         syncRst  => pulseRst);

   Sync_Pulse : entity work.SynchronizerEdge
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         OUT_POLARITY_G => OUT_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         BYPASS_SYNC_G  => BYPASS_SYNC_G)
      port map (
         clk        => clk,
         dataIn     => pulseRst,
         risingEdge => edgeDet);

   U_OnlyCyclePulse : if (PULSE_WIDTH_G = 1) generate
      dataOut <= edgeDet;
   end generate;

   U_PulseStretcher : if (PULSE_WIDTH_G > 1) generate
      
      comb : process (edgeDet, r, rst) is
         variable v : RegType;
      begin
         -- Latch the current value
         v := r;

         -- State Machine
         case r.state is
            ----------------------------------------------------------------------   
            when IDLE_S =>
               -- Reset the flag
               v.dataOut := not(OUT_POLARITY_G);
               -- Check for edge detection
               if (edgeDet = OUT_POLARITY_G) then
                  -- Next state
                  v.state := CNT_S;
               end if;
            ----------------------------------------------------------------------   
            when CNT_S =>
               -- Set the flag
               v.dataOut := OUT_POLARITY_G;
               -- Check the counter
               if r.cnt = (PULSE_WIDTH_G-1) then
                  -- Reset the counter
                  v.cnt   := 0;
                  -- Next state
                  v.state := IDLE_S;
               else
                  -- Increment the counter
                  v.cnt := r.cnt + 1;
               end if;
         ----------------------------------------------------------------------   
         end case;

         -- Reset
         if (rst = RST_POLARITY_G) then
            v := REG_INIT_C;
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

         -- Outputs 
         dataOut <= v.dataOut;

      end process;

      seq : process (clk) is
      begin
         if rising_edge(clk) then
            r <= rin after TPD_G;
         end if;
      end process seq;
      
   end generate;

end architecture rtl;
