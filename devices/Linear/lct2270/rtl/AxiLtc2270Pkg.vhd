-------------------------------------------------------------------------------
-- File       : AxiLtc2270Pkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-21
-- Last update: 2014-04-21
-------------------------------------------------------------------------------
-- Description: AxiLtc2270 Package File
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

package AxiLtc2270Pkg is

   type AxiLtc2270InType is record
      clkP  : sl;
      clkN  : sl;
      dataP : Slv8Array(0 to 1);
      dataN : Slv8Array(0 to 1);
      orP   : sl;
      orN   : sl;
   end record;
   type AxiLtc2270InArray is array (natural range <>) of AxiLtc2270InType;
   constant AXI_LTC2270_IN_INIT_C : AxiLtc2270InType := (
      '1',
      '0',
      (others => (others => '1')),
      (others => (others => '0')),
      '1',
      '0');

   type AxiLtc2270InOutType is record
      sdo : sl;
   end record;
   type AxiLtc2270InOutArray is array (natural range <>) of AxiLtc2270InOutType;
   constant AXI_LTC2270_IN_OUT_INIT_C : AxiLtc2270InOutType := (
      (others => 'Z'));        

   type AxiLtc2270OutType is record
      cs   : sl;
      sck  : sl;
      sdi  : sl;
      par  : sl;
      clkP : sl;
      clkN : sl;
   end record;
   type AxiLtc2270OutArray is array (natural range <>) of AxiLtc2270OutType;
   constant AXI_LTC2270_OUT_INIT_C : AxiLtc2270OutType := (
      '0',
      '0',
      '0',
      '0',
      '1',
      '0');    

   type AxiLtc2270DelayInType is record
      load : sl;
      rst  : sl;
      data : Slv5VectorArray(0 to 1, 0 to 7);
   end record;
   constant AXI_LTC2270_DELAY_IN_INIT_C : AxiLtc2270DelayInType := (
      '0',
      '0',
      (others => (others => (others => '0'))));  

   type AxiLtc2270DelayOutType is record
      rdy  : sl;
      data : Slv5VectorArray(0 to 1, 0 to 7);
   end record;
   constant AXI_LTC2270_DELAY_OUT_INIT_C : AxiLtc2270DelayOutType := (
      '0',
      (others => (others => (others => '0'))));        

   type AxiLtc2270ConfigType is record
      dmode   : slv(1 downto 0);
      -- IO-Delay Signals (refClk200MHz domain)
      delayIn : AxiLtc2270DelayInType;
   end record;
   constant AXI_LTC2270_CONFIG_INIT_C : AxiLtc2270ConfigType := (
      (others => '0'),
      AXI_LTC2270_DELAY_IN_INIT_C);    

   type AxiLtc2270StatusType is record
      adcValid : slv(1 downto 0);
      adcData  : Slv16Array(0 to 1);
      -- IO-Delay Signals (refClk200MHz domain)
      delayOut : AxiLtc2270DelayOutType;
   end record;
   constant AXI_LTC2270_STATUS_INIT_C : AxiLtc2270StatusType := (
      (others => '0'),
      (others => x"0000"),
      AXI_LTC2270_DELAY_OUT_INIT_C); 

end package;
