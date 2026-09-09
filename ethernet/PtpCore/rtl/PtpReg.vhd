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
      configValid      : in  slv(2 downto 0);
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
      -- Current-cycle calculations and diagnostics. Use v for same-edge
      -- decisions; these fields do not introduce a protocol pipeline stage.
      busy             : sl;
      snapshotNow      : sl;
      commitRequest    : sl;
      snapshotRequest  : sl;
      irqClear         : slv(31 downto 0);

      readSlave        : AxiLiteReadSlaveType;
      writeSlave       : AxiLiteWriteSlaveType;
      state            : CommitStateType;
      shadow           : slv(1 downto 0);
      candidate        : slv(1 downto 0);
      activeConfig     : slv(1 downto 0);
      configError      : sl;
      configSequence   : slv(31 downto 0);
      snapshotPending  : sl;
      snapshotSequence : slv(31 downto 0);
      irqStatus        : slv(31 downto 0);
      irqMask          : slv(31 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      busy             => '0',
      snapshotNow      => '0',
      commitRequest    => '0',
      snapshotRequest  => '0',
      irqClear         => (others => '0'),
      readSlave        => AXI_LITE_READ_SLAVE_INIT_C,
      writeSlave       => AXI_LITE_WRITE_SLAVE_INIT_C,
      state            => IDLE_S,
      shadow           => (others => '0'),
      candidate        => (others => '0'),
      activeConfig     => (others => '0'),
      configError      => '0',
      configSequence   => (others => '0'),
      snapshotPending  => '0',
      snapshotSequence => (others => '0'),
      irqStatus        => (others => '0'),
      irqMask          => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (r, rst, regRst, axiReadMaster, axiWriteMaster, manualBusy, configValid, captureAbort,
                   events, portActive, servoState, filterCount, announceValid) is
      variable v  : RegType;
      variable ep : AxiLiteEndpointType;
   begin
      v := r;

      -- Decode requests against pre-edge ownership; completing a commit does
      -- not make the same edge available for another submission.
      v.busy := '0';
      if r.state /= IDLE_S then
         v.busy := '1';
      end if;
      configControl.prepare <= '0';
      configControl.apply   <= '0';
      v.snapshotNow         := '0';

      v.commitRequest   := '0';
      v.snapshotRequest := '0';
      v.irqClear        := (others => '0');
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
         axiSlaveRegisterR(ep, toSlv(16#000#, 10), 0, slv'(x"00020000"));
         axiSlaveRegister(ep, toSlv(16#004#, 10), 0, v.shadow);
         axiSlaveRegister(ep, toSlv(16#03C#, 10), 0, v.commitRequest);
         axiSlaveRegisterR(ep, toSlv(16#040#, 10), 0, r.configError);
         axiSlaveRegisterR(ep, toSlv(16#040#, 10), 1, v.busy);
         axiSlaveRegisterR(ep, toSlv(16#044#, 10), 0, r.activeConfig);
         axiSlaveRegisterR(ep, toSlv(16#044#, 10), 4, portActive);
         axiSlaveRegisterR(ep, toSlv(16#044#, 10), 8, servoState);
         axiSlaveRegisterR(ep, toSlv(16#044#, 10), 12, filterCount);
         axiSlaveRegisterR(ep, toSlv(16#044#, 10), 16, announceValid);
         axiSlaveRegisterR(ep, toSlv(16#048#, 10), 0, r.configSequence);
         axiSlaveRegisterR(ep, toSlv(16#04C#, 10), 0, r.irqStatus);
         axiSlaveRegister(ep, toSlv(16#050#, 10), 0, v.irqMask);
         axiSlaveRegister(ep, toSlv(16#054#, 10), 0, v.irqClear);
         axiSlaveRegister(ep, toSlv(16#100#, 10), 0, v.snapshotRequest);
         axiSlaveRegisterR(ep, toSlv(16#104#, 10), 0, r.snapshotSequence);
         axiSlaveRegisterR(ep, toSlv(16#108#, 10), 0, r.snapshotPending);
      end if;
      -- Freeze, validate and apply the same candidate across every bank.
      case r.state is
         when IDLE_S =>
            null;
         when PREPARE_S =>
            if rst /= RST_POLARITY_G then
               configControl.prepare <= '1';
            end if;
            v.candidate := r.shadow;
            v.state     := VALIDATE_S;
         when VALIDATE_S =>
            if configValid = "111" and manualBusy = '0' then
               v.state := APPLY_S;
            else
               v.state          := IDLE_S;
               v.configError    := '1';
               v.configSequence := ptpSatInc(r.configSequence);
            end if;
         when APPLY_S =>
            if rst /= RST_POLARITY_G then
               configControl.apply <= '1';
            end if;
            v.activeConfig   := r.candidate;
            v.configError    := '0';
            v.configSequence := ptpSatInc(r.configSequence);
            v.state          := IDLE_S;
      end case;
      if v.commitRequest = '1' then
         if v.busy = '1' or manualBusy = '1' then
            ep.axiWriteSlave.bresp := AXI_RESP_SLVERR_C;
         else
            v.state := PREPARE_S;
         end if;
      end if;
      -- Snapshot pre-edge state only outside a commit and capture invalidation.
      -- Use r.snapshotPending so a new write cannot capture on its submit edge.
      if v.busy = '0' and captureAbort = '0' and rst /= RST_POLARITY_G then
         v.snapshotNow := r.snapshotPending;
      end if;
      if v.snapshotNow = '1' then
         v.snapshotPending  := '0';
         v.snapshotSequence := ptpSatInc(r.snapshotSequence);
      end if;
      if v.snapshotRequest = '1' then
         if r.snapshotPending = '1' then
            ep.axiWriteSlave.bresp := AXI_RESP_SLVERR_C;
         else
            v.snapshotPending := '1';
         end if;
      end if;
      -- A live event wins a coincident write-one-to-clear.
      v.irqStatus             := r.irqStatus and not v.irqClear;
      v.irqStatus(3 downto 0) := v.irqStatus(3 downto 0) or events;
      axiSlaveDefault(ep, v.writeSlave, v.readSlave, AXI_RESP_DECERR_C);
      -- The bus reset cancels responses only. Accepted operations and active
      -- settings belong to the system-reset lifetime, not the AXI transaction.
      if regRst = '1' then
         v.readSlave  := AXI_LITE_READ_SLAVE_INIT_C;
         v.writeSlave := AXI_LITE_WRITE_SLAVE_INIT_C;
      end if;
      -- Publish registered status and the qualified coordination strobes.
      configControl.busy         <= v.busy;
      snapshotControl.capture    <= v.snapshotNow;
      snapshotControl.sequenceId <= ptpSatInc(r.snapshotSequence);
      enable                     <= r.activeConfig(0);
      servoEnable                <= r.activeConfig(1);
      irq                        <= '0';
      if unsigned(r.irqStatus and r.irqMask) /= 0 then
         irq <= '1';
      end if;
      axiReadSlave  <= r.readSlave;
      axiWriteSlave <= r.writeSlave;

      if not RST_ASYNC_G and rst = RST_POLARITY_G then
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
