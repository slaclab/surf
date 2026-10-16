-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Autonomous PTP protocol, clock-control and register subsystem.
--
-- Connects the AXI banks inside PtpPhc, PtpProtocolEngine and PtpServo directly through
-- AxiLiteCrossbar. Each core owns its configuration and snapshot storage.
-- PtpEndpointControl coordinates configuration, snapshots and lifecycle events.
-- Validated RX records and observed TX completion records arrive from the
-- physical frontends. The port produces Delay_Req frames and timing
-- measurements; the servo turns qualified measurements into PHC commands. The
-- surrounding EthMacPtpEndpoint supplies the MAC and physical timestamp
-- adapters.
--
-- TX_AXIS_CONFIG_G selects the private Delay_Req output format. The default
-- eight-byte stream connects directly to the port; other formats use an
-- AxiStreamResize. Only system reset clears that TX stage, so port/register
-- resets leave accepted frames free to drain toward physical transmission.
--
-- PHC-local management arbitrates software and servo commands through
-- acknowledgement, so each response reaches the correct requester. Manual
-- steering requires automatic control to be disabled; PPS remains available
-- in either mode. A disabled servo continues to drain measurements.
--
-- Coordinates protocol restart, stale-work cancellation and clock validity
-- without feeding a PHC command's own capture invalidation back into that
-- command's commit. Port and register resets preserve the PHC; system reset
-- clears the complete subsystem. AXI-Lite status, snapshots, PPS and IRQ
-- expose the resulting time and endpoint state.
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
library surf;
use surf.StdRtlPkg.all;
use surf.PtpMathPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.PtpPkg.all;

entity PtpEndpoint is
   generic (
      AXIL_BASE_ADDR_G  : slv(31 downto 0)    := (others => '0');
      TPD_G             : time                := 1 ns;
      RST_POLARITY_G    : sl                  := '1';
      RST_ASYNC_G       : boolean             := false;
      CLK_FREQ_G        : positive            := 156250000;
      PACKET_LIFETIME_G : positive            := 156250000;
      INGRESS_LATENCY_G : slv(63 downto 0)    := (others => '0');
      EGRESS_LATENCY_G  : slv(63 downto 0)    := (others => '0');
      TX_AXIS_CONFIG_G  : AxiStreamConfigType := PTP_RX_AXIS_CONFIG_C);
   port (
      -- Shared endpoint clock domain and lifecycle controls.
      clk          : in  sl;
      rst          : in  sl;
      regRst       : in  sl := '0';
      portRst      : in  sl := '0';
      linkReady    : in  sl;
      macResetDone : in  sl;
      localMac     : in  slv(47 downto 0);
      -- AXI-Lite management.
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Validated RX records and physical TX completions.
      rxMessageMaster : in  PtpRxMessageMasterType;
      rxReady         : out sl;
      rxQueueOverflow : in  sl := '0';
      rxAbort         : in  sl;
      rxCounters      : in  PtpRxCountersType;
      -- Physical completion producer holds its record through txMessageReady.
      txMessageMaster : in  PtpRxMessageMasterType;
      txMessageReady  : out sl;
      txAbort         : in  sl;
      -- Private Delay_Req stream in TX_AXIS_CONFIG_G format.
      txMaster : out AxiStreamMasterType;
      txSlave  : in  AxiStreamSlaveType;
      -- Live PHC, capture controls and endpoint status.
      phcTime      : out PtpTimeType;
      phcStatus    : out PtpPhcStatusType;
      captureAbort : out sl;
      rxFlush      : out sl;
      pps          : out sl;
      irq          : out sl;
      portActive   : out sl;
      servoState   : out slv(2 downto 0));
end entity PtpEndpoint;

