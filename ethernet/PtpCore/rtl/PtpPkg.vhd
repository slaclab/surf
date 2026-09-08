-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PTP receive proof types and fixed capture arithmetic
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

   -- This package currently covers the RX slice, not the complete port/servo.
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
      seconds => (others => '0'), nanoseconds => (others => '0'), fraction => (others => '0'));

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
      timeValid  : sl;
      error      : sl;               -- arithmetic range failure; never admitted
   end record;
   constant PTP_RX_CAPTURE_INIT_C : PtpRxCaptureType := (
      timestamp => (others => '0'), ticks => (others => '0'), tickPhase => (others => '0'),
      generation => (others => '0'), timeValid => '0', error => '0');

   -- One queue item owns both the validated frame fields and its SOF capture.
   -- Multibyte fields use network significance (first octet at the high end),
   -- unlike the AXI byte lanes. The fixed message body excludes TLVs, padding,
   -- and FCS; unused low body bytes are zero. Source/profile policy and body
   -- interpretation remain the port's responsibility after structural checks.
   -- rxEpoch identifies local queue invalidation independently of the PHC
   -- generation, so RX overflow does not imply a PHC discontinuity.
   type PtpRxMessageType is record
      capture           : PtpRxCaptureType;
      rxEpoch           : slv(31 downto 0);
      destination       : slv(47 downto 0);
      sourcePortIdentity : slv(79 downto 0);
      sequenceId        : slv(15 downto 0);
      domainNumber      : slv(7 downto 0);
      messageType       : slv(3 downto 0);
      minorVersion      : slv(3 downto 0);
      transportSpecific : slv(3 downto 0);
      messageLength     : slv(15 downto 0);
      flags             : slv(15 downto 0);
      correction        : slv(63 downto 0); -- signed Q16 ns, wire bit pattern
      control           : slv(7 downto 0);
      logInterval       : slv(7 downto 0);  -- signed wire bit pattern
      messageBody              : slv(239 downto 0); -- first body byte at high end
   end record;
   constant PTP_RX_MESSAGE_INIT_C : PtpRxMessageType := (
      capture => PTP_RX_CAPTURE_INIT_C, rxEpoch => (others => '0'),
      destination => (others => '0'), sourcePortIdentity => (others => '0'),
      sequenceId => (others => '0'), domainNumber => (others => '0'),
      messageType => (others => '0'), minorVersion => (others => '0'),
      transportSpecific => (others => '0'), messageLength => (others => '0'),
      flags => (others => '0'), correction => (others => '0'), control => (others => '0'),
      logInterval => (others => '0'), messageBody => (others => '0'));
   type PtpRxMessageArray is array (natural range <>) of PtpRxMessageType;

   -- Fixed 744-bit representation used by flattened verification interfaces.
   -- Capture arithmetic errors are rejected before enqueue and are not packed.
   function toSlv (message : PtpRxMessageType) return slv;

   -- Translate a physical word sample to its first destination-MAC byte.
   -- lane is that byte's position (0..7), not the preceding XGMII /S/ lane.
   -- increment is the active unsigned Q32 ns/cycle PHC addend; ticks names
   -- the sampled cycle. GMII supplies lane zero. ingressLatency is signed
   -- Q16 ns and must be an elaboration-time value at the current call sites.
   function ptpRxCapture (
      phcTime : PtpTimeType; increment : slv(63 downto 0); lane : natural;
      ticks : slv(63 downto 0); generation : slv(31 downto 0); timeValid : sl;
      constant ingressLatency : slv(63 downto 0)) return PtpRxCaptureType;

end package PtpPkg;

package body PtpPkg is

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
      phcTime : PtpTimeType; increment : slv(63 downto 0); lane : natural;
      ticks : slv(63 downto 0); generation : slv(31 downto 0); timeValid : sl;
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
      variable retVar        : PtpRxCaptureType := PTP_RX_CAPTURE_INIT_C;
      variable ns            : signed(66 downto 0);
      variable sec           : signed(64 downto 0);
      variable subCycle      : unsigned(66 downto 0);
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
      retVar.timeValid := timeValid;
      return retVar;
   end function;

end package body PtpPkg;
