-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PTP acquisition, filtered delay estimation and PHC feedback
-- control.
--
-- Composes the delay filter and the PI loop, owns this core's AXI-Lite bank,
-- and routes measurements to whichever child consumes them. Delay measurements
-- refresh the filter; an eligible forward (Sync) measurement starts a
-- correction using the latest filtered delay.
--
-- There is no local 1 Hz servo timer. A 1 Hz Sync source gives approximately
-- that update cadence after acquisition, and qualification can reject updates.
-- The actuator is the PHC's numerical ns-per-tick increment; no output of this
-- module directly tunes the oscillator supplying clk.
--
-- PtpServoFilter publishes the median of up to five populated delay samples.
-- PtpServoPi computes local-minus-master offset, runs the fixed-point
-- proportional/integral loop with its clamps and conditional integration, and
-- generates PHC commands through the ready/valid/acknowledge lifecycle. Only
-- acknowledged rate commands update the retained frequency estimate. Phase
-- acquisition and the rate command share one SECOND converter with manual PHC
-- preparation; the loop keeps local converters for its nanosecond and nominal
-- conversions.
--
-- Lock/unlock thresholds and counters provide quality hysteresis. Loss of
-- fresh measurements enters holdover, removes phase slew and preserves the
-- last good frequency; registered expiry requests time-validity revocation on
-- the next PHC edge. A disabled servo drains measurements without steering.
-- PtpEndpointControl owns restart policy.
--
-- The local AXI-Lite bank stores gains, step/lock policy, sample-age limits
-- and asymmetry as writable shadows, frozen candidates and active settings.
-- Candidate validity is captured on prepare for the later coordinated apply.
-- Shared association, sync and path-delay limits come from PtpProtocolEngine's
-- active sharedConfig record, keeping one owner for settings used by both
-- cores. The common snapshot strobe stores filter, offset, rate and rejection
-- state locally with the endpoint sequence, so AXI read latency cannot mix
-- samples.
--
-- Management state uses this module's RegType/comb/seq pair; the arithmetic
-- lives in the children. regRst clears AXI responses without resetting the
-- active loop configuration; restart and measurement cancellation retain their
-- separate lifecycle roles. PtpPhc owns final arbitration between these
-- commands and manual writes.
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
use surf.PtpRegisterPkg.all;

