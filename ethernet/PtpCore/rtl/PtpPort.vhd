-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Fixed-source two-step Layer-2 PTP TimeReceiver protocol engine.
--
-- Consumes structurally validated RX records and applies the configured
-- source, domain and profile policy to Sync, Follow_Up, Delay_Resp and
-- Announce. Four bounded Sync/Follow_Up slots accept either arrival order and
-- reject conflicting associations. Completed Sync history supplies the sample
-- nearest an actual Delay_Req TX capture; Announce metadata and raw-tick
-- receipt timers qualify the current source session.
--
-- Estimates master time per raw local cycle from corrected Sync intervals,
-- independently of PHC validity or steering. Qualified intervals establish and
-- filter the rate ratio used by PtpE2e. The port publishes forward
-- measurements and serialized end-to-end path-delay results to PtpServo,
-- retaining generation and sequence provenance.
--
-- Schedules randomized Delay_Req intervals, reserves each wire key in
-- PtpTxLedger before presenting a frame, and builds the private eight-byte SSI
-- TX stream. The ledger joins physical TX completion with Delay_Resp in either
-- order. An already presented frame remains stable under backpressure and
-- drains across logical restart; protocol cancellation invalidates
-- measurements without forgetting unresolved MAC transmissions.
--
-- Implements a configured upstream source rather than BMCA. This endpoint
-- profile supports untagged multicast Layer-2 two-step E2E traffic; UDP, VLAN,
-- one-step Sync and peer-delay operation are outside its scope.
--
-- The local AXI-Lite bank owns identity/domain shadows, protocol timers,
-- rate-estimation limits and path-delay acceptance policy. configControl.prepare
-- freezes a candidate independently of subsequent software writes; validation
-- votes and configControl.apply let PtpEndpoint activate all banks on the same edge.
-- MAC-derived local identity is refreshed on apply or a MAC-address change,
-- which also requests protocol restart without discarding wire ownership.
--
-- Announce, exchange and protocol/RX counter snapshots are stored here on the
-- common capture strobe and tagged with its sequence. The servo consumes the
-- authoritative active associationTimeout, syncTimeout and maxPathDelay via
-- sharedConfig; it has no independently writable copies of these settings.
-- Register state and protocol state use one RegType/comb/seq pair. regRst
-- clears bus responses only, while restart preserves configuration and the TX
-- ledger lifetime. Measurement data/valid/abort and reverse-direction ready
-- use registered forward measurement records. PtpPortLifecycleType carries registered
-- command cancellation and identity restart; PtpPortStatusType owns registered
-- diagnostics. The AXI snapshot bank freezes pre-edge state independently of
-- live reporting. Active local registers are the sole configuration source;
-- PtpEndpoint coordinates their common prepare/validate/apply transaction.
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
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.PtpPkg.all;

entity PtpPort is
   generic (
      TPD_G             : time             := 1 ns;
      RST_POLARITY_G    : sl               := '1';
      RST_ASYNC_G       : boolean          := false;
      CLK_FREQ_G        : positive         := 156250000;
      PACKET_LIFETIME_G : positive         := 156250000;
      INGRESS_LATENCY_G : slv(63 downto 0) := (others => '0');
      EGRESS_LATENCY_G  : slv(63 downto 0) := (others => '0'));
   port (
      clk                 : in  sl;
      rst                 : in  sl;
      -- Local AXI-Lite bank and endpoint coordination (clk domain).
      regRst           : in  sl                     := '0';
      axiReadMaster    : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axiReadSlave     : out AxiLiteReadSlaveType;
      axiWriteMaster   : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axiWriteSlave    : out AxiLiteWriteSlaveType;
      configControl    : in  PtpConfigControlType   := PTP_CONFIG_CONTROL_INIT_C;
      snapshotControl  : in  PtpSnapshotControlType := PTP_SNAPSHOT_CONTROL_INIT_C;
      configValid      : out sl;
      enable           : in  sl                     := '0';
      rxCounters       : in  PtpRxCountersType      := PTP_RX_COUNTERS_INIT_C;
      sharedConfig     : out PtpSharedConfigType;
      -- Protocol/clock interface.
      restart             : in  sl;
      linkReady           : in  sl;
      macResetDone        : in  sl;
      localMac            : in  slv(47 downto 0);
      phcStatus           : in  PtpPhcStatusType;
      captureAbort        : in  sl;
      rxMessage           : in  PtpRxMessageType;
      rxValid             : in  sl;
      rxReady             : out sl;
      rxQueueOverflow     : in  sl := '0';
      rxAbort             : in  sl;
      txMessage           : in  PtpRxMessageType;
      txValid             : in  sl;
      txAbort             : in  sl;
      txMaster            : out AxiStreamMasterType;
      txSlave             : in  AxiStreamSlaveType;
      measurementMaster   : out PtpMeasurementMasterType;
      measurementSlave    : in  PtpMeasurementSlaveType;
      lifecycle           : out PtpPortLifecycleType;
      status              : out PtpPortStatusType);
end entity PtpPort;

