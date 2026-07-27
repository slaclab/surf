-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: RoCEv2 Protocol Wrapper for RX path
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

entity EthMacRxRoCEv2 is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      JUMBO_G        : boolean := true);
   port (
      -- Clock and Reset
      ethClk         : in  sl;
      ethRst         : in  sl;
      -- Checksum Interface
      obCsumMaster   : in  AxiStreamMasterType;
      -- Bypass Interface
      ibBypassMaster : out AxiStreamMasterType);
end EthMacRxRoCEv2;

architecture mapping of EthMacRxRoCEv2 is

   -- EthMacRxCheckICrc is store-and-forward: it releases no beat of a packet
   -- until the CRC-result beat arrives, which the CRC engine only emits after
   -- consuming the packet's LAST beat.  The delay FIFO must therefore hold a
   -- full max-size frame; the upstream MAC RX path has no flow control (the
   -- DeMux sAxisSlave is left open), so a full FIFO silently loses beats.
   -- 16 bytes/beat: jumbo (9000B) needs ~564 beats, standard (1500B) ~95.
   constant DLY_FIFO_ADDR_WIDTH_C : positive := ite(JUMBO_G, 10, 8);
   -- The packetizer FIFO holds tValid until a frame completes (VALID_THOLD=0),
   -- so its occupancy cannot drop while a frame is still streaming in.  If
   -- pause asserts below one full frame, AxiStreamFlush stalls mid-frame and
   -- the pipeline deadlocks: pause must stay above the max frame beat count.
   constant PAUSE_THRESH_C        : positive := ite(JUMBO_G, 896, 192);

   signal csumDmMasters : AxiStreamMasterArray(1 downto 0);
   signal csumDmSlaves  : AxiStreamSlaveArray(1 downto 0);

   signal csumMastersRoCE : AxiStreamMasterArray(1 downto 0);
   signal csumSlavesRoCE  : AxiStreamSlaveArray(1 downto 0);

   signal csumMasterDly : AxiStreamMasterType;
   signal csumSlaveDly  : AxiStreamSlaveType;

   signal axisMasterNoTrail : AxiStreamMasterType;
   signal axisSlaveNoTrail  : AxiStreamSlaveType;

   signal csumiCrcMaster : AxiStreamMasterType;
   signal csumiCrcSlave  : AxiStreamSlaveType;

   signal crcStreamMaster : AxiStreamMasterType;
   signal crcStreamSlave  : AxiStreamSlaveType;

   signal roceCheckedMaster : AxiStreamMasterType;
   signal roceCheckedSlave  : AxiStreamSlaveType;

   signal roceMaster : AxiStreamMasterType;
   signal roceCtrl   : AxiStreamCtrlType;

   signal roceMasters : AxiStreamMasterArray(1 downto 0);
   signal roceSlaves  : AxiStreamSlaveArray(1 downto 0);

