-------------------------------------------------------------------------------
-- File       : Pgp2bRxPhy.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2009-05-27
-- Last update: 2017-03-28
-------------------------------------------------------------------------------
-- Description:
-- Physical interface receive module for the Pretty Good Protocol version 2 core. 
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

entity Pgp2bRxPhy is
   generic (
      TPD_G         : time                 := 1 ns;
      RX_LANE_CNT_G : integer range 1 to 2 := 1  -- Number of receive lanes, 1-2
      );
   port (

      -- System clock, reset & control
      pgpRxClkEn  : in sl := '1';       -- Master clock Enable
      pgpRxClk    : in sl;              -- Master clock
      pgpRxClkRst : in sl;              -- Synchronous reset input

      -- Link is ready
      pgpRxLinkReady : out sl;          -- Local side has link

      -- Error Flags, one pulse per event
      pgpRxLinkDown  : out sl := '0';   -- A link down event has occured
      pgpRxLinkError : out sl := '0';   -- A link error has occured

      -- Opcode Receive Interface
      pgpRxOpCodeEn : out sl;               -- Opcode receive enable
      pgpRxOpCode   : out slv(7 downto 0);  -- Opcode receive value

      -- Sideband data
      pgpRemLinkReady : out sl              := '0';              -- Far end side has link
      pgpRemData      : out slv(7 downto 0) := (others => '0');  -- Far end side User Data

      -- Cell Receive Interfac e
      cellRxPause : out sl;                                -- Cell data pause
      cellRxSOC   : out sl;                                -- Cell data start of cell
      cellRxSOF   : out sl;                                -- Cell data start of frame
      cellRxEOC   : out sl;                                -- Cell data end of cell
      cellRxEOF   : out sl;                                -- Cell data end of frame
      cellRxEOFE  : out sl;                                -- Cell data end of frame error
      cellRxData  : out slv(RX_LANE_CNT_G*16-1 downto 0);  -- Cell data data

      -- Physical Interface Signals
      phyRxPolarity : out slv(RX_LANE_CNT_G-1 downto 0);     -- PHY receive signal polarity
      phyRxData     : in  slv(RX_LANE_CNT_G*16-1 downto 0);  -- PHY receive data
      phyRxDataK    : in  slv(RX_LANE_CNT_G*2-1 downto 0);   -- PHY receive data is K character
      phyRxDispErr  : in  slv(RX_LANE_CNT_G*2-1 downto 0);   -- PHY receive data has disparity error
      phyRxDecErr   : in  slv(RX_LANE_CNT_G*2-1 downto 0);   -- PHY receive data not in table
      phyRxReady    : in  sl;                                -- PHY receive interface is ready
      phyRxInit     : out sl                                 -- PHY receive interface init;
      );

end Pgp2bRxPhy;


