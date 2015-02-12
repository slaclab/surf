-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : TenGigEthGtx7.vhd
-- Author     : Larry Ruckman <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-02-12
-- Last update: 2015-02-12
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Gtx7 Wrapper for 10GBASE-R Ethernet
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.AxiStreamPkg.all;
use work.TenGigEthPkg.all;
use work.StdRtlPkg.all;

entity TenGigEthGtx7 is
   -- Defaults:
   -- 9 bits = 4kbytes
   -- 255 x 8 = 2kbytes (not enough for pause)
   -- 11 bits = 16kbytes 
   generic (
      TPD_G           : time                := 1 ns;
      IB_ADDR_WIDTH_G : integer             := 11;
      OB_ADDR_WIDTH_G : integer             := 9;
      PAUSE_THOLD_G   : integer             := 512;
      VALID_THOLD_G   : integer             := 255;
      EOH_BIT_G       : integer             := 0;
      ERR_BIT_G       : integer             := 1;
      HEADER_SIZE_G   : integer             := 16;
      AXIS_CONFIG_G   : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);      
   port (
      -- Streaming DMA Interface 
      dmaClk           : in  sl;
      dmaRst           : in  sl;
      dmaIbMaster      : out AxiStreamMasterType;
      dmaIbSlave       : in  AxiStreamSlaveType;
      dmaObMaster      : in  AxiStreamMasterType;
      dmaObSlave       : out AxiStreamSlaveType;
      -- Default MAC is 01:03:00:56:44:00                            
      macAddr          : in  MacAddrType := TEN_GIG_ETH_MAC_ADDR_INIT_C;
      -- GT Clocking
      stableClk        : in  sl;
      gtQPllRefClk     : in  sl;
      gtQPllClk        : in  sl;
      gtQPllLock       : in  sl;
      gtQPllRefClkLost : in  sl;
      gtQPllReset      : out sl;
      -- Gt Serial IO
      gtTxP            : out sl;
      gtTxN            : out sl;
      gtRxP            : in  sl;
      gtRxN            : in  sl);  
end TenGigEthGtx7;

architecture mapping of TenGigEthGtx7 is

   signal phyReady  : sl;
   signal phyRxd    : slv(63 downto 0);
   signal phyRxc    : slv(7 downto 0);
   signal phyTxd    : slv(63 downto 0);
   signal phyTxc    : slv(7 downto 0);
   signal phyConfig : TenGigEthMacConfig;
   signal phyStatus : TenGigEthMacStatus;
   
begin

   --------------------
   -- Gig Ethernet core
   --------------------
   U_TenGigEthMacCore : entity work.TenGigEthMacCore
      generic map (
         TPD_G           => TPD_G,
         IB_ADDR_WIDTH_G => IB_ADDR_WIDTH_G,
         OB_ADDR_WIDTH_G => OB_ADDR_WIDTH_G,
         PAUSE_THOLD_G   => PAUSE_THOLD_G,
         VALID_THOLD_G   => VALID_THOLD_G,
         EOH_BIT_G       => EOH_BIT_G,
         ERR_BIT_G       => ERR_BIT_G,
         HEADER_SIZE_G   => HEADER_SIZE_G,
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
         phyClk      => phyClk,
         phyRst      => phyRst,
         phyReady    => phyReady,
         phyRxd      => phyRxd,
         phyRxc      => phyRxc,
         phyTxd      => phyTxd,
         phyTxc      => phyTxc,
         phyConfig   => phyConfig,
         phyStatus   => phyStatus);   

   U_TenGigEthGtx7Core : TenGigEthGtx7Core
      port map (
         clk156               => clk156,
         dclk                 => dclk,
         txusrclk             => txusrclk,
         txusrclk2            => txusrclk2,
         areset               => areset,
         txclk322             => txclk322,
         areset_clk156        => areset_clk156,
         gttxreset            => gttxreset,
         gtrxreset            => gtrxreset,
         txuserrdy            => txuserrdy,
         qplllock             => qplllock,
         qplloutclk           => qplloutclk,
         qplloutrefclk        => qplloutrefclk,
         reset_counter_done   => reset_counter_done,
         txp                  => gtTxP,
         txn                  => gtTxN,
         rxp                  => gtRxP,
         rxn                  => gtRxN,
         sim_speedup_control  => sim_speedup_control,
         xgmii_txd            => phyTxd,
         xgmii_txc            => phyTxc,
         xgmii_rxd            => phyRxd,
         xgmii_rxc            => phyRxc,
         configuration_vector => configuration_vector,
         status_vector        => status_vector,
         core_status          => core_status,
         tx_resetdone         => tx_resetdone,
         rx_resetdone         => rx_resetdone,
         signal_detect        => signal_detect,
         tx_fault             => tx_fault,
         drp_req              => drp_req,
         drp_gnt              => drp_gnt,
         drp_den_o            => drp_den_o,
         drp_dwe_o            => drp_dwe_o,
         drp_daddr_o          => drp_daddr_o,
         drp_di_o             => drp_di_o,
         drp_drdy_o           => drp_drdy_o,
         drp_drpdo_o          => drp_drpdo_o,
         drp_den_i            => drp_den_i,
         drp_dwe_i            => drp_dwe_i,
         drp_daddr_i          => drp_daddr_i,
         drp_di_i             => drp_di_i,
         drp_drdy_i           => drp_drdy_i,
         drp_drpdo_i          => drp_drpdo_i,
         tx_disable           => tx_disable,
         pma_pmd_type         => pma_pmd_type); 

end mapping;
