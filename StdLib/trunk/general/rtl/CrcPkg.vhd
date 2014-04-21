-------------------------------------------------------------------------------
-- Title      : CRC Package
-------------------------------------------------------------------------------
-- File       : CrcPkg.vhd
-- Author     : Kurtis Nishimura, kurtisn@slac.stanford.edu
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-21
-- Last update: 2014-04-21
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: This package defines a few functions that are useful for 
--              computing CRC values.   
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use work.StdRtlPkg.all;

package CrcPkg is 

   function crcByteLookup (inByte : slv; constant poly : slv) return slv;
   function crcLfsrShift (lfsr : slv; constant poly : slv; input : sl) return slv;
   
end CrcPkg;

package body CrcPkg is

   -------------------------------------------------------------------------------------------------
   -- Implements an N tap linear feedback shift operation suitable for CRC implementations
   -- This uses a Galois LFSR and inherently assumes the highest polynomial term is 1
   -- (e.g., in CRC32 the x^32 term is implicit, so the standard polynomial 0x04C11DB7 is
   --  good enough). 
   --
   -- Size of LFSR is variable and determined by length of lfsr parameter, but size of the
   -- lfsr and polynomial should match.
   --
   -- The shift is in the direction of increasing index (left shift for decending, right for ascending)
   -- New data bits are shifted in from the lsb-end.
   --
   -- As written, this can be called N-times to implement CRC calculations, but requires an 
   -- a message augmented with zeroes to match standard CRC calculations.  This makes it a 
   -- "nondirect" implementation.
   -------------------------------------------------------------------------------------------------

   function crcLfsrShift (lfsr : slv; constant poly : slv; input : sl) return slv is
      variable retVar : slv(lfsr'range) := (others => '0');
   begin
      for i in lfsr'range loop
         if poly(i) = '1' then
            if (i = 0) then
               retVar(i) := lfsr(lfsr'left) xor input;  
            else
               retVar(i) := lfsr(lfsr'left) xor lfsr(i-1);               
            end if;
         else
            if (i = 0) then
               retVar(i) := input;
            else
               retVar(i) := lfsr(i-1);
            end if;
         end if;
      end loop;

      return retVar;
   end function;  

   -------------------------------------------------------------------------------------------------
   -- Implements an lookup of CRC values for a given data byte.  This is used in many 
   -- "table driven" implementations of CRC.
   -- Supports both ascending or descending bit orders.
   -------------------------------------------------------------------------------------------------

   function crcByteLookup (inByte : slv; constant poly : slv) return slv is 
      variable retVar : slv(poly'range) := (others => '0');
   begin
      assert (inByte'high-inByte'low = 7) report "crcByteLookup() - input must be byte-sized" severity failure;

      if (inByte'ascending) then
         retVar(retVar'right-7 to retVar'right) := inByte;
         retVar(0 to retVar'right-8)            := (others => '0');
      
         for b in 7 downto 0 loop
            if (retVar(retVar'right) = '1') then
               retVar := ('0' & retVar(0 to retVar'right-1)) xor poly;
            else
               retVar := ('0' & retVar(0 to retVar'right-1));
            end if;
         end loop;
               
      else
         retVar(retVar'left downto retVar'left-7) := inByte;
         retVar(retVar'left-8 downto 0)           := (others => '0');

         for b in 7 downto 0 loop
            if (retVar(retVar'left) = '1') then
               retVar := (retVar(retVar'left-1 downto 0) & '0') xor poly;
            else
               retVar := (retVar(retVar'left-1 downto 0) & '0');
            end if;
         end loop;
      end if;

      return retVar;
 
   end function; 


end package body CrcPkg;

