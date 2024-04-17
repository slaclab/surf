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
use ieee.math_real.all;
use ieee.math_complex.all;
use std.textio.all;
use ieee.fixed_pkg.all;

library surf;
use surf.StdRtlPkg.all;
use surf.ComplexFixedPkg.all;

entity CfixedPreAddMultTb is
end entity CfixedPreAddMultTb;

architecture test of CfixedPreAddMultTb is

   constant CLK_PERIOD_C  : time    := 10 ns;
   constant ERROR_TOL_C   : real    := 0.0001;
   constant ADD_NOT_SUB_C : boolean := false;
   constant RUN_CNT_C     : integer := 1000;

   signal clk : std_logic := '0';
   signal rst : std_logic := '1';
   signal run : boolean := true;
   signal cnt : integer := 0;

   signal a : cfixed(re(1 downto -25), im(1 downto -25)) := (others => (others => '0'));
   signal b : cfixed(re(1 downto -16), im(1 downto -16)) := (others => (others => '0'));
   signal d : cfixed(re(1 downto -25), im(1 downto -25)) := (others => (others => '0'));
   signal y : cfixed(re(1 downto -16), im(1 downto -16)) := (others => (others => '0'));
   signal aVld : std_logic := '1';
   signal bVld : std_logic := '1';
   signal dVld : std_logic := '0';
   signal yVld : std_logic := '1';

   signal aIn       : complex := (re => 0.00, im => 0.00);
   signal bIn       : complex := (re => 0.00, im => 0.00);
   signal dIn       : complex := (re => 0.00, im => 0.00);

   signal yExpected : complexArray(9 downto 0) := (others => (re => 0.00, im=>0.00));
   signal yE        : complex := (re => 0.00, im => 0.00);

   signal yOut      : complex := (re => 0.00, im => 0.00);
   signal yError    : real    := 0.000;
   signal maxError  : real    := 0.000;

   signal addNotSub : sl := ite(ADD_NOT_SUB_C, '1', '0');

begin


   yE <= yExpected(5);

   -- convert out DUT output back to reals
   yOut.re <= to_real(y.re);
   yOut.im <= to_real(y.im);

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
      variable s1 : integer := 981;
      variable s2 : integer := 12541;
      variable s3 : integer := 2745;
      variable s4 : integer := 442;

      impure function rand_complex(min_val, max_val : real) return complex is
         variable re : real := 0.0;
         variable im : real := 0.0;
         variable c  : complex := (re => 0.0, im => 0.0);
      begin
         uniform(s1, s2, re);
         uniform(s3, s4, im);
         c.re := re * (max_val - min_val) + min_val;
         c.im := im * (max_val - min_val) + min_val;
         return c;
      end function rand_complex;

   begin
      if rising_edge(clk) then
         case cnt is
            when 10 =>
               rst   <= '0';
            when 11 to RUN_CNT_C-1 =>
               aVld <= '1';
               bVld <= '1';
               dVld <= '1';
               aIn  <= rand_complex(-0.5, 0.5);
               bIn  <= rand_complex(-0.5, 0.5);
               dIn  <= rand_complex(-0.5, 0.5);
               a     <= to_cfixed(aIn, a);
               b     <= to_cfixed(bIn, b);
               d     <= to_cfixed(dIn, d);
               yExpected(9 downto 1) <= yExpected(8 downto 0);
               if ADD_NOT_SUB_C then
                  yExpected(0) <= ( aIn + dIn ) * bIn;
               else
                  yExpected(0) <= ( aIn - dIn ) * bIn;
               end if;
            when RUN_CNT_C =>
               run <= false;
               report CR & LF & CR & LF &
                  "Test PASSED!" & CR & LF &
                  "Max error is " & real'image(maxError)
                  & CR & LF;
            when others =>
         end case;

         case cnt is
            when 11 to RUN_CNT_C =>
               yError  <= abs(yOut - yE);
               maxError <= maximum(yError, maxError);
               assert (yError < ERROR_TOL_C)
                  report CR & LF & CR & LF &
                  "**** Test FAILED **** " & CR & LF &
                  "abs(error) is " & real'image(yError) &
                  CR & LF
                 severity failure;
            when others =>
        end case;

         cnt <= cnt + 1;
      end if;
   end process p_cnt;

   U_DUT : entity surf.CfixedPreAddMult
      generic map (
         REG_IN_G  => true,
         REG_OUT_G => false)
      port map (
         clk   => clk,
         add   => addNotSub, -- Add not sub
         a     => a,
         aVld  => aVld,
         b     => b,
         bVld  => bVld,
         d     => d,
         dVld  => dVld,
         y     => y,
         yVld  => yVld);

end architecture test;
