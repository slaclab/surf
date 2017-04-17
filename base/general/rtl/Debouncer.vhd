-------------------------------------------------------------------------------
-- File       : Debouncer.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-04-30
-- Last update: 2013-08-02
-------------------------------------------------------------------------------
-- Description: Debouncer for pushbutton switches
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
use ieee.numeric_std.all;
use work.StdRtlPkg.all;

entity Debouncer is
   
   generic (
      TPD_G             : time     := 1 ns;
      RST_POLARITY_G    : sl       := '1';    -- '1' for active high rst, '0' for active low
      RST_ASYNC_G       : boolean  := false;
      INPUT_POLARITY_G  : sl       := '0';
      OUTPUT_POLARITY_G : sl       := '1';
      FILTER_SIZE_G     : positive := 16;
      FILTER_INIT_G     : slv      := X"0000";
      SYNCHRONIZE_G     : boolean  := true);  -- Run input through 2 FFs before filtering

   port (
      clk : in  sl;
      rst : in  sl := not RST_POLARITY_G;
      i   : in  sl;
      o   : out sl);
end entity Debouncer;

architecture rtl of Debouncer is

   type RegType is record
      filter : slv(FILTER_SIZE_G-1 downto 0);
      o      : sl;
   end record RegType;

   constant REG_RESET_C : RegType :=
      (filter => FILTER_INIT_G,
       o      => not OUTPUT_POLARITY_G);

   signal r       : RegType := REG_RESET_C;
   signal rin     : RegType;
   signal iSynced : sl      := INPUT_POLARITY_G;

begin

   assert (FILTER_INIT_G'length = FILTER_SIZE_G) report "FILTER_INIT_G length must = FILTER_SIZE_G" severity failure;

   SynchronizerGen : if (SYNCHRONIZE_G) generate
      Synchronizer_1 : entity work.Synchronizer
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            RST_ASYNC_G    => RST_ASYNC_G,
            STAGES_G       => 2,
            INIT_G         => "00")
         port map (
            clk     => clk,
            rst     => rst,
            dataIn  => i,
            dataOut => iSynced);
   end generate SynchronizerGen;

   comb : process (r, i, iSynced, rst) is
      variable v : RegType;
   begin
      v := r;

      if (SYNCHRONIZE_G) then
         v.filter := r.filter(FILTER_SIZE_G-2 downto 0) & iSynced;
      else
         v.filter := r.filter(FILTER_SIZE_G-2 downto 0) & i;
      end if;

      if (allBits(r.filter, INPUT_POLARITY_G)) then
         v.o := OUTPUT_POLARITY_G;
      elsif (noBits(r.filter, INPUT_POLARITY_G)) then
         v.o := not OUTPUT_POLARITY_G;
      -- else v.o retains current value
      end if;

      -- Synchronous Reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_RESET_C;
      end if;

      rin <= v;
      o   <= r.o;
      
   end process comb;

   seq : process (clk, rst) is
   begin
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         r <= REG_RESET_C after TPD_G;
      elsif (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
