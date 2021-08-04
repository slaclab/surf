-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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
use ieee.math_real.all;
use ieee.math_complex.all;
use ieee.fixed_pkg.all;

library std;
use std.textio.all;

library surf;
use surf.StdRtlPkg.all;
use surf.ComplexFixedPkg.all;

entity SinCosLutTb is
end entity SinCosLutTb;

architecture test of SinCosLutTb is

   constant PHASE_WIDTH_C : integer := 18;

   constant CLK_PERIOD_C : time    := 10 ns;
   constant ERROR_TOL_C  : real    := 0.0001;
   constant RUN_CNT_C    : integer := 100 + 2**PHASE_WIDTH_C;

   signal clk : std_logic := '0';
   signal rst : std_logic := '1';
   signal run : boolean := true;
   signal cnt : integer := 0;

   signal phaseIn   : unsigned(PHASE_WIDTH_C - 1 downto 0) := (others => '0');
   signal validIn   : sl := '0';

   signal dout      : cfixed(re(0 downto -17), im(0 downto -17));
   signal validOut  : sl := '0';

   signal doutRe    : real := 0.0;
   signal doutIm    : real := 0.0;

begin

   -- convert out DUT output back to reals
   doutRe <= to_real(dout.re);
   doutIm <= to_real(dout.im);

   p_clk : process is
   begin
      if run then
         clk <= not clk;
         wait for CLK_PERIOD_C/2;
      else
         wait;
      end if;
   end process p_clk;

   p_cnt : process ( clk ) is
      file outf      : text open WRITE_MODE is "sincos_out.dat";
      constant comma : string := ", ";
      variable lin   : line;
   begin
      if rising_edge(clk) then
         case cnt is
            when 10 =>
               rst     <= '0';
               phaseIn <= (others => '0');
               validIn <= '1';
            when 11 to RUN_CNT_C-1 =>
               --phaseIn <= phaseIn + 1;
               --phaseIn <= phaseIn + 58921;
               phaseIn <= phaseIn + 2**16 + 2**10;
               write(lin, to_real(dout.re));
               write(lin, comma);
               write(lin, to_real(dout.im));
               writeline(outf, lin);
            when RUN_CNT_C =>
               run <= false;
               report CR & LF & CR & LF &
                  "Test PASSED!" & CR & LF
                  & CR & LF;
            when others =>
         end case;

         cnt <= cnt + 1;
      end if;
   end process p_cnt;

   U_DUT : entity surf.SinCosTaylor
      generic map (
         PHASE_WIDTH_G => PHASE_WIDTH_C)
      port map (
         clk       => clk,
         rst       => rst,
         validIn   => validIn,
         phaseIn   => phaseIn,
         validOut  => validOut,
         sinCosOut => dout);


end architecture test;
