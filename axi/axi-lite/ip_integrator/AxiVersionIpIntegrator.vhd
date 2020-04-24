-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP Integrator Wrapper for surf.AxiVersion
-------------------------------------------------------------------------------
-- TCL Command: create_bd_cell -type module -reference AxiVersionIpIntegrator AxiVersion_0
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
use surf.AxiLitePkg.all;

library ruckus;
use ruckus.BuildInfoPkg.all;

entity AxiVersionIpIntegrator is
   generic (
      EN_ERROR_RESP    : boolean                       := false;
      FREQ_HZ          : real                          := 125000000.0;
      XIL_DEVICE       : string                        := "7SERIES";  -- Either "7SERIES" or "ULTRASCALE"
      EN_DEVICE_DNA    : boolean                       := false;
      EN_ICAP          : boolean                       := false;
      EN_DS2411        : boolean                       := false;
      USE_SLOWCLK      : boolean                       := false;
      BUFR_CLK_DIV     : positive                      := 8;
      AUTO_RELOAD_EN   : boolean                       := false;
      AUTO_RELOAD_TIME : positive                      := 10;  -- units of seconds
      AUTO_RELOAD_ADDR : std_logic_vector(31 downto 0) := X"00000000");
   port (
      -- AXI-Lite Interface
      S_AXI_ACLK     : in    std_logic;
      S_AXI_ARESETN  : in    std_logic;
      S_AXI_AWADDR   : in    std_logic_vector(11 downto 0);
      S_AXI_AWVALID  : in    std_logic;
      S_AXI_AWREADY  : out   std_logic;
      S_AXI_WDATA    : in    std_logic_vector(31 downto 0);
      S_AXI_WVALID   : in    std_logic;
      S_AXI_WREADY   : out   std_logic;
      S_AXI_BRESP    : out   std_logic_vector(1 downto 0);
      S_AXI_BVALID   : out   std_logic;
      S_AXI_BREADY   : in    std_logic;
      S_AXI_ARADDR   : in    std_logic_vector(11 downto 0);
      S_AXI_ARVALID  : in    std_logic;
      S_AXI_ARREADY  : out   std_logic;
      S_AXI_RDATA    : out   std_logic_vector(31 downto 0);
      S_AXI_RRESP    : out   std_logic_vector(1 downto 0);
      S_AXI_RVALID   : out   std_logic;
      S_AXI_RREADY   : in    std_logic;
      -- Optional: User Reset
      userReset      : out   std_logic;
      -- Optional: FPGA Reloading Interface
      fpgaEnReload   : in    std_logic := '1';
      fpgaReload     : out   std_logic;
      fpgaReloadAddr : out   std_logic_vector(31 downto 0);
      upTimeCnt      : out   std_logic_vector(31 downto 0);
      -- Optional: Serial Number outputs
      slowClk        : in    std_logic := '0';
      dnaValueOut    : out   std_logic_vector(127 downto 0);
      fdValueOut     : out   std_logic_vector(63 downto 0);
      -- Optional: DS2411 interface
      fdSerSdio      : inout std_logic := 'Z');
end AxiVersionIpIntegrator;

architecture mapping of AxiVersionIpIntegrator is

   constant AXI_ADDR_WIDTH_C : positive := 12;

   constant CLK_PERIOD_C : real := (1.0/FREQ_HZ);  -- units of seconds   

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
      "ADDR_WIDTH " & integer'image(AXI_ADDR_WIDTH_C) & ", " &
      "FREQ_HZ " & real'image(FREQ_HZ);

   attribute X_INTERFACE_INFO of S_AXI_ARESETN      : signal is "xilinx.com:signal:reset:1.0 RST.S_AXI_ARESETN RST";
   attribute X_INTERFACE_PARAMETER of S_AXI_ARESETN : signal is
      "XIL_INTERFACENAME RST.S_AXI_ARESETN, " &
      "POLARITY ACTIVE_LOW";

   attribute X_INTERFACE_INFO of S_AXI_ACLK      : signal is "xilinx.com:signal:clock:1.0 CLK.S_AXI_ACLK CLK";
   attribute X_INTERFACE_PARAMETER of S_AXI_ACLK : signal is
      "XIL_INTERFACENAME CLK.S_AXI_ACLK, " &
      "ASSOCIATED_BUSIF S_AXI, " &
      "ASSOCIATED_RESET S_AXI_ARESETN, " &
      "FREQ_HZ " & real'image(FREQ_HZ);

   signal S_AXI_ReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal S_AXI_ReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal S_AXI_WriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal S_AXI_WriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

   signal S_AXI_reset : std_logic := '1';

