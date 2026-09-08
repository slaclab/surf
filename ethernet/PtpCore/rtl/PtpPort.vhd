-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Fixed-source two-step PTP port, bootstrap estimator and E2E transactions
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
      restart             : in  sl;
      linkReady           : in  sl;
      macResetDone        : in  sl;
      localMac            : in  slv(47 downto 0);
      config              : in  PtpConfigType;
      phcStatus           : in  PtpPhcStatusType;
      captureAbort        : in  sl;
      rxMessage           : in  PtpRxMessageType;
      rxValid             : in  sl;
      rxReady             : out sl;
      rxQueueOverflow     : in  sl := '0';
      commandAbort        : out sl;
      rxAbort             : in  sl;
      txMessage           : in  PtpRxMessageType;
      txValid             : in  sl;
      txAbort             : in  sl;
      txMaster            : out AxiStreamMasterType;
      txSlave             : in  AxiStreamSlaveType;
      measurement         : out PtpMeasurementType;
      measurementValid    : out sl;
      measurementReady    : in  sl;
      measurementAbort    : out sl;
      active              : out sl;
      ratioValid          : out sl;
      exchange            : out PtpExchangeType;
      announceBody        : out slv(239 downto 0);
      ledgerStatus        : out slv(31 downto 0);
      announceValid       : out sl;
      grandmasterIdentity : out slv(63 downto 0);
      announceFlags       : out slv(15 downto 0);
      utcOffset           : out slv(15 downto 0);
      rejectedCount       : out slv(31 downto 0);
      syncCount           : out slv(31 downto 0);
      delayCount          : out slv(31 downto 0);
      timeoutCount        : out slv(31 downto 0));
end entity PtpPort;

