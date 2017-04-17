-------------------------------------------------------------------------------
-- File       : SynchronizerEdge.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-05-13
-- Last update: 2016-09-22
-------------------------------------------------------------------------------
-- Description: A simple multi Flip FLop synchronization module.
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

entity SynchronizerEdge is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';    -- '1' for active HIGH reset, '0' for active LOW reset
      OUT_POLARITY_G : sl       := '1';    -- 0 for active LOW, 1 for active HIGH
      RST_ASYNC_G    : boolean  := false;  -- Reset is asynchronous
      BYPASS_SYNC_G  : boolean  := false;  -- Bypass Synchronizer module for synchronous data configuration      
      STAGES_G       : positive := 3;
      INIT_G         : slv      := "0");
   port (
      clk         : in  sl;                        -- clock to be SYNC'd to
      rst         : in  sl := not RST_POLARITY_G;  -- Optional reset
      dataIn      : in  sl;                        -- Data to be 'synced'
      dataOut     : out sl;                        -- synced data
      risingEdge  : out sl;                        -- Rising edge detected
      fallingEdge : out sl);                       -- Falling edge detected
end SynchronizerEdge;

architecture rtl of SynchronizerEdge is

   constant INIT_C : slv(STAGES_G-1 downto 0) := ite(INIT_G = "0", slvZero(STAGES_G), INIT_G);

   type RegType is record
      syncDataDly : sl;
      dataOut     : sl;
      risingEdge  : sl;
      fallingEdge : sl;
   end record RegType;
   constant REG_INIT_C : RegType := (
      '0',
      (not OUT_POLARITY_G),
      (not OUT_POLARITY_G),
      (not OUT_POLARITY_G));
   signal r        : RegType := REG_INIT_C;
   signal rin      : RegType;
   signal syncData : sl;
   
begin

   assert (STAGES_G >= 3) report "STAGES_G must be >= 3" severity failure;

   Synchronizer_Inst : entity work.Synchronizer
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         OUT_POLARITY_G => '1',
         RST_ASYNC_G    => RST_ASYNC_G,
         STAGES_G       => (STAGES_G-1),
         BYPASS_SYNC_G  => BYPASS_SYNC_G,
         INIT_G         => INIT_C(STAGES_G-2 downto 0))      
      port map (
         clk     => clk,
         rst     => rst,
         dataIn  => dataIn,
         dataOut => syncData); 

   comb : process (r, rst, syncData) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobe signals
      v.risingEdge  := not OUT_POLARITY_G;
      v.fallingEdge := not OUT_POLARITY_G;

      -- Keep a record of the last syncData
      v.syncDataDly := syncData;

      -- Set the polarity of the output
      if (OUT_POLARITY_G = '1') then
         v.dataOut := syncData;
      else
         v.dataOut := not(syncData);
      end if;

      -- Check for a rising edge of the syncData
      if (syncData = '1') and (r.syncDataDly = '0') then
         v.risingEdge := OUT_POLARITY_G;
      end if;

      -- Check for a rising edge of the syncData
      if (syncData = '0') and (r.syncDataDly = '1') then
         v.fallingEdge := OUT_POLARITY_G;
      end if;

      -- Sync Reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v             := REG_INIT_C;
         v.syncDataDly := syncData;     -- prevent accidental edge detection
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      dataOut     <= r.dataOut;
      risingEdge  <= r.risingEdge;
      fallingEdge <= r.fallingEdge;
      
   end process comb;

   seq : process (clk, rst, syncData) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
      -- Async Reset
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         r             <= REG_INIT_C after TPD_G;
         r.syncDataDly <= syncData   after TPD_G;  -- prevent accidental edge detection
      end if;
   end process seq;
   
end architecture rtl;
