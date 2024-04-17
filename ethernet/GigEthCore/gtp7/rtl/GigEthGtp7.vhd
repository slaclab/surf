-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 1000BASE-X Ethernet for Gtp7
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
use surf.EthMacPkg.all;
use surf.GigEthPkg.all;

entity GigEthGtp7 is
   generic (
      TPD_G           : time                := 1 ns;
      JUMBO_G         : boolean             := true;
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
      -- PHY + MAC signals
      sysClk62           : in  sl;
      sysClk125          : in  sl;
      sysRst125          : in  sl;
      extRst             : in  sl;
      phyReady           : out sl;
      sigDet             : in  sl                     := '1';
      -- Quad PLL Interface
      qPllOutClk         : in  slv(1 downto 0);
      qPllOutRefClk      : in  slv(1 downto 0);
      qPllLock           : in  slv(1 downto 0);
      qPllRefClkLost     : in  slv(1 downto 0);
      qPllReset          : out slv(1 downto 0);
      -- Switch Polarity of TxN/TxP, RxN/RxP
      gtTxPolarity       : in  sl                     := '0';
      gtRxPolarity       : in  sl                     := '0';
      -- MGT Ports
      gtTxP              : out sl;
      gtTxN              : out sl;
      gtRxP              : in  sl;
      gtRxN              : in  sl);
end GigEthGtp7;

architecture mapping of GigEthGtp7 is

   component GigEthGtp7Core
      port (
         gtrefclk                 : in  std_logic;
         gtrefclk_bufg            : in  std_logic;
         txp                      : out std_logic;
         txn                      : out std_logic;
         rxp                      : in  std_logic;
         rxn                      : in  std_logic;
         resetdone                : out std_logic;
         cplllock                 : out std_logic;
         mmcm_reset               : out std_logic;
         txoutclk                 : out std_logic;
         rxoutclk                 : out std_logic;
         userclk                  : in  std_logic;
         userclk2                 : in  std_logic;
         rxuserclk                : in  std_logic;
         rxuserclk2               : in  std_logic;
         pma_reset                : in  std_logic;
         mmcm_locked              : in  std_logic;
         independent_clock_bufg   : in  std_logic;
         gmii_txd                 : in  std_logic_vector (7 downto 0);
         gmii_tx_en               : in  std_logic;
         gmii_tx_er               : in  std_logic;
         gmii_rxd                 : out std_logic_vector (7 downto 0);
         gmii_rx_dv               : out std_logic;
         gmii_rx_er               : out std_logic;
         gmii_isolate             : out std_logic;
         configuration_vector     : in  std_logic_vector (4 downto 0);
         an_interrupt             : out std_logic;
         an_adv_config_vector     : in  std_logic_vector (15 downto 0);
         an_restart_config        : in  std_logic;
         status_vector            : out std_logic_vector (15 downto 0);
         reset                    : in  std_logic;
         gt0_txpmareset_in        : in  std_logic;
         gt0_txpcsreset_in        : in  std_logic;
         gt0_rxpmareset_in        : in  std_logic;
         gt0_rxpcsreset_in        : in  std_logic;
         gt0_rxbufreset_in        : in  std_logic;
         gt0_rxpmaresetdone_out   : out std_logic;
         gt0_rxbufstatus_out      : out std_logic_vector (2 downto 0);
         gt0_txbufstatus_out      : out std_logic_vector (1 downto 0);
         gt0_dmonitorout_out      : out std_logic_vector (14 downto 0);
         gt0_drpaddr_in           : in  std_logic_vector (8 downto 0);
         gt0_drpclk_in            : in  std_logic;
         gt0_drpdi_in             : in  std_logic_vector (15 downto 0);
         gt0_drpdo_out            : out std_logic_vector (15 downto 0);
         gt0_drpen_in             : in  std_logic;
         gt0_drprdy_out           : out std_logic;
         gt0_drpwe_in             : in  std_logic;
         gt0_rxchariscomma_out    : out std_logic_vector (1 downto 0);
         gt0_rxcharisk_out        : out std_logic_vector (1 downto 0);
         gt0_rxbyteisaligned_out  : out std_logic;
         gt0_rxbyterealign_out    : out std_logic;
         gt0_rxcommadet_out       : out std_logic;
         gt0_txpolarity_in        : in  std_logic;
         gt0_txdiffctrl_in        : in  std_logic_vector (3 downto 0);
         gt0_txinhibit_in         : in  std_logic;
         gt0_txpostcursor_in      : in  std_logic_vector (4 downto 0);
         gt0_txprecursor_in       : in  std_logic_vector (4 downto 0);
         gt0_rxpolarity_in        : in  std_logic;
         gt0_txprbssel_in         : in  std_logic_vector (2 downto 0);
         gt0_txprbsforceerr_in    : in  std_logic;
         gt0_rxprbscntreset_in    : in  std_logic;
         gt0_rxprbserr_out        : out std_logic;
         gt0_rxprbssel_in         : in  std_logic_vector (2 downto 0);
         gt0_loopback_in          : in  std_logic_vector (2 downto 0);
         gt0_txresetdone_out      : out std_logic;
         gt0_rxresetdone_out      : out std_logic;
         gt0_rxdisperr_out        : out std_logic_vector (1 downto 0);
         gt0_rxnotintable_out     : out std_logic_vector (1 downto 0);
         gt0_eyescanreset_in      : in  std_logic;
         gt0_eyescandataerror_out : out std_logic;
         gt0_eyescantrigger_in    : in  std_logic;
         gt0_rxcdrhold_in         : in  std_logic;
         gt0_rxlpmhfhold_in       : in  std_logic;
         gt0_rxlpmlfhold_in       : in  std_logic;
         gt0_rxlpmreset_in        : in  std_logic;
         gt0_rxlpmhfoverden_in    : in  std_logic;
         signal_detect            : in  std_logic;
         gt0_pll0outclk_in        : in  std_logic;
         gt0_pll0outrefclk_in     : in  std_logic;
         gt0_pll1outclk_in        : in  std_logic;
         gt0_pll1outrefclk_in     : in  std_logic;
         gt0_pll0refclklost_in    : in  std_logic;
         gt0_pll0lock_in          : in  std_logic;
         gt0_pll0reset_out        : out std_logic
         );
   end component;

   signal config : GigEthConfigType;
   signal status : GigEthStatusType;

   signal mAxiReadMaster  : AxiLiteReadMasterType;
   signal mAxiReadSlave   : AxiLiteReadSlaveType;
   signal mAxiWriteMaster : AxiLiteWriteMasterType;
   signal mAxiWriteSlave  : AxiLiteWriteSlaveType;

   signal gmiiTxClk : sl;
   signal gmiiTxd   : slv(7 downto 0);
   signal gmiiTxEn  : sl;
   signal gmiiTxEr  : sl;

   signal gmiiRxClk : sl;
   signal gmiiRxd   : slv(7 downto 0);
   signal gmiiRxDv  : sl;
   signal gmiiRxEr  : sl;

   signal areset  : sl;
   signal coreRst : sl;

