-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simple IIR filter using bit shifts
--              y(n) = alpha*x(n) + (1 - alpha)*y(n-1)
--                 where alpha = 2**(-IIR_SHIFT_G)
--              optionally supports time multiplexed channels with the
--                 ILEAVE_CHAN_G generic
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
use ieee.fixed_pkg.all;
use ieee.fixed_float_types.all;

library surf;
use surf.StdRtlPkg.all;

entity IirSimple is
   generic (
      TPD_G         : time    := 1 ns;
      XIL_DEVICE_G  : string  := "ULTRASCALE_PLUS";
      USE_CSA3_G    : boolean := false;
      BRAM_THRESH_G : integer := 256;
      IIR_SHIFT_G   : integer := 4;  -- alpha = 2**(-IIR_SHIFT_G)
      ILEAVE_CHAN_G : integer := 1;  -- Number of interleaved channels
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
end entity IirSimple;

architecture rtl of IirSimple is

   constant IIR_DELAY_C       : integer := ILEAVE_CHAN_G - 1;
   constant IIR_DELAY_STYLE_C : string  := ite(IIR_DELAY_C > BRAM_THRESH_G, "block", "srl_reg");

   -- Latency for user/valid
   constant TOT_LATENCY_C  : integer := 1 + ite(REG_IN_G, 1, 0) + ite(REG_OUT_G, 1, 0);
   constant INT_OVERFLOW_STYLE_C : fixed_overflow_style_type := fixed_wrap;
   constant INT_ROUNDING_STYLE_C : fixed_round_style_type    := fixed_truncate;

   type RegType is record
       din     : sfixed(din'range);
       dout    : sfixed(dout'range);
   end record RegType;

   constant REG_INIT_C : RegType := (
      din     => (others => '0'),
      dout    => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dinInt  : sfixed(din'range);
   signal doutInt : sfixed(dout'range);

   signal filtOut : sfixed(dout'high downto dout'low - IIR_SHIFT_G);
   signal filtDly : sfixed(dout'high downto dout'low - IIR_SHIFT_G);

   -- add 1 bit so we can delay valid and user together
   signal userDelayIn  : slv(userIn'length downto 0);
   signal userDelayOut : slv(userIn'length downto 0);

   signal shiftInA : sfixed(din'high - IIR_SHIFT_G downto din'low - IIR_SHIFT_G);
   signal shiftInB : sfixed(filtOut'high - IIR_SHIFT_G downto filtOut'low - IIR_SHIFT_G);

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

   U_ACCUM_DELAY : entity surf.sfixedDelay
      generic map (
         TPD_G         => TPD_G,
         XIL_DEVICE_G  => XIL_DEVICE_G,
         DELAY_G       => IIR_DELAY_C,
         DELAY_STYLE_G => IIR_DELAY_STYLE_C)
      port map (
         clk  => clk,
         din  => filtOut,
         dout => filtDly);

   -- Don't use shift_right, instead just reassign (reinterpert with new decimal)
   shiftInA <= dinInt;
   shiftInB <= filtDly;

   U_ADD_SUB : entity surf.add3
      generic map (
         XIL_DEVICE_G => XIL_DEVICE_G,
         USE_CSA3_G   => USE_CSA3_G,
         REG_OUT_G    => true,
         NEGATIVE_A_G => false,
         NEGATIVE_B_G => true)
      port map (
         clk  => clk,
         rst  => rst,
         a    => shiftInA,
         b    => shiftInB,
         c    => filtDly,
         y    => filtOut);

   comb : process(din, filtOut, r) is
      variable v   : RegType;
   begin

      v := r;

      v.din  := din;

      v.dout := resize(filtOut, v.dout, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);

      rin <= v;

      if REG_IN_G then
         dinInt <= r.din;
      else
         dinInt <= v.din;
      end if;

      if REG_OUT_G then
         dout <= r.dout;
      else
         dout <= v.dout;
      end if;

   end process comb;

   seq : process(clk) is
   begin
      if rising_edge(clk) then
         if rst = '1' then
            r <= REG_INIT_C after TPD_G;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process seq;

end architecture rtl;
