-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 1000BASE-X Ethernet for Gtx7
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.EthMacPkg.all;
use surf.GigEthPkg.all;

entity GigEthGtx7 is
   generic (
      TPD_G                   : time                := 1 ns;
      PAUSE_EN_G              : boolean             := true;
      -- AXI-Lite Configurations
      EN_AXI_REG_G            : boolean             := false;
      AXIL_BASE_ADDR_G        : slv(31 downto 0)    := X"00000000";
      AXIL_CLK_IS_SYSCLK125_G : boolean             := false;
      -- AXI Streaming Configurations
      AXIS_CONFIG_G           : AxiStreamConfigType := EMAC_AXIS_CONFIG_C);
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
      -- GT Drive strength
      gtTxDiffCtrl       : in  slv(3 downto 0)        := "1000";
      gtTxPreCursor      : in  slv(4 downto 0)        := (others => '0');
      gtTxPostCursor     : in  slv(4 downto 0)        := (others => '0');
      -- MGT Ports
      gtTxP              : out sl;
      gtTxN              : out sl;
      gtRxP              : in  sl;
      gtRxN              : in  sl);
end GigEthGtx7;

architecture mapping of GigEthGtx7 is

   component GigEthGtx7Core
      port (
         gtrefclk               : in  sl;
         gtrefclk_bufg          : in  sl;
         txp                    : out sl;
         txn                    : out sl;
         rxp                    : in  sl;
         rxn                    : in  sl;
         resetdone              : out sl;
         cplllock               : out sl;
         mmcm_reset             : out sl;
         txoutclk               : out sl;
         rxoutclk               : out sl;
         userclk                : in  sl;
         userclk2               : in  sl;
         rxuserclk              : in  sl;
         rxuserclk2             : in  sl;
         pma_reset              : in  sl;
         mmcm_locked            : in  sl;
         independent_clock_bufg : in  sl;
         drpaddr_in             : in  slv (8 downto 0);
         drpclk_in              : in  sl;
         drpdi_in               : in  slv (15 downto 0);
         drpdo_out              : out slv (15 downto 0);
         drpen_in               : in  sl;
         drprdy_out             : out sl;
         drpwe_in               : in  sl;
         gmii_txd               : in  slv (7 downto 0);
         gmii_tx_en             : in  sl;
         gmii_tx_er             : in  sl;
         gmii_rxd               : out slv (7 downto 0);
         gmii_rx_dv             : out sl;
         gmii_rx_er             : out sl;
         gmii_isolate           : out sl;
         configuration_vector   : in  slv (4 downto 0);
         an_interrupt           : out sl;
         an_adv_config_vector   : in  slv (15 downto 0);
         an_restart_config      : in  sl;
         status_vector          : out slv (15 downto 0);
         reset                  : in  sl;
         signal_detect          : in  sl;
         gt0_rxpolarity_in      : in  sl;
         gt0_txpolarity_in      : in  sl;
         gt0_txdiffctrl_in      : in  slv(3 downto 0);
         gt0_txpostcursor_in    : in  slv(4 downto 0);
         gt0_txprecursor_in     : in  slv(4 downto 0);
         gt0_qplloutclk_in      : in  sl;
         gt0_qplloutrefclk_in   : in  sl
         );
   end component;

   signal config : GigEthConfigType;
   signal status : GigEthStatusType;

   constant AXIL_NUM_C : integer := 2;
   constant ETH_AXIL_C : integer := 0;
   constant DRP_AXIL_C : integer := 1;

   constant AXIL_XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(AXIL_NUM_C-1 downto 0) := (
      ETH_AXIL_C      => (
         baseAddr     => AXIL_BASE_ADDR_G + X"0000",
         addrBits     => 12,
         connectivity => X"FFFF"),
      DRP_AXIL_C      => (
         baseAddr     => AXIL_BASE_ADDR_G + X"1000",
         addrBits     => 12,
         connectivity => X"FFFF"));

   signal syncAxilReadMaster  : AxiLiteReadMasterType;
   signal syncAxilReadSlave   : AxiLiteReadSlaveType;
   signal syncAxilWriteMaster : AxiLiteWriteMasterType;
   signal syncAxilWriteSlave  : AxiLiteWriteSlaveType;

   signal locAxilReadMasters  : AxiLiteReadMasterArray(AXIL_NUM_C-1 downto 0);
   signal locAxilReadSlaves   : AxiLiteReadSlaveArray(AXIL_NUM_C-1 downto 0);
   signal locAxilWriteMasters : AxiLiteWriteMasterArray(AXIL_NUM_C-1 downto 0);
   signal locAxilWriteSlaves  : AxiLiteWriteSlaveArray(AXIL_NUM_C-1 downto 0);

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

   signal drpaddr : slv (8 downto 0);
   signal drpclk  : sl;
   signal drpdi   : slv (15 downto 0);
   signal drpdo   : slv (15 downto 0);
   signal drpen   : sl;
   signal drprdy  : sl;
   signal drpwe   : sl;


