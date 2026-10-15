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
      rxMessage       : in  PtpRxMessageType;
      rxValid         : in  sl;
      rxReady         : out sl;
      rxQueueOverflow : in  sl := '0';
      rxAbort         : in  sl;
      -- Physical completion producer holds its record through txMessageReady.
      txMessage         : in  PtpRxMessageType;
      txValid           : in  sl;
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
      divideValid       : out slv(1 downto 0);
      divideReady       : in  slv(1 downto 0)         := (others => '0');
      divideOperandA    : out Slv128Array(1 downto 0);
      divideOperandB    : out slv(159 downto 0);
      divideCancel      : out slv(1 downto 0);
      divideResultValid : in  slv(1 downto 0)         := (others => '0');
      divideResultReady : out slv(1 downto 0);
      divideResultValue : in  Slv128Array(1 downto 0) := (others => (others => '0'));
      divideResultError : in  slv(1 downto 0)         := (others => '0'));
end entity PtpProtocolEngine;

architecture rtl of PtpProtocolEngine is

   signal activeConfig : PtpPortConfigType;
   signal identityChanged : sl;
   signal policyStatus : PtpPortStatusType;
   signal flowStatus : PtpPortStatusType;
   signal portStatus : PtpPortStatusType;
   signal publication : PtpPublicationType;
   signal policyValid : sl;
   signal policyFlags : slv(15 downto 0);
   signal announceValid : sl;
   signal intervalValid : sl;
   signal responseIntervalValid : sl;
   signal responseIntervalTicks : slv(63 downto 0);
   signal abortPort : sl;
   signal abortNow : sl;
   signal lastSyncTicks : slv(63 downto 0);
   signal syncAdmitted : sl;
   signal announceAdmitted : sl;
   signal sampleAccepted : sl;
   signal sampleTicks : slv(63 downto 0);
   signal policyIdle : sl;
   signal txEnable : sl;
   signal txIntervalValid : sl;
   signal allocate : sl;
   signal allocateReady : sl;
   signal allocateSequence : slv(15 downto 0);
   signal response : PtpRxMessageType;
   signal responseValid : sl;
   signal responseReady : sl;
   signal responseLog : slv(7 downto 0);
   signal responseAccepted : sl;
   signal delaySample : PtpDelaySampleType;
   signal delayValid : sl;
   signal delayReady : sl;
   signal ledgerStatus : slv(31 downto 0);
   signal timeoutCount : slv(31 downto 0);

