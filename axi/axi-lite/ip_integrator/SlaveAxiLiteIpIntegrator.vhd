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

entity SlaveAxiLiteIpIntegrator is
   generic (
      INTERFACENAME : string               := "S_AXI";
      EN_ERROR_RESP : boolean              := false;
      HAS_PROT      : natural range 0 to 1 := 0;
      HAS_WSTRB     : natural range 0 to 1 := 0;
      FREQ_HZ       : positive             := 100000000;
      ADDR_WIDTH    : positive             := 12);
   port (
      -- IP Integrator AXI-Lite Interface
      S_AXI_ACLK      : in  std_logic;
      S_AXI_ARESETN   : in  std_logic;
      S_AXI_AWADDR    : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      S_AXI_AWPROT    : in  std_logic_vector(2 downto 0);
      S_AXI_AWVALID   : in  std_logic;
      S_AXI_AWREADY   : out std_logic;
      S_AXI_WDATA     : in  std_logic_vector(31 downto 0);
      S_AXI_WSTRB     : in  std_logic_vector(3 downto 0);
      S_AXI_WVALID    : in  std_logic;
      S_AXI_WREADY    : out std_logic;
      S_AXI_BRESP     : out std_logic_vector(1 downto 0);
      S_AXI_BVALID    : out std_logic;
      S_AXI_BREADY    : in  std_logic;
      S_AXI_ARADDR    : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      S_AXI_ARPROT    : in  std_logic_vector(2 downto 0);
      S_AXI_ARVALID   : in  std_logic;
      S_AXI_ARREADY   : out std_logic;
      S_AXI_RDATA     : out std_logic_vector(31 downto 0);
      S_AXI_RRESP     : out std_logic_vector(1 downto 0);
      S_AXI_RVALID    : out std_logic;
      S_AXI_RREADY    : in  std_logic;
      -- SURF AXI-Lite Interface
      axilClk         : out sl;
      axilRst         : out sl;
      axilReadMaster  : out AxiLiteReadMasterType;
      axilReadSlave   : in  AxiLiteReadSlaveType;
      axilWriteMaster : out AxiLiteWriteMasterType;
      axilWriteSlave  : in  AxiLiteWriteSlaveType);
end SlaveAxiLiteIpIntegrator;

architecture mapping of SlaveAxiLiteIpIntegrator is

   attribute X_INTERFACE_INFO      : string;
   attribute X_INTERFACE_PARAMETER : string;

   attribute X_INTERFACE_INFO of S_AXI_RREADY      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RREADY";
   attribute X_INTERFACE_INFO of S_AXI_RVALID      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RVALID";
   attribute X_INTERFACE_INFO of S_AXI_RRESP       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RRESP";
   attribute X_INTERFACE_INFO of S_AXI_RDATA       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RDATA";
   attribute X_INTERFACE_INFO of S_AXI_ARREADY     : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARREADY";
   attribute X_INTERFACE_INFO of S_AXI_ARVALID     : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARVALID";
   attribute X_INTERFACE_INFO of S_AXI_ARADDR      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARADDR";
   attribute X_INTERFACE_INFO of S_AXI_ARPROT      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARPROT";
   attribute X_INTERFACE_INFO of S_AXI_BREADY      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " BREADY";
   attribute X_INTERFACE_INFO of S_AXI_BVALID      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " BVALID";
   attribute X_INTERFACE_INFO of S_AXI_BRESP       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " BRESP";
   attribute X_INTERFACE_INFO of S_AXI_WREADY      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WREADY";
   attribute X_INTERFACE_INFO of S_AXI_WVALID      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WVALID";
   attribute X_INTERFACE_INFO of S_AXI_WDATA       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WDATA";
   attribute X_INTERFACE_INFO of S_AXI_WSTRB       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WSTRB";
   attribute X_INTERFACE_INFO of S_AXI_AWREADY     : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWREADY";
   attribute X_INTERFACE_INFO of S_AXI_AWVALID     : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWVALID";
   attribute X_INTERFACE_INFO of S_AXI_AWPROT      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWPROT";
   attribute X_INTERFACE_INFO of S_AXI_AWADDR      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWADDR";
   attribute X_INTERFACE_PARAMETER of S_AXI_AWADDR : signal is
      "XIL_INTERFACENAME " & INTERFACENAME & ", " &
      "PROTOCOL AXI4LITE, " &
      "DATA_WIDTH 32, " &
      "HAS_PROT " & integer'image(HAS_PROT) & ", " &
      "HAS_WSTRB " & integer'image(HAS_WSTRB) & ", " &
      "MAX_BURST_LENGTH 1, " &
      "ADDR_WIDTH " & integer'image(ADDR_WIDTH) & ", " &
      "FREQ_HZ " & integer'image(FREQ_HZ);

   attribute X_INTERFACE_INFO of S_AXI_ARESETN      : signal is "xilinx.com:signal:reset:1.0 RST." & INTERFACENAME & "_ARESETN RST";
   attribute X_INTERFACE_PARAMETER of S_AXI_ARESETN : signal is
      "XIL_INTERFACENAME RST." & INTERFACENAME & "_ARESETN, " &
      "POLARITY ACTIVE_LOW";

   attribute X_INTERFACE_INFO of S_AXI_ACLK      : signal is "xilinx.com:signal:clock:1.0 CLK." & INTERFACENAME & "_ACLK CLK";
   attribute X_INTERFACE_PARAMETER of S_AXI_ACLK : signal is
      "XIL_INTERFACENAME CLK." & INTERFACENAME & "_ACLK, " &
      "ASSOCIATED_BUSIF " & INTERFACENAME & ", " &
      "ASSOCIATED_RESET " & INTERFACENAME & "_ARESETN, " &
      "FREQ_HZ " & integer'image(FREQ_HZ);

   signal S_AXI_ReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal S_AXI_ReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal S_AXI_WriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal S_AXI_WriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

