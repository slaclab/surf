-------------------------------------------------------------------------------
-- File       : AlignFrRepCh.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-15
-- Last update: 2016-02-12
-------------------------------------------------------------------------------
-- Description: Align bytes and replace control characters with data
--
-- What is supported:
--              Frame sizes 1, 2, 4
--              GT Word sizes 2, 4  <--- I don't think 2 word is supported because hard coded in Jesd204bPkg.vhd
--
--          Note: 
--          dataRx_i - is little endian and byteswapped (directly from GTH)
--                First sample in time:  dataRx_i(7  downto 0) & dataRx_i(15 downto 8)
--                Second sample in time: dataRx_i(23 downto 16)& dataRx_i(31 downto 24) 
--
--          sampleData_o is big endian and not byteswapped
--                First sample in time:  sampleData_o(31 downto 16) 
--                Second sample in time: sampleData_o(15 downto 0)   
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

entity AlignFrRepCh is
   generic (
      TPD_G : time := 1 ns;

      -- Number of bytes in a frame
      F_G : positive := 2);
   port (
      clk : in sl;
      rst : in sl;

      -- Enable character replacement
      replEnable_i : in sl;

      -- Enable scrambling/descrambling
      scrEnable_i : in sl;

      -- One c-c long pulse from syncFSM indicating that first non K
      -- character has been received
      alignFrame_i : in sl;

      -- Data ready (replace control character with data when '1')
      dataValid_i : in sl;

      -- Data and character indication 
      dataRx_i    : in slv((GT_WORD_SIZE_C*8)-1 downto 0);
      chariskRx_i : in slv(GT_WORD_SIZE_C-1 downto 0);

      -- Sample data output (after allignment, character replacement and scrambling)   
      sampleData_o      : out slv((GT_WORD_SIZE_C*8)-1 downto 0);
      sampleDataValid_o : out sl;

      -- Alignment and sync position errors
      alignErr_o    : out sl;           -- Invalid or misaligned character in the data
      positionErr_o : out sl            -- Invalid (comma) position received at time of alignment
      );
end entity AlignFrRepCh;

