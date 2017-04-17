-------------------------------------------------------------------------------
-- File       : SynchronizerOneShotTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-09-22
-- Last update: 2016-09-22
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for the SynchronizerOneShot module
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

----------------------------------------------------------------------------------------------------

entity SynchronizerOneShotTb is

end entity SynchronizerOneShotTb;

----------------------------------------------------------------------------------------------------

architecture sim of SynchronizerOneShotTb is

   -- component generics
   constant TPD_G           : time     := 1 ns;
   constant RST_POLARITY_G  : sl       := '1';
   constant RST_ASYNC_G     : boolean  := false;
   constant BYPASS_SYNC_G   : boolean  := false;
   constant RELEASE_DELAY_G : positive := 3;
   constant IN_POLARITY_G   : sl       := '1';
   constant OUT_POLARITY_G  : sl       := '1';

   -- component ports
   signal clk     : sl;                        -- [in]
   signal rst     : sl := not RST_POLARITY_G;  -- [in]
   signal dataIn  : sl;                        -- [in]
   signal dataOut : sl;                        -- [out]

begin

   -- component instantiation
   U_SynchronizerOneShot: entity work.SynchronizerOneShot
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         BYPASS_SYNC_G   => BYPASS_SYNC_G,
         RELEASE_DELAY_G => RELEASE_DELAY_G,
         IN_POLARITY_G   => IN_POLARITY_G,
         OUT_POLARITY_G  => OUT_POLARITY_G)
      port map (
         clk     => clk,                -- [in]
         rst     => rst,                -- [in]
         dataIn  => dataIn,             -- [in]
         dataOut => dataOut);           -- [out]

   
   U_ClkRst_1 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 5 ns,
         CLK_DELAY_G       => 1 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 5 us,
         SYNC_RESET_G      => true)
      port map (
         clkP => clk,
         rst  => rst);
   
   U_ClkRst_2 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 5 ns,
         CLK_DELAY_G       => 3 ns,
         RST_START_DELAY_G => 10 us,
         RST_HOLD_TIME_G   => 5 ns,
         SYNC_RESET_G      => true)
      port map (
         rst  => dataIn);

end architecture sim;

----------------------------------------------------------------------------------------------------
