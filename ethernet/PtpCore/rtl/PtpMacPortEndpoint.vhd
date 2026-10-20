-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Autonomous PTP TimeReceiver on the timing-port MAC.
--
-- The timing-port alternative to EthMacPtpEndpoint, selected by GigEthPtp's
-- MAC_MODE_G. PtpMacPortEthMac supplies the MAC, wire captures and terminal
-- TX outcomes. PtpMacPortRxAdapter turns port RX into the same validated
-- records the RX tap produces, and PtpMacPortTxAdapter turns the engine's
-- Delay_Req stream into port requests and SENT completions into the same
-- observed-Delay_Req records. PtpEndpoint, its register map and the PHC core
-- are unchanged and shared with the tapped build.
--
-- The port is PTP-only: there is no application stream. Admission opens after
-- system reset and is never drained or force-aborted by this controller, so
-- the transport generation stays at its first open value. macResetDone rises
-- one cycle after system reset, which clears the complete MAC and port.
-- Endpoint restart, link loss and PHC steps leave the port running; accepted
-- frames finish through its terminal outcomes. Port status and counters are
-- composition outputs and are readable on the port's own AXI-Lite bank,
-- beside the endpoint aperture. Contract:
-- ethernet/PtpCore/timing-port.md section 11.
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

entity PtpMacPortEndpoint is
   generic (
      AXIL_BASE_ADDR_G  : slv(31 downto 0)       := (others => '0');
      TPD_G             : time                   := 1 ns;
      RST_POLARITY_G    : sl                     := '1';
      PHY_TYPE_G        : string                 := "XGMII";  -- "GMII" or "XGMII"
      TLV_EN_G          : boolean                := true;
      MAX_FRAME_G       : PtpFrameCapacityType   := PTP_ETH_MAX_FRAME_C;
      CLK_FREQ_G        : positive               := 156250000;  -- Hz: 125000000 GMII, 156250000 XGMII.
      PACKET_LIFETIME_G : positive               := 156250000;
      INGRESS_LATENCY_G : slv(63 downto 0)       := (others => '0');
      EGRESS_LATENCY_G  : slv(63 downto 0)       := (others => '0');
      CONTROL_MODE_G    : string                 := "SELECTABLE";
      -- Outstanding Delay_Req requests (port TX table and adapter slots) and
      -- RX frames between wire start and frontend acceptance; 0 selects the
      -- PHY's loss-free RX depth. The RX FIFO depth follows the RX table:
      -- one maximum frame per entry.
      TX_TABLE_DEPTH_G  : positive range 1 to 16 := 4;
      RX_TABLE_DEPTH_G  : natural range 0 to 32  := 0);
   port (
      -- Common Ethernet/PHC clock domain
      clk       : in  sl;
      rst       : in  sl;
      portRst   : in  sl := '0';
      regRst    : in  sl := '0';
      phyReady  : in  sl;
      ethConfig : in  EthMacConfigType;
      ethStatus : out EthMacStatusType;

      -- Endpoint AXI-Lite aperture
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;

      -- Timing-port bank (PtpMacPortReg), also cancelled by regRst
      portAxiReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      portAxiReadSlave   : out AxiLiteReadSlaveType;
      portAxiWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      portAxiWriteSlave  : out AxiLiteWriteSlaveType;

      -- Selected physical interface, synchronous to clk
      xgmiiRxd : in  slv(63 downto 0) := (others => '0');
      xgmiiRxc : in  slv(7 downto 0)  := (others => '1');
      xgmiiTxd : out slv(63 downto 0);
      xgmiiTxc : out slv(7 downto 0);
      gmiiRxd  : in  slv(7 downto 0)  := (others => '0');
      gmiiRxDv : in  sl               := '0';
      gmiiRxEr : in  sl               := '0';
      gmiiTxd  : out slv(7 downto 0);
      gmiiTxEn : out sl;
      gmiiTxEr : out sl;

      -- PHC, endpoint and port status
      phcTime      : out PtpTimeType;
      phcStatus    : out PtpPhcStatusType;
      pps          : out sl;
      irq          : out sl;
      portActive   : out sl;
      servoState   : out slv(2 downto 0);
      portStatus   : out PtpMacPortStatusType;
      portCounters : out PtpMacPortCountersType);
end entity PtpMacPortEndpoint;

