library ieee;
use ieee.std_logic_1164.all;
use ieee.math_complex.all;
use std.textio.all;
use ieee.fixed_pkg.all;

library surf;
use surf.ComplexFixedPkg.all;

entity cmultAdd_tb is
end entity cmultAdd_tb;

architecture test of cmultAdd_tb is

   constant CLK_PERIOD_C : time := 10 ns;

   constant ERROR_TOL_C : real := 0.0001;

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

   signal a_in  : complexArray(0 to 9) := (
      others => (re => 0.251, im => 0.23));

   signal b_in  : complexArray(0 to 9) := (
      0      => (re =>  1.00, im =>  0.00),
      1      => (re => -1.00, im =>  0.00),
      2      => (re =>  0.00, im =>  1.00),
      3      => (re =>  0.00, im => -1.00),
      others => (re =>  0.10, im =>  0.00));

   signal c_in : complexArray(0 to 9) := (
      5      => (re => -0.20, im => 0.15),
      others => (re =>  0.00, im => 0.00));

   signal y_expected : complexArray(0 to 9);

   signal y_out   : COMPLEX;
   signal y_error : REAL;

begin


   -- generate exected outputs using ieee.math_complex
   GEN_Y_OUT : for i in y_expected'range generate 
       y_expected(i) <= a_in(i) * b_in(i) + c_in(i);
   end generate GEN_Y_OUT;

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
   begin
      if rising_edge(clk) then
         case cnt is
            when 10 =>
               rst   <= '0';
            when 11 to 20 =>
               a_vld <= '1';
               b_vld <= '1';
               c_vld <= '1';
               a     <= to_cfixed(a_in(cnt-11), a);
               b     <= to_cfixed(b_in(cnt-11), b);
               c     <= to_cfixed(c_in(cnt-11), c);
            when 100 => 
               run <= false;
               report CR & LF & CR & LF &
                  "Test PASSED!" & CR & LF;
            when others =>
         end case;

         case cnt is
            when 16 to 25 =>
               y_error  <= abs(y_out - y_expected(cnt-16));
               assert (y_error < ERROR_TOL_C) and (y_vld = '1') 
                  report CR & LF & CR & LF &
                  "**** Test FAILED **** " & CR & LF & 
                  "abs(error) is " & real'image(y_error) &
                  CR & LF
                 severity failure;
            when others =>
        end case;

         cnt <= cnt + 1;
      end if;
   end process p_cnt;

   U_DUT : entity work.cmultAdd
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