-- Define architecture
architecture Pgp2bRxPhy of Pgp2bRxPhy is

   -- Local Signals
   signal dly0RxData          : slv(RX_LANE_CNT_G*16-1 downto 0) := (others => '0');
   signal dly0RxDataK         : slv(RX_LANE_CNT_G*2-1 downto 0)  := (others => '0');
   signal dly0RxDispErr       : slv(RX_LANE_CNT_G*2-1 downto 0)  := (others => '0');
   signal dly0RxDecErr        : slv(RX_LANE_CNT_G*2-1 downto 0)  := (others => '0');
   signal dly1RxData          : slv(RX_LANE_CNT_G*16-1 downto 0) := (others => '0');
   signal dly1RxDataK         : slv(RX_LANE_CNT_G*2-1 downto 0)  := (others => '0');
   signal dly1RxDispErr       : slv(RX_LANE_CNT_G*2-1 downto 0)  := (others => '0');
   signal dly1RxDecErr        : slv(RX_LANE_CNT_G*2-1 downto 0)  := (others => '0');
   signal rxDetectLts         : sl                               := '0';
   signal rxDetectLtsOk       : sl                               := '0';
   signal rxDetectLtsRaw      : slv(1 downto 0);
   signal rxDetectInvert      : slv(RX_LANE_CNT_G-1 downto 0)    := (others => '0');
   signal rxDetectInvertRaw   : slv(RX_LANE_CNT_G-1 downto 0);
   signal rxDetectRemLink     : sl                               := '0';
   signal rxDetectRemData     : slv(7 downto 0)                  := (others => '0');
   signal rxDetectOpCodeEn    : sl                               := '0';
   signal rxDetectOpCodeEnRaw : slv(1 downto 0);
   signal rxDetectSOC         : sl                               := '0';
   signal rxDetectSOCRaw      : slv(1 downto 0);
   signal rxDetectSOF         : sl                               := '0';
   signal rxDetectSOFRaw      : slv(1 downto 0);
   signal rxDetectEOC         : sl                               := '0';
   signal rxDetectEOCRaw      : slv(1 downto 0);
   signal rxDetectEOF         : sl                               := '0';
   signal rxDetectEOFRaw      : slv(1 downto 0);
   signal rxDetectEOFE        : sl                               := '0';
   signal rxDetectEOFERaw     : slv(1 downto 0);
   signal nxtRxLinkReady      : sl;
   signal stateCntRst         : sl;
   signal stateCnt            : slv(19 downto 0)                 := (others => '0');
   signal ltsCntRst           : sl;
   signal ltsCntEn            : sl;
   signal ltsCnt              : slv(7 downto 0)                  := (others => '0');
   signal intRxLinkReady      : sl                               := '0';
   signal intRxPolarity       : slv(RX_LANE_CNT_G-1 downto 0)    := (others => '0');
   signal nxtRxPolarity       : slv(RX_LANE_CNT_G-1 downto 0);
   signal dlyRxLinkDown       : sl                               := '0';
   signal intRxLinkError      : sl                               := '0';
   signal dlyRxLinkError      : sl                               := '0';
   signal intRxInit           : sl                               := '0';
   signal nxtRxInit           : sl;

   -- Physical Link State
   constant ST_RESET_C : slv(2 downto 0) := "001";
   constant ST_LOCK_C  : slv(2 downto 0) := "010";
   constant ST_WAIT_C  : slv(2 downto 0) := "011";
   constant ST_INVRT_C : slv(2 downto 0) := "100";
   constant ST_READY_C : slv(2 downto 0) := "101";
   signal curState     : slv(2 downto 0) := ST_LOCK_C;
   signal nxtState     : slv(2 downto 0);

begin

   -- Link status
   pgpRxLinkReady <= intRxLinkReady;

   -- RX Interface Init
   phyRxInit <= intRxInit;

   -- Opcode Receive Interface
   pgpRxOpCodeEn <= rxDetectOpCodeEn;
   pgpRxOpCode   <= dly1RxData(15 downto 8);

   -- Cell Receive Interface
   cellRxPause <= rxDetectOpCodeEn;
   cellRxSOC   <= rxDetectSOC;
   cellRxSOF   <= rxDetectSOF;
   cellRxEOC   <= rxDetectEOC;
   cellRxEOF   <= rxDetectEOF;
   cellRxEOFE  <= rxDetectEOFE;
   cellRxData  <= dly1RxData;

   -- Drive active polarity control signals
   GEN_POL : for i in 0 to (RX_LANE_CNT_G-1) generate
      phyRxPolarity(i) <= intRxPolarity(i);
   end generate;

   -- State transition sync logic. 
   process (pgpRxClk, pgpRxClkRst)
   begin

      if pgpRxClkRst = '1' then
         curState        <= ST_LOCK_C       after TPD_G;
         stateCnt        <= (others => '0') after TPD_G;
         ltsCnt          <= (others => '0') after TPD_G;
         intRxLinkReady  <= '0'             after TPD_G;
         intRxPolarity   <= (others => '0') after TPD_G;
         dlyRxLinkDown   <= '0'             after TPD_G;
         pgpRxLinkDown   <= '0'             after TPD_G;
         intRxLinkError  <= '0'             after TPD_G;
         dlyRxLinkError  <= '0'             after TPD_G;
         pgpRxLinkError  <= '0'             after TPD_G;
         intRxInit       <= '0'             after TPD_G;
         pgpRemLinkReady <= '0'             after TPD_G;
         pgpRemData      <= (others => '0') after TPD_G;
      elsif rising_edge(pgpRxClk) then

         if pgpRxClkEn = '1' then
            -- Sideband data
            if intRxLinkReady = '1' then
               pgpRemLinkReady <= rxDetectRemLink;
               pgpRemData      <= rxDetectRemData;
            else
               pgpRemLinkReady <= '0'             after TPD_G;
               pgpRemData      <= (others => '0') after TPD_G;
            end if;

            -- Link down edge detection
            dlyRxLinkDown <= (not intRxLinkReady)                         after TPD_G;
            pgpRxLinkDown <= (not intRxLinkReady) and (not dlyRxLinkDown) after TPD_G;

            -- Link error generation
            if (dly1RxDispErr /= 0 or dly1RxDecErr /= 0) and intRxLinkReady = '1' then
               intRxLinkError <= '1' after TPD_G;
            else
               intRxLinkError <= '0' after TPD_G;
            end if;

            -- Link error edge detection
            dlyRxLinkError <= intRxLinkError                        after TPD_G;
            pgpRxLinkError <= intRxLinkError and not dlyRxLinkError after TPD_G;

            -- Status signals
            intRxLinkReady <= nxtRxLinkReady after TPD_G;
            intRxPolarity  <= nxtRxPolarity  after TPD_G;
            intRxInit      <= nxtRxInit      after TPD_G;

            -- State transition
            curState <= nxtState after TPD_G;

            -- In state counter
            if stateCntRst = '1' then
               stateCnt <= (others => '0') after TPD_G;
            else
               stateCnt <= stateCnt + 1 after TPD_G;
            end if;

            -- LTS Counter
            if ltsCntRst = '1' then
               ltsCnt <= (others => '0') after TPD_G;
            elsif (ltsCntEn = '1') and (ltsCnt /= 255) then
               ltsCnt <= ltsCnt + 1 after TPD_G;
            end if;

         end if;
      end if;
   end process;


