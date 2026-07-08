-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing flat wrapper for surf.RogueTcpMemoryWrap
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

entity RogueTcpMemoryWrapFlatWrapper is
   generic (
      TPD_G      : time                        := 1 ns;
      PORT_NUM_G : natural range 1024 to 49151 := 9606);
   port (
      axilClk       : in  sl;
      axilRst       : in  sl;
      M_AXI_AWADDR  : out slv(31 downto 0);
      M_AXI_AWPROT  : out slv(2 downto 0);
      M_AXI_AWVALID : out sl;
      M_AXI_AWREADY : in  sl;
      M_AXI_WDATA   : out slv(31 downto 0);
      M_AXI_WSTRB   : out slv(3 downto 0);
      M_AXI_WVALID  : out sl;
      M_AXI_WREADY  : in  sl;
      M_AXI_BRESP   : in  slv(1 downto 0);
      M_AXI_BVALID  : in  sl;
      M_AXI_BREADY  : out sl;
      M_AXI_ARADDR  : out slv(31 downto 0);
      M_AXI_ARPROT  : out slv(2 downto 0);
      M_AXI_ARVALID : out sl;
      M_AXI_ARREADY : in  sl;
      M_AXI_RDATA   : in  slv(31 downto 0);
      M_AXI_RRESP   : in  slv(1 downto 0);
      M_AXI_RVALID  : in  sl;
      M_AXI_RREADY  : out sl);
end entity RogueTcpMemoryWrapFlatWrapper;

architecture rtl of RogueTcpMemoryWrapFlatWrapper is

   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

begin

   ------------------------
   -- AXI-Lite shims  --
   ------------------------
   M_AXI_ARADDR          <= axilReadMaster.araddr;
   M_AXI_ARPROT          <= axilReadMaster.arprot;
   M_AXI_ARVALID         <= axilReadMaster.arvalid;
   M_AXI_RREADY          <= axilReadMaster.rready;
   axilReadSlave.arready <= M_AXI_ARREADY;
   axilReadSlave.rdata   <= M_AXI_RDATA;
   axilReadSlave.rresp   <= M_AXI_RRESP;
   axilReadSlave.rvalid  <= M_AXI_RVALID;

   M_AXI_AWADDR           <= axilWriteMaster.awaddr;
   M_AXI_AWPROT           <= axilWriteMaster.awprot;
   M_AXI_AWVALID          <= axilWriteMaster.awvalid;
   M_AXI_WDATA            <= axilWriteMaster.wdata;
   M_AXI_WSTRB            <= axilWriteMaster.wstrb;
   M_AXI_WVALID           <= axilWriteMaster.wvalid;
   M_AXI_BREADY           <= axilWriteMaster.bready;
   axilWriteSlave.awready <= M_AXI_AWREADY;
   axilWriteSlave.wready  <= M_AXI_WREADY;
   axilWriteSlave.bresp   <= M_AXI_BRESP;
   axilWriteSlave.bvalid  <= M_AXI_BVALID;

   ---------------------
   -- DUT instancing  --
   ---------------------
   U_DUT : entity surf.RogueTcpMemoryWrap
      generic map (
         TPD_G      => TPD_G,
         PORT_NUM_G => PORT_NUM_G)
      port map (
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

end architecture rtl;
