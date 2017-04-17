-------------------------------------------------------------------------------
-- File       : EthMacTop.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-22
-- Last update: 2016-10-20
-------------------------------------------------------------------------------
-- Description: Top-level for 1GbE/10GbE/40GbE ETH MAC Module
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

use work.AxiStreamPkg.all;
use work.StdRtlPkg.all;
use work.EthMacPkg.all;

entity EthMacTop is
   generic (
      -- Simulation Generics
      TPD_G               : time                     := 1 ns;
      -- MAC Configurations
      PAUSE_EN_G          : boolean                  := true;
      PAUSE_512BITS_G     : positive range 1 to 1024 := 8;
      PHY_TYPE_G          : string                   := "XGMII";  -- "GMII", "XGMII", or "XLGMII"
      DROP_ERR_PKT_G      : boolean                  := true;
      JUMBO_G             : boolean                  := true;
      -- RX FIFO Configurations
      INT_PIPE_STAGES_G   : natural                  := 1;
      PIPE_STAGES_G       : natural                  := 1;
      FIFO_ADDR_WIDTH_G   : positive                 := 10;
      CASCADE_SIZE_G      : positive                 := 2;
      FIFO_PAUSE_THRESH_G : positive                 := 1000;
      CASCADE_PAUSE_SEL_G : natural                  := 0;
      -- Non-VLAN Configurations
      FILT_EN_G           : boolean                  := false;
      PRIM_COMMON_CLK_G   : boolean                  := false;
      PRIM_CONFIG_G       : AxiStreamConfigType      := EMAC_AXIS_CONFIG_C;
      BYP_EN_G            : boolean                  := false;
      BYP_ETH_TYPE_G      : slv(15 downto 0)         := x"0000";
      BYP_COMMON_CLK_G    : boolean                  := false;
      BYP_CONFIG_G        : AxiStreamConfigType      := EMAC_AXIS_CONFIG_C;
      -- VLAN Configurations
      VLAN_EN_G           : boolean                  := false;
      VLAN_SIZE_G         : positive range 1 to 8    := 1;
      VLAN_VID_G          : Slv12Array               := (0 => x"001");
      VLAN_COMMON_CLK_G   : boolean                  := false;
      VLAN_CONFIG_G       : AxiStreamConfigType      := EMAC_AXIS_CONFIG_C);      
   port (
      -- Core Clock and Reset
      ethClk           : in  sl;
      ethRst           : in  sl;
      -- Primary Interface
      primClk          : in  sl;
      primRst          : in  sl;
      ibMacPrimMaster  : in  AxiStreamMasterType;
      ibMacPrimSlave   : out AxiStreamSlaveType;
      obMacPrimMaster  : out AxiStreamMasterType;
      obMacPrimSlave   : in  AxiStreamSlaveType;
      -- Bypass interface
      bypClk           : in  sl                                           := '0';
      bypRst           : in  sl                                           := '0';
      ibMacBypMaster   : in  AxiStreamMasterType                          := AXI_STREAM_MASTER_INIT_C;
      ibMacBypSlave    : out AxiStreamSlaveType;
      obMacBypMaster   : out AxiStreamMasterType;
      obMacBypSlave    : in  AxiStreamSlaveType                           := AXI_STREAM_SLAVE_FORCE_C;
      -- VLAN Interfaces
      vlanClk          : in  sl                                           := '0';
      vlanRst          : in  sl                                           := '0';
      ibMacVlanMasters : in  AxiStreamMasterArray(VLAN_SIZE_G-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
      ibMacVlanSlaves  : out AxiStreamSlaveArray(VLAN_SIZE_G-1 downto 0);
      obMacVlanMasters : out AxiStreamMasterArray(VLAN_SIZE_G-1 downto 0);
      obMacVlanSlaves  : in  AxiStreamSlaveArray(VLAN_SIZE_G-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);
      -- XLGMII PHY Interface
      xlgmiiRxd        : in  slv(127 downto 0)                            := (others => '0');
      xlgmiiRxc        : in  slv(15 downto 0)                             := (others => '0');
      xlgmiiTxd        : out slv(127 downto 0);
      xlgmiiTxc        : out slv(15 downto 0);
      -- XGMII PHY Interface
      xgmiiRxd         : in  slv(63 downto 0)                             := (others => '0');
      xgmiiRxc         : in  slv(7 downto 0)                              := (others => '0');
      xgmiiTxd         : out slv(63 downto 0);
      xgmiiTxc         : out slv(7 downto 0);
      -- GMII PHY Interface
      gmiiRxDv         : in  sl                                           := '0';
      gmiiRxEr         : in  sl                                           := '0';
      gmiiRxd          : in  slv(7 downto 0)                              := (others => '0');
      gmiiTxEn         : out sl;
      gmiiTxEr         : out sl;
      gmiiTxd          : out slv(7 downto 0);
      -- Configuration and status
      phyReady         : in  sl;
      ethConfig        : in  EthMacConfigType;
      ethStatus        : out EthMacStatusType);
end EthMacTop;

architecture mapping of EthMacTop is

   signal sPrimMaster : AxiStreamMasterType;
   signal sPrimSlave  : AxiStreamSlaveType;
   signal mPrimMaster : AxiStreamMasterType;
   signal mPrimCtrl   : AxiStreamCtrlType;

   signal sBypMaster : AxiStreamMasterType;
   signal sBypSlave  : AxiStreamSlaveType;
   signal mBypMaster : AxiStreamMasterType;
   signal mBypCtrl   : AxiStreamCtrlType;

   signal sVlanMasters : AxiStreamMasterArray(VLAN_SIZE_G-1 downto 0);
   signal sVlanSlaves  : AxiStreamSlaveArray(VLAN_SIZE_G-1 downto 0);
   signal mVlanMasters : AxiStreamMasterArray(VLAN_SIZE_G-1 downto 0);
   signal mVlanCtrl    : AxiStreamCtrlArray(VLAN_SIZE_G-1 downto 0);

   signal rxPauseReq   : sl;
   signal rxPauseValue : slv(15 downto 0);
   signal flowCtrl     : AxiStreamCtrlType;

   -- attribute dont_touch                 : string;
   -- attribute dont_touch of rxPauseReq   : signal is "true";
   -- attribute dont_touch of rxPauseValue : signal is "true";
   -- attribute dont_touch of flowCtrl     : signal is "true";

begin

   ethStatus.rxPauseCnt <= rxPauseReq;
   ethStatus.rxOverFlow <= flowCtrl.overflow;

   ----------
   -- TX FIFO
   ----------
   U_TxFifo : entity work.EthMacTxFifo
      generic map (
         TPD_G             => TPD_G,
         PRIM_COMMON_CLK_G => PRIM_COMMON_CLK_G,
         PRIM_CONFIG_G     => PRIM_CONFIG_G,
         BYP_EN_G          => BYP_EN_G,
         BYP_COMMON_CLK_G  => BYP_COMMON_CLK_G,
         BYP_CONFIG_G      => BYP_CONFIG_G,
         VLAN_EN_G         => VLAN_EN_G,
         VLAN_SIZE_G       => VLAN_SIZE_G,
         VLAN_COMMON_CLK_G => VLAN_COMMON_CLK_G,
         VLAN_CONFIG_G     => VLAN_CONFIG_G)
      port map (
         -- Master Clock and Reset
         mClk         => ethClk,
         mRst         => ethRst,
         -- Primary Interface
         sPrimClk     => primClk,
         sPrimRst     => primRst,
         sPrimMaster  => ibMacPrimMaster,
         sPrimSlave   => ibMacPrimSlave,
         mPrimMaster  => sPrimMaster,
         mPrimSlave   => sPrimSlave,
         -- Bypass interface
         sBypClk      => bypClk,
         sBypRst      => bypRst,
         sBypMaster   => ibMacBypMaster,
         sBypSlave    => ibMacBypSlave,
         mBypMaster   => sBypMaster,
         mBypSlave    => sBypSlave,
         -- VLAN Interfaces
         sVlanClk     => vlanClk,
         sVlanRst     => vlanRst,
         sVlanMasters => ibMacVlanMasters,
         sVlanSlaves  => ibMacVlanSlaves,
         mVlanMasters => sVlanMasters,
         mVlanSlaves  => sVlanSlaves);

   ------------
   -- TX Module
   ------------
   U_Tx : entity work.EthMacTx
      generic map (
         -- Simulation Generics
         TPD_G           => TPD_G,
         -- MAC Configurations
         PAUSE_EN_G      => PAUSE_EN_G,
         PAUSE_512BITS_G => PAUSE_512BITS_G,
         PHY_TYPE_G      => PHY_TYPE_G,
         DROP_ERR_PKT_G  => DROP_ERR_PKT_G,
         JUMBO_G         => JUMBO_G,
         -- Non-VLAN Configurations
         BYP_EN_G        => BYP_EN_G,
         -- VLAN Configurations
         VLAN_EN_G       => VLAN_EN_G,
         VLAN_SIZE_G     => VLAN_SIZE_G,
         VLAN_VID_G      => VLAN_VID_G)
      port map (
         -- Clocks
         ethClk         => ethClk,
         ethRst         => ethRst,
         -- Primary Interface
         sPrimMaster    => sPrimMaster,
         sPrimSlave     => sPrimSlave,
         -- Bypass interface
         sBypMaster     => sBypMaster,
         sBypSlave      => sBypSlave,
         -- VLAN Interfaces
         sVlanMasters   => sVlanMasters,
         sVlanSlaves    => sVlanSlaves,
         -- XLGMII PHY Interface
         xlgmiiTxd      => xlgmiiTxd,
         xlgmiiTxc      => xlgmiiTxc,
         -- XGMII PHY Interface
         xgmiiTxd       => xgmiiTxd,
         xgmiiTxc       => xgmiiTxc,
         -- GMII PHY Interface
         gmiiTxEn       => gmiiTxEn,
         gmiiTxEr       => gmiiTxEr,
         gmiiTxd        => gmiiTxd,
         -- Flow control Interface
         clientPause    => flowCtrl.pause,
         rxPauseReq     => rxPauseReq,
         rxPauseValue   => rxPauseValue,
         pauseTx        => ethStatus.txPauseCnt,
         -- Configuration and status
         phyReady       => phyReady,
         ethConfig      => ethConfig,
         txCountEn      => ethStatus.txCountEn,
         txUnderRun     => ethStatus.txUnderRunCnt,
         txLinkNotReady => ethStatus.txNotReadyCnt);          

   ---------------------      
   -- Flow Control Logic
   ---------------------      
   U_FlowCtrl : entity work.EthMacFlowCtrl
      generic map (
         TPD_G       => TPD_G,
         BYP_EN_G    => BYP_EN_G,
         VLAN_EN_G   => VLAN_EN_G,
         VLAN_SIZE_G => VLAN_SIZE_G)
      port map (
         -- Clock and Reset
         ethClk   => ethClk,
         ethRst   => ethRst,
         -- Inputs
         primCtrl => mPrimCtrl,
         bypCtrl  => mBypCtrl,
         vlanCtrl => mVlanCtrl,
         -- Output
         flowCtrl => flowCtrl);

   ------------
   -- RX Module
   ------------      
   U_Rx : entity work.EthMacRx
      generic map (
         -- Simulation Generics
         TPD_G          => TPD_G,
         -- MAC Configurations
         PAUSE_EN_G     => PAUSE_EN_G,
         PHY_TYPE_G     => PHY_TYPE_G,
         JUMBO_G        => JUMBO_G,
         -- Non-VLAN Configurations
         FILT_EN_G      => FILT_EN_G,
         BYP_EN_G       => BYP_EN_G,
         BYP_ETH_TYPE_G => BYP_ETH_TYPE_G,
         -- VLAN Configurations
         VLAN_EN_G      => VLAN_EN_G,
         VLAN_SIZE_G    => VLAN_SIZE_G,
         VLAN_VID_G     => VLAN_VID_G)
      port map (
         -- Clock and Reset
         ethClk       => ethClk,
         ethRst       => ethRst,
         -- Primary Interface
         mPrimMaster  => mPrimMaster,
         mPrimCtrl    => mPrimCtrl,
         -- Bypass Interface
         mBypMaster   => mBypMaster,
         mBypCtrl     => mBypCtrl,
         -- VLAN Interfaces
         mVlanMasters => mVlanMasters,
         mVlanCtrl    => mVlanCtrl,
         -- XLGMII PHY Interface
         xlgmiiRxd    => xlgmiiRxd,
         xlgmiiRxc    => xlgmiiRxc,
         -- XGMII PHY Interface
         xgmiiRxd     => xgmiiRxd,
         xgmiiRxc     => xgmiiRxc,
         -- GMII PHY Interface
         gmiiRxDv     => gmiiRxDv,
         gmiiRxEr     => gmiiRxEr,
         gmiiRxd      => gmiiRxd,
         -- Flow Control Interface
         rxPauseReq   => rxPauseReq,
         rxPauseValue => rxPauseValue,
         -- Configuration and status
         phyReady     => phyReady,
         ethConfig    => ethConfig,
         rxCountEn    => ethStatus.rxCountEn,
         rxCrcError   => ethStatus.rxCrcErrorCnt);

   ----------
   -- RX FIFO
   ----------         
   U_RxFifo : entity work.EthMacRxFifo
      generic map (
         TPD_G               => TPD_G,
         DROP_ERR_PKT_G      => DROP_ERR_PKT_G,
         INT_PIPE_STAGES_G   => INT_PIPE_STAGES_G,
         PIPE_STAGES_G       => PIPE_STAGES_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         CASCADE_SIZE_G      => CASCADE_SIZE_G,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         CASCADE_PAUSE_SEL_G => CASCADE_PAUSE_SEL_G,
         PRIM_COMMON_CLK_G   => PRIM_COMMON_CLK_G,
         PRIM_CONFIG_G       => PRIM_CONFIG_G,
         BYP_EN_G            => BYP_EN_G,
         BYP_COMMON_CLK_G    => BYP_COMMON_CLK_G,
         BYP_CONFIG_G        => BYP_CONFIG_G,
         VLAN_EN_G           => VLAN_EN_G,
         VLAN_SIZE_G         => VLAN_SIZE_G,
         VLAN_COMMON_CLK_G   => VLAN_COMMON_CLK_G,
         VLAN_CONFIG_G       => VLAN_CONFIG_G)
      port map (
         -- Slave Clock and Reset
         sClk         => ethClk,
         sRst         => ethRst,
         -- Status (sClk domain)
         phyReady     => phyReady,
         rxFifoDrop   => ethStatus.rxFifoDropCnt,
         -- Primary Interface
         mPrimClk     => primClk,
         mPrimRst     => primRst,
         sPrimMaster  => mPrimMaster,
         sPrimCtrl    => mPrimCtrl,
         mPrimMaster  => obMacPrimMaster,
         mPrimSlave   => obMacPrimSlave,
         -- Bypass interface
         mBypClk      => bypClk,
         mBypRst      => bypRst,
         sBypMaster   => mBypMaster,
         sBypCtrl     => mBypCtrl,
         mBypMaster   => obMacBypMaster,
         mBypSlave    => obMacBypSlave,
         -- VLAN Interfaces
         mVlanClk     => vlanClk,
         mVlanRst     => vlanRst,
         sVlanMasters => mVlanMasters,
         sVlanCtrl    => mVlanCtrl,
         mVlanMasters => obMacVlanMasters,
         mVlanSlaves  => obMacVlanSlaves);

end mapping;
