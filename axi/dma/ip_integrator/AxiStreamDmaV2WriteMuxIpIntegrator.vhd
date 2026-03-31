-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP integrator wrapper for surf.AxiStreamDmaV2WriteMux
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

entity AxiStreamDmaV2WriteMuxIpIntegrator is
   generic (
      TPD_G             : time     := 1 ns;
      AXI_READY_EN_G    : boolean  := false;
      ACK_WAIT_BVALID_G : boolean  := false;
      DATA_BYTES_G      : positive := 4);
   port (
      axiClk             : in  sl;
      axiRst             : in  sl;
      dataWriteCtrlPause : out sl;
      dataWriteCtrlOver  : out sl;
      mAxiWriteCtrlPause : in  sl                             := '0';
      mAxiWriteCtrlOver  : in  sl                             := '0';
      DATA_AXI_AWID      : in  slv(3 downto 0)                := (others => '0');
      DATA_AXI_AWADDR    : in  slv(15 downto 0)               := (others => '0');
      DATA_AXI_AWLEN     : in  slv(7 downto 0)                := (others => '0');
      DATA_AXI_AWSIZE    : in  slv(2 downto 0)                := (others => '0');
      DATA_AXI_AWBURST   : in  slv(1 downto 0)                := (others => '0');
      DATA_AXI_AWLOCK    : in  sl                             := '0';
      DATA_AXI_AWCACHE   : in  slv(3 downto 0)                := (others => '0');
      DATA_AXI_AWPROT    : in  slv(2 downto 0)                := (others => '0');
      DATA_AXI_AWREGION  : in  slv(3 downto 0)                := (others => '0');
      DATA_AXI_AWQOS     : in  slv(3 downto 0)                := (others => '0');
      DATA_AXI_AWVALID   : in  sl                             := '0';
      DATA_AXI_AWREADY   : out sl;
      DATA_AXI_WID       : in  slv(3 downto 0)                := (others => '0');
      DATA_AXI_WDATA     : in  slv(DATA_BYTES_G*8-1 downto 0) := (others => '0');
      DATA_AXI_WSTRB     : in  slv(DATA_BYTES_G-1 downto 0)   := (others => '0');
      DATA_AXI_WLAST     : in  sl                             := '0';
      DATA_AXI_WVALID    : in  sl                             := '0';
      DATA_AXI_WREADY    : out sl;
      DATA_AXI_BID       : out slv(3 downto 0);
      DATA_AXI_BRESP     : out slv(1 downto 0);
      DATA_AXI_BVALID    : out sl;
      DATA_AXI_BREADY    : in  sl                             := '0';
      DESC_AXI_AWID      : in  slv(3 downto 0)                := (others => '0');
      DESC_AXI_AWADDR    : in  slv(15 downto 0)               := (others => '0');
      DESC_AXI_AWLEN     : in  slv(7 downto 0)                := (others => '0');
      DESC_AXI_AWSIZE    : in  slv(2 downto 0)                := (others => '0');
      DESC_AXI_AWBURST   : in  slv(1 downto 0)                := (others => '0');
      DESC_AXI_AWLOCK    : in  sl                             := '0';
      DESC_AXI_AWCACHE   : in  slv(3 downto 0)                := (others => '0');
      DESC_AXI_AWPROT    : in  slv(2 downto 0)                := (others => '0');
      DESC_AXI_AWREGION  : in  slv(3 downto 0)                := (others => '0');
      DESC_AXI_AWQOS     : in  slv(3 downto 0)                := (others => '0');
      DESC_AXI_AWVALID   : in  sl                             := '0';
      DESC_AXI_AWREADY   : out sl;
      DESC_AXI_WID       : in  slv(3 downto 0)                := (others => '0');
      DESC_AXI_WDATA     : in  slv(DATA_BYTES_G*8-1 downto 0) := (others => '0');
      DESC_AXI_WSTRB     : in  slv(DATA_BYTES_G-1 downto 0)   := (others => '0');
      DESC_AXI_WLAST     : in  sl                             := '0';
      DESC_AXI_WVALID    : in  sl                             := '0';
      DESC_AXI_WREADY    : out sl;
      DESC_AXI_BID       : out slv(3 downto 0);
      DESC_AXI_BRESP     : out slv(1 downto 0);
      DESC_AXI_BVALID    : out sl;
      DESC_AXI_BREADY    : in  sl                             := '0';
      M_AXI_AWID         : out slv(3 downto 0);
      M_AXI_AWADDR       : out slv(15 downto 0);
      M_AXI_AWLEN        : out slv(7 downto 0);
      M_AXI_AWSIZE       : out slv(2 downto 0);
      M_AXI_AWBURST      : out slv(1 downto 0);
      M_AXI_AWLOCK       : out sl;
      M_AXI_AWCACHE      : out slv(3 downto 0);
      M_AXI_AWPROT       : out slv(2 downto 0);
      M_AXI_AWREGION     : out slv(3 downto 0);
      M_AXI_AWQOS        : out slv(3 downto 0);
      M_AXI_AWVALID      : out sl;
      M_AXI_AWREADY      : in  sl;
      M_AXI_WID          : out slv(3 downto 0);
      M_AXI_WDATA        : out slv(DATA_BYTES_G*8-1 downto 0);
      M_AXI_WSTRB        : out slv(DATA_BYTES_G-1 downto 0);
      M_AXI_WLAST        : out sl;
      M_AXI_WVALID       : out sl;
      M_AXI_WREADY       : in  sl;
      M_AXI_BID          : in  slv(3 downto 0);
      M_AXI_BRESP        : in  slv(1 downto 0);
      M_AXI_BVALID       : in  sl;
      M_AXI_BREADY       : out sl);
