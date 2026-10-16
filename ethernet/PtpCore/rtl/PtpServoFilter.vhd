-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Median filter over the most recent PTP path-delay samples.
--
-- Holds up to DEPTH_G populated signed Q16-nanosecond delay samples in a
-- circular history and publishes their median. A new sample is admitted only
-- when it is nonnegative, within the shared maximum path delay, and newer than
-- the stored sample, matching the admission this replaces.
--
-- Sorting uses one comparator walked over a fixed nine-pair network applied to
-- a separate destructible copy, so the circular history keeps arrival order.
-- Unpopulated positions sort above every real sample, which keeps the
-- lower-median startup behavior: with two populated samples the lower of the
-- two is published, not an average or a sentinel.
--
-- Input ready stays low across sorting, so the previously published median and
-- population remain stable until the new pair is published together. All ports
-- use clk. Input ready is combinational; the published median, population and
-- age are registered. Cancellation clears the population and replacement
-- pointer while retaining the last published median payload, so a consumer
-- reading the payload sees a value whose validity is reported by the count.
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
use surf.PtpServoPkg.all;
use surf.PtpPkg.all;

entity PtpServoFilter is
   generic (
      TPD_G          : time                  := 1 ns;
      RST_POLARITY_G : sl                    := '1';
      RST_ASYNC_G    : boolean               := false;
      DEPTH_G        : positive range 5 to 5 := 5);
   port (
      clk : in  sl;
      rst : in  sl;
      -- Clears population and replacement ownership; retains the last payload.
      cancel : in  sl;
      -- Delay-sample admission. The caller has already qualified generation
      -- and association age; this block applies the value and chronology
      -- rules. The sample arrives at the measurement record's full signed128
      -- width and is qualified there before being retained as signed64, which
      -- is lossless because an admitted value is bounded by maxPathDelay.
      request    : in  PtpFilterRequestType;
      inputReady : out sl;
      -- Published filter state. count is zero when no sample is valid.
      filterStatus : out PtpFilterStatusType;
      -- One-cycle strobe on an atomic median/population publication.
      filterUpdate : out sl;
      -- One-cycle strobe when an admitted sample fails the value or
      -- chronology rules. The owner counts these for its diagnostics.
      filterReject : out sl);
end entity PtpServoFilter;

