-------------------------------------------------------------------------------
-- Title      : 10G Ethernet Package
-------------------------------------------------------------------------------
-- File       : XauiPkg.vhd
-- Author     : Ryan Herbst <rherbst@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-07
-- Last update: 2015-04-07
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: XAUI 10G Ethernet: constants & types.
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.XMacPkg.all;

package XauiPkg is

   -- Default MAC is 01:03:00:56:44:00
   constant MAC_ADDR_INIT_C : slv(47 downto 0) := XMAC_ADDR_INIT_C;

   type XauiConfig is record
      softRst      : sl;
      phyConfig    : XMacConfig;
      configVector : slv(6 downto 0);
   end record;
   constant XAUI_CONFIG_INIT_C : XauiConfig := (
      softRst      => '0',
      phyConfig    => XMAC_CONFIG_INIT_C,
      configVector => (others => '0'));

   type XauiStatus is record
      phyReady     : sl;
      phyStatus    : XMacStatus;
      areset       : sl;
      clkLock      : sl;
      statusVector : slv(7 downto 0);
      debugVector  : slv(5 downto 0);
   end record;
   
end XauiPkg;
