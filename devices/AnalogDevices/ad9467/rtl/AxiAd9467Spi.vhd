-------------------------------------------------------------------------------
-- File       : AxiAd9467Spi.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-05-23
-- Last update: 2014-09-24
-------------------------------------------------------------------------------
-- Description: AD9467 SPI Interface Module
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
use work.AxiAd9467Pkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiAd9467Spi is
   generic (
      TPD_G          : time := 1 ns;
      AXI_CLK_FREQ_G : real := 125.0E+6);
   port (
      --ADC SPI I/O ports
      adcCs     : out   sl;
      adcSck    : out   sl;
      adcSdio   : inout sl;
      -- AXI-Lite Interface
      axiClk    : in    sl;
      axiRst    : in    sl;
      adcSpiIn  : in    AxiAd9467SpiInType;
      adcSpiOut : out   AxiAd9467SpiOutType);
end AxiAd9467Spi;

architecture rtl of AxiAd9467Spi is

   constant MAX_CNT_C : natural := getTimeRatio(AXI_CLK_FREQ_G, 50.0E+6);

   type StateType is (
      IDLE_S,
      SCK_LOW_S,
      SCK_HIGH_S,
      HANDSHAKE_S);

   signal state : StateType := IDLE_S;
   signal cs,
      sck,
      sdi,
      sdo,
      inEn : sl := '0';
   signal r    : AxiAd9467SpiOutType;
   signal pntr : slv(7 downto 0)              := (others => '0');
   signal cnt  : natural range 0 to MAX_CNT_C := 0;
   
begin
   
   adcCs     <= cs;
   adcSck    <= sck;
   adcSpiOut <= r;

   IOBUF_inst : IOBUF
      port map (
         O  => sdo,                     -- Buffer output
         IO => adcSdio,                 -- Buffer inout port (connect directly to top-level port)
         I  => sdi,                     -- Buffer input
         T  => inEn);                   -- 3-state enable input, high=input, low=output        

   process(axiClk)
   begin
      if rising_edge(axiClk) then
         if axiRst = '1' then
            cs     <= '1'             after TPD_G;
            sck    <= '0'             after TPD_G;
            sdi    <= '0'             after TPD_G;
            inEn   <= '0'             after TPD_G;
            cnt    <= 0               after TPD_G;
            pntr   <= (others => '0') after TPD_G;
            r.dout <= (others => '0') after TPD_G;
            state  <= IDLE_S;
         else
            case (state) is
               ----------------------------------------------------------------------
               when IDLE_S =>
                  if AdcSpiIn.req = '1' then
                     cs     <= '0'             after TPD_G;
                     r.dout <= (others => '0') after TPD_G;
                     state  <= SCK_LOW_S       after TPD_G;
                  end if;
               ----------------------------------------------------------------------
               when SCK_LOW_S =>
                  sck <= '0' after TPD_G;
                  if pntr > 15 then
                     inEn <= AdcSpiIn.RnW                        after TPD_G;
                     sdi  <= AdcSpiIn.din(conv_integer(23-pntr)) after TPD_G;
                  elsif pntr > 3 then
                     sdi <= AdcSpiIn.addr(conv_integer(15-pntr)) after TPD_G;
                  elsif pntr = 0 then
                     sdi <= AdcSpiIn.RnW after TPD_G;
                  else
                     sdi <= '0' after TPD_G;
                  end if;
                  cnt <= cnt + 1 after TPD_G;
                  -- Min. 20 ns wait
                  if cnt = MAX_CNT_C then
                     cnt <= 0 after TPD_G;
                     if pntr > 15 then
                        r.dout(conv_integer(23-pntr)) <= sdo after TPD_G;
                     end if;
                     state <= SCK_HIGH_S after TPD_G;
                  end if;
               ----------------------------------------------------------------------
               when SCK_HIGH_S =>
                  sck <= '1'     after TPD_G;
                  cnt <= cnt + 1 after TPD_G;
                  -- Min. 20 ns wait
                  if cnt = MAX_CNT_C then
                     cnt  <= 0        after TPD_G;
                     pntr <= pntr + 1 after TPD_G;
                     if pntr = 23 then
                        cs    <= '1'             after TPD_G;
                        pntr  <= (others => '0') after TPD_G;
                        inEn  <= '0'             after TPD_G;
                        r.ack <= '1'             after TPD_G;
                        state <= HANDSHAKE_S     after TPD_G;
                     else
                        state <= SCK_LOW_S after TPD_G;
                     end if;
                  end if;
               ----------------------------------------------------------------------
               when HANDSHAKE_S =>
                  r.ack <= '1' after TPD_G;
                  if AdcSpiIn.req = '0' then
                     r.ack <= '0'    after TPD_G;
                     sck   <= '0'    after TPD_G;
                     state <= IDLE_S after TPD_G;
                  end if;
            ----------------------------------------------------------------------
            end case;
         end if;
      end if;
   end process;
   
end rtl;
