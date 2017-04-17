-------------------------------------------------------------------------------
-- File       : XauiGthUltraScale.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-08
-- Last update: 2016-09-29
-------------------------------------------------------------------------------
-- Description: 10 GigE XAUI for GTH Ultra Scale
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
use work.XauiPkg.all;
use work.EthMacPkg.all;

library unisim;
use unisim.vcomponents.all;

entity XauiGthUltraScale is
   generic (
      TPD_G            : time                := 1 ns;
      -- XAUI Configurations
      XAUI_20GIGE_G    : boolean             := false;
      REF_CLK_FREQ_G   : real                := 156.25E+6;  -- Support 125MHz, 156.25MHz, or 312.5MHz
      -- AXI-Lite Configurations
      EN_AXI_REG_G     : boolean             := false;
      AXI_ERROR_RESP_G : slv(1 downto 0)     := AXI_RESP_SLVERR_C;
      -- AXI Streaming Configurations
      AXIS_CONFIG_G    : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);
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
      extRst             : in  sl;
      phyClk             : out sl;
      phyRst             : out sl;
      phyReady           : out sl;
      -- Transceiver Debug Interface
      gtTxPreCursor      : in  slv(19 downto 0)       := (others => '0');
      gtTxPostCursor     : in  slv(19 downto 0)       := (others => '0');
      gtTxDiffCtrl       : in  slv(15 downto 0)       := x"CCCC";
      gtRxPolarity       : in  slv(3 downto 0)        := x"0";
      gtTxPolarity       : in  slv(3 downto 0)        := x"0";
      -- MGT Ports
      refClk             : in  sl;      -- 125MHz, 156.25MHz, or 312.5MHz
      gtTxP              : out slv(3 downto 0);
      gtTxN              : out slv(3 downto 0);
      gtRxP              : in  slv(3 downto 0);
      gtRxN              : in  slv(3 downto 0));  
end XauiGthUltraScale;

architecture mapping of XauiGthUltraScale is

   signal phyRxd : slv(63 downto 0);
   signal phyRxc : slv(7 downto 0);
   signal phyTxd : slv(63 downto 0);
   signal phyTxc : slv(7 downto 0);

   signal phyClock  : sl;
   signal phyClkBuf : sl;
   signal phyReset  : sl;

   signal config : XauiConfig;
   signal status : XauiStatus;

   signal macRxAxisMaster : AxiStreamMasterType;
   signal macRxAxisCtrl   : AxiStreamCtrlType;
   signal macTxAxisMaster : AxiStreamMasterType;
   signal macTxAxisSlave  : AxiStreamSlaveType;
   
