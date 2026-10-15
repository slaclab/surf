-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Rate-corrected end-to-end PTP path-delay arithmetic.
--
-- Consumes an associated Sync sample and a completed Delay_Req/Delay_Resp
-- sample from PtpProtocolEngine. These supply master timestamps t1/t4,
-- correction fields and the local RX/TX captures t2/t3. A qualified Q48
-- master-nanoseconds-per-raw-cycle ratio converts the raw tick/phase
-- separation between t2 and t3 into master elapsed time, so the measurement
-- does not assume the steered PHC rate stayed constant during the exchange.
--
-- The published equation is
--   forward = t2 - (t1 + cSync)
--   elapsed = round(rawTicks(t2..t3) * ratio / 2**35) + calibration
--   delay   = round(((t4 - cDelay) - (t1 + cSync) - elapsed) / 2)
-- with each calibration plane rescaling its configured latency into master
-- time through its own captured PHC increment.
--
-- Arithmetic is fixed-function and local: one epoch normalizer converts the
-- seconds/subsecond pairs, one reused product forms the elapsed and
-- calibration products, and the shared endpoint divider performs the two
-- calibration divisions. In production the normalized-Sync history supplies
-- the forward value and corrected Sync directly, so only the Delay_Resp
-- conversion runs here; the standalone leaf normalizes all three.
--
-- Timestamp and correction additions intentionally wrap signed 128 bits, while
-- products and divisions stay checked: a product that does not fit signed 128
-- bits is rejected before its rounding shift. A zero ratio or captured
-- increment, and a generation mismatch, remain errors. Negative or excessive
-- path delay is rejected before publication.
--
-- All ports use clk. Input ready is combinational; the published measurement
-- and its valid are registered and held until resultReady. Cancellation
-- invalidates only this owner's work and publication, independently of
-- unrelated arithmetic and PHC ticks.
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
      EGRESS_LATENCY_G  : slv(63 downto 0) := (others => '0');
      NORMALIZED_SYNC_G : boolean          := false);
   port (
      clk    : in sl;
      rst    : in sl;
      cancel : in sl;

      -- Private history stream: words 0..3 the forward value, 4..7 the
      -- corrected Sync time in Q16 nanoseconds. Only used when the production
      -- normalized-Sync path supplies them.
      normalizedValid : in  sl               := '0';
      normalizedReady : out sl;
      normalizedWord  : in  slv(2 downto 0)  := (others => '0');
      normalizedData  : in  slv(31 downto 0) := (others => '0');

      inputValid   : in  sl;
      inputReady   : out sl;
      syncSample   : in  PtpSyncSampleType;
      delaySample  : in  PtpDelaySampleType;
      ratio        : in  slv(63 downto 0);
      maxPathDelay : in slv(63 downto 0);

      resultValue : out PtpMeasurementType;
      -- Registered valid; transfer requires valid/ready high and cancel/reset
      -- inactive.
      resultValid : out sl;
      resultReady : in  sl;
      resultError : out sl;

      -- Shared endpoint variable divider for the calibration planes.
      divideValid       : out sl;
      divideReady       : in  sl                := '0';
      divideOperandA    : out slv(127 downto 0);
      divideOperandB    : out slv(79 downto 0);
      divideCancel      : out sl;
      divideResultValid : in  sl                := '0';
      divideResultReady : out sl;
      divideResultValue : in  slv(127 downto 0) := (others => '0');
      divideResultError : in  sl                := '0');
end entity PtpE2e;

