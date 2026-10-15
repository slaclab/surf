-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PTP Sync association and measurement flow.
-- Coordinates pair/history transactions, rate/E2E sequencing and publication.
-- Separate children own the tables and shared scan ALU. Policy supplies admission
-- and cancellation; the ledger supplies completed Delay_Req samples.
-- Diagnostic uploads remain with their held payload owner: Announce uses the
-- RX producer, exchange uses the E2E operands. Registered word writes/commits
-- feed PtpProtocolReg without copying payloads or adding an acceptance edge.
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
use surf.PtpRegisterPkg.all;
use surf.PtpSyncPkg.all;

entity PtpSyncFlow is
   generic (
      TPD_G                 : time             := 1 ns;
      RST_POLARITY_G        : sl               := '1';
      RST_ASYNC_G           : boolean          := false;
      CLK_FREQ_G            : positive         := 156250000;
      INGRESS_LATENCY_G     : slv(63 downto 0) := (others => '0');
      EGRESS_LATENCY_G      : slv(63 downto 0) := (others => '0');
      HISTORY_MEMORY_TYPE_G : string           := "block";
      PAIR_MEMORY_TYPE_G    : string           := "block");
   port (
      clk          : in sl;
      rst          : in sl;
      activeConfig : in PtpPortConfigType;
      phcStatus    : in PtpPhcStatusType;
      rxMessage    : in PtpRxMessageType;
      rxValid      : in sl;
      rxReady      : out sl;
      -- Policy decisions and same-edge admission events.
      policyStatus     : in PtpPortStatusType;
      policyValid      : in sl;
      policyFlags      : in slv(15 downto 0);
      announceValid    : in sl;
      intervalValid    : in sl;
      abortPort        : in sl;
      abortNow         : in sl;
      lastSyncTicks    : in slv(63 downto 0);
      syncAdmitted     : out sl;
      announceAdmitted : out sl;
      sampleAccepted   : out sl;
      sampleTicks      : out slv(63 downto 0);
      policyIdle       : out sl;
      txEnable         : out sl;
      -- Held response to ledger and completed samples from ledger.
      response          : out PtpRxMessageType;
      responseValid     : out sl;
      responseReady     : in sl;
      responseLog       : out slv(7 downto 0);
      delaySample       : in PtpDelaySampleType;
      delayValid        : in sl;
      delayReady        : out sl;
      ledgerStatus      : in slv(31 downto 0);
      timeoutCount      : in slv(31 downto 0);
      measurementMaster : out PtpMeasurementMasterType;
      measurementSlave  : in PtpMeasurementSlaveType;
      status            : out PtpPortStatusType;
      publication       : out PtpPublicationType;
      -- Existing rate/E2E shared-divider interfaces.
      divideValid       : out slv(1 downto 0);
      divideReady       : in slv(1 downto 0);
      divideOperandA    : out Slv128Array(1 downto 0);
      divideOperandB    : out slv(159 downto 0);
      divideCancel      : out slv(1 downto 0);
      divideResultValid : in slv(1 downto 0);
      divideResultReady : out slv(1 downto 0);
      divideResultValue : in Slv128Array(1 downto 0);
      divideResultError : in slv(1 downto 0));
end entity PtpSyncFlow;

