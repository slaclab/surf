-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : XauiGthUltraScale.vhd
-- Author     : Larry Ruckman <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-08
-- Last update: 2015-04-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 10 GigE XAUI for GTH Ultra Scale
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.XauiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity XauiGthUltraScale is
   -- Defaults:
   -- 9 bits = 4kbytes
   -- 255 x 8 = 2kbytes (not enough for pause)
   -- 11 bits = 16kbytes 
   generic (
      TPD_G            : time                := 1 ns;
      -- DMA/MAC Configurations
      IB_ADDR_WIDTH_G  : integer             := 11;
      OB_ADDR_WIDTH_G  : integer             := 9;
      PAUSE_THOLD_G    : integer             := 512;
      VALID_THOLD_G    : integer             := 255;
      EOH_BIT_G        : integer             := 0;
      ERR_BIT_G        : integer             := 1;
      HEADER_SIZE_G    : integer             := 16;
      SHIFT_EN_G       : boolean             := false;
      MAC_ADDR_G       : slv(47 downto 0)    := MAC_ADDR_INIT_C;
      -- AXI-Lite Configurations
      AXI_ERROR_RESP_G : slv(1 downto 0)     := AXI_RESP_SLVERR_C;
      -- AXI Streaming Configurations
      AXIS_CONFIG_G    : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);  -- Note: Only support 64-bit AXIS configurations
   port (
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
      refClk             : in  sl;
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
   
begin

   phyClk   <= phyClock;
   phyRst   <= phyReset;
   phyReady <= status.phyReady;

   ---------------------------
   -- 10 Gig Ethernet MAC core
   ---------------------------
   U_XMacCore : entity work.XMacCore
      generic map (
         TPD_G           => TPD_G,
         IB_ADDR_WIDTH_G => IB_ADDR_WIDTH_G,
         OB_ADDR_WIDTH_G => OB_ADDR_WIDTH_G,
         PAUSE_THOLD_G   => PAUSE_THOLD_G,
         VALID_THOLD_G   => VALID_THOLD_G,
         EOH_BIT_G       => EOH_BIT_G,
         ERR_BIT_G       => ERR_BIT_G,
         HEADER_SIZE_G   => HEADER_SIZE_G,
         SHIFT_EN_G      => SHIFT_EN_G,
         AXIS_CONFIG_G   => AXIS_CONFIG_G)    
      port map (
         -- Streaming DMA Interface 
         dmaClk      => dmaClk,
         dmaRst      => dmaRst,
         dmaIbMaster => dmaIbMaster,
         dmaIbSlave  => dmaIbSlave,
         dmaObMaster => dmaObMaster,
         dmaObSlave  => dmaObSlave,
         -- PHY Interface
         phyClk      => phyClock,
         phyRst      => phyReset,
         phyReady    => status.phyReady,
         phyRxd      => phyRxd,
         phyRxc      => phyRxc,
         phyTxd      => phyTxd,
         phyTxc      => phyTxc,
         phyConfig   => config.phyConfig,
         phyStatus   => status.phyStatus);   

   --------------------
   -- 10 GigE XAUI Core
   --------------------
   U_XauiGthUltraScaleCore : entity work.XauiGthUltraScaleCore
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
         MAC_ADDR_G       => MAC_ADDR_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
      port map (
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
