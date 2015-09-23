-------------------------------------------------------------------------------
-- Title         : Generic Ethernet MAC
-- Project       : Ethernet MAC
-------------------------------------------------------------------------------
-- File          : EthMac.vhd
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
use work.EthPkg.all;

entity EthMac is 
   generic (
      TPD_G           : time := 1 ns,
      PAUSE_512BITS_G : integer range 1 to (2**32) := 8
   );
   port ( 

      -- Clocks
      ethClk       : in  sl;
      ethClkRst    : in  sl;

      -- Client Interface, TX
      sAxisMaster  : in  AxiStreamMasterType;
      sAxisSlave   : out AxiStreamSlaveType;

      -- Client Interface, RX
      mAxisMaster  : out AxiStreamMasterType;
      mAxisCtrl    : in  sl;

      -- PHY Interface
      phyTxd       : out slv(63 downto 0);
      phyTxc       : out slv(7  downto 0);
      phyRxd       : in  slv(63 downto 0);
      phyRxc       : in  slv(7  downto 0);
      phyReady     : in  sl;

      -- Configuration and status
      ethConfig    : in  EthConfig;
      ethStatus    : out EthStatus
   );
end EthMac;


-- Define architecture
architecture EthMac of EthMac is

   signal rxPauseReq    : sl;
   signal rxPauseValue  : slv(15 downto 0);
   signal pauseTxMaster : AxiStreamMasterType;
   signal pauseTxSlave  : AxiStreamSlaveType;
   signal macIbMaster   : AxiStreamMasterType;
   signal pauseRxMaster : AxiStreamMasterType;

begin

   ethStatus.rxPauseCnt <= rxPauseReq;

   ---------------------------------
   -- TX Path
   ---------------------------------

   U_EthPauseTx : entity work.EthPauseTx is 
      generic map (
         TPD_G           => TPD_G,
         PAUSE_512BITS_G => PAUSE_512BITS_G 
      ) port map ( 
         ethClk       => ethClk,
         ethClkRst    => ethClkRst,
         sAxisMaster  => sAxisMaster,
         sAxisSlave   => sAxisSlave,
         mAxisMaster  => pauseTxMaster,
         mAxisSlave   => pauseTxSlave,
         clientPause  => mAxisCtrl.pause,
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

   U_EthPauseRx : entity work.EthPauseRx 
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

   U_EthFilter : entity work.EthFilter
      generic map (
         TPD_G => TPD_G
      ) port map ( 
         ethClk       => ethClk,
         ethClkRst    => ethClkRst,
         sAxisMaster  => pauseRxMaster,
         mAxisMaster  => mAxisMaster,
         macAddress   => ethConfig.macAddress,
         filtEnable   => ethConfig.filtEnable
      );

end EthMac;

