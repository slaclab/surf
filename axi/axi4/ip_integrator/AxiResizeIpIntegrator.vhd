-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP integrator wrapper for surf.AxiResize
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

entity AxiResizeIpIntegrator is
   generic (
      TPD_G               : time                    := 1 ns;
      ADDR_WIDTH_G        : positive range 12 to 64 := 16;
      ID_WIDTH_G          : positive                := 4;
      SLAVE_DATA_BYTES_G  : positive                := 4;
      MASTER_DATA_BYTES_G : positive                := 8);
   port (
      axiClk         : in  sl;
      axiRst         : in  sl;
      S_AXI_AWID     : in  slv(ID_WIDTH_G-1 downto 0);
      S_AXI_AWADDR   : in  slv(ADDR_WIDTH_G-1 downto 0);
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
      S_AXI_WID      : in  slv(ID_WIDTH_G-1 downto 0);
      S_AXI_WDATA    : in  slv((SLAVE_DATA_BYTES_G*8)-1 downto 0);
      S_AXI_WSTRB    : in  slv(SLAVE_DATA_BYTES_G-1 downto 0);
      S_AXI_WLAST    : in  sl;
      S_AXI_WVALID   : in  sl;
      S_AXI_WREADY   : out sl;
      S_AXI_BID      : out slv(ID_WIDTH_G-1 downto 0);
      S_AXI_BRESP    : out slv(1 downto 0);
      S_AXI_BVALID   : out sl;
      S_AXI_BREADY   : in  sl;
      S_AXI_ARID     : in  slv(ID_WIDTH_G-1 downto 0);
      S_AXI_ARADDR   : in  slv(ADDR_WIDTH_G-1 downto 0);
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
      S_AXI_RID      : out slv(ID_WIDTH_G-1 downto 0);
      S_AXI_RDATA    : out slv((SLAVE_DATA_BYTES_G*8)-1 downto 0);
      S_AXI_RRESP    : out slv(1 downto 0);
      S_AXI_RLAST    : out sl;
      S_AXI_RVALID   : out sl;
      S_AXI_RREADY   : in  sl;
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
      M_AXI_WDATA    : out slv((MASTER_DATA_BYTES_G*8)-1 downto 0);
      M_AXI_WSTRB    : out slv(MASTER_DATA_BYTES_G-1 downto 0);
      M_AXI_WLAST    : out sl;
      M_AXI_WVALID   : out sl;
      M_AXI_WREADY   : in  sl;
      M_AXI_BID      : in  slv(ID_WIDTH_G-1 downto 0);
      M_AXI_BRESP    : in  slv(1 downto 0);
      M_AXI_BVALID   : in  sl;
      M_AXI_BREADY   : out sl;
      M_AXI_ARID     : out slv(ID_WIDTH_G-1 downto 0);
      M_AXI_ARADDR   : out slv(ADDR_WIDTH_G-1 downto 0);
      M_AXI_ARLEN    : out slv(7 downto 0);
      M_AXI_ARSIZE   : out slv(2 downto 0);
      M_AXI_ARBURST  : out slv(1 downto 0);
      M_AXI_ARLOCK   : out sl;
      M_AXI_ARCACHE  : out slv(3 downto 0);
      M_AXI_ARPROT   : out slv(2 downto 0);
      M_AXI_ARREGION : out slv(3 downto 0);
      M_AXI_ARQOS    : out slv(3 downto 0);
      M_AXI_ARVALID  : out sl;
      M_AXI_ARREADY  : in  sl;
      M_AXI_RID      : in  slv(ID_WIDTH_G-1 downto 0);
      M_AXI_RDATA    : in  slv((MASTER_DATA_BYTES_G*8)-1 downto 0);
      M_AXI_RRESP    : in  slv(1 downto 0);
      M_AXI_RLAST    : in  sl;
      M_AXI_RVALID   : in  sl;
      M_AXI_RREADY   : out sl);
end entity AxiResizeIpIntegrator;

architecture rtl of AxiResizeIpIntegrator is

   constant SLAVE_AXI_CONFIG_C  : AxiConfigType := axiConfig(ADDR_WIDTH_G, SLAVE_DATA_BYTES_G, ID_WIDTH_G, 8);
   constant MASTER_AXI_CONFIG_C : AxiConfigType := axiConfig(ADDR_WIDTH_G, MASTER_DATA_BYTES_G, ID_WIDTH_G, 8);

   signal axiResetN       : sl                 := '1';
   signal mAxiAwLock      : slv(1 downto 0)    := (others => '0');
   signal mAxiArLock      : slv(1 downto 0)    := (others => '0');
   signal sAxiReadMaster  : AxiReadMasterType  := AXI_READ_MASTER_INIT_C;
   signal sAxiReadSlave   : AxiReadSlaveType   := AXI_READ_SLAVE_INIT_C;
   signal sAxiWriteMaster : AxiWriteMasterType := AXI_WRITE_MASTER_INIT_C;
   signal sAxiWriteSlave  : AxiWriteSlaveType  := AXI_WRITE_SLAVE_INIT_C;
   signal mAxiReadMaster  : AxiReadMasterType  := AXI_READ_MASTER_INIT_C;
   signal mAxiReadSlave   : AxiReadSlaveType   := AXI_READ_SLAVE_INIT_C;
   signal mAxiWriteMaster : AxiWriteMasterType := AXI_WRITE_MASTER_INIT_C;
   signal mAxiWriteSlave  : AxiWriteSlaveType  := AXI_WRITE_SLAVE_INIT_C;

