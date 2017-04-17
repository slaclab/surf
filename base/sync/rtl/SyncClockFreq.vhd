-------------------------------------------------------------------------------
-- File       : SyncClockFreq.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-17
-- Last update: 2014-04-17
-------------------------------------------------------------------------------
-- Description:   This module measures the frequency of an input clock
--                with respect to a stable reference clock.
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

entity SyncClockFreq is
   generic (
      TPD_G             : time     := 1 ns;    -- Simulation FF output delay
      USE_DSP48_G       : string   := "no";    -- "no" for no DSP48 implementation, "yes" to use DSP48 slices
      REF_CLK_FREQ_G    : real     := 200.0E+6;-- Reference Clock frequency, units of Hz
      REFRESH_RATE_G    : real     := 1.0E+3;  -- Refresh rate, units of Hz
      CLK_LOWER_LIMIT_G : real     := 159.0E+6;-- Lower Limit for clock lock, units of Hz
      CLK_UPPER_LIMIT_G : real     := 161.0E+6;-- Lower Limit for clock lock, units of Hz
      CNT_WIDTH_G       : positive := 32);     -- Counters' width
   port (
      -- Frequency Measurement and Monitoring Outputs (locClk domain)
      freqOut     : out slv(CNT_WIDTH_G-1 downto 0);-- units of Hz
      freqUpdated : out sl;
      locked      : out sl; -- '1' CLK_LOWER_LIMIT_G < clkIn < CLK_UPPER_LIMIT_G
      tooFast     : out sl; -- '1' when clkIn > CLK_UPPER_LIMIT_G
      tooSlow     : out sl; -- '1' when clkIn < CLK_LOWER_LIMIT_G
      -- Clocks
      clkIn       : in  sl; -- Input clock to measure
      locClk      : in  sl; -- System clock
      refClk      : in  sl);-- Stable Reference Clock
end SyncClockFreq;

architecture rtl of SyncClockFreq is

   constant REFRESH_MAX_CNT_C : natural := getTimeRatio(REF_CLK_FREQ_G, REFRESH_RATE_G);
   constant CLK_LOWER_LIMIT_C : natural := getTimeRatio(CLK_LOWER_LIMIT_G, 1.0E+0);  -- lower limit
   constant CLK_UPPER_LIMIT_C : natural := getTimeRatio(CLK_UPPER_LIMIT_G, 1.0E+0);  -- upper limit

   signal updated,
      lockedDet,
      tooFastDet,
      tooSlowDet,
      wrEn,
      doneAccum : sl;
   
   signal freqHertz,
      cntIn,
      cntOut,
      cntStable,
      cntAccum,
      accum,
      cntOutDly,
      diffCnt : slv(CNT_WIDTH_G-1 downto 0);

   -- Attribute for XST
   attribute use_dsp48              : string;
   attribute use_dsp48 of cntIn     : signal is USE_DSP48_G;
   attribute use_dsp48 of cntStable : signal is USE_DSP48_G;
   attribute use_dsp48 of cntAccum  : signal is USE_DSP48_G;
   attribute use_dsp48 of accum     : signal is USE_DSP48_G;
   attribute use_dsp48 of diffCnt   : signal is USE_DSP48_G;
   attribute use_dsp48 of freqHertz : signal is USE_DSP48_G;
   
begin

   freqOut     <= freqHertz;
   freqUpdated <= updated;
   locked      <= lockedDet;
   tooFast     <= tooFastDet;
   tooSlow     <= tooSlowDet;

   ---------------------------
   -- Free Running Counter
   ---------------------------
   process(clkIn)
   begin
      if rising_edge(clkIn) then
         -- Increment the counter
         cntIn <= cntIn + 1 after TPD_G;
      end if;
   end process;

   ------------------------------------------------     
   -- Calculate the frequency of the input clock 
   ------------------------------------------------               
   SynchronizerFifo_In : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => CNT_WIDTH_G)   
      port map (
         --Write Ports (wr_clk domain)
         wr_clk => clkIn,
         din    => cntIn,
         --Read Ports (rd_clk domain)
         rd_clk => refClk,
         dout   => cntOut);      

   process(refClk)
   begin
      if rising_edge(refClk) then
         -- Reset the strobe
         wrEn      <= '0'           after TPD_G;
         -- Increment the Counter
         cntStable <= cntStable + 1 after TPD_G;
         -- Check if we have reached the targeted refresh rate
         if cntStable = REFRESH_MAX_CNT_C then
            -- Reset the Counter
            cntStable <= (others => '0')      after TPD_G;
            cntAccum  <= (others => '0')      after TPD_G;
            accum     <= (others => '0')      after TPD_G;
            -- Calculate the new frequency
            diffCnt   <= (cntOut - cntOutDly) after TPD_G;
            -- Save the current count value for next refresh cycle
            cntOutDly <= cntOut               after TPD_G;
            -- Reset the done flag
            doneAccum <= '0'                  after TPD_G;
         -- Check if we are accumulating
         elsif doneAccum = '0' then
            -- Check for accumulation counter
            if cntAccum = toSlv(integer(REFRESH_RATE_G), CNT_WIDTH_G) then
               -- Write the accumulated value to the output FIFO
               wrEn      <= '1' after TPD_G;
               -- Set the done flag
               doneAccum <= '1' after TPD_G;
            else
               -- Increment the counter
               cntAccum <= cntAccum + 1    after TPD_G;
               -- Accumulate the value
               accum    <= accum + diffCnt after TPD_G;
            end if;
         end if;
      end if;
   end process;

   SynchronizerFifo_Out : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => CNT_WIDTH_G)   
      port map (
         --Write Ports (wr_clk domain)
         wr_clk => refClk,
         wr_en  => wrEn,
         din    => accum,
         --Read Ports (rd_clk domain)
         rd_clk => locClk,
         valid  => updated,
         dout   => freqHertz);

   ---------------------------
   -- Clock Monitoring Process
   ---------------------------
   process(locClk)
   begin
      if rising_edge(locClk) then
         -- Update locked flag
         if (tooFastDet = '0') and (tooSlowDet = '0') then
            lockedDet <= '1' after TPD_G;
         else
            lockedDet <= '0' after TPD_G;
         end if;
         -- Check for too fast input clock
         if freqHertz > CLK_UPPER_LIMIT_C then
            tooFastDet <= '1' after TPD_G;
         else
            tooFastDet <= '0' after TPD_G;
         end if;
         -- Check for too slow input clock
         if freqHertz < CLK_LOWER_LIMIT_C then
            tooSlowDet <= '1' after TPD_G;
         else
            tooSlowDet <= '0' after TPD_G;
         end if;
      end if;
   end process;
   
end rtl;
