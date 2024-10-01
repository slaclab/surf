-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Taylor series corrected SinCosLut, stores 1/4 cos in
--              INT_PHASE_WIDTH_G - 2 bits LUT and does 1st order Taylor series
--              correction on ouput (3 real multipliers)
--              dout.re <= cos
--              dout.im <= sin
--
--              9  cycle latency REG_IN_G = false
--              10 cycle latency REG_IN_G = true
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
use ieee.fixed_pkg.all;
use ieee.fixed_float_types.all;

library surf;
use surf.StdRtlPkg.all;
use surf.ComplexFixedPkg.all;

entity SinCosTaylor is
   generic (
      TPD_G              : time     := 1 ns;
      XIL_DEVICE_G       : string   := "ULTRASCALE_PLUS";
      FULL_RANGE_G       : boolean  := true;
      MEMORY_TYPE_G      : string   := "block";
      REG_IN_G           : boolean  := true;
      USER_WIDTH_G       : integer  := 0;
      PHASE_WIDTH_G      : integer  := 24;
      INT_PHASE_WIDTH_G  : integer  := 12); -- Phase width (will store 1/4 wave table INT_PHASE_WIDTH_G-2 bit width)
   port (
      clk          : in  sl;
      rst          : in  sl := '0';
      validIn      : in  sl := '0';
      userIn       : in  slv(USER_WIDTH_G - 1 downto 0) := (others => '0');
      phaseIn      : in  unsigned(PHASE_WIDTH_G - 1 downto 0);
      validOut     : out sl;
      userOut      : out slv(USER_WIDTH_G - 1 downto 0);
      sinCosOut    : out cfixed);
end entity SinCosTaylor;

architecture rtl of SinCosTaylor is

   constant LUT_LATENCY_C  : integer := 4 + ite(REG_IN_G, 1, 0);
   constant MULT_LATENCY_C : integer := 4;
   constant ADD_LATENCY_C  : integer := 1;
   constant TOT_LATENCY_C  : integer := LUT_LATENCY_C + MULT_LATENCY_C + ADD_LATENCY_C;

   constant TRUN_BITS_C : integer := PHASE_WIDTH_G - INT_PHASE_WIDTH_G;
   constant M_PI_C      : sfixed(2 downto -15) := to_sfixed(MATH_PI, 2, -15);

   -- Truncate upper bits of phaseIn for LUT
   signal phaseTrun       : unsigned(phaseIn'high downto phaseIn'high - INT_PHASE_WIDTH_G + 1) := (others => '0');
   -- Lower bits, zero pad (error is always positive)
   signal phaseRemainder  : sfixed(1 - INT_PHASE_WIDTH_G downto 1 - phaseIn'length) := (others => '0');
   -- 18 bit phaseRad, MATH_PI gain
   signal phaseRad        : sfixed(phaseRemainder'high + 2 downto phaseRemainder'high + 2 - 17) := (others => '0');

   -- phase truncated sinCos from LUT
   signal sinCosTrun      : cfixed(re(sinCosOut.re'range), im(sinCosOut.im'range));
   signal sinCosTrunDelay : cfixed(re(sinCosOut.re'range), im(sinCosOut.im'range));

   signal sinPiInt    : sfixed(sinCosOut.re'range);
   signal cosPiInt    : sfixed(sinCosOut.re'range);
   signal sinCosCorr  : cfixed(re(sinCosOut.re'range), im(sinCosOut.im'range));

   signal slvDelayIn  : slv(USER_WIDTH_G downto 0);
   signal slvDelayOut : slv(USER_WIDTH_G downto 0);

begin

   slvDelayIn(USER_WIDTH_G)              <= validIn;
   slvDelayIn(USER_WIDTH_G - 1 downto 0) <= userIn;

   validOut <= slvDelayOut(USER_WIDTH_G);
   userOut  <= slvDelayOut(USER_WIDTH_G - 1 downto 0);

   U_MATCH_TOT_DELAY : entity surf.SlvFixedDelay
      generic map (
         TPD_G        => TPD_G,
         XIL_DEVICE_G => XIL_DEVICE_G,
         DELAY_G      => TOT_LATENCY_C,
         WIDTH_G      => USER_WIDTH_G + 1)
      port map (
         clk  => clk,
         din  => slvDelayIn,
         dout => slvDelayOut);

   phaseTrun      <= phaseIn(phaseIn'high downto phaseIn'high - INT_PHASE_WIDTH_G + 1);

   phaseRemainder(0 - INT_PHASE_WIDTH_G downto 1 - phaseIn'length) <=
      to_sfixed(
         std_logic_vector(phaseIn(phaseIn'high - INT_PHASE_WIDTH_G downto 0)),
         0,
         -TRUN_BITS_C + 1);

   U_SIN_COS_LUT : entity surf.SinCosLut
      generic map (
         TPD_G         => TPD_G,
         XIL_DEVICE_G  => XIL_DEVICE_G,
         MEMORY_TYPE_G => MEMORY_TYPE_G,
         REG_IN_G      => REG_IN_G,
         USER_WIDTH_G  => slvDelayIn'length,
         PHASE_WIDTH_G => INT_PHASE_WIDTH_G)
      port map (
         clk       => clk,
         rst       => rst,
         userIn    => slvDelayIn,
         phaseIn   => phaseTrun,
         sinCosOut => sinCosTrun);

   U_MATCH_DELAY : entity surf.cfixedDelay
      generic map (
         TPD_G   => TPD_G,
         DELAY_G => MULT_LATENCY_C)
      port map (
         clk     => clk,
         din     => sinCosTrun,
         dout    => sinCosTrunDelay);

   U_MULT_PI : entity surf.sfixedMult
      generic map (
         TPD_G         => TPD_G,
         LATENCY_G     => LUT_LATENCY_C,
         RND_SIMPLE_G  => true)
      port map (
         clk   => clk,
         a     => phaseRemainder,
         b     => M_PI_C,
         y     => phaseRad);

   U_MULT_COS : entity surf.sfixedMult
      generic map (
         TPD_G         => TPD_G,
         LATENCY_G     => MULT_LATENCY_C,
         RND_SIMPLE_G  => true)
      port map (
         clk   => clk,
         a     => sinCosTrun.re,
         b     => phaseRad,
         y     => cosPiInt);

   U_MULT_SIN : entity surf.sfixedMult
      generic map (
         TPD_G         => TPD_G,
         LATENCY_G     => MULT_LATENCY_C,
         RND_SIMPLE_G  => true)
      port map (
         clk   => clk,
         a     => sinCosTrun.im,
         b     => phaseRad,
         y     => sinPiInt);

   -- reset handled by DOREG reset in SinCosLut module
   seq : process(clk) is
   begin
      if rising_edge(clk) then
         sinCosOut.re <= resize( sinCosTrunDelay.re - sinPiInt, sinCosOut.re) after TPD_G;
         sinCosOut.im <= resize( sinCosTrunDelay.im + cosPiInt, sinCosOut.im) after TPD_G;
      end if;
   end process seq;

end architecture rtl;
