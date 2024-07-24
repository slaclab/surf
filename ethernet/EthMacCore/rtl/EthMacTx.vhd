-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Ethernet MAC TX Wrapper
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
      -- Misc. Configurations
      BYP_EN_G        : boolean                  := false;
      -- RAM Synthesis mode
      SYNTH_MODE_G    : string                   := "inferred");
   port (
      -- Clock and Reset
      ethClkEn       : in  sl;
      ethClk         : in  sl;
      ethRst         : in  sl;
      -- Primary Interface
      sPrimMaster    : in  AxiStreamMasterType;
      sPrimSlave     : out AxiStreamSlaveType;
      -- Bypass interface
      sBypMaster     : in  AxiStreamMasterType;
      sBypSlave      : out AxiStreamSlaveType;
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
      -- Configuration and status
      phyReady       : in  sl;
      ethConfig      : in  EthMacConfigType;
      txCountEn      : out sl;
      txUnderRun     : out sl;
      txLinkNotReady : out sl);
end EthMacTx;

architecture mapping of EthMacTx is

   signal bypassMaster : AxiStreamMasterType;
   signal bypassSlave  : AxiStreamSlaveType;

   signal csumMaster : AxiStreamMasterType;
   signal csumSlave  : AxiStreamSlaveType;

   signal macObMaster : AxiStreamMasterType;
   signal macObSlave  : AxiStreamSlaveType;

begin

   -------------------
   -- TX Bypass Module
   -------------------
   U_Bypass : entity surf.EthMacTxBypass
      generic map (
         TPD_G    => TPD_G,
         BYP_EN_G => BYP_EN_G)
      port map (
         -- Clock and Reset
         ethClk      => ethClk,
         ethRst      => ethRst,
         -- Incoming primary traffic
         sPrimMaster => sPrimMaster,
         sPrimSlave  => sPrimSlave,
         -- Incoming bypass traffic
         sBypMaster  => sBypMaster,
         sBypSlave   => sBypSlave,
         -- Outgoing data to MAC
         mAxisMaster => bypassMaster,
         mAxisSlave  => bypassSlave);

   ---------------------
   -- TX Checksum Module
   ---------------------
   U_Csum : entity surf.EthMacTxCsum
      generic map (
         TPD_G          => TPD_G,
         DROP_ERR_PKT_G => DROP_ERR_PKT_G,
         JUMBO_G        => JUMBO_G)
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
         mAxisMaster => csumMaster,
         mAxisSlave  => csumSlave);

   ------------------
   -- TX Pause Module
   ------------------
   U_Pause : entity surf.EthMacTxPause
      generic map (
         TPD_G           => TPD_G,
         PAUSE_EN_G      => PAUSE_EN_G,
         PAUSE_512BITS_G => PAUSE_512BITS_G)
      port map (
         -- Clock and Reset
         ethClk       => ethClk,
         ethRst       => ethRst,
         -- Incoming data from client
         sAxisMaster  => csumMaster,
         sAxisSlave   => csumSlave,
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
         pauseTx      => pauseTx);

   -----------------------
   -- TX MAC Export Module
   -----------------------
   U_Export : entity surf.EthMacTxExport
      generic map (
         TPD_G        => TPD_G,
         PHY_TYPE_G   => PHY_TYPE_G,
         SYNTH_MODE_G => SYNTH_MODE_G)
      port map (
         -- Clock and reset
         ethClkEn       => ethClkEn,
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
         phyReady       => phyReady,
         txCountEn      => txCountEn,
         txUnderRun     => txUnderRun,
         txLinkNotReady => txLinkNotReady);

end mapping;
