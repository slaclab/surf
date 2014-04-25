library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

package AxiW25Q128Pkg is
   
   type AxiW25Q128InOutType is record
      sdio : slv(3 downto 0);
      -- Note:
      --    In SPI mode:
      --       sdio[0] = sdi
      --       sdio[1] = sdo
      --       sdio[2] = wpL
      --       sdio[3] = holdL or rstL
      --
      --    In DSPI mode:
      --       sdio[0] = IO[0]
      --       sdio[1] = IO[1]
      --       sdio[2] = wpL
      --       sdio[3] = holdL or rstL
      --
      --    In QSPI mode:
      --       sdio[0] = IO[0]
      --       sdio[1] = IO[1]
      --       sdio[2] = IO[2]
      --       sdio[3] = IO[3]      
   end record;
   type AxiW25Q128InOutArray is array (natural range <>) of AxiW25Q128InOutType;
   constant AXI_W25Q128_IN_OUT_INIT_C : AxiW25Q128InOutType := (
      sdio => (others => 'Z'));        

   type AxiW25Q128OutType is record
      csL : sl;
      sck : sl;
   end record;
   type AxiW25Q128OutArray is array (natural range <>) of AxiW25Q128OutType;
   constant AXI_W25Q128_OUT_INIT_C : AxiW25Q128OutType := (
      '1',
      '1');    

end package;