begin

   phyClk   <= phyClock;
   phyRst   <= phyReset;
   phyReady <= status.phyReady;

   --------------------
   -- Ethernet MAC core
   --------------------
   U_MAC : entity work.EthMacTop
      generic map (
         TPD_G         => TPD_G,
         PHY_TYPE_G    => "XGMII",
         PRIM_CONFIG_G => AXIS_CONFIG_G)
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

   --------------------
   -- 10 GigE XAUI Core
   --------------------
   GEN_10GIGE : if (XAUI_20GIGE_G = false) generate
      GEN_125MHz : if (REF_CLK_FREQ_G = 125.00E+6) generate
         U_XauiGthUltraScaleCore : entity work.XauiGthUltraScale125MHz10GigECore
            port map (
               -- Clocks and Resets
               dclk                 => phyClock,
               reset                => status.areset,
               clk156_out           => phyClock,
               clk156_lock          => status.clkLock,
               refclk               => refClk,
               -- PHY Interface
               xgmii_txd            => phyTxd,
               xgmii_txc            => phyTxc,
               xgmii_rxd            => phyRxd,
               xgmii_rxc            => phyRxc,
               -- MGT Ports
               xaui_tx_l0_p         => gtTxP(0),
               xaui_tx_l0_n         => gtTxN(0),
               xaui_tx_l1_p         => gtTxP(1),
               xaui_tx_l1_n         => gtTxN(1),
               xaui_tx_l2_p         => gtTxP(2),
               xaui_tx_l2_n         => gtTxN(2),
               xaui_tx_l3_p         => gtTxP(3),
               xaui_tx_l3_n         => gtTxN(3),
               xaui_rx_l0_p         => gtRxP(0),
               xaui_rx_l0_n         => gtRxN(0),
               xaui_rx_l1_p         => gtRxP(1),
               xaui_rx_l1_n         => gtRxN(1),
               xaui_rx_l2_p         => gtRxP(2),
               xaui_rx_l2_n         => gtRxN(2),
               xaui_rx_l3_p         => gtRxP(3),
               xaui_rx_l3_n         => gtRxN(3),
               -- DRP
               gt0_drpaddr          => (others => '0'),
               gt0_drpen            => '0',
               gt0_drpdi            => X"0000",
               gt0_drpdo            => open,
               gt0_drprdy           => open,
               gt0_drpwe            => '0',
               gt1_drpaddr          => (others => '0'),
               gt1_drpen            => '0',
               gt1_drpdi            => X"0000",
               gt1_drpdo            => open,
               gt1_drprdy           => open,
               gt1_drpwe            => '0',
               gt2_drpaddr          => (others => '0'),
               gt2_drpen            => '0',
               gt2_drpdi            => X"0000",
               gt2_drpdo            => open,
               gt2_drprdy           => open,
               gt2_drpwe            => '0',
               gt3_drpaddr          => (others => '0'),
               gt3_drpen            => '0',
               gt3_drpdi            => X"0000",
               gt3_drpdo            => open,
               gt3_drprdy           => open,
               gt3_drpwe            => '0',
               -- TX Reset and Initialisation
               gt_txpmareset        => B"0000",
               gt_txpcsreset        => B"0000",
               gt_txresetdone       => open,
               -- RX Reset and Initialisation
               gt_rxpmareset        => B"0000",
               gt_rxpcsreset        => B"0000",
               gt_rxpmaresetdone    => open,
               gt_rxresetdone       => open,
               -- Clocking
               gt_rxbufstatus       => open,
               gt_txphaligndone     => open,
               gt_txphinitdone      => open,
               gt_txdlysresetdone   => open,
               gt_qplllock          => open,
               -- Signal Integrity adn Functionality
               -- Eye Scan
               gt_eyescantrigger    => B"0000",
               gt_eyescanreset      => B"0000",
               gt_eyescandataerror  => open,
               gt_rxrate            => X"000",
               -- Loopback
               gt_loopback          => X"000",
               -- Polarity
               gt_rxpolarity        => gtRxPolarity,
               gt_txpolarity        => gtTxPolarity,
               -- RX Decision Feedback Equalizer (DFE)
               gt_rxlpmen           => B"1111",
               gt_rxdfelpmreset     => B"0000",
               -- TX Driver
               gt_txpostcursor      => gtTxPostCursor,
               gt_txprecursor       => gtTxPreCursor,
               gt_txdiffctrl        => gtTxDiffCtrl,
               gt_txinhibit         => "0000",
               -- PRBS
               gt_rxprbscntreset    => B"0000",
               gt_rxprbserr         => open,
               gt_rxprbssel         => X"0000",
               gt_txprbssel         => X"0000",
               gt_txprbsforceerr    => B"0000",
               gt_rxcdrhold         => B"0000",
               gt_dmonitorout       => open,
               gt_pcsrsvdin         => (others => '0'),
               -- Configuration and Status
               gt_rxdisperr         => open,
               gt_rxnotintable      => open,
               gt_rxcommadet        => open,
               signal_detect        => (others => '1'),
               debug                => status.debugVector,
               configuration_vector => config.configVector,
               status_vector        => status.statusVector);
      end generate;
      GEN_156p25MHz : if (REF_CLK_FREQ_G = 156.25E+6) generate
         U_XauiGthUltraScaleCore : entity work.XauiGthUltraScale156p25MHz10GigECore
            port map (
               -- Clocks and Resets
               dclk                 => phyClock,
               reset                => status.areset,
               clk156_out           => phyClock,
               clk156_lock          => status.clkLock,
               refclk               => refClk,
               -- PHY Interface
               xgmii_txd            => phyTxd,
               xgmii_txc            => phyTxc,
               xgmii_rxd            => phyRxd,
               xgmii_rxc            => phyRxc,
               -- MGT Ports
               xaui_tx_l0_p         => gtTxP(0),
               xaui_tx_l0_n         => gtTxN(0),
               xaui_tx_l1_p         => gtTxP(1),
               xaui_tx_l1_n         => gtTxN(1),
               xaui_tx_l2_p         => gtTxP(2),
               xaui_tx_l2_n         => gtTxN(2),
               xaui_tx_l3_p         => gtTxP(3),
               xaui_tx_l3_n         => gtTxN(3),
               xaui_rx_l0_p         => gtRxP(0),
               xaui_rx_l0_n         => gtRxN(0),
               xaui_rx_l1_p         => gtRxP(1),
               xaui_rx_l1_n         => gtRxN(1),
               xaui_rx_l2_p         => gtRxP(2),
               xaui_rx_l2_n         => gtRxN(2),
               xaui_rx_l3_p         => gtRxP(3),
               xaui_rx_l3_n         => gtRxN(3),
               -- DRP
               gt0_drpaddr          => (others => '0'),
               gt0_drpen            => '0',
               gt0_drpdi            => X"0000",
               gt0_drpdo            => open,
               gt0_drprdy           => open,
               gt0_drpwe            => '0',
               gt1_drpaddr          => (others => '0'),
               gt1_drpen            => '0',
               gt1_drpdi            => X"0000",
               gt1_drpdo            => open,
               gt1_drprdy           => open,
               gt1_drpwe            => '0',
               gt2_drpaddr          => (others => '0'),
               gt2_drpen            => '0',
               gt2_drpdi            => X"0000",
               gt2_drpdo            => open,
               gt2_drprdy           => open,
               gt2_drpwe            => '0',
               gt3_drpaddr          => (others => '0'),
               gt3_drpen            => '0',
               gt3_drpdi            => X"0000",
               gt3_drpdo            => open,
               gt3_drprdy           => open,
               gt3_drpwe            => '0',
               -- TX Reset and Initialisation
               gt_txpmareset        => B"0000",
               gt_txpcsreset        => B"0000",
               gt_txresetdone       => open,
               -- RX Reset and Initialisation
               gt_rxpmareset        => B"0000",
               gt_rxpcsreset        => B"0000",
               gt_rxpmaresetdone    => open,
               gt_rxresetdone       => open,
               -- Clocking
               gt_rxbufstatus       => open,
               gt_txphaligndone     => open,
               gt_txphinitdone      => open,
               gt_txdlysresetdone   => open,
               gt_qplllock          => open,
               -- Signal Integrity adn Functionality
               -- Eye Scan
               gt_eyescantrigger    => B"0000",
               gt_eyescanreset      => B"0000",
               gt_eyescandataerror  => open,
               gt_rxrate            => X"000",
               -- Loopback
               gt_loopback          => X"000",
               -- Polarity
               gt_rxpolarity        => gtRxPolarity,
               gt_txpolarity        => gtTxPolarity,
               -- RX Decision Feedback Equalizer (DFE)
               gt_rxlpmen           => B"1111",
               gt_rxdfelpmreset     => B"0000",
               -- TX Driver
               gt_txpostcursor      => gtTxPostCursor,
               gt_txprecursor       => gtTxPreCursor,
               gt_txdiffctrl        => gtTxDiffCtrl,
               gt_txinhibit         => "0000",
               -- PRBS
               gt_rxprbscntreset    => B"0000",
               gt_rxprbserr         => open,
               gt_rxprbssel         => X"0000",
               gt_txprbssel         => X"0000",
               gt_txprbsforceerr    => B"0000",
               gt_rxcdrhold         => B"0000",
               gt_dmonitorout       => open,
               gt_pcsrsvdin         => (others => '0'),
               -- Configuration and Status
               gt_rxdisperr         => open,
               gt_rxnotintable      => open,
               gt_rxcommadet        => open,
               signal_detect        => (others => '1'),
               debug                => status.debugVector,
               configuration_vector => config.configVector,
               status_vector        => status.statusVector); 
      end generate;
      GEN_312p5MHz : if (REF_CLK_FREQ_G = 312.50E+6) generate
         U_XauiGthUltraScaleCore : entity work.XauiGthUltraScale312p5MHz10GigECore
            port map (
               -- Clocks and Resets
               dclk                 => phyClock,
               reset                => status.areset,
               clk156_out           => phyClock,
               clk156_lock          => status.clkLock,
               refclk               => refClk,
               -- PHY Interface
               xgmii_txd            => phyTxd,
               xgmii_txc            => phyTxc,
               xgmii_rxd            => phyRxd,
               xgmii_rxc            => phyRxc,
               -- MGT Ports
               xaui_tx_l0_p         => gtTxP(0),
               xaui_tx_l0_n         => gtTxN(0),
               xaui_tx_l1_p         => gtTxP(1),
               xaui_tx_l1_n         => gtTxN(1),
               xaui_tx_l2_p         => gtTxP(2),
               xaui_tx_l2_n         => gtTxN(2),
               xaui_tx_l3_p         => gtTxP(3),
               xaui_tx_l3_n         => gtTxN(3),
               xaui_rx_l0_p         => gtRxP(0),
               xaui_rx_l0_n         => gtRxN(0),
               xaui_rx_l1_p         => gtRxP(1),
               xaui_rx_l1_n         => gtRxN(1),
               xaui_rx_l2_p         => gtRxP(2),
               xaui_rx_l2_n         => gtRxN(2),
               xaui_rx_l3_p         => gtRxP(3),
               xaui_rx_l3_n         => gtRxN(3),
               -- DRP
               gt0_drpaddr          => (others => '0'),
               gt0_drpen            => '0',
               gt0_drpdi            => X"0000",
               gt0_drpdo            => open,
               gt0_drprdy           => open,
               gt0_drpwe            => '0',
               gt1_drpaddr          => (others => '0'),
               gt1_drpen            => '0',
               gt1_drpdi            => X"0000",
               gt1_drpdo            => open,
               gt1_drprdy           => open,
               gt1_drpwe            => '0',
               gt2_drpaddr          => (others => '0'),
               gt2_drpen            => '0',
               gt2_drpdi            => X"0000",
               gt2_drpdo            => open,
               gt2_drprdy           => open,
               gt2_drpwe            => '0',
               gt3_drpaddr          => (others => '0'),
               gt3_drpen            => '0',
               gt3_drpdi            => X"0000",
               gt3_drpdo            => open,
               gt3_drprdy           => open,
               gt3_drpwe            => '0',
               -- TX Reset and Initialisation
               gt_txpmareset        => B"0000",
               gt_txpcsreset        => B"0000",
               gt_txresetdone       => open,
               -- RX Reset and Initialisation
               gt_rxpmareset        => B"0000",
               gt_rxpcsreset        => B"0000",
               gt_rxpmaresetdone    => open,
               gt_rxresetdone       => open,
               -- Clocking
               gt_rxbufstatus       => open,
               gt_txphaligndone     => open,
               gt_txphinitdone      => open,
               gt_txdlysresetdone   => open,
               gt_qplllock          => open,
               -- Signal Integrity adn Functionality
               -- Eye Scan
               gt_eyescantrigger    => B"0000",
               gt_eyescanreset      => B"0000",
               gt_eyescandataerror  => open,
               gt_rxrate            => X"000",
               -- Loopback
               gt_loopback          => X"000",
               -- Polarity
               gt_rxpolarity        => gtRxPolarity,
               gt_txpolarity        => gtTxPolarity,
               -- RX Decision Feedback Equalizer (DFE)
               gt_rxlpmen           => B"1111",
               gt_rxdfelpmreset     => B"0000",
               -- TX Driver
               gt_txpostcursor      => gtTxPostCursor,
               gt_txprecursor       => gtTxPreCursor,
               gt_txdiffctrl        => gtTxDiffCtrl,
               gt_txinhibit         => "0000",
               -- PRBS
               gt_rxprbscntreset    => B"0000",
               gt_rxprbserr         => open,
               gt_rxprbssel         => X"0000",
               gt_txprbssel         => X"0000",
               gt_txprbsforceerr    => B"0000",
               gt_rxcdrhold         => B"0000",
               gt_dmonitorout       => open,
               gt_pcsrsvdin         => (others => '0'),
               -- Configuration and Status
               gt_rxdisperr         => open,
               gt_rxnotintable      => open,
               gt_rxcommadet        => open,
               signal_detect        => (others => '1'),
               debug                => status.debugVector,
               configuration_vector => config.configVector,
               status_vector        => status.statusVector);
      end generate;
   end generate;

   --------------------
   -- 20 GigE XAUI Core
   --------------------
   GEN_20GIGE : if (XAUI_20GIGE_G = true) generate
      GEN_125MHz : if (REF_CLK_FREQ_G = 125.00E+6) generate
         U_XauiGthUltraScaleCore : entity work.XauiGthUltraScale125MHz20GigECore
            port map (
               -- Clocks and Resets
               dclk                 => phyClock,
               reset                => status.areset,
               clk156_out           => phyClock,
               clk156_lock          => status.clkLock,
               refclk               => refClk,
               -- PHY Interface
               xgmii_txd            => phyTxd,
               xgmii_txc            => phyTxc,
               xgmii_rxd            => phyRxd,
               xgmii_rxc            => phyRxc,
               -- MGT Ports
               xaui_tx_l0_p         => gtTxP(0),
               xaui_tx_l0_n         => gtTxN(0),
               xaui_tx_l1_p         => gtTxP(1),
               xaui_tx_l1_n         => gtTxN(1),
               xaui_tx_l2_p         => gtTxP(2),
               xaui_tx_l2_n         => gtTxN(2),
               xaui_tx_l3_p         => gtTxP(3),
               xaui_tx_l3_n         => gtTxN(3),
               xaui_rx_l0_p         => gtRxP(0),
               xaui_rx_l0_n         => gtRxN(0),
               xaui_rx_l1_p         => gtRxP(1),
               xaui_rx_l1_n         => gtRxN(1),
               xaui_rx_l2_p         => gtRxP(2),
               xaui_rx_l2_n         => gtRxN(2),
               xaui_rx_l3_p         => gtRxP(3),
               xaui_rx_l3_n         => gtRxN(3),
               -- DRP
               gt0_drpaddr          => (others => '0'),
               gt0_drpen            => '0',
               gt0_drpdi            => X"0000",
               gt0_drpdo            => open,
               gt0_drprdy           => open,
               gt0_drpwe            => '0',
               gt1_drpaddr          => (others => '0'),
               gt1_drpen            => '0',
               gt1_drpdi            => X"0000",
               gt1_drpdo            => open,
               gt1_drprdy           => open,
               gt1_drpwe            => '0',
               gt2_drpaddr          => (others => '0'),
               gt2_drpen            => '0',
               gt2_drpdi            => X"0000",
               gt2_drpdo            => open,
               gt2_drprdy           => open,
               gt2_drpwe            => '0',
               gt3_drpaddr          => (others => '0'),
               gt3_drpen            => '0',
               gt3_drpdi            => X"0000",
               gt3_drpdo            => open,
               gt3_drprdy           => open,
               gt3_drpwe            => '0',
               -- TX Reset and Initialisation
               gt_txpmareset        => B"0000",
               gt_txpcsreset        => B"0000",
               gt_txresetdone       => open,
               -- RX Reset and Initialisation
               gt_rxpmareset        => B"0000",
               gt_rxpcsreset        => B"0000",
               gt_rxpmaresetdone    => open,
               gt_rxresetdone       => open,
               -- Clocking
               gt_rxbufstatus       => open,
               gt_txphaligndone     => open,
               gt_txphinitdone      => open,
               gt_txdlysresetdone   => open,
               gt_qplllock          => open,
               -- Signal Integrity adn Functionality
               -- Eye Scan
               gt_eyescantrigger    => B"0000",
               gt_eyescanreset      => B"0000",
               gt_eyescandataerror  => open,
               gt_rxrate            => X"000",
               -- Loopback
               gt_loopback          => X"000",
               -- Polarity
               gt_rxpolarity        => gtRxPolarity,
               gt_txpolarity        => gtTxPolarity,
               -- RX Decision Feedback Equalizer (DFE)
               gt_rxlpmen           => B"1111",
               gt_rxdfelpmreset     => B"0000",
               -- TX Driver
               gt_txpostcursor      => gtTxPostCursor,
               gt_txprecursor       => gtTxPreCursor,
               gt_txdiffctrl        => gtTxDiffCtrl,
               gt_txinhibit         => "0000",
               -- PRBS
               gt_rxprbscntreset    => B"0000",
               gt_rxprbserr         => open,
               gt_rxprbssel         => X"0000",
               gt_txprbssel         => X"0000",
               gt_txprbsforceerr    => B"0000",
               gt_rxcdrhold         => B"0000",
               gt_dmonitorout       => open,
               gt_pcsrsvdin         => (others => '0'),
               -- Configuration and Status
               gt_rxdisperr         => open,
               gt_rxnotintable      => open,
               gt_rxcommadet        => open,
               signal_detect        => (others => '1'),
               debug                => status.debugVector,
               configuration_vector => config.configVector,
               status_vector        => status.statusVector); 
      end generate;
      GEN_156p25MHz : if (REF_CLK_FREQ_G = 156.25E+6) generate
         U_XauiGthUltraScaleCore : entity work.XauiGthUltraScale156p25MHz20GigECore
            port map (
               -- Clocks and Resets
               dclk                 => phyClock,
               reset                => status.areset,
               clk156_out           => phyClock,
               clk156_lock          => status.clkLock,
               refclk               => refClk,
               -- PHY Interface
               xgmii_txd            => phyTxd,
               xgmii_txc            => phyTxc,
               xgmii_rxd            => phyRxd,
               xgmii_rxc            => phyRxc,
               -- MGT Ports
               xaui_tx_l0_p         => gtTxP(0),
               xaui_tx_l0_n         => gtTxN(0),
               xaui_tx_l1_p         => gtTxP(1),
               xaui_tx_l1_n         => gtTxN(1),
               xaui_tx_l2_p         => gtTxP(2),
               xaui_tx_l2_n         => gtTxN(2),
               xaui_tx_l3_p         => gtTxP(3),
               xaui_tx_l3_n         => gtTxN(3),
               xaui_rx_l0_p         => gtRxP(0),
               xaui_rx_l0_n         => gtRxN(0),
               xaui_rx_l1_p         => gtRxP(1),
               xaui_rx_l1_n         => gtRxN(1),
               xaui_rx_l2_p         => gtRxP(2),
               xaui_rx_l2_n         => gtRxN(2),
               xaui_rx_l3_p         => gtRxP(3),
               xaui_rx_l3_n         => gtRxN(3),
               -- DRP
               gt0_drpaddr          => (others => '0'),
               gt0_drpen            => '0',
               gt0_drpdi            => X"0000",
               gt0_drpdo            => open,
               gt0_drprdy           => open,
               gt0_drpwe            => '0',
               gt1_drpaddr          => (others => '0'),
               gt1_drpen            => '0',
               gt1_drpdi            => X"0000",
               gt1_drpdo            => open,
               gt1_drprdy           => open,
               gt1_drpwe            => '0',
               gt2_drpaddr          => (others => '0'),
               gt2_drpen            => '0',
               gt2_drpdi            => X"0000",
               gt2_drpdo            => open,
               gt2_drprdy           => open,
               gt2_drpwe            => '0',
               gt3_drpaddr          => (others => '0'),
               gt3_drpen            => '0',
               gt3_drpdi            => X"0000",
               gt3_drpdo            => open,
               gt3_drprdy           => open,
               gt3_drpwe            => '0',
               -- TX Reset and Initialisation
               gt_txpmareset        => B"0000",
               gt_txpcsreset        => B"0000",
               gt_txresetdone       => open,
               -- RX Reset and Initialisation
               gt_rxpmareset        => B"0000",
               gt_rxpcsreset        => B"0000",
               gt_rxpmaresetdone    => open,
               gt_rxresetdone       => open,
               -- Clocking
               gt_rxbufstatus       => open,
               gt_txphaligndone     => open,
               gt_txphinitdone      => open,
               gt_txdlysresetdone   => open,
               gt_qplllock          => open,
               -- Signal Integrity adn Functionality
               -- Eye Scan
               gt_eyescantrigger    => B"0000",
               gt_eyescanreset      => B"0000",
               gt_eyescandataerror  => open,
               gt_rxrate            => X"000",
               -- Loopback
               gt_loopback          => X"000",
               -- Polarity
               gt_rxpolarity        => gtRxPolarity,
               gt_txpolarity        => gtTxPolarity,
               -- RX Decision Feedback Equalizer (DFE)
               gt_rxlpmen           => B"1111",
               gt_rxdfelpmreset     => B"0000",
               -- TX Driver
               gt_txpostcursor      => gtTxPostCursor,
               gt_txprecursor       => gtTxPreCursor,
               gt_txdiffctrl        => gtTxDiffCtrl,
               gt_txinhibit         => "0000",
               -- PRBS
               gt_rxprbscntreset    => B"0000",
               gt_rxprbserr         => open,
               gt_rxprbssel         => X"0000",
               gt_txprbssel         => X"0000",
               gt_txprbsforceerr    => B"0000",
               gt_rxcdrhold         => B"0000",
               gt_dmonitorout       => open,
               gt_pcsrsvdin         => (others => '0'),
               -- Configuration and Status
               gt_rxdisperr         => open,
               gt_rxnotintable      => open,
               gt_rxcommadet        => open,
               signal_detect        => (others => '1'),
               debug                => status.debugVector,
               configuration_vector => config.configVector,
               status_vector        => status.statusVector);
      end generate;
      GEN_312p5MHz : if (REF_CLK_FREQ_G = 312.50E+6) generate
         U_XauiGthUltraScaleCore : entity work.XauiGthUltraScale312p5MHz20GigECore
            port map (
               -- Clocks and Resets
               dclk                 => phyClock,
               reset                => status.areset,
               clk156_out           => phyClock,
               clk156_lock          => status.clkLock,
               refclk               => refClk,
               -- PHY Interface
               xgmii_txd            => phyTxd,
               xgmii_txc            => phyTxc,
               xgmii_rxd            => phyRxd,
               xgmii_rxc            => phyRxc,
               -- MGT Ports
               xaui_tx_l0_p         => gtTxP(0),
               xaui_tx_l0_n         => gtTxN(0),
               xaui_tx_l1_p         => gtTxP(1),
               xaui_tx_l1_n         => gtTxN(1),
               xaui_tx_l2_p         => gtTxP(2),
               xaui_tx_l2_n         => gtTxN(2),
               xaui_tx_l3_p         => gtTxP(3),
               xaui_tx_l3_n         => gtTxN(3),
               xaui_rx_l0_p         => gtRxP(0),
               xaui_rx_l0_n         => gtRxN(0),
               xaui_rx_l1_p         => gtRxP(1),
               xaui_rx_l1_n         => gtRxN(1),
               xaui_rx_l2_p         => gtRxP(2),
               xaui_rx_l2_n         => gtRxN(2),
               xaui_rx_l3_p         => gtRxP(3),
               xaui_rx_l3_n         => gtRxN(3),
               -- DRP
               gt0_drpaddr          => (others => '0'),
               gt0_drpen            => '0',
               gt0_drpdi            => X"0000",
               gt0_drpdo            => open,
               gt0_drprdy           => open,
               gt0_drpwe            => '0',
               gt1_drpaddr          => (others => '0'),
               gt1_drpen            => '0',
               gt1_drpdi            => X"0000",
               gt1_drpdo            => open,
               gt1_drprdy           => open,
               gt1_drpwe            => '0',
               gt2_drpaddr          => (others => '0'),
               gt2_drpen            => '0',
               gt2_drpdi            => X"0000",
               gt2_drpdo            => open,
               gt2_drprdy           => open,
               gt2_drpwe            => '0',
               gt3_drpaddr          => (others => '0'),
               gt3_drpen            => '0',
               gt3_drpdi            => X"0000",
               gt3_drpdo            => open,
               gt3_drprdy           => open,
               gt3_drpwe            => '0',
               -- TX Reset and Initialisation
               gt_txpmareset        => B"0000",
               gt_txpcsreset        => B"0000",
               gt_txresetdone       => open,
               -- RX Reset and Initialisation
               gt_rxpmareset        => B"0000",
               gt_rxpcsreset        => B"0000",
               gt_rxpmaresetdone    => open,
               gt_rxresetdone       => open,
               -- Clocking
               gt_rxbufstatus       => open,
               gt_txphaligndone     => open,
               gt_txphinitdone      => open,
               gt_txdlysresetdone   => open,
               gt_qplllock          => open,
               -- Signal Integrity adn Functionality
               -- Eye Scan
               gt_eyescantrigger    => B"0000",
               gt_eyescanreset      => B"0000",
               gt_eyescandataerror  => open,
               gt_rxrate            => X"000",
               -- Loopback
               gt_loopback          => X"000",
               -- Polarity
               gt_rxpolarity        => gtRxPolarity,
               gt_txpolarity        => gtTxPolarity,
               -- RX Decision Feedback Equalizer (DFE)
               gt_rxlpmen           => B"1111",
               gt_rxdfelpmreset     => B"0000",
               -- TX Driver
               gt_txpostcursor      => gtTxPostCursor,
               gt_txprecursor       => gtTxPreCursor,
               gt_txdiffctrl        => gtTxDiffCtrl,
               gt_txinhibit         => "0000",
               -- PRBS
               gt_rxprbscntreset    => B"0000",
               gt_rxprbserr         => open,
               gt_rxprbssel         => X"0000",
               gt_txprbssel         => X"0000",
               gt_txprbsforceerr    => B"0000",
               gt_rxcdrhold         => B"0000",
               gt_dmonitorout       => open,
               gt_pcsrsvdin         => (others => '0'),
               -- Configuration and Status
               gt_rxdisperr         => open,
               gt_rxnotintable      => open,
               gt_rxcommadet        => open,
               signal_detect        => (others => '1'),
               debug                => status.debugVector,
               configuration_vector => config.configVector,
               status_vector        => status.statusVector); 
      end generate;
   end generate;

   status.phyReady <= uAnd(status.debugVector);

   --------------------------
   -- 10GBASE-R's Reset Logic
   --------------------------
   status.areset <= config.softRst or extRst;

   RstSync_Inst : entity work.RstSync
      generic map (
         TPD_G           => TPD_G,
         IN_POLARITY_G   => '0',
         OUT_POLARITY_G  => '1',
         RELEASE_DELAY_G => 4) 
      port map (
         clk      => phyClock,
         asyncRst => status.clkLock,
         syncRst  => phyReset);         

   --------------------------------     
   -- Configuration/Status Register   
   --------------------------------     
   U_XauiReg : entity work.XauiReg
      generic map (
         TPD_G            => TPD_G,
         EN_AXI_REG_G     => EN_AXI_REG_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
      port map (
         -- Local Configurations
         localMac       => localMac,
         -- AXI-Lite Register Interface
         axiClk         => axiLiteClk,
         axiRst         => axiLiteRst,
         axiReadMaster  => axiLiteReadMaster,
         axiReadSlave   => axiLiteReadSlave,
         axiWriteMaster => axiLiteWriteMaster,
         axiWriteSlave  => axiLiteWriteSlave,
         -- Configuration and Status Interface
         phyClk         => phyClock,
         phyRst         => phyReset,
         config         => config,
         status         => status); 

end mapping;
