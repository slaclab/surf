-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Fixed-source Layer-2 PTP TimeReceiver composition.
-- PtpProtocolReg owns active configuration, AXI and coherent snapshots.
-- PtpPortPolicy owns source admission, receipt deadlines and lifecycle.
-- PtpSyncFlow owns pairing/history scans and measurement sequencing.
-- PtpDelayReqTx owns request scheduling and frame drain; PtpTxLedger owns
-- wire keys and physical completion/response association across restart.
-- Child boundaries preserve same-edge cancellation and registered publication;
-- this composition adds no state or latency. It implements configured-source
-- one-/two-step E2E reception, not BMCA, VLAN, UDP or peer delay.
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
use surf.PtpMathPkg.all;
use surf.PtpProtocolPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.PtpPkg.all;
use surf.PtpRegisterPkg.all;

entity PtpProtocolEngine is
   generic (
      TPD_G             : time             := 1 ns;
      RST_POLARITY_G    : sl               := '1';
      RST_ASYNC_G       : boolean          := false;
      CLK_FREQ_G        : positive         := 156250000;
      PACKET_LIFETIME_G : positive         := 156250000;
      INGRESS_LATENCY_G : slv(63 downto 0) := (others => '0');
      EGRESS_LATENCY_G  : slv(63 downto 0) := (others => '0');
      -- Supported inferred RAM implementations: "distributed" or "block".
      HISTORY_MEMORY_TYPE_G : string           := "block";
      PAIR_MEMORY_TYPE_G    : string           := "block");
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
      configPrepared   : out sl;
      enable           : in  sl                     := '0';
      rxCounters       : in  PtpRxCountersType      := PTP_RX_COUNTERS_INIT_C;
      sharedConfig     : out PtpSharedConfigType;
      -- Protocol/clock interface.
      restart         : in  sl;
      linkReady       : in  sl;
      macResetDone    : in  sl;
      localMac        : in  slv(47 downto 0);
      phcStatus       : in  PtpPhcStatusType;
      captureAbort    : in  sl;
      rxMessageMaster : in  PtpRxMessageMasterType;
      rxReady         : out sl;
      rxQueueOverflow : in  sl := '0';
      rxAbort         : in  sl;
      -- Physical completion producer holds its record through txMessageReady.
      txMessageMaster   : in  PtpRxMessageMasterType;
      txMessageReady    : out sl;
      txAbort           : in  sl;
      txMaster          : out AxiStreamMasterType;
      txSlave           : in  AxiStreamSlaveType;
      measurementMaster : out PtpMeasurementMasterType;
      measurementSlave  : in  PtpMeasurementSlaveType;
      lifecycle         : out PtpPortLifecycleType;
      status            : out PtpPortStatusType;
      -- Shared endpoint variable divider. Index 0 is the rate estimator and
      -- index 1 is the E2E calibration path; both use the positive-divisor,
      -- quotient-only contract and qualify their divisor before narrowing.
      divideRequests    : out PtpDivideRequestArray(1 downto 0)(operandB(79 downto 0));
      divideReady       : in  slv(1 downto 0)                  := (others => '0');
      divideCancel      : out slv(1 downto 0);
      divideResults     : in  PtpDivideResultArray(1 downto 0) := (others => PTP_DIVIDE_RESULT_INIT_C);
      divideResultReady : out slv(1 downto 0));
end entity PtpProtocolEngine;

architecture rtl of PtpProtocolEngine is

   signal activeConfig     : PtpPortConfigType;
   signal identityChanged  : sl;
   signal policyStatus     : PtpPortStatusType;
   signal flowStatus       : PtpPortStatusType;
   signal portStatus       : PtpPortStatusType;
   signal publication      : PtpPublicationType;
   signal abortPort        : sl;
   signal abortNow         : sl;
   signal lastSyncTicks    : slv(63 downto 0);
   signal policyIdle       : sl;
   signal txEnable         : sl;
   signal txIntervalValid  : sl;
   signal allocate         : sl;
   signal allocateReady    : sl;
   signal allocateSequence : slv(15 downto 0);
   signal responseValid    : sl;
   signal responseReady    : sl;
   signal responseLog      : slv(7 downto 0);
   signal responseAccepted : sl;
   signal delayValid       : sl;
   signal delayReady       : sl;
   signal ledgerStatus     : slv(31 downto 0);
   signal timeoutCount     : slv(31 downto 0);

   signal policyAdmission        : PtpAdmissionType;
   signal policyResponseInterval : PtpIntervalType;
   signal flowResponseMaster     : PtpRxMessageMasterType;
   signal flowAdmissionEvents    : PtpAdmissionEventsType;
   signal delayReqTxInterval     : PtpIntervalType;
   signal ledgerSampleMaster     : PtpDelaySampleMasterType;
   signal ledgerAllocation       : PtpLedgerAllocationType;

