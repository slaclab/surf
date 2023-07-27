-------------------------------------------------------------------------------
-- Title      : AD9681 Simulation Module
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of SLAC Firmware Standard Library. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of SLAC Firmware Standard Library, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.TextUtilPkg.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity Ad9681 is

   generic (
      TPD_G : time := 1 ns);

   port (
      clkP : in sl;
      clkN : in sl;

      vin : in RealArray(7 downto 0);

      dP   : out slv8array(1 downto 0);
      dN   : out slv8array(1 downto 0);
      dcoP : out slv(1 downto 0);
      dcoN : out slv(1 downto 0);
      fcoP : out slv(1 downto 0);
      fcoN : out slv(1 downto 0);

      sclk : in    sl;
      sdio : inout sl;
      csb  : in    sl);

end entity Ad9681;

architecture behavioral of Ad9681 is

   -------------------------------------------------------------------------------------------------
   -- Config and Sampling constant and signals
   -------------------------------------------------------------------------------------------------
   constant PN_SHORT_TAPS_C : NaturalArray     := (0 => 4, 1 => 8);    -- X9+X5+1
   constant PN_SHORT_INIT_C : slv(8 downto 0)  := "011011111";
   constant PN_LONG_TAPS_C  : NaturalArray     := (0 => 16, 1 => 22);  -- X23+X18+1
   constant PN_LONG_INIT_C  : slv(22 downto 0) := "01001101110000000101000";

   -- ConfigSlave signals
   signal wrEn      : sl;
   signal addr      : slv(12 downto 0);
   signal wrData    : slv(31 downto 0);
   signal byteValid : slv(3 downto 0);

   type GlobalConfigType is record
      mode           : slv(2 downto 0);
      stabilizer     : sl;
      clockDivRatio  : slv(2 downto 0);
      outputLvds     : sl;
      outputInvert   : sl;
      termination    : slv(1 downto 0);
      driveStrength  : sl;
      lsbFirst       : sl;
      outputMode     : slv(2 downto 0);
      pllLowRateMode : sl;
      sel2xFrame     : sl;
      bits           : slv(1 downto 0);
      binFormat      : sl;
      digitalFsAdj   : slv(2 downto 0);
   end record GlobalConfigType;

   constant GLOBAL_CONFIG_INIT_C : GlobalConfigType := (
      mode           => "000",
      stabilizer     => '1',
      clockDivRatio  => "000",
      outputLvds     => '0',
      outputInvert   => '0',
      termination    => "00",
      driveStrength  => '0',
      lsbFirst       => '0',
      outputMode     => "011",
      pllLowRateMode => '0',
      sel2xFrame     => '0',
      bits           => "00",
      binFormat      => '1',
      digitalFsAdj   => "100");

   type ChannelConfigType is record
      chopMode        : sl;
      pn23            : slv(22 downto 0);
      resetPnLongGen  : sl;
      pn9             : slv(8 downto 0);
      resetPnShortGen : sl;
      userTestMode    : slv(1 downto 0);
      outputTestMode  : slv(3 downto 0);
      outputPhase     : slv(3 downto 0);
      inputPhase      : slv(2 downto 0);
      userPattern1    : slv(15 downto 0);
      userPattern2    : slv(15 downto 0);
      offsetAdjust    : slv(7 downto 0);
      outputReset     : sl;
      powerDown       : sl;
   end record ChannelConfigType;

   constant CHANNEL_CONFIG_INIT_C : ChannelConfigType := (
      chopMode        => '0',
      pn23            => PN_LONG_INIT_C,
      resetPnLongGen  => '0',
      pn9             => PN_SHORT_INIT_C,
      resetPnShortGen => '0',
      userTestMode    => "00",
      outputTestMode  => "0000",
      outputPhase     => "0011",
      inputPhase      => "000",
      userPattern1    => X"0000",
      userPattern2    => X"0000",
      offsetAdjust    => X"00",
      outputReset     => '0',
      powerDown       => '0');

   type ChannelConfigArray is array (natural range <>) of ChannelConfigType;

   type DelayArray is array (15 downto 0) of RealArray(7 downto 0);

   type ConfigRegType is record
      vinDelay        : DelayArray;
      sample          : Slv16Array(7 downto 0);  -- slv(13 downto 0);
      rdData          : slv(31 downto 0);
      lsbFirst        : sl;
      softReset       : sl;
      channelConfigEn : slv(9 downto 0);
      tmpGlobal       : GlobalConfigType;
      tmpChannel      : ChannelConfigType;
      global          : GlobalConfigType;
      channel         : ChannelConfigArray(9 downto 0);
      word            : sl;
   end record ConfigRegType;

   constant CONFIG_REG_INIT_C : ConfigRegType := (
      vinDelay        => (others => (others => 0.0)),
      sample          => (others => "0000000000000000"),
      rdData          => X"00000000",
      lsbFirst        => '0',
      softReset       => '0',
      channelConfigEn => "1111111111",
      tmpGlobal       => GLOBAL_CONFIG_INIT_C,
      tmpChannel      => CHANNEL_CONFIG_INIT_C,
      global          => GLOBAL_CONFIG_INIT_C,
      channel         => (others => CHANNEL_CONFIG_INIT_C),
      word            => '0');

   signal r   : ConfigRegType := CONFIG_REG_INIT_C;
   signal rin : ConfigRegType;

   -------------------------------------------------------------------------------------------------
   -- Output constants and signals
   -------------------------------------------------------------------------------------------------
