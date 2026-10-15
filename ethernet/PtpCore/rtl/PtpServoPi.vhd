-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PTP proportional/integral loop and PHC command generation.
--
-- Consumes one qualified forward (Sync) measurement together with the current
-- filtered delay and rate ratio, then drives the PHC's numerical increment.
-- Local-minus-master offset is forward time minus filtered delay and configured
-- asymmetry. No output of this module tunes the oscillator supplying clk.
--
-- Two acquisition paths share the offset calculation. While time is invalid and
-- stepping is permitted, an offset beyond the step threshold is converted to a
-- seconds/fraction phase adjustment through the shared SECOND service and
-- applied as one PHASE command, bypassing the loop. Otherwise the qualified
-- raw-clock ratio bootstraps frequency control and the PI loop runs.
--
-- Arithmetic is fixed-function with named local state. One reused multiplier
-- serves both gains, the bootstrap constant product and both nominal products;
-- the constant conversions use local BILLION and NOMINAL converters and the
-- shared SECOND service. Each rounding, clamp, anti-windup and selection step
-- is separately registered: combining them into one evaluation is what made an
-- earlier candidate miss setup by a wide margin.
--
-- Overflow policy is preserved. A product that does not fit signed 128 bits is
-- rejected before any rounding shift, so the set of discarded measurements is
-- unchanged; a representable shifted result is never substituted for a rejected
-- intermediate.
--
-- Frequency and sample history commit only on a successful RATE acknowledgement.
-- Expiry, cancellation and generation changes stay live during all arithmetic.
-- Input ready is combinational so cancellation suppresses admission on its own
-- edge; commands, expiry and status are registered. All ports use clk.
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

entity PtpServoPi is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      CLK_FREQ_G     : positive := 156250000);
   port (
      clk    : in sl;
      rst    : in sl;
      -- Discards pending arithmetic and revokes an uncommitted command.
      cancel : in sl;
      enable : in sl;

      -- Active configuration and shared limits, read directly from their owner.
      config       : in PtpServoConfigType;
      sharedConfig : in PtpSharedConfigType;
      phcStatus    : in PtpPhcStatusType;

      -- One forward measurement with the filter state it is evaluated against.
      inputValid       : in  sl;
      inputReady       : out sl;
      sampleTicks      : in  slv(63 downto 0);
      sampleGeneration : in  slv(31 downto 0);
      forwardValue     : in  slv(127 downto 0);
      ratio            : in  slv(63 downto 0);
      ratioValid       : in  sl;
      filteredDelay    : in  slv(127 downto 0);
      filterValid      : in  sl;
      filterTicks      : in  slv(63 downto 0);

      -- PHC command lifecycle and registered validity revocation.
      commandMaster : out PtpPhcCommandMasterType;
      commandSlave  : in  PtpPhcCommandSlaveType;
      expireTime    : out sl;
      status        : out PtpServoStatusType;
      -- One-cycle strobes for the owner's publication bank.
      offsetUpdate  : out sl;
      rateUpdate    : out sl;

      -- Shared SECOND service; cancellation is owner-local.
      secondValid       : out sl;
      secondReady       : in  sl;
      secondRound       : out sl;
      secondOperand     : out slv(127 downto 0);
      secondCancel      : out sl;
      secondResultValid : in  sl;
      secondResultReady : out sl;
      secondQuotient    : in  slv(127 downto 0);
      secondRemainder   : in  slv(127 downto 0));
end entity PtpServoPi;

