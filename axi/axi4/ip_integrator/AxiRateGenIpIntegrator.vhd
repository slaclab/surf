library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiPkg.all;
use surf.AxiLitePkg.all;

entity AxiRateGenIpIntegrator is
   generic (
      TPD_G            : time                        := 1 ns;
      COMMON_CLK_G     : boolean                     := true;
      AXI_ADDR_WIDTH_G : positive range 12 to 64    := 16;
      AXI_DATA_WIDTH_G : positive range 32 to 1024  := 32;
      AXI_ID_WIDTH_G   : positive                    := 4);
   port (
      axiClk         : in  sl;
      axiRst         : in  sl;
      axilClk        : in  sl;
      axilRst        : in  sl;
      S_AXIL_AWADDR  : in  slv(7 downto 0);
      S_AXIL_AWPROT  : in  slv(2 downto 0);
      S_AXIL_AWVALID : in  sl;
      S_AXIL_AWREADY : out sl;
      S_AXIL_WDATA   : in  slv(31 downto 0);
      S_AXIL_WSTRB   : in  slv(3 downto 0);
      S_AXIL_WVALID  : in  sl;
      S_AXIL_WREADY  : out sl;
      S_AXIL_BRESP   : out slv(1 downto 0);
      S_AXIL_BVALID  : out sl;
      S_AXIL_BREADY  : in  sl;
      S_AXIL_ARADDR  : in  slv(7 downto 0);
      S_AXIL_ARPROT  : in  slv(2 downto 0);
      S_AXIL_ARVALID : in  sl;
      S_AXIL_ARREADY : out sl;
      S_AXIL_RDATA   : out slv(31 downto 0);
      S_AXIL_RRESP   : out slv(1 downto 0);
      S_AXIL_RVALID  : out sl;
      S_AXIL_RREADY  : in  sl;
      M_AXI_AWID     : out slv(AXI_ID_WIDTH_G-1 downto 0);
      M_AXI_AWADDR   : out slv(AXI_ADDR_WIDTH_G-1 downto 0);
      M_AXI_AWLEN    : out slv(7 downto 0);
      M_AXI_AWSIZE   : out slv(2 downto 0);
      M_AXI_AWBURST  : out slv(1 downto 0);
      M_AXI_AWLOCK   : out sl;
      M_AXI_AWCACHE  : out slv(3 downto 0);
      M_AXI_AWPROT   : out slv(2 downto 0);
      M_AXI_AWREGION : out sl;
      M_AXI_AWQOS    : out slv(3 downto 0);
      M_AXI_AWVALID  : out sl;
      M_AXI_AWREADY  : in  sl;
      M_AXI_WID      : out slv(AXI_ID_WIDTH_G-1 downto 0);
      M_AXI_WDATA    : out slv(AXI_DATA_WIDTH_G-1 downto 0);
      M_AXI_WSTRB    : out slv((AXI_DATA_WIDTH_G/8)-1 downto 0);
      M_AXI_WLAST    : out sl;
      M_AXI_WVALID   : out sl;
      M_AXI_WREADY   : in  sl;
      M_AXI_BID      : in  slv(AXI_ID_WIDTH_G-1 downto 0);
      M_AXI_BRESP    : in  slv(1 downto 0);
      M_AXI_BVALID   : in  sl;
      M_AXI_BREADY   : out sl;
      M_AXI_ARID     : out slv(AXI_ID_WIDTH_G-1 downto 0);
      M_AXI_ARADDR   : out slv(AXI_ADDR_WIDTH_G-1 downto 0);
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
      M_AXI_RID      : in  slv(AXI_ID_WIDTH_G-1 downto 0);
      M_AXI_RDATA    : in  slv(AXI_DATA_WIDTH_G-1 downto 0);
      M_AXI_RRESP    : in  slv(1 downto 0);
      M_AXI_RLAST    : in  sl;
      M_AXI_RVALID   : in  sl;
      M_AXI_RREADY   : out sl);
