-------------------------------------------------------------------------------
-- Title      : Sample rate pulser
-------------------------------------------------------------------------------
-- File       : RatePulser.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-15
-- Last update: 2015-04-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Periodically outputs one clock cycle pulse (pulse_o).
--              Synchronises with the rising edge of trig_i.
--              Outputs first pulse 2 c-c after trig_i='1'
--              Rate division determined by value of rateDiv_i:
--                - 0 - Pulser outputs always '1'
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

entity RatePulser is
   generic (
      TPD_G        : time   := 1 ns);
   port (
      clk      : in  sl;
      rst      : in  sl;
      
      -- Synchronisation inputs
      rateDiv_i : in  slv(15 downto 0);
      trig_i   : in  sl;
      trigRe_o : out sl;
      
      -- Outs
      pulse_o     : out sl
   );
end entity RatePulser;

architecture rtl of RatePulser is
   
   type RegType is record
      trigD1 : sl;
      cnt      : slv(15 downto 0);
      pulse     : sl;
      trigRe : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      trigD1  => '0',
      cnt       => (others => '0'),
      pulse      => '0',
      trigRe  => '0'
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
begin

   comb : process (r, rst,trig_i, rateDiv_i) is
      variable v : RegType;
   begin
      v := r;
      
      -- Delay trig for one clock cycle 
      v.trigD1 := trig_i;
      
      -- Detect rising edge on trig
      v.trigRe := trig_i and not r.trigD1;

      -- rateDiv counter 

      -- pulse is aligned to trig on rising edge of trig_i. 
      -- The alignment is only done when nSync_i=‘0‘    
      if (r.trigRe = '1' ) then
         v.cnt  := (others => '0');
         v.pulse := '1';
      elsif (r.cnt = rateDiv_i) then
         v.cnt  := (others => '0');
         v.pulse := '1';
      else 
         v.cnt := r.cnt + 1;
         v.pulse := '0';         
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
   pulse_o    <= r.pulse;
   trigRe_o   <= r.trigRe;
---------------------------------------   
end architecture rtl;