architecture rtl of PtpSyncFlow is

   -- Raw oscillator qualification envelope, independent of servo actuation.
   constant MAX_OSCILLATOR_PPB_C  : positive := 200000; -- 200 ppm.
   constant RATIO_QUALIFY_COUNT_C : positive := 2;
   -- Q16 elapsed master ns / Q3 elapsed raw cycles -> Q48 ns/cycle.
   constant NOMINAL_C : unsigned(63 downto 0) := shift_left(unsigned(ptpNominalIncrement(CLK_FREQ_G)), PTP_PHC_TO_RATIO_SHIFT_C);
   type StateType is (
      IDLE_S,
      RATE_SUBMIT_S,
      RATE_ACCEPT_S,
      RATE_WAIT_S,
      RATE_HISTORY_S,
      RATE_PUBLISH_S);

   type RegType is record
      -- Current-edge admission for RX, ledger samples and E2E results.
      rxReady    : sl;
      delayReady : sl;
      e2eTake    : sl;
      -- Live diagnostic state; AXI snapshots below have a separate lifetime.
      portStatus      : PtpPortStatusType;
      rejectedPending : natural range 0 to 9;
      -- Diagnostic upload ownership stays with its held RX/E2E payload.
      publicationPort : PtpPublicationType;
      announceWord    : natural range 0 to 11;
      announceStored  : sl;
      exchangeWriting : sl;
      exchangeWord    : natural range 0 to 19;
      -- Retain normalized anchor data rather than reconverting a full sample.
      ratio             : slv(63 downto 0);
      ratioTicks        : slv(63 downto 0);
      state             : StateType;
      measurementMaster : PtpMeasurementMasterType;
      response          : PtpRxMessageType;
      responseValid     : sl;
      responseLog       : slv(7 downto 0);
      e2eInput          : sl;
      e2eBusy           : sl;
      e2eDelay          : PtpDelaySampleType;
      e2eRatio          : slv(63 downto 0);
      e2eMaximum        : slv(63 downto 0);
      rateInput         : sl;
      rateTake          : sl;
      rateRejectedSeen  : slv(31 downto 0);
      ratioQualified    : sl;
   end record;

   constant REG_INIT_C : RegType := (
      rxReady           => '0',
      delayReady        => '0',
      e2eTake           => '0',
      portStatus        => PTP_PORT_STATUS_INIT_C,
      rejectedPending   => 0,
      publicationPort   => PTP_PUBLICATION_INIT_C,
      announceWord      => 0,
      announceStored    => '0',
      exchangeWriting   => '0',
      exchangeWord      => 0,
      ratio             => slv(NOMINAL_C),
      ratioTicks        => (others => '0'),
      state             => IDLE_S,
      rateInput         => '0',
      rateTake          => '0',
      rateRejectedSeen  => (others => '0'),
      ratioQualified    => '0',
      measurementMaster => PTP_MEASUREMENT_MASTER_INIT_C,
      response          => PTP_RX_MESSAGE_INIT_C,
      responseValid     => '0',
      responseLog       => (others => '0'),
      e2eInput          => '0',
      e2eBusy           => '0',
      e2eDelay          => PTP_DELAY_SAMPLE_INIT_C,
      e2eRatio          => (others => '0'),
      e2eMaximum        => (others => '0'));

   signal r               : RegType := REG_INIT_C;
   signal rin             : RegType;
   signal normalizedReady : sl;
   signal e2eInput        : sl;
   signal e2eReady        : sl;
   signal rateReady       : sl;
   signal rateValid       : sl;
   signal rateRatio       : slv(63 downto 0);
   signal rateQualified   : sl;
   signal rateUpdate      : sl;
   signal rateNormalized  : slv(127 downto 0);
   signal rateCorrection  : slv(127 downto 0);
   signal rateForward     : slv(127 downto 0);
   signal rateAccepted    : sl;
   signal rateRejected    : slv(31 downto 0);

   signal e2eResult          : PtpMeasurementType;
   signal e2eValid           : sl;
   signal e2eTake            : sl;
   signal e2eError           : sl;
   signal pairIdle           : sl;
   signal pairTake           : sl;
   signal pairEnable         : sl;
   signal pairRejected       : natural range 0 to 2;
   signal pairScanRequest    : PtpScanRequestType;
   signal historyScanRequest : PtpScanRequestType;
   signal pairScanResult     : PtpScanResultType;
   signal historyScanResult  : PtpScanResultType;
   signal historyIdle        : sl;
   signal historyReady       : sl;
   signal appendBusy         : sl;

   signal pairResult       : PtpSyncPairResultType;
   signal lookupRequest    : PtpSyncLookupRequestType;
   signal lookupResult     : PtpSyncLookupResultType;
   signal appendRequest    : PtpSyncAppendRequestType;
   signal appendStatus     : PtpSyncAppendStatusType;
   signal normalizedMaster : PtpSyncNormalizedMasterType;

   function exchangeRecord(sync : PtpSyncSampleType;
   delay           : PtpDelaySampleType) return PtpExchangeType is
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
   index            : natural) return slv is
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