architecture rtl of PtpEndpoint is

   constant NUM_AXIL_MASTERS_C : positive := 4;
   -- Bank order defines the development register offsets within the 16 KiB aperture.
   constant CONTROL_AXIL_INDEX_C : natural := 0;
   constant PHC_AXIL_INDEX_C     : natural := 1;
   constant PORT_AXIL_INDEX_C    : natural := 2;
   constant SERVO_AXIL_INDEX_C   : natural := 3;
   constant AXIL_APERTURE_BITS_C : positive := 14; -- 16 KiB endpoint.
   constant AXIL_BANK_BITS_C     : positive := 12; -- 4 KiB per owner.
   constant AXIL_CONFIG_C        : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) :=
      genAxiLiteConfig(NUM_AXIL_MASTERS_C, AXIL_BASE_ADDR_G, AXIL_APERTURE_BITS_C, AXIL_BANK_BITS_C);
   signal readMasters           : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal readSlaves            : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal writeMasters          : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal writeSlaves           : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axiReset              : sl;
   signal enable                : sl;
   signal servoEnable           : sl;
   signal manualBusy            : sl;
   signal restart               : sl;
   signal sharedConfig          : PtpSharedConfigType;
   signal timeValue             : PtpTimeType;
   signal status                : PtpPhcStatusType;
   signal abortCapture          : sl;
   signal clearValid            : sl;
   signal phcConfigValid        : sl;
   signal portConfigValid       : sl;
   signal servoConfigValid      : sl;
   signal portConfigPrepared    : sl;
   signal servoConfigPrepared   : sl;
   signal configControl         : PtpConfigControlType;
   signal phcSnapshotPrepared   : sl;
   signal portSnapshotPrepared  : sl;
   signal servoSnapshotPrepared : sl;
   signal snapshotControl       : PtpSnapshotControlType;
   signal commandMaster         : PtpPhcCommandMasterType;
   signal commandSlave          : PtpPhcCommandSlaveType;
   signal servoStatus           : PtpServoStatusType;
   signal measurementMaster     : PtpMeasurementMasterType;
   signal measurementSlave      : PtpMeasurementSlaveType;
   signal portStatus            : PtpPortStatusType;
   signal portLifecycle         : PtpPortLifecycleType;
   signal portTxMaster          : AxiStreamMasterType;
   signal portTxSlave           : AxiStreamSlaveType;
   -- Two narrowly shared arithmetic services. SECOND converts between a Q16
   -- nanosecond scalar and seconds for manual PHC preparation (owner 0) and
   -- the servo (owner 1). The variable divider serves the rate estimator
   -- (owner 0) and the E2E calibration planes (owner 1). Everything else is
   -- local to its client.
   constant SECOND_PHC_C    : natural := 0;
   constant SECOND_SERVO_C  : natural := 1;
   signal secondReady       : slv(1 downto 0);
   signal secondCancel      : slv(1 downto 0);
   signal secondResultReady : slv(1 downto 0);
   signal divideReady       : slv(1 downto 0);
   signal divideCancel      : slv(1 downto 0);
   signal divideResultReady : slv(1 downto 0);

   signal secondRequests : PtpConstDivideRequestArray(2-1 downto 0)(operand(128-1 downto 0));
   signal secondResults  : PtpConstDivideResultArray(2-1 downto 0)(value(128-1 downto 0), remainder(128-1 downto 0));
   signal divideRequests : PtpDivideRequestArray(2-1 downto 0)(operandB(80-1 downto 0));
   signal divideResults  : PtpDivideResultArray(2-1 downto 0);

