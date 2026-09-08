-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Common-clock Ethernet MAC and autonomous PTP TimeReceiver.
--
-- Integrates EthMacTop with PtpEndpoint and passive GMII/XGMII timestamp
-- paths. RX bytes and their physical start capture pass together through
-- PtpRxTimestampAdapter and PtpRxFrontend, so protocol association does not
-- depend on whether the MAC forwards or drops its own copy. PtpTxTimestampTap
-- observes actual Delay_Req transmission after MAC queuing, arbitration and
-- pause.
--
-- Application traffic uses the primary EMAC stream through PtpPrimaryGuard.
-- The endpoint's private eight-byte Delay_Req stream is resized to the native
-- MAC bypass width; the MAC supplies padding, preamble and FCS. AXI-Lite
-- provides configuration and diagnostics while the PHC and servo run
-- autonomously.
--
-- All interfaces share the continuously running Ethernet/PHC clock: 125 MHz
-- for full-rate GMII or 156.25 MHz for XGMII. Ingress/egress calibration is
-- set by signed Q16 local-PHC-nanosecond generics. System reset must clear the
-- entire TX pipeline; port restart preserves PHC time and drains queued
-- transmissions. MAC reset confirmation and the configured packet-lifetime
-- bound govern safe TX key reuse.
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
use surf.EthMacPkg.all;
use surf.PtpPkg.all;

entity EthMacPtpEndpoint is
   generic (
      TPD_G             : time             := 1 ns;
      RST_POLARITY_G    : sl               := '1';
      PHY_TYPE_G        : string           := "XGMII";
      CLK_FREQ_G        : positive         := 156250000;
      PACKET_LIFETIME_G : positive         := 156250000;
      FIFO_ADDR_WIDTH_G : positive         := 9;
      INGRESS_LATENCY_G : slv(63 downto 0) := (others => '0');
      EGRESS_LATENCY_G  : slv(63 downto 0) := (others => '0'));
   port (
      clk            : in  sl;
      rst            : in  sl;
      portRst        : in  sl                  := '0';
      regRst         : in  sl                  := '0';
      phyReady       : in  sl;
      ethConfig      : in  EthMacConfigType;
      ethStatus      : out EthMacStatusType;
      sAxisMaster    : in  AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
      sAxisSlave     : out AxiStreamSlaveType;
      mAxisMaster    : out AxiStreamMasterType;
      mAxisSlave     : in  AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      xgmiiRxd       : in  slv(63 downto 0)    := (others => '0');
      xgmiiRxc       : in  slv(7 downto 0)     := (others => '1');
      xgmiiTxd       : out slv(63 downto 0);
      xgmiiTxc       : out slv(7 downto 0);
      gmiiRxd        : in  slv(7 downto 0)     := (others => '0');
      gmiiRxDv       : in  sl                  := '0';
      gmiiRxEr       : in  sl                  := '0';
      gmiiTxd        : out slv(7 downto 0);
      gmiiTxEn       : out sl;
      gmiiTxEr       : out sl;
      phcTime        : out PtpTimeType;
      phcStatus      : out PtpPhcStatusType;
      pps            : out sl;
      irq            : out sl;
      portActive     : out sl;
      servoState     : out slv(2 downto 0);
      primaryDropped : out slv(31 downto 0));
end entity EthMacPtpEndpoint;

architecture rtl of EthMacPtpEndpoint is

   signal guardedMaster   : AxiStreamMasterType;
   signal guardedSlave    : AxiStreamSlaveType;
   signal bypMaster       : AxiStreamMasterType;
   signal bypSlave        : AxiStreamSlaveType;
   signal macBypMaster    : AxiStreamMasterType;
   signal macBypSlave     : AxiStreamSlaveType;
   signal rxMaster        : AxiStreamMasterType;
   signal rxCapture       : PtpRxCaptureType;
   signal rxMessage       : PtpRxMessageType;
   signal rxValid         : sl;
   signal rxReady         : sl;
   signal rxQueueOverflow : sl;
   signal rxAbort         : sl;
   signal rxFlush         : sl;
   signal rxCounters      : Slv32Array(0 to 2);
   signal txMessage       : PtpRxMessageType;
   signal txValid         : sl;
   signal txAbort         : sl;
   signal timeValue       : PtpTimeType;
   signal status          : PtpPhcStatusType;
   signal abortCapture    : sl;
   signal txData          : slv(63 downto 0);
   signal txControl       : slv(7 downto 0);
   signal gmiiData        : slv(7 downto 0);
   signal gmiiEnable      : sl;
   signal gmiiError       : sl;
   signal resetDone       : sl := '0';

