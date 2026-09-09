-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Autonomous PTP protocol, clock-control and register subsystem.
--
-- Connects the AXI banks inside PtpPhc, PtpPort and PtpServo directly through
-- AxiLiteCrossbar. Each core owns its configuration and snapshot storage.
-- PtpReg coordinates atomic configuration and snapshots in the shared clock.
-- Validated RX records and observed TX completion records arrive from the
-- physical frontends. The port produces Delay_Req frames and timing
-- measurements; the servo turns qualified measurements into PHC commands. The
-- surrounding EthMacPtpEndpoint supplies the MAC and physical timestamp
-- adapters.
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
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.PtpPkg.all;

entity PtpEndpoint is
   generic (
      AXIL_BASE_ADDR_G  : slv(31 downto 0) := (others => '0');
      TPD_G             : time             := 1 ns;
      RST_POLARITY_G    : sl               := '1';
      RST_ASYNC_G       : boolean          := false;
      CLK_FREQ_G        : positive         := 156250000;
      PACKET_LIFETIME_G : positive         := 156250000;
      INGRESS_LATENCY_G : slv(63 downto 0) := (others => '0');
      EGRESS_LATENCY_G  : slv(63 downto 0) := (others => '0'));
   port (
      clk             : in  sl;
      rst             : in  sl;
      regRst          : in  sl := '0';
      portRst         : in  sl := '0';
      linkReady       : in  sl;
      macResetDone    : in  sl;
      localMac        : in  slv(47 downto 0);
      axiReadMaster   : in  AxiLiteReadMasterType;
      axiReadSlave    : out AxiLiteReadSlaveType;
      axiWriteMaster  : in  AxiLiteWriteMasterType;
      axiWriteSlave   : out AxiLiteWriteSlaveType;
      rxMessage       : in  PtpRxMessageType;
      rxValid         : in  sl;
      rxReady         : out sl;
      rxQueueOverflow : in  sl := '0';
      rxAbort         : in  sl;
      rxCounters      : in  PtpRxCountersType;
      txMessage       : in  PtpRxMessageType;
      txValid         : in  sl;
      txAbort         : in  sl;
      txMaster        : out AxiStreamMasterType;
      txSlave         : in  AxiStreamSlaveType;
      phcTime         : out PtpTimeType;
      phcStatus       : out PtpPhcStatusType;
      captureAbort    : out sl;
      rxFlush         : out sl;
      pps             : out sl;
      irq             : out sl;
      portActive      : out sl;
      servoState      : out slv(2 downto 0));
end entity PtpEndpoint;

architecture rtl of PtpEndpoint is

   constant NUM_AXIL_MASTERS_C : positive := 4;
   constant AXIL_CONFIG_C      : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) :=
      genAxiLiteConfig(NUM_AXIL_MASTERS_C, AXIL_BASE_ADDR_G, 12, 10);

   signal readMasters  : AxiLiteReadMasterArray(3 downto 0);
   signal readSlaves   : AxiLiteReadSlaveArray(3 downto 0);
   signal writeMasters : AxiLiteWriteMasterArray(3 downto 0);
   signal writeSlaves  : AxiLiteWriteSlaveArray(3 downto 0);
   signal axiReset     : sl;
   signal configValid  : slv(2 downto 0);
   signal enable       : sl;
   signal servoEnable  : sl;
   signal manualBusy   : sl;
   signal restart      : sl;
   signal sharedConfig : PtpSharedConfigType;
   signal timeValue    : PtpTimeType;
   signal status       : PtpPhcStatusType;
   signal abortCapture : sl;
   signal clearValid   : sl;
   signal events       : slv(3 downto 0);

   signal configControl   : PtpConfigControlType;
   signal snapshotControl : PtpSnapshotControlType;
   signal commandMaster   : PtpPhcCommandMasterType;
   signal commandSlave    : PtpPhcCommandSlaveType;
   signal servoStatus     : PtpServoStatusType;

   signal measurementMaster : PtpMeasurementMasterType;
   signal measurementSlave  : PtpMeasurementSlaveType;
   signal portStatus        : PtpPortStatusType;

