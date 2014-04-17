-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SyncTrigRate.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-16
-- Last update: 2014-04-16
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: This module measures the trigger rate of a trigger
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

entity SyncTrigRate is
   generic (
      TPD_G          : time     := 1 ns;  -- Simulation FF output delay
      COMMON_CLK_G   : boolean  := false;     -- true if locClk & refClk are the same clock
      IN_POLARITY_G  : sl       := '1';   -- 0 for active LOW, 1 for active HIGH
      REF_CLK_FREQ_G : real     := 200.0E+6;  -- units of Hz
      REFRESH_RATE_G : real     := 1.0E+0;    -- units of Hz
      USE_DSP48_G    : string   := "no";  -- "no" for no DSP48 implementation, "yes" to use DSP48 slices
      CNT_WIDTH_G    : positive := 32);   -- Counters' width
   port (
      -- Trigger Input (locClk domain)
      trigIn          : in  sl;
      -- Trigger Rate Output (locClk domain)
      trigRateUpdated : out sl;
      trigRateOut     : out slv(CNT_WIDTH_G-1 downto 0);
      -- Clocks
      locClkEn        : in  sl := '1';
      locClk          : in  sl;
      refClk          : in  sl);
end SyncTrigRate;

architecture rtl of SyncTrigRate is

   constant REFRESH_MAX_CNT_C     : natural                     := getTimeRatio(REF_CLK_FREQ_G, REFRESH_RATE_G);
   constant REFRESH_SLV_MAX_CNT_C : slv(CNT_WIDTH_G-1 downto 0) := toSlv((REFRESH_MAX_CNT_C-1), CNT_WIDTH_G);

   signal wrEn,
      wrEnSync : sl;
   signal trigCnt,
      trigCntSync,
      trigRateCnt,
      trigRateSync,
      trigCntDly : slv(CNT_WIDTH_G-1 downto 0);

   -- Attribute for XST
   attribute use_dsp48                 : string;
   attribute use_dsp48 of trigCnt      : signal is USE_DSP48_G;
   attribute use_dsp48 of trigRateCnt  : signal is USE_DSP48_G;
   attribute use_dsp48 of trigRateSync : signal is USE_DSP48_G;
   
begin

   GEN_ASYNC : if (COMMON_CLK_G = false) generate
      
      process (locClk) is
      begin
         if rising_edge(locClk) then
            -- Reset the write enable strobe
            wrEn <= '0' after TPD_G;
            -- Check the clock enable
            if locClkEn = '1' then
               -- Check for a trigger
               if trigIn = IN_POLARITY_G then
                  -- Increment the counter
                  trigCnt <= trigCnt + 1 after TPD_G;
                  -- Write the new counter value to the FIFO
                  wrEn    <= '1'         after TPD_G;
               end if;
            end if;
         end if;
      end process;

      SyncIn_trigCnt : entity work.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            DATA_WIDTH_G => CNT_WIDTH_G)
         port map (
            wr_clk => locClk,
            wr_en  => wrEn,
            din    => trigCnt,
            rd_clk => refClk,
            dout   => trigCntSync);                  

      process (refClk) is
      begin
         if rising_edge(refClk) then
            -- Reset the write enable strobe
            wrEnSync    <= '0'             after TPD_G;
            -- Increment the counter
            trigRateCnt <= trigRateCnt + 1 after TPD_G;
            -- Check if we have counted up to 1/REFRESH_RATE_G duration
            if trigRateCnt = REFRESH_SLV_MAX_CNT_C then
               -- Reset the counter
               trigRateCnt  <= (others => '0')          after TPD_G;
               -- Calculate the trigger rate
               trigRateSync <= trigCntSync - trigCntDly after TPD_G;
               -- Save the current trigger counter value
               trigCntDly   <= trigCntSync              after TPD_G;
               -- Write the new counter value to the FIFO
               wrEnSync     <= '1'                      after TPD_G;
            end if;
         end if;
      end process;

      SyncOut_trigRate : entity work.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            DATA_WIDTH_G => CNT_WIDTH_G)
         port map (
            wr_clk => refClk,
            wr_en  => wrEnSync,
            din    => trigRateSync,
            rd_clk => locClk,
            valid  => trigRateUpdated,
            dout   => trigRateOut);     

   end generate;

   GEN_SYNC : if (COMMON_CLK_G = true) generate
      
      trigRateOut     <= trigRateSync;
      trigRateUpdated <= wrEnSync;

      process (refClk) is
      begin
         if rising_edge(refClk) then
            -- Reset the write enable strobe
            wrEnSync <= '0' after TPD_G;
            -- Check the clock enable
            if locClkEn = '1' then
               -- Check for a trigger
               if trigIn = IN_POLARITY_G then
                  -- Increment the counter
                  trigCnt <= trigCnt + 1 after TPD_G;
               end if;
            end if;
            -- Increment the counter
            trigRateCnt <= trigRateCnt + 1 after TPD_G;
            -- Check if we have counted up to 1/REFRESH_RATE_G duration
            if trigRateCnt = REFRESH_SLV_MAX_CNT_C then
               -- Reset the counter
               trigRateCnt  <= (others => '0')      after TPD_G;
               -- Calculate the trigger rate
               trigRateSync <= trigCnt - trigCntDly after TPD_G;
               -- Save the current trigger counter value
               trigCntDly   <= trigCnt              after TPD_G;
               -- Write the new counter value to the FIFO
               wrEnSync     <= '1'                  after TPD_G;
            end if;
         end if;
      end process;
      
   end generate;
   
end rtl;
