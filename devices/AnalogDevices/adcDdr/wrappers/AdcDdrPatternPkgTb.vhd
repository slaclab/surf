-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation wrapper for surf.AdcDdrPatternPkg
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

library surf;
use surf.StdRtlPkg.all;
use surf.AdcDdrPatternPkg.all;

entity AdcDdrPatternPkgTb is
   generic (
      WORD_WIDTH_G : positive := 14);
   port (
      pn9State  : in  slv(8 downto 0);
      pn23State : in  slv(22 downto 0);
      pn9Next   : out slv(8 downto 0);
      pn23Next  : out slv(22 downto 0);
      pn9Word   : out slv(WORD_WIDTH_G-1 downto 0);
      pn23Word  : out slv(WORD_WIDTH_G-1 downto 0));
end entity AdcDdrPatternPkgTb;

architecture rtl of AdcDdrPatternPkgTb is

begin

   pn9Next  <= adcDdrPn9Advance(pn9State, WORD_WIDTH_G);
   pn23Next <= adcDdrPn23Advance(pn23State, WORD_WIDTH_G);
   pn9Word  <= adcDdrPn9Word(pn9State, WORD_WIDTH_G);
   pn23Word <= adcDdrPn23Word(pn23State, WORD_WIDTH_G);

end architecture rtl;
