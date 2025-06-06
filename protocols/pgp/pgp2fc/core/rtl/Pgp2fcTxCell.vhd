-------------------------------------------------------------------------------
-- Title      : PGP2fc: https://confluence.slac.stanford.edu/x/JhItHw
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Cell Transmit interface module for the Pretty Good Protocol core.
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

entity Pgp2fcTxCell is
   generic (
      TPD_G             : time    := 1 ns;
      PAYLOAD_CNT_TOP_G : integer := 7);  -- Top bit for payload counter
   port (
      -- System clock, reset & control
      pgpTxClkEn  : in sl := '1';         -- Master clock Enable
      pgpTxClk    : in sl;                -- Master clock
      pgpTxClkRst : in sl;                -- Synchronous reset input

      -- Link is ready
      pgpTxLinkReady : in sl;           -- Local side has link

      -- Phy is busy
      pgpTxBusy : in sl;

      -- Phy Transmit Interface
      cellTxSOC  : out sl;                -- Cell data start of cell
      cellTxSOF  : out sl;                -- Cell data start of frame
      cellTxEOC  : out sl;                -- Cell data end of cell
      cellTxEOF  : out sl;                -- Cell data end of frame
      cellTxEOFE : out sl;                -- Cell data end of frame error
      cellTxData : out slv(15 downto 0);  -- Cell data data

      -- Transmit Scheduler Interface
      schTxSOF     : out sl;               -- Cell contained SOF
      schTxEOF     : out sl;               -- Cell contained EOF
      schTxIdle    : in  sl;               -- Force IDLE transmit
      schTxReq     : in  sl;               -- Cell transmit request
      schTxAck     : out sl;               -- Cell transmit acknowledge
      schTxTimeout : in  sl;               -- Cell transmit timeout
      schTxDataVc  : in  slv(1 downto 0);  -- Cell transmit virtual channel

      -- Frame Transmit Interface, VC 0
      vc0FrameTxValid  : in  sl;        -- User frame data is valid
      vc0FrameTxReady  : out sl;        -- PGP is ready
      vc0FrameTxSOF    : in  sl;        -- User frame data start of frame
      vc0FrameTxEOF    : in  sl;        -- User frame data end of frame
      vc0FrameTxEOFE   : in  sl;        -- User frame data error
      vc0FrameTxData   : in  slv(15 downto 0);  -- User frame data
      vc0LocAlmostFull : in  sl;        -- Local buffer almost full
      vc0LocOverflow   : in  sl;        -- Local buffer full
      vc0RemAlmostFull : in  sl;        -- Remote buffer almost full

      -- Frame Transmit Interface, VC 1
      vc1FrameTxValid  : in  sl;        -- User frame data is valid
      vc1FrameTxReady  : out sl;        -- PGP is ready
      vc1FrameTxSOF    : in  sl;        -- User frame data start of frame
      vc1FrameTxEOF    : in  sl;        -- User frame data end of frame
      vc1FrameTxEOFE   : in  sl;        -- User frame data error
      vc1FrameTxData   : in  slv(15 downto 0);  -- User frame data
      vc1LocAlmostFull : in  sl;        -- Local buffer almost full
      vc1LocOverflow   : in  sl;        -- Local buffer full
      vc1RemAlmostFull : in  sl;        -- Remote buffer almost full

      -- Frame Transmit Interface, VC 2
      vc2FrameTxValid  : in  sl;        -- User frame data is valid
      vc2FrameTxReady  : out sl;        -- PGP is ready
      vc2FrameTxSOF    : in  sl;        -- User frame data start of frame
      vc2FrameTxEOF    : in  sl;        -- User frame data end of frame
      vc2FrameTxEOFE   : in  sl;        -- User frame data error
      vc2FrameTxData   : in  slv(15 downto 0);  -- User frame data
      vc2LocAlmostFull : in  sl;        -- Local buffer almost full
      vc2LocOverflow   : in  sl;        -- Local buffer full
      vc2RemAlmostFull : in  sl;        -- Remote buffer almost full

      -- Frame Transmit Interface, VC 3
      vc3FrameTxValid  : in  sl;        -- User frame data is valid
      vc3FrameTxReady  : out sl;        -- PGP is ready
      vc3FrameTxSOF    : in  sl;        -- User frame data start of frame
      vc3FrameTxEOF    : in  sl;        -- User frame data end of frame
      vc3FrameTxEOFE   : in  sl;        -- User frame data error
      vc3FrameTxData   : in  slv(15 downto 0);  -- User frame data
      vc3LocAlmostFull : in  sl;        -- Local buffer almost full
      vc3LocOverflow   : in  sl;        -- Local buffer full
      vc3RemAlmostFull : in  sl;        -- Remote buffer almost full

      -- Transmit CRC Interface
      crcTxIn    : out slv(15 downto 0);   -- Transmit data for CRC
      crcTxInit  : out sl;                 -- Transmit CRC value init
      crcTxValid : out sl;                 -- Transmit data for CRC is valid
      crcTxOut   : in  slv(31 downto 0));  -- Transmit calculated CRC value
