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
   signal clk : sl;                     -- [in]
   signal rst : sl;                     -- [in]


   signal dataIn_0     : slv(INPUT_WIDTH_G-1 downto 0) := "1111100010";  -- [in]
   signal validIn_0    : sl                            := '0';          -- [in]
   signal readyIn_0    : sl;                                            -- [out]
   signal dataOut_0    : slv(OUTPUT_WIDTH_G-1 downto 0);                -- [out]
   signal validOut_0   : sl;                                            -- [out]
   signal readyOut_0   : sl                            := '1';          -- [in]
   signal slip_0       : sl                            := '0';
   signal startOfSeq_0 : sl                            := '0';

--    signal dataIn_1     : slv(OUTPUT_WIDTH_G-1 downto 0) := X"A5";  -- [in]
--    signal validIn_1    : sl                            := '0';    -- [in]
--    signal readyIn_1    : sl;                                      -- [out]
   signal dataOut_1    : slv(INPUT_WIDTH_G-1 downto 0);  -- [out]
   signal validOut_1   : sl;                             -- [out]
   signal readyOut_1   : sl := '1';                      -- [in]
   signal slip_1       : sl := '0';
   signal startOfSeq_1 : sl := '0';
                                                         -- 

begin

   U_Gearbox_0 : entity work.Gearbox
      generic map (
         TPD_G          => TPD_G,
         INPUT_WIDTH_G  => INPUT_WIDTH_G,
         OUTPUT_WIDTH_G => OUTPUT_WIDTH_G)
      port map (
         clk      => clk,               -- [in]
         rst      => rst,               -- [in]
         dataIn   => dataIn_0,          -- [in]
         validIn  => validIn_0,         -- [in]
         readyIn  => readyIn_0,         -- [out]
         dataOut  => dataOut_0,         -- [out]
         validOut => validOut_0,        -- [out]
         readyOut => readyOut_0);       -- [in]

   -- component instantiation
   U_Gearbox_1 : entity work.Gearbox
      generic map (
         TPD_G          => TPD_G,
         INPUT_WIDTH_G  => OUTPUT_WIDTH_G,
         OUTPUT_WIDTH_G => INPUT_WIDTH_G)
      port map (
         clk        => clk,             -- [in]
         rst        => rst,             -- [in]
         dataIn     => dataOut_0,       -- [in]
         validIn    => validOut_0,      -- [in]
         readyIn    => readyOut_0,      -- [out]
         dataOut    => dataOut_1,       -- [out]
         validOut   => validOut_1,      -- [out]
         readyOut   => readyOut_1,      -- [in]
         slip       => slip_1,
         startOfSeq => startOfSeq_1);



   U_ClkRst_1 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 10 ns,
         CLK_DELAY_G       => 1 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 5 us,
         SYNC_RESET_G      => true)
      port map (
         clkP => clk,
         rst  => rst);

   tb : process is
      variable count : integer := 0;
   begin
      wait until rst = '1';
      wait until rst = '0';
      wait for 1 us;
      wait until clk = '1';
      wait until clk = '1';
      validIn_0 <= '1' after TPD_G;

--       while (count < 498) loop
--          wait until clk = '1';
--          count := count + 1;
--       end loop;
--       count := 0;

--       wait until clk = '1';
--       startOfSeq <= '1';

--       wait until clk = '1';
--       startOfSeq <= '0';
      for i in 0 to 10 loop
         while (count < 100) loop
            wait until clk = '1';
            count := count + 1;
         end loop;
         count := 0;

         wait until clk = '1';
         slip_1 <= '1';

         wait until clk = '1';
         slip_1 <= '0';
      end loop;


      while (count < 10000) loop
         wait until clk = '1';
         count := count + 1;
      end loop;
      count := 0;



   end process;


end architecture sim;

----------------------------------------------------------------------------------------------------
