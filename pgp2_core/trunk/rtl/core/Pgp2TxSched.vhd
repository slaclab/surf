-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, Transmit Scheduler
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2TxSched.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/18/2009
-------------------------------------------------------------------------------
-- Description:
-- Transmit scheduler interface module for the Pretty Good Protocol core. 
-------------------------------------------------------------------------------
-- Copyright (c) 2006 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 05/18/2009: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
USE work.ALL;
USE work.Pgp2CorePackage.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Pgp2TxSched is 
   generic (
      VcInterleave : integer := 1  -- Interleave Frames
   );
   port ( 

      -- System clock, reset & control
      pgpTxClk          : in  std_logic;                     -- Master clock
      pgpTxReset        : in  std_logic;                     -- Synchronous reset input

      -- Link is ready
      pgpTxLinkReady    : in  std_logic;                     -- Local side has link

      -- Cell Transmit Interface
      schTxSOF          : in  std_logic;                     -- Cell contained SOF
      schTxEOF          : in  std_logic;                     -- Cell contained EOF
      schTxIdle         : out std_logic;                     -- Force IDLE transmit
      schTxReq          : out std_logic;                     -- Cell transmit request
      schTxAck          : in  std_logic;                     -- Cell transmit acknowledge
      schTxDataVc       : out std_logic_vector(1 downto 0);  -- Cell transmit virtual channel

      -- VC Data Valid Signals
      vc0FrameTxValid   : in  std_logic;                     -- User frame data is valid
      vc1FrameTxValid   : in  std_logic;                     -- User frame data is valid
      vc2FrameTxValid   : in  std_logic;                     -- User frame data is valid
      vc3FrameTxValid   : in  std_logic                      -- User frame data is valid
   );

end Pgp2TxSched;


