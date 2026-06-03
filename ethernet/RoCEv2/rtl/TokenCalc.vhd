-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Token calculator. Tokens = Rc * 2^16 / f_clk. To ease the
-- division we approximate 2^16 / f_clk = K / 2^N so that tokens = Rc * K /
-- 2^N. So if N=32 we would have K = round(2^{32+16} / f_clk) = round(2^48 /
-- f_clk) so then we can do tokens = (Rc * K) >> 32
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity tokenCalc is
   generic (
      TPD_G       : time    := 1 ns;
      CLK_FREQ_G  : real    := 156.25E+6;
      FRAC_BITS_G : natural := 16
   );
   port (
      clk          : in  sl;
      rst          : in  sl;
      Rc           : in  slv(31 downto 0);
      byte_per_clk : out slv(15 + FRAC_BITS_G downto 0)
      );
end entity tokenCalc;

architecture rtl of tokenCalc is

   function calc_k(n_bits : positive; f_hz : natural; frac_bits : natural) return slv is
      variable kInt : integer;
   begin
      kInt := integer(exp(real(n_bits + frac_bits) * log(2.0)) / real(f_hz));
      return conv_std_logic_vector(kInt, 32);
   end function;

   constant N_C                : natural          := 48 - FRAC_BITS_G;
   constant CLK_PERIOD_C       : real             := 1.0/CLK_FREQ_G;  -- seconds
   constant CLK_FREQ_INTEGER_C : natural          := getTimeRatio(1.0, CLK_PERIOD_C);
   constant K_C                : slv(31 downto 0) := calc_k(N_C, CLK_FREQ_INTEGER_C, FRAC_BITS_G);

   signal prob : slv(63 downto 0);

begin  -- architecture rtl

   seq : process (clk) is
   begin  -- process seq
      if rising_edge(clk) then          -- rising clock edge
         prob         <= Rc * K_C;
         byte_per_clk <= prob(63 downto N_C);
      end if;
   end process seq;

end architecture rtl;
