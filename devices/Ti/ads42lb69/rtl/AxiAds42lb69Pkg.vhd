-------------------------------------------------------------------------------
-- File       : AxiAds42lb69Pkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-03-20
-- Last update: 2015-03-23
-------------------------------------------------------------------------------
-- Description: AxiAds42lb69 Package File
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

package AxiAds42lb69Pkg is

   type AxiAds42lb69InType is record
      clkFbP : sl;
      clkFbN : sl;
      dataP  : Slv8Array(1 downto 0);
      dataN  : Slv8Array(1 downto 0);
      sdo    : sl;
   end record;
   type AxiAds42lb69InArray is array (natural range <>) of AxiAds42lb69InType;

   type AxiAds42lb69OutType is record
      clkP  : sl;
      clkN  : sl;
      syncP : sl;
      syncN : sl;
      csL   : sl;
      sck   : sl;
      sdi   : sl;
      rst   : sl;
   end record;
   type AxiAds42lb69OutArray is array (natural range <>) of AxiAds42lb69OutType;

   type AxiAds42lb69DelayInType is record
      load : sl;
      rst  : sl;
      data : Slv5VectorArray(1 downto 0, 7 downto 0);
   end record;
   constant AXI_ADS42LB69_DELAY_IN_INIT_C : AxiAds42lb69DelayInType := (
      load => '0',
      rst  => '0',
      data => (others => (others => (others => '0'))));  

   type AxiAds42lb69DelayOutType is record
      rdy  : sl;
      data : Slv5VectorArray(1 downto 0, 7 downto 0);
   end record;
   constant AXI_ADS42LB69_DELAY_OUT_INIT_C : AxiAds42lb69DelayOutType := (
      rdy  => '0',
      data => (others => (others => (others => '0'))));        

   type AxiAds42lb69ConfigType is record
      dmode   : slv(1 downto 0);
      -- IO-Delay Signals (refClk200MHz domain)
      delayIn : AxiAds42lb69DelayInType;
   end record;
   constant AXI_ADS42LB69_CONFIG_INIT_C : AxiAds42lb69ConfigType := (
      dmode   => (others => '0'),
      delayIn => AXI_ADS42LB69_DELAY_IN_INIT_C);    

   type AxiAds42lb69StatusType is record
      adcValid : slv(1 downto 0);
      adcData  : Slv16Array(1 downto 0);
      -- IO-Delay Signals (refClk200MHz domain)
      delayOut : AxiAds42lb69DelayOutType;
   end record;
   constant AXI_ADS42LB69_STATUS_INIT_C : AxiAds42lb69StatusType := (
      adcValid => (others => '0'),
      adcData  => (others => x"0000"),
      delayOut => AXI_ADS42LB69_DELAY_OUT_INIT_C); 

end package;
