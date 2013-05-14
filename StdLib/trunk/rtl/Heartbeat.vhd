-------------------------------------------------------------------------------
-- Title      : Heartbeat
-------------------------------------------------------------------------------
-- File       : Heartbeat.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-04-30
-- Last update: 2013-04-30
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Heartbeat LED output
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.StdRtlPkg.all;
use work.SynchronizePkg.all;

entity Heartbeat is
   
   generic (
      TPD_G        : time     := 1 ns;
      COUNT_SIZE_G : positive := 27);

   port (
      clk : in  sl;
      o   : out sl);

end entity Heartbeat;

architecture rtl of Heartbeat is

   type RegType is record
      counter : unsigned(COUNT_SIZE_G-1 downto 0);
   end record RegType;

   constant REG_RESET_C : RegType := (counter => (others => '0'));

   signal r, rin : RegType := REG_RESET_C;

begin

   comb : process (r) is
      variable v : RegType;
   begin
      v := r;

      v.counter := r.counter + 1;

      rin <= v;
      o   <= r.counter(COUNT_SIZE_G-1);
      
   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
