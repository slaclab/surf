-------------------------------------------------------------------------------
-- Title      : 1GbE/10GbE Ethernet MAC
-------------------------------------------------------------------------------
-- File       : EthMacTop.vhd
-- Author     : Ryan Herbst <rherbst@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-22
-- Last update: 2016-09-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Generic Ethernet MAC
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.AxiStreamPkg.all;
use work.StdRtlPkg.all;
use work.EthMacPkg.all;

entity EthMacTop is
   generic (
      -- Simulation Generics
      TPD_G           : time                     := 1 ns;
      -- MAC Configurations
      PAUSE_EN_G      : boolean                  := true;
      PAUSE_512BITS_G : positive range 1 to 1024 := 8;
      GMII_EN_G       : boolean                  := false;  -- False = XGMII Interface only, True = GMII Interface only
      -- Non-VLAN Configurations
      FILT_EN_G       : boolean                  := false;
      BYP_EN_G        : boolean                  := false;
      BYP_ETH_TYPE_G  : slv(15 downto 0)         := x"0000";
      SHIFT_EN_G      : boolean                  := false;
      JUMBO_G         : boolean                  := false;
      -- VLAN Configurations
      VLAN_EN_G       : boolean                  := false;
      VLAN_CNT_G      : positive range 1 to 8    := 1;
      VLAN_JUMBO_G    : boolean                  := false);   
   port (
      -- Clock and Reset
      ethClk       : in  sl;
      ethClkRst    : in  sl;
      -- Primary Interface, TX
      sPrimMaster  : in  AxiStreamMasterType;
      sPrimSlave   : out AxiStreamSlaveType;
      -- Primary Interface, RX
      mPrimMaster  : out AxiStreamMasterType;
      mPrimCtrl    : in  AxiStreamCtrlType;
      -- Bypass interface, TX
      sBypMaster   : in  AxiStreamMasterType                         := AXI_STREAM_MASTER_INIT_C;
      sBypSlave    : out AxiStreamSlaveType;
      -- Bypass Interface, RX
      mBypMaster   : out AxiStreamMasterType;
      mBypCtrl     : in  AxiStreamCtrlType                           := AXI_STREAM_CTRL_UNUSED_C;
      -- VLAN Interfaces, TX
      sVlanMasters : in  AxiStreamMasterArray(VLAN_CNT_G-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
      sVlanSlaves  : out AxiStreamSlaveArray(VLAN_CNT_G-1 downto 0);
      -- VLAN Interfaces, RX
      mVlanMaster  : out AxiStreamMasterArray(VLAN_CNT_G-1 downto 0);
      mVlanCtrl    : in  AxiStreamCtrlArray(VLAN_CNT_G-1 downto 0)   := (others => AXI_STREAM_CTRL_UNUSED_C);
      -- XGMII PHY Interface
      phyTxd       : out slv(63 downto 0);
      phyTxc       : out slv(7 downto 0);
      phyRxd       : in  slv(63 downto 0);
      phyRxc       : in  slv(7 downto 0);
      phyReady     : in  sl;
      -- GMII PHY Interface
      gmiiRxDv     : in  sl                                          := '0';
      gmiiRxEr     : in  sl                                          := '0';
      gmiiRxd      : in  slv(7 downto 0)                             := x"00";
      gmiiTxEn     : out sl;
      gmiiTxEr     : out sl;
      gmiiTxd      : out slv(7 downto 0);
      -- Configuration and status
      ethConfig    : in  EthMacConfigType;
      ethStatus    : out EthMacStatusType);
end EthMacTop;

architecture mapping of EthMacTop is

   signal rxPauseReq   : sl;
   signal rxPauseValue : slv(15 downto 0);
   signal intCtrl      : AxiStreamCtrlType;

begin

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
         GMII_EN_G       => GMII_EN_G,
         -- Non-VLAN Configurations
         BYP_EN_G        => BYP_EN_G,
         SHIFT_EN_G      => SHIFT_EN_G,
         JUMBO_G         => JUMBO_G,
         -- VLAN Configurations
         VLAN_EN_G       => VLAN_EN_G,
         VLAN_CNT_G      => VLAN_CNT_G,
         VLAN_JUMBO_G    => VLAN_JUMBO_G)
      port map (
         -- Clocks
         ethClk         => ethClk,
         ethRst         => ethClkRst,
         -- Primary Interface
         sPrimMaster    => sPrimMaster,
         sPrimSlave     => sPrimSlave,
         -- Bypass interface
         sBypMaster     => sBypMaster,
         sBypSlave      => sBypSlave,
         -- VLAN Interfaces
         sVlanMasters   => sVlanMasters,
         sVlanSlaves    => sVlanSlaves,
         -- XGMII PHY Interface
         phyTxd         => phyTxd,
         phyTxc         => phyTxc,
         phyReady       => phyReady,
         -- GMII PHY Interface
         gmiiTxEn       => gmiiTxEn,
         gmiiTxEr       => gmiiTxEr,
         gmiiTxd        => gmiiTxd,
         -- Configurations
         ethConfig      => ethConfig,
         -- Flow control Interface
         clientPause    => intCtrl.pause,
         rxPauseReq     => rxPauseReq,
         rxPauseValue   => rxPauseValue,
         pauseTx        => ethStatus.txPauseCnt,
         pauseVlanTx    => ethStatus.vlantxPauseCnt,
         -- Status
         txCountEn      => ethStatus.txCountEn,
         txUnderRun     => ethStatus.txUnderRunCnt,
         txLinkNotReady => ethStatus.txNotReadyCnt);

   ---------------------      
   -- Flow Control Logic
   ---------------------      

   -- Pass control signals (VLAN pause not supported yet)
   intCtrl.pause    <= mPrimCtrl.pause or mBypCtrl.pause;
   intCtrl.overflow <= mPrimCtrl.overflow or mBypCtrl.overflow;
   intCtrl.idle     <= '0';

   -- Status signals (VLAN pause not supported yet)
   ethStatus.vlanRxPauseCnt <= (others => '0');
   ethStatus.rxPauseCnt     <= rxPauseReq;
   ethStatus.rxOverFlow     <= intCtrl.overflow;

   ------------
   -- RX Module
   ------------      
   U_Rx : entity work.EthMacRx
      generic map (
         -- Simulation Generics
         TPD_G          => TPD_G,
         -- MAC Configurations
         PAUSE_EN_G     => PAUSE_EN_G,
         GMII_EN_G      => GMII_EN_G,
         -- Non-VLAN Configurations
         FILT_EN_G      => FILT_EN_G,
         BYP_EN_G       => BYP_EN_G,
         BYP_ETH_TYPE_G => BYP_ETH_TYPE_G,
         SHIFT_EN_G     => SHIFT_EN_G,
         JUMBO_G        => JUMBO_G,
         -- VLAN Configurations
         VLAN_EN_G      => VLAN_EN_G,
         VLAN_CNT_G     => VLAN_CNT_G,
         VLAN_JUMBO_G   => VLAN_JUMBO_G)
      port map (
         -- Clock and Reset
         ethClk       => ethClk,
         ethRst       => ethClkRst,
         -- Primary Interface
         mPrimMaster  => mPrimMaster,
         mPrimCtrl    => mPrimCtrl,
         -- Bypass Interface
         mBypMaster   => mBypMaster,
         mBypCtrl     => mBypCtrl,
         -- Vlan Interfaces
         mVlanMaster  => mVlanMaster,
         mVlanCtrl    => mVlanCtrl,
         -- XGMII PHY Interface
         phyRxd       => phyRxd,
         phyRxc       => phyRxc,
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

end mapping;
