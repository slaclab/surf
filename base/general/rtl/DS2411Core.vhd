-------------------------------------------------------------------------------
-- File       : DS2411Core.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2007-12-19
-- Last update: 2015-01-14
-------------------------------------------------------------------------------
-- Description: Controller for DS2411 64-bit serial ID PROM
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

use work.StdRtlPkg.all;

entity DS2411Core is
   generic (
      TPD_G        : time             := 1 ns;
      SIMULATION_G : boolean          := false;
      SIM_OUTPUT_G : slv(63 downto 0) := x"0123456789ABCDEF";
      CLK_PERIOD_G : real             := 6.4E-9);  --units of seconds
   port (
      -- Clock & Reset Signals
      clk       : in    sl;
      rst       : in    sl;
      -- ID Prom Signals
      fdSerSdio : inout sl;
      -- Serial Number
      fdValue   : out   slv(63 downto 0);
      fdValid   : out   sl);
end DS2411Core;

architecture rtl of DS2411Core is
   type StateType is (
      ST_START,
      ST_RESET,
      ST_WAIT,
      ST_WRITE,
      ST_PAUSE,
      ST_READ,
      ST_DONE);
   signal curState,
      nxtState : StateType := ST_START;

   signal setOutLow,
      fdValidSet,
      fdSerDin,
      bitSet,
      bitCntEn : sl := '0';
   signal bitCntRst,
      timeCntRst : sl := '1';
   signal timeCnt      : slv(31 downto 0) := (others => '0');
   signal bitCnt       : slv(5 downto 0)  := (others => '0');
   signal setOutLowInv : sl;
   signal fdSerial     : slv(63 downto 0)  := (others => '0');

begin

   fdValue <= fdSerial when(fdValidSet = '1') else (others => '0');

   SIN_GEN : if (SIMULATION_G = true) generate
      fdSerSdio  <= 'Z';
      fdValid    <= '1';
      fdValidSet <= '1';
      fdSerial   <= SIM_OUTPUT_G;
   end generate;

   NORMAL_GEN : if (SIMULATION_G = false) generate

      setOutLowInv <= not setOutLow;
      FD_SER_SDIO_BUFT : IOBUF
         port map (
            I  => '0',
            O  => fdSerDin,
            IO => fdSerSdio,
            T  => setOutLowInv);

