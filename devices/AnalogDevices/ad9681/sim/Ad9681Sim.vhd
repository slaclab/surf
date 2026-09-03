-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Primitive-free pin-level AD9681 device simulation
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

library surf;
use surf.StdRtlPkg.all;

entity Ad9681Sim is
   generic (
      TPD_G         : time                   := 1 ns;
      CLK_PERIOD_G  : time                   := 8 ns;
      DATA_PHASE_G  : time                   := 0 ns;
      FCO_PHASE_G   : time                   := 0 ns;
      DATA_SKEW_G   : TimeArray(15 downto 0) := (others => 0 ns);
      FCO_SKEW_G    : TimeArray(1 downto 0)  := (others => 0 ns);
      JITTER_G      : time                   := 0 ns;
      TIMING_BIAS_G : time                   := 0 ns);
   port (
      clkP : in sl;
      clkN : in sl;

      vin : in RealArray(7 downto 0);

      dP   : out Slv8Array(1 downto 0);
      dN   : out Slv8Array(1 downto 0);
      dcoP : out slv(1 downto 0);
      dcoN : out slv(1 downto 0);
      fcoP : out slv(1 downto 0);
      fcoN : out slv(1 downto 0);

      sclk : in    sl;
      sdio : inout sl;
      csb  : in    sl);
end entity Ad9681Sim;

architecture behavioral of Ad9681Sim is

   constant FRAME_PATTERN_C       : slv(7 downto 0) := "11110000";
   constant HALF_BIT_TIME_C        : time := CLK_PERIOD_G/16;
   constant CONVERSION_LATENCY_C   : positive := 16;

   -- The coherent serializer-frame handoff contributes the final sample clock
   -- of the ADC's specified 16-clock conversion latency.
   type NormalDataPipelineType is array (CONVERSION_LATENCY_C-2 downto 0) of Slv16Array(7 downto 0);

   signal spiWrEn      : sl;
   signal cfgAddr      : slv(12 downto 0);
   signal cfgWrData    : slv(31 downto 0);
   signal cfgByteValid : slv(3 downto 0);
   signal cfgRdByte    : slv(7 downto 0);
   signal cfgRdData    : slv(31 downto 0);
   signal normalData   : Slv16Array(7 downto 0) := (others => (others => '0'));
   signal normalDataPipeline : NormalDataPipelineType := (others => (others => (others => '0')));
   signal delayedNormalData  : Slv16Array(7 downto 0);
   signal sampleData   : Slv16Array(7 downto 0);
   signal serialData   : Slv8Array(1 downto 0);
   signal serialDco    : sl;
   signal serialFco    : slv(1 downto 0);

