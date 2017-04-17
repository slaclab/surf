-------------------------------------------------------------------------------
-- File       : Pgp2bTxSched.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2009-05-27
-- Last update: 2017-03-28
-------------------------------------------------------------------------------
-- Description:
-- Transmit scheduler interface module for the Pretty Good Protocol core. 
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
use work.StdRtlPkg.all;
use work.Pgp2bPkg.all;

entity Pgp2bTxSched is
   generic (
      TPD_G           : time                 := 1 ns;
      VC_INTERLEAVE_G : integer              := 1;  -- Interleave Frames
      NUM_VC_EN_G     : integer range 1 to 4 := 4
      );
   port (

      -- System clock, reset & control
      pgpTxClkEn      : in  sl := '1';        -- Master clock Enable
      pgpTxClk        : in sl;                -- Master clock
      pgpTxClkRst     : in sl;                -- Synchronous reset input

      -- Link flush
      pgpTxFlush      : in sl;                -- Flush the link

      -- Link is ready
      pgpTxLinkReady  : in sl;                -- Local side has link

      -- Cell Transmit Interface
      schTxSOF        : in  sl;               -- Cell contained SOF
      schTxEOF        : in  sl;               -- Cell contained EOF
      schTxIdle       : out sl;               -- Force IDLE transmit
      schTxReq        : out sl;               -- Cell transmit request
      schTxAck        : in  sl;               -- Cell transmit acknowledge
      schTxTimeout    : out sl;               -- Cell transmit timeout
      schTxDataVc     : out slv(1 downto 0);  -- Cell transmit virtual channel

      -- VC Data Valid Signals
      vc0FrameTxValid : in sl;                -- User frame data is valid
      vc1FrameTxValid : in sl;                -- User frame data is valid
      vc2FrameTxValid : in sl;                -- User frame data is valid
      vc3FrameTxValid  : in sl;                -- User frame data is valid

      -- VC Flow Control Signals
      vc0RemAlmostFull : in sl;                -- Remote flow control
      vc1RemAlmostFull : in sl;                -- Remote flow control
      vc2RemAlmostFull : in sl;                -- Remote flow control
      vc3RemAlmostFull : in sl                 -- Remote flow control
   );

end Pgp2bTxSched;


-- Define architecture
architecture Pgp2bTxSched of Pgp2bTxSched is

   -- Local Signals
   signal currValid    : sl;
   signal currVc       : slv(1 downto 0);
   signal nextVc       : slv(1 downto 0);
   signal arbVc        : slv(1 downto 0);
   signal arbValid     : sl;
   signal vcInFrame    : slv(3 downto 0);
   signal intTxReq     : sl;
   signal intTxIdle    : sl;
   signal nxtTxReq     : sl;
   signal nxtTxIdle    : sl;
   signal nxtTxTimeout : sl;
   signal intTxTimeout : sl;
   signal vcTimerA     : slv(23 downto 0);
   signal vcTimerB     : slv(23 downto 0);
   signal vcTimerC     : slv(23 downto 0);
   signal vcTimerD     : slv(23 downto 0);
   signal vcTimeout    : slv(3 downto 0);
   signal gateTxValid  : slv(3 downto 0);

   -- Schedular state
   constant ST_RST_C   : slv(2 downto 0) := "001";
   constant ST_ARB_C   : slv(2 downto 0) := "010";
   constant ST_CELL_C  : slv(2 downto 0) := "011";
   constant ST_GAP_A_C : slv(2 downto 0) := "100";
   constant ST_GAP_B_C : slv(2 downto 0) := "101";
   constant ST_GAP_C_C : slv(2 downto 0) := "110";
   signal   curState   : slv(2 downto 0);
   signal   nxtState   : slv(2 downto 0);

