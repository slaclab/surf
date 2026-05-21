-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP Integrator Wrapper for surf.AxiStreamFrameBuffer
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

entity AxiStreamFrameBufferIpIntegrator is
   generic (
      TPD_G          : time    := 1 ns;
      ASYNC_CLOCKS_G : boolean := true;
      SAFE_BUFFS_G   : boolean := true);
   port (
      dataClk         : in  sl;
      dataRst         : in  sl := '0';
      dataValid       : in  sl := '1';
      dataValue       : in  slv(15 downto 0);
      dataFrameTxLast : in  sl := '0';
      dataFrameRxDone : out sl := '0';
      dataRdTrig      : in  sl;
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilRdTrig      : in  sl;
      axisClk         : in  sl;
      axisRst         : in  sl;
      S_AXI_AWADDR    : in  slv(7 downto 0);
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
      S_AXI_ARADDR    : in  slv(7 downto 0);
      S_AXI_ARPROT    : in  slv(2 downto 0);
      S_AXI_ARVALID   : in  sl;
      S_AXI_ARREADY   : out sl;
      S_AXI_RDATA     : out slv(31 downto 0);
      S_AXI_RRESP     : out slv(1 downto 0);
      S_AXI_RVALID    : out sl;
      S_AXI_RREADY    : in  sl;
      M_AXIS_TVALID   : out sl;
      M_AXIS_TDATA    : out slv(15 downto 0);
      M_AXIS_TKEEP    : out slv(1 downto 0);
      M_AXIS_TLAST    : out sl;
      M_AXIS_TDEST    : out slv(0 downto 0);
      M_AXIS_TID      : out slv(0 downto 0);
      M_AXIS_TUSER    : out slv(1 downto 0);
      M_AXIS_TREADY   : in  sl);
end entity AxiStreamFrameBufferIpIntegrator;

architecture rtl of AxiStreamFrameBufferIpIntegrator is

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      dataBytes => 2,
      tDestBits => 1,
      tUserBits => 2,
      tIdBits   => 1);

   signal axilResetN      : sl                     := '1';
   signal axisResetN      : sl                     := '1';
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal axisMaster      : AxiStreamMasterType    := AXI_STREAM_MASTER_INIT_C;
   signal axisSlave       : AxiStreamSlaveType     := AXI_STREAM_SLAVE_INIT_C;

begin

   ---------------------------------------------------------------------------
   -- AXI-Lite and AXI-Stream shims
   ---------------------------------------------------------------------------
   axilResetN <= not axilRst;
   axisResetN <= not axisRst;

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
         TDATA_NUM_BYTES => 2)
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

   ---------------------------------------------------------------------------
   -- DUT
   ---------------------------------------------------------------------------
   U_DUT : entity surf.AxiStreamFrameBuffer
      generic map (
         TPD_G               => TPD_G,
         COMMON_CLK_G        => not ASYNC_CLOCKS_G,
         DATA_BYTES_G        => 2,
         RAM_ADDR_WIDTH_G    => 4,
         SAFE_BUFFS_G        => SAFE_BUFFS_G,
         GEN_SYNC_FIFO_G     => not ASYNC_CLOCKS_G,
         AXI_STREAM_CONFIG_G => AXIS_CONFIG_C)
      port map (
         dataClk         => dataClk,
         dataRst         => dataRst,
         dataValid       => dataValid,
         dataValue       => dataValue,
         dataFrameTxLast => dataFrameTxLast,
         dataFrameRxDone => dataFrameRxDone,
         dataRdTrig      => dataRdTrig,
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         axilRdTrig      => axilRdTrig,
         axisClk         => axisClk,
         axisRst         => axisRst,
         axisMaster      => axisMaster,
         axisSlave       => axisSlave);

end architecture rtl;
