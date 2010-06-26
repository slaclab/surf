-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, MGT TX Reset Control
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2MgtTxRst.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/27/2009
-------------------------------------------------------------------------------
-- Description:
-- This module contains the logic to control the reset of the TX MGT.
-------------------------------------------------------------------------------
-- Copyright (c) 2009 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 05/27/2009: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.Pgp2MgtPackage.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

entity Pgp2MgtTxRst is port (

      -- Clock and reset, must not be derived from MGT transmit PLL
      mgtTxClk          : in  std_logic;
      mgtTxRst          : in  std_logic;

      -- TX Side is ready
      mgtTxReady        : out std_logic;

      -- Lock status
      mgtTxLock         : in  std_logic;

      -- PCS & PMA Reset
      mgtTxPmaReset     : out std_logic;
      mgtTxReset        : out std_logic;

      -- Buffer error
      mgtTxBuffError    : in  std_logic
   );

end Pgp2MgtTxRst;


-- Define architecture
architecture Pgp2MgtTxRst of Pgp2MgtTxRst is

   -- Local Signals
   signal txPcsResetCnt     : std_logic_vector(3 downto 0);
   signal txPcsResetCntRst  : std_logic;
   signal txPcsResetCntEn   : std_logic;
   signal txStateCnt        : std_logic_vector(5 downto 0);
   signal txStateCntRst     : std_logic;
   signal intTxPmaReset     : std_logic;
   signal intTxReset        : std_logic;
   signal txClockReady      : std_logic;

   -- TX Reset State Machine
   constant TX_SYSTEM_RESET : std_logic_vector(2 downto 0) := "000";
   constant TX_PMA_RESET    : std_logic_vector(2 downto 0) := "001";
   constant TX_WAIT_LOCK    : std_logic_vector(2 downto 0) := "010";
   constant TX_PCS_RESET    : std_logic_vector(2 downto 0) := "011";
   constant TX_WAIT_PCS     : std_logic_vector(2 downto 0) := "100";
   constant TX_ALMOST_READY : std_logic_vector(2 downto 0) := "101";
   constant TX_READY        : std_logic_vector(2 downto 0) := "110";
   signal   curTxState      : std_logic_vector(2 downto 0);
   signal   nxtTxState      : std_logic_vector(2 downto 0);

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   -- State Machine Synchronous Logic
   process ( mgtTxClk, mgtTxRst ) begin
      if mgtTxRst = '1' then
         curTxState    <= TX_SYSTEM_RESET after tpd;
         txPcsResetCnt <= (others=>'0')   after tpd;
         txStateCnt    <= (others=>'0')   after tpd;
         mgtTxPmaReset <= '1'             after tpd;
         mgtTxReset    <= '0'             after tpd;
         mgtTxReady    <= '0'             after tpd;
      elsif rising_edge(mgtTxClk) then

         -- Pass on reset signals
         mgtTxPmaReset <= intTxPmaReset after tpd;
         mgtTxReset    <= intTxReset    after tpd;

         -- Update state
         curTxState <= nxtTxState after tpd;

         -- Tx State Counter
         if txStateCntRst = '1' then
            txStateCnt <= (others=>'0') after tpd;
         else
            txStateCnt <= txStateCnt + 1 after tpd;
         end if;

         -- TX Loop Counter
         if txPcsResetCntRst = '1' then
            txPcsResetCnt <= (others=>'0') after tpd;
         elsif txPcsResetCntEn = '1' then
            txPcsResetCnt <= txPcsResetCnt + 1 after tpd;
         end if;

         -- Ready flag
         mgtTxReady <= txClockReady after tpd;
      end if;
   end process;


   -- Async TX State Logic
   process ( curTxState, txStateCnt, mgtTxLock, mgtTxBuffError, txPcsResetCnt ) begin
      case curTxState is 

         -- System Reset State
         when TX_SYSTEM_RESET =>
            txPcsResetCntRst <= '1';
            txPcsResetCntEn  <= '0';
            txStateCntRst    <= '1';
            intTxPmaReset    <= '1';
            intTxReset       <= '0';
            txClockReady     <= '0';
            nxtTxState       <= TX_PMA_RESET;

         -- PMA Reset State
         when TX_PMA_RESET =>
            txPcsResetCntRst <= '0';
            txPcsResetCntEn  <= '0';
            intTxPmaReset    <= '1';
            intTxReset       <= '0';
            txClockReady     <= '0';

            -- Wait for three clocks
            if txStateCnt = 3 then
               nxtTxState    <= TX_WAIT_LOCK;
               txStateCntRst <= '1';
            else
               nxtTxState    <= curTxState;
               txStateCntRst <= '0';
            end if;

         -- Wait for TX Lock
         when TX_WAIT_LOCK =>
            txPcsResetCntRst <= '0';
            txPcsResetCntEn  <= '0';
            intTxPmaReset    <= '0';
            intTxReset       <= '0';
            txStateCntRst    <= '1';
            txClockReady     <= '0';

            -- Wait for three clocks
            if mgtTxLock = '1' then
               nxtTxState <= TX_PCS_RESET;
            else
               nxtTxState <= curTxState;
            end if;
 
         -- Assert PCS Reset
         when TX_PCS_RESET =>
            txPcsResetCntRst <= '0';
            txPcsResetCntEn  <= '0';
            intTxPmaReset    <= '0';
            intTxReset       <= '1';
            txClockReady     <= '0';

            -- Loss of Lock
            if mgtTxLock = '0' then
               nxtTxState    <= TX_WAIT_LOCK;
               txStateCntRst <= '1';

            -- Wait for three clocks
            elsif txStateCnt = 3 then
               nxtTxState    <= TX_WAIT_PCS;
               txStateCntRst <= '1';
            else
               nxtTxState    <= curTxState;
               txStateCntRst <= '0';
            end if;

         -- Wait 5 clocks after PCS reset
         when TX_WAIT_PCS =>
            txPcsResetCntRst <= '0';
            txPcsResetCntEn  <= '0';
            intTxPmaReset    <= '0';
            intTxReset       <= '0';
            txClockReady     <= '0';

            -- Loss of Lock
            if mgtTxLock = '0' then
               nxtTxState    <= TX_WAIT_LOCK;
               txStateCntRst <= '1';

            -- Wait for three clocks
            elsif txStateCnt = 5 then
               nxtTxState    <= TX_ALMOST_READY;
               txStateCntRst <= '1';
            else
               nxtTxState    <= curTxState;
               txStateCntRst <= '0';
            end if;

         -- Almost Ready State
         when TX_ALMOST_READY =>
            intTxPmaReset    <= '0';
            intTxReset       <= '0';
            txClockReady     <= '0';

            -- Loss of Lock
            if mgtTxLock = '0' then
               nxtTxState       <= TX_WAIT_LOCK;
               txStateCntRst    <= '1';
               txPcsResetCntEn  <= '0';
               txPcsResetCntRst <= '0';

            -- TX Buffer Error
            elsif mgtTxBuffError = '1' then
               txStateCntRst   <= '1';
               txPcsResetCntEn <= '1';

               -- 16 Cycles have occured, reset PLL
               if txPcsResetCnt = 15 then
                  nxtTxState       <= TX_PMA_RESET;
                  txPcsResetCntRst <= '1';

               -- Go back to PCS Reset
               else
                  nxtTxState       <= TX_PCS_RESET;
                  txPcsResetCntRst <= '0';
               end if;

            -- Wait for 64 clocks
            elsif txStateCnt = 63 then
               nxtTxState       <= TX_READY;
               txStateCntRst    <= '1';
               txPcsResetCntEn  <= '0';
               txPcsResetCntRst <= '0';
            else
               nxtTxState       <= curTxState;
               txStateCntRst    <= '0';
               txPcsResetCntEn  <= '0';
               txPcsResetCntRst <= '0';
            end if;

         -- Ready State
         when TX_READY =>
            txPcsResetCntRst <= '1';
            txPcsResetCntEn  <= '0';
            intTxPmaReset    <= '0';
            intTxReset       <= '0';
            txStateCntRst    <= '1';
            txClockReady     <= '1';

            -- Loss of Lock
            if mgtTxLock = '0' then
               nxtTxState <= TX_WAIT_LOCK;

            -- Buffer error has occured
            elsif mgtTxBuffError = '1' then
               nxtTxState <= TX_PCS_RESET;
            else
               nxtTxState <= curTxState;
            end if;

         -- Just in case
         when others =>
            txPcsResetCntRst <= '0';
            txPcsResetCntEn  <= '0';
            intTxPmaReset    <= '0';
            intTxReset       <= '0';
            txStateCntRst    <= '0';
            txClockReady     <= '0';
            nxtTxState       <= TX_SYSTEM_RESET;
      end case;
   end process;

end Pgp2MgtTxRst;

