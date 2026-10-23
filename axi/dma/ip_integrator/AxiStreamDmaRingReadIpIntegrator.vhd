-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP Integrator Wrapper for surf.AxiStreamDmaRingRead
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
use surf.AxiPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity AxiStreamDmaRingReadIpIntegrator is
   generic (
      AXI_ADDR_WIDTH_G : positive range 12 to 64 := 16);
   port (
      axilClk         : in  sl;
      axilRst         : in  sl;
      M_AXIL_AWADDR   : out slv(31 downto 0);
      M_AXIL_AWPROT   : out slv(2 downto 0);
      M_AXIL_AWVALID  : out sl;
      M_AXIL_AWREADY  : in  sl;
      M_AXIL_WDATA    : out slv(31 downto 0);
      M_AXIL_WSTRB    : out slv(3 downto 0);
      M_AXIL_WVALID   : out sl;
      M_AXIL_WREADY   : in  sl;
      M_AXIL_BRESP    : in  slv(1 downto 0);
      M_AXIL_BVALID   : in  sl;
      M_AXIL_BREADY   : out sl;
      M_AXIL_ARADDR   : out slv(31 downto 0);
      M_AXIL_ARPROT   : out slv(2 downto 0);
      M_AXIL_ARVALID  : out sl;
      M_AXIL_ARREADY  : in  sl;
      M_AXIL_RDATA    : in  slv(31 downto 0);
      M_AXIL_RRESP    : in  slv(1 downto 0);
      M_AXIL_RVALID   : in  sl;
      M_AXIL_RREADY   : out sl;
      statusClk       : in  sl;
      statusRst       : in  sl;
      S_STATUS_TVALID : in  sl;
      S_STATUS_TDATA  : in  slv(7 downto 0);
      S_STATUS_TLAST  : in  sl;
      S_STATUS_TREADY : out sl;
      axiClk          : in  sl;
      axiRst          : in  sl;
      M_AXIS_TVALID   : out sl;
      M_AXIS_TDATA    : out slv(31 downto 0);
      M_AXIS_TKEEP    : out slv(3 downto 0);
      M_AXIS_TLAST    : out sl;
      M_AXIS_TDEST    : out slv(7 downto 0);
      M_AXIS_TID      : out slv(0 downto 0);
      M_AXIS_TUSER    : out slv(1 downto 0);
      M_AXIS_TREADY   : in  sl;
      M_AXI_ARID      : out slv(0 downto 0);
      M_AXI_ARADDR    : out slv(AXI_ADDR_WIDTH_G-1 downto 0);
      M_AXI_ARLEN     : out slv(7 downto 0);
      M_AXI_ARSIZE    : out slv(2 downto 0);
      M_AXI_ARBURST   : out slv(1 downto 0);
      M_AXI_ARLOCK    : out sl;
      M_AXI_ARCACHE   : out slv(3 downto 0);
      M_AXI_ARPROT    : out slv(2 downto 0);
      M_AXI_ARREGION  : out slv(3 downto 0);
      M_AXI_ARQOS     : out slv(3 downto 0);
      M_AXI_ARVALID   : out sl;
      M_AXI_ARREADY   : in  sl;
      M_AXI_RID       : in  slv(0 downto 0);
      M_AXI_RDATA     : in  slv(31 downto 0);
      M_AXI_RRESP     : in  slv(1 downto 0);
      M_AXI_RLAST     : in  sl;
      M_AXI_RVALID    : in  sl;
      M_AXI_RREADY    : out sl);
end entity AxiStreamDmaRingReadIpIntegrator;

architecture rtl of AxiStreamDmaRingReadIpIntegrator is

   constant STATUS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 1,
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_FIXED_C,
      TUSER_BITS_C  => 1,
      TUSER_MODE_C  => TUSER_NONE_C);

   constant DATA_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      dataBytes => 4,
      tKeepMode => TKEEP_NORMAL_C,
      tUserMode => TUSER_FIRST_LAST_C,
      tDestBits => 8,
      tUserBits => 2,
      tIdBits   => 0);

   constant AXI_CONFIG_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => AXI_ADDR_WIDTH_G,
      DATA_BYTES_C => 4,
      ID_BITS_C    => 1,
      LEN_BITS_C   => 8);

   signal axilResetN      : sl                     := '1';
   signal statusResetN    : sl                     := '1';
   signal axiResetN       : sl                     := '1';
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal statusMaster    : AxiStreamMasterType    := AXI_STREAM_MASTER_INIT_C;
   signal statusSlave     : AxiStreamSlaveType     := AXI_STREAM_SLAVE_INIT_C;
   signal dataMaster      : AxiStreamMasterType    := AXI_STREAM_MASTER_INIT_C;
   signal dataSlave       : AxiStreamSlaveType     := AXI_STREAM_SLAVE_INIT_C;
   signal axiReadMaster   : AxiReadMasterType      := AXI_READ_MASTER_INIT_C;
   signal axiReadSlave    : AxiReadSlaveType       := AXI_READ_SLAVE_INIT_C;
   signal axiWriteMaster  : AxiWriteMasterType     := AXI_WRITE_MASTER_INIT_C;
   signal axiWriteSlave   : AxiWriteSlaveType      := AXI_WRITE_SLAVE_INIT_C;

