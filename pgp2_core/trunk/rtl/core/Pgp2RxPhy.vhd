---------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol V2, Physical Interface Receive Module
-- Project       : General Purpose Core
---------------------------------------------------------------------------------
-- File          : Pgp2RxPhy.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/18/2009
---------------------------------------------------------------------------------
-- Description:
-- Physical interface receive module for the Pretty Good Protocol version 2 core. 
---------------------------------------------------------------------------------
-- Copyright (c) 2006 by Ryan Herbst. All rights reserved.
---------------------------------------------------------------------------------
-- Modification history:
-- 05/18/2009: created.
-- 11/23/2009: Renamed package.
-- 01/13/2010: Added init of reset controller if failed to link after 1023 clocks.
--             fixed bug in dealing with an inverted receive link.
-- 02/01/2011: Rem data and rem link not updated if EOF fields don't match.
---------------------------------------------------------------------------------

LIBRARY ieee;
--USE work.ALL;
USE work.Pgp2CorePackage.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Pgp2RxPhy is 
   generic (
      RxLaneCnt : integer  := 4  -- Number of receive lanes, 1-4
   );
   port ( 

      -- System clock, reset & control
      pgpRxClk          : in  std_logic;                                 -- Master clock
      pgpRxReset        : in  std_logic;                                 -- Synchronous reset input

      -- Link is ready
      pgpRxLinkReady    : out std_logic;                                 -- Local side has link

      -- Error Flags, one pulse per event
      pgpRxLinkDown     : out std_logic;                                 -- A link down event has occured
      pgpRxLinkError    : out std_logic;                                 -- A link error has occured

      -- Opcode Receive Interface
      pgpRxOpCodeEn     : out std_logic;                                 -- Opcode receive enable
      pgpRxOpCode       : out std_logic_vector(7 downto 0);              -- Opcode receive value

      -- Sideband data
      pgpRemLinkReady   : out std_logic;                                 -- Far end side has link
      pgpRemData        : out std_logic_vector(7 downto 0);              -- Far end side User Data

      -- Cell Receive Interface
      cellRxPause       : out std_logic;                                 -- Cell data pause
      cellRxSOC         : out std_logic;                                 -- Cell data start of cell
      cellRxSOF         : out std_logic;                                 -- Cell data start of frame
      cellRxEOC         : out std_logic;                                 -- Cell data end of cell
      cellRxEOF         : out std_logic;                                 -- Cell data end of frame
      cellRxEOFE        : out std_logic;                                 -- Cell data end of frame error
      cellRxData        : out std_logic_vector(RxLaneCnt*16-1 downto 0); -- Cell data data

      -- Physical Interface Signals
      phyRxPolarity     : out std_logic_vector(RxLaneCnt-1    downto 0); -- PHY receive signal polarity
      phyRxData         : in  std_logic_vector(RxLaneCnt*16-1 downto 0); -- PHY receive data
      phyRxDataK        : in  std_logic_vector(RxLaneCnt*2-1  downto 0); -- PHY receive data is K character
      phyRxDispErr      : in  std_logic_vector(RxLaneCnt*2-1  downto 0); -- PHY receive data has disparity error
      phyRxDecErr       : in  std_logic_vector(RxLaneCnt*2-1  downto 0); -- PHY receive data not in table
      phyRxReady        : in  std_logic;                                 -- PHY receive interface is ready
      phyRxInit         : out std_logic;                                 -- PHY receive interface init;

      -- Debug
      debug             : out std_logic_vector(63 downto 0)
   ); 

end Pgp2RxPhy;


