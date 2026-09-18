-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Four-bank AXI-Lite and real-PHC verification fixture.
--
-- Instantiates the production coordinator, crossbar and PtpPhc/PtpPort/PtpServo
-- cores at a configurable base address. AXI decode, configuration, snapshots
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
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.PtpPkg.all;

entity PtpRegWrapper is
   generic (
      AXIL_BASE_ADDR_G : slv(31 downto 0) := (others => '0'));
   port (
      -- All fixture controls and interfaces share clk.
      clk                  : in  sl;
      rst                  : in  sl;
      bankControlOverride  : in  sl := '0';
      bankPrepare          : in  sl := '0';
      bankApply            : in  sl := '0';
      snapshotInhibit      : in  sl := '0';
      regRst               : in  sl;
      localMac             : in  slv(47 downto 0);
      axil_awaddr          : in  slv(31 downto 0);
      axil_awvalid         : in  sl;
      axil_awready         : out sl;
      axil_wdata           : in  slv(31 downto 0);
      axil_wstrb           : in  slv(3 downto 0);
      axil_wvalid          : in  sl;
      axil_wready          : out sl;
      axil_bresp           : out slv(1 downto 0);
      axil_bvalid          : out sl;
      axil_bready          : in  sl;
      axil_araddr          : in  slv(31 downto 0);
      axil_arvalid         : in  sl;
      axil_arready         : out sl;
      axil_rdata           : out slv(31 downto 0);
      axil_rresp           : out slv(1 downto 0);
      axil_rvalid          : out sl;
      axil_rready          : in  sl;
      activeEnable         : out sl;
      activeServo          : out sl;
      configRestart        : out sl;
      configPrepare        : out sl;
      snapshotCapture      : out sl;
      timeSeconds          : out slv(47 downto 0);
      timeNanoseconds      : out slv(31 downto 0);
      timeFraction         : out slv(31 downto 0);
      timeTicks            : out slv(63 downto 0);
      timeGeneration       : out slv(31 downto 0);
      timeValid            : out sl;
      irq                  : out sl);
end entity PtpRegWrapper;

architecture rtl of PtpRegWrapper is

   constant TPD_G             : time := 1 ns;
   constant RST_POLARITY_G    : sl := '1';
   constant RST_ASYNC_G       : boolean := false;
   constant CLK_FREQ_G        : positive := 125000000;
   constant PACKET_LIFETIME_G : positive := 5000;
   constant INGRESS_LATENCY_G : slv(63 downto 0) := x"FFFFFFFFFFFF0000";
   constant EGRESS_LATENCY_G  : slv(63 downto 0) := x"0000000000020000";

   signal resetN         : sl;
   signal axiReadMaster  : AxiLiteReadMasterType;
   signal axiReadSlave   : AxiLiteReadSlaveType;
   signal axiWriteMaster : AxiLiteWriteMasterType;
   signal axiWriteSlave  : AxiLiteWriteSlaveType;

   constant NUM_AXIL_MASTERS_C : positive := 4;

   -- Bank order defines the development register offsets within the 16 KiB aperture.
   constant CONTROL_AXIL_INDEX_C : natural := 0;
   constant PHC_AXIL_INDEX_C     : natural := 1;
   constant PORT_AXIL_INDEX_C    : natural := 2;
   constant SERVO_AXIL_INDEX_C   : natural := 3;

   constant AXIL_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) :=
      genAxiLiteConfig(NUM_AXIL_MASTERS_C, AXIL_BASE_ADDR_G, 14, 12);

   signal readMasters   : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal readSlaves    : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal writeMasters  : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal writeSlaves   : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axiReset      : sl;
   signal snapshotAbort : sl;
   signal enable        : sl;
   signal servoEnable   : sl;
   signal manualBusy    : sl;
   signal restart       : sl;
   signal sharedConfig  : PtpSharedConfigType;
   signal timeValue     : PtpTimeType;
   signal status        : PtpPhcStatusType;
   signal abortCapture  : sl;
   signal clearValid    : sl;
   signal events        : slv(3 downto 0);

   signal phcConfigValid   : sl;
   signal portConfigValid  : sl;
   signal servoConfigValid : sl;

   signal configControl     : PtpConfigControlType;
   signal snapshotControl   : PtpSnapshotControlType;
   signal commandMaster     : PtpPhcCommandMasterType;
   signal commandSlave      : PtpPhcCommandSlaveType;
   signal servoStatus       : PtpServoStatusType;
   signal bankConfigControl : PtpConfigControlType;

   signal measurementMaster : PtpMeasurementMasterType;
   signal measurementSlave  : PtpMeasurementSlaveType;
   signal portStatus        : PtpPortStatusType;
   signal portLifecycle     : PtpPortLifecycleType;

