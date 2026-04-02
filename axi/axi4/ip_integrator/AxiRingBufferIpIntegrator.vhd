-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP Integrator Wrapper for surf.AxiRingBuffer
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

entity AxiRingBufferIpIntegrator is
   port (
      dataClk        : in  sl;
      dataRst        : in  sl;
      dataValid      : in  sl;
      dataValue      : in  slv(31 downto 0);
      extTrig        : in  sl;
      axisClk        : in  sl;
      axisRst        : in  sl;
      M_AXIS_TVALID  : out sl;
      M_AXIS_TDATA   : out slv(31 downto 0);
      M_AXIS_TKEEP   : out slv(3 downto 0);
      M_AXIS_TLAST   : out sl;
      M_AXIS_TDEST   : out slv(7 downto 0);
      M_AXIS_TID     : out slv(0 downto 0);
      M_AXIS_TUSER   : out slv(1 downto 0);
      M_AXIS_TREADY  : in  sl;
      axiClk         : in  sl;
      axiRst         : in  sl;
      M_AXI_AWID     : out slv(0 downto 0);
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
      M_AXI_WID      : out slv(0 downto 0);
      M_AXI_WDATA    : out slv(31 downto 0);
      M_AXI_WSTRB    : out slv(3 downto 0);
      M_AXI_WLAST    : out sl;
      M_AXI_WVALID   : out sl;
      M_AXI_WREADY   : in  sl;
      M_AXI_BID      : in  slv(0 downto 0);
      M_AXI_BRESP    : in  slv(1 downto 0);
      M_AXI_BVALID   : in  sl;
      M_AXI_BREADY   : out sl;
      M_AXI_ARID     : out slv(0 downto 0);
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
      M_AXI_RID      : in  slv(0 downto 0);
      M_AXI_RDATA    : in  slv(31 downto 0);
      M_AXI_RRESP    : in  slv(1 downto 0);
      M_AXI_RLAST    : in  sl;
      M_AXI_RVALID   : in  sl;
      M_AXI_RREADY   : out sl);
end entity AxiRingBufferIpIntegrator;

architecture rtl of AxiRingBufferIpIntegrator is

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      dataBytes => 4,
      tKeepMode => TKEEP_FIXED_C,
      tUserMode => TUSER_FIRST_LAST_C,
      tDestBits => 8,
      tUserBits => 2,
      tIdBits   => 0);

   signal axisResetN      : sl := '1';
   signal axiResetN       : sl := '1';
   signal axisMaster      : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal axisSlave       : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal axiWriteMaster  : AxiWriteMasterType  := AXI_WRITE_MASTER_INIT_C;
   signal axiWriteSlave   : AxiWriteSlaveType   := AXI_WRITE_SLAVE_INIT_C;
   signal axiReadMaster   : AxiReadMasterType   := AXI_READ_MASTER_INIT_C;
   signal axiReadSlave    : AxiReadSlaveType    := AXI_READ_SLAVE_INIT_C;

begin

   ---------------------------------------------------------------------------
   -- Bus shims
   ---------------------------------------------------------------------------
   axisResetN <= not axisRst;
   axiResetN  <= not axiRst;

   U_AXIS : entity surf.MasterAxiStreamIpIntegrator
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
         M_AXIS_ACLK    => axisClk,
         M_AXIS_ARESETN => axisResetN,
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
         axisMaster     => axisMaster,
         axisSlave      => axisSlave);

   U_AXI : entity surf.MasterAxiIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         ID_WIDTH      => 1,
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
         M_AXI_AWLOCK    => open,
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
         M_AXI_ARLOCK    => open,
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

   M_AXI_AWLOCK <= '0';
   M_AXI_ARLOCK <= '0';

   ---------------------------------------------------------------------------
   -- DUT
   ---------------------------------------------------------------------------
   U_DUT : entity surf.AxiRingBuffer
      generic map (
         ENABLE_DEFAULT_G       => '1',
         DATA_BYTES_G           => 4,
         RING_BUFF_ADDR_WIDTH_G => 10,
         AXIL_CLK_IS_DATA_CLK_G => true,
         AXI_CLK_IS_DATA_CLK_G  => true,
         BURST_BYTES_G          => 256,
         AXIS_CLK_IS_DATA_CLK_G => true,
         AXIS_CONFIG_G          => AXIS_CONFIG_C)
      port map (
         dataClk         => dataClk,
         dataRst         => dataRst,
         dataValid       => dataValid,
         dataValue       => dataValue,
         extTrig         => extTrig,
         axiClk          => axiClk,
         axiRst          => axiRst,
         axiReady        => '1',
         mAxiWriteMaster => axiWriteMaster,
         mAxiWriteSlave  => axiWriteSlave,
         mAxiReadMaster  => axiReadMaster,
         mAxiReadSlave   => axiReadSlave,
         axilClk         => dataClk,
         axilRst         => dataRst,
         axilReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
         axilReadSlave   => open,
         axilWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
         axilWriteSlave  => open,
         axisClk         => axisClk,
         axisRst         => axisRst,
         axisMaster      => axisMaster,
         axisSlave       => axisSlave);

end architecture rtl;
