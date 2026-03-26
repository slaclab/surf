library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity IpBusToAxiLiteIpIntegrator is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';
      RST_ASYNC_G    : boolean := false);
   port (
      axiClk         : in  sl;
      axiRst         : in  sl;
      ipbAddr        : in  slv(31 downto 0) := (others => '0');
      ipbWdata       : in  slv(31 downto 0) := (others => '0');
      ipbStrobe      : in  sl := '0';
      ipbWrite       : in  sl := '0';
      ipbRdata       : out slv(31 downto 0);
      ipbAck         : out sl;
      ipbErr         : out sl;
      M_AXI_AWADDR   : out slv(31 downto 0);
      M_AXI_AWPROT   : out slv(2 downto 0);
      M_AXI_AWVALID  : out sl;
      M_AXI_AWREADY  : in  sl;
      M_AXI_WDATA    : out slv(31 downto 0);
      M_AXI_WSTRB    : out slv(3 downto 0);
      M_AXI_WVALID   : out sl;
      M_AXI_WREADY   : in  sl;
      M_AXI_BRESP    : in  slv(1 downto 0);
      M_AXI_BVALID   : in  sl;
      M_AXI_BREADY   : out sl;
      M_AXI_ARADDR   : out slv(31 downto 0);
      M_AXI_ARPROT   : out slv(2 downto 0);
      M_AXI_ARVALID  : out sl;
      M_AXI_ARREADY  : in  sl;
      M_AXI_RDATA    : in  slv(31 downto 0);
      M_AXI_RRESP    : in  slv(1 downto 0);
      M_AXI_RVALID   : in  sl;
      M_AXI_RREADY   : out sl);
end entity IpBusToAxiLiteIpIntegrator;

architecture rtl of IpBusToAxiLiteIpIntegrator is

   signal axiResetN       : sl                     := '1';
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

begin

   axiResetN <= not axiRst when (RST_POLARITY_G = '1') else axiRst;

   U_MasterShimLayer : entity surf.MasterAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 32)
      port map (
         M_AXI_ACLK      => axiClk,
         M_AXI_ARESETN   => axiResetN,
         M_AXI_AWADDR    => M_AXI_AWADDR,
         M_AXI_AWPROT    => M_AXI_AWPROT,
         M_AXI_AWVALID   => M_AXI_AWVALID,
         M_AXI_AWREADY   => M_AXI_AWREADY,
         M_AXI_WDATA     => M_AXI_WDATA,
         M_AXI_WSTRB     => M_AXI_WSTRB,
         M_AXI_WVALID    => M_AXI_WVALID,
         M_AXI_WREADY    => M_AXI_WREADY,
         M_AXI_BRESP     => M_AXI_BRESP,
         M_AXI_BVALID    => M_AXI_BVALID,
         M_AXI_BREADY    => M_AXI_BREADY,
         M_AXI_ARADDR    => M_AXI_ARADDR,
         M_AXI_ARPROT    => M_AXI_ARPROT,
         M_AXI_ARVALID   => M_AXI_ARVALID,
         M_AXI_ARREADY   => M_AXI_ARREADY,
         M_AXI_RDATA     => M_AXI_RDATA,
         M_AXI_RRESP     => M_AXI_RRESP,
         M_AXI_RVALID    => M_AXI_RVALID,
         M_AXI_RREADY    => M_AXI_RREADY,
         axilClk         => open,
         axilRst         => open,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   U_DUT : entity surf.IpBusToAxiLite
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk             => axiClk,
         rst             => axiRst,
         ipbAddr         => ipbAddr,
         ipbWdata        => ipbWdata,
         ipbStrobe       => ipbStrobe,
         ipbWrite        => ipbWrite,
         ipbRdata        => ipbRdata,
         ipbAck          => ipbAck,
         ipbErr          => ipbErr,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

end architecture rtl;
