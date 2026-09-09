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
-- last good frequency; expiry requests time-validity revocation. Cancellation
-- removes obsolete work, while a disabled servo drains measurements without
-- steering. PtpEndpoint coordinates external restart policy.
--
-- The local AXI-Lite bank stores gains, step/lock policy, sample-age limits
-- and asymmetry as writable shadows, frozen candidates and active settings.
-- Validation checks the frozen candidate before the endpoint-wide apply edge.
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
      expireTime        : out sl;
      commandMaster     : out PtpPhcCommandMasterType;
      commandSlave      : in  PtpPhcCommandSlaveType;
      status            : out PtpServoStatusType);
end entity PtpServo;

architecture rtl of PtpServo is

   function initialConfig return PtpServoConfigType is
      variable v      : PtpServoConfigType := PTP_SERVO_CONFIG_INIT_C;
      constant TICK_C : unsigned(63 downto 0) := to_unsigned(CLK_FREQ_G, 64);

   begin
      v.maxDelayAge := slv(shift_left(TICK_C, 2));
      v.holdoverTimeout := slv(shift_left(TICK_C, 6));
      v.minSampleTicks := slv(shift_right(TICK_C, 6));
      v.maxSampleTicks := slv(shift_left(TICK_C, 1));
      return v;
   end function;

   constant NOMINAL_C    : unsigned(63 downto 0) := unsigned(ptpNominalIncrement(CLK_FREQ_G));
   constant SECOND_Q16_C : signed(127 downto 0) := shift_left(to_signed(1000000000, 128), 16);

   type StateType is (
      IDLE_S,
      ISSUE_S,
      WAIT_S,
      COMMAND_S,
      ACK_S);

   type DelayArray is array (0 to 4) of signed(63 downto 0);
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
      -- Current-cycle calculations and diagnostics. Use v for same-edge
      -- decisions; these fields do not introduce a protocol pipeline stage.
      staleWork          : sl;
      abortWork          : sl;
      sampleTickDelta    : signed(127 downto 0);
      frequencyCandidate : signed(127 downto 0);
      integralDelta      : signed(127 downto 0);
      stale              : boolean;
      acceptSample       : boolean;
      integrate          : boolean;

      -- Local management state shares the core reset and register process.
      readSlave          : AxiLiteReadSlaveType;
      writeSlave         : AxiLiteWriteSlaveType;
      shadow             : PtpServoConfigType;
      candidate          : PtpServoConfigType;
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
      command            : PtpPhcCommandType;
      generation         : slv(31 downto 0);
      abortSeen          : sl;
      quality            : slv(2 downto 0);
      delays             : DelayArray;
      delayCount         : natural range 0 to 5;
      delayPtr           : natural range 0 to 4;
      delayTicks         : slv(63 downto 0);
      filtered           : signed(127 downto 0);
      offset             : signed(127 downto 0);
      sampleTicks        : slv(63 downto 0);
      lastTicks          : slv(63 downto 0);
      haveSample         : sl;
      tracking           : sl;
      holding            : sl;
      holdApplied        : sl;
      workFrequency      : signed(127 downto 0);
      frequency          : signed(127 downto 0);
      slew               : signed(127 downto 0);
      finalRate          : signed(127 downto 0);
      bootstrap          : signed(127 downto 0);
      interval           : signed(127 downto 0);
      good               : unsigned(7 downto 0);
      bad                : unsigned(7 downto 0);
      rejected           : slv(31 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      staleWork          => '0',
      abortWork          => '0',
      sampleTickDelta    => (others => '0'),
      frequencyCandidate => (others => '0'),
      integralDelta      => (others => '0'),
      stale              => false,
      acceptSample       => false,
      integrate          => false,
      readSlave          => AXI_LITE_READ_SLAVE_INIT_C,
      writeSlave         => AXI_LITE_WRITE_SLAVE_INIT_C,
      shadow             => initialConfig,
      candidate          => initialConfig,
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
      command            => PTP_PHC_COMMAND_INIT_C,
      generation         => (others => '0'),
      abortSeen          => '0',
      quality            => PTP_SERVO_ACQUIRING_C,
      delays             => (others => (others => '0')),
      delayCount         => 0,
      delayPtr           => 0,
      delayTicks         => (others => '0'),
      filtered           => (others => '0'),
      offset             => (others => '0'),
      sampleTicks        => (others => '0'),
      lastTicks          => (others => '0'),
      haveSample         => '0',
      tracking           => '0',
      holding            => '0',
      holdApplied        => '0',
      frequency          => (others => '0'),
      workFrequency      => (others => '0'),
      slew               => (others => '0'),
      finalRate          => (others => '0'),
      bootstrap          => (others => '0'),
      interval           => (others => '0'),
      good               => (others => '0'),
      bad                => (others => '0'),
      rejected           => (others => '0'));

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

   function clamp (value : signed(127 downto 0);
   maximum : slv(31 downto 0)) return signed is
      variable limitValue : signed(127 downto 0);
   begin
      limitValue := shift_left(signed(resize(unsigned(maximum), 128)), 16);
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
   begin
      v      := r;
      sorted := r.delays;
      temp   := (others => '0');

      -- A held link/port abort cancels once, allowing later holdover work.
      -- Generation changes and stale samples independently invalidate work.
      v.staleWork := '0';
      if r.state /= IDLE_S and r.holding = '0' and
         unsigned(phcStatus.ticks)-unsigned(r.sampleTicks) > unsigned(sharedConfig.associationTimeout) then
         v.staleWork := '1';
      end if;
      v.abortWork := '0';
      if v.staleWork = '1' or restart = '1' or
         (measurementMaster.abort = '1' and r.abortSeen = '0') or
         phcStatus.generation /= r.generation or servoEnable = '0' then
         v.abortWork := '1';
      end if;

      v.abortSeen    := measurementMaster.abort;
      v.generation   := phcStatus.generation;
      v.stale        := r.haveSample = '1' and (measurementMaster.abort = '1' or r.delayCount = 0 or
         unsigned(phcStatus.ticks)-unsigned(r.delayTicks) > unsigned(r.activeConfig.maxDelayAge) or
         unsigned(phcStatus.ticks)-unsigned(r.lastTicks) > unsigned(sharedConfig.syncTimeout));
      v.acceptSample := false;
      if v.stale then
         v.quality  := PTP_SERVO_HOLDOVER_C;
         v.tracking := '0';
         v.good     := (others => '0');
      end if;
      -- Accept/filter a sample, evaluate the loop in named arithmetic stages,
      -- then wait for PHC acceptance and acknowledgement before updating history.
      case r.state is
         when IDLE_S =>
            if v.stale and r.holdApplied = '0' then
               -- Holdover removes the phase slew but preserves the last good
               -- frequency estimate. Conversion uses the same checked path as
               -- tracking; no combinational wide divider enters the clock loop.
               v.finalRate := clamp(r.frequency, r.activeConfig.maxRatePpb);
               v.a         := slv(v.finalRate);
               v.b         := slv(resize(NOMINAL_C, 128));
               v.divide    := '0';
               v.operation := RATE_SCALE_S;
               v.holding   := '1';
               v.state     := ISSUE_S;
            elsif measurementMaster.valid = '1' and measurementMaster.abort = '0' and servoEnable = '1' then
               if measurementMaster.data.generation /= phcStatus.generation or
                  unsigned(measurementMaster.data.ticks) > unsigned(phcStatus.ticks) or
                  unsigned(phcStatus.ticks)-unsigned(measurementMaster.data.ticks) > unsigned(sharedConfig.associationTimeout) then
                  v.rejected := ptpSatInc(v.rejected);
               elsif measurementMaster.data.isDelay = '1' then
                  if signed(measurementMaster.data.delayValue) >= 0 and signed(measurementMaster.data.delayValue) <= signed(sharedConfig.maxPathDelay) and
                     (r.delayCount = 0 or unsigned(measurementMaster.data.ticks) > unsigned(r.delayTicks)) then
                     v.delays(r.delayPtr) := signed(measurementMaster.data.delayValue(63 downto 0));
                     v.delayPtr           := (r.delayPtr+1) mod 5;
                     if r.delayCount < 5 then
                        v.delayCount := r.delayCount+1;
                     end if;
                     sorted := v.delays;
                     -- Sort only populated entries. Zero-filled startup history
                     -- is never mistaken for five accepted zero-delay samples.
                     for i in 0 to 4 loop
                        for j in 0 to 3 loop
                           if j+1 < v.delayCount and sorted(j) > sorted(j+1) then
                              temp        := sorted(j);
                              sorted(j)   := sorted(j+1);
                              sorted(j+1) := temp;
                           end if;
                        end loop;
                     end loop;
                     v.filtered   := resize(sorted((v.delayCount-1)/2), 128);
                     v.delayTicks := measurementMaster.data.ticks;
                  else
                     v.rejected := ptpSatInc(v.rejected);
                  end if;
               elsif r.delayCount /= 0 and measurementMaster.data.ratioValid = '1' and
                  unsigned(phcStatus.ticks)-unsigned(r.delayTicks) <= unsigned(r.activeConfig.maxDelayAge) and
                  (r.haveSample = '0' or unsigned(measurementMaster.data.ticks) > unsigned(r.lastTicks)) then
                  v.sampleTickDelta := signed(resize(unsigned(measurementMaster.data.ticks), 128))-signed(resize(unsigned(r.lastTicks), 128));
                  if r.tracking = '1' and (v.sampleTickDelta < signed(resize(unsigned(r.activeConfig.minSampleTicks), 128)) or
                     v.sampleTickDelta > signed(resize(unsigned(r.activeConfig.maxSampleTicks), 128))) then
                     v.rejected := ptpSatInc(v.rejected);
                  else
                     v.offset             := signed(measurementMaster.data.forward)-r.filtered-resize(signed(r.activeConfig.delayAsymmetry), 128);
                     v.sampleTicks        := measurementMaster.data.ticks;
                     v.holding            := '0';
                     v.command            := PTP_PHC_COMMAND_INIT_C;
                     v.command.generation := phcStatus.generation;
                     if phcStatus.timeValid = '0' and r.activeConfig.allowStep = '1' and abs(v.offset) > signed(r.activeConfig.stepThreshold) then
                        -- Normalize the full acquisition epoch delta outside the
                        -- PHC. Quotient/remainder are transported atomically and
                        -- applied to the normally advanced commit-edge time.
                        v.a         := slv(-v.offset);
                        v.b         := slv(SECOND_Q16_C);
                        v.divide    := '1';
                        v.operation := PHASE_DIVIDE_S;
                        v.state     := ISSUE_S;
                     elsif resize(resize(v.offset, 64), 128) /= v.offset then
                        v.rejected := ptpSatInc(v.rejected);
                     else
                        v.a         := slv(signed(resize(unsigned(measurementMaster.data.ratio), 128))-
                                   signed(shift_left(resize(NOMINAL_C, 128), 16)));
                        v.b         := slv(to_signed(1000000000, 128));
                        v.divide    := '0';
                        v.operation := RATIO_SCALE_S;
                        v.state     := ISSUE_S;
                     end if;
                  end if;
               end if;
            end if;
         when ISSUE_S =>
            if readyMath = '1' then
               v.state := WAIT_S;
            end if;
         when WAIT_S =>
            if validMath = '1' then
               v.state := ISSUE_S;
               if errorMath = '1' then
                  v.state    := IDLE_S;
                  v.rejected := ptpSatInc(v.rejected);
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
                        v.a         := slv(r.offset);
                        v.b         := slv(resize(unsigned(r.activeConfig.kp), 128));
                        v.divide    := '0';
                        v.operation := PROPORTIONAL_S;
                     when PROPORTIONAL_S =>
                        v.slew := clamp(-ptpRoundShift(signed(valueMath), 30), r.activeConfig.maxSlewPpb);
                        if r.tracking = '0' then
                           -- First apply qualified oscillator feedforward. Seed
                           -- the integrator minus the new proportional term, so
                           -- entry to tracking preserves this applied command.
                           v.workFrequency := clamp(r.bootstrap-v.slew, r.activeConfig.maxFrequencyPpb);
                           v.finalRate     := clamp(v.workFrequency+v.slew, r.activeConfig.maxRatePpb);
                           v.a             := slv(v.finalRate);
                           v.b             := slv(resize(NOMINAL_C, 128));
                           v.operation     := RATE_SCALE_S;
                        else
                           v.a         := slv(resize(unsigned(r.sampleTicks)-unsigned(r.lastTicks), 128));
                           v.b         := slv(resize(NOMINAL_C, 128));
                           v.operation := INTERVAL_SCALE_S;
                        end if;
                     when INTERVAL_SCALE_S =>
                        v.a         := valueMath;
                        v.b         := slv(to_signed(1000000000, 128));
                        v.divide    := '1';
                        v.operation := INTERVAL_DIVIDE_S;
                     when INTERVAL_DIVIDE_S =>
                        v.interval  := signed(valueMath); -- seconds Q32
                        v.a         := slv(r.offset);
                        v.b         := slv(resize(unsigned(r.activeConfig.ki), 128));
                        v.divide    := '0';
                        v.operation := INTEGRAL_GAIN_S;
                     when INTEGRAL_GAIN_S =>
                        v.a         := valueMath; -- Q16 offset * Q30 gain
                        v.b         := slv(r.interval); -- seconds Q32
                        v.operation := INTEGRAL_TIME_S;
                     when INTEGRAL_TIME_S =>
                        v.integralDelta      := -ptpRoundShift(signed(valueMath), 62); -- ppb Q16
                        v.frequencyCandidate := r.frequency+v.integralDelta;
                        v.workFrequency      := clamp(v.frequencyCandidate, r.activeConfig.maxFrequencyPpb);
                        -- Conditional integration freezes only outward movement
                        -- at either frequency or final-rate saturation. Movement
                        -- back toward the linear region remains possible.
                        v.integrate := true;
                        if v.frequencyCandidate /= v.workFrequency then
                           if (v.frequencyCandidate > 0 and v.integralDelta > 0) or (v.frequencyCandidate < 0 and v.integralDelta < 0) then
                              v.integrate := false;
                           end if;
                        end if;
                        if clamp(v.workFrequency+r.slew, r.activeConfig.maxRatePpb) /= v.workFrequency+r.slew then
                           if (v.workFrequency+r.slew > 0 and v.integralDelta > 0) or (v.workFrequency+r.slew < 0 and v.integralDelta < 0) then
                              v.integrate := false;
                           end if;
                        end if;
                        if not v.integrate then
                           v.workFrequency := r.frequency;
                        end if;
                        v.finalRate := clamp(v.workFrequency+r.slew, r.activeConfig.maxRatePpb);
                        v.a         := slv(v.finalRate);
                        v.b         := slv(resize(NOMINAL_C, 128));
                        v.divide    := '0';
                        v.operation := RATE_SCALE_S;
                     when RATE_SCALE_S =>
                        v.a         := valueMath;
                        v.b         := slv(SECOND_Q16_C); -- 1e9 * 2^16
                        v.divide    := '1';
                        v.operation := RATE_DIVIDE_S;
                     when RATE_DIVIDE_S =>
                        if resize(resize(signed(valueMath), 64), 128) /= signed(valueMath) then
                           v.quality := PTP_SERVO_FAULT_C;
                           v.state   := IDLE_S;
                        else
                           v.command            := PTP_PHC_COMMAND_INIT_C;
                           v.command.kind       := PTP_CMD_RATE_C;
                           v.command.generation := phcStatus.generation;
                           v.command.rate       := valueMath(63 downto 0);
                           v.state              := COMMAND_S;
                        end if;
                     when PHASE_DIVIDE_S =>
                        if resize(resize(signed(valueMath), 64), 128) /= signed(valueMath) then
                           v.quality := PTP_SERVO_FAULT_C;
                           v.state   := IDLE_S;
                        else
                           v.command.kind          := PTP_CMD_PHASE_C;
                           v.command.phaseSeconds  := valueMath(63 downto 0);
                           v.command.phaseFraction := slv(shift_left(resize(signed(remainderMath), 64), 16));
                           v.state                 := COMMAND_S;
                        end if;
                     when others =>
                        v.quality := PTP_SERVO_FAULT_C;
                        v.state   := IDLE_S;
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
                  v.quality := PTP_SERVO_FAULT_C;
               elsif r.command.kind = PTP_CMD_RATE_C then
                  if r.holding = '1' then
                     v.holdApplied := '1';
                  else
                     v.acceptSample := true;
                     v.frequency    := r.workFrequency;
                     v.tracking     := '1';
                     v.holdApplied  := '0';
                     if phcStatus.timeValid = '0' then
                        v.command.kind  := PTP_CMD_VALID_C;
                        v.command.value := '1';
                        v.state         := COMMAND_S;
                     end if;
                  end if;
               end if;
            end if;
      end case;
      -- Lock hysteresis uses only a sample whose rate command was acknowledged.
      if v.acceptSample then
         v.lastTicks  := r.sampleTicks;
         v.haveSample := '1';
         v.quality    := PTP_SERVO_TRACKING_C;
         if abs(r.offset) <= signed(r.activeConfig.lockThreshold) then
            if r.good /= x"FF" then
               v.good := r.good+1;
            end if;
            v.bad := (others => '0');
         elsif abs(r.offset) >= signed(r.activeConfig.unlockThreshold) then
            v.good := (others => '0');
            if r.bad /= x"FF" then
               v.bad := r.bad+1;
            end if;
         end if;
         if v.good >= unsigned(r.activeConfig.lockCount) or (r.quality = PTP_SERVO_LOCKED_C and v.bad < unsigned(r.activeConfig.unlockCount)) then
            v.quality := PTP_SERVO_LOCKED_C;
         end if;
      end if;
      -- Cancellation overrides work above; disabling/fault policy then selects
      -- the externally visible quality without discarding retained frequency.
      if v.abortWork = '1' then
         v.state       := IDLE_S;
         v.delayCount  := 0;
         v.delayPtr    := 0;
         v.tracking    := '0';
         v.holdApplied := '0';
         v.good        := (others => '0');
         v.bad         := (others => '0');
         v.quality     := PTP_SERVO_ACQUIRING_C;
         if r.haveSample = '1' then
            v.quality := PTP_SERVO_HOLDOVER_C;
         end if;
      end if;
      if servoEnable = '0' then
         v.quality    := PTP_SERVO_DISABLED_C;
         v.haveSample := '0';
      end if;
      if phcStatus.fault = '1' or r.quality = PTP_SERVO_FAULT_C then
         v.quality := PTP_SERVO_FAULT_C;
         v.state   := IDLE_S;
      end if;
      -- Local AXI register map, frozen configuration and snapshot capture.

      axiSlaveWaitTxn(ep, axiWriteMaster, axiReadMaster, v.writeSlave, v.readSlave);
      if regRst = '1' then
         ep.axiStatus := AXI_LITE_STATUS_INIT_C;
      end if;
      if ep.axiStatus.writeEnable = '1' and axiWriteMaster.awaddr(1 downto 0) /= "00" then
         ep.axiStatus.writeEnable := '0';
         axiSlaveWriteResponse(ep.axiWriteSlave, AXI_RESP_SLVERR_C);
      end if;
      if ep.axiStatus.readEnable = '1' and axiReadMaster.araddr(1 downto 0) /= "00" then
         ep.axiStatus.readEnable := '0';
         axiSlaveReadResponse(ep.axiReadSlave, AXI_RESP_SLVERR_C);
      end if;
      if ep.axiStatus.readEnable = '1' or ep.axiStatus.writeEnable = '1' then
         axiSlaveRegisterR(ep, toSlv(16#094#, 10), 0, r.activeConfig.kp);
         axiSlaveRegisterR(ep, toSlv(16#098#, 10), 0, r.activeConfig.ki);
         axiSlaveRegisterR(ep, toSlv(16#0A0#, 10), 0, sharedConfig.associationTimeout);
         axiSlaveRegisterR(ep, toSlv(16#0A8#, 10), 0, sharedConfig.syncTimeout);
         axiSlaveRegisterR(ep, toSlv(16#0B0#, 10), 0, sharedConfig.maxPathDelay);
         axiSlaveRegister(ep, toSlv(16#004#, 10), 2, v.shadow.allowStep);
         axiSlaveRegister(ep, toSlv(16#020#, 10), 0, v.shadow.kp);
         axiSlaveRegister(ep, toSlv(16#024#, 10), 0, v.shadow.ki);
         axiSlaveRegister(ep, toSlv(16#028#, 10), 0, v.shadow.maxFrequencyPpb);
         axiSlaveRegister(ep, toSlv(16#02C#, 10), 0, v.shadow.maxSlewPpb);
         axiSlaveRegister(ep, toSlv(16#030#, 10), 0, v.shadow.maxRatePpb);
         axiSlaveRegister(ep, toSlv(16#038#, 10), 0, v.shadow.stepThreshold);
         axiSlaveRegister(ep, toSlv(16#040#, 10), 0, v.shadow.lockThreshold);
         axiSlaveRegister(ep, toSlv(16#048#, 10), 0, v.shadow.unlockThreshold);
         axiSlaveRegister(ep, toSlv(16#050#, 10), 0, v.shadow.lockCount);
         axiSlaveRegister(ep, toSlv(16#054#, 10), 0, v.shadow.unlockCount);
         axiSlaveRegister(ep, toSlv(16#060#, 10), 0, v.shadow.maxDelayAge);
         axiSlaveRegister(ep, toSlv(16#068#, 10), 0, v.shadow.holdoverTimeout);
         axiSlaveRegister(ep, toSlv(16#070#, 10), 0, v.shadow.minSampleTicks);
         axiSlaveRegister(ep, toSlv(16#078#, 10), 0, v.shadow.maxSampleTicks);
         axiSlaveRegister(ep, toSlv(16#080#, 10), 0, v.shadow.delayAsymmetry);
         axiSlaveRegisterR(ep, toSlv(16#090#, 10), 0, r.quality);
         axiSlaveRegisterR(ep, toSlv(16#090#, 10), 4, slv(to_unsigned(r.delayCount, 3)));
         axiSlaveRegisterR(ep, toSlv(16#100#, 10), 0, r.snapOffset);
         axiSlaveRegisterR(ep, toSlv(16#110#, 10), 0, r.snapDelay);
         axiSlaveRegisterR(ep, toSlv(16#120#, 10), 0, r.snapRate);
         axiSlaveRegisterR(ep, toSlv(16#200#, 10), 0, r.snapRejected);
         axiSlaveRegisterR(ep, toSlv(16#3FC#, 10), 0, r.sequenceId);
      end if;

      configValid <= '1';

      -- Phase policy and lock hysteresis.
      if signed(r.candidate.stepThreshold) < 0 then
         configValid <= '0';
      end if;
      if signed(r.candidate.lockThreshold) < 0 then
         configValid <= '0';
      end if;
      if signed(r.candidate.unlockThreshold) < signed(r.candidate.lockThreshold) then
         configValid <= '0';
      end if;
      if unsigned(r.candidate.lockCount) = 0 or unsigned(r.candidate.unlockCount) = 0 then
         configValid <= '0';
      end if;

      -- Actuator limits and sample chronology.
      if unsigned(r.candidate.maxRatePpb) > 200000 then
         configValid <= '0';
      end if;
      if unsigned(r.candidate.maxFrequencyPpb) > unsigned(r.candidate.maxRatePpb) then
         configValid <= '0';
      end if;
      if unsigned(r.candidate.maxSlewPpb) > unsigned(r.candidate.maxRatePpb) then
         configValid <= '0';
      end if;
      if unsigned(r.candidate.maxSampleTicks) < unsigned(r.candidate.minSampleTicks) then
         configValid <= '0';
      end if;

      -- Every timeout must fit the supported unsigned-difference range.
      if not ptpValidTimeout(r.candidate.maxDelayAge) then
         configValid <= '0';
      end if;
      if not ptpValidTimeout(r.candidate.holdoverTimeout) then
         configValid <= '0';
      end if;
      if not ptpValidTimeout(r.candidate.minSampleTicks) then
         configValid <= '0';
      end if;
      if not ptpValidTimeout(r.candidate.maxSampleTicks) then
         configValid <= '0';
      end if;

      if configControl.prepare = '1' then
         v.candidate := r.shadow;
      end if;
      if configControl.apply = '1' then
         v.activeConfig := r.candidate;
      end if;
      if snapshotControl.capture = '1' then
         v.sequenceId   := snapshotControl.sequenceId;
         v.snapOffset   := slv(r.offset);
         v.snapDelay    := slv(r.filtered);
         v.snapRate     := slv(r.finalRate(63 downto 0));
         v.snapRejected := r.rejected;
      end if;
      axiSlaveDefault(ep, v.writeSlave, v.readSlave, AXI_RESP_DECERR_C);
      -- The bus reset cancels responses only. Accepted operations and active
      -- settings belong to the system-reset lifetime, not the AXI transaction.
      if regRst = '1' then
         v.readSlave  := AXI_LITE_READ_SLAVE_INIT_C;
         v.writeSlave := AXI_LITE_WRITE_SLAVE_INIT_C;
      end if;
      axiReadSlave  <= r.readSlave;
      axiWriteSlave <= r.writeSlave;

      measurementSlave.ready <= '0';
      -- A disabled servo still drains measurements. Manual clock ownership must
      -- not stall the port's association queue or prevent protocol diagnostics.
      if servoEnable = '0' and rst /= RST_POLARITY_G then
         measurementSlave.ready <= '1';
      elsif r.state = IDLE_S and not (v.stale and r.holdApplied = '0') and v.abortWork = '0' and r.quality /= PTP_SERVO_FAULT_C and rst /= RST_POLARITY_G then
         measurementSlave.ready <= '1';
      end if;
      commandMaster.valid <= '0';
      if r.state = COMMAND_S and v.abortWork = '0' and r.quality /= PTP_SERVO_FAULT_C and rst /= RST_POLARITY_G then
         commandMaster.valid <= '1';
      end if;
      commandMaster.data   <= r.command;
      commandMaster.cancel <= v.abortWork;
      commandMaster.stale  <= v.staleWork;
      expireTime           <= '0';
      if r.quality = PTP_SERVO_FAULT_C or (servoEnable = '1' and r.haveSample = '1' and
         unsigned(phcStatus.ticks)-unsigned(r.lastTicks) > unsigned(r.activeConfig.holdoverTimeout)) then
         expireTime <= '1';
      end if;
      status.state         <= r.quality;
      status.filteredDelay <= slv(r.filtered);
      status.offsetValue   <= slv(r.offset);
      status.ratePpb       <= slv(r.finalRate(63 downto 0));
      status.filterCount   <= slv(to_unsigned(r.delayCount, 3));
      status.rejectedCount <= r.rejected;
      invalidate           <= v.abortWork;
      inputMath            <= '0';
      if r.state = ISSUE_S then
         inputMath <= '1';
      end if;
      roundMath <= '1';
      if r.operation = PHASE_DIVIDE_S then
         roundMath <= '0';
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
