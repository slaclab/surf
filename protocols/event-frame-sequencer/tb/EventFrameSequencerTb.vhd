-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: surf.EventFrameSequencerMux/surf.EventFrameSequencerDemux cocoTB testbed
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
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;

entity EventFrameSequencerTb is
   generic (
      -- AXI Stream Configuration
      TUSER_WIDTH_G     : positive range 8 to 8   := 8;
      TID_WIDTH_G       : positive range 8 to 8   := 8;
      TDEST_WIDTH_G     : positive range 8 to 8   := 8;
      TDATA_NUM_BYTES_G : positive range 8 to 128 := 8);
   port (
      -- Clock and Reset
      AXIS_ACLK      : in  std_logic                                          := '0';
      AXIS_ARESETN   : in  std_logic                                          := '0';
      -- IP Integrator Slave AXI Stream Interface
      S_AXIS0_TVALID : in  std_logic                                          := '0';
      S_AXIS0_TDATA  : in  std_logic_vector((8*TDATA_NUM_BYTES_G)-1 downto 0) := (others => '0');
      S_AXIS0_TSTRB  : in  std_logic_vector(TDATA_NUM_BYTES_G-1 downto 0)     := (others => '0');
      S_AXIS0_TKEEP  : in  std_logic_vector(TDATA_NUM_BYTES_G-1 downto 0)     := (others => '0');
      S_AXIS0_TLAST  : in  std_logic                                          := '0';
      S_AXIS0_TDEST  : in  std_logic_vector(TDEST_WIDTH_G-1 downto 0)         := (others => '0');
      S_AXIS0_TID    : in  std_logic_vector(TID_WIDTH_G-1 downto 0)           := (others => '0');
      S_AXIS0_TUSER  : in  std_logic_vector(TUSER_WIDTH_G-1 downto 0)         := (others => '0');
      S_AXIS0_TREADY : out std_logic;
      -- IP Integrator Slave AXI Stream Interface
      S_AXIS1_TVALID : in  std_logic                                          := '0';
      S_AXIS1_TDATA  : in  std_logic_vector((8*TDATA_NUM_BYTES_G)-1 downto 0) := (others => '0');
      S_AXIS1_TSTRB  : in  std_logic_vector(TDATA_NUM_BYTES_G-1 downto 0)     := (others => '0');
      S_AXIS1_TKEEP  : in  std_logic_vector(TDATA_NUM_BYTES_G-1 downto 0)     := (others => '0');
      S_AXIS1_TLAST  : in  std_logic                                          := '0';
      S_AXIS1_TDEST  : in  std_logic_vector(TDEST_WIDTH_G-1 downto 0)         := (others => '0');
      S_AXIS1_TID    : in  std_logic_vector(TID_WIDTH_G-1 downto 0)           := (others => '0');
      S_AXIS1_TUSER  : in  std_logic_vector(TUSER_WIDTH_G-1 downto 0)         := (others => '0');
      S_AXIS1_TREADY : out std_logic;
      -- IP Integrator Master AXI Stream Interface
      M_AXIS0_TVALID : out std_logic;
      M_AXIS0_TDATA  : out std_logic_vector((8*TDATA_NUM_BYTES_G)-1 downto 0);
      M_AXIS0_TSTRB  : out std_logic_vector(TDATA_NUM_BYTES_G-1 downto 0);
      M_AXIS0_TKEEP  : out std_logic_vector(TDATA_NUM_BYTES_G-1 downto 0);
      M_AXIS0_TLAST  : out std_logic;
      M_AXIS0_TDEST  : out std_logic_vector(TDEST_WIDTH_G-1 downto 0);
      M_AXIS0_TID    : out std_logic_vector(TID_WIDTH_G-1 downto 0);
      M_AXIS0_TUSER  : out std_logic_vector(TUSER_WIDTH_G-1 downto 0);
      M_AXIS0_TREADY : in  std_logic;
      -- IP Integrator Master AXI Stream Interface
      M_AXIS1_TVALID : out std_logic;
      M_AXIS1_TDATA  : out std_logic_vector((8*TDATA_NUM_BYTES_G)-1 downto 0);
      M_AXIS1_TSTRB  : out std_logic_vector(TDATA_NUM_BYTES_G-1 downto 0);
      M_AXIS1_TKEEP  : out std_logic_vector(TDATA_NUM_BYTES_G-1 downto 0);
      M_AXIS1_TLAST  : out std_logic;
      M_AXIS1_TDEST  : out std_logic_vector(TDEST_WIDTH_G-1 downto 0);
      M_AXIS1_TID    : out std_logic_vector(TID_WIDTH_G-1 downto 0);
      M_AXIS1_TUSER  : out std_logic_vector(TUSER_WIDTH_G-1 downto 0);
      M_AXIS1_TREADY : in  std_logic;
      -- AXI-Lite Interface
      S_AXIL_AWADDR   : in  std_logic_vector(31 downto 0);
      S_AXIL_AWPROT   : in  std_logic_vector(2 downto 0);
      S_AXIL_AWVALID  : in  std_logic;
      S_AXIL_AWREADY  : out std_logic;
      S_AXIL_WDATA    : in  std_logic_vector(31 downto 0);
      S_AXIL_WSTRB    : in  std_logic_vector(3 downto 0);
      S_AXIL_WVALID   : in  std_logic;
      S_AXIL_WREADY   : out std_logic;
      S_AXIL_BRESP    : out std_logic_vector(1 downto 0);
      S_AXIL_BVALID   : out std_logic;
      S_AXIL_BREADY   : in  std_logic;
      S_AXIL_ARADDR   : in  std_logic_vector(31 downto 0);
      S_AXIL_ARPROT   : in  std_logic_vector(2 downto 0);
      S_AXIL_ARVALID  : in  std_logic;
      S_AXIL_ARREADY  : out std_logic;
      S_AXIL_RDATA    : out std_logic_vector(31 downto 0);
      S_AXIL_RRESP    : out std_logic_vector(1 downto 0);
      S_AXIL_RVALID   : out std_logic;
      S_AXIL_RREADY   : in  std_logic);