--      fdSerSdio <= '0' when(setOutLow = '1') else 'Z';
--      fdSerDin  <= fdSerSdio;

      -- Sync state logic
      process (clk, rst)
      begin
         if rst = '1' then
            fdSerial <= (others => '0') after TPD_G;
            fdValid  <= '0'             after TPD_G;
            timeCnt  <= (others => '0') after TPD_G;
            bitCnt   <= (others => '0') after TPD_G;
            curState <= ST_START        after TPD_G;
         elsif rising_edge(clk) then

            -- Shift new serial data
            if fdValidSet = '1' then
               fdValid <= '1' after TPD_G;
            end if;

            -- Bit Set Of Received Data
            if bitSet = '1' then
               fdSerial(conv_integer(bitCnt)) <= fdSerDin after TPD_G;
            end if;

            -- Bit Counter
            if bitCntRst = '1' then
               bitCnt <= (others => '0') after TPD_G;
            elsif bitCntEn = '1' then
               bitCnt <= bitCnt + 1 after TPD_G;
            end if;

            -- Time Counter
            if timeCntRst = '1' then
               timeCnt <= (others => '0') after TPD_G;
            else
               timeCnt <= timeCnt + 1 after TPD_G;
            end if;

            -- State
            curState <= nxtState after TPD_G;

         end if;
      end process;


      -- State Machine
      process (bitCnt, curState, timeCnt)
      begin

         -- State machine
         case curState is

            -- Start State
            when ST_START =>
               setOutLow  <= '0';
               fdValidSet <= '0';
               bitSet     <= '0';
               bitCntRst  <= '1';
               bitCntEn   <= '0';

               -- Wait 830us
               if timeCnt = toSlv(getTimeRatio(830.0E-6, CLK_PERIOD_G), 32) then
                  nxtState   <= ST_RESET;
                  timeCntRst <= '1';
               else
                  nxtState   <= curState;
                  timeCntRst <= '0';
               end if;

            -- Reset Link
            when ST_RESET =>
               setOutLow  <= '1';
               fdValidSet <= '0';
               bitSet     <= '0';
               bitCntRst  <= '1';
               bitCntEn   <= '0';

               -- Continue for 500us
               if timeCnt = toSlv(getTimeRatio(500.0E-6, CLK_PERIOD_G), 32) then
                  nxtState   <= ST_WAIT;
                  timeCntRst <= '1';
               else
                  nxtState   <= curState;
                  timeCntRst <= '0';
               end if;

            -- Wait after reset
            when ST_WAIT =>
               setOutLow  <= '0';
               fdValidSet <= '0';
               bitSet     <= '0';
               bitCntRst  <= '1';
               bitCntEn   <= '0';

               -- Wait 500us
               if timeCnt = toSlv(getTimeRatio(500.0E-6, CLK_PERIOD_G), 32) then
                  nxtState   <= ST_WRITE;
                  timeCntRst <= '1';
               else
                  nxtState   <= curState;
                  timeCntRst <= '0';
               end if;

            -- Write Command Bits To PROM (0x33)
            when ST_WRITE =>
               fdValidSet <= '0';
               bitSet     <= '0';

               -- Assert start pulse for 12us
               if timeCnt < toSlv(getTimeRatio(12.0E-6, CLK_PERIOD_G), 32) then
                  timeCntRst <= '0';
                  bitCntEn   <= '0';
                  bitCntRst  <= '0';
                  setOutLow  <= '1';
                  bitCntEn   <= '0';
                  nxtState   <= curState;

               -- Output write value for 52uS
               elsif timeCnt < toSlv(getTimeRatio(52.0E-6, CLK_PERIOD_G), 32) then
                  if bitCnt = 2 or bitCnt = 3 or bitCnt = 6 or bitCnt = 7 then
                     setOutLow <= '1';
                  else
                     setOutLow <= '0';
                  end if;
                  nxtState   <= curState;
                  timeCntRst <= '0';
                  bitCntRst  <= '0';
                  bitCntEn   <= '0';

               -- Recovery Time of 62.4us
               elsif timeCnt < toSlv(getTimeRatio(62.4E-6, CLK_PERIOD_G), 32) then
                  setOutLow  <= '0';
                  nxtState   <= curState;
                  timeCntRst <= '0';
                  bitCntRst  <= '0';
                  bitCntEn   <= '0';

               -- Done with bit
               else
                  timeCntRst <= '1';
                  bitCntEn   <= '1';
                  setOutLow  <= '0';

                  -- Done with write
                  if bitCnt = 7 then
                     bitCntRst <= '1';
                     nxtState  <= ST_PAUSE;
                  else
                     bitCntRst <= '0';
                     nxtState  <= curState;
                  end if;
               end if;

            -- Delay after write
            when ST_PAUSE =>
               setOutLow  <= '0';
               fdValidSet <= '0';
               bitSet     <= '0';
               bitCntRst  <= '1';
               bitCntEn   <= '0';

               -- Wait 60us
               if timeCnt = toSlv(getTimeRatio(60.0E-6, CLK_PERIOD_G), 32) then
                  nxtState   <= ST_READ;
                  timeCntRst <= '1';
               else
                  nxtState   <= curState;
                  timeCntRst <= '0';
               end if;

            -- Read Data Bits From Prom
            when ST_READ =>
               fdValidSet <= '0';

               -- Assert start pulse for 12us
               if timeCnt < toSlv(getTimeRatio(12.0E-6, CLK_PERIOD_G), 32) then
                  timeCntRst <= '0';
                  bitCntEn   <= '0';
                  bitCntRst  <= '0';
                  setOutLow  <= '1';
                  bitSet     <= '0';
                  nxtState   <= curState;

               -- Sample data at 13.1uS
               elsif timeCnt = toSlv(getTimeRatio(13.1E-6, CLK_PERIOD_G), 32) then
                  setOutLow  <= '0';
                  bitCntEn   <= '0';
                  timeCntRst <= '0';
                  bitCntRst  <= '0';
                  bitSet     <= '1';
                  nxtState   <= curState;

               -- Recovery Time of 62.4us
               elsif timeCnt < toSlv(getTimeRatio(62.4E-6, CLK_PERIOD_G), 32) then
                  setOutLow  <= '0';
                  timeCntRst <= '0';
                  bitCntEn   <= '0';
                  bitSet     <= '0';
                  bitCntRst  <= '0';
                  nxtState   <= curState;

               -- Done with bit
               else
                  setOutLow  <= '0';
                  timeCntRst <= '1';
                  bitCntEn   <= '1';
                  bitSet     <= '0';

                  -- Done with write
                  if bitCnt = 63 then
                     bitCntRst <= '1';
                     nxtState  <= ST_DONE;
                  else
                     bitCntRst <= '0';
                     nxtState  <= curState;
                  end if;
               end if;

            -- Done with read
            when ST_DONE =>
               fdValidSet <= '1';
               timeCntRst <= '1';
               bitCntRst  <= '1';
               bitCntEn   <= '0';
               setOutLow  <= '0';
               bitSet     <= '0';
               nxtState   <= curState;

            when others =>
               fdValidSet <= '0';
               timeCntRst <= '1';
               bitCntRst  <= '1';
               bitCntEn   <= '0';
               setOutLow  <= '0';
               bitSet     <= '0';
               nxtState   <= ST_START;
         end case;
      end process;
   end generate;
end rtl;
