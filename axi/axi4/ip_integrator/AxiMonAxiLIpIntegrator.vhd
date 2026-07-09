-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP Integrator Wrapper for surf.AxiMonAxiL
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

entity AxiMonAxiLIpIntegrator is
   port (
      axiClk        : in  sl;
      axiRst        : in  sl;
      wrValid       : in  sl;
      wrLast        : in  sl;
      wrReady       : in  sl;
      wrStrb        : in  slv(3 downto 0);
      rdValid       : in  sl;
      rdLast        : in  sl;
      rdReady       : in  sl;
      axilClk       : in  sl;
      axilRst       : in  sl;
      S_AXI_AWADDR  : in  slv(6 downto 0);
      S_AXI_AWPROT  : in  slv(2 downto 0);
      S_AXI_AWVALID : in  sl;
      S_AXI_AWREADY : out sl;
      S_AXI_WDATA   : in  slv(31 downto 0);
      S_AXI_WSTRB   : in  slv(3 downto 0);
      S_AXI_WVALID  : in  sl;
      S_AXI_WREADY  : out sl;
      S_AXI_BRESP   : out slv(1 downto 0);
      S_AXI_BVALID  : out sl;
      S_AXI_BREADY  : in  sl;
      S_AXI_ARADDR  : in  slv(6 downto 0);
      S_AXI_ARPROT  : in  slv(2 downto 0);
      S_AXI_ARVALID : in  sl;
      S_AXI_ARREADY : out sl;
      S_AXI_RDATA   : out slv(31 downto 0);
      S_AXI_RRESP   : out slv(1 downto 0);
      S_AXI_RVALID  : out sl;
      S_AXI_RREADY  : in  sl);
end entity AxiMonAxiLIpIntegrator;

architecture rtl of AxiMonAxiLIpIntegrator is

   constant AXI_CONFIG_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => 16,
      DATA_BYTES_C => 4,
      ID_BITS_C    => 1,
      LEN_BITS_C   => 8);

   signal axilResetN      : sl                              := '1';
   signal axiWriteMasters : AxiWriteMasterArray(0 downto 0) := (others => AXI_WRITE_MASTER_INIT_C);
   signal axiWriteSlaves  : AxiWriteSlaveArray(0 downto 0)  := (others => AXI_WRITE_SLAVE_INIT_C);
   signal axiReadMasters  : AxiReadMasterArray(0 downto 0)  := (others => AXI_READ_MASTER_INIT_C);
   signal axiReadSlaves   : AxiReadSlaveArray(0 downto 0)   := (others => AXI_READ_SLAVE_INIT_C);
   signal axilReadMaster  : AxiLiteReadMasterType           := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType            := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType          := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType           := AXI_LITE_WRITE_SLAVE_INIT_C;

begin

   ---------------------------------------------------------------------------
   -- Observable AXI channel wiring
   ---------------------------------------------------------------------------
   axiWriteMasters(0).wvalid            <= wrValid;
   axiWriteMasters(0).wlast             <= wrLast;
   axiWriteMasters(0).wstrb(3 downto 0) <= wrStrb;
   axiWriteSlaves(0).wready             <= wrReady;

   axiReadMasters(0).rready <= rdReady;
   axiReadSlaves(0).rvalid  <= rdValid;
   axiReadSlaves(0).rlast   <= rdLast;

   ---------------------------------------------------------------------------
   -- AXI-Lite shim
   ---------------------------------------------------------------------------
   axilResetN <= not axilRst;

   U_AXIL : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 7)
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
   U_DUT : entity surf.AxiMonAxiL
      generic map (
         COMMON_CLK_G    => true,
         AXI_CLK_FREQ_G  => 1000.0,
         AXI_NUM_SLOTS_G => 1,
         AXI_CONFIG_G    => AXI_CONFIG_C)
      port map (
         axiClk           => axiClk,
         axiRst           => axiRst,
         axiWriteMasters  => axiWriteMasters,
         axiWriteSlaves   => axiWriteSlaves,
         axiReadMasters   => axiReadMasters,
         axiReadSlaves    => axiReadSlaves,
         axilClk          => axilClk,
         axilRst          => axilRst,
         sAxilWriteMaster => axilWriteMaster,
         sAxilWriteSlave  => axilWriteSlave,
         sAxilReadMaster  => axilReadMaster,
         sAxilReadSlave   => axilReadSlave);

end architecture rtl;
