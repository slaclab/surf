-------------------------------------------------------------------------------
-- Title         : AXI Bus To AXI Lite Bus Bridge
-- File          : AxiToAxiLite.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 03/06/2014
-------------------------------------------------------------------------------
-- Description:
-- AXI to AXI lite bus converter module
-------------------------------------------------------------------------------
-- Copyright (c) 2014 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 03/06/2014: created.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiPkg.all;

entity AxiToAxiLite is
   generic (
      TPD_G  : time := 1 ns
   );
   port (

      -- Clocks & Reset
      axiClk             : in     sl;
      axiClkRst          : in     sl;

      -- AXI Slave 
      axiReadMaster      : in     AxiReadMasterType;
      axiReadSlave       : out    AxiReadSlaveType;
      axiWriteMaster     : in     AxiWriteMasterType;
      axiWriteSlave      : out    AxiWriteSlaveType;

      -- AXI Lite
      axilReadMaster     : out    AxiLiteReadMasterType;
      axilReadSlave      : in     AxiLiteReadSlaveType;
      axilWriteMaster    : out    AxiLiteWriteMasterType;
      axilWriteSlave     : in     AxiLiteWriteSlaveType
   );
end AxiToAxiLite;

architecture structure of AxiToAxiLite is

begin

   axilWriteMaster.awaddr  <= axiWriteMaster.awaddr(31 downto 0);
   axilWriteMaster.awprot  <= axiWriteMaster.awprot;
   axilWriteMaster.awvalid <= axiWriteMaster.awvalid;
   axilWriteMaster.wdata   <= axiWriteMaster.wdata(31 downto 0);
   axilWriteMaster.wstrb   <= axiWriteMaster.wstrb(3 downto 0);
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

   axiReadSlave.arready             <= axilReadSlave.arready;
   axiReadSlave.rdata(63 downto 32) <= (others=>'0');
   axiReadSlave.rdata(31 downto  0) <= axilReadSlave.rdata;
   axiReadSlave.rresp               <= axilReadSlave.rresp;
   axiReadSlave.rlast               <= '1';
   axiReadSlave.rvalid              <= axilReadSlave.rvalid;

   -- ID Tracking
   process ( axiClk ) begin
      if rising_edge(axiClk) then
         if axiClkRst = '1' then
            axiReadSlave.rid  <= (others=>'0') after TPD_G;
            axiWriteSlave.bid <= (others=>'0') after TPD_G;
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

end architecture structure;

