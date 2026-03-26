library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiPkg.all;
use surf.AxiDmaPkg.all;
use surf.AxiStreamPkg.all;

entity AxiStreamDmaV2ReadIpIntegrator is
   generic (
      TPD_G           : time                     := 1 ns;
      AXIS_READY_EN_G : boolean                  := false;
      PIPE_STAGES_G   : natural                  := 1;
      BURST_BYTES_G   : positive range 1 to 4096 := 16;
      PEND_THRESH_G   : positive                 := 1;
      DATA_BYTES_G    : positive                 := 4);
   port (
      axiClk                : in  sl;
      axiRst                : in  sl;
      dmaRdDescReqValid     : in  sl               := '0';
      dmaRdDescReqAddress   : in  slv(63 downto 0) := (others => '0');
      dmaRdDescReqBuffId    : in  slv(31 downto 0) := (others => '0');
      dmaRdDescReqFirstUser : in  slv(7 downto 0)  := (others => '0');
      dmaRdDescReqLastUser  : in  slv(7 downto 0)  := (others => '0');
      dmaRdDescReqSize      : in  slv(31 downto 0) := (others => '0');
      dmaRdDescReqContinue  : in  sl               := '0';
      dmaRdDescReqId        : in  slv(7 downto 0)  := (others => '0');
      dmaRdDescReqDest      : in  slv(7 downto 0)  := (others => '0');
      dmaRdDescAck          : out sl;
      dmaRdDescRetValid     : out sl;
      dmaRdDescRetBuffId    : out slv(31 downto 0);
      dmaRdDescRetResult    : out slv(2 downto 0);
      dmaRdDescRetAck       : in  sl               := '0';
      dmaRdIdle             : out sl;
      axiCache              : in  slv(3 downto 0)  := (others => '0');
      axisCtrlPause         : in  sl               := '0';
      axisCtrlOverflow      : in  sl               := '0';
      M_AXIS_TVALID         : out sl;
      M_AXIS_TDATA          : out slv(DATA_BYTES_G*8-1 downto 0);
      M_AXIS_TKEEP          : out slv(DATA_BYTES_G-1 downto 0);
      M_AXIS_TLAST          : out sl;
      M_AXIS_TDEST          : out slv(7 downto 0);
      M_AXIS_TID            : out slv(7 downto 0);
      M_AXIS_TUSER          : out slv(7 downto 0);
      M_AXIS_TREADY         : in  sl               := '0';
      M_AXI_ARID            : out slv(7 downto 0);
      M_AXI_ARADDR          : out slv(15 downto 0);
      M_AXI_ARLEN           : out slv(7 downto 0);
      M_AXI_ARSIZE          : out slv(2 downto 0);
      M_AXI_ARBURST         : out slv(1 downto 0);
      M_AXI_ARLOCK          : out sl;
      M_AXI_ARCACHE         : out slv(3 downto 0);
      M_AXI_ARPROT          : out slv(2 downto 0);
      M_AXI_ARREGION        : out slv(3 downto 0);
      M_AXI_ARQOS           : out slv(3 downto 0);
      M_AXI_ARVALID         : out sl;
      M_AXI_ARREADY         : in  sl;
      M_AXI_RID             : in  slv(7 downto 0);
      M_AXI_RDATA           : in  slv(DATA_BYTES_G*8-1 downto 0);
      M_AXI_RRESP           : in  slv(1 downto 0);
      M_AXI_RLAST           : in  sl;
      M_AXI_RVALID          : in  sl;
      M_AXI_RREADY          : out sl);
end entity AxiStreamDmaV2ReadIpIntegrator;

