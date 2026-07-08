-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for AxiLiteSrpV0 direct testing
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
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity AxiLiteSrpV0Wrapper is
   port (
      AXIS_ACLK      : in  std_logic;
      AXIS_ARESETN   : in  std_logic;
      S_AXI_AWADDR   : in  std_logic_vector(11 downto 0);
      S_AXI_AWPROT   : in  std_logic_vector(2 downto 0);
      S_AXI_AWVALID  : in  std_logic;
      S_AXI_AWREADY  : out std_logic;
      S_AXI_WDATA    : in  std_logic_vector(31 downto 0);
      S_AXI_WSTRB    : in  std_logic_vector(3 downto 0);
      S_AXI_WVALID   : in  std_logic;
      S_AXI_WREADY   : out std_logic;
      S_AXI_BRESP    : out std_logic_vector(1 downto 0);
      S_AXI_BVALID   : out std_logic;
      S_AXI_BREADY   : in  std_logic;
      S_AXI_ARADDR   : in  std_logic_vector(11 downto 0);
      S_AXI_ARPROT   : in  std_logic_vector(2 downto 0);
      S_AXI_ARVALID  : in  std_logic;
      S_AXI_ARREADY  : out std_logic;
      S_AXI_RDATA    : out std_logic_vector(31 downto 0);
      S_AXI_RRESP    : out std_logic_vector(1 downto 0);
      S_AXI_RVALID   : out std_logic;
      S_AXI_RREADY   : in  std_logic;
      S_AXIS_TVALID  : in  std_logic;
      S_AXIS_TDATA   : in  std_logic_vector(127 downto 0);
      S_AXIS_TKEEP   : in  std_logic_vector(15 downto 0);
      S_AXIS_TLAST   : in  std_logic;
      S_AXIS_TUSER   : in  std_logic_vector(1 downto 0);
      S_AXIS_TREADY  : out std_logic;
      M_AXIS_TVALID  : out std_logic;
      M_AXIS_TDATA   : out std_logic_vector(127 downto 0);
      M_AXIS_TKEEP   : out std_logic_vector(15 downto 0);
      M_AXIS_TLAST   : out std_logic;
      M_AXIS_TUSER   : out std_logic_vector(1 downto 0);
      M_AXIS_TREADY  : in  std_logic);
end entity AxiLiteSrpV0Wrapper;

architecture rtl of AxiLiteSrpV0Wrapper is

   constant TPD_C         : time                := 10 ns / 4;
   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(16);

   signal axisRst : sl := '0';

   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

begin

   axisRst <= not AXIS_ARESETN;

   -- AXI-Lite shim layer for cocotb-driven register requests.
   U_ShimLayerAxil : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         INTERFACENAME => "S_AXI",
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 12)
      port map (
         S_AXI_ACLK      => AXIS_ACLK,
         S_AXI_ARESETN   => AXIS_ARESETN,
         S_AXI_AWADDR    => S_AXI_AWADDR,
         S_AXI_AWPROT    => S_AXI_AWPROT,
         S_AXI_AWVALID   => S_AXI_AWVALID,
         S_AXI_AWREADY   => S_AXI_AWREADY,
         S_AXI_WDATA     => S_AXI_WDATA,
         S_AXI_WSTRB     => S_AXI_WSTRB,
         S_AXI_WVALID    => S_AXI_WVALID,
         S_AXI_WREADY    => S_AXI_WREADY,
         S_AXI_BRESP     => S_AXI_BRESP,
         S_AXI_BVALID    => S_AXI_BVALID,
         S_AXI_BREADY    => S_AXI_BREADY,
         S_AXI_ARADDR    => S_AXI_ARADDR,
         S_AXI_ARPROT    => S_AXI_ARPROT,
         S_AXI_ARVALID   => S_AXI_ARVALID,
         S_AXI_ARREADY   => S_AXI_ARREADY,
         S_AXI_RDATA     => S_AXI_RDATA,
         S_AXI_RRESP     => S_AXI_RRESP,
         S_AXI_RVALID    => S_AXI_RVALID,
         S_AXI_RREADY    => S_AXI_RREADY,
         axilClk         => open,
         axilRst         => open,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   -- AXI Stream response shim into the DUT.
   U_ShimLayerSlave : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "S_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 2,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 1,
         TDATA_NUM_BYTES => 16)
      port map (
         S_AXIS_ACLK    => AXIS_ACLK,
         S_AXIS_ARESETN => AXIS_ARESETN,
         S_AXIS_TVALID  => S_AXIS_TVALID,
         S_AXIS_TDATA   => S_AXIS_TDATA,
         S_AXIS_TSTRB   => (others => '0'),
         S_AXIS_TKEEP   => S_AXIS_TKEEP,
         S_AXIS_TLAST   => S_AXIS_TLAST,
         S_AXIS_TDEST   => "0",
         S_AXIS_TID     => "0",
         S_AXIS_TUSER   => S_AXIS_TUSER,
         S_AXIS_TREADY  => S_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => sAxisMaster,
         axisSlave      => sAxisSlave);

   -- AXI Stream request shim out to cocotb.
   U_ShimLayerMaster : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 2,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 1,
         TDATA_NUM_BYTES => 16)
      port map (
         M_AXIS_ACLK    => AXIS_ACLK,
         M_AXIS_ARESETN => AXIS_ARESETN,
         M_AXIS_TVALID  => M_AXIS_TVALID,
         M_AXIS_TDATA   => M_AXIS_TDATA,
         M_AXIS_TSTRB   => open,
         M_AXIS_TKEEP   => M_AXIS_TKEEP,
         M_AXIS_TLAST   => M_AXIS_TLAST,
         M_AXIS_TDEST   => open,
         M_AXIS_TID     => open,
         M_AXIS_TUSER   => M_AXIS_TUSER,
         M_AXIS_TREADY  => M_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => mAxisMaster,
         axisSlave      => mAxisSlave);

   -- DUT under test.
   U_DUT : entity surf.AxiLiteSrpV0
      generic map (
         TPD_G               => TPD_C,
         RESP_THOLD_G        => 1,
         SLAVE_READY_EN_G    => true,
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_PAUSE_THRESH_G => 256,
         AXI_STREAM_CONFIG_G => AXIS_CONFIG_C)
      port map (
         mAxisClk         => AXIS_ACLK,
         mAxisRst         => axisRst,
         mAxisMaster      => mAxisMaster,
         mAxisSlave       => mAxisSlave,
         sAxisClk         => AXIS_ACLK,
         sAxisRst         => axisRst,
         sAxisMaster      => sAxisMaster,
         sAxisSlave       => sAxisSlave,
         sAxisCtrl        => open,
         axilClk          => AXIS_ACLK,
         axilRst          => axisRst,
         sAxilWriteMaster => axilWriteMaster,
         sAxilWriteSlave  => axilWriteSlave,
         sAxilReadMaster  => axilReadMaster,
         sAxilReadSlave   => axilReadSlave);

end architecture rtl;
