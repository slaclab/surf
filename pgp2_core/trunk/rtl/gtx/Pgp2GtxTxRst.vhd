-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, GTX TX Reset Control
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2GtxTxRst.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 08/18/2009
-------------------------------------------------------------------------------
-- Description:
-- This module contains the logic to control the reset of the TX GTX.
-------------------------------------------------------------------------------
-- Copyright (c) 2006 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 08/18/2009: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.Pgp2GtxPackage.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;


entity Pgp2GtxTxRst is 
   port (

      -- Clock and reset
      gtxTxClk          : in  std_logic;
      gtxTxRst          : in  std_logic;

      -- TX Side is ready
      gtxTxReady        : out std_logic;

      -- GTX Status
      gtxLockDetect     : in  std_logic;
      gtxTxBuffStatus   : in  std_logic_vector(1  downto 0);
      gtxRstDone        : in  std_logic;

      -- Reset Control
      gtxTxReset        : out std_logic
   );

end Pgp2GtxTxRst;


-- Define architecture
architecture Pgp2GtxTxRst of Pgp2GtxTxRst is

   -- Local Signals
   signal intTxReset        : std_logic;
   signal txStateCnt        : std_logic_vector(1 downto 0);
   signal txStateCntRst     : std_logic;
   signal txClockReady      : std_logic;

   -- TX Reset State Machine
   constant TX_SYSTEM_RESET : std_logic_vector(2 downto 0) := "000";
   constant TX_WAIT_LOCK    : std_logic_vector(2 downto 0) := "001";
   constant TX_RESET        : std_logic_vector(2 downto 0) := "010";
   constant TX_WAIT_DONE    : std_logic_vector(2 downto 0) := "011";
   constant TX_READY        : std_logic_vector(2 downto 0) := "100";
   signal   curTxState      : std_logic_vector(2 downto 0);
   signal   nxtTxState      : std_logic_vector(2 downto 0);

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin


   -- TX State Machine Synchronous Logic
   process ( gtxTxClk, gtxTxRst ) begin
      if gtxTxRst = '1' then
         curTxState       <= TX_SYSTEM_RESET after tpd;
         txStateCnt       <= (others=>'0')   after tpd;
         gtxTxReset       <= '1'             after tpd;
         gtxTxReady       <= '0'             after tpd;
      elsif rising_edge(gtxTxClk) then

         -- RX Is Ready
         gtxTxReady <= txClockReady after tpd;

         -- Pass on reset signals
         gtxTxReset <= intTxReset   after tpd;

         -- Update state
         curTxState <= nxtTxState after tpd;

         -- Tx State Counter
         if txStateCntRst = '1' then
            txStateCnt <= (others=>'0') after tpd;
         else
            txStateCnt <= txStateCnt + 1 after tpd;
         end if;
      end if;
   end process;


   -- Async TX State Logic
   process ( curTxState, txStateCnt, gtxLockDetect, gtxTxBuffStatus, gtxRstDone ) begin
      case curTxState is 

         -- System Reset State
         when TX_SYSTEM_RESET =>
            txStateCntRst    <= '1';
            intTxReset       <= '1';
            txClockReady     <= '0';
            nxtTxState       <= TX_WAIT_LOCK;

         -- Wait for PLL lock
         when TX_WAIT_LOCK =>
            txStateCntRst    <= '1';
            intTxReset       <= '1';
            txClockReady     <= '0';

            -- Wait for three clocks
            if gtxLockDetect = '1' then
               nxtTxState    <= TX_RESET;
            else
               nxtTxState    <= curTxState;
            end if;

         -- TX Reset State
         when TX_RESET =>
            intTxReset       <= '1';
            txClockReady     <= '0';
            txStateCntRst    <= '0';

            -- Wait for three clocks
            if txStateCnt = 3 then
               nxtTxState    <= TX_WAIT_DONE;
            else
               nxtTxState    <= curTxState;
            end if;

         -- TX Wait Reset Done
         when TX_WAIT_DONE =>
            intTxReset       <= '0';
            txClockReady     <= '0';
            txStateCntRst    <= '1';

            -- Wait for three clocks
            if gtxRstDone = '1' then
               nxtTxState    <= TX_READY;
            else
               nxtTxState    <= curTxState;
            end if;

         -- TX Ready
         when TX_READY =>
            intTxReset       <= '0';
            txClockReady     <= '1';
            txStateCntRst    <= '1';

            -- Look for unlock error
            if gtxLockDetect = '0' then
               nxtTxState <= TX_WAIT_LOCK;

            -- Look For Buffer Error
            elsif gtxTxBuffStatus(1) = '1' then
               nxtTxState <= TX_RESET;
            else
               nxtTxState <= curTxState;
            end if;

         -- Default
         when others =>
            intTxReset    <= '0';
            txClockReady  <= '0';
            txStateCntRst <= '1';
            nxtTxState    <= TX_SYSTEM_RESET;
      end case;
   end process;

end Pgp2GtxTxRst;

