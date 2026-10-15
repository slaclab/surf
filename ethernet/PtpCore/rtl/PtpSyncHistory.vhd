-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Atomic normalized-Sync history append and nearest-sample lookup.
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
use ieee.numeric_std.all;
library surf;
use surf.StdRtlPkg.all;
use surf.PtpPkg.all;
use surf.PtpSyncPkg.all;

entity PtpSyncHistory is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';
      RST_ASYNC_G    : boolean := false;
      MEMORY_TYPE_G  : string  := "block");
   port (
      clk    : in sl;
      rst    : in sl;
      cancel : in sl;
      ticks  : in slv(63 downto 0);
      -- Start only with lookupIdle/lookupReady; caller retains delaySample
      -- through lookupDone. selectedSample persists until the next lookup.
      lookupStart     : in sl;
      lookupIdle      : out sl;
      lookupReady     : out sl;
      lookupQualified : in sl;
      delaySample     : in PtpDelaySampleType;
      lookupDone      : out sl;
      lookupMatched   : out sl;
      selectedSample  : out PtpSyncSampleType;
      -- One-edge append admission; hold all payload fields through appendDone.
      appendStart      : in sl;
      appendSample     : in PtpSyncSampleType;
      appendForward    : in slv(127 downto 0);
      appendNormalized : in slv(127 downto 0);
      appendBusy       : out sl;
      appendDone       : out sl;
      -- Selected normalized words stream directly from RAM, held on stall.
      normalizedValid : out sl;
      normalizedReady : in sl;
      normalizedWord  : out slv(2 downto 0);
      normalizedData  : out slv(31 downto 0);
      scanRequest     : out PtpScanRequestType;
      scanResult      : in PtpScanResultType);
end entity PtpSyncHistory;

architecture rtl of PtpSyncHistory is

   constant HISTORY_DEPTH_C      : positive := 4;
   constant HISTORY_WORDS_C      : positive := 25;
   constant HISTORY_ADDR_WIDTH_C : positive := log2(HISTORY_DEPTH_C*HISTORY_WORDS_C);
   type HistoryStateType is (
      HISTORY_IDLE_S,
      HISTORY_READ_S,
      HISTORY_CHECK_S,
      HISTORY_SCAN_S,
      HISTORY_NEXT_S,
      HISTORY_SELECT_S,
      HISTORY_FETCH_S,
      HISTORY_CAPTURE_S,
      HISTORY_DONE_S);

   type AppendStateType is (APPEND_IDLE_S, APPEND_SAMPLE_S, APPEND_NORMALIZED_S, APPEND_COMMIT_S);
   type RegType is record
      historyState        : HistoryStateType;
      normalizedValid     : sl;
      normalizedWord      : slv(2 downto 0);
      historyIndex        : natural range 0 to HISTORY_DEPTH_C-1;
      historyTicks        : slv(63 downto 0);
      historyFound        : sl;
      historyQualified    : sl;
      historyDistance     : slv(67 downto 0);
      historyReadEnable   : sl;
      historyReadAddress  : slv(HISTORY_ADDR_WIDTH_C-1 downto 0);
      historyWriteEnable  : sl;
      historyWriteAddress : slv(HISTORY_ADDR_WIDTH_C-1 downto 0);
      historyValid        : slv(HISTORY_DEPTH_C-1 downto 0);
      historyPtr          : natural range 0 to HISTORY_DEPTH_C-1;
      e2eSync             : PtpSyncSampleType;
      historyWriteData    : slv(31 downto 0);
      historyWriteBusy    : sl;
      historyWriteWord    : natural range 0 to HISTORY_WORDS_C;
      historyWord         : natural range 0 to HISTORY_WORDS_C-1;
      historyBest         : natural range 0 to HISTORY_DEPTH_C-1;
      historySampleTicks  : slv(63 downto 0);
      historyPhase        : slv(PTP_TICK_PHASE_BITS_C-1 downto 0);
      appendWord          : natural range 0 to 7;
      appendState         : AppendStateType;
   end record;

   constant REG_INIT_C : RegType := (
      historyState        => HISTORY_IDLE_S,
      normalizedValid     => '0',
      normalizedWord      => (others => '0'),
      historyIndex        => 0,
      historyTicks        => (others => '0'),
      historyFound        => '0',
      historyQualified    => '0',
      historyDistance     => (others => '0'),
      historyReadEnable   => '0',
      historyReadAddress  => (others => '0'),
      historyWriteEnable  => '0',
      historyWriteAddress => (others => '0'),
      historyValid        => (others => '0'),
      historyPtr          => 0,
      e2eSync             => PTP_SYNC_SAMPLE_INIT_C,
      historyWriteData    => (others => '0'),
      historyWriteBusy    => '0',
      historyWriteWord    => 0,
      historyWord         => 0,
      historyBest         => 0,
      historySampleTicks  => (others => '0'),
      historyPhase        => (others => '0'),
      appendWord          => 0,
      appendState         => APPEND_IDLE_S);

   signal r               : RegType := REG_INIT_C;
   signal rin             : RegType;
   signal historyReadData : slv(31 downto 0);

