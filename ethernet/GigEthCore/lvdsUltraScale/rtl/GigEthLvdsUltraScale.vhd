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
      ROCEV2_EN_G   : boolean             := false;
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
         ROCEV2_EN_G     => ROCEV2_EN_G,
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
   U_Phy : entity surf.GigEthLvdsUltraScalePhy
      port map (
         coreRst        => areset,             -- [in]
         sigDet         => sigDet,             -- [in]
         speed_is_10_100 => speed_is_10_100,    -- [in]
         speed_is_100    => speed_is_100,       -- [in]
         coreConfig     => config.coreConfig,  -- [in]
         coreStatus     => status.coreStatus,  -- [out]
         sysClk125      => sysClk125,           -- [out]
         sysRst125      => sysRst125,           -- [out]
         sysClkEn       => sysClk125En,         -- [out]
         gmiiTxd        => gmiiTxd,             -- [in]
         gmiiTxEn       => gmiiTxEn,            -- [in]
         gmiiTxEr       => gmiiTxEr,            -- [in]
         gmiiRxd        => gmiiRxd,             -- [out]
         gmiiRxDv       => gmiiRxDv,            -- [out]
         gmiiRxEr       => gmiiRxEr,            -- [out]
         sgmiiClkP      => sgmiiClkP,           -- [in]
         sgmiiClkN      => sgmiiClkN,           -- [in]
         sgmiiRxP       => sgmiiRxP,            -- [in]
         sgmiiRxN       => sgmiiRxN,            -- [in]
         sgmiiTxP       => sgmiiTxP,            -- [out]
         sgmiiTxN       => sgmiiTxN);           -- [out]

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
