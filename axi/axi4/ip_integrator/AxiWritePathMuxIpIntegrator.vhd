-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP integrator wrapper for surf.AxiWritePathMux
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

entity AxiWritePathMuxIpIntegrator is
   generic (
      TPD_G        : time                      := 1 ns;
      ADDR_WIDTH_G : positive range 12 to 64   := 16;
      DATA_WIDTH_G : positive range 32 to 1024 := 32;
      ID_WIDTH_G   : positive                  := 1);
   port (
      axiClk          : in  sl;
      axiRst          : in  sl;
      S0_AXI_AWID     : in  slv(ID_WIDTH_G-1 downto 0);
      S0_AXI_AWADDR   : in  slv(ADDR_WIDTH_G-1 downto 0);
      S0_AXI_AWLEN    : in  slv(7 downto 0);
      S0_AXI_AWSIZE   : in  slv(2 downto 0);
      S0_AXI_AWBURST  : in  slv(1 downto 0);
      S0_AXI_AWLOCK   : in  sl;
      S0_AXI_AWCACHE  : in  slv(3 downto 0);
      S0_AXI_AWPROT   : in  slv(2 downto 0);
      S0_AXI_AWREGION : in  slv(3 downto 0);
      S0_AXI_AWQOS    : in  slv(3 downto 0);
      S0_AXI_AWVALID  : in  sl;
      S0_AXI_AWREADY  : out sl;
      S0_AXI_WID      : in  slv(ID_WIDTH_G-1 downto 0);
      S0_AXI_WDATA    : in  slv(DATA_WIDTH_G-1 downto 0);
      S0_AXI_WSTRB    : in  slv((DATA_WIDTH_G/8)-1 downto 0);
      S0_AXI_WLAST    : in  sl;
      S0_AXI_WVALID   : in  sl;
      S0_AXI_WREADY   : out sl;
      S0_AXI_BID      : out slv(ID_WIDTH_G-1 downto 0);
      S0_AXI_BRESP    : out slv(1 downto 0);
      S0_AXI_BVALID   : out sl;
      S0_AXI_BREADY   : in  sl;
      S1_AXI_AWID     : in  slv(ID_WIDTH_G-1 downto 0);
      S1_AXI_AWADDR   : in  slv(ADDR_WIDTH_G-1 downto 0);
      S1_AXI_AWLEN    : in  slv(7 downto 0);
      S1_AXI_AWSIZE   : in  slv(2 downto 0);
      S1_AXI_AWBURST  : in  slv(1 downto 0);
      S1_AXI_AWLOCK   : in  sl;
      S1_AXI_AWCACHE  : in  slv(3 downto 0);
      S1_AXI_AWPROT   : in  slv(2 downto 0);
      S1_AXI_AWREGION : in  slv(3 downto 0);
      S1_AXI_AWQOS    : in  slv(3 downto 0);
      S1_AXI_AWVALID  : in  sl;
      S1_AXI_AWREADY  : out sl;
      S1_AXI_WID      : in  slv(ID_WIDTH_G-1 downto 0);
      S1_AXI_WDATA    : in  slv(DATA_WIDTH_G-1 downto 0);
      S1_AXI_WSTRB    : in  slv((DATA_WIDTH_G/8)-1 downto 0);
      S1_AXI_WLAST    : in  sl;
      S1_AXI_WVALID   : in  sl;
      S1_AXI_WREADY   : out sl;
      S1_AXI_BID      : out slv(ID_WIDTH_G-1 downto 0);
      S1_AXI_BRESP    : out slv(1 downto 0);
      S1_AXI_BVALID   : out sl;
      S1_AXI_BREADY   : in  sl;
      M_AXI_AWID      : out slv(ID_WIDTH_G-1 downto 0);
      M_AXI_AWADDR    : out slv(ADDR_WIDTH_G-1 downto 0);
      M_AXI_AWLEN     : out slv(7 downto 0);
      M_AXI_AWSIZE    : out slv(2 downto 0);
      M_AXI_AWBURST   : out slv(1 downto 0);
      M_AXI_AWLOCK    : out sl;
      M_AXI_AWCACHE   : out slv(3 downto 0);
      M_AXI_AWPROT    : out slv(2 downto 0);
      M_AXI_AWREGION  : out slv(3 downto 0);
      M_AXI_AWQOS     : out slv(3 downto 0);
      M_AXI_AWVALID   : out sl;
      M_AXI_AWREADY   : in  sl;
      M_AXI_WID       : out slv(ID_WIDTH_G-1 downto 0);
      M_AXI_WDATA     : out slv(DATA_WIDTH_G-1 downto 0);
      M_AXI_WSTRB     : out slv((DATA_WIDTH_G/8)-1 downto 0);
      M_AXI_WLAST     : out sl;
      M_AXI_WVALID    : out sl;
      M_AXI_WREADY    : in  sl;
      M_AXI_BID       : in  slv(ID_WIDTH_G-1 downto 0);
      M_AXI_BRESP     : in  slv(1 downto 0);
      M_AXI_BVALID    : in  sl;
      M_AXI_BREADY    : out sl);