begin

   assert MEMORY_TYPE_G = "distributed" or MEMORY_TYPE_G = "block"
      report "PtpSyncHistory memory must be distributed or block" severity failure;
   lookupIdle <= toSl(r.historyState = HISTORY_IDLE_S);
   lookupReady <= not r.historyWriteBusy and not r.historyWriteEnable;
   lookupDone <= toSl(r.historyState = HISTORY_DONE_S);
   lookupMatched <= r.historyFound and r.historyQualified;
   selectedSample <= r.e2eSync;
   appendBusy <= r.historyWriteBusy;
   appendDone <= toSl(r.appendState = APPEND_COMMIT_S);
   normalizedValid <= r.normalizedValid;
   normalizedWord <= r.normalizedWord;
   normalizedData <= historyReadData;
   scanRequest.valid <= toSl(r.historyState = HISTORY_SCAN_S);
   scanRequest.ticks <= r.historyTicks;
   scanRequest.rowTicks <= r.historySampleTicks;
   scanRequest.rowPhase <= r.historyPhase;
   scanRequest.targetTicks <= delaySample.capture.ticks;
   scanRequest.targetPhase <= delaySample.capture.tickPhase;
   scanRequest.best <= r.historyDistance;

   U_HistoryRam : entity surf.SimpleDualPortRam
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         MEMORY_TYPE_G  => MEMORY_TYPE_G,
         DATA_WIDTH_G   => 32,
         BYTE_WR_EN_G   => false,
         BYTE_WIDTH_G   => 32,
         ADDR_WIDTH_G   => HISTORY_ADDR_WIDTH_C,
         SYNTH_MODE_G   => "inferred",
         COMMON_CLK_G   => true,
         READ_LATENCY_G => 1)
      port map (
         clka  => clk,                    -- [in]
         wea   => r.historyWriteEnable,   -- [in]
         addra => r.historyWriteAddress,  -- [in]
         dina  => r.historyWriteData,       -- [in]
         clkb  => clk,                    -- [in]
         enb   => r.historyReadEnable,    -- [in]
         rstb  => rst,                    -- [in]
         addrb => r.historyReadAddress,   -- [in]
         doutb => historyReadData);       -- [out]

   comb : process (all) is
      variable v : RegType;
   begin
      v := r;
      v.historyReadEnable := '0';
      v.historyWriteEnable := '0';
      -- Appends reuse the rate producer's held sample. A lookup pins the
      -- table until its selected record is copied; it never sees a partial row.
      if r.historyWriteBusy = '1' and r.historyState = HISTORY_IDLE_S and r.historyWriteWord < 17 then
         v.historyWriteEnable := '1';
         v.historyWriteAddress := toSlv(HISTORY_WORDS_C*r.historyPtr+r.historyWriteWord, HISTORY_ADDR_WIDTH_C);
         v.historyWriteData := syncWord(appendSample, r.historyWriteWord);
         v.historyWriteWord := r.historyWriteWord+1;
      end if;

      case r.historyState is
         when HISTORY_IDLE_S =>

            if lookupStart = '1' then
               v.historyTicks := ticks;
               v.historyQualified := lookupQualified;
               v.historyFound := '0';
               v.historyIndex := 0;
               v.historyWord := 0;
               v.historyReadAddress := (others => '0');
               v.historyReadEnable := '1';
               v.historyState := HISTORY_READ_S;
            end if;

         when HISTORY_READ_S =>
            v.historyState := HISTORY_CHECK_S;
         when HISTORY_CHECK_S =>

            case r.historyWord is
               when 0 to 1 =>
                  v.historySampleTicks(32*r.historyWord+31 downto 32*r.historyWord) := historyReadData;
               when 2 =>
                  v.historyPhase := historyReadData(PTP_TICK_PHASE_BITS_C-1 downto 0);
               when others =>
                  v.historyState := HISTORY_NEXT_S;

                  if r.historyValid(r.historyIndex) = '1' then
                     if historyReadData = delaySample.generation then
                        v.historyState := HISTORY_SCAN_S;
                     end if;
                  end if;

            end case;

            if r.historyWord /= 3 then
               v.historyWord := r.historyWord+1;
               v.historyReadAddress := toSlv(HISTORY_WORDS_C*r.historyIndex+r.historyWord+1, HISTORY_ADDR_WIDTH_C);
               v.historyReadEnable := '1';
               v.historyState := HISTORY_READ_S;
            end if;

         when HISTORY_SCAN_S =>

            if scanResult.valid = '1' then
               if scanResult.expired = '0' and (r.historyFound = '0' or scanResult.better = '1') then
                  -- Strict comparison retains the first physical slot on ties.
                  v.historyFound := '1';
                  v.historyDistance := scanResult.distance;
                  v.historyBest := r.historyIndex;
               end if;
               v.historyState := HISTORY_NEXT_S;
            end if;

         when HISTORY_NEXT_S =>

            if r.historyIndex = HISTORY_DEPTH_C-1 then
               v.historyState := HISTORY_SELECT_S;
            else
               v.historyIndex := r.historyIndex+1;
               v.historyWord := 0;
               v.historyReadAddress := toSlv(HISTORY_WORDS_C*(r.historyIndex+1), HISTORY_ADDR_WIDTH_C);
               v.historyReadEnable := '1';
               v.historyState := HISTORY_READ_S;
            end if;

         when HISTORY_SELECT_S =>
            v.historyState := HISTORY_DONE_S;

            if r.historyFound = '1' and r.historyQualified = '1' then
               v.historyWord := 0;
               v.historyReadAddress := toSlv(HISTORY_WORDS_C*r.historyBest, HISTORY_ADDR_WIDTH_C);
               v.historyReadEnable := '1';
               v.historyState := HISTORY_FETCH_S;
            end if;

         when HISTORY_FETCH_S =>
            v.historyState := HISTORY_CAPTURE_S;
            v.normalizedWord := toSlv((r.historyWord+7) mod 8,3);
            if r.historyWord >= 17 then
               v.normalizedValid := '1';
            end if;
         when HISTORY_CAPTURE_S =>

            if r.historyWord < 17 then
               takeSyncWord(v.e2eSync, r.historyWord, historyReadData);
            end if;

            if r.historyWord < 17 or normalizedReady = '1' then
               v.normalizedValid := '0';
               if r.historyWord = HISTORY_WORDS_C-1 then
                  v.historyState := HISTORY_DONE_S;
               else
                  v.historyWord := r.historyWord+1;
                  v.historyReadAddress := toSlv(HISTORY_WORDS_C*r.historyBest+r.historyWord+1, HISTORY_ADDR_WIDTH_C);
                  v.historyReadEnable := '1';
                  v.historyState := HISTORY_FETCH_S;
               end if;
            end if;

         when HISTORY_DONE_S =>
            v.historyState := HISTORY_IDLE_S;

      end case;

      -- The rate producer holds all append fields until appendDone. Commit
      -- follows the last registered RAM write; lookups never see partial rows.
      case r.appendState is
         when APPEND_IDLE_S =>
            if appendStart = '1' then
               v.historyWriteBusy := '1';
               v.historyWriteWord := 0;
               v.appendState := APPEND_SAMPLE_S;
            end if;
         when APPEND_SAMPLE_S =>
            if r.historyWriteWord = 17 and r.historyWriteEnable = '0' then
               v.appendWord := 0;
               v.appendState := APPEND_NORMALIZED_S;
            end if;

         when APPEND_NORMALIZED_S =>
            -- Words 17..24 hold the normalized forward value and corrected
            -- Sync time, so the E2E path need not repeat either conversion.
            v.historyWriteEnable := '1';
            v.historyWriteAddress := toSlv(HISTORY_WORDS_C*r.historyPtr+17+r.appendWord, HISTORY_ADDR_WIDTH_C);

            if r.appendWord < 4 then
               v.historyWriteData := appendForward(32*r.appendWord+31 downto 32*r.appendWord);
            else
               v.historyWriteData := appendNormalized(32*(r.appendWord-4)+31 downto 32*(r.appendWord-4));
            end if;

            if r.appendWord = 7 then
               v.appendState := APPEND_COMMIT_S;
            else
               v.appendWord := r.appendWord+1;
            end if;

         when APPEND_COMMIT_S =>
            v.historyWriteBusy := '0';
            v.historyValid(r.historyPtr) := '1';
            v.historyPtr := (r.historyPtr+1) mod HISTORY_DEPTH_C;
            v.appendState := APPEND_IDLE_S;

      end case;
      if cancel = '1' then
         v.historyState := HISTORY_IDLE_S;
         v.normalizedValid := '0';
         v.historyReadEnable := '0';
         v.historyWriteEnable := '0';
         v.historyWriteBusy := '0';
         v.historyFound := '0';
         v.historyValid := (others => '0');
         v.appendState := APPEND_IDLE_S;
      end if;
      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;
      rin <= v;
   end process comb;

   seq : process (clk, rst) is
   begin

      if RST_ASYNC_G and rst = RST_POLARITY_G then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;

   end process seq;

end architecture rtl;
