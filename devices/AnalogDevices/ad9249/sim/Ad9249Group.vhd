-------------------------------------------------------------------------------
-- File       : Ad9249Group.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-11-14
-- Last update: 2016-12-06
-------------------------------------------------------------------------------
-- Description: AD9249 Group Module
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.StdRtlPkg.all;
use work.TextUtilPkg.all;

library UNISIM;
use UNISIM.vcomponents.all;


entity Ad9249Group is

   generic (
      TPD_G            : time    := 1 ns;
      CLK_PERIOD_G     : time    := 24 ns;
      DIVCLK_DIVIDE_G  : integer := 1;
      CLKFBOUT_MULT_G  : integer := 49;
      CLK_DCO_DIVIDE_G : integer := 49;
      CLK_FCO_DIVIDE_G : integer := 7);

   port (
      clk : in sl;

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

end entity Ad9249Group;

architecture behavioral of Ad9249Group is

   constant CLK_PERIOD_C : real := real(CLK_PERIOD_G / 1 ns);

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
      pdwnMode          : slv(2 downto 0);
      pdwnPin           : sl;
      stabilizer        : sl;
      clockDivRatio     : slv(2 downto 0);
      outputLvds        : sl;
      outputInvert      : sl;
      binFormat         : slv(1 downto 0);
      termination       : slv(1 downto 0);
      driveStrength     : sl;
      lsbFirst          : sl;
      lowRate           : sl;
      bits              : slv(2 downto 0);
      fullScaleAdj      : slv(2 downto 0);
      sampleRate        : slv(2 downto 0);
      resolution        : slv(1 downto 0);
      resSampleOverride : sl;
   end record GlobalConfigType;

   constant GLOBAL_CONFIG_INIT_C : GlobalConfigType := (
      pdwnMode          => "000",
      pdwnPin           => '0',
      stabilizer        => '1',
      clockDivRatio     => "000",
      outputLvds        => '0',
      outputInvert      => '0',
      binFormat         => "00",
      termination       => "00",
      driveStrength     => '0',
      lsbFirst          => '0',
      lowRate           => '0',
      bits              => "000",
      fullScaleAdj      => "100",
      sampleRate        => "000",
      resolution        => "00",
      resSampleOverride => '0');

   type ChannelConfigType is record
      pn23            : slv(22 downto 0);
      resetPnLongGen  : sl;
      pn9             : slv(8 downto 0);
      resetPnShortGen : sl;
      userTestMode    : slv(1 downto 0);
      outputTestMode  : slv(3 downto 0);
      outputPhase     : slv(3 downto 0);
      userPattern1    : slv(15 downto 0);
      userPattern2    : slv(15 downto 0);
      outputReset     : sl;
      powerDown       : sl;
      chopMode        : sl;
      offsetAdjust    : slv(7 downto 0);
   end record ChannelConfigType;

   constant CHANNEL_CONFIG_INIT_C : ChannelConfigType := (
      pn23            => PN_LONG_INIT_C,
      resetPnLongGen  => '0',
      pn9             => PN_SHORT_INIT_C,
      resetPnShortGen => '0',
      userTestMode    => "00",
      outputTestMode  => "0000",
      outputPhase     => "0011",
      userPattern1    => X"0000",
      userPattern2    => X"0000",
      outputReset     => '0',
      powerDown       => '0',
      chopMode        => '0',
      offsetAdjust    => X"00");

   type ChannelConfigArray is array (natural range <>) of ChannelConfigType;

   type Slv14x8Array is array (natural range <>) of Slv14Array(7 downto 0);

   type ConfigRegType is record
      rdData          : slv(31 downto 0);
      lsbFirst        : sl;
      softReset       : sl;
      channelConfigEn : slv(9 downto 0);
      global          : GlobalConfigType;
      channel         : ChannelConfigArray(9 downto 0);
   end record ConfigRegType;

   constant CONFIG_REG_INIT_C : ConfigRegType := (
      rdData          => X"00000000",
      lsbFirst        => '0',
      softReset       => '0',
      channelConfigEn => "1111111111",
      global          => GLOBAL_CONFIG_INIT_C,
      channel         => (others => CHANNEL_CONFIG_INIT_C));

   signal r   : ConfigRegType := CONFIG_REG_INIT_C;
   signal rin : ConfigRegType;

   -------------------------------------------------------------------------------------------------

   type AdcRegType is record
      sample : Slv14x8Array(16 downto 0);  -- slv(13 downto 0);
      word   : sl;
   end record AdcRegType;

   constant ADC_REG_INIT_C : AdcRegType := (
      sample => (others => (others => (others => '0'))),
      word   => '0');

   signal adcR   : AdcRegType := ADC_REG_INIT_C;
   signal adcRin : AdcRegType;


   -------------------------------------------------------------------------------------------------
   -- Output constants and signals
   -------------------------------------------------------------------------------------------------
--   constant DCLK_PERIOD_C : time := CLK_PERIOD_G / 7.0;

   signal pllRst  : sl;
   signal locked  : sl;
   signal rst     : sl;
   signal dClk    : sl;
   signal fClk    : sl;
   signal dco     : sl;
   signal fco     : sl;
   signal serData : slv(7 downto 0);
   signal cfgClk  : sl;

begin

   U_ClkRst_1 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G => 4 ns)
      port map (
         clkP => cfgClk);               -- [out]


   -------------------------------------------------------------------------------------------------
   -- Create local clocks
   -------------------------------------------------------------------------------------------------
