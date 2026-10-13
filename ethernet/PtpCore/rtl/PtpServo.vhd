-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PTP acquisition, filtered delay estimation and PHC feedback
-- control.
--
-- Accepts separate forward and path-delay measurements from PtpProtocolEngine. Up to
-- five populated delay samples form a median filter; local-minus-master offset
-- is forward time minus filtered delay and configured asymmetry. Generation,
-- sample chronology and raw-tick age checks reject stale measurements before
-- they can affect the clock.
-- The median sorts RAM scratch through nine shared-service comparisons and
-- conditional word copies. Input ready stays low until atomic publication;
-- the prior median/population remain stable throughout the sequence.
--
-- Control is measurement-driven: delay updates refresh the filter, while an
-- eligible forward (Sync) update starts a correction using the latest delay.
-- There is no local 1 Hz servo timer. A 1 Hz Sync source gives approximately
-- that update cadence after acquisition; qualification can reject updates.
-- The actuator here is the PHC's numerical ns-per-tick increment. No output
-- of this module directly tunes the oscillator supplying clk.
--
-- During acquisition, an enabled large phase adjustment can establish the
-- epoch. Otherwise the qualified raw-clock rate estimate initializes frequency
-- control. The endpoint-owned word processor evaluates the fixed-point
-- proportional/integral loop, including elapsed-time integration, frequency
-- and phase-slew clamps, final-rate limiting and conditional integration at
-- saturation. Commands use the PHC ready/valid and acknowledgement lifecycle;
-- only acknowledged rate commands update the retained frequency estimate.
-- Addressed intermediates, committed/candidate frequency and sorting scratch
-- remain in the shared workspace. Cancellation and expiry remain active in
-- every state; command acknowledgement waiting releases the arithmetic engine.
--
-- Lock/unlock thresholds and counters provide quality hysteresis. Loss of
-- fresh measurements enters holdover, removes phase slew and preserves the
-- last good frequency; registered expiry requests time-validity revocation
-- on the next PHC edge. Registered command cancellation can revoke a request
-- accepted on its detection edge before the PHC commits it. A disabled servo
-- drains measurements without steering. PtpEndpointControl owns restart policy.
--
-- The local AXI-Lite bank stores gains, step/lock policy, sample-age limits
-- and asymmetry as writable shadows, frozen candidates and active settings.
-- Candidate validity is captured on prepare for the later coordinated apply.
-- Shared association, sync and path-delay limits come from PtpProtocolEngine's active
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
use surf.PtpComputePkg.all;
use surf.PtpRegisterPkg.all;

