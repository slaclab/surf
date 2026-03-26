library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity AxiLiteAsyncIpIntegrator is
   generic (
      TPD_G            : time                  := 1 ns;
      RST_POLARITY_G   : sl                    := '1';
      RST_ASYNC_G      : boolean               := false;
      AXI_ERROR_RESP_G : slv(1 downto 0)       := AXI_RESP_SLVERR_C;
      COMMON_CLK_G     : boolean               := false;
      NUM_ADDR_BITS_G  : natural               := 32;
      PIPE_STAGES_G    : integer range 0 to 16 := 0);
   port (
      sAxiClk       : in  sl;
      sAxiClkRst    : in  sl;
      mAxiClk       : in  sl;
      mAxiClkRst    : in  sl;
      S_AXI_AWADDR  : in  slv(NUM_ADDR_BITS_G-1 downto 0);
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
      S_AXI_ARADDR  : in  slv(NUM_ADDR_BITS_G-1 downto 0);
      S_AXI_ARPROT  : in  slv(2 downto 0);
      S_AXI_ARVALID : in  sl;
      S_AXI_ARREADY : out sl;
      S_AXI_RDATA   : out slv(31 downto 0);
      S_AXI_RRESP   : out slv(1 downto 0);
      S_AXI_RVALID  : out sl;
      S_AXI_RREADY  : in  sl;
      M_AXI_AWADDR  : out slv(NUM_ADDR_BITS_G-1 downto 0);
      M_AXI_AWPROT  : out slv(2 downto 0);
      M_AXI_AWVALID : out sl;
      M_AXI_AWREADY : in  sl;
      M_AXI_WDATA   : out slv(31 downto 0);
      M_AXI_WSTRB   : out slv(3 downto 0);
      M_AXI_WVALID  : out sl;
      M_AXI_WREADY  : in  sl;
      M_AXI_BRESP   : in  slv(1 downto 0);
      M_AXI_BVALID  : in  sl;
      M_AXI_BREADY  : out sl;
      M_AXI_ARADDR  : out slv(NUM_ADDR_BITS_G-1 downto 0);
      M_AXI_ARPROT  : out slv(2 downto 0);
      M_AXI_ARVALID : out sl;
      M_AXI_ARREADY : in  sl;
      M_AXI_RDATA   : in  slv(31 downto 0);
      M_AXI_RRESP   : in  slv(1 downto 0);
      M_AXI_RVALID  : in  sl;
      M_AXI_RREADY  : out sl);
end entity AxiLiteAsyncIpIntegrator;

architecture rtl of AxiLiteAsyncIpIntegrator is

   signal sAxiAResetN : sl := '1';
   signal mAxiAResetN : sl := '1';

   signal sAxiReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal sAxiReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal sAxiWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal sAxiWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

   signal mAxiReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal mAxiReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal mAxiWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal mAxiWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

begin

   sAxiAResetN <= not sAxiClkRst when (RST_POLARITY_G = '1') else sAxiClkRst;
   mAxiAResetN <= not mAxiClkRst when (RST_POLARITY_G = '1') else mAxiClkRst;

   U_SlaveShim : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         INTERFACENAME => "S_AXI",
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => NUM_ADDR_BITS_G)
      port map (
         S_AXI_ACLK      => sAxiClk,
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
         axilReadMaster  => sAxiReadMaster,
         axilReadSlave   => sAxiReadSlave,
         axilWriteMaster => sAxiWriteMaster,
         axilWriteSlave  => sAxiWriteSlave);

   U_MasterShim : entity surf.MasterAxiLiteIpIntegrator
      generic map (
         INTERFACENAME => "M_AXI",
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => NUM_ADDR_BITS_G)
      port map (
         M_AXI_ACLK      => mAxiClk,
         M_AXI_ARESETN   => mAxiAResetN,
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
         axilReadMaster  => mAxiReadMaster,
         axilReadSlave   => mAxiReadSlave,
         axilWriteMaster => mAxiWriteMaster,
         axilWriteSlave  => mAxiWriteSlave);

   U_DUT : entity surf.AxiLiteAsync
      generic map (
         TPD_G            => TPD_G,
         RST_POLARITY_G   => RST_POLARITY_G,
         RST_ASYNC_G      => RST_ASYNC_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
         COMMON_CLK_G     => COMMON_CLK_G,
         NUM_ADDR_BITS_G  => NUM_ADDR_BITS_G,
         PIPE_STAGES_G    => PIPE_STAGES_G)
      port map (
         sAxiClk         => sAxiClk,
         sAxiClkRst      => sAxiClkRst,
         sAxiReadMaster  => sAxiReadMaster,
         sAxiReadSlave   => sAxiReadSlave,
         sAxiWriteMaster => sAxiWriteMaster,
         sAxiWriteSlave  => sAxiWriteSlave,
         mAxiClk         => mAxiClk,
         mAxiClkRst      => mAxiClkRst,
         mAxiReadMaster  => mAxiReadMaster,
         mAxiReadSlave   => mAxiReadSlave,
         mAxiWriteMaster => mAxiWriteMaster,
         mAxiWriteSlave  => mAxiWriteSlave);

end architecture rtl;
