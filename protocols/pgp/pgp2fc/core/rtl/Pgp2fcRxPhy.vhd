-------------------------------------------------------------------------------
-- Title      : PGPv2fc: https://confluence.slac.stanford.edu/x/q86fD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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

library surf;
use surf.StdRtlPkg.all;
use surf.Pgp2fcPkg.all;

entity Pgp2fcRxPhy is
   generic (
      TPD_G      : time                 := 1 ns;
      FC_WORDS_G : integer range 1 to 8 := 1
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

      -- Fast control interface
      fcValid : out sl := '0';
      fcWord  : out slv(16*FC_WORDS_G-1 downto 0);
      fcError : out sl := '0';

      -- Sideband data
      pgpRemLinkReady : out sl              := '0';              -- Far end side has link
      pgpRemData      : out slv(7 downto 0) := (others => '0');  -- Far end side User Data

      -- Cell Receive Interface
      cellRxPause : out sl;                -- Cell data pause
      cellRxSOC   : out sl;                -- Cell data start of cell
      cellRxSOF   : out sl;                -- Cell data start of frame
      cellRxEOC   : out sl;                -- Cell data end of cell
      cellRxEOF   : out sl;                -- Cell data end of frame
      cellRxEOFE  : out sl;                -- Cell data end of frame error
      cellRxData  : out slv(15 downto 0);  -- Cell data data

      -- Physical Interface Signals
      phyRxData    : in  slv(15 downto 0);  -- PHY receive data
      phyRxDataK   : in  slv(1 downto 0);   -- PHY receive data is K character
      phyRxDispErr : in  slv(1 downto 0);   -- PHY receive data has disparity error
      phyRxDecErr  : in  slv(1 downto 0);   -- PHY receive data not in table
      phyRxReady   : in  sl;                -- PHY receive interface is ready
      phyRxInit    : out sl                 -- PHY receive interface init;
      );

end Pgp2fcRxPhy;


-- Define architecture
architecture Pgp2fcRxPhy of Pgp2fcRxPhy is

   -- Local Signals
   signal dly0RxData          : slv(15 downto 0) := (others => '0');
   signal dly0RxDataK         : slv(1 downto 0)  := (others => '0');
   signal dly0RxDispErr       : slv(1 downto 0)  := (others => '0');
   signal dly0RxDecErr        : slv(1 downto 0)  := (others => '0');
   signal dly1RxData          : slv(15 downto 0) := (others => '0');
   signal dly1RxDataK         : slv(1 downto 0)  := (others => '0');
   signal dly1RxDispErr       : slv(1 downto 0)  := (others => '0');
   signal dly1RxDecErr        : slv(1 downto 0)  := (others => '0');
   signal rxDetectLts         : sl               := '0';
   signal rxDetectLtsOk       : sl               := '0';
   signal rxDetectLtsRaw      : sl;
   signal rxDetectInvert      : sl               := '0';
   signal rxDetectInvertRaw   : sl;
   signal rxDetectRemLink     : sl               := '0';
   signal rxDetectRemData     : slv(7 downto 0)  := (others => '0');
   signal rxDetectFcWordEnRaw : sl;
   signal rxDetectSOC         : sl               := '0';
   signal rxDetectSOCRaw      : sl;
   signal rxDetectSOF         : sl               := '0';
   signal rxDetectSOFRaw      : sl;
   signal rxDetectEOC         : sl               := '0';
   signal rxDetectEOCRaw      : sl;
   signal rxDetectEOF         : sl               := '0';
   signal rxDetectEOFRaw      : sl;
   signal rxDetectEOFE        : sl               := '0';
   signal rxDetectEOFERaw     : sl;
   signal nxtRxLinkReady      : sl;
   signal stateCntRst         : sl;
   signal stateCnt            : slv(19 downto 0) := (others => '0');
   signal ltsCntRst           : sl;
   signal ltsCntEn            : sl;
   signal ltsCnt              : slv(7 downto 0)  := (others => '0');
   signal intRxLinkReady      : sl               := '0';
   signal dlyRxLinkDown       : sl               := '0';
   signal intRxLinkError      : sl               := '0';
   signal dlyRxLinkError      : sl               := '0';
   signal intRxInit           : sl               := '0';
   signal nxtRxInit           : sl;

   signal intFcValid    : sl                            := '0';
   signal intFcBusy     : sl                            := '0';
   signal intFcError    : sl                            := '0';
   signal fcWordCounter : integer range 0 to FC_WORDS_G := 0;
   signal fcWordBuffer  : slv(16*FC_WORDS_G-1 downto 0) := (others => '0');

   signal crcRst    : sl;
   signal crcEn     : sl;
   signal crcDataIn : slv(15 downto 0);
   signal crcOut    : slv(7 downto 0);

   -- Physical Link State
   type FSM_STATE is (
      ST_RESET_C,
      ST_LOCK_C,
      ST_WAIT_C,
      ST_INVRT_C,
      ST_READY_C
      );
   signal curState : FSM_STATE := ST_LOCK_C;
   signal nxtState : FSM_STATE;

