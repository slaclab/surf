-------------------------------------------------------------------------------
-- Title      : Align bytes and replace control characters with data
-------------------------------------------------------------------------------
-- File       : AlignFrRepCh.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-15
-- Last update: 2015-04-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: What is supported 
--              Frame sizes 1, 2, 4
--              GT Word sizes 2, 4            
-------------------------------------------------------------------------------
-- This file is part of 'SLAC JESD204b Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC JESD204b Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.Jesd204bPkg.all;

entity AlignFrRepCh is
   generic (
      TPD_G        : time       := 1 ns;
      
      -- Number of bytes in a frame
      F_G : positive := 2);
   port (
      clk      : in  sl;
      rst      : in  sl;
      
      -- Enable character replacement
      replEnable_i : in  sl;
      
      -- One c-c long pulse from syncFSM indicating that first non K
      -- character has been received
      alignFrame_i   : in  sl;
      
      -- Data ready (replace control character with data when '1')
      dataValid_i    : in  sl;
      
      -- Data and character indication 
      dataRx_i       : in  slv((GT_WORD_SIZE_C*8)-1 downto 0);       
      chariskRx_i    : in  slv(GT_WORD_SIZE_C-1     downto 0);
      
      -- Aligned sample data output     
      sampleData_o  : out slv((GT_WORD_SIZE_C*8)-1    downto 0);
      
      -- Alignment and sync position errors
      alignErr_o    : out sl; -- Invalid or misaligned character in the data
      positionErr_o : out sl  -- Invalid (comma) position received at time of alignment
   );
end entity AlignFrRepCh;

architecture rtl of AlignFrRepCh is
   -- How many samples is in a GT word
   constant SAMPLES_IN_WORD_C    : positive := (GT_WORD_SIZE_C/F_G);
   
   type RegType is record
      dataRxD1       : slv(dataRx_i'range);
      chariskRxD1    : slv(chariskRx_i'range);
      dataAlignedD1  : slv(dataRx_i'range);
      charAlignedD1  : slv(chariskRx_i'range);
      position       : slv(chariskRx_i'range);

   end record RegType;

   constant REG_INIT_C : RegType := (
      dataRxD1       => (others => '0'),
      chariskRxD1    => (others => '0'),
      dataAlignedD1  => (others => '0'),
      charAlignedD1  => (others => '0'),
      position       => intToSlv(1, GT_WORD_SIZE_C) -- Initialize at "0001" or "01"  
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   
begin

   -- Buffer two GT words (Sequential logic)
   -- Register the alignment position when alignFrame_i pulse
   -- Incorrect alignment (non valid data word received) will result in
   -- v.position = (others => '1')
   ---------------------------------------------------------------------
   ---------------------------------------------------------------------
   comb : process (r, rst,chariskRx_i,dataRx_i,alignFrame_i,dataValid_i,replEnable_i) is
      variable v : RegType;
      
         -- Alignment error. Invalid data received at time of alignment
      variable v_positionErr   : sl;
      variable v_alignErr      : sl;      
      variable v_twoWordbuff   : slv((GT_WORD_SIZE_C*16)-1    downto 0);
      variable v_twoCharBuff   : slv((GT_WORD_SIZE_C*2) -1    downto 0);
      variable v_twoWordbuffAl : slv((GT_WORD_SIZE_C*16)-1    downto 0);
      variable v_twoCharBuffAl : slv((GT_WORD_SIZE_C*2) -1    downto 0);
      variable v_dataaligned   : slv(dataRx_i'range);
      variable v_charAligned   : slv(chariskRx_i'range);  
      variable v_data          : slv(dataRx_i'range);

   begin
      v := r;
      
      -- Buffer data and char one clock cycle 
      v.dataRxD1    := dataRx_i;
      v.chariskRxD1 := chariskRx_i;

      -- Buffer aligned data
      v.dataAlignedD1 := v_dataAligned;
      v.charAlignedD1 := v_charAligned;

      -- Register the alignment 
      if (alignFrame_i = '1') then
         v.position := detectPosFuncSwap(dataRx_i,chariskRx_i, GT_WORD_SIZE_C);
      end if;

   -- Align samples (Combinatorial logic) 
   
      -- Check position error (if position vector "1111" is returned)
      v_positionErr    := ite(allBits (r.position, '1'), '1', '0');
      
      -- Byte swap and combine the two consecutive GT words
      v_twoWordBuff := byteSwapSlv(r.dataRxD1, GT_WORD_SIZE_C) & byteSwapSlv(dataRx_i, GT_WORD_SIZE_C);  
      v_twoCharBuff := bitReverse(r.chariskRxD1) & bitReverse(chariskRx_i);
     
      -- Align the bytes within the words                     
      v_dataAligned := JesdDataAlign(v_twoWordBuff, r.position, GT_WORD_SIZE_C);
      v_charAligned := JesdCharAlign(v_twoCharBuff, r.position, GT_WORD_SIZE_C);
      
   -- Buffer aligned word and replace the alignment characters with the data
      v_twoWordBuffAl := r.dataAlignedD1 & v_dataAligned;
      v_twoCharBuffAl := r.charAlignedD1 & v_charAligned;
      v_alignErr      := '0';
      
   -- Replace the character in the data with the data value from previous frame    
      if(replEnable_i = '1' and dataValid_i = '1') then
         for I in (SAMPLES_IN_WORD_C-1) downto 0 loop
            -- Replace the character in the data with the data value from previous frame             
            if ( v_twoCharBuffAl(I*F_G) = '1' and
                 (v_twoWordBuffAl( (I*F_G*8+7) downto I*F_G*8) = A_CHAR_C or
                  v_twoWordBuffAl( (I*F_G*8+7) downto I*F_G*8) = F_CHAR_C)
               ) then
               v_twoWordBuffAl((I*F_G*8+7) downto I*F_G*8) := v_twoWordBuffAl( (I*F_G*8+8*F_G)+7 downto (I*F_G*8+8*F_G));    
               v_twoCharBuffAl(I*F_G) := '0';
            end if;
         end loop;
      end if;
      
   -- Check character if there are still characters in the data and issue the alignment error
   -- The error indicates that the characters in the data are possibly misplaced or wrong characters 
   -- have been received.
      if(replEnable_i = '1' and dataValid_i = '1') then
         for I in (GT_WORD_SIZE_C-1) downto 0 loop
            if ( v_twoCharBuffAl(I) = '1') then
                  v_alignErr := '1';  
            end if;
         end loop;
      end if;

      if (rst = '1') then
         v := REG_INIT_C;
      end if;
      
      -- Output assignment
      rin <= v;
      positionErr_o  <= v_positionErr;      
      alignErr_o     <= v_alignErr;
      sampleData_o   <= byteSwapSlv(v_twoWordBuffAl((GT_WORD_SIZE_C*8)-1 downto 0), GT_WORD_SIZE_C);
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
