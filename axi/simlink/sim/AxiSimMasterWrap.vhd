-------------------------------------------------------------------------------
-- File       : AxiSimMasterWrap.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-07-21
-- Last update: 2016-07-21
-------------------------------------------------------------------------------
-- Description: Wrapper for AXI Master Simulation Module 
------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;

library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;

entity AxiSimMasterWrap is
   generic (
      TPD_G       : time                   := 1 ns;
      MASTER_ID_G : integer range 0 to 255 := 0
   );
   port (

      -- AXI Clock/Rst
      axiClk            : in  sl;

      -- Master
      mstAxiReadMaster  : out AxiReadMasterType;
      mstAxiReadSlave   : in  AxiReadSlaveType;
      mstAxiWriteMaster : out AxiWriteMasterType;
      mstAxiWriteSlave  : in  AxiWriteSlaveType
   );
end AxiSimMasterWrap;

architecture structure of AxiSimMasterWrap is

   signal masterId : slv(7 downto 0);

begin

   masterId <= conv_std_logic_vector(MASTER_ID_G,8);

   U_AxiMaster : entity work.AxiSimMaster 
      port map (
         axiClk          => axiClk,
         masterId        => masterId,
         arvalid         => mstAxiReadMaster.arvalid,
         arready         => mstAxiReadSlave.arready,
         araddr          => mstAxiReadMaster.araddr(31 downto 0),
         arid            => mstAxiReadMaster.arid(11 downto 0),
         arlen           => mstAxiReadMaster.arlen(3  downto 0),
         arsize          => mstAxiReadMaster.arsize,
         arburst         => mstAxiReadMaster.arburst,
         arlock          => mstAxiReadMaster.arlock,
         arprot          => mstAxiReadMaster.arprot,
         arcache         => mstAxiReadMaster.arcache,
         rready          => mstAxiReadMaster.rready,
         rdataH          => mstAxiReadSlave.rdata(63 downto 32),
         rdataL          => mstAxiReadSlave.rdata(31 downto  0),
         rlast           => mstAxiReadSlave.rlast,
         rvalid          => mstAxiReadSlave.rvalid,
         rid             => mstAxiReadSlave.rid(11 downto 0),
         rresp           => mstAxiReadSlave.rresp,
         awvalid         => mstAxiWriteMaster.awvalid,
         awready         => mstAxiWriteSlave.awready,
         awaddr          => mstAxiWriteMaster.awaddr(31 downto 0),
         awid            => mstAxiWriteMaster.awid(11 downto 0),
         awlen           => mstAxiWriteMaster.awlen(3  downto 0),
         awsize          => mstAxiWriteMaster.awsize,
         awburst         => mstAxiWriteMaster.awburst,
         awlock          => mstAxiWriteMaster.awlock,
         awcache         => mstAxiWriteMaster.awcache,
         awprot          => mstAxiWriteMaster.awprot,
         wready          => mstAxiWriteSlave.wready,
         wdataH          => mstAxiWriteMaster.wdata(63 downto 32),
         wdataL          => mstAxiWriteMaster.wdata(31 downto 0),
         wlast           => mstAxiWriteMaster.wlast,
         wvalid          => mstAxiWriteMaster.wvalid,
         wid             => mstAxiWriteMaster.wid(11 downto 0),
         wstrb           => mstAxiWriteMaster.wstrb(7 downto 0),
         bready          => mstAxiWriteMaster.bready,
         bresp           => mstAxiWriteSlave.bresp,
         bvalid          => mstAxiWriteSlave.bvalid,
         bid             => mstAxiWriteSlave.bid(11 downto 0)
      );

end architecture structure;

