-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PTP endpoint telemetry records: PHC, measurement and servo.
--
-- Observes endpoint signals and emits fixed-format records, one SSI frame of
-- 64-bit words each (ethernet/PtpCore/telemetry.md). It drives no ready or
-- command: a slow consumer loses records, never delays the endpoint.
--
-- Each record type has one capture buffer, filled on its trigger edge with a
-- coherent PHC sample. A trigger that finds its buffer occupied is dropped and
-- counted; every trigger takes the next record sequence number, so drops show
-- as gaps. A servo command arms its buffer: the command is captured on its
-- acceptance edge and the PHC sample and servo status two edges later, after
-- the servo's status update. Waiting buffers are sent PHC, measurement, servo.
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

entity PtpTelemetry is
   generic (
      TPD_G          : time                   := 1 ns;
      RST_POLARITY_G : sl                     := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      TELEMETRY_ID_G : natural                := 0);
   port (
      clk               : in  sl;
      rst               : in  sl;
      -- Observed endpoint state
      phcTime           : in  PtpTimeType;
      phcStatus         : in  PtpPhcStatusType;
      portActive        : in  sl;
      linkReady         : in  sl;
      measurementMaster : in  PtpMeasurementMasterType;
      measurementSlave  : in  PtpMeasurementSlaveType;
      exchange          : in  PtpExchangeType;
      commandMaster     : in  PtpPhcCommandMasterType;
      commandSlave      : in  PtpPhcCommandSlaveType;
      servoStatus       : in  PtpServoStatusType;
      -- Records in PTP_TELEMETRY_AXIS_CONFIG_C
      telemetryMaster   : out AxiStreamMasterType;
      telemetrySlave    : in  AxiStreamSlaveType;
      dropped           : out slv(31 downto 0));
end entity PtpTelemetry;

