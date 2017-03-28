-------------------------------------------------------------------------------
-- File       : EthMacRx.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-22
-- Last update: 2016-10-20
-------------------------------------------------------------------------------
-- Description: Ethernet MAC RX Wrapper
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

entity EthMacRx is
   generic (
      -- Simulation Generics
      TPD_G          : time                  := 1 ns;
      -- MAC Configurations
      PAUSE_EN_G     : boolean               := true;
      PHY_TYPE_G     : string                := "XGMII";
      JUMBO_G        : boolean               := true;
      -- Non-VLAN Configurations
      FILT_EN_G      : boolean               := false;
      BYP_EN_G       : boolean               := false;
      BYP_ETH_TYPE_G : slv(15 downto 0)      := x"0000";
      -- VLAN Configurations
      VLAN_EN_G      : boolean               := false;
      VLAN_SIZE_G    : positive range 1 to 8 := 1;
      VLAN_VID_G     : Slv12Array            := (0 => x"001"));
   port (
      -- Clock and Reset
      ethClk       : in  sl;
      ethRst       : in  sl;
      -- Primary Interface
      mPrimMaster  : out AxiStreamMasterType;
      mPrimCtrl    : in  AxiStreamCtrlType;
      -- Bypass Interface
      mBypMaster   : out AxiStreamMasterType;
      mBypCtrl     : in  AxiStreamCtrlType;
      -- VLAN Interfaces
      mVlanMasters : out AxiStreamMasterArray(VLAN_SIZE_G-1 downto 0);
      mVlanCtrl    : in  AxiStreamCtrlArray(VLAN_SIZE_G-1 downto 0);
      -- XLGMII PHY Interface
      xlgmiiRxd    : in  slv(127 downto 0);
      xlgmiiRxc    : in  slv(15 downto 0);
      -- XGMII PHY Interface
      xgmiiRxd     : in  slv(63 downto 0);
      xgmiiRxc     : in  slv(7 downto 0);
      -- GMII PHY Interface
      gmiiRxDv     : in  sl;
      gmiiRxEr     : in  sl;
      gmiiRxd      : in  slv(7 downto 0);
      -- Flow Control Interface
      rxPauseReq   : out sl;
      rxPauseValue : out slv(15 downto 0);
      -- Configuration and status
      phyReady     : in  sl;
      ethConfig    : in  EthMacConfigType;
      rxCountEn    : out sl;
      rxCrcError   : out sl);
end EthMacRx;

architecture mapping of EthMacRx is

   signal macIbMaster  : AxiStreamMasterType;
   signal pauseMaster  : AxiStreamMasterType;
   signal pauseMasters : AxiStreamMasterArray(VLAN_SIZE_G-1 downto 0);
   signal csumMaster   : AxiStreamMasterType;
   signal bypassMaster : AxiStreamMasterType;

