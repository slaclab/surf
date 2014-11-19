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
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use work.StdRtlPkg.all;

entity RstSync is
   generic (
      TPD_G           : time                             := 1 ns;   -- Simulation FF output delay
      IN_POLARITY_G   : sl                               := '1';    -- 0 for active low rst, 1 for high
      OUT_POLARITY_G  : sl                               := '1';
      BYPASS_SYNC_G   : boolean                          := false;  -- Bypass Synchronizer module for synchronous data configuration   
      RELEASE_DELAY_G : integer range 3 to positive'high := 3);     -- Delay between deassertion of async and sync resets
   port (
      clk      : in  sl;
      asyncRst : in  sl;
      syncRst  : out sl);
end RstSync;

architecture rtl of RstSync is

   signal syncInt : sl := OUT_POLARITY_G;

begin

--   assert (RELEASE_DELAY_G >= 3) report "RELEASE_DELAY_G must be >= 3" severity failure;

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

   -- Final stage does not have async constraints applied, can be duplicated to ease timing
   OUT_REG : process (clk, asyncRst) is
   begin
      if (asyncRst = IN_POLARITY_G) then
         syncRst <= OUT_POLARITY_G after TPD_G;
      elsif (rising_edge(clk)) then
         syncRst <= syncInt after TPD_G;
      end if;
   end process OUT_REG;

end rtl;

