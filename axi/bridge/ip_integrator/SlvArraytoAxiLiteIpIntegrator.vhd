-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP Integrator Wrapper for surf.SlvArraytoAxiLite
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity SlvArraytoAxiLiteIpIntegrator is
   port (
      clk           : in  sl;
      rst           : in  sl;
      input0        : in  slv(31 downto 0);
      input1        : in  slv(31 downto 0);
      axilClk       : in  sl;
      axilRst       : in  sl;
      M_AXI_AWADDR  : out slv(31 downto 0);
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
      M_AXI_ARADDR  : out slv(31 downto 0);
      M_AXI_ARPROT  : out slv(2 downto 0);
      M_AXI_ARVALID : out sl;
      M_AXI_ARREADY : in  sl;
      M_AXI_RDATA   : in  slv(31 downto 0);
      M_AXI_RRESP   : in  slv(1 downto 0);
      M_AXI_RVALID  : in  sl;
      M_AXI_RREADY  : out sl);
end entity SlvArraytoAxiLiteIpIntegrator;

architecture rtl of SlvArraytoAxiLiteIpIntegrator is

   signal axilResetN      : sl := '1';
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

begin

   ---------------------------------------------------------------------------
   -- AXI-Lite master shim
   ---------------------------------------------------------------------------
   axilResetN <= not axilRst;

   U_M_AXI : entity surf.MasterAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 32)
      port map (
         M_AXI_ACLK      => axilClk,
         M_AXI_ARESETN   => axilResetN,
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
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   ---------------------------------------------------------------------------
   -- DUT
   ---------------------------------------------------------------------------
   U_DUT : entity surf.SlvArraytoAxiLite
      generic map (
         COMMON_CLK_G => true,
         SIZE_G       => 2,
         ADDR_G       => (0 => x"00000010", 1 => x"00000020"))
      port map (
         clk             => clk,
         rst             => rst,
         input           => (0 => input0, 1 => input1),
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

end architecture rtl;