entity PtpServo is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      CLK_FREQ_G     : positive := 156250000);
   port (
      -- Shared endpoint clock domain.
      clk : in sl;
      rst : in sl;

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
      restart           : in  sl := '0';
      phcStatus         : in  PtpPhcStatusType;

      -- Registered revocation level; the PHC consumes it on the next edge.
      expireTime    : out sl;
      commandMaster : out PtpPhcCommandMasterType;
      commandSlave  : in  PtpPhcCommandSlaveType;
      status        : out PtpServoStatusType;

      -- Shared SECOND service, also used by manual PHC preparation.
      secondValid       : out sl;
      secondReady       : in  sl                := '0';
      secondRound       : out sl;
      secondOperand     : out slv(127 downto 0);
      secondCancel      : out sl;
      secondResultValid : in  sl                := '0';
      secondResultReady : out sl;
      secondQuotient    : in  slv(127 downto 0) := (others => '0');
      secondRemainder   : in  slv(127 downto 0) := (others => '0'));
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
      v.minSampleTicks  := slv(TICK_C/64);              -- 1/64 s, rounded down to ticks.
      v.maxSampleTicks  := slv(resize(TICK_C*2, 64));   -- 2 s.
      return v;
   end function;

   function initialWords return Slv32Array is
      constant CFG_C : PtpServoConfigType := initialConfig;
      variable words : Slv32Array(0 to 33) := (others => (others => '0'));

      procedure put (
         constant index : natural;
         constant value : slv) is
      begin
         for i in 0 to (value'length+31)/32-1 loop
            words(index+i) := slv(resize(shift_right(unsigned(value), 32*i), 32));
         end loop;
      end procedure;

   begin
      words(1)(2) := CFG_C.allowStep;
      put(8, CFG_C.kp);
      put(9, CFG_C.ki);
      put(10, CFG_C.maxFrequencyPpb);
      put(11, CFG_C.maxSlewPpb);
      put(12, CFG_C.maxRatePpb);
      put(14, CFG_C.stepThreshold);
      put(16, CFG_C.lockThreshold);
      put(18, CFG_C.unlockThreshold);
      put(20, CFG_C.lockCount);
      put(21, CFG_C.unlockCount);
      put(24, CFG_C.maxDelayAge);
      put(26, CFG_C.holdoverTimeout);
      put(28, CFG_C.minSampleTicks);
      put(30, CFG_C.maxSampleTicks);
      put(32, CFG_C.delayAsymmetry);
      return words;
   end function;

   function configIndex (address : slv(11 downto 0)) return integer is
      variable index : natural := to_integer(unsigned(address(11 downto 2)));
   begin

      case index is
         when 1 | 8 to 12 | 14 to 21 | 24 to 33 =>
            return index;
         when others =>
            return -1;
      end case;

   end function;

   function configMask (
      index  : integer;
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

   -- Publication records: offset, filtered delay and rate, each streamed into
   -- the bank one 32-bit word at a time.
   constant OFFSET_RECORD_C : slv(3 downto 0) := x"0";
   constant FILTER_RECORD_C : slv(3 downto 0) := x"1";
   constant RATE_RECORD_C   : slv(3 downto 0) := x"2";

   type PublishStateType is (IDLE_S, WRITE_S, COMMIT_S);

   type RegType is record
      -- Combinational measurement admission, resolved through v each cycle.
      measurementSlave : PtpMeasurementSlaveType;

      -- Local management state shares the core reset and register process.
      readSlave         : AxiLiteReadSlaveType;
      writeSlave        : AxiLiteWriteSlaveType;
      candidate         : PtpServoConfigType;
      configBus         : PtpRegisterBusType;
      validateValue     : slv(63 downto 0);
      validatePrevious  : slv(63 downto 0);
      validateFrequency : slv(31 downto 0);
      validateSlew      : slv(31 downto 0);
      configValid       : sl;
      activeConfig      : PtpServoConfigType;
      sequenceId        : slv(31 downto 0);
      publicationPort   : PtpPublicationType;
      snapshotBus       : PtpRegisterBusType;
      counterBus        : PtpRegisterBusType;

      -- Measurement routing and publication streaming.
      publishState  : PublishStateType;
      publishRecord : slv(3 downto 0);
      publishWord   : natural range 0 to 3;
      publishWords  : natural range 1 to 4;
      publishValue  : slv(127 downto 0);
      pendingOffset : sl;
      pendingFilter : sl;
      pendingRate   : sl;
      delayValid    : sl;
      forwardValid  : sl;
      delayValue    : slv(127 downto 0);
      forwardValue  : slv(127 downto 0);
      ratio         : slv(63 downto 0);
      ratioValid    : sl;
      sampleTicks   : slv(63 downto 0);
      sampleGen     : slv(31 downto 0);
      rejectedCount : slv(31 downto 0);
      status        : PtpServoStatusType;
      generation    : slv(31 downto 0);
      abortSeen     : sl;
      cancel        : sl;
   end record;

   constant REG_INIT_C : RegType := (
      measurementSlave  => PTP_MEASUREMENT_SLAVE_INIT_C,
      readSlave         => AXI_LITE_READ_SLAVE_INIT_C,
      writeSlave        => AXI_LITE_WRITE_SLAVE_INIT_C,
      candidate         => initialConfig,
      configBus         => PTP_REGISTER_BUS_INIT_C,
      validateValue     => (others => '0'),
      validatePrevious  => (others => '0'),
      validateFrequency => (others => '0'),
      validateSlew      => (others => '0'),
      configValid       => '1',
      activeConfig      => initialConfig,
      sequenceId        => (others => '0'),
      publicationPort   => PTP_PUBLICATION_INIT_C,
      snapshotBus       => PTP_REGISTER_BUS_INIT_C,
      counterBus        => PTP_REGISTER_BUS_INIT_C,
      publishState      => IDLE_S,
      publishRecord     => (others => '0'),
      publishWord       => 0,
      publishWords      => 4,
      publishValue      => (others => '0'),
      pendingOffset     => '0',
      pendingFilter     => '0',
      pendingRate       => '0',
      delayValid        => '0',
      forwardValid      => '0',
      delayValue        => (others => '0'),
      forwardValue      => (others => '0'),
      ratio             => (others => '0'),
      ratioValid        => '0',
      sampleTicks       => (others => '0'),
      sampleGen         => (others => '0'),
      rejectedCount     => (others => '0'),
      status            => PTP_SERVO_STATUS_INIT_C,
      generation        => (others => '0'),
      abortSeen         => '0',
      cancel            => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- The bank keeps its two-master interface. Only the AXI port is used now:
   -- the loop reads its settings from the applied active record instead of
   -- fetching each operand word at arithmetic time.
   signal configMasters : PtpRegisterMasterArray(0 to 1);
   signal configSlaves  : PtpRegisterSlaveArray(0 to 1);
   signal scanValid     : sl;
   signal scanIndex     : slv(7 downto 0);
   signal scanData      : slv(31 downto 0);
   signal snapshotSlave : PtpRegisterSlaveType;
   signal counterSlave  : PtpRegisterSlaveType;

   -- Filter interface.
   signal filterInputValid : sl;
   signal filterInputReady : sl;
   signal filterValid      : sl;
   signal filteredDelay    : slv(127 downto 0);
   signal filterCount      : slv(2 downto 0);
   signal filterTicks      : slv(63 downto 0);
   signal filterUpdate     : sl;
   signal filterReject     : sl;

   -- PI interface.
   signal piInputValid : sl;
   signal piInputReady : sl;
   signal piStatus     : PtpServoStatusType;
   signal piOffsetUpd  : sl;
   signal piRateUpd    : sl;

begin

   U_Publication : entity surf.PtpPublicationBank
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         RECORD_WORDS_G => IntegerArray'(4, 4, 2))
      port map (
         clk         => clk,                  -- [in]
         rst         => rst,                  -- [in]
         publication => r.publicationPort,    -- [in]
         snapshot    => snapshotControl,      -- [in]
         master      => r.snapshotBus.master, -- [in]
         slave       => snapshotSlave);       -- [out]

   U_Snapshot : entity surf.PtpSnapshotBank
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         WORDS_G        => 1)
      port map (
         clk      => clk,                                     -- [in]
         rst      => rst,                                     -- [in]
         scalars  => Slv32Array'(0 => r.rejectedCount),       -- [in]
         snapshot => snapshotControl,                         -- [in]
         prepared => snapshotPrepared,                        -- [out]
         master   => r.counterBus.master,                     -- [in]
         slave    => counterSlave);                           -- [out]

   configMasters(0) <= r.configBus.master;
   configMasters(1) <= PTP_REGISTER_MASTER_INIT_C;

   U_Config : entity surf.PtpConfigBank
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         DEFAULTS_G     => initialWords,
         MEMORY_TYPE_G  => "block")
      port map (
         clk       => clk,            -- [in]
         rst       => rst,            -- [in]
         prepare   => configControl.prepare,  -- [in]
         apply     => configControl.apply,    -- [in]
         prepared  => configPrepared,  -- [out]
         scanValid => scanValid,       -- [out]
         scanIndex => scanIndex,       -- [out]
         scanData  => scanData,        -- [out]
         masters   => configMasters,   -- [in]
         slaves    => configSlaves);   -- [out]

   U_Filter : entity surf.PtpServoFilter
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         DEPTH_G        => DELAY_FILTER_DEPTH_C)
      port map (
         clk           => clk,                       -- [in]
         rst           => rst,                       -- [in]
         cancel        => r.cancel,                  -- [in]
         inputValid    => filterInputValid,          -- [in]
         inputReady    => filterInputReady,          -- [out]
         delayValue    => r.delayValue,              -- [in]
         sampleTicks   => r.sampleTicks,             -- [in]
         maxPathDelay  => sharedConfig.maxPathDelay, -- [in]
         filterValid   => filterValid,               -- [out]
         filteredDelay => filteredDelay,             -- [out]
         filterCount   => filterCount,               -- [out]
         filterTicks   => filterTicks,               -- [out]
         filterUpdate  => filterUpdate,              -- [out]
         filterReject  => filterReject);             -- [out]

   U_Pi : entity surf.PtpServoPi
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         CLK_FREQ_G     => CLK_FREQ_G)
      port map (
         clk               => clk,                -- [in]
         rst               => rst,                -- [in]
         cancel            => r.cancel,           -- [in]
         enable            => servoEnable,        -- [in]
         config            => r.activeConfig,     -- [in]
         sharedConfig      => sharedConfig,       -- [in]
         phcStatus         => phcStatus,          -- [in]
         inputValid        => piInputValid,       -- [in]
         inputReady        => piInputReady,       -- [out]
         sampleTicks       => r.sampleTicks,      -- [in]
         sampleGeneration  => r.sampleGen,        -- [in]
         forwardValue      => r.forwardValue,     -- [in]
         ratio             => r.ratio,            -- [in]
         ratioValid        => r.ratioValid,       -- [in]
         filteredDelay     => filteredDelay,      -- [in]
         filterValid       => filterValid,        -- [in]
         filterTicks       => filterTicks,        -- [in]
         commandMaster     => commandMaster,      -- [out]
         commandSlave      => commandSlave,       -- [in]
         expireTime        => expireTime,         -- [out]
         status            => piStatus,           -- [out]
         offsetUpdate      => piOffsetUpd,        -- [out]
         rateUpdate        => piRateUpd,          -- [out]
         secondValid       => secondValid,        -- [out]
         secondReady       => secondReady,        -- [in]
         secondRound       => secondRound,        -- [out]
         secondOperand     => secondOperand,      -- [out]
         secondCancel      => secondCancel,       -- [out]
         secondResultValid => secondResultValid,  -- [in]
         secondResultReady => secondResultReady,  -- [out]
         secondQuotient    => secondQuotient,     -- [in]
         secondRemainder   => secondRemainder);   -- [out]

   comb : process (all) is
      variable readAddress      : slv(11 downto 0);
      variable writeAddress     : slv(11 downto 0);
      variable v                : RegType;
      variable ep               : AxiLiteEndpointType;
      variable configReadIndex  : integer range -1 to 33;
      variable configWriteIndex : integer range -1 to 33;
      variable configReadBank   : slv(1 downto 0);
      variable configIndexValue : natural range 0 to 255;
      variable snapshotIndex    : integer range -1 to 9;
      variable cancelNow        : boolean;
   begin
      v := r;
      v.measurementSlave := PTP_MEASUREMENT_SLAVE_INIT_C;
      v.publicationPort.write := '0';
      v.publicationPort.commit := '0';

      -- A held link/port abort cancels once, allowing later holdover work.
      -- Generation changes independently invalidate work.
      cancelNow := restart = '1' or
                   (measurementMaster.abort = '1' and r.abortSeen = '0') or
                   phcStatus.generation /= r.generation or servoEnable = '0';
      v.cancel := toSl(cancelNow);
      v.abortSeen := measurementMaster.abort;
      v.generation := phcStatus.generation;

      -------------------------------------------------------------------------
      -- Measurement routing. One measurement is held for one child at a time.
      -------------------------------------------------------------------------
      if r.delayValid = '1' and filterInputReady = '1' then
         v.delayValid := '0';
      end if;

      if r.forwardValid = '1' and piInputReady = '1' then
         v.forwardValid := '0';
      end if;

      if v.delayValid = '0' and v.forwardValid = '0' and cancelNow = false then
         v.measurementSlave.ready := '1';

         if measurementMaster.valid = '1' and measurementMaster.abort = '0' and
            servoEnable = '1' then
            -- Reject a measurement whose provenance cannot match this PHC
            -- epoch before either child sees it.
            if measurementMaster.data.generation /= phcStatus.generation or
               unsigned(measurementMaster.data.ticks) > unsigned(phcStatus.ticks) or
               ptpAgeExpired(phcStatus.ticks, measurementMaster.data.ticks,
                             sharedConfig.associationTimeout) then
               v.rejectedCount := ptpSatInc(r.rejectedCount);
            elsif measurementMaster.data.isDelay = '1' then
               v.delayValue := measurementMaster.data.delayValue;
               v.sampleTicks := measurementMaster.data.ticks;
               v.delayValid := '1';
            else
               v.forwardValue := measurementMaster.data.forward;
               v.ratio := measurementMaster.data.ratio;
               v.ratioValid := measurementMaster.data.ratioValid;
               v.sampleTicks := measurementMaster.data.ticks;
               v.sampleGen := measurementMaster.data.generation;
               v.forwardValid := '1';
            end if;
         end if;
      end if;

      -------------------------------------------------------------------------
      -- Publication streaming. Each child strobe queues one record; the words
      -- then stream into the bank and commit atomically.
      -------------------------------------------------------------------------
      -- Both children report their own rejections; this core counts them
      -- alongside the provenance rejections it applies itself.
      if filterReject = '1' then
         v.rejectedCount := ptpSatInc(r.rejectedCount);
      end if;

      if piOffsetUpd = '1' then
         v.pendingOffset := '1';
      end if;

      if filterUpdate = '1' then
         v.pendingFilter := '1';
      end if;

      if piRateUpd = '1' then
         v.pendingRate := '1';
      end if;

      case r.publishState is
         when IDLE_S =>

            if r.pendingOffset = '1' then
               v.pendingOffset := '0';
               v.publishRecord := OFFSET_RECORD_C;
               v.publishValue := piStatus.offsetValue;
               v.publishWords := 4;
               v.publishWord := 0;
               v.publishState := WRITE_S;
            elsif r.pendingFilter = '1' then
               v.pendingFilter := '0';
               v.publishRecord := FILTER_RECORD_C;
               v.publishValue := filteredDelay;
               v.publishWords := 4;
               v.publishWord := 0;
               v.publishState := WRITE_S;
            elsif r.pendingRate = '1' then
               v.pendingRate := '0';
               v.publishRecord := RATE_RECORD_C;
               v.publishValue := slv(resize(signed(piStatus.ratePpb), 128));
               v.publishWords := 2;
               v.publishWord := 0;
               v.publishState := WRITE_S;
            end if;

         when WRITE_S =>
            v.publicationPort.write := '1';
            v.publicationPort.first := toSl(r.publishWord = 0);
            v.publicationPort.recordIndex := r.publishRecord;
            v.publicationPort.wordIndex := toSlv(r.publishWord, 8);
            v.publicationPort.data :=
               r.publishValue(32*r.publishWord+31 downto 32*r.publishWord);

            if r.publishWord = r.publishWords-1 then
               v.publishState := COMMIT_S;
            else
               v.publishWord := r.publishWord+1;
            end if;

         when COMMIT_S =>
            v.publicationPort.commit := '1';
            v.publicationPort.commitRecord := r.publishRecord;
            v.publishState := IDLE_S;
      end case;

      -- Cancellation discards queued publication work; a commit already
      -- issued belongs to the bank.
      if cancelNow then
         v.measurementSlave.ready := '0';
         v.delayValid := '0';
         v.forwardValid := '0';
         v.pendingOffset := '0';
         v.pendingFilter := '0';
         v.pendingRate := '0';
         v.publishState := IDLE_S;
         v.publicationPort.write := '0';
         v.publicationPort.commit := '0';
      end if;

      if servoEnable = '0' then
         -- Manual ownership still drains the port's measurement queue, even
         -- after a servo fault. Reset below has final admission priority.
         v.measurementSlave.ready := '1';
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

      -- Live quality and active local/shared configuration.
      axiSlaveRegisterR(ep, x"090", 0, r.status.state);
      axiSlaveRegisterR(ep, x"090", 4, r.status.filterCount);
      axiSlaveRegisterR(ep, x"0A0", 0, sharedConfig.associationTimeout);
      axiSlaveRegisterR(ep, x"0A8", 0, sharedConfig.syncTimeout);
      axiSlaveRegisterR(ep, x"0B0", 0, sharedConfig.maxPathDelay);
      -- Coherent measurement and diagnostic snapshots.
      axiSlaveRegisterR(ep, x"3FC", 0, r.sequenceId);
      configReadIndex := configIndex(readAddress);
      configWriteIndex := configIndex(writeAddress);
      configReadBank := "00";

      if readAddress(11 downto 2) = slv(to_unsigned(16#094#/4, 10)) then
         configReadIndex := 8;
         configReadBank := "01";
      elsif readAddress(11 downto 2) = slv(to_unsigned(16#098#/4, 10)) then
         configReadIndex := 9;
         configReadBank := "01";
      end if;

      ptpRegisterBus(v.configBus, r.configBus, configSlaves(0), ep, configReadIndex,
         configWriteIndex, configMask(configWriteIndex, ep.axiWriteMaster.wstrb),
         configReadBank, regRst);
      snapshotIndex := -1;

      if unsigned(readAddress(11 downto 2)) >= 64 and
         unsigned(readAddress(11 downto 2)) <= 73 then
         snapshotIndex := to_integer(unsigned(readAddress(11 downto 2)))-64;
      end if;

      ptpRegisterBus(v.snapshotBus, r.snapshotBus, snapshotSlave, ep, snapshotIndex,
         -1, x"00000000", "00", regRst);
      snapshotIndex := -1;

      if readAddress(11 downto 2) = slv(to_unsigned(128, 10)) then
         snapshotIndex := 0;
      end if;

      ptpRegisterBus(v.counterBus, r.counterBus, counterSlave, ep, snapshotIndex,
         -1, x"00000000", "00", regRst);
      axiSlaveDefault(ep, v.writeSlave, v.readSlave, AXI_RESP_DECERR_C);

      -- The bus reset cancels responses only. Accepted operations and active
      -- settings belong to the system-reset lifetime, not the AXI transaction.
      if regRst = '1' then
         v.readSlave := AXI_LITE_READ_SLAVE_INIT_C;
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
            when 8 =>
               v.candidate.kp := scanData;
            when 9 =>
               v.candidate.ki := scanData;
            when 10 =>
               v.candidate.maxFrequencyPpb := scanData;
               v.validateFrequency := scanData;
            when 11 =>
               v.candidate.maxSlewPpb := scanData;
               v.validateSlew := scanData;
            when 12 =>
               v.candidate.maxRatePpb := scanData;
               if unsigned(scanData) > MAX_ACTUATOR_PPB_C or
                  unsigned(r.validateFrequency) > unsigned(scanData) or
                  unsigned(r.validateSlew) > unsigned(scanData) then
                  v.configValid := '0';
               end if;
            when 15 | 17 =>
               if scanData(31) = '1' then
                  v.configValid := '0';
               end if;
               if configIndexValue = 15 then
                  v.candidate.stepThreshold := v.validateValue;
               else
                  v.candidate.lockThreshold := v.validateValue;
               end if;
               v.validatePrevious := v.validateValue;
            when 19 =>
               v.candidate.unlockThreshold := v.validateValue;
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
               if not ptpValidTimeout(v.validateValue) or
                  unsigned(v.validateValue) < unsigned(r.validatePrevious) then
                  v.configValid := '0';
               end if;
            when 33 =>
               v.candidate.delayAsymmetry := v.validateValue;
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

      -- The published status joins each owner's fields: the PI loop owns
      -- quality, offset and rate; the filter owns the delay median and its
      -- population; this core owns the combined rejection counter. The record
      -- is a public interface, so it is assembled here rather than split.
      v.status := piStatus;
      v.status.filteredDelay := filteredDelay;
      v.status.filterCount := filterCount;
      v.status.rejectedCount := v.rejectedCount;

      -- Apply synchronous reset before publishing next state and outputs.
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin <= v;

      -- Publish resolved controls and registered payloads without another
      -- decision stage. Measurement ready is the reverse capacity exception:
      -- holdover work and current cancellation share its input slot, and a
      -- delayed ready would require an extra reserved sample slot.
      filterInputValid <= v.delayValid;
      piInputValid <= v.forwardValid;

      axiReadSlave <= r.readSlave;
      axiWriteSlave <= r.writeSlave;
      configValid <= r.configValid;
      measurementSlave <= v.measurementSlave;
      status <= r.status;
   end process comb;

   seq : process (clk, rst) is
   begin
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
