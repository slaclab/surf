-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Endpoint-wide AXI coordination for distributed PTP register banks.
--
-- Owns only global enables, commit/snapshot transactions and IRQ aggregation.
-- PHC, port and servo settings and wide diagnostic payloads remain in their
-- local AXI managers. A commit freezes all candidates, checks their votes,
-- then applies every bank on one common edge or leaves all active state intact.
-- Commit submission returns immediately; software polls ConfigBusy and checks
-- ConfigError/ConfigSequence. Shadow writes after prepare affect a later commit.
-- Snapshots defer during commits or capture invalidation, then all banks latch
-- pre-edge state with the same sequence. Accepted coordination survives a bus
-- reset, even if that reset cancels its AXI response. System reset clears it.
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
use surf.AxiStreamPkg.all;
use surf.PtpPkg.all;

entity PtpReg is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      CLK_FREQ_G     : positive := 156250000);
   port (
      clk              : in  sl;
      rst              : in  sl;
      regRst           : in  sl := '0';
      axiReadMaster    : in  AxiLiteReadMasterType;
      axiReadSlave     : out AxiLiteReadSlaveType;
      axiWriteMaster   : in  AxiLiteWriteMasterType;
      axiWriteSlave    : out AxiLiteWriteSlaveType;
      manualBusy       : in  sl;
      phcConfigValid   : in  sl;
      portConfigValid  : in  sl;
      servoConfigValid : in  sl;
      captureAbort     : in  sl;
      events           : in  slv(3 downto 0);
      portActive       : in  sl;
      servoState       : in  slv(2 downto 0);
      filterCount      : in  slv(2 downto 0);
      announceValid    : in  sl;
      enable           : out sl;
      servoEnable      : out sl;
      irq              : out sl;
      configControl    : out PtpConfigControlType;
      snapshotControl  : out PtpSnapshotControlType);
end entity PtpReg;

