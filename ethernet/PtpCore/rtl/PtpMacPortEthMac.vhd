-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Standalone timing-port composition: PtpMacPort + EthMacTop
-------------------------------------------------------------------------------
-- Phase 1 composition of the composable PTP plan: a timing-mode EthMacTop
-- (EMAC_TIMING_AXIS_CONFIG_C, TIMING_EN_G) behind PtpMacPort, with the PHC
-- tuple supplied from outside (normally a PtpPhcCore, or a fixture). The
-- controller owns untagged 0x88F7 in both directions: there is no bypass
-- path, primary guard or drain. This is a build-time alternative to
-- EthMacPtpEndpoint, which is unchanged. PtpMacPortReg publishes the port's
-- capability, status, occupancy and counters on an optional AXI-Lite bank.
-- Contract and limits: ethernet/PtpCore/timing-port.md.
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

entity PtpMacPortEthMac is
   generic (
      TPD_G                 : time                    := 1 ns;
      RST_POLARITY_G        : sl                      := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      PHY_TYPE_G            : string                  := "GMII";  -- "GMII" or "XGMII"
      FILT_EN_G             : boolean                 := false;
      TX_TABLE_DEPTH_G      : positive range 1 to 255 := 16;
      RX_TABLE_DEPTH_G      : positive range 1 to 255 := 16;
      RX_FIFO_ADDR_WIDTH_G  : positive range 9 to 16  := 11;
      TX_STORE_ADDR_WIDTH_G : positive range 8 to 16  := 8;
      SYNTH_MODE_G          : string                  := "inferred";
      MEMORY_TYPE_G         : string                  := "block";
      INGRESS_LATENCY_G     : slv(63 downto 0)        := (others => '0');
      EGRESS_LATENCY_G      : slv(63 downto 0)        := (others => '0'));
   port (
      -- Ethernet/PHC clock domain and system reset
      clk              : in  sl;
      rst              : in  sl;
      phyReady         : in  sl;
      ethConfig        : in  EthMacConfigType;
      ethStatus        : out EthMacStatusType;
      -- External PHC state for the current cycle
      phcTime          : in  PtpTimeType;
      phcStatus        : in  PtpPhcStatusType;
      captureAbort     : in  sl := '0';
      -- Controller
      control          : in  PtpMacPortControlType;
      status           : out PtpMacPortStatusType;
      counters         : out PtpMacPortCountersType;
      txMaster         : in  PtpMacPortTxMasterType;
      txSlave          : out AxiStreamSlaveType;
      completionMaster : out PtpMacPortTxCompletionMasterType;
      completionReady  : in  sl;
      rxMaster         : out PtpMacPortRxMasterType;
      rxReady          : in  sl;
      -- Port AXI-Lite bank in clk; regRst cancels its responses only
      regRst           : in  sl                     := '0';
      axiReadMaster    : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axiReadSlave     : out AxiLiteReadSlaveType;
      axiWriteMaster   : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axiWriteSlave    : out AxiLiteWriteSlaveType;
      -- Selected physical interface, synchronous to clk
      xgmiiRxd         : in  slv(63 downto 0) := (others => '0');
      xgmiiRxc         : in  slv(7 downto 0)  := (others => '1');
      xgmiiTxd         : out slv(63 downto 0);
      xgmiiTxc         : out slv(7 downto 0);
      gmiiRxd          : in  slv(7 downto 0)  := (others => '0');
      gmiiRxDv         : in  sl               := '0';
      gmiiRxEr         : in  sl               := '0';
      gmiiTxd          : out slv(7 downto 0);
      gmiiTxEn         : out sl;
      gmiiTxEr         : out sl);
end entity PtpMacPortEthMac;

architecture mapping of PtpMacPortEthMac is

   constant CONFIG_C : AxiStreamConfigType := EMAC_TIMING_AXIS_CONFIG_C;

   -- RX FIFO bound (section 5): a full table of maximum frames plus one
   -- synthetic terminator each, so storage can never overflow
   constant RX_FIFO_WORDS_C : positive := RX_TABLE_DEPTH_G * ((EMAC_TIMING_MAX_FRAME_C + 15) / 16) + RX_TABLE_DEPTH_G;

   signal macTxMaster  : AxiStreamMasterType;
   signal macTxSlave   : AxiStreamSlaveType;
   signal macRxMaster  : AxiStreamMasterType;
   signal macRxSlave   : AxiStreamSlaveType;
   signal rxNextToken  : EthMacTokenType;
   signal rxFrameEvent : EthMacFrameEventType;
   signal rxRetire     : EthMacTokenRetireArray(EMAC_RX_RETIRE_SOURCES_C-1 downto 0);
   signal txFrameEvent : EthMacFrameEventType;
   signal txRetire     : EthMacTokenRetireArray(EMAC_TX_RETIRE_SOURCES_C-1 downto 0);
   signal macAbortReq  : EthMacAbortRequestType;
   signal macAbortAck  : EthMacAbortAckType;
   signal portStatus   : PtpMacPortStatusType;
   signal portCounters : PtpMacPortCountersType;