architecture rtl of PtpTelemetry is

   constant PHC_WORDS_C   : positive := 8;
   constant MEAS_WORDS_C  : positive := 27;
   constant SERVO_WORDS_C : positive := 19;

   -- PHC sample and header flags, taken on one edge.
   type SampleType is record
      phcTime    : PtpTimeType;
      ticks      : slv(63 downto 0);
      rate       : slv(63 downto 0);
      increment  : slv(63 downto 0);
      generation : slv(31 downto 0);
      servoState : slv(2 downto 0);
      timeValid  : sl;
      portActive : sl;
      linkReady  : sl;
      fault      : sl;
   end record SampleType;

   -- Command fields of a servo record not triggered by a command.
   constant NO_COMMAND_C : PtpPhcCommandType := (
      kind          => (others => '0'),
      generation    => (others => '0'),
      setTime       => PTP_TIME_INIT_C,
      phaseSeconds  => (others => '0'),
      phaseFraction => (others => '0'),
      rate          => (others => '0'),
      value         => '0');

   constant SAMPLE_INIT_C : SampleType := (
      phcTime    => PTP_TIME_INIT_C,
      ticks      => (others => '0'),
      rate       => (others => '0'),
      increment  => (others => '0'),
      generation => (others => '0'),
      servoState => (others => '0'),
      timeValid  => '0',
      portActive => '0',
      linkReady  => '0',
      fault      => '0');

   -- One buffer per record type; pending covers waiting and sending.
   type BufferType is record
      pending     : sl;
      recordSeq    : slv(31 downto 0);
      cause       : slv(7 downto 0);
      sample      : SampleType;
      measurement : PtpMeasurementType;
      exchange    : PtpExchangeType;
      command     : PtpPhcCommandType;
      servo       : PtpServoStatusType;
   end record BufferType;

   constant BUFFER_INIT_C : BufferType := (
      pending     => '0',
      recordSeq    => (others => '0'),
      cause       => (others => '0'),
      sample      => SAMPLE_INIT_C,
      measurement => PTP_MEASUREMENT_INIT_C,
      exchange    => PTP_EXCHANGE_INIT_C,
      command     => NO_COMMAND_C,
      servo       => PTP_SERVO_STATUS_INIT_C);

   type StateType is (
      IDLE_S,
      PHC_S,
      MEAS_S,
      SERVO_S);

   type RegType is record
      -- Previous-edge values for PHC event detection
      lastSeconds    : slv(47 downto 0);
      lastGeneration : slv(31 downto 0);
      lastTimeValid  : sl;
      lastPort       : sl;
      lastLink       : sl;
      lastFault      : sl;
      lastServoState : slv(2 downto 0);
      started        : sl;
      -- Record bookkeeping
      recordSeq       : slv(31 downto 0);
      dropped        : slv(31 downto 0);
      servoArm       : slv(1 downto 0);
      phc            : BufferType;
      meas           : BufferType;
      servo          : BufferType;
      -- Serializer
      state          : StateType;
      word           : natural range 0 to MEAS_WORDS_C-1;
      master         : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      lastSeconds    => (others => '0'),
      lastGeneration => (others => '0'),
      lastTimeValid  => '0',
      lastPort       => '0',
      lastLink       => '0',
      lastFault      => '0',
      lastServoState => (others => '0'),
      started        => '0',
      recordSeq       => (others => '0'),
      dropped        => (others => '0'),
      servoArm       => (others => '0'),
      phc            => BUFFER_INIT_C,
      meas           => BUFFER_INIT_C,
      servo          => BUFFER_INIT_C,
      state          => IDLE_S,
      word           => 0,
      master         => AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   function headerWord (
      kind    : slv(7 downto 0);
      buf     : BufferType;
      drops   : slv(31 downto 0);
      index   : natural)
      return slv is
      variable w : slv(63 downto 0);
   begin
      w := (others => '0');
      case index is
         when 0 =>
            w(7 downto 0)   := PTP_TELEMETRY_VERSION_C;
            w(15 downto 8)  := kind;
            w(23 downto 16) := toSlv(TELEMETRY_ID_G, 8);
            w(31 downto 24) := buf.cause;
            w(63 downto 32) := buf.recordSeq;
         when 1 =>
            w(31 downto 0)  := drops;
            w(34 downto 32) := buf.sample.servoState;
            w(35)           := buf.sample.timeValid;
            w(36)           := buf.sample.portActive;
            w(37)           := buf.sample.linkReady;
            w(38)           := buf.sample.fault;
         when 2 =>
            w(47 downto 0) := buf.sample.phcTime.seconds;
         when 3 =>
            w(31 downto 0)  := buf.sample.phcTime.nanoseconds;
            w(63 downto 32) := buf.sample.phcTime.fraction;
         when 4 =>
            w := buf.sample.ticks;
         when 5 =>
            w := buf.sample.rate;
         when others =>
            w(31 downto 0) := buf.sample.generation;
      end case;
      return w;
   end function headerWord;

   function phcWord (buf : BufferType; drops : slv(31 downto 0); index : natural) return slv is
   begin
      if index < 7 then
         return headerWord(PTP_TELEMETRY_PHC_C, buf, drops, index);
      end if;
      return buf.sample.increment;
   end function phcWord;

   function measWord (buf : BufferType; drops : slv(31 downto 0); index : natural) return slv is
      variable w : slv(63 downto 0);
   begin
      w := (others => '0');
      case index is
         when 0 to 6 =>
            w := headerWord(PTP_TELEMETRY_MEASUREMENT_C, buf, drops, index);
         when 7 =>
            w(0)            := buf.measurement.isDelay;
            w(1)            := buf.measurement.ratioValid;
            w(31 downto 16) := buf.measurement.syncSequence;
            w(47 downto 32) := buf.measurement.delaySequence;
         when 8 =>
            w(31 downto 0) := buf.measurement.generation;
         when 9 =>
            w := buf.measurement.ticks;
         when 10 =>
            w := buf.measurement.forward(63 downto 0);
         when 11 =>
            w := buf.measurement.forward(127 downto 64);
         when 12 =>
            w := buf.measurement.delayValue(63 downto 0);
         when 13 =>
            w := buf.measurement.delayValue(127 downto 64);
         when 14 =>
            w := buf.measurement.ratio;
         when 15 =>
            w := buf.exchange.t1(63 downto 0);
         when 16 =>
            w(15 downto 0) := buf.exchange.t1(79 downto 64);
         when 17 =>
            w := buf.exchange.t2(63 downto 0);
         when 18 =>
            w(31 downto 0) := buf.exchange.t2(95 downto 64);
         when 19 =>
            w := buf.exchange.t3(63 downto 0);
         when 20 =>
            w(31 downto 0) := buf.exchange.t3(95 downto 64);
         when 21 =>
            w := buf.exchange.t4(63 downto 0);
         when 22 =>
            w(15 downto 0) := buf.exchange.t4(79 downto 64);
         when 23 =>
            w := buf.exchange.syncCorrection(63 downto 0);
         when 24 =>
            w := buf.exchange.syncCorrection(127 downto 64);
         when 25 =>
            w := buf.exchange.delayCorrection;
         when others =>
            w(15 downto 0)  := buf.exchange.syncSequence;
            w(31 downto 16) := buf.exchange.delaySequence;
            w(63 downto 32) := buf.exchange.generation;
      end case;
      return w;
   end function measWord;

   function servoWord (buf : BufferType; drops : slv(31 downto 0); index : natural) return slv is
      variable w : slv(63 downto 0);
   begin
      w := (others => '0');
      case index is
         when 0 to 6 =>
            w := headerWord(PTP_TELEMETRY_SERVO_C, buf, drops, index);
         when 7 =>
            w(2 downto 0)   := buf.command.kind;
            w(3)            := buf.command.value;
            w(63 downto 32) := buf.command.generation;
         when 8 =>
            w := buf.command.rate;
         when 9 =>
            w := buf.command.phaseSeconds;
         when 10 =>
            w := buf.command.phaseFraction;
         when 11 =>
            w(47 downto 0) := buf.command.setTime.seconds;
         when 12 =>
            w(31 downto 0)  := buf.command.setTime.nanoseconds;
            w(63 downto 32) := buf.command.setTime.fraction;
         when 13 =>
            w := buf.servo.offsetValue(63 downto 0);
         when 14 =>
            w := buf.servo.offsetValue(127 downto 64);
         when 15 =>
            w := buf.servo.filteredDelay(63 downto 0);
         when 16 =>
            w := buf.servo.filteredDelay(127 downto 64);
         when 17 =>
            w := buf.servo.ratePpb;
         when others =>
            w(2 downto 0)   := buf.servo.state;
            w(6 downto 4)   := buf.servo.filterCount;
            w(63 downto 32) := buf.servo.rejectedCount;
      end case;
      return w;
   end function servoWord;