begin

   -- Link status
   pgpRxLinkReady <= intRxLinkReady;

   -- RX Interface Init
   phyRxInit <= intRxInit;

   -- Fast Control Receiver Interface
   fcValid <= intFcValid;
   fcWord  <= fcWordBuffer when intFcValid = '1' else (others => '0');  -- Zeroing can be removed to improve routing if required
   fcError <= intFcError;

   -- Cell Receive Interface
   cellRxPause <= intFcBusy;
   cellRxSOC   <= rxDetectSOC;
   cellRxSOF   <= rxDetectSOF;
   cellRxEOC   <= rxDetectEOC;
   cellRxEOF   <= rxDetectEOF;
   cellRxEOFE  <= rxDetectEOFE;
   cellRxData  <= dly1RxData;

   -- State transition sync logic.
   process (pgpRxClk, pgpRxClkRst)
   begin

      if pgpRxClkRst = '1' then
         curState        <= ST_LOCK_C       after TPD_G;
         stateCnt        <= (others => '0') after TPD_G;
         ltsCnt          <= (others => '0') after TPD_G;
         intRxLinkReady  <= '0'             after TPD_G;
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
            rxDetectInvert, phyRxReady, dly1RxDecErr, dly1RxDispErr)
   begin
      case curState is

         -- Hold in rx reset for 8 clocks
         when ST_RESET_C =>
            nxtRxLinkReady <= '0';
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
               stateCntRst <= '1';
               ltsCntEn    <= '0';
               ltsCntRst   <= '0';
               nxtState    <= ST_RESET_C;

            -- Decode or disparity error, clear lts count
            elsif phyRxReady = '0' or dly1RxDispErr /= 0 or dly1RxDecErr /= 0 then
               stateCntRst <= '0';
               ltsCntEn    <= '0';
               ltsCntRst   <= '1';
               nxtState    <= curState;

            -- Training pattern seen
            elsif rxDetectLts = '1' then
               stateCntRst <= '1';

               -- No Inversion
               if rxDetectInvert = '0' then
                  nxtState <= curState;

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
                  ltsCntEn  <= '0';
                  ltsCntRst <= '1';
                  nxtState  <= ST_INVRT_C;
               end if;

            -- Run after we have seen 256 non-inverted training sequences
            -- without any disparity or decode errors.
            elsif ltsCnt = 255 then
               stateCntRst <= '1';
               ltsCntEn    <= '0';
               ltsCntRst   <= '1';
               nxtState    <= ST_READY_C;

            -- Terminal count without seeing a valid LTS
            elsif stateCnt = x"FFFFF" then
               stateCntRst <= '1';
               ltsCntEn    <= '0';
               ltsCntRst   <= '1';
               nxtState    <= ST_RESET_C;

            -- Count cycles without LTS
            else
               stateCntRst <= '0';
               ltsCntEn    <= '0';
               ltsCntRst   <= '0';
               nxtState    <= curState;
            end if;

         -- Wait a few clocks after inverting receive interface
         -- TODO: Is this really necessary?
         when ST_INVRT_C =>
            nxtRxLinkReady <= '0';
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
            ltsCntRst      <= '1';
            ltsCntEn       <= '0';
            nxtRxInit      <= '0';

            --
            -- Lock is lost
            if phyRxReady = '0' then
               nxtState    <= ST_RESET_C;
               stateCntRst <= '1';

            -- Training sequence seen
            elsif rxDetectLts = '1' then

               -- Link is inverted or bad lts, reset and relink
               if rxDetectInvert /= '0' or rxDetectLtsOk = '0' then
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

   -- Fast Control logic
   process (pgpRxClk, pgpRxClkRst)
   begin
      if pgpRxClkRst = '1' then
         intFcValid    <= '0'             after TPD_G;
         intFcBusy     <= '0'             after TPD_G;
         intFcError    <= '0'             after TPD_G;
         fcWordCounter <= 0               after TPD_G;
         fcWordBuffer  <= (others => '0') after TPD_G;
      elsif rising_edge(pgpRxClk) then
         -- Defaults
         intFcValid    <= '0';
         intFcBusy     <= '0';
         intFcError    <= '0';
         fcWordCounter <= 0;
         fcWordBuffer  <= fcWordBuffer;

         if rxDetectFcWordEnRaw = '1' or fcWordCounter /= 0 then
            if fcWordCounter = FC_WORDS_G then
               fcWordCounter <= 0;
            else
               fcWordCounter <= fcWordCounter + 1;
            end if;
            intFcBusy <= '1';
         end if;

         if fcWordCounter = 0 then
            fcWordBuffer(7 downto 0) <= dly0RxData(15 downto 8);
         elsif fcWordCounter = FC_WORDS_G then
            fcWordBuffer(FC_WORDS_G*16-1 downto (FC_WORDS_G-1)*16+8) <= dly0RxData(7 downto 0);

            -- Check CRC too
            if (crcOut = dly0RxData(15 downto 8)) then
               intFcValid <= '1';
            else
               intFcError <= '1';
            end if;
         else
            fcWordBuffer(fcWordCounter*16+7 downto (fcWordCounter-1)*16+8) <= dly0RxData;
         end if;
      end if;
   end process;

   crcRst    <= '1'        when fcWordCounter = FC_WORDS_G                      else '0';
   crcEn     <= '1'        when rxDetectFcWordEnRaw = '1' or fcWordCounter /= 0 else '0';
   crcDataIn <= dly0RxData when fcWordCounter /= FC_WORDS_G                     else x"00" & dly0RxData(7 downto 0);

   U_Crc7 : entity surf.CRC7Rtl
      port map (
         rst     => crcRst,
         clk     => pgpRxClk,
         data_in => crcDataIn,
         crc_en  => crcEn,
         crc_out => crcOut
         );

   -- Link init ordered set detect
   process (pgpRxClk, pgpRxClkRst)
   begin
      if pgpRxClkRst = '1' then
         rxDetectLts     <= '0'             after TPD_G;
         rxDetectLtsOk   <= '0'             after TPD_G;
         rxDetectInvert  <= '0'             after TPD_G;
         rxDetectRemLink <= '0'             after TPD_G;
         rxDetectRemData <= (others => '0') after TPD_G;
         rxDetectSOC     <= '0'             after TPD_G;
         rxDetectSOF     <= '0'             after TPD_G;
         rxDetectEOC     <= '0'             after TPD_G;
         rxDetectEOF     <= '0'             after TPD_G;
         rxDetectEOFE    <= '0'             after TPD_G;
      elsif rising_edge(pgpRxClk) then
         if pgpRxClkEn = '1' then
            -- LTS is detected when phy is ready
            if phyRxReady = '1' then

               -- Detect link init ordered sets
               if rxDetectLtsRaw = '1' then
                  rxDetectInvert <= rxDetectInvertRaw after TPD_G;
                  rxDetectLts    <= '1'               after TPD_G;

                  -- Fast control word count and ID must match
                  if dly0RxData(14 downto 12) = conv_std_logic_vector(FC_WORDS_G-1, 3) and
                     dly0RxData(11 downto 8) = PGP2FC_ID_C then
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
               rxDetectInvert  <= '0'             after TPD_G;
               rxDetectRemLink <= '0'             after TPD_G;
               rxDetectRemData <= (others => '0') after TPD_G;
            end if;

            -- The remaining opcodes are only detected when the link is up
            if intRxLinkReady = '1' then

               -- Detect SOC ordered set
               if rxDetectSOCRaw = '1' then
                  rxDetectSOC <= '1' after TPD_G;
                  rxDetectSOF <= '0' after TPD_G;

               -- Detect SOF ordered set
               elsif rxDetectSOFRaw = '1' then
                  rxDetectSOC <= '1' after TPD_G;
                  rxDetectSOF <= '1' after TPD_G;
               else
                  rxDetectSOC <= '0' after TPD_G;
                  rxDetectSOF <= '0' after TPD_G;
               end if;

               -- Detect EOC ordered set
               if rxDetectEOCRaw = '1' then
                  rxDetectEOC  <= '1' after TPD_G;
                  rxDetectEOF  <= '0' after TPD_G;
                  rxDetectEOFE <= '0' after TPD_G;

               -- Detect EOF ordered set
               elsif rxDetectEOFRaw = '1' then
                  rxDetectEOC  <= '1' after TPD_G;
                  rxDetectEOF  <= '1' after TPD_G;
                  rxDetectEOFE <= '0' after TPD_G;

               -- Detect EOFE ordered set
               elsif rxDetectEOFERaw = '1' then
                  rxDetectEOC  <= '1' after TPD_G;
                  rxDetectEOF  <= '1' after TPD_G;
                  rxDetectEOFE <= '1' after TPD_G;
               else
                  rxDetectEOC  <= '0' after TPD_G;
                  rxDetectEOF  <= '0' after TPD_G;
                  rxDetectEOFE <= '0' after TPD_G;
               end if;
            else
