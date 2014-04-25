library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

package AxiAd5780Pkg is
   
   type AxiAd5780InType is record
      dacSdo : sl;
   end record;
   type AxiAd5780InArray is array (natural range <>) of AxiAd5780InType;
   type AxiAd5780InVectorArray is array (integer range<>, integer range<>)of AxiAd5780InType;
   constant AXI_AD5780_IN_INIT_C : AxiAd5780InType := (
      (others => '1'));     

   type AxiAd5780OutType is record
      dacSync : sl;
      dacSclk : sl;
      dacSdi  : sl;
      dacLdac : sl;
      dacClr  : sl;
      dacRst  : sl;
   end record;
   type AxiAd5780OutArray is array (natural range <>) of AxiAd5780OutType;
   type AxiAd5780OutVectorArray is array (integer range<>, integer range<>)of AxiAd5780OutType;
   constant AXI_AD5780_OUT_INIT_C : AxiAd5780OutType := (
      '1',
      '1',
      '1',
      '1',
      '1',
      '1');    

   type AxiAd5780StatusType is record
      dacUpdated : sl;
      dacData    : slv(17 downto 0);    -- 2's complement by default
   end record;
   constant AXI_AD5780_STATUS_INIT_C : AxiAd5780StatusType := (
      '0',
      (others => '0')); 

   type AxiAd5780ConfigType is record
      halfSckPeriod : slv(31 downto 0);
      sdoDisable    : sl;
      binaryOffset  : sl;
      dacTriState   : sl;
      opGnd         : sl;
      rbuf          : sl;
      debugMux      : sl;
      debugData     : slv(17 downto 0);  -- 2's complement by default     
   end record;
   constant AXI_AD5780_CONFIG_INIT_C : AxiAd5780ConfigType := (
      (others => '1'),
      '1',
      '0',
      '0',
      '0',
      '1',
      '0',
      (others => '0'));  

end package;
