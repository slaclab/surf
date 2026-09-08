-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI-Lite configuration, manual clock control and PTP
-- diagnostics.
--
-- Implements the endpoint's 4 KiB register ABI using SURF AXI-Lite helpers.
-- Configuration writes update shadows; an explicit validated commit activates
-- the complete set together and requests protocol restart. Defaults derive
-- raw-tick timers from CLK_FREQ_G. The active local PTP identity can follow
-- the shared MAC address or use the configured override.
--
-- Manual commands latch their operands before waiting for PHC admission,
-- preserving them across backpressure and later shadow writes. A dedicated
-- PtpMath engine normalizes signed Q16 phase adjustments into the PHC's
-- whole-seconds and Q32-remainder command format. Busy, acknowledgement and
-- error status track the full transaction. PtpEndpoint arbitrates these
-- commands with automatic servo control.
--
-- Explicit snapshots retain coherent PHC and diagnostic values for multiword
-- software reads. The map also exposes source/Announce state, counters,
-- calibration constants and masked sticky interrupts. regRst cancels AXI
-- responses while preserving active configuration and accepted clock commands;
-- rst resets the full register subsystem. The matching software map is
-- python/surf/ethernet/ptp/_PtpEndpoint.py.
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

entity PtpReg is
   generic (
      TPD_G             : time             := 1 ns;
      RST_POLARITY_G    : sl               := '1';
      RST_ASYNC_G       : boolean          := false;
      PACKET_LIFETIME_G : positive         := 156250000;
      CLK_FREQ_G        : positive         := 156250000;
      INGRESS_LATENCY_G : slv(63 downto 0) := (others => '0');
      EGRESS_LATENCY_G  : slv(63 downto 0) := (others => '0'));
   port (
      clk                 : in  sl;
      rst                 : in  sl;
      regRst              : in  sl := '0';
      axiReadMaster       : in  AxiLiteReadMasterType;
      axiReadSlave        : out AxiLiteReadSlaveType;
      axiWriteMaster      : in  AxiLiteWriteMasterType;
      axiWriteSlave       : out AxiLiteWriteSlaveType;
      localMac            : in  slv(47 downto 0);
      config              : out PtpConfigType;
      configRestart       : out sl;
      phcTime             : in  PtpTimeType;
      phcStatus           : in  PtpPhcStatusType;
      captureAbort        : in  sl;
      command             : out PtpPhcCommandType;
      commandValid        : out sl;
      commandReady        : in  sl;
      commandAck          : in  sl;
      commandError        : in  sl;
      portActive          : in  sl;
      servoState          : in  slv(2 downto 0);
      filteredDelay       : in  slv(127 downto 0);
      offsetValue         : in  slv(127 downto 0);
      ratePpb             : in  slv(63 downto 0);
      filterCount         : in  slv(2 downto 0);
      exchange            : in  PtpExchangeType;
      announceBody        : in  slv(239 downto 0);
      ledgerStatus        : in  slv(31 downto 0);
      announceValid       : in  sl;
      grandmasterIdentity : in  slv(63 downto 0);
      announceFlags       : in  slv(15 downto 0);
      utcOffset           : in  slv(15 downto 0);
      counters            : in  Slv32Array(0 to 7);
      irq                 : out sl);
end entity PtpReg;

