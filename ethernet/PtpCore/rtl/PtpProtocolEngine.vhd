-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Fixed-source Layer-2 PTP TimeReceiver protocol engine.
--
-- Consumes structurally validated RX records and applies the configured
-- source, domain and profile policy to Sync, Follow_Up, Delay_Resp and
-- Announce. Four bounded slots accept one-step Sync or two-step Sync/Follow_Up
-- in either arrival order and reject conflicting associations. Sync history
-- supplies the sample nearest a Delay_Req TX capture; Announce metadata and raw-tick
-- receipt timers qualify the current source session.
-- Both four-row payload tables use synchronous SURF RAM. Pairing holds the
-- RX producer through a serial lookup; history reserves E2E capacity and blocks
-- appends through a nearest-sample scan. A shared 32-bit word ALU arbitrates
-- age, distance and ordering checks per row. Reset/abort clears ownership, not RAM.
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
-- profile supports untagged multicast Layer-2 one-/two-step E2E reception;
-- UDP, VLAN, one-step transmit insertion and peer-delay are outside its scope.
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
-- ledger lifetime. Measurement data/valid/abort are registered; reverse ready
-- describes current capacity. PtpPortLifecycleType carries registered
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
use surf.PtpRegisterPkg.all;

entity PtpProtocolEngine is
   generic (
      TPD_G             : time             := 1 ns;
      RST_POLARITY_G    : sl               := '1';
      RST_ASYNC_G       : boolean          := false;
      CLK_FREQ_G        : positive         := 156250000;
      PACKET_LIFETIME_G : positive         := 156250000;
      INGRESS_LATENCY_G : slv(63 downto 0) := (others => '0');
      EGRESS_LATENCY_G  : slv(63 downto 0) := (others => '0');
      -- Supported inferred RAM implementations: "distributed" or "block".
      HISTORY_MEMORY_TYPE_G : string           := "block";
      PAIR_MEMORY_TYPE_G    : string           := "block");
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
      enable           : in  sl                     := '0';
      rxCounters       : in  PtpRxCountersType      := PTP_RX_COUNTERS_INIT_C;
      sharedConfig     : out PtpSharedConfigType;
      -- Protocol/clock interface.
      restart         : in  sl;
      linkReady       : in  sl;
      macResetDone    : in  sl;
      localMac        : in  slv(47 downto 0);
      phcStatus       : in  PtpPhcStatusType;
      captureAbort    : in  sl;
      rxMessage       : in  PtpRxMessageType;
      rxValid         : in  sl;
      rxReady         : out sl;
      rxQueueOverflow : in  sl := '0';
      rxAbort         : in  sl;
      -- Physical completion producer holds its record through txMessageReady.
      txMessage         : in  PtpRxMessageType;
      txValid           : in  sl;
      txMessageReady    : out sl;
      txAbort           : in  sl;
      txMaster          : out AxiStreamMasterType;
      txSlave           : in  AxiStreamSlaveType;
      measurementMaster : out PtpMeasurementMasterType;
      measurementSlave  : in  PtpMeasurementSlaveType;
      lifecycle         : out PtpPortLifecycleType;
      status            : out PtpPortStatusType;
      -- Shared endpoint variable divider. Index 0 is the rate estimator and
      -- index 1 is the E2E calibration path; both use the positive-divisor,
      -- quotient-only contract and qualify their divisor before narrowing.
      divideValid       : out slv(1 downto 0);
      divideReady       : in  slv(1 downto 0)         := (others => '0');
      divideOperandA    : out Slv128Array(1 downto 0);
      divideOperandB    : out slv(159 downto 0);
      divideCancel      : out slv(1 downto 0);
      divideResultValid : in  slv(1 downto 0)         := (others => '0');
      divideResultReady : out slv(1 downto 0);
      divideResultValue : in  Slv128Array(1 downto 0) := (others => (others => '0'));
      divideResultError : in  slv(1 downto 0)         := (others => '0'));
end entity PtpProtocolEngine;

