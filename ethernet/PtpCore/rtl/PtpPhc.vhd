-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Continuously advancing PTP hardware clock and atomic command
-- target.
--
-- Maintains 48-bit seconds, 32-bit nanoseconds and a 32-bit fractional
-- nanosecond accumulator. Each clock adds the committed Q32
-- nanoseconds-per-cycle increment, normalizing seconds rollover. RATE commands
-- form that increment from nominal plus the signed adjustment. A separate
-- 64-bit unsteered cycle counter provides protocol timers and rate-estimation
-- intervals independent of clock steering.
--
-- This disciplines a numerical time coordinate, not the physical clk input.
-- At 125 MHz the nominal increment is 8 ns; a +10 ppm numerical correction
-- makes it 8.000080 ns per tick without moving any physical clock edge.
-- Fractional bits preserve small accumulated corrections, not sub-cycle I/O
-- timing. Separate integration logic owns waveform generation and physical
-- oscillator control.
--
-- A single ready/valid command slot latches immutable operands and commits
-- them on the following edge. SET names commit-edge time, PHASE adjusts
-- normally advanced time, and RATE changes subsequent increments. Other
-- commands control time validity and PPS enable. Generation checks, command
-- cancellation and monotonic policy reject stale or prohibited operations with
-- an acknowledgement and error.
--
-- A time discontinuity advances the generation, clears validity and suppresses
-- captures and PPS on the affected edge. Registered capture inhibition announces
-- SET/PHASE at admission, before commit; a rejected command may also inhibit
-- captures conservatively. Epoch, tick or generation exhaustion
-- faults closed until system reset;
-- physical timestamp adapters consume the time, exact active increment, raw
-- ticks and capture-abort indication from this module.
--
-- Its local AXI-Lite bank owns monotonic-policy shadows, manual SET/PHASE/RATE
-- operands, command completion and coherent time/rate/tick snapshots. PHASE
-- uses the endpoint-owned word processor to normalize signed Q16 nanoseconds
-- into whole seconds and a signed Q32 remainder. Signed128 quotient/remainder
-- semantics and quotient-fit checks remain exact. Submission freezes operand
-- bank ownership, so later register writes cannot alter a command
-- already being prepared.
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
use surf.PtpRegisterPkg.all;

entity PtpPhc is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      CLK_FREQ_G     : positive := 156250000);
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
      commandSlave  : out PtpPhcCommandSlaveType;
      -- Shared SECOND service, also used by the servo. Manual phase
      -- preparation is the only arithmetic this core performs; the tick and
      -- PPS datapath needs no multiply or divide.
      secondValid       : out sl;
      secondReady       : in  sl                := '0';
      secondRound       : out sl;
      secondOperand     : out slv(127 downto 0);
      secondCancel      : out sl;
      secondResultValid : in  sl                := '0';
      secondResultReady : out sl;
      secondQuotient    : in  slv(127 downto 0) := (others => '0');
      secondRemainder   : in  slv(127 downto 0) := (others => '0'));
end entity PtpPhc;

