-------------------------------------------------------------------------------
-- File       : GigEthLvdsUltraScale.vhd
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.EthMacPkg.all;
use work.GigEthPkg.all;

entity GigEthLvdsUltraScale is
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
   U_GigEthLvdsUltraScaleCore : entity work.SaltUltraScaleCore
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
