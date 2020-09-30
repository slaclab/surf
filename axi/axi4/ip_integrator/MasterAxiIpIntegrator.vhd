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

entity MasterAxiIpIntegrator is
   generic (
      INTERFACENAME         : string                    := "M_AXI";
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
      M_AXI_ACLK     : in  std_logic;
      M_AXI_ARESETN  : in  std_logic;
      M_AXI_AWID     : out std_logic_vector(ID_WIDTH-1 downto 0);
      M_AXI_AWADDR   : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      M_AXI_AWLEN    : out std_logic_vector(7 downto 0);
      M_AXI_AWSIZE   : out std_logic_vector(2 downto 0);
      M_AXI_AWBURST  : out std_logic_vector(1 downto 0);
      M_AXI_AWLOCK   : out std_logic_vector(1 downto 0);
      M_AXI_AWCACHE  : out std_logic_vector(3 downto 0);
      M_AXI_AWPROT   : out std_logic_vector(2 downto 0);
      M_AXI_AWREGION : out std_logic_vector(3 downto 0);
      M_AXI_AWQOS    : out std_logic_vector(3 downto 0);
--      M_AXI_AWUSER   : out std_logic_vector(AWUSER_WIDTH-1 downto 0);
      M_AXI_AWVALID  : out std_logic;
      M_AXI_AWREADY  : in  std_logic;
      M_AXI_WID      : out std_logic_vector(ID_WIDTH-1 downto 0);
      M_AXI_WDATA    : out std_logic_vector(DATA_WIDTH-1 downto 0);
      M_AXI_WSTRB    : out std_logic_vector((DATA_WIDTH/8)-1 downto 0);
      M_AXI_WLAST    : out std_logic;
--      M_AXI_WUSER    : out std_logic_vector(WUSER_WIDTH-1 downto 0);
      M_AXI_WVALID   : out std_logic;
      M_AXI_WREADY   : in  std_logic;
      M_AXI_BID      : in  std_logic_vector(ID_WIDTH-1 downto 0);
      M_AXI_BRESP    : in  std_logic_vector(1 downto 0);
--      M_AXI_BUSER    : in  std_logic_vector(BUSER_WIDTH downto 0);
      M_AXI_BVALID   : in  std_logic;
      M_AXI_BREADY   : out std_logic;
      M_AXI_ARID     : out std_logic_vector(ID_WIDTH-1 downto 0);
      M_AXI_ARADDR   : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      M_AXI_ARLEN    : out std_logic_vector(7 downto 0);
      M_AXI_ARSIZE   : out std_logic_vector(2 downto 0);
      M_AXI_ARBURST  : out std_logic_vector(1 downto 0);
      M_AXI_ARLOCK   : out std_logic_vector(1 downto 0);
      M_AXI_ARCACHE  : out std_logic_vector(3 downto 0);
      M_AXI_ARPROT   : out std_logic_vector(2 downto 0);
      M_AXI_ARREGION : out std_logic_vector(3 downto 0);
      M_AXI_ARQOS    : out std_logic_vector(3 downto 0);
--      M_AXI_ARUSER   : out std_logic_vector(ARUSER_WIDTH-1 downto 0);
      M_AXI_ARVALID  : out std_logic;
      M_AXI_ARREADY  : in  std_logic;
      M_AXI_RID      : in  std_logic_vector(ID_WIDTH-1 downto 0);
      M_AXI_RDATA    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      M_AXI_RRESP    : in  std_logic_vector(1 downto 0);
      M_AXI_RLAST    : in  std_logic;
--      M_AXI_RUSER    : in  std_logic_vector(RUSER_WIDTH-1 downto 0);
      M_AXI_RVALID   : in  std_logic;
      M_AXI_RREADY   : out std_logic;
      -- SURF AXI Interface
      axiClk         : out sl;
      axiRst         : out sl;
      axiReadMaster  : in  AxiReadMasterType;
      axiReadSlave   : out AxiReadSlaveType;
      axiWriteMaster : in  AxiWriteMasterType;
      axiWriteSlave  : out AxiWriteSlaveType);
end MasterAxiIpIntegrator;

architecture mapping of MasterAxiIpIntegrator is

   attribute X_INTERFACE_INFO      : string;
   attribute X_INTERFACE_PARAMETER : string;

   attribute X_INTERFACE_INFO of M_AXI_AWID        : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWID";
   attribute X_INTERFACE_INFO of M_AXI_AWADDR      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWADDR";
   attribute X_INTERFACE_INFO of M_AXI_AWLEN       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWLEN";
   attribute X_INTERFACE_INFO of M_AXI_AWSIZE      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWSIZE";
   attribute X_INTERFACE_INFO of M_AXI_AWBURST     : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWBURST";
   attribute X_INTERFACE_INFO of M_AXI_AWLOCK      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWLOCK";
   attribute X_INTERFACE_INFO of M_AXI_AWCACHE     : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWCACHE";
   attribute X_INTERFACE_INFO of M_AXI_AWPROT      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWPROT";
   attribute X_INTERFACE_INFO of M_AXI_AWREGION    : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWREGION";
   attribute X_INTERFACE_INFO of M_AXI_AWQOS       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWQOS";
