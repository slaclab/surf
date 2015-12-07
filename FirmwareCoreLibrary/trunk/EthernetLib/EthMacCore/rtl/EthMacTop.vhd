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
      VLAN_CNT_G      : natural range 0 to 7    := 0;
      SHIFT_EN_G      : boolean                 := false;
      FILT_EN_G       : boolean                 := false;
      CSUM_EN_G       : boolean                 := false
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
      ethConfig    : in  EthMacConfigArray(VLAN_CNT_G downto 0);
      ethStatus    : out EthMacStatusArray(VLAN_CNT_G downto 0)
   );
end EthMacTop;


-- Define architecture
architecture EthMacTop of EthMacTop is

   signal rxPauseReq    : sl;
   signal rxPauseValue  : slv(15 downto 0);
   signal shiftTxMaster : AxiStreamMasterType;
   signal shiftTxSlave  : AxiStreamSlaveType;
   signal shiftRxMaster : AxiStreamMasterType;
   signal pauseTxMaster : AxiStreamMasterType;
   signal pauseTxSlave  : AxiStreamSlaveType;
   signal macIbMaster   : AxiStreamMasterType;
   signal pauseRxMaster : AxiStreamMasterType;

begin

   ethStatus(0).rxPauseCnt <= rxPauseReq;
   ethStatus(0).rxOverFlow <= mAxisCtrl(0).overflow;

   ---------------------------------
   -- Optional shifters
   ---------------------------------
   U_ShiftEnGen: if SHIFT_EN_G = true generate

      -- Shift outbound data n bytes to the right.
      -- This removes bytes of data at start 
      -- of the packet. These were added by software
      -- to create a software friendly alignment of 
      -- outbound data.
      U_TxShift : entity work.AxiStreamShift
         generic map (
            TPD_G         => TPD_G,
            AXIS_CONFIG_G => EMAC_AXIS_CONFIG_C
         ) port map (
            axisClk     => ethClk,
            axisRst     => ethClkRst,
            axiStart    => '1',
            axiShiftDir => '1', -- 1 = right (msb to lsb)
            axiShiftCnt => ethConfig(0).txShift,
            sAxisMaster => sAxisMaster(0),
            sAxisSlave  => sAxisSlave(0),
            mAxisMaster => shiftTxMaster,
            mAxisSlave  => shiftTxSlave
         );

      -- Shift inbound data n bytes to the left.
      -- This adds bytes of data at start of the packet. 
      U_RxShift : entity work.AxiStreamShift
         generic map (
            TPD_G          => TPD_G,
            AXIS_CONFIG_G  => EMAC_AXIS_CONFIG_C,
            ADD_VALID_EN_G => true
         ) port map (
            axisClk     => ethClk,
            axisRst     => ethClkRst,
            axiStart    => '1',
            axiShiftDir => '0', -- 0 = left (lsb to msb)
            axiShiftCnt => ethConfig(0).rxShift,
            sAxisMaster => shiftRxMaster,
            sAxisSlave  => open,
            mAxisMaster => mAxisMaster(0),
            mAxisSlave  => AXI_STREAM_SLAVE_FORCE_C
         );
   end generate;

   U_ShiftDisGen: if SHIFT_EN_G = false generate
      mAxisMaster(0) <= shiftRxMaster;
      shiftTxMaster  <= sAxisMaster(0);
      sAxisSlave(0)  <= shiftTxSlave;
   end generate;


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
         sAxisMaster  => shiftTxMaster,
         sAxisSlave   => shiftTxSlave,
         mAxisMaster  => pauseTxMaster,
         mAxisSlave   => pauseTxSlave,
         clientPause  => mAxisCtrl(0).pause,
         phyReady     => phyReady,
         rxPauseReq   => rxPauseReq,
         rxPauseValue => rxPauseValue,
         pauseEnable  => ethConfig(0).pauseEnable,
         pauseTime    => ethConfig(0).pauseTime,
         macAddress   => ethConfig(0).macAddress,
         pauseTx      => ethStatus(0).txPauseCnt
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
         interFrameGap  => ethConfig(0).interFramegap,
         macAddress     => ethConfig(0).macAddress,
         txCountEn      => ethStatus(0).txCountEn,
         txUnderRun     => ethStatus(0).txUnderRunCnt,
         txLinkNotReady => ethStatus(0).txNotReadyCnt
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
         rxCountEn   => ethStatus(0).rxCountEn,
         rxCrcError  => ethStatus(0).rxCrcErrorCnt
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

   U_FiltEnGen: if FILT_EN_G = true generate
      U_EthMacFilter : entity work.EthMacFilter
         generic map (
            TPD_G => TPD_G
         ) port map ( 
            ethClk       => ethClk,
            ethClkRst    => ethClkRst,
            sAxisMaster  => pauseRxMaster,
            mAxisMaster  => shiftRxMaster,
            macAddress   => ethConfig(0).macAddress,
            filtEnable   => ethConfig(0).filtEnable
         );
   end generate;

   U_FiltDisGen: if FILT_EN_G = false generate
      shiftRxMaster <= pauseRxMaster;
   end generate;


end EthMacTop;

