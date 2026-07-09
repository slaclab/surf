-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP integrator wrapper for surf.AxiStreamDmaV2Write
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

entity AxiStreamDmaV2WriteIpIntegrator is
   generic (
      TPD_G             : time                    := 1 ns;
      AXI_READY_EN_G    : boolean                 := false;
      PIPE_STAGES_G     : natural                 := 1;
      BURST_BYTES_G     : integer range 1 to 4096 := 16;
      ACK_WAIT_BVALID_G : boolean                 := false;
      DATA_BYTES_G      : positive                := 4);
   port (
      axiClk                 : in  sl;
      axiRst                 : in  sl;
      dmaWrDescReqValid      : out sl;
      dmaWrDescReqId         : out slv(7 downto 0);
      dmaWrDescReqDest       : out slv(7 downto 0);
      dmaWrDescAckValid      : in  sl                             := '0';
      dmaWrDescAckAddress    : in  slv(63 downto 0)               := (others => '0');
      dmaWrDescAckMetaEnable : in  sl                             := '0';
      dmaWrDescAckMetaAddr   : in  slv(63 downto 0)               := (others => '0');
      dmaWrDescAckDropEn     : in  sl                             := '0';
      dmaWrDescAckMaxSize    : in  slv(31 downto 0)               := (others => '0');
      dmaWrDescAckContEn     : in  sl                             := '0';
      dmaWrDescAckBuffId     : in  slv(31 downto 0)               := (others => '0');
      dmaWrDescAckTimeout    : in  slv(31 downto 0)               := (others => '0');
      dmaWrDescRetValid      : out sl;
      dmaWrDescRetBuffId     : out slv(31 downto 0);
      dmaWrDescRetFirstUser  : out slv(7 downto 0);
      dmaWrDescRetLastUser   : out slv(7 downto 0);
      dmaWrDescRetSize       : out slv(31 downto 0);
      dmaWrDescRetContinue   : out sl;
      dmaWrDescRetResult     : out slv(3 downto 0);
      dmaWrDescRetDest       : out slv(7 downto 0);
      dmaWrDescRetId         : out slv(7 downto 0);
      dmaWrDescRetAck        : in  sl                             := '0';
      dmaWrIdle              : out sl;
      axiCache               : in  slv(3 downto 0)                := (others => '0');
      M_AXIS_TVALID          : in  sl                             := '0';
      M_AXIS_TDATA           : in  slv(DATA_BYTES_G*8-1 downto 0) := (others => '0');
      M_AXIS_TKEEP           : in  slv(DATA_BYTES_G-1 downto 0)   := (others => '0');
      M_AXIS_TLAST           : in  sl                             := '0';
      M_AXIS_TDEST           : in  slv(7 downto 0)                := (others => '0');
      M_AXIS_TID             : in  slv(7 downto 0)                := (others => '0');
      M_AXIS_TUSER           : in  slv(1 downto 0)                := (others => '0');
      M_AXIS_TREADY          : out sl;
      M_AXI_AWID             : out slv(7 downto 0);
      M_AXI_AWADDR           : out slv(15 downto 0);
      M_AXI_AWLEN            : out slv(7 downto 0);
      M_AXI_AWSIZE           : out slv(2 downto 0);
      M_AXI_AWBURST          : out slv(1 downto 0);
      M_AXI_AWLOCK           : out sl;
      M_AXI_AWCACHE          : out slv(3 downto 0);
      M_AXI_AWPROT           : out slv(2 downto 0);
      M_AXI_AWREGION         : out slv(3 downto 0);
      M_AXI_AWQOS            : out slv(3 downto 0);
      M_AXI_AWVALID          : out sl;
      M_AXI_AWREADY          : in  sl;
      M_AXI_WID              : out slv(7 downto 0);
      M_AXI_WDATA            : out slv(DATA_BYTES_G*8-1 downto 0);
      M_AXI_WSTRB            : out slv(DATA_BYTES_G-1 downto 0);
      M_AXI_WLAST            : out sl;
      M_AXI_WVALID           : out sl;
      M_AXI_WREADY           : in  sl;
      M_AXI_BID              : in  slv(7 downto 0);
      M_AXI_BRESP            : in  slv(1 downto 0);
      M_AXI_BVALID           : in  sl;
      M_AXI_BREADY           : out sl;
      axiWriteCtrlPause      : in  sl                             := '0';
      axiWriteCtrlOver       : in  sl                             := '0');
end entity AxiStreamDmaV2WriteIpIntegrator;

