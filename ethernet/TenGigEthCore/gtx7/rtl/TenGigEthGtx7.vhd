-------------------------------------------------------------------------------
-- File       : TenGigEthGtx7.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 10GBASE-R Ethernet for Gtx7
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.TenGigEthPkg.all;
use work.EthMacPkg.all;

entity TenGigEthGtx7 is
   generic (
      TPD_G           : time                := 1 ns;
      PAUSE_EN_G      : boolean             := true;
      -- AXI-Lite Configurations
      EN_AXI_REG_G    : boolean             := false;
      -- AXI Streaming Configurations
      AXIS_CONFIG_G   : AxiStreamConfigType := EMAC_AXIS_CONFIG_C);
   port (
      -- Local Configurations
      localMac           : in  slv(47 downto 0)       := MAC_ADDR_INIT_C;
      -- Streaming DMA Interface 
      dmaClk             : in  sl;
      dmaRst             : in  sl;
      dmaIbMaster        : out AxiStreamMasterType;
      dmaIbSlave         : in  AxiStreamSlaveType;
      dmaObMaster        : in  AxiStreamMasterType;
      dmaObSlave         : out AxiStreamSlaveType;
      -- Slave AXI-Lite Interface 
      axiLiteClk         : in  sl                     := '0';
      axiLiteRst         : in  sl                     := '0';
      axiLiteReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axiLiteReadSlave   : out AxiLiteReadSlaveType;
      axiLiteWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axiLiteWriteSlave  : out AxiLiteWriteSlaveType;
      -- SFP+ Ports
      sigDet             : in  sl                     := '1';
      txFault            : in  sl                     := '0';
      txDisable          : out sl;
      -- Misc. Signals
      extRst             : in  sl                     := '0';
      phyClk             : in  sl;
      phyRst             : in  sl;
      phyReady           : out sl;
      -- Transceiver Debug Interface
      gtTxPreCursor      : in  slv(4 downto 0)        := "00000";
      gtTxPostCursor     : in  slv(4 downto 0)        := "00000";
      gtTxDiffCtrl       : in  slv(3 downto 0)        := "1110";
      gtRxPolarity       : in  sl                     := '0';
      gtTxPolarity       : in  sl                     := '0';
      -- Quad PLL Ports
      qplllock           : in  sl;
      qplloutclk         : in  sl;
      qplloutrefclk      : in  sl;
      qpllRst            : out sl;
      -- MGT Ports
      gtTxP              : out sl;
      gtTxN              : out sl;
      gtRxP              : in  sl;
      gtRxN              : in  sl);
end TenGigEthGtx7;

