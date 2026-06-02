-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP Integrator Wrapper for surf.AxiWritePathFifo
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

entity AxiWritePathFifoIpIntegrator is
   generic (
      TPD_G        : time                      := 1 ns;
      ADDR_WIDTH_G : positive range 12 to 64   := 16;
      DATA_WIDTH_G : positive range 32 to 1024 := 32;
      ID_WIDTH_G   : positive                  := 4);
   port (
      sAxiClk        : in  sl;
      sAxiRst        : in  sl;
      mAxiClk        : in  sl;
      mAxiRst        : in  sl;
      S_AXI_AWID     : in  slv(ID_WIDTH_G-1 downto 0);
      S_AXI_AWADDR   : in  slv(ADDR_WIDTH_G-1 downto 0);
      S_AXI_AWLEN    : in  slv(7 downto 0);
      S_AXI_AWSIZE   : in  slv(2 downto 0);
      S_AXI_AWBURST  : in  slv(1 downto 0);
      S_AXI_AWLOCK   : in  sl;
      S_AXI_AWCACHE  : in  slv(3 downto 0);
      S_AXI_AWPROT   : in  slv(2 downto 0);
      S_AXI_AWVALID  : in  sl;
      S_AXI_AWREADY  : out sl;
      S_AXI_WID      : in  slv(ID_WIDTH_G-1 downto 0);
      S_AXI_WDATA    : in  slv(DATA_WIDTH_G-1 downto 0);
      S_AXI_WSTRB    : in  slv((DATA_WIDTH_G/8)-1 downto 0);
      S_AXI_WLAST    : in  sl;
      S_AXI_WVALID   : in  sl;
      S_AXI_WREADY   : out sl;
      S_AXI_BID      : out slv(ID_WIDTH_G-1 downto 0);
      S_AXI_BRESP    : out slv(1 downto 0);
      S_AXI_BVALID   : out sl;
      S_AXI_BREADY   : in  sl;
      writePause     : out sl;
      M_AXI_AWID     : out slv(ID_WIDTH_G-1 downto 0);
      M_AXI_AWADDR   : out slv(ADDR_WIDTH_G-1 downto 0);
      M_AXI_AWLEN    : out slv(7 downto 0);
      M_AXI_AWSIZE   : out slv(2 downto 0);
      M_AXI_AWBURST  : out slv(1 downto 0);
      M_AXI_AWLOCK   : out sl;
      M_AXI_AWCACHE  : out slv(3 downto 0);
      M_AXI_AWPROT   : out slv(2 downto 0);
      M_AXI_AWREGION : out slv(3 downto 0);
      M_AXI_AWQOS    : out slv(3 downto 0);
      M_AXI_AWVALID  : out sl;
      M_AXI_AWREADY  : in  sl;
      M_AXI_WID      : out slv(ID_WIDTH_G-1 downto 0);
      M_AXI_WDATA    : out slv(DATA_WIDTH_G-1 downto 0);
      M_AXI_WSTRB    : out slv((DATA_WIDTH_G/8)-1 downto 0);
      M_AXI_WLAST    : out sl;
      M_AXI_WVALID   : out sl;
      M_AXI_WREADY   : in  sl;
      M_AXI_BID      : in  slv(ID_WIDTH_G-1 downto 0);
      M_AXI_BRESP    : in  slv(1 downto 0);
      M_AXI_BVALID   : in  sl;
      M_AXI_BREADY   : out sl);
end entity AxiWritePathFifoIpIntegrator;

