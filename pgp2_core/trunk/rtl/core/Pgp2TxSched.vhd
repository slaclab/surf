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
-- 05/18/2012: Added VC transmit timeout
-------------------------------------------------------------------------------

library ieee;
--USE work.ALL;
use work.Pgp2CorePackage.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Pgp2TxSched is
   generic (
      VcInterleave : integer              := 1;  -- Interleave Frames
      NUM_VC_EN_G  : integer range 1 to 4 := 4
      );
   port (

      -- System clock, reset & control
      pgpTxClk   : in std_logic;        -- Master clock
      pgpTxReset : in std_logic;        -- Synchronous reset input

      -- Link flush
      pgpTxFlush : in std_logic;        -- Flush the link

      -- Link is ready
      pgpTxLinkReady : in std_logic;    -- Local side has link

      -- Cell Transmit Interface
      schTxSOF     : in  std_logic;                     -- Cell contained SOF
      schTxEOF     : in  std_logic;                     -- Cell contained EOF
      schTxIdle    : out std_logic;                     -- Force IDLE transmit
      schTxReq     : out std_logic;                     -- Cell transmit request
      schTxAck     : in  std_logic;                     -- Cell transmit acknowledge
      schTxTimeout : out std_logic;                     -- Cell transmit timeout
      schTxDataVc  : out std_logic_vector(1 downto 0);  -- Cell transmit virtual channel

      -- VC Data Valid Signals
      vc0FrameTxValid : in std_logic;   -- User frame data is valid
      vc1FrameTxValid : in std_logic;   -- User frame data is valid
      vc2FrameTxValid : in std_logic;   -- User frame data is valid
      vc3FrameTxValid : in std_logic    -- User frame data is valid
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
   signal nxtTxTimeout : std_logic;
   signal intTxTimeout : std_logic;
   signal vcTimerA     : std_logic_vector(23 downto 0);
   signal vcTimerB     : std_logic_vector(23 downto 0);
   signal vcTimerC     : std_logic_vector(23 downto 0);
   signal vcTimerD     : std_logic_vector(23 downto 0);
   signal vcTimeout    : std_logic_vector(3 downto 0);

   -- Schedular state
   constant ST_RST   : std_logic_vector(2 downto 0) := "001";
   constant ST_ARB   : std_logic_vector(2 downto 0) := "010";
   constant ST_CELL  : std_logic_vector(2 downto 0) := "011";
   constant ST_GAP_A : std_logic_vector(2 downto 0) := "100";
   constant ST_GAP_B : std_logic_vector(2 downto 0) := "101";
   constant ST_GAP_C : std_logic_vector(2 downto 0) := "110";
   signal curState   : std_logic_vector(2 downto 0);
   signal nxtState   : std_logic_vector(2 downto 0);

   -- Register delay for simulation
   constant tpd : time := 0.5 ns;

begin

   -- Outgoing signals
   schTxReq     <= intTxReq;
   schTxIdle    <= intTxIdle;
   schTxDataVc  <= currVc;
   schTxTimeout <= intTxTimeout;


   -- State transition logic
   process (pgpTxClk, pgpTxReset)
   begin
      if pgpTxReset = '1' then
         curState     <= ST_ARB after tpd;
         currVc       <= "00"   after tpd;
         intTxReq     <= '0'    after tpd;
         intTxIdle    <= '0'    after tpd;
         intTxTimeout <= '0'    after tpd;
      elsif rising_edge(pgpTxClk) then

         -- Force state to select state when link goes down
         if pgpTxLinkReady = '0' then
            curState <= ST_RST after tpd;
         else
            curState <= nxtState after tpd;
         end if;

         -- Control signals
         currVc       <= nextVc       after tpd;
         intTxReq     <= nxtTxReq     after tpd;
         intTxIdle    <= nxtTxIdle    after tpd;
         intTxTimeout <= nxtTxTimeout after tpd;

      end if;
   end process;


   -- Scheduler state machine
   process (curState, arbValid, arbVc, currVc, schTxAck, vcInFrame, currValid, vcTimeout)
   begin
      case curState is

         -- Held in reset due to non-link
         when ST_RST =>
            nxtTxIdle    <= '0';
            nxtTxReq     <= '0';
            nxtTxTimeout <= '0';
            nextVc       <= (others => '0');
            nxtState     <= ST_ARB;

         -- IDLE, wait for ack receiver to be ready 
         when ST_ARB =>

            -- VC0 Timeout
            if vcTimeout(0) = '1' then
               nxtTxIdle    <= '0';
               nxtTxReq     <= '1';
               nxtTxTimeout <= '1';
               nextVc       <= "00";

            -- VC1 Timeout
            elsif vcTimeout(1) = '1' and NUM_VC_EN_G > 1 then
               nxtTxIdle    <= '0';
               nxtTxReq     <= '1';
               nxtTxTimeout <= '1';
               nextVc       <= "01";

            -- VC2 Timeout
            elsif vcTimeout(2) = '1' and NUM_VC_EN_G > 2 then
               nxtTxIdle    <= '0';
               nxtTxReq     <= '1';
               nxtTxTimeout <= '1';
               nextVc       <= "10";

            -- VC3 Timeout
            elsif vcTimeout(3) = '1' and NUM_VC_EN_G > 3 then
               nxtTxIdle    <= '0';
               nxtTxReq     <= '1';
               nxtTxTimeout <= '1';
               nextVc       <= "11";

            -- Non-interleave mode and current is in frame
            elsif VcInterleave = 0 and vcInFrame(conv_integer(currVc)) = '1' then
               nxtTxIdle    <= not currValid;
               nxtTxReq     <= currValid;
               nextVc       <= currVc;
               nxtTxTimeout <= '0';

            -- Else use new arb winner if valid
            else
               nxtTxIdle    <= not arbValid;
               nxtTxReq     <= arbValid;
               nextVc       <= arbVc;
               nxtTxTimeout <= '0';
            end if;
            nxtState <= ST_CELL;

         -- Transmit Cell Data
         when ST_CELL =>
            nxtTxIdle    <= '0';
            nxtTxTimeout <= '0';
            nxtTxReq     <= '0';
            nextVc       <= currVc;

            -- Cell is done
            if schTxAck = '1' then
               nxtState <= ST_GAP_A;
            else
               nxtState <= curState;
            end if;

         -- Wait between cells
         when ST_GAP_A =>
            nxtTxIdle    <= '0';
            nxtTxReq     <= '0';
            nxtTxTimeout <= '0';
            nextVc       <= currVc;
            nxtState     <= ST_GAP_B;

         -- Wait between cells
         when ST_GAP_B =>
            nxtTxIdle    <= '0';
            nxtTxReq     <= '0';
            nxtTxTimeout <= '0';
            nextVc       <= currVc;
            nxtState     <= ST_GAP_C;

         -- Wait between cells
         when ST_GAP_C =>
            nxtTxIdle    <= '0';
            nxtTxReq     <= '0';
            nxtTxTimeout <= '0';
            nextVc       <= currVc;
            nxtState     <= ST_ARB;

         -- Just in case
         when others =>
            nxtTxIdle    <= '0';
            nxtTxReq     <= '0';
            nxtTxTimeout <= '0';
            nextVc       <= (others => '0');
            nxtState     <= ST_ARB;
      end case;
   end process;


   -- Current owner has valid asserted
   currValid <= vc0FrameTxValid when currVc = "00" else
                vc1FrameTxValid when currVc = "01" and NUM_VC_EN_G > 1 else
                vc2FrameTxValid when currVc = "10" and NUM_VC_EN_G > 2 else
                vc3FrameTxValid when currVc = "11" and NUM_VC_EN_G > 3 else
                '0';


   -- Arbitrate for the next VC value based upon current VC value and status of valid inputs
   process (currVc, vc0FrameTxValid, vc1FrameTxValid, vc2FrameTxValid, vc3FrameTxValid)
   begin
      case currVc is
         when "00" =>
            if vc1FrameTxValid = '1' and NUM_VC_EN_G > 1 then arbVc    <= "01"; arbValid <= '1';
            elsif vc2FrameTxValid = '1' and NUM_VC_EN_G > 2 then arbVc <= "10"; arbValid <= '1';
            elsif vc3FrameTxValid = '1' and NUM_VC_EN_G > 3 then arbVc <= "11"; arbValid <= '1';
            elsif vc0FrameTxValid = '1' then arbVc                     <= "00"; arbValid <= '1';
            else arbVc                                                 <= "00"; arbValid <= '0'; end if;
         when "01" =>
            if vc2FrameTxValid = '1' and NUM_VC_EN_G > 2 then arbVc    <= "10"; arbValid <= '1';
            elsif vc3FrameTxValid = '1' and NUM_VC_EN_G > 3 then arbVc <= "11"; arbValid <= '1';
            elsif vc0FrameTxValid = '1' then arbVc                     <= "00"; arbValid <= '1';
            elsif vc1FrameTxValid = '1' and NUM_VC_EN_G > 1 then arbVc <= "01"; arbValid <= '1';
            else arbVc                                                 <= "01"; arbValid <= '0'; end if;
         when "10" =>
            if vc3FrameTxValid = '1' and NUM_VC_EN_G > 3 then arbVc    <= "11"; arbValid <= '1';
            elsif vc0FrameTxValid = '1' then arbVc                     <= "00"; arbValid <= '1';
            elsif vc1FrameTxValid = '1' and NUM_VC_EN_G > 1 then arbVc <= "01"; arbValid <= '1';
            elsif vc2FrameTxValid = '1' and NUM_VC_EN_G > 2 then arbVc <= "10"; arbValid <= '1';
            else arbVc                                                 <= "10"; arbValid <= '0'; end if;
         when "11" =>
            if vc0FrameTxValid = '1' then arbVc                        <= "00"; arbValid <= '1';
            elsif vc1FrameTxValid = '1' and NUM_VC_EN_G > 1 then arbVc <= "01"; arbValid <= '1';
            elsif vc2FrameTxValid = '1' and NUM_VC_EN_G > 2 then arbVc <= "10"; arbValid <= '1';
            elsif vc3FrameTxValid = '1' and NUM_VC_EN_G > 3 then arbVc <= "11"; arbValid <= '1';
            else arbVc                                                 <= "11"; arbValid <= '0'; end if;
         when others =>
            arbVc <= "00"; arbValid <= '0';
      end case;
   end process;


   -- Lock in the status of the last cell transmitted
   process (pgpTxClk, pgpTxReset)
   begin
      if pgpTxReset = '1' then
         vcInFrame <= "0000" after tpd;
      elsif rising_edge(pgpTxClk) then

         -- Link is down or flush requested, reset status
         if pgpTxLinkReady = '0' or pgpTxFlush = '1' then
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

   -- Detect frame transmit timeout
   process (pgpTxClk, pgpTxReset)
   begin
      if pgpTxReset = '1' then
         vcTimerA  <= (others => '0') after tpd;
         vcTimerB  <= (others => '0') after tpd;
         vcTimerC  <= (others => '0') after tpd;
         vcTimerD  <= (others => '0') after tpd;
         vcTimeout <= (others => '0') after tpd;
      elsif rising_edge(pgpTxClk) then

         if vcInFrame(0) = '0' or (currVc = 0 and intTxReq = '1') then
            vcTimerA     <= (others => '0') after tpd;
            vcTimeout(0) <= '0'             after tpd;
         elsif vcTimerA /= x"FFFFFF" then
            vcTimerA     <= vcTimerA + 1 after tpd;
            vcTimeout(0) <= '0'          after tpd;
         else
            vcTimeout(0) <= '1' after tpd;
         end if;

         if NUM_VC_EN_G > 1 then
            if vcInFrame(1) = '0' or (currVc = 1 and intTxReq = '1') then
               vcTimerB     <= (others => '0') after tpd;
               vcTimeout(1) <= '0'             after tpd;
            elsif vcTimerB /= x"FFFFFF" then
               vcTimerB     <= vcTimerB + 1 after tpd;
               vcTimeout(1) <= '0'          after tpd;
            else
               vcTimeout(1) <= '1' after tpd;
            end if;
         end if;

         if NUM_VC_EN_G > 2 then
            if vcInFrame(2) = '0' or (currVc = 2 and intTxReq = '1') then
               vcTimerC     <= (others => '0') after tpd;
               vcTimeout(2) <= '0'             after tpd;
            elsif vcTimerC /= x"FFFFFF" then
               vcTimerC     <= vcTimerC + 1 after tpd;
               vcTimeout(2) <= '0'          after tpd;
            else
               vcTimeout(2) <= '1' after tpd;
            end if;
         end if;

         if NUM_VC_EN_G > 3 then
            if vcInFrame(3) = '0' or (currVc = 3 and intTxReq = '1') then
               vcTimerD     <= (others => '0') after tpd;
               vcTimeout(3) <= '0'             after tpd;
            elsif vcTimerD /= x"FFFFFF" then
               vcTimerD     <= vcTimerD + 1 after tpd;
               vcTimeout(3) <= '0'          after tpd;
            else
               vcTimeout(3) <= '1' after tpd;
            end if;
         end if;
      end if;
   end process;

end Pgp2TxSched;

