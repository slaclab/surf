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

   constant ROCE_CRC32CALC_AXI_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 32,
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant ROCE_CRC32_AXI_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 4,
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);


   signal bypassMaster : AxiStreamMasterType;
   signal bypassSlave  : AxiStreamSlaveType;

   signal csumMaster : AxiStreamMasterType;
   signal csumSlave  : AxiStreamSlaveType;

   signal csumDmMasters : AxiStreamMasterArray(1 downto 0);
   signal csumDmSlaves  : AxiStreamSlaveArray(1 downto 0);

   signal csumMastersRoCE : AxiStreamMasterArray(1 downto 0);
   signal csumSlavesRoCE  : AxiStreamSlaveArray(1 downto 0);

   signal csumMasterDly : AxiStreamMasterType;
   signal csumSlaveDly  : AxiStreamSlaveType;

   signal csumiCrcMaster : AxiStreamMasterType;
   signal csumiCrcSlave  : AxiStreamSlaveType;

   signal readyForiCrcMaster : AxiStreamMasterType;
   signal readyForiCrcSlave  : AxiStreamSlaveType;

   signal crcStreamMaster : AxiStreamMasterType;
   signal crcStreamSlave  : AxiStreamSlaveType;

   signal roceStreamMaster : AxiStreamMasterType;
   signal roceStreamSlave  : AxiStreamSlaveType;

   signal roceFixMaster : AxiStreamMasterType;
   signal roceFixSlave  : AxiStreamSlaveType;

   signal roceMasters : AxiStreamMasterArray(1 downto 0);
   signal roceSlaves  : AxiStreamSlaveArray(1 downto 0);

   signal csumMasterUdp : AxiStreamMasterType;
   signal csumSlaveUdp  : AxiStreamSlaveType;

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

   ----------------------------------------------------------------------------
   -- RoCE iCRC calculation
   ----------------------------------------------------------------------------
   U_DeMux : entity surf.AxiStreamDeMux
      generic map (
         TPD_G         => TPD_G,
         NUM_MASTERS_G => 2,
         MODE_G        => "INDEXED",
         TDEST_HIGH_G  => 1,
         TDEST_LOW_G   => 0)
      port map (
         axisClk      => ethClk,
         axisRst      => ethRst,
         sAxisMaster  => csumMaster,
         sAxisSlave   => csumSlave,
         mAxisMasters => csumDmMasters,
         mAxisSlaves  => csumDmSlaves);

   -- double the stream
   U_Repeater : entity surf.AxiStreamRepeater
      generic map (
         TPD_G         => TPD_G,
         NUM_MASTERS_G => 2)
      port map (
         axisClk      => ethClk,
         axisRst      => ethRst,
         sAxisMaster  => csumDmMasters(1),
         sAxisSlave   => csumDmSlaves(1),
         mAxisMasters => csumMastersRoCE,
         mAxisSlaves  => csumSlavesRoCE);

   U_FifoV2 : entity surf.AxiStreamFifoV2
      generic map (
         TPD_G               => TPD_G,
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 5,
         SLAVE_AXI_CONFIG_G  => EMAC_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => EMAC_AXIS_CONFIG_C)
      port map (
         sAxisClk    => ethClk,
         sAxisRst    => ethRst,
         sAxisMaster => csumMastersRoCE(1),
         sAxisSlave  => csumSlavesRoCE(1),
         mAxisClk    => ethClk,
         mAxisRst    => ethRst,
         mAxisMaster => csumMasterDly,
         mAxisSlave  => csumSlaveDly);

   U_iCrc : entity surf.EthMacPrepareForICrc
      generic map (
         TPD_G => TPD_G)
      port map (
         ethClk      => ethClk,
         ethRst      => ethRst,
         sAxisMaster => csumMastersRoCE(0),
         sAxisSlave  => csumSlavesRoCE(0),
         mAxisMaster => csumiCrcMaster,
         mAxisSlave  => csumiCrcSlave);

   U_Compact : entity surf.AxiStreamCompact
      generic map (
         TPD_G               => TPD_G,
         SLAVE_AXI_CONFIG_G  => EMAC_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => ROCE_CRC32CALC_AXI_CONFIG_C)
      port map (
         axisClk     => ethClk,
         axisRst     => ethRst,
         sAxisMaster => csumiCrcMaster,
         sAxisSlave  => csumiCrcSlave,
         mAxisMaster => readyForiCrcMaster,
         mAxisSlave  => readyForiCrcSlave);

   CrcAxiStreamWrapperSend_1 : entity surf.EthMacCrcAxiStreamWrapperSend
      port map (
         ethClk      => ethClk,
         ethRst      => ethRst,
         sAxisMaster => readyForiCrcMaster,
         sAxisSlave  => readyForiCrcSlave,
         mAxisMaster => crcStreamMaster,
         mAxisSlave  => crcStreamSlave);

   U_TrailerAppend : entity surf.AxiStreamTrailerAppend
      generic map (
         TPD_G                     => TPD_G,
         TRAILER_AXI_CONFIG_G      => ROCE_CRC32_AXI_CONFIG_C,
         MASTER_SLAVE_AXI_CONFIG_G => EMAC_AXIS_CONFIG_C)
      port map (
         axisClk            => ethClk,
         axisRst            => ethRst,
         sAxisMaster        => csumMasterDly,
         sAxisSlave         => csumSlaveDly,
         sAxisTrailerMaster => crcStreamMaster,
         sAxisTrailerSlave  => crcStreamSlave,
         mAxisMaster        => roceStreamMaster,
         mAxisSlave         => roceStreamSlave);

   U_Compact_1 : entity surf.AxiStreamCompact
      generic map (
         TPD_G               => TPD_G,
         SLAVE_AXI_CONFIG_G  => EMAC_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => EMAC_AXIS_CONFIG_C)
      port map (
         axisClk     => ethClk,
         axisRst     => ethRst,
         sAxisMaster => roceStreamMaster,
         sAxisSlave  => roceStreamSlave,
         mAxisMaster => roceFixMaster,
         mAxisSlave  => roceFixSlave);

   --------------------
   -- Packetizer FIFOs
   --------------------
   U_FifoPacketizer_Roce : entity surf.AxiStreamFifoV2
      generic map (
         TPD_G               => TPD_G,
         VALID_THOLD_G       => 0,
         GEN_SYNC_FIFO_G     => true,
         SLAVE_AXI_CONFIG_G  => EMAC_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => EMAC_AXIS_CONFIG_C)
      port map (
         sAxisClk    => ethClk,
         sAxisRst    => ethRst,
         sAxisMaster => RoceFixMaster,
         sAxisSlave  => RoceFixSlave,
         mAxisClk    => ethClk,
         mAxisRst    => ethRst,
         mAxisMaster => roceMasters(1),
         mAxisSlave  => roceSlaves(1));

   U_FifoPacketizer_Udp : entity surf.AxiStreamFifoV2
      generic map (
         TPD_G               => TPD_G,
         VALID_THOLD_G       => 0,
         GEN_SYNC_FIFO_G     => true,
         SLAVE_AXI_CONFIG_G  => EMAC_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => EMAC_AXIS_CONFIG_C)
      port map (
         sAxisClk    => ethClk,
         sAxisRst    => ethRst,
         sAxisMaster => csumDmMasters(0),
         sAxisSlave  => csumDmSlaves(0),
         mAxisClk    => ethClk,
         mAxisRst    => ethRst,
         mAxisMaster => roceMasters(0),
         mAxisSlave  => roceSlaves(0));

   -----------------------
   -- RoCE - Normal MUX
   -----------------------
   AxiStreamMux_1 : entity surf.AxiStreamMux
      generic map (
         TPD_G                => TPD_G,
         NUM_SLAVES_G         => 2,
         ILEAVE_EN_G          => true,
         ILEAVE_ON_NOTVALID_G => true,
         MODE_G               => "PASSTHROUGH",
         TID_MODE_G           => "PASSTHROUGH")
      port map (
         axisClk      => ethClk,
         axisRst      => ethRst,
         sAxisMasters => roceMasters,
         sAxisSlaves  => roceSlaves,
         mAxisMaster  => csumMasterUdp,
         mAxisSlave   => csumSlaveUdp);

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
         sAxisMaster  => csumMasterUdp,
         sAxisSlave   => csumSlaveUdp,
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