architecture rtl of PtpE2e is

   -- Raw Q3 tick/phase separation scaled by the Q48 ratio reaches Q16 master
   -- nanoseconds after this shift.
   constant ELAPSED_SHIFT_C : natural := PTP_TICK_PHASE_BITS_C+PTP_RATIO_FRAC_BITS_C-PTP_TIME_FRAC_BITS_C;

   -- Both calibration planes are elaboration constants, so a zero plane
   -- removes its product, division and addition entirely.
   constant INGRESS_ACTIVE_C : boolean := signed(INGRESS_LATENCY_G) /= 0;
   constant EGRESS_ACTIVE_C  : boolean := signed(EGRESS_LATENCY_G) /= 0;

   -- Product operands: a signed68 raw separation or signed64 latency by the
   -- unsigned64 ratio. The full product is checked against signed128.
   constant PRODUCT_A_C : positive := 68;
   constant PRODUCT_B_C : positive := 64;

   type StateType is (
      IDLE_S,
      EPOCH_LOCAL_S, EPOCH_SYNC_S, EPOCH_REMOTE_S, EPOCH_WAIT_S,
      CORRECT_SYNC_S, CORRECT_REMOTE_S,
      ELAPSED_PRODUCT_S, PRODUCT_WAIT_S, ELAPSED_SHIFT_S,
      RX_PRODUCT_S, RX_DIVIDE_S, DIVIDE_WAIT_S, RX_ADD_S,
      TX_PRODUCT_S, TX_DIVIDE_S, TX_ADD_S,
      FORWARD_S, REMOTE_DIFF_S, DELAY_DIFF_S, DELAY_HALF_S, DELAY_CHECK_S,
      DONE_S);

   type EpochSelectType is (LOCAL_E, SYNC_E, REMOTE_E);

   type RegType is record
      state       : StateType;
      returnState : StateType;
      epochSelect : EpochSelectType;
      inputReady  : sl;
      historyReady : sl;

      -- Named working values, all Q16 nanoseconds unless stated.
      localTime   : signed(127 downto 0);
      syncTime    : signed(127 downto 0);
      remoteTime  : signed(127 downto 0);
      forwardValue : signed(127 downto 0);
      elapsedValue : signed(127 downto 0);
      productValue : signed(127 downto 0);
      rawSeparation : signed(67 downto 0);

      -- Every operand is captured at the accepting edge. The producer is
      -- free to change its sample records immediately afterward, so reading
      -- them in a later state would use perturbed values.
      ratio          : unsigned(63 downto 0);
      rxIncrement    : unsigned(63 downto 0);
      txIncrement    : unsigned(63 downto 0);
      maximum        : signed(63 downto 0);
      localSeconds   : slv(47 downto 0);
      localSubsecond : slv(47 downto 0);
      syncSeconds    : slv(47 downto 0);
      syncSubsecond  : slv(47 downto 0);
      remoteSeconds  : slv(47 downto 0);
      remoteSubsecond : slv(47 downto 0);
      syncCorrection : signed(127 downto 0);
      delayCorrection : signed(63 downto 0);

      epochValid  : sl;
      epochSeconds : slv(47 downto 0);
      epochSubsecond : slv(47 downto 0);

      mulA        : slv(PRODUCT_A_C-1 downto 0);
      mulB        : slv(PRODUCT_B_C-1 downto 0);
      mulValid    : sl;
      mulTake     : sl;
      mulPending  : sl;

      divOperandA : slv(127 downto 0);
      divOperandB : slv(79 downto 0);
      divValid    : sl;
      divReady    : sl;

      resultValue : PtpMeasurementType;
      resultValid : sl;
      error       : sl;
   end record;

   constant REG_INIT_C : RegType := (
      state          => IDLE_S,
      returnState    => IDLE_S,
      epochSelect    => LOCAL_E,
      inputReady     => '0',
      historyReady   => '0',
      localTime      => (others => '0'),
      syncTime       => (others => '0'),
      remoteTime     => (others => '0'),
      forwardValue   => (others => '0'),
      elapsedValue   => (others => '0'),
      productValue   => (others => '0'),
      rawSeparation  => (others => '0'),
      ratio          => (others => '0'),
      rxIncrement    => (others => '0'),
      txIncrement    => (others => '0'),
      maximum        => (others => '0'),
      localSeconds   => (others => '0'),
      localSubsecond => (others => '0'),
      syncSeconds    => (others => '0'),
      syncSubsecond  => (others => '0'),
      remoteSeconds  => (others => '0'),
      remoteSubsecond => (others => '0'),
      syncCorrection => (others => '0'),
      delayCorrection => (others => '0'),
      epochValid     => '0',
      epochSeconds   => (others => '0'),
      epochSubsecond => (others => '0'),
      mulA           => (others => '0'),
      mulB           => (others => '0'),
      mulValid       => '0',
      mulTake        => '0',
      mulPending     => '0',
      divOperandA    => (others => '0'),
      divOperandB    => (others => '0'),
      divValid       => '0',
      divReady       => '0',
      resultValue    => PTP_MEASUREMENT_INIT_C,
      resultValid    => '0',
      error          => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal epochReady       : sl;
   signal epochResultValid : sl;
   signal epochResultValue : slv(94 downto 0);
   signal mulReady         : sl;
   signal mulResultValid   : sl;
   signal mulResultReady   : sl;
   signal mulOverflow      : sl;
   signal mulResult        : slv(PRODUCT_A_C+PRODUCT_B_C-1 downto 0);

begin

   -- One normalizer serves every seconds/subsecond conversion in this chain.
   U_Epoch : entity surf.PtpEpochNormalize
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk          => clk,               -- [in]
         rst          => rst,               -- [in]
         cancel       => cancel,            -- [in]
         inputValid   => r.epochValid,      -- [in]
         inputReady   => epochReady,        -- [out]
         seconds      => r.epochSeconds,    -- [in]
         subsecondQ16 => r.epochSubsecond,  -- [in]
         resultValid  => epochResultValid,  -- [out]
         resultReady  => '1',               -- [in]
         resultValue  => epochResultValue);  -- [out]

   U_Product : entity surf.PtpLimbProduct
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         A_G            => PRODUCT_A_C,
         B_G            => PRODUCT_B_C)
      port map (
         clk         => clk,             -- [in]
         rst         => rst,             -- [in]
         cancel      => cancel,          -- [in]
         inputValid  => r.mulValid,      -- [in]
         inputReady  => mulReady,        -- [out]
         operandA    => r.mulA,          -- [in]
         operandB    => r.mulB,          -- [in]
         resultValid => mulResultValid,  -- [out]
         resultReady => mulResultReady,  -- [in]
         resultValue => mulResult,       -- [out]
         overflow    => mulOverflow);    -- [out]

   comb : process (all) is
      variable v          : RegType;
      variable separation : signed(67 downto 0);
      variable delayHalf  : signed(127 downto 0);
   begin
      v := r;
      v.inputReady := '0';
      v.historyReady := '0';
      v.mulTake := '0';
      v.divReady := '0';

      separation := (others => '0');
      delayHalf := (others => '0');

      -- Release an accepted epoch request as soon as the normalizer takes it.
      if r.epochValid = '1' and epochReady = '1' then
         v.epochValid := '0';
      end if;

      case r.state is
         when IDLE_S =>
            -- The production history stream fills the forward and corrected
            -- Sync values outside a measurement.
            if NORMALIZED_SYNC_G and normalizedValid = '1' then
               v.historyReady := '1';

               if unsigned(normalizedWord) < 4 then
                  v.forwardValue(32*to_integer(unsigned(normalizedWord))+31 downto
                                 32*to_integer(unsigned(normalizedWord))) := signed(normalizedData);
               else
                  v.syncTime(32*(to_integer(unsigned(normalizedWord))-4)+31 downto
                             32*(to_integer(unsigned(normalizedWord))-4)) := signed(normalizedData);
               end if;
            end if;

            v.inputReady := '1';

            if inputValid = '1' then
               v.resultValue := PTP_MEASUREMENT_INIT_C;
               v.resultValue.isDelay := '1';
               v.resultValue.generation := delaySample.generation;
               v.resultValue.ticks := delaySample.capture.ticks;
               v.resultValue.syncSequence := syncSample.sequenceId;
               v.resultValue.delaySequence := delaySample.sequenceId;
               v.resultValue.ratio := ratio;
               v.resultValue.ratioValid := '1';
               v.error := '0';

               v.ratio := unsigned(ratio);
               v.rxIncrement := unsigned(syncSample.capture.increment);
               v.txIncrement := unsigned(delaySample.capture.increment);
               v.maximum := signed(maxPathDelay);

               -- Local Sync RX capture already carries a Q16 subsecond; the
               -- two wire times carry integer nanoseconds that become Q16 by
               -- placement.
               v.localSeconds := syncSample.capture.timestamp(95 downto 48);
               v.localSubsecond := syncSample.capture.timestamp(47 downto 0);
               v.syncSeconds := syncSample.remoteTime(79 downto 32);
               v.syncSubsecond := syncSample.remoteTime(31 downto 0) & x"0000";
               v.remoteSeconds := delaySample.remoteTime(79 downto 32);
               v.remoteSubsecond := delaySample.remoteTime(31 downto 0) & x"0000";
               v.syncCorrection := signed(syncSample.correction);
               v.delayCorrection := signed(delaySample.correction);

               -- The raw separation is formed from the two captures directly;
               -- both are unsigned67 Q3 tick/phase values.
               v.rawSeparation :=
                  signed(resize(unsigned(delaySample.capture.ticks) &
                                unsigned(delaySample.capture.tickPhase), 68)) -
                  signed(resize(unsigned(syncSample.capture.ticks) &
                                unsigned(syncSample.capture.tickPhase), 68));

               if NORMALIZED_SYNC_G then
                  v.state := EPOCH_REMOTE_S;
               else
                  v.state := EPOCH_LOCAL_S;
               end if;

               -- A zero ratio or captured increment cannot produce a
               -- measurement, and a generation mismatch invalidates it.
               if unsigned(ratio) = 0 or
                  unsigned(syncSample.capture.increment) = 0 or
                  unsigned(delaySample.capture.increment) = 0 or
                  syncSample.capture.generation /= delaySample.generation then
                  v.error := '1';
                  v.resultValid := '1';
                  v.state := DONE_S;
               end if;
            end if;

         when EPOCH_LOCAL_S =>
            v.epochSeconds := r.localSeconds;
            v.epochSubsecond := r.localSubsecond;
            v.epochSelect := LOCAL_E;
            v.epochValid := '1';
            v.returnState := EPOCH_SYNC_S;
            v.state := EPOCH_WAIT_S;

         when EPOCH_SYNC_S =>
            v.epochSeconds := r.syncSeconds;
            v.epochSubsecond := r.syncSubsecond;
            v.epochSelect := SYNC_E;
            v.epochValid := '1';
            v.returnState := CORRECT_SYNC_S;
            v.state := EPOCH_WAIT_S;

         when EPOCH_REMOTE_S =>
            v.epochSeconds := r.remoteSeconds;
            v.epochSubsecond := r.remoteSubsecond;
            v.epochSelect := REMOTE_E;
            v.epochValid := '1';
            v.returnState := CORRECT_REMOTE_S;
            v.state := EPOCH_WAIT_S;

         when EPOCH_WAIT_S =>
            if epochResultValid = '1' then
               case r.epochSelect is
                  when LOCAL_E =>
                     v.localTime := resize(signed(epochResultValue), 128);
                  when SYNC_E =>
                     v.syncTime := resize(signed(epochResultValue), 128);
                  when REMOTE_E =>
                     v.remoteTime := resize(signed(epochResultValue), 128);
               end case;

               v.state := r.returnState;
            end if;

         when CORRECT_SYNC_S =>
            -- Correction additions intentionally wrap signed128.
            v.syncTime := r.syncTime+r.syncCorrection;
            v.state := EPOCH_REMOTE_S;

         when CORRECT_REMOTE_S =>
            v.remoteTime := r.remoteTime-resize(r.delayCorrection, 128);
            v.state := ELAPSED_PRODUCT_S;

         when ELAPSED_PRODUCT_S =>
            v.mulA := slv(r.rawSeparation);
            v.mulB := slv(r.ratio);
            v.mulValid := '1';
            v.returnState := ELAPSED_SHIFT_S;
            v.state := PRODUCT_WAIT_S;

         when PRODUCT_WAIT_S =>
            -- The product asserts ready only while idle, so valid-and-ready
            -- is the accepting edge. Clear the request there and only then
            -- look at the result; the leaf holds its previous result until
            -- consumed, so an early test would latch the prior product.
            if r.mulValid = '1' and mulReady = '1' then
               v.mulValid := '0';
               v.mulPending := '1';
            end if;

            if r.mulPending = '1' and mulResultValid = '1' then
               v.mulPending := '0';
               v.mulTake := '1';
               v.productValue := resize(signed(mulResult), 128);
               v.state := r.returnState;

               -- Reject an overflowing product before its rounding shift, so
               -- the discarded-measurement set is unchanged.
               if mulOverflow = '1' then
                  v.error := '1';
                  v.resultValid := '1';
                  v.state := DONE_S;
               end if;
            end if;

         when ELAPSED_SHIFT_S =>
            v.elapsedValue := resize(
               ptpRoundShiftExact(r.productValue, ELAPSED_SHIFT_C), 128);
            v.state := FORWARD_S;

            if INGRESS_ACTIVE_C then
               v.state := RX_PRODUCT_S;
            elsif EGRESS_ACTIVE_C then
               v.state := TX_PRODUCT_S;
            end if;

         when RX_PRODUCT_S =>
            v.mulA := slv(resize(signed(INGRESS_LATENCY_G), PRODUCT_A_C));
            v.mulB := slv(r.ratio);
            v.mulValid := '1';
            v.returnState := RX_DIVIDE_S;
            v.state := PRODUCT_WAIT_S;

         when RX_DIVIDE_S =>
            -- Each plane converts through its own captured increment; the
            -- current or nominal increment would change the measurement.
            v.divOperandA := slv(r.productValue);
            v.divOperandB := slv(shift_left(resize(r.rxIncrement, 80),
                                            PTP_TIME_FRAC_BITS_C));
            v.divValid := '1';
            v.returnState := RX_ADD_S;
            v.state := DIVIDE_WAIT_S;

         when DIVIDE_WAIT_S =>
            if divideReady = '1' then
               v.divValid := '0';
            end if;

            v.divReady := '1';

            if r.divValid = '0' and divideResultValid = '1' then
               v.productValue := signed(divideResultValue);
               v.state := r.returnState;

               if divideResultError = '1' then
                  v.error := '1';
                  v.resultValid := '1';
                  v.state := DONE_S;
               end if;
            end if;

         when RX_ADD_S =>
            v.elapsedValue := r.elapsedValue+r.productValue;
            v.state := FORWARD_S;

            if EGRESS_ACTIVE_C then
               v.state := TX_PRODUCT_S;
            end if;

         when TX_PRODUCT_S =>
            v.mulA := slv(resize(signed(EGRESS_LATENCY_G), PRODUCT_A_C));
            v.mulB := slv(r.ratio);
            v.mulValid := '1';
            v.returnState := TX_DIVIDE_S;
            v.state := PRODUCT_WAIT_S;

         when TX_DIVIDE_S =>
            v.divOperandA := slv(r.productValue);
            v.divOperandB := slv(shift_left(resize(r.txIncrement, 80),
                                            PTP_TIME_FRAC_BITS_C));
            v.divValid := '1';
            v.returnState := TX_ADD_S;
            v.state := DIVIDE_WAIT_S;

         when TX_ADD_S =>
            v.elapsedValue := r.elapsedValue+r.productValue;
            v.state := FORWARD_S;

         when FORWARD_S =>
            -- In normalized mode the history already supplied the forward
            -- value; the standalone leaf forms it here.
            if not NORMALIZED_SYNC_G then
               v.forwardValue := r.localTime-r.syncTime;
            end if;

            v.state := REMOTE_DIFF_S;

         when REMOTE_DIFF_S =>
            v.remoteTime := r.remoteTime-r.syncTime;
            v.state := DELAY_DIFF_S;

         when DELAY_DIFF_S =>
            v.elapsedValue := r.remoteTime-r.elapsedValue;
            v.state := DELAY_HALF_S;

         when DELAY_HALF_S =>
            v.elapsedValue := resize(ptpRoundShiftExact(r.elapsedValue, 1), 128);
            v.state := DELAY_CHECK_S;

         when DELAY_CHECK_S =>
            -- Negative or excessive path delay is rejected before publication.
            v.resultValue.forward := slv(r.forwardValue);
            v.resultValue.delayValue := slv(r.elapsedValue);
            v.resultValid := '1';
            v.state := DONE_S;

            if r.elapsedValue < 0 or
               r.elapsedValue > resize(r.maximum, 128) then
               v.error := '1';
            end if;

         when DONE_S =>
            if resultReady = '1' then
               v.resultValid := '0';
               v.state := IDLE_S;
            end if;
      end case;

      if cancel = '1' then
         v := REG_INIT_C;
      end if;

      -- Combinatorial outputs before the reset
      inputReady <= v.inputReady;
      normalizedReady <= v.historyReady;
      mulResultReady <= v.mulTake;
      divideResultReady <= v.divReady;

      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin <= v;

      resultValue <= r.resultValue;
      resultValid <= r.resultValid;
      resultError <= r.error;

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
