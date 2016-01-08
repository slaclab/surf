-------------------------------------------------------------------------------
-- Title      : SSI PCIe Core
-------------------------------------------------------------------------------
-- File       : SsiPcieDmaLoopBack.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-22
-- Last update: 2015-04-22
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SSI PCIe Inbound TLP Packet Controller
-------------------------------------------------------------------------------
-- This file is part of 'SLAC SSI PCI-E Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC SSI PCI-E Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity SsiPcieDmaLoopBack is
   generic (
      TPD_G         : time                   := 1 ns;
      LOOPBACK_EN_G : boolean                := true);  -- true = synthesis loopback capability
   port (
      dmaLoopback : in  sl;
      -- External DMA Interface
      dmaIbMaster : in  AxiStreamMasterType;
      dmaIbSlave  : out AxiStreamSlaveType;
      dmaObMaster : out AxiStreamMasterType;
      dmaObSlave  : in  AxiStreamSlaveType;
      -- Internal DMA Interface
      ibMaster    : out AxiStreamMasterType;
      ibSlave     : in  AxiStreamSlaveType;
      obMaster    : in  AxiStreamMasterType;
      obSlave     : out AxiStreamSlaveType;
      -- Clock and Resets
      pciClk      : in  sl;
      pciRst      : in  sl);       
end SsiPcieDmaLoopBack;

architecture mapping of SsiPcieDmaLoopBack is
   
begin

   GEN_LOOPBACK : if (LOOPBACK_EN_G = true) generate
   
      dmaObMaster <= obMaster    when(dmaLoopback = '0') else AXI_STREAM_MASTER_INIT_C;  
      dmaIbSlave  <= ibSlave     when(dmaLoopback = '0') else AXI_STREAM_SLAVE_INIT_C;  
      ibMaster    <= dmaIbMaster when(dmaLoopback = '0') else obMaster;     
      obSlave     <= dmaObSlave  when(dmaLoopback = '0') else ibSlave;     
   
   end generate;

   GEN_NO_LOOPBACK : if (LOOPBACK_EN_G = false) generate
      
      ibMaster    <= dmaIbMaster;
      dmaIbSlave  <= ibSlave;
      dmaObMaster <= obMaster;
      obSlave     <= dmaObSlave;
      
   end generate;

end mapping;
