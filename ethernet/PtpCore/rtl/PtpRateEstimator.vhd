-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Measures master nanoseconds per raw local cycle.
--
-- Extracted from PtpProtocolEngine so that protocol policy (parsing,
-- association, timeouts, flag legality) and rate measurement no longer share
-- one state machine. They have different inputs, different failure modes and
-- different test strategies.
--
-- Each accepted Sync supplies a master origin, its correction fields and the
-- local raw tick/phase capture. The estimator normalizes master time, holds
-- the first qualifying sample as an anchor, and once the anchor span is wide
-- enough computes
--   ratio = round(((remoteQ16 - anchorQ16) << 35) / deltaRawQ3)
-- using the shared endpoint divider. The denominator is measured elapsed raw
-- ticks, not an assumed Sync interval.
--
-- A candidate is qualified against a fixed nominal margin derived from the
-- oscillator envelope, then combined with a quarter-weight IIR after the first
-- accepted estimate. Only an accepted interval renews ratio freshness. The
-- published ratio is independent of PHC validity or steering.
--
-- Arithmetic is local and fixed-function: one epoch normalizer for the master
-- time conversion, and the shared divider for the single variable division.
-- The ratio shift and the IIR divide-by-four are constant shifts.
--
-- All ports use clk. Input ready is combinational; the published ratio, its
-- validity and the rejection counter are registered. A completion and its
-- acceptance/update flags are held until resultReady. Cancellation clears
-- pending work and the anchor without disturbing the published ratio payload.
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

entity PtpRateEstimator is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      CLK_FREQ_G     : positive := 156250000;
      -- Oscillator deviation envelope used for candidate qualification, in
      -- parts per billion. This bounds the raw oscillator, not an
      -- operator-installed PHC increment.
      MAX_OSCILLATOR_PPB_G : positive := 200000;
      -- Accepted intervals required before the ratio is published.
      QUALIFY_COUNT_G      : positive := 2);
   port (
      clk    : in sl;
      rst    : in sl;
      cancel : in sl;

      -- One accepted Sync sample with its local capture.
      inputValid  : in  sl;
      inputReady  : out sl;
      resultValid : out sl;
      resultReady : in  sl;
      syncSample  : in  PtpSyncSampleType;

      -- Minimum anchor span, in raw cycles, before a ratio is estimated.
      minimumSpan : in slv(63 downto 0);

      -- Published measurement. ratioValid gates consumers; ratioUpdate is a
      -- held flag on an accepted new estimate, qualified by resultValid.
      ratio       : out slv(63 downto 0);
      ratioValid  : out sl;
      ratioUpdate : out sl;
      -- Normalized corrected master time for the accepted sample, so the
      -- measurement path need not repeat this conversion. combinedCorrection
      -- is the signed sum of the two raw correction halves, which downstream
      -- E2E arithmetic consumes as one signed128 value.
      normalizedTime     : out slv(127 downto 0);
      combinedCorrection : out slv(127 downto 0);
      -- Local Sync RX capture minus corrected master time, the forward value
      -- the servo consumes. Published with sampleAccepted.
      forwardValue       : out slv(127 downto 0);
      sampleAccepted     : out sl;
      rejectedCount      : out slv(31 downto 0);

      -- Shared endpoint variable divider.
      divideValid       : out sl;
      divideReady       : in  sl                := '0';
      divideOperandA    : out slv(127 downto 0);
      divideOperandB    : out slv(79 downto 0);
      divideCancel      : out sl;
      divideResultValid : in  sl                := '0';
      divideResultReady : out sl;
      divideResultValue : in  slv(127 downto 0) := (others => '0');
      divideResultError : in  sl                := '0');
end entity PtpRateEstimator;

