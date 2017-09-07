-------------------------------------------------------------------------------
-- File       : DspComparator.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-09-07
-- Last update: 2017-09-07
-------------------------------------------------------------------------------
-- Description: Generalized DSP inferred comparator
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
use ieee.numeric_std.all;

use work.StdRtlPkg.all;

entity DspComparator is
   generic (
      TPD_G   : time                   := 1 ns;
      WIDTH_G : positive range 2 to 48 := 32);
   port (
      clk  : in  sl;
      ain  : in  slv(WIDTH_G-1 downto 0);
      bin  : in  slv(WIDTH_G-1 downto 0);
      eq   : out sl;                    -- equal                    (a =  b)
      gt   : out sl;                    -- greater than             (a >  b)
      gtEq : out sl;                    -- greater than or equal to (a >= b)
      ls   : out sl;                    -- less than                (a <  b)
      lsEq : out sl);                   -- less than or equal to    (a <= b)
end DspComparator;

architecture rtl of DspComparator is

   signal a : signed(WIDTH_G - 1 downto 0);
   signal b : signed(WIDTH_G - 1 downto 0);
   signal c : signed(WIDTH_G - 1 downto 0);

   attribute use_dsp48      : string;
   attribute use_dsp48 of c : signal is "yes";

begin

   a <= signed(ain);
   b <= signed(bin);

   process(clk)
   begin
      if rising_edge(clk) then
         c <= a - b after TPD_G;
      end if;
   end process;

   eq   <= '1' when (c(WIDTH_G-1 downto 0) = 0)                         else '0';
   gt   <= '1' when (c(WIDTH_G-1) = '0' and c(WIDTH_G-2 downto 0) /= 0) else '0';
   gtEq <= '1' when (c(WIDTH_G-1) = '0')                                else '0';
   ls   <= '1' when (c(WIDTH_G-1) = '1')                                else '0';
   lsEq <= '1' when (c(WIDTH_G-1) = '1' or c(WIDTH_G-1 downto 0) = 0)   else '0';

end rtl;
