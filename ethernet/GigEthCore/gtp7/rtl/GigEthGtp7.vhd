-------------------------------------------------------------------------------
-- File       : GigEthGtp7.vhd
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.EthMacPkg.all;
use work.GigEthPkg.all;

entity GigEthGtp7 is
   generic (
      TPD_G           : time                := 1 ns;
      PAUSE_EN_G      : boolean             := true;
      PAUSE_512BITS_G : positive            := 8;
      -- AXI-Lite Configurations
      EN_AXI_REG_G    : boolean             := false;
      -- AXI Streaming Configurations
      AXIS_CONFIG_G   : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);
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
         mAxiClk         => sysClk125,
         mAxiClkRst      => sysRst125,
         mAxiReadMaster  => mAxiReadMaster,
         mAxiReadSlave   => mAxiReadSlave,
         mAxiWriteMaster => mAxiWriteMaster,
         mAxiWriteSlave  => mAxiWriteSlave);

   areset <= extRst or config.softRst or sysRst125;

   U_PwrUpRst : entity work.PwrUpRst
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
   U_MAC : entity work.EthMacTop
      generic map (
         TPD_G           => TPD_G,
         PAUSE_EN_G      => PAUSE_EN_G,
         PAUSE_512BITS_G => PAUSE_512BITS_G,
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
   U_GigEthGtp7Core : entity work.GigEthGtp7Core
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

         gt0_dmonitorout_out       => open ,
         gt0_drpaddr_in            => (others=>'0'),
         gt0_drpclk_in             => sysClk125,
         gt0_drpdi_in              => (others=>'0'),
         gt0_drpdo_out             => open,
         gt0_drpen_in              => '0',
         gt0_drprdy_out            => open,
         gt0_drpwe_in              => '0',
         gt0_eyescandataerror_out  => open,
         gt0_eyescanreset_in       => '0',
         gt0_eyescantrigger_in     => '0',
         gt0_loopback_in           => (others=>'0'),
         gt0_rxbufreset_in         => '0',
         gt0_rxbufstatus_out       => open,
         gt0_rxbyteisaligned_out   => open,
         gt0_rxbyterealign_out     => open,
         gt0_rxcdrhold_in          => '0',
         gt0_rxcommadet_out        => open,
         gt0_rxlpmhfhold_in        => '0',
         gt0_rxlpmhfoverden_in     => '0' ,
         gt0_rxlpmlfhold_in        => '0',
         gt0_rxlpmreset_in         => '0'    ,
         gt0_rxpcsreset_in         => '0',
         gt0_rxpmareset_in         => '0',
         gt0_rxpmaresetdone_out    => open,
         gt0_rxpolarity_in         => gtRxPolarity,
         gt0_rxprbscntreset_in     => '0',
         gt0_rxprbserr_out         => open,
         gt0_rxprbssel_in          => (others=>'0'),
         gt0_rxresetdone_out       => open,
         gt0_txbufstatus_out       => open,
         gt0_txdiffctrl_in         => "1000",
         gt0_txinhibit_in          => '0',
         gt0_txpcsreset_in         => '0',
         gt0_txpmareset_in         => '0',
         gt0_txpolarity_in         => gtTxPolarity,
         gt0_txpostcursor_in       => (others=>'0'),
         gt0_txprbsforceerr_in     => '0',
         gt0_txprbssel_in          => (others=>'0'),
         gt0_txprecursor_in        => (others=>'0'),
         gt0_txresetdone_out       => open);

   status.phyReady <= status.coreStatus(1);
   phyReady        <= status.phyReady;
   qPllReset(1)    <= '1';              -- No using QPLL[1]   

   --------------------------------     
   -- Configuration/Status Register   
   --------------------------------     
   U_GigEthReg : entity work.GigEthReg
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
