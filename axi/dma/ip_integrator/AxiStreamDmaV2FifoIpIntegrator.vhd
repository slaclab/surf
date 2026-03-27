-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP Integrator Wrapper for surf.AxiStreamDmaV2Fifo
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

entity AxiStreamDmaV2FifoIpIntegrator is
   generic (
      TPD_G : time := 1 ns);
   port (
      axiClk         : in  sl;
      axiRst         : in  sl;
      axilClk        : in  sl;
      axilRst        : in  sl;
      axiReady       : in  sl;
      sAxisPause     : out sl;
      sAxisOverflow  : out sl;
      sAxisIdle      : out sl;
      S_AXI_AWADDR   : in  slv(7 downto 0);
      S_AXI_AWPROT   : in  slv(2 downto 0);
      S_AXI_AWVALID  : in  sl;
      S_AXI_AWREADY  : out sl;
      S_AXI_WDATA    : in  slv(31 downto 0);
      S_AXI_WSTRB    : in  slv(3 downto 0);
      S_AXI_WVALID   : in  sl;
      S_AXI_WREADY   : out sl;
      S_AXI_BRESP    : out slv(1 downto 0);
      S_AXI_BVALID   : out sl;
      S_AXI_BREADY   : in  sl;
      S_AXI_ARADDR   : in  slv(7 downto 0);
      S_AXI_ARPROT   : in  slv(2 downto 0);
      S_AXI_ARVALID  : in  sl;
      S_AXI_ARREADY  : out sl;
      S_AXI_RDATA    : out slv(31 downto 0);
      S_AXI_RRESP    : out slv(1 downto 0);
      S_AXI_RVALID   : out sl;
      S_AXI_RREADY   : in  sl;
      S_AXIS_TVALID  : in  sl;
      S_AXIS_TDATA   : in  slv(31 downto 0);
      S_AXIS_TKEEP   : in  slv(3 downto 0);
      S_AXIS_TLAST   : in  sl;
      S_AXIS_TDEST   : in  slv(7 downto 0);
      S_AXIS_TID     : in  slv(7 downto 0);
      S_AXIS_TUSER   : in  slv(1 downto 0);
      S_AXIS_TREADY  : out sl;
      M_AXIS_TVALID  : out sl;
      M_AXIS_TDATA   : out slv(31 downto 0);
      M_AXIS_TKEEP   : out slv(3 downto 0);
      M_AXIS_TLAST   : out sl;
      M_AXIS_TDEST   : out slv(7 downto 0);
      M_AXIS_TID     : out slv(7 downto 0);
      M_AXIS_TUSER   : out slv(1 downto 0);
      M_AXIS_TREADY  : in  sl;
      M_AXI_AWID     : out slv(7 downto 0);
      M_AXI_AWADDR   : out slv(15 downto 0);
      M_AXI_AWLEN    : out slv(7 downto 0);
      M_AXI_AWSIZE   : out slv(2 downto 0);
      M_AXI_AWBURST  : out slv(1 downto 0);
      M_AXI_AWLOCK   : out sl;
      M_AXI_AWCACHE  : out slv(3 downto 0);
      M_AXI_AWPROT   : out slv(2 downto 0);
      M_AXI_AWREGION : out slv(3 downto 0);
      M_AXI_AWQOS    : out slv(3 downto 0);
      M_AXI_AWVALID  : out sl;
      M_AXI_AWREADY  : in  sl;
      M_AXI_WID      : out slv(7 downto 0);
      M_AXI_WDATA    : out slv(31 downto 0);
      M_AXI_WSTRB    : out slv(3 downto 0);
      M_AXI_WLAST    : out sl;
      M_AXI_WVALID   : out sl;
      M_AXI_WREADY   : in  sl;
      M_AXI_BID      : in  slv(7 downto 0);
      M_AXI_BRESP    : in  slv(1 downto 0);
      M_AXI_BVALID   : in  sl;
      M_AXI_BREADY   : out sl;
      M_AXI_ARID     : out slv(7 downto 0);
      M_AXI_ARADDR   : out slv(15 downto 0);
      M_AXI_ARLEN    : out slv(7 downto 0);
      M_AXI_ARSIZE   : out slv(2 downto 0);
      M_AXI_ARBURST  : out slv(1 downto 0);
      M_AXI_ARLOCK   : out sl;
      M_AXI_ARCACHE  : out slv(3 downto 0);
      M_AXI_ARPROT   : out slv(2 downto 0);
      M_AXI_ARREGION : out slv(3 downto 0);
      M_AXI_ARQOS    : out slv(3 downto 0);
      M_AXI_ARVALID  : out sl;
      M_AXI_ARREADY  : in  sl;
      M_AXI_RID      : in  slv(7 downto 0);
      M_AXI_RDATA    : in  slv(31 downto 0);
      M_AXI_RRESP    : in  slv(1 downto 0);
      M_AXI_RLAST    : in  sl;
      M_AXI_RVALID   : in  sl;
      M_AXI_RREADY   : out sl);
