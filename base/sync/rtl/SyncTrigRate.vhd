-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: This module measures the trigger rate of a trigger
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

entity SyncTrigRate is
   generic (
      TPD_G          : time     := 1 ns;   -- Simulation FF output delay
      COMMON_CLK_G   : boolean  := false;  -- true if locClk & refClk are the same clock
      ONE_SHOT_G     : boolean  := false;
      IN_POLARITY_G  : sl       := '1';  -- 0 for active LOW, 1 for active HIGH
      COUNT_EDGES_G  : boolean  := false;  -- Count edges or high time
      REF_CLK_FREQ_G : real     := 200.0E+6;              -- units of Hz
      REFRESH_RATE_G : real     := 1.0E+0;                -- units of Hz
      CNT_WIDTH_G    : positive := 32);  -- Counters' width
   port (
      -- Trigger Input (locClk domain)
      trigIn          : in  sl;
      -- Trigger Rate Output (locClk domain)
      trigRateUpdated : out sl;
      trigRateOut     : out slv(CNT_WIDTH_G-1 downto 0);  -- units of REFRESH_RATE_G
      trigRateOutMax  : out slv(CNT_WIDTH_G-1 downto 0);  -- units of REFRESH_RATE_G
      trigRateOutMin  : out slv(CNT_WIDTH_G-1 downto 0);  -- units of REFRESH_RATE_G
      -- Clocks
      locClkEn        : in  sl := '1';
      locClk          : in  sl;
      locRst          : in  sl := '0';
      refClk          : in  sl;
      refRst          : in  sl := '0');
end SyncTrigRate;

architecture rtl of SyncTrigRate is

   constant TIMEOUT_C : natural := getTimeRatio(REF_CLK_FREQ_G, REFRESH_RATE_G)-1;

   type RegType is record
      updated    : sl;
      timer      : natural range 0 to TIMEOUT_C;
      trigCntDly : slv(CNT_WIDTH_G-1 downto 0);
      rate       : slv(CNT_WIDTH_G-1 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      updated    => '0',
      timer      => 0,
      trigCntDly => (others => '0'),
      rate       => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal trig        : sl                          := not(IN_POLARITY_G);
   signal trigLast    : sl                          := not IN_POLARITY_G;
   signal updated     : sl                          := '0';
   signal trigCnt     : slv(CNT_WIDTH_G-1 downto 0) := (others => '0');
   signal trigCntSync : slv(CNT_WIDTH_G-1 downto 0) := (others => '0');
   signal rstStat     : sl;

begin

   BYPASS_ONE_SHOT : if (ONE_SHOT_G = false) generate

      trig <= trigIn;

   end generate;

   GEN_ONE_SHOT : if (ONE_SHOT_G = true) generate

      U_OneShot : entity surf.SynchronizerOneShot
         generic map (
            TPD_G          => TPD_G,
            IN_POLARITY_G  => IN_POLARITY_G,
            OUT_POLARITY_G => IN_POLARITY_G)
         port map (
            clk     => locClk,
            dataIn  => trigIn,
            dataOut => trig);

   end generate;

   process (locClk) is
   begin
      if rising_edge(locClk) then
         -- Check the clock enable
         if (locClkEn = '1') or (ONE_SHOT_G = true) then
            trigLast <= trig after TPD_G;
            -- Check for a trigger
            if (COUNT_EDGES_G = false and trig = IN_POLARITY_G) or
               (COUNT_EDGES_G and trig = IN_POLARITY_G and trigLast = not (IN_POLARITY_G)) then
               -- Increment the counter
               trigCnt <= trigCnt + 1 after TPD_G;
            end if;
         end if;
      end if;
   end process;

   SyncIn_trigCnt : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => CNT_WIDTH_G)
      port map (
         wr_clk => locClk,
         din    => trigCnt,
         rd_clk => refClk,
         dout   => trigCntSync);

   comb : process (r, trigCntSync) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.updated := '0';

      -- Check for timeout 
      if r.timer = TIMEOUT_C then
         -- Reset the timer
         v.timer      := 0;
         -- Update the rate measurement
         v.updated    := '1';
         v.rate       := trigCntSync - r.trigCntDly;
         -- Keep a delayed copy of trigCntSync
         v.trigCntDly := trigCntSync;
      else
         -- Increment the timer
         v.timer := r.timer + 1;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (refClk) is
   begin
      if rising_edge(refClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   rstStat <= refRst or locRst;

   U_Sync : entity surf.SyncMinMax
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         WIDTH_G      => CNT_WIDTH_G)
      port map (
         -- ASYNC statistics reset    
         rstStat => rstStat,
         -- Write Interface (wrClk domain)
         wrClk   => refClk,
         wrEn    => r.updated,
         dataIn  => r.rate,
         -- Read Interface (rdClk domain)
         rdClk   => locClk,
         updated => trigRateUpdated,
         dataOut => trigRateOut,
         dataMin => trigRateOutMin,
         dataMax => trigRateOutMax);

end rtl;
