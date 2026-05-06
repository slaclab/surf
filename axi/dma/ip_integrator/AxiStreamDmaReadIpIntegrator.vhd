-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP integrator wrapper for surf.AxiStreamDmaRead
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

entity AxiStreamDmaReadIpIntegrator is
   generic (
      TPD_G           : time     := 1 ns;
      AXIS_READY_EN_G : boolean  := true;
      PIPE_STAGES_G   : natural  := 1;
      PEND_THRESH_G   : natural  := 0;
      BYP_SHIFT_G     : boolean  := false;
      DATA_BYTES_G    : positive := 8);
   port (
      axiClk            : in  sl;
      axiRst            : in  sl;
      dmaReqRequest     : in  sl               := '0';
      dmaReqAddress     : in  slv(63 downto 0) := (others => '0');
      dmaReqSize        : in  slv(31 downto 0) := (others => '0');
      dmaReqFirstUser   : in  slv(7 downto 0)  := (others => '0');
      dmaReqLastUser    : in  slv(7 downto 0)  := (others => '0');
      dmaReqDest        : in  slv(7 downto 0)  := (others => '0');
      dmaReqId          : in  slv(7 downto 0)  := (others => '0');
      dmaReqProt        : in  slv(2 downto 0)  := (others => '0');
      dmaAckIdle        : out sl;
      dmaAckDone        : out sl;
      dmaAckReadError   : out sl;
      dmaAckErrorValue  : out slv(1 downto 0);
      axisCtrlPause     : in  sl               := '0';
      axisCtrlOverflow  : in  sl               := '0';
      M_AXIS_TVALID     : out sl;
      M_AXIS_TDATA      : out slv(DATA_BYTES_G*8-1 downto 0);
      M_AXIS_TKEEP      : out slv(DATA_BYTES_G-1 downto 0);
      M_AXIS_TLAST      : out sl;
      M_AXIS_TDEST      : out slv(7 downto 0);
      M_AXIS_TID        : out slv(7 downto 0);
      M_AXIS_TUSER      : out slv(7 downto 0);
      M_AXIS_FIRST_USER : out slv(7 downto 0);
      M_AXIS_LAST_USER  : out slv(7 downto 0);
      M_AXIS_TREADY     : in  sl               := '0';
      M_AXI_ARID        : out slv(7 downto 0);
      M_AXI_ARADDR      : out slv(15 downto 0);
      M_AXI_ARLEN       : out slv(7 downto 0);
      M_AXI_ARSIZE      : out slv(2 downto 0);
      M_AXI_ARBURST     : out slv(1 downto 0);
      M_AXI_ARLOCK      : out sl;
      M_AXI_ARCACHE     : out slv(3 downto 0);
      M_AXI_ARPROT      : out slv(2 downto 0);
      M_AXI_ARREGION    : out slv(3 downto 0);
      M_AXI_ARQOS       : out slv(3 downto 0);
      M_AXI_ARVALID     : out sl;
      M_AXI_ARREADY     : in  sl;
      M_AXI_RID         : in  slv(7 downto 0);
      M_AXI_RDATA       : in  slv(DATA_BYTES_G*8-1 downto 0);
      M_AXI_RRESP       : in  slv(1 downto 0);
      M_AXI_RLAST       : in  sl;
      M_AXI_RVALID      : in  sl;
      M_AXI_RREADY      : out sl);
end entity AxiStreamDmaReadIpIntegrator;

architecture rtl of AxiStreamDmaReadIpIntegrator is

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => DATA_BYTES_G,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 8,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant AXI_CONFIG_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => 16,
      DATA_BYTES_C => DATA_BYTES_G,
      ID_BITS_C    => 8,
      LEN_BITS_C   => 8);

   signal axisAResetN   : sl                  := '1';
   signal dmaReq        : AxiReadDmaReqType   := AXI_READ_DMA_REQ_INIT_C;
   signal dmaAck        : AxiReadDmaAckType   := AXI_READ_DMA_ACK_INIT_C;
   signal axisMaster    : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal axisSlave     : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal axisCtrl      : AxiStreamCtrlType   := AXI_STREAM_CTRL_UNUSED_C;
   signal axiReadMaster : AxiReadMasterType   := AXI_READ_MASTER_INIT_C;
   signal axiReadSlave  : AxiReadSlaveType    := AXI_READ_SLAVE_INIT_C;

begin

   axisAResetN <= not axiRst;

   dmaReq.request    <= dmaReqRequest;
   dmaReq.address    <= dmaReqAddress;
   dmaReq.size       <= dmaReqSize;
   dmaReq.firstUser  <= dmaReqFirstUser;
   dmaReq.lastUser   <= dmaReqLastUser;
   dmaReq.dest       <= dmaReqDest;
   dmaReq.id         <= dmaReqId;
   dmaReq.prot       <= dmaReqProt;
   dmaAckIdle        <= dmaAck.idle;
   dmaAckDone        <= dmaAck.done;
   dmaAckReadError   <= dmaAck.readError;
   dmaAckErrorValue  <= dmaAck.errorValue;
   axisCtrl.pause    <= axisCtrlPause;
   axisCtrl.overflow <= axisCtrlOverflow;
   M_AXIS_FIRST_USER <= axiStreamGetUserField(AXIS_CONFIG_C, axisMaster, 0);
   M_AXIS_LAST_USER  <= axiStreamGetUserField(AXIS_CONFIG_C, axisMaster, -1);

   U_StreamMaster : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 8,
         TID_WIDTH       => 8,
         TDEST_WIDTH     => 8,
         TDATA_NUM_BYTES => DATA_BYTES_G)
      port map (
         M_AXIS_ACLK    => axiClk,
         M_AXIS_ARESETN => axisAResetN,
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

   U_AxiReadMaster : entity surf.MasterAxiIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         ID_WIDTH      => 8,
         ADDR_WIDTH    => 16,
         DATA_WIDTH    => DATA_BYTES_G*8)
      port map (
         M_AXI_ACLK     => axiClk,
         M_AXI_ARESETN  => axisAResetN,
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
         M_AXI_ARCACHE  => M_AXI_ARCACHE,
         M_AXI_ARPROT   => M_AXI_ARPROT,
         M_AXI_ARREGION => M_AXI_ARREGION,
         M_AXI_ARQOS    => M_AXI_ARQOS,
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
         axiWriteMaster => AXI_WRITE_MASTER_INIT_C,
         axiWriteSlave  => open);

   M_AXI_ARLOCK <= '0';

   U_DUT : entity surf.AxiStreamDmaRead
      generic map (
         TPD_G           => TPD_G,
         AXIS_READY_EN_G => AXIS_READY_EN_G,
         AXIS_CONFIG_G   => AXIS_CONFIG_C,
         AXI_CONFIG_G    => AXI_CONFIG_C,
         AXI_BURST_G     => "01",
         AXI_CACHE_G     => "1111",
         SW_CACHE_EN_G   => false,
         PIPE_STAGES_G   => PIPE_STAGES_G,
         PEND_THRESH_G   => PEND_THRESH_G,
         BYP_SHIFT_G     => BYP_SHIFT_G)
      port map (
         axiClk        => axiClk,
         axiRst        => axiRst,
         dmaReq        => dmaReq,
         dmaAck        => dmaAck,
         swCache       => (others => '0'),
         axisMaster    => axisMaster,
         axisSlave     => axisSlave,
         axisCtrl      => axisCtrl,
         axiReadMaster => axiReadMaster,
         axiReadSlave  => axiReadSlave);

end architecture rtl;
