-------------------------------------------------------------------------------
-- File       : TestSigGen.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-15
-- Last update: 2015-04-15
-------------------------------------------------------------------------------
-- Description: Outputs a digital signal depending on thresholds
--              This is a test module so only F_G = 2 
--              and is GT_WORD_SIZE_C = 4 is supported.          
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.Jesd204bPkg.all;

entity TestSigGen is
   generic (
      TPD_G        : time       := 1 ns;
      
      -- Number of bytes in a frame
      F_G : positive := 2);
   port (
      clk      : in  sl;
      rst      : in  sl;
      
      -- Enable pulser
      enable_i   : in  sl;
      
      -- Threshold for Rising edge detection      
      thresoldLow_i  : in  slv((F_G*8)-1 downto 0);
      thresoldHigh_i : in  slv((F_G*8)-1 downto 0);
       
      -- Sample data input     
      sampleData_i  : in slv((GT_WORD_SIZE_C*8)-1 downto 0);
      
      -- Test signal 
      testSig_o    : out sl
   );
end entity TestSigGen;

architecture rtl of TestSigGen is
  
   type RegType is record
      sig         : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      sig              => '0'
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   signal s_sampleDataBr : slv(sampleData_i'range);
   
begin

   s_sampleDataBr <= sampleData_i;
   
   -- Buffer two GT words. And compare previous and current samples to threshold.
   -- If the difference between the previous and current sample is higher than threshold
   -- output a pulse.
   ---------------------------------------------------------------------
   ---------------------------------------------------------------------
   comb : process (r, rst,s_sampleDataBr, thresoldLow_i, thresoldHigh_i, enable_i) is
      variable v : RegType;
   begin
      v := r;
      
--      if (  signed(s_sampleDataBr((F_G*8)-1 downto 0) ) > signed(thresoldHigh_i))   then
      if (  s_sampleDataBr((F_G*8)-1 downto 0) > thresoldHigh_i)   then
         v.sig := '1';
--      elsif (  signed(s_sampleDataBr((F_G*8)-1 downto 0) ) < signed(thresoldLow_i)) then
      elsif (  s_sampleDataBr((F_G*8)-1 downto 0) < thresoldLow_i) then
         v.sig := '0';
      end if;
      
      if (rst = '1' or enable_i='0') then
         v := REG_INIT_C;
      end if;

      -- Output assignment
      rin <= v;
      testSig_o <= r.sig;
      -----------------------------------------------------------
   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   ---------------------------------------------------------------------
   ---------------------------------------------------------------------
end architecture rtl;