architecture rtl of PtpReg is

   type CommitStateType is (
      IDLE_S,
      PREPARE_S,
      VALIDATE_S,
      APPLY_S);

   type RegType is record
      readSlave        : AxiLiteReadSlaveType;
      writeSlave       : AxiLiteWriteSlaveType;
      state            : CommitStateType;
      configControl    : PtpConfigControlType;
      shadow           : slv(1 downto 0);
      candidate        : slv(1 downto 0);
      activeConfig     : slv(1 downto 0);
      configError      : sl;
      configSequence   : slv(31 downto 0);
      snapshotPending  : sl;
      snapshotSequence : slv(31 downto 0);
      snapshotControl  : PtpSnapshotControlType;
      irq              : sl;
      irqStatus        : slv(31 downto 0);
      irqMask          : slv(31 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      readSlave        => AXI_LITE_READ_SLAVE_INIT_C,
      writeSlave       => AXI_LITE_WRITE_SLAVE_INIT_C,
      state            => IDLE_S,
      configControl    => PTP_CONFIG_CONTROL_INIT_C,
      shadow           => (others => '0'),
      candidate        => (others => '0'),
      activeConfig     => (others => '0'),
      configError      => '0',
      configSequence   => (others => '0'),
      snapshotPending  => '0',
      snapshotSequence => (others => '0'),
      snapshotControl  => PTP_SNAPSHOT_CONTROL_INIT_C,
      irq              => '0',
      irqStatus        => (others => '0'),
      irqMask          => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (r, rst, regRst, axiReadMaster, axiWriteMaster, manualBusy, phcConfigValid,
                   portConfigValid, servoConfigValid, captureAbort, events, portActive, servoState, filterCount, announceValid) is
      variable v  : RegType;
      variable ep : AxiLiteEndpointType;

      -- Calculations used only during this evaluation.
      variable commitRequest   : sl;
      variable snapshotRequest : sl;
      variable irqClear        : slv(31 downto 0);
   begin
      v := r;

      -- Decode requests against pre-edge ownership; completing a commit does
      -- not make the same edge available for another submission.
      commitRequest   := '0';
      snapshotRequest := '0';
      irqClear        := (others => '0');

      -------------------------------------------------------------------------
      -- AXI-Lite: decode, map, qualify submissions, then close the transaction.
      -------------------------------------------------------------------------
      axiSlaveWaitTxn(ep, axiWriteMaster, axiReadMaster, v.writeSlave, v.readSlave);

      -- Suppress register accesses during AXI-only reset.
      if regRst = '1' then
         ep.axiStatus := AXI_LITE_STATUS_INIT_C;
      end if;

      -- Identification, enable shadows and coordinated commit.
      -- Provisional development identification; no released ABI version yet.
      axiSlaveRegisterR(ep, x"000", 0, slv'(x"00020000"));
      axiSlaveRegister(ep, x"004", 0, v.shadow);
      axiSlaveRegister(ep, x"03C", 0, commitRequest);
      axiSlaveRegisterR(ep, x"040", 0, r.configError);
      axiSlaveRegisterR(ep, x"040", 1, r.configControl.busy);
      axiSlaveRegisterR(ep, x"044", 0, r.activeConfig);
      axiSlaveRegisterR(ep, x"044", 4, portActive);
      axiSlaveRegisterR(ep, x"044", 8, servoState);
      axiSlaveRegisterR(ep, x"044", 12, filterCount);
      axiSlaveRegisterR(ep, x"044", 16, announceValid);
      axiSlaveRegisterR(ep, x"048", 0, r.configSequence);

      -- Interrupt status, mask and write-one-to-clear.
      axiSlaveRegisterR(ep, x"04C", 0, r.irqStatus);
      axiSlaveRegister(ep, x"050", 0, v.irqMask);
      axiSlaveRegister(ep, x"054", 0, irqClear);

      -- Coordinated snapshot submission and completion.
      axiSlaveRegister(ep, x"100", 0, snapshotRequest);
      axiSlaveRegisterR(ep, x"104", 0, r.snapshotSequence);
      axiSlaveRegisterR(ep, x"108", 0, r.snapshotPending);

      -- Submission checks use pre-edge ownership. Completion below cannot
      -- make a busy command or pending snapshot accept a replacement here.
      if commitRequest = '1' then
         if r.configControl.busy = '1' or manualBusy = '1' then
            ep.axiWriteSlave.bresp := AXI_RESP_SLVERR_C;
         else
            v.state := PREPARE_S;
         end if;
      end if;
      if snapshotRequest = '1' then
         if r.snapshotPending = '1' then
            ep.axiWriteSlave.bresp := AXI_RESP_SLVERR_C;
         else
            v.snapshotPending := '1';
         end if;
      end if;
      -- A live event wins a coincident write-one-to-clear.
      v.irqStatus             := r.irqStatus and not irqClear;
      v.irqStatus(3 downto 0) := v.irqStatus(3 downto 0) or events;

      -- Register IRQ with the event/W1C result and any mask write.
      v.irq := '0';
      if unsigned(v.irqStatus and v.irqMask) /= 0 then
         v.irq := '1';
      end if;

      axiSlaveDefault(ep, v.writeSlave, v.readSlave, AXI_RESP_DECERR_C);
      -- The bus reset cancels responses only. Accepted operations and active
      -- settings belong to the system-reset lifetime, not the AXI transaction.
      if regRst = '1' then
         v.readSlave  := AXI_LITE_READ_SLAVE_INIT_C;
         v.writeSlave := AXI_LITE_WRITE_SLAVE_INIT_C;
      end if;

      -------------------------------------------------------------------------
      -- Accepted commit/snapshot work survives AXI-only reset.
      -------------------------------------------------------------------------
      -- Freeze, validate and apply the same candidate across every bank.
      case r.state is
         when IDLE_S =>
            null;
         when PREPARE_S =>
            v.candidate := r.shadow;
            v.state     := VALIDATE_S;
         when VALIDATE_S =>
            if phcConfigValid = '1' and portConfigValid = '1' and
               servoConfigValid = '1' and manualBusy = '0' then
               v.state := APPLY_S;
            else
               v.state          := IDLE_S;
               v.configError    := '1';
               v.configSequence := ptpSatInc(r.configSequence);
            end if;
         when APPLY_S =>
            v.activeConfig   := r.candidate;
            v.configError    := '0';
            v.configSequence := ptpSatInc(r.configSequence);
            v.state          := IDLE_S;
      end case;
      -- Register coordination with the resolved state. Banks still sample
      -- prepare in PREPARE_S and apply in APPLY_S, with no extra commit cycle.
      -- System reset resets the coordinator and every participating bank.
      v.configControl := PTP_CONFIG_CONTROL_INIT_C;
      if v.state /= IDLE_S then
         v.configControl.busy := '1';
      end if;
      case v.state is
         when PREPARE_S =>
            v.configControl.prepare := '1';
         when APPLY_S =>
            v.configControl.apply := '1';
         when others =>
            null;
      end case;

      -- Issue a registered broadcast, then complete on the edge on which all
      -- banks consume it. An issued snapshot samples coherent pre-edge state,
      -- even if a command changes that state on the same edge. Invalidation
      -- defers new issues; it cannot withdraw an already published request.
      v.snapshotControl.capture := '0';
      if r.snapshotControl.capture = '1' then
         v.snapshotPending  := '0';
         v.snapshotSequence := r.snapshotControl.sequenceId;
      elsif r.snapshotPending = '1' and r.configControl.busy = '0' and
         captureAbort = '0' and rst /= RST_POLARITY_G then
         v.snapshotControl.capture    := '1';
         v.snapshotControl.sequenceId := ptpSatInc(r.snapshotSequence);
      end if;
      -- Apply synchronous reset before publishing next state and outputs.
      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;
      rin <= v;

      -- Publish registered status and the qualified coordination strobes.
      configControl   <= r.configControl;
      snapshotControl <= r.snapshotControl;
      enable          <= r.activeConfig(0);
      servoEnable     <= r.activeConfig(1);
      irq             <= r.irq;
      axiReadSlave    <= r.readSlave;
      axiWriteSlave   <= r.writeSlave;
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