architecture rtl of PtpServoPi is

   constant NOMINAL_C : unsigned(63 downto 0) := unsigned(ptpNominalIncrement(CLK_FREQ_G));

   -- Offset Q16 * gain Q30 -> ppb Q16. Integration additionally multiplies by
   -- elapsed seconds carrying the PHC addend's Q32 precision.
   constant PROPORTIONAL_SHIFT_C : natural := PTP_TIME_FRAC_BITS_C+PTP_GAIN_FRAC_BITS_C-PTP_PPB_FRAC_BITS_C;
   constant INTEGRAL_SHIFT_C     : natural := PROPORTIONAL_SHIFT_C+PTP_PHC_FRAC_BITS_C;

   -- Product operand bounds proven over the admitted ranges. The widest case
   -- is the integral gain product by the elapsed interval.
   constant PRODUCT_A_C : positive := 96;
   constant PRODUCT_B_C : positive := 95;

   -- Local constant converters. Widths follow the per-site dividend proofs:
   -- the integral interval product is below 2**97, and the bootstrap and rate
   -- numerators are below 2**95 at both supported clocks.
   constant BILLION_WIDTH_C : positive := 98;
   constant NOMINAL_WIDTH_C : positive := 95;

   function clamp (value : signed; ppb : slv(31 downto 0)) return signed is
      variable limit : signed(127 downto 0);
   begin
      limit := signed(shift_left(resize(unsigned(ppb), 128), PTP_PPB_FRAC_BITS_C));

      if resize(value, 128) > limit then
         return limit;
      elsif resize(value, 128) < -limit then
         return -limit;
      end if;

      return resize(value, 128);
   end function;

   type StateType is (
      IDLE_S,
      OFFSET_DELAY_S, OFFSET_ASYMMETRY_S, OFFSET_PUBLISH_S, OFFSET_DECIDE_S,
      PRODUCT_WAIT_S, DIVIDE_WAIT_S,
      PHASE_REQUEST_S, PHASE_RESULT_S,
      PROPORTIONAL_DONE_S,
      BOOT_PRODUCT_S, BOOT_DONE_S, BOOT_SUBTRACT_S,
      INTERVAL_PRODUCT_S, INTERVAL_DONE_S, GAIN_DONE_S, INTEGRAL_DONE_S,
      FREQUENCY_PROPOSE_S, FREQUENCY_LIMIT_S,
      RATE_TRIAL_SUM_S, RATE_TRIAL_CHECK_S, INTEGRATE_SELECT_S,
      RATE_SUM_S, RATE_LIMIT_S, RATE_PUBLISH_S,
      RATE_START_S, RATE_PRODUCT_S, RATE_COMMAND_S,
      COMMAND_S, ACK_S);

   -- Converter selection for the divide helper.
   constant SECOND_ID_C  : natural := 0;
   constant BILLION_ID_C : natural := 1;
   constant NOMINAL_ID_C : natural := 2;

   type RegType is record
      state              : StateType;
      returnState        : StateType;
      status             : PtpServoStatusType;
      command            : PtpPhcCommandMasterType;
      sampleTicks        : slv(63 downto 0);
      lastTicks          : slv(63 downto 0);
      generation         : slv(31 downto 0);
      ratio              : unsigned(63 downto 0);
      forwardValue       : signed(127 downto 0);
      delayValue         : signed(127 downto 0);
      offsetWide         : signed(127 downto 0);
      offsetValue        : signed(63 downto 0);
      proportional       : signed(63 downto 0);
      interval           : unsigned(94 downto 0);
      frequency          : signed(63 downto 0);
      candidate          : signed(63 downto 0);
      mathValue          : signed(127 downto 0);
      remainderValue     : signed(127 downto 0);
      correction         : signed(66 downto 0);
      proposed           : signed(67 downto 0);
      trial              : signed(64 downto 0);
      correctionNegative : sl;
      correctionNonzero  : sl;
      outward            : sl;
      stepping           : sl;
      mulA               : slv(PRODUCT_A_C-1 downto 0);
      mulB               : slv(PRODUCT_B_C-1 downto 0);
      mulValid           : sl;
      mulTake            : sl;
      mulPending         : sl;
      divOperand         : slv(127 downto 0);
      divRound           : sl;
      divKind            : natural range 0 to 2;
      divValid           : sl;
      arithmeticCancel   : sl;
      secondResultReady  : sl;
      haveSample         : sl;
      tracking           : sl;
      integrating        : sl;
      holding            : sl;
      holdApplied        : sl;
      inputReady         : sl;
      expireTime         : sl;
      offsetUpdate       : sl;
      rateUpdate         : sl;
      inLock             : sl;
      outUnlock          : sl;
      good               : unsigned(7 downto 0);
      bad                : unsigned(7 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      state              => IDLE_S,
      returnState        => IDLE_S,
      status             => PTP_SERVO_STATUS_INIT_C,
      command            => PTP_PHC_COMMAND_MASTER_INIT_C,
      sampleTicks        => (others => '0'),
      lastTicks          => (others => '0'),
      generation         => (others => '0'),
      ratio              => (others => '0'),
      forwardValue       => (others => '0'),
      delayValue         => (others => '0'),
      offsetWide         => (others => '0'),
      offsetValue        => (others => '0'),
      proportional       => (others => '0'),
      interval           => (others => '0'),
      frequency          => (others => '0'),
      candidate          => (others => '0'),
      mathValue          => (others => '0'),
      remainderValue     => (others => '0'),
      correction         => (others => '0'),
      proposed           => (others => '0'),
      trial              => (others => '0'),
      correctionNegative => '0',
      correctionNonzero  => '0',
      outward            => '0',
      stepping           => '0',
      mulA               => (others => '0'),
      mulB               => (others => '0'),
      mulValid           => '0',
      mulTake            => '0',
      mulPending         => '0',
      divOperand         => (others => '0'),
      divRound           => '1',
      divKind            => SECOND_ID_C,
      divValid           => '0',
      arithmeticCancel   => '0',
      secondResultReady  => '0',
      haveSample         => '0',
      tracking           => '0',
      integrating        => '0',
      holding            => '0',
      holdApplied        => '0',
      inputReady         => '0',
      expireTime         => '0',
      offsetUpdate       => '0',
      rateUpdate         => '0',
      inLock             => '0',
      outUnlock          => '0',
      good               => (others => '0'),
      bad                => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal arithmeticCancel : sl;
   signal mulReady         : sl;
   signal mulResultValid   : sl;
   signal mulResultReady   : sl;
   signal mulOverflow      : sl;
   signal mulResult        : slv(PRODUCT_A_C+PRODUCT_B_C-1 downto 0);
   signal divRequest       : slv(2 downto 0);
   signal divReady         : slv(2 downto 0);
   signal divResultValid   : slv(2 downto 0);
   signal divResult        : Slv128Array(0 to 2);
   signal billionResult    : slv(BILLION_WIDTH_C-1 downto 0);
   signal nominalResult    : slv(NOMINAL_WIDTH_C-1 downto 0);

   procedure multiply (
      variable v         : inout RegType;
      constant a         : in    signed;
      constant b         : in    unsigned;
      constant nextState : in    StateType) is
   begin
      assert resize(resize(a, PRODUCT_A_C), a'length) = a
         report "PtpServoPi multiplier A operand exceeds its proven bound"
         severity failure;
      assert resize(resize(b, PRODUCT_B_C), b'length) = b
         report "PtpServoPi multiplier B operand exceeds its proven bound"
         severity failure;

      v.mulA := slv(resize(a, PRODUCT_A_C));
      v.mulB := slv(resize(b, PRODUCT_B_C));
      v.mulValid := '1';
      v.returnState := nextState;
      v.state := PRODUCT_WAIT_S;
   end procedure multiply;

   procedure divide (
      variable v         : inout RegType;
      constant value     : in    signed;
      constant kind      : in    natural;
      constant round     : in    sl;
      constant nextState : in    StateType) is
   begin
      if kind = BILLION_ID_C then
         assert resize(resize(value, BILLION_WIDTH_C), value'length) = value
            report "PtpServoPi interval dividend exceeds its proven bound"
            severity failure;
      elsif kind = NOMINAL_ID_C then
         assert resize(resize(value, NOMINAL_WIDTH_C), value'length) = value
            report "PtpServoPi nominal dividend exceeds its proven bound"
            severity failure;
      end if;

      v.divOperand := slv(resize(value, 128));
      v.divKind := kind;
      v.divRound := round;
      v.divValid := '1';
      v.returnState := nextState;
      v.state := DIVIDE_WAIT_S;
   end procedure divide;

begin

   U_Product : entity surf.PtpLimbProduct
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         A_G            => PRODUCT_A_C,
         B_G            => PRODUCT_B_C)
      port map (
         clk         => clk,               -- [in]
         rst         => rst,               -- [in]
         cancel      => arithmeticCancel,  -- [in]
         inputValid  => r.mulValid,        -- [in]
         inputReady  => mulReady,          -- [out]
         operandA    => r.mulA,            -- [in]
         operandB    => r.mulB,            -- [in]
         resultValid => mulResultValid,    -- [out]
         resultReady => mulResultReady,    -- [in]
         resultValue => mulResult,         -- [out]
         overflow    => mulOverflow);      -- [out]

   -- BILLION and NOMINAL stay local: only this loop converts them, so sharing
   -- would add arbitration and response storage without a second owner.
   U_Billion : entity surf.PtpConstDivide
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         WIDTH_G        => BILLION_WIDTH_C,
         DIVISOR_G      => PTP_NANOSECOND_DIVISOR_C)
      port map (
         clk             => clk,                                   -- [in]
         rst             => rst,                                   -- [in]
         cancel          => arithmeticCancel,                      -- [in]
         inputValid      => divRequest(BILLION_ID_C),              -- [in]
         inputReady      => divReady(BILLION_ID_C),                -- [out]
         roundNearest    => r.divRound,                            -- [in]
         operand         => r.divOperand(BILLION_WIDTH_C-1 downto 0),  -- [in]
         resultValid     => divResultValid(BILLION_ID_C),          -- [out]
         resultReady     => '1',                                   -- [in]
         resultValue     => billionResult,                         -- [out]
         resultRemainder => open);                                 -- [out]

   U_Nominal : entity surf.PtpConstDivide
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         WIDTH_G        => NOMINAL_WIDTH_C,
         DIVISOR_G      => slv(NOMINAL_C))
      port map (
         clk             => clk,                                   -- [in]
         rst             => rst,                                   -- [in]
         cancel          => arithmeticCancel,                      -- [in]
         inputValid      => divRequest(NOMINAL_ID_C),              -- [in]
         inputReady      => divReady(NOMINAL_ID_C),                -- [out]
         roundNearest    => r.divRound,                            -- [in]
         operand         => r.divOperand(NOMINAL_WIDTH_C-1 downto 0),  -- [in]
         resultValid     => divResultValid(NOMINAL_ID_C),          -- [out]
         resultReady     => '1',                                   -- [in]
         resultValue     => nominalResult,                         -- [out]
         resultRemainder => open);                                 -- [out]

   GEN_REQUEST : for i in 0 to 2 generate
      divRequest(i) <= r.divValid when r.divKind = i else '0';
   end generate GEN_REQUEST;

   -- The SECOND converter is shared with manual PHC preparation.
   divReady(SECOND_ID_C) <= secondReady;
   divResultValid(SECOND_ID_C) <= secondResultValid;
   divResult(SECOND_ID_C) <= secondQuotient;
   divResult(BILLION_ID_C) <= slv(resize(signed(billionResult), 128));
   divResult(NOMINAL_ID_C) <= slv(resize(signed(nominalResult), 128));

   comb : process (all) is
      variable v          : RegType;
      variable cancelNow  : boolean;
      variable stale      : boolean;
      variable accepted   : boolean;
      variable deltaTicks : unsigned(63 downto 0);
      variable correction : signed(127 downto 0);
      variable magnitude  : signed(127 downto 0);
      variable limit      : signed(67 downto 0);
      variable bootstrap  : signed(127 downto 0);
   begin
      v := r;
      v.inputReady := '0';
      v.mulTake := '0';
      v.secondResultReady := '0';
      v.offsetUpdate := '0';
      v.rateUpdate := '0';

      accepted := false;
      deltaTicks := unsigned(sampleTicks)-unsigned(r.lastTicks);
      correction := (others => '0');
      magnitude := (others => '0');
      limit := (others => '0');
      bootstrap := (others => '0');

      -- A command whose sample aged out beyond the association timeout is
      -- marked stale so the PHC rejects it on the commit edge.
      v.command.stale := '0';

      if r.state /= IDLE_S and r.holding = '0' and
         ptpAgeExpired(phcStatus.ticks, r.sampleTicks, sharedConfig.associationTimeout) then
         v.command.stale := '1';
      end if;

      cancelNow := v.command.stale = '1' or cancel = '1' or
                   phcStatus.generation /= r.generation or enable = '0';
      v.command.cancel := toSl(cancelNow);
      v.generation := phcStatus.generation;

      stale := r.haveSample = '1' and
               (cancel = '1' or filterValid = '0' or
                ptpAgeExpired(phcStatus.ticks, filterTicks, config.maxDelayAge) or
                ptpAgeExpired(phcStatus.ticks, r.lastTicks, sharedConfig.syncTimeout));

      -- Registered expiry level; the PHC consumes it on the following edge.
      v.expireTime := '0';

      if r.status.state = PTP_SERVO_FAULT_C then
         v.expireTime := '1';
      elsif enable = '1' and r.haveSample = '1' and
            ptpAgeExpired(phcStatus.ticks, r.lastTicks, config.holdoverTimeout) then
         v.expireTime := '1';
      end if;

      if stale then
         v.tracking := '0';
         v.good := (others => '0');
         v.status.state := PTP_SERVO_HOLDOVER_C;
      end if;

      case r.state is
         when IDLE_S =>

            if stale and r.holdApplied = '0' then
               -- Holdover preserves the committed frequency and removes slew.
               v.holding := '1';
               v.status.ratePpb := slv(resize(clamp(r.frequency, config.maxRatePpb), 64));
               v.rateUpdate := '1';
               v.state := RATE_START_S;
            elsif r.command.cancel = '0' then
               v.inputReady := '1';

               if inputValid = '1' and cancel = '0' then
                  if sampleGeneration /= phcStatus.generation or
                     unsigned(sampleTicks) > unsigned(phcStatus.ticks) or
                     ptpAgeExpired(phcStatus.ticks, sampleTicks, sharedConfig.associationTimeout) then
                     v.status.rejectedCount := ptpSatInc(r.status.rejectedCount);
                  elsif filterValid = '1' and ratioValid = '1' and
                        not ptpAgeExpired(phcStatus.ticks, filterTicks, config.maxDelayAge) and
                        (r.haveSample = '0' or unsigned(sampleTicks) > unsigned(r.lastTicks)) then

                     if r.tracking = '1' and
                        (deltaTicks < unsigned(config.minSampleTicks) or
                         deltaTicks > unsigned(config.maxSampleTicks)) then
                        v.status.rejectedCount := ptpSatInc(r.status.rejectedCount);
                     else
                        v.sampleTicks := sampleTicks;
                        v.forwardValue := signed(forwardValue);
                        v.delayValue := signed(filteredDelay);
                        v.status.filteredDelay := filteredDelay;
                        v.ratio := unsigned(ratio);
                        v.holding := '0';
                        v.command.data := PTP_PHC_COMMAND_INIT_C;
                        v.command.data.generation := phcStatus.generation;
                        v.state := OFFSET_DELAY_S;
                     end if;
                  end if;
               end if;
            end if;

         when OFFSET_DELAY_S =>
            v.offsetWide := r.forwardValue-r.delayValue;
            v.state := OFFSET_ASYMMETRY_S;

         when OFFSET_ASYMMETRY_S =>
            v.offsetWide := r.offsetWide-resize(signed(config.delayAsymmetry), 128);
            v.state := OFFSET_PUBLISH_S;

         when OFFSET_PUBLISH_S =>
            v.status.offsetValue := slv(r.offsetWide);
            v.offsetUpdate := '1';
            v.state := OFFSET_DECIDE_S;

         when OFFSET_DECIDE_S =>
            magnitude := abs(r.offsetWide);
            v.inLock := toSl(magnitude <= resize(signed(config.lockThreshold), 128));
            v.outUnlock := toSl(magnitude >= resize(signed(config.unlockThreshold), 128));

            -- A large step can establish the epoch while time is invalid. This
            -- decision precedes the signed64 offset fit check, so the phase
            -- path retains the full signed128 offset.
            if phcStatus.timeValid = '0' and config.allowStep = '1' and
               magnitude > resize(signed(config.stepThreshold), 128) then
               v.stepping := '1';
               v.state := PHASE_REQUEST_S;
            elsif resize(resize(r.offsetWide, 64), 128) /= r.offsetWide then
               v.status.rejectedCount := ptpSatInc(r.status.rejectedCount);
               v.state := IDLE_S;
            else
               v.offsetValue := resize(r.offsetWide, 64);
               multiply(v, r.offsetWide, unsigned(config.kp), PROPORTIONAL_DONE_S);
            end if;

         when PHASE_REQUEST_S =>
            -- Truncating conversion of the negated offset: the quotient is
            -- whole seconds and the remainder is the exact subsecond part.
            divide(v, -r.offsetWide, SECOND_ID_C, '0', PHASE_RESULT_S);

         when PHASE_RESULT_S =>
            if resize(resize(r.mathValue, 64), 128) /= r.mathValue or
               resize(resize(r.remainderValue, 48), 128) /= r.remainderValue then
               v.status.state := PTP_SERVO_FAULT_C;
               v.state := IDLE_S;
            else
               v.command.data := PTP_PHC_COMMAND_INIT_C;
               v.command.data.kind := PTP_CMD_PHASE_C;
               v.command.data.generation := r.generation;
               v.command.data.phaseSeconds := slv(resize(r.mathValue, 64));
               v.command.data.phaseFraction :=
                  slv(shift_left(resize(r.remainderValue, 64), PTP_TIME_FRAC_BITS_C));
               v.state := COMMAND_S;
            end if;

         when PRODUCT_WAIT_S =>
            -- The product asserts ready only while idle, so valid-and-ready
            -- is the accepting edge. Clear the request there and only then
            -- look at the result.
            if r.mulValid = '1' and mulReady = '1' then
               v.mulValid := '0';
               v.mulPending := '1';
            end if;

            if r.mulPending = '1' and mulResultValid = '1' then
               v.mulPending := '0';
               v.mulTake := '1';
               v.mathValue := resize(signed(mulResult), 128);
               v.state := r.returnState;

               -- Reject an overflowing product before any rounding shift.
               if mulOverflow = '1' then
                  v.status.rejectedCount := ptpSatInc(r.status.rejectedCount);
                  v.state := IDLE_S;
               end if;
            end if;

         when DIVIDE_WAIT_S =>
            if divReady(r.divKind) = '1' then
               v.divValid := '0';
            end if;


            if r.divKind = SECOND_ID_C then
               v.secondResultReady := '1';
            end if;

            if r.divValid = '0' and divResultValid(r.divKind) = '1' then
               v.mathValue := signed(divResult(r.divKind));
               v.state := r.returnState;

               -- Only the SECOND service returns a remainder, and only the
               -- phase path consumes it.
               if r.divKind = SECOND_ID_C then
                  v.remainderValue := signed(secondRemainder);
               end if;
            end if;

         when PROPORTIONAL_DONE_S =>
            assert resize(resize(r.mathValue, 96), 128) = r.mathValue
               report "PtpServoPi proportional product exceeds its proven bound"
               severity failure;
            v.proportional := resize(clamp(
               -ptpRoundShiftExact(resize(r.mathValue, 96), PROPORTIONAL_SHIFT_C),
               config.maxSlewPpb), 64);

            -- Preserve the pre-edge qualification rule: a stale condition first
            -- detected on this edge affects the next sample, not this one.
            v.integrating := r.tracking;

            if r.tracking = '1' then
               multiply(v, signed(resize(deltaTicks, 96)), NOMINAL_C, INTERVAL_PRODUCT_S);
            else
               bootstrap := signed(resize(r.ratio, 128))-
                            signed(shift_left(resize(NOMINAL_C, 128), PTP_PHC_TO_RATIO_SHIFT_C));
               multiply(v, bootstrap, to_unsigned(PTP_PPB_SCALE_C, 30), BOOT_PRODUCT_S);
            end if;

         when BOOT_PRODUCT_S =>
            divide(v, r.mathValue, NOMINAL_ID_C, '1', BOOT_DONE_S);

         when BOOT_DONE_S =>
            v.proposed := resize(clamp(r.mathValue, config.maxFrequencyPpb), 68);
            v.state := BOOT_SUBTRACT_S;

         when BOOT_SUBTRACT_S =>
            v.proposed := r.proposed-resize(r.proportional, 68);
            v.state := FREQUENCY_LIMIT_S;

         when INTERVAL_PRODUCT_S =>
            divide(v, r.mathValue, BILLION_ID_C, '1', INTERVAL_DONE_S);

         when INTERVAL_DONE_S =>
            assert r.mathValue >= 0 and resize(resize(r.mathValue, 95), 128) = r.mathValue
               report "PtpServoPi elapsed interval is not a positive signed95 value"
               severity failure;
            v.interval := resize(unsigned(r.mathValue), 95);
            multiply(v, r.offsetValue, unsigned(config.ki), GAIN_DONE_S);

         when GAIN_DONE_S =>
            multiply(v, r.mathValue, r.interval, INTEGRAL_DONE_S);

         when INTEGRAL_DONE_S =>
            -- Full signed128 overflow was rejected before this state. The
            -- rounded shift then fits signed67; retain the correction for the
            -- frequency sum and its direction for anti-windup.
            -- The helper returns value'length-bits+1 bits, so widen before
            -- assigning into the signed128 working variable.
            correction := -resize(ptpRoundShiftExact(r.mathValue, INTEGRAL_SHIFT_C), 128);
            assert resize(resize(correction, 67), 128) = correction
               report "PtpServoPi integral correction exceeds signed67"
               severity failure;
            v.correction := resize(correction, 67);
            v.correctionNegative := correction(127);
            v.correctionNonzero := toSl(correction /= 0);
            v.state := FREQUENCY_PROPOSE_S;

         when FREQUENCY_PROPOSE_S =>
            v.proposed := resize(r.frequency, 68)+resize(r.correction, 68);
            v.state := FREQUENCY_LIMIT_S;

         when FREQUENCY_LIMIT_S =>
            v.candidate := resize(clamp(r.proposed, config.maxFrequencyPpb), 64);
            v.state := RATE_SUM_S;

            if r.integrating = '1' then
               limit := signed(shift_left(resize(unsigned(config.maxFrequencyPpb), 68),
                                          PTP_PPB_FRAC_BITS_C));
               -- Test saturation direction in parallel with clamping rather
               -- than feeding the clamp result through another equality chain.
               v.outward := toSl(r.correctionNonzero = '1' and
                  ((r.proposed > limit and r.correctionNegative = '0') or
                   (r.proposed < -limit and r.correctionNegative = '1')));
               v.state := RATE_TRIAL_SUM_S;
            end if;

         when RATE_TRIAL_SUM_S =>
            v.trial := resize(r.candidate, 65)+resize(r.proportional, 65);
            v.state := RATE_TRIAL_CHECK_S;

         when RATE_TRIAL_CHECK_S =>
            limit := signed(shift_left(resize(unsigned(config.maxRatePpb), 68),
                                       PTP_PPB_FRAC_BITS_C));

            if r.correctionNonzero = '1' and
               ((resize(r.trial, 68) > limit and r.correctionNegative = '0') or
                (resize(r.trial, 68) < -limit and r.correctionNegative = '1')) then
               v.outward := '1';
            end if;

            v.state := INTEGRATE_SELECT_S;

         when INTEGRATE_SELECT_S =>
            -- Conditional integration: hold the committed frequency when the
            -- correction would push further into saturation.
            if r.outward = '1' then
               v.candidate := r.frequency;
            end if;

            v.state := RATE_SUM_S;

         when RATE_SUM_S =>
            v.trial := resize(r.candidate, 65)+resize(r.proportional, 65);
            v.state := RATE_LIMIT_S;

         when RATE_LIMIT_S =>
            v.status.ratePpb := slv(resize(clamp(r.trial, config.maxRatePpb), 64));
            v.state := RATE_PUBLISH_S;

         when RATE_PUBLISH_S =>
            v.rateUpdate := '1';
            v.state := RATE_START_S;

         when RATE_START_S =>
            multiply(v, signed(r.status.ratePpb), NOMINAL_C, RATE_PRODUCT_S);

         when RATE_PRODUCT_S =>
            divide(v, r.mathValue, SECOND_ID_C, '1', RATE_COMMAND_S);

         when RATE_COMMAND_S =>
            if resize(resize(r.mathValue, 64), 128) /= r.mathValue then
               v.status.state := PTP_SERVO_FAULT_C;
               v.state := IDLE_S;
            else
               v.command.data := PTP_PHC_COMMAND_INIT_C;
               v.command.data.kind := PTP_CMD_RATE_C;
               v.command.data.generation := r.generation;
               v.command.data.rate := slv(resize(r.mathValue, 64));
               v.state := COMMAND_S;
            end if;

         when COMMAND_S =>
            if commandSlave.ready = '1' then
               v.state := ACK_S;
            end if;

         when ACK_S =>
            if commandSlave.ack = '1' then
               v.state := IDLE_S;

               if commandSlave.error = '1' then
                  v.status.state := PTP_SERVO_FAULT_C;
               elsif r.command.data.kind = PTP_CMD_PHASE_C then
                  -- A successful phase step establishes the epoch; frequency
                  -- control starts from the next forward measurement.
                  v.stepping := '0';
                  v.lastTicks := r.sampleTicks;
                  v.haveSample := '1';

                  if phcStatus.timeValid = '0' then
                     v.command.data.kind := PTP_CMD_VALID_C;
                     v.command.data.value := '1';
                     v.state := COMMAND_S;
                  end if;
               elsif r.command.data.kind = PTP_CMD_RATE_C then
                  if r.holding = '1' then
                     v.holdApplied := '1';
                  else
                     -- Frequency and history commit only here.
                     v.frequency := r.candidate;
                     v.tracking := '1';
                     v.haveSample := '1';
                     v.lastTicks := r.sampleTicks;
                     v.holdApplied := '0';
                     accepted := true;

                     if phcStatus.timeValid = '0' then
                        v.command.data.kind := PTP_CMD_VALID_C;
                        v.command.data.value := '1';
                        v.state := COMMAND_S;
                     end if;
                  end if;
               end if;
            end if;
      end case;

      -- Lock hysteresis qualifies the internal offset estimate using only a
      -- sample whose rate command was acknowledged. It is not an independent
      -- accuracy measurement or a physical PLL lock indication.
      if accepted then
         v.status.state := PTP_SERVO_TRACKING_C;

         if r.inLock = '1' then
            if r.good /= x"FF" then
               v.good := r.good+1;
            end if;
            v.bad := (others => '0');
         elsif r.outUnlock = '1' then
            v.good := (others => '0');
            if r.bad /= x"FF" then
               v.bad := r.bad+1;
            end if;
         end if;

         if v.good >= unsigned(config.lockCount) or
            (r.status.state = PTP_SERVO_LOCKED_C and v.bad < unsigned(config.unlockCount)) then
            v.status.state := PTP_SERVO_LOCKED_C;
         end if;
      end if;

      -- Cancellation overrides pending work but not a successful ACK's
      -- already committed frequency and history.
      if cancelNow then
         v.state := IDLE_S;
         v.mulValid := '0';
         v.divValid := '0';
         v.stepping := '0';
         v.tracking := '0';
         v.holdApplied := '0';
         v.good := (others => '0');
         v.bad := (others => '0');
         v.status.state := PTP_SERVO_ACQUIRING_C;

         if r.haveSample = '1' then
            v.status.state := PTP_SERVO_HOLDOVER_C;
         end if;
      end if;

      if enable = '0' then
         v.haveSample := '0';
         v.status.state := PTP_SERVO_DISABLED_C;
      end if;

      if phcStatus.fault = '1' or r.status.state = PTP_SERVO_FAULT_C then
         v.state := IDLE_S;
         v.status.state := PTP_SERVO_FAULT_C;
      end if;

      -- Resolve admission after every override so a cancelled or faulted edge
      -- cannot advertise acceptance. A disabled servo drains measurements.
      if cancelNow or phcStatus.fault = '1' or r.status.state = PTP_SERVO_FAULT_C then
         v.inputReady := '0';
      end if;

      if enable = '0' then
         v.inputReady := '1';
      end if;

      v.command.valid := toSl(v.state = COMMAND_S);
      v.arithmeticCancel := toSl(cancelNow or phcStatus.fault = '1' or
                                 v.status.state = PTP_SERVO_FAULT_C);

      -- Combinatorial outputs before the reset.
      -- Arithmetic cancellation also covers a fault, which stops the loop
      -- without being a command cancellation.
      arithmeticCancel <= v.arithmeticCancel;
      secondCancel <= v.arithmeticCancel;
      secondResultReady <= v.secondResultReady;
      mulResultReady <= v.mulTake;
      inputReady <= v.inputReady;

      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin <= v;

      -- The SECOND request is registered like the local converter requests, so
      -- valid, operand and rounding mode reach the shared service together.
      secondValid <= divRequest(SECOND_ID_C);
      secondRound <= r.divRound;
      secondOperand <= r.divOperand;

      commandMaster <= r.command;
      expireTime <= r.expireTime;
      status <= r.status;
      offsetUpdate <= r.offsetUpdate;
      rateUpdate <= r.rateUpdate;
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
