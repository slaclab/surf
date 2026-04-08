-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP Integrator Wrapper for surf.AxiStreamDmaWrite
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
use surf.AxiDmaPkg.all;
use surf.AxiStreamPkg.all;

entity AxiStreamDmaWriteIpIntegrator is
   port (
      axiClk            : in  sl;
      axiRst            : in  sl;
      dmaReqRequest     : in  sl;
      dmaReqDrop        : in  sl;
      dmaReqAddress     : in  slv(63 downto 0);
      dmaReqMaxSize     : in  slv(31 downto 0);
      dmaReqProt        : in  slv(2 downto 0);
      dmaAckDone        : out sl;
      dmaAckIdle        : out sl;
      dmaAckSize        : out slv(31 downto 0);
      dmaAckOverflow    : out sl;
      dmaAckWriteError  : out sl;
      dmaAckErrorValue  : out slv(1 downto 0);
      dmaAckFirstUser   : out slv(7 downto 0);
      dmaAckLastUser    : out slv(7 downto 0);
      dmaAckDest        : out slv(7 downto 0);
      dmaAckId          : out slv(7 downto 0);
      axiCache          : in  slv(3 downto 0);
      S_AXIS_TVALID     : in  sl;
      S_AXIS_TDATA      : in  slv(63 downto 0);
      S_AXIS_TKEEP      : in  slv(7 downto 0);
      S_AXIS_TLAST      : in  sl;
      S_AXIS_TDEST      : in  slv(7 downto 0);
      S_AXIS_TID        : in  slv(7 downto 0);
      S_AXIS_TUSER      : in  slv(1 downto 0);
      S_AXIS_TREADY     : out sl;
      M_AXI_AWID        : out slv(7 downto 0);
      M_AXI_AWADDR      : out slv(15 downto 0);
      M_AXI_AWLEN       : out slv(7 downto 0);
      M_AXI_AWSIZE      : out slv(2 downto 0);
      M_AXI_AWBURST     : out slv(1 downto 0);
      M_AXI_AWLOCK      : out sl;
      M_AXI_AWCACHE     : out slv(3 downto 0);
      M_AXI_AWPROT      : out slv(2 downto 0);
      M_AXI_AWREGION    : out slv(3 downto 0);
      M_AXI_AWQOS       : out slv(3 downto 0);
      M_AXI_AWVALID     : out sl;
      M_AXI_AWREADY     : in  sl;
      M_AXI_WID         : out slv(7 downto 0);
      M_AXI_WDATA       : out slv(63 downto 0);
      M_AXI_WSTRB       : out slv(7 downto 0);
      M_AXI_WLAST       : out sl;
      M_AXI_WVALID      : out sl;
      M_AXI_WREADY      : in  sl;
      M_AXI_BID         : in  slv(7 downto 0);
      M_AXI_BRESP       : in  slv(1 downto 0);
      M_AXI_BVALID      : in  sl;
      M_AXI_BREADY      : out sl);
end entity AxiStreamDmaWriteIpIntegrator;

architecture rtl of AxiStreamDmaWriteIpIntegrator is

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant AXI_CONFIG_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => 16,
      DATA_BYTES_C => 8,
      ID_BITS_C    => 8,
      LEN_BITS_C   => 8);

   signal axiResetN      : sl := '1';
   signal dmaReq         : AxiWriteDmaReqType := AXI_WRITE_DMA_REQ_INIT_C;
   signal dmaAck         : AxiWriteDmaAckType := AXI_WRITE_DMA_ACK_INIT_C;
   signal axisMaster     : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal axisSlave      : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal axiWriteMaster : AxiWriteMasterType := AXI_WRITE_MASTER_INIT_C;
   signal axiWriteSlave  : AxiWriteSlaveType  := AXI_WRITE_SLAVE_INIT_C;

begin

   ---------------------------------------------------------------------------
   -- Bus shims
   ---------------------------------------------------------------------------
   axiResetN <= not axiRst;

   dmaReq.request <= dmaReqRequest;
   dmaReq.drop    <= dmaReqDrop;
   dmaReq.address <= dmaReqAddress;
   dmaReq.maxSize <= dmaReqMaxSize;
   dmaReq.prot    <= dmaReqProt;

   dmaAckDone       <= dmaAck.done;
   dmaAckIdle       <= dmaAck.idle;
   dmaAckSize       <= dmaAck.size;
   dmaAckOverflow   <= dmaAck.overflow;
   dmaAckWriteError <= dmaAck.writeError;
   dmaAckErrorValue <= dmaAck.errorValue;
   dmaAckFirstUser  <= dmaAck.firstUser;
   dmaAckLastUser   <= dmaAck.lastUser;
   dmaAckDest       <= dmaAck.dest;
   dmaAckId         <= dmaAck.id;

   U_AXIS : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "S_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 2,
         TID_WIDTH       => 8,
         TDEST_WIDTH     => 8,
         TDATA_NUM_BYTES => 8)
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
         axisMaster     => axisMaster,
         axisSlave      => axisSlave);

   U_AXI : entity surf.MasterAxiIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         ID_WIDTH      => 8,
         ADDR_WIDTH    => 16,
         DATA_WIDTH    => 64)
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
         M_AXI_ARID      => open,
         M_AXI_ARADDR    => open,
         M_AXI_ARLEN     => open,
         M_AXI_ARSIZE    => open,
         M_AXI_ARBURST   => open,
         M_AXI_ARLOCK    => open,
         M_AXI_ARCACHE   => open,
         M_AXI_ARPROT    => open,
         M_AXI_ARREGION  => open,
         M_AXI_ARQOS     => open,
         M_AXI_ARVALID   => open,
         M_AXI_ARREADY   => '0',
         M_AXI_RID       => (others => '0'),
         M_AXI_RDATA     => (others => '0'),
         M_AXI_RRESP     => (others => '0'),
         M_AXI_RLAST     => '0',
         M_AXI_RVALID    => '0',
         M_AXI_RREADY    => open,
         axiClk          => open,
         axiRst          => open,
         axiReadMaster   => AXI_READ_MASTER_INIT_C,
         axiReadSlave    => open,
         axiWriteMaster  => axiWriteMaster,
         axiWriteSlave   => axiWriteSlave);

   M_AXI_AWLOCK <= '0';

   ---------------------------------------------------------------------------
   -- DUT
   ---------------------------------------------------------------------------
   U_DUT : entity surf.AxiStreamDmaWrite
      generic map (
         AXI_READY_EN_G => true,
         AXIS_CONFIG_G  => AXIS_CONFIG_C,
         AXI_CONFIG_G   => AXI_CONFIG_C,
         AXI_BURST_G    => "01",
         AXI_CACHE_G    => "1111",
         SW_CACHE_EN_G  => true)
      port map (
         axiClk         => axiClk,
         axiRst         => axiRst,
         dmaReq         => dmaReq,
         dmaAck         => dmaAck,
         swCache        => axiCache,
         axisMaster     => axisMaster,
         axisSlave      => axisSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave,
         axiWriteCtrl   => AXI_CTRL_UNUSED_C);

end architecture rtl;
