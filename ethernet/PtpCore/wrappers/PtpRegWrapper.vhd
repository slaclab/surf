-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Endpoint AXI-Lite map and real-PHC verification fixture.
--
-- Instantiates the production coordinator, crossbar and the PtpPhcCore,
-- PtpProtocolEngine and PtpServo cores at a configurable base address, using
-- the endpoint's 32 KiB map from PtpRegisterPkg. AXI decode, configuration, snapshots
-- and command ownership are implemented inside the real cores. The protocol
-- inputs are inactive; PHC phase preparation and time advancement remain real.
--
-- Optional direct bank prepare/apply controls let cocotb hold frozen candidates
-- across arbitrary shadow writes. Snapshot inhibition exposes reset recovery
-- while an accepted snapshot waits for a qualified edge. Observation ports
-- report coordination strobes and clock state; stimulus and assertions remain
-- in Python. None of these test controls enter the production endpoint.
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
use surf.PtpRegisterPkg.all;

entity PtpRegWrapper is
   generic (
      AXIL_BASE_ADDR_G : slv(31 downto 0) := (others => '0'));
   port (
      -- All fixture controls and interfaces share clk.
      clk                 : in  sl;
      rst                 : in  sl;
      bankControlOverride : in  sl := '0';
      bankPrepare         : in  sl := '0';
      bankApply           : in  sl := '0';
      snapshotInhibit     : in  sl := '0';
      regRst              : in  sl;
      localMac            : in  slv(47 downto 0);
      axil_awaddr         : in  slv(31 downto 0);
      axil_awvalid        : in  sl;
      axil_awready        : out sl;
      axil_wdata          : in  slv(31 downto 0);
      axil_wstrb          : in  slv(3 downto 0);
      axil_wvalid         : in  sl;
      axil_wready         : out sl;
      axil_bresp          : out slv(1 downto 0);
      axil_bvalid         : out sl;
      axil_bready         : in  sl;
      axil_araddr         : in  slv(31 downto 0);
      axil_arvalid        : in  sl;
      axil_arready        : out sl;
      axil_rdata          : out slv(31 downto 0);
      axil_rresp          : out slv(1 downto 0);
      axil_rvalid         : out sl;
      axil_rready         : in  sl;
      activeEnable        : out sl;
      activeServo         : out sl;
      configApply         : out sl;
      configRestart       : out sl;
      configPrepare       : out sl;
      snapshotCapture     : out sl;
      timeSeconds         : out slv(47 downto 0);
      timeNanoseconds     : out slv(31 downto 0);
      timeFraction        : out slv(31 downto 0);
      timeTicks           : out slv(63 downto 0);
      timeGeneration      : out slv(31 downto 0);
      timeValid           : out sl;
      irq                 : out sl);
end entity PtpRegWrapper;

