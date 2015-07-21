-------------------------------------------------------------------------------
-- Title      : Sample rate decimation circuit
-------------------------------------------------------------------------------
-- File       : Decimator.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-15
-- Last update: 2015-04-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Periodically outputs one clock cycle rateClk (rateClk_o).
--              Synchronises with the rising edge of trig_i.
--              Outputs first rateClk 2 c-c after trig_i='1'
--              Rate division determined by value of rateDiv_i:
--                - 0 - rateClkr outputs always '1'
--                - 1 - Clock frequency/2
--                - 2 - Clock frequency/3
--                - etc.
--              Outputs rising edge of the trigger for external use.
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.jesd204bpkg.all;

entity Decimator is
   generic (
      TPD_G        : time   := 1 ns;
      -- Number of bytes in a frame
      F_G : positive := 2
   );
   port (
      clk      : in  sl;
      rst      : in  sl;
      
      -- Sample data I/O
      sampleData_i  : in  slv((GT_WORD_SIZE_C*8)-1 downto 0);
      decSampData_o : out  slv((GT_WORD_SIZE_C*8)-1 downto 0);      
      
      rateDiv_i : in  slv(15 downto 0);
      trig_i   : in  sl;
      trigRe_o : out sl;
      
      -- Divided rate clk
      rateClk_o     : out sl
   );
end entity Decimator;

architecture rtl of Decimator is
   
   type RegType is record
      trigD1 : sl;
      cnt    : slv(15 downto 0);
      divClk : sl;
      trigRe : sl;
      shft   : slv(1 downto 0);
      prevFrame: slv((F_G*8)-1 downto 0);       
   end record RegType;

   constant REG_INIT_C : RegType := (
      trigD1  => '0',
      cnt     => (others => '0'),
      divClk  => '0',
      trigRe  => '0',
      shft    => "01",
      prevFrame => (others => '0')   
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
begin

   comb : process (r, rst,trig_i, rateDiv_i, sampleData_i) is
      variable v : RegType;
   begin
      v := r;
      
      -- Delay trig for one clock cycle 
      v.trigD1 := trig_i;
      
      -- Detect rising edge on trig
      v.trigRe := trig_i and not r.trigD1;

      -- rateDiv clock generator 
      -- divClk is aligned to trig on rising edge of trig_i. 
      if (r.trigRe = '1' ) then
         v.cnt  := (others => '0');
         v.divClk := '1';
      elsif (rateDiv_i = (rateDiv_i'range => '0')) then  
         v.cnt  := (others => '0');
         v.divClk := '1';        
      elsif (r.cnt = rateDiv_i-1) then
         v.cnt  := (others => '0');
         v.divClk := '1';
      else 
         v.cnt := r.cnt + 1;
         v.divClk := '0';         
      end if;
      
      -- make a shifted control signal that indicates when to save and when to sample data
      if (r.trigRe = '1' ) then
         v.shft := "01";
      elsif (r.divClk = '1' ) then
         v.shft := r.shft(0) & r.shft(1);
      else 
         v.shft := r.shft;        
      end if;
      
      -- Save frame
      if (r.divClk = '1' and r.shft = "01") then
         v.prevFrame  := sampleData_i((F_G*8)-1 downto 0);
      else
         v.prevFrame  := r.prevFrame;
      end if;
      
      -- Reset
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
   rateClk_o  <= '1' when (r.divClk = '1' and r.shft = "10") or rateDiv_i = (rateDiv_i'range => '0') else '0';
   
   decSampData_o <= sampleData_i((F_G*8)-1 downto 0) & r.prevFrame  when (GT_WORD_SIZE_C = 4 and rateDiv_i /= (rateDiv_i'range => '0')) else
                    sampleData_i;
                    
   trigRe_o   <= r.trigRe;
---------------------------------------   
end architecture rtl;
