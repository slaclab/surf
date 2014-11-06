-------------------------------------------------------------------------------
-- Title         : Ethernet Arbiter Module
-- Project       : SID, KPIX ASIC
-------------------------------------------------------------------------------
-- File          : EthArbiter.vhd
-- Author        : Raghuveer Ausoori, ausoori@slac.stanford.edu
-- Created       : 10/11/2011
-------------------------------------------------------------------------------
-- Description:
-- This module arbirates between different blocks that wants to TX
-------------------------------------------------------------------------------
-- Copyright (c) 2011 by Raghuveer Ausoori. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 10/11/2011: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
Library Unisim;
USE ieee.std_logic_1164.ALL;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
--USE work.ALL;
use work.EthClientPackage.all;

entity EthArbiter is 
   port ( 

      -- Ethernet clock & reset
      gtpClk         : in  std_logic;                        -- 125Mhz master clock
      gtpClkRst      : in  std_logic;                        -- Synchronous reset input

      -- User Transmit ETH Interface
      userTxValid    : out std_logic;
      userTxReady    : in  std_logic;
      userTxData     : out std_logic_vector(31 downto 0);    -- Ethernet TX Data
      userTxSOF      : out std_logic;                        -- Ethernet TX Start of Frame
      userTxEOF      : out std_logic;                        -- Ethernet TX End of Frame
      userTxVc       : out std_logic_vector(1  downto 0);    -- Ethernet TX Virtual Channel

      -- User 0 Transmit Interface
      user0TxValid   : in  std_logic;
      user0TxReady   : out std_logic;
      user0TxData    : in  std_logic_vector(31 downto 0);    -- Ethernet TX Data
      user0TxSOF     : in  std_logic;                        -- Ethernet TX Start of Frame
      user0TxEOF     : in  std_logic;                        -- Ethernet TX End of Frame

      -- User 1 Transmit Interface
      user1TxValid   : in  std_logic;
      user1TxReady   : out std_logic;
      user1TxData    : in  std_logic_vector(31 downto 0);    -- Ethernet TX Data
      user1TxSOF     : in  std_logic;                        -- Ethernet TX Start of Frame
      user1TxEOF     : in  std_logic;                        -- Ethernet TX End of Frame

       -- User 2 Transmit Interface
      user2TxValid   : in  std_logic;
      user2TxReady   : out std_logic;
      user2TxData    : in  std_logic_vector(31 downto 0);    -- Ethernet TX Data
      user2TxSOF     : in  std_logic;                        -- Ethernet TX Start of Frame
      user2TxEOF     : in  std_logic;                        -- Ethernet TX End of Frame

      -- User 3 Transmit Interface
      user3TxValid   : in  std_logic;
      user3TxReady   : out std_logic;
      user3TxData    : in  std_logic_vector(31 downto 0);    -- Ethernet TX Data
      user3TxSOF     : in  std_logic;                        -- Ethernet TX Start of Frame
      user3TxEOF     : in  std_logic                         -- Ethernet TX End of Frame

   );
end EthArbiter;


-- Define architecture for Interface module
architecture EthArbiter of EthArbiter is 

   -- Local signals
   constant ST_IDLE       : std_logic_vector(2 downto 0) := "000";
   constant ST_SEL0       : std_logic_vector(2 downto 0) := "001";
   constant ST_SEL1       : std_logic_vector(2 downto 0) := "010";
   constant ST_SEL2       : std_logic_vector(2 downto 0) := "011";
   constant ST_SEL3       : std_logic_vector(2 downto 0) := "100";
   signal   curState      : std_logic_vector(2 downto 0);
   signal   nxtState      : std_logic_vector(2 downto 0);

