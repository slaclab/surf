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

entity IirSimpleTb is
end entity IirSimpleTb;

architecture test of IirSimpleTb is

   constant TPD_C        : time    := 1 ns;
   constant CLK_PERIOD_C : time    := 10 ns;
   constant ERROR_TOL_C  : real    := 0.0001;
   constant RUN_CNT_C    : integer := 10000;

   constant IIR_SHIFT_C : integer := 4;
   constant ILEAVE_C    : integer := 7;
   constant FILT_A_C    : real    := 2**(-real( IIR_SHIFT_C));

   signal clk : std_logic := '0';
   signal rst : std_logic := '1';

   type StateType is (
      INIT_S,
      RUNNING_S,
      FAILED_S,
      PASSED_S);

   type RegType is record
       cnt      : integer;
       passed   : sl;
       failed   : sl;
       halt     : sl;
       dinR     : real;
       doutR    : real;
       din      : sfixed(0 downto -15);
       dout     : sfixed(0 downto -15);
       validIn  : sl;
       validOut : sl;
       userIn   : slv(3 downto 0);
       userOut  : slv(3 downto 0);
       expected : real;
       err      : real;
       maxError : real;
       state    : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      cnt       => 0,
      passed    => '0',
      failed    => '0',
      halt      => '0',
      dinR      => 0.0,
      doutR     => 0.0,
      din       => (others => '0'),
      dout      => (others => '0'),
      validIn   => '0',
      validOut  => '0',
      userIn    => (others => '0'),
      userOut   => (others => '0'),
      expected  => 0.0,
      err       => 0.0,
      maxError  => 0.0,
      state     => INIT_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dout     : sfixed(r.dout'range);
   signal validOut : sl;
   signal userOut  : slv(r.userOut'range);

   signal passed : sl := '0';
   signal failed : sl := '0';

begin

   passed <= r.passed;
   failed <= r.failed;

   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 1 ns,
         RST_HOLD_TIME_G   => 1 us)
      port map (
         halt => r.halt,
         clkP => clk,
         clkN => open,
         rst  => rst,
         rstL => open);

   U_DUT : entity surf.IirSimple
      generic map (
         TPD_G         => TPD_C,
         USE_CSA3_G    => true,
         IIR_SHIFT_G   => IIR_SHIFT_C,
         ILEAVE_CHAN_G => ILEAVE_C,
         USER_WIDTH_G  => r.userIn'length)
      port map (
         clk       => clk,
         rst       => rst,
         validIn   => r.validIn,
         userIn    => r.userIn,
         din       => r.din,
         validOut  => validOut,
         userOut   => userOut,
         dout      => dout);

   comb : process (dout, validOut, userOut, rst, r) is
      variable v : RegType;
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

      v := r;

      case r.state is
         when INIT_S =>
            v.state := RUNNING_S;

         when RUNNING_S =>
            v.dout     := dout;
            v.validOut := validOut;
            v.userOut  := userOut;

            v.cnt      := r.cnt + 1;
            if (r.cnt mod ILEAVE_C) = 0 then
               rn          := rand_n(-0.5, 0.5);
               v.userIn    := (others => '1');
               v.validIn   := '1';
               -- compute expected value
               v.expected := (FILT_A_C * rn) + (real(1) - FILT_A_C) * r.expected;
            else
               rn        := 0.0;
               v.userIn  := (others => '0');
               v.validIn := '0';
            end if;

            v.dinR   := rn;
            v.din    := to_sfixed(rn, v.din);

            if r.validOut = '1' then
                v.doutR    := to_real(r.dout);
                v.err      := abs(v.doutR - r.expected);
                v.maxError := maximum(r.maxError, v.err);
            end if;

            if r.maxError > ERROR_TOL_C then
               v.state := FAILED_S;
            elsif r.cnt = RUN_CNT_C then
               v.state := PASSED_S;
            end if;

         when FAILED_S =>
            v.halt   := '1';
            v.failed := '1';

         when PASSED_S =>
            v.halt   := '1';
            v.passed := '1';

         when others =>
            v := REG_INIT_C;

      end case;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_C;
      end if;
   end process seq;

   process(failed, passed)
   begin
      if passed = '1' then
         report CR & LF & CR & LF &
            "Simulation Passed!" & CR & LF &
             "Max error is " & real'image(r.maxError) &
             CR & LF & CR & LF;
      elsif failed = '1' then
         assert false
            report CR & LF & CR & LF &
               "Simulation Failed!" & CR & LF &
                "Max error is " & real'image(r.maxError) &
                CR & LF & CR & LF severity failure;
      end if;
   end process;


end architecture test;
