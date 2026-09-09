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
      bankControlOverride  : in  sl := '0';
      bankPrepare          : in  sl := '0';
      bankApply            : in  sl := '0';
      snapshotInhibit      : in  sl := '0';
      clk                  : in  sl;
      rst                  : in  sl;
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

   constant AXIL_CONFIG_C : AxiLiteCrossbarMasterConfigArray(3 downto 0) :=
      genAxiLiteConfig(4, AXIL_BASE_ADDR_G, 12, 10);

   signal readMasters   : AxiLiteReadMasterArray(3 downto 0);
   signal readSlaves    : AxiLiteReadSlaveArray(3 downto 0);
   signal writeMasters  : AxiLiteWriteMasterArray(3 downto 0);
   signal writeSlaves   : AxiLiteWriteSlaveArray(3 downto 0);
   signal axiReset      : sl;
   signal snapshotAbort : sl;
   signal configValid   : slv(2 downto 0);
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

   signal configControl     : PtpConfigControlType;
   signal snapshotControl   : PtpSnapshotControlType;
   signal commandMaster     : PtpPhcCommandMasterType;
   signal commandSlave      : PtpPhcCommandSlaveType;
   signal servoStatus       : PtpServoStatusType;
   signal bankConfigControl : PtpConfigControlType;

   signal measurementMaster : PtpMeasurementMasterType;
   signal measurementSlave  : PtpMeasurementSlaveType;
   signal portStatus        : PtpPortStatusType;