begin

   -- Compose registered fields without introducing another sampling edge.
   status <= portStatus;
   portStatus.active <= policyStatus.active;
   portStatus.announceValid <= policyStatus.announceValid;
   portStatus.announceBody <= policyStatus.announceBody;
   portStatus.grandmasterIdentity <= policyStatus.grandmasterIdentity;
   portStatus.announceFlags <= policyStatus.announceFlags;
   portStatus.utcOffset <= policyStatus.utcOffset;
   portStatus.ratioValid <= flowStatus.ratioValid;
   portStatus.rejectedCount <= flowStatus.rejectedCount;
   portStatus.syncCount <= flowStatus.syncCount;
   portStatus.delayCount <= flowStatus.delayCount;
   portStatus.exchange <= flowStatus.exchange;
   portStatus.ledgerStatus <= flowStatus.ledgerStatus;
   portStatus.timeoutCount <= flowStatus.timeoutCount;
   txIntervalValid <= responseAccepted and responseIntervalValid;

   U_Reg : entity surf.PtpProtocolReg
      generic map (
         TPD_G => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G => RST_ASYNC_G,
         CLK_FREQ_G => CLK_FREQ_G,
         PACKET_LIFETIME_G => PACKET_LIFETIME_G,
         INGRESS_LATENCY_G => INGRESS_LATENCY_G,
         EGRESS_LATENCY_G => EGRESS_LATENCY_G)
      port map (
         clk => clk,
         rst => rst,
         regRst => regRst,
         axiReadMaster => axiReadMaster,
         axiReadSlave => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave => axiWriteSlave,
         configControl => configControl,
         snapshotControl => snapshotControl,
         snapshotPrepared => snapshotPrepared,
         configValid => configValid,
         configPrepared => configPrepared,
         localMac => localMac,
         identityChanged => identityChanged,
         activeConfig => activeConfig,
         sharedConfig => sharedConfig,
         rxCounters => rxCounters,
         status => portStatus,
         timeoutCount => timeoutCount,
         publication => publication);

   U_Policy : entity surf.PtpPortPolicy
      generic map (
         TPD_G => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G => RST_ASYNC_G,
         CLK_FREQ_G => CLK_FREQ_G)
      port map (
         clk => clk,
         rst => rst,
         config => activeConfig,
         applyConfig => configControl.apply,
         identityChanged => identityChanged,
         enable => enable,
         restart => restart,
         linkReady => linkReady,
         phcStatus => phcStatus,
         captureAbort => captureAbort,
         rxQueueOverflow => rxQueueOverflow,
         rxAbort => rxAbort,
         txAbort => txAbort,
         rxMessage => rxMessage,
         rxValid => rxValid,
         idle => policyIdle,
         syncAdmitted => syncAdmitted,
         announceAdmitted => announceAdmitted,
         sampleAccepted => sampleAccepted,
         sampleTicks => sampleTicks,
         responseLog => responseLog,
         policyValid => policyValid,
         policyFlags => policyFlags,
         announceValid => announceValid,
         intervalValid => intervalValid,
         responseIntervalValid => responseIntervalValid,
         responseIntervalTicks => responseIntervalTicks,
         cancel => abortPort,
         abortRegistered => abortNow,
         lastSyncTicks => lastSyncTicks,
         lifecycle => lifecycle,
         status => policyStatus);

   U_Flow : entity surf.PtpSyncFlow
      generic map (
         TPD_G => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G => RST_ASYNC_G,
         CLK_FREQ_G => CLK_FREQ_G,
         INGRESS_LATENCY_G => INGRESS_LATENCY_G,
         EGRESS_LATENCY_G => EGRESS_LATENCY_G,
         HISTORY_MEMORY_TYPE_G => HISTORY_MEMORY_TYPE_G,
         PAIR_MEMORY_TYPE_G => PAIR_MEMORY_TYPE_G)
      port map (
         clk => clk,
         rst => rst,
         activeConfig => activeConfig,
         phcStatus => phcStatus,
         rxMessage => rxMessage,
         rxValid => rxValid,
         rxReady => rxReady,
         policyStatus => policyStatus,
         policyValid => policyValid,
         policyFlags => policyFlags,
         announceValid => announceValid,
         intervalValid => intervalValid,
         abortPort => abortPort,
         abortNow => abortNow,
         lastSyncTicks => lastSyncTicks,
         syncAdmitted => syncAdmitted,
         announceAdmitted => announceAdmitted,
         sampleAccepted => sampleAccepted,
         sampleTicks => sampleTicks,
         policyIdle => policyIdle,
         txEnable => txEnable,
         response => response,
         responseValid => responseValid,
         responseReady => responseReady,
         responseLog => responseLog,
         delaySample => delaySample,
         delayValid => delayValid,
         delayReady => delayReady,
         ledgerStatus => ledgerStatus,
         timeoutCount => timeoutCount,
         measurementMaster => measurementMaster,
         measurementSlave => measurementSlave,
         status => flowStatus,
         publication => publication,
         divideValid => divideValid,
         divideReady => divideReady,
         divideOperandA => divideOperandA,
         divideOperandB => divideOperandB,
         divideCancel => divideCancel,
         divideResultValid => divideResultValid,
         divideResultReady => divideResultReady,
         divideResultValue => divideResultValue,
         divideResultError => divideResultError);

   U_DelayReqTx : entity surf.PtpDelayReqTx
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk              => clk,                         -- [in]
         rst              => rst,                         -- [in]
         enable           => txEnable,                    -- [in]
         cancel           => abortPort,                    -- [in]
         ticks            => phcStatus.ticks,             -- [in]
         config           => activeConfig,  -- [in]
         localMac         => localMac,                    -- [in]
         intervalValid    => txIntervalValid,             -- [in]
         intervalTicks    => responseIntervalTicks,             -- [in]
         ledgerCancel     => abortNow,                    -- [in]
         allocate         => allocate,                    -- [out]
         allocateReady    => allocateReady,               -- [in]
         allocateSequence => allocateSequence,            -- [in]
         txMaster         => txMaster,                    -- [out]
         txSlave          => txSlave);                    -- [in]

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
         config           => activeConfig,        -- [in]
         allocate         => allocate,              -- [in]
         allocateReady    => allocateReady,         -- [out]
         allocateSequence => allocateSequence,      -- [out]
         wireMessage      => txMessage,             -- [in]
         wireReady        => txMessageReady,        -- [out]
         wireValid        => txValid,               -- [in]
         response         => response,            -- [in]
         responseReady    => responseReady,         -- [out]
         responseValid    => responseValid,         -- [in]
         sample           => delaySample,           -- [out]
         sampleValid      => delayValid,            -- [out]
         sampleReady      => delayReady,            -- [in]
         timeoutCount     => timeoutCount,          -- [out]
         ledgerStatus     => ledgerStatus,          -- [out]
         responseAccepted => responseAccepted,      -- [out]
         rejectedCount    => open);       -- [out]

end architecture rtl;