-- Define architecture
architecture Pgp2TxSched of Pgp2TxSched is

   -- Local Signals
   signal currValid    : std_logic;
   signal currVc       : std_logic_vector(1 downto 0);
   signal nextVc       : std_logic_vector(1 downto 0);
   signal arbVc        : std_logic_vector(1 downto 0);
   signal arbValid     : std_logic;
   signal vcInFrame    : std_logic_vector(3 downto 0);
   signal intTxReq     : std_logic;
   signal intTxIdle    : std_logic;
   signal nxtTxReq     : std_logic;
   signal nxtTxIdle    : std_logic;

   -- Schedular state
   constant ST_RST   : std_logic_vector(2 downto 0) := "001";
   constant ST_ARB   : std_logic_vector(2 downto 0) := "010";
   constant ST_CELL  : std_logic_vector(2 downto 0) := "011";
   constant ST_GAP_A : std_logic_vector(2 downto 0) := "100";
   constant ST_GAP_B : std_logic_vector(2 downto 0) := "101";
   constant ST_GAP_C : std_logic_vector(2 downto 0) := "110";
   signal   curState : std_logic_vector(2 downto 0);
   signal   nxtState : std_logic_vector(2 downto 0);

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   -- Outgoing signals
   schTxReq    <= intTxReq;
   schTxIdle   <= intTxIdle;
   schTxDataVc <= currVc;


   -- State transition logic
   process ( pgpTxClk, pgpTxReset ) begin
      if pgpTxReset = '1' then
         curState  <= ST_ARB        after tpd;
         currVc    <= "00"          after tpd;
         intTxReq  <= '0'           after tpd;
         intTxIdle <= '0'           after tpd;
      elsif rising_edge(pgpTxClk) then

         -- Force state to select state when link goes down
         if pgpTxLinkReady = '0' then
            curState <= ST_RST   after tpd;
         else
            curState <= nxtState after tpd;
         end if;

         -- Control signals
         currVc    <= nextVc    after tpd;
         intTxReq  <= nxtTxReq  after tpd;
         intTxIdle <= nxtTxIdle after tpd;

      end if;
   end process;


   -- Scheduler state machine
   process ( curState, arbValid, arbVc, currVc, schTxAck, vcInFrame, currValid ) begin
      case curState is

         -- Held in reset due to non-link
         when ST_RST =>
            nxtTxIdle  <= '0';
            nxtTxReq   <= '0';
            nextVc     <= (others=>'0');
            nxtState   <= ST_ARB;

         -- IDLE, wait for ack receiver to be ready 
         when ST_ARB =>

            -- Non-interleave mode and current is in frame
            if VcInterleave = 0 and vcInFrame(conv_integer(currVc)) = '1' then
               nxtTxIdle <= not currValid;
               nxtTxReq  <= currValid;
               nextVc    <= currVc;

            -- Else use new arb winner if valid
            else
               nxtTxIdle <= not arbValid;
               nxtTxReq  <= arbValid;
               nextVc    <= arbVc;
            end if;
            nxtState <= ST_CELL;

         -- Transmit Cell Data
         when ST_CELL =>
            nxtTxIdle  <= '0';
            nxtTxReq   <= '0';
            nextVc     <= currVc;

            -- Cell is done
            if schTxAck = '1' then
               nxtState <= ST_GAP_A;
            else
               nxtState <= curState;
            end if;

         -- Wait between cells
         when ST_GAP_A =>
            nxtTxIdle  <= '0';
            nxtTxReq   <= '0';
            nextVc     <= currVc;
            nxtState   <= ST_GAP_B;

         -- Wait between cells
         when ST_GAP_B =>
            nxtTxIdle  <= '0';
            nxtTxReq   <= '0';
            nextVc     <= currVc;
            nxtState   <= ST_GAP_C;

         -- Wait between cells
         when ST_GAP_C =>
            nxtTxIdle  <= '0';
            nxtTxReq   <= '0';
            nextVc     <= currVc;
            nxtState   <= ST_ARB;

         -- Just in case
         when others =>
            nxtTxIdle  <= '0';
            nxtTxReq   <= '0';
            nextVc     <= (others=>'0');
            nxtState   <= ST_ARB;
      end case;
   end process;


   -- Current owner has valid asserted
   currValid <= vc0FrameTxValid when currVc = "00" else
                vc1FrameTxValid when currVc = "01" else
                vc2FrameTxValid when currVc = "10" else
                vc3FrameTxValid;


   -- Arbitrate for the next VC value based upon current VC value and status of valid inputs
   process ( currVc, vc0FrameTxValid, vc1FrameTxValid, vc2FrameTxValid, vc3FrameTxValid ) begin
      case currVc is
         when "00" =>
            if    vc1FrameTxValid = '1' then arbVc <= "01"; arbValid <= '1';
            elsif vc2FrameTxValid = '1' then arbVc <= "10"; arbValid <= '1';
            elsif vc3FrameTxValid = '1' then arbVc <= "11"; arbValid <= '1';
            elsif vc0FrameTxValid = '1' then arbVc <= "00"; arbValid <= '1';
            else  arbVc <= currVc; arbValid <= '0'; end if;
         when "01" =>
            if    vc2FrameTxValid = '1' then arbVc <= "10"; arbValid <= '1';
            elsif vc3FrameTxValid = '1' then arbVc <= "11"; arbValid <= '1';
            elsif vc0FrameTxValid = '1' then arbVc <= "00"; arbValid <= '1';
            elsif vc1FrameTxValid = '1' then arbVc <= "01"; arbValid <= '1';
            else  arbVc <= currVc; arbValid <= '0'; end if;
         when "10" =>
            if    vc3FrameTxValid = '1' then arbVc <= "11"; arbValid <= '1';
            elsif vc0FrameTxValid = '1' then arbVc <= "00"; arbValid <= '1';
            elsif vc1FrameTxValid = '1' then arbVc <= "01"; arbValid <= '1';
            elsif vc2FrameTxValid = '1' then arbVc <= "10"; arbValid <= '1';
            else  arbVc <= currVc; arbValid <= '0'; end if;
         when "11" =>
            if    vc0FrameTxValid = '1' then arbVc <= "00"; arbValid <= '1';
            elsif vc1FrameTxValid = '1' then arbVc <= "01"; arbValid <= '1';
            elsif vc2FrameTxValid = '1' then arbVc <= "10"; arbValid <= '1';
            elsif vc3FrameTxValid = '1' then arbVc <= "11"; arbValid <= '1';
            else  arbVc <= currVc; arbValid <= '0'; end if;
         when others =>
            arbVc <= "00"; arbValid <= '0';
      end case;
   end process;


   -- Lock in the status of the last cell transmitted
   process ( pgpTxClk, pgpTxReset ) begin
      if pgpTxReset = '1' then
         vcInFrame    <= "0000"        after tpd;
      elsif rising_edge(pgpTxClk) then

         -- Link is down, reset status
         if pgpTxLinkReady  = '0' then
            vcInFrame <= "0000" after tpd;
         else

            -- Update state of VC, track if VC is currently in frame or not
            -- SOF transmitted
            if schTxSOF = '1' then
               vcInFrame(conv_integer(currVc)) <= '1' after tpd;
               
            -- EOF transmitted
            elsif schTxEOF = '1' then
               vcInFrame(conv_integer(currVc)) <= '0' after tpd;
            end if;
         end if;
      end if;
   end process;

end Pgp2TxSched;

