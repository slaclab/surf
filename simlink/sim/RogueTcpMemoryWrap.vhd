-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Reusable Rogue TCP Memory simulation interface
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
         clock   => axilClk,                 -- [in]
         reset   => axilRst,                 -- [in]
         portNum => toSlv(PORT_NUM_G, 16),    -- [in]
         araddr  => axilReadMaster.araddr,   -- [out]
         arprot  => axilReadMaster.arprot,   -- [out]
         arvalid => axilReadMaster.arvalid,  -- [out]
         rready  => axilReadMaster.rready,   -- [out]
         arready => axilReadSlave.arready,   -- [in]
         rdata   => axilReadSlave.rdata,     -- [in]
         rresp   => axilReadSlave.rresp,     -- [in]
         rvalid  => axilReadSlave.rvalid,    -- [in]
         awaddr  => axilWriteMaster.awaddr,  -- [out]
         awprot  => axilWriteMaster.awprot,  -- [out]
         awvalid => axilWriteMaster.awvalid, -- [out]
         wdata   => axilWriteMaster.wdata,   -- [out]
         wstrb   => axilWriteMaster.wstrb,   -- [out]
         wvalid  => axilWriteMaster.wvalid,  -- [out]
         bready  => axilWriteMaster.bready,  -- [out]
         awready => axilWriteSlave.awready,  -- [in]
         wready  => axilWriteSlave.wready,   -- [in]
         bresp   => axilWriteSlave.bresp,    -- [in]
         bvalid  => axilWriteSlave.bvalid);  -- [in]

end RogueTcpMemoryWrap;
