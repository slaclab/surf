-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : XauiGthUltraScale.vhd
-- Author     : Larry Ruckman <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-08
-- Last update: 2016-01-13
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 10 GigE XAUI for GTH Ultra Scale
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

   ---------------------------
   -- 10 Gig Ethernet MAC core
   ---------------------------
   U_MacTxFifo : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         FIFO_ADDR_WIDTH_G   => 10,
         VALID_THOLD_G       => 0,      -- Only when full frame is ready
         SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_G,
         MASTER_AXI_CONFIG_G => EMAC_AXIS_CONFIG_C) 
      port map (
         sAxisClk    => dmaClk,
         sAxisRst    => dmaRst,
         sAxisMaster => dmaObMaster,
         sAxisSlave  => dmaObSlave,
         mAxisClk    => phyClock,
         mAxisRst    => phyReset,
         mAxisMaster => macTxAxisMaster,
         mAxisSlave  => macTxAxisSlave);

   U_XMacCore : entity work.EthMacTop
      generic map (
         TPD_G           => TPD_G,
         PAUSE_512BITS_G => 8,
         VLAN_CNT_G      => 1,
         VLAN_EN_G       => false,
         BYP_EN_G        => false,
         BYP_ETH_TYPE_G  => x"0000",
         SHIFT_EN_G      => false,
         FILT_EN_G       => false,
         CSUM_EN_G       => false) 
      port map (
         ethClk      => phyClock,
         ethClkRst   => phyReset,
         sPrimMaster => macTxAxisMaster,
         sPrimSlave  => macTxAxisSlave,
         mPrimMaster => macRxAxisMaster,
         mPrimCtrl   => macRxAxisCtrl,
         phyTxd      => phyTxd,
         phyTxc      => phyTxc,
         phyRxd      => phyRxd,
         phyRxc      => phyRxc,
         phyReady    => status.phyReady,
         ethConfig   => config.macConfig,
         ethStatus   => status.macStatus);

   U_MacRxFifo : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         FIFO_ADDR_WIDTH_G   => 11,
         SLAVE_READY_EN_G    => false,
         FIFO_PAUSE_THRESH_G => 1024,
         SLAVE_AXI_CONFIG_G  => EMAC_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => AXIS_CONFIG_G) 
      port map (
         sAxisClk    => phyClock,
         sAxisRst    => phyReset,
         sAxisMaster => macRxAxisMaster,
         sAxisCtrl   => macRxAxisCtrl,
         mAxisClk    => dmaClk,
         mAxisRst    => dmaRst,
         mAxisMaster => dmaIbMaster,
         mAxisSlave  => dmaIbSlave);

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
               -- Configuration and Status
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
               -- Configuration and Status
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
               -- Configuration and Status
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
               -- Configuration and Status
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
               -- Configuration and Status
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
               -- Configuration and Status
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
