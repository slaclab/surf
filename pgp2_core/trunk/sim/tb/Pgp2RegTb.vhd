-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, Top Level PGP + MGT Test Bench
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2RegTb.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/27/2009
-------------------------------------------------------------------------------
-- Description:
-- Test Bench for PGP core plus Xilinx MGT
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
-- 05/27/2009: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
USE work.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.Pgp2MgtPackage.all;
use work.Pgp2RcePackage.all;
use work.Pgp2AppPackage.all;
Library unisim;
use unisim.vcomponents.all;

entity Pgp2RegTb is end Pgp2RegTb;


-- Define architecture
architecture Pgp2RegTb of Pgp2RegTb is

   -- Internal signals
   signal pgpClk           : std_logic;
   signal pgpReset         : std_logic;
   signal locClk           : std_logic;
   signal locReset         : std_logic;
   signal vcFrameRxValid   : std_logic;
   signal vcFrameRxSOF     : std_logic;
   signal vcFrameRxEOF     : std_logic;
   signal vcFrameRxEOFE    : std_logic;
   signal vcFrameRxData    : std_logic_vector(15 downto 0);
   signal vcLocBuffAFull   : std_logic;
   signal vcLocBuffFull    : std_logic;
   signal vcFrameTxValid   : std_logic;
   signal vcFrameTxReady   : std_logic;
   signal vcFrameTxSOF     : std_logic;
   signal vcFrameTxEOF     : std_logic;
   signal vcFrameTxEOFE    : std_logic;
   signal vcFrameTxData    : std_logic_vector(15 downto 0);
   signal vcRemBuffAFull   : std_logic;
   signal vcRemBuffFull    : std_logic;
   signal regInp           : std_logic;
   signal regReq           : std_logic;
   signal regOp            : std_logic;
   signal regAck           : std_logic;
   signal regFail          : std_logic;
   signal regAddr          : std_logic_vector(23 downto 0);
   signal regDataOut       : std_logic_vector(31 downto 0);
   signal regDataIn        : std_logic_vector(31 downto 0);
   signal intCount         : std_logic_vector(31 downto 0);

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin


   -- Reset generation
   process 
   begin
      pgpReset <= '0';
      wait for (6.4 ns);
      pgpReset <= '1';
      wait for (6.4 ns * 20);
      pgpReset <= '0';
      wait;
   end process;

   -- 156.25Mhz Clock
   process 
   begin
      pgpClk <= '0';
      wait for (6.4 ns / 2);
      pgpClk <= '1';
      wait for (6.4 ns / 2);
   end process;

   -- Reset generation
   process 
   begin
      locReset <= '0';
      wait for (8 ns);
      locReset <= '1';
      wait for (8 ns * 20);
      locReset <= '0';
      wait;
   end process;

   -- 156.25Mhz Clock
   process 
   begin
      locClk <= '0';
      wait for (8 ns / 2);
      locClk <= '1';
      wait for (8 ns / 2);
   end process;

   -- Register core
   U_Pgp2RegSlave : Pgp2AppPackage.Pgp2RegSlave port map (
      pgpRxClk         => pgpClk,
      pgpRxReset       => pgpReset,
      pgpTxClk         => pgpClk,
      pgpTxReset       => pgpReset,
      locClk           => locClk,
      locReset         => locReset,
      vcFrameRxValid   => vcFrameRxValid,
      vcFrameRxSOF     => vcFrameRxSOF,
      vcFrameRxEOF     => vcFrameRxEOF,
      vcFrameRxEOFE    => vcFrameRxEOFE,
      vcFrameRxData    => vcFrameRxData,
      vcLocBuffAFull   => vcLocBuffAFull,
      vcLocBuffFull    => vcLocBuffFull,
      vcFrameTxValid   => vcFrameTxValid,
      vcFrameTxReady   => vcFrameTxReady,
      vcFrameTxSOF     => vcFrameTxSOF,
      vcFrameTxEOF     => vcFrameTxEOF,
      vcFrameTxEOFE    => vcFrameTxEOFE,
      vcFrameTxData    => vcFrameTxData,
      vcRemBuffAFull   => vcRemBuffAFull,
      vcRemBuffFull    => vcRemBuffFull,
      regInp           => regInp,
      regReq           => regReq,
      regOp            => regOp,
      regAck           => regAck,
      regFail          => regFail,
      regAddr          => regAddr,
      regDataOut       => regDataOut,
      regDataIn        => regDataIn
   );


   -- Drive ack
   process ( locClk, locReset ) begin
      if locReset = '1' then
         regAck    <= '0'           after tpd;
         regDataIn <= (others=>'0') after tpd;
         regFail   <= '0'           after tpd;
      elsif rising_edge(locClk) then
         regAck    <= regReq          after tpd;
         regDataIn <= x"55" & regAddr after tpd;
         regFail   <= '0'             after tpd;
      end if;
   end process;

   vcRemBuffAFull <= '0';
   vcRemBuffFull  <= '0';
   vcFrameTxReady <= vcFrameTxValid;


   -- Drive data
   process ( pgpClk, pgpReset ) begin
      if pgpReset = '1' then
         vcFrameRxValid   <= '0'           after tpd;
         vcFrameRxSOF     <= '0'           after tpd;
         vcFrameRxEOF     <= '0'           after tpd;
         vcFrameRxEOFE    <= '0'           after tpd;
         vcFrameRxData    <= (others=>'0') after tpd;
         intCount         <= (others=>'0') after tpd;
      elsif rising_edge(pgpClk) then

         if intCount /= 500 then
            intCount <= intCount + 1 after tpd;
         end if;

         if intCount = 0 then
            vcFrameRxData    <= x"0000" after tpd;
            vcFrameRxValid   <= '1'     after tpd;
            vcFrameRxSOF     <= '1'     after tpd;
            vcFrameRxEOF     <= '0'     after tpd;
            vcFrameRxEOFE    <= '0'     after tpd;

         elsif intCount = 1 then
            vcFrameRxData    <= x"0000" after tpd;
            vcFrameRxValid   <= '1'     after tpd;
            vcFrameRxSOF     <= '0'     after tpd;
            vcFrameRxEOF     <= '0'     after tpd;
            vcFrameRxEOFE    <= '0'     after tpd;

         elsif intCount = 2 then
            vcFrameRxData    <= x"008C" after tpd;
            vcFrameRxValid   <= '1'     after tpd;
            vcFrameRxSOF     <= '0'     after tpd;
            vcFrameRxEOF     <= '0'     after tpd;
            vcFrameRxEOFE    <= '0'     after tpd;

         elsif intCount = 3 then
            vcFrameRxData    <= x"4000" after tpd; -- Read =0000, Write=4000
            vcFrameRxValid   <= '1'     after tpd;
            vcFrameRxSOF     <= '0'     after tpd;
            vcFrameRxEOF     <= '0'     after tpd;
            vcFrameRxEOFE    <= '0'     after tpd;

         elsif intCount = 4 then
            vcFrameRxData    <= x"0007" after tpd; -- Read Count, write data
            vcFrameRxValid   <= '1'     after tpd;
            vcFrameRxSOF     <= '0'     after tpd;
            vcFrameRxEOF     <= '0'     after tpd;
            vcFrameRxEOFE    <= '0'     after tpd;

         elsif intCount = 5 then
            vcFrameRxData    <= x"0008" after tpd;
            vcFrameRxValid   <= '1'     after tpd;
            vcFrameRxSOF     <= '0'     after tpd;
            vcFrameRxEOF     <= '0'     after tpd;
            vcFrameRxEOFE    <= '0'     after tpd;

         elsif intCount = 6 then
            vcFrameRxData    <= x"0009" after tpd;
            vcFrameRxValid   <= '1'     after tpd;
            vcFrameRxSOF     <= '0'     after tpd;
            vcFrameRxEOF     <= '0'     after tpd;
            vcFrameRxEOFE    <= '0'     after tpd;

         elsif intCount = 7 then
            vcFrameRxData    <= x"000A" after tpd;
            vcFrameRxValid   <= '1'     after tpd;
            vcFrameRxSOF     <= '0'     after tpd;
            vcFrameRxEOF     <= '0'     after tpd;
            vcFrameRxEOFE    <= '0'     after tpd;

         elsif intCount = 8 then
            vcFrameRxData    <= x"0000" after tpd;
            vcFrameRxValid   <= '1'     after tpd;
            vcFrameRxSOF     <= '0'     after tpd;
            vcFrameRxEOF     <= '0'     after tpd;
            vcFrameRxEOFE    <= '0'     after tpd;

         elsif intCount = 9 then
            vcFrameRxData    <= x"0000" after tpd;
            vcFrameRxValid   <= '1'     after tpd;
            vcFrameRxSOF     <= '0'     after tpd;
            vcFrameRxEOF     <= '1'     after tpd;
            vcFrameRxEOFE    <= '0'     after tpd;

         else
            vcFrameRxData    <= x"0000" after tpd;
            vcFrameRxValid   <= '0'     after tpd;
            vcFrameRxSOF     <= '0'     after tpd;
            vcFrameRxEOF     <= '0'     after tpd;
            vcFrameRxEOFE    <= '0'     after tpd;
         end if;
      end if;
   end process;

end Pgp2RegTb;