begin

   axiResetN <= not axiRst;

   M_AXI_AWLOCK <= mAxiAwLock(0);
   M_AXI_ARLOCK <= mAxiArLock(0);

   U_S : entity surf.SlaveAxiIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         ID_WIDTH      => ID_WIDTH_G,
         ADDR_WIDTH    => ADDR_WIDTH_G,
         DATA_WIDTH    => SLAVE_DATA_BYTES_G*8)
      port map (
         S_AXI_ACLK     => axiClk,
         S_AXI_ARESETN  => axiResetN,
         S_AXI_AWID     => S_AXI_AWID,
         S_AXI_AWADDR   => S_AXI_AWADDR,
         S_AXI_AWLEN    => S_AXI_AWLEN,
         S_AXI_AWSIZE   => S_AXI_AWSIZE,
         S_AXI_AWBURST  => S_AXI_AWBURST,
         S_AXI_AWLOCK   => '0' & S_AXI_AWLOCK,
         S_AXI_AWCACHE  => S_AXI_AWCACHE,
         S_AXI_AWPROT   => S_AXI_AWPROT,
         S_AXI_AWREGION => S_AXI_AWREGION,
         S_AXI_AWQOS    => S_AXI_AWQOS,
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
         S_AXI_ARID     => S_AXI_ARID,
         S_AXI_ARADDR   => S_AXI_ARADDR,
         S_AXI_ARLEN    => S_AXI_ARLEN,
         S_AXI_ARSIZE   => S_AXI_ARSIZE,
         S_AXI_ARBURST  => S_AXI_ARBURST,
         S_AXI_ARLOCK   => '0' & S_AXI_ARLOCK,
         S_AXI_ARCACHE  => S_AXI_ARCACHE,
         S_AXI_ARPROT   => S_AXI_ARPROT,
         S_AXI_ARREGION => S_AXI_ARREGION,
         S_AXI_ARQOS    => S_AXI_ARQOS,
         S_AXI_ARVALID  => S_AXI_ARVALID,
         S_AXI_ARREADY  => S_AXI_ARREADY,
         S_AXI_RID      => S_AXI_RID,
         S_AXI_RDATA    => S_AXI_RDATA,
         S_AXI_RRESP    => S_AXI_RRESP,
         S_AXI_RLAST    => S_AXI_RLAST,
         S_AXI_RVALID   => S_AXI_RVALID,
         S_AXI_RREADY   => S_AXI_RREADY,
         axiClk         => open,
         axiRst         => open,
         axiReadMaster  => sAxiReadMaster,
         axiReadSlave   => sAxiReadSlave,
         axiWriteMaster => sAxiWriteMaster,
         axiWriteSlave  => sAxiWriteSlave);

   U_M : entity surf.MasterAxiIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         ID_WIDTH      => ID_WIDTH_G,
         ADDR_WIDTH    => ADDR_WIDTH_G,
         DATA_WIDTH    => MASTER_DATA_BYTES_G*8)
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
         M_AXI_ARID     => M_AXI_ARID,
         M_AXI_ARADDR   => M_AXI_ARADDR,
         M_AXI_ARLEN    => M_AXI_ARLEN,
         M_AXI_ARSIZE   => M_AXI_ARSIZE,
         M_AXI_ARBURST  => M_AXI_ARBURST,
         M_AXI_ARLOCK   => mAxiArLock,
         M_AXI_ARCACHE  => M_AXI_ARCACHE,
         M_AXI_ARPROT   => M_AXI_ARPROT,
         M_AXI_ARREGION => M_AXI_ARREGION,
         M_AXI_ARQOS    => M_AXI_ARQOS,
         M_AXI_ARVALID  => M_AXI_ARVALID,
         M_AXI_ARREADY  => M_AXI_ARREADY,
         M_AXI_RID      => M_AXI_RID,
         M_AXI_RDATA    => M_AXI_RDATA,
         M_AXI_RRESP    => M_AXI_RRESP,
         M_AXI_RLAST    => M_AXI_RLAST,
         M_AXI_RVALID   => M_AXI_RVALID,
         M_AXI_RREADY   => M_AXI_RREADY,
         axiClk         => open,
         axiRst         => open,
         axiReadMaster  => mAxiReadMaster,
         axiReadSlave   => mAxiReadSlave,
         axiWriteMaster => mAxiWriteMaster,
         axiWriteSlave  => mAxiWriteSlave);

   U_DUT : entity surf.AxiResize
      generic map (
         TPD_G               => TPD_G,
         SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_C,
         MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_C)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         sAxiReadMaster  => sAxiReadMaster,
         sAxiReadSlave   => sAxiReadSlave,
         sAxiWriteMaster => sAxiWriteMaster,
         sAxiWriteSlave  => sAxiWriteSlave,
         mAxiReadMaster  => mAxiReadMaster,
         mAxiReadSlave   => mAxiReadSlave,
         mAxiWriteMaster => mAxiWriteMaster,
         mAxiWriteSlave  => mAxiWriteSlave);

end architecture rtl;
