-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for multiple SyncTrigRate modules
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


library surf;
use surf.StdRtlPkg.all;

entity SyncTrigRateVector is
   generic (
      TPD_G          : time     := 1 ns;  -- Simulation FF output delay
      COMMON_CLK_G   : boolean  := false;     -- true if locClk & refClk are the same clock
      ONE_SHOT_G     : boolean  := false;
      IN_POLARITY_G  : slv      := "1";   -- 0 for active LOW, 1 for active HIGH
      REF_CLK_FREQ_G : real     := 200.0E+6;  -- units of Hz
      REFRESH_RATE_G : real     := 1.0E+0;    -- units of Hz
      CNT_WIDTH_G    : positive := 32;  -- Counters' width 
      WIDTH_G        : positive := 16);
   port (
      -- Trigger Input (locClk domain)
      trigIn          : in  slv(WIDTH_G-1 downto 0);
      -- Trigger Rate Output (locClk domain)
      trigRateUpdated : out sl;
      trigRateOut     : out SlVectorArray(WIDTH_G-1 downto 0, CNT_WIDTH_G-1 downto 0);  -- units of REFRESH_RATE_G
      -- Clocks
      locClkEn        : in  sl := '1';
      locClk          : in  sl;
      refClk          : in  sl);        
end SyncTrigRateVector;

architecture mapping of SyncTrigRateVector is

   type MyVectorArray is array (WIDTH_G-1 downto 0) of sl;

   function FillVectorArray (INPUT : slv)
      return MyVectorArray is
      variable retVar : MyVectorArray := (others => '1');
   begin
      if INPUT = "1" then
         retVar := (others => '1');
      else
         for i in WIDTH_G-1 downto 0 loop
            retVar(i) := INPUT(i);
         end loop;
      end if;
      return retVar;
   end function FillVectorArray;

   constant IN_POLARITY_C : MyVectorArray := FillVectorArray(IN_POLARITY_G);

   type MySlvArray is array (WIDTH_G-1 downto 0) of slv(CNT_WIDTH_G-1 downto 0);
   signal trigRate : MySlvArray;

   signal trigRateUpdate : slv(WIDTH_G-1 downto 0);
   
begin

   -- Only need to propagate one of the updates because they will be identical signals.
   trigRateUpdated <= trigRateUpdate(0);

   GEN_VEC :
   for i in (WIDTH_G-1) downto 0 generate
      
      SyncTrigRate_Inst : entity surf.SyncTrigRate
         generic map (
            TPD_G          => TPD_G,
            COMMON_CLK_G   => COMMON_CLK_G,
            ONE_SHOT_G     => ONE_SHOT_G,
            IN_POLARITY_G  => IN_POLARITY_C(i),
            REF_CLK_FREQ_G => REF_CLK_FREQ_G,
            REFRESH_RATE_G => REFRESH_RATE_G,
            CNT_WIDTH_G    => CNT_WIDTH_G)           
         port map (
            -- Trigger Input (locClk domain)
            trigIn          => trigIn(i),
            -- Trigger Rate Output (locClk domain)
            trigRateUpdated => trigRateUpdate(i),
            trigRateOut     => trigRate(i),
            -- Clocks
            locClkEn        => locClkEn,
            locClk          => locClk,
            refClk          => refClk);         

      GEN_MAP :
      for j in (CNT_WIDTH_G-1) downto 0 generate
         trigRateOut(i, j) <= trigRate(i)(j);
      end generate GEN_MAP;
      
   end generate GEN_VEC;
   
end architecture mapping;
