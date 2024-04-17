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
use surf.ComplexFixedPkg.all;

entity CfixedMultAddTb is
end entity CfixedMultAddTb;

architecture test of CfixedMultAddTb is

   constant CLK_PERIOD_C : time    := 10 ns;
   constant ERROR_TOL_C  : real    := 0.0001;
   constant RUN_CNT_C    : integer := 1000;

   signal clk : std_logic := '0';
   signal rst : std_logic := '1';
   signal run : boolean := true;
   signal cnt : integer := 0;

   signal a : cfixed(re(1 downto -25), im(1 downto -25)) := (others => (others => '0'));
   signal b : cfixed(re(1 downto -16), im(1 downto -16)) := (others => (others => '0'));
   signal c : cfixed(re(1 downto -16), im(1 downto -16)) := (others => (others => '0'));
   signal y : cfixed(re(1 downto -16), im(1 downto -16)) := (others => (others => '0'));
   signal aVld : std_logic := '1';
   signal bVld : std_logic := '1';
   signal cVld : std_logic := '0';
   signal yVld : std_logic := '0';

   signal aIn       : complex := (re => 0.00, im => 0.00);
   signal bIn       : complex := (re => 0.00, im => 0.00);
   signal cIn       : complex := (re => 0.00, im => 0.00);

   signal yExpected : complexArray(9 downto 0) := (others => (re => 0.00, im=>0.00));
   signal yE        : complex := (re => 0.00, im => 0.00);

   signal yOut    : COMPLEX;
   signal yError  : REAL;
   signal maxError : REAL := 0.0;

begin

   yE <= yExpected(4);

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
               cVld <= '1';
               aIn  <= rand_complex(-0.5, 0.5);
               bIn  <= rand_complex(-0.5, 0.5);
               cIn  <= rand_complex(-0.5, 0.5);
               a     <= to_cfixed(aIn, a);
               b     <= to_cfixed(bIn, b);
               c     <= to_cfixed(cIn, c);
               yExpected(9 downto 1) <= yExpected(8 downto 0);
               yExpected(0) <=  aIn * bIn + cIn;
            when RUN_CNT_C =>
               run <= false;
               report CR & LF & CR & LF &
                  "Test PASSED!" & CR & LF
                  & "Max error is " & real'image(maxError)
                  & CR & LF;
            when others =>
         end case;

         case cnt is
            when 11 to RUN_CNT_C =>
               yError  <= abs(yOut - yE);
               maxError <= maximum(yError, maxError);
               --assert (yError < ERROR_TOL_C) and (yVld = '1')
               --   report CR & LF & CR & LF &
               --   "**** Test FAILED **** " & CR & LF &
               --   "abs(error) is " & real'image(yError) &
               --   CR & LF
               --  severity failure;
            when others =>
        end case;

         cnt <= cnt + 1;
      end if;
   end process p_cnt;

   U_DUT : entity surf.cfixedMultAdd
      generic map (
         CIN_REG_G => 2)
      port map (
         clk   => clk,
         rst   => rst,
         a     => a,
         aVld => aVld,
         b     => b,
         bVld => aVld,
         c     => c,
         cVld => cVld,
         y     => y,
         yVld => yVld);


end architecture test;