architecture rtl of PtpRateEstimator is

   -- Q16 elapsed master ns / Q3 elapsed raw cycles -> Q48 ns/cycle.
   constant RATIO_SHIFT_C : natural :=
      PTP_RATIO_FRAC_BITS_C+PTP_TICK_PHASE_BITS_C-PTP_TIME_FRAC_BITS_C;

   -- Nominal ratio and its acceptance margin, both Q48 ns per raw cycle.
   constant NOMINAL_C : unsigned(63 downto 0) :=
      shift_left(unsigned(ptpNominalIncrement(CLK_FREQ_G)), PTP_PHC_TO_RATIO_SHIFT_C);
   constant MARGIN_C : unsigned(63 downto 0) :=
      resize((resize(NOMINAL_C, 96)*to_unsigned(MAX_OSCILLATOR_PPB_G, 32))/
             to_unsigned(PTP_PPB_SCALE_C, 128), 64);

   -- Quarter weight on a new estimate after the first accepted one.
   constant FILTER_SHIFT_C : positive := 2;

   type StateType is (
      IDLE_S, EPOCH_REMOTE_S, EPOCH_LOCAL_S, EPOCH_WAIT_S,
      CORRECT_S, FORWARD_S, ACCEPT_S, ANCHOR_S,
      SPAN_S, ELAPSED_S, SHIFT_S, DIVIDE_S, DIVIDE_WAIT_S,
      QUALIFY_S, FILTER_S, PUBLISH_S, COMPLETE_S, RESULT_S);

   type EpochSelectType is (REMOTE_E, LOCAL_E);

   type RegType is record
      state       : StateType;
      epochSelect : EpochSelectType;
      inputReady  : sl;
      epochValid  : sl;
      epochSeconds : slv(47 downto 0);
      epochSubsecond : slv(47 downto 0);

      remoteTime : slv(79 downto 0);
      localTimestamp : slv(95 downto 0);
      minSpan : unsigned(66 downto 0);
      lastTime : signed(127 downto 0);
      lastRaw : unsigned(66 downto 0);
      valid : sl;
      currentTime : signed(127 downto 0);
      localTime   : signed(127 downto 0);
      forward     : signed(127 downto 0);
      anchorTime  : signed(127 downto 0);
      currentRaw  : unsigned(66 downto 0);
      anchorRaw   : unsigned(66 downto 0);
      elapsed     : signed(127 downto 0);
      scaled      : signed(127 downto 0);
      candidate   : signed(127 downto 0);
      correction  : signed(127 downto 0);

      anchorValid : sl;
      accepted    : sl;
      ratioCount  : natural range 0 to QUALIFY_COUNT_G;
      ratio       : slv(63 downto 0);
      ratioValid  : sl;
      ratioUpdate : sl;
      normalized  : slv(127 downto 0);
      combined    : slv(127 downto 0);
      rejected    : slv(31 downto 0);

      divOperandA : slv(127 downto 0);
      divOperandB : slv(79 downto 0);
      divValid    : sl;
      divReady    : sl;
   end record;

   constant REG_INIT_C : RegType := (
      state          => IDLE_S,
      epochSelect    => REMOTE_E,
      inputReady     => '0',
      epochValid     => '0',
      epochSeconds   => (others => '0'),
      epochSubsecond => (others => '0'),
      remoteTime     => (others => '0'),
      localTimestamp => (others => '0'),
      minSpan        => (others => '0'),
      lastTime       => (others => '0'),
      lastRaw        => (others => '0'),
      valid          => '0',
      currentTime    => (others => '0'),
      localTime      => (others => '0'),
      forward        => (others => '0'),
      anchorTime     => (others => '0'),
      currentRaw     => (others => '0'),
      anchorRaw      => (others => '0'),
      elapsed        => (others => '0'),
      scaled         => (others => '0'),
      candidate      => (others => '0'),
      correction     => (others => '0'),
      anchorValid    => '0',
      accepted       => '0',
      ratioCount     => 0,
      ratio          => slv(NOMINAL_C),
      ratioValid     => '0',
      ratioUpdate    => '0',
      normalized     => (others => '0'),
      combined       => (others => '0'),
      rejected       => (others => '0'),
      divOperandA    => (others => '0'),
      divOperandB    => (others => '0'),
      divValid       => '0',
      divReady       => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal epochReady       : sl;
   signal epochResultValid : sl;
   signal epochResultValue : slv(94 downto 0);

begin

   U_Epoch : entity surf.PtpEpochNormalize
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk          => clk,                -- [in]
         rst          => rst,                -- [in]
         cancel       => cancel,             -- [in]
         inputValid   => r.epochValid,       -- [in]
         inputReady   => epochReady,         -- [out]
         seconds      => r.epochSeconds,     -- [in]
         subsecondQ16 => r.epochSubsecond,   -- [in]
         resultValid  => epochResultValid,   -- [out]
         resultReady  => '1',                -- [in]
         resultValue  => epochResultValue);  -- [out]

   comb : process (all) is
      variable v         : RegType;
      variable span      : unsigned(66 downto 0);
      variable magnitude : unsigned(63 downto 0);
   begin
      v := r;
      v.inputReady := '0';
      v.divReady := '0';

      span := (others => '0');
      magnitude := (others => '0');

      if r.epochValid = '1' and epochReady = '1' then
         v.epochValid := '0';
      end if;

      case r.state is
         when IDLE_S =>
            v.inputReady := '1';

            if inputValid = '1' then
               v.accepted := '0';
               v.ratioUpdate := '0';
               v.remoteTime := syncSample.remoteTime;
               v.localTimestamp := syncSample.capture.timestamp;
               v.minSpan := unsigned(minimumSpan) & "000";
               v.currentRaw := unsigned(syncSample.capture.ticks) &
                               unsigned(syncSample.capture.tickPhase);
               -- The record carries the Sync and Follow_Up corrections as
               -- two separate raw signed64 halves. Sum them at full width;
               -- the one-step Follow_Up half is zero.
               v.correction := resize(signed(syncSample.correction(63 downto 0)), 128) +
                               resize(signed(syncSample.correction(127 downto 64)), 128);
               v.state := EPOCH_REMOTE_S;
            end if;

         when EPOCH_REMOTE_S =>
            -- Master origin: wire nanoseconds become Q16 by placement.
            v.epochSeconds := r.remoteTime(79 downto 32);
            v.epochSubsecond := r.remoteTime(31 downto 0) & x"0000";
            v.epochSelect := REMOTE_E;
            v.epochValid := '1';
            v.state := EPOCH_WAIT_S;

         when EPOCH_LOCAL_S =>
            -- Local Sync RX capture, already a Q16 subsecond.
            v.epochSeconds := r.localTimestamp(95 downto 48);
            v.epochSubsecond := r.localTimestamp(47 downto 0);
            v.epochSelect := LOCAL_E;
            v.epochValid := '1';
            v.state := EPOCH_WAIT_S;

         when EPOCH_WAIT_S =>
            if epochResultValid = '1' then
               if r.epochSelect = REMOTE_E then
                  v.currentTime := resize(signed(epochResultValue), 128);
                  v.state := CORRECT_S;
               else
                  v.localTime := resize(signed(epochResultValue), 128);
                  v.state := FORWARD_S;
               end if;
            end if;

         when CORRECT_S =>
            -- Correction addition intentionally wraps signed128.
            v.currentTime := r.currentTime+r.correction;
            v.state := EPOCH_LOCAL_S;

         when FORWARD_S =>
            -- forward = t2 - (t1 + cSync), the servo's measurement input.
            v.forward := r.localTime-r.currentTime;
            v.state := ACCEPT_S;

         when ACCEPT_S =>
            -- Compare with the last accepted sample, independently of the
            -- longer-lived rate anchor. Duplicate raw ticks remain invalid
            -- even if their fractional capture phase differs.
            if r.anchorValid = '1' and
               (r.currentTime <= r.lastTime or
                r.currentRaw(66 downto 3) <= r.lastRaw(66 downto 3)) then
               v.rejected := ptpSatInc(r.rejected);
               v.state := COMPLETE_S;
            else
               v.accepted := '1';
               v.lastTime := r.currentTime;
               v.lastRaw := r.currentRaw;
               v.normalized := slv(r.currentTime);
               v.combined := slv(r.correction);
               v.state := ANCHOR_S;
            end if;

         when ANCHOR_S =>
            if r.anchorValid = '0' then
               v.anchorTime := r.currentTime;
               v.anchorRaw := r.currentRaw;
               v.anchorValid := '1';
               v.state := COMPLETE_S;
            else
               v.state := SPAN_S;
            end if;

         when SPAN_S =>
            -- Retain the anchor below the configured minimum. Both operands
            -- use Q3 raw cycles; this is not a rejected sample.
            span := r.currentRaw-r.anchorRaw;

            if span < r.minSpan then
               v.state := COMPLETE_S;
            else
               v.state := ELAPSED_S;
            end if;

         when ELAPSED_S =>
            v.elapsed := r.currentTime-r.anchorTime;
            v.state := SHIFT_S;

         when SHIFT_S =>
            v.scaled := shift_left(r.elapsed, RATIO_SHIFT_C);
            v.state := DIVIDE_S;

         when DIVIDE_S =>
            -- The divisor is a positive measured raw span, qualified above.
            v.divOperandA := slv(r.scaled);
            v.divOperandB := slv(resize(r.currentRaw-r.anchorRaw, 80));
            v.divValid := '1';
            -- Every attempted interval advances the anchor, even if its ratio
            -- is rejected. Only a qualified estimate renews ratio freshness.
            v.anchorTime := r.currentTime;
            v.anchorRaw := r.currentRaw;
            v.state := DIVIDE_WAIT_S;

         when DIVIDE_WAIT_S =>
            if divideReady = '1' then
               v.divValid := '0';
            end if;

            v.divReady := not r.divValid;

            if r.divValid = '0' and divideResultValid = '1' then
               v.candidate := signed(divideResultValue);
               v.state := QUALIFY_S;

               if divideResultError = '1' then
                  v.rejected := ptpSatInc(r.rejected);
                  v.state := COMPLETE_S;
               end if;
            end if;

         when QUALIFY_S =>
            -- Bound the candidate to the oscillator envelope around nominal.
            -- A candidate outside it is rejected and does not renew freshness.
            if r.candidate < resize(signed('0' & (NOMINAL_C-MARGIN_C)), 128) or
               r.candidate > resize(signed('0' & (NOMINAL_C+MARGIN_C)), 128) then
               v.rejected := ptpSatInc(r.rejected);
               v.state := COMPLETE_S;
            elsif r.ratioCount = 0 then
               -- The first accepted estimate initializes the filter.
               v.ratio := slv(resize(r.candidate, 64));
               v.state := PUBLISH_S;
            else
               v.state := FILTER_S;
            end if;

         when FILTER_S =>
            -- filtered += round((new - filtered) / 4), a constant shift.
            v.ratio := slv(resize(
               signed(resize(unsigned(r.ratio), 65)) +
               resize(ptpRoundShiftExact(
                  r.candidate-resize(signed('0' & unsigned(r.ratio)), 128),
                  FILTER_SHIFT_C), 65), 64));
            v.state := PUBLISH_S;

         when PUBLISH_S =>
            v.ratioUpdate := '1';

            if r.ratioCount < QUALIFY_COUNT_G then
               v.ratioCount := r.ratioCount+1;
            end if;

            if v.ratioCount >= QUALIFY_COUNT_G then
               v.ratioValid := '1';
            end if;

            v.state := COMPLETE_S;

         when COMPLETE_S =>
            v.valid := '1';
            v.state := RESULT_S;

         when RESULT_S =>
            if resultReady = '1' then
               v.valid := '0';
               v.state := IDLE_S;
            end if;
      end case;

      if cancel = '1' then
         v.state := IDLE_S;
         v.epochValid := '0';
         v.divValid := '0';
         v.anchorValid := '0';
         v.ratioCount := 0;
         v.ratioValid := '0';
         v.ratioUpdate := '0';
         v.accepted := '0';
         v.valid := '0';
         v.divReady := '0';
         v.inputReady := '0';
      end if;

      -- Combinatorial outputs before the reset
      inputReady <= v.inputReady;
      divideResultReady <= v.divReady;

      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin <= v;

      resultValid <= r.valid;
      ratio <= r.ratio;
      ratioValid <= r.ratioValid;
      ratioUpdate <= r.ratioUpdate;
      normalizedTime <= r.normalized;
      combinedCorrection <= r.combined;
      forwardValue <= slv(r.forward);
      sampleAccepted <= r.accepted;
      rejectedCount <= r.rejected;

      divideValid <= r.divValid;
      divideOperandA <= r.divOperandA;
      divideOperandB <= r.divOperandB;
      divideCancel <= cancel;
   end process comb;

   seq : process (clk, rst) is
   begin
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
