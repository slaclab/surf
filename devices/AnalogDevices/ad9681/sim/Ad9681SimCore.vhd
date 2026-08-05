-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Primitive-free AD9681 digital output model
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
use surf.AdcDdrPatternPkg.all;

entity Ad9681SimCore is
   generic (
      TPD_G : time := 1 ns);
   port (
      sampleClk    : in  sl;
      sampleRst    : in  sl;
      sampleEnable : in  sl;
      normalData   : in  Slv16Array(7 downto 0);
      cfgBank      : in  sl;
      cfgWrEn      : in  sl;
      cfgAddr      : in  slv(8 downto 0);
      cfgWrData    : in  slv(7 downto 0);
      cfgRdData    : out slv(7 downto 0);
      sampleData   : out Slv16Array(7 downto 0);
      sampleValid  : out sl);
end entity Ad9681SimCore;

architecture rtl of Ad9681SimCore is

   constant PN9_SEED_C  : slv(8 downto 0)  := "011011111";
   constant PN23_SEED_C : slv(22 downto 0) := "01001101110000000101000";

   constant SPI_CONFIG_ADDR_C      : slv(8 downto 0) := '0' & X"00";
   constant CHIP_ID_ADDR_C         : slv(8 downto 0) := '0' & X"01";
   constant CHIP_GRADE_ADDR_C      : slv(8 downto 0) := '0' & X"02";
   constant DEVICE_INDEX_ADDR_C    : slv(8 downto 0) := '0' & X"05";
   constant POWER_MODE_ADDR_C      : slv(8 downto 0) := '0' & X"08";
   constant TEST_MODE_ADDR_C       : slv(8 downto 0) := '0' & X"0D";
   constant OUTPUT_MODE_ADDR_C     : slv(8 downto 0) := '0' & X"14";
   constant USER_PATTERN1_LSB_C    : slv(8 downto 0) := '0' & X"19";
   constant USER_PATTERN1_MSB_C    : slv(8 downto 0) := '0' & X"1A";
   constant USER_PATTERN2_LSB_C    : slv(8 downto 0) := '0' & X"1B";
   constant USER_PATTERN2_MSB_C    : slv(8 downto 0) := '0' & X"1C";
   constant SERIAL_OUTPUT_ADDR_C   : slv(8 downto 0) := '0' & X"21";
   constant CHANNEL_STATUS_ADDR_C  : slv(8 downto 0) := '0' & X"22";
   constant TRANSFER_ADDR_C        : slv(8 downto 0) := '0' & X"FF";
   constant RESOLUTION_RATE_ADDR_C : slv(8 downto 0) := '1' & X"00";

   type GlobalType is record
      powerMode    : slv(2 downto 0);
      outputInvert : sl;
      outputFormat : sl;
      lsbFirst     : sl;
      outputMode   : slv(2 downto 0);
      select2x     : sl;
      outputBits   : slv(1 downto 0);
   end record GlobalType;

   constant GLOBAL_INIT_C : GlobalType := (
      powerMode    => "000",
      outputInvert => '0',
      outputFormat => '0',
      lsbFirst     => '0',
      outputMode   => "011",
      select2x     => '0',
      outputBits   => "00");

   type ChannelType is record
      testMode     : slv(3 downto 0);
      userMode     : slv(1 downto 0);
      userPatternA : slv(15 downto 0);
      userPatternB : slv(15 downto 0);
      outputReset  : sl;
      powerDown    : sl;
      resetPn9     : sl;
      resetPn23    : sl;
      pn9           : slv(8 downto 0);
      pn23          : slv(22 downto 0);
   end record ChannelType;

   constant CHANNEL_INIT_C : ChannelType := (
      testMode     => "0000",
      userMode     => "00",
      userPatternA => (others => '0'),
      userPatternB => (others => '0'),
      outputReset  => '0',
      powerDown    => '0',
      resetPn9     => '0',
      resetPn23    => '0',
      pn9           => PN9_SEED_C,
      pn23          => PN23_SEED_C);

   type ChannelArray is array (natural range <>) of ChannelType;
   type SelectArray is array (natural range <>) of slv(3 downto 0);

   type RegType is record
      rdData        : slv(7 downto 0);
      selectMask   : SelectArray(1 downto 0);
      global       : GlobalType;
      channel      : ChannelArray(7 downto 0);
      resolution   : slv(6 downto 0);
      tmpResolution : slv(6 downto 0);
      toggle       : sl;
      data         : Slv16Array(7 downto 0);
      valid        : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      rdData        => (others => '0'),
      selectMask   => (others => (others => '1')),
      global       => GLOBAL_INIT_C,
      channel      => (others => CHANNEL_INIT_C),
      resolution   => (others => '0'),
      tmpResolution => (others => '0'),
      toggle       => '0',
      data         => (others => (others => '0')),
      valid        => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   -------------------------------------------------------------------------------------------------
   -- Each configuration bank owns four channels. AD9681 writes take effect
   -- immediately except for the resolution/sample-rate override at 0x100.
   -------------------------------------------------------------------------------------------------
   comb : process (cfgAddr, cfgBank, cfgWrData, cfgWrEn, normalData, r, sampleEnable, sampleRst) is
      variable active    : ChannelType;
      variable bankBase  : natural range 0 to 4;
      variable bankIndex : natural range 0 to 1;
      variable v         : RegType;
      variable word      : slv(15 downto 0);
      variable code      : slv(13 downto 0);
   begin
      v         := r;
      v.valid   := '0';
      bankBase  := ite(cfgBank = '1', 4, 0);
      bankIndex := ite(cfgBank = '1', 1, 0);

      if (sampleRst = '1') then
         v := REG_INIT_C;
      else
         if (cfgWrEn = '1') then
            case cfgAddr is
               when SPI_CONFIG_ADDR_C =>
                  if (cfgWrData(5) = '1' or cfgWrData(2) = '1') then
                     v := REG_INIT_C;
                  end if;
               when DEVICE_INDEX_ADDR_C =>
                  v.selectMask(bankIndex) := cfgWrData(3 downto 0);
               when POWER_MODE_ADDR_C =>
                  v.global.powerMode(1 downto 0) := cfgWrData(1 downto 0);
                  v.global.powerMode(2)          := cfgWrData(5);
               when TEST_MODE_ADDR_C =>
                  for i in 3 downto 0 loop
                     if (r.selectMask(bankIndex)(i) = '1') then
                        v.channel(bankBase+i).userMode  := cfgWrData(7 downto 6);
                        v.channel(bankBase+i).resetPn23 := cfgWrData(5);
                        v.channel(bankBase+i).resetPn9  := cfgWrData(4);
                        v.channel(bankBase+i).testMode  := cfgWrData(3 downto 0);
                        if (cfgWrData(4) = '1') then
                           v.channel(bankBase+i).pn9 := PN9_SEED_C;
                        end if;
                        if (cfgWrData(5) = '1') then
                           v.channel(bankBase+i).pn23 := PN23_SEED_C;
                        end if;
                     end if;
                  end loop;
               when OUTPUT_MODE_ADDR_C =>
                  v.global.outputInvert := cfgWrData(2);
                  v.global.outputFormat := cfgWrData(0);
               when USER_PATTERN1_LSB_C | USER_PATTERN1_MSB_C |
                    USER_PATTERN2_LSB_C | USER_PATTERN2_MSB_C =>
                  for i in 3 downto 0 loop
                     if (r.selectMask(bankIndex)(i) = '1') then
                        case cfgAddr is
                           when USER_PATTERN1_LSB_C => v.channel(bankBase+i).userPatternA(7 downto 0) := cfgWrData;
                           when USER_PATTERN1_MSB_C => v.channel(bankBase+i).userPatternA(15 downto 8) := cfgWrData;
                           when USER_PATTERN2_LSB_C => v.channel(bankBase+i).userPatternB(7 downto 0) := cfgWrData;
                           when others => v.channel(bankBase+i).userPatternB(15 downto 8) := cfgWrData;
                        end case;
                     end if;
                  end loop;
               when SERIAL_OUTPUT_ADDR_C =>
                  assert cfgWrData(6 downto 4) = "011" and cfgWrData(2) = '0' and
                         cfgWrData(1 downto 0) = "00"
                     report "Ad9681SimCore does not model this output format; continuing with " &
                            "16-bit DDR two-lane bytewise output"
                     severity warning;
                  v.global.lsbFirst   := cfgWrData(7);
                  v.global.outputMode := cfgWrData(6 downto 4);
                  v.global.select2x   := cfgWrData(2);
                  v.global.outputBits := cfgWrData(1 downto 0);
               when CHANNEL_STATUS_ADDR_C =>
                  for i in 3 downto 0 loop
                     if (r.selectMask(bankIndex)(i) = '1') then
                        v.channel(bankBase+i).outputReset := cfgWrData(1);
                        v.channel(bankBase+i).powerDown   := cfgWrData(0);
                     end if;
                  end loop;
               when TRANSFER_ADDR_C =>
                  if (cfgWrData(0) = '1') then
                     v.resolution := r.tmpResolution;
                  end if;
               when RESOLUTION_RATE_ADDR_C =>
                  v.tmpResolution := cfgWrData(6 downto 0);
               when others => null;
            end case;
         end if;

         if (sampleEnable = '1') then
            v.toggle := not r.toggle;
            v.valid  := '1';
            for i in 7 downto 0 loop
               case r.channel(i).testMode is
                  when "0000" =>
                     code := normalData(i)(13 downto 0);
                     if (r.global.outputFormat = '1') then
                        code(13) := not code(13);
                     end if;
                     word := code & "00";
                  when "0001" => word := "1000000000000000";
                  when "0010" => word := "1111111111111100";
                  when "0011" => word := (others => '0');
                  when "0100" => word := ite(r.toggle = '0', "1010101010101000", "0101010101010100");
                  when "0101" =>
                     word := adcDdrPn23Word(r.channel(i).pn23, 14) & "00";
                     if (r.channel(i).resetPn23 = '1') then
                        v.channel(i).pn23 := PN23_SEED_C;
                     else
                        v.channel(i).pn23 := adcDdrPn23Advance(r.channel(i).pn23, 14);
                     end if;
                  when "0110" =>
                     word := adcDdrPn9Word(r.channel(i).pn9, 14) & "00";
                     if (r.channel(i).resetPn9 = '1') then
                        v.channel(i).pn9 := PN9_SEED_C;
                     else
                        v.channel(i).pn9 := adcDdrPn9Advance(r.channel(i).pn9, 14);
                     end if;
                  when "0111" => word := ite(r.toggle = '0', "1111111111111100", "0000000000000000");
                  when "1000" => word := ite(r.toggle = '0', r.channel(i).userPatternA,
                                              r.channel(i).userPatternB);
                  when "1001" => word := "1010101010101000";
                  when "1010" => word := "0000000111111100";
                  when "1011" => word := "1000000000000000";
                  when "1100" => word := "1010000110011100";
                  when others => word := (others => '0');
               end case;
               if (r.global.outputInvert = '1') then
                  word := not word;
               end if;
               if (r.global.lsbFirst = '1') then
                  word(15 downto 8) := bitReverse(word(15 downto 8));
                  word(7 downto 0)  := bitReverse(word(7 downto 0));
               end if;
               if (r.global.powerMode /= "000" or r.channel(i).powerDown = '1' or
                   r.channel(i).outputReset = '1') then
                  word := (others => '0');
               end if;
               v.data(i) := word;
            end loop;
         end if;
      end if;

      -- Local-register reads return the lowest-numbered selected channel. This
      -- is Channel A when the default mask selects all four channels.
      active := r.channel(bankBase);
      for i in 3 downto 0 loop
         if (r.selectMask(bankIndex)(i) = '1') then
            active := r.channel(bankBase+i);
         end if;
      end loop;
      v.rdData := (others => '0');
      case cfgAddr is
         when SPI_CONFIG_ADDR_C => v.rdData := "00011000";
         when CHIP_ID_ADDR_C => v.rdData := X"8F";
         when CHIP_GRADE_ADDR_C => v.rdData(6 downto 4) := "110";
         when DEVICE_INDEX_ADDR_C => v.rdData(3 downto 0) := r.selectMask(bankIndex);
         when POWER_MODE_ADDR_C =>
            v.rdData(1 downto 0) := r.global.powerMode(1 downto 0);
            v.rdData(5)          := r.global.powerMode(2);
         when TEST_MODE_ADDR_C => v.rdData := active.userMode & active.resetPn23 & active.resetPn9 & active.testMode;
         when OUTPUT_MODE_ADDR_C =>
            v.rdData(2) := r.global.outputInvert;
            v.rdData(0) := r.global.outputFormat;
         when USER_PATTERN1_LSB_C => v.rdData := active.userPatternA(7 downto 0);
         when USER_PATTERN1_MSB_C => v.rdData := active.userPatternA(15 downto 8);
         when USER_PATTERN2_LSB_C => v.rdData := active.userPatternB(7 downto 0);
         when USER_PATTERN2_MSB_C => v.rdData := active.userPatternB(15 downto 8);
         when SERIAL_OUTPUT_ADDR_C =>
            v.rdData(7)          := r.global.lsbFirst;
            v.rdData(6 downto 4) := r.global.outputMode;
            v.rdData(2)          := r.global.select2x;
            v.rdData(1 downto 0) := r.global.outputBits;
         when CHANNEL_STATUS_ADDR_C => v.rdData(1 downto 0) := active.outputReset & active.powerDown;
         when TRANSFER_ADDR_C => v.rdData := (others => '0');
         when RESOLUTION_RATE_ADDR_C => v.rdData(6 downto 0) := r.resolution;
         when others => v.rdData := (others => '1');
      end case;
      rin <= v;
   end process comb;

   seq : process (sampleClk) is
   begin
      if rising_edge(sampleClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   cfgRdData   <= rin.rdData;
   sampleData  <= r.data;
   sampleValid <= r.valid;

end architecture rtl;
