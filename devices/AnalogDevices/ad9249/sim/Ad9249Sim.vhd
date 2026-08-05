-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Primitive-free pin-level AD9249 device simulation
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

entity Ad9249Sim is
   generic (
      TPD_G            : time                    := 1 ns;
      CLK_PERIOD_G     : time                    := 24 ns;
      DIVCLK_DIVIDE_G  : integer                 := 1;
      CLKFBOUT_MULT_G  : integer                 := 49;
      CLK_DCO_DIVIDE_G : integer                 := 49;
      CLK_FCO_DIVIDE_G : integer                 := 7;
      DATA_PHASE_G     : time                    := 0 ns;
      FCO_PHASE_G      : time                    := 0 ns;
      DATA_SKEW_G      : TimeArray(15 downto 0)  := (others => 0 ns);
      FCO_SKEW_G       : TimeArray(1 downto 0)   := (others => 0 ns);
      JITTER_G         : time                    := 0 ns;
      TIMING_BIAS_G    : time                    := 0 ns);
   port (
      clkP : in    sl;
      clkN : in    sl;
      vin  : in    RealArray(15 downto 0);
      dP   : out   slv(15 downto 0);
      dN   : out   slv(15 downto 0);
      dcoP : out   slv(1 downto 0);
      dcoN : out   slv(1 downto 0);
      fcoP : out   slv(1 downto 0);
      fcoN : out   slv(1 downto 0);
      sclk : in    sl;
      sdio : inout sl;
      csb  : in    slv(1 downto 0));
end entity Ad9249Sim;

architecture behavioral of Ad9249Sim is

   constant FRAME_PATTERN_C     : slv(13 downto 0) := "11111110000000";
   constant HALF_BIT_TIME_C      : time := CLK_PERIOD_G/28;
   constant CONVERSION_LATENCY_C : positive := 16;

   type Slv13Array is array (natural range <>) of slv(12 downto 0);
   type NormalDataPipelineType is array (CONVERSION_LATENCY_C-2 downto 0) of
      Slv16Array(15 downto 0);

   signal cfgWrEn      : slv(1 downto 0);
   signal cfgAddr      : Slv13Array(1 downto 0);
   signal cfgWrData    : Slv32Array(1 downto 0);
   signal cfgByteValid : Slv4Array(1 downto 0);
   signal cfgRdByte    : Slv8Array(1 downto 0);
   signal cfgRdData    : Slv32Array(1 downto 0);
   signal normalData   : Slv16Array(15 downto 0) := (others => (others => '0'));
   signal normalDataPipeline : NormalDataPipelineType := (others => (others => (others => '0')));
   signal delayedNormalData  : Slv16Array(15 downto 0);
   signal sampleData   : Slv16Array(15 downto 0);
   signal sampleValid  : slv(1 downto 0);
   signal serialData   : Slv8Array(1 downto 0);
   signal serialDco    : slv(1 downto 0);
   signal serialFco    : slv(1 downto 0);

