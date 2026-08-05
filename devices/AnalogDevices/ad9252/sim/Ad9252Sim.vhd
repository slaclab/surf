-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Primitive-free pin-level AD9252 device simulation
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

entity Ad9252Sim is
   generic (
      TPD_G         : time                  := 1 ns;
      CLK_PERIOD_G  : time                  := 24 ns;
      DATA_PHASE_G  : time                  := 0 ns;
      FCO_PHASE_G   : time                  := 0 ns;
      DATA_SKEW_G   : TimeArray(7 downto 0) := (others => 0 ns);
      FCO_SKEW_G    : time                  := 0 ns;
      JITTER_G      : time                  := 0 ns;
      TIMING_BIAS_G : time                  := 0 ns);
   port (
      clkP : in sl;
      clkN : in sl;

      vin : in RealArray(7 downto 0);

      dP   : out slv(7 downto 0);
      dN   : out slv(7 downto 0);
      dcoP : out sl;
      dcoN : out sl;
      fcoP : out sl;
      fcoN : out sl;

      sclk : in    sl;
      sdio : inout sl;
      csb  : in    sl);
end entity Ad9252Sim;

architecture behavioral of Ad9252Sim is

   constant FRAME_PATTERN_C     : slv(13 downto 0) := "11111110000000";
   constant HALF_BIT_TIME_C      : time := CLK_PERIOD_G/28;
   constant CONVERSION_LATENCY_C : positive := 8;

   type NormalDataPipelineType is array (CONVERSION_LATENCY_C-2 downto 0) of
      Slv16Array(7 downto 0);

   signal cfgWrEn      : sl;
   signal cfgAddr      : slv(12 downto 0);
   signal cfgWrData    : slv(31 downto 0);
   signal cfgByteValid : slv(3 downto 0);
   signal cfgRdByte    : slv(7 downto 0);
   signal cfgRdData    : slv(31 downto 0);
   signal normalData   : Slv16Array(7 downto 0) := (others => (others => '0'));
   signal normalDataPipeline : NormalDataPipelineType := (others => (others => (others => '0')));
   signal delayedNormalData  : Slv16Array(7 downto 0);
   signal sampleData   : Slv16Array(7 downto 0);
   signal serialData   : slv(7 downto 0);
   signal serialDco    : sl;
   signal serialFco    : sl;