-- Link control state machine
   process (curState, stateCnt, ltsCnt, rxDetectLts, rxDetectLtsOk,
            rxDetectInvert, intRxPolarity, phyRxReady, dly1RxDecErr, dly1RxDispErr)
   begin
      case curState is

         -- Hold in rx reset for 8 clocks
         when ST_RESET_C =>
            nxtRxLinkReady <= '0';
            nxtRxPolarity  <= (others => '0');
            ltsCntRst      <= '1';
            ltsCntEn       <= '0';
            nxtRxInit      <= '1';

            -- Hold reset for 255 clocks
            if stateCnt(7 downto 0) = 255 then
               stateCntRst <= '1';
               nxtState    <= ST_LOCK_C;
            else
               stateCntRst <= '0';
               nxtState    <= curState;
            end if;

         -- Wait for lock state
         when ST_LOCK_C =>
            nxtRxLinkReady <= '0';
            nxtRxPolarity  <= (others => '0');
            ltsCntRst      <= '1';
            ltsCntEn       <= '0';
            nxtRxInit      <= '0';

            -- Wait for lock
            if phyRxReady = '1' then
               nxtState    <= ST_WAIT_C;
               stateCntRst <= '1';

            -- Terminal count without lock
            elsif stateCnt = x"FFFFF" then
               nxtState    <= ST_RESET_C;
               stateCntRst <= '1';
            else
               nxtState    <= curState;
               stateCntRst <= '0';
            end if;

         -- Wait for training pattern
         when ST_WAIT_C =>
            nxtRxLinkReady <= '0';
            nxtRxInit      <= '0';

            -- Lock is lost
            if phyRxReady = '0' then
               stateCntRst   <= '1';
               ltsCntEn      <= '0';
               ltsCntRst     <= '0';
               nxtRxPolarity <= intRxPolarity;
               nxtState      <= ST_RESET_C;

            -- Decode or disparity error, clear lts count
            elsif phyRxReady = '0' or dly1RxDispErr /= 0 or dly1RxDecErr /= 0 then
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
                  nxtState      <= ST_INVRT_C;
               end if;

            -- Run after we have seen 256 non-inverted training sequences
            -- without any disparity or decode errors.
            elsif ltsCnt = 255 then
               stateCntRst   <= '1';
               ltsCntEn      <= '0';
               ltsCntRst     <= '1';
               nxtRxPolarity <= intRxPolarity;
               nxtState      <= ST_READY_C;

            -- Terminal count without seeing a valid LTS
            elsif stateCnt = x"FFFFF" then
               stateCntRst   <= '1';
               ltsCntEn      <= '0';
               ltsCntRst     <= '1';
               nxtRxPolarity <= intRxPolarity;
               nxtState      <= ST_RESET_C;

            -- Count cycles without LTS
            else
               stateCntRst   <= '0';
               ltsCntEn      <= '0';
               ltsCntRst     <= '0';
               nxtRxPolarity <= intRxPolarity;
               nxtState      <= curState;
            end if;

         -- Wait a few clocks after inverting receive interface
         when ST_INVRT_C =>
            nxtRxLinkReady <= '0';
            nxtRxPolarity  <= intRxPolarity;
            ltsCntRst      <= '1';
            ltsCntEn       <= '0';
            nxtRxInit      <= '0';

            -- Wait 128 clocks
            if stateCnt(6 downto 0) = 127 then
               nxtState    <= ST_WAIT_C;
               stateCntRst <= '1';
            else
               nxtState    <= curState;
               stateCntRst <= '0';
            end if;

         -- Ready
         when ST_READY_C =>
            nxtRxLinkReady <= '1';
            nxtRxPolarity  <= intRxPolarity;
            ltsCntRst      <= '1';
            ltsCntEn       <= '0';
            nxtRxInit      <= '0';

            -- Lock is lost
            if phyRxReady = '0' then
               nxtState    <= ST_RESET_C;
               stateCntRst <= '1';

            -- Training sequence seen
            elsif rxDetectLts = '1' then

               -- Link is inverted or bad lts, reset and relink
               if rxDetectInvert /= 0 or rxDetectLtsOk = '0' then
                  nxtState    <= ST_RESET_C;
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
               nxtState    <= ST_RESET_C;
               stateCntRst <= '1';

            -- Count cycles without LTS
            else
               nxtState    <= curState;
               stateCntRst <= '0';
            end if;

         -- Default
         when others =>
            nxtRxLinkReady <= '0';
            nxtRxPolarity  <= (others => '0');
            stateCntRst    <= '0';
            ltsCntRst      <= '0';
            ltsCntEn       <= '0';
            nxtRxInit      <= '0';
            nxtState       <= ST_LOCK_C;
      end case;
   end process;