--               rxDetectOpCodeEn <= '0' after TPD_G;
               rxDetectSOC  <= '0' after TPD_G;
               rxDetectSOF  <= '0' after TPD_G;
               rxDetectEOC  <= '0' after TPD_G;
               rxDetectEOF  <= '0' after TPD_G;
               rxDetectEOFE <= '0' after TPD_G;
            end if;
         end if;
      end if;
   end process;

   -- Ordered Set Detection
   process (dly1RxDataK, dly1RxData, dly0RxDataK, dly0RxData, dly0RxDispErr, dly0RxDecErr, dly1RxDispErr, dly1RxDecErr)
   begin

      -- Skip errored decodes
      if dly0RxDispErr = "00" and
         dly0RxDecErr = "00" and
         dly1RxDispErr = "00" and
         dly1RxDecErr = "00" then

         -- Link init ordered set
         if (dly1RxDataK = "01" and
             dly0RxDataK = "00" and
             dly1RxData(7 downto 0) = K_LTS_C and
             (dly1RxData(15 downto 8) = D_102_C or dly1RxData(15 downto 8) = D_215_C)) then
            rxDetectLtsRaw <= '1';

            -- Detect Link Inversion
            if dly1RxData(15 downto 8) = D_102_C then
               rxDetectInvertRaw <= '0';
            else
               rxDetectInvertRaw <= '1';
            end if;
         else
            rxDetectLtsRaw    <= '0';
            rxDetectInvertRaw <= '0';
         end if;

         -- Fast Control
         if (dly0RxDataK = "01" and dly0RxData(7 downto 0) = K_FCD_C) then
            rxDetectFcWordEnRaw <= '1';
         else
            rxDetectFcWordEnRaw <= '0';
         end if;

         -- SOC Detect
         if (dly0RxDataK = "01" and dly0RxData(7 downto 0) = K_SOC_C) then
            rxDetectSOCRaw <= '1';
         else
            rxDetectSOCRaw <= '0';
         end if;

         -- SOF Detect
         if (dly0RxDataK = "01" and dly0RxData(7 downto 0) = K_SOF_C) then
            rxDetectSOFRaw <= '1';
         else
            rxDetectSOFRaw <= '0';
         end if;

         -- EOC Detect
         if (dly0RxDataK = "01" and dly0RxData(7 downto 0) = K_EOC_C) then
            rxDetectEOCRaw <= '1';
         else
            rxDetectEOCRaw <= '0';
         end if;

         -- EOF Detect
         if (dly0RxDataK = "01" and dly0RxData(7 downto 0) = K_EOF_C) then
            rxDetectEOFRaw <= '1';
         else
            rxDetectEOFRaw <= '0';
         end if;

         -- EOFE Detect
         if (dly0RxDataK = "01" and dly0RxData(7 downto 0) = K_EOFE_C) then
            rxDetectEOFERaw <= '1';
         else
            rxDetectEOFERaw <= '0';
         end if;
      else
         rxDetectLtsRaw      <= '0';
         rxDetectInvertRaw   <= '0';
         rxDetectFcWordEnRaw <= '0';
         rxDetectSOCRaw      <= '0';
         rxDetectSOFRaw      <= '0';
         rxDetectEOCRaw      <= '0';
         rxDetectEOFRaw      <= '0';
         rxDetectEOFERaw     <= '0';
      end if;
   end process;

end Pgp2fcRxPhy;

