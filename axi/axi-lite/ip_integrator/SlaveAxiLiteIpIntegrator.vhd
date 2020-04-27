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
      EN_ERROR_RESP_G : boolean  := false;
      FREQ_HZ_G       : positive := 100000000;
      ADDR_WIDTH_G    : positive := 12);
   port (
      -- IP Integrator AXI-Lite Interface
      S_AXI_ACLK      : in  std_logic;
      S_AXI_ARESETN   : in  std_logic;
      S_AXI_AWADDR    : in  std_logic_vector(ADDR_WIDTH_G-1 downto 0);
      S_AXI_AWVALID   : in  std_logic;
      S_AXI_AWREADY   : out std_logic;
      S_AXI_WDATA     : in  std_logic_vector(31 downto 0);
      S_AXI_WVALID    : in  std_logic;
      S_AXI_WREADY    : out std_logic;
      S_AXI_BRESP     : out std_logic_vector(1 downto 0);
      S_AXI_BVALID    : out std_logic;
      S_AXI_BREADY    : in  std_logic;
      S_AXI_ARADDR    : in  std_logic_vector(ADDR_WIDTH_G-1 downto 0);
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

   attribute X_INTERFACE_INFO of S_AXI_RREADY      : signal is "xilinx.com:interface:aximm:1.0 S_AXI RREADY";
   attribute X_INTERFACE_INFO of S_AXI_RVALID      : signal is "xilinx.com:interface:aximm:1.0 S_AXI RVALID";
   attribute X_INTERFACE_INFO of S_AXI_RRESP       : signal is "xilinx.com:interface:aximm:1.0 S_AXI RRESP";
   attribute X_INTERFACE_INFO of S_AXI_RDATA       : signal is "xilinx.com:interface:aximm:1.0 S_AXI RDATA";
   attribute X_INTERFACE_INFO of S_AXI_ARREADY     : signal is "xilinx.com:interface:aximm:1.0 S_AXI ARREADY";
   attribute X_INTERFACE_INFO of S_AXI_ARVALID     : signal is "xilinx.com:interface:aximm:1.0 S_AXI ARVALID";
   attribute X_INTERFACE_INFO of S_AXI_ARADDR      : signal is "xilinx.com:interface:aximm:1.0 S_AXI ARADDR";
   attribute X_INTERFACE_INFO of S_AXI_BREADY      : signal is "xilinx.com:interface:aximm:1.0 S_AXI BREADY";
   attribute X_INTERFACE_INFO of S_AXI_BVALID      : signal is "xilinx.com:interface:aximm:1.0 S_AXI BVALID";
   attribute X_INTERFACE_INFO of S_AXI_BRESP       : signal is "xilinx.com:interface:aximm:1.0 S_AXI BRESP";
   attribute X_INTERFACE_INFO of S_AXI_WREADY      : signal is "xilinx.com:interface:aximm:1.0 S_AXI WREADY";
   attribute X_INTERFACE_INFO of S_AXI_WVALID      : signal is "xilinx.com:interface:aximm:1.0 S_AXI WVALID";
   attribute X_INTERFACE_INFO of S_AXI_WDATA       : signal is "xilinx.com:interface:aximm:1.0 S_AXI WDATA";
   attribute X_INTERFACE_INFO of S_AXI_AWREADY     : signal is "xilinx.com:interface:aximm:1.0 S_AXI AWREADY";
   attribute X_INTERFACE_INFO of S_AXI_AWVALID     : signal is "xilinx.com:interface:aximm:1.0 S_AXI AWVALID";
   attribute X_INTERFACE_INFO of S_AXI_AWADDR      : signal is "xilinx.com:interface:aximm:1.0 S_AXI AWADDR";
   attribute X_INTERFACE_PARAMETER of S_AXI_AWADDR : signal is
      "XIL_INTERFACENAME S_AXI, " &
      "PROTOCOL AXI4LITE, " &
      "DATA_WIDTH 32, " &
      "HAS_PROT 0, " &
      "HAS_WSTRB 0, "&
      "MAX_BURST_LENGTH 1, " &
      "ADDR_WIDTH " & integer'image(ADDR_WIDTH_G) & ", " &
      "FREQ_HZ_G " & integer'image(FREQ_HZ_G);

   attribute X_INTERFACE_INFO of S_AXI_ARESETN      : signal is "xilinx.com:signal:reset:1.0 RST.S_AXI_ARESETN RST";
   attribute X_INTERFACE_PARAMETER of S_AXI_ARESETN : signal is
      "XIL_INTERFACENAME RST.S_AXI_ARESETN, " &
      "POLARITY ACTIVE_LOW";

   attribute X_INTERFACE_INFO of S_AXI_ACLK      : signal is "xilinx.com:signal:clock:1.0 CLK.S_AXI_ACLK CLK";
   attribute X_INTERFACE_PARAMETER of S_AXI_ACLK : signal is
      "XIL_INTERFACENAME CLK.S_AXI_ACLK, " &
      "ASSOCIATED_BUSIF S_AXI, " &
      "ASSOCIATED_RESET S_AXI_ARESETN, " &
      "FREQ_HZ_G " & integer'image(FREQ_HZ_G);

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

   S_AXI_ReadMaster.araddr(ADDR_WIDTH_G-1 downto 0) <= S_AXI_araddr;
   S_AXI_ReadMaster.arvalid                         <= S_AXI_arvalid;
   S_AXI_ReadMaster.rready                          <= S_AXI_rready;

   S_AXI_arready <= S_AXI_ReadSlave.arready;
   S_AXI_rdata   <= S_AXI_ReadSlave.rdata;
   S_AXI_rresp   <= S_AXI_ReadSlave.rresp when(EN_ERROR_RESP_G) else AXI_RESP_OK_C;
   S_AXI_rvalid  <= S_AXI_ReadSlave.rvalid;

   S_AXI_WriteMaster.awaddr(ADDR_WIDTH_G-1 downto 0) <= S_AXI_awaddr;
   S_AXI_WriteMaster.awvalid                         <= S_AXI_awvalid;
   S_AXI_WriteMaster.wdata                           <= S_AXI_wdata;
   S_AXI_WriteMaster.wvalid                          <= S_AXI_wvalid;
   S_AXI_WriteMaster.bready                          <= S_AXI_bready;

   S_AXI_awready <= S_AXI_WriteSlave.awready;
   S_AXI_wready  <= S_AXI_WriteSlave.wready;
   S_AXI_bresp   <= S_AXI_WriteSlave.bresp when(EN_ERROR_RESP_G) else AXI_RESP_OK_C;
   S_AXI_bvalid  <= S_AXI_WriteSlave.bvalid;

end mapping;
