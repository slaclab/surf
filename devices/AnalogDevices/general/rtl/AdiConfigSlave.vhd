-------------------------------------------------------------------------------
-- File       : AdiConfigSlave.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-01-14
-- Last update: 2016-11-14
-------------------------------------------------------------------------------
-- Description: An implementation of the common SPI configuration interface
-- use by many AnalogDevices chips.
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

entity AdiConfigSlave is
   
   generic (
      TPD_G : time := 1 ns);

   port (
      clk : in sl;

      sclk : in    sl;
      sdio : inout sl;
      csb  : in    sl;

      wrEn      : out sl;
      rdEn      : out sl;
      addr      : out slv(12 downto 0);
      wrData    : out slv(31 downto 0);
      byteValid : out slv(3 downto 0);
      rdData    : in  slv(31 downto 0));

end entity AdiConfigSlave;

architecture behavioral of AdiConfigSlave is

   type StateType is (
      WAIT_CSB_FALL_S,
      SHIFT_HEADER_S,
      LATCH_HEADER_S,
      WRITE_S,
      LATCH_WRITE_BYTE_S,
      READ_WAIT_S,
      LATCH_READ_BYTE_S,
      READ_S,
      WAIT_SCLK_RISE_S);

   type RegType is record
      state     : StateType;
      count     : slv(3 downto 0);
      shift     : slv(15 downto 0);
      bytes     : slv(1 downto 0);
      wrEn      : sl;
      rdEn      : sl;
      addr      : slv(12 downto 0);
      wrData    : slv(31 downto 0);
      byteValid : slv(3 downto 0);
      dataOut   : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state     => WAIT_CSB_FALL_S,
      count     => (others => '0'),
      shift     => (others => '0'),
      bytes     => (others => '0'),
      wrEn      => '0',
      rdEn      => '0',
      addr      => (others => '0'),
      wrData    => (others => '0'),
      byteValid => (others => '0'),
      dataOut   => '1');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal sdioRes  : sl;
   signal sdioSync : sl;
   signal sdioRise : sl;
   signal sdioFall : sl;
   signal sclkRes  : sl;
   signal sclkSync : sl;
   signal sclkRise : sl;
   signal sclkFall : sl;
   signal csbRes   : sl;
   signal csbSync  : sl;
   signal csbRise  : sl;
   signal csbFall  : sl;
   
begin

   sdio <= '0' when r.dataOut = '0' else 'Z';
   
   sdioRes <= to_x01z(sdio);
   sclkRes <= to_x01z(sclk);
   csbRes <= to_x01z(csb);

   SynchronizerEdge_SDIO : entity work.SynchronizerEdge
      generic map (
         TPD_G => TPD_G)
      port map (
         clk         => clk,
         rst         => '0',
         dataIn      => sdioRes,
         dataOut     => sdioSync,
         risingEdge  => sdioRise,
         fallingEdge => sdioFall);

   SynchronizerEdge_SCLK : entity work.SynchronizerEdge
      generic map (
         TPD_G => TPD_G)
      port map (
         clk         => clk,
         rst         => '0',
         dataIn      => sclkRes,
         dataOut     => sclkSync,
         risingEdge  => sclkRise,
         fallingEdge => sclkFall);

   SynchronizerEdge_CSB : entity work.SynchronizerEdge
      generic map (
         TPD_G => TPD_G)
      port map (
         clk         => clk,
         rst         => '0',
         dataIn      => csbRes,
         dataOut     => csbSync,
         risingEdge  => csbRise,
         fallingEdge => csbFall);

   comb : process (csbFall, r, rdData, sclkFall, sclkRise, sdioSync) is
      variable v : RegType;
   begin
      v         := r;
      v.wrEn    := '0';
      v.dataOut := '1';
      case (r.state) is
         when WAIT_CSB_FALL_S =>
            v.rdEn  := '0';
            v.shift := (others => '0');
            v.count := (others => '0');
            if (csbFall = '1') then
               v.state := SHIFT_HEADER_S;
            end if;

         when SHIFT_HEADER_S =>
            if (sclkRise = '1') then
               v.shift := r.shift(14 downto 0) & sdioSync;
               v.count := r.count + 1;
               if (r.count = 15) then
                  v.state := LATCH_HEADER_S;
               end if;
            end if;

         when LATCH_HEADER_S =>
            v.addr := r.shift(12 downto 0);
            case (r.shift(14 downto 13)) is
               when "00" =>
                  v.byteValid := "0001";
               when "01" =>
                  v.byteValid := "0011";
               when "10" =>
                  v.byteValid := "0111";
               when "11" =>
                  v.byteValid := "1111";  -- No support yet for streaming
               when others =>
                  v.byteValid := "0000";
            end case;
            v.bytes := r.shift(14 downto 13);

            if (r.shift(15) = '0') then
               v.state := WRITE_S;
            else
               v.state := READ_WAIT_S;
               v.rdEn  := '1';
            end if;

         when WRITE_S =>
            if (sclkRise = '1') then
               v.shift := v.shift(14 downto 0) & sdioSync;
               v.count := r.count + 1;
               if (r.count = 7) then
                  v.state := LATCH_WRITE_BYTE_S;
               end if;
            end if;

         when LATCH_WRITE_BYTE_S =>
            v.wrData(conv_integer(r.bytes)*8+7 downto conv_integer(r.bytes)*8) := r.shift(7 downto 0);

            v.count := (others => '0');
            if (r.bytes = 0) then
               v.wrEn  := '1';
               v.state := WAIT_CSB_FALL_S;
            else
               v.bytes := r.bytes - 1;
               v.state := WRITE_S;
            end if;

         when READ_WAIT_S =>
            v.dataOut := r.dataOut;
            v.state   := LATCH_READ_BYTE_S;

         when LATCH_READ_BYTE_S =>
            v.dataOut           := r.dataOut;
            v.shift(7 downto 0) := rdData(conv_integer(r.bytes)*8+7 downto conv_integer(r.bytes)*8);
            v.count             := (others => '0');
            v.state             := READ_S;

         when READ_S =>
            v.dataOut := r.dataOut;
            if (sclkFall = '1') then
               v.dataOut := v.shift(7);
               v.shift   := v.shift(14 downto 0) & '0';
               v.count   := r.count + 1;
               if (r.count = 7) then
                  v.bytes := r.bytes - 1;
                  if(r.bytes = 0) then
                     v.state := WAIT_SCLK_RISE_S;
                  else
                     v.state := LATCH_READ_BYTE_S;
                  end if;
               end if;
            end if;

         when WAIT_SCLK_RISE_S =>
            -- Hold last rd data until it has been sampled and txn is over
            v.dataOut := r.dataOut;
            if (sclkRise = '1') then
               v.state := WAIT_CSB_FALL_S;
            end if;

      end case;


      rin       <= v;
      wrData    <= r.wrData;
      wrEn      <= r.wrEn;
      rdEn      <= r.rdEn;
      addr      <= r.addr;
      byteValid <= r.byteValid;

      
   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;




end architecture behavioral;