-- Receive data pipeline
   process (pgpRxClk, pgpRxClkRst)
   begin
      if pgpRxClkRst = '1' then
         dly0RxData    <= (others => '0') after TPD_G;
         dly0RxDataK   <= (others => '0') after TPD_G;
         dly0RxDispErr <= (others => '0') after TPD_G;
         dly0RxDecErr  <= (others => '0') after TPD_G;
         dly1RxData    <= (others => '0') after TPD_G;
         dly1RxDataK   <= (others => '0') after TPD_G;
         dly1RxDispErr <= (others => '0') after TPD_G;
         dly1RxDecErr  <= (others => '0') after TPD_G;

      elsif rising_edge(pgpRxClk) then
         if pgpRxClkEn = '1' then
            dly0RxData    <= phyRxData     after TPD_G;
            dly0RxDataK   <= phyRxDataK    after TPD_G;
            dly0RxDispErr <= phyRxDispErr  after TPD_G;
            dly0RxDecErr  <= phyRxDecErr   after TPD_G;
            dly1RxData    <= dly0RxData    after TPD_G;
            dly1RxDataK   <= dly0RxDataK   after TPD_G;
            dly1RxDispErr <= dly0RxDispErr after TPD_G;
            dly1RxDecErr  <= dly0RxDecErr  after TPD_G;
         end if;
      end if;
   end process;


