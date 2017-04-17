-------------------------------------------------------------------------------
-- File       : GigEthPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-02-07
-- Last update: 2016-02-07
-------------------------------------------------------------------------------
-- Description: 1GbE Package Files
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

use work.StdRtlPkg.all;
use work.EthMacPkg.all;

package GigEthPkg is

   -- Default MAC is 01:03:00:56:44:00
   constant MAC_ADDR_INIT_C : slv(47 downto 0) := EMAC_ADDR_INIT_C;

   type GigEthConfigType is record
      softRst    : sl;
      coreConfig : slv(4 downto 0);
      macConfig  : EthMacConfigType;
   end record;
   constant GIG_ETH_CONFIG_INIT_C : GigEthConfigType := (
      softRst    => '0',
      coreConfig => "00000",
      macConfig  => ETH_MAC_CONFIG_INIT_C);

   type GigEthStatusType is record
      phyReady   : sl;
      macStatus  : EthMacStatusType;
      coreStatus : slv(15 downto 0);
   end record;
   
end GigEthPkg;