architecture rtl of AxiWritePathFifoIpIntegrator is

   constant AXI_CONFIG_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => ADDR_WIDTH_G,
      DATA_BYTES_C => DATA_WIDTH_G/8,
      ID_BITS_C    => ID_WIDTH_G,
      LEN_BITS_C   => 8);

   signal sAxiResetN      : sl                 := '1';
   signal mAxiResetN      : sl                 := '1';
   signal mAxiAwLock      : slv(1 downto 0)    := (others => '0');
   signal sAxiWriteMaster : AxiWriteMasterType := AXI_WRITE_MASTER_INIT_C;
   signal sAxiWriteSlave  : AxiWriteSlaveType  := AXI_WRITE_SLAVE_INIT_C;
   signal sAxiCtrl        : AxiCtrlType        := AXI_CTRL_INIT_C;
   signal mAxiWriteMaster : AxiWriteMasterType := AXI_WRITE_MASTER_INIT_C;
   signal mAxiWriteSlave  : AxiWriteSlaveType  := AXI_WRITE_SLAVE_INIT_C;

begin

   ---------------------------------------------------------------------------
   -- AXI write shims
   ---------------------------------------------------------------------------
   sAxiResetN   <= not sAxiRst;
   mAxiResetN   <= not mAxiRst;
   M_AXI_AWLOCK <= mAxiAwLock(0);
   writePause   <= sAxiCtrl.pause;

   U_S_AXI : entity surf.SlaveAxiIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         ID_WIDTH      => ID_WIDTH_G,
         ADDR_WIDTH    => ADDR_WIDTH_G,
         DATA_WIDTH    => DATA_WIDTH_G)
      port map (
         S_AXI_ACLK     => sAxiClk,
         S_AXI_ARESETN  => sAxiResetN,
         S_AXI_AWID     => S_AXI_AWID,
         S_AXI_AWADDR   => S_AXI_AWADDR,
         S_AXI_AWLEN    => S_AXI_AWLEN,
         S_AXI_AWSIZE   => S_AXI_AWSIZE,
         S_AXI_AWBURST  => S_AXI_AWBURST,
         S_AXI_AWLOCK   => '0' & S_AXI_AWLOCK,
         S_AXI_AWCACHE  => S_AXI_AWCACHE,
         S_AXI_AWPROT   => S_AXI_AWPROT,
         S_AXI_AWREGION => (others => '0'),
         S_AXI_AWQOS    => (others => '0'),
         S_AXI_AWVALID  => S_AXI_AWVALID,
         S_AXI_AWREADY  => S_AXI_AWREADY,
         S_AXI_WID      => S_AXI_WID,
         S_AXI_WDATA    => S_AXI_WDATA,
         S_AXI_WSTRB    => S_AXI_WSTRB,
         S_AXI_WLAST    => S_AXI_WLAST,
         S_AXI_WVALID   => S_AXI_WVALID,
         S_AXI_WREADY   => S_AXI_WREADY,
         S_AXI_BID      => S_AXI_BID,
         S_AXI_BRESP    => S_AXI_BRESP,
         S_AXI_BVALID   => S_AXI_BVALID,
         S_AXI_BREADY   => S_AXI_BREADY,
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
         axiWriteMaster => sAxiWriteMaster,
         axiWriteSlave  => sAxiWriteSlave);

   U_M_AXI : entity surf.MasterAxiIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         ID_WIDTH      => ID_WIDTH_G,
         ADDR_WIDTH    => ADDR_WIDTH_G,
         DATA_WIDTH    => DATA_WIDTH_G)
      port map (
         M_AXI_ACLK     => mAxiClk,
         M_AXI_ARESETN  => mAxiResetN,
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

   ---------------------------------------------------------------------------
   -- DUT
   ---------------------------------------------------------------------------
   U_DUT : entity surf.AxiWritePathFifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => false,
         AXI_CONFIG_G    => AXI_CONFIG_C)
      port map (
         sAxiClk         => sAxiClk,
         sAxiRst         => sAxiRst,
         sAxiWriteMaster => sAxiWriteMaster,
         sAxiWriteSlave  => sAxiWriteSlave,
         sAxiCtrl        => sAxiCtrl,
         mAxiClk         => mAxiClk,
         mAxiRst         => mAxiRst,
         mAxiWriteMaster => mAxiWriteMaster,
         mAxiWriteSlave  => mAxiWriteSlave);

end architecture rtl;