architecture rtl of PtpRegWrapper is

   constant TPD_C             : time             := 1 ns;
   constant RST_POLARITY_C    : sl               := '1';
   constant RST_ASYNC_C       : boolean          := false;
   constant CLK_FREQ_C        : positive         := 125000000;
   constant PACKET_LIFETIME_C : positive         := 5000;
   constant INGRESS_LATENCY_C : slv(63 downto 0) := x"FFFFFFFFFFFF0000";
   constant EGRESS_LATENCY_C  : slv(63 downto 0) := x"0000000000020000";
   signal resetN              : sl;
   signal axiReadMaster        : AxiLiteReadMasterType;
   signal axiReadSlave         : AxiLiteReadSlaveType;
   signal axiWriteMaster       : AxiLiteWriteMasterType;
   signal axiWriteSlave        : AxiLiteWriteSlaveType;
   -- Same slot order and offsets as PtpEndpoint.
   constant NUM_AXIL_MASTERS_C   : positive := PTP_ENDPOINT_AXIL_MASTERS_C;
   constant CONTROL_AXIL_INDEX_C : natural  := PTP_ENDPOINT_CONTROL_INDEX_C;
   constant PHC_AXIL_INDEX_C     : natural  := PTP_ENDPOINT_PHC_INDEX_C;
   constant PORT_AXIL_INDEX_C    : natural  := PTP_ENDPOINT_PORT_INDEX_C;
   constant SERVO_AXIL_INDEX_C   : natural  := PTP_ENDPOINT_SERVO_INDEX_C;
   constant AXIL_CONFIG_C        : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) :=
      ptpEndpointAxilConfig(AXIL_BASE_ADDR_G);
   signal readMasters           : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal readSlaves            : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal writeMasters          : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal writeSlaves           : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axiReset              : sl;
   signal snapshotAbort         : sl;
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
   signal phcConfigPrepared     : sl;
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
   signal bankConfigControl     : PtpConfigControlType;
   signal measurementMaster     : PtpMeasurementMasterType;
   signal measurementSlave      : PtpMeasurementSlaveType;
   signal portStatus            : PtpPortStatusType;
   signal portLifecycle         : PtpPortLifecycleType;
   -- Match the endpoint: the servo's SECOND converter is private, as is the
   -- PHC core's.
   signal secondReady       : slv(0 downto 0);
   signal secondCancel      : slv(0 downto 0);
   signal secondResultReady : slv(0 downto 0);
   signal divideReady       : slv(1 downto 0);
   signal divideCancel      : slv(1 downto 0);
   signal divideResultReady : slv(1 downto 0);

   signal protocolEngineRxMessageMaster : PtpRxMessageMasterType;
   signal protocolEngineTxMessageMaster : PtpRxMessageMasterType;

   signal secondRequests : PtpConstDivideRequestArray(1-1 downto 0)(operand(128-1 downto 0));
   signal secondResults  : PtpConstDivideResultArray(1-1 downto 0)(value(128-1 downto 0), remainder(128-1 downto 0));
   signal divideRequests : PtpDivideRequestArray(2-1 downto 0)(operandB(80-1 downto 0));
   signal divideResults  : PtpDivideResultArray(2-1 downto 0);

