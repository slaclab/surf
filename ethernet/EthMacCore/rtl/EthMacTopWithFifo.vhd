-------------------------------------------------------------------------------
-- Title      : 1GbE/10GbE/40GbE Ethernet MAC
-------------------------------------------------------------------------------
-- File       : EthMacTopWithFifo.vhd
-- Author     : Larry Ruckman <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-29
-- Last update: 2016-09-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Common FIFO Wrapper for the EthMacTop
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
use work.EthMacPkg.all;

entity EthMacTopWithFifo is
   generic (
      TPD_G         : time                := 1 ns;
      PHY_TYPE_G    : string              := "XGMII";  -- "GMII", "XGMII", or "XLGMII"  
      AXIS_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);
   port (
      -- DMA Interface 
      dmaClk      : in  sl;
      dmaClkRst   : in  sl;
      dmaIbMaster : out AxiStreamMasterType;
      dmaIbSlave  : in  AxiStreamSlaveType;
      dmaObMaster : in  AxiStreamMasterType;
      dmaObSlave  : out AxiStreamSlaveType;
      -- Ethernet Interface
      ethClk      : in  sl;
      ethClkRst   : in  sl;
      phyReady    : in  sl;
      ethConfig   : in  EthMacConfigType;
      ethStatus   : out EthMacStatusType;
      -- XLGMII PHY Interface
      xlgmiiRxd   : in  slv(127 downto 0);
      xlgmiiRxc   : in  slv(15 downto 0);
      xlgmiiTxd   : out slv(127 downto 0);
      xlgmiiTxc   : out slv(15 downto 0);
      -- XGMII PHY Interface
      xgmiiRxd    : in  slv(63 downto 0);
      xgmiiRxc    : in  slv(7 downto 0);
      xgmiiTxd    : out slv(63 downto 0);
      xgmiiTxc    : out slv(7 downto 0);
      -- GMII PHY Interface
      gmiiRxDv    : in  sl;
      gmiiRxEr    : in  sl;
      gmiiRxd     : in  slv(7 downto 0);
      gmiiTxEn    : out sl;
      gmiiTxEr    : out sl;
      gmiiTxd     : out slv(7 downto 0));
end EthMacTopWithFifo;

architecture mapping of EthMacTopWithFifo is

   signal macTxAxisMaster : AxiStreamMasterType;
   signal macTxAxisSlave  : AxiStreamSlaveType;
   signal macRxAxisMaster : AxiStreamMasterType;
   signal macRxAxisCtrl   : AxiStreamCtrlType;

begin

   ----------
   -- TX FIFO
   ----------
   -- U_MacTxFifo : entity work.AxiStreamFifo
   -- generic map (
   -- TPD_G               => TPD_G,
   -- INT_PIPE_STAGES_G   => 0,
   -- PIPE_STAGES_G       => 1,
   -- FIFO_ADDR_WIDTH_G   => 10,
   -- VALID_THOLD_G       => 0,      -- Only when full frame is ready
   -- SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_G,
   -- MASTER_AXI_CONFIG_G => EMAC_AXIS_CONFIG_C)
   -- port map (
   -- sAxisClk    => dmaClk,
   -- sAxisRst    => dmaClkRst,
   -- sAxisMaster => dmaObMaster,
   -- sAxisSlave  => dmaObSlave,
   -- mAxisClk    => ethClk,
   -- mAxisRst    => ethClkRst,
   -- mAxisMaster => macTxAxisMaster,
   -- mAxisSlave  => macTxAxisSlave);
   
   U_MacTxFifo : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => 0,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => false,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => false,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 4,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_G,
         MASTER_AXI_CONFIG_G => EMAC_AXIS_CONFIG_C)        
      port map (
         sAxisClk    => dmaClk,
         sAxisRst    => dmaClkRst,
         sAxisMaster => dmaObMaster,
         sAxisSlave  => dmaObSlave,
         mAxisClk    => ethClk,
         mAxisRst    => ethClkRst,
         mAxisMaster => macTxAxisMaster,
         mAxisSlave  => macTxAxisSlave);      

   --------------------
   -- Ethernet MAC core
   --------------------
   U_EthMac : entity work.EthMacTop
      generic map (
         TPD_G           => TPD_G,
         PAUSE_EN_G      => true,
         PAUSE_512BITS_G => 8,
         VLAN_CNT_G      => 1,
         VLAN_EN_G       => false,
         BYP_EN_G        => false,
         BYP_ETH_TYPE_G  => x"0000",
         SHIFT_EN_G      => false,
         FILT_EN_G       => false,
         PHY_TYPE_G      => PHY_TYPE_G)
      port map (
         -- Clock and Reset
         ethClk      => ethClk,
         ethRst      => ethClkRst,
         -- Primary Interface, TX
         sPrimMaster => macTxAxisMaster,
         sPrimSlave  => macTxAxisSlave,
         -- Primary Interface, RX
         mPrimMaster => macRxAxisMaster,
         mPrimCtrl   => macRxAxisCtrl,
         -- XLGMII PHY Interface
         xlgmiiRxd   => xlgmiiRxd,
         xlgmiiRxc   => xlgmiiRxc,
         xlgmiiTxd   => xlgmiiTxd,
         xlgmiiTxc   => xlgmiiTxc,
         -- XGMII PHY Interface
         xgmiiRxd    => xgmiiRxd,
         xgmiiRxc    => xgmiiRxc,
         xgmiiTxd    => xgmiiTxd,
         xgmiiTxc    => xgmiiTxc,
         -- GMII PHY Interface
         gmiiRxDv    => gmiiRxDv,
         gmiiRxEr    => gmiiRxEr,
         gmiiRxd     => gmiiRxd,
         gmiiTxEn    => gmiiTxEn,
         gmiiTxEr    => gmiiTxEr,
         gmiiTxd     => gmiiTxd,
         -- Configuration and status
         phyReady    => phyReady,
         ethConfig   => ethConfig,
         ethStatus   => ethStatus);

   ----------
   -- RX FIFO
   ----------         
   U_MacRxFifo : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => 0,
         PIPE_STAGES_G       => 1,
         FIFO_ADDR_WIDTH_G   => 11,
         SLAVE_READY_EN_G    => false,
         FIFO_PAUSE_THRESH_G => 1024,
         SLAVE_AXI_CONFIG_G  => EMAC_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => AXIS_CONFIG_G)
      port map (
         sAxisClk    => ethClk,
         sAxisRst    => ethClkRst,
         sAxisMaster => macRxAxisMaster,
         sAxisCtrl   => macRxAxisCtrl,
         mAxisClk    => dmaClk,
         mAxisRst    => dmaClkRst,
         mAxisMaster => dmaIbMaster,
         mAxisSlave  => dmaIbSlave);

end mapping;
