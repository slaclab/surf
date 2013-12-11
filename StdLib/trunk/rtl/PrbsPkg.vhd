-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PrbsPkg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-12-10
-- Last update: 2013-12-10
-- Platform   : ISE 14.7
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: PseudoRandom Binary Sequence (PRBS) Package
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;

package PrbsPkg is

   function getPrbs (A : real; tapLoc : natural) return slv;

end PrbsPkg;

package body PrbsPkg is

   function getPrbs (input : slv; tapLoc : natural) return slv is
      variable retVar : slv(input'LEFT downto 0) := (others => '0');
   begin
      --check for a valid tap location
      assert (tapLoc <= input'LEFT) report "PrbsPkg: getPrbs's tapLoc input is out of range" severity failure;
      
      -- shift register
      for i in (input'LEFT - 1) downto 0 loop
         retVar(i) := input(i+1)
      end loop;
      
      -- calculate the "xor'd" feedback
      retVar(input'LEFT) := input(0) xor input(tapLoc);
      
      --return the result
      return retVar;
      
   end function;
   
end package body PrbsPkg;