architecture rtl of AxiStreamDmaV2ReadIpIntegrator is

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

   signal axisAResetN  : sl := '1';
   signal dmaRdDescReq : AxiReadDmaDescReqType := AXI_READ_DMA_DESC_REQ_INIT_C;
   signal dmaRdDescRet : AxiReadDmaDescRetType := AXI_READ_DMA_DESC_RET_INIT_C;
   signal axisMaster   : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal axisSlave    : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal axisCtrl     : AxiStreamCtrlType   := AXI_STREAM_CTRL_UNUSED_C;
   signal axiReadMaster : AxiReadMasterType := AXI_READ_MASTER_INIT_C;
   signal axiReadSlave  : AxiReadSlaveType  := AXI_READ_SLAVE_INIT_C;

begin

   axisAResetN <= not axiRst;

   dmaRdDescReq.valid     <= dmaRdDescReqValid;
   dmaRdDescReq.address   <= dmaRdDescReqAddress;
   dmaRdDescReq.buffId    <= dmaRdDescReqBuffId;
   dmaRdDescReq.firstUser <= dmaRdDescReqFirstUser;
   dmaRdDescReq.lastUser  <= dmaRdDescReqLastUser;
   dmaRdDescReq.size      <= dmaRdDescReqSize;
   dmaRdDescReq.continue  <= dmaRdDescReqContinue;
   dmaRdDescReq.id        <= dmaRdDescReqId;
   dmaRdDescReq.dest      <= dmaRdDescReqDest;
   dmaRdDescRetValid      <= dmaRdDescRet.valid;
   dmaRdDescRetBuffId     <= dmaRdDescRet.buffId;
   dmaRdDescRetResult     <= dmaRdDescRet.result;
   axisCtrl.pause         <= axisCtrlPause;
   axisCtrl.overflow      <= axisCtrlOverflow;

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
         M_AXI_ACLK      => axiClk,
         M_AXI_ARESETN   => axisAResetN,
         M_AXI_AWID      => open,
         M_AXI_AWADDR    => open,
         M_AXI_AWLEN     => open,
         M_AXI_AWSIZE    => open,
         M_AXI_AWBURST   => open,
         M_AXI_AWLOCK    => open,
         M_AXI_AWCACHE   => open,
         M_AXI_AWPROT    => open,
         M_AXI_AWREGION  => open,
         M_AXI_AWQOS     => open,
         M_AXI_AWVALID   => open,
         M_AXI_AWREADY   => '0',
         M_AXI_WID       => open,
         M_AXI_WDATA     => open,
         M_AXI_WSTRB     => open,
         M_AXI_WLAST     => open,
         M_AXI_WVALID    => open,
         M_AXI_WREADY    => '0',
         M_AXI_BID       => (others => '0'),
         M_AXI_BRESP     => (others => '0'),
         M_AXI_BVALID    => '0',
         M_AXI_BREADY    => open,
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
         axiWriteMaster  => AXI_WRITE_MASTER_INIT_C,
         axiWriteSlave   => open);

   M_AXI_ARLOCK <= '0';

   U_DUT : entity surf.AxiStreamDmaV2Read
      generic map (
         TPD_G           => TPD_G,
         AXIS_READY_EN_G => AXIS_READY_EN_G,
         AXIS_CONFIG_G   => AXIS_CONFIG_C,
         AXI_CONFIG_G    => AXI_CONFIG_C,
         PIPE_STAGES_G   => PIPE_STAGES_G,
         BURST_BYTES_G   => BURST_BYTES_G,
         PEND_THRESH_G   => PEND_THRESH_G)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         dmaRdDescReq    => dmaRdDescReq,
         dmaRdDescAck    => dmaRdDescAck,
         dmaRdDescRet    => dmaRdDescRet,
         dmaRdDescRetAck => dmaRdDescRetAck,
         dmaRdIdle       => dmaRdIdle,
         axiCache        => axiCache,
         axisMaster      => axisMaster,
         axisSlave       => axisSlave,
         axisCtrl        => axisCtrl,
         axiReadMaster   => axiReadMaster,
         axiReadSlave    => axiReadSlave);

end architecture rtl;
