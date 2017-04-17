-------------------------------------------------------------------------------
-- File       : PrbsPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-12-10
-- Last update: 2014-01-22
-------------------------------------------------------------------------------
-- Description: PseudoRandom Binary Sequence (PRBS) Package
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
use ieee.numeric_std.all;

use work.StdRtlPkg.all;

package PrbsPkg is

   -- Randomizers based on the ITU-T O.150 Standard
   function getPrbs1xTap (input : slv; tap0 : natural) return slv;
   function getPrbs2xTap (input : slv; tap0, tap1 : natural) return slv;
   function getPrbs3xTap (input : slv; tap0, tap1, tap2 : natural) return slv;
	function getPrbs4xTap (input : slv; tap0, tap1, tap2, tap3 : natural) return slv;
	function getGaloisPrbs4xTap (input : slv; tap0, tap1, tap2, tap3 : natural) return slv;
	
   -- Randomizer based LTC2270 IC
   function getXorRand (input : slv; tap : natural) return slv;  -- NOTE: same function for encoding and decoding

end PrbsPkg;

package body PrbsPkg is
-------------------------------------------------------------------------------
   function getPrbs1xTap (input : slv; tap0 : natural) return slv is
      variable retVar : slv(input'left downto 0) := (others => '0');
   begin

      --check for a valid tap location
      assert (tap0 <= input'left) report "PrbsPkg: getPrbs1xTap's tap0 input is out of range" severity failure;

      -- shift register
      for i in (input'left - 1) downto 0 loop
         retVar(i) := input(i+1);
      end loop;

      -- calculate the "xor'd" feedback
      retVar(input'left) := input(0) xor input(tap0);

      --return the result
      return retVar;
      
   end function;
-------------------------------------------------------------------------------   
   function getPrbs2xTap (input : slv; tap0, tap1 : natural) return slv is
      variable retVar : slv(input'left downto 0) := (others => '0');
   begin

      --check for a valid tap location
      assert (tap0 <= input'left) report "PrbsPkg: getPrbs2xTap's tap0 input is out of range" severity failure;
      assert (tap1 <= input'left) report "PrbsPkg: getPrbs2xTap's tap1 input is out of range" severity failure;

      -- shift register
      for i in (input'left - 1) downto 0 loop
         retVar(i) := input(i+1);
      end loop;

      -- calculate the "xor'd" feedback
      retVar(input'left) := input(0) xor input(tap0) xor input(tap1);

      --return the result
      return retVar;
      
   end function;
-------------------------------------------------------------------------------   
   function getPrbs3xTap (input : slv; tap0, tap1, tap2 : natural) return slv is
      variable retVar : slv(input'left downto 0) := (others => '0');
   begin

      --check for a valid tap location
      assert (tap0 <= input'left) report "PrbsPkg: getPrbs3xTap's tap0 input is out of range" severity failure;
      assert (tap1 <= input'left) report "PrbsPkg: getPrbs3xTap's tap1 input is out of range" severity failure;
      assert (tap2 <= input'left) report "PrbsPkg: getPrbs3xTap's tap2 input is out of range" severity failure;

      -- shift register
      for i in (input'left - 1) downto 0 loop
         retVar(i) := input(i+1);
      end loop;

      -- calculate the "xor'd" feedback
      retVar(input'left) := input(0) xor input(tap0) xor input(tap1) xor input(tap2);

      --return the result
      return retVar;
      
   end function;
-------------------------------------------------------------------------------   
   function getPrbs4xTap (input : slv; tap0, tap1, tap2, tap3 : natural) return slv is
      variable retVar : slv(input'left downto 0) := (others => '0');
   begin

      --check for a valid tap location
      assert (tap0 <= input'left) report "PrbsPkg: getPrbs3xTap's tap0 input is out of range" severity failure;
      assert (tap1 <= input'left) report "PrbsPkg: getPrbs3xTap's tap1 input is out of range" severity failure;
      assert (tap2 <= input'left) report "PrbsPkg: getPrbs3xTap's tap2 input is out of range" severity failure;
      assert (tap3 <= input'left) report "PrbsPkg: getPrbs3xTap's tap3 input is out of range" severity failure;
		
      -- shift register
      for i in (input'left - 1) downto 0 loop
         retVar(i) := input(i+1);
      end loop;

      -- calculate the "xor'd" feedback
      retVar(input'left) := input(tap0) xor input(tap1) xor input(tap2) xor input(tap3);

      --return the result
      return retVar;
      
   end function;
-------------------------------------------------------------------------------   
   function getGaloisPrbs4xTap (input : slv; tap0, tap1, tap2, tap3 : natural) return slv is
      variable retVar : slv(input'left downto 0) := (others => '0');
   begin

      --check for a valid tap location
      assert (tap0 <= input'left) report "PrbsPkg: getGaloisPrbs3xTap's tap0 input is out of range" severity failure;
      assert (tap1 <= input'left) report "PrbsPkg: getGaloisPrbs3xTap's tap1 input is out of range" severity failure;
      assert (tap2 <= input'left) report "PrbsPkg: getGaloisPrbs3xTap's tap2 input is out of range" severity failure;
      assert (tap3 <= input'left) report "PrbsPkg: getGaloisPrbs3xTap's tap3 input is out of range" severity failure;
		
      -- shift register
      for i in 0 to (input'left-1) loop
         retVar(i) := input(i+1);
      end loop;
		retVar(retVar'left) := '0';

		for i in 0 to (input'left) loop
			if (i = tap0 or i = tap1 or i = tap2 or i = tap3) then
				retVar(i) := retVar(i) xor input(0);
			end if;
		end loop;
		
      --return the result
      return retVar;
      
   end function;
-------------------------------------------------------------------------------   
   function getXorRand (input : slv; tap : natural) return slv is  -- NOTE: same function for encoding and decoding
      variable retVar : slv(input'left downto 0) := (others => '0');
   begin

      --check for a valid tap location
      assert (tap <= input'left) report "PrbsPkg: getXorRand's tap input is out of range" severity failure;

      -- Encoder/Decoder
      for i in input'left downto 0 loop
         if i = tap then
            retVar(i) := input(i);
         else
            retVar(i) := input(i) xor input(tap);
         end if;
      end loop;

      --return the result
      return retVar;
      
   end function;
-------------------------------------------------------------------------------   
end package body PrbsPkg;
