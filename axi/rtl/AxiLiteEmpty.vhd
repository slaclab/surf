-------------------------------------------------------------------------------
-- Title         : AXI Lite Empty End Point
-- File          : AxiLiteEmpty.vhd
-------------------------------------------------------------------------------
-- Description:
-- Empty slave endpoint for AXI Lite bus.
-- Absorbs writes and returns zeros on reads.
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity AxiLiteEmpty is
   generic (
      TPD_G       : time             := 1 ns;
      AXI_RESP_G  : slv(1 downto 0)  := AXI_RESP_OK_C;
      AXI_RDATA_G : slv(31 downto 0) := (others => '0'));
   port (
      -- AXI-Lite Bus
      axiClk         : in  sl := '0';
      axiClkRst      : in  sl := '0';
      axiReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axiWriteSlave  : out AxiLiteWriteSlaveType);
end AxiLiteEmpty;

architecture rtl of AxiLiteEmpty is

begin

   axiReadSlave <= (
      arready => '1',
      rdata   => AXI_RDATA_G,
      rresp   => AXI_RESP_G,
      rvalid  => '1');

   axiWriteSlave <= (
      awready => '1',
      wready  => '1',
      bresp   => AXI_RESP_G,
      bvalid  => '1');


end architecture rtl;
