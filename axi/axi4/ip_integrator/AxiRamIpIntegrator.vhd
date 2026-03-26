library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiPkg.all;

entity AxiRamIpIntegrator is
   generic (
      TPD_G          : time                      := 1 ns;
      SYNTH_MODE_G   : string                    := "inferred";
      MEMORY_TYPE_G  : string                    := "block";
      READ_LATENCY_G : natural range 0 to 2      := 2;
      ADDR_WIDTH_G   : positive range 1 to 64    := 16;
      DATA_WIDTH_G   : positive range 32 to 1024 := 64;
      ID_WIDTH_G     : positive                  := 4);
   port (
      axiClk         : in  sl;
      axiRst         : in  sl;
      S_AXI_AWID     : in  slv(ID_WIDTH_G-1 downto 0);
      S_AXI_AWADDR   : in  slv(ADDR_WIDTH_G-1 downto 0);
      S_AXI_AWLEN    : in  slv(7 downto 0);
      S_AXI_AWSIZE   : in  slv(2 downto 0);
      S_AXI_AWBURST  : in  slv(1 downto 0);
      S_AXI_AWLOCK   : in  sl;
      S_AXI_AWCACHE  : in  slv(3 downto 0);
      S_AXI_AWPROT   : in  slv(2 downto 0);
      S_AXI_AWREGION : in  slv(3 downto 0);
      S_AXI_AWQOS    : in  slv(3 downto 0);
      S_AXI_AWVALID  : in  sl;
      S_AXI_AWREADY  : out sl;
      S_AXI_WID      : in  slv(ID_WIDTH_G-1 downto 0);
      S_AXI_WDATA    : in  slv(DATA_WIDTH_G-1 downto 0);
      S_AXI_WSTRB    : in  slv((DATA_WIDTH_G/8)-1 downto 0);
      S_AXI_WLAST    : in  sl;
      S_AXI_WVALID   : in  sl;
      S_AXI_WREADY   : out sl;
      S_AXI_BID      : out slv(ID_WIDTH_G-1 downto 0);
      S_AXI_BRESP    : out slv(1 downto 0);
      S_AXI_BVALID   : out sl;
      S_AXI_BREADY   : in  sl;
      S_AXI_ARID     : in  slv(ID_WIDTH_G-1 downto 0);
      S_AXI_ARADDR   : in  slv(ADDR_WIDTH_G-1 downto 0);
      S_AXI_ARLEN    : in  slv(7 downto 0);
      S_AXI_ARSIZE   : in  slv(2 downto 0);
      S_AXI_ARBURST  : in  slv(1 downto 0);
      S_AXI_ARLOCK   : in  sl;
      S_AXI_ARCACHE  : in  slv(3 downto 0);
      S_AXI_ARPROT   : in  slv(2 downto 0);
      S_AXI_ARREGION : in  slv(3 downto 0);
      S_AXI_ARQOS    : in  slv(3 downto 0);
      S_AXI_ARVALID  : in  sl;
      S_AXI_ARREADY  : out sl;
      S_AXI_RID      : out slv(ID_WIDTH_G-1 downto 0);
      S_AXI_RDATA    : out slv(DATA_WIDTH_G-1 downto 0);
      S_AXI_RRESP    : out slv(1 downto 0);
      S_AXI_RLAST    : out sl;
      S_AXI_RVALID   : out sl;
      S_AXI_RREADY   : in  sl);
end entity AxiRamIpIntegrator;

architecture rtl of AxiRamIpIntegrator is

   constant AXI_CONFIG_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => ADDR_WIDTH_G,
      DATA_BYTES_C => DATA_WIDTH_G/8,
      ID_BITS_C    => ID_WIDTH_G,
      LEN_BITS_C   => 8);

   signal axiResetN      : sl := '1';
   signal sAxiArLock     : slv(1 downto 0) := (others => '0');
   signal sAxiAwLock     : slv(1 downto 0) := (others => '0');
   signal axiReadMaster  : AxiReadMasterType := AXI_READ_MASTER_INIT_C;
   signal axiReadSlave   : AxiReadSlaveType  := AXI_READ_SLAVE_INIT_C;
   signal axiWriteMaster : AxiWriteMasterType := AXI_WRITE_MASTER_INIT_C;
   signal axiWriteSlave  : AxiWriteSlaveType  := AXI_WRITE_SLAVE_INIT_C;