begin

   ----------------------------------------------------------------------------
   -- RoCE iCRC check
   ----------------------------------------------------------------------------
   U_DeMux : entity surf.AxiStreamDeMux
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         NUM_MASTERS_G  => 2,
         MODE_G         => "INDEXED",
         TDEST_HIGH_G   => 1,
         TDEST_LOW_G    => 0)
      port map (
         axisClk      => ethClk,
         axisRst      => ethRst,
         sAxisMaster  => obCsumMaster,
         sAxisSlave   => open,
         mAxisMasters => csumDmMasters,
         mAxisSlaves  => csumDmSlaves);

   -- double the stream
   U_Repeater : entity surf.AxiStreamRepeater
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         NUM_MASTERS_G  => 2)
      port map (
         axisClk      => ethClk,
         axisRst      => ethRst,
         sAxisMaster  => csumDmMasters(1),
         sAxisSlave   => csumDmSlaves(1),
         mAxisMasters => csumMastersRoCE,
         mAxisSlaves  => csumSlavesRoCE);

   -- FIFO the second stream to wait for iCrc (must hold a full frame, see
   -- DLY_FIFO_ADDR_WIDTH_C above)
   U_FifoV2 : entity surf.AxiStreamFifoV2
      generic map (
         TPD_G               => TPD_G,
         RST_POLARITY_G      => RST_POLARITY_G,
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => DLY_FIFO_ADDR_WIDTH_C,
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

   U_TrailerRemove : entity surf.AxiStreamTrailerRemove
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         AXI_CONFIG_G   => EMAC_AXIS_CONFIG_C)
      port map (
         axisClk     => ethClk,
         axisRst     => ethRst,
         sAxisMaster => csumMasterDly,
         sAxisSlave  => csumSlaveDly,
         mAxisMaster => axisMasterNoTrail,
         mAxisSlave  => axisSlaveNoTrail);

   U_iCrc : entity surf.EthMacPrepareForICrc
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G)
      port map (
         ethClk      => ethClk,
         ethRst      => ethRst,
         sAxisMaster => csumMastersRoCE(0),
         sAxisSlave  => csumSlavesRoCE(0),
         mAxisMaster => csumiCrcMaster,
         mAxisSlave  => csumiCrcSlave);

   U_iCrcIn : entity surf.EthMacCrcAxiStream
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         CRC_MODE_G     => "RECV")
      port map (
         ethClk      => ethClk,
         ethRst      => ethRst,
         sAxisMaster => csumiCrcMaster,
         sAxisSlave  => csumiCrcSlave,
         mAxisMaster => crcStreamMaster,
         mAxisSlave  => crcStreamSlave);

   U_CheckICrc : entity surf.EthMacRxCheckICrc
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G)
      port map (
         ethClk              => ethClk,
         ethRst              => ethRst,
         sAxisMaster         => axisMasterNoTrail,
         sAxisSlave          => axisSlaveNoTrail,
         sAxisCrcCheckMaster => crcStreamMaster,
         sAxisCrcCheckSlave  => crcStreamSlave,
         mAxisMaster         => roceCheckedMaster,
         mAxisSlave          => roceCheckedSlave);

   U_Flush : entity surf.AxiStreamFlush
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         AXIS_CONFIG_G  => EMAC_AXIS_CONFIG_C,
         SSI_EN_G       => true)
      port map (
         axisClk     => ethClk,
         axisRst     => ethRst,
         flushEn     => roceCheckedMaster.tUser(2),
         sAxisMaster => roceCheckedMaster,
         sAxisSlave  => roceCheckedSlave,
         mAxisMaster => roceMaster,
         mAxisCtrl   => roceCtrl);

   --------------------
   -- Packetizer FIFOs
   --------------------
   U_FifoPacketizer_Roce : entity surf.AxiStreamFifoV2
      generic map (
         TPD_G               => TPD_G,
         RST_POLARITY_G      => RST_POLARITY_G,
         VALID_THOLD_G       => 0,
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => DLY_FIFO_ADDR_WIDTH_C,
         FIFO_PAUSE_THRESH_G => PAUSE_THRESH_C,
         SLAVE_AXI_CONFIG_G  => EMAC_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => EMAC_AXIS_CONFIG_C)
      port map (
         sAxisClk    => ethClk,
         sAxisRst    => ethRst,
         sAxisMaster => RoceMaster,
         sAxisCtrl   => RoceCtrl,
         mAxisClk    => ethClk,
         mAxisRst    => ethRst,
         mAxisMaster => RoceMasters(1),
         mAxisSlave  => RoceSlaves(1));

   U_FifoPacketizer_Udp : entity surf.AxiStreamFifoV2
      generic map (
         TPD_G               => TPD_G,
         RST_POLARITY_G      => RST_POLARITY_G,
         VALID_THOLD_G       => 0,
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => DLY_FIFO_ADDR_WIDTH_C,
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
         RST_POLARITY_G       => RST_POLARITY_G,
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
         mAxisMaster  => ibBypassMaster,
         mAxisSlave   => AXI_STREAM_SLAVE_FORCE_C);

end mapping;
