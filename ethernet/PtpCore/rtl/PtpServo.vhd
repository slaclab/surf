-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PTP acquisition, filtered delay estimation and PHC feedback
-- control.
--
-- Accepts separate forward and path-delay measurements from PtpPort. Up to
-- five populated delay samples form a median filter; local-minus-master offset
-- is forward time minus filtered delay and configured asymmetry. Generation,
-- sample chronology and raw-tick age checks reject stale measurements before
-- they can affect the clock.
--
-- During acquisition, an enabled large phase adjustment can establish the
-- epoch. Otherwise the qualified raw-clock rate estimate initializes frequency
-- control. A serialized PtpMath engine evaluates the fixed-point
-- proportional/integral loop, including elapsed-time integration, frequency
-- and phase-slew clamps, final-rate limiting and conditional integration at
-- saturation. Commands use the PHC ready/valid and acknowledgement lifecycle;
-- only acknowledged rate commands update the retained frequency estimate.
--
-- Lock/unlock thresholds and counters provide quality hysteresis. Loss of
-- fresh measurements enters holdover, removes phase slew and preserves the
-- last good frequency; registered expiry requests time-validity revocation
-- on the next PHC edge. Registered command cancellation can revoke a request
-- accepted on its detection edge before the PHC commits it. A disabled servo
-- drains measurements without steering. PtpEndpoint coordinates restart policy.
--
-- The local AXI-Lite bank stores gains, step/lock policy, sample-age limits
-- and asymmetry as writable shadows, frozen candidates and active settings.
-- Candidate validity is captured on prepare for the later coordinated apply.
-- Shared association, sync and path-delay limits come from PtpPort's active
-- sharedConfig record, maintaining one owner for settings used by both cores.
-- The common snapshot strobe stores filter, offset, rate and rejection state
-- locally with the endpoint sequence; AXI read latency cannot mix samples.
--
-- Management and feedback state share this module's RegType/comb/seq pair.
-- regRst clears AXI responses without resetting the active loop configuration;
-- restart and measurement cancellation retain their separate lifecycle roles.
-- PtpEndpoint connects this bank directly to its AXI-Lite crossbar. Loop
-- settings always come from the local active registers. PtpPhc owns final
-- arbitration between these commands and manual writes. Directional PHC
-- command records keep requests and their completion responses together; the
-- status record reports live diagnostics independently of those handshakes.
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
use surf.AxiLitePkg.all;
use surf.PtpPkg.all;

entity PtpServo is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      CLK_FREQ_G     : positive := 156250000);
   port (
      -- Shared endpoint clock domain.
      clk               : in  sl;
      rst               : in  sl;

      -- Local AXI-Lite bank and endpoint coordination (clk domain).
      regRst           : in  sl                     := '0';
      axiReadMaster    : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axiReadSlave     : out AxiLiteReadSlaveType;
      axiWriteMaster   : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axiWriteSlave    : out AxiLiteWriteSlaveType;
      configControl    : in  PtpConfigControlType   := PTP_CONFIG_CONTROL_INIT_C;
      snapshotControl  : in  PtpSnapshotControlType := PTP_SNAPSHOT_CONTROL_INIT_C;
      configValid      : out sl;
      servoEnable      : in  sl                     := '0';
      sharedConfig     : in  PtpSharedConfigType    := PTP_SHARED_CONFIG_INIT_C;

      -- Protocol/clock interface.
      measurementMaster : in  PtpMeasurementMasterType;
      measurementSlave  : out PtpMeasurementSlaveType;
      restart           : in  sl            := '0';
      phcStatus         : in  PtpPhcStatusType;
      -- Registered revocation level; the PHC consumes it on the next edge.
      expireTime        : out sl;
      commandMaster     : out PtpPhcCommandMasterType;
      commandSlave      : in  PtpPhcCommandSlaveType;
      status            : out PtpServoStatusType);
end entity PtpServo;

