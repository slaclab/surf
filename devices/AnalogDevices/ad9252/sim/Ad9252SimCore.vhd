-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Primitive-free AD9252 register and digital output model
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

entity Ad9252SimCore is
   generic (
      TPD_G : time := 1 ns);
   port (
      sampleClk    : in  sl;
      sampleRst    : in  sl;
      sampleEnable : in  sl;
      normalData   : in  Slv16Array(7 downto 0);
      cfgWrEn      : in  sl;
      cfgAddr      : in  slv(7 downto 0);
      cfgWrData    : in  slv(7 downto 0);
      cfgRdData    : out slv(7 downto 0);
      sampleData   : out Slv16Array(7 downto 0);
      sampleValid  : out sl);
end entity Ad9252SimCore;

architecture rtl of Ad9252SimCore is

   constant PN9_SEED_C  : slv(8 downto 0)  := "011011111";
   constant PN23_SEED_C : slv(22 downto 0) := "01001101110000000101000";

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
      staged       : ChannelType;
      channel      : ChannelArray(7 downto 0);
      outputInvert : sl;
      stagedInvert : sl;
      lsbFirst     : sl;
      stagedLsb    : sl;
      toggle       : sl;
      data         : Slv16Array(7 downto 0);
      valid        : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      rdData       => (others => '0'),
      selectMask   => (others => '0'),
      staged       => CHANNEL_INIT_C,
      channel      => (others => CHANNEL_INIT_C),
      outputInvert => '0',
      stagedInvert => '0',
      lsbFirst     => '0',
      stagedLsb    => '0',
      toggle       => '0',
      data         => (others => (others => '0')),
      valid        => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   -------------------------------------------------------------------------------------------------
   -- Configuration writes and sample generation share sampleClk in this
   -- logical model. Register writes update staging state; only device-update
   -- register 0xFF publishes buffered settings to selected channels.
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
         -------------------------------------------------------------------------------------------
         -- AD9252 SPI-register behavior represented as a byte write port.
         -- Device-index writes take effect immediately. Functional settings
         -- are staged, matching the device's transfer/update requirement.
         -------------------------------------------------------------------------------------------
         if (cfgWrEn = '1') then
            case cfgAddr is
               when X"00" =>
                  if (cfgWrData(5) = '1' or cfgWrData(2) = '1') then
                     v := REG_INIT_C;
                  end if;
               when X"04" =>
                  v.selectMask(7 downto 4) := cfgWrData(3 downto 0);
               when X"05" =>
                  v.selectMask(3 downto 0) := cfgWrData(3 downto 0);
                  v.selectMask(9 downto 8) := cfgWrData(5 downto 4);
               when X"0D" =>
                  v.staged.userMode  := cfgWrData(7 downto 6);
                  v.staged.resetPn23 := cfgWrData(5);
                  v.staged.resetPn9  := cfgWrData(4);
                  v.staged.testMode  := cfgWrData(3 downto 0);
               when X"14" =>
                  v.stagedInvert := cfgWrData(2);
               when X"16" =>
                  v.staged.outputPhase := cfgWrData(3 downto 0);
               when X"19" =>
                  v.staged.userPatternA(7 downto 0) := cfgWrData;
               when X"1A" =>
                  v.staged.userPatternA(13 downto 8) := cfgWrData(5 downto 0);
               when X"1B" =>
                  v.staged.userPatternB(7 downto 0) := cfgWrData;
               when X"1C" =>
                  v.staged.userPatternB(13 downto 8) := cfgWrData(5 downto 0);
               when X"21" =>
                  assert cfgWrData(2 downto 0) = "000"
                     report "Ad9252SimCore supports only 14-bit serial output"
                     severity failure;
                  v.stagedLsb := cfgWrData(7);
               when X"22" =>
                  v.staged.outputReset := cfgWrData(1);
                  v.staged.powerDown   := cfgWrData(0);
               when X"FF" =>
                  -- Atomically publish global settings and the staged
                  -- channel image to every channel selected by 0x04/0x05.
                  if (cfgWrData(0) = '1') then
                     v.outputInvert := r.stagedInvert;
                     v.lsbFirst     := r.stagedLsb;
                     for i in 7 downto 0 loop
                        if (r.selectMask(i) = '1') then
                           v.channel(i) := r.staged;
                           -- Preserve live PN state across ordinary
                           -- transfers. An asserted reset instead installs
                           -- and holds the documented seed value.
                           v.channel(i).pn9  := r.channel(i).pn9;
                           v.channel(i).pn23 := r.channel(i).pn23;
                           if (r.staged.resetPn9 = '1') then
                              v.channel(i).pn9 := PN9_SEED_C;
                           end if;
                           if (r.staged.resetPn23 = '1') then
                              v.channel(i).pn23 := PN23_SEED_C;
                           end if;
                        end if;
                     end loop;
                  end if;
               when others => null;
            end case;
         end if;

         -------------------------------------------------------------------------------------------
         -- Generate one parallel ADC word per enabled sample. Pattern state
         -- advances independently per channel, then global inversion/bit
         -- order and per-channel suppression are applied in pin-data order.
         -------------------------------------------------------------------------------------------
         if (sampleEnable = '1') then
            v.toggle := not r.toggle;
            v.valid  := '1';
            for i in 7 downto 0 loop
               case r.channel(i).testMode is
                  when "0000" => word := normalData(i)(13 downto 0);
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
               if (r.channel(i).powerDown = '1' or r.channel(i).outputReset = '1') then
                  word := (others => '0');
               end if;
               v.data(i) := "00" & word;
            end loop;
         end if;
      end if;

      -- Local-register reads return the lowest-numbered selected channel. This
      -- is Channel A when all channels are selected.
      active := r.channel(0);
      for i in 7 downto 0 loop
         if (r.selectMask(i) = '1') then
            active := r.channel(i);
         end if;
      end loop;
      v.rdData := (others => '0');
      case cfgAddr is
         when X"00" => v.rdData := "00011000";
         when X"01" => v.rdData := X"09";
         when X"02" => v.rdData := X"30";
         when X"04" => v.rdData(3 downto 0) := r.selectMask(7 downto 4);
         when X"05" => v.rdData(5 downto 0) := r.selectMask(9 downto 8) & r.selectMask(3 downto 0);
         when X"0D" => v.rdData := active.userMode & active.resetPn23 & active.resetPn9 & active.testMode;
         when X"14" => v.rdData(2) := r.outputInvert;
         when X"16" => v.rdData(3 downto 0) := active.outputPhase;
         when X"19" => v.rdData := active.userPatternA(7 downto 0);
         when X"1A" => v.rdData(5 downto 0) := active.userPatternA(13 downto 8);
         when X"1B" => v.rdData := active.userPatternB(7 downto 0);
         when X"1C" => v.rdData(5 downto 0) := active.userPatternB(13 downto 8);
         when X"21" => v.rdData(7) := r.lsbFirst;
         when X"22" => v.rdData(1 downto 0) := active.outputReset & active.powerDown;
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