begin

   protocolEngineRxMessageMaster <=
   (
      valid => '0',
      data  => PTP_RX_MESSAGE_INIT_C
   );
   protocolEngineTxMessageMaster <=
   (
      valid => '0',
      data  => PTP_RX_MESSAGE_INIT_C
   );

   U_Second : entity surf.PtpSecondService
      generic map (
         NUM_CLIENTS_G => 1,
         WIDTH_G       => 128)
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

   assert AXIL_BASE_ADDR_G(PTP_ENDPOINT_AXIL_APERTURE_BITS_C-1 downto 0) = toSlv(0, PTP_ENDPOINT_AXIL_APERTURE_BITS_C)
      report "PTP AXI-Lite base address must be 32 KiB aligned" severity failure;
   -- Only fixture-specific combinational overrides live here. The production
   -- controller owns reset distribution and registered restart/event timing.
   comb : process (bankControlOverride, bankPrepare, bankApply, configControl, abortCapture,
                   snapshotInhibit) is
      variable bankControlNow   : PtpConfigControlType;
      variable snapshotAbortNow : sl;
   begin
      bankControlNow := configControl;

      if bankControlOverride = '1' then
         bankControlNow.prepare := bankPrepare;
         bankControlNow.apply   := bankApply;
      end if;

      snapshotAbortNow  := abortCapture or snapshotInhibit;
      bankConfigControl <= bankControlNow;
      snapshotAbort     <= snapshotAbortNow;
   end process comb;
   resetN          <= not rst;
   activeEnable    <= enable;
   activeServo     <= servoEnable;
   configApply     <= configControl.apply;
   configRestart   <= restart;
   configPrepare   <= configControl.prepare;
   snapshotCapture <= snapshotControl.capture;
   timeSeconds     <= timeValue.seconds;
   timeNanoseconds <= timeValue.nanoseconds;
   timeFraction    <= timeValue.fraction;
   timeTicks       <= status.ticks;
   timeGeneration  <= status.generation;
   timeValid       <= status.timeValid;

   U_Axi : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         ADDR_WIDTH    => 32,
         EN_ERROR_RESP => true,
         HAS_WSTRB     => 1,
         FREQ_HZ       => CLK_FREQ_C)
      port map (
         S_AXI_ACLK      => clk,             -- [in]
         S_AXI_ARESETN   => resetN,          -- [in]
         S_AXI_AWADDR    => axil_awaddr,     -- [in]
         S_AXI_AWPROT    => "000",           -- [in]
         S_AXI_AWVALID   => axil_awvalid,    -- [in]
         S_AXI_AWREADY   => axil_awready,    -- [out]
         S_AXI_WDATA     => axil_wdata,      -- [in]
         S_AXI_WSTRB     => axil_wstrb,      -- [in]
         S_AXI_WVALID    => axil_wvalid,     -- [in]
         S_AXI_WREADY    => axil_wready,     -- [out]
         S_AXI_BRESP     => axil_bresp,      -- [out]
         S_AXI_BVALID    => axil_bvalid,     -- [out]
         S_AXI_BREADY    => axil_bready,     -- [in]
         S_AXI_ARADDR    => axil_araddr,     -- [in]
         S_AXI_ARPROT    => "000",           -- [in]
         S_AXI_ARVALID   => axil_arvalid,    -- [in]
         S_AXI_ARREADY   => axil_arready,    -- [out]
         S_AXI_RDATA     => axil_rdata,      -- [out]
         S_AXI_RRESP     => axil_rresp,      -- [out]
         S_AXI_RVALID    => axil_rvalid,     -- [out]
         S_AXI_RREADY    => axil_rready,     -- [in]
         axilClk         => open,            -- [out]
         axilRst         => open,            -- [out]
         axilReadMaster  => axiReadMaster,   -- [out]
         axilReadSlave   => axiReadSlave,    -- [in]
         axilWriteMaster => axiWriteMaster,  -- [out]
         axilWriteSlave  => axiWriteSlave);  -- [in]

   U_Xbar : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_C,
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
         TPD_G          => TPD_C,
         RST_POLARITY_G => RST_POLARITY_C,
         RST_ASYNC_G    => RST_ASYNC_C,
         CLK_FREQ_G     => CLK_FREQ_C)
      port map (
         clk                   => clk,                                 -- [in]
         rst                   => rst,                                 -- [in]
         regRst                => regRst,                              -- [in]
         portRst               => '0',                                 -- [in]
         linkReady             => '1',                                 -- [in]
         identityRestart       => portLifecycle.identityRestart,       -- [in]
         axiReadMaster         => readMasters(CONTROL_AXIL_INDEX_C),   -- [in]
         axiReadSlave          => readSlaves(CONTROL_AXIL_INDEX_C),    -- [out]
         axiWriteMaster        => writeMasters(CONTROL_AXIL_INDEX_C),  -- [in]
         axiWriteSlave         => writeSlaves(CONTROL_AXIL_INDEX_C),   -- [out]
         manualBusy            => manualBusy,                          -- [in]
         phcConfigValid        => phcConfigValid,                      -- [in]
         phcConfigPrepared     => phcConfigPrepared,                   -- [in]
         portConfigValid       => portConfigValid,                     -- [in]
         servoConfigValid      => servoConfigValid,                    -- [in]
         portConfigPrepared    => portConfigPrepared,                  -- [in]
         servoConfigPrepared   => servoConfigPrepared,                 -- [in]
         phcSnapshotPrepared   => phcSnapshotPrepared,                 -- [in]
         portSnapshotPrepared  => portSnapshotPrepared,                -- [in]
         servoSnapshotPrepared => servoSnapshotPrepared,               -- [in]
         captureAbort          => snapshotAbort,                       -- [in]
         phcFault              => status.fault,                        -- [in]
         phcDiscontinuity      => status.discontinuity,                -- [in]
         phcCommandError       => status.error,                        -- [in]
         portActive            => portStatus.active,                   -- [in]
         servoState            => servoStatus.state,                   -- [in]
         filterCount           => servoStatus.filterCount,             -- [in]
         announceValid         => portStatus.announceValid,            -- [in]
         axiReset              => axiReset,                            -- [out]
         restart               => restart,                             -- [out]
         rxFlush               => open,                                -- [out]
         enable                => enable,                              -- [out]
         irq                   => irq,                                 -- [out]
         configControl         => configControl,                       -- [out]
         snapshotControl       => snapshotControl);                    -- [out]

   U_PhcCore : entity surf.PtpPhcCore
      generic map (
         TPD_G              => TPD_C,
         RST_POLARITY_G     => RST_POLARITY_C,
         RST_ASYNC_G        => RST_ASYNC_C,
         AXIL_BASE_ADDR_G   => AXIL_CONFIG_C(PHC_AXIL_INDEX_C).baseAddr,
         CLK_FREQ_G         => CLK_FREQ_C,
         COMMON_CLK_G       => true,
         EXT_COMMAND_EN_G   => true,
         EXT_COORDINATION_G => true)
      port map (
         axiReadMaster    => readMasters(PHC_AXIL_INDEX_C),   -- [in]
         axiReadSlave     => readSlaves(PHC_AXIL_INDEX_C),    -- [out]
         axiWriteMaster   => writeMasters(PHC_AXIL_INDEX_C),  -- [in]
         axiWriteSlave    => writeSlaves(PHC_AXIL_INDEX_C),   -- [out]
         clk              => clk,                             -- [in]
         rst              => rst,                             -- [in]
         regRst           => regRst,                          -- [in]
         restart          => restart,                         -- [in]
         commandAbort     => portLifecycle.commandAbort,      -- [in]
         commandMaster    => commandMaster,                   -- [in]
         commandSlave     => commandSlave,                    -- [out]
         clearValid       => clearValid,                      -- [in]
         externalOwner    => servoEnable,                     -- [out]
         configControl    => bankConfigControl,               -- [in]
         snapshotControl  => snapshotControl,                 -- [in]
         configPrepared   => phcConfigPrepared,               -- [out]
         configValid      => phcConfigValid,                  -- [out]
         snapshotPrepared => phcSnapshotPrepared,             -- [out]
         manualBusy       => manualBusy,                      -- [out]
         phcTime          => timeValue,                       -- [out]
         phcStatus        => status,                          -- [out]
         captureAbort     => abortCapture,                    -- [out]
         pps              => open,                            -- [out]
         irq              => open);                           -- [out]

   U_ProtocolEngine : entity surf.PtpProtocolEngine
      generic map (
         TPD_G             => TPD_C,
         RST_POLARITY_G    => RST_POLARITY_C,
         RST_ASYNC_G       => RST_ASYNC_C,
         CLK_FREQ_G        => CLK_FREQ_C,
         PACKET_LIFETIME_G => PACKET_LIFETIME_C,
         INGRESS_LATENCY_G => INGRESS_LATENCY_C,
         EGRESS_LATENCY_G  => EGRESS_LATENCY_C)
      port map (
         clk               => clk,                              -- [in]
         rst               => rst,                              -- [in]
         regRst            => regRst,                           -- [in]
         axiReadMaster     => readMasters(PORT_AXIL_INDEX_C),   -- [in]
         axiReadSlave      => readSlaves(PORT_AXIL_INDEX_C),    -- [out]
         axiWriteMaster    => writeMasters(PORT_AXIL_INDEX_C),  -- [in]
         axiWriteSlave     => writeSlaves(PORT_AXIL_INDEX_C),   -- [out]
         configControl     => bankConfigControl,                -- [in]
         snapshotControl   => snapshotControl,                  -- [in]
         snapshotPrepared  => portSnapshotPrepared,             -- [out]
         configValid       => portConfigValid,                  -- [out]
         configPrepared    => portConfigPrepared,               -- [out]
         enable            => enable,                           -- [in]
         rxCounters        => PTP_RX_COUNTERS_INIT_C,           -- [in]
         sharedConfig      => sharedConfig,                     -- [out]
         restart           => restart,                          -- [in]
         linkReady         => '0',                              -- [in]
         macResetDone      => '0',                              -- [in]
         localMac          => localMac,                         -- [in]
         phcStatus         => status,                           -- [in]
         captureAbort      => abortCapture,                     -- [in]
         rxMessageMaster   => protocolEngineRxMessageMaster,    -- [in]
         rxReady           => open,                             -- [out]
         rxQueueOverflow   => '0',                              -- [in]
         rxAbort           => '0',                              -- [in]
         txMessageMaster   => protocolEngineTxMessageMaster,    -- [in]
         txMessageReady    => open,                             -- [out]
         txAbort           => '0',                              -- [in]
         txMaster          => open,                             -- [out]
         txSlave           => AXI_STREAM_SLAVE_FORCE_C,         -- [in]
         measurementMaster => measurementMaster,                -- [out]
         measurementSlave  => measurementSlave,                 -- [in]
         lifecycle         => portLifecycle,                    -- [out]
         status            => portStatus,                       -- [out]
         divideRequests    => divideRequests,                   -- [out]
         divideReady       => divideReady,                      -- [in]
         divideCancel      => divideCancel,                     -- [out]
         divideResults     => divideResults,                    -- [in]
         divideResultReady => divideResultReady);               -- [out]

   U_Servo : entity surf.PtpServo
      generic map (
         TPD_G          => TPD_C,
         RST_POLARITY_G => RST_POLARITY_C,
         RST_ASYNC_G    => RST_ASYNC_C,
         CLK_FREQ_G     => CLK_FREQ_C)
      port map (
         clk               => clk,                               -- [in]
         rst               => rst,                               -- [in]
         regRst            => regRst,                            -- [in]
         axiReadMaster     => readMasters(SERVO_AXIL_INDEX_C),   -- [in]
         axiReadSlave      => readSlaves(SERVO_AXIL_INDEX_C),    -- [out]
         axiWriteMaster    => writeMasters(SERVO_AXIL_INDEX_C),  -- [in]
         axiWriteSlave     => writeSlaves(SERVO_AXIL_INDEX_C),   -- [out]
         configControl     => bankConfigControl,                 -- [in]
         snapshotControl   => snapshotControl,                   -- [in]
         snapshotPrepared  => servoSnapshotPrepared,             -- [out]
         configValid       => servoConfigValid,                  -- [out]
         configPrepared    => servoConfigPrepared,               -- [out]
         servoEnable       => servoEnable,                       -- [in]
         sharedConfig      => sharedConfig,                      -- [in]
         measurementMaster => measurementMaster,                 -- [in]
         measurementSlave  => measurementSlave,                  -- [out]
         restart           => restart,                           -- [in]
         phcStatus         => status,                            -- [in]
         expireTime        => clearValid,                        -- [out]
         commandMaster     => commandMaster,                     -- [out]
         commandSlave      => commandSlave,                      -- [in]
         status            => servoStatus,                       -- [out]
         secondRequest     => secondRequests(0),                 -- [out]
         secondReady       => secondReady(0),                    -- [in]
         secondCancel      => secondCancel(0),                   -- [out]
         secondResult      => secondResults(0),                  -- [in]
         secondResultReady => secondResultReady(0));             -- [out]

end architecture rtl;