architecture rtl of PtpPort is

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
      pairs            : PairArray;
      history          : PtpSyncSampleArray(0 to 3);
      historyValid     : slv(3 downto 0);
      historyPtr       : natural range 0 to 3;
      generation       : slv(31 downto 0);
      active           : sl;
      lastSync         : PtpSyncSampleType;
      lastRemote       : signed(127 downto 0);
      syncLimit        : slv(63 downto 0);
      announceLimit    : slv(63 downto 0);
      lastTicks        : slv(63 downto 0);
      anchor           : PtpSyncSampleType;
      anchorValid      : sl;
      ratio            : slv(63 downto 0);
      ratioCount       : natural range 0 to 2;
      ratioTicks       : slv(63 downto 0);
      state            : StateType;
      rateA            : slv(127 downto 0);
      rateB            : slv(127 downto 0);
      pendingSync      : PtpSyncSampleType;
      measurement      : PtpMeasurementType;
      measurementValid : sl;
      master           : AxiStreamMasterType;
      frame            : slv(463 downto 0);
      beat             : natural range 0 to 7;
      lastRequest      : slv(63 downto 0);
      requestInterval  : unsigned(63 downto 0);
      minimumInterval  : unsigned(63 downto 0);
      requestStarted   : sl;
      lfsr             : slv(15 downto 0);
      exchange         : PtpExchangeType;
      pendingExchange  : PtpExchangeType;
      announceBody     : slv(239 downto 0);
      announceSeen     : sl;
      announceTicks    : slv(63 downto 0);
      gmIdentity       : slv(63 downto 0);
      flags            : slv(15 downto 0);
      utc              : slv(15 downto 0);
      rejectedCount    : slv(31 downto 0);
      syncCount        : slv(31 downto 0);
      delayCount       : slv(31 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      pairs            => (others => PAIR_INIT_C),
      history          => (others => PTP_SYNC_SAMPLE_INIT_C),
      historyValid     => (others => '0'),
      historyPtr       => 0,
      generation       => (others => '0'),
      active           => '0',
      lastSync         => PTP_SYNC_SAMPLE_INIT_C,
      lastRemote       => (others => '0'),
      lastTicks        => (others => '0'),
      syncLimit        => (others => '0'),
      announceLimit    => (others => '0'),
      anchor           => PTP_SYNC_SAMPLE_INIT_C,
      anchorValid      => '0',
      ratio            => slv(NOMINAL_C),
      ratioCount       => 0,
      ratioTicks       => (others => '0'),
      state            => IDLE_S,
      rateA            => (others => '0'),
      rateB            => (others => '0'),
      pendingSync      => PTP_SYNC_SAMPLE_INIT_C,
      measurement      => PTP_MEASUREMENT_INIT_C,
      measurementValid => '0',
      master           => AXI_STREAM_MASTER_INIT_C,
      frame            => (others => '0'),
      beat             => 0,
      lastRequest      => (others => '0'),
      requestInterval  => (others => '0'),
      minimumInterval  => (others => '0'),
      requestStarted   => '0',
      lfsr             => x"0001",
      exchange         => PTP_EXCHANGE_INIT_C,
      pendingExchange  => PTP_EXCHANGE_INIT_C,
      announceBody     => (others => '0'),
      announceSeen     => '0',
      announceTicks    => (others => '0'),
      gmIdentity       => (others => '0'),
      flags            => (others => '0'),
      utc              => (others => '0'),
      rejectedCount    => (others => '0'),
      syncCount        => (others => '0'),
      delayCount       => (others => '0'));

   signal r                : RegType := REG_INIT_C;
   signal rin              : RegType;
   signal announceChange   : sl;
   signal externalAbort    : sl;
   signal abortNow         : sl;
   signal readyRx          : sl;
   signal policyValid      : sl;
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
   signal qualifiedRatio   : sl;

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

   function buildRequest (cfg : PtpConfigType;
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

begin

   -- This signal reaches arithmetic, ledger and publication combinationally.
   -- Abort must beat a coincident ready/valid measurement transfer, not merely
   -- clear state one cycle after a consumer has already steered the PHC.
   -- Detect a changed grandmaster or PTP timescale before accepting Announce.
   -- Measurements from the old timescale cannot qualify the new one. This does
   -- not depend on readyRx/abortNow, avoiding a cancellation feedback loop.
   announceChange <= '1' when rxValid = '1' and r.state = IDLE_S and r.measurementValid = '0' and
      r.announceSeen = '1' and policyValid = '1' and rxMessage.messageType = x"B" and
      rxMessage.control = x"05" and rxMessage.flags(1 downto 0) /= "11" and
      rxMessage.flags(15 downto 8) = x"00" and
      (rxMessage.messageBody(87 downto 24) /= r.gmIdentity or rxMessage.flags(3) /= r.flags(3)) else '0';
   externalAbort  <= '1' when announceChange = '1' or restart = '1' or linkReady = '0' or config.enable = '0' or
      rxQueueOverflow = '1' or txAbort = '1' or rst = RST_POLARITY_G or
      (r.active = '1' and unsigned(phcStatus.ticks)-unsigned(r.lastTicks) > unsigned(r.syncLimit)) else '0';
   commandAbort   <= externalAbort;
   abortNow       <= '1' when externalAbort = '1' or captureAbort = '1' or rxAbort = '1' or
      phcStatus.generation /= r.generation else '0';
   qualifiedRatio <= '1' when r.ratioCount = 2 and
      unsigned(phcStatus.ticks)-unsigned(r.ratioTicks) <= unsigned(config.maxRateAge) else '0';
   readyRx        <= '1' when r.state = IDLE_S and r.measurementValid = '0' and abortNow = '0' else '0';
   policyValid    <= '1' when rxMessage.destination = x"011B19000000" and
      rxMessage.sourcePortIdentity = config.sourceIdentity and rxMessage.domainNumber = config.domainNumber and
      rxMessage.transportSpecific = x"0" and rxMessage.capture.generation = phcStatus.generation and
      rxMessage.capture.error = '0' and unsigned(phcStatus.ticks) >= unsigned(rxMessage.capture.ticks) and
      unsigned(phcStatus.ticks)-unsigned(rxMessage.capture.ticks) <= unsigned(config.associationTimeout) else '0';
   responseValid  <= rxValid and readyRx and policyValid when rxMessage.messageType = x"9" and
      rxMessage.flags = x"0000" and rxMessage.control = x"03" and
      unsigned(rxMessage.messageBody(191 downto 160)) < 1000000000 else '0';

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
         config           => config,                -- [in]
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

   rateInput <= '1' when r.state = RATE_ISSUE_S else '0';

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
         clk          => clk,                  -- [in]
         rst          => rst,                  -- [in]
         cancel       => abortNow,             -- [in]
         inputValid   => e2eInput,             -- [in]
         inputReady   => e2eReady,             -- [out]
         syncSample   => e2eSync,              -- [in]
         delaySample  => delaySample,          -- [in]
         ratio        => r.ratio,              -- [in]
         maxPathDelay => config.maxPathDelay,  -- [in]
         resultValue  => e2eResult,            -- [out]
         resultValid  => e2eValid,             -- [out]
         resultReady  => e2eTake,              -- [in]
         resultError  => e2eError);            -- [out]

   comb : process (r, rst, config, phcStatus, localMac, rxMessage, rxValid, txSlave,
                   measurementReady, abortNow, announceChange, readyRx, policyValid, responseValid, responseAccepted,
                   allocateReady, allocateSequence, qualifiedRatio, delaySample, delayValid,
                   e2eReady, e2eResult, e2eValid, e2eError, rateReady, rateResultValid, rateResult, rateError) is
      variable v         : RegType;
      variable slot      : integer range -1 to 3;
      variable freeSlot  : integer range -1 to 3;
      variable completed : integer range -1 to 3;
      variable selected  : integer range -1 to 3;
      variable distance  : signed(127 downto 0);
      variable nearest   : signed(127 downto 0);
      variable remote    : signed(127 downto 0);
      variable span      : signed(127 downto 0);
      variable item      : PtpSyncSampleType;
      variable interval  : unsigned(63 downto 0);
      variable malformed : boolean;
   begin
      v := r;

      allocate     <= '0';
      e2eInput     <= '0';
      e2eSync      <= PTP_SYNC_SAMPLE_INIT_C;
      delayReady   <= '0';
      e2eTake      <= '0';
      slot         := -1;
      freeSlot     := -1;
      completed    := -1;
      selected     := -1;
      nearest      := (others => '1');
      nearest(127) := '0';
      item         := PTP_SYNC_SAMPLE_INIT_C;
      malformed    := false;
      v.generation := phcStatus.generation;
      if r.measurementValid = '1' and measurementReady = '1' then
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
      interval := unsigned(config.delayInterval);
      if r.minimumInterval > interval then
         interval := r.minimumInterval;
      end if;
      if r.active = '1' and qualifiedRatio = '1' and r.master.tValid = '0' and allocateReady = '1' and
         (r.requestStarted = '0' or unsigned(phcStatus.ticks)-unsigned(r.lastRequest) >= r.requestInterval) then
         allocate                    <= '1';
         v.frame                     := buildRequest(config, localMac, allocateSequence);
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
         v.requestInterval := interval;
         if r.lfsr(1 downto 0) = "00" then
            v.requestInterval := shift_right(interval, 1);
         elsif r.lfsr(1 downto 0) = "11" then
            v.requestInterval := interval + shift_right(interval, 1);
         end if;
         v.lfsr := r.lfsr(14 downto 0) & (r.lfsr(15) xor r.lfsr(13) xor r.lfsr(12) xor r.lfsr(10));
      end if;

      for i in 0 to 3 loop
         if r.pairs(i).used = '1' and
            unsigned(phcStatus.ticks)-unsigned(r.pairs(i).born) > unsigned(config.associationTimeout) then
            v.pairs(i) := PAIR_INIT_C;
         end if;
         if v.pairs(i).used = '0' and freeSlot = -1 then
            freeSlot := i;
         elsif v.pairs(i).used = '1' and v.pairs(i).sample.sequenceId = rxMessage.sequenceId then
            slot := i;
         end if;
      end loop;
      if freeSlot = -1 then
         for i in 0 to 3 loop
            if v.pairs(i).complete = '1' then
               if freeSlot = -1 then
                  freeSlot := i;
               elsif unsigned(v.pairs(i).born) < unsigned(v.pairs(freeSlot).born) then
                  freeSlot := i;
               end if;
            end if;
         end loop;
      end if;
      if readyRx = '1' and rxValid = '1' then
         if policyValid = '0' then
            malformed := true;
         elsif rxMessage.messageType = x"0" or rxMessage.messageType = x"8" then
            if (rxMessage.messageType = x"0" and (rxMessage.flags /= x"0200" or rxMessage.control /= x"00")) or
               (rxMessage.messageType = x"8" and (rxMessage.flags /= x"0000" or rxMessage.control /= x"02" or
                unsigned(rxMessage.messageBody(191 downto 160)) >= 1000000000)) then
               malformed := true;
            else
               if slot = -1 then
                  slot := freeSlot;
                  if slot /= -1 then
                     v.pairs(slot)                   := PAIR_INIT_C;
                     v.pairs(slot).used              := '1';
                     v.pairs(slot).born              := phcStatus.ticks;
                     v.pairs(slot).sample.sequenceId := rxMessage.sequenceId;
                  end if;
               end if;
               if slot = -1 then
                  malformed := true;
               elsif rxMessage.messageType = x"0" then
                  if v.pairs(slot).syncSeen = '1' then
                     -- Duplicate Sync is ambiguous even if its headers match:
                     -- the physical capture is a different wire event.
                     v.pairs(slot).complete := '1';
                     malformed              := true;
                  else
                     v.pairs(slot).syncSeen       := '1';
                     v.pairs(slot).sample.capture := rxMessage.capture;
                     v.pairs(slot).syncCorrection := rxMessage.correction;
                     v.syncLimit                  := config.syncTimeout;
                     if signed(rxMessage.logInterval) >= -10 and signed(rxMessage.logInterval) <= 22 then
                        interval := intervalTicks(rxMessage.logInterval, config.syncTimeout);
                        interval := interval + shift_left(interval, 1);
                        if interval < unsigned(config.syncTimeout) then
                           v.syncLimit := slv(interval);
                        end if;
                     elsif rxMessage.logInterval /= x"7F" then
                        v.rejectedCount := ptpSatInc(v.rejectedCount);
                     end if;
                  end if;
               else
                  if v.pairs(slot).followSeen = '1' then
                     if v.pairs(slot).sample.remoteTime /= rxMessage.messageBody(239 downto 160) or
                        v.pairs(slot).followCorrection /= rxMessage.correction then
                        v.pairs(slot).complete := '1';
                        malformed              := true;
                     end if;
                  else
                     v.pairs(slot).followSeen        := '1';
                     v.pairs(slot).sample.remoteTime := rxMessage.messageBody(239 downto 160);
                     v.pairs(slot).followCorrection  := rxMessage.correction;
                  end if;
               end if;
            end if;
         elsif rxMessage.messageType = x"9" then
            if responseValid = '0' then
               malformed := true;
            elsif responseAccepted = '1' and rxMessage.logInterval /= x"7F" and signed(rxMessage.logInterval) >= -10 and signed(rxMessage.logInterval) <= 22 then
               v.minimumInterval := intervalTicks(rxMessage.logInterval, config.delayInterval);
            end if;
         elsif rxMessage.messageType = x"B" then
            if rxMessage.control /= x"05" or rxMessage.flags(1 downto 0) = "11" or rxMessage.flags(15 downto 8) /= x"00" then
               malformed      := true;
               v.announceSeen := '0';
            else
               v.announceSeen  := '1';
               v.announceBody  := rxMessage.messageBody;
               v.announceTicks := rxMessage.capture.ticks;
               v.gmIdentity    := rxMessage.messageBody(87 downto 24);
               v.flags         := rxMessage.flags;
               v.utc           := rxMessage.messageBody(159 downto 144);
               v.announceLimit := slv(shift_left(unsigned(config.syncTimeout), 1));
               if signed(rxMessage.logInterval) >= -10 and signed(rxMessage.logInterval) <= 22 then
                  interval := intervalTicks(rxMessage.logInterval, v.announceLimit);
                  interval := interval + shift_left(interval, 1);
                  if interval < unsigned(v.announceLimit) then
                     v.announceLimit := slv(interval);
                  end if;
               elsif rxMessage.logInterval /= x"7F" then
                  v.rejectedCount := ptpSatInc(v.rejectedCount);
               end if;
            end if;
         else
            malformed := true;
         end if;
      end if;
      if malformed then
         v.rejectedCount := ptpSatInc(v.rejectedCount);
      end if;

      -- Complete at most one Sync association while the rate engine and output
      -- slot are free. Chronology is capture based, not packet completion order.
      if r.state = IDLE_S and r.measurementValid = '0' then
         for i in 0 to 3 loop
            if v.pairs(i).syncSeen = '1' and v.pairs(i).followSeen = '1' and v.pairs(i).complete = '0' and completed = -1 then
               completed := i;
            end if;
         end loop;
         if completed /= -1 then
            v.pairs(completed).complete := '1';
            item                        := v.pairs(completed).sample;
            item.correction             := slv(resize(signed(v.pairs(completed).syncCorrection), 128)+
                                   resize(signed(v.pairs(completed).followCorrection), 128));
            remote                      := ptpWireTimeQ16(item.remoteTime)+signed(item.correction);
            if unsigned(phcStatus.ticks)-unsigned(item.capture.ticks) > unsigned(config.associationTimeout) or
               (r.active = '1' and (remote <= r.lastRemote or unsigned(item.capture.ticks) <= unsigned(r.lastTicks))) then
               v.rejectedCount := ptpSatInc(v.rejectedCount);
            else
               v.active                     := '1';
               v.lastSync                   := item;
               v.lastRemote                 := remote;
               v.lastTicks                  := item.capture.ticks;
               v.history(r.historyPtr)      := item;
               v.historyValid(r.historyPtr) := '1';
               v.historyPtr                 := (r.historyPtr+1) mod 4;
               v.syncCount                  := ptpSatInc(v.syncCount);
               v.measurement                := forwardMeasurement(item);
               v.measurement.ratio          := r.ratio;
               v.measurement.ratioValid     := qualifiedRatio;
               v.measurementValid           := '1';
               if r.anchorValid = '0' then
                  v.anchor      := item;
                  v.anchorValid := '1';
               else
                  span := ptpTickPhase(item.capture)-ptpTickPhase(r.anchor.capture);
                  if span >= shift_left(signed(resize(unsigned(config.minRateSpan), 128)), 3) and span > 0 then
                     v.rateA            := slv(shift_left(remote-ptpWireTimeQ16(r.anchor.remoteTime)-signed(r.anchor.correction), 35));
                     v.rateB            := slv(span);
                     v.pendingSync      := item;
                     v.anchor           := item;
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
         if v.ratioCount = 2 and unsigned(phcStatus.ticks)-unsigned(v.ratioTicks) <= unsigned(config.maxRateAge) then
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
            distance := abs(ptpTickPhase(delaySample.capture)-ptpTickPhase(r.history(i).capture));
            if r.historyValid(i) = '1' and distance < nearest and
               r.history(i).capture.generation = delaySample.generation and
               distance <= shift_left(signed(resize(unsigned(config.maxExchange), 128)), 3) and
               unsigned(phcStatus.ticks)-unsigned(r.history(i).capture.ticks) <= unsigned(config.associationTimeout) then
               selected := i;
               nearest  := distance;
            end if;
         end loop;
         delayReady <= '1';
         if selected /= -1 and qualifiedRatio = '1' then
            e2eSync                           <= r.history(selected);
            e2eInput                          <= '1';
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
            v.rejectedCount := ptpSatInc(v.rejectedCount);
         end if;
      end if;
      if e2eValid = '1' and r.state = IDLE_S and v.state = IDLE_S and v.measurementValid = '0' then
         e2eTake <= '1';
         if e2eError = '0' and qualifiedRatio = '1' then
            v.measurement      := e2eResult;
            v.exchange         := r.pendingExchange;
            v.measurementValid := '1';
            v.delayCount       := ptpSatInc(v.delayCount);
         else
            v.rejectedCount := ptpSatInc(v.rejectedCount);
         end if;
      end if;

      if abortNow = '1' then
         -- Keep the TX frame/beat and diagnostic counters. Ledger retirement is
         -- independent and receives abort on this same edge.
         v.pairs            := (others => PAIR_INIT_C);
         v.historyValid     := (others => '0');
         v.active           := '0';
         v.syncLimit        := config.syncTimeout;
         v.announceLimit    := slv(shift_left(unsigned(config.syncTimeout), 1));
         v.anchorValid      := '0';
         v.ratioCount       := 0;
         v.state            := IDLE_S;
         v.measurementValid := '0';
         v.requestStarted   := '0';
         v.minimumInterval  := (others => '0');
         v.announceSeen     := '0';
         if announceChange = '1' then
            v.gmIdentity := rxMessage.messageBody(87 downto 24);
         end if;
         v.lfsr := config.lfsrSeed;
         if unsigned(v.lfsr) = 0 then
            v.lfsr := x"0001";
         end if;
         allocate   <= '0';
         e2eInput   <= '0';
         delayReady <= '0';
      end if;
      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;
      rin <= v;
   end process comb;
   rxReady             <= readyRx;
   txMaster            <= r.master;
   measurement         <= r.measurement;
   measurementValid    <= r.measurementValid and not abortNow;
   measurementAbort    <= abortNow;
   active              <= r.active and not abortNow;
   ratioValid          <= qualifiedRatio and not abortNow;
   announceValid       <= r.announceSeen when abortNow = '0' and unsigned(phcStatus.ticks)-unsigned(r.announceTicks) <=
      unsigned(r.announceLimit) else '0';
   exchange            <= r.exchange;
   announceBody        <= r.announceBody;
   grandmasterIdentity <= r.gmIdentity;
   announceFlags       <= r.flags;
   utcOffset           <= r.utc;
   rejectedCount       <= r.rejectedCount;
   syncCount           <= r.syncCount;
   delayCount          <= r.delayCount;
   seq : process (clk, rst) is
   begin
      if RST_ASYNC_G and rst = RST_POLARITY_G then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
