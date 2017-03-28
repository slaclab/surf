-------------------------------------------------------------------------------
-- File       : TestStreamTx.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-15
-- Last update: 2015-04-15
-------------------------------------------------------------------------------
-- Description: Test Data Stream Generator
--  Outputs a saw, ramp, or square wave test signal data stream for testing
--  Saw signal increment (type_i = 00): Ramp step is determined by rampStep_i.
--  Saw signal decrement (type_i = 01): Ramp step is determined by rampStep_i.             
--  Square wave(type_i = 10): Period is squarePeriod_i. Duty cycle is 50%.              
--                            Amplitude is determined by posAmplitude_i and negAmplitude_i.
--                            pulse_o is a binary equivalent of the analogue square wave.      
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
      
      -- Enable signal generation  
      -- when switching between signal types the module has to be 
      -- disabled and re-enabled in order to align signals
      enable_i     : in  sl;
      
      -- Signal type
      type_i           : in  slv(1 downto 0);
      
      -- Increase counter by the step
      rampStep_i       : in slv(PER_STEP_WIDTH_C-1 downto 0);
      squarePeriod_i   : in slv(PER_STEP_WIDTH_C-1 downto 0);
      
      -- Positive and negative amplitude square wave
      posAmplitude_i   : in slv(F_G*8-1 downto 0);   
      negAmplitude_i   : in slv(F_G*8-1 downto 0);
      
      -- Sample data containing test signal
      sampleData_o : out slv(GT_WORD_SIZE_C*8-1 downto 0);
      -- Digital out pulse for latency debug
      pulse_o : out sl
   );
end entity TestStreamTx;

architecture rtl of TestStreamTx is
   
   constant SAM_IN_WORD_C    : positive := (GT_WORD_SIZE_C/F_G);

   type RegType is record
      squareCnt    : slv(PER_STEP_WIDTH_C-1 downto 0);
      rampCnt      : signed(F_G*8-1 downto 0);
      testData     : slv (sampleData_o'range);
      inc          : sl;
      sign         : sl;      
   end record RegType;

   constant REG_INIT_C : RegType := (
      squareCnt   => (others => '0'),
      rampCnt     => (others => '0'),
      testData    => (others => '0'),
      inc         => '1',
      sign        => '0'
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   --
begin

   comb : process (r, rst,enable_i,rampStep_i,type_i,posAmplitude_i,squarePeriod_i,negAmplitude_i) is
       variable v : RegType;
   begin
      v := r;
     
      -- Ramp generator
      ------------------------------------------------------------- 
      if (type_i = "00" or type_i = "01") then
         
         -- Saw tooth increment
         if (type_i = "00") then
            v.inc := '1';
         end if;
       
       -- Saw tooth decrement
         if (type_i = "01") then
            v.inc := '0';
         end if;
         
         -- Ramp up or down counter
         if (v.inc = '1') then
           -- Increment sample base
            v.rampCnt := r.rampCnt +  slvToInt(rampStep_i)*SAM_IN_WORD_C;
            
            -- Increment samples within the word
            for I in (SAM_IN_WORD_C-1) downto 0 loop
               v.testData((F_G*8*I)+(F_G*8-1) downto F_G*8*I)     := std_logic_vector(r.rampCnt(F_G*8-1 downto 0)+((SAM_IN_WORD_C-1)-I)*slvToInt(rampStep_i));
            end loop;
         else
            -- Decrement sample base         
            v.rampCnt := r.rampCnt - slvToInt(rampStep_i)*SAM_IN_WORD_C;
            
            -- Decrement samples within the word
            for I in (SAM_IN_WORD_C-1) downto 0 loop
               v.testData((F_G*8*I)+(F_G*8-1) downto F_G*8*I)     := std_logic_vector(r.rampCnt(F_G*8-1 downto 0)-((SAM_IN_WORD_C-1)-I)*slvToInt(rampStep_i));
            end loop;
         end if;
         
         -- Initialize square parameters
         v.squareCnt := (others=>'0');
         v.sign  := '0';     
      elsif (type_i = "10") then
         v.squareCnt := r.squareCnt+1;
         if (r.squareCnt = squarePeriod_i) then
            v.squareCnt := (others=>'0');
            v.sign := not r.sign;
            if (r.sign = '0') then
               for I in (SAM_IN_WORD_C-1) downto 0 loop
                  v.testData((F_G*8*I)+(F_G*8-1) downto F_G*8*I)    := negAmplitude_i;
               end loop;
            elsif (r.sign = '1') then
               for I in (SAM_IN_WORD_C-1) downto 0 loop
                  v.testData((F_G*8*I)+(F_G*8-1) downto F_G*8*I)    := posAmplitude_i;
               end loop;
            end if;
         end if;
         
         -- Initialize ramp parameters
         v.rampCnt := (others=>'0');
         v.inc := '1';
      else
         v.testData := (others=>'0');
         
         -- Initialize square parameters
         v.squareCnt := (others=>'0');
         v.sign  := '0';
         
         -- Initialize ramp parameters
         v.rampCnt := (others=>'0');
         v.inc := '1';
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
   
   -- Digital square waveform out 
   pulse_o <= r.sign; 
   -- Output data assignment
   sampleData_o <= r.testData;
---------------------------------------   
end architecture rtl;
