-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP Integrator Wrapper for surf.AxiLiteFifoPushPop
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

entity AxiLiteFifoPushPopIpIntegrator is
   port (
      axiClk         : in  sl;
      axiClkRst      : in  sl;
      popFifoClk     : in  sl;
      popFifoRst     : in  sl;
      popFifoWrite   : in  sl;
      popFifoDin     : in  slv(31 downto 0);
      popFifoValid   : out sl;
      loopFifoValid  : out sl;
      loopFifoAEmpty : out sl;
      loopFifoAFull  : out sl;
      pushFifoClk    : in  sl;
      pushFifoRst    : in  sl;
      pushFifoValid  : out sl;
      pushFifoDout   : out slv(35 downto 0);
      pushFifoRead   : in  sl;
      S_AXI_AWADDR   : in  slv(9 downto 0);
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
      S_AXI_ARADDR   : in  slv(9 downto 0);
      S_AXI_ARPROT   : in  slv(2 downto 0);
      S_AXI_ARVALID  : in  sl;
      S_AXI_ARREADY  : out sl;
      S_AXI_RDATA    : out slv(31 downto 0);
      S_AXI_RRESP    : out slv(1 downto 0);
      S_AXI_RVALID   : out sl;
      S_AXI_RREADY   : in  sl);
end entity AxiLiteFifoPushPopIpIntegrator;

architecture rtl of AxiLiteFifoPushPopIpIntegrator is

   signal axilResetN        : sl := '1';
   signal axilReadMaster    : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave     : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster   : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave    : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal popFifoValidVec   : slv(0 downto 0);
   signal popFifoAEmptyVec  : slv(0 downto 0);
   signal loopFifoValidVec  : slv(0 downto 0);
   signal loopFifoAEmptyVec : slv(0 downto 0);
   signal loopFifoAFullVec  : slv(0 downto 0);
   signal pushFifoAFullVec  : slv(3 downto 0);
   signal pushFifoValidVec  : slv(3 downto 0);
   signal pushFifoDoutVec   : Slv36Array(3 downto 0);
   signal popFifoFullVec    : slv(0 downto 0);
   signal popFifoAFullVec   : slv(0 downto 0);
   signal popFifoPFullVec   : slv(0 downto 0);

begin

   ---------------------------------------------------------------------------
   -- AXI-Lite shim
   ---------------------------------------------------------------------------
   axilResetN <= not axiClkRst;

   U_AXIL : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 10)
      port map (
         S_AXI_ACLK      => axiClk,
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
   U_DUT : entity surf.AxiLiteFifoPushPop
      generic map (
         POP_FIFO_COUNT_G  => 1,
         POP_SYNC_FIFO_G   => true,
         LOOP_FIFO_EN_G    => true,
         LOOP_FIFO_COUNT_G => 1,
         PUSH_FIFO_COUNT_G => 4,
         PUSH_SYNC_FIFO_G  => true,
         RANGE_LSB_G       => 8)
      port map (
         axiClk         => axiClk,
         axiClkRst      => axiClkRst,
         axiReadMaster  => axilReadMaster,
         axiReadSlave   => axilReadSlave,
         axiWriteMaster => axilWriteMaster,
         axiWriteSlave  => axilWriteSlave,
         popFifoValid   => popFifoValidVec,
         popFifoAEmpty  => popFifoAEmptyVec,
         loopFifoValid  => loopFifoValidVec,
         loopFifoAEmpty => loopFifoAEmptyVec,
         loopFifoAFull  => loopFifoAFullVec,
         pushFifoAFull  => pushFifoAFullVec,
         popFifoClk     => (0 => popFifoClk),
         popFifoRst     => (0 => popFifoRst),
         popFifoWrite   => (0 => popFifoWrite),
         popFifoDin     => (0 => popFifoDin),
         popFifoFull    => popFifoFullVec,
         popFifoAFull   => popFifoAFullVec,
         popFifoPFull   => popFifoPFullVec,
         pushFifoClk    => (0 => pushFifoClk, 1 => pushFifoClk, 2 => pushFifoClk, 3 => pushFifoClk),
         pushFifoRst    => (0 => pushFifoRst, 1 => pushFifoRst, 2 => pushFifoRst, 3 => pushFifoRst),
         pushFifoValid  => pushFifoValidVec,
         pushFifoDout   => pushFifoDoutVec,
         pushFifoRead   => (0 => pushFifoRead, 1 => '0', 2 => '0', 3 => '0'));

   ---------------------------------------------------------------------------
   -- Flatten the single exposed FIFO lanes
   ---------------------------------------------------------------------------
   popFifoValid  <= popFifoValidVec(0);
   loopFifoValid <= loopFifoValidVec(0);
   loopFifoAEmpty <= loopFifoAEmptyVec(0);
   loopFifoAFull <= loopFifoAFullVec(0);
   pushFifoValid <= pushFifoValidVec(0);
   pushFifoDout  <= pushFifoDoutVec(0);

end architecture rtl;
