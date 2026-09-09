-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Primitive-free AD9249 output-bank simulation core
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

entity Ad9249SimCore is
   generic (
      TPD_G : time := 1 ns);
   port (
      sampleClk    : in  sl;
      sampleRst    : in  sl;
      sampleEnable : in  sl;
      normalData   : in  Slv16Array(7 downto 0);
      cfgWrEn      : in  sl;
      cfgAddr      : in  slv(8 downto 0);
      cfgWrData    : in  slv(7 downto 0);
      cfgRdData    : out slv(7 downto 0);
      sampleData   : out Slv16Array(7 downto 0);
      sampleValid  : out sl);
end entity Ad9249SimCore;

architecture rtl of Ad9249SimCore is

   constant PN9_SEED_C  : slv(8 downto 0)  := "011011111";
   constant PN23_SEED_C : slv(22 downto 0) := "01001101110000000101000";

   constant SPI_CONFIG_ADDR_C      : slv(8 downto 0) := '0' & X"00";
   constant CHIP_ID_ADDR_C         : slv(8 downto 0) := '0' & X"01";
   constant CHIP_GRADE_ADDR_C      : slv(8 downto 0) := '0' & X"02";
   constant DEVICE_INDEX2_ADDR_C   : slv(8 downto 0) := '0' & X"04";
   constant DEVICE_INDEX1_ADDR_C   : slv(8 downto 0) := '0' & X"05";
   constant POWER_MODE_ADDR_C      : slv(8 downto 0) := '0' & X"08";
   constant TEST_MODE_ADDR_C       : slv(8 downto 0) := '0' & X"0D";
   constant OUTPUT_MODE_ADDR_C     : slv(8 downto 0) := '0' & X"14";
   constant OUTPUT_PHASE_ADDR_C    : slv(8 downto 0) := '0' & X"16";
   constant USER_PATTERN1_LSB_C    : slv(8 downto 0) := '0' & X"19";
   constant USER_PATTERN1_MSB_C    : slv(8 downto 0) := '0' & X"1A";
   constant USER_PATTERN2_LSB_C    : slv(8 downto 0) := '0' & X"1B";
   constant USER_PATTERN2_MSB_C    : slv(8 downto 0) := '0' & X"1C";
   constant SERIAL_OUTPUT_ADDR_C   : slv(8 downto 0) := '0' & X"21";
   constant CHANNEL_STATUS_ADDR_C  : slv(8 downto 0) := '0' & X"22";
   constant TRANSFER_ADDR_C        : slv(8 downto 0) := '0' & X"FF";
   constant RESOLUTION_RATE_ADDR_C : slv(8 downto 0) := '1' & X"00";

   type ChannelType is record
      testMode     : slv(3 downto 0);
      userMode     : slv(1 downto 0);
      userPatternA : slv(13 downto 0);
      userPatternB : slv(13 downto 0);
      outputPhase  : slv(3 downto 0);
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
      outputPhase  => "0011",
      outputReset  => '0',
      powerDown    => '0',
      resetPn9     => '0',
      resetPn23    => '0',
      pn9           => PN9_SEED_C,
      pn23          => PN23_SEED_C);

   type ChannelArray is array (natural range <>) of ChannelType;

   type RegType is record
      rdData       : slv(7 downto 0);
      selectMask   : slv(9 downto 0);
      channel      : ChannelArray(7 downto 0);
      outputInvert : sl;
      outputFormat : sl;
      lsbFirst     : sl;
      powerMode    : slv(2 downto 0);
      resolution   : slv(6 downto 0);
      tmpResolution : slv(6 downto 0);
      toggle       : sl;
      data         : Slv16Array(7 downto 0);
      valid        : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      rdData       => (others => '0'),
      selectMask   => (others => '1'),
      channel      => (others => CHANNEL_INIT_C),
      outputInvert => '0',
      outputFormat => '0',
      lsbFirst     => '0',
      powerMode    => "000",
      resolution   => (others => '0'),
      tmpResolution => (others => '0'),
      toggle       => '0',
      data         => (others => (others => '0')),
      valid        => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   -------------------------------------------------------------------------------------------------
   -- AD9249 writes take effect immediately except for the resolution/sample-rate
   -- override at 0x100. The model represents one independently selected output
   -- bank; a full device uses two instances.
   -------------------------------------------------------------------------------------------------
   comb : process (cfgAddr, cfgWrData, cfgWrEn, normalData, r, sampleEnable, sampleRst) is
      variable active : ChannelType;
      variable v      : RegType;
      variable word   : slv(13 downto 0);
   begin
      v       := r;
      v.valid := '0';

      if (sampleRst = '1') then
         v := REG_INIT_C;
      else
         if (cfgWrEn = '1') then
            case cfgAddr is
               when SPI_CONFIG_ADDR_C =>
                  if (cfgWrData(5) = '1' or cfgWrData(2) = '1') then
                     v := REG_INIT_C;
                  end if;
               when DEVICE_INDEX2_ADDR_C =>
                  v.selectMask(7 downto 4) := cfgWrData(3 downto 0);
               when DEVICE_INDEX1_ADDR_C =>
                  v.selectMask(3 downto 0) := cfgWrData(3 downto 0);
                  v.selectMask(9 downto 8) := cfgWrData(5 downto 4);
               when POWER_MODE_ADDR_C =>
                  v.powerMode := cfgWrData(2 downto 0);
               when TEST_MODE_ADDR_C =>
                  for i in 7 downto 0 loop
                     if (r.selectMask(i) = '1') then
                        v.channel(i).userMode  := cfgWrData(7 downto 6);
                        v.channel(i).resetPn23 := cfgWrData(5);
                        v.channel(i).resetPn9  := cfgWrData(4);
                        v.channel(i).testMode  := cfgWrData(3 downto 0);
                        if (cfgWrData(4) = '1') then
                           v.channel(i).pn9 := PN9_SEED_C;
                        end if;
                        if (cfgWrData(5) = '1') then
                           v.channel(i).pn23 := PN23_SEED_C;
                        end if;
                     end if;
                  end loop;
               when OUTPUT_MODE_ADDR_C =>
                  v.outputInvert := cfgWrData(2);
                  v.outputFormat := cfgWrData(0);
               when OUTPUT_PHASE_ADDR_C =>
                  for i in 7 downto 0 loop
                     if (r.selectMask(i) = '1') then
                        v.channel(i).outputPhase := cfgWrData(3 downto 0);
                     end if;
                  end loop;
               when USER_PATTERN1_LSB_C =>
                  for i in 7 downto 0 loop
                     if (r.selectMask(i) = '1') then
                        v.channel(i).userPatternA(7 downto 0) := cfgWrData;
                     end if;
                  end loop;
               when USER_PATTERN1_MSB_C =>
                  for i in 7 downto 0 loop
                     if (r.selectMask(i) = '1') then
                        v.channel(i).userPatternA(13 downto 8) := cfgWrData(5 downto 0);
                     end if;
                  end loop;
               when USER_PATTERN2_LSB_C =>
                  for i in 7 downto 0 loop
                     if (r.selectMask(i) = '1') then
                        v.channel(i).userPatternB(7 downto 0) := cfgWrData;
                     end if;
                  end loop;
               when USER_PATTERN2_MSB_C =>
                  for i in 7 downto 0 loop
                     if (r.selectMask(i) = '1') then
                        v.channel(i).userPatternB(13 downto 8) := cfgWrData(5 downto 0);
                     end if;
                  end loop;
               when SERIAL_OUTPUT_ADDR_C =>
                  assert cfgWrData(2 downto 0) = "000"
                     report "Ad9249SimCore supports only 14-bit serial output"
                     severity failure;
                  v.lsbFirst := cfgWrData(7);
               when CHANNEL_STATUS_ADDR_C =>
                  for i in 7 downto 0 loop
                     if (r.selectMask(i) = '1') then
                        v.channel(i).outputReset := cfgWrData(1);
                        v.channel(i).powerDown   := cfgWrData(0);
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
                     word := normalData(i)(13 downto 0);
                     if (r.outputFormat = '1') then
                        word(13) := not word(13);
                     end if;
                  when "0001" => word := "10000000000000";
                  when "0010" => word := (others => '1');
                  when "0011" => word := (others => '0');
                  when "0100" =>
                     for j in 13 downto 0 loop
                        word(j) := ite((j mod 2) = 0, r.toggle, not r.toggle);
                     end loop;
                  when "0101" =>
                     word := adcDdrPn23Word(r.channel(i).pn23, 14);
                     if (r.channel(i).resetPn23 = '1') then
                        v.channel(i).pn23 := PN23_SEED_C;
                     else
                        v.channel(i).pn23 := adcDdrPn23Advance(r.channel(i).pn23, 14);
                     end if;
                  when "0110" =>
                     word := adcDdrPn9Word(r.channel(i).pn9, 14);
                     if (r.channel(i).resetPn9 = '1') then
                        v.channel(i).pn9 := PN9_SEED_C;
                     else
                        v.channel(i).pn9 := adcDdrPn9Advance(r.channel(i).pn9, 14);
                     end if;
                  when "0111" => word := (others => r.toggle);
                  when "1000" => word := ite(r.toggle = '0', r.channel(i).userPatternA,
                                              r.channel(i).userPatternB);
                  when "1001" => word := "10101010101010";
                  when "1010" => word := "00000001111111";
                  when "1011" => word := "10000000000000";
                  when "1100" => word := "10100001100111";
                  when others => word := (others => '0');
               end case;
               if (r.outputInvert = '1') then
                  word := not word;
               end if;
               if (r.lsbFirst = '1') then
                  word := bitReverse(word);
               end if;
               if (r.powerMode /= "000" or r.channel(i).powerDown = '1' or
                   r.channel(i).outputReset = '1') then
                  word := (others => '0');
               end if;
               v.data(i) := "00" & word;
            end loop;
         end if;
      end if;

      -- Local-register reads return the lowest-numbered selected channel. This
      -- is Channel A when the default mask selects all channels.
      active := r.channel(0);
      for i in 7 downto 0 loop
         if (r.selectMask(i) = '1') then
            active := r.channel(i);
         end if;
      end loop;
      v.rdData := (others => '0');
      case cfgAddr is
         when SPI_CONFIG_ADDR_C => v.rdData := "00011000";
         when CHIP_ID_ADDR_C => v.rdData := X"92";
         when CHIP_GRADE_ADDR_C => v.rdData := X"30";
         when DEVICE_INDEX2_ADDR_C => v.rdData(3 downto 0) := r.selectMask(7 downto 4);
         when DEVICE_INDEX1_ADDR_C => v.rdData(5 downto 0) := r.selectMask(9 downto 8) & r.selectMask(3 downto 0);
         when POWER_MODE_ADDR_C => v.rdData(2 downto 0) := r.powerMode;
         when TEST_MODE_ADDR_C => v.rdData := active.userMode & active.resetPn23 & active.resetPn9 & active.testMode;
         when OUTPUT_MODE_ADDR_C =>
            v.rdData(2) := r.outputInvert;
            v.rdData(0) := r.outputFormat;
         when OUTPUT_PHASE_ADDR_C => v.rdData(3 downto 0) := active.outputPhase;
         when USER_PATTERN1_LSB_C => v.rdData := active.userPatternA(7 downto 0);
         when USER_PATTERN1_MSB_C => v.rdData(5 downto 0) := active.userPatternA(13 downto 8);
         when USER_PATTERN2_LSB_C => v.rdData := active.userPatternB(7 downto 0);
         when USER_PATTERN2_MSB_C => v.rdData(5 downto 0) := active.userPatternB(13 downto 8);
         when SERIAL_OUTPUT_ADDR_C => v.rdData(7) := r.lsbFirst;
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
