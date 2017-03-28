-------------------------------------------------------------------------------
-- File       : AlignChGen.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-15
-- Last update: 2016-02-22
-------------------------------------------------------------------------------
-- Description:  Alignment character generator
--     Scrambles incoming data if enabled
--     Inverts incoming data if enabled
--
--     Replaces data with F and A characters.
--     A(K28.3) - x"7C" - Inserted at the end of a multiframe.   
--     F(K28.7) - x"FC" - Inserted at the end of a frame.
--     
--     Note: Character replacement mechanism is different weather scrambler is enabled or disabled.
--     Disabled: The characters are inserted if two corresponding octets in consecutive samples have the same value.
--     Enabled:  The characters are inserted it the corresponding octet has the same value as the inserted character.    
--     
--     3 c-c data latency
--       
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

entity AlignChGen is
   generic (
      TPD_G : time     := 1 ns;
      F_G   : positive := 2);
   port (
      clk : in sl;
      rst : in sl;

      -- Enable counter      
      enable_i : in sl;

      -- Enable scrambling/descrambling
      scrEnable_i : in sl;

      -- Local multi clock
      lmfc_i : in sl;

      -- Valid data from Tx FSM
      dataValid_i : in sl;

      -- Invert ADC data
      inv_i     : in sl:='0';
      
      -- 
      sampleData_i : in slv(GT_WORD_SIZE_C*8-1 downto 0);

      -- Outs    
      sampleData_o : out slv(GT_WORD_SIZE_C*8-1 downto 0);
      sampleK_o    : out slv(GT_WORD_SIZE_C-1 downto 0)
      );
end entity AlignChGen;

architecture rtl of AlignChGen is

   -- How many samples is in a GT word
   constant SAMPLES_IN_WORD_C : positive := (GT_WORD_SIZE_C/F_G);

   -- Register type
   type RegType is record
      sampleDataReg : slv(sampleData_o'range);
      sampleDataInv : slv(sampleData_o'range);
      sampleDataD1  : slv(sampleData_o'range);
      sampleDataD2  : slv(sampleData_o'range);
      sampleKD1     : slv(sampleK_o'range);
      lmfcD1        : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      sampleDataReg => (others => '0'), 
      sampleDataInv => (others => '0'),             
      sampleDataD1  => (others => '0'),
      sampleDataD2  => (others => '0'),
      sampleKD1     => (others => '0'),
      lmfcD1        => '0'
      );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

--
begin


   comb : process (r, rst, sampleData_i, dataValid_i, enable_i, lmfc_i, scrEnable_i,
                   inv_i) is
      variable v            : RegType;
      variable v_sampleData : slv(sampleData_o'range);
      variable v_sampleK    : slv(sampleK_o'range);

      variable v_twoWordBuff : slv((2*GT_WORD_SIZE_C*8)-1 downto 0);
      variable v_twoCharBuff : slv((2*GT_WORD_SIZE_C) -1 downto 0);
   begin
      v := r;
      
      -- Register data
      v.sampleDataReg := sampleData_i;
      
      -- Invert Data if enabled
      if (inv_i = '1') then
      -- Invert sample data      
         v.sampleDataInv :=  invData(r.sampleDataReg, F_G, GT_WORD_SIZE_C);
      else
         v.sampleDataInv :=  r.sampleDataReg;
      end if;
     
      -- Scramble Data if enabled
      if scrEnable_i = '1' then
         -- Scramble the data if scrambling enabled
         for i in (GT_WORD_SIZE_C*8)-1 downto 0 loop
            v.sampleDataD1 := lfsrShift(v.sampleDataD1, JESD_PRBS_TAPS_C, r.sampleDataInv(i));
         end loop;
      else
         -- Use the data from the input if scrambling disabled 
         v.sampleDataD1 := r.sampleDataInv;
      end if;


      -- Buffer data for two clock cycles
      v.sampleDataD2 := r.sampleDataD1;

      -- Delay LMFC for 1 c-c
      v.lmfcD1 := lmfc_i;

      -- Combinatorial logic
      v_twoWordBuff := r.sampleDataD2 & r.sampleDataD1;
      v_twoCharBuff := r.sampleKD1 & (sampleK_o'range => '0');

      --
      if enable_i = '1' and dataValid_i = '1' then
         -- Replace with A character at the end of the multi-frame
         if r.lmfcD1 = '1' then
            if scrEnable_i = '1' then
               if (v_twoWordBuff(7 downto 0) = A_CHAR_C) then
                  v_twoCharBuff(0) := '1';
               end if;            
            else
               if (v_twoWordBuff((F_G*8)+7 downto (F_G*8)) = v_twoWordBuff(7 downto 0)) then
                  v_twoWordBuff(7 downto 0) := A_CHAR_C;
                  v_twoCharBuff(0) := '1';
               end if;
            end if;
         end if;

         -- Replace with F character
         for I in (SAMPLES_IN_WORD_C-1) downto 0 loop
            if scrEnable_i = '1' then
               if (v_twoWordBuff((I*F_G*8)+7 downto (I*F_G*8)) = F_CHAR_C and
                  v_twoCharBuff((I*F_G+F_G)) = '0')
               then
                  v_twoCharBuff(I*F_G) := '1';
               end if;            
            else   
               if (v_twoWordBuff((I*F_G*8)+(F_G*8)+7 downto (I*F_G*8)+(F_G*8)) = v_twoWordBuff((I*F_G*8)+7 downto (I*F_G*8)) and
                   v_twoCharBuff((I*F_G+F_G)) = '0')
               then
                  v_twoWordBuff((I*F_G*8)+7 downto (I*F_G*8)) := F_CHAR_C;
                  v_twoCharBuff(I*F_G)                        := '1';
               end if;
            end if;
         end loop;
      end if;

      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Buffer char for one clock cycle     
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
