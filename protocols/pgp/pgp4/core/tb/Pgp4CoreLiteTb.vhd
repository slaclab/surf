-------------------------------------------------------------------------------
-- Title      : PGPv4: https://confluence.slac.stanford.edu/x/1dzgEQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Pgp4Lite Testbed
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.Pgp4Pkg.all;

entity Pgp4CoreLiteTb is
   port (
      LINK_READY    : out std_logic;
      -- Clock and Reset
      AXIS_ACLK     : in  std_logic                     := '0';
      AXIS_ARESETN  : in  std_logic                     := '0';
      -- IP Integrator Slave AXI Stream Interface
      S_AXIS_TVALID : in  std_logic                     := '0';
      S_AXIS_TDATA  : in  std_logic_vector(63 downto 0) := (others => '0');
      S_AXIS_TSTRB  : in  std_logic_vector(7 downto 0)  := (others => '0');
      S_AXIS_TKEEP  : in  std_logic_vector(7 downto 0)  := (others => '0');
      S_AXIS_TLAST  : in  std_logic                     := '0';
      S_AXIS_TDEST  : in  std_logic_vector(0 downto 0)  := (others => '0');
      S_AXIS_TID    : in  std_logic_vector(0 downto 0)  := (others => '0');
      S_AXIS_TUSER  : in  std_logic_vector(0 downto 0)  := (others => '0');
      S_AXIS_TREADY : out std_logic;
      -- IP Integrator Master AXI Stream Interface
      M_AXIS_TVALID : out std_logic;
      M_AXIS_TDATA  : out std_logic_vector(63 downto 0);
      M_AXIS_TSTRB  : out std_logic_vector(7 downto 0);
      M_AXIS_TKEEP  : out std_logic_vector(7 downto 0);
      M_AXIS_TLAST  : out std_logic;
      M_AXIS_TDEST  : out std_logic_vector(0 downto 0);
      M_AXIS_TID    : out std_logic_vector(0 downto 0);
      M_AXIS_TUSER  : out std_logic_vector(0 downto 0);
      M_AXIS_TREADY : in  std_logic);
end entity Pgp4CoreLiteTb;

architecture testbed of Pgp4CoreLiteTb is

   constant TUSER_WIDTH_C     : positive := 1;
   constant TID_WIDTH_C       : positive := 1;
   constant TDEST_WIDTH_C     : positive := 1;
   constant TDATA_NUM_BYTES_C : positive := 8;

   signal axisClk : sl := '0';
   signal axisRst : sl := '0';

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal pgpTxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal pgpTxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal pgpTxIn  : Pgp4TxInType := PGP4_TX_IN_INIT_C;
   signal pgpTxOut : Pgp4TxOutType;

   signal phyValid  : sl               := '0';
   signal phyData   : slv(63 downto 0) := (others => '0');
   signal phyHeader : slv(1 downto 0)  := (others => '0');

   signal pgpRxIn  : Pgp4RxInType := PGP4_RX_IN_INIT_C;
   signal pgpRxOut : Pgp4RxOutType;

   signal pgpRxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal pgpRxCtrl   : AxiStreamCtrlType   := AXI_STREAM_CTRL_INIT_C;

   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

