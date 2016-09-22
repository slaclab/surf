-------------------------------------------------------------------------------
-- Title      : 1GbE/10GbE/40GbE Ethernet MAC
-------------------------------------------------------------------------------
-- File       : EthMacTx.vhd
-- Author     : Ryan Herbst <rherbst@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-22
-- Last update: 2016-09-21
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

entity EthMacTx is
   generic (
      -- Simulation Generics
      TPD_G           : time                     := 1 ns;
      -- MAC Configurations
      PAUSE_EN_G      : boolean                  := true;
      PAUSE_512BITS_G : positive range 1 to 1024 := 8;
      PHY_TYPE_G      : string                   := "XGMII";
      DROP_ERR_PKT_G  : boolean                  := true;
      JUMBO_G         : boolean                  := true;
      -- Non-VLAN Configurations
      BYP_EN_G        : boolean                  := false;
      SHIFT_EN_G      : boolean                  := false;
      -- VLAN Configurations
      VLAN_EN_G       : boolean                  := false;
      VLAN_CNT_G      : positive range 1 to 8    := 1);
   port (
      -- Clock and Reset
      ethClk         : in  sl;
      ethRst         : in  sl;
      -- Primary Interface
      sPrimMaster    : in  AxiStreamMasterType;
      sPrimSlave     : out AxiStreamSlaveType;
      -- Bypass interface
      sBypMaster     : in  AxiStreamMasterType;
      sBypSlave      : out AxiStreamSlaveType;
      -- VLAN Interfaces
      sVlanMasters   : in  AxiStreamMasterArray(VLAN_CNT_G-1 downto 0);
      sVlanSlaves    : out AxiStreamSlaveArray(VLAN_CNT_G-1 downto 0);
      -- XLGMII PHY Interface
      xlgmiiTxd      : out slv(127 downto 0);
      xlgmiiTxc      : out slv(15 downto 0);
      -- XGMII PHY Interface
      xgmiiTxd       : out slv(63 downto 0);
      xgmiiTxc       : out slv(7 downto 0);
      -- GMII PHY Interface
      gmiiTxEn       : out sl;
      gmiiTxEr       : out sl;
      gmiiTxd        : out slv(7 downto 0);
      -- Flow control Interface
      clientPause    : in  sl;
      rxPauseReq     : in  sl;
      rxPauseValue   : in  slv(15 downto 0);
      pauseTx        : out sl;
      pauseVlanTx    : out slv(7 downto 0);
      -- Configuration and status
      phyReady       : in  sl;
      ethConfig      : in  EthMacConfigType;
      txCountEn      : out sl;
      txUnderRun     : out sl;
      txLinkNotReady : out sl);  
end EthMacTx;

architecture mapping of EthMacTx is

   signal shiftMaster  : AxiStreamMasterType;
   signal shiftSlave   : AxiStreamSlaveType;
   signal bypassMaster : AxiStreamMasterType;
   signal bypassSlave  : AxiStreamSlaveType;
   signal toeMaster    : AxiStreamMasterType;
   signal toeSlave     : AxiStreamSlaveType;
   signal toeMasters   : AxiStreamMasterArray(VLAN_CNT_G-1 downto 0);
   signal toeSlaves    : AxiStreamSlaveArray(VLAN_CNT_G-1 downto 0);
   signal macObMaster  : AxiStreamMasterType;
   signal macObSlave   : AxiStreamSlaveType;

