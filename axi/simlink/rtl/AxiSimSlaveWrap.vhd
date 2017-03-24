-------------------------------------------------------------------------------
-- File       : AxiSimSlaveWrap.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-07-21
-- Last update: 2016-07-21
-------------------------------------------------------------------------------
-- Description: Wrapper for AXI Slave Simulation Module 
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

entity AxiSimSlaveWrap is
   generic (
      TPD_G      : time                   := 1 ns;
      SLAVE_ID_G : integer range 0 to 255 := 0
   );
   port (

      -- AXI Clock/Rst
      axiClk            : in  sl;

      -- Slave
      slvAxiReadMaster  : in  AxiReadMasterType;
      slvAxiReadSlave   : out AxiReadSlaveType;
      slvAxiWriteMaster : in  AxiWriteMasterType;
      slvAxiWriteSlave  : out AxiWriteSlaveType
   );
end AxiSimSlaveWrap;

architecture structure of AxiSimSlaveWrap is

   signal slaveId : slv(7 downto 0);

begin

   slaveId <= conv_std_logic_vector(SLAVE_ID_G,8);

   U_AxiSlave : entity work.AxiSimSlave
      port map (
         axiClk          => axiClk,
         slaveId         => slaveId,
         arvalid         => slvAxiReadMaster.arvalid,
         arready         => slvAxiReadSlave.arready,
         araddr          => slvAxiReadMaster.araddr(31 downto 0),
         arid            => slvAxiReadMaster.arid(11 downto 0),
         arlen           => slvAxiReadMaster.arlen(3  downto 0),
         arsize          => slvAxiReadMaster.arsize,
         arburst         => slvAxiReadMaster.arburst,
         arlock          => slvAxiReadMaster.arlock,
         arprot          => slvAxiReadMaster.arprot,
         arcache         => slvAxiReadMaster.arcache,
         rready          => slvAxiReadMaster.rready,
         rdataH          => slvAxiReadSlave.rdata(63 downto 32),
         rdataL          => slvAxiReadSlave.rdata(31 downto  0),
         rlast           => slvAxiReadSlave.rlast,
         rvalid          => slvAxiReadSlave.rvalid,
         rid             => slvAxiReadSlave.rid(11 downto 0),
         rresp           => slvAxiReadSlave.rresp,
         awvalid         => slvAxiWriteMaster.awvalid,
         awready         => slvAxiWriteSlave.awready,
         awaddr          => slvAxiWriteMaster.awaddr(31 downto 0),
         awid            => slvAxiWriteMaster.awid(11 downto 0),
         awlen           => slvAxiWriteMaster.awlen(3  downto 0),
         awsize          => slvAxiWriteMaster.awsize,
         awburst         => slvAxiWriteMaster.awburst,
         awlock          => slvAxiWriteMaster.awlock,
         awcache         => slvAxiWriteMaster.awcache,
         awprot          => slvAxiWriteMaster.awprot,
         wready          => slvAxiWriteSlave.wready,
         wdataH          => slvAxiWriteMaster.wdata(63 downto 32),
         wdataL          => slvAxiWriteMaster.wdata(31 downto 0),
         wlast           => slvAxiWriteMaster.wlast,
         wvalid          => slvAxiWriteMaster.wvalid,
         wid             => slvAxiWriteMaster.wid(11 downto 0),
         wstrb           => slvAxiWriteMaster.wstrb(7 downto 0),
         bready          => slvAxiWriteMaster.bready,
         bresp           => slvAxiWriteSlave.bresp,
         bvalid          => slvAxiWriteSlave.bvalid,
         bid             => slvAxiWriteSlave.bid(11 downto 0)
      );

end architecture structure;

