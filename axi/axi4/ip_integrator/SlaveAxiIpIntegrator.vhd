-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Common shim layer between IP Integrator interface and surf AXI interface
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiPkg.all;

entity SlaveAxiIpIntegrator is
   generic (
      INTERFACENAME         : string                    := "S_AXI";
      EN_ERROR_RESP         : boolean                   := false;
      MAX_BURST_LENGTH      : positive range 1 to 256   := 256;  -- [1, 256]
      NUM_WRITE_OUTSTANDING : natural range 0 to 32     := 1;   -- [0, 32]
      NUM_READ_OUTSTANDING  : natural range 0 to 32     := 1;   -- [0, 32]
      SUPPORTS_NARROW_BURST : natural range 0 to 1      := 1;
--      BUSER_WIDTH           : positive                  := 1;
--      RUSER_WIDTH           : positive                  := 1;
--      WUSER_WIDTH           : positive                  := 1;
--      ARUSER_WIDTH          : positive                  := 1;
--      AWUSER_WIDTH          : positive                  := 1;
      ADDR_WIDTH            : positive range 1 to 64    := 32;  -- [1, 64]
      ID_WIDTH              : positive                  := 1;
      DATA_WIDTH            : positive range 32 to 1024 := 32;  -- [32,64,128,256,512,1024]
      HAS_BURST             : natural range 0 to 1      := 1;
      HAS_CACHE             : natural range 0 to 1      := 1;
      HAS_LOCK              : natural range 0 to 1      := 1;
      HAS_PROT              : natural range 0 to 1      := 1;
      HAS_QOS               : natural range 0 to 1      := 1;
      HAS_REGION            : natural range 0 to 1      := 1;
      HAS_WSTRB             : natural range 0 to 1      := 1;
      HAS_BRESP             : natural range 0 to 1      := 1;
      HAS_RRESP             : natural range 0 to 1      := 1);
   port (
      -- IP Integrator AXI-Lite Interface
      S_AXI_ACLK     : in  std_logic;
      S_AXI_ARESETN  : in  std_logic;
      S_AXI_AWID     : in  std_logic_vector(ID_WIDTH-1 downto 0);
      S_AXI_AWADDR   : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      S_AXI_AWLEN    : in  std_logic_vector(7 downto 0);
      S_AXI_AWSIZE   : in  std_logic_vector(2 downto 0);
      S_AXI_AWBURST  : in  std_logic_vector(1 downto 0);
      S_AXI_AWLOCK   : in  std_logic_vector(1 downto 0);
      S_AXI_AWCACHE  : in  std_logic_vector(3 downto 0);
      S_AXI_AWPROT   : in  std_logic_vector(2 downto 0);
      S_AXI_AWREGION : in  std_logic_vector(3 downto 0);
      S_AXI_AWQOS    : in  std_logic_vector(3 downto 0);
--      S_AXI_AWUSER   : in  std_logic_vector(AWUSER_WIDTH-1 downto 0);
      S_AXI_AWVALID  : in  std_logic;
      S_AXI_AWREADY  : out std_logic;
      S_AXI_WID      : in  std_logic_vector(ID_WIDTH-1 downto 0);
      S_AXI_WDATA    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      S_AXI_WSTRB    : in  std_logic_vector((DATA_WIDTH/8)-1 downto 0);
      S_AXI_WLAST    : in  std_logic;
--      S_AXI_WUSER    : in  std_logic_vector(WUSER_WIDTH-1 downto 0);
      S_AXI_WVALID   : in  std_logic;
      S_AXI_WREADY   : out std_logic;
      S_AXI_BID      : out std_logic_vector(ID_WIDTH-1 downto 0);
      S_AXI_BRESP    : out std_logic_vector(1 downto 0);
--      S_AXI_BUSER    : out std_logic_vector(BUSER_WIDTH downto 0);
      S_AXI_BVALID   : out std_logic;
      S_AXI_BREADY   : in  std_logic;
      S_AXI_ARID     : in  std_logic_vector(ID_WIDTH-1 downto 0);
      S_AXI_ARADDR   : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      S_AXI_ARLEN    : in  std_logic_vector(7 downto 0);
      S_AXI_ARSIZE   : in  std_logic_vector(2 downto 0);
      S_AXI_ARBURST  : in  std_logic_vector(1 downto 0);
      S_AXI_ARLOCK   : in  std_logic_vector(1 downto 0);
      S_AXI_ARCACHE  : in  std_logic_vector(3 downto 0);
      S_AXI_ARPROT   : in  std_logic_vector(2 downto 0);
      S_AXI_ARREGION : in  std_logic_vector(3 downto 0);
      S_AXI_ARQOS    : in  std_logic_vector(3 downto 0);
--      S_AXI_ARUSER   : in  std_logic_vector(ARUSER_WIDTH-1 downto 0);
      S_AXI_ARVALID  : in  std_logic;
      S_AXI_ARREADY  : out std_logic;
      S_AXI_RID      : out std_logic_vector(ID_WIDTH-1 downto 0);
      S_AXI_RDATA    : out std_logic_vector(DATA_WIDTH-1 downto 0);
      S_AXI_RRESP    : out std_logic_vector(1 downto 0);
      S_AXI_RLAST    : out std_logic;
--      S_AXI_RUSER    : out std_logic_vector(RUSER_WIDTH-1 downto 0);
      S_AXI_RVALID   : out std_logic;
      S_AXI_RREADY   : in  std_logic;
      -- SURF AXI Interface
      axiClk         : out sl;
      axiRst         : out sl;
      axiReadMaster  : out AxiReadMasterType;
      axiReadSlave   : in  AxiReadSlaveType;
      axiWriteMaster : out AxiWriteMasterType;
      axiWriteSlave  : in  AxiWriteSlaveType);
