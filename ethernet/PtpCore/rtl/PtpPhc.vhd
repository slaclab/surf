-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Continuously advancing PTP hardware clock and atomic command
-- target.
--
-- Maintains 48-bit seconds, 32-bit nanoseconds and a 32-bit fractional
-- nanosecond accumulator. Each clock adds the nominal Q32
-- nanoseconds-per-cycle increment plus the signed rate adjustment, normalizing
-- seconds rollover. A separate 64-bit unsteered cycle counter provides
-- protocol timers and rate-estimation intervals independent of clock steering.
--
-- A single ready/valid command slot latches immutable operands and commits
-- them on the following edge. SET names commit-edge time, PHASE adjusts
-- normally advanced time, and RATE changes subsequent increments. Other
-- commands control time validity and PPS enable. Generation checks, command
-- cancellation and monotonic policy reject stale or prohibited operations with
-- an acknowledgement and error.
--
-- A time discontinuity advances the generation, clears validity and suppresses
-- captures and PPS on the affected edge. Epoch, tick or generation exhaustion
-- faults closed until system reset;
-- physical timestamp adapters consume the time, exact active increment, raw
-- ticks and capture-abort indication from this module.
--
-- Its local AXI-Lite bank owns monotonic-policy shadows, manual SET/PHASE/RATE
-- operands, command completion and coherent time/rate/tick snapshots. PHASE
-- uses a serialized PtpMath divide to normalize signed Q16 nanoseconds into
-- whole seconds and a signed Q32 remainder. Submission copies the operands,
-- so later register writes cannot alter a command already being prepared.
-- Manual preparation progresses through issue, math completion, target request
-- and acknowledgement states; ordinary commands skip the math states.
-- Manual and servo requests share the same command slot; ownership is retained
-- through acknowledgement, including rejection and independent cancellation.
-- A command's own capture-abort pulse does not revoke its PHC commit.
--
-- PtpEndpoint connects this bank directly to its AXI-Lite crossbar. Common
-- prepare/apply strobes freeze and activate monotonic policy, and a shared
-- snapshot strobe captures pre-edge state with the endpoint sequence. regRst
-- clears only AXI responses; accepted commands, policy and time survive it.
-- Monotonic policy always comes from the local active register. The
-- commandMaster/commandSlave records carry the servo payload and its admission,
-- cancellation and completion handshake. The returned error belongs to the
-- acknowledged servo command; manual completion remains in the local bank.
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

entity PtpPhc is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      CLK_FREQ_G     : positive := 156250000);
   port (
      clk           : in  sl;
      rst           : in  sl;
      -- Local AXI-Lite bank and endpoint coordination (clk domain).
      regRst           : in  sl                     := '0';
      axiReadMaster    : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axiReadSlave     : out AxiLiteReadSlaveType;
      axiWriteMaster   : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axiWriteSlave    : out AxiLiteWriteSlaveType;
      configControl    : in  PtpConfigControlType   := PTP_CONFIG_CONTROL_INIT_C;
      snapshotControl  : in  PtpSnapshotControlType := PTP_SNAPSHOT_CONTROL_INIT_C;
      configValid      : out sl;
      servoEnable      : in  sl                     := '0';
      restart          : in  sl                     := '0';
      portCommandAbort : in  sl                     := '0';
      manualBusy       : out sl;
      -- Protocol/clock interface.
      clearValid    : in  sl                      := '0';
      phcTime       : out PtpTimeType;
      status        : out PtpPhcStatusType;
      pps           : out sl;
      captureAbort  : out sl;
      commandMaster : in  PtpPhcCommandMasterType := PTP_PHC_COMMAND_MASTER_INIT_C;
      commandSlave  : out PtpPhcCommandSlaveType);
end entity PtpPhc;