begin

   ------------------
   -- TX Shift Module
   ------------------
   U_Shift : entity work.EthMacTxShift
      generic map (
         TPD_G      => TPD_G,
         SHIFT_EN_G => SHIFT_EN_G) 
      port map (
         -- Clock and Reset
         ethClk      => ethClk,
         ethRst      => ethRst,
         -- AXIS Interface
         sAxisMaster => sPrimMaster,
         sAxisSlave  => sPrimSlave,
         mAxisMaster => shiftMaster,
         mAxisSlave  => shiftSlave,
         -- Configuration
         txShift     => ethConfig.txShift);

   -------------------
   -- TX Bypass Module
   -------------------
   U_Bypass : entity work.EthMacTxBypass
      generic map (
         TPD_G    => TPD_G,
         BYP_EN_G => BYP_EN_G) 
      port map (
         -- Clock and Reset
         ethClk      => ethClk,
         ethRst      => ethRst,
         -- Incoming primary traffic
         sPrimMaster => shiftMaster,
         sPrimSlave  => shiftSlave,
         -- Incoming bypass traffic
         sBypMaster  => sBypMaster,
         sBypSlave   => sBypSlave,
         -- Outgoing data to MAC
         mAxisMaster => bypassMaster,
         mAxisSlave  => bypassSlave);

   -------------------------
   -- TX Non-VLAN TOE Module
   -------------------------
   U_Csum : entity work.EthMacTxCsum
      generic map (
         TPD_G          => TPD_G,
         DROP_ERR_PKT_G => DROP_ERR_PKT_G,
         JUMBO_G        => JUMBO_G,
         VLAN_G         => false) 
      port map (
         -- Clock and Reset
         ethClk      => ethClk,
         ethRst      => ethRst,
         -- Configurations
         ipCsumEn    => ethConfig.ipCsumEn,
         tcpCsumEn   => ethConfig.tcpCsumEn,
         udpCsumEn   => ethConfig.udpCsumEn,
         -- Outbound data to MAC
         sAxisMaster => bypassMaster,
         sAxisSlave  => bypassSlave,
         mAxisMaster => toeMaster,
         mAxisSlave  => toeSlave);

   ---------------------
   -- TX VLAN TOE Module
   ---------------------         
   GEN_VLAN : if (VLAN_EN_G = true) generate
      GEN_VEC :
      for i in (VLAN_CNT_G-1) downto 0 generate
         U_Csum : entity work.EthMacTxCsum
            generic map (
               TPD_G          => TPD_G,
               DROP_ERR_PKT_G => DROP_ERR_PKT_G,
               JUMBO_G        => JUMBO_G,
               VLAN_G         => true) 
            port map (
               -- Clock and Reset
               ethClk      => ethClk,
               ethRst      => ethRst,
               -- Configurations
               ipCsumEn    => '1',
               tcpCsumEn   => '1',
               udpCsumEn   => '1',
               -- Outbound data to MAC
               sAxisMaster => sVlanMasters(i),
               sAxisSlave  => sVlanSlaves(i),
               mAxisMaster => toeMasters(i),
               mAxisSlave  => toeSlaves(i));
      end generate GEN_VEC;
   end generate;

   BYPASS_VLAN : if (VLAN_EN_G = false) generate
      -- Terminate Unused buses
      sVlanSlaves <= (others => AXI_STREAM_SLAVE_FORCE_C);
      toeMasters  <= (others => AXI_STREAM_MASTER_INIT_C);
   end generate;

   ------------------
   -- TX Pause Module
   ------------------
   U_Pause : entity work.EthMacTxPause
      generic map (
         TPD_G           => TPD_G,
         PAUSE_EN_G      => PAUSE_EN_G,
         PAUSE_512BITS_G => PAUSE_512BITS_G,
         VLAN_EN_G       => VLAN_EN_G,
         VLAN_CNT_G      => VLAN_CNT_G)        
      port map (
         -- Clock and Reset
         ethClk       => ethClk,
         ethRst       => ethRst,
         -- Incoming data from client
         sAxisMaster  => toeMaster,
         sAxisSlave   => toeSlave,
         sAxisMasters => toeMasters,
         sAxisSlaves  => toeSlaves,
         -- Outgoing data to MAC
         mAxisMaster  => macObMaster,
         mAxisSlave   => macObSlave,
         -- Flow control input
         clientPause  => clientPause,
         -- Inputs from pause frame RX
         rxPauseReq   => rxPauseReq,
         rxPauseValue => rxPauseValue,
         -- Configuration and status
         phyReady     => phyReady,
         pauseEnable  => ethConfig.pauseEnable,
         pauseTime    => ethConfig.pauseTime,
         macAddress   => ethConfig.macAddress,
         pauseTx      => pauseTx,
         pauseVlanTx  => pauseVlanTx);

   -----------------------
   -- TX MAC Export Module 
   -----------------------
   U_Export : entity work.EthMacTxExport
      generic map (
         TPD_G      => TPD_G,
         PHY_TYPE_G => PHY_TYPE_G)
      port map (
         -- Clock and reset
         ethClk         => ethClk,
         ethRst         => ethRst,
         -- AXIS Interface   
         macObMaster    => macObMaster,
         macObSlave     => macObSlave,
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
         -- Configuration and status
         macAddress     => ethConfig.macAddress,
         phyReady       => phyReady,
         txCountEn      => txCountEn,
         txUnderRun     => txUnderRun,
         txLinkNotReady => txLinkNotReady);

end mapping;
