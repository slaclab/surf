-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP Integrator Wrapper for surf.AxiWriteEmulate
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

entity AxiWriteEmulateIpIntegrator is
   generic (
      TPD_G     : time    := 1 ns;
      LATENCY_G : natural := 3);
   port (
      axiClk         : in  sl;
      axiRst         : in  sl;
      S_AXI_AWID     : in  slv(7 downto 0);
      S_AXI_AWADDR   : in  slv(15 downto 0);
      S_AXI_AWLEN    : in  slv(7 downto 0);
      S_AXI_AWSIZE   : in  slv(2 downto 0);
      S_AXI_AWBURST  : in  slv(1 downto 0);
      S_AXI_AWLOCK   : in  slv(1 downto 0);
      S_AXI_AWCACHE  : in  slv(3 downto 0);
      S_AXI_AWPROT   : in  slv(2 downto 0);
      S_AXI_AWREGION : in  slv(3 downto 0);
      S_AXI_AWQOS    : in  slv(3 downto 0);
      S_AXI_AWVALID  : in  sl;
      S_AXI_AWREADY  : out sl;
      S_AXI_WID      : in  slv(7 downto 0);
      S_AXI_WDATA    : in  slv(31 downto 0);
      S_AXI_WSTRB    : in  slv(3 downto 0);
      S_AXI_WLAST    : in  sl;
      S_AXI_WVALID   : in  sl;
      S_AXI_WREADY   : out sl;
      S_AXI_BID      : out slv(7 downto 0);
      S_AXI_BRESP    : out slv(1 downto 0);
      S_AXI_BVALID   : out sl;
      S_AXI_BREADY   : in  sl);
end entity AxiWriteEmulateIpIntegrator;

architecture rtl of AxiWriteEmulateIpIntegrator is

   constant AXI_CONFIG_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => 16,
      DATA_BYTES_C => 4,
      ID_BITS_C    => 8,
      LEN_BITS_C   => 8);

   signal axiResetN      : sl := '1';
   signal axiWriteMaster : AxiWriteMasterType := AXI_WRITE_MASTER_INIT_C;
   signal axiWriteSlave  : AxiWriteSlaveType  := AXI_WRITE_SLAVE_INIT_C;

begin

   ---------------------------------------------------------------------------
   -- AXI4 shim
   ---------------------------------------------------------------------------
   axiResetN <= not axiRst;

   U_S_AXI : entity surf.SlaveAxiIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         ID_WIDTH      => 8,
         ADDR_WIDTH    => 16,
         DATA_WIDTH    => 32)
      port map (
         S_AXI_ACLK      => axiClk,
         S_AXI_ARESETN   => axiResetN,
         S_AXI_AWID      => S_AXI_AWID,
         S_AXI_AWADDR    => S_AXI_AWADDR,
         S_AXI_AWLEN     => S_AXI_AWLEN,
         S_AXI_AWSIZE    => S_AXI_AWSIZE,
         S_AXI_AWBURST   => S_AXI_AWBURST,
         S_AXI_AWLOCK    => S_AXI_AWLOCK,
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
         S_AXI_ARID      => (others => '0'),
         S_AXI_ARADDR    => (others => '0'),
         S_AXI_ARLEN     => (others => '0'),
         S_AXI_ARSIZE    => (others => '0'),
         S_AXI_ARBURST   => (others => '0'),
         S_AXI_ARLOCK    => (others => '0'),
         S_AXI_ARCACHE   => (others => '0'),
         S_AXI_ARPROT    => (others => '0'),
         S_AXI_ARREGION  => (others => '0'),
         S_AXI_ARQOS     => (others => '0'),
         S_AXI_ARVALID   => '0',
         S_AXI_ARREADY   => open,
         S_AXI_RID       => open,
         S_AXI_RDATA     => open,
         S_AXI_RRESP     => open,
         S_AXI_RLAST     => open,
         S_AXI_RVALID    => open,
         S_AXI_RREADY    => '0',
         axiClk          => open,
         axiRst          => open,
         axiReadMaster   => open,
         axiReadSlave    => AXI_READ_SLAVE_INIT_C,
         axiWriteMaster  => axiWriteMaster,
         axiWriteSlave   => axiWriteSlave);

   ---------------------------------------------------------------------------
   -- DUT
   ---------------------------------------------------------------------------
   U_DUT : entity surf.AxiWriteEmulate
      generic map (
         TPD_G        => TPD_G,
         LATENCY_G    => LATENCY_G,
         AXI_CONFIG_G => AXI_CONFIG_C)
      port map (
         axiClk         => axiClk,
         axiRst         => axiRst,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave);

end architecture rtl;
