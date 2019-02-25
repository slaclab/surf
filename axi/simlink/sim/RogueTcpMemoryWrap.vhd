-------------------------------------------------------------------------------
-- File       : RogueTcpMemoryWrap.vhd
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

LIBRARY ieee;
USE work.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity RogueTcpMemoryWrap is 
   generic (
      TPD_G      : time                     := 1 ns;
      PORT_NUM_G : natural range 0 to 65535 := 1
   );
   port (
      axiClk         : in    sl;
      axiRst         : in    sl;
      axiReadMaster  : out   AxiLiteReadMasterType;
      axiReadSlave   : in    AxiLiteReadSlaveType;
      axiWriteMaster : out   AxiLiteWriteMasterType;
      axiWriteSlave  : in    AxiLiteWriteSlaveType
   );
end RogueTcpMemoryWrap;

-- Define architecture
architecture RogueTcpMemoryWrap of RogueTcpMemoryWrap is

begin

   -- Sim Core
   U_RogueTcpMemory : entity work.RogueTcpMemory
      port map (
         clock    => axiClk,
         reset    => axiRst,
         portNum  => toSlv(PORT_NUM_G,16),
         araddr   => axiReadMaster.araddr,
         arprot   => axiReadMaster.arprot,
         arvalid  => axiReadMaster.arvalid,
         rready   => axiReadMaster.rready,
         arready  => axiReadSlave.arready,
         rdata    => axiReadSlave.rdata,
         rresp    => axiReadSlave.rresp,
         rvalid   => axiReadSlave.rvalid,
         awaddr   => axiWriteMaster.awaddr,
         awprot   => axiWriteMaster.awprot,
         awvalid  => axiWriteMaster.awvalid,
         wdata    => axiWriteMaster.wdata,
         wstrb    => axiWriteMaster.wstrb,
         wvalid   => axiWriteMaster.wvalid,
         bready   => axiWriteMaster.bready,
         awready  => axiWriteSlave.awready,
         wready   => axiWriteSlave.wready,
         bresp    => axiWriteSlave.bresp,
         bvalid   => axiWriteSlave.bvalid);

end RogueTcpMemoryWrap;