end SlaveAxiIpIntegrator;

architecture mapping of SlaveAxiIpIntegrator is

   attribute X_INTERFACE_INFO      : string;
   attribute X_INTERFACE_PARAMETER : string;

   attribute X_INTERFACE_INFO of S_AXI_AWID        : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWID";
   attribute X_INTERFACE_INFO of S_AXI_AWADDR      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWADDR";
   attribute X_INTERFACE_INFO of S_AXI_AWLEN       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWLEN";
   attribute X_INTERFACE_INFO of S_AXI_AWSIZE      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWSIZE";
   attribute X_INTERFACE_INFO of S_AXI_AWBURST     : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWBURST";
   attribute X_INTERFACE_INFO of S_AXI_AWLOCK      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWLOCK";
   attribute X_INTERFACE_INFO of S_AXI_AWCACHE     : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWCACHE";
   attribute X_INTERFACE_INFO of S_AXI_AWPROT      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWPROT";
   attribute X_INTERFACE_INFO of S_AXI_AWREGION    : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWREGION";
   attribute X_INTERFACE_INFO of S_AXI_AWQOS       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWQOS";
--   attribute X_INTERFACE_INFO of S_AXI_AWUSER      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWUSER";
   attribute X_INTERFACE_INFO of S_AXI_AWVALID     : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWVALID";
   attribute X_INTERFACE_INFO of S_AXI_AWREADY     : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWREADY";
   attribute X_INTERFACE_INFO of S_AXI_WID         : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WID";
   attribute X_INTERFACE_INFO of S_AXI_WDATA       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WDATA";
   attribute X_INTERFACE_INFO of S_AXI_WSTRB       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WSTRB";
   attribute X_INTERFACE_INFO of S_AXI_WLAST       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WLAST";
--   attribute X_INTERFACE_INFO of S_AXI_WUSER       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WUSER";
   attribute X_INTERFACE_INFO of S_AXI_WVALID      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WVALID";
   attribute X_INTERFACE_INFO of S_AXI_WREADY      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WREADY";
   attribute X_INTERFACE_INFO of S_AXI_BID         : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " BID";
   attribute X_INTERFACE_INFO of S_AXI_BRESP       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " BRESP";
--   attribute X_INTERFACE_INFO of S_AXI_BUSER       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " BUSER";
   attribute X_INTERFACE_INFO of S_AXI_BVALID      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " BVALID";
   attribute X_INTERFACE_INFO of S_AXI_BREADY      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " BREADY";
   attribute X_INTERFACE_INFO of S_AXI_ARID        : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARID";
   attribute X_INTERFACE_INFO of S_AXI_ARADDR      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARADDR";
   attribute X_INTERFACE_INFO of S_AXI_ARLEN       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARLEN";
   attribute X_INTERFACE_INFO of S_AXI_ARSIZE      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARSIZE";
   attribute X_INTERFACE_INFO of S_AXI_ARBURST     : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARBURST";
   attribute X_INTERFACE_INFO of S_AXI_ARLOCK      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARLOCK";
   attribute X_INTERFACE_INFO of S_AXI_ARCACHE     : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARCACHE";
   attribute X_INTERFACE_INFO of S_AXI_ARPROT      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARPROT";
   attribute X_INTERFACE_INFO of S_AXI_ARREGION    : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARREGION";
   attribute X_INTERFACE_INFO of S_AXI_ARQOS       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARQOS";
