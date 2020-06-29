-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: SGMII Ethernet over LVDS
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

entity GigEthLvdsUltraScale is
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
      -- Speed selection
      speed_is_10_100    : in  sl                     := '0';
      speed_is_100       : in  sl                     := '0';
      -- PHY + MAC signals
      sysClk625          : in  sl;
      sysClk312          : in  sl;
      sysClk125          : in  sl;
      sysRst125          : in  sl;
      ethClkEn           : in  sl;
      extRst             : in  sl;
      phyReady           : out sl;
      sigDet             : in  sl                     := '1';
      mmcmLocked         : in  sl                     := '1';
      -- SGMII / LVDS Ports
      sgmiiTxP           : out sl;
      sgmiiTxN           : out sl;
      sgmiiRxP           : in  sl;
      sgmiiRxN           : in  sl);
end GigEthLvdsUltraScale;

architecture mapping of GigEthLvdsUltraScale is

   component SaltUltraScaleCore
      port (
         -----------------------------
         -- LVDS transceiver Interface
         -----------------------------
         txp                  : out std_logic;  -- Differential +ve of serial transmission from PMA to PMD.
         txn                  : out std_logic;  -- Differential -ve of serial transmission from PMA to PMD.
         rxp                  : in  std_logic;  -- Differential +ve for serial reception from PMD to PMA.
         rxn                  : in  std_logic;  -- Differential -ve for serial reception from PMD to PMA.
         clk125m              : in  std_logic;
         mmcm_locked          : in  std_logic;
         sgmii_clk_r          : out std_logic;  -- Clock for client MAC (125Mhz, 12.5MHz or 1.25MHz).
         sgmii_clk_f          : out std_logic;  -- Clock for client MAC (125Mhz, 12.5MHz or 1.25MHz).
         sgmii_clk_en         : out std_logic;  -- Clock enable for client MAC
         ----------------
         -- Speed Control
         ----------------
         speed_is_10_100      : in  std_logic;  -- Core should operate at either 10Mbps or 100Mbps speeds
         speed_is_100         : in  std_logic;  -- Core should operate at 100Mbps speed
         clk625               : in  std_logic;
         clk312               : in  std_logic;
         idelay_rdy_in        : in  std_logic;
         -----------------
         -- GMII Interface
         -----------------
         gmii_txd             : in  std_logic_vector(7 downto 0);  -- Transmit data from client MAC.
         gmii_tx_en           : in  std_logic;  -- Transmit control signal from client MAC.
         gmii_tx_er           : in  std_logic;  -- Transmit control signal from client MAC.
         gmii_rxd             : out std_logic_vector(7 downto 0);  -- Received Data to client MAC.
         gmii_rx_dv           : out std_logic;  -- Received control signal to client MAC.
         gmii_rx_er           : out std_logic;  -- Received control signal to client MAC.
         gmii_isolate         : out std_logic;  -- Tristate control to electrically isolate GMII.
         ---------------
         -- General IO's
         ---------------
         configuration_vector : in  std_logic_vector(4 downto 0);  -- Alternative to MDIO interface.
         status_vector        : out std_logic_vector(15 downto 0);  -- Core status.
         reset                : in  std_logic;  -- Asynchronous reset for entire core.
         signal_detect        : in  std_logic);  -- Input from PMD to indicate presence of optical input.
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

   signal delayCtrlRdy : sl;

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
         ethClkEn        => ethClkEn,
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

   -- The SaltUltrascaleCore uses IDELAYE3 in 'COUNT' mode.
   -- An IDELAYCTRL unit is not required (Ultrascale SelectIO UG571, pp. 165)

   delayCtrlRdy <= '1';

   ------------------
   -- gmii - sgmii
   ------------------
   U_GigEthLvdsUltraScaleCore : SaltUltraScaleCore
      port map (
         -- Clocks and Resets
         clk125m              => sysClk125,
         clk312               => sysClk312,
         clk625               => sysClk625,
         idelay_rdy_in        => delayCtrlRdy,
         mmcm_locked          => mmcmLocked,
         sgmii_clk_r          => open,
         sgmii_clk_f          => open,
         sgmii_clk_en         => open,
         speed_is_10_100      => speed_is_10_100,
         speed_is_100         => speed_is_100,
         reset                => coreRst,
         -- PHY Interface
         gmii_txd             => gmiiTxd,
         gmii_tx_en           => gmiiTxEn,
         gmii_tx_er           => gmiiTxEr,
         gmii_rxd             => gmiiRxd,
         gmii_rx_dv           => gmiiRxDv,
         gmii_rx_er           => gmiiRxEr,
         gmii_isolate         => open,
         -- MGT Ports
         txp                  => sgmiiTxP,
         txn                  => sgmiiTxN,
         rxp                  => sgmiiRxP,
         rxn                  => sgmiiRxN,
         -- Configuration and Status
         configuration_vector => config.coreConfig,
         status_vector        => status.coreStatus,
         signal_detect        => sigDet);

   status.phyReady <= status.coreStatus(0);
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