end entity AxiStreamDmaV2FifoIpIntegrator;

architecture rtl of AxiStreamDmaV2FifoIpIntegrator is

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 4,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant AXI_CONFIG_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => 16,
      DATA_BYTES_C => 4,
      ID_BITS_C    => 8,
      LEN_BITS_C   => 8);

   signal axiResetN       : sl := '1';
   signal axilResetN      : sl := '1';
   signal mAxiAwLock      : slv(1 downto 0)   := (others => '0');
   signal mAxiArLock      : slv(1 downto 0)   := (others => '0');
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal sAxisMaster     : AxiStreamMasterType    := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave      : AxiStreamSlaveType     := AXI_STREAM_SLAVE_INIT_C;
   signal sAxisCtrl       : AxiStreamCtrlType      := AXI_STREAM_CTRL_UNUSED_C;
   signal mAxisMaster     : AxiStreamMasterType    := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave      : AxiStreamSlaveType     := AXI_STREAM_SLAVE_INIT_C;
   signal axiReadMaster   : AxiReadMasterType      := AXI_READ_MASTER_INIT_C;
   signal axiReadSlave    : AxiReadSlaveType       := AXI_READ_SLAVE_INIT_C;
   signal axiWriteMaster  : AxiWriteMasterType     := AXI_WRITE_MASTER_INIT_C;
   signal axiWriteSlave   : AxiWriteSlaveType      := AXI_WRITE_SLAVE_INIT_C;

