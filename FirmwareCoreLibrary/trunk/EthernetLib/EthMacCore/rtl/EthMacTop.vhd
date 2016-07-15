-------------------------------------------------------------------------------
-- Title      : Generic Ethernet MAC
-------------------------------------------------------------------------------
-- File       : EthMacTop.vhd
-- Author     : Ryan Herbst <rherbst@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-22
-- Last update: 2016-07-15
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
      TPD_G           : time                    := 1 ns;
      PAUSE_EN_G      : boolean                 := true;
      PAUSE_512BITS_G : natural range 1 to 1024 := 8;
      VLAN_CNT_G      : natural range 1 to 8    := 1;
      VLAN_EN_G       : boolean                 := false;
      BYP_EN_G        : boolean                 := false;
      BYP_ETH_TYPE_G  : slv(15 downto 0)        := x"0000";
      SHIFT_EN_G      : boolean                 := false;
      FILT_EN_G       : boolean                 := false;
      CSUM_EN_G       : boolean                 := false;
      GMII_EN_G       : boolean                 := false);  -- False = XGMII Interface only, True = GMII Interface only
   port (
      -- Clocks
      ethClk      : in  sl;
      ethClkRst   : in  sl;
      -- Primary Interface, TX
      sPrimMaster : in  AxiStreamMasterType;
      sPrimSlave  : out AxiStreamSlaveType;
      -- Primary Interface, RX
      mPrimMaster : out AxiStreamMasterType;
      mPrimCtrl   : in  AxiStreamCtrlType;
      -- Bypass interface, TX
      sBypMaster  : in  AxiStreamMasterType                         := AXI_STREAM_MASTER_INIT_C;
      sBypSlave   : out AxiStreamSlaveType;
      -- Bypass Interfaces, RX
      mBypMaster  : out AxiStreamMasterType;
      mBypCtrl    : in  AxiStreamCtrlType                           := AXI_STREAM_CTRL_UNUSED_C;
      -- VLAN Interfaces, TX
      sVlanMaster : in  AxiStreamMasterArray(VLAN_CNT_G-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
      sVlanSlave  : out AxiStreamSlaveArray(VLAN_CNT_G-1 downto 0);
      -- Vlan Interfaces, RX
      mVlanMaster : out AxiStreamMasterArray(VLAN_CNT_G-1 downto 0);
      mVlanCtrl   : in  AxiStreamCtrlArray(VLAN_CNT_G-1 downto 0)   := (others => AXI_STREAM_CTRL_UNUSED_C);
      -- XGMII PHY Interface
      phyTxd      : out slv(63 downto 0);
      phyTxc      : out slv(7 downto 0);
      phyRxd      : in  slv(63 downto 0);
      phyRxc      : in  slv(7 downto 0);
      phyReady    : in  sl;
      -- GMII PHY Interface
      gmiiRxDv    : in  sl                                          := '0';
      gmiiRxEr    : in  sl                                          := '0';
      gmiiRxd     : in  slv(7 downto 0)                             := x"00";
      gmiiTxEn    : out sl;
      gmiiTxEr    : out sl;
      gmiiTxd     : out slv(7 downto 0);
      -- Configuration and status
      ethConfig   : in  EthMacConfigType;
      ethStatus   : out EthMacStatusType);
end EthMacTop;

architecture mapping of EthMacTop is

   signal rxPauseReq    : sl;
   signal rxPauseValue  : slv(15 downto 0);
   signal shiftTxMaster : AxiStreamMasterType;
   signal shiftTxSlave  : AxiStreamSlaveType;
   signal bypTxMaster   : AxiStreamMasterType;
   signal bypTxSlave    : AxiStreamSlaveType;
   signal shiftRxMaster : AxiStreamMasterType;
   signal pauseTxMaster : AxiStreamMasterType;
   signal pauseTxSlave  : AxiStreamSlaveType;
   signal macIbMaster   : AxiStreamMasterType;
   signal pauseRxMaster : AxiStreamMasterType;
   signal bypassMaster  : AxiStreamMasterType;
   signal intCtrl       : AxiStreamCtrlType;

begin

   -- No VLAN Support Yet!
   sVlanSlave  <= (others => AXI_STREAM_SLAVE_INIT_C);
   mVlanMaster <= (others => AXI_STREAM_MASTER_INIT_C);

   -- Pass control signals
   intCtrl.pause    <= mPrimCtrl.pause or mBypCtrl.pause;
   intCtrl.overflow <= mPrimCtrl.overflow or mBypCtrl.overflow;
   intCtrl.idle     <= '0';

   -- Status signals
   ethStatus.rxPauseCnt <= rxPauseReq;
   ethStatus.rxOverFlow <= intCtrl.overflow;

   ----------------------
   -- TX Shift Generation
   ----------------------
   U_TxShiftEnGen : if SHIFT_EN_G = true generate
      -- Shift outbound data n bytes to the right.
      -- This removes bytes of data at start 
      -- of the packet. These were added by software
      -- to create a software friendly alignment of 
      -- outbound data.
      U_TxShift : entity work.AxiStreamShift
         generic map (
            TPD_G         => TPD_G,
            AXIS_CONFIG_G => EMAC_AXIS_CONFIG_C) 
         port map (
            axisClk     => ethClk,
            axisRst     => ethClkRst,
            axiStart    => '1',
            axiShiftDir => '1',         -- 1 = right (msb to lsb)
            axiShiftCnt => ethConfig.txShift,
            sAxisMaster => sPrimMaster,
            sAxisSlave  => sPrimSlave,
            mAxisMaster => shiftTxMaster,
            mAxisSlave  => shiftTxSlave);
   end generate;

   U_TxShiftDisGen : if SHIFT_EN_G = false generate
      sPrimSlave    <= shiftTxSlave;
      shiftTxMaster <= sPrimMaster;
   end generate;

   -----------------------
   -- TX Bypass Generation
   -----------------------     
   U_BypTxEnGen : if BYP_EN_G = true generate
      U_BypassMux : entity work.EthMacBypassMux
         generic map (
            TPD_G => TPD_G) 
         port map (
            ethClk      => ethClk,
            ethClkRst   => ethClkRst,
            sPrimMaster => shiftTxMaster,
            sPrimSlave  => shiftTxSlave,
            sBypMaster  => sBypMaster,
            sBypSlave   => sBypSlave,
            mAxisMaster => bypTxMaster,
            mAxisSlave  => bypTxSlave);
   end generate;

   U_BypTxDisGen : if BYP_EN_G = false generate
      bypTxMaster  <= shiftTxMaster;
      shiftTxSlave <= bypTxSlave;
      sBypSlave    <= AXI_STREAM_SLAVE_FORCE_C;
   end generate;

   ----------------------
   -- TX Pause Generation
   ----------------------      
   U_TxPauseGen : if PAUSE_EN_G = true generate
      U_EthMacPauseTx : entity work.EthMacPauseTx
         generic map (
            TPD_G           => TPD_G,
            PAUSE_512BITS_G => PAUSE_512BITS_G) 
         port map (
            ethClk       => ethClk,
            ethClkRst    => ethClkRst,
            sAxisMaster  => bypTxMaster,
            sAxisSlave   => bypTxSlave,
            mAxisMaster  => pauseTxMaster,
            mAxisSlave   => pauseTxSlave,
            clientPause  => intCtrl.pause,
            phyReady     => phyReady,
            rxPauseReq   => rxPauseReq,
            rxPauseValue => rxPauseValue,
            pauseEnable  => ethConfig.pauseEnable,
            pauseTime    => ethConfig.pauseTime,
            macAddress   => ethConfig.macAddress,
            pauseTx      => ethStatus.txPauseCnt);
   end generate;

   U_BypTxPause : if PAUSE_EN_G = false generate
      pauseTxMaster        <= bypTxMaster;
      bypTxSlave           <= pauseTxSlave;
      ethStatus.txPauseCnt <= '0';
   end generate;

   ---------------------------     
   -- TX MAC Export Generation
   ---------------------------            
   U_10G_EXPORT : if GMII_EN_G = false generate
      U_EthMacExport : entity work.EthMacExport
         generic map (
            TPD_G => TPD_G) 
         port map (
            ethClk         => ethClk,
            ethClkRst      => ethClkRst,
            macObMaster    => pauseTxMaster,
            macObSlave     => pauseTxSlave,
            phyTxd         => phyTxd,
            phyTxc         => phyTxc,
            phyReady       => phyReady,
            interFrameGap  => ethConfig.interFramegap,
            macAddress     => ethConfig.macAddress,
            txCountEn      => ethStatus.txCountEn,
            txUnderRun     => ethStatus.txUnderRunCnt,
            txLinkNotReady => ethStatus.txNotReadyCnt);
      -- Unused output ports
      gmiiTxEn <= '0';
      gmiiTxEr <= '0';
      gmiiTxd  <= (others => '0');
   end generate;

   U_1G_EXPORT : if GMII_EN_G = true generate
      U_EthMacExport : entity work.EthMacExportGmii
         generic map (
            TPD_G => TPD_G) 
         port map (
            ethClk         => ethClk,
            ethClkRst      => ethClkRst,
            macObMaster    => pauseTxMaster,
            macObSlave     => pauseTxSlave,
            gmiiTxEn       => gmiiTxEn,
            gmiiTxEr       => gmiiTxEr,
            gmiiTxd        => gmiiTxd,
            phyReady       => phyReady,
            interFrameGap  => ethConfig.interFramegap,
            macAddress     => ethConfig.macAddress,
            txCountEn      => ethStatus.txCountEn,
            txUnderRun     => ethStatus.txUnderRunCnt,
            txLinkNotReady => ethStatus.txNotReadyCnt);
      -- Unused output ports
      phyTxd <= (others => '0');
      phyTxc <= (others => '0');
   end generate;

   ---------------------------     
   -- RX MAC Import Generation
   ---------------------------     
   U_10G_IMPORT : if GMII_EN_G = false generate
      U_EthMacImport : entity work.EthMacImport
         generic map (
            TPD_G => TPD_G) 
         port map (
            ethClk      => ethClk,
            ethClkRst   => ethClkRst,
            macIbMaster => macIbMaster,
            phyRxd      => phyRxd,
            phyRxc      => phyRxc,
            phyReady    => phyReady,
            rxCountEn   => ethStatus.rxCountEn,
            rxCrcError  => ethStatus.rxCrcErrorCnt);
   end generate;

   U_1G_IMPORT : if GMII_EN_G = true generate
      U_EthMacImport : entity work.EthMacImportGmii
         generic map (
            TPD_G => TPD_G) 
         port map (
            ethClk      => ethClk,
            ethClkRst   => ethClkRst,
            macIbMaster => macIbMaster,
            gmiiRxDv    => gmiiRxDv,
            gmiiRxEr    => gmiiRxEr,
            gmiiRxd     => gmiiRxd,
            phyReady    => phyReady,
            rxCountEn   => ethStatus.rxCountEn,
            rxCrcError  => ethStatus.rxCrcErrorCnt);
   end generate;

   ----------------------
   -- RX Pause Generation
   ----------------------    
   U_RxPauseGen : if PAUSE_EN_G = true generate
      U_EthMacPauseRx : entity work.EthMacPauseRx
         generic map (
            TPD_G => TPD_G) 
         port map (
            ethClk       => ethClk,
            ethClkRst    => ethClkRst,
            sAxisMaster  => macIbMaster,
            mAxisMaster  => pauseRxMaster,
            rxPauseReq   => rxPauseReq,
            rxPauseValue => rxPauseValue);
   end generate;

   U_BypRxPause : if PAUSE_EN_G = false generate
      pauseRxMaster <= macIbMaster;
      rxPauseReq    <= '0';
      rxPauseValue  <= (others => '0');
   end generate;

   -----------------------
   -- RX Bypass Generation
   -----------------------   
   U_BypRxEnGen : if BYP_EN_G = true generate
      U_EthMacBypassRx : entity work.EthMacBypassRx
         generic map (
            TPD_G          => TPD_G,
            BYP_ETH_TYPE_G => BYP_ETH_TYPE_G) 
         port map (
            ethClk      => ethClk,
            ethClkRst   => ethClkRst,
            sAxisMaster => pauseRxMaster,
            mPrimMaster => bypassMaster,
            mBypMaster  => mBypMaster);
   end generate;

   U_BypRxDisGen : if BYP_EN_G = false generate
      bypassMaster <= pauseRxMaster;
      mBypMaster   <= AXI_STREAM_MASTER_INIT_C;
   end generate;

   -----------------------
   -- RX Filter Generation
   -----------------------
   U_FiltEnGen : if FILT_EN_G = true generate
      U_EthMacFilter : entity work.EthMacFilter
         generic map (
            TPD_G => TPD_G) 
         port map (
            ethClk      => ethClk,
            ethClkRst   => ethClkRst,
            sAxisMaster => bypassMaster,
            mAxisMaster => shiftRxMaster,
            mAxisCtrl   => mPrimCtrl,
            dropOnPause => ethConfig.dropOnPause,
            macAddress  => ethConfig.macAddress,
            filtEnable  => ethConfig.filtEnable);
   end generate;

   U_FiltDisGen : if FILT_EN_G = false generate
      shiftRxMaster <= pauseRxMaster;
   end generate;

   ----------------------
   -- RX Shift Generation
   ----------------------
   U_RxShiftEnGen : if SHIFT_EN_G = true generate
      -- Shift inbound data n bytes to the left.
      -- This adds bytes of data at start of the packet. 
      U_RxShift : entity work.AxiStreamShift
         generic map (
            TPD_G          => TPD_G,
            AXIS_CONFIG_G  => EMAC_AXIS_CONFIG_C,
            ADD_VALID_EN_G => true) 
         port map (
            axisClk     => ethClk,
            axisRst     => ethClkRst,
            axiStart    => '1',
            axiShiftDir => '0',         -- 0 = left (lsb to msb)
            axiShiftCnt => ethConfig.rxShift,
            sAxisMaster => shiftRxMaster,
            sAxisSlave  => open,
            mAxisMaster => mPrimMaster,
            mAxisSlave  => AXI_STREAM_SLAVE_FORCE_C);
   end generate;

   U_RxShiftDisGen : if SHIFT_EN_G = false generate
      mPrimMaster <= shiftRxMaster;
   end generate;

end mapping;
