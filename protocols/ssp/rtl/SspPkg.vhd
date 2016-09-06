-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SspPkg.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-08-26
-- Last update: 2014-08-26
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.STD_LOGIC_ARITH.all;

use work.StdRtlPkg.all;
use work.Code8b10bPkg.all;

package SspPkg is

   constant SSP_IDLE_CHAR_C : slv(15 downto 0) := D_10_2_C & K_28_5_C;
   constant SSP_SOF_CHAR_C  : slv(15 downto 0) := D_10_2_C & K_23_7_C;
   constant SSP_EOF_CHAR_C  : slv(15 downto 0) := D_10_2_C & K_29_7_C;

end package SspPkg;