begin

   ---------------------------------------------------------------------------
   -- AXI-Lite, AXI-Stream, and AXI shims
   ---------------------------------------------------------------------------
   axiResetN  <= not axiRst;
   axilResetN <= not axilRst;

   M_AXI_AWLOCK <= mAxiAwLock(0);
   M_AXI_ARLOCK <= mAxiArLock(0);

   U_AXIL : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 8)
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

   U_S_AXIS : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "S_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 2,
         TID_WIDTH       => 8,
         TDEST_WIDTH     => 8,
         TDATA_NUM_BYTES => 4)
      port map (
         S_AXIS_ACLK    => axiClk,
         S_AXIS_ARESETN => axiResetN,
         S_AXIS_TVALID  => S_AXIS_TVALID,
         S_AXIS_TDATA   => S_AXIS_TDATA,
         S_AXIS_TSTRB   => (others => '0'),
         S_AXIS_TKEEP   => S_AXIS_TKEEP,
         S_AXIS_TLAST   => S_AXIS_TLAST,
         S_AXIS_TDEST   => S_AXIS_TDEST,
         S_AXIS_TID     => S_AXIS_TID,
         S_AXIS_TUSER   => S_AXIS_TUSER,
         S_AXIS_TREADY  => S_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => sAxisMaster,
         axisSlave      => sAxisSlave);

   U_M_AXIS : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 2,
         TID_WIDTH       => 8,
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
         axisMaster     => mAxisMaster,
         axisSlave      => mAxisSlave);

   U_M_AXI : entity surf.MasterAxiIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         ID_WIDTH      => 8,
         ADDR_WIDTH    => 16,
         DATA_WIDTH    => 32)
      port map (
         M_AXI_ACLK      => axiClk,
         M_AXI_ARESETN   => axiResetN,
         M_AXI_AWID      => M_AXI_AWID,
         M_AXI_AWADDR    => M_AXI_AWADDR,
         M_AXI_AWLEN     => M_AXI_AWLEN,
         M_AXI_AWSIZE    => M_AXI_AWSIZE,
         M_AXI_AWBURST   => M_AXI_AWBURST,
         M_AXI_AWLOCK    => mAxiAwLock,
         M_AXI_AWCACHE   => M_AXI_AWCACHE,
         M_AXI_AWPROT    => M_AXI_AWPROT,
         M_AXI_AWREGION  => M_AXI_AWREGION,
         M_AXI_AWQOS     => M_AXI_AWQOS,
         M_AXI_AWVALID   => M_AXI_AWVALID,
         M_AXI_AWREADY   => M_AXI_AWREADY,
         M_AXI_WID       => M_AXI_WID,
         M_AXI_WDATA     => M_AXI_WDATA,
         M_AXI_WSTRB     => M_AXI_WSTRB,
         M_AXI_WLAST     => M_AXI_WLAST,
         M_AXI_WVALID    => M_AXI_WVALID,
         M_AXI_WREADY    => M_AXI_WREADY,
         M_AXI_BID       => M_AXI_BID,
         M_AXI_BRESP     => M_AXI_BRESP,
         M_AXI_BVALID    => M_AXI_BVALID,
         M_AXI_BREADY    => M_AXI_BREADY,
         M_AXI_ARID      => M_AXI_ARID,
         M_AXI_ARADDR    => M_AXI_ARADDR,
         M_AXI_ARLEN     => M_AXI_ARLEN,
         M_AXI_ARSIZE    => M_AXI_ARSIZE,
         M_AXI_ARBURST   => M_AXI_ARBURST,
         M_AXI_ARLOCK    => mAxiArLock,
         M_AXI_ARCACHE   => M_AXI_ARCACHE,
         M_AXI_ARPROT    => M_AXI_ARPROT,
         M_AXI_ARREGION  => M_AXI_ARREGION,
         M_AXI_ARQOS     => M_AXI_ARQOS,
         M_AXI_ARVALID   => M_AXI_ARVALID,
         M_AXI_ARREADY   => M_AXI_ARREADY,
         M_AXI_RID       => M_AXI_RID,
         M_AXI_RDATA     => M_AXI_RDATA,
         M_AXI_RRESP     => M_AXI_RRESP,
         M_AXI_RLAST     => M_AXI_RLAST,
         M_AXI_RVALID    => M_AXI_RVALID,
         M_AXI_RREADY    => M_AXI_RREADY,
         axiClk          => open,
         axiRst          => open,
         axiReadMaster   => axiReadMaster,
         axiReadSlave    => axiReadSlave,
         axiWriteMaster  => axiWriteMaster,
         axiWriteSlave   => axiWriteSlave);

   ---------------------------------------------------------------------------
   -- DUT
   ---------------------------------------------------------------------------
   U_DUT : entity surf.AxiStreamDmaV2Fifo
      generic map (
         TPD_G              => TPD_G,
         COMMON_CLK_G       => true,
         BUFF_FRAME_WIDTH_G => 8,
         AXI_BUFFER_WIDTH_G => 12,
         AXIS_CONFIG_G      => AXIS_CONFIG_C,
         AXI_CONFIG_G       => AXI_CONFIG_C,
         BURST_BYTES_G      => 16,
         RD_PEND_THRESH_G   => 4)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         axiReady        => axiReady,
         axiReadMaster   => axiReadMaster,
         axiReadSlave    => axiReadSlave,
         axiWriteMaster  => axiWriteMaster,
         axiWriteSlave   => axiWriteSlave,
         sAxisMaster     => sAxisMaster,
         sAxisSlave      => sAxisSlave,
         sAxisCtrl       => sAxisCtrl,
         mAxisMaster     => mAxisMaster,
         mAxisSlave      => mAxisSlave,
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   ---------------------------------------------------------------------------
   -- Export stream-control status for the bench
   ---------------------------------------------------------------------------
   sAxisPause    <= sAxisCtrl.pause;
   sAxisOverflow <= sAxisCtrl.overflow;
   sAxisIdle     <= sAxisCtrl.idle;

end architecture rtl;
