-------------------------------------------------------------------------------
-- Title      : Align bytes and replace control characters with data
-------------------------------------------------------------------------------
-- File       : alignFrRepCh.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-15
-- Last update: 2015-04-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: What is supported 
--              Frame sizes 1, 2
--              GT Word sizes 2, 4
--              
--              
--              
--              
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.Jesd204bPkg.all;

entity alignFrRepCh is
   generic (
      TPD_G        : time       := 1 ns;
      
      -- Number of bytes in a frame
      F_G : positive := 2);
   port (
      clk      : in  sl;
      rst      : in  sl;
      
      -- One c-c long pulse from syncFSM indicating that first non K
      -- character has been received
      alignFrame_i   : in  sl;
      
      -- Data ready (replace control character with data when '1')
      dataReady_i    : in  sl;
      
      -- Data and character indication 
      dataRx_i       : in    slv((GT_WORD_SIZE_C*8)-1 downto 0);       
      chariskRx_i    : in    slv(GT_WORD_SIZE_C-1     downto 0);
      
      -- Aligned sample data output     
      sampleData_o  : out slv((GT_WORD_SIZE_C*8)-1    downto 0);
      
      -- Alignment error
      -- Invalid data received at time of alignment
      alignErr_o    : out sl
   );
end entity alignFrRepCh;

architecture rtl of alignFrRepCh is
   
   type RegType is record
      dataRxD1       : slv(dataRx_i'range);
      chariskRxD1    : slv(chariskRx_i'range);
      position       : slv(chariskRx_i'range);
   end record RegType;

   constant REG_INIT_C : RegType := (
      dataRxD1       => (others => '0'),
      chariskRxD1    => (others => '0'),
      position       => intToSlv(1, GT_WORD_SIZE_C) -- Initialize at "0001" or "01"  
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   --! Internal signals
   
   -- Alignment error. Invalid data received at time of alignment
   signal s_alignErr    : sl; 

   -- Alignment error. Invalid data received at time of alignment  
   signal s_twowordbuff : slv((GT_WORD_SIZE_C*16)-1    downto 0);
   signal s_dataaligned : slv(dataRx_i'range);
   
begin

   -- Buffer two GT words (Sequential logic)
   -- Register the alignment position when alignFrame_i pulse
   -- Incorrect alignment (non valid data word received) will result in
   -- v.position = (others => '1')
   ---------------------------------------------------------------------
   ---------------------------------------------------------------------
   comb : process (r, rst,chariskRx_i,dataRx_i,alignFrame_i ) is
      variable v : RegType;
   begin
      v := r;
      
      -- Buffer data and char one clock cycle 
      v.dataRxD1    := dataRx_i;
      v.chariskRxD1 := chariskRx_i;

      -- Register the alignment 
      if (alignFrame_i = '1') then
         v.position := detectPosFunc(dataRx_i,chariskRx_i, GT_WORD_SIZE_C);
      end if;
      
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;
      
   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -- Align samples (Combinatorial logic)
   ---------------------------------------------------------------------
   ---------------------------------------------------------------------
   
   -- Check alignment error
   s_alignErr    <= '1' when r.position = (r.position'range => '1') else '0';
   
   -- Byte swap and combine the two consecutive GT words
   s_twoWordBuff <= byteSwapSlv(r.dataRxD1, GT_WORD_SIZE_C) & byteSwapSlv(dataRx_i, GT_WORD_SIZE_C);

   -- Align the bytes within the words                     
   s_dataAligned <= JesdDataAlign(s_twoWordBuff, r.position, GT_WORD_SIZE_C);

   -- Output assignment
  alignErr_o   <= s_alignErr;
  sampleData_o <= byteSwapSlv(s_dataAligned, GT_WORD_SIZE_C);

end architecture rtl;
