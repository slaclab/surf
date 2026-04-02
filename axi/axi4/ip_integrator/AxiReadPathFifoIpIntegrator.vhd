-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP Integrator Wrapper for surf.AxiReadPathFifo
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

entity AxiReadPathFifoIpIntegrator is
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
      S_AXI_ARID     : in  slv(ID_WIDTH_G-1 downto 0);
      S_AXI_ARADDR   : in  slv(ADDR_WIDTH_G-1 downto 0);
      S_AXI_ARLEN    : in  slv(7 downto 0);
      S_AXI_ARSIZE   : in  slv(2 downto 0);
      S_AXI_ARBURST  : in  slv(1 downto 0);
      S_AXI_ARLOCK   : in  sl;
      S_AXI_ARCACHE  : in  slv(3 downto 0);
      S_AXI_ARPROT   : in  slv(2 downto 0);
      S_AXI_ARVALID  : in  sl;
      S_AXI_ARREADY  : out sl;
      S_AXI_RID      : out slv(ID_WIDTH_G-1 downto 0);
      S_AXI_RDATA    : out slv(DATA_WIDTH_G-1 downto 0);
      S_AXI_RRESP    : out slv(1 downto 0);
      S_AXI_RLAST    : out sl;
      S_AXI_RVALID   : out sl;
      S_AXI_RREADY   : in  sl;
      M_AXI_ARID     : out slv(ID_WIDTH_G-1 downto 0);
      M_AXI_ARADDR   : out slv(ADDR_WIDTH_G-1 downto 0);
      M_AXI_ARLEN    : out slv(7 downto 0);
      M_AXI_ARSIZE   : out slv(2 downto 0);
      M_AXI_ARBURST  : out slv(1 downto 0);
      M_AXI_ARLOCK   : out sl;
      M_AXI_ARCACHE  : out slv(3 downto 0);
      M_AXI_ARPROT   : out slv(2 downto 0);
      M_AXI_ARVALID  : out sl;
      M_AXI_ARREADY  : in  sl;
      M_AXI_RID      : in  slv(ID_WIDTH_G-1 downto 0);
      M_AXI_RDATA    : in  slv(DATA_WIDTH_G-1 downto 0);
      M_AXI_RRESP    : in  slv(1 downto 0);
      M_AXI_RLAST    : in  sl;
      M_AXI_RVALID   : in  sl;
      M_AXI_RREADY   : out sl);
end entity AxiReadPathFifoIpIntegrator;

architecture rtl of AxiReadPathFifoIpIntegrator is

   constant AXI_CONFIG_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => ADDR_WIDTH_G,
      DATA_BYTES_C => DATA_WIDTH_G/8,
      ID_BITS_C    => ID_WIDTH_G,
      LEN_BITS_C   => 8);

   signal sAxiResetN   : sl := '1';
   signal mAxiResetN   : sl := '1';
   signal mAxiArLock   : slv(1 downto 0)  := (others => '0');
   signal sAxiReadMaster : AxiReadMasterType := AXI_READ_MASTER_INIT_C;
   signal sAxiReadSlave  : AxiReadSlaveType  := AXI_READ_SLAVE_INIT_C;
   signal mAxiReadMaster : AxiReadMasterType := AXI_READ_MASTER_INIT_C;
   signal mAxiReadSlave  : AxiReadSlaveType  := AXI_READ_SLAVE_INIT_C;

