library ieee;
use ieee.std_logic_1164.all;

use IEEE.NUMERIC_STD.all;
use work.StdRtlPkg.all;

package Jesd204bPkg is

-- Constant definitions
   constant K_CHAR_C    : slv(7 downto 0) := x"BC";
   
-- Types
-------------------------------------------------------------------------- 
   type ctrlRegType is
   record
      enable  : sl;
      lmfcDly : slv(3 downto 0);
   end record;
   
   type statRegType is
   record
      statReg : slv(7 downto 0);
   end record;
   
   type ctrlRegArrType is array (natural range<>) of ctrlRegType;
   type statRegArrType is array (natural range<>) of statRegType;
   
-- Functions
--------------------------------------------------------------------------  
   -- Detect K character
   function detKcharFunc(data_slv: slv; charisk_slv: slv; bytes_int: positive) return std_logic;
   
   -- Output variable index from SLV (use in variable length shift register) 
   function varIndexOutFunc(shft_slv: slv; index_slv: slv) return std_logic;

end Jesd204bPkg;

package body Jesd204bPkg is

-- Functions
--------------------------------------------------------------------------  
   -- Detect K character
   function detKcharFunc(data_slv: slv; charisk_slv: slv; bytes_int: positive) return std_logic is
   begin

      if(bytes_int = 2) then
         if(   data_slv (7  downto 0 ) = K_CHAR_C and
               data_slv (15 downto 8 ) = K_CHAR_C and
               charisk_slv = (charisk_slv'range => '1')
         ) then
            return '1';
         else
            return '0';
         end if; 
      elsif(bytes_int = 4) then
         if(   data_slv (7  downto 0 ) = K_CHAR_C and
               data_slv (15 downto 8 ) = K_CHAR_C and
               data_slv (23 downto 16) = K_CHAR_C and
               data_slv (31 downto 24) = K_CHAR_C and
               charisk_slv = (charisk_slv'range => '1')
         ) then
            return '1';
         else
            return '0';
         end if;
      else
            return '0';      
      end if;     
   end detKcharFunc; 
   
   -- Output variable index from SLV (use in variable length shift register) 
   function varIndexOutFunc(shft_slv: slv; index_slv: slv) return std_logic is
      variable i : integer;
      
   begin
   
      -- Return the index
      i := to_integer(unsigned(index_slv));    
      return shft_slv(i);    
     
   end varIndexOutFunc; 
   
   

end package body Jesd204bPkg;