--   attribute X_INTERFACE_INFO of S_AXI_ARUSER      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARUSER";
   attribute X_INTERFACE_INFO of S_AXI_ARVALID     : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARVALID";
   attribute X_INTERFACE_INFO of S_AXI_ARREADY     : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARREADY";
   attribute X_INTERFACE_INFO of S_AXI_RID         : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RID";
   attribute X_INTERFACE_INFO of S_AXI_RDATA       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RDATA";
   attribute X_INTERFACE_INFO of S_AXI_RRESP       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RRESP";
   attribute X_INTERFACE_INFO of S_AXI_RLAST       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RLAST";
--   attribute X_INTERFACE_INFO of S_AXI_RUSER       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RUSER";
   attribute X_INTERFACE_INFO of S_AXI_RVALID      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RVALID";
   attribute X_INTERFACE_INFO of S_AXI_RREADY      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RREADY";
   attribute X_INTERFACE_PARAMETER of S_AXI_AWADDR : signal is
      "XIL_INTERFACENAME " & INTERFACENAME & ", " &
      "PROTOCOL AXI4, " &
      "MAX_BURST_LENGTH " & integer'image(MAX_BURST_LENGTH) & ", " &
      "NUM_WRITE_OUTSTANDING " & integer'image(NUM_WRITE_OUTSTANDING) & ", " &
      "NUM_READ_OUTSTANDING " & integer'image(NUM_READ_OUTSTANDING) & ", " &
      "SUPPORTS_NARROW_BURST " & integer'image(SUPPORTS_NARROW_BURST) & ", " &
--      "BUSER_WIDTH " & integer'image(BUSER_WIDTH) & ", " &
--      "RUSER_WIDTH " & integer'image(RUSER_WIDTH) & ", " &
--      "WUSER_WIDTH " & integer'image(WUSER_WIDTH) & ", " &
--      "ARUSER_WIDTH " & integer'image(ARUSER_WIDTH) & ", " &
--      "AWUSER_WIDTH " & integer'image(AWUSER_WIDTH) & ", " &
      "ADDR_WIDTH " & integer'image(ADDR_WIDTH) & ", " &
      "ID_WIDTH " & integer'image(ID_WIDTH) & ", " &
      "DATA_WIDTH " & integer'image(DATA_WIDTH) & ", " &
      "HAS_BURST " & integer'image(HAS_BURST) & ", " &
      "HAS_CACHE " & integer'image(HAS_CACHE) & ", " &
      "HAS_LOCK " & integer'image(HAS_LOCK) & ", " &
      "HAS_PROT " & integer'image(HAS_PROT) & ", " &
      "HAS_QOS " & integer'image(HAS_QOS) & ", " &
      "HAS_REGION " & integer'image(HAS_REGION) & ", " &
      "HAS_WSTRB " & integer'image(HAS_WSTRB) & ", " &
      "HAS_BRESP " & integer'image(HAS_BRESP) & ", " &
      "HAS_RRESP " & integer'image(HAS_RRESP);

   attribute X_INTERFACE_INFO of S_AXI_ARESETN      : signal is "xilinx.com:signal:reset:1.0 RST." & INTERFACENAME & "_ARESETN RST";
   attribute X_INTERFACE_PARAMETER of S_AXI_ARESETN : signal is
      "XIL_INTERFACENAME RST." & INTERFACENAME & "_ARESETN, " &
      "POLARITY ACTIVE_LOW";

   attribute X_INTERFACE_INFO of S_AXI_ACLK      : signal is "xilinx.com:signal:clock:1.0 CLK." & INTERFACENAME & "_ACLK CLK";
   attribute X_INTERFACE_PARAMETER of S_AXI_ACLK : signal is
      "XIL_INTERFACENAME CLK." & INTERFACENAME & "_ACLK, " &
      "ASSOCIATED_BUSIF " & INTERFACENAME & ", " &
      "ASSOCIATED_RESET " & INTERFACENAME & "_ARESETN";

   signal S_AXI_ReadMaster  : AxiReadMasterType  := AXI_READ_MASTER_INIT_C;
   signal S_AXI_ReadSlave   : AxiReadSlaveType   := AXI_READ_SLAVE_INIT_C;
   signal S_AXI_WriteMaster : AxiWriteMasterType := AXI_WRITE_MASTER_INIT_C;
   signal S_AXI_WriteSlave  : AxiWriteSlaveType  := AXI_WRITE_SLAVE_INIT_C;

