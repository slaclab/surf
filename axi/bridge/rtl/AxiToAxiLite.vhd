-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiPkg.all;

entity AxiToAxiLite is
   generic (
      TPD_G           : time    := 1 ns;
      EN_SLAVE_RESP_G : boolean := true);
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
   axilWriteMaster.wvalid  <= axiWriteMaster.wvalid;
   axilWriteMaster.bready  <= axiWriteMaster.bready;

   axiWriteSlave.awready <= axilWriteSlave.awready;
   axiWriteSlave.bresp   <= axilWriteSlave.bresp when(EN_SLAVE_RESP_G) else AXI_RESP_OK_C;
   axiWriteSlave.bvalid  <= axilWriteSlave.bvalid;
   axiWriteSlave.wready  <= axilWriteSlave.wready;

   axilReadMaster.araddr  <= axiReadMaster.araddr(31 downto 0);
   axilReadMaster.arprot  <= axiReadMaster.arprot;
   axilReadMaster.arvalid <= axiReadMaster.arvalid;
   axilReadMaster.rready  <= axiReadMaster.rready;

   axiReadSlave.arready <= axilReadSlave.arready;
   axiReadSlave.rresp   <= axilReadSlave.rresp when(EN_SLAVE_RESP_G) else AXI_RESP_OK_C;
   axiReadSlave.rlast   <= '1';
   axiReadSlave.rvalid  <= axilReadSlave.rvalid;

   --
   -- Collapse Axi wdata onto 32-bit AxiLite wdata
   --   Assumes only active 32 bits are asserted,
   --     otherwise could use wstrb to pick correct 32 bits
   --
   process(axiWriteMaster)
      variable i     : natural;
      variable byte  : natural;
      variable wdata : slv(31 downto 0);
   begin
      wdata := (others => '0');
      for i in 0 to (1024/8)-1 loop
         byte := (8*i) mod 32;
         if axiWriteMaster.wstrb(i) = '1' then
            wdata(byte+7 downto byte) := wdata(byte+7 downto byte) or axiWriteMaster.wdata(8*i+7 downto 8*i);
         end if;
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
