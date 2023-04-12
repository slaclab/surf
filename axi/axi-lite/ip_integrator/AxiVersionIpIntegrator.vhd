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
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

library ruckus;
use ruckus.BuildInfoPkg.all;

entity AxiVersionIpIntegrator is
   generic (
      EN_ERROR_RESP : boolean  := false;
      FREQ_HZ       : positive := 125000000);
   port (
      -- AXI-Lite Interface
      S_AXI_ACLK     : in    std_logic;
      S_AXI_ARESETN  : in    std_logic;
      S_AXI_AWADDR   : in    std_logic_vector(11 downto 0);  -- Must match ADDR_WIDTH_C
      S_AXI_AWPROT   : in    std_logic_vector(2 downto 0);
      S_AXI_AWVALID  : in    std_logic;
      S_AXI_AWREADY  : out   std_logic;
      S_AXI_WDATA    : in    std_logic_vector(31 downto 0);
      S_AXI_WSTRB    : in    std_logic_vector(3 downto 0);
      S_AXI_WVALID   : in    std_logic;
      S_AXI_WREADY   : out   std_logic;
      S_AXI_BRESP    : out   std_logic_vector(1 downto 0);
      S_AXI_BVALID   : out   std_logic;
      S_AXI_BREADY   : in    std_logic;
      S_AXI_ARADDR   : in    std_logic_vector(11 downto 0);  -- Must match ADDR_WIDTH_C
      S_AXI_ARPROT   : in    std_logic_vector(2 downto 0);
      S_AXI_ARVALID  : in    std_logic;
      S_AXI_ARREADY  : out   std_logic;
      S_AXI_RDATA    : out   std_logic_vector(31 downto 0);
      S_AXI_RRESP    : out   std_logic_vector(1 downto 0);
      S_AXI_RVALID   : out   std_logic;
      S_AXI_RREADY   : in    std_logic;
      -- Optional: User Reset
      userReset      : out   std_logic;
      -- Optional: FPGA Reloading Interface
      fpgaEnReload   : in    std_logic                            := '1';
      fpgaReload     : out   std_logic;
      fpgaReloadAddr : out   std_logic_vector(31 downto 0);
      upTimeCnt      : out   std_logic_vector(31 downto 0);
      -- Optional: Serial Number outputs
      slowClk        : in    std_logic                            := '0';
      dnaValueOut    : out   std_logic_vector(127 downto 0);
      fdValueOut     : out   std_logic_vector(63 downto 0);
      -- Optional: user values
      userValues     : in    std_logic_vector((64*32)-1 downto 0) := (others => '0');
      -- Optional: DS2411 interface
      fdSerSdio      : inout std_logic                            := 'Z');
end AxiVersionIpIntegrator;

architecture mapping of AxiVersionIpIntegrator is

   constant ADDR_WIDTH_C : positive := 12;  -- Must match the entity's port width

   constant CLK_PERIOD_C : real := (1.0/real(FREQ_HZ));  -- units of seconds

   signal axilClk         : sl;
   signal axilRst         : sl;
   signal axilReadMaster  : AxiLiteReadMasterType;
   signal axilReadSlave   : AxiLiteReadSlaveType;
   signal axilWriteMaster : AxiLiteWriteMasterType;
   signal axilWriteSlave  : AxiLiteWriteSlaveType;

   signal userValuesArray : Slv32Array(0 to 63);

begin

   U_ShimLayer : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => EN_ERROR_RESP,
         FREQ_HZ       => FREQ_HZ,
         ADDR_WIDTH    => ADDR_WIDTH_C)
      port map (
         -- IP Integrator AXI-Lite Interface
         S_AXI_ACLK      => S_AXI_ACLK,
         S_AXI_ARESETN   => S_AXI_ARESETN,
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
         -- SURF AXI-Lite Interface
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   process(userValues)
      variable retVar : Slv32Array(0 to 63);
   begin
      for i in 0 to 63 loop
         retVar(i) := userValues((i*32)+31 downto i*32);
      end loop;
      userValuesArray <= retVar;
   end process;

   U_AxiVersion : entity surf.AxiVersion
      generic map (
         BUILD_INFO_G => BUILD_INFO_C,
         CLK_PERIOD_G => CLK_PERIOD_C)
      port map (
         -- AXI-Lite Interface
         axiClk         => axilClk,
         axiRst         => axilRst,
         axiReadMaster  => axilReadMaster,
         axiReadSlave   => axilReadSlave,
         axiWriteMaster => axilWriteMaster,
         axiWriteSlave  => axilWriteSlave,
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
         userValues     => userValuesArray,
         -- Optional: DS2411 interface
         fdSerSdio      => fdSerSdio);

end mapping;
