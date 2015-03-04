-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiWinbondW25QPkg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-25
-- Last update: 2015-03-03
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

package AxiWinbondW25QPkg is
   
   type AxiWinbondW25QInOutType is record
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
   type AxiWinbondW25QInOutArray is array (natural range <>) of AxiWinbondW25QInOutType;
   constant AXI_W25Q128_IN_OUT_INIT_C : AxiWinbondW25QInOutType := (
      sdio => (others => 'Z'));        

   type AxiWinbondW25QOutType is record
      csL : sl;
      sck : sl;
   end record;
   type AxiWinbondW25QOutArray is array (natural range <>) of AxiWinbondW25QOutType;
   constant AXI_W25Q128_OUT_INIT_C : AxiWinbondW25QOutType := (
      csL => '1',
      sck => '1');    

end package;