architecture rtl of PtpServo is

   constant DELAY_FILTER_DEPTH_C : positive := 5;
   -- Supported actuator policy envelope (200 ppm), not the signed arithmetic
   -- limit. Preserve the existing cap; hardware qualification remains open.
   -- It is independent of the port's raw-oscillator qualification bound.
   constant MAX_ACTUATOR_PPB_C : positive := 200000;

   function initialConfig return PtpServoConfigType is
      variable v      : PtpServoConfigType    := PTP_SERVO_CONFIG_INIT_C;
      constant TICK_C : unsigned(63 downto 0) := to_unsigned(CLK_FREQ_G, 64);

   begin
      -- Vector arithmetic avoids integer overflow for long default durations;
      -- numeric_std multiplication widens its result before the resize.
      v.maxDelayAge     := slv(resize(TICK_C*4, 64));   -- 4 s.
      v.holdoverTimeout := slv(resize(TICK_C*64, 64));  -- 64 s.
      v.minSampleTicks  := slv(TICK_C/64);             -- 1/64 s, rounded down to ticks.
      v.maxSampleTicks  := slv(resize(TICK_C*2, 64));   -- 2 s.
      return v;
   end function;

   -- Validate the same pre-edge shadows captured by prepare.
   function validConfig (cfg : PtpServoConfigType) return boolean is
   begin
      -- Phase policy and lock hysteresis.
      if signed(cfg.stepThreshold) < 0 then
         return false;
      end if;
      if signed(cfg.lockThreshold) < 0 then
         return false;
      end if;
      if signed(cfg.unlockThreshold) < signed(cfg.lockThreshold) then
         return false;
      end if;
      if unsigned(cfg.lockCount) = 0 or unsigned(cfg.unlockCount) = 0 then
         return false;
      end if;

      -- Actuator limits and sample chronology.
      if unsigned(cfg.maxRatePpb) > MAX_ACTUATOR_PPB_C then
         return false;
      end if;
      if unsigned(cfg.maxFrequencyPpb) > unsigned(cfg.maxRatePpb) then
         return false;
      end if;
      if unsigned(cfg.maxSlewPpb) > unsigned(cfg.maxRatePpb) then
         return false;
      end if;
      if unsigned(cfg.maxSampleTicks) < unsigned(cfg.minSampleTicks) then
         return false;
      end if;

      -- Every timeout must fit the supported unsigned-difference range.
      if not ptpValidTimeout(cfg.maxDelayAge) then
         return false;
      end if;
      if not ptpValidTimeout(cfg.holdoverTimeout) then
         return false;
      end if;
      if not ptpValidTimeout(cfg.minSampleTicks) then
         return false;
      end if;
      if not ptpValidTimeout(cfg.maxSampleTicks) then
         return false;
      end if;
      return true;
   end function;

   constant NOMINAL_C    : unsigned(63 downto 0) := unsigned(ptpNominalIncrement(CLK_FREQ_G));
   constant SECOND_Q16_C : signed(127 downto 0)  := shift_left(to_signed(PTP_NANOSECONDS_PER_SECOND_C, 128), PTP_TIME_FRAC_BITS_C);

   constant PPB_Q16_SCALE_C : signed(127 downto 0) := shift_left(to_signed(PTP_PPB_SCALE_C, 128), PTP_PPB_FRAC_BITS_C);

   -- Offset Q16 * gain Q30 -> ppb Q16. Integration additionally multiplies
   -- by elapsed seconds with the PHC addend's fractional precision (Q32).
   constant PROPORTIONAL_SHIFT_C : natural := PTP_TIME_FRAC_BITS_C+PTP_GAIN_FRAC_BITS_C-PTP_PPB_FRAC_BITS_C;
   constant INTEGRAL_SHIFT_C     : natural := PROPORTIONAL_SHIFT_C+PTP_PHC_FRAC_BITS_C;

   type StateType is (
      IDLE_S,
      ISSUE_S,
      WAIT_S,
      COMMAND_S,
      ACK_S);

   type DelayArray is array (0 to DELAY_FILTER_DEPTH_C-1) of signed(63 downto 0);
   type OperationType is (
      RATIO_SCALE_S,
      RATIO_DIVIDE_S,
      PROPORTIONAL_S,
      INTERVAL_SCALE_S,
      INTERVAL_DIVIDE_S,
      INTEGRAL_GAIN_S,
      INTEGRAL_TIME_S,
      RATE_SCALE_S,
      RATE_DIVIDE_S,
      RESERVED_S,
      PHASE_DIVIDE_S);

   type RegType is record
      -- Registered command interface. Use v.commandMaster.cancel/stale for
      -- current-edge local decisions and publish the complete record from r.
      commandMaster      : PtpPhcCommandMasterType;
      -- Combinational measurement admission, resolved through v each cycle.
      measurementSlave   : PtpMeasurementSlaveType;
      expireTime         : sl;
      status             : PtpServoStatusType;

      -- Local management state shares the core reset and register process.
      readSlave          : AxiLiteReadSlaveType;
      writeSlave         : AxiLiteWriteSlaveType;
      shadow             : PtpServoConfigType;
      candidate          : PtpServoConfigType;
      configValid        : sl;
      activeConfig       : PtpServoConfigType;
      sequenceId         : slv(31 downto 0);
      snapOffset         : slv(127 downto 0);
      snapDelay          : slv(127 downto 0);
      snapRate           : slv(63 downto 0);
      snapRejected       : slv(31 downto 0);
      state              : StateType;
      operation          : OperationType;
      a                  : slv(127 downto 0);
      b                  : slv(127 downto 0);
      divide             : sl;
      mathValid          : sl;
      mathRound          : sl;
      generation         : slv(31 downto 0);
      abortSeen          : sl;
      delays             : DelayArray;
      delayPtr           : natural range 0 to DELAY_FILTER_DEPTH_C-1;
      delayTicks         : slv(63 downto 0);
      sampleTicks        : slv(63 downto 0);
      lastTicks          : slv(63 downto 0);
      haveSample         : sl;
      tracking           : sl;
      holding            : sl;
      holdApplied        : sl;
      workFrequency      : signed(127 downto 0);
      frequency          : signed(127 downto 0);
      slew               : signed(127 downto 0);
      bootstrap          : signed(127 downto 0);
      interval           : signed(127 downto 0);
      good               : unsigned(7 downto 0);
      bad                : unsigned(7 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      commandMaster      => PTP_PHC_COMMAND_MASTER_INIT_C,
      measurementSlave   => PTP_MEASUREMENT_SLAVE_INIT_C,
      expireTime         => '0',
      status             => PTP_SERVO_STATUS_INIT_C,
      readSlave          => AXI_LITE_READ_SLAVE_INIT_C,
      writeSlave         => AXI_LITE_WRITE_SLAVE_INIT_C,
      shadow             => initialConfig,
      candidate          => initialConfig,
      configValid        => toSl(validConfig(initialConfig)),
      activeConfig       => initialConfig,
      sequenceId         => (others => '0'),
      snapOffset         => (others => '0'),
      snapDelay          => (others => '0'),
      snapRate           => (others => '0'),
      snapRejected       => (others => '0'),
      state              => IDLE_S,
      operation          => RATIO_SCALE_S,
      a                  => (others => '0'),
      b                  => (others => '0'),
      divide             => '0',
      mathValid          => '0',
      mathRound          => '1',
      generation         => (others => '0'),
      abortSeen          => '0',
      delays             => (others => (others => '0')),
      delayPtr           => 0,
      delayTicks         => (others => '0'),
      sampleTicks        => (others => '0'),
      lastTicks          => (others => '0'),
      haveSample         => '0',
      tracking           => '0',
      holding            => '0',
      holdApplied        => '0',
      frequency          => (others => '0'),
      workFrequency      => (others => '0'),
      slew               => (others => '0'),
      bootstrap          => (others => '0'),
      interval           => (others => '0'),
      good               => (others => '0'),
      bad                => (others => '0'));

   signal r             : RegType := REG_INIT_C;
   signal rin           : RegType;
   signal invalidate    : sl;
   signal inputMath     : sl;
   signal readyMath     : sl;
   signal validMath     : sl;
   signal valueMath     : slv(127 downto 0);
   signal remainderMath : slv(127 downto 0);
   signal errorMath     : sl;
   signal roundMath     : sl;

   -- The 32-bit ppb bound with 16 fractional bits fits the 64-bit status
   -- rate field. Keep wide arithmetic until this clamp, then sign-extend the
   -- stored rate when issuing 128-bit math operands.
   function clamp (
      value   : signed(127 downto 0);
      maximum : slv(31 downto 0)) return signed is
      variable limitValue : signed(127 downto 0);
   begin
      limitValue := shift_left(signed(resize(unsigned(maximum), 128)), PTP_PPB_FRAC_BITS_C);
      if value > limitValue then
         return limitValue;
      elsif value < -limitValue then
         return -limitValue;
      end if;
      return value;
   end function;

