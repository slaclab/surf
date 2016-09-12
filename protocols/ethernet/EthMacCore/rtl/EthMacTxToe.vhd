-------------------------------------------------------------------------------
-- Title      : 1GbE/10GbE Ethernet MAC
-------------------------------------------------------------------------------
-- File       : EthMacTxToe.vhd
-- Author     : Ryan Herbst <rherbst@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-09-08
-- Last update: 2016-09-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: TX TCP Offload Engine (TOE) module
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Ethernet Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Ethernet Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.AxiStreamPkg.all;
use work.StdRtlPkg.all;
use work.EthMacPkg.all;

entity EthMacTxToe is
   generic (
      TPD_G   : time    := 1 ns;
      JUMBO_G : boolean := false;
      VLAN_G  : boolean := false);
   port (
      -- Clock and Reset
      ethClk      : in  sl;
      ethRst      : in  sl;
      -- Configurations
      ipCsumEn    : in  sl;
      tcpCsumEn   : in  sl;
      udpCsumEn   : in  sl;
      -- Outbound data to MAC
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);
end EthMacTxToe;

architecture rtl of EthMacTxToe is

begin

   mAxisMaster <= sAxisMaster;
   sAxisSlave  <= mAxisSlave;

end rtl;