architecture rtl of PtpPort is

   constant PAIR_DEPTH_C    : positive := 4;
   constant HISTORY_DEPTH_C : positive := 4;

   -- Existing implementation admission floor, in raw cycles. Its original
   -- latency budget is not documented; retain it pending timing qualification.
   constant MIN_ASSOCIATION_TICKS_C : positive := 2048;
   -- Raw oscillator qualification envelope, independent of servo actuation.
   constant MAX_OSCILLATOR_PPB_C  : positive := 200000; -- 200 ppm.
   constant RATIO_QUALIFY_COUNT_C : positive := 2;
   constant RATIO_FILTER_SHIFT_C  : positive := 2; -- One-quarter new estimate.
   -- Supported profile interval policy: roughly 1 ms through 48.5 days.
   -- These are admission bounds, not the representable signed wire range.
   constant MIN_LOG_INTERVAL_C : integer := -10;
   constant MAX_LOG_INTERVAL_C : integer := 22;
   -- Receipt timeout spans three advertised intervals; Announce uses twice
   -- the configured Sync receipt cap.
   constant RECEIPT_INTERVALS_C   : positive         := 3;
   constant ANNOUNCE_CAP_FACTOR_C : positive         := 2;
   constant LFSR_SEED_C           : slv(15 downto 0) := PTP_PORT_CONFIG_INIT_C.lfsrSeed;

   -- Untagged Delay_Req, excluding MAC-supplied padding and FCS.
   constant TX_FRAME_BYTES_C : positive := PTP_ETH_HEADER_BYTES_C+PTP_TIMESTAMP_MSG_BYTES_C;
   constant TX_BEAT_BYTES_C  : positive := PTP_RX_AXIS_CONFIG_C.TDATA_BYTES_C;
   constant TX_LAST_BEAT_C   : natural := (TX_FRAME_BYTES_C-1)/TX_BEAT_BYTES_C;
   constant TX_LAST_BYTES_C  : positive := TX_FRAME_BYTES_C-TX_LAST_BEAT_C*TX_BEAT_BYTES_C;
   constant TX_LAST_KEEP_C   : slv(TX_BEAT_BYTES_C-1 downto 0) := toSlv(2**TX_LAST_BYTES_C-1, TX_BEAT_BYTES_C);

   function initialConfig return PtpPortConfigType is
      variable v      : PtpPortConfigType     := PTP_PORT_CONFIG_INIT_C;
      constant TICK_C : unsigned(63 downto 0) := to_unsigned(CLK_FREQ_G, 64);

   begin
      v.delayInterval      := slv(TICK_C);               -- 1 s before jitter.
      v.syncTimeout        := slv(resize(TICK_C*3, 64));  -- 3 s.
      v.associationTimeout := slv(resize(TICK_C*2, 64));  -- 2 s.
      v.maxExchange        := slv(resize(TICK_C*2, 64));  -- 2 s.
      v.minRateSpan        := slv(TICK_C/2);             -- 0.5 s, rounded down to ticks.
      v.maxRateAge         := slv(resize(TICK_C*4, 64));  -- 4 s.
      return v;
   end function;

   -- Validate the same pre-edge shadows captured by prepare.
   function validConfig (cfg : PtpPortConfigType) return boolean is
   begin
      -- Identity and protocol selection.
      if unsigned(cfg.minorVersion) > unsigned(PTP_MINOR_VERSION_MAX_C) then
         return false;
      end if;
      if unsigned(cfg.localIdentity(15 downto 0)) = 0 or
         unsigned(cfg.sourceIdentity(15 downto 0)) = 0 then
         return false;
      end if;

      -- Physical and association limits.
      if signed(cfg.maxPathDelay) <= 0 then
         return false;
      end if;
      if unsigned(cfg.associationTimeout) < MIN_ASSOCIATION_TICKS_C then
         return false;
      end if;
      if unsigned(cfg.maxRateAge) < unsigned(cfg.minRateSpan) then
         return false;
      end if;

      -- Every timeout must fit the supported unsigned-difference range.
      if not ptpValidTimeout(cfg.delayInterval) then
         return false;
      end if;
      if not ptpValidTimeout(cfg.syncTimeout) then
         return false;
      end if;
      if not ptpValidTimeout(cfg.associationTimeout) then
         return false;
      end if;
      if not ptpValidTimeout(cfg.maxExchange) then
         return false;
      end if;
      if not ptpValidTimeout(cfg.minRateSpan) then
         return false;
      end if;
      if not ptpValidTimeout(cfg.maxRateAge) then
         return false;
      end if;
      return true;
   end function;

   -- Q16 elapsed master ns / Q3 elapsed raw cycles -> Q48 ns/cycle.
   constant RATE_RATIO_SHIFT_C : natural := PTP_RATIO_FRAC_BITS_C+PTP_TICK_PHASE_BITS_C-PTP_TIME_FRAC_BITS_C;
   constant NOMINAL_C          : unsigned(63 downto 0) := shift_left(unsigned(ptpNominalIncrement(CLK_FREQ_G)), PTP_PHC_TO_RATIO_SHIFT_C);
   constant RATE_MARGIN_C      : unsigned(63 downto 0) := resize((resize(NOMINAL_C, 96)*to_unsigned(MAX_OSCILLATOR_PPB_C, 32))/to_unsigned(PTP_PPB_SCALE_C, 128), 64);

   type PairType is record
      used             : sl;
      syncSeen         : sl;
      followSeen       : sl;
      complete         : sl;
      born             : slv(63 downto 0);
      syncCorrection   : slv(63 downto 0);
      followCorrection : slv(63 downto 0);
      sample           : PtpSyncSampleType;
   end record;

   constant PAIR_INIT_C : PairType := (
      used             => '0',
      syncSeen         => '0',
      followSeen       => '0',
      complete         => '0',
      born             => (others => '0'),
      syncCorrection   => (others => '0'),
      followCorrection => (others => '0'),
      sample           => PTP_SYNC_SAMPLE_INIT_C);

   type PairArray is array (0 to PAIR_DEPTH_C-1) of PairType;
   type StateType is (
      IDLE_S,
      RATE_ISSUE_S,
      RATE_WAIT_S);

   type RegType is record
      -- Current-edge admission for RX, ledger samples and E2E results.
      rxReady             : sl;
      delayReady          : sl;
      e2eTake             : sl;
      -- Live diagnostic state; AXI snapshots below have a separate lifetime.
      portStatus          : PtpPortStatusType;

      -- Local management state shares the core reset and register process.
      readSlave           : AxiLiteReadSlaveType;
      writeSlave          : AxiLiteWriteSlaveType;
      shadow              : PtpPortConfigType;
      candidate           : PtpPortConfigType;
      configValid         : sl;
      activeConfig        : PtpPortConfigType;
      lastMac             : slv(47 downto 0);
      sequenceId          : slv(31 downto 0);
      snapExchange        : PtpExchangeType;
      snapAnnounce        : slv(239 downto 0);
      snapGm              : slv(63 downto 0);
      snapFlags           : slv(15 downto 0);
      snapUtc             : slv(15 downto 0);
      snapCounters        : Slv32Array(0 to 6);
      pairs               : PairArray;
      history             : PtpSyncSampleArray(0 to HISTORY_DEPTH_C-1);
      historyValid        : slv(HISTORY_DEPTH_C-1 downto 0);
      historyPtr          : natural range 0 to HISTORY_DEPTH_C-1;
      generation          : slv(31 downto 0);
      -- Last accepted sample retained for waveform diagnostics.
      lastSync            : PtpSyncSampleType;
      lastRemote          : signed(127 downto 0);
      syncLimit           : slv(63 downto 0);
      announceLimit       : slv(63 downto 0);
      lastTicks           : slv(63 downto 0);
      anchor              : PtpSyncSampleType;
      anchorValid         : sl;
      ratio               : slv(63 downto 0);
      ratioCount          : natural range 0 to RATIO_QUALIFY_COUNT_C;
      ratioTicks          : slv(63 downto 0);
      state               : StateType;
      rateInput           : sl;
      rateA               : slv(127 downto 0);
      rateB               : slv(127 downto 0);
      pendingSync         : PtpSyncSampleType;
      measurementMaster   : PtpMeasurementMasterType;
      lifecycle           : PtpPortLifecycleType;
      allocate            : sl;
      response            : PtpRxMessageType;
      responseValid       : sl;
      responseLog         : slv(7 downto 0);
      e2eInput            : sl;
      e2eBusy             : sl;
      e2eSync             : PtpSyncSampleType;
      e2eDelay            : PtpDelaySampleType;
      e2eRatio            : slv(63 downto 0);
      e2eMaximum          : slv(63 downto 0);
      master              : AxiStreamMasterType;
      frame               : slv(8*TX_FRAME_BYTES_C-1 downto 0);
      beat                : natural range 0 to TX_LAST_BEAT_C;
      lastRequest         : slv(63 downto 0);
      requestInterval     : unsigned(63 downto 0);
      minimumInterval     : unsigned(63 downto 0);
      requestStarted      : sl;
      lfsr                : slv(15 downto 0);
      pendingExchange     : PtpExchangeType;
      announceSeen        : sl;
      announceTicks       : slv(63 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      rxReady             => '0',
      delayReady          => '0',
      e2eTake             => '0',
      portStatus          => PTP_PORT_STATUS_INIT_C,
      readSlave           => AXI_LITE_READ_SLAVE_INIT_C,
      writeSlave          => AXI_LITE_WRITE_SLAVE_INIT_C,
      shadow              => initialConfig,
      candidate           => initialConfig,
      configValid         => toSl(validConfig(initialConfig)),
      activeConfig        => initialConfig,
      lastMac             => (others => '0'),
      sequenceId          => (others => '0'),
      snapExchange        => PTP_EXCHANGE_INIT_C,
      snapAnnounce        => (others => '0'),
      snapGm              => (others => '0'),
      snapFlags           => (others => '0'),
      snapUtc             => (others => '0'),
      snapCounters        => (others => (others => '0')),
      pairs               => (others => PAIR_INIT_C),
      history             => (others => PTP_SYNC_SAMPLE_INIT_C),
      historyValid        => (others => '0'),
      historyPtr          => 0,
      generation          => (others => '0'),
      lastSync            => PTP_SYNC_SAMPLE_INIT_C,
      lastRemote          => (others => '0'),
      lastTicks           => (others => '0'),
      syncLimit           => (others => '0'),
      announceLimit       => (others => '0'),
      anchor              => PTP_SYNC_SAMPLE_INIT_C,
      anchorValid         => '0',
      ratio               => slv(NOMINAL_C),
      ratioCount          => 0,
      ratioTicks          => (others => '0'),
      state               => IDLE_S,
      rateInput           => '0',
      rateA               => (others => '0'),
      rateB               => (others => '0'),
      pendingSync         => PTP_SYNC_SAMPLE_INIT_C,
      measurementMaster   => PTP_MEASUREMENT_MASTER_INIT_C,
      lifecycle           => PTP_PORT_LIFECYCLE_INIT_C,
      allocate            => '0',
      response            => PTP_RX_MESSAGE_INIT_C,
      responseValid       => '0',
      responseLog         => (others => '0'),
      e2eInput            => '0',
      e2eBusy             => '0',
      e2eSync             => PTP_SYNC_SAMPLE_INIT_C,
      e2eDelay            => PTP_DELAY_SAMPLE_INIT_C,
      e2eRatio            => (others => '0'),
      e2eMaximum          => (others => '0'),
      master              => AXI_STREAM_MASTER_INIT_C,
      frame               => (others => '0'),
      beat                => 0,
      lastRequest         => (others => '0'),
      requestInterval     => (others => '0'),
      minimumInterval     => (others => '0'),
      requestStarted      => '0',
      lfsr                => LFSR_SEED_C,
      pendingExchange     => PTP_EXCHANGE_INIT_C,
      announceSeen        => '0',
      announceTicks       => (others => '0'));

   signal r                : RegType := REG_INIT_C;
   signal rin              : RegType;
   signal abortNow         : sl;
   signal responseAccepted : sl;
   signal responseValid    : sl;
   signal allocate         : sl;
   signal allocateReady    : sl;
   signal allocateSequence : slv(15 downto 0);
   signal delaySample      : PtpDelaySampleType;
   signal delayValid       : sl;
   signal delayReady       : sl;
   signal ledgerRejected   : slv(31 downto 0);
   signal rateInput        : sl;
   signal rateReady        : sl;
   signal rateResultValid  : sl;
   signal rateResult       : slv(127 downto 0);
   signal rateError        : sl;
   signal e2eInput         : sl;
   signal e2eReady         : sl;
   signal e2eSync          : PtpSyncSampleType;
   signal e2eResult        : PtpMeasurementType;
   signal e2eValid         : sl;
   signal e2eTake          : sl;
   signal e2eError         : sl;

   -- Prefer an existing sequence association, then an unused slot, then the
   -- oldest completed slot. The caller retires expired entries before searching.
   function findPair (pairs : PairArray; sequenceId : slv(15 downto 0)) return integer is
      variable matched  : integer range -1 to PAIR_DEPTH_C-1;
      variable reusable : integer range -1 to PAIR_DEPTH_C-1;
   begin
      matched  := -1;
      reusable := -1;
      for i in pairs'range loop
         if pairs(i).used = '0' and reusable = -1 then
            reusable := i;
         elsif pairs(i).used = '1' and pairs(i).sample.sequenceId = sequenceId then
            matched := i;
         end if;
      end loop;
      if matched /= -1 then
         return matched;
      end if;
      if reusable = -1 then
         for i in pairs'range loop
            if pairs(i).complete = '1' then
               if reusable = -1 then
                  reusable := i;
               elsif unsigned(pairs(i).born) < unsigned(pairs(reusable).born) then
                  reusable := i;
               end if;
            end if;
         end loop;
      end if;
      return reusable;
   end function;

   function completedPair (pairs : PairArray) return integer is
   begin
      for i in pairs'range loop
         if pairs(i).syncSeen = '1' and pairs(i).followSeen = '1' and pairs(i).complete = '0' then
            return i;
         end if;
      end loop;
      return -1;
   end function;

   -- Select by capture phase, not delivery time. Equal distances retain the
   -- first history entry; a Sync just after the TX capture is also eligible.
   function nearestSync (history : PtpSyncSampleArray(0 to HISTORY_DEPTH_C-1);
   historyValid : slv(HISTORY_DEPTH_C-1 downto 0); sample : PtpDelaySampleType;
   ticks : slv(63 downto 0); cfg : PtpPortConfigType) return integer is
      variable selected : integer range -1 to HISTORY_DEPTH_C-1;
      variable distance : signed(127 downto 0);
      variable nearest  : signed(127 downto 0);
   begin
      selected     := -1;
      nearest      := (others => '1');
      nearest(127) := '0';
      for i in history'range loop
         distance := abs(ptpTickPhase(sample.capture)-ptpTickPhase(history(i).capture));
         if historyValid(i) = '1' and distance < nearest and
            history(i).capture.generation = sample.generation and
            distance <= shift_left(signed(resize(unsigned(cfg.maxExchange), 128)), PTP_TICK_PHASE_BITS_C) and
            unsigned(ticks)-unsigned(history(i).capture.ticks) <= unsigned(cfg.associationTimeout) then
            selected := i;
            nearest  := distance;
         end if;
      end loop;
      return selected;
   end function;

   -- Supported log2(seconds) range; 0x7F means unspecified on the wire.
   function validLogInterval (logInterval : slv(7 downto 0)) return boolean is
   begin
      return signed(logInterval) >= MIN_LOG_INTERVAL_C and signed(logInterval) <= MAX_LOG_INTERVAL_C;
   end function;

   -- Announce uses the general-message control value. Leap flags are mutually
   -- exclusive, and the upper flag octet is reserved for this endpoint profile.
   function validAnnounce (message : PtpRxMessageType) return boolean is
   begin
      return message.control = PTP_CONTROL_OTHER_C and
         (message.flags and PTP_LEAP_FLAGS_MASK_C) /= PTP_LEAP_FLAGS_MASK_C and
         (message.flags and PTP_GENERAL_RESERVED_C) = x"0000";
   end function;

   function intervalTicks (logInterval : slv(7 downto 0);
   fallback : slv(63 downto 0)) return unsigned is
      variable exponent : integer range -128 to 127;
      variable value    : unsigned(63 downto 0);
   begin
      exponent := to_integer(signed(logInterval));
      value    := to_unsigned(CLK_FREQ_G, 64);
      if exponent < MIN_LOG_INTERVAL_C or exponent > MAX_LOG_INTERVAL_C then
         return unsigned(fallback);
      elsif exponent < 0 then
         return shift_right(value, -exponent);
      end if;
      return shift_left(value, exponent);
   end function;

   -- Three advertised intervals, capped by the configured raw-tick timeout.
   -- Invalid/unspecified intervals use the cap; rejection accounting stays at
   -- the message handler because an invalid interval need not reject its data.
   function receiptTimeout (logInterval : slv(7 downto 0);
   limit : slv(63 downto 0)) return slv is
      variable ticks : unsigned(63 downto 0);
   begin
      if validLogInterval(logInterval) then
         ticks := intervalTicks(logInterval, limit);
         ticks := resize(ticks*RECEIPT_INTERVALS_C, ticks'length);
         if ticks < unsigned(limit) then
            return slv(ticks);
         end if;
      end if;
      return limit;
   end function;

   function buildRequest (cfg : PtpPortConfigType;
   mac : slv(47 downto 0);
   seqId : slv(15 downto 0)) return slv is
      constant MESSAGE_LENGTH_C : slv(15 downto 0) := toSlv(PTP_TIMESTAMP_MSG_BYTES_C, 16);
      variable bytes            : Slv8Array(0 to TX_FRAME_BYTES_C-1) := (others => (others => '0'));
      variable resultValue      : slv(8*TX_FRAME_BYTES_C-1 downto 0);

   begin
      -- Ethernet header, bytes 0..13. Destination uses network significance;
      -- the SURF source MAC stores its first wire octet in the low byte.
      for i in 0 to 5 loop
         bytes(i)   := PTP_PRIMARY_MULTICAST_MAC_C(47-8*i downto 40-8*i);
         bytes(6+i) := mac(8*i+7 downto 8*i);
      end loop;
      bytes(12) := PTP_ETH_TYPE_C(15 downto 8);  -- EtherType, high octet first.
      bytes(13) := PTP_ETH_TYPE_C(7 downto 0);

      -- PTP common header, bytes 14..47. Explicit wire positions keep this
      -- encoder readable; protocol values and message sizes remain named.
      bytes(14) := PTP_TRANSPORT_SPECIFIC_C & PTP_MSG_DELAY_REQ_C;  -- transportSpecific/messageType.
      bytes(15) := cfg.minorVersion & PTP_MAJOR_VERSION_C;         -- minorVersionPTP/versionPTP.
      bytes(16) := MESSAGE_LENGTH_C(15 downto 8);                  -- messageLength.
      bytes(17) := MESSAGE_LENGTH_C(7 downto 0);
      bytes(18) := cfg.domainNumber;                              -- domainNumber.

      -- sourcePortIdentity, bytes 34..43, high octet first.
      for i in 0 to 9 loop
         bytes(34+i) := cfg.localIdentity(79-8*i downto 72-8*i);
      end loop;
      bytes(44) := seqId(15 downto 8);               -- sequenceId.
      bytes(45) := seqId(7 downto 0);
      bytes(46) := PTP_CONTROL_DELAY_REQ_C;          -- controlField.
      bytes(47) := PTP_LOG_INTERVAL_UNSPECIFIED_C;   -- logMessageInterval.

      -- Reserved fields, flags, correctionField and originTimestamp (48..57)
      -- retain their zero initialization. Pack into low-byte-first AXI lanes.
      for i in bytes'range loop
         resultValue(8*i+7 downto 8*i) := bytes(i);
      end loop;
      return resultValue;
   end function;

   function forwardMeasurement (item : PtpSyncSampleType) return PtpMeasurementType is
      variable resultValue : PtpMeasurementType := PTP_MEASUREMENT_INIT_C;
   begin
      resultValue.generation   := item.capture.generation;
      resultValue.ticks        := item.capture.ticks;
      resultValue.syncSequence := item.sequenceId;
      resultValue.forward      := slv(ptpTimeQ16(item.capture.timestamp)-ptpWireTimeQ16(item.remoteTime)-signed(item.correction));
      return resultValue;
   end function;

   signal ledgerStatus : slv(31 downto 0);
   signal timeoutCount : slv(31 downto 0);

begin

   U_Ledger : entity surf.PtpTxLedger
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         PACKET_LIFETIME_G => PACKET_LIFETIME_G)
      port map (
         clk              => clk,                   -- [in]
         rst              => rst,                   -- [in]
         restart          => abortNow,              -- [in]
         macResetDone     => macResetDone,          -- [in]
         ticks            => phcStatus.ticks,       -- [in]
         generation       => phcStatus.generation,  -- [in]
         config           => r.activeConfig,        -- [in]
         allocate         => allocate,              -- [in]
         allocateReady    => allocateReady,         -- [out]
         allocateSequence => allocateSequence,      -- [out]
         wireMessage      => txMessage,             -- [in]
         wireValid        => txValid,               -- [in]
         response         => r.response,             -- [in]
         responseValid    => responseValid,         -- [in]
         sample           => delaySample,           -- [out]
         sampleValid      => delayValid,            -- [out]
         sampleReady      => delayReady,            -- [in]
         timeoutCount     => timeoutCount,          -- [out]
         ledgerStatus     => ledgerStatus,          -- [out]
         responseAccepted => responseAccepted,      -- [out]
         rejectedCount    => ledgerRejected);       -- [out]

   U_RateMath : entity surf.PtpMath
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk             => clk,              -- [in]
         rst             => rst,              -- [in]
         cancel          => abortNow,         -- [in]
         inputValid      => rateInput,        -- [in]
         inputReady      => rateReady,        -- [out]
         divide          => '1',              -- [in]
         roundNearest    => '1',              -- [in]
         operandA        => r.rateA,          -- [in]
         operandB        => r.rateB,          -- [in]
         resultValid     => rateResultValid,  -- [out]
         resultReady     => '1',              -- [in]
         resultValue     => rateResult,       -- [out]
         resultRemainder => open,             -- [out]
         resultError     => rateError);       -- [out]

   U_E2e : entity surf.PtpE2e
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         INGRESS_LATENCY_G => INGRESS_LATENCY_G,
         EGRESS_LATENCY_G  => EGRESS_LATENCY_G)
      port map (
         clk          => clk,                          -- [in]
         rst          => rst,                          -- [in]
         cancel       => abortNow,                     -- [in]
         inputValid   => e2eInput,                     -- [in]
         inputReady   => e2eReady,                     -- [out]
         syncSample   => e2eSync,                      -- [in]
         delaySample  => r.e2eDelay,                  -- [in]
         ratio        => r.e2eRatio,                      -- [in]
         maxPathDelay => r.e2eMaximum,  -- [in]
         resultValue  => e2eResult,                    -- [out]
         resultValid  => e2eValid,                     -- [out]
         resultReady  => e2eTake,                      -- [in]
         resultError  => e2eError);                    -- [out]

   comb : process (r, rst, regRst, axiReadMaster, axiWriteMaster, configControl, snapshotControl,
                   enable, rxCounters, restart, linkReady, localMac, phcStatus, captureAbort, rxMessage,
                   rxValid, rxQueueOverflow, rxAbort, txAbort, txSlave, measurementSlave,
                   responseAccepted, allocateReady, allocateSequence, delaySample, delayValid,
                   rateReady, rateResultValid, rateResult, rateError, e2eReady, e2eResult, e2eValid,
                   e2eError, ledgerStatus, timeoutCount) is
      variable v  : RegType;
      variable ep : AxiLiteEndpointType;

      -- Same-edge admission/cancellation decisions.
      variable announceChange : sl;
      variable externalAbort  : sl;
      variable abortPort      : sl;
      variable policyValid    : sl;
      variable qualifiedRatio : sl;
      variable validResponse  : sl;
      variable malformed      : boolean;

      -- Bounded table searches (-1 means no match) and timestamp arithmetic.
      variable slot          : integer range -1 to PAIR_DEPTH_C-1;
      variable completed     : integer range -1 to PAIR_DEPTH_C-1;
      variable selected      : integer range -1 to HISTORY_DEPTH_C-1;
      variable remoteTime    : signed(127 downto 0);
      variable rateSpan      : signed(127 downto 0);
      variable completedSync : PtpSyncSampleType;
   begin
      v := r;

      -- Requests retain their complete payload until the child accepts them.
      -- The response lane accepts one RX message per clock and returns its
      -- registered acceptance one edge later; delay the log interval with it.
      v.responseValid := '0';
      v.responseLog   := r.response.logInterval;
      if r.e2eInput = '1' and e2eReady = '1' then
         v.e2eInput := '0';
      end if;
      v.delayReady := '0';
      v.e2eTake    := '0';
      v.generation := phcStatus.generation;
      if r.measurementMaster.valid = '1' and measurementSlave.ready = '1' then
         v.measurementMaster.valid := '0';
      end if;

      -------------------------------------------------------------------------
      -- Local lifecycle decisions and RX admission
      -------------------------------------------------------------------------
      -- First check Ethernet/PTP identity, then capture provenance and age.
      -- A rejected record is still consumed below and counted as a rejection.
      policyValid := '1';
      if rxMessage.destination /= PTP_PRIMARY_MULTICAST_MAC_C then
         policyValid := '0';
      elsif rxMessage.sourcePortIdentity /= r.activeConfig.sourceIdentity then
         policyValid := '0';
      elsif rxMessage.domainNumber /= r.activeConfig.domainNumber or rxMessage.transportSpecific /= PTP_TRANSPORT_SPECIFIC_C then
         policyValid := '0';
      elsif rxMessage.capture.generation /= phcStatus.generation or rxMessage.capture.error /= '0' then
         policyValid := '0';
      elsif unsigned(phcStatus.ticks) < unsigned(rxMessage.capture.ticks) then
         policyValid := '0';
      elsif unsigned(phcStatus.ticks)-unsigned(rxMessage.capture.ticks) > unsigned(r.activeConfig.associationTimeout) then
         policyValid := '0';
      end if;

      -- A changed grandmaster or timescale cancels the old measurements on
      -- this edge. This decision precedes readiness and cannot depend on it.
      announceChange := '0';
      if rxValid = '1' and r.state = IDLE_S and r.measurementMaster.valid = '0' then
         if policyValid = '1' and r.announceSeen = '1' and rxMessage.messageType = PTP_MSG_ANNOUNCE_C then
            if validAnnounce(rxMessage) then
               if ptpGrandmasterIdentity(rxMessage) /= r.portStatus.grandmasterIdentity or rxMessage.flags(PTP_TIMESCALE_BIT_C) /= r.portStatus.announceFlags(PTP_TIMESCALE_BIT_C) then
                  announceChange := '1';
               end if;
            end if;
         end if;
      end if;

      -- Independent protocol causes may revoke an accepted PHC command. Its
      -- own capture invalidation only flushes measurement/association work.
      externalAbort := '0';
      if rst = RST_POLARITY_G or restart = '1' or configControl.apply = '1' or localMac /= r.lastMac then
         externalAbort := '1';
      elsif linkReady = '0' or enable = '0' then
         externalAbort := '1';
      elsif rxQueueOverflow = '1' or txAbort = '1' or announceChange = '1' then
         externalAbort := '1';
      elsif r.portStatus.active = '1' then
         if unsigned(phcStatus.ticks)-unsigned(r.lastTicks) > unsigned(r.syncLimit) then
            externalAbort := '1';
         end if;
      end if;
      abortPort := '0';
      if externalAbort = '1' or captureAbort = '1' or rxAbort = '1' or
         phcStatus.generation /= r.generation then
         abortPort := '1';
      end if;

      -- Publish lifecycle events after this detection edge. The PHC observes
      -- commandAbort on the next edge, in time to veto a command admitted on
      -- this edge. Earlier committed work is not retroactively revoked.
      v.lifecycle              := PTP_PORT_LIFECYCLE_INIT_C;
      v.lifecycle.commandAbort := externalAbort;
      if localMac /= r.lastMac then
         v.lifecycle.identityRestart := '1';
      end if;
      v.measurementMaster.abort := abortPort;
      -- Drain the registered child cancellation before admitting new work.
      -- Do not feed that old event back into its own next value above.
      abortPort := abortPort or r.measurementMaster.abort;

      qualifiedRatio := '0';
      if r.ratioCount = RATIO_QUALIFY_COUNT_C and
         unsigned(phcStatus.ticks)-unsigned(r.ratioTicks) <= unsigned(r.activeConfig.maxRateAge) then
         qualifiedRatio := '1';
      end if;
      v.rxReady := '0';
      if r.state = IDLE_S and r.measurementMaster.valid = '0' and abortPort = '0' then
         v.rxReady := '1';
      end if;
      validResponse := '0';
      if rxMessage.messageType = PTP_MSG_DELAY_RESP_C and rxMessage.flags = x"0000" and
         rxMessage.control = PTP_CONTROL_DELAY_RESP_C and unsigned(ptpMessageNanoseconds(rxMessage)) < PTP_NANOSECONDS_PER_SECOND_C then
         validResponse := rxValid and v.rxReady and policyValid;
      end if;

      if validResponse = '1' then
         v.response      := rxMessage;
         v.responseValid := '1';
      end if;
      if responseAccepted = '1' and abortPort = '0' and validLogInterval(r.responseLog) then
         v.minimumInterval := intervalTicks(r.responseLog, r.activeConfig.delayInterval);
      end if;

      -------------------------------------------------------------------------
      -- TX ownership and request scheduling
      -------------------------------------------------------------------------
      -- TX ownership survives abort. Once valid is presented, every byte and
      -- sideband stays stable under backpressure until the entire frame drains.
      if r.master.tValid = '1' and txSlave.tReady = '1' then
         v.master := AXI_STREAM_MASTER_INIT_C;
         if r.beat /= TX_LAST_BEAT_C then
            v.beat          := r.beat+1;
            v.master.tValid := '1';
            if v.beat = TX_LAST_BEAT_C then
               v.master.tData(8*TX_LAST_BYTES_C-1 downto 0) := r.frame(8*TX_FRAME_BYTES_C-1 downto 8*TX_LAST_BEAT_C*TX_BEAT_BYTES_C);
               v.master.tKeep(TX_BEAT_BYTES_C-1 downto 0) := TX_LAST_KEEP_C;
               v.master.tLast              := '1';
            else
               -- Static slices make the seven-way beat mux explicit to both
               -- synthesis frontends; the final two-byte beat is handled above.
               for i in 0 to TX_LAST_BEAT_C-1 loop
                  if v.beat = i then
                     v.master.tData(8*TX_BEAT_BYTES_C-1 downto 0) := r.frame(8*TX_BEAT_BYTES_C*(i+1)-1 downto 8*TX_BEAT_BYTES_C*i);
                  end if;
               end loop;
               v.master.tKeep(TX_BEAT_BYTES_C-1 downto 0) := (others => '1');
            end if;
         end if;
      end if;

      -- Offer a registered reservation request independently of ledger ready.
      -- Only the actual handshake creates a frame. A local abort on that edge
      -- cannot undo a reservation already accepted by the child: preserve and
      -- transmit that frame, then let the registered cancellation retire it.
      if r.allocate = '0' and r.portStatus.active = '1' and qualifiedRatio = '1' and
         r.master.tValid = '0' and abortPort = '0' and
         (r.requestStarted = '0' or unsigned(phcStatus.ticks)-unsigned(r.lastRequest) >= r.requestInterval) then
         v.allocate := '1';
      end if;
      if r.allocate = '1' and allocateReady = '1' and r.measurementMaster.abort = '0' then
         v.allocate                                   := '0';
         v.frame                                      := buildRequest(r.activeConfig, localMac, allocateSequence);
         v.master                                     := AXI_STREAM_MASTER_INIT_C;
         v.master.tValid                              := '1';
         v.master.tKeep(TX_BEAT_BYTES_C-1 downto 0)   := (others => '1');
         v.master.tData(8*TX_BEAT_BYTES_C-1 downto 0) := v.frame(8*TX_BEAT_BYTES_C-1 downto 0);
         ssiSetUserSof(PTP_RX_AXIS_CONFIG_C, v.master, '1');
         v.beat           := 0;
         v.lastRequest    := phcStatus.ticks;
         v.requestStarted := '1';
         -- A bounded three-point schedule (0.5, 1.0, 1.5 times mean) avoids a
         -- runtime multiplier while preserving deterministic seeded variation.
         v.requestInterval := unsigned(r.activeConfig.delayInterval);
         if r.minimumInterval > v.requestInterval then
            v.requestInterval := r.minimumInterval;
         end if;
         if r.lfsr(1 downto 0) = "00" then
            v.requestInterval := shift_right(v.requestInterval, 1);
         elsif r.lfsr(1 downto 0) = "11" then
            v.requestInterval := v.requestInterval + shift_right(v.requestInterval, 1);
         end if;
         -- Fibonacci LFSR taps 16, 14, 13, 11 (one-based); shift toward bit 15,
         -- feed the XOR into bit 0. A nonzero seed avoids the all-zero lockup.
         v.lfsr := r.lfsr(14 downto 0) & (r.lfsr(15) xor r.lfsr(13) xor r.lfsr(12) xor r.lfsr(10));
      end if;

      -------------------------------------------------------------------------
      -- RX association and message dispatch
      -------------------------------------------------------------------------
      -- Retire expired partial associations before accepting this cycle's RX record.
      for i in r.pairs'range loop
         if r.pairs(i).used = '1' and
            unsigned(phcStatus.ticks)-unsigned(r.pairs(i).born) > unsigned(r.activeConfig.associationTimeout) then
            v.pairs(i) := PAIR_INIT_C;
         end if;
      end loop;

      -- Consume one message: reject policy failures, otherwise dispatch by type.
      malformed := false;
      if v.rxReady = '1' and rxValid = '1' then
         if policyValid = '0' then
            malformed := true;
         else
            case rxMessage.messageType is
               when PTP_MSG_SYNC_C | PTP_MSG_FOLLOW_UP_C =>
                  if (rxMessage.messageType = PTP_MSG_SYNC_C and
                      (rxMessage.flags /= PTP_TWO_STEP_FLAGS_C or rxMessage.control /= PTP_CONTROL_SYNC_C)) or
                     (rxMessage.messageType = PTP_MSG_FOLLOW_UP_C and
                      (rxMessage.flags /= x"0000" or rxMessage.control /= PTP_CONTROL_FOLLOW_UP_C or
                       unsigned(ptpMessageNanoseconds(rxMessage)) >= PTP_NANOSECONDS_PER_SECOND_C)) then
                     malformed := true;
                  else
                     slot := findPair(v.pairs, rxMessage.sequenceId);
                     if slot /= -1 then
                        if v.pairs(slot).used = '0' or v.pairs(slot).sample.sequenceId /= rxMessage.sequenceId then
                           v.pairs(slot)                   := PAIR_INIT_C;
                           v.pairs(slot).used              := '1';
                           v.pairs(slot).born              := phcStatus.ticks;
                           v.pairs(slot).sample.sequenceId := rxMessage.sequenceId;
                        end if;
                     end if;
                     if slot = -1 then
                        malformed := true;
                     elsif rxMessage.messageType = PTP_MSG_SYNC_C then
                        if v.pairs(slot).syncSeen = '1' then
                           -- Duplicate Sync is ambiguous even if its headers match:
                           -- the physical capture is a different wire event.
                           v.pairs(slot).complete := '1';
                           malformed              := true;
                        else
                           v.pairs(slot).syncSeen       := '1';
                           v.pairs(slot).sample.capture := rxMessage.capture;
                           v.pairs(slot).syncCorrection := rxMessage.correction;
                           v.syncLimit                  := receiptTimeout(rxMessage.logInterval, r.activeConfig.syncTimeout);
                           if not validLogInterval(rxMessage.logInterval) and
                              rxMessage.logInterval /= PTP_LOG_INTERVAL_UNSPECIFIED_C then
                              v.portStatus.rejectedCount := ptpSatInc(v.portStatus.rejectedCount);
                           end if;
                        end if;
                     else
                        if v.pairs(slot).followSeen = '1' then
                           if v.pairs(slot).sample.remoteTime /= ptpMessageTimestamp(rxMessage) or
                              v.pairs(slot).followCorrection /= rxMessage.correction then
                              v.pairs(slot).complete := '1';
                              malformed              := true;
                           end if;
                        else
                           v.pairs(slot).followSeen        := '1';
                           v.pairs(slot).sample.remoteTime := ptpMessageTimestamp(rxMessage);
                           v.pairs(slot).followCorrection  := rxMessage.correction;
                        end if;
                     end if;
                  end if;

               when PTP_MSG_DELAY_RESP_C =>
                  if validResponse = '0' then
                     malformed := true;
                  end if;

               when PTP_MSG_ANNOUNCE_C =>
                  if not validAnnounce(rxMessage) then
                     malformed      := true;
                     v.announceSeen := '0';
                  else
                     v.announceSeen                   := '1';
                     v.portStatus.announceBody        := rxMessage.messageBody;
                     v.announceTicks                  := rxMessage.capture.ticks;
                     v.portStatus.grandmasterIdentity := ptpGrandmasterIdentity(rxMessage);
                     v.portStatus.announceFlags       := rxMessage.flags;
                     v.portStatus.utcOffset           := ptpUtcOffset(rxMessage);
                     v.announceLimit                  := receiptTimeout(rxMessage.logInterval,
                        slv(resize(unsigned(r.activeConfig.syncTimeout)*ANNOUNCE_CAP_FACTOR_C, 64)));
                     if not validLogInterval(rxMessage.logInterval) and
                        rxMessage.logInterval /= PTP_LOG_INTERVAL_UNSPECIFIED_C then
                        v.portStatus.rejectedCount := ptpSatInc(v.portStatus.rejectedCount);
                     end if;
                  end if;

               when others =>
                  malformed := true;
            end case;
         end if;
      end if;
      if malformed then
         v.portStatus.rejectedCount := ptpSatInc(v.portStatus.rejectedCount);
      end if;

      -------------------------------------------------------------------------
      -- Rate estimation and forward-measurement publication
      -------------------------------------------------------------------------
      -- One rate-engine state owns each step. IDLE can complete a pair inserted
      -- above on this same evaluation; capture chronology still gates acceptance.
      case r.state is
         when IDLE_S =>
            if r.measurementMaster.valid = '0' then
               completed := completedPair(v.pairs);
               if completed /= -1 then
                  v.pairs(completed).complete := '1';
                  completedSync               := v.pairs(completed).sample;
                  completedSync.correction    := slv(resize(signed(v.pairs(completed).syncCorrection), 128)+
                                                     resize(signed(v.pairs(completed).followCorrection), 128));
                  remoteTime := ptpWireTimeQ16(completedSync.remoteTime)+signed(completedSync.correction);
                  if unsigned(phcStatus.ticks)-unsigned(completedSync.capture.ticks) > unsigned(r.activeConfig.associationTimeout) or
                     (r.portStatus.active = '1' and (remoteTime <= r.lastRemote or unsigned(completedSync.capture.ticks) <= unsigned(r.lastTicks))) then
                     v.portStatus.rejectedCount := ptpSatInc(v.portStatus.rejectedCount);
                  else
                     v.portStatus.active                     := '1';
                     v.lastSync                              := completedSync;
                     v.lastRemote                            := remoteTime;
                     v.lastTicks                             := completedSync.capture.ticks;
                     v.history(r.historyPtr)                 := completedSync;
                     v.historyValid(r.historyPtr)            := '1';
                     v.historyPtr                            := (r.historyPtr+1) mod HISTORY_DEPTH_C;
                     v.portStatus.syncCount                  := ptpSatInc(v.portStatus.syncCount);
                     v.measurementMaster.data                := forwardMeasurement(completedSync);
                     v.measurementMaster.data.ratio          := r.ratio;
                     v.measurementMaster.data.ratioValid     := qualifiedRatio;
                     v.measurementMaster.valid               := '1';
                     if r.anchorValid = '0' then
                        v.anchor      := completedSync;
                        v.anchorValid := '1';
                     else
                        rateSpan := ptpTickPhase(completedSync.capture)-ptpTickPhase(r.anchor.capture);
                        if rateSpan >= shift_left(signed(resize(unsigned(r.activeConfig.minRateSpan), 128)), PTP_TICK_PHASE_BITS_C) and rateSpan > 0 then
                           v.rateA                   := slv(shift_left(remoteTime-ptpWireTimeQ16(r.anchor.remoteTime)-signed(r.anchor.correction), RATE_RATIO_SHIFT_C));
                           v.rateB                   := slv(rateSpan);
                           v.pendingSync             := completedSync;
                           v.anchor                  := completedSync;
                           v.state                   := RATE_ISSUE_S;
                           v.measurementMaster.valid := '0';
                        end if;
                     end if;
                  end if;
               end if;
            end if;

         when RATE_ISSUE_S =>
            if rateReady = '1' then
               v.state := RATE_WAIT_S;
            end if;

         when RATE_WAIT_S =>
            if rateResultValid = '1' and abortPort = '0' then
               if rateError = '0' and signed(rateResult) >= signed(resize(NOMINAL_C-RATE_MARGIN_C, 128)) and
                  signed(rateResult) <= signed(resize(NOMINAL_C+RATE_MARGIN_C, 128)) then
                  if r.ratioCount = 0 then
                     v.ratio := rateResult(63 downto 0);
                  else
                     v.ratio := slv(resize(signed(resize(unsigned(r.ratio), 128))+
                        ptpRoundShift(signed(rateResult)-signed(resize(unsigned(r.ratio), 128)), RATIO_FILTER_SHIFT_C), 64));
                  end if;
                  if r.ratioCount < RATIO_QUALIFY_COUNT_C then
                     v.ratioCount := r.ratioCount+1;
                  end if;
                  v.ratioTicks := r.pendingSync.capture.ticks;
               else
                  v.portStatus.rejectedCount := ptpSatInc(v.portStatus.rejectedCount);
               end if;
               v.measurementMaster.data            := forwardMeasurement(r.pendingSync);
               v.measurementMaster.data.ratio      := v.ratio;
               v.measurementMaster.data.ratioValid := '0';
               if v.ratioCount = RATIO_QUALIFY_COUNT_C and unsigned(phcStatus.ticks)-unsigned(v.ratioTicks) <= unsigned(r.activeConfig.maxRateAge) then
                  v.measurementMaster.data.ratioValid := '1';
               end if;
               v.measurementMaster.valid := '1';
               v.state                   := IDLE_S;
            end if;
      end case;

      -------------------------------------------------------------------------
      -- E2E association and result publication
      -------------------------------------------------------------------------
      -- Result valid is registered; the shared abort takes priority at this
      -- receiver as well as at the arithmetic/ledger producers.
      -- Select the retained Sync nearest the actual TX capture, not nearest to
      -- the delayed wire-completion/Delay_Resp delivery. Signed separation also
      -- supports a Sync arriving just after the Delay_Req left the wire.
      if delayValid = '1' and r.e2eBusy = '0' and abortPort = '0' then
         selected     := nearestSync(r.history, r.historyValid, delaySample, phcStatus.ticks, r.activeConfig);
         v.delayReady := '1';
         if selected /= -1 and qualifiedRatio = '1' then
            v.e2eSync                         := r.history(selected);
            v.e2eDelay                        := delaySample;
            v.e2eRatio                        := r.ratio;
            v.e2eMaximum                      := r.activeConfig.maxPathDelay;
            v.e2eInput                        := '1';
            v.e2eBusy                         := '1';
            v.pendingExchange.t1              := r.history(selected).remoteTime;
            v.pendingExchange.t2              := r.history(selected).capture.timestamp;
            v.pendingExchange.t3              := delaySample.capture.timestamp;
            v.pendingExchange.t4              := delaySample.remoteTime;
            v.pendingExchange.syncCorrection  := r.history(selected).correction;
            v.pendingExchange.delayCorrection := delaySample.correction;
            v.pendingExchange.generation      := delaySample.generation;
            v.pendingExchange.syncSequence    := r.history(selected).sequenceId;
            v.pendingExchange.delaySequence   := delaySample.sequenceId;
         else
            v.portStatus.rejectedCount := ptpSatInc(v.portStatus.rejectedCount);
         end if;
      end if;
      if e2eValid = '1' and abortPort = '0' and r.state = IDLE_S and v.state = IDLE_S and v.measurementMaster.valid = '0' then
         v.e2eTake := '1';
         v.e2eBusy := '0';
         if e2eError = '0' and qualifiedRatio = '1' then
            v.measurementMaster.data           := e2eResult;
            v.portStatus.exchange              := r.pendingExchange;
            v.measurementMaster.valid          := '1';
            v.portStatus.delayCount            := ptpSatInc(v.portStatus.delayCount);
         else
            v.portStatus.rejectedCount := ptpSatInc(v.portStatus.rejectedCount);
         end if;
      end if;

      -------------------------------------------------------------------------
      -- Final cancellation priority
      -------------------------------------------------------------------------
      -- Cancellation has final priority over association and publication. TX
      -- drain state and unresolved ledger ownership deliberately survive it.
      if abortPort = '1' then
         -- Keep the TX frame/beat and diagnostic counters. Ledger retirement is
         -- independent and receives the registered abort on the following edge.
         v.pairs                    := (others => PAIR_INIT_C);
         v.historyValid             := (others => '0');
         v.portStatus.active        := '0';
         v.syncLimit                := r.activeConfig.syncTimeout;
         v.announceLimit            := slv(resize(unsigned(r.activeConfig.syncTimeout)*ANNOUNCE_CAP_FACTOR_C, 64));
         v.anchorValid              := '0';
         v.ratioCount               := 0;
         v.state                    := IDLE_S;
         v.measurementMaster.valid  := '0';
         v.requestStarted           := '0';
         v.minimumInterval          := (others => '0');
         v.announceSeen             := '0';
         if announceChange = '1' then
            v.portStatus.grandmasterIdentity := ptpGrandmasterIdentity(rxMessage);
         end if;
         v.lfsr := r.activeConfig.lfsrSeed;
         if unsigned(v.lfsr) = 0 then
            v.lfsr := LFSR_SEED_C;
         end if;
         v.allocate      := '0';
         v.responseValid := '0';
         v.e2eInput      := '0';
         v.e2eBusy       := '0';
         v.delayReady    := '0';
      end if;
      -- Register the rate request with the next operands/state. The shared
      -- child samples the registered abort with these requests. Local admission
      -- remains closed while that cancellation drains through the child.
      v.rateInput := '0';
      if v.state = RATE_ISSUE_S then
         v.rateInput := '1';
      end if;
      -------------------------------------------------------------------------
      -- Registered diagnostic summaries
      -------------------------------------------------------------------------
      -- Sample derived diagnostic summaries after all protocol updates and
      -- cancellation. Counters, metadata and exchange already live in portStatus.
      v.portStatus.ratioValid := '0';
      if v.ratioCount = RATIO_QUALIFY_COUNT_C and
         unsigned(phcStatus.ticks)-unsigned(v.ratioTicks) <= unsigned(r.activeConfig.maxRateAge) then
         v.portStatus.ratioValid := '1';
      end if;
      v.portStatus.announceValid := '0';
      if unsigned(phcStatus.ticks)-unsigned(v.announceTicks) <= unsigned(v.announceLimit) then
         v.portStatus.announceValid := v.announceSeen;
      end if;
      v.portStatus.ledgerStatus := ledgerStatus;
      v.portStatus.timeoutCount := timeoutCount;

      -------------------------------------------------------------------------
      -- AXI-Lite: decode, map, then close the transaction.
      -------------------------------------------------------------------------
      axiSlaveWaitTxn(ep, axiWriteMaster, axiReadMaster, v.writeSlave, v.readSlave);

      -- Suppress register accesses during AXI-only reset.
      if regRst = '1' then
         ep.axiStatus := AXI_LITE_STATUS_INIT_C;
      end if;

      -- Configuration shadows and live identity/status.
      axiSlaveRegister(ep, x"004", 4, v.shadow.identityOverride);
      axiSlaveRegister(ep, x"008", 0, v.shadow.domainNumber);
      axiSlaveRegister(ep, x"008", 8, v.shadow.minorVersion);
      axiSlaveRegister(ep, x"010", 0, v.shadow.localIdentity);
      axiSlaveRegister(ep, x"020", 0, v.shadow.sourceIdentity);
      axiSlaveRegisterR(ep, x"030", 0, localMac);
      axiSlaveRegisterR(ep, x"044", 0, r.portStatus.active);
      axiSlaveRegisterR(ep, x"044", 1, r.portStatus.announceValid);
      axiSlaveRegisterR(ep, x"044", 2, r.portStatus.ratioValid);
      axiSlaveRegisterR(ep, x"048", 0, r.portStatus.ledgerStatus);
      axiSlaveRegisterR(ep, x"060", 0, r.activeConfig.localIdentity);
      axiSlaveRegisterR(ep, x"070", 0, r.activeConfig.sourceIdentity);

      -- Protocol timer and acceptance-limit shadows.
      axiSlaveRegister(ep, x"080", 0, v.shadow.delayInterval);
      axiSlaveRegister(ep, x"088", 0, v.shadow.syncTimeout);
      axiSlaveRegister(ep, x"090", 0, v.shadow.associationTimeout);
      axiSlaveRegister(ep, x"098", 0, v.shadow.maxExchange);
      axiSlaveRegister(ep, x"0A0", 0, v.shadow.minRateSpan);
      axiSlaveRegister(ep, x"0A8", 0, v.shadow.maxRateAge);
      axiSlaveRegister(ep, x"0B0", 0, v.shadow.lfsrSeed);
      axiSlaveRegister(ep, x"0B8", 0, v.shadow.maxPathDelay);

      -- Implementation constants and active shared limits.
      axiSlaveRegisterR(ep, x"0C0", 0, slv(to_unsigned(PACKET_LIFETIME_G, 64)));
      axiSlaveRegisterR(ep, x"0D0", 0, INGRESS_LATENCY_G);
      axiSlaveRegisterR(ep, x"0D8", 0, EGRESS_LATENCY_G);
      axiSlaveRegisterR(ep, x"0E0", 0, r.activeConfig.associationTimeout);
      axiSlaveRegisterR(ep, x"0E8", 0, r.activeConfig.syncTimeout);
      axiSlaveRegisterR(ep, x"0F0", 0, r.activeConfig.maxPathDelay);

      -- Coherent Announce and exchange snapshots.
      axiSlaveRegisterR(ep, x"130", 0, r.snapGm);
      axiSlaveRegisterR(ep, x"138", 0, r.snapFlags);
      axiSlaveRegisterR(ep, x"13C", 0, r.snapUtc);
      axiSlaveRegisterR(ep, x"140", 0, r.snapAnnounce);
      axiSlaveRegisterR(ep, x"160", 0, r.snapExchange.t1);
      axiSlaveRegisterR(ep, x"170", 0, r.snapExchange.t2);
      axiSlaveRegisterR(ep, x"180", 0, r.snapExchange.t3);
      axiSlaveRegisterR(ep, x"190", 0, r.snapExchange.t4);
      axiSlaveRegisterR(ep, x"1A0", 0, r.snapExchange.syncCorrection);
      axiSlaveRegisterR(ep, x"1B0", 0, r.snapExchange.delayCorrection);
      axiSlaveRegisterR(ep, x"1B8", 0, r.snapExchange.generation);
      axiSlaveRegisterR(ep, x"1BC", 0, r.snapExchange.syncSequence);
      axiSlaveRegisterR(ep, x"1BC", 16, r.snapExchange.delaySequence);

      -- Coherent RX/protocol counters and snapshot sequence.
      axiSlaveRegisterR(ep, x"200", 0, r.snapCounters(0));
      axiSlaveRegisterR(ep, x"204", 0, r.snapCounters(1));
      axiSlaveRegisterR(ep, x"208", 0, r.snapCounters(2));
      axiSlaveRegisterR(ep, x"20C", 0, r.snapCounters(3));
      axiSlaveRegisterR(ep, x"210", 0, r.snapCounters(4));
      axiSlaveRegisterR(ep, x"214", 0, r.snapCounters(5));
      axiSlaveRegisterR(ep, x"218", 0, r.snapCounters(6));
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

      -- Freeze candidate and vote together; same-edge shadow writes belong
      -- to the next commit and must not affect this validation result.
      if configControl.prepare = '1' then
         v.candidate   := r.shadow;
         v.configValid := toSl(validConfig(r.shadow));
      end if;
      if configControl.apply = '1' then
         v.activeConfig := r.candidate;
      end if;
      -- Derive the active identity at apply and whenever the shared MAC
      -- changes. A frozen override candidate remains independent of MAC edits.
      if configControl.apply = '1' or localMac /= r.lastMac then
         if v.activeConfig.identityOverride = '0' then
            v.activeConfig.localIdentity := ptpPortIdentity(
               localMac, v.activeConfig.localIdentity(15 downto 0));
         end if;
      end if;
      v.lastMac := localMac;
      if snapshotControl.capture = '1' then
         v.sequenceId   := snapshotControl.sequenceId;
         v.snapExchange := r.portStatus.exchange;
         v.snapAnnounce := r.portStatus.announceBody;
         v.snapGm       := r.portStatus.grandmasterIdentity;
         v.snapFlags    := r.portStatus.announceFlags;
         v.snapUtc      := r.portStatus.utcOffset;
         v.snapCounters := (
            rxCounters.accepted,
            rxCounters.dropped,
            rxCounters.overflow,
            r.portStatus.rejectedCount,
            r.portStatus.syncCount,
            r.portStatus.delayCount,
            timeoutCount);
      end if;
      configValid   <= r.configValid;
      axiReadSlave  <= r.readSlave;
      axiWriteSlave <= r.writeSlave;
      -- Registered forward interfaces; reverse ready still describes capacity
      -- on this edge. RX/measurement arbitration and local cancellation can
      -- remove capacity now; registering ready would need an additional input
      -- slot or a reservation shared with those competing producers.
      allocate          <= r.allocate;
      e2eInput          <= r.e2eInput;
      e2eSync           <= r.e2eSync;
      delayReady        <= v.delayReady;
      e2eTake           <= v.e2eTake;
      rateInput         <= r.rateInput;
      rxReady           <= v.rxReady;
      responseValid     <= r.responseValid;
      lifecycle         <= r.lifecycle;
      abortNow          <= r.measurementMaster.abort;
      measurementMaster <= r.measurementMaster;
      txMaster          <= r.master;

      -- Registered diagnostics and active shared configuration.
      status                          <= r.portStatus;
      sharedConfig.associationTimeout <= r.activeConfig.associationTimeout;
      sharedConfig.syncTimeout        <= r.activeConfig.syncTimeout;
      sharedConfig.maxPathDelay       <= r.activeConfig.maxPathDelay;

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