end entity AxiStreamDmaV2WriteMuxIpIntegrator;

architecture rtl of AxiStreamDmaV2WriteMuxIpIntegrator is

   constant AXI_CONFIG_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => 16,
      DATA_BYTES_C => DATA_BYTES_G,
      ID_BITS_C    => 4,
      LEN_BITS_C   => 8);

   signal dataWriteMaster : AxiWriteMasterType := AXI_WRITE_MASTER_INIT_C;
   signal dataWriteSlave  : AxiWriteSlaveType  := AXI_WRITE_SLAVE_INIT_C;
   signal dataWriteCtrl   : AxiCtrlType        := AXI_CTRL_UNUSED_C;
   signal descWriteMaster : AxiWriteMasterType := AXI_WRITE_MASTER_INIT_C;
   signal descWriteSlave  : AxiWriteSlaveType  := AXI_WRITE_SLAVE_INIT_C;
   signal mAxiWriteMaster : AxiWriteMasterType := AXI_WRITE_MASTER_INIT_C;
   signal mAxiWriteSlave  : AxiWriteSlaveType  := AXI_WRITE_SLAVE_INIT_C;
   signal mAxiWriteCtrl   : AxiCtrlType        := AXI_CTRL_UNUSED_C;

begin

   dataWriteCtrlPause <= dataWriteCtrl.pause;
   dataWriteCtrlOver  <= dataWriteCtrl.overflow;
   mAxiWriteCtrl.pause <= mAxiWriteCtrlPause;
   mAxiWriteCtrl.overflow <= mAxiWriteCtrlOver;

   dataWriteMaster.awid     <= resize(DATA_AXI_AWID, dataWriteMaster.awid'length);
   dataWriteMaster.awaddr   <= resize(DATA_AXI_AWADDR, dataWriteMaster.awaddr'length);
   dataWriteMaster.awlen    <= DATA_AXI_AWLEN;
   dataWriteMaster.awsize   <= DATA_AXI_AWSIZE;
   dataWriteMaster.awburst  <= DATA_AXI_AWBURST;
   dataWriteMaster.awlock(0) <= DATA_AXI_AWLOCK;
   dataWriteMaster.awcache  <= DATA_AXI_AWCACHE;
   dataWriteMaster.awprot   <= DATA_AXI_AWPROT;
   dataWriteMaster.awregion <= DATA_AXI_AWREGION;
   dataWriteMaster.awqos    <= DATA_AXI_AWQOS;
   dataWriteMaster.awvalid  <= DATA_AXI_AWVALID;
   dataWriteMaster.wid      <= resize(DATA_AXI_WID, dataWriteMaster.wid'length);
   dataWriteMaster.wdata    <= resize(DATA_AXI_WDATA, dataWriteMaster.wdata'length);
   dataWriteMaster.wstrb    <= resize(DATA_AXI_WSTRB, dataWriteMaster.wstrb'length);
   dataWriteMaster.wlast    <= DATA_AXI_WLAST;
   dataWriteMaster.wvalid   <= DATA_AXI_WVALID;
   dataWriteMaster.bready   <= DATA_AXI_BREADY;

   DATA_AXI_AWREADY <= dataWriteSlave.awready;
   DATA_AXI_WREADY  <= dataWriteSlave.wready;
   DATA_AXI_BID     <= dataWriteSlave.bid(3 downto 0);
   DATA_AXI_BRESP   <= dataWriteSlave.bresp;
   DATA_AXI_BVALID  <= dataWriteSlave.bvalid;

   descWriteMaster.awid     <= resize(DESC_AXI_AWID, descWriteMaster.awid'length);
   descWriteMaster.awaddr   <= resize(DESC_AXI_AWADDR, descWriteMaster.awaddr'length);
   descWriteMaster.awlen    <= DESC_AXI_AWLEN;
   descWriteMaster.awsize   <= DESC_AXI_AWSIZE;
   descWriteMaster.awburst  <= DESC_AXI_AWBURST;
   descWriteMaster.awlock(0) <= DESC_AXI_AWLOCK;
   descWriteMaster.awcache  <= DESC_AXI_AWCACHE;
   descWriteMaster.awprot   <= DESC_AXI_AWPROT;
   descWriteMaster.awregion <= DESC_AXI_AWREGION;
   descWriteMaster.awqos    <= DESC_AXI_AWQOS;
   descWriteMaster.awvalid  <= DESC_AXI_AWVALID;
   descWriteMaster.wid      <= resize(DESC_AXI_WID, descWriteMaster.wid'length);
   descWriteMaster.wdata    <= resize(DESC_AXI_WDATA, descWriteMaster.wdata'length);
   descWriteMaster.wstrb    <= resize(DESC_AXI_WSTRB, descWriteMaster.wstrb'length);
   descWriteMaster.wlast    <= DESC_AXI_WLAST;
   descWriteMaster.wvalid   <= DESC_AXI_WVALID;
   descWriteMaster.bready   <= DESC_AXI_BREADY;

   DESC_AXI_AWREADY <= descWriteSlave.awready;
   DESC_AXI_WREADY  <= descWriteSlave.wready;
   DESC_AXI_BID     <= descWriteSlave.bid(3 downto 0);
   DESC_AXI_BRESP   <= descWriteSlave.bresp;
   DESC_AXI_BVALID  <= descWriteSlave.bvalid;

   M_AXI_AWID     <= mAxiWriteMaster.awid(3 downto 0);
   M_AXI_AWADDR   <= mAxiWriteMaster.awaddr(15 downto 0);
   M_AXI_AWLEN    <= mAxiWriteMaster.awlen;
   M_AXI_AWSIZE   <= mAxiWriteMaster.awsize;
   M_AXI_AWBURST  <= mAxiWriteMaster.awburst;
   M_AXI_AWLOCK   <= mAxiWriteMaster.awlock(0);
   M_AXI_AWCACHE  <= mAxiWriteMaster.awcache;
   M_AXI_AWPROT   <= mAxiWriteMaster.awprot;
   M_AXI_AWREGION <= mAxiWriteMaster.awregion;
   M_AXI_AWQOS    <= mAxiWriteMaster.awqos;
   M_AXI_AWVALID  <= mAxiWriteMaster.awvalid;
   M_AXI_WID      <= mAxiWriteMaster.wid(3 downto 0);
   M_AXI_WDATA    <= mAxiWriteMaster.wdata(DATA_BYTES_G*8-1 downto 0);
   M_AXI_WSTRB    <= mAxiWriteMaster.wstrb(DATA_BYTES_G-1 downto 0);
   M_AXI_WLAST    <= mAxiWriteMaster.wlast;
   M_AXI_WVALID   <= mAxiWriteMaster.wvalid;
   M_AXI_BREADY   <= mAxiWriteMaster.bready;

   mAxiWriteSlave.awready <= M_AXI_AWREADY;
   mAxiWriteSlave.wready  <= M_AXI_WREADY;
   mAxiWriteSlave.bid(3 downto 0) <= M_AXI_BID;
   mAxiWriteSlave.bresp   <= M_AXI_BRESP;
   mAxiWriteSlave.bvalid  <= M_AXI_BVALID;

   U_DUT : entity surf.AxiStreamDmaV2WriteMux
      generic map (
         TPD_G             => TPD_G,
         AXI_CONFIG_G      => AXI_CONFIG_C,
         AXI_READY_EN_G    => AXI_READY_EN_G,
         ACK_WAIT_BVALID_G => ACK_WAIT_BVALID_G)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         dataWriteMaster => dataWriteMaster,
         dataWriteSlave  => dataWriteSlave,
         dataWriteCtrl   => dataWriteCtrl,
         descWriteMaster => descWriteMaster,
         descWriteSlave  => descWriteSlave,
         mAxiWriteMaster => mAxiWriteMaster,
         mAxiWriteSlave  => mAxiWriteSlave,
         mAxiWriteCtrl   => mAxiWriteCtrl);

end architecture rtl;
