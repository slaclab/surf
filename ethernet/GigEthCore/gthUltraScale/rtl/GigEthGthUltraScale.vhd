-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 1000BASE-X Ethernet for Gth7
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

entity GigEthGthUltraScale is
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
      -- Switch Polarity of TxN/TxP, RxN/RxP
      gtTxPolarity       : in  sl                     := '0';
      gtRxPolarity       : in  sl                     := '0';
      -- MGT Ports
      gtTxP              : out sl;
      gtTxN              : out sl;
      gtRxP              : in  sl;
      gtRxN              : in  sl);
end GigEthGthUltraScale;

architecture mapping of GigEthGthUltraScale is

   component GigEthGthUltraScaleCore
      port (
         ---------------------
         -- Transceiver Interface
         ---------------------
         gtrefclk               : in  std_logic;  -- Very high quality clock for GT transceiver.
         txp                    : out std_logic;  -- Differential +ve of serial transmission from PMA to PMD.
         txn                    : out std_logic;  -- Differential -ve of serial transmission from PMA to PMD.
         rxp                    : in  std_logic;  -- Differential +ve for serial reception from PMD to PMA.
         rxn                    : in  std_logic;  -- Differential -ve for serial reception from PMD to PMA.
         resetdone              : out std_logic;  -- The GT transceiver has completed its reset cycle
         cplllock               : out std_logic;  -- The GT transceiver has completed its reset cycle
         mmcm_reset             : out std_logic;
         txoutclk               : out std_logic;
         rxoutclk               : out std_logic;
         userclk                : in  std_logic;
         userclk2               : in  std_logic;
         rxuserclk              : in  std_logic;
         rxuserclk2             : in  std_logic;
         pma_reset              : in  std_logic;  -- transceiver PMA reset signal
         mmcm_locked            : in  std_logic;  -- MMCM Locked
         independent_clock_bufg : in  std_logic;
         -----------------
         -- GMII Interface
         -----------------
         gmii_txd               : in  std_logic_vector(7 downto 0);  -- Transmit data from client MAC.
         gmii_tx_en             : in  std_logic;  -- Transmit control signal from client MAC.
         gmii_tx_er             : in  std_logic;  -- Transmit control signal from client MAC.
         gmii_rxd               : out std_logic_vector(7 downto 0);  -- Received Data to client MAC.
         gmii_rx_dv             : out std_logic;  -- Received control signal to client MAC.
         gmii_rx_er             : out std_logic;  -- Received control signal to client MAC.
         gmii_isolate           : out std_logic;  -- Tristate control to electrically isolate GMII.
         --------------------------------------------
         -- Management: Alternative to MDIO Interface
         --------------------------------------------
         configuration_vector   : in  std_logic_vector(4 downto 0);  -- Alternative to MDIO interface.
         an_interrupt           : out std_logic;  -- Interrupt to processor to signal that Auto-Negotiation has completed
         an_adv_config_vector   : in  std_logic_vector(15 downto 0);  -- Alternate interface to program REG4 (AN ADV)
         an_restart_config      : in  std_logic;  -- Alternate signal to modify AN restart bit in REG0
         ---------------
         -- General IO's
         ---------------
         gt0_txpolarity_in      : in  std_logic;
         gt0_rxpolarity_in      : in  std_logic;
         status_vector          : out std_logic_vector(15 downto 0);  -- Core status.
         reset                  : in  std_logic;  -- Asynchronous reset for entire core.
         signal_detect          : in  std_logic);  -- Input from PMD to indicate presence of optical input.
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

   attribute dont_touch           : string;
   attribute dont_touch of config : signal is "TRUE";
   attribute dont_touch of status : signal is "TRUE";

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
   U_GigEthGthUltraScaleCore : GigEthGthUltraScaleCore
      port map (
         -- Clocks and Resets
         gtrefclk               => sysClk125,  -- Used as CPLL clock reference
         independent_clock_bufg => sysClk62,  -- Used for the GT free running and DRP clock
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
         -- Configuration and Status
         an_restart_config      => '0',
         an_adv_config_vector   => GIG_ETH_AN_ADV_CONFIG_INIT_C,
         an_interrupt           => open,
         configuration_vector   => config.coreConfig,
         status_vector          => status.coreStatus,
         gt0_txpolarity_in      => gtTxPolarity,
         gt0_rxpolarity_in      => gtRxPolarity,
         signal_detect          => sigDet);

   status.phyReady <= status.coreStatus(1);
   phyReady        <= status.phyReady;

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