begin

   assert TELEMETRY_ID_G <= 255 report "PtpTelemetry: TELEMETRY_ID_G must fit in eight bits" severity failure;

   comb : process (commandMaster, commandSlave, exchange, linkReady, measurementMaster, measurementSlave,
                   phcStatus, phcTime, portActive, r, rst, servoStatus, telemetrySlave) is
      variable v        : RegType;
      variable sample   : SampleType;
      variable phcCause : slv(7 downto 0);
      variable last     : boolean;
      variable data     : slv(63 downto 0);

      -- Take the next sequence number; count a drop when the buffer is busy.
      procedure claim (constant busy : in boolean; variable taken : out boolean) is
      begin
         v.recordSeq := slv(unsigned(v.recordSeq)+1);
         taken      := not busy;
         if busy and v.dropped /= x"FFFFFFFF" then
            v.dropped := slv(unsigned(v.dropped)+1);
         end if;
      end procedure claim;

      variable busy  : boolean;
      variable taken : boolean;
   begin
      -- Latch the current value
      v := r;

      -- PHC sample and header flags of this edge
      sample.phcTime    := phcTime;
      sample.ticks      := phcStatus.ticks;
      sample.rate       := phcStatus.rate;
      sample.increment  := phcStatus.increment;
      sample.generation := phcStatus.generation;
      sample.servoState := servoStatus.state;
      sample.timeValid  := phcStatus.timeValid;
      sample.portActive := portActive;
      sample.linkReady  := linkReady;
      sample.fault      := phcStatus.fault;

      -------------------------------------------------------------------------
      -- Serializer: one registered word per accepted transfer
      -------------------------------------------------------------------------
      if telemetrySlave.tReady = '1' then
         v.master.tValid := '0';
      end if;

      if v.master.tValid = '0' then
         if r.state = IDLE_S then
            -- Start the first waiting buffer
            if r.phc.pending = '1' then
               v.state := PHC_S;
            elsif r.meas.pending = '1' then
               v.state := MEAS_S;
            elsif r.servo.pending = '1' and r.servoArm = "00" then
               v.state := SERVO_S;
            end if;
            v.word := 0;
         end if;

         if v.state /= IDLE_S then
            case v.state is
               when PHC_S =>
                  data := phcWord(r.phc, r.dropped, v.word);
                  last := v.word = PHC_WORDS_C-1;
               when MEAS_S =>
                  data := measWord(r.meas, r.dropped, v.word);
                  last := v.word = MEAS_WORDS_C-1;
               when others =>
                  data := servoWord(r.servo, r.dropped, v.word);
                  last := v.word = SERVO_WORDS_C-1;
            end case;
            v.master                   := AXI_STREAM_MASTER_INIT_C;
            v.master.tValid            := '1';
            v.master.tData(63 downto 0) := data;
            v.master.tKeep(7 downto 0) := (others => '1');
            ssiSetUserSof(PTP_TELEMETRY_AXIS_CONFIG_C, v.master, toSl(v.word = 0));
            if last then
               -- The buffer frees once its last word is registered
               v.master.tLast := '1';
               case v.state is
                  when PHC_S  => v.phc.pending := '0';
                  when MEAS_S => v.meas.pending := '0';
                  when others => v.servo.pending := '0';
               end case;
               v.state := IDLE_S;
               v.word  := 0;
            else
               v.word := v.word+1;
            end if;
         end if;
      end if;

      -------------------------------------------------------------------------
      -- Triggers, in sequence order PHC, measurement, servo
      -------------------------------------------------------------------------
      -- PHC: seconds change and PHC/link events. The first edge after reset
      -- only seeds the previous values.
      phcCause := (others => '0');
      if r.started = '1' then
         phcCause(0) := toSl(phcTime.seconds /= r.lastSeconds);
         phcCause(1) := phcStatus.discontinuity;
         phcCause(2) := toSl(phcStatus.generation /= r.lastGeneration);
         phcCause(3) := toSl(phcStatus.timeValid /= r.lastTimeValid);
         phcCause(4) := toSl(portActive /= r.lastPort or linkReady /= r.lastLink);
         phcCause(5) := phcStatus.fault and not r.lastFault;
      end if;
      if phcCause /= x"00" then
         busy := r.phc.pending = '1';
         claim(busy, taken);
         if taken then
            v.phc.pending  := '1';
            v.phc.recordSeq := v.recordSeq;
            v.phc.cause    := phcCause;
            v.phc.sample   := sample;
         end if;
      end if;

      -- Measurement: each transfer into the servo
      if measurementMaster.valid = '1' and measurementSlave.ready = '1' and measurementMaster.abort = '0' then
         busy := r.meas.pending = '1';
         claim(busy, taken);
         if taken then
            v.meas.pending     := '1';
            v.meas.recordSeq    := v.recordSeq;
            v.meas.cause       := (0 => measurementMaster.data.isDelay, others => '0');
            v.meas.sample      := sample;
            v.meas.measurement := measurementMaster.data;
            v.meas.exchange    := exchange;
         end if;
      end if;

      -- Servo: an armed command completes its capture two edges later
      v.servoArm := '0' & r.servoArm(1);
      if r.servoArm = "01" then
         v.servo.sample := sample;
         v.servo.servo  := servoStatus;
      end if;
      if commandMaster.valid = '1' and commandSlave.ready = '1' then
         busy := r.servo.pending = '1';
         claim(busy, taken);
         if taken then
            v.servo.pending  := '1';
            v.servo.recordSeq := v.recordSeq;
            v.servo.cause    := (0 => '1', others => '0');
            v.servo.command  := commandMaster.data;
            v.servoArm       := "10";
         end if;
      end if;
      if r.started = '1' and servoStatus.state /= r.lastServoState then
         if r.servoArm /= "00" or v.servoArm /= "00" then
            -- Still capturing: the armed record reports the new state.
            v.servo.cause(1) := '1';
         else
            busy := r.servo.pending = '1';
            claim(busy, taken);
            if taken then
               v.servo.pending  := '1';
               v.servo.recordSeq := v.recordSeq;
               v.servo.cause    := (1 => '1', others => '0');
               v.servo.sample   := sample;
               v.servo.command  := NO_COMMAND_C;
               v.servo.servo    := servoStatus;
            end if;
         end if;
      end if;

      -- Previous-edge values
      v.started        := '1';
      v.lastSeconds    := phcTime.seconds;
      v.lastGeneration := phcStatus.generation;
      v.lastTimeValid  := phcStatus.timeValid;
      v.lastPort       := portActive;
      v.lastLink       := linkReady;
      v.lastFault      := phcStatus.fault;
      v.lastServoState := servoStatus.state;

      -- Outputs
      telemetryMaster <= r.master;
      dropped         <= r.dropped;

      -- Reset
      if (rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
