-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Rate-corrected end-to-end PTP path-delay arithmetic.
--
-- Consumes an associated Sync sample and completed Delay_Req/Delay_Resp sample
-- from PtpPort. These supply master timestamps t1/t4, correction fields and
-- local RX/TX captures t2/t3. A qualified Q48 master-nanoseconds-per-raw-cycle
-- ratio converts the raw tick/phase separation between t2 and t3 into master
-- elapsed time, avoiding an assumption that the steered PHC rate stayed
-- constant during the exchange.
--
-- A local PtpMath engine serializes the wide multiplications and divisions.
-- Ingress and egress calibration are signed Q16 local PHC nanoseconds; each
-- displacement is converted using the increment saved with its own capture
-- before computing mean path delay. The returned measurement also carries the
-- forward term, generation, raw timestamp and sequence provenance for the
-- servo and diagnostics.
--
-- Latches all operands at input acceptance and holds the result until
-- consumed. Zero ratio/increments, generation mismatch, arithmetic failure and
-- negative or excessive delay mark the result as erroneous. Cancel aborts both
-- arithmetic and publication; the caller rejects errored results before
-- steering the clock.
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

entity PtpE2e is
   generic (
      TPD_G             : time             := 1 ns;
      RST_POLARITY_G    : sl               := '1';
      RST_ASYNC_G       : boolean          := false;
      INGRESS_LATENCY_G : slv(63 downto 0) := (others => '0');
      EGRESS_LATENCY_G  : slv(63 downto 0) := (others => '0'));
   port (
      clk          : in  sl;
      rst          : in  sl;
      cancel       : in  sl;
      inputValid   : in  sl;
      inputReady   : out sl;
      syncSample   : in  PtpSyncSampleType;
      delaySample  : in  PtpDelaySampleType;
      ratio        : in  slv(63 downto 0);
      maxPathDelay : in  slv(63 downto 0);
      resultValue  : out PtpMeasurementType;
      resultValid  : out sl;
      resultReady  : in  sl;
      resultError  : out sl);
end entity PtpE2e;

architecture rtl of PtpE2e is

   type StateType is (
      IDLE_S,
      ISSUE_S,
      WAIT_S,
      DONE_S);

   type OperationType is (
      ELAPSED_SCALE_S,
      INGRESS_SCALE_S,
      INGRESS_DIVIDE_S,
      EGRESS_SCALE_S,
      EGRESS_DIVIDE_S);

   type RegType is record
      state       : StateType;
      operation   : OperationType;
      a           : slv(127 downto 0);
      b           : slv(127 downto 0);
      divide      : sl;
      elapsed     : signed(127 downto 0);
      syncSample  : PtpSyncSampleType;
      delaySample : PtpDelaySampleType;
      ratio       : slv(63 downto 0);
      maximum     : slv(63 downto 0);
      resultValue : PtpMeasurementType;
      error       : sl;
   end record;

   constant REG_INIT_C : RegType := (
      state       => IDLE_S,
      operation   => ELAPSED_SCALE_S,
      a           => (others => '0'),
      b           => (others => '0'),
      divide      => '0',
      elapsed     => (others => '0'),
      syncSample  => PTP_SYNC_SAMPLE_INIT_C,
      delaySample => PTP_DELAY_SAMPLE_INIT_C,
      ratio       => (others => '0'),
      maximum     => (others => '0'),
      resultValue => PTP_MEASUREMENT_INIT_C,
      error       => '0');

   signal r          : RegType := REG_INIT_C;
   signal rin        : RegType;
   signal mathInput  : sl;
   signal mathReady  : sl;
   signal mathValid  : sl;
   signal mathResult : slv(127 downto 0);
   signal mathError  : sl;

