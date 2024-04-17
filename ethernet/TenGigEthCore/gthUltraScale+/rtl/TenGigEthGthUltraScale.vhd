-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 10GBASE-R Ethernet for GTH Ultra Scale
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
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.TenGigEthPkg.all;
use surf.EthMacPkg.all;

entity TenGigEthGthUltraScale is
   generic (
      TPD_G         : time                := 1 ns;
      JUMBO_G       : boolean             := true;
      PAUSE_EN_G    : boolean             := true;
      -- AXI-Lite Configurations
      EN_AXI_REG_G  : boolean             := false;
      -- AXI Streaming Configurations
      AXIS_CONFIG_G : AxiStreamConfigType := EMAC_AXIS_CONFIG_C);
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
      -- Misc. Signals
      coreClk            : in  sl;
      coreRst            : in  sl;
      phyClk             : out sl;
      phyRst             : out sl;
      phyReady           : out sl;
      -- Transceiver Debug Interface
      gtTxPreCursor      : in  slv(4 downto 0)        := "00000";
      gtTxPostCursor     : in  slv(4 downto 0)        := "00000";
      gtTxDiffCtrl       : in  slv(4 downto 0)        := "11100";
      gtRxPolarity       : in  sl                     := '0';
      gtTxPolarity       : in  sl                     := '0';
      -- Quad PLL Ports
      qplllock           : in  slv(1 downto 0);
      qplloutclk         : in  slv(1 downto 0);
      qplloutrefclk      : in  slv(1 downto 0);
      qpllRst            : out slv(1 downto 0);
      -- MGT Ports
      gtTxP              : out sl;
      gtTxN              : out sl;
      gtRxP              : in  sl;
      gtRxN              : in  sl);
end TenGigEthGthUltraScale;