architecture rtl of PtpProtocolEngine is

   constant PAIR_DEPTH_C    : positive := 4;
   constant HISTORY_DEPTH_C : positive := 4;
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
   constant TX_FRAME_BYTES_C : positive                        := PTP_ETH_HEADER_BYTES_C+PTP_TIMESTAMP_MSG_BYTES_C;
   constant TX_BEAT_BYTES_C  : positive                        := PTP_RX_AXIS_CONFIG_C.TDATA_BYTES_C;
   constant TX_LAST_BEAT_C   : natural                         := (TX_FRAME_BYTES_C-1)/TX_BEAT_BYTES_C;
   constant TX_LAST_BYTES_C  : positive                        := TX_FRAME_BYTES_C-TX_LAST_BEAT_C*TX_BEAT_BYTES_C;
   constant TX_LAST_KEEP_C   : slv(TX_BEAT_BYTES_C-1 downto 0) := toSlv(2**TX_LAST_BYTES_C-1, TX_BEAT_BYTES_C);
   function initialConfig return PtpPortConfigType is
      variable v      : PtpPortConfigType     := PTP_PORT_CONFIG_INIT_C;
      constant TICK_C : unsigned(63 downto 0) := to_unsigned(CLK_FREQ_G, 64);
   begin
      v.delayInterval      := slv(TICK_C);               -- 1 s before jitter.
      v.syncTimeout        := slv(resize(TICK_C*3, 64));  -- 3 s.
      v.associationTimeout := slv(resize(TICK_C*2, 64));  -- 2 s at supported PHY clocks.

      if unsigned(v.associationTimeout) < PTP_MIN_ASSOCIATION_TICKS_C then
         v.associationTimeout := toSlv(PTP_MIN_ASSOCIATION_TICKS_C,64);
      end if;

      v.maxExchange        := slv(resize(TICK_C*2, 64));  -- 2 s.
      v.minRateSpan        := slv(TICK_C/2);             -- 0.5 s, rounded down to ticks.
      v.maxRateAge         := slv(resize(TICK_C*4, 64));  -- 4 s.
      return v;
   end function;

   -- Identity, admission/expiry and request scheduling must react on any
   -- clock, so only those controls are cached. The rate-span operand is fetched
   -- from the active word bank during its serialized upload.
   type ControlCacheType is record
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

   function initialCache return ControlCacheType is
      constant CFG_C : PtpPortConfigType := initialConfig;
      variable cache : ControlCacheType;
   begin
      cache.identityOverride := CFG_C.identityOverride;
      cache.domainNumber := CFG_C.domainNumber;
      cache.minorVersion := CFG_C.minorVersion;
      cache.localIdentity := CFG_C.localIdentity;
      cache.sourceIdentity := CFG_C.sourceIdentity;
      cache.delayInterval := CFG_C.delayInterval;
      cache.syncTimeout := CFG_C.syncTimeout;
      cache.associationTimeout := CFG_C.associationTimeout;
      cache.maxExchange := CFG_C.maxExchange;
      cache.minRateSpan := CFG_C.minRateSpan;
      cache.maxRateAge := CFG_C.maxRateAge;
      cache.maxPathDelay := CFG_C.maxPathDelay;
      cache.lfsrSeed := CFG_C.lfsrSeed;
      return cache;
   end function;

   function portConfig(cache : ControlCacheType) return PtpPortConfigType is
      variable cfg : PtpPortConfigType := PTP_PORT_CONFIG_INIT_C;
   begin
      cfg.identityOverride := cache.identityOverride;
      cfg.domainNumber := cache.domainNumber;
      cfg.minorVersion := cache.minorVersion;
      cfg.localIdentity := cache.localIdentity;
      cfg.sourceIdentity := cache.sourceIdentity;
      cfg.delayInterval := cache.delayInterval;
      cfg.syncTimeout := cache.syncTimeout;
      cfg.associationTimeout := cache.associationTimeout;
      cfg.maxExchange := cache.maxExchange;
      cfg.minRateSpan := cache.minRateSpan;
      cfg.maxRateAge := cache.maxRateAge;
      cfg.maxPathDelay := cache.maxPathDelay;
      cfg.lfsrSeed := cache.lfsrSeed;
      return cfg;
   end function;

   function initialWords return Slv32Array is
      constant CFG_C : PtpPortConfigType := initialConfig;
      variable words : Slv32Array(0 to 47) := (others => (others => '0'));
      procedure put(constant index : natural;
      constant value : slv) is
      begin
         for i in 0 to (value'length+31)/32-1 loop
            words(index+i) := slv(resize(shift_right(unsigned(value),32*i),32));
         end loop;
      end procedure;

   begin
      words(1)(4) := CFG_C.identityOverride;
      words(2)(7 downto 0) := CFG_C.domainNumber;
      words(2)(11 downto 8) := CFG_C.minorVersion;
      put(4,CFG_C.localIdentity);
      put(8,CFG_C.sourceIdentity);
      put(32,CFG_C.delayInterval);
      put(34,CFG_C.syncTimeout);
      put(36,CFG_C.associationTimeout);
      put(38,CFG_C.maxExchange);
      put(40,CFG_C.minRateSpan);
      put(42,CFG_C.maxRateAge);
      put(44,CFG_C.lfsrSeed);
      put(46,CFG_C.maxPathDelay);
      return words;
   end function;

   function configIndex(address : slv(11 downto 0)) return integer is
      variable index : natural := to_integer(unsigned(address(11 downto 2)));
   begin

      case index is
         when 1 | 2 | 4 to 6 | 8 to 10 | 32 to 44 | 46 to 47 =>
            return index;
         when others =>
            return -1;
      end case;

   end function;

   function configMask(index : integer;
   strobe : slv(3 downto 0)) return slv is
      variable mask : slv(31 downto 0) := (others => '0');
   begin

      case index is
         when 1 =>

            if strobe(0) = '1' then
               mask(4) := '1';
            end if;

         when 2 =>

            if strobe(0) = '1' then
               mask(7 downto 0) := (others => '1');
            end if;

            if strobe(1) = '1' then
               mask(11 downto 8) := (others => '1');
            end if;

         when 6 | 10 | 44 =>

            if strobe(1 downto 0) = "11" then
               mask(15 downto 0) := (others => '1');
            end if;

         when others =>

            if strobe = x"F" then
               mask := (others => '1');
            end if;

      end case;

      return mask;
   end function;

   -- Q16 elapsed master ns / Q3 elapsed raw cycles -> Q48 ns/cycle.
   constant RATE_RATIO_SHIFT_C : natural               := PTP_RATIO_FRAC_BITS_C+PTP_TICK_PHASE_BITS_C-PTP_TIME_FRAC_BITS_C;
   constant NOMINAL_C          : unsigned(63 downto 0) := shift_left(unsigned(ptpNominalIncrement(CLK_FREQ_G)), PTP_PHC_TO_RATIO_SHIFT_C);
   constant RATE_MARGIN_C      : unsigned(63 downto 0) := resize((resize(NOMINAL_C, 96)*to_unsigned(MAX_OSCILLATOR_PPB_C, 32))/to_unsigned(PTP_PPB_SCALE_C, 128), 64);
   -- Temporary decision flags only; payload fields stay in the pair word RAM.
   type PairType is record
      used       : sl;
      syncSeen   : sl;
      twoStep    : sl;                  -- Meaningful only after syncSeen.
      followSeen : sl;
      complete   : sl;
      sequenceId : slv(15 downto 0);
   end record;

   constant PAIR_INIT_C : PairType := (
      used       => '0',
      syncSeen   => '0',
      twoStep    => '0',
      followSeen => '0',
      complete   => '0',
      sequenceId => (others => '0'));

   constant PAIR_WORDS_C : positive := 20;
   constant PAIR_ADDR_WIDTH_C : positive := log2(PAIR_DEPTH_C*PAIR_WORDS_C);
   constant HISTORY_WORDS_C : positive := 25;
   constant HISTORY_ADDR_WIDTH_C : positive := log2(HISTORY_DEPTH_C*HISTORY_WORDS_C);
   -- The first four words are the nearest-sample search key. Only the chosen
   -- sample is read into the stable E2E publication record after the scan.
   function syncWord(sample : PtpSyncSampleType;
   index : natural) return slv is
      variable word : slv(31 downto 0) := (others => '0');
   begin

      case index is
         when 0 to 1 =>
            word := sample.capture.ticks(32*index+31 downto 32*index);
         when 2 =>
            word(PTP_TICK_PHASE_BITS_C-1 downto 0) := sample.capture.tickPhase;
            word(3) := sample.capture.timeValid;
            word(4) := sample.capture.error;
         when 3 =>
            word := sample.capture.generation;
         when 4 =>
            word(15 downto 0) := sample.sequenceId;
         when 5 to 7 =>
            word := sample.capture.timestamp(32*(index-5)+31 downto 32*(index-5));
         when 8 to 9 =>
            word := sample.capture.increment(32*(index-8)+31 downto 32*(index-8));
         when 10 to 11 =>
            word := sample.remoteTime(32*(index-10)+31 downto 32*(index-10));
         when 12 =>
            word(15 downto 0) := sample.remoteTime(79 downto 64);
         when 13 to 16 =>
            word := sample.correction(32*(index-13)+31 downto 32*(index-13));
         when others =>
            null;
      end case;

      return word;
   end function;

   procedure takeSyncWord(variable sample : inout PtpSyncSampleType;
   constant index : natural;
   constant word : slv(31 downto 0)) is
   begin

      case index is
         when 0 to 1 =>
            sample.capture.ticks(32*index+31 downto 32*index) := word;
         when 2 =>
            sample.capture.tickPhase := word(PTP_TICK_PHASE_BITS_C-1 downto 0);
            sample.capture.timeValid := word(3);
            sample.capture.error := word(4);
         when 3 =>
            sample.capture.generation := word;
         when 4 =>
            sample.sequenceId := word(15 downto 0);
         when 5 to 7 =>
            sample.capture.timestamp(32*(index-5)+31 downto 32*(index-5)) := word;
         when 8 to 9 =>
            sample.capture.increment(32*(index-8)+31 downto 32*(index-8)) := word;
         when 10 to 11 =>
            sample.remoteTime(32*(index-10)+31 downto 32*(index-10)) := word;
         when 12 =>
            sample.remoteTime(79 downto 64) := word(15 downto 0);
         when 13 to 16 =>
            sample.correction(32*(index-13)+31 downto 32*(index-13)) := word;
         when others =>
            null;
      end case;

   end procedure;

   type PairStateType is (
      PAIR_IDLE_S,
      PAIR_READ_S,
      PAIR_CHECK_S,
      PAIR_SCAN_S,
      PAIR_NEXT_S,
      PAIR_SELECT_S,
      PAIR_COMPARE_READ_S,
      PAIR_COMPARE_S,
      PAIR_DECIDE_S,
      PAIR_UPDATE_S,
      PAIR_PUBLISH_S,
      PAIR_PUBLISH_READ_S,
      PAIR_PUBLISH_CAPTURE_S,
      PAIR_ACK_S);

   type HistoryStateType is (
      HISTORY_IDLE_S,
      HISTORY_READ_S,
      HISTORY_CHECK_S,
      HISTORY_SCAN_S,
      HISTORY_NEXT_S,
      HISTORY_SELECT_S,
      HISTORY_FETCH_S,
      HISTORY_CAPTURE_S,
      HISTORY_DONE_S);

   -- Pair and history scans may overlap. One row owns the word ALU until
   -- DONE; round-robin arbitration bounds either wait by one competing row.
   type ScanStateType is (
      SCAN_IDLE_S,
      SCAN_AGE_S,
      SCAN_AGE_LIMIT_S,
      SCAN_DISTANCE_S,
      SCAN_ABS_S,
      SCAN_LIMIT_S,
      SCAN_BEST_S,
      SCAN_DONE_S);

   type StateType is (
      IDLE_S,
      RATE_SUBMIT_S, RATE_ACCEPT_S, RATE_WAIT_S,
      RATE_HISTORY_BEGIN_S, RATE_HISTORY_READ_S, RATE_HISTORY_DONE_S,
      RATE_PUBLISH_S);

   type RegType is record
      -- Current-edge admission for RX, ledger samples and E2E results.
      rxReady    : sl;
      delayReady : sl;
      e2eTake    : sl;
      -- Live diagnostic state; AXI snapshots below have a separate lifetime.
      portStatus : PtpPortStatusType;
      rejectedPending : natural range 0 to 9;
      -- Local management state shares the core reset and register process.
      readSlave        : AxiLiteReadSlaveType;
      writeSlave       : AxiLiteWriteSlaveType;
      candidate        : ControlCacheType;
      configBus        : PtpRegisterBusType;
      configMaster     : PtpRegisterMasterType;
      validateValue    : slv(63 downto 0);
      validatePrevious : slv(63 downto 0);
      configValid      : sl;
      activeConfig     : ControlCacheType;
      lastMac          : slv(47 downto 0);
      sequenceId       : slv(31 downto 0);
      publicationPort  : PtpPublicationType;
      snapshotBus      : PtpRegisterBusType;
      counterBus       : PtpRegisterBusType;
      announceWord     : natural range 0 to 11;
      announceStored   : sl;
      exchangeWriting  : sl;
      exchangeWord     : natural range 0 to 19;
      -- Payload tables use synchronous RAM; only ownership is reset in bulk.
      pairState           : PairStateType;
      pairUsed            : slv(PAIR_DEPTH_C-1 downto 0);
      pairSyncSeen        : slv(PAIR_DEPTH_C-1 downto 0);
      pairTwoStep         : slv(PAIR_DEPTH_C-1 downto 0);
      pairFollowSeen      : slv(PAIR_DEPTH_C-1 downto 0);
      pairComplete        : slv(PAIR_DEPTH_C-1 downto 0);
      pairIndex           : natural range 0 to PAIR_DEPTH_C-1;
      pairSlot            : integer range -1 to PAIR_DEPTH_C-1;
      pairMatch           : integer range -1 to PAIR_DEPTH_C-1;
      pairFree            : integer range -1 to PAIR_DEPTH_C-1;
      pairOldest          : integer range -1 to PAIR_DEPTH_C-1;
      pairOldestBorn      : slv(63 downto 0);
      pairTicks           : slv(63 downto 0);
      pairReadEnable      : sl;
      pairReadAddress     : slv(PAIR_ADDR_WIDTH_C-1 downto 0);
      pairWriteEnable     : sl;
      pairWriteAddress    : slv(PAIR_ADDR_WIDTH_C-1 downto 0);
      pairWriteData       : slv(31 downto 0);
      historyState        : HistoryStateType;
      normalizedValid     : sl;
      normalizedWord      : slv(2 downto 0);
      historyIndex        : natural range 0 to HISTORY_DEPTH_C-1;
      historyTicks        : slv(63 downto 0);
      historyFound        : sl;
      historyQualified    : sl;
      historyDistance     : slv(67 downto 0);
      historyReadEnable   : sl;
      historyReadAddress  : slv(HISTORY_ADDR_WIDTH_C-1 downto 0);
      historyWriteEnable  : sl;
      historyWriteAddress : slv(HISTORY_ADDR_WIDTH_C-1 downto 0);
      historyValid        : slv(HISTORY_DEPTH_C-1 downto 0);
      historyPtr          : natural range 0 to HISTORY_DEPTH_C-1;
      generation          : slv(31 downto 0);
      -- Shared scan scratch, never a second copy of a table row. Clients hold
      -- their captured row and admission ticks until the matching DONE edge.
      scanState   : ScanStateType;
      scanHistory : sl;
      scanTurn    : sl;
      scanWord    : natural range 0 to 2;
      scanValue   : slv(67 downto 0);
      scanCarry   : sl;
      scanZero    : sl;
      scanExpired : sl;
      scanBetter  : sl;
      -- Per-clock receipt policy and rate qualification remain local.
      syncLimit     : slv(63 downto 0);
      announceLimit : slv(63 downto 0);
      lastTicks     : slv(63 downto 0);
      -- Retain normalized anchor data rather than reconverting a full sample.
      ratio              : slv(63 downto 0);
      ratioTicks         : slv(63 downto 0);
      state              : StateType;
      pendingSync        : PtpSyncSampleType;
      measurementMaster  : PtpMeasurementMasterType;
      lifecycle          : PtpPortLifecycleType;
      allocate           : sl;
      response           : PtpRxMessageType;
      responseValid      : sl;
      responseLog        : slv(7 downto 0);
      e2eInput           : sl;
      e2eBusy            : sl;
      e2eSync            : PtpSyncSampleType;
      e2eDelay           : PtpDelaySampleType;
      e2eRatio           : slv(63 downto 0);
      e2eMaximum         : slv(63 downto 0);
      master             : AxiStreamMasterType;
      frame              : slv(8*TX_FRAME_BYTES_C-1 downto 0);
      beat               : natural range 0 to TX_LAST_BEAT_C;
      lastRequest        : slv(63 downto 0);
      requestInterval    : unsigned(63 downto 0);
      minimumInterval    : unsigned(63 downto 0);
      requestStarted     : sl;
      lfsr               : slv(15 downto 0);
      announceSeen       : sl;
      announceTicks      : slv(63 downto 0);
      pairWord           : natural range 0 to PAIR_WORDS_C-1;
      pairKey            : slv(15 downto 0);
      pairBorn           : slv(63 downto 0);
      pairNew            : sl;
      pairDuplicateEqual : sl;
      pairWriteSync      : sl;
      pairWriteFollow    : sl;
      pairPublish        : sl;
      historyWriteData   : slv(31 downto 0);
      historyWriteBusy   : sl;
      historyWriteWord   : natural range 0 to HISTORY_WORDS_C;
      historyWord        : natural range 0 to HISTORY_WORDS_C-1;
      historyBest        : natural range 0 to HISTORY_DEPTH_C-1;
      historySampleTicks : slv(63 downto 0);
      historyPhase       : slv(PTP_TICK_PHASE_BITS_C-1 downto 0);
      rateWord           : natural range 0 to 7;
      rateInput          : sl;
   end record;

   constant REG_INIT_C : RegType := (
      rxReady             => '0',
      delayReady          => '0',
      e2eTake             => '0',
      portStatus          => PTP_PORT_STATUS_INIT_C,
      rejectedPending     => 0,
      readSlave           => AXI_LITE_READ_SLAVE_INIT_C,
      writeSlave          => AXI_LITE_WRITE_SLAVE_INIT_C,
      candidate           => initialCache,
      configBus           => PTP_REGISTER_BUS_INIT_C,
      configMaster        => PTP_REGISTER_MASTER_INIT_C,
      validateValue       => (others => '0'),
      validatePrevious    => (others => '0'),
      configValid         => '1',
      activeConfig        => initialCache,
      lastMac             => (others => '0'),
      sequenceId          => (others => '0'),
      publicationPort     => PTP_PUBLICATION_INIT_C,
      snapshotBus         => PTP_REGISTER_BUS_INIT_C,
      counterBus          => PTP_REGISTER_BUS_INIT_C,
      announceWord        => 0,
      announceStored      => '0',
      exchangeWriting     => '0',
      exchangeWord        => 0,
      pairState           => PAIR_IDLE_S,
      pairWord            => 0,
      pairKey             => (others => '0'),
      pairBorn            => (others => '0'),
      pairNew             => '0',
      pairDuplicateEqual  => '1',
      pairWriteSync       => '0',
      pairWriteFollow     => '0',
      pairPublish         => '0',
      pairUsed            => (others => '0'),
      pairSyncSeen        => (others => '0'),
      pairTwoStep         => (others => '0'),
      pairFollowSeen      => (others => '0'),
      pairComplete        => (others => '0'),
      pairIndex           => 0,
      pairSlot            => -1,
      pairMatch           => -1,
      pairFree            => -1,
      pairOldest          => -1,
      pairOldestBorn      => (others => '0'),
      pairTicks           => (others => '0'),
      pairReadEnable      => '0',
      pairReadAddress     => (others => '0'),
      pairWriteEnable     => '0',
      pairWriteAddress    => (others => '0'),
      pairWriteData       => (others => '0'),
      historyState        => HISTORY_IDLE_S,
      normalizedValid     => '0',
      normalizedWord      => (others => '0'),
      historyIndex        => 0,
      historyTicks        => (others => '0'),
      historyFound        => '0',
      historyQualified    => '0',
      historyDistance     => (others => '0'),
      scanState           => SCAN_IDLE_S,
      scanHistory         => '0',
      scanTurn            => '1',
      scanWord            => 0,
      scanValue           => (others => '0'),
      scanCarry           => '1',
      scanZero            => '1',
      scanExpired         => '0',
      scanBetter          => '0',
      historyReadEnable   => '0',
      historyReadAddress  => (others => '0'),
      historyWriteEnable  => '0',
      historyWriteData    => (others => '0'),
      historyWriteBusy    => '0',
      historyWriteWord    => 0,
      historyWord         => 0,
      historyBest         => 0,
      historySampleTicks  => (others => '0'),
      historyPhase        => (others => '0'),
      historyWriteAddress => (others => '0'),
      historyValid        => (others => '0'),
      historyPtr          => 0,
      generation          => (others => '0'),
      lastTicks           => (others => '0'),
      syncLimit           => (others => '0'),
      announceLimit       => (others => '0'),
      ratio               => slv(NOMINAL_C),
      ratioTicks          => (others => '0'),
      state               => IDLE_S,
      rateWord            => 0,
      rateInput           => '0',
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
      announceSeen        => '0',
      announceTicks       => (others => '0'));

   signal r                : RegType := REG_INIT_C;
   signal rin              : RegType;
   signal abortNow         : sl;
   signal responseAccepted : sl;
   signal responseReady    : sl;
   signal responseValid    : sl;
   signal allocate         : sl;
   signal allocateReady    : sl;
   signal allocateSequence : slv(15 downto 0);
   signal delaySample      : PtpDelaySampleType;
   signal delayValid       : sl;
   signal delayReady       : sl;
   signal ledgerRejected   : slv(31 downto 0);
   signal normalizedValid : sl;
   signal normalizedReady : sl;
   signal normalizedWord : slv(2 downto 0);
   signal e2eInput         : sl;
   signal e2eReady         : sl;
   signal e2eSync          : PtpSyncSampleType;
   signal rateReady      : sl;
   signal rateRatio      : slv(63 downto 0);
   signal rateQualified  : sl;
   signal rateUpdate     : sl;
   signal rateNormalized : slv(127 downto 0);
   signal rateCorrection : slv(127 downto 0);
   signal rateForward    : slv(127 downto 0);
   signal rateAccepted   : sl;
   signal rateRejected   : slv(31 downto 0);

   signal e2eResult        : PtpMeasurementType;
   signal e2eValid         : sl;
   signal e2eTake          : sl;
   signal e2eError         : sl;
   signal historyReadData  : slv(31 downto 0);
   signal pairReadData     : slv(31 downto 0);
   -- Elaborate the accepted exponent range once. Negative exponents first
   -- round down to whole ticks, then receipt timeouts multiply those ticks by
   -- three, matching the wire policy. No runtime shifter or multiplier is used.
   type IntervalType is record
      valid   : boolean;
      ticks   : unsigned(63 downto 0);
      receipt : unsigned(63 downto 0);
   end record;

   type IntervalArray is array (MIN_LOG_INTERVAL_C to MAX_LOG_INTERVAL_C) of IntervalType;

   function intervalTable return IntervalArray is
      variable values : IntervalArray;
      variable ticks  : unsigned(63 downto 0);
   begin
      for exponent in values'range loop
         ticks := to_unsigned(CLK_FREQ_G, 64);
         if exponent < 0 then
            ticks := shift_right(ticks, -exponent);
         else
            ticks := shift_left(ticks, exponent);
         end if;
         values(exponent).valid := true;
         values(exponent).ticks := ticks;
         values(exponent).receipt := resize(ticks*RECEIPT_INTERVALS_C, 64);
      end loop;
      return values;
   end function;

   constant INTERVAL_TABLE_C : IntervalArray := intervalTable;

   function decodeInterval(logInterval : slv(7 downto 0)) return IntervalType is
      variable value : IntervalType := (false, (others => '0'), (others => '0'));
   begin
      for exponent in INTERVAL_TABLE_C'range loop
         if logInterval = slv(to_signed(exponent, 8)) then
            value := INTERVAL_TABLE_C(exponent);
         end if;
      end loop;
      return value;
   end function;

   -- IEEE 1588-2019 13.2 and Table 37: reserved flags are ignored on receipt.
   constant RESERVED_FLAGS_MASK_C : slv(15 downto 0) := x"9880";
   -- Leap flags are mutually exclusive. Unsupported assigned upper-octet
   -- flags remain outside this multicast endpoint's selected options.
   -- Layer-2 controlField is ignored per 13.3.2.13, including legacy values.
   function validAnnounce (message : PtpRxMessageType) return boolean is
   begin
      return (message.flags and PTP_LEAP_FLAGS_MASK_C) /= PTP_LEAP_FLAGS_MASK_C and
         (message.flags and PTP_GENERAL_RESERVED_C and not RESERVED_FLAGS_MASK_C) = x"0000";
   end function;

   function buildRequest (
      cfg   : PtpPortConfigType;
      mac   : slv(47 downto 0);
      seqId : slv(15 downto 0)) return slv is
      constant MESSAGE_LENGTH_C : slv(15 downto 0)                   := toSlv(PTP_TIMESTAMP_MSG_BYTES_C, 16);
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
      -- 2019 Layer-2 transmits controlField=0; retain the 2008 encoding only
      -- when software explicitly selects minor version 0 compatibility.
      if cfg.minorVersion = PTP_MINOR_VERSION_MIN_C then
         bytes(46) := PTP_CONTROL_DELAY_REQ_C;
      end if;

      bytes(47) := PTP_LOG_INTERVAL_UNSPECIFIED_C;   -- logMessageInterval.
      -- Reserved fields, flags, correctionField and originTimestamp (48..57)
      -- retain their zero initialization. Pack into low-byte-first AXI lanes.
      for i in bytes'range loop
         resultValue(8*i+7 downto 8*i) := bytes(i);
      end loop;
      return resultValue;
   end function;

   signal ledgerStatus : slv(31 downto 0);
   signal timeoutCount : slv(31 downto 0);
   function exchangeRecord(sync : PtpSyncSampleType;
   delay : PtpDelaySampleType) return PtpExchangeType is
      variable ret : PtpExchangeType;
   begin
      ret.t1 := sync.remoteTime;
      ret.t2 := sync.capture.timestamp;
      ret.t3 := delay.capture.timestamp;
      ret.t4 := delay.remoteTime;
      ret.syncCorrection := sync.correction;
      ret.delayCorrection := delay.correction;
      ret.generation := delay.generation;
      ret.syncSequence := sync.sequenceId;
      ret.delaySequence := delay.sequenceId;
      return ret;
   end function;

   function exchangeWord(item : PtpExchangeType;
   index : natural) return slv is
      variable word : slv(31 downto 0) := (others => '0');
   begin

      case index is
         when 0 to 2 =>
            word := slv(resize(shift_right(unsigned(item.t1),32*index),32));
         when 3 to 5 =>
            word := slv(resize(shift_right(unsigned(item.t2),32*(index-3)),32));
         when 6 to 8 =>
            word := slv(resize(shift_right(unsigned(item.t3),32*(index-6)),32));
         when 9 to 11 =>
            word := slv(resize(shift_right(unsigned(item.t4),32*(index-9)),32));
         when 12 to 15 =>
            word := slv(resize(shift_right(unsigned(item.syncCorrection),32*(index-12)),32));
         when 16 to 17 =>
            word := slv(resize(shift_right(unsigned(item.delayCorrection),32*(index-16)),32));
         when 18 =>
            word := item.generation;
         when 19 =>
            word := item.delaySequence & item.syncSequence;
         when others =>
            null;
      end case;

      return word;
   end function;

   signal snapshotSlave : PtpRegisterSlaveType;
   signal counterSlave : PtpRegisterSlaveType;
   signal snapshotScalars : Slv32Array(0 to 6);
   signal configMasters : PtpRegisterMasterArray(0 to 1);
   signal configSlaves : PtpRegisterSlaveArray(0 to 1);
   signal scanValid : sl;
   signal scanIndex : slv(7 downto 0);
   signal scanData : slv(31 downto 0);

begin

   snapshotScalars <=
   (
      rxCounters.accepted,
      rxCounters.dropped,
      rxCounters.overflow,
      r.portStatus.rejectedCount,
      r.portStatus.syncCount,
      r.portStatus.delayCount,
      timeoutCount
   );

   U_Publication : entity surf.PtpPublicationBank
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         RECORD_WORDS_G => IntegerArray'(12,20),
         MEMORY_TYPE_G  => "block")
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
         WORDS_G        => 7)
      port map (
         clk      => clk,
         rst      => rst,
         scalars  => snapshotScalars,
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
         DEFAULTS_G     => initialWords,
         MEMORY_TYPE_G  => "block")
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

   assert HISTORY_MEMORY_TYPE_G = "distributed" or HISTORY_MEMORY_TYPE_G = "block"
      report "PtpProtocolEngine history memory must be distributed or block" severity failure;
   assert PAIR_MEMORY_TYPE_G = "distributed" or PAIR_MEMORY_TYPE_G = "block"
      report "PtpProtocolEngine pair memory must be distributed or block" severity failure;

   U_HistoryRam : entity surf.SimpleDualPortRam
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         MEMORY_TYPE_G  => HISTORY_MEMORY_TYPE_G,
         DATA_WIDTH_G   => 32,
         BYTE_WR_EN_G   => false,
         BYTE_WIDTH_G   => 32,
         ADDR_WIDTH_G   => HISTORY_ADDR_WIDTH_C,
         SYNTH_MODE_G   => "inferred",
         COMMON_CLK_G   => true,
         READ_LATENCY_G => 1)
      port map (
         clka  => clk,                    -- [in]
         wea   => r.historyWriteEnable,   -- [in]
         addra => r.historyWriteAddress,  -- [in]
         dina  => r.historyWriteData,       -- [in]
         clkb  => clk,                    -- [in]
         enb   => r.historyReadEnable,    -- [in]
         rstb  => rst,                    -- [in]
         addrb => r.historyReadAddress,   -- [in]
         doutb => historyReadData);       -- [out]

   U_PairRam : entity surf.SimpleDualPortRam
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         MEMORY_TYPE_G  => PAIR_MEMORY_TYPE_G,
         DATA_WIDTH_G   => 32,
         BYTE_WR_EN_G   => false,
         BYTE_WIDTH_G   => 32,
         ADDR_WIDTH_G   => PAIR_ADDR_WIDTH_C,
         SYNTH_MODE_G   => "inferred",
         COMMON_CLK_G   => true,
         READ_LATENCY_G => 1)
      port map (
         clka  => clk,                 -- [in]
         wea   => r.pairWriteEnable,   -- [in]
         addra => r.pairWriteAddress,  -- [in]
         dina  => r.pairWriteData,     -- [in]
         clkb  => clk,                 -- [in]
         enb   => r.pairReadEnable,    -- [in]
         rstb  => rst,                 -- [in]
         addrb => r.pairReadAddress,   -- [in]
         doutb => pairReadData);       -- [out]

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
         config           => portConfig(r.activeConfig),        -- [in]
         allocate         => allocate,              -- [in]
         allocateReady    => allocateReady,         -- [out]
         allocateSequence => allocateSequence,      -- [out]
         wireMessage      => txMessage,             -- [in]
         wireReady        => txMessageReady,        -- [out]
         wireValid        => txValid,               -- [in]
         response         => r.response,            -- [in]
         responseReady    => responseReady,         -- [out]
         responseValid    => responseValid,         -- [in]
         sample           => delaySample,           -- [out]
         sampleValid      => delayValid,            -- [out]
         sampleReady      => delayReady,            -- [in]
         timeoutCount     => timeoutCount,          -- [out]
         ledgerStatus     => ledgerStatus,          -- [out]
         responseAccepted => responseAccepted,      -- [out]
         rejectedCount    => ledgerRejected);       -- [out]

   -- Payload comes directly from synchronous RAM; valid and word ownership
   -- are registered on the same return edge and held through a stalled upload.
   normalizedValid <= r.normalizedValid;
   normalizedWord  <= r.normalizedWord;

   U_E2e : entity surf.PtpE2e
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         INGRESS_LATENCY_G => INGRESS_LATENCY_G,
         EGRESS_LATENCY_G  => EGRESS_LATENCY_G,
         NORMALIZED_SYNC_G => true)
      port map (
         normalizedValid => normalizedValid,
         normalizedReady => normalizedReady,
         normalizedWord  => normalizedWord,
         normalizedData  => historyReadData,
         clk             => clk,           -- [in]
         rst             => rst,           -- [in]
         cancel          => abortNow,      -- [in]
         inputValid      => e2eInput,      -- [in]
         inputReady      => e2eReady,      -- [out]
         syncSample      => e2eSync,       -- [in]
         delaySample     => r.e2eDelay,    -- [in]
         ratio           => r.e2eRatio,    -- [in]
         maxPathDelay    => r.e2eMaximum,  -- [in]
         resultValue     => e2eResult,     -- [out]
         resultValid     => e2eValid,      -- [out]
         resultReady     => e2eTake,       -- [in]
         resultError       => e2eError,              -- [out]
         divideValid       => divideValid(1),        -- [out]
         divideReady       => divideReady(1),        -- [in]
         divideOperandA    => divideOperandA(1),     -- [out]
         divideOperandB    => divideOperandB(159 downto 80),  -- [out]
         divideCancel      => divideCancel(1),       -- [out]
         divideResultValid => divideResultValid(1),  -- [in]
         divideResultReady => divideResultReady(1),  -- [out]
         divideResultValue => divideResultValue(1),  -- [in]
         divideResultError => divideResultError(1));  -- [in]

   -- Rate measurement is a separate responsibility from protocol policy.
   U_RateEstimator : entity surf.PtpRateEstimator
      generic map (
         TPD_G                => TPD_G,
         RST_POLARITY_G       => RST_POLARITY_G,
         RST_ASYNC_G          => RST_ASYNC_G,
         CLK_FREQ_G           => CLK_FREQ_G,
         MAX_OSCILLATOR_PPB_G => MAX_OSCILLATOR_PPB_C,
         QUALIFY_COUNT_G      => RATIO_QUALIFY_COUNT_C)
      port map (
         clk                => clk,                     -- [in]
         rst                => rst,                     -- [in]
         cancel             => abortNow,                -- [in]
         inputValid         => r.rateInput,             -- [in]
         inputReady         => rateReady,               -- [out]
         syncSample         => r.pendingSync,           -- [in]
         minimumSpan        => r.activeConfig.minRateSpan,  -- [in]
         ratio              => rateRatio,               -- [out]
         ratioValid         => rateQualified,           -- [out]
         ratioUpdate        => rateUpdate,              -- [out]
         normalizedTime     => rateNormalized,          -- [out]
         combinedCorrection => rateCorrection,          -- [out]
         forwardValue       => rateForward,             -- [out]
         sampleAccepted     => rateAccepted,            -- [out]
         rejectedCount      => rateRejected,            -- [out]
         divideValid        => divideValid(0),          -- [out]
         divideReady        => divideReady(0),          -- [in]
         divideOperandA     => divideOperandA(0),       -- [out]
         divideOperandB     => divideOperandB(79 downto 0),  -- [out]
         divideCancel       => divideCancel(0),         -- [out]
         divideResultValid  => divideResultValid(0),    -- [in]
         divideResultReady  => divideResultReady(0),    -- [out]
         divideResultValue  => divideResultValue(0),    -- [in]
         divideResultError  => divideResultError(0));   -- [in]

   comb : process (all) is
      variable readAddress      : slv(11 downto 0);
      variable writeAddress     : slv(11 downto 0);
      variable v                : RegType;
      variable ep               : AxiLiteEndpointType;
      variable configReadIndex  : integer range -1 to 47;
      variable configWriteIndex : integer range -1 to 47;
      variable configIndexValue : natural range 0 to 255;
      variable snapshotIndex    : integer range -1 to 31;
      variable snapshotAddress  : natural range 0 to 1023;
      -- Same-edge admission/cancellation decisions.
      variable announceChange   : sl;
      variable externalAbort    : sl;
      variable abortPort        : sl;
      variable policyValid      : sl;
      variable qualifiedRatio   : sl;
      variable historyStarting  : boolean;
      variable validResponse    : sl;
      variable malformed        : boolean;
      variable rejectedEvents   : natural range 0 to 9;
      variable rejectedSum      : unsigned(32 downto 0);
      variable policyFlags      : slv(15 downto 0);
      variable rxInterval       : IntervalType;
      variable responseInterval : IntervalType;
      variable rxReceiptLimit   : unsigned(63 downto 0);
      -- Bounded table searches (-1 means no match) and timestamp arithmetic.
      variable slot        : integer range -1 to PAIR_DEPTH_C-1;
      variable pair        : PairType;
      variable pairUpdated : boolean;
      variable scanA       : slv(95 downto 0);
      variable scanB       : slv(95 downto 0);
      variable scanLeft    : unsigned(31 downto 0);
      variable scanRight   : unsigned(31 downto 0);
      variable scanCarryIn : unsigned(32 downto 0);
      variable scanAlu     : unsigned(32 downto 0);
      variable scanLast    : natural range 1 to 2;
      variable pairWord    : slv(31 downto 0);
      variable remoteTime  : slv(95 downto 0);
      variable inputSample : PtpSyncSampleType;
   begin
      v := r;
      -- Compare the retained Announce deadline before admission/cancellation
      -- selects the next state. A new Announce selects its own comparison;
      -- final cancellation clears validity without feeding another age ALU.
      v.portStatus.announceValid := '0';
      if not ptpAgeExpired(phcStatus.ticks, r.announceTicks, r.announceLimit) then
         v.portStatus.announceValid := r.announceSeen;
      end if;
      rejectedEvents := 0;
      v.publicationPort.write := '0';
      v.publicationPort.commit := '0';
      pair        := PAIR_INIT_C;
      pairUpdated := false;
      pairWord    := (others => '0');
      remoteTime  := x"0000" & ptpMessageTimestamp(rxMessage);
      inputSample := PTP_SYNC_SAMPLE_INIT_C;
      inputSample.sequenceId := rxMessage.sequenceId;
      inputSample.capture := rxMessage.capture;
      inputSample.remoteTime := ptpMessageTimestamp(rxMessage);
      v.pairReadEnable     := '0';
      v.pairWriteEnable    := '0';
      v.historyReadEnable  := '0';
      v.historyWriteEnable := '0';
      policyFlags := rxMessage.flags and not RESERVED_FLAGS_MASK_C;
      -- Sync and Announce share one decoder and capped receipt preparation.
      -- A previously submitted Delay_Resp may complete on this same edge, so
      -- its held log interval needs an independent lookup (no added latency).
      rxInterval := decodeInterval(rxMessage.logInterval);
      responseInterval := decodeInterval(r.responseLog);
      rxReceiptLimit := unsigned(r.activeConfig.syncTimeout);
      if rxMessage.messageType = PTP_MSG_ANNOUNCE_C then
         rxReceiptLimit := resize(rxReceiptLimit*ANNOUNCE_CAP_FACTOR_C, 64);
      end if;
      if rxInterval.valid and rxInterval.receipt < rxReceiptLimit then
         rxReceiptLimit := rxInterval.receipt;
      end if;

      v.configMaster.cancel := '0';
      v.configMaster.responseReady := '1';

      if r.configMaster.valid = '1' and configSlaves(1).ready = '1' then
         v.configMaster.valid := '0';
      end if;

      -- Requests retain their complete payload until the child accepts them.
      -- The RAM ledger scans the held response before accepting it. Retain
      -- its log interval for the registered acceptance result on the next edge.
      if r.responseValid = '1' and responseReady = '1' then
         v.responseValid := '0';
         v.responseLog   := r.response.logInterval;
      end if;

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
      elsif ptpAgeExpired(phcStatus.ticks, rxMessage.capture.ticks, r.activeConfig.associationTimeout) then
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
         if ptpAgeExpired(phcStatus.ticks, r.lastTicks, r.syncLimit) then
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
      abortPort      := abortPort or r.measurementMaster.abort;
      -- The estimator reports whether its ratio is qualified; freshness for
      -- this consumer is the separate age test.
      qualifiedRatio := '0';

      if rateQualified = '1' and
         not ptpAgeExpired(phcStatus.ticks, r.ratioTicks, r.activeConfig.maxRateAge) then
         qualifiedRatio := '1';
      end if;

      -------------------------------------------------------------------------
      -- Shared 32-bit scan arithmetic. Subtraction uses complemented B and
      -- carry=1; carry out is inverse borrow. Age discards the final borrow
      -- (modulo 64), while Q3 distance keeps all 68 signed bits before ABS.
      -------------------------------------------------------------------------
      scanA := (others => '0');
      scanB := (others => '0');
      scanLast := 1;
      case r.scanState is
         when SCAN_AGE_S =>
            scanA(63 downto 0) := r.pairTicks;
            scanB(63 downto 0) := r.pairBorn;
            if r.scanHistory = '1' then
               scanA(63 downto 0) := r.historyTicks;
               scanB(63 downto 0) := r.historySampleTicks;
            end if;
         when SCAN_AGE_LIMIT_S =>
            scanA(63 downto 0) := r.scanValue(63 downto 0);
            scanB(63 downto 0) := r.activeConfig.associationTimeout;
         when SCAN_DISTANCE_S =>
            scanA(66 downto 0) := r.e2eDelay.capture.ticks & r.e2eDelay.capture.tickPhase;
            scanB(66 downto 0) := r.historySampleTicks & r.historyPhase;
            scanLast := 2;
         when SCAN_ABS_S =>
            scanB(67 downto 0) := r.scanValue;
            scanLast := 2;
         when SCAN_LIMIT_S =>
            scanA(67 downto 0) := r.scanValue;
            scanB(66 downto 0) := r.activeConfig.maxExchange & toSlv(0,PTP_TICK_PHASE_BITS_C);
            scanLast := 2;
         when SCAN_BEST_S =>
            scanA(63 downto 0) := r.pairBorn;
            scanB(63 downto 0) := r.pairOldestBorn;
            if r.scanHistory = '1' then
               scanA(67 downto 0) := r.scanValue;
               scanB(67 downto 0) := r.historyDistance;
               scanLast := 2;
            end if;
         when others =>
            null;
      end case;

      -- Static word slices avoid a variable shift. There is one word ALU for
      -- subtraction, negation and comparison across both table owners.
      scanLeft := (others => '0');
      scanRight := (others => '0');
      for i in 0 to 2 loop
         if r.scanWord = i then
            scanLeft := unsigned(scanA(32*i+31 downto 32*i));
            scanRight := unsigned(scanB(32*i+31 downto 32*i));
         end if;
      end loop;
      scanCarryIn := (others => '0');
      scanCarryIn(0) := r.scanCarry;
      scanAlu := ('0' & scanLeft) + ('0' & not scanRight) + scanCarryIn;

      case r.scanState is
         when SCAN_IDLE_S =>

            if r.pairState = PAIR_SCAN_S or r.historyState = HISTORY_SCAN_S then
               v.scanHistory := '0';
               if r.historyState = HISTORY_SCAN_S and
                  (r.pairState /= PAIR_SCAN_S or r.scanTurn = '1') then
                  v.scanHistory := '1';
               end if;
               v.scanTurn := not v.scanHistory;
               v.scanState := SCAN_AGE_S;
               v.scanWord := 0;
               v.scanCarry := '1';
               v.scanZero := '1';
               v.scanValue := (others => '0');
               v.scanExpired := '0';
            end if;

         when SCAN_DONE_S =>
            v.scanState := SCAN_IDLE_S;

         when others =>
            v.scanCarry := scanAlu(32);
            v.scanZero := r.scanZero and toSl(scanAlu(31 downto 0) = 0);
            if r.scanState = SCAN_AGE_S or r.scanState = SCAN_DISTANCE_S or r.scanState = SCAN_ABS_S then
               case r.scanWord is
                  when 0 =>
                     v.scanValue(31 downto 0) := slv(scanAlu(31 downto 0));
                  when 1 =>
                     v.scanValue(63 downto 32) := slv(scanAlu(31 downto 0));
                  when 2 =>
                     v.scanValue(67 downto 64) := slv(scanAlu(3 downto 0));
               end case;
            end if;

            if r.scanWord /= scanLast then
               v.scanWord := r.scanWord+1;
            else
               case r.scanState is
                  when SCAN_AGE_S =>
                     v.scanState := SCAN_AGE_LIMIT_S;
                  when SCAN_AGE_LIMIT_S =>
                     v.scanExpired := scanAlu(32) and not v.scanZero;
                     v.scanState := SCAN_BEST_S;
                     if r.scanHistory = '1' then
                        v.scanState := SCAN_DISTANCE_S;
                     end if;
                  when SCAN_DISTANCE_S =>
                     v.scanState := SCAN_LIMIT_S;
                     if scanAlu(32) = '0' then
                        v.scanState := SCAN_ABS_S;
                     end if;
                  when SCAN_ABS_S =>
                     v.scanState := SCAN_LIMIT_S;
                  when SCAN_LIMIT_S =>
                     v.scanExpired := r.scanExpired or (scanAlu(32) and not v.scanZero);
                     v.scanState := SCAN_BEST_S;
                  when SCAN_BEST_S =>
                     v.scanBetter := not scanAlu(32);
                     v.scanState := SCAN_DONE_S;
                  when others =>
                     null;
               end case;
               v.scanWord := 0;
               v.scanCarry := '1';
               v.scanZero := '1';
            end if;
      end case;

      -------------------------------------------------------------------------
      -- History lookup owns a stable table and admission-time arithmetic inputs.
      -------------------------------------------------------------------------
      -- Appends reuse the rate producer's held sample. A lookup pins the
      -- table until its selected record is copied; it never sees a partial row.
      if r.historyWriteBusy = '1' and r.historyState = HISTORY_IDLE_S and r.historyWriteWord < 17 then
         v.historyWriteEnable := '1';
         v.historyWriteAddress := toSlv(HISTORY_WORDS_C*r.historyPtr+r.historyWriteWord, HISTORY_ADDR_WIDTH_C);
         v.historyWriteData := syncWord(r.pendingSync, r.historyWriteWord);
         v.historyWriteWord := r.historyWriteWord+1;
      end if;

      -- Only this admission can leave an idle history machine. Reuse its
      -- predicate below instead of decoding the complete combinational next
      -- state, which also contains the compute memory-ready return path.
      historyStarting := delayValid = '1' and r.e2eBusy = '0' and r.historyWriteBusy = '0' and
                         r.historyWriteEnable = '0' and abortPort = '0';
      case r.historyState is
         when HISTORY_IDLE_S =>

            if historyStarting then
               v.delayReady := '1';
               v.e2eBusy := '1';
               v.e2eDelay := delaySample;
               v.e2eRatio := rateRatio;
               v.e2eMaximum := r.activeConfig.maxPathDelay;
               v.historyTicks := phcStatus.ticks;
               v.historyQualified := qualifiedRatio;
               v.historyFound := '0';
               v.historyIndex := 0;
               v.historyWord := 0;
               v.historyReadAddress := (others => '0');
               v.historyReadEnable := '1';
               v.historyState := HISTORY_READ_S;
            end if;

         when HISTORY_READ_S =>
            v.historyState := HISTORY_CHECK_S;
         when HISTORY_CHECK_S =>

            case r.historyWord is
               when 0 to 1 =>
                  v.historySampleTicks(32*r.historyWord+31 downto 32*r.historyWord) := historyReadData;
               when 2 =>
                  v.historyPhase := historyReadData(PTP_TICK_PHASE_BITS_C-1 downto 0);
               when others =>
                  v.historyState := HISTORY_NEXT_S;

                  if r.historyValid(r.historyIndex) = '1' then
                     if historyReadData = r.e2eDelay.generation then
                        v.historyState := HISTORY_SCAN_S;
                     end if;
                  end if;

            end case;

            if r.historyWord /= 3 then
               v.historyWord := r.historyWord+1;
               v.historyReadAddress := toSlv(HISTORY_WORDS_C*r.historyIndex+r.historyWord+1, HISTORY_ADDR_WIDTH_C);
               v.historyReadEnable := '1';
               v.historyState := HISTORY_READ_S;
            end if;

         when HISTORY_SCAN_S =>

            if r.scanState = SCAN_DONE_S and r.scanHistory = '1' then
               if r.scanExpired = '0' and (r.historyFound = '0' or r.scanBetter = '1') then
                  -- Strict comparison retains the first physical slot on ties.
                  v.historyFound := '1';
                  v.historyDistance := r.scanValue;
                  v.historyBest := r.historyIndex;
               end if;
               v.historyState := HISTORY_NEXT_S;
            end if;

         when HISTORY_NEXT_S =>

            if r.historyIndex = HISTORY_DEPTH_C-1 then
               v.historyState := HISTORY_SELECT_S;
            else
               v.historyIndex := r.historyIndex+1;
               v.historyWord := 0;
               v.historyReadAddress := toSlv(HISTORY_WORDS_C*(r.historyIndex+1), HISTORY_ADDR_WIDTH_C);
               v.historyReadEnable := '1';
               v.historyState := HISTORY_READ_S;
            end if;

         when HISTORY_SELECT_S =>
            v.historyState := HISTORY_DONE_S;

            if r.historyFound = '1' and r.historyQualified = '1' then
               v.historyWord := 0;
               v.historyReadAddress := toSlv(HISTORY_WORDS_C*r.historyBest, HISTORY_ADDR_WIDTH_C);
               v.historyReadEnable := '1';
               v.historyState := HISTORY_FETCH_S;
            end if;

         when HISTORY_FETCH_S =>
            v.historyState := HISTORY_CAPTURE_S;
            v.normalizedWord := toSlv((r.historyWord+7) mod 8,3);
            if r.historyWord >= 17 then
               v.normalizedValid := '1';
            end if;
         when HISTORY_CAPTURE_S =>

            if r.historyWord < 17 then
               takeSyncWord(v.e2eSync, r.historyWord, historyReadData);
            end if;

            if r.historyWord < 17 or normalizedReady = '1' then
               v.normalizedValid := '0';
               if r.historyWord = HISTORY_WORDS_C-1 then
                  v.historyState := HISTORY_DONE_S;
               else
                  v.historyWord := r.historyWord+1;
                  v.historyReadAddress := toSlv(HISTORY_WORDS_C*r.historyBest+r.historyWord+1, HISTORY_ADDR_WIDTH_C);
                  v.historyReadEnable := '1';
                  v.historyState := HISTORY_FETCH_S;
               end if;
            end if;

         when HISTORY_DONE_S =>
            v.historyState := HISTORY_IDLE_S;

            if r.historyFound = '1' and r.historyQualified = '1' then
               v.e2eInput := '1';
               v.exchangeWriting := '1';
               v.exchangeWord := 0;
            else
               v.e2eBusy := '0';
               rejectedEvents := rejectedEvents+1;
            end if;

      end case;

      -- Stream the stable E2E producer fields once into the result store.
      -- The arithmetic client owns these inputs until result retirement; no
      -- separate pendingExchange record is needed.
      if r.exchangeWriting = '1' then
         v.publicationPort.write := '1';
         v.publicationPort.first := toSl(r.exchangeWord = 0);
         v.publicationPort.recordIndex := x"1";
         v.publicationPort.wordIndex := toSlv(r.exchangeWord,8);
         v.publicationPort.data := exchangeWord(exchangeRecord(r.e2eSync,r.e2eDelay),r.exchangeWord);
         if r.exchangeWord = 19 then
            v.exchangeWriting := '0';
         else
            v.exchangeWord := r.exchangeWord+1;
         end if;
      end if;

      -------------------------------------------------------------------------
      -- RX holds a pair transaction through its shared expiry/key search.
      -------------------------------------------------------------------------
      case r.pairState is
         when PAIR_IDLE_S =>

            if rxValid = '1' and (rxMessage.messageType = PTP_MSG_SYNC_C or rxMessage.messageType = PTP_MSG_FOLLOW_UP_C) and
               r.state = IDLE_S and r.measurementMaster.valid = '0' and
               r.historyState = HISTORY_IDLE_S and not historyStarting and
               r.pairWriteEnable = '0' and r.historyWriteBusy = '0' and e2eValid = '0' and abortPort = '0' then
               v.pairTicks := phcStatus.ticks;
               v.pairIndex := 0;
               v.pairWord := 0;
               v.pairMatch := -1;
               v.pairFree := -1;
               v.pairOldest := -1;
               v.pairPublish := '0';
               v.pairReadAddress := (others => '0');
               v.pairReadEnable := '1';
               v.pairState := PAIR_READ_S;
            end if;

         when PAIR_READ_S =>
            v.pairState := PAIR_CHECK_S;
         when PAIR_CHECK_S =>

            case r.pairWord is
               when 0 =>
                  v.pairKey := pairReadData(15 downto 0);
               when 1 =>
                  v.pairBorn(31 downto 0) := pairReadData;
               when others =>
                  v.pairBorn(63 downto 32) := pairReadData;
            end case;

            if r.pairWord /= 2 then
               v.pairWord := r.pairWord+1;
               v.pairReadAddress := toSlv(PAIR_WORDS_C*r.pairIndex+r.pairWord+1, PAIR_ADDR_WIDTH_C);
               v.pairReadEnable := '1';
               v.pairState := PAIR_READ_S;
            else
               v.pairState := PAIR_NEXT_S;
               if r.pairUsed(r.pairIndex) = '1' then
                  v.pairState := PAIR_SCAN_S;
               end if;
            end if;

         when PAIR_SCAN_S =>

            if r.scanState = SCAN_DONE_S and r.scanHistory = '0' then
               if r.scanExpired = '1' then
                  v.pairUsed(r.pairIndex) := '0';
               else
                  if r.pairKey = rxMessage.sequenceId then
                     v.pairMatch := r.pairIndex;
                  end if;
                  if r.pairComplete(r.pairIndex) = '1' and
                     (r.pairOldest = -1 or r.scanBetter = '1') then
                     v.pairOldest := r.pairIndex;
                     v.pairOldestBorn := r.pairBorn;
                  end if;
               end if;
               v.pairState := PAIR_NEXT_S;
            end if;

         when PAIR_NEXT_S =>

            if r.pairUsed(r.pairIndex) = '0' and r.pairFree = -1 then
               v.pairFree := r.pairIndex;
            end if;
            if r.pairIndex = PAIR_DEPTH_C-1 then
               v.pairState := PAIR_SELECT_S;
            else
               v.pairIndex := r.pairIndex+1;
               v.pairWord := 0;
               v.pairReadAddress := toSlv(PAIR_WORDS_C*(r.pairIndex+1), PAIR_ADDR_WIDTH_C);
               v.pairReadEnable := '1';
               v.pairState := PAIR_READ_S;
            end if;

         when PAIR_SELECT_S =>
            v.pairSlot := r.pairMatch;
            v.pairNew := '0';
            v.pairDuplicateEqual := '1';
            v.pairWriteSync := '0';
            v.pairWriteFollow := '0';
            v.pairState := PAIR_DECIDE_S;

            if r.pairMatch = -1 then
               v.pairNew := '1';
               v.pairSlot := r.pairFree;
               if r.pairFree = -1 then
                  v.pairSlot := r.pairOldest;
               end if;
            elsif rxMessage.messageType = PTP_MSG_FOLLOW_UP_C and r.pairFollowSeen(r.pairMatch) = '1' then
               -- Duplicate identity is checked without reconstructing the row.
               v.pairWord := 5;
               v.pairReadAddress := toSlv(PAIR_WORDS_C*r.pairMatch+5, PAIR_ADDR_WIDTH_C);
               v.pairReadEnable := '1';
               v.pairState := PAIR_COMPARE_READ_S;
            end if;

         when PAIR_COMPARE_READ_S =>
            v.pairState := PAIR_COMPARE_S;
         when PAIR_COMPARE_S =>

            if r.pairWord <= 6 then
               pairWord := rxMessage.correction(32*(r.pairWord-5)+31 downto 32*(r.pairWord-5));
            else
               pairWord := remoteTime(32*(r.pairWord-17)+31 downto 32*(r.pairWord-17));
            end if;

            v.pairDuplicateEqual := r.pairDuplicateEqual and toSl(pairWord = pairReadData);

            if r.pairWord = 19 then
               v.pairState := PAIR_DECIDE_S;
            else
               v.pairWord := r.pairWord+1;
               if r.pairWord = 6 then
                  v.pairWord := 17;
               end if;
               v.pairReadAddress := toSlv(PAIR_WORDS_C*r.pairSlot+v.pairWord, PAIR_ADDR_WIDTH_C);
               v.pairReadEnable := '1';
               v.pairState := PAIR_COMPARE_READ_S;
            end if;

         when PAIR_DECIDE_S =>
            v.pairState := PAIR_ACK_S;

            if r.pairSlot /= -1 and r.pairNew = '0' then
               pair.used := '1';
               pair.sequenceId := rxMessage.sequenceId;
               pair.syncSeen := r.pairSyncSeen(r.pairSlot);
               pair.twoStep := r.pairTwoStep(r.pairSlot);
               pair.followSeen := r.pairFollowSeen(r.pairSlot);
               pair.complete := r.pairComplete(r.pairSlot);
            end if;

         when PAIR_UPDATE_S =>
            v.pairWriteEnable := r.pairNew;

            case r.pairWord is
               when 0 =>
                  pairWord(15 downto 0) := rxMessage.sequenceId;
               when 1 to 2 =>
                  pairWord := r.pairTicks(32*(r.pairWord-1)+31 downto 32*(r.pairWord-1));
               when 3 to 4 =>

                  if r.pairWriteSync = '1' then
                     pairWord := rxMessage.correction(32*(r.pairWord-3)+31 downto 32*(r.pairWord-3));
                     v.pairWriteEnable := '1';
                  end if;

               when 5 to 6 =>

                  if r.pairWriteFollow = '1' then
                     if rxMessage.messageType = PTP_MSG_FOLLOW_UP_C then
                        pairWord := rxMessage.correction(32*(r.pairWord-5)+31 downto 32*(r.pairWord-5));
                     end if;
                     v.pairWriteEnable := '1';
                  end if;

               when 7 to 16 =>

                  if r.pairWriteSync = '1' then
                     pairWord := syncWord(inputSample, r.pairWord-7);
                     v.pairWriteEnable := '1';
                  end if;

               when 17 to 19 =>

                  if r.pairWriteFollow = '1' then
                     pairWord := syncWord(inputSample, r.pairWord-7);
                     v.pairWriteEnable := '1';
                  end if;

            end case;

            v.pairWriteAddress := toSlv(PAIR_WORDS_C*r.pairSlot+r.pairWord, PAIR_ADDR_WIDTH_C);
            v.pairWriteData := pairWord;

            if r.pairWord = PAIR_WORDS_C-1 then
               v.pairState := PAIR_PUBLISH_S;
            else
               v.pairWord := r.pairWord+1;
            end if;

         when PAIR_PUBLISH_S =>
            v.pairState := PAIR_ACK_S;

            if r.pairPublish = '1' then
               v.pairWord := 3;
               v.pairReadAddress := toSlv(PAIR_WORDS_C*r.pairSlot+3, PAIR_ADDR_WIDTH_C);
               v.pairReadEnable := '1';
               v.pairState := PAIR_PUBLISH_READ_S;
            end if;

         when PAIR_PUBLISH_READ_S =>
            v.pairState := PAIR_PUBLISH_CAPTURE_S;
         when PAIR_PUBLISH_CAPTURE_S =>

            if r.pairWord <= 6 then
               -- Keep the two signed wire corrections here until RATE sums
               -- them in its workspace before normalizing the remote timestamp.
               v.pendingSync.correction(32*(r.pairWord-3)+31 downto 32*(r.pairWord-3)) := pairReadData;
            else
               takeSyncWord(v.pendingSync, r.pairWord-7, pairReadData);
            end if;

            if r.pairWord = PAIR_WORDS_C-1 then
               v.pairState := PAIR_ACK_S;
            else
               v.pairWord := r.pairWord+1;
               v.pairReadAddress := toSlv(PAIR_WORDS_C*r.pairSlot+r.pairWord+1, PAIR_ADDR_WIDTH_C);
               v.pairReadEnable := '1';
               v.pairState := PAIR_PUBLISH_READ_S;
            end if;

         when PAIR_ACK_S =>
            null;
      end case;

      v.rxReady := '0';
      -- A pair's producer is the input holding register throughout the scan.
      -- Acknowledge only when its selected row and publication capacity are
      -- available; registering ready here would require another payload slot.
      if r.state = IDLE_S and r.measurementMaster.valid = '0' and abortPort = '0' and
         r.historyState = HISTORY_IDLE_S and not historyStarting and
         (r.responseValid = '0' or responseReady = '1') then
         if r.pairState = PAIR_ACK_S then
            v.rxReady := '1';
         elsif r.pairState = PAIR_IDLE_S and
            rxMessage.messageType /= PTP_MSG_SYNC_C and rxMessage.messageType /= PTP_MSG_FOLLOW_UP_C then
            v.rxReady := '1';
         end if;
      end if;

      -- Announce body and decoded metadata form one immutable result. Its
      -- producer holds them through this twelve-word upload; acknowledgement publishes RAM ownership
      -- and the public diagnostic record together. Rejected traffic needs no copy.
      if v.rxReady = '1' and rxValid = '1' and rxMessage.messageType = PTP_MSG_ANNOUNCE_C and
         policyValid = '1' and validAnnounce(rxMessage) and r.announceStored = '0' then
         v.rxReady := '0';
         if r.exchangeWriting = '0' then
            v.publicationPort.write := '1';
            v.publicationPort.first := toSl(r.announceWord = 0);
            v.publicationPort.recordIndex := x"0";
            v.publicationPort.wordIndex := toSlv(r.announceWord,8);
            case r.announceWord is
               when 0 to 7 =>
                  v.publicationPort.data := slv(resize(shift_right(unsigned(rxMessage.messageBody),32*r.announceWord),32));
               when 8 to 9 =>
                  v.publicationPort.data := slv(resize(shift_right(unsigned(ptpGrandmasterIdentity(rxMessage)),32*(r.announceWord-8)),32));
               when 10 =>
                  v.publicationPort.data := x"0000" & rxMessage.flags;
               when others =>
                  v.publicationPort.data := x"0000" & ptpUtcOffset(rxMessage);
            end case;
            if r.announceWord = 11 then
               v.announceStored := '1';
               v.announceWord := 0;
            else
               v.announceWord := r.announceWord+1;
            end if;
         end if;
      end if;

      if v.rxReady = '1' and rxValid = '1' and rxMessage.messageType = PTP_MSG_ANNOUNCE_C then
         v.announceStored := '0';
         v.announceWord := 0;
      end if;

      validResponse := '0';

      if rxMessage.messageType = PTP_MSG_DELAY_RESP_C and policyFlags = x"0000" and
         unsigned(ptpMessageNanoseconds(rxMessage)) < PTP_NANOSECONDS_PER_SECOND_C then
         validResponse := rxValid and v.rxReady and policyValid;
      end if;

      if validResponse = '1' then
         v.response      := rxMessage;
         v.responseValid := '1';
      end if;

      if responseAccepted = '1' and abortPort = '0' and responseInterval.valid then
         v.minimumInterval := responseInterval.ticks;
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
               v.master.tKeep(TX_BEAT_BYTES_C-1 downto 0)   := TX_LAST_KEEP_C;
               v.master.tLast                               := '1';
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
         v.frame                                      := buildRequest(portConfig(r.activeConfig), localMac, allocateSequence);
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
            -- Unsigned division rounds the half interval down to whole ticks.
            v.requestInterval := v.requestInterval/2;
         elsif r.lfsr(1 downto 0) = "11" then
            v.requestInterval := v.requestInterval + v.requestInterval/2;
         end if;
         -- Fibonacci LFSR taps 16, 14, 13, 11 (one-based); shift toward bit 15,
         -- feed the XOR into bit 0. A nonzero seed avoids the all-zero lockup.
         v.lfsr := r.lfsr(14 downto 0) & (r.lfsr(15) xor r.lfsr(13) xor r.lfsr(12) xor r.lfsr(10));
      end if;

      -------------------------------------------------------------------------
      -- RX association and message dispatch
      -------------------------------------------------------------------------
      -- Expiry is evaluated at scan admission, before selecting a key. RX
      -- payload stays at its producer until this acknowledgement edge.
      -- Consume one message: reject policy failures, otherwise dispatch by type.
      malformed := false;

      if rxValid = '1' and (r.pairState = PAIR_DECIDE_S or
         (v.rxReady = '1' and r.pairState = PAIR_IDLE_S)) then
         if policyValid = '0' then
            malformed := true;
         else

            case rxMessage.messageType is
               when PTP_MSG_SYNC_C | PTP_MSG_FOLLOW_UP_C =>
                  -- Validate message semantics before allocating or changing a slot.
                  if rxMessage.messageType = PTP_MSG_SYNC_C then
                     if policyFlags /= PTP_ONE_STEP_FLAGS_C and policyFlags /= PTP_TWO_STEP_FLAGS_C then
                        malformed := true;
                     elsif policyFlags = PTP_ONE_STEP_FLAGS_C then
                        -- Only one-step Sync carries the authoritative timestamp.
                        -- The two-step Sync body is ignored in favor of Follow_Up.
                        if unsigned(ptpMessageNanoseconds(rxMessage)) >= PTP_NANOSECONDS_PER_SECOND_C then
                           malformed := true;
                        end if;
                     end if;
                  else
                     -- Follow_Up ignores reserved bits and controlField.
                     if policyFlags /= PTP_ONE_STEP_FLAGS_C then
                        malformed := true;
                     elsif unsigned(ptpMessageNanoseconds(rxMessage)) >= PTP_NANOSECONDS_PER_SECOND_C then
                        malformed := true;
                     end if;
                  end if;
                  if not malformed then
                     slot := r.pairSlot;
                     if slot /= -1 then
                        pairUpdated := true;
                        if pair.used = '0' or pair.sequenceId /= rxMessage.sequenceId then
                           pair := PAIR_INIT_C;
                           pair.used              := '1';
                           pair.sequenceId := rxMessage.sequenceId;
                        end if;
                     end if;
                     if slot = -1 then
                        malformed := true;
                     elsif rxMessage.correction = PTP_CORRECTION_OVERFLOW_C then
                        -- Retain a completed key even when this is the first
                        -- half received. Neither arrival order nor a later
                        -- finite duplicate may revive an overflowed exchange.
                        pair.complete := '1';
                        malformed := true;
                     elsif rxMessage.messageType = PTP_MSG_SYNC_C then
                        if pair.syncSeen = '1' or
                           (policyFlags = PTP_ONE_STEP_FLAGS_C and pair.followSeen = '1') then
                           -- Duplicate Sync is ambiguous even if its headers match:
                           -- the physical capture is a different wire event.
                           -- One-step cannot inherit an earlier Follow_Up either.
                           pair.complete := '1';
                           malformed := true;
                        else
                           v.pairWriteSync := '1';
                           pair.syncSeen       := '1';
                           pair.twoStep        := '0';
                           if policyFlags = PTP_TWO_STEP_FLAGS_C then
                              pair.twoStep := '1';
                           else
                              v.pairWriteFollow := '1';
                           end if;
                           v.syncLimit := slv(rxReceiptLimit);
                           if not rxInterval.valid and
                              rxMessage.logInterval /= PTP_LOG_INTERVAL_UNSPECIFIED_C then
                              rejectedEvents := rejectedEvents+1;
                           end if;
                        end if;
                     else
                        if pair.syncSeen = '1' and pair.twoStep = '0' then
                           -- Count inconsistent Follow_Up without changing any
                           -- part of the one-step association, even after use.
                           malformed := true;
                        elsif pair.followSeen = '1' then
                           if r.pairDuplicateEqual = '0' then
                              pair.complete := '1';
                              malformed := true;
                           end if;
                        else
                           v.pairWriteFollow := '1';
                           pair.followSeen        := '1';
                        end if;
                     end if;
                  end if;
               when PTP_MSG_DELAY_RESP_C =>
                  if validResponse = '0' then
                     malformed := true;
                  end if;
               when PTP_MSG_ANNOUNCE_C =>
                  if not validAnnounce(rxMessage) then
                     malformed := true;
                     v.announceSeen := '0';
                     v.portStatus.announceValid := '0';
                  else
                     v.announceSeen                   := '1';
                     v.portStatus.announceValid := toSl(not ptpAgeExpired(
                        phcStatus.ticks, rxMessage.capture.ticks, slv(rxReceiptLimit)));
                     v.publicationPort.commit := '1';
                     v.publicationPort.commitRecord := x"0";
                     v.portStatus.announceBody        := rxMessage.messageBody;
                     v.announceTicks                  := rxMessage.capture.ticks;
                     v.portStatus.grandmasterIdentity := ptpGrandmasterIdentity(rxMessage);
                     v.portStatus.announceFlags       := rxMessage.flags;
                     v.portStatus.utcOffset           := ptpUtcOffset(rxMessage);
                     v.announceLimit                  := slv(rxReceiptLimit);
                     if not rxInterval.valid and
                        rxMessage.logInterval /= PTP_LOG_INTERVAL_UNSPECIFIED_C then
                        rejectedEvents := rejectedEvents+1;
                     end if;
                  end if;
               when others =>
                  malformed := true;
            end case;

         end if;
      end if;

      if malformed then
         rejectedEvents := rejectedEvents+1;
      end if;

      -------------------------------------------------------------------------
      -- Rate estimation handoff and forward-measurement publication
      -------------------------------------------------------------------------
      -- PtpRateEstimator owns the master-time conversion, anchor chronology,
      -- the variable division and ratio qualification. This machine hands it
      -- a completed Sync pair, appends the sample to the history table, then
      -- publishes the forward measurement it returns. Protocol policy stays
      -- here; the measurement arithmetic does not.
      case r.state is
         when IDLE_S =>

            if r.pairState = PAIR_ACK_S and v.rxReady = '1' and rxValid = '1' then
               v.pairState := PAIR_IDLE_S;
               if r.pairPublish = '1' then
                  if ptpAgeExpired(phcStatus.ticks, r.pendingSync.capture.ticks, r.activeConfig.associationTimeout) then
                     rejectedEvents := rejectedEvents+1;
                  else
                     v.state := RATE_SUBMIT_S;
                  end if;
               end if;
            end if;

         when RATE_SUBMIT_S =>
            -- Chronology against the last accepted Sync stays local, because
            -- it gates history admission as well as the rate estimate.
            if r.portStatus.active = '1' and
               unsigned(r.pendingSync.capture.ticks) <= unsigned(r.lastTicks) then
               rejectedEvents := rejectedEvents+1;
               v.state := IDLE_S;
            else
               v.rateInput := '1';
               v.state := RATE_ACCEPT_S;
            end if;

         when RATE_ACCEPT_S =>

            if rateReady = '1' then
               v.rateInput := '0';
               v.portStatus.active := '1';
               v.lastTicks := r.pendingSync.capture.ticks;
               v.portStatus.syncCount := ptpSatInc(v.portStatus.syncCount);
               v.historyWriteBusy := '1';
               v.historyWriteWord := 0;
               v.state := RATE_HISTORY_BEGIN_S;
            end if;

         when RATE_HISTORY_BEGIN_S =>

            if r.historyWriteWord = 17 and r.historyWriteEnable = '0' then
               v.rateWord := 0;
               v.state := RATE_WAIT_S;
            end if;

         when RATE_WAIT_S =>
            -- Wait for the estimator to finish this sample. It publishes the
            -- forward value whether or not the sample also yields a new ratio.
            if rateAccepted = '1' then
               v.state := RATE_HISTORY_READ_S;
            end if;

         when RATE_HISTORY_READ_S =>
            -- Words 17..24 hold the normalized forward value and corrected
            -- Sync time, so the E2E path need not repeat either conversion.
            v.historyWriteEnable := '1';
            v.historyWriteAddress := toSlv(HISTORY_WORDS_C*r.historyPtr+17+r.rateWord, HISTORY_ADDR_WIDTH_C);

            if r.rateWord < 4 then
               v.historyWriteData := rateForward(32*r.rateWord+31 downto 32*r.rateWord);
            else
               v.historyWriteData := rateNormalized(32*(r.rateWord-4)+31 downto 32*(r.rateWord-4));
            end if;

            if r.rateWord = 7 then
               v.state := RATE_HISTORY_DONE_S;
            else
               v.rateWord := r.rateWord+1;
            end if;

         when RATE_HISTORY_DONE_S =>
            v.historyWriteBusy := '0';
            v.historyValid(r.historyPtr) := '1';
            v.historyPtr := (r.historyPtr+1) mod HISTORY_DEPTH_C;
            v.state := RATE_PUBLISH_S;

         when RATE_PUBLISH_S =>

            if rateUpdate = '1' then
               v.ratioTicks := r.pendingSync.capture.ticks;
            end if;

            v.pendingSync.correction := rateCorrection;
            v.measurementMaster.data.isDelay := '0';
            v.measurementMaster.data.generation := r.pendingSync.capture.generation;
            v.measurementMaster.data.ticks := r.pendingSync.capture.ticks;
            v.measurementMaster.data.syncSequence := r.pendingSync.sequenceId;
            v.measurementMaster.data.delaySequence := (others => '0');
            v.measurementMaster.data.delayValue := (others => '0');
            v.measurementMaster.data.forward := rateForward;
            v.measurementMaster.data.ratio := rateRatio;
            v.measurementMaster.data.ratioValid := '0';

            -- Freshness is separate from acceptance: a qualified ratio must
            -- also be recent enough for this sample's consumer.
            if rateQualified = '1' and
               not ptpAgeExpired(phcStatus.ticks, v.ratioTicks, r.activeConfig.maxRateAge) then
               v.measurementMaster.data.ratioValid := '1';
            end if;

            v.measurementMaster.valid := '1';
            v.state := IDLE_S;
      end case;

      -------------------------------------------------------------------------
      -- E2E association and result publication
      -------------------------------------------------------------------------
      -- Result valid is registered; the shared abort takes priority at this
      -- receiver as well as at the arithmetic/ledger producers.
      -- E2E valid blocks a new pair search. With the pair already idle, the
      -- rate machine cannot start (it requires PAIR_ACK_S), so both next-state
      -- idle tests are redundant. Keep compute ready out of publication enables.
      if e2eValid = '1' and abortPort = '0' and r.state = IDLE_S and
         r.pairState = PAIR_IDLE_S and v.measurementMaster.valid = '0' and
         r.exchangeWriting = '0' and v.publicationPort.commit = '0' then
         v.e2eTake := '1';
         v.e2eBusy := '0';
         if e2eError = '0' and qualifiedRatio = '1' then
            v.measurementMaster.data           := e2eResult;
            v.portStatus.exchange := exchangeRecord(r.e2eSync,r.e2eDelay);
            v.publicationPort.commit := '1';
            v.publicationPort.commitRecord := x"1";
            v.measurementMaster.valid          := '1';
            v.portStatus.delayCount            := ptpSatInc(v.portStatus.delayCount);
         else
            rejectedEvents := rejectedEvents+1;
         end if;
      end if;

      -- Ownership changes precede field writes, but RX and rate admission
      -- remain blocked until the selected row has drained its registered write.
      if pairUpdated then
         v.pairPublish := '0';
         if pair.used = '1' and pair.syncSeen = '1' and pair.complete = '0' and
            (pair.twoStep = '0' or pair.followSeen = '1') then
            v.pairPublish := '1';
            pair.complete := '1';
         end if;
         v.pairUsed(r.pairSlot) := pair.used;
         v.pairSyncSeen(r.pairSlot) := pair.syncSeen;
         v.pairTwoStep(r.pairSlot) := pair.twoStep;
         v.pairFollowSeen(r.pairSlot) := pair.followSeen;
         v.pairComplete(r.pairSlot) := pair.complete;
         v.pairWord := 0;
         v.pairState := PAIR_UPDATE_S;
      end if;

      -------------------------------------------------------------------------
      -- Final cancellation priority
      -------------------------------------------------------------------------
      -- Cancellation has final priority over association and publication. TX
      -- drain state and unresolved ledger ownership deliberately survive it.
      if abortPort = '1' then
         -- Keep the TX frame/beat and diagnostic counters. Ledger retirement is
         -- independent and receives the registered abort on the following edge.
         v.pairUsed                := (others => '0');
         v.pairState               := PAIR_IDLE_S;
         v.pairReadEnable          := '0';
         v.pairWriteEnable         := '0';
         v.historyState            := HISTORY_IDLE_S;
         v.scanState               := SCAN_IDLE_S;
         v.scanTurn                := '1';
         v.normalizedValid         := '0';
         v.exchangeWriting := '0';
         v.announceWord := 0;
         v.announceStored := '0';
         v.historyReadEnable       := '0';
         v.historyWriteEnable      := '0';
         v.historyWriteBusy := '0';
         v.historyFound            := '0';
         v.historyValid            := (others => '0');
         v.portStatus.active       := '0';
         v.syncLimit               := r.activeConfig.syncTimeout;
         v.announceLimit           := slv(resize(unsigned(r.activeConfig.syncTimeout)*ANNOUNCE_CAP_FACTOR_C, 64));
         v.configMaster.valid := '0';
         v.configMaster.cancel := '1';
         v.rateInput               := '0';
         v.state                   := IDLE_S;
         v.measurementMaster.valid := '0';
         v.requestStarted          := '0';
         v.minimumInterval         := (others => '0');
         v.announceSeen            := '0';
         v.portStatus.announceValid := '0';
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

      -------------------------------------------------------------------------
      -- Registered diagnostic summaries
      -------------------------------------------------------------------------
      -- Sample derived diagnostic summaries after all protocol updates and
      -- cancellation. Counters, metadata and exchange already live in portStatus.
      -- Register the event multiplicity before full-width saturation. Counts
      -- become visible one cycle after rejection; simultaneous events are kept.
      -- Logical cancellation preserves diagnostics; system reset below wins.
      v.rejectedPending := rejectedEvents;
      rejectedSum := resize(unsigned(r.portStatus.rejectedCount), rejectedSum'length) +
                     to_unsigned(r.rejectedPending, rejectedSum'length);
      v.portStatus.rejectedCount := slv(rejectedSum(31 downto 0));
      if rejectedSum(32) = '1' then
         v.portStatus.rejectedCount := (others => '1');
      end if;

      v.portStatus.ratioValid := '0';

      if rateQualified = '1' and
         not ptpAgeExpired(phcStatus.ticks, v.ratioTicks, r.activeConfig.maxRateAge) then
         v.portStatus.ratioValid := '1';
      end if;


      v.portStatus.ledgerStatus := ledgerStatus;
      v.portStatus.timeoutCount := timeoutCount;
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

      -- Configuration shadows and live identity/status.
      axiSlaveRegisterR(ep, x"030", 0, localMac);
      axiSlaveRegisterR(ep, x"044", 0, r.portStatus.active);
      axiSlaveRegisterR(ep, x"044", 1, r.portStatus.announceValid);
      axiSlaveRegisterR(ep, x"044", 2, r.portStatus.ratioValid);
      axiSlaveRegisterR(ep, x"048", 0, r.portStatus.ledgerStatus);
      axiSlaveRegisterR(ep, x"060", 0, r.activeConfig.localIdentity);
      axiSlaveRegisterR(ep, x"070", 0, r.activeConfig.sourceIdentity);
      -- Protocol timer and acceptance-limit shadows.
      -- Implementation constants and active shared limits.
      axiSlaveRegisterR(ep, x"0C0", 0, slv(to_unsigned(PACKET_LIFETIME_G, 64)));
      axiSlaveRegisterR(ep, x"0D0", 0, INGRESS_LATENCY_G);
      axiSlaveRegisterR(ep, x"0D8", 0, EGRESS_LATENCY_G);
      axiSlaveRegisterR(ep, x"0E0", 0, r.activeConfig.associationTimeout);
      axiSlaveRegisterR(ep, x"0E8", 0, r.activeConfig.syncTimeout);
      axiSlaveRegisterR(ep, x"0F0", 0, r.activeConfig.maxPathDelay);
      axiSlaveRegisterR(ep, x"0F8", 0, toSlv(PTP_MIN_ASSOCIATION_TICKS_C, 32));
      -- Coherent Announce and exchange snapshots.
      -- Coherent RX/protocol counters and snapshot sequence.
      axiSlaveRegisterR(ep, x"3FC", 0, r.sequenceId);
      configReadIndex  := configIndex(readAddress);
      configWriteIndex := configIndex(writeAddress);
      ptpRegisterBus(v.configBus, r.configBus, configSlaves(0), ep, configReadIndex, configWriteIndex,
         configMask(configWriteIndex,ep.axiWriteMaster.wstrb), "00", regRst);
      snapshotIndex   := -1;
      snapshotAddress := to_integer(unsigned(readAddress(11 downto 2)));

      case snapshotAddress is
         when 76 to 79 =>
            snapshotIndex := snapshotAddress-68;
         when 80 to 87 =>
            snapshotIndex := snapshotAddress-80;
         when 88 to 90 =>
            snapshotIndex := snapshotAddress-76;
         when 92 to 94 =>
            snapshotIndex := snapshotAddress-77;
         when 96 to 98 =>
            snapshotIndex := snapshotAddress-78;
         when 100 to 102 =>
            snapshotIndex := snapshotAddress-79;
         when 104 to 111 =>
            snapshotIndex := snapshotAddress-80;
         when others =>
            null;
      end case;

      ptpRegisterBus(v.snapshotBus, r.snapshotBus, snapshotSlave, ep, snapshotIndex, -1, x"00000000", "00", regRst);
      snapshotIndex := -1;

      if snapshotAddress >= 128 and snapshotAddress <= 134 then
         snapshotIndex := snapshotAddress-128;
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
      -- Validate only the frozen candidate streamed by the word bank. Its
      -- preparation handshake keeps the coordinator from sampling a partial vote.
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
               v.candidate.identityOverride := scanData(4);
            when 2 =>
               v.candidate.domainNumber := scanData(7 downto 0);
               v.candidate.minorVersion := scanData(11 downto 8);
               if unsigned(scanData(11 downto 8)) > unsigned(PTP_MINOR_VERSION_MAX_C) then
                  v.configValid := '0';
               end if;
            when 4 to 5 =>
               v.candidate.localIdentity(32*(configIndexValue-4)+31 downto 32*(configIndexValue-4)) := scanData;
               if configIndexValue = 4 and unsigned(scanData(15 downto 0)) = 0 then
                  v.configValid := '0';
               end if;
            when 6 =>
               v.candidate.localIdentity(79 downto 64) := scanData(15 downto 0);
            when 8 to 9 =>
               v.candidate.sourceIdentity(32*(configIndexValue-8)+31 downto 32*(configIndexValue-8)) := scanData;
               if configIndexValue = 8 and unsigned(scanData(15 downto 0)) = 0 then
                  v.configValid := '0';
               end if;
            when 10 =>
               v.candidate.sourceIdentity(79 downto 64) := scanData(15 downto 0);
            when 33 =>
               v.candidate.delayInterval := v.validateValue;
            when 35 =>
               v.candidate.syncTimeout := v.validateValue;
            when 37 =>
               v.candidate.associationTimeout := v.validateValue;
               if unsigned(v.validateValue) < PTP_MIN_ASSOCIATION_TICKS_C then
                  v.configValid := '0';
               end if;
            when 39 =>
               v.candidate.maxExchange := v.validateValue;
            when 41 =>
               v.candidate.minRateSpan := v.validateValue;
               v.validatePrevious := v.validateValue;
            when 43 =>
               v.candidate.maxRateAge := v.validateValue;
               if unsigned(v.validateValue) < unsigned(r.validatePrevious) then
                  v.configValid := '0';
               end if;
            when 44 =>
               v.candidate.lfsrSeed := scanData(15 downto 0);
            when 47 =>
               v.candidate.maxPathDelay := v.validateValue;
               if signed(v.validateValue) <= 0 then
                  v.configValid := '0';
               end if;
            when others =>
               null;
         end case;

         if configIndexValue >= 33 and configIndexValue <= 43 and configIndexValue mod 2 = 1 then
            if not ptpValidTimeout(v.validateValue) then
               v.configValid := '0';
            end if;
         end if;
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

      if snapshotControl.publish = '1' then
         v.sequenceId := snapshotControl.sequenceId;
      end if;

      -- Apply synchronous reset before publishing next state and outputs.
      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;

      rin <= v;
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