begin

   assert HALF_BIT_TIME_C > 0 ns
      report "Ad9252Sim requires CLK_PERIOD_G >= 28 simulator time units"
      severity failure;

   assert JITTER_G >= 0 ns
      report "Ad9252Sim requires nonnegative JITTER_G"
      severity failure;

   assert TIMING_BIAS_G >= 0 ns
      report "Ad9252Sim requires nonnegative TIMING_BIAS_G"
      severity failure;

   GEN_DATA_TIMING_CHECK : for i in 7 downto 0 generate
      constant EARLIEST_EDGE_C : time :=
         TIMING_BIAS_G+DATA_PHASE_G+DATA_SKEW_G(i)-JITTER_G;
      constant LATEST_EDGE_C   : time := DATA_PHASE_G+DATA_SKEW_G(i)+JITTER_G;
   begin
      assert EARLIEST_EDGE_C >= 0 ns and LATEST_EDGE_C < HALF_BIT_TIME_C
         report "Ad9252Sim data timing must be schedulable and precede the DCO edge"
         severity failure;
   end generate GEN_DATA_TIMING_CHECK;

   assert TIMING_BIAS_G+FCO_PHASE_G+FCO_SKEW_G-JITTER_G >= 0 ns and
          FCO_PHASE_G+FCO_SKEW_G+JITTER_G < HALF_BIT_TIME_C
      report "Ad9252Sim FCO timing must be schedulable and precede the DCO edge"
      severity failure;

   GEN_NORMAL_DATA : for i in 7 downto 0 generate
      adcConvert : process (vin(i)) is
         variable analogInput : real;
      begin
         -- Real-valued board models can briefly produce NaN at time zero.
         -- Substitute low scale because adcConversion() cannot clamp NaN.
         if (vin(i) < 0.0) or (vin(i) >= 0.0) then
            analogInput := vin(i);
         else
            analogInput := 0.0;
         end if;
         normalData(i) <= "00" & adcConversion(analogInput, 0.0, 2.0, 14, false);
      end process adcConvert;
   end generate GEN_NORMAL_DATA;

   ------------------------------------------------------------------------------------------------
   -- The AD9252 specifies eight sample clocks of conversion latency. Seven
   -- stages are explicit here; the coherent serializer-frame capture below
   -- contributes the final sample clock at the output pins. Test patterns are
   -- generated after this normal-conversion pipeline.
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
         wrEn      => cfgWrEn, -- [out]
         rdEn      => open, -- [out]
         addr      => cfgAddr, -- [out]
         wrData    => cfgWrData, -- [out]
         byteValid => cfgByteValid, -- [out]
         rdData    => cfgRdData); -- [in]

   U_Core : entity surf.Ad9252SimCore
      generic map (
         TPD_G => TPD_G)
      port map (
         sampleClk    => clkP, -- [in]
         sampleRst    => '0', -- [in]
         sampleEnable => '1', -- [in]
         normalData   => delayedNormalData, -- [in]
         cfgWrEn      => cfgWrEn, -- [in]
         cfgAddr      => cfgAddr(7 downto 0), -- [in]
         cfgWrData    => cfgWrData(7 downto 0), -- [in]
         cfgRdData    => cfgRdByte, -- [out]
         sampleData   => sampleData, -- [out]
         sampleValid  => open); -- [out]

   ------------------------------------------------------------------------------------------------
   -- Latch one coherent word per frame before applying transition-only static
   -- timing and bounded alternating jitter. DCO remains binary and jitter-free;
   -- the common bias makes negative jitter schedulable.
   ------------------------------------------------------------------------------------------------
   serializer : process is
      variable dco                : sl := '0';
      variable frameData          : Slv16Array(7 downto 0) := (others => (others => '0'));
      variable dataCurrent        : slv(7 downto 0) := (others => '0');
      variable fcoCurrent         : sl := '0';
      variable dataJitterPositive : BooleanArray(7 downto 0) := (others => false);
      variable fcoJitterPositive  : boolean := false;
      variable nextData           : sl;
      variable nextFco            : sl;
      variable edgeJitter         : time;
   begin
      serialData <= (others => '0');
      serialDco  <= '0';
      serialFco  <= '0';
      wait until rising_edge(clkP);
      loop
         -- sampleData updates after the encode edge. Capturing it here both
         -- prevents checkerboard tearing and supplies the last latency cycle.
         frameData := sampleData;
         for bitindex in 13 downto 0 loop
            for ch in 7 downto 0 loop
               nextData := frameData(ch)(bitindex);
               if (nextData /= dataCurrent(ch)) then
                  if (dataJitterPositive(ch)) then
                     edgeJitter := JITTER_G;
                  else
                     edgeJitter := -JITTER_G;
                  end if;
                  dataJitterPositive(ch) := not dataJitterPositive(ch);
                  serialData(ch) <= transport nextData after
                     TIMING_BIAS_G+DATA_PHASE_G+DATA_SKEW_G(ch)+edgeJitter;
                  dataCurrent(ch) := nextData;
               end if;
            end loop;

            nextFco := FRAME_PATTERN_C(bitindex);
            if (nextFco /= fcoCurrent) then
               if (fcoJitterPositive) then
                  edgeJitter := JITTER_G;
               else
                  edgeJitter := -JITTER_G;
               end if;
               fcoJitterPositive := not fcoJitterPositive;
               serialFco <= transport nextFco after
                  TIMING_BIAS_G+FCO_PHASE_G+FCO_SKEW_G+edgeJitter;
               fcoCurrent := nextFco;
            end if;

            wait for HALF_BIT_TIME_C;
            dco       := not dco;
            serialDco <= transport dco after TIMING_BIAS_G;
            wait for HALF_BIT_TIME_C;
         end loop;
      end loop;
   end process serializer;

   dP   <= serialData;
   dN   <= not serialData;
   dcoP <= serialDco;
   dcoN <= not serialDco;
   fcoP <= serialFco;
   fcoN <= not serialFco;

end architecture behavioral;