end entity AxiRateGenIpIntegrator;

architecture rtl of AxiRateGenIpIntegrator is

   constant AXI_CONFIG_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => AXI_ADDR_WIDTH_G,
      DATA_BYTES_C => AXI_DATA_WIDTH_G/8,
      ID_BITS_C    => AXI_ID_WIDTH_G,
      LEN_BITS_C   => 8);

   signal axiResetN       : sl := '1';
   signal axilResetN      : sl := '1';
   signal mAxiAwLock      : slv(1 downto 0)       := (others => '0');
   signal mAxiArLock      : slv(1 downto 0)       := (others => '0');
   signal axilReadMaster  : AxiLiteReadMasterType := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType  := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal axiReadMaster   : AxiReadMasterType     := AXI_READ_MASTER_INIT_C;
   signal axiReadSlave    : AxiReadSlaveType      := AXI_READ_SLAVE_INIT_C;
   signal axiWriteMaster  : AxiWriteMasterType    := AXI_WRITE_MASTER_INIT_C;
   signal axiWriteSlave   : AxiWriteSlaveType     := AXI_WRITE_SLAVE_INIT_C;

begin

   axiResetN  <= not axiRst;
   axilResetN <= not axilRst;
   M_AXI_AWLOCK <= mAxiAwLock(0);
   M_AXI_ARLOCK <= mAxiArLock(0);

   U_S_AXIL : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 8)
      port map (
         S_AXI_ACLK      => axilClk,
         S_AXI_ARESETN   => axilResetN,
         S_AXI_AWADDR    => S_AXIL_AWADDR,
         S_AXI_AWPROT    => S_AXIL_AWPROT,
         S_AXI_AWVALID   => S_AXIL_AWVALID,
         S_AXI_AWREADY   => S_AXIL_AWREADY,
         S_AXI_WDATA     => S_AXIL_WDATA,
         S_AXI_WSTRB     => S_AXIL_WSTRB,
         S_AXI_WVALID    => S_AXIL_WVALID,
         S_AXI_WREADY    => S_AXIL_WREADY,
         S_AXI_BRESP     => S_AXIL_BRESP,
         S_AXI_BVALID    => S_AXIL_BVALID,
         S_AXI_BREADY    => S_AXIL_BREADY,
         S_AXI_ARADDR    => S_AXIL_ARADDR,
         S_AXI_ARPROT    => S_AXIL_ARPROT,
         S_AXI_ARVALID   => S_AXIL_ARVALID,
         S_AXI_ARREADY   => S_AXIL_ARREADY,
         S_AXI_RDATA     => S_AXIL_RDATA,
         S_AXI_RRESP     => S_AXIL_RRESP,
         S_AXI_RVALID    => S_AXIL_RVALID,
         S_AXI_RREADY    => S_AXIL_RREADY,
         axilClk         => open,
         axilRst         => open,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   U_M_AXI : entity surf.MasterAxiIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         ID_WIDTH      => AXI_ID_WIDTH_G,
         ADDR_WIDTH    => AXI_ADDR_WIDTH_G,
         DATA_WIDTH    => AXI_DATA_WIDTH_G)
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

   U_DUT : entity surf.AxiRateGen
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         AXI_CONFIG_G => AXI_CONFIG_C)
      port map (
         axiClk           => axiClk,
         axiRst           => axiRst,
         axiWriteMaster   => axiWriteMaster,
         axiWriteSlave    => axiWriteSlave,
         axiReadMaster    => axiReadMaster,
         axiReadSlave     => axiReadSlave,
         axilClk          => axilClk,
         axilRst          => axilRst,
         sAxilReadMaster  => axilReadMaster,
         sAxilReadSlave   => axilReadSlave,
         sAxilWriteMaster => axilWriteMaster,
         sAxilWriteSlave  => axilWriteSlave);

end architecture rtl;