architecture rtl of AlignFrRepCh is
   -- How many samples is in a GT word
   constant SAMPLES_IN_WORD_C : positive := (GT_WORD_SIZE_C/F_G);

   type RegType is record
      dataRxD1      : slv(dataRx_i'range);
      chariskRxD1   : slv(chariskRx_i'range);
      dataAlignedD1 : slv(dataRx_i'range);
      charAlignedD1 : slv(chariskRx_i'range);
      scrData       : slv(sampleData_o'range);
      scrDataValid  : sl;
      lfsr          : slv((GT_WORD_SIZE_C*8)-1 downto 0);
      descrData     : slv((GT_WORD_SIZE_C*8)-1 downto 0);
      descrDataValid: sl;
      sampleData    : slv(sampleData_o'range);
      dataValid     : sl;
      position      : slv(chariskRx_i'range);
   end record RegType;

   constant REG_INIT_C : RegType := (
      dataRxD1      => (others => '0'),
      chariskRxD1   => (others => '0'),
      dataAlignedD1 => (others => '0'),
      charAlignedD1 => (others => '0'),
      scrData       => (others => '0'),
      lfsr          => (others => '0'),
      descrData     => (others => '0'),
      scrDataValid  => '0',
      sampleData    => (others => '0'),
      descrDataValid  => '0',
      dataValid     => '0',
      position      => intToSlv(1, GT_WORD_SIZE_C)  -- Initialize at "0001" or "01"  
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
   comb : process (r, rst, chariskRx_i, dataRx_i, alignFrame_i, dataValid_i, replEnable_i, scrEnable_i) is
      variable v : RegType;

      -- Alignment error. Invalid data received at time of alignment
      variable v_positionErr   : sl;
      variable v_alignErr      : sl;
      variable v_twoWordbuff   : slv((GT_WORD_SIZE_C*16)-1 downto 0);
      variable v_twoCharBuff   : slv((GT_WORD_SIZE_C*2) -1 downto 0);
      variable v_twoWordbuffAl : slv((GT_WORD_SIZE_C*16)-1 downto 0);
      variable v_twoCharBuffAl : slv((GT_WORD_SIZE_C*2) -1 downto 0);
      variable v_dataaligned   : slv(dataRx_i'range);
      variable v_charAligned   : slv(chariskRx_i'range);
     
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
         v.position := detectPosFuncSwap(dataRx_i, chariskRx_i, GT_WORD_SIZE_C);
      end if;

      -- Align samples (Combinatorial logic) 

      -- Check position error (if position vector "1111" is returned)
      v_positionErr := ite(allBits (r.position, '1'), '1', '0');

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

      -- Replace the control characters in the data with valid data   
      if(replEnable_i = '1' and dataValid_i = '1') then
         for I in (SAMPLES_IN_WORD_C-1) downto 0 loop
            -- If the A_CHAR_C or F_CHAR_C characters detected in the stream           
            if (v_twoCharBuffAl(I*F_G) = '1' and
                (v_twoWordBuffAl((I*F_G*8+7) downto I*F_G*8) = A_CHAR_C or
                 v_twoWordBuffAl((I*F_G*8+7) downto I*F_G*8) = F_CHAR_C)
                ) then
               -- If scrambling disabled
               -- Replace the character in the data with the data value from previous frame
               if (scrEnable_i = '0') then
                  v_twoWordBuffAl((I*F_G*8+7) downto I*F_G*8) := v_twoWordBuffAl((I*F_G*8+8*F_G)+7 downto (I*F_G*8+8*F_G));
                  v_twoCharBuffAl(I*F_G)                      := '0';
               -- If scrambling enabled
               -- The data value equals char value and only the char flags are cleared
               else
                  v_twoWordBuffAl        := v_twoWordBuffAl;
                  v_twoCharBuffAl(I*F_G) := '0';
               end if;
            end if;
         end loop;
      end if;

      -- Check character if there are still characters in the data and issue the alignment error
      -- The error indicates that the characters in the data are possibly misplaced or wrong characters 
      -- have been received.
      if(replEnable_i = '1' and dataValid_i = '1') then
         for I in (GT_WORD_SIZE_C-1) downto 0 loop
            if (v_twoCharBuffAl(I) = '1') then
               v_alignErr := '1';
            end if;
         end loop;
      end if;

      -- Register data before scrambling
      v.scrData := v_twoWordBuffAl((GT_WORD_SIZE_C*8)-1 downto 0);
      v.scrDataValid  := dataValid_i;
      v.descrDataValid := r.scrDataValid;
      
      -- Descramble data put data into descrambler MSB first
      -- Start descrambling when data is enabled 
      if (scrEnable_i = '1' and r.scrDataValid = '1') then
         for i in (GT_WORD_SIZE_C*8)-1 downto 0 loop
            v.lfsr := v.lfsr(v.lfsr'left-1 downto v.lfsr'right) & r.scrData(i);
            --
            v.descrData(i) := r.scrData(i);
            for j in JESD_PRBS_TAPS_C'range loop
               v.descrData(i)  := v.descrData(i) xor v.lfsr(JESD_PRBS_TAPS_C(j));
            end loop;
            --
         end loop;
      else
         v.descrData := r.scrData;
      end if;

      -- Register sample data before output (Prevent timing issues! Adds one clock cycle to latency!)
      if (scrEnable_i = '1') then
         -- 3 c-c latency
         v.sampleData   := r.descrData;
         v.dataValid    := r.descrDataValid;   
      else
         -- 1 c-c latency
         v.sampleData   := v_twoWordBuffAl((GT_WORD_SIZE_C*8)-1 downto 0);
         v.dataValid    := dataValid_i;
      end if;
      
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      --
      rin <= v;

      -- Output assignment
      positionErr_o     <= v_positionErr;
      alignErr_o        <= v_alignErr;
      sampleData_o      <= r.sampleData;
      sampleDataValid_o <= r.dataValid;
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