-- Link init ordered set detect
   process (pgpRxClk, pgpRxClkRst)
   begin
      if pgpRxClkRst = '1' then
         rxDetectLts      <= '0'             after TPD_G;
         rxDetectLtsOk    <= '0'             after TPD_G;
         rxDetectInvert   <= (others => '0') after TPD_G;
         rxDetectRemLink  <= '0'             after TPD_G;
         rxDetectRemData  <= (others => '0') after TPD_G;
         rxDetectOpCodeEn <= '0'             after TPD_G;
         rxDetectSOC      <= '0'             after TPD_G;
         rxDetectSOF      <= '0'             after TPD_G;
         rxDetectEOC      <= '0'             after TPD_G;
         rxDetectEOF      <= '0'             after TPD_G;
         rxDetectEOFE     <= '0'             after TPD_G;
      elsif rising_edge(pgpRxClk) then
         if pgpRxClkEn = '1' then
            -- LTS is detected when phy is ready
            if phyRxReady = '1' then

               -- Detect link init ordered sets
               if rxDetectLtsRaw(0) = '1' and
                  (rxDetectLtsRaw(1) = '1' or RX_LANE_CNT_G < 2) then
                  rxDetectInvert <= rxDetectInvertRaw after TPD_G;
                  rxDetectLts    <= '1'               after TPD_G;

                  -- Lane count and ID must match
                  if dly0RxData(13 downto 12) = conv_std_logic_vector(RX_LANE_CNT_G-1, 2) and
                     dly0RxData(11 downto 8) = PGP2B_ID_C then
                     rxDetectLtsOk   <= '1'                    after TPD_G;
                     rxDetectRemLink <= dly0RxData(15)         after TPD_G;
                     rxDetectRemData <= dly0RxData(7 downto 0) after TPD_G;
                  else
                     rxDetectLtsOk <= '0' after TPD_G;
                  end if;
               else
                  rxDetectLts   <= '0' after TPD_G;
                  rxDetectLtsOk <= '0' after TPD_G;
               end if;
            else
               rxDetectLts     <= '0'             after TPD_G;
               rxDetectLtsOk   <= '0'             after TPD_G;
               rxDetectInvert  <= (others => '0') after TPD_G;
               rxDetectRemLink <= '0'             after TPD_G;
               rxDetectRemData <= (others => '0') after TPD_G;
            end if;

            -- The remaining opcodes are only detected when the link is up
            if intRxLinkReady = '1' then

               -- Detect opCode ordered set
               if rxDetectOpCodeEnRaw(0) = '1' and
                  (rxDetectOpCodeEnRaw(1) = '1' or RX_LANE_CNT_G < 2) then
                  rxDetectOpCodeEn <= '1' after TPD_G;
               else
                  rxDetectOpCodeEn <= '0' after TPD_G;
               end if;

               -- Detect SOC ordered set
               if rxDetectSOCRaw(0) = '1' and (rxDetectSOCRaw(1) = '1' or RX_LANE_CNT_G < 2) then
                  rxDetectSOC <= '1' after TPD_G;
                  rxDetectSOF <= '0' after TPD_G;

               -- Detect SOF ordered set
               elsif rxDetectSOFRaw(0) = '1' and (rxDetectSOFRaw(1) = '1' or RX_LANE_CNT_G < 2) then
                  rxDetectSOC <= '1' after TPD_G;
                  rxDetectSOF <= '1' after TPD_G;
               else
                  rxDetectSOC <= '0' after TPD_G;
                  rxDetectSOF <= '0' after TPD_G;
               end if;

               -- Detect EOC ordered set
               if rxDetectEOCRaw(0) = '1' and (rxDetectEOCRaw(1) = '1' or RX_LANE_CNT_G < 2) then
                  rxDetectEOC  <= '1' after TPD_G;
                  rxDetectEOF  <= '0' after TPD_G;
                  rxDetectEOFE <= '0' after TPD_G;

               -- Detect EOF ordered set
               elsif rxDetectEOFRaw(0) = '1' and (rxDetectEOFRaw(1) = '1' or RX_LANE_CNT_G < 2) then
                  rxDetectEOC  <= '1' after TPD_G;
                  rxDetectEOF  <= '1' after TPD_G;
                  rxDetectEOFE <= '0' after TPD_G;

               -- Detect EOFE ordered set
               elsif rxDetectEOFERaw(0) = '1' and (rxDetectEOFERaw(1) = '1' or RX_LANE_CNT_G < 2) then
                  rxDetectEOC  <= '1' after TPD_G;
                  rxDetectEOF  <= '1' after TPD_G;
                  rxDetectEOFE <= '1' after TPD_G;
               else
                  rxDetectEOC  <= '0' after TPD_G;
                  rxDetectEOF  <= '0' after TPD_G;
                  rxDetectEOFE <= '0' after TPD_G;
               end if;
            else
               rxDetectOpCodeEn <= '0' after TPD_G;
               rxDetectSOC      <= '0' after TPD_G;
               rxDetectSOF      <= '0' after TPD_G;
               rxDetectEOC      <= '0' after TPD_G;
               rxDetectEOF      <= '0' after TPD_G;
               rxDetectEOFE     <= '0' after TPD_G;
            end if;
         end if;
      end if;
   end process;

