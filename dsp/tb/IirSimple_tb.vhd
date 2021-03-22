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

entity IirSimple_tb is
end entity IirSimple_tb;

architecture test of IirSimple_tb is

   constant CLK_PERIOD_C : time    := 10 ns;
   constant ERROR_TOL_C  : real    := 0.0001;
   constant RUN_CNT_C    : integer := 10000;

   constant IIR_SHIFT_C : integer := 4;
   constant ILEAVE_C    : integer := 28;

   signal clk : std_logic := '0';
   signal rst : std_logic := '1';
   signal run : boolean   := true;
   signal cnt : integer   := 0;

   constant FILT_A_C  : real := 2**(-real( IIR_SHIFT_C));
   signal expected    : real := 0.0;

   signal dinR  : real := 0.0;
   signal doutR : real := 0.0;
   signal din   : sfixed(0 downto -23) := (others => '0');
   signal dout  : sfixed(0 downto -23) := (others => '0');

   signal validIn  : sl := '0';
   signal validOut : sl := '0';

   signal userIn   : slv(3 downto 0) := (others => '0');
   signal userOut  : slv(3 downto 0) := (others => '0');

   signal yError   : real := 0.0;
   signal maxError : real := 0.0;

begin

   doutR <= to_real(dout);

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

      variable rn : real;

      impure function rand_n(min_val, max_val : real) return real is
         variable re : real := 0.0;
         variable im : real := 0.0;
         variable r  : real := 0.0;
      begin
         uniform(s1, s2, r);
         r := r * (max_val - min_val) + min_val;
         return r;
      end function rand_n;
   begin
      if rising_edge(clk) then
         case cnt is
            when 10 =>
               rst   <= '0';
            when 11 to RUN_CNT_C-1 =>
               if (cnt mod ILEAVE_C) = 0 then
                  rn       := rand_n(-0.5, 0.5);
                  userIn   <= (others => '1');
                  expected <= (FILT_A_C * rn) + (real(1) - FILT_A_C) * expected;
                  validIn  <= '1';
               else
                  rn      := 0.0;
                  userIn  <= (others => '0');
                  validIn <= '0';
               end if;
               dinR   <= rn;
               din    <= to_sfixed(rn, din);
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
               if validOut = '1' then
                  yError   <= abs(expected - doutR);
                  maxError <= maximum(yError, maxError);
               end if;
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

   U_DUT : entity work.iirSimple
      generic map (
         IIR_SHIFT_G   => IIR_SHIFT_C,
         ILEAVE_CHAN_G => ILEAVE_C,
         USER_WIDTH_G  => userIn'length)
      port map (
         clk       => clk,
         rst       => rst,
         validIn   => validIn,
         userIn    => userIn,
         din       => din,
         validOut  => validOut,
         userOut   => userOut,
         dout      => dout);


end architecture test;
