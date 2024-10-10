-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: RoCEv2 Protocol Wrapper for TX path
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

entity EthMacTxRoCEv2 is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      ethClk        : in  sl;
      ethRst        : in  sl;
      -- Checksum Interface
      obCsumMaster  : in  AxiStreamMasterType;
      obCsumSlave   : out AxiStreamSlaveType;
      -- Pause Interface
      ibPauseMaster : out AxiStreamMasterType;
      ibPauseSlave  : in  AxiStreamSlaveType);
end EthMacTxRoCEv2;

architecture mapping of EthMacTxRoCEv2 is

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

begin

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
         sAxisMaster  => obCsumMaster,
         sAxisSlave   => obCsumSlave,
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
         mAxisMaster  => ibPauseMaster,
         mAxisSlave   => ibPauseSlave);

end mapping;
