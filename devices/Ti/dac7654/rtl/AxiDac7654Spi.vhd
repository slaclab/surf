-------------------------------------------------------------------------------
-- File       : AxiDac7654Spi.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-05-22
-- Last update: 2016-09-20
-------------------------------------------------------------------------------
-- Description: SPI Interface Module
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
use work.AxiDac7654Pkg.all;

entity AxiDac7654Spi is
   generic (
      TPD_G          : time := 1 ns;
      AXI_CLK_FREQ_G : real := 125.0E+6);
   port (
      -- Parallel interface
      spiIn   : in  AxiDac7654SpiInType;
      spiOut  : out AxiDac7654SpiOutType;
      --DAC I/O ports
      dacCs   : out sl;
      dacSck  : out sl;
      dacSdi  : out sl;
      dacSdo  : in  sl;
      dacLoad : out sl;
      dacLdac : out sl;
      dacRst  : out sl;
      --Global Signals
      axiClk  : in  sl;
      axiRst  : in  sl);     
end AxiDac7654Spi;

architecture rtl of AxiDac7654Spi is

   constant AXI_CLK_PERIOD_C : real    := 1.0 / AXI_CLK_FREQ_G;
   constant MAX_CNT_C        : natural := getTimeRatio(166.4E-9, AXI_CLK_PERIOD_C);

   type StateType is (
      RST_S,
      IDLE_S,
      SCK_LOW_S,
      SCK_HIGH_S,
      LOAD_S,
      TLD2_WAIT_S,
      LDAC_S,
      HANDSHAKE_S);

   signal state : StateType := RST_S;
   signal ack,
      cs,
      sck,
      sdi,
      load,
      ldac,
      rst : sl := '0';
   signal ch   : slv(1 downto 0)              := (others => '0');
   signal pntr : natural range 0 to 23        := 0;
   signal cnt  : natural range 0 to MAX_CNT_C := 0;
   
begin

   dacCs      <= cs;
   dacSck     <= sck;
   dacSdi     <= sdi;
   dacLoad    <= load;
   dacLdac    <= ldac;
   dacRst     <= rst;
   spiOut.ack <= ack;

   process(axiClk)
   begin
      if rising_edge(axiClk) then
         if axiRst = '1' then
            cs    <= '1'             after TPD_G;
            sck   <= '1'             after TPD_G;
            sdi   <= '0'             after TPD_G;
            load  <= '1'             after TPD_G;
            ldac  <= '0'             after TPD_G;
            rst   <= '0'             after TPD_G;
            cnt   <= 0               after TPD_G;
            pntr  <= 0               after TPD_G;
            ch    <= (others => '0') after TPD_G;
            ack   <= '0'             after TPD_G;
            state <= RST_S           after TPD_G;
         else
            case (state) is
               ----------------------------------------------------------------------
               when RST_S =>
                  cnt <= cnt + 1 after TPD_G;
                  if cnt = getTimeRatio(19.2E-9, AXI_CLK_PERIOD_C) then   -- 19.2ns wait
                     rst   <= '1'    after TPD_G;
                     cnt   <= 0      after TPD_G;
                     state <= IDLE_S after TPD_G;
                  end if;
               ----------------------------------------------------------------------
               when IDLE_S =>
                  if spiIn.req = '1' then
                     cs    <= '0'       after TPD_G;
                     state <= SCK_LOW_S after TPD_G;
                  end if;
               ----------------------------------------------------------------------
               when SCK_LOW_S =>
                  sck <= '0' after TPD_G;
                  if pntr = 0 then
                     sdi <= ch(1) after TPD_G;
                  elsif pntr = 1 then
                     sdi <= ch(0) after TPD_G;
                  elsif pntr > 7 then
                     sdi <= spiIn.data(conv_integer(ch))(23-pntr) after TPD_G;
                  else
                     sdi <= '0' after TPD_G;
                  end if;
                  cnt <= cnt + 1 after TPD_G;
                  if cnt = getTimeRatio(32.0E-9, AXI_CLK_PERIOD_C) then   -- 32ns wait
                     cnt   <= 0          after TPD_G;
                     state <= SCK_HIGH_S after TPD_G;
                  end if;
               ----------------------------------------------------------------------
               when SCK_HIGH_S =>
                  sck <= '1'     after TPD_G;
                  cnt <= cnt + 1 after TPD_G;
                  if cnt = getTimeRatio(32.0E-9, AXI_CLK_PERIOD_C) then   -- 32ns wait
                     cnt  <= 0        after TPD_G;
                     pntr <= pntr + 1 after TPD_G;
                     if pntr = 23 then
                        cs    <= '1'         after TPD_G;
                        pntr  <= 0           after TPD_G;
                        state <= TLD2_WAIT_S after TPD_G;
                     else
                        state <= SCK_LOW_S after TPD_G;
                     end if;
                  end if;
               ----------------------------------------------------------------------
               when TLD2_WAIT_S =>  --required settling time between rising edge of SCK and falling of LOAD
                  cnt <= cnt + 1 after TPD_G;
                  if cnt = getTimeRatio(12.8E-9, AXI_CLK_PERIOD_C) then   -- 12.8ns wait
                     cnt   <= 0      after TPD_G;
                     state <= LOAD_S after TPD_G;
                  end if;
               ----------------------------------------------------------------------         
               when LOAD_S =>
                  load <= '0'     after TPD_G;
                  cnt  <= cnt + 1 after TPD_G;
                  if cnt = getTimeRatio(51.2E-9, AXI_CLK_PERIOD_C) then   -- 51.2ns wait
                     load  <= '1'    after TPD_G;
                     cnt   <= 0      after TPD_G;
                     state <= LDAC_S after TPD_G;
                  end if;
               ----------------------------------------------------------------------         
               when LDAC_S =>
                  ldac <= '1'     after TPD_G;
                  cnt  <= cnt + 1 after TPD_G;
                  if cnt = getTimeRatio(166.4E-9, AXI_CLK_PERIOD_C) then  -- 166.4 ns wait   
                     ldac <= '0'    after TPD_G;
                     cnt  <= 0      after TPD_G;
                     ch   <= ch + 1 after TPD_G;
                     if ch = 3 then
                        ch    <= (others => '0') after TPD_G;
                        ack   <= '1'             after TPD_G;
                        state <= HANDSHAKE_S     after TPD_G;
                     else
                        cs    <= '0'       after TPD_G;
                        state <= SCK_LOW_S after TPD_G;
                     end if;
                  end if;
               ----------------------------------------------------------------------
               when HANDSHAKE_S =>
                  if spiIn.req = '0' then
                     ack   <= '0'    after TPD_G;
                     state <= IDLE_S after TPD_G;
                  end if;
            ----------------------------------------------------------------------
            end case;
         end if;
      end if;
   end process;
end rtl;
