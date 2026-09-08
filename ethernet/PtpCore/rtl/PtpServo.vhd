-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PTP acquisition, filtered delay estimation and PHC feedback
-- control.
--
-- Accepts separate forward and path-delay measurements from PtpPort. Up to
-- five populated delay samples form a median filter; local-minus-master offset
-- is forward time minus filtered delay and configured asymmetry. Generation,
-- sample chronology and raw-tick age checks reject stale measurements before
-- they can affect the clock.
--
-- During acquisition, an enabled large phase adjustment can establish the
-- epoch. Otherwise the qualified raw-clock rate estimate initializes frequency
-- control. A serialized PtpMath engine evaluates the fixed-point
-- proportional/integral loop, including elapsed-time integration, frequency
-- and phase-slew clamps, final-rate limiting and conditional integration at
-- saturation. Commands use the PHC ready/valid and acknowledgement lifecycle;
-- only acknowledged rate commands update the retained frequency estimate.
--
-- Lock/unlock thresholds and counters provide quality hysteresis. Loss of
-- fresh measurements enters holdover, removes phase slew and preserves the
-- last good frequency; expiry requests time-validity revocation. Cancellation
-- removes obsolete work, while a disabled servo drains measurements without
-- steering. PtpEndpoint supplies command arbitration, the actual PHC and
-- external restart policy.
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

entity PtpServo is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      CLK_FREQ_G     : positive := 156250000);
   port (
      clk              : in  sl;
      rst              : in  sl;
      restart          : in  sl := '0';
      cancel           : in  sl;
      config           : in  PtpConfigType;
      phcStatus        : in  PtpPhcStatusType;
      measurement      : in  PtpMeasurementType;
      measurementValid : in  sl;
      measurementReady : out sl;
      command          : out PtpPhcCommandType;
      commandValid     : out sl;
      commandReady     : in  sl;
      commandAck       : in  sl;
      commandError     : in  sl;
      staleCommand     : out sl;
      cancelCommand    : out sl;
      expireTime       : out sl;
      servoState       : out slv(2 downto 0);
      filteredDelay    : out slv(127 downto 0);
      offsetValue      : out slv(127 downto 0);
      ratePpb          : out slv(63 downto 0);
      filterCount      : out slv(2 downto 0);
      rejectedCount    : out slv(31 downto 0));
end entity PtpServo;

architecture rtl of PtpServo is

   constant NOMINAL_C    : unsigned(63 downto 0) := unsigned(ptpNominalIncrement(CLK_FREQ_G));
   constant SECOND_Q16_C : signed(127 downto 0) := shift_left(to_signed(1000000000, 128), 16);

   type StateType is (
      IDLE_S,
      ISSUE_S,
      WAIT_S,
      COMMAND_S,
      ACK_S);

   type DelayArray is array (0 to 4) of signed(63 downto 0);
   type RegType is record
      state         : StateType;
      operation     : natural range 0 to 10;
      a             : slv(127 downto 0);
      b             : slv(127 downto 0);
      divide        : sl;
      command       : PtpPhcCommandType;
      generation    : slv(31 downto 0);
      abortSeen     : sl;
      quality       : slv(2 downto 0);
      delays        : DelayArray;
      delayCount    : natural range 0 to 5;
      delayPtr      : natural range 0 to 4;
      delayTicks    : slv(63 downto 0);
      filtered      : signed(127 downto 0);
      offset        : signed(127 downto 0);
      sampleTicks   : slv(63 downto 0);
      lastTicks     : slv(63 downto 0);
      haveSample    : sl;
      tracking      : sl;
      holding       : sl;
      holdApplied   : sl;
      workFrequency : signed(127 downto 0);
      frequency     : signed(127 downto 0);
      slew          : signed(127 downto 0);
      finalRate     : signed(127 downto 0);
      bootstrap     : signed(127 downto 0);
      interval      : signed(127 downto 0);
      good          : unsigned(7 downto 0);
      bad           : unsigned(7 downto 0);
      rejected      : slv(31 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      state         => IDLE_S,
      operation     => 0,
      a             => (others => '0'),
      b             => (others => '0'),
      divide        => '0',
      command       => PTP_PHC_COMMAND_INIT_C,
      generation    => (others => '0'),
      abortSeen     => '0',
      quality       => "001",
      delays        => (others => (others => '0')),
      delayCount    => 0,
      delayPtr      => 0,
      delayTicks    => (others => '0'),
      filtered      => (others => '0'),
      offset        => (others => '0'),
      sampleTicks   => (others => '0'),
      lastTicks     => (others => '0'),
      haveSample    => '0',
      tracking      => '0',
      holding       => '0',
      holdApplied   => '0',
      frequency     => (others => '0'),
      workFrequency => (others => '0'),
      slew          => (others => '0'),
      finalRate     => (others => '0'),
      bootstrap     => (others => '0'),
      interval      => (others => '0'),
      good          => (others => '0'),
      bad           => (others => '0'),
      rejected      => (others => '0'));

   signal r             : RegType := REG_INIT_C;
   signal rin           : RegType;
   signal staleWork     : sl;
   signal invalidate    : sl;
   signal inputMath     : sl;
   signal readyMath     : sl;
   signal validMath     : sl;
   signal valueMath     : slv(127 downto 0);
   signal remainderMath : slv(127 downto 0);
   signal errorMath     : sl;
   signal roundMath     : sl;

   function clamp (value : signed(127 downto 0);
   maximum : slv(31 downto 0)) return signed is
      variable limitValue : signed(127 downto 0);
   begin
      limitValue := shift_left(signed(resize(unsigned(maximum), 128)), 16);
      if value > limitValue then
         return limitValue;
      elsif value < -limitValue then
         return -limitValue;
      end if;
      return value;
   end function;

