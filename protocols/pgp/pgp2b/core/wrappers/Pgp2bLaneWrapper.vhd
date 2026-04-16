-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.Pgp2bLane loopback testing
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.Pgp2bPkg.all;

entity Pgp2bLaneWrapper is
   port (
      LINK_READY    : out std_logic;
      AXIS_ACLK     : in  std_logic                     := '0';
      AXIS_ARESETN  : in  std_logic                     := '0';
      S_AXIS_TVALID : in  std_logic                     := '0';
      S_AXIS_TDATA  : in  std_logic_vector(15 downto 0) := (others => '0');
      S_AXIS_TKEEP  : in  std_logic_vector(1 downto 0)  := (others => '0');
      S_AXIS_TLAST  : in  std_logic                     := '0';
      S_AXIS_TDEST  : in  std_logic_vector(3 downto 0)  := (others => '0');
      S_AXIS_TID    : in  std_logic_vector(0 downto 0)  := (others => '0');
      S_AXIS_TUSER  : in  std_logic_vector(1 downto 0)  := (others => '0');
      S_AXIS_TREADY : out std_logic;
      M_AXIS_TVALID : out std_logic;
      M_AXIS_TDATA  : out std_logic_vector(15 downto 0);
      M_AXIS_TKEEP  : out std_logic_vector(1 downto 0);
      M_AXIS_TLAST  : out std_logic;
      M_AXIS_TDEST  : out std_logic_vector(3 downto 0);
      M_AXIS_TID    : out std_logic_vector(0 downto 0);
      M_AXIS_TUSER  : out std_logic_vector(1 downto 0);
      M_AXIS_TREADY : in  std_logic);
end entity Pgp2bLaneWrapper;

architecture rtl of Pgp2bLaneWrapper is

   constant TUSER_WIDTH_C     : positive := 2;
   constant TDEST_WIDTH_C     : positive := 4;
   constant TDATA_NUM_BYTES_C : positive := 2;

   signal axisClk : sl := '0';
   signal axisRst : sl := '0';

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal pgpTxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal pgpTxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal pgpTxMasters : AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal pgpTxSlaves  : AxiStreamSlaveArray(3 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);

   signal pgpTxIn  : Pgp2bTxInType  := PGP2B_TX_IN_INIT_C;
   signal pgpTxOut : Pgp2bTxOutType := PGP2B_TX_OUT_INIT_C;

   signal phyTxLanesOut : Pgp2bTxPhyLaneOutArray(0 to 0) := (others => PGP2B_TX_PHY_LANE_OUT_INIT_C);

   signal pgpRxIn  : Pgp2bRxInType  := PGP2B_RX_IN_INIT_C;
   signal pgpRxOut : Pgp2bRxOutType := PGP2B_RX_OUT_INIT_C;

   signal pgpRxMasters : AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal pgpRxCtrl    : AxiStreamCtrlArray(3 downto 0)   := (others => AXI_STREAM_CTRL_UNUSED_C);

   signal phyRxLanesIn  : Pgp2bRxPhyLaneInArray(0 to 0)  := (others => PGP2B_RX_PHY_LANE_IN_INIT_C);
   signal phyRxLanesOut : Pgp2bRxPhyLaneOutArray(0 to 0) := (others => PGP2B_RX_PHY_LANE_OUT_INIT_C);
   signal phyRxInit     : sl                             := '0';

   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

