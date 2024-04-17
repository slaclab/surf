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
      TPD_G         : time                := 1 ns;
      JUMBO_G       : boolean             := true;
      PAUSE_EN_G    : boolean             := true;
      -- AXI-Lite Configurations
      EN_AXIL_REG_G : boolean             := false;
      -- AXI Streaming Configurations
      AXIS_CONFIG_G : AxiStreamConfigType := EMAC_AXIS_CONFIG_C);
   port (
      -- Local Configurations
      localMac        : in  slv(47 downto 0)       := MAC_ADDR_INIT_C;
      -- Streaming DMA Interface
      dmaClk          : in  sl;
      dmaRst          : in  sl;
      dmaIbMaster     : out AxiStreamMasterType;
      dmaIbSlave      : in  AxiStreamSlaveType;
      dmaObMaster     : in  AxiStreamMasterType;
      dmaObSlave      : out AxiStreamSlaveType;
      -- Slave AXI-Lite Interface
      axilClk         : in  sl                     := '0';
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Speed selection
      speed_is_10_100 : in  sl                     := '0';
      speed_is_100    : in  sl                     := '0';
      -- PHY + MAC signals
      extRst          : in  sl;
      ethClk          : out sl;
      ethRst          : out sl;
      phyReady        : out sl;
      sigDet          : in  sl                     := '1';
      -- SGMII / LVDS Ports
      sgmiiClkP       : in  sl;         -- 625 MHz
      sgmiiClkN       : in  sl;         -- 625 MHz
      sgmiiTxP        : out sl;
      sgmiiTxN        : out sl;
      sgmiiRxP        : in  sl;
      sgmiiRxN        : in  sl);
end GigEthLvdsUltraScale;

architecture mapping of GigEthLvdsUltraScale is

   component GigEthLvdsUltraScaleCore
      port (
         txn                  : out std_logic;
         txp                  : out std_logic;
         rxn                  : in  std_logic;
         rxp                  : in  std_logic;
         mmcm_locked_out      : out std_logic;
         sgmii_clk_r          : out std_logic;
         sgmii_clk_f          : out std_logic;
         sgmii_clk_en         : out std_logic;
         clk125_out           : out std_logic;
         clk625_out           : out std_logic;
         clk312_out           : out std_logic;
         rst_125_out          : out std_logic;
         refclk625_n          : in  std_logic;
         refclk625_p          : in  std_logic;
         gmii_txd             : in  std_logic_vector(7 downto 0);
         gmii_tx_en           : in  std_logic;
         gmii_tx_er           : in  std_logic;
         gmii_rxd             : out std_logic_vector(7 downto 0);
         gmii_rx_dv           : out std_logic;
         gmii_rx_er           : out std_logic;
         gmii_isolate         : out std_logic;
         configuration_vector : in  std_logic_vector(4 downto 0);
         speed_is_10_100      : in  std_logic;
         speed_is_100         : in  std_logic;
         status_vector        : out std_logic_vector(15 downto 0);
         reset                : in  std_logic;
         signal_detect        : in  std_logic;
         idelay_rdy_out       : out std_logic
         );
   end component;

   signal config : GigEthConfigType;
   signal status : GigEthStatusType;

   signal mAxiReadMaster  : AxiLiteReadMasterType;
   signal mAxiReadSlave   : AxiLiteReadSlaveType;
   signal mAxiWriteMaster : AxiLiteWriteMasterType;
   signal mAxiWriteSlave  : AxiLiteWriteSlaveType;

   signal gmiiTxd  : slv(7 downto 0);
   signal gmiiTxEn : sl;
   signal gmiiTxEr : sl;

   signal gmiiRxd  : slv(7 downto 0);
   signal gmiiRxDv : sl;
   signal gmiiRxEr : sl;

   signal sysClk125En : sl;
   signal sysClk125   : sl;
   signal sysRst125   : sl;
   signal areset      : sl;

begin

   ethClk <= sysClk125;
   ethRst <= sysRst125;

   areset <= extRst or config.softRst;

   ------------------
   -- Synchronization
   ------------------
   U_AxiLiteAsync : entity surf.AxiLiteAsync
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Slave Port
         sAxiClk         => axilClk,
         sAxiClkRst      => axilRst,
         sAxiReadMaster  => axilReadMaster,
         sAxiReadSlave   => axilReadSlave,
         sAxiWriteMaster => axilWriteMaster,
         sAxiWriteSlave  => axilWriteSlave,
         -- Master Port
         mAxiClk         => sysClk125,
         mAxiClkRst      => sysRst125,
         mAxiReadMaster  => mAxiReadMaster,
         mAxiReadSlave   => mAxiReadSlave,
         mAxiWriteMaster => mAxiWriteMaster,
         mAxiWriteSlave  => mAxiWriteSlave);

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
         ethClkEn        => sysClk125En,
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
   -- gmii - sgmii
   ------------------
   U_GigEthLvdsUltraScaleCore : GigEthLvdsUltraScaleCore
      port map (
         -- Clocks and Resets
         refclk625_p          => sgmiiClkP,
         refclk625_n          => sgmiiClkN,
         clk125_out           => sysClk125,
         clk312_out           => open,
         clk625_out           => open,
         reset                => areset,
         rst_125_out          => sysRst125,
         sgmii_clk_r          => open,
         sgmii_clk_f          => open,
         sgmii_clk_en         => sysClk125En,
         -- MGT Ports
         txp                  => sgmiiTxP,
         txn                  => sgmiiTxN,
         rxp                  => sgmiiRxP,
         rxn                  => sgmiiRxN,
         -- PHY Interface
         gmii_txd             => gmiiTxd,
         gmii_tx_en           => gmiiTxEn,
         gmii_tx_er           => gmiiTxEr,
         gmii_rxd             => gmiiRxd,
         gmii_rx_dv           => gmiiRxDv,
         gmii_rx_er           => gmiiRxEr,
         gmii_isolate         => open,
         -- Configuration and Status
         configuration_vector => config.coreConfig,
         status_vector        => status.coreStatus,
         mmcm_locked_out      => open,
         speed_is_10_100      => speed_is_10_100,
         speed_is_100         => speed_is_100,
         idelay_rdy_out       => open,
         signal_detect        => sigDet);

   status.phyReady <= status.coreStatus(0);
   phyReady        <= status.phyReady;

   --------------------------------
   -- Configuration/Status Register
   --------------------------------
   U_GigEthReg : entity surf.GigEthReg
      generic map (
         TPD_G        => TPD_G,
         EN_AXI_REG_G => EN_AXIL_REG_G)
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
