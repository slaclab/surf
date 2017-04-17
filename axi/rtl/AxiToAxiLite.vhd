-------------------------------------------------------------------------------
-- File       : AxiToAxiLite.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-03-06
-- Last update: 2016-09-28
-------------------------------------------------------------------------------
-- Description: AXI4-to-AXI-Lite bridge
--
-- Note: This module only supports 32-bit aligned addresses and 32-bit transactions.  
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiPkg.all;

entity AxiToAxiLite is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clocks & Reset
      axiClk          : in  sl;
      axiClkRst       : in  sl;
      -- AXI Slave 
      axiReadMaster   : in  AxiReadMasterType;
      axiReadSlave    : out AxiReadSlaveType;
      axiWriteMaster  : in  AxiWriteMasterType;
      axiWriteSlave   : out AxiWriteSlaveType;
      -- AXI Lite
      axilReadMaster  : out AxiLiteReadMasterType;
      axilReadSlave   : in  AxiLiteReadSlaveType;
      axilWriteMaster : out AxiLiteWriteMasterType;
      axilWriteSlave  : in  AxiLiteWriteSlaveType);
end AxiToAxiLite;

architecture mapping of AxiToAxiLite is

begin

   axilWriteMaster.awaddr  <= axiWriteMaster.awaddr(31 downto 0);
   axilWriteMaster.awprot  <= axiWriteMaster.awprot;
   axilWriteMaster.awvalid <= axiWriteMaster.awvalid;
--   axilWriteMaster.wdata   <= axiWriteMaster.wdata(31 downto 0);
--   axilWriteMaster.wstrb   <= axiWriteMaster.wstrb(3 downto 0);
   axilWriteMaster.wvalid  <= axiWriteMaster.wvalid;
   axilWriteMaster.bready  <= axiWriteMaster.bready;

   axiWriteSlave.awready <= axilWriteSlave.awready;
   axiWriteSlave.bresp   <= axilWriteSlave.bresp;
   axiWriteSlave.bvalid  <= axilWriteSlave.bvalid;
   axiWriteSlave.wready  <= axilWriteSlave.wready;

   axilReadMaster.araddr  <= axiReadMaster.araddr(31 downto 0);
   axilReadMaster.arprot  <= axiReadMaster.arprot;
   axilReadMaster.arvalid <= axiReadMaster.arvalid;
   axilReadMaster.rready  <= axiReadMaster.rready;

   axiReadSlave.arready <= axilReadSlave.arready;
   axiReadSlave.rresp   <= axilReadSlave.rresp;
   axiReadSlave.rlast   <= '1';
   axiReadSlave.rvalid  <= axilReadSlave.rvalid;

   --
   -- Collapse Axi wdata onto 32-bit AxiLite wdata
   --   Assumes only active 32 bits are asserted,
   --     otherwise could use wstrb to pick correct 32 bits
   --
   process(axiWriteMaster)
      variable i     : integer;
      variable wdata : slv(31 downto 0);
   begin
      wdata := (others=>'0');
      for i in 0 to 31 loop
         wdata := wdata or axiWriteMaster.wdata(32*i+31 downto 32*i);
      end loop;
      axilWriteMaster.wdata <= wdata;
      axilWriteMaster.wstrb <= x"F";
   end process;
  
   process(axilReadSlave)
      variable i     : integer;
      variable rdata : slv(1023 downto 0);
   begin
      -- Copy the responds read bus bus to all word boundaries
      for i in 0 to 31 loop
         rdata((32*i)+31 downto (32*i)) := axilReadSlave.rdata;
      end loop;
      -- Return the value to the output
      axiReadSlave.rdata <= rdata;
   end process;

   -- ID Tracking
   process (axiClk)
   begin
      if rising_edge(axiClk) then
         if axiClkRst = '1' then
            axiReadSlave.rid  <= (others => '0') after TPD_G;
            axiWriteSlave.bid <= (others => '0') after TPD_G;
         else
            if axiReadMaster.arvalid = '1' and axilReadSlave.arready = '1' then
               axiReadSlave.rid <= axiReadMaster.arid after TPD_G;
            end if;
            if axiWriteMaster.awvalid = '1' and axilWriteSlave.awready = '1' then
               axiWriteSlave.bid <= axiWriteMaster.awid after TPD_G;
            end if;
         end if;
      end if;
   end process;

end architecture mapping;
