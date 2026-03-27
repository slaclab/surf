-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP Integrator Wrapper for surf.AxiStreamMonAxiL
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
use surf.AxiStreamPkg.all;

entity AxiStreamMonAxiLIpIntegrator is
   port (
      axisClk        : in  sl;
      axisRst        : in  sl;
      S_AXIS_TVALID  : in  sl;
      S_AXIS_TDATA   : in  slv(31 downto 0);
      S_AXIS_TKEEP   : in  slv(3 downto 0);
      S_AXIS_TLAST   : in  sl;
      S_AXIS_TDEST   : in  slv(0 downto 0);
      S_AXIS_TID     : in  slv(0 downto 0);
      S_AXIS_TUSER   : in  slv(0 downto 0);
      S_AXIS_TREADY  : out sl;
      axilClk        : in  sl;
      axilRst        : in  sl;
      S_AXI_AWADDR   : in  slv(5 downto 0);
      S_AXI_AWPROT   : in  slv(2 downto 0);
      S_AXI_AWVALID  : in  sl;
      S_AXI_AWREADY  : out sl;
      S_AXI_WDATA    : in  slv(31 downto 0);
      S_AXI_WSTRB    : in  slv(3 downto 0);
      S_AXI_WVALID   : in  sl;
      S_AXI_WREADY   : out sl;
      S_AXI_BRESP    : out slv(1 downto 0);
      S_AXI_BVALID   : out sl;
      S_AXI_BREADY   : in  sl;
      S_AXI_ARADDR   : in  slv(5 downto 0);
      S_AXI_ARPROT   : in  slv(2 downto 0);
      S_AXI_ARVALID  : in  sl;
      S_AXI_ARREADY  : out sl;
      S_AXI_RDATA    : out slv(31 downto 0);
      S_AXI_RRESP    : out slv(1 downto 0);
      S_AXI_RVALID   : out sl;
      S_AXI_RREADY   : in  sl);
end entity AxiStreamMonAxiLIpIntegrator;

architecture rtl of AxiStreamMonAxiLIpIntegrator is

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 4,
      TDEST_BITS_C  => 1,
      TID_BITS_C    => 1,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 1,
      TUSER_MODE_C  => TUSER_NORMAL_C);

   signal axisResetN      : sl := '1';
   signal axilResetN      : sl := '1';
   signal axisMasters     : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal axisSlaves      : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

begin

   ---------------------------------------------------------------------------
   -- Bus shims
   ---------------------------------------------------------------------------
   axisResetN <= not axisRst;
   axilResetN <= not axilRst;

   U_AXIS : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "S_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 1,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 1,
         TDATA_NUM_BYTES => 4)
      port map (
         S_AXIS_ACLK    => axisClk,
         S_AXIS_ARESETN => axisResetN,
         S_AXIS_TVALID  => S_AXIS_TVALID,
         S_AXIS_TDATA   => S_AXIS_TDATA,
         S_AXIS_TSTRB   => (others => '0'),
         S_AXIS_TKEEP   => S_AXIS_TKEEP,
         S_AXIS_TLAST   => S_AXIS_TLAST,
         S_AXIS_TDEST   => S_AXIS_TDEST,
         S_AXIS_TID     => S_AXIS_TID,
         S_AXIS_TUSER   => S_AXIS_TUSER,
         S_AXIS_TREADY  => S_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => axisMasters(0),
         axisSlave      => axisSlaves(0));

   U_AXIL : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 6)
      port map (
         S_AXI_ACLK      => axilClk,
         S_AXI_ARESETN   => axilResetN,
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
         axilClk         => open,
         axilRst         => open,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   ---------------------------------------------------------------------------
   -- DUT
   ---------------------------------------------------------------------------
   U_DUT : entity surf.AxiStreamMonAxiL
      generic map (
         COMMON_CLK_G     => true,
         AXIS_CLK_FREQ_G  => 1000.0,
         AXIS_NUM_SLOTS_G => 1,
         AXIS_CONFIG_G    => AXIS_CONFIG_C)
      port map (
         axisClk          => axisClk,
         axisRst          => axisRst,
         axisMasters      => axisMasters,
         axisSlaves       => axisSlaves,
         axilClk          => axilClk,
         axilRst          => axilRst,
         sAxilWriteMaster => axilWriteMaster,
         sAxilWriteSlave  => axilWriteSlave,
         sAxilReadMaster  => axilReadMaster,
         sAxilReadSlave   => axilReadSlave);

end architecture rtl;
