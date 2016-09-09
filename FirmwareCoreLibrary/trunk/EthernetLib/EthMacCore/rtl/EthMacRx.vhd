-------------------------------------------------------------------------------
-- Title      : 1GbE/10GbE Ethernet MAC
-------------------------------------------------------------------------------
-- File       : EthMacRx.vhd
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

entity EthMacRx is
   generic (
      -- Simulation Generics
      TPD_G          : time                  := 1 ns;
      -- MAC Configurations
      PAUSE_EN_G     : boolean               := true;
      GMII_EN_G      : boolean               := false;  -- False = XGMII Interface only, True = GMII Interface only
      -- Non-VLAN Configurations
      FILT_EN_G      : boolean               := false;
      BYP_EN_G       : boolean               := false;
      BYP_ETH_TYPE_G : slv(15 downto 0)      := x"0000";
      SHIFT_EN_G     : boolean               := false;
      JUMBO_G        : boolean               := false;
      -- VLAN Configurations
      VLAN_EN_G      : boolean               := false;
      VLAN_CNT_G     : positive range 1 to 8 := 1;
      VLAN_JUMBO_G   : boolean               := false);   
   port (
      -- Clock and Reset
      ethClk       : in  sl;
      ethRst       : in  sl;
      -- Primary Interface
      mPrimMaster  : out AxiStreamMasterType;
      mPrimCtrl    : in  AxiStreamCtrlType;
      -- Bypass Interface
      mBypMaster   : out AxiStreamMasterType;
      mBypCtrl     : in  AxiStreamCtrlType                         := AXI_STREAM_CTRL_UNUSED_C;
      -- VLAN Interfaces
      mVlanMaster  : out AxiStreamMasterArray(VLAN_CNT_G-1 downto 0);
      mVlanCtrl    : in  AxiStreamCtrlArray(VLAN_CNT_G-1 downto 0) := (others => AXI_STREAM_CTRL_UNUSED_C);
      -- XGMII PHY Interface
      phyRxd       : in  slv(63 downto 0);
      phyRxc       : in  slv(7 downto 0);
      -- GMII PHY Interface
      gmiiRxDv     : in  sl                                        := '0';
      gmiiRxEr     : in  sl                                        := '0';
      gmiiRxd      : in  slv(7 downto 0)                           := x"00";
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
   signal pauseMasters : AxiStreamMasterArray(VLAN_CNT_G-1 downto 0);
   signal toeMaster    : AxiStreamMasterType;
   signal bypassMaster : AxiStreamMasterType;
   signal filterMaster : AxiStreamMasterType;

begin

   -------------------
   -- RX Import Module
   -------------------
   U_Import : entity work.EthMacRxImport
      generic map (
         TPD_G     => TPD_G,
         GMII_EN_G => GMII_EN_G)
      port map (
         -- Clock and reset
         ethClk      => ethClk,
         ethRst      => ethRst,
         -- AXIS Interface   
         macIbMaster => macIbMaster,
         -- XGMII PHY Interface
         phyRxd      => phyRxd,
         phyRxc      => phyRxc,
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
         TPD_G      => TPD_G,
         PAUSE_EN_G => PAUSE_EN_G,
         VLAN_EN_G  => VLAN_EN_G,
         VLAN_CNT_G => VLAN_CNT_G)         
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

   -------------------------
   -- RX Non-VLAN TOE Module
   -------------------------
   U_Toe : entity work.EthMacRxToe
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
         mAxisMaster => toeMaster);

   ---------------------
   -- RX VLAN TOE Module
   ---------------------         
   GEN_VLAN : if (VLAN_EN_G = true) generate
      GEN_VEC :
      for i in (VLAN_CNT_G-1) downto 0 generate
         U_Toe : entity work.EthMacRxToe
            generic map (
               TPD_G   => TPD_G,
               JUMBO_G => VLAN_JUMBO_G,
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
               mAxisMaster => mVlanMaster(i));
      end generate GEN_VEC;
   end generate;

   BYPASS_VLAN : if (VLAN_EN_G = false) generate
      -- Terminate Unused buses
      mVlanMaster <= (others => AXI_STREAM_MASTER_INIT_C);
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
         sAxisMaster => toeMaster,
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
         mAxisMaster => filterMaster,
         mAxisCtrl   => mPrimCtrl,
         -- Configuration
         dropOnPause => ethConfig.dropOnPause,
         macAddress  => ethConfig.macAddress,
         filtEnable  => ethConfig.filtEnable);   

   ------------------
   -- RX Shift Module
   ------------------   
   U_Shift : entity work.EthMacRxShift
      generic map (
         TPD_G      => TPD_G,
         SHIFT_EN_G => SHIFT_EN_G) 
      port map (
         -- Clock and Reset
         ethClk      => ethClk,
         ethRst      => ethRst,
         -- AXIS Interface
         sAxisMaster => filterMaster,
         mAxisMaster => mPrimMaster,
         -- Configuration
         rxShift     => ethConfig.rxShift);   

end mapping;