architecture mapping of TenGigEthGthUltraScale is

   component TenGigEthGthUltraScale156p25MHzCore
      port (
         gt_txp_out                          : out std_logic_vector(0 downto 0);
         gt_txn_out                          : out std_logic_vector(0 downto 0);
         gt_rxp_in                           : in  std_logic_vector(0 downto 0);
         gt_rxn_in                           : in  std_logic_vector(0 downto 0);
         rx_core_clk_0                       : in  std_logic;
         rx_serdes_reset_0                   : in  std_logic;
         txoutclksel_in_0                    : in  std_logic_vector(2 downto 0);
         rxoutclksel_in_0                    : in  std_logic_vector(2 downto 0);
         gt_dmonitorout_0                    : out std_logic_vector(16 downto 0);
         gt_eyescandataerror_0               : out std_logic;
         gt_eyescanreset_0                   : in  std_logic;
         gt_eyescantrigger_0                 : in  std_logic;
         gt_pcsrsvdin_0                      : in  std_logic_vector(15 downto 0);
         gt_rxbufreset_0                     : in  std_logic;
         gt_rxbufstatus_0                    : out std_logic_vector(2 downto 0);
         gt_rxcdrhold_0                      : in  std_logic;
         gt_rxcommadeten_0                   : in  std_logic;
         gt_rxdfeagchold_0                   : in  std_logic;
         gt_rxdfelpmreset_0                  : in  std_logic;
         gt_rxlatclk_0                       : in  std_logic;
         gt_rxlpmen_0                        : in  std_logic;
         gt_rxpcsreset_0                     : in  std_logic;
         gt_rxpmareset_0                     : in  std_logic;
         gt_rxpolarity_0                     : in  std_logic;
         gt_rxprbscntreset_0                 : in  std_logic;
         gt_rxprbserr_0                      : out std_logic;
         gt_rxprbssel_0                      : in  std_logic_vector(3 downto 0);
         gt_rxrate_0                         : in  std_logic_vector(2 downto 0);
         gt_rxslide_in_0                     : in  std_logic;
         gt_rxstartofseq_0                   : out std_logic_vector(1 downto 0);
         gt_txbufstatus_0                    : out std_logic_vector(1 downto 0);
         gt_txdiffctrl_0                     : in  std_logic_vector(4 downto 0);
         gt_txinhibit_0                      : in  std_logic;
         gt_txlatclk_0                       : in  std_logic;
         gt_txmaincursor_0                   : in  std_logic_vector(6 downto 0);
         gt_txpcsreset_0                     : in  std_logic;
         gt_txpmareset_0                     : in  std_logic;
         gt_txpolarity_0                     : in  std_logic;
         gt_txpostcursor_0                   : in  std_logic_vector(4 downto 0);
         gt_txprbsforceerr_0                 : in  std_logic;
         gt_txprbssel_0                      : in  std_logic_vector(3 downto 0);
         gt_txprecursor_0                    : in  std_logic_vector(4 downto 0);
         rxrecclkout_0                       : out std_logic;
         gt_drpclk_0                         : in  std_logic;
         gt_drpdo_0                          : out std_logic_vector(15 downto 0);
         gt_drprdy_0                         : out std_logic;
         gt_drpen_0                          : in  std_logic;
         gt_drpwe_0                          : in  std_logic;
         gt_drpaddr_0                        : in  std_logic_vector(9 downto 0);
         gt_drpdi_0                          : in  std_logic_vector(15 downto 0);
         sys_reset                           : in  std_logic;
         dclk                                : in  std_logic;
         tx_mii_clk_0                        : out std_logic;
         rx_clk_out_0                        : out std_logic;
         gtpowergood_out_0                   : out std_logic;
         qpll0clk_in                         : in  std_logic_vector(0 downto 0);
         qpll0refclk_in                      : in  std_logic_vector(0 downto 0);
         qpll1clk_in                         : in  std_logic_vector(0 downto 0);
         qpll1refclk_in                      : in  std_logic_vector(0 downto 0);
         gtwiz_reset_qpll0lock_in            : in  std_logic;
         gtwiz_reset_qpll0reset_out          : out std_logic;
         gtwiz_reset_qpll1lock_in            : in  std_logic;
         gtwiz_reset_qpll1reset_out          : out std_logic;
         gt_reset_tx_done_out_0              : out std_logic;
         gt_reset_rx_done_out_0              : out std_logic;
         gt_reset_all_in_0                   : in  std_logic;
         gt_tx_reset_in_0                    : in  std_logic;
         gt_rx_reset_in_0                    : in  std_logic;
         rx_reset_0                          : in  std_logic;
         rx_mii_d_0                          : out std_logic_vector(63 downto 0);
         rx_mii_c_0                          : out std_logic_vector(7 downto 0);
         ctl_rx_test_pattern_0               : in  std_logic;
         ctl_rx_data_pattern_select_0        : in  std_logic;
         ctl_rx_test_pattern_enable_0        : in  std_logic;
         ctl_rx_prbs31_test_pattern_enable_0 : in  std_logic;
         stat_rx_framing_err_0               : out std_logic;
         stat_rx_framing_err_valid_0         : out std_logic;
         stat_rx_local_fault_0               : out std_logic;
         stat_rx_block_lock_0                : out std_logic;
         stat_rx_valid_ctrl_code_0           : out std_logic;
         stat_rx_status_0                    : out std_logic;
         stat_rx_hi_ber_0                    : out std_logic;
         stat_rx_bad_code_0                  : out std_logic;
         stat_rx_bad_code_valid_0            : out std_logic;
         stat_rx_error_0                     : out std_logic_vector(7 downto 0);
         stat_rx_error_valid_0               : out std_logic;
         stat_rx_fifo_error_0                : out std_logic;
         tx_reset_0                          : in  std_logic;
         tx_mii_d_0                          : in  std_logic_vector(63 downto 0);
         tx_mii_c_0                          : in  std_logic_vector(7 downto 0);
         stat_tx_local_fault_0               : out std_logic;
         ctl_tx_test_pattern_0               : in  std_logic;
         ctl_tx_test_pattern_enable_0        : in  std_logic;
         ctl_tx_test_pattern_select_0        : in  std_logic;
         ctl_tx_data_pattern_select_0        : in  std_logic;
         ctl_tx_test_pattern_seed_a_0        : in  std_logic_vector(57 downto 0);
         ctl_tx_test_pattern_seed_b_0        : in  std_logic_vector(57 downto 0);
         ctl_tx_prbs31_test_pattern_enable_0 : in  std_logic;
         gt_loopback_in_0                    : in  std_logic_vector(2 downto 0)
         );
   end component;

   signal mAxiReadMaster  : AxiLiteReadMasterType;
   signal mAxiReadSlave   : AxiLiteReadSlaveType;
   signal mAxiWriteMaster : AxiLiteWriteMasterType;
   signal mAxiWriteSlave  : AxiLiteWriteSlaveType;

   signal phyRxd : slv(63 downto 0);
   signal phyRxc : slv(7 downto 0);
   signal phyTxd : slv(63 downto 0);
   signal phyTxc : slv(7 downto 0);

   signal txGtClk  : sl;
   signal phyClock : sl;
   signal phyReset : sl;

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
   status.qplllock <= qplllock(0) and qplllock(1);

   ------------------
   -- Synchronization
   ------------------
   U_AxiLiteAsync : entity surf.AxiLiteAsync
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

   --------------------
   -- Ethernet MAC core
   --------------------
   U_MAC : entity surf.EthMacTop
      generic map (
         TPD_G             => TPD_G,
         JUMBO_G           => JUMBO_G,
         PAUSE_EN_G        => PAUSE_EN_G,
         FIFO_ADDR_WIDTH_G => 12,       -- single 4K UltraRAM
         SYNTH_MODE_G      => "xpm",
         MEMORY_TYPE_G     => "ultra",
         PHY_TYPE_G        => "XGMII",
         PRIM_CONFIG_G     => AXIS_CONFIG_G)
      port map (
         -- Primary Interface
         primClk         => dmaClk,
         primRst         => dmaRst,
         ibMacPrimMaster => dmaObMaster,
         ibMacPrimSlave  => dmaObSlave,
         obMacPrimMaster => dmaIbMaster,
         obMacPrimSlave  => dmaIbSlave,
         -- Ethernet Interface
         ethClk          => phyClock,
         ethRst          => phyReset,
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
   U_TenGigEthGthUltraScaleCore : TenGigEthGthUltraScale156p25MHzCore
      port map (
         -- Clocks
         dclk                                => coreClk,
         gt_drpclk_0                         => coreClk,
         rx_core_clk_0                       => phyClock,
         tx_mii_clk_0                        => txGtClk,
         rx_clk_out_0                        => open,
         rxrecclkout_0                       => open,
         -- Resets
         gt_reset_all_in_0                   => coreRst,
         gt_tx_reset_in_0                    => coreRst,
         gt_rx_reset_in_0                    => coreRst,
         tx_reset_0                          => coreRst,
         rx_reset_0                          => coreRst,
         rx_serdes_reset_0                   => coreRst,
         sys_reset                           => coreRst,
         -- Quad PLL Interface
         qpll0clk_in(0)                      => qplloutclk(0),
         qpll0refclk_in(0)                   => qplloutrefclk(0),
         qpll1clk_in(0)                      => qplloutclk(1),
         qpll1refclk_in(0)                   => qplloutrefclk(1),
         gtwiz_reset_qpll0lock_in            => qplllock(0),
         gtwiz_reset_qpll0reset_out          => qpllRst(0),
         gtwiz_reset_qpll1lock_in            => qplllock(1),
         gtwiz_reset_qpll1reset_out          => qpllRst(1),
         -- MGT Ports
         gt_txp_out(0)                       => gtTxP,
         gt_txn_out(0)                       => gtTxN,
         gt_rxp_in(0)                        => gtRxP,
         gt_rxn_in(0)                        => gtRxN,
         -- PHY Interface
         tx_mii_d_0                          => phyTxd,
         tx_mii_c_0                          => phyTxc,
         rx_mii_d_0                          => phyRxd,
         rx_mii_c_0                          => phyRxc,
         -- Configuration and Status
         txoutclksel_in_0                    => "101",
         rxoutclksel_in_0                    => "101",
         gt_loopback_in_0                    => (others => '0'),
         ctl_rx_test_pattern_0               => '0',
         ctl_rx_data_pattern_select_0        => '0',
         ctl_rx_test_pattern_enable_0        => '0',
         ctl_rx_prbs31_test_pattern_enable_0 => '0',
         ctl_tx_test_pattern_0               => '0',
         ctl_tx_test_pattern_enable_0        => '0',
         ctl_tx_test_pattern_select_0        => '0',
         ctl_tx_data_pattern_select_0        => '0',
         ctl_tx_test_pattern_seed_a_0        => (others => '0'),
         ctl_tx_test_pattern_seed_b_0        => (others => '0'),
         ctl_tx_prbs31_test_pattern_enable_0 => '0',
         gtpowergood_out_0                   => open,
         gt_reset_tx_done_out_0              => status.txRstdone,
         gt_reset_rx_done_out_0              => status.rxRstdone,
         stat_tx_local_fault_0               => open,
         stat_rx_framing_err_0               => open,
         stat_rx_framing_err_valid_0         => open,
         stat_rx_local_fault_0               => open,
         stat_rx_block_lock_0                => open,
         stat_rx_valid_ctrl_code_0           => open,
         stat_rx_status_0                    => open,
         stat_rx_hi_ber_0                    => open,
         stat_rx_bad_code_0                  => open,
         stat_rx_bad_code_valid_0            => open,
         stat_rx_error_0                     => open,
         stat_rx_error_valid_0               => open,
         stat_rx_fifo_error_0                => open,
         -- DRP interface
         gt_drpdo_0                          => open,
         gt_drprdy_0                         => open,
         gt_drpen_0                          => '0',
         gt_drpwe_0                          => '0',
         gt_drpaddr_0                        => (others => '0'),
         gt_drpdi_0                          => (others => '0'),
         -- Transceiver Debug Interface
         gt_dmonitorout_0                    => open,
         gt_eyescandataerror_0               => open,
         gt_eyescanreset_0                   => '0',
         gt_eyescantrigger_0                 => '0',
         gt_pcsrsvdin_0                      => (others => '0'),
         gt_rxbufreset_0                     => '0',
         gt_rxbufstatus_0                    => open,
         gt_rxcdrhold_0                      => '0',
         gt_rxcommadeten_0                   => '0',
         gt_rxdfeagchold_0                   => '0',
         gt_rxdfelpmreset_0                  => '0',
         gt_rxlatclk_0                       => '0',
         gt_rxlpmen_0                        => '0',
         gt_rxpcsreset_0                     => '0',
         gt_rxpmareset_0                     => '0',
         gt_rxpolarity_0                     => gtRxPolarity,
         gt_rxprbscntreset_0                 => '0',
         gt_rxprbserr_0                      => open,
         gt_rxprbssel_0                      => (others => '0'),
         gt_rxrate_0                         => (others => '0'),
         gt_rxslide_in_0                     => '0',
         gt_rxstartofseq_0                   => open,
         gt_txbufstatus_0                    => open,
         gt_txdiffctrl_0                     => gtTxDiffCtrl,
         gt_txinhibit_0                      => '0',
         gt_txlatclk_0                       => '0',
         gt_txmaincursor_0                   => (others => '0'),
         gt_txpcsreset_0                     => '0',
         gt_txpmareset_0                     => '0',
         gt_txpolarity_0                     => gtTxPolarity,
         gt_txpostcursor_0                   => gtTxPostCursor,
         gt_txprbsforceerr_0                 => '0',
         gt_txprbssel_0                      => (others => '0'),
         gt_txprecursor_0                    => gtTxPreCursor);

   ---------------------------
   -- 10GBASE-R's Reset Module
   ---------------------------
   U_TenGigEthRst : entity surf.TenGigEthGthUltraScaleRst
      generic map (
         TPD_G => TPD_G)
      port map (
         coreClk   => coreClk,
         coreRst   => coreRst,
         txGtClk   => txGtClk,
         txRstdone => status.txRstdone,
         rxRstdone => status.rxRstdone,
         phyClk    => phyClock,
         phyRst    => phyReset,
         phyReady  => status.phyReady);

   --------------------------------
   -- Configuration/Status Register
   --------------------------------
   U_TenGigEthReg : entity surf.TenGigEthReg
      generic map (
         TPD_G        => TPD_G,
         EN_AXI_REG_G => EN_AXI_REG_G)
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
