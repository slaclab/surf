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

   function getPrbs1xTap (input : slv; tap0 : natural) return slv;
   function getPrbs2xTap (input : slv; tap0, tap1 : natural) return slv;
   function getPrbs3xTap (input : slv; tap0, tap1, tap2 : natural) return slv;

end PrbsPkg;

package body PrbsPkg is

   function getPrbs1xTap (input : slv; tap0 : natural) return slv is
      variable retVar : slv(input'LEFT downto 0) := (others => '0');
   begin
      --check for a valid tap location
      assert (tap0 <= input'LEFT) report "PrbsPkg: getPrbs's tap0 input is out of range" severity failure;
      
      -- shift register
      for i in (input'LEFT - 1) downto 0 loop
         retVar(i) := input(i+1);
      end loop;
      
      -- calculate the "xor'd" feedback
      retVar(input'LEFT) := input(0) xor input(tap0);
      
      --return the result
      return retVar;
      
   end function;
   
   function getPrbs2xTap (input : slv; tap0, tap1 : natural) return slv is
      variable retVar : slv(input'LEFT downto 0) := (others => '0');
   begin
      --check for a valid tap location
      assert (tap0 <= input'LEFT) report "PrbsPkg: getPrbs's tap0 input is out of range" severity failure;
      assert (tap1 <= input'LEFT) report "PrbsPkg: getPrbs's tap1 input is out of range" severity failure;
      
      -- shift register
      for i in (input'LEFT - 1) downto 0 loop
         retVar(i) := input(i+1);
      end loop;
      
      -- calculate the "xor'd" feedback
      retVar(input'LEFT) := input(0) xor input(tap0) xor input(tap1);
      
      --return the result
      return retVar;
      
   end function;   
   
   function getPrbs3xTap (input : slv; tap0, tap1, tap2 : natural) return slv is
      variable retVar : slv(input'LEFT downto 0) := (others => '0');
   begin
      --check for a valid tap location
      assert (tap0 <= input'LEFT) report "PrbsPkg: getPrbs's tap0 input is out of range" severity failure;
      assert (tap1 <= input'LEFT) report "PrbsPkg: getPrbs's tap1 input is out of range" severity failure;
      assert (tap2 <= input'LEFT) report "PrbsPkg: getPrbs's tap2 input is out of range" severity failure;
      
      -- shift register
      for i in (input'LEFT - 1) downto 0 loop
         retVar(i) := input(i+1);
      end loop;
      
      -- calculate the "xor'd" feedback
      retVar(input'LEFT) := input(0) xor input(tap0) xor input(tap1) xor input(tap2);
      
      --return the result
      return retVar;
      
   end function;      
   
end package body PrbsPkg;