begin

   comb : process (bankControlOverride, bankPrepare, bankApply, configControl, abortCapture,
                   snapshotInhibit, rst, regRst, portStatus, status, servoStatus, enable, servoEnable,
                   snapshotControl, timeValue) is
      variable restartPort : sl;
   begin
      -- Normal operation uses the real coordinator. Direct controls let the
      -- fixture hold a candidate while software edits its shadow registers.
      bankConfigControl <= configControl;
      if bankControlOverride = '1' then
         bankConfigControl.prepare <= bankPrepare;
         bankConfigControl.apply   <= bankApply;
      end if;
      snapshotAbort <= abortCapture or snapshotInhibit;

      -- Match production reset/lifecycle wiring before exposing observations.
      axiReset <= '0';
      if rst = RST_POLARITY_G or regRst = '1' then
         axiReset <= '1';
      end if;
      resetN      <= not rst;
      restartPort := configControl.apply or portStatus.identityRestart;
      restart     <= restartPort;
      events(0)   <= status.fault;
      events(1)   <= status.discontinuity;
      events(2)   <= status.error;
      events(3)   <= '0';
      if servoStatus.state = PTP_SERVO_FAULT_C then
         events(3) <= '1';
      end if;

      -- Flatten only the signals required by cocotb's independent checks.
      activeEnable    <= enable;
      activeServo     <= servoEnable;
      configRestart   <= restartPort;
      configPrepare   <= configControl.prepare;
      snapshotCapture <= snapshotControl.capture;
      timeSeconds     <= timeValue.seconds;
      timeNanoseconds <= timeValue.nanoseconds;
      timeFraction    <= timeValue.fraction;
      timeTicks       <= status.ticks;
      timeGeneration  <= status.generation;
      timeValid       <= status.timeValid;
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
         NUM_MASTER_SLOTS_G => 4,
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
         clk             => clk,                       -- [in]
         rst             => rst,                       -- [in]
         regRst          => regRst,                    -- [in]
         axiReadMaster   => readMasters(0),            -- [in]
         axiReadSlave    => readSlaves(0),             -- [out]
         axiWriteMaster  => writeMasters(0),           -- [in]
         axiWriteSlave   => writeSlaves(0),            -- [out]
         manualBusy      => manualBusy,                -- [in]
         configValid     => configValid,               -- [in]
         captureAbort    => snapshotAbort,             -- [in]
         events          => events,                    -- [in]
         portActive      => portStatus.active,         -- [in]
         servoState      => servoStatus.state,         -- [in]
         filterCount     => servoStatus.filterCount,   -- [in]
         announceValid   => portStatus.announceValid,  -- [in]
         enable          => enable,                    -- [out]
         servoEnable     => servoEnable,               -- [out]
         configControl   => configControl,             -- [out]
         snapshotControl => snapshotControl,           -- [out]
         irq             => irq);                      -- [out]

   U_Phc : entity surf.PtpPhc
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         CLK_FREQ_G     => CLK_FREQ_G)
      port map (
         clk              => clk,                      -- [in]
         rst              => rst,                      -- [in]
         regRst           => regRst,                   -- [in]
         axiReadMaster    => readMasters(1),           -- [in]
         axiReadSlave     => readSlaves(1),            -- [out]
         axiWriteMaster   => writeMasters(1),          -- [in]
         axiWriteSlave    => writeSlaves(1),           -- [out]
         configControl    => bankConfigControl,        -- [in]
         snapshotControl  => snapshotControl,          -- [in]
         configValid      => configValid(0),           -- [out]
         servoEnable      => servoEnable,              -- [in]
         restart          => restart,                  -- [in]
         portCommandAbort => portStatus.commandAbort,  -- [in]
         commandMaster    => commandMaster,            -- [in]
         commandSlave     => commandSlave,             -- [out]
         phcTime          => timeValue,                -- [out]
         status           => status,                   -- [out]
         captureAbort     => abortCapture,             -- [out]
         clearValid       => clearValid,               -- [in]
         pps              => open,                     -- [out]
         manualBusy       => manualBusy);              -- [out]

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
         clk               => clk,                       -- [in]
         rst               => rst,                       -- [in]
         regRst            => regRst,                    -- [in]
         axiReadMaster     => readMasters(2),            -- [in]
         axiReadSlave      => readSlaves(2),             -- [out]
         axiWriteMaster    => writeMasters(2),           -- [in]
         axiWriteSlave     => writeSlaves(2),            -- [out]
         configControl     => bankConfigControl,         -- [in]
         snapshotControl   => snapshotControl,           -- [in]
         configValid       => configValid(1),            -- [out]
         restart           => restart,                   -- [in]
         linkReady         => '0',                       -- [in]
         macResetDone      => '0',                       -- [in]
         localMac          => localMac,                  -- [in]
         phcStatus         => status,                    -- [in]
         measurementMaster => measurementMaster,         -- [out]
         measurementSlave  => measurementSlave,          -- [in]
         captureAbort      => abortCapture,              -- [in]
         rxMessage         => PTP_RX_MESSAGE_INIT_C,     -- [in]
         rxValid           => '0',                       -- [in]
         rxReady           => open,                      -- [out]
         rxQueueOverflow   => '0',                       -- [in]
         rxAbort           => '0',                       -- [in]
         txMessage         => PTP_RX_MESSAGE_INIT_C,     -- [in]
         txValid           => '0',                       -- [in]
         txAbort           => '0',                       -- [in]
         txMaster          => open,                      -- [out]
         txSlave           => AXI_STREAM_SLAVE_FORCE_C,  -- [in]
         enable            => enable,                    -- [in]
         rxCounters        => PTP_RX_COUNTERS_INIT_C,    -- [in]
         sharedConfig      => sharedConfig,              -- [out]
         status            => portStatus);               -- [out]

   U_Servo : entity surf.PtpServo
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         CLK_FREQ_G     => CLK_FREQ_G)
      port map (
         clk               => clk,                -- [in]
         rst               => rst,                -- [in]
         regRst            => regRst,             -- [in]
         axiReadMaster     => readMasters(3),     -- [in]
         axiReadSlave      => readSlaves(3),      -- [out]
         axiWriteMaster    => writeMasters(3),    -- [in]
         axiWriteSlave     => writeSlaves(3),     -- [out]
         configControl     => bankConfigControl,  -- [in]
         snapshotControl   => snapshotControl,    -- [in]
         configValid       => configValid(2),     -- [out]
         restart           => restart,            -- [in]
         phcStatus         => status,             -- [in]
         measurementMaster => measurementMaster,  -- [in]
         measurementSlave  => measurementSlave,   -- [out]
         commandMaster     => commandMaster,      -- [out]
         commandSlave      => commandSlave,       -- [in]
         expireTime        => clearValid,         -- [out]
         status            => servoStatus,        -- [out]
         servoEnable       => servoEnable,        -- [in]
         sharedConfig      => sharedConfig);      -- [in]

end architecture rtl;