-- Generate Loop
   GEN_LANES : for i in 0 to (RX_LANE_CNT_G-1) generate

      -- Ordered Set Detection
      process (dly1RxDataK, dly1RxData, dly0RxDataK, dly0RxData, dly0RxDispErr, dly0RxDecErr, dly1RxDispErr, dly1RxDecErr)
      begin

         -- Skip errored decodes
         if dly0RxDispErr(i*2) = '0' and dly0RxDispErr(i*2+1) = '0' and
            dly0RxDecErr(i*2) = '0' and dly0RxDecErr(i*2+1) = '0' and
            dly1RxDispErr(i*2) = '0' and dly1RxDispErr(i*2+1) = '0' and
            dly1RxDecErr(i*2) = '0' and dly1RxDecErr(i*2+1) = '0' then

            -- Link init ordered set
            if (dly1RxDataK(i*2) = '1' and dly1RxDataK(i*2+1) = '0' and
                dly0RxDataK(i*2) = '0' and dly0RxDataK(i*2+1) = '0' and
                dly1RxData(i*16+7 downto i*16) = K_LTS_C and
                (dly1RxData(i*16+15 downto i*16+8) = D_102_C or dly1RxData(i*16+15 downto i*16+8) = D_215_C)) then
               rxDetectLtsRaw(i) <= '1';

               -- Detect Link Inversion
               if dly1RxData(i*16+15 downto i*16+8) = D_102_C then
                  rxDetectInvertRaw(i) <= '0';
               else
                  rxDetectInvertRaw(i) <= '1';
               end if;
            else
               rxDetectLtsRaw(i)    <= '0';
               rxDetectInvertRaw(i) <= '0';
            end if;

            -- OpCode Enable
            if (dly0RxDataK(i*2) = '1' and dly0RxDataK(i*2+1) = '0' and dly0RxData(i*16+7 downto i*16) = K_OTS_C) then
               rxDetectOpCodeEnRaw(i) <= '1';
            else
               rxDetectOpCodeEnRaw(i) <= '0';
            end if;

            -- SOC Detect
            if (dly0RxDataK(i*2) = '1' and dly0RxDataK(i*2+1) = '0' and dly0RxData(i*16+7 downto i*16) = K_SOC_C) then
               rxDetectSOCRaw(i) <= '1';
            else
               rxDetectSOCRaw(i) <= '0';
            end if;

            -- SOF Detect
            if (dly0RxDataK(i*2) = '1' and dly0RxDataK(i*2+1) = '0' and dly0RxData(i*16+7 downto i*16) = K_SOF_C) then
               rxDetectSOFRaw(i) <= '1';
            else
               rxDetectSOFRaw(i) <= '0';
            end if;

            -- EOC Detect
            if (dly0RxDataK(i*2) = '1' and dly0RxDataK(i*2+1) = '0' and dly0RxData(i*16+7 downto i*16) = K_EOC_C) then
               rxDetectEOCRaw(i) <= '1';
            else
               rxDetectEOCRaw(i) <= '0';
            end if;

            -- EOF Detect
            if (dly0RxDataK(i*2) = '1' and dly0RxDataK(i*2+1) = '0' and dly0RxData(i*16+7 downto i*16) = K_EOF_C) then
               rxDetectEOFRaw(i) <= '1';
            else
               rxDetectEOFRaw(i) <= '0';
            end if;

            -- EOFE Detect
            if (dly0RxDataK(i*2) = '1' and dly0RxDataK(i*2+1) = '0' and dly0RxData(i*16+7 downto i*16) = K_EOFE_C) then
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
   GEN_SPARE : for i in RX_LANE_CNT_G to 1 generate
      rxDetectLtsRaw(i)      <= '0';
      rxDetectOpCodeEnRaw(i) <= '0';
      rxDetectSOCRaw(i)      <= '0';
      rxDetectSOFRaw(i)      <= '0';
      rxDetectEOCRaw(i)      <= '0';
      rxDetectEOFRaw(i)      <= '0';
      rxDetectEOFERaw(i)     <= '0';
   end generate;

end Pgp2bRxPhy;

