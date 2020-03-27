-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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

library surf;
use surf.StdRtlPkg.all;

entity Debouncer is
   
   generic (
      TPD_G             : time     := 1 ns;
      RST_POLARITY_G    : sl       := '1';         -- '1' for active high rst, '0' for active low
      RST_ASYNC_G       : boolean  := false;
      INPUT_POLARITY_G  : sl       := '0';
      OUTPUT_POLARITY_G : sl       := '1';
      CLK_FREQ_G        : real     := 156.250E+6;  -- units of Hz
      DEBOUNCE_PERIOD_G : real     := 1.0E-3;      -- units of seconds
      SYNCHRONIZE_G     : boolean  := true);       -- Run input through 2 FFs before filtering

   port (
      clk : in  sl;
      rst : in  sl := not RST_POLARITY_G;
      i   : in  sl;
      o   : out sl);
end entity Debouncer;

architecture rtl of Debouncer is
   
   constant CLK_PERIOD_C   : real            := 1.0/CLK_FREQ_G;
   constant CNT_MAX_C      : natural         := getTimeRatio(DEBOUNCE_PERIOD_G, CLK_PERIOD_C) - 1;
   constant POLARITY_EQ_C  : boolean         := ite(INPUT_POLARITY_G = OUTPUT_POLARITY_G, true, false);
   constant SYNC_INIT_C    : slv(1 downto 0) := (others => not INPUT_POLARITY_G);
   
   type RegType is record
      filter      : integer range 0 to CNT_MAX_C;
      iSyncedDly  : sl;
      o           : sl;
   end record RegType;

   constant REG_RESET_C : RegType :=
      (filter     => 0,
       iSyncedDly => not INPUT_POLARITY_G,
       o          => not OUTPUT_POLARITY_G);

   signal r       : RegType := REG_RESET_C;
   signal rin     : RegType;
   signal iSynced : sl      := INPUT_POLARITY_G;

begin

   SynchronizerGen : if (SYNCHRONIZE_G) generate
      Synchronizer_1 : entity surf.Synchronizer
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            RST_ASYNC_G    => RST_ASYNC_G,
            STAGES_G       => 2,
            INIT_G         => SYNC_INIT_C)
         port map (
            clk     => clk,
            rst     => rst,
            dataIn  => i,
            dataOut => iSynced);
   end generate SynchronizerGen;
   
   NoSynchronizerGen : if (not SYNCHRONIZE_G) generate
      iSynced <= i;
   end generate NoSynchronizerGen;

   comb : process (r, iSynced, rst) is
      variable v : RegType;
   begin
      v := r;
      
      v.iSyncedDly := iSynced;
      
      if (r.iSyncedDly /= iSynced) then  -- any edge
         v.filter := CNT_MAX_C;
      elsif (r.filter /= 0) then
         v.filter := r.filter - 1;
      end if;
      
      if POLARITY_EQ_C then
         if (r.filter = 0 and r.o /= r.iSyncedDly) then
            v.o := r.iSyncedDly;
         -- else v.o retains current value
         end if;
      else
         if (r.filter = 0 and r.o = r.iSyncedDly) then
            v.o := not r.iSyncedDly;
         -- else v.o retains current value
         end if;
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