--   attribute X_INTERFACE_INFO of M_AXI_AWUSER      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWUSER";
   attribute X_INTERFACE_INFO of M_AXI_AWVALID     : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWVALID";
   attribute X_INTERFACE_INFO of M_AXI_AWREADY     : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWREADY";
   attribute X_INTERFACE_INFO of M_AXI_WID         : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WID";
   attribute X_INTERFACE_INFO of M_AXI_WDATA       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WDATA";
   attribute X_INTERFACE_INFO of M_AXI_WSTRB       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WSTRB";
   attribute X_INTERFACE_INFO of M_AXI_WLAST       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WLAST";
--   attribute X_INTERFACE_INFO of M_AXI_WUSER       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WUSER";
   attribute X_INTERFACE_INFO of M_AXI_WVALID      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WVALID";
   attribute X_INTERFACE_INFO of M_AXI_WREADY      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WREADY";
   attribute X_INTERFACE_INFO of M_AXI_BID         : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " BID";
   attribute X_INTERFACE_INFO of M_AXI_BRESP       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " BRESP";
--   attribute X_INTERFACE_INFO of M_AXI_BUSER       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " BUSER";
   attribute X_INTERFACE_INFO of M_AXI_BVALID      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " BVALID";
   attribute X_INTERFACE_INFO of M_AXI_BREADY      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " BREADY";
   attribute X_INTERFACE_INFO of M_AXI_ARID        : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARID";
   attribute X_INTERFACE_INFO of M_AXI_ARADDR      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARADDR";
   attribute X_INTERFACE_INFO of M_AXI_ARLEN       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARLEN";
   attribute X_INTERFACE_INFO of M_AXI_ARSIZE      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARSIZE";
   attribute X_INTERFACE_INFO of M_AXI_ARBURST     : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARBURST";
   attribute X_INTERFACE_INFO of M_AXI_ARLOCK      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARLOCK";
   attribute X_INTERFACE_INFO of M_AXI_ARCACHE     : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARCACHE";
   attribute X_INTERFACE_INFO of M_AXI_ARPROT      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARPROT";
   attribute X_INTERFACE_INFO of M_AXI_ARREGION    : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARREGION";
   attribute X_INTERFACE_INFO of M_AXI_ARQOS       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARQOS";
--   attribute X_INTERFACE_INFO of M_AXI_ARUSER      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARUSER";
   attribute X_INTERFACE_INFO of M_AXI_ARVALID     : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARVALID";
   attribute X_INTERFACE_INFO of M_AXI_ARREADY     : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARREADY";
   attribute X_INTERFACE_INFO of M_AXI_RID         : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RID";
   attribute X_INTERFACE_INFO of M_AXI_RDATA       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RDATA";
   attribute X_INTERFACE_INFO of M_AXI_RRESP       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RRESP";
   attribute X_INTERFACE_INFO of M_AXI_RLAST       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RLAST";
--   attribute X_INTERFACE_INFO of M_AXI_RUSER       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RUSER";
   attribute X_INTERFACE_INFO of M_AXI_RVALID      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RVALID";
   attribute X_INTERFACE_INFO of M_AXI_RREADY      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RREADY";
   attribute X_INTERFACE_PARAMETER of M_AXI_AWADDR : signal is
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

   attribute X_INTERFACE_INFO of M_AXI_ARESETN      : signal is "xilinx.com:signal:reset:1.0 RST." & INTERFACENAME & "_ARESETN RST";
   attribute X_INTERFACE_PARAMETER of M_AXI_ARESETN : signal is
      "XIL_INTERFACENAME RST." & INTERFACENAME & "_ARESETN, " &
      "POLARITY ACTIVE_LOW";

   attribute X_INTERFACE_INFO of M_AXI_ACLK      : signal is "xilinx.com:signal:clock:1.0 CLK." & INTERFACENAME & "_ACLK CLK";
   attribute X_INTERFACE_PARAMETER of M_AXI_ACLK : signal is
      "XIL_INTERFACENAME CLK." & INTERFACENAME & "_ACLK, " &
      "ASSOCIATED_BUSIF " & INTERFACENAME & ", " &
      "ASSOCIATED_RESET " & INTERFACENAME & "_ARESETN";

   signal M_AXI_ReadMaster  : AxiReadMasterType  := AXI_READ_MASTER_INIT_C;
   signal M_AXI_ReadSlave   : AxiReadSlaveType   := AXI_READ_SLAVE_INIT_C;
   signal M_AXI_WriteMaster : AxiWriteMasterType := AXI_WRITE_MASTER_INIT_C;
   signal M_AXI_WriteSlave  : AxiWriteSlaveType  := AXI_WRITE_SLAVE_INIT_C;

