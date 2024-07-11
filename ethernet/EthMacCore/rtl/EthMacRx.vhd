-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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

library surf;
use surf.AxiStreamPkg.all;
use surf.StdRtlPkg.all;
use surf.EthMacPkg.all;

entity EthMacRx is
   generic (
      -- Simulation Generics
      TPD_G          : time             := 1 ns;
      -- MAC Configurations
      PAUSE_EN_G     : boolean          := true;
      PHY_TYPE_G     : string           := "XGMII";
      JUMBO_G        : boolean          := true;
      -- Misc. Configurations
      FILT_EN_G      : boolean          := false;
      BYP_EN_G       : boolean          := false;
      BYP_ETH_TYPE_G : slv(15 downto 0) := x"0000";
      -- Internal RAM synthesis mode
      SYNTH_MODE_G   : string           := "inferred");
   port (
      -- Clock and Reset
      ethClkEn     : in  sl;
      ethClk       : in  sl;
      ethRst       : in  sl;
      -- Primary Interface
      mPrimMaster  : out AxiStreamMasterType;
      mPrimCtrl    : in  AxiStreamCtrlType;
      -- Bypass Interface
      mBypMaster   : out AxiStreamMasterType;
      mBypCtrl     : in  AxiStreamCtrlType;
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
   signal csumMaster   : AxiStreamMasterType;
   signal bypassMaster : AxiStreamMasterType;

begin

   -------------------
   -- RX Import Module
   -------------------
   U_Import : entity surf.EthMacRxImport
      generic map (
         TPD_G        => TPD_G,
         PHY_TYPE_G   => PHY_TYPE_G,
         SYNTH_MODE_G => SYNTH_MODE_G)
      port map (
         -- Clock and reset
         ethClkEn    => ethClkEn,
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
   U_Pause : entity surf.EthMacRxPause
      generic map (
         TPD_G      => TPD_G,
         PAUSE_EN_G => PAUSE_EN_G)
      port map (
         -- Clock and Reset
         ethClk       => ethClk,
         ethRst       => ethRst,
         -- Incoming data from MAC
         sAxisMaster  => macIbMaster,
         -- Outgoing data
         mAxisMaster  => pauseMaster,
         -- Pause Values
         rxPauseReq   => rxPauseReq,
         rxPauseValue => rxPauseValue);

   ---------------------
   -- RX Checksum Module
   ---------------------
   U_Csum : entity surf.EthMacRxCsum
      generic map (
         TPD_G   => TPD_G,
         JUMBO_G => JUMBO_G)
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

   -------------------
   -- RX Bypass Module
   -------------------
   U_Bypass : entity surf.EthMacRxBypass
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
   U_Filter : entity surf.EthMacRxFilter
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
