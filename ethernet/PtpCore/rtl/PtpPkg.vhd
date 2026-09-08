-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PTP endpoint records, fixed-point helpers and physical capture arithmetic
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

   -- Shared wire records and timebase interfaces. All arithmetic units are explicit.
   -- Normalized RX retains destination-MAC-through-FCS bytes in low-byte-first
   -- AXI lanes. SOF and the capture sidecar must share one pipeline; there is
   -- no independent timestamp queue or ready signal at this physical boundary.
   constant PTP_RX_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(8);
   constant PTP_RX_MESSAGE_BITS_C : positive := 744;

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

   -- timestamp is calibrated PHC time; ticks/tickPhase remain at the raw
   -- MAC/PCS message point. Their reference-plane difference matters when
   -- reconstructing elapsed time for E2E arithmetic. generation invalidates
   -- work across PHC/configuration changes; it is not a network packet ID.
   -- timeValid reports clock quality and may be false during acquisition.
   -- error instead means this capture cannot represent a usable timestamp.
   type PtpRxCaptureType is record
      timestamp  : slv(95 downto 0);  -- seconds, nanoseconds, Q16 fraction
      ticks      : slv(63 downto 0);
      tickPhase  : slv(2 downto 0);   -- eighths of an unsteered cycle
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
      messageBody        : slv(239 downto 0);  -- first body byte at high end
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

   -- Runtime configuration is committed atomically by PtpReg. Timer units are
   -- unsteered clock cycles; all delay/offset limits are signed Q16 nanoseconds.
   -- Conservative defaults target a 1 Hz source. Tests may select shorter
   -- intervals but must separately qualify the resulting control envelope.
   type PtpConfigType is record
      identityOverride   : sl;
      enable             : sl;
      servoEnable        : sl;
      allowStep          : sl;
      monotonic          : sl;
      domainNumber       : slv(7 downto 0);
      minorVersion       : slv(3 downto 0);
      localIdentity      : slv(79 downto 0);
      sourceIdentity     : slv(79 downto 0);
      delayInterval      : slv(63 downto 0);
      syncTimeout        : slv(63 downto 0);
      associationTimeout : slv(63 downto 0);
      maxDelayAge        : slv(63 downto 0);
      holdoverTimeout    : slv(63 downto 0);
      maxExchange        : slv(63 downto 0);
      minRateSpan        : slv(63 downto 0);
      maxRateAge         : slv(63 downto 0);
      minSampleTicks     : slv(63 downto 0);
      maxSampleTicks     : slv(63 downto 0);
      maxPathDelay       : slv(63 downto 0);
      delayAsymmetry     : slv(63 downto 0);
      stepThreshold      : slv(63 downto 0);
      lockThreshold      : slv(63 downto 0);
      unlockThreshold    : slv(63 downto 0);
      kp                 : slv(31 downto 0);
      ki                 : slv(31 downto 0);
      maxFrequencyPpb    : slv(31 downto 0);
      maxSlewPpb         : slv(31 downto 0);
      maxRatePpb         : slv(31 downto 0);
      lockCount          : slv(7 downto 0);
      unlockCount        : slv(7 downto 0);
      lfsrSeed           : slv(15 downto 0);
   end record;

   constant PTP_CONFIG_INIT_C : PtpConfigType := (
      identityOverride   => '0',
      enable             => '0',
      servoEnable        => '0',
      allowStep          => '1',
      monotonic          => '1',
      domainNumber       => x"00",
      minorVersion       => x"1",
      localIdentity      => x"001122FFFE3344550001",
      sourceIdentity     => x"00000000000000000001",
      delayInterval      => x"0000000009502F90",
      syncTimeout        => x"000000001BF08EB0",
      associationTimeout => x"0000000012A05F20",
      maxDelayAge        => x"000000002540BE40",
      holdoverTimeout    => x"00000002540BE400",
      maxExchange        => x"0000000012A05F20",
      minRateSpan        => x"0000000004A817C8",
      maxRateAge         => x"000000002540BE40",
      minSampleTicks     => x"00000000002540BE",
      maxSampleTicks     => x"0000000012A05F20",
      maxPathDelay       => x"0000000F42400000",
      delayAsymmetry     => (others => '0'),
      stepThreshold      => x"000000004E200000",
      lockThreshold      => x"0000000000640000",
      unlockThreshold    => x"0000000003E80000",
      kp                 => x"10000000",
      ki                 => x"04000000",
      maxFrequencyPpb    => x"000186A0",
      maxSlewPpb         => x"0000C350",
      maxRatePpb         => x"000249F0",
      lockCount          => x"08",
      unlockCount        => x"03",
      lfsrSeed           => x"0001");

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

   function ptpTimeQ16 (timestamp : slv(95 downto 0)) return signed;
   function ptpWireTimeQ16 (timestamp : slv(79 downto 0)) return signed;
   function ptpTickPhase (capture : PtpRxCaptureType) return signed;
   function ptpRoundShift (value : signed;
   bits : natural) return signed;
   function ptpSatInc (value : slv) return slv;

   -- Fixed 744-bit representation used by flattened verification interfaces.
   -- Capture arithmetic errors are rejected before enqueue and are not packed.
   function toSlv (message : PtpRxMessageType) return slv;

   -- Translate a physical word sample to its first destination-MAC byte.
   -- lane is that byte's position (0..7), not the preceding XGMII /S/ lane.
   -- increment is the active unsigned Q32 ns/cycle PHC addend; ticks names
   -- the sampled cycle. GMII supplies lane zero. ingressLatency is signed
   -- Q16 ns and must be an elaboration-time value at the current call sites.
   function ptpRxCapture (
      phcTime : PtpTimeType;
      increment : slv(63 downto 0);
      lane : natural;
      ticks : slv(63 downto 0);
      generation : slv(31 downto 0);
      timeValid : sl;
      constant ingressLatency : slv(63 downto 0)) return PtpRxCaptureType;

