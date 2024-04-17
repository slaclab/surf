-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Rogue Stream Module Wrapper
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity RogueTcpMemoryWrap is
   generic (
      TPD_G      : time                        := 1 ns;
      PORT_NUM_G : natural range 1024 to 49151 := 9000);
   port (
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : out AxiLiteReadMasterType;
      axilReadSlave   : in  AxiLiteReadSlaveType;
      axilWriteMaster : out AxiLiteWriteMasterType;
      axilWriteSlave  : in  AxiLiteWriteSlaveType);
end RogueTcpMemoryWrap;

-- Define architecture
architecture RogueTcpMemoryWrap of RogueTcpMemoryWrap is

begin

   -- Sim Core
   U_RogueTcpMemory : entity surf.RogueTcpMemory
      port map (
         clock   => axilClk,
         reset   => axilRst,
         portNum => toSlv(PORT_NUM_G, 16),
         araddr  => axilReadMaster.araddr,
         arprot  => axilReadMaster.arprot,
         arvalid => axilReadMaster.arvalid,
         rready  => axilReadMaster.rready,
         arready => axilReadSlave.arready,
         rdata   => axilReadSlave.rdata,
         rresp   => axilReadSlave.rresp,
         rvalid  => axilReadSlave.rvalid,
         awaddr  => axilWriteMaster.awaddr,
         awprot  => axilWriteMaster.awprot,
         awvalid => axilWriteMaster.awvalid,
         wdata   => axilWriteMaster.wdata,
         wstrb   => axilWriteMaster.wstrb,
         wvalid  => axilWriteMaster.wvalid,
         bready  => axilWriteMaster.bready,
         awready => axilWriteSlave.awready,
         wready  => axilWriteSlave.wready,
         bresp   => axilWriteSlave.bresp,
         bvalid  => axilWriteSlave.bvalid);

end RogueTcpMemoryWrap;

