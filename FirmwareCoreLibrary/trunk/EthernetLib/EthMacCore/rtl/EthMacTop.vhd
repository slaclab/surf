-------------------------------------------------------------------------------
-- Title         : Generic Ethernet MAC
-- Project       : Ethernet MAC
-------------------------------------------------------------------------------
-- File          : EthMacTop.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 09/22/2015
-------------------------------------------------------------------------------
-- Description:
-- Generic ethernet MAC
-------------------------------------------------------------------------------
-- Copyright (c) 2015 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 09/22/2015: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.AxiStreamPkg.all;
use work.StdRtlPkg.all;
use work.EthMacPkg.all;

entity EthMacTop is 
   generic (
      TPD_G           : time := 1 ns;
      PAUSE_512BITS_G : natural range 1 to 1024 := 8;
      VLAN_CNT_G      : natural range 0 to 7    := 0
   );
   port ( 

      -- Clocks
      ethClk       : in  sl;
      ethClkRst    : in  sl;

      -- Client Interfaces, TX
      sAxisMaster  : in  AxiStreamMasterArray(VLAN_CNT_G downto 0);
      sAxisSlave   : out AxiStreamSlaveArray(VLAN_CNT_G downto 0);

      -- Client Interfaces, RX
      mAxisMaster  : out AxiStreamMasterArray(VLAN_CNT_G downto 0);
      mAxisCtrl    : in  AxiStreamCtrlArray(VLAN_CNT_G downto 0);

      -- PHY Interface
      phyTxd       : out slv(63 downto 0);
      phyTxc       : out slv(7  downto 0);
      phyRxd       : in  slv(63 downto 0);
      phyRxc       : in  slv(7  downto 0);
      phyReady     : in  sl;

      -- Configuration and status
      ethConfig    : in  EthMacConfigType;
      ethStatus    : out EthMacStatusType
   );
end EthMacTop;


-- Define architecture
architecture EthMacTop of EthMacTop is

   signal rxPauseReq    : sl;
   signal rxPauseValue  : slv(15 downto 0);
   signal pauseTxMaster : AxiStreamMasterType;
   signal pauseTxSlave  : AxiStreamSlaveType;
   signal macIbMaster   : AxiStreamMasterType;
   signal pauseRxMaster : AxiStreamMasterType;

begin

   ethStatus.rxPauseCnt <= rxPauseReq;
   ethStatus.rxOverFlow <= mAxisCtrl.overflow;

   ---------------------------------
   -- TX Path
   ---------------------------------

   U_EthMacPauseTx : entity work.EthMacPauseTx 
      generic map (
         TPD_G           => TPD_G,
         PAUSE_512BITS_G => PAUSE_512BITS_G 
      ) port map ( 
         ethClk       => ethClk,
         ethClkRst    => ethClkRst,
         sAxisMaster  => sAxisMaster(0),
         sAxisSlave   => sAxisSlave(0),
         mAxisMaster  => pauseTxMaster,
         mAxisSlave   => pauseTxSlave,
         clientPause  => mAxisCtrl(0).pause,
         rxPauseReq   => rxPauseReq,
         rxPauseValue => rxPauseValue,
         pauseEnable  => ethConfig.pauseEnable,
         pauseTime    => ethConfig.pauseTime,
         macAddress   => ethConfig.macAddress,
         pauseTx      => ethStatus.txPauseCnt
      );

   U_EthMacExport: entity work.EthMacExport 
      generic map (
         TPD_G => TPD_G
      ) port map ( 
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
         txLinkNotReady => ethStatus.txNotReadyCnt
      );


   ---------------------------------
   -- RX Path
   ---------------------------------

   U_EthMacImport : entity work.EthMacImport
      generic map (
         TPD_G => TPD_G
      ) port map ( 
         ethClk      => ethClk,
         ethClkRst   => ethClkRst,
         macIbMaster => macIbMaster,
         phyRxd      => phyRxd,
         phyRxc      => phyRxc,
         phyReady    => phyReady,
         rxCountEn   => ethStatus.rxCountEn,
         rxCrcError  => ethStatus.rxCrcErrorCnt
      );

   U_EthMacPauseRx : entity work.EthMacPauseRx 
      generic map (
         TPD_G => TPD_G
      ) port map ( 
         ethClk       => ethClk,
         ethClkRst    => ethClkRst,
         sAxisMaster  => macIbMaster,
         mAxisMaster  => pauseRxMaster,
         rxPauseReq   => rxPauseReq,
         rxPauseValue => rxPauseValue
      );

   U_EthMacFilter : entity work.EthMacFilter
      generic map (
         TPD_G => TPD_G
      ) port map ( 
         ethClk       => ethClk,
         ethClkRst    => ethClkRst,
         sAxisMaster  => pauseRxMaster,
         mAxisMaster  => mAxisMaster(0),
         macAddress   => ethConfig.macAddress,
         filtEnable   => ethConfig.filtEnable
      );

end EthMacTop;