entity PtpServo is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      CLK_FREQ_G     : positive := 156250000);
   port (
      -- Shared endpoint clock domain.
      clk : in  sl;
      rst : in  sl;
      -- Local AXI-Lite bank and endpoint coordination (clk domain).
      regRst           : in  sl                     := '0';
      axiReadMaster    : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axiReadSlave     : out AxiLiteReadSlaveType;
      axiWriteMaster   : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axiWriteSlave    : out AxiLiteWriteSlaveType;
      configControl    : in  PtpConfigControlType   := PTP_CONFIG_CONTROL_INIT_C;
      snapshotControl  : in  PtpSnapshotControlType := PTP_SNAPSHOT_CONTROL_INIT_C;
      snapshotPrepared : out sl;
      configValid      : out sl;
      configPrepared   : out sl;
      servoEnable      : in  sl                     := '0';
      sharedConfig     : in  PtpSharedConfigType    := PTP_SHARED_CONFIG_INIT_C;
      -- Protocol/clock interface.
      measurementMaster : in  PtpMeasurementMasterType;
      measurementSlave  : out PtpMeasurementSlaveType;
      restart           : in  sl            := '0';
      phcStatus         : in  PtpPhcStatusType;
      -- Registered revocation level; the PHC consumes it on the next edge.
      expireTime    : out sl;
      commandMaster : out PtpPhcCommandMasterType;
      commandSlave  : in  PtpPhcCommandSlaveType;
      status        : out PtpServoStatusType;
      computeMaster : out PtpComputeMasterType;
      computeSlave  : in PtpComputeSlaveType);
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

   -- Only admission/expiry policy is cached for cycle-by-cycle decisions.
   -- Gains, thresholds, asymmetry and clamps are read from the active word bank
   -- when their arithmetic stage needs them.
   type ControlCacheType is record
      allowStep       : sl;
      lockCount       : slv(7 downto 0);
      unlockCount     : slv(7 downto 0);
      maxDelayAge     : slv(63 downto 0);
      holdoverTimeout : slv(63 downto 0);
      minSampleTicks  : slv(63 downto 0);
      maxSampleTicks  : slv(63 downto 0);
   end record;

   function initialCache return ControlCacheType is
      constant CFG_C : PtpServoConfigType := initialConfig;
   begin
      return (CFG_C.allowStep, CFG_C.lockCount, CFG_C.unlockCount, CFG_C.maxDelayAge,
         CFG_C.holdoverTimeout, CFG_C.minSampleTicks, CFG_C.maxSampleTicks);
   end function;

   function initialWords return Slv32Array is
      constant CFG_C : PtpServoConfigType := initialConfig;
      variable words : Slv32Array(0 to 33) := (others => (others => '0'));
      procedure put(constant index : natural;
      constant value : slv) is
      begin
         for i in 0 to (value'length+31)/32-1 loop
            words(index+i) := slv(resize(shift_right(unsigned(value),32*i),32));
         end loop;
      end procedure;

   begin
      words(1)(2) := CFG_C.allowStep;
      put(8,CFG_C.kp);
      put(9,CFG_C.ki);
      put(10,CFG_C.maxFrequencyPpb);
      put(11,CFG_C.maxSlewPpb);
      put(12,CFG_C.maxRatePpb);
      put(14,CFG_C.stepThreshold);
      put(16,CFG_C.lockThreshold);
      put(18,CFG_C.unlockThreshold);
      put(20,CFG_C.lockCount);
      put(21,CFG_C.unlockCount);
      put(24,CFG_C.maxDelayAge);
      put(26,CFG_C.holdoverTimeout);
      put(28,CFG_C.minSampleTicks);
      put(30,CFG_C.maxSampleTicks);
      put(32,CFG_C.delayAsymmetry);
      return words;
   end function;

   function configIndex(address : slv(11 downto 0)) return integer is
      variable index : natural := to_integer(unsigned(address(11 downto 2)));
   begin

      case index is
         when 1 | 8 to 12 | 14 to 21 | 24 to 33 =>
            return index;
         when others =>
            return -1;
      end case;

   end function;

   function configMask(index : integer;
   strobe : slv(3 downto 0)) return slv is
      variable mask : slv(31 downto 0) := (others => '0');
   begin

      if index = 1 and strobe(0) = '1' then
         mask(2) := '1';
      elsif (index = 20 or index = 21) and strobe(0) = '1' then
         mask(7 downto 0) := (others => '1');
      elsif index /= 1 and index /= 20 and index /= 21 and strobe = x"F" then
         mask := (others => '1');
      end if;

      return mask;
   end function;

   constant NOMINAL_C    : unsigned(63 downto 0) := unsigned(ptpNominalIncrement(CLK_FREQ_G));
   constant SECOND_Q16_C : signed(127 downto 0)  := shift_left(to_signed(PTP_NANOSECONDS_PER_SECOND_C, 128), PTP_TIME_FRAC_BITS_C);
   constant PPB_Q16_SCALE_C : signed(127 downto 0) := shift_left(to_signed(PTP_PPB_SCALE_C, 128), PTP_PPB_FRAC_BITS_C);
   -- Elaboration only: the encoded increment exceeds the VHDL integer range.
   -- Offset Q16 * gain Q30 -> ppb Q16. Integration additionally multiplies
   -- by elapsed seconds with the PHC addend's fractional precision (Q32).
   constant PROPORTIONAL_SHIFT_C : natural := PTP_TIME_FRAC_BITS_C+PTP_GAIN_FRAC_BITS_C-PTP_PPB_FRAC_BITS_C;
   constant INTEGRAL_SHIFT_C     : natural := PROPORTIONAL_SHIFT_C+PTP_PHC_FRAC_BITS_C;
   -- Arithmetic/command progress, distinct from status.state's synchronization
   -- quality (acquiring, tracking, locked, holdover, fault). PtpPhc continues
   -- ticking while this FSM waits for a multi-cycle math result or command ACK.
   type StateType is (
      IDLE_S,
      INIT_COPY_S,
      INIT_DONE_S,
      LOAD_S, CONFIG_READ_S, CONFIG_WAIT_S,
      READ_S,
      READ_WAIT_S,
      ISSUE_S,
      WAIT_S,
      DELAY_HIGH_S,
      DELAY_ACCEPT_S,
      MEDIAN_FETCH_S,
      MEDIAN_RAM_WAIT_S,
      MEDIAN_RAM_CAPTURE_S,
      MEDIAN_STORE_S,
      MEDIAN_COMPARE_S,
      MEDIAN_DECIDE_S,
      MEDIAN_SWAP_RIGHT_S,
      MEDIAN_SWAP_LEFT_S,
      MEDIAN_NEXT_S,
      MEDIAN_PUBLISH_S,
      FORWARD_RATIO_S,
      FORWARD_ACCEPT_S,
      OFFSET_DELAY_S,
      OFFSET_ASYMMETRY_S,
      OFFSET_SUBTRACT_S,
      OFFSET_READ_S,
      OFFSET_PUBLISH_S,
      OFFSET_ABSOLUTE_S,
      OFFSET_THRESHOLD_S,
      OFFSET_DECIDE_S,
      LOCK_COMPARE_S,
      LOCK_CAPTURE_S,
      UNLOCK_COMPARE_S,
      UNLOCK_CAPTURE_S,
      BOOT_DIFFERENCE_S,
      BOOT_SCALE_S,
      BOOT_MULTIPLY_S,
      BOOT_DENOMINATOR_S,
      BOOT_DIVIDE_S,
      BOOT_CLAMP_S,
      PROPORTIONAL_LOAD_S,
      PROPORTIONAL_MULTIPLY_S,
      PROPORTIONAL_ROUND_S,
      PROPORTIONAL_NEGATE_S,
      PROPORTIONAL_CLAMP_S,
      PROPORTIONAL_DONE_S,
      INTERVAL_LOAD_S,
      INTERVAL_SUBTRACT_S,
      INTERVAL_NOMINAL_S,
      INTERVAL_MULTIPLY_S,
      INTERVAL_SCALE_S,
      INTERVAL_DIVIDE_S,
      INTEGRAL_GAIN_LOAD_S,
      INTEGRAL_GAIN_MULTIPLY_S,
      INTEGRAL_TIME_MULTIPLY_S,
      INTEGRAL_ROUND_S,
      INTEGRAL_NEGATE_S,
      INTEGRAL_SIGN_S,
      INTEGRAL_ADD_S,
      BOOT_FREQUENCY_S,
      FREQUENCY_CLAMP_S,
      FREQUENCY_DONE_S,
      RATE_TRIAL_S,
      RATE_TRIAL_CLAMP_S,
      RATE_TRIAL_CHECK_S,
      RATE_SUM_S,
      RATE_LIMIT_S,
      RATE_READ_S,
      RATE_PUBLISH_S,
      RATE_NOMINAL_S,
      RATE_MULTIPLY_S,
      RATE_SCALE_S,
      RATE_DIVIDE_S,
      RATE_COMMAND_S,
      PHASE_NEGATE_S,
      PHASE_SCALE_S,
      PHASE_DIVIDE_S,
      PHASE_QUOTIENT_S,
      PHASE_SECONDS_S,
      PHASE_REMAINDER_S,
      PHASE_COMMAND_S,
      CLAMP_POSITIVE_S,
      CLAMP_POSITIVE_CHECK_S,
      CLAMP_NEGATE_S,
      CLAMP_NEGATIVE_S,
      CLAMP_NEGATIVE_CHECK_S,
      COMMAND_S,
      ACK_S);

   -- The same nine sorting-network pairs are visited by one comparator.
   -- Keep the circular history separate from this destructively sorted copy.
   type MedianIndexArray is array (0 to 8) of natural range 0 to DELAY_FILTER_DEPTH_C-1;
   constant MEDIAN_LEFT_C  : MedianIndexArray := (0, 1, 0, 1, 0, 2, 1, 3, 2);
   constant MEDIAN_RIGHT_C : MedianIndexArray := (3, 4, 2, 3, 1, 4, 2, 4, 3);
   type LoadType is (ZERO_L, INPUT_FORWARD_L, INPUT_RATIO_L, FILTER_L, ASYMMETRY_L, STEP_L, LOCK_L, UNLOCK_L, NOMINAL_RATIO_L, NOMINAL_L, BILLION_L, SECOND_L, KP_L, KI_L, SAMPLE_TICKS_L, LAST_TICKS_L, MAX_FREQUENCY_L, MAX_SLEW_L, MAX_RATE_L);
   type RegType is record
      -- Registered command interface. Use v.commandMaster.cancel/stale for
      -- current-edge local decisions and publish the complete record from r.
      commandMaster : PtpPhcCommandMasterType;
      -- Combinational measurement admission, resolved through v each cycle.
      measurementSlave : PtpMeasurementSlaveType;
      expireTime       : sl;
      status           : PtpServoStatusType;
      -- Local management state shares the core reset and register process.
      readSlave          : AxiLiteReadSlaveType;
      writeSlave         : AxiLiteWriteSlaveType;
      candidate          : ControlCacheType;
      configBus          : PtpRegisterBusType;
      configMaster       : PtpRegisterMasterType;
      configWord         : slv(31 downto 0);
      configSign         : sl;
      validateValue      : slv(63 downto 0);
      validatePrevious   : slv(63 downto 0);
      validateFrequency  : slv(31 downto 0);
      validateSlew       : slv(31 downto 0);
      configValid        : sl;
      activeConfig       : ControlCacheType;
      sequenceId         : slv(31 downto 0);
      publicationPort    : PtpPublicationType;
      snapshotBus        : PtpRegisterBusType;
      counterBus         : PtpRegisterBusType;
      state              : StateType;
      compute            : PtpComputeMasterType;
      nextState          : StateType;
      loadKind           : LoadType;
      wordIndex          : natural range 0 to 3;
      slot               : natural range 0 to 15;
      publication        : slv(127 downto 0);
      checked            : boolean;
      less               : sl;
      equal              : sl;
      frequencyValid     : sl;
      frequencyBank      : natural range 0 to 1;
      correctionNegative : sl;
      correctionNonzero  : sl;
      inLock             : sl;
      outUnlock          : sl;
      clampSlot          : natural range 0 to 15;
      clampReturn        : StateType;
      saturated          : sl;
      clampNegative      : sl;
      medianWord         : natural range 0 to 19;
      ramRead            : sl;
      ramReadAddr        : slv(3 downto 0);
      ramWrite           : sl;
      ramWriteAddr       : slv(3 downto 0);
      ramWriteData       : slv(31 downto 0);
      generation         : slv(31 downto 0);
      abortSeen          : sl;
      medianStep         : natural range MEDIAN_LEFT_C'range;
      filterPopulation   : positive range 1 to DELAY_FILTER_DEPTH_C;
      delayPtr           : natural range 0 to DELAY_FILTER_DEPTH_C-1;
      delayTicks         : slv(63 downto 0);
      sampleTicks        : slv(63 downto 0);
      lastTicks          : slv(63 downto 0);
      haveSample         : sl;
      tracking           : sl;
      holding            : sl;
      holdApplied        : sl;
      -- Signed Q16 ppb: frequency is the acknowledged integral state, slew is
      -- the temporary proportional correction, and workFrequency is a candidate
      -- retained as frequency only after the PHC acknowledges its rate command.
      integrating : sl;
      integrate   : sl;
      good        : unsigned(7 downto 0);
      bad         : unsigned(7 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      commandMaster      => PTP_PHC_COMMAND_MASTER_INIT_C,
      measurementSlave   => PTP_MEASUREMENT_SLAVE_INIT_C,
      expireTime         => '0',
      status             => PTP_SERVO_STATUS_INIT_C,
      readSlave          => AXI_LITE_READ_SLAVE_INIT_C,
      writeSlave         => AXI_LITE_WRITE_SLAVE_INIT_C,
      candidate          => initialCache,
      configBus          => PTP_REGISTER_BUS_INIT_C,
      configMaster       => PTP_REGISTER_MASTER_INIT_C,
      configWord         => (others => '0'),
      configSign         => '0',
      validateValue      => (others => '0'),
      validatePrevious   => (others => '0'),
      validateFrequency  => (others => '0'),
      validateSlew       => (others => '0'),
      configValid        => '1',
      activeConfig       => initialCache,
      sequenceId         => (others => '0'),
      publicationPort    => PTP_PUBLICATION_INIT_C,
      snapshotBus        => PTP_REGISTER_BUS_INIT_C,
      counterBus         => PTP_REGISTER_BUS_INIT_C,
      state              => IDLE_S,
      compute            => PTP_COMPUTE_MASTER_INIT_C,
      nextState          => IDLE_S,
      loadKind           => ZERO_L,
      wordIndex          => 0,
      slot               => 0,
      publication        => (others => '0'),
      checked            => false,
      less               => '0',
      equal              => '0',
      frequencyValid     => '0',
      frequencyBank      => 0,
      correctionNegative => '0',
      correctionNonzero  => '0',
      inLock             => '0',
      outUnlock          => '0',
      clampSlot          => 0,
      clampReturn        => IDLE_S,
      saturated          => '0',
      clampNegative      => '0',
      medianWord         => 0,
      ramRead            => '0',
      ramReadAddr        => (others => '0'),
      ramWrite           => '0',
      ramWriteAddr       => (others => '0'),
      ramWriteData       => (others => '0'),
      generation         => (others => '0'),
      abortSeen          => '0',
      medianStep         => 0,
      filterPopulation   => 1,
      delayPtr           => 0,
      delayTicks         => (others => '0'),
      sampleTicks        => (others => '0'),
      lastTicks          => (others => '0'),
      haveSample         => '0',
      tracking           => '0',
      holding            => '0',
      holdApplied        => '0',
      integrating        => '0',
      integrate          => '0',
      good               => (others => '0'),
      bad                => (others => '0'));

   signal r             : RegType := REG_INIT_C;
   signal rin           : RegType;
   signal historyData : slv(31 downto 0);
   -- Slots 0..4 are median scratch or offset/bootstrap/slew/interval/correction.
   -- 7 holds the candidate rate or normalized command. Slots 10/11 alternate
   -- retained and candidate frequency; ACK changes only their ownership pointer.
   -- 12 is a loaded configuration constant, 13 is zero, 14 scratch, 15 remainder.
   procedure issue (
      variable v : inout RegType;
      constant operation : slv(2 downto 0);
      constant a : natural;
      constant b : natural;
      constant target : natural;
      constant following : StateType;
      constant checked : boolean := false;
      constant shift : natural   := 0;
      constant rounding : sl     := '0') is
   begin
      v.compute.job := ptpComputeJob(operation, a, b, target, 15, shift, rounding);
      v.compute.jobValid := '1';
      v.nextState := following;
      v.checked := checked;
      v.state := ISSUE_S;
   end procedure issue;

   procedure loadWords (
      variable v : inout RegType;
      constant kind : LoadType;
      constant target : natural;
      constant following : StateType) is
   begin
      v.loadKind := kind;
      v.slot := target;
      v.wordIndex := 0;
      v.nextState := following;
      v.state := LOAD_S;
   end procedure loadWords;

   procedure readWords (
      variable v : inout RegType;
      constant source : natural;
      constant following : StateType) is
   begin
      v.slot := source;
      v.wordIndex := 0;
      v.nextState := following;
      v.state := READ_S;
   end procedure readWords;

   procedure clampWords (
      variable v : inout RegType;
      constant source : natural;
      constant maximum : LoadType;
      constant following : StateType) is
   begin
      v.clampSlot := source;
      v.clampReturn := following;
      v.saturated := '0';
      v.clampNegative := '0';
      loadWords(v, maximum, 12, CLAMP_POSITIVE_S);
   end procedure clampWords;

   signal configMasters : PtpRegisterMasterArray(0 to 1);
   signal configSlaves : PtpRegisterSlaveArray(0 to 1);
   signal scanValid : sl;
   signal scanIndex : slv(7 downto 0);
   signal scanData : slv(31 downto 0);
   signal snapshotSlave : PtpRegisterSlaveType;
   signal counterSlave : PtpRegisterSlaveType;

begin

   U_Publication : entity surf.PtpPublicationBank
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         RECORD_WORDS_G => IntegerArray'(4,4,2))
      port map (
         clk         => clk,
         rst         => rst,
         publication => r.publicationPort,
         snapshot    => snapshotControl,
         master      => r.snapshotBus.master,
         slave       => snapshotSlave);

   U_Snapshot : entity surf.PtpSnapshotBank
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         WORDS_G        => 1)
      port map (
         clk      => clk,
         rst      => rst,
         scalars  => Slv32Array'(0 => r.status.rejectedCount),
         snapshot => snapshotControl,
         prepared => snapshotPrepared,
         master   => r.counterBus.master,
         slave    => counterSlave);

   configMasters(0) <= r.configBus.master;
   configMasters(1) <= r.configMaster;

   U_Config : entity surf.PtpConfigBank
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         DEFAULTS_G     => initialWords)
      port map (
         clk       => clk,
         rst       => rst,
         prepare   => configControl.prepare,
         apply     => configControl.apply,
         prepared  => configPrepared,
         scanValid => scanValid,
         scanIndex => scanIndex,
         scanData  => scanData,
         masters   => configMasters,
         slaves    => configSlaves);

   U_DelayHistory : entity surf.SimpleDualPortRam
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         DATA_WIDTH_G   => 32,
         BYTE_WR_EN_G   => false,
         BYTE_WIDTH_G   => 32,
         ADDR_WIDTH_G   => 4,
         COMMON_CLK_G   => true,
         MEMORY_TYPE_G  => "distributed",
         DOB_REG_G      => false,
         READ_LATENCY_G => 1)
      port map (
         clka  => clk,
         ena   => r.ramWrite,
         wea   => r.ramWrite,
         addra => r.ramWriteAddr,
         dina  => r.ramWriteData,
         clkb  => clk,
         rstb  => rst,
         enb   => r.ramRead,
         addrb => r.ramReadAddr,
         doutb => historyData);

   comb : process (all) is
      variable readAddress      : slv(11 downto 0);
      variable writeAddress     : slv(11 downto 0);
      variable v                : RegType;
      variable ep               : AxiLiteEndpointType;
      variable sampleTickDelta  : signed(127 downto 0);
      variable stale            : boolean;
      variable acceptSample     : boolean;
      variable value            : slv(127 downto 0);
      variable frequencySlot    : natural range 10 to 11;
      variable candidateSlot    : natural range 10 to 11;
      variable leftIndex        : natural range 0 to 4;
      variable rightIndex       : natural range 0 to 4;
      variable configAddress    : integer range -1 to 33;
      variable configReadIndex  : integer range -1 to 33;
      variable configWriteIndex : integer range -1 to 33;
      variable configReadBank   : slv(1 downto 0);
      variable clampConstant    : boolean;
      variable configIndexValue : natural range 0 to 255;
      variable snapshotIndex    : integer range -1 to 9;
   begin
      v := r;
      v.measurementSlave := PTP_MEASUREMENT_SLAVE_INIT_C;
      v.compute.cancel := '0';
      v.publicationPort.write := '0';
      v.publicationPort.commit := '0';
      v.compute.retain := '1';
      v.compute.resultReady := '0';
      v.compute.readReady := '0';
      v.configMaster.responseReady := '1';
      v.configMaster.cancel := '0';

      if r.configMaster.valid = '1' and configSlaves(1).ready = '1' then
         v.configMaster.valid := '0';
      end if;

      v.ramRead := '0';
      v.ramWrite := '0';
      frequencySlot := 10+r.frequencyBank;
      candidateSlot := 11-r.frequencyBank;
      leftIndex     := MEDIAN_LEFT_C(r.medianStep);
      rightIndex    := MEDIAN_RIGHT_C(r.medianStep);
      value         := (others => '0');
      configAddress := -1;
      clampConstant := false;

      case r.loadKind is
         when ZERO_L =>
            null;
         when INPUT_FORWARD_L =>
            value := measurementMaster.data.forward;
         when INPUT_RATIO_L =>
            value(63 downto 0) := measurementMaster.data.ratio;
         when FILTER_L =>
            value := r.status.filteredDelay;
         when ASYMMETRY_L =>
            configAddress := 32;
         when STEP_L =>
            configAddress := 14;
         when LOCK_L =>
            configAddress := 16;
         when UNLOCK_L =>
            configAddress := 18;
         when NOMINAL_RATIO_L =>
            value := slv(shift_left(resize(NOMINAL_C, 128), PTP_PHC_TO_RATIO_SHIFT_C));
         when NOMINAL_L =>
            value := slv(resize(NOMINAL_C, 128));
         when BILLION_L =>
            value := slv(to_signed(PTP_PPB_SCALE_C, 128));
         when SECOND_L =>
            value := slv(SECOND_Q16_C);
         when KP_L =>
            configAddress := 8;
         when KI_L =>
            configAddress := 9;
         when SAMPLE_TICKS_L =>
            value(63 downto 0) := r.sampleTicks;
         when LAST_TICKS_L =>
            value(63 downto 0) := r.lastTicks;
         when MAX_FREQUENCY_L =>
            configAddress := 10;
         when MAX_SLEW_L =>
            configAddress := 11;
         when MAX_RATE_L =>
            configAddress := 12;
      end case;

      clampConstant := r.loadKind = MAX_FREQUENCY_L or r.loadKind = MAX_SLEW_L or r.loadKind = MAX_RATE_L;

      if configAddress >= 0 then
         value := (others => '0');
         if clampConstant then
            value(47 downto 16) := r.configWord;
         elsif configAddress >= 14 then
            value := (others => r.configSign);
         end if;
      end if;

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
      stale := r.haveSample = '1' and (measurementMaster.abort = '1' or unsigned(r.status.filterCount) = 0 or
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

            if r.frequencyValid = '0' then
               loadWords(v, ZERO_L, 13, INIT_COPY_S);
            elsif r.compute.cancel = '0' then
               v.measurementSlave.ready := '1';
               if stale and r.holdApplied = '0' then
                  v.measurementSlave.ready := '0';
                  v.holding := '1';
                  issue(v, PTP_COMPUTE_COPY_C, frequencySlot, 0, 7, RATE_LIMIT_S);
               elsif measurementMaster.valid = '1' and measurementMaster.abort = '0' and servoEnable = '1' then
                  v.measurementSlave.ready := '1';
                  if measurementMaster.data.generation /= phcStatus.generation or
                     unsigned(measurementMaster.data.ticks) > unsigned(phcStatus.ticks) or
                     unsigned(phcStatus.ticks)-unsigned(measurementMaster.data.ticks) > unsigned(sharedConfig.associationTimeout) then
                     v.status.rejectedCount := ptpSatInc(v.status.rejectedCount);
                  elsif measurementMaster.data.isDelay = '1' then
                     if signed(measurementMaster.data.delayValue) >= 0 and signed(measurementMaster.data.delayValue) <= signed(sharedConfig.maxPathDelay) and
                        (unsigned(r.status.filterCount) = 0 or unsigned(measurementMaster.data.ticks) > unsigned(r.delayTicks)) then
                        v.measurementSlave.ready := '0';
                        v.ramWrite := '1';
                        v.ramWriteAddr := toSlv(2*r.delayPtr, 4);
                        v.ramWriteData := measurementMaster.data.delayValue(31 downto 0);
                        v.filterPopulation := DELAY_FILTER_DEPTH_C;
                        if unsigned(r.status.filterCount) < DELAY_FILTER_DEPTH_C then
                           v.filterPopulation := to_integer(unsigned(r.status.filterCount))+1;
                        end if;
                        v.sampleTicks := measurementMaster.data.ticks;
                        v.holding := '0';
                        v.state := DELAY_HIGH_S;
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
                        v.measurementSlave.ready := '0';
                        v.sampleTicks := measurementMaster.data.ticks;
                        v.holding := '0';
                        v.commandMaster.data := PTP_PHC_COMMAND_INIT_C;
                        v.commandMaster.data.generation := phcStatus.generation;
                        loadWords(v, INPUT_FORWARD_L, 0, FORWARD_RATIO_S);
                     end if;
                  end if;
               end if;
            end if;

         when INIT_COPY_S =>
            issue(v, PTP_COMPUTE_COPY_C, 13, 0, frequencySlot, INIT_DONE_S);
         when INIT_DONE_S =>
            v.frequencyValid := '1';
            v.state := IDLE_S;
         when LOAD_S =>

            if r.compute.memValid = '0' and configAddress >= 0 and
               ((configAddress < 14 and r.wordIndex = 0) or (configAddress >= 14 and r.wordIndex < 2)) then
               v.state := CONFIG_READ_S;
            elsif r.compute.memValid = '0' then
               v.compute.memValid := '1';
               v.compute.memWrite := '1';
               v.compute.memWord := toSlv(4*r.slot+r.wordIndex, 6);
               v.compute.memData := value(32*r.wordIndex+31 downto 32*r.wordIndex);
            elsif computeSlave.memReady = '1' then
               v.compute.memValid := '0';
               if r.wordIndex = 3 then
                  v.state := r.nextState;
               else
                  v.wordIndex := r.wordIndex+1;
               end if;
            end if;

         when CONFIG_READ_S =>
            v.configMaster.valid := '1';
            v.configMaster.write := '0';
            v.configMaster.bank := "01";
            v.configMaster.index := toSlv(configAddress+r.wordIndex, 8);
            v.state := CONFIG_WAIT_S;
         when CONFIG_WAIT_S =>

            if configSlaves(1).responseValid = '1' then
               v.configWord := configSlaves(1).data;
               v.configSign := configSlaves(1).data(31);
               v.compute.memValid := '1';
               v.compute.memWrite := '1';
               v.compute.memWord := toSlv(4*r.slot+r.wordIndex, 6);
               v.compute.memData := configSlaves(1).data;
               if clampConstant then
                  v.compute.memData := configSlaves(1).data(15 downto 0) & x"0000";
               end if;
               v.state := LOAD_S;
            end if;

         when READ_S =>
            v.compute.memValid := '1';
            v.compute.memWrite := '0';
            v.compute.memWord := toSlv(4*r.slot+r.wordIndex, 6);

            if r.compute.memValid = '1' and computeSlave.memReady = '1' then
               v.compute.memValid := '0';
               v.compute.readReady := '1';
               v.state := READ_WAIT_S;
            end if;

         when READ_WAIT_S =>
            v.compute.readReady := '1';

            if computeSlave.readValid = '1' then
               if r.nextState = OFFSET_PUBLISH_S or r.nextState = MEDIAN_PUBLISH_S or
                  (r.nextState = RATE_PUBLISH_S and r.wordIndex < 2) then
                  v.publicationPort.write := '1';
                  v.publicationPort.first := toSl(r.wordIndex = 0);
                  v.publicationPort.recordIndex := x"0";
                  if r.nextState = MEDIAN_PUBLISH_S then
                     v.publicationPort.recordIndex := x"1";
                  elsif r.nextState = RATE_PUBLISH_S then
                     v.publicationPort.recordIndex := x"2";
                  end if;
                  v.publicationPort.wordIndex := toSlv(r.wordIndex,8);
                  v.publicationPort.data := computeSlave.readData;
               end if;
               v.publication(32*r.wordIndex+31 downto 32*r.wordIndex) := computeSlave.readData;
               if r.wordIndex = 3 then
                  v.state := r.nextState;
               else
                  v.wordIndex := r.wordIndex+1;
                  v.state := READ_S;
               end if;
            end if;

         when ISSUE_S =>

            if computeSlave.jobReady = '1' then
               v.compute.jobValid := '0';
               v.state := WAIT_S;
            end if;

         when WAIT_S =>

            if computeSlave.resultValid = '1' then
               v.compute.resultReady := '1';
               v.less := computeSlave.resultLess;
               v.equal := computeSlave.resultEqual;
               v.state := r.nextState;
               if r.checked and computeSlave.resultError = '1' then
                  v.status.rejectedCount := ptpSatInc(v.status.rejectedCount);
                  v.state := IDLE_S;
               end if;
            end if;

         when DELAY_HIGH_S =>
            v.ramWrite := '1';
            v.ramWriteAddr := toSlv(2*r.delayPtr+1, 4);
            v.ramWriteData := measurementMaster.data.delayValue(63 downto 32);
            v.state := DELAY_ACCEPT_S;
         when DELAY_ACCEPT_S =>
            v.measurementSlave.ready := '1';

            if measurementMaster.valid = '1' then
               v.delayTicks := r.sampleTicks;
               v.delayPtr := (r.delayPtr+1) mod DELAY_FILTER_DEPTH_C;
               v.medianWord := 0;
               v.medianStep := 0;
               v.state := MEDIAN_FETCH_S;
            end if;

         when MEDIAN_FETCH_S =>
            v.compute.memWord := toSlv(r.medianWord, 6);
            v.compute.memWrite := '1';

            if r.medianWord/4 < r.filterPopulation and r.medianWord mod 4 < 2 then
               v.ramRead := '1';
               v.ramReadAddr := toSlv(2*(r.medianWord/4)+r.medianWord mod 4, 4);
               v.state := MEDIAN_RAM_WAIT_S;
            else
               v.compute.memData := (others => '0');
               if r.medianWord/4 >= r.filterPopulation then
                  if r.medianWord mod 4 = 0 then
                     v.compute.memData := x"FFFFFFFF";
                  elsif r.medianWord mod 4 = 1 then
                     v.compute.memData := x"7FFFFFFF";
                  end if;
               end if;
               v.compute.memValid := '1';
               v.state := MEDIAN_STORE_S;
            end if;

         when MEDIAN_RAM_WAIT_S =>
            v.state := MEDIAN_RAM_CAPTURE_S;
         when MEDIAN_RAM_CAPTURE_S =>
            v.compute.memData := historyData;
            v.compute.memValid := '1';
            v.state := MEDIAN_STORE_S;
         when MEDIAN_STORE_S =>

            if computeSlave.memReady = '1' then
               v.compute.memValid := '0';
               if r.medianWord = 19 then
                  v.state := MEDIAN_COMPARE_S;
               else
                  v.medianWord := r.medianWord+1;
                  v.state := MEDIAN_FETCH_S;
               end if;
            end if;

         when MEDIAN_COMPARE_S =>
            issue(v, PTP_COMPUTE_CMP_C, leftIndex, rightIndex, 14, MEDIAN_DECIDE_S);
         when MEDIAN_DECIDE_S =>
            v.state := MEDIAN_NEXT_S;

            if r.less = '0' and r.equal = '0' then
               issue(v, PTP_COMPUTE_COPY_C, leftIndex, 0, 14, MEDIAN_SWAP_RIGHT_S);
            end if;

         when MEDIAN_SWAP_RIGHT_S =>
            issue(v, PTP_COMPUTE_COPY_C, rightIndex, 0, leftIndex, MEDIAN_SWAP_LEFT_S);
         when MEDIAN_SWAP_LEFT_S =>
            issue(v, PTP_COMPUTE_COPY_C, 14, 0, rightIndex, MEDIAN_NEXT_S);
         when MEDIAN_NEXT_S =>

            if r.medianStep = MEDIAN_LEFT_C'high then
               readWords(v, (r.filterPopulation-1)/2, MEDIAN_PUBLISH_S);
            else
               v.medianStep := r.medianStep+1;
               v.state := MEDIAN_COMPARE_S;
            end if;

         when MEDIAN_PUBLISH_S =>

            if v.commandMaster.cancel = '0' and phcStatus.fault = '0' then
               v.status.filteredDelay := r.publication;
               v.publicationPort.commit := '1';
               v.publicationPort.commitRecord := x"1";
               v.status.filterCount := toSlv(r.filterPopulation, v.status.filterCount'length);
            end if;

            v.state := IDLE_S;
         when FORWARD_RATIO_S =>
            loadWords(v, INPUT_RATIO_L, 1, FORWARD_ACCEPT_S);
         when FORWARD_ACCEPT_S =>
            v.measurementSlave.ready := '1';

            if measurementMaster.valid = '1' then
               loadWords(v, FILTER_L, 12, OFFSET_DELAY_S);
            end if;

         when OFFSET_DELAY_S =>
            issue(v, PTP_COMPUTE_SUB_C, 0, 12, 0, OFFSET_ASYMMETRY_S);
         when OFFSET_ASYMMETRY_S =>
            loadWords(v, ASYMMETRY_L, 12, OFFSET_SUBTRACT_S);
         when OFFSET_SUBTRACT_S =>
            issue(v, PTP_COMPUTE_SUB_C, 0, 12, 0, OFFSET_READ_S);
         when OFFSET_READ_S =>
            readWords(v, 0, OFFSET_PUBLISH_S);
         when OFFSET_PUBLISH_S =>
            v.status.offsetValue := r.publication;
            v.publicationPort.commit := '1';
            v.publicationPort.commitRecord := x"0";
            issue(v, PTP_COMPUTE_CMP_C, 0, 13, 14, OFFSET_ABSOLUTE_S);
         when OFFSET_ABSOLUTE_S =>

            if r.less = '1' then
               issue(v, PTP_COMPUTE_SUB_C, 13, 0, 7, OFFSET_THRESHOLD_S);
            else
               issue(v, PTP_COMPUTE_COPY_C, 0, 0, 7, OFFSET_THRESHOLD_S);
            end if;

         when OFFSET_THRESHOLD_S =>
            loadWords(v, STEP_L, 12, OFFSET_DECIDE_S);
         when OFFSET_DECIDE_S =>
            issue(v, PTP_COMPUTE_CMP_C, 12, 7, 14, LOCK_COMPARE_S);
         when LOCK_COMPARE_S =>

            if phcStatus.timeValid = '0' and r.activeConfig.allowStep = '1' and r.less = '1' then
               v.state := PHASE_NEGATE_S;
            elsif resize(resize(signed(r.publication), 64), 128) /= signed(r.publication) then
               v.status.rejectedCount := ptpSatInc(v.status.rejectedCount);
               v.state := IDLE_S;
            else
               loadWords(v, LOCK_L, 12, LOCK_CAPTURE_S);
            end if;

         when LOCK_CAPTURE_S =>
            issue(v, PTP_COMPUTE_CMP_C, 7, 12, 14, UNLOCK_COMPARE_S);
         when UNLOCK_COMPARE_S =>
            v.inLock := r.less or r.equal;
            loadWords(v, UNLOCK_L, 12, UNLOCK_CAPTURE_S);
         when UNLOCK_CAPTURE_S =>
            issue(v, PTP_COMPUTE_CMP_C, 12, 7, 14, BOOT_DIFFERENCE_S);
         when BOOT_DIFFERENCE_S =>
            v.outUnlock := r.less or r.equal;
            loadWords(v, NOMINAL_RATIO_L, 12, BOOT_SCALE_S);
         when BOOT_SCALE_S =>
            issue(v, PTP_COMPUTE_SUB_C, 1, 12, 1, BOOT_MULTIPLY_S, false, 0, '0');
         when BOOT_MULTIPLY_S =>
            loadWords(v, BILLION_L, 12, BOOT_DENOMINATOR_S);
         when BOOT_DENOMINATOR_S =>
            issue(v, PTP_COMPUTE_MUL_C, 1, 12, 1, BOOT_DIVIDE_S, true, 0, '0');
         when BOOT_DIVIDE_S =>
            loadWords(v, NOMINAL_L, 12, BOOT_CLAMP_S);
         when BOOT_CLAMP_S =>
            issue(v, PTP_COMPUTE_DIV_C, 1, 12, 1, PROPORTIONAL_LOAD_S, true, 0, '1');
         when PROPORTIONAL_LOAD_S =>
            clampWords(v, 1, MAX_FREQUENCY_L, PROPORTIONAL_MULTIPLY_S);
         when PROPORTIONAL_MULTIPLY_S =>
            loadWords(v, KP_L, 12, PROPORTIONAL_ROUND_S);
         when PROPORTIONAL_ROUND_S =>
            issue(v, PTP_COMPUTE_MUL_C, 0, 12, 2, PROPORTIONAL_NEGATE_S, true, 0, '0');
         when PROPORTIONAL_NEGATE_S =>
            issue(v, PTP_COMPUTE_SHR_C, 2, 0, 2, PROPORTIONAL_CLAMP_S, false, PROPORTIONAL_SHIFT_C, '1');
         when PROPORTIONAL_CLAMP_S =>
            issue(v, PTP_COMPUTE_SUB_C, 13, 2, 2, PROPORTIONAL_DONE_S, false, 0, '0');
         when PROPORTIONAL_DONE_S =>
            v.integrating := r.tracking;
            clampWords(v, 2, MAX_SLEW_L, INTERVAL_LOAD_S);
         when INTERVAL_LOAD_S =>

            if r.integrating = '1' then
               loadWords(v, SAMPLE_TICKS_L, 3, INTERVAL_SUBTRACT_S);
            else
               v.state := BOOT_FREQUENCY_S;
            end if;

         when INTERVAL_SUBTRACT_S =>
            loadWords(v, LAST_TICKS_L, 12, INTERVAL_NOMINAL_S);
         when INTERVAL_NOMINAL_S =>
            issue(v, PTP_COMPUTE_SUB_C, 3, 12, 3, INTERVAL_MULTIPLY_S, false, 0, '0');
         when INTERVAL_MULTIPLY_S =>
            loadWords(v, NOMINAL_L, 12, INTERVAL_SCALE_S);
         when INTERVAL_SCALE_S =>
            issue(v, PTP_COMPUTE_MUL_C, 3, 12, 3, INTERVAL_DIVIDE_S, true, 0, '0');
         when INTERVAL_DIVIDE_S =>
            loadWords(v, BILLION_L, 12, INTEGRAL_GAIN_LOAD_S);
         when INTEGRAL_GAIN_LOAD_S =>
            issue(v, PTP_COMPUTE_DIV_C, 3, 12, 3, INTEGRAL_GAIN_MULTIPLY_S, true, 0, '1');
         when INTEGRAL_GAIN_MULTIPLY_S =>
            loadWords(v, KI_L, 12, INTEGRAL_TIME_MULTIPLY_S);
         when INTEGRAL_TIME_MULTIPLY_S =>
            issue(v, PTP_COMPUTE_MUL_C, 0, 12, 4, INTEGRAL_ROUND_S, true, 0, '0');
         when INTEGRAL_ROUND_S =>
            issue(v, PTP_COMPUTE_MUL_C, 4, 3, 4, INTEGRAL_NEGATE_S, true, 0, '0');
         when INTEGRAL_NEGATE_S =>
            issue(v, PTP_COMPUTE_SHR_C, 4, 0, 4, INTEGRAL_SIGN_S, false, INTEGRAL_SHIFT_C, '1');
         when INTEGRAL_SIGN_S =>
            issue(v, PTP_COMPUTE_SUB_C, 13, 4, 4, INTEGRAL_ADD_S, false, 0, '0');
         when INTEGRAL_ADD_S =>
            issue(v, PTP_COMPUTE_CMP_C, 4, 13, 14, FREQUENCY_CLAMP_S, false, 0, '0');
         when BOOT_FREQUENCY_S =>
            issue(v, PTP_COMPUTE_SUB_C, 1, 2, candidateSlot, FREQUENCY_DONE_S, false, 0, '0');
         when FREQUENCY_CLAMP_S =>
            v.correctionNegative := r.less;
            v.correctionNonzero := not r.equal;
            issue(v, PTP_COMPUTE_ADD_C, frequencySlot, 4, candidateSlot, FREQUENCY_DONE_S);
         when FREQUENCY_DONE_S =>
            clampWords(v, candidateSlot, MAX_FREQUENCY_L, RATE_TRIAL_S);
         when RATE_TRIAL_S =>
            v.integrate := '1';

            if r.integrating = '1' and r.saturated = '1' and
               r.correctionNonzero = '1' and r.clampNegative = r.correctionNegative then
               v.integrate := '0';
            end if;

            issue(v, PTP_COMPUTE_ADD_C, candidateSlot, 2, 7, RATE_TRIAL_CLAMP_S);
         when RATE_TRIAL_CLAMP_S =>
            clampWords(v, 7, MAX_RATE_L, RATE_TRIAL_CHECK_S);
         when RATE_TRIAL_CHECK_S =>

            if r.integrating = '1' and (r.integrate = '0' or
               (r.saturated = '1' and r.correctionNonzero = '1' and r.clampNegative = r.correctionNegative)) then
               issue(v, PTP_COMPUTE_COPY_C, frequencySlot, 0, candidateSlot, RATE_SUM_S);
            else
               v.state := RATE_SUM_S;
            end if;

         when RATE_SUM_S =>
            issue(v, PTP_COMPUTE_ADD_C, candidateSlot, 2, 7, RATE_LIMIT_S, false, 0, '0');
         when RATE_LIMIT_S =>
            clampWords(v, 7, MAX_RATE_L, RATE_READ_S);
         when RATE_READ_S =>
            readWords(v, 7, RATE_PUBLISH_S);
         when RATE_PUBLISH_S =>
            v.status.ratePpb := r.publication(63 downto 0);
            v.publicationPort.commit := '1';
            v.publicationPort.commitRecord := x"2";
            loadWords(v, NOMINAL_L, 12, RATE_NOMINAL_S);
         when RATE_NOMINAL_S =>
            issue(v, PTP_COMPUTE_MUL_C, 7, 12, 7, RATE_MULTIPLY_S, true, 0, '0');
         when RATE_MULTIPLY_S =>
            loadWords(v, SECOND_L, 12, RATE_SCALE_S);
         when RATE_SCALE_S =>
            issue(v, PTP_COMPUTE_DIV_C, 7, 12, 7, RATE_DIVIDE_S, true, 0, '1');
         when RATE_DIVIDE_S =>
            readWords(v, 7, RATE_COMMAND_S);
         when RATE_COMMAND_S =>

            if resize(resize(signed(r.publication), 64), 128) /= signed(r.publication) then
               v.status.state := PTP_SERVO_FAULT_C;
               v.state := IDLE_S;
            else
               v.commandMaster.data := PTP_PHC_COMMAND_INIT_C;
               v.commandMaster.data.kind := PTP_CMD_RATE_C;
               v.commandMaster.data.generation := phcStatus.generation;
               v.commandMaster.data.rate := r.publication(63 downto 0);
               v.state := COMMAND_S;
            end if;

         when PHASE_NEGATE_S =>
            issue(v, PTP_COMPUTE_SUB_C, 13, 0, 0, PHASE_SCALE_S, false, 0, '0');
         when PHASE_SCALE_S =>
            loadWords(v, SECOND_L, 12, PHASE_DIVIDE_S);
         when PHASE_DIVIDE_S =>
            issue(v, PTP_COMPUTE_DIV_C, 0, 12, 7, PHASE_QUOTIENT_S, true, 0, '0');
         when PHASE_QUOTIENT_S =>
            readWords(v, 7, PHASE_SECONDS_S);
         when PHASE_SECONDS_S =>

            if resize(resize(signed(r.publication), 64), 128) /= signed(r.publication) then
               v.status.state := PTP_SERVO_FAULT_C;
               v.state := IDLE_S;
            else
               v.commandMaster.data.kind := PTP_CMD_PHASE_C;
               v.commandMaster.data.phaseSeconds := r.publication(63 downto 0);
               v.state := PHASE_REMAINDER_S;
            end if;

         when PHASE_REMAINDER_S =>
            readWords(v, 15, PHASE_COMMAND_S);
         when PHASE_COMMAND_S =>
            v.commandMaster.data.phaseFraction := r.publication(47 downto 0) & x"0000";
            v.state := COMMAND_S;
         when CLAMP_POSITIVE_S =>
            issue(v, PTP_COMPUTE_CMP_C, 12, r.clampSlot, 14, CLAMP_POSITIVE_CHECK_S);
         when CLAMP_POSITIVE_CHECK_S =>

            if r.less = '1' then
               v.saturated := '1';
               issue(v, PTP_COMPUTE_COPY_C, 12, 0, r.clampSlot, r.clampReturn);
            else
               v.state := CLAMP_NEGATE_S;
            end if;

         when CLAMP_NEGATE_S =>
            issue(v, PTP_COMPUTE_SUB_C, 13, 12, 12, CLAMP_NEGATIVE_S);
         when CLAMP_NEGATIVE_S =>
            issue(v, PTP_COMPUTE_CMP_C, r.clampSlot, 12, 14, CLAMP_NEGATIVE_CHECK_S);
         when CLAMP_NEGATIVE_CHECK_S =>
            v.state := r.clampReturn;

            if r.less = '1' then
               v.saturated := '1';
               v.clampNegative := '1';
               issue(v, PTP_COMPUTE_COPY_C, 12, 0, r.clampSlot, r.clampReturn);
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
                     acceptSample := true;
                     v.frequencyBank := 1-r.frequencyBank;
                     v.tracking := '1';
                     v.holdApplied := '0';
                     if phcStatus.timeValid = '0' then
                        v.commandMaster.data.kind := PTP_CMD_VALID_C;
                        v.commandMaster.data.value := '1';
                        v.state := COMMAND_S;
                     end if;
                  end if;
               end if;
            end if;

      end case;

      -- Lock hysteresis uses only a sample whose rate command was acknowledged.
      -- This qualifies the internal offset estimate. It is not an independent
      -- accuracy measurement, nor the LOCKED indication of a physical PLL.
      if acceptSample then
         v.lastTicks    := r.sampleTicks;
         v.haveSample   := '1';
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
         if v.good >= unsigned(r.activeConfig.lockCount) or (r.status.state = PTP_SERVO_LOCKED_C and v.bad < unsigned(r.activeConfig.unlockCount)) then
            v.status.state := PTP_SERVO_LOCKED_C;
         end if;
      end if;

      -- Cancellation overrides work above; disabling/fault policy then selects
      -- the externally visible quality without discarding retained frequency.
      if v.commandMaster.cancel = '1' then
         v.state              := IDLE_S;
         v.compute := PTP_COMPUTE_MASTER_INIT_C;
         v.compute.cancel := '1';
         v.compute.retain := '1';
         v.configMaster.valid := '0';
         v.configMaster.cancel := '1';
         v.ramRead := '0';
         v.ramWrite := '0';
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

      -------------------------------------------------------------------------
      -- AXI-Lite: decode, map, then close the transaction.
      -------------------------------------------------------------------------
      axiSlaveWaitTxn(ep, axiWriteMaster, axiReadMaster, v.writeSlave, v.readSlave);
      -- An inactive AXI address is unspecified. Decode only admitted requests;
      -- RAM responses retain their address/ownership inside ptpRegisterBus.
      readAddress := (others => '0');
      writeAddress := (others => '0');
      if ep.axiStatus.readEnable = '1' then
         readAddress := ep.axiReadMaster.araddr(11 downto 0);
      end if;
      if ep.axiStatus.writeEnable = '1' then
         writeAddress := ep.axiWriteMaster.awaddr(11 downto 0);
      end if;

      -- Suppress register accesses during AXI-only reset.
      if regRst = '1' then
         ep.axiStatus := AXI_LITE_STATUS_INIT_C;
      end if;

      -- Phase policy, PI gains and actuator-limit shadows.
      -- Lock thresholds, qualification counts and sample timing.
      -- Live quality and active local/shared configuration.
      axiSlaveRegisterR(ep, x"090", 0, r.status.state);
      axiSlaveRegisterR(ep, x"090", 4, r.status.filterCount);
      axiSlaveRegisterR(ep, x"0A0", 0, sharedConfig.associationTimeout);
      axiSlaveRegisterR(ep, x"0A8", 0, sharedConfig.syncTimeout);
      axiSlaveRegisterR(ep, x"0B0", 0, sharedConfig.maxPathDelay);
      -- Coherent measurement and diagnostic snapshots.
      axiSlaveRegisterR(ep, x"3FC", 0, r.sequenceId);
      configReadIndex  := configIndex(readAddress);
      configWriteIndex := configIndex(writeAddress);
      configReadBank   := "00";

      if readAddress(11 downto 2) = slv(to_unsigned(16#094#/4,10)) then
         configReadIndex := 8;
         configReadBank  := "01";
      elsif readAddress(11 downto 2) = slv(to_unsigned(16#098#/4,10)) then
         configReadIndex := 9;
         configReadBank  := "01";
      end if;

      ptpRegisterBus(v.configBus, r.configBus, configSlaves(0), ep, configReadIndex, configWriteIndex,
         configMask(configWriteIndex,ep.axiWriteMaster.wstrb), configReadBank, regRst);
      snapshotIndex := -1;

      if unsigned(readAddress(11 downto 2)) >= 64 and unsigned(readAddress(11 downto 2)) <= 73 then
         snapshotIndex := to_integer(unsigned(readAddress(11 downto 2)))-64;
      end if;

      ptpRegisterBus(v.snapshotBus, r.snapshotBus, snapshotSlave, ep, snapshotIndex, -1, x"00000000", "00", regRst);
      snapshotIndex := -1;

      if readAddress(11 downto 2) = slv(to_unsigned(128,10)) then
         snapshotIndex := 0;
      end if;

      ptpRegisterBus(v.counterBus, r.counterBus, counterSlave, ep, snapshotIndex, -1, x"00000000", "00", regRst);
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
      -- The word bank freezes the candidate and streams its validation scan.
      -- Previously admitted writes drain before copying; later writes wait for
      -- the next shadow. The coordinator samples the vote after preparation.
      if configControl.prepare = '1' then
         v.configValid := '1';
      end if;

      if scanValid = '1' then
         configIndexValue := to_integer(unsigned(scanIndex));
         if configIndexValue mod 2 = 0 then
            v.validateValue(31 downto 0) := scanData;
         else
            v.validateValue(63 downto 32) := scanData;
         end if;

         case configIndexValue is
            when 1 =>
               v.candidate.allowStep := scanData(2);
            when 10 =>
               v.validateFrequency := scanData;
            when 11 =>
               v.validateSlew := scanData;
            when 12 =>
               if unsigned(scanData) > MAX_ACTUATOR_PPB_C or unsigned(r.validateFrequency) > unsigned(scanData) or
                  unsigned(r.validateSlew) > unsigned(scanData) then
                  v.configValid := '0';
               end if;
            when 15 | 17 =>
               if scanData(31) = '1' then
                  v.configValid := '0';
               end if;
               v.validatePrevious := v.validateValue;
            when 19 =>
               if signed(v.validateValue) < signed(r.validatePrevious) then
                  v.configValid := '0';
               end if;
            when 20 =>
               v.candidate.lockCount := scanData(7 downto 0);
               if unsigned(scanData(7 downto 0)) = 0 then
                  v.configValid := '0';
               end if;
            when 21 =>
               v.candidate.unlockCount := scanData(7 downto 0);
               if unsigned(scanData(7 downto 0)) = 0 then
                  v.configValid := '0';
               end if;
            when 25 =>
               v.candidate.maxDelayAge := v.validateValue;
               if not ptpValidTimeout(v.validateValue) then
                  v.configValid := '0';
               end if;
            when 27 =>
               v.candidate.holdoverTimeout := v.validateValue;
               if not ptpValidTimeout(v.validateValue) then
                  v.configValid := '0';
               end if;
            when 29 =>
               v.candidate.minSampleTicks := v.validateValue;
               v.validatePrevious := v.validateValue;
               if not ptpValidTimeout(v.validateValue) then
                  v.configValid := '0';
               end if;
            when 31 =>
               v.candidate.maxSampleTicks := v.validateValue;
               if not ptpValidTimeout(v.validateValue) or unsigned(v.validateValue) < unsigned(r.validatePrevious) then
                  v.configValid := '0';
               end if;
            when others =>
               null;
         end case;

      end if;

      if configControl.apply = '1' then
         v.activeConfig := r.candidate;
      end if;

      if snapshotControl.publish = '1' then
         v.sequenceId := snapshotControl.sequenceId;
      end if;

      -- Apply synchronous reset before publishing next state and outputs.
      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;

      rin <= v;
      computeMaster <= r.compute;
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