begin

   assert AXIL_BASE_ADDR_G(13 downto 0) = toSlv(0, 14)
      report "PTP AXI-Lite base address must be 16 KiB aligned" severity failure;

   comb : process (bankControlOverride, bankPrepare, bankApply, configControl, abortCapture,
                   snapshotInhibit, rst, regRst, portStatus, portLifecycle, status, servoStatus, enable, servoEnable,
                   snapshotControl, timeValue) is
      variable restartPort      : sl;
      variable bankControlNow   : PtpConfigControlType;
      variable snapshotAbortNow : sl;
      variable axiResetNow      : sl;
      variable resetNNow        : sl;
      variable irqEvents        : slv(3 downto 0);
   begin
      -- Normal operation uses the real coordinator. Direct controls let the
      -- fixture hold a candidate while software edits its shadow registers.
      bankControlNow := configControl;
      if bankControlOverride = '1' then
         bankControlNow.prepare := bankPrepare;
         bankControlNow.apply   := bankApply;
      end if;
      snapshotAbortNow := abortCapture or snapshotInhibit;

      -- Match production reset/lifecycle wiring before exposing observations.
      axiResetNow := '0';
      if rst = RST_POLARITY_G or regRst = '1' then
         axiResetNow := '1';
      end if;
      resetNNow                          := not rst;
      restartPort                        := configControl.apply or portLifecycle.identityRestart;
      irqEvents                          := (others => '0');
      irqEvents(PTP_IRQ_PHC_FAULT_C)     := status.fault;
      irqEvents(PTP_IRQ_DISCONTINUITY_C) := status.discontinuity;
      irqEvents(PTP_IRQ_COMMAND_ERROR_C) := status.error;
      if servoStatus.state = PTP_SERVO_FAULT_C then
         irqEvents(PTP_IRQ_SERVO_FAULT_C) := '1';
      end if;

      -- Flatten only the signals required by cocotb's independent checks.
      bankConfigControl <= bankControlNow;
      snapshotAbort     <= snapshotAbortNow;
      axiReset          <= axiResetNow;
      resetN            <= resetNNow;
      restart           <= restartPort;
      events            <= irqEvents;
      activeEnable      <= enable;
      activeServo       <= servoEnable;
      configRestart     <= restartPort;
      configPrepare     <= configControl.prepare;
      snapshotCapture   <= snapshotControl.capture;
      timeSeconds       <= timeValue.seconds;
      timeNanoseconds   <= timeValue.nanoseconds;
      timeFraction      <= timeValue.fraction;
      timeTicks         <= status.ticks;
      timeGeneration    <= status.generation;
      timeValid         <= status.timeValid;
   end process comb;

   U_Axi : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         ADDR_WIDTH    => 32,
         EN_ERROR_RESP => true,
         HAS_WSTRB     => 1,
         FREQ_HZ       => 125000000)
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
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXIL_MASTERS_C,
         MASTERS_CONFIG_G   => AXIL_CONFIG_C)
      port map (
         axiClk              => clk,             -- [in]
         axiClkRst           => axiReset,        -- [in]
         sAxiWriteMasters(0) => axiWriteMaster,  -- [in]
         sAxiWriteSlaves(0)  => axiWriteSlave,   -- [out]
         sAxiReadMasters(0)  => axiReadMaster,   -- [in]
         sAxiReadSlaves(0)   => axiReadSlave,    -- [out]
         mAxiWriteMasters    => writeMasters,    -- [out]
         mAxiWriteSlaves     => writeSlaves,     -- [in]
         mAxiReadMasters     => readMasters,     -- [out]
         mAxiReadSlaves      => readSlaves);     -- [in]

   U_Control : entity surf.PtpReg
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         CLK_FREQ_G     => CLK_FREQ_G)
      port map (
         clk              => clk,                                 -- [in]
         rst              => rst,                                 -- [in]
         regRst           => regRst,                              -- [in]
         axiReadMaster    => readMasters(CONTROL_AXIL_INDEX_C),   -- [in]
         axiReadSlave     => readSlaves(CONTROL_AXIL_INDEX_C),    -- [out]
         axiWriteMaster   => writeMasters(CONTROL_AXIL_INDEX_C),  -- [in]
         axiWriteSlave    => writeSlaves(CONTROL_AXIL_INDEX_C),   -- [out]
         manualBusy       => manualBusy,                          -- [in]
         phcConfigValid   => phcConfigValid,                      -- [in]
         portConfigValid  => portConfigValid,                     -- [in]
         servoConfigValid => servoConfigValid,                    -- [in]
         captureAbort     => snapshotAbort,                       -- [in]
         events           => events,                              -- [in]
         portActive       => portStatus.active,                   -- [in]
         servoState       => servoStatus.state,                   -- [in]
         filterCount      => servoStatus.filterCount,             -- [in]
         announceValid    => portStatus.announceValid,            -- [in]
         enable           => enable,                              -- [out]
         servoEnable      => servoEnable,                         -- [out]
         configControl    => configControl,                       -- [out]
         snapshotControl  => snapshotControl,                     -- [out]
         irq              => irq);                                -- [out]

   U_Phc : entity surf.PtpPhc
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         CLK_FREQ_G     => CLK_FREQ_G)
      port map (
         clk              => clk,                             -- [in]
         rst              => rst,                             -- [in]
         regRst           => regRst,                          -- [in]
         axiReadMaster    => readMasters(PHC_AXIL_INDEX_C),   -- [in]
         axiReadSlave     => readSlaves(PHC_AXIL_INDEX_C),    -- [out]
         axiWriteMaster   => writeMasters(PHC_AXIL_INDEX_C),  -- [in]
         axiWriteSlave    => writeSlaves(PHC_AXIL_INDEX_C),   -- [out]
         configControl    => bankConfigControl,               -- [in]
         snapshotControl  => snapshotControl,                 -- [in]
         configValid      => phcConfigValid,                  -- [out]
         servoEnable      => servoEnable,                     -- [in]
         restart          => restart,                         -- [in]
         portCommandAbort => portLifecycle.commandAbort,      -- [in]
         commandMaster    => commandMaster,                   -- [in]
         commandSlave     => commandSlave,                    -- [out]
         phcTime          => timeValue,                       -- [out]
         status           => status,                          -- [out]
         captureAbort     => abortCapture,                    -- [out]
         clearValid       => clearValid,                      -- [in]
         pps              => open,                            -- [out]
         manualBusy       => manualBusy);                     -- [out]

   U_Port : entity surf.PtpPort
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
         configControl     => bankConfigControl,                -- [in]
         snapshotControl   => snapshotControl,                  -- [in]
         configValid       => portConfigValid,                  -- [out]
         restart           => restart,                          -- [in]
         linkReady         => '0',                              -- [in]
         macResetDone      => '0',                              -- [in]
         localMac          => localMac,                         -- [in]
         phcStatus         => status,                           -- [in]
         measurementMaster => measurementMaster,                -- [out]
         measurementSlave  => measurementSlave,                 -- [in]
         captureAbort      => abortCapture,                     -- [in]
         rxMessage         => PTP_RX_MESSAGE_INIT_C,            -- [in]
         rxValid           => '0',                              -- [in]
         rxReady           => open,                             -- [out]
         rxQueueOverflow   => '0',                              -- [in]
         rxAbort           => '0',                              -- [in]
         txMessage         => PTP_RX_MESSAGE_INIT_C,            -- [in]
         txValid           => '0',                              -- [in]
         txAbort           => '0',                              -- [in]
         txMaster          => open,                             -- [out]
         txSlave           => AXI_STREAM_SLAVE_FORCE_C,         -- [in]
         enable            => enable,                           -- [in]
         rxCounters        => PTP_RX_COUNTERS_INIT_C,           -- [in]
         sharedConfig      => sharedConfig,                     -- [out]
         lifecycle         => portLifecycle,                     -- [out]
         status            => portStatus);                      -- [out]

   U_Servo : entity surf.PtpServo
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         CLK_FREQ_G     => CLK_FREQ_G)
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
         configValid       => servoConfigValid,                  -- [out]
         restart           => restart,                           -- [in]
         phcStatus         => status,                            -- [in]
         measurementMaster => measurementMaster,                 -- [in]
         measurementSlave  => measurementSlave,                  -- [out]
         commandMaster     => commandMaster,                     -- [out]
         commandSlave      => commandSlave,                      -- [in]
         expireTime        => clearValid,                        -- [out]
         status            => servoStatus,                       -- [out]
         servoEnable       => servoEnable,                       -- [in]
         sharedConfig      => sharedConfig);                     -- [in]

end architecture rtl;