begin

   axiResetN <= not axiRst;
   sAxiArLock <= '0' & S_AXI_ARLOCK;
   sAxiAwLock <= '0' & S_AXI_AWLOCK;

   U_S : entity surf.SlaveAxiIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         ID_WIDTH      => ID_WIDTH_G,
         ADDR_WIDTH    => ADDR_WIDTH_G,
         DATA_WIDTH    => DATA_WIDTH_G)
      port map (
         S_AXI_ACLK      => axiClk,
         S_AXI_ARESETN   => axiResetN,
         S_AXI_AWID      => S_AXI_AWID,
         S_AXI_AWADDR    => S_AXI_AWADDR,
         S_AXI_AWLEN     => S_AXI_AWLEN,
         S_AXI_AWSIZE    => S_AXI_AWSIZE,
         S_AXI_AWBURST   => S_AXI_AWBURST,
         S_AXI_AWLOCK    => sAxiAwLock,
         S_AXI_AWCACHE   => S_AXI_AWCACHE,
         S_AXI_AWPROT    => S_AXI_AWPROT,
         S_AXI_AWREGION  => S_AXI_AWREGION,
         S_AXI_AWQOS     => S_AXI_AWQOS,
         S_AXI_AWVALID   => S_AXI_AWVALID,
         S_AXI_AWREADY   => S_AXI_AWREADY,
         S_AXI_WID       => S_AXI_WID,
         S_AXI_WDATA     => S_AXI_WDATA,
         S_AXI_WSTRB     => S_AXI_WSTRB,
         S_AXI_WLAST     => S_AXI_WLAST,
         S_AXI_WVALID    => S_AXI_WVALID,
         S_AXI_WREADY    => S_AXI_WREADY,
         S_AXI_BID       => S_AXI_BID,
         S_AXI_BRESP     => S_AXI_BRESP,
         S_AXI_BVALID    => S_AXI_BVALID,
         S_AXI_BREADY    => S_AXI_BREADY,
         S_AXI_ARID      => S_AXI_ARID,
         S_AXI_ARADDR    => S_AXI_ARADDR,
         S_AXI_ARLEN     => S_AXI_ARLEN,
         S_AXI_ARSIZE    => S_AXI_ARSIZE,
         S_AXI_ARBURST   => S_AXI_ARBURST,
         S_AXI_ARLOCK    => sAxiArLock,
         S_AXI_ARCACHE   => S_AXI_ARCACHE,
         S_AXI_ARPROT    => S_AXI_ARPROT,
         S_AXI_ARREGION  => S_AXI_ARREGION,
         S_AXI_ARQOS     => S_AXI_ARQOS,
         S_AXI_ARVALID   => S_AXI_ARVALID,
         S_AXI_ARREADY   => S_AXI_ARREADY,
         S_AXI_RID       => S_AXI_RID,
         S_AXI_RDATA     => S_AXI_RDATA,
         S_AXI_RRESP     => S_AXI_RRESP,
         S_AXI_RLAST     => S_AXI_RLAST,
         S_AXI_RVALID    => S_AXI_RVALID,
         S_AXI_RREADY    => S_AXI_RREADY,
         axiClk          => open,
         axiRst          => open,
         axiReadMaster   => axiReadMaster,
         axiReadSlave    => axiReadSlave,
         axiWriteMaster  => axiWriteMaster,
         axiWriteSlave   => axiWriteSlave);

   U_DUT : entity surf.AxiRam
      generic map (
         TPD_G          => TPD_G,
         SYNTH_MODE_G   => SYNTH_MODE_G,
         MEMORY_TYPE_G  => MEMORY_TYPE_G,
         READ_LATENCY_G => READ_LATENCY_G,
         AXI_CONFIG_G   => AXI_CONFIG_C)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         sAxiWriteMaster => axiWriteMaster,
         sAxiWriteSlave  => axiWriteSlave,
         sAxiReadMaster  => axiReadMaster,
         sAxiReadSlave   => axiReadSlave);

end architecture rtl;