architecture rtl of PtpPhc is

   type OwnerType is (
      NONE_S,
      MANUAL_S,
      AUTO_S);

   type ManualStateType is (
      IDLE_S,
      PHASE_ISSUE_S,
      PHASE_WAIT_S,
      REQUEST_S,
      WAIT_ACK_S);

   signal mathInputValid : sl;
   signal mathReady      : sl;
   signal mathValid      : sl;
   signal mathResult     : slv(127 downto 0);
   signal mathRemainder  : slv(127 downto 0);
   signal mathError      : sl;

   constant SECOND_Q16_C : slv(127 downto 0) := slv(shift_left(to_unsigned(PTP_NANOSECONDS_PER_SECOND_C, 128), PTP_TIME_FRAC_BITS_C));

   constant NOMINAL_C : unsigned(63 downto 0) := unsigned(ptpNominalIncrement(CLK_FREQ_G));
   constant SECOND_C  : signed(66 downto 0) := shift_left(to_signed(PTP_NANOSECONDS_PER_SECOND_C, 67), PTP_PHC_FRAC_BITS_C);

   -- Capture consumers need the nominal increment even before the first tick.
   function initialStatus return PtpPhcStatusType is
      variable retVar : PtpPhcStatusType := PTP_PHC_STATUS_INIT_C;
   begin
      retVar.increment := slv(NOMINAL_C);
      return retVar;
   end function;

   type RegType is record
      -- AXI responses, policy shadows and software command operands.
      readSlave          : AxiLiteReadSlaveType;
      writeSlave         : AxiLiteWriteSlaveType;
      shadowMonotonic    : sl;
      candidateMonotonic : sl;
      activeMonotonic    : sl;
      setTime            : PtpTimeType;
      phase              : slv(127 downto 0);
      rate               : slv(63 downto 0);

      -- Accepted manual work survives AXI reset and later operand writes.
      manualState        : ManualStateType;
      manualBusy         : sl;
      mathInputValid     : sl;
      manualCommand      : PtpPhcCommandType;
      phaseOperand       : slv(127 downto 0);
      manualAck          : sl;
      manualError        : sl;

      -- Local copies of the common pre-edge diagnostic snapshot.
      snapshotSequence   : slv(31 downto 0);
      snapshotTime       : PtpTimeType;
      snapshotStatus     : PtpPhcStatusType;

      -- Clock state and the shared one-command commit slot.
      timeValue          : PtpTimeType;
      status             : PtpPhcStatusType;
      owner              : OwnerType;
      abortSeen          : sl;
      command            : PtpPhcCommandType;
      pending            : sl;
      ppsEnable          : sl;
      pps                : sl;
   end record;

   constant REG_INIT_C : RegType := (
      readSlave          => AXI_LITE_READ_SLAVE_INIT_C,
      writeSlave         => AXI_LITE_WRITE_SLAVE_INIT_C,
      shadowMonotonic    => '1',
      candidateMonotonic => '1',
      activeMonotonic    => '1',
      setTime            => PTP_TIME_INIT_C,
      phase              => (others => '0'),
      rate               => (others => '0'),
      manualState        => IDLE_S,
      manualBusy         => '0',
      mathInputValid     => '0',
      manualCommand      => PTP_PHC_COMMAND_INIT_C,
      phaseOperand       => (others => '0'),
      manualAck          => '0',
      manualError        => '0',
      snapshotSequence   => (others => '0'),
      snapshotTime       => PTP_TIME_INIT_C,
      snapshotStatus     => PTP_PHC_STATUS_INIT_C,
      timeValue          => PTP_TIME_INIT_C,
      status             => initialStatus,
      owner              => NONE_S,
      abortSeen          => '0',
      command            => PTP_PHC_COMMAND_INIT_C,
      pending            => '0',
      ppsEnable          => '0',
      pps                => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

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
         inputValid      => mathInputValid,  -- [in]
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

   configValid <= '1';

   assert NOMINAL_C > 0 and NOMINAL_C < unsigned(SECOND_C)
      report "PHC nominal increment must be positive and below one second" severity failure;

   comb : process (r, rst, regRst, axiReadMaster, axiWriteMaster, configControl, snapshotControl,
                   servoEnable, restart, portCommandAbort, commandMaster, clearValid, mathReady,
                   mathValid, mathResult, mathRemainder, mathError) is
      variable v  : RegType;
      variable ep : AxiLiteEndpointType;

      -- AXI write payload and shared current-cycle admission qualification.
      variable commandWord     : slv(7 downto 0);
      variable slotReady       : sl;
      variable commandResponse : PtpPhcCommandSlaveType;
      variable captureAbortNow : sl;

      -- Preserve carry/sign bits until normalization and range checks finish.
      variable nextNanoseconds : signed(66 downto 0);
      variable nextSeconds     : signed(65 downto 0);
      variable tickIncrement   : signed(64 downto 0);
      variable nextIncrement   : signed(64 downto 0);
   begin
      v := r;

      -- Default one-cycle indications. Manual completion stays latched until
      -- the next accepted software command; target completion is a pulse.
      v.status.ack           := '0';
      v.status.error         := '0';
      v.status.discontinuity := '0';
      v.pps                  := '0';
      v.abortSeen            := portCommandAbort;
      commandWord            := (others => '0');
      commandResponse        := PTP_PHC_COMMAND_SLAVE_INIT_C;

      -------------------------------------------------------------------------
      -- AXI-Lite: decode, map, qualify submission, then close the transaction.
      -------------------------------------------------------------------------
      axiSlaveWaitTxn(ep, axiWriteMaster, axiReadMaster, v.writeSlave, v.readSlave);

      -- Suppress register accesses during AXI-only reset.
      if regRst = '1' then
         ep.axiStatus := AXI_LITE_STATUS_INIT_C;
      end if;

      axiSlaveRegister(ep, x"004", 3, v.shadowMonotonic);
      axiSlaveRegisterR(ep, x"008", 0, r.snapshotTime.seconds);
      axiSlaveRegisterR(ep, x"010", 0, r.snapshotTime.nanoseconds);
      axiSlaveRegisterR(ep, x"014", 0, r.snapshotTime.fraction);
      axiSlaveRegisterR(ep, x"018", 0, r.snapshotStatus.generation);
      axiSlaveRegisterR(ep, x"01C", 0, r.snapshotStatus.timeValid);
      axiSlaveRegister(ep, x"020", 0, commandWord);
      axiSlaveRegisterR(ep, x"024", 0, r.manualBusy);
      axiSlaveRegisterR(ep, x"024", 1, r.manualAck);
      axiSlaveRegisterR(ep, x"024", 2, r.manualError);
      axiSlaveRegister(ep, x"028", 0, v.setTime.seconds);
      axiSlaveRegister(ep, x"030", 0, v.setTime.nanoseconds);
      axiSlaveRegister(ep, x"034", 0, v.setTime.fraction);
      axiSlaveRegister(ep, x"038", 0, v.phase);
      axiSlaveRegister(ep, x"048", 0, v.rate);
      axiSlaveRegisterR(ep, x"050", 0, ptpNominalIncrement(CLK_FREQ_G));
      axiSlaveRegisterR(ep, x"058", 0, r.snapshotStatus.rate);
      axiSlaveRegisterR(ep, x"060", 0, r.snapshotStatus.ticks);
      axiSlaveRegisterR(ep, x"068", 0, r.status.fault);
      axiSlaveRegisterR(ep, x"080", 0, slv(to_unsigned(CLK_FREQ_G, 32)));
      axiSlaveRegisterR(ep, x"084", 3, r.activeMonotonic);
      axiSlaveRegisterR(ep, x"3FC", 0, r.snapshotSequence);

      if commandWord(7) = '1' then
         -- Admission uses pre-edge ownership even if an old command completes
         -- below. PPS control is the only manual command allowed with the servo.
         if r.manualState /= IDLE_S or configControl.busy = '1' then
            ep.axiWriteSlave.bresp := AXI_RESP_SLVERR_C;
         elsif servoEnable = '1' and commandWord(2 downto 0) /= PTP_CMD_PPS_C then
            ep.axiWriteSlave.bresp := AXI_RESP_SLVERR_C;
         elsif unsigned(commandWord(2 downto 0)) > unsigned(PTP_CMD_PPS_C) then
            ep.axiWriteSlave.bresp := AXI_RESP_SLVERR_C;
         else
            -- Freeze operands from r, not shadows changed by this evaluation.
            v.manualCommand            := PTP_PHC_COMMAND_INIT_C;
            v.manualCommand.kind       := commandWord(2 downto 0);
            v.manualCommand.value      := commandWord(3);
            v.manualCommand.generation := r.status.generation;
            v.manualCommand.setTime    := r.setTime;
            v.manualCommand.rate       := r.rate;
            v.manualAck                := '0';
            v.manualError              := '0';
            if commandWord(2 downto 0) = PTP_CMD_PHASE_C then
               v.phaseOperand := r.phase;
               v.manualState  := PHASE_ISSUE_S;
            else
               v.manualState := REQUEST_S;
            end if;
         end if;
      end if;

      axiSlaveDefault(ep, v.writeSlave, v.readSlave, AXI_RESP_DECERR_C);
      if regRst = '1' then
         v.readSlave  := AXI_LITE_READ_SLAVE_INIT_C;
         v.writeSlave := AXI_LITE_WRITE_SLAVE_INIT_C;
      end if;

      -------------------------------------------------------------------------
      -- Manual command preparation and completion.
      -------------------------------------------------------------------------
      -- Evaluate r.manualState so AXI submission cannot enter the next stage
      -- on this edge. Accepted work continues through a register-only reset.
      case r.manualState is
         when IDLE_S =>
            -- AXI submission above owns the transition out of idle.
            null;
         when PHASE_ISSUE_S =>
            if mathReady = '1' then
               v.manualState := PHASE_WAIT_S;
            end if;
         when PHASE_WAIT_S =>
            if mathValid = '1' then
               if mathError = '1' or resize(resize(signed(mathResult), 64), 128) /= signed(mathResult) then
                  v.manualState := IDLE_S;
                  v.manualAck   := '1';
                  v.manualError := '1';
               else
                  v.manualCommand.phaseSeconds  := mathResult(63 downto 0);
                  v.manualCommand.phaseFraction := slv(shift_left(resize(signed(mathRemainder), 64), PTP_TIME_TO_PHC_SHIFT_C));
                  v.manualState                 := REQUEST_S;
               end if;
            end if;
         when REQUEST_S =>
            -- The arbiter below owns admission to the PHC command slot.
            null;
         when WAIT_ACK_S =>
            if r.owner = MANUAL_S and r.status.ack = '1' then
               v.manualState := IDLE_S;
               v.manualAck   := '1';
               v.manualError := r.status.error;
            end if;
      end case;

      -------------------------------------------------------------------------
      -- Shared command slot: select a producer and retain it through ACK.
      -------------------------------------------------------------------------
      slotReady := not r.pending and not r.status.fault;
      if rst = RST_POLARITY_G then
         slotReady := '0';
      end if;

      -- Admission uses the old slot occupancy. Committing a pending command
      -- below cannot admit its replacement on the same edge.
      -- The response is an owner-qualified view of the shared registered
      -- completion, with combinational ready. Keep one authoritative result
      -- for automatic, manual and diagnostic consumers rather than copying it.
      case r.owner is
         when NONE_S =>
            if r.manualState = REQUEST_S then
               if slotReady = '1' then
                  v.command     := r.manualCommand;
                  v.pending     := '1';
                  v.owner       := MANUAL_S;
                  v.manualState := WAIT_ACK_S;
               end if;
            elsif commandMaster.valid = '1' and commandMaster.cancel = '0' and commandMaster.stale = '0' then
               commandResponse.ready := slotReady;
               if slotReady = '1' then
                  v.command := commandMaster.data;
                  v.pending := '1';
                  v.owner   := AUTO_S;
               end if;
            end if;
         when MANUAL_S =>
            if r.status.ack = '1' then
               v.owner := NONE_S;
            end if;
         when AUTO_S =>
            commandResponse.ack   := r.status.ack;
            commandResponse.error := r.status.error;
            if r.status.ack = '1' then
               v.owner := NONE_S;
            end if;
      end case;

      -------------------------------------------------------------------------
      -- Clock algorithm: ordinary tick, pending command, then final priority.
      -------------------------------------------------------------------------
      -- Advance once with the pre-edge rate. Keep widened signed intermediates
      -- until all command arithmetic and epoch bounds have been checked.
      tickIncrement      := signed('0' & slv(NOMINAL_C)) + resize(signed(r.status.rate), 65);
      nextNanoseconds    := signed(resize(unsigned(slv'(r.timeValue.nanoseconds & r.timeValue.fraction)), 67)) + resize(tickIncrement, 67);
      nextSeconds        := signed(resize(unsigned(r.timeValue.seconds), 66));
      v.status.increment := slv(tickIncrement(63 downto 0));
      v.status.ticks     := slv(unsigned(r.status.ticks) + 1);
      if nextNanoseconds >= SECOND_C then
         nextNanoseconds := nextNanoseconds - SECOND_C;
         nextSeconds     := nextSeconds + 1;
         v.pps           := r.ppsEnable and r.status.timeValid;
      end if;

      -- The admission-to-commit cycle allows registered servo cancellation
      -- to revoke a request accepted on the cancellation detection edge.
      -- Only an already pending command commits. SET replaces commit-edge
      -- time; PHASE adjusts the ordinary tick; RATE affects subsequent ticks.
      if r.pending = '1' then
         v.pending    := '0';
         v.status.ack := '1';
         if r.command.generation /= r.status.generation or r.status.fault = '1' then
            v.status.error := '1';
         elsif r.owner = AUTO_S and
            ((portCommandAbort and not r.abortSeen) or restart or commandMaster.cancel or commandMaster.stale or not servoEnable) = '1' then
            -- Registered servo cancellation can arrive after admission and
            -- still veto this commit. Only automatic commands are affected.
            -- A held port abort cancels once, allowing later holdover commands.
            -- The PHC's own capture abort does not cancel its pending command.
            v.status.error := '1';
         else
            case r.command.kind is
               when PTP_CMD_SET_C =>
                  if unsigned(r.command.setTime.nanoseconds) >= PTP_NANOSECONDS_PER_SECOND_C then
                     v.status.error := '1';
                  elsif r.activeMonotonic = '1' and r.status.timeValid = '1' then
                     v.status.error := '1';
                  else
                     nextSeconds            := signed(resize(unsigned(r.command.setTime.seconds), 66));
                     nextNanoseconds        := signed(resize(unsigned(slv'(r.command.setTime.nanoseconds & r.command.setTime.fraction)), 67));
                     v.status.discontinuity := '1';
                  end if;
               when PTP_CMD_PHASE_C =>
                  -- The producer supplies whole seconds and a signed remainder
                  -- strictly inside one second. Valid monotonic time cannot go back.
                  if abs(resize(signed(r.command.phaseFraction), 67)) >= SECOND_C then
                     v.status.error := '1';
                  elsif r.activeMonotonic = '1' and r.status.timeValid = '1' and
                     (signed(r.command.phaseSeconds) < 0 or
                      (signed(r.command.phaseSeconds) = 0 and signed(r.command.phaseFraction) < 0)) then
                     v.status.error := '1';
                  else
                     nextSeconds     := nextSeconds + resize(signed(r.command.phaseSeconds), 66);
                     nextNanoseconds := nextNanoseconds + resize(signed(r.command.phaseFraction), 67);
                     if nextNanoseconds < 0 then
                        nextNanoseconds := nextNanoseconds + SECOND_C;
                        nextSeconds     := nextSeconds - 1;
                     elsif nextNanoseconds >= SECOND_C then
                        nextNanoseconds := nextNanoseconds - SECOND_C;
                        nextSeconds     := nextSeconds + 1;
                     end if;
                     v.status.discontinuity := '1';
                  end if;
               when PTP_CMD_RATE_C =>
                  nextIncrement := signed('0' & slv(NOMINAL_C)) + resize(signed(r.command.rate), 65);
                  if nextIncrement <= 0 or nextIncrement >= SECOND_C then
                     v.status.error := '1';
                  else
                     v.status.rate      := r.command.rate;
                     v.status.increment := slv(nextIncrement(63 downto 0));
                  end if;
               when PTP_CMD_VALID_C =>
                  v.status.timeValid := r.command.value;
               when PTP_CMD_PPS_C =>
                  v.ppsEnable := r.command.value;
               when others =>
                  v.status.error := '1';
            end case;
         end if;
      end if;

      -- A successful SET/PHASE invalidates captures and advances provenance,
      -- even if its arithmetic subsequently trips the fatal epoch check.
      if v.status.discontinuity = '1' then
         if unsigned(r.status.generation) = x"FFFFFFFF" then
            v.status.fault := '1';
            v.status.error := '1';
         else
            v.status.generation := slv(unsigned(r.status.generation) + 1);
         end if;
      end if;

      -- Epoch/tick exhaustion cannot wrap into plausible time. A generation
      -- fault alone does not freeze raw ticks; retain the existing tick policy.
      if nextSeconds < 0 or shift_right(nextSeconds, 48) /= 0 or unsigned(r.status.ticks) = x"FFFFFFFFFFFFFFFF" then
         v.status.fault := '1';
         v.status.error := '1';
         v.status.ticks := r.status.ticks;
      end if;

      -- Fatal fault wins over a command, then discontinuity/external revocation
      -- wins over validity. PPS is qualified last, including PPS-disable at rollover.
      if v.status.fault = '1' then
         v.timeValue        := r.timeValue;
         v.status.timeValid := '0';
      else
         v.timeValue.seconds     := slv(nextSeconds(47 downto 0));
         v.timeValue.nanoseconds := slv(nextNanoseconds(63 downto 32));
         v.timeValue.fraction    := slv(nextNanoseconds(31 downto 0));
         if v.status.discontinuity = '1' or clearValid = '1' then
            v.status.timeValid := '0';
         end if;
      end if;
      if v.status.timeValid = '0' or v.ppsEnable = '0' then
         v.pps := '0';
      end if;

      -- Timing exception: captures must reject the epoch invalidated on this
      -- commit edge. Delaying this control alone would admit stale timestamps.
      captureAbortNow := v.status.fault;
      if v.status.discontinuity = '1' or rst = RST_POLARITY_G then
         captureAbortNow := '1';
      end if;

      -------------------------------------------------------------------------
      -- Coordinated policy/snapshot capture always samples pre-edge state.
      -------------------------------------------------------------------------
      if configControl.prepare = '1' then
         v.candidateMonotonic := r.shadowMonotonic;
      end if;
      if configControl.apply = '1' then
         v.activeMonotonic := r.candidateMonotonic;
      end if;
      if snapshotControl.capture = '1' then
         v.snapshotSequence := snapshotControl.sequenceId;
         v.snapshotTime     := r.timeValue;
         v.snapshotStatus   := r.status;
      end if;

      v.manualBusy := '0';
      if v.manualState /= IDLE_S then
         v.manualBusy := '1';
      end if;
      -- Register the issue request with its frozen operand. Resolved next
      -- state preserves the existing admission edge without another cycle.
      v.mathInputValid := '0';
      if v.manualState = PHASE_ISSUE_S then
         v.mathInputValid := '1';
      end if;

      -------------------------------------------------------------------------
      -- Outputs retain their registered/combinational timing across reset.
      -------------------------------------------------------------------------
      -- Publish resolved controls before synchronous reset replaces v.
      commandSlave   <= commandResponse;
      captureAbort   <= captureAbortNow;
      manualBusy     <= r.manualBusy;
      mathInputValid <= r.mathInputValid;
      axiReadSlave   <= r.readSlave;
      axiWriteSlave  <= r.writeSlave;
      phcTime        <= r.timeValue;
      status         <= r.status;
      pps            <= r.pps;

      if RST_ASYNC_G = false and rst = RST_POLARITY_G then
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
