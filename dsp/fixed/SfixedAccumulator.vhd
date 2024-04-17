-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: sfixed accumulator, supports interleaved channels
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
use ieee.fixed_pkg.all;
use ieee.fixed_float_types.all;

library surf;
use surf.StdRtlPkg.all;

entity SfixedAccumulator is
   generic (
      TPD_G         : time    := 1 ns;
      XIL_DEVICE_G  : string  := "ULTRASCALE_PLUS";
      ILEAVE_CHAN_G : integer := 1;
      USER_WIDTH_G  : integer := 0;
      REG_IN_G      : boolean := true;
      REG_OUT_G     : boolean := true);
   port (
      clk       : in  sl;
      rst       : in  sl := '0';
      -- inputs
      validIn   : in  sl := '0';
      userIn    : in  slv(USER_WIDTH_G - 1 downto 0) := (others => '0');
      din       : in  sfixed;
      -- outputs
      validOut  : out sl;
      userOut   : out slv(USER_WIDTH_G - 1 downto 0);
      dout      : out sfixed);
end entity SfixedAccumulator;

architecture rtl of SfixedAccumulator is

   constant TOT_LATENCY_C  : integer := 1 + ite(REG_IN_G, 1, 0) + ite(REG_OUT_G, 1, 0);
   constant INT_OVERFLOW_STYLE_C : fixed_overflow_style_type := fixed_wrap;
   constant INT_ROUNDING_STYLE_C : fixed_round_style_type    := fixed_truncate;

   type RegType is record
       rst     : sl;
       dinR    : sfixed(din'range);
       doutR   : sfixed(dout'range);
       sum    : sfixed(dout'range);
   end record RegType;

   constant REG_INIT_C : RegType := (
      rst     => '0',
      dinR    => (others => '0'),
      doutR   => (others => '0'),
      sum     => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal sumDly : sfixed(dout'range);

   -- add 1 bit so we can delay valid and user together
   signal userDelayIn  : slv(userIn'length downto 0);
   signal userDelayOut : slv(userIn'length downto 0);

begin

   userDelayIn(userDelayIn'high) <= validIn;
   userDelayIn(userDelayIn'high - 1 downto userDelayIn'low) <= userIn;

   validOut <= userDelayOut(userDelayOut'high);
   userOut  <= userDelayOut(userDelayOut'high - 1 downto 0);

   U_USER_DELAY : entity surf.SlvFixedDelay
      generic map (
         TPD_G        => TPD_G,
         XIL_DEVICE_G => XIL_DEVICE_G,
         DELAY_G      => TOT_LATENCY_C,
         WIDTH_G      => userDelayIn'length)
      port map (
         clk  => clk,
         din  => userDelayIn,
         dout => userDelayOut);

   GEN_1_CHAN : if ILEAVE_CHAN_G = 1 generate
      sumDly <= r.sum;
   end generate GEN_1_CHAN;

   GEN_N_CHAN : if ILEAVE_CHAN_G > 1 generate
      signal slvDelayIn  : slv(din'length - 1 downto 0);
      signal slvDelayOut : slv(din'length - 1 downto 0);
   begin

      slvDelayIn <= to_slv(r.sum);
      sumDly     <= to_sfixed(slvDelayOut, sumDly);

      U_DELAY : entity surf.SlvFixedDelay
         generic map (
            TPD_G        => TPD_G,
            XIL_DEVICE_G => XIL_DEVICE_G,
            DELAY_G      => ILEAVE_CHAN_G-1,
            WIDTH_G      => din'length)
         port map (
            clk  => clk,
            din  => slvDelayIn,
            dout => slvDelayOut);

   end generate GEN_N_CHAN;

   comb : process(din, sumDly, rst, r) is
      variable v   : RegType;
   begin

      v := r;

      v.rst   := rst;
      v.dinR  := din;

      v.doutR := r.sum;

      if REG_IN_G then
         if r.rst = '1' then
            v.sum := (others => '0');
         else
            v.sum := resize(r.dinR + sumDly, r.sum, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
         end if;
      else
         if v.rst = '1' then
            v.sum := (others => '0');
         else
            v.sum := resize(v.dinR + sumDly, r.sum, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
         end if;
      end if;

      rin <= v;

      if REG_OUT_G then
         dout <= r.doutR;
      else
         dout <= v.doutR;
      end if;

   end process comb;

   seq : process(clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
