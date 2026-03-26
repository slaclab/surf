library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity AxiLiteToDrpIpIntegrator is
   generic (
      TPD_G            : time                   := 1 ns;
      RST_POLARITY_G   : sl                     := '1';
      RST_ASYNC_G      : boolean                := false;
      COMMON_CLK_G     : boolean                := false;
      EN_ARBITRATION_G : boolean                := false;
      TIMEOUT_G        : positive               := 4096;
      ADDR_WIDTH_G     : positive range 1 to 32 := 16;
      DATA_WIDTH_G     : positive range 1 to 32 := 16);
   port (
      axilClk       : in  sl;
      axilRst       : in  sl;
      drpClk        : in  sl;
      drpRst        : in  sl;
      S_AXI_AWADDR  : in  slv(ADDR_WIDTH_G+1 downto 0);
      S_AXI_AWPROT  : in  slv(2 downto 0);
      S_AXI_AWVALID : in  sl;
      S_AXI_AWREADY : out sl;
      S_AXI_WDATA   : in  slv(31 downto 0);
      S_AXI_WSTRB   : in  slv(3 downto 0);
      S_AXI_WVALID  : in  sl;
      S_AXI_WREADY  : out sl;
      S_AXI_BRESP   : out slv(1 downto 0);
      S_AXI_BVALID  : out sl;
      S_AXI_BREADY  : in  sl;
      S_AXI_ARADDR  : in  slv(ADDR_WIDTH_G+1 downto 0);
      S_AXI_ARPROT  : in  slv(2 downto 0);
      S_AXI_ARVALID : in  sl;
      S_AXI_ARREADY : out sl;
      S_AXI_RDATA   : out slv(31 downto 0);
      S_AXI_RRESP   : out slv(1 downto 0);
      S_AXI_RVALID  : out sl;
      S_AXI_RREADY  : in  sl;
      drpGnt        : in  sl := '1';
      drpReq        : out sl;
      drpRdy        : in  sl := '0';
      drpEn         : out sl;
      drpWe         : out sl;
      drpUsrRst     : out sl;
      drpAddr       : out slv(ADDR_WIDTH_G-1 downto 0);
      drpDi         : out slv(DATA_WIDTH_G-1 downto 0);
      drpDo         : in  slv(DATA_WIDTH_G-1 downto 0) := (others => '0'));
end entity AxiLiteToDrpIpIntegrator;

architecture rtl of AxiLiteToDrpIpIntegrator is

   signal sAxiAResetN : sl := '1';

   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

begin

   sAxiAResetN <= not axilRst when (RST_POLARITY_G = '1') else axilRst;

   U_SlaveShim : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         INTERFACENAME => "S_AXI",
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => ADDR_WIDTH_G + 2)
      port map (
         S_AXI_ACLK      => axilClk,
         S_AXI_ARESETN   => sAxiAResetN,
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

   U_DUT : entity surf.AxiLiteToDrp
      generic map (
         TPD_G            => TPD_G,
         RST_POLARITY_G   => RST_POLARITY_G,
         RST_ASYNC_G      => RST_ASYNC_G,
         COMMON_CLK_G     => COMMON_CLK_G,
         EN_ARBITRATION_G => EN_ARBITRATION_G,
         TIMEOUT_G        => TIMEOUT_G,
         ADDR_WIDTH_G     => ADDR_WIDTH_G,
         DATA_WIDTH_G     => DATA_WIDTH_G)
      port map (
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         drpClk          => drpClk,
         drpRst          => drpRst,
         drpGnt          => drpGnt,
         drpReq          => drpReq,
         drpRdy          => drpRdy,
         drpEn           => drpEn,
         drpWe           => drpWe,
         drpUsrRst       => drpUsrRst,
         drpAddr         => drpAddr,
         drpDi           => drpDi,
         drpDo           => drpDo);

end architecture rtl;
