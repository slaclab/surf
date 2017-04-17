-------------------------------------------------------------------------------
-- File       : AxiAd9467Pkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-09-23
-- Last update: 2014-09-24
--------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Description: AD9467 Package File
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

package AxiAd9467Pkg is
   
   type AxiAd9467InType is record
      clkP  : sl;
      clkN  : sl;
      orP   : sl;
      orN   : sl;
      dataP : slv(7 downto 0);
      dataN : slv(7 downto 0);
   end record;
   type AxiAd9467InArray is array (natural range <>) of AxiAd9467InType;
   type AxiAd9467InVectorArray is array (integer range<>, integer range<>)of AxiAd9467InType;
   constant AXI_AD9467_IN_INIT_C : AxiAd9467InType := (
      clkP  => '0',
      clkN  => '1',
      orP   => '0',
      orN   => '1',
      dataP => (others => '0'),
      dataN => (others => '1'));  

   type AxiAd9467InOutType is record
      sdio : sl;
   end record;
   type AxiAd9467InOutArray is array (natural range <>) of AxiAd9467InOutType;
   type AxiAd9467InOutVectorArray is array (integer range<>, integer range<>)of AxiAd9467InOutType;
   constant AXI_AD9467_IN_OUT_INIT_C : AxiAd9467InOutType := (
      sdio => 'Z');        

   type AxiAd9467OutType is record
      cs   : sl;
      sck  : sl;
      clkP : sl;
      clkN : sl;
   end record;
   type AxiAd9467OutArray is array (natural range <>) of AxiAd9467OutType;
   type AxiAd9467OutVectorArray is array (integer range<>, integer range<>)of AxiAd9467OutType;
   constant AXI_AD9467_OUT_INIT_C : AxiAd9467OutType := (
      cs   => '1',
      sck  => '1',
      clkP => '0',
      clkN => '1');       

   type AxiAd9467SpiInType is record
      req  : sl;
      RnW  : sl;
      din  : slv(7 downto 0);
      addr : slv(11 downto 0);
   end record;
   constant AXI_AD9467_SPI_IN_INIT_C : AxiAd9467SpiInType := (
      '0',
      '0',
      (others => '0'),
      (others => '0'));            

   type AxiAd9467SpiOutType is record
      ack  : sl;
      dout : slv(7 downto 0);
   end record;
   constant AXI_AD9467_SPI_OUT_INIT_C : AxiAd9467SpiOutType := (
      '0',
      (others => '0'));  

   type AxiAd9467DelayInType is record
      dmux : sl;
      load : sl;
      rst  : sl;
      data : Slv5Array(0 to 7);
   end record;
   constant AXI_AD9467_DELAY_IN_INIT_C : AxiAd9467DelayInType := (
      dmux => '0',
      load => '0',
      rst  => '0',
      data => (others => "00000"));  

   type AxiAd9467DelayOutType is record
      rdy  : sl;
      data : Slv5Array(0 to 7);
   end record;
   constant AXI_AD9467_DELAY_OUT_INIT_C : AxiAd9467DelayOutType := (
      rdy  => '0',
      data => (others => "00000"));  

   type AxiAd9467StatusType is record
      pllLocked  : sl;
      adcData    : slv(15 downto 0);
      adcDataMon : Slv16Array(0 to 15);
      spi        : AxiAd9467SpiOutType;
      delay      : AxiAd9467DelayOutType;
   end record;
   constant AXI_AD9467_STATUS_INIT_C : AxiAd9467StatusType := (
      pllLocked  => '0',
      adcData    => x"0000",
      adcDataMon => (others => x"0000"),
      spi        => AXI_AD9467_SPI_OUT_INIT_C,
      delay      => AXI_AD9467_DELAY_OUT_INIT_C); 

   type AxiAd9467ConfigType is record
      spi   : AxiAd9467SpiInType;
      delay : AxiAd9467DelayInType;
   end record;
   constant AXI_AD9467_CONFIG_INIT_C : AxiAd9467ConfigType := (
      spi   => AXI_AD9467_SPI_IN_INIT_C,
      delay => AXI_AD9467_DELAY_IN_INIT_C); 

end package;
