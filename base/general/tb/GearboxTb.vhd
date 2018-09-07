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
   constant INPUT_WIDTH_G  : natural := 66;
   constant OUTPUT_WIDTH_G : natural := 32;

   -- component ports
   signal clk      : sl;                                           -- [in]
   signal rst      : sl;                                           -- [in]
   signal dataIn   : slv(INPUT_WIDTH_G-1 downto 0) := "10" & X"AAAAAAAAAAAAAAA0";  -- [in]
   signal validIn  : sl                            := '0';         -- [in]
   signal readyIn  : sl;                                           -- [out]
   signal dataOut  : slv(OUTPUT_WIDTH_G-1 downto 0);               -- [out]
   signal validOut : sl;                                           -- [out]
   signal readyOut : sl;                                           -- [in]

begin

   -- component instantiation
   U_Gearbox : entity work.Gearbox
      generic map (
         TPD_G          => TPD_G,
         INPUT_WIDTH_G  => INPUT_WIDTH_G,
         OUTPUT_WIDTH_G => OUTPUT_WIDTH_G)
      port map (
         clk      => clk,               -- [in]
         rst      => rst,               -- [in]
         dataIn   => dataIn,            -- [in]
         validIn  => validIn,           -- [in]
         readyIn  => readyIn,           -- [out]
         dataOut  => dataOut,           -- [out]
         validOut => validOut,          -- [out]
         readyOut => '1');              -- [in]


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
   begin
      wait until rst = '1';
      wait until rst = '0';
      wait for 1 us;
      wait until clk = '1';
      wait until clk = '1';      
      validIn <= '1' after TPD_G;

      while (true) loop
         wait until clk = '1';

      end loop;

   end process;


end architecture sim;

----------------------------------------------------------------------------------------------------