architecture rtl of PtpPhc is

   type OwnerType is (
      NONE_S,
      MANUAL_S,
      AUTO_S);

   type ManualStateType is (
      IDLE_S, FREEZE_S, OPERAND_READ_S, OPERAND_WAIT_S, OPERAND_STORE_S,
      PHASE_ADMIT_S, PHASE_REQUEST_S, PHASE_WAIT_S, PHASE_CHECK_S,
      REQUEST_S,
      WAIT_ACK_S);
   -- One billion needs 30 bits; Q16 encoding gives a 46-bit divisor magnitude.
   -- Q32 ns: the encoded value is ns * 2**32. The signed status.rate uses the
   -- same scale, so adding it changes ns/tick directly, without a ppb conversion.
   constant NOMINAL_C : unsigned(63 downto 0) := unsigned(ptpNominalIncrement(CLK_FREQ_G));
   constant SECOND_C  : signed(66 downto 0)   := shift_left(to_signed(PTP_NANOSECONDS_PER_SECOND_C, 67), PTP_PHC_FRAC_BITS_C);
   constant EPOCH_LIMIT_C : signed(65 downto 0) := shift_left(to_signed(1, 66), 48);
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
      operandBus         : PtpRegisterBusType;
      operandMaster      : PtpRegisterMasterType;
      operandPrepare     : sl;
      operandWord        : natural range 0 to 9;
      -- Accepted manual work survives AXI reset and later operand writes.
      manualState   : ManualStateType;
      manualBusy    : sl;
      -- Four 32-bit submission words are frozen on admission. The fourth is
      -- an admission guard, not a converter operand: it makes an oversized
      -- software write observable in hardware, which a three-word register
      -- could not do once a client had already truncated its value.
      phaseSubmission : slv(127 downto 0);
      phaseOperand    : slv(95 downto 0);
      secondValid     : sl;
      secondReady     : sl;
      phaseError      : sl;
      manualCommand : PtpPhcCommandType;
      manualAck     : sl;
      manualError   : sl;
      -- Local copies of the common pre-edge diagnostic snapshot.
      snapshotSequence : slv(31 downto 0);
      snapshotBus      : PtpRegisterBusType;
      -- Clock state and the shared one-command commit slot.
      timeValue    : PtpTimeType;
      status       : PtpPhcStatusType;
      owner        : OwnerType;
      commandSlave : PtpPhcCommandSlaveType;
      captureAbort : sl;
      abortSeen    : sl;
      command      : PtpPhcCommandType;
      pending      : sl;
      ppsEnable    : sl;
      pps          : sl;
   end record;

   constant REG_INIT_C : RegType := (
      readSlave          => AXI_LITE_READ_SLAVE_INIT_C,
      writeSlave         => AXI_LITE_WRITE_SLAVE_INIT_C,
      shadowMonotonic    => '1',
      candidateMonotonic => '1',
      activeMonotonic    => '1',
      operandBus         => PTP_REGISTER_BUS_INIT_C,
      operandMaster      => PTP_REGISTER_MASTER_INIT_C,
      operandPrepare     => '0',
      operandWord        => 0,
      manualState        => IDLE_S,
      manualBusy         => '0',
      phaseSubmission    => (others => '0'),
      phaseOperand       => (others => '0'),
      secondValid        => '0',
      secondReady        => '0',
      phaseError         => '0',
      manualCommand      => PTP_PHC_COMMAND_INIT_C,
      manualAck          => '0',
      manualError        => '0',
      snapshotSequence   => (others => '0'),
      snapshotBus        => PTP_REGISTER_BUS_INIT_C,
      timeValue          => PTP_TIME_INIT_C,
      status             => initialStatus,
      owner              => NONE_S,
      commandSlave       => PTP_PHC_COMMAND_SLAVE_INIT_C,
      captureAbort       => '1',
      abortSeen          => '0',
      command            => PTP_PHC_COMMAND_INIT_C,
      pending            => '0',
      ppsEnable          => '0',
      pps                => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   signal operandMasters : PtpRegisterMasterArray(0 to 1);
   signal operandSlaves : PtpRegisterSlaveArray(0 to 1);
   signal operandPrepared : sl;
   signal snapshotScalars : Slv32Array(0 to 9);
   signal snapshotSlave : PtpRegisterSlaveType;

begin

   configValid <= '1';
   assert NOMINAL_C > 0 and NOMINAL_C < unsigned(SECOND_C)
      report "PHC nominal increment must be positive and below one second" severity failure;
   snapshotScalars(0) <= r.timeValue.seconds(31 downto 0);
   snapshotScalars(1) <= x"0000" & r.timeValue.seconds(47 downto 32);
   snapshotScalars(2) <= r.timeValue.nanoseconds;
   snapshotScalars(3) <= r.timeValue.fraction;
   snapshotScalars(4) <= r.status.generation;
   snapshotScalars(5) <= (0 => r.status.timeValid, others => '0');
   snapshotScalars(6) <= r.status.rate(31 downto 0);
   snapshotScalars(7) <= r.status.rate(63 downto 32);
   snapshotScalars(8) <= r.status.ticks(31 downto 0);
   snapshotScalars(9) <= r.status.ticks(63 downto 32);

   U_Snapshot : entity surf.PtpSnapshotBank
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         WORDS_G        => 10)
      port map (
         clk      => clk,
         rst      => rst,
         scalars  => snapshotScalars,
         snapshot => snapshotControl,
         prepared => snapshotPrepared,
         master   => r.snapshotBus.master,
         slave    => snapshotSlave);

   operandMasters(0) <= r.operandBus.master;
   operandMasters(1) <= r.operandMaster;

   U_Operands : entity surf.PtpConfigBank
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         DEFAULTS_G     => Slv32Array'(0 to 9 => (others => '0')))
      port map (
         clk       => clk,
         rst       => rst,
         prepare   => r.operandPrepare,
         apply     => '0',
         prepared  => operandPrepared,
         scanValid => open,
         scanIndex => open,
         scanData  => open,
         masters   => operandMasters,
         slaves    => operandSlaves);

   comb : process (all) is
      variable readAddress  : slv(11 downto 0);
      variable writeAddress : slv(11 downto 0);
      variable v            : RegType;
      variable ep           : AxiLiteEndpointType;
      -- AXI write payload and shared current-cycle admission qualification.
      variable commandWord : slv(7 downto 0);
      variable slotReady   : sl;
      variable readIndex   : integer range -1 to 9;
      variable writeIndex  : integer range -1 to 9;
      variable wordMask    : slv(31 downto 0);
      -- Preserve carry/sign bits until normalization and range checks finish.
      variable nextNanoseconds : signed(66 downto 0);
      variable tickNanoseconds : signed(66 downto 0);
      variable nextSeconds     : signed(65 downto 0);
      variable nextIncrement   : signed(64 downto 0);
      variable phaseSeconds    : signed(65 downto 0);
      variable epochError      : boolean;
   begin
      -- r is pre-edge state. v collects the state to register next; ordinary
      -- ticking happens even while command preparation or arbitration is busy.
      v := r;
      v.secondValid := r.secondValid;
      v.secondReady := '0';
      v.operandPrepare := '0';
      v.operandMaster.responseReady := '1';

      if r.operandMaster.valid = '1' and operandSlaves(1).ready = '1' then
         v.operandMaster.valid := '0';
      end if;

      -- Default one-cycle indications. Manual completion stays latched until
      -- the next accepted software command; target completion is a pulse.
      v.status.ack           := '0';
      v.status.error         := '0';
      v.status.discontinuity := '0';
      v.pps                  := '0';
      v.abortSeen            := portCommandAbort;
      commandWord := (others => '0');
      v.commandSlave         := PTP_PHC_COMMAND_SLAVE_INIT_C;
      -------------------------------------------------------------------------
      -- AXI-Lite: decode, map, qualify submission, then close the transaction.
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

      axiSlaveRegister(ep, x"004", 3, v.shadowMonotonic);
      axiSlaveRegister(ep, x"020", 0, commandWord);
      axiSlaveRegisterR(ep, x"024", 0, r.manualBusy);
      axiSlaveRegisterR(ep, x"024", 1, r.manualAck);
      axiSlaveRegisterR(ep, x"024", 2, r.manualError);
      readIndex  := -1;
      writeIndex := -1;
      wordMask   := (others => '0');

      if unsigned(readAddress(11 downto 2)) >= 10 and unsigned(readAddress(11 downto 2)) <= 19 then
         readIndex := to_integer(unsigned(readAddress(11 downto 2)))-10;
      end if;

      if unsigned(writeAddress(11 downto 2)) >= 10 and unsigned(writeAddress(11 downto 2)) <= 19 then
         writeIndex := to_integer(unsigned(writeAddress(11 downto 2)))-10;
         if writeIndex = 1 then
            if ep.axiWriteMaster.wstrb(1 downto 0) = "11" then
               wordMask := x"0000FFFF";
            end if;
         elsif ep.axiWriteMaster.wstrb = x"F" then
            wordMask := (others => '1');
         end if;
      end if;

      ptpRegisterBus(v.operandBus, r.operandBus, operandSlaves(0), ep, readIndex, writeIndex, wordMask, "00", regRst);
      axiSlaveRegisterR(ep, x"050", 0, slv(NOMINAL_C));
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
            v.manualAck                := '0';
            v.manualError              := '0';
            if commandWord(2 downto 0) = PTP_CMD_SET_C or commandWord(2 downto 0) = PTP_CMD_PHASE_C or
               commandWord(2 downto 0) = PTP_CMD_RATE_C then
               v.operandPrepare := '1';
               v.phaseError := '0';
               v.manualState := FREEZE_S;
            else
               v.manualState := REQUEST_S;
            end if;
         end if;
      end if;

      readIndex := -1;

      case to_integer(unsigned(readAddress(11 downto 2))) is
         when 2 to 7 =>
            readIndex := to_integer(unsigned(readAddress(11 downto 2)))-2;
         when 22 to 25 =>
            readIndex := to_integer(unsigned(readAddress(11 downto 2)))-16;
         when others =>
            null;
      end case;

      ptpRegisterBus(v.snapshotBus, r.snapshotBus, snapshotSlave, ep, readIndex, -1, x"00000000", "00", regRst);
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
         when FREEZE_S =>

            if r.operandPrepare = '0' and operandPrepared = '1' then
               v.operandWord := 0;
               if r.manualCommand.kind = PTP_CMD_PHASE_C then
                  v.operandWord := 4;
               elsif r.manualCommand.kind = PTP_CMD_RATE_C then
                  v.operandWord := 8;
               end if;
               v.manualState := OPERAND_READ_S;
            end if;

         when OPERAND_READ_S =>
            v.operandMaster.valid := '1';
            v.operandMaster.write := '0';
            v.operandMaster.bank := "10";
            v.operandMaster.index := toSlv(r.operandWord, 8);
            v.manualState := OPERAND_WAIT_S;
         when OPERAND_WAIT_S =>

            if operandSlaves(1).responseValid = '1' then

               case r.operandWord is
                  when 0 =>
                     v.manualCommand.setTime.seconds(31 downto 0) := operandSlaves(1).data;
                  when 1 =>
                     v.manualCommand.setTime.seconds(47 downto 32) := operandSlaves(1).data(15 downto 0);
                  when 2 =>
                     v.manualCommand.setTime.nanoseconds := operandSlaves(1).data;
                  when 3 =>
                     v.manualCommand.setTime.fraction := operandSlaves(1).data;
                  when 4 to 7 =>
                     -- Collect all four submission words, including the guard.
                     v.phaseSubmission(32*(r.operandWord-4)+31 downto
                                       32*(r.operandWord-4)) := operandSlaves(1).data;
                  when 8 to 9 =>
                     v.manualCommand.rate(32*(r.operandWord-8)+31 downto 32*(r.operandWord-8)) := operandSlaves(1).data;
               end case;

               v.manualState := OPERAND_STORE_S;
            end if;

         when OPERAND_STORE_S =>

            if r.operandWord = 3 or r.operandWord = 9 then
               v.manualState := REQUEST_S;
            elsif r.operandWord = 7 then
               v.manualState := PHASE_ADMIT_S;
            else
               v.operandWord := r.operandWord+1;
               v.manualState := OPERAND_READ_S;
            end if;

         when PHASE_ADMIT_S =>
            -- Validate the entire 128-bit submission before narrowing. A
            -- non-sign-extended guard word is a command error: it does not
            -- advance generation, invalidate time or raise a fatal fault.
            -- Signed96 spans the whole reachable epoch, so no successful
            -- adjustment changes behavior. A representable value can still
            -- exceed the epoch at commit and keeps the existing fault.
            v.manualState := PHASE_REQUEST_S;

            if resize(signed(r.phaseSubmission(95 downto 0)), 128) /=
               signed(r.phaseSubmission) then
               v.phaseError := '1';
               v.manualState := PHASE_CHECK_S;
            else
               v.phaseOperand := r.phaseSubmission(95 downto 0);
               v.secondValid := '1';
            end if;

         when PHASE_REQUEST_S =>
            -- Truncating conversion: the quotient is whole seconds and the
            -- remainder is the exact subsecond part with the dividend's sign.
            if secondReady = '1' then
               v.secondValid := '0';
               v.manualState := PHASE_WAIT_S;
            end if;

         when PHASE_WAIT_S =>
            v.secondReady := '1';

            if secondResultValid = '1' then
               v.secondReady := '0';
               v.manualState := PHASE_CHECK_S;

               -- The quotient must fit signed64 and the remainder signed48,
               -- the widths the command record carries.
               if resize(signed(secondQuotient(63 downto 0)), 128) /= signed(secondQuotient) or
                  resize(signed(secondRemainder(47 downto 0)), 128) /= signed(secondRemainder) then
                  v.phaseError := '1';
               else
                  v.manualCommand.phaseSeconds := secondQuotient(63 downto 0);
                  v.manualCommand.phaseFraction :=
                     slv(shift_left(resize(signed(secondRemainder), 64), PTP_TIME_FRAC_BITS_C));
               end if;
            end if;

         when PHASE_CHECK_S =>
            v.manualState := REQUEST_S;

            if r.phaseError = '1' then
               v.manualState := IDLE_S;
               v.manualAck := '1';
               v.manualError := '1';
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
      -- Registered ready promises an available automatic-command slot. Manual
      -- preparation deasserts that promise before REQUEST_S can claim it.
      -- Completion routing is resolved with the result before registration.
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
               if r.commandSlave.ready = '1' then
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

            if r.status.ack = '1' then
               v.owner := NONE_S;
            end if;

      end case;

      -------------------------------------------------------------------------
      -- Clock algorithm: ordinary tick, pending command, then final priority.
      -------------------------------------------------------------------------
      -- Advance once with the committed pre-edge increment. Keep widened signed
      -- intermediates until command arithmetic and epoch bounds are checked.
      -- Concatenating nanoseconds and fraction forms one Q32-ns value. Carry
      -- across bit 31 advances integer ns; SECOND_C handles the decimal second.
      tickNanoseconds := signed(resize(unsigned(slv'(r.timeValue.nanoseconds & r.timeValue.fraction)), 67) +
         resize(unsigned(r.status.increment), 67));
      nextNanoseconds := tickNanoseconds;
      nextSeconds := signed(resize(unsigned(r.timeValue.seconds), 66));
      -- Check epoch bounds in parallel with seconds arithmetic. Do not route
      -- the late nanosecond carry through a seconds sum and then a wide fault
      -- comparison back to every time register's enable.
      epochError := false;
      -- Raw ticks deliberately ignore numerical rate and phase corrections.
      -- They count oscillator edges, not calibrated nanoseconds; physically
      -- steering clk would also change their relationship to real elapsed time.
      v.status.ticks := slv(unsigned(r.status.ticks) + 1);

      if nextNanoseconds >= SECOND_C then
         -- Detect crossing, not equality: an adjusted increment can skip over
         -- exactly zero ns. PPS is one clk cycle on this edge grid (8 ns at
         -- 125 MHz); final validity/command checks below may suppress it.
         nextNanoseconds := nextNanoseconds-SECOND_C;
         nextSeconds     := nextSeconds+1;
         v.pps           := r.ppsEnable and r.status.timeValid;
         epochError := r.timeValue.seconds = x"FFFFFFFFFFFF";
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
                  -- SET names the desired time at this commit edge. Unlike
                  -- PHASE, it replaces rather than offsets the ordinary tick.
                  if unsigned(r.command.setTime.nanoseconds) >= PTP_NANOSECONDS_PER_SECOND_C then
                     v.status.error := '1';
                  elsif r.activeMonotonic = '1' and r.status.timeValid = '1' then
                     v.status.error := '1';
                  else
                     nextSeconds     := signed(resize(unsigned(r.command.setTime.seconds), 66));
                     nextNanoseconds := signed(resize(unsigned(slv'(r.command.setTime.nanoseconds & r.command.setTime.fraction)), 67));
                     v.status.discontinuity := '1';
                     epochError := false;
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
                     -- Combine the phase with the unnormalized tick. Feeding
                     -- ordinary rollover back through a second normalization
                     -- serializes two wide carry/compare/select paths.
                     phaseSeconds := signed(resize(unsigned(r.timeValue.seconds), 66)) +
                        resize(signed(r.command.phaseSeconds), 66);
                     nextSeconds := phaseSeconds;
                     epochError := phaseSeconds < 0 or phaseSeconds >= EPOCH_LIMIT_C;
                     nextNanoseconds := tickNanoseconds +
                        resize(signed(r.command.phaseFraction), 67);
                     if nextNanoseconds < 0 then
                        nextNanoseconds := nextNanoseconds+SECOND_C;
                        nextSeconds     := phaseSeconds-1;
                        epochError := phaseSeconds < 1 or phaseSeconds >= EPOCH_LIMIT_C+1;
                     elsif nextNanoseconds >= shift_left(SECOND_C, 1) then
                        nextNanoseconds := nextNanoseconds-shift_left(SECOND_C, 1);
                        nextSeconds     := phaseSeconds+2;
                        epochError := phaseSeconds < -2 or phaseSeconds >= EPOCH_LIMIT_C-2;
                     elsif nextNanoseconds >= SECOND_C then
                        nextNanoseconds := nextNanoseconds-SECOND_C;
                        nextSeconds     := phaseSeconds+1;
                        epochError := phaseSeconds < -1 or phaseSeconds >= EPOCH_LIMIT_C-1;
                     end if;
                     v.status.discontinuity := '1';
                  end if;
               when PTP_CMD_RATE_C =>
                  -- This commit edge has advanced with r.status.increment.
                  -- Publish the new increment beside the resulting timestamp
                  -- so consumers know the rate for subsequent clock intervals.
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
      -- generation is a discontinuity tag, not the seconds counter. Old packet
      -- captures and queued commands must not be reused across a time step.
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
      if epochError or unsigned(r.status.ticks) = x"FFFFFFFFFFFFFFFF" then
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
         -- Invalid time still advances. clearValid revokes its qualification;
         -- it does not stop timekeeping or erase the retained rate correction.
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

      -- Announce possible SET/PHASE invalidation at admission, one cycle before
      -- commit. A later rejected command may conservatively inhibit a capture;
      -- it must never require a combinational veto from the commit arithmetic.
      -- Keep fault/discontinuity asserted with the resulting clock state.
      v.captureAbort := v.status.fault or v.status.discontinuity;

      if v.pending = '1' and (v.command.kind = PTP_CMD_SET_C or v.command.kind = PTP_CMD_PHASE_C) then
         v.captureAbort := '1';
      end if;

      if r.owner = AUTO_S then
         v.commandSlave.ack   := v.status.ack;
         v.commandSlave.error := v.status.error;
      end if;

      if v.owner = NONE_S and v.manualState /= REQUEST_S and v.status.fault = '0' then
         v.commandSlave.ready := '1';
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

      if snapshotControl.publish = '1' then
         v.snapshotSequence := snapshotControl.sequenceId;
      end if;

      v.manualBusy := '0';

      if v.manualState /= IDLE_S then
         v.manualBusy := '1';
      end if;

      -- Apply synchronous reset before publishing next state and outputs.
      if RST_ASYNC_G = false and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;

      rin <= v;
      -------------------------------------------------------------------------
      -- Registered functional outputs, including admission and completion.
      -------------------------------------------------------------------------
      commandSlave   <= r.commandSlave;
      captureAbort   <= r.captureAbort;
      manualBusy     <= r.manualBusy;
      secondValid <= r.secondValid;
      secondRound <= '0';  -- Truncate; the remainder is the subsecond part.
      secondOperand <= slv(resize(signed(r.phaseOperand), 128));
      secondCancel <= '0';
      secondResultReady <= v.secondReady;
      axiReadSlave   <= r.readSlave;
      axiWriteSlave  <= r.writeSlave;
      phcTime        <= r.timeValue;
      status         <= r.status;
      pps            <= r.pps;
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