begin

   -- Outgoing signals
   schTxReq     <= intTxReq;
   schTxIdle    <= intTxIdle;
   schTxDataVc  <= currVc;
   schTxTimeout <= intTxTimeout;


   -- State transition logic
   process (pgpTxClk)
   begin
      if rising_edge(pgpTxClk) then
         if pgpTxClkRst = '1' then
            curState     <= ST_ARB_C after TPD_G;
            currVc       <= "00"     after TPD_G;
            intTxReq     <= '0'      after TPD_G;
            intTxIdle    <= '0'      after TPD_G;
            intTxTimeout <= '0'      after TPD_G;
         elsif pgpTxClkEn = '1' then
            -- Force state to select state when link goes down
            if pgpTxLinkReady = '0' then
               curState <= ST_RST_C after TPD_G;
            else
               curState <= nxtState after TPD_G;
            end if;

            -- Control signals
            currVc       <= nextVc       after TPD_G;
            intTxReq     <= nxtTxReq     after TPD_G;
            intTxIdle    <= nxtTxIdle    after TPD_G;
            intTxTimeout <= nxtTxTimeout after TPD_G;

         end if;
      end if;
   end process;


   -- Scheduler state machine
   process (curState, arbValid, arbVc, currVc, schTxAck, vcInFrame, currValid, vcTimeout)
   begin
      case curState is

         -- Held in reset due to non-link
         when ST_RST_C =>
            nxtTxIdle    <= '0';
            nxtTxReq     <= '0';
            nxtTxTimeout <= '0';
            nextVc       <= (others => '0');
            nxtState     <= ST_ARB_C;

         -- IDLE, wait for ack receiver to be ready 
         when ST_ARB_C =>

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
            elsif VC_INTERLEAVE_G = 0 and vcInFrame(conv_integer(currVc)) = '1' then
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
            nxtState <= ST_CELL_C;

         -- Transmit Cell Data
         when ST_CELL_C =>
            nxtTxIdle    <= '0';
            nxtTxTimeout <= '0';
            nxtTxReq     <= '0';
            nextVc       <= currVc;

            -- Cell is done
            if schTxAck = '1' then
               nxtState <= ST_GAP_A_C;
            else
               nxtState <= curState;
            end if;

         -- Wait between cells
         when ST_GAP_A_C =>
            nxtTxIdle    <= '0';
            nxtTxReq     <= '0';
            nxtTxTimeout <= '0';
            nextVc       <= currVc;
            nxtState     <= ST_GAP_B_C;

         -- Wait between cells
         when ST_GAP_B_C =>
            nxtTxIdle    <= '0';
            nxtTxReq     <= '0';
            nxtTxTimeout <= '0';
            nextVc       <= currVc;
            nxtState     <= ST_GAP_C_C;

         -- Wait between cells
         when ST_GAP_C_C =>
            nxtTxIdle    <= '0';
            nxtTxReq     <= '0';
            nxtTxTimeout <= '0';
            nextVc       <= currVc;
            nxtState     <= ST_ARB_C;

         -- Just in case
         when others =>
            nxtTxIdle    <= '0';
            nxtTxReq     <= '0';
            nxtTxTimeout <= '0';
            nextVc       <= (others => '0');
            nxtState     <= ST_ARB_C;
      end case;
   end process;

   -- Gate valid signals based upon flow control
   gateTxValid(0) <= vc0FrameTxvalid and (not vc0RemAlmostFull);
   gateTxValid(1) <= vc1FrameTxvalid and (not vc1RemAlmostFull);
   gateTxValid(2) <= vc2FrameTxvalid and (not vc2RemAlmostFull);
   gateTxValid(3) <= vc3FrameTxvalid and (not vc3RemAlmostFull);

   -- Current owner has valid asserted
   currValid <= gateTxValid(0) when currVc = "00" else
                gateTxValid(1) when currVc = "01" and NUM_VC_EN_G > 1 else
                gateTxValid(2) when currVc = "10" and NUM_VC_EN_G > 2 else
                gateTxValid(3) when currVc = "11" and NUM_VC_EN_G > 3 else
                '0';


   -- Arbitrate for the next VC value based upon current VC value and status of valid inputs
   process (currVc, gateTxValid)
   begin
      case currVc is
         when "00" =>
            if    gateTxValid(1) = '1' and NUM_VC_EN_G > 1 then arbVc <= "01"; arbValid <= '1';
            elsif gateTxValid(2) = '1' and NUM_VC_EN_G > 2 then arbVc <= "10"; arbValid <= '1';
            elsif gateTxValid(3) = '1' and NUM_VC_EN_G > 3 then arbVc <= "11"; arbValid <= '1';
            elsif gateTxValid(0) = '1' then arbVc                     <= "00"; arbValid <= '1';
            else arbVc                                                 <= "00"; arbValid <= '0'; end if;
         when "01" =>
            if    gateTxValid(2) = '1' and NUM_VC_EN_G > 2 then arbVc <= "10"; arbValid <= '1';
            elsif gateTxValid(3) = '1' and NUM_VC_EN_G > 3 then arbVc <= "11"; arbValid <= '1';
            elsif gateTxValid(0) = '1' then arbVc                     <= "00"; arbValid <= '1';
            elsif gateTxValid(1) = '1' and NUM_VC_EN_G > 1 then arbVc <= "01"; arbValid <= '1';
            else arbVc                                                 <= "01"; arbValid <= '0'; end if;
         when "10" =>
            if    gateTxValid(3) = '1' and NUM_VC_EN_G > 3 then arbVc <= "11"; arbValid <= '1';
            elsif gateTxValid(0) = '1' then arbVc                     <= "00"; arbValid <= '1';
            elsif gateTxvalid(1) = '1' and NUM_VC_EN_G > 1 then arbVc <= "01"; arbValid <= '1';
            elsif gateTxvalid(2) = '1' and NUM_VC_EN_G > 2 then arbVc <= "10"; arbValid <= '1';
            else arbVc                                                 <= "10"; arbValid <= '0'; end if;
         when "11" =>
            if    gateTxValid(0) = '1' then arbVc                     <= "00"; arbValid <= '1';
            elsif gateTxValid(1) = '1' and NUM_VC_EN_G > 1 then arbVc <= "01"; arbValid <= '1';
            elsif gateTxValid(2) = '1' and NUM_VC_EN_G > 2 then arbVc <= "10"; arbValid <= '1';
            elsif gateTxValid(3) = '1' and NUM_VC_EN_G > 3 then arbVc <= "11"; arbValid <= '1';
            else arbVc                                                 <= "11"; arbValid <= '0'; end if;
         when others =>
            arbVc <= "00"; arbValid <= '0';
      end case;
   end process;


   -- Lock in the status of the last cell transmitted
   process (pgpTxClk)
   begin
      if rising_edge(pgpTxClk) then
         if pgpTxClkRst = '1' then
            vcInFrame <= "0000" after TPD_G;
         elsif pgpTxClkEn = '1' then
            -- Link is down or flush requested, reset status
            if pgpTxLinkReady = '0' or pgpTxFlush = '1' then
               vcInFrame <= "0000" after TPD_G;
            else

               -- Update state of VC, track if VC is currently in frame or not
               -- SOF transmitted
               if schTxSOF = '1' then
                  vcInFrame(conv_integer(currVc)) <= '1' after TPD_G;

               -- EOF transmitted
               elsif schTxEOF = '1' then
                  vcInFrame(conv_integer(currVc)) <= '0' after TPD_G;
               end if;
            end if;
         end if;
      end if;
   end process;

   -- Detect frame transmit timeout, enabled only in VC non interleave mode
   process (pgpTxClk)
   begin
      if rising_edge(pgpTxClk) then
         if pgpTxClkRst = '1' or VC_INTERLEAVE_G = 1 then
            vcTimerA  <= (others => '0') after TPD_G;
            vcTimerB  <= (others => '0') after TPD_G;
            vcTimerC  <= (others => '0') after TPD_G;
            vcTimerD  <= (others => '0') after TPD_G;
            vcTimeout <= (others => '0') after TPD_G;
         elsif pgpTxClkEn = '1' then
            if vcInFrame(0) = '0' or (currVc = 0 and intTxReq = '1') then
               vcTimerA     <= (others => '0') after TPD_G;
               vcTimeout(0) <= '0'             after TPD_G;
            elsif vcTimerA /= x"FFFFFF" then
               vcTimerA     <= vcTimerA + 1 after TPD_G;
               vcTimeout(0) <= '0'          after TPD_G;
            else
               vcTimeout(0) <= '1' after TPD_G;
            end if;

            if NUM_VC_EN_G > 1 then
               if vcInFrame(1) = '0' or (currVc = 1 and intTxReq = '1') then
                  vcTimerB     <= (others => '0') after TPD_G;
                  vcTimeout(1) <= '0'             after TPD_G;
               elsif vcTimerB /= x"FFFFFF" then
                  vcTimerB     <= vcTimerB + 1 after TPD_G;
                  vcTimeout(1) <= '0'          after TPD_G;
               else
                  vcTimeout(1) <= '1' after TPD_G;
               end if;
            end if;

            if NUM_VC_EN_G > 2 then
               if vcInFrame(2) = '0' or (currVc = 2 and intTxReq = '1') then
                  vcTimerC     <= (others => '0') after TPD_G;
                  vcTimeout(2) <= '0'             after TPD_G;
               elsif vcTimerC /= x"FFFFFF" then
                  vcTimerC     <= vcTimerC + 1 after TPD_G;
                  vcTimeout(2) <= '0'          after TPD_G;
               else
                  vcTimeout(2) <= '1' after TPD_G;
               end if;
            end if;

            if NUM_VC_EN_G > 3 then
               if vcInFrame(3) = '0' or (currVc = 3 and intTxReq = '1') then
                  vcTimerD     <= (others => '0') after TPD_G;
                  vcTimeout(3) <= '0'             after TPD_G;
               elsif vcTimerD /= x"FFFFFF" then
                  vcTimerD     <= vcTimerD + 1 after TPD_G;
                  vcTimeout(3) <= '0'          after TPD_G;
               else
                  vcTimeout(3) <= '1' after TPD_G;
               end if;
            end if;
         end if;
      end if;
   end process;

end Pgp2bTxSched;