begin

   ---------------------------------------------------------------------------
   -- Bus shims
   ---------------------------------------------------------------------------
   axilResetN   <= not axilRst;
   statusResetN <= not statusRst;
   axiResetN    <= not axiRst;

   U_AXIL : entity surf.MasterAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 32)
      port map (
         M_AXI_ACLK      => axilClk,
         M_AXI_ARESETN   => axilResetN,
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

   U_STATUS : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "S_STATUS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 0,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 1,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 1,
         TDATA_NUM_BYTES => 1)
      port map (
         S_AXIS_ACLK    => statusClk,
         S_AXIS_ARESETN => statusResetN,
         S_AXIS_TVALID  => S_STATUS_TVALID,
         S_AXIS_TDATA   => S_STATUS_TDATA,
         S_AXIS_TSTRB   => (others => '0'),
         S_AXIS_TKEEP   => (others => '1'),
         S_AXIS_TLAST   => S_STATUS_TLAST,
         S_AXIS_TDEST   => (others => '0'),
         S_AXIS_TID     => (others => '0'),
         S_AXIS_TUSER   => "0",
         S_AXIS_TREADY  => S_STATUS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => statusMaster,
         axisSlave      => statusSlave);

   U_DATA : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 2,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 8,
         TDATA_NUM_BYTES => 4)
      port map (
         M_AXIS_ACLK    => axiClk,
         M_AXIS_ARESETN => axiResetN,
         M_AXIS_TVALID  => M_AXIS_TVALID,
         M_AXIS_TDATA   => M_AXIS_TDATA,
         M_AXIS_TSTRB   => open,
         M_AXIS_TKEEP   => M_AXIS_TKEEP,
         M_AXIS_TLAST   => M_AXIS_TLAST,
         M_AXIS_TDEST   => M_AXIS_TDEST,
         M_AXIS_TID     => M_AXIS_TID,
         M_AXIS_TUSER   => M_AXIS_TUSER,
         M_AXIS_TREADY  => M_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => dataMaster,
         axisSlave      => dataSlave);

   U_AXI : entity surf.MasterAxiIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         ID_WIDTH      => 1,
         ADDR_WIDTH    => AXI_ADDR_WIDTH_G,
         DATA_WIDTH    => 32)
      port map (
         M_AXI_ACLK     => axiClk,
         M_AXI_ARESETN  => axiResetN,
         M_AXI_AWID     => open,
         M_AXI_AWADDR   => open,
         M_AXI_AWLEN    => open,
         M_AXI_AWSIZE   => open,
         M_AXI_AWBURST  => open,
         M_AXI_AWLOCK   => open,
         M_AXI_AWCACHE  => open,
         M_AXI_AWPROT   => open,
         M_AXI_AWREGION => open,
         M_AXI_AWQOS    => open,
         M_AXI_AWVALID  => open,
         M_AXI_AWREADY  => '0',
         M_AXI_WID      => open,
         M_AXI_WDATA    => open,
         M_AXI_WSTRB    => open,
         M_AXI_WLAST    => open,
         M_AXI_WVALID   => open,
         M_AXI_WREADY   => '0',
         M_AXI_BID      => (others => '0'),
         M_AXI_BRESP    => (others => '0'),
         M_AXI_BVALID   => '0',
         M_AXI_BREADY   => open,
         M_AXI_ARID     => M_AXI_ARID,
         M_AXI_ARADDR   => M_AXI_ARADDR,
         M_AXI_ARLEN    => M_AXI_ARLEN,
         M_AXI_ARSIZE   => M_AXI_ARSIZE,
         M_AXI_ARBURST  => M_AXI_ARBURST,
         M_AXI_ARLOCK   => open,
         M_AXI_ARCACHE  => open,
         M_AXI_ARPROT   => open,
         M_AXI_ARREGION => open,
         M_AXI_ARQOS    => open,
         M_AXI_ARVALID  => M_AXI_ARVALID,
         M_AXI_ARREADY  => M_AXI_ARREADY,
         M_AXI_RID      => M_AXI_RID,
         M_AXI_RDATA    => M_AXI_RDATA,
         M_AXI_RRESP    => M_AXI_RRESP,
         M_AXI_RLAST    => M_AXI_RLAST,
         M_AXI_RVALID   => M_AXI_RVALID,
         M_AXI_RREADY   => M_AXI_RREADY,
         axiClk         => open,
         axiRst         => open,
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave);

   M_AXI_ARLOCK   <= '0';
   M_AXI_ARCACHE  <= (others => '0');
   M_AXI_ARPROT   <= (others => '0');
   M_AXI_ARREGION <= (others => '0');
   M_AXI_ARQOS    <= (others => '0');

   ---------------------------------------------------------------------------
   -- DUT
   ---------------------------------------------------------------------------
   U_DUT : entity surf.AxiStreamDmaRingRead
      generic map (
         BUFFERS_G           => 2,
         BURST_SIZE_BYTES_G  => 16,
         AXI_STREAM_CONFIG_G => DATA_CONFIG_C,
         AXI_READ_CONFIG_G   => AXI_CONFIG_C)
      port map (
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         statusClk       => statusClk,
         statusRst       => statusRst,
         statusMaster    => statusMaster,
         statusSlave     => statusSlave,
         dataMaster      => dataMaster,
         dataSlave       => dataSlave,
         dataCtrl        => AXI_STREAM_CTRL_UNUSED_C,
         axiClk          => axiClk,
         axiRst          => axiRst,
         axiReadMaster   => axiReadMaster,
         axiReadSlave    => axiReadSlave);

end architecture rtl;