-- Define architecture
architecture Pgp2RxPhy of Pgp2RxPhy is

   -- Local Signals
   signal dly0RxData          : std_logic_vector(RxLaneCnt*16-1 downto 0);
   signal dly0RxDataK         : std_logic_vector(RxLaneCnt*2-1  downto 0);
   signal dly0RxDispErr       : std_logic_vector(RxLaneCnt*2-1  downto 0);
   signal dly0RxDecErr        : std_logic_vector(RxLaneCnt*2-1  downto 0);
   signal dly1RxData          : std_logic_vector(RxLaneCnt*16-1 downto 0);
   signal dly1RxDataK         : std_logic_vector(RxLaneCnt*2-1  downto 0);
   signal dly1RxDispErr       : std_logic_vector(RxLaneCnt*2-1  downto 0);
   signal dly1RxDecErr        : std_logic_vector(RxLaneCnt*2-1  downto 0);
   signal rxDetectLts         : std_logic;
   signal rxDetectLtsOk       : std_logic;
   signal rxDetectLtsRaw      : std_logic_vector(3 downto 0);
   signal rxDetectInvert      : std_logic_vector(RxLaneCnt-1 downto 0);
   signal rxDetectInvertRaw   : std_logic_vector(RxLaneCnt-1 downto 0);
   signal rxDetectRemLink     : std_logic;
   signal rxDetectRemData     : std_logic_vector(7 downto 0);
   signal rxDetectOpCodeEn    : std_logic;
   signal rxDetectOpCodeEnRaw : std_logic_vector(3 downto 0);
   signal rxDetectSOC         : std_logic;
   signal rxDetectSOCRaw      : std_logic_vector(3 downto 0);
   signal rxDetectSOF         : std_logic;
   signal rxDetectSOFRaw      : std_logic_vector(3 downto 0);
   signal rxDetectEOC         : std_logic;
   signal rxDetectEOCRaw      : std_logic_vector(3 downto 0);
   signal rxDetectEOF         : std_logic;
   signal rxDetectEOFRaw      : std_logic_vector(3 downto 0);
   signal rxDetectEOFE        : std_logic;
   signal rxDetectEOFERaw     : std_logic_vector(3 downto 0);
   signal nxtRxLinkReady      : std_logic;
   signal stateCntRst         : std_logic;
   signal stateCnt            : std_logic_vector(19 downto 0);
   signal ltsCntRst           : std_logic;
   signal ltsCntEn            : std_logic;
   signal ltsCnt              : std_logic_vector(7 downto 0);
   signal intRxLinkReady      : std_logic;
   signal intRxPolarity       : std_logic_vector(RxLaneCnt-1 downto 0);
   signal nxtRxPolarity       : std_logic_vector(RxLaneCnt-1 downto 0);
   signal dlyRxLinkDown       : std_logic;
   signal intRxLinkError      : std_logic;
   signal dlyRxLinkError      : std_logic;
   signal intRxInit           : std_logic;
   signal nxtRxInit           : std_logic;
   signal dbgRxData           : std_logic_vector(31 downto 0);
   signal dbgRxDataK          : std_logic_vector(3  downto 0);
   signal dbgInvert           : std_logic_vector(1  downto 0);
   signal dbgPolarity         : std_logic_vector(1  downto 0);
   signal dbgRxDispErr        : std_logic_vector(3  downto 0);
   signal dbgRxDecErr         : std_logic_vector(3  downto 0);

   -- Physical Link State
   constant ST_RESET : std_logic_vector(2 downto 0) := "001";
   constant ST_LOCK  : std_logic_vector(2 downto 0) := "010";
   constant ST_WAIT  : std_logic_vector(2 downto 0) := "011";
   constant ST_INVRT : std_logic_vector(2 downto 0) := "100";
   constant ST_READY : std_logic_vector(2 downto 0) := "101";
   signal   curState : std_logic_vector(2 downto 0);
   signal   nxtState : std_logic_vector(2 downto 0);

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   -- Link status
   pgpRxLinkReady    <= intRxLinkReady;

   -- RX Interface Init
   phyRxInit         <= intRxInit;

   -- Opcode Receive Interface
   pgpRxOpCodeEn     <= rxDetectOpCodeEn;
   pgpRxOpCode       <= dly1RxData(15 downto 8);

   -- Cell Receive Interface
   cellRxPause       <= rxDetectOpCodeEn;
   cellRxSOC         <= rxDetectSOC;
   cellRxSOF         <= rxDetectSOF;
   cellRxEOC         <= rxDetectEOC;
   cellRxEOF         <= rxDetectEOF;
   cellRxEOFE        <= rxDetectEOFE;
   cellRxData        <= dly1RxData;

   -- Drive active polarity control signals
   GEN_POL: for i in 0 to (RxLaneCnt-1) generate
      phyRxPolarity(i) <= intRxPolarity(i);
   end generate;

   -- State transition sync logic. 
   process ( pgpRxClk, pgpRxReset ) begin
      if pgpRxReset = '1' then
         curState        <= ST_RESET      after tpd;
         stateCnt        <= (others=>'0') after tpd;
         ltsCnt          <= (others=>'0') after tpd;
         intRxLinkReady  <= '0'           after tpd;
         intRxPolarity   <= (others=>'0') after tpd;
         dlyRxLinkDown   <= '0'           after tpd;
         pgpRxLinkDown   <= '0'           after tpd;
         intRxLinkError  <= '0'           after tpd;
         dlyRxLinkError  <= '0'           after tpd;
         pgpRxLinkError  <= '0'           after tpd;
         intRxInit       <= '0'           after tpd;
         pgpRemLinkReady <= '0'           after tpd;
         pgpRemData      <= (others=>'0') after tpd;
      elsif rising_edge(pgpRxClk) then

         -- Sideband data
         if intRxLinkReady = '1' then
            pgpRemLinkReady <= rxDetectRemLink;
            pgpRemData      <= rxDetectRemData;
         else
            pgpRemLinkReady <= '0'           after tpd;
            pgpRemData      <= (others=>'0') after tpd;
         end if;

         -- Link down edge detection
         dlyRxLinkDown  <= (not intRxLinkReady) after tpd;
         pgpRxLinkDown  <= (not intRxLinkReady) and (not dlyRxLinkDown) after tpd;

         -- Link error generation
         if (phyRxDispErr /= 0 or phyRxDecErr /= 0) and intRxLinkReady = '1' then 
            intRxLinkError <= '1' after tpd;
         else
            intRxLinkError <= '0' after tpd;
         end if;

         -- Link error edge detection
         dlyRxLinkError <= intRxLinkError after tpd;
         pgpRxLinkError <= intRxLinkError and not dlyRxLinkError after tpd;

         -- Status signals
         intRxLinkReady  <= nxtRxLinkReady after tpd;
         intRxPolarity   <= nxtRxPolarity  after tpd;
         intRxInit       <= nxtRxInit      after tpd;

         -- State transition
         curState <= nxtState after tpd;

         -- In state counter
         if stateCntRst = '1' then
            stateCnt <= (others=>'0') after tpd;
         else
            stateCnt <= stateCnt + 1 after tpd;
         end if;

         -- LTS Counter
         if ltsCntRst = '1' then
            ltsCnt <= (others=>'0') after tpd;
         elsif ltsCntEn = '1' and ltsCnt /= 255 then
            ltsCnt <= ltsCnt + 1 after tpd;
         end if;

      end if;
   end process;


   -- Link control state machine
   process ( curState, stateCnt, ltsCnt, rxDetectLts, rxDetectLtsOk, 
             rxDetectInvert, intRxPolarity, phyRxReady, phyRxDecErr, phyRxDispErr ) begin
      case curState is 

         -- Hold in rx reset for 8 clocks
         when ST_RESET =>
            nxtRxLinkReady  <= '0';
            nxtRxPolarity   <= (others=>'0');
            ltsCntRst       <= '1';
            ltsCntEn        <= '0';
            nxtRxInit       <= '1';

            -- Hold reset for 255 clocks
            if stateCnt(7 downto 0) = 255 then
               stateCntRst <= '1';
               nxtState    <= ST_LOCK;
            else
               stateCntRst <= '0';
               nxtState    <= curState;
            end if;

         -- Wait for lock state
         when ST_LOCK =>
            nxtRxLinkReady  <= '0';
            nxtRxPolarity   <= (others=>'0');
            ltsCntRst       <= '1';
            ltsCntEn        <= '0';
            nxtRxInit       <= '0';

            -- Wait for lock
            if phyRxReady = '1' then
               nxtState    <= ST_WAIT;
               stateCntRst <= '1';

            -- Terminal count without lock
            elsif stateCnt = x"FFFFF" then
               nxtState    <= ST_RESET;
               stateCntRst <= '1';
            else
               nxtState    <= curState;
               stateCntRst <= '0';
            end if;

         -- Wait for training pattern
         when ST_WAIT =>
            nxtRxLinkReady <= '0';
            nxtRxInit      <= '0';

            -- Lock is lost
            if phyRxReady = '0' then
               stateCntRst   <= '1';
               ltsCntEn      <= '0';
               ltsCntRst     <= '0';
               nxtRxPolarity <= intRxPolarity;
               nxtState      <= ST_RESET;

            -- Decode or disparity error, clear lts count
            elsif phyRxReady = '0' or phyRxDispErr /= 0 or phyRxDecErr /= 0 then
               stateCntRst   <= '0';
               ltsCntEn      <= '0';
               ltsCntRst     <= '1';
               nxtRxPolarity <= intRxPolarity;
               nxtState      <= curState;

            -- Training pattern seen
            elsif rxDetectLts = '1' then
               stateCntRst <= '1';

               -- No Inversion
               if rxDetectInvert = 0 then
                  nxtRxPolarity <= intRxPolarity;
                  nxtState      <= curState;

                  -- ID & Lane Count Ok
                  if rxDetectLtsOk = '1' then
                     ltsCntEn  <= '1';
                     ltsCntRst <= '0';
                  else
                     ltsCntEn  <= '0';
                     ltsCntRst <= '1';
                  end if;

               -- Inverted
               else
                  ltsCntEn      <= '0';
                  ltsCntRst     <= '1';
                  nxtRxPolarity <= intRxPolarity xor rxDetectInvert;
                  nxtState      <= ST_INVRT;
               end if;
            
            -- Run after we have seen 256 non-inverted training sequences
            -- without any disparity or decode errors.
            elsif ltsCnt = 255 then
               stateCntRst   <= '1';
               ltsCntEn      <= '0';
               ltsCntRst     <= '1';
               nxtRxPolarity <= intRxPolarity;
               nxtState      <= ST_READY;

            -- Terminal count without seeing a valid LTS
            elsif stateCnt = x"FFFFF" then
               stateCntRst   <= '1';
               ltsCntEn      <= '0';
               ltsCntRst     <= '1';
               nxtRxPolarity <= intRxPolarity;
               nxtState      <= ST_RESET;

            -- Count cycles without LTS
            else
               stateCntRst   <= '0';
               ltsCntEn      <= '0';
               ltsCntRst     <= '0';
               nxtRxPolarity <= intRxPolarity;
               nxtState      <= curState;
            end if;

         -- Wait a few clocks after inverting receive interface
         when ST_INVRT =>
            nxtRxLinkReady  <= '0';
            nxtRxPolarity   <= intRxPolarity;
            ltsCntRst       <= '1';
            ltsCntEn        <= '0';
            nxtRxInit       <= '0';

            -- Wait 128 clocks
            if stateCnt(6 downto 0) = 127 then
               nxtState    <= ST_WAIT;
               stateCntRst <= '1';
            else
               nxtState    <= curState;
               stateCntRst <= '0';
            end if;

         -- Ready
         when ST_READY =>
            nxtRxLinkReady <= '1';
            nxtRxPolarity  <= intRxPolarity;
            ltsCntRst      <= '1';
            ltsCntEn       <= '0';
            nxtRxInit      <= '0';

            -- Lock is lost
            if phyRxReady = '0' then
               nxtState    <= ST_RESET;
               stateCntRst <= '1';

            -- Training sequence seen
            elsif rxDetectLts = '1' then

               -- Link is inverted or bad lts, reset and relink
               if rxDetectInvert /= 0 or rxDetectLtsOk = '0' then
                  nxtState    <= ST_RESET;
                  stateCntRst <= '1';

               -- Good LTS
               else
                  nxtState    <= curState;
                  stateCntRst <= '1';
               end if;

            -- Link is down after long period without seeing a LTS
            -- Min spacing of LTS is 2 Cells = 2 * 256 = 512
            -- Timeout set at 4096 = 8 cells
            elsif stateCnt(11 downto 0) = x"FFF" then
               nxtState    <= ST_RESET;
               stateCntRst <= '1';
            
            -- Count cycles without LTS
            else
               nxtState    <= curState;
               stateCntRst <= '0';
            end if;

         -- Default
         when others =>
            nxtRxLinkReady <= '0';
            nxtRxPolarity  <= (others=>'0');
            stateCntRst    <= '0';
            ltsCntRst      <= '0';
            ltsCntEn       <= '0';
            nxtRxInit      <= '0';
            nxtState       <= ST_LOCK;
      end case;
   end process;


   -- Receive data pipeline
   process ( pgpRxClk, pgpRxReset ) begin
      if pgpRxReset = '1' then
         dly0RxData    <= (others=>'0') after tpd;
         dly0RxDataK   <= (others=>'0') after tpd;
         dly0RxDispErr <= (others=>'0') after tpd;
         dly0RxDecErr  <= (others=>'0') after tpd;
         dly1RxData    <= (others=>'0') after tpd;
         dly1RxDataK   <= (others=>'0') after tpd;
         dly1RxDispErr <= (others=>'0') after tpd;
         dly1RxDecErr  <= (others=>'0') after tpd;
      elsif rising_edge(pgpRxClk) then
         dly0RxData    <= phyRxData     after tpd;
         dly0RxDataK   <= phyRxDataK    after tpd;
         dly0RxDispErr <= phyRxDispErr  after tpd;
         dly0RxDecErr  <= phyRxDecErr   after tpd;
         dly1RxData    <= dly0RxData    after tpd;
         dly1RxDataK   <= dly0RxDataK   after tpd;
         dly1RxDispErr <= dly0RxDispErr after tpd;
         dly1RxDecErr  <= dly0RxDecErr  after tpd;
      end if;
   end process;


   -- Link init ordered set detect
   process ( pgpRxClk, pgpRxReset ) begin
      if pgpRxReset = '1' then
         rxDetectLts       <= '0'           after tpd;
         rxDetectLtsOk     <= '0'           after tpd;
         rxDetectInvert    <= (others=>'0') after tpd;
         rxDetectRemLink   <= '0'           after tpd;
         rxDetectRemData   <= (others=>'0') after tpd;
         rxDetectOpCodeEn  <= '0'           after tpd;
         rxDetectSOC       <= '0'           after tpd;
         rxDetectSOF       <= '0'           after tpd;
         rxDetectEOC       <= '0'           after tpd;
         rxDetectEOF       <= '0'           after tpd;
         rxDetectEOFE      <= '0'           after tpd;
      elsif rising_edge(pgpRxClk) then

         -- LTS is detected when phy is ready
         if phyRxReady = '1' then

            -- Detect link init ordered sets
            if rxDetectLtsRaw(0) = '1' and 
               ( rxDetectLtsRaw(1) = '1' or RxLaneCnt < 2 ) and
               ( rxDetectLtsRaw(2) = '1' or RxLaneCnt < 3 ) and
               ( rxDetectLtsRaw(3) = '1' or RxLaneCnt < 4 ) then
               rxDetectInvert  <= rxDetectInvertRaw after tpd;
               rxDetectLts     <= '1'               after tpd;

               -- Lane count and ID must match
               if dly0RxData(13 downto 12) = conv_std_logic_vector(RxLaneCnt-1,2) and
                  dly0RxData(11 downto  8) = Pgp2Id then
                  rxDetectLtsOk   <= '1'                      after tpd;
                  rxDetectRemLink <= dly0RxData(15)           after tpd;
                  rxDetectRemData <= dly0RxData(7  downto  0) after tpd;
               else
                  rxDetectLtsOk <= '0' after tpd;
               end if;
            else
               rxDetectLts     <= '0' after tpd;
               rxDetectLtsOk   <= '0' after tpd;
            end if;
         else
            rxDetectLts       <= '0'           after tpd;
            rxDetectLtsOk     <= '0'           after tpd;
            rxDetectInvert    <= (others=>'0') after tpd;
            rxDetectRemLink   <= '0'           after tpd;
            rxDetectRemData   <= (others=>'0') after tpd;
         end if;

         -- The remaining opcodes are only detected when the link is up
         if intRxLinkReady = '1' then

            -- Detect opCode ordered set
            if rxDetectOpCodeEnRaw(0) = '1' and 
               ( rxDetectOpCodeEnRaw(1) = '1' or RxLaneCnt < 2 ) and
               ( rxDetectOpCodeEnRaw(2) = '1' or RxLaneCnt < 3 ) and
               ( rxDetectOpCodeEnRaw(3) = '1' or RxLaneCnt < 4 ) then
               rxDetectOpCodeEn <= '1' after tpd;
            else
               rxDetectOpCodeEn <= '0' after tpd;
            end if;

            -- Detect SOC ordered set
            if rxDetectSOCRaw(0) = '1' and 
               ( rxDetectSOCRaw(1) = '1' or RxLaneCnt < 2 ) and
               ( rxDetectSOCRaw(2) = '1' or RxLaneCnt < 3 ) and
               ( rxDetectSOCRaw(3) = '1' or RxLaneCnt < 4 ) then
               rxDetectSOC <= '1' after tpd;
               rxDetectSOF <= '0' after tpd;

            -- Detect SOF ordered set
            elsif rxDetectSOFRaw(0) = '1' and 
               ( rxDetectSOFRaw(1) = '1' or RxLaneCnt < 2 ) and
               ( rxDetectSOFRaw(2) = '1' or RxLaneCnt < 3 ) and
               ( rxDetectSOFRaw(3) = '1' or RxLaneCnt < 4 ) then
               rxDetectSOC <= '1' after tpd;
               rxDetectSOF <= '1' after tpd;
            else
               rxDetectSOC <= '0' after tpd;
               rxDetectSOF <= '0' after tpd;
            end if;

            -- Detect EOC ordered set
            if rxDetectEOCRaw(0) = '1' and 
               ( rxDetectEOCRaw(1) = '1' or RxLaneCnt < 2 ) and
               ( rxDetectEOCRaw(2) = '1' or RxLaneCnt < 3 ) and
               ( rxDetectEOCRaw(3) = '1' or RxLaneCnt < 4 ) then
               rxDetectEOC  <= '1' after tpd;
               rxDetectEOF  <= '0' after tpd;
               rxDetectEOFE <= '0' after tpd;

            -- Detect EOF ordered set
            elsif rxDetectEOFRaw(0) = '1' and 
               ( rxDetectEOFRaw(1) = '1' or RxLaneCnt < 2 ) and
               ( rxDetectEOFRaw(2) = '1' or RxLaneCnt < 3 ) and
               ( rxDetectEOFRaw(3) = '1' or RxLaneCnt < 4 ) then
               rxDetectEOC  <= '1' after tpd;
               rxDetectEOF  <= '1' after tpd;
               rxDetectEOFE <= '0' after tpd;

            -- Detect EOFE ordered set
            elsif rxDetectEOFERaw(0) = '1' and 
               ( rxDetectEOFERaw(1) = '1' or RxLaneCnt < 2 ) and
               ( rxDetectEOFERaw(2) = '1' or RxLaneCnt < 3 ) and
               ( rxDetectEOFERaw(3) = '1' or RxLaneCnt < 4 ) then
               rxDetectEOC  <= '1' after tpd;
               rxDetectEOF  <= '1' after tpd;
               rxDetectEOFE <= '1' after tpd;
            else
               rxDetectEOC  <= '0' after tpd;
               rxDetectEOF  <= '0' after tpd;
               rxDetectEOFE <= '0' after tpd;
            end if;
         else
            rxDetectOpCodeEn  <= '0'           after tpd;
            rxDetectSOC       <= '0'           after tpd;
            rxDetectSOF       <= '0'           after tpd;
            rxDetectEOC       <= '0'           after tpd;
            rxDetectEOF       <= '0'           after tpd;
            rxDetectEOFE      <= '0'           after tpd;
         end if;
      end if;
   end process;

   -- Generate Loop
   GEN_LANES: for i in 0 to (RxLaneCnt-1) generate

      -- Ordered Set Detection
      process ( dly1RxDataK, dly1RxData, dly0RxDataK, dly0RxData, phyRxDispErr, phyRxDecErr ) begin

         -- Skip errored decodes
         if phyRxDispErr(i*2) = '0' and phyRxDispErr(i*2+1) = '0' and 
            phyRxDecErr(i*2)  = '0' and phyRxDecErr(i*2+1)  = '0' then

            -- Link init ordered set
            if ( dly1RxDataK(i*2) = '1' and dly1RxDataK(i*2+1) = '0' and
                 dly0RxDataK(i*2) = '0' and dly0RxDataK(i*2+1) = '0' and
                 dly1RxData(i*16+7 downto i*16) = K_LTS and
                 ( dly1RxData(i*16+15 downto i*16+8) = D_102 or dly1RxData(i*16+15 downto i*16+8) = D_215 ) ) then
               rxDetectLtsRaw(i) <= '1';

               -- Detect Link Inversion
               if dly1RxData(i*16+15 downto i*16+8) = D_102 then
                  rxDetectInvertRaw(i) <= '0';
               else
                  rxDetectInvertRaw(i) <= '1';
               end if;
            else
               rxDetectLtsRaw(i)    <= '0';
               rxDetectInvertRaw(i) <= '0';
            end if;

            -- OpCode Enable
            if ( dly0RxDataK(i*2) = '1' and dly0RxDataK(i*2+1) = '0' and dly0RxData(i*16+7 downto i*16) = K_OTS ) then
               rxDetectOpCodeEnRaw(i) <= '1';
            else
               rxDetectOpCodeEnRaw(i) <= '0';
            end if;

            -- SOC Detect
            if ( dly0RxDataK(i*2) = '1' and dly0RxDataK(i*2+1) = '0' and dly0RxData(i*16+7 downto i*16) = K_SOC ) then
               rxDetectSOCRaw(i) <= '1';
            else
               rxDetectSOCRaw(i) <= '0';
            end if;

            -- SOF Detect
            if ( dly0RxDataK(i*2) = '1' and dly0RxDataK(i*2+1) = '0' and dly0RxData(i*16+7 downto i*16) = K_SOF ) then
               rxDetectSOFRaw(i) <= '1';
            else
               rxDetectSOFRaw(i) <= '0';
            end if;

            -- EOC Detect
            if ( dly0RxDataK(i*2) = '1' and dly0RxDataK(i*2+1) = '0' and dly0RxData(i*16+7 downto i*16) = K_EOC ) then
               rxDetectEOCRaw(i) <= '1';
            else
               rxDetectEOCRaw(i) <= '0';
            end if;

            -- EOF Detect
            if ( dly0RxDataK(i*2) = '1' and dly0RxDataK(i*2+1) = '0' and dly0RxData(i*16+7 downto i*16) = K_EOF ) then
               rxDetectEOFRaw(i) <= '1';
            else
               rxDetectEOFRaw(i) <= '0';
            end if;

            -- EOFE Detect
            if ( dly0RxDataK(i*2) = '1' and dly0RxDataK(i*2+1) = '0' and dly0RxData(i*16+7 downto i*16) = K_EOFE ) then
               rxDetectEOFERaw(i) <= '1';
            else
               rxDetectEOFERaw(i) <= '0';
            end if;
         else
            rxDetectLtsRaw(i)      <= '0';
            rxDetectInvertRaw(i)   <= '0';
            rxDetectOpCodeEnRaw(i) <= '0';
            rxDetectSOCRaw(i)      <= '0';
            rxDetectSOFRaw(i)      <= '0';
            rxDetectEOCRaw(i)      <= '0';
            rxDetectEOFRaw(i)      <= '0';
            rxDetectEOFERaw(i)     <= '0';
         end if;
      end process;
   end generate;

   -- Generate Loop for unused lanes
   GEN_SPARE: for i in RxLaneCnt to 3 generate
      rxDetectLtsRaw(i)       <= '0';
      rxDetectOpCodeEnRaw(i)  <= '0';
      rxDetectSOCRaw(i)       <= '0';
      rxDetectSOFRaw(i)       <= '0';
      rxDetectEOCRaw(i)       <= '0';
      rxDetectEOFRaw(i)       <= '0';
      rxDetectEOFERaw(i)      <= '0';
   end generate;

   -----------------------------
   -- Debug
   -----------------------------

   -- Upper debug bits
   GEN_DBGA: if RxLaneCnt > 1 generate
      dbgInvert(1)             <= rxDetectInvert(1);
      dbgPolarity(1)           <= intRxPolarity(1);
      dbgRxDataK(3 downto 2)   <= dly0RxDataK(3 downto 2);
      dbgRxData(31 downto 16)  <= dly0RxData(31 downto 16);
      dbgRxDispErr(3 downto 2) <= phyRxDispErr(3 downto 2);
      dbgRxDecErr(3 downto 2)  <= phyRxDecErr(3 downto 2);
   end generate;
   GEN_DBGB: if RxLaneCnt = 1 generate
      dbgInvert(1)             <= '0';
      dbgPolarity(1)           <= '0';
      dbgRxDataK(3 downto 2)   <= (others=>'0');
      dbgRxData(31 downto 16)  <= (others=>'0');
      dbgRxDispErr(3 downto 2) <= (others=>'0');
      dbgRxDecErr(3 downto 2)  <= (others=>'0');
   end generate;
   dbgInvert(0)             <= rxDetectInvert(0);
   dbgPolarity(0)           <= intRxPolarity(0);
   dbgRxDataK(1 downto 0)   <= dly0RxDataK(1 downto 0);
   dbgRxData(15 downto 0)   <= dly0RxData(15 downto 0);
   dbgRxDispErr(1 downto 0) <= phyRxDispErr(1 downto 0);
   dbgRxDecErr(1 downto 0)  <= phyRxDecErr(1 downto 0);

   -- Debug
   debug(63 downto 32) <= dbgRxData;
   debug(31 downto 28) <= dbgRxDataK;
   debug(27 downto 26) <= dbgInvert;
   debug(25 downto 24) <= dbgPolarity;
   debug(23 downto 21) <= curState;
   debug(20)           <= ltsCntEn;
   debug(19)           <= ltsCntRst;
   debug(18)           <= rxDetectSOF;
   debug(17)           <= rxDetectEOF;
   debug(16)           <= phyRxReady;
   debug(15 downto 12) <= dbgRxDispErr;
   debug(11 downto  8) <= dbgRxDecErr;
   debug(7)            <= rxDetectRemLink;
   debug(6)            <= intRxInit;
   debug(5)            <= rxDetectSOC;
   debug(4)            <= rxDetectEOC;
   debug(3)            <= rxDetectLtsOk;
   debug(2)            <= rxDetectLts;
   debug(1)            <= rxDetectOpCodeEn;
   debug(0)            <= intRxLinkReady;

end Pgp2RxPhy;

