-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, Cell Transmit Interface
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2TxCell.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/18/2009
-------------------------------------------------------------------------------
-- Description:
-- Cell Transmit interface module for the Pretty Good Protocol core. 
-------------------------------------------------------------------------------
-- Copyright (c) 2006 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 05/18/2009: created.
-- 11/23/2009: Renamed package.
-- 06/25/2010: Added payload size config as generic.
-- 05/18/2012: Added VC transmit timeout
-------------------------------------------------------------------------------

LIBRARY ieee;
--USE work.ALL;
USE work.Pgp2CorePackage.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Pgp2TxCell is 
   generic (
      TxLaneCnt     : integer := 4; -- Number of bonded lanes, 1-4
      PayloadCntTop : integer := 7  -- Top bit for payload counter
   );
   port ( 

      -- System clock, reset & control
      pgpTxClk          : in  std_logic;                                 -- Master clock
      pgpTxReset        : in  std_logic;                                 -- Synchronous reset input

      -- Link is ready
      pgpTxLinkReady    : in  std_logic;                                 -- Local side has link

      -- Phy Transmit Interface
      cellTxSOC         : out std_logic;                                 -- Cell data start of cell
      cellTxSOF         : out std_logic;                                 -- Cell data start of frame
      cellTxEOC         : out std_logic;                                 -- Cell data end of cell
      cellTxEOF         : out std_logic;                                 -- Cell data end of frame
      cellTxEOFE        : out std_logic;                                 -- Cell data end of frame error
      cellTxData        : out std_logic_vector(TxLaneCnt*16-1 downto 0); -- Cell data data

      -- Transmit Scheduler Interface
      schTxSOF          : out std_logic;                                 -- Cell contained SOF
      schTxEOF          : out std_logic;                                 -- Cell contained EOF
      schTxIdle         : in  std_logic;                                 -- Force IDLE transmit
      schTxReq          : in  std_logic;                                 -- Cell transmit request
      schTxAck          : out std_logic;                                 -- Cell transmit acknowledge
      schTxTimeout      : in  std_logic;                                 -- Cell transmit timeout
      schTxDataVc       : in  std_logic_vector(1 downto 0);              -- Cell transmit virtual channel

      -- Frame Transmit Interface, VC 0
      vc0FrameTxValid   : in  std_logic;                                 -- User frame data is valid
      vc0FrameTxReady   : out std_logic;                                 -- PGP is ready
      vc0FrameTxSOF     : in  std_logic;                                 -- User frame data start of frame
      vc0FrameTxEOF     : in  std_logic;                                 -- User frame data end of frame
      vc0FrameTxEOFE    : in  std_logic;                                 -- User frame data error
      vc0FrameTxData    : in  std_logic_vector(TxLaneCnt*16-1 downto 0); -- User frame data
      vc0LocBuffAFull   : in  std_logic;                                 -- Remote buffer almost full
      vc0LocBuffFull    : in  std_logic;                                 -- Remote buffer full

      -- Frame Transmit Interface, VC 1
      vc1FrameTxValid   : in  std_logic;                                 -- User frame data is valid
      vc1FrameTxReady   : out std_logic;                                 -- PGP is ready
      vc1FrameTxSOF     : in  std_logic;                                 -- User frame data start of frame
      vc1FrameTxEOF     : in  std_logic;                                 -- User frame data end of frame
      vc1FrameTxEOFE    : in  std_logic;                                 -- User frame data error
      vc1FrameTxData    : in  std_logic_vector(TxLaneCnt*16-1 downto 0); -- User frame data
      vc1LocBuffAFull   : in  std_logic;                                 -- Remote buffer almost full
      vc1LocBuffFull    : in  std_logic;                                 -- Remote buffer full

      -- Frame Transmit Interface, VC 2
      vc2FrameTxValid   : in  std_logic;                                 -- User frame data is valid
      vc2FrameTxReady   : out std_logic;                                 -- PGP is ready
      vc2FrameTxSOF     : in  std_logic;                                 -- User frame data start of frame
      vc2FrameTxEOF     : in  std_logic;                                 -- User frame data end of frame
      vc2FrameTxEOFE    : in  std_logic;                                 -- User frame data error
      vc2FrameTxData    : in  std_logic_vector(TxLaneCnt*16-1 downto 0); -- User frame data
      vc2LocBuffAFull   : in  std_logic;                                 -- Remote buffer almost full
      vc2LocBuffFull    : in  std_logic;                                 -- Remote buffer full

      -- Frame Transmit Interface, VC 3
      vc3FrameTxValid   : in  std_logic;                                 -- User frame data is valid
      vc3FrameTxReady   : out std_logic;                                 -- PGP is ready
      vc3FrameTxSOF     : in  std_logic;                                 -- User frame data start of frame
      vc3FrameTxEOF     : in  std_logic;                                 -- User frame data end of frame
      vc3FrameTxEOFE    : in  std_logic;                                 -- User frame data error
      vc3FrameTxData    : in  std_logic_vector(TxLaneCnt*16-1 downto 0); -- User frame data
      vc3LocBuffAFull   : in  std_logic;                                 -- Remote buffer almost full
      vc3LocBuffFull    : in  std_logic;                                 -- Remote buffer full

      -- Transmit CRC Interface
      crcTxIn           : out std_logic_vector(TxLaneCnt*16-1 downto 0); -- Transmit data for CRC
      crcTxInit         : out std_logic;                                 -- Transmit CRC value init
      crcTxValid        : out std_logic;                                 -- Transmit data for CRC is valid
      crcTxOut          : in  std_logic_vector(31 downto 0)              -- Transmit calculated CRC value
   );