begin

   U_RstSync : entity surf.RstSync
      generic map (
         IN_POLARITY_G  => '0',
         OUT_POLARITY_G => '1')
      port map (
         clk      => S_AXI_ACLK,
         asyncRst => S_AXI_ARESETN,
         syncRst  => S_AXI_reset);

   S_AXI_ReadMaster.araddr(AXI_ADDR_WIDTH_C-1 downto 0) <= S_AXI_araddr;
   S_AXI_ReadMaster.arvalid                             <= S_AXI_arvalid;
   S_AXI_ReadMaster.rready                              <= S_AXI_rready;

   S_AXI_arready <= S_AXI_ReadSlave.arready;
   S_AXI_rdata   <= S_AXI_ReadSlave.rdata;
   S_AXI_rresp   <= S_AXI_ReadSlave.rresp when(EN_ERROR_RESP) else AXI_RESP_OK_C;
   S_AXI_rvalid  <= S_AXI_ReadSlave.rvalid;

   S_AXI_WriteMaster.awaddr(AXI_ADDR_WIDTH_C-1 downto 0) <= S_AXI_awaddr;
   S_AXI_WriteMaster.awvalid                             <= S_AXI_awvalid;
   S_AXI_WriteMaster.wdata                               <= S_AXI_wdata;
   S_AXI_WriteMaster.wvalid                              <= S_AXI_wvalid;
   S_AXI_WriteMaster.bready                              <= S_AXI_bready;

   S_AXI_awready <= S_AXI_WriteSlave.awready;
   S_AXI_wready  <= S_AXI_WriteSlave.wready;
   S_AXI_bresp   <= S_AXI_WriteSlave.bresp when(EN_ERROR_RESP) else AXI_RESP_OK_C;
   S_AXI_bvalid  <= S_AXI_WriteSlave.bvalid;

   U_AxiVersion : entity surf.AxiVersion
      generic map (
         BUILD_INFO_G       => BUILD_INFO_C,
         CLK_PERIOD_G       => CLK_PERIOD_C,
         XIL_DEVICE_G       => XIL_DEVICE,
         EN_DEVICE_DNA_G    => EN_DEVICE_DNA,
         EN_DS2411_G        => EN_DS2411,
         EN_ICAP_G          => EN_ICAP,
         USE_SLOWCLK_G      => USE_SLOWCLK,
         BUFR_CLK_DIV_G     => BUFR_CLK_DIV,
         AUTO_RELOAD_EN_G   => AUTO_RELOAD_EN,
         AUTO_RELOAD_TIME_G => AUTO_RELOAD_TIME,
         AUTO_RELOAD_ADDR_G => AUTO_RELOAD_ADDR)
      port map (
         -- AXI-Lite Interface
         axiClk         => S_AXI_ACLK,
         axiRst         => S_AXI_reset,
         axiReadMaster  => S_AXI_ReadMaster,
         axiReadSlave   => S_AXI_ReadSlave,
         axiWriteMaster => S_AXI_WriteMaster,
         axiWriteSlave  => S_AXI_WriteSlave,
         -- Optional: User Reset
         userReset      => userReset,
         -- Optional: FPGA Reloading Interface
         fpgaEnReload   => fpgaEnReload,
         fpgaReload     => fpgaReload,
         fpgaReloadAddr => fpgaReloadAddr,
         upTimeCnt      => upTimeCnt,
         -- Optional: Serial Number outputs
         slowClk        => slowClk,
         dnaValueOut    => dnaValueOut,
         fdValueOut     => fdValueOut,
         -- Optional: user values
         userValues     => (others => X"00000000"),
         -- Optional: DS2411 interface
         fdSerSdio      => fdSerSdio);

end mapping;