begin

   -- Single-bit admission gate also used by bounded regression retirement.
   appendBusy <= appendStatus.busy;
   policyIdle <= toSl(r.state = IDLE_S) and not r.measurementMaster.valid;
   sampleTicks <= pairResult.sample.capture.ticks;
   response <= r.response;
   responseLog <= r.responseLog;
   publication <= r.publicationPort;

   -- Pair and history owners hold their row operands until scan completion.
   U_Scan : entity surf.PtpTableScan
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk                => clk,
         rst                => rst,
         cancel             => abortPort,
         associationTimeout => activeConfig.associationTimeout,
         maxExchange        => activeConfig.maxExchange,
         pairRequest        => pairScanRequest,
         historyRequest     => historyScanRequest,
         pairResult         => pairScanResult,
         historyResult      => historyScanResult);

   U_Pair : entity surf.PtpSyncPair
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         MEMORY_TYPE_G  => PAIR_MEMORY_TYPE_G)
      port map (
         clk           => clk,
         rst           => rst,
         cancel        => abortPort,
         enable        => pairEnable,
         ticks         => phcStatus.ticks,
         rxMessage     => rxMessage,
         rxValid       => rxValid,
         policyValid   => policyValid,
         policyFlags   => policyFlags,
         intervalValid => intervalValid,
         idle          => pairIdle,
         take          => pairTake,
         result        => pairResult,  -- [out]
         syncAdmitted  => syncAdmitted,
         rejected      => pairRejected,
         scanRequest   => pairScanRequest,
         scanResult    => pairScanResult);

   U_History : entity surf.PtpSyncHistory
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         MEMORY_TYPE_G  => HISTORY_MEMORY_TYPE_G)
      port map (
         clk              => clk,
         rst              => rst,
         cancel           => abortPort,
         ticks            => phcStatus.ticks,
         lookupRequest    => lookupRequest,  -- [in]
         delaySample      => r.e2eDelay,
         lookupIdle       => historyIdle,  -- [out]
         lookupReady      => historyReady,  -- [out]
         lookupResult     => lookupResult,  -- [out]
         appendRequest    => appendRequest,  -- [in]
         appendStatus     => appendStatus,  -- [out]
         normalizedMaster => normalizedMaster,  -- [out]
         normalizedReady  => normalizedReady,  -- [in]
         scanRequest      => historyScanRequest,
         scanResult       => historyScanResult);

   U_E2e : entity surf.PtpE2e
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         INGRESS_LATENCY_G => INGRESS_LATENCY_G,
         EGRESS_LATENCY_G  => EGRESS_LATENCY_G,
         NORMALIZED_SYNC_G => true)
      port map (
         normalizedMaster  => normalizedMaster,  -- [in]
         normalizedReady   => normalizedReady,  -- [out]
         clk               => clk,           -- [in]
         rst               => rst,           -- [in]
         cancel            => abortNow,      -- [in]
         inputValid        => e2eInput,      -- [in]
         inputReady        => e2eReady,      -- [out]
         syncSample        => lookupResult.sample,       -- [in]
         delaySample       => r.e2eDelay,    -- [in]
         ratio             => r.e2eRatio,    -- [in]
         maxPathDelay      => r.e2eMaximum,  -- [in]
         resultValue       => e2eResult,     -- [out]
         resultValid       => e2eValid,      -- [out]
         resultReady       => e2eTake,       -- [in]
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
         resultValid        => rateValid,               -- [out]
         resultReady        => r.rateTake,              -- [in]
         syncSample         => pairResult.sample,           -- [in]
         minimumSpan        => activeConfig.minRateSpan,  -- [in]
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
      variable v                 : RegType;
      variable lookupCommand     : PtpSyncLookupRequestType;
      variable appendCommand     : PtpSyncAppendRequestType;
      variable announceAdmission : sl;
      variable sampleAcceptance  : sl;
      -- Same-edge admission/cancellation decisions.
      variable qualifiedRatio  : sl;
      variable historyStarting : boolean;
      variable validResponse   : sl;
      variable malformed       : boolean;
      variable rejectedEvents  : natural range 0 to 9;
      variable rejectedSum     : unsigned(32 downto 0);
   begin
      v := r;
      -- One combinational driver overlays the held rate correction for append.
      -- The pair owner retains the sample; this creates no second register bank.
      lookupCommand := PTP_SYNC_LOOKUP_REQUEST_INIT_C;
      appendCommand := PTP_SYNC_APPEND_REQUEST_INIT_C;
      appendCommand.sample := pairResult.sample;
      appendCommand.sample.correction := rateCorrection;
      appendCommand.forwardValue := rateForward;
      appendCommand.normalizedTime := rateNormalized;
      announceAdmission := '0';
      sampleAcceptance := '0';
      rejectedEvents := pairRejected;
      v.rateTake := '0';
      v.rateRejectedSeen := rateRejected;
      if rateRejected /= r.rateRejectedSeen then
         rejectedEvents := rejectedEvents+1;
      end if;
      v.publicationPort.write := '0';
      v.publicationPort.commit := '0';
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

      if r.measurementMaster.valid = '1' and measurementSlave.ready = '1' then
         v.measurementMaster.valid := '0';
      end if;

      -- The estimator reports whether its ratio is qualified; freshness for
      -- this consumer is the separate age test.
      qualifiedRatio := '0';

      if r.ratioQualified = '1' and
         not ptpAgeExpired(phcStatus.ticks, r.ratioTicks, activeConfig.maxRateAge) then
         qualifiedRatio := '1';
      end if;

      -- Reserve E2E capacity on the original ledger handshake edge. The
      -- history owner borrows the retained Delay sample until lookupResult.done.
      historyStarting := delayValid = '1' and r.e2eBusy = '0' and
                         historyReady = '1' and abortPort = '0';
      lookupCommand.start := toSl(historyStarting) and historyIdle;
      lookupCommand.qualified := qualifiedRatio;
      if historyStarting and historyIdle = '1' then
         v.delayReady := '1';
         v.e2eBusy := '1';
         v.e2eDelay := delaySample;
         v.e2eRatio := r.ratio;
         v.e2eMaximum := activeConfig.maxPathDelay;
      end if;
      if lookupResult.done = '1' then
         if lookupResult.matched = '1' then
            v.e2eInput := '1';
            v.exchangeWriting := '1';
            v.exchangeWord := 0;
         else
            v.e2eBusy := '0';
            rejectedEvents := rejectedEvents+1;
         end if;
      end if;
      pairEnable <= toSl(r.state = IDLE_S) and not r.measurementMaster.valid and
                    historyIdle and not toSl(historyStarting) and not appendBusy and not e2eValid;

      -- Stream the stable E2E producer fields once into the result store.
      -- The arithmetic client owns these inputs until result retirement; no
      -- separate pendingExchange record is needed.
      if r.exchangeWriting = '1' then
         v.publicationPort.write := '1';
         v.publicationPort.first := toSl(r.exchangeWord = 0);
         v.publicationPort.recordIndex := x"1";
         v.publicationPort.wordIndex := toSlv(r.exchangeWord,8);
         v.publicationPort.data := exchangeWord(exchangeRecord(lookupResult.sample,r.e2eDelay),r.exchangeWord);
         if r.exchangeWord = 19 then
            v.exchangeWriting := '0';
         else
            v.exchangeWord := r.exchangeWord+1;
         end if;
      end if;

      v.rxReady := '0';
      -- A pair's producer is the input holding register throughout the scan.
      -- Acknowledge only when its selected row and publication capacity are
      -- available; registering ready here would require another payload slot.
      if r.state = IDLE_S and r.measurementMaster.valid = '0' and abortPort = '0' and
         historyIdle = '1' and not historyStarting and
         (r.responseValid = '0' or responseReady = '1') then
         if pairResult.done = '1' then
            v.rxReady := '1';
         elsif pairIdle = '1' and
            rxMessage.messageType /= PTP_MSG_SYNC_C and rxMessage.messageType /= PTP_MSG_FOLLOW_UP_C then
            v.rxReady := '1';
         end if;
      end if;

      -- Announce body and decoded metadata form one immutable result. Its
      -- producer holds them through this twelve-word upload; acknowledgement publishes RAM ownership
      -- and the public diagnostic record together. Rejected traffic needs no copy.
      if v.rxReady = '1' and rxValid = '1' and rxMessage.messageType = PTP_MSG_ANNOUNCE_C and
         policyValid = '1' and announceValid = '1' and r.announceStored = '0' then
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

      -- Qualified measurement state permits the transmitter to schedule requests.
      txEnable        <= policyStatus.active and qualifiedRatio;

      -------------------------------------------------------------------------
      -- RX association and message dispatch
      -------------------------------------------------------------------------
      -- Expiry is evaluated at scan admission, before selecting a key. RX
      -- payload stays at its producer until this acknowledgement edge.
      -- Consume one message: reject policy failures, otherwise dispatch by type.
      malformed := false;

      if rxValid = '1' and v.rxReady = '1' and pairIdle = '1' then
         if policyValid = '0' then
            malformed := true;
         else

            case rxMessage.messageType is
               when PTP_MSG_DELAY_RESP_C =>
                  if validResponse = '0' then
                     malformed := true;
                  end if;
               when PTP_MSG_ANNOUNCE_C =>
                  announceAdmission := '1';
                  if announceValid = '0' then
                     malformed := true;
                  else
                     v.publicationPort.commit := '1';
                     v.publicationPort.commitRecord := x"0";
                     if intervalValid = '0' and
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
      -- publishes the forward measurement it returns. Accepted-sample events
      -- update the separate policy owner on the same edge.
      case r.state is
         when IDLE_S =>

            if pairResult.done = '1' and v.rxReady = '1' and rxValid = '1' then
               if pairResult.sampleValid = '1' then
                  if ptpAgeExpired(phcStatus.ticks, pairResult.sample.capture.ticks, activeConfig.associationTimeout) then
                     rejectedEvents := rejectedEvents+1;
                  else
                     v.state := RATE_SUBMIT_S;
                  end if;
               end if;
            end if;

         when RATE_SUBMIT_S =>
            -- Chronology against the last accepted Sync stays local, because
            -- it gates history admission as well as the rate estimate.
            if policyStatus.active = '1' and
               unsigned(pairResult.sample.capture.ticks) <= unsigned(lastSyncTicks) then
               rejectedEvents := rejectedEvents+1;
               v.state := IDLE_S;
            else
               v.rateInput := '1';
               v.state := RATE_ACCEPT_S;
            end if;

         when RATE_ACCEPT_S =>
            if rateReady = '1' then
               v.rateInput := '0';
               v.state := RATE_WAIT_S;
            end if;

         when RATE_WAIT_S =>
            -- The child holds the complete result, including ratio freshness,
            -- while this owner writes history and publishes the measurement.
            if rateValid = '1' then
               if rateAccepted = '1' then
                  sampleAcceptance := '1';
                  v.portStatus.syncCount := ptpSatInc(v.portStatus.syncCount);
                  v.state := RATE_HISTORY_S;
               else
                  v.rateTake := '1';
                  v.state := IDLE_S;
               end if;
            end if;

         when RATE_HISTORY_S =>
            if appendStatus.done = '1' then
               v.state := RATE_PUBLISH_S;
            end if;

         when RATE_PUBLISH_S =>
            v.rateTake := '1';
            v.ratio := rateRatio;
            v.ratioQualified := rateQualified;

            if rateUpdate = '1' then
               v.ratioTicks := pairResult.sample.capture.ticks;
            end if;

            v.measurementMaster.data.isDelay := '0';
            v.measurementMaster.data.generation := pairResult.sample.capture.generation;
            v.measurementMaster.data.ticks := pairResult.sample.capture.ticks;
            v.measurementMaster.data.syncSequence := pairResult.sample.sequenceId;
            v.measurementMaster.data.delaySequence := (others => '0');
            v.measurementMaster.data.delayValue := (others => '0');
            v.measurementMaster.data.forward := rateForward;
            v.measurementMaster.data.ratio := rateRatio;
            v.measurementMaster.data.ratioValid := '0';

            -- Freshness is separate from acceptance: a qualified ratio must
            -- also be recent enough for this sample's consumer.
            if rateQualified = '1' and
               not ptpAgeExpired(phcStatus.ticks, v.ratioTicks, activeConfig.maxRateAge) then
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
      -- rate machine cannot start (it requires pairResult.done), so both next-state
      -- idle tests are redundant. Keep service ready out of publication enables.
      if e2eValid = '1' and abortPort = '0' and r.state = IDLE_S and
         pairIdle = '1' and v.measurementMaster.valid = '0' and
         r.exchangeWriting = '0' and v.publicationPort.commit = '0' then
         v.e2eTake := '1';
         v.e2eBusy := '0';
         if e2eError = '0' and qualifiedRatio = '1' then
            v.measurementMaster.data           := e2eResult;
            v.portStatus.exchange := exchangeRecord(lookupResult.sample,r.e2eDelay);
            v.publicationPort.commit := '1';
            v.publicationPort.commitRecord := x"1";
            v.measurementMaster.valid          := '1';
            v.portStatus.delayCount            := ptpSatInc(v.portStatus.delayCount);
         else
            rejectedEvents := rejectedEvents+1;
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
         v.exchangeWriting := '0';
         v.announceWord := 0;
         v.announceStored := '0';
         v.rateInput               := '0';
         v.rateTake                := '0';
         v.ratioQualified          := '0';
         v.state                   := IDLE_S;
         v.measurementMaster.valid := '0';
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

      if v.ratioQualified = '1' and
         not ptpAgeExpired(phcStatus.ticks, v.ratioTicks, activeConfig.maxRateAge) then
         v.portStatus.ratioValid := '1';
      end if;


      v.portStatus.ledgerStatus := ledgerStatus;
      v.portStatus.timeoutCount := timeoutCount;
      -- Current-edge events update policy deadlines without adding a stage.
      -- Policy applies its own final cancellation priority to these events.
      appendCommand.start := sampleAcceptance;
      announceAdmitted <= announceAdmission;
      sampleAccepted <= sampleAcceptance;

      -- Apply synchronous reset before publishing next state and outputs.
      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;

      lookupRequest <= lookupCommand;
      appendRequest <= appendCommand;
      rin <= v;
      -- Registered forward interfaces; reverse ready still describes capacity
      -- on this edge. RX/measurement arbitration and local cancellation can
      -- remove capacity now; registering ready would need an additional input
      -- slot or a reservation shared with those competing producers.
      e2eInput          <= r.e2eInput;
      delayReady        <= v.delayReady;
      e2eTake           <= v.e2eTake;
      rxReady           <= v.rxReady;
      pairTake <= v.rxReady and rxValid and pairResult.done;
      responseValid     <= r.responseValid;
      measurementMaster <= r.measurementMaster;
      -- This field comes from the policy owner's registered abort event.
      measurementMaster.abort <= abortNow;
      -- Registered measurement diagnostics; policy fields are composed by the parent.
      status <= r.portStatus;
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
