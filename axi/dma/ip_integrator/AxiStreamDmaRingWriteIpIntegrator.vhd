-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP Integrator Wrapper for surf.AxiStreamDmaRingWrite
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

entity AxiStreamDmaRingWriteIpIntegrator is
   port (
      axilClk         : in  sl;
      axilRst         : in  sl;
      S_AXI_AWADDR    : in  slv(11 downto 0);
      S_AXI_AWPROT    : in  slv(2 downto 0);
      S_AXI_AWVALID   : in  sl;
      S_AXI_AWREADY   : out sl;
      S_AXI_WDATA     : in  slv(31 downto 0);
      S_AXI_WSTRB     : in  slv(3 downto 0);
      S_AXI_WVALID    : in  sl;
      S_AXI_WREADY    : out sl;
      S_AXI_BRESP     : out slv(1 downto 0);
      S_AXI_BVALID    : out sl;
      S_AXI_BREADY    : in  sl;
      S_AXI_ARADDR    : in  slv(11 downto 0);
      S_AXI_ARPROT    : in  slv(2 downto 0);
      S_AXI_ARVALID   : in  sl;
      S_AXI_ARREADY   : out sl;
      S_AXI_RDATA     : out slv(31 downto 0);
      S_AXI_RRESP     : out slv(1 downto 0);
      S_AXI_RVALID    : out sl;
      S_AXI_RREADY    : in  sl;
      axisStatusClk   : in  sl;
      axisStatusRst   : in  sl;
      M_STATUS_TVALID : out sl;
      M_STATUS_TDATA  : out slv(7 downto 0);
      M_STATUS_TLAST  : out sl;
      M_STATUS_TUSER  : out slv(1 downto 0);
      M_STATUS_TDEST  : out slv(3 downto 0);
      M_STATUS_TREADY : in  sl;
      axiClk          : in  sl;
      axiRst          : in  sl;
      S_AXIS_TVALID   : in  sl;
      S_AXIS_TDATA    : in  slv(31 downto 0);
      S_AXIS_TKEEP    : in  slv(3 downto 0);
      S_AXIS_TLAST    : in  sl;
      S_AXIS_TDEST    : in  slv(0 downto 0);
      S_AXIS_TUSER    : in  slv(1 downto 0);
      S_AXIS_TREADY   : out sl;
      bufferEnabled   : out slv(1 downto 0);
      bufferEmpty     : out slv(1 downto 0);
      bufferFull      : out slv(1 downto 0);
      bufferDone      : out slv(1 downto 0);
      bufferTriggered : out slv(1 downto 0);
      bufferError     : out slv(1 downto 0);
      M_AXI_AWID      : out slv(0 downto 0);
      M_AXI_AWADDR    : out slv(15 downto 0);
      M_AXI_AWLEN     : out slv(7 downto 0);
      M_AXI_AWSIZE    : out slv(2 downto 0);
      M_AXI_AWBURST   : out slv(1 downto 0);
      M_AXI_AWLOCK    : out sl;
      M_AXI_AWCACHE   : out slv(3 downto 0);
      M_AXI_AWPROT    : out slv(2 downto 0);
      M_AXI_AWREGION  : out slv(3 downto 0);
      M_AXI_AWQOS     : out slv(3 downto 0);
      M_AXI_AWVALID   : out sl;
      M_AXI_AWREADY   : in  sl;
      M_AXI_WID       : out slv(0 downto 0);
      M_AXI_WDATA     : out slv(31 downto 0);
      M_AXI_WSTRB     : out slv(3 downto 0);
      M_AXI_WLAST     : out sl;
      M_AXI_WVALID    : out sl;
      M_AXI_WREADY    : in  sl;
      M_AXI_BID       : in  slv(0 downto 0);
      M_AXI_BRESP     : in  slv(1 downto 0);
      M_AXI_BVALID    : in  sl;
      M_AXI_BREADY    : out sl);
end entity AxiStreamDmaRingWriteIpIntegrator;

