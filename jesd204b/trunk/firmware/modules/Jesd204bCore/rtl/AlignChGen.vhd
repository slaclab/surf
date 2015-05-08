-------------------------------------------------------------------------------
-- Title      : Alignment character generator
-------------------------------------------------------------------------------
-- File       : AlignChGen.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-15
-- Last update: 2015-04-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Replaces data with F and A characters.
--     A(K28.3) - x"7C" - Inserted at the end of a multiframe.   
--     F(K28.7) - x"FC" - Inserted at the end of a frame.
--   Note: The transmitter does not support scrambling (assumes that the receiver does not expect scrambled data)
--         Character replacement procedure is different for scrambled data.
--               
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.jesd204bpkg.all;

entity AlignChGen is
   generic (
      TPD_G        : time   := 1 ns;
      F_G          : positive   := 2);
   port (
      clk      : in  sl;
      rst      : in  sl;
      
      -- Enable counter      
      enable_i  : in  sl;
      
      -- Increase counter
      lmfc_i  : in  sl; 
     
      -- Increase counter
      dataValid_i  : in  sl;

      -- 
      sampleData_i : in slv(GT_WORD_SIZE_C*8-1 downto 0);     
      
      -- Outs    
      sampleData_o : out slv(GT_WORD_SIZE_C*8-1 downto 0);
      sampleK_o    : out slv(  GT_WORD_SIZE_C-1 downto 0)      
   );
end entity AlignChGen;

architecture rtl of AlignChGen is
   
   -- How many samples is in a GT word
   constant SAMPLES_IN_WORD_C    : positive := (GT_WORD_SIZE_C/F_G);
   
   -- Register type
   type RegType is record
      sampleDataD1     : slv(sampleData_o'range);
      sampleDataD2     : slv(sampleData_o'range);
      sampleKD1        : slv(sampleK_o'range);
      lmfcD1           : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      sampleDataD1      => (others => '0'),
      sampleDataD2      => (others => '0'),
      sampleKD1         => (others => '0'),
      lmfcD1            => '0'
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   --
begin


   comb : process (r, rst,sampleData_i, dataValid_i, enable_i, lmfc_i) is
      variable v : RegType;
      variable v_sampleData : slv(sampleData_o'range);
      variable v_sampleK    : slv(sampleK_o'range);
      
      variable v_twoWordBuff: slv( (2*GT_WORD_SIZE_C*8)-1 downto 0);
      variable v_twoCharBuff: slv( (2*GT_WORD_SIZE_C)  -1 downto 0);
   begin
      v := r;

      -- Buffer data for two clock cycles 
      v.sampleDataD1  := sampleData_i;
      v.sampleDataD2  := r.sampleDataD1;

      -- Delay LMFC for 1 c-c
      v.lmfcD1 := lmfc_i;

      -- Combinatorial logic
      v_twoWordBuff:= byteSwapSlv(r.sampleDataD2, GT_WORD_SIZE_C) & byteSwapSlv(r.sampleDataD1, GT_WORD_SIZE_C);
      v_twoCharBuff:= r.sampleKD1 & (sampleK_o'range => '0');

      
      if enable_i = '1' and dataValid_i = '1' then
         -- Replace with A character at the end of the multi-frame
         if r.lmfcD1 = '1' then
               if ( v_twoWordBuff((F_G*8)+7 downto (F_G*8)) = v_twoWordBuff(7 downto 0)) then
                  v_twoWordBuff(7 downto 0)  := A_CHAR_C;
                  v_twoCharBuff(0)       := '1';      
               end if;
         end if;
         
         -- Replace with F character
         for I in (SAMPLES_IN_WORD_C-1) downto 0 loop
            if ( v_twoWordBuff((I*F_G*8)+(F_G*8)+7 downto (I*F_G*8)+(F_G*8)) = v_twoWordBuff((I*F_G*8)+7 downto (I*F_G*8)) and
                 v_twoCharBuff((I*F_G+F_G))  = '0' )
            then
               v_twoWordBuff((I*F_G*8)+7 downto (I*F_G*8))  := F_CHAR_C;
               v_twoCharBuff(I*F_G)                         := '1';      
            end if;
         end loop;
      end if; 
      
      
      
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      
      -- Buffer char for one clock cycles      
      v.sampleKD1 := v_twoCharBuff((GT_WORD_SIZE_C)-1 downto 0); 

      rin <= v;
      
      -- Output assignment
      sampleData_o <= byteSwapSlv(v_twoWordBuff((GT_WORD_SIZE_C*8)-1 downto 0), GT_WORD_SIZE_C);  
      sampleK_o    <= bitReverse(v_twoCharBuff((GT_WORD_SIZE_C)-1 downto 0));
      
   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
---------------------------------------

 
end architecture rtl;