begin

   LINK_READY <= pgpRxOut.linkReady and pgpTxOut.linkReady;

   U_ShimLayerSlave : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "S_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 1,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => TUSER_WIDTH_C,
         TID_WIDTH       => TID_WIDTH_C,
         TDEST_WIDTH     => TDEST_WIDTH_C,
         TDATA_NUM_BYTES => TDATA_NUM_BYTES_C)
      port map (
         -- IP Integrator AXI Stream Interface
         S_AXIS_ACLK    => AXIS_ACLK,
         S_AXIS_ARESETN => AXIS_ARESETN,
         S_AXIS_TVALID  => S_AXIS_TVALID,
         S_AXIS_TDATA   => S_AXIS_TDATA,
         S_AXIS_TSTRB   => S_AXIS_TSTRB,
         S_AXIS_TKEEP   => S_AXIS_TKEEP,
         S_AXIS_TLAST   => S_AXIS_TLAST,
         S_AXIS_TDEST   => S_AXIS_TDEST,
         S_AXIS_TID     => S_AXIS_TID,
         S_AXIS_TUSER   => S_AXIS_TUSER,
         S_AXIS_TREADY  => S_AXIS_TREADY,
         -- SURF AXI Stream Interface
         axisClk        => axisClk,
         axisRst        => axisRst,
         axisMaster     => sAxisMaster,
         axisSlave      => sAxisSlave);

   U_InsertSOF : entity surf.SsiInsertSof
      generic map (
         COMMON_CLK_G        => true,
         SLAVE_FIFO_G        => false,
         MASTER_FIFO_G       => false,
         SLAVE_AXI_CONFIG_G  => PGP4_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => PGP4_AXIS_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => axisClk,
         sAxisRst    => axisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         mAxisClk    => axisClk,
         mAxisRst    => axisRst,
         mAxisMaster => pgpTxMaster,
         mAxisSlave  => pgpTxSlave);

   U_DUT : entity surf.Pgp4CoreLite
      generic map (
         NUM_VC_G       => 1,           -- Only 1 VC per PGPv4 link
         SKIP_EN_G      => false,  -- No skips (assumes clock source synchronous system)
         FLOW_CTRL_EN_G => true)
      port map (
         -- Tx User interface
         pgpTxClk        => axisClk,
         pgpTxRst        => axisRst,
         pgpTxIn         => pgpTxIn,
         pgpTxOut        => pgpTxOut,
         pgpTxMasters(0) => pgpTxMaster,
         pgpTxSlaves(0)  => pgpTxSlave,
         -- Tx PHY interface
         phyTxActive     => '1',
         phyTxReady      => '1',
         phyTxValid      => phyValid,
         phyTxData       => phyData,
         phyTxHeader     => phyHeader,
         -- Rx User interface
         pgpRxClk        => axisClk,
         pgpRxRst        => axisRst,
         pgpRxIn         => pgpRxIn,
         pgpRxOut        => pgpRxOut,
         pgpRxMasters(0) => pgpRxMaster,
         pgpRxCtrl(0)    => pgpRxCtrl,
         -- Rx PHY interface
         phyRxClk        => axisClk,
         phyRxRst        => axisRst,
         phyRxActive     => '1',
         phyRxStartSeq   => '0',
         phyRxValid      => phyValid,
         phyRxData       => phyData,
         phyRxHeader     => phyHeader);

   U_RxFifo : entity surf.PgpRxVcFifo
      generic map (
         INT_PIPE_STAGES_G   => 0,
         PIPE_STAGES_G       => 0,
         SYNTH_MODE_G        => "inferred",
         MEMORY_TYPE_G       => "distributed",
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 4,      -- 2^4 = 16 deep buffer
         FIFO_PAUSE_THRESH_G => 4,      -- 4 sample deep water mark
         PHY_AXI_CONFIG_G    => PGP4_AXIS_CONFIG_C,
         APP_AXI_CONFIG_G    => PGP4_AXIS_CONFIG_C)
      port map (
         -- PGP Interface (pgpClk domain)
         pgpClk      => axisClk,
         pgpRst      => axisRst,
         rxlinkReady => pgpRxOut.linkReady,
         pgpRxMaster => pgpRxMaster,
         pgpRxCtrl   => pgpRxCtrl,
         -- AXIS Interface (axisClk domain)
         axisClk     => axisClk,
         axisRst     => axisRst,
         axisMaster  => mAxisMaster,
         axisSlave   => mAxisSlave);

   U_ShimLayerMaster : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 1,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => TUSER_WIDTH_C,
         TID_WIDTH       => TID_WIDTH_C,
         TDEST_WIDTH     => TDEST_WIDTH_C,
         TDATA_NUM_BYTES => TDATA_NUM_BYTES_C)
      port map (
         -- IP Integrator AXI Stream Interface
         M_AXIS_ACLK    => AXIS_ACLK,
         M_AXIS_ARESETN => AXIS_ARESETN,
         M_AXIS_TVALID  => M_AXIS_TVALID,
         M_AXIS_TDATA   => M_AXIS_TDATA,
         M_AXIS_TSTRB   => M_AXIS_TSTRB,
         M_AXIS_TKEEP   => M_AXIS_TKEEP,
         M_AXIS_TLAST   => M_AXIS_TLAST,
         M_AXIS_TDEST   => M_AXIS_TDEST,
         M_AXIS_TID     => M_AXIS_TID,
         M_AXIS_TUSER   => M_AXIS_TUSER,
         M_AXIS_TREADY  => M_AXIS_TREADY,
         -- SURF AXI Stream Interface
         axisClk        => open,
         axisRst        => open,
         axisMaster     => mAxisMaster,
         axisSlave      => mAxisSlave);

end testbed;
