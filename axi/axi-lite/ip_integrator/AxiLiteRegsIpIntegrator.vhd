library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity AxiLiteRegsIpIntegrator is
   generic (
      TPD_G           : time                  := 1 ns;
      RST_POLARITY_G  : sl                    := '1';
      RST_ASYNC_G     : boolean               := false;
      NUM_WRITE_REG_G : integer range 1 to 32 := 1;
      NUM_READ_REG_G  : integer range 1 to 32 := 1);
   port (
      axilClk          : in  sl;
      axilRst          : in  sl;
      S_AXI_AWADDR     : in  slv(8 downto 0);
      S_AXI_AWPROT     : in  slv(2 downto 0);
      S_AXI_AWVALID    : in  sl;
      S_AXI_AWREADY    : out sl;
      S_AXI_WDATA      : in  slv(31 downto 0);
      S_AXI_WSTRB      : in  slv(3 downto 0);
      S_AXI_WVALID     : in  sl;
      S_AXI_WREADY     : out sl;
      S_AXI_BRESP      : out slv(1 downto 0);
      S_AXI_BVALID     : out sl;
      S_AXI_BREADY     : in  sl;
      S_AXI_ARADDR     : in  slv(8 downto 0);
      S_AXI_ARPROT     : in  slv(2 downto 0);
      S_AXI_ARVALID    : in  sl;
      S_AXI_ARREADY    : out sl;
      S_AXI_RDATA      : out slv(31 downto 0);
      S_AXI_RRESP      : out slv(1 downto 0);
      S_AXI_RVALID     : out sl;
      S_AXI_RREADY     : in  sl;
      writeRegisterOut : out slv((NUM_WRITE_REG_G*32)-1 downto 0);
      readRegisterIn   : in  slv((NUM_READ_REG_G*32)-1 downto 0) := (others => '0'));
end entity AxiLiteRegsIpIntegrator;

architecture rtl of AxiLiteRegsIpIntegrator is

   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal sAxiAResetN     : sl                     := '1';

   signal writeRegister : Slv32Array(NUM_WRITE_REG_G-1 downto 0);
   signal readRegister  : Slv32Array(NUM_READ_REG_G-1 downto 0);

begin

   sAxiAResetN <= not axilRst when (RST_POLARITY_G = '1') else axilRst;

   U_ShimLayer : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 9)
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

   GEN_READ_REG : for i in 0 to NUM_READ_REG_G-1 generate
      readRegister(i) <= readRegisterIn((i*32)+31 downto i*32);
   end generate;

   GEN_WRITE_REG : for i in 0 to NUM_WRITE_REG_G-1 generate
      writeRegisterOut((i*32)+31 downto i*32) <= writeRegister(i);
   end generate;

   U_DUT : entity surf.AxiLiteRegs
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         NUM_WRITE_REG_G => NUM_WRITE_REG_G,
         NUM_READ_REG_G  => NUM_READ_REG_G)
      port map (
         axiClk         => axilClk,
         axiClkRst      => axilRst,
         axiReadMaster  => axilReadMaster,
         axiReadSlave   => axilReadSlave,
         axiWriteMaster => axilWriteMaster,
         axiWriteSlave  => axilWriteSlave,
         writeRegister  => writeRegister,
         readRegister   => readRegister);

end architecture rtl;