--   constant DCLK_PERIOD_C : time := CLK_PERIOD_G / 7.0;

   signal pllRst   : sl;
   signal clk      : sl;
   signal locked   : sl;
   signal rst      : sl;
   signal clkFbOut : sl;
   signal clkFbIn  : sl;
   signal dClkInt  : sl;
   signal dClk     : sl;
   signal fClkInt  : sl;
   signal fClk     : sl;
   signal dcoInt   : sl;
   signal dco      : sl;
   signal fcoInt   : sl;
   signal fco      : sl;
   signal serData  : slv8array(1 downto 0);

begin

   -------------------------------------------------------------------------------------------------
   -- Create local clocks
   -------------------------------------------------------------------------------------------------
--   ClkRst_1 : entity surf.ClkRst
--      generic map (
--         RST_HOLD_TIME_G => 50 us)
--      port map (
--         rst => pllRst);

   process is
   begin
      pllRst <= '1';
      wait for 15 us;
      pllRst <= '0';
      wait until locked = '0';
   end process;


   CLK_BUFG : IBUFGDS
      port map (
         I  => clkP,
         IB => clkN,
         O  => clk);

   plle2_adv_inst : PLLE2_ADV
      generic map (
         BANDWIDTH          => "HIGH",
         COMPENSATION       => "ZHOLD",
         DIVCLK_DIVIDE      => 1,
         CLKFBOUT_MULT      => 8,
         CLKFBOUT_PHASE     => 0.000,
         CLKOUT0_DIVIDE     => 8,
         CLKOUT0_PHASE      => 0.000,
         CLKOUT0_DUTY_CYCLE => 0.500,
         CLKOUT1_DIVIDE     => 2,
         CLKOUT1_PHASE      => 0.000,
         CLKOUT1_DUTY_CYCLE => 0.500,
         CLKOUT2_DIVIDE     => 2,
         CLKOUT2_PHASE      => 180.000,
         CLKOUT2_DUTY_CYCLE => 0.500,
         CLKOUT3_DIVIDE     => 8,
         CLKOUT3_PHASE      => 0.000,
         CLKOUT3_DUTY_CYCLE => 0.500,
         CLKIN1_PERIOD      => 8.0,
         REF_JITTER1        => 0.010)
      port map (
         -- Output clocks
         CLKFBOUT => clkFbOut,
         CLKOUT0  => fClkInt,
         CLKOUT1  => dClkInt,
         CLKOUT2  => dcoInt,            -- Shifted serial clock for output
         CLKOUT3  => fcoInt,
         CLKOUT4  => open,
         CLKOUT5  => open,
         -- Input clock control
         CLKFBIN  => clkFbIn,
         CLKIN1   => clk,
         CLKIN2   => '0',
         -- Tied to always select the primary input clock
         CLKINSEL => '1',
         -- Ports for dynamic reconfiguration
         DADDR    => (others => '0'),
         DCLK     => '0',
         DEN      => '0',
         DI       => (others => '0'),
         DO       => open,
         DRDY     => open,
         DWE      => '0',
         -- Other control and status signals
         LOCKED   => locked,
         PWRDWN   => '0',
         RST      => pllRst);

   FB_BUFG : BUFG
      port map (
         I => clkFbOut,
         O => clkFbIn);

   FCLK_BUFG : BUFG
      port map (
         I => fClkInt,
         O => fClk);

   DCLK_BUFG : BUFG
      port map (
         I => dClkInt,
         O => dClk);

   DCO_BUFG : BUFG
      port map (
         I => dcoInt,
         O => dco);

   FCO_BUFG : BUFG
      port map (
         I => fcoInt,
         O => fco);

   RstSync_1 : entity surf.RstSync
      generic map (
         TPD_G           => TPD_G,
         IN_POLARITY_G   => '0',
         OUT_POLARITY_G  => '1',
         RELEASE_DELAY_G => 10)
      port map (
         clk      => fClk,
         asyncRst => locked,
         syncRst  => rst);

   -------------------------------------------------------------------------------------------------
   -- Instantiate configuration interface
   -------------------------------------------------------------------------------------------------
   AdiConfigSlave_1 : entity surf.AdiConfigSlave
      generic map (
         TPD_G => TPD_G)
      port map (
         clk       => fClk,
         sclk      => sclk,
         sdio      => sdio,
         csb       => csb,
         wrEn      => wrEn,
         rdEn      => open,
         addr      => addr,
         wrData    => wrData,
         byteValid => byteValid,
         rdData    => r.rdData);

   -------------------------------------------------------------------------------------------------
   -- Configuration register logic
   -------------------------------------------------------------------------------------------------
   comb : process (addr, r, vin, wrData, wrEn) is
      variable v             : ConfigRegType;
      variable activeChannel : ChannelConfigType;
      variable zero          : slv(13 downto 0) := (others => '0');
   begin
      v := r;

      for i in 7 downto 0 loop
         v.vinDelay(0)(i) := vin(i);
         for j in 15 downto 1 loop
            v.vinDelay(j)(i) := r.vinDelay(j-1)(i);
         end loop;
      end loop;

      ----------------------------------------------------------------------------------------------
      -- Configuration Registers
      ----------------------------------------------------------------------------------------------
      activeChannel := r.channel(0);
      for i in 9 downto 0 loop
         if (r.channelConfigEn(i) = '1') then
            activeChannel := r.channel(i);
         end if;
      end loop;


      v.rdData := (others => '0');
      case (addr(7 downto 0)) is

         when X"00" =>                  -- chip_port_config
            v.rdData(6) := r.lsbFirst;
            v.rdData(5) := r.softReset;
            v.rdData(4) := '1';
            v.rdData(3) := '1';
            v.rdData(2) := r.softReset;
            v.rdData(1) := r.lsbFirst;
            if (wrEn = '1') then
               v.lsbFirst  := wrData(6) or wrData(1);
               v.softReset := wrData(5) or wrData(2);
            end if;

         when X"01" =>                  -- chip_id
            v.rdData(7 downto 0) := X"8F";

         when X"02" =>                  -- chip_grade
            v.rdData(6 downto 4) := "110";

            -------------------------------------------------------------------------------------------