architecture rtl of PtpServoFilter is

   -- The same nine sorting-network pairs are visited by one comparator.
   type MedianIndexArray is array (0 to 8) of natural range 0 to DEPTH_G-1;

   constant MEDIAN_LEFT_C  : MedianIndexArray := (0, 1, 0, 1, 0, 2, 1, 3, 2);
   constant MEDIAN_RIGHT_C : MedianIndexArray := (3, 4, 2, 3, 1, 4, 2, 4, 3);

   -- Unpopulated positions must sort above every admitted sample. Admitted
   -- delays are nonnegative, so the signed64 maximum is a valid sentinel.
   constant SENTINEL_C : signed(63 downto 0) := (63 => '0', others => '1');

   type SampleArray is array (natural range <>) of signed(63 downto 0);

   type StateType is (IDLE_S, SORT_COMPARE_S, PUBLISH_S);

   type RegType is record
      state        : StateType;
      history      : SampleArray(0 to DEPTH_G-1);
      sorted       : SampleArray(0 to DEPTH_G-1);
      population   : natural range 0 to DEPTH_G;
      writePtr     : natural range 0 to DEPTH_G-1;
      medianStep   : natural range MEDIAN_LEFT_C'range;
      inputReady   : sl;
      filterStatus : PtpFilterStatusType;
      update       : sl;
      rejected     : sl;
   end record;

   constant REG_INIT_C : RegType := (
      state        => IDLE_S,
      history      => (others => (others => '0')),
      sorted       => (others => (others => '0')),
      population   => 0,
      writePtr     => 0,
      medianStep   => 0,
      inputReady   => '0',
      filterStatus => PTP_FILTER_STATUS_INIT_C,
      update       => '0',
      rejected     => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (all) is
      variable v          : RegType;
      variable leftIndex  : natural range 0 to DEPTH_G-1;
      variable rightIndex : natural range 0 to DEPTH_G-1;
      variable swap       : signed(63 downto 0);
      variable median     : signed(63 downto 0);
   begin
      v            := r;
      v.inputReady := '0';
      v.update     := '0';
      v.rejected   := '0';

      leftIndex  := MEDIAN_LEFT_C(r.medianStep);
      rightIndex := MEDIAN_RIGHT_C(r.medianStep);
      swap       := (others => '0');
      median     := (others => '0');

      case r.state is
         when IDLE_S =>
            v.inputReady := '1';

            if request.valid = '1' then
               -- Nonnegative, within the shared limit, and newer than the
               -- stored sample. The comparison uses the full submitted width,
               -- so an out-of-range high word cannot be truncated away. A
               -- rejected sample is consumed, not retried.
               if signed(request.delayValue) >= 0 and
                  signed(request.delayValue) <= resize(signed(request.maxPathDelay), 128) and
                  (r.population = 0 or unsigned(request.ticks) > unsigned(r.filterStatus.ticks)) then
                  v.history(r.writePtr) := resize(signed(request.delayValue), 64);
                  v.writePtr           := (r.writePtr+1) mod DEPTH_G;
                  v.filterStatus.ticks := request.ticks;

                  if r.population < DEPTH_G then
                     v.population := r.population+1;
                  end if;

                  -- Sort a copy so arrival order survives in the history.
                  -- The replacement slot is always below the new population,
                  -- so this copy already includes the sample just stored.
                  for i in 0 to DEPTH_G-1 loop
                     if i < v.population then
                        v.sorted(i) := v.history(i);
                     else
                        v.sorted(i) := SENTINEL_C;
                     end if;
                  end loop;

                  -- Preserve ready on the accepting edge. The new state
                  -- withdraws it while sorting on subsequent cycles.
                  v.medianStep := 0;
                  v.state      := SORT_COMPARE_S;
               else
                  v.rejected := '1';
               end if;
            end if;

         when SORT_COMPARE_S =>
            -- One compare-and-swap per clock keeps the comparator single and
            -- the path short; nine steps complete the network.
            if r.sorted(leftIndex) > r.sorted(rightIndex) then
               swap := r.sorted(leftIndex);
               v.sorted(leftIndex) := r.sorted(rightIndex);
               v.sorted(rightIndex) := swap;
            end if;

            if r.medianStep = MEDIAN_LEFT_C'high then
               v.state := PUBLISH_S;
            else
               v.medianStep := r.medianStep+1;
            end if;

         when PUBLISH_S =>
            -- Lower median for an even population, matching the behavior this
            -- replaces. Population is published with its payload.
            median                    := r.sorted((r.population-1)/2);
            v.filterStatus.delayValue := slv(resize(median, 128));
            v.filterStatus.count      := toSlv(r.population, 3);
            v.filterStatus.valid      := '1';
            v.update                  := '1';
            v.state                   := IDLE_S;
      end case;

      -- Cancellation clears validity and replacement ownership but retains the
      -- prior median payload for diagnostic reads. The payload is restored
      -- explicitly because cancellation can coincide with the publication edge
      -- of an in-flight sort, which would otherwise commit a median whose
      -- population has just been invalidated.
      if cancel = '1' then
         v.state                   := IDLE_S;
         v.population              := 0;
         v.writePtr                := 0;
         v.medianStep              := 0;
         v.filterStatus.valid      := '0';
         v.filterStatus.delayValue := r.filterStatus.delayValue;
         v.filterStatus.count      := (others => '0');
         v.update                  := '0';
         v.rejected                := '0';
         v.inputReady              := '0';
      end if;

      -- Combinatorial outputs before the reset. Rejection accompanies the
      -- accepting edge that consumed the sample, like the ready beside it, so
      -- the owner's counter advances one register after the event rather than
      -- three. A registered strobe here would put the filter's register, the
      -- owner's counter and the owner's status output in series.
      inputReady   <= v.inputReady;
      filterReject <= v.rejected;

      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin          <= v;
      filterStatus <= r.filterStatus;
      filterUpdate <= r.update;
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