architecture mapping of TenGigEthGtx7 is

   component TenGigEthGtx7Core
      port (
         rxrecclk_out         : out std_logic;
         coreclk              : in  std_logic;
         dclk                 : in  std_logic;
         txusrclk             : in  std_logic;
         txusrclk2            : in  std_logic;
         areset               : in  std_logic;
         txoutclk             : out std_logic;
         areset_coreclk       : in  std_logic;
         gttxreset            : in  std_logic;
         gtrxreset            : in  std_logic;
         txuserrdy            : in  std_logic;
         qplllock             : in  std_logic;
         qplloutclk           : in  std_logic;
         qplloutrefclk        : in  std_logic;
         reset_counter_done   : in  std_logic;
         txp                  : out std_logic;
         txn                  : out std_logic;
         rxp                  : in  std_logic;
         rxn                  : in  std_logic;
         sim_speedup_control  : in  std_logic;
         xgmii_txd            : in  std_logic_vector(63 downto 0);
         xgmii_txc            : in  std_logic_vector(7 downto 0);
         xgmii_rxd            : out std_logic_vector(63 downto 0);
         xgmii_rxc            : out std_logic_vector(7 downto 0);
         configuration_vector : in  std_logic_vector(535 downto 0);
         status_vector        : out std_logic_vector(447 downto 0);
         core_status          : out std_logic_vector(7 downto 0);
         tx_resetdone         : out std_logic;
         rx_resetdone         : out std_logic;
         signal_detect        : in  std_logic;
         tx_fault             : in  std_logic;
         drp_req              : out std_logic;
         drp_gnt              : in  std_logic;
         drp_den_o            : out std_logic;
         drp_dwe_o            : out std_logic;
         drp_daddr_o          : out std_logic_vector(15 downto 0);
         drp_di_o             : out std_logic_vector(15 downto 0);
         drp_drdy_o           : out std_logic;
         drp_drpdo_o          : out std_logic_vector(15 downto 0);
         drp_den_i            : in  std_logic;
         drp_dwe_i            : in  std_logic;
         drp_daddr_i          : in  std_logic_vector(15 downto 0);
         drp_di_i             : in  std_logic_vector(15 downto 0);
         drp_drdy_i           : in  std_logic;
         drp_drpdo_i          : in  std_logic_vector(15 downto 0);
         tx_disable           : out std_logic;
         pma_pmd_type         : in  std_logic_vector(2 downto 0);
         gt0_eyescanreset     : in  std_logic;
         gt0_eyescandataerror : out std_logic;
         gt0_txbufstatus      : out std_logic_vector(1 downto 0);
         gt0_rxbufstatus      : out std_logic_vector(2 downto 0);
         gt0_eyescantrigger   : in  std_logic;
         gt0_rxcdrhold        : in  std_logic;
         gt0_txprbsforceerr   : in  std_logic;
         gt0_txpolarity       : in  std_logic;
         gt0_rxpolarity       : in  std_logic;
         gt0_rxprbserr        : out std_logic;
         gt0_txpmareset       : in  std_logic;
         gt0_rxpmareset       : in  std_logic;
         gt0_txresetdone      : out std_logic;
         gt0_rxresetdone      : out std_logic;
         gt0_rxdfelpmreset    : in  std_logic;
         gt0_rxlpmen          : in  std_logic;
         gt0_dmonitorout      : out std_logic_vector(7 downto 0);
         gt0_rxrate           : in  std_logic_vector(2 downto 0);
         gt0_txprecursor      : in  std_logic_vector(4 downto 0);
         gt0_txpostcursor     : in  std_logic_vector(4 downto 0);
         gt0_txdiffctrl       : in  std_logic_vector(3 downto 0));
   end component;

   signal mAxiReadMaster  : AxiLiteReadMasterType;
   signal mAxiReadSlave   : AxiLiteReadSlaveType;
   signal mAxiWriteMaster : AxiLiteWriteMasterType;
   signal mAxiWriteSlave  : AxiLiteWriteSlaveType;

   signal phyRxd : slv(63 downto 0);
   signal phyRxc : slv(7 downto 0);
   signal phyTxd : slv(63 downto 0);
   signal phyTxc : slv(7 downto 0);

   signal areset    : sl;
   signal txClk322  : sl;
   signal txUsrClk  : sl;
   signal txUsrClk2 : sl;
   signal txUsrRdy  : sl;

   signal drpReqGnt : sl;
   signal drpEn     : sl;
   signal drpWe     : sl;
   signal drpAddr   : slv(15 downto 0);
   signal drpDi     : slv(15 downto 0);
   signal drpRdy    : sl;
   signal drpDo     : slv(15 downto 0);

   signal configurationVector : slv(535 downto 0) := (others => '0');

   signal config : TenGigEthConfig;
   signal status : TenGigEthStatus;

   signal macRxAxisMaster : AxiStreamMasterType;
   signal macRxAxisCtrl   : AxiStreamCtrlType;
   signal macTxAxisMaster : AxiStreamMasterType;
   signal macTxAxisSlave  : AxiStreamSlaveType;