architecture rtl of AxiStreamDmaRingWriteIpIntegrator is

   constant DATA_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 4,
      TDEST_BITS_C  => 1,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant STATUS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      dataBytes => 1,
      tKeepMode => TKEEP_FIXED_C,
      tUserMode => TUSER_FIRST_LAST_C,
      tDestBits => 4,
      tUserBits => 2,
      tIdBits   => 0);

   constant AXI_CONFIG_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => 16,
      DATA_BYTES_C => 4,
      ID_BITS_C    => 1,
      LEN_BITS_C   => 8);

   signal axilResetN       : sl                     := '1';
   signal axisResetN       : sl                     := '1';
   signal statusResetN     : sl                     := '1';
   signal axiResetN        : sl                     := '1';
   signal axilReadMaster   : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave    : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster  : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave   : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal axisDataMaster   : AxiStreamMasterType    := AXI_STREAM_MASTER_INIT_C;
   signal axisDataSlave    : AxiStreamSlaveType     := AXI_STREAM_SLAVE_INIT_C;
   signal axisStatusMaster : AxiStreamMasterType    := AXI_STREAM_MASTER_INIT_C;
   signal axisStatusSlave  : AxiStreamSlaveType     := AXI_STREAM_SLAVE_INIT_C;
   signal axiReadMaster    : AxiReadMasterType      := AXI_READ_MASTER_INIT_C;
   signal axiReadSlave     : AxiReadSlaveType       := AXI_READ_SLAVE_INIT_C;
   signal axiWriteMaster   : AxiWriteMasterType     := AXI_WRITE_MASTER_INIT_C;
   signal axiWriteSlave    : AxiWriteSlaveType      := AXI_WRITE_SLAVE_INIT_C;

