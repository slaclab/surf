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
      BYPASS_SYNC_G  : boolean  := false;  -- Bypass RstSync module for synchronous data configuration
      IN_POLARITY_G  : sl       := '1';    -- 0 for active LOW, 1 for active HIGH
      OUT_POLARITY_G : sl       := '1';    -- 0 for active LOW, 1 for active HIGH
      OUT_DELAY_G    : positive := 3;   -- Stages in output sync chain
      PULSE_WIDTH_G  : positive := 1);  -- one-shot pulse width duration (units of clk cycles)
   port (
      clk     : in  sl;                 -- Clock to be SYNC'd to
      dataIn  : in  sl;                 -- Trigger to be sync'd
      dataOut : out sl);                -- synced one-shot pulse
end SynchronizerOneShot;

architecture rtl of SynchronizerOneShot is

   constant NOT_OUT_POLARITY_C : sl := not OUT_POLARITY_G;

   signal pulseRst : sl;
   signal edgeDet  : sl;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";      

begin

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
         STAGES_G       => OUT_DELAY_G,
         BYPASS_SYNC_G  => BYPASS_SYNC_G)
      port map (
         clk        => clk,
         dataIn     => pulseRst,
         risingEdge => edgeDet);

   U_OnlyCyclePulse : if (PULSE_WIDTH_G = 1) generate
      dataOut <= edgeDet;
   end generate;


   U_PulseStretcher : if (PULSE_WIDTH_G > 1) generate
      -- Strech the pulse using a simple synchronously reset register chain
      -- Using PULSE_WIDTH_G > 1 will incur 1 extra cycle of OUT_DELAY_G

      U_Synchronizer_1 : entity surf.Synchronizer
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => OUT_POLARITY_G
            OUT_POLARITY_G => OUT_POLARITY_G,
            RST_ASYNC_G    => false,
            STAGES_G       => PULSE_WIDTH_G,
            BYPASS_SYNC_G  => false,
            INIT_G         => OUT_POLARITY_G)
         port map (
            clk     => clk,                 -- [in]
            rst     => edgeDet,             -- [in]
            dataIn  => NOT_OUT_POLARITY_C,  -- [in]
            dataOut => dataOut);            -- [out]

   end generate;

end architecture rtl;