architecture rtl of AxiStreamDmaV2WriteIpIntegrator is

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => DATA_BYTES_G,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant AXI_CONFIG_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => 16,
      DATA_BYTES_C => DATA_BYTES_G,
      ID_BITS_C    => 8,
      LEN_BITS_C   => 8);

   signal axisAResetN    : sl                     := '1';
   signal dmaWrDescReq   : AxiWriteDmaDescReqType := AXI_WRITE_DMA_DESC_REQ_INIT_C;
   signal dmaWrDescAck   : AxiWriteDmaDescAckType := AXI_WRITE_DMA_DESC_ACK_INIT_C;
   signal dmaWrDescRet   : AxiWriteDmaDescRetType := AXI_WRITE_DMA_DESC_RET_INIT_C;
   signal axisMaster     : AxiStreamMasterType    := AXI_STREAM_MASTER_INIT_C;
   signal axisSlave      : AxiStreamSlaveType     := AXI_STREAM_SLAVE_INIT_C;
   signal axiWriteMaster : AxiWriteMasterType     := AXI_WRITE_MASTER_INIT_C;
   signal axiWriteSlave  : AxiWriteSlaveType      := AXI_WRITE_SLAVE_INIT_C;
   signal axiWriteCtrl   : AxiCtrlType            := AXI_CTRL_UNUSED_C;

begin

   axisAResetN <= not axiRst;

   dmaWrDescReqValid       <= dmaWrDescReq.valid;
   dmaWrDescReqId          <= dmaWrDescReq.id;
   dmaWrDescReqDest        <= dmaWrDescReq.dest;
   dmaWrDescAck.valid      <= dmaWrDescAckValid;
   dmaWrDescAck.address    <= dmaWrDescAckAddress;
   dmaWrDescAck.metaEnable <= dmaWrDescAckMetaEnable;
   dmaWrDescAck.metaAddr   <= dmaWrDescAckMetaAddr;
   dmaWrDescAck.dropEn     <= dmaWrDescAckDropEn;
   dmaWrDescAck.maxSize    <= dmaWrDescAckMaxSize;
   dmaWrDescAck.contEn     <= dmaWrDescAckContEn;
   dmaWrDescAck.buffId     <= dmaWrDescAckBuffId;
   dmaWrDescAck.timeout    <= dmaWrDescAckTimeout;
   dmaWrDescRetValid       <= dmaWrDescRet.valid;
   dmaWrDescRetBuffId      <= dmaWrDescRet.buffId;
   dmaWrDescRetFirstUser   <= dmaWrDescRet.firstUser;
   dmaWrDescRetLastUser    <= dmaWrDescRet.lastUser;
   dmaWrDescRetSize        <= dmaWrDescRet.size;
   dmaWrDescRetContinue    <= dmaWrDescRet.continue;
   dmaWrDescRetResult      <= dmaWrDescRet.result;
   dmaWrDescRetDest        <= dmaWrDescRet.dest;
   dmaWrDescRetId          <= dmaWrDescRet.id;
   axiWriteCtrl.pause      <= axiWriteCtrlPause;
   axiWriteCtrl.overflow   <= axiWriteCtrlOver;

   U_StreamSlave : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 2,
         TID_WIDTH       => 8,
         TDEST_WIDTH     => 8,
         TDATA_NUM_BYTES => DATA_BYTES_G)
      port map (
         S_AXIS_ACLK    => axiClk,
         S_AXIS_ARESETN => axisAResetN,
         S_AXIS_TVALID  => M_AXIS_TVALID,
         S_AXIS_TDATA   => M_AXIS_TDATA,
         S_AXIS_TSTRB   => (others => '0'),
         S_AXIS_TKEEP   => M_AXIS_TKEEP,
         S_AXIS_TLAST   => M_AXIS_TLAST,
         S_AXIS_TDEST   => M_AXIS_TDEST,
         S_AXIS_TID     => M_AXIS_TID,
         S_AXIS_TUSER   => M_AXIS_TUSER,
         S_AXIS_TREADY  => M_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => axisMaster,
         axisSlave      => axisSlave);

   U_AxiWriteMaster : entity surf.MasterAxiIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         ID_WIDTH      => 8,
         ADDR_WIDTH    => 16,
         DATA_WIDTH    => DATA_BYTES_G*8)
      port map (
         M_AXI_ACLK     => axiClk,
         M_AXI_ARESETN  => axisAResetN,
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
         axiReadMaster  => AXI_READ_MASTER_INIT_C,
         axiReadSlave   => open,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave);

   M_AXI_AWLOCK <= '0';

   U_DUT : entity surf.AxiStreamDmaV2Write
      generic map (
         TPD_G             => TPD_G,
         AXI_READY_EN_G    => AXI_READY_EN_G,
         AXIS_CONFIG_G     => AXIS_CONFIG_C,
         AXI_CONFIG_G      => AXI_CONFIG_C,
         PIPE_STAGES_G     => PIPE_STAGES_G,
         BURST_BYTES_G     => BURST_BYTES_G,
         ACK_WAIT_BVALID_G => ACK_WAIT_BVALID_G)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         dmaWrDescReq    => dmaWrDescReq,
         dmaWrDescAck    => dmaWrDescAck,
         dmaWrDescRet    => dmaWrDescRet,
         dmaWrDescRetAck => dmaWrDescRetAck,
         dmaWrIdle       => dmaWrIdle,
         axiCache        => axiCache,
         axisMaster      => axisMaster,
         axisSlave       => axisSlave,
         axiWriteMaster  => axiWriteMaster,
         axiWriteSlave   => axiWriteSlave,
         axiWriteCtrl    => axiWriteCtrl);

end architecture rtl;
