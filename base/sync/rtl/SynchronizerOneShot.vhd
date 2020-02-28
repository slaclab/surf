-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: One-Shot Pulser that has to cross clock domains
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


library surf;
use surf.StdRtlPkg.all;

entity SynchronizerOneShot is
   generic (
      TPD_G          : time     := 1 ns;   -- Simulation FF output delay
      RST_ASYNC_G    : boolean  := false;
      RST_POLARITY_G : sl       := '1';    -- '1' for active HIGH reset, '0' for active LOW reset
      BYPASS_SYNC_G  : boolean  := false;  -- Bypass RstSync module for synchronous data configuration
      IN_POLARITY_G  : sl       := '1';    -- 0 for active LOW, 1 for active HIGH
      OUT_POLARITY_G : sl       := '1';    -- 0 for active LOW, 1 for active HIGH
      OUT_DELAY_G    : positive := 3;   -- Stages in output sync chain
      PULSE_WIDTH_G  : positive := 1);  -- one-shot pulse width duration (units of clk cycles)
   port (
      clk     : in  sl;                 -- Clock to be SYNC'd to
      rst     : in  sl := not RST_POLARITY_G;  --Optional reset
      dataIn  : in  sl;                 -- Trigger to be sync'd
      dataOut : out sl);                -- synced one-shot pulse
end SynchronizerOneShot;

architecture rtl of SynchronizerOneShot is

   type RegType is record
      dataOut : sl;
      counter : integer range 0 to PULSE_WIDTH_G;
   end record RegType;

   constant REG_INIT_C : RegType := (
      dataOut => '0',
      counter => 0);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal pulseRst : sl;
   signal edgeDet  : sl;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";      

begin

   assert (OUT_DELAY_G >= 3) report "SynchronizerOneShot: OUT_DELAY_G must be >= 3" severity failure;

   GEN_SYNC : if (BYPASS_SYNC_G = true) generate
      pulseRst <= dataIn when(IN_POLARITY_G = '1') else not(dataIn);
   end generate;

   GEN_ASYNC : if (BYPASS_SYNC_G = false) generate
      RstSync_Inst : entity surf.RstSync
         generic map (
            TPD_G          => TPD_G,
            IN_POLARITY_G  => IN_POLARITY_G,
            OUT_POLARITY_G => '1')
         port map (
            clk      => clk,
            asyncRst => dataIn,
            syncRst  => pulseRst);
   end generate;

   Sync_Pulse : entity surf.SynchronizerEdge
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         OUT_POLARITY_G => OUT_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         STAGES_G       => OUT_DELAY_G,
         BYPASS_SYNC_G  => BYPASS_SYNC_G)
      port map (
         clk        => clk,
         rst        => rst,
         dataIn     => pulseRst,
         risingEdge => edgeDet);

   U_OnlyCyclePulse : if (PULSE_WIDTH_G = 1) generate
      dataOut <= edgeDet;
   end generate;


   U_PulseStretcher : if (PULSE_WIDTH_G > 1) generate
      -- Strech the pulse using a simple synchronously reset register chain
      -- Using PULSE_WIDTH_G > 1 will incur 1 extra cycle of OUT_DELAY_G

      comb : process (edgeDet, r, rst) is
         variable v : RegType;
      begin
         v := r;

         -- Assert output and start counting when edge seen
         if (edgeDet = OUT_POLARITY_G) then
            v.dataOut := OUT_POLARITY_G;
            v.counter := r.counter + 1;
         end if;

         -- Keep counting
         if (r.dataOut = OUT_POLARITY_G) then
            v.counter := r.counter + 1;
         end if;

         -- Stop counting when PULSE_WIDTH_G counter to
         if (r.counter = PULSE_WIDTH_G) then
            v.dataOut := not OUT_POLARITY_G;
            v.counter := 0;
         end if;

         if (RST_ASYNC_G and rst = RST_POLARITY_G) then
            v := REG_INIT_C;
         end if;

         rin <= v;

         dataOut <= r.dataOut;

      end process comb;

      seq : process (clk, rst) is
      begin
         if (rising_edge(clk)) then
            r <= rin after TPD_G;
         end if;

         if (RST_ASYNC_G and rst = RST_POLARITY_G) then
            r <= REG_INIT_C after TPD_G;
         end if;
      end process seq;

   end generate;

end architecture rtl;
