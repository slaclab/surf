-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SynchronizerOneShot.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-02-06
-- Last update: 2014-07-02
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
      RELEASE_DELAY_G : positive := 3;      -- Delay between deassertion of async and sync resets
      IN_POLARITY_G   : sl       := '1';    -- 0 for active LOW, 1 for active HIGH
      OUT_POLARITY_G  : sl       := '1');   -- 0 for active LOW, 1 for active HIGH
   port (
      clk     : in  sl;                        -- Clock to be SYNC'd to
      rst     : in  sl := not RST_POLARITY_G;  -- Optional reset
      dataIn  : in  sl;                        -- Trigger to be sync'd
      dataOut : out sl);                       -- synced one-shot pulse
end SynchronizerOneShot;

architecture rtl of SynchronizerOneShot is
   
   type RegType is record
      syncRstDly : sl;
      dataOut    : sl;
   end record RegType;
   constant REG_INIT_C : RegType := (
      '1',
      (not OUT_POLARITY_G));
   signal r       : RegType := REG_INIT_C;
   signal rin     : RegType;
   signal syncRst : sl;
   
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
         syncRst  => syncRst); 

   comb : process (r, rst, syncRst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobe signals
      v.dataOut := not OUT_POLARITY_G;

      -- Keep a record of the last syncRst
      v.syncRstDly := syncRst;

      -- Check for a rising edge of the syncRst
      if (syncRst = '1') and (r.syncRstDly = '0') then
         v.dataOut := OUT_POLARITY_G;
      end if;

      -- Sync Reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      dataOut <= r.dataOut;
      
   end process comb;

   seq : process (clk, rst) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
      -- Async Reset
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      end if;
   end process seq;

end architecture rtl;
