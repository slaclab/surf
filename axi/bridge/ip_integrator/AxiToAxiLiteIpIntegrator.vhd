-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP integrator wrapper for surf.AxiToAxiLite
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
use surf.AxiPkg.all;
use surf.AxiLitePkg.all;

entity AxiToAxiLiteIpIntegrator is
   generic (
      TPD_G             : time                      := 1 ns;
      RST_POLARITY_G    : sl                        := '1';
      RST_ASYNC_G       : boolean                   := false;
      EN_SLAVE_RESP_G   : boolean                   := true;
      AXI_ADDR_WIDTH_G  : positive range 12 to 64   := 16;
      AXI_DATA_WIDTH_G  : positive range 32 to 1024 := 64;
      AXI_ID_WIDTH_G    : positive                  := 4;
      AXIL_ADDR_WIDTH_G : positive                  := 16);
   port (
      axiClk         : in  sl;
      axiRst         : in  sl;
      S_AXI_AWID     : in  slv(AXI_ID_WIDTH_G-1 downto 0);
      S_AXI_AWADDR   : in  slv(AXI_ADDR_WIDTH_G-1 downto 0);
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
      S_AXI_WID      : in  slv(AXI_ID_WIDTH_G-1 downto 0);
      S_AXI_WDATA    : in  slv(AXI_DATA_WIDTH_G-1 downto 0);
      S_AXI_WSTRB    : in  slv((AXI_DATA_WIDTH_G/8)-1 downto 0);
      S_AXI_WLAST    : in  sl;
      S_AXI_WVALID   : in  sl;
      S_AXI_WREADY   : out sl;
      S_AXI_BID      : out slv(AXI_ID_WIDTH_G-1 downto 0);
      S_AXI_BRESP    : out slv(1 downto 0);
      S_AXI_BVALID   : out sl;
      S_AXI_BREADY   : in  sl;
      S_AXI_ARID     : in  slv(AXI_ID_WIDTH_G-1 downto 0);
      S_AXI_ARADDR   : in  slv(AXI_ADDR_WIDTH_G-1 downto 0);
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
      S_AXI_RID      : out slv(AXI_ID_WIDTH_G-1 downto 0);
      S_AXI_RDATA    : out slv(AXI_DATA_WIDTH_G-1 downto 0);
      S_AXI_RRESP    : out slv(1 downto 0);
      S_AXI_RLAST    : out sl;
      S_AXI_RVALID   : out sl;
      S_AXI_RREADY   : in  sl;
      M_AXIL_AWADDR  : out slv(AXIL_ADDR_WIDTH_G-1 downto 0);
      M_AXIL_AWPROT  : out slv(2 downto 0);
      M_AXIL_AWVALID : out sl;
      M_AXIL_AWREADY : in  sl;
      M_AXIL_WDATA   : out slv(31 downto 0);
      M_AXIL_WSTRB   : out slv(3 downto 0);
      M_AXIL_WVALID  : out sl;
      M_AXIL_WREADY  : in  sl;
      M_AXIL_BRESP   : in  slv(1 downto 0);
      M_AXIL_BVALID  : in  sl;
      M_AXIL_BREADY  : out sl;
      M_AXIL_ARADDR  : out slv(AXIL_ADDR_WIDTH_G-1 downto 0);
      M_AXIL_ARPROT  : out slv(2 downto 0);
      M_AXIL_ARVALID : out sl;
      M_AXIL_ARREADY : in  sl;
      M_AXIL_RDATA   : in  slv(31 downto 0);
      M_AXIL_RRESP   : in  slv(1 downto 0);
      M_AXIL_RVALID  : in  sl;
      M_AXIL_RREADY  : out sl);
end entity AxiToAxiLiteIpIntegrator;

architecture rtl of AxiToAxiLiteIpIntegrator is

   signal axiResetN       : sl := '1';
   signal axiReadMaster   : AxiReadMasterType       := AXI_READ_MASTER_INIT_C;
   signal axiReadSlave    : AxiReadSlaveType        := AXI_READ_SLAVE_INIT_C;
   signal axiWriteMaster  : AxiWriteMasterType      := AXI_WRITE_MASTER_INIT_C;
   signal axiWriteSlave   : AxiWriteSlaveType       := AXI_WRITE_SLAVE_INIT_C;
   signal axilReadMaster  : AxiLiteReadMasterType   := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType    := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType  := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType   := AXI_LITE_WRITE_SLAVE_INIT_C;

begin

   axiResetN <= not axiRst when (RST_POLARITY_G = '1') else axiRst;

   U_S : entity surf.SlaveAxiIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         ID_WIDTH      => AXI_ID_WIDTH_G,
         ADDR_WIDTH    => AXI_ADDR_WIDTH_G,
         DATA_WIDTH    => AXI_DATA_WIDTH_G)
      port map (
         S_AXI_ACLK      => axiClk,
         S_AXI_ARESETN   => axiResetN,
         S_AXI_AWID      => S_AXI_AWID,
         S_AXI_AWADDR    => S_AXI_AWADDR,
         S_AXI_AWLEN     => S_AXI_AWLEN,
         S_AXI_AWSIZE    => S_AXI_AWSIZE,
         S_AXI_AWBURST   => S_AXI_AWBURST,
         S_AXI_AWLOCK    => '0' & S_AXI_AWLOCK,
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
         S_AXI_ARLOCK    => '0' & S_AXI_ARLOCK,
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

   U_M : entity surf.MasterAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => AXIL_ADDR_WIDTH_G)
      port map (
         M_AXI_ACLK      => axiClk,
         M_AXI_ARESETN   => axiResetN,
         M_AXI_AWADDR    => M_AXIL_AWADDR,
         M_AXI_AWPROT    => M_AXIL_AWPROT,
         M_AXI_AWVALID   => M_AXIL_AWVALID,
         M_AXI_AWREADY   => M_AXIL_AWREADY,
         M_AXI_WDATA     => M_AXIL_WDATA,
         M_AXI_WSTRB     => M_AXIL_WSTRB,
         M_AXI_WVALID    => M_AXIL_WVALID,
         M_AXI_WREADY    => M_AXIL_WREADY,
         M_AXI_BRESP     => M_AXIL_BRESP,
         M_AXI_BVALID    => M_AXIL_BVALID,
         M_AXI_BREADY    => M_AXIL_BREADY,
         M_AXI_ARADDR    => M_AXIL_ARADDR,
         M_AXI_ARPROT    => M_AXIL_ARPROT,
         M_AXI_ARVALID   => M_AXIL_ARVALID,
         M_AXI_ARREADY   => M_AXIL_ARREADY,
         M_AXI_RDATA     => M_AXIL_RDATA,
         M_AXI_RRESP     => M_AXIL_RRESP,
         M_AXI_RVALID    => M_AXIL_RVALID,
         M_AXI_RREADY    => M_AXIL_RREADY,
         axilClk         => open,
         axilRst         => open,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   U_DUT : entity surf.AxiToAxiLite
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         EN_SLAVE_RESP_G => EN_SLAVE_RESP_G)
      port map (
         axiClk          => axiClk,
         axiClkRst       => axiRst,
         axiReadMaster   => axiReadMaster,
         axiReadSlave    => axiReadSlave,
         axiWriteMaster  => axiWriteMaster,
         axiWriteSlave   => axiWriteSlave,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

end architecture rtl;
