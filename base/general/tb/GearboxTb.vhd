-------------------------------------------------------------------------------
-- Title      : Testbench for design "Gearbox"
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of SURF. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of SURF, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
----------------------------------------------------------------------------------------------------

entity GearboxTb is

end entity GearboxTb;

----------------------------------------------------------------------------------------------------

architecture sim of GearboxTb is

   -- component generics
   constant TPD_G          : time    := 1 ns;
   constant INPUT_WIDTH_G  : natural := 10;
   constant OUTPUT_WIDTH_G : natural := 8;

   -- component ports
   signal clk32 : sl := '0';            -- [in]
   signal rst32 : sl := '0';            -- [in]

   signal clk66 : sl := '0';
   signal rst66 : sl := '0';

   signal input : slv(INPUT_WIDTH_G-1 downto 0) := (others => '0');


   signal slaveData_0   : slv(INPUT_WIDTH_G-1 downto 0)  := (others => '0');  -- [in]
   signal slaveValid_0  : sl                             := '0';              -- [in]
   signal slaveReady_0  : sl                             := '0';              -- [out]
   signal masterData_0  : slv(OUTPUT_WIDTH_G-1 downto 0) := (others => '0');  -- [out]
   signal masterValid_0 : sl                             := '0';              -- [out]
   signal masterReady_0 : sl                             := '0';              -- [in]
   signal slip_0        : sl                             := '0';
   signal startOfSeq_0  : sl                             := '0';

--    signal slaveData_1     : slv(OUTPUT_WIDTH_G-1 downto 0) := X"A5";  -- [in]
--    signal slaveValid_1    : sl                            := '0';    -- [in]
--    signal slaveReady_1    : sl;                                      -- [out]
   signal masterData_1  : slv(INPUT_WIDTH_G-1 downto 0) := (others => '0');  -- [out]
   signal masterValid_1 : sl                            := '0';              -- [out]
   signal masterReady_1 : sl                            := '1';              -- [in]
   signal slip_1        : sl                            := '0';
   signal startOfSeq_1  : sl                            := '0';
                                                                             -- 

begin

   U_FifoAsync_1 : entity work.FifoAsync
      generic map (
         TPD_G         => TPD_G,
         FWFT_EN_G     => true,
         BRAM_EN_G     => true,
         DATA_WIDTH_G  => INPUT_WIDTH_G,
         PIPE_STAGES_G => 0)
      port map (
         rst    => rst66,               -- [in]
         wr_clk => clk66,               -- [in]
         wr_en  => '1',                 -- [in]
         din    => input,
         rd_clk => clk32,               -- [in]
         rd_en  => slaveReady_0,        -- [in]
         dout   => slaveData_0,         -- [out]
         valid  => slaveValid_0);       -- [out]


   U_Gearbox_0 : entity work.Gearbox
      generic map (
         TPD_G          => TPD_G,
         SLAVE_WIDTH_G  => INPUT_WIDTH_G,
         MASTER_WIDTH_G => OUTPUT_WIDTH_G)
      port map (
         clk         => clk32,           -- [in]
         rst         => rst32,           -- [in]
         slaveData   => slaveData_0,     -- [in]
         slaveValid  => slaveValid_0,    -- [in]
         slaveReady  => slaveReady_0,    -- [out]
         masterData  => masterData_0,    -- [out]
         masterValid => masterValid_0,   -- [out]
         masterReady => masterReady_0);  -- [in]

   -- component instantiation
   U_Gearbox_1 : entity work.Gearbox
      generic map (
         TPD_G          => TPD_G,
         SLAVE_WIDTH_G  => OUTPUT_WIDTH_G,
         MASTER_WIDTH_G => INPUT_WIDTH_G)
      port map (
         clk         => clk32,          -- [in]
         rst         => rst32,          -- [in]
         slaveData   => masterData_0,   -- [in]
         slaveValid  => masterValid_0,  -- [in]
         slaveReady  => masterReady_0,  -- [out]
         masterData  => masterData_1,   -- [out]
         masterValid => masterValid_1,  -- [out]
         masterReady => masterReady_1,  -- [in]
         slip        => slip_1,
         startOfSeq  => startOfSeq_1);



   U_ClkRst_1 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 30 ns,
         CLK_DELAY_G       => 1 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 5 us,
         SYNC_RESET_G      => true)
      port map (
         clkP => clk32,
         rst  => rst32);

   U_ClkRst_2 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 80 ns,
         CLK_DELAY_G       => 1 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 5 us,
         SYNC_RESET_G      => true)
      port map (
         clkP => clk66,
         rst  => rst66);

   tb : process is
      variable count : integer := 0;
   begin
      wait until rst66 = '1';
      wait until rst66 = '0';
      wait for 1 us;
      wait until clk66 = '1';
      wait until clk66 = '1';
--      slaveValid_0 <= '1' after TPD_G;

--       while (count < 498) loop
--          wait until clk = '1';
--          count := count + 1;
--       end loop;
--       count := 0;

--       wait until clk = '1';
--       startOfSeq <= '1';

--       wait until clk = '1';
--       startOfSeq <= '0';
--       for i in 0 to 10 loop
--          while (count < 100) loop
--             wait until clk = '1';
--             count := count + 1;
--          end loop;
--          count := 0;

--          wait until clk = '1';
--          slip_1 <= '1';

--          wait until clk = '1';
--          slip_1 <= '0';
--       end loop;


      while (count < 10000) loop
         wait until clk66 = '1';
         count := count + 1;
      end loop;
      count := 0;



   end process;


end architecture sim;

----------------------------------------------------------------------------------------------------