begin

   U_Second : entity surf.PtpSecondService
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         NUM_CLIENTS_G  => 2,
         WIDTH_G        => 128)
      port map (
         clk         => clk,                 -- [in]
         rst         => rst,                 -- [in]
         cancel      => secondCancel,        -- [in]
         requests    => secondRequests,      -- [in]
         inputReady  => secondReady,         -- [out]
         results     => secondResults,       -- [out]
         resultReady => secondResultReady);  -- [in]

   U_Divide : entity surf.PtpVariableDivide
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         NUM_CLIENTS_G   => 2,
         DIVISOR_WIDTH_G => 80)
      port map (
         clk         => clk,                 -- [in]
         rst         => rst,                 -- [in]
         cancel      => divideCancel,        -- [in]
         requests    => divideRequests,      -- [in]
         inputReady  => divideReady,         -- [out]
         results     => divideResults,       -- [out]
         resultReady => divideResultReady);  -- [in]

   assert AXIL_BASE_ADDR_G(AXIL_APERTURE_BITS_C-1 downto 0) = toSlv(0, AXIL_APERTURE_BITS_C)
      report "PTP AXI-Lite base address must be 16 KiB aligned" severity failure;
   -- Structural forwarding preserves each child's registered boundary.
   phcTime      <= timeValue;
   phcStatus    <= status;
   captureAbort <= abortCapture;
   portActive   <= portStatus.active;
   servoState   <= servoStatus.state;

   U_Xbar : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXIL_MASTERS_C,
         MASTERS_CONFIG_G   => AXIL_CONFIG_C)
      port map (
         axiClk    => clk,       -- [in]
         axiClkRst => axiReset,  -- [in]
         sAxiWriteMasters(0) => axiWriteMaster,  -- [in]
         sAxiWriteSlaves(0)  => axiWriteSlave,   -- [out]
         sAxiReadMasters(0)  => axiReadMaster,   -- [in]
         sAxiReadSlaves(0)   => axiReadSlave,    -- [out]
         mAxiWriteMasters => writeMasters,  -- [out]
         mAxiWriteSlaves  => writeSlaves,   -- [in]
         mAxiReadMasters  => readMasters,   -- [out]
         mAxiReadSlaves   => readSlaves);   -- [in]

   U_Control : entity surf.PtpEndpointControl
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         CLK_FREQ_G     => CLK_FREQ_G)
      port map (
         clk                   => clk,                                 -- [in]
         rst                   => rst,                                 -- [in]
         regRst                => regRst,                              -- [in]
         portRst               => portRst,                             -- [in]
         linkReady             => linkReady,                           -- [in]
         identityRestart       => portLifecycle.identityRestart,       -- [in]
         axiReadMaster         => readMasters(CONTROL_AXIL_INDEX_C),   -- [in]
         axiReadSlave          => readSlaves(CONTROL_AXIL_INDEX_C),    -- [out]
         axiWriteMaster        => writeMasters(CONTROL_AXIL_INDEX_C),  -- [in]
         axiWriteSlave         => writeSlaves(CONTROL_AXIL_INDEX_C),   -- [out]
         manualBusy            => manualBusy,                          -- [in]
         phcConfigValid        => phcConfigValid,                      -- [in]
         portConfigValid       => portConfigValid,                     -- [in]
         servoConfigValid      => servoConfigValid,                    -- [in]
         portConfigPrepared    => portConfigPrepared,                  -- [in]
         servoConfigPrepared   => servoConfigPrepared,                 -- [in]
         phcSnapshotPrepared   => phcSnapshotPrepared,                 -- [in]
         portSnapshotPrepared  => portSnapshotPrepared,                -- [in]
         servoSnapshotPrepared => servoSnapshotPrepared,               -- [in]
         captureAbort          => abortCapture,                        -- [in]
         phcFault              => status.fault,                        -- [in]
         phcDiscontinuity      => status.discontinuity,                -- [in]
         phcCommandError       => status.error,                        -- [in]
         portActive            => portStatus.active,                   -- [in]
         servoState            => servoStatus.state,                   -- [in]
         filterCount           => servoStatus.filterCount,             -- [in]
         announceValid         => portStatus.announceValid,            -- [in]
         axiReset              => axiReset,                            -- [out]
         restart               => restart,                             -- [out]
         rxFlush               => rxFlush,                             -- [out]
         enable                => enable,                              -- [out]
         servoEnable           => servoEnable,                         -- [out]
         irq                   => irq,                                 -- [out]
         configControl         => configControl,                       -- [out]
         snapshotControl       => snapshotControl);                    -- [out]

   U_Phc : entity surf.PtpPhc
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         CLK_FREQ_G     => CLK_FREQ_G)
      port map (
         clk               => clk,                               -- [in]
         rst               => rst,                               -- [in]
         regRst            => regRst,                            -- [in]
         axiReadMaster     => readMasters(PHC_AXIL_INDEX_C),     -- [in]
         axiReadSlave      => readSlaves(PHC_AXIL_INDEX_C),      -- [out]
         axiWriteMaster    => writeMasters(PHC_AXIL_INDEX_C),    -- [in]
         axiWriteSlave     => writeSlaves(PHC_AXIL_INDEX_C),     -- [out]
         configControl     => configControl,                     -- [in]
         snapshotControl   => snapshotControl,                   -- [in]
         snapshotPrepared  => phcSnapshotPrepared,               -- [out]
         configValid       => phcConfigValid,                    -- [out]
         servoEnable       => servoEnable,                       -- [in]
         restart           => restart,                           -- [in]
         portCommandAbort  => portLifecycle.commandAbort,        -- [in]
         manualBusy        => manualBusy,                        -- [out]
         clearValid        => clearValid,                        -- [in]
         phcTime           => timeValue,                         -- [out]
         status            => status,                            -- [out]
         pps               => pps,                               -- [out]
         captureAbort      => abortCapture,                      -- [out]
         commandMaster     => commandMaster,                     -- [in]
         commandSlave      => commandSlave,                      -- [out]
         secondRequest     => secondRequests(SECOND_PHC_C),      -- [out]
         secondReady       => secondReady(SECOND_PHC_C),         -- [in]
         secondCancel      => secondCancel(SECOND_PHC_C),        -- [out]
         secondResult      => secondResults(SECOND_PHC_C),       -- [in]
         secondResultReady => secondResultReady(SECOND_PHC_C));  -- [out]

   U_ProtocolEngine : entity surf.PtpProtocolEngine
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         CLK_FREQ_G        => CLK_FREQ_G,
         PACKET_LIFETIME_G => PACKET_LIFETIME_G,
         INGRESS_LATENCY_G => INGRESS_LATENCY_G,
         EGRESS_LATENCY_G  => EGRESS_LATENCY_G)
      port map (
         clk               => clk,                              -- [in]
         rst               => rst,                              -- [in]
         regRst            => regRst,                           -- [in]
         axiReadMaster     => readMasters(PORT_AXIL_INDEX_C),   -- [in]
         axiReadSlave      => readSlaves(PORT_AXIL_INDEX_C),    -- [out]
         axiWriteMaster    => writeMasters(PORT_AXIL_INDEX_C),  -- [in]
         axiWriteSlave     => writeSlaves(PORT_AXIL_INDEX_C),   -- [out]
         configControl     => configControl,                    -- [in]
         snapshotControl   => snapshotControl,                  -- [in]
         snapshotPrepared  => portSnapshotPrepared,             -- [out]
         configValid       => portConfigValid,                  -- [out]
         configPrepared    => portConfigPrepared,               -- [out]
         enable            => enable,                           -- [in]
         rxCounters        => rxCounters,                       -- [in]
         sharedConfig      => sharedConfig,                     -- [out]
         restart           => restart,                          -- [in]
         linkReady         => linkReady,                        -- [in]
         macResetDone      => macResetDone,                     -- [in]
         localMac          => localMac,                         -- [in]
         phcStatus         => status,                           -- [in]
         captureAbort      => abortCapture,                     -- [in]
         rxMessageMaster   => rxMessageMaster,                  -- [in]
         rxReady           => rxReady,                          -- [out]
         rxQueueOverflow   => rxQueueOverflow,                  -- [in]
         rxAbort           => rxAbort,                          -- [in]
         txMessageMaster   => txMessageMaster,                  -- [in]
         txMessageReady    => txMessageReady,                   -- [out]
         txAbort           => txAbort,                          -- [in]
         txMaster          => portTxMaster,                     -- [out]
         txSlave           => portTxSlave,                      -- [in]
         measurementMaster => measurementMaster,                -- [out]
         measurementSlave  => measurementSlave,                 -- [in]
         lifecycle         => portLifecycle,                    -- [out]
         status            => portStatus,                       -- [out]
         divideRequests    => divideRequests,                   -- [out]
         divideReady       => divideReady,                      -- [in]
         divideCancel      => divideCancel,                     -- [out]
         divideResults     => divideResults,                    -- [in]
         divideResultReady => divideResultReady);               -- [out]

   -- Preserve the original ready/valid path when no format conversion is needed.
   GEN_TX_BYPASS : if TX_AXIS_CONFIG_G = PTP_RX_AXIS_CONFIG_C generate
      txMaster    <= portTxMaster;
      portTxSlave <= txSlave;
   end generate GEN_TX_BYPASS;
   GEN_TX_RESIZE : if TX_AXIS_CONFIG_G /= PTP_RX_AXIS_CONFIG_C generate
      -- This stage belongs to the physical TX pipeline. Logical restart and
      -- AXI-only reset must let queued data drain; only system reset clears it.
      U_TxResize : entity surf.AxiStreamResize
         generic map (
            TPD_G               => TPD_G,
            RST_POLARITY_G      => RST_POLARITY_G,
            RST_ASYNC_G         => RST_ASYNC_G,
            SLAVE_AXI_CONFIG_G  => PTP_RX_AXIS_CONFIG_C,
            MASTER_AXI_CONFIG_G => TX_AXIS_CONFIG_G)
         port map (
            axisClk     => clk,           -- [in]
            axisRst     => rst,           -- [in]
            sAxisMaster => portTxMaster,  -- [in]
            sAxisSlave  => portTxSlave,   -- [out]
            mAxisMaster => txMaster,      -- [out]
            mSideBand   => open,          -- [out]
            mAxisSlave  => txSlave);      -- [in]

   end generate GEN_TX_RESIZE;

   U_Servo : entity surf.PtpServo
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         CLK_FREQ_G     => CLK_FREQ_G)
      port map (
         clk               => clk,                                 -- [in]
         rst               => rst,                                 -- [in]
         regRst            => regRst,                              -- [in]
         axiReadMaster     => readMasters(SERVO_AXIL_INDEX_C),     -- [in]
         axiReadSlave      => readSlaves(SERVO_AXIL_INDEX_C),      -- [out]
         axiWriteMaster    => writeMasters(SERVO_AXIL_INDEX_C),    -- [in]
         axiWriteSlave     => writeSlaves(SERVO_AXIL_INDEX_C),     -- [out]
         configControl     => configControl,                       -- [in]
         snapshotControl   => snapshotControl,                     -- [in]
         snapshotPrepared  => servoSnapshotPrepared,               -- [out]
         configValid       => servoConfigValid,                    -- [out]
         configPrepared    => servoConfigPrepared,                 -- [out]
         servoEnable       => servoEnable,                         -- [in]
         sharedConfig      => sharedConfig,                        -- [in]
         measurementMaster => measurementMaster,                   -- [in]
         measurementSlave  => measurementSlave,                    -- [out]
         restart           => restart,                             -- [in]
         phcStatus         => status,                              -- [in]
         expireTime        => clearValid,                          -- [out]
         commandMaster     => commandMaster,                       -- [out]
         commandSlave      => commandSlave,                        -- [in]
         status            => servoStatus,                         -- [out]
         secondRequest     => secondRequests(SECOND_SERVO_C),      -- [out]
         secondReady       => secondReady(SECOND_SERVO_C),         -- [in]
         secondCancel      => secondCancel(SECOND_SERVO_C),        -- [out]
         secondResult      => secondResults(SECOND_SERVO_C),       -- [in]
         secondResultReady => secondResultReady(SECOND_SERVO_C));  -- [out]

end architecture rtl;
