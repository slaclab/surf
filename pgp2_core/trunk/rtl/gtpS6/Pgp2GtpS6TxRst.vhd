-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, Spartan 6 GTP TX Reset Control
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2GtpS6TxRst.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 08/18/2009
-------------------------------------------------------------------------------
-- Description:
-- This module contains the logic to control the reset of the TX GTP.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC PGP2 Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC PGP2 Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 08/18/2009: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.Pgp2GtpS6Package.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;


entity Pgp2GtpS6TxRst is 
   port (

      -- Clock and reset
      gtpTxClk          : in  std_logic;
      gtpTxRst          : in  std_logic;

      -- TX Side is ready
      gtpTxReady        : out std_logic;

      -- GTP Status
      gtpLockDetect     : in  std_logic;
      gtpTxBuffStatus   : in  std_logic_vector(1  downto 0);
      gtpRstDone        : in  std_logic;

      -- Reset Control
      gtpTxReset        : out std_logic
   );

end Pgp2GtpS6TxRst;


-- Define architecture
architecture Pgp2GtpS6TxRst of Pgp2GtpS6TxRst is

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
   process ( gtpTxClk, gtpTxRst ) begin
      if gtpTxRst = '1' then
         curTxState       <= TX_SYSTEM_RESET after tpd;
         txStateCnt       <= (others=>'0')   after tpd;
         gtpTxReset       <= '1'             after tpd;
         gtpTxReady       <= '0'             after tpd;
      elsif rising_edge(gtpTxClk) then

         -- RX Is Ready
         gtpTxReady <= txClockReady after tpd;

         -- Pass on reset signals
         gtpTxReset <= intTxReset   after tpd;

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
   process ( curTxState, txStateCnt, gtpLockDetect, gtpTxBuffStatus, gtpRstDone ) begin
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
            if gtpLockDetect = '1' then
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
            if gtpRstDone = '1' then
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
            if gtpLockDetect = '0' then
               nxtTxState <= TX_WAIT_LOCK;

            -- Look For Buffer Error
            elsif gtpTxBuffStatus(1) = '1' then
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

end Pgp2GtpS6TxRst;