begin

   phyReady        <= status.phyReady;
   areset          <= extRst or config.softRst;
   status.qplllock <= qplllock;

   ------------------
   -- Synchronization 
   ------------------
   U_AxiLiteAsync : entity work.AxiLiteAsync
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Slave Port
         sAxiClk         => axiLiteClk,
         sAxiClkRst      => axiLiteRst,
         sAxiReadMaster  => axiLiteReadMaster,
         sAxiReadSlave   => axiLiteReadSlave,
         sAxiWriteMaster => axiLiteWriteMaster,
         sAxiWriteSlave  => axiLiteWriteSlave,
         -- Master Port
         mAxiClk         => phyClk,
         mAxiClkRst      => phyRst,
         mAxiReadMaster  => mAxiReadMaster,
         mAxiReadSlave   => mAxiReadSlave,
         mAxiWriteMaster => mAxiWriteMaster,
         mAxiWriteSlave  => mAxiWriteSlave);

   txDisable <= status.txDisable;

   U_Sync : entity work.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 3)
      port map (
         clk        => phyClk,
         -- Input
         dataIn(0)  => sigDet,
         dataIn(1)  => txFault,
         dataIn(2)  => txUsrRdy,
         -- Output
         dataOut(0) => status.sigDet,
         dataOut(1) => status.txFault,
         dataOut(2) => status.txUsrRdy);

   --------------------
   -- Ethernet MAC core
   --------------------
   U_MAC : entity work.EthMacTop
      generic map (
         TPD_G           => TPD_G,
         PAUSE_EN_G      => PAUSE_EN_G,
         PHY_TYPE_G      => "XGMII",
         PRIM_CONFIG_G   => AXIS_CONFIG_G)
      port map (
         -- Primary Interface
         primClk         => dmaClk,
         primRst         => dmaRst,
         ibMacPrimMaster => dmaObMaster,
         ibMacPrimSlave  => dmaObSlave,
         obMacPrimMaster => dmaIbMaster,
         obMacPrimSlave  => dmaIbSlave,
         -- Ethernet Interface
         ethClk          => phyClk,
         ethRst          => phyRst,
         ethConfig       => config.macConfig,
         ethStatus       => status.macStatus,
         phyReady        => status.phyReady,
         -- XGMII PHY Interface
         xgmiiRxd        => phyRxd,
         xgmiiRxc        => phyRxc,
         xgmiiTxd        => phyTxd,
         xgmiiTxc        => phyTxc);

   -----------------
   -- 10GBASE-R core
   -----------------
   U_TenGigEthGtx7Core : TenGigEthGtx7Core
      port map (
         -- Clocks and Resets
         rxrecclk_out         => open,
         coreclk              => phyClk,
         txoutclk             => txClk322,
         areset_coreclk       => phyRst,
         dclk                 => phyClk,
         txusrclk             => txUsrClk,
         txusrclk2            => txUsrClk2,
         areset               => areset,
         gttxreset            => status.gtTxRst,
         gtrxreset            => status.gtRxRst,
         txuserrdy            => txUsrRdy,
         reset_counter_done   => status.rstCntDone,
         -- Quad PLL Interface
         qplllock             => status.qplllock,
         qplloutclk           => qplloutclk,
         qplloutrefclk        => qplloutrefclk,
         -- MGT Ports
         txp                  => gtTxP,
         txn                  => gtTxN,
         rxp                  => gtRxP,
         rxn                  => gtRxN,
         -- PHY Interface
         xgmii_txd            => phyTxd,
         xgmii_txc            => phyTxc,
         xgmii_rxd            => phyRxd,
         xgmii_rxc            => phyRxc,
         -- Configuration and Status
         sim_speedup_control  => '0',
         configuration_vector => configurationVector,
         status_vector        => open,
         core_status          => status.core_status,
         tx_resetdone         => status.txRstdone,
         rx_resetdone         => status.rxRstdone,
         signal_detect        => status.sigDet,
         tx_fault             => status.txFault,
         tx_disable           => status.txDisable,
         pma_pmd_type         => config.pma_pmd_type,
         -- DRP interface
         -- Note: If no arbitration is required on the GT DRP ports 
         -- then connect REQ to GNT and connect other signals i <= o;         
         drp_req              => drpReqGnt,
         drp_gnt              => drpReqGnt,
         drp_den_o            => drpEn,
         drp_dwe_o            => drpWe,
         drp_daddr_o          => drpAddr,
         drp_di_o             => drpDi,
         drp_drdy_o           => drpRdy,
         drp_drpdo_o          => drpDo,
         drp_den_i            => drpEn,
         drp_dwe_i            => drpWe,
         drp_daddr_i          => drpAddr,
         drp_di_i             => drpDi,
         drp_drdy_i           => drpRdy,
         drp_drpdo_i          => drpDo,
         -- Transceiver Debug Interface
         gt0_eyescanreset     => '0',
         gt0_eyescandataerror => open,
         gt0_txbufstatus      => open,
         gt0_rxbufstatus      => open,
         gt0_eyescantrigger   => '0',
         gt0_rxcdrhold        => '0',
         gt0_txprbsforceerr   => '0',
         gt0_txpolarity       => gtTxPolarity,
         gt0_rxpolarity       => gtRxPolarity,
         gt0_rxprbserr        => open,
         gt0_txpmareset       => '0',
         gt0_rxpmareset       => '0',
         gt0_txresetdone      => open,
         gt0_rxresetdone      => open,
         gt0_rxdfelpmreset    => '0',
         gt0_rxlpmen          => '0',
         gt0_dmonitorout      => open,
         gt0_rxrate           => (others => '0'),
         gt0_txprecursor      => gtTxPreCursor,
         gt0_txpostcursor     => gtTxPostCursor,
         gt0_txdiffctrl       => gtTxDiffCtrl);

   -------------------------------------
   -- 10GBASE-R's Reset Module
   -------------------------------------        
   U_TenGigEthRst : entity work.TenGigEthRst
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Clocks and Resets
         extRst     => extRst,
         phyClk     => phyClk,
         phyRst     => phyRst,
         txClk322   => txClk322,
         txUsrClk   => txUsrClk,
         txUsrClk2  => txUsrClk2,
         gtTxRst    => status.gtTxRst,
         gtRxRst    => status.gtRxRst,
         txUsrRdy   => txUsrRdy,
         rstCntDone => status.rstCntDone,
         -- Quad PLL Ports
         qplllock   => status.qplllock,
         qpllRst    => qpllRst);

   -------------------------------         
   -- Configuration Vector Mapping
   -------------------------------         
   configurationVector(0)              <= config.pma_loopback;
   configurationVector(15)             <= config.pma_reset;
   configurationVector(110)            <= config.pcs_loopback;
   configurationVector(111)            <= config.pcs_reset;
   configurationVector(399 downto 384) <= x"4C4B";  -- timer_ctrl = 0x4C4B (default)

   ----------------------
   -- Core Status Mapping
   ----------------------   
   status.phyReady <= status.core_status(0) or config.pcs_loopback;

   --------------------------------     
   -- Configuration/Status Register   
   --------------------------------     
   U_TenGigEthReg : entity work.TenGigEthReg
      generic map (
         TPD_G        => TPD_G,
         EN_AXI_REG_G => EN_AXI_REG_G)
      port map (
         -- Local Configurations
         localMac       => localMac,
         -- Clocks and resets
         clk            => phyClk,
         rst            => phyRst,
         -- AXI-Lite Register Interface
         axiReadMaster  => mAxiReadMaster,
         axiReadSlave   => mAxiReadSlave,
         axiWriteMaster => mAxiWriteMaster,
         axiWriteSlave  => mAxiWriteSlave,
         -- Configuration and Status Interface
         config         => config,
         status         => status);

end mapping;