begin

   delayReqTxInterval <=
   (
      valid => txIntervalValid,
      ticks => policyResponseInterval.ticks
   );

   responseValid    <= flowResponseMaster.valid;
   delayValid       <= ledgerSampleMaster.valid;
   allocateReady    <= ledgerAllocation.ready;
   allocateSequence <= ledgerAllocation.sequenceId;

   -- Compose registered fields without introducing another sampling edge.
   status                         <= portStatus;
   portStatus.active              <= policyStatus.active;
   portStatus.announceValid       <= policyStatus.announceValid;
   portStatus.announceBody        <= policyStatus.announceBody;
   portStatus.grandmasterIdentity <= policyStatus.grandmasterIdentity;
   portStatus.announceFlags       <= policyStatus.announceFlags;
   portStatus.utcOffset           <= policyStatus.utcOffset;
   portStatus.ratioValid          <= flowStatus.ratioValid;
   portStatus.rejectedCount       <= flowStatus.rejectedCount;
   portStatus.syncCount           <= flowStatus.syncCount;
   portStatus.delayCount          <= flowStatus.delayCount;
   portStatus.exchange            <= flowStatus.exchange;
   portStatus.ledgerStatus        <= flowStatus.ledgerStatus;
   portStatus.timeoutCount        <= flowStatus.timeoutCount;
   txIntervalValid                <= responseAccepted and policyResponseInterval.valid;

   U_Reg : entity surf.PtpProtocolReg
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         CLK_FREQ_G        => CLK_FREQ_G,
         PACKET_LIFETIME_G => PACKET_LIFETIME_G,
         INGRESS_LATENCY_G => INGRESS_LATENCY_G,
         EGRESS_LATENCY_G  => EGRESS_LATENCY_G)
      port map (
         clk              => clk,               -- [in]
         rst              => rst,               -- [in]
         regRst           => regRst,            -- [in]
         axiReadMaster    => axiReadMaster,     -- [in]
         axiReadSlave     => axiReadSlave,      -- [out]
         axiWriteMaster   => axiWriteMaster,    -- [in]
         axiWriteSlave    => axiWriteSlave,     -- [out]
         configControl    => configControl,     -- [in]
         snapshotControl  => snapshotControl,   -- [in]
         snapshotPrepared => snapshotPrepared,  -- [out]
         configValid      => configValid,       -- [out]
         configPrepared   => configPrepared,    -- [out]
         localMac         => localMac,          -- [in]
         identityChanged  => identityChanged,   -- [out]
         activeConfig     => activeConfig,      -- [out]
         sharedConfig     => sharedConfig,      -- [out]
         rxCounters       => rxCounters,        -- [in]
         status           => portStatus,        -- [in]
         timeoutCount     => timeoutCount,      -- [in]
         publication      => publication);      -- [in]

   U_Policy : entity surf.PtpPortPolicy
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         CLK_FREQ_G     => CLK_FREQ_G)
      port map (
         clk              => clk,                     -- [in]
         rst              => rst,                     -- [in]
         config           => activeConfig,            -- [in]
         applyConfig      => configControl.apply,     -- [in]
         identityChanged  => identityChanged,         -- [in]
         enable           => enable,                  -- [in]
         restart          => restart,                 -- [in]
         linkReady        => linkReady,               -- [in]
         phcStatus        => phcStatus,               -- [in]
         captureAbort     => captureAbort,            -- [in]
         rxQueueOverflow  => rxQueueOverflow,         -- [in]
         rxAbort          => rxAbort,                 -- [in]
         txAbort          => txAbort,                 -- [in]
         rxMessageMaster  => rxMessageMaster,         -- [in]
         idle             => policyIdle,              -- [in]
         admissionEvents  => flowAdmissionEvents,     -- [in]
         responseLog      => responseLog,             -- [in]
         admission        => policyAdmission,         -- [out]
         responseInterval => policyResponseInterval,  -- [out]
         cancel           => abortPort,               -- [out]
         abortRegistered  => abortNow,                -- [out]
         lastSyncTicks    => lastSyncTicks,           -- [out]
         lifecycle        => lifecycle,               -- [out]
         status           => policyStatus);           -- [out]

   U_Flow : entity surf.PtpSyncFlow
      generic map (
         TPD_G                 => TPD_G,
         RST_POLARITY_G        => RST_POLARITY_G,
         RST_ASYNC_G           => RST_ASYNC_G,
         CLK_FREQ_G            => CLK_FREQ_G,
         INGRESS_LATENCY_G     => INGRESS_LATENCY_G,
         EGRESS_LATENCY_G      => EGRESS_LATENCY_G,
         HISTORY_MEMORY_TYPE_G => HISTORY_MEMORY_TYPE_G,
         PAIR_MEMORY_TYPE_G    => PAIR_MEMORY_TYPE_G)
      port map (
         clk               => clk,                  -- [in]
         rst               => rst,                  -- [in]
         activeConfig      => activeConfig,         -- [in]
         phcStatus         => phcStatus,            -- [in]
         rxMessageMaster   => rxMessageMaster,      -- [in]
         rxReady           => rxReady,              -- [out]
         policyStatus      => policyStatus,         -- [in]
         admission         => policyAdmission,      -- [in]
         abortPort         => abortPort,            -- [in]
         abortNow          => abortNow,             -- [in]
         lastSyncTicks     => lastSyncTicks,        -- [in]
         admissionEvents   => flowAdmissionEvents,  -- [out]
         policyIdle        => policyIdle,           -- [out]
         txEnable          => txEnable,             -- [out]
         responseMaster    => flowResponseMaster,   -- [out]
         responseReady     => responseReady,        -- [in]
         responseLog       => responseLog,          -- [out]
         delayMaster       => ledgerSampleMaster,   -- [in]
         delayReady        => delayReady,           -- [out]
         ledgerStatus      => ledgerStatus,         -- [in]
         timeoutCount      => timeoutCount,         -- [in]
         measurementMaster => measurementMaster,    -- [out]
         measurementSlave  => measurementSlave,     -- [in]
         status            => flowStatus,           -- [out]
         publication       => publication,          -- [out]
         divideRequests    => divideRequests,       -- [out]
         divideReady       => divideReady,          -- [in]
         divideCancel      => divideCancel,         -- [out]
         divideResults     => divideResults,        -- [in]
         divideResultReady => divideResultReady);   -- [out]

   U_DelayReqTx : entity surf.PtpDelayReqTx
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk          => clk,                 -- [in]
         rst          => rst,                 -- [in]
         enable       => txEnable,            -- [in]
         cancel       => abortPort,           -- [in]
         ticks        => phcStatus.ticks,     -- [in]
         config       => activeConfig,        -- [in]
         localMac     => localMac,            -- [in]
         interval     => delayReqTxInterval,  -- [in]
         ledgerCancel => abortNow,            -- [in]
         allocate     => allocate,            -- [out]
         allocation   => ledgerAllocation,    -- [in]
         txMaster     => txMaster,            -- [out]
         txSlave      => txSlave);            -- [in]

   U_Ledger : entity surf.PtpTxLedger
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         PACKET_LIFETIME_G => PACKET_LIFETIME_G)
      port map (
         clk              => clk,                   -- [in]
         rst              => rst,                   -- [in]
         restart          => abortNow,              -- [in]
         macResetDone     => macResetDone,          -- [in]
         ticks            => phcStatus.ticks,       -- [in]
         generation       => phcStatus.generation,  -- [in]
         config           => activeConfig,          -- [in]
         allocate         => allocate,              -- [in]
         allocation       => ledgerAllocation,      -- [out]
         wireMaster       => txMessageMaster,       -- [in]
         wireReady        => txMessageReady,        -- [out]
         responseMaster   => flowResponseMaster,    -- [in]
         responseReady    => responseReady,         -- [out]
         sampleMaster     => ledgerSampleMaster,    -- [out]
         sampleReady      => delayReady,            -- [in]
         ledgerStatus     => ledgerStatus,          -- [out]
         responseAccepted => responseAccepted,      -- [out]
         timeoutCount     => timeoutCount,          -- [out]
         rejectedCount    => open);                 -- [out]

end architecture rtl;
