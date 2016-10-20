-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SynchronizerOneShot.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-02-06
-- Last update: 2016-09-22
-- Platform   : 
-- Standard   : VHDL'93/02
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

use work.StdRtlPkg.all;

entity SynchronizerOneShot is
   generic (
      TPD_G           : time     := 1 ns;   -- Simulation FF output delay
      RST_POLARITY_G  : sl       := '1';    -- '1' for active HIGH reset, '0' for active LOW reset
      RST_ASYNC_G     : boolean  := false;  -- Reset is asynchronous
      BYPASS_SYNC_G   : boolean  := false;  -- Bypass RstSync module for synchronous data configuration
      RELEASE_DELAY_G : positive := 3;  -- Delay between deassertion of async and sync resets
      IN_POLARITY_G   : sl       := '1';    -- 0 for active LOW, 1 for active HIGH
      OUT_POLARITY_G  : sl       := '1');   -- 0 for active LOW, 1 for active HIGH
   port (
      clk     : in  sl;                 -- Clock to be SYNC'd to
      rst     : in  sl := not RST_POLARITY_G;  -- Optional reset
      dataIn  : in  sl;                 -- Trigger to be sync'd
      dataOut : out sl);                -- synced one-shot pulse
end SynchronizerOneShot;

architecture rtl of SynchronizerOneShot is

   signal pulseRst : sl;

begin

   RstSync_Inst : entity work.RstSync
      generic map (
         TPD_G           => TPD_G,
         RELEASE_DELAY_G => RELEASE_DELAY_G,
         BYPASS_SYNC_G   => BYPASS_SYNC_G,
         IN_POLARITY_G   => IN_POLARITY_G,
         OUT_POLARITY_G  => '1')
      port map (
         clk      => clk,
         asyncRst => dataIn,
         syncRst  => pulseRst);

   Sync_Pulse : entity work.SynchronizerEdge
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         OUT_POLARITY_G => OUT_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         BYPASS_SYNC_G  => BYPASS_SYNC_G)
      port map (
         clk        => clk,
         dataIn     => pulseRst,
         risingEdge => dataOut);

end architecture rtl;
