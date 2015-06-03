-------------------------------------------------------------------------------
-- Title      : Test Data Stream Generator
-------------------------------------------------------------------------------
-- File       : TestStreamTx.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-15
-- Last update: 2015-04-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Outputs a ramp test signal as sample data stream for testing
--              Step size:  
--                   - rampStep_i=0 increment every c-c 
--                   - rampStep_i=1 increment every second c-c
--                   - rampStep_i=2 increment third second c-c
--                   - ...
--              Note: An increment corresponds to GT word size and bytes in frame (F_G). 
--                    So if GT word size is 4-bytes and F_G=2 the increment period will be /2.
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
 
library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;

use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.jesd204bpkg.all;

entity TestStreamTx is
   generic (
      TPD_G        : time   := 1 ns;
      F_G          : positive   := 2
   );
   port (
      clk      : in  sl;
      rst      : in  sl;
      
      -- Enable counter      
      enable_i     : in  sl;
      sawNRamp_i        : in  sl;      
      -- Increase counter by the step
      rampStep_i   : in slv(RAMP_STEP_WIDTH_C-1 downto 0);     
 
      -- Outs 
      sampleData_o : out slv(GT_WORD_SIZE_C*8-1 downto 0)  
   );
end entity TestStreamTx;

architecture rtl of TestStreamTx is
   
   constant SAM_IN_WORD_C    : positive := (GT_WORD_SIZE_C/F_G);

   type RegType is record
      stepCnt      : slv(RAMP_STEP_WIDTH_C-1 downto 0);
      rampCnt      : signed(F_G*8-1 downto 0);
      inc          : sl;      
   end record RegType;

   constant REG_INIT_C : RegType := (
      stepCnt     => (others => '0'),
      rampCnt     => (others => '0'),
      inc         => '1'
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   -- 
   signal s_sample_data : slv (sampleData_o'range);
   --
begin

   comb : process (r, rst,enable_i,rampStep_i,sawNRamp_i) is
      variable v : RegType;
      variable v_rampCntPP : signed(F_G*8 downto 0);  
   begin
      v := r;
          
      -- Ramp generator      
      ------------------------------------------------------------- 
      -- Increment/decrement ramp control
      if (v.inc = '0') then
         v_rampCntPP := ('0'&v.rampCnt) - slvToInt(rampStep_i)*SAM_IN_WORD_C;
         if (v_rampCntPP(F_G*8) = '1') then
            v.inc := '1';
         end if;
      elsif (v.inc = '1') then
         v_rampCntPP := ('0'&v.rampCnt) + slvToInt(rampStep_i)*SAM_IN_WORD_C;
         if (v_rampCntPP(F_G*8) = '1') then
            v.inc := '0';
         end if;
      end if;
      
      if (sawNRamp_i = '1') then
         v.inc := '1';
      end if;
      
      -- Ramp up or down counter
       if (v.inc = '1') then
        -- Increment sample base
         v.rampCnt := r.rampCnt +  slvToInt(rampStep_i)*SAM_IN_WORD_C;
         
         -- Increment samples within the word
         for I in (SAM_IN_WORD_C-1) downto 0 loop
            s_sample_data((F_G*8*I)+(F_G*8-1) downto F_G*8*I)     <= std_logic_vector(r.rampCnt(F_G*8-1 downto 0)+I*slvToInt(rampStep_i));
         end loop;
      else
         -- Decrement sample base         
         v.rampCnt := r.rampCnt - slvToInt(rampStep_i)*SAM_IN_WORD_C;
         
         -- Decrement samples within the word
         for I in (SAM_IN_WORD_C-1) downto 0 loop
            s_sample_data((F_G*8*I)+(F_G*8-1) downto F_G*8*I)     <= std_logic_vector(r.rampCnt(F_G*8-1 downto 0)-I*slvToInt(rampStep_i));
         end loop;
      end if;                

      if (enable_i = '0') then
         v := REG_INIT_C;
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
   
   -- Output assignment 
   sampleData_o <= byteSwapSlv(s_sample_data, GT_WORD_SIZE_C);
   
---------------------------------------   
end architecture rtl;
