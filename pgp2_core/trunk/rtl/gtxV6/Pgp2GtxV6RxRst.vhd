-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, Virtex 6 GTX RX Reset Control
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2GtxV6RxRst.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 08/18/2009
-------------------------------------------------------------------------------
-- Description:
-- This module contains the logic to control the reset of the RX GTP.
-------------------------------------------------------------------------------
-- Copyright (c) 2009 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 08/18/2009: created.
-- 01/13/2010: Added received init line to help linking.
-- 04/20/2010: Elec idle will no longer cause general reset.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.Pgp2GtxV6Package.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;


entity Pgp2GtxV6RxRst is 
   port (

      -- Clock and reset
      gtpRxClk          : in  std_logic;
      gtpRxRst          : in  std_logic;

      -- RX Side is ready
      gtpRxReady        : out std_logic;
      gtpRxInit         : in  std_logic;

      -- GTP Status
      gtpLockDetect     : in  std_logic;
      gtpRxElecIdle     : in  std_logic;
      gtpRxBuffStatus   : in  std_logic_vector(2  downto 0);
      gtpRstDone        : in  std_logic;

      -- Reset Control
      gtpRxElecIdleRst  : out std_logic;
      gtpRxReset        : out std_logic;
      gtpRxCdrReset     : out std_logic 
   );

end Pgp2GtxV6RxRst;


-- Define architecture
architecture Pgp2GtxV6RxRst of Pgp2GtxV6RxRst is

   -- Local Signals
   signal intRxElecIdleRst  : std_logic;
   signal intRxReset        : std_logic;
   signal intRxCdrReset     : std_logic;
   signal rxStateCnt        : std_logic_vector(1 downto 0);
   signal rxStateCntRst     : std_logic;
   signal rxClockReady      : std_logic;

   -- RX Reset State Machine
   constant RX_SYSTEM_RESET : std_logic_vector(2 downto 0) := "000";
   constant RX_WAIT_LOCK    : std_logic_vector(2 downto 0) := "001";
   constant RX_RESET        : std_logic_vector(2 downto 0) := "010";
   constant RX_WAIT_DONE    : std_logic_vector(2 downto 0) := "011";
   constant RX_READY        : std_logic_vector(2 downto 0) := "100";
   signal   curRxState      : std_logic_vector(2 downto 0);
   signal   nxtRxState      : std_logic_vector(2 downto 0);

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin


   -- RX State Machine Synchronous Logic
   process ( gtpRxClk, gtpRxRst ) begin
      if gtpRxRst = '1' then
         curRxState       <= RX_SYSTEM_RESET after tpd;
         rxStateCnt       <= (others=>'0')   after tpd;
         gtpRxReady       <= '0'             after tpd;
         gtpRxElecIdleRst <= '1'             after tpd;
         gtpRxReset       <= '1'             after tpd;
         gtpRxCdrReset    <= '1'             after tpd;
      elsif rising_edge(gtpRxClk) then

         -- Drive PIB Lock 
         gtpRxReady <= rxClockReady after tpd;

         -- Pass on reset signals
         gtpRxElecIdleRst <= intRxElecIdleRst or gtpRxInit after tpd;
         gtpRxReset       <= intRxReset                    after tpd;
         gtpRxCdrReset    <= intRxCdrReset                 after tpd;

         -- Update state
         if gtpRxInit = '1' then
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
      end if;
   end process;


   -- Async RX State Logic
   process ( curRxState, rxStateCnt, gtpLockDetect, gtpRxBuffStatus, gtpRstDone ) begin
      case curRxState is 

         -- System Reset State
         when RX_SYSTEM_RESET =>
            rxStateCntRst    <= '1';
            intRxReset       <= '1';
            intRxCdrReset    <= '1';
            rxClockReady     <= '0';
            nxtRxState       <= RX_WAIT_LOCK;

         -- Wait for PLL lock
         when RX_WAIT_LOCK =>
            rxStateCntRst    <= '1';
            intRxReset       <= '1';
            intRxCdrReset    <= '0';
            rxClockReady     <= '0';

            -- Wait for lock
            if gtpLockDetect = '1' then
               nxtRxState    <= RX_RESET;
            else
               nxtRxState    <= curRxState;
            end if;

         -- RX Reset State
         when RX_RESET =>
            intRxReset       <= '1';
            intRxCdrReset    <= '0';
            rxClockReady     <= '0';
            rxStateCntRst    <= '0';

            -- Wait for three clocks
            if rxStateCnt = 3 then
               nxtRxState    <= RX_WAIT_DONE;
            else
               nxtRxState    <= curRxState;
            end if;

         -- RX Wait Reset Done
         when RX_WAIT_DONE =>
            intRxReset       <= '0';
            intRxCdrReset    <= '0';
            rxClockReady     <= '0';
            rxStateCntRst    <= '1';

            -- Wait for reset done
            if gtpRstDone = '1' then
               nxtRxState    <= RX_READY;
            else
               nxtRxState    <= curRxState;
            end if;

         -- RX Ready
         when RX_READY =>
            intRxReset       <= '0';
            intRxCdrReset    <= '0';
            rxClockReady     <= '1';
            rxStateCntRst    <= '1';

            -- Look for unlock error
            if gtpLockDetect = '0' then
               nxtRxState <= RX_WAIT_LOCK;

            -- Look For Buffer Error
            elsif gtpRxBuffStatus(2) = '1' then
               nxtRxState <= RX_RESET;

            else
               nxtRxState <= curRxState;
            end if;

         -- Default
         when others =>
            intRxReset       <= '0';
            intRxCdrReset    <= '0';
            rxClockReady     <= '0';
            rxStateCntRst    <= '1';
            nxtRxState       <= RX_SYSTEM_RESET;
      end case;
   end process;

   -- Elec idle reset
   intRxElecIdleRst <= gtpRxElecIdle and gtpRstDone;

end Pgp2GtxV6RxRst;