end Pgp2TxCell;


-- Define architecture
architecture Pgp2TxCell of Pgp2TxCell is

   -- Local Signals
   signal muxFrameTxValid    : std_logic;
   signal muxFrameTxSOF      : std_logic;
   signal muxFrameTxEOF      : std_logic;
   signal muxFrameTxEOFE     : std_logic;
   signal muxFrameTxData     : std_logic_vector(TxLaneCnt*16-1 downto 0);
   signal cellCnt            : std_logic_vector(PayloadCntTop downto 0);
   signal cellCntRst         : std_logic;
   signal nxtFrameTxReady    : std_logic;
   signal nxtType            : std_logic_vector(2 downto 0);
   signal nxtTypeLast        : std_logic_vector(2 downto 0);
   signal curTypeLast        : std_logic_vector(2 downto 0);
   signal nxtTxSOF           : std_logic;
   signal nxtTxEOF           : std_logic;
   signal nxtTxAck           : std_logic;
   signal nxtData            : std_logic_vector(TxLaneCnt*16-1 downto 0);
   signal eocWord            : std_logic_vector(TxLaneCnt*16-1 downto 0);
   signal socWord            : std_logic_vector(TxLaneCnt*16-1 downto 0);
   signal crcWordA           : std_logic_vector(TxLaneCnt*16-1 downto 0);
   signal crcWordB           : std_logic_vector(TxLaneCnt*16-1 downto 0);
   signal serialCntEn        : std_logic;
   signal vc0Serial          : std_logic_vector(5 downto 0);
   signal vc1Serial          : std_logic_vector(5 downto 0);
   signal vc2Serial          : std_logic_vector(5 downto 0);
   signal vc3Serial          : std_logic_vector(5 downto 0);
   signal muxSerial          : std_logic_vector(5 downto 0);
   signal dly0Data           : std_logic_vector(TxLaneCnt*16-1 downto 0);
   signal dly0Type           : std_logic_vector(2 downto 0);
   signal dly1Data           : std_logic_vector(TxLaneCnt*16-1 downto 0);
   signal dly1Type           : std_logic_vector(2 downto 0);
   signal dly2Data           : std_logic_vector(TxLaneCnt*16-1 downto 0);
   signal dly2Type           : std_logic_vector(2 downto 0);
   signal dly3Data           : std_logic_vector(TxLaneCnt*16-1 downto 0);
   signal dly3Type           : std_logic_vector(2 downto 0);
   signal dly4Data           : std_logic_vector(TxLaneCnt*16-1 downto 0);
   signal dly4Type           : std_logic_vector(2 downto 0);
   signal int0FrameTxReady   : std_logic;
   signal int1FrameTxReady   : std_logic;
   signal int2FrameTxReady   : std_logic;
   signal int3FrameTxReady   : std_logic;
   signal intTimeout         : std_logic;

   -- Transmit Data Marker
   constant TX_DATA   : std_logic_vector(2 downto 0) := "000";
   constant TX_SOC    : std_logic_vector(2 downto 0) := "001";
   constant TX_SOF    : std_logic_vector(2 downto 0) := "010";
   constant TX_EOC    : std_logic_vector(2 downto 0) := "011";
   constant TX_EOF    : std_logic_vector(2 downto 0) := "100";
   constant TX_EOFE   : std_logic_vector(2 downto 0) := "101";
   constant TX_CRCA   : std_logic_vector(2 downto 0) := "110";
   constant TX_CRCB   : std_logic_vector(2 downto 0) := "111";

   -- Transmit states
   signal   curState  : std_logic_vector(2 downto 0);
   signal   nxtState  : std_logic_vector(2 downto 0);
   constant ST_IDLE   : std_logic_vector(2 downto 0) := "001";
   constant ST_EMPTY  : std_logic_vector(2 downto 0) := "010";
   constant ST_SOC    : std_logic_vector(2 downto 0) := "011";
   constant ST_DATA   : std_logic_vector(2 downto 0) := "100";
   constant ST_CRCA   : std_logic_vector(2 downto 0) := "101";
   constant ST_CRCB   : std_logic_vector(2 downto 0) := "110";
   constant ST_EOC    : std_logic_vector(2 downto 0) := "111";

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin


   -- Mux incoming data
   process ( vc0FrameTxValid, vc0FrameTxSOF, vc0FrameTxEOF, vc0FrameTxEOFE, vc0FrameTxData, 
             vc1FrameTxValid, vc1FrameTxSOF, vc1FrameTxEOF, vc1FrameTxEOFE, vc1FrameTxData, 
             vc2FrameTxValid, vc2FrameTxSOF, vc2FrameTxEOF, vc2FrameTxEOFE, vc2FrameTxData, 
             vc3FrameTxValid, vc3FrameTxSOF, vc3FrameTxEOF, vc3FrameTxEOFE, vc3FrameTxData, 
             vc0Serial, vc1Serial, vc2Serial, vc3Serial, schTxDataVc ) begin
      case schTxDataVc is
         when "00" =>
            muxFrameTxValid <= vc0FrameTxValid;
            muxFrameTxSOF   <= vc0FrameTxSOF;
            muxFrameTxEOF   <= vc0FrameTxEOF;
            muxFrameTxEOFE  <= vc0FrameTxEOFE;
            muxFrameTxData  <= vc0FrameTxData;
            muxSerial       <= vc0Serial;
         when "01" =>
            muxFrameTxValid <= vc1FrameTxValid;
            muxFrameTxSOF   <= vc1FrameTxSOF;
            muxFrameTxEOF   <= vc1FrameTxEOF;
            muxFrameTxEOFE  <= vc1FrameTxEOFE;
            muxFrameTxData  <= vc1FrameTxData;
            muxSerial       <= vc1Serial;
         when "10" =>
            muxFrameTxValid <= vc2FrameTxValid;
            muxFrameTxSOF   <= vc2FrameTxSOF;
            muxFrameTxEOF   <= vc2FrameTxEOF;
            muxFrameTxEOFE  <= vc2FrameTxEOFE;
            muxFrameTxData  <= vc2FrameTxData;
            muxSerial       <= vc2Serial;
         when others =>
            muxFrameTxValid <= vc3FrameTxValid;
            muxFrameTxSOF   <= vc3FrameTxSOF;
            muxFrameTxEOF   <= vc3FrameTxEOF;
            muxFrameTxEOFE  <= vc3FrameTxEOFE;
            muxFrameTxData  <= vc3FrameTxData;
            muxSerial       <= vc3Serial;
      end case;
   end process;


   -- Choose data for SOF & EOF Positions
   GEN_DATA: for i in 0 to (TxLaneCnt-1) generate

      -- SOF, vc number and serial number
      socWord(i*16+15 downto i*16+14) <= schTxDataVc;
      socWord(i*16+13 downto i*16+8)  <= muxSerial;
      socWord(i*16+7  downto i*16)    <= (others=>'0');

      -- EOF, buffer status
      eocWord(i*16+15 downto i*16+12) <= vc3LocBuffFull  & vc2LocBuffFull  & vc1LocBuffFull  & vc0LocBuffFull;
      eocWord(i*16+11 downto i*16+8)  <= vc3LocBuffAFull & vc2LocBuffAFull & vc1LocBuffAFull & vc0LocBuffAFull;
      eocWord(i*16+7  downto i*16)    <= (others=>'0');
   end generate;


   -- Simple state machine to control transmission of data frames
   process ( pgpTxClk, pgpTxReset ) begin
      if pgpTxReset = '1' then
         curState         <= ST_IDLE       after tpd;
         cellCnt          <= (others=>'0') after tpd;
         int0FrameTxReady <= '0'           after tpd;
         int1FrameTxReady <= '0'           after tpd;
         int2FrameTxReady <= '0'           after tpd;
         int3FrameTxReady <= '0'           after tpd;
         intTimeout       <= '0'           after tpd;
         schTxSOF         <= '0'           after tpd;
         schTxEOF         <= '0'           after tpd;
         schTxAck         <= '0'           after tpd;
         vc0Serial        <= (others=>'0') after tpd;
         vc1Serial        <= (others=>'0') after tpd;
         vc2Serial        <= (others=>'0') after tpd;
         vc3Serial        <= (others=>'0') after tpd;
         curTypeLast      <= (others=>'0') after tpd;
      elsif rising_edge(pgpTxClk) then

         -- State control
         if pgpTxLinkReady = '0' then
            curState <= ST_IDLE  after tpd;
         else
            curState <= nxtState after tpd;
         end if;

         -- Payload Counter
         if cellCntRst = '1' then
            cellCnt <= (others=>'1') after tpd;
         elsif cellCnt /= 0 then
            cellCnt <= cellCnt - 1 after tpd;
         end if;

         -- Outgoing ready signal
         case schTxDataVc is
            when "00" =>
               int0FrameTxReady <= nxtFrameTxReady after tpd;
               int1FrameTxReady <= '0'             after tpd;
               int2FrameTxReady <= '0'             after tpd;
               int3FrameTxReady <= '0'             after tpd;
            when "01" =>
               int0FrameTxReady <= '0'             after tpd;
               int1FrameTxReady <= nxtFrameTxReady after tpd;
               int2FrameTxReady <= '0'             after tpd;
               int3FrameTxReady <= '0'             after tpd;
            when "10" =>
               int0FrameTxReady <= '0'             after tpd;
               int1FrameTxReady <= '0'             after tpd;
               int2FrameTxReady <= nxtFrameTxReady after tpd;
               int3FrameTxReady <= '0'             after tpd;
            when others =>
               int0FrameTxReady <= '0'             after tpd;
               int1FrameTxReady <= '0'             after tpd;
               int2FrameTxReady <= '0'             after tpd;
               int3FrameTxReady <= nxtFrameTxReady after tpd;
         end case;

         -- Register timeout request
         if schTxReq = '1' then
            intTimeout <= schTxTimeout after tpd;
         end if;

         -- Update Last Type
         curTypeLast <= nxtTypeLast after tpd;

         -- VC Serial Numbers
         if pgpTxLinkReady = '0' then
            vc0Serial <= (others=>'0') after tpd;
            vc1Serial <= (others=>'0') after tpd;
            vc2Serial <= (others=>'0') after tpd;
            vc3Serial <= (others=>'0') after tpd;
         elsif serialCntEn = '1' then
            case schTxDataVc is
               when "00"   => vc0Serial <= vc0Serial + 1 after tpd;
               when "01"   => vc1Serial <= vc1Serial + 1 after tpd;
               when "10"   => vc2Serial <= vc2Serial + 1 after tpd;
               when others => vc3Serial <= vc3Serial + 1 after tpd;
            end case;
         end if;

         -- Scheduler Signals
         schTxSOF <= nxtTxSOF after tpd;
         schTxEOF <= nxtTxEOF after tpd;
         schTxAck <= nxtTxAck after tpd;

      end if;
   end process;


   -- Drive TX Ready
   vc0FrameTxReady <= int0FrameTxReady;
   vc1FrameTxReady <= int1FrameTxReady;
   vc2FrameTxReady <= int2FrameTxReady;
   vc3FrameTxReady <= int3FrameTxReady;


   -- Async state control
   process ( curState, schTxIdle, schTxReq, intTimeout, cellCnt, eocWord, socWord, curTypeLast,
            muxFrameTxValid, muxFrameTxSOF, muxFrameTxEOF, muxFrameTxEOFE, muxFrameTxData ) begin
      case curState is 

         -- Idle
         when ST_IDLE =>
            cellCntRst      <= '1';
            nxtFrameTxReady <= '0';
            nxtType         <= TX_DATA;
            nxtData         <= (others=>'0');
            nxtTxSOF        <= '0';
            nxtTxEOF        <= '0';
            nxtTxAck        <= '0';
            serialCntEn     <= '0';
            nxtTypeLast     <= (others=>'0');

            -- Idle request
            if schTxIdle = '1' then
               nxtState <= ST_EMPTY;

            -- Cell transmit request
            elsif schTxReq = '1' then
               nxtState <= ST_SOC;
            else
               nxtState <= curState;
            end if;

         -- Send empty cell
         when ST_EMPTY =>
            cellCntRst      <= '1';
            nxtFrameTxReady <= '0';
            nxtType         <= TX_EOC;
            nxtTxSOF        <= '0';
            nxtTxEOF        <= '0';
            nxtTxAck        <= '1';
            serialCntEn     <= '0';
            nxtData         <= eocWord;
            nxtTypeLast     <= (others=>'0');

            -- Go back to idle
            nxtState <= ST_IDLE;

         -- Send first charactor of cell, assert ready
         when ST_SOC =>
            cellCntRst      <= '1';
            nxtFrameTxReady <= not intTimeout;
            nxtTxEOF        <= '0';
            nxtTxAck        <= '0';
            serialCntEn     <= '0';
            nxtData         <= socWord;
            nxtTypeLast     <= (others=>'0');

            -- Determine type
            if intTimeout = '1' then
               nxtType  <= TX_SOC;
               nxtTxSOF <= '0';
            elsif muxFrameTxSOF = '1' then
               nxtType  <= TX_SOF;
               nxtTxSOF <= '1';
            else
               nxtType  <= TX_SOC;
               nxtTxSOF <= '0';
            end if;

            -- Move on to normal data
            nxtState <= ST_DATA;

         -- Send data
         when ST_DATA =>
            cellCntRst   <= '0';
            nxtTxEOF     <= '0';
            nxtTxSOF     <= '0';
            nxtTxAck     <= '0';
            serialCntEn  <= '0';
            nxtData      <= muxFrameTxData;

            -- Timeout frame, force EOFE
            if intTimeout = '1' then
               nxtType         <= TX_DATA;
               nxtTypeLast     <= TX_EOFE;
               nxtState        <= ST_CRCA;
               nxtFrameTxReady <= '0';

            -- Valid is de-asserted
            elsif muxFrameTxValid = '0' then
               nxtTypeLast     <= TX_EOC;
               nxtFrameTxReady <= '0';
               nxtType         <= TX_CRCA;

               -- One or two CRC words?
               if TxLaneCnt = 1 then
                  nxtState <= ST_CRCB;
               else
                  nxtState <= ST_EOC;
               end if;
            else
               nxtType <= TX_DATA;

               -- EOFE is asserted
               if muxFrameTxEOFE = '1' then
                  nxtTypeLast     <= TX_EOFE;
                  nxtState        <= ST_CRCA;
                  nxtFrameTxReady <= '0';
              
               -- EOF is asserted
               elsif muxFrameTxEOF = '1' then
                  nxtTypeLast     <= TX_EOF;
                  nxtState        <= ST_CRCA;
                  nxtFrameTxReady <= '0';

               -- Cell size reached
               elsif cellCnt = 0 then
                  nxtTypeLast     <= TX_EOC;
                  nxtState        <= ST_CRCA;
                  nxtFrameTxReady <= '0';

               -- Keep sending cell data
               else
                  nxtTypeLast     <= curTypeLast;
                  nxtState        <= curState;
                  nxtFrameTxReady <= '1';
                  nxtType         <= TX_DATA;
               end if;
            end if;

         -- Send CRC A
         when ST_CRCA =>
            cellCntRst      <= '1';
            nxtTxEOF        <= '0';
            nxtTxSOF        <= '0';
            nxtTxAck        <= '0';
            serialCntEn     <= '0';
            nxtData         <= (others=>'0');
            nxtType         <= TX_CRCA;
            nxtTypeLast     <= curTypeLast;
            nxtFrameTxReady <= '0';

            -- One or two CRC words?
            if TxLaneCnt = 1 then
               nxtState <= ST_CRCB;
            else
               nxtState <= ST_EOC;
            end if;

         -- Send CRC B
         when ST_CRCB =>
            cellCntRst      <= '1';
            nxtTxEOF        <= '0';
            nxtTxSOF        <= '0';
            nxtTxAck        <= '0';
            serialCntEn     <= '0';
            nxtData         <= (others=>'0');
            nxtType         <= TX_CRCB;
            nxtTypeLast     <= curTypeLast;
            nxtFrameTxReady <= '0';
            nxtState        <= ST_EOC;

         -- Send End of Cell
         when ST_EOC =>
            cellCntRst      <= '1';
            nxtTxSOF        <= '0';
            nxtTxAck        <= '1';
            serialCntEn     <= '1';
            nxtData         <= eocWord;
            nxtType         <= curTypeLast;
            nxtTypeLast     <= curTypeLast;
            nxtFrameTxReady <= '0';
            nxtState        <= ST_IDLE;

            -- EOF?
            if curTypeLast /= TX_EOC then
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
            nxtData         <= (others=>'0');
            nxtType         <= (others=>'0');
            nxtTypeLast     <= (others=>'0');
            nxtFrameTxReady <= '0';
            nxtState        <= ST_IDLE;
      end case;
   end process;


   -- Delay chain to allow CRC data to catch up.
   process ( pgpTxClk, pgpTxReset ) begin
      if pgpTxReset = '1' then
         dly0Data         <= (others=>'0');
         dly0Type         <= (others=>'0');
         dly1Data         <= (others=>'0');
         dly1Type         <= (others=>'0');
         dly2Data         <= (others=>'0');
         dly2Type         <= (others=>'0');
         dly3Data         <= (others=>'0');
         dly3Type         <= (others=>'0');
         dly4Data         <= (others=>'0');
         dly4Type         <= (others=>'0');
      elsif rising_edge(pgpTxClk) then

         -- Delay stage 1
         dly0Data  <= nxtData after tpd;
         dly0Type  <= nxtType after tpd;

         -- Delay stage 2
         dly1Data  <= dly0Data after tpd;
         dly1Type  <= dly0Type after tpd;

         -- Delay stage 3
         dly2Data  <= dly1Data after tpd;
         dly2Type  <= dly1Type after tpd;

         -- Delay stage 3
         dly3Data  <= dly2Data after tpd;
         dly3Type  <= dly2Type after tpd;

         -- Delay stage 3
         dly4Data  <= dly3Data after tpd;
         dly4Type  <= dly3Type after tpd;
      end if;
   end process;


   -- Output to CRC engine
   crcTxIn      <= dly0Data;
   crcTxInit    <= '1' when (dly0Type = TX_SOC or dly0Type = TX_SOF) else '0';
   crcTxValid   <= '1' when (dly0Type = TX_SOC or dly0Type = TX_SOF or dly0Type = TX_DATA) else '0';


   -- CRC Data, Single lane, split into two 16-bit values
   GEN_CRC_NARROW: if TxLaneCnt = 1 generate
      crcWordA(7  downto 0) <= crcTxOut(31 downto 24);
      crcWordA(15 downto 8) <= crcTxOut(23 downto 16);
      crcWordB(7  downto 0) <= crcTxOut(15 downto  8);
      crcWordB(15 downto 8) <= crcTxOut(7  downto  0);
   end generate;

   -- CRC Data, Multi lane, send one 32-bit value
   GEN_CRC_WIDE: if TxLaneCnt /= 1 generate
      crcWordA(7  downto  0) <= crcTxOut(31 downto 24);
      crcWordA(15 downto  8) <= crcTxOut(23 downto 16);
      crcWordA(23 downto 16) <= crcTxOut(15 downto  8);
      crcWordA(31 downto 24) <= crcTxOut(7  downto  0);
      crcWordB(31 downto  0) <= (others=>'0');
   end generate;

   -- CRC Data, 3 or 4 lanes, Set upper bits to 0.
   GEN_CRC_OTHER: if TxLaneCnt >= 3 generate
      crcWordA(TxLaneCnt*16-1 downto 32) <= (others=>'0');
      crcWordB(TxLaneCnt*16-1 downto 32) <= (others=>'0');
   end generate;

   -- Output stage
   process ( pgpTxClk, pgpTxReset ) begin
      if pgpTxReset = '1' then
         cellTxSOC    <= '0'           after tpd;
         cellTxSOF    <= '0'           after tpd;
         cellTxEOC    <= '0'           after tpd;
         cellTxEOF    <= '0'           after tpd;
         cellTxEOFE   <= '0'           after tpd;
         cellTxData   <= (others=>'0') after tpd;
      elsif rising_edge(pgpTxClk) then

         -- Which data type
         case dly2Type is 
            when TX_DATA =>
               cellTxSOC    <= '0'           after tpd;
               cellTxSOF    <= '0'           after tpd;
               cellTxEOC    <= '0'           after tpd;
               cellTxEOF    <= '0'           after tpd;
               cellTxEOFE   <= '0'           after tpd;
               cellTxData   <= dly2Data      after tpd;
            when TX_SOC =>
               cellTxSOC    <= '1'           after tpd;
               cellTxSOF    <= '0'           after tpd;
               cellTxEOC    <= '0'           after tpd;
               cellTxEOF    <= '0'           after tpd;
               cellTxEOFE   <= '0'           after tpd;
               cellTxData   <= dly2Data      after tpd;
            when TX_SOF =>
               cellTxSOC    <= '1'           after tpd;
               cellTxSOF    <= '1'           after tpd;
               cellTxEOC    <= '0'           after tpd;
               cellTxEOF    <= '0'           after tpd;
               cellTxEOFE   <= '0'           after tpd;
               cellTxData   <= dly2Data      after tpd;
            when TX_CRCA =>
               cellTxSOC    <= '0'           after tpd;
               cellTxSOF    <= '0'           after tpd;
               cellTxEOC    <= '0'           after tpd;
               cellTxEOF    <= '0'           after tpd;
               cellTxEOFE   <= '0'           after tpd;
               cellTxData   <= crcWordA      after tpd;
            when TX_CRCB =>
               cellTxSOC    <= '0'           after tpd;
               cellTxSOF    <= '0'           after tpd;
               cellTxEOC    <= '0'           after tpd;
               cellTxEOF    <= '0'           after tpd;
               cellTxEOFE   <= '0'           after tpd;
               cellTxData   <= crcWordB      after tpd;
            when TX_EOC =>
               cellTxSOC    <= '0'           after tpd;
               cellTxSOF    <= '0'           after tpd;
               cellTxEOC    <= '1'           after tpd;
               cellTxEOF    <= '0'           after tpd;
               cellTxEOFE   <= '0'           after tpd;
               cellTxData   <= dly2Data      after tpd;
            when TX_EOF =>
               cellTxSOC    <= '0'           after tpd;
               cellTxSOF    <= '0'           after tpd;
               cellTxEOC    <= '1'           after tpd;
               cellTxEOF    <= '1'           after tpd;
               cellTxEOFE   <= '0'           after tpd;
               cellTxData   <= dly2Data      after tpd;
            when TX_EOFE =>
               cellTxSOC    <= '0'           after tpd;
               cellTxSOF    <= '0'           after tpd;
               cellTxEOC    <= '1'           after tpd;
               cellTxEOF    <= '1'           after tpd;
               cellTxEOFE   <= '1'           after tpd;
               cellTxData   <= dly2Data      after tpd;
            when others =>
               cellTxSOC    <= '0'           after tpd;
               cellTxSOF    <= '0'           after tpd;
               cellTxEOC    <= '0'           after tpd;
               cellTxEOF    <= '0'           after tpd;
               cellTxEOFE   <= '0'           after tpd;
               cellTxData   <= (others=>'0') after tpd;
         end case;
      end if;
   end process;

end Pgp2TxCell;