begin

   assert HALF_BIT_TIME_C > 0 ns
      report "Ad9681Sim requires CLK_PERIOD_G >= 16 simulator time units"
      severity failure;

   assert JITTER_G >= 0 ns
      report "Ad9681Sim requires nonnegative JITTER_G"
      severity failure;

   assert TIMING_BIAS_G >= 0 ns
      report "Ad9681Sim requires nonnegative TIMING_BIAS_G"
      severity failure;

   GEN_DATA_TIMING_CHECK : for i in 15 downto 0 generate
      constant EARLIEST_EDGE_C : time :=
         TIMING_BIAS_G+DATA_PHASE_G+DATA_SKEW_G(i)-JITTER_G;
      constant LATEST_EDGE_C   : time := DATA_PHASE_G+DATA_SKEW_G(i)+JITTER_G;
   begin
      assert EARLIEST_EDGE_C >= 0 ns and LATEST_EDGE_C < HALF_BIT_TIME_C
         report "Ad9681Sim data timing must be schedulable and precede the DCO edge"
         severity failure;
   end generate GEN_DATA_TIMING_CHECK;

   GEN_FCO_TIMING_CHECK : for i in 1 downto 0 generate
      constant EARLIEST_EDGE_C : time :=
         TIMING_BIAS_G+FCO_PHASE_G+FCO_SKEW_G(i)-JITTER_G;
      constant LATEST_EDGE_C   : time := FCO_PHASE_G+FCO_SKEW_G(i)+JITTER_G;
   begin
      assert EARLIEST_EDGE_C >= 0 ns and LATEST_EDGE_C < HALF_BIT_TIME_C
         report "Ad9681Sim FCO timing must be schedulable and precede the DCO edge"
         severity failure;
   end generate GEN_FCO_TIMING_CHECK;

   GEN_NORMAL_DATA : for i in 7 downto 0 generate
      adcConvert : process (vin(i)) is
         variable analogInput : real;
      begin
         -- Real-valued board models can produce a transient NaN while their
         -- concurrent amplifier stages settle at time zero. NaN is unordered,
         -- so both comparisons are false. Substitute the low-scale input before
         -- calling adcConversion(), whose math_real clamp does not handle NaN.
         if (vin(i) < 0.0) or (vin(i) >= 0.0) then
            analogInput := vin(i);
         else
            analogInput := 0.0;
         end if;
         -- vin is the differential ADC input (vinP - vinN); the AD9681's 2 Vpp
         -- differential full scale spans +/-1 V, so a symmetric conversion
         -- window maps 0 V to mid-scale (offset binary).  A unipolar [0,2]
         -- window would clamp every negative differential to code 0.
         normalData(i) <= "00" & adcConversion(analogInput, -1.0, 1.0, 14, false);
      end process adcConvert;
   end generate GEN_NORMAL_DATA;

   ------------------------------------------------------------------------------------------------
   -- The AD9681 specifies 16 sample clocks of conversion latency. Fifteen
   -- stages are explicit here; sampleData is then captured once per complete
   -- serializer frame below, providing the sixteenth sample-clock delay at the
   -- pins. Test patterns are generated after this analog conversion pipeline.
   ------------------------------------------------------------------------------------------------
   conversionPipeline : process (clkP) is
   begin
      if rising_edge(clkP) then
         normalDataPipeline(0) <= normalData after TPD_G;
         for i in 1 to CONVERSION_LATENCY_C-2 loop
            normalDataPipeline(i) <= normalDataPipeline(i-1) after TPD_G;
         end loop;
      end if;
   end process conversionPipeline;

   delayedNormalData <= normalDataPipeline(CONVERSION_LATENCY_C-2);

   cfgRdData <= x"000000" & cfgRdByte;

   U_Config : entity surf.AdiConfigSlave
      generic map (
         TPD_G => TPD_G)
      port map (
         clk       => clkP, -- [in]
         sclk      => sclk, -- [in]
         sdio      => sdio, -- [inout]
         csb       => csb, -- [in]
         wrEn      => spiWrEn, -- [out]
         rdEn      => open, -- [out]
         addr      => cfgAddr, -- [out]
         wrData    => cfgWrData, -- [out]
         byteValid => cfgByteValid, -- [out]
         rdData    => cfgRdData); -- [in]

   ------------------------------------------------------------------------------------------------
   -- The physical AD9681 exposes a single SPI port that addresses both internal
   -- four-channel banks. Applying each write to both banks in the same sample
   -- clock keeps their per-channel PN generators reseeded coherently, matching
   -- the real device; staggering the two banks would offset them by one sample.
   ------------------------------------------------------------------------------------------------
   U_Core : entity surf.Ad9681SimCore
      generic map (
         TPD_G => TPD_G)
      port map (
         sampleClk    => clkP, -- [in]
         sampleRst    => '0', -- [in]
         sampleEnable => '1', -- [in]
         normalData   => delayedNormalData, -- [in]
         cfgWrEn      => spiWrEn, -- [in]
         cfgAddr      => cfgAddr(8 downto 0), -- [in]
         cfgWrData    => cfgWrData(7 downto 0), -- [in]
         cfgRdData    => cfgRdByte, -- [out]
         sampleData   => sampleData, -- [out]
         sampleValid  => open); -- [out]

   ------------------------------------------------------------------------------------------------
   -- Each physical output group serializes one byte of every channel. DCO
   -- remains binary and jitter-free. A common timing bias delays DCO, data, and
   -- FCO equally so negative jitter remains schedulable without moving the
   -- nominal sampling point. Data and FCO transitions also receive their
   -- configured static phase/skew plus bounded deterministic jitter that
   -- alternates between negative and positive displacement on each actual
   -- transition. All pins remain binary so unknown values cannot escape through
   -- system interfaces.
   ------------------------------------------------------------------------------------------------
   serializer : process is
      variable dco                : sl := '0';
      variable frameData          : Slv16Array(7 downto 0) := (others => (others => '0'));
      variable dataCurrent        : Slv8Array(1 downto 0) := (others => (others => '0'));
      variable fcoCurrent         : slv(1 downto 0) := (others => '0');
      variable dataJitterPositive : BooleanArray(15 downto 0) := (others => false);
      variable fcoJitterPositive  : BooleanArray(1 downto 0) := (others => false);
      variable nextData           : sl;
      variable nextFco            : sl;
      variable edgeJitter         : time;
   begin
      serialData <= (others => (others => '0'));
      serialDco  <= '0';
      serialFco  <= (others => '0');
      wait until rising_edge(clkP);
      loop
         -- Capture one coherent output word per channel. sampleData updates
         -- after the encode edge, so this also provides the last cycle of the
         -- specified conversion latency without tearing alternating patterns.
         frameData := sampleData;
         for bitindex in 7 downto 0 loop
            for grp in 1 downto 0 loop
               for ch in 7 downto 0 loop
                  nextData := frameData(ch)(bitindex+(8*grp));
                  if (nextData /= dataCurrent(grp)(ch)) then
                     if (dataJitterPositive((8*grp)+ch)) then
                        edgeJitter := JITTER_G;
                     else
                        edgeJitter := -JITTER_G;
                     end if;
                     dataJitterPositive((8*grp)+ch) :=
                        not dataJitterPositive((8*grp)+ch);
                     serialData(grp)(ch) <= transport nextData after
                        TIMING_BIAS_G+DATA_PHASE_G+
                        DATA_SKEW_G((8*grp)+ch)+edgeJitter;
                     dataCurrent(grp)(ch) := nextData;
                  end if;
               end loop;
            end loop;

            nextFco := FRAME_PATTERN_C(bitindex);
            for grp in 1 downto 0 loop
               if (nextFco /= fcoCurrent(grp)) then
                  if (fcoJitterPositive(grp)) then
                     edgeJitter := JITTER_G;
                  else
                     edgeJitter := -JITTER_G;
                  end if;
                  fcoJitterPositive(grp) := not fcoJitterPositive(grp);
                  serialFco(grp) <= transport nextFco after
                     TIMING_BIAS_G+FCO_PHASE_G+FCO_SKEW_G(grp)+edgeJitter;
                  fcoCurrent(grp) := nextFco;
               end if;
            end loop;

            wait for HALF_BIT_TIME_C;
            dco       := not dco;
            serialDco <= transport dco after TIMING_BIAS_G;
            wait for HALF_BIT_TIME_C;
         end loop;
      end loop;
   end process serializer;

   dP   <= serialData;
   dN   <= (not serialData(1), not serialData(0));
   dcoP <= (others => serialDco);
   dcoN <= (others => not serialDco);
   fcoP <= serialFco;
   fcoN <= not serialFco;

end architecture behavioral;