--   ClkRst_1 : entity work.ClkRst
--      generic map (
--         RST_HOLD_TIME_G => 50 us)
--      port map (
--         rst => pllRst);

   process is
   begin
      pllRst <= '1';
      wait for 1 us;
      wait until clk = '1';
      wait until clk = '1';
      wait until clk = '1';
      wait until clk = '1';
      pllRst <= '0';
      wait until locked = '1';
      wait until locked = '0';
   end process;



   -------------------------------------------------------------------------------------------------
   -- Use a clock manager to create the serial clock
   -- There's probably a better way but this works.
   -------------------------------------------------------------------------------------------------
   U_CtrlClockManager7 : entity work.ClockManager7
      generic map (
         TPD_G            => TPD_G,
         TYPE_G           => "MMCM",
         INPUT_BUFG_G     => false,
         FB_BUFG_G        => true,
         NUM_CLOCKS_G     => 4,
         BANDWIDTH_G      => "HIGH",
         CLKIN_PERIOD_G   => CLK_PERIOD_C,
         DIVCLK_DIVIDE_G  => DIVCLK_DIVIDE_G,
         CLKFBOUT_MULT_G  => CLKFBOUT_MULT_G,
         CLKOUT0_DIVIDE_G => CLK_FCO_DIVIDE_G,
         CLKOUT1_DIVIDE_G => CLK_DCO_DIVIDE_G,
         CLKOUT2_DIVIDE_G => CLK_DCO_DIVIDE_G,
         CLKOUT2_PHASE_G  => 90.0,
         CLKOUT3_DIVIDE_G => CLK_FCO_DIVIDE_G,
         CLKOUT3_PHASE_G  => 257.143)
      port map (
         clkIn     => clk,
         rstIn     => pllRst,
         clkOut(0) => fClk,
         clkOut(1) => dClk,
         clkOut(2) => dco,
         clkOut(3) => fco,
         locked    => locked);


   RstSync_1 : entity work.RstSync
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
   AdiConfigSlave_1 : entity work.AdiConfigSlave
      generic map (
         TPD_G => TPD_G)
      port map (
         clk       => cfgClk,
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
      case (addr(11 downto 0)) is

         when X"000" =>                 -- chip_port_config
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

         when X"001" =>                 -- chip_id
            v.rdData(7 downto 0) := X"92";

         when X"002" =>                 -- chip_grade
            v.rdData(6 downto 4) := "011";

         -------------------------------------------------------------------------------------------
         when X"004" =>                 -- device_index_2
            v.rdData(3 downto 0) := r.channelConfigEn(7 downto 4);
            if (wrEn = '1') then
               v.channelConfigEn(7 downto 4) := wrData(3 downto 0);
            end if;

         when X"005" =>                 -- device_index_1
            v.rdData(3 downto 0) := r.channelConfigEn(3 downto 0);
            v.rdData(4)          := r.channelConfigEn(8);
            v.rdData(5)          := r.channelConfigEn(9);
            if (wrEn = '1') then
               v.channelConfigEn(3 downto 0) := wrData(3 downto 0);
               v.channelConfigEn(8)          := wrData(4);
               v.channelConfigEn(9)          := wrData(5);
            end if;

         when X"0FF" =>                 -- device update
            if (wrEn = '1') then

            end if;

         -------------------------------------------------------------------------------------------
         when X"008" =>                 -- modes
            v.rdData(2 downto 0) := r.global.pdwnMode;
            v.rdData(5)          := r.global.pdwnPin;
            if (wrEn = '1') then
               v.global.pdwnMode := wrData(2 downto 0);
               v.global.pdwnPin  := wrData(5);
            end if;

         when X"009" =>                 -- clock
            v.rdData(0) := r.global.stabilizer;
            if (wrEn = '1') then
               v.global.stabilizer := wrData(0);
            end if;

         when X"00B" =>                 -- Clock Divide
            v.rdData(2 downto 0) := r.global.clockDivRatio;
            if (wrEn = '1') then
               v.global.clockDivRatio := wrData(2 downto 0);
            end if;

         when X"00C" =>                 -- Enhancement Control
            v.rdData(2) := activeChannel.chopMode;
            if (wrEn = '1') then
               for i in 9 downto 0 loop
                  if (v.channelConfigEn(i) = '1') then
                     v.channel(i).chopMode := wrData(2);
                  end if;
               end loop;
            end if;

         when X"00D" =>                 -- test_io
            v.rdData(7 downto 6) := activeChannel.userTestMode;
            v.rdData(5)          := activeChannel.resetPnLongGen;
            v.rdData(4)          := activeChannel.resetPnShortGen;
            v.rdData(3 downto 0) := activeChannel.outputTestMode;
            if (wrEn = '1') then
               for i in 9 downto 0 loop
                  if (r.channelConfigEn(i) = '1') then
                     v.channel(i).userTestMode    := wrData(7 downto 6);
                     v.channel(i).resetPnLongGen  := wrData(5);
                     v.channel(i).resetPnShortGen := wrData(4);
                     v.channel(i).outputTestMode  := wrData(3 downto 0);
                  end if;
               end loop;
            end if;

         when X"010" =>
            v.rdData(7 downto 0) := activeChannel.offsetAdjust;
            if (wrEn = '1') then
               for i in 9 downto 0 loop
                  if (r.channelConfigEn(i) = '1') then
                     v.channel(i).offsetAdjust := wrData(7 downto 0);
                  end if;
               end loop;
            end if;

         when X"014" =>                 -- output_mode
            v.rdData(6)          := r.global.outputLvds;
            v.rdData(2)          := r.global.outputInvert;
            v.rdData(1 downto 0) := r.global.binFormat;
            if (wrEn = '1') then
               v.global.outputLvds   := wrData(6);
               v.global.outputInvert := wrData(2);
               v.global.binFormat    := wrData(1 downto 0);
            end if;

         when X"015" =>                 -- output_adjust
            -- Not sure if this is global
            v.rdData(5 downto 4) := r.global.termination;
            v.rdData(0)          := r.global.driveStrength;
            if (wrEn = '1') then
               v.global.termination   := wrData(5 downto 4);
               v.global.driveStrength := wrData(0);
            end if;

         when X"016" =>                 -- output_phase
            v.rdData(3 downto 0) := activeChannel.outputPhase;
            if (wrEn = '1') then
               for i in 9 downto 0 loop
                  if (r.channelConfigEn(i) = '1') then
                     v.channel(i).outputPhase := wrData(3 downto 0);
                  end if;
               end loop;
            end if;

         when X"018" =>                 -- VREF
            v.rdData(2 downto 0) := r.global.fullScaleAdj;
            if (wrEn = '1') then
               v.global.fullScaleAdj := wrData(2 downto 0);
            end if;

         when X"019" =>                 -- user_patt1_lsb
            v.rdData(7 downto 0) := activeChannel.userPattern1(7 downto 0);
            if (wrEn = '1') then
               for i in 9 downto 0 loop
                  if (r.channelConfigEn(i) = '1') then
                     v.channel(i).userPattern1(7 downto 0) := wrData(7 downto 0);
                  end if;
               end loop;
            end if;

         when X"01A" =>                 -- user_patt1_msb
            v.rdData(7 downto 0) := activeChannel.userPattern1(15 downto 8);
            if (wrEn = '1') then
               for i in 9 downto 0 loop
                  if (r.channelConfigEn(i) = '1') then
                     v.channel(i).userPattern1(15 downto 8) := wrData(7 downto 0);
                  end if;
               end loop;
            end if;

         when X"01B" =>                 -- user_patt2_lsb
            v.rdData(7 downto 0) := activeChannel.userPattern2(7 downto 0);
            if (wrEn = '1') then
               for i in 9 downto 0 loop
                  if (r.channelConfigEn(i) = '1') then
                     v.channel(i).userPattern2(7 downto 0) := wrData(7 downto 0);
                  end if;
               end loop;
            end if;

         when X"01C" =>                 -- user_patt2_msb
            v.rdData(7 downto 0) := activeChannel.userPattern2(15 downto 8);
            if (wrEn = '1') then
               for i in 9 downto 0 loop
                  if (r.channelConfigEn(i) = '1') then
                     v.channel(i).userPattern2(15 downto 8) := wrData(7 downto 0);
                  end if;
               end loop;
            end if;

         when X"021" =>                 -- serial_control
            v.rdData(7)          := r.global.lsbFirst;
            v.rdData(3)          := r.global.lowRate;
            v.rdData(2 downto 0) := r.global.bits;
            if (wrEn = '1') then
               v.global.lsbFirst := wrData(7);
               v.global.lowRate  := wrData(3);
               v.global.bits     := wrData(2 downto 0);
            end if;

         when X"022" =>                 -- serial_ch_stat
            v.rdData(1) := activeChannel.outputReset;
            v.rdData(0) := activeChannel.powerDown;
            if (wrEn = '1') then
               for i in 9 downto 0 loop
                  if (r.channelConfigEn(i) = '1') then
                     v.channel(i).outputReset := wrData(1);
                     v.channel(i).powerDown   := wrData(0);
                  end if;
               end loop;
            end if;

         when X"100" =>
            v.rdData(2 downto 0) := r.global.sampleRate;
            v.rdData(5 downto 4) := r.global.resolution;
            v.rdData(6)          := r.global.resSampleOverride;
            if (wrEn = '1') then
               v.global.sampleRate        := wrData(2 downto 0);
               v.global.resolution        := wrData(5 downto 4);
               v.global.resSampleOverride := wrData(6);
            end if;


         when others =>
            v.rdData := (others => '1');

      end case;

      rin <= v;

   end process comb;

   seq : process (cfgClk) is
   begin
      if (rising_edge(cfgClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   adcComb : process (adcR) is
      variable v : AdcRegType := ADC_REG_INIT_C;
   begin
      v        := adcR;
      ----------------------------------------------------------------------------------------------
      -- ADC Sampling
      ----------------------------------------------------------------------------------------------
      v.word   := not adcR.word;
      v.sample := adcR.sample(15 downto 0) & adcR.sample(0);
      for i in 7 downto 0 loop
         if (r.channel(i).powerDown = '0') then
            case (r.channel(i).outputTestMode) is
               when "0000" =>           -- normal
                  v.sample(0)(i) := adcConversion(vin(i), 0.0, 2.0, 14, false);
               when "0001" =>           -- midscale short
                  v.sample(0)(i) := "10000000000000";
               when "0010" =>           -- +FS short
                  v.sample(0)(i) := "11111111111111";
               when "0011" =>           -- -FS short
                  v.sample(0)(i) := "00000000000000";
               when "0100" =>           -- checkerboard
                  v.sample(0)(i) := ite(adcR.word = '0', "10101010101010", "01010101010101");
               when "0101" =>           -- pn23 (not implemented)
                  v.sample(0)(i) := (others => '0');  --(scrambler(zero, adcR.pn23, PN_LONG_TAPS_C, v.pn23, v.sample(i));
               when "0110" =>           -- pn9 (not implemented)
                  v.sample(0)(i) := (others => '0');  --scrambler(zero, adcR.pn9, PN_SHORT_TAPS_C, v.pn9, v.sample(i));
               when "0111" =>           -- one/zero toggle
                  v.sample(0)(i) := ite(adcR.word = '0', "11111111111111", "00000000000000");
               when "1000" =>           -- user input
                  v.sample(0)(i) := ite(adcR.word = '0', r.channel(i).userPattern1(13 downto 0), r.channel(i).userPattern2(13 downto 0));
               when "1001" =>           -- 1/0 bit toggle
                  v.sample(0)(i) := "10101010101010";
               when "1010" =>           -- 1x sync
                  v.sample(0)(i) := "00000001111111";
               when "1011" =>           -- one bit high
                  v.sample(0)(i) := "10000000000000";
               when "1100" =>           -- mixed bit frequency
                  v.sample(0)(i) := "10100001100111";
               when others =>
                  v.sample(0)(i) := (others => '0');
            end case;

         else
            v.sample(0)(i) := (others => '0');
         end if;
      end loop;

      adcRin <= v;
   end process adcComb;

   adcSeq : process (fClk) is
   begin
      if (rising_edge(fClk)) then
         adcR <= adcRin after TPD_G;
      end if;
   end process adcSeq;

   -------------------------------------------------------------------------------------------------
   -- Output
   -------------------------------------------------------------------------------------------------
   DATA_SERIALIZER_GEN : for i in 7 downto 0 generate
      Ad9249Serializer_1 : entity work.Ad9249Serializer
         port map (
            clk    => dClk,
            clkDiv => fClk,
            rst    => rst,
            iData  => adcR.sample(16)(i),
            oData  => serData(i));

      DATA_OUT_BUFF : OBUFDS
         port map (
            I  => serData(i),
            O  => dP(i),
            OB => dN(i));
   end generate DATA_SERIALIZER_GEN;


   FCLK_OUT_BUFF : entity work.ClkOutBufDiff
      port map (
         clkIn   => fco,
         clkOutP => fcoP,
         clkOutN => fcoN);

   DCLK_OUT_BUFF : entity work.ClkOutBufDiff
      port map (
         clkIn   => dco,
         clkOutP => dcoP,
         clkOutN => dcoN);


end architecture behavioral;