begin

   assert PHY_TYPE_G = "XGMII" or PHY_TYPE_G = "GMII" report "Unsupported PTP physical interface" severity failure;
   -- System reset reaches the complete MAC TX pipeline and endpoint. Port-only
   -- reset reaches neither MAC FIFO nor PHC. The rising resetDone confirmation
   -- starts the ledger's bounded startup quarantine after each system reset.
   seq : process (clk) is
   begin
      if rising_edge(clk) then
         if rst = RST_POLARITY_G then
            resetDone <= '0' after TPD_G;
         else
            resetDone <= '1' after TPD_G;
         end if;
      end if;
   end process seq;

   U_Guard : entity surf.PtpPrimaryGuard
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G)
      port map (
         clk          => clk,              -- [in]
         rst          => rst,              -- [in]
         sMaster      => sAxisMaster,      -- [in]
         sSlave       => sAxisSlave,       -- [out]
         mMaster      => guardedMaster,    -- [out]
         mSlave       => guardedSlave,     -- [in]
         droppedCount => primaryDropped);  -- [out]

   -- EthMacTop shares one bypass configuration between RX and TX. Its passive
   -- RX FIFO cannot narrow the native stream without backpressure, even when
   -- that redundant RX copy is drained. Resize only our ready/valid TX path.
   -- System reset clears this physical pipeline; port restart must let it drain.
   U_TxResize : entity surf.AxiStreamResize
      generic map (
         TPD_G               => TPD_G,
         RST_POLARITY_G      => RST_POLARITY_G,
         SLAVE_AXI_CONFIG_G  => PTP_RX_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => EMAC_AXIS_CONFIG_C)
      port map (
         axisClk     => clk,           -- [in]
         axisRst     => rst,           -- [in]
         sAxisMaster => bypMaster,     -- [in]
         sAxisSlave  => bypSlave,      -- [out]
         mAxisMaster => macBypMaster,  -- [out]
         mSideBand   => open,          -- [out]
         mAxisSlave  => macBypSlave);  -- [in]

   U_Mac : entity surf.EthMacTop
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         PHY_TYPE_G        => PHY_TYPE_G,
         PAUSE_512BITS_G   => ite(PHY_TYPE_G = "GMII", 64, 8),
         JUMBO_G           => false,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         SYNTH_MODE_G      => "inferred",
         MEMORY_TYPE_G     => "distributed",
         PRIM_COMMON_CLK_G => true,
         PRIM_CONFIG_G     => EMAC_AXIS_CONFIG_C,
         BYP_EN_G          => true,
         BYP_ETH_TYPE_G    => x"F788",
         BYP_COMMON_CLK_G  => true,
         BYP_CONFIG_G      => EMAC_AXIS_CONFIG_C)
      port map (
         ethClk          => clk,                       -- [in]
         ethRst          => rst,                       -- [in]
         ethClkEn        => '1',                       -- [in]
         primClk         => clk,                       -- [in]
         primRst         => rst,                       -- [in]
         ibMacPrimMaster => guardedMaster,             -- [in]
         ibMacPrimSlave  => guardedSlave,              -- [out]
         obMacPrimMaster => mAxisMaster,               -- [out]
         obMacPrimSlave  => mAxisSlave,                -- [in]
         bypClk          => clk,                       -- [in]
         bypRst          => rst,                       -- [in]
         ibMacBypMaster  => macBypMaster,              -- [in]
         ibMacBypSlave   => macBypSlave,               -- [out]
         obMacBypMaster  => open,                      -- [out]
         obMacBypSlave   => AXI_STREAM_SLAVE_FORCE_C,  -- [in]
         xlgmiiTxd       => open,                      -- [out]
         xlgmiiTxc       => open,                      -- [out]
         xgmiiRxd        => xgmiiRxd,                  -- [in]
         xgmiiRxc        => xgmiiRxc,                  -- [in]
         xgmiiTxd        => txData,                    -- [out]
         xgmiiTxc        => txControl,                 -- [out]
         gmiiRxd         => gmiiRxd,                   -- [in]
         gmiiRxDv        => gmiiRxDv,                  -- [in]
         gmiiRxEr        => gmiiRxEr,                  -- [in]
         gmiiTxd         => gmiiData,                  -- [out]
         gmiiTxEn        => gmiiEnable,                -- [out]
         gmiiTxEr        => gmiiError,                 -- [out]
         phyReady        => phyReady,                  -- [in]
         ethConfig       => ethConfig,                 -- [in]
         ethStatus       => ethStatus);                -- [out]

   U_RxAdapter : entity surf.PtpRxTimestampAdapter
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         PHY_TYPE_G        => PHY_TYPE_G,
         INGRESS_LATENCY_G => INGRESS_LATENCY_G)
      port map (
         clk          => clk,                -- [in]
         rst          => rst,                -- [in]
         rxFlush      => rxFlush,            -- [in]
         phyReady     => phyReady,           -- [in]
         generation   => status.generation,  -- [in]
         phcTime      => timeValue,          -- [in]
         phcIncrement => status.increment,   -- [in]
         tickCount    => status.ticks,       -- [in]
         timeValid    => status.timeValid,   -- [in]
         xgmiiRxd     => xgmiiRxd,           -- [in]
         xgmiiRxc     => xgmiiRxc,           -- [in]
         gmiiRxd      => gmiiRxd,            -- [in]
         gmiiRxDv     => gmiiRxDv,           -- [in]
         gmiiRxEr     => gmiiRxEr,           -- [in]
         rxMaster     => rxMaster,           -- [out]
         rxCapture    => rxCapture);         -- [out]

   U_Rx : entity surf.PtpRxFrontend
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G)
      port map (
         clk           => clk,                -- [in]
         rst           => rst,                -- [in]
         rxFlush       => rxFlush,            -- [in]
         generation    => status.generation,  -- [in]
         rxMaster      => rxMaster,           -- [in]
         rxCapture     => rxCapture,          -- [in]
         message       => rxMessage,          -- [out]
         messageValid  => rxValid,            -- [out]
         messageReady  => rxReady,            -- [in]
         rxAbort       => rxAbort,            -- [out]
         queueOverflow => rxQueueOverflow,    -- [out]
         rxEpoch       => open,               -- [out]
         acceptedCount => rxCounters(0),      -- [out]
         droppedCount  => rxCounters(1),      -- [out]
         overflowCount => rxCounters(2));     -- [out]

   U_TxTap : entity surf.PtpTxTimestampTap
      generic map (
         TPD_G            => TPD_G,
         RST_POLARITY_G   => RST_POLARITY_G,
         PHY_TYPE_G       => PHY_TYPE_G,
         EGRESS_LATENCY_G => EGRESS_LATENCY_G)
      port map (
         clk             => clk,           -- [in]
         rst             => rst,           -- [in]
         phyReady        => phyReady,      -- [in]
         phcTime         => timeValue,     -- [in]
         phcStatus       => status,        -- [in]
         captureAbort    => abortCapture,  -- [in]
         xgmiiTxd        => txData,        -- [in]
         xgmiiTxc        => txControl,     -- [in]
         gmiiTxd         => gmiiData,      -- [in]
         gmiiTxEn        => gmiiEnable,    -- [in]
         gmiiTxEr        => gmiiError,     -- [in]
         completion      => txMessage,     -- [out]
         completionValid => txValid,       -- [out]
         completionReady => '1',           -- [in]
         completionAbort => txAbort);      -- [out]

   U_Endpoint : entity surf.PtpEndpoint
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         CLK_FREQ_G        => CLK_FREQ_G,
         PACKET_LIFETIME_G => PACKET_LIFETIME_G,
         INGRESS_LATENCY_G => INGRESS_LATENCY_G,
         EGRESS_LATENCY_G  => EGRESS_LATENCY_G)
      port map (
         clk             => clk,                   -- [in]
         rst             => rst,                   -- [in]
         regRst          => regRst,                -- [in]
         portRst         => portRst,               -- [in]
         linkReady       => phyReady,              -- [in]
         macResetDone    => resetDone,             -- [in]
         localMac        => ethConfig.macAddress,  -- [in]
         axiReadMaster   => axiReadMaster,         -- [in]
         axiReadSlave    => axiReadSlave,          -- [out]
         axiWriteMaster  => axiWriteMaster,        -- [in]
         axiWriteSlave   => axiWriteSlave,         -- [out]
         rxMessage       => rxMessage,             -- [in]
         rxValid         => rxValid,               -- [in]
         rxReady         => rxReady,               -- [out]
         rxAbort         => rxAbort,               -- [in]
         rxQueueOverflow => rxQueueOverflow,       -- [in]
         rxCounters      => rxCounters,            -- [in]
         txMessage       => txMessage,             -- [in]
         txValid         => txValid,               -- [in]
         txAbort         => txAbort,               -- [in]
         txMaster        => bypMaster,             -- [out]
         txSlave         => bypSlave,              -- [in]
         phcTime         => timeValue,             -- [out]
         phcStatus       => status,                -- [out]
         captureAbort    => abortCapture,          -- [out]
         rxFlush         => rxFlush,               -- [out]
         pps             => pps,                   -- [out]
         irq             => irq,                   -- [out]
         portActive      => portActive,            -- [out]
         servoState      => servoState);           -- [out]

   xgmiiTxd  <= txData;
   xgmiiTxc  <= txControl;
   gmiiTxd   <= gmiiData;
   gmiiTxEn  <= gmiiEnable;
   gmiiTxEr  <= gmiiError;
   phcTime   <= timeValue;
   phcStatus <= status;

end architecture rtl;