--          when X"04" =>                  -- device_index_2
--             v.rdData(3 downto 0) := r.channelConfigEn(7 downto 4);
--             if (wrEn = '1') then
--                v.channelConfigEn(7 downto 4) := wrData(3 downto 0);
--             end if;

         when X"05" =>                                               -- device_index_1
            v.rdData(3 downto 0) := r.channelConfigEn(3 downto 0);
            v.rdData(4)          := r.channelConfigEn(8);
            v.rdData(5)          := r.channelConfigEn(9);
            if (wrEn = '1') then
               v.channelConfigEn(3 downto 0) := wrData(3 downto 0);
               v.channelConfigEn(7 downto 4) := wrData(3 downto 0);  -- Check this
               v.channelConfigEn(8)          := wrData(4);
               v.channelConfigEn(9)          := wrData(5);
            end if;

         when X"FF" =>                  -- device update
            if (wrEn = '1') then
               v.global := r.tmpGlobal;
               for i in 9 downto 0 loop
                  if (r.channelConfigEn(i) = '1') then
                     v.channel(i) := r.tmpChannel;
                     if (r.tmpChannel.resetPnLongGen = '1') then
                        v.channel(i).pn23 := PN_LONG_INIT_C;
                     end if;
                     if (r.tmpChannel.resetPnShortGen = '1') then
                        v.channel(i).pn9 := PN_SHORT_INIT_C;
                     end if;
                  end if;
               end loop;
            end if;

         -------------------------------------------------------------------------------------------
         when X"08" =>                  -- modes
            v.rdData(1 downto 0) := r.global.mode(1 downto 0);
            v.rdData(5)          := r.global.mode(2);
            if (wrEn = '1') then
               v.tmpGlobal.mode(1 downto 0) := wrData(1 downto 0);
               v.tmpGlobal.mode(2)          := wrData(5);
            end if;

         when X"09" =>                  -- clock
            v.rdData(0) := r.global.stabilizer;
            if (wrEn = '1') then
               v.tmpGlobal.stabilizer := wrData(0);
            end if;

         when X"0B" =>
            v.rdData(2 downto 0) := r.global.clockDivRatio;
            if (wrEn = '1') then
               v.tmpGlobal.clockDivRatio := wrData(2 downto 0);
            end if;

         when X"0C" =>
            v.rdData(2) := activeChannel.chopMode;
            if (wrEn = '1') then
               v.tmpChannel.chopMode := wrData(2);
            end if;


         when X"0D" =>                  -- test_io
            v.rdData(7 downto 6) := activeChannel.userTestMode;
            v.rdData(5)          := activeChannel.resetPnLongGen;
            v.rdData(4)          := activeChannel.resetPnShortGen;
            v.rdData(3 downto 0) := activeChannel.outputTestMode;
            if (wrEn = '1') then
               v.tmpChannel.userTestMode    := wrData(7 downto 6);
               v.tmpChannel.resetPnLongGen  := wrData(5);
               v.tmpChannel.resetPnShortGen := wrData(4);
               v.tmpChannel.outputTestMode  := wrData(3 downto 0);
            end if;

         when X"10" =>
            v.rdData(7 downto 0) := activeChannel.offsetAdjust;
            if (wrEn = '1') then
               v.tmpChannel.offsetAdjust := wrData(7 downto 0);
            end if;


         when X"14" =>                  -- output_mode
            v.rdData(6) := r.global.outputLvds;
            v.rdData(2) := r.global.outputInvert;
            v.rdData(0) := r.global.binFormat;
            if (wrEn = '1') then
               v.tmpGlobal.outputLvds   := wrData(6);
               v.tmpGlobal.outputInvert := wrData(2);
               v.tmpGlobal.binFormat    := wrData(0);
            end if;

         when X"15" =>                  -- output_adjust
            -- Not sure if this is global
            v.rdData(5 downto 4) := r.global.termination;
            v.rdData(0)          := r.global.driveStrength;
            if (wrEn = '1') then
               v.tmpGlobal.termination   := wrData(5 downto 4);
               v.tmpGlobal.driveStrength := wrData(0);
            end if;

         when X"16" =>                  -- output_phase
            v.rdData(6 downto 4) := activeChannel.inputPhase;
            v.rdData(3 downto 0) := activeChannel.outputPhase;
            if (wrEn = '1') then
               v.tmpChannel.inputPhase  := wrData(6 downto 4);
               v.tmpChannel.outputPhase := wrData(3 downto 0);
            end if;

         when X"18" =>
            v.rdData(2 downto 0) := r.global.digitalFsAdj;
            if (wrEn = '1') then
               v.tmpGlobal.digitalFsAdj := wrData(2 downto 0);
            end if;


         when X"19" =>                  -- user_patt1_lsb
            v.rdData(7 downto 0) := activeChannel.userPattern1(7 downto 0);
            if (wrEn = '1') then
               v.tmpChannel.userPattern1(7 downto 0) := wrData(7 downto 0);
            end if;

         when X"1A" =>                  -- user_patt1_msb
            v.rdData(7 downto 0) := activeChannel.userPattern1(15 downto 8);
            if (wrEn = '1') then
               v.tmpChannel.userPattern1(15 downto 8) := wrData(7 downto 0);
            end if;

         when X"1B" =>                  -- user_patt2_lsb
            v.rdData(7 downto 0) := activeChannel.userPattern2(7 downto 0);
            if (wrEn = '1') then
               v.tmpChannel.userPattern2(7 downto 0) := wrData(7 downto 0);
            end if;

         when X"1C" =>                  -- user_patt2_msb
            v.rdData(7 downto 0) := activeChannel.userPattern2(15 downto 8);
            if (wrEn = '1') then
               v.tmpChannel.userPattern2(15 downto 8) := wrData(7 downto 0);
            end if;

         when X"21" =>                  -- serial_control
            v.rdData(7)          := r.global.lsbFirst;
            v.rdData(6 downto 4) := r.global.outputMode;
            v.rdData(3)          := r.global.pllLowRateMode;
            v.rdData(2)          := r.global.sel2xFrame;
            v.rdData(1 downto 0) := r.global.bits;
            if (wrEn = '1') then
               v.tmpGlobal.lsbFirst       := wrData(7);
               v.tmpGlobal.outputMode     := wrData(6 downto 4);
               v.tmpGlobal.pllLowRateMode := wrData(3);
               v.tmpGlobal.sel2xFrame     := wrData(2);
               v.tmpGlobal.bits           := wrData(1 downto 0);
            end if;

         when X"22" =>                  -- serial_ch_stat
            v.rdData(1) := activeChannel.outputReset;
            v.rdData(0) := activeChannel.powerDown;
            if (wrEn = '1') then
               v.tmpChannel.outputReset := wrData(1);
               v.tmpChannel.powerDown   := wrData(0);
            end if;

         when others =>
            v.rdData := (others => '1');

      end case;

      ----------------------------------------------------------------------------------------------
      -- ADC Sampling
      ----------------------------------------------------------------------------------------------
      v.word := not r.word;
      for i in 7 downto 0 loop
         if (r.channel(i).powerDown = '0') then
            case (r.channel(i).outputTestMode) is
               when "0000" =>           -- normal
                  v.sample(i) := adcConversion(r.vinDelay(15)(i), -1.0, 1.0, 14, toBoolean(r.global.binFormat)) & "00";

                  -- Emulate chip behavior at -1
                  if (r.vinDelay(15)(i) >= 1.0 or r.vinDelay(15)(i) <= -1.0) then
                     v.sample(i) := X"8000";
                  end if;
               when "0001" =>           -- midscale short
                  v.sample(i) := "1000000000000000";
               when "0010" =>           -- +FS short
                  v.sample(i) := "1111111111111100";
               when "0011" =>           -- -FS short
                  v.sample(i) := "0000000000000000";
               when "0100" =>           -- checkerboard
                  v.sample(i) := ite(r.word = '0', "1010101010101000", "0101010101010100");
               when "0101" =>           -- pn23 (not implemented)
                  v.sample(i) := (others => '0');  --(scrambler(zero, r.pn23, PN_LONG_TAPS_C, v.pn23, v.sample(i));
               when "0110" =>           -- pn9 (not implemented)
                  v.sample(i) := (others => '0');  --scrambler(zero, r.pn9, PN_SHORT_TAPS_C, v.pn9, v.sample(i));
               when "0111" =>           -- one/zero toggle
                  v.sample(i) := ite(r.word = '0', "1111111111111100", "0000000000000000");
               when "1000" =>           -- user input
                  v.sample(i) := ite(r.word = '0', r.channel(i).userPattern1, r.channel(i).userPattern2);
               when "1001" =>           -- 1/0 bit toggle
                  v.sample(i) := "1010101010101000";
               when "1010" =>           -- 1x sync
                  v.sample(i) := "0000000111111100";
               when "1011" =>           -- one bit high
                  v.sample(i) := "1000000000000000";
               when "1100" =>           -- mixed bit frequency
                  v.sample(i) := "1010000110011100";
               when others =>
                  v.sample(i) := (others => '0');
            end case;

         else
            v.sample(i) := (others => '0');
         end if;
      end loop;

      rin <= v;

   end process comb;

   seq : process (fClk) is
   begin
      if (rising_edge(fClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -------------------------------------------------------------------------------------------------
   -- Output
   -------------------------------------------------------------------------------------------------
   BYTE_GEN : for i in 1 downto 0 generate
      DATA_SERIALIZER_GEN : for ch in 7 downto 0 generate
         Ad9681Serializer_1 : entity surf.Ad9681Serializer
            port map (
               clk    => dClk,
               clkDiv => fClk,
               rst    => rst,
               iData  => r.sample(ch)(i*8+7 downto i*8),
               oData  => serData(i)(ch));

         DATA_OUT_BUFF : OBUFDS
            port map (
               I  => serData(i)(ch),
               O  => dP(i)(ch),
               OB => dN(i)(ch));
      end generate DATA_SERIALIZER_GEN;


      FCLK_OUT_BUFF : entity surf.ClkOutBufDiff
         port map (
            clkIn   => fco,
            clkOutP => fcoP(i),
            clkOutN => fcoN(i));

      DCLK_OUT_BUFF : entity surf.ClkOutBufDiff
         port map (
            clkIn   => dco,
            clkOutP => dcoP(i),
            clkOutN => dcoN(i));
   end generate;


end architecture behavioral;
