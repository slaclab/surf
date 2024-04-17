-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: SinCosLut, stores 1/4 cos in PHASE_WIDTH_G - 2 bits LUT
--              dout.re <= cos
--              dout.im <= sin
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

entity SinCosLut is
   generic (
      TPD_G          : time     := 1 ns;
      XIL_DEVICE_G   : string   := "ULTRASCALE_PLUS";
      FULL_RANGE_G   : boolean  := true;
      MEMORY_TYPE_G  : string   := "block";
      REG_IN_G       : boolean  := true;
      USER_WIDTH_G   : integer  := 0;
      PHASE_WIDTH_G  : integer  := 12); -- Phase width (will store 1/4 wave table PHASE_WIDTH_G-2 bit width)
   port (
      clk          : in  sl;
      rst          : in  sl := '0';
      validIn      : in  sl := '0';
      userIn       : in  slv(USER_WIDTH_G - 1 downto 0) := (others => '0');
      phaseIn      : in  unsigned(PHASE_WIDTH_G - 1 downto 0);
      validOut     : out sl;
      userOut      : out slv(USER_WIDTH_G - 1 downto 0);
      sinCosOut    : out cfixed);
end entity SinCosLut;

architecture rtl of SinCosLut is

   constant TOT_LATENCY_C : integer := 4 + ite(REG_IN_G, 1, 0);
   -- Only store 1/4 of a sine wave internally
   constant INT_PHASE_WIDTH_C : integer := PHASE_WIDTH_G - 2;
   constant QUARTER_DEPTH_C   : integer := 2**INT_PHASE_WIDTH_C;

   constant INT_OVERFLOW_STYLE_C : fixed_overflow_style_type := fixed_wrap;
   constant INT_ROUNDING_STYLE_C : fixed_round_style_type    := fixed_truncate;

   type QuarterWaveLutType is array(0 to QUARTER_DEPTH_C-1) of sfixed(sinCosOut.re'range);

   function initQuarterWaveLut(QUARTER_DEPTH : integer; STYP : sfixed) return QuarterWaveLutType is
      variable cs    : real := 0.0;
      variable ret   : QuarterWaveLutType := (others => (others => '0'));
      variable sfix  : sfixed(STYP'range) := (others => '1');
      variable scale : real := 1.0;
   begin

      if FULL_RANGE_G then
         sfix(sfix'high)     := '0';
         sfix(sfix'low + 1)  := '0';
         scale := to_real(sfix);
      else
         scale := 1.0;
      end if;

      for i in 0 to QUARTER_DEPTH-1 loop
         cs := scale * cos(2.0 * MATH_PI * real(2*i + 1) / real(8.0 * QUARTER_DEPTH));
         ret(i) := to_sfixed(cs, STYP);
      end loop;

      return ret;
   end function initQuarterWaveLut;

   type RegType is record
       rst          : slv(2 downto 0);
       phaseMsb     : unsigned(1 downto 0);
       phaseMsbR    : unsigned(1 downto 0);
       phaseMsbRR   : unsigned(1 downto 0);
       phaseMsbRRR  : unsigned(1 downto 0);
       phaseLsb     : unsigned(phaseIn'high - 2 downto 0);
       sinAddr      : unsigned(phaseIn'high - 2 downto 0);
       cosAddr      : unsigned(phaseIn'high - 2 downto 0);
       lutSin       : sfixed(sinCosOut.re'range);
       lutCos       : sfixed(sinCosOut.re'range);
       lutSinDoReg  : sfixed(sinCosOut.re'range);
       lutCosDoReg  : sfixed(sinCosOut.re'range);
       sinCosOut    : cfixed(re(sinCosOut.re'range), im(sinCosOut.im'range));
   end record RegType;

   constant REG_INIT_C : RegType := (
      rst          => (others => '0'),
      phaseMsb     => (others => '0'),
      phaseMsbR    => (others => '0'),
      phaseMsbRR   => (others => '0'),
      phaseMsbRRR  => (others => '0'),
      phaseLsb     => (others => '0'),
      sinAddr      => (others => '0'),
      cosAddr      => (others => '0'),
      lutSin       => (others => '0'),
      lutCos       => (others => '0'),
      lutSinDoReg  => (others => '0'),
      lutCosDoReg  => (others => '0'),
      sinCosOut    => (others => (others => '0')));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal quarterWaveLut : QuarterWaveLutType :=  initQuarterWaveLut(QUARTER_DEPTH_C, r.lutSin);

   attribute ram_style : string;
   attribute ram_style of quarterWaveLut : signal is MEMORY_TYPE_G;

   signal slvDelayIn  : slv(USER_WIDTH_G downto 0);
   signal slvDelayOut : slv(USER_WIDTH_G downto 0);

begin

   slvDelayIn(USER_WIDTH_G)              <= validIn;
   slvDelayIn(USER_WIDTH_G - 1 downto 0) <= userIn;
   validOut <= slvDelayOut(USER_WIDTH_G);
   userOut  <= slvDelayOut(USER_WIDTH_G - 1 downto 0);

   U_MATCH_CMULT_DELAY : entity surf.SlvFixedDelay
      generic map (
         TPD_G        => TPD_G,
         XIL_DEVICE_G => XIL_DEVICE_G,
         DELAY_G      => TOT_LATENCY_C,
         WIDTH_G      => USER_WIDTH_G + 1)
      port map (
         clk  => clk,
         din  => slvDelayIn,
         dout => slvDelayOut);

   comb : process(phaseIn, rst, r) is
      variable v      : RegType;
   begin
      v := r;

      v.phaseMsb  := phaseIn(phaseIn'high downto phaseIn'high - 1);
      v.phaseLsb  := phaseIn(phaseIn'high - 2 downto 0);

      v.rst(0)          := rst;
      v.rst(2 downto 1) := r.rst(1 downto 0);

      if REG_IN_G then
         case r.phaseMsb is
            when "00" =>
                v.cosAddr := r.phaseLsb;
                v.sinAddr := not(r.phaseLsb);
            when "01" =>
                v.cosAddr := not(r.phaseLsb);
                v.sinAddr := r.phaseLsb;
            when "10" =>
                v.cosAddr := r.phaseLsb;
                v.sinAddr := not(r.phaseLsb);
            --when "11" =>
            when others =>
                v.cosAddr := not(r.phaseLsb);
                v.sinAddr := r.phaseLsb;
         end case;

         v.phaseMsbR   := r.phaseMsb;
         v.phaseMsbRR  := r.phaseMsbR;
         v.phaseMsbRRR := r.phaseMsbRR;
      else
         case v.phaseMsb is
            when "00" =>
                v.cosAddr := v.phaseLsb;
                v.sinAddr := not(v.phaseLsb);
            when "01" =>
                v.cosAddr := not(v.phaseLsb);
                v.sinAddr := v.phaseLsb;
            when "10" =>
                v.cosAddr := v.phaseLsb;
                v.sinAddr := not(v.phaseLsb);
            --when "11" =>
            when others =>
                v.cosAddr := not(v.phaseLsb);
                v.sinAddr := v.phaseLsb;
         end case;

         -- skip first pipeline stage
         v.phaseMsbRR  := r.phaseMsb;
         v.phaseMsbRRR := r.phaseMsbRR;
      end if;

      case r.phaseMsbRRR is
         when "00" =>
             v.sinCosOut.re := resize( r.lutCosDoReg, v.sinCosOut.re, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
             v.sinCosOut.im := resize( r.lutSinDoReg, v.sinCosOut.re, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
         when "01" =>
             v.sinCosOut.re := resize(-r.lutCosDoReg, v.sinCosOut.re, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
             v.sinCosOut.im := resize( r.lutSinDoReg, v.sinCosOut.re, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
         when "10" =>
             v.sinCosOut.re := resize(-r.lutCosDoReg, v.sinCosOut.re, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
             v.sinCosOut.im := resize(-r.lutSinDoReg, v.sinCosOut.re, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
         --when "11" =>
         when others =>
             v.sinCosOut.re := resize( r.lutCosDoReg, v.sinCosOut.re, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
             v.sinCosOut.im := resize(-r.lutSinDoReg, v.sinCosOut.re, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
      end case;



      -- 2 c-c to access LUT value for BRAM
      v.lutCos      := quarterWaveLut(to_integer(r.cosAddr));
      v.lutSin      := quarterWaveLut(to_integer(r.sinAddr));

      -- DOREG reset
      if REG_IN_G then
         if r.rst(2) = '1' then
            v.lutCosDoReg := (others => '0');
            v.lutSinDoReg := (others => '0');
         else
            v.lutCosDoReg := r.lutCos;
            v.lutSinDoReg := r.lutSin;
         end if;
      else
         if r.rst(1) = '1' then
            v.lutCosDoReg := (others => '0');
            v.lutSinDoReg := (others => '0');
         else
            v.lutCosDoReg := r.lutCos;
            v.lutSinDoReg := r.lutSin;
         end if;
      end if;

      rin <= v;

      -- Outputs
      sinCosOut <= r.sinCosOut;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