architecture rtl of PtpReg is

   -- Defaults use the actual clock frequency, never the 10G-specific tick
   -- counts of the package's illustrative reset configuration.
   function initialConfig return PtpConfigType is
      variable value : PtpConfigType := PTP_CONFIG_INIT_C;
      variable tick  : unsigned(63 downto 0) := to_unsigned(CLK_FREQ_G, 64);
   begin
      value.delayInterval := slv(tick);
      value.syncTimeout := slv(tick+shift_left(tick, 1));
      value.associationTimeout := slv(shift_left(tick, 1));
      value.maxDelayAge := slv(shift_left(tick, 2));
      value.holdoverTimeout := slv(shift_left(tick, 6));
      value.maxExchange := slv(shift_left(tick, 1));
      value.minRateSpan := slv(shift_right(tick, 1));
      value.maxRateAge := slv(shift_left(tick, 2));
      value.minSampleTicks := slv(shift_right(tick, 6));
      value.maxSampleTicks := slv(shift_left(tick, 1));
      return value;
   end function;

   type RegType is record
      readSlave        : AxiLiteReadSlaveType;
      writeSlave       : AxiLiteWriteSlaveType;
      shadow           : PtpConfigType;
      config           : PtpConfigType;
      restart          : sl;
      configError      : sl;
      lastMac          : slv(47 downto 0);
      snapshotExchange : PtpExchangeType;
      snapshotAnnounce : slv(239 downto 0);
      identityOverride : sl;
      command          : PtpPhcCommandType;
      commandValid     : sl;
      busy             : sl;
      ack              : sl;
      error            : sl;
      setTime          : PtpTimeType;
      phaseOperand     : slv(127 downto 0);
      phase            : slv(127 downto 0);
      rate             : slv(63 downto 0);
      phaseIssue       : sl;
      phaseWait        : sl;
      snapshotPending  : sl;
      snapshotSequence : slv(31 downto 0);
      snapshotTime     : PtpTimeType;
      snapshotStatus   : PtpPhcStatusType;
      snapshotOffset   : slv(127 downto 0);
      snapshotDelay    : slv(127 downto 0);
      snapshotRate     : slv(63 downto 0);
      snapshotCounters : Slv32Array(0 to 7);
      snapshotGm       : slv(63 downto 0);
      snapshotFlags    : slv(15 downto 0);
      snapshotUtc      : slv(15 downto 0);
      irqStatus        : slv(31 downto 0);
      irqMask          : slv(31 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      readSlave        => AXI_LITE_READ_SLAVE_INIT_C,
      writeSlave       => AXI_LITE_WRITE_SLAVE_INIT_C,
      shadow           => initialConfig,
      config           => initialConfig,
      restart          => '0',
      configError      => '0',
      lastMac          => (others => '0'),
      snapshotExchange => PTP_EXCHANGE_INIT_C,
      snapshotAnnounce => (others => '0'),
      identityOverride => '0',
      command          => PTP_PHC_COMMAND_INIT_C,
      commandValid     => '0',
      busy             => '0',
      ack              => '0',
      error            => '0',
      setTime          => PTP_TIME_INIT_C,
      phaseOperand     => (others => '0'),
      phase            => (others => '0'),
      rate             => (others => '0'),
      phaseIssue       => '0',
      phaseWait        => '0',
      snapshotPending  => '0',
      snapshotSequence => (others => '0'),
      snapshotTime     => PTP_TIME_INIT_C,
      snapshotStatus   => PTP_PHC_STATUS_INIT_C,
      snapshotOffset   => (others => '0'),
      snapshotDelay    => (others => '0'),
      snapshotRate     => (others => '0'),
      snapshotCounters => (others => (others => '0')),
      snapshotGm       => (others => '0'),
      snapshotFlags    => (others => '0'),
      snapshotUtc      => (others => '0'),
      irqStatus        => (others => '0'),
      irqMask          => (others => '0'));

   signal r             : RegType := REG_INIT_C;
   signal rin           : RegType;
   signal mathReady     : sl;
   signal mathValid     : sl;
   signal mathResult    : slv(127 downto 0);
   signal mathRemainder : slv(127 downto 0);
   signal mathError     : sl;

   constant SECOND_Q16_C : slv(127 downto 0) := slv(shift_left(to_unsigned(1000000000, 128), 16));