begin

   axiClk <= M_AXI_ACLK;

   M_AXI_ReadMaster <= axiReadMaster;
   axiReadSlave     <= M_AXI_ReadSlave;

   M_AXI_WriteMaster <= axiWriteMaster;
   axiWriteSlave     <= M_AXI_WriteSlave;

   U_RstSync : entity surf.RstSync
      generic map (
         IN_POLARITY_G  => '0',
         OUT_POLARITY_G => '1')
      port map (
         clk      => M_AXI_ACLK,
         asyncRst => M_AXI_ARESETN,
         syncRst  => axiRst);

   M_AXI_AWID     <= M_AXI_WriteMaster.awid(ID_WIDTH-1 downto 0);
   M_AXI_AWADDR   <= M_AXI_WriteMaster.awaddr(ADDR_WIDTH-1 downto 0);
   M_AXI_AWLEN    <= M_AXI_WriteMaster.awlen(7 downto 0);
   M_AXI_AWSIZE   <= M_AXI_WriteMaster.awsize(2 downto 0);
   M_AXI_AWBURST  <= M_AXI_WriteMaster.awburst(1 downto 0);
   M_AXI_AWLOCK   <= M_AXI_WriteMaster.awlock(1 downto 0);
   M_AXI_AWCACHE  <= M_AXI_WriteMaster.awcache(3 downto 0);
   M_AXI_AWPROT   <= M_AXI_WriteMaster.awprot;
   M_AXI_AWREGION <= M_AXI_WriteMaster.awregion(3 downto 0);
   M_AXI_AWQOS    <= M_AXI_WriteMaster.awqos(3 downto 0);
--   M_AXI_AWUSER   <= M_AXI_WriteMaster.awuser(AWUSER_WIDTH-1 downto 0);
   M_AXI_AWVALID  <= M_AXI_WriteMaster.awvalid;
   M_AXI_WID      <= M_AXI_WriteMaster.wid(ID_WIDTH-1 downto 0);
   M_AXI_WDATA    <= M_AXI_WriteMaster.wdata(DATA_WIDTH-1 downto 0);
   M_AXI_WSTRB    <= M_AXI_WriteMaster.wstrb((DATA_WIDTH/8)-1 downto 0) when(HAS_WSTRB /= 0) else (others => '1');
   M_AXI_WLAST    <= M_AXI_WriteMaster.wlast;
--   M_AXI_WUSER    <= M_AXI_WriteMaster.wuser(WUSER_WIDTH-1 downto 0);
   M_AXI_WVALID   <= M_AXI_WriteMaster.wvalid;
   M_AXI_BREADY   <= M_AXI_WriteMaster.bready;

   M_AXI_WriteSlave.awready                  <= M_AXI_AWREADY;
   M_AXI_WriteSlave.wready                   <= M_AXI_WREADY;
   M_AXI_WriteSlave.bid(ID_WIDTH-1 downto 0) <= M_AXI_BID;
   M_AXI_WriteSlave.bresp                    <= M_AXI_BRESP when(EN_ERROR_RESP and (HAS_BRESP /= 0)) else "00";
--   M_AXI_WriteSlave.buser(BUSER_WIDTH-1 downto 0) <= M_AXI_BUSER;
   M_AXI_WriteSlave.bvalid                   <= M_AXI_BVALID;

   M_AXI_ARID     <= M_AXI_ReadMaster.arid(ID_WIDTH-1 downto 0);
   M_AXI_ARADDR   <= M_AXI_ReadMaster.araddr(ADDR_WIDTH-1 downto 0);
   M_AXI_ARLEN    <= M_AXI_ReadMaster.arlen;
   M_AXI_ARSIZE   <= M_AXI_ReadMaster.arsize;
   M_AXI_ARBURST  <= M_AXI_ReadMaster.arburst;
   M_AXI_ARLOCK   <= M_AXI_ReadMaster.arlock;
   M_AXI_ARCACHE  <= M_AXI_ReadMaster.arcache;
   M_AXI_ARPROT   <= M_AXI_ReadMaster.arprot;
   M_AXI_ARREGION <= M_AXI_ReadMaster.arregion(3 downto 0);
   M_AXI_ARQOS    <= M_AXI_ReadMaster.arqos(3 downto 0);
--   M_AXI_ARUSER   <= M_AXI_ReadMaster.aruser(ARUSER_WIDTH-1 downto 0);
   M_AXI_ARVALID  <= M_AXI_ReadMaster.arvalid;
   M_AXI_RREADY   <= M_AXI_ReadMaster.rready;

   M_AXI_ReadSlave.arready                      <= M_AXI_ARREADY;
   M_AXI_ReadSlave.rid(ID_WIDTH-1 downto 0)     <= M_AXI_RID;
   M_AXI_ReadSlave.rdata(DATA_WIDTH-1 downto 0) <= M_AXI_RDATA;
   M_AXI_ReadSlave.rresp                        <= M_AXI_RRESP when(EN_ERROR_RESP and (HAS_RRESP /= 0)) else "00";
   M_AXI_ReadSlave.rlast                        <= M_AXI_RLAST;
--   M_AXI_ReadSlave.ruser(RUSER_WIDTH-1 downto 0) <= M_AXI_RUSER;
   M_AXI_ReadSlave.rvalid                       <= M_AXI_RVALID;

end mapping;