begin

   assert HALF_BIT_TIME_C > 0 ns
      report "Ad9249Sim requires CLK_PERIOD_G >= 28 simulator time units"
      severity failure;

   -- These clock-manager generics are retained for source compatibility with
   -- the legacy model. Device timing is derived directly from CLK_PERIOD_G.
   assert DIVCLK_DIVIDE_G > 0 and CLKFBOUT_MULT_G > 0 and
          CLK_DCO_DIVIDE_G > 0 and CLK_FCO_DIVIDE_G > 0
      report "Ad9249Sim clock compatibility generics must be positive"
      severity failure;

   assert JITTER_G >= 0 ns
      report "Ad9249Sim requires nonnegative JITTER_G"
      severity failure;

   assert TIMING_BIAS_G >= 0 ns
      report "Ad9249Sim requires nonnegative TIMING_BIAS_G"
      severity failure;

   GEN_DATA_TIMING_CHECK : for i in 15 downto 0 generate
      constant EARLIEST_EDGE_C : time :=
         TIMING_BIAS_G+DATA_PHASE_G+DATA_SKEW_G(i)-JITTER_G;
      constant LATEST_EDGE_C   : time := DATA_PHASE_G+DATA_SKEW_G(i)+JITTER_G;
   begin
      assert EARLIEST_EDGE_C >= 0 ns and LATEST_EDGE_C < HALF_BIT_TIME_C
         report "Ad9249Sim data timing must be schedulable and precede the DCO edge"
         severity failure;
   end generate GEN_DATA_TIMING_CHECK;

   GEN_FCO_TIMING_CHECK : for i in 1 downto 0 generate
      constant EARLIEST_EDGE_C : time :=
         TIMING_BIAS_G+FCO_PHASE_G+FCO_SKEW_G(i)-JITTER_G;
      constant LATEST_EDGE_C   : time := FCO_PHASE_G+FCO_SKEW_G(i)+JITTER_G;
   begin
      assert EARLIEST_EDGE_C >= 0 ns and LATEST_EDGE_C < HALF_BIT_TIME_C
         report "Ad9249Sim FCO timing must be schedulable and precede the DCO edge"
         severity failure;
   end generate GEN_FCO_TIMING_CHECK;

   GEN_NORMAL_DATA : for i in 15 downto 0 generate
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
   -- The AD9249 specifies 16 sample clocks of conversion latency. Fifteen
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

   GEN_GROUP : for g in 1 downto 0 generate
      constant LOW_CH_C  : natural := 8*g;
      constant HIGH_CH_C : natural := LOW_CH_C+7;
   begin

      cfgRdData(g) <= x"000000" & cfgRdByte(g);

      U_Config : entity surf.AdiConfigSlave
         generic map (
            TPD_G => TPD_G)
         port map (
            clk       => clkP, -- [in]
            sclk      => sclk, -- [in]
            sdio      => sdio, -- [inout]
            csb       => csb(g), -- [in]
            wrEn      => cfgWrEn(g), -- [out]
            rdEn      => open, -- [out]
            addr      => cfgAddr(g), -- [out]
            wrData    => cfgWrData(g), -- [out]
            byteValid => cfgByteValid(g), -- [out]
            rdData    => cfgRdData(g)); -- [in]

      U_Core : entity surf.Ad9249SimCore
         generic map (
            TPD_G => TPD_G)
         port map (
            sampleClk    => clkP, -- [in]
            sampleRst    => '0', -- [in]
            sampleEnable => '1', -- [in]
            normalData   => delayedNormalData(HIGH_CH_C downto LOW_CH_C), -- [in]
            cfgWrEn      => cfgWrEn(g), -- [in]
            cfgAddr      => cfgAddr(g)(8 downto 0), -- [in]
            cfgWrData    => cfgWrData(g)(7 downto 0), -- [in]
            cfgRdData    => cfgRdByte(g), -- [out]
            sampleData   => sampleData(HIGH_CH_C downto LOW_CH_C), -- [out]
            sampleValid  => sampleValid(g)); -- [out]

      ------------------------------------------------------------------------------------------------
      -- Latch one coherent bank word per frame before applying transition-only
      -- static timing and bounded alternating jitter. DCO remains binary and
      -- jitter-free; the common bias makes negative jitter schedulable.
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
         serialData(g) <= (others => '0');
         serialDco(g)  <= '0';
         serialFco(g)  <= '0';
         wait until rising_edge(clkP);
         loop
            -- sampleData updates after the encode edge. Capturing it here both
            -- prevents checkerboard tearing and supplies the last latency cycle.
            for ch in 7 downto 0 loop
               frameData(ch) := sampleData(LOW_CH_C+ch);
            end loop;
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
                     serialData(g)(ch) <= transport nextData after
                        TIMING_BIAS_G+DATA_PHASE_G+
                        DATA_SKEW_G(LOW_CH_C+ch)+edgeJitter;
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
                  serialFco(g) <= transport nextFco after
                     TIMING_BIAS_G+FCO_PHASE_G+FCO_SKEW_G(g)+edgeJitter;
                  fcoCurrent := nextFco;
               end if;

               wait for HALF_BIT_TIME_C;
               dco         := not dco;
               serialDco(g) <= transport dco after TIMING_BIAS_G;
               wait for HALF_BIT_TIME_C;
            end loop;
         end loop;
      end process serializer;

   end generate GEN_GROUP;

   dP   <= serialData(1) & serialData(0);
   dN   <= not (serialData(1) & serialData(0));
   dcoP <= serialDco;
   dcoN <= not serialDco;
   fcoP <= serialFco;
   fcoN <= not serialFco;

end architecture behavioral;