begin

   U_Math : entity surf.PtpMath
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk             => clk,         -- [in]
         rst             => rst,         -- [in]
         cancel          => cancel,      -- [in]
         inputValid      => mathInput,   -- [in]
         inputReady      => mathReady,   -- [out]
         divide          => r.divide,    -- [in]
         roundNearest    => '1',         -- [in]
         operandA        => r.a,         -- [in]
         operandB        => r.b,         -- [in]
         resultValid     => mathValid,   -- [out]
         resultReady     => '1',         -- [in]
         resultValue     => mathResult,  -- [out]
         resultRemainder => open,        -- [out]
         resultError     => mathError);  -- [out]

   comb : process (r, rst, cancel, inputValid, syncSample, delaySample, ratio, maxPathDelay,
                   resultReady, mathReady, mathValid, mathResult, mathError) is
      variable v : RegType;
   begin
      v := r;

      -- Latch one complete exchange, run its arithmetic stages in order, then
      -- hold the result until consumed. Cancellation below overrides all stages.
      case r.state is
         when IDLE_S =>
            if inputValid = '1' then
               v             := REG_INIT_C;
               v.syncSample  := syncSample;
               v.delaySample := delaySample;
               v.ratio       := ratio;
               v.maximum     := maxPathDelay;
               v.a           := slv(ptpTickPhase(delaySample.capture)-ptpTickPhase(syncSample.capture));
               v.b           := slv(resize(unsigned(ratio), 128));
               v.state       := ISSUE_S;
               if unsigned(ratio) = 0 or unsigned(syncSample.capture.increment) = 0 or
                  unsigned(delaySample.capture.increment) = 0 or
                  syncSample.capture.generation /= delaySample.generation then
                  v.error := '1';
                  v.state := DONE_S;
               end if;
            end if;
         when ISSUE_S =>
            if mathReady = '1' then
               v.state := WAIT_S;
            end if;
         when WAIT_S =>
            if mathValid = '1' then
               v.state := ISSUE_S;
               if mathError = '1' then
                  v.error := '1';
                  v.state := DONE_S;
               else
                  case r.operation is
                     when ELAPSED_SCALE_S =>
                        -- Q3 raw cycles times Q48 ns/cycle -> Q16 nanoseconds.
                        v.elapsed   := ptpRoundShift(signed(mathResult), 35);
                        v.a         := slv(resize(signed(INGRESS_LATENCY_G), 128));
                        v.b         := slv(resize(unsigned(r.ratio), 128));
                        v.operation := INGRESS_SCALE_S;
                     when INGRESS_SCALE_S =>
                        v.a         := mathResult;
                        v.b         := slv(shift_left(resize(unsigned(r.syncSample.capture.increment), 128), 16));
                        v.divide    := '1';
                        v.operation := INGRESS_DIVIDE_S;
                     when INGRESS_DIVIDE_S =>
                        -- Calibration is in local PHC ns. Convert each plane
                        -- displacement with that capture's actual PHC increment,
                        -- including a rate replacement between RX and TX.
                        v.elapsed   := r.elapsed + signed(mathResult);
                        v.a         := slv(resize(signed(EGRESS_LATENCY_G), 128));
                        v.b         := slv(resize(unsigned(r.ratio), 128));
                        v.divide    := '0';
                        v.operation := EGRESS_SCALE_S;
                     when EGRESS_SCALE_S =>
                        v.a         := mathResult;
                        v.b         := slv(shift_left(resize(unsigned(r.delaySample.capture.increment), 128), 16));
                        v.divide    := '1';
                        v.operation := EGRESS_DIVIDE_S;
                     when EGRESS_DIVIDE_S =>
                        v.elapsed                   := r.elapsed + signed(mathResult);
                        v.resultValue.delayValue    := slv(ptpRoundShift(ptpWireTimeQ16(r.delaySample.remoteTime) -
                           resize(signed(r.delaySample.correction), 128) -
                           ptpWireTimeQ16(r.syncSample.remoteTime) - signed(r.syncSample.correction) - v.elapsed, 1));
                        v.resultValue.isDelay       := '1';
                        v.resultValue.generation    := r.delaySample.generation;
                        v.resultValue.ticks         := r.delaySample.capture.ticks;
                        v.resultValue.syncSequence  := r.syncSample.sequenceId;
                        v.resultValue.delaySequence := r.delaySample.sequenceId;
                        v.resultValue.forward       := slv(ptpTimeQ16(r.syncSample.capture.timestamp) -
                           ptpWireTimeQ16(r.syncSample.remoteTime) - signed(r.syncSample.correction));
                        v.resultValue.ratio         := r.ratio;
                        v.resultValue.ratioValid    := '1';
                        if signed(v.resultValue.delayValue) < 0 or signed(v.resultValue.delayValue) > signed(r.maximum) then
                           v.error := '1';
                        end if;
                        v.state := DONE_S;
                  end case;
               end if;
            end if;
         when DONE_S =>
            if resultReady = '1' then
               v.state := IDLE_S;
            end if;
      end case;
      if cancel = '1' or (not RST_ASYNC_G and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;
      mathInput <= '0';
      if r.state = ISSUE_S then
         mathInput <= '1';
      end if;
      rin         <= v;
      inputReady  <= '0';
      resultValid <= '0';
      if cancel = '0' and rst /= RST_POLARITY_G then
         if r.state = IDLE_S then
            inputReady <= '1';
         elsif r.state = DONE_S then
            resultValid <= '1';
         end if;
      end if;
      resultValue <= r.resultValue;
      resultError <= r.error;
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