begin

   U_Phase : entity surf.PtpMath
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk             => clk,             -- [in]
         rst             => rst,             -- [in]
         cancel          => '0',             -- [in]
         inputValid      => r.phaseIssue,    -- [in]
         inputReady      => mathReady,       -- [out]
         divide          => '1',             -- [in]
         roundNearest    => '0',             -- [in]
         operandA        => r.phaseOperand,  -- [in]
         operandB        => SECOND_Q16_C,    -- [in]
         resultValid     => mathValid,       -- [out]
         resultReady     => '1',             -- [in]
         resultValue     => mathResult,      -- [out]
         resultRemainder => mathRemainder,   -- [out]
         resultError     => mathError);      -- [out]

   comb : process (r, rst, regRst, axiReadMaster, axiWriteMaster, localMac, phcTime, phcStatus, captureAbort,
                   commandReady, commandAck, commandError, portActive, servoState, filteredDelay, offsetValue,
                   ratePpb, filterCount, exchange, announceBody, ledgerStatus, announceValid, grandmasterIdentity, announceFlags, utcOffset,
                   counters, mathReady, mathValid, mathResult, mathRemainder, mathError) is
      variable v             : RegType;
      variable ep            : AxiLiteEndpointType;
      variable commit        : sl;
      variable snapshot      : sl;
      variable commandWord   : slv(7 downto 0);
      variable irqClear      : slv(31 downto 0);
      variable invalidConfig : boolean;
      variable identity      : slv(79 downto 0);
   begin
      v := r;

      v.restart   := '0';
      v.lastMac   := localMac;
      commit      := '0';
      snapshot    := '0';
      commandWord := (others => '0');
      irqClear    := (others => '0');
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
      -- Decode only on an actual AXI transaction. PHC ticks and status changes
      -- need not re-evaluate the full register map on otherwise idle cycles.
      if ep.axiStatus.readEnable = '1' or ep.axiStatus.writeEnable = '1' then
         axiSlaveRegisterR(ep, x"000", 0, slv'(x"00010000"));
         axiSlaveRegister(ep, x"004", 0, v.shadow.enable);
         axiSlaveRegister(ep, x"004", 1, v.shadow.servoEnable);
         axiSlaveRegister(ep, x"004", 2, v.shadow.allowStep);
         axiSlaveRegister(ep, x"004", 3, v.shadow.monotonic);
         axiSlaveRegister(ep, x"004", 4, v.identityOverride);
         axiSlaveRegister(ep, x"008", 0, v.shadow.domainNumber);
         axiSlaveRegister(ep, x"008", 8, v.shadow.minorVersion);
         axiSlaveRegister(ep, x"010", 0, v.shadow.localIdentity);
         axiSlaveRegister(ep, x"020", 0, v.shadow.sourceIdentity);
         axiSlaveRegisterR(ep, x"030", 0, localMac);
         axiSlaveRegister(ep, x"03C", 0, commit);
         axiSlaveRegisterR(ep, x"040", 0, r.configError);
         axiSlaveRegisterR(ep, x"044", 0, r.config.enable);
         axiSlaveRegisterR(ep, x"044", 1, r.config.servoEnable);
         axiSlaveRegisterR(ep, x"044", 4, portActive);
         axiSlaveRegisterR(ep, x"044", 8, servoState);
         axiSlaveRegisterR(ep, x"044", 12, filterCount);
         axiSlaveRegisterR(ep, x"044", 16, announceValid);
         axiSlaveRegisterR(ep, x"048", 0, ledgerStatus);
         axiSlaveRegisterR(ep, x"060", 0, r.config.localIdentity);
         axiSlaveRegisterR(ep, x"070", 0, r.config.sourceIdentity);
         axiSlaveRegisterR(ep, x"04C", 0, r.irqStatus);
         axiSlaveRegister(ep, x"050", 0, v.irqMask);
         axiSlaveRegister(ep, x"054", 0, irqClear);
         axiSlaveRegister(ep, x"100", 0, snapshot);
         axiSlaveRegisterR(ep, x"104", 0, r.snapshotSequence);
         axiSlaveRegisterR(ep, x"108", 0, r.snapshotTime.seconds);
         axiSlaveRegisterR(ep, x"110", 0, r.snapshotTime.nanoseconds);
         axiSlaveRegisterR(ep, x"114", 0, r.snapshotTime.fraction);
         axiSlaveRegisterR(ep, x"118", 0, r.snapshotStatus.generation);
         axiSlaveRegisterR(ep, x"11C", 0, r.snapshotStatus.timeValid);
         axiSlaveRegister(ep, x"120", 0, commandWord);
         axiSlaveRegisterR(ep, x"124", 0, r.busy);
         axiSlaveRegisterR(ep, x"124", 1, r.ack);
         axiSlaveRegisterR(ep, x"124", 2, r.error);
         axiSlaveRegister(ep, x"128", 0, v.setTime.seconds);
         axiSlaveRegister(ep, x"130", 0, v.setTime.nanoseconds);
         axiSlaveRegister(ep, x"134", 0, v.setTime.fraction);
         axiSlaveRegister(ep, x"138", 0, v.phase);
         axiSlaveRegister(ep, x"148", 0, v.rate);
         axiSlaveRegisterR(ep, x"150", 0, ptpNominalIncrement(CLK_FREQ_G));
         axiSlaveRegisterR(ep, x"158", 0, r.snapshotStatus.rate);
         axiSlaveRegisterR(ep, x"160", 0, r.snapshotStatus.ticks);
         axiSlaveRegisterR(ep, x"168", 0, phcStatus.fault);
         axiSlaveRegister(ep, x"200", 0, v.shadow.delayInterval);
         axiSlaveRegister(ep, x"208", 0, v.shadow.syncTimeout);
         axiSlaveRegister(ep, x"210", 0, v.shadow.associationTimeout);
         axiSlaveRegister(ep, x"218", 0, v.shadow.maxDelayAge);
         axiSlaveRegister(ep, x"220", 0, v.shadow.holdoverTimeout);
         axiSlaveRegister(ep, x"228", 0, v.shadow.maxExchange);
         axiSlaveRegister(ep, x"230", 0, v.shadow.minRateSpan);
         axiSlaveRegister(ep, x"238", 0, v.shadow.maxRateAge);
         axiSlaveRegister(ep, x"240", 0, v.shadow.minSampleTicks);
         axiSlaveRegister(ep, x"248", 0, v.shadow.maxSampleTicks);
         axiSlaveRegister(ep, x"250", 0, v.shadow.lfsrSeed);
         axiSlaveRegister(ep, x"300", 0, v.shadow.kp);
         axiSlaveRegister(ep, x"304", 0, v.shadow.ki);
         axiSlaveRegister(ep, x"308", 0, v.shadow.maxFrequencyPpb);
         axiSlaveRegister(ep, x"30C", 0, v.shadow.maxSlewPpb);
         axiSlaveRegister(ep, x"310", 0, v.shadow.maxRatePpb);
         axiSlaveRegister(ep, x"318", 0, v.shadow.stepThreshold);
         axiSlaveRegister(ep, x"320", 0, v.shadow.lockThreshold);
         axiSlaveRegister(ep, x"328", 0, v.shadow.unlockThreshold);
         axiSlaveRegister(ep, x"330", 0, v.shadow.lockCount);
         axiSlaveRegister(ep, x"334", 0, v.shadow.unlockCount);
         axiSlaveRegister(ep, x"400", 0, v.shadow.maxPathDelay);
         axiSlaveRegister(ep, x"408", 0, v.shadow.delayAsymmetry);
         axiSlaveRegisterR(ep, x"380", 0, slv(to_unsigned(CLK_FREQ_G, 32)));
         axiSlaveRegisterR(ep, x"384", 0, slv(to_unsigned(PACKET_LIFETIME_G, 64)));
         axiSlaveRegisterR(ep, x"410", 0, INGRESS_LATENCY_G);
         axiSlaveRegisterR(ep, x"418", 0, EGRESS_LATENCY_G);
         axiSlaveRegisterR(ep, x"500", 0, r.snapshotOffset);
         axiSlaveRegisterR(ep, x"510", 0, r.snapshotDelay);
         axiSlaveRegisterR(ep, x"520", 0, r.snapshotRate);
         axiSlaveRegisterR(ep, x"530", 0, r.snapshotGm);
         axiSlaveRegisterR(ep, x"538", 0, r.snapshotFlags);
         axiSlaveRegisterR(ep, x"53C", 0, r.snapshotUtc);
         axiSlaveRegisterR(ep, x"540", 0, r.snapshotAnnounce);
         axiSlaveRegisterR(ep, x"560", 0, r.snapshotExchange.t1);
         axiSlaveRegisterR(ep, x"570", 0, r.snapshotExchange.t2);
         axiSlaveRegisterR(ep, x"580", 0, r.snapshotExchange.t3);
         axiSlaveRegisterR(ep, x"590", 0, r.snapshotExchange.t4);
         axiSlaveRegisterR(ep, x"5A0", 0, r.snapshotExchange.syncCorrection);
         axiSlaveRegisterR(ep, x"5B0", 0, r.snapshotExchange.delayCorrection);
         axiSlaveRegisterR(ep, x"5B8", 0, r.snapshotExchange.generation);
         axiSlaveRegisterR(ep, x"5BC", 0, r.snapshotExchange.syncSequence);
         axiSlaveRegisterR(ep, x"5BC", 16, r.snapshotExchange.delaySequence);
         for i in 0 to 7 loop
            axiSlaveRegisterR(ep, slv(to_unsigned(16#600#+4*i, 12)), 0, r.snapshotCounters(i));
         end loop;
      end if;
      if r.commandValid = '1' and commandReady = '1' then
         v.commandValid := '0';
      end if;
      if commandAck = '1' and r.busy = '1' then
         v.busy  := '0';
         v.ack   := '1';
         v.error := commandError;
      end if;
      if r.phaseIssue = '1' and mathReady = '1' then
         v.phaseIssue := '0';
         v.phaseWait  := '1';
      end if;
      if r.phaseWait = '1' and mathValid = '1' then
         v.phaseWait := '0';
         if mathError = '1' or resize(resize(signed(mathResult), 64), 128) /= signed(mathResult) then
            v.busy  := '0';
            v.ack   := '1';
            v.error := '1';
         else
            v.command.phaseSeconds  := mathResult(63 downto 0);
            v.command.phaseFraction := slv(shift_left(resize(signed(mathRemainder), 64), 16));
            v.commandValid          := '1';
         end if;
      end if;
      if commandWord(7) = '1' then
         -- Manual time writes require automatic control disabled. A command is
         -- copied out of all shadow words before acceptance, then held stable
         -- until acknowledgement; subsequent shadow edits cannot mutate it.
         if r.busy = '1' or (r.config.servoEnable = '1' and commandWord(2 downto 0) /= PTP_CMD_PPS_C) or unsigned(commandWord(2 downto 0)) > 4 then
            ep.axiWriteSlave.bresp := AXI_RESP_SLVERR_C;
         else
            v.command            := PTP_PHC_COMMAND_INIT_C;
            v.command.kind       := commandWord(2 downto 0);
            v.command.value      := commandWord(3);
            v.command.generation := phcStatus.generation;
            v.command.setTime    := r.setTime;
            v.command.rate       := r.rate;
            v.busy               := '1';
            v.ack                := '0';
            v.error              := '0';
            if commandWord(2 downto 0) = PTP_CMD_PHASE_C then
               v.phaseOperand := r.phase;
               v.phaseIssue   := '1';
            else
               v.commandValid := '1';
            end if;
         end if;
      end if;
      if commit = '1' then
         invalidConfig := r.busy = '1' or unsigned(v.shadow.minorVersion) > 1 or
            signed(v.shadow.maxPathDelay) <= 0 or signed(v.shadow.stepThreshold) < 0 or
            signed(v.shadow.lockThreshold) < 0 or signed(v.shadow.unlockThreshold) < signed(v.shadow.lockThreshold) or
            unsigned(v.shadow.minRateSpan) = 0 or unsigned(v.shadow.delayInterval) = 0 or
            unsigned(v.shadow.syncTimeout) = 0 or unsigned(v.shadow.associationTimeout) = 0 or
            unsigned(v.shadow.maxDelayAge) = 0 or unsigned(v.shadow.holdoverTimeout) = 0 or
            unsigned(v.shadow.minSampleTicks) = 0 or unsigned(v.shadow.maxSampleTicks) < unsigned(v.shadow.minSampleTicks) or
            unsigned(v.shadow.maxRatePpb) > 200000 or unsigned(v.shadow.maxFrequencyPpb) > unsigned(v.shadow.maxRatePpb) or
            unsigned(v.shadow.maxSlewPpb) > unsigned(v.shadow.maxRatePpb) or unsigned(v.shadow.lockCount) = 0 or
            unsigned(v.shadow.unlockCount) = 0 or unsigned(v.shadow.localIdentity(15 downto 0)) = 0 or
            unsigned(v.shadow.sourceIdentity(15 downto 0)) = 0 or
            unsigned(v.shadow.maxRateAge) < unsigned(v.shadow.minRateSpan) or unsigned(v.shadow.maxExchange) = 0 or
            unsigned(v.shadow.associationTimeout) < 2048;
         invalidConfig := invalidConfig or v.shadow.delayInterval(63 downto 62) /= "00";
         invalidConfig := invalidConfig or v.shadow.syncTimeout(63 downto 62) /= "00";
         invalidConfig := invalidConfig or v.shadow.associationTimeout(63 downto 62) /= "00";
         invalidConfig := invalidConfig or v.shadow.maxDelayAge(63 downto 62) /= "00";
         invalidConfig := invalidConfig or v.shadow.holdoverTimeout(63 downto 62) /= "00";
         invalidConfig := invalidConfig or v.shadow.maxExchange(63 downto 62) /= "00";
         invalidConfig := invalidConfig or v.shadow.minRateSpan(63 downto 62) /= "00";
         invalidConfig := invalidConfig or v.shadow.maxRateAge(63 downto 62) /= "00";
         invalidConfig := invalidConfig or v.shadow.minSampleTicks(63 downto 62) /= "00";
         invalidConfig := invalidConfig or v.shadow.maxSampleTicks(63 downto 62) /= "00";
         if invalidConfig then
            v.configError          := '1';
            ep.axiWriteSlave.bresp := AXI_RESP_SLVERR_C;
         else
            v.config                  := v.shadow;
            v.config.identityOverride := v.identityOverride;
            if v.identityOverride = '0' then
               -- localMac follows SURF's low-byte-first address convention.
               identity               := localMac(7 downto 0) & localMac(15 downto 8) & localMac(23 downto 16) &
                  x"FFFE" & localMac(31 downto 24) & localMac(39 downto 32) & localMac(47 downto 40) & v.shadow.localIdentity(15 downto 0);
               v.config.localIdentity := identity;
            end if;
            v.configError := '0';
            v.restart     := '1';
         end if;
      end if;
      if localMac /= r.lastMac then
         v.restart := '1';
         if v.config.identityOverride = '0' then
            v.config.localIdentity := localMac(7 downto 0) & localMac(15 downto 8) & localMac(23 downto 16) &
               x"FFFE" & localMac(31 downto 24) & localMac(39 downto 32) & localMac(47 downto 40) & v.config.localIdentity(15 downto 0);
         end if;
      end if;
      if snapshot = '1' then
         v.snapshotPending := '1';
      end if;
      if r.snapshotPending = '1' and captureAbort = '0' then
         v.snapshotPending  := '0';
         v.snapshotSequence := ptpSatInc(r.snapshotSequence);
         v.snapshotTime     := phcTime;
         v.snapshotStatus   := phcStatus;
         v.snapshotOffset   := offsetValue;
         v.snapshotDelay    := filteredDelay;
         v.snapshotRate     := ratePpb;
         v.snapshotCounters := counters;
         v.snapshotGm       := grandmasterIdentity;
         v.snapshotFlags    := announceFlags;
         v.snapshotUtc      := utcOffset;
         v.snapshotExchange := exchange;
         v.snapshotAnnounce := announceBody;
      end if;
      v.irqStatus    := r.irqStatus and not irqClear;
      v.irqStatus(0) := v.irqStatus(0) or phcStatus.fault;
      v.irqStatus(1) := v.irqStatus(1) or phcStatus.discontinuity;
      v.irqStatus(2) := v.irqStatus(2) or phcStatus.error;
      if servoState = "101" then
         v.irqStatus(3) := '1';
      end if;
      axiSlaveDefault(ep, v.writeSlave, v.readSlave, AXI_RESP_DECERR_C);
      -- AXI-only reset cancels bus responses, never an accepted PHC command,
      -- active configuration, or the PHC itself.
      if regRst = '1' then
         v.readSlave  := AXI_LITE_READ_SLAVE_INIT_C;
         v.writeSlave := AXI_LITE_WRITE_SLAVE_INIT_C;
      end if;
      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;
      rin           <= v;
      axiReadSlave  <= r.readSlave;
      axiWriteSlave <= r.writeSlave;
      config        <= r.config;
      configRestart <= '1' when localMac /= r.lastMac else r.restart;
      command       <= r.command;
      commandValid  <= r.commandValid;
      irq           <= '1' when unsigned(r.irqStatus and r.irqMask) /= 0 else '0';
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