end Pgp2fcTxCell;

architecture Pgp2fcTxCell of Pgp2fcTxCell is

   -- Local Signals
   signal muxFrameTxValid  : sl;
   signal muxFrameTxSOF    : sl;
   signal muxFrameTxEOF    : sl;
   signal muxFrameTxEOFE   : sl;
   signal muxFrameTxData   : slv(15 downto 0);
   signal muxRemAlmostFull : sl;
   signal cellCnt          : slv(PAYLOAD_CNT_TOP_G downto 0);
   signal cellCntRst       : sl;
   signal nxtFrameTxReady  : sl;
   signal nxtType          : slv(2 downto 0);
   signal nxtTypeLast      : slv(2 downto 0);
   signal curTypeLast      : slv(2 downto 0);
   signal nxtTxSOF         : sl;
   signal nxtTxEOF         : sl;
   signal nxtTxAck         : sl;
   signal nxtData          : slv(15 downto 0);
   signal eocWord          : slv(15 downto 0);
   signal socWord          : slv(15 downto 0);
   signal crcWordA         : slv(15 downto 0);
   signal crcWordB         : slv(15 downto 0);
   signal serialCntEn      : sl;
   signal vc0Serial        : slv(5 downto 0);
   signal vc1Serial        : slv(5 downto 0);
   signal vc2Serial        : slv(5 downto 0);
   signal vc3Serial        : slv(5 downto 0);
   signal muxSerial        : slv(5 downto 0);
   signal dly0Data         : slv(15 downto 0) := (others => '0');
   signal dly0Type         : slv(2 downto 0)  := (others => '0');
   signal dly1Data         : slv(15 downto 0) := (others => '0');
   signal dly1Type         : slv(2 downto 0)  := (others => '0');
   signal dly2Data         : slv(15 downto 0) := (others => '0');
   signal dly2Type         : slv(2 downto 0)  := (others => '0');
   signal dly3Data         : slv(15 downto 0) := (others => '0');
   signal dly3Type         : slv(2 downto 0)  := (others => '0');
   signal dly4Data         : slv(15 downto 0) := (others => '0');
   signal dly4Type         : slv(2 downto 0)  := (others => '0');
   signal int0FrameTxReady : sl               := '0';
   signal int1FrameTxReady : sl               := '0';
   signal int2FrameTxReady : sl               := '0';
   signal int3FrameTxReady : sl               := '0';
   signal intTimeout       : sl               := '0';
   signal intOverflow      : slv(3 downto 0)  := (others => '0');

   -- Transmit Data Marker
   constant TX_DATA_C : slv(2 downto 0) := "000";
   constant TX_SOC_C  : slv(2 downto 0) := "001";
   constant TX_SOF_C  : slv(2 downto 0) := "010";
   constant TX_EOC_C  : slv(2 downto 0) := "011";
   constant TX_EOF_C  : slv(2 downto 0) := "100";
   constant TX_EOFE_C : slv(2 downto 0) := "101";
   constant TX_CRCA_C : slv(2 downto 0) := "110";
   constant TX_CRCB_C : slv(2 downto 0) := "111";

   -- Transmit states
   type StateType is (
      IDLE_S,
      EMPTY_S,
      SOC_S,
      DATA_S,
      CRCA_S,
      CRCB_S,
      EOC_S);

   signal curState : StateType := IDLE_S;
   signal nxtState : StateType;

