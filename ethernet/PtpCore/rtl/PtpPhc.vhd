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

   signal mathReady     : sl;
   signal mathValid     : sl;
   signal mathResult    : slv(127 downto 0);
   signal mathRemainder : slv(127 downto 0);
   signal mathError     : sl;

   constant SECOND_Q16_C : slv(127 downto 0) := slv(shift_left(to_unsigned(1000000000, 128), 16));

   constant NOMINAL_C : unsigned(63 downto 0) := unsigned(ptpNominalIncrement(CLK_FREQ_G));
   constant SECOND_C  : signed(66 downto 0) := shift_left(to_signed(1000000000, 67), 32);

   type RegType is record
      -- Current-cycle calculations and diagnostics. Use v for same-edge
      -- decisions; these fields do not introduce a protocol pipeline stage.
      commandWord        : slv(7 downto 0);
      manualReady        : sl;
      manualAck          : sl;
      targetCommand      : PtpPhcCommandType;
      targetValid        : sl;
      targetReady        : sl;
      targetCancel       : sl;
      nextNanoseconds    : signed(66 downto 0);
      nextSeconds        : signed(65 downto 0);
      tickIncrement      : signed(64 downto 0);
      nextIncrement      : signed(64 downto 0);
      rejectCommand      : boolean;
      jump               : boolean;
      abortNow           : sl;

      -- Local management state shares the core reset and register process.
      readSlave          : AxiLiteReadSlaveType;
      writeSlave         : AxiLiteWriteSlaveType;
      shadowMonotonic    : sl;
      candidateMonotonic : sl;
      activeMonotonic    : sl;
      owner              : OwnerType;
      abortSeen          : sl;
      manualCommand      : PtpPhcCommandType;
      manualValid        : sl;
      busy               : sl;
      ack                : sl;
      error              : sl;
      setTime            : PtpTimeType;
      phaseOperand       : slv(127 downto 0);
      phase              : slv(127 downto 0);
      rate               : slv(63 downto 0);
      phaseIssue         : sl;
      phaseWait          : sl;
      snapshotSequence   : slv(31 downto 0);
      snapshotTime       : PtpTimeType;
      snapshotStatus     : PtpPhcStatusType;
      timeValue          : PtpTimeType;
      status             : PtpPhcStatusType;
      command            : PtpPhcCommandType;
      pending            : sl;
      ppsEnable          : sl;
      pps                : sl;
   end record;

   constant REG_INIT_C : RegType := (
      commandWord        => (others => '0'),
      manualReady        => '0',
      manualAck          => '0',
      targetCommand      => PTP_PHC_COMMAND_INIT_C,
      targetValid        => '0',
      targetReady        => '0',
      targetCancel       => '0',
      nextNanoseconds    => (others => '0'),
      nextSeconds        => (others => '0'),
      tickIncrement      => (others => '0'),
      nextIncrement      => (others => '0'),
      rejectCommand      => false,
      jump               => false,
      abortNow           => '0',
      readSlave          => AXI_LITE_READ_SLAVE_INIT_C,
      writeSlave         => AXI_LITE_WRITE_SLAVE_INIT_C,
      shadowMonotonic    => '1',
      candidateMonotonic => '1',
      activeMonotonic    => '1',
      owner              => NONE_S,
      abortSeen          => '0',
      manualCommand      => PTP_PHC_COMMAND_INIT_C,
      manualValid        => '0',
      busy               => '0',
      ack                => '0',
      error              => '0',
      setTime            => PTP_TIME_INIT_C,
      phaseOperand       => (others => '0'),
      phase              => (others => '0'),
      rate               => (others => '0'),
      phaseIssue         => '0',
      phaseWait          => '0',
      snapshotSequence   => (others => '0'),
      snapshotTime       => PTP_TIME_INIT_C,
      snapshotStatus     => PTP_PHC_STATUS_INIT_C,
      timeValue          => PTP_TIME_INIT_C,
      status             => PTP_PHC_STATUS_INIT_C,
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

   manualBusy  <= r.busy;
   configValid <= '1';

   assert NOMINAL_C > 0 and NOMINAL_C < unsigned(SECOND_C)
      report "PHC nominal increment must be positive and below one second" severity failure;

   comb : process (r, rst, regRst, axiReadMaster, axiWriteMaster, configControl, snapshotControl,
                   servoEnable, restart, portCommandAbort, commandMaster, clearValid, mathReady,
                   mathValid, mathResult, mathRemainder, mathError) is
      variable v  : RegType;
      variable ep : AxiLiteEndpointType;
   begin
      v := r;

      -- Resolve ownership before evaluating the numerical command slot.
      v.targetReady := not r.pending and not r.status.fault;
      if rst = RST_POLARITY_G then
         v.targetReady := '0';
      end if;

      v.commandWord      := (others => '0');
      v.manualReady      := '0';
      v.manualAck        := '0';
      v.abortSeen        := portCommandAbort;
      v.targetCommand    := PTP_PHC_COMMAND_INIT_C;
      v.targetValid      := '0';
      v.targetCancel     := '0';
      commandSlave.ready <= '0';
      commandSlave.ack   <= '0';
      commandSlave.error <= '0';
      -- Ownership lasts until the PHC acknowledgement, including cancellation
      -- acknowledgements. Producer backpressure cannot redirect that response.
      case r.owner is
         when NONE_S =>
            if r.manualValid = '1' then
               v.targetCommand := r.manualCommand;
               v.targetValid   := r.manualValid;
               v.manualReady   := v.targetReady;
               if v.targetReady = '1' then
                  v.owner := MANUAL_S;
               end if;
            elsif commandMaster.valid = '1' and commandMaster.cancel = '0' then
               v.targetCommand    := commandMaster.data;
               v.targetValid      := commandMaster.valid;
               commandSlave.ready <= v.targetReady;
               if v.targetReady = '1' then
                  v.owner := AUTO_S;
               end if;
            end if;
         when MANUAL_S =>
            v.manualAck := r.status.ack;
            if r.status.ack = '1' then
               v.owner := NONE_S;
            end if;
         when AUTO_S =>
            v.targetCancel     := (portCommandAbort and not r.abortSeen) or restart or commandMaster.stale or not servoEnable;
            commandSlave.ack   <= r.status.ack;
            commandSlave.error <= r.status.error;
            if r.status.ack = '1' then
               v.owner := NONE_S;
            end if;
      end case;
      axiReadSlave  <= r.readSlave;
      axiWriteSlave <= r.writeSlave;

      -- Advance time and raw ticks once using the currently applied rate.
      v.status.ack           := '0';
      v.status.error         := '0';
      v.status.discontinuity := '0';
      v.pps                  := '0';
      v.abortNow             := r.status.fault;
      v.tickIncrement        := signed('0' & slv(NOMINAL_C)) + resize(signed(r.status.rate), 65);
      v.status.increment     := slv(v.tickIncrement(63 downto 0));
      v.status.ticks         := slv(unsigned(r.status.ticks) + 1);
      v.nextNanoseconds      := signed(resize(unsigned(slv'(r.timeValue.nanoseconds & r.timeValue.fraction)), 67)) + resize(v.tickIncrement, 67);
      v.nextSeconds          := signed(resize(unsigned(r.timeValue.seconds), 66));
      if v.nextNanoseconds >= SECOND_C then
         v.nextNanoseconds := v.nextNanoseconds - SECOND_C;
         v.nextSeconds     := v.nextSeconds + 1;
         v.pps             := r.ppsEnable and r.status.timeValid;
      end if;

      -- The registered command commits against normally advanced time. A rate
      -- replacement affects the next tick; absolute set names this commit edge.
      v.rejectCommand := false;
      v.jump          := false;
      if r.pending = '1' then
         v.pending    := '0';
         v.status.ack := '1';
         if v.targetCancel = '1' or r.command.generation /= r.status.generation or r.status.fault = '1' then
            v.rejectCommand := true;
         else
            case r.command.kind is
               when PTP_CMD_SET_C =>
                  if unsigned(r.command.setTime.nanoseconds) >= 1000000000 or
                     (r.activeMonotonic = '1' and r.status.timeValid = '1') then
                     v.rejectCommand := true;
                  else
                     v.nextSeconds     := signed(resize(unsigned(r.command.setTime.seconds), 66));
                     v.nextNanoseconds := signed(resize(unsigned(slv'(r.command.setTime.nanoseconds & r.command.setTime.fraction)), 67));
                     v.jump            := true;
                  end if;
               when PTP_CMD_PHASE_C =>
                  if abs(resize(signed(r.command.phaseFraction), 67)) >= SECOND_C or
                     (r.activeMonotonic = '1' and r.status.timeValid = '1' and
                      (signed(r.command.phaseSeconds) < 0 or
                       (signed(r.command.phaseSeconds) = 0 and signed(r.command.phaseFraction) < 0))) then
                     v.rejectCommand := true;
                  else
                     v.nextSeconds     := v.nextSeconds + resize(signed(r.command.phaseSeconds), 66);
                     v.nextNanoseconds := v.nextNanoseconds + resize(signed(r.command.phaseFraction), 67);
                     if v.nextNanoseconds < 0 then
                        v.nextNanoseconds := v.nextNanoseconds + SECOND_C;
                        v.nextSeconds     := v.nextSeconds - 1;
                     elsif v.nextNanoseconds >= SECOND_C then
                        v.nextNanoseconds := v.nextNanoseconds - SECOND_C;
                        v.nextSeconds     := v.nextSeconds + 1;
                     end if;
                     v.jump := true;
                  end if;
               when PTP_CMD_RATE_C =>
                  v.nextIncrement := signed('0' & slv(NOMINAL_C)) + resize(signed(r.command.rate), 65);
                  if v.nextIncrement <= 0 or v.nextIncrement >= SECOND_C then
                     v.rejectCommand := true;
                  else
                     v.status.rate      := r.command.rate;
                     v.status.increment := slv(v.nextIncrement(63 downto 0));
                  end if;
               when PTP_CMD_VALID_C =>
                  v.status.timeValid := r.command.value;
               when PTP_CMD_PPS_C =>
                  v.ppsEnable := r.command.value;
               when others =>
 v.rejectCommand := true;
            end case;
         end if;
         if v.rejectCommand then
            v.status.error := '1';
         end if;
      end if;
      if v.jump then
         v.abortNow             := '1';
         v.pps                  := '0';
         v.status.timeValid     := '0';
         v.status.discontinuity := '1';
         if unsigned(r.status.generation) = x"FFFFFFFF" then
            v.status.fault := '1';
            v.status.error := '1';
         else
            v.status.generation := slv(unsigned(r.status.generation) + 1);
         end if;
      end if;
      -- A malformed epoch cannot wrap into a plausible timestamp. Keep the last
      -- representable time on fatal overflow and prohibit further commands.
      if v.nextSeconds < 0 or shift_right(v.nextSeconds, 48) /= 0 or unsigned(r.status.ticks) = x"FFFFFFFFFFFFFFFF" then
         v.status.fault := '1';
         v.status.error := '1';
         v.status.ticks := r.status.ticks;
      end if;
      if v.status.fault = '1' then
         v.timeValue        := r.timeValue;
         v.status.timeValid := '0';
         v.pps              := '0';
         v.abortNow         := '1';
      else
         v.timeValue.seconds     := slv(v.nextSeconds(47 downto 0));
         v.timeValue.nanoseconds := slv(v.nextNanoseconds(63 downto 32));
         v.timeValue.fraction    := slv(v.nextNanoseconds(31 downto 0));
      end if;
      if clearValid = '1' then
         v.status.timeValid := '0';
      end if;
      -- Revocation wins over a natural rollover on this edge. Never publish a
      -- PPS alongside invalid time or after a committing PPS-disable command.
      if v.status.timeValid = '0' or v.ppsEnable = '0' then
         v.pps := '0';
      end if;
      -- No fallthrough: the input is accepted only while the command slot was
      -- empty before this edge. Producers hold the complete record until ready.
      if r.pending = '0' and r.status.fault = '0' and v.targetCancel = '0' and v.targetValid = '1' then
         v.command := v.targetCommand;
         v.pending := '1';
      end if;
      -- Service the local bank after the numerical clock path. Preparation and
      -- snapshots use pre-edge operands, independently of the commit above.
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
         axiSlaveRegisterR(ep, toSlv(16#084#, 10), 3, r.activeMonotonic);
         axiSlaveRegister(ep, toSlv(16#004#, 10), 3, v.shadowMonotonic);
         axiSlaveRegisterR(ep, toSlv(16#008#, 10), 0, r.snapshotTime.seconds);
         axiSlaveRegisterR(ep, toSlv(16#010#, 10), 0, r.snapshotTime.nanoseconds);
         axiSlaveRegisterR(ep, toSlv(16#014#, 10), 0, r.snapshotTime.fraction);
         axiSlaveRegisterR(ep, toSlv(16#018#, 10), 0, r.snapshotStatus.generation);
         axiSlaveRegisterR(ep, toSlv(16#01C#, 10), 0, r.snapshotStatus.timeValid);
         axiSlaveRegister(ep, toSlv(16#020#, 10), 0, v.commandWord);
         axiSlaveRegisterR(ep, toSlv(16#024#, 10), 0, r.busy);
         axiSlaveRegisterR(ep, toSlv(16#024#, 10), 1, r.ack);
         axiSlaveRegisterR(ep, toSlv(16#024#, 10), 2, r.error);
         axiSlaveRegister(ep, toSlv(16#028#, 10), 0, v.setTime.seconds);
         axiSlaveRegister(ep, toSlv(16#030#, 10), 0, v.setTime.nanoseconds);
         axiSlaveRegister(ep, toSlv(16#034#, 10), 0, v.setTime.fraction);
         axiSlaveRegister(ep, toSlv(16#038#, 10), 0, v.phase);
         axiSlaveRegister(ep, toSlv(16#048#, 10), 0, v.rate);
         axiSlaveRegisterR(ep, toSlv(16#050#, 10), 0, ptpNominalIncrement(CLK_FREQ_G));
         axiSlaveRegisterR(ep, toSlv(16#058#, 10), 0, r.snapshotStatus.rate);
         axiSlaveRegisterR(ep, toSlv(16#060#, 10), 0, r.snapshotStatus.ticks);
         axiSlaveRegisterR(ep, toSlv(16#068#, 10), 0, r.status.fault);
         axiSlaveRegisterR(ep, toSlv(16#080#, 10), 0, slv(to_unsigned(CLK_FREQ_G, 32)));
         axiSlaveRegisterR(ep, toSlv(16#3FC#, 10), 0, r.snapshotSequence);
      end if;
      -- Retire accepted manual work before admitting another command.
      if r.manualValid = '1' and v.manualReady = '1' then
         v.manualValid := '0';
      end if;
      if v.manualAck = '1' and r.busy = '1' then
         v.busy  := '0';
         v.ack   := '1';
         v.error := r.status.error;
      end if;
      -- Normalize the immutable phase operands through the math handshake.
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
            v.manualCommand.phaseSeconds  := mathResult(63 downto 0);
            v.manualCommand.phaseFraction := slv(shift_left(resize(signed(mathRemainder), 64), 16));
            v.manualValid                 := '1';
         end if;
      end if;
      if v.commandWord(7) = '1' then
         -- Manual time writes require automatic control disabled. A command is
         -- copied out of all shadow words before acceptance, then held stable
         -- until acknowledgement; subsequent shadow edits cannot mutate it.
         if r.busy = '1' or configControl.busy = '1' or (servoEnable = '1' and v.commandWord(2 downto 0) /= PTP_CMD_PPS_C) or unsigned(v.commandWord(2 downto 0)) > 4 then
            ep.axiWriteSlave.bresp := AXI_RESP_SLVERR_C;
         else
            v.manualCommand            := PTP_PHC_COMMAND_INIT_C;
            v.manualCommand.kind       := v.commandWord(2 downto 0);
            v.manualCommand.value      := v.commandWord(3);
            v.manualCommand.generation := r.status.generation;
            v.manualCommand.setTime    := r.setTime;
            v.manualCommand.rate       := r.rate;
            v.busy                     := '1';
            v.ack                      := '0';
            v.error                    := '0';
            if v.commandWord(2 downto 0) = PTP_CMD_PHASE_C then
               v.phaseOperand := r.phase;
               v.phaseIssue   := '1';
            else
               v.manualValid := '1';
            end if;
         end if;
      end if;
      if configControl.prepare = '1' then
         v.candidateMonotonic := r.shadowMonotonic;
      end if;
      if configControl.apply = '1' then
         v.activeMonotonic := r.candidateMonotonic;
      end if;
      if snapshotControl.capture = '1' then
         v.snapshotSequence         := snapshotControl.sequenceId;
         v.snapshotTime             := r.timeValue;
         v.snapshotStatus           := r.status;
         v.snapshotStatus.increment := slv(unsigned(NOMINAL_C) + unsigned(r.status.rate));
      end if;
      axiSlaveDefault(ep, v.writeSlave, v.readSlave, AXI_RESP_DECERR_C);
      -- The bus reset cancels responses only. Accepted operations and active
      -- settings belong to the system-reset lifetime, not the AXI transaction.
      if regRst = '1' then
         v.readSlave  := AXI_LITE_READ_SLAVE_INIT_C;
         v.writeSlave := AXI_LITE_WRITE_SLAVE_INIT_C;
      end if;

      if rst = RST_POLARITY_G then
         v.abortNow := '1';
      end if;
      captureAbort <= v.abortNow;
      phcTime      <= r.timeValue;
      status       <= r.status;
      -- Increment is combinational from registered rate so it is canonical even
      -- during initial reset recovery, before the first ordinary PHC tick.
      status.increment <= slv(v.tickIncrement(63 downto 0));
      pps              <= r.pps;

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
