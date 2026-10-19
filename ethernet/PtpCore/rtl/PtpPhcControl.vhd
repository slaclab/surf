-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PHC subsystem identity, owner selection and coordination.
--
-- Owns the committed clock owner: the AXI bank (0) or the external command
-- client (1). The owner shadow freezes at prepare and activates at apply,
-- on the same edges as the PHC monotonic policy. Prepare also closes command
-- admission (busy); this participant reports configPrepared only after the
-- PHC reports commandIdle, sampled from the second edge after prepare so a
-- command admitted by an already published ready is drained first. An owner
-- change therefore happens only at a command boundary. Selecting an external
-- owner that was compiled out votes invalid.
--
-- With EXT_COORDINATION_G = false this block is also the coordinator: local
-- CommitConfig and Snapshot drive localConfigControl/localSnapshotControl,
-- which PtpPhcCore routes to both participants. With EXT_COORDINATION_G = true
-- an enclosing coordinator's records arrive instead and the local submission
-- registers return SLVERR, so only one coordinator drives the PHC strobes.
-- Either way configControl/snapshotControl are the records actually in force.
--
-- Sticky PHC fault, discontinuity and command-error events drive a masked IRQ.
-- regRst cancels AXI responses only; owner state, transactions and snapshot
-- sessions survive it. System reset restores the AXI owner. Contract:
-- ethernet/PtpCore/phc.md.
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

entity PtpPhcControl is
   generic (
      TPD_G              : time    := 1 ns;
      RST_POLARITY_G     : sl      := '1';
      RST_ASYNC_G        : boolean := false;
      COMMON_CLK_G       : boolean := true;
      EXT_COMMAND_EN_G   : boolean := true;
      EXT_COORDINATION_G : boolean := false);
   port (
      -- PHC clock domain
      clk    : in  sl;
      rst    : in  sl;
      regRst : in  sl := '0';

      -- Local register bank
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;

      -- Local coordinator strobes, used only without enclosing coordination
      localConfigControl   : out PtpConfigControlType;
      localSnapshotControl : out PtpSnapshotControlType;

      -- Records in force (local or enclosing) and this participant's votes
      configControl   : in  PtpConfigControlType;
      snapshotControl : in  PtpSnapshotControlType;
      configPrepared  : out sl;
      configValid     : out sl;

      -- PHC participant status and events
      commandIdle         : in  sl;
      manualBusy          : in  sl;
      phcSnapshotPrepared : in  sl;
      captureAbort        : in  sl;
      phcStatus           : in  PtpPhcStatusType;

      -- Committed owner and interrupt
      externalOwner : out sl;
      irq           : out sl);
end entity PtpPhcControl;

