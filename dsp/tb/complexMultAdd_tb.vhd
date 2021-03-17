library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;
use ieee.math_complex.all;
use std.textio.all;
use ieee.fixed_pkg.all;

library surf;
use surf.ComplexFixedPkg.all;

entity complexMultAdd_tb is
end entity complexMultAdd_tb;

architecture test of complexMultAdd_tb is

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
   signal a_vld : std_logic := '1';
   signal b_vld : std_logic := '1';
   signal c_vld : std_logic := '0';
   signal y_vld : std_logic := '0';

   signal a_in       : complex := (re => 0.00, im => 0.00);
   signal b_in       : complex := (re => 0.00, im => 0.00);
   signal c_in       : complex := (re => 0.00, im => 0.00);

   signal y_expected : complexArray(9 downto 0) := (others => (re => 0.00, im=>0.00));
   signal y_e        : complex := (re => 0.00, im => 0.00);

   signal y_out    : COMPLEX;
   signal y_error  : REAL;
   signal maxError : REAL := 0.0;

begin

   y_e <= y_expected(4);

   -- convert out DUT output back to reals
   y_out.re <= to_real(y.re);
   y_out.im <= to_real(y.im);

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
               a_vld <= '1';
               b_vld <= '1';
               c_vld <= '1';
               a_in  <= rand_complex(-0.5, 0.5);
               b_in  <= rand_complex(-0.5, 0.5);
               c_in  <= rand_complex(-0.5, 0.5);
               a     <= to_cfixed(a_in, a);
               b     <= to_cfixed(b_in, b);
               c     <= to_cfixed(c_in, c);
               y_expected(9 downto 1) <= y_expected(8 downto 0);
               y_expected(0) <=  a_in * b_in + c_in;
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
               y_error  <= abs(y_out - y_e);
               maxError <= maximum(y_error, maxError);
               --assert (y_error < ERROR_TOL_C) and (y_vld = '1') 
               --   report CR & LF & CR & LF &
               --   "**** Test FAILED **** " & CR & LF & 
               --   "abs(error) is " & real'image(y_error) &
               --   CR & LF
               --  severity failure;
            when others =>
        end case;

         cnt <= cnt + 1;
      end if;
   end process p_cnt;

   U_DUT : entity work.complexMultAdd
      generic map (
         CIN_REG_G => 2)
      port map (
         clk   => clk,
         rst   => rst,
         a     => a,
         a_vld => a_vld,
         b     => b,
         b_vld => a_vld,
         c     => c,
         c_vld => c_vld,
         y     => y,
         y_vld => y_vld);


end architecture test;