begin

   ---------------------------------------------------------------------------
   -- AXI read shims
   ---------------------------------------------------------------------------
   sAxiResetN <= not sAxiRst;
   mAxiResetN <= not mAxiRst;
   M_AXI_ARLOCK <= mAxiArLock(0);

   U_S_AXI : entity surf.SlaveAxiIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         ID_WIDTH      => ID_WIDTH_G,
         ADDR_WIDTH    => ADDR_WIDTH_G,
         DATA_WIDTH    => DATA_WIDTH_G)
      port map (
         S_AXI_ACLK      => sAxiClk,
         S_AXI_ARESETN   => sAxiResetN,
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
         S_AXI_ARLOCK    => '0' & S_AXI_ARLOCK,
         S_AXI_ARCACHE   => S_AXI_ARCACHE,
         S_AXI_ARPROT    => S_AXI_ARPROT,
         S_AXI_ARREGION  => (others => '0'),
         S_AXI_ARQOS     => (others => '0'),
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
         axiReadMaster   => sAxiReadMaster,
         axiReadSlave    => sAxiReadSlave,
         axiWriteMaster  => open,
         axiWriteSlave   => AXI_WRITE_SLAVE_INIT_C);

   U_M_AXI : entity surf.MasterAxiIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         ID_WIDTH      => ID_WIDTH_G,
         ADDR_WIDTH    => ADDR_WIDTH_G,
         DATA_WIDTH    => DATA_WIDTH_G)
      port map (
         M_AXI_ACLK      => mAxiClk,
         M_AXI_ARESETN   => mAxiResetN,
         M_AXI_AWID      => open,
         M_AXI_AWADDR    => open,
         M_AXI_AWLEN     => open,
         M_AXI_AWSIZE    => open,
         M_AXI_AWBURST   => open,
         M_AXI_AWLOCK    => open,
         M_AXI_AWCACHE   => open,
         M_AXI_AWPROT    => open,
         M_AXI_AWREGION  => open,
         M_AXI_AWQOS     => open,
         M_AXI_AWVALID   => open,
         M_AXI_AWREADY   => '0',
         M_AXI_WID       => open,
         M_AXI_WDATA     => open,
         M_AXI_WSTRB     => open,
         M_AXI_WLAST     => open,
         M_AXI_WVALID    => open,
         M_AXI_WREADY    => '0',
         M_AXI_BID       => (others => '0'),
         M_AXI_BRESP     => (others => '0'),
         M_AXI_BVALID    => '0',
         M_AXI_BREADY    => open,
         M_AXI_ARID      => M_AXI_ARID,
         M_AXI_ARADDR    => M_AXI_ARADDR,
         M_AXI_ARLEN     => M_AXI_ARLEN,
         M_AXI_ARSIZE    => M_AXI_ARSIZE,
         M_AXI_ARBURST   => M_AXI_ARBURST,
         M_AXI_ARLOCK    => mAxiArLock,
         M_AXI_ARCACHE   => M_AXI_ARCACHE,
         M_AXI_ARPROT    => M_AXI_ARPROT,
         M_AXI_ARREGION  => open,
         M_AXI_ARQOS     => open,
         M_AXI_ARVALID   => M_AXI_ARVALID,
         M_AXI_ARREADY   => M_AXI_ARREADY,
         M_AXI_RID       => M_AXI_RID,
         M_AXI_RDATA     => M_AXI_RDATA,
         M_AXI_RRESP     => M_AXI_RRESP,
         M_AXI_RLAST     => M_AXI_RLAST,
         M_AXI_RVALID    => M_AXI_RVALID,
         M_AXI_RREADY    => M_AXI_RREADY,
         axiClk          => open,
         axiRst          => open,
         axiReadMaster   => mAxiReadMaster,
         axiReadSlave    => mAxiReadSlave,
         axiWriteMaster  => AXI_WRITE_MASTER_INIT_C,
         axiWriteSlave   => open);

   ---------------------------------------------------------------------------
   -- DUT
   ---------------------------------------------------------------------------
   U_DUT : entity surf.AxiReadPathFifo
      generic map (
         TPD_G        => TPD_G,
         GEN_SYNC_FIFO_G => false,
         AXI_CONFIG_G => AXI_CONFIG_C)
      port map (
         sAxiClk        => sAxiClk,
         sAxiRst        => sAxiRst,
         sAxiReadMaster => sAxiReadMaster,
         sAxiReadSlave  => sAxiReadSlave,
         mAxiClk        => mAxiClk,
         mAxiRst        => mAxiRst,
         mAxiReadMaster => mAxiReadMaster,
         mAxiReadSlave  => mAxiReadSlave);

end architecture rtl;