begin

   U_Math : entity surf.PtpMath
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk             => clk,            -- [in]
         rst             => rst,            -- [in]
         cancel          => invalidate,     -- [in]
         inputValid      => inputMath,      -- [in]
         inputReady      => readyMath,      -- [out]
         divide          => r.divide,       -- [in]
         roundNearest    => roundMath,      -- [in]
         operandA        => r.a,            -- [in]
         operandB        => r.b,            -- [in]
         resultValid     => validMath,      -- [out]
         resultReady     => '1',            -- [in]
         resultValue     => valueMath,      -- [out]
         resultRemainder => remainderMath,  -- [out]
         resultError     => errorMath);     -- [out]

   comb : process (r, measurementMaster, rst, regRst, axiReadMaster, axiWriteMaster, configControl,
                   snapshotControl, servoEnable, sharedConfig, restart, phcStatus, commandSlave,
                   readyMath, validMath, valueMath, remainderMath, errorMath) is
      variable v      : RegType;
      variable ep     : AxiLiteEndpointType;
      variable sorted : DelayArray;
      variable temp   : signed(63 downto 0);

      -- Calculations used only during this evaluation.
      variable sampleTickDelta    : signed(127 downto 0);
      variable frequencyCandidate : signed(127 downto 0);
      variable integralDelta      : signed(127 downto 0);
      variable stale              : boolean;
      variable acceptSample       : boolean;
      variable integrate          : boolean;
   begin
      v                  := r;
      v.measurementSlave := PTP_MEASUREMENT_SLAVE_INIT_C;
      sorted             := r.delays;
      temp               := (others => '0');

      -- A held link/port abort cancels once, allowing later holdover work.
      -- Generation changes and stale samples independently invalidate work.
      v.commandMaster.stale := '0';
      if r.state /= IDLE_S and r.holding = '0' and
         unsigned(phcStatus.ticks)-unsigned(r.sampleTicks) > unsigned(sharedConfig.associationTimeout) then
         v.commandMaster.stale := '1';
      end if;
      v.commandMaster.cancel := '0';
      if v.commandMaster.stale = '1' or restart = '1' or
         (measurementMaster.abort = '1' and r.abortSeen = '0') or
         phcStatus.generation /= r.generation or servoEnable = '0' then
         v.commandMaster.cancel := '1';
      end if;

      v.abortSeen  := measurementMaster.abort;
      v.generation := phcStatus.generation;
      stale        := r.haveSample = '1' and (measurementMaster.abort = '1' or unsigned(r.status.filterCount) = 0 or
         unsigned(phcStatus.ticks)-unsigned(r.delayTicks) > unsigned(r.activeConfig.maxDelayAge) or
         unsigned(phcStatus.ticks)-unsigned(r.lastTicks) > unsigned(sharedConfig.syncTimeout));
      -- Sample expiry as a registered level. The PHC consumes it on the
      -- following edge; both assertion and release have one cycle of latency.
      v.expireTime := '0';
      if r.status.state = PTP_SERVO_FAULT_C then
         v.expireTime := '1';
      elsif servoEnable = '1' and r.haveSample = '1' then
         if unsigned(phcStatus.ticks)-unsigned(r.lastTicks) > unsigned(r.activeConfig.holdoverTimeout) then
            v.expireTime := '1';
         end if;
      end if;

      acceptSample := false;
      if stale then
         v.status.state := PTP_SERVO_HOLDOVER_C;
         v.tracking     := '0';
         v.good         := (others => '0');
      end if;
      -- Accept/filter a sample, evaluate the loop in named arithmetic stages,
      -- then wait for PHC acceptance and acknowledgement before updating history.
      case r.state is
         when IDLE_S =>
            if stale and r.holdApplied = '0' then
               -- Holdover removes the phase slew but preserves the last good
               -- frequency estimate. Conversion uses the same checked path as
               -- tracking; no combinational wide divider enters the clock loop.
               v.status.ratePpb := slv(resize(clamp(r.frequency, r.activeConfig.maxRatePpb), 64));
               v.a              := slv(resize(signed(v.status.ratePpb), 128));
               v.b              := slv(resize(NOMINAL_C, 128));
               v.divide         := '0';
               v.operation      := RATE_SCALE_S;
               v.holding        := '1';
               v.state          := ISSUE_S;
            else
               -- Holdover work has priority over admitting another sample.
               v.measurementSlave.ready := '1';
               if measurementMaster.valid = '1' and measurementMaster.abort = '0' and servoEnable = '1' then
                  if measurementMaster.data.generation /= phcStatus.generation or
                     unsigned(measurementMaster.data.ticks) > unsigned(phcStatus.ticks) or
                     unsigned(phcStatus.ticks)-unsigned(measurementMaster.data.ticks) > unsigned(sharedConfig.associationTimeout) then
                     v.status.rejectedCount := ptpSatInc(v.status.rejectedCount);
                  elsif measurementMaster.data.isDelay = '1' then
                     if signed(measurementMaster.data.delayValue) >= 0 and signed(measurementMaster.data.delayValue) <= signed(sharedConfig.maxPathDelay) and
                        (unsigned(r.status.filterCount) = 0 or unsigned(measurementMaster.data.ticks) > unsigned(r.delayTicks)) then
                        v.delays(r.delayPtr) := signed(measurementMaster.data.delayValue(63 downto 0));
                        v.delayPtr           := (r.delayPtr+1) mod DELAY_FILTER_DEPTH_C;
                        if unsigned(r.status.filterCount) < DELAY_FILTER_DEPTH_C then
                           v.status.filterCount := slv(unsigned(r.status.filterCount)+1);
                        end if;
                        sorted := v.delays;
                        -- Sort only populated entries. Zero-filled startup history
                        -- is never mistaken for five accepted zero-delay samples.
                        for i in sorted'range loop
                           for j in sorted'low to sorted'high-1 loop
                              if j+1 < unsigned(v.status.filterCount) and sorted(j) > sorted(j+1) then
                                 temp        := sorted(j);
                                 sorted(j)   := sorted(j+1);
                                 sorted(j+1) := temp;
                              end if;
                           end loop;
                        end loop;
                        v.status.filteredDelay := slv(resize(sorted((to_integer(unsigned(v.status.filterCount))-1)/2), 128));
                        v.delayTicks           := measurementMaster.data.ticks;
                     else
                        v.status.rejectedCount := ptpSatInc(v.status.rejectedCount);
                     end if;
                  elsif unsigned(r.status.filterCount) /= 0 and measurementMaster.data.ratioValid = '1' and
                     unsigned(phcStatus.ticks)-unsigned(r.delayTicks) <= unsigned(r.activeConfig.maxDelayAge) and
                     (r.haveSample = '0' or unsigned(measurementMaster.data.ticks) > unsigned(r.lastTicks)) then
                     sampleTickDelta := signed(resize(unsigned(measurementMaster.data.ticks), 128))-signed(resize(unsigned(r.lastTicks), 128));
                     if r.tracking = '1' and (sampleTickDelta < signed(resize(unsigned(r.activeConfig.minSampleTicks), 128)) or
                        sampleTickDelta > signed(resize(unsigned(r.activeConfig.maxSampleTicks), 128))) then
                        v.status.rejectedCount := ptpSatInc(v.status.rejectedCount);
                     else
                        v.status.offsetValue            := slv(signed(measurementMaster.data.forward)-signed(r.status.filteredDelay)-resize(signed(r.activeConfig.delayAsymmetry), 128));
                        v.sampleTicks                   := measurementMaster.data.ticks;
                        v.holding                       := '0';
                        v.commandMaster.data            := PTP_PHC_COMMAND_INIT_C;
                        v.commandMaster.data.generation := phcStatus.generation;
                        if phcStatus.timeValid = '0' and r.activeConfig.allowStep = '1' and abs(signed(v.status.offsetValue)) > signed(r.activeConfig.stepThreshold) then
                           -- Normalize the full acquisition epoch delta outside the
                           -- PHC. Quotient/remainder are transported atomically and
                           -- applied to the normally advanced commit-edge time.
                           v.a         := slv(-signed(v.status.offsetValue));
                           v.b         := slv(SECOND_Q16_C);
                           v.divide    := '1';
                           v.operation := PHASE_DIVIDE_S;
                           v.state     := ISSUE_S;
                        elsif resize(resize(signed(v.status.offsetValue), 64), 128) /= signed(v.status.offsetValue) then
                           v.status.rejectedCount := ptpSatInc(v.status.rejectedCount);
                        else
                           v.a         := slv(signed(resize(unsigned(measurementMaster.data.ratio), 128))-
                                      signed(shift_left(resize(NOMINAL_C, 128), PTP_PHC_TO_RATIO_SHIFT_C)));
                           v.b         := slv(to_signed(PTP_PPB_SCALE_C, 128));
                           v.divide    := '0';
                           v.operation := RATIO_SCALE_S;
                           v.state     := ISSUE_S;
                        end if;
                     end if;
                  end if;
               end if;
            end if;
         when ISSUE_S =>
            if readyMath = '1' then
               v.state := WAIT_S;
            end if;
         when WAIT_S =>
            if validMath = '1' and v.commandMaster.cancel = '0' then
               v.state := ISSUE_S;
               if errorMath = '1' then
                  v.state                := IDLE_S;
                  v.status.rejectedCount := ptpSatInc(v.status.rejectedCount);
               else
                  case r.operation is
                     when RATIO_SCALE_S =>
                        v.a         := valueMath;
                        v.b         := slv(resize(NOMINAL_C, 128));
                        v.divide    := '1';
                        v.operation := RATIO_DIVIDE_S;
                     when RATIO_DIVIDE_S =>
                        -- Ratio Q48 vs nominal Q32 leaves Q16 ppb after the
                        -- 1e9 conversion. Bootstrap is independent of PHC rate.
                        v.bootstrap := clamp(signed(valueMath), r.activeConfig.maxFrequencyPpb);
                        v.a         := r.status.offsetValue;
                        v.b         := slv(resize(unsigned(r.activeConfig.kp), 128));
                        v.divide    := '0';
                        v.operation := PROPORTIONAL_S;
                     when PROPORTIONAL_S =>
                        v.slew := clamp(-ptpRoundShift(signed(valueMath), PROPORTIONAL_SHIFT_C), r.activeConfig.maxSlewPpb);
                        if r.tracking = '0' then
                           -- First apply qualified oscillator feedforward. Seed
                           -- the integrator minus the new proportional term, so
                           -- entry to tracking preserves this applied command.
                           v.workFrequency  := clamp(r.bootstrap-v.slew, r.activeConfig.maxFrequencyPpb);
                           v.status.ratePpb := slv(resize(clamp(v.workFrequency+v.slew, r.activeConfig.maxRatePpb), 64));
                           v.a              := slv(resize(signed(v.status.ratePpb), 128));
                           v.b              := slv(resize(NOMINAL_C, 128));
                           v.operation      := RATE_SCALE_S;
                        else
                           v.a         := slv(resize(unsigned(r.sampleTicks)-unsigned(r.lastTicks), 128));
                           v.b         := slv(resize(NOMINAL_C, 128));
                           v.operation := INTERVAL_SCALE_S;
                        end if;
                     when INTERVAL_SCALE_S =>
                        v.a         := valueMath;
                        v.b         := slv(to_signed(PTP_NANOSECONDS_PER_SECOND_C, 128));
                        v.divide    := '1';
                        v.operation := INTERVAL_DIVIDE_S;
                     when INTERVAL_DIVIDE_S =>
                        v.interval  := signed(valueMath); -- seconds Q32
                        v.a         := r.status.offsetValue;
                        v.b         := slv(resize(unsigned(r.activeConfig.ki), 128));
                        v.divide    := '0';
                        v.operation := INTEGRAL_GAIN_S;
                     when INTEGRAL_GAIN_S =>
                        v.a         := valueMath; -- Q16 offset * Q30 gain
                        v.b         := slv(r.interval); -- seconds Q32
                        v.operation := INTEGRAL_TIME_S;
                     when INTEGRAL_TIME_S =>
                        integralDelta      := -ptpRoundShift(signed(valueMath), INTEGRAL_SHIFT_C); -- ppb Q16
                        frequencyCandidate := r.frequency+integralDelta;
                        v.workFrequency    := clamp(frequencyCandidate, r.activeConfig.maxFrequencyPpb);
                        -- Conditional integration freezes only outward movement
                        -- at either frequency or final-rate saturation. Movement
                        -- back toward the linear region remains possible.
                        integrate := true;
                        if frequencyCandidate /= v.workFrequency then
                           if (frequencyCandidate > 0 and integralDelta > 0) or (frequencyCandidate < 0 and integralDelta < 0) then
                              integrate := false;
                           end if;
                        end if;
                        if clamp(v.workFrequency+r.slew, r.activeConfig.maxRatePpb) /= v.workFrequency+r.slew then
                           if (v.workFrequency+r.slew > 0 and integralDelta > 0) or (v.workFrequency+r.slew < 0 and integralDelta < 0) then
                              integrate := false;
                           end if;
                        end if;
                        if not integrate then
                           v.workFrequency := r.frequency;
                        end if;
                        v.status.ratePpb := slv(resize(clamp(v.workFrequency+r.slew, r.activeConfig.maxRatePpb), 64));
                        v.a              := slv(resize(signed(v.status.ratePpb), 128));
                        v.b              := slv(resize(NOMINAL_C, 128));
                        v.divide         := '0';
                        v.operation      := RATE_SCALE_S;
                     when RATE_SCALE_S =>
                        v.a         := valueMath;
                        v.b         := slv(PPB_Q16_SCALE_C); -- Convert Q16 ppb to a dimensionless rate.
                        v.divide    := '1';
                        v.operation := RATE_DIVIDE_S;
                     when RATE_DIVIDE_S =>
                        if resize(resize(signed(valueMath), 64), 128) /= signed(valueMath) then
                           v.status.state := PTP_SERVO_FAULT_C;
                           v.state        := IDLE_S;
                        else
                           v.commandMaster.data            := PTP_PHC_COMMAND_INIT_C;
                           v.commandMaster.data.kind       := PTP_CMD_RATE_C;
                           v.commandMaster.data.generation := phcStatus.generation;
                           v.commandMaster.data.rate       := valueMath(63 downto 0);
                           v.state                         := COMMAND_S;
                        end if;
                     when PHASE_DIVIDE_S =>
                        if resize(resize(signed(valueMath), 64), 128) /= signed(valueMath) then
                           v.status.state := PTP_SERVO_FAULT_C;
                           v.state        := IDLE_S;
                        else
                           v.commandMaster.data.kind          := PTP_CMD_PHASE_C;
                           v.commandMaster.data.phaseSeconds  := valueMath(63 downto 0);
                           v.commandMaster.data.phaseFraction := slv(shift_left(resize(signed(remainderMath), 64), PTP_TIME_TO_PHC_SHIFT_C));
                           v.state                            := COMMAND_S;
                        end if;
                     when others =>
                        v.status.state := PTP_SERVO_FAULT_C;
                        v.state        := IDLE_S;
                  end case;
               end if;
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
               elsif r.commandMaster.data.kind = PTP_CMD_RATE_C then
                  if r.holding = '1' then
                     v.holdApplied := '1';
                  else
                     acceptSample  := true;
                     v.frequency   := r.workFrequency;
                     v.tracking    := '1';
                     v.holdApplied := '0';
                     if phcStatus.timeValid = '0' then
                        v.commandMaster.data.kind  := PTP_CMD_VALID_C;
                        v.commandMaster.data.value := '1';
                        v.state                    := COMMAND_S;
                     end if;
                  end if;
               end if;
            end if;
      end case;
      -- Lock hysteresis uses only a sample whose rate command was acknowledged.
      if acceptSample then
         v.lastTicks    := r.sampleTicks;
         v.haveSample   := '1';
         v.status.state := PTP_SERVO_TRACKING_C;
         if abs(signed(r.status.offsetValue)) <= signed(r.activeConfig.lockThreshold) then
            if r.good /= x"FF" then
               v.good := r.good+1;
            end if;
            v.bad := (others => '0');
         elsif abs(signed(r.status.offsetValue)) >= signed(r.activeConfig.unlockThreshold) then
            v.good := (others => '0');
            if r.bad /= x"FF" then
               v.bad := r.bad+1;
            end if;
         end if;
         if v.good >= unsigned(r.activeConfig.lockCount) or (r.status.state = PTP_SERVO_LOCKED_C and v.bad < unsigned(r.activeConfig.unlockCount)) then
            v.status.state := PTP_SERVO_LOCKED_C;
         end if;
      end if;
      -- Cancellation overrides work above; disabling/fault policy then selects
      -- the externally visible quality without discarding retained frequency.
      if v.commandMaster.cancel = '1' then
         v.state              := IDLE_S;
         v.status.filterCount := (others => '0');
         v.delayPtr           := 0;
         v.tracking           := '0';
         v.holdApplied        := '0';
         v.good               := (others => '0');
         v.bad                := (others => '0');
         v.status.state       := PTP_SERVO_ACQUIRING_C;
         if r.haveSample = '1' then
            v.status.state := PTP_SERVO_HOLDOVER_C;
         end if;
      end if;
      -- Cancel current-edge measurement admission using pre-edge fault state.
      -- Math has its separate local cancel input; its valid remains registered.
      if v.commandMaster.cancel = '1' or r.status.state = PTP_SERVO_FAULT_C then
         v.measurementSlave.ready := '0';
      end if;
      if servoEnable = '0' then
         -- Manual ownership still drains the port's measurement queue, even
         -- after a servo fault. Reset below has final admission priority.
         v.measurementSlave.ready := '1';
         v.status.state           := PTP_SERVO_DISABLED_C;
         v.haveSample             := '0';
      end if;
      if phcStatus.fault = '1' or r.status.state = PTP_SERVO_FAULT_C then
         v.status.state := PTP_SERVO_FAULT_C;
         v.state        := IDLE_S;
      end if;

      if rst = RST_POLARITY_G then
         v.measurementSlave.ready := '0';
      end if;

      -- Valid and payload enter COMMAND_S together and remain stable until
      -- accepted or canceled. Cancellation is also registered: if admission
      -- coincides with its detection, the PHC rejects the pending command on
      -- the following commit edge using r.commandMaster.cancel/r.commandMaster.stale.
      v.commandMaster.valid := '0';
      if v.state = COMMAND_S then
         v.commandMaster.valid := '1';
      end if;

      -- Register the request controls with the next operands and operation.
      -- Decoding v keeps valid aligned with ISSUE_S without adding a cycle.
      v.mathValid := '0';
      if v.state = ISSUE_S then
         v.mathValid := '1';
      end if;
      -- Phase normalization transports a signed remainder and truncates;
      -- all other operations retain nearest rounding.
      v.mathRound := '1';
      if v.operation = PHASE_DIVIDE_S then
         v.mathRound := '0';
      end if;

      -------------------------------------------------------------------------
      -- AXI-Lite: decode, map, then close the transaction.
      -------------------------------------------------------------------------
      axiSlaveWaitTxn(ep, axiWriteMaster, axiReadMaster, v.writeSlave, v.readSlave);

      -- Suppress register accesses during AXI-only reset.
      if regRst = '1' then
         ep.axiStatus := AXI_LITE_STATUS_INIT_C;
      end if;

      -- Phase policy, PI gains and actuator-limit shadows.
      axiSlaveRegister(ep, x"004", 2, v.shadow.allowStep);
      axiSlaveRegister(ep, x"020", 0, v.shadow.kp);
      axiSlaveRegister(ep, x"024", 0, v.shadow.ki);
      axiSlaveRegister(ep, x"028", 0, v.shadow.maxFrequencyPpb);
      axiSlaveRegister(ep, x"02C", 0, v.shadow.maxSlewPpb);
      axiSlaveRegister(ep, x"030", 0, v.shadow.maxRatePpb);

      -- Lock thresholds, qualification counts and sample timing.
      axiSlaveRegister(ep, x"038", 0, v.shadow.stepThreshold);
      axiSlaveRegister(ep, x"040", 0, v.shadow.lockThreshold);
      axiSlaveRegister(ep, x"048", 0, v.shadow.unlockThreshold);
      axiSlaveRegister(ep, x"050", 0, v.shadow.lockCount);
      axiSlaveRegister(ep, x"054", 0, v.shadow.unlockCount);
      axiSlaveRegister(ep, x"060", 0, v.shadow.maxDelayAge);
      axiSlaveRegister(ep, x"068", 0, v.shadow.holdoverTimeout);
      axiSlaveRegister(ep, x"070", 0, v.shadow.minSampleTicks);
      axiSlaveRegister(ep, x"078", 0, v.shadow.maxSampleTicks);
      axiSlaveRegister(ep, x"080", 0, v.shadow.delayAsymmetry);

      -- Live quality and active local/shared configuration.
      axiSlaveRegisterR(ep, x"090", 0, r.status.state);
      axiSlaveRegisterR(ep, x"090", 4, r.status.filterCount);
      axiSlaveRegisterR(ep, x"094", 0, r.activeConfig.kp);
      axiSlaveRegisterR(ep, x"098", 0, r.activeConfig.ki);
      axiSlaveRegisterR(ep, x"0A0", 0, sharedConfig.associationTimeout);
      axiSlaveRegisterR(ep, x"0A8", 0, sharedConfig.syncTimeout);
      axiSlaveRegisterR(ep, x"0B0", 0, sharedConfig.maxPathDelay);

      -- Coherent measurement and diagnostic snapshots.
      axiSlaveRegisterR(ep, x"100", 0, r.snapOffset);
      axiSlaveRegisterR(ep, x"110", 0, r.snapDelay);
      axiSlaveRegisterR(ep, x"120", 0, r.snapRate);
      axiSlaveRegisterR(ep, x"200", 0, r.snapRejected);
      axiSlaveRegisterR(ep, x"3FC", 0, r.sequenceId);

      axiSlaveDefault(ep, v.writeSlave, v.readSlave, AXI_RESP_DECERR_C);
      -- The bus reset cancels responses only. Accepted operations and active
      -- settings belong to the system-reset lifetime, not the AXI transaction.
      if regRst = '1' then
         v.readSlave  := AXI_LITE_READ_SLAVE_INIT_C;
         v.writeSlave := AXI_LITE_WRITE_SLAVE_INIT_C;
      end if;

      -------------------------------------------------------------------------
      -- Coordinated configuration and snapshots survive AXI-only reset.
      -------------------------------------------------------------------------

      -- Freeze candidate and vote together. Same-edge AXI writes belong to
      -- the next commit, so both use r.shadow rather than v.shadow.
      if configControl.prepare = '1' then
         v.candidate   := r.shadow;
         v.configValid := toSl(validConfig(r.shadow));
      end if;
      if configControl.apply = '1' then
         v.activeConfig := r.candidate;
      end if;
      if snapshotControl.capture = '1' then
         v.sequenceId   := snapshotControl.sequenceId;
         v.snapOffset   := r.status.offsetValue;
         v.snapDelay    := r.status.filteredDelay;
         v.snapRate     := r.status.ratePpb;
         v.snapRejected := r.status.rejectedCount;
      end if;
      -- Apply synchronous reset before publishing next state and outputs.
      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;
      rin <= v;

      -- Publish resolved controls and registered payloads without another
      -- decision stage. Combinational ready observes the reset override above.
      -- Measurement ready is the reverse capacity exception: holdover work and
      -- current cancellation share its input slot; delayed ready would require
      -- an extra reserved sample slot. Forward commands/cancel remain registered.
      axiReadSlave     <= r.readSlave;
      axiWriteSlave    <= r.writeSlave;
      configValid      <= r.configValid;
      measurementSlave <= v.measurementSlave;
      commandMaster    <= r.commandMaster;
      expireTime       <= r.expireTime;
      status           <= r.status;
      invalidate       <= r.commandMaster.cancel;
      inputMath        <= r.mathValid;
      roundMath        <= r.mathRound;
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
