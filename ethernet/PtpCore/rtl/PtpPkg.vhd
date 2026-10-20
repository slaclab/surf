-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Shared types and arithmetic contracts for the PTP endpoint.
--
-- Defines time/capture payloads, decoded messages, measurement and PHC-command
-- channels, local configuration records, bank coordination and diagnostics.
-- Directional channel records keep payload, admission and completion semantics
-- together; configuration and snapshot controls describe separate transactions
-- in the common endpoint clock domain. Init constants provide inactive channel
-- values and deterministic default state for every exported record.
--
-- Package helpers encode/decode protocol fields, perform fixed-point rounding
-- and bounds checks, and translate physical capture positions into calibrated
-- timestamps. Units and generation/lifecycle rules are documented beside each
-- interface so producers, consumers and test wrappers use one shared contract.
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
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

package PtpPkg is

   -- Seconds-to-nanoseconds conversion and exclusive upper bound on the
   -- nanoseconds field of a normalized PTP timestamp.
   constant PTP_NANOSECONDS_PER_SECOND_C : positive := 1000000000;
   -- Retained finite-burst floor from the retired shared word processor.
   -- Four RX records, four completed ledger entries and one in-flight chain;
   -- see ethernet/PtpCore/interfaces.md#shared-service-bound. Re-derive the
   -- complete endpoint bound before reducing this floor for the new services.
   constant PTP_MIN_ASSOCIATION_TICKS_C : positive := (4*608+4*192+608)*18464+9*4096;
   -- Dimensionless parts-per-billion scale, independent of time units.
   constant PTP_PPB_SCALE_C : positive := 1000000000;
   -- Shared fixed-point formats. Derive conversions from these bit counts;
   -- Q16 ppb and Q16 nanoseconds have different units despite equal precision.
   -- These describe fixed interface contracts, not tunable precision generics.
   constant PTP_TIME_FRAC_BITS_C  : positive := 16;
   constant PTP_PHC_FRAC_BITS_C   : positive := 32;
   constant PTP_RATIO_FRAC_BITS_C : positive := 48;
   constant PTP_TICK_PHASE_BITS_C : positive := 3;
   constant PTP_GAIN_FRAC_BITS_C  : positive := 30;
   constant PTP_PPB_FRAC_BITS_C   : positive := 16;
   -- Left-shift counts for Q16 time -> Q32 PHC and Q32 PHC -> Q48 ratio.
   -- The reverse conversion drops the same number of low fractional bits.
   constant PTP_TIME_TO_PHC_SHIFT_C  : natural := PTP_PHC_FRAC_BITS_C-PTP_TIME_FRAC_BITS_C;
   constant PTP_PHC_TO_RATIO_SHIFT_C : natural := PTP_RATIO_FRAC_BITS_C-PTP_PHC_FRAC_BITS_C;

   -- Constant divisors for the fixed-function converters, as 64-bit values
   -- because a decimal second in Q16 nanoseconds exceeds a VHDL integer.
   -- Each name states the units of the conversion it performs, so a converter
   -- instance cannot silently inherit the wrong one.

   -- One decimal second in Q16 nanoseconds. Converts a Q16-nanosecond scalar
   -- to whole seconds plus a Q16 subsecond remainder, and Q16 ppb rate
   -- commands to a Q32 PHC increment addend.
   constant PTP_SECOND_Q16_DIVISOR_C : slv(63 downto 0) :=
      slv(shift_left(to_unsigned(PTP_NANOSECONDS_PER_SECOND_C, 64), PTP_TIME_FRAC_BITS_C));

   -- Nanoseconds per second, for converting a nanosecond-scaled product to
   -- seconds. This is a time-unit conversion; PTP_PPB_SCALE_C is the
   -- dimensionless ppb scale and the two are not interchangeable.
   constant PTP_NANOSECOND_DIVISOR_C : slv(63 downto 0) :=
      slv(to_unsigned(PTP_NANOSECONDS_PER_SECOND_C, 64));
   -- Untagged Ethernet geometry, including FCS in frame-size limits.
   constant PTP_ETH_MAC_BYTES_C      : positive := 6;
   constant PTP_ETH_HEADER_BYTES_C   : positive := 14; -- Two MAC addresses and EtherType.
   constant PTP_ETH_FCS_BYTES_C      : positive := 4;
   constant PTP_ETH_OVERHEAD_BYTES_C : positive := PTP_ETH_HEADER_BYTES_C+PTP_ETH_FCS_BYTES_C;
   constant PTP_ETH_MIN_FRAME_C      : positive := 64;
   constant PTP_ETH_MAX_FRAME_C      : positive := 1518;
   -- Network significance versus low-byte-first AXI/MAC lane order.
   constant PTP_ETH_TYPE_C      : slv(15 downto 0) := x"88F7";
   constant PTP_ETH_TYPE_AXIS_C : slv(15 downto 0) := PTP_ETH_TYPE_C(7 downto 0) & PTP_ETH_TYPE_C(15 downto 8);
   -- PTP common header and fixed message sizes, before optional TLVs.
   constant PTP_HEADER_BYTES_C        : positive := 34;
   constant PTP_TIMESTAMP_BYTES_C     : positive := 10;
   constant PTP_PORT_ID_BYTES_C       : positive := 10;
   constant PTP_TIMESTAMP_MSG_BYTES_C : positive := PTP_HEADER_BYTES_C+PTP_TIMESTAMP_BYTES_C;
   constant PTP_DELAY_RESP_BYTES_C    : positive := PTP_TIMESTAMP_MSG_BYTES_C+PTP_PORT_ID_BYTES_C;
   constant PTP_ANNOUNCE_BODY_BYTES_C : positive := 30;
   constant PTP_ANNOUNCE_BYTES_C      : positive := PTP_HEADER_BYTES_C+PTP_ANNOUNCE_BODY_BYTES_C;
   constant PTP_TLV_HEADER_BYTES_C    : positive := 4;
   constant PTP_TLV_LENGTH_OFFSET_C   : natural  := 2;
   -- Frontend storage capacity must hold Announce plus Ethernet/FCS, even
   -- though individual accepted Ethernet frames may be shorter than Announce.
   subtype PtpFrameCapacityType is positive range
      PTP_ETH_OVERHEAD_BYTES_C+PTP_ANNOUNCE_BYTES_C to PTP_ETH_MAX_FRAME_C;
   -- Supported fixed-source Layer-2 profile. Sync accepts only the complete
   -- one-step or two-step flag words below; these constants are not bit masks.
   -- The general-message upper flag octet is reserved by this implementation.
   constant PTP_MAJOR_VERSION_C      : slv(3 downto 0)  := x"2";
   constant PTP_MINOR_VERSION_MIN_C  : slv(3 downto 0)  := x"0";
   constant PTP_MINOR_VERSION_MAX_C  : slv(3 downto 0)  := x"1";
   constant PTP_TRANSPORT_SPECIFIC_C : slv(3 downto 0)  := x"0";
   constant PTP_ONE_STEP_FLAGS_C     : slv(15 downto 0) := x"0000";
   constant PTP_TWO_STEP_FLAGS_C     : slv(15 downto 0) := x"0200";
   constant PTP_LEAP_FLAGS_MASK_C    : slv(15 downto 0) := x"0003";
   constant PTP_GENERAL_RESERVED_C   : slv(15 downto 0) := x"FF00";
   constant PTP_TIMESCALE_BIT_C      : natural          := 3;
   -- Endpoint event positions in the central IRQ status/mask registers.
   constant PTP_IRQ_PHC_FAULT_C     : natural := 0;
   constant PTP_IRQ_DISCONTINUITY_C : natural := 1;
   constant PTP_IRQ_COMMAND_ERROR_C : natural := 2;
   constant PTP_IRQ_SERVO_FAULT_C   : natural := 3;
   -- PTP primary Layer-2 multicast MAC: 01:1B:19:00:00:00. Used for receive
   -- filtering and Delay_Req transmission by this E2E endpoint. Network byte
   -- order: the first wire octet (01) occupies bits 47 downto 40.
   constant PTP_PRIMARY_MULTICAST_MAC_C : slv(47 downto 0) := x"011B19000000";
   -- Inserted between the two three-octet MAC halves to form clockIdentity.
   constant PTP_CLOCK_ID_INSERT_C : slv(15 downto 0) := x"FFFE";
   -- PTPv2 wire messageType nibble and legacy controlField encodings.
   -- Announce uses the OTHER control value.
   constant PTP_MSG_SYNC_C                 : slv(3 downto 0) := x"0";
   constant PTP_MSG_DELAY_REQ_C            : slv(3 downto 0) := x"1";
   constant PTP_MSG_FOLLOW_UP_C            : slv(3 downto 0) := x"8";
   constant PTP_MSG_DELAY_RESP_C           : slv(3 downto 0) := x"9";
   constant PTP_MSG_ANNOUNCE_C             : slv(3 downto 0) := x"B";
   constant PTP_CONTROL_SYNC_C             : slv(7 downto 0) := x"00";
   constant PTP_CONTROL_DELAY_REQ_C        : slv(7 downto 0) := x"01";
   constant PTP_CONTROL_FOLLOW_UP_C        : slv(7 downto 0) := x"02";
   constant PTP_CONTROL_DELAY_RESP_C       : slv(7 downto 0) := x"03";
   constant PTP_CONTROL_OTHER_C            : slv(7 downto 0) := x"05";
   constant PTP_LOG_INTERVAL_UNSPECIFIED_C : slv(7 downto 0) := x"7F";
   -- IEEE 1588-2019 13.3.2.9: this encoding is not a finite Q16 correction.
   constant PTP_CORRECTION_OVERFLOW_C : slv(63 downto 0) := x"7FFFFFFFFFFFFFFF";
   -- Shared wire records and timebase interfaces. All arithmetic units are explicit.
   -- Normalized RX retains destination-MAC-through-FCS bytes in low-byte-first
   -- AXI lanes. SOF and the capture sidecar must share one pipeline; there is
   -- no independent timestamp queue or ready signal at this physical boundary.
   constant PTP_RX_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(2**PTP_TICK_PHASE_BITS_C);
   -- Canonical PHC input: nanoseconds < 1e9 and fraction in units of 2^-32 ns.
   -- The adapter receives the value corresponding to lane zero of the sampled
   -- physical word, before its own registered output delay.
   type PtpTimeType is record
      seconds     : slv(47 downto 0);
      nanoseconds : slv(31 downto 0);
      fraction    : slv(31 downto 0);
   end record;

   constant PTP_TIME_INIT_C : PtpTimeType := (
      seconds     => (others => '0'),
      nanoseconds => (others => '0'),
      fraction    => (others => '0'));

   -- Commands are accepted with valid/ready, then commit on the following
   -- edge. Phase transport is normalized by the command producer: signed whole
   -- seconds plus a signed Q32 remainder strictly smaller than one second.
   -- This permits a full-epoch adjustment without a divider in the PHC tick path.
   constant PTP_CMD_SET_C   : slv(2 downto 0) := "000";
   constant PTP_CMD_PHASE_C : slv(2 downto 0) := "001";
   constant PTP_CMD_RATE_C  : slv(2 downto 0) := "010";
   constant PTP_CMD_VALID_C : slv(2 downto 0) := "011";
   constant PTP_CMD_PPS_C   : slv(2 downto 0) := "100";
   type PtpPhcCommandType is record
      kind          : slv(2 downto 0);
      generation    : slv(31 downto 0);
      setTime       : PtpTimeType;
      phaseSeconds  : slv(63 downto 0);
      phaseFraction : slv(63 downto 0);
      rate          : slv(63 downto 0);
      value         : sl;
   end record;

   constant PTP_PHC_COMMAND_INIT_C : PtpPhcCommandType := (
      kind          => PTP_CMD_VALID_C,
      generation    => (others => '0'),
      setTime       => PTP_TIME_INIT_C,
      phaseSeconds  => (others => '0'),
      phaseFraction => (others => '0'),
      rate          => (others => '0'),
      value         => '0');

   -- Servo-to-PHC command channel, entirely in clk. All master fields are
   -- registered. Hold data and valid until ready accepts or cancellation
   -- withdraws the request. cancel and stale both gate admission and revoke
   -- accepted automatic work before commit; neither is qualified by valid.
   -- The PHC commits on the edge after acceptance, allowing cancellation
   -- registered on the acceptance edge to veto the pending command. Events
   -- first sampled by the servo on the commit edge cannot revoke that commit.
   -- The PHC retains ownership until ack, so ready and ack describe different
   -- phases. error is meaningful with ack and belongs to that command owner.
   type PtpPhcCommandMasterType is record
      data   : PtpPhcCommandType;
      valid  : sl;
      cancel : sl;
      stale  : sl;
   end record;

   constant PTP_PHC_COMMAND_MASTER_INIT_C : PtpPhcCommandMasterType := (
      data   => PTP_PHC_COMMAND_INIT_C,
      valid  => '0',
      cancel => '0',
      stale  => '0');

   -- All response fields are registered. Ready reserves the available slot;
   -- cancel/stale/reset exclude transfer without changing ready mid-cycle.
   type PtpPhcCommandSlaveType is record
      ready : sl;
      ack   : sl;
      error : sl;
   end record;

   constant PTP_PHC_COMMAND_SLAVE_INIT_C : PtpPhcCommandSlaveType := (
      ready => '0',
      ack   => '0',
      error => '0');

   -- Generation exhaustion and epoch overflow fail closed until system reset.
   -- Such a reset must also reset all consumers and cancel snapshot sessions.
   type PtpPhcStatusType is record
      generation    : slv(31 downto 0);
      ticks         : slv(63 downto 0);
      increment     : slv(63 downto 0);
      rate          : slv(63 downto 0);
      timeValid     : sl;
      ack           : sl;
      error         : sl;
      discontinuity : sl;
      fault         : sl;
   end record;

   constant PTP_PHC_STATUS_INIT_C : PtpPhcStatusType := (
      generation    => (others => '0'),
      ticks         => (others => '0'),
      increment     => (others => '0'),
      rate          => (others => '0'),
      timeValid     => '0',
      ack           => '0',
      error         => '0',
      discontinuity => '0',
      fault         => '0');

   function ptpNominalIncrement (frequency : positive) return slv;

   -- PtpPhcCore register ABI identity (ethernet/PtpCore/phc.md): major in
   -- bits 31:16, minor in 15:0. Unreleased development layout.
   constant PTP_PHC_CORE_VERSION_C : slv(31 downto 0) := x"00010000";
   -- timestamp is calibrated PHC time; ticks/tickPhase remain at the raw
   -- MAC/PCS message point. Their reference-plane difference matters when
   -- reconstructing elapsed time for E2E arithmetic. generation invalidates
   -- work across PHC/configuration changes; it is not a network packet ID.
   -- timeValid reports clock quality and may be false during acquisition.
   -- error instead means this capture cannot represent a usable timestamp.
   type PtpRxCaptureType is record
      timestamp  : slv(95 downto 0);  -- seconds, nanoseconds, Q16 fraction
      ticks      : slv(63 downto 0);
      tickPhase  : slv(PTP_TICK_PHASE_BITS_C-1 downto 0);   -- eighths of an unsteered cycle
      generation : slv(31 downto 0);
      increment  : slv(63 downto 0);  -- active PHC Q32 addend at capture
      timeValid  : sl;
      error      : sl;                -- arithmetic range failure; never admitted
   end record;

   constant PTP_RX_CAPTURE_INIT_C : PtpRxCaptureType := (
      timestamp  => (others => '0'),
      ticks      => (others => '0'),
      tickPhase  => (others => '0'),
      generation => (others => '0'),
      increment  => (others => '0'),
      timeValid  => '0',
      error      => '0');

   -- One queue item owns both the validated frame fields and its SOF capture.
   -- Multibyte fields use network significance (first octet at the high end),
   -- unlike the AXI byte lanes. The fixed message body excludes TLVs, padding,
   -- and FCS; unused low body bytes are zero. Source/profile policy and body
   -- interpretation remain the port's responsibility after structural checks.
   -- rxEpoch identifies local queue invalidation independently of the PHC
   -- generation, so RX overflow does not imply a PHC discontinuity.
   type PtpRxMessageType is record
      capture            : PtpRxCaptureType;
      rxEpoch            : slv(31 downto 0);
      destination        : slv(47 downto 0);
      sourcePortIdentity : slv(79 downto 0);
      sequenceId         : slv(15 downto 0);
      domainNumber       : slv(7 downto 0);
      messageType        : slv(3 downto 0);
      minorVersion       : slv(3 downto 0);
      transportSpecific  : slv(3 downto 0);
      messageLength      : slv(15 downto 0);
      flags              : slv(15 downto 0);
      correction         : slv(63 downto 0);   -- signed Q16 ns, wire bit pattern
      control            : slv(7 downto 0);
      logInterval        : slv(7 downto 0);    -- signed wire bit pattern
      messageBody        : slv(8*PTP_ANNOUNCE_BODY_BYTES_C-1 downto 0);  -- first body byte at high end
   end record;

   constant PTP_RX_MESSAGE_INIT_C : PtpRxMessageType := (
      capture            => PTP_RX_CAPTURE_INIT_C,
      rxEpoch            => (others => '0'),
      destination        => (others => '0'),
      sourcePortIdentity => (others => '0'),
      sequenceId         => (others => '0'),
      domainNumber       => (others => '0'),
      messageType        => (others => '0'),
      minorVersion       => (others => '0'),
      transportSpecific  => (others => '0'),
      messageLength      => (others => '0'),
      flags              => (others => '0'),
      correction         => (others => '0'),
      control            => (others => '0'),
      logInterval        => (others => '0'),
      messageBody        => (others => '0'));

   type PtpRxMessageArray is array (natural range <>) of PtpRxMessageType;
   -- Flattened verification representation: the exact fields serialized by
   -- toSlv below. Capture increment/error are intentionally not transported.
   constant PTP_RX_MESSAGE_BITS_C : positive :=
      PTP_RX_CAPTURE_INIT_C.timestamp'length + PTP_RX_CAPTURE_INIT_C.ticks'length +
      PTP_RX_CAPTURE_INIT_C.tickPhase'length + PTP_RX_CAPTURE_INIT_C.generation'length + 1 +
      PTP_RX_MESSAGE_INIT_C.rxEpoch'length + PTP_RX_MESSAGE_INIT_C.destination'length +
      PTP_RX_MESSAGE_INIT_C.sourcePortIdentity'length + PTP_RX_MESSAGE_INIT_C.sequenceId'length +
      PTP_RX_MESSAGE_INIT_C.domainNumber'length + PTP_RX_MESSAGE_INIT_C.messageType'length +
      PTP_RX_MESSAGE_INIT_C.minorVersion'length + PTP_RX_MESSAGE_INIT_C.transportSpecific'length +
      PTP_RX_MESSAGE_INIT_C.messageLength'length + PTP_RX_MESSAGE_INIT_C.flags'length +
      PTP_RX_MESSAGE_INIT_C.correction'length + PTP_RX_MESSAGE_INIT_C.control'length +
      PTP_RX_MESSAGE_INIT_C.logInterval'length + PTP_RX_MESSAGE_INIT_C.messageBody'length;
   -- Lossless storage representation extends the unchanged verification layout.
   -- MSBs are toSlv(message); low bits are capture.increment then capture.error.
   constant PTP_RX_STORAGE_BITS_C : positive :=
      PTP_RX_MESSAGE_BITS_C + PTP_RX_CAPTURE_INIT_C.increment'length + 1;
   subtype PtpRxStorageType is slv(PTP_RX_STORAGE_BITS_C-1 downto 0);
   function ptpPackRxMessage (message : PtpRxMessageType) return PtpRxStorageType;
   function ptpUnpackRxMessage (value : PtpRxStorageType) return PtpRxMessageType;
   -- Message-specific body views, in network significance. Callers first
   -- qualify messageType; these accessors do not perform protocol admission.
   function ptpMessageTimestamp (message : PtpRxMessageType) return slv;
   function ptpMessageNanoseconds (message : PtpRxMessageType) return slv;
   function ptpRequestingIdentity (message : PtpRxMessageType) return slv;
   function ptpGrandmasterIdentity (message : PtpRxMessageType) return slv;
   function ptpUtcOffset (message : PtpRxMessageType) return slv;
   -- Registered coordinator-to-bank commit transaction in clk. prepare freezes each
   -- bank's shadow. Sequential preparation raises configPrepared before the
   -- coordinator consumes configValid and issues a later common apply.
   -- busy spans the transaction and prevents PHC manual command admission.
   -- Banks consume the same record so the candidate and apply edges agree.
   -- System reset must reset the coordinator and all participating banks.
   type PtpConfigControlType is record
      prepare : sl;
      apply   : sl;
      busy    : sl;
   end record;

   constant PTP_CONFIG_CONTROL_INIT_C : PtpConfigControlType := (
      prepare => '0',
      apply   => '0',
      busy    => '0');

   -- Registered snapshot request broadcast to all register banks. The next
   -- edge samples pre-edge status and completes the coordinator's sequence.
   -- Once issued, the request is not withdrawn by later capture invalidation;
   -- all banks sample the same edge even if live state changes on that edge.
   -- sequenceId tags the samples; it has no meaning without capture.
   type PtpSnapshotControlType is record
      publish    : sl;
      capture    : sl;
      sequenceId : slv(31 downto 0);
   end record;

   constant PTP_SNAPSHOT_CONTROL_INIT_C : PtpSnapshotControlType := (
      publish    => '0',
      capture    => '0',
      sequenceId => (others => '0'));

   -- Saturating RX frontend counters. accepted counts queue insertions;
   -- dropped counts completed frames rejected by validation, not every frame
   -- lost during flush or before SOF; overflow counts full-queue completions.
   -- These are live clk-domain values; PtpProtocolEngine snapshots them for AXI reads.
   type PtpRxCountersType is record
      accepted : slv(31 downto 0);
      dropped  : slv(31 downto 0);
      overflow : slv(31 downto 0);
   end record;

   constant PTP_RX_COUNTERS_INIT_C : PtpRxCountersType := (
      accepted => (others => '0'),
      dropped  => (others => '0'),
      overflow => (others => '0'));

   -- PtpProtocolEngine owns these shadow/candidate/active settings in clk. Its child
   -- PtpTxLedger consumes the complete active record directly in that domain.
   -- Timers use unsteered clock cycles; maxPathDelay uses signed Q16 ns.
   -- Defaults target a 1 Hz source. Shorter intervals require separate
   -- qualification of the resulting control envelope.
   type PtpPortConfigType is record
      identityOverride   : sl;
      domainNumber       : slv(7 downto 0);
      minorVersion       : slv(3 downto 0);
      localIdentity      : slv(79 downto 0);
      sourceIdentity     : slv(79 downto 0);
      delayInterval      : slv(63 downto 0);
      syncTimeout        : slv(63 downto 0);
      associationTimeout : slv(63 downto 0);
      maxExchange        : slv(63 downto 0);
      minRateSpan        : slv(63 downto 0);
      maxRateAge         : slv(63 downto 0);
      maxPathDelay       : slv(63 downto 0);
      lfsrSeed           : slv(15 downto 0);
   end record;

   constant PTP_PORT_CONFIG_INIT_C : PtpPortConfigType := (
      identityOverride => '0',                     -- Derive clock identity from localMac on apply.
      domainNumber     => x"00",                   -- Default PTP domain 0.
      minorVersion     => x"1",                    -- Transmit major version 2, minor version 1.
      localIdentity    => x"001122FFFE3344550001", -- Example MAC 00:11:22:33:44:55 + FFFE, port 1.
      sourceIdentity   => x"00000000000000000001", -- Placeholder clock identity 0, port 1; configure upstream.
      -- Raw ticks = seconds * 156250000 here. PtpProtocolReg.initialConfig recomputes
      -- these timer defaults from CLK_FREQ_G, including at 125 MHz.
      delayInterval      => x"0000000009502F90",     -- 1 s nominal Delay_Req interval before jitter.
      syncTimeout        => x"000000001BF08EB0",     -- 3 s: three nominal 1 Hz Sync periods.
      associationTimeout => x"0000000012A05F20",     -- 2 s to associate message/timestamp records.
      maxExchange        => x"0000000012A05F20",     -- 2 s maximum E2E exchange span.
      minRateSpan        => x"0000000004A817C8",     -- 0.5 s minimum baseline for rate estimation.
      maxRateAge         => x"000000002540BE40",     -- 4 s maximum age of a rate estimate.
      -- Signed Q16 nanoseconds: integer nanoseconds multiplied by 2**16.
      maxPathDelay => x"0000000F42400000",     -- 1000000 ns = 1 ms path-delay bound.
      lfsrSeed     => x"0001");                -- Nonzero seed avoids the Delay_Req jitter LFSR's zero state.

   -- PtpServo owns these shadow/candidate/active settings in clk. Timers use
   -- unsteered cycles; delay/offset limits use signed Q16 ns, gains Q2.30,
   -- rate limits whole ppb, and qualification counts accepted samples.
   type PtpServoConfigType is record
      allowStep       : sl;
      maxDelayAge     : slv(63 downto 0);
      holdoverTimeout : slv(63 downto 0);
      minSampleTicks  : slv(63 downto 0);
      maxSampleTicks  : slv(63 downto 0);
      delayAsymmetry  : slv(63 downto 0);
      stepThreshold   : slv(63 downto 0);
      lockThreshold   : slv(63 downto 0);
      unlockThreshold : slv(63 downto 0);
      kp              : slv(31 downto 0);
      ki              : slv(31 downto 0);
      maxFrequencyPpb : slv(31 downto 0);
      maxSlewPpb      : slv(31 downto 0);
      maxRatePpb      : slv(31 downto 0);
      lockCount       : slv(7 downto 0);
      unlockCount     : slv(7 downto 0);
   end record;

   -- Configurable startup policy for a 1 Hz source. Gain/limit choices and
   -- their numerical qualification are recorded in
   -- docs/plans/ethernet-ptp/autonomous-endpoint.md (repository-relative).
   constant PTP_SERVO_CONFIG_INIT_C : PtpServoConfigType := (
      allowStep => '1',                 -- Permit epoch acquisition while time is invalid.
      -- Raw ticks = seconds * 156250000 here. PtpServo.initialConfig recomputes
      -- these timer defaults from CLK_FREQ_G, including at 125 MHz.
      maxDelayAge     => x"000000002540BE40", -- 4 s maximum age of a path-delay estimate.
      holdoverTimeout => x"00000002540BE400", -- 64 s maximum holdover before validity expires.
      minSampleTicks  => x"00000000002540BE", -- floor(156250000 / 64): about 1/64 s.
      maxSampleTicks  => x"0000000012A05F20", -- 2 s maximum servo sample interval.
      -- Signed Q16 nanoseconds: integer nanoseconds multiplied by 2**16.
      delayAsymmetry  => (others => '0'),     -- No calibrated directional asymmetry correction.
      stepThreshold   => x"000000004E200000", -- 20000 ns = 20 us acquisition-step threshold.
      lockThreshold   => x"0000000000640000", -- 100 ns inner lock threshold.
      unlockThreshold => x"0000000003E80000", -- 1000 ns = 1 us outer hysteresis threshold.
      -- Q2.30 gains: physical gain multiplied by 2**30.
      kp => x"10000000",         -- 0.25 ppb/ns proportional phase-slew gain.
      ki => x"04000000",         -- 0.0625 ppb/(ns*s) integral frequency gain.
      -- Whole-ppb clamps; the total budget is frequency plus phase slew.
      maxFrequencyPpb => x"000186A0",         -- 100000 ppb = 100 ppm frequency correction.
      maxSlewPpb      => x"0000C350",         -- 50000 ppb = 50 ppm phase slew.
      maxRatePpb      => x"000249F0",         -- 150000 ppb = 150 ppm combined correction.
      lockCount       => x"08",               -- Eight qualifying samples inside the lock threshold.
      unlockCount     => x"03");              -- Three qualifying samples beyond the unlock threshold.

   -- PtpProtocolEngine exports these active limits to PtpServo in the common clk domain.
   -- There is no handshake or independent writable copy in the receiving core.
   -- Timeout units are unsteered cycles; maxPathDelay is signed Q16 ns.
   type PtpSharedConfigType is record
      associationTimeout : slv(63 downto 0);
      syncTimeout        : slv(63 downto 0);
      maxPathDelay       : slv(63 downto 0);
   end record;

   constant PTP_SHARED_CONFIG_INIT_C : PtpSharedConfigType := (
      associationTimeout => PTP_PORT_CONFIG_INIT_C.associationTimeout,
      syncTimeout        => PTP_PORT_CONFIG_INIT_C.syncTimeout,
      maxPathDelay       => PTP_PORT_CONFIG_INIT_C.maxPathDelay);

   -- Servo quality encoding shared by RTL status and the software register ABI.
   constant PTP_SERVO_DISABLED_C  : slv(2 downto 0) := "000";
   constant PTP_SERVO_ACQUIRING_C : slv(2 downto 0) := "001";
   constant PTP_SERVO_TRACKING_C  : slv(2 downto 0) := "010";
   constant PTP_SERVO_LOCKED_C    : slv(2 downto 0) := "011";
   constant PTP_SERVO_HOLDOVER_C  : slv(2 downto 0) := "100";
   constant PTP_SERVO_FAULT_C     : slv(2 downto 0) := "101";
   -- Live servo diagnostics in clk, without a handshake. These fields report
   -- the same pre-edge state exposed by the local register snapshots. Delay
   -- and offset use signed Q16 nanoseconds; ratePpb is signed Q16 ppb.
   -- Lifecycle outputs such as expireTime are controls, not diagnostic fields.
   type PtpServoStatusType is record
      state         : slv(2 downto 0);
      filteredDelay : slv(127 downto 0);
      offsetValue   : slv(127 downto 0);
      ratePpb       : slv(63 downto 0);
      filterCount   : slv(2 downto 0);
      rejectedCount : slv(31 downto 0);
   end record;

   constant PTP_SERVO_STATUS_INIT_C : PtpServoStatusType := (
      state         => PTP_SERVO_ACQUIRING_C,
      filteredDelay => (others => '0'),
      offsetValue   => (others => '0'),
      ratePpb       => (others => '0'),
      filterCount   => (others => '0'),
      rejectedCount => (others => '0'));

   -- Forward and path-delay updates have independent cadences. Provenance stays
   -- with arithmetic through its serialized pipeline; abort cancels publication.
   type PtpMeasurementType is record
      isDelay       : sl;
      generation    : slv(31 downto 0);
      ticks         : slv(63 downto 0);
      syncSequence  : slv(15 downto 0);
      delaySequence : slv(15 downto 0);
      forward       : slv(127 downto 0);
      delayValue    : slv(127 downto 0);
      ratio         : slv(63 downto 0);   -- Q16.48 master ns per raw clock cycle
      ratioValid    : sl;
   end record;

   constant PTP_MEASUREMENT_INIT_C : PtpMeasurementType := (
      isDelay       => '0',
      generation    => (others => '0'),
      ticks         => (others => '0'),
      syncSequence  => (others => '0'),
      delaySequence => (others => '0'),
      forward       => (others => '0'),
      delayValue    => (others => '0'),
      ratio         => (others => '0'),
      ratioValid    => '0');

   -- Port-to-servo transfer in the shared PHC clock domain. Data is sampled
   -- only when valid and ready are high and abort is low. Abort has priority
   -- over a coincident transfer and invalidates pending downstream work; it
   -- is meaningful even when valid is low. All forward fields are registered.
   -- An event detected at N is consumed at N+1; earlier completed operations
   -- are not retroactively revoked. This is not a CDC handshake.
   type PtpMeasurementMasterType is record
      data  : PtpMeasurementType;
      valid : sl;
      abort : sl;
   end record;

   constant PTP_MEASUREMENT_MASTER_INIT_C : PtpMeasurementMasterType := (
      data  => PTP_MEASUREMENT_INIT_C,
      valid => '0',
      abort => '0');

   type PtpMeasurementSlaveType is record
      ready : sl;
   end record;

   constant PTP_MEASUREMENT_SLAVE_INIT_C : PtpMeasurementSlaveType := (
      ready => '0');

   type PtpSyncSampleType is record
      capture    : PtpRxCaptureType;
      remoteTime : slv(79 downto 0);
      correction : slv(127 downto 0);
      sequenceId : slv(15 downto 0);
   end record;

   constant PTP_SYNC_SAMPLE_INIT_C : PtpSyncSampleType := (
      capture    => PTP_RX_CAPTURE_INIT_C,
      remoteTime => (others => '0'),
      correction => (others => '0'),
      sequenceId => (others => '0'));

   type PtpSyncSampleArray is array (natural range <>) of PtpSyncSampleType;
   type PtpDelaySampleType is record
      capture       : PtpRxCaptureType;
      remoteTime    : slv(79 downto 0);
      correction    : slv(63 downto 0);
      responseTicks : slv(63 downto 0);
      sequenceId    : slv(15 downto 0);
      generation    : slv(31 downto 0);
   end record;

   constant PTP_DELAY_SAMPLE_INIT_C : PtpDelaySampleType := (
      capture       => PTP_RX_CAPTURE_INIT_C,
      remoteTime    => (others => '0'),
      correction    => (others => '0'),
      responseTicks => (others => '0'),
      sequenceId    => (others => '0'),
      generation    => (others => '0'));

   type PtpExchangeType is record
      t1              : slv(79 downto 0);
      t2              : slv(95 downto 0);
      t3              : slv(95 downto 0);
      t4              : slv(79 downto 0);
      syncCorrection  : slv(127 downto 0);
      delayCorrection : slv(63 downto 0);
      generation      : slv(31 downto 0);
      syncSequence    : slv(15 downto 0);
      delaySequence   : slv(15 downto 0);
   end record;

   constant PTP_EXCHANGE_INIT_C : PtpExchangeType := (
      t1              => (others => '0'),
      t2              => (others => '0'),
      t3              => (others => '0'),
      t4              => (others => '0'),
      syncCorrection  => (others => '0'),
      delayCorrection => (others => '0'),
      generation      => (others => '0'),
      syncSequence    => (others => '0'),
      delaySequence   => (others => '0'));

   -- Registered lifecycle controls in clk, without a ready/valid handshake.
   -- A cause sampled at N is consumed at N+1. commandAbort excludes the PHC's
   -- own capture abort, so a phase step cannot cancel itself. identityRestart
   -- reports a MAC change; endpoint restart/RX flush add one registered hop.
   type PtpPortLifecycleType is record
      commandAbort    : sl;
      identityRestart : sl;
   end record;

   constant PTP_PORT_LIFECYCLE_INIT_C : PtpPortLifecycleType := (
      commandAbort    => '0',
      identityRestart => '0');

   -- Registered port diagnostics in clk; no handshake or cancellation role.
   -- The record owns live counters, Announce metadata and the last completed
   -- exchange. Derived ratio/Announce validity is sampled on each clock edge;
   -- protocol admission uses current-cycle checks rather than these summaries.
   -- PtpProtocolEngine's separate AXI snapshot bank freezes pre-edge diagnostic state on
   -- the common capture strobe. PtpEndpointControl consumes registered summaries.
   type PtpPortStatusType is record
      active              : sl;
      ratioValid          : sl;
      announceValid       : sl;
      exchange            : PtpExchangeType;
      announceBody        : slv(239 downto 0);
      ledgerStatus        : slv(31 downto 0);
      grandmasterIdentity : slv(63 downto 0);
      announceFlags       : slv(15 downto 0);
      utcOffset           : slv(15 downto 0);
      rejectedCount       : slv(31 downto 0);
      syncCount           : slv(31 downto 0);
      delayCount          : slv(31 downto 0);
      timeoutCount        : slv(31 downto 0);
   end record;

   constant PTP_PORT_STATUS_INIT_C : PtpPortStatusType := (
      active              => '0',
      ratioValid          => '0',
      announceValid       => '0',
      exchange            => PTP_EXCHANGE_INIT_C,
      announceBody        => (others => '0'),
      ledgerStatus        => (others => '0'),
      grandmasterIdentity => (others => '0'),
      announceFlags       => (others => '0'),
      utcOffset           => (others => '0'),
      rejectedCount       => (others => '0'),
      syncCount           => (others => '0'),
      delayCount          => (others => '0'),
      timeoutCount        => (others => '0'));

   -- Build an 80-bit portIdentity from the SURF MAC representation: the first
   -- wire octet is in mac(7 downto 0). The result has clockIdentity in bits
   -- 79:16, first wire octet most significant, followed by the port number.
   -- MAC A:B:C:D:E:F becomes A:B:C:FF:FE:D:E:F; MAC bits are unchanged.
   function ptpPortIdentity (
      mac        : slv(47 downto 0);
      portNumber : slv(15 downto 0)) return slv;
   function ptpTimeQ16 (timestamp : slv(95 downto 0)) return signed;
   function ptpWireTimeQ16 (timestamp : slv(79 downto 0)) return signed;
   function ptpTickPhase (capture : PtpRxCaptureType) return signed;
   function ptpRoundShift (
      value : signed;
      bits  : natural) return signed;

   -- Rounded right shift with ties away from zero, computed without forming a
   -- wide absolute value. Uses the floor shift plus a guard/sticky decision,
   -- so the long combinational path through an abs/negate chain is avoided.
   -- The result is one bit wider than the floor quotient to retain a positive
   -- rounding carry, including at the signed input extrema.
   function ptpRoundShiftExact (
      value : signed;
      bits  : positive) return signed;

   -- Count of low zero bits and of significant bits in a constant. These are
   -- elaboration helpers for factoring a constant divisor as `odd << k`.
   function ptpTrailingZeros (value : unsigned) return natural;
   function ptpUsedBits (value : unsigned) return positive;

   function ptpSatInc (value : slv) return slv;
   -- Compatibility adder; native inference beats the former carry-select tree.
   -- Operands have equal widths; the result wraps at that width like numeric_std.
   function ptpAddFast (left, right : unsigned; carry : sl := '0') return unsigned;
   function ptpAgeExpired (nowTicks, thenTicks, timeout : slv(63 downto 0)) return boolean;
   -- Walk at most two complete TLV headers per normalized eight-byte beat.
   -- Only the bytes in [firstByte, endByte) belong to the TLV stream.
   procedure ptpTlvBeat (
      constant data        : in  slv(63 downto 0);
      constant firstByte   : in  natural;
      constant endByte     : in  natural;
      constant messageLeft : in  natural;
      variable headerBytes : inout natural;
      variable length      : inout slv(15 downto 0);
      variable remaining   : inout natural;
      variable bad         : inout sl);

   -- Timeout comparisons use unsigned tick differences. Restrict configured
   -- intervals to nonzero values below 2^62 so wrap/ordering stays unambiguous.
   function ptpValidTimeout (value : slv(63 downto 0)) return boolean;
   -- Fixed 744-bit representation used by flattened verification interfaces.
   -- Capture arithmetic errors are rejected before enqueue and are not packed.
   function toSlv (message : PtpRxMessageType) return slv;
   -- Translate a physical word sample to its first destination-MAC byte.
   -- lane is that byte's position (0..7), not the preceding XGMII /S/ lane.
   -- increment is the active unsigned Q32 ns/cycle PHC addend; ticks names
   -- the sampled cycle. GMII supplies lane zero. ingressLatency is signed
   -- Q16 ns and must be an elaboration-time value at the current call sites.
   function ptpRxCapture (
      phcTime                 : PtpTimeType;
      increment               : slv(63 downto 0);
      lane                    : natural;
      ticks                   : slv(63 downto 0);
      generation              : slv(31 downto 0);
      timeValid               : sl;
      constant ingressLatency : slv(63 downto 0)) return PtpRxCaptureType;

   -- Produced in the local protocol clk. valid/data are held until messageReady.
   -- Abort/flush is a separate lifecycle event and invalidates a same-edge transfer.
   -- The data record retains the wire timestamp, generation and message metadata.
   type PtpRxMessageMasterType is record
      valid : sl;
      data  : PtpRxMessageType;
   end record;

   constant PTP_RX_MESSAGE_MASTER_INIT_C : PtpRxMessageMasterType := (
      valid => '0',
      data  => PTP_RX_MESSAGE_INIT_C);

   -- Ledger-produced in clk. Hold valid/data until sampleReady; restart/reset
   -- invalidates transfer. data retains the completed physical request's provenance.
   type PtpDelaySampleMasterType is record
      valid : sl;
      data  : PtpDelaySampleType;
   end record;

   constant PTP_DELAY_SAMPLE_MASTER_INIT_C : PtpDelaySampleMasterType := (
      valid => '0',
      data  => PTP_DELAY_SAMPLE_INIT_C);

   -- Published in readClk: valid pulses with a coherent PHC snapshot, no ready.
   -- timeValid qualifies the timestamp; ticks/generation come from that PHC edge.
   -- sequenceId identifies the local request. Either domain reset cancels the session;
   -- this record never combines readClk signals with live phcClk status.
   type PtpPhcReadResultType is record
      valid      : sl;
      time       : PtpTimeType;
      generation : slv(31 downto 0);
      ticks      : slv(63 downto 0);
      timeValid  : sl;
      sequenceId : slv(31 downto 0);
   end record;

   constant PTP_PHC_READ_RESULT_INIT_C : PtpPhcReadResultType := (
      valid      => '0',
      time       => PTP_TIME_INIT_C,
      generation => (others => '0'),
      ticks      => (others => '0'),
      timeValid  => '0',
      sequenceId => (others => '0'));

   -- Timing-port contract: ethernet/PtpCore/timing-port.md. These records are
   -- the controller-facing boundary of a timing-capable MAC port. No production
   -- entity produces or consumes them yet; the layouts are declared here so
   -- the RTL, DMA envelope, PyRogue and Linux adapter share one definition.
   -- The MAC-port prefix is distinct from the IEEE 1588 protocol-port records
   -- (PtpPortConfigType, PtpPortLifecycleType, PtpPortStatusType) above.

   -- ABI identity published in the capability register and in every DMA
   -- envelope header. A receiver validates version and type before status.
   constant PTP_MAC_PORT_ABI_VERSION_C      : slv(7 downto 0) := x"01";
   constant PTP_MAC_PORT_ENVELOPE_VERSION_C : slv(7 downto 0) := x"01";
   constant PTP_MAC_PORT_RECORD_RX_C        : slv(7 downto 0) := x"01";
   constant PTP_MAC_PORT_RECORD_TX_REQ_C    : slv(7 downto 0) := x"02";
   constant PTP_MAC_PORT_RECORD_TX_CMPL_C   : slv(7 downto 0) := x"03";
   -- Envelope status byte bit positions (offset 12 of the common header).
   constant PTP_MAC_PORT_STATUS_OUTCOME_LOW_C   : natural := 0;  -- bits 1:0
   constant PTP_MAC_PORT_STATUS_CAPTURE_VALID_C : natural := 2;
   constant PTP_MAC_PORT_STATUS_CAPTURE_ERROR_C : natural := 3;
   constant PTP_MAC_PORT_STATUS_TIME_VALID_C    : natural := 4;
   constant PTP_MAC_PORT_STATUS_TIMESTAMP_REQ_C : natural := 5;
   -- Capture plane identifier: first destination-MAC octet at the MAC-side pins.
   constant PTP_MAC_PORT_PLANE_MAC_DMAC_C : slv(3 downto 0) := x"1";
   -- PHY type as published; matches the PHY_TYPE_G string selection.
   constant PTP_MAC_PORT_PHY_GMII_C  : slv(3 downto 0) := x"1";
   constant PTP_MAC_PORT_PHY_XGMII_C : slv(3 downto 0) := x"2";

   -- Autonomous-backend RX table depths (timing-port.md section 11.1): the
   -- minimum-length PTP frames at the minimum IFG that arrive while a
   -- maximum frame drains through the RX adapter, measured loss-free, and
   -- the largest depth whose maximum-frame RX FIFO (97 words per entry)
   -- fits 512 (GMII) or 2048 (XGMII) words.
   constant PTP_MAC_PORT_RX_DEPTH_GMII_C  : positive := 5;
   constant PTP_MAC_PORT_RX_DEPTH_XGMII_C : positive := 21;

   -- Software cookie carried with a TX request and returned unchanged in its
   -- completion. The port's internal MAC token is narrower and never exposed.
   constant PTP_MAC_PORT_COOKIE_BITS_C : positive := 32;
   subtype PtpMacPortCookieType is slv(PTP_MAC_PORT_COOKIE_BITS_C-1 downto 0);

   -- Final disposition of a frame at the wire plane.
   constant PTP_MAC_PORT_OUTCOME_SENT_C      : slv(1 downto 0) := "00";  -- Complete frame left/entered the wire, FCS good.
   constant PTP_MAC_PORT_OUTCOME_WIRE_ERR_C  : slv(1 downto 0) := "01";  -- Reached the wire, corrupted: underrun, link loss or aborted.
   constant PTP_MAC_PORT_OUTCOME_DISCARDED_C : slv(1 downto 0) := "10";  -- Consumed inside the port or MAC before the wire plane.
   constant PTP_MAC_PORT_OUTCOME_FLUSHED_C   : slv(1 downto 0) := "11";  -- Never reached the wire plane: forced abort before start, or a stale-generation request.

   -- Port lifetime identifier carried in every RX record and TX completion.
   -- System reset clears it to PTP_MAC_PORT_GENERATION_RESET_C; the port advances
   -- it to the first live value when admission opens and on each acknowledged
   -- forced abort. The reset value never admits traffic. The last value is an
   -- exhaustion fault that closes admission until system reset; it never wraps.
   constant PTP_MAC_PORT_GENERATION_BITS_C    : positive         := 16;
   constant PTP_MAC_PORT_GENERATION_RESET_C   : slv(15 downto 0) := x"0000";
   constant PTP_MAC_PORT_GENERATION_EXHAUST_C : slv(15 downto 0) := x"FFFF";

   -- Per-frame metadata delivered beside a received frame in clk. Published
   -- with the frame's SOF beat and held stable until the frame's last beat is
   -- accepted; final status is known at SOF because delivery is
   -- store-and-forward. frameLength counts Ethernet bytes from the destination
   -- MAC through the last payload octet, FCS excluded. capture is the complete
   -- RX capture at the first destination-MAC octet; capture.error marks an
   -- unusable timestamp without invalidating the frame. transportGeneration
   -- is the live generation at the frame's wire start; a consumer discards
   -- frames whose generation it has not observed. The RX table entry stays
   -- owned until the controller accepts the frame's last beat.
   type PtpMacPortRxMetaType is record
      capture             : PtpRxCaptureType;
      frameLength         : slv(15 downto 0);
      transportGeneration : slv(15 downto 0);
   end record;

   constant PTP_MAC_PORT_RX_META_INIT_C : PtpMacPortRxMetaType := (
      capture             => PTP_RX_CAPTURE_INIT_C,
      frameLength         => (others => '0'),
      transportGeneration => (others => '0'));

   -- Port RX output in clk: frame is an SSI AXI Stream master in the port's
   -- primary configuration (SOF on the first beat, EOFE never set on a
   -- delivered frame); meta is valid on every beat of that frame. The reverse
   -- ready is a separate signal. Dropped frames are counted and never appear.
   type PtpMacPortRxMasterType is record
      frame : AxiStreamMasterType;
      meta  : PtpMacPortRxMetaType;
   end record;

   constant PTP_MAC_PORT_RX_MASTER_INIT_C : PtpMacPortRxMasterType := (
      frame => AXI_STREAM_MASTER_INIT_C,
      meta  => PTP_MAC_PORT_RX_META_INIT_C);

   -- TX request descriptor in clk, presented with the frame's SOF beat and
   -- held stable until that beat is accepted. The port accepts the SOF beat
   -- only after reserving a table entry and a completion slot; the controller
   -- sees ordinary stream backpressure otherwise. timestamp asks for a wire
   -- capture; every accepted request receives exactly one completion whether
   -- or not it asked. frameLength is the Ethernet byte count the controller
   -- will present, FCS excluded; the port verifies it against the bytes
   -- actually received. transportGeneration is the generation the controller
   -- observed when it built the request; a request from another generation is
   -- consumed and completed FLUSHED without reaching the MAC.
   type PtpMacPortTxRequestType is record
      cookie              : PtpMacPortCookieType;
      timestamp           : sl;
      frameLength         : slv(15 downto 0);
      transportGeneration : slv(15 downto 0);
   end record;

   constant PTP_MAC_PORT_TX_REQUEST_INIT_C : PtpMacPortTxRequestType := (
      cookie              => (others => '0'),
      timestamp           => '0',
      frameLength         => (others => '0'),
      transportGeneration => (others => '0'));

   -- Port TX input in clk: frame is an SSI AXI Stream master in the port's
   -- primary configuration; request is meaningful on the SOF beat. The reverse
   -- ready is a separate signal.
   type PtpMacPortTxMasterType is record
      frame   : AxiStreamMasterType;
      request : PtpMacPortTxRequestType;
   end record;

   constant PTP_MAC_PORT_TX_MASTER_INIT_C : PtpMacPortTxMasterType := (
      frame   => AXI_STREAM_MASTER_INIT_C,
      request => PTP_MAC_PORT_TX_REQUEST_INIT_C);

   -- Terminal completion for one accepted TX request, in clk. Published once
   -- per request after its wire done event, confirmed discard or acknowledged
   -- forced abort; held through ready, and the table entry is released only
   -- when the controller accepts it. captureValid means the SOF capture was
   -- taken with error clear and no PHC generation change or capture abort
   -- intervened before done. FLUSHED is issued only for a request whose frame
   -- never produced a wire start: forced abort before the exporter launched
   -- it, or a stale generation. A frame on the pins at abort is terminated by
   -- the exporter and completes WIRE_ERR with its capture. A FLUSHED
   -- completion carries the generation of the aborted lifetime, or the stale
   -- request's own generation.
   type PtpMacPortTxCompletionType is record
      cookie              : PtpMacPortCookieType;
      outcome             : slv(1 downto 0);
      captureValid        : sl;
      capture             : PtpRxCaptureType;
      transportGeneration : slv(15 downto 0);
   end record;

   constant PTP_MAC_PORT_TX_COMPLETION_INIT_C : PtpMacPortTxCompletionType := (
      cookie              => (others => '0'),
      outcome             => PTP_MAC_PORT_OUTCOME_DISCARDED_C,
      captureValid        => '0',
      capture             => PTP_RX_CAPTURE_INIT_C,
      transportGeneration => (others => '0'));

   -- Port-produced in clk. Hold valid/data until completionReady. A system
   -- reset of the MAC pipeline invalidates a same-edge transfer; forced abort
   -- does not, because FLUSHED completions are themselves delivered through
   -- this channel and their entries stay owned until accepted.
   type PtpMacPortTxCompletionMasterType is record
      valid : sl;
      data  : PtpMacPortTxCompletionType;
   end record;

   constant PTP_MAC_PORT_TX_COMPLETION_MASTER_INIT_C : PtpMacPortTxCompletionMasterType := (
      valid => '0',
      data  => PTP_MAC_PORT_TX_COMPLETION_INIT_C);

   -- Controller-to-port lifecycle controls in clk; registered levels, no
   -- handshake of their own. openAdmission moves the generation off its reset
   -- value and admits traffic. drainRequest closes admission to new frames
   -- while the currently open TX frame completes. abortRequest starts the
   -- forced abort of §6; cancelAck is the controller's acknowledgement that
   -- it has terminated its open TX frame and consumed the port's partial RX
   -- terminator, held high until the port clears cancelRequest.
   type PtpMacPortControlType is record
      openAdmission : sl;
      drainRequest  : sl;
      abortRequest  : sl;
      cancelAck     : sl;
   end record;

   constant PTP_MAC_PORT_CONTROL_INIT_C : PtpMacPortControlType := (
      openAdmission => '0',
      drainRequest  => '0',
      abortRequest  => '0',
      cancelAck     => '0');

   -- Port-to-controller lifecycle status in clk; registered levels.
   -- cancelRequest asks the controller to take part in a forced abort (§6);
   -- abortDone reports that every owner and the controller acknowledged and
   -- the remaining entries were released; transportGeneration is the live
   -- value. Fault bits are sticky until system reset.
   type PtpMacPortStatusType is record
      admissionOpen       : sl;
      drainIdle           : sl;
      cancelRequest       : sl;
      abortDone           : sl;
      transportGeneration : slv(15 downto 0);
      faultGeneration     : sl;
      faultClockEnable    : sl;
      faultTokenProtocol  : sl;
   end record;

   constant PTP_MAC_PORT_STATUS_INIT_C : PtpMacPortStatusType := (
      admissionOpen       => '0',
      drainIdle           => '1',
      cancelRequest       => '0',
      abortDone           => '0',
      transportGeneration => PTP_MAC_PORT_GENERATION_RESET_C,
      faultGeneration     => '0',
      faultClockEnable    => '0',
      faultTokenProtocol  => '0');

   -- Registered port diagnostics in clk; no handshake. Saturating counters.
   -- rxDropped counts tokened RX frames consumed by a MAC stage or released
   -- by forced abort without delivery; rxLost counts wire starts the import
   -- leaf abandoned before emitting any beat. txSent/txWireError/txDiscarded/
   -- txFlushed count completions by outcome; txRejected counts TX stream
   -- frames consumed without admission (no SOF, no request context), which
   -- receive no completion.
   type PtpMacPortCountersType is record
      rxDelivered : slv(31 downto 0);
      rxDropped   : slv(31 downto 0);
      rxLost      : slv(31 downto 0);
      txSent      : slv(31 downto 0);
      txWireError : slv(31 downto 0);
      txDiscarded : slv(31 downto 0);
      txFlushed   : slv(31 downto 0);
      txRejected  : slv(31 downto 0);
   end record;

   constant PTP_MAC_PORT_COUNTERS_INIT_C : PtpMacPortCountersType := (
      rxDelivered => (others => '0'),
      rxDropped   => (others => '0'),
      rxLost      => (others => '0'),
      txSent      => (others => '0'),
      txWireError => (others => '0'),
      txDiscarded => (others => '0'),
      txFlushed   => (others => '0'),
      txRejected  => (others => '0'));

   -- Packed widths for a vector-only boundary such as a completion FIFO.
   -- Field order, MSB to LSB, matches the record declaration order; see the
   -- pack/unpack bodies. tValid and ready are transported separately.
   constant PTP_RX_CAPTURE_BITS_C : positive :=
      PTP_RX_CAPTURE_INIT_C.timestamp'length + PTP_RX_CAPTURE_INIT_C.ticks'length +
      PTP_RX_CAPTURE_INIT_C.tickPhase'length + PTP_RX_CAPTURE_INIT_C.generation'length +
      PTP_RX_CAPTURE_INIT_C.increment'length + 2;

   constant PTP_MAC_PORT_RX_META_BITS_C : positive := PTP_RX_CAPTURE_BITS_C + 16 + 16;

   constant PTP_MAC_PORT_TX_COMPLETION_BITS_C : positive :=
      PTP_MAC_PORT_COOKIE_BITS_C + 2 + 1 + PTP_RX_CAPTURE_BITS_C + 16;

   function toSlv (capture : PtpRxCaptureType) return slv;
   function toPtpRxCapture (value : slv) return PtpRxCaptureType;
   function toSlv (meta : PtpMacPortRxMetaType) return slv;
   function toPtpMacPortRxMeta (value : slv) return PtpMacPortRxMetaType;
   function toSlv (completion : PtpMacPortTxCompletionType) return slv;
   function toPtpMacPortTxCompletion (value : slv) return PtpMacPortTxCompletionType;