begin

   axilClk <= S_AXI_ACLK;

   axilReadMaster  <= S_AXI_ReadMaster;
   S_AXI_ReadSlave <= axilReadSlave;

   axilWriteMaster  <= S_AXI_WriteMaster;
   S_AXI_WriteSlave <= axilWriteSlave;

   U_RstSync : entity surf.RstSync
      generic map (
         IN_POLARITY_G  => '0',
         OUT_POLARITY_G => '1')
      port map (
         clk      => S_AXI_ACLK,
         asyncRst => S_AXI_ARESETN,
         syncRst  => axilRst);

   S_AXI_ReadMaster.araddr(ADDR_WIDTH-1 downto 0) <= S_AXI_ARADDR;
   S_AXI_ReadMaster.arprot                        <= S_AXI_ARPROT;
   S_AXI_ReadMaster.arvalid                       <= S_AXI_ARVALID;
   S_AXI_ReadMaster.rready                        <= S_AXI_RREADY;

   S_AXI_ARREADY <= S_AXI_ReadSlave.arready;
   S_AXI_RDATA   <= S_AXI_ReadSlave.rdata;
   S_AXI_RRESP   <= S_AXI_ReadSlave.rresp when(EN_ERROR_RESP) else AXI_RESP_OK_C;
   S_AXI_RVALID  <= S_AXI_ReadSlave.rvalid;

   S_AXI_WriteMaster.awaddr(ADDR_WIDTH-1 downto 0) <= S_AXI_AWADDR;
   S_AXI_WriteMaster.awprot                        <= S_AXI_AWPROT;
   S_AXI_WriteMaster.awvalid                       <= S_AXI_AWVALID;
   S_AXI_WriteMaster.wdata                         <= S_AXI_WDATA;
   S_AXI_WriteMaster.wstrb                         <= S_AXI_WSTRB when(HAS_WSTRB /= 0) else x"F";
   S_AXI_WriteMaster.wvalid                        <= S_AXI_WVALID;
   S_AXI_WriteMaster.bready                        <= S_AXI_BREADY;

   S_AXI_AWREADY <= S_AXI_WriteSlave.awready;
   S_AXI_WREADY  <= S_AXI_WriteSlave.wready;
   S_AXI_BRESP   <= S_AXI_WriteSlave.bresp when(EN_ERROR_RESP) else AXI_RESP_OK_C;
   S_AXI_BVALID  <= S_AXI_WriteSlave.bvalid;

end mapping;