begin

   -------------------
   -- RX Import Module
   -------------------
   U_Import : entity work.EthMacRxImport
      generic map (
         TPD_G      => TPD_G,
         PHY_TYPE_G => PHY_TYPE_G)
      port map (
         -- Clock and reset
         ethClk      => ethClk,
         ethRst      => ethRst,
         -- AXIS Interface   
         macIbMaster => macIbMaster,
         -- XLGMII PHY Interface
         xlgmiiRxd   => xlgmiiRxd,
         xlgmiiRxc   => xlgmiiRxc,
         -- XGMII PHY Interface
         xgmiiRxd    => xgmiiRxd,
         xgmiiRxc    => xgmiiRxc,
         -- GMII PHY Interface
         gmiiRxDv    => gmiiRxDv,
         gmiiRxEr    => gmiiRxEr,
         gmiiRxd     => gmiiRxd,
         -- Configuration and status
         phyReady    => phyReady,
         rxCountEn   => rxCountEn,
         rxCrcError  => rxCrcError);

   ------------------
   -- RX Pause Module
   ------------------
   U_Pause : entity work.EthMacRxPause
      generic map (
         TPD_G       => TPD_G,
         PAUSE_EN_G  => PAUSE_EN_G,
         VLAN_EN_G   => VLAN_EN_G,
         VLAN_SIZE_G => VLAN_SIZE_G,
         VLAN_VID_G  => VLAN_VID_G)         
      port map (
         -- Clock and Reset
         ethClk       => ethClk,
         ethRst       => ethRst,
         -- Incoming data from MAC
         sAxisMaster  => macIbMaster,
         -- Outgoing data 
         mAxisMaster  => pauseMaster,
         mAxisMasters => pauseMasters,
         -- Pause Values
         rxPauseReq   => rxPauseReq,
         rxPauseValue => rxPauseValue);

   ------------------------------
   -- RX Non-VLAN Checksum Module
   ------------------------------
   U_Csum : entity work.EthMacRxCsum
      generic map (
         TPD_G   => TPD_G,
         JUMBO_G => JUMBO_G,
         VLAN_G  => false) 
      port map (
         -- Clock and Reset
         ethClk      => ethClk,
         ethRst      => ethRst,
         -- Configurations
         ipCsumEn    => ethConfig.ipCsumEn,
         tcpCsumEn   => ethConfig.tcpCsumEn,
         udpCsumEn   => ethConfig.udpCsumEn,
         -- Outbound data to MAC
         sAxisMaster => pauseMaster,
         mAxisMaster => csumMaster);

   --------------------------         
   -- RX VLAN Checksum Module
   --------------------------         
   GEN_VLAN : if (VLAN_EN_G = true) generate
      GEN_VEC :
      for i in (VLAN_SIZE_G-1) downto 0 generate
         U_Csum : entity work.EthMacRxCsum
            generic map (
               TPD_G   => TPD_G,
               JUMBO_G => JUMBO_G,
               VLAN_G  => true) 
            port map (
               -- Clock and Reset
               ethClk      => ethClk,
               ethRst      => ethRst,
               -- Configurations
               ipCsumEn    => '1',
               tcpCsumEn   => '1',
               udpCsumEn   => '1',
               -- Outbound data to MAC
               sAxisMaster => pauseMasters(i),
               mAxisMaster => mVlanMasters(i));
      end generate GEN_VEC;
   end generate;

   BYPASS_VLAN : if (VLAN_EN_G = false) generate
      -- Terminate Unused buses
      mVlanMasters <= (others => AXI_STREAM_MASTER_INIT_C);
   end generate;

   -------------------
   -- RX Bypass Module
   -------------------      
   U_Bypass : entity work.EthMacRxBypass
      generic map (
         TPD_G          => TPD_G,
         BYP_EN_G       => BYP_EN_G,
         BYP_ETH_TYPE_G => BYP_ETH_TYPE_G) 
      port map (
         -- Clock and Reset
         ethClk      => ethClk,
         ethRst      => ethRst,
         -- Incoming data from MAC
         sAxisMaster => csumMaster,
         -- Outgoing primary data 
         mPrimMaster => bypassMaster,
         -- Outgoing bypass data 
         mBypMaster  => mBypMaster);

   -------------------
   -- RX Filter Module
   -------------------      
   U_Filter : entity work.EthMacRxFilter
      generic map (
         TPD_G     => TPD_G,
         FILT_EN_G => FILT_EN_G) 
      port map (
         -- Clock and Reset
         ethClk      => ethClk,
         ethRst      => ethRst,
         -- Incoming data from MAC
         sAxisMaster => bypassMaster,
         -- Outgoing data
         mAxisMaster => mPrimMaster,
         mAxisCtrl   => mPrimCtrl,
         -- Configuration
         dropOnPause => ethConfig.dropOnPause,
         macAddress  => ethConfig.macAddress,
         filtEnable  => ethConfig.filtEnable);   

end mapping;