end EventFrameSequencerTb;

architecture mapping of EventFrameSequencerTb is

   constant TPD_C : time := 3 ns;

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => true,
      TDATA_BYTES_C => TDATA_NUM_BYTES_G,
      TDEST_BITS_C  => TDEST_WIDTH_G,
      TID_BITS_C    => TID_WIDTH_G,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => TUSER_WIDTH_G,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant AXIL_CONFIG_C : AxiLiteCrossbarMasterConfigArray(1 downto 0) := genAxiLiteConfig(2, x"0000_0000", 20, 16);

   signal axilReadMaster  : AxiLiteReadMasterType;
   signal axilReadSlave   : AxiLiteReadSlaveType;
   signal axilWriteMaster : AxiLiteWriteMasterType;
   signal axilWriteSlave  : AxiLiteWriteSlaveType;

   signal axilReadMasters  : AxiLiteReadMasterArray(1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(1 downto 0);
   signal axilWriteMasters : AxiLiteWriteMasterArray(1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(1 downto 0);

   signal axisClk : sl := '0';
   signal axisRst : sl := '0';

   signal sAxisMasters : AxiStreamMasterArray(1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal sAxisSlaves  : AxiStreamSlaveArray(1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);

   signal axisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal axisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal mAxisMasters : AxiStreamMasterArray(1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal mAxisSlaves  : AxiStreamSlaveArray(1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);

begin

   ---------------------------------------------------------------------------
   -- Adding Shim Layers for translating between cocoTB and local record types
   ---------------------------------------------------------------------------
   U_ShimLayerSlave_0 : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "S_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 1,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => TUSER_WIDTH_G,
         TID_WIDTH       => TID_WIDTH_G,
         TDEST_WIDTH     => TDEST_WIDTH_G,
         TDATA_NUM_BYTES => TDATA_NUM_BYTES_G)
      port map (
         -- IP Integrator AXI Stream Interface
         S_AXIS_ACLK    => AXIS_ACLK,
         S_AXIS_ARESETN => AXIS_ARESETN,
         S_AXIS_TVALID  => S_AXIS0_TVALID,
         S_AXIS_TDATA   => S_AXIS0_TDATA,
         S_AXIS_TSTRB   => S_AXIS0_TSTRB,
         S_AXIS_TKEEP   => S_AXIS0_TKEEP,
         S_AXIS_TLAST   => S_AXIS0_TLAST,
         S_AXIS_TDEST   => S_AXIS0_TDEST,
         S_AXIS_TID     => S_AXIS0_TID,
         S_AXIS_TUSER   => S_AXIS0_TUSER,
         S_AXIS_TREADY  => S_AXIS0_TREADY,
         -- SURF AXI Stream Interface
         axisClk        => axisClk,
         axisRst        => axisRst,
         axisMaster     => sAxisMasters(0),
         axisSlave      => sAxisSlaves(0));

   U_ShimLayerSlave_1 : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "S_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 1,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => TUSER_WIDTH_G,
         TID_WIDTH       => TID_WIDTH_G,
         TDEST_WIDTH     => TDEST_WIDTH_G,
         TDATA_NUM_BYTES => TDATA_NUM_BYTES_G)
      port map (
         -- IP Integrator AXI Stream Interface
         S_AXIS_ACLK    => AXIS_ACLK,
         S_AXIS_ARESETN => AXIS_ARESETN,
         S_AXIS_TVALID  => S_AXIS1_TVALID,
         S_AXIS_TDATA   => S_AXIS1_TDATA,
         S_AXIS_TSTRB   => S_AXIS1_TSTRB,
         S_AXIS_TKEEP   => S_AXIS1_TKEEP,
         S_AXIS_TLAST   => S_AXIS1_TLAST,
         S_AXIS_TDEST   => S_AXIS1_TDEST,
         S_AXIS_TID     => S_AXIS1_TID,
         S_AXIS_TUSER   => S_AXIS1_TUSER,
         S_AXIS_TREADY  => S_AXIS1_TREADY,
         -- SURF AXI Stream Interface
         axisClk        => open,
         axisRst        => open,
         axisMaster     => sAxisMasters(1),
         axisSlave      => sAxisSlaves(1));

   U_ShimLayerMaster_0 : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 1,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => TUSER_WIDTH_G,
         TID_WIDTH       => TID_WIDTH_G,
         TDEST_WIDTH     => TDEST_WIDTH_G,
         TDATA_NUM_BYTES => TDATA_NUM_BYTES_G)
      port map (
         -- IP Integrator AXI Stream Interface
         M_AXIS_ACLK    => AXIS_ACLK,
         M_AXIS_ARESETN => AXIS_ARESETN,
         M_AXIS_TVALID  => M_AXIS0_TVALID,
         M_AXIS_TDATA   => M_AXIS0_TDATA,
         M_AXIS_TSTRB   => M_AXIS0_TSTRB,
         M_AXIS_TKEEP   => M_AXIS0_TKEEP,
         M_AXIS_TLAST   => M_AXIS0_TLAST,
         M_AXIS_TDEST   => M_AXIS0_TDEST,
         M_AXIS_TID     => M_AXIS0_TID,
         M_AXIS_TUSER   => M_AXIS0_TUSER,
         M_AXIS_TREADY  => M_AXIS0_TREADY,
         -- SURF AXI Stream Interface
         axisClk        => open,
         axisRst        => open,
         axisMaster     => mAxisMasters(0),
         axisSlave      => mAxisSlaves(0));

   U_ShimLayerMaster_1 : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 1,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => TUSER_WIDTH_G,
         TID_WIDTH       => TID_WIDTH_G,
         TDEST_WIDTH     => TDEST_WIDTH_G,
         TDATA_NUM_BYTES => TDATA_NUM_BYTES_G)
      port map (
         -- IP Integrator AXI Stream Interface
         M_AXIS_ACLK    => AXIS_ACLK,
         M_AXIS_ARESETN => AXIS_ARESETN,
         M_AXIS_TVALID  => M_AXIS1_TVALID,
         M_AXIS_TDATA   => M_AXIS1_TDATA,
         M_AXIS_TSTRB   => M_AXIS1_TSTRB,
         M_AXIS_TKEEP   => M_AXIS1_TKEEP,
         M_AXIS_TLAST   => M_AXIS1_TLAST,
         M_AXIS_TDEST   => M_AXIS1_TDEST,
         M_AXIS_TID     => M_AXIS1_TID,
         M_AXIS_TUSER   => M_AXIS1_TUSER,
         M_AXIS_TREADY  => M_AXIS1_TREADY,
         -- SURF AXI Stream Interface
         axisClk        => open,
         axisRst        => open,
         axisMaster     => mAxisMasters(1),
         axisSlave      => mAxisSlaves(1));

   U_ShimLayer : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         FREQ_HZ       => 100000000,
         ADDR_WIDTH    => 32)
      port map (
         -- IP Integrator AXI-Lite Interface
         S_AXI_ACLK      => AXIS_ACLK,
         S_AXI_ARESETN   => AXIS_ARESETN,
         S_AXI_AWADDR    => S_AXIL_AWADDR,
         S_AXI_AWPROT    => S_AXIL_AWPROT,
         S_AXI_AWVALID   => S_AXIL_AWVALID,
         S_AXI_AWREADY   => S_AXIL_AWREADY,
         S_AXI_WDATA     => S_AXIL_WDATA,
         S_AXI_WSTRB     => S_AXIL_WSTRB,
         S_AXI_WVALID    => S_AXIL_WVALID,
         S_AXI_WREADY    => S_AXIL_WREADY,
         S_AXI_BRESP     => S_AXIL_BRESP,
         S_AXI_BVALID    => S_AXIL_BVALID,
         S_AXI_BREADY    => S_AXIL_BREADY,
         S_AXI_ARADDR    => S_AXIL_ARADDR,
         S_AXI_ARPROT    => S_AXIL_ARPROT,
         S_AXI_ARVALID   => S_AXIL_ARVALID,
         S_AXI_ARREADY   => S_AXIL_ARREADY,
         S_AXI_RDATA     => S_AXIL_RDATA,
         S_AXI_RRESP     => S_AXIL_RRESP,
         S_AXI_RVALID    => S_AXIL_RVALID,
         S_AXI_RREADY    => S_AXIL_RREADY,
         -- SURF AXI-Lite Interface
         axilClk         => open,
         axilRst         => open,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   U_AXIL_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_C,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => 2,
         MASTERS_CONFIG_G   => AXIL_CONFIG_C)
      port map (
         axiClk              => axisClk,
         axiClkRst           => axisRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);

   ---------------------------------------------------------------------------
   -- Design Under Testing (DUT) Modules
   ---------------------------------------------------------------------------

   -- Module used on the front end board for sequencing the frames to back end
   U_DUT_MUX : entity surf.EventFrameSequencerMux
      generic map (
         TPD_G          => TPD_C,
         NUM_SLAVES_G   => 2,
         MODE_G         => "ROUTED",
         TDEST_ROUTES_G => (
            0           => "0000000-",   -- Trig on 0x1, Event on 0x0
            1           => "00000010"),  -- Map PGP[tap] to TDEST 0x2
         TRANS_TDEST_G  => X"00",
         AXIS_CONFIG_G  => AXIS_CONFIG_C)
      port map (
         -- Clock and Reset
         axisClk         => axisClk,
         axisRst         => axisRst,
         -- AXI-Lite Interface (axisClk domain)
         axilReadMaster  => axilReadMasters(0),
         axilReadSlave   => axilReadSlaves(0),
         axilWriteMaster => axilWriteMasters(0),
         axilWriteSlave  => axilWriteSlaves(0),
         -- AXIS Interfaces
         sAxisMasters    => sAxisMasters,
         sAxisSlaves     => sAxisSlaves,
         mAxisMaster     => axisMaster,
         mAxisSlave      => axisSlave);

   -- Module used on the back end board (e.g. FPGA PCIe) for decoding
   U_DUT_DEMUX : entity surf.EventFrameSequencerDemux
      generic map (
         TPD_G         => TPD_C,
         NUM_MASTERS_G => 2,
         AXIS_CONFIG_G => AXIS_CONFIG_C)
      port map (
         -- Clock and Reset
         axisClk         => axisClk,
         axisRst         => axisRst,
         -- AXI-Lite Interface
         axilReadMaster  => axilReadMasters(1),
         axilReadSlave   => axilReadSlaves(1),
         axilWriteMaster => axilWriteMasters(1),
         axilWriteSlave  => axilWriteSlaves(1),
         -- AXIS Interfaces
         sAxisMaster     => axisMaster,
         sAxisSlave      => axisSlave,
         mAxisMasters    => mAxisMasters,
         mAxisSlaves     => mAxisSlaves);

end mapping;
