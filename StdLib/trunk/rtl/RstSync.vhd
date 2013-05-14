-------------------------------------------------------------------------------
-- Title      : Reset Synchronizer
-- Project    : 
-------------------------------------------------------------------------------
-- File       : RstSync.vhd
-- Standard   : VHDL'93/02, Math Packages
-------------------------------------------------------------------------------
-- Description: Synchronizes the trailing edge of an asynchronous reset to a
--              given clock.
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use work.StdRtlPkg.all;

entity RstSync is
   generic (
      TPD_G           : time     := 1 ns;  -- Simulation FF output delay
      IN_POLARITY_G   : sl       := '1';   -- 0 for active low rst, 1 for high
      OUT_POLARITY_G  : sl       := '1';
      RELEASE_DELAY_G : positive := 2);    -- Delay between deassertion of async and sync resets
   port (
      clk      : in  sl;
      asyncRst : in  sl;
      syncRst  : out sl);
begin
   assert (RELEASE_DELAY_G >= 2) report "RELEASE_DELAY_G must be >= 2" severity failure;
end RstSync;

architecture rtl of RstSync is

begin

   -- Reuse synchronizer that turns off shift reg extraction and register balancing for you
   Synchronizer_1 : entity work.Synchronizer
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => IN_POLARITY_G,
         STAGES_G       => RELEASE_DELAY_G,
         INIT_G         => slvAll(RELEASE_DELAY_G, OUT_POLARITY_G))
      port map (
         clk     => clk,
         aRst     => asyncRst,
         dataIn  => not OUT_POLARITY_G,
         dataOut => syncRst);

--   process (clk, asyncRst)
--   begin
--      if (asyncRst = IN_POLARITY_G) then
--         syncReg <= (others => OUT_POLARITY_G) after DELAY_G;
--         syncRst <= OUT_POLARITY_G             after DELAY_G;
--      elsif (rising_edge(clk)) then
--         syncRst <= syncReg(0) after DELAY_G;

--         if (HOLD_CYCLES_G > 1) then
--            for i in 0 to HOLD_CYCLES_G-2 loop
--               syncReg(i) <= syncReg(i+1) after DELAY_G;
--            end loop;
--         end if;

--         syncReg(HOLD_CYCLES_G-1) <= not OUT_POLARITY_G after DELAY_G;
--      end if;
--   end process;

end rtl;