begin

   process ( curState, userTxReady, user0TxValid, user0TxData, user0TxSOF, user0TxEOF,
            user1TxValid, user1TxData, user1TxSOF, user1TxEOF,
            user2TxValid, user2TxData, user2TxSOF, user2TxEOF,
            user3TxValid, user3TxData, user3TxSOF, user3TxEOF) begin

      case curState is
         when ST_IDLE =>
            userTxValid  <= '0';
            user0TxReady <= '0';
            user1TxReady <= '0';
            user2TxReady <= '0';
            user3TxReady <= '0';
            userTxData   <= (others=>'0');
            userTxSOF    <= '0';
            userTxEOF    <= '0';
            userTxVc     <= "00";

            if ( user0TxValid = '1' ) then
               nxtState <= ST_SEL0;
            elsif ( user1TxValid = '1' ) then
               nxtState <= ST_SEL1;
            elsif ( user2TxValid = '1' ) then
               nxtState <= ST_SEL2;
            elsif ( user3TxValid = '1' ) then
               nxtState <= ST_SEL3;
            else
               nxtState <= ST_IDLE;
            end if;

         when ST_SEL0 =>
            userTxValid  <= user0TxValid;
            user0TxReady <= userTxReady;
            user1TxReady <= '0';
            user2TxReady <= '0';
            user3TxReady <= '0';
            userTxData   <= user0TxData;
            userTxSOF    <= user0TxSOF;
            userTxEOF    <= user0TxEOF;
            userTxVc     <= "00";

            if ( user0TxEOF = '1' and user0TxValid = '1' and userTxReady = '1' ) then
               if ( user1TxValid = '1' ) then
                  nxtState <= ST_SEL1;
               elsif ( user2TxValid = '1' ) then
                  nxtState <= ST_SEL2;
               elsif ( user3TxValid = '1' ) then
                  nxtState <= ST_SEL3;
               else
                  nxtState <= ST_IDLE;
               end if;
            else
               nxtState <= ST_SEL0;
            end if;

         when ST_SEL1 =>
            userTxValid  <= user1TxValid;
            user0TxReady <= '0';
            user1TxReady <= userTxReady;
            user2TxReady <= '0';
            user3TxReady <= '0';
            userTxData   <= user1TxData;
            userTxSOF    <= user1TxSOF;
            userTxEOF    <= user1TxEOF;
            userTxVc     <= "01";

            if ( user1TxEOF = '1' and user1TxValid = '1' and userTxReady = '1' ) then
               if ( user2TxValid = '1' ) then
                  nxtState <= ST_SEL2;
               elsif ( user3TxValid = '1' ) then
                  nxtState <= ST_SEL3;
               elsif ( user0TxValid = '1' ) then
                  nxtState <= ST_SEL0;
               else
                  nxtState <= ST_IDLE;
               end if;
            else
               nxtState <= ST_SEL1;
            end if;

         when ST_SEL2 =>
            userTxValid  <= user2TxValid;
            user0TxReady <= '0';
            user1TxReady <= '0';
            user2TxReady <= userTxReady;
            user3TxReady <= '0';
            userTxData   <= user2TxData;
            userTxSOF    <= user2TxSOF;
            userTxEOF    <= user2TxEOF;
            userTxVc     <= "10";

            if ( user2TxEOF = '1' and user2TxValid = '1' and userTxReady = '1' ) then
               if ( user3TxValid = '1' ) then
                  nxtState <= ST_SEL3;
               elsif ( user0TxValid = '1' ) then
                  nxtState <= ST_SEL0;
               elsif ( user1TxValid = '1' ) then
                  nxtState <= ST_SEL1;
               else
                  nxtState <= ST_IDLE;
               end if;
            else
               nxtState <= ST_SEL2;
            end if;

         when ST_SEL3 =>
            userTxValid  <= user3TxValid;
            user0TxReady <= '0';
            user1TxReady <= '0';
            user2TxReady <= '0';
            user3TxReady <= userTxReady;
            userTxData   <= user3TxData;
            userTxSOF    <= user3TxSOF;
            userTxEOF    <= user3TxEOF;
            userTxVc     <= "11";

            if ( user3TxEOF = '1' and user3TxValid = '1' and userTxReady = '1' ) then
               if ( user0TxValid = '1' ) then
                  nxtState <= ST_SEL0;
               elsif ( user1TxValid = '1' ) then
                  nxtState <= ST_SEL1;
               elsif ( user2TxValid = '1' ) then
                  nxtState <= ST_SEL2;
               else
                  nxtState <= ST_IDLE;
               end if;
            else
               nxtState <= ST_SEL3;
            end if;
         when others =>
            userTxValid  <= '0';
            user0TxReady <= '0';
            user1TxReady <= '0';
            user2TxReady <= '0';
            user3TxReady <= '0';
            userTxData   <= (others=>'0');
            userTxSOF    <= '0';
            userTxEOF    <= '0';
            userTxVc     <= "00";
            nxtState     <= ST_IDLE;
      end case;
   end process;

   process ( gtpClkRst, gtpClk ) begin
      if gtpClkRst = '1' then
         curState <= ST_IDLE;
      elsif rising_edge(gtpClk) then
         curState <= nxtState;
      end if;
   end process;

end EthArbiter;
