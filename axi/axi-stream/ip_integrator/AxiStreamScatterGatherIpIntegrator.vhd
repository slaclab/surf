-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP Integrator Wrapper for surf.AxiStreamScatterGather
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

entity AxiStreamScatterGatherIpIntegrator is
   generic (
      TPD_G                   : time    := 1 ns;
      AXIS_SLAVE_FRAME_SIZE_G : integer := 129);
   port (
      axiClk         : in  sl;
      axiRst         : in  sl;
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
      S_AXIS_TDATA   : in  slv(15 downto 0);
      S_AXIS_TKEEP   : in  slv(1 downto 0);
      S_AXIS_TLAST   : in  sl;
      S_AXIS_TDEST   : in  slv(0 downto 0);
      S_AXIS_TID     : in  slv(0 downto 0);
      S_AXIS_TUSER   : in  slv(1 downto 0);
      S_AXIS_TREADY  : out sl;
      M_AXIS_TVALID  : out sl;
      M_AXIS_TDATA   : out slv(95 downto 0);
      M_AXIS_TKEEP   : out slv(11 downto 0);
      M_AXIS_TLAST   : out sl;
      M_AXIS_TDEST   : out slv(0 downto 0);
      M_AXIS_TID     : out slv(0 downto 0);
      M_AXIS_TUSER   : out slv(1 downto 0);
      M_AXIS_TREADY  : in  sl);
end entity AxiStreamScatterGatherIpIntegrator;

architecture rtl of AxiStreamScatterGatherIpIntegrator is

   constant SLAVE_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      dataBytes => 2,
      tDestBits => 1,
      tUserBits => 2,
      tIdBits   => 1);

   constant MASTER_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      dataBytes => 12,
      tDestBits => 1,
      tUserBits => 2,
      tIdBits   => 1);

   signal axiResetN       : sl := '1';
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal sAxisMaster     : AxiStreamMasterType    := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave      : AxiStreamSlaveType     := AXI_STREAM_SLAVE_INIT_C;
   signal sAxisCtrl       : AxiStreamCtrlType      := AXI_STREAM_CTRL_UNUSED_C;
   signal mAxisMaster     : AxiStreamMasterType    := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave      : AxiStreamSlaveType     := AXI_STREAM_SLAVE_INIT_C;

begin

   ---------------------------------------------------------------------------
   -- AXI-Lite shim
   ---------------------------------------------------------------------------
   axiResetN <= not axiRst;

   U_AXIL : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 8)
      port map (
         S_AXI_ACLK      => axiClk,
         S_AXI_ARESETN   => axiResetN,
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

   ---------------------------------------------------------------------------
   -- AXI-Stream shims
   ---------------------------------------------------------------------------
   U_S_AXIS : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "S_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 2,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 1,
         TDATA_NUM_BYTES => 2)
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
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 1,
         TDATA_NUM_BYTES => 12)
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

   ---------------------------------------------------------------------------
   -- DUT
   ---------------------------------------------------------------------------
   U_DUT : entity surf.AxiStreamScatterGather
      generic map (
         TPD_G                   => TPD_G,
         AXIS_SLAVE_FRAME_SIZE_G => AXIS_SLAVE_FRAME_SIZE_G,
         SLAVE_AXIS_CONFIG_G     => SLAVE_AXIS_CONFIG_C,
         MASTER_AXIS_CONFIG_G    => MASTER_AXIS_CONFIG_C)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         sAxisMaster     => sAxisMaster,
         sAxisSlave      => sAxisSlave,
         sAxisCtrl       => sAxisCtrl,
         mAxisMaster     => mAxisMaster,
         mAxisSlave      => mAxisSlave,
         mAxisCtrl       => AXI_STREAM_CTRL_UNUSED_C);

   ---------------------------------------------------------------------------
   -- Export stream-control status for the bench
   ---------------------------------------------------------------------------
   sAxisPause    <= sAxisCtrl.pause;
   sAxisOverflow <= sAxisCtrl.overflow;
   sAxisIdle     <= sAxisCtrl.idle;

end architecture rtl;
