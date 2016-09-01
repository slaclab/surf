library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

package AxiDac7654Pkg is
   
   type AxiDac7654InType is record
      sdo : sl;
   end record;
   type AxiDac7654InArray is array (natural range <>) of AxiDac7654InType;
   type AxiDac7654InVectorArray is array (integer range<>, integer range<>)of AxiDac7654InType;
   constant AXI_DAC7654_IN_INIT_C : AxiDac7654InType := (
      sdo => '0');  

   type AxiDac7654OutType is record
      cs   : sl;
      sck  : sl;
      sdi  : sl;
      load : sl;
      ldac : sl;
      rst  : sl;
   end record;
   type AxiDac7654OutArray is array (natural range <>) of AxiDac7654OutType;
   type AxiDac7654OutVectorArray is array (integer range<>, integer range<>)of AxiDac7654OutType;
   constant AXI_DAC7654_OUT_INIT_C : AxiDac7654OutType := (
      cs   => '1',
      sck  => '1',
      sdi  => '0',
      load => '1',
      ldac => '0',
      rst  => '0');   

   type AxiDac7654SpiInType is record
      req  : sl;
      data : Slv16Array(0 to 3);
   end record;
   constant AXI_DAC7654_SPI_IN_INIT_C : AxiDac7654SpiInType := (
      req  => '1',
      data => (others => x"8000"));            

   type AxiDac7654SpiOutType is record
      ack : sl;
   end record;
   constant AXI_DAC7654_SPI_OUT_INIT_C : AxiDac7654SpiOutType := (
      ack => '0');

   type AxiDac7654StatusType is record
      spi : AxiDac7654SpiOutType;
   end record;
   constant AXI_DAC7654_STATUS_INIT_C : AxiDac7654StatusType := (
      spi => AXI_DAC7654_SPI_OUT_INIT_C); 

   type AxiDac7654ConfigType is record
      spi : AxiDac7654SpiInType;
   end record;
   constant AXI_DAC7654_CONFIG_INIT_C : AxiDac7654ConfigType := (
      spi => AXI_DAC7654_SPI_IN_INIT_C); 

end package;