end entity AxiWritePathMuxIpIntegrator;

architecture rtl of AxiWritePathMuxIpIntegrator is

   signal axiResetN        : sl                              := '1';
   signal mAxiAwLock       : slv(1 downto 0)                 := (others => '0');
   signal sAxiWriteMasters : AxiWriteMasterArray(1 downto 0) := (others => AXI_WRITE_MASTER_INIT_C);
   signal sAxiWriteSlaves  : AxiWriteSlaveArray(1 downto 0)  := (others => AXI_WRITE_SLAVE_INIT_C);
   signal mAxiWriteMaster  : AxiWriteMasterType              := AXI_WRITE_MASTER_INIT_C;
   signal mAxiWriteSlave   : AxiWriteSlaveType               := AXI_WRITE_SLAVE_INIT_C;

begin

   axiResetN <= not axiRst;

   M_AXI_AWLOCK <= mAxiAwLock(0);

   U_S0 : entity surf.SlaveAxiIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         ID_WIDTH      => ID_WIDTH_G,
         ADDR_WIDTH    => ADDR_WIDTH_G,
         DATA_WIDTH    => DATA_WIDTH_G)
      port map (
         S_AXI_ACLK     => axiClk,
         S_AXI_ARESETN  => axiResetN,
         S_AXI_AWID     => S0_AXI_AWID,
         S_AXI_AWADDR   => S0_AXI_AWADDR,
         S_AXI_AWLEN    => S0_AXI_AWLEN,
         S_AXI_AWSIZE   => S0_AXI_AWSIZE,
         S_AXI_AWBURST  => S0_AXI_AWBURST,
         S_AXI_AWLOCK   => '0' & S0_AXI_AWLOCK,
         S_AXI_AWCACHE  => S0_AXI_AWCACHE,
         S_AXI_AWPROT   => S0_AXI_AWPROT,
         S_AXI_AWREGION => S0_AXI_AWREGION,
         S_AXI_AWQOS    => S0_AXI_AWQOS,
         S_AXI_AWVALID  => S0_AXI_AWVALID,
         S_AXI_AWREADY  => S0_AXI_AWREADY,
         S_AXI_WID      => S0_AXI_WID,
         S_AXI_WDATA    => S0_AXI_WDATA,
         S_AXI_WSTRB    => S0_AXI_WSTRB,
         S_AXI_WLAST    => S0_AXI_WLAST,
         S_AXI_WVALID   => S0_AXI_WVALID,
         S_AXI_WREADY   => S0_AXI_WREADY,
         S_AXI_BID      => S0_AXI_BID,
         S_AXI_BRESP    => S0_AXI_BRESP,
         S_AXI_BVALID   => S0_AXI_BVALID,
         S_AXI_BREADY   => S0_AXI_BREADY,
         S_AXI_ARID     => (others => '0'),
         S_AXI_ARADDR   => (others => '0'),
         S_AXI_ARLEN    => (others => '0'),
         S_AXI_ARSIZE   => (others => '0'),
         S_AXI_ARBURST  => (others => '0'),
         S_AXI_ARLOCK   => (others => '0'),
         S_AXI_ARCACHE  => (others => '0'),
         S_AXI_ARPROT   => (others => '0'),
         S_AXI_ARREGION => (others => '0'),
         S_AXI_ARQOS    => (others => '0'),
         S_AXI_ARVALID  => '0',
         S_AXI_ARREADY  => open,
         S_AXI_RID      => open,
         S_AXI_RDATA    => open,
         S_AXI_RRESP    => open,
         S_AXI_RLAST    => open,
         S_AXI_RVALID   => open,
         S_AXI_RREADY   => '0',
         axiClk         => open,
         axiRst         => open,
         axiReadMaster  => open,
         axiReadSlave   => AXI_READ_SLAVE_INIT_C,
         axiWriteMaster => sAxiWriteMasters(0),
         axiWriteSlave  => sAxiWriteSlaves(0));

   U_S1 : entity surf.SlaveAxiIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         ID_WIDTH      => ID_WIDTH_G,
         ADDR_WIDTH    => ADDR_WIDTH_G,
         DATA_WIDTH    => DATA_WIDTH_G)
      port map (
         S_AXI_ACLK     => axiClk,
         S_AXI_ARESETN  => axiResetN,
         S_AXI_AWID     => S1_AXI_AWID,
         S_AXI_AWADDR   => S1_AXI_AWADDR,
         S_AXI_AWLEN    => S1_AXI_AWLEN,
         S_AXI_AWSIZE   => S1_AXI_AWSIZE,
         S_AXI_AWBURST  => S1_AXI_AWBURST,
         S_AXI_AWLOCK   => '0' & S1_AXI_AWLOCK,
         S_AXI_AWCACHE  => S1_AXI_AWCACHE,
         S_AXI_AWPROT   => S1_AXI_AWPROT,
         S_AXI_AWREGION => S1_AXI_AWREGION,
         S_AXI_AWQOS    => S1_AXI_AWQOS,
         S_AXI_AWVALID  => S1_AXI_AWVALID,
         S_AXI_AWREADY  => S1_AXI_AWREADY,
         S_AXI_WID      => S1_AXI_WID,
         S_AXI_WDATA    => S1_AXI_WDATA,
         S_AXI_WSTRB    => S1_AXI_WSTRB,
         S_AXI_WLAST    => S1_AXI_WLAST,
         S_AXI_WVALID   => S1_AXI_WVALID,
         S_AXI_WREADY   => S1_AXI_WREADY,
         S_AXI_BID      => S1_AXI_BID,
         S_AXI_BRESP    => S1_AXI_BRESP,
         S_AXI_BVALID   => S1_AXI_BVALID,
         S_AXI_BREADY   => S1_AXI_BREADY,
         S_AXI_ARID     => (others => '0'),
         S_AXI_ARADDR   => (others => '0'),
         S_AXI_ARLEN    => (others => '0'),
         S_AXI_ARSIZE   => (others => '0'),
         S_AXI_ARBURST  => (others => '0'),
         S_AXI_ARLOCK   => (others => '0'),
         S_AXI_ARCACHE  => (others => '0'),
         S_AXI_ARPROT   => (others => '0'),
         S_AXI_ARREGION => (others => '0'),
         S_AXI_ARQOS    => (others => '0'),
         S_AXI_ARVALID  => '0',
         S_AXI_ARREADY  => open,
         S_AXI_RID      => open,
         S_AXI_RDATA    => open,
         S_AXI_RRESP    => open,
         S_AXI_RLAST    => open,
         S_AXI_RVALID   => open,
         S_AXI_RREADY   => '0',
         axiClk         => open,
         axiRst         => open,
         axiReadMaster  => open,
         axiReadSlave   => AXI_READ_SLAVE_INIT_C,
         axiWriteMaster => sAxiWriteMasters(1),
         axiWriteSlave  => sAxiWriteSlaves(1));

   U_M : entity surf.MasterAxiIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         ID_WIDTH      => ID_WIDTH_G,
         ADDR_WIDTH    => ADDR_WIDTH_G,
         DATA_WIDTH    => DATA_WIDTH_G)
      port map (
         M_AXI_ACLK     => axiClk,
         M_AXI_ARESETN  => axiResetN,
         M_AXI_AWID     => M_AXI_AWID,
         M_AXI_AWADDR   => M_AXI_AWADDR,
         M_AXI_AWLEN    => M_AXI_AWLEN,
         M_AXI_AWSIZE   => M_AXI_AWSIZE,
         M_AXI_AWBURST  => M_AXI_AWBURST,
         M_AXI_AWLOCK   => mAxiAwLock,
         M_AXI_AWCACHE  => M_AXI_AWCACHE,
         M_AXI_AWPROT   => M_AXI_AWPROT,
         M_AXI_AWREGION => M_AXI_AWREGION,
         M_AXI_AWQOS    => M_AXI_AWQOS,
         M_AXI_AWVALID  => M_AXI_AWVALID,
         M_AXI_AWREADY  => M_AXI_AWREADY,
         M_AXI_WID      => M_AXI_WID,
         M_AXI_WDATA    => M_AXI_WDATA,
         M_AXI_WSTRB    => M_AXI_WSTRB,
         M_AXI_WLAST    => M_AXI_WLAST,
         M_AXI_WVALID   => M_AXI_WVALID,
         M_AXI_WREADY   => M_AXI_WREADY,
         M_AXI_BID      => M_AXI_BID,
         M_AXI_BRESP    => M_AXI_BRESP,
         M_AXI_BVALID   => M_AXI_BVALID,
         M_AXI_BREADY   => M_AXI_BREADY,
         M_AXI_ARID     => open,
         M_AXI_ARADDR   => open,
         M_AXI_ARLEN    => open,
         M_AXI_ARSIZE   => open,
         M_AXI_ARBURST  => open,
         M_AXI_ARLOCK   => open,
         M_AXI_ARCACHE  => open,
         M_AXI_ARPROT   => open,
         M_AXI_ARREGION => open,
         M_AXI_ARQOS    => open,
         M_AXI_ARVALID  => open,
         M_AXI_ARREADY  => '0',
         M_AXI_RID      => (others => '0'),
         M_AXI_RDATA    => (others => '0'),
         M_AXI_RRESP    => (others => '0'),
         M_AXI_RLAST    => '0',
         M_AXI_RVALID   => '0',
         M_AXI_RREADY   => open,
         axiClk         => open,
         axiRst         => open,
         axiReadMaster  => AXI_READ_MASTER_INIT_C,
         axiReadSlave   => open,
         axiWriteMaster => mAxiWriteMaster,
         axiWriteSlave  => mAxiWriteSlave);

   U_DUT : entity surf.AxiWritePathMux
      generic map (
         TPD_G        => TPD_G,
         NUM_SLAVES_G => 2)
      port map (
         axiClk           => axiClk,
         axiRst           => axiRst,
         sAxiWriteMasters => sAxiWriteMasters,
         sAxiWriteSlaves  => sAxiWriteSlaves,
         mAxiWriteMaster  => mAxiWriteMaster,
         mAxiWriteSlave   => mAxiWriteSlave);

end architecture rtl;
