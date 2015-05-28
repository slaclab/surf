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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

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
      
      -- Increase counter
      rampStep_i   : in slv(RAMP_STEP_WIDTH_C-1 downto 0);
      
      -- Outs    
      sampleData_o : out slv(GT_WORD_SIZE_C*8-1 downto 0)  
   );
end entity TestStreamTx;

architecture rtl of TestStreamTx is
   
   constant SAM_IN_WORD_C    : positive := (GT_WORD_SIZE_C/F_G);

   type RegType is record
      stepCnt      : slv(RAMP_STEP_WIDTH_C-1 downto 0);
      rampCnt      : slv(F_G*8-1 downto 0);
      strobe       : sl;
      inc          : sl;      
   end record RegType;

   constant REG_INIT_C : RegType := (
      stepCnt     => (others => '0'),
      rampCnt     => (others => '0'),
      strobe      => '0',
      inc         => '1'
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   -- 
   signal s_sample_data : slv (sampleData_o'range);
   --
begin

   comb : process (r, rst,enable_i,rampStep_i) is
      variable v : RegType;
   begin
      v := r;
      
      -- Strobe period ticker (one clock cycle every step period, constant '1' if rampStep_i=0)
      -------------------------------------------------------------
      if (r.stepCnt = rampStep_i) then
         v.stepCnt  := (others => '0');
         v.strobe := '1';
      else 
         v.stepCnt := r.stepCnt + 1;
         v.strobe := '0';         
      end if;
      
      -- Ramp generator      
      ------------------------------------------------------------- 
      
      -- Increment/decrement ramp control
      if (r.rampCnt = (F_G*8-1 downto 0 => '0')) then
         v.inc := '1';
      elsif (r.rampCnt = (F_G*8-1 downto 0 => '1')) then
         v.inc := '0';     
      end if;     
      
      -- Ramp up or down counter
      if (r.strobe = '1') then
         if (v.inc = '1') then
            v.rampCnt := r.rampCnt + 1;
         else
            v.rampCnt := r.rampCnt - 1;
         end if;                   
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
   SAMPLE_DATA_GEN : for I in SAM_IN_WORD_C-1 downto 0 generate 
      s_sample_data((F_G*8*I)+(F_G*8-1) downto F_G*8*I)     <= r.rampCnt;
   end generate SAMPLE_DATA_GEN;  

   sampleData_o <= byteSwapSlv(s_sample_data, GT_WORD_SIZE_C);
   
---------------------------------------   
end architecture rtl;