begin

   LINK_READY <= pgpRxOut.linkReady and pgpTxOut.linkReady;

   pgpTxMasters(0) <= pgpTxMaster;
   pgpTxSlave      <= pgpTxSlaves(0);

   phyRxLanesIn(0).data    <= phyTxLanesOut(0).data;
   phyRxLanesIn(0).dataK   <= phyTxLanesOut(0).dataK;
   phyRxLanesIn(0).dispErr <= (others => '0');
   phyRxLanesIn(0).decErr  <= (others => '0');

   ---------------------------------------------------------------------------
   -- Input shim and SOF insertion
   ---------------------------------------------------------------------------
   U_ShimLayerSlave : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "S_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => TUSER_WIDTH_C,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => TDEST_WIDTH_C,
         TDATA_NUM_BYTES => TDATA_NUM_BYTES_C)
      port map (
         S_AXIS_ACLK    => AXIS_ACLK,
         S_AXIS_ARESETN => AXIS_ARESETN,
         S_AXIS_TVALID  => S_AXIS_TVALID,
         S_AXIS_TDATA   => S_AXIS_TDATA,
         S_AXIS_TKEEP   => S_AXIS_TKEEP,
         S_AXIS_TLAST   => S_AXIS_TLAST,
         S_AXIS_TDEST   => S_AXIS_TDEST,
         S_AXIS_TID     => S_AXIS_TID,
         S_AXIS_TUSER   => S_AXIS_TUSER,
         S_AXIS_TREADY  => S_AXIS_TREADY,
         axisClk        => axisClk,
         axisRst        => axisRst,
         axisMaster     => sAxisMaster,
         axisSlave      => sAxisSlave);

   U_InsertSOF : entity surf.SsiInsertSof
      generic map (
         COMMON_CLK_G        => true,
         SLAVE_FIFO_G        => false,
         MASTER_FIFO_G       => false,
         SLAVE_AXI_CONFIG_G  => SSI_PGP2B_CONFIG_C,
         MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C)
      port map (
         sAxisClk    => axisClk,
         sAxisRst    => axisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         mAxisClk    => axisClk,
         mAxisRst    => axisRst,
         mAxisMaster => pgpTxMaster,
         mAxisSlave  => pgpTxSlave);

   ---------------------------------------------------------------------------
   -- DUT loopback path
   ---------------------------------------------------------------------------
   U_DUT : entity surf.Pgp2bLane
      generic map (
         LANE_CNT_G      => 1,
         VC_INTERLEAVE_G => 1,
         NUM_VC_EN_G     => 1)
      port map (
         pgpTxClkEn    => '1',
         pgpTxClk      => axisClk,
         pgpTxClkRst   => axisRst,
         pgpTxIn       => pgpTxIn,
         pgpTxOut      => pgpTxOut,
         pgpTxMasters  => pgpTxMasters,
         pgpTxSlaves   => pgpTxSlaves,
         phyTxLanesOut => phyTxLanesOut,
         phyTxReady    => '1',
         pgpRxClkEn    => '1',
         pgpRxClk      => axisClk,
         pgpRxClkRst   => axisRst,
         pgpRxIn       => pgpRxIn,
         pgpRxOut      => pgpRxOut,
         pgpRxMasters  => pgpRxMasters,
         pgpRxCtrl     => pgpRxCtrl,
         phyRxLanesOut => phyRxLanesOut,
         phyRxLanesIn  => phyRxLanesIn,
         phyRxReady    => '1',
         phyRxInit     => phyRxInit);

   U_RxFifo : entity surf.AxiStreamFifoV2
      generic map (
         PIPE_STAGES_G       => 0,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         MEMORY_TYPE_G       => "distributed",
         GEN_SYNC_FIFO_G     => true,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 4,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 4,
         SLAVE_AXI_CONFIG_G  => SSI_PGP2B_CONFIG_C,
         MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C)
      port map (
         sAxisClk        => axisClk,
         sAxisRst        => axisRst,
         sAxisMaster     => pgpRxMasters(0),
         sAxisSlave      => open,
         sAxisCtrl       => open,
         fifoPauseThresh => (others => '1'),
         mAxisClk        => axisClk,
         mAxisRst        => axisRst,
         mAxisMaster     => mAxisMaster,
         mAxisSlave      => mAxisSlave);

   ---------------------------------------------------------------------------
   -- Output shim
   ---------------------------------------------------------------------------
   U_ShimLayerMaster : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => TUSER_WIDTH_C,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => TDEST_WIDTH_C,
         TDATA_NUM_BYTES => TDATA_NUM_BYTES_C)
      port map (
         M_AXIS_ACLK    => AXIS_ACLK,
         M_AXIS_ARESETN => AXIS_ARESETN,
         M_AXIS_TVALID  => M_AXIS_TVALID,
         M_AXIS_TDATA   => M_AXIS_TDATA,
         M_AXIS_TKEEP   => M_AXIS_TKEEP,
         M_AXIS_TLAST   => M_AXIS_TLAST,
         M_AXIS_TDEST   => M_AXIS_TDEST,
         M_AXIS_TID     => M_AXIS_TID,
         M_AXIS_TUSER   => M_AXIS_TUSER,
         M_AXIS_TREADY  => M_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => mAxisMaster,
         axisSlave      => mAxisSlave);

end architecture rtl;
