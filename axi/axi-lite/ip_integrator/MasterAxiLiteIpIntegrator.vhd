-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Common shim layer between IP Integrator interface and surf AXI-Lite interface
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
use surf.AxiLitePkg.all;

entity MasterAxiLiteIpIntegrator is
   generic (
      INTERFACENAME : string               := "M_AXI";
      EN_ERROR_RESP : boolean              := false;
      HAS_PROT      : natural range 0 to 1 := 0;
      HAS_WSTRB     : natural range 0 to 1 := 0;
      FREQ_HZ       : positive             := 100000000;
      ADDR_WIDTH    : positive             := 12);
   port (
      -- IP Integrator AXI-Lite Interface
      M_AXI_ACLK      : in  std_logic;
      M_AXI_ARESETN   : in  std_logic;
      M_AXI_AWADDR    : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      M_AXI_AWPROT    : out std_logic_vector(2 downto 0);
      M_AXI_AWVALID   : out std_logic;
      M_AXI_AWREADY   : in  std_logic;
      M_AXI_WDATA     : out std_logic_vector(31 downto 0);
      M_AXI_WSTRB     : out std_logic_vector(3 downto 0);
      M_AXI_WVALID    : out std_logic;
      M_AXI_WREADY    : in  std_logic;
      M_AXI_BRESP     : in  std_logic_vector(1 downto 0);
      M_AXI_BVALID    : in  std_logic;
      M_AXI_BREADY    : out std_logic;
      M_AXI_ARADDR    : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      M_AXI_ARPROT    : out std_logic_vector(2 downto 0);
      M_AXI_ARVALID   : out std_logic;
      M_AXI_ARREADY   : in  std_logic;
      M_AXI_RDATA     : in  std_logic_vector(31 downto 0);
      M_AXI_RRESP     : in  std_logic_vector(1 downto 0);
      M_AXI_RVALID    : in  std_logic;
      M_AXI_RREADY    : out std_logic;
      -- SURF AXI-Lite Interface
      axilClk         : out sl;
      axilRst         : out sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end MasterAxiLiteIpIntegrator;

architecture mapping of MasterAxiLiteIpIntegrator is

   attribute X_INTERFACE_INFO      : string;
   attribute X_INTERFACE_PARAMETER : string;

   attribute X_INTERFACE_INFO of M_AXI_RREADY      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RREADY";
   attribute X_INTERFACE_INFO of M_AXI_RVALID      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RVALID";
   attribute X_INTERFACE_INFO of M_AXI_RRESP       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RRESP";
   attribute X_INTERFACE_INFO of M_AXI_RDATA       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RDATA";
   attribute X_INTERFACE_INFO of M_AXI_ARREADY     : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARREADY";
   attribute X_INTERFACE_INFO of M_AXI_ARVALID     : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARVALID";
   attribute X_INTERFACE_INFO of M_AXI_ARADDR      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARADDR";
   attribute X_INTERFACE_INFO of M_AXI_ARPROT      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARPROT";
   attribute X_INTERFACE_INFO of M_AXI_BREADY      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " BREADY";
   attribute X_INTERFACE_INFO of M_AXI_BVALID      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " BVALID";
   attribute X_INTERFACE_INFO of M_AXI_BRESP       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " BRESP";
   attribute X_INTERFACE_INFO of M_AXI_WREADY      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WREADY";
   attribute X_INTERFACE_INFO of M_AXI_WVALID      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WVALID";
   attribute X_INTERFACE_INFO of M_AXI_WDATA       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WDATA";
   attribute X_INTERFACE_INFO of M_AXI_WSTRB       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WSTRB";
   attribute X_INTERFACE_INFO of M_AXI_AWREADY     : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWREADY";
   attribute X_INTERFACE_INFO of M_AXI_AWVALID     : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWVALID";
   attribute X_INTERFACE_INFO of M_AXI_AWPROT      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWPROT";
   attribute X_INTERFACE_INFO of M_AXI_AWADDR      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWADDR";
   attribute X_INTERFACE_PARAMETER of M_AXI_AWADDR : signal is
      "XIL_INTERFACENAME " & INTERFACENAME & ", " &
      "PROTOCOL AXI4LITE, " &
      "DATA_WIDTH 32, " &
      "HAS_PROT " & integer'image(HAS_PROT) & ", " &
      "HAS_WSTRB " & integer'image(HAS_WSTRB) & ", " &
      "MAX_BURST_LENGTH 1, " &
      "ADDR_WIDTH " & integer'image(ADDR_WIDTH) & ", " &
      "FREQ_HZ " & integer'image(FREQ_HZ);

   attribute X_INTERFACE_INFO of M_AXI_ARESETN      : signal is "xilinx.com:signal:reset:1.0 RST." & INTERFACENAME & "_ARESETN RST";
   attribute X_INTERFACE_PARAMETER of M_AXI_ARESETN : signal is
      "XIL_INTERFACENAME RST." & INTERFACENAME & "_ARESETN, " &
      "POLARITY ACTIVE_LOW";

   attribute X_INTERFACE_INFO of M_AXI_ACLK      : signal is "xilinx.com:signal:clock:1.0 CLK." & INTERFACENAME & "_ACLK CLK";
   attribute X_INTERFACE_PARAMETER of M_AXI_ACLK : signal is
      "XIL_INTERFACENAME CLK." & INTERFACENAME & "_ACLK, " &
      "ASSOCIATED_BUSIF " & INTERFACENAME & ", " &
      "ASSOCIATED_RESET " & INTERFACENAME & "_ARESETN, " &
      "FREQ_HZ " & integer'image(FREQ_HZ);

   signal M_AXI_ReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal M_AXI_ReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal M_AXI_WriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal M_AXI_WriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

begin

   axilClk <= M_AXI_ACLK;

   M_AXI_ReadMaster <= axilReadMaster;
   axilReadSlave    <= M_AXI_ReadSlave;

   M_AXI_WriteMaster <= axilWriteMaster;
   axilWriteSlave    <= M_AXI_WriteSlave;

   U_RstSync : entity surf.RstSync
      generic map (
         IN_POLARITY_G  => '0',
         OUT_POLARITY_G => '1')
      port map (
         clk      => M_AXI_ACLK,
         asyncRst => M_AXI_ARESETN,
         syncRst  => axilRst);

   M_AXI_ARADDR  <= M_AXI_ReadMaster.araddr(ADDR_WIDTH-1 downto 0);
   M_AXI_ARPROT  <= M_AXI_ReadMaster.arprot;
   M_AXI_ARVALID <= M_AXI_ReadMaster.arvalid;
   M_AXI_RREADY  <= M_AXI_ReadMaster.rready;

   M_AXI_ReadSlave.arready <= M_AXI_ARREADY;
   M_AXI_ReadSlave.rdata   <= M_AXI_RDATA;
   M_AXI_ReadSlave.rresp   <= M_AXI_RRESP when(EN_ERROR_RESP) else AXI_RESP_OK_C;
   M_AXI_ReadSlave.rvalid  <= M_AXI_RVALID;

   M_AXI_AWADDR  <= M_AXI_WriteMaster.awaddr(ADDR_WIDTH-1 downto 0);
   M_AXI_AWPROT  <= M_AXI_WriteMaster.awprot;
   M_AXI_AWVALID <= M_AXI_WriteMaster.awvalid;
   M_AXI_WDATA   <= M_AXI_WriteMaster.wdata;
   M_AXI_WSTRB   <= M_AXI_WriteMaster.wstrb when(HAS_WSTRB /= 0) else x"F";
   M_AXI_WVALID  <= M_AXI_WriteMaster.wvalid;
   M_AXI_BREADY  <= M_AXI_WriteMaster.bready;

   M_AXI_WriteSlave.awready <= M_AXI_AWREADY;
   M_AXI_WriteSlave.wready  <= M_AXI_WREADY;
   M_AXI_WriteSlave.bresp   <= M_AXI_BRESP when(EN_ERROR_RESP) else AXI_RESP_OK_C;
   M_AXI_WriteSlave.bvalid  <= M_AXI_BVALID;

end mapping;