begin

   -- A level-held link/port abort starts one cancellation transaction. Holdover
   -- can subsequently issue its frequency-only command while the link is down.
   -- A new PHC generation independently cancels even a sustained abort session.
   staleWork  <= '1' when r.state /= IDLE_S and r.holding = '0' and
      unsigned(phcStatus.ticks)-unsigned(r.sampleTicks) > unsigned(config.associationTimeout) else '0';
   invalidate <= '1' when staleWork = '1' or restart = '1' or (cancel = '1' and r.abortSeen = '0') or
      phcStatus.generation /= r.generation or config.servoEnable = '0' else '0';
   inputMath  <= '1' when r.state = ISSUE_S else '0';
   roundMath  <= '0' when r.operation = 10 else '1';

   U_Math : entity surf.PtpMath
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk             => clk,            -- [in]
         rst             => rst,            -- [in]
         cancel          => invalidate,     -- [in]
         inputValid      => inputMath,      -- [in]
         inputReady      => readyMath,      -- [out]
         divide          => r.divide,       -- [in]
         roundNearest    => roundMath,      -- [in]
         operandA        => r.a,            -- [in]
         operandB        => r.b,            -- [in]
         resultValid     => validMath,      -- [out]
         resultReady     => '1',            -- [in]
         resultValue     => valueMath,      -- [out]
         resultRemainder => remainderMath,  -- [out]
         resultError     => errorMath);     -- [out]

   comb : process (r, rst, cancel, config, phcStatus, measurement, measurementValid,
                   commandReady, commandAck, commandError, invalidate, readyMath, validMath, valueMath, remainderMath, errorMath) is
      variable v            : RegType;
      variable sorted       : DelayArray;
      variable temp         : signed(63 downto 0);
      variable delta        : signed(127 downto 0);
      variable candidate    : signed(127 downto 0);
      variable limited      : signed(127 downto 0);
      variable stale        : boolean;
      variable acceptSample : boolean;
   begin
      v := r;

      v.abortSeen  := cancel;
      v.generation := phcStatus.generation;
      stale        := r.haveSample = '1' and (cancel = '1' or r.delayCount = 0 or
         unsigned(phcStatus.ticks)-unsigned(r.delayTicks) > unsigned(config.maxDelayAge) or
         unsigned(phcStatus.ticks)-unsigned(r.lastTicks) > unsigned(config.syncTimeout));
      acceptSample := false;
      if stale then
         v.quality  := "100";
         v.tracking := '0';
         v.good     := (others => '0');
      end if;
      case r.state is
         when IDLE_S =>
            if stale and r.holdApplied = '0' then
               -- Holdover removes the phase slew but preserves the last good
               -- frequency estimate. Conversion uses the same checked path as
               -- tracking; no combinational wide divider enters the clock loop.
               v.finalRate := clamp(r.frequency, config.maxRatePpb);
               v.a         := slv(v.finalRate);
               v.b         := slv(resize(NOMINAL_C, 128));
               v.divide    := '0';
               v.operation := 7;
               v.holding   := '1';
               v.state     := ISSUE_S;
            elsif measurementValid = '1' and cancel = '0' and config.servoEnable = '1' then
               if measurement.generation /= phcStatus.generation or
                  unsigned(measurement.ticks) > unsigned(phcStatus.ticks) or
                  unsigned(phcStatus.ticks)-unsigned(measurement.ticks) > unsigned(config.associationTimeout) then
                  v.rejected := ptpSatInc(v.rejected);
               elsif measurement.isDelay = '1' then
                  if signed(measurement.delayValue) >= 0 and signed(measurement.delayValue) <= signed(config.maxPathDelay) and
                     (r.delayCount = 0 or unsigned(measurement.ticks) > unsigned(r.delayTicks)) then
                     v.delays(r.delayPtr) := signed(measurement.delayValue(63 downto 0));
                     v.delayPtr           := (r.delayPtr+1) mod 5;
                     if r.delayCount < 5 then
                        v.delayCount := r.delayCount+1;
                     end if;
                     sorted := v.delays;
                     -- Sort only populated entries. Zero-filled startup history
                     -- is never mistaken for five accepted zero-delay samples.
                     for i in 0 to 4 loop
                        for j in 0 to 3 loop
                           if j+1 < v.delayCount and sorted(j) > sorted(j+1) then
                              temp        := sorted(j);
                              sorted(j)   := sorted(j+1);
                              sorted(j+1) := temp;
                           end if;
                        end loop;
                     end loop;
                     v.filtered   := resize(sorted((v.delayCount-1)/2), 128);
                     v.delayTicks := measurement.ticks;
                  else
                     v.rejected := ptpSatInc(v.rejected);
                  end if;
               elsif r.delayCount /= 0 and measurement.ratioValid = '1' and
                  unsigned(phcStatus.ticks)-unsigned(r.delayTicks) <= unsigned(config.maxDelayAge) and
                  (r.haveSample = '0' or unsigned(measurement.ticks) > unsigned(r.lastTicks)) then
                  delta := signed(resize(unsigned(measurement.ticks), 128))-signed(resize(unsigned(r.lastTicks), 128));
                  if r.tracking = '1' and (delta < signed(resize(unsigned(config.minSampleTicks), 128)) or
                     delta > signed(resize(unsigned(config.maxSampleTicks), 128))) then
                     v.rejected := ptpSatInc(v.rejected);
                  else
                     v.offset             := signed(measurement.forward)-r.filtered-resize(signed(config.delayAsymmetry), 128);
                     v.sampleTicks        := measurement.ticks;
                     v.holding            := '0';
                     v.command            := PTP_PHC_COMMAND_INIT_C;
                     v.command.generation := phcStatus.generation;
                     if phcStatus.timeValid = '0' and config.allowStep = '1' and abs(v.offset) > signed(config.stepThreshold) then
                        -- Normalize the full acquisition epoch delta outside the
                        -- PHC. Quotient/remainder are transported atomically and
                        -- applied to the normally advanced commit-edge time.
                        v.a         := slv(-v.offset);
                        v.b         := slv(SECOND_Q16_C);
                        v.divide    := '1';
                        v.operation := 10;
                        v.state     := ISSUE_S;
                     elsif resize(resize(v.offset, 64), 128) /= v.offset then
                        v.rejected := ptpSatInc(v.rejected);
                     else
                        v.a         := slv(signed(resize(unsigned(measurement.ratio), 128))-
                                   signed(shift_left(resize(NOMINAL_C, 128), 16)));
                        v.b         := slv(to_signed(1000000000, 128));
                        v.divide    := '0';
                        v.operation := 0;
                        v.state     := ISSUE_S;
                     end if;
                  end if;
               end if;
            end if;
         when ISSUE_S =>
            if readyMath = '1' then
               v.state := WAIT_S;
            end if;
         when WAIT_S =>
            if validMath = '1' then
               v.state := ISSUE_S;
               if errorMath = '1' then
                  v.state    := IDLE_S;
                  v.rejected := ptpSatInc(v.rejected);
               else
                  case r.operation is
                     when 0 =>
                        v.a         := valueMath;
                        v.b         := slv(resize(NOMINAL_C, 128));
                        v.divide    := '1';
                        v.operation := 1;
                     when 1 =>
                        -- Ratio Q48 vs nominal Q32 leaves Q16 ppb after the
                        -- 1e9 conversion. Bootstrap is independent of PHC rate.
                        v.bootstrap := clamp(signed(valueMath), config.maxFrequencyPpb);
                        v.a         := slv(r.offset);
                        v.b         := slv(resize(unsigned(config.kp), 128));
                        v.divide    := '0';
                        v.operation := 2;
                     when 2 =>
                        v.slew := clamp(-ptpRoundShift(signed(valueMath), 30), config.maxSlewPpb);
                        if r.tracking = '0' then
                           -- First apply qualified oscillator feedforward. Seed
                           -- the integrator minus the new proportional term, so
                           -- entry to tracking preserves this applied command.
                           v.workFrequency := clamp(r.bootstrap-v.slew, config.maxFrequencyPpb);
                           v.finalRate     := clamp(v.workFrequency+v.slew, config.maxRatePpb);
                           v.a             := slv(v.finalRate);
                           v.b             := slv(resize(NOMINAL_C, 128));
                           v.operation     := 7;
                        else
                           v.a         := slv(resize(unsigned(r.sampleTicks)-unsigned(r.lastTicks), 128));
                           v.b         := slv(resize(NOMINAL_C, 128));
                           v.operation := 3;
                        end if;
                     when 3 =>
                        v.a         := valueMath;
                        v.b         := slv(to_signed(1000000000, 128));
                        v.divide    := '1';
                        v.operation := 4;
                     when 4 =>
                        v.interval  := signed(valueMath); -- seconds Q32
                        v.a         := slv(r.offset);
                        v.b         := slv(resize(unsigned(config.ki), 128));
                        v.divide    := '0';
                        v.operation := 5;
                     when 5 =>
                        v.a         := valueMath; -- Q16 offset * Q30 gain
                        v.b         := slv(r.interval); -- seconds Q32
                        v.operation := 6;
                     when 6 =>
                        delta     := -ptpRoundShift(signed(valueMath), 62); -- ppb Q16
                        candidate := r.frequency+delta;
                        limited   := clamp(candidate, config.maxFrequencyPpb);
                        -- Conditional integration freezes only outward movement
                        -- at either frequency or final-rate saturation. Movement
                        -- back toward the linear region remains possible.
                        if (candidate /= limited and ((candidate > 0 and delta > 0) or (candidate < 0 and delta < 0))) or
                           (clamp(limited+r.slew, config.maxRatePpb) /= limited+r.slew and
                            ((limited+r.slew > 0 and delta > 0) or (limited+r.slew < 0 and delta < 0))) then
                           limited := r.frequency;
                        end if;
                        v.workFrequency := limited;
                        v.finalRate     := clamp(limited+r.slew, config.maxRatePpb);
                        v.a             := slv(v.finalRate);
                        v.b             := slv(resize(NOMINAL_C, 128));
                        v.divide        := '0';
                        v.operation     := 7;
                     when 7 =>
                        v.a         := valueMath;
                        v.b         := slv(SECOND_Q16_C); -- 1e9 * 2^16
                        v.divide    := '1';
                        v.operation := 8;
                     when 8 =>
                        if resize(resize(signed(valueMath), 64), 128) /= signed(valueMath) then
                           v.quality := "101";
                           v.state   := IDLE_S;
                        else
                           v.command            := PTP_PHC_COMMAND_INIT_C;
                           v.command.kind       := PTP_CMD_RATE_C;
                           v.command.generation := phcStatus.generation;
                           v.command.rate       := valueMath(63 downto 0);
                           v.state              := COMMAND_S;
                        end if;
                     when 10 =>
                        if resize(resize(signed(valueMath), 64), 128) /= signed(valueMath) then
                           v.quality := "101";
                           v.state   := IDLE_S;
                        else
                           v.command.kind          := PTP_CMD_PHASE_C;
                           v.command.phaseSeconds  := valueMath(63 downto 0);
                           v.command.phaseFraction := slv(shift_left(resize(signed(remainderMath), 64), 16));
                           v.state                 := COMMAND_S;
                        end if;
                     when others =>
                        v.quality := "101";
                        v.state   := IDLE_S;
                  end case;
               end if;
            end if;
         when COMMAND_S =>
            if commandReady = '1' then
               v.state := ACK_S;
            end if;
         when ACK_S =>
            if commandAck = '1' then
               v.state := IDLE_S;
               if commandError = '1' then
                  v.quality := "101";
               elsif r.command.kind = PTP_CMD_RATE_C then
                  if r.holding = '1' then
                     v.holdApplied := '1';
                  else
                     acceptSample  := true;
                     v.frequency   := r.workFrequency;
                     v.tracking    := '1';
                     v.holdApplied := '0';
                     if phcStatus.timeValid = '0' then
                        v.command.kind  := PTP_CMD_VALID_C;
                        v.command.value := '1';
                        v.state         := COMMAND_S;
                     end if;
                  end if;
               end if;
            end if;
      end case;
      if acceptSample then
         v.lastTicks  := r.sampleTicks;
         v.haveSample := '1';
         v.quality    := "010";
         if abs(r.offset) <= signed(config.lockThreshold) then
            if r.good /= x"FF" then
               v.good := r.good+1;
            end if;
            v.bad := (others => '0');
         elsif abs(r.offset) >= signed(config.unlockThreshold) then
            v.good := (others => '0');
            if r.bad /= x"FF" then
               v.bad := r.bad+1;
            end if;
         end if;
         if v.good >= unsigned(config.lockCount) or (r.quality = "011" and v.bad < unsigned(config.unlockCount)) then
            v.quality := "011";
         end if;
      end if;
      if invalidate = '1' then
         v.state       := IDLE_S;
         v.delayCount  := 0;
         v.delayPtr    := 0;
         v.tracking    := '0';
         v.holdApplied := '0';
         v.good        := (others => '0');
         v.bad         := (others => '0');
         v.quality     := "001";
         if r.haveSample = '1' then
            v.quality := "100";
         end if;
      end if;
      if config.servoEnable = '0' then
         v.quality    := "000";
         v.haveSample := '0';
      end if;
      if phcStatus.fault = '1' or r.quality = "101" then
         v.quality := "101";
         v.state   := IDLE_S;
      end if;
      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;
      rin              <= v;
      measurementReady <= '0';
      -- A disabled servo still drains measurements. Manual clock ownership must
      -- not stall the port's association queue or prevent protocol diagnostics.
      if config.servoEnable = '0' and rst /= RST_POLARITY_G then
         measurementReady <= '1';
      elsif r.state = IDLE_S and not (stale and r.holdApplied = '0') and invalidate = '0' and r.quality /= "101" and rst /= RST_POLARITY_G then
         measurementReady <= '1';
      end if;
      commandValid <= '0';
      if r.state = COMMAND_S and invalidate = '0' and r.quality /= "101" and rst /= RST_POLARITY_G then
         commandValid <= '1';
      end if;
      command       <= r.command;
      cancelCommand <= invalidate;
      staleCommand  <= staleWork;
      expireTime    <= '0';
      if r.quality = "101" or (config.servoEnable = '1' and r.haveSample = '1' and
         unsigned(phcStatus.ticks)-unsigned(r.lastTicks) > unsigned(config.holdoverTimeout)) then
         expireTime <= '1';
      end if;
      servoState    <= r.quality;
      filteredDelay <= slv(r.filtered);
      offsetValue   <= slv(r.offset);
      ratePpb       <= slv(r.finalRate(63 downto 0));
      filterCount   <= slv(to_unsigned(r.delayCount, 3));
      rejectedCount <= r.rejected;
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