begin

   ------------------
   -- Synchronization
   ------------------
   U_AxiLiteAsync : entity surf.AxiLiteAsync
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => AXIL_CLK_IS_SYSCLK125_G)
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
         mAxiReadMaster  => syncAxilReadMaster,
         mAxiReadSlave   => syncAxilReadSlave,
         mAxiWriteMaster => syncAxilWriteMaster,
         mAxiWriteSlave  => syncAxilWriteSlave);

   U_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => AXIL_NUM_C,
         MASTERS_CONFIG_G   => AXIL_XBAR_CONFIG_C)
      port map (
         axiClk              => sysClk125,
         axiClkRst           => sysRst125,
         sAxiWriteMasters(0) => syncAxilWriteMaster,
         sAxiWriteSlaves(0)  => syncAxilWriteSlave,
         sAxiReadMasters(0)  => syncAxilReadMaster,
         sAxiReadSlaves(0)   => syncAxilReadSlave,
         mAxiWriteMasters    => locAxilWriteMasters,
         mAxiWriteSlaves     => locAxilWriteSlaves,
         mAxiReadMasters     => locAxilReadMasters,
         mAxiReadSlaves      => locAxilReadSlaves);

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
   U_GigEthGtx7Core : GigEthGtx7Core
      port map (
         -- Clocks and Resets
         gtrefclk_bufg          => sysClk125,  -- Used as DRP clock in IP core
         gtrefclk               => sysClk125,  -- Used as CPLL clock reference
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
         -- DRP Interface
         drpaddr_in             => drpaddr,
         drpclk_in              => drpclk,
         drpdi_in               => drpdi,
         drpdo_out              => drpdo,
         drpen_in               => drpen,
         drprdy_out             => drprdy,
         drpwe_in               => drpwe,
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
         gt0_qplloutclk_in      => '0',        -- QPLL not used
         gt0_qplloutrefclk_in   => '0',        -- QPLL not used
         -- Configuration and Status
         an_restart_config      => '0',
         an_adv_config_vector   => GIG_ETH_AN_ADV_CONFIG_INIT_C,
         an_interrupt           => open,
         configuration_vector   => config.coreConfig,
         status_vector          => status.coreStatus,
         gt0_txpolarity_in      => gtTxPolarity,
         gt0_rxpolarity_in      => gtRxPolarity,
         gt0_txdiffctrl_in      => gtTxDiffCtrl,
         gt0_txprecursor_in     => gtTxPreCursor,
         gt0_txpostcursor_in    => gtTxPostCursor,
         signal_detect          => sigDet);

   status.phyReady <= status.coreStatus(1);
   phyReady        <= status.phyReady;

   drpClk <= sysClk125;
   U_AxiLiteToDrp_1 : entity surf.AxiLiteToDrp
      generic map (
         TPD_G            => TPD_G,
         COMMON_CLK_G     => true,
         EN_ARBITRATION_G => false,
         ADDR_WIDTH_G     => 9,
         DATA_WIDTH_G     => 16)
      port map (
         axilClk         => sysClk125,                        -- [in]
         axilRst         => sysRst125,                        -- [in]
         axilReadMaster  => locAxilReadMasters(DRP_AXIL_C),   -- [in]
         axilReadSlave   => locAxilReadSlaves(DRP_AXIL_C),    -- [out]
         axilWriteMaster => locAxilWriteMasters(DRP_AXIL_C),  -- [in]
         axilWriteSlave  => locAxilWriteSlaves(DRP_AXIL_C),   -- [out]
         drpClk          => sysClk125,                        -- [in]
         drpRst          => sysRst125,                        -- [in]
         drpRdy          => drpRdy,                           -- [in]
         drpEn           => drpEn,                            -- [out]
         drpWe           => drpWe,                            -- [out]
         drpAddr         => drpAddr,                          -- [out]
         drpDi           => drpDi,                            -- [out]
         drpDo           => drpDo);                           -- [in]

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
         axiReadMaster  => locAxilReadMasters(ETH_AXIL_C),
         axiReadSlave   => locAxilReadSlaves(ETH_AXIL_C),
         axiWriteMaster => locAxilWriteMasters(ETH_AXIL_C),
         axiWriteSlave  => locAxilWriteSlaves(ETH_AXIL_C),
         -- Configuration and Status Interface
         config         => config,
         status         => status);

end mapping;
