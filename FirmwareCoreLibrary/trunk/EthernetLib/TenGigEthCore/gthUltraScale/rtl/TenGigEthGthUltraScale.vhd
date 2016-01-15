-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : TenGigEthGthUltraScale.vhd
-- Author     : Larry Ruckman <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-08
-- Last update: 2016-01-13
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 10GBASE-R Ethernet for GTH Ultra Scale
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Ethernet Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Ethernet Library', including this file, 
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

entity TenGigEthGthUltraScale is
   generic (
      TPD_G            : time                := 1 ns;
      REF_CLK_FREQ_G   : real                := 156.25E+6;  -- Support 156.25MHz or 312.5MHz      
      -- AXI-Lite Configurations
      AXI_ERROR_RESP_G : slv(1 downto 0)     := AXI_RESP_SLVERR_C;
      -- AXI Streaming Configurations
      AXIS_CONFIG_G    : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);  -- Note: Only support 64-bit AXIS configurations
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
      extRst             : in  sl;
      coreClk            : in  sl;
      phyClk             : out sl;
      phyRst             : out sl;
      phyReady           : out sl;
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
end TenGigEthGthUltraScale;

architecture mapping of TenGigEthGthUltraScale is

   signal mAxiReadMaster  : AxiLiteReadMasterType;
   signal mAxiReadSlave   : AxiLiteReadSlaveType;
   signal mAxiWriteMaster : AxiLiteWriteMasterType;
   signal mAxiWriteSlave  : AxiLiteWriteSlaveType;

   signal phyRxd : slv(63 downto 0);
   signal phyRxc : slv(7 downto 0);
   signal phyTxd : slv(63 downto 0);
   signal phyTxc : slv(7 downto 0);

   signal areset      : sl;
   signal coreRst     : sl;
   signal phyClock    : sl;
   signal phyReset    : sl;
   signal txClk322    : sl;
   signal txUsrClk    : sl;
   signal txUsrClk2   : sl;
   signal txUsrRdy    : sl;
   signal txBufgGtRst : sl;

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

   phyClk          <= phyClock;
   phyRst          <= phyReset;
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
         mAxiClk         => phyClock,
         mAxiClkRst      => phyReset,
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
         clk        => phyClock,
         -- Input
         dataIn(0)  => sigDet,
         dataIn(1)  => txFault,
         dataIn(2)  => txUsrRdy,
         -- Output
         dataOut(0) => status.sigDet,
         dataOut(1) => status.txFault,
         dataOut(2) => status.txUsrRdy);  

   ---------------------------
   -- 10 Gig Ethernet MAC core
   ---------------------------
   U_MacTxFifo : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         FIFO_ADDR_WIDTH_G   => 10,
         VALID_THOLD_G       => 0,      -- Only when full frame is ready
         SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_G,
         MASTER_AXI_CONFIG_G => EMAC_AXIS_CONFIG_C) 
      port map (
         sAxisClk    => dmaClk,
         sAxisRst    => dmaRst,
         sAxisMaster => dmaObMaster,
         sAxisSlave  => dmaObSlave,
         mAxisClk    => phyClock,
         mAxisRst    => phyReset,
         mAxisMaster => macTxAxisMaster,
         mAxisSlave  => macTxAxisSlave);

   U_XMacCore : entity work.EthMacTop
      generic map (
         TPD_G           => TPD_G,
         PAUSE_512BITS_G => 8,
         VLAN_CNT_G      => 1,
         VLAN_EN_G       => false,
         BYP_EN_G        => false,
         BYP_ETH_TYPE_G  => x"0000",
         SHIFT_EN_G      => false,
         FILT_EN_G       => false,
         CSUM_EN_G       => false) 
      port map (
         ethClk      => phyClock,
         ethClkRst   => phyReset,
         sPrimMaster => macTxAxisMaster,
         sPrimSlave  => macTxAxisSlave,
         mPrimMaster => macRxAxisMaster,
         mPrimCtrl   => macRxAxisCtrl,
         phyTxd      => phyTxd,
         phyTxc      => phyTxc,
         phyRxd      => phyRxd,
         phyRxc      => phyRxc,
         phyReady    => status.phyReady,
         ethConfig   => config.macConfig,
         ethStatus   => status.macStatus);

   U_MacRxFifo : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         FIFO_ADDR_WIDTH_G   => 11,
         SLAVE_READY_EN_G    => false,
         FIFO_PAUSE_THRESH_G => 1024,
         SLAVE_AXI_CONFIG_G  => EMAC_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => AXIS_CONFIG_G) 
      port map (
         sAxisClk    => phyClock,
         sAxisRst    => phyReset,
         sAxisMaster => macRxAxisMaster,
         sAxisCtrl   => macRxAxisCtrl,
         mAxisClk    => dmaClk,
         mAxisRst    => dmaRst,
         mAxisMaster => dmaIbMaster,
         mAxisSlave  => dmaIbSlave); 

   -----------------
   -- 10GBASE-R core
   -----------------
   GEN_156p25MHz : if (REF_CLK_FREQ_G = 156.25E+6) generate
      U_TenGigEthGthUltraScaleCore : entity work.TenGigEthGthUltraScale156p25MHzCore
         port map (
            -- Clocks and Resets
            coreclk              => coreclk,
            dclk                 => coreclk,
            txusrclk             => txusrclk,
            txusrclk2            => txusrclk2,
            txoutclk             => txClk322,
            areset_coreclk       => coreRst,
            txuserrdy            => txUsrRdy,
            rxrecclk_out         => open,
            areset               => areset,
            gttxreset            => status.gtTxRst,
            gtrxreset            => status.gtRxRst,
            reset_tx_bufg_gt     => txBufgGtRst,
            reset_counter_done   => status.rstCntDone,
            -- Quad PLL Interface
            qpll0lock            => status.qplllock,
            qpll0outclk          => qplloutclk,
            qpll0outrefclk       => qplloutrefclk,
            qpll0reset           => qpllRst,
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
            core_to_gt_drpen     => drpEn,
            core_to_gt_drpwe     => drpWe,
            core_to_gt_drpaddr   => drpAddr,
            core_to_gt_drpdi     => drpDi,
            gt_drprdy            => drpRdy,
            gt_drpdo             => drpDo,
            gt_drpen             => drpEn,
            gt_drpwe             => drpWe,
            gt_drpaddr           => drpAddr,
            gt_drpdi             => drpDi,
            core_to_gt_drprdy    => drpRdy,
            core_to_gt_drpdo     => drpDo);
   end generate;
   GEN_312p5MHz : if (REF_CLK_FREQ_G = 312.50E+6) generate
      U_TenGigEthGthUltraScaleCore : entity work.TenGigEthGthUltraScale312p5MHzCore
         port map (
            -- Clocks and Resets
            coreclk              => coreclk,
            dclk                 => phyClock,
            txusrclk             => txusrclk,
            txusrclk2            => txusrclk2,
            txoutclk             => txClk322,
            areset_coreclk       => coreRst,
            txuserrdy            => txUsrRdy,
            rxrecclk_out         => open,
            areset               => areset,
            gttxreset            => status.gtTxRst,
            gtrxreset            => status.gtRxRst,
            reset_tx_bufg_gt     => txBufgGtRst,
            reset_counter_done   => status.rstCntDone,
            -- Quad PLL Interface
            qpll0lock            => status.qplllock,
            qpll0outclk          => qplloutclk,
            qpll0outrefclk       => qplloutrefclk,
            qpll0reset           => qpllRst,
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
            core_to_gt_drpen     => drpEn,
            core_to_gt_drpwe     => drpWe,
            core_to_gt_drpaddr   => drpAddr,
            core_to_gt_drpdi     => drpDi,
            gt_drprdy            => drpRdy,
            gt_drpdo             => drpDo,
            gt_drpen             => drpEn,
            gt_drpwe             => drpWe,
            gt_drpaddr           => drpAddr,
            gt_drpdi             => drpDi,
            core_to_gt_drprdy    => drpRdy,
            core_to_gt_drpdo     => drpDo);
   end generate;

   -------------------------------------
   -- 10GBASE-R's Reset Module
   -------------------------------------        
   U_TenGigEthRst : entity work.TenGigEthGthUltraScaleRst
      generic map (
         TPD_G => TPD_G)
      port map (
         extRst      => extRst,
         coreClk     => coreClk,
         coreRst     => coreRst,
         phyClk      => phyClock,
         phyRst      => phyReset,
         txBufgGtRst => txBufgGtRst,
         qplllock    => status.qplllock,
         txClk322    => txClk322,
         txUsrClk    => txUsrClk,
         txUsrClk2   => txUsrClk2,
         gtTxRst     => status.gtTxRst,
         gtRxRst     => status.gtRxRst,
         txUsrRdy    => txUsrRdy,
         rstCntDone  => status.rstCntDone);   

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
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
      port map (
         -- Local Configurations
         localMac       => localMac,
         -- Clocks and resets
         clk            => phyClock,
         rst            => phyReset,
         -- AXI-Lite Register Interface
         axiReadMaster  => mAxiReadMaster,
         axiReadSlave   => mAxiReadSlave,
         axiWriteMaster => mAxiWriteMaster,
         axiWriteSlave  => mAxiWriteSlave,
         -- Configuration and Status Interface
         config         => config,
         status         => status); 

end mapping;
