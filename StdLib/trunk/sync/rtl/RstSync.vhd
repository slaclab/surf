-------------------------------------------------------------------------------
-- Title      : Reset Synchronizer
-- Project    : 
-------------------------------------------------------------------------------
-- File       : RstSync.vhd
-- Standard   : VHDL'93/02, Math Packages
-------------------------------------------------------------------------------
-- Description: Synchronizes the trailing edge of an asynchronous reset to a
--              given clock.
--
-- Dependencies:  ^/StdLib/trunk/rtl/Synchronizer.vhd
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use work.StdRtlPkg.all;

entity RstSync is
   generic (
      TPD_G           : time                             := 1 ns;  -- Simulation FF output delay
      IN_POLARITY_G   : sl                               := '1';  -- 0 for active low rst, 1 for high
      OUT_POLARITY_G  : sl                               := '1';
      BYPASS_SYNC_G   : boolean                          := false;  -- Bypass Synchronizer module for synchronous data configuration   
      RELEASE_DELAY_G : integer range 3 to positive'high := 3;  -- Delay between deassertion of async and sync resets
      OUT_REG_RST_G   : boolean                          := true;  -- Apply async reset to final reg stage
      PIPE_STAGES_G   : natural                          := 1);
   port (
      clk      : in  sl;
      asyncRst : in  sl;
      syncRst  : out sl);
end RstSync;

architecture rtl of RstSync is

   constant PIPE_STAGES_C : natural := ite((PIPE_STAGES_G = 0), 1, (PIPE_STAGES_G-1));

   signal syncInt  : sl                          := OUT_POLARITY_G;
   signal syncRsts : slv(PIPE_STAGES_C downto 0) := (others => OUT_POLARITY_G);

begin

   -- Reuse synchronizer that turns off shift reg extraction and register balancing for you
   Synchronizer_1 : entity work.Synchronizer
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => IN_POLARITY_G,
         RST_ASYNC_G    => true,
         STAGES_G       => RELEASE_DELAY_G-1,
         BYPASS_SYNC_G  => BYPASS_SYNC_G,
         INIT_G         => slvAll(RELEASE_DELAY_G-1, OUT_POLARITY_G))
      port map (
         clk     => clk,
         rst     => asyncRst,
         dataIn  => not OUT_POLARITY_G,
         dataOut => syncInt);

   ZERO_LATENCY : if (PIPE_STAGES_G = 0) generate
      syncRst <= syncInt;
   end generate;

   PIPE_REG : if (PIPE_STAGES_G > 0) generate

      -- Final stage ("syncInt") does not have ASYNC constraints applied
      -- Note: It can be duplicated to ease timing via PIPE_STAGES_G generic
      syncRst <= syncRsts(PIPE_STAGES_C);

      OUT_REG : process (asyncRst, clk) is
         variable i : natural;
      begin
         if (asyncRst = IN_POLARITY_G) and (OUT_REG_RST_G) then
            syncRsts <= (others => OUT_POLARITY_G) after TPD_G;
         elsif (rising_edge(clk)) then
            if (PIPE_STAGES_C = 0) then
               syncRsts(0) <= syncInt after TPD_G;
            else
               syncRsts <= (syncRsts(PIPE_STAGES_C downto 1) & syncInt) after TPD_G;
            end if;
         end if;
      end process OUT_REG;
      
   end generate;
   
end rtl;

