-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : GigEthGth7.vhd
-- Author     : Larry Ruckman <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-02-07
-- Last update: 2016-09-29
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 1000BASE-X Ethernet for Gth7
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Ethernet Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Ethernet Library', including this file, 
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

entity GigEthGth7 is
   generic (
      TPD_G            : time                := 1 ns;
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
      -- PHY + MAC signals
      sysClk62           : in  sl;
      sysClk125          : in  sl;
      sysRst125          : in  sl;
      extRst             : in  sl;
      phyReady           : out sl;
      sigDet             : in  sl                     := '1';
      -- MGT Ports
      gtTxP              : out sl;
      gtTxN              : out sl;
      gtRxP              : in  sl;
      gtRxN              : in  sl);  
end GigEthGth7;

architecture mapping of GigEthGth7 is

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

   U_SysRst : entity work.RstSync
      generic map (
         TPD_G           => TPD_G,
         IN_POLARITY_G   => '1',
         OUT_POLARITY_G  => '1',
         BYPASS_SYNC_G   => false,
         RELEASE_DELAY_G => 3)
      port map (
         clk      => sysClk125,
         asyncRst => areset,
         syncRst  => coreRst);         

   --------------------
   -- Ethernet MAC core
   --------------------
   U_MAC : entity work.EthMacTop
      generic map (
         TPD_G         => TPD_G,
         PHY_TYPE_G    => "GMII",
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
   U_GigEthGth7Core : entity work.GigEthGth7Core
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
         configuration_vector   => config.coreConfig,
         status_vector          => status.coreStatus,
         signal_detect          => sigDet); 

   status.phyReady <= status.coreStatus(0);
   phyReady        <= status.phyReady;

   --------------------------------     
   -- Configuration/Status Register   
   --------------------------------     
   U_GigEthReg : entity work.GigEthReg
      generic map (
         TPD_G            => TPD_G,
         EN_AXI_REG_G     => EN_AXI_REG_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
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
