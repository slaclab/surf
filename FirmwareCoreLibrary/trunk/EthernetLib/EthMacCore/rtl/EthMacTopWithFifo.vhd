-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EthMacTopWithFifo.vhd
-- Author     : Larry Ruckman <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-29
-- Last update: 2016-07-15
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
      GMII_EN_G     : boolean             := false;  -- False = XGMII Interface only, True = GMII Interface only      
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
      ethConfig   : in  EthMacConfigType;
      ethStatus   : out EthMacStatusType;
      -- XGMII PHY Interface
      phyTxd      : out slv(63 downto 0);
      phyTxc      : out slv(7 downto 0);
      phyRxd      : in  slv(63 downto 0);
      phyRxc      : in  slv(7 downto 0);
      phyReady    : in  sl;
      -- GMII PHY Interface
      gmiiRxDv    : in  sl              := '0';
      gmiiRxEr    : in  sl              := '0';
      gmiiRxd     : in  slv(7 downto 0) := x"00";
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
   U_MacTxFifo : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => 0,
         PIPE_STAGES_G       => 1,
         FIFO_ADDR_WIDTH_G   => 10,
         VALID_THOLD_G       => 0,      -- Only when full frame is ready
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
         CSUM_EN_G       => false,
         GMII_EN_G       => GMII_EN_G)
      port map (
         -- Clocks
         ethClk      => ethClk,
         ethClkRst   => ethClkRst,
         -- Primary Interface, TX
         sPrimMaster => macTxAxisMaster,
         sPrimSlave  => macTxAxisSlave,
         -- Primary Interface, RX
         mPrimMaster => macRxAxisMaster,
         mPrimCtrl   => macRxAxisCtrl,
         -- XGMII PHY Interface
         phyTxd      => phyTxd,
         phyTxc      => phyTxc,
         phyRxd      => phyRxd,
         phyRxc      => phyRxc,
         phyReady    => phyReady,
         -- GMII PHY Interface
         gmiiRxDv    => gmiiRxDv,
         gmiiRxEr    => gmiiRxEr,
         gmiiRxd     => gmiiRxd,
         gmiiTxEn    => gmiiTxEn,
         gmiiTxEr    => gmiiTxEr,
         gmiiTxd     => gmiiTxd,
         -- Configuration and status
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
