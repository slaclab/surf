-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, MGT RX Reset Control
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2MgtRxRst.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/27/2009
-------------------------------------------------------------------------------
-- Description:
-- This module contains the logic to control the reset of the RX MGT.
-------------------------------------------------------------------------------
-- Copyright (c) 2009 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 05/27/2009: created.
-- 01/13/2010: Added received init line to help linking.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.Pgp2MgtPackage.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

entity Pgp2MgtRxRst is 
   port (

      -- Clock and reset, must not be derived from MGT receive PLL
      mgtRxClk          : in  std_logic;
      mgtRxRst          : in  std_logic;

      -- RX Side is ready
      mgtRxReady        : out std_logic;
      mgtRxInit         : in  std_logic;

      -- Lock status
      mgtRxLock         : in  std_logic;

      -- PCS & PMA Reset
      mgtRxPmaReset     : out std_logic;
      mgtRxReset        : out std_logic;

      -- Buffer error
      mgtRxBuffError    : in  std_logic
   );

end Pgp2MgtRxRst;


-- Define architecture
architecture Pgp2MgtRxRst of Pgp2MgtRxRst is

   -- Local Signals
   signal rxPcsResetCnt     : std_logic_vector(3 downto 0);
   signal rxPcsResetCntRst  : std_logic;
   signal rxPcsResetCntEn   : std_logic;
   signal rxStateCnt        : std_logic_vector(13 downto 0);
   signal rxStateCntRst     : std_logic;
   signal intRxPmaReset     : std_logic;
   signal intRxReset        : std_logic;
   signal rxClockReady      : std_logic;

   -- RX Reset State Machine
   constant RX_SYSTEM_RESET : std_logic_vector(2 downto 0) := "000";
   constant RX_PMA_RESET    : std_logic_vector(2 downto 0) := "001";
   constant RX_WAIT_LOCK    : std_logic_vector(2 downto 0) := "010";
   constant RX_PCS_RESET    : std_logic_vector(2 downto 0) := "011";
   constant RX_WAIT_PCS     : std_logic_vector(2 downto 0) := "100";
   constant RX_ALMOST_READY : std_logic_vector(2 downto 0) := "101";
   constant RX_READY        : std_logic_vector(2 downto 0) := "110";
   signal   curRxState      : std_logic_vector(2 downto 0);
   signal   nxtRxState      : std_logic_vector(2 downto 0);

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   -- State Machine Synchronous Logic
   process ( mgtRxClk, mgtRxRst ) begin
      if mgtRxRst = '1' then
         curRxState    <= RX_SYSTEM_RESET after tpd;
         rxPcsResetCnt <= (others=>'0')   after tpd;
         rxStateCnt    <= (others=>'0')   after tpd;
         mgtRxPmaReset <= '1'             after tpd;
         mgtRxReset    <= '0'             after tpd;
         mgtRxReady    <= '0'             after tpd;
      elsif rising_edge(mgtRxClk) then

         -- Pass on reset signals
         mgtRxPmaReset <= intRxPmaReset after tpd;
         mgtRxReset    <= intRxReset    after tpd;

         -- Update state
         if mgtRxInit = '1' then
            curRxState <= RX_SYSTEM_RESET after tpd;
         else
            curRxState <= nxtRxState after tpd;
         end if;

         -- Rx State Counter
         if rxStateCntRst = '1' then
            rxStateCnt <= (others=>'0') after tpd;
         else
            rxStateCnt <= rxStateCnt + 1 after tpd;
         end if;

         -- RX Loop Counter
         if rxPcsResetCntRst = '1' then
            rxPcsResetCnt <= (others=>'0') after tpd;
         elsif rxPcsResetCntEn = '1' then
            rxPcsResetCnt <= rxPcsResetCnt + 1 after tpd;
         end if;

         -- Ready flag
         mgtRxReady <= rxClockReady after tpd;

      end if;
   end process;


   -- Async RX State Logic
   process ( curRxState, rxStateCnt, mgtRxLock, mgtRxBuffError, rxPcsResetCnt ) begin
      case curRxState is 

         -- System Reset State
         when RX_SYSTEM_RESET =>
            rxPcsResetCntRst <= '1';
            rxPcsResetCntEn  <= '0';
            rxStateCntRst    <= '1';
            intRxPmaReset    <= '1';
            intRxReset       <= '0';
            rxClockReady     <= '0';
            nxtRxState       <= RX_PMA_RESET;

         -- PMA Reset State
         when RX_PMA_RESET =>
            rxPcsResetCntRst <= '0';
            rxPcsResetCntEn  <= '0';
            intRxPmaReset    <= '1';
            intRxReset       <= '0';
            rxClockReady     <= '0';

            -- Wait for three clocks
            if rxStateCnt = 3 then
               nxtRxState    <= RX_WAIT_LOCK;
               rxStateCntRst <= '1';
            else
               nxtRxState    <= curRxState;
               rxStateCntRst <= '0';
            end if;

         -- Wait for RX Lock
         when RX_WAIT_LOCK =>
            rxPcsResetCntRst <= '0';
            rxPcsResetCntEn  <= '0';
            intRxPmaReset    <= '0';
            intRxReset       <= '0';
            rxStateCntRst    <= not mgtRxLock;
            rxClockReady     <= '0';

            -- Wait for rx to be locked for 16K clock cycles
            if rxStateCnt = "11111111111111" then
               nxtRxState <= RX_PCS_RESET;
            else
               nxtRxState <= curRxState;
            end if;
 
         -- Assert PCS Reset
         when RX_PCS_RESET =>
            rxPcsResetCntRst <= '0';
            rxPcsResetCntEn  <= '0';
            intRxPmaReset    <= '0';
            intRxReset       <= '1';
            rxClockReady     <= '0';

            -- Loss of Lock
            if mgtRxLock = '0' then
               nxtRxState    <= RX_WAIT_LOCK;
               rxStateCntRst <= '1';

            -- Wait for three clocks
            elsif rxStateCnt = 3 then
               nxtRxState    <= RX_WAIT_PCS;
               rxStateCntRst <= '1';
            else
               nxtRxState    <= curRxState;
               rxStateCntRst <= '0';
            end if;

         -- Wait 5 clocks after PCS reset
         when RX_WAIT_PCS =>
            rxPcsResetCntRst <= '0';
            rxPcsResetCntEn  <= '0';
            intRxPmaReset    <= '0';
            intRxReset       <= '0';
            rxClockReady     <= '0';

            -- Loss of Lock
            if mgtRxLock = '0' then
               nxtRxState    <= RX_WAIT_LOCK;
               rxStateCntRst <= '1';

            -- Wait for five clocks
            elsif rxStateCnt = 5 then
               nxtRxState    <= RX_ALMOST_READY;
               rxStateCntRst <= '1';
            else
               nxtRxState    <= curRxState;
               rxStateCntRst <= '0';
            end if;

         -- Almost Ready State
         when RX_ALMOST_READY =>
            intRxPmaReset    <= '0';
            intRxReset       <= '0';
            rxClockReady     <= '0';

            -- Loss of Lock
            if mgtRxLock = '0' then
               nxtRxState       <= RX_WAIT_LOCK;
               rxStateCntRst    <= '1';
               rxPcsResetCntEn  <= '0';
               rxPcsResetCntRst <= '0';

            -- RX Buffer Error
            elsif mgtRxBuffError = '1' then
               rxStateCntRst   <= '1';
               rxPcsResetCntEn <= '1';

               -- 16 Cycles have occured, reset PLL
               if rxPcsResetCnt = 15 then
                  nxtRxState       <= RX_PMA_RESET;
                  rxPcsResetCntRst <= '1';

               -- Go back to PCS Reset
               else
                  nxtRxState       <= RX_PCS_RESET;
                  rxPcsResetCntRst <= '0';
               end if;

            -- Wait for 64 clocks
            elsif rxStateCnt = 63 then
               nxtRxState       <= RX_READY;
               rxStateCntRst    <= '1';
               rxPcsResetCntEn  <= '0';
               rxPcsResetCntRst <= '0';
            else
               nxtRxState       <= curRxState;
               rxStateCntRst    <= '0';
               rxPcsResetCntEn  <= '0';
               rxPcsResetCntRst <= '0';
            end if;

         -- Ready State
         when RX_READY =>
            rxPcsResetCntRst <= '1';
            rxPcsResetCntEn  <= '0';
            intRxPmaReset    <= '0';
            intRxReset       <= '0';
            rxStateCntRst    <= '1';
            rxClockReady     <= '1';

            -- Loss of Lock
            if mgtRxLock = '0' then
               nxtRxState <= RX_WAIT_LOCK;

            -- Buffer error has occured
            elsif mgtRxBuffError = '1' then
               nxtRxState <= RX_PCS_RESET;
            else
               nxtRxState <= curRxState;
            end if;

         -- Just in case
         when others =>
            rxPcsResetCntRst <= '0';
            rxPcsResetCntEn  <= '0';
            intRxPmaReset    <= '0';
            intRxReset       <= '0';
            rxStateCntRst    <= '0';
            rxClockReady     <= '0';
            nxtRxState       <= RX_SYSTEM_RESET;
      end case;
   end process;

end Pgp2MgtRxRst;

