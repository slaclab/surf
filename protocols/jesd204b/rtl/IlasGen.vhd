-------------------------------------------------------------------------------
-- File       : TestStreamTx.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-15
-- Last update: 2015-04-15
-------------------------------------------------------------------------------
-- Description: Initial lane alignment sequence Generator
--              Adds A na R characters at the LMFC borders.
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
use work.jesd204bpkg.all;

entity ilasGen is
   generic (
      TPD_G        : time   := 1 ns;
      F_G          : positive   := 2);
   port (
      clk      : in  sl;
      rst      : in  sl;
      
      -- Enable counter      
      enable_i  : in  sl;
      
      -- Increase counter
      ilas_i  : in  sl; 
      
      -- Increase counter
      lmfc_i  : in  sl; 

      -- Outs    
      ilasData_o : out slv(GT_WORD_SIZE_C*8-1 downto 0);
      ilasK_o    : out slv(  GT_WORD_SIZE_C-1 downto 0)      
   );
end entity ilasGen;

architecture rtl of ilasGen is
   
   type RegType is record
      lmfcD1      : sl;
      lmfcD2      : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      lmfcD1       => '0',
      lmfcD2       => '0'      
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   --
begin

   comb : process (r, rst,lmfc_i,enable_i, ilas_i) is
      variable v : RegType;
      variable v_ilasData : slv(ilasData_o'range);
      variable v_ilasK    : slv(ilasK_o'range);
   begin
      v := r;
     
      -- Delay LMFC for 2 c-c
      v.lmfcD1 := lmfc_i;
      v.lmfcD2 := r.lmfcD1;
          
      -- Combinatorial logic
      v_ilasData := (others => '0');
      v_ilasK    := (others => '0');
      
      if enable_i = '1' and ilas_i = '1' then
         -- Send A character
         if r.lmfcD1 = '1' then
            v_ilasData(v_ilasData'high downto v_ilasData'high-7)  := A_CHAR_C;
            v_ilasK(v_ilasK'high)                                 := '1';       
         end if;
         -- Send R character         
         if r.lmfcD2 = '1' then
            v_ilasData (7 downto 0)   := R_CHAR_C;
            v_ilasK(0)                := '1';          
         end if;  
      end if;
      
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;
      
      -- Output assignment
      ilasData_o <= v_ilasData;      
      ilasK_o    <= v_ilasK;
   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
---------------------------------------   
end architecture rtl;
