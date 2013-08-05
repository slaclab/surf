-------------------------------------------------------------------------------
-- Title      : Heartbeat
-------------------------------------------------------------------------------
-- File       : Heartbeat.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-04-30
-- Last update: 2013-08-02
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

entity Heartbeat is
   
   generic (
      TPD_G        : time                   := 1 ns;
      USE_DSP48_G  : string                 := "auto";
      COUNT_SIZE_G : positive range 1 to 48 := 27);

   port (
      clk : in  sl;
      o   : out sl);
begin
   -- USE_DSP48_G check
   assert ((USE_DSP48_G = "yes") or (USE_DSP48_G = "no") or (USE_DSP48_G = "auto") or (USE_DSP48_G = "automax"))
      report "USE_DSP48_G must be either yes, no, auto, or automax"
      severity failure;
end entity Heartbeat;

architecture rtl of Heartbeat is

   type RegType is record
      counter : unsigned(COUNT_SIZE_G-1 downto 0);
   end record RegType;

   constant REG_RESET_C : RegType := (counter => (others => '0'));

   signal r   : RegType := REG_RESET_C;
   signal rin : RegType;

   -- Attribute for XST
   attribute use_dsp48        : string;
   attribute use_dsp48 of rin : signal is USE_DSP48_G;
   
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