begin

   assert (2**RX_FIFO_ADDR_WIDTH_G >= RX_FIFO_WORDS_C)
      report "PtpMacPortEthMac: RX_FIFO_ADDR_WIDTH_G cannot hold RX_TABLE_DEPTH_G maximum frames"
      severity failure;

   assert (PHY_TYPE_G = "GMII") or (PHY_TYPE_G = "XGMII")
      report "PtpMacPortEthMac: PHY_TYPE_G must be GMII or XGMII"
      severity failure;

   U_Port : entity surf.PtpMacPort
      generic map (
         TPD_G                 => TPD_G,
         RST_POLARITY_G        => RST_POLARITY_G,
         TX_TABLE_DEPTH_G      => TX_TABLE_DEPTH_G,
         RX_TABLE_DEPTH_G      => RX_TABLE_DEPTH_G,
         TX_STORE_ADDR_WIDTH_G => TX_STORE_ADDR_WIDTH_G,
         MEMORY_TYPE_G         => MEMORY_TYPE_G,
         SYNTH_MODE_G          => SYNTH_MODE_G,
         INGRESS_LATENCY_G     => INGRESS_LATENCY_G,
         EGRESS_LATENCY_G      => EGRESS_LATENCY_G)
      port map (
         clk              => clk,
         rst              => rst,
         ethClkEn         => '1',
         phcTime          => phcTime,
         phcStatus        => phcStatus,
         captureAbort     => captureAbort,
         control          => control,
         status           => portStatus,
         counters         => portCounters,
         txMaster         => txMaster,
         txSlave          => txSlave,
         completionMaster => completionMaster,
         completionReady  => completionReady,
         rxMaster         => rxMaster,
         rxReady          => rxReady,
         macTxMaster      => macTxMaster,
         macTxSlave       => macTxSlave,
         macRxMaster      => macRxMaster,
         macRxSlave       => macRxSlave,
         rxNextToken      => rxNextToken,
         rxFrameEvent     => rxFrameEvent,
         rxRetire         => rxRetire,
         txFrameEvent     => txFrameEvent,
         txRetire         => txRetire,
         macAbortReq      => macAbortReq,
         macAbortAck      => macAbortAck);

   status   <= portStatus;
   counters <= portCounters;

   U_Reg : entity surf.PtpMacPortReg
      generic map (
         TPD_G            => TPD_G,
         RST_POLARITY_G   => RST_POLARITY_G,
         PHY_TYPE_G       => PHY_TYPE_G,
         TX_TABLE_DEPTH_G => TX_TABLE_DEPTH_G,
         RX_TABLE_DEPTH_G => RX_TABLE_DEPTH_G)
      port map (
         clk            => clk,             -- [in]
         rst            => rst,             -- [in]
         regRst         => regRst,          -- [in]
         control        => control,         -- [in]
         status         => portStatus,      -- [in]
         counters       => portCounters,    -- [in]
         axiReadMaster  => axiReadMaster,   -- [in]
         axiReadSlave   => axiReadSlave,    -- [out]
         axiWriteMaster => axiWriteMaster,  -- [in]
         axiWriteSlave  => axiWriteSlave);  -- [out]

   U_Mac : entity surf.EthMacTop
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         PAUSE_EN_G        => true,
         PHY_TYPE_G        => PHY_TYPE_G,
         DROP_ERR_PKT_G    => true,
         JUMBO_G           => false,
         FIFO_ADDR_WIDTH_G => RX_FIFO_ADDR_WIDTH_G,
         SYNTH_MODE_G      => SYNTH_MODE_G,
         MEMORY_TYPE_G     => MEMORY_TYPE_G,
         ROCEV2_EN_G       => false,
         FILT_EN_G         => FILT_EN_G,
         PRIM_COMMON_CLK_G => true,
         PRIM_CONFIG_G     => CONFIG_C,
         BYP_EN_G          => false,
         INT_CONFIG_G      => CONFIG_C,
         TIMING_EN_G       => true)
      port map (
         ethClkEn        => '1',
         ethClk          => clk,
         ethRst          => rst,
         primClk         => clk,
         primRst         => rst,
         ibMacPrimMaster => macTxMaster,
         ibMacPrimSlave  => macTxSlave,
         obMacPrimMaster => macRxMaster,
         obMacPrimSlave  => macRxSlave,
         xgmiiRxd        => xgmiiRxd,
         xgmiiRxc        => xgmiiRxc,
         xgmiiTxd        => xgmiiTxd,
         xgmiiTxc        => xgmiiTxc,
         gmiiRxDv        => gmiiRxDv,
         gmiiRxEr        => gmiiRxEr,
         gmiiRxd         => gmiiRxd,
         gmiiTxEn        => gmiiTxEn,
         gmiiTxEr        => gmiiTxEr,
         gmiiTxd         => gmiiTxd,
         phyReady        => phyReady,
         ethConfig       => ethConfig,
         ethStatus       => ethStatus,
         rxNextToken     => rxNextToken,
         rxFrameEvent    => rxFrameEvent,
         rxRetire        => rxRetire,
         txFrameEvent    => txFrameEvent,
         txRetire        => txRetire,
         abortReq        => macAbortReq,
         abortAck        => macAbortAck);

end architecture mapping;
