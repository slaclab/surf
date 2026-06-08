-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for SrpV0AxiLite direct testing
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

entity SrpV0AxiLiteWrapper is
   generic (
      EN_32BIT_ADDR_G : boolean := false);
   port (
      AXIS_ACLK      : in  std_logic;
      AXIS_ARESETN   : in  std_logic;
      S_AXIS_TVALID  : in  std_logic;
      S_AXIS_TDATA   : in  std_logic_vector(31 downto 0);
      S_AXIS_TKEEP   : in  std_logic_vector(3 downto 0);
      S_AXIS_TLAST   : in  std_logic;
      S_AXIS_TUSER   : in  std_logic_vector(1 downto 0);
      S_AXIS_TREADY  : out std_logic;
      M_AXIS_TVALID  : out std_logic;
      M_AXIS_TDATA   : out std_logic_vector(31 downto 0);
      M_AXIS_TKEEP   : out std_logic_vector(3 downto 0);
      M_AXIS_TLAST   : out std_logic;
      M_AXIS_TUSER   : out std_logic_vector(1 downto 0);
      M_AXIS_TREADY  : in  std_logic;
      M_AXIL_AWADDR  : out std_logic_vector(31 downto 0);
      M_AXIL_AWPROT  : out std_logic_vector(2 downto 0);
      M_AXIL_AWVALID : out std_logic;
      M_AXIL_AWREADY : in  std_logic;
      M_AXIL_WDATA   : out std_logic_vector(31 downto 0);
      M_AXIL_WSTRB   : out std_logic_vector(3 downto 0);
      M_AXIL_WVALID  : out std_logic;
      M_AXIL_WREADY  : in  std_logic;
      M_AXIL_BRESP   : in  std_logic_vector(1 downto 0);
      M_AXIL_BVALID  : in  std_logic;
      M_AXIL_BREADY  : out std_logic;
      M_AXIL_ARADDR  : out std_logic_vector(31 downto 0);
      M_AXIL_ARPROT  : out std_logic_vector(2 downto 0);
      M_AXIL_ARVALID : out std_logic;
      M_AXIL_ARREADY : in  std_logic;
      M_AXIL_RDATA   : in  std_logic_vector(31 downto 0);
      M_AXIL_RRESP   : in  std_logic_vector(1 downto 0);
      M_AXIL_RVALID  : in  std_logic;
      M_AXIL_RREADY  : out std_logic);
end entity SrpV0AxiLiteWrapper;

architecture rtl of SrpV0AxiLiteWrapper is

   constant TPD_C         : time                := 10 ns / 4;
   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4);

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

   -- AXI Stream request shim into the DUT.
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
         TDATA_NUM_BYTES => 4)
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

   -- AXI Stream response shim back to cocotb.
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
         TDATA_NUM_BYTES => 4)
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

   -- AXI-Lite shim exposes the DUT's generated bus to cocotb RAM/responders.
   U_ShimLayerAxil : entity surf.MasterAxiLiteIpIntegrator
      generic map (
         INTERFACENAME => "M_AXIL",
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 32)
      port map (
         M_AXI_ACLK      => AXIS_ACLK,
         M_AXI_ARESETN   => AXIS_ARESETN,
         M_AXI_AWADDR    => M_AXIL_AWADDR,
         M_AXI_AWPROT    => M_AXIL_AWPROT,
         M_AXI_AWVALID   => M_AXIL_AWVALID,
         M_AXI_AWREADY   => M_AXIL_AWREADY,
         M_AXI_WDATA     => M_AXIL_WDATA,
         M_AXI_WSTRB     => M_AXIL_WSTRB,
         M_AXI_WVALID    => M_AXIL_WVALID,
         M_AXI_WREADY    => M_AXIL_WREADY,
         M_AXI_BRESP     => M_AXIL_BRESP,
         M_AXI_BVALID    => M_AXIL_BVALID,
         M_AXI_BREADY    => M_AXIL_BREADY,
         M_AXI_ARADDR    => M_AXIL_ARADDR,
         M_AXI_ARPROT    => M_AXIL_ARPROT,
         M_AXI_ARVALID   => M_AXIL_ARVALID,
         M_AXI_ARREADY   => M_AXIL_ARREADY,
         M_AXI_RDATA     => M_AXIL_RDATA,
         M_AXI_RRESP     => M_AXIL_RRESP,
         M_AXI_RVALID    => M_AXIL_RVALID,
         M_AXI_RREADY    => M_AXIL_RREADY,
         axilClk         => open,
         axilRst         => open,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   -- DUT under test.
   U_DUT : entity surf.SrpV0AxiLite
      generic map (
         TPD_G               => TPD_C,
         RESP_THOLD_G        => 1,
         SLAVE_READY_EN_G    => true,
         EN_32BIT_ADDR_G     => EN_32BIT_ADDR_G,
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_PAUSE_THRESH_G => 256,
         AXI_STREAM_CONFIG_G => AXIS_CONFIG_C)
      port map (
         sAxisClk            => AXIS_ACLK,
         sAxisRst            => axisRst,
         sAxisMaster         => sAxisMaster,
         sAxisSlave          => sAxisSlave,
         sAxisCtrl           => open,
         mAxisClk            => AXIS_ACLK,
         mAxisRst            => axisRst,
         mAxisMaster         => mAxisMaster,
         mAxisSlave          => mAxisSlave,
         axiLiteClk          => AXIS_ACLK,
         axiLiteRst          => axisRst,
         mAxiLiteWriteMaster => axilWriteMaster,
         mAxiLiteWriteSlave  => axilWriteSlave,
         mAxiLiteReadMaster  => axilReadMaster,
         mAxiLiteReadSlave   => axilReadSlave);

end architecture rtl;