begin

   axiClk <= S_AXI_ACLK;

   axiReadMaster   <= S_AXI_ReadMaster;
   S_AXI_ReadSlave <= axiReadSlave;

   axiWriteMaster   <= S_AXI_WriteMaster;
   S_AXI_WriteSlave <= axiWriteSlave;

   U_RstSync : entity surf.RstSync
      generic map (
         IN_POLARITY_G  => '0',
         OUT_POLARITY_G => '1')
      port map (
         clk      => S_AXI_ACLK,
         asyncRst => S_AXI_ARESETN,
         syncRst  => axiRst);

   S_AXI_WriteMaster.awid(ID_WIDTH-1 downto 0)        <= S_AXI_AWID;
   S_AXI_WriteMaster.awaddr(ADDR_WIDTH-1 downto 0)    <= S_AXI_AWADDR;
   S_AXI_WriteMaster.awlen(7 downto 0)                <= S_AXI_AWLEN;
   S_AXI_WriteMaster.awsize(2 downto 0)               <= S_AXI_AWSIZE;
   S_AXI_WriteMaster.awburst(1 downto 0)              <= S_AXI_AWBURST;
   S_AXI_WriteMaster.awlock(1 downto 0)               <= S_AXI_AWLOCK;
   S_AXI_WriteMaster.awcache(3 downto 0)              <= S_AXI_AWCACHE;
   S_AXI_WriteMaster.awprot                           <= S_AXI_AWPROT;
   S_AXI_WriteMaster.awregion(3 downto 0)             <= S_AXI_AWREGION;
   S_AXI_WriteMaster.awqos(3 downto 0)                <= S_AXI_AWQOS;
--   S_AXI_WriteMaster.awuser(AWUSER_WIDTH-1 downto 0)  <= S_AXI_AWUSER;
   S_AXI_WriteMaster.awvalid                          <= S_AXI_AWVALID;
   S_AXI_WriteMaster.wid(ID_WIDTH-1 downto 0)         <= S_AXI_WID;
   S_AXI_WriteMaster.wdata(DATA_WIDTH-1 downto 0)     <= S_AXI_WDATA;
   S_AXI_WriteMaster.wstrb((DATA_WIDTH/8)-1 downto 0) <= S_AXI_WSTRB when(HAS_WSTRB /= 0) else (others => '1');
   S_AXI_WriteMaster.wlast                            <= S_AXI_WLAST;
--   S_AXI_WriteMaster.wuser(WUSER_WIDTH-1 downto 0)    <= S_AXI_WUSER;
   S_AXI_WriteMaster.wvalid                           <= S_AXI_WVALID;
   S_AXI_WriteMaster.bready                           <= S_AXI_BREADY;

   S_AXI_AWREADY <= S_AXI_WriteSlave.awready;
   S_AXI_WREADY  <= S_AXI_WriteSlave.wready;
   S_AXI_BID     <= S_AXI_WriteSlave.bid(ID_WIDTH-1 downto 0);
   S_AXI_BRESP   <= S_AXI_WriteSlave.bresp when(EN_ERROR_RESP and (HAS_BRESP /= 0)) else "00";
--   S_AXI_BUSER   <= S_AXI_WriteSlave.buser(BUSER_WIDTH-1 downto 0);
   S_AXI_BVALID  <= S_AXI_WriteSlave.bvalid;

   S_AXI_ReadMaster.arid(ID_WIDTH-1 downto 0)     <= S_AXI_ARID;
   S_AXI_ReadMaster.araddr(ADDR_WIDTH-1 downto 0) <= S_AXI_ARADDR;
   S_AXI_ReadMaster.arlen                         <= S_AXI_ARLEN;
   S_AXI_ReadMaster.arsize                        <= S_AXI_ARSIZE;
   S_AXI_ReadMaster.arburst                       <= S_AXI_ARBURST;
   S_AXI_ReadMaster.arlock                        <= S_AXI_ARLOCK;
   S_AXI_ReadMaster.arcache                       <= S_AXI_ARCACHE;
   S_AXI_ReadMaster.arprot                        <= S_AXI_ARPROT;
   S_AXI_ReadMaster.arregion(3 downto 0)          <= S_AXI_ARREGION;
   S_AXI_ReadMaster.arqos(3 downto 0)             <= S_AXI_ARQOS;
--   S_AXI_ReadMaster.aruser(ARUSER_WIDTH-1 downto 0) <= S_AXI_ARUSER;
   S_AXI_ReadMaster.arvalid                       <= S_AXI_ARVALID;
   S_AXI_ReadMaster.rready                        <= S_AXI_RREADY;

   S_AXI_ARREADY <= S_AXI_ReadSlave.arready;
   S_AXI_RID     <= S_AXI_ReadSlave.rid(ID_WIDTH-1 downto 0);
   S_AXI_RDATA   <= S_AXI_ReadSlave.rdata(DATA_WIDTH-1 downto 0);
   S_AXI_RRESP   <= S_AXI_ReadSlave.rresp when(EN_ERROR_RESP and (HAS_RRESP /= 0)) else "00";
   S_AXI_RLAST   <= S_AXI_ReadSlave.rlast;
--   S_AXI_RUSER   <= S_AXI_ReadSlave.ruser(RUSER_WIDTH-1 downto 0);
   S_AXI_RVALID  <= S_AXI_ReadSlave.rvalid;

end mapping;