architecture rtl of PtpMacPortEndpoint is

   constant RX_DEPTH_C : positive :=
      ite(RX_TABLE_DEPTH_G /= 0, RX_TABLE_DEPTH_G,
          ite(PHY_TYPE_G = "GMII", PTP_MAC_PORT_RX_DEPTH_GMII_C, PTP_MAC_PORT_RX_DEPTH_XGMII_C));

   -- PtpMacPortEthMac RX storage bound: maximum frames plus one terminator
   -- each, at least the FIFO's minimum address width.
   constant RX_FIFO_ADDR_WIDTH_C : positive :=
      maximum(9, bitSize(RX_DEPTH_C*((EMAC_TIMING_MAX_FRAME_C+15)/16+1)-1));

   type RegType is record
      resetDone : sl;
      control   : PtpMacPortControlType;
   end record;

   constant REG_INIT_C : RegType := (
      resetDone => '0',
      control   => PTP_MAC_PORT_CONTROL_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal timeValue        : PtpTimeType;
   signal status           : PtpPhcStatusType;
   signal abortCapture     : sl;
   signal rxFlush          : sl;
   signal portStatusInt    : PtpMacPortStatusType;
   signal portTxMaster     : PtpMacPortTxMasterType;
   signal portTxSlave      : AxiStreamSlaveType;
   signal portCompletion   : PtpMacPortTxCompletionMasterType;
   signal completionReady  : sl;
   signal portRxMaster     : PtpMacPortRxMasterType;
   signal portRxReady      : sl;
   signal delayReqMaster   : AxiStreamMasterType;
   signal delayReqSlave    : AxiStreamSlaveType;
   signal rxMessageMaster  : PtpRxMessageMasterType;
   signal rxReady          : sl;
   signal rxQueueOverflow  : sl;
   signal rxAbort          : sl;
   signal rxCounters       : PtpRxCountersType;
   signal txMessageMaster  : PtpRxMessageMasterType;
   signal txMessageReady   : sl;

begin

   assert PHY_TYPE_G = "XGMII" or PHY_TYPE_G = "GMII" report "Unsupported PTP physical interface" severity failure;
   assert (PHY_TYPE_G = "GMII" and CLK_FREQ_G = 125000000) or
      (PHY_TYPE_G = "XGMII" and CLK_FREQ_G = 156250000)
      report "PTP requires CLK_FREQ_G = 125000000 for GMII or 156250000 for XGMII"
      severity failure;

   -- Only system reset discards the whole MAC/port pipeline; its rising
   -- confirmation starts the ledger's startup quarantine. Admission then
   -- stays open for the life of the reset.
   comb : process (r, rst) is
      variable v : RegType;
   begin
      v := r;

      v.resetDone             := '1';
      v.control.openAdmission := '1';

      if rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;

      rin <= v;
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_Port : entity surf.PtpMacPortEthMac
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         PHY_TYPE_G           => PHY_TYPE_G,
         TX_TABLE_DEPTH_G     => TX_TABLE_DEPTH_G,
         RX_TABLE_DEPTH_G     => RX_DEPTH_C,
         RX_FIFO_ADDR_WIDTH_G => RX_FIFO_ADDR_WIDTH_C,
         INGRESS_LATENCY_G    => INGRESS_LATENCY_G,
         EGRESS_LATENCY_G     => EGRESS_LATENCY_G)
      port map (
         clk              => clk,              -- [in]
         rst              => rst,              -- [in]
         phyReady         => phyReady,         -- [in]
         ethConfig        => ethConfig,        -- [in]
         ethStatus        => ethStatus,        -- [out]
         phcTime          => timeValue,        -- [in]
         phcStatus        => status,           -- [in]
         captureAbort     => abortCapture,     -- [in]
         control          => r.control,        -- [in]
         status           => portStatusInt,    -- [out]
         counters         => portCounters,     -- [out]
         txMaster         => portTxMaster,     -- [in]
         txSlave          => portTxSlave,      -- [out]
         completionMaster => portCompletion,   -- [out]
         completionReady  => completionReady,  -- [in]
         rxMaster         => portRxMaster,     -- [out]
         rxReady          => portRxReady,      -- [in]
         regRst           => regRst,              -- [in]
         axiReadMaster    => portAxiReadMaster,   -- [in]
         axiReadSlave     => portAxiReadSlave,    -- [out]
         axiWriteMaster   => portAxiWriteMaster,  -- [in]
         axiWriteSlave    => portAxiWriteSlave,   -- [out]
         xgmiiRxd         => xgmiiRxd,         -- [in]
         xgmiiRxc         => xgmiiRxc,         -- [in]
         xgmiiTxd         => xgmiiTxd,         -- [out]
         xgmiiTxc         => xgmiiTxc,         -- [out]
         gmiiRxd          => gmiiRxd,          -- [in]
         gmiiRxDv         => gmiiRxDv,         -- [in]
         gmiiRxEr         => gmiiRxEr,         -- [in]
         gmiiTxd          => gmiiTxd,          -- [out]
         gmiiTxEn         => gmiiTxEn,         -- [out]
         gmiiTxEr         => gmiiTxEr);        -- [out]

   U_RxAdapter : entity surf.PtpMacPortRxAdapter
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         TLV_EN_G       => TLV_EN_G,
         MAX_FRAME_G    => MAX_FRAME_G)
      port map (
         clk           => clk,                -- [in]
         rst           => rst,                -- [in]
         rxFlush       => rxFlush,            -- [in]
         generation    => status.generation,  -- [in]
         portRxMaster  => portRxMaster,       -- [in]
         portRxReady   => portRxReady,        -- [out]
         messageMaster => rxMessageMaster,    -- [out]
         messageReady  => rxReady,            -- [in]
         rxAbort       => rxAbort,            -- [out]
         queueOverflow => rxQueueOverflow,    -- [out]
         rxEpoch       => open,               -- [out]
         counters      => rxCounters);        -- [out]

   U_TxAdapter : entity surf.PtpMacPortTxAdapter
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         TABLE_DEPTH_G  => TX_TABLE_DEPTH_G)
      port map (
         clk                 => clk,                                -- [in]
         rst                 => rst,                                -- [in]
         sAxisMaster         => delayReqMaster,                     -- [in]
         sAxisSlave          => delayReqSlave,                      -- [out]
         portTxMaster        => portTxMaster,                       -- [out]
         portTxSlave         => portTxSlave,                        -- [in]
         portGeneration      => portStatusInt.transportGeneration,  -- [in]
         portCompletion      => portCompletion,                     -- [in]
         portCompletionReady => completionReady,                    -- [out]
         messageMaster       => txMessageMaster,                    -- [out]
         messageReady        => txMessageReady);                    -- [in]

   U_Endpoint : entity surf.PtpEndpoint
      generic map (
         AXIL_BASE_ADDR_G  => AXIL_BASE_ADDR_G,
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         CLK_FREQ_G        => CLK_FREQ_G,
         PACKET_LIFETIME_G => PACKET_LIFETIME_G,
         INGRESS_LATENCY_G => INGRESS_LATENCY_G,
         EGRESS_LATENCY_G  => EGRESS_LATENCY_G,
         TX_AXIS_CONFIG_G  => EMAC_AXIS_CONFIG_C,
         CONTROL_MODE_G    => CONTROL_MODE_G)
      port map (
         clk             => clk,                   -- [in]
         rst             => rst,                   -- [in]
         regRst          => regRst,                -- [in]
         portRst         => portRst,               -- [in]
         linkReady       => phyReady,              -- [in]
         macResetDone    => r.resetDone,           -- [in]
         localMac        => ethConfig.macAddress,  -- [in]
         axiReadMaster   => axiReadMaster,         -- [in]
         axiReadSlave    => axiReadSlave,          -- [out]
         axiWriteMaster  => axiWriteMaster,        -- [in]
         axiWriteSlave   => axiWriteSlave,         -- [out]
         rxMessageMaster => rxMessageMaster,       -- [in]
         rxReady         => rxReady,               -- [out]
         rxQueueOverflow => rxQueueOverflow,       -- [in]
         rxAbort         => rxAbort,               -- [in]
         rxCounters      => rxCounters,            -- [in]
         txMessageMaster => txMessageMaster,       -- [in]
         txMessageReady  => txMessageReady,        -- [out]
         txAbort         => '0',                   -- [in]
         txMaster        => delayReqMaster,        -- [out]
         txSlave         => delayReqSlave,         -- [in]
         phcTime         => timeValue,             -- [out]
         phcStatus       => status,                -- [out]
         captureAbort    => abortCapture,          -- [out]
         rxFlush         => rxFlush,               -- [out]
         pps             => pps,                   -- [out]
         irq             => irq,                   -- [out]
         portActive      => portActive,            -- [out]
         servoState      => servoState);           -- [out]

   phcTime    <= timeValue;
   phcStatus  <= status;
   portStatus <= portStatusInt;

end architecture rtl;