begin

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
         mAxiClk         => sysClk125,
         mAxiClkRst      => sysRst125,
         mAxiReadMaster  => mAxiReadMaster,
         mAxiReadSlave   => mAxiReadSlave,
         mAxiWriteMaster => mAxiWriteMaster,
         mAxiWriteSlave  => mAxiWriteSlave);

   areset <= extRst or config.softRst or sysRst125;

   U_PwrUpRst : entity surf.PwrUpRst
      generic map (
         TPD_G      => TPD_G,
         DURATION_G => 1000)
      port map (
         clk    => sysClk125,
         arst   => areset,
         rstOut => coreRst);

   --------------------
   -- Ethernet MAC core
   --------------------
   U_MAC : entity surf.EthMacTop
      generic map (
         TPD_G           => TPD_G,
         JUMBO_G         => JUMBO_G,
         PAUSE_EN_G      => PAUSE_EN_G,
         PAUSE_512BITS_G => PAUSE_512BITS_C,
         PHY_TYPE_G      => "GMII",
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
         ethClk          => sysClk125,
         ethRst          => sysRst125,
         ethConfig       => config.macConfig,
         ethStatus       => status.macStatus,
         phyReady        => status.phyReady,
         -- GMII PHY Interface
         gmiiRxDv        => gmiiRxDv,
         gmiiRxEr        => gmiiRxEr,
         gmiiRxd         => gmiiRxd,
         gmiiTxEn        => gmiiTxEn,
         gmiiTxEr        => gmiiTxEr,
         gmiiTxd         => gmiiTxd);

   ------------------
   -- 1000BASE-X core
   ------------------
   U_GigEthGtp7Core : GigEthGtp7Core
      port map (
         -- Clocks and Resets
         gtrefclk_bufg          => sysClk125,  -- Used as DRP clock in IP core
         gtrefclk               => sysClk125,  -- Not connected to loads in GTP7 IP core
         independent_clock_bufg => sysClk125,  -- Used as stable clock reference
         txoutclk               => open,
         rxoutclk               => open,
         userclk                => sysClk62,
         userclk2               => sysClk125,
         rxuserclk              => sysClk62,
         rxuserclk2             => sysClk62,
         reset                  => coreRst,
         pma_reset              => coreRst,
         resetdone              => open,
         mmcm_locked            => '1',
         mmcm_reset             => open,
         cplllock               => open,
         -- PHY Interface
         gmii_txd               => gmiiTxd,
         gmii_tx_en             => gmiiTxEn,
         gmii_tx_er             => gmiiTxEr,
         gmii_rxd               => gmiiRxd,
         gmii_rx_dv             => gmiiRxDv,
         gmii_rx_er             => gmiiRxEr,
         gmii_isolate           => open,
         -- MGT Ports
         txp                    => gtTxP,
         txn                    => gtTxN,
         rxp                    => gtRxP,
         rxn                    => gtRxN,
         -- Quad PLL Interface
         gt0_pll0outclk_in      => qPllOutClk(0),
         gt0_pll0outrefclk_in   => qPllOutRefClk(0),
         gt0_pll0lock_in        => qPllLock(0),
         gt0_pll0refclklost_in  => qPllRefClkLost(0),
         gt0_pll0reset_out      => qPllReset(0),
         gt0_pll1outclk_in      => qPllOutClk(1),
         gt0_pll1outrefclk_in   => qPllOutRefClk(1),
         -- Configuration and Status
         an_restart_config      => '0',
         an_adv_config_vector   => GIG_ETH_AN_ADV_CONFIG_INIT_C,
         an_interrupt           => open,
         configuration_vector   => config.coreConfig,
         status_vector          => status.coreStatus,
         signal_detect          => sigDet,

         -- Debug and Misc. IO

         gt0_dmonitorout_out      => open,
         gt0_drpaddr_in           => (others => '0'),
         gt0_drpclk_in            => sysClk125,
         gt0_drpdi_in             => (others => '0'),
         gt0_drpdo_out            => open,
         gt0_drpen_in             => '0',
         gt0_drprdy_out           => open,
         gt0_drpwe_in             => '0',
         gt0_eyescandataerror_out => open,
         gt0_eyescanreset_in      => '0',
         gt0_eyescantrigger_in    => '0',
         gt0_loopback_in          => (others => '0'),
         gt0_rxbufreset_in        => '0',
         gt0_rxbufstatus_out      => open,
         gt0_rxbyteisaligned_out  => open,
         gt0_rxbyterealign_out    => open,
         gt0_rxcdrhold_in         => '0',
         gt0_rxcommadet_out       => open,
         gt0_rxlpmhfhold_in       => '0',
         gt0_rxlpmhfoverden_in    => '0',
         gt0_rxlpmlfhold_in       => '0',
         gt0_rxlpmreset_in        => '0',
         gt0_rxpcsreset_in        => '0',
         gt0_rxpmareset_in        => '0',
         gt0_rxpmaresetdone_out   => open,
         gt0_rxpolarity_in        => gtRxPolarity,
         gt0_rxprbscntreset_in    => '0',
         gt0_rxprbserr_out        => open,
         gt0_rxprbssel_in         => (others => '0'),
         gt0_rxresetdone_out      => open,
         gt0_txbufstatus_out      => open,
         gt0_txdiffctrl_in        => "1000",
         gt0_txinhibit_in         => '0',
         gt0_txpcsreset_in        => '0',
         gt0_txpmareset_in        => '0',
         gt0_txpolarity_in        => gtTxPolarity,
         gt0_txpostcursor_in      => (others => '0'),
         gt0_txprbsforceerr_in    => '0',
         gt0_txprbssel_in         => (others => '0'),
         gt0_txprecursor_in       => (others => '0'),
         gt0_txresetdone_out      => open);

   status.phyReady <= status.coreStatus(1);
   phyReady        <= status.phyReady;
   qPllReset(1)    <= '1';              -- No using QPLL[1]

   --------------------------------
   -- Configuration/Status Register
   --------------------------------
   U_GigEthReg : entity surf.GigEthReg
      generic map (
         TPD_G        => TPD_G,
         EN_AXI_REG_G => EN_AXI_REG_G)
      port map (
         -- Local Configurations
         localMac       => localMac,
         -- Clocks and resets
         clk            => sysClk125,
         rst            => sysRst125,
         -- AXI-Lite Register Interface
         axiReadMaster  => mAxiReadMaster,
         axiReadSlave   => mAxiReadSlave,
         axiWriteMaster => mAxiWriteMaster,
         axiWriteSlave  => mAxiWriteSlave,
         -- Configuration and Status Interface
         config         => config,
         status         => status);

end mapping;