begin


   -- Mux incoming data
   process (schTxDataVc, vc0FrameTxData, vc0FrameTxEOF, vc0FrameTxEOFE,
            vc0FrameTxSOF, vc0FrameTxValid, vc0RemAlmostFull, vc0Serial,
            vc1FrameTxData, vc1FrameTxEOF, vc1FrameTxEOFE, vc1FrameTxSOF,
            vc1FrameTxValid, vc1RemAlmostFull, vc1Serial, vc2FrameTxData,
            vc2FrameTxEOF, vc2FrameTxEOFE, vc2FrameTxSOF, vc2FrameTxValid,
            vc2RemAlmostFull, vc2Serial, vc3FrameTxData, vc3FrameTxEOF,
            vc3FrameTxEOFE, vc3FrameTxSOF, vc3FrameTxValid, vc3RemAlmostFull,
            vc3Serial)
   begin
      case schTxDataVc is
         when "00" =>
            muxFrameTxValid  <= vc0FrameTxValid;
            muxFrameTxSOF    <= vc0FrameTxSOF;
            muxFrameTxEOF    <= vc0FrameTxEOF;
            muxFrameTxEOFE   <= vc0FrameTxEOFE;
            muxFrameTxData   <= vc0FrameTxData;
            muxRemAlmostFull <= vc0RemAlmostFull;
            muxSerial        <= vc0Serial;
         when "01" =>
            muxFrameTxValid  <= vc1FrameTxValid;
            muxFrameTxSOF    <= vc1FrameTxSOF;
            muxFrameTxEOF    <= vc1FrameTxEOF;
            muxFrameTxEOFE   <= vc1FrameTxEOFE;
            muxFrameTxData   <= vc1FrameTxData;
            muxRemAlmostFull <= vc1RemAlmostFull;
            muxSerial        <= vc1Serial;
         when "10" =>
            muxFrameTxValid  <= vc2FrameTxValid;
            muxFrameTxSOF    <= vc2FrameTxSOF;
            muxFrameTxEOF    <= vc2FrameTxEOF;
            muxFrameTxEOFE   <= vc2FrameTxEOFE;
            muxFrameTxData   <= vc2FrameTxData;
            muxRemAlmostFull <= vc2RemAlmostFull;
            muxSerial        <= vc2Serial;
         when others =>
            muxFrameTxValid  <= vc3FrameTxValid;
            muxFrameTxSOF    <= vc3FrameTxSOF;
            muxFrameTxEOF    <= vc3FrameTxEOF;
            muxFrameTxEOFE   <= vc3FrameTxEOFE;
            muxFrameTxData   <= vc3FrameTxData;
            muxRemAlmostFull <= vc3RemAlmostFull;
            muxSerial        <= vc3Serial;
      end case;
   end process;


   -- Choose data for SOF & EOF Positions
   -- SOF, vc number and serial number
   socWord(15 downto 14) <= schTxDataVc;
   socWord(13 downto 8)  <= muxSerial;
   socWord(7 downto 0)   <= (others => '0');

   -- EOF, buffer status
   eocWord(15 downto 12) <= intOverflow;
   eocWord(11 downto 8)  <= vc3LocAlmostFull & vc2LocAlmostFull & vc1LocAlmostFull & vc0LocAlmostFull;
   eocWord(7 downto 0)   <= (others => '0');


   -- Simple state machine to control transmission of data frames
   process (pgpTxClk)
   begin
      if rising_edge(pgpTxClk) then
         if pgpTxClkRst = '1' then
            curState         <= IDLE_S          after TPD_G;
            cellCnt          <= (others => '0') after TPD_G;
            int0FrameTxReady <= '0'             after TPD_G;
            int1FrameTxReady <= '0'             after TPD_G;
            int2FrameTxReady <= '0'             after TPD_G;
            int3FrameTxReady <= '0'             after TPD_G;
            intTimeout       <= '0'             after TPD_G;
            schTxSOF         <= '0'             after TPD_G;
            schTxEOF         <= '0'             after TPD_G;
            schTxAck         <= '0'             after TPD_G;
            vc0Serial        <= (others => '0') after TPD_G;
            vc1Serial        <= (others => '0') after TPD_G;
            vc2Serial        <= (others => '0') after TPD_G;
            vc3Serial        <= (others => '0') after TPD_G;
            curTypeLast      <= (others => '0') after TPD_G;
            intOverflow      <= (others => '0') after TPD_G;
         elsif pgpTxClkEn = '1' then

            if pgpTxLinkReady = '0' then
               curState <= IDLE_S after TPD_G;

               vc0Serial <= (others => '0') after TPD_G;
               vc1Serial <= (others => '0') after TPD_G;
               vc2Serial <= (others => '0') after TPD_G;
               vc3Serial <= (others => '0') after TPD_G;
            elsif pgpTxBusy = '0' then
               -- State control
               curState <= nxtState after TPD_G;

               -- Payload Counter
               if cellCntRst = '1' then
                  cellCnt <= (others => '1') after TPD_G;
               elsif cellCnt /= 0 then
                  cellCnt <= cellCnt - 1 after TPD_G;
               end if;

               -- Outgoing ready signal
               case schTxDataVc is
                  when "00" =>
                     int0FrameTxReady <= nxtFrameTxReady after TPD_G;
                     int1FrameTxReady <= '0'             after TPD_G;
                     int2FrameTxReady <= '0'             after TPD_G;
                     int3FrameTxReady <= '0'             after TPD_G;
                  when "01" =>
                     int0FrameTxReady <= '0'             after TPD_G;
                     int1FrameTxReady <= nxtFrameTxReady after TPD_G;
                     int2FrameTxReady <= '0'             after TPD_G;
                     int3FrameTxReady <= '0'             after TPD_G;
                  when "10" =>
                     int0FrameTxReady <= '0'             after TPD_G;
                     int1FrameTxReady <= '0'             after TPD_G;
                     int2FrameTxReady <= nxtFrameTxReady after TPD_G;
                     int3FrameTxReady <= '0'             after TPD_G;
                  when others =>
                     int0FrameTxReady <= '0'             after TPD_G;
                     int1FrameTxReady <= '0'             after TPD_G;
                     int2FrameTxReady <= '0'             after TPD_G;
                     int3FrameTxReady <= nxtFrameTxReady after TPD_G;
               end case;

               -- Register timeout request
               if schTxReq = '1' then
                  intTimeout <= schTxTimeout after TPD_G;
               end if;

               -- Update Last Type
               curTypeLast <= nxtTypeLast after TPD_G;

               -- VC Serial Numbers
               if serialCntEn = '1' then
                  case schTxDataVc is
                     when "00"   => vc0Serial <= vc0Serial + 1 after TPD_G;
                     when "01"   => vc1Serial <= vc1Serial + 1 after TPD_G;
                     when "10"   => vc2Serial <= vc2Serial + 1 after TPD_G;
                     when others => vc3Serial <= vc3Serial + 1 after TPD_G;
                  end case;
               end if;

               -- Scheduler Signals
               schTxSOF <= nxtTxSOF after TPD_G;
               schTxEOF <= nxtTxEOF after TPD_G;
               schTxAck <= nxtTxAck after TPD_G;

               -- Overflow Latch Until Send
               if vc0LocOverflow = '1' then
                  intOverflow(0) <= '1' after TPD_G;
               elsif curState = EMPTY_S or curState = EOC_S then
                  intOverflow(0) <= '0' after TPD_G;
               end if;

               if vc1LocOverflow = '1' then
                  intOverflow(1) <= '1' after TPD_G;
               elsif curState = EMPTY_S or curState = EOC_S then
                  intOverflow(1) <= '0' after TPD_G;
               end if;

               if vc2LocOverflow = '1' then
                  intOverflow(2) <= '1' after TPD_G;
               elsif curState = EMPTY_S or curState = EOC_S then
                  intOverflow(2) <= '0' after TPD_G;
               end if;

               if vc3LocOverflow = '1' then
                  intOverflow(3) <= '1' after TPD_G;
               elsif curState = EMPTY_S or curState = EOC_S then
                  intOverflow(3) <= '0' after TPD_G;
               end if;
            end if;
         end if;
      end if;
   end process;


   -- Drive TX Ready
   vc0FrameTxReady <= int0FrameTxReady when pgpTxBusy = '0' else '0';
   vc1FrameTxReady <= int1FrameTxReady when pgpTxBusy = '0' else '0';
   vc2FrameTxReady <= int2FrameTxReady when pgpTxBusy = '0' else '0';
   vc3FrameTxReady <= int3FrameTxReady when pgpTxBusy = '0' else '0';


   -- Async state control
   process (cellCnt, curState, curTypeLast, eocWord, intTimeout,
            muxFrameTxData, muxFrameTxEOF, muxFrameTxEOFE, muxFrameTxSOF,
            muxFrameTxValid, muxRemAlmostFull, schTxIdle, schTxReq, socWord)
   begin
      case curState is

         -- Idle
         when IDLE_S =>
            cellCntRst      <= '1';
            nxtFrameTxReady <= '0';
            nxtType         <= TX_DATA_C;
            nxtData         <= (others => '0');
            nxtTxSOF        <= '0';
            nxtTxEOF        <= '0';
            nxtTxAck        <= '0';
            serialCntEn     <= '0';
            nxtTypeLast     <= (others => '0');

            -- Idle request
            if schTxIdle = '1' then
               nxtState <= EMPTY_S;

            -- Cell transmit request
            elsif schTxReq = '1' then
               nxtState <= SOC_S;
            else
               nxtState <= curState;
            end if;

         -- Send empty cell
         when EMPTY_S =>
            cellCntRst      <= '1';
            nxtFrameTxReady <= '0';
            nxtType         <= TX_EOC_C;
            nxtTxSOF        <= '0';
            nxtTxEOF        <= '0';
            nxtTxAck        <= '1';
            serialCntEn     <= '0';
            nxtData         <= eocWord;
            nxtTypeLast     <= (others => '0');

            -- Go back to idle
            nxtState <= IDLE_S;

         -- Send first charactor of cell, assert ready
         when SOC_S =>
            cellCntRst      <= '1';
            nxtFrameTxReady <= not intTimeout;
            nxtTxEOF        <= '0';
            nxtTxAck        <= '0';
            serialCntEn     <= '0';
            nxtData         <= socWord;
            nxtTypeLast     <= (others => '0');

            -- Determine type
            if intTimeout = '1' then
               nxtType  <= TX_SOC_C;
               nxtTxSOF <= '0';
            elsif muxFrameTxSOF = '1' then
               nxtType  <= TX_SOF_C;
               nxtTxSOF <= '1';
            else
               nxtType  <= TX_SOC_C;
               nxtTxSOF <= '0';
            end if;

            -- Move on to normal data
            nxtState <= DATA_S;

         -- Send data
         when DATA_S =>
            cellCntRst  <= '0';
            nxtTxEOF    <= '0';
            nxtTxSOF    <= '0';
            nxtTxAck    <= '0';
            serialCntEn <= '0';
            nxtData     <= muxFrameTxData;

            -- Timeout frame, force EOFE
            if intTimeout = '1' then
               nxtType         <= TX_DATA_C;
               nxtTypeLast     <= TX_EOFE_C;
               nxtState        <= CRCA_S;
               nxtFrameTxReady <= '0';

            -- Valid is de-asserted
            elsif muxFrameTxValid = '0' then
               nxtTypeLast     <= TX_EOC_C;
               nxtFrameTxReady <= '0';
               nxtType         <= TX_CRCA_C;

               nxtState <= CRCB_S;
            else
               nxtType <= TX_DATA_C;

               -- EOFE is asserted
               if muxFrameTxEOFE = '1' then
                  nxtTypeLast     <= TX_EOFE_C;
                  nxtState        <= CRCA_S;
                  nxtFrameTxReady <= '0';

               -- EOF is asserted
               elsif muxFrameTxEOF = '1' then
                  nxtTypeLast     <= TX_EOF_C;
                  nxtState        <= CRCA_S;
                  nxtFrameTxReady <= '0';

               -- Pause is asserted
               elsif muxRemAlmostFull = '1' then
                  nxtTypeLast     <= TX_EOC_C;
                  nxtState        <= CRCA_S;
                  nxtFrameTxReady <= '0';

               -- Cell size reached
               elsif cellCnt = 0 then
                  nxtTypeLast     <= TX_EOC_C;
                  nxtState        <= CRCA_S;
                  nxtFrameTxReady <= '0';

               -- Keep sending cell data
               else
                  nxtTypeLast     <= curTypeLast;
                  nxtState        <= curState;
                  nxtFrameTxReady <= '1';
                  nxtType         <= TX_DATA_C;
               end if;
            end if;

         -- Send CRC A
         when CRCA_S =>
            cellCntRst      <= '1';
            nxtTxEOF        <= '0';
            nxtTxSOF        <= '0';
            nxtTxAck        <= '0';
            serialCntEn     <= '0';
            nxtData         <= (others => '0');
            nxtType         <= TX_CRCA_C;
            nxtTypeLast     <= curTypeLast;
            nxtFrameTxReady <= '0';

            nxtState <= CRCB_S;

         -- Send CRC B
         when CRCB_S =>
            cellCntRst      <= '1';
            nxtTxEOF        <= '0';
            nxtTxSOF        <= '0';
            nxtTxAck        <= '0';
            serialCntEn     <= '0';
            nxtData         <= (others => '0');
            nxtType         <= TX_CRCB_C;
            nxtTypeLast     <= curTypeLast;
            nxtFrameTxReady <= '0';
            nxtState        <= EOC_S;

         -- Send End of Cell
         when EOC_S =>
            cellCntRst      <= '1';
            nxtTxSOF        <= '0';
            nxtTxAck        <= '1';
            serialCntEn     <= '1';
            nxtData         <= eocWord;
            nxtType         <= curTypeLast;
            nxtTypeLast     <= curTypeLast;
            nxtFrameTxReady <= '0';
            nxtState        <= IDLE_S;

            -- EOF?
            if curTypeLast /= TX_EOC_C then
               nxtTxEOF <= '1';
            else
               nxtTxEOF <= '0';
            end if;

         -- Default State
         when others =>
            cellCntRst      <= '0';
            nxtTxEOF        <= '0';
            nxtTxSOF        <= '0';
            nxtTxAck        <= '0';
            serialCntEn     <= '0';
            nxtData         <= (others => '0');
            nxtType         <= (others => '0');
            nxtTypeLast     <= (others => '0');
            nxtFrameTxReady <= '0';
            nxtState        <= IDLE_S;
      end case;
   end process;


   -- Delay chain to allow CRC data to catch up.
   process (pgpTxClk)
   begin
      if rising_edge(pgpTxClk) then
         if pgpTxClkRst = '1' then
            dly0Data <= (others => '0');
            dly0Type <= (others => '0');
            dly1Data <= (others => '0');
            dly1Type <= (others => '0');
            dly2Data <= (others => '0');
            dly2Type <= (others => '0');
            dly3Data <= (others => '0');
            dly3Type <= (others => '0');
            dly4Data <= (others => '0');
            dly4Type <= (others => '0');
         elsif pgpTxClkEn = '1' and pgpTxBusy = '0' then
            -- Delay stage 1
            dly0Data <= nxtData after TPD_G;
            dly0Type <= nxtType after TPD_G;

            -- Delay stage 2
            dly1Data <= dly0Data after TPD_G;
            dly1Type <= dly0Type after TPD_G;

            -- Delay stage 3
            dly2Data <= dly1Data after TPD_G;
            dly2Type <= dly1Type after TPD_G;

            -- Delay stage 3
            dly3Data <= dly2Data after TPD_G;
            dly3Type <= dly2Type after TPD_G;

            -- Delay stage 3
            dly4Data <= dly3Data after TPD_G;
            dly4Type <= dly3Type after TPD_G;
         end if;
      end if;
   end process;


   -- Output to CRC engine
   -- TODO: This might need a delay too!
   crcTxIn    <= dly0Data;
   crcTxInit  <= '1' when (dly0Type = TX_SOC_C or dly0Type = TX_SOF_C)                                             else '0';
   crcTxValid <= '1' when (dly0Type = TX_SOC_C or dly0Type = TX_SOF_C or dly0Type = TX_DATA_C) and pgpTxBusy = '0' else '0';


   -- CRC Data, Single lane, split into two 16-bit values
   crcWordA(7 downto 0)  <= crcTxOut(31 downto 24);
   crcWordA(15 downto 8) <= crcTxOut(23 downto 16);
   crcWordB(7 downto 0)  <= crcTxOut(15 downto 8);
   crcWordB(15 downto 8) <= crcTxOut(7 downto 0);

   -- Output stage
   process (pgpTxClk)
   begin
      if rising_edge(pgpTxClk) then
         if pgpTxClkRst = '1' then
            cellTxSOC  <= '0'             after TPD_G;
            cellTxSOF  <= '0'             after TPD_G;
            cellTxEOC  <= '0'             after TPD_G;
            cellTxEOF  <= '0'             after TPD_G;
            cellTxEOFE <= '0'             after TPD_G;
            cellTxData <= (others => '0') after TPD_G;
         elsif pgpTxClkEn = '1' and pgpTxBusy = '0' then
            -- Which data type
            case dly2Type is
               when TX_DATA_C =>
                  cellTxSOC  <= '0'      after TPD_G;
                  cellTxSOF  <= '0'      after TPD_G;
                  cellTxEOC  <= '0'      after TPD_G;
                  cellTxEOF  <= '0'      after TPD_G;
                  cellTxEOFE <= '0'      after TPD_G;
                  cellTxData <= dly2Data after TPD_G;
               when TX_SOC_C =>
                  cellTxSOC  <= '1'      after TPD_G;
                  cellTxSOF  <= '0'      after TPD_G;
                  cellTxEOC  <= '0'      after TPD_G;
                  cellTxEOF  <= '0'      after TPD_G;
                  cellTxEOFE <= '0'      after TPD_G;
                  cellTxData <= dly2Data after TPD_G;
               when TX_SOF_C =>
                  cellTxSOC  <= '1'      after TPD_G;
                  cellTxSOF  <= '1'      after TPD_G;
                  cellTxEOC  <= '0'      after TPD_G;
                  cellTxEOF  <= '0'      after TPD_G;
                  cellTxEOFE <= '0'      after TPD_G;
                  cellTxData <= dly2Data after TPD_G;
               when TX_CRCA_C =>
                  cellTxSOC  <= '0'      after TPD_G;
                  cellTxSOF  <= '0'      after TPD_G;
                  cellTxEOC  <= '0'      after TPD_G;
                  cellTxEOF  <= '0'      after TPD_G;
                  cellTxEOFE <= '0'      after TPD_G;
                  cellTxData <= crcWordA after TPD_G;
               when TX_CRCB_C =>
                  cellTxSOC  <= '0'      after TPD_G;
                  cellTxSOF  <= '0'      after TPD_G;
                  cellTxEOC  <= '0'      after TPD_G;
                  cellTxEOF  <= '0'      after TPD_G;
                  cellTxEOFE <= '0'      after TPD_G;
                  cellTxData <= crcWordB after TPD_G;
               when TX_EOC_C =>
                  cellTxSOC  <= '0'      after TPD_G;
                  cellTxSOF  <= '0'      after TPD_G;
                  cellTxEOC  <= '1'      after TPD_G;
                  cellTxEOF  <= '0'      after TPD_G;
                  cellTxEOFE <= '0'      after TPD_G;
                  cellTxData <= dly2Data after TPD_G;
               when TX_EOF_C =>
                  cellTxSOC  <= '0'      after TPD_G;
                  cellTxSOF  <= '0'      after TPD_G;
                  cellTxEOC  <= '1'      after TPD_G;
                  cellTxEOF  <= '1'      after TPD_G;
                  cellTxEOFE <= '0'      after TPD_G;
                  cellTxData <= dly2Data after TPD_G;
               when TX_EOFE_C =>
                  cellTxSOC  <= '0'      after TPD_G;
                  cellTxSOF  <= '0'      after TPD_G;
                  cellTxEOC  <= '1'      after TPD_G;
                  cellTxEOF  <= '1'      after TPD_G;
                  cellTxEOFE <= '1'      after TPD_G;
                  cellTxData <= dly2Data after TPD_G;
               when others =>
                  cellTxSOC  <= '0'             after TPD_G;
                  cellTxSOF  <= '0'             after TPD_G;
                  cellTxEOC  <= '0'             after TPD_G;
                  cellTxEOF  <= '0'             after TPD_G;
                  cellTxEOFE <= '0'             after TPD_G;
                  cellTxData <= (others => '0') after TPD_G;
            end case;
         end if;
      end if;
   end process;

end Pgp2fcTxCell;