begin

   ---------------------------------------------------------------------------
   -- Bus shims
   ---------------------------------------------------------------------------
   axilResetN   <= not axilRst;
   axisResetN   <= not axiRst;
   statusResetN <= not axisStatusRst;
   axiResetN    <= not axiRst;

   U_AXIL : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 12)
      port map (
         S_AXI_ACLK      => axilClk,
         S_AXI_ARESETN   => axilResetN,
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

   U_DATA : entity surf.SlaveAxiStreamIpIntegrator
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
         S_AXIS_ACLK    => axiClk,
         S_AXIS_ARESETN => axisResetN,
         S_AXIS_TVALID  => S_AXIS_TVALID,
         S_AXIS_TDATA   => S_AXIS_TDATA,
         S_AXIS_TSTRB   => (others => '0'),
         S_AXIS_TKEEP   => S_AXIS_TKEEP,
         S_AXIS_TLAST   => S_AXIS_TLAST,
         S_AXIS_TDEST   => S_AXIS_TDEST,
         S_AXIS_TID     => (others => '0'),
         S_AXIS_TUSER   => S_AXIS_TUSER,
         S_AXIS_TREADY  => S_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => axisDataMaster,
         axisSlave      => axisDataSlave);

   U_STATUS : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_STATUS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 0,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 2,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 4,
         TDATA_NUM_BYTES => 1)
      port map (
         M_AXIS_ACLK    => axisStatusClk,
         M_AXIS_ARESETN => statusResetN,
         M_AXIS_TVALID  => M_STATUS_TVALID,
         M_AXIS_TDATA   => M_STATUS_TDATA,
         M_AXIS_TSTRB   => open,
         M_AXIS_TKEEP   => open,
         M_AXIS_TLAST   => M_STATUS_TLAST,
         M_AXIS_TDEST   => M_STATUS_TDEST,
         M_AXIS_TID     => open,
         M_AXIS_TUSER   => M_STATUS_TUSER,
         M_AXIS_TREADY  => M_STATUS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => axisStatusMaster,
         axisSlave      => axisStatusSlave);

   U_AXI : entity surf.MasterAxiIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         ID_WIDTH      => 1,
         ADDR_WIDTH    => 16,
         DATA_WIDTH    => 32)
      port map (
         M_AXI_ACLK     => axiClk,
         M_AXI_ARESETN  => axiResetN,
         M_AXI_AWID     => M_AXI_AWID,
         M_AXI_AWADDR   => M_AXI_AWADDR,
         M_AXI_AWLEN    => M_AXI_AWLEN,
         M_AXI_AWSIZE   => M_AXI_AWSIZE,
         M_AXI_AWBURST  => M_AXI_AWBURST,
         M_AXI_AWLOCK   => open,
         M_AXI_AWCACHE  => M_AXI_AWCACHE,
         M_AXI_AWPROT   => M_AXI_AWPROT,
         M_AXI_AWREGION => M_AXI_AWREGION,
         M_AXI_AWQOS    => M_AXI_AWQOS,
         M_AXI_AWVALID  => M_AXI_AWVALID,
         M_AXI_AWREADY  => M_AXI_AWREADY,
         M_AXI_WID      => M_AXI_WID,
         M_AXI_WDATA    => M_AXI_WDATA,
         M_AXI_WSTRB    => M_AXI_WSTRB,
         M_AXI_WLAST    => M_AXI_WLAST,
         M_AXI_WVALID   => M_AXI_WVALID,
         M_AXI_WREADY   => M_AXI_WREADY,
         M_AXI_BID      => M_AXI_BID,
         M_AXI_BRESP    => M_AXI_BRESP,
         M_AXI_BVALID   => M_AXI_BVALID,
         M_AXI_BREADY   => M_AXI_BREADY,
         M_AXI_ARID     => open,
         M_AXI_ARADDR   => open,
         M_AXI_ARLEN    => open,
         M_AXI_ARSIZE   => open,
         M_AXI_ARBURST  => open,
         M_AXI_ARLOCK   => open,
         M_AXI_ARCACHE  => open,
         M_AXI_ARPROT   => open,
         M_AXI_ARREGION => open,
         M_AXI_ARQOS    => open,
         M_AXI_ARVALID  => open,
         M_AXI_ARREADY  => '0',
         M_AXI_RID      => (others => '0'),
         M_AXI_RDATA    => (others => '0'),
         M_AXI_RRESP    => (others => '0'),
         M_AXI_RLAST    => '0',
         M_AXI_RVALID   => '0',
         M_AXI_RREADY   => open,
         axiClk         => open,
         axiRst         => open,
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave);

   M_AXI_AWLOCK <= '0';

   ---------------------------------------------------------------------------
   -- DUT
   ---------------------------------------------------------------------------
   U_DUT : entity surf.AxiStreamDmaRingWrite
      generic map (
         BUFFERS_G            => 2,
         BURST_SIZE_BYTES_G   => 16,
         TRIGGER_USER_BIT_G   => 1,
         DATA_AXIS_CONFIG_G   => DATA_CONFIG_C,
         STATUS_AXIS_CONFIG_G => STATUS_CONFIG_C,
         AXI_WRITE_CONFIG_G   => AXI_CONFIG_C)
      port map (
         axilClk          => axilClk,
         axilRst          => axilRst,
         axilReadMaster   => axilReadMaster,
         axilReadSlave    => axilReadSlave,
         axilWriteMaster  => axilWriteMaster,
         axilWriteSlave   => axilWriteSlave,
         axisStatusClk    => axisStatusClk,
         axisStatusRst    => axisStatusRst,
         axisStatusMaster => axisStatusMaster,
         axisStatusSlave  => axisStatusSlave,
         axiClk           => axiClk,
         axiRst           => axiRst,
         axisDataMaster   => axisDataMaster,
         axisDataSlave    => axisDataSlave,
         bufferEnabled    => bufferEnabled,
         bufferEmpty      => bufferEmpty,
         bufferFull       => bufferFull,
         bufferDone       => bufferDone,
         bufferTriggered  => bufferTriggered,
         bufferError      => bufferError,
         axiWriteMaster   => axiWriteMaster,
         axiWriteSlave    => axiWriteSlave);

end architecture rtl;
