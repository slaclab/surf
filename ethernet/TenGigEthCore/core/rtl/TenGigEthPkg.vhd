-------------------------------------------------------------------------------
-- File       : TenGigEthPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-02-12
-- Last update: 2015-04-07
-------------------------------------------------------------------------------
-- Description: 10GbE Package Files
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

package TenGigEthPkg is

   -- Default MAC is 01:03:00:56:44:00
   constant MAC_ADDR_INIT_C : slv(47 downto 0) := EMAC_ADDR_INIT_C;

   type TenGigEthConfig is record
      softRst      : sl;
      macConfig    : EthMacConfigType;
      pma_pmd_type : slv(2 downto 0);
      pma_loopback : sl;
      pma_reset    : sl;
      pcs_loopback : sl;
      pcs_reset    : sl;
   end record;
   constant TEN_GIG_ETH_CONFIG_INIT_C : TenGigEthConfig := (
      softRst      => '0',
      macConfig    => ETH_MAC_CONFIG_INIT_C,
      pma_pmd_type => "111",            --111 = 10GBASE-SR (Wavelength:850 nm & OM3:300m)
      pma_loopback => '0',
      pma_reset    => '0',
      pcs_loopback => '0',
      pcs_reset    => '0');

   type TenGigEthStatus is record
      phyReady    : sl;
      macStatus   : EthMacStatusType;
      txDisable   : sl;
      sigDet      : sl;
      txFault     : sl;
      gtTxRst     : sl;
      gtRxRst     : sl;
      rstCntDone  : sl;
      qplllock    : sl;
      txRstdone   : sl;
      rxRstdone   : sl;
      txUsrRdy    : sl;
      core_status : slv(7 downto 0);
   end record;
   
end TenGigEthPkg;
