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
-- use the package measurement records. PtpPortStatusType groups live status
-- and diagnostics; snapshot storage remains in this module. Active local registers are the sole configuration source;
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
      rxQueueOverflow     : in  sl            := '0';
      rxAbort             : in  sl;
      txMessage           : in  PtpRxMessageType;
      txValid             : in  sl;
      txAbort             : in  sl;
      txMaster            : out AxiStreamMasterType;
      txSlave             : in  AxiStreamSlaveType;
      measurementMaster   : out PtpMeasurementMasterType;
      measurementSlave    : in  PtpMeasurementSlaveType;
      status              : out PtpPortStatusType);
end entity PtpPort;

architecture rtl of PtpPort is

   function initialConfig return PtpPortConfigType is
      variable v      : PtpPortConfigType := PTP_PORT_CONFIG_INIT_C;
      constant TICK_C : unsigned(63 downto 0) := to_unsigned(CLK_FREQ_G, 64);

   begin
      v.delayInterval := slv(TICK_C);
      v.syncTimeout := slv(TICK_C+shift_left(TICK_C, 1));
      v.associationTimeout := slv(shift_left(TICK_C, 1));
      v.maxExchange := slv(shift_left(TICK_C, 1));
      v.minRateSpan := slv(shift_right(TICK_C, 1));
      v.maxRateAge := slv(shift_left(TICK_C, 2));
      return v;
   end function;

   constant NOMINAL_C     : unsigned(63 downto 0) := shift_left(unsigned(ptpNominalIncrement(CLK_FREQ_G)), 16);
   constant RATE_MARGIN_C : unsigned(63 downto 0) := resize((resize(NOMINAL_C, 96)*to_unsigned(200000, 32))/to_unsigned(1000000000, 128), 64);

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

   type PairArray is array (0 to 3) of PairType;
   type StateType is (
      IDLE_S,
      RATE_ISSUE_S,
      RATE_WAIT_S);

   type RegType is record
      -- Current-cycle calculations and diagnostics. Use v for same-edge
      -- decisions; these fields do not introduce a protocol pipeline stage.
      portStatus          : PtpPortStatusType;
      announceChange      : sl;
      externalAbort       : sl;
      abortPort           : sl;
      readyRx             : sl;
      policyValid         : sl;
      qualifiedRatio      : sl;
      validResponse       : sl;
      slot                : integer range -1 to 3;
      freeSlot            : integer range -1 to 3;
      completed           : integer range -1 to 3;
      selected            : integer range -1 to 3;
      syncDistance        : signed(127 downto 0);
      nearestSyncDistance : signed(127 downto 0);
      remoteTime          : signed(127 downto 0);
      rateSpan            : signed(127 downto 0);
      completedSync       : PtpSyncSampleType;
      intervalTicksValue  : unsigned(63 downto 0);
      malformed           : boolean;

      -- Local management state shares the core reset and register process.
      readSlave           : AxiLiteReadSlaveType;
      writeSlave          : AxiLiteWriteSlaveType;
      shadow              : PtpPortConfigType;
      candidate           : PtpPortConfigType;
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
      history             : PtpSyncSampleArray(0 to 3);
      historyValid        : slv(3 downto 0);
      historyPtr          : natural range 0 to 3;
      generation          : slv(31 downto 0);
      active              : sl;
      lastSync            : PtpSyncSampleType;
      lastRemote          : signed(127 downto 0);
      syncLimit           : slv(63 downto 0);
      announceLimit       : slv(63 downto 0);
      lastTicks           : slv(63 downto 0);
      anchor              : PtpSyncSampleType;
      anchorValid         : sl;
      ratio               : slv(63 downto 0);
      ratioCount          : natural range 0 to 2;
      ratioTicks          : slv(63 downto 0);
      state               : StateType;
      rateA               : slv(127 downto 0);
      rateB               : slv(127 downto 0);
      pendingSync         : PtpSyncSampleType;
      measurement         : PtpMeasurementType;
      measurementValid    : sl;
      master              : AxiStreamMasterType;
      frame               : slv(463 downto 0);
      beat                : natural range 0 to 7;
      lastRequest         : slv(63 downto 0);
      requestInterval     : unsigned(63 downto 0);
      minimumInterval     : unsigned(63 downto 0);
      requestStarted      : sl;
      lfsr                : slv(15 downto 0);
      exchange            : PtpExchangeType;
      pendingExchange     : PtpExchangeType;
      announceBody        : slv(239 downto 0);
      announceSeen        : sl;
      announceTicks       : slv(63 downto 0);
      gmIdentity          : slv(63 downto 0);
      flags               : slv(15 downto 0);
      utc                 : slv(15 downto 0);
      rejectedCount       : slv(31 downto 0);
      syncCount           : slv(31 downto 0);
      delayCount          : slv(31 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      portStatus          => PTP_PORT_STATUS_INIT_C,
      announceChange      => '0',
      externalAbort       => '0',
      abortPort           => '0',
      readyRx             => '0',
      policyValid         => '0',
      qualifiedRatio      => '0',
      validResponse       => '0',
      slot                => -1,
      freeSlot            => -1,
      completed           => -1,
      selected            => -1,
      syncDistance        => (others => '0'),
      nearestSyncDistance => (others => '0'),
      remoteTime          => (others => '0'),
      rateSpan            => (others => '0'),
      completedSync       => PTP_SYNC_SAMPLE_INIT_C,
      intervalTicksValue  => (others => '0'),
      malformed           => false,
      readSlave           => AXI_LITE_READ_SLAVE_INIT_C,
      writeSlave          => AXI_LITE_WRITE_SLAVE_INIT_C,
      shadow              => initialConfig,
      candidate           => initialConfig,
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
      active              => '0',
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
      rateA               => (others => '0'),
      rateB               => (others => '0'),
      pendingSync         => PTP_SYNC_SAMPLE_INIT_C,
      measurement         => PTP_MEASUREMENT_INIT_C,
      measurementValid    => '0',
      master              => AXI_STREAM_MASTER_INIT_C,
      frame               => (others => '0'),
      beat                => 0,
      lastRequest         => (others => '0'),
      requestInterval     => (others => '0'),
      minimumInterval     => (others => '0'),
      requestStarted      => '0',
      lfsr                => x"0001",
      exchange            => PTP_EXCHANGE_INIT_C,
      pendingExchange     => PTP_EXCHANGE_INIT_C,
      announceBody        => (others => '0'),
      announceSeen        => '0',
      announceTicks       => (others => '0'),
      gmIdentity          => (others => '0'),
      flags               => (others => '0'),
      utc                 => (others => '0'),
      rejectedCount       => (others => '0'),
      syncCount           => (others => '0'),
      delayCount          => (others => '0'));

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

   function intervalTicks (logInterval : slv(7 downto 0);
   fallback : slv(63 downto 0)) return unsigned is
      variable exponent : integer range -128 to 127;
      variable value    : unsigned(63 downto 0);
   begin
      exponent := to_integer(signed(logInterval));
      value := to_unsigned(CLK_FREQ_G, 64);
      if exponent < -10 or exponent > 22 then
         return unsigned(fallback);
      elsif exponent < 0 then
         return shift_right(value, -exponent);
      end if;
      return shift_left(value, exponent);
   end function;

   function buildRequest (cfg : PtpPortConfigType;
   mac : slv(47 downto 0);
   seqId : slv(15 downto 0)) return slv is
      variable bytes       : Slv8Array(0 to 57) := (others => (others => '0'));
      variable resultValue : slv(463 downto 0);
      constant DEST_C      : slv(47 downto 0) := x"011B19000000";

   begin
      for i in 0 to 5 loop
         bytes(i) := DEST_C(47-8*i downto 40-8*i);
         bytes(6+i) := mac(8*i+7 downto 8*i);
      end loop;
      bytes(12) := x"88";
      bytes(13) := x"F7";
      bytes(14) := x"01";
      bytes(15) := cfg.minorVersion & x"2";
      bytes(17) := x"2C";
      bytes(18) := cfg.domainNumber;
      for i in 0 to 9 loop
         bytes(34+i) := cfg.localIdentity(79-8*i downto 72-8*i);
      end loop;
      bytes(44) := seqId(15 downto 8);
      bytes(45) := seqId(7 downto 0);
      bytes(46) := x"01";
      bytes(47) := x"7F";
      for i in 0 to 57 loop
         resultValue(8*i+7 downto 8*i) := bytes(i);
      end loop;
      return resultValue;
   end function;

   function forwardMeasurement (item : PtpSyncSampleType) return PtpMeasurementType is
      variable resultValue : PtpMeasurementType := PTP_MEASUREMENT_INIT_C;
   begin
      resultValue.generation := item.capture.generation;
      resultValue.ticks := item.capture.ticks;
      resultValue.syncSequence := item.sequenceId;
      resultValue.forward := slv(ptpTimeQ16(item.capture.timestamp)-ptpWireTimeQ16(item.remoteTime)-signed(item.correction));
      return resultValue;
   end function;

   signal coreConfig   : PtpConfigType;
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
         config           => coreConfig,            -- [in]
         allocate         => allocate,              -- [in]
         allocateReady    => allocateReady,         -- [out]
         allocateSequence => allocateSequence,      -- [out]
         wireMessage      => txMessage,             -- [in]
         wireValid        => txValid,               -- [in]
         response         => rxMessage,             -- [in]
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
         delaySample  => delaySample,                  -- [in]
         ratio        => r.ratio,                      -- [in]
         maxPathDelay => r.activeConfig.maxPathDelay,  -- [in]
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
   begin
      v := r;

      -- First check Ethernet/PTP identity, then capture provenance and age.
      -- A rejected record is still consumed below and counted as a rejection.
      v.policyValid := '1';
      if rxMessage.destination /= x"011B19000000" then
         v.policyValid := '0';
      elsif rxMessage.sourcePortIdentity /= r.activeConfig.sourceIdentity then
         v.policyValid := '0';
      elsif rxMessage.domainNumber /= r.activeConfig.domainNumber or rxMessage.transportSpecific /= x"0" then
         v.policyValid := '0';
      elsif rxMessage.capture.generation /= phcStatus.generation or rxMessage.capture.error /= '0' then
         v.policyValid := '0';
      elsif unsigned(phcStatus.ticks) < unsigned(rxMessage.capture.ticks) then
         v.policyValid := '0';
      elsif unsigned(phcStatus.ticks)-unsigned(rxMessage.capture.ticks) > unsigned(r.activeConfig.associationTimeout) then
         v.policyValid := '0';
      end if;

      -- A changed grandmaster or timescale cancels the old measurements on
      -- this edge. This decision precedes readiness and cannot depend on it.
      v.announceChange := '0';
      if rxValid = '1' and r.state = IDLE_S and r.measurementValid = '0' then
         if v.policyValid = '1' and r.announceSeen = '1' and rxMessage.messageType = x"B" then
            if rxMessage.control = x"05" and rxMessage.flags(1 downto 0) /= "11" and
               rxMessage.flags(15 downto 8) = x"00" then
               if rxMessage.messageBody(87 downto 24) /= r.gmIdentity or rxMessage.flags(3) /= r.flags(3) then
                  v.announceChange := '1';
               end if;
            end if;
         end if;
      end if;

      -- Independent protocol causes may revoke an accepted PHC command. Its
      -- own capture invalidation only flushes measurement/association work.
      v.externalAbort := '0';
      if rst = RST_POLARITY_G or restart = '1' then
         v.externalAbort := '1';
      elsif linkReady = '0' or enable = '0' then
         v.externalAbort := '1';
      elsif rxQueueOverflow = '1' or txAbort = '1' or v.announceChange = '1' then
         v.externalAbort := '1';
      elsif r.active = '1' then
         if unsigned(phcStatus.ticks)-unsigned(r.lastTicks) > unsigned(r.syncLimit) then
            v.externalAbort := '1';
         end if;
      end if;
      v.abortPort := '0';
      if v.externalAbort = '1' or captureAbort = '1' or rxAbort = '1' or
         phcStatus.generation /= r.generation then
         v.abortPort := '1';
      end if;

      v.qualifiedRatio := '0';
      if r.ratioCount = 2 and
         unsigned(phcStatus.ticks)-unsigned(r.ratioTicks) <= unsigned(r.activeConfig.maxRateAge) then
         v.qualifiedRatio := '1';
      end if;
      v.readyRx := '0';
      if r.state = IDLE_S and r.measurementValid = '0' and v.abortPort = '0' then
         v.readyRx := '1';
      end if;
      v.validResponse := '0';
      if rxMessage.messageType = x"9" and rxMessage.flags = x"0000" and
         rxMessage.control = x"03" and unsigned(rxMessage.messageBody(191 downto 160)) < 1000000000 then
         v.validResponse := rxValid and v.readyRx and v.policyValid;
      end if;

      allocate                   <= '0';
      e2eInput                   <= '0';
      e2eSync                    <= PTP_SYNC_SAMPLE_INIT_C;
      delayReady                 <= '0';
      e2eTake                    <= '0';
      v.slot                     := -1;
      v.freeSlot                 := -1;
      v.completed                := -1;
      v.selected                 := -1;
      v.nearestSyncDistance      := (others => '1');
      v.nearestSyncDistance(127) := '0';
      v.completedSync            := PTP_SYNC_SAMPLE_INIT_C;
      v.malformed                := false;
      v.generation               := phcStatus.generation;
      if r.measurementValid = '1' and measurementSlave.ready = '1' then
         v.measurementValid := '0';
      end if;

      -- TX ownership survives abort. Once valid is presented, every byte and
      -- sideband stays stable under backpressure until the entire frame drains.
      if r.master.tValid = '1' and txSlave.tReady = '1' then
         v.master := AXI_STREAM_MASTER_INIT_C;
         if r.beat /= 7 then
            v.beat          := r.beat+1;
            v.master.tValid := '1';
            if v.beat = 7 then
               v.master.tData(15 downto 0) := r.frame(463 downto 448);
               v.master.tKeep(7 downto 0)  := x"03";
               v.master.tLast              := '1';
            else
               -- Static slices make the seven-way beat mux explicit to both
               -- synthesis frontends; the final two-byte beat is handled above.
               for i in 0 to 6 loop
                  if v.beat = i then
                     v.master.tData(63 downto 0) := r.frame(64*i+63 downto 64*i);
                  end if;
               end loop;
               v.master.tKeep(7 downto 0) := x"FF";
            end if;
         end if;
      end if;
      -- Schedule a new request only after servicing an already presented TX beat.
      v.intervalTicksValue := unsigned(r.activeConfig.delayInterval);
      if r.minimumInterval > v.intervalTicksValue then
         v.intervalTicksValue := r.minimumInterval;
      end if;
      if r.active = '1' and v.qualifiedRatio = '1' and r.master.tValid = '0' and allocateReady = '1' and
         (r.requestStarted = '0' or unsigned(phcStatus.ticks)-unsigned(r.lastRequest) >= r.requestInterval) then
         allocate                    <= '1';
         v.frame                     := buildRequest(r.activeConfig, localMac, allocateSequence);
         v.master                    := AXI_STREAM_MASTER_INIT_C;
         v.master.tValid             := '1';
         v.master.tKeep(7 downto 0)  := x"FF";
         v.master.tData(63 downto 0) := v.frame(63 downto 0);
         ssiSetUserSof(PTP_RX_AXIS_CONFIG_C, v.master, '1');
         v.beat                      := 0;
         v.lastRequest               := phcStatus.ticks;
         v.requestStarted            := '1';
         -- A bounded three-point schedule (0.5, 1.0, 1.5 times mean) avoids a
         -- runtime multiplier while preserving deterministic seeded variation.
         v.requestInterval := v.intervalTicksValue;
         if r.lfsr(1 downto 0) = "00" then
            v.requestInterval := shift_right(v.intervalTicksValue, 1);
         elsif r.lfsr(1 downto 0) = "11" then
            v.requestInterval := v.intervalTicksValue + shift_right(v.intervalTicksValue, 1);
         end if;
         v.lfsr := r.lfsr(14 downto 0) & (r.lfsr(15) xor r.lfsr(13) xor r.lfsr(12) xor r.lfsr(10));
      end if;

      -- Retire expired partial associations before accepting this cycle's RX record.
      for i in 0 to 3 loop
         if r.pairs(i).used = '1' and
            unsigned(phcStatus.ticks)-unsigned(r.pairs(i).born) > unsigned(r.activeConfig.associationTimeout) then
            v.pairs(i) := PAIR_INIT_C;
         end if;
         if v.pairs(i).used = '0' and v.freeSlot = -1 then
            v.freeSlot := i;
         elsif v.pairs(i).used = '1' and v.pairs(i).sample.sequenceId = rxMessage.sequenceId then
            v.slot := i;
         end if;
      end loop;
      if v.freeSlot = -1 then
         for i in 0 to 3 loop
            if v.pairs(i).complete = '1' then
               if v.freeSlot = -1 then
                  v.freeSlot := i;
               elsif unsigned(v.pairs(i).born) < unsigned(v.pairs(v.freeSlot).born) then
                  v.freeSlot := i;
               end if;
            end if;
         end loop;
      end if;
      -- Consume one message: reject policy failures, otherwise dispatch by type.
      if v.readyRx = '1' and rxValid = '1' then
         if v.policyValid = '0' then
            v.malformed := true;
         elsif rxMessage.messageType = x"0" or rxMessage.messageType = x"8" then
            if (rxMessage.messageType = x"0" and (rxMessage.flags /= x"0200" or rxMessage.control /= x"00")) or
               (rxMessage.messageType = x"8" and (rxMessage.flags /= x"0000" or rxMessage.control /= x"02" or
                unsigned(rxMessage.messageBody(191 downto 160)) >= 1000000000)) then
               v.malformed := true;
            else
               if v.slot = -1 then
                  v.slot := v.freeSlot;
                  if v.slot /= -1 then
                     v.pairs(v.slot)                   := PAIR_INIT_C;
                     v.pairs(v.slot).used              := '1';
                     v.pairs(v.slot).born              := phcStatus.ticks;
                     v.pairs(v.slot).sample.sequenceId := rxMessage.sequenceId;
                  end if;
               end if;
               if v.slot = -1 then
                  v.malformed := true;
               elsif rxMessage.messageType = x"0" then
                  if v.pairs(v.slot).syncSeen = '1' then
                     -- Duplicate Sync is ambiguous even if its headers match:
                     -- the physical capture is a different wire event.
                     v.pairs(v.slot).complete := '1';
                     v.malformed              := true;
                  else
                     v.pairs(v.slot).syncSeen       := '1';
                     v.pairs(v.slot).sample.capture := rxMessage.capture;
                     v.pairs(v.slot).syncCorrection := rxMessage.correction;
                     v.syncLimit                    := r.activeConfig.syncTimeout;
                     if signed(rxMessage.logInterval) >= -10 and signed(rxMessage.logInterval) <= 22 then
                        v.intervalTicksValue := intervalTicks(rxMessage.logInterval, r.activeConfig.syncTimeout);
                        v.intervalTicksValue := v.intervalTicksValue + shift_left(v.intervalTicksValue, 1);
                        if v.intervalTicksValue < unsigned(r.activeConfig.syncTimeout) then
                           v.syncLimit := slv(v.intervalTicksValue);
                        end if;
                     elsif rxMessage.logInterval /= x"7F" then
                        v.rejectedCount := ptpSatInc(v.rejectedCount);
                     end if;
                  end if;
               else
                  if v.pairs(v.slot).followSeen = '1' then
                     if v.pairs(v.slot).sample.remoteTime /= rxMessage.messageBody(239 downto 160) or
                        v.pairs(v.slot).followCorrection /= rxMessage.correction then
                        v.pairs(v.slot).complete := '1';
                        v.malformed              := true;
                     end if;
                  else
                     v.pairs(v.slot).followSeen        := '1';
                     v.pairs(v.slot).sample.remoteTime := rxMessage.messageBody(239 downto 160);
                     v.pairs(v.slot).followCorrection  := rxMessage.correction;
                  end if;
               end if;
            end if;
         elsif rxMessage.messageType = x"9" then
            if v.validResponse = '0' then
               v.malformed := true;
            elsif responseAccepted = '1' and rxMessage.logInterval /= x"7F" and signed(rxMessage.logInterval) >= -10 and signed(rxMessage.logInterval) <= 22 then
               v.minimumInterval := intervalTicks(rxMessage.logInterval, r.activeConfig.delayInterval);
            end if;
         elsif rxMessage.messageType = x"B" then
            if rxMessage.control /= x"05" or rxMessage.flags(1 downto 0) = "11" or rxMessage.flags(15 downto 8) /= x"00" then
               v.malformed    := true;
               v.announceSeen := '0';
            else
               v.announceSeen  := '1';
               v.announceBody  := rxMessage.messageBody;
               v.announceTicks := rxMessage.capture.ticks;
               v.gmIdentity    := rxMessage.messageBody(87 downto 24);
               v.flags         := rxMessage.flags;
               v.utc           := rxMessage.messageBody(159 downto 144);
               v.announceLimit := slv(shift_left(unsigned(r.activeConfig.syncTimeout), 1));
               if signed(rxMessage.logInterval) >= -10 and signed(rxMessage.logInterval) <= 22 then
                  v.intervalTicksValue := intervalTicks(rxMessage.logInterval, v.announceLimit);
                  v.intervalTicksValue := v.intervalTicksValue + shift_left(v.intervalTicksValue, 1);
                  if v.intervalTicksValue < unsigned(v.announceLimit) then
                     v.announceLimit := slv(v.intervalTicksValue);
                  end if;
               elsif rxMessage.logInterval /= x"7F" then
                  v.rejectedCount := ptpSatInc(v.rejectedCount);
               end if;
            end if;
         else
            v.malformed := true;
         end if;
      end if;
      if v.malformed then
         v.rejectedCount := ptpSatInc(v.rejectedCount);
      end if;

      -- Complete at most one Sync association while the rate engine and output
      -- slot are free. Chronology is capture based, not packet completion order.
      if r.state = IDLE_S and r.measurementValid = '0' then
         for i in 0 to 3 loop
            if v.pairs(i).syncSeen = '1' and v.pairs(i).followSeen = '1' and v.pairs(i).complete = '0' and v.completed = -1 then
               v.completed := i;
            end if;
         end loop;
         if v.completed /= -1 then
            v.pairs(v.completed).complete := '1';
            v.completedSync               := v.pairs(v.completed).sample;
            v.completedSync.correction    := slv(resize(signed(v.pairs(v.completed).syncCorrection), 128)+
                                   resize(signed(v.pairs(v.completed).followCorrection), 128));
            v.remoteTime                  := ptpWireTimeQ16(v.completedSync.remoteTime)+signed(v.completedSync.correction);
            if unsigned(phcStatus.ticks)-unsigned(v.completedSync.capture.ticks) > unsigned(r.activeConfig.associationTimeout) or
               (r.active = '1' and (v.remoteTime <= r.lastRemote or unsigned(v.completedSync.capture.ticks) <= unsigned(r.lastTicks))) then
               v.rejectedCount := ptpSatInc(v.rejectedCount);
            else
               v.active                     := '1';
               v.lastSync                   := v.completedSync;
               v.lastRemote                 := v.remoteTime;
               v.lastTicks                  := v.completedSync.capture.ticks;
               v.history(r.historyPtr)      := v.completedSync;
               v.historyValid(r.historyPtr) := '1';
               v.historyPtr                 := (r.historyPtr+1) mod 4;
               v.syncCount                  := ptpSatInc(v.syncCount);
               v.measurement                := forwardMeasurement(v.completedSync);
               v.measurement.ratio          := r.ratio;
               v.measurement.ratioValid     := v.qualifiedRatio;
               v.measurementValid           := '1';
               if r.anchorValid = '0' then
                  v.anchor      := v.completedSync;
                  v.anchorValid := '1';
               else
                  v.rateSpan := ptpTickPhase(v.completedSync.capture)-ptpTickPhase(r.anchor.capture);
                  if v.rateSpan >= shift_left(signed(resize(unsigned(r.activeConfig.minRateSpan), 128)), 3) and v.rateSpan > 0 then
                     v.rateA            := slv(shift_left(v.remoteTime-ptpWireTimeQ16(r.anchor.remoteTime)-signed(r.anchor.correction), 35));
                     v.rateB            := slv(v.rateSpan);
                     v.pendingSync      := v.completedSync;
                     v.anchor           := v.completedSync;
                     v.state            := RATE_ISSUE_S;
                     v.measurementValid := '0';
                  end if;
               end if;
            end if;
         end if;
      end if;
      if r.state = RATE_ISSUE_S and rateReady = '1' then
         v.state := RATE_WAIT_S;
      elsif r.state = RATE_WAIT_S and rateResultValid = '1' then
         if rateError = '0' and signed(rateResult) >= signed(resize(NOMINAL_C-RATE_MARGIN_C, 128)) and
            signed(rateResult) <= signed(resize(NOMINAL_C+RATE_MARGIN_C, 128)) then
            if r.ratioCount = 0 then
               v.ratio := rateResult(63 downto 0);
            else
               v.ratio := slv(resize(signed(resize(unsigned(r.ratio), 128))+
                  ptpRoundShift(signed(rateResult)-signed(resize(unsigned(r.ratio), 128)), 2), 64));
            end if;
            if r.ratioCount < 2 then
               v.ratioCount := r.ratioCount+1;
            end if;
            v.ratioTicks := r.pendingSync.capture.ticks;
         else
            v.rejectedCount := ptpSatInc(v.rejectedCount);
         end if;
         v.measurement            := forwardMeasurement(r.pendingSync);
         v.measurement.ratio      := v.ratio;
         v.measurement.ratioValid := '0';
         if v.ratioCount = 2 and unsigned(phcStatus.ticks)-unsigned(v.ratioTicks) <= unsigned(r.activeConfig.maxRateAge) then
            v.measurement.ratioValid := '1';
         end if;
         v.measurementValid := '1';
         v.state            := IDLE_S;
      end if;

      -- Select the retained Sync nearest the actual TX capture, not nearest to
      -- the delayed wire-completion/Delay_Resp delivery. Signed separation also
      -- supports a Sync arriving just after the Delay_Req left the wire.
      if delayValid = '1' and e2eReady = '1' then
         for i in 0 to 3 loop
            v.syncDistance := abs(ptpTickPhase(delaySample.capture)-ptpTickPhase(r.history(i).capture));
            if r.historyValid(i) = '1' and v.syncDistance < v.nearestSyncDistance and
               r.history(i).capture.generation = delaySample.generation and
               v.syncDistance <= shift_left(signed(resize(unsigned(r.activeConfig.maxExchange), 128)), 3) and
               unsigned(phcStatus.ticks)-unsigned(r.history(i).capture.ticks) <= unsigned(r.activeConfig.associationTimeout) then
               v.selected            := i;
               v.nearestSyncDistance := v.syncDistance;
            end if;
         end loop;
         delayReady <= '1';
         if v.selected /= -1 and v.qualifiedRatio = '1' then
            e2eSync                           <= r.history(v.selected);
            e2eInput                          <= '1';
            v.pendingExchange.t1              := r.history(v.selected).remoteTime;
            v.pendingExchange.t2              := r.history(v.selected).capture.timestamp;
            v.pendingExchange.t3              := delaySample.capture.timestamp;
            v.pendingExchange.t4              := delaySample.remoteTime;
            v.pendingExchange.syncCorrection  := r.history(v.selected).correction;
            v.pendingExchange.delayCorrection := delaySample.correction;
            v.pendingExchange.generation      := delaySample.generation;
            v.pendingExchange.syncSequence    := r.history(v.selected).sequenceId;
            v.pendingExchange.delaySequence   := delaySample.sequenceId;
         else
            v.rejectedCount := ptpSatInc(v.rejectedCount);
         end if;
      end if;
      if e2eValid = '1' and r.state = IDLE_S and v.state = IDLE_S and v.measurementValid = '0' then
         e2eTake <= '1';
         if e2eError = '0' and v.qualifiedRatio = '1' then
            v.measurement      := e2eResult;
            v.exchange         := r.pendingExchange;
            v.measurementValid := '1';
            v.delayCount       := ptpSatInc(v.delayCount);
         else
            v.rejectedCount := ptpSatInc(v.rejectedCount);
         end if;
      end if;

      -- Cancellation has final priority over association and publication. TX
      -- drain state and unresolved ledger ownership deliberately survive it.
      if v.abortPort = '1' then
         -- Keep the TX frame/beat and diagnostic counters. Ledger retirement is
         -- independent and receives abort on this same edge.
         v.pairs            := (others => PAIR_INIT_C);
         v.historyValid     := (others => '0');
         v.active           := '0';
         v.syncLimit        := r.activeConfig.syncTimeout;
         v.announceLimit    := slv(shift_left(unsigned(r.activeConfig.syncTimeout), 1));
         v.anchorValid      := '0';
         v.ratioCount       := 0;
         v.state            := IDLE_S;
         v.measurementValid := '0';
         v.requestStarted   := '0';
         v.minimumInterval  := (others => '0');
         v.announceSeen     := '0';
         if v.announceChange = '1' then
            v.gmIdentity := rxMessage.messageBody(87 downto 24);
         end if;
         v.lfsr := r.activeConfig.lfsrSeed;
         if unsigned(v.lfsr) = 0 then
            v.lfsr := x"0001";
         end if;
         allocate   <= '0';
         e2eInput   <= '0';
         delayReady <= '0';
      end if;
      -- Construct live status from pre-edge state. AXI snapshots below capture
      -- this same record; they do not read back this process's signal outputs.
      v.portStatus              := PTP_PORT_STATUS_INIT_C;
      v.portStatus.active       := r.active and not v.abortPort;
      v.portStatus.ratioValid   := v.qualifiedRatio and not v.abortPort;
      v.portStatus.commandAbort := v.externalAbort;
      if localMac /= r.lastMac then
         v.portStatus.identityRestart := '1';
      end if;
      if v.abortPort = '0' and unsigned(phcStatus.ticks)-unsigned(r.announceTicks) <= unsigned(r.announceLimit) then
         v.portStatus.announceValid := r.announceSeen;
      end if;
      v.portStatus.exchange            := r.exchange;
      v.portStatus.announceBody        := r.announceBody;
      v.portStatus.ledgerStatus        := ledgerStatus;
      v.portStatus.grandmasterIdentity := r.gmIdentity;
      v.portStatus.announceFlags       := r.flags;
      v.portStatus.utcOffset           := r.utc;
      v.portStatus.rejectedCount       := r.rejectedCount;
      v.portStatus.syncCount           := r.syncCount;
      v.portStatus.delayCount          := r.delayCount;
      v.portStatus.timeoutCount        := timeoutCount;

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
         axiSlaveRegisterR(ep, toSlv(16#0E0#, 10), 0, r.activeConfig.associationTimeout);
         axiSlaveRegisterR(ep, toSlv(16#0E8#, 10), 0, r.activeConfig.syncTimeout);
         axiSlaveRegisterR(ep, toSlv(16#0F0#, 10), 0, r.activeConfig.maxPathDelay);
         axiSlaveRegister(ep, toSlv(16#004#, 10), 4, v.shadow.identityOverride);
         axiSlaveRegister(ep, toSlv(16#008#, 10), 0, v.shadow.domainNumber);
         axiSlaveRegister(ep, toSlv(16#008#, 10), 8, v.shadow.minorVersion);
         axiSlaveRegister(ep, toSlv(16#010#, 10), 0, v.shadow.localIdentity);
         axiSlaveRegister(ep, toSlv(16#020#, 10), 0, v.shadow.sourceIdentity);
         axiSlaveRegister(ep, toSlv(16#080#, 10), 0, v.shadow.delayInterval);
         axiSlaveRegister(ep, toSlv(16#088#, 10), 0, v.shadow.syncTimeout);
         axiSlaveRegister(ep, toSlv(16#090#, 10), 0, v.shadow.associationTimeout);
         axiSlaveRegister(ep, toSlv(16#098#, 10), 0, v.shadow.maxExchange);
         axiSlaveRegister(ep, toSlv(16#0A0#, 10), 0, v.shadow.minRateSpan);
         axiSlaveRegister(ep, toSlv(16#0A8#, 10), 0, v.shadow.maxRateAge);
         axiSlaveRegister(ep, toSlv(16#0B0#, 10), 0, v.shadow.lfsrSeed);
         axiSlaveRegister(ep, toSlv(16#0B8#, 10), 0, v.shadow.maxPathDelay);
         axiSlaveRegisterR(ep, toSlv(16#030#, 10), 0, localMac);
         axiSlaveRegisterR(ep, toSlv(16#044#, 10), 0, v.portStatus.active);
         axiSlaveRegisterR(ep, toSlv(16#048#, 10), 0, ledgerStatus);
         axiSlaveRegisterR(ep, toSlv(16#060#, 10), 0, r.activeConfig.localIdentity);
         axiSlaveRegisterR(ep, toSlv(16#070#, 10), 0, r.activeConfig.sourceIdentity);
         axiSlaveRegisterR(ep, toSlv(16#0C0#, 10), 0, slv(to_unsigned(PACKET_LIFETIME_G, 64)));
         axiSlaveRegisterR(ep, toSlv(16#0D0#, 10), 0, INGRESS_LATENCY_G);
         axiSlaveRegisterR(ep, toSlv(16#0D8#, 10), 0, EGRESS_LATENCY_G);
         axiSlaveRegisterR(ep, toSlv(16#130#, 10), 0, r.snapGm);
         axiSlaveRegisterR(ep, toSlv(16#138#, 10), 0, r.snapFlags);
         axiSlaveRegisterR(ep, toSlv(16#13C#, 10), 0, r.snapUtc);
         axiSlaveRegisterR(ep, toSlv(16#140#, 10), 0, r.snapAnnounce);
         axiSlaveRegisterR(ep, toSlv(16#160#, 10), 0, r.snapExchange.t1);
         axiSlaveRegisterR(ep, toSlv(16#170#, 10), 0, r.snapExchange.t2);
         axiSlaveRegisterR(ep, toSlv(16#180#, 10), 0, r.snapExchange.t3);
         axiSlaveRegisterR(ep, toSlv(16#190#, 10), 0, r.snapExchange.t4);
         axiSlaveRegisterR(ep, toSlv(16#1A0#, 10), 0, r.snapExchange.syncCorrection);
         axiSlaveRegisterR(ep, toSlv(16#1B0#, 10), 0, r.snapExchange.delayCorrection);
         axiSlaveRegisterR(ep, toSlv(16#1B8#, 10), 0, r.snapExchange.generation);
         axiSlaveRegisterR(ep, toSlv(16#1BC#, 10), 0, r.snapExchange.syncSequence);
         axiSlaveRegisterR(ep, toSlv(16#3FC#, 10), 0, r.sequenceId);
         axiSlaveRegisterR(ep, toSlv(16#044#, 10), 1, v.portStatus.announceValid);
         axiSlaveRegisterR(ep, toSlv(16#044#, 10), 2, v.portStatus.ratioValid);
         axiSlaveRegisterR(ep, toSlv(16#1BC#, 10), 16, r.snapExchange.delaySequence);
         axiSlaveRegisterR(ep, toSlv(16#200#, 10), 0, r.snapCounters(0));
         axiSlaveRegisterR(ep, toSlv(16#204#, 10), 0, r.snapCounters(1));
         axiSlaveRegisterR(ep, toSlv(16#208#, 10), 0, r.snapCounters(2));
         axiSlaveRegisterR(ep, toSlv(16#20C#, 10), 0, r.snapCounters(3));
         axiSlaveRegisterR(ep, toSlv(16#210#, 10), 0, r.snapCounters(4));
         axiSlaveRegisterR(ep, toSlv(16#214#, 10), 0, r.snapCounters(5));
         axiSlaveRegisterR(ep, toSlv(16#218#, 10), 0, r.snapCounters(6));
      end if;

      -- Validate the immutable candidate, not subsequently writable shadows.
      configValid <= '1';

      -- Identity and protocol selection.
      if unsigned(r.candidate.minorVersion) > 1 then
         configValid <= '0';
      end if;
      if unsigned(r.candidate.localIdentity(15 downto 0)) = 0 or
         unsigned(r.candidate.sourceIdentity(15 downto 0)) = 0 then
         configValid <= '0';
      end if;

      -- Physical and association limits.
      if signed(r.candidate.maxPathDelay) <= 0 then
         configValid <= '0';
      end if;
      if unsigned(r.candidate.associationTimeout) < 2048 then
         configValid <= '0';
      end if;
      if unsigned(r.candidate.maxRateAge) < unsigned(r.candidate.minRateSpan) then
         configValid <= '0';
      end if;

      -- Every timeout must fit the supported unsigned-difference range.
      if not ptpValidTimeout(r.candidate.delayInterval) then
         configValid <= '0';
      end if;
      if not ptpValidTimeout(r.candidate.syncTimeout) then
         configValid <= '0';
      end if;
      if not ptpValidTimeout(r.candidate.associationTimeout) then
         configValid <= '0';
      end if;
      if not ptpValidTimeout(r.candidate.maxExchange) then
         configValid <= '0';
      end if;
      if not ptpValidTimeout(r.candidate.minRateSpan) then
         configValid <= '0';
      end if;
      if not ptpValidTimeout(r.candidate.maxRateAge) then
         configValid <= '0';
      end if;

      if configControl.prepare = '1' then
         v.candidate := r.shadow;
      end if;
      if configControl.apply = '1' then
         v.activeConfig := r.candidate;
      end if;
      -- Derive the active identity at apply and whenever the shared MAC
      -- changes. A frozen override candidate remains independent of MAC edits.
      if configControl.apply = '1' or localMac /= r.lastMac then
         if v.activeConfig.identityOverride = '0' then
            v.activeConfig.localIdentity := localMac(7 downto 0) & localMac(15 downto 8) & localMac(23 downto 16) &
               x"FFFE" & localMac(31 downto 24) & localMac(39 downto 32) & localMac(47 downto 40) & v.activeConfig.localIdentity(15 downto 0);
         end if;
      end if;
      v.lastMac := localMac;
      if snapshotControl.capture = '1' then
         v.sequenceId   := snapshotControl.sequenceId;
         v.snapExchange := v.portStatus.exchange;
         v.snapAnnounce := v.portStatus.announceBody;
         v.snapGm       := v.portStatus.grandmasterIdentity;
         v.snapFlags    := v.portStatus.announceFlags;
         v.snapUtc      := v.portStatus.utcOffset;
         v.snapCounters := (rxCounters.accepted, rxCounters.dropped, rxCounters.overflow,
                            v.portStatus.rejectedCount, v.portStatus.syncCount, v.portStatus.delayCount, timeoutCount);
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

      -- Publish child controls and outward records once, after local decisions.
      -- Drive the ledger configuration directly from its registered owner.
      coreConfig                    <= PTP_CONFIG_INIT_C;
      coreConfig.enable             <= enable;
      coreConfig.identityOverride   <= r.activeConfig.identityOverride;
      coreConfig.domainNumber       <= r.activeConfig.domainNumber;
      coreConfig.minorVersion       <= r.activeConfig.minorVersion;
      coreConfig.localIdentity      <= r.activeConfig.localIdentity;
      coreConfig.sourceIdentity     <= r.activeConfig.sourceIdentity;
      coreConfig.delayInterval      <= r.activeConfig.delayInterval;
      coreConfig.syncTimeout        <= r.activeConfig.syncTimeout;
      coreConfig.associationTimeout <= r.activeConfig.associationTimeout;
      coreConfig.maxExchange        <= r.activeConfig.maxExchange;
      coreConfig.minRateSpan        <= r.activeConfig.minRateSpan;
      coreConfig.maxRateAge         <= r.activeConfig.maxRateAge;
      coreConfig.maxPathDelay       <= r.activeConfig.maxPathDelay;
      coreConfig.lfsrSeed           <= r.activeConfig.lfsrSeed;
      abortNow                      <= v.abortPort;
      responseValid                 <= v.validResponse;
      rateInput                     <= '0';
      if r.state = RATE_ISSUE_S then
         rateInput <= '1';
      end if;
      rxReady                         <= v.readyRx;
      txMaster                        <= r.master;
      measurementMaster.data          <= r.measurement;
      measurementMaster.valid         <= r.measurementValid and not v.abortPort;
      measurementMaster.abort         <= v.abortPort;
      status                          <= v.portStatus;
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