architecture rtl of PtpPhcControl is

   type CommitStateType is (
      IDLE_S,
      PREPARE_S,
      VALIDATE_S,
      APPLY_S);

   constant IRQ_FAULT_C         : natural := 0;
   constant IRQ_DISCONTINUITY_C : natural := 1;
   constant IRQ_COMMAND_ERROR_C : natural := 2;

   -- Capability word: supported command kinds, then structural options.
   constant COMMAND_MASK_C : slv(4 downto 0) := "11111";

   function capabilities return slv is
      variable retVar : slv(31 downto 0) := (others => '0');
   begin
      retVar(4 downto 0) := COMMAND_MASK_C;
      retVar(8)          := toSl(EXT_COMMAND_EN_G);
      retVar(9)          := toSl(EXT_COORDINATION_G);
      retVar(10)         := toSl(not COMMON_CLK_G);
      retVar(11)         := '0';  -- No physical actuator in this core.
      return retVar;
   end function;

   type RegType is record
      readSlave        : AxiLiteReadSlaveType;
      writeSlave       : AxiLiteWriteSlaveType;
      -- Owner shadow, frozen candidate and committed value.
      shadowOwner      : sl;
      candidateOwner   : sl;
      activeOwner      : sl;
      -- Participant drain: armed by prepare, satisfied by commandIdle.
      drainArm         : sl;
      configPrepared   : sl;
      configValid      : sl;
      -- Local coordinator.
      state            : CommitStateType;
      localConfig      : PtpConfigControlType;
      configError      : sl;
      configSequence   : slv(31 downto 0);
      snapshotPending  : sl;
      snapshotIssued   : sl;
      localSnapshot    : PtpSnapshotControlType;
      snapshotSequence : slv(31 downto 0);
      -- Sticky events and interrupt.
      events           : slv(2 downto 0);
      irqStatus        : slv(2 downto 0);
      irqMask          : slv(2 downto 0);
      irq              : sl;
   end record;

   constant REG_INIT_C : RegType := (
      readSlave        => AXI_LITE_READ_SLAVE_INIT_C,
      writeSlave       => AXI_LITE_WRITE_SLAVE_INIT_C,
      shadowOwner      => '0',
      candidateOwner   => '0',
      activeOwner      => '0',
      drainArm         => '0',
      configPrepared   => '1',
      configValid      => '1',
      state            => IDLE_S,
      localConfig      => PTP_CONFIG_CONTROL_INIT_C,
      configError      => '0',
      configSequence   => (others => '0'),
      snapshotPending  => '0',
      snapshotIssued   => '0',
      localSnapshot    => PTP_SNAPSHOT_CONTROL_INIT_C,
      snapshotSequence => (others => '0'),
      events           => (others => '0'),
      irqStatus        => (others => '0'),
      irqMask          => (others => '0'),
      irq              => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (all) is
      variable v  : RegType;
      variable ep : AxiLiteEndpointType;
      -- Submissions decoded during this evaluation.
      variable commitRequest   : sl;
      variable snapshotRequest : sl;
      variable irqClear        : slv(2 downto 0);
   begin
      v := r;

      commitRequest   := '0';
      snapshotRequest := '0';
      irqClear        := (others => '0');

      -- Register the one-cycle PHC events before they reach sticky status.
      v.events                      := (others => '0');
      v.events(IRQ_FAULT_C)         := phcStatus.fault;
      v.events(IRQ_DISCONTINUITY_C) := phcStatus.discontinuity;
      v.events(IRQ_COMMAND_ERROR_C) := phcStatus.error;

      -------------------------------------------------------------------------
      -- AXI-Lite: decode, map, qualify submissions, then close the transaction.
      -------------------------------------------------------------------------
      axiSlaveWaitTxn(ep, axiWriteMaster, axiReadMaster, v.writeSlave, v.readSlave);

      -- Suppress register accesses during AXI-only reset.
      if regRst = '1' then
         ep.axiStatus := AXI_LITE_STATUS_INIT_C;
      end if;

      axiSlaveRegisterR(ep, x"000", 0, PTP_PHC_CORE_VERSION_C);
      axiSlaveRegister(ep, x"004", 0, v.shadowOwner);
      axiSlaveRegisterR(ep, x"008", 0, capabilities);
      axiSlaveRegister(ep, x"03C", 0, commitRequest);
      axiSlaveRegisterR(ep, x"040", 0, r.configError);
      axiSlaveRegisterR(ep, x"040", 1, configControl.busy);
      axiSlaveRegisterR(ep, x"044", 0, r.activeOwner);
      axiSlaveRegisterR(ep, x"044", 4, commandIdle);
      axiSlaveRegisterR(ep, x"048", 0, r.configSequence);
      axiSlaveRegisterR(ep, x"04C", 0, r.irqStatus);
      axiSlaveRegister(ep, x"050", 0, v.irqMask);
      axiSlaveRegister(ep, x"054", 0, irqClear);
      axiSlaveRegister(ep, x"100", 0, snapshotRequest);
      axiSlaveRegisterR(ep, x"104", 0, r.snapshotSequence);
      axiSlaveRegisterR(ep, x"108", 0, r.snapshotPending);

      -- Submission checks use pre-edge ownership. Under enclosing
      -- coordination the local submissions would be a second coordinator.
      if commitRequest = '1' then
         if EXT_COORDINATION_G or r.localConfig.busy = '1' or manualBusy = '1' then
            ep.axiWriteSlave.bresp := AXI_RESP_SLVERR_C;
         else
            v.state := PREPARE_S;
         end if;
      end if;

      if snapshotRequest = '1' then
         if EXT_COORDINATION_G or r.snapshotPending = '1' then
            ep.axiWriteSlave.bresp := AXI_RESP_SLVERR_C;
         else
            v.snapshotPending := '1';
         end if;
      end if;

      -- A registered event wins a coincident write-one-to-clear.
      v.irqStatus := (r.irqStatus and not irqClear) or r.events;
      v.irq       := '0';

      if unsigned(v.irqStatus and v.irqMask) /= 0 then
         v.irq := '1';
      end if;

      axiSlaveDefault(ep, v.writeSlave, v.readSlave, AXI_RESP_DECERR_C);

      -- The bus reset cancels responses only.
      if regRst = '1' then
         v.readSlave  := AXI_LITE_READ_SLAVE_INIT_C;
         v.writeSlave := AXI_LITE_WRITE_SLAVE_INIT_C;
      end if;

      -------------------------------------------------------------------------
      -- Participant: freeze, drain and apply on the records in force.
      -------------------------------------------------------------------------
      -- commandIdle registered on the edge after prepare already reflects any
      -- admission by a ready published before busy was seen.
      if r.drainArm = '1' and commandIdle = '1' then
         v.drainArm       := '0';
         v.configPrepared := '1';
      end if;

      if configControl.prepare = '1' then
         v.candidateOwner := r.shadowOwner;
         v.drainArm       := '1';
         v.configPrepared := '0';
         v.configValid    := '1';

         if r.shadowOwner = '1' and not EXT_COMMAND_EN_G then
            v.configValid := '0';
         end if;
      end if;

      if configControl.apply = '1' then
         v.activeOwner := r.candidateOwner;
      end if;

      if snapshotControl.publish = '1' then
         v.snapshotSequence := snapshotControl.sequenceId;
      end if;

      -------------------------------------------------------------------------
      -- Local coordinator; it stays idle under enclosing coordination.
      -------------------------------------------------------------------------
      case r.state is
         when IDLE_S =>
            null;
         when PREPARE_S =>
            v.state := VALIDATE_S;
         when VALIDATE_S =>

            if r.configPrepared = '1' and r.drainArm = '0' then
               if r.configValid = '1' and manualBusy = '0' then
                  v.state := APPLY_S;
               else
                  v.state          := IDLE_S;
                  v.configError    := '1';
                  v.configSequence := ptpSatInc(r.configSequence);
               end if;
            end if;

         when APPLY_S =>
            v.configError    := '0';
            v.configSequence := ptpSatInc(r.configSequence);
            v.state          := IDLE_S;
      end case;

      v.localConfig := PTP_CONFIG_CONTROL_INIT_C;

      if v.state /= IDLE_S then
         v.localConfig.busy := '1';
      end if;

      case v.state is
         when PREPARE_S =>
            v.localConfig.prepare := '1';
         when APPLY_S =>
            v.localConfig.apply := '1';
         when others =>
            null;
      end case;

      -- Capture pins the pre-edge cohort; publish follows bank preparation.
      v.localSnapshot.capture := '0';
      v.localSnapshot.publish := '0';

      if r.localSnapshot.publish = '1' then
         v.snapshotPending := '0';
      elsif r.localSnapshot.capture = '1' then
         null;  -- Prepared falls on this edge; do not sample its old value.
      elsif r.snapshotIssued = '1' then
         if phcSnapshotPrepared = '1' then
            v.localSnapshot.publish := '1';
            v.snapshotIssued        := '0';
         end if;
      elsif r.snapshotPending = '1' and r.localConfig.busy = '0' and
         captureAbort = '0' and rst /= RST_POLARITY_G then
         v.localSnapshot.capture    := '1';
         v.localSnapshot.sequenceId := ptpSatInc(r.snapshotSequence);
         v.snapshotIssued           := '1';
      end if;

      -- Apply synchronous reset before publishing next state and outputs.
      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;

      rin <= v;

      -- Registered outputs.
      axiReadSlave         <= r.readSlave;
      axiWriteSlave        <= r.writeSlave;
      localConfigControl   <= r.localConfig;
      localSnapshotControl <= r.localSnapshot;
      configPrepared       <= r.configPrepared;
      configValid          <= r.configValid;
      externalOwner        <= r.activeOwner;
      irq                  <= r.irq;
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