begin

   comb : process (rst, regRst, portRst, configControl, portStatus, linkReady, abortCapture, status,
                   timeValue, servoStatus) is
      variable restartPort : sl;
   begin
      -- Form the bus reset independently of protocol restart. A register-only
      -- reset must leave the PHC, active configuration and TX ownership intact.
      axiReset <= '0';
      if rst = RST_POLARITY_G or regRst = '1' then
         axiReset <= '1';
      end if;

      -- Apply protocol lifecycle changes to the port and physical RX frontend.
      restartPort := portRst or configControl.apply or portStatus.identityRestart;
      restart     <= restartPort;
      rxFlush     <= restartPort or not linkReady or abortCapture;

      -- Aggregate only the event bits needed by the central IRQ register.
      events(0) <= status.fault;
      events(1) <= status.discontinuity;
      events(2) <= status.error;
      events(3) <= '0';
      if servoStatus.state = PTP_SERVO_FAULT_C then
         events(3) <= '1';
      end if;
      phcTime      <= timeValue;
      phcStatus    <= status;
      captureAbort <= abortCapture;
      portActive   <= portStatus.active;
      servoState   <= servoStatus.state;
   end process comb;

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
         clk             => clk,                       -- [in]
         rst             => rst,                       -- [in]
         regRst          => regRst,                    -- [in]
         axiReadMaster   => readMasters(0),            -- [in]
         axiReadSlave    => readSlaves(0),             -- [out]
         axiWriteMaster  => writeMasters(0),           -- [in]
         axiWriteSlave   => writeSlaves(0),            -- [out]
         manualBusy      => manualBusy,                -- [in]
         configValid     => configValid,               -- [in]
         captureAbort    => abortCapture,              -- [in]
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
         configControl    => configControl,            -- [in]
         snapshotControl  => snapshotControl,          -- [in]
         configValid      => configValid(0),           -- [out]
         servoEnable      => servoEnable,              -- [in]
         restart          => restart,                  -- [in]
         portCommandAbort => portStatus.commandAbort,  -- [in]
         commandMaster    => commandMaster,            -- [in]
         commandSlave     => commandSlave,             -- [out]
         manualBusy       => manualBusy,               -- [out]
         clearValid       => clearValid,               -- [in]
         phcTime          => timeValue,                -- [out]
         status           => status,                   -- [out]
         captureAbort     => abortCapture,             -- [out]
         pps              => pps);                     -- [out]

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
         clk               => clk,                -- [in]
         rst               => rst,                -- [in]
         regRst            => regRst,             -- [in]
         axiReadMaster     => readMasters(2),     -- [in]
         axiReadSlave      => readSlaves(2),      -- [out]
         axiWriteMaster    => writeMasters(2),    -- [in]
         axiWriteSlave     => writeSlaves(2),     -- [out]
         configControl     => configControl,      -- [in]
         snapshotControl   => snapshotControl,    -- [in]
         configValid       => configValid(1),     -- [out]
         restart           => restart,            -- [in]
         linkReady         => linkReady,          -- [in]
         macResetDone      => macResetDone,       -- [in]
         localMac          => localMac,           -- [in]
         phcStatus         => status,             -- [in]
         measurementMaster => measurementMaster,  -- [out]
         measurementSlave  => measurementSlave,   -- [in]
         captureAbort      => abortCapture,       -- [in]
         rxMessage         => rxMessage,          -- [in]
         rxValid           => rxValid,            -- [in]
         rxReady           => rxReady,            -- [out]
         rxQueueOverflow   => rxQueueOverflow,    -- [in]
         rxAbort           => rxAbort,            -- [in]
         txMessage         => txMessage,          -- [in]
         txValid           => txValid,            -- [in]
         txAbort           => txAbort,            -- [in]
         txMaster          => txMaster,           -- [out]
         txSlave           => txSlave,            -- [in]
         enable            => enable,             -- [in]
         rxCounters        => rxCounters,         -- [in]
         sharedConfig      => sharedConfig,       -- [out]
         status            => portStatus);        -- [out]

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
         configControl     => configControl,      -- [in]
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