end package PtpPkg;

package body PtpPkg is

   function ptpAddFast (left, right : unsigned; carry : sl := '0') return unsigned is
      variable carryValue : unsigned(left'length-1 downto 0);
   begin
      assert right'length = left'length report "ptpAddFast operand width mismatch" severity failure;
      carryValue := (others => '0');
      carryValue(0) := carry;
      return left+right+carryValue;
   end function;

   function ptpAgeExpired (nowTicks, thenTicks, timeout : slv(63 downto 0)) return boolean is
   begin
      -- Subtract at exactly 64 bits before comparing: expiry is strict and the
      -- elapsed age wraps modulo 2^64, including future capture tick values.
      return unsigned(nowTicks)-unsigned(thenTicks) > unsigned(timeout);
   end function;

   procedure ptpTlvBeat (
      constant data        : in  slv(63 downto 0);
      constant firstByte   : in  natural;
      constant endByte     : in  natural;
      constant messageLeft : in  natural;
      variable headerBytes : inout natural;
      variable length      : inout slv(15 downto 0);
      variable remaining   : inout natural;
      variable bad         : inout sl) is
      variable count : natural range 0 to 8;
      variable start       : integer range -3 to PTP_ETH_MAX_FRAME_C;
      variable firstLow : natural range 0 to PTP_ETH_MAX_FRAME_C+11;
      variable firstAt  : slv(7 downto 0);
      variable laneLength  : Slv16Array(0 to 7);
      variable reachable : boolean;
      variable value     : natural range 0 to 65535;
      variable left      : natural range 0 to 7;
      variable partial   : natural range 0 to 11;
   begin
      count    := endByte-firstByte;
      start    := remaining-integer(headerBytes);
      firstLow := firstByte+start+3;
      -- Decode candidate header endings in parallel at fixed physical lanes.
      -- The only possible second ending is four or six bytes after the first:
      -- its preceding value must have length zero or two. Avoid a variable
      -- byte mux -> length sum -> second variable byte mux feedback chain.
      firstAt := (others => '0');
      for i in 0 to 7 loop
         firstAt(i) := toSl(i = firstLow and i >= firstByte and i < endByte);
         laneLength(i)(7 downto 0) := data(8*i+7 downto 8*i);
         laneLength(i)(15 downto 8) := length(15 downto 8);
         if i > 0 and i > firstByte then
            laneLength(i)(15 downto 8) := data(8*i-1 downto 8*i-8);
         end if;
      end loop;

      -- Default for a beat containing only value bytes or a partial header.
      headerBytes := 0;
      if remaining >= count then
         remaining := remaining-count;
      else
         remaining := 0;
      end if;
      if start < count then
         partial := count-start;
         if partial < 4 then
            headerBytes := partial;
            if partial = 3 and count /= 0 then
               length(15 downto 8) := data(8*endByte-1 downto 8*endByte-8);
            end if;
         end if;
      end if;

      for i in 0 to 7 loop
         reachable := firstAt(i) = '1';
         if i >= 4 then
            reachable := reachable or (firstAt(i-4) = '1' and laneLength(i-4) = x"0000");
         end if;
         if i >= 6 then
            reachable := reachable or (firstAt(i-6) = '1' and laneLength(i-6) = x"0002");
         end if;
         if reachable and i < endByte then
            value       := to_integer(unsigned(laneLength(i)));
            length      := laneLength(i);
            headerBytes := 0;
            remaining   := 0;
            if laneLength(i)(0) = '1' or value > messageLeft-(i-firstByte)-1 then
               bad := '1';
            else
               left := endByte-i-1;
               if value >= left then
                  remaining := value-left;
               else
                  partial := left-value;
                  -- Four or more bytes imply another reachable completion,
                  -- whose later lane overwrites this intermediate state.
                  if partial < 4 then
                     headerBytes := partial;
                     if partial = 3 then
                        length(15 downto 8) := data(8*endByte-1 downto 8*endByte-8);
                     end if;
                  end if;
               end if;
            end if;
         end if;
      end loop;
   end procedure;

   function ptpMessageTimestamp (message : PtpRxMessageType) return slv is
   begin
      -- Sync, Follow_Up and Delay_Resp: body bytes 0..9, seconds then ns.
      return message.messageBody(239 downto 160);
   end function;

   function ptpMessageNanoseconds (message : PtpRxMessageType) return slv is
   begin
      -- Nanoseconds occupy bytes 6..9 of the leading wire timestamp.
      return message.messageBody(191 downto 160);
   end function;

   function ptpRequestingIdentity (message : PtpRxMessageType) return slv is
   begin
      -- Delay_Resp body bytes 10..19, following receiveTimestamp.
      return message.messageBody(159 downto 80);
   end function;

   function ptpGrandmasterIdentity (message : PtpRxMessageType) return slv is
   begin
      -- Announce body bytes 19..26, following grandmasterPriority2.
      return message.messageBody(87 downto 24);
   end function;

   function ptpUtcOffset (message : PtpRxMessageType) return slv is
   begin
      -- Announce body bytes 10..11, following originTimestamp.
      return message.messageBody(159 downto 144);
   end function;

   function ptpPortIdentity (
      mac               : slv(47 downto 0);
      portNumber        : slv(15 downto 0)) return slv is
      variable identity : slv(79 downto 0);
   begin
      identity(79 downto 56) := mac(7 downto 0) & mac(15 downto 8) & mac(23 downto 16);
      identity(55 downto 40) := PTP_CLOCK_ID_INSERT_C;
      identity(39 downto 16) := mac(31 downto 24) & mac(39 downto 32) & mac(47 downto 40);
      identity(15 downto 0)  := portNumber;
      return identity;
   end function;

   function ptpValidTimeout (value : slv(63 downto 0)) return boolean is
   begin
      return unsigned(value) /= 0 and value(63 downto 62) = "00";
   end function;

   function ptpTimeQ16 (timestamp : slv(95 downto 0)) return signed is
      variable whole : unsigned(79 downto 0);
   begin
      whole := unsigned(timestamp(95 downto 48))*to_unsigned(PTP_NANOSECONDS_PER_SECOND_C, 32) +
         resize(unsigned(timestamp(47 downto 16)), 80);
      return signed(resize(whole & unsigned(timestamp(15 downto 0)), 128));
   end function;

   function ptpWireTimeQ16 (timestamp : slv(79 downto 0)) return signed is
   begin
      return ptpTimeQ16(timestamp & x"0000");
   end function;

   function ptpTickPhase (capture : PtpRxCaptureType) return signed is
   begin
      return signed(resize(unsigned(slv'(capture.ticks & capture.tickPhase)), 128));
   end function;

   function ptpRoundShift (
      value                : signed;
      bits                 : natural) return signed is
      variable magnitude   : unsigned(value'length downto 0);
      variable resultValue : signed(value'length downto 0);
   begin
      resultValue := resize(value, value'length+1);
      magnitude   := unsigned(abs(resultValue));

      if bits /= 0 then
         magnitude := shift_right(magnitude + shift_left(to_unsigned(1, magnitude'length), bits-1), bits);
      end if;

      resultValue := signed(magnitude);

      if value(value'high) = '1' then
         resultValue := -resultValue;
      end if;

      return resize(resultValue, value'length);
   end function;

   function ptpRoundShiftExact (
      value : signed;
      bits  : positive) return signed is
      -- value = floor(value/2**bits)*2**bits + unsigned(discarded bits).
      -- A positive tie increments the floor; a negative tie keeps it, which is
      -- ties-away-from-zero in both directions.
      constant RESULT_BITS_C : positive := value'length-bits+1;
      variable resultValue   : signed(RESULT_BITS_C-1 downto 0);
      variable sticky        : boolean;
   begin
      resultValue := resize(shift_right(value, bits), RESULT_BITS_C);
      sticky      := false;

      if bits > 1 then
         sticky := unsigned(value(bits-2 downto 0)) /= 0;
      end if;

      if value(bits-1) = '1' and (value(value'high) = '0' or sticky) then
         resultValue := resultValue+1;
      end if;

      return resultValue;
   end function;

   function ptpTrailingZeros (value : unsigned) return natural is
   begin

      for i in 0 to value'high loop
         if value(i) = '1' then
            return i;
         end if;
      end loop;

      return 0;
   end function;

   function ptpUsedBits (value : unsigned) return positive is
   begin

      for i in value'high downto 0 loop
         if value(i) = '1' then
            return i+1;
         end if;
      end loop;

      return 1;
   end function;

   function ptpSatInc (value : slv) return slv is
   begin

      if unsigned(value) = (value'range => '1') then
         return value;
      end if;

      return slv(unsigned(value)+1);
   end function;

   function ptpNominalIncrement (frequency : positive) return slv is
      constant NUMERATOR_C : unsigned(63 downto 0) := shift_left(to_unsigned(PTP_NANOSECONDS_PER_SECOND_C, 64), PTP_PHC_FRAC_BITS_C);
   begin
      -- Constant elaboration arithmetic, rounded to nearest Q32 ns/cycle.
      return slv((NUMERATOR_C + to_unsigned(frequency/2, 64))/to_unsigned(frequency, 64));
   end function;

   function toSlv (message : PtpRxMessageType) return slv is
   begin
      -- MSB to LSB: capture/provenance, Ethernet identity, PTP header, body.
      return message.capture.timestamp & message.capture.ticks & message.capture.tickPhase &
         message.capture.generation & message.capture.timeValid & message.rxEpoch &
         message.destination & message.sourcePortIdentity & message.sequenceId & message.domainNumber &
         message.messageType & message.minorVersion & message.transportSpecific & message.messageLength &
         message.flags & message.correction & message.control & message.logInterval & message.messageBody;
   end function;

   function ptpPackRxMessage (message : PtpRxMessageType) return PtpRxStorageType is
   begin
      return toSlv(message) & message.capture.increment & message.capture.error;
   end function;

   function ptpUnpackRxMessage (value : PtpRxStorageType) return PtpRxMessageType is
      variable retVar : PtpRxMessageType := PTP_RX_MESSAGE_INIT_C;
      variable index  : integer := 0;
   begin
      assignRecord(index, value, retVar.capture.error);
      assignRecord(index, value, retVar.capture.increment);
      assignRecord(index, value, retVar.messageBody);
      assignRecord(index, value, retVar.logInterval);
      assignRecord(index, value, retVar.control);
      assignRecord(index, value, retVar.correction);
      assignRecord(index, value, retVar.flags);
      assignRecord(index, value, retVar.messageLength);
      assignRecord(index, value, retVar.transportSpecific);
      assignRecord(index, value, retVar.minorVersion);
      assignRecord(index, value, retVar.messageType);
      assignRecord(index, value, retVar.domainNumber);
      assignRecord(index, value, retVar.sequenceId);
      assignRecord(index, value, retVar.sourcePortIdentity);
      assignRecord(index, value, retVar.destination);
      assignRecord(index, value, retVar.rxEpoch);
      assignRecord(index, value, retVar.capture.timeValid);
      assignRecord(index, value, retVar.capture.generation);
      assignRecord(index, value, retVar.capture.tickPhase);
      assignRecord(index, value, retVar.capture.ticks);
      assignRecord(index, value, retVar.capture.timestamp);
      return retVar;
   end function;

   function ptpRxCapture (
      phcTime                 : PtpTimeType;
      increment               : slv(63 downto 0);
      lane                    : natural;
      ticks                   : slv(63 downto 0);
      generation              : slv(31 downto 0);
      timeValid               : sl;
      constant ingressLatency : slv(63 downto 0)) return PtpRxCaptureType is
      -- Split the elaboration-time latency into whole seconds and a signed
      -- remainder smaller than one second. VHDL rem preserves the dividend's
      -- sign, allowing the same subtraction for positive and negative latency.
      -- Current callers pass a generic; never make this a runtime divider by
      -- substituting a changing calibration input without redesigning the path.
      constant SECOND_Q16_C  : signed(63 downto 0) := shift_left(to_signed(PTP_NANOSECONDS_PER_SECOND_C, 64), PTP_TIME_FRAC_BITS_C);
      constant SECOND_Q32_C  : signed(66 downto 0) := shift_left(to_signed(PTP_NANOSECONDS_PER_SECOND_C, 67), PTP_PHC_FRAC_BITS_C);
      constant LAT_SECONDS_C : signed(63 downto 0) := signed(ingressLatency) / SECOND_Q16_C;
      constant LAT_REMAIN_C  : signed(63 downto 0) := signed(ingressLatency) rem SECOND_Q16_C;
      variable retVar        : PtpRxCaptureType := PTP_RX_CAPTURE_INIT_C;
      variable ns            : signed(66 downto 0);
      variable sec           : signed(64 downto 0);
      variable subCycle      : unsigned(66 downto 0);
   begin
      -- Scale the byte phase with the active PHC rate, rather than assuming a
      -- fixed 0.8 ns XGMII byte. Widen before arithmetic and retain Q32 precision
      -- through calibration; a positive ingress latency moves time earlier.
      subCycle := shift_right(unsigned(increment) * to_unsigned(lane, PTP_TICK_PHASE_BITS_C), PTP_TICK_PHASE_BITS_C);
      ns       := signed(resize(unsigned(slv'(phcTime.nanoseconds & phcTime.fraction)), 67)) +
         signed(subCycle) - shift_left(resize(LAT_REMAIN_C, 67), PTP_TIME_TO_PHC_SHIFT_C);
      sec := signed(resize(unsigned(phcTime.seconds), 65)) - resize(LAT_SECONDS_C, 65);
      -- Canonical input and the supported Ethernet-clock addend need at most
      -- one carry/borrow after subtracting the sub-second latency remainder.
      if ns < 0 then
         ns  := ns + SECOND_Q32_C;
         sec := sec - 1;
      elsif ns >= SECOND_Q32_C then
         ns  := ns - SECOND_Q32_C;
         sec := sec + 1;
      end if;

      -- Reject an out-of-range epoch or failed normalization. Truncating the
      -- seconds field alone would wrap a negative capture into a distant future.
      if sec < 0 or shift_right(sec, 48) /= 0 or ns < 0 or ns >= SECOND_Q32_C then
         retVar.error := '1';
      end if;

      -- Discard the low sixteen fractional bits only after normalization.
      -- Raw tick provenance is intentionally unaffected by ingress latency.
      retVar.timestamp  := slv(sec(47 downto 0)) & slv(ns(63 downto PTP_TIME_TO_PHC_SHIFT_C));
      retVar.ticks      := ticks;
      retVar.tickPhase  := slv(to_unsigned(lane, PTP_TICK_PHASE_BITS_C));
      retVar.generation := generation;
      retVar.increment  := increment;
      retVar.timeValid  := timeValid;
      return retVar;
   end function;

   -- Timing-port packing. Each toSlv lists fields MSB to LSB in declaration
   -- order; the paired decoder consumes them LSB-first with assignRecord.

   function toSlv (capture : PtpRxCaptureType) return slv is
   begin
      return capture.timestamp & capture.ticks & capture.tickPhase & capture.generation &
         capture.increment & capture.timeValid & capture.error;
   end function;

   function toPtpRxCapture (value : slv) return PtpRxCaptureType is
      variable retVar : PtpRxCaptureType := PTP_RX_CAPTURE_INIT_C;
      variable index  : integer          := 0;
   begin
      assignRecord(index, value, retVar.error);
      assignRecord(index, value, retVar.timeValid);
      assignRecord(index, value, retVar.increment);
      assignRecord(index, value, retVar.generation);
      assignRecord(index, value, retVar.tickPhase);
      assignRecord(index, value, retVar.ticks);
      assignRecord(index, value, retVar.timestamp);
      return retVar;
   end function;

   function toSlv (meta : PtpMacPortRxMetaType) return slv is
   begin
      return toSlv(meta.capture) & meta.frameLength & meta.transportGeneration;
   end function;

   function toPtpMacPortRxMeta (value : slv) return PtpMacPortRxMetaType is
      variable retVar  : PtpMacPortRxMetaType := PTP_MAC_PORT_RX_META_INIT_C;
      variable capture : slv(PTP_RX_CAPTURE_BITS_C-1 downto 0);
      variable index   : integer           := 0;
   begin
      assignRecord(index, value, retVar.transportGeneration);
      assignRecord(index, value, retVar.frameLength);
      assignRecord(index, value, capture);
      retVar.capture := toPtpRxCapture(capture);
      return retVar;
   end function;

   function toSlv (completion : PtpMacPortTxCompletionType) return slv is
   begin
      return completion.cookie & completion.outcome & completion.captureValid &
         toSlv(completion.capture) & completion.transportGeneration;
   end function;

   function toPtpMacPortTxCompletion (value : slv) return PtpMacPortTxCompletionType is
      variable retVar  : PtpMacPortTxCompletionType := PTP_MAC_PORT_TX_COMPLETION_INIT_C;
      variable capture : slv(PTP_RX_CAPTURE_BITS_C-1 downto 0);
      variable index   : integer                 := 0;
   begin
      assignRecord(index, value, retVar.transportGeneration);
      assignRecord(index, value, capture);
      retVar.capture := toPtpRxCapture(capture);
      assignRecord(index, value, retVar.captureValid);
      assignRecord(index, value, retVar.outcome);
      assignRecord(index, value, retVar.cookie);
      return retVar;
   end function;

end package body PtpPkg;