end package PtpPkg;

package body PtpPkg is

   function ptpTimeQ16 (timestamp : slv(95 downto 0)) return signed is
      variable whole : unsigned(79 downto 0);
   begin
      whole := unsigned(timestamp(95 downto 48))*to_unsigned(1000000000, 32) +
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

   function ptpRoundShift (value : signed;
   bits : natural) return signed is
      variable magnitude   : unsigned(value'length downto 0);
      variable resultValue : signed(value'length downto 0);
   begin
      resultValue := resize(value, value'length+1);
      magnitude := unsigned(abs(resultValue));
      if bits /= 0 then
         magnitude := shift_right(magnitude + shift_left(to_unsigned(1, magnitude'length), bits-1), bits);
      end if;
      resultValue := signed(magnitude);
      if value(value'high) = '1' then
         resultValue := -resultValue;
      end if;
      return resize(resultValue, value'length);
   end function;

   function ptpSatInc (value : slv) return slv is
   begin
      if unsigned(value) = (value'range => '1') then
         return value;
      end if;
      return slv(unsigned(value)+1);
   end function;

   function ptpNominalIncrement (frequency : positive) return slv is
      constant NUMERATOR_C : unsigned(63 downto 0) := shift_left(to_unsigned(1000000000, 64), 32);

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

   function ptpRxCapture (
      phcTime : PtpTimeType;
      increment : slv(63 downto 0);
      lane : natural;
      ticks : slv(63 downto 0);
      generation : slv(31 downto 0);
      timeValid : sl;
      constant ingressLatency : slv(63 downto 0)) return PtpRxCaptureType is
      -- Split the elaboration-time latency into whole seconds and a signed
      -- remainder smaller than one second. VHDL rem preserves the dividend's
      -- sign, allowing the same subtraction for positive and negative latency.
      -- Current callers pass a generic; never make this a runtime divider by
      -- substituting a changing calibration input without redesigning the path.
      constant SECOND_Q16_C  : signed(63 downto 0) := shift_left(to_signed(1000000000, 64), 16);
      constant SECOND_Q32_C  : signed(66 downto 0) := shift_left(to_signed(1000000000, 67), 32);
      constant LAT_SECONDS_C : signed(63 downto 0) := signed(ingressLatency) / SECOND_Q16_C;
      constant LAT_REMAIN_C  : signed(63 downto 0) := signed(ingressLatency) rem SECOND_Q16_C;

      variable retVar   : PtpRxCaptureType := PTP_RX_CAPTURE_INIT_C;
      variable ns       : signed(66 downto 0);
      variable sec      : signed(64 downto 0);
      variable subCycle : unsigned(66 downto 0);
   begin
      -- Scale the byte phase with the active PHC rate, rather than assuming a
      -- fixed 0.8 ns XGMII byte. Widen before arithmetic and retain Q32 precision
      -- through calibration; a positive ingress latency moves time earlier.
      subCycle := shift_right(unsigned(increment) * to_unsigned(lane, 3), 3);
      ns := signed(resize(unsigned(slv'(phcTime.nanoseconds & phcTime.fraction)), 67)) +
         signed(subCycle) - shift_left(resize(LAT_REMAIN_C, 67), 16);
      sec := signed(resize(unsigned(phcTime.seconds), 65)) - resize(LAT_SECONDS_C, 65);
      -- Canonical input and the supported Ethernet-clock addend need at most
      -- one carry/borrow after subtracting the sub-second latency remainder.
      if ns < 0 then
         ns := ns + SECOND_Q32_C;
         sec := sec - 1;
      elsif ns >= SECOND_Q32_C then
         ns := ns - SECOND_Q32_C;
         sec := sec + 1;
      end if;
      -- Reject an out-of-range epoch or failed normalization. Truncating the
      -- seconds field alone would wrap a negative capture into a distant future.
      if sec < 0 or shift_right(sec, 48) /= 0 or ns < 0 or ns >= SECOND_Q32_C then
         retVar.error := '1';
      end if;
      -- Discard the low sixteen fractional bits only after normalization.
      -- Raw tick provenance is intentionally unaffected by ingress latency.
      retVar.timestamp := slv(sec(47 downto 0)) & slv(ns(63 downto 16));
      retVar.ticks := ticks;
      retVar.tickPhase := slv(to_unsigned(lane, 3));
      retVar.generation := generation;
      retVar.increment := increment;
      retVar.timeValid := timeValid;
      return retVar;
   end function;

end package body PtpPkg;
