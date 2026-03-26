library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity AxiLiteToIpBusIpIntegrator is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';
      RST_ASYNC_G    : boolean := false);
   port (
      axiClk         : in  sl;
      axiRst         : in  sl;
      S_AXI_AWADDR   : in  slv(31 downto 0);
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
      S_AXI_ARADDR   : in  slv(31 downto 0);
      S_AXI_ARPROT   : in  slv(2 downto 0);
      S_AXI_ARVALID  : in  sl;
      S_AXI_ARREADY  : out sl;
      S_AXI_RDATA    : out slv(31 downto 0);
      S_AXI_RRESP    : out slv(1 downto 0);
      S_AXI_RVALID   : out sl;
      S_AXI_RREADY   : in  sl;
      ipbRdata       : in  slv(31 downto 0) := (others => '0');
      ipbAck         : in  sl := '0';
      ipbErr         : in  sl := '0';
      ipbAddr        : out slv(31 downto 0);
      ipbWdata       : out slv(31 downto 0);
      ipbStrobe      : out sl;
      ipbWrite       : out sl);
end entity AxiLiteToIpBusIpIntegrator;

architecture rtl of AxiLiteToIpBusIpIntegrator is

   signal axiResetN       : sl                     := '1';
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

begin

   axiResetN <= not axiRst when (RST_POLARITY_G = '1') else axiRst;

   U_ShimLayerSlave : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 32)
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

   U_DUT : entity surf.AxiLiteToIpBus
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk             => axiClk,
         rst             => axiRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         ipbRdata        => ipbRdata,
         ipbAck          => ipbAck,
         ipbErr          => ipbErr,
         ipbAddr         => ipbAddr,
         ipbWdata        => ipbWdata,
         ipbStrobe       => ipbStrobe,
         ipbWrite        => ipbWrite);

end architecture rtl;
