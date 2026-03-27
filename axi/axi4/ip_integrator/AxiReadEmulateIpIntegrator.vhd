-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP Integrator Wrapper for surf.AxiReadEmulate
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

entity AxiReadEmulateIpIntegrator is
   generic (
      TPD_G     : time    := 1 ns;
      LATENCY_G : natural := 3);
   port (
      axiClk        : in  sl;
      axiRst        : in  sl;
      S_AXI_ARID    : in  slv(7 downto 0);
      S_AXI_ARADDR  : in  slv(15 downto 0);
      S_AXI_ARLEN   : in  slv(7 downto 0);
      S_AXI_ARSIZE  : in  slv(2 downto 0);
      S_AXI_ARBURST : in  slv(1 downto 0);
      S_AXI_ARLOCK  : in  slv(1 downto 0);
      S_AXI_ARCACHE : in  slv(3 downto 0);
      S_AXI_ARPROT  : in  slv(2 downto 0);
      S_AXI_ARREGION : in  slv(3 downto 0);
      S_AXI_ARQOS   : in  slv(3 downto 0);
      S_AXI_ARVALID : in  sl;
      S_AXI_ARREADY : out sl;
      S_AXI_RID     : out slv(7 downto 0);
      S_AXI_RDATA   : out slv(31 downto 0);
      S_AXI_RRESP   : out slv(1 downto 0);
      S_AXI_RLAST   : out sl;
      S_AXI_RVALID  : out sl;
      S_AXI_RREADY  : in  sl);
end entity AxiReadEmulateIpIntegrator;

architecture rtl of AxiReadEmulateIpIntegrator is

   constant AXI_CONFIG_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => 16,
      DATA_BYTES_C => 4,
      ID_BITS_C    => 8,
      LEN_BITS_C   => 8);

   signal axiResetN     : sl := '1';
   signal axiReadMaster : AxiReadMasterType := AXI_READ_MASTER_INIT_C;
   signal axiReadSlave  : AxiReadSlaveType  := AXI_READ_SLAVE_INIT_C;

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
         S_AXI_AWID      => (others => '0'),
         S_AXI_AWADDR    => (others => '0'),
         S_AXI_AWLEN     => (others => '0'),
         S_AXI_AWSIZE    => (others => '0'),
         S_AXI_AWBURST   => (others => '0'),
         S_AXI_AWLOCK    => (others => '0'),
         S_AXI_AWCACHE   => (others => '0'),
         S_AXI_AWPROT    => (others => '0'),
         S_AXI_AWREGION  => (others => '0'),
         S_AXI_AWQOS     => (others => '0'),
         S_AXI_AWVALID   => '0',
         S_AXI_AWREADY   => open,
         S_AXI_WID       => (others => '0'),
         S_AXI_WDATA     => (others => '0'),
         S_AXI_WSTRB     => (others => '0'),
         S_AXI_WLAST     => '0',
         S_AXI_WVALID    => '0',
         S_AXI_WREADY    => open,
         S_AXI_BID       => open,
         S_AXI_BRESP     => open,
         S_AXI_BVALID    => open,
         S_AXI_BREADY    => '0',
         S_AXI_ARID      => S_AXI_ARID,
         S_AXI_ARADDR    => S_AXI_ARADDR,
         S_AXI_ARLEN     => S_AXI_ARLEN,
         S_AXI_ARSIZE    => S_AXI_ARSIZE,
         S_AXI_ARBURST   => S_AXI_ARBURST,
         S_AXI_ARLOCK    => S_AXI_ARLOCK,
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
         axiWriteMaster  => open,
         axiWriteSlave   => AXI_WRITE_SLAVE_INIT_C);

   ---------------------------------------------------------------------------
   -- DUT
   ---------------------------------------------------------------------------
   U_DUT : entity surf.AxiReadEmulate
      generic map (
         TPD_G        => TPD_G,
         LATENCY_G    => LATENCY_G,
         AXI_CONFIG_G => AXI_CONFIG_C)
      port map (
         axiClk        => axiClk,
         axiRst        => axiRst,
         axiReadMaster => axiReadMaster,
         axiReadSlave  => axiReadSlave);

end architecture rtl;
