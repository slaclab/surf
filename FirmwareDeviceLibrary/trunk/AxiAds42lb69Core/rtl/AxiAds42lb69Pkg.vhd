library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

package AxiAds42lb69Pkg is

   type AxiAds42lb69InType is record
      clkFbP  : sl;
      clkFbN  : sl;
      dataP   : Slv8Array(0 to 1);
      dataN   : Slv8Array(0 to 1);
      sdo     : sl;
   end record;
   type AxiAds42lb69InArray is array (natural range <>) of AxiAds42lb69InType;
     
   type AxiAds42lb69OutType is record
      clkP  : sl;
      clkN  : sl;
      syncP : sl;
      syncN : sl;      
      csL    : sl;
      sck   : sl;
      sdi   : sl;
      rst   : sl;
   end record;
   type AxiAds42lb69OutArray is array (natural range <>) of AxiAds42lb69OutType;

   type AxiAds42lb69DelayInType is record
      load : sl;
      rst  : sl;
      data : Slv5VectorArray(0 to 1, 0 to 7);
   end record;
   constant AXI_ADS42LB69_DELAY_IN_INIT_C : AxiAds42lb69DelayInType := (
      '0',
      '0',
      (others => (others => (others => '0'))));  

   type AxiAds42lb69DelayOutType is record
      rdy  : sl;
      data : Slv5VectorArray(0 to 1, 0 to 7);
   end record;
   constant AXI_ADS42LB69_DELAY_OUT_INIT_C : AxiAds42lb69DelayOutType := (
      '0',
      (others => (others => (others => '0'))));        

   type AxiAds42lb69ConfigType is record
      dmode   : slv(1 downto 0);
      -- IO-Delay Signals (refClk200MHz domain)
      delayIn : AxiAds42lb69DelayInType;
   end record;
   constant AXI_ADS42LB69_CONFIG_INIT_C : AxiAds42lb69ConfigType := (
      (others => '0'),
      AXI_ADS42LB69_DELAY_IN_INIT_C);    

   type AxiAds42lb69StatusType is record
      adcValid : slv(1 downto 0);
      adcData  : Slv16Array(0 to 1);
      -- IO-Delay Signals (refClk200MHz domain)
      delayOut : AxiAds42lb69DelayOutType;
   end record;
   constant AXI_ADS42LB69_STATUS_INIT_C : AxiAds42lb69StatusType := (
      (others => '0'),
      (others => x"0000"),
      AXI_ADS42LB69_DELAY_OUT_INIT_C); 

end package;
